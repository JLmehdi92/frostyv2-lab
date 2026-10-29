import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/widgets/settings_glyph.dart';
import 'package:frosty/screens/settings/widgets/settings_kit.dart';
import 'package:frosty/screens/settings/widgets/settings_page.dart';
import 'package:frosty/theme.dart';

/// "Muted keywords": how many there are; a tap opens the list (board
/// Parametres: the field, the words, "Undo" after a removal).
class SettingsMutedWords extends StatefulWidget {
  final SettingsStore settingsStore;
  const SettingsMutedWords({super.key, required this.settingsStore});

  @override
  State<SettingsMutedWords> createState() => _SettingsMutedWordsState();
}

class _SettingsMutedWordsState extends State<SettingsMutedWords> {
  late final SettingsStore settingsStore;
  final TextEditingController textController = TextEditingController();
  final FocusNode textFieldFocusNode = FocusNode();

  @override
  void initState() {
    settingsStore = widget.settingsStore;
    super.initState();
  }

  void addMutedWord(String text) {
    // An empty keyword would mute nothing useful: the field just closes.
    if (text.trim().isEmpty) {
      textController.clear();
      textFieldFocusNode.unfocus();
      return;
    }
    settingsStore.mutedWords = [...settingsStore.mutedWords, text];

    textController.clear();
    textFieldFocusNode.unfocus();
  }

  void removeMutedWord(int index) {
    settingsStore.mutedWords = [...settingsStore.mutedWords..removeAt(index)];
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final count = settingsStore.mutedWords.length;
        return SettingsRow(
          glyph: SettingsGlyphKind.mute,
          title: 'Muted keywords',
          value: switch (count) {
            0 => 'None',
            1 => '1 keyword',
            _ => '$count keywords',
          },
          end: SettingsRowEnd.chevron,
          onTap: () => showSettingsSheet<void>(
            context: context,
            title: 'Muted keywords',
            // Its own messenger: "Undo" shows on the sheet, not under it.
            builder: (context) => SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: ScaffoldMessenger(
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Builder(builder: _list),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _list(BuildContext context) {
    final colors = SettingsColors.of(context);
    final accent = SettingsColors.accentOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: ListenableBuilder(
            listenable: textController,
            builder: (context, _) {
              final empty = textController.text.isEmpty;
              return Container(
                height: 48,
                padding: const EdgeInsets.only(left: 16, right: 4),
                decoration: ShapeDecoration(
                  color: colors.well,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: colors.buttonRing,
                      width: FrostyTokens.hairlineWidth,
                    ),
                  ),
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: textController,
                        focusNode: textFieldFocusNode,
                        onSubmitted: addMutedWord,
                        autocorrect: false,
                        cursorColor: accent,
                        style: TextStyle(
                          fontFamily: FrostyTokens.bodyFamily,
                          fontSize: 15,
                          color: colors.text,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter keywords to mute',
                          hintStyle: TextStyle(
                            fontFamily: FrostyTokens.bodyFamily,
                            fontSize: 15,
                            color: colors.tertiary,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: empty ? 'Cancel' : 'Add keyword',
                      child: Semantics(
                        button: true,
                        label: empty ? 'Cancel' : 'Add keyword',
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: () {
                            if (textController.text.isEmpty) {
                              textFieldFocusNode.unfocus();
                            } else {
                              addMutedWord(textController.text);
                            }
                          },
                          child: AnimatedContainer(
                            duration: settingsMotion(context, 160),
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: empty ? colors.tile : accent,
                            ),
                            child: SettingsGlyph(
                              SettingsGlyphKind.check,
                              strokeWidth: 2.4,
                              color: empty
                                  ? colors.secondary
                                  : SettingsColors.onAccentOf(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Expanded(
          child: Observer(
            builder: (context) {
              final words = settingsStore.mutedWords;
              if (words.isEmpty) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 10,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.tile,
                        shape: BoxShape.circle,
                      ),
                      child: SettingsGlyph(
                        SettingsGlyphKind.mute,
                        size: 22,
                        color: colors.secondary,
                      ),
                    ),
                    Text(
                      'No muted keywords',
                      style: TextStyle(
                        fontFamily: FrostyTokens.bodyFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.body,
                      ),
                    ),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: colors.stackIdle,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.cardRing,
                        width: FrostyTokens.hairlineWidth,
                      ),
                    ),
                    child: Column(
                      children: [
                        for (final (index, word) in words.indexed) ...[
                          if (index > 0)
                            Divider(
                              height: FrostyTokens.hairlineWidth,
                              thickness: FrostyTokens.hairlineWidth,
                              color: colors.hairline,
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    word,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: FrostyTokens.bodyFamily,
                                      fontSize: 15,
                                      color: colors.text,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove $word',
                                  constraints: const BoxConstraints.tightFor(
                                    width: 44,
                                    height: 44,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: SettingsGlyph(
                                    SettingsGlyphKind.trash,
                                    color: colors.secondary,
                                  ),
                                  onPressed: () => _remove(context, index),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _remove(BuildContext context, int index) {
    final word = settingsStore.mutedWords.elementAt(index);
    removeMutedWord(index);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Removed '$word'"),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            settingsStore.mutedWords = [...settingsStore.mutedWords, word];
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    textController.dispose();
    textFieldFocusNode.dispose();
    super.dispose();
  }
}
