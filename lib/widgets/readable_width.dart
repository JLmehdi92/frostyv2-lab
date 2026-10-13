import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:frosty/utils/context_extensions.dart';

/// Widest a column of settings tiles gets on a large screen, in dp.
const kReadableMaxWidth = 720.0;

/// Side inset that centres a [kReadableMaxWidth] column in [width].
double readableInset(double width) =>
    math.max(0, (width - kReadableMaxWidth) / 2);

/// Centres [sliver] in a [kReadableMaxWidth] column on a large screen, so
/// list tiles do not run across a whole landscape tablet. The scroll view
/// keeps its full width, so it still scrolls from the side gutters. Phones
/// are left as they are.
class SliverReadableWidth extends StatelessWidget {
  const SliverReadableWidth({super.key, required this.sliver});

  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    if (!context.isLargeScreen) return sliver;
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverPadding(
        padding: EdgeInsets.symmetric(
          horizontal: readableInset(constraints.crossAxisExtent),
        ),
        sliver: sliver,
      ),
    );
  }
}
