import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/chat/widgets/chat_bottom_bar.dart';

void main() {
  ({bool pencil, bool send}) controls({
    double chatWidth = 0.2,
    bool landscape = true,
    bool showVideo = true,
    bool expandChat = false,
  }) => ChatBottomBar.inputControls(
    chatWidth: chatWidth,
    landscape: landscape,
    showVideo: showVideo,
    expandChat: expandChat,
  );

  test('a landscape side chat under 30% gets the pencil until expanded', () {
    expect(controls(), (pencil: true, send: false));
    expect(controls(expandChat: true), (pencil: false, send: true));
  });

  test('a side chat from 30% has the text field and the send button', () {
    expect(controls(chatWidth: 0.3), (pencil: false, send: true));
  });

  test('portrait and chat-only never show the pencil', () {
    expect(controls(landscape: false), (pencil: false, send: true));
    expect(controls(showVideo: false).pencil, isFalse);
  });

  test("ONSET's rule holds in every configuration", () {
    for (var w = 10; w <= 60; w++) {
      final chatWidth = w / 100;
      for (final landscape in [false, true]) {
        for (final showVideo in [false, true]) {
          for (final expandChat in [false, true]) {
            expect(
              controls(
                chatWidth: chatWidth,
                landscape: landscape,
                showVideo: showVideo,
                expandChat: expandChat,
              ),
              (
                pencil:
                    !expandChat && chatWidth < 0.3 && showVideo && landscape,
                send: chatWidth >= 0.3 || expandChat || !landscape,
              ),
              reason:
                  '$chatWidth landscape=$landscape video=$showVideo '
                  'expand=$expandChat',
            );
          }
        }
      }
    }
  });
}
