class WhisperPeer {
  const WhisperPeer({
    required this.id,
    required this.login,
    required this.displayName,
  });

  final String id;
  final String login;
  final String displayName;

  static final _numericId = RegExp(r'^[0-9]{1,20}$');
  static final _login = RegExp(r'^[a-zA-Z0-9_]{1,25}$');

  static WhisperPeer? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final login = json['login'];
    if (id is! String || !_numericId.hasMatch(id)) return null;
    if (login is! String || !_login.hasMatch(login)) return null;
    final name = json['displayName'];
    return WhisperPeer(
      id: id,
      login: login.toLowerCase(),
      displayName: name is String && name.isNotEmpty && name.length <= 64
          ? name
          : login,
    );
  }
}

class WhisperHistoryMessage {
  const WhisperHistoryMessage({
    required this.id,
    required this.fromId,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String fromId;
  final String text;
  final DateTime sentAt;

  static const maxLength = 2000;

  static WhisperHistoryMessage? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final from = WhisperPeer.fromJson(json['from']);
    final sentAt = DateTime.tryParse('${json['sentAt']}');
    final content = json['content'];
    final text = content is Map ? content['content'] : null;
    if (id is! String || id.isEmpty || id.length > 128) return null;
    if (from == null || sentAt == null) return null;
    if (text is! String || text.trim().isEmpty || text.length > maxLength) {
      return null;
    }
    return WhisperHistoryMessage(
      id: id,
      fromId: from.id,
      text: text,
      sentAt: sentAt.toLocal(),
    );
  }
}

class WhisperHistoryThread {
  const WhisperHistoryThread({
    required this.id,
    required this.peer,
    required this.unread,
    required this.archived,
    required this.muted,
    this.last,
  });

  final String id;
  final WhisperPeer peer;
  final WhisperHistoryMessage? last;
  final int unread;
  final bool archived;
  final bool muted;

  static final _threadId = RegExp(r'^[0-9]{1,20}_[0-9]{1,20}$');

  static WhisperHistoryThread? fromJson(Object? json, {required String me}) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || !_threadId.hasMatch(id)) return null;
    final participants = json['participants'];
    if (participants is! List) return null;
    final peer = participants
        .map(WhisperPeer.fromJson)
        .whereType<WhisperPeer>()
        .where((p) => p.id != me)
        .firstOrNull;
    if (peer == null) return null;
    final messages = json['messages'];
    final edges = messages is Map ? messages['edges'] : null;
    final firstEdge = edges is List ? edges.firstOrNull : null;
    final unread = json['unreadMessagesCount'];
    return WhisperHistoryThread(
      id: id,
      peer: peer,
      last: WhisperHistoryMessage.fromJson(
        firstEdge is Map ? firstEdge['node'] : null,
      ),
      unread: unread is int && unread > 0 ? unread : 0,
      archived: json['isArchived'] == true,
      muted: json['isMuted'] == true,
    );
  }
}

class WhisperPrivacy {
  const WhisperPrivacy({
    required this.blockStrangers,
    this.banned = false,
    this.disabledByParent = false,
  });

  final bool blockStrangers;
  final bool banned;
  final bool disabledByParent;

  static WhisperPrivacy? fromSettings(Object? settings) {
    if (settings is! Map) return null;
    final block = settings['isBlockingWhispersFromStrangers'];
    if (block is! bool) return null;
    return WhisperPrivacy(
      blockStrangers: block,
      banned: settings['isWhisperBanned'] == true,
      disabledByParent: settings['isWhispersDisabledByParent'] == true,
    );
  }
}
