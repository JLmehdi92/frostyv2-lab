import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

/// Lets the user store the twitch.tv web session token (the `auth-token`
/// cookie) that unlocks Twitch's enhanced-broadcast renditions.
///
/// Twitch only offers the 1440p HEVC / AV1 tracks of some streams to an
/// authenticated viewer, and its GQL endpoint rejects tokens minted for
/// the app's own client-id — so the web token is the only way to ask for them.
/// Leaving it empty keeps the previous anonymous behaviour.
class SettingsTwitchWebToken extends StatelessWidget {
  final AuthStore authStore;

  const SettingsTwitchWebToken({super.key, required this.authStore});

  Future<void> _edit(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierColor: kSheetScrim,
      builder: (context) => _WebTokenDialog(authStore: authStore),
    );
  }

  /// What the tile says about the token, in the three states that matter to
  /// the user rather than the three the code tracks.
  String _status(AppLocalizations l) {
    if (authStore.webSessionExpired) return l.webTokenExpired;
    return authStore.twitchWebToken == null
        ? l.webTokenUnset
        : l.webTokenActive;
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final colors = SettingsColors.of(context);
        final set = authStore.twitchWebToken != null;
        return SettingsRow(
          title: context.l10n.webTokenTitle,
          subtitle: Text(_status(context.l10n)),
          end: SettingsRowEnd.chevron,
          onTap: () => _edit(context),
          // Only whether one is set: the token itself is never drawn.
          trailing: ExcludeSemantics(
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: ShapeDecoration(
                color: colors.tile,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: colors.buttonRing,
                    width: OnsetTokens.hairlineWidth,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  SettingsGlyph(
                    SettingsGlyphKind.lock,
                    size: 13,
                    strokeWidth: 2.2,
                    color: colors.secondary,
                  ),
                  Text(
                    set ? '••••••' : context.l10n.webTokenNotSet,
                    style: TextStyle(
                      fontFamily: OnsetTokens.bodyFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.96,
                      color: colors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Replaces or clears the stored token without ever displaying it.
///
/// The token is a live twitch.tv session: shown in clear, it would be one
/// screenshot or screen share away from someone else's hands. So the field
/// starts empty and obscured, and the dialog only says whether one is set.
class _WebTokenDialog extends StatefulWidget {
  final AuthStore authStore;

  const _WebTokenDialog({required this.authStore});

  @override
  State<_WebTokenDialog> createState() => _WebTokenDialogState();
}

class _WebTokenDialogState extends State<_WebTokenDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String? token) async {
    await widget.authStore.setTwitchWebToken(token);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final accent = SettingsColors.accentOf(context);
    final isSet = widget.authStore.twitchWebToken != null;
    final canSave = _controller.text.trim().isNotEmpty;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );

    final l = context.l10n;
    return SettingsDialog(
      title: l.webTokenTitle,
      message: l.webTokenExplanation,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.only(left: 12, right: 4),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.trackRing,
                width: OnsetTokens.hairlineWidth,
              ),
            ),
            child: Row(
              spacing: 10,
              children: [
                SettingsGlyph(
                  SettingsGlyphKind.lock,
                  size: 16,
                  strokeWidth: 2,
                  color: colors.secondary,
                ),
                Expanded(
                  child: Text(
                    isSet ? l.webTokenIsSet : l.webTokenNoneSet,
                    style: TextStyle(
                      fontFamily: OnsetTokens.bodyFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                ),
                if (isSet)
                  TextButton(
                    onPressed: () => _save(null),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.danger,
                      minimumSize: const Size(0, 40),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontFamily: OnsetTokens.bodyFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(l.webTokenClear),
                  ),
              ],
            ),
          ),
          TextField(
            controller: _controller,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            cursorColor: accent,
            style: TextStyle(
              fontFamily: OnsetTokens.bodyFamily,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
              color: colors.text,
            ),
            decoration: InputDecoration(
              labelText: isSet ? l.webTokenNewField : _cookieName,
              hintText: l.webTokenFieldHint,
              // Lines rather than an ellipsis (a phone, large text; the
              // hint takes the wide letter spacing of the hidden token).
              hintMaxLines: 3,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              filled: true,
              fillColor: colors.well,
              border: border(colors.buttonRing),
              enabledBorder: border(colors.buttonRing),
              focusedBorder: border(accent.withValues(alpha: 0.7)),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        SettingsButton(
          label: l.commonCancel,
          onPressed: () => Navigator.pop(context),
        ),
        SettingsButton(
          label: isSet ? l.webTokenReplace : l.webTokenSave,
          tone: SettingsButtonTone.primary,
          onPressed: canSave ? () => _save(_controller.text) : null,
        ),
      ],
    );
  }
}

/// The cookie's name on twitch.tv: the field's label when no token is set,
/// the same in every language.
const _cookieName = 'auth-token';
