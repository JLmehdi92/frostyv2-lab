import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_chat_history_service.dart';
import 'package:onset/apis/twitch_mod_api.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/badges.dart';
import 'package:onset/models/chat_history.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/events.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/raid_arrival.dart';
import 'package:onset/models/user.dart';
import 'package:onset/models/user_notice.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/chat_delay_queue.dart';
import 'package:onset/screens/channel/chat/chat_history.dart' as history;
import 'package:onset/screens/channel/chat/chat_restrictions.dart';
import 'package:onset/screens/channel/chat/details/stores/chat_details_store.dart';
import 'package:onset/screens/channel/chat/emote_entitlements.dart';
import 'package:onset/screens/channel/chat/gift_bomb_tracker.dart';
import 'package:onset/screens/channel/chat/held_messages.dart';
import 'package:onset/screens/channel/chat/incoming_raid.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_events.dart';
import 'package:onset/screens/channel/chat/mod_tools/stores/mod_tools_store.dart';
import 'package:onset/screens/channel/chat/moderation.dart';
import 'package:onset/screens/channel/chat/moderation_notice.dart';
import 'package:onset/screens/channel/chat/muted_words.dart';
import 'package:onset/screens/channel/chat/server_notice.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:onset/screens/channel/chat/stores/chat_rules_store.dart';
import 'package:onset/screens/channel/chat/widgets/chat_character_counter.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/services/notifications/mention_alerts.dart';
import 'package:onset/services/realtime/twitch_eventsub_client.dart';
import 'package:onset/services/telemetry.dart';
import 'package:onset/stores/whisper_store.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

part 'chat_store.g.dart';

const emoteRefreshDelay = Duration(seconds: 3);

const sharedChatBannerDuration = Duration(seconds: 15);

typedef ChatUserCardRequest = ({String login, String id, String displayName});

/// The store and view-model for chat-related activities.
class ChatStore = ChatStoreBase with _$ChatStore;

abstract class ChatStoreBase with Store {
  /// The total maximum amount of messages in chat.
  static const _messageLimit = 5000;

  /// The maximum ammount of messages to render when autoscroll is enabled.
  static const _renderMessageLimit = 100;

  /// IRC commands that should bypass chat delay.
  /// These are confirmations/state updates rather than chat messages to sync.
  static const _delayBypassCommands = {
    'USERSTATE',
    'GLOBALUSERSTATE',
    'ROOMSTATE',
    'NOTICE', // Rejection notices need immediate feedback
  };

  /// Base height of the bottom bar (input field area).
  static const _baseBottomBarHeight = 68.0;

  /// Height of the autocomplete bar: the 56 dp row of chips, its hairline
  /// drawn inside.
  static const _autocompleteHeight = 56.0;

  /// Height of the reply bar (Container + Divider).
  static const _replyBarHeight = 41.0;

  /// Splits an IRC frame into the lines handled at once and the lines held
  /// by the chat delay. Kept apart line by line, so a held message sharing
  /// a frame with a bypass line is not shown early. A `PING` must be
  /// answered at once (a late PONG costs the connection) and a `RECONNECT`
  /// is about the connection, not the chat; the commands in
  /// [_delayBypassCommands] give the viewer immediate feedback.
  @visibleForTesting
  static ({String now, String held}) splitDelayedIrc(String data) {
    final now = <String>[];
    final held = <String>[];
    for (final line in data.trimRight().split('\r\n')) {
      if (line.isEmpty) continue;
      (_bypassesDelay(line) ? now : held).add(line);
    }
    return (now: now.join('\r\n'), held: held.join('\r\n'));
  }

  static bool _bypassesDelay(String line) {
    if (line.startsWith('PING')) return true;
    final parts = line.split(' ');
    if (line.startsWith('@')) {
      return parts.length >= 3 && _delayBypassCommands.contains(parts[2]);
    }
    return parts.length >= 2 && parts[1] == 'RECONNECT';
  }

  int get _chatDelaySeconds => settings.effectiveChatDelay.toInt();

  bool get _hasActiveChatDelay => settings.showVideo && _chatDelaySeconds > 0;

  final TwitchApi twitchApi;

  /// The viewer's whispers, for `/w` (null in tests and when not given).
  final WhisperStore? whispers;

  /// Twitch's own recent chat, shown on joining like the official app
  /// (null in tests and when not given).
  final TwitchChatHistoryService? chatHistory;

  /// The ids of the history lines shown (and of history gifts folded into
  /// their bomb): the same message arriving live afterwards is not shown,
  /// or counted, twice.
  final _historyIds = <String>{};

  /// Whether the history is still on its way.
  var _historyPending = true;

  /// The deletions, timeouts and clears received live while the history
  /// was on its way, to apply to it when it lands.
  final _moderationBeforeHistory = <IRCMessage>[];

  /// The ids of the notices handed to the gift-bomb tracker (the newest
  /// [_maxTrackedNotices]), so a gift is never counted twice.
  final _trackedNoticeIds = <String>{};

  static const _maxTrackedNotices = 1000;

  static final _lineBreak = RegExp(r'\r\n|\r|\n');

  /// What a message id may look like in a reply the viewer sends: anything
  /// else could carry its own IRC command into the viewer's connection.
  static final _replyId = RegExp(r'^[A-Za-z0-9-]{1,64}$');

  /// Listens to the viewer's EventSub topics, to say what moderators
  /// decided about held messages (null in tests and when not given).
  final EventSubHandle Function(EventSubTopic topic)? listenEvents;

  /// Tells about mentions while the app is not in front (the app's own
  /// when not given).
  final MentionAlerts? mentionAlerts;

  HeldMessageWatcher? _heldMessages;

  /// The channel's chat rules and their gate on the input (null in tests
  /// and when not given).
  final ChatRulesStore? chatRules;

  /// The amount of messages to free (remove) when the [_messageLimit] is reached.
  final _messagesToRemove = (_messageLimit * 0.2).toInt();

  /// The provided auth store to determine login status, get the token, and use the headers for requests.
  final AuthStore auth;

  /// The provided setting store to account for any user-defined behaviors.
  final SettingsStore settings;

  /// The focus node for the textfield to allow for showing and hiding the keyboard/focus.
  final textFieldFocusNode = FocusNode();

  /// The name of the channel to connect to.
  final String channelName;

  /// The channel's ID for API requests.
  final String channelId;

  /// The channel's display name to show on widgets.
  final String displayName;

  var _shouldDisconnect = false;

  /// The Twitch IRC WebSocket channel.
  WebSocketChannel? _channel;

  /// The subscription that handles the WebSocket connection.
  StreamSubscription? _channelListener;

  WebSocketChannel? _sevenTVChannel;

  /// The subscription that handles the 7TV WebSocket connection.
  StreamSubscription? _sevenTVChannelListener;

  static const _maxRetries = 5;

  // The retry counter for exponential backoff.
  var _retries = 0;

  // The current time to wait between retries for exponential backoff.
  var _backoffTime = 0;

  // Reference to the reconnect message for in-place updates.
  IRCMessage? _reconnectMessage;

  // Timestamp when reconnection started, for calculating elapsed time.
  DateTime? _reconnectStartTime;

  /// The scroll controller that controls auto-scroll and resume-scroll behavior.
  final scrollController = ScrollController();

  /// The text controller that handles the TextField inputs and sending of messages.
  final textController = TextEditingController();

  /// The chat details store responsible for the chat modes and users in chat.
  final ChatDetailsStore chatDetailsStore;

  /// The assets store responsible for badges, emotes, and the emote menu.
  final ChatAssetsStore assetsStore;

  /// Requested message to be sent by the user. Will only be sent on receipt of a USERNOTICE command.
  IRCMessage? toSend;

  /// The list of reaction disposer functions that will be used later when disposing.
  final reactions = <ReactionDisposer>[];

  /// The periodic timer used for batching chat message re-renders.
  Timer? _messageBufferTimer;

  /// The list of chat messages to add once autoscroll is resumed.
  /// This is used as an optimization to prevent the list from being updated/shifted while the user is scrolling.
  final messageBuffer = ObservableList<IRCMessage>();

  /// Opens the chat (IRC) and 7TV event sockets.
  final WebSocketChannel Function(Uri uri) _connectSocket;

  /// Pending delayed IRC payloads waiting to be rendered.
  final _pendingChatCallbacks = ChatDelayQueue();

  /// Follows the gift bombs of this chat: decides whether each gift of a
  /// bomb gets its own line and which bombs earn the pinned banner.
  final _giftBombs = GiftBombTracker();

  /// The latest gift bomb that earns the pinned banner (five gifts or more,
  /// live, from this channel), set as its header reaches the chat.
  @readonly
  GiftBomb? _latestGiftBomb;

  /// The gift bomb keyed [key] as its gifts arrive (after the chat delay),
  /// while this chat still remembers it.
  ValueListenable<GiftBomb>? watchGiftBomb(String key) => _giftBombs.watch(key);

  /// The gift bombs whose recipients the viewer opened in their header row
  /// (most recent last, at most [GiftBombTracker.maxTracked]): the rows are
  /// rebuilt as chat scrolls, the choice must outlive them.
  final expandedGiftBombs = <String>{};

  /// Opens or closes the recipients of the gift bomb keyed [key].
  void setGiftBombExpanded(String key, bool expanded) {
    expandedGiftBombs.remove(key);
    if (!expanded) return;
    expandedGiftBombs.add(key);
    if (expandedGiftBombs.length > GiftBombTracker.maxTracked) {
      expandedGiftBombs.remove(expandedGiftBombs.first);
    }
  }

  /// The welcome of a raid the viewer followed here, waiting for the chat
  /// to be joined (it shows right after "Welcome to X's chat!").
  RaidArrival? _pendingArrival;

  /// Says "You followed X's raid" in this chat: now if it is joined, else
  /// as soon as it is.
  void addArrivalNotice(RaidArrival arrival) {
    if (_shouldDisconnect) return;
    if (_messageBufferTimer == null) {
      _pendingArrival = arrival;
      return;
    }
    runInAction(() => messageBuffer.add(IRCMessage.raidWelcome(arrival)));
  }

