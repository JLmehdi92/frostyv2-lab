import 'package:flutter/material.dart';
import 'package:onset/utils/context_extensions.dart';

class SectionHeader extends StatelessWidget {
  final String text;
  final EdgeInsets? padding;
  final double? fontSize;
  final bool isFirst;
  final double? topPadding;

  const SectionHeader(
    this.text, {
    super.key,
    this.padding,
    this.fontSize,
    this.isFirst = false,
    this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          padding ??
          EdgeInsets.fromLTRB(
            16 + MediaQuery.of(context).padding.left,
            0,
            16 + MediaQuery.of(context).padding.right,
            8,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFirst) ...[SizedBox(height: topPadding ?? 32)],
          Text(
            text.toUpperCase(),
            // Section headers share the wide-tracked monospace label used for
            // stream categories, so groups and metadata read as one voice.
            style: context.onsetText.label.copyWith(fontSize: fontSize),
          ),
        ],
      ),
    );
  }
}
