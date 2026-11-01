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

/// Every read of the view's insets straight from `View.of`, which registers
/// no dependency on them: a widget reading the keyboard that way is not
/// rebuilt when it comes or goes, unless it listens itself.
const _viewInsetsAllowed = <String, String>{
  'lib/screens/channel/channel_top_overlays.dart':
      'the fallback of an overlay drawn without its ChannelKeyboardScope',
  'lib/screens/channel/channel_info.dart':
      '_HiddenWhileTyping listens to the metrics itself '
      '(WidgetsBindingObserver.didChangeMetrics)',
};

/// [source] without its comments; string literals are kept whole, so a
/// `//` in a URL is not taken for a comment.
String stripComments(String source) {
  final out = StringBuffer();
  var i = 0;
  bool at(String token) => source.startsWith(token, i);
  while (i < source.length) {
    if (at('//')) {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
    } else if (at('/*')) {
      var depth = 0;
      do {
        if (at('/*')) {
          depth++;
          i += 2;
        } else if (at('*/')) {
          depth--;
          i += 2;
        } else {
          i++;
        }
      } while (depth > 0 && i < source.length);
    } else if (at("'") || at('"')) {
      final raw = i > 0 && source[i - 1] == 'r';
      final quote = at("'''") || at('"""')
          ? source.substring(i, i + 3)
          : source[i];
      out.write(quote);
      i += quote.length;
      while (i < source.length && !at(quote)) {
        if (!raw && at(r'\')) {
          out.write(source.substring(i, i + 2));
          i += 2;
        } else {
          out.write(source[i++]);
        }
      }
      if (i < source.length) {
        out.write(quote);
        i += quote.length;
      }
    } else {
      out.write(source[i++]);
    }
  }
  return out.toString();
}

Map<String, int> _count(RegExp pattern) {
  final found = <String, int>{};
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
  for (final file in files) {
    final count = pattern
        .allMatches(stripComments(file.readAsStringSync()))
        .length;
    if (count > 0) found[file.path.replaceAll(r'\', '/')] = count;
  }
  return found;
}

final _wholeMediaQuery = RegExp(r'MediaQuery\s*\.\s*(of|maybeOf)\s*\(');

void main() {
  test('the comment stripping keeps code after a URL and drops comments', () {
    const source = '''
final url = 'https://example.com'; MediaQuery.of(context);
// MediaQuery.of(context) in a line comment
/* MediaQuery.of(context) in a block comment */
final raw = r'C:\\path'; MediaQuery.maybeOf(context);
final quoted = "it's // not a comment"; MediaQuery.of(context);
''';
    expect(_wholeMediaQuery.allMatches(stripComments(source)).length, 3);
  });

  test('the whole MediaQuery is read only where it is needed', () {
    final found = _count(_wholeMediaQuery);
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

  test("the view's insets are read with a dependency, or listened to", () {
    final found = _count(
      RegExp(r'View\s*\.\s*(of|maybeOf)\s*\([^;]*?\)[\s\S]{0,80}?viewInsets'),
    );
    expect(found, isNotEmpty);
    expect(
      found.keys.toSet(),
      _viewInsetsAllowed.keys.toSet(),
      reason:
          'View.of(context).viewInsets does not rebuild its reader when the '
          'keyboard comes or goes: read MediaQuery.viewInsetsOf, or add it '
          'here with how it follows the keyboard.',
    );
  });
}
