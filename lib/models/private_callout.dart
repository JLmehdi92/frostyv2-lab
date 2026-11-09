class PrivateCallout {
  const PrivateCallout({
    required this.id,
    required this.body,
    this.actionLabel,
    this.actionUrl,
  });

  final String id;
  final String body;
  final String? actionLabel;
  final Uri? actionUrl;

  static const maxBodyLength = 300;
  static final _id = RegExp(r'^[A-Za-z0-9_:\-]{1,128}$');

  static PrivateCallout? fromEvent(Map<String, dynamic> data) {
    final callout = data['private_callout'];
    if (callout is! Map) return null;
    final id = callout['id'];
    final body = callout['body'];
    if (id is! String || !_id.hasMatch(id)) return null;
    if (body is! String) return null;
    final text = body.trim();
    if (text.isEmpty || text.length > maxBodyLength) return null;
    final action = _linkAction(callout['actions']);
    return PrivateCallout(
      id: id,
      body: text,
      actionLabel: action?.label,
      actionUrl: action?.url,
    );
  }

  static ({String? label, Uri url})? _linkAction(Object? actions) {
    if (actions is! List) return null;
    for (final action in actions) {
      if (action is! Map) continue;
      final raw = action['url'];
      final url = raw is String ? Uri.tryParse(raw) : null;
      if (url == null || url.scheme != 'https' || url.host.isEmpty) continue;
      final label = action['body'];
      return (
        label: label is String && label.trim().isNotEmpty ? label.trim() : null,
        url: url,
      );
    }
    return null;
  }
}

class PredictionWin {
  const PredictionWin({required this.eventId, required this.points});

  final String eventId;
  final int points;

  static PredictionWin? fromEvent(String type, Map<String, dynamic> data) {
    if (type != 'prediction-result') return null;
    final prediction = data['prediction'];
    if (prediction is! Map) return null;
    final result = prediction['result'];
    if (result is! Map || result['type'] != 'WIN') return null;
    final points = result['points_won'];
    final event = prediction['event_id'];
    if (points is! int || points <= 0 || event is! String) return null;
    return PredictionWin(eventId: event, points: points);
  }
}
