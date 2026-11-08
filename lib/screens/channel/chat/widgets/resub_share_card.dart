import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/resub_notification.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

class ResubShareCard extends StatelessWidget {
  const ResubShareCard({super.key, required this.resub, this.onShare});

  final ResubNotification resub;
  final VoidCallback? onShare;

  static const shareKey = ValueKey('resub-share');

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SheetPresentation.isPanel(context)
            ? (dark ? const Color(0xFF202020) : colors.well)
            : colors.well,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.hairline,
          width: OnsetTokens.hairlineWidth,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Row(
              spacing: 8,
              children: [
                SheetGlyph(
                  SheetGlyphKind.cake,
                  strokeWidth: 1.9,
                  color: SheetColors.accentOf(context),
                ),
                Expanded(
                  child: Text(
                    l.resubShareTitle(months: resub.months),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: OnsetTokens.bodyFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              l.resubShareBody,
              style: TextStyle(
                fontFamily: OnsetTokens.bodyFamily,
                fontSize: 13,
                height: 1.35,
                color: colors.body,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                key: shareKey,
                onPressed: onShare,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: SheetColors.accentOf(context),
                  foregroundColor: SheetColors.onAccentOf(context),
                  shape: const StadiumBorder(),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(l.streakShareInChat),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResubShareDialog extends StatefulWidget {
  const ResubShareDialog({super.key});

  static const messageKey = ValueKey('resub-share-message');
  static const sendKey = ValueKey('resub-share-send');

  @override
  State<ResubShareDialog> createState() => _ResubShareDialogState();
}

class _ResubShareDialogState extends State<ResubShareDialog> {
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return OnsetDialog(
      title: l.resubShareDialogTitle,
      content: SheetTextField(
        key: ResubShareDialog.messageKey,
        controller: _message,
        hint: l.resubShareMessageHint,
        maxLength: TwitchViewerActionsService.maxResubMessageLength,
      ),
      actions: [
        SheetButton(
          label: l.commonCancel,
          tone: SheetButtonTone.text,
          onPressed: () => Navigator.pop(context),
        ),
        SheetButton(
          key: ResubShareDialog.sendKey,
          label: l.resubShareSend,
          onPressed: () => Navigator.pop(context, _message.text),
        ),
      ],
    );
  }
}
