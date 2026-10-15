import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/community_highlights/highlight_stack.dart';

HighlightItem item(HighlightKind kind, String id, {bool sticky = false}) =>
    HighlightItem(kind: kind, id: id, sticky: sticky);

void main() {
  const empty = HighlightStack();

  test('a new highlight becomes the one shown', () {
    final stack = empty
        .upsert(item(HighlightKind.pinned, 'pin'))
        .upsert(item(HighlightKind.poll, 'p'));

    expect(stack.current!.kind, HighlightKind.poll);
    expect(stack.items, hasLength(2));
  });

  test('the same id updates in place and keeps its expanded state', () {
    final stack = empty
        .upsert(item(HighlightKind.poll, 'p'))
        .toggleExpanded()
        .upsert(item(HighlightKind.pinned, 'pin', sticky: true))
        .upsert(item(HighlightKind.poll, 'p'));

    expect(stack.items.first.kind, HighlightKind.poll);
    expect(stack.items.first.expanded, isTrue);
    expect(stack.items, hasLength(2));
  });

  test('a new id of a kind replaces that kind and is shown', () {
    final stack = empty
        .upsert(item(HighlightKind.poll, 'old'))
        .upsert(item(HighlightKind.pinned, 'pin'))
        .upsert(item(HighlightKind.poll, 'new'));

    expect(
      stack.items.where((i) => i.kind == HighlightKind.poll),
      hasLength(1),
    );
    expect(stack.current!.id, 'new');
  });

  test('sticky (initial pinned) goes to the end without taking focus', () {
    final stack = empty
        .upsert(item(HighlightKind.poll, 'p'))
        .upsert(item(HighlightKind.pinned, 'pin', sticky: true));

    expect(stack.current!.kind, HighlightKind.poll);
    expect(stack.items.last.kind, HighlightKind.pinned);
  });

  test('an expanded card is not pushed away: the new one waits behind', () {
    final stack = empty
        .upsert(item(HighlightKind.poll, 'p'))
        .toggleExpanded()
        .upsert(item(HighlightKind.prediction, 'e'));

    expect(stack.current!.kind, HighlightKind.poll);
    expect(stack.items[1].kind, HighlightKind.prediction);
    expect(stack.unseenBehind, isTrue);

    final seen = stack.select(1);
    expect(seen.current!.kind, HighlightKind.prediction);
    expect(seen.unseenBehind, isFalse);
  });

  test('the "new" pill names the unseen one, and only until it shows', () {
    // Poll expanded, prediction behind it, poll collapsed, then a raid.
    var stack = empty
        .upsert(item(HighlightKind.poll, 'p'))
        .toggleExpanded()
        .upsert(item(HighlightKind.prediction, 'e'))
        .toggleExpanded()
        .upsert(item(HighlightKind.raid, 'r'));

    expect(stack.current!.kind, HighlightKind.raid);
    expect(stack.unseen?.kind, HighlightKind.prediction);

    // Going back to the poll keeps it; showing the prediction clears it.
    stack = stack.select(1);
    expect(stack.unseen?.kind, HighlightKind.prediction);
    stack = stack.select(stack.items.indexOf(stack.unseen!));
    expect(stack.unseen, isNull);
    expect(stack.select(0).unseen, isNull);

    // Gone with its highlight.
    final removed = empty
        .upsert(item(HighlightKind.poll, 'p'))
        .toggleExpanded()
        .upsert(item(HighlightKind.prediction, 'e'))
        .remove(HighlightKind.prediction);
    expect(removed.unseen, isNull);
  });

  test('a collapsed pinned card never blocks a new one', () {
    final stack = empty
        .upsert(item(HighlightKind.pinned, 'pin'))
        .upsert(item(HighlightKind.raid, 'r'));
    expect(stack.current!.kind, HighlightKind.raid);
  });

  test('removing the current one keeps a valid selection', () {
    final stack = empty
        .upsert(item(HighlightKind.pinned, 'pin'))
        .upsert(item(HighlightKind.poll, 'p'))
        .select(1)
        .remove(HighlightKind.pinned);
    expect(stack.current!.kind, HighlightKind.poll);
    expect(stack.remove(HighlightKind.poll).current, isNull);
    expect(stack.select(9).currentIndex, 0);
  });

  test('a dismissed id stays hidden; a new id of that kind shows', () {
    final stack = empty
        .upsert(item(HighlightKind.poll, 'p'))
        .dismiss(HighlightKind.poll, 'p')
        .upsert(item(HighlightKind.poll, 'p'));
    expect(stack.items, isEmpty);
    expect(stack.upsert(item(HighlightKind.poll, 'q')).current!.id, 'q');
  });

  test('a gift bomb banner takes the slot and leaves on its own', () {
    final stack = const HighlightStack()
        .upsert(item(HighlightKind.pinned, 'pin', sticky: true))
        .upsert(item(HighlightKind.giftBomb, 'bomb'));
    expect(stack.current!.kind, HighlightKind.giftBomb);

    final after = stack.remove(HighlightKind.giftBomb);
    expect(after.current!.kind, HighlightKind.pinned);
  });
}
