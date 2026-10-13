import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/vod/stores/vod_chat_replay_store.dart';
import 'package:frosty/screens/vod/widgets/vod_chat_message.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/frosty_scrollbar.dart';
import 'package:frosty/widgets/loading_indicator.dart';

/// The chat replay pane under (or beside) the VOD player.
class VodChatReplay extends StatelessWidget {
  const VodChatReplay({super.key, required this.store, this.showHeader = true});

  final VodChatReplayStore store;

  /// The slim "Chat replay" title (hidden when the pane is an overlay).
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) const _ReplayHeader(),
        Expanded(
          child: Observer(
            builder: (context) {
              final settings = store.settings;
              switch (store.status) {
                case ReplayStatus.notApplicable:
                  return const AlertMessage(
                    message: 'Uploads have no chat replay',
                    vertical: true,
                  );
                case ReplayStatus.unavailable:
                  return Center(
                    child: AlertMessage(
                      message: 'Chat replay is unavailable for this video',
                      trailingIcon: Icons.refresh_rounded,
                      onTrailingIconPressed: store.retry,
                      padding: const EdgeInsets.all(16),
                    ),
                  );
                case ReplayStatus.loading when store.messages.isEmpty:
                  return const LoadingIndicator(
                    subtitle: 'Loading chat replay',
                  );
                case ReplayStatus.active when store.messages.isEmpty:
                  return const AlertMessage(
                    message: 'No messages yet',
                    vertical: true,
                  );
                case ReplayStatus.loading || ReplayStatus.active:
                  break;
              }
              final messages = store.messages;
              return Stack(
                alignment: AlignmentDirectional.bottomCenter,
                children: [
                  MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: settings.messageScale.textScaler),
                    child: DefaultTextStyle(
                      style: context.defaultTextStyle.copyWith(
                        fontSize: settings.fontSize,
                      ),
                      child: FrostyScrollbar(
                        controller: store.scrollController,
                        child: ListView.builder(
                          reverse: true,
                          addAutomaticKeepAlives: false,
                          controller: store.scrollController,
                          itemCount: messages.length,
                          itemBuilder: (context, index) => VodChatMessage(
                            ircMessage: messages[messages.length - 1 - index],
                            assetsStore: store.assetsStore,
                            settings: settings,
                            vodCreatedAt: store.vod.createdAt,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: store.autoScroll
                          ? null
                          : ElevatedButton.icon(
                              onPressed: store.resumeScroll,
                              icon: const Icon(Icons.arrow_downward_rounded),
                              label: const Text('Resume scroll'),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReplayHeader extends StatelessWidget {
  const _ReplayHeader();

  @override
  Widget build(BuildContext context) {
    final muted = context.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Chat replay',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Tooltip(
            message:
                "7TV, BTTV and FFZ emotes are the channel's current sets, "
                'which may differ from the ones used during the broadcast.',
            triggerMode: TooltipTriggerMode.tap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.info_outline_rounded, size: 18, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
