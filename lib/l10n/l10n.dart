import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/l10n/app_localizations.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:onset/l10n/app_localizations.dart';

/// The app's texts, in widgets: `context.l10n.commonNext`.
extension L10nContext on BuildContext {
  /// The texts of the language on screen. English where no
  /// [AppLocalizations] is above (a bare `MaterialApp` in a test), so a
  /// widget never fails for want of one.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      L10n.english;
}

/// The texts where there is no widget to ask (a chat notice put in the
/// buffer, a notification): [current], the language the app shows.
///
/// [LocaleSync] keeps it in step with the screen; widgets read
/// `context.l10n` instead, which rebuilds them when the language changes.
abstract final class L10n {
  /// The English texts: the fallback, and the language until the app shows
  /// another.
  static final AppLocalizations english = lookupAppLocalizations(
    const Locale('en'),
  );

  static final _current = Observable<AppLocalizations>(
    english,
    name: 'L10n.current',
  );

  /// The texts of the language the app shows (observable).
  static AppLocalizations get current => _current.value;

  /// The app now shows [locale] (an unsupported one reads as English):
  /// [current] and `Intl.defaultLocale` (dates and numbers) follow.
  static void use(Locale locale) {
    final supported = resolveAppLocale(AppLanguage.system, [locale]);
    Intl.defaultLocale = supported.languageCode;
    runInAction(() => _current.value = lookupAppLocalizations(supported));
  }
}

/// The locale the app shows for [language] on a device whose preferred
/// languages are [device], first preferred first: the language picked, or
/// for [AppLanguage.system] the first supported one the device prefers
/// (fr-CA is French), English when it prefers none.
Locale resolveAppLocale(AppLanguage language, List<Locale> device) {
  if (language.locale case final picked?) return picked;
  for (final locale in device) {
    for (final supported in AppLocalizations.supportedLocales) {
      if (locale.languageCode == supported.languageCode) return supported;
    }
  }
  return const Locale('en');
}

/// The language the app shows for [language] on a device preferring
/// [device]: [language] itself when the viewer picked one, else the
/// device's ([resolveAppLocale]). Never [AppLanguage.system]: what the
/// language pills show selected, and what choosing nothing stores.
AppLanguage resolveAppLanguage(AppLanguage language, List<Locale> device) {
  if (language != AppLanguage.system) return language;
  return switch (resolveAppLocale(language, device).languageCode) {
    'fr' => AppLanguage.fr,
    _ => AppLanguage.en,
  };
}

/// Says the locale the app shows to whoever needs it outside widgets.
///
/// Placed in `MaterialApp.builder`, under the app's [Localizations]: each
/// time the resolved locale changes (at launch, then whenever the viewer or
/// the device changes the language) it calls [L10n.use], then every
/// listener of [onLocale] in order, each with the new locale. Listeners
/// that fail are reported and do not stop the others.
class LocaleSync extends StatefulWidget {
  const LocaleSync({super.key, this.onLocale = const [], required this.child});

  /// Told the new locale after [L10n] (the saved copy the background tasks
  /// read, for instance).
  final List<ValueChanged<Locale>> onLocale;

  final Widget child;

  @override
  State<LocaleSync> createState() => _LocaleSyncState();
}

class _LocaleSyncState extends State<LocaleSync> {
  Locale? _locale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (locale == _locale) return;
    _locale = locale;
    L10n.use(locale);
    for (final listener in widget.onLocale) {
      try {
        listener(locale);
      } catch (e, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: stack,
            library: 'onset l10n',
            context: ErrorDescription('while telling a listener the locale'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The preferences key of the language the app last showed ('en' or 'fr'),
/// for what runs without the app's widgets (the background go-live check).
const kUiLanguagePrefsKey = 'ui_language';

/// Saves [locale]'s language under [kUiLanguagePrefsKey] (a [LocaleSync]
/// listener). Nothing breaks without it: the background reads the device's
/// language then.
Future<void> saveUiLanguage(Locale locale) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUiLanguagePrefsKey, locale.languageCode);
  } catch (e) {
    debugPrint('Language not saved for the background: ${e.runtimeType}');
  }
}

/// The first private-use code point of [l10nMark].
const _firstMark = 0xF0000;

/// How many pieces [l10nSpans] can place in one message.
const _markCount = 16;

/// Stands in for piece [index] of [l10nSpans] in a message: pass it as the
/// placeholder's value (`l.loggedInAs(name: l10nMark(0))`).
String l10nMark(int index) {
  RangeError.checkValueInInterval(index, 0, _markCount - 1, 'index');
  return String.fromCharCode(_firstMark + index);
}

/// A message with styled pieces (a bold name, a link) where its
/// placeholders are, whatever order the language puts them in.
///
/// [message] is the message built with [l10nMark]s as placeholder values;
/// mark `i` becomes `pieces[i]` and the text around it plain spans (in the
/// style the spans inherit). A piece the message does not place is left
/// out; a mark without a piece stays out too.
List<InlineSpan> l10nSpans(String message, List<InlineSpan> pieces) {
  final spans = <InlineSpan>[];
  final text = StringBuffer();
  void flush() {
    if (text.isEmpty) return;
    spans.add(TextSpan(text: text.toString()));
    text.clear();
  }

  for (final rune in message.runes) {
    final index = rune - _firstMark;
    if (index >= 0 && index < _markCount) {
      flush();
      if (index < pieces.length) spans.add(pieces[index]);
    } else {
      text.writeCharCode(rune);
    }
  }
  flush();
  return spans;
}
