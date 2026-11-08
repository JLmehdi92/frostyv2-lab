import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_mod_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/category.dart';
import 'package:onset/models/moderation.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/mod_tools/stores/mod_tools_store.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/mod_sheet_parts.dart';
import 'package:onset/screens/channel/chat/moderation.dart';
import 'package:onset/screens/channel/chat/moderation_notice.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

const kAnnouncementColors = {
  AnnouncementColor.primary: null,
  AnnouncementColor.blue: Color(0xFF00D6D6),
  AnnouncementColor.green: Color(0xFF00DB84),
  AnnouncementColor.orange: Color(0xFFFFB31A),
  AnnouncementColor.purple: Color(0xFF9147FF),
};

class _FormPadding extends StatelessWidget {
  const _FormPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 6), child: child);
}

class AnnounceSheet extends StatefulWidget {
  const AnnounceSheet({super.key, required this.chatStore});

  final ChatStore chatStore;

  @override
  State<AnnounceSheet> createState() => _AnnounceSheetState();
}

class _AnnounceSheetState extends State<AnnounceSheet>
    with ModActionState<AnnounceSheet> {
  final _message = TextEditingController();
  var _color = AnnouncementColor.primary;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => busy = true);
    ModerationOutcome? outcome;
    try {
      outcome = await widget.chatStore.moderate(
        AnnounceCommand(singleLine(_message.text), _color),
      );
    } catch (error) {
      outcome = moderationFailed;
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      statusOk = outcome?.ok ?? true;
      statusMessage = outcome?.message;
      if (statusOk) _message.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final accent = SheetColors.accentOf(context);
    return ModSheetBody(
      children: [
        ModSheetTitle(l.modToolsAnnounce, caption: l.modToolsAnnounceCaption),
        _FormPadding(
          child: SheetTextField(
            controller: _message,
            label: l.modToolsAnnounceLabel,
            maxLength: ModTextLimits.announcement,
            counter: true,
          ),
        ),
        SheetSectionLabel(l.modToolsAnnounceColor),
        _FormPadding(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final MapEntry(key: color, value: swatch)
                  in kAnnouncementColors.entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: swatch ?? accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SheetChoicePill(
                      label: l.modToolsAnnounceColorName(color: color.name),
                      selected: _color == color,
                      large: true,
                      onSelected: () => setState(() => _color = color),
                    ),
                  ],
                ),
            ],
          ),
        ),
        _FormPadding(
          child: ListenableBuilder(
            listenable: _message,
            builder: (context, _) => SheetButton(
              label: l.modToolsAnnounceSend,
              expand: true,
              large: true,
              onPressed: busy || singleLine(_message.text).isEmpty
                  ? null
                  : _send,
            ),
          ),
        ),
        statusLine(),
      ],
    );
  }
}

const kPollDurations = [
  Duration(minutes: 1),
  Duration(minutes: 2),
  Duration(minutes: 5),
  Duration(minutes: 10),
  Duration(minutes: 30),
];

const kPredictionWindows = [
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 2),
  Duration(minutes: 5),
  Duration(minutes: 10),
];

class _ChoiceFields extends StatelessWidget {
  const _ChoiceFields({
    required this.controllers,
    required this.label,
    required this.maxLength,
    required this.max,
    required this.onAdd,
    required this.addLabel,
  });

  final List<TextEditingController> controllers;
  final String Function(int number) label;
  final int maxLength;
  final int max;
  final VoidCallback onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, controller) in controllers.indexed)
        _FormPadding(
          child: SheetTextField(
            controller: controller,
            label: label(index + 1),
            maxLength: maxLength,
          ),
        ),
      if (controllers.length < max)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SheetButton(
              label: addLabel,
              tone: SheetButtonTone.text,
              onPressed: onAdd,
            ),
          ),
        ),
    ],
  );
}

class _DurationPills extends StatelessWidget {
  const _DurationPills({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final List<Duration> values;
  final Duration selected;
  final ValueChanged<Duration> onSelected;

  @override
  Widget build(BuildContext context) => _FormPadding(
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          SheetChoicePill(
            label: timeoutLength(value.inSeconds, context.l10n),
            selected: value == selected,
            large: true,
            onSelected: () => onSelected(value),
          ),
      ],
    ),
  );
}

