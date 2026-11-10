import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/bttv_api.dart';
import 'package:onset/apis/ffz_api.dart';
import 'package:onset/apis/seventv_api.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/badges.dart';
import 'package:onset/models/cheermote.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/shared_chat_session.dart';
import 'package:onset/models/third_party_cosmetics.dart';
import 'package:onset/models/third_party_events.dart';
import 'package:onset/models/user.dart';
import 'package:onset/stores/global_assets_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'chat_assets_store.g.dart';

/// The keys of the viewer's Twitch emote sections that are not a channel's
/// ([ChatAssetsStoreBase.userEmoteSectionToEmotes], where a channel's
/// section is keyed by its display name). Keys, not text: the emote menu
/// names them in the language on screen.
abstract final class UserEmoteSection {
  static const channel = 'Channel Emotes';
  static const global = 'Global Emotes';
  static const unlocked = 'Unlocked Emotes';
  static const other = 'Other Channels';
}

class ChatAssetsStore = ChatAssetsStoreBase with _$ChatAssetsStore;

abstract class ChatAssetsStoreBase with Store {
  final TwitchApi twitchApi;
  final BTTVApi bttvApi;
  final FFZApi ffzApi;
  final SevenTVApi sevenTVApi;
  final GlobalAssetsStore globalAssetsStore;

  /// Contains any custom FFZ mod and vip badges for the channel.
  RoomFFZ? get ffzRoomInfo => _ffzRoomInfo;
  set ffzRoomInfo(RoomFFZ? room) {
    _ffzRoomInfo = room;
    _ffzRoomBadgeIdsByUser = room?.badgeIdsByUser ?? const {};
  }

  RoomFFZ? _ffzRoomInfo;
  var _ffzRoomBadgeIdsByUser = const <String, List<String>>{};

  List<ChatBadge>? ffzRoomBadgesFor(String? userId) {
    if (!showFfzRoomBadges || userId == null) return null;
    final badgeIds = _ffzRoomBadgeIdsByUser[userId];
    final definitions = globalAssetsStore.ffzBadgeDefinitions;
    if (badgeIds == null || definitions == null) return null;
    final badges = [
      for (final id in badgeIds) ?definitions[id],
    ];
    return badges.isEmpty ? null : badges;
  }

  String? sevenTvEmoteSetId;

  /// Tracks shared chat participant channels that we've already loaded assets for.
  final Set<String> _loadedSharedChannelIds = <String>{};

  /// Optional: Track 7TV set ids for shared chat participants (keyed by broadcaster id).
  final sharedSevenTvSetIds = ObservableMap<String, String>();

  final channelIdToUserTwitch = ObservableMap<String, UserTwitch>();

  final sharedChatChannelIds = ObservableList<String>();

  @computed
  List<Emote> get bttvEmotes =>
      emoteToObject.values.where((emote) => isBTTV(emote)).toList();

  @computed
  List<Emote> get ffzEmotes =>
      emoteToObject.values.where((emote) => isFFZ(emote)).toList();

  @computed
  List<Emote> get sevenTVEmotes =>
      emoteToObject.values.where((emote) => is7TV(emote)).toList();

  @readonly
  var _recentEmotes = ObservableList<Emote>();

  /// Channel-specific emotes only (not global).
  @readonly
  var _channelEmoteToObject = ObservableMap<String, Emote>();

  /// Channel-specific Twitch badges (overrides globals).
  @readonly
  var _channelTwitchBadges = <String, ChatBadge>{};

  /// The channel's cheermotes, drawn in cheer messages.
  @readonly
  var _cheermotes = Cheermotes.empty;

  /// Combined emotes: global + channel. Channel emotes take precedence.
  @computed
  Map<String, Emote> get emoteToObject {
    final combined = Map<String, Emote>.from(globalAssetsStore.globalEmoteMap);
    combined.addAll(_channelEmoteToObject);
    return combined;
  }

  /// Combined Twitch badges: global + channel. Channel badges take precedence.
  @computed
  Map<String, ChatBadge> get twitchBadgesToObject {
    final combined = Map<String, ChatBadge>.from(
      globalAssetsStore.twitchGlobalBadges,
    );
    combined.addAll(_channelTwitchBadges);
    return combined;
  }

  /// The emotes that are "owned" and may be used by the current user.
  @readonly
  // ignore: prefer_final_fields
  var _userEmoteToObject = <String, Emote>{};

