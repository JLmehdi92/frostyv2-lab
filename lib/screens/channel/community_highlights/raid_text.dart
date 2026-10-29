import 'dart:math' as math;

import 'package:intl/intl.dart';

/// A raid's viewer count as shown on the raid cards ("1,204"); never
/// below zero.
String formatRaidViewers(int count) =>
    NumberFormat.decimalPattern().format(math.max(0, count));

/// "viewer" or "viewers" for [count].
String raidViewerNoun(int count) => count == 1 ? 'viewer' : 'viewers';

/// "1,204 viewers".
String raidViewers(int count) =>
    '${formatRaidViewers(count)} ${raidViewerNoun(count)}';
