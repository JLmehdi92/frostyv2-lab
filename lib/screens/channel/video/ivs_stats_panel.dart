import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/video/latency_controller.dart';
import 'package:onset/screens/channel/video/latency_stats.dart';
import 'package:onset/screens/channel/video/overlay_common.dart';
import 'package:onset/screens/channel/video/stores/ivs_video_store.dart';
import 'package:onset/theme.dart';

/// Compact technical overlay for measuring the IVS player on a real device:
/// live latency with its rolling median / p90 / max, buffer, bitrate, frames,
/// quality, low-latency state, playback speed, what auto latency does (and
/// an active Ultra fallback), startup time and rebuffers.
///
/// Shown above the video (outside the auto-hiding overlay) while
/// [IvsVideoStore.statsVisible] is true.
class IvsStatsPanel extends StatelessWidget {
  const IvsStatsPanel({super.key, required this.store});

  final IvsVideoStore store;

  @override
  Widget build(BuildContext context) {
    // Light on black 60 %, 10.5 sp tabular figures,
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

              final l = context.l10n;
              String ms(int? v) =>
                  v == null ? '—' : displayLatency(formatLatency(v), l);

              final rows = <(String, String)>[
                (l.latencyStatsLatency, ms(latencyMs)),
                (
                  l.latencyStatsSpread,
                  '${ms(sampler.median)} / ${ms(sampler.p90)} / '
                      '${ms(sampler.max)} (${sampler.count})',
                ),
                (l.latencyStatsBuffer, ms(stats?.bufferedMs)),
                (
                  l.latencyStatsBitrate,
                  l.latencyStatsBitrateValue(
                    bitrate: formatBitrate(stats?.bitrate, l),
                    network: formatBitrate(stats?.bandwidth, l),
                  ),
                ),
                (
                  l.latencyStatsFrames,
                  l.latencyStatsFramesValue(
                    fps: '${stats?.fps ?? '—'}',
                    dropped: '${stats?.droppedFrames ?? '—'}',
                    decoded: '${stats?.decodedFrames ?? '—'}',
                  ),
                ),
                (
                  l.playerQuality,
                  [
                    stats?.qualityName ?? store.streamQuality,
                    ?stats?.resolution,
                    ?stats?.codecs,
                  ].join(' · '),
                ),
                (
                  l.latencyStatsLowLatency,
                  switch (stats?.lowLatency) {
                    true => l.latencyStatsOn,
                    false => l.latencyStatsOff,
                    null => '—',
                  },
                ),
                (
                  l.latencyStatsSpeed,
                  switch (stats?.playbackRate) {
                    final rate? => l.latencyStatsRate(
                      rate: localDecimal(rate.toStringAsFixed(2)),
                    ),
                    null => '—',
                  },
                ),
                (l.latencyStatsMode, store.playerConfig.label(l)),
                (
                  l.latencyStatsAutoLatency,
                  describeAutoLatency(store.autoLatencyStatus, l),
                ),
                if (describeBufferFallback(store.bufferFallbackUntil, l)
                    case final fallback?)
                  (l.latencyStatsNextStreams, fallback),
                (l.latencyStatsStartup, ms(store.startupMs)),
                (l.latencyStatsRebuffers, '${store.rebufferCount}'),
                (l.latencyStatsLiveJumps, '${store.liveJumps}'),
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
