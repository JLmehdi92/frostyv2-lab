import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/whispers/whisper_conversation.dart';
import 'package:frosty/stores/whisper_store.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/frosty_app_bar.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:frosty/widgets/readable_width.dart';
import 'package:intl/intl.dart';

/// What to tell about [status] above the conversations, or null.
String? whisperStatusHint(WhisperStatus status) => switch (status) {
  WhisperStatus.refused =>
    'Twitch refused to send your whispers to this app. Log out and log in '
        'again to allow them.',
  WhisperStatus.interrupted => 'Reconnecting… whispers will arrive again soon.',
  WhisperStatus.off => 'Log in to get whispers.',
  WhisperStatus.connecting || WhisperStatus.listening => null,
};

/// The viewer's whisper conversations, most recent first.
class WhispersScreen extends StatelessWidget {
  const WhispersScreen({super.key, required this.store});

  final WhisperStore store;

  static const routeName = '/whispers';

  static Future<void> open(BuildContext context, WhisperStore store) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: routeName),
          builder: (context) => WhispersScreen(store: store),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FrostyAppBar(title: Text('Whispers')),
      body: Observer(
        builder: (context) {
          final hint = whisperStatusHint(store.status);
          final threads = store.threads;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kReadableMaxWidth),
              child: Column(
                children: [
                  if (hint != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: AlertMessage(message: hint, centered: false),
                    ),
                  Expanded(
                    child: threads.isEmpty
                        ? const AlertMessage(
                            message:
                                'No whispers yet. Whispers you get while '
                                'the app is open show up here.',
                            vertical: true,
                          )
                        : ListView.builder(
                            itemCount: threads.length,
                            itemBuilder: (context, index) => _ThreadTile(
                              store: store,
                              thread: threads[index],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.store, required this.thread});

  final WhisperStore store;
  final WhisperThread thread;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final theme = Theme.of(context);
        final last = thread.whispers.lastOrNull;
        final unread = thread.unread;
        return ListTile(
          leading: ProfilePicture(userLogin: thread.login),
          title: Text(
            thread.displayName,
            overflow: TextOverflow.ellipsis,
            style: unread > 0
                ? const TextStyle(fontWeight: FontWeight.bold)
                : null,
          ),
          subtitle: last == null
              ? null
              : Text(
                  '${last.mine ? 'You: ' : ''}${last.text}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (last != null)
                Text(
                  DateFormat.jm().format(last.sentAt.toLocal()),
                  style: theme.textTheme.bodySmall,
                ),
              if (unread > 0) ...[
                const SizedBox(height: 4),
                Badge(label: Text('$unread')),
              ],
            ],
          ),
          onTap: () => WhisperConversation.open(
            context,
            store: store,
            userId: thread.userId,
            login: thread.login,
            displayName: thread.displayName,
          ),
        );
      },
    );
  }
}
