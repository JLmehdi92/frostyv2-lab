import 'package:flutter/material.dart';
import 'package:frosty/screens/whispers/whisper_kit.dart';
import 'package:frosty/stores/whisper_store.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:frosty/widgets/state_glyph.dart';

/// A whisper received elsewhere in the app (boards Etats 06 and
/// EtatsTablette): a floating card with the sender's picture and its
/// whisper mark, their name and the whisper on two lines at most, and
/// "Open". It leaves by itself, like any snack bar (not while accessible
/// navigation is on: "Open" is its action).
SnackBar whisperNotice(
  BuildContext context,
  IncomingWhisper whisper, {
  required VoidCallback onOpen,
}) {
  final colors = WhisperColors.of(context);
  final large = context.isLargeScreen;
  final accent = context.frostyColors.live;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final fill = dark ? colors.raised : FrostyTokens.surfaceLight;
  final avatar = large ? 38.0 : 34.0;
  final name = whisperPreview(whisper.fromName);
  final text = whisperPreview(whisper.whisper.text);
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: fill,
    elevation: 10,
    width: large ? 480 : null,
    margin: large ? null : const EdgeInsets.fromLTRB(10, 0, 10, 8),
    padding: EdgeInsets.fromLTRB(large ? 14 : 12, 10, 8, 10),
    // An action keeps the notice up while accessible navigation is on.
    action: SnackBarAction(label: 'Open', textColor: accent, onPressed: onOpen),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(large ? 18 : 16),
      side: BorderSide(
        color: dark
            ? FrostyTokens.hairlineStrongDark.withValues(alpha: 0.14)
            : FrostyTokens.hairlineLight,
        width: FrostyTokens.hairlineWidth,
      ),
    ),
    content: Row(
      children: [
        ExcludeSemantics(
          child: SizedBox.square(
            dimension: avatar + 3,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ProfilePicture(
                  userLogin: whisper.fromLogin,
                  radius: avatar / 2,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: large ? 19 : 18,
                    height: large ? 19 : 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: dark
                          ? FrostyTokens.textPrimaryDark
                          : FrostyTokens.backgroundDark,
                      shape: BoxShape.circle,
                      border: Border.all(color: fill, width: 2),
                    ),
                    child: StateGlyph(
                      StateGlyphKind.whisper,
                      color: dark
                          ? FrostyTokens.backgroundDark
                          : FrostyTokens.textPrimaryDark,
                      size: 10,
                      strokeWidth: 2.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: large ? 12 : 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$name ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
                TextSpan(text: text),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, height: 1.4, color: colors.body),
          ),
        ),
      ],
    ),
  );
}
