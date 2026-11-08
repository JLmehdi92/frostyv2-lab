class VodChapter {
  const VodChapter({
    required this.start,
    required this.length,
    required this.title,
    this.gameId,
    this.boxArtUrl,
  });

  final Duration start;
  final Duration length;
  final String title;
  final String? gameId;
  final String? boxArtUrl;

  Duration get end => start + length;

  static VodChapter? tryParse(Object? node) {
    if (node is! Map) return null;
    final position = node['positionMilliseconds'];
    final duration = node['durationMilliseconds'];
    if (position is! num || duration is! num || position < 0) return null;
    final details = node['details'];
    final game = details is Map ? details['game'] : null;
    final gameName = game is Map ? game['displayName'] : null;
    final description = node['description'];
    final title = switch ((gameName, description)) {
      (final String name, _) when name.trim().isNotEmpty => name.trim(),
      (_, final String text) when text.trim().isNotEmpty => text.trim(),
      _ => null,
    };
    if (title == null) return null;
    final gameId = game is Map ? game['id'] : null;
    final boxArt = game is Map ? game['boxArtURL'] : null;
    return VodChapter(
      start: Duration(milliseconds: position.toInt()),
      length: Duration(milliseconds: duration < 0 ? 0 : duration.toInt()),
      title: title,
      gameId: gameId is String && gameId.isNotEmpty ? gameId : null,
      boxArtUrl: boxArt is String && boxArt.startsWith('https://')
          ? boxArt
          : null,
    );
  }
}

List<VodChapter> sortedChapters(Iterable<VodChapter> chapters) =>
    [...chapters]..sort((a, b) => a.start.compareTo(b.start));

VodChapter? chapterAt(List<VodChapter> chapters, Duration at) {
  VodChapter? current;
  for (final chapter in chapters) {
    if (chapter.start > at) break;
    current = chapter;
  }
  return current;
}
