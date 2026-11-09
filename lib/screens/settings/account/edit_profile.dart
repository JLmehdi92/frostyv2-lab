import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:onset/apis/twitch_account_gql_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/profile_edit.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/twitch_web_page.dart';
import 'package:provider/provider.dart';

class EditProfileActions {
  const EditProfileActions({
    required this.profile,
    required this.renameStatus,
    required this.socialLinks,
    required this.availability,
    required this.setDisplayName,
    required this.setDescription,
    required this.changeUsername,
    required this.addLink,
    required this.updateLink,
    required this.deleteLink,
    this.onAccountChanged,
  });

  factory EditProfileActions.of(
    TwitchAccountGqlService service, {
    required String Function() token,
    Future<void> Function()? onAccountChanged,
  }) {
    late String userId;
    return EditProfileActions(
      profile: () async {
        final profile = await service.profile(authToken: token());
        if (profile != null) userId = profile.id;
        return profile;
      },
      renameStatus: () => service.renameStatus(authToken: token()),
      socialLinks: () => service.socialLinks(authToken: token()),
      availability: (login) =>
          service.usernameAvailability(login: login, authToken: token()),
      setDisplayName: (name) => service.updateDisplayName(
        userId: userId,
        displayName: name,
        authToken: token(),
      ),
      setDescription: (text) => service.updateDescription(
        userId: userId,
        description: text,
        authToken: token(),
      ),
      changeUsername: (login) => service.changeUsername(
        userId: userId,
        login: login,
        authToken: token(),
      ),
      addLink: (title, url) => service.addSocialLink(
        channelId: userId,
        title: title,
        url: url,
        authToken: token(),
      ),
      updateLink: (id, title, url) => service.updateSocialLink(
        channelId: userId,
        linkId: id,
        title: title,
        url: url,
        authToken: token(),
      ),
      deleteLink: (id) => service.deleteSocialLink(
        channelId: userId,
        linkId: id,
        authToken: token(),
      ),
      onAccountChanged: onAccountChanged,
    );
  }

  factory EditProfileActions.unavailable() {
    const failed = AccountEditResult<Never>.failed();
    return EditProfileActions(
      profile: () async => null,
      renameStatus: () async => null,
      socialLinks: () async => null,
      availability: (_) async => UsernameAvailability.unknown,
      setDisplayName: (_) async => failed,
      setDescription: (_) async => failed,
      changeUsername: (_) async => failed,
      addLink: (_, _) async => failed,
      updateLink: (_, _, _) async => failed,
      deleteLink: (_) async => failed,
    );
  }

  final Future<EditableProfile?> Function() profile;
  final Future<LoginRenameStatus?> Function() renameStatus;
  final Future<List<SocialLink>?> Function() socialLinks;
  final Future<UsernameAvailability> Function(String login) availability;
  final Future<AccountEditResult<EditableProfile>> Function(String name)
  setDisplayName;
  final Future<AccountEditResult<EditableProfile>> Function(String text)
  setDescription;
  final Future<AccountEditResult<EditableProfile>> Function(String login)
  changeUsername;
  final Future<AccountEditResult<List<SocialLink>>> Function(
    String title,
    String url,
  )
  addLink;
  final Future<AccountEditResult<List<SocialLink>>> Function(
    String id,
    String title,
    String url,
  )
  updateLink;
  final Future<AccountEditResult<List<SocialLink>>> Function(String id)
  deleteLink;
  final Future<void> Function()? onAccountChanged;
}

final twitchProfileSettingsUrl = Uri.https(
  'www.twitch.tv',
  '/settings/profile',
);

class EditProfile extends StatefulWidget {
  const EditProfile({super.key, required this.actions});

  static const displayNameKey = ValueKey('edit-profile-display-name');
  static const bioKey = ValueKey('edit-profile-bio');
  static const usernameKey = ValueKey('edit-profile-username');
  static const addLinkKey = ValueKey('edit-profile-add-link');
  static const imagesKey = ValueKey('edit-profile-images');
  static const fieldKey = ValueKey('edit-profile-field');
  static const secondFieldKey = ValueKey('edit-profile-field-2');
  static const saveKey = ValueKey('edit-profile-save');
  static const deleteKey = ValueKey('edit-profile-delete');
  static const checkKey = ValueKey('edit-profile-check');
  static ValueKey<String> linkKey(String id) => ValueKey('edit-profile-$id');

