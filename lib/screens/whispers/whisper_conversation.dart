import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/stores/whisper_store.dart';
import 'package:frosty/widgets/frosty_app_bar.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:frosty/widgets/readable_width.dart';
import 'package:intl/intl.dart';

/// The whispers with one person, and a field to answer.
class WhisperConversation extends StatefulWidget {
  const WhisperConversation({
    super.key,
    required this.store,
    required this.userId,
    required this.login,
    required this.displayName,
  });

  final WhisperStore store;
  final String userId;
  final String login;
  final String displayName;

  static const routeName = '/whisper';

  static Future<void> open(
    BuildContext context, {
    required WhisperStore store,
    required String userId,
    required String login,
    required String displayName,
  }) => Navigator.push(
    context,
    route(store: store, userId: userId, login: login, displayName: displayName),
  );

  /// The screen as a route, for a caller whose context is going away (a
  /// bottom sheet that closes first).
  static Route<void> route({
    required WhisperStore store,
    required String userId,
    required String login,
    required String displayName,
  }) => MaterialPageRoute(
    settings: const RouteSettings(name: routeName),
    builder: (context) => WhisperConversation(
      store: store,
      userId: userId,
      login: login,
      displayName: displayName,
    ),
  );

  @override
  State<WhisperConversation> createState() => _WhisperConversationState();
}

class _WhisperConversationState extends State<WhisperConversation> {
  late final WhisperThread _thread;
  final _text = TextEditingController();
  var _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Opened outside any build: it marks the whispers read.
    _thread = widget.store.open(
      userId: widget.userId,
      login: widget.login,
      displayName: widget.displayName,
    );
  }

  @override
  void dispose() {
    widget.store.close(widget.userId);
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await widget.store.send(_thread, text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = error;
      // Keep a draft typed while it was sending.
      if (error == null && _text.text == text) _text.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: FrostyAppBar(
        title: Row(
          children: [
            ProfilePicture(userLogin: widget.login, radius: 14),
            const SizedBox(width: 12),
            Flexible(
              child: Text(widget.displayName, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kReadableMaxWidth),
          child: Column(
            children: [
              Expanded(
                child: Observer(
                  builder: (context) {
                    final whispers = _thread.whispers.reversed.toList();
                    if (whispers.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Whisper ${widget.displayName}. Twitch keeps no '
                            'history the app can show, so only this '
                            "session's whispers appear here.",
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }
                    // Bubbles take at most 3/4 of the column (not of a
                    // tablet's whole width), so sides stay apart.
                    return LayoutBuilder(
                      builder: (context, constraints) => ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: whispers.length,
                        itemBuilder: (context, index) => _Bubble(
                          whisper: whispers[index],
                          maxWidth: constraints.maxWidth * 0.75,
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: TwitchApi.maxWhisperLength,
                          buildCounter:
                              (
                                context, {
                                required currentLength,
                                required isFocused,
                                required maxLength,
                              }) => null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Whisper ${widget.displayName}',
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(24),
                              ),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Send',
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.whisper, required this.maxWidth});

  final Whisper whisper;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = whisper.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: mine
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SelectableText(
                whisper.text,
                style: TextStyle(
                  color: mine
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat.jm().format(whisper.sentAt.toLocal()),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
