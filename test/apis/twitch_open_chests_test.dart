import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/legendary_collection.dart';

const _gql = 'https://gql.twitch.tv/gql';

Map<String, Object?> _season({
  required List<bool> owned,
  int free = 0,
  int paid = 0,
}) => {
  'data': {
    'legendaryEmoteSeason': {
      'campaign': {'name': 'Season'},
      'emotePool': [
        for (final (i, isOwned) in owned.indexed)
          {
            'tier': 'RARE',
            'isOwned': isOwned,
            'emote': {'id': 'e$i', 'token': 'Emote$i'},
          },
      ],
      'userProgress': {
        'chestInventory': [
          {'chestType': 'FREE', 'unopenedCount': free},
          {'chestType': 'PAID', 'unopenedCount': paid},
        ],
      },
    },
  },
};

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late List<RequestOptions> sent;

  setUp(() {
    dio = Dio();
    adapter = DioAdapter(dio: dio);
    sent = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          sent.add(options);
          handler.next(options);
        },
      ),
    );
  });

  test('opens the free and paid chests the viewer holds', () async {
    adapter.onPost(
      _gql,
      (server) => server.reply(200, {
        'data': {
          'openChests': {'txnID': 'tx1', 'error': null},
        },
      }),
      data: Matchers.any,
    );
    final outcome = await TwitchViewerActionsService(
      dio,
    ).openChests(channelId: '7', freeCount: 2, paidCount: 1, authToken: 't');
    expect(outcome, ViewerActionOutcome.done);
    final body = sent.single.data as Map;
    expect(body['operationName'], 'OpenChests');
    expect((body['variables'] as Map)['input'], {
      'channelID': '7',
      'freeCount': 2,
      'paidCount': 1,
      'shouldOpenFtue': false,
    });
  });

  test('an error from Twitch is a refusal', () async {
    adapter.onPost(
      _gql,
      (server) => server.reply(200, {
        'data': {
          'openChests': {
            'txnID': null,
            'error': {'code': 'NO_CHESTS', 'message': 'none'},
          },
        },
      }),
      data: Matchers.any,
    );
    expect(
      await TwitchViewerActionsService(
        dio,
      ).openChests(channelId: '7', freeCount: 1, paidCount: 0, authToken: 't'),
      ViewerActionOutcome.refused,
    );
  });

  test('nothing to open, a bad channel or no session sends nothing', () async {
    final service = TwitchViewerActionsService(dio);
    expect(
      await service.openChests(
        channelId: '7',
        freeCount: 0,
        paidCount: 0,
        authToken: 't',
      ),
      ViewerActionOutcome.failed,
    );
    expect(
      await service.openChests(
        channelId: 'x',
        freeCount: 1,
        paidCount: 0,
        authToken: 't',
      ),
      ViewerActionOutcome.failed,
    );
    expect(
      await service.openChests(
        channelId: '7',
        freeCount: 1,
        paidCount: 0,
        authToken: '',
      ),
      ViewerActionOutcome.signedOut,
    );
    expect(sent, isEmpty);
  });

  test('the collection tells free from paid chests and what is new', () {
    final before = LegendaryCollection.fromBody(
      _season(owned: [true, false, false], free: 2, paid: 1),
    )!;
    expect(before.unopenedChests, 3);
    expect(before.freeChests, 2);
    expect(before.paidChests, 1);
    final after = LegendaryCollection.fromBody(
      _season(owned: [true, true, false]),
    )!;
    expect(after.newlyOwnedSince(before).map((e) => e.id), ['e1']);
  });
}
