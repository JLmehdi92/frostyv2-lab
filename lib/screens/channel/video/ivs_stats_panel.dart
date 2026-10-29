import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/screens/channel/video/latency_stats.dart';
import 'package:onset/screens/channel/video/overlay_common.dart';
import 'package:onset/screens/channel/video/stores/ivs_video_store.dart';
import 'package:onset/theme.dart';

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
    // Board ChaineLecteur: light on black 60 %, 10.5 sp tabular figures,
    // the labels at 66 %.
    const textColor = OnsetTokens.textPrimaryDark;
    const style = TextStyle(
      color: textColor,
      fontSize: 10.5,
      height: 1.33,
      fontWeight: FontWeight.w500,
      fontFeatures: [FontFeature.tabularFigures()],
      shadows: kPlayerChromeShadow,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(OnsetTokens.radiusSmall),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: OnsetTokens.hairlineWidth,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                ('Mode', store.playerConfig.label),
                ('Startup', ms(store.startupMs)),
                ('Rebuffers', '${store.rebufferCount}'),
                ('Jumps to live', '${store.liveJumps}'),
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
                              color: textColor.withValues(alpha: 0.66),
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