  /// The Twitch emote types mapped to their emotes (i.e., global, specific channels, unlocked).
  @readonly
  // ignore: prefer_final_fields
  var _userEmoteSectionToEmotes = <String, List<Emote>>{};

  /// The map of user IDs to their FFZ badges (from global store).
  Map<String, List<ChatBadge>> get userToFFZBadges =>
      globalAssetsStore.ffzBadges;

  /// The map of user IDs to their 7TV badges.
  Map<String, List<ChatBadge>> get userTo7TVBadges => _userTo7TVBadges;
  final _userTo7TVBadges = ObservableMap<String, List<ChatBadge>>();

  final userTo7TVPaint = ObservableMap<String, NamePaint>();

  final userToPersonalEmotes = ObservableMap<String, Map<String, Emote>>();

  NamePaint? paintFor(String? userId) =>
      userId == null ? null : userTo7TVPaint[userId];

  String? sevenTvUserId;

  String? bttvChannelId;

  var showSevenTvBadges = true;
  var showSevenTvPaints = true;
  var showSevenTvPersonalEmotes = true;
  var showBttvPersonalEmotes = true;
  var showFfzRoomBadges = true;

  void Function(String setId)? onPersonalEmoteSetSeen;

  final _sevenTvPaintDefinitions = <String, NamePaint>{};
  final _sevenTvBadgeDefinitions = <String, ChatBadge>{};
  final _sevenTvPersonalSetOwners = <String, Set<String>>{};
  final _bttvPersonalEmotes = <String, Map<String, Emote>>{};
  final _sevenTvPersonalEmotes = <String, Map<String, Emote>>{};
  final _lookedUpChatters = <String>{};

  bool get _wantsSevenTvLookups =>
      showSevenTvBadges || showSevenTvPaints || showSevenTvPersonalEmotes;

  Map<String, Emote>? personalEmotesFor(String? userId) =>
      userId == null ? null : userToPersonalEmotes[userId];

  Set<String> get sevenTvPersonalSetIds =>
      _sevenTvPersonalSetOwners.keys.toSet();

  /// The map of user IDs to their BTTV badge (from global store).
  Map<String, ChatBadge> get userToBTTVBadges => globalAssetsStore.bttvBadges;

  /// Whether or not the emote menu is visible.
  @observable
  var showEmoteMenu = false;

  bool isBTTV(Emote emote) {
    return emote.type == EmoteType.bttvChannel ||
        emote.type == EmoteType.bttvGlobal ||
        emote.type == EmoteType.bttvShared;
  }

  bool isFFZ(Emote emote) {
    return emote.type == EmoteType.ffzChannel ||
        emote.type == EmoteType.ffzGlobal;
  }

  bool is7TV(Emote emote) {
    return emote.type == EmoteType.sevenTVChannel ||
        emote.type == EmoteType.sevenTVGlobal;
  }

  late final ReactionDisposer _disposeReaction;

  ChatAssetsStoreBase({
    required this.twitchApi,
    required this.bttvApi,
    required this.ffzApi,
    required this.sevenTVApi,
    required this.globalAssetsStore,
  });

  @action
  Future<void> init() async {
    // Retrieve the instance that will allow us to retrieve local search history.
    final prefs = await SharedPreferences.getInstance();

    _recentEmotes =
        prefs
            .getStringList('recent_emotes')
            ?.map((emoteJson) => Emote.fromJson(jsonDecode(emoteJson)))
            .toList()
            .asObservable() ??
        ObservableList<Emote>();

    _disposeReaction = autorun((_) {
      if (_recentEmotes.length > 48) _recentEmotes.removeLast();
      prefs.setStringList(
        'recent_emotes',
        _recentEmotes.map((emote) => jsonEncode(emote)).toList(),
      );
    });
  }

