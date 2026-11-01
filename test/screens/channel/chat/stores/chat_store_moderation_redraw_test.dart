import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

import '../../../../helpers/chat_store_harness.dart';

const _privmsg =
    '@badge-info=;badges=;color=#00FF00;display-name=Viewer;emotes=;'
    'id=msg-1;room-id=12345;tmi-sent-ts=1;user-id=55555 '
    ':viewer!viewer@viewer.tmi.twitch.tv PRIVMSG #channel :the answer';

const _clearmsg =
    '@login=viewer;room-id=12345;target-msg-id=msg-1;tmi-sent-ts=2 '
    ':tmi.twitch.tv CLEARMSG #channel :the answer';

const _timeout =
    '@ban-duration=600;room-id=12345;target-user-id=55555;tmi-sent-ts=3 '
    ':tmi.twitch.tv CLEARCHAT #channel :viewer';

/// Moderation marks a line in place (its command changes). The chat's list
/// redraws when what it observes, [ChatStore.renderMessages], reports a
/// change; a quiet chat has no new message to do it.
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  for (final (name, line, command) in [
    ('a deleted message', _clearmsg, Command.clearMessage),
    ('a timed-out user', _timeout, Command.clearChat),
  ]) {
    test('$name is redrawn in a quiet chat, without a new message', () {
      fakeAsync((async) {
        final settings = SettingsStore.fromJson({})
          ..showVideo = false
          ..autoSyncChatDelay = false
          ..chatDelay = 0;
        final sockets = <FakeSocket>[];
        final store = createTestChatStore(settings: settings, sockets: sockets);
        async.flushMicrotasks();
        final irc = sockets.single;
        irc.receive(_privmsg);
        async.flushMicrotasks();
        store.addMessages();

        // What the chat's list Observer reads: the list and its length.
        final seen = <Command>[];
        var first = true;
        final dispose = autorun((_) {
          final lines = store.renderMessages;
          final command = lines
              .lastWhere((m) => m.tags['id'] == 'msg-1')
              .command;
          if (first) {
            first = false;
            return;
          }
          seen.add(command);
        });

        irc.receive(line);
        async.flushMicrotasks();
        // No message arrives; the buffer's flush has nothing to add.
        store.addMessages();

        // Before: nothing reported, the line kept showing until the next
        // message.
        expect(seen, [command]);
        // The line itself is the one marked, kept in place.
        expect(
          store.messages.where((m) => m.tags['id'] == 'msg-1').single.command,
          command,
        );
        // Revealing a deleted message works on the same line as before.
        store.revealMessage('msg-1');
        expect(store.revealedMessageIds, contains('msg-1'));

        dispose();
        store.dispose();
        unawaited(irc.drop());
        async.elapse(const Duration(seconds: 30));
      });
    });
  }

  group('a ban wave', () {
    String line(int i) =>
        '@badge-info=;badges=;color=#00FF00;display-name=U$i;emotes=;'
        'id=m-$i;room-id=12345;tmi-sent-ts=$i;user-id=${10000 + i} '
        ':u$i!u$i@u$i.tmi.twitch.tv PRIVMSG #channel :hello $i';

    String timeout(String user) =>
        '@ban-duration=60;room-id=12345;target-user-id=1;tmi-sent-ts=9 '
        ':tmi.twitch.tv CLEARCHAT #channel :$user';

    /// A chat of 400 lines (u0 to u399), then [wave] played over [ticks]
    /// flushes of 200 ms; returns how many times the list reported a change.
    int redraws(List<String> wave, {int ticks = 1}) {
      var reports = 0;
      fakeAsync((async) {
        final settings = SettingsStore.fromJson({})
          ..showVideo = false
          ..autoSyncChatDelay = false
          ..chatDelay = 0
          ..showModerationNotices = false;
        final sockets = <FakeSocket>[];
        final store = createTestChatStore(settings: settings, sockets: sockets);
        async.flushMicrotasks();
        final irc = sockets.single;
        for (var i = 0; i < 400; i++) {
          irc.receive(line(i));
        }
        async.flushMicrotasks();
        store.addMessages();

        // What the chat's list Observer reads: the list and its length.
        var runs = 0;
        final dispose = autorun((_) {
          store.renderMessages.length;
          runs++;
        });
        final perTick = (wave.length / ticks).ceil();
        for (var tick = 0; tick < ticks; tick++) {
          for (final message in wave.skip(tick * perTick).take(perTick)) {
            irc.receive(message);
          }
          async.flushMicrotasks();
          store.addMessages();
        }

        reports = runs - 1;
        dispose();
        store.dispose();
        unawaited(irc.drop());
        async.elapse(const Duration(seconds: 30));
      });
      return reports;
    }

    test('of users with no line in the chat redraws nothing', () {
      // Before: one redraw per timeout, 200, each outside the 200 ms flush.
      expect(redraws([for (var i = 0; i < 200; i++) timeout('nobody_$i')]), 0);
    });

    test('of users in the chat redraws once per flush at most', () {
      final wave = [for (var i = 0; i < 200; i++) timeout('u$i')];
      // Before: 200 redraws.
      expect(redraws(wave), 1);
      expect(redraws(wave, ticks: 4), 4);
    });

    test('repeating a timeout already shown redraws nothing more', () {
      final wave = [for (var i = 0; i < 50; i++) timeout('u7')];
      expect(redraws(wave, ticks: 5), 1);
    });
  });
}
