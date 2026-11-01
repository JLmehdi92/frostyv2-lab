/// The ratchet of no_hardcoded_strings_test: how many hard-coded UI strings
/// each file of `lib/` still has, before its texts move to the ARB files.
///
/// Counts may only go down, and must match exactly: the guard fails when a
/// file has more (or a new file has any), and when it has fewer until its
/// count here is lowered. The map is empty once every text is translated.
const l10nBaseline = <String, int>{};
