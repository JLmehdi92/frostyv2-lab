import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/channel_profile.dart';
import 'package:onset/screens/channel_profile/widgets/profile_about_tab.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

import '../helpers/l10n.dart';

const _djProfile = ChannelProfile(
  id: '1',
  login: 'djchannel',
  displayName: 'DjChannel',
  description: 'Sets tous les soirs.',
  role: BroadcasterRole.affiliate,
  isParticipatingDj: true,
  followers: 12400,
);

Widget lot9bScreen(String name) => Scaffold(
  body: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: name == 'dj about'
        ? ProfileAboutContent(profile: _djProfile, onOpenLink: (_) {})
        : Builder(
            builder: (context) => SheetRow(
              glyph: SheetGlyphKind.pin,
              label: context.l10n.chatPinMessage,
              onTap: () {},
            ),
          ),
  ),
);

const lot9bScreenNames = ['dj about', 'pin row'];

void main() {
  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      for (final name in lot9bScreenNames) {
        testWidgets('$name, $sizeName, text ×$scale', (tester) async {
          await pumpLocalized(
            tester,
            lot9bScreen(name),
            size: size,
            textScale: scale,
          );
          await tester.pump();
          if (name == 'dj about') {
            expect(
              find.textContaining('DJ officiel de Twitch'),
              findsOneWidget,
            );
          }
          await expectFrenchThroughout(
            tester,
            '$name, $sizeName, ×$scale',
            content: const ['DjChannel', 'Sets tous les soirs.'],
          );
        });
      }
    }
  }
}
