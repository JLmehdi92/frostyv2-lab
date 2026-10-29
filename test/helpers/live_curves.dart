import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts the [CurvedAnimation]s created and not yet disposed, from the
/// debug allocation events: one built per rebuild and never disposed leaves
/// a status listener on its parent each time.
class LiveCurves {
  LiveCurves._();

  final _live = <Object>{};

  void _on(ObjectEvent event) {
    if (event.object is! CurvedAnimation) return;
    if (event is ObjectCreated) {
      _live.add(event.object);
    } else if (event is ObjectDisposed) {
      _live.remove(event.object);
    }
  }

  int get count => _live.length;

  /// Starts counting; stops when the test ends.
  static LiveCurves track() {
    final curves = LiveCurves._();
    FlutterMemoryAllocations.instance.addListener(curves._on);
    addTearDown(
      () => FlutterMemoryAllocations.instance.removeListener(curves._on),
    );
    return curves;
  }
}
