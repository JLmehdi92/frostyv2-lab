/// A notification id that stays the same for [key] across launches (a
/// 31-bit FNV-1a hash), never 0 or 1: the go-live summary and problem
/// notices use those.
int stableNoticeId(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  final id = hash & 0x7fffffff;
  return id <= 1 ? id + 2 : id;
}
