import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onset/apis/giphy_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/gif_picker.dart';
import 'package:onset/screens/channel/channel_info.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

class GifPickerPanel extends StatefulWidget {
  const GifPickerPanel({
    super.key,
    required this.channelLogin,
    required this.channelName,
    required this.loadConfig,
    required this.giphy,
    required this.send,
    required this.onSent,
  });

  static const searchKey = ValueKey('gif-search');
  static const sendKey = ValueKey('gif-send');
  static ValueKey<String> tileKey(String id) => ValueKey('gif-$id');

  final String channelLogin;
  final String channelName;
  final Future<GifPickerConfig?> Function() loadConfig;
  final GiphyService giphy;
  final Future<GifSendResult> Function(GiphyGif gif, String searchTerm) send;
  final VoidCallback onSent;

  @override
  State<GifPickerPanel> createState() => _GifPickerPanelState();
}

class _GifPickerPanelState extends State<GifPickerPanel> {
  final _query = TextEditingController();
  Timer? _debounce;
  GifPickerConfig? _config;
  List<GiphyGif>? _gifs;
  var _loadingConfig = true;
  var _loadingGifs = false;
  var _sending = false;
  var _searchEpoch = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadConfig());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await widget.loadConfig();
    if (!mounted) return;
    setState(() {
      _config = config;
      _loadingConfig = false;
    });
    if (config != null && config.canSend) await _search();
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_search());
    });
  }

  Future<void> _search() async {
    final config = _config;
    if (config == null) return;
    final epoch = ++_searchEpoch;
    setState(() => _loadingGifs = true);
    final gifs = await widget.giphy.search(config: config, query: _query.text);
    if (!mounted || epoch != _searchEpoch) return;
    setState(() {
      _gifs = gifs;
      _loadingGifs = false;
    });
  }

  Future<void> _confirmAndSend(GiphyGif gif) async {
    if (_sending) return;
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => OnsetDialog(
        title: l.gifSendTitle,
        message: l.gifSendDisclosure,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(OnsetTokens.radiusSmall),
          child: AspectRatio(
            aspectRatio: gif.width / gif.height,
            child: OnsetCachedNetworkImage(imageUrl: gif.previewUrl),
          ),
        ),
        actions: [
          SheetButton(
            label: l.commonCancel,
            tone: SheetButtonTone.text,
            onPressed: () => Navigator.pop(context, false),
          ),
          SheetButton(
            key: GifPickerPanel.sendKey,
            label: l.gifSend,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _sending = true);
    final result = await widget.send(gif, _query.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (result.status == GifSendStatus.sent) {
      widget.onSent();
      return;
    }
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l.gifSendResult(
              status: result.status.name,
              seconds: result.secondsUntilCanSend,
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    if (_loadingConfig) return const _Spinner();
    final config = _config;
    if (config == null || !config.enabled) {
      return _Message(text: l.gifUnavailable, colors: colors);
    }
    if (!config.canSend) {
      return _Message(
        text: l.gifSubscribersOnly,
        colors: colors,
        action: SubscribeButton(
          login: widget.channelLogin,
          name: widget.channelName,
          height: 36,
        ),
      );
    }
    final gifs = _gifs;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: TextField(
            key: GifPickerPanel.searchKey,
            controller: _query,
            onChanged: _onQueryChanged,
            maxLength: GiphyService.maxQueryLength,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => unawaited(_search()),
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              hintText: l.gifSearchHint,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: colors.field,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(OnsetTokens.radiusPill),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: switch (gifs) {
            _ when _loadingGifs && gifs == null => const _Spinner(),
            null => _Message(text: l.gifLoadFailed, colors: colors),
            [] => _Message(text: l.gifNoResults, colors: colors),
            final gifs => GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: gifs.length,
              itemBuilder: (context, index) {
                final gif = gifs[index];
                return Semantics(
                  button: true,
                  label: gif.title.isEmpty ? l.gifTileLabel : gif.title,
                  child: InkWell(
                    key: GifPickerPanel.tileKey(gif.id),
                    borderRadius: BorderRadius.circular(
                      OnsetTokens.radiusSmall,
                    ),
                    onTap: _sending ? null : () => _confirmAndSend(gif),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        OnsetTokens.radiusSmall,
                      ),
                      child: ColoredBox(
                        color: colors.well,
                        child: OnsetCachedNetworkImage(
                          imageUrl: gif.previewUrl,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          },
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            l.gifPoweredBy,
            style: TextStyle(
              fontFamily: OnsetTokens.bodyFamily,
              fontSize: 11,
              color: colors.tertiary,
            ),
          ),
        ),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox.square(
      dimension: 22,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.colors, this.action});

  final String text;
  final SheetColors colors;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: OnsetTokens.bodyFamily,
              fontSize: 14,
              color: colors.secondary,
            ),
          ),
          if (action case final action?) ...[
            const SizedBox(height: 12),
            action,
          ],
        ],
      ),
    ),
  );
}
