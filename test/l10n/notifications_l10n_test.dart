import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/channel_profile.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/services/background_audio.dart';
import 'package:onset/services/go_live/go_live.dart';
import 'package:onset/services/go_live/go_live_worker.dart';
import 'package:onset/services/notifications/activity_log.dart';
import 'package:onset/services/notifications/mention_alerts.dart';
import 'package:onset/services/notifications/schedule_reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What ONSET posts to the system speaks the language the app shows: the
/// go-live, mention and reminder notices, the Android channels they are
/// listed under, the media notification's buttons, the Activity list
/// (reworded in the language on screen, old entries as they were), and the
/// background check's language, which it finds by itself.
void main() {
  final english = lookupAppLocalizations(const Locale('en'));
  final french = lookupAppLocalizations(const Locale('fr'));

  StreamTwitch stream({String title = 'Ranked', String game = 'Chess'}) =>
      StreamTwitch(
        '42',
        'streamer',
        'Streamer',
        '7',
        game,
        title,
        12,
        '2026-10-20T10:00:00Z',
        '',
      );

  group('go-live notices', () {
    test('in English, as before', () {
      final notice = goLiveNotice(stream(), english);
      expect(notice.title, 'Streamer is live');
      expect(notice.body, 'Ranked · Chess');
      expect(goLiveNotice(stream(game: ''), english).body, 'Ranked');
      expect(goLiveNotice(stream(title: ' '), english).body, 'Chess');
      expect(english.notifGoLiveMore(count: 1), '1 more channel went live');
      expect(english.notifGoLiveMore(count: 3), '3 more channels went live');
    });

    test('in French, the category first', () {
      final notice = goLiveNotice(stream(), french);
      expect(notice.title, 'Streamer est en direct');
      expect(notice.body, 'Chess · Ranked');
      expect(
        french.notifGoLiveMore(count: 1),
        '1 autre chaîne a lancé un live',
      );
      expect(
        french.notifGoLiveMore(count: 3),
        '3 autres chaînes ont lancé un live',
      );
    });

    test('the paused notice is a code, an old English one read as it', () {
      SharedPreferences.setMockInitialValues({
        'go_live_problem': kGoLiveLoggedOutLegacy,
      });
      return GoLivePrefs.load().then((prefs) async {
        expect(prefs.problem, kGoLiveLoggedOut);
        await prefs.setProblem(kGoLiveLoggedOut);
        final saved = await SharedPreferences.getInstance();
        expect(saved.getString('go_live_problem'), 'logged_out');
      });
    });
  });

  group('Android channels are named in the language shown', () {
    AndroidNotificationDetails android(NotificationDetails details) =>
        details.android!;

    test('go-live, mentions, reminders', () {
      for (final (l, live, mentions, reminders) in [
        (english, 'Go live', 'Chat Mentions', 'Stream reminders'),
        (
          french,
          'Lives des chaînes suivies',
          'Mentions dans le chat',
          'Rappels de lives',
        ),
      ]) {
        final go = android(GoLiveNotifications.detailsFor(l));
        expect(go.channelId, 'go_live');
        expect(go.channelName, live);
        expect(go.channelDescription, l.notifChannelGoLiveDescription);
        final mention = android(MentionNotifications.detailsFor(l));
        expect(mention.channelId, 'chat_mentions');
        expect(mention.channelName, mentions);
        expect(mention.channelDescription, l.notifChannelMentionsDescription);
        final reminder = android(LocalReminderPlatform.detailsFor(l));
        expect(reminder.channelId, 'schedule_reminders');
        expect(reminder.channelName, reminders);
        expect(reminder.channelDescription, l.notifChannelRemindersDescription);
      }
      // The English channels keep their words.
      expect(
        android(GoLiveNotifications.detailsFor(english)).channelDescription,
        'When channels you follow go live',
      );
      expect(
        android(LocalReminderPlatform.detailsFor(english)).channelDescription,
        'Scheduled streams you asked to be reminded of',
      );
    });

    test('the media notification\'s words', () {
      expect(mediaLabelsOf(english), (
        channel: 'Playback',
        play: 'Play',
        pause: 'Pause',
        stop: 'Stop',
      ));
      expect(mediaLabelsOf(french), (
        channel: 'Lecture en cours',
        play: 'Lire',
        pause: 'Mettre en pause',
        stop: 'Arrêter',
      ));
    });
  });

  group('mention notices', () {
    Future<MentionNotice?> posted(AppLocalizations l) async {
      MentionNotice? notice;
      final alerts = MentionAlerts(
        post: (n) async => notice = n,
        inFront: () => false,
        words: () => l,
      );
      await alerts.onMention((
        messageId: 'm1',
        channelId: '42',
        channelLogin: 'streamer',
        channelName: 'Streamer',
        fromName: 'Friend',
        text: 'hey @viewer',
      ));
      return notice;
    }

    test('worded in the language shown, the message as written', () async {
      final en = (await posted(english))!;
      expect(en.title, 'Friend mentioned you in Streamer');
      expect(en.body, 'hey @viewer');
      final fr = (await posted(french))!;
      expect(fr.title, 'Mention de Friend dans le chat de la chaîne Streamer');
      expect(fr.body, 'hey @viewer');
    });
  });

  group('reminders', () {
    final reminder = ScheduleReminder(
      segmentId: 's1',
      login: 'streamer',
      channelName: 'Streamer',
      startAt: DateTime.utc(2026, 10, 20, 12),
      title: 'Ranked',
      category: 'Chess',
    );
    final untitled = ScheduleReminder(
      segmentId: 's2',
      login: 'streamer',
      channelName: 'Streamer',
      startAt: DateTime.utc(2026, 10, 20, 12),
    );

    test('in English, as before', () {
      expect(reminder.noticeTitleIn(english), "Streamer's stream is starting");
      expect(reminder.noticeBodyIn(english), 'Ranked · Chess');
      expect(untitled.noticeBodyIn(english), 'Stream');
    });

    test('in French', () {
      expect(
        reminder.noticeTitleIn(french),
        'Le live de la chaîne Streamer commence',
      );
      expect(reminder.noticeBodyIn(french), 'Chess · Ranked');
      expect(untitled.noticeBodyIn(french), 'Live prévu');
    });
  });

  group('Activity entries', () {
    final at = DateTime(2026, 10, 20, 12);

    test('read in the language on screen from what they say', () {
      final live = goLiveEntry(goLiveNotice(stream(), english), at);
      expect(live.titleIn(french), 'Streamer est en direct');
      expect(live.bodyIn(french), 'Chess · Ranked');
      expect(live.titleIn(english), 'Streamer is live');
      expect(live.bodyIn(english), 'Ranked · Chess');

      final mention = mentionEntry((
        messageId: 'm1',
        channelId: '42',
        channelLogin: 'streamer',
        sender: 'Friend',
        channelName: 'Streamer',
        title: 'Friend mentioned you in Streamer',
        body: 'hey @viewer',
      ), at);
      expect(
        mention.titleIn(french),
        'Mention de Friend dans le chat de la chaîne Streamer',
      );
      expect(mention.bodyIn(french), 'hey @viewer');

      final reminder = ScheduleReminder(
        segmentId: 's1',
        login: 'streamer',
        channelName: 'Streamer',
        startAt: at,
      ).entryIn(english);
      expect(
        reminder.titleIn(french),
        'Le live de la chaîne Streamer commence',
      );
      expect(reminder.bodyIn(french), 'Live prévu');
      expect(reminder.bodyIn(english), 'Stream');
    });

    test('keep what they say across a save', () {
      final live = goLiveEntry(goLiveNotice(stream(), english), at);
      final read = ActivityEntry.fromJson(
        jsonDecode(jsonEncode(live.toJson())),
      )!;
      expect(read.params, live.params);
      expect(read.titleIn(french), 'Streamer est en direct');
      expect(read.copyWith(read: true).params, live.params);
    });

    test('an entry an older version kept shows its stored words', () {
      final old = ActivityEntry.fromJson({
        'id': 'live:42:x',
        'kind': 'live',
        'title': 'Streamer is live',
        'body': 'Ranked · Chess',
        'at': at.millisecondsSinceEpoch,
      })!;
      expect(old.params, isNull);
      expect(old.titleIn(french), 'Streamer is live');
      expect(old.bodyIn(french), 'Ranked · Chess');
    });

    test('every kind reads in both languages', () {
      for (final kind in ActivityKind.values) {
        final entry = ActivityEntry(
          id: kind.name,
          kind: kind,
          title: 'stored',
          body: 'stored body',
          at: at,
          params: const {
            'name': 'Streamer',
            'sender': 'Friend',
            'channel': 'Streamer',
          },
        );
        for (final l in [english, french]) {
          expect(entry.titleIn(l), isNot('stored'), reason: kind.name);
          expect(entry.titleIn(l), contains('Streamer'), reason: kind.name);
        }
      }
    });
  });

  group('the background check\'s language', () {
    test('uiLanguageIn: saved, then the settings, then the device, then '
        'English', () {
      expect(uiLanguageIn(saved: 'fr'), 'fr');
      expect(
        uiLanguageIn(saved: 'en', settingsJson: '{"appLanguage":"fr"}'),
        'en',
      );
      expect(uiLanguageIn(settingsJson: '{"appLanguage":"fr"}'), 'fr');
      expect(
        uiLanguageIn(
          settingsJson: '{"appLanguage":"system"}',
          device: const [Locale('fr', 'CA')],
        ),
        'fr',
      );
      expect(
        uiLanguageIn(
          saved: 'de',
          settingsJson: 'not json',
          device: const [Locale('de'), Locale('fr')],
        ),
        'fr',
      );
      expect(uiLanguageIn(device: const [Locale('de')]), 'en');
      expect(uiLanguageIn(), 'en');
    });

    test('useBackgroundLanguage shows it, dates loaded', () async {
      final previous = Intl.defaultLocale;
      addTearDown(() {
        L10n.use(const Locale('en'));
        Intl.defaultLocale = previous;
      });
      SharedPreferences.setMockInitialValues({
        'settings': '{"appLanguage":"system"}',
        kUiLanguagePrefsKey: 'fr',
      });
      final l = await useBackgroundLanguage(
        await SharedPreferences.getInstance(),
        const [Locale('en')],
      );
      expect(l.localeName, 'fr');
      expect(L10n.current.localeName, 'fr');
      expect(Intl.defaultLocale, 'fr');
      // French month names: the isolate loaded them itself.
      expect(DateFormat.MMMM().format(DateTime(2026, 6)), 'juin');
      expect(goLiveNotice(stream()).title, 'Streamer est en direct');
    });

    test('without a saved language, the device\'s', () async {
      addTearDown(() => L10n.use(const Locale('en')));
      SharedPreferences.setMockInitialValues({});
      final l = await useBackgroundLanguage(
        await SharedPreferences.getInstance(),
        const [Locale('fr', 'FR')],
      );
      expect(l.localeName, 'fr');
    });
  });

  testWidgets('switching the language words the reminders again and the '
      'media notification\'s buttons (LocaleSync)', (tester) async {
    addTearDown(() => L10n.use(const Locale('en')));
    SharedPreferences.setMockInitialValues({});
    final platform = _RecordingReminderPlatform();
    final reminders = ScheduleReminders(
      prefs: await SharedPreferences.getInstance(),
      platform: platform,
      now: () => DateTime.utc(2026, 10, 20, 12),
    );
    await reminders.toggle(
      ScheduleSegment(
        id: 's1',
        startAt: DateTime.utc(2026, 10, 20, 16),
        title: 'Tournoi',
        categoryName: 'Échecs',
      ),
      login: 'streamer',
      channelName: 'Streamer',
    );
    final labels = <MediaLabels>[];
    Widget app(Locale locale) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => LocaleSync(
        onLocale: [
          (_) => reminders.reschedule(),
          (_) => labels.add(mediaLabelsOf(L10n.current)),
        ],
        child: child!,
      ),
      home: const SizedBox.shrink(),
    );
    await tester.pumpWidget(app(const Locale('en')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(const Locale('fr')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    final notice = platform.scheduled[reminderNoticeId('s1')]!;
    expect(notice.title, 'Le live de la chaîne Streamer commence');
    expect(notice.body, 'Échecs · Tournoi');
    expect(notice.language, 'fr');
    expect(labels.last.play, 'Lire');
  });
}

class _RecordingReminderPlatform implements ReminderPlatform {
  final scheduled = <int, ({String title, String body, String language})>{};

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
    required AppLocalizations l,
  }) async {
    scheduled[id] = (title: title, body: body, language: l.localeName);
  }

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}
