import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/profile_edit.dart';
import 'package:onset/screens/settings/account/edit_profile.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/widgets/twitch_web_page.dart';

import '../../helpers/l10n.dart';

const profileFixture = EditableProfile(
  id: '1000',
  login: 'caster',
  displayName: 'Caster',
  description: 'Speedruns on weekends.',
);

const linkFixture = SocialLink(
  id: 'a',
  title: 'YouTube',
  url: 'https://youtube.com/@caster',
);

class Calls {
  final log = <String>[];
}

EditProfileActions profileActions(
  Calls calls, {
  EditableProfile? profile = profileFixture,
  List<SocialLink>? links = const [linkFixture],
  LoginRenameStatus? rename = const LoginRenameStatus(eligible: true),
  UsernameAvailability availability = UsernameAvailability.available,
  AccountEditResult<EditableProfile>? profileResult,
  void Function()? onAccountChanged,
}) {
  AccountEditResult<EditableProfile> ok(EditableProfile p) =>
      profileResult ?? AccountEditResult(AccountEditOutcome.done, value: p);
  return EditProfileActions(
    profile: () async => profile,
    renameStatus: () async => rename,
    socialLinks: () async => links,
    availability: (login) async {
      calls.log.add('check $login');
      return availability;
    },
    setDisplayName: (name) async {
      calls.log.add('name $name');
      return ok(
        EditableProfile(
          id: '1000',
          login: 'caster',
          displayName: name,
          description: profileFixture.description,
        ),
      );
    },
    setDescription: (text) async {
      calls.log.add('bio $text');
      return ok(
        EditableProfile(
          id: '1000',
          login: 'caster',
          displayName: 'Caster',
          description: text,
        ),
      );
    },
    changeUsername: (login) async {
      calls.log.add('login $login');
      return ok(
        EditableProfile(
          id: '1000',
          login: login,
          displayName: login,
          description: '',
        ),
      );
    },
    addLink: (title, url) async {
      calls.log.add('add $title $url');
      return AccountEditResult(
        AccountEditOutcome.done,
        value: [
          linkFixture,
          SocialLink(id: 'b', title: title, url: url),
        ],
      );
    },
    updateLink: (id, title, url) async {
      calls.log.add('update $id');
      return const AccountEditResult(
        AccountEditOutcome.done,
        value: [linkFixture],
      );
    },
    deleteLink: (id) async {
      calls.log.add('delete $id');
      return const AccountEditResult(AccountEditOutcome.done, value: []);
    },
    onAccountChanged: () async => onAccountChanged?.call(),
  );
}

Future<void> pumpEditProfile(
  WidgetTester tester,
  EditProfileActions actions, {
  Locale locale = en,
  Size size = const Size(390, 844),
}) async {
  await pumpLocalized(
    tester,
    Builder(
      builder: (context) => SettingsScaffold(
        title: SettingsPageId.editProfile.title(context.l10n),
        body: EditProfile(actions: actions),
      ),
    ),
    locale: locale,
    size: size,
  );
  await tester.pump();
  await tester.pump();
}

Finder fieldOf(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(TextField));

