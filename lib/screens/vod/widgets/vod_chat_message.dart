import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/channel.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:onset/utils/modal_bottom_sheet.dart';
import 'package:onset/widgets/profile_picture.dart';

/// One replayed chat message, rendered exactly like live chat (badges,
/// colours, Twitch/7TV/BTTV/FFZ emotes, mentions). Read-only: no reply or
/// moderation actions.
class VodChatMessage extends StatelessWidget {
  const VodChatMessage({
    super.key,
    required this.ircMessage,
    required this.assetsStore,
    required this.settings,
    required this.vodCreatedAt,
  });

  final IRCMessage ircMessage;
  final ChatAssetsStore assetsStore;
  final SettingsStore settings;

  /// Start of the broadcast, to show timestamps as video time.
  final DateTime vodCreatedAt;

  /// Where in the video the message was sent.
  Duration? get _videoTime {
    final sentAt = int.tryParse(ircMessage.tags['tmi-sent-ts'] ?? '');
    if (sentAt == null) return null;
    return Duration(milliseconds: sentAt - vodCreatedAt.millisecondsSinceEpoch);
  }

  void _onTapName(BuildContext context) {
    final login = ircMessage.user;
    if (login == null || ircMessage.tags['user-id'] == null) return;
    final name = ircMessage.tags['display-name'] ?? login;
    // Captured now: the replay may drop this message while the sheet is open.
    final navigator = Navigator.of(context);
    showModalBottomSheetWithProperFocus(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: ProfilePicture(userLogin: login),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: name.toLowerCase() == login ? null : Text(login),
            ),
            ListTile(
              leading: const Icon(Icons.live_tv_rounded),
              title: Text(context.l10n.vodOpenChannel),
              onTap: () {
                Navigator.pop(sheetContext);
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) => VideoChat(
                      userId: ircMessage.tags['user-id']!,
                      userName: name,
                      userLogin: login,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onLongPress(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    // Read now: the sheet's context is gone once it closes.
    final copied = context.l10n.chatMessageCopied;
    showModalBottomSheetWithProperFocus(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.copy_rounded),
          title: Text(context.l10n.chatCopyMessage),
          onTap: () async {
            Navigator.pop(sheetContext);
            await Clipboard.setData(
              ClipboardData(text: ircMessage.message ?? ''),
            );
            messenger.showSnackBar(SnackBar(content: Text(copied)));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    final mutedColor = style.color?.withValues(alpha: 0.5);
    final videoTime = _videoTime;
    final showTime =
        settings.timestampType != TimestampType.disabled && videoTime != null;
    final highlight = ircMessage.mention == true
        ? Theme.of(context).colorScheme.error
        : null;

    final text = Text.rich(
      TextSpan(
        style: style,
        children: [
          if (showTime)
            TextSpan(
              text: '${formatVodTime(videoTime)} ',
              style: TextStyle(
                color: mutedColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ...ircMessage.generateSpan(
            context,
            onTapName: () => _onTapName(context),
            style: style,
            assetsStore: assetsStore,
            emoteScale: settings.emoteScale,
            badgeScale: settings.badgeScale,
            animateEmotes: settings.animateEmotes,
            showGifs: settings.showGifs,
            animateGifs: settings.animateGifs,
            nameContrast: settings.nameColorContrast,
            launchExternal: settings.launchUrlExternal,
          ),
        ],
      ),
    );

    final padded = Padding(
      padding: EdgeInsets.only(
        top: settings.messageSpacing / 2,
        bottom: settings.messageSpacing / 2,
        left: highlight == null ? 12 : 0,
        right: highlight == null ? 12 : 0,
      ),
      child: text,
    );
    final divided = settings.showChatMessageDividers
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [padded, const Divider()],
          )
        : padded;
    final colored = highlight == null
        ? divided
        : Container(
            padding: const EdgeInsets.only(left: 8, right: 12),
            decoration: BoxDecoration(
              color: highlight.withValues(alpha: 0.1),
              border: Border(left: BorderSide(color: highlight, width: 4)),
            ),
            child: divided,
          );

    return InkWell(onLongPress: () => _onLongPress(context), child: colored);
  }
}
