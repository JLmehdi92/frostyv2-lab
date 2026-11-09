import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/playback_access_token.dart';
import 'package:onset/screens/channel/channel_info.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/motion/press_scale.dart';

class FreePreviewController extends ChangeNotifier {
  FreePreviewController({
    required this.endsAt,
    DateTime Function()? clock,
    this.onExpired,
  }) : _clock = clock ?? DateTime.now {
    _tick();
    if (!_expired) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  final DateTime endsAt;
  final DateTime Function() _clock;
  final VoidCallback? onExpired;
  Timer? _ticker;
  var _expired = false;
  var _bannerDismissed = false;
  SubscriberTier _tier = SubscriberTier.any;

  bool get expired => _expired;
  bool get bannerVisible => !_expired && !_bannerDismissed;
  SubscriberTier get tier => _tier;

  Duration get remaining {
    final left = endsAt.difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  set tier(SubscriberTier value) {
    if (value == _tier) return;
    _tier = value;
    notifyListeners();
  }

  void dismissBanner() {
    _bannerDismissed = true;
    notifyListeners();
  }

  void expire() {
    if (_expired) return;
    _expired = true;
    _ticker?.cancel();
    notifyListeners();
    onExpired?.call();
  }

  void _tick() {
    if (remaining == Duration.zero) {
      expire();
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

String formatPreviewRemaining(Duration remaining) {
  final minutes = remaining.inMinutes;
  final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class FreePreviewLayer extends StatelessWidget {
  const FreePreviewLayer({
    super.key,
    required this.controller,
    required this.name,
    required this.login,
    required this.onUseWebPlayer,
  });

  static const bannerKey = ValueKey('free-preview-banner');
  static const endedKey = ValueKey('free-preview-ended');
  static const webPlayerKey = ValueKey('free-preview-web-player');

  final FreePreviewController controller;
  final String name;
  final String login;
  final VoidCallback onUseWebPlayer;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (controller.expired) {
        return _FreePreviewEnded(
          key: endedKey,
          name: name,
          login: login,
          tier: controller.tier,
          onUseWebPlayer: onUseWebPlayer,
        );
      }
      return Align(
        alignment: Alignment.topLeft,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          child: controller.bannerVisible
              ? _FreePreviewBanner(
                  key: bannerKey,
                  name: name,
                  login: login,
                  tier: controller.tier,
                  remaining: controller.remaining,
                  onDismiss: controller.dismissBanner,
                )
              : const SizedBox.shrink(),
        ),
      );
    },
  );
}

String _streamingFor(AppLocalizations l, SubscriberTier tier, String name) =>
    switch (tier) {
      SubscriberTier.any => l.freePreviewTitle(name: name),
      SubscriberTier.tier2 => l.freePreviewTitleTier2(name: name),
      SubscriberTier.tier3 => l.freePreviewTitleTier3(name: name),
    };

class _FreePreviewBanner extends StatelessWidget {
  const _FreePreviewBanner({
    super.key,
    required this.name,
    required this.login,
    required this.tier,
    required this.remaining,
    required this.onDismiss,
  });

  final String name;
  final String login;
  final SubscriberTier tier;
  final Duration remaining;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 44, 10, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE6141414),
            borderRadius: BorderRadius.circular(OnsetTokens.radiusCard),
            border: Border.all(
              color: OnsetTokens.hairlineDark,
              width: OnsetTokens.hairlineWidth,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _streamingFor(l, tier, name),
                        style: const TextStyle(
                          fontFamily: OnsetTokens.bodyFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: OnsetTokens.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.freePreviewRemaining(
                          time: formatPreviewRemaining(remaining),
                        ),
                        style: const TextStyle(
                          fontFamily: OnsetTokens.bodyFamily,
                          fontSize: 12,
                          color: OnsetTokens.accent,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (tier == SubscriberTier.any) ...[
                        const SizedBox(height: 8),
                        SubscribeButton(login: login, name: name, height: 32),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.freePreviewHide,
                  onPressed: onDismiss,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: OnsetTokens.textPrimaryDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FreePreviewEnded extends StatelessWidget {
  const _FreePreviewEnded({
    super.key,
    required this.name,
    required this.login,
    required this.tier,
    required this.onUseWebPlayer,
  });

  final String name;
  final String login;
  final SubscriberTier tier;
  final VoidCallback onUseWebPlayer;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ColoredBox(
      color: OnsetTokens.backgroundDark,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.freePreviewEndedTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: OnsetTokens.displayFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: OnsetTokens.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _streamingFor(l, tier, name),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 13,
                    color: Color(0xB3F5F5F5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.freePreviewEndedBody(name: name),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 13,
                    color: Color(0xB3F5F5F5),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SubscribeButton(login: login, name: name),
                    PressScale(
                      child: TextButton(
                        key: FreePreviewLayer.webPlayerKey,
                        onPressed: onUseWebPlayer,
                        style: TextButton.styleFrom(
                          foregroundColor: OnsetTokens.textPrimaryDark,
                          minimumSize: const Size(0, 40),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(l.freePreviewWebPlayer),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
