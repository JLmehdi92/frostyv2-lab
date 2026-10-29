import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';

void main() {
  test('logging in asks for the clip scope, keeping the others', () {
    final scopes = AuthBase.loginScopes.split(' ');
    expect(scopes, contains('clips:edit'));
    for (final scope in [
      'chat:read',
      'chat:edit',
      'user:read:follows',
      'user:manage:whispers',
      'user:read:chat',
      'moderator:manage:banned_users',
    ]) {
      expect(scopes, contains(scope));
    }
    expect(scopes.toSet(), hasLength(scopes.length), reason: 'no duplicate');
  });
}
