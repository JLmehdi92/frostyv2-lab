import 'dart:io';

import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/widgets/alert_message.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

var _downloading = false;

Future<void> downloadClip(
  BuildContext context, {
  required TwitchClipService service,
  required String slug,
  @visibleForTesting Future<Directory> Function()? folder,
  @visibleForTesting SharePlus? sharer,
}) async {
  if (_downloading) return;
  _downloading = true;
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  final box = context.findRenderObject();
  final origin = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  void say(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: AlertMessage(message: message, centered: false)),
    );
  try {
    say(l.clipDownloadPreparing);
    final file = await service.downloadClip(
      slug,
      await (folder ?? getTemporaryDirectory)(),
    );
    messenger.hideCurrentSnackBar();
    try {
      await (sharer ?? SharePlus.instance).share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'video/mp4')],
          sharePositionOrigin: origin,
        ),
      );
    } finally {
      if (file.existsSync()) file.deleteSync();
    }
  } catch (e) {
    debugPrint('Clip download failed: ${e.runtimeType}');
    say(l.clipDownloadFailed);
  } finally {
    _downloading = false;
  }
}