List<TextEditingController> _controllers(int count) => [
  for (var i = 0; i < count; i++) TextEditingController(),
];

class PollSheet extends StatefulWidget {
  const PollSheet({super.key, required this.chatStore});

  final ChatStore chatStore;

  @override
  State<PollSheet> createState() => _PollSheetState();
}

class _PollSheetState extends State<PollSheet> with ModActionState<PollSheet> {
  final _title = TextEditingController();
  final _choices = _controllers(2);
  var _duration = kPollDurations[1];
  ChannelPoll? _poll;
  var _loading = true;

  TwitchModApi get _api => widget.chatStore.twitchApi.moderation;
  String get _channel => widget.chatStore.channelId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    for (final controller in _choices) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    ChannelPoll? poll;
    try {
      poll = await _api.getLatestPoll(broadcasterId: _channel);
    } catch (error) {
      debugPrint('Poll unreadable: $error');
    }
    if (mounted) {
      setState(() {
        _poll = poll;
        _loading = false;
      });
    }
  }

  bool get _ready =>
      singleLine(_title.text).isNotEmpty &&
      _choices.where((c) => singleLine(c.text).isNotEmpty).length >=
          ModTextLimits.pollChoicesMin;

  Future<void> _create() async {
    final l = context.l10n;
    ChannelPoll? created;
    await runModAction(
      () async => created = await _api.createPoll(
        broadcasterId: _channel,
        title: _title.text,
        choices: [for (final c in _choices) c.text],
        duration: _duration,
      ),
      command: 'createPoll',
      success: l.modToolsPollStarted,
    );
    if (created != null && mounted) setState(() => _poll = created);
  }

  Future<void> _end(ChannelPoll poll) async {
    final l = context.l10n;
    final confirmed = await confirmModAction(
      context,
      title: l.modToolsPollEndTitle,
      message: l.modToolsPollEndMessage,
      confirmLabel: l.modToolsPollEnd,
      danger: true,
    );
    if (!confirmed || !mounted) return;
    ChannelPoll? ended;
    await runModAction(
      () async =>
          ended = await _api.endPoll(broadcasterId: _channel, pollId: poll.id),
      command: 'endPoll',
      success: l.modToolsPollEnded,
    );
    if (ended != null && mounted) setState(() => _poll = ended);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final poll = _poll;
    return ModSheetBody(
      children: [
        ModSheetTitle(l.modToolsPolls, caption: l.modToolsPollsCaption),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (poll != null && poll.isActive) ...[
          SheetSectionLabel(l.modToolsPollLive),
          ModNote(poll.title, strong: true),
          for (final choice in poll.choices)
            ModItemTile(
              leading: const SizedBox(width: 4),
              title: choice.title,
              subtitle: l.modToolsVotes(count: choice.votes),
            ),
          _FormPadding(
            child: SheetButton(
              label: l.modToolsPollEnd,
              tone: SheetButtonTone.danger,
              expand: true,
              onPressed: busy ? null : () => _end(poll),
            ),
          ),
        ] else ...[
          _FormPadding(
            child: SheetTextField(
              controller: _title,
              label: l.modToolsQuestionLabel,
              maxLength: ModTextLimits.pollTitle,
              counter: true,
              onChanged: (_) => setState(() {}),
            ),
          ),
          _ChoiceFields(
            controllers: _choices,
            label: (number) => l.modToolsChoiceLabel(number: number),
            maxLength: ModTextLimits.pollChoice,
            max: ModTextLimits.pollChoicesMax,
            addLabel: l.modToolsAddChoice,
            onAdd: () => setState(() => _choices.add(TextEditingController())),
          ),
          SheetSectionLabel(l.modToolsPollDuration),
          _DurationPills(
            values: kPollDurations,
            selected: _duration,
            onSelected: (value) => setState(() => _duration = value),
          ),
          _FormPadding(
            child: ListenableBuilder(
              listenable: Listenable.merge(_choices),
              builder: (context, _) => SheetButton(
                label: l.modToolsPollStart,
                expand: true,
                large: true,
                onPressed: busy || !_ready ? null : _create,
              ),
            ),
          ),
        ],
        statusLine(),
      ],
    );
  }
}

