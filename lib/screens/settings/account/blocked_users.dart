import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/widgets/settings_glyph.dart';
import 'package:frosty/screens/settings/widgets/settings_kit.dart';
import 'package:frosty/screens/settings/widgets/settings_page.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils.dart';
import 'package:frosty/widgets/sheet/onset_sheet.dart';

/// The viewer's blocked users (boards Parametres, ParametresTablette), each
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
      title: 'Unblock',
      message: 'Are you sure you want to unblock "$name"?',
      confirm: 'Yes',
      danger: false,
    );
    if (confirmed) await authStore.user.unblock(targetId: id);
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final colors = SettingsColors.of(context);
        final blocked = authStore.user.blockedUsers;
        if (blocked.isEmpty) {
          return SettingsGroupsView(
            onRefresh: _refresh,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 80),
                child: Column(
                  spacing: 12,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.card,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.trackRing,
                          width: FrostyTokens.hairlineWidth,
                        ),
                      ),
                      child: SettingsGlyph(
                        SettingsGlyphKind.ban,
                        size: 24,
                        color: colors.secondary,
                      ),
                    ),
                    Text(
                      'No blocked users',
                      style: TextStyle(
                        fontFamily: FrostyTokens.bodyFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.body,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return SettingsGroupsView(
          onRefresh: _refresh,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                SettingsSectionLabel('${blocked.length} blocked'),
                SettingsCard(
                  child: Column(
                    children: [
                      for (final (index, user) in blocked.indexed) ...[
                        if (index > 0)
                          Divider(
                            height: FrostyTokens.hairlineWidth,
                            thickness: FrostyTokens.hairlineWidth,
                            color: colors.hairline,
                          ),
                        _BlockedRow(
                          name: getReadableName(
                            user.displayName,
                            user.userLogin,
                          ),
                          onUnblock: (name) =>
                              _unblock(context, name: name, id: user.userId),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Text(
                    'Blocked users are removed from channel lists, search '
                    'results, and chat messages. Pull down to refresh.',
                    style: SettingsText.detail.copyWith(
                      height: 1.5,
                      color: colors.tertiary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _BlockedRow extends StatelessWidget {
  const _BlockedRow({required this.name, required this.onUnblock});

  final String name;
  final ValueChanged<String> onUnblock;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          spacing: 12,
          children: [
            InitialAvatar(name: name, size: 34),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SettingsText.row.copyWith(color: colors.text),
              ),
            ),
            Semantics(
              label: 'Unblock $name',
              button: true,
              excludeSemantics: true,
              child: SettingsButton(
                label: 'Unblock',
                onPressed: () => onUnblock(name),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
