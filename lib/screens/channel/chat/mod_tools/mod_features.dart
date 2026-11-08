enum ModFeature {
  announcements({'moderator:manage:announcements'}),
  shoutouts({'moderator:manage:shoutouts'}),
  shieldMode({'moderator:manage:shield_mode'}),
  autoMod({'moderator:manage:automod'}),
  blockedTerms({'moderator:manage:blocked_terms'}),
  unbanRequests({'moderator:manage:unban_requests'}),
  suspiciousUsers({'moderator:manage:suspicious_users'}),
  actionFeed({
    'moderator:read:moderators',
    'moderator:read:vips',
    'moderator:manage:blocked_terms',
    'moderator:manage:chat_settings',
    'moderator:manage:unban_requests',
    'moderator:manage:banned_users',
    'moderator:manage:chat_messages',
    'moderator:manage:warnings',
  }),
  moderators({'channel:manage:moderators'}, broadcasterOnly: true),
  vips({'channel:manage:vips'}, broadcasterOnly: true),
  streamInfo({'channel:manage:broadcast'}, broadcasterOnly: true),
  marker({'channel:manage:broadcast'}, broadcasterOnly: true),
  commercial({'channel:edit:commercial'}, broadcasterOnly: true),
  raid({'channel:manage:raids'}, broadcasterOnly: true),
  polls({'channel:manage:polls'}, broadcasterOnly: true),
  predictions({'channel:manage:predictions'}, broadcasterOnly: true),
  redemptions({'channel:manage:redemptions'}, broadcasterOnly: true),
  bans({'moderator:manage:banned_users'}, broadcasterOnly: true);

  const ModFeature(this.scopes, {this.broadcasterOnly = false});

  final Set<String> scopes;
  final bool broadcasterOnly;

  static Set<String> get allScopes => {
    for (final feature in values) ...feature.scopes,
  };
}
