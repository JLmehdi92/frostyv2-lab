import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/user_notice_presentation.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';

String chatBubbleEventLabel(ChatBubbleEvent event, AppLocalizations l) =>
    switch (event) {
      ChatBubbleEvent.subs => l.chatBubblesSubs,
      ChatBubbleEvent.gifts => l.chatBubblesGifts,
      ChatBubbleEvent.raids => l.chatBubblesRaids,
      ChatBubbleEvent.announcements => l.chatBubblesAnnouncements,
      ChatBubbleEvent.other => l.chatBubblesOther,
    };

class ChatBubblesSetting extends StatelessWidget {
  const ChatBubblesSetting({super.key, required this.settingsStore});

  final SettingsStore settingsStore;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Observer(
      builder: (context) {
        final count = settingsStore.chatBubbleEvents.length;
        return SettingsRow(
          key: const ValueKey('chat-bubbles'),
          title: l.chatBubblesTitle,
          subtitle: Text(l.chatBubblesDetail),
          value: count == 0
              ? l.chatBubblesOff
              : l.chatBubblesCount(count: count),
          end: SettingsRowEnd.chevron,
          onTap: () => showSettingsSheet<void>(
            context: context,
            builder: (context) =>
                ChatBubblesSheet(settingsStore: settingsStore),
          ),
        );
      },
    );
  }
}

class ChatBubblesSheet extends StatelessWidget {
  const ChatBubblesSheet({super.key, required this.settingsStore});

  final SettingsStore settingsStore;

  void _toggle(ChatBubbleEvent event, bool on) {
    final current = settingsStore.chatBubbleEvents;
    settingsStore.chatBubbleEvents = [
      for (final e in ChatBubbleEvent.values)
        if (e == event ? on : current.contains(e.name)) e.name,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SettingsSheetContent(
      title: l.chatBubblesTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 20),
          sliver: SliverToBoxAdapter(
            child: Observer(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final event in ChatBubbleEvent.values)
                    SettingsListSwitch(
                      title: chatBubbleEventLabel(event, l),
                      value: settingsStore.chatBubbleEvents.contains(
                        event.name,
                      ),
                      onChanged: (on) => _toggle(event, on),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
