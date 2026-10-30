import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/video/buffer_fallback.dart';

void main() {
  late DateTime now;
  late BufferFallback fallback;

  setUp(() {
    now = DateTime(2026, 10, 30, 20);
    fallback = BufferFallback(now: () => now);
  });

  test('one stall is not enough', () {
    expect(fallback.onUltraRebuffer(), isFalse);
    expect(fallback.active, isFalse);
  });

  test('two stalls within a minute trip it', () {
    fallback.onUltraRebuffer();
    now = now.add(const Duration(seconds: 59));

    expect(fallback.onUltraRebuffer(), isTrue);
    expect(fallback.active, isTrue);
    expect(fallback.until, now.add(BufferFallback.holdFor));
  });

  test('two stalls further apart do not', () {
    fallback.onUltraRebuffer();
    now = now.add(const Duration(seconds: 61));

    expect(fallback.onUltraRebuffer(), isFalse);
    expect(fallback.active, isFalse);
  });

  test('wears off after its hold', () {
    fallback
      ..onUltraRebuffer()
      ..onUltraRebuffer();

    now = now.add(BufferFallback.holdFor - const Duration(seconds: 1));
    expect(fallback.active, isTrue);
    now = now.add(const Duration(seconds: 1));
    expect(fallback.active, isFalse);
    expect(fallback.until, isNull);
  });

  test('stalls counted before it tripped do not count again', () {
    fallback
      ..onUltraRebuffer()
      ..onUltraRebuffer();
    now = now.add(BufferFallback.holdFor);

    expect(fallback.onUltraRebuffer(), isFalse);
  });

  test('the app shares one', () {
    expect(BufferFallback.shared, same(BufferFallback.shared));
  });
}
