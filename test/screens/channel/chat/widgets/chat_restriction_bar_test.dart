import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/chat_restrictions.dart';
import 'package:onset/screens/channel/chat/widgets/chat_restriction_bar.dart';
import 'package:onset/screens/channel/chat/widgets/chat_warning_dialog.dart';
import 'package:onset/utils/link_router.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  var now = DateTime.utc(2026, 10, 13, 20);

  Future<void> pump(WidgetTester tester, ChatRestriction? restriction) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatRestrictionBar(restriction: restriction, now: () => now),
          ),
        ),
      );

  testWidgets('a timeout counts down every second', (tester) async {
    await pump(
      tester,
      ChatRestriction(
        ChatRestrictionKind.timedOut,
        until: now.add(const Duration(seconds: 65)),
      ),
    );
    expect(find.text('You’re timed out · 1:05'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('You’re timed out · 1:04'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('room modes stay out of this line', (tester) async {
    await pump(
      tester,
      const ChatRestriction(ChatRestrictionKind.followersOnly, minutes: 10),
    );
    expect(find.byType(Text), findsNothing);
    await pump(tester, null);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a ban shows its line (fixed height) without a countdown', (
    tester,
  ) async {
    await pump(tester, const ChatRestriction(ChatRestrictionKind.banned));
    expect(find.text('Permanently banned'), findsOneWidget);
    expect(
      tester.getSize(find.byType(ChatRestrictionBar)).height,
      kRestrictionBarTapHeight,
    );
    expect(
      tester.getSize(find.byKey(ChatRestrictionBar.lineKey)).height,
      kRestrictionBarHeight,
    );
  });

  testWidgets('a ban bar opens the unban request on a tap', (tester) async {
    var appeals = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatRestrictionBar(
            restriction: const ChatRestriction(ChatRestrictionKind.banned),
            now: () => now,
            onAppeal: () => appeals++,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ChatRestrictionBar));
    expect(appeals, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatRestrictionBar(
            restriction: ChatRestriction(
              ChatRestrictionKind.timedOut,
              until: now.add(const Duration(minutes: 1)),
            ),
            now: () => now,
            onAppeal: () => appeals++,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ChatRestrictionBar));
    expect(appeals, 1);
  });

  test('USERSTATE knows a VIP from its badges', () {
    final state = const USERSTATE().fromIRCMessage(
      IRCMessage.fromString(
        '@badges=vip/1,subscriber/12;mod=0;subscriber=1 '
        ':tmi.twitch.tv USERSTATE #channel',
      ),
    );
    expect(state.vip, isTrue);
    expect(state.mod, isFalse);
    final plain = state.fromIRCMessage(
      IRCMessage.fromString(
        '@badges=subscriber/12;mod=0 :tmi.twitch.tv USERSTATE #channel',
      ),
    );
    expect(plain.vip, isFalse);
    // No badges at all (an empty tag) is no VIP either.
    final none = state.fromIRCMessage(
      IRCMessage.fromString('@badges=;mod=0 :tmi.twitch.tv USERSTATE #channel'),
    );
    expect(none.vip, isFalse);
  });

  testWidgets('a verification requirement opens Twitch’s security settings', (
    tester,
  ) async {
    final opened = <Uri>[];
    final previous = LinkRouter.launcher;
    LinkRouter.launcher = (url, {mode = LaunchMode.platformDefault}) async {
      opened.add(url);
      return true;
    };
    addTearDown(() => LinkRouter.launcher = previous);
    await pump(
      tester,
      const ChatRestriction(ChatRestrictionKind.verifiedEmail),
    );
    expect(find.text('Verified email required'), findsOneWidget);
    await tester.tap(find.text('Verified email required'));
    await tester.pump();
    expect(opened, [Uri.parse(kTwitchSecuritySettingsUrl)]);
  });

  testWidgets('an account refusal without a fix just says why', (tester) async {
    await pump(
      tester,
      const ChatRestriction(ChatRestrictionKind.phoneAliasBanned),
    );
    expect(find.text('Phone banned here'), findsOneWidget);
    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('the verify bar is tappable over 48 dp, drawn in 28', (
    tester,
  ) async {
    final opened = <Uri>[];
    final previous = LinkRouter.launcher;
    LinkRouter.launcher = (url, {mode = LaunchMode.platformDefault}) async {
      opened.add(url);
      return true;
    };
    addTearDown(() => LinkRouter.launcher = previous);
    const restriction = ChatRestriction(ChatRestrictionKind.verifiedPhone);
    await pump(tester, restriction);
    final bar = tester.getRect(find.byType(ChatRestrictionBar));
    expect(bar.height, 48);
    expect(restriction.barHeight, 48);
    final line = tester.getRect(find.byKey(ChatRestrictionBar.lineKey));
    expect(line.height, kRestrictionBarHeight);
    await tester.tapAt(bar.topCenter + const Offset(0, 4));
    await tester.pump();
    expect(opened, hasLength(1));
  });

  testWidgets('a warning bar asks to acknowledge on a tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatRestrictionBar(
            restriction: const ChatRestriction(ChatRestrictionKind.warned),
            onAcknowledge: () => taps++,
          ),
        ),
      ),
    );
    expect(find.text('Warning received'), findsOneWidget);
    await tester.tap(find.byKey(ChatRestrictionBar.lineKey));
    expect(taps, 1);
  });

  testWidgets('without a way to acknowledge, the warning only says so', (
    tester,
  ) async {
    await pump(tester, const ChatRestriction(ChatRestrictionKind.warned));
    expect(find.text('Warning received'), findsOneWidget);
    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('the warning dialog answers true only on Acknowledge', (
    tester,
  ) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answer = await showDialog<bool>(
              context: context,
              builder: (_) => const ChatWarningDialog(),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Acknowledge the warning?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ChatWarningDialog.acknowledgeKey));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });
}
