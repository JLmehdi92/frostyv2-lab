import 'package:flutter/material.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

/// The official app's "Message Blocked" sheet, shown when the viewer taps
/// a word their chat filters hid. Pops true for "Show Message".
class FilteredMessageSheet extends StatelessWidget {
  const FilteredMessageSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Message Blocked',
                    style: SheetText.title.copyWith(color: colors.text),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                style: IconButton.styleFrom(
                  fixedSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                ),
                icon: SheetGlyph(
                  SheetGlyphKind.close,
                  strokeWidth: 2,
                  color: colors.secondary,
                ),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 4, bottom: 16),
            child: Text(
              'Would you like to see this message? It has been hidden for '
              'you based on your NSFW Chat Filter settings.',
              style: SheetText.body.copyWith(color: colors.body),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SheetButton(
              label: 'Show Message',
              large: true,
              expand: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ),
        ],
      ),
    );
  }
}