  final EditProfileActions actions;

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  EditableProfile? _profile;
  List<SocialLink>? _links;
  LoginRenameStatus? _renameStatus;
  var _loading = true;

  EditProfileActions get _actions => widget.actions;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final profile = await _actions.profile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = profile != null;
    });
    if (profile == null) return;
    final results = await Future.wait<Object?>([
      _actions.socialLinks(),
      _actions.renameStatus(),
    ]);
    if (!mounted) return;
    setState(() {
      _links = results[0] as List<SocialLink>?;
      _renameStatus = results[1] as LoginRenameStatus?;
      _loading = false;
    });
  }

  void _openOnTwitch() => unawaited(
    TwitchWebPage.open(
      context,
      title: context.l10n.editProfileTitle,
      url: twitchProfileSettingsUrl,
    ),
  );

  void _say(String text) => ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  String _failure(AccountEditResult<Object?> result) {
    final l = context.l10n;
    return switch (result.outcome) {
      AccountEditOutcome.refused => l.editProfileRefused(
        code: result.code ?? 'UNKNOWN',
      ),
      AccountEditOutcome.integrityRefused => l.editProfileIntegrity,
      AccountEditOutcome.signedOut => l.editProfileSignedOut,
      _ => l.editProfileFailed,
    };
  }

  Future<void> _applyProfile(
    Future<AccountEditResult<EditableProfile>> change,
    String done,
  ) async {
    final result = await change;
    if (!mounted) return;
    final profile = result.value;
    if (result.succeeded && profile != null) {
      setState(() => _profile = profile);
      _say(done);
      unawaited(_actions.onAccountChanged?.call());
    } else {
      _say(_failure(result));
    }
  }

  Future<void> _applyLinks(
    Future<AccountEditResult<List<SocialLink>>> change,
    String done,
  ) async {
    final result = await change;
    if (!mounted) return;
    final links = result.value;
    if (result.succeeded && links != null) {
      setState(() => _links = links);
      _say(done);
    } else {
      _say(_failure(result));
    }
  }

  Future<void> _editDisplayName(EditableProfile profile) async {
    final l = context.l10n;
    final value = await _askText(
      title: l.editProfileDisplayName,
      message: l.editProfileDisplayNameHelp(login: profile.login),
      initial: profile.displayName,
      maxLength: 25,
      valid: (text) =>
          text.trim().isNotEmpty && text.trim() != profile.displayName,
    );
    if (value == null || !mounted) return;
    await _applyProfile(
      _actions.setDisplayName(value),
      l.editProfileDisplayNameSaved,
    );
  }

  Future<void> _editBio(EditableProfile profile) async {
    final l = context.l10n;
    final value = await _askText(
      title: l.editProfileBio,
      initial: profile.description,
      maxLength: EditableProfile.maxDescriptionLength,
      maxLines: 5,
      counter: true,
      valid: (text) => text.trim() != profile.description.trim(),
    );
    if (value == null || !mounted) return;
    await _applyProfile(_actions.setDescription(value), l.editProfileBioSaved);
  }

  Future<void> _editUsername(EditableProfile profile) async {
    final l = context.l10n;
    final status = _renameStatus;
    if (status != null && !status.eligible) {
      final at = status.eligibleAt;
      await showDialog<void>(
        context: context,
        barrierColor: kSheetScrim,
        builder: (context) => SettingsDialog(
          title: l.editProfileUsername,
          message: at == null
              ? l.editProfileUsernameNotYet
              : l.editProfileUsernameNotUntil(
                  date: DateFormat.yMMMMd(l.localeName).format(at.toLocal()),
                ),
          actions: [
            SettingsButton(
              label: l.commonClose,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }
    final login = await showDialog<String>(
      context: context,
      barrierColor: kSheetScrim,
      builder: (context) => _UsernameDialog(
        current: profile.login,
        availability: _actions.availability,
      ),
    );
    if (login == null || !mounted) return;
    final confirmed = await confirmSettingsAction(
      context,
      title: l.editProfileUsernameConfirmTitle(login: login),
      message: l.editProfileUsernameConfirmBody,
      confirm: l.editProfileUsernameChange,
    );
    if (!confirmed || !mounted) return;
    await _applyProfile(
      _actions.changeUsername(login),
      l.editProfileUsernameSaved(login: login),
    );
    final fresh = await _actions.renameStatus();
    if (mounted && fresh != null) setState(() => _renameStatus = fresh);
  }

  Future<void> _editLink([SocialLink? link]) async {
    final l = context.l10n;
    final result = await showDialog<_LinkEdit>(
      context: context,
      barrierColor: kSheetScrim,
      builder: (context) => _LinkDialog(link: link),
    );
    if (result == null || !mounted) return;
    if (result.delete && link != null) {
      final confirmed = await confirmSettingsAction(
        context,
        title: l.editProfileLinkDeleteTitle(title: link.title),
        message: l.editProfileLinkDeleteBody,
        confirm: l.editProfileLinkDelete,
      );
      if (!confirmed || !mounted) return;
      await _applyLinks(_actions.deleteLink(link.id), l.editProfileLinkDeleted);
      return;
    }
    await _applyLinks(
      link == null
          ? _actions.addLink(result.title, result.url)
          : _actions.updateLink(link.id, result.title, result.url),
      l.editProfileLinkSaved,
    );
  }

  Future<String?> _askText({
    required String title,
    String? message,
    required String initial,
    required int maxLength,
    required bool Function(String text) valid,
    int maxLines = 1,
    bool counter = false,
  }) => showDialog<String>(
    context: context,
    barrierColor: kSheetScrim,
    builder: (context) => _TextDialog(
      title: title,
      message: message,
      initial: initial,
      maxLength: maxLength,
      maxLines: maxLines,
      counter: counter,
      valid: valid,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SettingsColors.of(context);
    final profile = _profile;
    if (profile == null) {
      return SettingsGroupsView(
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            SettingsNote(l.editProfileUnavailable),
          SettingsGroup(
            children: [
              SettingsRow(
                glyph: SettingsGlyphKind.user,
                title: l.editProfileOnTwitch,
                end: SettingsRowEnd.external,
                onTap: _openOnTwitch,
              ),
            ],
          ),
        ],
      );
    }
    final links = _links;
    return SettingsGroupsView(
      children: [
        SettingsGroup(
          children: [
            _ProfileImages(profile: profile),
            SettingsRow(
              key: EditProfile.imagesKey,
              glyph: SettingsGlyphKind.user,
              title: l.editProfileImages,
              subtitle: Text(
                l.editProfileImagesHelp,
                style: SettingsText.detail.copyWith(color: colors.secondary),
              ),
              end: SettingsRowEnd.external,
              onTap: _openOnTwitch,
            ),
          ],
        ),
        SettingsGroup(
          title: l.editProfileAbout,
          children: [
            SettingsRow(
              key: EditProfile.displayNameKey,
              title: l.editProfileDisplayName,
              value: profile.displayName,
              end: SettingsRowEnd.chevron,
              onTap: () => unawaited(_editDisplayName(profile)),
            ),
            SettingsRow(
              key: EditProfile.usernameKey,
              title: l.editProfileUsername,
              value: '@${profile.login}',
              end: SettingsRowEnd.chevron,
              onTap: () => unawaited(_editUsername(profile)),
            ),
            SettingsRow(
              key: EditProfile.bioKey,
              title: l.editProfileBio,
              subtitle: Text(
                profile.description.isEmpty
                    ? l.editProfileBioEmpty
                    : profile.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: SettingsText.detail.copyWith(color: colors.secondary),
              ),
              end: SettingsRowEnd.chevron,
              onTap: () => unawaited(_editBio(profile)),
            ),
          ],
        ),
        if (links == null)
          SettingsNote(l.editProfileLinksUnavailable)
        else
          SettingsGroup(
            title: l.editProfileLinks,
            children: [
              for (final link in links)
                SettingsRow(
                  key: EditProfile.linkKey(link.id),
                  glyph: SettingsGlyphKind.link,
                  title: link.title,
                  subtitle: Text(
                    link.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SettingsText.detail.copyWith(
                      color: colors.secondary,
                    ),
                  ),
                  end: SettingsRowEnd.chevron,
                  onTap: () => unawaited(_editLink(link)),
                ),
              if (links.length < EditableProfile.maxSocialLinks)
                SettingsRow(
                  key: EditProfile.addLinkKey,
                  glyph: SettingsGlyphKind.link,
                  title: l.editProfileLinkAdd,
                  end: SettingsRowEnd.chevron,
                  onTap: () => unawaited(_editLink()),
                )
              else
                SettingsNote(l.editProfileLinksFull),
            ],
          ),
      ],
    );
  }
}

class _ProfileImages extends StatelessWidget {
  const _ProfileImages({required this.profile});

  final EditableProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final banner = profile.bannerImageUrl;
    final avatar = profile.profileImageUrl;
    final initial = Container(
      color: colors.tile,
      alignment: Alignment.center,
      child: Text(
        profile.displayName.characters.first.toUpperCase(),
        style: SettingsText.row.copyWith(color: colors.secondary, fontSize: 24),
      ),
    );
    return ExcludeSemantics(
      child: SizedBox(
        height: 132,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              bottom: 36,
              child: banner == null
                  ? ColoredBox(color: colors.tile)
                  : OnsetCachedNetworkImage(
                      imageUrl: banner,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => ColoredBox(color: colors.tile),
                      errorWidget: (_, _, _) => ColoredBox(color: colors.tile),
                    ),
            ),
            Positioned(
              left: 16,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: colors.card,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: SizedBox.square(
                    dimension: 64,
                    child: avatar == null
                        ? initial
                        : OnsetCachedNetworkImage(
                            imageUrl: avatar,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => initial,
                            errorWidget: (_, _, _) => initial,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.initial,
    required this.maxLength,
    required this.valid,
    this.message,
    this.maxLines = 1,
    this.counter = false,
  });

  final String title;
  final String? message;
  final String initial;
  final int maxLength;
  final int maxLines;
  final bool counter;
  final bool Function(String text) valid;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final valid = widget.valid(_controller.text);
    return SettingsDialog(
      title: widget.title,
      message: widget.message,
      content: SheetTextField(
        key: EditProfile.fieldKey,
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        maxLines: widget.maxLines,
        counter: widget.counter,
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        SettingsButton(
          label: l.commonCancel,
          onPressed: () => Navigator.pop(context),
        ),
        SettingsButton(
          key: EditProfile.saveKey,
          label: l.editProfileSave,
          tone: SettingsButtonTone.primary,
          onPressed: valid
              ? () => Navigator.pop(context, _controller.text.trim())
              : null,
        ),
      ],
    );
  }
}

class _UsernameDialog extends StatefulWidget {
  const _UsernameDialog({required this.current, required this.availability});

  final String current;
  final Future<UsernameAvailability> Function(String login) availability;

  @override
  State<_UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<_UsernameDialog> {
  final _controller = TextEditingController();
  UsernameAvailability? _checked;
  String? _checkedLogin;
  var _checking = false;

  String get _login => _controller.text.trim();

  bool get _wellFormed =>
      TwitchAccountGqlService.isValidLogin(_login) &&
      _login.toLowerCase() != widget.current.toLowerCase();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final login = _login;
    setState(() => _checking = true);
    final result = await widget.availability(login);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _checked = result;
      _checkedLogin = login;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SettingsColors.of(context);
    final checked = _checkedLogin == _login ? _checked : null;
    final status = !_wellFormed && _login.isNotEmpty
        ? (l.editProfileUsernameRules, colors.danger)
        : switch (checked) {
            UsernameAvailability.available => (
              l.editProfileUsernameAvailable,
              colors.text,
            ),
            UsernameAvailability.taken => (
              l.editProfileUsernameTaken,
              colors.danger,
            ),
            UsernameAvailability.unknown => (
              l.editProfileUsernameUnknown,
              colors.secondary,
            ),
            null => null,
          };
    return SettingsDialog(
      title: l.editProfileUsername,
      message: l.editProfileUsernameHelp,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          SheetTextField(
            key: EditProfile.fieldKey,
            controller: _controller,
            autofocus: true,
            maxLength: 25,
            hint: widget.current,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9_]')),
            ],
            onChanged: (_) => setState(() {}),
          ),
          if (status case (final text, final color))
            Text(text, style: SettingsText.detail.copyWith(color: color)),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SettingsButton(
              key: EditProfile.checkKey,
              label: l.editProfileUsernameCheck,
              onPressed: _wellFormed && !_checking
                  ? () => unawaited(_check())
                  : null,
            ),
          ),
        ],
      ),
      actions: [
        SettingsButton(
          label: l.commonCancel,
          onPressed: () => Navigator.pop(context),
        ),
        SettingsButton(
          key: EditProfile.saveKey,
          label: l.editProfileContinue,
          tone: SettingsButtonTone.primary,
          onPressed:
              _wellFormed &&
                  checked != null &&
                  checked != UsernameAvailability.taken
              ? () => Navigator.pop(context, _login.toLowerCase())
              : null,
        ),
      ],
    );
  }
}