  /// Fetches channel-specific assets (badges and emotes).
  /// Global assets are loaded via [globalAssetsStore] and combined automatically.
  @action
  Future<void> assetsFuture({
    required String channelId,
    required Map<String, String> headers,
    required Function onEmoteError,
    required Function onBadgeError,
    bool showTwitchEmotes = true,
    bool showTwitchBadges = true,
    bool show7TVEmotes = true,
    bool showBTTVEmotes = true,
    bool showBTTVBadges = true,
    bool showFFZEmotes = true,
    bool showFFZBadges = true,
  }) async {
    // Fetch global (cached) and channel-specific assets in parallel
    await Future.wait([
      // Global assets (cached across all tabs - only fetches once)
      globalAssetsStore.ensureLoaded(
        showTwitchEmotes: showTwitchEmotes,
        showTwitchBadges: showTwitchBadges,
        show7TVEmotes: show7TVEmotes,
        showBTTVEmotes: showBTTVEmotes,
        showBTTVBadges: showBTTVBadges,
        showFFZEmotes: showFFZEmotes,
        showFFZBadges: showFFZBadges,
      ),
      // Channel-specific emotes
      Future.wait([
            if (showTwitchEmotes)
              twitchApi
                  .getEmotesChannel(id: channelId)
                  .then((emotes) {
                    _userEmoteSectionToEmotes.update(
                      UserEmoteSection.channel,
                      (existingEmoteSet) => [...existingEmoteSet, ...emotes],
                      ifAbsent: () => emotes.toList(),
                    );
                    return emotes;
                  })
                  .catchError(onEmoteError),
            if (show7TVEmotes)
              sevenTVApi
                  .getChannel(id: channelId)
                  .then((channel) {
                    sevenTvEmoteSetId = channel.setId;
                    sevenTvUserId = channel.userId;
                    return channel.emotes;
                  })
                  .catchError(onEmoteError),
            if (showBTTVEmotes)
              bttvApi
                  .getEmotesChannel(id: channelId)
                  .then((emotes) {
                    bttvChannelId = channelId;
                    return emotes;
                  })
                  .catchError(onEmoteError),
            if (showFFZEmotes)
              ffzApi
                  .getRoomInfo(id: channelId)
                  .then((ffzRoom) {
                    final (roomInfo, emotes) = ffzRoom;
                    ffzRoomInfo = roomInfo;
                    return emotes;
                  })
                  .catchError(onEmoteError),
          ])
          .then((assets) => assets.expand((list) => list))
          .then(
            (emotes) => _channelEmoteToObject = <String, Emote>{
              for (final emote in emotes) emote.name: emote,
            }.asObservable(),
          ),
      // Cheermotes: without them cheers stay text, so a failure is quiet.
      twitchApi
          .getCheermotes(broadcasterId: channelId)
          .then((cheermotes) => _cheermotes = cheermotes)
          .catchError((Object e) {
            debugPrint('Cheermotes unavailable: $e');
            return Cheermotes.empty;
          }),
      // Channel badges (Twitch only - FFZ/BTTV badges are global)
      if (showTwitchBadges)
        twitchApi
            .getBadgesChannel(id: channelId)
            .then((badges) => _channelTwitchBadges = badges)
            .catchError(onBadgeError),
    ]);
  }

  /// Fetch and merge assets for all participants in a shared chat session.
  /// Safe to call multiple times; only new participant channels will be fetched.
  @action
  Future<void> fetchSharedChatAssets({
    required String channelId,
    required Map<String, String> headers,
    required Function onEmoteError,
    required Function onBadgeError,
    bool showTwitchEmotes = true,
    bool showTwitchBadges = true,
    bool show7TVEmotes = true,
    bool showBTTVEmotes = true,
    bool showFFZEmotes = true,
    bool showFFZBadges = true,
    bool force = false,
  }) async {
    if (force) {
      _loadedSharedChannelIds.clear();
      sharedSevenTvSetIds.clear();
    }

    final newParticipantIds = await populateSharedChatParticipants(
      channelId: channelId,
      onBadgeError: onBadgeError,
    );

    if (newParticipantIds.isEmpty) return;

    // Fetch emotes and badges for all new participants in parallel.
    final futures = <Future<void>>[];

    // Add emote futures for each participant.
    futures.addAll(
      newParticipantIds.map(
        (id) =>
            _fetchEmotesForChannel(
              id,
              onEmoteError: onEmoteError,
              showTwitchEmotes: showTwitchEmotes,
              show7TVEmotes: show7TVEmotes,
              showBTTVEmotes: showBTTVEmotes,
              showFFZEmotes: showFFZEmotes,
            ).then((emotes) {
              for (final emote in emotes) {
                _channelEmoteToObject[emote.name] = emote;
              }
            }),
      ),
    );

    // Add badge futures for each participant.
    if (showTwitchBadges) {
      futures.addAll(
        newParticipantIds.map(
          (id) => _fetchBadgesForChannel(id, onBadgeError: onBadgeError),
        ),
      );
    }

    await Future.wait(futures);
  }

