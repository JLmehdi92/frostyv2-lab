class UnbanRequestState {
  const UnbanRequestState({
    required this.enabled,
    this.canRequest,
    this.status,
    this.createdAt,
    this.moderatorNote,
  });

  final bool enabled;
  final bool? canRequest;
  final String? status;
  final DateTime? createdAt;
  final String? moderatorNote;

  static const _statuses = {
    'PENDING',
    'APPROVED',
    'DENIED',
    'ACKNOWLEDGED',
    'CANCELED',
  };

  bool get hasRequest => status != null && createdAt != null;

  bool get canSend => enabled && canRequest == true && status != 'PENDING';

  static UnbanRequestState? fromBody(Object? body) {
    final data = body is Map ? body['data'] : null;
    final channel = data is Map ? data['channel'] : null;
    if (channel is! Map) return null;
    final settings = channel['unbanRequestsSettings'];
    final self = channel['self'];
    final last = self is Map ? self['lastUnbanRequest'] : null;
    final can = self is Map ? self['canRequestUnban'] : null;
    final status = last is Map ? last['status'] : null;
    final created = last is Map ? last['createdAt'] : null;
    final note = last is Map ? last['resolverMessage'] : null;
    return UnbanRequestState(
      enabled: settings is Map && settings['isEnabled'] == true,
      canRequest: can is bool ? can : null,
      status: status is String && _statuses.contains(status) ? status : null,
      createdAt: created is String ? DateTime.tryParse(created) : null,
      moderatorNote: note is String && note.trim().isNotEmpty
          ? note.trim()
          : null,
    );
  }
}

enum UnbanRequestResult { sent, refused, signedOut, failed }

class UnbanRequestOutcome {
  const UnbanRequestOutcome(this.result, {this.code});

  final UnbanRequestResult result;
  final String? code;

  static UnbanRequestOutcome fromBody(Object? body) {
    if (body is! Map) {
      return const UnbanRequestOutcome(UnbanRequestResult.failed);
    }
    final data = body['data'];
    final payload = data is Map ? data['createUnbanRequest'] : null;
    if (payload is! Map) {
      return const UnbanRequestOutcome(UnbanRequestResult.failed);
    }
    final error = payload['error'];
    if (error is Map) {
      final code = error['code'];
      return UnbanRequestOutcome(
        UnbanRequestResult.refused,
        code: code is String ? code : null,
      );
    }
    return payload['unbanRequest'] is Map
        ? const UnbanRequestOutcome(UnbanRequestResult.sent)
        : const UnbanRequestOutcome(UnbanRequestResult.failed);
  }
}
