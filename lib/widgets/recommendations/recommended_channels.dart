import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/apis/twitch_social_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/recommended_channel.dart';
import 'package:onset/screens/channel/channel.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/haptics.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:provider/provider.dart';

class Recommendations {
  const Recommendations({required this.service, required this.token});

  final TwitchSocialService service;
  final String? token;

  static Recommendations? of(BuildContext context) {
    final service = context.read<TwitchSocialService?>();
    if (service == null) return null;
    final token = context.read<AuthStore?>()?.twitchWebToken;
    return Recommendations(
      service: service,
      token: token == null || token.isEmpty ? null : token,
    );
  }

  Future<List<RecommendedChannel>?> load(
    RecommendationSection section, {
    String? channelLogin,
  }) => service.recommendations(
    section: section,
    channelLogin: channelLogin,
    authToken: token,
  );

  Future<ViewerActionOutcome> tellTwitch(
    RecommendedChannel channel,
    NotInterestedReason reason,
  ) {
    final token = this.token;
    if (token == null) return Future.value(ViewerActionOutcome.signedOut);
    return service.notInterested(
      channelId: channel.userId,
      reason: reason,
      authToken: token,
    );
  }
}

Future<void> openRecommendedChannel(
  BuildContext context,
  RecommendedChannel channel, {
  bool replace = false,
}) {
  final route = MaterialPageRoute<void>(
    settings: const RouteSettings(name: VideoChat.routeName),
    builder: (context) => VideoChat(
      userId: channel.userId,
      userName: channel.displayName,
      userLogin: channel.login,
    ),
  );
  return replace
      ? Navigator.pushReplacement(context, route)
      : Navigator.push(context, route);
}

Future<NotInterestedReason?> pickNotInterestedReason(
  BuildContext context, {
  required String name,
}) {
  final l = context.l10n;
  return showOnsetSheet<NotInterestedReason>(
    context: context,
    builder: (sheetContext) => ListView(
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Semantics(
            header: true,
            child: Text(
              l.notInterestedTitle(name: name),
              style: SheetText.subtitle.copyWith(
                color: SheetColors.of(sheetContext).text,
              ),
            ),
          ),
        ),
        for (final reason in NotInterestedReason.values)
          SheetRow(
            key: ValueKey('not-interested-${reason.name}'),
            label: notInterestedReasonLabel(l, reason),
            glyph: reason == NotInterestedReason.offensive
                ? SheetGlyphKind.flag
                : SheetGlyphKind.close,
            onTap: () => Navigator.pop(sheetContext, reason),
          ),
      ],
    ),
  );
}

String notInterestedReasonLabel(AppLocalizations l, NotInterestedReason r) =>
    switch (r) {
      NotInterestedReason.notInterested => l.notInterestedReasonNotInterested,
      NotInterestedReason.offensive => l.notInterestedReasonOffensive,
      NotInterestedReason.other => l.notInterestedReasonOther,
    };

Future<void> markNotInterested(
  BuildContext context,
  RecommendedChannel channel, {
  required Future<ViewerActionOutcome> Function(
    RecommendedChannel channel,
    NotInterestedReason reason,
  )
  tellTwitch,
}) async {
  final settings = context.read<SettingsStore>();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l = context.l10n;
  final reason = await pickNotInterestedReason(
    context,
    name: channel.displayName,
  );
  if (reason == null) return;
  Haptics.light();
  settings.markNotInterested(channel.userId, channel.displayName);
  final outcome = await tellTwitch(channel, reason);
  final recorded = outcome == ViewerActionOutcome.done;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          recorded || outcome == ViewerActionOutcome.signedOut
              ? l.notInterestedDone(name: channel.displayName)
              : l.notInterestedOnlyHere(name: channel.displayName),
        ),
        action: SnackBarAction(
          label: l.commonUndo,
          onPressed: () => settings.clearNotInterested(channel.userId),
        ),
      ),
    );
}

class RecommendationsShelf extends StatefulWidget {
  const RecommendationsShelf({super.key, this.load});

  static const shelfKey = ValueKey('recommendations-shelf');

  final Future<List<RecommendedChannel>?> Function()? load;

  @override
  State<RecommendationsShelf> createState() => _RecommendationsShelfState();
}

class _RecommendationsShelfState extends State<RecommendationsShelf> {
  List<RecommendedChannel>? _channels;
  Recommendations? _recommendations;

  @override
  void initState() {
    super.initState();
    _recommendations = Recommendations.of(context);
    unawaited(_load());
  }

