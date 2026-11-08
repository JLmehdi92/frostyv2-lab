import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/overlay_chat_placement.dart';

class OverlayChatFrame extends StatefulWidget {
  const OverlayChatFrame({
    super.key,
    required this.width,
    required this.placement,
    required this.showHandles,
    required this.onPlacementChanged,
    required this.onLeftSideChanged,
    required this.leftSide,
    required this.child,
  });

  final double width;
  final OverlayChatPlacement placement;
  final bool showHandles;
  final bool leftSide;
  final ValueChanged<OverlayChatPlacement> onPlacementChanged;
  final ValueChanged<bool> onLeftSideChanged;
  final Widget child;

  @override
  State<OverlayChatFrame> createState() => _OverlayChatFrameState();
}

class _OverlayChatFrameState extends State<OverlayChatFrame> {
  double? _pointerX;

  void _move(DragUpdateDetails details, double height) {
    _pointerX = details.globalPosition.dx;
    widget.onPlacementChanged(
      widget.placement.movedBy(details.delta.dy / height),
    );
  }

  void _endMove(DragEndDetails _) {
    final pointerX = _pointerX;
    _pointerX = null;
    if (pointerX == null) return;
    final left = overlayChatOnLeftAfterDrag(
      pointerX: pointerX,
      screenWidth: MediaQuery.sizeOf(context).width,
    );
    if (left != widget.leftSide) widget.onLeftSideChanged(left);
  }

  void _resize(DragUpdateDetails details, double height) =>
      widget.onPlacementChanged(
        widget.placement.resizedBy(details.delta.dy / height),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final placement = widget.placement;
        return SizedBox(
          width: widget.width,
          height: height,
          child: Stack(
            children: [
              Positioned(
                top: height * placement.top,
                height: height * placement.height,
                left: 0,
                right: 0,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.child,
                    if (widget.showHandles) ...[
                      Align(
                        alignment: Alignment.topCenter,
                        child: _Grip(
                          key: const ValueKey('overlay-chat-move'),
                          label: l.overlayChatMove,
                          onUpdate: (details) => _move(details, height),
                          onEnd: _endMove,
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: _Grip(
                          key: const ValueKey('overlay-chat-resize'),
                          label: l.overlayChatResize,
                          onUpdate: (details) => _resize(details, height),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Grip extends StatelessWidget {
  const _Grip({
    super.key,
    required this.label,
    required this.onUpdate,
    this.onEnd,
  });

  final String label;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback? onEnd;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Tooltip(
      message: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: onUpdate,
        onPanEnd: onEnd,
        child: SizedBox(
          width: 72,
          height: 28,
          child: Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0x99FFFFFF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