class PredictionSheet extends StatefulWidget {
  const PredictionSheet({super.key, required this.chatStore});

  final ChatStore chatStore;

  @override
  State<PredictionSheet> createState() => _PredictionSheetState();
}

class _PredictionSheetState extends State<PredictionSheet>
    with ModActionState<PredictionSheet> {
  final _title = TextEditingController();
  final _outcomes = _controllers(2);
  var _window = kPredictionWindows[2];
  ChannelPrediction? _prediction;
  var _loading = true;

  TwitchModApi get _api => widget.chatStore.twitchApi.moderation;
  String get _channel => widget.chatStore.channelId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    for (final controller in _outcomes) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    ChannelPrediction? prediction;
    try {
      prediction = await _api.getLatestPrediction(broadcasterId: _channel);
    } catch (error) {
      debugPrint('Prediction unreadable: $error');
    }
    if (mounted) {
      setState(() {
        _prediction = prediction;
        _loading = false;
      });
    }
  }

  bool get _ready =>
      singleLine(_title.text).isNotEmpty &&
      _outcomes.where((c) => singleLine(c.text).isNotEmpty).length >=
          ModTextLimits.predictionOutcomesMin;

  Future<void> _create() async {
    final l = context.l10n;
    ChannelPrediction? created;
    await runModAction(
      () async => created = await _api.createPrediction(
        broadcasterId: _channel,
        title: _title.text,
        outcomes: [for (final c in _outcomes) c.text],
        window: _window,
      ),
      command: 'createPrediction',
      success: l.modToolsPredictionStarted,
    );
    if (created != null && mounted) setState(() => _prediction = created);
  }

  Future<void> _end(
    ChannelPrediction prediction,
    PredictionEnd end, {
    PredictionOutcome? winner,
  }) async {
    final l = context.l10n;
    final confirmed = await confirmModAction(
      context,
      title: switch (end) {
        PredictionEnd.locked => l.modToolsPredictionLockTitle,
        PredictionEnd.canceled => l.modToolsPredictionCancelTitle,
        PredictionEnd.resolved => l.modToolsPredictionResolveTitle,
      },
      message: switch (end) {
        PredictionEnd.locked => l.modToolsPredictionLockMessage,
        PredictionEnd.canceled => l.modToolsPredictionCancelMessage,
        PredictionEnd.resolved => l.modToolsPredictionResolveMessage(
          outcome: winner!.title,
        ),
      },
      confirmLabel: switch (end) {
        PredictionEnd.locked => l.modToolsPredictionLock,
        PredictionEnd.canceled => l.modToolsPredictionCancel,
        PredictionEnd.resolved => l.modToolsPredictionResolve,
      },
      danger: end != PredictionEnd.resolved,
    );
    if (!confirmed || !mounted) return;
    ChannelPrediction? updated;
    await runModAction(
      () async => updated = await _api.endPrediction(
        broadcasterId: _channel,
        predictionId: prediction.id,
        end: end,
        winningOutcomeId: winner?.id,
      ),
      command: switch (end) {
        PredictionEnd.locked => 'lockPrediction',
        PredictionEnd.resolved => 'resolvePrediction',
        PredictionEnd.canceled => 'cancelPrediction',
      },
      success: l.modToolsPredictionUpdated(state: end.name),
    );
    if (updated != null && mounted) setState(() => _prediction = updated);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final prediction = _prediction;
    return ModSheetBody(
      children: [
        ModSheetTitle(
          l.modToolsPredictions,
          caption: l.modToolsPredictionsCaption,
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (prediction != null && prediction.isOpen) ...[
          SheetSectionLabel(
            prediction.isLocked
                ? l.modToolsPredictionLocked
                : l.modToolsPredictionLive,
          ),
          ModNote(prediction.title, strong: true),
          for (final outcome in prediction.outcomes)
            ModItemTile(
              leading: const SizedBox(width: 4),
              title: outcome.title,
              subtitle: [
                l.modToolsPredictionUsers(count: outcome.users),
                l.modToolsPredictionPoints(count: outcome.channelPoints),
              ].join(' · '),
              actions: [
                ModCompactButton(
                  label: l.modToolsPredictionPickWinner,
                  primary: true,
                  onPressed: busy
                      ? null
                      : () => _end(
                          prediction,
                          PredictionEnd.resolved,
                          winner: outcome,
                        ),
                ),
              ],
            ),
          _FormPadding(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (prediction.isActive)
                  SheetButton(
                    label: l.modToolsPredictionLock,
                    tone: SheetButtonTone.text,
                    onPressed: busy
                        ? null
                        : () => _end(prediction, PredictionEnd.locked),
                  ),
                SheetButton(
                  label: l.modToolsPredictionCancel,
                  tone: SheetButtonTone.danger,
                  onPressed: busy
                      ? null
                      : () => _end(prediction, PredictionEnd.canceled),
                ),
              ],
            ),
          ),
        ] else ...[
          _FormPadding(
            child: SheetTextField(
              controller: _title,
              label: l.modToolsQuestionLabel,
              maxLength: ModTextLimits.predictionTitle,
              counter: true,
              onChanged: (_) => setState(() {}),
            ),
          ),
          _ChoiceFields(
            controllers: _outcomes,
            label: (number) => l.modToolsOutcomeLabel(number: number),
            maxLength: ModTextLimits.predictionOutcome,
            max: ModTextLimits.predictionOutcomesMax,
            addLabel: l.modToolsAddOutcome,
            onAdd: () => setState(() => _outcomes.add(TextEditingController())),
          ),
          SheetSectionLabel(l.modToolsPredictionWindow),
          _DurationPills(
            values: kPredictionWindows,
            selected: _window,
            onSelected: (value) => setState(() => _window = value),
          ),
          _FormPadding(
            child: ListenableBuilder(
              listenable: Listenable.merge(_outcomes),
              builder: (context, _) => SheetButton(
                label: l.modToolsPredictionStart,
                expand: true,
                large: true,
                onPressed: busy || !_ready ? null : _create,
              ),
            ),
          ),
        ],
        statusLine(),
      ],
    );
  }
}

