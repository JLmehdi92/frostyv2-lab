import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/screens/channel/chat/widgets/ffz_modified_emote.dart';

const _everyFlag = [
  FfzModifier.flipX,
  FfzModifier.flipY,
  FfzModifier.slide,
  FfzModifier.appear,
  FfzModifier.disappear,
  FfzModifier.rotate,
  FfzModifier.rotate90,
  FfzModifier.greyscale,
  FfzModifier.sepia,
  FfzModifier.rainbow,
  FfzModifier.hyperRed,
  FfzModifier.hyperShake,
  FfzModifier.cursed,
  FfzModifier.jam,
  FfzModifier.bounce,
];

const _box = SizedBox(key: Key('emote'), width: 28, height: 28);

FfzModifiedEmote _emote(int modifiers, {bool animate = true}) =>
    FfzModifiedEmote(
      modifiers: modifiers,
      animate: animate,
      width: 28,
      height: 28,
      child: _box,
    );

Matrix4? _transform(WidgetTester tester) {
  final found = find.ancestor(
    of: find.byKey(const Key('emote')),
    matching: find.byType(Transform),
  );
  return found.evaluate().isEmpty
      ? null
      : tester.widget<Transform>(found.first).transform;
}

void main() {
  test('every modifier FFZ defines changes how the emote looks', () {
    for (final flag in _everyFlag) {
      final emote = _emote(flag);
      final frames = [
        for (final seconds in [0.0, 0.2, 0.37, 0.61]) emote.frame(seconds),
      ];
      expect(
        frames.any((frame) => frame is! SizedBox),
        isTrue,
        reason: 'flag $flag',
      );
    }
  });

  test('the colour modifiers tint, and the rainbow keeps turning', () {
    expect(FfzModifiedEmote.colorMatrix(FfzModifier.rotate, 0), isNull);
    final grey = FfzModifiedEmote.colorMatrix(FfzModifier.greyscale, 0)!;
    expect(grey.sublist(0, 3), grey.sublist(5, 8));
    final early = FfzModifiedEmote.colorMatrix(FfzModifier.rainbow, 0.1)!;
    final later = FfzModifiedEmote.colorMatrix(FfzModifier.rainbow, 0.9)!;
    expect(early, isNot(later));
    final red = FfzModifiedEmote.colorMatrix(FfzModifier.hyperRed, 0)!;
    expect(red[4], greaterThan(0));
  });

  test('motions stay within the emote’s own size', () {
    for (var seconds = 0.0; seconds < 3; seconds += 0.07) {
      final bounce = FfzModifiedEmote.motion(
        FfzModifier.bounce,
        seconds,
        28,
        28,
      ).getTranslation();
      expect(bounce.y, inInclusiveRange(-7.01, 0));
      final slide = FfzModifiedEmote.motion(
        FfzModifier.slide,
        seconds,
        28,
        28,
      ).getTranslation();
      expect(slide.x, inInclusiveRange(-28, 28));
    }
  });

  testWidgets('a spinning emote turns over time', (tester) async {
    await tester.pumpWidget(Center(child: _emote(FfzModifier.rotate)));
    await tester.pump(const Duration(milliseconds: 100));
    final first = _transform(tester)!.clone();
    await tester.pump(const Duration(milliseconds: 375));
    final second = _transform(tester)!;
    expect(second, isNot(first));
    final angle = math.atan2(second.entry(1, 0), second.entry(0, 0));
    expect(angle.abs(), greaterThan(0.5));
  });

  testWidgets('one clock drives every emote and stops with the last', (
    tester,
  ) async {
    final clock = FfzModifierClock.instance;
    expect(clock.isTicking, isFalse);
    await tester.pumpWidget(
      Column(
        children: [
          _emote(FfzModifier.rotate),
          _emote(FfzModifier.bounce),
          _emote(FfzModifier.rainbow),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(clock.isTicking, isTrue);
    expect(tester.binding.transientCallbackCount, 1);

    await tester.pumpWidget(const SizedBox());
    expect(clock.isTicking, isFalse);
  });

  testWidgets('with animations off the emote keeps a still frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      Column(
        children: [
          _emote(FfzModifier.rotate | FfzModifier.flipX, animate: false),
        ],
      ),
    );
    expect(FfzModifierClock.instance.isTicking, isFalse);
    expect(find.byType(AnimatedBuilder), findsNothing);
    expect(_transform(tester)!.entry(0, 0), -1);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _emote(FfzModifier.bounce),
      ),
    );
    expect(FfzModifierClock.instance.isTicking, isFalse);
  });

  testWidgets('a quarter turn and a static tint do not tick', (tester) async {
    await tester.pumpWidget(
      Center(child: _emote(FfzModifier.rotate90 | FfzModifier.sepia)),
    );
    expect(FfzModifierClock.instance.isTicking, isFalse);
    expect(find.byType(ColorFiltered), findsOneWidget);
    expect(_transform(tester)!.entry(0, 0).abs(), lessThan(1e-9));
  });
}
