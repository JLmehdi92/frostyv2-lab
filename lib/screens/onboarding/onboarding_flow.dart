import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/home/home.dart';
import 'package:frosty/screens/onboarding/login_webview.dart';
import 'package:frosty/screens/onboarding/onboarding_intro.dart';
import 'package:frosty/screens/onboarding/onboarding_login.dart';
import 'package:frosty/screens/onboarding/onboarding_parts.dart';
import 'package:frosty/screens/onboarding/onboarding_setup.dart';
import 'package:frosty/screens/onboarding/onboarding_welcome.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/launch/launch_intro.dart';
import 'package:frosty/widgets/launch/onset_mark.dart';
import 'package:frosty/widgets/motion/haptics.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds the Twitch page of the Log in step: [onSignedIn] moves on to
/// Setup, [onTokenCaptured] is given the login in flight.
typedef LoginPanelBuilder =
    Widget Function(
      BuildContext context,
      VoidCallback onSignedIn,
      ValueChanged<Future<void>> onTokenCaptured,
    );

/// The onboarding's steps. The Twitch page belongs to Log in (the progress
/// counts four steps).
enum OnboardingStep {
  intro,
  login,
  web,
  setup,
  welcome;

  /// Its place in the four-segment progress.
  int get progress => switch (this) {
    intro => 0,
    login || web => 1,
    setup => 2,
    welcome => 3,
  };

  /// Where back leads, if anywhere (Setup goes back to Log in, not to the
  /// Twitch page).
  OnboardingStep? get back => switch (this) {
    intro => null,
    login => intro,
    web => login,
    setup => login,
    welcome => setup,
  };
}

/// Whether Firebase collects, for the "Share crash logs and analytics"
/// setting [shared]: never in a debug build (as `main.dart` sets it), so
/// development never pollutes the data.
bool firebaseCollectionFor(bool shared) => shared && !kDebugMode;

/// Turns the Firebase collection on or off, as the setting says (see
/// [firebaseCollectionFor]).
void setFirebaseCollection(bool shared) {
  final enabled = firebaseCollectionFor(shared);
  FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
  FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
  FirebasePerformance.instance.setPerformanceCollectionEnabled(enabled);
}

/// The first launch (boards Onboarding, OnboardingTablette, OnboardingEtapes):
/// Intro, Log in (with the Twitch page), Setup, Welcome, then the app.
///
/// - It continues the launch intro: its first frame is the intro's last
///   (the same tile at the same place, the same black, the name
///   underlined), then the live mosaic and the text come in around it. On a
///   tablet the tile slides from there into the brand pane on the left (on
///   top in portrait), where it stays for every step.
/// - Always drawn in the intro's black; the accent picked in Setup applies
///   at once, the theme only to Setup's preview (and to the app after).
/// - Back (the bar's, or Android's) goes one step back; on the Intro it
///   leaves the app. Steps slide 32 dp and fade, the next one's parts rise
///   in; under reduce motion, short fades only.
/// - Reaching Welcome marks the first run done (`first_run`), as "Let's go!"
///   does; "Let's go!" sends the tile up into the shell's header like the
///   end of the launch intro ([LaunchIntro.land]) and opens the app.
/// - A phone is held in portrait; a tablet turns freely.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    this.loadLiveStreams,
    this.loginPanelBuilder,
    this.onShareCrashLogsChanged,
    this.homeBuilder,
  });

  /// The live channels of the mosaic and the preview; Twitch's top streams
  /// by default.
  @visibleForTesting
  final Future<List<StreamTwitch>> Function()? loadLiveStreams;

  /// The Twitch page; [TwitchLoginPanel] by default.
  @visibleForTesting
  final LoginPanelBuilder? loginPanelBuilder;

  /// What turns crash reports on or off; [setFirebaseCollection] by default.
  @visibleForTesting
  final ValueChanged<bool>? onShareCrashLogsChanged;

  /// The app opened at the end; [Home] by default.
  @visibleForTesting
  final WidgetBuilder? homeBuilder;

  /// How long a step's change and the rise of its parts take.
  static const stepDuration = Duration(milliseconds: 730);

  /// The first appearance after the launch intro.
  static const handDuration = Duration(milliseconds: 1460);

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

