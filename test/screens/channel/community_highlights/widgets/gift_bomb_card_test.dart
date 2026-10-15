import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/chat/gift_bomb_tracker.dart';
import 'package:frosty/screens/channel/community_highlights/widgets/highlight_cards.dart';
import 'package:frosty/theme.dart';

final _start = DateTime.utc(2026, 10, 13, 20);

GiftBombBanner _banner({int count = 5, String gifter = 'BigGifter'}) =>
    GiftBombBanner(
      bomb: GiftBomb(
        key: 'bomb',
        gifterName: gifter,
        isAnonymous: false,
        count: count,
        tier: 'Tier 1',
      ),
      startedAt: _start,
      endsAt: _start.add(const Duration(seconds: 10)),
    );

void main() {
  var dismissed = 0;

  setUp(() => dismissed = 0);

  Future<void> pump(
    WidgetTester tester,
    GiftBombBanner banner, {
    bool reduceMotion = false,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: const FrostyThemes(colorSchemeSeed: FrostyTokens.accent).dark,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              child: GiftBombCard(
                banner: banner,
                card: HighlightCardContext(
                  expanded: false,
                  onToggle: () {},
                  onDismiss: () => dismissed++,
                  now: () => _start,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  double barValue(WidgetTester tester) => tester
      .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
      .value!;

  testWidgets('says who is gifting how many, the name in bold', (tester) async {
    await pump(tester, _banner());

    final title = find.textContaining(
      'BigGifter is gifting 5 Subscriptions!',
      findRichText: true,
    );
    expect(title, findsOneWidget);
    final spans = <TextSpan>[];
    tester.widget<RichText>(title).text.visitChildren((span) {
      if (span is TextSpan) spans.add(span);
      return true;
    });
    final name = spans.firstWhere((s) => s.text == 'BigGifter');
    expect(name.style!.fontWeight, FontWeight.w700);
    expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget);
  });

  testWidgets('a single gift is one Subscription', (tester) async {
    await pump(tester, _banner(count: 1));

    expect(
      find.textContaining('is gifting 1 Subscription!', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('the close button dismisses it', (tester) async {
    await pump(tester, _banner());

    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(dismissed, 1);
  });

  testWidgets('a 3dp green bar drains with the time left', (tester) async {
    await pump(tester, _banner());

    final bar = find.byType(LinearProgressIndicator);
    expect(tester.getSize(bar).height, 3);
    expect(
      tester.widget<LinearProgressIndicator>(bar).color,
      const Color(0xFF12A87A),
    );
    expect(barValue(tester), 1);

    await tester.pump(const Duration(milliseconds: 2500));
    expect(barValue(tester), closeTo(0.75, 0.01));

    await tester.pump(const Duration(milliseconds: 7500));
    expect(barValue(tester), 0);
  });

  testWidgets('with reduced motion the bar steps a second at a time', (
    tester,
  ) async {
    await pump(tester, _banner(), reduceMotion: true);

    await tester.pump(const Duration(milliseconds: 2500));
    expect(barValue(tester), closeTo(0.8, 1e-9));

    await tester.pump(const Duration(milliseconds: 400));
    expect(barValue(tester), closeTo(0.8, 1e-9));

    await tester.pump(const Duration(milliseconds: 200));
    expect(barValue(tester), closeTo(0.7, 1e-9));
  });

  testWidgets('a banner shown late starts part-drained', (tester) async {
    await pump(
      tester,
      GiftBombBanner(
        bomb: _banner().bomb,
        startedAt: _start.subtract(const Duration(seconds: 4)),
        endsAt: _start.add(const Duration(seconds: 6)),
      ),
    );

    expect(barValue(tester), closeTo(0.6, 1e-9));
  });
}
