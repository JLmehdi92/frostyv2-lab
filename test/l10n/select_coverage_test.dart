import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/constants.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/badges.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/chat_restrictions.dart';
import 'package:onset/screens/channel/chat/moderation.dart';
import 'package:onset/screens/channel/chat/server_notice.dart';

/// An ICU `select` falls back to its `other` branch for a value it does not
/// name, silently: an empty text, or a vague one (« do that »). Each select
/// that can is listed here with the values the code passes it, and each
/// value must give its own words, in every language. A new select like
/// that fails the first test until it is listed.
void main() {
  final languages = [
    for (final locale in AppLocalizations.supportedLocales)
      lookupAppLocalizations(locale),
  ];

  // Every moderation action the chat names in its failures.
  final moderationCommands = <ModerationCommand>[
    const BanCommand('troll', ''),
    const TimeoutCommand('troll', Duration(minutes: 10), ''),
    const UnbanCommand('troll'),
    const UnbanCommand('troll', timeout: true),
    const WarnCommand('troll', 'be nice'),
    const DeleteMessageCommand('abc'),
    const ClearChatCommand(),
    for (final mode in ChatMode.values)
      for (final on in [true, false]) ChatModeCommand(mode, on: on),
  ];

  // Built-in rewards Twitch sends without a title.
  const automaticRewards = [
    'SEND_HIGHLIGHTED_MESSAGE',
    'RANDOM_SUB_EMOTE_UNLOCK',
    'CHOSEN_SUB_EMOTE_UNLOCK',
    'CHOSEN_MODIFIED_SUB_EMOTE_UNLOCK',
    'SINGLE_MESSAGE_BYPASS_SUB_MODE',
  ];

  final checks = <String, void Function(AppLocalizations l)>{
    'chatCommandDescription': (l) {
      for (final command in [...kChatCommands, ...kModeratorChatCommands]) {
        expect(command.description(l), isNotEmpty, reason: command.name);
      }
    },
    'chatModeName': (l) {
      for (final mode in ChatMode.values) {
        expect(mode.label(l), isNotEmpty, reason: mode.name);
      }
    },
    'chatModePill': (l) {
      for (final mode in ChatMode.values) {
        expect(mode.pill(l), isNotEmpty, reason: mode.name);
      }
    },
    'chatModeChanged': (l) {
      final fallback = l.chatModeChanged(mode: '?', state: OnOff.on.name);
      for (final mode in ChatMode.values) {
        for (final state in OnOff.values) {
          final text = l.chatModeChanged(mode: mode.name, state: state.name);
          expect(text, isNot(fallback), reason: '${mode.name} ${state.name}');
          expect(text, startsWith(mode.label(l)), reason: mode.name);
        }
      }
    },
    'chatModFailed': (l) {
      final fallback = l.chatModFailed(command: '?', reason: 'x');
      for (final command in moderationCommands) {
        final name = moderationCommand(command);
        expect(
          l.chatModFailed(command: name, reason: 'x'),
          isNot(fallback),
          reason: name,
        );
      }
    },
    'chatModFailedUnexpected': (l) {
      final fallback = l.chatModFailedUnexpected(command: '?');
      for (final command in moderationCommands) {
        final name = moderationCommand(command);
        expect(
          l.chatModFailedUnexpected(command: name),
          isNot(fallback),
          reason: name,
        );
      }
    },
    'chatColorName': (l) {
      for (final name in chatColorNames) {
        expect(l.chatColorName(color: name), isNotEmpty, reason: name);
      }
    },
    'pointsAutomaticReward': (l) {
      for (final type in automaticRewards) {
        final title = PointsReward.automaticRewardTitle(type, l);
        expect(title, isNotEmpty, reason: type);
        // Not the readable identifier an unknown type falls back to.
        expect(title, isNot(type.toLowerCase().replaceAll('_', ' ')));
      }
    },
    'emoteUnlockHint': (l) {
      for (final type in EmoteType.values) {
        final emote = Emote(
          name: 'Kappa',
          zeroWidth: false,
          url: 'https://cdn.example/kappa.png',
          type: type,
          ownerId: '1',
        );
        final hint = emote.unlockHint(l);
        if (hint != null) expect(hint, isNotEmpty, reason: type.name);
      }
    },
    'emoteTypeName': (l) {
      for (final type in EmoteType.values) {
        expect(type.label(l), isNotEmpty, reason: type.name);
      }
    },
    'chatServerNotice': (l) {
      for (final kind in kPlainServerNotices.values) {
        expect(l.chatServerNotice(notice: kind), isNotEmpty, reason: kind);
      }
    },
    'chatServerNoticeName': (l) {
      for (final kind in kNamedServerNotices.values) {
        expect(
          l.chatServerNoticeName(notice: kind, name: 'friend'),
          contains('friend'),
          reason: kind,
        );
      }
    },
    'chatRestrictionAccount': (l) {
      for (final kind in ChatRestrictionKind.values) {
        final restriction = ChatRestriction(kind, minutes: 10);
        expect(restriction.describe(null, l), isNotEmpty, reason: kind.name);
      }
    },
    'badgeTypeName': (l) {
      for (final type in BadgeType.values) {
        expect(type.label(l), isNotEmpty, reason: type.name);
      }
    },
  };

  test('every select that can fall back to an empty or vague text is '
      'checked here', () {
    final english =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, Object?>;
    final french =
        jsonDecode(File('lib/l10n/app_fr.arb').readAsStringSync())
            as Map<String, Object?>;
    final silent = {
      for (final MapEntry(:key, :value) in english.entries)
        if (!key.startsWith('@') &&
            value is String &&
            value.contains('select,') &&
            (value.contains('other{}') ||
                // A failure naming no action (« do that »).
                value.contains('other{do that}') ||
                (french[key]! as String).contains('other{}')))
          key,
    };
    expect(silent, unorderedEquals(checks.keys));
  });

  for (final MapEntry(:key, :value) in checks.entries) {
    test('$key: every value the code passes has its own words, in every '
        'language', () {
      for (final l in languages) {
        value(l);
      }
    });
  }
}
