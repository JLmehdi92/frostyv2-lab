import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/user.dart';
import 'package:onset/widgets/profile_picture.dart';
import 'package:provider/provider.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

/// Rebuilds its picture on demand, as any parent does (a store changing, the
/// controls of the video showing).
class _Rebuilder extends StatefulWidget {
  const _Rebuilder({required this.login, super.key});

  final String login;

  @override
  State<_Rebuilder> createState() => _RebuilderState();
}

class _RebuilderState extends State<_Rebuilder> {
  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) =>
      Center(child: ProfilePicture(userLogin: widget.login));
}

void main() {
  late MockTwitchApi api;
  final key = GlobalKey<_RebuilderState>();

  setUp(() => api = MockTwitchApi());

  Future<void> pump(WidgetTester tester, String login) async {
    tester.view
      ..physicalSize = const Size(400, 400)
      ..devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<TwitchApi>.value(
        value: api,
        child: MaterialApp(
          home: _Rebuilder(key: key, login: login),
        ),
      ),
    );
  }

  UserTwitch user(String login) =>
      UserTwitch('1', login, login, 'https://example.com/$login.png');

  testWidgets('a parent rebuilding does not ask Twitch again after a failure', (
    tester,
  ) async {
    when(
      () => api.getUser(userLogin: 'offline_one'),
    ).thenAnswer((_) => Future.error(Exception('offline')));
    await pump(tester, 'offline_one');
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      key.currentState!.rebuild();
      await tester.pump();
    }
    // Before: one request per build of the parent.
    verify(() => api.getUser(userLogin: 'offline_one')).called(1);
  });

  testWidgets('a failed lookup is tried again after a delay and the picture '
      'comes back', (tester) async {
    var calls = 0;
    when(() => api.getUser(userLogin: 'flaky_one')).thenAnswer((_) {
      calls++;
      if (calls == 1) return Future.error(Exception('network blip'));
      return Future.value(user('flaky_one'));
    });
    await pump(tester, 'flaky_one');
    await tester.pump();
    expect(find.byType(CachedNetworkImage), findsNothing);

    await tester.pump(ProfilePicture.retryDelays.first);
    await tester.pump();
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('a lookup that keeps failing is tried a bounded number of '
      'times, then again when the app comes back to the front', (tester) async {
    var calls = 0;
    var online = false;
    when(() => api.getUser(userLogin: 'down_one')).thenAnswer((_) {
      calls++;
      return online
          ? Future.value(user('down_one'))
          : Future.error(Exception('offline'));
    });
    await pump(tester, 'down_one');
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(minutes: 1));
    }
    expect(calls, 1 + ProfilePicture.retryDelays.length);

    online = true;
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(calls, 2 + ProfilePicture.retryDelays.length);
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('a known picture shows from the first frame, decoded as '
      'before', (tester) async {
    when(
      () => api.getUser(userLogin: 'known_one'),
    ).thenAnswer((_) async => user('known_one'));
    // The first picture asks Twitch once.
    await pump(tester, 'known_one');
    await tester.pump();
    expect(find.byType(CachedNetworkImage), findsOneWidget);

    // Another one of the same login, later: no placeholder frame, no
    // request, and no rebuild waiting on a future.
    await tester.pumpWidget(const SizedBox());
    await pump(tester, 'known_one');
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    verify(() => api.getUser(userLogin: 'known_one')).called(1);

    // One decoded copy serves every size the avatar is drawn at: a decode
    // per size would fade the picture in (500 ms) the first time it shows
    // at a new size.
    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.memCacheWidth, isNull);
    expect(image.memCacheHeight, isNull);
  });
}
