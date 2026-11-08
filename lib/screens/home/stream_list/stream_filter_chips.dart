import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/home/stream_list/stores/stream_list_store.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/screens/settings/widgets/stream_language_setting.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/stream_languages.dart';
import 'package:onset/widgets/onset_chip.dart';

class StreamFilterChips extends StatelessWidget {
  const StreamFilterChips({
    super.key,
    required this.store,
    this.showTags = true,
  });

  final ListStore store;
  final bool showTags;

  void _pickLanguage(BuildContext context) {
    final l = context.l10n;
    showSettingsSheet<void>(
      context: context,
      builder: (sheet) => StreamLanguageList(
        selected: store.languageFilter,
        followSetting: (
          label: l.streamFilterFollowSetting(
            language: streamLanguageName(
              streamLanguageOrAll(store.settingsStore.streamLanguage),
              l,
            ),
          ),
          onTap: () {
            store.languageFilter = null;
            Navigator.of(sheet).pop();
          },
        ),
        onSelected: (code) {
          store.languageFilter = code;
          Navigator.of(sheet).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = FeedColors.of(context);
    return Observer(
      builder: (context) {
        final language = store.languageFilter;
        final tags = showTags ? store.topTags : const <String>[];
        final tag = store.tagFilter;
        return Semantics(
          container: true,
          label: l.streamFilterLabel,
          explicitChildNodes: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(
              16 + MediaQuery.paddingOf(context).left,
              4,
              16 + MediaQuery.paddingOf(context).right,
              4,
            ),
            child: Row(
              spacing: 8,
              children: [
                OnsetChip(
                  key: const ValueKey('stream-filter-language'),
                  label: language == null
                      ? l.streamFilterLanguage
                      : streamLanguageName(language, l),
                  selected: language != null,
                  height: OnsetChip.filterHeight,
                  onSelected: () => _pickLanguage(context),
                ),
                if (tags.isNotEmpty)
                  Container(
                    width: OnsetTokens.hairlineWidth,
                    height: 20,
                    color: colors.pillBorder,
                  ),
                for (final name in tags)
                  OnsetChip(
                    label: name,
                    selected: name == tag,
                    height: OnsetChip.filterHeight,
                    onSelected: () =>
                        store.tagFilter = name == tag ? null : name,
                  ),
                if (store.isFiltered)
                  OnsetChip(
                    key: const ValueKey('stream-filter-clear'),
                    label: l.streamFilterClear,
                    selected: false,
                    height: OnsetChip.filterHeight,
                    onSelected: store.clearFilters,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
