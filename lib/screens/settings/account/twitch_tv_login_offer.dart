import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/twitch_tv_session_store.dart';
import 'package:onset/widgets/follow/follow_flow.dart';

class TwitchTvLoginOffer {
  TwitchTvLoginOffer({required this.store, required this.context});

  final TwitchTvSessionStore store;
  final BuildContext? Function() context;

  var _restored = false;
  String? _lastAccount;

  Future<void> accountChanged(String? id) async {
    final firstCall = !_restored;
    _restored = true;
    if (id == null) {
      store.detach();
      return;
    }
    final switched = _lastAccount != null && _lastAccount != id;
    _lastAccount = id;
    await store.attach(id);
    if (_lastAccount != id) return;
    if (firstCall || store.status != TwitchTvSessionStatus.disconnected) {
      return;
    }
    if (!switched && !await store.shouldPrompt()) return;
    final from = context();
    if (from == null || !from.mounted) return;
    await store.markPrompted();
    if (!from.mounted) return;
    unawaited(
      FollowFlow.offerTvSession(
        from,
        store,
        message: from.l10n.twitchTvLoginOfferBody,
      ),
    );
  }
}
