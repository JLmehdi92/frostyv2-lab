import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/main.dart';
import 'package:onset/screens/onboarding/login_webview.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/widgets/onset_alert_dialog.dart';
import 'package:provider/provider.dart';

/// Dio interceptor that catches 401 Unauthorized errors and shows a login dialog
class UnauthorizedInterceptor extends Interceptor {
  final AuthStore _authStore;

  UnauthorizedInterceptor(this._authStore);

  /// Set to true in a request's `extra` when a 401 is an expected answer
  /// the caller handles (e.g. a scope older tokens lack): no login dialog.
  static const quiet = 'onset.quietUnauthorized';

  /// Whether a 401 to [request] asks the user to log in again.
  static bool promptsLogin(RequestOptions request) =>
      // Token validation handles its own 401.
      !request.uri.path.endsWith('/validate') && request.extra[quiet] != true;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Check if this is a 401 Unauthorized error
    if (err.response?.statusCode == 401) {
      if (!promptsLogin(err.requestOptions)) {
        handler.next(err);
        return;
      }

      // A logged-out viewer is never asked to log in by a 401: the app token
      // is missing, expired or revoked (a dialog would come back on every
      // Helix call), or the call needed an account, which the viewer chose
      // not to use. The app token is looked at again instead (at most once
      // a minute). A user's session, even reconnecting, still gets the
      // dialog.
      if (_authStore.isAnonymous) {
        unawaited(
          _authStore.retryAppToken(
            refused: _header(err.requestOptions, 'Authorization'),
          ),
        );
        handler.next(err);
        return;
      }

      // For other requests, show login dialog and reject so the Future completes
      _showLoginDialog();
      handler.reject(err);
      return;
    }

    // For non-401 errors, continue with normal error handling
    handler.next(err);
  }

  static String? _header(RequestOptions request, String name) {
    for (final MapEntry(:key, :value) in request.headers.entries) {
      if (key.toLowerCase() == name.toLowerCase()) return value?.toString();
    }
    return null;
  }

  void _showLoginDialog() {
    // Use the global navigator key to show dialog without needing BuildContext
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Use a flag to prevent multiple dialogs
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    // Determine if user is logged in but missing scopes vs completely logged out
    final isLoggedIn = _authStore.isLoggedIn;
    final l = context.l10n;
    final title = isLoggedIn
        ? l.authMissingPermissionsTitle
        : l.authSessionExpiredTitle;
    final message = isLoggedIn
        ? l.authMissingPermissions
        : l.authSessionExpired;

    showDialog(
      context: context,
      barrierDismissible: false, // User must choose an action
      builder: (BuildContext dialogContext) {
        return OnsetAlertDialog(
          title: title,
          message: message,
          actions: [
            TextButton(
              onPressed: () {
                _isDialogShowing = false;
                Navigator.of(dialogContext).pop(); // Close dialog
              },
              child: Text(l.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                _isDialogShowing = false;
                Navigator.of(dialogContext).pop(); // Close dialog
                // Navigate to login WebView
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => Provider<AuthStore>.value(
                      value: _authStore,
                      child: const LoginWebView(),
                    ),
                  ),
                );
              },
              child: Text(l.authLogIn),
            ),
          ],
        );
      },
    ).then((_) {
      // Reset flag when dialog is dismissed
      _isDialogShowing = false;
    });
  }

  static bool _isDialogShowing = false;
}