class _LinkEdit {
  const _LinkEdit({this.title = '', this.url = '', this.delete = false});

  final String title;
  final String url;
  final bool delete;
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({this.link});

  final SocialLink? link;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final _title = TextEditingController(text: widget.link?.title ?? '');
  late final _url = TextEditingController(text: widget.link?.url ?? '');

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  bool get _valid =>
      _title.text.trim().isNotEmpty && SocialLink.isValidUrl(_url.text);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final link = widget.link;
    return SettingsDialog(
      title: link == null ? l.editProfileLinkAdd : l.editProfileLinkEdit,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          SheetTextField(
            key: EditProfile.fieldKey,
            controller: _title,
            label: l.editProfileLinkTitle,
            maxLength: SocialLink.maxTitleLength,
            onChanged: (_) => setState(() {}),
          ),
          SheetTextField(
            key: EditProfile.secondFieldKey,
            controller: _url,
            label: l.editProfileLinkUrl,
            hint: 'https://',
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        if (link != null)
          SettingsButton(
            key: EditProfile.deleteKey,
            label: l.editProfileLinkDelete,
            onPressed: () =>
                Navigator.pop(context, const _LinkEdit(delete: true)),
          ),
        SettingsButton(
          label: l.commonCancel,
          onPressed: () => Navigator.pop(context),
        ),
        SettingsButton(
          key: EditProfile.saveKey,
          label: l.editProfileSave,
          tone: SettingsButtonTone.primary,
          onPressed: _valid
              ? () => Navigator.pop(
                  context,
                  _LinkEdit(title: _title.text.trim(), url: _url.text.trim()),
                )
              : null,
        ),
      ],
    );
  }
}

class EditProfileHost extends StatelessWidget {
  const EditProfileHost({super.key, required this.authStore});

  final AuthStore authStore;

  @override
  Widget build(BuildContext context) {
    final service = context.read<TwitchAccountGqlService?>();
    return EditProfile(
      actions: service == null
          ? EditProfileActions.unavailable()
          : EditProfileActions.of(
              service,
              token: () => authStore.twitchWebToken ?? '',
              onAccountChanged: () async {
                try {
                  await authStore.user.init();
                } catch (e) {
                  debugPrint('Account refresh after a profile edit failed: $e');
                }
              },
            ),
    );
  }
}

void openEditProfile(BuildContext context, AuthStore authStore) => unawaited(
  openSettingsPage(
    context,
    id: SettingsPageId.editProfile,
    builder: (context) => EditProfileHost(authStore: authStore),
  ),
);
