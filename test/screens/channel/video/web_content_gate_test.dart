import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/video/web_content_gate.dart';

void main() {
  group('WebContentGateClicker', () {
    late List<String> scripts;

    WebContentGateClicker clicker({required bool consent}) =>
        WebContentGateClicker(
          consent: consent,
          pollScript: 'POLL',
          clickScript: 'CLICK',
          runJavaScript: (script) async => scripts.add(script),
        );

    setUp(() => scripts = []);

    test('without the viewer, it only watches the page', () async {
      final gate = clicker(consent: false);

      await gate.onPageReady();
      await gate.onPageReady();

      expect(scripts, ['POLL', 'POLL']);
    });

    test('with consent already given, every page load clicks', () async {
      final gate = clicker(consent: true);

      await gate.onPageReady();

      expect(scripts, ['POLL', 'CLICK']);
    });

    test("the viewer's acceptance clicks the page already there", () async {
      final gate = clicker(consent: false);
      await gate.onPageReady();

      await gate.accept();

      expect(scripts, ['POLL', 'CLICK']);
      expect(gate.consent, isTrue);
    });

    test('an acceptance before the page loads waits for it', () async {
      final gate = clicker(consent: false);

      await gate.accept();
      expect(scripts, isEmpty, reason: 'no page to click yet');

      await gate.onPageReady();
      expect(scripts, ['POLL', 'CLICK']);
    });

    test('a failing page never surfaces', () async {
      final gate = WebContentGateClicker(
        consent: true,
        pollScript: 'POLL',
        clickScript: 'CLICK',
        runJavaScript: (_) async => throw StateError('page gone'),
      );

      await expectLater(gate.onPageReady(), completes);
      await expectLater(gate.accept(), completes);
    });
  });
}
