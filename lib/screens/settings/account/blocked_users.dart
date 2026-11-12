import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_name_list.dart';
import 'package:onset/utils/common_utils.dart';

/// The viewer's blocked users, each
/// with "Unblock"; pull to refresh.
class BlockedUsers extends StatelessWidget {
  final AuthStore authStore;

  const BlockedUsers({super.key, required this.authStore});

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    await authStore.user.refreshBlockedUsers();
  }

  Future<void> _unblock(
    BuildContext context, {
    required String name,
    required String id,
  }) async {
    final confirmed = await confirmSettingsAction(
      context,
      title: context.l10n.settingsUnblock,
      message: context.l10n.settingsUnblockMessage(name: name),
      confirm: context.l10n.commonYes,
      danger: false,
    );
    if (confirmed) await authStore.user.unblock(targetId: id);
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final l = context.l10n;
        final blocked = authStore.user.blockedUsers;
        return SettingsNameList(
          names: [
            for (final user in blocked)
              getReadableName(user.displayName, user.userLogin),
          ],
          emptyGlyph: SettingsGlyphKind.ban,
          emptyText: l.settingsNoBlockedUsers,
          countText: l.settingsBlockedCount(count: blocked.length),
          note: l.settingsBlockedNote,
          onRefresh: _refresh,
          actionLabel: l.settingsUnblock,
          actionSemantics: (name) => l.settingsUnblockName(name: name),
          onAction: (index, name) =>
              _unblock(context, name: name, id: blocked[index].userId),
        );
      },
    );
  }
}
