// Dev-only harness for the hype train on a device, WITHOUT Twitch app
// credentials. Run with:
//   flutter run -t lib/dev_hype_train_harness.dart
//
// - Live: lists channels with an active hype train (anonymous GQL over the
//   top streams), then shows the real store, realtime client and banner.
// - Replay: scripted scenarios through `injectEvent`, offline, to see every
//   variant and timing (with a landscape preview and a reduce-motion switch).
//
// This file is not part of the shipped app.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_slot.dart';
import 'package:frosty/services/realtime/realtime_socket.dart';
import 'package:frosty/services/realtime/twitch_realtime_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      theme: ThemeData(colorSchemeSeed: const Color(0xff9146ff)),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xff9146ff),
        brightness: Brightness.dark,
      ),
      home: const _Harness(),
    ),
  );
}

class _Harness extends StatelessWidget {
  const _Harness();

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Hype train harness'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Live'),
            Tab(text: 'Replay'),
          ],
        ),
      ),
      body: const TabBarView(children: [_LiveTab(), _ReplayTab()]),
    ),
  );
}

// --- Live -------------------------------------------------------------------

typedef _Active = ({String id, String login, int level, String type});

/// Anonymous GQL over the top streams of the top categories (dev only).
Future<List<_Active>> _findActiveTrains(Dio dio) async {
  Future<Map> gql(String query, Map<String, Object?> variables) async {
    final response = await dio.post<Map>(
      'https://gql.twitch.tv/gql',
      data: {'query': query, 'variables': variables},
      options: Options(headers: {'Client-ID': kTwitchWebClientId}),
    );
    return response.data ?? const {};
  }

  final games = await gql(
    'query { games(first: 30) { edges { node { streams(first: 30) { '
    'edges { node { broadcaster { id login } } } } } } } }',
    const {},
  );
  final logins = <String, String>{};
  for (final game in (games['data']?['games']?['edges'] as List? ?? [])) {
    final streams = game['node']?['streams']?['edges'] as List? ?? [];
    for (final stream in streams) {
      final broadcaster = stream['node']?['broadcaster'];
      if (broadcaster is Map) {
        logins['${broadcaster['id']}'] = '${broadcaster['login']}';
      }
    }
  }
  final ids = logins.keys.toList();
  final active = <_Active>[];
  for (var i = 0; i < ids.length; i += 100) {
    final statuses = await gql(
      r'query($ids: [ID!]!) { allActiveHypeTrainStatuses(channelIDs: $ids) '
      '{ channel { id } level hypeTrainType } }',
      {'ids': ids.sublist(i, i + 100 > ids.length ? ids.length : i + 100)},
    );
    for (final s
        in (statuses['data']?['allActiveHypeTrainStatuses'] as List?) ?? []) {
      final id = '${s['channel']?['id']}';
      active.add((
        id: id,
        login: logins[id] ?? id,
        level: (s['level'] as num?)?.toInt() ?? 0,
        type: '${s['hypeTrainType']}',
      ));
    }
  }
  active.sort((a, b) => b.level.compareTo(a.level));
  return active;
}

class _LiveTab extends StatefulWidget {
  const _LiveTab();

