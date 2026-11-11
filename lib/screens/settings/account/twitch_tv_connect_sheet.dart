import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/main.dart';
import 'package:onset/models/twitch_tv_session.dart';
import 'package:onset/screens/settings/stores/twitch_tv_session_store.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/twitch_web_page.dart';
import 'package:provider/provider.dart';

Future<bool> showTwitchTvConnectSheet(
  BuildContext context,
  TwitchTvSessionStore store,
) async {
  final connected = await showOnsetSheet<bool>(
    context: context,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => TwitchTvConnectSheet(store: store),
  );
  return connected == true;
}

SnackBarAction? twitchTvConnectSnackAction(BuildContext context) {
  final TwitchTvSessionStore? store;
  try {
    store = context.read<TwitchTvSessionStore?>();
  } on ProviderNotFoundException {
    return null;
  }
  final navigator =
      Navigator.maybeOf(context, rootNavigator: true) ??
      navigatorKey.currentState;
  if (store == null || navigator == null) return null;
  return SnackBarAction(
    label: context.l10n.twitchTvConnectAction,
    onPressed: () {
      if (navigator.mounted) {
        unawaited(showTwitchTvConnectSheet(navigator.context, store!));
      }
    },
  );
}

enum _Phase { requesting, waiting, finished }

class TwitchTvConnectSheet extends StatefulWidget {
  const TwitchTvConnectSheet({super.key, required this.store});

  static const codeKey = ValueKey('twitch-tv-code');
  static const openKey = ValueKey('twitch-tv-open');
  static const copyKey = ValueKey('twitch-tv-copy');
  static const newCodeKey = ValueKey('twitch-tv-new-code');
  static const doneKey = ValueKey('twitch-tv-done');

  final TwitchTvSessionStore store;

  @override
  State<TwitchTvConnectSheet> createState() => _TwitchTvConnectSheetState();
}

