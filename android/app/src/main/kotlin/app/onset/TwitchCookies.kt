package app.onset

import android.webkit.CookieManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.net.URI
import java.net.URISyntaxException

/**
 * Reads cookies out of the WebView's cookie jar.
 *
 * The login flow already signs the user in to twitch.tv inside an in-app
 * WebView, which leaves the `auth-token` cookie in this jar. That cookie is the
 * only credential Twitch's GQL endpoint accepts for the enhanced-broadcast
 * renditions (1440p HEVC / AV1), because GQL only honours allowlisted
 * client-ids and the fork's own OAuth token is minted for its own client-id.
 *
 * Dart cannot read that cookie itself: `webview_flutter`'s cookie manager only
 * writes and clears, and Twitch may mark the cookie `HttpOnly`, which hides it
 * from `document.cookie`. Android's [CookieManager] returns it either way.
 */
class TwitchCookies(messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getCookie" -> {
                    val url = call.argument<String>("url")
                    if (url == null || !isTwitchUrl(url)) {
                        result.error("bad_args", "a https twitch.tv url is required", null)
                    } else {
                        result.success(readCookie(url))
                    }
                }
                "clearCookies" -> {
                    CookieManager.getInstance().removeAllCookies { }
                    CookieManager.getInstance().flush()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Returns the raw `name=value; name=value` cookie string [url] would be
     * sent, or null when the jar holds nothing for it.
     *
     * The jar is flushed first: cookies written by the WebView live in memory
     * until Chromium persists them, and a login immediately followed by a read
     * would otherwise race that write.
     */
    private fun readCookie(url: String): String? {
        val manager = CookieManager.getInstance()
        manager.flush()
        return manager.getCookie(url)?.takeIf { it.isNotBlank() }
    }

    /**
     * Only twitch.tv's own cookies may leave the jar. The channel is reachable
     * from any Dart code, and the jar also holds the sessions of every other
     * site the in-app WebViews have visited.
     */
    private fun isTwitchUrl(url: String): Boolean {
        val uri = try {
            URI(url)
        } catch (e: URISyntaxException) {
            return false
        }
        val host = uri.host ?: return false
        return uri.scheme == "https" && (host == "twitch.tv" || host.endsWith(".twitch.tv"))
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    companion object {
        const val CHANNEL = "onset/cookies"
    }
}