/// The step's slide in (360 ms) and out (240 ms), within [stepDuration].
const _enterShare = 360 / 730;
const _leaveShare = 240 / 730;
const _leaveCurve = Cubic(0.4, 0, 1, 1);

class _OnboardingFlowState extends State<OnboardingFlow>
    with TickerProviderStateMixin {
  var _step = OnboardingStep.intro;
  OnboardingStep? _previous;
  var _forward = true;

  /// Whether the step on screen came in going forward (its parts rise in).
  var _rising = false;

  /// The Intro has not been left yet: its parts still come in with the
  /// hand-over from the launch intro.
  var _introFresh = true;

  late final AnimationController _switch = AnimationController(
    vsync: this,
    duration: OnboardingFlow.stepDuration,
    value: 1,
  );

  /// The hand-over from the launch intro: the tile into place, the mosaic,
  /// the bar and the Intro's text.
  late final AnimationController _hand = AnimationController(
    vsync: this,
    duration: OnboardingFlow.handDuration,
  );
  var _handStarted = false;

  /// Where the launch intro left the tile, when it held for the onboarding.
  Rect? _launchTile;

  var _reduce = false;
  bool? _phone;
  String? _version;
  List<StreamTwitch> _streams = const [];
  var _login = OnboardingLogin.none;
  var _finishing = false;

  late final SettingsStore _settings = context.read<SettingsStore>();
  late final AuthStore _auth = context.read<AuthStore>();

  @override
  void initState() {
    super.initState();
    _switch.addStatusListener((status) {
      if (status == AnimationStatus.completed && _previous != null) {
        setState(() => _previous = null);
      }
    });
    if (LaunchIntro.running.value) {
      LaunchIntro.running.addListener(_onIntro);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startHand());
    }
    unawaited(_loadVersion());
    unawaited(_loadStreams());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = reduceMotionOf(context);
    final phone = !isLargeScreenSize(MediaQuery.sizeOf(context));
    if (phone != _phone) {
      _phone = phone;
      _holdOrientation();
    }
    final covered = ModalRoute.of(context)?.secondaryAnimation;
    if (covered != _covered) {
      _covered?.removeStatusListener(_onCovered);
      _covered = covered?..addStatusListener(_onCovered);
    }
  }

  /// What the page above the onboarding does (a deep-linked channel), seen
  /// from below: its animation over this route.
  Animation<double>? _covered;

  /// A page over the onboarding (a deep-linked player) may have turned the
  /// orientation free when it closed: once the onboarding shows again, a
  /// phone is held in portrait again. After the next frames, because that
  /// page lets the orientation go when it is disposed, which comes after
  /// its closing animation.
  void _onCovered(AnimationStatus status) {
    if (status != AnimationStatus.dismissed) return;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        WidgetsBinding.instance
          ..addPostFrameCallback((_) {
            if (mounted && ModalRoute.of(context)?.isCurrent == true) {
              _holdOrientation();
            }
          })
          ..ensureVisualUpdate();
      })
      ..ensureVisualUpdate();
  }

  /// A phone is held in portrait, a tablet turns freely.
  void _holdOrientation() {
    SystemChrome.setPreferredOrientations(
      _phone ?? true
          ? const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
          : const [],
    );
  }

  void _onIntro() {
    if (LaunchIntro.running.value) return;
    LaunchIntro.running.removeListener(_onIntro);
    _launchTile = LaunchIntro.restingTile.value;
    _startHand();
  }

  void _startHand() {
    if (_handStarted || !mounted) return;
    _handStarted = true;
    _hand.duration = _reduce
        ? FrostyMotion.reducedFade
        : OnboardingFlow.handDuration;
    setState(() {});
    _hand.forward();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = 'v${info.version} (${info.buildNumber})');
    } catch (e) {
      debugPrint('Onboarding: no version: ${e.runtimeType}');
    }
  }

  Future<void> _loadStreams() async {
    if (!_settings.showThumbnails) return;
    try {
      final load =
          widget.loadLiveStreams ??
          () async =>
              (await context.read<TwitchApi>().getTopStreams(quiet: true)).data;
      final streams = await load();
      if (!mounted || streams.isEmpty) return;
      setState(() => _streams = streams.take(24).toList());
    } catch (e) {
      // The mosaic keeps its stand-ins.
      debugPrint('Onboarding: no live pictures: ${e.runtimeType}');
    }
  }

  @override
  void dispose() {
    LaunchIntro.running.removeListener(_onIntro);
    _covered?.removeStatusListener(_onCovered);
    _switch.dispose();
    _hand.dispose();
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  void _go(OnboardingStep to, {required bool forward}) {
    if (to == _step || _finishing) return;
    Haptics.selection();
    if (_step == OnboardingStep.intro) _introFresh = false;
    if (to == OnboardingStep.welcome) unawaited(_markFirstRunDone());
    setState(() {
      _previous = _step;
      _step = to;
      _forward = forward;
      _rising = forward && !_reduce;
    });
    _switch.duration = _reduce
        ? FrostyMotion.reducedFade
        : OnboardingFlow.stepDuration;
    _switch.forward(from: 0);
  }

  void _back() {
    final back = _step.back;
    if (back != null) _go(back, forward: false);
  }

  /// Twitch handed a token back: Setup says "Signing you in…" until the
  /// login ends, then who is logged in, or that it failed.
  void _onTokenCaptured(Future<void> login) {
    if (!mounted) return;
    setState(() => _login = OnboardingLogin.pending);
    login.whenComplete(() {
      if (!mounted || _login != OnboardingLogin.pending) return;
      setState(
        () => _login = _auth.isLoggedIn
            ? OnboardingLogin.none
            : OnboardingLogin.failed,
      );
    }).ignore();
  }

  Future<void> _markFirstRunDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('first_run', false);
    } catch (e) {
      debugPrint('Onboarding: first run not saved: ${e.runtimeType}');
    }
  }

  void _finish(_Geometry geometry) {
    if (_finishing) return;
    setState(() => _finishing = true);
    final navigator = Navigator.of(context);
    final home = widget.homeBuilder ?? (context) => const Home();
    // Already written when Welcome opened; written again (without waiting
    // for it) in case that write failed.
    unawaited(_markFirstRunDone());

    // The onboarding's own route is swapped for the app, in place: a page
    // opened over it meanwhile (a link) stays on top.
    final route = ModalRoute.of(context);
    final played = LaunchIntro.land(
      from: Rect.fromCenter(
        center: geometry.tileCenter,
        width: OnsetMark.designSize,
        height: OnsetMark.designSize,
      ),
      appear: !geometry.tablet,
      onCovered: () {
        final next = PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, _, _) => home(context),
        );
        if (route != null && route.isActive) {
          navigator.replace(oldRoute: route, newRoute: next);
        } else {
          navigator.pushAndRemoveUntil(next, (_) => false);
        }
      },
    );
    if (played) return;
    final fade = motionDuration(context, const Duration(milliseconds: 280));
    unawaited(
      navigator.pushAndRemoveUntil(
        PageRouteBuilder<void>(
          transitionDuration: fade,
          reverseTransitionDuration: fade,
          pageBuilder: (context, _, _) => home(context),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
        (_) => false,
      ),
    );
  }

  /// [value] of the hand-over, between [startMs] and [endMs].
  double _handSpan(
    double startMs,
    double endMs, [
    Curve curve = Curves.linear,
  ]) {
    if (_reduce) return _hand.value;
    final total = OnboardingFlow.handDuration.inMilliseconds;
    final t = ((_hand.value * total - startMs) / (endMs - startMs)).clamp(
      0.0,
      1.0,
    );
    return curve.transform(t);
  }

  /// How [step] shows now: its opacity and sideways offset.
  (double, double) _stepMotion(OnboardingStep step) {
    final v = _switch.value;
    final switching = _previous != null;
    if (step == _step) {
      if (!switching) return (1, 0);
      if (_reduce) return (v, 0);
      final p = FrostyMotion.standard.transform((v / _enterShare).clamp(0, 1));
      return (p, (_forward ? 32 : -32) * (1 - p));
    }
    if (step == _previous && switching) {
      if (_reduce) return (1 - v, 0);
      final q = _leaveCurve.transform((v / _leaveShare).clamp(0, 1));
      return (1 - q, (_forward ? -32 : 32) * q);
    }
    return (0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final accent = Color(_settings.accentColor);
        return Theme(
          data: FrostyThemes(colorSchemeSeed: accent).dark,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: onboardingBars,
            child: PopScope(
              canPop: _step == OnboardingStep.intro && !_finishing,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && !_finishing) _back();
              },
              child: Material(
                color: OnboardingColors.ground,
                child: _layout(context, accent),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _layout(BuildContext context, Color accent) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final geometry = _Geometry.of(
      size,
      padding,
      nameHeight:
          MediaQuery.textScalerOf(context).scale(
                OnsetWordmark.letterSize(tablet: isLargeScreenSize(size)),
              ) *
              1.2 +
          14,
    );
    final tablet = geometry.tablet;

    // What does not change from frame to frame is built once here, so the
    // animation below only moves it (an identical widget is not rebuilt).
    final mosaicView = OnboardingMosaic(
      streams: _streams,
      tablet: tablet,
      landscape: geometry.landscape,
    );
    final versionView = OnboardingVersion(version: _version);
    final tileView = OnsetMarkTile(
      glow: [
        BoxShadow(
          color: FrostyTokens.accent.withValues(alpha: 0.25),
          blurRadius: tablet ? 48 : 40,
        ),
      ],
    );
    final nameView = Center(child: OnsetWordmark(tablet: tablet));
    final stepLayout = OnboardingStepLayout(
      tablet: tablet,
      padding: geometry.stepPadding,
    );
    Widget content(OnboardingStep step) {
      final view = _stepContent(step, geometry, stepLayout, accent);
      if (step == OnboardingStep.intro && _introFresh) {
        return _reduce
            ? view
            : StepEntrance(
                animation: _hand,
                delays: tablet ? _tabletIntroDelays : _phoneIntroDelays,
                total: OnboardingFlow.handDuration,
                child: view,
              );
      }
      if (step == _step && _rising) {
        return StepEntrance(
          animation: _switch,
          delays: StepEntrance.stepDelays,
          total: OnboardingFlow.stepDuration,
          child: view,
        );
      }
      return view;
    }

    final current = content(_step);
    final previous = _previous == null ? null : content(_previous!);
    final barView = Padding(
      padding: EdgeInsets.symmetric(horizontal: geometry.barSide),
      child: _TopBar(
        step: _step,
        tablet: tablet,
        accent: accent,
        onBack: _back,
      ),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_switch, _hand]),
      builder: (context, _) {
        // The hand-over: the tile from where the intro left it to its
        // place.
        final slide = _reduce
            ? 1.0
            : _handSpan(240, 880, FrostyMotion.standard);
        final launch =
            _launchTile ??
            Rect.fromCenter(
              center: _reduce ? geometry.tileCenter : size.center(Offset.zero),
              width: OnsetMark.designSize,
              height: OnsetMark.designSize,
            );
        final tileCenter = Offset.lerp(
          launch.center,
          geometry.tileCenter,
          slide,
        )!;
        final tileScale = lerpDouble(
          launch.width / OnsetMark.designSize,
          1,
          slide,
        )!;
        final nameCenterX = lerpDouble(
          size.width / 2,
          geometry.tileCenter.dx,
          slide,
        )!;
        final mosaic = _handSpan(
          tablet ? 560 : 280,
          tablet ? 1460 : 1180,
          FrostyMotion.standard,
        );
        final bar = _handSpan(tablet ? 860 : 600, tablet ? 1460 : 1200);

        // A phone shows the brand on the Intro only; it leaves with it.
        final (introOpacity, introShift) = _stepMotion(OnboardingStep.intro);
        final brandOpacity = tablet ? 1.0 : introOpacity;
        final brandShift = tablet ? 0.0 : introShift;
        final nameTop =
            tileCenter.dy +
            OnsetMark.designSize / 2 +
            OnsetWordmark.gapBelowTile(tablet: tablet);

        final brand = Visibility(
          visible: brandOpacity > 0,
          maintainState: true,
          child: Opacity(
            opacity: brandOpacity.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(brandShift, 0),
              child: Stack(
                children: [
                  Positioned.fromRect(
                    rect: geometry.mosaic,
                    child: Opacity(opacity: mosaic, child: mosaicView),
                  ),
                  if (tablet) ...[
                    Positioned.fromRect(
                      rect: geometry.divider,
                      child: Opacity(
                        opacity: mosaic,
                        child: const ColoredBox(color: OnboardingColors.ring),
                      ),
                    ),
                    Positioned(
                      left: geometry.brand.left + 40,
                      bottom:
                          size.height -
                          geometry.brand.bottom +
                          (geometry.landscape ? 32 + padding.bottom : 20),
                      child: Opacity(opacity: mosaic, child: versionView),
                    ),
                  ],
                  Positioned(
                    left: tileCenter.dx - OnsetMark.designSize / 2,
                    top: tileCenter.dy - OnsetMark.designSize / 2,
                    width: OnsetMark.designSize,
                    height: OnsetMark.designSize,
                    child: Transform.scale(scale: tileScale, child: tileView),
                  ),
                  Positioned(
                    left: nameCenterX - 160,
                    width: 320,
                    top: nameTop,
                    child: nameView,
                  ),
                ],
              ),
            ),
          ),
        );

        Widget stepView(OnboardingStep step, Widget view) {
          final (opacity, shift) = _stepMotion(step);
          final leaving = step != _step;
          if (step == OnboardingStep.intro && _introFresh && _reduce) {
            view = Opacity(opacity: _hand.value, child: view);
          }
          return KeyedSubtree(
            key: ValueKey(step),
            child: IgnorePointer(
              ignoring: leaving,
              child: ExcludeSemantics(
                excluding: leaving,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(shift, 0),
                    child: view,
                  ),
                ),
              ),
            ),
          );
        }

        final steps = Positioned.fromRect(
          rect: geometry.steps,
          child: ClipRect(
            clipBehavior: tablet ? Clip.hardEdge : Clip.none,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_previous case final step? when previous != null)
                  stepView(step, previous),
                stepView(_step, current),
              ],
            ),
          ),
        );

        final topBar = Positioned.fromRect(
          rect: geometry.bar,
          child: Opacity(opacity: bar, child: barView),
        );

        return Stack(children: [brand, steps, topBar]);
      },
    );
  }

  static const _phoneIntroDelays = [
    Duration.zero,
    Duration(milliseconds: 340),
    Duration(milliseconds: 420),
    Duration(milliseconds: 500),
    Duration(milliseconds: 560),
  ];

  static const _tabletIntroDelays = [
    Duration.zero,
    Duration(milliseconds: 620),
    Duration(milliseconds: 690),
    Duration(milliseconds: 760),
    Duration(milliseconds: 830),
  ];

  Widget _stepContent(
    OnboardingStep step,
    _Geometry geometry,
    OnboardingStepLayout layout,
    Color accent,
  ) {
    final tablet = geometry.tablet;
    void next() => _go(OnboardingStep.login, forward: true);
    switch (step) {
      case OnboardingStep.intro:
        if (tablet) {
          return OnboardingIntroTablet(
            layout: layout,
            accent: accent,
            onNext: next,
          );
        }
        return OnboardingIntroPhone(
          nameBottom: geometry.nameBottom,
          version: _version,
          accent: accent,
          bottomInset: geometry.bottomInset,
          onNext: next,
        );
      case OnboardingStep.login:
        return OnboardingLoginStep(
          layout: layout,
          accent: accent,
          onConnect: () => _go(OnboardingStep.web, forward: true),
          onSkip: () => _go(OnboardingStep.setup, forward: true),
        );
      case OnboardingStep.web:
        void signedIn() {
          if (mounted && _step == OnboardingStep.web) {
            _go(OnboardingStep.setup, forward: true);
          }
        }
        final panel =
            widget.loginPanelBuilder?.call(
              context,
              signedIn,
              _onTokenCaptured,
            ) ??
            TwitchLoginPanel(
              tablet: tablet,
              accent: accent,
              onSignedIn: signedIn,
              onTokenCaptured: _onTokenCaptured,
            );
        // The page shrinks above the keyboard, so the Twitch fields stay
        // in view.
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        return Padding(
          padding: EdgeInsets.only(top: geometry.webTop),
          child: ColoredBox(
            color: OnboardingColors.web,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: keyboard > geometry.bottomInset
                    ? keyboard
                    : geometry.bottomInset,
              ),
              child: panel,
            ),
          ),
        );
      case OnboardingStep.setup:
        return OnboardingSetupStep(
          layout: layout,
          accent: accent,
          settings: _settings,
          auth: _auth,
          login: _login,
          preview: _streams.isEmpty ? null : _streams.first,
          onShareCrashLogsChanged:
              widget.onShareCrashLogsChanged ?? setFirebaseCollection,
          onNext: () => _go(OnboardingStep.welcome, forward: true),
        );
      case OnboardingStep.welcome:
        return OnboardingWelcomeStep(
          layout: layout,
          accent: accent,
          onFinish: () => _finish(geometry),
        );
    }
  }
}

