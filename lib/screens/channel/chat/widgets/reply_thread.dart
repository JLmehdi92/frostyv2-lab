import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/channel/chat/widgets/chat_message.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:onset/widgets/onset_scrollbar.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

class ReplyThread extends StatelessWidget {
  final IRCMessage selectedMessage;
  final ChatStore chatStore;

  const ReplyThread({
    super.key,
    required this.selectedMessage,
    required this.chatStore,
  });

  @override
  Widget build(BuildContext context) {
    final replyParent = chatStore.messages.firstWhereOrNull(
      (message) =>
          message.tags['id'] == selectedMessage.tags['reply-parent-msg-id'],
    );

    final replyDisplayName = selectedMessage.tags['reply-parent-display-name'];
    final replyUserLogin = selectedMessage.tags['reply-parent-user-login'];
    final replyBody = selectedMessage.tags['reply-parent-msg-body'];

    final replyName = replyUserLogin != null
        ? getReadableName(replyDisplayName!, replyUserLogin)
        : replyDisplayName;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.5,
      child: Observer(
        builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(chatStore.settings.messageScale),
            ),
            child: DefaultTextStyle(
              style: DefaultTextStyle.of(
                context,
              ).style.copyWith(fontSize: chatStore.settings.fontSize),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SheetSectionLabel(
                    context.l10n.chatReplies,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  ),
                  if (replyParent != null)
                    ChatMessage(ircMessage: replyParent, chatStore: chatStore)
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Text(
                        '$replyName: $replyBody',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  Flexible(
                    child: OnsetScrollbar(
                      child: ListView(
                        primary: false,
                        children: chatStore.messages
                            .where(
                              (message) =>
                                  message.tags['reply-parent-msg-id'] ==
                                  selectedMessage.tags['reply-parent-msg-id'],
                            )
                            .map(
                              (message) => ChatMessage(
                                isModal: true,
                                showReplyHeader: false,
                                isInReplyThread: true,
                                ircMessage: message,
                                chatStore: chatStore,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
