import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';

/// A draggable vertical divider that allows users to resize content areas
class DraggableDivider extends StatefulWidget {
  /// Called when the divider is being dragged
  final ValueChanged<double> onDrag;

  /// Called when dragging starts
  final VoidCallback? onDragStart;

  /// Called when dragging ends
  final VoidCallback? onDragEnd;

  /// The minimum width percentage (0.0 to 1.0)
  final double minWidth;

  /// The maximum width percentage (0.0 to 1.0)
  final double maxWidth;

  /// The current width percentage (0.0 to 1.0)
  final double currentWidth;

  /// Width of the draggable area
  final double dragAreaWidth;

  /// Whether the resizable area is on the left side of the divider
  final bool isResizableOnLeft;

  /// Whether to show the pill-shaped drag handle
  final bool showHandle;

  /// Whether to show the background divider line
  final bool showDividerLine;

  /// What a screen reader calls the width being resized.
  final String semanticLabel;

  /// How much one screen-reader adjustment changes the width.
  static const semanticStep = 0.05;

  const DraggableDivider({
    super.key,
    required this.onDrag,
    this.onDragStart,
    this.onDragEnd,
    this.minWidth = 0.2,
    this.maxWidth = 0.8,
    required this.currentWidth,
    this.dragAreaWidth = 24.0,
    this.isResizableOnLeft = true,
    this.showHandle = true,
    this.showDividerLine = true,
    this.semanticLabel = 'Chat width',
  });

  @override
  State<DraggableDivider> createState() => _DraggableDividerState();
}

class _DraggableDividerState extends State<DraggableDivider> {
  bool _isDragging = false;
  bool _isHovered = false;
  bool _hasHapticAtMin = false;
  bool _hasHapticAtMax = false;

  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });

    // Reset haptic flags for new drag session
    _hasHapticAtMin = false;
    _hasHapticAtMax = false;

    widget.onDragStart?.call();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    // Use delta to update position incrementally for better accuracy
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      // Get the total available width by finding the Row parent
      RenderObject? current = renderBox.parent;
      while (current != null && current is! RenderBox) {
        current = current.parent;
      }

      if (current is RenderBox) {
        final totalWidth = current.size.width;

        // Convert delta movement to width percentage change
        final deltaPercentage = details.delta.dx / totalWidth;

        // If resizable area is on left, dragging right increases width
        // If resizable area is on right, dragging left increases width
        final newWidth = widget.isResizableOnLeft
            ? (widget.currentWidth + deltaPercentage)
            : (widget.currentWidth - deltaPercentage);

        final clampedWidth = newWidth.clamp(widget.minWidth, widget.maxWidth);

        widget.onDrag(clampedWidth);

        // Provide haptic feedback once when reaching either end
        if (clampedWidth <= widget.minWidth && !_hasHapticAtMin) {
          HapticFeedback.lightImpact();
          _hasHapticAtMin = true;
        } else if (clampedWidth >= widget.maxWidth && !_hasHapticAtMax) {
          HapticFeedback.lightImpact();
          _hasHapticAtMax = true;
        }
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    widget.onDragEnd?.call();
  }

  void _handleHover(bool hovering) {
    setState(() {
      _isHovered = hovering;
    });
  }

  /// Resizes by one step for a screen reader, which cannot drag.
  void _step(double delta) => widget.onDrag(
    (widget.currentWidth + delta).clamp(widget.minWidth, widget.maxWidth),
  );

  String _percent(double width) =>
      '${(width.clamp(widget.minWidth, widget.maxWidth) * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const step = DraggableDivider.semanticStep;

    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: _percent(widget.currentWidth),
      increasedValue: _percent(widget.currentWidth + step),
      decreasedValue: _percent(widget.currentWidth - step),
      onIncrease: widget.currentWidth < widget.maxWidth
          ? () => _step(step)
          : null,
      onDecrease: widget.currentWidth > widget.minWidth
          ? () => _step(-step)
          : null,
      child: _buildHandle(colorScheme),
    );
  }

  Widget _buildHandle(ColorScheme colorScheme) {
    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        // The slider semantics above step the width instead.
        excludeFromSemantics: true,
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        child: Container(
          width: widget.dragAreaWidth,
          color: Colors.transparent,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background divider line - show only during interaction
              if (_isDragging || _isHovered)
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    width: _isDragging ? 4.0 : (_isHovered ? 3.0 : 1.0),
                    decoration: BoxDecoration(
                      color: _isDragging
                          ? colorScheme.primary
                          : (_isHovered
                                ? colorScheme.onSurface.withValues(alpha: 0.3)
                                : colorScheme.onSurface.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              // Modern drag handle
              if (widget.showHandle)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: _isDragging ? 12.0 : 10.0,
                  height: _isDragging ? 52.0 : 48.0,
                  decoration: BoxDecoration(
                    // Le systeme est plat : la poignee se detache par sa
                    // couleur d'accent, pas par une ombre portee.
                    color: context.frostyColors.live,
                    borderRadius: BorderRadius.circular(
                      FrostyTokens.radiusCard,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 2,
                      height: _isDragging ? 20.0 : 16.0,
                      decoration: BoxDecoration(
                        color: colorScheme.onPrimary,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
