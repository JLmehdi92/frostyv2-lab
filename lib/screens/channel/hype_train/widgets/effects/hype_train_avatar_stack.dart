import 'package:flutter/material.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';

/// A channel or viewer picture; the initial when there is no (Twitch CDN)
/// picture.
class HtAvatar extends StatelessWidget {
  const HtAvatar({super.key, required this.user, this.size = 24});

  final HtUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = user.profileImageUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scheme.surface, width: 1.5),
      ),
      child: ClipOval(
        child: url != null
            ? FrostyCachedNetworkImage(imageUrl: url, width: size, height: size)
            : ColoredBox(
                color: scheme.secondaryContainer,
                child: Center(
                  child: Text(
                    user.displayName.isEmpty
                        ? '?'
                        : user.displayName.characters.first.toUpperCase(),
                    style: TextStyle(
                      fontSize: size * 0.45,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Overlapping avatars (8 px), for shared trains and merges.
class HypeTrainAvatarStack extends StatelessWidget {
  const HypeTrainAvatarStack({
    super.key,
    required this.users,
    this.size = 24,
    this.max = 5,
  });

  final List<HtUser> users;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = users.take(max).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final step = size - 8;
    return SizedBox(
      width: size + step * (shown.length - 1),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            PositionedDirectional(
              start: step * i,
              child: HtAvatar(user: shown[i], size: size),
            ),
        ],
      ),
    );
  }
}
