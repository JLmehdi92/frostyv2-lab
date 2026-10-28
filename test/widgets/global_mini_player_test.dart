import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/widgets/global_mini_player.dart';

void main() {
  const phone = MediaQueryData(size: Size(390, 844));

  test("under the shell's header and above its bar (board MiniLecteur)", () {
    // Home's header (100) and the floating bar (14 + 64).
    final area = MiniWindowArea.of(
      phone,
      chrome: const EdgeInsets.only(top: 100, bottom: 78),
    );
    expect(area.window.width, closeTo(164, 0.5));
    expect(area.window.height, closeTo(92, 0.5));
    expect(area.top, 112);
    expect(area.bottom, closeTo(662, 0.5));
    expect(area.initial.dx, closeTo(214, 0.5));
    expect(area.initial.dy, 112);

    // Dragged anywhere, it snaps to the nearest corner inside.
    expect(area.snap(const Offset(20, 700)), Offset(12, area.bottom));
    expect(area.snap(const Offset(300, 120)), Offset(area.initial.dx, 112));
    // Never over the header or the bar.
    expect(area.clamp(const Offset(100, 0)).dy, 112);
    expect(area.clamp(const Offset(100, 900)).dy, area.bottom);
  });

  test('on any other page: under a standard app bar', () {
    final area = MiniWindowArea.of(
      phone.copyWith(padding: const EdgeInsets.only(top: 24, bottom: 16)),
    );
    expect(area.top, 24 + kToolbarHeight + 12);
    expect(area.bottom, closeTo(844 - 92.1375 - 16 - 12, 0.01));
  });

  test('a screen too short for both: the header wins', () {
    final area = MiniWindowArea.of(
      const MediaQueryData(size: Size(844, 390)),
      chrome: const EdgeInsets.only(top: 100, bottom: 78),
    );
    expect(area.bottom, area.top);
    expect(area.clamp(const Offset(0, 500)).dy, area.top);
  });

  test('the chrome changing keeps a corner a corner', () {
    final home = MiniWindowArea.of(
      phone,
      chrome: const EdgeInsets.only(top: 100, bottom: 78),
    );
    final profile = MiniWindowArea.of(
      phone,
      chrome: const EdgeInsets.only(top: 56, bottom: 78),
    );
    // A corner is kept as a corner: under each header, above the bar.
    final corner = profile.nearest(const Offset(300, 70));
    expect(corner, MiniCorner.topRight);
    expect(profile.at(corner).dy, 68);
    expect(home.at(corner).dy, 112);
    final low = home.nearest(const Offset(10, 700));
    expect(low, MiniCorner.bottomLeft);
    final page = MiniWindowArea.of(phone);
    // On a page without the bar the window goes back down to the edge.
    expect(page.at(low).dy, greaterThan(home.at(low).dy));
  });
}
