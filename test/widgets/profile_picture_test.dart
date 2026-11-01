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

  testWidgets('a known picture shows from the first frame, decoded as '
      'before', (tester) async {
    when(() => api.getUser(userLogin: 'known_one')).thenAnswer(
      (_) async => const UserTwitch(
        '1',
        'known_one',
        'Known',
        'https://example.com/known.png',
      ),
    );
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
