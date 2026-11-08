import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/mod_tools_sheet.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

class ShieldModeIndicator extends StatelessWidget {
  const ShieldModeIndicator({super.key, required this.chatStore});

  final ChatStore chatStore;

  @override
  Widget build(BuildContext context) => Observer(
    builder: (context) {
      final active = chatStore.shieldModeActive;
      return AnimatedSwitcher(
        duration: motionDuration(context, const Duration(milliseconds: 220)),
        child: active
            ? _ShieldPill(
                key: const ValueKey('shield'),
                onTap: () => showModTools(context, chatStore),
              )
            : const SizedBox.shrink(key: ValueKey('none')),
      );
    },
  );
}

class _ShieldPill extends StatelessWidget {
  const _ShieldPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final l = context.l10n;
    return Semantics(
      liveRegion: true,
      button: true,
      label: l.modToolsShieldModeOn,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: colors.dangerTint,
          shape: StadiumBorder(
            side: BorderSide(
              color: colors.danger.withValues(alpha: 0.5),
              width: OnsetTokens.hairlineWidth,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 5,
                  children: [
                    SheetGlyph(
                      SheetGlyphKind.shield,
                      size: 14,
                      strokeWidth: 2.2,
                      color: colors.danger,
                    ),
                    Text(
                      l.modToolsShieldModeOn,
                      style: SheetText.pill.copyWith(
                        fontSize: 12,
                        color: colors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
