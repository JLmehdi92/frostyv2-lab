import 'package:flutter_test/flutter_test.dart';
import 'package:onset/utils/punycode.dart';

void main() {
  test('labels with letters outside ASCII get their punycode form', () {
    expect(punycodeEncode('bücher'), 'bcher-kva');
    expect(punycodeEncode('münchen'), 'mnchen-3ya');
    expect(punycodeEncode('日本語'), 'wgv71a119e');
    expect(punycodeEncode('ドメイン名例'), 'eckwd4c7cu47r2wf');
    expect(asciiHost('www.bücher.de'), 'www.xn--bcher-kva.de');
    expect(asciiHost('example.com'), 'example.com');
  });

  test('a host Dart keeps percent-encoded is decoded first', () {
    final host = Uri.parse('https://twitсh.tv/login').host;
    expect(asciiHost(host), 'xn--twith-4ye.tv');
    expect(asciiHost('bad%zzhost.tv'), 'bad%zzhost.tv');
  });
}
