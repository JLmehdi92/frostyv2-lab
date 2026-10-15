package com.tommychow.frosty

import android.webkit.CookieManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

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
                    if (url == null) {
                        result.error("bad_args", "url is required", null)
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

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    companion object {
        const val CHANNEL = "frosty/cookies"
    }
}
