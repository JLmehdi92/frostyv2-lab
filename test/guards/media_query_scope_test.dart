import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every read of the whole [MediaQueryData] in the app, with why it needs
/// all of it.
///
/// `MediaQuery.of` makes its caller depend on every field, and the software
/// keyboard changes the view insets on every frame it slides in: a screen
/// that only wanted its orientation, size or padding was rebuilt each frame
/// of it (the channel screen and its chat, and Home under it, stuttered as
/// the keyboard opened). Read one aspect instead (`MediaQuery.sizeOf`,
/// `paddingOf`, `orientationOf`, `viewInsetsOf`…), or isolate the read in
/// a small widget that takes the rest of the subtree as a child.
const _allowed = <String, (int, String)>{
  'lib/screens/channel/chat/chat.dart': (
    1,
    "_MessageTextScale re-provides the screen's metrics with the chat's "
        'text scale; it is a leaf holding the messages as its child',
  ),
  'lib/screens/home/home.dart': (
    2,
    "_ScreenMedia and _ShellPageMedia re-provide the screen's metrics to "
        'the shell and its pages, built apart and passed in as children',
  ),
  'lib/screens/home/top/browse_page.dart': (
    1,
    "the tablet's category pane re-provides the metrics as its own window",
  ),
  'lib/screens/channel/chat/widgets/reply_thread.dart': (
    1,
    'a sheet re-providing the metrics with a text scale',
  ),
  'lib/screens/channel/chat/widgets/chat_user_modal.dart': (
    1,
    'a sheet re-providing the metrics with a text scale',
  ),
  'lib/screens/vod/widgets/vod_chat_replay.dart': (
    1,
    'the replayed chat re-provides the metrics with its text scale',
  ),
  'lib/screens/settings/widgets/settings_page.dart': (
    2,
    'the page re-provides the metrics under its header; its sheet sizes '
        'itself on the keyboard (it needs the insets and the size together)',
  ),
  'lib/widgets/sheet/onset_panel.dart': (
    1,
    'an anchored panel keeps clear of the keyboard and closes when the '
        'screen changes size (insets and size together)',
  ),
};

void main() {
  test('the whole MediaQuery is read only where it is needed', () {
    final found = <String, int>{};
    final pattern = RegExp(r'MediaQuery\s*\.\s*(of|maybeOf)\s*\(');
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
    for (final file in files) {
      final code = file
          .readAsLinesSync()
          .map((line) {
            final comment = line.indexOf('//');
            return comment == -1 ? line : line.substring(0, comment);
          })
          .join('\n');
      final count = pattern.allMatches(code).length;
      if (count > 0) found[file.path.replaceAll(r'\', '/')] = count;
    }
    // The scan saw something: an empty result would pass anything.
    expect(found, isNotEmpty);
    expect(
      found,
      {for (final e in _allowed.entries) e.key: e.value.$1},
      reason:
          'A new MediaQuery.of rebuilds its caller on every keyboard frame: '
          'read one aspect, or add it here with the reason it needs all.',
    );
  });
}
