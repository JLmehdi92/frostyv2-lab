import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/shoutout_profile.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_events.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/twitch_web_page.dart';

class ShoutoutCard extends StatefulWidget {
  const ShoutoutCard({
    super.key,
    required this.notice,
    required this.load,
    required this.onViewProfile,
  });

  final ShoutoutNotice notice;
  final Future<ShoutoutProfile?> Function() load;
  final VoidCallback onViewProfile;

  static const followKey = ValueKey('shoutout-follow');
  static const profileKey = ValueKey('shoutout-profile');
  static const failedKey = ValueKey('shoutout-failed');

  @override
  State<ShoutoutCard> createState() => _ShoutoutCardState();
}

class _ShoutoutCardState extends State<ShoutoutCard> {
  late Future<ShoutoutProfile?> _profile = widget.load();

  static final _login = RegExp(r'^[a-z0-9_]{1,25}$');

  Future<void> _follow(String login, String name) async {
    await TwitchWebPage.open(
      context,
      title: name,
      url: Uri.https('www.twitch.tv', '/$login'),
    );
    if (mounted) setState(() => _profile = widget.load());
  }

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final l = context.l10n;
    return FutureBuilder<ShoutoutProfile?>(
      future: _profile,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final profile = snapshot.data;
        final name = profile?.displayName ?? widget.notice.targetName;
        final login = (profile?.login ?? widget.notice.targetLogin)
            .toLowerCase();
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
            children: [
              Text(
                l.shoutoutCardEyebrow.toUpperCase(),
                style: SheetText.section.copyWith(color: colors.secondary),
              ),
              const SizedBox(height: 10),
              Row(
                spacing: 12,
                children: [
                  _Avatar(url: profile?.profileImageUrl, name: name),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SheetText.subtitle.copyWith(color: colors.text),
                      ),
                    ),
                  ),
                ],
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (profile == null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    l.shoutoutCardFailed,
                    key: ShoutoutCard.failedKey,
                    style: SheetText.body.copyWith(color: colors.secondary),
                  ),
                )
              else ...[
                if (profile.categories.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    l.shoutoutCardRecent,
                    style: SheetText.rowDetail.copyWith(
                      color: colors.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Categories(categories: profile.categories),
                ],
                if (profile.nextStream case final next?) ...[
                  const SizedBox(height: 14),
                  Text(
                    l.shoutoutCardNext(time: _scheduleTime(next.startAt, l)),
                    style: SheetText.body.copyWith(color: colors.body),
                  ),
                  if (next.title case final title?)
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SheetText.rowDetail.copyWith(
                        color: colors.secondary,
                      ),
                    ),
                ],
              ],
              const SizedBox(height: 18),
              Row(
                spacing: 10,
                children: [
                  if (_login.hasMatch(login))
                    Expanded(
                      child: SheetButton(
                        key: ShoutoutCard.followKey,
                        label: profile?.following == true
                            ? l.channelFollowing
                            : l.channelFollow,
                        large: true,
                        expand: true,
                        tone: profile?.following == true
                            ? SheetButtonTone.text
                            : SheetButtonTone.primary,
                        onPressed: () => _follow(login, name),
                      ),
                    ),
                  Expanded(
                    child: SheetButton(
                      key: ShoutoutCard.profileKey,
                      label: l.chatUserProfile,
                      large: true,
                      expand: true,
                      tone: SheetButtonTone.text,
                      onPressed: widget.onViewProfile,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

String _scheduleTime(DateTime start, AppLocalizations l) {
  final local = start.toLocal();
  final text = DateFormat.MMMEd(dateLocaleOf(l)).add_jm().format(local);
  return l.localeName == 'fr' && local.day == 1
      ? text.replaceFirst(RegExp(r'(?<=\s)1(?=\s)'), '1er')
      : text;
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final image = url;
    return ClipOval(
      child: SizedBox.square(
        dimension: 56,
        child: image == null
            ? InitialAvatar(name: name, size: 56)
            : OnsetCachedNetworkImage(
                imageUrl: image,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => InitialAvatar(name: name, size: 56),
              ),
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({required this.categories});

  final List<ShoutoutCategory> categories;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        for (final category in categories.take(3))
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: switch (category.boxArtUrl) {
                      final url? => OnsetCachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            ColoredBox(color: colors.raised),
                      ),
                      null => ColoredBox(color: colors.raised),
                    },
                  ),
                ),
                Text(
                  category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ),
        for (var i = categories.length; i < 3; i++) const Spacer(),
      ],
    );
  }
}
