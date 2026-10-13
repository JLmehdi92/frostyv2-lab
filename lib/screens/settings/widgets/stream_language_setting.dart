import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';
import 'package:frosty/utils/stream_languages.dart';

/// Picks the language Top and category lists are filtered by.
class StreamLanguageSetting extends StatelessWidget {
  final SettingsStore settingsStore;

  const StreamLanguageSetting({super.key, required this.settingsStore});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final selected = streamLanguageOrAll(settingsStore.streamLanguage);

        return ListTile(
          title: const Text('Stream language'),
          subtitle: Text(kStreamLanguages[selected]!),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showModalBottomSheetWithProperFocus(
            context: context,
            isScrollControlled: true,
            builder: (context) => _LanguageSheet(
              selected: selected,
              onSelected: (code) {
                settingsStore.streamLanguage = code;
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
    );
  }
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final MapEntry(key: code, value: name)
                in kStreamLanguages.entries)
              ListTile(
                title: Text(name),
                selected: code == selected,
                trailing: code == selected
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => onSelected(code),
              ),
          ],
        ),
      ),
    );
  }
}
