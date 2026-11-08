class ResubNotification {
  final int months;
  final String tokenId;
  final bool isGift;

  const ResubNotification({
    required this.months,
    required this.tokenId,
    this.isGift = false,
  });

  static final _safeToken = RegExp(r'^[A-Za-z0-9_:\-]{1,128}$');

  static ResubNotification? tryParse(Object? body) {
    if (body is! Map || body['errors'] != null) return null;
    final user = (body['data'] as Map?)?['user'];
    if (user is! Map) return null;
    final self = user['self'];
    if (self is! Map) return null;
    final notification = self['resubNotification'];
    if (notification is! Map) return null;
    final token = notification['token'];
    final months = notification['months'];
    if (token is! String || !_safeToken.hasMatch(token)) return null;
    if (months is! int || months < 1) return null;
    return ResubNotification(
      months: months,
      tokenId: token,
      isGift: notification['isGiftSubscription'] == true,
    );
  }
}
