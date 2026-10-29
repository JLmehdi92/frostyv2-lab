import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/utils/https_url.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/profile_picture.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:provider/provider.dart';

/// A channel's round picture in the raid cards: [url] when Twitch gave
/// one on its image host, else looked up by [login], else its initial.
class RaidAvatar extends StatelessWidget {
  const RaidAvatar({
    super.key,
    required this.name,
    this.url,
    this.login,
    this.size = 28,
  });

  final String name;
  final String? url;
  final String? login;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = InitialAvatar(name: name, size: size);
    final url = twitchImageOrNull(this.url);
    final Widget picture;
    if (url != null) {
      picture = ClipOval(
        child: OnsetCachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, _) => initial,
          errorWidget: (_, _, _) => initial,
        ),
      );
    } else if (login != null &&
        Provider.of<TwitchApi?>(context, listen: false) != null) {
      picture = ProfilePicture(userLogin: login!, radius: size / 2);
    } else {
      picture = initial;
    }
    return ExcludeSemantics(
      child: SizedBox.square(dimension: size, child: picture),
    );
  }
}
