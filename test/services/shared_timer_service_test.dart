import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/services/shared_timer_service.dart';

void main() {
  test('the shared tick stops in the background and resumes with one tick', () {
    fakeAsync((async) {
      final timer = SharedTimerService.instance;
      var ticks = 0;
      void listener() => ticks++;
      timer.addListener(listener);
      async.elapse(const Duration(seconds: 3));
      expect(ticks, 3);

      timer.pause();
      async.elapse(const Duration(minutes: 1));
      expect(ticks, 3);

      timer.resume();
      expect(ticks, 4);
      async.elapse(const Duration(seconds: 2));
      expect(ticks, 6);

      timer.removeListener(listener);
      async.elapse(const Duration(seconds: 2));
      expect(ticks, 6);
    });
  });

  test('a listener added in the background waits for the resume', () {
    fakeAsync((async) {
      final timer = SharedTimerService.instance..pause();
      var ticks = 0;
      void listener() => ticks++;
      timer.addListener(listener);
      async.elapse(const Duration(seconds: 5));
      expect(ticks, 0);
      timer.resume();
      async.elapse(const Duration(seconds: 1));
      expect(ticks, 2);
      timer.removeListener(listener);
    });
  });
}
