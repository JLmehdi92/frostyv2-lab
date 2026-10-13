import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/chat/widgets/chat_bottom_bar.dart';

void main() {
  ({bool pencil, bool send}) controls({
    double screenWidth = 1600,
    double chatWidth = 0.2,
    bool landscape = true,
    bool forceVerticalChat = false,
    bool showVideo = true,
    bool expandChat = false,
    bool largeScreen = true,
  }) => ChatBottomBar.inputControls(
    screenWidth: screenWidth,
    chatWidth: chatWidth,
    landscape: landscape,
    forceVerticalChat: forceVerticalChat,
    showVideo: showVideo,
    expandChat: expandChat,
    largeScreen: largeScreen,
  );

  test('a tablet side chat at the default width has the text field', () {
    expect(controls(), (pencil: false, send: true));
  });

  test('a narrow tablet side chat gets the pencil until expanded', () {
    expect(controls(screenWidth: 800), (pencil: true, send: false));
    expect(controls(screenWidth: 800, expandChat: true), (
      pencil: false,
      send: true,
    ));
  });

  test('a full-width tablet chat never shows the pencil', () {
    expect(controls(landscape: false).pencil, isFalse);
    expect(controls(screenWidth: 800, forceVerticalChat: true).pencil, isFalse);
    expect(controls(screenWidth: 800, showVideo: false).pencil, isFalse);
  });

  test('phones keep the original rule in every configuration', () {
    for (final screenWidth in const <double>[360, 640, 740, 915, 960]) {
      for (var w = 20; w <= 60; w++) {
        final chatWidth = w / 100;
        for (final landscape in [false, true]) {
          for (final showVideo in [false, true]) {
            for (final expandChat in [false, true]) {
              for (final forceVerticalChat in [false, true]) {
                final reason =
                    '$screenWidth × $chatWidth landscape=$landscape '
                    'video=$showVideo expand=$expandChat '
                    'vertical=$forceVerticalChat';
                expect(
                  controls(
                    screenWidth: screenWidth,
                    chatWidth: chatWidth,
                    landscape: landscape,
                    forceVerticalChat: forceVerticalChat,
                    showVideo: showVideo,
                    expandChat: expandChat,
                    largeScreen: false,
                  ),
                  (
                    pencil:
                        !expandChat &&
                        chatWidth < 0.3 &&
                        showVideo &&
                        landscape,
                    send: chatWidth >= 0.3 || expandChat || !landscape,
                  ),
                  reason: reason,
                );
              }
            }
          }
        }
      }
    }
  });
}
