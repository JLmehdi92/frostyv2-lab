import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:onset/screens/channel_profile/widgets/profile_schedule_tab.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';

import '../helpers/l10n.dart';

/// Numbers and dates written in the language on screen: the compact
/// counts of the cards, and the schedule's day headings.
void main() {
  // From nothing to two billion, the steps where the unit changes.
  const counts = [
    0,
    1,
    999,
    1000,
    1200,
    2445,
    12600,
    999999,
    1000000,
    12600000,
    1000000000,
    2000000000,
  ];

  group('formatViewers', () {
    test('English: lower case, as the cards always drew it', () async {
      await useLocale(en);
      // The English intl gives "1.2K", "12.6M", "2B": the cards draw them
      // lowered, as they always did.
      expect(formatViewers(1200), '1.2k');
      expect(formatViewers(12600000), '12.6m');
      expect(formatViewers(2000000000), '2b');
      for (final n in counts) {
        expect(
          formatViewers(n),
          NumberFormat.compact(locale: 'en').format(n).toLowerCase(),
          reason: '$n',
        );
      }
      expect(formatViewers(2445, compact: false), '2,445');
    });

    test('French: intl\'s own units, never lowered (« M » is a million, '
        '« m » a metre)', () async {
      await useLocale(fr);
      for (final n in counts) {
        expect(
          formatViewers(n),
          NumberFormat.compact(locale: 'fr').format(n),
          reason: '$n',
        );
      }
      expect(formatViewers(1200), '1,2 k');
      expect(formatViewers(12600000), '12,6 M');
      expect(formatViewers(2000000000), '2 Md');
      expect(formatViewers(12600000), isNot(contains('m')));
      expect(formatViewers(2445, compact: false), '2 445');
    });
  });

  group('scheduleDayTitle', () {
    test('English, as intl writes it', () async {
      await useLocale(en);
      expect(scheduleDayTitle(DateTime(2026, 11)), 'Sunday, November 1');
      expect(scheduleDayTitle(DateTime(2026, 11, 2)), 'Monday, November 2');
    });

    test('French: a title\'s capital, and « 1er » for the first', () async {
      await useLocale(fr);
      expect(scheduleDayTitle(DateTime(2026, 11)), 'Dimanche 1er novembre');
      expect(scheduleDayTitle(DateTime(2026, 11, 2)), 'Lundi 2 novembre');
      expect(scheduleDayTitle(DateTime(2026, 11, 11)), 'Mercredi 11 novembre');
      expect(scheduleDayTitle(DateTime(2026, 11, 21)), 'Samedi 21 novembre');
      expect(scheduleDayTitle(DateTime(2027)), 'Vendredi 1er janvier');
    });
  });
}
