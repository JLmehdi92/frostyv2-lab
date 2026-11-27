import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/video/slow_frames.dart';

void main() {
  test('counts the frames over 16 ms of the last 10 seconds', () {
    var now = DateTime(2026, 11, 27, 20);
    final frames = SlowFrames(now: () => now);

    frames.add(const [
      Duration(milliseconds: 8),
      Duration(milliseconds: 16),
      Duration(milliseconds: 17),
      Duration(milliseconds: 40),
    ]);
    expect(frames.count, 2);

    now = now.add(const Duration(seconds: 6));
    frames.add(const [Duration(milliseconds: 33)]);
    expect(frames.count, 3);

    now = now.add(const Duration(seconds: 5));
    expect(frames.count, 1);

    now = now.add(const Duration(seconds: 5));
    expect(frames.count, 0);
  });
}
