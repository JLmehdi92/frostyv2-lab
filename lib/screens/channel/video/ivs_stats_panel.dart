import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/channel/video/latency_stats.dart';
import 'package:frosty/screens/channel/video/stores/ivs_video_store.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';

/// Compact technical overlay for measuring the IVS player on a real device:
/// live latency with its rolling median / p90 / max, buffer, bitrate, frames,
/// quality, low-latency state, playback speed, startup time and rebuffers.
///
/// Shown above the video (outside the auto-hiding overlay) while
/// [IvsVideoStore.statsVisible] is true.
class IvsStatsPanel extends StatelessWidget {
  const IvsStatsPanel({super.key, required this.store});

  final IvsVideoStore store;

  @override
  Widget build(BuildContext context) {
    final textColor = context.frostyColors.overlayOnSurface;
    final style = TextStyle(
      color: textColor,
      fontSize: 11,
      height: 1.35,
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
      shadows: kOverlayShadow,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Observer(
            builder: (context) {
              final stats = store.stats;
              final sampler = store.latencySampler;
              final latencyMs = store.latencyMs;
              // The sampler itself is not observable; samplesVersion changes
              // on every sample and on reset.
              store.samplesVersion;

              String ms(int? v) => v == null ? '—' : formatLatency(v);

              final rows = <(String, String)>[
                ('Latency', latencyMs == null ? '—' : formatLatency(latencyMs)),
                (
                  'Med / p90 / max',
                  '${ms(sampler.median)} / ${ms(sampler.p90)} / '
                      '${ms(sampler.max)} (${sampler.count})',
                ),
                ('Buffer', ms(stats?.bufferedMs)),
                (
                  'Bitrate',
                  '${formatBitrate(stats?.bitrate)} · '
                      'net ${formatBitrate(stats?.bandwidth)}',
                ),
                (
                  'Frames',
                  '${stats?.fps ?? '—'} fps · '
                      '${stats?.droppedFrames ?? '—'} dropped / '
                      '${stats?.decodedFrames ?? '—'}',
                ),
                (
                  'Quality',
                  [
                    stats?.qualityName ?? store.streamQuality,
                    ?stats?.resolution,
                    ?stats?.codecs,
                  ].join(' · '),
                ),
                (
                  'Low latency',
                  switch (stats?.lowLatency) {
                    true => 'on',
                    false => 'off',
                    null => '—',
                  },
                ),
                (
                  'Speed',
                  switch (stats?.playbackRate) {
                    final rate? => '${rate.toStringAsFixed(2)}x',
                    null => '—',
                  },
                ),
                ('Startup', ms(store.startupMs)),
                ('Rebuffers', '${store.rebufferCount}'),
              ];

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (label, value) in rows)
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$label  ',
                            style: style.copyWith(
                              color: textColor.withValues(alpha: 0.7),
                            ),
                          ),
                          TextSpan(text: value),
                        ],
                      ),
                      style: style,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
