import 'package:flutter/widgets.dart';
import 'package:onset/theme.dart';

/// The signal-tinted pill of the gift bomb pin's "×N" and of the chat row's
/// "N recipients": [accent] at 12 % ringed by a
/// 0.5 dp line at 45 %.
ShapeDecoration signalPillDecoration(Color accent) => ShapeDecoration(
  color: accent.withValues(alpha: 0.12),
  shape: StadiumBorder(
    side: BorderSide(
      color: accent.withValues(alpha: 0.45),
      width: OnsetTokens.hairlineWidth,
    ),
  ),
);
