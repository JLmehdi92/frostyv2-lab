import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the system share sheet for [url] (anchored to [context]'s widget,
/// as iPad needs). Where sharing is not possible, the link is copied and
/// a snack bar says so.
Future<void> shareLink(
  BuildContext context,
  String url, {
  String? subject,
  @visibleForTesting SharePlus? sharer,
}) async {
  final box = context.findRenderObject();
  final origin = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  try {
    final result = await (sharer ?? SharePlus.instance).share(
      ShareParams(text: url, subject: subject, sharePositionOrigin: origin),
    );
    if (result.status != ShareResultStatus.unavailable) return;
  } catch (e) {
    debugPrint('Share failed: $e');
  }
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied')));
  }
}
