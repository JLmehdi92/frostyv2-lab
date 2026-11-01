import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:provider/provider.dart';

class ProfilePicture extends StatefulWidget {
  final String userLogin;
  final double radius;

  const ProfilePicture({super.key, required this.userLogin, this.radius = 20});

  /// How long a failed lookup waits before each new try. After the last
  /// one, it tries again when the app comes back to the front.
  static const retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  @override
  State<ProfilePicture> createState() => _ProfilePictureState();
}

class _ProfilePictureState extends State<ProfilePicture> {
  // Cache profile image URLs to avoid repeated API calls
  static final Map<String, String> _urlCache = {};
  static final Map<String, Future<String>> _pendingRequests = {};

  /// The picture's address, asked once per login shown. Asked in build, a
  /// new future each time made every rebuild of a parent cost a frame of
  /// placeholder and a rebuild more, and a request to Twitch again after a
  /// failure.
  late Future<String> _url = _lookUp();

  /// Failed lookups in a row for the current login.
  var _failures = 0;

  /// The next try after a failure.
  Timer? _retry;

  /// Up only after a failure: the app coming back to the front tries again
  /// (a network that was down while it was away).
  AppLifecycleListener? _lifecycle;

  @override
  void didUpdateWidget(ProfilePicture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userLogin != widget.userLogin) {
      _failures = 0;
      _retry?.cancel();
      _url = _lookUp();
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  /// Asks for the address; a failure is tried again after a delay (a few
  /// times, then on the app's return to the front), never on a rebuild.
  Future<String> _lookUp() {
    final future = _getProfileImageUrl();
    future.then(
      (_) {
        if (!identical(future, _url)) return;
        _failures = 0;
        _lifecycle?.dispose();
        _lifecycle = null;
      },
      onError: (Object _) {
        if (!mounted || !identical(future, _url)) return;
        _lifecycle ??= AppLifecycleListener(onResume: _retryNow);
        final delays = ProfilePicture.retryDelays;
        if (_failures >= delays.length) return;
        _retry?.cancel();
        _retry = Timer(delays[_failures++], _tryAgain);
      },
    );
    return future;
  }

  void _tryAgain() {
    if (!mounted) return;
    setState(() {
      _url = _lookUp();
    });
  }

  /// Back in front after a failure: a new try, and a new round of delays.
  void _retryNow() {
    _retry?.cancel();
    _failures = 0;
    _tryAgain();
  }

  Future<String> _getProfileImageUrl() async {
    final userLogin = widget.userLogin;

    // Return cached URL if available
    if (_urlCache.containsKey(userLogin)) {
      return _urlCache[userLogin]!;
    }

    // Return existing pending request if one is already in progress
    if (_pendingRequests.containsKey(userLogin)) {
      return _pendingRequests[userLogin]!;
    }

    // Make new request and cache it
    final future = context
        .read<TwitchApi>()
        .getUser(userLogin: userLogin)
        .then((user) => user.profileImageUrl);
    _pendingRequests[userLogin] = future;

    try {
      final url = await future;
      _urlCache[userLogin] = url;
      _pendingRequests.remove(userLogin);
      return url;
    } catch (e) {
      _pendingRequests.remove(userLogin);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final diameter = widget.radius * 2;
    final placeholderColor = Theme.of(context).colorScheme.surfaceContainer;

    return ClipOval(
      child: FutureBuilder<String>(
        future: _url,
        // A picture already known shows from the first frame.
        initialData: _urlCache[widget.userLogin],
        builder: (context, snapshot) {
          return snapshot.hasData
              ? OnsetCachedNetworkImage(
                  width: diameter,
                  height: diameter,
                  imageUrl: snapshot.data!,
                  placeholder: (context, url) =>
                      ColoredBox(color: placeholderColor),
                )
              : Container(
                  color: placeholderColor,
                  width: diameter,
                  height: diameter,
                );
        },
      ),
    );
  }
}
