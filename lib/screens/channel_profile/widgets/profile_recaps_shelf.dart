import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/recap.dart';
import 'package:onset/screens/channel_profile/widgets/profile_home_tab.dart';
import 'package:onset/screens/channel_profile/widgets/profile_parts.dart';

class ProfileRecapsShelf extends StatefulWidget {
  const ProfileRecapsShelf({super.key, required this.load, this.large = false});

  static const listKey = ValueKey('profile-recaps');

  final Future<List<Recap>> Function() load;
  final bool large;

  @override
  State<ProfileRecapsShelf> createState() => _ProfileRecapsShelfState();
}

class _ProfileRecapsShelfState extends State<ProfileRecapsShelf> {
  List<Recap> _recaps = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final recaps = await widget.load();
      if (mounted) setState(() => _recaps = recaps);
    } catch (e) {
      debugPrint('ProfileRecapsShelf failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_recaps.isEmpty) return const SizedBox.shrink();
    final large = widget.large;
    final tileWidth = large ? 300.0 : 240.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          ProfileSectionTitle(title: context.l10n.recapsTitle, large: large),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth < tileWidth + 40
                  ? constraints.maxWidth * 0.8
                  : tileWidth;
              return SingleChildScrollView(
                key: ProfileRecapsShelf.listKey,
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: large ? 16 : 12,
                  children: [
                    for (final recap in _recaps)
                      SizedBox(
                        width: width,
                        child: ProfileRecapTile(recap: recap, large: large),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
