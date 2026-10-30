import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The bundled Inter font's licence (SIL Open Font License 1.1).
const interLicenseAsset = 'assets/fonts/OFL.txt';

/// Adds the licences of the bundled fonts to the Licenses page: they are
/// assets, not packages, so Flutter does not list them by itself.
void registerFontLicenses() => LicenseRegistry.addLicense(_fontLicenses);

Stream<LicenseEntry> _fontLicenses() async* {
  final text = await rootBundle.loadString(interLicenseAsset);
  yield LicenseEntryWithLineBreaks(const ['Inter'], text);
}