  /// Adds a line of ONSET's own to this chat (a celebration said quietly),
  /// held like chat while it is delayed to match the video, so it shows in
  /// step with what it is about.
  void addLocalNotice(String text) {
    if (_shouldDisconnect) return;
    // An action wherever it runs: the delay queue may release it from the
    // socket listener or a reaction.
    void add() => runInAction(
      () => messageBuffer.add(IRCMessage.createNotice(message: text)),
    );
    if (_hasActiveChatDelay) {
      _enqueueDelayedCallback(_pendingChatCallbacks, add);
    } else {
      add();
    }
  }

  /// The latest live raid on this channel, set as its notice reaches the
  /// chat (after the chat delay), for the pin above chat.
  @readonly
  IncomingRaid? _latestIncomingRaid;

  /// Pending delayed 7TV payloads waiting to be rendered.
  final _pendingSevenTVCallbacks = ChatDelayQueue();

  /// The set of message IDs that have been revealed by the user (for deleted messages).
  final revealedMessageIds = ObservableSet<String>();

  @action
  void revealMessage(String id) {
    revealedMessageIds.add(id);
  }

  /// Messages the chat filters hid that the viewer chose to see ("Show
  /// Message"), by id.
  final revealedFilteredMessageIds = ObservableSet<String>();

  @action
  void revealFilteredMessage(String id) {
    revealedFilteredMessageIds.add(id);
  }

  /// Timer used for dismissing the notification.
  Timer? _notificationTimer;

  /// Timer used for resetting the sending state if no acknowledgment is received.
  Timer? _sendingTimeoutTimer;

  /// Timer used for updating the chat delay countdown message.
  Timer? _chatDelayCountdownTimer;

  /// Reference to the current countdown message for direct updates (avoids O(n) search).
  IRCMessage? _countdownMessage;

  /// Tracks whether the initial chat delay sync has completed for the current session.
  /// Prevents the countdown from re-appearing when latency updates arrive after initial sync.
  bool _chatDelaySyncCompleted = false;

  /// The current timer for the sleep timer if active.
  Timer? sleepTimer;

  /// The time remaining for the sleep timer.
  @observable
  var timeRemaining = const Duration();

  /// A notification message to display above the chat.
  @readonly
  String? _notification;

  /// The list of chat messages to render and display.
  @readonly
  var _messages = ObservableList<IRCMessage>();

  /// The list of chat messages that should be rendered. Used to prevent jank when resuming scroll.
  @computed
  List<IRCMessage> get renderMessages {
    // If autoscroll is disabled, render ALL messages in chat.
    // The second condition is to prevent an out of index error with sublist.
    if (!_autoScroll || _messages.length < _renderMessageLimit) {
      return _messages;
    }

    // When autoscroll is enabled, only show the first [_renderMessageLimit] messages.
    // This will improve performance by only rendering a limited amount of messages
    // instead of the entire history at all times.
    return _messages.sublist(_messages.length - _renderMessageLimit);
  }

  /// Whether a deletion, a timeout or a ban marked lines in place since the
  /// last flush (their command changed), which no observable reports. The
  /// next flush ([addMessages], every 200 ms) hands the same lines out in a
  /// new list if nothing else does, so the chat redraws them then rather
  /// than at the next message (a quiet chat may have none for a while),
  /// once per flush however many arrive (a ban wave).
  var _linesMarkedInPlace = false;

  /// If the chat should automatically scroll/jump to the latest message.
  @readonly
  var _autoScroll = true;

  @readonly
  var _inputText = '';

  @readonly
  var _showSendButton = false;

  @readonly
  var _showEmoteAutocomplete = false;

  @readonly
  var _showMentionAutocomplete = false;

  /// Whether the chat is currently in shared chat mode (based on source-room-id tag presence).
  @readonly
  var _isInSharedChatMode = false;

  @readonly
  var _showSharedChatBanner = false;

  @readonly
  var _sharedChatStartedNow = false;

  var _sawUnsharedMessage = false;

  var _sharedChatAnnounced = false;

  Timer? _sharedChatBannerTimer;

  @computed
  List<UserTwitch> get sharedChatPartners => [
    if (_isInSharedChatMode)
      for (final id in assetsStore.sharedChatChannelIds)
        if (id != channelId) ?assetsStore.channelIdToUserTwitch[id],
  ];

  @action
  void dismissSharedChatBanner() {
    _sharedChatBannerTimer?.cancel();
    _showSharedChatBanner = false;
  }

  void _announceSharedChat(IRCMessage message) {
    if (_sharedChatAnnounced ||
        message.command != Command.privateMessage ||
        message.tags['historical'] == '1') {
      return;
    }
    _sharedChatAnnounced = true;
    _sharedChatStartedNow = _sawUnsharedMessage;
    _showSharedChatBanner = true;
    _sharedChatBannerTimer?.cancel();
    _sharedChatBannerTimer = Timer(
      sharedChatBannerDuration,
      () => runInAction(() => _showSharedChatBanner = false),
    );
  }

  /// Whether we're waiting for server acknowledgment of a sent message.
  @readonly
  var _isWaitingForAck = false;

  /// Whether the chat WebSocket is currently connected.
  @readonly
  var _isConnected = false;

  /// Whether we've successfully connected at least once (to distinguish
  /// "connecting" from "disconnected" in the UI).
  @readonly
  var _hasConnected = false;

  /// The logged-in user's appearance in chat.
  @readonly
  var _userState = const USERSTATE();

  /// What keeps the viewer from chatting (a ban, a timeout, the slow-mode
  /// wait) or limits it (room modes); recomputed on chat events and when a
  /// wait ends.
  @readonly
  ChatRestriction? _restriction;

  var _banned = false;
  DateTime? _timedOutUntil;
  DateTime? _lastSentAt;
  ChatRestrictionKind? _refusedFor;
  Timer? _restrictionTimer;

  /// Adds Twitch's "X has been timed out / banned" line for a targeted
  /// CLEARCHAT, at the time Twitch sent it.
  void _addModerationNotice(IRCMessage clearChat, List<IRCMessage> buffer) {
    // Blocked people stay out of chat, notices included (moderators and the
    // channel owner see them, as they see their messages).
    final notice = moderationNoticeLine(
      clearChat,
      hiddenLogins: canModerate
          ? const {}
          : {for (final user in auth.user.blockedUsers) user.userLogin},
      newestFirst: buffer.reversed.followedBy(_messages.reversed),
    );
    if (notice != null) buffer.add(notice);
  }

  void _wordServerNotice(IRCMessage notice) {
    final text = notice.message;
    if (text == null) return;
    notice.message = serverNoticeText(
      notice.tags['msg-id'],
      text,
      L10n.current,
    );
  }

  /// Whether the viewer moderates this chat (the broadcaster does too).
  @computed
  bool get canModerate =>
      _userState.mod || channelName == auth.user.details?.login;

  late final ModToolsStore modTools = ModToolsStore(
    twitchApi: twitchApi,
    broadcasterId: channelId,
    listenEvents: listenEvents,
    showActionsInChat: () => settings.showModActionsInChat,
    onChatLine: _addModLine,
  );

  Stream<ModToolsView> get modToolsRequests => modTools.requests;

  @computed
  bool get shieldModeActive => canModerate && modTools.shieldActive;

  void _addModLine(String text, {String? actionLabel, VoidCallback? onAction}) {
    if (_shouldDisconnect) return;
    runInAction(
      () => messageBuffer.add(
        IRCMessage.createNotice(
          message: text,
          actionLabel: actionLabel,
          actionCallback: onAction,
        ),
      ),
    );
  }

  final _shoutoutIds = <String>{};

  void addShoutout(ShoutoutNotice shoutout) {
    if (!_shoutoutIds.add(shoutout.id)) return;
    final l = L10n.current;
    _addModLine(
      l.chatShoutoutNotice(name: shoutout.targetName),
      actionLabel: l.chatShoutoutView,
      onAction: () => _shoutoutRequests.add(shoutout),
    );
  }

  final _shoutoutRequests = StreamController<ShoutoutNotice>.broadcast();

  Stream<ShoutoutNotice> get shoutoutRequests => _shoutoutRequests.stream;

  void _followModTools(String? moderatorId) {
    if (moderatorId == null) {
      modTools.stop();
    } else {
      unawaited(modTools.start(moderatorId));
    }
  }

  @action
  void _updateRestriction() {
    _restrictionTimer?.cancel();
    final now = DateTime.now();
    final restriction = chatRestriction(
      room: chatDetailsStore.roomState,
      privileged: canModerate || _userState.vip,
      subscriber: _userState.subscriber,
      now: now,
      banned: _banned,
      timedOutUntil: _timedOutUntil,
      lastSentAt: _lastSentAt,
      refusedFor: _refusedFor,
    );
    _restriction = restriction;
    final until = restriction?.until;
    if (until != null) {
      _restrictionTimer = Timer(
        until.difference(now) + const Duration(milliseconds: 50),
        _updateRestriction,
      );
    }
  }

  /// Whether a slash command is still running (one runs at a time: a
  /// second tap on send would repeat a ban or a warning).
  var _runningCommand = false;

