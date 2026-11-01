import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/community_highlights.dart';

/// Whole percentages of [counts] that add up to exactly 100 (largest
/// remainder); all 0 when nothing was counted.
List<int> percentages(List<int> counts) {
  final total = counts.fold(0, (sum, c) => sum + (c > 0 ? c : 0));
  if (total == 0) return [for (final _ in counts) 0];
  final exact = [for (final c in counts) (c > 0 ? c : 0) * 100 / total];
  final floors = [for (final e in exact) e.floor()];
  var left = 100 - floors.fold(0, (sum, f) => sum + f);
  final order = List.generate(counts.length, (i) => i)
    ..sort((a, b) {
      final byRemainder = (exact[b] - floors[b]).compareTo(
        exact[a] - floors[a],
      );
      return byRemainder != 0 ? byRemainder : a.compareTo(b);
    });
  for (final i in order) {
    if (left == 0) break;
    floors[i]++;
    left--;
  }
  return floors;
}

/// Indexes of the highest count (several on a tie; none when all are 0).
Set<int> leaders(List<int> counts) {
  if (counts.isEmpty) return {};
  final top = counts.reduce((a, b) => a > b ? a : b);
  if (top <= 0) return {};
  return {
    for (var i = 0; i < counts.length; i++)
      if (counts[i] == top) i,
  };
}

/// What one point on [outcome] returns if it wins (total / outcome points),
/// or null when nobody predicted it.
double? returnRatio(Prediction prediction, PredictionOutcome outcome) {
  if (outcome.points <= 0) return null;
  return prediction.totalPoints / outcome.points;
}

/// "1:2.43", like Twitch; "—" when there is no ratio.
String formatRatio(double? ratio) {
  if (ratio == null || !ratio.isFinite) return '—';
  final text = ratio
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  // The language's decimal separator (« 1:1,02 » in French).
  return '1:${localDecimal(text)}';
}
