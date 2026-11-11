import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/twitch_tv_session_store.dart';
import 'package:onset/widgets/follow/follow_flow.dart';

class TwitchTvLoginOffer {
  TwitchTvLoginOffer({
    required this.store,
    required this.context,
    required this.logins,
  });

  final TwitchTvSessionStore store;
  final BuildContext? Function() context;
  final int Function() logins;

  var _seq = 0;
  int? _answeredLogins;
  String? _lastAccount;
  BuildContext? _openOffer;

  Future<void> accountChanged(String? id) async {
    final seq = ++_seq;
    _answeredLogins ??= logins();
    _closeOffer();
    if (id == null) {
      store.detach();
      return;
    }
    final switched = _lastAccount != null && _lastAccount != id;
    _lastAccount = id;
    await store.attach(id);
    if (seq != _seq) return;
    final loginCount = logins();
    final newLogin = loginCount > _answeredLogins!;
    _answeredLogins = loginCount;
    if (!newLogin) return;
    if (store.status != TwitchTvSessionStatus.disconnected) return;
    if (!switched && !await store.shouldPrompt()) return;
    if (seq != _seq) return;
    final from = context();
    if (from == null || !from.mounted) return;
    await store.markPrompted();
    if (seq != _seq || !from.mounted) return;
    unawaited(
      FollowFlow.offerTvSession(
        from,
        store,
        message: from.l10n.twitchTvLoginOfferBody,
        onShown: (dialog) => _openOffer = dialog,
      ).whenComplete(() {
        if (seq == _seq) _openOffer = null;
      }),
    );
  }

  void _closeOffer() {
    final dialog = _openOffer;
    _openOffer = null;
    if (dialog == null || !dialog.mounted) return;
    final route = ModalRoute.of(dialog);
    if (route == null || !route.isActive) return;
    Navigator.of(dialog).removeRoute(route);
  }
}
