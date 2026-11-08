import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/channel_profile.dart';
import 'package:onset/screens/channel_profile/widgets/profile_schedule_tab.dart';
import 'package:onset/screens/channel_profile/widgets/schedule_slot_sheet.dart';

import '../../helpers/l10n.dart';

final _now = DateTime.utc(2026, 11, 8, 12);

final _segment = ScheduleSegment(
  id: 'seg1',
  startAt: DateTime.utc(2026, 11, 9, 18),
  endAt: DateTime.utc(2026, 11, 9, 21),
  title: 'Speedruns',
  categoryName: 'Celeste',
);

void main() {
  test('Helix extras: the vacation and the weekly streams', () {
    final extras = ScheduleExtras.fromHelix({
      'data': {
        'vacation': {
          'start_time': '2026-11-01T00:00:00Z',
          'end_time': '2026-11-20T00:00:00Z',
        },
        'segments': [
          {'start_time': '2026-11-09T18:00:00Z', 'is_recurring': true},
          {'start_time': '2026-11-10T18:00:00Z', 'is_recurring': false},
        ],
      },
    });
    expect(extras.onVacationAfter(_now), isTrue);
    expect(extras.onVacationAfter(DateTime.utc(2026, 12)), isFalse);
    expect(extras.isRecurring(_segment), isTrue);
    expect(ScheduleExtras.fromHelix({'data': null}).recurringStarts, isEmpty);
  });

  test('a slot link points to the stream on the channel schedule', () {
    expect(
      scheduleSlotUri('Streamer', _segment).toString(),
      'https://www.twitch.tv/streamer/schedule?segmentID=seg1',
    );
  });

  testWidgets('the vacation banner, the weekly tag and the slot detail', (
    tester,
  ) async {
    await pumpLocalized(
      tester,
      locale: en,
      Scaffold(
        body: SingleChildScrollView(
          child: ProfileScheduleContent(
            schedule: ChannelSchedule(segments: [_segment]),
            now: _now,
            login: 'streamer',
            extras: ScheduleExtras(
              vacationStart: DateTime.utc(2026, 11, 20),
              vacationEnd: DateTime.utc(2026, 11, 27),
              recurringStarts: {_segment.startAt},
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('On a break from'), findsOneWidget);
    expect(find.textContaining('Weekly'), findsOneWidget);

    await tester.tap(find.text('Speedruns'));
    await tester.pumpAndSettle();
    expect(find.text('Repeats every week'), findsOneWidget);
    expect(find.text('Share this stream'), findsOneWidget);
    expect(find.text('Celeste'), findsOneWidget);
  });

  testWidgets('the schedule extras read in French', (tester) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: ScheduleSlotSheet(
          segment: _segment,
          login: 'streamer',
          recurring: true,
        ),
      ),
    );
    expect(find.text('Se répète chaque semaine'), findsOneWidget);
    expect(englishLeaks(tester, content: ['Speedruns', 'Celeste']), isEmpty);
  });
}
