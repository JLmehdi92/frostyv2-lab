import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/chat_identity.dart';

import '../fixtures/chat_identity_payloads.dart';

void main() {
  test('reads the channel and global badges, the picks and the flair', () {
    final identity = ChatIdentity.fromBody(
      chatIdentityResponse(flairHidden: true),
    )!;

    expect(identity.channelBadges.map((b) => b.key), [
      'subscriber/3012',
      'sub-gifter/5',
    ]);
    expect(identity.selectedFor(ChatBadgeScope.channel)?.title, 'Subscriber');
    expect(identity.globalBadges, hasLength(2));
    expect(identity.globalSelected?.setId, 'premium');
    expect(identity.flairHidden, isTrue);
    expect(identity.channelBadges.first.imageUrl, endsWith('subscriber-2'));
  });

  test('is null when logged out or malformed', () {
    expect(ChatIdentity.fromBody(chatIdentityAnonymousResponse), isNull);
    expect(ChatIdentity.fromBody(null), isNull);
    expect(ChatBadgeChoice.tryParse({'setID': 'a b', 'version': '1'}), isNull);
  });
}
