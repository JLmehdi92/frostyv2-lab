import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frosty/screens/onboarding/onboarding_parts.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The "Connect with Twitch" page, on its own (the login from Profile, the
/// "Session expired" prompt, clip creation): the board's bar (back, title,
/// "?" help) over the Twitch page.
///
/// Signing in pops it, or replaces it with [routeAfter] when given, as the
/// login page always did ([AuthStore.handleNavigation]).
class LoginWebView extends StatelessWidget {
  /// Optional widget to navigate to after successful login
  final Widget? routeAfter;

  /// Draws the page in place of the WebView (tests have no WebView).
  @visibleForTesting
  final Widget Function(WebViewController controller)? pageBuilder;

  const LoginWebView({super.key, this.routeAfter, this.pageBuilder});

  @override
  Widget build(BuildContext context) {
    final tablet = context.isLargeScreen;
    final padding = MediaQuery.paddingOf(context);
    final accent = Color(
      context.read<SettingsStore?>()?.accentColor ??
          FrostyTokens.accent.toARGB32(),
    );
    final themes = FrostyThemes(colorSchemeSeed: accent);
    return Theme(
      data: themes.dark,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: onboardingBars,
        // A Scaffold, so the page shrinks above the keyboard (the username
        // and password fields stay in view).
        child: Scaffold(
          backgroundColor: OnboardingColors.ground,
          body: Column(
            children: [
              SizedBox(height: padding.top),
              SizedBox(
                height: tablet ? 72 : 56,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: tablet ? 28 : 6),
                  child: LoginBar(
                    tablet: tablet,
                    inOnboarding: false,
                    onBack: () => Navigator.maybePop(context),
                  ),
                ),
              ),
              Expanded(
                child: TwitchLoginPanel(
                  tablet: tablet,
                  accent: accent,
                  routeAfter: routeAfter,
                  pageBuilder: pageBuilder,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The light status and navigation bars over the onboarding's black.
const onboardingBars = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: OnboardingColors.ground,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
);

/// The login page's bar: back, "Connect with Twitch", the "?" help.
class LoginBar extends StatelessWidget {
  const LoginBar({
    super.key,
    required this.tablet,
    required this.inOnboarding,
    required this.onBack,
  });

  final bool tablet;

  /// The help's last advice differs: the onboarding has a first step to go
  /// back to, the other entry points do not.
  final bool inOnboarding;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OnboardingIconButton(
          glyph: OnboardingGlyphKind.chevronLeft,
          tooltip: 'Back',
          onPressed: onBack,
        ),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              'Connect with Twitch',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: tablet ? 18 : 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.015 * (tablet ? 18 : 17),
                color: OnboardingColors.text,
              ),
            ),
          ),
        ),
        OnboardingIconButton(
          glyph: OnboardingGlyphKind.help,
          tooltip: 'Login help',
          size: 21,
          strokeWidth: 1.8,
          onPressed: () => showLoginHelp(
            context,
            tablet: tablet,
            inOnboarding: inOnboarding,
          ),
        ),
      ],
    );
  }
}