/// Where everything goes, for a window of [size] with system [padding].
class _Geometry {
  const _Geometry({
    required this.tablet,
    required this.landscape,
    required this.brand,
    required this.mosaic,
    required this.divider,
    required this.steps,
    required this.bar,
    required this.barSide,
    required this.stepPadding,
    required this.tileCenter,
    required this.nameBottom,
    required this.webTop,
    required this.bottomInset,
  });

  factory _Geometry.of(
    Size size,
    EdgeInsets padding, {
    required double nameHeight,
  }) {
    final w = size.width;
    final h = size.height;
    final tablet = isLargeScreenSize(size);
    const half = OnsetMark.designSize / 2;
    if (!tablet) {
      // The tile in the middle (where the launch intro left it), raised on
      // a short window so the description, the version and "Next" fit.
      final gap = OnsetWordmark.gapBelowTile(tablet: false);
      final lowest =
          h -
          padding.bottom -
          OnboardingIntroPhone.neededBelowName -
          nameHeight -
          gap -
          half;
      final highest = padding.top + 56 + half + 8;
      final cy = (h / 2).clamp(highest, lowest < highest ? highest : lowest);
      final full = Offset.zero & size;
      return _Geometry(
        tablet: false,
        landscape: false,
        brand: full,
        mosaic: Rect.fromLTWH(0, 0, w, h * 0.52 < 440 ? h * 0.52 : 440),
        divider: Rect.zero,
        steps: full,
        bar: Rect.fromLTWH(0, padding.top, w, 56),
        barSide: 6,
        stepPadding: EdgeInsets.fromLTRB(
          24,
          padding.top + 68,
          24,
          padding.bottom + 20,
        ),
        tileCenter: Offset(w / 2, cy),
        nameBottom: cy + half + gap + nameHeight,
        webTop: padding.top + 56,
        bottomInset: padding.bottom,
      );
    }
    final landscape = w > h;
    if (landscape) {
      final pane = (w * 0.4375).clamp(360.0, 560.0);
      final steps = Rect.fromLTWH(pane, 0, w - pane, h);
      final side = steps.width >= 600 ? 80.0 : 48.0;
      return _Geometry(
        tablet: true,
        landscape: true,
        brand: Rect.fromLTWH(0, 0, pane, h),
        mosaic: Rect.fromLTWH(0, 0, pane, h),
        divider: Rect.fromLTWH(pane, 0, FrostyTokens.hairlineWidth, h),
        steps: steps,
        bar: Rect.fromLTWH(pane, padding.top, w - pane, 72),
        barSide: 28,
        stepPadding: EdgeInsets.fromLTRB(
          side,
          padding.top + 104,
          side,
          padding.bottom + 40,
        ),
        tileCenter: Offset(pane / 2, h / 2),
        nameBottom: 0,
        webTop: padding.top + 72,
        bottomInset: padding.bottom,
      );
    }
    final pane = (h * 0.36).clamp(320.0, 480.0);
    final gap = OnsetWordmark.gapBelowTile(tablet: true);
    final group = OnsetMark.designSize + gap + nameHeight;
    final groupTop = (padding.top + pane - group) / 2;
    return _Geometry(
      tablet: true,
      landscape: false,
      brand: Rect.fromLTWH(0, 0, w, pane),
      mosaic: Rect.fromLTWH(0, 0, w, pane),
      divider: Rect.fromLTWH(0, pane, w, FrostyTokens.hairlineWidth),
      steps: Rect.fromLTWH(0, pane, w, h - pane),
      bar: Rect.fromLTWH(0, pane, w, 72),
      barSide: 28,
      stepPadding: EdgeInsets.fromLTRB(64, 104, 64, padding.bottom + 40),
      tileCenter: Offset(w / 2, groupTop + half),
      nameBottom: 0,
      webTop: 72,
      bottomInset: padding.bottom,
    );
  }

