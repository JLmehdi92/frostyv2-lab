import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:simple_pip_mode/simple_pip.dart';

/// simple_pip_mode keeps a single platform handler: the last [PipWidget]
/// created receives every PiP event. When a player screen is back on top
/// (the screen above it closed), point the events at its [PipWidget] again.
void reclaimPipCallbacks(GlobalKey<PipWidgetState> key) {
  final state = key.currentState;
  if (state == null) return;
  unawaited(
    SimplePip(
      onPipEntered: state.onPipEntered,
      onPipExited: state.onPipExited,
      onPipAction: state.onPipAction,
    ).setPipActionsLayout(state.widget.pipLayout),
  );
}
