import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';

enum NewFeature {
  dataSaver,
  streamPreviews,
  clipDiscovery,
  hideViewerCount,
  notInterested,
  landscapeAlerts,
  cast,
  floatingPlayer,
}

class NewFeaturePill extends StatelessWidget {
  const NewFeaturePill({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = context.onsetColors.live;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        context.l10n.newFeaturePill.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: OnsetTokens.backgroundDark,
          height: 1.2,
        ),
      ),
    );
  }
}
