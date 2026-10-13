import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/utils/image_size.dart';

void main() {
  test('rounds up to the step at the device pixel ratio', () {
    // A row card thumbnail in a three-column Pad 7 grid: ~178 dp at 2x.
    expect(imagePixelWidth(178, 2), 480);
    expect(imagePixelWidth(80, 3), 320);
  });

  test('never above the cap, never zero', () {
    expect(imagePixelWidth(1600, 2), 1920);
    expect(imagePixelWidth(0, 2), 160);
    expect(imagePixelWidth(double.infinity, 2), 160);
  });
}