class StreamInfoSheet extends StatefulWidget {
  const StreamInfoSheet({super.key, required this.chatStore});

  final ChatStore chatStore;

  @override
  State<StreamInfoSheet> createState() => _StreamInfoSheetState();
}

class _StreamInfoSheetState extends State<StreamInfoSheet>
    with ModActionState<StreamInfoSheet> {
  final _title = TextEditingController();
  final _category = TextEditingController();
  final _tag = TextEditingController();
  var _tags = <String>[];
  String? _gameId;
  String _gameName = '';
  List<CategoryTwitch> _results = const [];
  var _loading = true;
  String? _tagProblem;
  String? _loadFailure;
  String _loadedTitle = '';
  String? _loadedGameId;
  List<String> _loadedTags = const [];

  ChatStore get _chat => widget.chatStore;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _tag.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailure = null;
    });
    String? failure;
    try {
      final channel = await _chat.twitchApi.getChannel(userId: _chat.channelId);
      _title.text = channel.title;
      _loadedTitle = channel.title;
      _gameId = channel.gameId;
      _loadedGameId = channel.gameId;
      _gameName = channel.gameName;
      _tags = [...channel.tags];
      _loadedTags = [...channel.tags];
    } catch (error) {
      debugPrint('Stream info unreadable: $error');
      failure = modToolsFailure(error, 'loadStream');
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _loadFailure = failure;
      });
    }
  }

  bool get _tagsChanged =>
      _tags.length != _loadedTags.length ||
      _tags.indexed.any((entry) => _loadedTags[entry.$1] != entry.$2);

  bool get _changed =>
      singleLine(_title.text) != _loadedTitle ||
      _gameId != _loadedGameId ||
      _tagsChanged;

  Future<void> _search(String query) async {
    final term = query.trim();
    if (term.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    try {
      final found = await _chat.twitchApi.searchCategories(query: term);
      if (mounted && _category.text.trim() == term) {
        setState(() => _results = found.data.take(5).toList());
      }
    } catch (error) {
      debugPrint('Category search failed: $error');
    }
  }

  void _addTag() {
    final l = context.l10n;
    final tag = singleLine(_tag.text).replaceAll(' ', '');
    if (tag.isEmpty) return;
    setState(() {
      if (!isValidStreamTag(tag)) {
        _tagProblem = l.modToolsTagInvalid;
      } else if (_tags.length >= ModTextLimits.tagsMax) {
        _tagProblem = l.modToolsTagLimit(count: ModTextLimits.tagsMax);
      } else {
        _tagProblem = null;
        if (!_tags.any((t) => t.toLowerCase() == tag.toLowerCase())) {
          _tags = [..._tags, tag];
        }
        _tag.clear();
      }
    });
  }

  Future<void> _save() async {
    final l = context.l10n;
    await runModAction(
      () async {
        final title = singleLine(_title.text);
        final tags = [..._tags];
        await _chat.twitchApi.moderation.updateStreamInfo(
          broadcasterId: _chat.channelId,
          title: title == _loadedTitle ? null : title,
          gameId: _gameId == _loadedGameId ? null : _gameId,
          tags: _tagsChanged ? tags : null,
        );
        _loadedTitle = title;
        _loadedGameId = _gameId;
        _loadedTags = tags;
      },
      command: 'updateStream',
      success: l.modToolsStreamInfoSaved,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_loading) {
      return ModSheetBody(
        children: [
          ModSheetTitle(l.modToolsStreamInfo),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    if (_loadFailure case final failure?) {
      return ModSheetBody(
        children: [
          ModSheetTitle(l.modToolsStreamInfo),
          ModNote(failure),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: SheetButton(
                label: l.commonRetry,
                tone: SheetButtonTone.text,
                onPressed: _load,
              ),
            ),
          ),
        ],
      );
    }
    return ModSheetBody(
      children: [
        ModSheetTitle(
          l.modToolsStreamInfo,
          caption: l.modToolsStreamInfoCaption,
        ),
        _FormPadding(
          child: SheetTextField(
            controller: _title,
            label: l.modToolsStreamTitleLabel,
            maxLength: ModTextLimits.streamTitle,
            counter: true,
            onChanged: (_) => setState(() {}),
          ),
        ),
        _FormPadding(
          child: SheetTextField(
            controller: _category,
            label: l.modToolsCategoryLabel,
            hint: _gameName.isEmpty ? l.modToolsCategoryNone : _gameName,
            onChanged: _search,
          ),
        ),
        for (final category in _results)
          SheetRow(
            label: category.name,
            trailing: category.id == _gameId
                ? SheetGlyph(
                    SheetGlyphKind.check,
                    color: SheetColors.accentOf(context),
                  )
                : null,
            onTap: () => setState(() {
              _gameId = category.id;
              _gameName = category.name;
              _results = const [];
              _category.clear();
            }),
          ),
        SheetSectionLabel(l.modToolsTags),
        _FormPadding(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _tags)
                _TagPill(
                  tag: tag,
                  removeTooltip: l.modToolsRemoveTag(tag: tag),
                  onRemove: () =>
                      setState(() => _tags = [..._tags]..remove(tag)),
                ),
            ],
          ),
        ),
        ModAddField(
          label: l.modToolsTagLabel,
          actionLabel: l.modToolsAdd,
          maxLength: ModTextLimits.tag,
          onSubmit: (text) async {
            _tag.text = text;
            _addTag();
            return _tagProblem == null;
          },
        ),
        if (_tagProblem case final problem?)
          ModNote(problem, padding: const EdgeInsets.fromLTRB(16, 0, 16, 4)),
        _FormPadding(
          child: SheetButton(
            label: l.modToolsSave,
            expand: true,
            large: true,
            onPressed: busy || singleLine(_title.text).isEmpty || !_changed
                ? null
                : _save,
          ),
        ),
        statusLine(),
      ],
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.tag,
    required this.removeTooltip,
    required this.onRemove,
  });

  final String tag;
  final String removeTooltip;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsetsDirectional.only(start: 14),
      decoration: ShapeDecoration(
        color: colors.chip,
        shape: StadiumBorder(side: BorderSide(color: colors.ring)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tag, style: SheetText.pill.copyWith(color: colors.text)),
          IconButton(
            tooltip: removeTooltip,
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            icon: SheetGlyph(
              SheetGlyphKind.close,
              size: 14,
              strokeWidth: 2.2,
              color: colors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
