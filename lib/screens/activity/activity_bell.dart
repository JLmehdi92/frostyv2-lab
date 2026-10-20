import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/activity/activity_screen.dart';
import 'package:frosty/screens/activity/stores/activity_store.dart';
import 'package:frosty/stores/whisper_store.dart';

/// The way to Activity from Home, with the count of what came since it
/// was last opened (Twitch's Activity tab badge).
class ActivityBell extends StatelessWidget {
  const ActivityBell({
    super.key,
    required this.store,
    required this.onOpenChannel,
    this.whispers,
  });

  final ActivityStore store;
  final void Function(String login) onOpenChannel;

  /// The viewer's whispers (a tab of Activity); null when logged out.
  final WhisperStore? whispers;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final count = store.newCount;
        return IconButton(
          tooltip: count > 0 ? 'Activity ($count new)' : 'Activity',
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 99 ? '99+' : '$count'),
            child: const Icon(Icons.notifications_none_rounded),
          ),
          onPressed: () => ActivityScreen.open(
            context,
            store: store,
            whispers: whispers,
            onOpenChannel: onOpenChannel,
          ),
        );
      },
    );
  }
}
