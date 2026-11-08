import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/mod_tools/stores/mod_tools_store.dart';
import 'package:onset/screens/onboarding/login_webview.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:provider/provider.dart';

class ModSheetTitle extends StatelessWidget {
  const ModSheetTitle(this.title, {super.key, this.caption});

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: SheetText.title.copyWith(color: colors.text),
            ),
          ),
          if (caption case final caption?)
            Text(
              caption,
              style: SheetText.status.copyWith(color: colors.secondary),
            ),
        ],
      ),
    );
  }
}

class ModSheetBody extends StatelessWidget {
  const ModSheetBody({super.key, required this.children});

  final List<Widget> children;

  static const maxHeightFactor = 0.85;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
    ),
    child: ListView(
      primary: false,
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 12),
      children: children,
    ),
  );
}

class ModNote extends StatelessWidget {
  const ModNote(this.text, {super.key, this.padding, this.strong = false});

  final String text;
  final EdgeInsetsGeometry? padding;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        text,
        style: strong
            ? SheetText.subtitle.copyWith(color: colors.text)
            : SheetText.body.copyWith(color: colors.secondary),
      ),
    );
  }
}

class ModHairline extends StatelessWidget {
  const ModHairline({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: OnsetTokens.hairlineWidth,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    color: SheetColors.of(context).hairline,
  );
}

class ModCompactButton extends StatelessWidget {
  const ModCompactButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.danger = false,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool danger;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final accent = SheetColors.accentOf(context);
    final foreground = danger
        ? colors.danger
        : primary
        ? accent
        : colors.text;
    return OutlinedButton(
      onPressed: onPressed == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onPressed!();
            },
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        minimumSize: const Size(44, 36),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: const StadiumBorder(),
        side: BorderSide(
          color: danger
              ? colors.danger.withValues(alpha: 0.5)
              : primary
              ? accent.withValues(alpha: 0.55)
              : colors.ringStrong,
        ),
        textStyle: SheetText.pill,
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}

class ModItemTile extends StatelessWidget {
  const ModItemTile({
    super.key,
    required this.title,
    this.subtitle,
    this.body,
    this.actions = const [],
    this.leading,
  });

  final String title;
  final String? subtitle;
  final String? body;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          leading ?? InitialAvatar(name: title, size: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(title, style: SheetText.row.copyWith(color: colors.text)),
                if (subtitle case final subtitle?)
                  Text(
                    subtitle,
                    style: SheetText.rowDetail.copyWith(
                      color: colors.secondary,
                    ),
                  ),
                if (body case final body?)
                  Text(
                    body,
                    style: SheetText.body.copyWith(color: colors.body),
                  ),
                if (actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(spacing: 8, runSpacing: 6, children: actions),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ModAddField extends StatefulWidget {
  const ModAddField({
    super.key,
    required this.label,
    required this.actionLabel,
    required this.onSubmit,
    this.maxLength,
    this.enabled = true,
  });

  final String label;
  final String actionLabel;
  final Future<bool> Function(String text) onSubmit;
  final int? maxLength;
  final bool enabled;

  @override
  State<ModAddField> createState() => _ModAddFieldState();
}

class _ModAddFieldState extends State<ModAddField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (await widget.onSubmit(text) && mounted) _controller.clear();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 10,
      children: [
        Expanded(
          child: SheetTextField(
            controller: _controller,
            label: widget.label,
            maxLength: widget.maxLength,
          ),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => SheetButton(
            label: widget.actionLabel,
            onPressed: widget.enabled && _controller.text.trim().isNotEmpty
                ? _submit
                : null,
          ),
        ),
      ],
    ),
  );
}

Future<bool> confirmModAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => OnsetDialog(
      title: title,
      message: message,
      actions: [
        SheetButton(
          label: context.l10n.commonCancel,
          tone: SheetButtonTone.text,
          onPressed: () => Navigator.pop(context, false),
        ),
        SheetButton(
          label: confirmLabel,
          tone: danger ? SheetButtonTone.danger : SheetButtonTone.primary,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<void> openModLogin(
  BuildContext context,
  AuthStore authStore,
  Set<String> scopes,
) async {
  final navigator = Navigator.of(context);
  await authStore.requestScopes(scopes);
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (context) => Provider<AuthStore>.value(
        value: authStore,
        child: const LoginWebView(),
      ),
    ),
  );
}

mixin ModActionState<T extends StatefulWidget> on State<T> {
  var busy = false;
  String? statusMessage;
  var statusOk = true;

  Future<bool> runModAction(
    Future<void> Function() action, {
    required String command,
    String? success,
  }) async {
    if (busy) return false;
    setState(() {
      busy = true;
      statusMessage = null;
    });
    String? failure;
    try {
      await action();
    } catch (error) {
      debugPrint('Mod tools $command failed: $error');
      failure = modToolsFailure(error, command);
    }
    if (!mounted) return failure == null;
    setState(() {
      busy = false;
      statusOk = failure == null;
      statusMessage = failure ?? success;
    });
    return failure == null;
  }

  Widget statusLine() => SheetStatusLine(
    busy: busy,
    message: statusMessage,
    ok: statusOk,
    minHeight: 26,
    padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
  );
}
