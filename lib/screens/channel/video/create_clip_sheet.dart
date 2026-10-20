import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/screens/channel/stores/create_clip_store.dart';
import 'package:frosty/screens/onboarding/login_webview.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';
import 'package:frosty/utils/share_link.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/twitch_web_page.dart';
import 'package:provider/provider.dart';

/// What to tell the viewer when Twitch would not make the clip.
String clipFailureMessage(ClipCreateFailure failure) => switch (failure) {
  ClipCreateFailure.missingScope =>
    'Your Twitch login does not allow creating clips.',
  ClipCreateFailure.restricted =>
    "You can't clip this channel right now: clips may be off, only for "
        'followers or subscribers, or you are banned or timed out here.',
  ClipCreateFailure.offline => 'Only live streams can be clipped.',
  ClipCreateFailure.notClippable =>
    'This channel does not permit clips of this category.',
  ClipCreateFailure.rateLimited =>
    'Too many clips at once. Try again in a moment.',
  ClipCreateFailure.unknown => 'Hmm... Something went wrong',
};

/// The official app's Create Clip panel: the clip is made as soon as it
/// opens; once Twitch has it, Edit (twitch.tv's clip editor, where the
/// title and the moment are set before publishing), Share Clip and Copy
/// link.
class CreateClipSheet extends StatelessWidget {
  const CreateClipSheet({
    super.key,
    required this.store,
    required this.onLogIn,
    required this.onOpenEditor,
    required this.onShare,
  });

  final CreateClipStore store;

  /// Logs in again (with the clip permission).
  final VoidCallback onLogIn;
  final void Function(Uri editUrl) onOpenEditor;
  final void Function(String link) onShare;

  /// Opens the panel and clips [broadcasterId]'s stream right away.
  static Future<void> show(
    BuildContext context, {
    required String broadcasterId,
  }) async {
    final authStore = context.read<AuthStore>();
    final store = CreateClipStore(
      twitchApi: context.read<TwitchApi>(),
      broadcasterId: broadcasterId,
      isLoggedIn: () => authStore.isLoggedIn,
    );
    unawaited(store.start());
    final navigator = Navigator.of(context);
    try {
      await showModalBottomSheetWithProperFocus(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => CreateClipSheet(
          store: store,
          onLogIn: () {
            Navigator.of(sheetContext).pop();
            navigator.push(
              MaterialPageRoute(
                builder: (context) => Provider<AuthStore>.value(
                  value: authStore,
                  child: const LoginWebView(),
                ),
              ),
            );
          },
          onOpenEditor: (url) =>
              TwitchWebPage.open(sheetContext, title: 'Edit Clip', url: url),
          onShare: (link) => shareLink(sheetContext, link),
        ),
      );
    } finally {
      store.dispose();
    }
  }

  Future<void> _copy(BuildContext context, String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: AlertMessage(message: 'Clip link copied', centered: false),
      ),
    );
  }

  Widget _progress(String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      spacing: 16,
      children: [
        const CircularProgressIndicator(),
        Text(label, textAlign: TextAlign.center),
      ],
    ),
  );

  Widget _prompt(String message, String action, VoidCallback onPressed) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Text(message),
            FilledButton(onPressed: onPressed, child: Text(action)),
          ],
        ),
      );

  Widget _content(BuildContext context) {
    final creation = store.creation;
    switch (store.status) {
      case CreateClipStatus.idle:
      case CreateClipStatus.checking:
      case CreateClipStatus.creating:
        return _progress('Generating Clipperino...');
      case CreateClipStatus.rendering:
        return _progress('Rendering Clip');
      case CreateClipStatus.needsLogin:
        return _prompt('Log in to create clips.', 'Log in', onLogIn);
      case CreateClipStatus.missingScope:
        return _prompt(
          'Creating clips needs a permission your Twitch login does not '
              'have yet. Reconnect to Twitch to allow it.',
          'Reconnect to Twitch',
          onLogIn,
        );
      case CreateClipStatus.failed:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            spacing: 16,
            children: [
              Text(
                clipFailureMessage(store.failure ?? ClipCreateFailure.unknown),
                textAlign: TextAlign.center,
              ),
              OutlinedButton(
                onPressed: store.start,
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      case CreateClipStatus.ready:
        if (creation == null) return const SizedBox.shrink();
        final editUrl = creation.editUrl;
        final thumbnail = store.thumbnailUrl;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (thumbnail != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          const ColoredBox(color: Colors.black),
                    ),
                  ),
                ),
              ),
            if (editUrl != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => onOpenEditor(editUrl),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('Edit'),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share Clip'),
              onTap: () => onShare(creation.link),
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Copy link'),
              onTap: () => _copy(context, creation.link),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Create Clip',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Observer(builder: _content),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// The live player's Clip button (top right, like the official app).
class CreateClipButton extends StatelessWidget {
  const CreateClipButton({
    super.key,
    required this.broadcasterId,
    required this.color,
    this.shadows,
  });

  final String broadcasterId;
  final Color color;
  final List<Shadow>? shadows;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Clip',
      icon: Icon(Icons.movie_creation_outlined, color: color, shadows: shadows),
      onPressed: () =>
          CreateClipSheet.show(context, broadcasterId: broadcasterId),
    );
  }
}
