import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_api.dart';

/// The update workflow cannot run here, so its text is checked: a build made
/// while the repository is public must never carry UPDATE_TOKEN, because the
/// APK of a public release can be downloaded, and the token read, by anyone.
void main() {
  late String workflow;

  setUpAll(
    () => workflow = File(
      '.github/workflows/onset-update.yml',
    ).readAsStringSync().replaceAll('\r\n', '\n'),
  );

  const guarded =
      "\${{ steps.visibility.outputs.private == 'true' && "
      "secrets.UPDATE_TOKEN || '' }}";

  /// The lines of the step named [name], up to the next step.
  String step(String name) {
    final start = workflow.indexOf('- name: $name\n');
    expect(start, isNot(-1), reason: 'no step "$name"');
    final next = workflow.indexOf('\n      - name: ', start + 1);
    final jobEnd = workflow.indexOf('\n  publish:', start + 1);
    final ends = [next, jobEnd, workflow.length].where((i) => i > start);
    return workflow.substring(start, ends.reduce((a, b) => a < b ? a : b));
  }

  test('reads the visibility from the event and from the live repository', () {
    final visibility = step('Check the repository visibility');

    expect(visibility, contains('id: visibility'));
    expect(
      visibility,
      contains(r'EVENT_PRIVATE: ${{ github.event.repository.private }}'),
    );
    expect(visibility, contains(r'gh api "repos/$GITHUB_REPOSITORY"'));
    // Only "private" on both sides keeps the token.
    expect(visibility, contains('true/true) private=true'));
    expect(visibility, contains('exit 1'));
    expect(
      workflow.indexOf('- name: Check the repository visibility'),
      lessThan(workflow.indexOf('- name: Check the secrets')),
    );
  });

  test(
    'every use of the UPDATE_TOKEN secret is guarded by the private flag',
    () {
      final uses = 'secrets.UPDATE_TOKEN'.allMatches(workflow).length;
      final guardedUses = guarded.allMatches(workflow).length;

      expect(uses, greaterThan(0));
      expect(guardedUses, uses);
      expect(step('Build the APK'), contains('UPDATE_TOKEN: $guarded'));
      expect(step('Check the secrets'), contains('UPDATE_TOKEN: $guarded'));
    },
  );

  test('the token is only required when the repository is private', () {
    final check = step('Check the secrets');

    expect(
      check,
      contains(r'REPO_PRIVATE: ${{ steps.visibility.outputs.private }}'),
    );
    expect(check, contains(r'if [ "$REPO_PRIVATE" = true ]; then'));
    expect(
      RegExp(r'for name in [^;]*UPDATE_TOKEN').hasMatch(check),
      isFalse,
      reason: 'UPDATE_TOKEN must not be required unconditionally',
    );
  });

  test('the build passes the token as a dart-define and never prints it', () {
    final build = step('Build the APK');

    expect(build, contains(r'--dart-define=UPDATE_TOKEN="$UPDATE_TOKEN"'));
    expect(
      RegExp(r'flutter build[^\n]*(\s-v\b|--verbose)').hasMatch(build),
      isFalse,
    );
    expect(
      RegExp(r'(echo|printf)[^\n]*UPDATE_TOKEN').hasMatch(workflow),
      isFalse,
    );
    expect(RegExp(r'set -x').hasMatch(workflow), isFalse);
  });

  test('the Twitch client secret is neither required nor passed', () {
    // It lives in the token proxy (tool/token_proxy/), never in an APK.
    expect(workflow, isNot(contains('secrets.SECRET')));
    expect(workflow, isNot(contains('--dart-define=SECRET')));
    expect(
      RegExp(
        r'for name in [^;]*\bSECRET\b',
      ).hasMatch(step('Check the secrets')),
      isFalse,
    );
  });

  test('build numbers start above 2000', () {
    // Builds start at 2001 and stay above the earlier 10xx series: Android
    // installs an update only over a lower build number, and the app offers
    // only a higher one.
    final build = step('Build the APK');

    expect(build, contains(r'BUILD=$((2000 + GITHUB_RUN_NUMBER))'));
    expect(build, contains(r'--build-number="$BUILD"'));
    expect(build, contains(r'echo "build=$BUILD" >> "$GITHUB_OUTPUT"'));
  });

  test('the token proxy URL comes from a repository variable', () {
    const fromVariable = r'TOKEN_PROXY_URL: ${{ vars.TOKEN_PROXY_URL }}';

    expect(workflow, isNot(contains('secrets.TOKEN_PROXY_URL')));
    expect(step('Check the secrets'), contains(fromVariable));
    expect(step('Build the APK'), contains(fromVariable));
    expect(
      step('Build the APK'),
      contains(r'--dart-define=TOKEN_PROXY_URL="$TOKEN_PROXY_URL"'),
    );
  });

  test('a build without a token proxy URL the app accepts fails, saying '
      'why', () {
    final check = step('Check the secrets');

    // The same pattern as the app's, so CI never ships a URL the app
    // would refuse.
    expect(
      check,
      contains("proxy_pattern='${TwitchApi.tokenProxyUrlPattern}'"),
    );
    expect(
      check,
      contains(r'if [[ ! "$TOKEN_PROXY_URL" =~ $proxy_pattern ]]; then'),
    );
    expect(
      check,
      contains(
        '::error::The repository variable TOKEN_PROXY_URL is missing or '
        'is not a plain https:// URL',
      ),
    );
    final variableCheck = check.substring(
      check.indexOf(r'if [[ ! "$TOKEN_PROXY_URL"'),
    );
    expect(variableCheck, contains('exit 1'));
  });

  test('the URL pattern refuses what the app refuses', () {
    final pattern = RegExp(TwitchApi.tokenProxyUrlPattern);
    for (final good in [
      'https://onset-token.me.workers.dev',
      'https://onset-token.me.workers.dev/',
      'https://proxy.example.dev:8443/base',
    ]) {
      expect(pattern.hasMatch(good), isTrue, reason: good);
    }
    for (final bad in [
      '',
      'http://onset-token.me.workers.dev',
      'https://user:pass@onset-token.me.workers.dev',
      'https://onset-token.me.workers.dev?x=1',
      'https://onset-token.me.workers.dev#x',
      'https://onset-token.me.workers.dev/a b',
      ' https://onset-token.me.workers.dev',
    ]) {
      expect(pattern.hasMatch(bad), isFalse, reason: bad);
    }
  });

  test('the public build log says why there is no token', () {
    expect(
      step('Check the repository visibility'),
      contains(
        'The build carries no update token (event or repository is public).',
      ),
    );
  });

  test('the publish guard fails closed and deletes a refused artifact', () {
    final recheck = step('Check the repository is still private');

    // Anything but an explicit "false" counts as a build with the token.
    expect(
      recheck,
      contains(r'if [ "$TOKEN_BUILD" != false ] && [ "$live" != true ]; then'),
    );
    expect(recheck, contains(r'actions/runs/$GITHUB_RUN_ID/artifacts'));
    expect(recheck, contains('select(.name == "onset-update")'));
    expect(recheck, contains('gh api -X DELETE'));
    final publish = workflow.substring(workflow.indexOf('\n  publish:'));
    expect(publish, contains('      actions: write\n'));
    expect(publish, isNot(contains('secrets.')));
  });

  test('publishing refuses a token build once the repository is public', () {
    expect(
      workflow,
      contains(r'token: ${{ steps.visibility.outputs.private }}'),
    );
    final recheck = step('Check the repository is still private');

    expect(recheck, contains(r'TOKEN_BUILD: ${{ needs.build.outputs.token }}'));
    expect(recheck, contains(r'gh api "repos/$GITHUB_REPOSITORY"'));
    expect(recheck, contains('exit 1'));
    expect(
      workflow.indexOf('- name: Check the repository is still private'),
      lessThan(workflow.indexOf('- name: Create the release')),
    );
  });
}
