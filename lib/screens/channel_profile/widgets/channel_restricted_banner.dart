import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_channel_profile_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/theme.dart';
import 'package:provider/provider.dart';

class ChannelRestrictedBanner extends StatefulWidget {
  const ChannelRestrictedBanner({
    super.key,
    required this.channelId,
    required this.name,
    this.check,
  });

  final String channelId;
  final String name;
  final Future<bool> Function(String channelId)? check;

  @override
  State<ChannelRestrictedBanner> createState() =>
      _ChannelRestrictedBannerState();
}

class _ChannelRestrictedBannerState extends State<ChannelRestrictedBanner> {
  var _restricted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  @override
  void didUpdateWidget(ChannelRestrictedBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId != widget.channelId) {
      _restricted = false;
      unawaited(_read());
    }
  }

  Future<void> _read() async {
    final channelId = widget.channelId;
    final check =
        widget.check ??
        context.read<TwitchChannelProfileService?>()?.isRestricted;
    if (check == null) return;
    final bool restricted;
    try {
      restricted = await check(channelId);
    } catch (_) {
      return;
    }
    if (mounted && widget.channelId == channelId && restricted) {
      setState(() => _restricted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_restricted) return const SizedBox.shrink();
    final colors = FeedColors.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: OnsetTokens.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: OnsetTokens.danger.withValues(alpha: 0.45),
            width: OnsetTokens.hairlineWidth,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.gpp_maybe_rounded,
                  size: 18,
                  color: OnsetTokens.danger,
                ),
              ),
              Expanded(
                child: Text(
                  context.l10n.channelRestrictedBanner(name: widget.name),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: colors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
