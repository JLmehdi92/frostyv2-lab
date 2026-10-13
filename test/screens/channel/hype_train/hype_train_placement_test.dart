import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_placement.dart';

void main() {
  HtPlacement place({
    bool landscape = false,
    bool forceVertical = false,
    bool fullScreen = false,
    bool overlayChat = false,
    bool showVideo = true,
    bool keyboardOpen = false,
    bool largeScreen = false,
  }) => hypeTrainPlacement(
    landscape: landscape,
    forceVertical: forceVertical,
    fullScreen: fullScreen,
    overlayChat: overlayChat,
    showVideo: showVideo,
    keyboardOpen: keyboardOpen,
    largeScreen: largeScreen,
  );

  test('portrait is always the full banner, keyboard or not', () {
    expect(place(), HtPlacement.bannerFull);
    expect(place(keyboardOpen: true), HtPlacement.bannerFull);
    expect(place(fullScreen: true), HtPlacement.bannerFull);
  });

  test('landscape with vertical chat is the full banner', () {
    expect(place(landscape: true, forceVertical: true), HtPlacement.bannerFull);
  });

  test('landscape side chat is compact', () {
    expect(place(landscape: true), HtPlacement.bannerCompact);
  });

  test('landscape full screen: overlay chat compact, hidden chat a pill', () {
    expect(
      place(landscape: true, fullScreen: true, overlayChat: true),
      HtPlacement.bannerCompact,
    );
    expect(place(landscape: true, fullScreen: true), HtPlacement.pill);
  });

  test('the landscape keyboard hides it', () {
    expect(place(landscape: true, keyboardOpen: true), HtPlacement.none);
    expect(
      place(landscape: true, fullScreen: true, keyboardOpen: true),
      HtPlacement.none,
    );
  });

  test('chat only is the full banner, except with the landscape keyboard', () {
    expect(place(showVideo: false), HtPlacement.bannerFull);
    expect(
      place(showVideo: false, landscape: true, fullScreen: true),
      HtPlacement.bannerFull,
    );
    expect(
      place(showVideo: false, landscape: true, keyboardOpen: true),
      HtPlacement.none,
    );
  });

  test('a large screen keeps it when the landscape keyboard opens', () {
    expect(
      place(landscape: true, keyboardOpen: true, largeScreen: true),
      HtPlacement.bannerCompact,
    );
    expect(
      place(
        landscape: true,
        fullScreen: true,
        overlayChat: true,
        keyboardOpen: true,
        largeScreen: true,
      ),
      HtPlacement.bannerCompact,
    );
    expect(
      place(
        showVideo: false,
        landscape: true,
        keyboardOpen: true,
        largeScreen: true,
      ),
      HtPlacement.bannerFull,
    );
  });

  test('a large screen in full screen with hidden chat is still a pill', () {
    expect(
      place(landscape: true, fullScreen: true, largeScreen: true),
      HtPlacement.pill,
    );
  });

  test('every combination has a placement', () {
    for (var bits = 0; bits < 128; bits++) {
      bool bit(int i) => bits & (1 << i) != 0;
      expect(
        HtPlacement.values,
        contains(
          hypeTrainPlacement(
            landscape: bit(0),
            forceVertical: bit(1),
            fullScreen: bit(2),
            overlayChat: bit(3),
            showVideo: bit(4),
            keyboardOpen: bit(5),
            largeScreen: bit(6),
          ),
        ),
      );
    }
  });
}
