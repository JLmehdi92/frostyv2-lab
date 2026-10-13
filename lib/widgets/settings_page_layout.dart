import 'package:flutter/material.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/frosty_scrollbar.dart';
import 'package:frosty/widgets/readable_width.dart';

/// A reusable layout for settings pages that handles common functionality:
/// - Orientation detection
/// - Responsive padding calculations
/// - ScrollController management
class SettingsPageLayout extends StatefulWidget {
  final List<Widget> children;
  final bool hasBottomPadding;
  final EdgeInsetsGeometry? additionalPadding;
  final RefreshCallback? onRefresh;

  const SettingsPageLayout({
    super.key,
    required this.children,
    this.hasBottomPadding = true,
    this.additionalPadding,
    this.onRefresh,
  });

  @override
  State<SettingsPageLayout> createState() => _SettingsPageLayoutState();
}

class _SettingsPageLayoutState extends State<SettingsPageLayout> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait = context.isPortrait;

    // Responsive values based on orientation
    final listPadding = EdgeInsets.only(
      top: isPortrait ? 116 : 92,
      bottom: widget.hasBottomPadding ? context.safePaddingBottom + 8 : 0,
    );

    final borderTop = isPortrait ? 108 : 84;

    final largeScreen = context.isLargeScreen;

    final content = Stack(
      children: [
        FrostyScrollbar(
          controller: _scrollController,
          padding: EdgeInsets.only(top: borderTop.toDouble()),
          // The list keeps the full width (it scrolls from the side gutters);
          // on a large screen its tiles sit in a centred readable column.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final inset = largeScreen
                  ? readableInset(constraints.maxWidth)
                  : 0.0;
              final padding = listPadding.add(
                EdgeInsets.symmetric(horizontal: inset),
              );
              return ListView(
                controller: _scrollController,
                padding: widget.additionalPadding != null
                    ? widget.additionalPadding!.add(padding)
                    : padding,
                children: widget.children,
              );
            },
          ),
        ),
      ],
    );

    // Conditionally wrap with RefreshIndicator if onRefresh is provided
    if (widget.onRefresh != null) {
      return RefreshIndicator.adaptive(
        onRefresh: widget.onRefresh!,
        child: content,
      );
    }

    return content;
  }
}
