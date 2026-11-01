import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:provider/provider.dart';

class ProfilePicture extends StatefulWidget {
  final String userLogin;
  final double radius;

  const ProfilePicture({super.key, required this.userLogin, this.radius = 20});

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
  late Future<String> _url = _getProfileImageUrl();

  @override
  void didUpdateWidget(ProfilePicture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userLogin != widget.userLogin) _url = _getProfileImageUrl();
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
    // Twitch serves 300 px pictures; decoded at the size drawn, they take
    // the same pixels on screen for a fraction of the memory.
    final decoded = (diameter * MediaQuery.devicePixelRatioOf(context)).ceil();
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
                  // The width alone: the height follows the picture's
                  // own proportions, as it did at full size.
                  memCacheWidth: decoded,
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
