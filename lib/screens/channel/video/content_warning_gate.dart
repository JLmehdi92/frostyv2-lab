import 'package:flutter/material.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/screens/channel/video/player_glyph.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/content_labels.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:provider/provider.dart';

/// Channels whose content warning the viewer accepted this session, so
/// re-entering a channel, or opening one of its videos, does not ask again
/// (the official app shares its acceptances between live and VODs too).
/// Kept until the app restarts.
abstract final class AcceptedContentWarnings {
  static final _ids = <String>{};

  static bool has(String userId) => _ids.contains(userId);
  static void add(String userId) => _ids.add(userId);

  @visibleForTesting
  static void reset() => _ids.clear();
}

/// Whether the viewer already chose to watch [channelId]'s labelled content
/// (warnings turned off, or its warning accepted this session): only then
/// may Twitch's own warning in a web player be clicked for them.
bool contentWarningConsented({
  required bool warnMatureContent,
  required String channelId,
}) =>
    !warnMatureContent ||
    (channelId.isNotEmpty && AcceptedContentWarnings.has(channelId));

/// Covers [child] (the whole video, controls included) with Twitch's
/// mature-content warning until the viewer accepts, when the channel carries
/// content classification labels and the setting is on. Fetches the labels
/// itself (any engine) and fails open (no warning) so a hiccup never blocks
/// playback.
///
/// While the warning shows it calls [onActiveChanged] so the channel can
/// pause the player: the cover alone would hide the picture but still play
/// the audio.
class ContentWarningGate extends StatefulWidget {
  const ContentWarningGate({
    super.key,
    required this.userId,
    required this.displayName,
    required this.onActiveChanged,
    required this.child,
  });

  final String userId;
  final String displayName;

  /// Called with true when the warning starts covering the video and false
  /// when it is accepted (never called when there is nothing to warn about).
  final ValueChanged<bool> onActiveChanged;
  final Widget child;

  @override
  State<ContentWarningGate> createState() => _ContentWarningGateState();
}

class _ContentWarningGateState extends State<ContentWarningGate> {
  List<String> _labels = const [];
  var _resolved = false;

  @override
  void initState() {
    super.initState();
    if (!context.settingsStore.warnMatureContent ||
        AcceptedContentWarnings.has(widget.userId)) {
      _resolved = true;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    List<String> labels = const [];
    try {
      final channel = await context.read<TwitchApi>().getChannel(
        userId: widget.userId,
      );
      labels = contentLabelNames(channel.contentClassificationLabels);
    } catch (_) {
      // Fail open: a channel we cannot read is not blocked.
    }
    if (!mounted) return;
    setState(() {
      _labels = labels;
      _resolved = true;
    });
    if (labels.isNotEmpty) widget.onActiveChanged(true);
  }

  void _accept() {
    AcceptedContentWarnings.add(widget.userId);
    setState(() => _labels = const []);
    widget.onActiveChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    final showWarning = _resolved && _labels.isNotEmpty;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // Last, so it sits above the player and its controls.
        if (showWarning)
          Positioned.fill(
            child: ContentWarningCover(
              displayName: widget.displayName,
              labels: _labels,
              onAccept: _accept,
            ),
          ),
      ],
    );
  }
}

/// Twitch's mature-content warning, opaque over a player (live or VOD):
/// worded like the official app's ("Just one second…"), with the labels,
/// "Start watching" and "Go back".
class ContentWarningCover extends StatelessWidget {
  const ContentWarningCover({
    super.key,
    required this.displayName,
    required this.labels,
    required this.onAccept,
  });

  final String displayName;

  /// Readable label names.
  final List<String> labels;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    // Opaque: over a player it also swallows taps so the controls
    // underneath cannot be reached before accepting (board ChaineLecteur:
    // the ground, not a scrim, with the player paused behind it).
    return SizedBox.expand(
      child: ColoredBox(
        color: FrostyTokens.backgroundDark,
        // A portrait 16:9 player is short: the whole card shrinks to fit so
        // its buttons stay on screen (and tappable) instead of scrolling.
        child: LayoutBuilder(
          builder: (context, constraints) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: (constraints.maxWidth - 48).clamp(160.0, 480.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PlayerGlyph(
                      PlayerGlyphKind.eyeOff,
                      color: FrostyTokens.textPrimaryDark,
                      size: 30,
                      strokeWidth: 1.7,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Just one second…',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.16,
                        color: FrostyTokens.textPrimaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayName.isEmpty
                          ? 'This content is intended for certain audiences.'
                          : "$displayName's content is intended for certain "
                                'audiences.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: FrostyTokens.textBodyDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'It may contain: ${labels.join(', ')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: FrostyTokens.textSecondaryDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Side by side; one above the other on a very small player.
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: onAccept,
                          style: FilledButton.styleFrom(
                            backgroundColor: FrostyTokens.accent,
                            foregroundColor: FrostyTokens.backgroundDark,
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontFamily: FrostyTokens.bodyFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Start watching'),
                        ),
                        OutlinedButton(
                          onPressed: () => Navigator.maybePop(context),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: FrostyTokens.raisedDark,
                            foregroundColor: FrostyTokens.textPrimaryDark,
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            side: const BorderSide(
                              color: Color(0x24FFFFFF),
                              width: FrostyTokens.hairlineWidth,
                            ),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontFamily: FrostyTokens.bodyFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Go back'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
