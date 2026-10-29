/// The kinds of community highlight above chat. A gift bomb is the banner
/// Twitch pins for a mass gift of five subs or more; an incoming raid, the
/// short pin of a channel raiding this one.
enum HighlightKind { poll, prediction, pinned, raid, giftBomb, incomingRaid }

extension HighlightKindLife on HighlightKind {
  /// Up for seconds: takes the slot at once, never arrives expanded, and
  /// shows even under the hype train's details.
  bool get shortLived =>
      this == HighlightKind.giftBomb || this == HighlightKind.incomingRaid;
}

/// One highlight in the stack (its data lives in the store, by kind).
class HighlightItem {
  const HighlightItem({
    required this.kind,
    required this.id,
    this.sticky = false,
    this.expanded = false,
  });

  final HighlightKind kind;
  final String id;

  /// Known before the screen opened (an existing pinned message): it goes
  /// to the end instead of taking the viewer's attention.
  final bool sticky;
  final bool expanded;

  HighlightItem copyWith({bool? expanded}) => HighlightItem(
    kind: kind,
    id: id,
    sticky: sticky,
    expanded: expanded ?? this.expanded,
  );
}

/// Which highlights are up, and which one shows: Twitch web's recency
/// stack (no fixed priority). Immutable; every change returns a new stack.
///
/// - The same id updates in place and keeps its expanded state.
/// - One highlight per kind: a new id replaces that kind.
/// - A sticky one is appended at the end.
/// - Otherwise the new one takes the visible slot, unless the visible one is
///   expanded: then it waits right behind it as [unseen]. A gift bomb banner
///   or an incoming raid is short-lived and always takes the slot, as
///   Twitch pins it on top.
class HighlightStack {
  const HighlightStack({
    this.items = const [],
    this.currentIndex = 0,
    this.unseenKey,
    this.dismissed = const {},
  });

  final List<HighlightItem> items;
  final int currentIndex;

  /// `kind:id` of the highlight that arrived behind the expanded one and
  /// was not looked at yet (shown as a "new" pill).
  final String? unseenKey;

  /// The highlight waiting behind the shown one, unseen.
  HighlightItem? get unseen {
    final key = unseenKey;
    if (key == null) return null;
    final index = items.indexWhere((i) => _key(i.kind, i.id) == key);
    return index == -1 || index == currentIndex ? null : items[index];
  }

  bool get unseenBehind => unseen != null;

  /// `kind:id` the viewer closed for this session.
  final Set<String> dismissed;

  HighlightItem? get current =>
      items.isEmpty ? null : items[currentIndex.clamp(0, items.length - 1)];

  static String _key(HighlightKind kind, String id) => '${kind.name}:$id';

  HighlightStack _copy({
    List<HighlightItem>? items,
    int? currentIndex,
    String? unseenKey,
    Set<String>? dismissed,
  }) {
    final list = items ?? this.items;
    final index = (currentIndex ?? this.currentIndex).clamp(
      0,
      list.isEmpty ? 0 : list.length - 1,
    );
    // Seen once it shows, and gone with its highlight.
    var unseen = unseenKey ?? this.unseenKey;
    if (unseen != null) {
      final at = list.indexWhere((i) => _key(i.kind, i.id) == unseen);
      if (at == -1 || at == index) unseen = null;
    }
    return HighlightStack(
      items: list,
      currentIndex: index,
      unseenKey: unseen,
      dismissed: dismissed ?? this.dismissed,
    );
  }

  /// Adds or updates [item] (see the class rules).
  HighlightStack upsert(HighlightItem item) {
    if (dismissed.contains(_key(item.kind, item.id))) return this;
    final sameKind = items.indexWhere((i) => i.kind == item.kind);
    if (sameKind != -1 && items[sameKind].id == item.id) {
      final updated = [...items];
      updated[sameKind] = item.copyWith(expanded: items[sameKind].expanded);
      return _copy(items: updated);
    }
    // A new id of a kind replaces it: drop the old one first.
    var stack = sameKind == -1 ? this : remove(item.kind);
    final list = [...stack.items];
    if (item.sticky || list.isEmpty) {
      list.add(item);
      return stack._copy(
        items: list,
        currentIndex: stack.items.isEmpty ? 0 : stack.currentIndex,
      );
    }
    final current = stack.current;
    if (current != null && current.expanded && !item.kind.shortLived) {
      list.insert(stack.currentIndex + 1, item);
      return stack._copy(items: list, unseenKey: _key(item.kind, item.id));
    }
    list.insert(stack.currentIndex, item);
    stack = stack._copy(items: list);
    return stack;
  }

  /// Removes the highlight of [kind].
  HighlightStack remove(HighlightKind kind) {
    final index = items.indexWhere((i) => i.kind == kind);
    if (index == -1) return this;
    final list = [...items]..removeAt(index);
    final shown = index < currentIndex ? currentIndex - 1 : currentIndex;
    return _copy(items: list, currentIndex: shown);
  }

  /// Hides the highlight [kind]/[id] for the session.
  HighlightStack dismiss(HighlightKind kind, String id) {
    final stack = items.any((i) => i.kind == kind && i.id == id)
        ? remove(kind)
        : this;
    return stack._copy(dismissed: {...dismissed, _key(kind, id)});
  }

  /// Shows the highlight at [index] (clamped); seeing the one behind clears
  /// the "new" pill.
  HighlightStack select(int index) {
    if (items.isEmpty) return this;
    final shown = index.clamp(0, items.length - 1);
    return _copy(currentIndex: shown);
  }

  /// Expands or collapses the visible highlight.
  HighlightStack toggleExpanded() {
    final current = this.current;
    if (current == null) return this;
    final list = [...items];
    list[currentIndex] = current.copyWith(expanded: !current.expanded);
    return _copy(items: list);
  }
}