  /// Runs a slash command and says the outcome in chat; a failed command
  /// keeps its text for another try. The input clears only while it still
  /// holds [submitted] (not a draft typed meanwhile).
  Future<void> _runCommand(ChatCommand command, String submitted) async {
    // Lines put in the chat are worded in the language on screen now.
    final l = L10n.current;
    void say(String text) =>
        messageBuffer.add(IRCMessage.createNotice(message: text));
    void done() {
      if (!_shouldDisconnect && textController.text == submitted) {
        textController.clear();
      }
    }

    final me = auth.user.details?.id;
    switch (command) {
      case SendAsIs():
        return;
      case HelpCommand():
        final commands = [
          ...kChatCommands,
          if (canModerate) ...kModeratorChatCommands,
        ];
        say(
          l.chatHelpCommands(
            commands: [
              for (final c in commands) c.usage(l, inChatLine: true),
            ].join(', '),
          ),
        );
        done();
      case ModerationCommand():
        final outcome = await moderate(command);
        if (outcome?.ok ?? false) done();
      case UnsupportedCommand():
        say(command.text(l));
      case WhisperCommand(:final login, :final message):
        final whispers = this.whispers;
        if (me == null || whispers == null) return say(l.chatLogInToWhisper);
        try {
          final user = await twitchApi.getUser(userLogin: login);
          if (_shouldDisconnect) return;
          final error = await whispers.sendTo(
            userId: user.id,
            login: user.login,
            displayName: user.displayName,
            text: message,
          );
          if (_shouldDisconnect) return;
          if (error != null) return say(error.text(l));
          say(
            whispers.status == WhisperStatus.refused
                ? l.chatWhisperSentNoReplies(name: user.displayName)
                : l.chatWhisperSent(name: user.displayName),
          );
          done();
        } on NotFoundException {
          if (!_shouldDisconnect) {
            say(l.chatWhisperNoUser(login: login));
          }
        } on ApiException catch (e) {
          if (!_shouldDisconnect) {
            say(l.chatWhisperFailedBecause(reason: chatErrorText(l, e)));
          }
        } catch (e, stack) {
          Telemetry.recordError(e, stack, reason: '/w');
          if (!_shouldDisconnect) say(l.chatWhisperFailed);
        }
      case UserCardCommand(:final login):
        await _openUserCard(login, say);
        if (!_shouldDisconnect) done();
      case DisconnectCommand():
        done();
        _channel?.sink.close(1000);
      case ColorCommand(:final color):
        if (me == null) return say(l.chatLogInToChangeColor);
        final ok = await twitchApi.updateUserChatColor(
          userId: me,
          color: color,
        );
        if (_shouldDisconnect) return;
        if (ok) {
          say(l.chatColorChanged);
          done();
        } else {
          say(l.chatColorFailedHex);
        }
      case BlockCommand(:final login) || UnblockCommand(:final login):
        final block = command is BlockCommand;
        try {
          final user = await twitchApi.getUser(userLogin: login);
          final already = auth.user.blockedUsers.any(
            (b) => b.userId == user.id,
          );
          if (block && already) {
            say(l.chatAlreadyBlocked(name: user.displayName));
            done();
            return;
          }
          if (block) {
            // The chat filter compares logins.
            await auth.user.block(targetId: user.id, displayName: user.login);
          } else {
            await auth.user.unblock(targetId: user.id);
          }
          if (_shouldDisconnect) return;
          // The user store reports nothing: the list says if it worked.
          final listed = auth.user.blockedUsers.any((b) => b.userId == user.id);
          if (listed != block) {
            throw StateError('not ${block ? '' : 'un'}blocked');
          }
          say(
            block
                ? l.chatBlockedUser(name: user.displayName)
                : l.chatUnblockedUser(name: user.displayName),
          );
          done();
        } catch (e) {
          debugPrint('/${block ? 'block' : 'unblock'} $login failed: $e');
          if (!_shouldDisconnect) {
            say(
              block
                  ? l.chatBlockFailed(login: login)
                  : l.chatUnblockFailed(login: login),
            );
          }
        }
    }
  }

  final _userCardRequests = StreamController<ChatUserCardRequest>.broadcast();

  final _chatSettingsRequests = StreamController<void>.broadcast();

  Stream<void> get chatSettingsRequests => _chatSettingsRequests.stream;

  void _calloutAnimatedEmotes(IRCMessage message) {
    if (message.command != Command.privateMessage ||
        !settings.animateEmotes ||
        settings.animatedEmotesCalloutShown) {
      return;
    }
    if (!hasAnimatedEmote(message, assetsStore.emoteToObject)) return;
    settings.animatedEmotesCalloutShown = true;
    final l = L10n.current;
    messageBuffer.add(
      IRCMessage.createNotice(
        message: l.chatAnimatedEmotesCallout,
        actionLabel: l.chatAnimatedEmotesCalloutShow,
        actionCallback: () => _chatSettingsRequests.add(null),
      ),
    );
  }

  Timer? _emoteRefreshTimer;
  List<String>? _globalEmoteSets;
  String? _userStateEmoteSets;

  void scheduleEmoteRefresh() {
    if (_shouldDisconnect || auth.user.details == null) return;
    _emoteRefreshTimer?.cancel();
    _emoteRefreshTimer = Timer(emoteRefreshDelay, () {
      if (!_shouldDisconnect) unawaited(_loadUserEmotes(_currentEmoteSets));
    });
  }

  List<String>? get _currentEmoteSets {
    final latest = _userStateEmoteSets?.split(',');
    final global = _globalEmoteSets;
    if (latest == null) return global;
    return {...?global, ...latest}.toList();
  }

  void _noteEmoteSets(IRCMessage userState) {
    final sets = userState.tags['emote-sets'];
    if (emoteSetsChanged(_userStateEmoteSets, sets)) scheduleEmoteRefresh();
    _userStateEmoteSets = sets ?? _userStateEmoteSets;
  }

  Stream<ChatUserCardRequest> get userCardRequests => _userCardRequests.stream;

  Future<void> _openUserCard(String login, void Function(String) say) async {
    final l = L10n.current;
    try {
      final user = await twitchApi.getUser(userLogin: login);
      if (_shouldDisconnect) return;
      _userCardRequests.add((
        login: user.login,
        id: user.id,
        displayName: user.displayName,
      ));
    } on NotFoundException {
      if (!_shouldDisconnect) say(l.chatUserCardNoUser(login: login));
    } catch (e) {
      debugPrint('/user $login failed: $e');
      if (!_shouldDisconnect) say(l.chatUserCardFailed(login: login));
    }
  }

  /// Every emote the viewer can use (Helix, follower emotes included), or
  /// the emote sets GLOBALUSERSTATE named when Helix will not say.
  Future<void> _loadUserEmotes(List<String>? setIds) async {
    final me = auth.user.details?.id;
    if (me != null &&
        await assetsStore.userEmotesFromHelix(
          userId: me,
          broadcasterId: channelId,
        )) {
      return;
    }
    if (setIds == null || _shouldDisconnect) return;
    await assetsStore.userEmotesFuture(
      emoteSets: setIds,
      headers: auth.headersTwitch,
      onError: (error) {
        debugPrint(error.toString());
        return <Emote>[];
      },
    );
  }

  /// Runs [command] in this chat as the viewer and says the outcome in
  /// chat (a viewer who is not a moderator hears it from Twitch). [userId] is the target's id when already known. Null when the
  /// chat closed before it ended.
  Future<ModerationOutcome?> moderate(
    ModerationCommand command, {
    String? userId,
  }) async {
    final me = auth.user.details?.id;
    final ModerationOutcome outcome;
    if (me == null) {
      outcome = (ok: false, message: L10n.current.chatLogInToModerate);
    } else {
      // Helix decides: USERSTATE (behind [canModerate]) comes after joining
      // and misses someone modded meanwhile.
      outcome = await ChatModeration(
        api: twitchApi,
        broadcasterId: channelId,
        moderatorId: me,
      ).run(command, userId: userId);
      if (_shouldDisconnect) return null;
    }
    if (outcome.ok) _noteModerated(command, userId);
    final l = L10n.current;
    final listedRole = command is RoleListCommand && outcome.ok
        ? command.role
        : null;
    messageBuffer.add(
      IRCMessage.createNotice(
        message: outcome.message,
        actionLabel: listedRole == null ? null : l.chatModViewList,
        actionCallback: listedRole == null
            ? null
            : () => modTools.request(
                listedRole == ChannelRole.moderator
                    ? ModToolsView.moderators
                    : ModToolsView.vips,
              ),
      ),
    );
    return outcome;
  }

  void _noteModerated(ModerationCommand command, String? userId) {
    switch (command) {
      case ShieldCommand(:final on):
        modTools.noteShieldMode(on);
      case SuspicionCommand(:final status, :final on) when userId != null:
        modTools.noteSuspicion(userId, on ? status : null);
      default:
        break;
    }
  }

  void _forgetFollowRefusalWhenOpen() {
    final followersOnly =
        int.tryParse(chatDetailsStore.roomState.followersOnly) ?? -1;
    if (_refusedFor == ChatRestrictionKind.followRequired &&
        followersOnly < 0) {
      _refusedFor = null;
    }
  }

  @action
  Future<ViewerActionOutcome?> acknowledgeWarning(
    TwitchViewerActionsService service,
  ) async {
    if (_refusedFor != ChatRestrictionKind.warned) return null;
    final token = auth.twitchWebToken;
    if (token == null || token.isEmpty) return ViewerActionOutcome.signedOut;
    final outcome = await service.acknowledgeWarning(
      channelId: channelId,
      authToken: token,
    );
    if (outcome == ViewerActionOutcome.done &&
        _refusedFor == ChatRestrictionKind.warned) {
      runInAction(() {
        _refusedFor = null;
        _updateRestriction();
      });
    }
    return outcome;
  }

  void _resetOwnRestrictions() {
    _banned = false;
    _refusedFor = null;
    _timedOutUntil = null;
    _lastSentAt = null;
    _updateRestriction();
  }

  /// A send refused for a ban, a timeout or slow mode tells how long.
  void _applyRejection(String msgId, String? message) {
    if (accountRestrictionOf(msgId) case final kind?) {
      _refusedFor = kind;
      _updateRestriction();
      return;
    }
    final seconds = int.tryParse(
      RegExp(r'(\d+) (?:more )?seconds?').firstMatch(message ?? '')?[1] ?? '',
    );
    final now = DateTime.now();
    switch (msgId) {
      case 'msg_banned':
        _banned = true;
      case 'msg_timedout' when seconds != null:
        _timedOutUntil = now.add(Duration(seconds: seconds));
      case 'msg_slowmode' when seconds != null:
        final slow = int.tryParse(chatDetailsStore.roomState.slowMode) ?? 0;
        _lastSentAt = now.add(Duration(seconds: seconds - slow));
      default:
        return;
    }
    _updateRestriction();
  }

