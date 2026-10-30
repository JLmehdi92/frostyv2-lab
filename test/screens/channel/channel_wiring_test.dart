import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The channel screen's code without comments or white space, so the checks
/// below look at what it does, not at how it is written or explained. String
/// literals are kept as they are: a `//` in a URL is not a comment.
String _code(String source) => (_Stripper(source)..code()).out.toString();

class _Stripper {
  _Stripper(this.source);

  final String source;
  final out = StringBuffer();
  var i = 0;

  bool at(String token) => source.startsWith(token, i);

  /// Copies code without comments or white space, up to an unmatched
  /// [until].
  void code({String? until}) {
    var braces = 0;
    while (i < source.length) {
      if (until != null && braces == 0 && at(until)) return;
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
      } else if (at("'") || at('"') || _rawString()) {
        string();
      } else if (RegExp(r'\s').hasMatch(source[i])) {
        i++;
      } else {
        if (source[i] == '{') braces++;
        if (source[i] == '}') braces--;
        out.write(source[i++]);
      }
    }
  }

  /// `r'…'`, not the end of a word such as `bar'`.
  bool _rawString() =>
      (at("r'") || at('r"')) &&
      (i == 0 || !RegExp(r'[\w$]').hasMatch(source[i - 1]));

  /// Copies the string literal opened at [i] (quoted, raw, triple), its
  /// interpolations read as code.
  void string() {
    final raw = at('r');
    if (raw) out.write(source[i++]);
    final quote = at("'''") || at('"""')
        ? source.substring(i, i + 3)
        : source[i];
    out.write(quote);
    i += quote.length;
    while (i < source.length && !at(quote)) {
      if (!raw && at(r'\')) {
        out.write(source.substring(i, i + 2));
        i += 2;
      } else if (!raw && at(r'${')) {
        out.write(r'${');
        i += 2;
        code(until: '}');
        if (i < source.length) out.write(source[i++]);
      } else {
        out.write(source[i++]);
      }
    }
    out.write(quote);
    i += quote.length;
  }
}

/// The channel screen cannot be pumped in a test (live chat sockets, the
/// native player, some twenty services), so these guard how it is put
/// together; what each part does is tested with the part
/// (content_warning_gate_test, the player stores' tests).
void main() {
  test('comments go, strings stay as they are', () {
    expect(
      _code(
        "final url = 'https://twitch.tv'; // a link\n"
        '/* a /* nested */ note */ go(r"//raw", "\${a /* b */}", bar);',
      ),
      "finalurl='https://twitch.tv';go(r\"//raw\",\"\${a}\",bar);",
    );
    expect(_code("call('''it's // kept''')"), "call('''it's // kept''')");
  });

  final code = _code(
    File('lib/screens/channel/channel.dart').readAsStringSync(),
  );

  int count(String needle) => needle.allMatches(code).length;

  test('one content warning, keyed, around the video in every layout', () {
    expect(count('ContentWarningGate('), 1);
    expect(code, contains('ContentWarningGate(key:_contentGateKey,'));
    // Portrait and side chat, and full screen (a saved choice: a channel
    // can open straight into it).
    expect(code, contains('finalvideo=gated('));
    expect(code, contains('settingsStore.fullScreen?gated('));
    expect(code, contains('onStateChanged:_onContentGate,'));
  });

  test('the player, PiP and the mini player follow the warning', () {
    // A warning built again (chat only, then the video back) does not let
    // a covered stream go while it reads its labels again.
    expect(
      code,
      contains(
        '_contentGate=followContentGate(_contentGate,gate);'
        '_videoStore.setContentGate(_contentGate);',
      ),
    );
    expect(code, contains('onPipAction:(_)=>pipPlayPause(_videoStore),'));
    expect(
      code,
      contains(
        'void_minimizeToMiniPlayer(){if(!_contentGate.allowsLeaving)return;',
      ),
    );
    // A fallback engine starts where the warning stands.
    expect(code, contains('..setContentGate(_contentGate);'));
  });

  test('the video stats are drawn in every layout', () {
    expect(count('Positioned.fill(child:statsLayer)'), 1);
    expect(count('children:[chrome,statsLayer,]'), 2);
  });

  test("a tablet's panels know where the video is", () {
    // The picture itself, in every layout and in PiP, reports its place.
    expect(
      code,
      contains('finalplayer=PanelAvoidTarget(holder:_panelAvoid,child:'),
    );
    // Over every layout, so the user card, the points and the emote menu
    // keep it clear.
    expect(
      code,
      contains(
        'Positioned.fill(child:PanelAvoidScope(holder:_panelAvoid,'
        'child:videoChat),)',
      ),
    );
  });

  test("the double tap's side column is full screen beside the chat", () {
    // The double tap (and its screen-reader action) goes through the cycle,
    // which knows which side column it opened.
    expect(
      code,
      contains(
        'void_cycleLandscapeChatMode(){HapticFeedback.lightImpact();'
        '_chatCycle.next();}',
      ),
    );
    expect(count('_cycleLandscapeChatMode'), 3);
    // Read where the layout's Observer tracks it.
    expect(code, contains('finalplainSide=_chatCycle.plainSide;'));
    // A tablet's video column drops its info area there, on either side of
    // the chat, and keeps the same player (the column is the same widget).
    expect(count('_buildTabletVideoColumn(video,infoArea:!plainSide,)'), 2);
    expect(count('_buildTabletVideoColumn('), 3);
    // The tablet's chat column is the same in both.
    expect(
      code,
      contains('child:tablet?_buildTabletChat(chat,settingsStore,):chat,'),
    );
    // Portrait ends it; leaving the screen stops it.
    expect(code, contains('if(context.isPortrait)_chatCycle.reset();'));
    expect(code, contains('_chatCycle.dispose();'));
  });
}
