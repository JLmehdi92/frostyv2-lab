import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/recap.dart';
import 'package:onset/models/report.dart';
import 'package:onset/screens/clips/clip_story_screen.dart';
import 'package:onset/screens/vod/widgets/video_back_button.dart';
import 'package:onset/screens/vod/widgets/video_glyph.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/utils/twitch_report.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/report/report_sheet.dart';

class RecapScreen extends StatefulWidget {
  const RecapScreen({
    super.key,
    required this.recap,
    this.refresh,
    @visibleForTesting this.playerFactory,
  });

  static const routeName = 'RecapScreen';
  static const reportKey = ValueKey('recap-report');
  static const unavailableKey = ValueKey('recap-unavailable');

  final Recap recap;
  final Future<Recap> Function(String id)? refresh;
  final ClipStoryPlayerFactory? playerFactory;

  static Future<void> open(BuildContext context, {required Recap recap}) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: routeName),
          builder: (context) => RecapScreen(
            recap: recap,
            refresh: context.twitchClipService.getRecap,
          ),
        ),
      );

  @override
  State<RecapScreen> createState() => _RecapScreenState();
}

enum _RecapState { checking, playing, unavailable }

class _RecapScreenState extends State<RecapScreen> {
  late Recap _recap = widget.recap;
  var _state = _RecapState.checking;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    final refresh = widget.refresh;
    if (refresh == null) {
      setState(() => _state = _RecapState.playing);
      return;
    }
    try {
      final fresh = await refresh(widget.recap.id);
      if (!mounted) return;
      setState(() {
        _recap = fresh;
        _state = _RecapState.playing;
      });
    } on RecapUnavailableException {
      if (mounted) setState(() => _state = _RecapState.unavailable);
    } catch (e) {
      debugPrint('RecapScreen refresh failed: $e');
      if (mounted) setState(() => _state = _RecapState.playing);
    }
  }

  void _report() {
    final url = twitchReportUri(_recap.channelLogin);
    if (url == null) return;
    unawaited(
      reportFromOnset(
        context,
        target: ReportTarget.channel(
          channelId: _recap.channelId,
          name: _recap.channelDisplayName,
        ),
        title: context.l10n.recapReport,
        fallbackUrl: url,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    switch (_state) {
      case _RecapState.playing:
        return ClipStoryScreen(
          clips: _recap.clips,
          title: _recap.channelDisplayName,
          subtitle: _recap.title.isEmpty ? l.recapUntitled : _recap.title,
          playerFactory: widget.playerFactory,
          actions: [
            if (twitchReportUri(_recap.channelLogin) != null)
              Tooltip(
                message: l.recapReport,
                child: PressScale(
                  child: IconButton(
                    key: RecapScreen.reportKey,
                    onPressed: _report,
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    icon: const VideoGlyph(
                      VideoGlyphKind.alert,
                      color: Colors.white,
                      shadow: true,
                    ),
                  ),
                ),
              ),
          ],
        );
      case _RecapState.checking:
      case _RecapState.unavailable:
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: VideoBackButtonLayer(
                child: Center(
                  child: _state == _RecapState.checking
                      ? const SizedBox.square(
                          dimension: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Padding(
                          key: RecapScreen.unavailableKey,
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            l.recapUnavailable,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: OnsetTokens.bodyFamily,
                              fontSize: 15,
                              height: 1.4,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
    }
  }
}
