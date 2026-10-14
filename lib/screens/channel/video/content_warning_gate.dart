import 'package:flutter/material.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/utils/content_labels.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:provider/provider.dart';

/// Channels whose content warning the viewer accepted this session, so
/// re-entering a channel does not ask again. Kept until the app restarts,
/// like Twitch.
abstract final class AcceptedContentWarnings {
  static final _ids = <String>{};

  static bool has(String userId) => _ids.contains(userId);
  static void add(String userId) => _ids.add(userId);

  @visibleForTesting
  static void reset() => _ids.clear();
}

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
          _ContentWarning(
            displayName: widget.displayName,
            labels: _labels,
            onAccept: _accept,
          ),
      ],
    );
  }
}

class _ContentWarning extends StatelessWidget {
  const _ContentWarning({
    required this.displayName,
    required this.labels,
    required this.onAccept,
  });

  final String displayName;
  final List<String> labels;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    // Opaque and on top: it also swallows taps so the controls underneath
    // cannot be reached before accepting.
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  'Content intended for certain audiences',
                  textAlign: TextAlign.center,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$displayName has labeled this channel:\n'
                  '${labels.join(', ')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onAccept,
                  child: const Text('Start watching'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