  @observable
  var expandChat = false;

  @observable
  IRCMessage? replyingToMessage;

  /// Emotes matching the current autocomplete search term.
  @computed
  List<Emote> get matchingEmotes {
    if (!_showEmoteAutocomplete) return const [];
    final searchTerm = _inputText.split(' ').last.toLowerCase();
    if (searchTerm.isEmpty) return const [];

    return [
      ...assetsStore.userEmoteToObject.values,
      ...assetsStore.bttvEmotes,
      ...assetsStore.ffzEmotes,
      ...assetsStore.sevenTVEmotes,
    ].where((emote) => emote.name.toLowerCase().contains(searchTerm)).toList();
  }

  /// Chatters matching the current mention autocomplete search term.
  @computed
  List<String> get matchingChatters {
    if (!_showMentionAutocomplete) return const [];
    final searchTerm = _inputText
        .split(' ')
        .last
        .replaceFirst('@', '')
        .toLowerCase();
    return chatDetailsStore.chatUsers
        .where((chatter) => chatter.contains(searchTerm))
        .toList();
  }

  /// Slash commands matching what is typed ("/co" suggests /color).
  @computed
  List<ChatCommandInfo> get matchingCommands =>
      matchCommands(_inputText, moderator: canModerate);

  /// Current bottom bar height based on visible overlays.
  /// Used to dynamically adjust chat message list padding.
  @computed
  double get bottomBarHeight {
    var height = _baseBottomBarHeight;

    // Add reply bar height when replying to a message.
    if (replyingToMessage != null) {
      height += _replyBarHeight;
    }

    // Add autocomplete bar height when showing matches.
    if (settings.autocomplete &&
        ((_showEmoteAutocomplete && matchingEmotes.isNotEmpty) ||
            (_showMentionAutocomplete && matchingChatters.isNotEmpty) ||
            matchingCommands.isNotEmpty)) {
      height += _autocompleteHeight;
    }

    // The ban, timeout or slow-mode line above the input.
    if (_restriction case final restriction?
        when auth.isLoggedIn && restriction.showsBar) {
      height += restriction.barHeight;
    }

    return height;
  }

  ChatStoreBase({
    required this.twitchApi,
    required this.auth,
    required this.chatDetailsStore,
    required this.assetsStore,
    required this.settings,
    required this.channelName,
    required this.channelId,
    required this.displayName,
    this.whispers,
    this.chatHistory,
    this.listenEvents,
    this.mentionAlerts,
    this.chatRules,
    @visibleForTesting WebSocketChannel Function(Uri uri)? connectSocket,
  }) : _connectSocket = connectSocket ?? WebSocketChannel.connect {
    // The rules show before the first message, like the official app.
    chatRules
      ?..attach(textFieldFocusNode)
      ..load();

    // Create a reaction that will reconnect to chat when logging in or out.
    // Closing the channel will trigger a reconnect with the new credentials.
    reactions.add(
      reaction((_) => auth.isLoggedIn, (_) => _channel?.sink.close(1000)),
    );

    // Held messages are the logged-in viewer's: follow whoever that is,
    // anew with each token (logging in again grants a missing scope).
    reactions.add(
      reaction(
        (_) => (auth.isLoggedIn ? auth.user.details?.id : null, auth.token),
        (session) => _watchHeldMessages(session.$1),
        fireImmediately: true,
      ),
    );

    reactions.add(
      reaction(
        (_) => (
          auth.isLoggedIn && canModerate ? auth.user.details?.id : null,
          auth.token,
        ),
        (session) => _followModTools(session.$1),
        fireImmediately: true,
      ),
    );

    reactions.add(
      reaction(
        (_) => [
          settings.showTwitchEmotes,
          settings.showTwitchBadges,
          settings.show7TVEmotes,
          settings.showBTTVEmotes,
          settings.showBTTVBadges,
          settings.showFFZEmotes,
          settings.showFFZBadges,
        ],
        (_) {
          if (!settings.show7TVEmotes) {
            _sevenTVChannel?.sink.close(1000);
          }

          getAssets().then((_) {
            if (settings.show7TVEmotes) {
              final emoteSetId = assetsStore.sevenTvEmoteSetId;
              if (emoteSetId != null) {
                listenToSevenTVEmoteSet(emoteSetId: emoteSetId);
              }
            }
          });
        },
      ),
    );

    // Start chat delay countdown when toggling video on, cancel when off
    reactions.add(
      reaction((_) => settings.showVideo, (showVideo) {
        if (showVideo && settings.effectiveChatDelay > 0) {
          _startChatDelayCountdown();
        } else if (!showVideo) {
          _flushPendingDelayedCallbacks();
          _cancelChatDelayCountdown();
          _chatDelaySyncCompleted = false;
        }
      }),
    );

    // Start chat delay countdown when chatDelay is set (for auto sync mode)
    // Cancel countdown if delay becomes 0
    reactions.add(
      reaction((_) => settings.effectiveChatDelay, (chatDelay) {
        if (chatDelay == 0) {
          _flushPendingDelayedCallbacks();
          _cancelChatDelayCountdown();
          _chatDelaySyncCompleted = false;
        } else if (settings.autoSyncChatDelay &&
            settings.showVideo &&
            chatDelay > 0 &&
            !_chatDelaySyncCompleted) {
          _startChatDelayCountdown();
        }
      }),
    );

    assetsStore.init();

    _messages.add(
      IRCMessage.createNotice(message: L10n.current.chatConnecting),
    );

    // IRC first: the history is put above whatever live chat has shown by
    // the time it arrives, so it never holds the chat back.
    connectToChat();
    unawaited(loadHistory());

    // Tell the scrollController to determine when auto-scroll should be enabled or disabled.
    scrollController.addListener(() {
      // If the scroll position is at the latest message (maximum possible), enable autoscroll.
      // Else if the position is before the latest message (not at the edge), disable autoscroll.
      if (scrollController.position.pixels <= 0) {
        _autoScroll = true;
      } else if (scrollController.position.pixels > 0) {
        _autoScroll = false;
      }
    });

    textFieldFocusNode.addListener(() {
      if (textFieldFocusNode.hasFocus) {
        // Hide the emote menu if it is currently shown.
        if (assetsStore.showEmoteMenu) assetsStore.showEmoteMenu = false;
      }

      // Un-expand the chat when unfocusing.
      if (!textFieldFocusNode.hasFocus) expandChat = false;
    });

    // Add a listener to the textfield that will show/hide the autocomplete bar if focused.
    // Will also rebuild the autocomplete bar when typing, refreshing the results as the user types.
    textController.addListener(() {
      _inputText = textController.text;

      _showEmoteAutocomplete =
          !_showMentionAutocomplete &&
          textFieldFocusNode.hasFocus &&
          textController.text.split(' ').last.isNotEmpty;

      _showSendButton = textController.text.isNotEmpty;
      _showMentionAutocomplete =
          textFieldFocusNode.hasFocus &&
          textController.text.split(' ').last.startsWith('@');
    });
  }

  void _enqueueDelayedCallback(
    ChatDelayQueue queue,
    void Function() callback,
  ) => queue.add(callback, now: clock.now());

  /// The delay is read now, not when each payload arrived: it follows the
  /// video latency, which shrinks when the player catches up.
  void _flushDueDelayedCallbacks() {
    final now = clock.now();
    final delay = Duration(seconds: _chatDelaySeconds);
    _pendingChatCallbacks.flushDue(now, delay);
    _pendingSevenTVCallbacks.flushDue(now, delay);
  }

  void _flushPendingDelayedCallbacks() {
    _pendingChatCallbacks.flushAll();
    _pendingSevenTVCallbacks.flushAll();
  }