  /// Load and cache shared chat participants for a broadcaster.
  /// Returns the list of new participant broadcaster IDs (deduped).
  @action
  Future<List<String>> populateSharedChatParticipants({
    required String channelId,
    required Function onBadgeError,
  }) async {
    SharedChatSession? sharedSession;
    try {
      sharedSession = await twitchApi.getSharedChatSession(
        broadcasterId: channelId,
      );
    } catch (e) {
      onBadgeError(e);
      return <String>[];
    }

    if (sharedSession == null) {
      runInAction(sharedChatChannelIds.clear);
      return <String>[];
    }

    runInAction(
      () => sharedChatChannelIds
        ..clear()
        ..addAll(
          sharedSession!.participants.map((p) => p.broadcasterId).toSet(),
        ),
    );

    final newParticipantIds = <String>[];
    for (final participant in sharedSession.participants) {
      final id = participant.broadcasterId;
      if (_loadedSharedChannelIds.add(id)) {
        newParticipantIds.add(id);
      }
    }

    // Fetch user profiles concurrently.
    if (newParticipantIds.isNotEmpty) {
      await Future.wait(
        newParticipantIds.map((id) async {
          try {
            final user = await twitchApi.getUser(id: id);
            channelIdToUserTwitch[id] = user;
          } catch (e) {
            onBadgeError(e);
          }
        }),
      );
    }

    return newParticipantIds;
  }

  Future<List<Emote>> _fetchEmotesForChannel(
    String id, {
    required Function onEmoteError,
    bool showTwitchEmotes = true,
    bool show7TVEmotes = true,
    bool showBTTVEmotes = true,
    bool showFFZEmotes = true,
  }) async {
    final futures = <Future<List<Emote>>>[];

    if (showTwitchEmotes) {
      futures.add(twitchApi.getEmotesChannel(id: id).catchError(onEmoteError));
    }
    if (show7TVEmotes) {
      futures.add(
        sevenTVApi
            .getEmotesChannel(id: id)
            .then((data) {
              final (setId, emotes) = data;
              sharedSevenTvSetIds[id] = setId;
              return emotes;
            })
            .catchError(onEmoteError),
      );
    }
    if (showBTTVEmotes) {
      futures.add(bttvApi.getEmotesChannel(id: id).catchError(onEmoteError));
    }
    if (showFFZEmotes) {
      futures.add(
        ffzApi
            .getRoomInfo(id: id)
            .then((ffzRoom) {
              final (roomInfoIgnored, emotes) = ffzRoom;
              return emotes;
            })
            .catchError(onEmoteError),
      );
    }

    final lists = await Future.wait(futures);
    return lists.expand((e) => e).toList();
  }

  Future<void> _fetchBadgesForChannel(
    String id, {
    required Function onBadgeError,
  }) async {
    try {
      final badges = await twitchApi.getBadgesChannel(id: id);
      _channelTwitchBadges = {..._channelTwitchBadges, ...badges};
    } catch (e) {
      onBadgeError(e);
    }
  }

  /// Fills the emote menu with every emote the viewer can use here
  /// (follower emotes included), by section. False when Twitch would not
  /// say (a token without the scope): [userEmotesFuture] then reads the
  /// chat's emote sets instead.
  @action
  Future<bool> userEmotesFromHelix({
    required String userId,
    required String broadcasterId,
  }) async {
    final List<Emote> emotes;
    Map<String, String> owners;
    try {
      emotes = await twitchApi.getUserEmotes(
        userId: userId,
        broadcasterId: broadcasterId,
      );
    } catch (e) {
      debugPrint('Helix user emotes unavailable: $e');
      return false;
    }
    final ownerIds = {
      for (final emote in emotes)
        if (_ownedSection(emote) &&
            RegExp(r'^[0-9]{1,20}$').hasMatch(emote.ownerId ?? ''))
          emote.ownerId!,
    };
    try {
      owners = {
        for (final user in await twitchApi.getUsersByIds([...ownerIds]))
          user.id: user.displayName,
      };
    } catch (e) {
      // The emotes stay; their channels are just not named.
      debugPrint('Emote owners unavailable: $e');
      owners = const {};
    }
    final sections = <String, List<Emote>>{
      // Loaded with the channel's other emotes.
      UserEmoteSection.channel:
          ?_userEmoteSectionToEmotes[UserEmoteSection.channel],
    };
    for (final emote in emotes) {
      final section = _ownedSection(emote)
          ? owners[emote.ownerId] ?? UserEmoteSection.other
          : emote.type == EmoteType.twitchGlobal || emote.ownerId == 'twitch'
          ? UserEmoteSection.global
          : UserEmoteSection.unlocked;
      (sections[section] ??= []).add(emote);
    }
    _userEmoteSectionToEmotes = sections;
    _userEmoteToObject = {for (final emote in emotes) emote.name: emote};
    return true;
  }

