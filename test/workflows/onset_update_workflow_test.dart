import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