class _TwitchTvConnectSheetState extends State<TwitchTvConnectSheet> {
  var _phase = _Phase.requesting;
  TwitchTvDeviceCode? _code;
  TwitchTvConnectOutcome? _outcome;
  var _attempt = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _attempt++;
    super.dispose();
  }

  Future<void> _start() async {
    final attempt = ++_attempt;
    setState(() {
      _phase = _Phase.requesting;
      _code = null;
      _outcome = null;
    });
    final code = await widget.store.requestCode();
    if (!mounted || attempt != _attempt) return;
    if (code == null) {
      setState(() {
        _phase = _Phase.finished;
        _outcome = TwitchTvConnectOutcome.failed;
      });
      return;
    }
    setState(() {
      _phase = _Phase.waiting;
      _code = code;
    });
    final outcome = await widget.store.approve(
      code,
      isCancelled: () => !mounted || attempt != _attempt,
    );
    if (!mounted || attempt != _attempt) return;
    if (outcome == TwitchTvConnectOutcome.connected) {
      unawaited(HapticFeedback.lightImpact());
    }
    setState(() {
      _phase = _Phase.finished;
      _outcome = outcome;
    });
  }

  Future<void> _copy(String code) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final copied = context.l10n.twitchTvConnectCopied;
    await Clipboard.setData(ClipboardData(text: code));
    unawaited(HapticFeedback.selectionClick());
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(copied)));
  }

  void _openActivation(TwitchTvDeviceCode code) => unawaited(
    TwitchWebPage.open(
      context,
      title: context.l10n.twitchTvConnectTitle,
      url: code.activationUri,
    ),
  );

  bool get _connected => _outcome == TwitchTvConnectOutcome.connected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    final code = _code;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l.twitchTvConnectTitle,
              style: SheetText.title.copyWith(color: colors.text),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.twitchTvConnectBody,
            style: SheetText.body.copyWith(color: colors.secondary),
          ),
          const SizedBox(height: 18),
          _CodeCard(code: code?.userCode, dimmed: _phase == _Phase.finished),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: motionDuration(
              context,
              const Duration(milliseconds: 220),
            ),
            child: KeyedSubtree(
              key: ValueKey('${_phase.name}-${_outcome?.name}'),
              child: _status(context),
            ),
          ),
          const SizedBox(height: 12),
          ..._actions(context, code),
        ],
      ),
    );
  }

  Widget _status(BuildContext context) {
    final l = context.l10n;
    final outcome = _outcome;
    if (_phase == _Phase.finished && outcome != null) {
      return SheetStatusLine(
        busy: false,
        ok: _connected,
        okGlyphColor: OnsetTokens.accent,
        padding: EdgeInsets.zero,
        message: l.twitchTvConnectResult(status: outcome.name),
      );
    }
    final colors = SheetColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 30),
      child: Row(
        spacing: 10,
        children: [
          SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: SheetColors.accentOf(context),
            ),
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                _phase == _Phase.requesting
                    ? l.twitchTvConnectRequesting
                    : l.twitchTvConnectWaiting,
                style: SheetText.status.copyWith(color: colors.secondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, TwitchTvDeviceCode? code) {
    final l = context.l10n;
    if (_phase == _Phase.finished) {
      if (_connected) {
        return [
          SheetButton(
            key: TwitchTvConnectSheet.doneKey,
            label: l.commonDone,
            large: true,
            expand: true,
            onPressed: () => Navigator.pop(context, true),
          ),
        ];
      }
      return [
        SheetButton(
          key: TwitchTvConnectSheet.newCodeKey,
          label: l.twitchTvConnectNewCode,
          large: true,
          expand: true,
          onPressed: () => unawaited(_start()),
        ),
        const SizedBox(height: 8),
        SheetButton(
          label: l.commonCancel,
          tone: SheetButtonTone.text,
          expand: true,
          onPressed: () => Navigator.pop(context, false),
        ),
      ];
    }
    return [
      SheetButton(
        key: TwitchTvConnectSheet.openKey,
        label: l.twitchTvConnectOpen,
        large: true,
        expand: true,
        icon: const SettingsGlyph(SettingsGlyphKind.external),
        onPressed: code == null ? null : () => _openActivation(code),
      ),
      const SizedBox(height: 8),
      Row(
        spacing: 8,
        children: [
          Expanded(
            child: SheetButton(
              key: TwitchTvConnectSheet.copyKey,
              label: l.twitchTvConnectCopy,
              tone: SheetButtonTone.text,
              expand: true,
              onPressed: code == null
                  ? null
                  : () => unawaited(_copy(code.userCode)),
            ),
          ),
          Expanded(
            child: SheetButton(
              label: l.commonCancel,
              tone: SheetButtonTone.text,
              expand: true,
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
        ],
      ),
    ];
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.dimmed});

  final String? code;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    final code = this.code;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: colors.well,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        spacing: 8,
        children: [
          Text(
            l.twitchTvConnectCodeLabel.toUpperCase(),
            style: SheetText.section.copyWith(color: colors.tertiary),
          ),
          AnimatedOpacity(
            opacity: dimmed ? 0.4 : 1,
            duration: motionDuration(
              context,
              const Duration(milliseconds: 200),
            ),
            child: SizedBox(
              height: 44,
              child: Center(
                child: code == null
                    ? const SizedBox.shrink()
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SelectableText(
                          code,
                          key: TwitchTvConnectSheet.codeKey,
                          maxLines: 1,
                          style: SheetText.tabular(
                            TextStyle(
                              fontFamily: OnsetTokens.bodyFamily,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 6,
                              height: 1.1,
                              color: colors.text,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TwitchTvSessionGroup extends StatelessWidget {
  const TwitchTvSessionGroup({super.key, required this.store});

  static const rowKey = ValueKey('settings-twitch-tv-session');

  final TwitchTvSessionStore store;

  Future<void> _onTap(BuildContext context) async {
    if (store.status != TwitchTvSessionStatus.connected) {
      await showTwitchTvConnectSheet(context, store);
      return;
    }
    final l = context.l10n;
    final confirmed = await confirmSettingsAction(
      context,
      title: l.twitchTvDisconnectTitle,
      message: l.twitchTvDisconnectBody,
      confirm: l.twitchTvDisconnect,
    );
    if (confirmed) await store.forget();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Observer(
      builder: (context) {
        final status = store.status;
        return SettingsGroup(
          children: [
            SettingsRow(
              key: rowKey,
              glyph: SettingsGlyphKind.link,
              title: l.twitchTvSessionTitle,
              subtitle: Text(l.twitchTvSessionDetail),
              value: l.twitchTvSessionState(state: status.name),
              end: SettingsRowEnd.chevron,
              onTap: () => unawaited(_onTap(context)),
            ),
          ],
        );
      },
    );
  }
}
