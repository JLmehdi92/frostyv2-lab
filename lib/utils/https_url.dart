/// Twitch's image host: raid pictures named by Twitch payloads come from
/// there, and nothing else is loaded for them.
const kTwitchImageHost = 'static-cdn.jtvnw.net';

/// [url] when it is an https URL on Twitch's image host, else null (the
/// caller falls back to the channel's initial).
String? twitchImageOrNull(String? url) {
  if (url == null) return null;
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != kTwitchImageHost ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return url;
}
