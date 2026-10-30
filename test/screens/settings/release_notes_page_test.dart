import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/release_notes.dart';
import 'package:onset/screens/settings/widgets/release_notes_parts.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/link_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

const _notes = '''
<!-- a note for writers -->

## v1.1.0

November 12, 2026

### New

- Go-live notifications for the channels you follow.
- **Tablet layout:** settings open in two panes, see `Settings › Video`.
  - In portrait, chat sits under the video.

### Improvements

- [Android] Updates are checked before they install.

### Fixes

- Fixed the mini player after a rotation.
- [iOS] Fixed captions staying on.
- Read [the docs](https://example.com/docs) or [this](javascript:alert(1)).

---

## v1.0.0

October 20, 2026

The first ONSET.

### New

- The low-latency player arrives.

### Housekeeping

- Older strings were tidied.
''';

const _phone = Size(390, 844);
const _landscape = Size(1280, 854);
const _portrait = Size(854, 1280);
const _sizes = [_phone, _landscape, _portrait];

void main() {
  tearDown(() => ReleaseNotes.debugSource = null);

  /// Opens the notes over a plain page (so closing them can be seen), at
  /// [size], in [mode], with [reduceMotion].
  Future<void> open(
    WidgetTester tester, {
    String? notes = _notes,
    Size size = _phone,
    ThemeMode mode = ThemeMode.dark,
    bool reduceMotion = false,
    String? updatedTo,
    String? updatedFrom,
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ReleaseNotes.debugSource = notes == null
        ? () async => throw StateError('no asset')
        : () async => notes;
    final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    await tester.pumpWidget(
      // A fresh app each time (a test may open the notes twice).
      KeyedSubtree(
        key: UniqueKey(),
        child: Provider<SettingsStore>.value(
          value: SettingsStore.fromJson({}),
          child: MaterialApp(
            theme: themes.light,
            darkTheme: themes.dark,
            themeMode: mode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(
                          name: ReleaseNotes.routeName,
                        ),
                        builder: (_) => ReleaseNotes(
                          updatedTo: updatedTo,
                          updatedFrom: updatedFrom,
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  /// Every text span of the page's paragraphs with [text], and its
  /// recognizer.
  List<TextSpan> spansWith(WidgetTester tester, String text) {
    final spans = <TextSpan>[];
    for (final element in find.byType(RichText).evaluate()) {
      (element.widget as RichText).text.visitChildren((span) {
        if (span is TextSpan && span.text == text) spans.add(span);
        return true;
      });
    }
    return spans;
  }

  group('every state fits every size, light and dark', () {
    for (final size in _sizes) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        final name = '${size.width.toInt()}×${size.height.toInt()} $mode';

        testWidgets('from settings, $name', (tester) async {
          await open(tester, size: size, mode: mode);
          expect(tester.takeException(), isNull);
          expect(find.text('v1.1.0'), findsWidgets);
          expect(find.text('ONSET 1.1.0'), findsOneWidget);
          expect(find.text('November 12, 2026'), findsWidgets);
          expect(find.text('2 new · 1 improvement · 3 fixes'), findsWidgets);
          expect(find.text('NEW'), findsOneWidget);
          expect(find.text('IMPROVEMENTS'), findsOneWidget);
          expect(find.text('FIXES'), findsOneWidget);
          expect(find.text('Android'), findsOneWidget);
          expect(find.text('iOS'), findsOneWidget);
          expect(find.text('Settings › Video'), findsOneWidget);
          expect(find.byTooltip('Back'), findsOneWidget);
          expect(find.text('No release notes yet'), findsNothing);
          expect(find.text('Got it'), findsNothing);
        });

        testWidgets('just updated, $name', (tester) async {
          await open(
            tester,
            size: size,
            mode: mode,
            updatedTo: '1.1.0',
            updatedFrom: '1.0.2',
          );
          expect(tester.takeException(), isNull);
          expect(find.text("WHAT'S NEW IN 1.1.0"), findsOneWidget);
          expect(find.text('Updated to 1.1.0'), findsOneWidget);
          expect(find.textContaining('You were on'), findsOneWidget);
          expect(find.textContaining('1.0.2'), findsOneWidget);
          expect(find.text('Got it'), findsOneWidget);
        });

        testWidgets('empty, $name', (tester) async {
          await open(tester, size: size, mode: mode, notes: '<!-- x -->\n');
          expect(tester.takeException(), isNull);
          expect(find.text('No release notes yet'), findsOneWidget);
          expect(find.byTooltip('Back'), findsOneWidget);
          expect(find.text('Got it'), findsNothing);
        });
      }
    }
  });

  testWidgets('a phone in landscape keeps the phone layout and fits', (
    tester,
  ) async {
    await open(
      tester,
      size: const Size(844, 390),
      updatedTo: '1.1.0',
      updatedFrom: '1.0.2',
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Got it'), findsOneWidget);
    expect(find.text('VERSIONS'), findsNothing);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('EARLIER VERSIONS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in _sizes) {
    testWidgets('the bundled 1.0.0 notes fit '
        '${size.width.toInt()}×${size.height.toInt()}', (tester) async {
      final bundled = File('assets/release-notes.md').readAsStringSync();
      await open(tester, size: size, notes: bundled);
      expect(tester.takeException(), isNull);
      expect(find.text('ONSET 1.0.0'), findsOneWidget);
      expect(find.text('5 new · 2 improvements · 1 fix'), findsWidgets);
      expect(find.text('EARLIER VERSIONS'), findsNothing);
      expect(find.text('Newer'), findsNothing);
      expect(find.text('Older'), findsNothing);
    });
  }

  testWidgets('the phone page starts under its header, not behind it', (
    tester,
  ) async {
    await open(tester);
    // The header is 56 dp (no status bar in a test view).
    expect(tester.getRect(find.text("WHAT'S NEW")).top, greaterThan(56));
    await open(tester, updatedTo: '1.1.0');
    expect(tester.getRect(find.byType(ReleaseFreshHero)).top, greaterThan(56));
  });

  testWidgets('every button can be pressed with a screen reader', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester, updatedTo: '1.1.0');
    expect(
      tester.getSemantics(find.bySemanticsLabel('Got it')),
      containsSemantics(isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('^v1.0.0'))),
      containsSemantics(isButton: true, hasTapAction: true),
    );
    await open(tester, size: _landscape);
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('^v1.0.0'))),
      containsSemantics(isButton: true, hasTapAction: true),
    );
    await tester.ensureVisible(find.text('Older'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('^Older'))),
      containsSemantics(isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  testWidgets('just updated: the card is the installed version\'s entry', (
    tester,
  ) async {
    // Notes already holding a newer entry than the build installed.
    await open(tester, updatedTo: '1.0.3', updatedFrom: '0.9.0');
    expect(find.text('ONSET 1.0.0'), findsOneWidget);
    expect(find.text('Latest'), findsNothing);
    expect(find.text('v1.1.0'), findsOneWidget);
    await open(
      tester,
      size: _landscape,
      updatedTo: '1.0.3',
      updatedFrom: '0.9.0',
    );
    expect(find.text('ONSET 1.0.0'), findsOneWidget);
  });

  testWidgets('two entries with the same version are still two', (
    tester,
  ) async {
    const twice = '## v1.0.0\n\n- First.\n\n## 1.0.0\n\n- Second.\n';
    await open(tester, notes: twice);
    await tester.tap(find.text('v1.0.0').last);
    await tester.pumpAndSettle();
    expect(find.text('First.'), findsOneWidget);
    expect(find.text('Second.'), findsOneWidget);
    await open(tester, size: _landscape, notes: twice);
    await tester.tap(find.text('v1.0.0').at(1));
    await tester.pumpAndSettle();
    expect(find.text('Second.'), findsOneWidget);
    expect(find.text('First.'), findsNothing);
  });

  testWidgets('tapping the version shown changes nothing', (tester) async {
    final long = [
      '## v1.1.0',
      '',
      '### New',
      '',
      for (var i = 0; i < 40; i++) '- Point number $i of a long version.',
      '',
      '## v1.0.0',
      '',
      '- One.',
    ].join('\n');
    await open(tester, size: _landscape, notes: long);
    final scrollable = find.byType(Scrollable).last;
    await tester.drag(scrollable, const Offset(0, -150));
    await tester.pumpAndSettle();
    final scrolled = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(scrolled, greaterThan(0));
    await tester.tap(find.text('v1.1.0').first);
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(scrollable).position.pixels, scrolled);
  });

  testWidgets('a preamble keeps its points and their tags', (tester) async {
    await open(
      tester,
      notes: '- [Android] Requires Android 8.\n\n## v1.0.0\n\n- One.\n',
    );
    expect(find.text('Android'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a platform tag hugs its name, the point follows it', (
    tester,
  ) async {
    await open(
      tester,
      notes: '- [Android] Requires Android 8.\n\n## v1.0.0\n\n- One.\n',
    );
    final tag = find
        .ancestor(of: find.text('Android'), matching: find.byType(Container))
        .first;
    final line = find.ancestor(
      of: find.text('Android'),
      matching: find.byType(RichText),
    );
    final tagBox = tester.getRect(tag);
    expect(tagBox.width, lessThan(150), reason: 'a tag, not a bar');
    // The point's text starts on the tag's line, right after it.
    final paragraph = tester.renderObject<RenderParagraph>(line.last);
    final firstWord = paragraph.getBoxesForSelection(
      TextSelection(
        baseOffset: paragraph.text.toPlainText().indexOf('Requires'),
        extentOffset: paragraph.text.toPlainText().indexOf('Requires') + 1,
      ),
    );
    expect(firstWord, isNotEmpty);
    final wordTop = paragraph.localToGlobal(Offset(0, firstWord.first.top)).dy;
    expect(wordTop, lessThan(tagBox.bottom));
  });

  testWidgets('unreadable notes show the empty state, never an error', (
    tester,
  ) async {
    await open(tester, notes: null);
    expect(tester.takeException(), isNull);
    expect(find.text('No release notes yet'), findsOneWidget);
  });

  testWidgets('just updated without the old version leaves it out', (
    tester,
  ) async {
    await open(tester, updatedTo: '1.1.0');
    expect(find.text('Updated to 1.1.0'), findsOneWidget);
    expect(find.textContaining('You were on'), findsNothing);
  });

  for (final size in [_phone, _landscape]) {
    testWidgets('Got it closes the page (${size.width.toInt()})', (
      tester,
    ) async {
      await open(tester, size: size, updatedTo: '1.1.0', updatedFrom: '1.0.2');
      expect(find.byType(ReleaseNotes), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.byType(ReleaseNotes), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  }

  testWidgets('back closes the page', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(ReleaseNotes), findsNothing);
  });

  group('earlier versions (phone)', () {
    testWidgets('expand and collapse', (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester);
      expect(find.text('EARLIER VERSIONS'), findsOneWidget);
      expect(find.text('v1.0.0'), findsOneWidget);
      expect(find.text('1 new · 1 change'), findsOneWidget);
      expect(find.text('The low-latency player arrives.'), findsNothing);

      await tester.ensureVisible(find.text('v1.0.0'));
      await tester.tap(find.text('v1.0.0'));
      // Mid-way through the 300 ms spring, the body is partly open.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('The low-latency player arrives.'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('The first ONSET.'), findsOneWidget);
      expect(find.text('HOUSEKEEPING'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('v1.0.0'))),
        containsSemantics(
          isExpanded: true,
          hasExpandedState: true,
          isButton: true,
        ),
      );

      await tester.tap(find.text('v1.0.0'));
      await tester.pumpAndSettle();
      expect(find.text('The low-latency player arrives.'), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('under reduce motion, the body opens at once', (tester) async {
      await open(tester, reduceMotion: true);
      await tester.ensureVisible(find.text('v1.0.0'));
      await tester.tap(find.text('v1.0.0'));
      await tester.pump();
      expect(find.text('The low-latency player arrives.'), findsOneWidget);
      // Fully open on the first frame: nothing is clipped away.
      final body = tester.getRect(find.text('HOUSEKEEPING'));
      expect(body.height, greaterThan(0));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('only one version: no earlier versions', (tester) async {
      await open(tester, notes: '## v1.0.0\n\nOctober 29, 2026\n\n- One.\n');
      expect(find.text('EARLIER VERSIONS'), findsNothing);
      expect(find.text('1 change'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the entrance plays once, then nothing moves', (tester) async {
    await open(tester, updatedTo: '1.1.0', settle: false);
    expect(find.text('Updated to 1.1.0'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduce motion: the page is in place after a short fade', (
    tester,
  ) async {
    await open(tester, reduceMotion: true, updatedTo: '1.1.0', settle: false);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('Got it'), findsOneWidget);
  });

  group('tablet', () {
    testWidgets('a version list and the chosen version\'s details', (
      tester,
    ) async {
      await open(tester, size: _landscape);
      expect(find.text('VERSIONS'), findsOneWidget);
      expect(find.text('LATEST'), findsOneWidget);
      expect(find.text('ONSET 1.1.0'), findsOneWidget);
      expect(find.text('Older'), findsOneWidget);
      expect(find.text('Newer'), findsNothing);

      // The version list comes first (the other is Older's label).
      await tester.tap(find.text('v1.0.0').first);
      await tester.pumpAndSettle();
      expect(find.text('ONSET 1.0.0'), findsOneWidget);
      expect(find.text('The first ONSET.'), findsOneWidget);
      expect(find.text('Newer'), findsOneWidget);
      expect(find.text('Older'), findsNothing);

      await tester.tap(find.text('Newer'));
      await tester.pumpAndSettle();
      expect(find.text('ONSET 1.1.0'), findsOneWidget);
      await tester.tap(find.text('Older'));
      await tester.pumpAndSettle();
      expect(find.text('ONSET 1.0.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the chosen version survives rotation and resizing', (
      tester,
    ) async {
      await open(tester, size: _landscape);
      await tester.tap(find.text('v1.0.0').first);
      await tester.pumpAndSettle();
      expect(find.text('ONSET 1.0.0'), findsOneWidget);

      tester.view.physicalSize = _portrait;
      await tester.pumpAndSettle();
      expect(find.text('ONSET 1.0.0'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // A phone-sized window (split screen), then a tablet again.
      tester.view.physicalSize = _phone;
      await tester.pumpAndSettle();
      expect(find.text('EARLIER VERSIONS'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = _landscape;
      await tester.pumpAndSettle();
      expect(find.text('ONSET 1.0.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('just updated: the old version and Got it in the header', (
      tester,
    ) async {
      await open(
        tester,
        size: _landscape,
        updatedTo: '1.1.0',
        updatedFrom: '1.0.2',
      );
      final gotIt = tester.getRect(find.text('Got it'));
      final title = tester.getRect(find.text('Updated to 1.1.0'));
      expect((gotIt.center.dy - title.center.dy).abs(), lessThan(40));
      expect(gotIt.left, greaterThan(title.right));
    });
  });

  group('links', () {
    late List<Uri> launched;

    setUp(() {
      launched = [];
      LinkRouter.launcher = (url, {mode = LaunchMode.platformDefault}) async {
        launched.add(url);
        return true;
      };
    });
    tearDown(() => LinkRouter.launcher = launchUrl);

    testWidgets('an http(s) link opens through the app\'s link launcher', (
      tester,
    ) async {
      await open(tester);
      final docs = spansWith(tester, 'the docs');
      expect(docs, hasLength(1));
      (docs.single.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();
      expect(launched, [Uri.parse('https://example.com/docs')]);
    });

    testWidgets('any other scheme is plain text, never a link', (tester) async {
      await open(tester);
      final other = spansWith(tester, 'this');
      expect(other, hasLength(1));
      expect(other.single.recognizer, isNull);
      expect(launched, isEmpty);
    });
  });

  testWidgets('the page reads its sections as headings', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    expect(
      tester.getSemantics(find.text('ONSET 1.1.0')),
      containsSemantics(isHeader: true, label: 'ONSET 1.1.0'),
    );
    semantics.dispose();
  });
}
