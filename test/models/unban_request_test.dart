import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/unban_request.dart';

import '../fixtures/unban_request_payloads.dart';

void main() {
  test('reads the last request, its outcome and the note', () {
    final state = UnbanRequestState.fromBody(
      unbanResponse(canRequest: false, status: 'DENIED', note: ' Not yet. '),
    )!;
    expect(state.hasRequest, isTrue);
    expect(state.status, 'DENIED');
    expect(state.moderatorNote, 'Not yet.');
    expect(state.canSend, isFalse);
  });

  test('a pending request cannot be sent again', () {
    final state = UnbanRequestState.fromBody(unbanResponse(status: 'PENDING'))!;
    expect(state.canSend, isFalse);
    expect(UnbanRequestState.fromBody(unbanResponse())!.canSend, isTrue);
  });

  test('logged out, the settings are still read but nothing can be sent', () {
    final state = UnbanRequestState.fromBody(unbanAnonymousResponse)!;
    expect(state.enabled, isTrue);
    expect(state.canSend, isFalse);
    expect(UnbanRequestState.fromBody(null), isNull);
  });

  test('the creation outcome keeps the refusal code', () {
    expect(
      UnbanRequestOutcome.fromBody({
        'data': {
          'createUnbanRequest': {
            'unbanRequest': null,
            'error': {'code': 'ALREADY_CREATED'},
          },
        },
      }).code,
      'ALREADY_CREATED',
    );
    expect(
      UnbanRequestOutcome.fromBody({
        'data': {
          'createUnbanRequest': {
            'unbanRequest': {'id': 'r'},
            'error': null,
          },
        },
      }).result,
      UnbanRequestResult.sent,
    );
    expect(
      UnbanRequestOutcome.fromBody({'errors': []}).result,
      UnbanRequestResult.failed,
    );
  });
}
