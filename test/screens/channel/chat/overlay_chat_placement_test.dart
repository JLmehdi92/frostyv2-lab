import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/chat/overlay_chat_placement.dart';

void main() {
  test('moving stays on screen', () {
    const placement = OverlayChatPlacement(top: 0.2, height: 0.5);
    expect(placement.movedBy(0.1).top, closeTo(0.3, 1e-9));
    expect(
      placement.movedBy(1),
      const OverlayChatPlacement(top: 0.5, height: 0.5),
    );
    expect(
      placement.movedBy(-1),
      const OverlayChatPlacement(top: 0, height: 0.5),
    );
  });

  test('resizing keeps a usable height and stays on screen', () {
    const placement = OverlayChatPlacement(top: 0.4, height: 0.5);
    expect(placement.resizedBy(1).height, closeTo(0.6, 1e-9));
    expect(placement.resizedBy(-1).height, OverlayChatPlacement.minHeight);
  });

  test('saved values out of range are made safe', () {
    expect(
      OverlayChatPlacement.clamped(top: double.nan, height: 5),
      OverlayChatPlacement.full,
    );
    expect(
      OverlayChatPlacement.clamped(top: 0.9, height: 0.1),
      const OverlayChatPlacement(top: 0.7, height: 0.3),
    );
  });

  test('a drag ending on a half puts the chat on that side', () {
    expect(overlayChatOnLeftAfterDrag(pointerX: 100, screenWidth: 800), isTrue);
    expect(
      overlayChatOnLeftAfterDrag(pointerX: 500, screenWidth: 800),
      isFalse,
    );
  });
}
