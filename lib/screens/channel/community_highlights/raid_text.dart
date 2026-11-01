import 'dart:math' as math;

import 'package:onset/l10n/l10n.dart';

/// A raid's viewer count as a number never below zero (the raid cards'
/// counts, and what chooses their words' plural).
int raidViewerCount(int count) => math.max(0, count);

/// "1,204 viewers", in [l]'s language.
String raidViewers(int count, AppLocalizations l) =>
    l.raidViewers(count: raidViewerCount(count));
