import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/services/cast_bridge.dart';
import 'package:onset/stores/cast_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/coach_mark.dart';
import 'package:onset/widgets/new_feature_pill.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

typedef CastMediaSource = CastMedia? Function();

class CastButton extends StatelessWidget {
  const CastButton({
    super.key,
    required this.media,
    this.onCastStarted,
    this.store,
    this.color = Colors.white,
    this.size = 44,
    this.glyphSize = 22,
  });

  final CastMediaSource media;
  final VoidCallback? onCastStarted;
  final CastStore? store;
  final Color color;
  final double size;
  final double glyphSize;

  @override
  Widget build(BuildContext context) {
    final store = this.store ?? sharedCastStore;
    if (!store.supported) return const SizedBox.shrink();
    return CoachMark(
      feature: NewFeature.cast,
      message: context.l10n.coachMarkCast,
      child: _observedButton(store),
    );
  }

  Widget _observedButton(CastStore store) {
    return Observer(
      builder: (context) {
        final l = context.l10n;
        final connected = store.connected;
        final device = store.status.deviceName;
        final tint = connected ? OnsetTokens.accent : color;
        return Tooltip(
          message: connected && device != null
              ? l.castConnectedTo(device: device)
              : l.castButton,
          child: Semantics(
            selected: connected,
            child: IconButton(
              key: const ValueKey('cast-button'),
              onPressed: () => showCastSheet(
                context,
                store: store,
                media: media,
                onCastStarted: onCastStarted,
              ),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(width: size, height: size),
              style: IconButton.styleFrom(
                foregroundColor: tint,
                highlightColor: const Color(0x1FFFFFFF),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                connected ? Icons.cast_connected_rounded : Icons.cast_rounded,
                size: glyphSize,
                color: tint,
                shadows: const [
                  Shadow(color: Color(0x66000000), blurRadius: 6),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> showCastSheet(
  BuildContext context, {
  required CastStore store,
  required CastMediaSource media,
  VoidCallback? onCastStarted,
}) => showOnsetSheet<void>(
  context: context,
  builder: (_) =>
      CastSheet(store: store, media: media, onCastStarted: onCastStarted),
);

class CastSheet extends StatefulWidget {
  const CastSheet({
    super.key,
    required this.store,
    required this.media,
    this.onCastStarted,
    this.searchTimeout = const Duration(seconds: 8),
  });

  final CastStore store;
  final CastMediaSource media;
  final VoidCallback? onCastStarted;
  final Duration searchTimeout;

  @override
  State<CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends State<CastSheet> {
  Timer? _searchTimer;
  var _searchedLongEnough = false;
  String? _connectingTo;
  String? _error;

  CastStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    unawaited(_store.beginDiscovery());
    _searchTimer = Timer(widget.searchTimeout, () {
      if (mounted) setState(() => _searchedLongEnough = true);
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    unawaited(_store.endDiscovery());
    super.dispose();
  }

  void _started() {
    widget.onCastStarted?.call();
    if (mounted) Navigator.maybePop(context);
  }

  Future<void> _castHere() async {
    final l = context.l10n;
    final media = widget.media();
    if (media == null) {
      setState(() => _error = l.castNotReady);
      return;
    }
    setState(() => _error = null);
    final loaded = await _store.castHere(media, onLoaded: _started);
    if (!mounted || loaded) return;
    setState(() => _error = l.castFailed);
  }

  Future<void> _castTo(CastDevice device) async {
    final l = context.l10n;
    final media = widget.media();
    if (media == null) {
      setState(() => _error = l.castNotReady);
      return;
    }
    setState(() {
      _error = null;
      _connectingTo = device.id;
    });
    final requested = await _store.castTo(device, media, onLoaded: _started);
    if (!mounted) return;
    if (!requested) {
      setState(() {
        _connectingTo = null;
        _error = l.castFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final l = context.l10n;
        final store = _store;
        final device = store.status.deviceName;
        final failed = store.loadFailed && _connectingTo != null;
        final error = _error ?? (failed ? l.castFailed : null);
        return ListView(
          shrinkWrap: true,
          children: [
            SheetSectionLabel(
              store.connected && device != null
                  ? l.castConnectedTo(device: device)
                  : l.castSheetTitle,
            ),
            ..._body(context, store),
            if (error != null)
              SheetStatusLine(busy: false, message: error, ok: false),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  List<Widget> _body(BuildContext context, CastStore store) {
    final l = context.l10n;
    if (store.available == false) {
      return [_CastNote(l.castUnavailable)];
    }
    if (store.connected) {
      return [
        SheetRow(
          key: const ValueKey('cast-this-video'),
          leading: const Icon(Icons.cast_connected_rounded, size: 22),
          label: l.castThisVideo,
          onTap: () => unawaited(_castHere()),
        ),
        SheetRow(
          key: const ValueKey('cast-stop'),
          leading: const Icon(Icons.stop_circle_outlined, size: 22),
          label: l.castStop,
          danger: true,
          onTap: () {
            unawaited(store.stopCasting());
            Navigator.maybePop(context);
          },
        ),
      ];
    }
    final devices = store.devices;
    if (devices.isEmpty) {
      return [
        if (!_searchedLongEnough) const SheetStatusLine(busy: true),
        _CastNote(_searchedLongEnough ? l.castNoDevices : l.castSearching),
      ];
    }
    return [
      for (final device in devices)
        SheetRow(
          key: ValueKey('cast-device-${device.id}'),
          leading: const Icon(Icons.tv_rounded, size: 22),
          label: device.name,
          trailing: _connectingTo == device.id
              ? Semantics(
                  label: l.castConnecting,
                  child: const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
          onTap: _connectingTo == null
              ? () => unawaited(_castTo(device))
              : null,
        ),
    ];
  }
}

class _CastNote extends StatelessWidget {
  const _CastNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Text(
      text,
      style: SheetText.body.copyWith(color: SheetColors.of(context).secondary),
    ),
  );
}
