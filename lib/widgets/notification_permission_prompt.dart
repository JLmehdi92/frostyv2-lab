import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/widgets/onset_alert_dialog.dart';

enum NotificationConsent { granted, refused, dismissed }

Future<bool> explainNotificationPermission(BuildContext context) async {
  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l = context.l10n;
      return OnsetAlertDialog(
        title: l.notificationPermissionTitle,
        message: l.notificationPermissionMessage,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.notificationPermissionNotNow),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.notificationPermissionContinue),
          ),
        ],
      );
    },
  );
  return proceed ?? false;
}

Future<bool> explainUnlessAllowed(
  BuildContext context,
  Future<bool> Function() allowed,
) async {
  final alreadyAllowed = await allowed().catchError((Object _) => true);
  if (alreadyAllowed) return true;
  if (!context.mounted) return false;
  return explainNotificationPermission(context);
}

Future<NotificationConsent> askNotificationPermission(
  BuildContext context, {
  required Future<bool> Function() allowed,
  required Future<bool> Function() request,
}) async {
  if (!await explainUnlessAllowed(context, allowed)) {
    return NotificationConsent.dismissed;
  }
  return await request()
      ? NotificationConsent.granted
      : NotificationConsent.refused;
}
