import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/services/background_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('frosty/background-audio-test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late BackgroundAudio audio;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    audio = BackgroundAudio(channel: channel, supported: true);
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> command(String action) => messenger.handlePlatformMessage(
    channel.name,
    channel.codec.encodeMethodCall(MethodCall('command', {'action': action})),
    (_) {},
  );

  test('shows, updates and hides the media notification', () async {
    final owner = Object();
    await audio.show(
      owner: owner,
      title: 'Streamer',
      subtitle: 'Endgames',
      playing: true,
      onCommand: (_) {},
    );
    await audio.show(
      owner: owner,
      title: 'Streamer',
      subtitle: 'Endgames',
      playing: false,
      onCommand: (_) {},
    );
    await audio.hide(owner);

    expect(calls.map((c) => c.method), ['show', 'show', 'hide']);
    expect(calls.first.arguments, {
      'title': 'Streamer',
      'subtitle': 'Endgames',
      'playing': true,
    });
    expect((calls[1].arguments as Map)['playing'], isFalse);
  });

  test('says whether a stream plays with the notification up', () async {
    final owner = Object();
    expect(audio.playing, isFalse);
    await audio.show(
      owner: owner,
      title: 'Streamer',
      subtitle: '',
      playing: true,
      onCommand: (_) {},
    );
    expect(audio.playing, isTrue);
    await audio.show(
      owner: owner,
      title: 'Streamer',
      subtitle: '',
      playing: false,
      onCommand: (_) {},
    );
    expect(audio.playing, isFalse);
    await audio.show(
      owner: owner,
      title: 'Streamer',
      subtitle: '',
      playing: true,
      onCommand: (_) {},
    );
    await audio.hide(owner);
    expect(audio.playing, isFalse);
  });

  test('media buttons reach the player showing it', () async {
    final commands = <MediaCommand>[];
    await audio.show(
      owner: Object(),
      title: 'Streamer',
      subtitle: '',
      playing: true,
      onCommand: commands.add,
    );

    await command('pause');
    await command('play');
    await command('stop');
    await command('rewind');

    expect(commands, [
      MediaCommand.pause,
      MediaCommand.play,
      MediaCommand.stop,
    ]);
  });

  test('a player that no longer shows it cannot change or hide it', () async {
    final first = Object();
    final second = Object();
    final firstCommands = <MediaCommand>[];
    await audio.show(
      owner: first,
      title: 'A',
      subtitle: '',
      playing: true,
      onCommand: firstCommands.add,
    );
    await audio.show(
      owner: second,
      title: 'B',
      subtitle: '',
      playing: true,
      onCommand: (_) {},
    );
    calls.clear();

    await audio.hide(first);
    await command('pause');

    expect(calls, isEmpty);
    expect(firstCommands, isEmpty);
  });

  test('a platform without it is left alone', () async {
    audio = BackgroundAudio(channel: channel, supported: false);
    final owner = Object();
    await audio.show(
      owner: owner,
      title: 'A',
      subtitle: '',
      playing: true,
      onCommand: (_) {},
    );
    await audio.hide(owner);

    expect(calls, isEmpty);
  });

  test('a native failure is not thrown at the player', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'denied'),
    );
    final owner = Object();

    await audio.show(
      owner: owner,
      title: 'A',
      subtitle: '',
      playing: true,
      onCommand: (_) {},
    );
    await audio.hide(owner);
  });

  test('a show the system refused is sent again on resume', () async {
    var refuse = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (refuse) throw PlatformException(code: 'start_failed');
      return null;
    });
    final owner = Object();
    await audio.show(
      owner: owner,
      title: 'A',
      subtitle: '',
      playing: true,
      onCommand: (_) {},
    );

    refuse = false;
    await audio.retryShow();
    await audio.retryShow();

    expect(calls.map((c) => c.method), ['show', 'show']);
  });

  test('nothing is sent again once shown or hidden', () async {
    final owner = Object();
    await audio.show(
      owner: owner,
      title: 'A',
      subtitle: '',
      playing: true,
      onCommand: (_) {},
    );
    await audio.retryShow();
    await audio.hide(owner);
    await audio.retryShow();

    expect(calls.map((c) => c.method), ['show', 'hide']);
  });
}
