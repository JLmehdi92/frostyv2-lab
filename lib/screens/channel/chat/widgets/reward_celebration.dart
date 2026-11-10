import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/legendary_collection.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

class ParticleBurst extends StatelessWidget {
  const ParticleBurst({
    super.key,
    required this.progress,
    required this.color,
    this.count = 14,
    this.seed = 7,
  });

  final double progress;
  final Color color;
  final int count;
  final int seed;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _BurstPainter(
        progress: progress,
        color: color,
        count: count,
        seed: seed,
      ),
    ),
  );
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.progress,
    required this.color,
    required this.count,
    required this.seed,
  });

  final double progress;
  final Color color;
  final int count;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final random = math.Random(seed);
    final center = size.center(Offset.zero);
    final reach = size.shortestSide / 2;
    final travel = Curves.easeOutCubic.transform(progress);
    final fade = 1 - Curves.easeIn.transform(progress);
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * math.pi * 2 + random.nextDouble() * 0.5;
      final distance = reach * (0.55 + random.nextDouble() * 0.45) * travel;
      final radius = (1.6 + random.nextDouble() * 2.2) * (1 - progress * 0.5);
      final tint = i.isEven ? color : Colors.white;
      paint.color = tint.withValues(
        alpha: fade * (0.6 + random.nextDouble() * 0.4),
      );
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * distance,
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.progress != progress || old.color != color;
}

const _spring = SpringDescription(mass: 1, stiffness: 260, damping: 18);

class PointsBurst extends StatefulWidget {
  const PointsBurst({super.key, required this.points, this.onDone});

  final int points;
  final VoidCallback? onDone;

  static const burstKey = ValueKey('points-burst');

  @override
  State<PointsBurst> createState() => _PointsBurstState();
}

class _PointsBurstState extends State<PointsBurst>
    with TickerProviderStateMixin {
  late final _pop = AnimationController.unbounded(vsync: this);
  late final _life = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _pop.value = 1;
        _life.value = 0.5;
        Future<void>.delayed(const Duration(milliseconds: 900), _finish);
        return;
      }
      _pop.animateWith(SpringSimulation(_spring, 0, 1, 0));
      _life.forward().whenComplete(_finish);
    });
  }

  void _finish() {
    if (mounted) widget.onDone?.call();
  }

  @override
  void dispose() {
    _pop.dispose();
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = OnsetTokens.accent;
    final label = '+${widget.points}';
    return Semantics(
      liveRegion: true,
      label: context.l10n.pointsBonusCollected(points: '${widget.points}'),
      excludeSemantics: true,
      child: AnimatedBuilder(
        key: PointsBurst.burstKey,
        animation: Listenable.merge([_pop, _life]),
        builder: (context, child) {
          final t = _life.value;
          final rise = Curves.easeOutCubic.transform(t) * -18;
          final fade = t < 0.75 ? 1.0 : 1 - (t - 0.75) / 0.25;
          return SizedBox(
            width: 120,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: ParticleBurst(
                    progress: (t * 1.4).clamp(0, 1),
                    color: accent,
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, rise),
                  child: Opacity(
                    opacity: fade.clamp(0, 1),
                    child: Transform.scale(
                      scale: _pop.value.clamp(0, 1.4),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: accent,
            shape: const StadiumBorder(),
            shadows: [
              BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 16),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: OnsetTokens.displayFamily,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: OnsetTokens.backgroundDark,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChestRevealSheet extends StatefulWidget {
  const ChestRevealSheet({super.key, required this.revealed});

  final List<LegendaryEmote> revealed;

  static const doneKey = ValueKey('chest-reveal-done');

  @override
  State<ChestRevealSheet> createState() => _ChestRevealSheetState();
}

class _ChestRevealSheetState extends State<ChestRevealSheet>
    with SingleTickerProviderStateMixin {
  late final _intro = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 900 + widget.revealed.length * 90),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _intro.value = 1;
      } else {
        _intro.forward();
      }
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  double _entry(int index) {
    final count = widget.revealed.length;
    final start = count <= 1 ? 0.0 : (index / count) * 0.45;
    final local = ((_intro.value - start) / 0.55).clamp(0.0, 1.0);
    return Curves.elasticOut.transform(local);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    final revealed = widget.revealed;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 150,
              child: AnimatedBuilder(
                animation: _intro,
                builder: (context, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: ParticleBurst(
                        progress: _intro.value,
                        color: OnsetTokens.accent,
                        count: 28,
                      ),
                    ),
                    if (revealed.isEmpty)
                      Opacity(
                        opacity: _intro.value.clamp(0, 1),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 56,
                          color: colors.secondary,
                        ),
                      )
                    else
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final (index, emote) in revealed.indexed)
                            Transform.scale(
                              scale: _entry(index),
                              child: _RevealedEmote(emote: emote),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(
                l.hypeChestRevealTitle(count: revealed.length),
                textAlign: TextAlign.center,
                style: SheetText.title.copyWith(color: colors.text),
              ),
            ),
            if (revealed.isEmpty) ...[
              const SizedBox(height: 6),
              Text(
                l.hypeChestRevealEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: OnsetTokens.bodyFamily,
                  fontSize: 13,
                  height: 1.45,
                  color: colors.secondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SheetButton(
              key: ChestRevealSheet.doneKey,
              label: l.hypeChestRevealDone,
              large: true,
              expand: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealedEmote extends StatelessWidget {
  const _RevealedEmote({required this.emote});

  final LegendaryEmote emote;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return Semantics(
      label: emote.token,
      child: Container(
        width: 64,
        height: 64,
        padding: const EdgeInsets.all(8),
        decoration: ShapeDecoration(
          color: colors.well,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: OnsetTokens.accent.withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
        ),
        child: OnsetCachedNetworkImage(imageUrl: emote.imageUrl),
      ),
    );
  }
}
