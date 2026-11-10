import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/apis/twitch_report_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/report.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:onset/widgets/twitch_web_page.dart';
import 'package:provider/provider.dart';

typedef ReportSender =
    Future<ViewerActionOutcome> Function(
      ReportReason reason,
      String description,
    );

Future<void> reportFromOnset(
  BuildContext context, {
  required ReportTarget target,
  required String title,
  Uri? fallbackUrl,
}) async {
  final send = _senderFor(context, target);
  if (send == null) {
    if (fallbackUrl == null) return;
    if (!await _confirmWebReport(context) || !context.mounted) return;
    await TwitchWebPage.open(context, title: title, url: fallbackUrl);
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l = context.l10n;
  final outcome = await showOnsetSheet<ViewerActionOutcome>(
    context: context,
    builder: (_) => ReportSheet(target: target, send: send),
  );
  if (outcome == null) return;
  if (outcome == ViewerActionOutcome.done) {
    unawaited(HapticFeedback.lightImpact());
  }
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          outcome == ViewerActionOutcome.done
              ? l.reportSent
              : l.viewerActionResult(status: outcome.name),
        ),
      ),
    );
}

ReportSender? _senderFor(BuildContext context, ReportTarget target) {
  final TwitchReportService? service;
  final AuthStore? auth;
  try {
    service = context.read<TwitchReportService?>();
    auth = context.read<AuthStore?>();
  } on ProviderNotFoundException {
    return null;
  }
  final token = auth?.twitchWebToken ?? '';
  if (service == null ||
      token.isEmpty ||
      !TwitchReportService.isReportable(target)) {
    return null;
  }
  final reporter = service;
  return (reason, description) => reporter.report(
    target: target,
    reason: reason,
    description: description,
    authToken: auth?.twitchWebToken ?? '',
  );
}

Future<bool> _confirmWebReport(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: kSheetScrim,
    builder: (context) => OnsetDialog(
      title: context.l10n.reportWebFallbackTitle,
      message: context.l10n.reportWebFallbackBody,
      actions: [
        SheetButton(
          label: context.l10n.commonCancel,
          tone: SheetButtonTone.text,
          onPressed: () => Navigator.pop(context, false),
        ),
        SheetButton(
          key: ReportSheet.webFallbackKey,
          label: context.l10n.reportOpenOnTwitchAction,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class ReportSheet extends StatefulWidget {
  const ReportSheet({super.key, required this.target, required this.send});

  final ReportTarget target;
  final ReportSender send;

  static const sendKey = ValueKey('report-send');
  static const webFallbackKey = ValueKey('report-web-fallback');
  static ValueKey<String> reasonKey(ReportReason reason) =>
      ValueKey('report-reason-${reason.name}');

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _details = TextEditingController();
  ReportReason? _reason;
  var _sending = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send(ReportReason reason) async {
    if (_sending) return;
    setState(() => _sending = true);
    final outcome = await widget.send(reason, _details.text);
    if (!mounted) return;
    Navigator.pop(context, outcome);
  }

  @override
  Widget build(BuildContext context) {
    final reason = _reason;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: reason == null
          ? _ReasonPicker(
              key: const ValueKey('reasons'),
              target: widget.target,
              onPick: (picked) => setState(() => _reason = picked),
            )
          : _Confirmation(
              key: const ValueKey('confirm'),
              target: widget.target,
              reason: reason,
              details: _details,
              sending: _sending,
              onBack: _sending ? null : () => setState(() => _reason = null),
              onSend: () => _send(reason),
            ),
    );
  }
}

class _ReasonPicker extends StatelessWidget {
  const _ReasonPicker({super.key, required this.target, required this.onPick});

  final ReportTarget target;
  final ValueChanged<ReportReason> onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
            child: Semantics(
              header: true,
              child: Text(
                l.reportTitle(kind: target.kind.name, name: target.name),
                style: SheetText.title.copyWith(color: colors.text),
              ),
            ),
          ),
          SheetSectionLabel(l.reportWhy),
          for (final reason in target.reasons)
            SheetRow(
              key: ReportSheet.reasonKey(reason),
              label: l.reportReason(reason: reason.name),
              end: SheetRowEnd.chevron,
              onTap: () => onPick(reason),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({
    super.key,
    required this.target,
    required this.reason,
    required this.details,
    required this.sending,
    required this.onBack,
    required this.onSend,
  });

  final ReportTarget target;
  final ReportReason reason;
  final TextEditingController details;
  final bool sending;
  final VoidCallback? onBack;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetBackHeader(
              title: l.reportConfirmTitle,
              onBack: onBack ?? () {},
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              child: Text(
                l.reportReason(reason: reason.name),
                style: SheetText.title.copyWith(color: colors.text),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: SheetGlyph(
                      SheetGlyphKind.flag,
                      size: 16,
                      color: colors.secondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      l.reportConfirmBody,
                      style: TextStyle(
                        fontFamily: OnsetTokens.bodyFamily,
                        fontSize: 13,
                        height: 1.45,
                        color: colors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SheetTextField(
                controller: details,
                label: l.reportDetailsLabel,
                hint: l.reportDetailsHint,
                maxLength: TwitchReportService.maxDescriptionLength,
                counter: true,
                maxLines: 3,
              ),
            ),
            SheetStatusLine(busy: sending),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: SheetButton(
                key: ReportSheet.sendKey,
                label: l.reportSend,
                large: true,
                expand: true,
                onPressed: sending ? null : onSend,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
