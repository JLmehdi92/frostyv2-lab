enum ReportKind { user, channel, emote, message, clip }

enum ReportReason {
  harassment('harassment'),
  hatefulConduct('hateful_conduct'),
  spam('spam'),
  sexualContent('sexual_content'),
  gore('gore'),
  harm('harm'),
  selfHarm('selfharm'),
  terrorism('terrorism_mass_violence'),
  impersonation('impersonation'),
  misinformation('misinformation'),
  ipViolation('ip_violation'),
  underaged('underaged'),
  banEvasion('tos_ban_evasion'),
  chatBanEvasion('chat_ban_evasion'),
  cheating('cheating'),
  bitsViolation('bits_violation');

  const ReportReason(this.id);

  final String id;

  static const _shared = [
    harassment,
    hatefulConduct,
    spam,
    sexualContent,
    gore,
    harm,
    selfHarm,
    terrorism,
    impersonation,
    misinformation,
    ipViolation,
    underaged,
  ];

  static List<ReportReason> forKind(ReportKind kind) => switch (kind) {
    ReportKind.user => [..._shared, banEvasion, bitsViolation],
    ReportKind.channel => [..._shared, banEvasion, cheating],
    ReportKind.emote => _shared,
    ReportKind.message => [..._shared, banEvasion, chatBanEvasion, cheating],
    ReportKind.clip => [..._shared, banEvasion, cheating],
  };
}

class ReportTarget {
  const ReportTarget._({
    required this.kind,
    required this.targetUserId,
    required this.contentId,
    required this.name,
    this.extra = '',
  });

  const ReportTarget.user({required String userId, required String name})
    : this._(
        kind: ReportKind.user,
        targetUserId: userId,
        contentId: userId,
        name: name,
      );

  const ReportTarget.channel({required String channelId, required String name})
    : this._(
        kind: ReportKind.channel,
        targetUserId: channelId,
        contentId: channelId,
        name: name,
      );

  const ReportTarget.emote({
    required String emoteId,
    required String ownerId,
    required String name,
  }) : this._(
         kind: ReportKind.emote,
         targetUserId: ownerId,
         contentId: emoteId,
         name: name,
       );

  const ReportTarget.message({
    required String messageId,
    required String senderId,
    required String channelId,
    required String name,
  }) : this._(
         kind: ReportKind.message,
         targetUserId: senderId,
         contentId: messageId,
         name: name,
         extra: channelId,
       );

  const ReportTarget.clip({
    required String slug,
    required String broadcasterId,
    required String name,
  }) : this._(
         kind: ReportKind.clip,
         targetUserId: broadcasterId,
         contentId: slug,
         name: name,
       );

  static final _twitchEmoteUrl = RegExp(
    r'^https://static-cdn\.jtvnw\.net/emoticons/v[12]/([A-Za-z0-9_]+)/',
  );

  static String? twitchEmoteId(String url) =>
      _twitchEmoteUrl.firstMatch(url)?.group(1);

  final ReportKind kind;
  final String targetUserId;
  final String contentId;
  final String name;
  final String extra;

  String get contentType => switch (kind) {
    ReportKind.user || ReportKind.channel => 'USER_REPORT',
    ReportKind.emote => 'EMOTE_REPORT',
    ReportKind.message => 'CHAT_REPORT',
    ReportKind.clip => 'CLIP_REPORT',
  };

  List<ReportReason> get reasons => ReportReason.forKind(kind);
}
