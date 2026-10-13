import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/chat/emote_menu/emote_menu_section.dart';
import 'package:frosty/widgets/global_mini_player.dart';

void main() {
  test(
    'the mini player keeps 42% on phones and stops at 400 dp on tablets',
    () {
      expect(miniPlayerWidth(360, largeScreen: false), closeTo(151.2, 0.01));
      expect(miniPlayerWidth(740, largeScreen: false), closeTo(310.8, 0.01));
      // A 21:9 phone in landscape keeps its 42%.
      expect(miniPlayerWidth(960, largeScreen: false), closeTo(403.2, 0.01));
      expect(miniPlayerWidth(1600, largeScreen: true), 400);
      expect(miniPlayerWidth(1067, largeScreen: true), 400);
    },
  );

  group('emoteGridDelegate', () {
    test('phones keep 8, 6 or 16 columns', () {
      int columns({required bool portrait, required bool showVideo}) =>
          (emoteGridDelegate(
                    largeScreen: false,
                    portrait: portrait,
                    showVideo: showVideo,
                  )
                  as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount;

      expect(columns(portrait: true, showVideo: true), 8);
      expect(columns(portrait: false, showVideo: true), 6);
      expect(columns(portrait: false, showVideo: false), 16);
    });

    test('a large screen caps the cell size', () {
      final delegate =
          emoteGridDelegate(largeScreen: true, portrait: true, showVideo: true)
              as SliverGridDelegateWithMaxCrossAxisExtent;
      expect(delegate.maxCrossAxisExtent, kLargeScreenEmoteCell);
    });
  });
}
