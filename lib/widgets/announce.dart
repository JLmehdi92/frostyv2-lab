import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

void announce(BuildContext context, String message) {
  if (!context.mounted) return;
  SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    Directionality.of(context),
  );
}
