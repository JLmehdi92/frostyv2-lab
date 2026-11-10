import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/integrity_retry_interceptor.dart';
import 'package:onset/apis/twitch_report_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/report.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchReportService service;
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
    service = TwitchReportService(dio);
  });

  void reply(Object? body) => adapter.onPost(
    _gql,
    (server) => server.reply(200, body),
    data: Matchers.any,
  );

  Map<dynamic, dynamic> input() =>
      ((sent.single.data as Map)['variables'] as Map)['input'] as Map;

  const user = ReportTarget.user(userId: '42', name: 'Someone');
  const message = ReportTarget.message(
    messageId: 'a1b2-c3',
    senderId: '42',
    channelId: '7',
    name: 'Someone',
  );

  test('a user report sends ReportContent with the user as content', () async {
    reply({
      'data': {
        'reportContent': {'content': 'USER_REPORT', 'contentID': '42'},
      },
    });
    final outcome = await service.report(
      target: user,
      reason: ReportReason.spam,
      description: ' bot ',
      authToken: 't',
    );
    expect(outcome, ViewerActionOutcome.done);
    expect(input(), {
      'content': 'USER_REPORT',
      'contentID': '42',
      'targetID': '42',
      'reason': 'spam',
      'description': 'bot',
      'extra': '',
    });
    expect(sent.single.headers['Authorization'], 'OAuth t');
    expect(sent.single.extra[IntegrityRetryInterceptor.userActionKey], isTrue);
  });

  test('a message report names the message, its sender and channel', () async {
    reply({
      'data': {
        'reportContent': {'content': 'CHAT_REPORT', 'contentID': 'a1b2-c3'},
      },
    });
    await service.report(
      target: message,
      reason: ReportReason.harassment,
      description: '',
      authToken: 't',
    );
    expect(input()['content'], 'CHAT_REPORT');
    expect(input()['contentID'], 'a1b2-c3');
    expect(input()['targetID'], '42');
    expect(input()['extra'], '7');
  });

  test('each kind offers only reasons Twitch lists for it', () {
    expect(
      ReportReason.forKind(ReportKind.emote),
      isNot(contains(ReportReason.banEvasion)),
    );
    expect(
      ReportReason.forKind(ReportKind.message),
      contains(ReportReason.chatBanEvasion),
    );
    expect(
      const ReportTarget.emote(
        emoteId: 'e1',
        ownerId: '9',
        name: 'x',
      ).contentType,
      'EMOTE_REPORT',
    );
    expect(
      const ReportTarget.clip(
        slug: 'Abc-1',
        broadcasterId: '9',
        name: 'x',
      ).contentType,
      'CLIP_REPORT',
    );
  });

  test('an error is a refusal, an integrity error says so', () async {
    reply({
      'errors': [
        {'message': 'failed integrity check'},
      ],
    });
    expect(
      await service.report(
        target: user,
        reason: ReportReason.spam,
        description: '',
        authToken: 't',
      ),
      ViewerActionOutcome.integrityRefused,
    );
  });

  test(
    'a reason the kind lacks, a bad id or no session sends nothing',
    () async {
      expect(
        await service.report(
          target: const ReportTarget.emote(
            emoteId: 'e1',
            ownerId: '9',
            name: 'x',
          ),
          reason: ReportReason.banEvasion,
          description: '',
          authToken: 't',
        ),
        ViewerActionOutcome.failed,
      );
      expect(
        await service.report(
          target: const ReportTarget.user(userId: 'abc', name: 'x'),
          reason: ReportReason.spam,
          description: '',
          authToken: 't',
        ),
        ViewerActionOutcome.failed,
      );
      expect(
        await service.report(
          target: user,
          reason: ReportReason.spam,
          description: '',
          authToken: '',
        ),
        ViewerActionOutcome.signedOut,
      );
      expect(sent, isEmpty);
    },
  );

  test('a Twitch emote’s id is read from its image address', () {
    expect(
      ReportTarget.twitchEmoteId(
        'https://static-cdn.jtvnw.net/emoticons/v2/emotesv2_abc123/default/dark/2.0',
      ),
      'emotesv2_abc123',
    );
    expect(
      ReportTarget.twitchEmoteId('https://cdn.7tv.app/emote/x/2x.webp'),
      isNull,
    );
  });
}
