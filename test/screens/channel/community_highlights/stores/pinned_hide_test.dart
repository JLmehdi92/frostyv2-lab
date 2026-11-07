import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/community_highlight_event.dart';
import 'package:onset/models/community_highlights.dart';
import 'package:onset/screens/channel/community_highlights/highlight_stack.dart';
import 'package:onset/screens/channel/community_highlights/pinned_notice.dart';
import 'package:onset/screens/channel/community_highlights/stores/community_highlights_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

import '../../../../helpers/community_highlights_harness.dart';

void main() {
  late Harness h;
  late SettingsStore settings;

  setUp(() {
    h = Harness();
    settings = SettingsStore.fromJson({});
  });

  void run(void Function(FakeAsync async) body) =>
      fakeAsync(body, initialTime: harnessNow);

  CommunityHighlightsStore create() => h.create(
    isPinHidden: settings.hiddenPinnedChatIds.contains,
    onHidePin: settings.hidePinnedChat,
  );

  test('a pinned message hidden for me stays hidden, in a new session', () {
    run((async) {
      create();
      async.flushMicrotasks();
      h.send(HighlightTopic.pinned, pinPayload('a'));
      expect(h.store.current?.kind, HighlightKind.pinned);
      h.store.dismissCurrent();
      expect(h.store.current, isNull);
      expect(settings.hiddenPinnedChatIds, ['a']);
      h.store.dispose();

      final restored = SettingsStore.fromJson(settings.toJson());
      expect(restored.hiddenPinnedChatIds, ['a']);
      h.create(
        isPinHidden: restored.hiddenPinnedChatIds.contains,
        onHidePin: restored.hidePinnedChat,
      );
      async.flushMicrotasks();
      h.send(HighlightTopic.pinned, pinPayload('a'));
      expect(h.store.pinned?.id, 'a');
      expect(h.store.current, isNull);

      h.send(HighlightTopic.pinned, pinPayload('b'));
      expect(h.store.current?.id, 'b');
      h.store.dispose();
    });
  });

  test('hiding a poll is for this session only', () {
    run((async) {
      create();
      async.flushMicrotasks();
      h.send(HighlightTopic.polls, pollPayload('POLL_CREATE'));
      h.store.dismissCurrent();
      expect(settings.hiddenPinnedChatIds, isEmpty);
      h.store.dispose();
    });
  });

  test('a new pin is announced once, a hidden one never', () {
    run((async) {
      settings.hidePinnedChat('hidden');
      create();
      final pins = <String>[];
      h.store.newPins.listen((pin) => pins.add(pin.id));
      async.flushMicrotasks();
      h.send(HighlightTopic.pinned, pinPayload('a'));
      h.send(HighlightTopic.pinned, pinPayload('a'));
      h.send(HighlightTopic.pinned, pinPayload('hidden'));
      h.send(HighlightTopic.pinned, pinPayload('b'));
      async.flushMicrotasks();
      expect(pins, ['a', 'b']);
      h.store.dispose();
    });
  });

  test('the snapshot on opening is no new pin', () {
    run((async) {
      final pins = <String>[];
      when(
        () => h.service.getPinned(any()),
      ).thenAnswer((_) async => pinnedModel('old'));
      create();
      h.store.newPins.listen((pin) => pins.add(pin.id));
      async.flushMicrotasks();
      expect(h.store.pinned?.id, 'old');
      expect(pins, isEmpty);
      h.store.dispose();
    });
  });

  test('only the last 50 hidden pins are kept', () {
    for (var i = 0; i < 60; i++) {
      settings.hidePinnedChat('p$i');
    }
    settings.hidePinnedChat('p59');
    expect(settings.hiddenPinnedChatIds, hasLength(50));
    expect(settings.hiddenPinnedChatIds.first, 'p10');
    expect(settings.hiddenPinnedChatIds.last, 'p59');
  });

  test('the chat line names who pinned when Twitch says', () {
    final l = L10n.english;
    const by = PinnedChatMessage(
      id: 'a',
      senderLogin: 'fan',
      senderDisplayName: 'Fan',
      text: 'Rules',
      fragments: [],
      badges: [],
      pinnedBy: 'Mira',
    );
    expect(pinnedNotice(by, l), 'Mira pinned a message.');
    expect(pinnedNotice(pinnedModel('b'), l), 'A message was pinned.');
  });
}