  @override
  State<_LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends State<_LiveTab> {
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  late final _service = TwitchHypeTrainService(_dio);
  final _realtime = TwitchRealtimeClient();
  List<_Active>? _active;
  String? _error;
  HypeTrainStore? _store;
  String? _login;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _active = null;
      _error = null;
    });
    try {
      final active = await _findActiveTrains(_dio);
      if (mounted) setState(() => _active = active);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _open(_Active train) {
    _store?.dispose();
    setState(() {
      _login = train.login;
      _store = HypeTrainStore(
        channelId: train.id,
        service: _service,
        realtime: _realtime,
      );
    });
  }

  @override
  void dispose() {
    _store?.dispose();
    unawaited(_realtime.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    return Column(
      children: [
        if (store != null) ...[
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: 360,
              child: HypeTrainSlot(store: store, onLearnMore: () {}),
            ),
          ),
          Observer(
            builder: (_) => Text(
              '$_login · ${store.phase.name} · level ${store.level} · '
              '${store.percent}% · realtime '
              '${store.realtimeDegraded ? 'degraded' : 'ok'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Divider(),
        ],
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: [
                if (_error != null) ListTile(title: Text(_error!)),
                if (_active == null && _error == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                for (final train in _active ?? const <_Active>[])
                  ListTile(
                    title: Text(train.login),
                    subtitle: Text('level ${train.level} · ${train.type}'),
                    onTap: () => _open(train),
                  ),
                if (_active?.isEmpty ?? false)
                  const ListTile(title: Text('No active trains right now')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- Replay -----------------------------------------------------------------

/// A socket that never connects to anything (offline replay).
class _SilentSocket implements RealtimeSocket {
  final _messages = StreamController<String>();

  @override
  Stream<String> get messages => _messages.stream;

  @override
  void send(String text) {}

  @override
  Future<void> close([int? code, String? reason]) => _messages.close();

  @override
  int? get closeCode => null;
}

class _OfflineService extends TwitchHypeTrainService {
  _OfflineService() : super(Dio());

  @override
  Future<HypeTrainSnapshot> getHypeTrain(String channelId) async =>
      const HtNoTrain();

  @override
  Future<List<(int, List<HtReward>)>> getUpcomingRewards(
    String channelId,
  ) async => [
    (3, [_emote('305954156', 'PogChamp')]),
    (4, [_emote('1902', 'Keepo')]),
  ];
}

HtReward _emote(String id, String token) =>
    HtReward(type: HtRewardType.emote, id: id, token: token);

final _emotes = [
  _emote('25', 'Kappa'),
  _emote('1902', 'Keepo'),
  _emote('305954156', 'PogChamp'),
  _emote('88', 'PogChamp'),
  _emote('354', '4Head'),
];

HtUser _user(String id, String name) =>
    HtUser(id: id, login: name.toLowerCase(), displayName: name);

HtProgress _progress(
  int level,
  int value, {
  int goal = 1000,
  HtAthState ath = HtAthState.none,
}) => HtProgress(
  level: HtLevel(
    value: level,
    cumulativeGoal: level * goal,
    rewards: _emotes.take(3).toList(),
  ),
  goal: goal,
  value: value,
  total: (level - 1) * goal + value,
  athState: ath,
);

HypeTrainExecution _train({
  int level = 1,
  int value = 0,
  HtVariant variant = HtVariant.regular,
  HtTreasure? treasure,
  HtCommunity? community,
  HtMythic? mythic,
  HtShared? shared,
  HtAthState ath = HtAthState.none,
}) => HypeTrainExecution(
  id: 'replay',
  progress: _progress(level, value, ath: ath),
  expiresAt: DateTime.now().add(const Duration(minutes: 5)),
  variant: variant,
  treasure: treasure,
  community: community,
  mythic: mythic,
  shared: shared,
  config: HtConfig(
    maxLevel: 25,
    conversionRates: const {'TIER_1_SUB': 500, 'CHEER': 1},
    calloutEmote: _emotes.first,
  ),
  ath: const HtAth(level: 6, goal: 1000, progression: 0, total: 6000),
);

HtProgressionEvent _contribution(
  int level,
  int value, {
  bool large = false,
  HtAthState ath = HtAthState.none,
}) {
  final progress = _progress(level, value, ath: ath);
  return HtProgressionEvent(
    trainId: 'replay',
    sequenceId: progress.total,
    displayName: large ? 'BigGifter' : 'Viewer${value % 7}',
    action: HtAction(large ? 'TIER_1_GIFTED_SUB' : 'CHEER'),
    source: large ? HtSource.subs : HtSource.bits,
    quantity: large ? 50 : 100,
    isLarge: large,
    progress: progress,
  );
}

HtLevelUpEvent _levelUp(int level, {HypeTrainExecution? train}) =>
    HtLevelUpEvent(
      timeToExpire: DateTime.now().add(const Duration(minutes: 5)),
      progress: _progress(level, 50),
      train: train,
    );

typedef _Scenario = ({String name, List<(int, HypeTrainEvent)> events});

List<_Scenario> _scenarios() {
  const treasure = HtTreasure(
    discountPercentage: 50,
    threshold: 2,
    status: HtUnlockStatus.none,
  );
  final community = HtCommunity.parse(const {
    'rewardLevelThreshold': 2,
    'currentRewardAmount': 25,
    'nextRewardAmount': 25,
  });
  final mythic = HtMythic(pool: _emotes, selectedEmote: _emotes[2]);
  final shared = HtShared(
    id: 'shared',
    channels: [
      HtSharedChannel(user: _user('1', 'Alpha'), progress: _progress(2, 300)),
      HtSharedChannel(user: _user('2', 'Bravo'), progress: _progress(2, 200)),
    ],
  );
  return [
    (
      name: 'Regular: start, levels, completed',
      events: [
        (0, HtStartEvent(_train())),
        (6000, _contribution(1, 400)),
        (1000, _contribution(1, 900)),
        (1000, _contribution(2, 50)),
        (500, _levelUp(2)),
        (6000, _contribution(2, 600)),
        (2000, const HtEndEvent(reason: HtEndReason.completed)),
      ],
    ),
    (
      name: 'Large contribution burst (12 events)',
      events: [
        (0, HtStartEvent(_train())),
        (6000, _contribution(1, 100, large: true)),
        for (var i = 2; i <= 12; i++) (150, _contribution(1, i * 60)),
      ],
    ),
    (
      name: 'Golden Kappa level-up',
      events: [
        (0, HtStartEvent(_train())),
        (
          6000,
          _levelUp(2, train: _train(level: 2, variant: HtVariant.goldenKappa)),
        ),
        (7000, const HtEndEvent(reason: HtEndReason.completed)),
      ],
    ),
    (
      name: 'Treasure through its threshold',
      events: [
        (
          0,
          HtStartEvent(_train(variant: HtVariant.treasure, treasure: treasure)),
        ),
        (8000, _levelUp(2)),
      ],
    ),
    (
      name: 'Community through its threshold',
      events: [
        (
          0,
          HtStartEvent(
            _train(variant: HtVariant.community, community: community),
          ),
        ),
        (8000, _levelUp(2)),
      ],
    ),
    (
      name: 'Mythic: pool, then the reveal',
      events: [
        (0, HtStartEvent(_train(variant: HtVariant.mythic, mythic: mythic))),
        (6000, _levelUp(2)),
        (7000, const HtEndEvent(reason: HtEndReason.completed)),
      ],
    ),
    (
      name: 'Shared: start, merge, channel left',
      events: [
        (0, HtStartEvent(_train(level: 2, shared: shared))),
        (
          9000,
          HtMergeEvent(
            train: _train(level: 4, shared: shared),
            previousChannels: [_user('1', 'Alpha'), _user('2', 'Bravo')],
            joiningChannels: [_user('3', 'Charlie')],
          ),
        ),
        (
          5000,
          HtChannelLeftEvent(
            shouldEnd: false,
            continuesIn: _user('3', 'Charlie'),
          ),
        ),
      ],
    ),
    (
      name: 'Record: approaching, then reached',
      events: [
        (0, HtStartEvent(_train(level: 5))),
        (6000, _contribution(5, 300, ath: HtAthState.approaching)),
        (2000, _contribution(5, 900, ath: HtAthState.reached)),
      ],
    ),
    (
      name: 'Approaching, then a start',
      events: [
        (
          0,
          HtApproachingEvent(
            HypeTrainApproaching(
              id: 'a',
              goal: 3,
              deadlines: const {1: 40, 2: 60},
              levelOneRewards: _emotes.take(3).toList(),
            ),
          ),
        ),
        (6000, HtStartEvent(_train())),
      ],
    ),
    (
      name: 'Expired at level 1',
      events: [
        (0, HtStartEvent(_train())),
        (6000, const HtEndEvent(reason: HtEndReason.expired)),
      ],
    ),
  ];
}

class _ReplayTab extends StatefulWidget {
  const _ReplayTab();

  @override
  State<_ReplayTab> createState() => _ReplayTabState();
}

class _ReplayTabState extends State<_ReplayTab> {
  final _realtime = TwitchRealtimeClient(connect: (_) => _SilentSocket());
  final _service = _OfflineService();
  final _timers = <Timer>[];
  HypeTrainStore? _store;
  var _reduceMotion = false;
  var _dark = false;

  void _play(_Scenario scenario) {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _store?.dispose();
    final store = HypeTrainStore(
      channelId: '0',
      service: _service,
      realtime: _realtime,
    );
    setState(() => _store = store);
    var at = 0;
    for (final (delay, event) in scenario.events) {
      at += delay;
      _timers.add(
        Timer(
          Duration(milliseconds: at),
          // A dev tool replaying events, like the tests do.
          // ignore: invalid_use_of_visible_for_testing_member
          () => store.injectEvent(event),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _store?.dispose();
    unawaited(_realtime.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final theme = _dark
        ? ThemeData(
            colorSchemeSeed: const Color(0xff9146ff),
            brightness: Brightness.dark,
          )
        : Theme.of(context);
    return Column(
      children: [
        if (store != null)
          Theme(
            data: theme,
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: _reduceMotion),
              child: Container(
                color: theme.colorScheme.surface,
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    SizedBox(
                      width: 360,
                      child: HypeTrainSlot(store: store, onLearnMore: () {}),
                    ),
                    const SizedBox(height: 8),
                    const Text('Landscape preview'),
                    SizedBox(
                      width: 260,
                      child: HypeTrainSlot(
                        store: store,
                        compact: true,
                        onLearnMore: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SwitchListTile(
          title: const Text('Reduce motion'),
          value: _reduceMotion,
          onChanged: (value) => setState(() => _reduceMotion = value),
        ),
        SwitchListTile(
          title: const Text('Dark'),
          value: _dark,
          onChanged: (value) => setState(() => _dark = value),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final scenario in _scenarios())
                ListTile(
                  title: Text(scenario.name),
                  trailing: const Icon(Icons.play_arrow_rounded),
                  onTap: () => _play(scenario),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
