import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/services/font_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the Inter font licence is on the Licenses page', () async {
    registerFontLicenses();

    final inter = await LicenseRegistry.licenses
        .where((entry) => entry.packages.contains('Inter'))
        .toList();

    expect(inter, hasLength(1));
    final text = inter.single.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('Copyright (c) 2016 The Inter Project Authors'));
    expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
  });
}
