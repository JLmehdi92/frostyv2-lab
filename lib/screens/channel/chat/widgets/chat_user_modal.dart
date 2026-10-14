import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/channel/chat/stores/chat_store.dart';
import 'package:frosty/screens/channel/chat/widgets/chat_message.dart';
import 'package:frosty/screens/channel/chat/widgets/chat_moderation_bar.dart';
import 'package:frosty/screens/channel/chat/widgets/user_card_info.dart';
import 'package:frosty/screens/channel_profile/channel_profile_screen.dart';
import 'package:frosty/screens/vod/channel_videos.dart';
import 'package:frosty/utils.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/frosty_scrollbar.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:frosty/widgets/user_actions_modal.dart';

class ChatUserModal extends StatefulWidget {
  final ChatStore chatStore;
  final String username;
  final String displayName;
  final String userId;

  const ChatUserModal({
    super.key,
    required this.chatStore,
    required this.username,
    required this.displayName,
    required this.userId,
  });

  @override
  State<ChatUserModal> createState() => _ChatUserModalState();
}

class _ChatUserModalState extends State<ChatUserModal> {
  @override
  Widget build(BuildContext context) {
    final name = getReadableName(widget.displayName, widget.username);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            leading: ProfilePicture(userLogin: widget.username),
            title: Row(
              children: [
                Flexible(
                  child: Tooltip(
                    message: name,
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.chatStore.auth.isLoggedIn)
                  IconButton(
                    tooltip: 'Reply',
                    onPressed: () {
                      widget.chatStore.textController.text =
                          '@${widget.username} ';
                      Navigator.pop(context);
                      widget.chatStore.safeRequestFocus();
                    },
                    icon: const Icon(Icons.reply_rounded),
                  ),
                IconButton(
                  tooltip: 'Profile',
                  onPressed: () {
                    Navigator.pop(context);
                    ChannelProfileScreen.open(
                      context,
                      login: widget.username,
                      userId: widget.userId,
                      displayName: name,
                      // The streamer of this chat: Watch goes back to it.
                      fromChannel:
                          widget.username.toLowerCase() ==
                          widget.chatStore.channelName.toLowerCase(),
                    );
                  },
                  icon: const Icon(Icons.account_circle_outlined),
                ),
                IconButton(
                  tooltip: 'Videos',
                  onPressed: () {
                    Navigator.pop(context);
                    ChannelVideosScreen.open(
                      context,
                      userLogin: widget.username,
                      displayName: name,
                    );
                  },
                  icon: const Icon(Icons.video_library_outlined),
                ),
                IconButton(
                  tooltip: 'More',
                  onPressed: () => showModalBottomSheetWithProperFocus(
                    context: context,
                    builder: (context) => UserActionsModal(
                      authStore: widget.chatStore.auth,
                      name: name,
                      userLogin: widget.username,
                      userId: widget.userId,
                    ),
                  ),
                  icon: Icon(Icons.adaptive.more_rounded),
                ),
              ],
            ),
          ),
          Builder(
            builder: (context) {
              final store = widget.chatStore;
              final isBroadcaster =
                  widget.username.toLowerCase() ==
                  store.channelName.toLowerCase();
              return UserCardInfo(
                api: store.twitchApi,
                userId: widget.userId,
                channelId: store.channelId,
                showFollowAge: store.canModerate && !isBroadcaster,
                badges: userCardBadges(
                  store.messages.lastWhereOrNull(
                    (message) => message.user == widget.username,
                  ),
                  store.assetsStore.twitchBadgesToObject,
                ),
              );
            },
          ),
          Observer(
            builder: (context) {
              final store = widget.chatStore;
              final login = widget.username.toLowerCase();
              // Twitch refuses actions on the broadcaster and on oneself.
              if (!store.canModerate ||
                  login == store.channelName.toLowerCase() ||
                  login == store.auth.user.details?.login.toLowerCase()) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ChatModerationBar(
                  login: widget.username,
                  name: name,
                  onModerate: (command) =>
                      store.moderate(command, userId: widget.userId),
                ),
              );
            },
          ),
          const Divider(indent: 12, endIndent: 12),
          Expanded(
            child: Observer(
              builder: (context) {
                final userMessages = widget.chatStore.messages.reversed
                    .where((message) => message.user == widget.username)
                    .toList();

                if (userMessages.isEmpty) {
                  return const AlertMessage(message: 'No recent messages');
                }

                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(
                      widget.chatStore.settings.messageScale,
                    ),
                  ),
                  child: DefaultTextStyle(
                    style: DefaultTextStyle.of(context).style.copyWith(
                      fontSize: widget.chatStore.settings.fontSize,
                    ),
                    child: FrostyScrollbar(
                      child: ListView.builder(
                        reverse: true,
                        primary: false,
                        itemCount: userMessages.length,
                        itemBuilder: (context, index) => ChatMessage(
                          ircMessage: userMessages[index],
                          chatStore: widget.chatStore,
                          isModal: true,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
