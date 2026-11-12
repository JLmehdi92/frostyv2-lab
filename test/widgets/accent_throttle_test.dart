import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/widgets/accent_picker_controls.dart';

void main() {
  const red = Color(0xffff0000);
  const green = Color(0xff00ff00);
  const blue = Color(0xff0000ff);

  testWidgets('a drag applies at once, then at most every 100 ms, then '
      'the last colour', (tester) async {
    final applied = <Color>[];
    final apply = AccentThrottle(applied.add);

    apply(red);
    expect(applied, [red]);
    apply(green);
    apply(blue);
    expect(applied, [red]);
    await tester.pump(const Duration(milliseconds: 100));
    expect(applied, [red, blue]);

    apply(green);
    expect(applied, [red, blue, green]);
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('flush applies the waiting colour now; cancel drops it', (
    tester,
  ) async {
    final applied = <Color>[];
    final apply = AccentThrottle(applied.add);

    apply(red);
    apply(green);
    apply.flush();
    expect(applied, [red, green]);
    await tester.pump(const Duration(milliseconds: 200));
    expect(applied, [red, green]);

    apply(blue);
    apply(red);
    apply.cancel();
    await tester.pump(const Duration(milliseconds: 200));
    expect(applied, [red, green, blue]);

    apply.flush();
    expect(applied, [red, green, blue]);
  });
}