/// The "?" of the login page: how to get past the Twitch cookie banner when
/// it still blocks the login (boards' dialog: 24 dp corners, #1E1E1E, an
/// icon tile, the title, the text, "Close"; 440 dp wide on a tablet).
Future<void> showLoginHelp(
  BuildContext context, {
  required bool tablet,
  bool inOnboarding = true,
}) {
  final theme = Theme.of(context);
  final retry = inOnboarding
      ? 'go back to the first step of the onboarding and then try again.'
      : 'go back, then open the login again.';
  return showDialog<void>(
    context: context,
    barrierColor: OnboardingColors.scrim,
    builder: (context) => Theme(
      data: theme,
      child: _OnboardingDialog(
        width: tablet ? 440 : null,
        label: 'Login help',
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: OnboardingColors.control,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const OnboardingGlyph(
              OnboardingGlyphKind.help,
              color: OnboardingColors.text,
            ),
          ),
          const Text(
            'Workaround for the Twitch cookie banner',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.27,
              height: 1.3,
              color: OnboardingColors.text,
            ),
          ),
          Text(
            'If the Twitch cookie banner is still blocking the login, try '
            'clicking one of the links in the cookie policy description and '
            'navigating until you reach the Twitch home page. From there, you '
            'can try logging in on the top right profile icon. Once logged '
            'in, $retry',
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: OnboardingColors.body,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OnboardingTextButton(
              label: 'Close',
              fontSize: 14,
              color: OnboardingColors.text,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The boards' dialog card: #1E1E1E, 24 dp corners, the 0.5 dp ring.
class _OnboardingDialog extends StatelessWidget {
  const _OnboardingDialog({
    required this.children,
    required this.label,
    this.width,
  });

  final List<Widget> children;
  final String label;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: OnboardingColors.raised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FrostyTokens.radiusLarge),
        side: const BorderSide(
          color: OnboardingColors.ringStrong,
          width: FrostyTokens.hairlineWidth,
        ),
      ),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: label,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// The Twitch login page in its panel (#111111 under a 0.5 dp edge): the
/// host it shows (the full address carries the token, so only the host is
/// ever shown), the WebView, and over it "Signing you in…" once Twitch
/// handed the token back, or what failed with "Try again".
///
/// Every rule of the login is [AuthStore]'s: the authorization page, the
/// token taken from the redirect, the cookie banner capped at 20 % of the
/// page, the browser user agent. [onSignedIn] (the onboarding) is told when
/// Twitch has signed the WebView in; without it the page is popped (or
/// replaced by [routeAfter]).
class TwitchLoginPanel extends StatefulWidget {
  const TwitchLoginPanel({
    super.key,
    required this.tablet,
    required this.accent,
    this.routeAfter,
    this.onSignedIn,
    this.onTokenCaptured,
    this.pageBuilder,
  });

  final bool tablet;

  /// The colour picked in Setup (the spinner, "Try again").
  final Color accent;
  final Widget? routeAfter;
  final VoidCallback? onSignedIn;

  /// Given the login's own outcome once Twitch handed a token back.
  final ValueChanged<Future<bool>>? onTokenCaptured;

  /// Draws the page in place of the WebView (tests have no WebView).
  @visibleForTesting
  final Widget Function(WebViewController controller)? pageBuilder;

  /// How long "Signing you in…" may cover the page before the page shows
  /// again (Twitch never redirected to its home).
  static const signingInLimit = Duration(seconds: 20);

  @override
  State<TwitchLoginPanel> createState() => _TwitchLoginPanelState();
}

class _TwitchLoginPanelState extends State<TwitchLoginPanel> {
  late final WebViewController _controller;
  late final AuthStore _auth;

  /// The page the WebView shows (only its scheme and host are ever drawn).
  Uri _page = Uri.parse('https://id.twitch.tv');
  bool _signingIn = false;

  /// The page itself failed to load ([_failedPage]); another page clears
  /// it.
  bool _failed = false;
  Uri? _failedPage;

  /// Twitch handed a token back but the login did not go through.
  bool _loginFailed = false;
  Timer? _signingLimit;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthStore>();
    _controller = _auth.createAuthWebViewController(
      onSignedIn: _onTwitchSignedIn,
      onTokenCaptured: _onTokenCaptured,
      onNotSignedIn: _onNotSignedIn,
      onPage: _onPage,
      onError: _onError,
    );
  }

  /// [uri] without what does not make it another page (the fragment, an
  /// empty path, the host's case).
  static Uri _pageOf(Uri uri) {
    final page = uri.removeFragment().normalizePath();
    return page.path.isEmpty && page.hasAuthority
        ? page.replace(path: '/')
        : page;
  }

  void _onPage(Uri uri) {
    if (!mounted) return;
    final failed = _failedPage;
    final moved = _failed && (failed == null || _pageOf(uri) != failed);
    if (uri == _page && !moved) return;
    setState(() {
      _page = uri;
      if (moved) _failed = false;
    });
  }

  /// This page's login, once Twitch handed its token back, and its own
  /// outcome (null while in flight).
  Future<bool>? _login;
  bool? _loginWorked;

  /// Twitch's redirect to twitch.tv came (the store harvests the 2K cookie
  /// there): the page may close once its login is known.
  bool _twitchDone = false;

  /// The 20 s of "Signing you in…" are over.
  bool _signingLimitPassed = false;

  void _onTokenCaptured(Future<bool> login) {
    widget.onTokenCaptured?.call(login);
    if (!mounted) return;
    _login = login;
    _loginWorked = null;
    _signingLimitPassed = false;
    _signingLimit?.cancel();
    _signingLimit = Timer(TwitchLoginPanel.signingInLimit, _onSigningLimit);
    setState(() {
      _signingIn = true;
      _failed = false;
      _loginFailed = false;
    });
    login.catchError((Object _) => false).then((worked) {
      if (!mounted || !identical(login, _login)) return;
      _loginWorked = worked;
      if (!worked) {
        // Refused (also when another account is logged in already): the
        // page shows again at once, with what happened.
        _signingLimit?.cancel();
        setState(() {
          _signingIn = false;
          _loginFailed = true;
        });
      } else if (_signingLimitPassed) {
        _closeAfterHarvest();
        return;
      }
      // Signed in: the page waits for Twitch's redirect (the cookie
      // harvest happens there), unless it already came.
      if (_twitchDone) _afterTwitch();
    }).ignore();
  }

  /// Twitch's redirect to twitch.tv: the end of the page's journey.
  void _onTwitchSignedIn() {
    _twitchDone = true;
    _afterTwitch();
  }

  void _afterTwitch() {
    if (!mounted) return;
    // A login still in flight: closing now would leave nothing to show if it
    // fails. Once it is known, this runs again.
    if (_login != null && _loginWorked == null) return;
    // A login that failed: the page stays with the failure and Try again
    // (the onboarding moves on regardless: its Setup says it failed).
    if (_loginWorked == false && widget.onSignedIn == null) return;
    _finish();
  }

  /// No redirect after 20 s: a login that went through closes the page,
  /// after one attempt at the cookie harvest; otherwise the page shows again.
  void _onSigningLimit() {
    if (!mounted) return;
    _signingLimitPassed = true;
    if (_loginWorked == true) {
      _closeAfterHarvest();
      return;
    }
    setState(() => _signingIn = false);
  }

  /// Closes the page after one attempt at the cookie harvest, waiting 5 s
  /// at most for it (it may finish later; its write still goes through the
  /// store's account check).
  void _closeAfterHarvest() {
    _auth
        .harvestTwitchWebToken()
        .timeout(const Duration(seconds: 5), onTimeout: () => false)
        .catchError((Object _) => false)
        .whenComplete(_finish)
        .ignore();
  }

  /// Whether the page has been closed (or the onboarding moved on) once.
  bool _finished = false;

  /// The login is done: the onboarding moves on ([TwitchLoginPanel
  /// .onSignedIn]), or this page closes (or makes way for [TwitchLoginPanel
  /// .routeAfter]). Once, and only this page's own route: one already
  /// closed (Back, its exit still running) takes nothing else with it.
  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _signingLimit?.cancel();
    final onSignedIn = widget.onSignedIn;
    if (onSignedIn != null) {
      onSignedIn();
      return;
    }
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    final navigator = Navigator.of(context);
    final routeAfter = widget.routeAfter;
    if (!route.isCurrent) {
      navigator.removeRoute(route);
    } else if (routeAfter != null) {
      navigator.pushReplacement(
        MaterialPageRoute<void>(builder: (context) => routeAfter),
      );
    } else {
      navigator.pop();
    }
  }

  /// Twitch signed the page in without handing this login a token (the
  /// user said no): nothing was taken; the page says so while it stays.
  void _onNotSignedIn() {
    if (!mounted) return;
    _signingLimit?.cancel();
    setState(() {
      _signingIn = false;
      _loginFailed = true;
    });
  }

  void _onError(WebResourceError error) {
    // A picture or a script that failed leaves the page usable; only the
    // page itself failing is shown. Once the token is back, the page
    // underneath no longer matters.
    if (error.isForMainFrame != true || _signingIn || !mounted) return;
    // A navigation replaced by another (a quick tap, a redirect) is not a
    // failure: iOS reports it as cancelled (-999) or interrupted (102).
    if (error.errorCode == -999 || error.errorCode == 102) return;
    // iOS may not say which page failed: it is the one that was loading.
    final url = error.url == null ? null : Uri.tryParse(error.url!);
    setState(() {
      _failed = true;
      _failedPage = _pageOf(url ?? _page);
    });
  }

  void _retry() {
    _login = null;
    _loginWorked = null;
    _twitchDone = false;
    setState(() {
      _failed = false;
      _loginFailed = false;
    });
    // A new attempt: a new state, the earlier one is no longer accepted.
    unawaited(
      _auth.retryLogin(_controller).catchError((Object e) {
        debugPrint('Login page reload failed: ${e.runtimeType}');
        if (!mounted) return;
        setState(() {
          _failed = true;
          _failedPage = _pageOf(_page);
        });
      }),
    );
  }

  @override
  void dispose() {
    _signingLimit?.cancel();
    // The page is gone: its login's state is no longer accepted.
    _auth.closeLogin(_controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = motionDuration(context, const Duration(milliseconds: 220));
    Widget page =
        widget.pageBuilder?.call(_controller) ??
        WebViewWidget(controller: _controller);
    if (widget.tablet) {
      // The page is a phone page: centred in the panel, as on the board.
      page = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: page,
        ),
      );
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: OnboardingColors.web,
        border: Border(
          top: BorderSide(
            color: OnboardingColors.ring,
            width: FrostyTokens.hairlineWidth,
          ),
        ),
      ),
      child: Column(
        children: [
          _HostStrip(page: _page),
          if (_loginFailed) _LoginFailedLine(onRetry: _retry),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                page,
                AnimatedSwitcher(
                  duration: fade,
                  switchInCurve: FrostyMotion.standard,
                  child: _signingIn
                      ? _SigningIn(
                          key: const ValueKey('signing-in'),
                          accent: widget.accent,
                        )
                      : _failed
                      ? _LoadFailed(
                          key: const ValueKey('load-failed'),
                          accent: widget.accent,
                          onRetry: _retry,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The 30 dp strip naming the page: its host, with a lock when the page is
/// https; the scheme (`http://host`, `about:`) otherwise. Never the path,
/// the query or the fragment (they carry the state and the token).
class _HostStrip extends StatelessWidget {
  const _HostStrip({required this.page});

  final Uri page;

  @override
  Widget build(BuildContext context) {
    final secure = page.scheme == 'https' && page.host.isNotEmpty;
    final label = page.host.isEmpty
        ? '${page.scheme}:'
        : secure
        ? page.host
        : '${page.scheme}://${page.host}';
    return Container(
      height: 30,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: OnboardingColors.divider,
            width: FrostyTokens.hairlineWidth,
          ),
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          if (secure)
            const OnboardingGlyph(
              OnboardingGlyphKind.lock,
              size: 12,
              strokeWidth: 2,
              color: OnboardingColors.tertiary,
            ),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              semanticsLabel: secure ? 'Secure page: $label' : 'Page: $label',
              style: const TextStyle(
                fontSize: 12,
                color: OnboardingColors.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The line under the address when Twitch handed a token back that did not
/// sign the user in.
class _LoginFailedLine extends StatelessWidget {
  const _LoginFailedLine({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
        color: FrostyTokens.danger.withValues(alpha: 0.12),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Twitch did not sign you in. Try again.',
                style: TextStyle(fontSize: 13, color: OnboardingColors.text),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: OnboardingColors.text,
                minimumSize: const Size(44, 44),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Signing you in…" over the page, with the accent spinner.
class _SigningIn extends StatelessWidget {
  const _SigningIn({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: OnboardingColors.web,
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 14,
          children: [
            SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                strokeCap: StrokeCap.round,
                color: accent,
                backgroundColor: OnboardingColors.ringStrong,
                value: reduceMotionOf(context) ? 0.25 : null,
              ),
            ),
            const Text(
              'Signing you in…',
              style: TextStyle(fontSize: 14, color: OnboardingColors.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// The page could not be loaded: what happened and "Try again".
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({super.key, required this.accent, required this.onRetry});

  final Color accent;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: OnboardingColors.web,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              const Text(
                'Twitch could not be reached',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: OnboardingColors.text,
                ),
              ),
              const Text(
                'Check your connection, then try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: OnboardingColors.secondary,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 200,
                child: OnboardingButton(
                  label: 'Try again',
                  accent: accent,
                  height: 44,
                  leading: OnboardingGlyphKind.refresh,
                  onPressed: onRetry,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
