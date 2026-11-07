import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/utils/punycode.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

typedef ExternalLinkChoice = ({bool dontAskAgain});

Future<ExternalLinkChoice?> showExternalLinkDialog(
  BuildContext context,
  Uri url,
) => showDialog<ExternalLinkChoice>(
  context: context,
  builder: (context) => ExternalLinkDialog(url: url),
);

class ExternalLinkDialog extends StatefulWidget {
  const ExternalLinkDialog({super.key, required this.url});

  final Uri url;

  @override
  State<ExternalLinkDialog> createState() => _ExternalLinkDialogState();
}

class _ExternalLinkDialogState extends State<ExternalLinkDialog> {
  var _dontAskAgain = false;

  void _toggle(bool value) => setState(() => _dontAskAgain = value);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    final host = asciiHost(widget.url.host);
    final shown = widget.url.replace(host: host).toString();
    final body = SheetText.body.copyWith(color: colors.body);
    return OnsetDialog(
      title: l.linkConfirmTitle,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text.rich(
            TextSpan(
              children: l10nSpans(l.linkConfirmBody(host: l10nMark(0)), [
                TextSpan(
                  text: host,
                  style: body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ]),
            ),
            style: body,
          ),
          Text(
            shown,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SheetText.rowDetail.copyWith(color: colors.secondary),
          ),
          MergeSemantics(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                HapticFeedback.selectionClick();
                _toggle(!_dontAskAgain);
              },
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Text(
                      l.linkConfirmDontAsk,
                      style: SheetText.row.copyWith(color: colors.text),
                    ),
                  ),
                  OnsetSwitch(value: _dontAskAgain, onChanged: _toggle),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        SheetButton(
          label: l.commonCancel,
          tone: SheetButtonTone.text,
          onPressed: () => Navigator.pop(context),
        ),
        SheetButton(
          label: l.linkConfirmOpen,
          onPressed: () =>
              Navigator.pop(context, (dontAskAgain: _dontAskAgain)),
        ),
      ],
    );
  }
}

Future<bool> confirmExternalLink(
  BuildContext? context,
  Uri url, {
  required bool ask,
  required VoidCallback stopAsking,
}) async {
  if (!ask || context == null || !context.mounted) return true;
  final choice = await showExternalLinkDialog(context, url);
  if (choice == null) return false;
  if (choice.dontAskAgain) stopAsking();
  return true;
}
