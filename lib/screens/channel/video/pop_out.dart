import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/video/stores/ivs_video_store.dart';
import 'package:onset/services/floating_player.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:onset/widgets/onset_alert_dialog.dart';

enum PopOutResult { floating, pictureInPicture, cancelled, notReady }

typedef WaitForResume = Future<void> Function();

Future<void> waitForAppResume({Duration timeout = const Duration(minutes: 3)}) {
  final resumed = Completer<void>();
  late final AppLifecycleListener listener;
  listener = AppLifecycleListener(
    onResume: () {
      if (!resumed.isCompleted) resumed.complete();
    },
  );
  return resumed.future
      .timeout(timeout, onTimeout: () {})
      .whenComplete(listener.dispose);
}

Future<bool> explainOverlayPermission(BuildContext context) async {
  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l = context.l10n;
      return OnsetAlertDialog(
        title: l.popOutPermissionTitle,
        message: l.popOutPermissionMessage,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.popOutPermissionNotNow),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.popOutPermissionContinue),
          ),
        ],
      );
    },
  );
  return proceed ?? false;
}

Future<PopOutResult> popOutLive(BuildContext context, IvsVideoStore player) {
  final stream = player.streamInfo;
  return popOut(
    context,
    floating: FloatingPlayer.shared,
    url: player.url,
    title: stream == null
        ? player.userLogin
        : getReadableName(stream.userName, stream.userLogin),
    pictureInPicture: player.requestPictureInPicture,
    beforeStart: player.prepareFloatingPlayer,
    afterClose: player.floatingPlayerClosed,
  );
}

Future<PopOutResult> popOut(
  BuildContext context, {
  required FloatingPlayer floating,
  required String? url,
  required String title,
  required VoidCallback pictureInPicture,
  required VoidCallback beforeStart,
  required void Function({required bool returned}) afterClose,
  WaitForResume waitForResume = waitForAppResume,
}) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (url == null) {
    messenger?.showSnackBar(SnackBar(content: Text(l.popOutNotReady)));
    return PopOutResult.notReady;
  }
  if (!await floating.canDrawOverlays()) {
    if (!context.mounted || !await explainOverlayPermission(context)) {
      return PopOutResult.cancelled;
    }
    if (await floating.openPermissionSettings()) await waitForResume();
    if (!await floating.canDrawOverlays()) {
      messenger?.showSnackBar(SnackBar(content: Text(l.popOutRefused)));
      pictureInPicture();
      return PopOutResult.pictureInPicture;
    }
  }
  beforeStart();
  final started = await floating.start(
    url: url,
    title: title,
    channelLabel: l.popOutNotificationChannel,
    closeLabel: l.popOutClose,
  );
  if (!started) {
    afterClose(returned: true);
    pictureInPicture();
    return PopOutResult.pictureInPicture;
  }
  floating.onClosed = (returned) => afterClose(returned: returned);
  return PopOutResult.floating;
}
