import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/private_callout.dart';

void main() {
  test('keeps the body and the first https link', () {
    final callout = PrivateCallout.fromEvent({
      'private_callout': {
        'id': 'c1',
        'body': '  Hello there  ',
        'actions': [
          {'body': 'Open', 'url': 'http://insecure.example'},
          {'url': 'https://www.twitch.tv/x'},
        ],
      },
    })!;
    expect(callout.body, 'Hello there');
    expect(callout.actionUrl.toString(), 'https://www.twitch.tv/x');
    expect(callout.actionLabel, isNull);
  });

  test('refuses an empty, oversized or unidentified callout', () {
    expect(PrivateCallout.fromEvent({}), isNull);
    expect(
      PrivateCallout.fromEvent({
        'private_callout': {'id': 'c1', 'body': ' '},
      }),
      isNull,
    );
    expect(
      PrivateCallout.fromEvent({
        'private_callout': {'id': 'c 1', 'body': 'x'},
      }),
      isNull,
    );
    expect(
      PrivateCallout.fromEvent({
        'private_callout': {'id': 'c1', 'body': 'x' * 301},
      }),
      isNull,
    );
  });

  test('only a won prediction with points is a win', () {
    Map<String, dynamic> data(String type, Object points) => {
      'prediction': {
        'event_id': 'e1',
        'result': {'type': type, 'points_won': points},
      },
    };
    expect(
      PredictionWin.fromEvent('prediction-result', data('WIN', 40))?.points,
      40,
    );
    expect(
      PredictionWin.fromEvent('prediction-result', data('REFUND', 40)),
      isNull,
    );
    expect(
      PredictionWin.fromEvent('prediction-result', data('WIN', 0)),
      isNull,
    );
    expect(PredictionWin.fromEvent('prediction-made', data('WIN', 40)), isNull);
  });
}
