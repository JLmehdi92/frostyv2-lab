import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/twitch_channel_profile_service.dart';
import 'package:onset/models/channel_profile.dart';
import 'package:onset/models/team.dart';
import 'package:onset/models/user.dart';
import 'package:onset/models/video_collection.dart';

part 'channel_profile_store.g.dart';

class ChannelProfileStore = ChannelProfileStoreBase with _$ChannelProfileStore;

/// A channel's profile and schedule for its profile page. The profile comes
/// from anonymous GQL; when that fails, Helix `/users` still gives the
/// header (name, avatar, id), so the page never blocks reaching the
/// channel.
abstract class ChannelProfileStoreBase with Store {
  ChannelProfileStoreBase({
    required this.login,
    required this.profileService,
    this.helixUser,
    this.teamsOf,
    this.scheduleExtrasOf,
    this.collectionsOf,
  });

  final Future<List<VideoCollection>?> Function(String userId)? collectionsOf;

  @readonly
  List<VideoCollection> _collections = const [];

  final Future<ScheduleExtras> Function(String userId)? scheduleExtrasOf;

  @readonly
  ScheduleExtras _scheduleExtras = ScheduleExtras.none;

  final Future<List<Team>> Function(String userId)? teamsOf;

  @readonly
  ChannelTrailer? _trailer;

  @readonly
  List<Team> _teams = const [];

  final String login;
  final TwitchChannelProfileService profileService;

  /// The Helix user for [login] (the fallback header).
  final Future<UserTwitch> Function(String login)? helixUser;

  Future<void>? _profileInFlight;
  Future<void>? _scheduleInFlight;
  var _disposed = false;

  @readonly
  ChannelProfile? _profile;

  /// The Helix header, only when the profile could not be read.
  @readonly
  UserTwitch? _fallback;

  @readonly
  var _isLoading = false;

  /// At least one load finished.
  @readonly
  var _loaded = false;

  @readonly
  var _notFound = false;

  /// What made the profile fail to load (null when it did not); the screen
  /// says it could not load.
  @readonly
  Object? _error;

  @readonly
  ChannelSchedule? _schedule;

  @readonly
  var _scheduleLoading = false;

  /// What made the schedule fail to load (null when it did not); the
  /// screen says it could not load.
  @readonly
  Object? _scheduleError;

  /// The channel's user id, once known.
  @computed
  String? get userId => _profile?.id ?? _fallback?.id;

  @computed
  String? get displayName => _profile?.displayName ?? _fallback?.displayName;

  /// Loads the profile; a call while loading joins the running request.
  Future<void> load() =>
      _profileInFlight ??= _load().whenComplete(() => _profileInFlight = null);

  /// Loads the schedule (when its tab first shows).
  Future<void> loadSchedule() => _scheduleInFlight ??= _loadSchedule()
      .whenComplete(() => _scheduleInFlight = null);

  /// Pull to refresh: the profile, and the schedule if it was shown.
  Future<void> refresh() => Future.wait([
    load(),
    if (_schedule != null || _scheduleError != null) loadSchedule(),
  ]);

  @action
  Future<void> _load() async {
    _isLoading = true;
    try {
      final profile = await profileService.getProfile(login);
      if (_disposed) return;
      runInAction(() {
        _profile = profile;
        _error = null;
        if (profile != null) _fallback = null;
      });
      if (profile == null) {
        // Helix confirms before the page says the channel is gone.
        await _loadFallback();
        if (!_disposed) runInAction(() => _notFound = _fallback == null);
      } else {
        runInAction(() => _notFound = false);
        await _loadExtras(profile.id);
      }
    } catch (e) {
      debugPrint('ChannelProfileStore($login) profile failed: $e');
      if (_disposed) return;
      runInAction(() => _error = e);
      await _loadFallback();
    } finally {
      if (!_disposed) {
        runInAction(() {
          _isLoading = false;
          _loaded = true;
        });
      }
    }
  }

  Future<void> _loadExtras(String userId) async {
    final teamsOf = this.teamsOf;
    final (trailer, teams, collections) = await (
      Future(() => profileService.getTrailer(login)).then<ChannelTrailer?>(
        (trailer) => trailer,
        onError: (Object e) {
          debugPrint('ChannelProfileStore($login) trailer failed: $e');
          return null;
        },
      ),
      Future<List<Team>>(
        () => teamsOf == null ? const <Team>[] : teamsOf(userId),
      ).then<List<Team>>(
        (teams) => teams,
        onError: (Object e) {
          debugPrint('ChannelProfileStore($login) teams failed: $e');
          return const <Team>[];
        },
      ),
      _loadCollections(userId),
    ).wait;
    if (_disposed) return;
    runInAction(() {
      _trailer = trailer;
      _teams = teams;
      _collections = collections;
    });
  }

  Future<List<VideoCollection>> _loadCollections(String userId) async {
    final collectionsOf = this.collectionsOf;
    if (collectionsOf == null) return const [];
    try {
      return await collectionsOf(userId) ?? const [];
    } catch (e) {
      debugPrint('ChannelProfileStore($login) collections failed: $e');
      return const [];
    }
  }

  Future<void> _loadScheduleExtras() async {
    final extrasOf = scheduleExtrasOf;
    final id = userId;
    if (extrasOf == null || id == null) return;
    try {
      final extras = await extrasOf(id);
      if (!_disposed) runInAction(() => _scheduleExtras = extras);
    } catch (e) {
      debugPrint('ChannelProfileStore($login) schedule extras failed: $e');
    }
  }

  Future<void> _loadFallback() async {
    final helixUser = this.helixUser;
    if (helixUser == null || _profile != null || _fallback != null) return;
    try {
      final user = await helixUser(login);
      if (!_disposed) runInAction(() => _fallback = user);
    } catch (e) {
      debugPrint('ChannelProfileStore($login) fallback failed: $e');
    }
  }

  @action
  Future<void> _loadSchedule() async {
    _scheduleLoading = true;
    try {
      final schedule = await profileService.getSchedule(login);
      if (_disposed) return;
      runInAction(() {
        _schedule = schedule;
        _scheduleError = null;
      });
      await _loadScheduleExtras();
    } catch (e) {
      debugPrint('ChannelProfileStore($login) schedule failed: $e');
      if (!_disposed) {
        runInAction(() => _scheduleError = e);
      }
    } finally {
      if (!_disposed) runInAction(() => _scheduleLoading = false);
    }
  }

  void dispose() => _disposed = true;
}
