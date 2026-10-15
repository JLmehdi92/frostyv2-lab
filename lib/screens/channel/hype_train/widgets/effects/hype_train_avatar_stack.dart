import 'package:flutter/material.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_tokens.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';

/// A channel or viewer picture; the initial when there is no (Twitch CDN)
/// picture.
class HtAvatar extends StatelessWidget {
  const HtAvatar({super.key, required this.user, this.size = HtDims.icon});

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

/// Twitch's channel avatar stack: up to [max] avatars overlapping by 6 dp,
/// then, with [joining] channels, a "+" and up to [max] of those.
class HypeTrainAvatarStack extends StatelessWidget {
  const HypeTrainAvatarStack({
    super.key,
    required this.users,
    this.joining = const [],
    this.size = HtDims.avatar,
    this.max = 6,
    this.plusColor = Colors.white,
  });

  final List<HtUser> users;
  final List<HtUser> joining;
  final double size;
  final int max;
  final Color plusColor;

  Widget _stack(List<HtUser> shown) {
    final step = size - HtDims.avatarOverlap;
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

  @override
  Widget build(BuildContext context) {
    final shown = users.take(max).toList();
    final joiners = joining.take(max).toList();
    if (shown.isEmpty && joiners.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (shown.isNotEmpty) _stack(shown),
        if (joiners.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HtDims.margin),
            child: Icon(Icons.add_rounded, size: HtDims.icon, color: plusColor),
          ),
          _stack(joiners),
        ],
      ],
    );
  }
}
