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
}
