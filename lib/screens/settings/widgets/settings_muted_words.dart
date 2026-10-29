import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/theme.dart';

/// "Muted keywords": how many there are; a tap opens the list (board
/// Parametres: the field, the words, "Undo" after a removal).
class SettingsMutedWords extends StatelessWidget {
  final SettingsStore settingsStore;
  const SettingsMutedWords({super.key, required this.settingsStore});

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
            builder: (context) => MutedWordsSheet(settingsStore: settingsStore),
          ),
        );
      },
    );
  }
}

/// The muted keywords' list: the field (kept above the keyboard), the
/// words, "Undo" after a removal. It owns its field, so it outlives the
/// page that opened it (a fold that swaps the tablet's pane for the
/// phone's profile while it is open).
class MutedWordsSheet extends StatefulWidget {
  const MutedWordsSheet({super.key, required this.settingsStore});

  final SettingsStore settingsStore;

  @override
  State<MutedWordsSheet> createState() => _MutedWordsSheetState();
}

class _MutedWordsSheetState extends State<MutedWordsSheet> {
  late final SettingsStore settingsStore = widget.settingsStore;
  final TextEditingController textController = TextEditingController();
  final FocusNode textFieldFocusNode = FocusNode();

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
  void dispose() {
    textController.dispose();
    textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Its own messenger: "Undo" shows on the sheet, not under it.
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // The sheet already stands above the keyboard.
        resizeToAvoidBottomInset: false,
        body: Builder(builder: _content),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final colors = SettingsColors.of(context);
    final accent = SettingsColors.accentOf(context);
    return SettingsSheetContent(
      title: 'Muted keywords',
      pinned: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Padding(
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
                      width: OnsetTokens.hairlineWidth,
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
                          fontFamily: OnsetTokens.bodyFamily,
                          fontSize: 15,
                          color: colors.text,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter keywords to mute',
                          hintStyle: TextStyle(
                            fontFamily: OnsetTokens.bodyFamily,
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
      ),
      slivers: [
        Observer(
          builder: (context) {
            final words = settingsStore.mutedWords;
            if (words.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                          fontFamily: OnsetTokens.bodyFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.body,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              sliver: SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.stackIdle,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.cardRing,
                      width: OnsetTokens.hairlineWidth,
                    ),
                  ),
                  child: Column(
                    children: [
                      for (final (index, word) in words.indexed) ...[
                        if (index > 0)
                          Divider(
                            height: OnsetTokens.hairlineWidth,
                            thickness: OnsetTokens.hairlineWidth,
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
                                    fontFamily: OnsetTokens.bodyFamily,
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
              ),
            );
          },
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
}