  /// A channel's emote (subscriber or follower), shown under its name.
  static bool _ownedSection(Emote emote) =>
      (emote.type == EmoteType.twitchSub ||
          emote.type == EmoteType.twitchFollower) &&
      emote.ownerId != 'twitch';

  @action
  Future<void> userEmotesFuture({
    required List<String> emoteSets,
    required Map<String, String> headers,
    required Function onError,
  }) async {
    final userEmotes = await Future.wait(
      emoteSets.map(
        (setId) => twitchApi.getEmotesSets(setId: setId).catchError(onError),
      ),
    );

    for (final emoteSet in userEmotes) {
      if (emoteSet.isNotEmpty) {
        if (emoteSet.first.type == EmoteType.twitchSub) {
          final ownerId = emoteSet.first.ownerId;

          // Check for tuurbo emote sets (e.g., monkey set).
          if (ownerId == 'twitch') {
            _userEmoteSectionToEmotes.update(
              UserEmoteSection.global,
              (existingEmoteSet) => [...existingEmoteSet, ...emoteSet],
              ifAbsent: () => emoteSet,
            );
          } else {
            final owner = await twitchApi.getUser(id: ownerId);
            _userEmoteSectionToEmotes.update(
              owner.displayName,
              (existingEmoteSet) => [...existingEmoteSet, ...emoteSet],
              ifAbsent: () => emoteSet,
            );
          }
        } else if (emoteSet.first.type == EmoteType.twitchGlobal) {
          _userEmoteSectionToEmotes.update(
            UserEmoteSection.global,
            (existingEmoteSet) => [...existingEmoteSet, ...emoteSet],
            ifAbsent: () => emoteSet,
          );
        } else if (emoteSet.first.type == EmoteType.twitchUnlocked) {
          _userEmoteSectionToEmotes.update(
            UserEmoteSection.unlocked,
            (existingEmoteSet) => [...existingEmoteSet, ...emoteSet],
            ifAbsent: () => emoteSet,
          );
        }

        for (final emote in emoteSet) {
          _userEmoteToObject[emote.name] = emote;
        }
      }
    }
  }

  @action
  void removeRecentEmote(Emote emote) => _recentEmotes.removeWhere(
    (recent) => recent.name == emote.name && recent.type == emote.type,
  );

  /// Adds a channel emote (e.g., from a live 7TV event).
  /// Mutates the observable `_channelEmoteToObject` so `emoteToObject` recomputes.
  @action
  void addChannelEmote(Emote emote) {
    _channelEmoteToObject[emote.name] = emote;
  }

  /// Removes a channel emote by name (e.g., from a live 7TV event).
  /// Mutates the observable `_channelEmoteToObject` so `emoteToObject` recomputes.
  @action
  void removeChannelEmote(String emoteName) {
    _channelEmoteToObject.remove(emoteName);
  }

  @action
  void configureCosmetics({
    required bool sevenTvBadges,
    required bool sevenTvPaints,
    required bool sevenTvPersonalEmotes,
    required bool bttvPersonalEmotes,
    required bool ffzRoomBadges,
  }) {
    showSevenTvBadges = sevenTvBadges;
    showSevenTvPaints = sevenTvPaints;
    showSevenTvPersonalEmotes = sevenTvPersonalEmotes;
    showBttvPersonalEmotes = bttvPersonalEmotes;
    showFfzRoomBadges = ffzRoomBadges;
    if (!sevenTvBadges) _userTo7TVBadges.clear();
    if (!sevenTvPaints) userTo7TVPaint.clear();
    if (!sevenTvPersonalEmotes) _sevenTvPersonalEmotes.clear();
    if (!bttvPersonalEmotes) _bttvPersonalEmotes.clear();
    _refreshPersonalEmotes();
    if (_wantsSevenTvLookups) {
      final chatters = _lookedUpChatters.toList();
      _lookedUpChatters.clear();
      chatters.forEach(noteChatter);
    }
  }

