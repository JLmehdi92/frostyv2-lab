// Dev-only harness to verify the REAL NativeVideoStore on a device WITHOUT
// Twitch app credentials. Run with:
//   flutter run -t lib/dev_player_harness.dart
//
// It finds the first live channel in [_candidates] (via TwitchStreamService,
// which uses the public web client-id), then builds the actual NativeVideoStore
// + NativeVideo widget used by the app and shows its latency/quality. Stream
// info (twitchApi.getStream) will report offline without credentials — that is
// expected and does not affect video playback.
//
// This file is not part of the shipped app.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_stream_service.dart';
import 'package:frosty/screens/channel/video/native_video.dart';
import 'package:frosty/screens/channel/video/stores/native_video_store.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:media_kit/media_kit.dart';

const _candidates = [
  'kaicenat',
  'xqc',
  'jynxzi',
  'caedrel',
  'zackrawrr',
  'hasanabi',
  'tarik',
  'jasontheween',
  'ludwig',
  'pokimane',
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const MaterialApp(home: _HarnessScreen()));
}

class _HarnessScreen extends StatefulWidget {
  const _HarnessScreen();

  @override
  State<_HarnessScreen> createState() => _HarnessScreenState();
}

class _HarnessScreenState extends State<_HarnessScreen> {
  final Dio _dio = Dio();
  NativeVideoStore? _store;
  String _status = 'Searching for a live channel...';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final probe = TwitchStreamService(Dio());
    for (final channel in _candidates) {
      try {
        final variants = await probe.getStreamVariants(userLogin: channel);
        if (variants.isEmpty) continue;
        final twitchApi = TwitchApi(_dio);
        setState(() {
          _status = 'Channel: $channel';
          _store = NativeVideoStore(
            userLogin: channel,
            userId: '',
            twitchApi: twitchApi,
            authStore: AuthStore(twitchApi: twitchApi),
            settingsStore: SettingsStore(),
          );
        });
        probe.close();
        return;
      } catch (_) {
        // Offline or blocked — try the next candidate.
      }
    }
    probe.close();
    setState(() => _status = 'No candidate channel is live right now.');
  }

  @override
  void dispose() {
    _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (store != null)
            Positioned.fill(child: NativeVideo(videoStore: store)),
          Positioned(
            top: 40,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black54,
              child: Observer(
                builder: (_) => Text(
                  '$_status\n'
                  'Store latency: ${store?.latency ?? '-'}\n'
                  'Quality: ${store?.streamQuality ?? '-'}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
