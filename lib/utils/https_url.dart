/// [url] when it is an https URL, else null: pictures named by Twitch
/// payloads are only ever loaded over https.
String? httpsOrNull(String? url) =>
    url != null && url.startsWith('https://') ? url : null;
