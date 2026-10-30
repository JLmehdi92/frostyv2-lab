import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/models/chat_rules.dart';
import 'package:onset/screens/channel/chat/stores/chat_rules_store.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

/// The official app's "Chat Rules" sheet: the channel's picture and name
/// over the title, the rules as a numbered list, and "OK, Got it!" (also
/// shown inside the chat menu).
class ChatRulesSheet extends StatelessWidget {
  const ChatRulesSheet({
    super.key,
    required this.rules,
    required this.onAccept,
    this.onBack,
  });

  final ChatRules rules;
  final VoidCallback onAccept;

  /// Inside the chat menu: a back header like its other views.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final avatar = rules.iconUrl;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onBack case final back?)
            SheetBackHeader(title: 'Chat rules', onBack: back),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              spacing: 10,
              children: [
                ClipOval(
                  child: SizedBox.square(
                    dimension: 40,
                    child: avatar == null
                        ? ColoredBox(
                            color: colors.raised,
                            child: Center(
                              child: SheetGlyph(
                                SheetGlyphKind.profile,
                                color: colors.secondary,
                              ),
                            ),
                          )
                        : OnsetCachedNetworkImage(
                            imageUrl: avatar,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 1,
                    children: [
                      if (rules.channelName.isNotEmpty)
                        Text(
                          rules.channelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SheetText.rowDetail.copyWith(
                            color: colors.secondary,
                          ),
                        ),
                      Semantics(
                        header: true,
                        child: Text(
                          'Chat Rules',
                          style: SheetText.subtitle.copyWith(
                            color: colors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              children: [
                for (final (index, rule) in rules.rules.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 20,
                          child: Text(
                            '${index + 1}.',
                            style: SheetText.tabular(
                              SheetText.body.copyWith(color: colors.body),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            rule,
                            style: SheetText.body.copyWith(color: colors.body),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: SheetButton(
              label: 'OK, Got it!',
              large: true,
              expand: true,
              onPressed: onAccept,
            ),
          ),
        ],
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
    final accepted = await showOnsetSheet<bool>(
      context: context,
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
/// Nothing when the channel has none. [onOpen] shows them in place (the
/// chat menu's own view); without it they open in a sheet.
class ChatRulesTile extends StatelessWidget {
  const ChatRulesTile({super.key, required this.rules, this.onOpen});

  final ChatRulesStore? rules;
  final ValueChanged<ChatRules>? onOpen;

  @override
  Widget build(BuildContext context) {
    final store = rules;
    if (store == null) return const SizedBox.shrink();
    return Observer(
      builder: (context) {
        final read = store.rules;
        if (read == null || !read.hasRules) return const SizedBox.shrink();
        return SheetRow(
          glyph: SheetGlyphKind.rules,
          label: 'Chat rules',
          end: SheetRowEnd.chevron,
          onTap: () async {
            if (onOpen case final open?) {
              open(read);
              return;
            }
            final accepted = await showOnsetSheet<bool>(
              context: context,
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