  /// Handle and process the provided string-representation of the IRC data.
  ///
  /// If a message, parses the IRC data into an [IRCMessage] and handles it based on the [Command].
  /// Else if a PING request, sends back the PONG to keep the connection alive.
  @action
  void _handleIRCData(String data) {
    // The IRC data can contain more than one message separated by CRLF.
    // To account for this, split by CRLF, then loop and process each message.
    for (final message in data.trimRight().split('\r\n')) {
      // debugPrint('$message\n');
      if (message.startsWith('@')) {
        final parsedIRCMessage = IRCMessage.fromString(
          message,
          userLogin: auth.user.details?.login,
        );

        // Already shown from the history loaded on joining.
        final command = parsedIRCMessage.command;
        if ((command == Command.privateMessage ||
                command == Command.userNotice) &&
            _historyIds.contains(parsedIRCMessage.tags['id'])) {
          continue;
        }

        if (parsedIRCMessage.user != null) {
          chatDetailsStore.chatUsers.add(parsedIRCMessage.user!);
        }

        // Filter messages from any blocked users if not a moderator or not the channel owner.
        if (!_userState.mod &&
            channelName != auth.user.details?.login &&
            auth.user.blockedUsers
                .where(
                  (blockedUser) =>
                      blockedUser.userLogin == parsedIRCMessage.user,
                )
                .isNotEmpty) {
          continue;
        }

        // Filter messages containing any muted words (only this one: the
        // rest of the batch goes on).
        final text = parsedIRCMessage.message;
        final clears =
            parsedIRCMessage.command == Command.clearChat ||
            parsedIRCMessage.command == Command.clearMessage;
        if (text != null &&
            !clears &&
            isMuted(
              text,
              settings.mutedWords,
              wholeWord: settings.matchWholeWord,
            )) {
          continue;
        }

        switch (parsedIRCMessage.command) {
          case Command.privateMessage:
          case Command.notice:
          case Command.userNotice:
            // Check if this is a rejection notice for a pending message
            if (parsedIRCMessage.command == Command.notice &&
                _isWaitingForAck) {
              final msgId = parsedIRCMessage.tags['msg-id'];
              if (msgId != null && isSendRejection(msgId)) {
                // Message was rejected - clear pending but preserve text field for retry
                _sendingTimeoutTimer?.cancel();
                _isWaitingForAck = false;
                toSend = null;

                if (parsedIRCMessage.message case final text?) {
                  HapticFeedback.heavyImpact();
                  updateNotification(
                    serverNoticeText(msgId, text, L10n.current),
                  );
                }
                _applyRejection(msgId, parsedIRCMessage.message);
              }
            }
            if (parsedIRCMessage.command == Command.notice) {
              _wordServerNotice(parsedIRCMessage);
            }

            // Update shared chat mode based on source-room-id tag presence
            final wasShared = _isInSharedChatMode;
            _isInSharedChatMode = parsedIRCMessage.tags.containsKey(
              'source-room-id',
            );
            if (_isInSharedChatMode) {
              _announceSharedChat(parsedIRCMessage);
            } else if (parsedIRCMessage.command == Command.privateMessage) {
              _sawUnsharedMessage = true;
            }
            // On transition into shared chat mode, fetch assets for participants.
            if (!wasShared && _isInSharedChatMode) {
              assetsStore.fetchSharedChatAssets(
                channelId: channelId,
                headers: auth.headersTwitch,
                onEmoteError: (error) {
                  debugPrint(error.toString());
                  return <Emote>[];
                },
                onBadgeError: (error) {
                  debugPrint(error.toString());
                  return <ChatBadge>[];
                },
                showTwitchEmotes: settings.showTwitchEmotes,
                showTwitchBadges: settings.showTwitchBadges,
                show7TVEmotes: settings.show7TVEmotes,
                showBTTVEmotes: settings.showBTTVEmotes,
                showFFZEmotes: settings.showFFZEmotes,
                showFFZBadges: settings.showFFZBadges,
              );
            }
            // Every gift of a gift bomb gets its own line, as on Twitch,
            // unless the viewer collapses them into their header.
            final notice = parsedIRCMessage.command == Command.userNotice
                ? parsedIRCMessage.notice
                : null;
            if (notice != null) {
              final decision = _trackGiftBomb(parsedIRCMessage, notice);
              final hidden = _hidesGift(notice);
              if (decision.banner case final banner? when !hidden) {
                _latestGiftBomb = banner;
              }
              if (IncomingRaid.fromNotice(notice, channelId: channelId)
                  case final raid?) {
                _latestIncomingRaid = raid;
              }
              if (!decision.show || hidden) continue;
            }

            unawaited(
              alertChatMention(
                parsedIRCMessage,
                enabled: settings.mentionNotifications,
                ownLogin: auth.user.details?.login,
                channelId: channelId,
                channelLogin: channelName,
                channelName: displayName,
                alerts: mentionAlerts ?? MentionAlerts.shared,
              ),
            );

            messageBuffer.add(parsedIRCMessage);
            if (changesOwnEmotes(
              parsedIRCMessage,
              ownUserId: auth.user.details?.id,
            )) {
              scheduleEmoteRefresh();
            }
            _calloutAnimatedEmotes(parsedIRCMessage);
            break;
          case Command.clearChat:
            if (_historyPending) _moderationBeforeHistory.add(parsedIRCMessage);
            if (IRCMessage.clearChat(
              messages: _messages,
              bufferedMessages: messageBuffer,
              ircMessage: parsedIRCMessage,
            )) {
              _linesMarkedInPlace = true;
            }
            if (canModerate) {
              modTools.noteClearChat(
                parsedIRCMessage.tags['target-user-id'],
                int.tryParse(parsedIRCMessage.tags['ban-duration'] ?? ''),
              );
            }
            if (settings.showModerationNotices) {
              _addModerationNotice(parsedIRCMessage, messageBuffer);
            }
            final own = ownClearChat(
              parsedIRCMessage,
              ownUserId: auth.user.details?.id,
              now: DateTime.now(),
            );
            if (own != null) {
              _banned = own.banned;
              _timedOutUntil = own.until;
              _updateRestriction();
            }
            break;
          case Command.clearMessage:
            if (_historyPending) _moderationBeforeHistory.add(parsedIRCMessage);
            if (IRCMessage.clearMessage(
              messages: _messages,
              bufferedMessages: messageBuffer,
              ircMessage: parsedIRCMessage,
            )) {
              _linesMarkedInPlace = true;
            }
            if (ownDeletedMessageNotice(
                  parsedIRCMessage,
                  ownLogin: auth.user.details?.login,
                )
                case final notice?) {
              messageBuffer.add(notice);
            }
            break;
          case Command.roomState:
            chatDetailsStore.roomState = chatDetailsStore.roomState
                .fromIRCMessage(parsedIRCMessage);
            _forgetFollowRefusalWhenOpen();
            _updateRestriction();
            continue;
          case Command.userState:
            _userState = _userState.fromIRCMessage(parsedIRCMessage);
            _noteEmoteSets(parsedIRCMessage);

            // USERSTATE arrival confirms message was sent, even without id tag
            if (toSend != null) {
              final messageId = parsedIRCMessage.tags['id'];
              if (messageId != null) {
                toSend!.tags['id'] = messageId;
              } else {
                // Fallback ID for edge cases where Twitch doesn't provide one
                toSend!.tags['id'] =
                    'local-${DateTime.now().millisecondsSinceEpoch}';
              }
              messageBuffer.add(toSend!);
              toSend = null;
              // Reset sending state and clear text/reply after successful confirmation
              _sendingTimeoutTimer?.cancel();
              _isWaitingForAck = false;
              textController.clear();
              replyingToMessage = null;
              // Sent: not banned, and slow mode counts from now.
              _banned = false;
              _refusedFor = null;
              _lastSentAt = DateTime.now();
            }
            _updateRestriction();
            break;
          case Command.globalUserState:
            final setIds = parsedIRCMessage.tags['emote-sets']?.split(',');
            _globalEmoteSets = setIds;
            unawaited(_loadUserEmotes(setIds));
            continue;
          case Command.none:
            debugPrint('Unknown command: ${parsedIRCMessage.command}');
            continue;
        }

        if (!_autoScroll) {
          // While autoscroll is disabled, occasionally move messages from the buffer to the messages to prevent a memory leak.
          if (messageBuffer.length >= _messagesToRemove) {
            _messages.addAll(messageBuffer);
            messageBuffer.clear();
          }
        }

        // If the message limit is reached, remove the oldest messages.
        if (_messages.length >= _messageLimit) {
          _messages = _messages.sublist(_messagesToRemove).asObservable();
        }
      } else if (message == 'PING :tmi.twitch.tv') {
        _channel?.sink.add('PONG :tmi.twitch.tv');
        return;
      } else if (message.contains('Welcome, GLHF!')) {
        // A new connection (maybe as another account): what Twitch says
        // from here on decides the viewer's restrictions.
        _resetOwnRestrictions();
        messageBuffer.add(
          IRCMessage.createNotice(
            message: L10n.current.chatWelcome(
              name: getReadableName(displayName, channelName),
            ),
          ),
        );
        if (_pendingArrival case final arrival?) {
          _pendingArrival = null;
          messageBuffer.add(IRCMessage.raidWelcome(arrival));
        }

        // Activate the message buffer.
        // Cancel any existing timer before creating a new one to prevent duplicates on reconnect.
        _messageBufferTimer?.cancel();
        // Create a timer that will add messages from the buffer every 200 milliseconds.
        _messageBufferTimer = Timer.periodic(
          const Duration(milliseconds: 200),
          (timer) => addMessages(),
        );

        // Set up 7TV real-time listener (assets already fetched in connectToChat)
        if (settings.show7TVEmotes) {
          final emoteSetId = assetsStore.sevenTvEmoteSetId;
          if (emoteSetId != null && !_shouldDisconnect) {
            listenToSevenTVEmoteSet(emoteSetId: emoteSetId);
          }
        }

        // Transform reconnect message to summary on successful connection
        if (_reconnectMessage != null && _reconnectStartTime != null) {
          final elapsed = DateTime.now()
              .difference(_reconnectStartTime!)
              .inSeconds;
          final attempts = _retries;
          final index = _messages.indexOf(_reconnectMessage!);
          if (index != -1) {
            _messages[index] = IRCMessage.createNotice(
              message: L10n.current.chatReconnected(
                attempts: attempts,
                seconds: elapsed,
              ),
            );
          }
        }
        _reconnectMessage = null;
        _reconnectStartTime = null;

        // Reset exponential backoff if successfully connected.
        _retries = 0;
        _backoffTime = 0;

        // Mark connection as established for UI
        _isConnected = true;
        _hasConnected = true;
      }
    }
  }

  // Fetch the assets used in chat including badges and emotes.
  @action
  Future<void> getAssets() async {
    // Prepare common error handlers to avoid repetition.
    List<Emote> onEmoteError(dynamic error) {
      debugPrint(error.toString());
      return <Emote>[];
    }

    List<ChatBadge> onBadgeError(dynamic error) {
      debugPrint(error.toString());
      return <ChatBadge>[];
    }

    final baseAssets = assetsStore.assetsFuture(
      channelId: channelId,
      headers: auth.headersTwitch,
      onEmoteError: onEmoteError,
      onBadgeError: onBadgeError,
      showTwitchEmotes: settings.showTwitchEmotes,
      showTwitchBadges: settings.showTwitchBadges,
      show7TVEmotes: settings.show7TVEmotes,
      showBTTVEmotes: settings.showBTTVEmotes,
      showBTTVBadges: settings.showBTTVBadges,
      showFFZEmotes: settings.showFFZEmotes,
      showFFZBadges: settings.showFFZBadges,
    );

    // If shared chat mode is active, also refresh participant assets in parallel.
    if (_isInSharedChatMode) {
      final sharedAssets = assetsStore.fetchSharedChatAssets(
        channelId: channelId,
        headers: auth.headersTwitch,
        onEmoteError: onEmoteError,
        onBadgeError: onBadgeError,
        showTwitchEmotes: settings.showTwitchEmotes,
        showTwitchBadges: settings.showTwitchBadges,
        show7TVEmotes: settings.show7TVEmotes,
        showBTTVEmotes: settings.showBTTVEmotes,
        showFFZEmotes: settings.showFFZEmotes,
        showFFZBadges: settings.showFFZBadges,
        force: true,
      );
      await Future.wait([baseAssets, sharedAssets]);
    } else {
      await baseAssets;
    }
  }

