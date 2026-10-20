import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/vod/stores/up_next_store.dart';

/// The official app's Up Next card over the ended video: a bar filling over
/// the countdown, "Up Next N seconds" and Cancel, the next video's title and
/// channel, and a button that plays it now. Without autoplay it waits for
/// the viewer, without a countdown.
class UpNextOverlay extends StatelessWidget {
  const UpNextOverlay({super.key, required this.store});

  final UpNextStore store;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final phase = store.phase;
        final next = store.next;
        final counting = phase == UpNextPhase.countdown;
        if (next == null || (!counting && phase != UpNextPhase.waiting)) {
          return const SizedBox.shrink();
        }
        final accent = Theme.of(context).colorScheme.primary;
        final seconds = store.secondsLeft;
        const total = UpNextStoreBase.countdownSeconds;
        final channel = next.ownerDisplayName.isNotEmpty
            ? next.ownerDisplayName
            : next.ownerLogin;
        final title = next.title.trim().isEmpty ? 'Untitled' : next.title;
        const white = TextStyle(color: Colors.white);

        return Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.75),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (counting)
                      TweenAnimationBuilder<double>(
                        // Fills smoothly between the one-second ticks.
                        tween: Tween(end: (total - seconds + 1) / total),
                        duration: const Duration(seconds: 1),
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value.clamp(0.0, 1.0),
                          minHeight: 3,
                          color: accent,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: 'Up Next',
                              children: [
                                if (counting)
                                  TextSpan(
                                    text:
                                        ' $seconds '
                                        '${seconds == 1 ? 'second' : 'seconds'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            style: white.copyWith(fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: store.cancel,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 48),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: white.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      store.similar ? '$channel · Similar video' : channel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: accent, fontSize: 13),
                    ),
                    Expanded(
                      child: Center(
                        child: IconButton.filled(
                          tooltip: 'Play now',
                          iconSize: 32,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white24,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: store.playNow,
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