  final bool tablet;
  final bool landscape;

  /// The tablet's brand pane (the whole window on a phone).
  final Rect brand;
  final Rect mosaic;

  /// The tablet's 0.5 dp line between the panes.
  final Rect divider;

  /// Where the steps go.
  final Rect steps;
  final Rect bar;
  final double barSide;
  final EdgeInsets stepPadding;

  /// The tile at rest.
  final Offset tileCenter;

  /// A phone's: where the name's underline ends.
  final double nameBottom;

  /// The Twitch page's top, in the steps' coordinates.
  final double webTop;
  final double bottomInset;
}

/// The bar: back (not on the Intro), the four-segment progress (the title
/// on the Twitch page), the "?" help on the Twitch page.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.step,
    required this.tablet,
    required this.accent,
    required this.onBack,
  });

  final OnboardingStep step;
  final bool tablet;
  final Color accent;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final hasBack = step.back != null;
    if (step == OnboardingStep.web) {
      return LoginBar(tablet: tablet, inOnboarding: true, onBack: onBack);
    }
    return Row(
      children: [
        IgnorePointer(
          ignoring: !hasBack,
          child: ExcludeSemantics(
            excluding: !hasBack,
            child: AnimatedOpacity(
              duration: motionDuration(
                context,
                const Duration(milliseconds: 200),
              ),
              opacity: hasBack ? 1 : 0,
              child: OnboardingIconButton(
                glyph: OnboardingGlyphKind.chevronLeft,
                tooltip: 'Back',
                onPressed: onBack,
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: _Progress(
              index: step.progress,
              accent: accent,
              tablet: tablet,
            ),
          ),
        ),
        const SizedBox(width: 44, height: 44),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({
    required this.index,
    required this.accent,
    required this.tablet,
  });

  final int index;
  final Color accent;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final width = motionDuration(context, const Duration(milliseconds: 360));
    return Semantics(
      label: 'Onboarding progress',
      value: 'Step ${index + 1} of 4',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: tablet ? 8 : 6,
        children: [
          for (var i = 0; i < 4; i++)
            AnimatedContainer(
              duration: width,
              curve: FrostyMotion.standard,
              width: i == index ? 28 : 14,
              height: 4,
              decoration: BoxDecoration(
                color: i == index
                    ? accent
                    : i < index
                    ? OnboardingColors.segmentDone
                    : OnboardingColors.segmentTodo,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
