import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/team.dart';
import 'package:onset/screens/channel_profile/channel_profile_screen.dart';
import 'package:onset/screens/channel_profile/widgets/profile_extras.dart';
import 'package:onset/screens/channel_profile/widgets/profile_parts.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/state_views.dart';
import 'package:provider/provider.dart';

typedef TeamLoader = Future<Team?> Function(String name);
typedef TeamLiveLoader =
    Future<List<StreamTwitch>> Function(List<String> userIds);

class TeamScreen extends StatefulWidget {
  const TeamScreen({
    super.key,
    required this.name,
    required this.loadTeam,
    required this.loadLive,
    this.initial,
  });

  final String name;
  final Team? initial;
  final TeamLoader loadTeam;
  final TeamLiveLoader loadLive;

  static const routeName = '/team';

  static Future<void> open(BuildContext context, Team team) {
    final api = context.read<TwitchApi>();
    return Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: routeName),
        builder: (_) => TeamScreen(
          name: team.name,
          initial: team,
          loadTeam: (name) => api.getTeam(name: name),
          loadLive: (ids) async =>
              (await api.getStreamsByIds(userIds: ids)).data,
        ),
      ),
    );
  }

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  Team? _team;
  Map<String, StreamTwitch> _live = const {};
  var _loading = true;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _team = widget.initial;
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final team = await widget.loadTeam(widget.name);
      if (!mounted) return;
      if (team == null) {
        setState(() {
          _loading = false;
          _failed = true;
        });
        return;
      }
      var live = const <String, StreamTwitch>{};
      try {
        final ids = [for (final m in team.members.take(100)) m.id];
        if (ids.isNotEmpty) {
          live = {
            for (final stream in await widget.loadLive(ids))
              stream.userId: stream,
          };
        }
      } catch (e) {
        debugPrint('Team ${widget.name} live members failed: $e');
      }
      if (!mounted) return;
      setState(() {
        _team = team;
        _live = live;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Team ${widget.name} failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _openMember(TeamMember member) {
    final stream = _live[member.id];
    if (stream != null) {
      unawaited(Navigator.push(context, streamRoute(stream)));
      return;
    }
    unawaited(
      ChannelProfileScreen.open(
        context,
        login: member.login,
        userId: member.id,
        displayName: member.displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final team = _team;
    final l = context.l10n;
    final colors = FeedColors.of(context);
    final large = context.isLargeScreen;
    final gutter = large ? OnsetSpacing.gutterTablet : OnsetSpacing.gutterPhone;
    final members = team?.members ?? const <TeamMember>[];
    final live =
        [
          for (final m in members)
            if (_live.containsKey(m.id)) m,
        ]..sort(
          (a, b) =>
              _live[b.id]!.viewerCount.compareTo(_live[a.id]!.viewerCount),
        );
    final offline = [
      for (final m in members)
        if (!_live.containsKey(m.id)) m,
    ];
    final Widget body;
    if (team == null || (_failed && members.isEmpty)) {
      body = Center(
        child: _loading
            ? const CircularProgressIndicator.adaptive()
            : FeedStatusView.error(message: l.teamFailed, onRetry: _load),
      );
    } else {
      body = RefreshIndicator.adaptive(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            gutter,
            12,
            gutter,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    Row(
                      spacing: 14,
                      children: [
                        TeamLogo(team: team, size: 64),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 4,
                            children: [
                              Text(
                                team.displayName,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: colors.text,
                                ),
                              ),
                              Text(
                                l.teamMembersCount(count: members.length),
                                style: OnsetType.tabular(
                                  TextStyle(
                                    fontSize: 13,
                                    color: colors.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (team.info.isNotEmpty)
                      Text(
                        team.info,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: colors.body,
                        ),
                      ),
                    if (live.isNotEmpty) ...[
                      ProfileSectionTitle(title: l.teamLiveNow),
                      _MemberGrid(
                        members: live,
                        live: _live,
                        large: large,
                        onOpen: _openMember,
                      ),
                    ],
                    if (offline.isNotEmpty) ...[
                      ProfileSectionTitle(title: l.teamMembers),
                      _MemberGrid(
                        members: offline,
                        live: _live,
                        large: large,
                        onOpen: _openMember,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(team?.displayName ?? l.profileTeams)),
      body: body,
    );
  }
}

class _MemberGrid extends StatelessWidget {
  const _MemberGrid({
    required this.members,
    required this.live,
    required this.large,
    required this.onOpen,
  });

  final List<TeamMember> members;
  final Map<String, StreamTwitch> live;
  final bool large;
  final ValueChanged<TeamMember> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = large && constraints.maxWidth >= 600 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final member in members)
              SizedBox(
                width: width,
                child: _MemberRow(
                  member: member,
                  stream: live[member.id],
                  onTap: () => onOpen(member),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.stream,
    required this.onTap,
  });

  final TeamMember member;
  final StreamTwitch? stream;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final stream = this.stream;
    return PressScale(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('team-member-${member.login}'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ProfileCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              spacing: 12,
              children: [
                InitialAvatar(name: member.displayName, size: 36),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                      if (stream != null)
                        Text(
                          stream.gameName.isEmpty
                              ? stream.title
                              : stream.gameName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.secondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (stream != null)
                  Text(
                    context.l10n.streamViewers(count: stream.viewerCount),
                    style: OnsetType.tabular(
                      TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.onsetColors.live,
                      ),
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