  Future<void> _load() async {
    final load =
        widget.load ??
        switch (_recommendations) {
          final r? => () => r.load(RecommendationSection.recommended),
          null => null,
        };
    if (load == null) return;
    final channels = await load();
    if (!mounted) return;
    setState(() => _channels = channels);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsStore?>();
    if (settings == null || _channels == null) return const SizedBox.shrink();
    return Observer(
      builder: (context) {
        final hidden = settings.notInterestedChannels;
        final channels = [
          for (final channel in _channels ?? const <RecommendedChannel>[])
            if (!hidden.containsKey(channel.userId)) channel,
        ];
        if (channels.isEmpty) return const SizedBox.shrink();
        final padding = MediaQuery.paddingOf(context);
        final large = context.isLargeScreen;
        final gutter = large
            ? OnsetSpacing.gutterTablet
            : OnsetSpacing.gutterPhone;
        final tileWidth = large ? 132.0 : 112.0;
        final scale = MediaQuery.textScalerOf(context).scale(1);
        return Padding(
          key: RecommendationsShelf.shelfKey,
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: gutter + padding.left,
                  right: gutter + padding.right,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FeedSectionTitle(context.l10n.recommendationsTitle),
                ),
              ),
              SizedBox(
                height: tileWidth * 0.62 + 66 * scale,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.only(
                    left: gutter + padding.left,
                    right: gutter + padding.right,
                  ),
                  itemCount: channels.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final channel = channels[index];
                    return RecommendedChannelTile(
                      channel: channel,
                      width: tileWidth,
                      onTap: () =>
                          unawaited(openRecommendedChannel(context, channel)),
                      onNotInterested: switch (_recommendations) {
                        final r? => () => unawaited(
                          markNotInterested(
                            context,
                            channel,
                            tellTwitch: r.tellTwitch,
                          ),
                        ),
                        null => null,
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RecommendedChannelTile extends StatelessWidget {
  const RecommendedChannelTile({
    super.key,
    required this.channel,
    required this.width,
    required this.onTap,
    this.onNotInterested,
  });

  final RecommendedChannel channel;
  final double width;
  final VoidCallback onTap;
  final VoidCallback? onNotInterested;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final l = context.l10n;
    final name = getReadableName(channel.displayName, channel.login);
    final avatar = width * 0.62;
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        onLongPressHint: onNotInterested == null
            ? null
            : l.liveFeedNotInterested,
        child: PressScale(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onLongPress: onNotInterested,
            child: Column(
              spacing: 4,
              children: [
                ClipOval(
                  child: SizedBox.square(
                    dimension: avatar,
                    child: switch (channel.avatarUrl) {
                      final url? => OnsetCachedNetworkImage(
                        imageUrl: url,
                        width: avatar,
                        height: avatar,
                        fit: BoxFit.cover,
                      ),
                      null => InitialAvatar(name: name, size: avatar),
                    },
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
                Text(
                  channel.category ??
                      l.streamViewers(count: channel.viewers ?? 0),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 12,
                    color: colors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SimilarChannelsSheet extends StatefulWidget {
  const SimilarChannelsSheet({
    super.key,
    required this.name,
    required this.load,
    required this.onOpen,
    this.onNotInterested,
  });

  final String name;
  final Future<List<RecommendedChannel>?> Function() load;
  final void Function(RecommendedChannel channel) onOpen;
  final void Function(RecommendedChannel channel)? onNotInterested;

  static ValueKey<String> rowKey(String id) => ValueKey('similar-$id');

  @override
  State<SimilarChannelsSheet> createState() => _SimilarChannelsSheetState();
}

class _SimilarChannelsSheetState extends State<SimilarChannelsSheet> {
  List<RecommendedChannel>? _channels;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final channels = await widget.load();
    if (!mounted) return;
    setState(() {
      _channels = channels;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    final settings = context.read<SettingsStore>();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Observer(
        builder: (context) {
          final hidden = settings.notInterestedChannels;
          final channels = [
            for (final channel in _channels ?? const <RecommendedChannel>[])
              if (!hidden.containsKey(channel.userId)) channel,
          ];
          return ListView(
            shrinkWrap: true,
            primary: false,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    l.recommendationsSimilarTitle(name: widget.name),
                    style: SheetText.subtitle.copyWith(color: colors.text),
                  ),
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
              else if (channels.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    l.recommendationsEmpty,
                    style: SheetText.rowDetail.copyWith(
                      color: colors.secondary,
                    ),
                  ),
                )
              else
                for (final channel in channels) _row(context, channel),
            ],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, RecommendedChannel channel) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    final name = getReadableName(channel.displayName, channel.login);
    final detail = [
      ?channel.category,
      if (channel.viewers case final viewers?) l.streamViewers(count: viewers),
    ].join(' · ');
    final onNotInterested = widget.onNotInterested;
    return InkWell(
      key: SimilarChannelsSheet.rowKey(channel.userId),
      onTap: () => widget.onOpen(channel),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          spacing: 14,
          children: [
            ClipOval(
              child: SizedBox.square(
                dimension: 40,
                child: switch (channel.avatarUrl) {
                  final url? => OnsetCachedNetworkImage(
                    imageUrl: url,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                  null => InitialAvatar(name: name, size: 40),
                },
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SheetText.row.copyWith(color: colors.text),
                  ),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SheetText.rowDetail.copyWith(
                        color: colors.secondary,
                      ),
                    ),
                ],
              ),
            ),
            if (onNotInterested != null)
              IconButton(
                key: ValueKey('similar-not-interested-${channel.userId}'),
                tooltip: l.liveFeedNotInterested,
                onPressed: () => onNotInterested(channel),
                icon: SheetGlyph(SheetGlyphKind.more, color: colors.secondary),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> showSimilarChannels(
  BuildContext context, {
  required String login,
  required String name,
}) {
  final recommendations = Recommendations.of(context);
  if (recommendations == null) return Future.value();
  return showOnsetSheet<void>(
    context: context,
    builder: (sheetContext) => SimilarChannelsSheet(
      name: name,
      load: () => recommendations.load(
        RecommendationSection.similar,
        channelLogin: login,
      ),
      onOpen: (channel) {
        Navigator.pop(sheetContext);
        unawaited(openRecommendedChannel(context, channel, replace: true));
      },
      onNotInterested: (channel) => unawaited(
        markNotInterested(
          sheetContext,
          channel,
          tellTwitch: recommendations.tellTwitch,
        ),
      ),
    ),
  );
}