void main() {
  tearDown(() => TwitchWebPage.debugBody = null);

  testWidgets('shows the profile and its links', (tester) async {
    await pumpEditProfile(tester, profileActions(Calls()));
    expect(find.text('Caster'), findsOneWidget);
    expect(find.text('@caster'), findsOneWidget);
    expect(find.text('Speedruns on weekends.'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.byKey(EditProfile.addLinkKey), findsOneWidget);
  });

  testWidgets('saves a new display name on Save only', (tester) async {
    final calls = Calls();
    var refreshed = 0;
    await pumpEditProfile(
      tester,
      profileActions(calls, onAccountChanged: () => refreshed++),
    );
    await tester.tap(find.byKey(EditProfile.displayNameKey));
    await tester.pumpAndSettle();
    await tester.enterText(fieldOf(EditProfile.fieldKey), 'CASTER');
    await tester.pump();
    expect(calls.log, isEmpty);
    await tester.tap(find.byKey(EditProfile.saveKey));
    await tester.pumpAndSettle();
    expect(calls.log, ['name CASTER']);
    expect(find.text('CASTER'), findsOneWidget);
    expect(find.text('Display name updated'), findsOneWidget);
    expect(refreshed, 1);
  });

  testWidgets('Cancel changes nothing', (tester) async {
    final calls = Calls();
    await pumpEditProfile(tester, profileActions(calls));
    await tester.tap(find.byKey(EditProfile.bioKey));
    await tester.pumpAndSettle();
    await tester.enterText(fieldOf(EditProfile.fieldKey), 'Other');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls.log, isEmpty);
    expect(find.text('Speedruns on weekends.'), findsOneWidget);
  });

  testWidgets('a refusal says why and keeps the old value', (tester) async {
    await pumpEditProfile(
      tester,
      profileActions(
        Calls(),
        profileResult: const AccountEditResult(
          AccountEditOutcome.refused,
          code: 'DESCRIPTION_FAILED_MODERATION',
        ),
      ),
    );
    await tester.tap(find.byKey(EditProfile.bioKey));
    await tester.pumpAndSettle();
    await tester.enterText(fieldOf(EditProfile.fieldKey), 'Bad words');
    await tester.pump();
    await tester.tap(find.byKey(EditProfile.saveKey));
    await tester.pumpAndSettle();
    expect(find.text('This bio didn’t pass moderation.'), findsOneWidget);
    expect(find.text('Speedruns on weekends.'), findsOneWidget);
  });

  testWidgets('a username changes after the check and a confirmation', (
    tester,
  ) async {
    final calls = Calls();
    await pumpEditProfile(tester, profileActions(calls));
    await tester.tap(find.byKey(EditProfile.usernameKey));
    await tester.pumpAndSettle();
    await tester.enterText(fieldOf(EditProfile.fieldKey), 'New_Name');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(EditProfile.saveKey),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(EditProfile.checkKey));
    await tester.pumpAndSettle();
    expect(find.text('This username is available.'), findsOneWidget);
    await tester.tap(find.byKey(EditProfile.saveKey));
    await tester.pumpAndSettle();
    expect(find.text('Change your username to new_name?'), findsOneWidget);
    expect(calls.log, ['check New_Name']);
    await tester.tap(find.text('Change username'));
    await tester.pumpAndSettle();
    expect(calls.log, ['check New_Name', 'login new_name']);
    expect(find.text('@new_name'), findsOneWidget);
  });

  testWidgets('a taken username cannot go on', (tester) async {
    final calls = Calls();
    await pumpEditProfile(
      tester,
      profileActions(calls, availability: UsernameAvailability.taken),
    );
    await tester.tap(find.byKey(EditProfile.usernameKey));
    await tester.pumpAndSettle();
    await tester.enterText(fieldOf(EditProfile.fieldKey), 'taken_name');
    await tester.pump();
    await tester.tap(find.byKey(EditProfile.checkKey));
    await tester.pumpAndSettle();
    expect(find.text('This username is unavailable.'), findsOneWidget);
    await tester.tap(find.byKey(EditProfile.saveKey));
    await tester.pumpAndSettle();
    expect(calls.log, ['check taken_name']);
  });

  testWidgets('no rename before Twitch allows it', (tester) async {
    final calls = Calls();
    await pumpEditProfile(
      tester,
      profileActions(
        calls,
        rename: LoginRenameStatus(
          eligible: false,
          eligibleAt: DateTime.utc(2027, 1, 8, 12),
        ),
      ),
    );
    await tester.tap(find.byKey(EditProfile.usernameKey));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'You changed your username recently. You can change it again on January 8, 2027.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(EditProfile.fieldKey), findsNothing);
  });

  testWidgets('adds, and deletes after a confirmation', (tester) async {
    final calls = Calls();
    await pumpEditProfile(tester, profileActions(calls));
    await tester.tap(find.byKey(EditProfile.addLinkKey));
    await tester.pumpAndSettle();
    await tester.enterText(fieldOf(EditProfile.fieldKey), 'Site');
    await tester.enterText(fieldOf(EditProfile.secondFieldKey), 'javascript:x');
    await tester.pump();
    await tester.tap(find.byKey(EditProfile.saveKey));
    await tester.pump();
    expect(calls.log, isEmpty);
    await tester.enterText(
      fieldOf(EditProfile.secondFieldKey),
      'https://example.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(EditProfile.saveKey));
    await tester.pumpAndSettle();
    expect(calls.log, ['add Site https://example.com']);
    expect(find.text('Site'), findsOneWidget);

    await tester.tap(find.byKey(EditProfile.linkKey('a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(EditProfile.deleteKey));
    await tester.pumpAndSettle();
    expect(find.text('Delete YouTube?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(calls.log.last, 'delete a');
    expect(find.text('YouTube'), findsNothing);
  });

  testWidgets('an unreadable profile points to twitch.tv', (tester) async {
    TwitchWebPage.debugBody = () => const SizedBox(key: ValueKey('web'));
    await pumpEditProfile(tester, profileActions(Calls(), profile: null));
    expect(
      find.text(
        'Couldn’t load your profile from Twitch. You can still edit it on twitch.tv.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Edit on twitch.tv'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('web')), findsOneWidget);
  });

  testWidgets('unreadable links hide the links group only', (tester) async {
    await pumpEditProfile(tester, profileActions(Calls(), links: null));
    expect(find.text('Caster'), findsOneWidget);
    expect(find.text('Couldn’t load your social links.'), findsOneWidget);
    expect(find.byKey(EditProfile.addLinkKey), findsNothing);
  });
}
