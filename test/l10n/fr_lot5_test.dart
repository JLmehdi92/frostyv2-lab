import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_channel_profile_service.dart';
import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/models/channel_profile.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/team.dart';
import 'package:onset/screens/channel/chat/widgets/points_intro.dart';
import 'package:onset/screens/channel/video/video_overlay.dart';
import 'package:onset/screens/channel_profile/team_screen.dart';
import 'package:onset/screens/channel_profile/widgets/profile_extras.dart';
import 'package:onset/screens/channel_profile/widgets/profile_schedule_tab.dart';
import 'package:onset/screens/channel_profile/widgets/schedule_slot_sheet.dart';
import 'package:onset/screens/home/search/search.dart';
import 'package:onset/screens/home/stream_list/streams_list.dart';
import 'package:onset/screens/settings/account/block_reason_picker.dart';
import 'package:onset/screens/settings/not_interested_channels.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/whispers/whisper_actions.dart';
import 'package:onset/widgets/share_sheet.dart';

import '../helpers/l10n.dart';

final _segment = ScheduleSegment(
  id: 's',
  startAt: DateTime.utc(2030, 1, 7, 18),
  endAt: DateTime.utc(2030, 1, 7, 21),
  title: 'Speedrun',
  categoryName: 'Celeste',
);

const _team = Team(
  id: '1',
  name: 'equipe',
  displayName: 'Équipe',
  info: 'Une équipe de joueurs.',
  members: [
    TeamMember(id: '1', login: 'alpha', displayName: 'Alpha'),
    TeamMember(id: '2', login: 'beta', displayName: 'Beta'),
  ],
);

Map<String, Widget Function()> lot5Screens() => {
  'the new whisper sheet': () => Scaffold(
    body: NewWhisperSheet(search: ({required query}) async => const []),
  ),
  'the hidden channels': () => Scaffold(
    body: NotInterestedChannels(
      settingsStore: SettingsStore()
        ..markNotInterested('1', 'Alpha')
        ..markNotInterested('2', 'Beta'),
    ),
  ),
  'a team page': () => TeamScreen(
    name: 'equipe',
    initial: _team,
    loadTeam: (_) async => _team,
    loadLive: (_) async => const [
      StreamTwitch('2', 'beta', 'Beta', '1', 'Discussion', 'Partie', 42, '', ''),
    ],
  ),
  'the trailer and the teams': () => Scaffold(
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ProfileTrailerCard(
          trailer: const ChannelTrailer(
            videoId: '1',
            title: 'Bienvenue',
            length: Duration(minutes: 1, seconds: 15),
          ),
          onOpen: () {},
        ),
        const SizedBox(height: 16),
        ProfileTeams(teams: const [_team], onOpen: (_) {}),
      ],
    ),
  ),
  'the schedule with a break': () => Scaffold(
    body: SingleChildScrollView(
      child: ProfileScheduleContent(
        schedule: ChannelSchedule(segments: [_segment]),
        now: DateTime.utc(2030, 1, 6),
        login: 'chaine',
        extras: ScheduleExtras(
          vacationStart: DateTime.utc(2030, 1, 20),
          vacationEnd: DateTime.utc(2030, 1, 27),
          recurringStarts: {_segment.startAt},
        ),
      ),
    ),
  ),
  'a schedule slot': () => Scaffold(
    body: ScheduleSlotSheet(
      segment: _segment,
      login: 'chaine',
      recurring: true,
      reminder: (set: false, toggle: () {}),
    ),
  ),
  'the share sheet': () => Scaffold(
    body: ShareSheet(
      url: 'https://www.twitch.tv/chaine',
      viewerId: '7',
      channelId: '1',
      channelName: 'Chaîne',
      sendToChat:
          ({
            required broadcasterId,
            required senderId,
            required message,
          }) async {},
      onShare: () async {},
      pickWhisperTarget: (_) async => null,
    ),
  ),
  'the points intro and how to earn them': () => Scaffold(
    body: ListView(
      children: [
        PointsIntroCard(onDismiss: () {}, onLearnMore: () {}),
        const PointsEarnSheet(),
      ],
    ),
  ),
  'an offline channel': () => Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: OfflineChannelMessage(
        name: 'Chaîne',
        failed: false,
        onRetry: () async {},
        action: const SizedBox.shrink(),
      ),
    ),
  ),
  'search suggestions and the new videos badge': () => const Scaffold(
    body: Column(
      children: [
        SearchSuggestionsRow(
          suggestions: [
            SearchSuggestion(
              text: 'Chaîne',
              kind: SearchSuggestionKind.channel,
              login: 'chaine',
            ),
            SearchSuggestion(text: 'speedrun'),
          ],
          onUse: _ignore,
        ),
        NewVideosBadge(count: 4),
        BlockReasonPicker(selected: null, onSelected: _ignoreReason),
      ],
    ),
  ),
};

void _ignore(SearchSuggestion _) {}

void _ignoreReason(Object? _) {}

void main() {
  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      final at = '$sizeName, text ×$scale';
      for (final MapEntry(key: name, value: build) in lot5Screens().entries) {
        testWidgets('$name, $at', (tester) async {
          await pumpLocalized(tester, build(), size: size, textScale: scale);
          await tester.pumpAndSettle();
          await expectFrenchThroughout(
            tester,
            '$name, $at',
            content: const [
              'Alpha',
              'Beta',
              'Speedrun',
              'Celeste',
              'Bienvenue',
              'Équipe',
              'Une équipe de joueurs.',
              'Chaîne',
              'speedrun',
              'Partie',
              'Discussion',
            ],
          );
        });
      }
    }
  }
}
