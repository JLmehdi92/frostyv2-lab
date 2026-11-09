import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/community_highlight_event.dart';

import '../../../../helpers/community_highlights_harness.dart';

void main() {
  late Harness h;

  setUp(() => h = Harness());

  void run(void Function(FakeAsync async) body) =>
      fakeAsync(body, initialTime: harnessNow);

  test('a moderator unpins the current pin, then it is read again', () {
    run((async) {
      final removed = <String>[];
      var moderator = true;
      h.create(
        pinRemover: (id) async {
          removed.add(id);
          return ViewerActionOutcome.done;
        },
        canRemovePins: () => moderator,
      );
      async.flushMicrotasks();
      expect(h.store.canUnpin, isFalse);
      h.send(HighlightTopic.pinned, pinPayload('a'));
      expect(h.store.canUnpin, isTrue);
      moderator = false;
      expect(h.store.canUnpin, isFalse);
      moderator = true;

      ViewerActionOutcome? outcome;
      h.store.unpin().then((value) => outcome = value);
      async.flushMicrotasks();
      expect(outcome, ViewerActionOutcome.done);
      expect(removed, ['a']);
      async.elapse(const Duration(minutes: 1));
      verify(() => h.service.getPinned(any())).called(greaterThan(1));
      h.store.dispose();
    });
  });

  test('without a remover nothing can be unpinned', () {
    run((async) {
      h.create(canRemovePins: () => true);
      async.flushMicrotasks();
      h.send(HighlightTopic.pinned, pinPayload('a'));
      expect(h.store.canUnpin, isFalse);
      ViewerActionOutcome? outcome = ViewerActionOutcome.failed;
      h.store.unpin().then((value) => outcome = value);
      async.flushMicrotasks();
      expect(outcome, isNull);
      h.store.dispose();
    });
  });
}
