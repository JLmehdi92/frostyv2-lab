import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/onboarding/onboarding_parts.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/theme.dart';

/// One thing the login lets ONSET do, in the viewer's language, and the
/// Twitch scopes behind it ([AuthBase.loginScopes]; a test checks that
/// every scope is listed).
class OnboardingPermission {
  const OnboardingPermission({
    required this.glyph,
    required this.title,
    required this.detail,
    required this.scopes,
  });

  final OnboardingGlyphKind glyph;
  final String Function(AppLocalizations l) title;
  final String Function(AppLocalizations l) detail;
  final List<String> scopes;
}

/// What the Log in step lists under "What you will authorize".
const onboardingPermissions = [
  OnboardingPermission(
    glyph: OnboardingGlyphKind.chat,
    title: _chatTitle,
    detail: _chatDetail,
    scopes: ['chat:read', 'chat:edit', 'user:read:chat'],
  ),
  OnboardingPermission(
    glyph: OnboardingGlyphKind.heart,
    title: _followsTitle,
    detail: _followsDetail,
    scopes: ['user:read:follows'],
  ),
  OnboardingPermission(
    glyph: OnboardingGlyphKind.smile,
    title: _emotesTitle,
    detail: _emotesDetail,
    scopes: ['user:read:emotes'],
  ),
  OnboardingPermission(
    glyph: OnboardingGlyphKind.send,
    title: _whispersTitle,
    detail: _whispersDetail,
    scopes: ['user:manage:whispers'],
  ),
  OnboardingPermission(
    glyph: OnboardingGlyphKind.shield,
    title: _moderationTitle,
    detail: _moderationDetail,
    scopes: [
      'moderator:manage:banned_users',
      'moderator:manage:chat_messages',
      'moderator:manage:chat_settings',
      'moderator:manage:warnings',
      'moderator:read:followers',
      'moderator:manage:announcements',
      'moderator:manage:shoutouts',
      'moderator:manage:shield_mode',
      'moderator:manage:automod',
      'moderator:manage:blocked_terms',
      'moderator:manage:unban_requests',
      'moderator:manage:suspicious_users',
      'moderator:read:moderators',
      'moderator:read:vips',
    ],
  ),
  OnboardingPermission(
    glyph: OnboardingGlyphKind.scissors,
    title: _clipsTitle,
    detail: _clipsDetail,
    scopes: ['clips:edit'],
  ),
  OnboardingPermission(
    glyph: OnboardingGlyphKind.userX,
    title: _blocksTitle,
    detail: _blocksDetail,
    scopes: [
      'user:read:blocked_users',
      'user:manage:blocked_users',
      'user:manage:chat_color',
    ],
  ),
];

String _chatTitle(AppLocalizations l) => l.onboardingPermissionChatTitle;
String _chatDetail(AppLocalizations l) => l.onboardingPermissionChatDetail;
String _followsTitle(AppLocalizations l) => l.onboardingPermissionFollowsTitle;
String _followsDetail(AppLocalizations l) =>
    l.onboardingPermissionFollowsDetail;
String _emotesTitle(AppLocalizations l) => l.onboardingPermissionEmotesTitle;
String _emotesDetail(AppLocalizations l) => l.onboardingPermissionEmotesDetail;
String _whispersTitle(AppLocalizations l) =>
    l.onboardingPermissionWhispersTitle;
String _whispersDetail(AppLocalizations l) =>
    l.onboardingPermissionWhispersDetail;
String _moderationTitle(AppLocalizations l) =>
    l.onboardingPermissionModerationTitle;
String _moderationDetail(AppLocalizations l) =>
    l.onboardingPermissionModerationDetail;
String _clipsTitle(AppLocalizations l) => l.onboardingPermissionClipsTitle;
String _clipsDetail(AppLocalizations l) => l.onboardingPermissionClipsDetail;
String _blocksTitle(AppLocalizations l) => l.onboardingPermissionBlocksTitle;
String _blocksDetail(AppLocalizations l) => l.onboardingPermissionBlocksDetail;

