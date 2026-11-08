import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/resub_notification.dart';

import '../fixtures/community_gql_payloads.dart';

void main() {
  test('reads the shareable resub with its months and token', () {
    final resub = ResubNotification.tryParse(resubNotificationResponse);

    expect(resub, isNotNull);
    expect(resub!.months, 14);
    expect(resub.tokenId, 'token-1');
    expect(resub.isGift, isFalse);
  });

  test('nothing to share for an anonymous or empty answer', () {
    expect(
      ResubNotification.tryParse(anonymousResubNotificationResponse),
      isNull,
    );
    expect(ResubNotification.tryParse(noResubNotificationResponse), isNull);
    expect(ResubNotification.tryParse({'errors': []}), isNull);
    expect(ResubNotification.tryParse('nonsense'), isNull);
  });

  test('refuses a token that could not be sent back safely', () {
    final body = {
      'data': {
        'user': {
          'self': {
            'resubNotification': {'months': 3, 'token': 'bad token!'},
          },
        },
      },
    };

    expect(ResubNotification.tryParse(body), isNull);
  });
}