  /// Re-enables [_autoScroll] and jumps to the latest message.
  @action
  void resumeScroll() {
    _autoScroll = true;

    // Jump to the latest message (bottom of the list/chat).
    scrollController.jumpTo(0);

    // Add a post frame callback in the event a messages is added at the same time.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollController.jumpTo(0);
    });
  }

  @action
  void listenToSevenTVEmoteSet({required String emoteSetId}) {
    final subscribePayload = SevenTVEvent(
      op: 35,
      d: SevenTVEventData(
        type: 'emote_set.update',
        condition: {'object_id': emoteSetId},
      ),
    );

    _sevenTVChannel?.sink.close(1000);
    _sevenTVChannel = _connectSocket(Uri.parse('wss://events.7tv.io/v3'));

    void listener(dynamic data) {
      // debugPrint(data);
      final decoded = jsonDecode(data);

      final event = SevenTVEvent.fromJson(decoded);

      final body = event.d.body;
      if (event.d.type != 'emote_set.update' || body == null) return;

      if (body.pushed != null) {
        final pushedEmote = body.pushed?.first.value;

        if (pushedEmote == null) return;

        final emote = Emote.from7TV(pushedEmote, EmoteType.sevenTVChannel);

        assetsStore.addChannelEmote(emote);

        messageBuffer.add(
          IRCMessage.createNotice(
            message: L10n.current.chatSevenTvEmoteAdded(
              name: getReadableName(
                body.actor.displayName,
                body.actor.username,
              ),
              emote: emote.name,
            ),
          ),
        );
      } else if (body.pulled != null) {
        final pulledEmote = body.pulled?.first.oldValue;

        if (pulledEmote == null) return;

        assetsStore.removeChannelEmote(pulledEmote.name);

        messageBuffer.add(
          IRCMessage.createNotice(
            message: L10n.current.chatSevenTvEmoteRemoved(
              name: getReadableName(
                body.actor.displayName,
                body.actor.username,
              ),
              emote: pulledEmote.name,
            ),
          ),
        );
      }
    }

    // Cancel previous subscription if exists
    _sevenTVChannelListener?.cancel();
    _sevenTVChannelListener = _sevenTVChannel?.stream.listen(
      (data) {
        if (!_hasActiveChatDelay) {
          // Whatever is still held goes first, so nothing overtakes it.
          _pendingSevenTVCallbacks.flushAll();
          listener(data);
        } else {
          _enqueueDelayedCallback(
            _pendingSevenTVCallbacks,
            () => listener(data),
          );
        }
      },
      onError: (error) {
        debugPrint('7TV events error: ${error.toString()}');
        Telemetry.recordError(
          error,
          StackTrace.current,
          reason: '7TV WebSocket error',
        );
      },
      // Held events stay: each is whole and releases on schedule, in order.
      onDone: () => debugPrint('7TV events done'),
    );

    _sevenTVChannel?.sink.add(jsonEncode(subscribePayload));
  }

  @action
  Future<void> connectToChat({bool isReconnect = false}) async {
    // Fetch assets first so they're available for all messages
    getAssets().catchError(
      (e) => debugPrint('Failed to fetch chat assets: $e'),
    );

    // Cancel existing listener to prevent duplicate message processing
    _channelListener?.cancel();
    // Held chat is kept across reconnects: each payload is whole (a dropped
    // CLEARMSG or CLEARCHAT would leave a deleted or timed-out message on
    // screen), and they release on schedule, in order.

    _channel?.sink.close(1000);
    _channel = _connectSocket(Uri.parse('wss://irc-ws.chat.twitch.tv:443'));

    // Only show chat delay countdown on initial connection or video toggle, not on reconnects
    if (!isReconnect && _hasActiveChatDelay) {
      _startChatDelayCountdown();
    }

    // Listen for new messages and forward them to the handler.
    _channelListener = _channel?.stream.listen(
      (data) {
        final dataStr = data.toString();

        // Process immediately if delay is disabled or command should bypass delay
        if (!_hasActiveChatDelay) {
          // Whatever is still held goes first, so nothing overtakes it.
          _pendingChatCallbacks.flushAll();
          _handleIRCData(dataStr);
          return;
        }
        final split = splitDelayedIrc(dataStr);
        if (split.now.isNotEmpty) _handleIRCData(split.now);
        if (split.held.isNotEmpty) {
          _enqueueDelayedCallback(_pendingChatCallbacks, () {
            _handleIRCData(split.held);
          });
        }
      },
      onError: (error) {
        debugPrint('Chat error: ${error.toString()}');
        Telemetry.recordError(
          error,
          StackTrace.current,
          reason: 'IRC WebSocket error',
        );
      },
      onDone: () async {
        // Mark connection as disconnected for UI
        _isConnected = false;

        // Cancel chat delay countdown when disconnecting
        _cancelChatDelayCountdown();
        _chatDelaySyncCompleted = false;

        if (_shouldDisconnect) {
          _sevenTVChannel?.sink.close(1000);
          return;
        }

        if (_retries >= _maxRetries) {
          Telemetry.log(
            'WebSocket reconnection failed after $_maxRetries attempts',
          );
          // Remove the reconnect message before showing final disconnect notice
          if (_reconnectMessage != null) {
            final index = _messages.indexOf(_reconnectMessage!);
            if (index != -1) _messages.removeAt(index);
            _reconnectMessage = null;
          }
          _reconnectStartTime = null;

          // Add directly to messages, not buffer, so it shows immediately
          _messages.add(
            IRCMessage.createNotice(
              message: L10n.current.chatDisconnected,
              actionCallback: () {
                _retries = 0;
                _backoffTime = 0;
                connectToChat(isReconnect: true);
              },
              actionLabel: L10n.current.chatReconnect,
            ),
          );
          return;
        }

        // Increment the retry count.
        _retries++;
        Telemetry.log('WebSocket reconnecting: attempt $_retries/$_maxRetries');

        // Start exponential backoff only after first failed attempt (capped at 8s).
        // First retry is immediate to catch brief network hiccups.
        if (_retries > 1) {
          final newBackoff = _backoffTime == 0 ? 1 : _backoffTime * 2;
          _backoffTime = newBackoff > 8 ? 8 : newBackoff;
        }

        // Helper to update the single reconnect message in place (or add if first time)
        void updateReconnectMessage(String text) {
          final msg = IRCMessage.createNotice(message: text);
          if (_reconnectMessage == null) {
            _reconnectStartTime ??=
                DateTime.now(); // Record when reconnection started
            _reconnectMessage = msg;
            _messages.add(_reconnectMessage!);
          } else {
            final index = _messages.indexOf(_reconnectMessage!);
            if (index != -1) {
              _reconnectMessage = msg;
              _messages[index] = _reconnectMessage!;
            } else {
              // Reference was lost (e.g., message limit cleanup) - re-add
              _reconnectMessage = msg;
              _messages.add(_reconnectMessage!);
            }
          }
        }

        // Countdown phase (if backoff time > 0)
        if (_backoffTime > 0) {
          var remainingSeconds = _backoffTime;
          updateReconnectMessage(
            L10n.current.chatReconnectingIn(
              seconds: remainingSeconds,
              attempt: _retries,
              max: _maxRetries,
            ),
          );

          // Update countdown every second
          await Future.doWhile(() async {
            await Future.delayed(const Duration(seconds: 1));

            // Abort countdown if dispose was called
            if (_shouldDisconnect) {
              if (_reconnectMessage != null) {
                final index = _messages.indexOf(_reconnectMessage!);
                if (index != -1) _messages.removeAt(index);
                _reconnectMessage = null;
              }
              _reconnectStartTime = null;
              return false; // Exit loop
            }

            remainingSeconds--;

            if (remainingSeconds > 0) {
              updateReconnectMessage(
                L10n.current.chatReconnectingIn(
                  seconds: remainingSeconds,
                  attempt: _retries,
                  max: _maxRetries,
                ),
              );
              return true; // Continue loop
            }
            return false; // Exit loop
          });

          // Don't proceed with reconnection if disposed
          if (_shouldDisconnect) return;
        }

        // Attempting phase - update same message, no add/remove
        updateReconnectMessage(
          L10n.current.chatReconnecting(attempt: _retries, max: _maxRetries),
        );

        _channelListener?.cancel();
        connectToChat(isReconnect: true);
      },
    );

    // The list of messages sent to the IRC WebSocket channel to connect and join.
    final commands = [
      // Request the tags and commands capabilities.
      // This will display tags containing metadata along with each IRC message.
      'CAP REQ :twitch.tv/tags twitch.tv/commands',

      // The OAuth token in order to connect, default or user token.
      'PASS oauth:${auth.token}',

      // The nickname for the connecting user. 'justinfan888' is the Twitch default if not logged in.
      'NICK ${auth.isLoggedIn ? auth.user.details!.login : 'justinfan888'}',

      // Join the desired channel's room.
      'JOIN #$channelName',
    ];

    // Send each command in order.
    for (final command in commands) {
      _channel?.sink.add(command);
    }
  }

  @action
  void addMessages() {
    _flushDueDelayedCallbacks();

    final marked = _linesMarkedInPlace;
    _linesMarkedInPlace = false;

    if (!_autoScroll || messageBuffer.isEmpty) {
      // Lines marked in place, and no new line to report the change.
      if (marked) _messages = ObservableList.of(_messages);
      return;
    }

    _messages.addAll(messageBuffer);
    messageBuffer.clear();
  }

  /// Cancels the chat delay countdown and removes the countdown message.
  @action
  void _cancelChatDelayCountdown() {
    _chatDelayCountdownTimer?.cancel();
    _chatDelayCountdownTimer = null;

    // Remove the countdown message if it exists
    if (_countdownMessage != null) {
      _messages.remove(_countdownMessage);
      _countdownMessage = null;
    }
  }

  /// Starts and manages the chat delay countdown message.
  @action
  void _startChatDelayCountdown() {
    // Cancel any existing countdown first (prevents duplicate messages)
    _cancelChatDelayCountdown();

    // Flush any buffered messages first to ensure countdown is at the bottom
    if (messageBuffer.isNotEmpty) {
      _messages.addAll(messageBuffer);
      messageBuffer.clear();
    }

    var remainingSeconds = _chatDelaySeconds;

    // Create and store reference to the countdown message
    _countdownMessage = IRCMessage.createNotice(
      message: L10n.current.chatSyncIn(seconds: remainingSeconds),
    );
    _messages.add(_countdownMessage!);

    // Update countdown every second
    _chatDelayCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      remainingSeconds--;

      // Use runInAction for proper MobX reactivity in async callbacks
      runInAction(() {
        // Check if countdown message still exists in the list
        // (could be removed by message limit cleanup)
        if (_countdownMessage == null ||
            !_messages.contains(_countdownMessage)) {
          timer.cancel();
          _countdownMessage = null;
          _chatDelayCountdownTimer = null;
          return;
        }

        final index = _messages.indexOf(_countdownMessage!);
        if (index != -1) {
          if (remainingSeconds > 0) {
            // Create new message and update reference
            _countdownMessage = IRCMessage.createNotice(
              message: L10n.current.chatSyncIn(seconds: remainingSeconds),
            );
            _messages[index] = _countdownMessage!;
          } else {
            // Remove countdown message when done
            _messages.removeAt(index);
            _countdownMessage = null;
            _chatDelayCountdownTimer = null;
            _chatDelaySyncCompleted = true;
            timer.cancel();
          }
        } else {
          _countdownMessage = null;
          _chatDelayCountdownTimer = null;
          timer.cancel();
        }
      });
    });
  }

  /// Sends the given string message by the logged-in user and adds it to [_messages].
  @action
  void sendMessage(String message) {
    // Do not send if the message is blank/empty.
    if (message.isEmpty) return;

    // The rules come first, however the message was typed; the text stays.
    if (chatRules?.gate() ?? false) return;

    // Twitch drops longer messages (text set by code skips the input's
    // limit).
    if (message.characters.length > kChatMessageMaxLength) {
      updateNotification(
        L10n.current.chatMessageTooLong(max: kChatMessageMaxLength),
      );
      return;
    }

    // Slash commands run here: Twitch ignores them over IRC (except /me).
    final command = parseChatCommand(message);
    if (command is! SendAsIs) {
      if (_runningCommand) {
        updateNotification(L10n.current.chatWaitCommand);
        return;
      }
      _runningCommand = true;
      unawaited(
        _runCommand(
          command,
          message,
        ).whenComplete(() => _runningCommand = false),
      );
      return;
    }

    // Prevent double-sending while waiting for server acknowledgment
    if (_isWaitingForAck) {
      HapticFeedback.mediumImpact();
      updateNotification(L10n.current.chatWaitMessage);
      return;
    }

    if (_channel == null || _channel?.closeCode != null) {
      messageBuffer.add(
        IRCMessage.createNotice(
          message: L10n.current.chatCannotSendDisconnected,
        ),
      );
      return;
    }

    // Set waiting state for UI feedback
    _isWaitingForAck = true;

    // Send the message to the IRC chat room. The parent's id comes from
    // chat (live, Twitch's history or a third party's): it is sent only if
    // it looks like an id, so it cannot add a command to the line.
    final replyId = replyingToMessage?.tags['id'];
    final replyTo = replyId != null && _replyId.hasMatch(replyId)
        ? replyId
        : null;
    _channel?.sink.add(
      '${replyTo != null ? '@reply-parent-msg-id=$replyTo ' : ''}PRIVMSG #$channelName :$message',
    );

    // Text field and reply state cleared on USERSTATE confirmation (not optimistically)
    // to preserve message text if Twitch rejects it (e.g., slow mode)

    // Start timeout timer in case server doesn't respond (network failure)
    // Must be outside userStateString conditional to always have a safety net
    _sendingTimeoutTimer?.cancel();
    _sendingTimeoutTimer = Timer(const Duration(seconds: 10), () {
      // Guard against execution after disposal
      if (_shouldDisconnect) return;

      if (_isWaitingForAck) {
        _isWaitingForAck = false;
        toSend = null;
        HapticFeedback.heavyImpact();
        updateNotification(L10n.current.chatMaybeNotSent);
      }
    });

    // Obtain the logged-in user's appearance in chat with USERSTATE and create the full message to render.
    var userStateString = _userState.raw;
    if (userStateString != null) {
      final action = RegExp(r'^[/.]me\s', caseSensitive: false);
      if (action.hasMatch(message)) {
        userStateString +=
            ' :\x01ACTION ${message.replaceRange(0, 3, '').trim()}\x01';
      } else {
        userStateString +=
            ' :${replyingToMessage?.tags['display-name'] != null ? '@${replyingToMessage!.tags['display-name']} ' : ''}${message.trim()}';
      }

      final userChatMessage = IRCMessage.fromString(userStateString);
      userChatMessage.localEmotes?.addAll(assetsStore.userEmoteToObject);
      if (auth.isLoggedIn && auth.user.details != null) {
        userChatMessage.tags['user-id'] = auth.user.details!.id;
      }

      if (replyingToMessage != null && replyTo != null) {
        userChatMessage.tags['reply-parent-msg-id'] = replyTo;
        userChatMessage.tags['reply-parent-display-name'] =
            replyingToMessage!.tags['display-name'] ?? '';
        userChatMessage.tags['reply-parent-msg-body'] =
            replyingToMessage!.message ?? '';
      }

      // Ensure a timestamp so merged-mode sorting works correctly.
      userChatMessage.tags['tmi-sent-ts'] ??=
          '${DateTime.now().millisecondsSinceEpoch}';

      toSend = userChatMessage;
    }
  }

  /// Adds the given [emote] to the chat textfield.
  @action
  void addEmote(Emote emote, {bool autocompleteMode = false}) {
    if (textController.text.isEmpty || textController.text.endsWith(' ')) {
      textController.text += '${emote.name} ';
    } else if (autocompleteMode &&
        _showEmoteAutocomplete &&
        textController.text.endsWith('')) {
      final split = textController.text.split(' ')
        ..removeLast()
        ..add('${emote.name} ');

      textController.text = split.join(' ');
    } else {
      textController.text += ' ${emote.name} ';
    }

    assetsStore.recentEmotes
      ..removeWhere(
        (recentEmote) =>
            recentEmote.name == emote.name && recentEmote.type == emote.type,
      )
      ..insert(0, emote);

    textController.selection = TextSelection.fromPosition(
      TextPosition(offset: textController.text.length),
    );
  }

  /// Cancels the previous notification/timer and creates a new one with the provided [notificationMessage].
  @action
  void updateNotification(String notificationMessage) {
    // Cancel the previous notification to prevent the notification from phasing in and out
    // when copying messages repeatedly.
    _notificationTimer?.cancel();

    // Set the new notification message and create a new timer that will dismiss it after 3 seconds.
    _notification = notificationMessage;
    _notificationTimer = Timer(
      const Duration(seconds: 5),
      () => _notification = null,
    );
  }

  /// Clears the current notification immediately.
  @action
  void clearNotification() {
    _notificationTimer?.cancel();
    _notification = null;
  }

  /// Updates the sleep timer with the given [duration].
  /// Calls [onTimerFinished] when the sleep timer completes.
  @action
  void updateSleepTimer({
    required Duration duration,
    required VoidCallback onTimerFinished,
  }) {
    // If there is an ongoing timer, cancel it since it'll be replaced.
    if (sleepTimer != null) cancelSleepTimer();

    // Update the new time remaining
    timeRemaining = duration;

    // Set a periodic timer that will update the time remaining every second.
    sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // If the timer is up, cancel the timer and exit the app.
      if (timeRemaining.inSeconds == 0) {
        timer.cancel();
        onTimerFinished();
        return;
      }

      // Decrement the time remaining.
      timeRemaining = Duration(seconds: timeRemaining.inSeconds - 1);
    });
  }

  /// Cancels the sleep timer and resets the time remaining.
  @action
  void cancelSleepTimer() {
    sleepTimer?.cancel();
    timeRemaining = const Duration();
  }

  /// [line] (one IRC line) tagged `historical=1`: any other `historical`
  /// tag it carries (`historical=0`, an empty one) is replaced, so a line
  /// cannot pass for live.
  static String markHistorical(String line) {
    if (!line.startsWith('@')) return '@historical=1 $line';
    final end = line.indexOf(' ');
    final tags = (end == -1 ? line.substring(1) : line.substring(1, end)).split(
      ';',
    );
    bool isMark(String tag) =>
        tag == 'historical' || tag.startsWith('historical=');
    final marks = tags.where(isMark);
    if (marks.isNotEmpty && marks.every((tag) => tag == 'historical=1')) {
      return line;
    }
    final rest = tags.where((tag) => tag.isNotEmpty && !isMark(tag)).join(';');
    final tail = end == -1 ? '' : line.substring(end);
    return rest.isEmpty ? '@historical=1$tail' : '@historical=1;$rest$tail';
  }

  bool _hidesGift(UserNotice notice) =>
      settings.hideGiftSubNotices && notice.isGiftNotice;

  /// Hands [notice] (of [message]) to the gift-bomb tracker, remembering
  /// its id so the same notice is never counted twice.
  GiftBombDecision _trackGiftBomb(IRCMessage message, UserNotice notice) {
    if (message.tags['id'] case final id?) {
      _trackedNoticeIds.add(id);
      if (_trackedNoticeIds.length > _maxTrackedNotices) {
        _trackedNoticeIds.remove(_trackedNoticeIds.first);
      }
    }
    return _giftBombs.onNotice(
      notice,
      collapse: settings.collapseGiftBombs,
      channelId: channelId,
    );
  }

  /// The people whose messages stay out of this chat, as live: the ones
  /// the viewer blocked, unless the viewer moderates it or owns it (who
  /// sees everything said in it).
  ({Set<String> logins, Set<String> ids}) get _hiddenSenders {
    if (_userState.mod || channelName == auth.user.details?.login) {
      return (logins: const {}, ids: const {});
    }
    final blocked = auth.user.blockedUsers;
    return (
      logins: {for (final user in blocked) user.userLogin.toLowerCase()},
      ids: {for (final user in blocked) user.userId},
    );
  }

  bool _muted(String text) =>
      isMuted(text, settings.mutedWords, wholeWord: settings.matchWholeWord);

  /// Shows the chat said before joining, at the top, the way the official
  /// app does: Twitch's own history (the `ChatHistory` query, read with the
  /// viewer's twitch.tv web token). Only when Twitch gives none (no web
  /// token, a failure, an empty answer) and the viewer turned on "Fallback
  /// chat history (third-party)", the third-party recent-messages service.
  ///
  /// The history goes in one insert above everything shown, never through
  /// the live path: no chat delay, held messages, sounds, mention or other
  /// notices, raid, celebration, gift-bomb or hype pins, restrictions or
  /// moderation reactions.
  @visibleForTesting
  Future<void> loadHistory() async {
    try {
      var lines = await _twitchHistory();
      if (_shouldDisconnect) return;
      if (lines == null && settings.showRecentMessages) {
        lines = await _recentMessagesHistory();
        if (_shouldDisconnect) return;
      }
      if (lines != null && lines.isNotEmpty) _insertHistory(lines);
    } catch (e) {
      // The chat goes on without history; the type only, never content.
      debugPrint('Chat history not shown: ${e.runtimeType}');
    } finally {
      _historyPending = false;
      _moderationBeforeHistory.clear();
    }
  }

  /// Twitch's history as chat lines, or null when Twitch gave none.
  Future<List<IRCMessage>?> _twitchHistory() async {
    final service = chatHistory;
    final token = auth.twitchWebToken;
    if (service == null || token == null || token.isEmpty) return null;
    final List<ChatHistoryMessage> messages;
    try {
      messages = await service.getRecentMessages(
        channelLogin: channelName,
        channelId: channelId,
        authToken: token,
      );
    } catch (e) {
      debugPrint('Chat history unavailable: ${e.runtimeType}');
      return null;
    }
    if (messages.isEmpty) return null;
    final hidden = _hiddenSenders;
    return history.chatHistoryLines(
      messages,
      channelId: channelId,
      channelLogin: channelName,
      viewerLogin: auth.user.details?.login,
      hiddenLogins: hidden.logins,
      hiddenUserIds: hidden.ids,
      muted: _muted,
    );
  }

  /// The recent-messages service's lines (raw IRC, `historical=1`) as one
  /// history batch, or null when it gave none. Its moderation lines apply
  /// within the batch (a deleted or timed-out message shows so); nothing in
  /// it acts on the chat as if it happened now.
  Future<List<IRCMessage>?> _recentMessagesHistory() async {
    final List<dynamic> raw;
    try {
      raw = await twitchApi.getRecentMessages(userLogin: channelName);
    } catch (e) {
      debugPrint('Failed to fetch recent messages: ${e.runtimeType}');
      return null;
    }
    final hidden = _hiddenSenders;
    // What live chat already showed or counted: such a line is skipped
    // before it reaches the gift-bomb tracker, which would count it again.
    final shown = {
      for (final message in _messages.followedBy(messageBuffer))
        ?message.tags['id'],
      ..._trackedNoticeIds,
    };
    final batch = <IRCMessage>[];
    // Each string is split into lines as IRC is: a line break inside one
    // could otherwise hide a second command in a tag (the reply id).
    final lines = [
      for (final chunk in raw)
        if (chunk is String) ...chunk.split(_lineBreak),
    ];
    for (final line in lines) {
      if (line.isEmpty) continue;
      final IRCMessage message;
      try {
        // History, even when the service leaves out its mark.
        message = IRCMessage.fromString(
          markHistorical(line),
          userLogin: auth.user.details?.login,
        );
      } catch (e) {
        debugPrint('Unreadable recent message: ${e.runtimeType}');
        continue;
      }
      if (shown.contains(message.tags['id'])) continue;
      final user = message.user;
      if (user != null) chatDetailsStore.chatUsers.add(user);
      if (hidden.logins.contains(user?.toLowerCase()) ||
          hidden.ids.contains(message.tags['user-id'])) {
        continue;
      }
      switch (message.command) {
        case Command.privateMessage:
        case Command.notice:
        case Command.userNotice:
          final text = message.message;
          if (text != null && _muted(text)) continue;
          if (message.command == Command.notice) _wordServerNotice(message);
          // A gift bomb's gifts fold into its header as live ones do; a
          // historical bomb never earns the pinned banner.
          final notice = message.command == Command.userNotice
              ? message.notice
              : null;
          if (notice != null &&
              (!_trackGiftBomb(message, notice).show || _hidesGift(notice))) {
            // Folded into its bomb: its live copy must not count again.
            if (message.tags['id'] case final id?) _historyIds.add(id);
            continue;
          }
          batch.add(message);
        case Command.clearChat:
          IRCMessage.clearChat(
            messages: batch,
            bufferedMessages: <IRCMessage>[],
            ircMessage: message,
          );
          if (settings.showModerationNotices) {
            final notice = moderationNoticeLine(
              message,
              hiddenLogins: hidden.logins,
              newestFirst: batch.reversed,
            );
            if (notice != null) batch.add(notice);
          }
        case Command.clearMessage:
          IRCMessage.clearMessage(
            messages: batch,
            bufferedMessages: <IRCMessage>[],
            ircMessage: message,
          );
        default:
          continue;
      }
    }
    return batch.isEmpty ? null : batch;
  }

  /// [lines] with what moderators did live while they were on their way:
  /// timeouts, bans and deletions mark them, and a cleared chat drops every
  /// line said before the clear.
  List<IRCMessage> _applyModerationBeforeHistory(List<IRCMessage> lines) {
    var kept = lines;
    for (final moderation in _moderationBeforeHistory) {
      if (moderation.command == Command.clearMessage) {
        IRCMessage.clearMessage(
          messages: kept,
          bufferedMessages: <IRCMessage>[],
          ircMessage: moderation,
        );
      } else if (moderation.message != null) {
        IRCMessage.clearChat(
          messages: kept,
          bufferedMessages: <IRCMessage>[],
          ircMessage: moderation,
        );
      } else {
        final clearedAt = int.tryParse(moderation.tags['tmi-sent-ts'] ?? '');
        kept = [
          if (clearedAt != null)
            for (final line in kept)
              if ((int.tryParse(line.tags['tmi-sent-ts'] ?? '') ?? 0) >
                  clearedAt)
                line,
        ];
      }
    }
    return kept;
  }

  /// Puts [lines] above everything shown, in one change of the list.
  @action
  void _insertHistory(List<IRCMessage> lines) {
    final fresh = history.insertHistory(
      _messages,
      _applyModerationBeforeHistory(lines),
      alsoShown: messageBuffer,
    );
    for (final line in fresh) {
      if (line.tags['id'] case final id?) _historyIds.add(id);
      if (line.user case final user?) chatDetailsStore.chatUsers.add(user);
    }
    if (_messages.length >= _messageLimit) {
      _messages = _messages
          .sublist(_messages.length - _messageLimit + _messagesToRemove)
          .asObservable();
    }
  }

  /// Closes and disposes all the channels and controllers used by the store.
  void dispose() {
    _shouldDisconnect = true;

    _pendingChatCallbacks.clear();
    _pendingSevenTVCallbacks.clear();

    _messageBufferTimer?.cancel();
    _notificationTimer?.cancel();
    _sendingTimeoutTimer?.cancel();
    _restrictionTimer?.cancel();
    _cancelChatDelayCountdown();
    sleepTimer?.cancel();
    _userCardRequests.close();
    _shoutoutRequests.close();
    _chatSettingsRequests.close();
    _sharedChatBannerTimer?.cancel();
    _emoteRefreshTimer?.cancel();

    _heldMessages?.dispose();
    modTools.dispose();
    chatRules?.dispose();

    // Cancel WebSocket subscriptions
    _channelListener?.cancel();
    _sevenTVChannelListener?.cancel();

    // Close WebSocket channels
    _channel?.sink.close(1000);
    _sevenTVChannel?.sink.close(1000);

    for (final reactionDisposer in reactions) {
      reactionDisposer();
    }

    textFieldFocusNode.dispose();
    textController.dispose();
    scrollController.dispose();

    assetsStore.dispose();
    chatDetailsStore.dispose();
  }

  void _watchHeldMessages(String? userId) {
    _heldMessages?.dispose();
    _heldMessages = null;
    final listen = listenEvents;
    if (listen == null || userId == null) return;
    try {
      _heldMessages = HeldMessageWatcher(
        listen: listen,
        broadcasterId: channelId,
        userId: userId,
        onNotice: (notice) => runInAction(
          () => messageBuffer.add(IRCMessage.createNotice(message: notice)),
        ),
      );
    } on ArgumentError catch (e) {
      debugPrint('Held messages not followed: $e');
    }
  }

  /// Unfocuses the text field.
  @action
  void unfocusInput() {
    textFieldFocusNode.unfocus();
  }

  /// Requests focus for the text field.
  @action
  void safeRequestFocus() {
    textFieldFocusNode.requestFocus();
  }
}
