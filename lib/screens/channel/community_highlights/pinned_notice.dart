import 'package:onset/l10n/app_localizations.dart';
import 'package:onset/models/community_highlights.dart';

String pinnedNotice(PinnedChatMessage pin, AppLocalizations l) =>
    switch (pin.pinnedBy?.trim()) {
      final by? when by.isNotEmpty => l.chatPinnedBy(name: by),
      _ => l.chatPinnedNew,
    };
