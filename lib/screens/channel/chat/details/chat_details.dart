import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:onset/constants.dart';
import 'package:onset/main.dart';
import 'package:onset/models/chat_rules.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/details/chat_details_store.dart';
import 'package:onset/screens/channel/chat/details/chat_mode_controls.dart';
import 'package:onset/screens/channel/chat/details/chat_modes.dart';
import 'package:onset/screens/channel/chat/details/chat_users_list.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/channel/chat/widgets/chat_rules_sheet.dart';
import 'package:onset/screens/settings/settings.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils.dart';
import 'package:onset/utils/twitch_links.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/onset_scrollbar.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:onset/widgets/twitch_web_page.dart';

/// Opens the chat's details ("⋯" beside the points, or a tablet's chat
/// header): board ChaineDetailsTchat.
Future<void> showChatDetails(
  BuildContext context, {
  required ChatStore chatStore,
  required VoidCallback onAddChat,
}) => showOnsetSheet<void>(
  context: context,
  builder: (_) => ChatDetails(
    chatDetailsStore: chatStore.chatDetailsStore,
    chatStore: chatStore,
    userLogin: chatStore.channelName,
    onAddChat: onAddChat,
  ),
);

/// The views of the chat's details: the menu, and what opens in place of
/// it (a back chevron returns to the menu).
enum ChatDetailsView { menu, sleep, color, rules }

class ChatDetails extends StatefulWidget {
  final ChatDetailsStore chatDetailsStore;
  final ChatStore chatStore;
  final String userLogin;

  /// Callback to add a new chat tab.
  /// Shows an "Add chat" option in the menu.
  final VoidCallback onAddChat;

  const ChatDetails({
    super.key,
    required this.chatDetailsStore,
    required this.chatStore,
    required this.userLogin,
    required this.onAddChat,
  });

  /// The board's tallest sheet.
  static const maxHeight = 600.0;

  /// The sleep timer's lengths.
  static const sleepDurations = [
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 3),
    Duration(hours: 4),
    Duration(hours: 5),
    Duration(hours: 6),
    Duration(hours: 7),
    Duration(hours: 8),
    Duration(hours: 9),
    Duration(hours: 10),
    Duration(hours: 11),
    Duration(hours: 12),
  ];

  @override
  State<ChatDetails> createState() => _ChatDetailsState();
}

class _ChatDetailsState extends State<ChatDetails> {
  late final _scrollController = ScrollController();

  var _view = ChatDetailsView.menu;

  bool _isRefreshingAssets = false;
  bool _showRefreshSuccess = false;
  Timer? _refreshSuccessTimer;

  /// The rules shown in the rules view.
  ChatRules? _rules;

  /// The colour picked in the colour view, and whether it is being saved.
  String? _pickedColor;
  bool _loadingColor = false;
  bool _savingColor = false;

