import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
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
  String _status() {
    if (authStore.webSessionExpired) {
      return 'Twitch session expired — log in again to restore 2K';
    }
    return authStore.twitchWebToken == null
        ? 'Not set — log in to pick it up automatically'
        : 'Active — picked up automatically, 2K requested';
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final colors = SettingsColors.of(context);
        final set = authStore.twitchWebToken != null;
        return SettingsRow(
          title: 'Twitch web token (2K)',
          subtitle: Text(_status()),
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
                    set ? '••••••' : 'Not set',
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

    return SettingsDialog(
      title: 'Twitch web token (2K)',
      message:
          'Some streams only offer their 2K (1440p HEVC) quality to a '
          'signed-in viewer. This is normally picked up on its own when you '
          'log in, and refreshed on each launch — you should never need to '
          'touch it. Fill it in by hand only if that fails: paste the value '
          'of the "auth-token" cookie from twitch.tv in a browser.',
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
                    isSet ? 'A token is set.' : 'No token set.',
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
                    child: const Text('Clear'),
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
              labelText: isSet ? 'New auth-token' : 'auth-token',
              hintText: 'Paste to replace — never shown',
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
          label: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        SettingsButton(
          label: isSet ? 'Replace' : 'Save',
          tone: SettingsButtonTone.primary,
          onPressed: canSave ? () => _save(_controller.text) : null,
        ),
      ],
    );
  }
}
