import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/whispers/whisper_actions.dart';
import 'package:onset/screens/whispers/whispers_screen.dart';
import 'package:onset/stores/whisper_store.dart';
import 'package:onset/utils/share_link.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:provider/provider.dart';

typedef ChatLinkSender =
    Future<void> Function({
      required String broadcasterId,
      required String senderId,
      required String message,
    });

T? _maybeRead<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}

Future<void> showShareSheet(
  BuildContext context, {
  required String url,
  String? channelId,
  String? channelName,
}) {
  final auth = _maybeRead<AuthStore>(context);
  final api = _maybeRead<TwitchApi>(context);
  final whispers = _maybeRead<WhisperStore>(context);
  final viewerId = auth != null && auth.isLoggedIn
      ? auth.user.details?.id
      : null;
  if (viewerId == null || api == null) return shareLink(context, url);
  return showOnsetSheet<void>(
    context: context,
    builder: (_) => ShareSheet(
      url: url,
      viewerId: viewerId,
      channelId: channelId,
      channelName: channelName,
      sendToChat: api.sendChatMessage,
      whisperStore: whispers,
      onShare: () => shareLink(context, url),
      pickWhisperTarget: (sheetContext) =>
          pickWhisperTarget(sheetContext, me: viewerId),
    ),
  );
}

class ShareSheet extends StatelessWidget {
  const ShareSheet({
    super.key,
    required this.url,
    required this.viewerId,
    required this.sendToChat,
    required this.onShare,
    required this.pickWhisperTarget,
    this.channelId,
    this.channelName,
    this.whisperStore,
  });

  final String url;
  final String viewerId;
  final String? channelId;
  final String? channelName;
  final ChatLinkSender sendToChat;
  final WhisperStore? whisperStore;
  final Future<void> Function() onShare;
  final Future<WhisperTarget?> Function(BuildContext context) pickWhisperTarget;

  Future<void> _sendToChat(BuildContext context, String channelId) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l10n;
    final name = channelName ?? '';
    Navigator.pop(context);
    String result;
    try {
      await sendToChat(
        broadcasterId: channelId,
        senderId: viewerId,
        message: url,
      );
      result = l.shareSentToChat(name: name);
    } on UnauthorizedException {
      result = l.shareChatLogInAgain;
    } catch (e) {
      debugPrint('Share to chat failed: $e');
      result = l.shareChatFailed;
    }
    messenger?.showSnackBar(SnackBar(content: Text(result)));
  }

  Future<void> _whisper(BuildContext context, WhisperStore store) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l10n;
    final navigator = Navigator.of(context);
    final target = await pickWhisperTarget(context);
    if (target == null) return;
    if (navigator.mounted) navigator.pop();
    final failure = await store.sendTo(
      userId: target.userId,
      login: target.login,
      displayName: target.displayName,
      text: url,
    );
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          failure?.text(l) ?? l.shareWhisperSent(name: target.displayName),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final channelId = this.channelId;
    final store = whisperStore;
    return ListView(
      shrinkWrap: true,
      children: [
        SheetSectionLabel(l.shareTitle),
        if (channelId != null)
          SheetRow(
            key: const ValueKey('share-chat'),
            glyph: SheetGlyphKind.addChat,
            label: channelName == null
                ? l.shareSendToChat
                : l.shareSendToChannelChat(name: channelName!),
            onTap: () => unawaited(_sendToChat(context, channelId)),
          ),
        if (store != null)
          SheetRow(
            key: const ValueKey('share-whisper'),
            glyph: SheetGlyphKind.whisper,
            label: l.shareSendAsWhisper,
            onTap: () => unawaited(_whisper(context, store)),
          ),
        SheetRow(
          key: const ValueKey('share-system'),
          glyph: SheetGlyphKind.share,
          label: l.shareOther,
          onTap: () {
            Navigator.pop(context);
            unawaited(onShare());
          },
        ),
      ],
    );
  }
}