/// Step 2, Log in: what the login
/// allows, in plain words, before Twitch opens; "Connect with Twitch" opens
/// the Twitch page, "Skip" goes on without an account.
class OnboardingLoginStep extends StatelessWidget {
  const OnboardingLoginStep({
    super.key,
    required this.layout,
    required this.accent,
    required this.onConnect,
    required this.onSkip,
  });

  final OnboardingStepLayout layout;
  final Color accent;
  final VoidCallback onConnect;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final tablet = layout.tablet;
    final l = context.l10n;
    return OnboardingStepFrame(
      layout: layout,
      content: [
        StepRise(
          order: 1,
          child: Semantics(
            header: true,
            child: Text(
              l.onboardingLoginTitle,
              style: OnboardingType.title(tablet: tablet),
            ),
          ),
        ),
        SizedBox(height: tablet ? 12 : 10),
        StepRise(
          order: 2,
          child: Text(
            l.onboardingLoginLead,
            style: OnboardingType.lead(tablet: tablet),
          ),
        ),
        SizedBox(height: tablet ? 24 : 20),
        StepRise(
          order: 3,
          child: tablet ? const _PermissionGrid() : const _PermissionList(),
        ),
        if (tablet) ...[
          const SizedBox(height: 18),
          StepRise(
            order: 4,
            child: Text(
              l.onboardingLoginDisclaimer,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: OnboardingColors.tertiary,
              ),
            ),
          ),
        ],
      ],
      footer: OnboardingFooter(
        tablet: tablet,
        primaryWidth: 250,
        note: StepRise(
          order: 4,
          child: Text(
            l.onboardingLoginDisclaimer,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: OnboardingColors.tertiary,
            ),
          ),
        ),
        primary: StepRise(
          order: tablet ? 6 : 5,
          child: OnboardingButton(
            label: l.commonConnectWithTwitch,
            accent: accent,
            leading: OnboardingGlyphKind.login,
            onPressed: onConnect,
          ),
        ),
        secondary: StepRise(
          order: tablet ? 5 : 6,
          child: OnboardingTextButton(
            label: l.onboardingLoginSkip,
            height: tablet ? 52 : 44,
            onPressed: onSkip,
          ),
        ),
      ),
    );
  }
}

/// The phone's list: one card, a row per permission.
class _PermissionList extends StatelessWidget {
  const _PermissionList();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: onboardingCard(),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Semantics(
              header: true,
              child: Text(
                context.l10n.onboardingLoginAuthorizeHeader.toUpperCase(),
                style: OnboardingType.eyebrow,
              ),
            ),
          ),
          for (final (i, permission) in onboardingPermissions.indexed)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : const Border(
                        top: BorderSide(
                          color: OnboardingColors.divider,
                          width: OnsetTokens.hairlineWidth,
                        ),
                      ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _PermissionRow(permission: permission, tile: 32),
              ),
            ),
        ],
      ),
    );
  }
}

/// The tablet's grid: two columns of cards.
class _PermissionGrid extends StatelessWidget {
  const _PermissionGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            header: true,
            child: Text(
              context.l10n.onboardingLoginAuthorizeHeader.toUpperCase(),
              style: OnboardingType.eyebrow,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final permission in onboardingPermissions)
                  SizedBox(
                    width: width,
                    child: Container(
                      decoration: onboardingCard(radius: 14),
                      padding: const EdgeInsets.all(12),
                      child: _PermissionRow(permission: permission, tile: 36),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.permission, required this.tile});

  final OnboardingPermission permission;
  final double tile;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: tile,
            height: tile,
            decoration: BoxDecoration(
              color: OnboardingColors.raised,
              borderRadius: BorderRadius.circular(tile == 32 ? 9 : 10),
            ),
            alignment: Alignment.center,
            child: OnboardingGlyph(
              permission.glyph,
              size: 16,
              color: OnboardingColors.body,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: tile == 32 ? 1 : 2,
              children: [
                Text(
                  permission.title(context.l10n),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: OnboardingColors.text,
                  ),
                ),
                Text(
                  permission.detail(context.l10n),
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: OnboardingColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
