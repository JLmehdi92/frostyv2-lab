import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

Future<Duration?> showGoToTimeDialog(
  BuildContext context, {
  required Duration position,
  required Duration length,
}) => showDialog<Duration>(
  context: context,
  builder: (context) => GoToTimeDialog(position: position, length: length),
);

class GoToTimeDialog extends StatefulWidget {
  const GoToTimeDialog({
    super.key,
    required this.position,
    required this.length,
  });

  final Duration position;
  final Duration length;

  @override
  State<GoToTimeDialog> createState() => _GoToTimeDialogState();
}

class _GoToTimeDialogState extends State<GoToTimeDialog> {
  final _field = TextEditingController();

  Duration? get _target {
    final parsed = parseGoToTime(_field.text);
    if (parsed == null || parsed > widget.length) return null;
    return parsed;
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _go() {
    final target = _target;
    if (target != null) Navigator.pop(context, target);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    final target = _target;
    final invalid = _field.text.trim().isNotEmpty && target == null;
    return OnsetDialog(
      title: l.vodGoToTime,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          SheetTextField(
            controller: _field,
            autofocus: true,
            maxLength: 12,
            hint: formatVodTime(widget.position),
            keyboardType: TextInputType.datetime,
            onChanged: (_) => setState(() {}),
          ),
          if (invalid)
            Text(
              l.vodGoToTimeInvalid(end: formatVodTime(widget.length)),
              style: SheetText.rowDetail.copyWith(color: colors.danger),
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
          label: l.vodGoToTimeGo,
          onPressed: target == null ? null : _go,
        ),
      ],
    );
  }
}
