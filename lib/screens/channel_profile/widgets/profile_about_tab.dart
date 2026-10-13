import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:frosty/models/channel_profile.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:simple_icons/simple_icons.dart';

/// The icon of a social site, by Twitch's key; a link icon otherwise.
IconData socialIcon(String name) => switch (name) {
  'twitter' || 'x' => SimpleIcons.x,
  'discord' => SimpleIcons.discord,
  'youtube' => SimpleIcons.youtube,
  'instagram' => SimpleIcons.instagram,
  'tiktok' => SimpleIcons.tiktok,
  'reddit' => SimpleIcons.reddit,
  'facebook' => SimpleIcons.facebook,
  'kick' => SimpleIcons.kick,
  'patreon' => SimpleIcons.patreon,
  'github' => SimpleIcons.github,
  'threads' => SimpleIcons.threads,
  'bluesky' => SimpleIcons.bluesky,
  'steam' => SimpleIcons.steam,
  'spotify' => SimpleIcons.spotify,
  'linktree' => SimpleIcons.linktree,
  _ => Icons.link_rounded,
};

/// A channel's bio, followers, join date, social links and panels. Links
/// go through [onOpenLink].
class ProfileAboutContent extends StatelessWidget {
  const ProfileAboutContent({
    super.key,
    required this.profile,
    required this.onOpenLink,
  });

  final ChannelProfile profile;
  final ValueChanged<String> onOpenLink;

  @override
  Widget build(BuildContext context) {
    final muted = context.colorScheme.onSurfaceVariant;
    final description = profile.description?.trim();
    final followers = profile.followers;
    final joined = profile.createdAt;
    final facts = [
      if (followers != null)
        '${NumberFormat.decimalPattern().format(followers)} '
            '${followers == 1 ? 'follower' : 'followers'}',
      if (joined != null) 'Joined ${DateFormat.yMMMM().format(joined)}',
      if (profile.role == BroadcasterRole.partner) 'Partner',
      if (profile.role == BroadcasterRole.affiliate) 'Affiliate',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text(
              'About ${profile.displayName}',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (facts.isNotEmpty)
              Text(facts.join(' · '), style: TextStyle(color: muted)),
            Text(
              description == null || description.isEmpty
                  ? 'No bio yet.'
                  : description,
              style: description == null || description.isEmpty
                  ? TextStyle(color: muted)
                  : null,
            ),
          ],
        ),
        if (profile.socials.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final social in profile.socials)
                ActionChip(
                  avatar: Icon(socialIcon(social.name), size: 16),
                  label: Text(social.title),
                  tooltip: social.url,
                  onPressed: () => onOpenLink(social.url),
                ),
            ],
          ),
        if (profile.panels.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              // Two columns of Twitch's 320 px panels when there is room.
              final columns = constraints.maxWidth >= 660 ? 2 : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 16,
                children: [
                  for (final panel in profile.panels)
                    SizedBox(
                      width: width,
                      child: ProfilePanel(panel: panel, onOpenLink: onOpenLink),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

/// One About panel: its image (a link when it has one), title and Markdown
/// description. Images inside the Markdown are not loaded.
class ProfilePanel extends StatelessWidget {
  const ProfilePanel({
    super.key,
    required this.panel,
    required this.onOpenLink,
  });

  final ChannelPanel panel;
  final ValueChanged<String> onOpenLink;

  @override
  Widget build(BuildContext context) {
    final image = panel.imageUrl;
    final link = panel.linkUrl;
    final title = panel.title;
    final description = panel.description;

    Widget? picture;
    if (image != null) {
      picture = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FrostyCachedNetworkImage(
            imageUrl: image,
            fit: BoxFit.fitWidth,
            memCacheWidth: 640,
          ),
        ),
      );
      picture = Semantics(
        image: true,
        label: panel.altText ?? title ?? 'Panel image',
        link: link != null,
        child: link == null
            ? ExcludeSemantics(child: picture)
            : InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onOpenLink(link),
                child: ExcludeSemantics(child: picture),
              ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        ?picture,
        if (title != null)
          Text(
            title,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        if (description != null)
          MarkdownBody(
            data: description,
            softLineBreak: true,
            onTapLink: (_, href, _) {
              final uri = href == null ? null : Uri.tryParse(href);
              if (uri != null &&
                  (uri.scheme == 'https' || uri.scheme == 'http')) {
                onOpenLink(uri.toString());
              }
            },
            imageBuilder: (_, _, alt) =>
                alt == null || alt.isEmpty ? const SizedBox() : Text(alt),
          ),
        if (link != null && image == null)
          TextButton.icon(
            onPressed: () => onOpenLink(link),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(Uri.parse(link).host),
          ),
      ],
    );
  }
}
