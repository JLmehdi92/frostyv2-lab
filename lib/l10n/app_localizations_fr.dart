// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get languageNameEnglish => 'English';

  @override
  String get languageNameFrench => 'Français';

  @override
  String get languageChoiceSemantics => 'Language · Langue';

  @override
  String get appLanguageSystem => 'Système';

  @override
  String get commonNext => 'Suivant';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonTryAgain => 'Réessayer';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonLiveBadge => 'LIVE';

  @override
  String get commonDismiss => 'Masquer';

  @override
  String get commonConnectWithTwitch => 'Se connecter avec Twitch';

  @override
  String get settingsLanguageTitle => 'Langue';

  @override
  String settingsLanguageSystemSubtitle({required String language}) {
    return '« Système » suit la langue de votre appareil (actuellement : $language).';
  }

  @override
  String get languageInTextEnglish => 'anglais';

  @override
  String get languageInTextFrench => 'français';

  @override
  String get languagePromptTitle => 'Choisissez votre langue';

  @override
  String get languagePromptBody =>
      'ONSET est désormais disponible en anglais et en français. Vous pourrez changer de langue à tout moment dans Paramètres › Général.';

  @override
  String get languagePromptConfirm => 'Continuer';

  @override
  String get onboardingIntroDescription =>
      'Un client mobile pour Twitch, compatible avec 7TV, BetterTTV (BTTV) et FrankerFaceZ (FFZ).';

  @override
  String get onboardingIntroEyebrow => 'Premier lancement';

  @override
  String get onboardingProgressLabel => 'Progression de la prise en main';

  @override
  String onboardingProgressValue({required int step, required int count}) {
    return 'Étape $step sur $count';
  }

  @override
  String get onboardingLoginTitle => 'Connexion';

  @override
  String get onboardingLoginLead =>
      'ONSET a besoin de votre autorisation pour vous permettre de discuter dans le chat, de voir les lives des chaînes que vous suivez, et plus encore.';

  @override
  String get onboardingLoginAuthorizeHeader => 'Ce que vous autorisez';

  @override
  String get onboardingPermissionChatTitle => 'Chat';

  @override
  String get onboardingPermissionChatDetail => 'Lire et envoyer des messages';

  @override
  String get onboardingPermissionFollowsTitle => 'Chaînes suivies';

  @override
  String get onboardingPermissionFollowsDetail => 'Voir qui est en direct';

  @override
  String get onboardingPermissionEmotesTitle => 'Vos emotes';

  @override
  String get onboardingPermissionEmotesDetail =>
      'Utiliser vos emotes d’abonné et de follower';

  @override
  String get onboardingPermissionWhispersTitle => 'Chuchotements';

  @override
  String get onboardingPermissionWhispersDetail =>
      'Lire et envoyer des chuchotements';

  @override
  String get onboardingPermissionModerationTitle => 'Modération';

  @override
  String get onboardingPermissionModerationDetail =>
      'Bannissements, avertissements, messages, modes du chat';

  @override
  String get onboardingPermissionClipsTitle => 'Clips';

  @override
  String get onboardingPermissionClipsDetail =>
      'Créer des clips à partir d’un live';

  @override
  String get onboardingPermissionBlocksTitle => 'Blocages et couleur du pseudo';

  @override
  String get onboardingPermissionBlocksDetail =>
      'Gérer les blocages, changer votre couleur dans le chat';

  @override
  String get onboardingLoginDisclaimer =>
      'ONSET ne demande que les autorisations nécessaires, via l’API officielle de Twitch. Vous pourrez les consulter avant de les accorder.';

  @override
  String get onboardingLoginSkip => 'Passer';

  @override
  String get onboardingSetupTitle => 'Configuration';

  @override
  String get onboardingSetupLead =>
      'Ajustons quelques réglages avant de commencer. Ceux-ci et bien d’autres restent modifiables à tout moment.';

  @override
  String onboardingSetupLoggedInAs({required String name}) {
    return 'Compte connecté : $name';
  }

  @override
  String get loginSigningIn => 'Connexion en cours…';

  @override
  String get onboardingSetupLoginFailed =>
      'Échec de la connexion · réessayez en revenant en arrière, ou plus tard depuis l’onglet Profil';

  @override
  String get onboardingSetupNotLoggedIn =>
      'Aucun compte connecté · vous pourrez vous connecter plus tard depuis l’onglet Profil';

  @override
  String get onboardingSetupPreviewChannel => 'Chaîne en direct';

  @override
  String get onboardingSetupPreviewDetail => 'Catégorie · spectateurs';

  @override
  String onboardingSetupPreviewSemantics({
    required String name,
    required String detail,
  }) {
    return 'Aperçu : $name, $detail';
  }

  @override
  String get onboardingSetupPreviewBadge => 'APERÇU';

  @override
  String get onboardingSetupThemeTitle => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get onboardingSetupThemeSystemNote => 'Suit votre appareil';

  @override
  String get onboardingSetupThemeLightNote => 'Surfaces claires partout';

  @override
  String get onboardingSetupThemeDarkNote => 'Le thème par défaut d’ONSET';

  @override
  String get accentColorTitle => 'Couleur d’accent';

  @override
  String accentColorSemantics({required String hex}) {
    return 'Couleur d’accent, $hex';
  }

  @override
  String get accentColorRandom => 'Aléatoire';

  @override
  String get accentSaturationBrightness => 'Saturation et luminosité';

  @override
  String accentSaturationBrightnessValue({
    required int saturation,
    required int brightness,
  }) {
    return '$saturation %, $brightness %';
  }

  @override
  String accentHue({required int degrees}) {
    String _temp0 = intl.Intl.pluralLogic(
      degrees,
      locale: localeName,
      other: 'Teinte $degrees degrés',
      one: 'Teinte $degrees degré',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSetupHistoryTitle =>
      'Historique de secours du chat (tiers)';

  @override
  String onboardingSetupHistoryDetail({required String link}) {
    return 'Si l’historique du chat de Twitch est indisponible, ne se charge pas ou est vide, ONSET récupère les messages récents depuis $link, qui reçoit alors le nom de la chaîne.';
  }

  @override
  String get onboardingSetupCrashTitle =>
      'Partager les rapports de plantage et statistiques';

  @override
  String get onboardingSetupCrashDetail =>
      'Aidez-nous à améliorer ONSET en envoyant les rapports de plantage et les statistiques d’utilisation via Firebase. Ni votre compte Twitch ni vos chaînes ne sont transmis.';

  @override
  String get onboardingWelcomeTitle => 'Bienvenue !';

  @override
  String get onboardingWelcomeLead => 'Encore quelques petites choses…';

  @override
  String get onboardingWelcomeTipGitHub =>
      'Le bouton GitHub, en haut à droite des paramètres, ouvre le dépôt d’ONSET : explorez le code source, signalez des bugs, proposez des fonctionnalités, et plus encore.';

  @override
  String get onboardingWelcomeTipChangelog =>
      'Les liens vers le journal complet des modifications et la FAQ se trouvent dans les paramètres, rubrique « Autres ».';

  @override
  String get onboardingWelcomeTipRating =>
      'N’oubliez pas de laisser une note ou un avis sur la boutique d’applications !';

  @override
  String get onboardingWelcomeGo => 'C’est parti !';

  @override
  String get loginHelpTooltip => 'Aide à la connexion';

  @override
  String get loginHelpTitle => 'Contourner le bandeau de cookies de Twitch';

  @override
  String get loginHelpBodyOnboarding =>
      'Si le bandeau de cookies de Twitch bloque encore la connexion, appuyez sur l’un des liens de son texte sur la politique de cookies et naviguez jusqu’à la page d’accueil de Twitch. De là, essayez de vous connecter depuis l’icône de profil en haut à droite. Une fois la connexion effectuée, revenez à la première étape de la prise en main, puis réessayez.';

  @override
  String get loginHelpBodyElsewhere =>
      'Si le bandeau de cookies de Twitch bloque encore la connexion, appuyez sur l’un des liens de son texte sur la politique de cookies et naviguez jusqu’à la page d’accueil de Twitch. De là, essayez de vous connecter depuis l’icône de profil en haut à droite. Une fois la connexion effectuée, revenez en arrière, puis rouvrez la page de connexion.';

  @override
  String loginHostSecure({required String host}) {
    return 'Page sécurisée : $host';
  }

  @override
  String loginHostPage({required String host}) {
    return 'Page : $host';
  }

  @override
  String get loginFailedLine => 'Twitch n’a pas pu vous connecter. Réessayez.';

  @override
  String get loginLoadFailedTitle => 'Impossible de joindre Twitch';

  @override
  String get loginLoadFailedDetail =>
      'Vérifiez votre connexion Internet, puis réessayez.';

  @override
  String get shellSectionHome => 'Accueil';

  @override
  String get shellSectionBrowse => 'Parcourir';

  @override
  String get shellSectionActivity => 'Activité';

  @override
  String get shellSectionProfile => 'Profil';

  @override
  String shellActivityNew({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Activité, $count éléments non lus',
      one: 'Activité, $count élément non lu',
    );
    return '$_temp0';
  }

  @override
  String get shellFeedFollowing => 'Suivis';

  @override
  String get shellFeedLive => 'En direct';

  @override
  String get shellFeedClips => 'Clips';

  @override
  String get shellBrowseCategories => 'Catégories';

  @override
  String get shellBrowseLiveChannels => 'Chaînes en direct';

  @override
  String get shellActivityNotifications => 'Notifications';

  @override
  String get shellWhispers => 'Chuchotements';

  @override
  String shellWhispersUnread({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Chuchotements ($count non lus)',
      one: 'Chuchotements ($count non lu)',
    );
    return '$_temp0';
  }

  @override
  String get shellWhispersRefused =>
      'Chuchotements (reconnectez-vous pour les recevoir)';

  @override
  String shellTabUnread({required String label, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$label, $count éléments non lus',
      one: '$label, $count élément non lu',
    );
    return '$_temp0';
  }

  @override
  String get shellNavSemantics => 'Navigation principale';

  @override
  String get shellSearch => 'Rechercher';

  @override
  String get shellSearchHint =>
      'Rechercher des chaînes, des catégories ou des vidéos';

  @override
  String get shellSettings => 'Paramètres';

  @override
  String homeOpenChannelFailed({required String login}) {
    return 'Impossible d’ouvrir la chaîne $login.';
  }

  @override
  String mentionNotice({required String login}) {
    return 'Nouvelle mention dans le chat de la chaîne $login';
  }

  @override
  String get deepLinkCategoryFallback => 'Catégorie';

  @override
  String deepLinkFailed({required String uri}) {
    return 'Impossible d’ouvrir « $uri »';
  }

  @override
  String get deepLinkOpenInBrowser => 'Ouvrir dans le navigateur';

  @override
  String get scrollToTop => 'Revenir en haut';

  @override
  String get miniPlayerReturn => 'Revenir au live';

  @override
  String get miniPlayerClose => 'Fermer le mini-lecteur';

  @override
  String get userActionsProfile => 'Profil';

  @override
  String get userActionsVideos => 'Vidéos';

  @override
  String userActionsPin({required String name}) {
    return 'Épingler $name';
  }

  @override
  String userActionsUnpin({required String name}) {
    return 'Désépingler $name';
  }

  @override
  String userActionsBlock({required String name}) {
    return 'Bloquer $name';
  }

  @override
  String userActionsFollowOnTwitch({required String name}) {
    return 'Suivre $name sur Twitch';
  }

  @override
  String get userActionsFollowDetail => 'Ouvre la chaîne sur twitch.tv';

  @override
  String get userActionsCopyLink => 'Copier le lien';

  @override
  String get userActionsLinkCopied => 'Lien copié';

  @override
  String userActionsShare({required String name}) {
    return 'Partager $name';
  }

  @override
  String userActionsReport({required String name}) {
    return 'Signaler $name';
  }

  @override
  String get draggableDividerChatWidth => 'Largeur du chat';

  @override
  String draggableDividerValue({required int percent}) {
    return '$percent %';
  }

  @override
  String get photoViewThumbnail => 'Voir la miniature';

  @override
  String get photoViewOriginal => 'Voir l’original';

  @override
  String get videoListEmptyHint => 'Tirez vers le bas pour actualiser.';

  @override
  String get releaseNotesEarlierVersions => 'Versions précédentes';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsCustomize => 'Personnaliser';

  @override
  String get settingsSectionsSemantics => 'Rubriques des paramètres';

  @override
  String get settingsJumpToGroup => 'Aller à un groupe';

  @override
  String get settingsPageGeneral => 'Général';

  @override
  String get settingsPageGeneralDescription =>
      'Le thème, les cartes de live, la navigation et les liens';

  @override
  String get settingsPageVideo => 'Vidéo';

  @override
  String get settingsPageVideoDescription =>
      'Le lecteur à faible latence, la lecture, l’interface du lecteur, les vidéos et les sous-titres';

  @override
  String get settingsPageChat => 'Chat';

  @override
  String get settingsPageChatDescription =>
      'L’apparence, le délai, les alertes et les filtres du chat';

  @override
  String get settingsPageNotifications => 'Notifications';

  @override
  String get settingsPageNotificationsDescription =>
      'Les notifications de live et de mention dans le chat';

  @override
  String get settingsPageOther => 'Autres';

  @override
  String get settingsPageOtherDescription =>
      'Les mises à jour, le stockage, la confidentialité et la rubrique À propos';

  @override
  String get settingsPageAccount => 'Compte';

  @override
  String get settingsPageAccountDescription => 'Votre compte Twitch dans ONSET';

  @override
  String get settingsPageBlocked => 'Utilisateurs bloqués';

  @override
  String get settingsPageBlockedDescription =>
      'Les personnes que vous avez bloquées sur Twitch';

  @override
  String get settingsPageChatFilters => 'Modifier les filtres du chat';

  @override
  String get settingsSummaryGeneral =>
      'Thème, couleur d’accent, navigation, liens';

  @override
  String get settingsSummaryVideo =>
      'Lecteur à faible latence, sous-titres, interface';

  @override
  String get settingsSummaryChat => 'Taille, alertes, filtres, emotes';

  @override
  String get settingsSummaryNotifications => 'Lives et mentions dans le chat';

  @override
  String get settingsSummaryNotificationsLoggedOut =>
      'Connectez-vous pour recevoir les notifications de live et de mention';

  @override
  String get settingsSummaryOther =>
      'Mises à jour, cache, confidentialité, à propos';

  @override
  String settingsSummaryMentions({required String mentions}) {
    String _temp0 = intl.Intl.selectLogic(mentions, {
      'on': 'Mentions activées',
      'other': 'Mentions désactivées',
    });
    return '$_temp0';
  }

  @override
  String settingsSummaryGoLiveMentions({
    required String goLive,
    required String mentions,
  }) {
    String _temp0 = intl.Intl.selectLogic(goLive, {
      'on': 'Notifications de live activées',
      'other': 'Notifications de live désactivées',
    });
    String _temp1 = intl.Intl.selectLogic(mentions, {
      'on': 'mentions activées',
      'other': 'mentions désactivées',
    });
    return '$_temp0 · $_temp1';
  }

  @override
  String get settingsUnableToReachTwitch => 'Impossible de joindre Twitch';

  @override
  String get settingsCheckConnection =>
      'Vérifiez votre connexion Internet, puis réessayez';

  @override
  String get settingsReconnect => 'Réessayer';

  @override
  String get settingsAccountCardDetail =>
      'Utilisateurs bloqués, twitch.tv, déconnexion';

  @override
  String get settingsAnonymous => 'Anonyme';

  @override
  String get settingsWatchingWithoutAccount => 'Visionnage sans compte';

  @override
  String get settingsLoginPitch =>
      'Connectez-vous pour discuter dans le chat, voir les lives des chaînes que vous suivez, et plus encore.';

  @override
  String get settingsLoginDisclaimer =>
      'ONSET ne demande que les autorisations nécessaires, via l’API officielle de Twitch. Vous pourrez les consulter avant de les accorder.';

  @override
  String get settingsTokenLoginTip =>
      'Vous avez copié un jeton ? Appuyez de manière prolongée sur cette carte pour vous connecter avec ce jeton.';

  @override
  String get settingsTokenLoginHint => 'se connecter avec un jeton copié';

  @override
  String get settingsYourAccount => 'Votre compte';

  @override
  String get settingsMyChannel => 'Ma chaîne';

  @override
  String get settingsOnTwitch => 'Sur twitch.tv';

  @override
  String get settingsTwitchSecurity => 'Sécurité et confidentialité';

  @override
  String get settingsTwitchSecurityDetail =>
      'Mot de passe, e-mail, téléphone, double authentification – sur twitch.tv';

  @override
  String get settingsTwitchConnections => 'Connexions';

  @override
  String get settingsTwitchConnectionsDetail =>
      'Comptes associés – sur twitch.tv';

  @override
  String get settingsLogOut => 'Se déconnecter';

  @override
  String get settingsLogOutTitle => 'Déconnexion';

  @override
  String get settingsLogOutMessage => 'Voulez-vous vraiment vous déconnecter ?';

  @override
  String settingsJoined({required DateTime date}) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMM(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Membre depuis $dateString';
  }

  @override
  String get settingsYourProfile => 'Votre profil';

  @override
  String get settingsUnblock => 'Débloquer';

  @override
  String settingsUnblockName({required String name}) {
    return 'Débloquer $name';
  }

  @override
  String settingsUnblockMessage({required String name}) {
    return 'Voulez-vous vraiment débloquer « $name » ?';
  }

  @override
  String get settingsBlock => 'Bloquer';

  @override
  String settingsBlockMessage({required String name}) {
    return 'Voulez-vous vraiment bloquer « $name » ? Cette personne n’apparaîtra plus dans les listes de chaînes, les résultats de recherche et les messages du chat.';
  }

  @override
  String get commonYes => 'Oui';

  @override
  String get settingsNoBlockedUsers => 'Aucun utilisateur bloqué';

  @override
  String settingsBlockedCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utilisateurs bloqués',
      one: '$count utilisateur bloqué',
    );
    return '$_temp0';
  }

  @override
  String get settingsBlockedNote =>
      'Les utilisateurs bloqués n’apparaissent plus dans les listes de chaînes, les résultats de recherche et les messages du chat. Tirez vers le bas pour actualiser.';

  @override
  String get authForeignTokenNotice =>
      'Ce jeton a été créé pour une autre application – certaines fonctionnalités risquent d’être indisponibles.';

  @override
  String get authSessionEndedNotice =>
      'Votre session Twitch a pris fin. Reconnectez-vous depuis les paramètres.';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsAccentColorChange => 'Changer la couleur d’accent';

  @override
  String get settingsAccentColorLive =>
      'S’applique partout dès que vous la choisissez';

  @override
  String get settingsStreamCard => 'Carte de live';

  @override
  String get settingsLargeStreamCard => 'Utiliser les grandes cartes de live';

  @override
  String get settingsShowThumbnail => 'Afficher la miniature';

  @override
  String get settingsBrowse => 'Parcourir';

  @override
  String get settingsStartTab => 'Ouvrir l’application sur';

  @override
  String get settingsLinks => 'Liens';

  @override
  String get settingsExternalBrowser =>
      'Ouvrir les liens dans un navigateur externe';

  @override
  String get settingsStreamLanguage => 'Langue des lives';

  @override
  String get streamLanguageAll => 'Toutes les langues';

  @override
  String get streamLanguageOther => 'Autre';

  @override
  String get settingsHideLabeled =>
      'Masquer les lives selon leur classification';

  @override
  String settingsHideLabeledValue({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count classifications',
      one: '$count classification',
      zero: 'Aucune',
    );
    return '$_temp0';
  }

  @override
  String get settingsHideLabeledNote =>
      'Les lives qui portent ces classifications sont exclus des onglets En direct et Chaînes en direct, des catégories et des tags. Les chaînes suivies s’affichent toujours.';

  @override
  String get contentLabelDrugs =>
      'Drogues, intoxication ou consommation excessive de tabac';

  @override
  String get contentLabelSexualThemes => 'Thèmes sexuels';

  @override
  String get contentLabelViolentGraphic =>
      'Représentations violentes et explicites';

  @override
  String get contentLabelGambling => 'Jeux d’argent';

  @override
  String get contentLabelProfanity => 'Grossièretés ou vulgarité marquées';

  @override
  String get contentLabelMatureGame => 'Jeu classé pour adultes';

  @override
  String get contentLabelPolitics =>
      'Politique et questions sociales sensibles';

  @override
  String get settingsLowLatencyPlayer => 'Lecteur à faible latence';

  @override
  String get settingsLowLatencyPlayerSwitch =>
      'Lecteur à faible latence (Amazon IVS)';

  @override
  String get settingsLowLatencyPlayerDetail =>
      'Lit le live avec le lecteur Amazon IVS, qui repose sur la même technologie vidéo que Twitch, pour une faible latence. Désactivez cette option pour utiliser le lecteur web d’origine de Twitch.';

  @override
  String get settingsAutoLatency => 'Latence automatique';

  @override
  String get settingsAutoLatencyDetail =>
      'Garde le live au plus près du direct en le lisant très légèrement plus vite quand il prend du retard, sans le recharger. Si la lecture se bloque trop souvent en « Ultra », les lives suivants passent en « Standard » pendant un moment. S’applique à la prochaine ouverture d’un live.';

  @override
  String get settingsLiveCatchUp => 'Rattrapage du direct';

  @override
  String get settingsLiveCatchUpDetail =>
      '« Accélérer » lit un peu plus vite jusqu’à rattraper le direct (la latence automatique le fait quand elle est activée). « Revenir au direct » rejoint le direct d’un coup après un blocage. S’applique à la prochaine ouverture d’un live.';

  @override
  String get liveCatchUpSpeedUp => 'Accélérer';

  @override
  String get liveCatchUpJumpToLive => 'Revenir au direct';

  @override
  String get settingsBufferProfile => 'Profil de mémoire tampon';

  @override
  String get settingsBufferProfileDetail =>
      '« Ultra » garde une mémoire tampon encore plus réduite pour baisser la latence, mais la lecture risque de s’interrompre plus souvent sur une connexion Internet faible. S’applique à la prochaine ouverture d’un live.';

  @override
  String get bufferProfileStandard => 'Standard';

  @override
  String get bufferProfileUltra => 'Ultra';

  @override
  String get playerConfigAuto => 'Auto';

  @override
  String get playerConfigJumpToLiveAuto => 'Revenir au direct + auto';

  @override
  String playerConfigUltraStalled({
    required String mode,
    required String buffer,
  }) {
    return '$mode · $buffer (blocages en « Ultra »)';
  }

  @override
  String get settingsPlayback => 'Lecture';

  @override
  String get settingsEnableVideo => 'Activer la vidéo';

  @override
  String get settingsHighestQuality => 'Qualité maximale par défaut';

  @override
  String get settingsFastRendering => 'Utiliser le rendu vidéo rapide';

  @override
  String get settingsFastRenderingDetail =>
      'Utilise une méthode de rendu WebView plus rapide. Désactivez cette option si l’application plante pendant que vous regardez un live.';

  @override
  String get settingsKeepAwake => 'Garder l’écran allumé';

  @override
  String get settingsKeepAwakeDetail =>
      'Empêche la mise en veille de l’écran tant qu’une chaîne est ouverte.';

  @override
  String get settingsBackgroundAudio => 'Audio en arrière-plan';

  @override
  String get settingsBackgroundAudioDetail =>
      'Poursuit la lecture d’un live quand vous quittez l’application ou éteignez l’écran, avec les commandes de lecture dans une notification.';

  @override
  String get settingsOverlay => 'Interface du lecteur';

  @override
  String get settingsCustomOverlay =>
      'Utiliser l’interface de lecteur personnalisée';

  @override
  String get settingsCustomOverlayDetail =>
      'Remplace l’interface web par défaut de Twitch par une version adaptée aux mobiles.';

  @override
  String get settingsToggleOverlay =>
      'Changer d’interface par un appui prolongé';

  @override
  String get settingsToggleOverlayDetail =>
      'Un appui prolongé sur le lecteur fait passer de l’interface de Twitch à l’interface personnalisée, et inversement.';

  @override
  String get settingsShowLatency => 'Afficher la latence';

  @override
  String get settingsShowLatencyDetail =>
      'Affiche la latence du live dans l’interface du lecteur. Avec le lecteur à faible latence, appuyez dessus pour afficher les statistiques vidéo en direct.';

  @override
  String get settingsVideosAndContent => 'Vidéos et contenu';

  @override
  String get settingsVodAutoplay => 'Lecture automatique des vidéos';

  @override
  String get settingsVodAutoplayDetail =>
      'Choisissez quand les vidéos se lancent automatiquement';

  @override
  String get vodAutoplayAlways => 'Données mobiles et Wi-Fi';

  @override
  String get vodAutoplayWifiOnly => 'Wi-Fi uniquement';

  @override
  String get vodAutoplayNever => 'Jamais';

  @override
  String get settingsWarnMature =>
      'Prévenir avant un contenu pour public averti';

  @override
  String get settingsWarnMatureDetail =>
      'Affiche un avertissement avant une chaîne classée pour un public averti.';

  @override
  String get settingsCaptions => 'Sous-titres';

  @override
  String get settingsClosedCaptions => 'Afficher les sous-titres';

  @override
  String get settingsClosedCaptionsDetail =>
      'Affiche les sous-titres sur les lives et les vidéos qui en proposent. S’il y a plusieurs pistes, choisissez-en une dans le menu du lecteur.';

  @override
  String get settingsCaptionSize => 'Taille des sous-titres';

  @override
  String get captionSizeSmall => 'Petite';

  @override
  String get captionSizeMedium => 'Moyenne';

  @override
  String get captionSizeLarge => 'Grande';

  @override
  String get captionSizeExtraLarge => 'Très grande';

  @override
  String get settingsCaptionBackground => 'Fond des sous-titres';

  @override
  String get captionBackgroundBlack => 'Noir';

  @override
  String get captionBackgroundTranslucent => 'Translucide';

  @override
  String get captionBackgroundNone => 'Aucun';

  @override
  String get settingsCaptionSample => 'Voici l’apparence des sous-titres.';

  @override
  String get webTokenTitle => 'Jeton web Twitch (2K)';

  @override
  String get webTokenExpired =>
      'Session Twitch expirée – reconnectez-vous pour retrouver la 2K';

  @override
  String get webTokenUnset =>
      'Non défini – connectez-vous pour le récupérer automatiquement';

  @override
  String get webTokenActive => 'Actif – récupéré automatiquement, 2K demandée';

  @override
  String get webTokenNotSet => 'Non défini';

  @override
  String get webTokenExplanation =>
      'Certains lives ne proposent leur qualité 2K (1440p HEVC) qu’aux spectateurs connectés. Ce jeton est normalement récupéré tout seul quand vous vous connectez, puis actualisé à chaque lancement : vous ne devriez jamais avoir à y toucher. Ne le saisissez à la main qu’en cas d’échec : collez la valeur du cookie « auth-token » de twitch.tv, copiée depuis un navigateur.';

  @override
  String get webTokenIsSet => 'Un jeton est défini.';

  @override
  String get webTokenNoneSet => 'Aucun jeton défini.';

  @override
  String get webTokenClear => 'Effacer';

  @override
  String get webTokenNewField => 'Nouvel auth-token';

  @override
  String get webTokenFieldHint => 'Collez pour remplacer – jamais affiché';

  @override
  String get webTokenReplace => 'Remplacer';

  @override
  String get webTokenSave => 'Enregistrer';

  @override
  String get settingsMessageSizing => 'Taille des messages';

  @override
  String get settingsChatPreview => 'Aperçu';

  @override
  String get settingsChatPreviewBadgeEmote =>
      'Aperçu des badges et des emotes.';

  @override
  String get settingsChatPreviewText => 'Bonjour ! Voici un aperçu du texte.';

  @override
  String get settingsChatPreviewSpacing =>
      'Et un autre, sans emote, pour l’espacement !';

  @override
  String get settingsBadgeScale => 'Échelle des badges';

  @override
  String get settingsEmoteScale => 'Échelle des emotes';

  @override
  String get settingsMessageScale => 'Échelle des messages';

  @override
  String settingsScaleValue({required double scale}) {
    final intl.NumberFormat scaleNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 2,
        );
    final String scaleString = scaleNumberFormat.format(scale);

    return '$scaleString ×';
  }

  @override
  String get settingsMessageSpacing => 'Espacement des messages';

  @override
  String settingsSpacingValue({required int pixels}) {
    return '$pixels px';
  }

  @override
  String get settingsFontSize => 'Taille de police';

  @override
  String get settingsMessageAppearance => 'Apparence des messages';

  @override
  String get settingsShowDeleted => 'Afficher les messages supprimés';

  @override
  String get settingsShowDeletedDetail =>
      'Rétablit le texte d’origine des messages supprimés.';

  @override
  String get settingsAnimateEmotes => 'Animer les emotes';

  @override
  String get settingsAnimateEmotesDetail =>
      'Si l’option est désactivée, seule la première image des emotes animées s’affiche dans le chat.';

  @override
  String get settingsAnimatedGifs => 'GIF animés';

  @override
  String get settingsAnimatedGifsDetail =>
      'Si l’option est désactivée, seule la première image des GIF envoyés dans le chat s’affiche.';

  @override
  String get settingsShowGifs => 'Afficher les GIF dans le chat';

  @override
  String get settingsShowGifsDetail =>
      'Si l’option est désactivée, le titre du GIF s’affiche à la place du GIF.';

  @override
  String get settingsLinkPreviews => 'Aperçu des clips et des vidéos';

  @override
  String get settingsLinkPreviewsDetail =>
      'Affiche une carte sous les messages qui contiennent un lien vers un clip ou une vidéo Twitch.';

  @override
  String get settingsModerationNotices =>
      'Afficher les exclusions temporaires et les bannissements';

  @override
  String get settingsModerationNoticesDetail =>
      'Ajoute une ligne quand un modérateur exclut temporairement ou bannit quelqu’un.';

  @override
  String get settingsMessageDividers => 'Afficher les séparateurs de messages';

  @override
  String get settingsTimestamps => 'Horodatage des messages';

  @override
  String get timestampDisabled => 'Désactivé';

  @override
  String get timestampTwelve => '12 heures';

  @override
  String get timestampTwentyFour => '24 heures';

  @override
  String get settingsDelayAndLatency => 'Délai et latence';

  @override
  String get settingsSyncDelay =>
      'Synchroniser le délai des messages avec la latence';

  @override
  String get settingsSyncDelayDetail =>
      'Retient chaque message le temps du retard de la vidéo sur le direct, pour que le chat corresponde à ce que vous voyez. Vos propres messages s’affichent immédiatement.';

  @override
  String get settingsMessageDelay => 'Délai des messages';

  @override
  String settingsMessageDelayValue({required int seconds}) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds secondes',
      one: '$seconds seconde',
    );
    return '$_temp0';
  }

  @override
  String get settingsMessageDelayDetail =>
      'Ajoute un délai avant l’affichage de chaque message dans le chat.';

  @override
  String get settingsMessageDelayDetailIos =>
      'Ajoute un délai avant l’affichage de chaque message dans le chat. Un délai de 15 secondes est recommandé sur iOS.';

  @override
  String get settingsLayout => 'Disposition';

  @override
  String get settingsEmoteButtonLeft => 'Placer le bouton des emotes à gauche';

  @override
  String get settingsEmoteButtonLeftDetail =>
      'Place le bouton du menu des emotes à gauche pour éviter les appuis accidentels.';

  @override
  String get settingsPersistTabs => 'Conserver les onglets du chat';

  @override
  String get settingsPersistTabsDetail =>
      'Les onglets de chat secondaires sont conservés quand vous changez de chaîne.';

  @override
  String get settingsAlerts => 'Alertes';

  @override
  String get settingsFirstTimeChatters =>
      'Mettre en avant les premiers messages';

  @override
  String get settingsUserNotices => 'Afficher les événements';

  @override
  String get settingsUserNoticesDetail =>
      'Affiche les événements comme les abonnements et les réabonnements, les annonces et les raids.';

  @override
  String get settingsCollapseGiftBombs => 'Regrouper les abonnements offerts';

  @override
  String get settingsCollapseGiftBombsDetail =>
      'Réduit à sa première ligne tout envoi d’au moins cinq abonnements offerts à la communauté ; appuyez sur « destinataires » pour voir qui en a reçu un.';

  @override
  String get settingsShowHypeTrains => 'Afficher les Hype Trains';

  @override
  String get settingsShowHypeTrainsDetail =>
      'Affiche la progression, les niveaux et les récompenses du Hype Train au-dessus du chat.';

  @override
  String get settingsCommunityHighlights =>
      'Afficher les temps forts de la communauté';

  @override
  String get settingsCommunityHighlightsDetail =>
      'Affiche les sondages, les prédictions, les messages épinglés, les abonnements offerts à la communauté et les raids au-dessus du chat.';

  @override
  String get settingsCelebrations => 'Afficher les célébrations';

  @override
  String get settingsCelebrationsDetail =>
      'Lance une animation sur la chaîne quand quelqu’un offre des abonnements.';

  @override
  String get settingsCelebrationsOnVideo => 'Célébrations sur la vidéo';

  @override
  String get settingsCelebrationsOnVideoDetail =>
      '« Complètes » : l’animation s’affiche par-dessus la vidéo. « Discrètes » : la vidéo reste dégagée et une ligne l’annonce dans le chat.';

  @override
  String get celebrationsFull => 'Complètes';

  @override
  String get celebrationsSubtle => 'Discrètes';

  @override
  String get settingsAutocomplete => 'Saisie automatique';

  @override
  String get settingsAutocompleteBar =>
      'Afficher la barre de saisie automatique';

  @override
  String get settingsAutocompleteBarDetail =>
      'Affiche une barre d’emotes et de mentions correspondantes pendant la saisie.';

  @override
  String get settingsLandscape => 'Mode paysage';

  @override
  String get settingsChatLeft => 'Placer le chat à gauche';

  @override
  String get settingsVerticalChat => 'Forcer le chat vertical';

  @override
  String get settingsVerticalChatDetail =>
      'Conçu pour les tablettes et les autres grands écrans.';

  @override
  String get settingsNotchSide => 'Occuper le côté de l’encoche';

  @override
  String get settingsNotchSideDetail =>
      'Occupe l’espace disponible autour de l’encoche sur les appareils qui en ont une.';

  @override
  String get notchSideNone => 'Aucun';

  @override
  String get notchSideLeft => 'Gauche';

  @override
  String get notchSideRight => 'Droite';

  @override
  String get notchSideBoth => 'Les deux';

  @override
  String get settingsOverlayOpacity => 'Opacité du chat superposé';

  @override
  String settingsOverlayOpacityValue({required int percent}) {
    return '$percent %';
  }

  @override
  String get settingsOverlayOpacityDetail =>
      'Règle l’opacité (la transparence) du chat superposé à la vidéo en plein écran.';

  @override
  String get settingsFiltersGroup => 'Filtres du chat et mots-clés masqués';

  @override
  String get settingsFiltersOn => 'Activés';

  @override
  String get settingsFiltersOff => 'Désactivés';

  @override
  String get settingsWholeWords => 'Mots entiers uniquement';

  @override
  String get settingsWholeWordsDetail =>
      'Ne masque que les mots entiers, pas les parties de mots.';

  @override
  String get settingsEmotesAndBadges => 'Emotes et badges';

  @override
  String get settingsShowTwitchEmotes => 'Afficher les emotes Twitch';

  @override
  String get settingsShowTwitchBadges => 'Afficher les badges Twitch';

  @override
  String get settingsShow7tvEmotes => 'Afficher les emotes 7TV';

  @override
  String get settingsShowBttvEmotes => 'Afficher les emotes BTTV';

  @override
  String get settingsShowBttvBadges => 'Afficher les badges BTTV';

  @override
  String get settingsShowFfzEmotes => 'Afficher les emotes FFZ';

  @override
  String get settingsShowFfzBadges => 'Afficher les badges FFZ';

  @override
  String get settingsRecentMessages => 'Messages récents';

  @override
  String get chatFiltersEnable => 'Activer le filtrage du chat';

  @override
  String get chatFiltersExplanation =>
      'Choisissez ce que vous souhaitez filtrer dans le chat, sur toutes les chaînes. Sur les chaînes que vous modérez, vous verrez toujours tous les messages.';

  @override
  String get chatFiltersGroup => 'Filtres';

  @override
  String get chatFilterDiscrimination => 'Discrimination';

  @override
  String get chatFilterDiscriminationDetail =>
      'Propos négatifs sur l’origine, le genre, l’orientation sexuelle ou d’autres caractéristiques';

  @override
  String get chatFilterSexual => 'Langage sexuellement explicite';

  @override
  String get chatFilterSexualDetail =>
      'Allusions à des actes sexuels, à du contenu sexuel ou à des parties du corps';

  @override
  String get chatFilterHarassment => 'Harcèlement';

  @override
  String get chatFilterHarassmentDetail =>
      'Propos agressifs ou de harcèlement sexuel envers d’autres personnes';

  @override
  String get chatFilterProfanity => 'Grossièretés';

  @override
  String get chatFilterProfanityDetail =>
      'Jurons, injures ou autres obscénités';

  @override
  String get chatFiltersNote =>
      'L’AutoMod de Twitch analyse chaque message du chat en direct et classe certains mots dans une catégorie ; seuls ces mots sont masqués, donc un message sans mot classé s’affiche toujours. Les mots masqués apparaissent sous forme d’étoiles : appuyez dessus pour voir le message. Le chat des anciennes diffusions n’est pas filtré.';

  @override
  String get mutedKeywordsTitle => 'Mots-clés masqués';

  @override
  String mutedKeywordsCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mots-clés',
      one: '$count mot-clé',
      zero: 'Aucun',
    );
    return '$_temp0';
  }

  @override
  String get mutedKeywordsHint => 'Saisissez les mots-clés à masquer';

  @override
  String get mutedKeywordsAdd => 'Ajouter le mot-clé';

  @override
  String get mutedKeywordsEmpty => 'Aucun mot-clé masqué';

  @override
  String mutedKeywordsRemove({required String word}) {
    return 'Retirer « $word »';
  }

  @override
  String mutedKeywordsRemoved({required String word}) {
    return 'Mot-clé « $word » retiré';
  }

  @override
  String get commonUndo => 'Annuler';

  @override
  String get settingsChannelsYouFollow => 'Chaînes suivies';

  @override
  String get goLiveTitle => 'Notifications de live';

  @override
  String get goLiveAndroidOnly => 'Android uniquement.';

  @override
  String get goLiveLoggedOut =>
      'Connectez-vous pour recevoir une notification quand une chaîne que vous suivez lance un live.';

  @override
  String get goLiveBlocked =>
      'Les notifications sont bloquées pour cette application. Autorisez-les dans les paramètres du système.';

  @override
  String get goLiveOnDetail =>
      'Vérification toutes les 90 secondes quand ONSET est ouvert ou en lecture, et environ toutes les 15 minutes sinon, si le système le permet. Désactivez la cloche d’une chaîne depuis son menu.';

  @override
  String get goLiveOffDetail =>
      'Recevez une notification quand une chaîne que vous suivez lance un live.';

  @override
  String get goLiveLogInAgain =>
      'Reconnectez-vous pour recevoir les notifications de live.';

  @override
  String get goLiveReadFailed =>
      'Impossible de lire le réglage des notifications de live.';

  @override
  String get goLiveTurnOnFailed =>
      'Impossible d’activer les notifications de live.';

  @override
  String get goLiveTurnOffFailed =>
      'Impossible de désactiver les notifications de live.';

  @override
  String get notificationsAllowInSystem =>
      'Autorisez les notifications de cette application dans les paramètres du système.';

  @override
  String get goLiveBellFailed => 'Impossible de modifier la cloche.';

  @override
  String goLiveBell({required String name}) {
    return 'Me prévenir quand $name lance un live';
  }

  @override
  String get mentionTitle => 'Notifications de mention dans le chat';

  @override
  String get mentionLoggedOut =>
      'Connectez-vous pour recevoir une notification quand quelqu’un vous mentionne dans le chat.';

  @override
  String get mentionBlocked =>
      'Les notifications sont bloquées pour cette application.';

  @override
  String get mentionAllow => 'Autoriser';

  @override
  String get mentionDetail =>
      'Vous prévient quand quelqu’un vous mentionne dans le chat d’une chaîne que vous regardez, pendant qu’ONSET est en arrière-plan ou en Picture-in-picture.';

  @override
  String get settingsUpdates => 'Mises à jour';

  @override
  String get settingsReleaseNotes => 'Notes de version';

  @override
  String get settingsUpdatesNote =>
      'ONSET recherche un build plus récent au démarrage et à chaque retour au premier plan. Les notes de version s’ouvrent d’elles-mêmes après une mise à jour vers une nouvelle version.';

  @override
  String get settingsStorage => 'Stockage et réinitialisation';

  @override
  String get settingsClearCache => 'Vider le cache des images';

  @override
  String get settingsCacheCleared => 'Cache des images vidé';

  @override
  String get settingsReset => 'Réinitialiser les paramètres';

  @override
  String get settingsResetTitle => 'Réinitialiser tous les paramètres';

  @override
  String get settingsResetMessage =>
      'Voulez-vous vraiment réinitialiser tous les paramètres ?';

  @override
  String get settingsResetConfirm => 'Réinitialiser';

  @override
  String get settingsResetDone => 'Tous les paramètres ont été réinitialisés';

  @override
  String get settingsPrivacy => 'Confidentialité';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get settingsSourceCode => 'Code source';

  @override
  String get settingsLicenses => 'Licences';

  @override
  String settingsLegalese({required String url}) {
    return 'ONSET est un logiciel libre distribué sous licence GNU AGPL-3.0-or-later, SANS AUCUNE GARANTIE. Code source : $url';
  }

  @override
  String get updatesUpToDate => 'ONSET est à jour';

  @override
  String get updatesCheckFailed => 'Impossible de rechercher les mises à jour';

  @override
  String get updatesCheck => 'Rechercher des mises à jour';

  @override
  String updatesBuild({required int build}) {
    return 'Build $build';
  }

  @override
  String get updatesChecking => 'Recherche en cours';

  @override
  String get followedSortViewers => 'Spectateurs (décroissant)';

  @override
  String get followedSortRecent => 'Lancés récemment';

  @override
  String get followedSortName => 'Nom (A-Z)';

  @override
  String get followedSortCategory => 'Catégorie';

  @override
  String releaseKindAdded({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveautés',
      one: '$count nouveauté',
    );
    return '$_temp0';
  }

  @override
  String releaseKindImproved({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count améliorations',
      one: '$count amélioration',
    );
    return '$_temp0';
  }

  @override
  String releaseKindFixed({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count corrections',
      one: '$count correction',
    );
    return '$_temp0';
  }

  @override
  String releaseKindOther({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications',
      one: '$count modification',
    );
    return '$_temp0';
  }

  @override
  String get releaseNotesWhatsNew => 'QUOI DE NEUF';

  @override
  String releaseNotesWhatsNewIn({required String version}) {
    return 'QUOI DE NEUF DANS LA $version';
  }

  @override
  String releaseNotesUpdatedTo({required String version}) {
    return 'Version $version installée';
  }

  @override
  String releaseNotesWasOn({required String version}) {
    return 'Vous utilisiez la $version';
  }

  @override
  String releaseNotesWasOnSince({required String version}) {
    return 'Vous utilisiez la $version. Voici ce qui a changé depuis.';
  }

  @override
  String get releaseNotesOtherVersions => 'Autres versions';

  @override
  String get releaseNotesGotIt => 'J’ai compris';

  @override
  String get releaseNotesVersions => 'Versions';

  @override
  String get releaseNotesFootnote =>
      'Les notes de version s’ouvrent d’elles-mêmes après une mise à jour vers une nouvelle version.';

  @override
  String releaseNotesPoints({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '$count point',
    );
    return '$_temp0';
  }

  @override
  String get releaseNotesLatest => 'Dernière';

  @override
  String get releaseNotesLatestBadge => 'DERNIÈRE';

  @override
  String get releaseNotesNewer => 'Plus récente';

  @override
  String get releaseNotesOlder => 'Plus ancienne';

  @override
  String get releaseNotesEmpty => 'Aucune note de version pour l’instant';

  @override
  String get releaseNotesEmptyDetail =>
      'Les nouveautés de chaque version d’ONSET s’affichent ici, et cette page s’ouvre d’elle-même après une mise à jour.';

  @override
  String get updateAllowTitle => 'Autoriser les mises à jour';

  @override
  String get updateAllowMessage =>
      'Android vous demande d’autoriser ONSET à installer des applications. Activez « Autoriser cette source » sur l’écran suivant, puis revenez.';

  @override
  String get updateOpenSettings => 'Ouvrir les paramètres';

  @override
  String get updateNotAllowed =>
      'ONSET n’est pas autorisé à installer des mises à jour';

  @override
  String get updateCorrupted =>
      'Le fichier téléchargé est corrompu – réessayez';

  @override
  String get updateInstallFailed =>
      'Android n’a pas pu installer la mise à jour';

  @override
  String get updateDownloadFailed => 'Échec du téléchargement';

  @override
  String updateInstalledBuild({required int build}) {
    return 'Installé : build $build';
  }

  @override
  String updateSize({required double megabytes}) {
    final intl.NumberFormat megabytesNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String megabytesString = megabytesNumberFormat.format(megabytes);

    return '$megabytesString Mo';
  }

  @override
  String get updateChecked => 'Empreinte SHA-256 vérifiée avant l’installation';

  @override
  String get updateAvailable => 'Mise à jour disponible';

  @override
  String get updateNewBuild => 'NOUVEAU BUILD';

  @override
  String updateReady({required int build}) {
    return 'Le build $build d’ONSET est prêt.';
  }

  @override
  String get updateNow => 'Mettre à jour';

  @override
  String get updateLater => 'Plus tard';

  @override
  String get updateInstalling => 'Installation de la mise à jour';

  @override
  String get updateDownloading => 'Téléchargement de la mise à jour';

  @override
  String updateProgress({required double received, required double total}) {
    final intl.NumberFormat receivedNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String receivedString = receivedNumberFormat.format(received);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String totalString = totalNumberFormat.format(total);

    return '$receivedString / $totalString Mo';
  }

  @override
  String streamPreviewSemantics({required String name}) {
    return '$name, aperçu du live';
  }

  @override
  String get streamEnlargeHint => 'agrandir';

  @override
  String streamViewers({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString spectateurs',
      one: '$countString spectateur',
    );
    return '$_temp0';
  }

  @override
  String streamViewersCompact({required int count}) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString spectateurs',
      one: '$countString spectateur',
    );
    return '$_temp0';
  }

  @override
  String streamWatching({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString spectateurs',
      one: '$countString spectateur',
    );
    return '$_temp0';
  }

  @override
  String streamWatchingShort({required int count, required String viewers}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$viewers spectateurs',
      one: '$viewers spectateur',
    );
    return '$_temp0';
  }

  @override
  String streamWatchStreakSemantics({required int value}) {
    return 'Série de visionnage : $value';
  }

  @override
  String streamStreak({required int value}) {
    return 'Série $value';
  }

  @override
  String get streamNoCategory => 'Aucune catégorie';

  @override
  String streamTagsSemantics({required String tags}) {
    return 'Tags : $tags';
  }

  @override
  String streamTagSemantics({required String tag}) {
    return 'Tag $tag';
  }

  @override
  String get streamWatch => 'Regarder';

  @override
  String get streamOffline => 'Hors ligne';

  @override
  String streamFollowingForYears({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Suivie depuis $count ans',
      one: 'Suivie depuis $count an',
    );
    return '$_temp0';
  }

  @override
  String streamFollowingForMonths({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Suivie depuis $count mois',
      one: 'Suivie depuis $count mois',
    );
    return '$_temp0';
  }

  @override
  String streamFollowingForDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Suivie depuis $count jours',
      one: 'Suivie depuis $count jour',
    );
    return '$_temp0';
  }

  @override
  String streamFollowingForHours({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Suivie depuis $count heures',
      one: 'Suivie depuis $count heure',
    );
    return '$_temp0';
  }

  @override
  String streamFollowingForMinutes({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Suivie depuis $count minutes',
      one: 'Suivie depuis $count minute',
    );
    return '$_temp0';
  }

  @override
  String get followedCategoriesTitle => 'Catégories';

  @override
  String get apiErrorUnableToConnect => 'Impossible de joindre Twitch';

  @override
  String get apiErrorNetwork =>
      'Pas de connexion Internet. Vérifiez votre réseau.';

  @override
  String get apiErrorConnectionTimeout => 'La connexion a expiré. Réessayez.';

  @override
  String get apiErrorSendTimeout => 'L’envoi a pris trop de temps. Réessayez.';

  @override
  String get apiErrorReceiveTimeout =>
      'Le serveur a mis trop de temps à répondre. Réessayez.';

  @override
  String get apiErrorCancelled => 'La requête a été annulée';

  @override
  String get apiErrorCertificate => 'Erreur de certificat de sécurité';

  @override
  String get apiErrorUnexpected => 'Une erreur inattendue est survenue';

  @override
  String get apiErrorBadRequest => 'Requête non valide';

  @override
  String get apiErrorUnauthorized => 'Connectez-vous pour continuer';

  @override
  String get apiErrorForbidden => 'Accès refusé. Autorisations insuffisantes';

  @override
  String get apiErrorNotFound => 'Contenu introuvable';

  @override
  String get apiErrorConflict => 'Le contenu a changé entre-temps. Actualisez';

  @override
  String get apiErrorInvalid => 'Données non valides';

  @override
  String get apiErrorRateLimited =>
      'Trop de requêtes. Patientez avant de réessayer';

  @override
  String get apiErrorServer => 'Erreur du serveur. Réessayez plus tard';

  @override
  String get apiErrorUnavailable => 'Service temporairement indisponible';

  @override
  String get apiErrorMaintenance =>
      'Service en maintenance. Réessayez plus tard';

  @override
  String get apiErrorServerTimeout => 'Le serveur ne répond pas. Réessayez';

  @override
  String apiErrorHttp({required int status}) {
    return 'Erreur HTTP $status';
  }

  @override
  String get apiErrorUserNotFound => 'Cet utilisateur n’existe pas';

  @override
  String get apiErrorChannelNotFound => 'Cette chaîne n’existe pas';

  @override
  String get apiErrorCategoryNotFound => 'Catégorie introuvable';

  @override
  String get apiErrorTokenProxyTimeout =>
      'Le serveur d’ONSET n’a pas répondu à temps';

  @override
  String get streamSortViewersHigh => 'Spectateurs (décroissant)';

  @override
  String get streamSortRecommended => 'Recommandés';

  @override
  String get streamSortViewersLow => 'Spectateurs (croissant)';

  @override
  String get streamSortRecent => 'Lancés récemment';

  @override
  String get streamSortTooltip => 'Trier les lives';

  @override
  String get followedSortTooltip => 'Trier les chaînes en direct';

  @override
  String streamSortedBy({required String sort}) {
    return 'Tri : $sort';
  }

  @override
  String get streamListTagUnavailable =>
      'Les lives de ce tag sont indisponibles pour le moment';

  @override
  String streamListSortFailed({
    required String sort,
    required String fallback,
  }) {
    return 'Twitch n’a pas pu trier par « $sort ». Le tri « $fallback » fonctionne toujours.';
  }

  @override
  String get streamListLoadFailed =>
      'Une erreur est survenue lors du chargement des lives';

  @override
  String get streamListPinnedFailed =>
      'Une erreur est survenue lors du chargement des lives épinglés';

  @override
  String get streamListOfflineFailed =>
      'Une erreur est survenue lors du chargement des chaînes hors ligne';

  @override
  String get streamListAllHidden =>
      'Tous les lives de cette liste portent une classification que vous masquez';

  @override
  String get streamListShowHidden => 'Les afficher';

  @override
  String get streamListEmptyFollowed => 'Aucune chaîne suivie en direct';

  @override
  String get streamListEmptyTop => 'Aucun live pour le moment';

  @override
  String get streamListEmptyLive => 'Aucun live en cours';

  @override
  String get streamListPinned => 'Épinglées';

  @override
  String get streamListAll => 'Toutes';

  @override
  String get streamListLiveNow => 'En direct';

  @override
  String streamListHiddenCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lives masqués par vos préférences de contenu',
      one: '$count live masqué par vos préférences de contenu',
    );
    return '$_temp0';
  }

  @override
  String get streamListShow => 'Afficher';

  @override
  String get followedVideosTitle => 'Vidéos des chaînes suivies';

  @override
  String get contentWarningTitle => 'Un instant…';

  @override
  String get contentWarningAudience =>
      'Ce contenu est destiné à certains publics.';

  @override
  String contentWarningAudienceOf({required String name}) {
    return 'Le contenu de la chaîne $name est destiné à certains publics.';
  }

  @override
  String contentWarningMayContain({required String labels}) {
    return 'Il peut contenir : $labels';
  }

  @override
  String get contentWarningStart => 'Commencer à regarder';

  @override
  String get contentWarningBack => 'Retour';

  @override
  String liveFeedHidden({required String name}) {
    return 'Vous ne verrez plus $name dans l’onglet En direct pour le moment';
  }

  @override
  String get liveFeedUndo => 'Annuler';

  @override
  String get liveFeedAllCategories => 'Toutes';

  @override
  String get liveFeedPreviewUnavailable => 'Aperçu indisponible';

  @override
  String get liveFeedContentWarningSemantics =>
      'Avertissement de contenu. Lire l’aperçu';

  @override
  String get liveFeedContentWarning =>
      'Avertissement de contenu · Lire l’aperçu';

  @override
  String get liveFeedPlayPreview => 'Lire l’aperçu';

  @override
  String get liveFeedUnmute => 'Réactiver le son';

  @override
  String get liveFeedMute => 'Couper le son';

  @override
  String get liveFeedSoundOn => 'Son activé';

  @override
  String get liveFeedMuted => 'Son coupé';

  @override
  String get liveFeedWatchWithChat => 'Regarder avec le chat';

  @override
  String liveFeedFollowOnTwitch({required String name}) {
    return 'Suivre $name sur Twitch';
  }

  @override
  String get liveFeedFollow => 'Suivre';

  @override
  String liveFeedPreviewSemantics({required String name}) {
    return '$name, aperçu du live. Ouvre la chaîne';
  }

  @override
  String get liveFeedChannelActions => 'Actions sur la chaîne';

  @override
  String get liveFeedNotInterested => 'Ça ne m’intéresse pas';

  @override
  String get liveFeedShare => 'Partager';

  @override
  String get liveFeedSwipeHint => 'BALAYEZ POUR PASSER AU LIVE SUIVANT';

  @override
  String get liveFeedUpNext => 'À SUIVRE';

  @override
  String get liveFeedUpNextHelp =>
      'Balayez l’aperçu vers le haut ou appuyez sur un live de la liste. Les aperçus démarrent toujours sans son.';

  @override
  String get liveFeedLoadingMore => 'Chargement d’autres chaînes en direct';

  @override
  String get liveFeedEnd =>
      'Vous avez fait le tour des chaînes en direct pour le moment';

  @override
  String get liveFeedBackToFirst => 'Revenir au début';

  @override
  String get commonSeeAll => 'Tout voir';

  @override
  String get searchTabTop => 'Tout';

  @override
  String get searchTabChannels => 'Chaînes';

  @override
  String get searchTabCategories => 'Catégories';

  @override
  String get searchTabVideos => 'Vidéos';

  @override
  String get searchClear => 'Effacer';

  @override
  String get searchHint => 'Rechercher des chaînes, catégories ou vidéos';

  @override
  String searchSeeAllSemantics({required String section}) {
    return 'Tout voir : $section';
  }

  @override
  String get searchHistory => 'Historique';

  @override
  String searchRemoveFromHistory({required String query}) {
    return 'Retirer « $query » de l’historique';
  }

  @override
  String get searchNoHistory => 'Aucune recherche récente';

  @override
  String get searchCategoriesFailed => 'Impossible de charger les catégories';

  @override
  String get searchCategoriesUnavailable =>
      'Impossible d’obtenir les catégories';

  @override
  String get searchNoCategories => 'Aucune catégorie correspondante';

  @override
  String get searchChannelNotFound => 'Chaîne introuvable';

  @override
  String get searchChannelsFailed => 'Impossible de charger les chaînes';

  @override
  String searchGoToChannel({required String query}) {
    return 'Aller à la chaîne « $query »';
  }

  @override
  String get searchVideosFailed => 'Impossible de charger les vidéos';

  @override
  String get searchNoResults => 'Aucun résultat';

  @override
  String browseLiveChannels({required String where}) {
    return 'Chaînes en direct $where';
  }

  @override
  String get browseAcrossTwitch => 'sur tout Twitch';

  @override
  String get categoriesEmpty => 'Aucune catégorie pour le moment';

  @override
  String get categoriesLoadFailed =>
      'Une erreur est survenue lors du chargement des catégories';

  @override
  String get categoriesRailTitle => 'Catégories';

  @override
  String get categoriesRailNote => 'Les plus regardées d’abord';

  @override
  String get categorySectionLive => 'En direct';

  @override
  String get categorySectionVideos => 'Vidéos';

  @override
  String get categorySectionClips => 'Clips';

  @override
  String get categoryNoVideos => 'Aucune vidéo dans cette catégorie';

  @override
  String get categoryEyebrow => 'CATÉGORIE';

  @override
  String get categoryFollowOnTwitch => 'Suivre sur Twitch';

  @override
  String get followedVideosToday => 'Aujourd’hui';

  @override
  String get followedVideosYesterday => 'Hier';

  @override
  String get followedVideosThisWeek => 'Cette semaine';

  @override
  String get followedVideosOlder => 'Plus anciennes';

  @override
  String get followedVideosEmpty => 'Aucune vidéo récente';

  @override
  String get followedVideosSubtitle =>
      'Les dernières vidéos des chaînes que vous suivez';

  @override
  String get followedVideosRefresh => 'Actualiser';

  @override
  String get followedVideosLoadFailed =>
      'Une erreur est survenue lors du chargement des vidéos';

  @override
  String get continueWatchingTitle => 'Continuer à regarder';

  @override
  String continueWatchingResumeAt({required String time}) {
    return 'Reprendre à $time';
  }

  @override
  String get continueWatchingEmpty => 'Rien à reprendre';

  @override
  String get savedToday => 'aujourd’hui';

  @override
  String get savedYesterday => 'hier';

  @override
  String savedDaysAgo({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'il y a $count jour',
    );
    return '$_temp0';
  }

  @override
  String savedWeeksAgo({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count sem.',
      one: 'il y a $count sem.',
    );
    return '$_temp0';
  }

  @override
  String savedMonthsAgo({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count mois',
      one: 'il y a $count mois',
    );
    return '$_temp0';
  }

  @override
  String get timeAgoJustNow => 'À l’instant';

  @override
  String timeAgoMinutes({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count minutes',
      one: 'Il y a $count minute',
    );
    return '$_temp0';
  }

  @override
  String timeAgoHours({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count heures',
      one: 'Il y a $count heure',
    );
    return '$_temp0';
  }

  @override
  String get timeAgoYesterday => 'Hier';

  @override
  String timeAgoDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count jours',
      one: 'Il y a $count jour',
    );
    return '$_temp0';
  }

  @override
  String timeAgoWeeks({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count semaines',
      one: 'Il y a $count semaine',
    );
    return '$_temp0';
  }

  @override
  String timeAgoMonths({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count mois',
      one: 'Il y a $count mois',
    );
    return '$_temp0';
  }

  @override
  String timeAgoYears({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count ans',
      one: 'Il y a $count an',
    );
    return '$_temp0';
  }

  @override
  String videoViews({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString vues',
      one: '$countString vue',
    );
    return '$_temp0';
  }

  @override
  String videoViewsCompact({required int count}) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString vues',
      one: '$countString vue',
    );
    return '$_temp0';
  }

  @override
  String videoViewsShort({required int count, required String views}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$views vues',
      one: '$views vue',
    );
    return '$_temp0';
  }

  @override
  String get clipUntitled => 'Clip sans titre';

  @override
  String get clipsPlayerSemantics =>
      'Lecteur de clip. Appuyez deux fois pour lire ou mettre en pause';

  @override
  String get clipsCannotPlay => 'Impossible de lire ce clip ici';

  @override
  String get clipsLoadingMore => 'Chargement d’autres clips pour vous';

  @override
  String get clipsLoadFailed => 'Impossible de charger les clips';

  @override
  String get clipsEmpty => 'Aucun clip pour le moment';

  @override
  String get clipsOpen => 'Ouvrir le clip';

  @override
  String clipsNextSemantics({required String channel, required String title}) {
    return 'Clip suivant, $channel, $title';
  }

  @override
  String get clipsNext => 'SUIVANT';

  @override
  String get clipsSwipeHint => 'Balayez pour passer au clip suivant';

  @override
  String get clipsLoadMoreFailed => 'Impossible de charger d’autres clips';

  @override
  String get clipsEnd =>
      'C’est tout pour le moment ! Découvrez d’autres clips des lives précédents';

  @override
  String get clipsUpNext => 'À suivre dans Clips';

  @override
  String get clipsUpNextHelp => 'Balayez la vidéo ou choisissez un clip';

  @override
  String clipOpenChannel({required String channel}) {
    return 'Ouvrir $channel';
  }

  @override
  String clipOpenChannelClippedBy({
    required String channel,
    required String curator,
  }) {
    return 'Ouvrir $channel, clip créé par $curator';
  }

  @override
  String clipClippedBy({required String curator}) {
    return 'Créé par $curator';
  }

  @override
  String get clipWatchFullVideo => 'Regarder la vidéo complète';

  @override
  String get clipCopyLink => 'Copier le lien';

  @override
  String get clipShare => 'Partager';

  @override
  String get clipsNoneForPeriod => 'Aucun clip sur cette période';

  @override
  String clipsShowingTop({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Voici les $count premiers clips',
      one: 'Voici le premier clip',
    );
    return '$_temp0';
  }

  @override
  String get clipsCategoryNotFound => 'Catégorie introuvable';

  @override
  String get clipsChannelNotFound => 'Chaîne introuvable';

  @override
  String get clipsListFailed => 'Impossible de charger les clips';

  @override
  String clipsMoreFrom({required String channel}) {
    return 'Autres clips de la chaîne $channel';
  }

  @override
  String get clipLinkCopied => 'Lien copié';

  @override
  String get clipCopyClipLink => 'Copier le lien du clip';

  @override
  String get clipDetailsFailed => 'Impossible de charger les détails du clip';

  @override
  String get clipSyncedToClip => 'synchronisé avec le clip';

  @override
  String playbackSubscriberOnly({required String subject}) {
    String _temp0 = intl.Intl.selectLogic(subject, {
      'clip': 'Ce clip est réservé aux abonnés.',
      'other': 'Cette vidéo est réservée aux abonnés.',
    });
    return '$_temp0';
  }

  @override
  String playbackGeoBlocked({required String subject}) {
    String _temp0 = intl.Intl.selectLogic(subject, {
      'clip': 'Ce clip n’est pas disponible dans votre région',
      'other': 'Cette vidéo n’est pas disponible dans votre région',
    });
    return '$_temp0';
  }

  @override
  String playbackNotFound({required String subject}) {
    String _temp0 = intl.Intl.selectLogic(subject, {
      'clip': 'Ce clip n’est plus disponible',
      'other': 'Cette vidéo n’est plus disponible',
    });
    return '$_temp0';
  }

  @override
  String playbackFailed({required String subject}) {
    String _temp0 = intl.Intl.selectLogic(subject, {
      'clip': 'Impossible de lire ce clip',
      'other': 'Impossible de lire cette vidéo',
    });
    return '$_temp0';
  }

  @override
  String get playbackSubscribeDetail =>
      'Abonnez-vous pour regarder et soutenir cette chaîne.';

  @override
  String get clipPeriodLastDay => '24 heures';

  @override
  String get clipPeriodLastWeek => '7 jours';

  @override
  String get clipPeriodLastMonth => '30 jours';

  @override
  String get clipPeriodAllTime => 'Depuis toujours';

  @override
  String get clipSortTop => 'Les plus vus';

  @override
  String get clipSortTrending => 'Tendances';

  @override
  String get profileTabHome => 'Accueil';

  @override
  String get profileTabVideos => 'Vidéos';

  @override
  String get profileTabClips => 'Clips';

  @override
  String get profileTabSchedule => 'Planning';

  @override
  String get profileTabAbout => 'À propos';

  @override
  String get profileRefreshFailed => 'Impossible d’actualiser cette chaîne';

  @override
  String get profileOpenFailed =>
      'Impossible d’ouvrir cette chaîne. Vérifiez votre connexion Internet.';

  @override
  String get profileShare => 'Partager';

  @override
  String get profileMore => 'Plus d’options';

  @override
  String get profileLoadFailed =>
      'Impossible de charger le profil de cette chaîne';

  @override
  String get profileNoDetails => 'Aucun détail';

  @override
  String get profileScheduleFailed => 'Impossible de charger le planning';

  @override
  String get profileNotFound => 'Chaîne introuvable';

  @override
  String profileFollowers({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString followers',
      one: '$countString follower',
    );
    return '$_temp0';
  }

  @override
  String profileFollowersShort({
    required int count,
    required String followers,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$followers followers',
      one: '$followers follower',
    );
    return '$_temp0';
  }

  @override
  String profileJoined({required DateTime date}) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMM(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Membre depuis $dateString';
  }

  @override
  String get profilePartner => 'Partenaire';

  @override
  String get profileAffiliate => 'Affilié';

  @override
  String profileAboutTitle({required String name}) {
    return 'À propos de la chaîne $name';
  }

  @override
  String get profileNoBio => 'Aucune bio pour l’instant.';

  @override
  String get profilePanelImage => 'Image du panneau';

  @override
  String get profileWatchLive => 'Regarder le live';

  @override
  String get profileChat => 'Chat';

  @override
  String profileNextStreamAt({required String time}) {
    return 'Prochain live · $time';
  }

  @override
  String get profileComingUp => 'À venir';

  @override
  String get profileRecentBroadcasts => 'Diffusions récentes';

  @override
  String get profilePopularClips => 'Clips populaires';

  @override
  String get profileThumbnail => 'Miniature';

  @override
  String get videoUntitled => 'Sans titre';

  @override
  String get profileRecording => 'En cours';

  @override
  String get profileWatched => 'Regardée';

  @override
  String get profileSubscribersOnly => 'Réservé aux abonnés';

  @override
  String profileLastLive({required String when}) {
    return 'Dernier live $when';
  }

  @override
  String get profileRerun => 'Rediffusion';

  @override
  String get profileRerunBadge => 'REDIFF';

  @override
  String get profileLive => 'En direct';

  @override
  String get profileReminderSet => 'Rappel activé';

  @override
  String get profileRemindMe => 'Me le rappeler';

  @override
  String get startsNow => 'imminent';

  @override
  String startsInMinutes({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans $count minutes',
      one: 'dans $count minute',
    );
    return '$_temp0';
  }

  @override
  String startsInHours({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans $count heures',
      one: 'dans $count heure',
    );
    return '$_temp0';
  }

  @override
  String startsInDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans $count jours',
      one: 'dans $count jour',
    );
    return '$_temp0';
  }

  @override
  String get profileReminderRefused =>
      'Autorisez les notifications de cette application dans les paramètres du système.';

  @override
  String get profileReminderFailed => 'Impossible de programmer le rappel.';

  @override
  String get profileStreamUntitled => 'Live sans titre';

  @override
  String get profileNoSchedule => 'Aucun live prévu';

  @override
  String profileNextStreamIn({required String when, required String time}) {
    return 'Prochain live $when · $time';
  }

  @override
  String get profileCancelled => 'Annulé';

  @override
  String get profilePastBroadcasts => 'Anciennes diffusions';

  @override
  String get profileNoPastBroadcasts => 'Aucune ancienne diffusion';

  @override
  String get profileHighlights => 'Temps forts';

  @override
  String get profileNoHighlights => 'Aucun temps fort';

  @override
  String get profileUploads => 'Mises en ligne';

  @override
  String get profileNoUploads => 'Aucune mise en ligne';

  @override
  String get videosListFailed => 'Impossible de charger les vidéos';

  @override
  String videosShowingMostViewed({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Voici les $count vidéos les plus vues',
      one: 'Voici la vidéo la plus vue',
    );
    return '$_temp0';
  }

  @override
  String videosShowingMostRecent({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Voici les $count vidéos les plus récentes',
      one: 'Voici la vidéo la plus récente',
    );
    return '$_temp0';
  }

  @override
  String get videoProcessing => 'En traitement';

  @override
  String get videoUntitledBroadcast => 'Diffusion sans titre';

  @override
  String get activityTitle => 'Activité';

  @override
  String get activityNote =>
      'Les notifications envoyées par ONSET sur cet appareil.';

  @override
  String get activityRemove => 'Supprimer la notification';

  @override
  String get activityEmpty => 'Parfait ! Vous êtes à jour';

  @override
  String get activityEmptyDetail =>
      'Revenez bientôt pour voir les alertes qui vous concernent et celles des chaînes que vous suivez.';

  @override
  String get activityMostRecent => 'Récentes';

  @override
  String get activityEarlier => 'Plus anciennes';

  @override
  String get activityMarkAllRead => 'Tout marquer comme lu';

  @override
  String get activityOptions => 'Options';

  @override
  String get activityUnread => 'Non lue';

  @override
  String get activityNoWhispers =>
      'Aucun chuchotement pour l’instant. Ceux que vous recevez quand l’application est ouverte s’affichent ici.';

  @override
  String get activityKindLive => 'En direct';

  @override
  String get activityKindMention => 'Mentions dans le chat';

  @override
  String get activityKindReminder => 'Événements';

  @override
  String get whispersTitle => 'Chuchotements';

  @override
  String whispersUnreadCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count non lus',
      one: '$count non lu',
    );
    return '$_temp0';
  }

  @override
  String get whispersAllRead => 'Tout est lu';

  @override
  String get whispersChoose => 'Choisissez une conversation';

  @override
  String get whispersEmpty => 'Aucun chuchotement pour l’instant';

  @override
  String get whispersEmptyDetail =>
      'Les chuchotements reçus pendant que l’application est ouverte s’affichent ici.';

  @override
  String get whisperSessionNote =>
      'Twitch ne conserve aucun historique que l’application puisse afficher : seuls les chuchotements de cette session apparaissent ici.';

  @override
  String whisperHint({required String name}) {
    return 'Chuchoter à $name';
  }

  @override
  String get whisperSend => 'Envoyer';

  @override
  String get whisperYou => 'Vous';

  @override
  String get whisperOpen => 'Ouvrir';

  @override
  String get whisperStatusRefused =>
      'Twitch refuse d’envoyer vos chuchotements à cette application. Déconnectez-vous puis reconnectez-vous pour les autoriser.';

  @override
  String get whisperStatusInterrupted =>
      'Reconnexion… les chuchotements reviendront bientôt.';

  @override
  String get whisperStatusUnavailable =>
      'Twitch n’envoie pas de chuchotements à cette application pour le moment. Une nouvelle tentative aura lieu à votre retour dans l’application.';

  @override
  String get whisperStatusOff =>
      'Connectez-vous pour recevoir des chuchotements.';

  @override
  String get playerBack10 => 'Reculer de 10 secondes';

  @override
  String get playerForward10 => 'Avancer de 10 secondes';

  @override
  String get playerChangeChatLayout => 'Changer la disposition du chat';

  @override
  String get playerHideChatOverlay => 'Masquer le chat superposé';

  @override
  String get playerShowChatOverlay => 'Afficher le chat superposé';

  @override
  String get playerStopLooping => 'Ne plus lire en boucle';

  @override
  String get playerLoop => 'Lire en boucle';

  @override
  String get playerSettings => 'Paramètres';

  @override
  String get playerReplay => 'Revoir';

  @override
  String get playerPlay => 'Lire';

  @override
  String get playerPause => 'Mettre en pause';

  @override
  String playerElapsed({required String elapsed, required String total}) {
    return 'Temps écoulé : $elapsed sur $total';
  }

  @override
  String get playerPictureInPicture => 'Picture-in-picture';

  @override
  String get playerFitScreen => 'Adapter à l’écran';

  @override
  String get playerFillScreen => 'Remplir l’écran';

  @override
  String get playerExitFullScreen => 'Quitter le plein écran';

  @override
  String get playerFullScreen => 'Plein écran';

  @override
  String get playerSpeed => 'Vitesse de lecture';

  @override
  String get playerQuality => 'Qualité';

  @override
  String get playerVolume => 'Volume';

  @override
  String get playerCaptions => 'Sous-titres';

  @override
  String get playerCaptionsDetail => 'Si la vidéo en propose';

  @override
  String get playerSpeedNormal => 'Normale';

  @override
  String get playerSemantics => 'Lecteur vidéo';

  @override
  String get playerHideControls => 'masquer les commandes';

  @override
  String get playerShowControls => 'afficher les commandes';

  @override
  String get channelFollow => 'Suivre';

  @override
  String get channelFollowing => 'Suivie';

  @override
  String channelFollowTooltip({required String name}) {
    return 'Suivre $name sur Twitch';
  }

  @override
  String channelFollowingTooltip({required String name}) {
    return 'Vous suivez $name · ouvre twitch.tv';
  }

  @override
  String get channelSubscribe => 'S’abonner';

  @override
  String channelSubscribeTooltip({required String name}) {
    return 'S’abonner à $name · ouvre twitch.tv';
  }
}