  RoomFFZ? get ffzRoomBadges => showFfzRoomBadges ? ffzRoomInfo : null;

  void noteChatter(String? userId) {
    if (userId == null || userId.isEmpty || !_wantsSevenTvLookups) return;
    if (!_lookedUpChatters.add(userId)) return;
    globalAssetsStore.sevenTvCosmetics
        .lookup(userId)
        .then((cosmetics) => _applySevenTvCosmetics(userId, cosmetics));
  }

  @action
  void _applySevenTvCosmetics(String userId, SevenTvUserCosmetics cosmetics) {
    if (cosmetics.badge case final badge? when showSevenTvBadges) {
      _userTo7TVBadges.remove(userId);
      _userTo7TVBadges[userId] = [badge];
    }
    if (cosmetics.paint case final paint?
        when showSevenTvPaints && paint.isDrawable) {
      userTo7TVPaint.remove(userId);
      userTo7TVPaint[userId] = paint;
    }
    _trimPerUserMaps();
    final setId = cosmetics.personalSetId;
    if (setId != null && showSevenTvPersonalEmotes) {
      _ownPersonalSet(userId, setId);
      _sevenTvPersonalEmotes.remove(userId);
      _sevenTvPersonalEmotes[userId] = {
        for (final emote in cosmetics.personalEmotes) emote.name: emote,
      };
      _refreshPersonalEmotes(userId);
    }
  }

  void _ownPersonalSet(String userId, String setId) {
    final owners = _sevenTvPersonalSetOwners.putIfAbsent(setId, () {
      onPersonalEmoteSetSeen?.call(setId);
      return <String>{};
    });
    owners.add(userId);
  }

  @action
  void defineSevenTvCosmetic(SevenTvCosmeticCreated cosmetic) {
    if (cosmetic.paint case final paint?) {
      _sevenTvPaintDefinitions[cosmetic.id] = paint;
    }
    if (cosmetic.badge case final badge?) {
      _sevenTvBadgeDefinitions[cosmetic.id] = badge;
    }
  }

  @action
  Future<void> applySevenTvEntitlement(SevenTvEntitlement entitlement) async {
    final userId = entitlement.twitchUserId;
    switch (entitlement.kind) {
      case SevenTvEntitlementKind.badge:
        if (!showSevenTvBadges) return;
        final badge = _sevenTvBadgeDefinitions[entitlement.refId];
        if (entitlement.granted && badge != null) {
          _userTo7TVBadges.remove(userId);
          _userTo7TVBadges[userId] = [badge];
          _trimPerUserMaps();
        } else if (!entitlement.granted) {
          _userTo7TVBadges.remove(userId);
        }
      case SevenTvEntitlementKind.paint:
        if (!showSevenTvPaints) return;
        final paint = _sevenTvPaintDefinitions[entitlement.refId];
        if (entitlement.granted && paint != null && paint.isDrawable) {
          userTo7TVPaint.remove(userId);
          userTo7TVPaint[userId] = paint;
          _trimPerUserMaps();
        } else if (!entitlement.granted) {
          userTo7TVPaint.remove(userId);
        }
      case SevenTvEntitlementKind.emoteSet:
        if (!showSevenTvPersonalEmotes) return;
        if (!entitlement.granted) {
          _sevenTvPersonalSetOwners[entitlement.refId]?.remove(userId);
          _sevenTvPersonalEmotes.remove(userId);
          _refreshPersonalEmotes(userId);
          return;
        }
        _ownPersonalSet(userId, entitlement.refId);
        final emotes = await globalAssetsStore.sevenTvCosmetics.emoteSet(
          entitlement.refId,
        );
        runInAction(() {
          if (!showSevenTvPersonalEmotes) return;
          _sevenTvPersonalEmotes[userId] = {
            for (final emote in emotes) emote.name: emote,
          };
          _refreshPersonalEmotes(userId);
        });
    }
  }