  String formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} ${Intl.plural(duration.inMinutes, one: 'minute', other: 'minutes')}';
    }

    return '${duration.inHours} ${Intl.plural(duration.inHours, one: 'hour', other: 'hours')}';
  }

  String formatTimeLeft(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  void _show(ChatDetailsView view) {
    if (!mounted) return;
    setState(() => _view = view);
  }

  /// Converts a hex color string to a color name if it matches one of our predefined chat colors.
  /// Returns null if no match is found.
  String? _hexToColorName(String hexColor) {
    // Remove # if present
    final cleanHex = hexColor.startsWith('#')
        ? hexColor.substring(1)
        : hexColor;

    // Convert to uppercase for comparison
    final upperHex = cleanHex.toUpperCase();

    // Find matching color name
    for (final entry in chatColorValues.entries) {
      final colorValue = entry.value.toARGB32().toRadixString(16).toUpperCase();
      // Remove alpha channel (first 2 characters) for comparison
      if (colorValue.length >= 6) {
        final colorHex = colorValue.substring(2);
        if (colorHex == upperHex) {
          return entry.key;
        }
      }
    }

    return null;
  }

  /// The colour view, once the viewer's current colour is read.
  Future<void> _openColorPicker() async {
    if (_loadingColor) return;
    setState(() => _loadingColor = true);
    final selectedColor = await _getCurrentUserColor();
    if (!mounted) return;
    setState(() {
      _loadingColor = false;
      _pickedColor = selectedColor;
      _view = ChatDetailsView.color;
    });
  }

  Future<String?> _getCurrentUserColor() async {
    try {
      final currentColorHex = await widget.chatStore.twitchApi.getUserChatColor(
        userId: widget.chatStore.auth.user.details!.id,
      );

      if (currentColorHex.isNotEmpty) {
        return _hexToColorName(currentColorHex);
      }
    } catch (e) {
      // Ignore errors when fetching current color
    }
    return null;
  }

  Future<void> _saveColor(String color) async {
    setState(() => _savingColor = true);
    bool success;
    try {
      success = await widget.chatStore.twitchApi.updateUserChatColor(
        userId: widget.chatStore.auth.user.details!.id,
        color: color,
      );
    } catch (error) {
      // Anything but an API error (offline, signed out meanwhile) must not
      // leave Save greyed out for good.
      debugPrint('Failed to update chat color: $error');
      success = false;
    }

    if (!mounted) return;
    setState(() {
      _savingColor = false;
      // A failed save keeps the pick on screen for another try.
      if (success) _view = ChatDetailsView.menu;
    });

    final message = success
        ? 'Chat color updated successfully!'
        : 'Failed to update chat color. Please try again.';
    _showMessage(message);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _hasActiveModes() {
    final roomState = widget.chatDetailsStore.roomState;
    return roomState.subMode != '0' ||
        roomState.followersOnly != '-1' ||
        roomState.emoteOnly != '0' ||
        roomState.slowMode != '0' ||
        roomState.r9k != '0';
  }

  Future<void> _handleRefreshAssets() async {
    setState(() => _isRefreshingAssets = true);

    try {
      await widget.chatStore.getAssets();
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _isRefreshingAssets = false;
          _showRefreshSuccess = true;
        });

        // Hide success after 2 seconds
        _refreshSuccessTimer?.cancel();
        _refreshSuccessTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _showRefreshSuccess = false);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshingAssets = false);
      }
    }
  }

  Widget _refreshTrailing(BuildContext context) {
    final accent = SheetColors.accentOf(context);
    return AnimatedSwitcher(
      duration: motionDuration(context, const Duration(milliseconds: 200)),
      child: _isRefreshingAssets
          ? SizedBox(
              key: const ValueKey('busy'),
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accent,
                backgroundColor: SheetColors.of(context).ring,
              ),
            )
          : _showRefreshSuccess
          ? SheetGlyph(
              SheetGlyphKind.check,
              key: const ValueKey('success'),
              strokeWidth: 2.4,
              color: accent,
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _menu(BuildContext context) {
    final store = widget.chatStore;
    return Observer(
      builder: (context) {
        // Read in the observer: the menu follows a login while it is open.
        final loggedIn = store.auth.isLoggedIn;
        final children = [
          if (_hasActiveModes())
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: ChatModes(roomState: widget.chatDetailsStore.roomState),
            ),
          Observer(
            builder: (context) {
              final showVideo = store.settings.showVideo;
              return SheetRow(
                glyph: showVideo
                    ? SheetGlyphKind.whisper
                    : SheetGlyphKind.monitor,
                label: showVideo ? 'Chat only' : 'Show video',
                onTap: () {
                  store.settings.showVideo = !showVideo;
                  Navigator.of(context).pop();
                },
              );
            },
          ),
          SheetRow(
            glyph: SheetGlyphKind.refresh,
            label: 'Refresh emotes and badges',
            trailing: _refreshTrailing(context),
            onTap: _isRefreshingAssets ? null : _handleRefreshAssets,
          ),
          SheetRow(
            glyph: SheetGlyphKind.plug,
            label: 'Reconnect',
            onTap: () {
              Navigator.of(context).pop();
              store.updateNotification('Reconnecting to chat...');
              store.connectToChat();
            },
          ),
          if (loggedIn)
            SheetRow(
              glyph: SheetGlyphKind.palette,
              label: 'Username color',
              end: SheetRowEnd.chevron,
              trailing: _loadingColor
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SheetColors.accentOf(context),
                      ),
                    )
                  : null,
              onTap: _openColorPicker,
            ),
          if (loggedIn)
            SheetRow(
              glyph: SheetGlyphKind.coin,
              label: 'Channel points, polls and predictions',
              detail: 'Opens the chat on twitch.tv',
              end: SheetRowEnd.external,
              onTap: () {
                Navigator.of(context).pop();
                TwitchWebPage.open(
                  context,
                  title: 'Twitch chat',
                  url: Uri.https(
                    'www.twitch.tv',
                    '/popout/${widget.userLogin}/chat',
                  ),
                );
              },
            ),
          // Twitch's Subscribe and Gift a Sub: purchases happen on the
          // channel's twitch.tv subscription page.
          if (loggedIn &&
              store.auth.user.details?.login.toLowerCase() !=
                  widget.userLogin.toLowerCase())
            if (twitchSubscribeUrl(widget.userLogin) case final url?) ...[
              SheetRow(
                glyph: SheetGlyphKind.star,
                label: 'Subscribe',
                detail: 'Opens twitch.tv',
                end: SheetRowEnd.external,
                onTap: () {
                  Navigator.of(context).pop();
                  TwitchWebPage.open(context, title: 'Subscribe', url: url);
                },
              ),
              SheetRow(
                glyph: SheetGlyphKind.gift,
                label: 'Gift a Sub',
                detail: 'Opens twitch.tv',
                end: SheetRowEnd.external,
                onTap: () {
                  Navigator.of(context).pop();
                  TwitchWebPage.open(context, title: 'Gift a Sub', url: url);
                },
              ),
            ],
          if (store.canModerate)
            SheetRow(
              glyph: SheetGlyphKind.shield,
              label: 'Chat modes',
              detail: 'Slow, followers-only, clear chat…',
              end: SheetRowEnd.chevron,
              onTap: () => showOnsetSheet<void>(
                context: context,
                builder: (context) => Observer(
                  builder: (context) => ChatModeControls(
                    roomState: widget.chatDetailsStore.roomState,
                    onModerate: store.moderate,
                  ),
                ),
              ),
            ),
          ChatRulesTile(
            rules: store.chatRules,
            onOpen: (rules) {
              _rules = rules;
              _show(ChatDetailsView.rules);
            },
          ),
          SheetRow(
            glyph: SheetGlyphKind.people,
            label: 'Chatters',
            end: SheetRowEnd.chevron,
            onTap: () => showOnsetSheet<void>(
              context: context,
              builder: (context) => GestureDetector(
                onTap: FocusScope.of(context).unfocus,
                child: ChattersList(
                  chatDetailsStore: widget.chatDetailsStore,
                  chatStore: store,
                  userLogin: widget.userLogin,
                ),
              ),
            ),
          ),
          SheetRow(
            glyph: SheetGlyphKind.addChat,
            label: 'Add chat',
            end: SheetRowEnd.chevron,
            onTap: widget.onAddChat,
          ),
          Observer(
            builder: (context) {
              final hasTimer = store.timeRemaining.inSeconds > 0;
              final accent = SheetColors.accentOf(context);
              return SheetRow(
                glyph: SheetGlyphKind.timer,
                label: hasTimer
                    ? formatTimeLeft(store.timeRemaining)
                    : 'Sleep timer',
                color: hasTimer ? accent : null,
                end: SheetRowEnd.chevron,
                onTap: () => _show(ChatDetailsView.sleep),
              );
            },
          ),
          SheetRow(
            glyph: SheetGlyphKind.settings,
            label: 'Settings',
            end: SheetRowEnd.chevron,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: Settings.routeName),
                builder: (context) => Settings(settingsStore: store.settings),
              ),
            ),
          ),
        ];

        return ListView(
          key: const ValueKey(ChatDetailsView.menu),
          shrinkWrap: true,
          primary: false,
          padding: const EdgeInsets.only(bottom: 14),
          children: children,
        );
      },
    );
  }

  Widget _sleep(BuildContext context) {
    final store = widget.chatStore;
    final accent = SheetColors.accentOf(context);
    return ListView(
      key: const ValueKey(ChatDetailsView.sleep),
      shrinkWrap: true,
      primary: false,
      padding: const EdgeInsets.only(bottom: 14),
      children: [
        SheetBackHeader(
          title: 'Sleep timer',
          onBack: () => _show(ChatDetailsView.menu),
        ),
        if (store.sleepTimer?.isActive == true)
          Observer(
            builder: (context) => SheetRow(
              glyph: SheetGlyphKind.close,
              label: 'Cancel',
              trailing: Text(
                formatTimeLeft(store.timeRemaining),
                style: SheetText.tabular(
                  TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
              onTap: () {
                store.cancelSleepTimer();
                _show(ChatDetailsView.menu);
              },
            ),
          ),
        for (final duration in ChatDetails.sleepDurations)
          SheetRow(
            glyph: SheetGlyphKind.hourglass,
            label: formatDuration(duration),
            minHeight: 48,
            onTap: () {
              store.updateSleepTimer(
                duration: duration,
                onTimerFinished: () => navigatorKey.currentState?.popUntil(
                  (route) => route.isFirst,
                ),
              );
              _show(ChatDetailsView.menu);
            },
          ),
      ],
    );
  }

  Widget _rulesView(BuildContext context) {
    final rules = _rules;
    if (rules == null) return const SizedBox.shrink();
    return ChatRulesSheet(
      key: const ValueKey(ChatDetailsView.rules),
      rules: rules,
      onAccept: () {
        unawaited(widget.chatStore.chatRules?.accept());
        _show(ChatDetailsView.menu);
      },
      onBack: () => _show(ChatDetailsView.menu),
    );
  }

  Widget _colorView(BuildContext context) {
    final colors = SheetColors.of(context);
    final picked = _pickedColor;
    return SizedBox(
      key: const ValueKey(ChatDetailsView.color),
      height: ChatDetails.maxHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetBackHeader(
            title: 'Username color',
            onBack: () => _show(ChatDetailsView.menu),
          ),
          if (picked != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.well,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.hairline,
                  width: OnsetTokens.hairlineWidth,
                ),
              ),
              child: _ColorPreview(chatStore: widget.chatStore, color: picked),
            ),
          Expanded(
            child: OnsetScrollbar(
              controller: _scrollController,
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                children: [
                  for (final name in chatColorNames)
                    _ColorRow(
                      name: name,
                      selected: picked == name,
                      onTap: () => setState(() => _pickedColor = name),
                    ),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colors.hairline,
                  width: OnsetTokens.hairlineWidth,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: SheetButton(
                      label: 'Cancel',
                      tone: SheetButtonTone.text,
                      expand: true,
                      onPressed: () => _show(ChatDetailsView.menu),
                    ),
                  ),
                  Expanded(
                    child: SheetButton(
                      label: 'Save',
                      expand: true,
                      onPressed: picked == null || _savingColor
                          ? null
                          : () => _saveColor(picked),
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
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final view = switch (_view) {
      ChatDetailsView.menu => _menu(context),
      ChatDetailsView.sleep => _sleep(context),
      ChatDetailsView.color => _colorView(context),
      ChatDetailsView.rules => _rulesView(context),
    };
    // A sub-view goes back to the menu first, like the sheets it replaces
    // (the back button and the scrim close one level).
    return PopScope(
      canPop: _view == ChatDetailsView.menu,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _show(ChatDetailsView.menu);
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: ChatDetails.maxHeight),
        child: AnimatedSize(
          duration: motionDuration(context, const Duration(milliseconds: 260)),
          curve: OnsetMotion.standard,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: motionDuration(
              context,
              const Duration(milliseconds: 240),
            ),
            switchInCurve: OnsetMotion.emphasizedDecelerate,
            switchOutCurve: OnsetMotion.emphasizedAccelerate,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) {
              final fade = FadeTransition(opacity: animation, child: child);
              if (reduce) return fade;
              // Sub-views come in from the side they go back to.
              final menu = child.key == const ValueKey(ChatDetailsView.menu);
              return SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(menu ? -0.06 : 0.06, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: fade,
              );
            },
            child: view,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _refreshSuccessTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}

/// One of Twitch's name colours.
class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = name
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
    // Apply the same color adjustment for consistent preview
    final color = adjustChatNameColor(context, chatColorValues[name]!);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SheetRow(
        label: displayName,
        minHeight: 48,
        leading: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        trailing: AnimatedOpacity(
          opacity: selected ? 1 : 0,
          duration: motionDuration(context, const Duration(milliseconds: 160)),
          child: SheetGlyph(
            SheetGlyphKind.check,
            strokeWidth: 2.4,
            color: SheetColors.accentOf(context),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// "How it will look in chat": the viewer's own message, with their badges,
/// in [color].
class _ColorPreview extends StatelessWidget {
  const _ColorPreview({required this.chatStore, required this.color});

  final ChatStore chatStore;
  final String color;

  @override
  Widget build(BuildContext context) {
    final userDetails = chatStore.auth.user.details!;
    final userState = chatStore.userState;

    // Create a mock IRC message with the user's current state
    final mockTags = <String, String>{
      'display-name': userDetails.displayName,
      'color':
          '#${chatColorValues[color]!.toARGB32().toRadixString(16).substring(2)}',
      'user-id': userDetails.id,
      'mod': userState.mod ? '1' : '0',
      'subscriber': userState.subscriber ? '1' : '0',
      'id': 'preview-message',
      'tmi-sent-ts': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    // Copy any badges from the current user state
    if (userState.raw != null) {
      final userStateMessage = IRCMessage.fromString(userState.raw!);
      if (userStateMessage.tags['badges'] != null) {
        mockTags['badges'] = userStateMessage.tags['badges']!;
      }
      if (userStateMessage.tags['badge-info'] != null) {
        mockTags['badge-info'] = userStateMessage.tags['badge-info']!;
      }
    }

    final mockMessage = IRCMessage(
      raw: '',
      command: Command.privateMessage,
      tags: mockTags,
      user: userDetails.login,
      message: 'How it will look in chat',
      split: ['How', 'it', 'will', 'look', 'in', 'chat'],
      action: false,
      mention: false,
    );

    return Text.rich(
      TextSpan(
        children: mockMessage.generateSpan(
          context,
          assetsStore: chatStore.assetsStore,
          emoteScale: chatStore.settings.emoteScale,
          badgeScale: chatStore.settings.badgeScale,
          animateEmotes: chatStore.settings.animateEmotes,
          launchExternal: false, // Disable launching for preview
          style: DefaultTextStyle.of(context).style,
        ),
      ),
    );
  }
}
