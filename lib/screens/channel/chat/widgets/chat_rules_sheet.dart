import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/chat_rules.dart';
import 'package:frosty/screens/channel/chat/stores/chat_rules_store.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:mobx/mobx.dart';

/// The official app's "Chat Rules" sheet: the channel's picture and name
/// over the title, the rules as plain lines, and "OK, Got it!".
class ChatRulesSheet extends StatelessWidget {
  const ChatRulesSheet({super.key, required this.rules, required this.onAccept});

  final ChatRules rules;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final avatar = rules.iconUrl;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClipOval(
                    child: SizedBox.square(
                      dimension: 40,
                      child: avatar == null
                          ? ColoredBox(
                              color: context.frostyColors.hairline,
                              child: const Icon(Icons.person_rounded),
                            )
                          : FrostyCachedNetworkImage(
                              imageUrl: avatar,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (rules.channelName.isNotEmpty)
                          Text(
                            rules.channelName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.frostyColors.metadata,
                            ),
                          ),
                        Text(
                          'Chat Rules',
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(top: 8),
                  children: [
                    for (final rule in rules.rules)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(rule),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAccept,
                child: const Text('OK, Got it!'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows [ChatRulesSheet] whenever [rules] stops the viewer from typing in
/// [focus] (the chat input), and gives the input back once they accept.
class ChatRulesPrompt extends StatefulWidget {
  const ChatRulesPrompt({
    super.key,
    required this.rules,
    required this.focus,
    required this.child,
  });

  final ChatRulesStore? rules;
  final FocusNode focus;
  final Widget child;

  @override
  State<ChatRulesPrompt> createState() => _ChatRulesPromptState();
}

class _ChatRulesPromptState extends State<ChatRulesPrompt> {
  ReactionDisposer? _dispose;
  var _showing = false;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void didUpdateWidget(ChatRulesPrompt old) {
    super.didUpdateWidget(old);
    if (old.rules != widget.rules) _watch();
  }

  void _watch() {
    _dispose?.call();
    final store = widget.rules;
    if (store == null) return;
    _dispose = reaction((_) => store.prompting, (bool prompting) {
      if (prompting) _show(store);
    });
  }

  Future<void> _show(ChatRulesStore store) async {
    final rules = store.rules;
    if (_showing || rules == null || !mounted) return;
    _showing = true;
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ChatRulesSheet(
        rules: rules,
        onAccept: () => Navigator.of(context).pop(true),
      ),
    );
    _showing = false;
    if (accepted == true) {
      await store.accept();
      if (mounted && widget.rules == store) widget.focus.requestFocus();
    } else {
      store.dismissPrompt();
    }
  }

  @override
  void dispose() {
    _dispose?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// "Chat rules" in the chat menu, to read the rules again at any time (an
/// ONSET addition: Twitch only shows them before the first message).
/// Nothing when the channel has none.
class ChatRulesTile extends StatelessWidget {
  const ChatRulesTile({super.key, required this.rules});

  final ChatRulesStore? rules;

  @override
  Widget build(BuildContext context) {
    final store = rules;
    if (store == null) return const SizedBox.shrink();
    return Observer(
      builder: (context) {
        final read = store.rules;
        if (read == null || !read.hasRules) return const SizedBox.shrink();
        return ListTile(
          leading: const Icon(Icons.gavel_rounded),
          title: const Text('Chat rules'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final accepted = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              builder: (context) => ChatRulesSheet(
                rules: read,
                onAccept: () => Navigator.of(context).pop(true),
              ),
            );
            if (accepted == true) await store.accept();
          },
        );
      },
    );
  }
}
