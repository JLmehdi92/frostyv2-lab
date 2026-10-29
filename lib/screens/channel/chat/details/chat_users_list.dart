import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/screens/channel/chat/details/chat_details_store.dart';
import 'package:frosty/screens/channel/chat/stores/chat_store.dart';
import 'package:frosty/screens/channel/chat/widgets/chat_user_modal.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/frosty_scrollbar.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';
import 'package:frosty/widgets/scroll_to_top_button.dart';
import 'package:frosty/widgets/sheet/onset_sheet.dart';
import 'package:frosty/widgets/sheet/sheet_glyph.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ChattersList extends StatefulWidget {
  final ChatDetailsStore chatDetailsStore;
  final ChatStore chatStore;
  final String userLogin;

  const ChattersList({
    super.key,
    required this.chatDetailsStore,
    required this.chatStore,
    required this.userLogin,
  });

  @override
  State<ChattersList> createState() => _ChattersListState();
}

class _ChattersListState extends State<ChattersList> {
  Future<void> _open(String login) async {
    final userInfo = await context.read<TwitchApi>().getUser(userLogin: login);

    if (!mounted) return;

    showChatUserCard(
      context,
      chatStore: widget.chatStore,
      username: userInfo.login,
      userId: userInfo.id,
      displayName: userInfo.displayName,
    );
  }

  /// "No chatters found", "No matching chatters": the board's empty state.
  Widget _empty(BuildContext context, String message) {
    final color = SheetColors.of(context).tertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          SheetGlyph(
            SheetGlyphKind.people,
            size: 26,
            strokeWidth: 1.6,
            color: color,
          ),
          Text(message, style: SheetText.body.copyWith(color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final accent = SheetColors.accentOf(context);
    final store = widget.chatDetailsStore;
    // Board ChaineDetailsTchat: the filter, the count, one 48 dp row per
    // chatter; the sheet takes the room under the video.
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            // Focus is not observable: the ring and Cancel follow the node.
            child: ListenableBuilder(
              listenable: store.textFieldFocusNode,
              builder: (context, _) => Observer(
                builder: (context) {
                  final focused = store.textFieldFocusNode.hasFocus;
                  final showClear = focused || store.filterText.isNotEmpty;
                  return AnimatedContainer(
                    duration: motionDuration(
                      context,
                      const Duration(milliseconds: 160),
                    ),
                    height: 44,
                    padding: const EdgeInsetsDirectional.only(
                      start: 12,
                      end: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.raised,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: focused
                            ? accent.withValues(alpha: 0.55)
                            : colors.ring,
                        width: focused ? 1 : FrostyTokens.hairlineWidth,
                      ),
                    ),
                    child: Row(
                      spacing: 10,
                      children: [
                        SheetGlyph(
                          SheetGlyphKind.filter,
                          size: 18,
                          color: colors.secondary,
                        ),
                        Expanded(
                          child: TextField(
                            controller: store.textController,
                            focusNode: store.textFieldFocusNode,
                            autocorrect: false,
                            cursorColor: accent,
                            style: SheetText.row.copyWith(
                              fontWeight: FontWeight.w400,
                              color: colors.text,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Filter chatters',
                              hintStyle: SheetText.row.copyWith(
                                fontWeight: FontWeight.w400,
                                color: colors.tertiary,
                              ),
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                        if (showClear)
                          IconButton(
                            tooltip: store.filterText.isEmpty
                                ? 'Cancel'
                                : 'Clear',
                            style: IconButton.styleFrom(
                              fixedSize: const Size(40, 40),
                              minimumSize: const Size(40, 40),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () {
                              if (store.filterText.isEmpty) {
                                store.textFieldFocusNode.unfocus();
                              }
                              store.textController.clear();
                            },
                            icon: SheetGlyph(
                              SheetGlyphKind.close,
                              size: 18,
                              strokeWidth: 2,
                              color: colors.secondary,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator.adaptive(
              onRefresh: () async {
                HapticFeedback.lightImpact();

                setState(() {});
              },
              child: Stack(
                alignment: AlignmentDirectional.bottomCenter,
                children: [
                  FrostyScrollbar(
                    controller: store.scrollController,
                    child: Observer(
                      builder: (context) {
                        // One pass over the filter per build: indexing the
                        // lazy filter row by row walked it again each time.
                        final users = store.filteredUsers.toList();
                        return CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          controller: store.scrollController,
                          slivers: [
                            if (store.filterText.isEmpty)
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  2,
                                  16,
                                  8,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: Text(
                                    '${NumberFormat().format(store.chatUsers.length)} chatters found',
                                    style: SheetText.tabular(
                                      TextStyle(
                                        fontFamily: FrostyTokens.bodyFamily,
                                        fontSize: 13,
                                        color: colors.secondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (store.chatUsers.isEmpty)
                              SliverToBoxAdapter(
                                child: _empty(context, 'No chatters found'),
                              )
                            else if (users.isEmpty)
                              SliverToBoxAdapter(
                                child: _empty(context, 'No matching chatters'),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.only(bottom: 16),
                                sliver: SliverList.builder(
                                  itemCount: users.length,
                                  itemBuilder: (context, index) {
                                    final login = users[index];
                                    return InkWell(
                                      onTap: () => _open(login),
                                      child: Container(
                                        height: 48,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Row(
                                          spacing: 12,
                                          children: [
                                            InitialAvatar(name: login),
                                            Expanded(
                                              child: Text(
                                                login,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: SheetText.row.copyWith(
                                                  fontWeight: FontWeight.w400,
                                                  color: colors.text,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  Observer(
                    builder: (context) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: store.showJumpButton
                          ? ScrollToTopButton(
                              scrollController: store.scrollController,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.chatDetailsStore.showJumpButton = false;
    super.dispose();
  }
}