  @action
  void applyPersonalEmoteSetChange(SevenTvEmoteSetChange change) {
    final owners = _sevenTvPersonalSetOwners[change.setId];
    if (owners == null || !showSevenTvPersonalEmotes) return;
    globalAssetsStore.sevenTvCosmetics.forgetEmoteSet(change.setId);
    for (final owner in owners) {
      final emotes = {...?_sevenTvPersonalEmotes[owner]};
      for (final name in change.removed) {
        emotes.remove(name);
      }
      for (final rename in change.renamed) {
        emotes.remove(rename.oldName);
        final emote = Emote.from7TV(rename.emote, EmoteType.sevenTVPersonal);
        if (emote.url.isNotEmpty) emotes[emote.name] = emote;
      }
      for (final added in change.added) {
        final emote = Emote.from7TV(added, EmoteType.sevenTVPersonal);
        if (emote.url.isNotEmpty) emotes[emote.name] = emote;
      }
      _sevenTvPersonalEmotes[owner] = emotes;
      _refreshPersonalEmotes(owner);
    }
  }

  @action
  void applyBttvProUser(BttvProUser user) {
    if (!showBttvPersonalEmotes) return;
    if (!user.pro || user.emotes.isEmpty) {
      _bttvPersonalEmotes.remove(user.providerId);
    } else {
      _bttvPersonalEmotes.remove(user.providerId);
      _bttvPersonalEmotes[user.providerId] = {
        for (final emote in user.emotes)
          emote.code: Emote.fromBTTV(emote, EmoteType.bttvPersonal),
      };
    }
    _refreshPersonalEmotes(user.providerId);
  }

  void _refreshPersonalEmotes([String? onlyUserId]) {
    final userIds = onlyUserId != null
        ? {onlyUserId}
        : {
            ...userToPersonalEmotes.keys,
            ..._sevenTvPersonalEmotes.keys,
            ..._bttvPersonalEmotes.keys,
          };
    for (final userId in userIds) {
      final merged = {
        if (showBttvPersonalEmotes) ...?_bttvPersonalEmotes[userId],
        if (showSevenTvPersonalEmotes) ...?_sevenTvPersonalEmotes[userId],
      };
      userToPersonalEmotes.remove(userId);
      if (merged.isNotEmpty) userToPersonalEmotes[userId] = merged;
    }
    _trimPerUserMaps();
  }

  static const perUserCapacity = 4000;

  void _trimPerUserMaps() {
    for (final map in <Map<String, Object>>[
      _sevenTvPersonalEmotes,
      _bttvPersonalEmotes,
      userToPersonalEmotes,
      _userTo7TVBadges,
      userTo7TVPaint,
    ]) {
      while (map.length > perUserCapacity) {
        map.remove(map.keys.first);
      }
    }
    while (_lookedUpChatters.length > perUserCapacity) {
      _lookedUpChatters.remove(_lookedUpChatters.first);
    }
  }

  Future<bool> switchSevenTvSet(String setId) async {
    final List<Emote> emotes;
    try {
      emotes = await sevenTVApi.getEmoteSet(
        id: setId,
        type: EmoteType.sevenTVChannel,
      );
    } catch (error) {
      debugPrint('7TV emote set unavailable: $error');
      return false;
    }
    runInAction(() {
      replaceSevenTvChannelEmotes(emotes);
      sevenTvEmoteSetId = setId;
    });
    return true;
  }

  @action
  void replaceSevenTvChannelEmotes(List<Emote> emotes) {
    _channelEmoteToObject.removeWhere(
      (_, emote) => emote.type == EmoteType.sevenTVChannel,
    );
    for (final emote in emotes) {
      _channelEmoteToObject.putIfAbsent(emote.name, () => emote);
    }
  }

  @action
  Emote? renameChannelEmote({
    required bool Function(Emote emote) where,
    required Emote Function(Emote emote) to,
  }) {
    final entry = _channelEmoteToObject.entries.firstWhereOrNull(
      (entry) => where(entry.value),
    );
    if (entry == null) return null;
    _channelEmoteToObject.remove(entry.key);
    final renamed = to(entry.value);
    _channelEmoteToObject[renamed.name] = renamed;
    return entry.value;
  }

  @action
  Emote? removeChannelEmoteWhere(bool Function(Emote emote) where) {
    final entry = _channelEmoteToObject.entries.firstWhereOrNull(
      (entry) => where(entry.value),
    );
    if (entry == null) return null;
    _channelEmoteToObject.remove(entry.key);
    return entry.value;
  }

  void dispose() => _disposeReaction();
}
