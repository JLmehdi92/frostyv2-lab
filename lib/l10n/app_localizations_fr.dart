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
      'Bannissements, AutoMod, termes, mode bouclier, modes du chat';

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
      'ONSET recherche lui-même les nouveaux builds, et les notes de version s’ouvrent après chaque mise à jour.';

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
  String get settingsConfirmLinks => 'Demander avant d’ouvrir un lien';

  @override
  String get settingsConfirmLinksDetail =>
      'Indique où mène un lien du chat ou du profil d’une chaîne avant de l’ouvrir.';

  @override
  String get linkConfirmTitle => 'Ouvrir ce lien ?';

  @override
  String linkConfirmBody({required String host}) {
    return 'Ce lien mène à $host, en dehors d’ONSET.';
  }

  @override
  String get linkConfirmDontAsk => 'Ne plus demander';

  @override
  String get linkConfirmOpen => 'Ouvrir';

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
  String get settingsBackgroundAudioHeadphonesOnly =>
      'Uniquement avec un casque ou des écouteurs';

  @override
  String get settingsBackgroundAudioHeadphonesOnlyDetail =>
      'Met le live en pause quand vous quittez l’application sans casque ni écouteurs connectés.';

  @override
  String get settingsAutoPip => 'Picture-in-picture automatique';

  @override
  String get settingsAutoPipDetail =>
      'Garde une vidéo en cours de lecture dans une fenêtre flottante quand vous quittez l’application.';

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
  String get settingsReadableNameColors => 'Couleurs de pseudo lisibles';

  @override
  String get settingsReadableNameColorsDetail =>
      'Éclaircit ou assombrit les couleurs de pseudo difficiles à lire sur le fond.';

  @override
  String get settingsReadableNameColorsLocked =>
      'Toujours activé tant que le contraste du chat est augmenté.';

  @override
  String get settingsIncreaseChatContrast => 'Augmenter le contraste du chat';

  @override
  String get settingsIncreaseChatContrastDetail =>
      'Renforce le contraste entre les couleurs de pseudo et le fond.';

  @override
  String get timestampDisabled => 'Désactivé';

  @override
  String get timestampTwelve => '12 heures';

  @override
  String get timestampTwentyFour => '24 heures';

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
  String get settingsPortraitChatHeight => 'Hauteur du chat en portrait';

  @override
  String get settingsPortraitChatHeightDetail =>
      'Vous pouvez aussi faire glisser la barre sous la vidéo.';

  @override
  String get portraitChatHeightLow => 'Basse';

  @override
  String get portraitChatHeightMedium => 'Moyenne';

  @override
  String get portraitChatHeightHigh => 'Haute';

  @override
  String get portraitChatHeightCustom => 'Personnalisée';

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
  String get settingsHideGiftSubNotices => 'Masquer les abonnements offerts';

  @override
  String get settingsHideGiftSubNoticesDetail =>
      'Les abonnements offerts, les cadeaux à la communauté et les abonnements bonus des sponsors ne s’affichent plus dans le chat.';

  @override
  String get settingsHideGiftCount => 'Masquer le total des cadeaux';

  @override
  String get settingsHideGiftCountDetail =>
      'N’affiche plus le nombre d’abonnements offerts par un spectateur sur la chaîne.';

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
  String get settingsTapToCloseOverlay =>
      'Appuyer pour fermer le chat superposé';

  @override
  String get settingsTapToCloseOverlayDetail =>
      'Un appui sur une zone vide du chat superposé à la vidéo le masque.';

  @override
  String get settingsChatSwitching =>
      'Appuyer deux fois sur la vidéo en paysage';

  @override
  String get settingsChatSwitchingOverlay => 'Chat superposé à la vidéo';

  @override
  String get settingsChatSwitchingDetail =>
      'Un double appui sur la vidéo passe à la disposition suivante parmi celles activées ici. Gardez-en au moins deux.';

  @override
  String get settingsChatSwitchingColumn => 'Chat à côté de la vidéo';

  @override
  String get settingsChatSwitchingHidden => 'Sans chat';

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
  String get mutedKeywordsHint => 'Mots-clés à masquer';

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
  String get notificationPermissionTitle => 'Autoriser les notifications ?';

  @override
  String get notificationPermissionMessage =>
      'ONSET peut vous prévenir quand une chaîne que vous suivez lance un live, quand quelqu’un vous mentionne dans le chat et quand commence un live pour lequel vous avez activé un rappel. Votre appareil vous demandera ensuite l’autorisation.';

  @override
  String get notificationPermissionNotNow => 'Plus tard';

  @override
  String get notificationPermissionContinue => 'Continuer';

  @override
  String get goLiveBellFailed => 'Impossible de modifier la cloche.';

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
  String get streamWatchLatestBroadcast => 'Voir la dernière diffusion';

  @override
  String get streamEndedPlayingBroadcast =>
      'Le live est terminé. Lecture de son ancienne diffusion.';

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
  String get apiErrorConnectionTimeout =>
      'Impossible de joindre Twitch à temps. Réessayez.';

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
  String audienceLabelMature({required String labels}) {
    return 'Pour certains publics : $labels';
  }

  @override
  String get audienceLabelPaidPromotion => 'Inclut une promotion rémunérée';

  @override
  String get audienceLabelHide => 'Masquer les mentions';

  @override
  String liveFeedHidden({required String name}) {
    return 'Vous ne verrez plus $name dans l’onglet En direct.';
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
  String get searchHint => 'Rechercher';

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
  String get clipNoRecordedChat => 'Ce clip n’a pas de chat enregistré.';

  @override
  String playbackSubscriberOnly({required String subject}) {
    String _temp0 = intl.Intl.selectLogic(subject, {
      'clip': 'Ce clip est réservé aux abonnés.',
      'other': 'Cette vidéo est réservée aux abonnés.',
    });
    return '$_temp0';
  }

  @override
  String playbackProxy({required String subject}) {
    String _temp0 = intl.Intl.selectLogic(subject, {
      'clip': 'Twitch bloque ce clip tant qu’un VPN ou un proxy est utilisé',
      'other':
          'Twitch bloque cette vidéo tant qu’un VPN ou un proxy est utilisé',
    });
    return '$_temp0';
  }

  @override
  String playbackWifiRequired({required String subject}) {
    String _temp0 = intl.Intl.selectLogic(subject, {
      'clip': 'Connectez-vous à un réseau Wi-Fi pour regarder ce clip',
      'other': 'Connectez-vous à un réseau Wi-Fi pour regarder cette vidéo',
    });
    return '$_temp0';
  }

  @override
  String playbackUnsupportedDevice({required String subject}) {
    String _temp0 = intl.Intl.selectLogic(subject, {
      'clip': 'Votre appareil ne peut pas lire ce clip',
      'other': 'Votre appareil ne peut pas lire cette vidéo',
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
  String get overlayChatMove => 'Déplacer le chat';

  @override
  String get overlayChatResize => 'Redimensionner le chat';

  @override
  String get followedDrawerTitle => 'Chaînes suivies';

  @override
  String get followedDrawerLive => 'En direct';

  @override
  String get followedDrawerEmpty => 'Vous ne suivez encore aucune chaîne.';

  @override
  String get followedDrawerFailed =>
      'Impossible de charger vos chaînes suivies.';

  @override
  String get playerStopLooping => 'Ne plus lire en boucle';

  @override
  String get playerLoop => 'Lire en boucle';

  @override
  String get playerSettings => 'Paramètres';

  @override
  String get vodLockScreen => 'Verrouiller l’écran';

  @override
  String get vodUnlockScreen => 'Déverrouiller l’écran';

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

  @override
  String get channelProfile => 'Profil de la chaîne';

  @override
  String get channelVideos => 'Vidéos';

  @override
  String channelWebFallback({required String notice}) {
    return 'Passage au lecteur web. $notice';
  }

  @override
  String get channelSwipeDownForPip =>
      'Balayez vers le bas pour passer en Picture-in-picture';

  @override
  String get channelResizeVideo => 'Redimensionner la vidéo';

  @override
  String get channelResizeVideoHint =>
      'Faites glisser pour changer la taille de la vidéo, appuyez deux fois pour revenir à la pleine largeur';

  @override
  String channelUptimeMinutes({required int minutes}) {
    return '$minutes min';
  }

  @override
  String channelUptimeHours({required int hours, required String minutes}) {
    return '$hours h $minutes';
  }

  @override
  String channelWatchStreak({required int value}) {
    return 'Série $value';
  }

  @override
  String get channelAlsoLive => 'AUTRES CHAÎNES SUIVIES EN DIRECT';

  @override
  String get channelChat => 'Chat';

  @override
  String get channelChatSynced => 'synchronisé avec la vidéo';

  @override
  String channelChatDelay({required int seconds}) {
    return '$seconds s de délai';
  }

  @override
  String get channelChatSettings => 'Paramètres du chat';

  @override
  String get livePlayerQualityAndSettings => 'Qualité et paramètres';

  @override
  String get livePlayerMute => 'Couper le son';

  @override
  String get livePlayerUnmute => 'Réactiver le son';

  @override
  String get livePlayerRefresh => 'Actualiser';

  @override
  String get livePlayerEnterFullScreen => 'Passer en plein écran';

  @override
  String get livePlayerExitFullScreen => 'Quitter le plein écran';

  @override
  String get livePlayerShowChat => 'Afficher le chat';

  @override
  String get livePlayerHideChat => 'Masquer le chat';

  @override
  String get livePlayerEnterLandscape => 'Passer en mode paysage';

  @override
  String get livePlayerExitLandscape => 'Quitter le mode paysage';

  @override
  String get livePlayerEnterPip => 'Passer en Picture-in-picture';

  @override
  String get livePlayerExitPip => 'Quitter le Picture-in-picture';

  @override
  String get livePlayerStreamQuality => 'Qualité du live';

  @override
  String get livePlayerAudioOnly => 'Audio uniquement';

  @override
  String get livePlayerQualityUnavailable => 'Non disponible pour vous';

  @override
  String livePlayerQualityUnavailableBitrate({required String bitrate}) {
    return '$bitrate · Non disponible pour vous';
  }

  @override
  String get livePlayerMeasurement => 'Mesure';

  @override
  String get livePlayerVideoStats => 'Statistiques vidéo';

  @override
  String get livePlayerVideoStatsDetail =>
      'Latence, mémoire tampon, débit et images par-dessus la vidéo';

  @override
  String get livePlayerResetStats => 'Réinitialiser les statistiques';

  @override
  String get livePlayerResetStatsDetail => 'Mesurer à nouveau la latence';

  @override
  String get livePlayerPlayback => 'Lecture';

  @override
  String get livePlayerShareChannel => 'Partager la chaîne';

  @override
  String livePlayerSharedChatTitle({required String title}) {
    return 'Chat partagé · $title';
  }

  @override
  String get sharedChatStarted => 'Chat partagé lancé';

  @override
  String get sharedChatOngoing => 'Ce chat est partagé';

  @override
  String sharedChatStartedBody({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Les messages de $count autres chaînes s’affichent aussi ici.',
      one: 'Les messages d’une autre chaîne s’affichent aussi ici.',
    );
    return '$_temp0';
  }

  @override
  String get sharedChatWith => 'Chat partagé avec';

  @override
  String get livePlayerUptime => 'Durée du live';

  @override
  String get livePlayerViewerCount => 'Nombre de spectateurs';

  @override
  String get liveCaptionsDetail => 'Si le live en propose';

  @override
  String liveCaptionsTrack({required int number}) {
    return 'Sous-titres $number';
  }

  @override
  String liveRefusedSubscribersOnly({required String name}) {
    return 'Ce live de la chaîne $name est réservé aux abonnés.';
  }

  @override
  String get liveRefusedGeoblocked =>
      'Ce live n’est pas disponible dans votre région.';

  @override
  String liveRefusedBanned({required String name}) {
    return 'Votre compte est banni de la chaîne $name.';
  }

  @override
  String get liveRefusedUnauthorized =>
      'Twitch refuse ce live au lecteur de l’application.';

  @override
  String get liveRefused => 'Twitch refuse ce live.';

  @override
  String get liveRefusedProxy =>
      'Twitch bloque ce live tant qu’un VPN ou un proxy est utilisé.';

  @override
  String get liveRefusedWifiRequired =>
      'Connectez-vous à un réseau Wi-Fi pour regarder ce live.';

  @override
  String get liveRefusedUnsupportedDevice =>
      'Votre appareil ne peut pas lire ce live.';

  @override
  String liveRefusedBecause({required String reason}) {
    return 'Twitch refuse ce live : $reason';
  }

  @override
  String latencySeconds({required String value}) {
    return '$value s';
  }

  @override
  String get latencyPillTooltip => 'Latence avec le diffuseur';

  @override
  String get latencyPillTooltipStats =>
      'Latence avec le diffuseur · appuyez pour les statistiques vidéo';

  @override
  String latencyPillSemantics({required String latency}) {
    return 'Latence : $latency';
  }

  @override
  String latencyMegabits({required String value}) {
    return '$value Mbit/s';
  }

  @override
  String latencyKilobits({required int value}) {
    return '$value kbit/s';
  }

  @override
  String get latencyStatsLatency => 'Latence';

  @override
  String get latencyStatsSpread => 'Méd. / p90 / max';

  @override
  String get latencyStatsBuffer => 'Tampon';

  @override
  String get latencyStatsBitrate => 'Débit';

  @override
  String latencyStatsBitrateValue({
    required String bitrate,
    required String network,
  }) {
    return '$bitrate · réseau $network';
  }

  @override
  String get latencyStatsFrames => 'Images';

  @override
  String latencyStatsFramesValue({
    required String fps,
    required String dropped,
    required String decoded,
  }) {
    return '$fps i/s · $dropped perdues / $decoded';
  }

  @override
  String get latencyStatsLowLatency => 'Faible latence';

  @override
  String get latencyStatsOn => 'activée';

  @override
  String get latencyStatsOff => 'désactivée';

  @override
  String get latencyStatsSpeed => 'Vitesse';

  @override
  String latencyStatsRate({required String rate}) {
    return '$rate ×';
  }

  @override
  String get latencyStatsMode => 'Mode';

  @override
  String get latencyStatsAutoLatency => 'Latence auto';

  @override
  String get latencyStatsNextStreams => 'Lives suivants';

  @override
  String get latencyStatsStartup => 'Démarrage';

  @override
  String get latencyStatsRebuffers => 'Blocages';

  @override
  String get latencyStatsLiveJumps => 'Retours au direct';

  @override
  String get latencyAutoOff => 'désactivée';

  @override
  String latencyAutoWithTarget({
    required String status,
    required String latency,
  }) {
    return '$status · cible $latency';
  }

  @override
  String latencyAutoStopped({required String reason}) {
    return 'arrêtée : $reason';
  }

  @override
  String latencyAutoHeld({required String reason}) {
    return 'suspendue : $reason';
  }

  @override
  String get latencyAutoSettling => 'stabilisation';

  @override
  String latencyAutoSettlingSeconds({required int seconds}) {
    return 'stabilisation $seconds s';
  }

  @override
  String get latencyAutoSteady => 'à la cible';

  @override
  String latencyAutoCatchingUp({required String rate}) {
    return 'rattrapage $rate ×';
  }

  @override
  String latencyAutoDraining({required String rate}) {
    return 'résorption $rate ×';
  }

  @override
  String latencyAutoDrainingBecause({
    required String rate,
    required String reason,
  }) {
    return 'résorption $rate × ($reason)';
  }

  @override
  String get latencyReasonGaveUp => 'abandon';

  @override
  String get latencyReasonHeld => 'en attente';

  @override
  String get latencyReasonAd => 'publicité';

  @override
  String get latencyReasonNoBufferReading => 'aucune mesure du tampon';

  @override
  String get latencyReasonNoLatencyReading => 'aucune mesure de la latence';

  @override
  String get latencyReasonNoLatencyTicks =>
      'mesures de la latence interrompues';

  @override
  String get latencyReasonNotLowLatency => 'live sans faible latence';

  @override
  String get latencyReasonPaused => 'en pause';

  @override
  String get latencyReasonReconnecting => 'reconnexion';

  @override
  String get latencyReasonBuffering => 'chargement';

  @override
  String get latencyReasonRateRefused => 'le lecteur a refusé la vitesse';

  @override
  String get latencyReasonRateNotKept => 'le lecteur n’a pas tenu la vitesse';

  @override
  String get latencyReasonStalls => 'blocages après le rattrapage';

  @override
  String latencyReasonStuckFast({required String rate}) {
    return 'le lecteur est resté à $rate ×';
  }

  @override
  String latencyReasonNotBackToNormal({required String rate}) {
    return 'le lecteur n’est pas revenu à $rate ×';
  }

  @override
  String latencyBufferFallback({required String time}) {
    return 'Standard jusqu’à $time (blocages en « Ultra »)';
  }

  @override
  String get clipCreateTitle => 'Créer un clip';

  @override
  String get clipCreateButton => 'Créer un clip';

  @override
  String get clipCreateGenerating => 'Création du clip…';

  @override
  String get clipCreateRendering => 'Rendu du clip en cours';

  @override
  String get clipCreateLogIn => 'Connectez-vous pour créer des clips.';

  @override
  String get clipCreateLogInAction => 'Se connecter';

  @override
  String get clipCreateMissingScope =>
      'Pour créer des clips, votre connexion Twitch doit disposer d’une autorisation qu’elle n’a pas encore. Reconnectez-vous à Twitch pour l’accorder.';

  @override
  String get clipCreateReconnect => 'Se reconnecter à Twitch';

  @override
  String get clipCreateShare => 'Partager';

  @override
  String get clipCreateLinkCopied => 'Lien du clip copié';

  @override
  String get clipCreateThumbnail => 'Miniature du clip';

  @override
  String get clipCreateEdit => 'Modifier';

  @override
  String get clipCreateEditDetail =>
      'Titre et moment, dans l’éditeur de clips de twitch.tv';

  @override
  String get clipCreateEditorTitle => 'Modifier le clip';

  @override
  String get clipCreateFailedMissingScope =>
      'Votre connexion Twitch ne permet pas de créer des clips.';

  @override
  String get clipCreateFailedRestricted =>
      'Impossible de créer un clip de cette chaîne pour le moment : les clips y sont peut-être désactivés ou réservés aux followers ou aux abonnés, ou votre compte y est banni ou exclu temporairement.';

  @override
  String get clipCreateFailedOffline =>
      'Seuls les lives en cours peuvent faire l’objet d’un clip.';

  @override
  String get clipCreateFailedNotClippable =>
      'Cette chaîne n’autorise pas les clips dans cette catégorie.';

  @override
  String get clipCreateFailedRateLimited =>
      'Trop de clips en même temps. Réessayez dans un instant.';

  @override
  String get clipCreateFailedUnknown => 'Hum… Une erreur est survenue';

  @override
  String get commonHide => 'Masquer';

  @override
  String commonPercent({required int value}) {
    return '$value %';
  }

  @override
  String celebrationEffect({required String effect}) {
    String _temp0 = intl.Intl.selectLogic(effect, {
      'fireworks': 'Feu d’artifice',
      'rain': 'Pluie',
      'float': 'Envolée',
      'flamethrower': 'Lance-flammes',
      'extinctionEvent': 'Extinction de masse',
      'other': 'Étincelles',
    });
    return '$_temp0';
  }

  @override
  String celebrationChatLine({required String effect}) {
    return 'Célébration : $effect';
  }

  @override
  String celebrationChatLineGiftedSubs({required String effect}) {
    return 'Célébration des abonnements offerts : $effect';
  }

  @override
  String highlightKind({required String kind}) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'poll': 'Sondage',
      'prediction': 'Prédiction',
      'pinned': 'Épinglé',
      'raid': 'Raid',
      'giftBomb': 'Abonnements offerts',
      'incomingRaid': 'Raid entrant',
      'other': 'Temps fort',
    });
    return '$_temp0';
  }

  @override
  String highlightNew({required String kind}) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'poll': 'Nouveau sondage',
      'prediction': 'Nouvelle prédiction',
      'pinned': 'Nouveau message épinglé',
      'raid': 'Nouveau raid',
      'giftBomb': 'Nouveaux abonnements offerts',
      'incomingRaid': 'Nouveau raid entrant',
      'other': 'Nouveau temps fort',
    });
    return '$_temp0';
  }

  @override
  String highlightAndMore({required String label, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'et $count autres',
      one: 'et $count autre',
    );
    return '$label $_temp0';
  }

  @override
  String get highlightPrevious => 'Temps fort précédent';

  @override
  String get highlightNext => 'Temps fort suivant';

  @override
  String highlightPosition({required int index, required int count}) {
    return 'Temps fort $index sur $count';
  }

  @override
  String get highlightTwitchChat => 'Chat Twitch';

  @override
  String get highlightThisChannel => 'Cette chaîne';

  @override
  String highlightTimeLeft({required String time}) {
    return 'Encore $time';
  }

  @override
  String highlightVotes({required int count}) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString votes',
      one: '$countString vote',
    );
    return '$_temp0';
  }

  @override
  String get highlightFinalResults => 'Résultats finaux';

  @override
  String get highlightFinalResultsLower => 'résultats finaux';

  @override
  String highlightPollLeads({required String choice, required int percent}) {
    return '$choice est en tête avec $percent pour cent';
  }

  @override
  String get highlightVote => 'Voter sur Twitch';

  @override
  String get highlightPredictionsOpen => 'Prédictions ouvertes';

  @override
  String get highlightPredictionsClosed => 'Prédictions verrouillées';

  @override
  String get highlightPredictionWaiting => 'En attente du résultat';

  @override
  String get highlightPredictionResult => 'Résultat';

  @override
  String get highlightPredictionCanceled => 'Annulée · points remboursés';

  @override
  String highlightWinnerLower({required String outcome}) {
    return 'gagnant : $outcome';
  }

  @override
  String highlightOutcomeShare({
    required String outcome,
    required int percent,
  }) {
    return '$outcome $percent pour cent';
  }

  @override
  String highlightTimeToPredict({required String time}) {
    return 'Encore $time pour prédire';
  }

  @override
  String highlightWinner({required String outcome}) {
    return 'Gagnant : $outcome';
  }

  @override
  String get highlightPredict => 'Prédire sur Twitch';

  @override
  String get highlightWinnerMark => 'Gagnant';

  @override
  String highlightPoints({required int count}) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString points',
      one: '$countString point',
    );
    return '$_temp0';
  }

  @override
  String highlightPredictors({required int count}) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString participants',
      one: '$countString participant',
    );
    return '$_temp0';
  }

  @override
  String highlightTopPredictor({required String name}) {
    return 'Plus grosse mise : $name';
  }

  @override
  String highlightPinnedFrom({required String sender, required String text}) {
    return 'Message épinglé, envoyé par $sender : $text';
  }

  @override
  String highlightPinnedBy({required String name}) {
    return 'par $name';
  }

  @override
  String get highlightHideForMe => 'Masquer pour moi';

  @override
  String chatPinnedBy({required String name}) {
    return 'Message épinglé par $name.';
  }

  @override
  String get chatPinnedNew => 'Un message a été épinglé.';

  @override
  String raidViewers({required int count}) {
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
  String raidStay({required String source}) {
    return 'Vous restez sur $source';
  }

  @override
  String raidStayDetail({required String target}) {
    return 'Le raid part sans vous vers $target';
  }

  @override
  String raidLeftFor({required String target}) {
    return 'Le raid est parti vers $target';
  }

  @override
  String raidWentAlong({required int count, required String viewers}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$viewers l’ont suivi',
      one: '$viewers l’a suivi',
    );
    return '$_temp0';
  }

  @override
  String get raidCancelled => 'Raid annulé';

  @override
  String raidStaysLive({required String source}) {
    return '$source reste en direct';
  }

  @override
  String raidRaidingWith({
    required String source,
    required String target,
    required String viewers,
  }) {
    return '$source lance un raid sur $target avec $viewers';
  }

  @override
  String raidRaiding({required String source, required String target}) {
    return '$source lance un raid sur $target';
  }

  @override
  String raidHeadingTo({required String target}) {
    return 'En route vers $target';
  }

  @override
  String raidToHasLeft({required String target}) {
    return 'Le raid vers $target est parti';
  }

  @override
  String raidWatchTarget({required String target}) {
    return 'Regarder $target';
  }

  @override
  String get raidBadge => 'RAID';

  @override
  String raidGoAlong({required String viewers}) {
    return '$viewers · départ automatique';
  }

  @override
  String raidLeavesIn({required String time}) {
    return 'Départ dans $time';
  }

  @override
  String get raidGoNow => 'Y aller';

  @override
  String raidGoNowTarget({required String target}) {
    return 'Aller sur $target maintenant';
  }

  @override
  String get raidStayHere => 'Rester ici';

  @override
  String get raidHeadingOut => 'Départ…';

  @override
  String raidIncoming({
    required int count,
    required String name,
    required String viewers,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name lance un raid avec $viewers spectateurs',
      one: '$name lance un raid avec $viewers spectateur',
    );
    return '$_temp0';
  }

  @override
  String get raidSayHi => 'Dites bonjour dans le chat';

  @override
  String raidComingWithYou({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString spectateurs vous accompagnent',
      one: '$countString spectateur vous accompagne',
    );
    return '$_temp0';
  }

  @override
  String giftBombGifting({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'offre $count abonnements',
      one: 'offre $count abonnement',
    );
    return '$_temp0';
  }

  @override
  String giftBombSemantics({required int count, required String name}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name offre $count abonnements',
      one: '$name offre $count abonnement',
    );
    return '$_temp0';
  }

  @override
  String giftBombAllHandedOut({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'les $count abonnements ont été distribués',
      one: 'l’abonnement a été distribué',
    );
    return '$_temp0';
  }

  @override
  String giftBombHandedOutSemantics({
    required int received,
    required int count,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      received,
      locale: localeName,
      other: '$received sur $count distribués',
      one: '$received sur $count distribué',
    );
    return '$_temp0';
  }

  @override
  String giftBombProgress({
    required int receivedCount,
    required String received,
    required int total,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      receivedCount,
      locale: localeName,
      other: '$received sur $total distribués',
      one: '$received sur $total distribué',
    );
    return '$_temp0';
  }

  @override
  String giftBombDone({required int count}) {
    return '$count sur $count · merci !';
  }

  @override
  String get htTitle => 'Hype Train';

  @override
  String htTrainTitle({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa': 'Hype Train Kappa doré',
      'treasure': 'Hype Train trésor',
      'community': 'Hype Train collectif',
      'mythic': 'Hype Train mythique',
      'other': 'Hype Train',
    });
    return '$_temp0';
  }

  @override
  String htSharedTrainTitle({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa': 'Hype Train Kappa doré partagé',
      'community': 'Hype Train collectif partagé',
      'mythic': 'Hype Train mythique partagé',
      'other': 'Hype Train partagé',
    });
    return '$_temp0';
  }

  @override
  String htLevelShort({required int level}) {
    return 'NIV. $level';
  }

  @override
  String get htSubtitle => 'Abonnements, cadeaux ou Bits !';

  @override
  String get htFinalLevel => 'Dernier niveau !';

  @override
  String get htAthApproaching =>
      'Le record de la chaîne est presque battu. Continuez à la soutenir.';

  @override
  String get htAthApproachingCompact =>
      'Le record de la chaîne est presque battu.';

  @override
  String get htAthReached =>
      'Nouveau record en cours ! Continuez jusqu’à la fin du compte à rebours.';

  @override
  String get htAthReachedShared =>
      'Nouveau record partagé en cours ! Continuez jusqu’à la fin du compte à rebours.';

  @override
  String htTreasureLocked({required int level, required int discount}) {
    return 'Niveau $level : −$discount % sur les abonnements offerts !';
  }

  @override
  String htTreasureUnlockedSubtitle({required int discount}) {
    return '−$discount % dès 5 abonnements offerts jusqu’à la fin du train';
  }

  @override
  String htCommunityLocked({required int level}) {
    return 'Atteignez le niveau $level et le chat recevra aussi des emotes !';
  }

  @override
  String htCommunityUnlockedSubtitle({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString emotes pour le chat',
      one: '$countString emote pour le chat',
    );
    return '$_temp0';
  }

  @override
  String htLevelComplete({required int level}) {
    return 'Niveau $level terminé !';
  }

  @override
  String htStarted({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa': 'Le Hype Train Kappa doré démarre !',
      'treasure': 'Un Hype Train trésor arrive !',
      'community': 'Un Hype Train collectif arrive !',
      'mythic': 'Un Hype Train mythique arrive !',
      'other': 'Le Hype Train démarre !',
    });
    return '$_temp0';
  }

  @override
  String htSharedStarted({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa': 'Le Hype Train Kappa doré partagé démarre !',
      'other': 'Le Hype Train partagé démarre !',
    });
    return '$_temp0';
  }

  @override
  String get htLevelUp => 'hyyyyypeeee';

  @override
  String htCompleted({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa': 'Hype Train Kappa doré réussi !',
      'treasure': 'Hype Train trésor réussi !',
      'community': 'Hype Train collectif réussi !',
      'mythic': 'Hype Train mythique réussi !',
      'other': 'Hype Train réussi !',
    });
    return '$_temp0';
  }

  @override
  String htSharedCompleted({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa': 'Hype Train Kappa doré partagé réussi !',
      'other': 'Hype Train partagé réussi !',
    });
    return '$_temp0';
  }

  @override
  String get htTreasureUnlockedMarquee => 'HYPE TRAIN TRÉSOR DÉBLOQUÉ !';

  @override
  String get htCommunityUnlockedMarquee =>
      'RÉCOMPENSES COLLECTIVES DÉBLOQUÉES !';

  @override
  String get htMerging =>
      'Ça va chauffer ! Vos forces s’unissent et les niveaux grimpent !';

  @override
  String get htSummaryRecord =>
      'Record absolu pulvérisé !\nVous avez atteint de nouveaux sommets de soutien !';

  @override
  String htSummary({required String variant, required int level}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'treasure':
          'Quel soutien !\nNiveau $level du Hype Train trésor terminé !',
      'community':
          'Quel soutien !\nNiveau $level du Hype Train collectif terminé !',
      'mythic':
          'Quel soutien !\nNiveau $level du Hype Train mythique terminé !',
      'other': 'Quel soutien !\nNiveau $level terminé !',
    });
    return '$_temp0';
  }

  @override
  String get htAthReachedTitle => 'Record absolu pulvérisé !';

  @override
  String get htSomeone => 'Quelqu’un';

  @override
  String htContributionBits({required int count, required String name}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name vient d’utiliser $countString Bits !',
      one: '$name vient d’utiliser $countString Bit !',
    );
    return '$_temp0';
  }

  @override
  String htContributionGift({
    required int count,
    required String name,
    required int tier,
  }) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name vient d’offrir $countString abonnements de niveau $tier !',
      one: '$name vient d’offrir $countString abonnement de niveau $tier !',
    );
    return '$_temp0';
  }

  @override
  String htContributionSub({required String name, required int tier}) {
    return '$name vient de s’abonner au niveau $tier !';
  }

  @override
  String htContributionOther({required String name}) {
    return '$name vient de faire avancer le train !';
  }

  @override
  String htSubs({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString abonnements',
      one: '$countString abonnement',
    );
    return '$_temp0';
  }

  @override
  String htBits({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Bits',
      one: '$countString Bit',
    );
    return '$_temp0';
  }

  @override
  String htInstructionStart({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa':
          'Vous avez peu de temps pour gagner une emote Kappa dorée exclusive, valable 24 h.',
      'community': 'Waouh, un Hype Train collectif, c’est rare !',
      'mythic': 'Waouh, un Hype Train mythique, c’est rare !',
      'other': 'Vous avez peu de temps pour gagner des emotes exclusives.',
    });
    return '$_temp0';
  }

  @override
  String htInstructionTreasureReachLevel({
    required int level,
    required int discount,
  }) {
    return 'Atteignez le niveau $level pendant ce train pour obtenir $discount % de réduction sur les abonnements offerts !';
  }

  @override
  String get htInstructionTreasureOneAway =>
      'Encore un niveau pour débloquer une réduction jusqu’à la fin de ce train. Continuez !';

  @override
  String htInstructionTreasureUnlocked({required int discount}) {
    return 'Vous avez débloqué $discount % de réduction dès 5 abonnements offerts ! Profitez-en !';
  }

  @override
  String htCommunityUnlocked({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Vous avez débloqué $countString emotes pour le chat ! Passez au niveau suivant pour en offrir davantage.',
      one:
          'Vous avez débloqué $countString emote pour le chat ! Passez au niveau suivant pour en offrir davantage.',
    );
    return '$_temp0';
  }

  @override
  String get htInstructionCommunityRewards =>
      'Les emotes pour le chat arrivent !';

  @override
  String get htInstructionSeeYouNextTime =>
      'Rendez-vous au prochain Hype Train partagé !';

  @override
  String htSharedLevel({required int level, required int percent}) {
    return 'NIV. $level, $percent %';
  }

  @override
  String get htSharedLevelReached => 'Niveau du train partagé atteint';

  @override
  String htContinuesIn({required int level}) {
    return 'Le train de niveau $level reprend dans';
  }

  @override
  String htOtherChannelRecord({required String name}) {
    return 'Nouveau record absolu partagé pour la chaîne $name !';
  }

  @override
  String get htSharedRecordReached => 'Record du train partagé battu !';

  @override
  String get htSharedNew => 'Nouveau Hype Train partagé';

  @override
  String htApproachingTitle({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa': 'Un Hype Train Kappa doré approche !',
      'treasure': 'Un Hype Train trésor est tout proche !',
      'community': 'Un Hype Train collectif est tout proche !',
      'mythic': 'Un Hype Train mythique est tout proche !',
      'other': 'Un Hype Train approche !',
    });
    return '$_temp0';
  }

  @override
  String htApproachingSubtitle({required String train}) {
    return 'Lancez un $train : abonnements, cadeaux ou Bits';
  }

  @override
  String htApproachingMore({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Encore $count personnes doivent s’abonner, offrir des abonnements ou utiliser des Bits',
      one:
          'Encore $count personne doit s’abonner, offrir des abonnements ou utiliser des Bits',
    );
    return '$_temp0';
  }

  @override
  String get htApproachingShort => 'Imminent';

  @override
  String htApproachingQuestion({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa': 'Qu’est-ce qu’un Hype Train Kappa doré ?',
      'other': 'Qu’est-ce qu’un Hype Train ?',
    });
    return '$_temp0';
  }

  @override
  String htApproachingExplanationFirst({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa':
          'Un Hype Train Kappa doré démarre lorsque plusieurs personnes s’abonnent, utilisent des Bits ou offrent des abonnements à la communauté.',
      'other':
          'Un Hype Train démarre lorsque plusieurs personnes s’abonnent, utilisent des Bits ou offrent des abonnements à la communauté.',
    });
    return '$_temp0';
  }

  @override
  String htApproachingExplanationSecond({required String variant}) {
    String _temp0 = intl.Intl.selectLogic(variant, {
      'goldenKappa':
          'Une fois le Hype Train Kappa doré lancé, la communauté remplit la jauge de hype avec d’autres abonnements, abonnements offerts ou Bits. Toutes les personnes dont la contribution donne droit aux récompenses reçoivent l’emote Kappa dorée pendant 24 heures, en plus des emotes habituelles.',
      'other':
          'Une fois le Hype Train lancé, la communauté remplit la jauge de hype avec d’autres abonnements, abonnements offerts ou Bits. Chaque personne qui contribue reçoit une emote unique selon le plus haut niveau terminé.',
    });
    return '$_temp0';
  }

  @override
  String get htRewards => 'Bravo ! Les emotes arrivent chez les soutiens';

  @override
  String get htGoldenRewards =>
      'Bravo ! Les soutiens profitent de l’emote Kappa dorée exclusive pendant 24 h';

  @override
  String get htExpired =>
      'Vous avez raté le train. Ce sera pour la prochaine fois !';

  @override
  String get htGoldenExpired =>
      'Le Hype Train Kappa doré est passé depuis longtemps. Ce sera pour la prochaine fois !';

  @override
  String get htConductorsHeader => 'CONDUCTEURS DE LA HYPE';

  @override
  String get htConductorsDescription =>
      'Les plus grands soutiens de ce Hype Train.';

  @override
  String get htRewardsHeader => 'RÉCOMPENSES DISPONIBLES';

  @override
  String get htRewardsDescription =>
      'Vous pouvez obtenir une emote par train en vous abonnant, en offrant des abonnements ou en utilisant plus de 100 Bits au total pendant l’événement. Les emotes exclusives sont distribuées à la fin du Hype Train et restent disponibles jusqu’à la fin de la saison en cours.';

  @override
  String get htGoldenRewardsDescription =>
      'Contribuez en vous abonnant, en offrant des abonnements ou en utilisant plus de 100 Bits au total pendant l’événement pour obtenir une emote Kappa dorée exclusive pendant 24 heures, en plus des emotes habituelles.';

  @override
  String get htContributionsHeader => 'CONTRIBUTIONS';

  @override
  String htLevelEmotes({required int level}) {
    return 'Emotes du niveau $level';
  }

  @override
  String get htMoreInfo => 'Plus d’infos';

  @override
  String get htLearnMore => 'En savoir plus';

  @override
  String get htUnlockedSoFar => 'Déjà débloquées';

  @override
  String get htComingUp => 'À venir';

  @override
  String get htNothingMore => 'Rien d’autre à afficher pour l’instant';

  @override
  String htLevelTarget({
    required int level,
    required int subs,
    required int bits,
  }) {
    final intl.NumberFormat subsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String subsString = subsNumberFormat.format(subs);
    final intl.NumberFormat bitsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String bitsString = bitsNumberFormat.format(bits);

    String _temp0 = intl.Intl.pluralLogic(
      subs,
      locale: localeName,
      other: '$subsString abonnements de niveau 1',
      one: '$subsString abonnement de niveau 1',
    );
    String _temp1 = intl.Intl.pluralLogic(
      bits,
      locale: localeName,
      other: '$bitsString Bits',
      one: '$bitsString Bit',
    );
    return 'Pour terminer le niveau $level, il faut un soutien total équivalent à $_temp0 ou $_temp1';
  }

  @override
  String htSubsConductor({required int count, required String name}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name a apporté $countString abonnements !',
      one: '$name a apporté $countString abonnement !',
    );
    return '$_temp0';
  }

  @override
  String htBitsConductor({required int count, required String name}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name a utilisé $countString Bits',
      one: '$name a utilisé $countString Bit',
    );
    return '$_temp0';
  }

  @override
  String get htNoSubsConductor =>
      'Abonnez-vous ou offrez un abonnement pour prendre cette place !';

  @override
  String get htNoBitsConductor =>
      'Utilisez des Bits pour prendre cette place !';

  @override
  String htChannelRecord({required int percent, required int level}) {
    return 'Record absolu de la chaîne ! Niveau $level à $percent %';
  }

  @override
  String htTreasureCardUnlocked({required int discount}) {
    return 'Économisez $discount % dès 5 abonnements offerts, uniquement pendant ce train. En voiture !';
  }

  @override
  String htTreasureCardLocked({required int level, required int discount}) {
    return 'Atteignez le niveau $level de ce train pour débloquer une réduction temporaire de $discount % sur les abonnements offerts !';
  }

  @override
  String htMythicCard({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Débloquez 1 emote exclusive parmi $count, valable 24 heures !',
      one: 'Débloquez 1 emote exclusive parmi $count, valable 24 heures !',
    );
    return '$_temp0';
  }

  @override
  String htCardLevelRecord({required int level}) {
    return 'Record absolu · Niveau $level';
  }

  @override
  String htCardLevel({required String train, required int level}) {
    return '$train · Niveau $level';
  }

  @override
  String get htCollapse => 'Réduire le Hype Train';

  @override
  String get htExpand => 'Afficher le Hype Train';

  @override
  String get htDetailsHint => 'afficher les détails';

  @override
  String get htSemanticsApproaching => 'Hype Train imminent';

  @override
  String htSemanticsMinutes({required int minutes}) {
    return '$minutes min';
  }

  @override
  String htSemanticsSeconds({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count secondes',
      one: '$count seconde',
    );
    return '$_temp0';
  }

  @override
  String htSemanticsOngoing({
    required int level,
    required int percent,
    required String time,
  }) {
    return 'Hype Train niveau $level, $percent pour cent, encore $time';
  }

  @override
  String htSemanticsEnded({required int level}) {
    return 'Hype Train terminé au niveau $level';
  }

  @override
  String get htSemanticsExpired => 'Hype Train expiré';

  @override
  String htRewardLocked({required String name}) {
    return 'Récompense verrouillée : $name';
  }

  @override
  String htRewardUnlocked({required String name}) {
    return 'Récompense débloquée : $name';
  }

  @override
  String chatDurationSeconds({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count secondes',
      one: '$count seconde',
    );
    return '$_temp0';
  }

  @override
  String chatDurationMinutes({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '$count minute',
    );
    return '$_temp0';
  }

  @override
  String chatDurationHours({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count heures',
      one: '$count heure',
    );
    return '$_temp0';
  }

  @override
  String chatDurationDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '$count jour',
    );
    return '$_temp0';
  }

  @override
  String chatDurationWeeks({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semaines',
      one: '$count semaine',
    );
    return '$_temp0';
  }

  @override
  String chatDurationMonths({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mois',
      one: '$count mois',
    );
    return '$_temp0';
  }

  @override
  String chatShortSeconds({required int seconds}) {
    return '$seconds s';
  }

  @override
  String chatShortMinutes({required int minutes}) {
    return '$minutes min';
  }

  @override
  String chatShortMinutesSeconds({required int minutes, required int seconds}) {
    return '$minutes min $seconds s';
  }

  @override
  String chatShortHours({required int hours}) {
    return '$hours h';
  }

  @override
  String chatShortHoursMinutes({required int hours, required int minutes}) {
    return '$hours h $minutes min';
  }

  @override
  String get chatConnecting => 'Connexion au chat…';

  @override
  String chatWelcome({required String name}) {
    return 'Bienvenue dans le chat de la chaîne $name !';
  }

  @override
  String chatReconnected({required int attempts, required int seconds}) {
    String _temp0 = intl.Intl.pluralLogic(
      attempts,
      locale: localeName,
      other: 'Chat reconnecté ($attempts tentatives, $seconds s)',
      one: 'Chat reconnecté ($attempts tentative, $seconds s)',
    );
    return '$_temp0';
  }

  @override
  String chatReconnectingIn({
    required int seconds,
    required int attempt,
    required int max,
  }) {
    return 'Reconnexion dans $seconds s… (tentative $attempt sur $max)';
  }

  @override
  String chatReconnecting({required int attempt, required int max}) {
    return 'Reconnexion… (tentative $attempt sur $max)';
  }

  @override
  String get chatDisconnected =>
      'Chat déconnecté. Vérifiez votre connexion Internet.';

  @override
  String get chatReconnect => 'Se reconnecter';

  @override
  String get chatReconnectingNotice => 'Reconnexion au chat…';

  @override
  String get chatExpandedAnnouncement => 'Chat agrandi';

  @override
  String get chatCollapsedAnnouncement => 'Chat réduit';

  @override
  String chatSyncIn({required int seconds}) {
    return 'Synchronisation du chat dans $seconds s…';
  }

  @override
  String chatSevenTvEmoteAdded({required String name, required String emote}) {
    return '$name a ajouté l’emote 7TV « $emote » au chat';
  }

  @override
  String chatSevenTvEmoteRemoved({
    required String name,
    required String emote,
  }) {
    return '$name a retiré l’emote 7TV « $emote » du chat';
  }

  @override
  String chatMessageTooLong({required int max}) {
    return 'Les messages sont limités à $max caractères';
  }

  @override
  String get chatWaitCommand =>
      'Patientez, exécution de la commande précédente…';

  @override
  String get chatWaitMessage => 'Patientez, envoi du message précédent…';

  @override
  String get chatCannotSendDisconnected =>
      'Impossible d’envoyer le message : le chat est déconnecté. Reconnexion…';

  @override
  String get chatMaybeNotSent =>
      'Le message n’a peut-être pas été envoyé. Réessayez.';

  @override
  String get chatClearedByModerator => 'Le chat a été effacé par un modérateur';

  @override
  String chatHelpCommands({required String commands}) {
    return 'Commandes : $commands';
  }

  @override
  String get chatLogInToWhisper => 'Connectez-vous pour chuchoter.';

  @override
  String chatWhisperSent({required String name}) {
    return 'Chuchotement envoyé à $name.';
  }

  @override
  String chatWhisperSentNoReplies({required String name}) {
    return 'Chuchotement envoyé à $name. Les réponses ne pourront pas arriver dans cette application avant votre prochaine connexion.';
  }

  @override
  String chatWhisperNoUser({required String login}) {
    return 'Impossible de chuchoter. Aucun utilisateur nommé $login.';
  }

  @override
  String chatUserCardNoUser({required String login}) {
    return 'Impossible d’ouvrir le profil. Aucun utilisateur nommé $login.';
  }

  @override
  String chatUserCardFailed({required String login}) {
    return 'Impossible d’ouvrir le profil du compte $login.';
  }

  @override
  String chatWhisperFailedBecause({required String reason}) {
    return 'Impossible de chuchoter. $reason';
  }

  @override
  String get chatWhisperFailed => 'Impossible de chuchoter.';

  @override
  String get chatLogInToChangeColor =>
      'Connectez-vous pour changer de couleur.';

  @override
  String get chatColorChanged => 'Couleur du pseudo modifiée.';

  @override
  String get chatColorFailedHex =>
      'Impossible de changer la couleur de votre pseudo (les couleurs hexadécimales nécessitent Turbo ou Prime).';

  @override
  String chatAlreadyBlocked({required String name}) {
    return 'Utilisateur déjà bloqué : $name.';
  }

  @override
  String chatBlockedUser({required String name}) {
    return 'Utilisateur bloqué : $name.';
  }

  @override
  String chatUnblockedUser({required String name}) {
    return 'Utilisateur débloqué : $name.';
  }

  @override
  String chatBlockFailed({required String login}) {
    return 'Impossible de bloquer $login.';
  }

  @override
  String chatUnblockFailed({required String login}) {
    return 'Impossible de débloquer $login.';
  }

  @override
  String get chatLogInToModerate => 'Connectez-vous pour modérer.';

  @override
  String get chatCommandArgUser => 'utilisateur';

  @override
  String get chatCommandArgMessage => 'message';

  @override
  String get chatCommandArgColor => 'couleur';

  @override
  String get chatCommandArgReason => 'motif';

  @override
  String get chatCommandArgLength => 'durée';

  @override
  String get chatCommandArgSeconds => 'secondes';

  @override
  String get chatCommandArgMessageId => 'ID du message';

  @override
  String chatCommandDescription({required String command}) {
    String _temp0 = intl.Intl.selectLogic(command, {
      'me': 'Parler à la troisième personne',
      'color': 'Changer la couleur de votre pseudo',
      'block': 'Bloquer un utilisateur',
      'unblock': 'Débloquer un utilisateur',
      'w': 'Chuchoter à un utilisateur',
      'user': 'Afficher le profil d’un utilisateur',
      'disconnect': 'Se reconnecter au chat',
      'help': 'Afficher la liste des commandes',
      'ban': 'Bannir un utilisateur du chat',
      'unban': 'Lever le bannissement d’un utilisateur',
      'timeout':
          'Exclure temporairement un utilisateur (10m par défaut ; s, m, h, d, w)',
      'untimeout': 'Lever l’exclusion temporaire d’un utilisateur',
      'warn': 'Avertir un utilisateur',
      'delete': 'Supprimer un message',
      'clear': 'Supprimer tous les messages',
      'slow': 'Activer le mode lent (30s par défaut)',
      'slowoff': 'Désactiver le mode lent',
      'followers': 'Activer le mode followers uniquement (m, h, d, w, mo)',
      'followersoff': 'Désactiver le mode followers uniquement',
      'subscribers': 'Activer le mode abonnés uniquement',
      'subscribersoff': 'Désactiver le mode abonnés uniquement',
      'emoteonly': 'Activer le mode emotes uniquement',
      'emoteonlyoff': 'Désactiver le mode emotes uniquement',
      'uniquechat': 'Activer le mode chat unique (pas de messages répétés)',
      'uniquechatoff': 'Désactiver le mode chat unique',
      'announce': 'Envoyer une annonce',
      'announceblue': 'Envoyer une annonce bleue',
      'announcegreen': 'Envoyer une annonce verte',
      'announceorange': 'Envoyer une annonce orange',
      'announcepurple': 'Envoyer une annonce violette',
      'shoutout': 'Faire une dédicace à une chaîne',
      'shield': 'Activer le mode bouclier',
      'shieldoff': 'Désactiver le mode bouclier',
      'monitor': 'Surveiller les messages d’un utilisateur',
      'unmonitor': 'Arrêter de surveiller un utilisateur',
      'restrict':
          'Restreindre un utilisateur (seuls les modérateurs voient ses messages)',
      'unrestrict': 'Lever la restriction d’un utilisateur',
      'mods': 'Afficher la liste des modérateurs',
      'vips': 'Afficher la liste des VIP',
      'mod': 'Attribuer le rôle de modérateur',
      'unmod': 'Retirer le rôle de modérateur',
      'vip': 'Attribuer le statut VIP',
      'unvip': 'Retirer le statut VIP',
      'marker': 'Ajouter un repère au live',
      'commercial':
          'Lancer une publicité (30, 60, 90, 120, 150 ou 180 secondes)',
      'raid': 'Lancer un raid vers une chaîne',
      'unraid': 'Annuler le raid',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String chatCommandUsage({required String usage}) {
    return 'Utilisation : $usage';
  }

  @override
  String chatCommandBadLength({required String length}) {
    return 'Durée non reconnue : « $length ». Utilisez par exemple 30, 10m, 2h, 1d ou 1w.';
  }

  @override
  String get chatCommandTimeoutRange =>
      'Une exclusion temporaire dure de 1 seconde à 2 semaines.';

  @override
  String get chatCommandSlowRange =>
      'Le délai du mode lent va de 3 à 120 secondes.';

  @override
  String get chatCommandFollowAgeRange =>
      'L’ancienneté de suivi va de 0 minute à 3 mois (par exemple 10m, 1w, 3mo).';

  @override
  String get chatCommandUnknownColor =>
      'Couleur inconnue. Essayez blue, coral, hotpink… ou #RRGGBB (Turbo ou Prime).';

  @override
  String chatCommandNotInApp({required String command}) {
    return '/$command n’est pas disponible dans cette application.';
  }

  @override
  String chatCommandUnknown({required String command}) {
    return 'Commande inconnue : /$command. Tapez /help pour voir les commandes disponibles.';
  }

  @override
  String chatModeName({required String mode}) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'slow': 'Mode lent',
      'followers': 'Mode followers uniquement',
      'subscribers': 'Mode abonnés uniquement',
      'emoteOnly': 'Mode emotes uniquement',
      'uniqueChat': 'Mode chat unique',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String chatModeChanged({required String mode, required String state}) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'slow': 'Mode lent',
      'followers': 'Mode followers uniquement',
      'subscribers': 'Mode abonnés uniquement',
      'emoteOnly': 'Mode emotes uniquement',
      'uniqueChat': 'Mode chat unique',
      'other': '',
    });
    String _temp1 = intl.Intl.selectLogic(state, {
      'on': 'activé',
      'other': 'désactivé',
    });
    return '$_temp0 $_temp1.';
  }

  @override
  String chatModeSlowOn({required String duration}) {
    return 'Mode lent activé ($duration).';
  }

  @override
  String chatModeFollowersOn({required String duration}) {
    return 'Mode followers uniquement activé (followers depuis au moins $duration).';
  }

  @override
  String chatModFailed({required String command, required String reason}) {
    String _temp0 = intl.Intl.selectLogic(command, {
      'ban': 'de bannir',
      'timeout': 'd’exclure temporairement',
      'untimeout': 'de lever l’exclusion temporaire',
      'unban': 'de débannir',
      'warn': 'd’avertir',
      'delete': 'de supprimer le message',
      'clear': 'd’effacer le chat',
      'slowOn': 'd’activer le mode lent',
      'slowOff': 'de désactiver le mode lent',
      'followersOn': 'd’activer le mode followers uniquement',
      'followersOff': 'de désactiver le mode followers uniquement',
      'subscribersOn': 'd’activer le mode abonnés uniquement',
      'subscribersOff': 'de désactiver le mode abonnés uniquement',
      'emoteOnlyOn': 'd’activer le mode emotes uniquement',
      'emoteOnlyOff': 'de désactiver le mode emotes uniquement',
      'uniqueChatOn': 'd’activer le mode chat unique',
      'uniqueChatOff': 'de désactiver le mode chat unique',
      'announce': 'd’envoyer l’annonce',
      'shoutout': 'd’envoyer la dédicace',
      'mods': 'd’afficher les modérateurs',
      'vips': 'd’afficher les VIP',
      'mod': 'd’attribuer le rôle de modérateur',
      'unmod': 'de retirer le rôle de modérateur',
      'vip': 'd’attribuer le statut VIP',
      'unvip': 'de retirer le statut VIP',
      'shieldOn': 'd’activer le mode bouclier',
      'shieldOff': 'de désactiver le mode bouclier',
      'marker': 'd’ajouter le repère',
      'commercial': 'de lancer la publicité',
      'raid': 'de lancer le raid',
      'unraid': 'd’annuler le raid',
      'monitor': 'de surveiller l’utilisateur',
      'unmonitor': 'd’arrêter la surveillance',
      'restrict': 'de restreindre l’utilisateur',
      'unrestrict': 'de lever la restriction',
      'blockTerm': 'd’ajouter le terme bloqué',
      'unblockTerm': 'de retirer le terme bloqué',
      'allowMessage': 'd’autoriser le message',
      'denyMessage': 'de refuser le message',
      'approveUnban': 'd’accepter la demande de débannissement',
      'denyUnban': 'de refuser la demande de débannissement',
      'createPoll': 'de lancer le sondage',
      'endPoll': 'de terminer le sondage',
      'createPrediction': 'de lancer la prédiction',
      'lockPrediction': 'de verrouiller la prédiction',
      'resolvePrediction': 'de confirmer le résultat',
      'cancelPrediction': 'd’annuler la prédiction',
      'fulfil': 'de valider la demande',
      'refund': 'de rembourser la demande',
      'updateStream': 'd’enregistrer les infos du live',
      'load': 'de charger la liste',
      'loadStream': 'de charger les infos du live',
      'other': 'd’effectuer cette action',
    });
    return 'Impossible $_temp0. $reason';
  }

  @override
  String chatModFailedUnexpected({required String command}) {
    String _temp0 = intl.Intl.selectLogic(command, {
      'ban': 'de bannir',
      'timeout': 'd’exclure temporairement',
      'untimeout': 'de lever l’exclusion temporaire',
      'unban': 'de débannir',
      'warn': 'd’avertir',
      'delete': 'de supprimer le message',
      'clear': 'd’effacer le chat',
      'slowOn': 'd’activer le mode lent',
      'slowOff': 'de désactiver le mode lent',
      'followersOn': 'd’activer le mode followers uniquement',
      'followersOff': 'de désactiver le mode followers uniquement',
      'subscribersOn': 'd’activer le mode abonnés uniquement',
      'subscribersOff': 'de désactiver le mode abonnés uniquement',
      'emoteOnlyOn': 'd’activer le mode emotes uniquement',
      'emoteOnlyOff': 'de désactiver le mode emotes uniquement',
      'uniqueChatOn': 'd’activer le mode chat unique',
      'uniqueChatOff': 'de désactiver le mode chat unique',
      'announce': 'd’envoyer l’annonce',
      'shoutout': 'd’envoyer la dédicace',
      'mods': 'd’afficher les modérateurs',
      'vips': 'd’afficher les VIP',
      'mod': 'd’attribuer le rôle de modérateur',
      'unmod': 'de retirer le rôle de modérateur',
      'vip': 'd’attribuer le statut VIP',
      'unvip': 'de retirer le statut VIP',
      'shieldOn': 'd’activer le mode bouclier',
      'shieldOff': 'de désactiver le mode bouclier',
      'marker': 'd’ajouter le repère',
      'commercial': 'de lancer la publicité',
      'raid': 'de lancer le raid',
      'unraid': 'd’annuler le raid',
      'monitor': 'de surveiller l’utilisateur',
      'unmonitor': 'd’arrêter la surveillance',
      'restrict': 'de restreindre l’utilisateur',
      'unrestrict': 'de lever la restriction',
      'blockTerm': 'd’ajouter le terme bloqué',
      'unblockTerm': 'de retirer le terme bloqué',
      'allowMessage': 'd’autoriser le message',
      'denyMessage': 'de refuser le message',
      'approveUnban': 'd’accepter la demande de débannissement',
      'denyUnban': 'de refuser la demande de débannissement',
      'createPoll': 'de lancer le sondage',
      'endPoll': 'de terminer le sondage',
      'createPrediction': 'de lancer la prédiction',
      'lockPrediction': 'de verrouiller la prédiction',
      'resolvePrediction': 'de confirmer le résultat',
      'cancelPrediction': 'd’annuler la prédiction',
      'fulfil': 'de valider la demande',
      'refund': 'de rembourser la demande',
      'updateStream': 'd’enregistrer les infos du live',
      'load': 'de charger la liste',
      'loadStream': 'de charger les infos du live',
      'other': 'd’effectuer cette action',
    });
    return 'Impossible $_temp0 (erreur inattendue).';
  }

  @override
  String get chatModCannotModerate =>
      'Twitch indique que vous ne pouvez pas modérer ce chat.';

  @override
  String chatTwitchReason({required String reason}) {
    return 'Raison de Twitch : « $reason »';
  }

  @override
  String chatModNoUser({required String login}) {
    return 'Aucun utilisateur nommé $login.';
  }

  @override
  String get chatModLogInAgain =>
      'Reconnectez-vous pour modérer depuis cette application.';

  @override
  String get chatModNotThrough => 'L’action n’a pas abouti. Réessayez.';

  @override
  String chatAutoModHeld({required String name}) {
    return 'Message de $name retenu par l’AutoMod.';
  }

  @override
  String get chatAutoModReview => 'Examiner';

  @override
  String get chatCommandArgChannel => 'chaîne';

  @override
  String get chatCommandArgDescription => 'texte';

  @override
  String chatModAction({
    required String action,
    required String moderator,
    required String user,
    required String duration,
  }) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'ban': '$moderator a banni $user.',
      'timeout': '$moderator a exclu temporairement $user ($duration).',
      'timeoutUnknown': '$moderator a exclu temporairement $user.',
      'unban': '$moderator a débanni $user.',
      'untimeout': '$moderator a levé l’exclusion temporaire visant $user.',
      'warn': '$moderator a averti $user.',
      'delete': '$moderator a supprimé un message envoyé par $user.',
      'clear': '$moderator a effacé le chat.',
      'mod': '$moderator a attribué le rôle de modérateur à $user.',
      'unmod': '$moderator a retiré le rôle de modérateur à $user.',
      'vip': '$moderator a attribué le statut VIP à $user.',
      'unvip': '$moderator a retiré le statut VIP à $user.',
      'raid': '$moderator a lancé un raid vers la chaîne $user.',
      'unraid': '$moderator a annulé le raid vers la chaîne $user.',
      'addBlockedTerm': '$moderator a ajouté un terme bloqué.',
      'removeBlockedTerm': '$moderator a retiré un terme bloqué.',
      'addPermittedTerm': '$moderator a ajouté un terme autorisé.',
      'removePermittedTerm': '$moderator a retiré un terme autorisé.',
      'approveUnbanRequest':
          '$moderator a accepté la demande de débannissement envoyée par $user.',
      'denyUnbanRequest':
          '$moderator a refusé la demande de débannissement envoyée par $user.',
      'emoteonly': '$moderator a activé le mode emotes uniquement.',
      'emoteonlyoff': '$moderator a désactivé le mode emotes uniquement.',
      'followers': '$moderator a activé le mode followers uniquement.',
      'followersoff': '$moderator a désactivé le mode followers uniquement.',
      'slow': '$moderator a activé le mode lent.',
      'slowoff': '$moderator a désactivé le mode lent.',
      'subscribers': '$moderator a activé le mode abonnés uniquement.',
      'subscribersoff': '$moderator a désactivé le mode abonnés uniquement.',
      'uniquechat': '$moderator a activé le mode chat unique.',
      'uniquechatoff': '$moderator a désactivé le mode chat unique.',
      'other': '$moderator a effectué une action de modération.',
    });
    return '$_temp0';
  }

  @override
  String chatModActionWithReason({
    required String line,
    required String reason,
  }) {
    return '$line Motif : « $reason ».';
  }

  @override
  String get chatModAnnounced => 'Annonce envoyée.';

  @override
  String chatModBroadcasterOnly({required String command}) {
    return '$command ne fonctionne que sur votre propre chaîne.';
  }

  @override
  String chatModCommercialStarted({required String duration}) {
    return 'Publicité lancée ($duration).';
  }

  @override
  String get chatModMarkerAdded => 'Repère ajouté au live.';

  @override
  String chatModModeratorList({required int count, required String names}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Modérateurs ($count) : $names',
      one: 'Modérateur ($count) : $names',
    );
    return '$_temp0';
  }

  @override
  String get chatModRaidCanceled => 'Raid annulé.';

  @override
  String chatModRaidStarted({required String name}) {
    return 'Préparation du raid vers la chaîne $name.';
  }

  @override
  String chatModRoleChanged({required String change, required String name}) {
    String _temp0 = intl.Intl.selectLogic(change, {
      'moderatorAdded': 'Rôle de modérateur attribué : $name.',
      'moderatorRemoved': 'Rôle de modérateur retiré : $name.',
      'vipAdded': 'Statut VIP attribué : $name.',
      'vipRemoved': 'Statut VIP retiré : $name.',
      'other': 'Rôle modifié : $name.',
    });
    return '$_temp0';
  }

  @override
  String chatModRoleListEmpty({required String role}) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'moderator': 'Cette chaîne n’a aucun modérateur.',
      'vip': 'Cette chaîne n’a aucun VIP.',
      'other': 'Personne n’a ce rôle.',
    });
    return '$_temp0';
  }

  @override
  String chatModShield({required String state}) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'on': 'Mode bouclier activé.',
      'other': 'Mode bouclier désactivé.',
    });
    return '$_temp0';
  }

  @override
  String chatModShoutoutSent({required String name}) {
    return 'Dédicace envoyée à la chaîne $name.';
  }

  @override
  String chatModSuspicion({required String change, required String name}) {
    String _temp0 = intl.Intl.selectLogic(change, {
      'monitor': 'Surveillance activée : $name.',
      'unmonitor': 'Surveillance levée : $name.',
      'restrict': 'Restriction activée : $name.',
      'unrestrict': 'Restriction levée : $name.',
      'other': 'Statut modifié : $name.',
    });
    return '$_temp0';
  }

  @override
  String get chatModViewList => 'Voir la liste';

  @override
  String chatModVipList({required int count, required String names}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'VIP ($count) : $names',
      one: 'VIP ($count) : $names',
    );
    return '$_temp0';
  }

  @override
  String chatShieldModeChangedBy({
    required String state,
    required String moderator,
  }) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'on': '$moderator a activé le mode bouclier.',
      'other': '$moderator a désactivé le mode bouclier.',
    });
    return '$_temp0';
  }

  @override
  String chatShoutoutNotice({required String name}) {
    return 'Dédicace à la chaîne $name ! Allez la découvrir.';
  }

  @override
  String get chatShoutoutView => 'Voir';

  @override
  String get modToolsActionLog => 'Actions de modération';

  @override
  String get modToolsActionLogCaption =>
      'Actions effectuées dans ce chat depuis son ouverture.';

  @override
  String get modToolsActionLogDetail => 'Qui a fait quoi, en direct';

  @override
  String get modToolsActionLogEmpty =>
      'Aucune action de modération pour l’instant';

  @override
  String get modToolsAdd => 'Ajouter';

  @override
  String get modToolsAddChoice => 'Ajouter un choix';

  @override
  String get modToolsAddOutcome => 'Ajouter un résultat';

  @override
  String get modToolsAllow => 'Autoriser';

  @override
  String get modToolsAnnounce => 'Envoyer une annonce';

  @override
  String get modToolsAnnounceCaption =>
      'L’annonce est mise en avant dans le chat, pour tout le monde.';

  @override
  String get modToolsAnnounceColor => 'Couleur';

  @override
  String modToolsAnnounceColorName({required String color}) {
    String _temp0 = intl.Intl.selectLogic(color, {
      'primary': 'Couleur de la chaîne',
      'blue': 'Bleu',
      'green': 'Vert',
      'orange': 'Orange',
      'purple': 'Violet',
      'other': 'Couleur de la chaîne',
    });
    return '$_temp0';
  }

  @override
  String get modToolsAnnounceLabel => 'Texte de l’annonce';

  @override
  String get modToolsAnnounceSend => 'Envoyer';

  @override
  String get modToolsApprove => 'Accepter';

  @override
  String get modToolsAutoModCaption =>
      'Messages retenus par l’AutoMod, en attente de décision.';

  @override
  String get modToolsAutoModEmpty => 'Aucun message en attente';

  @override
  String get modToolsAutoModEmptyDetail => 'Rien à examiner';

  @override
  String modToolsAutoModPending({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages en attente',
      one: '$count message en attente',
    );
    return '$_temp0';
  }

  @override
  String get modToolsAutoModQueue => 'File de l’AutoMod';

  @override
  String get modToolsBlockedTermAdded => 'Terme bloqué ajouté.';

  @override
  String get modToolsBlockedTermRemoved => 'Terme bloqué retiré.';

  @override
  String get modToolsBlockedTermTooShort =>
      'Un terme bloqué doit comporter au moins 2 caractères.';

  @override
  String get modToolsBlockedTerms => 'Termes bloqués';

  @override
  String get modToolsBlockedTermsCaption =>
      'Les messages contenant ces termes n’apparaissent jamais dans le chat.';

  @override
  String get modToolsBlockedTermsEmpty => 'Aucun terme bloqué';

  @override
  String get modToolsCaptionBroadcaster =>
      'Vous êtes propriétaire de cette chaîne';

  @override
  String get modToolsCaptionModerator => 'Vous modérez cette chaîne';

  @override
  String get modToolsCategoryLabel => 'Catégorie';

  @override
  String get modToolsCategoryNone => 'Aucune catégorie';

  @override
  String get modToolsChannelLabel => 'Nom de la chaîne';

  @override
  String modToolsChoiceLabel({required int number}) {
    return 'Choix $number';
  }

  @override
  String get modToolsClearResolved => 'Effacer les messages traités';

  @override
  String get modToolsCommercial => 'Lancer une publicité';

  @override
  String get modToolsCommercialMessage =>
      'Tous les spectateurs verront la publicité. Choisissez sa durée.';

  @override
  String get modToolsCommercialStart => 'Lancer';

  @override
  String get modToolsCommercialTitle => 'Lancer une publicité ?';

  @override
  String get modToolsConfirm => 'Confirmer';

  @override
  String get modToolsDeny => 'Refuser';

  @override
  String get modToolsEntryDetail => 'AutoMod, termes, mode bouclier et plus';

  @override
  String get modToolsFulfil => 'Valider';

  @override
  String get modToolsFulfilled => 'Demande validée.';

  @override
  String modToolsHeldLevel({required String reason, required int level}) {
    return '$reason · niveau $level';
  }

  @override
  String modToolsHeldReason({required String reason}) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'automod': 'AutoMod',
      'blockedTerm': 'Terme bloqué',
      'blockedLink': 'Lien bloqué',
      'other': 'AutoMod',
    });
    return '$_temp0';
  }

  @override
  String modToolsHeldStatus({required String status}) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'pending': 'En attente',
      'approved': 'Autorisé',
      'denied': 'Refusé',
      'expired': 'Expiré',
      'other': 'En attente',
    });
    return '$_temp0';
  }

  @override
  String get modToolsLogInToEnable => 'Reconnectez-vous pour y accéder';

  @override
  String get modToolsMakeModerator => 'Attribuer le rôle de modérateur';

  @override
  String get modToolsMakeVip => 'Attribuer le statut VIP';

  @override
  String get modToolsMarker => 'Ajouter un repère';

  @override
  String get modToolsMarkerAdd => 'Ajouter';

  @override
  String get modToolsMarkerLabel => 'Description (facultative)';

  @override
  String get modToolsMarkerTitle => 'Ajouter un repère';

  @override
  String modToolsModeratorCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modérateurs',
      one: '$count modérateur',
    );
    return '$_temp0';
  }

  @override
  String get modToolsModerators => 'Modérateurs';

  @override
  String get modToolsMonitor => 'Surveiller ses messages';

  @override
  String get modToolsMoreActions => 'Autres actions de modération';

  @override
  String modToolsOutcomeLabel({required int number}) {
    return 'Résultat $number';
  }

  @override
  String get modToolsPermittedTerms => 'Termes autorisés';

  @override
  String get modToolsPollDuration => 'Durée';

  @override
  String get modToolsPollEnd => 'Terminer le sondage';

  @override
  String get modToolsPollEndMessage =>
      'Le vote s’arrête maintenant et les résultats s’affichent.';

  @override
  String get modToolsPollEndTitle => 'Terminer le sondage ?';

  @override
  String get modToolsPollEnded => 'Sondage terminé.';

  @override
  String get modToolsPollLive => 'Sondage en cours';

  @override
  String get modToolsPollStart => 'Lancer le sondage';

  @override
  String get modToolsPollStarted => 'Sondage lancé.';

  @override
  String get modToolsPolls => 'Sondages';

  @override
  String get modToolsPollsCaption => 'Posez une question au chat.';

  @override
  String get modToolsPredictionCancel => 'Annuler la prédiction';

  @override
  String get modToolsPredictionCancelMessage =>
      'Tous les participants récupèrent leurs points de chaîne.';

  @override
  String get modToolsPredictionCancelTitle => 'Annuler la prédiction ?';

  @override
  String get modToolsPredictionLive => 'Prédiction en cours';

  @override
  String get modToolsPredictionLock => 'Verrouiller';

  @override
  String get modToolsPredictionLockMessage =>
      'Plus personne ne pourra participer. Ce verrouillage est définitif.';

  @override
  String get modToolsPredictionLockTitle => 'Verrouiller la prédiction ?';

  @override
  String get modToolsPredictionLocked => 'Prédiction verrouillée';

  @override
  String get modToolsPredictionPickWinner => 'Choisir ce résultat';

  @override
  String modToolsPredictionPoints({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString points',
      one: '$countString point',
    );
    return '$_temp0';
  }

  @override
  String get modToolsPredictionResolve => 'Confirmer le résultat';

  @override
  String modToolsPredictionResolveMessage({required String outcome}) {
    return '« $outcome » l’emporte. Les points de chaîne reviennent aux participants qui l’ont choisi.';
  }

  @override
  String get modToolsPredictionResolveTitle => 'Confirmer le résultat ?';

  @override
  String get modToolsPredictionStart => 'Lancer la prédiction';

  @override
  String get modToolsPredictionStarted => 'Prédiction lancée.';

  @override
  String modToolsPredictionUpdated({required String state}) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'locked': 'Prédiction verrouillée.',
      'resolved': 'Résultat confirmé.',
      'canceled': 'Prédiction annulée.',
      'other': 'Prédiction mise à jour.',
    });
    return '$_temp0';
  }

  @override
  String modToolsPredictionUsers({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '$count participant',
    );
    return '$_temp0';
  }

  @override
  String get modToolsPredictionWindow => 'Durée pour participer';

  @override
  String get modToolsPredictions => 'Prédictions';

  @override
  String get modToolsPredictionsCaption =>
      'Laissez le chat miser des points de chaîne.';

  @override
  String get modToolsQuestionLabel => 'Intitulé';

  @override
  String get modToolsRaid => 'Lancer un raid';

  @override
  String get modToolsRaidCancel => 'Annuler le raid';

  @override
  String get modToolsRaidCancelMessage => 'Vos spectateurs restent ici.';

  @override
  String get modToolsRaidCancelTitle => 'Annuler le raid ?';

  @override
  String get modToolsRaidMessage =>
      'Vos spectateurs rejoindront cette chaîne à la fin du compte à rebours.';

  @override
  String get modToolsRaidStart => 'Lancer le raid';

  @override
  String get modToolsRaidTitle => 'Lancer un raid';

  @override
  String modToolsRedemptionReward({required String reward, required int cost}) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String costString = costNumberFormat.format(cost);

    String _temp0 = intl.Intl.pluralLogic(
      cost,
      locale: localeName,
      other: '$costString points',
      one: '$costString point',
    );
    return '$reward · $_temp0';
  }

  @override
  String get modToolsRefund => 'Rembourser';

  @override
  String modToolsRefundMessage({required String name, required String reward}) {
    return 'Les points dépensés pour « $reward » seront rendus à $name.';
  }

  @override
  String get modToolsRefundTitle => 'Rembourser cette demande ?';

  @override
  String get modToolsRefunded => 'Demande remboursée.';

  @override
  String get modToolsRemove => 'Retirer';

  @override
  String get modToolsRemoveModerator => 'Retirer le rôle de modérateur';

  @override
  String modToolsRemoveTag({required String tag}) {
    return 'Retirer $tag';
  }

  @override
  String modToolsRemoveTermMessage({required String term}) {
    return 'Les messages contenant « $term » pourront de nouveau apparaître dans le chat.';
  }

  @override
  String get modToolsRemoveTermTitle => 'Retirer ce terme bloqué ?';

  @override
  String get modToolsRemoveVip => 'Retirer le statut VIP';

  @override
  String modToolsRequestedOn({required String date}) {
    return 'Envoyée le $date';
  }

  @override
  String get modToolsRestrict => 'Restreindre';

  @override
  String modToolsRestrictMessage({required String name}) {
    return 'Seuls les modérateurs verront les messages envoyés par $name.';
  }

  @override
  String get modToolsRestrictTitle => 'Restreindre cet utilisateur ?';

  @override
  String get modToolsRewardQueueWeb => 'File complète des récompenses';

  @override
  String get modToolsRewardRequests => 'Demandes de récompenses';

  @override
  String get modToolsRewardRequestsCaption =>
      'Twitch ne permet à cette application de gérer que les récompenses créées dans ONSET. La file complète est sur twitch.tv.';

  @override
  String get modToolsRewardRequestsEmpty => 'Aucune demande en attente';

  @override
  String modToolsRoleConfirmMessage({
    required String change,
    required String name,
  }) {
    String _temp0 = intl.Intl.selectLogic(change, {
      'addModerator': '$name pourra modérer ce chat.',
      'removeModerator': '$name ne pourra plus modérer ce chat.',
      'addVip': '$name recevra le badge VIP.',
      'removeVip': '$name perdra le badge VIP.',
      'other': 'Le rôle changera pour $name.',
    });
    return '$_temp0';
  }

  @override
  String modToolsRoleConfirmTitle({required String change}) {
    String _temp0 = intl.Intl.selectLogic(change, {
      'addModerator': 'Attribuer le rôle de modérateur ?',
      'removeModerator': 'Retirer le rôle de modérateur ?',
      'addVip': 'Attribuer le statut VIP ?',
      'removeVip': 'Retirer le statut VIP ?',
      'other': 'Modifier le rôle ?',
    });
    return '$_temp0';
  }

  @override
  String get modToolsSave => 'Enregistrer';

  @override
  String modToolsSeconds({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count s',
      one: '$count s',
    );
    return '$_temp0';
  }

  @override
  String get modToolsSectionChannel => 'Votre chaîne';

  @override
  String get modToolsSectionChat => 'Outils du chat';

  @override
  String get modToolsSectionLive => 'En direct';

  @override
  String get modToolsShieldMode => 'Mode bouclier';

  @override
  String get modToolsShieldModeDetail =>
      'Vos protections prédéfinies, en un geste';

  @override
  String get modToolsShieldModeOn => 'Mode bouclier activé';

  @override
  String get modToolsShoutout => 'Faire une dédicace';

  @override
  String get modToolsShoutoutDetail =>
      'Faire découvrir une autre chaîne au chat';

  @override
  String get modToolsShoutoutSend => 'Envoyer';

  @override
  String get modToolsShoutoutTitle => 'Faire une dédicace';

  @override
  String get modToolsShoutoutUser => 'Faire une dédicace';

  @override
  String get modToolsShowActionsInChat =>
      'Afficher les actions de modération dans le chat';

  @override
  String get modToolsStreamInfo => 'Modifier les infos du live';

  @override
  String get modToolsStreamInfoCaption => 'Titre, catégorie et tags';

  @override
  String get modToolsStreamInfoSaved => 'Infos du live enregistrées.';

  @override
  String get modToolsStreamTitleLabel => 'Titre';

  @override
  String get modToolsTagInvalid =>
      'Un tag ne peut contenir que des lettres et des chiffres (25 caractères au maximum).';

  @override
  String get modToolsTagLabel => 'Ajouter un tag';

  @override
  String modToolsTagLimit({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Un live peut avoir jusqu’à $count tags.',
      one: 'Un live peut avoir jusqu’à $count tag.',
    );
    return '$_temp0';
  }

  @override
  String get modToolsTags => 'Tags';

  @override
  String get modToolsTermLabel => 'Terme ou expression';

  @override
  String get modToolsTermTemporary => 'Temporaire';

  @override
  String get modToolsTitle => 'Outils de modération';

  @override
  String get modToolsUnbanCaption =>
      'Utilisateurs bannis qui demandent à revenir.';

  @override
  String modToolsUnbanDialogMessage({
    required String decision,
    required String name,
  }) {
    String _temp0 = intl.Intl.selectLogic(decision, {
      'approved':
          'Le bannissement sera levé pour $name. Vous pouvez ajouter une note à son intention.',
      'denied':
          'Le bannissement est maintenu pour $name. Vous pouvez ajouter une note à son intention.',
      'other': 'Vous pouvez ajouter une note pour $name.',
    });
    return '$_temp0';
  }

  @override
  String modToolsUnbanDialogTitle({required String decision}) {
    String _temp0 = intl.Intl.selectLogic(decision, {
      'approved': 'Accepter la demande ?',
      'denied': 'Refuser la demande ?',
      'other': 'Répondre à la demande ?',
    });
    return '$_temp0';
  }

  @override
  String get modToolsUnbanEmpty => 'Aucune demande de débannissement';

  @override
  String get modToolsUnbanNoteLabel => 'Note (facultative)';

  @override
  String get modToolsUnbanRequests => 'Demandes de débannissement';

  @override
  String modToolsUnbanResolved({
    required String decision,
    required String name,
  }) {
    String _temp0 = intl.Intl.selectLogic(decision, {
      'approved': 'Demande acceptée : $name.',
      'denied': 'Demande refusée : $name.',
      'other': 'Demande traitée : $name.',
    });
    return '$_temp0';
  }

  @override
  String get modToolsUnmonitor => 'Arrêter la surveillance';

  @override
  String get modToolsUnrestrict => 'Lever la restriction';

  @override
  String get modToolsUserActionsTitle => 'Actions de modération';

  @override
  String get modToolsUserLabel => 'Nom d’utilisateur';

  @override
  String modToolsUserPill({required String pill}) {
    String _temp0 = intl.Intl.selectLogic(pill, {
      'banned': 'Bannissement',
      'timedOut': 'Exclusion temporaire',
      'warned': 'Avertissement',
      'monitored': 'Sous surveillance',
      'restricted': 'Restriction',
      'other': 'Signalement',
    });
    return '$_temp0';
  }

  @override
  String modToolsVipCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count VIP',
      one: '$count VIP',
    );
    return '$_temp0';
  }

  @override
  String get modToolsVips => 'VIP';

  @override
  String modToolsVotes({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString votes',
      one: '$countString vote',
    );
    return '$_temp0';
  }

  @override
  String chatModBanned({required String name}) {
    return 'Vous avez banni $name.';
  }

  @override
  String chatModTimedOut({required String name, required String duration}) {
    return 'Vous avez exclu $name pendant $duration.';
  }

  @override
  String chatModUntimedOut({required String name}) {
    return 'Exclusion temporaire levée : $name.';
  }

  @override
  String chatModUnbanned({required String name}) {
    return 'Vous avez débanni $name.';
  }

  @override
  String chatModWarned({required String name}) {
    return 'Vous avez averti $name.';
  }

  @override
  String get chatModMessageDeleted => 'Message supprimé.';

  @override
  String get chatModCleared => 'Vous avez effacé le chat.';

  @override
  String chatNoticeBanned({required String name}) {
    return 'Bannissement définitif : $name.';
  }

  @override
  String chatNoticeTimedOut({required String name}) {
    return 'Exclusion temporaire : $name.';
  }

  @override
  String chatNoticeTimedOutFor({
    required String name,
    required String duration,
  }) {
    return 'Exclusion temporaire ($duration) : $name.';
  }

  @override
  String chatServerNotice({required String notice}) {
    String _temp0 = intl.Intl.selectLogic(notice, {
      'rateLimit':
          'Impossible d’envoyer votre message. Vous envoyez des messages trop vite.',
      'duplicate':
          'Impossible d’envoyer votre message. Il est identique à un message envoyé il y a moins de 30 secondes.',
      'subsOnly':
          'Impossible d’envoyer votre message. Le chat est en mode abonnés uniquement : abonnez-vous à la chaîne pour écrire.',
      'emoteOnly':
          'Impossible d’envoyer votre message. Le chat est en mode emotes uniquement.',
      'uniqueChat':
          'Impossible d’envoyer votre message. Le chat est en mode chat unique et votre message n’est pas original.',
      'followRequired':
          'Impossible d’envoyer votre message. Le chat est en mode followers uniquement : suivez la chaîne pour écrire.',
      'followedTooRecently':
          'Impossible d’envoyer votre message. Vous ne suivez pas cette chaîne depuis assez longtemps pour écrire.',
      'verifiedEmail':
          'Impossible d’envoyer votre message. Cette chaîne exige une adresse e-mail vérifiée : vérifiez la vôtre dans les paramètres de sécurité de Twitch.',
      'verifiedPhone':
          'Impossible d’envoyer votre message. Cette chaîne exige un numéro de téléphone vérifié : vérifiez le vôtre dans les paramètres de sécurité de Twitch.',
      'emailAliasBanned':
          'Impossible d’envoyer votre message. Votre adresse e-mail est bannie de cette chaîne.',
      'phoneAliasBanned':
          'Impossible d’envoyer votre message. Votre numéro de téléphone est banni de cette chaîne.',
      'channelSuspended': 'Cette chaîne n’existe pas ou est suspendue.',
      'accountSuspended':
          'Impossible d’envoyer votre message. Votre compte est suspendu.',
      'channelBlocked':
          'Impossible d’envoyer votre message. Votre compte n’est pas en règle sur cette chaîne.',
      'userRestricted':
          'Impossible d’envoyer votre message. Votre compte ne peut pas envoyer de messages pour le moment. En savoir plus sur appeals.twitch.tv.',
      'channelRestricted':
          'Impossible d’envoyer votre message. Cette chaîne ne peut pas recevoir de messages pour le moment.',
      'invalidReply':
          'Impossible d’envoyer votre réponse. Il n’est pas possible de répondre à ce message.',
      'unexpected': 'Impossible d’envoyer votre message. Réessayez.',
      'badCharacters':
          'Impossible d’envoyer votre message. Il contient trop de caractères que Twitch ne peut pas traiter.',
      'rejectedBySettings':
          'Impossible d’envoyer votre message. Il est contraire aux paramètres de modération de la chaîne.',
      'tooManyChats':
          'Trop de chats sont ouverts en même temps. Quittez-en un pour rejoindre celui-ci.',
      'warned':
          'Impossible d’envoyer votre message. Vous avez reçu un avertissement d’un modérateur : confirmez-en la lecture sur twitch.tv pour écrire de nouveau.',
      'banned':
          'Bannissement définitif : vous ne pouvez plus écrire dans ce chat.',
      'followersOnNow': 'Le chat est maintenant en mode followers uniquement.',
      'noPermission': 'Vous n’avez pas l’autorisation de faire cela.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String chatServerNoticeTimedOut({required String wait}) {
    return 'Exclusion temporaire : vous pourrez écrire de nouveau dans $wait.';
  }

  @override
  String chatServerNoticeSlowMode({required String wait}) {
    return 'Impossible d’envoyer votre message. Le chat est en mode lent : vous pourrez écrire de nouveau dans $wait.';
  }

  @override
  String chatServerNoticeUnknownCommand({required String command}) {
    return 'Commande inconnue : $command.';
  }

  @override
  String chatNoticeOwnMessageDeleted({required String message}) {
    return 'Votre message a été supprimé : « $message ».';
  }

  @override
  String get chatRestrictionBanned => 'Bannissement définitif';

  @override
  String get chatRestrictionTimedOut => 'Exclusion temporaire';

  @override
  String chatRestrictionTimedOutFor({required String wait}) {
    return 'Exclusion temporaire · $wait';
  }

  @override
  String chatRestrictionSlow({required String wait}) {
    return 'Mode lent · encore $wait';
  }

  @override
  String get chatRestrictionEmoteOnly => 'Mode emotes uniquement';

  @override
  String get chatRestrictionSubscribersOnly => 'Mode abonnés uniquement';

  @override
  String get chatRestrictionFollowersOnly => 'Followers uniquement';

  @override
  String chatRestrictionFollowersFor({required String duration}) {
    return 'Followers depuis $duration';
  }

  @override
  String chatRestrictionAccount({required String reason}) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'verifiedEmail': 'E-mail vérifié requis',
      'verifiedPhone': 'Téléphone vérifié requis',
      'emailAliasBanned': 'E-mail banni ici',
      'phoneAliasBanned': 'Téléphone banni ici',
      'accountRestricted': 'Compte restreint',
      'channelRestricted': 'Chat suspendu ici',
      'followRequired': 'Suivez la chaîne',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String chatNewMessages({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux messages',
      one: '$count nouveau message',
    );
    return '$_temp0';
  }

  @override
  String get chatResumeScroll => 'Revenir en bas';

  @override
  String get chatHistoricalMessage => 'Message de l’historique';

  @override
  String chatSentFromCurrent({required String name}) {
    return 'Envoyé depuis la chaîne $name (celle-ci)';
  }

  @override
  String chatSentFrom({required String name}) {
    return 'Envoyé depuis la chaîne $name';
  }

  @override
  String get chatMessageDeletedInline => '<message supprimé>';

  @override
  String get chatDeletedUser => 'Utilisateur supprimé';

  @override
  String get chatFilteredWord => 'Mot filtré';

  @override
  String chatCheerSemantics({required String prefix, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$prefix $count Bits',
      one: '$prefix $count Bit',
    );
    return '$_temp0';
  }

  @override
  String chatEmoteStackWith({required String emotes}) {
    return 'avec $emotes';
  }

  @override
  String chatEmoteBy({required String name}) {
    return 'par $name';
  }

  @override
  String chatBadgeExplainer({required String kind}) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'broadcaster': 'Diffuse sur cette chaîne.',
      'moderator': 'Modère le chat de cette chaîne.',
      'leadModerator': 'Dirige l’équipe de modération de cette chaîne.',
      'vip': 'A reçu le statut de VIP sur cette chaîne.',
      'subscriber':
          'Abonnement à cette chaîne en cours ; le badge évolue avec l’ancienneté de l’abonnement.',
      'founder': 'Fait partie des premiers abonnés de cette chaîne.',
      'bits': 'A envoyé des Bits sur cette chaîne ; le badge indique le total.',
      'bitsLeader':
          'Fait partie des personnes qui envoient le plus de Bits sur cette chaîne.',
      'subGifter':
          'A offert des abonnements sur cette chaîne ; le badge indique combien.',
      'subGiftLeader':
          'Fait partie des personnes qui offrent le plus d’abonnements sur cette chaîne.',
      'partner': 'Partenaire Twitch.',
      'staff': 'Travaille chez Twitch.',
      'premium': 'A un abonnement Prime Gaming.',
      'turbo': 'A un abonnement Twitch Turbo.',
      'artist': 'Crée des illustrations pour cette chaîne.',
      'noAudio': 'Regarde sans le son.',
      'noVideo': 'Écoute sans la vidéo.',
      'predictions':
          'Participe à la prédiction en cours ; le badge indique la réponse choisie.',
      'hypeTrain': 'A participé à un Hype Train sur cette chaîne.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String chatBadgeExplainerElsewhere({
    required String kind,
    required String channel,
  }) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'broadcaster': 'Diffuse sur la chaîne $channel.',
      'moderator': 'Modère le chat de la chaîne $channel.',
      'leadModerator': 'Dirige l’équipe de modération de la chaîne $channel.',
      'vip': 'A reçu le statut de VIP sur la chaîne $channel.',
      'subscriber':
          'Abonnement à la chaîne $channel en cours ; le badge évolue avec l’ancienneté de l’abonnement.',
      'founder': 'Fait partie des premiers abonnés de la chaîne $channel.',
      'bits':
          'A envoyé des Bits sur la chaîne $channel ; le badge indique le total.',
      'bitsLeader':
          'Fait partie des personnes qui envoient le plus de Bits sur la chaîne $channel.',
      'subGifter':
          'A offert des abonnements sur la chaîne $channel ; le badge indique combien.',
      'subGiftLeader':
          'Fait partie des personnes qui offrent le plus d’abonnements sur la chaîne $channel.',
      'artist': 'Crée des illustrations pour la chaîne $channel.',
      'predictions':
          'Participe à la prédiction en cours de la chaîne $channel ; le badge indique la réponse choisie.',
      'hypeTrain': 'A participé à un Hype Train sur la chaîne $channel.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get chatCopyName => 'Copier le nom';

  @override
  String get chatCopyImageUrl => 'Copier l’URL de l’image';

  @override
  String get chatOpenInBrowser => 'Ouvrir dans le navigateur';

  @override
  String get chatMessageCopied => 'Message copié';

  @override
  String get chatCopyMessage => 'Copier le message';

  @override
  String get chatCopyMessageAndPaste => 'Copier et coller le message';

  @override
  String get chatReplyToMessage => 'Répondre au message';

  @override
  String get chatDeleteMessage => 'Supprimer le message';

  @override
  String get chatFirstMessage => 'Premier message';

  @override
  String get chatHighlightedMessage => 'Message mis en avant';

  @override
  String chatCheeredIn({required String channel}) {
    return 'Bits envoyés sur la chaîne $channel';
  }

  @override
  String get chatSubsOnlyRedemption =>
      'Envoyé avec des points de chaîne en mode abonnés uniquement';

  @override
  String get chatAnimatedMessage => 'Message animé';

  @override
  String get chatMessageDeleted => 'Message supprimé';

  @override
  String get chatPermanentlyBanned => 'Bannissement définitif';

  @override
  String chatTimedOutForLength({required String duration}) {
    return 'Exclusion temporaire ($duration)';
  }

  @override
  String get chatAnnouncement => 'Annonce';

  @override
  String get chatMessageOptionsHint => 'afficher les options du message';

  @override
  String get chatCopyMessageHint => 'copier le message';

  @override
  String get chatReplies => 'Réponses';

  @override
  String get chatEmoteMenu => 'Menu des emotes';

  @override
  String get chatLogInToChat => 'Connectez-vous pour discuter';

  @override
  String get chatCancelReply => 'Annuler la réponse';

  @override
  String get chatEnterMessage => 'Envoyer un message';

  @override
  String get chatCannotChatNow => 'Envoi impossible';

  @override
  String get chatInputDisconnected => 'Chat déconnecté';

  @override
  String get chatInputConnecting => 'Connexion au chat…';

  @override
  String get chatSending => 'Envoi…';

  @override
  String get chatSend => 'Envoyer';

  @override
  String chatReplyIn({required String name}) {
    return 'Réponse · $name';
  }

  @override
  String get chatReply => 'Répondre';

  @override
  String chatInChannelDelayed({required String name, required int seconds}) {
    return '$name · délai $seconds s';
  }

  @override
  String chatDelayed({required int seconds}) {
    return 'Chat · délai $seconds s';
  }

  @override
  String chatInChannel({required String name}) {
    return 'Chat · $name';
  }

  @override
  String get chatInputPlaceholder => 'Envoyer un message';

  @override
  String get chatMoreOptions => 'Plus d’options';

  @override
  String chatCharactersLeft({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count caractères restants',
      one: '$count caractère restant',
    );
    return '$_temp0';
  }

  @override
  String get chatColorUpdated => 'Couleur du pseudo modifiée !';

  @override
  String get chatColorUpdateFailed =>
      'Impossible de modifier la couleur du pseudo. Réessayez.';

  @override
  String get chatDetailsChatOnly => 'Chat seul';

  @override
  String get chatDetailsShowVideo => 'Afficher la vidéo';

  @override
  String get chatDetailsRefreshAssets => 'Actualiser les emotes et les badges';

  @override
  String get chatDetailsUsernameColor => 'Couleur du pseudo';

  @override
  String get chatDetailsPointsPollsPredictions =>
      'Points de chaîne, sondages et prédictions';

  @override
  String get chatDetailsOpensTwitchChat => 'Ouvre le chat sur twitch.tv';

  @override
  String get chatDetailsTwitchChat => 'Chat Twitch';

  @override
  String get chatDetailsOpensTwitch => 'Ouvre twitch.tv';

  @override
  String get chatDetailsPreferences => 'Préférences';

  @override
  String get chatDetailsHideOffensive => 'Masquer les propos choquants';

  @override
  String get chatDetailsGiftSub => 'Offrir un abonnement';

  @override
  String get chatDetailsModes => 'Modes du chat';

  @override
  String get chatDetailsModesDetail => 'Lent, followers, effacer le chat…';

  @override
  String get chatDetailsChatters => 'Utilisateurs dans le chat';

  @override
  String get chatDetailsAddChat => 'Ajouter un chat';

  @override
  String get chatDetailsSleepTimer => 'Minuteur de mise en veille';

  @override
  String get chatSave => 'Enregistrer';

  @override
  String get chatColorPreview => 'Voici à quoi ressemblera votre pseudo';

  @override
  String chatColorName({required String color}) {
    String _temp0 = intl.Intl.selectLogic(color, {
      'blue': 'Bleu',
      'blue_violet': 'Bleu-violet',
      'cadet_blue': 'Bleu cadet',
      'chocolate': 'Chocolat',
      'coral': 'Corail',
      'dodger_blue': 'Bleu Dodger',
      'firebrick': 'Rouge brique',
      'golden_rod': 'Verge d’or',
      'green': 'Vert',
      'hot_pink': 'Rose vif',
      'orange_red': 'Rouge orangé',
      'red': 'Rouge',
      'sea_green': 'Vert océan',
      'spring_green': 'Vert printemps',
      'yellow_green': 'Jaune-vert',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get chatModesAnyFollower => 'Tous les followers';

  @override
  String get chatModesClearTitle => 'Effacer le chat ?';

  @override
  String get chatModesClearMessage =>
      'Tous les messages sont supprimés pour tout le monde.';

  @override
  String get chatClear => 'Effacer';

  @override
  String get chatModesModerator => 'Modérateur';

  @override
  String chatBadgeModeratorBot({required String moderator}) {
    return '$moderator (bot)';
  }

  @override
  String chatModesSlowWait({required int seconds}) {
    return '$seconds s entre les messages';
  }

  @override
  String get chatModesClearChat => 'Effacer le chat';

  @override
  String chatModePill({required String mode}) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'emoteOnly': 'Emotes uniquement',
      'followers': 'Followers uniquement',
      'slow': 'Mode lent',
      'subscribers': 'Abonnés uniquement',
      'uniqueChat': 'Chat unique',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String chatModeExplainer({required String mode}) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'emoteOnly': 'Les messages ne peuvent contenir que des emotes.',
      'followersNow': 'Seuls les followers peuvent écrire dans le chat.',
      'followers':
          'Seuls les followers peuvent écrire dans le chat, après avoir suivi la chaîne pendant la durée indiquée.',
      'slow': 'Chacun doit attendre la durée indiquée entre deux messages.',
      'subscribers': 'Seuls les abonnés peuvent écrire dans le chat.',
      'uniqueChat':
          'Chaque message doit être unique : les messages répétés sont refusés.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get chatChattersFilter => 'Filtrer les utilisateurs';

  @override
  String chatChattersFound({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString utilisateurs trouvés',
      one: '$countString utilisateur trouvé',
    );
    return '$_temp0';
  }

  @override
  String get chatChattersNone => 'Aucun utilisateur trouvé';

  @override
  String get chatChattersNoMatch => 'Aucun utilisateur correspondant';

  @override
  String get emoteMenuRecent => 'Récentes';

  @override
  String get emoteMenuClearRecent => 'Effacer les emotes récentes';

  @override
  String get chatAnimatedEmotesCallout =>
      'Vous pouvez désactiver les emotes animées dans Paramètres › Chat.';

  @override
  String get chatAnimatedEmotesCalloutShow => 'Me montrer';

  @override
  String get emoteMenuRecentCleared => 'Emotes récentes effacées';

  @override
  String get emoteMenuNoRecent => 'Aucune emote récente';

  @override
  String emoteMenuLocked({required String name}) {
    return '$name, verrouillée';
  }

  @override
  String emoteMenuAnimated({required String name}) {
    return '$name, emote animée';
  }

  @override
  String get emoteMenuRemoveRecent => 'Retirer des emotes récentes';

  @override
  String emoteMenuFollowerInfo({required String channel}) {
    return 'Les emotes de follower ne peuvent être utilisées que dans le chat de la chaîne $channel.';
  }

  @override
  String get emoteLimitedTime => 'Emote à durée limitée';

  @override
  String get emoteMenuChannel => 'Chaîne';

  @override
  String get emoteMenuGlobal => 'Globales';

  @override
  String get emoteMenuUnlocked => 'Débloquées';

  @override
  String get emoteMenuOther => 'Autres';

  @override
  String chatHeldDecision({required String decision}) {
    String _temp0 = intl.Intl.selectLogic(decision, {
      'approved': 'Les modérateurs ont approuvé votre message retenu',
      'denied': 'Les modérateurs ont refusé votre message retenu',
      'other': 'Votre message retenu ne peut plus être examiné',
    });
    return '$_temp0';
  }

  @override
  String chatHeldQuoted({required String decision, required String quote}) {
    return '$decision : « $quote »';
  }

  @override
  String get chatAddChatSearchFailed => 'Impossible de rechercher les chaînes';

  @override
  String get chatAddChatTitle => 'Ajouter un chat';

  @override
  String get chatAddChatSearch => 'Rechercher une chaîne';

  @override
  String get chatAddChatPrompt => 'Recherchez la chaîne à ajouter';

  @override
  String get chatAddChatNoChannels => 'Aucune chaîne trouvée';

  @override
  String get chatTabsSplit => 'Séparer les chats';

  @override
  String get chatTabsMerge => 'Fusionner les chats chargés';

  @override
  String get chatTabsDisconnect => 'Déconnecter';

  @override
  String get chatTabsRemove => 'Retirer';

  @override
  String get chatTabsOptions => 'Options de l’onglet';

  @override
  String get chatTabsMaximum => '10 chats ouverts au maximum';

  @override
  String get chatTabsAlreadyOpen =>
      'Cette chaîne est déjà ouverte : son chat est affiché';

  @override
  String get chatUserWhisper => 'Chuchoter';

  @override
  String get chatUserProfile => 'Profil';

  @override
  String get chatUserNoRecentMessages => 'Aucun message récent';

  @override
  String get chatUserRecentMessages => 'Messages récents';

  @override
  String chatUserBadgeMonths({required String name, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name · $count mois',
      one: '$name · $count mois',
    );
    return '$_temp0';
  }

  @override
  String chatUserAccountCreated({required String date}) {
    return 'Compte créé le $date';
  }

  @override
  String chatUserFollowingSince({required String date}) {
    return 'Suit la chaîne depuis le $date';
  }

  @override
  String get chatFilteredTitle => 'Message masqué';

  @override
  String get chatFilteredBody =>
      'Ce message a été masqué par vos filtres du chat. L’afficher quand même ?';

  @override
  String get chatFilteredShow => 'Afficher le message';

  @override
  String get chatRulesTitle => 'Règles du chat';

  @override
  String get chatRulesHeading => 'Règles du chat';

  @override
  String get chatRulesAccept => 'J’ai compris';

  @override
  String chatRaidWelcomeSemantics({
    required String from,
    required String target,
  }) {
    return 'Vous avez rejoint le raid de la chaîne $from. Bienvenue dans le chat de la chaîne $target';
  }

  @override
  String chatRaidWelcomeFrom({required String name}) {
    return 'Vous avez rejoint le raid de la chaîne $name';
  }

  @override
  String chatRaidWelcomeTo({required String name}) {
    return 'Bienvenue dans le chat de la chaîne $name';
  }

  @override
  String chatGiftRecipientsReceived({
    required int received,
    required int count,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$received sur $count destinataires',
      one: '$received sur $count destinataire',
    );
    return '$_temp0';
  }

  @override
  String chatGiftRecipients({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count destinataires',
      one: '$count destinataire',
    );
    return '$_temp0';
  }

  @override
  String chatGiftRecipientsMore({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count autres',
      one: '+$count autre',
    );
    return '$_temp0';
  }

  @override
  String get chatAnonymousGifter => 'Anonyme';

  @override
  String get chatLinkUntitledClip => 'Clip sans titre';

  @override
  String get chatLinkUntitled => 'Sans titre';

  @override
  String get chatLinkClip => 'Clip';

  @override
  String get chatLinkVideo => 'Vidéo';

  @override
  String chatLinkViews({required int count, required String views}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$views vues',
      one: '$views vue',
    );
    return '$_temp0';
  }

  @override
  String chatModBarBanTitle({required String name}) {
    return 'Bannir $name ?';
  }

  @override
  String get chatModBarBan => 'Bannir';

  @override
  String chatModBarWarnTitle({required String name}) {
    return 'Avertir $name';
  }

  @override
  String get chatModBarWarn => 'Avertir';

  @override
  String get chatModBarPurge => '1 seconde (purge)';

  @override
  String get chatModBarTimeout => 'Exclure temporairement';

  @override
  String get chatModBarTimeoutShort => 'Exclure';

  @override
  String get chatModBarUnban => 'Débannir';

  @override
  String get chatModBarReason => 'Motif';

  @override
  String get chatModBarReasonOptional => 'Motif (facultatif)';

  @override
  String get pointsChannelPoints => 'Points de chaîne';

  @override
  String get pointsLogInForBalance => 'Connectez-vous pour voir votre solde.';

  @override
  String get pointsPredictionOpen => 'Prédiction ouverte';

  @override
  String get pointsPredictionLocked => 'Prédiction verrouillée';

  @override
  String get pointsRewards => 'Récompenses';

  @override
  String get pointsNoRewards => 'Cette chaîne n’a configuré aucune récompense.';

  @override
  String get pointsStreakNote =>
      'C’est Twitch qui gère les séries : regarder dans cette application peut ne pas compter.';

  @override
  String get pointsBonusBlocked =>
      'Twitch empêche de récupérer le bonus depuis l’application (sa vérification anti-bot). Récupérez-le sur twitch.tv : le solde suivra.';

  @override
  String get pointsCollectBonus => 'Récupérer le bonus';

  @override
  String pointsOutcomeTotals({required String points, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$points · $count participants',
      one: '$points · $count participant',
    );
    return '$_temp0';
  }

  @override
  String pointsBetOn({required String title, required String odds}) {
    return 'Miser sur $title, rapporte $odds fois la mise';
  }

  @override
  String pointsBetOnUnknown({required String title}) {
    return 'Miser sur $title, gain inconnu';
  }

  @override
  String get pointsTapToBet => 'Appuyez sur une issue pour miser.';

  @override
  String get pointsBetHeading => 'MISER SUR';

  @override
  String pointsBalance({required String points}) {
    return 'Solde : $points';
  }

  @override
  String pointsNeedAtLeast({required int points}) {
    return 'Il faut au moins $points points pour miser.';
  }

  @override
  String get pointsStake => 'Mise';

  @override
  String get pointsMax => 'Max';

  @override
  String get pointsField => 'Points';

  @override
  String get pointsNoOdds => 'Pas encore de cote.';

  @override
  String pointsPaysAbout({required String odds}) {
    return 'Rapporte environ $odds × si cette issue gagne (évolue avec chaque mise).';
  }

  @override
  String pointsBetAmount({required String points, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Miser $points points',
      one: 'Miser $points point',
    );
    return '$_temp0';
  }

  @override
  String get pointsBet => 'Miser';

  @override
  String pointsOdds({required String odds}) {
    return '$odds ×';
  }

  @override
  String pointsSpend({required String points}) {
    return 'Dépenser $points points ?';
  }

  @override
  String get pointsYourMessage => 'Votre message';

  @override
  String get pointsRedeem => 'Échanger';

  @override
  String pointsResult({required String status, required String reason}) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'success': 'C’est fait.',
      'integrityRefused':
          'Twitch a refusé : vérification anti-bot. Cette application ne peut pas la passer.',
      'notAuthenticated':
          'Twitch a refusé la connexion. Reconnectez-vous pour dépenser des points.',
      'network': 'Impossible de joindre Twitch. Réessayez.',
      'other': 'Twitch a refusé : $reason',
    });
    return '$_temp0';
  }

  @override
  String get pointsBusy => 'Déjà en cours.';

  @override
  String get pointsNoReason => 'aucune raison donnée';

  @override
  String pointsAutomaticReward({required String type}) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'highlight': 'Mettre mon message en avant',
      'randomEmote': 'Débloquer une emote d’abonné au hasard',
      'chosenEmote': 'Choisir une emote à débloquer',
      'modifiedEmote': 'Modifier une seule emote',
      'subOnlyMessage': 'Envoyer un message en mode abonnés uniquement',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get streakSaveTitle =>
      'Continuez à regarder pour sauver votre série de visionnage !';

  @override
  String streakSaveLive({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Regardez ce live pour sauver votre série actuelle de $count lives.',
      one: 'Regardez ce live pour sauver votre série actuelle de $count live.',
    );
    return '$_temp0';
  }

  @override
  String get streakExpiringTitle => 'Votre série de visionnage expire bientôt';

  @override
  String streakExpiring({required String name, required String time}) {
    return 'Regardez la chaîne $name dans les $time pour sauver votre série !';
  }

  @override
  String streakYour({required int value}) {
    return 'Votre série de visionnage : $value';
  }

  @override
  String streakOneMore({required int count, required String points}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encore 1 live pour gagner $points points de chaîne en bonus',
      one: 'Encore 1 live pour gagner $points point de chaîne en bonus',
    );
    return '$_temp0';
  }

  @override
  String streakReached({
    required int count,
    required int next,
    required String points,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Vous avez atteint une série de $next lives et gagné $points points de chaîne en bonus',
      one:
          'Vous avez atteint une série de $next lives et gagné $points point de chaîne en bonus',
    );
    return '$_temp0';
  }

  @override
  String streakReach({
    required int count,
    required int next,
    required String points,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Atteignez une série de $next lives pour gagner $points points de chaîne en bonus',
      one:
          'Atteignez une série de $next lives pour gagner $points point de chaîne en bonus',
    );
    return '$_temp0';
  }

  @override
  String emoteUnlockHint({required String how}) {
    String _temp0 = intl.Intl.selectLogic(how, {
      'global': 'Disponible pour tout le monde sur Twitch.',
      'owned': 'Vous pouvez l’utiliser.',
      'follow': 'Suivez cette chaîne pour l’utiliser.',
      'bits': 'Envoyez des Bits sur cette chaîne pour la débloquer.',
      'subscribe': 'Abonnez-vous à cette chaîne pour l’utiliser.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String emoteUnlockTier({required int tier}) {
    return 'Abonnez-vous à cette chaîne au niveau $tier pour l’utiliser.';
  }

  @override
  String emoteTypeName({required String type}) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'twitchBits': 'Emote de Bits Twitch',
      'twitchFollower': 'Emote de follower Twitch',
      'twitchSub': 'Emote d’abonné Twitch',
      'twitchGlobal': 'Emote globale Twitch',
      'twitchUnlocked': 'Emote Twitch débloquée',
      'twitchChannel': 'Emote de chaîne Twitch',
      'ffzGlobal': 'Emote globale FrankerFaceZ',
      'ffzChannel': 'Emote de chaîne FrankerFaceZ',
      'bttvGlobal': 'Emote globale BetterTTV',
      'bttvChannel': 'Emote de chaîne BetterTTV',
      'bttvShared': 'Emote partagée BetterTTV',
      'sevenTVGlobal': 'Emote globale 7TV',
      'sevenTVChannel': 'Emote de chaîne 7TV',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String badgeTypeName({required String type}) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'twitch': 'Badge Twitch',
      'bttv': 'Badge BetterTTV',
      'ffz': 'Badge FrankerFaceZ',
      'sevenTV': 'Badge 7TV',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String noticeSubscribed({
    required String plan,
    required String name,
    required int tier,
  }) {
    String _temp0 = intl.Intl.selectLogic(plan, {
      'prime': 'Abonnement : $name (Prime Gaming).',
      'tier': 'Abonnement : $name (niveau $tier).',
      'other': 'Abonnement : $name.',
    });
    return '$_temp0';
  }

  @override
  String noticeResubscribed({
    required String plan,
    required String name,
    required int tier,
  }) {
    String _temp0 = intl.Intl.selectLogic(plan, {
      'prime': 'Réabonnement : $name (Prime Gaming).',
      'tier': 'Réabonnement : $name (niveau $tier).',
      'other': 'Réabonnement : $name.',
    });
    return '$_temp0';
  }

  @override
  String noticeSubStreak({required int months, required int streak}) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months mois d’abonnement, série de $streak mois en cours !',
      one: '$months mois d’abonnement, série de $streak mois en cours !',
    );
    return '$_temp0';
  }

  @override
  String noticeSubMonths({required int months}) {
    return '$months mois d’abonnement !';
  }

  @override
  String noticeGiftedSub({
    required String tiered,
    required String gifter,
    required int tier,
    required String recipient,
  }) {
    String _temp0 = intl.Intl.selectLogic(tiered, {
      'yes': '$gifter a offert un abonnement de niveau $tier à $recipient !',
      'other': '$gifter a offert un abonnement à $recipient !',
    });
    return '$_temp0';
  }

  @override
  String noticeGiftedMonthsTier({
    required String gifter,
    required String months,
    required String tier,
    required String recipient,
  }) {
    return '$gifter a offert $months d’abonnement de $tier à $recipient !';
  }

  @override
  String noticeGiftedMonths({
    required String gifter,
    required String months,
    required String recipient,
  }) {
    return '$gifter a offert un abonnement de $months à $recipient !';
  }

  @override
  String noticeGiftMonths({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mois',
      one: '$count mois',
    );
    return '$_temp0';
  }

  @override
  String noticeGiftMonthsShort({required int count}) {
    return '$count mois';
  }

  @override
  String noticeGiftTier({required int tier}) {
    return 'niveau $tier';
  }

  @override
  String get noticeGiftFirst =>
      'C’est son premier abonnement offert sur la chaîne !';

  @override
  String noticeGiftCount({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Son total sur la chaîne : $countString abonnements offerts !';
  }

  @override
  String noticeCommunityGift({
    required String tiered,
    required int count,
    required String gifter,
    required int tier,
    required String channel,
    required String end,
  }) {
    String _temp0 = intl.Intl.selectLogic(end, {'more': '.', 'other': ' !'});
    String _temp1 = intl.Intl.selectLogic(end, {'more': '.', 'other': ' !'});
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$gifter offre $count abonnements de niveau $tier à la communauté de la chaîne $channel$_temp0',
      one:
          '$gifter offre $count abonnement de niveau $tier à la communauté de la chaîne $channel$_temp1',
    );
    String _temp3 = intl.Intl.selectLogic(end, {'more': '.', 'other': ' !'});
    String _temp4 = intl.Intl.selectLogic(end, {'more': '.', 'other': ' !'});
    String _temp5 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$gifter offre $count abonnements à la communauté de la chaîne $channel$_temp3',
      one:
          '$gifter offre $count abonnement à la communauté de la chaîne $channel$_temp4',
    );
    String _temp6 = intl.Intl.selectLogic(tiered, {
      'yes': '$_temp2',
      'other': '$_temp5',
    });
    return '$_temp6';
  }

  @override
  String get noticeCommunityGiftFirst =>
      'C’est son premier abonnement offert sur la chaîne !';

  @override
  String noticeCommunityGiftTotal({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Son total sur la chaîne : $countString abonnements offerts !';
  }

  @override
  String noticeExtendedSub({
    required String tiered,
    required String name,
    required int tier,
    required String month,
  }) {
    String _temp0 = intl.Intl.selectLogic(tiered, {
      'yes':
          '$name a prolongé son abonnement de niveau $tier jusqu’en $month !',
      'other': '$name a prolongé son abonnement jusqu’en $month !',
    });
    return '$_temp0';
  }

  @override
  String noticeRaid({required String name, required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name lance un raid avec $countString spectateurs !',
      one: '$name lance un raid avec $countString spectateur !',
    );
    return '$_temp0';
  }

  @override
  String noticeSubMultiMonth({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mois payés d’avance.',
      one: '$count mois payé d’avance.',
    );
    return '$_temp0';
  }

  @override
  String noticeGiftRedeemed({
    required int month,
    required int total,
    required String gifter,
  }) {
    return 'Mois $month sur $total d’un abonnement offert par $gifter.';
  }

  @override
  String noticeGiftRedeemedAnonymous({required int month, required int total}) {
    return 'Mois $month sur $total d’un abonnement offert anonymement.';
  }

  @override
  String noticeGiftPaidUpgrade({required String name, required String gifter}) {
    return '$name prolonge l’abonnement offert par $gifter !';
  }

  @override
  String noticeGiftPaidUpgradeAnonymous({required String name}) {
    return '$name prolonge un abonnement offert anonymement !';
  }

  @override
  String noticePayForward({
    required String name,
    required String gifter,
    required String recipient,
  }) {
    return '$name offre à son tour un abonnement à $recipient, après celui offert par $gifter !';
  }

  @override
  String noticePayForwardCommunity({
    required String name,
    required String gifter,
  }) {
    return '$name offre à son tour un abonnement à la communauté, après celui offert par $gifter !';
  }

  @override
  String noticeSponsorBonus({required String sponsor, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$sponsor ajoute $count abonnements offerts en bonus !',
      one: '$sponsor ajoute $count abonnement offert en bonus !',
    );
    return '$_temp0';
  }

  @override
  String noticeRewardGift({required String name, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Grâce à $name, $count autres spectateurs reçoivent une récompense !',
      one: 'Grâce à $name, $count autre spectateur reçoit une récompense !',
    );
    return '$_temp0';
  }

  @override
  String noticeWatchStreak({required String name, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Série de visionnage de $count lives pour $name !',
      one: 'Série de visionnage de $count live pour $name !',
    );
    return '$_temp0';
  }

  @override
  String noticeWatchStreakPoints({required int points}) {
    final intl.NumberFormat pointsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pointsString = pointsNumberFormat.format(points);

    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$pointsString points de chaîne gagnés.',
      one: '$pointsString point de chaîne gagné.',
    );
    return '$_temp0';
  }

  @override
  String noticeCharity({
    required String name,
    required String amount,
    required String charity,
  }) {
    return '$name a fait un don de $amount à $charity !';
  }

  @override
  String get vodCopyLinkAtTime => 'Copier le lien à ce moment';

  @override
  String get vodGoToTime => 'Aller à un moment';

  @override
  String vodGoToTimeInvalid({required String end}) {
    return 'Saisissez un moment entre 0:00 et $end.';
  }

  @override
  String get vodGoToTimeGo => 'Y aller';

  @override
  String get vodKindArchive => 'Ancienne diffusion';

  @override
  String get vodKindHighlight => 'Temps fort';

  @override
  String get vodKindUpload => 'Mise en ligne';

  @override
  String vodPlaybackRate({required String rate}) {
    return '$rate ×';
  }

  @override
  String get vodLinkCopied => 'Lien copié';

  @override
  String get vodShare => 'Partager';

  @override
  String get vodOpenChannel => 'Ouvrir la chaîne';

  @override
  String vodSpeedPill({required String rate}) {
    return 'Vitesse $rate';
  }

  @override
  String get vodSpeedPillNormal => 'Vitesse normale';

  @override
  String vodQualityPill({required String quality}) {
    return 'Qualité $quality';
  }

  @override
  String get vodQualityPillAuto => 'Qualité auto';

  @override
  String get vodQualityPillAudioOnly => 'Qualité audio uniquement';

  @override
  String vodCaptionsState({required String state}) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'on': 'Sous-titres, activés',
      'other': 'Sous-titres, désactivés',
    });
    return '$_temp0';
  }

  @override
  String get vodLegendMuted => 'Passages sans son (droits d’auteur)';

  @override
  String get vodLegendDoubleTap =>
      'Appuyez deux fois sur un côté pour reculer ou avancer de 10 s';

  @override
  String get vodLegendUpNext => 'Lecture automatique de la vidéo suivante';

  @override
  String vodLegendUpNextWhen({required String autoplay}) {
    return 'Lecture automatique de la vidéo suivante · $autoplay';
  }

  @override
  String get vodSeek => 'Position de lecture';

  @override
  String vodSeekValue({required String position, required String duration}) {
    return '$position sur $duration';
  }

  @override
  String get vodUpNext => 'À suivre';

  @override
  String vodUpNextSeconds({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans $count s',
      one: 'dans $count s',
    );
    return '$_temp0';
  }

  @override
  String vodUpNextSimilar({required String channel}) {
    return '$channel · Suggestion';
  }

  @override
  String get vodPlayNow => 'Lire maintenant';

  @override
  String get vodReplayTitle => 'Rediffusion du chat';

  @override
  String get vodReplaySynced => 'synchronisé';

  @override
  String get vodReplayEmotesNote =>
      'Les emotes 7TV, BTTV et FFZ sont celles que la chaîne utilise aujourd’hui : elles peuvent différer de celles de la diffusion.';

  @override
  String get vodReplayEmotesAbout =>
      'À propos des emotes dans les rediffusions';

  @override
  String get vodReplayNotForUploads =>
      'Les mises en ligne n’ont pas de rediffusion du chat';

  @override
  String get vodReplayUnavailable =>
      'La rediffusion du chat n’est pas disponible pour cette vidéo';

  @override
  String get vodReplayNoMessages => 'Aucun message à ce moment de la vidéo';

  @override
  String get vodReplayLoading => 'Chargement de la rediffusion du chat…';

  @override
  String get whisperOtherAccount =>
      'Cette conversation appartient à un autre compte.';

  @override
  String whisperTooLong({required int max}) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'Les chuchotements sont limités à $maxString caractères.';
  }

  @override
  String get whisperLogInAgain =>
      'Reconnectez-vous pour chuchoter depuis cette application.';

  @override
  String get whisperFailedUnexpected =>
      'Impossible de chuchoter (erreur inattendue).';

  @override
  String notifGoLiveTitle({required String name}) {
    return '$name est en direct';
  }

  @override
  String notifStreamBody({required String title, required String category}) {
    return '$category · $title';
  }

  @override
  String notifGoLiveMore({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autres chaînes sont en direct',
      one: '$count autre chaîne est en direct',
    );
    return '$_temp0';
  }

  @override
  String get notifGoLivePaused => 'Notifications de live en pause';

  @override
  String notifMentionTitle({required String sender, required String channel}) {
    return '$sender vous mentionne dans le chat de la chaîne $channel';
  }

  @override
  String notifReminderTitle({required String name}) {
    return 'Le live de la chaîne $name commence';
  }

  @override
  String get notifReminderUntitled => 'Live sans titre';

  @override
  String get notifChannelGoLive => 'Lives des chaînes suivies';

  @override
  String get notifChannelGoLiveDescription =>
      'Quand une chaîne que vous suivez lance un live';

  @override
  String get notifChannelMentions => 'Mentions dans le chat';

  @override
  String get notifChannelMentionsDescription =>
      'Quand quelqu’un vous mentionne dans un chat ouvert en arrière-plan';

  @override
  String get notifChannelReminders => 'Rappels de lives';

  @override
  String get notifChannelRemindersDescription =>
      'Quand commence un live prévu pour lequel vous avez activé un rappel';

  @override
  String get mediaChannel => 'Lecture en cours';

  @override
  String get mediaPlay => 'Lire';

  @override
  String get mediaPause => 'Mettre en pause';

  @override
  String get mediaStop => 'Arrêter';

  @override
  String get authMissingPermissionsTitle => 'Autorisations manquantes';

  @override
  String get authMissingPermissions =>
      'Votre session ne dispose pas de toutes les autorisations nécessaires. Reconnectez-vous pour continuer.';

  @override
  String get authSessionExpiredTitle => 'Session expirée';

  @override
  String get authSessionExpired =>
      'Votre session a expiré. Reconnectez-vous pour continuer.';

  @override
  String get authLogIn => 'Se connecter';

  @override
  String get whispersNew => 'Nouveau chuchotement';

  @override
  String get whispersNewSearch => 'Rechercher une personne';

  @override
  String whispersNewNoMatch({required String query}) {
    return 'Personne ne correspond à « $query ».';
  }

  @override
  String get whispersNewFailed =>
      'Impossible de lancer la recherche. Vérifiez votre connexion, puis réessayez.';

  @override
  String get whisperMore => 'Options de la conversation';

  @override
  String get whisperMute => 'Couper les notifications';

  @override
  String get whisperUnmute => 'Réactiver les notifications';

  @override
  String get whisperMuted => 'Notifications coupées';

  @override
  String get whisperArchive => 'Archiver';

  @override
  String get whisperUnarchive => 'Désarchiver';

  @override
  String whispersArchived({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Conversations archivées ($count)',
      one: 'Conversation archivée ($count)',
    );
    return '$_temp0';
  }

  @override
  String get whisperHide => 'Masquer la conversation';

  @override
  String get whisperHideConfirmTitle => 'Masquer cette conversation ?';

  @override
  String whisperHideConfirmMessage({required String name}) {
    return 'Vos chuchotements avec $name seront retirés de cette application. Un nouveau chuchotement ouvrira une nouvelle conversation.';
  }

  @override
  String get whisperHideConfirm => 'Masquer';

  @override
  String get blockReasonTitle => 'Motif (facultatif)';

  @override
  String get blockReasonHarassment => 'Harcèlement';

  @override
  String get blockReasonSpam => 'Spam';

  @override
  String get blockReasonOther => 'Autre';

  @override
  String goLiveBellLevelTitle({required String name}) {
    return 'Notifications de live pour $name';
  }

  @override
  String get goLiveBellAll => 'Tous les lives';

  @override
  String get goLiveBellNone => 'Aucune';

  @override
  String get settingsPageNotInterested => 'Chaînes masquées';

  @override
  String notInterestedCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chaînes masquées',
      one: '$count chaîne masquée',
    );
    return '$_temp0';
  }

  @override
  String get notInterestedEmpty => 'Aucune chaîne masquée';

  @override
  String get notInterestedNote =>
      'Les chaînes marquées « Ça ne m’intéresse pas » dans l’onglet En direct n’y apparaissent plus tant que vous ne les réaffichez pas ici.';

  @override
  String get notInterestedRestore => 'Réafficher';

  @override
  String notInterestedRestoreName({required String name}) {
    return 'Réafficher $name';
  }

  @override
  String get searchSuggestions => 'Suggestions';

  @override
  String get profileTrailer => 'Bande-annonce';

  @override
  String profileTrailerOpen({required String title}) {
    return 'Lire la bande-annonce : $title';
  }

  @override
  String get profileTeams => 'Équipes';

  @override
  String teamMembersCount({required int count}) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString membres',
      one: '$countString membre',
    );
    return '$_temp0';
  }

  @override
  String get teamLiveNow => 'En direct';

  @override
  String get teamMembers => 'Membres';

  @override
  String get teamFailed => 'Impossible de charger cette équipe.';

  @override
  String scheduleVacation({required String start, required String end}) {
    return 'En pause du $start au $end. Le planning reprendra ensuite.';
  }

  @override
  String get scheduleWeekly => 'Chaque semaine';

  @override
  String get scheduleRepeatsWeekly => 'Se répète chaque semaine';

  @override
  String get scheduleShareSlot => 'Partager ce live';

  @override
  String get settingsClipDiscovery => 'Clips des chaînes';

  @override
  String get clipDiscoveryAll => 'Tous les clips';

  @override
  String get clipDiscoveryFeatured => 'Mis en avant uniquement';

  @override
  String get settingsHideViewerCount => 'Masquer le nombre de spectateurs';

  @override
  String get settingsStreamPreviews => 'Aperçus des lives';

  @override
  String get settingsStreamPreviewsDetail =>
      'Lit la chaîne affichée dans l’onglet En direct avant que vous ne l’ouvriez.';

  @override
  String get settingsMutePreviews => 'Lancer les aperçus sans le son';

  @override
  String get settingsDataSaver => 'Économiseur de données';

  @override
  String get settingsDataSaverDetail =>
      'Sur les données mobiles, les lives démarrent en 480p au maximum et les aperçus ne sont pas lus. Vous pouvez toujours choisir une autre qualité.';

  @override
  String get settingsAlertsOverLandscapeVideo =>
      'Alertes sur la vidéo en paysage';

  @override
  String get settingsAlertsOverLandscapeVideoDetail =>
      'Désactivé, le mode paysage affiche une ligne dans le chat à la place, et rien ne couvre le live.';

  @override
  String get followedSortRecommended => 'Recommandées';

  @override
  String followedVideosNew({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouvelles vidéos',
      one: '$count nouvelle vidéo',
    );
    return '$_temp0';
  }

  @override
  String get followedBrowseChannels => 'Parcourir les chaînes';

  @override
  String get shareTitle => 'Partager';

  @override
  String get shareSendToChat => 'Envoyer dans le chat';

  @override
  String shareSendToChannelChat({required String name}) {
    return 'Envoyer dans le chat de $name';
  }

  @override
  String get shareSendAsWhisper => 'Envoyer en chuchotement';

  @override
  String get shareOther => 'Plus d’options…';

  @override
  String shareSentToChat({required String name}) {
    return 'Lien envoyé dans le chat de $name.';
  }

  @override
  String get shareChatLogInAgain =>
      'Reconnectez-vous pour envoyer des liens dans le chat depuis ici.';

  @override
  String get shareChatFailed => 'Impossible d’envoyer le lien dans le chat.';

  @override
  String shareWhisperSent({required String name}) {
    return 'Lien chuchoté à $name.';
  }

  @override
  String get newFeaturePill => 'Nouveau';

  @override
  String get pointsIntroTitle => 'Points de chaîne';

  @override
  String get pointsIntroBody =>
      'Chaque chaîne a ses propres points. Vous les gagnez en regardant, et vous les dépensez en récompenses et en prédictions sur cette chaîne.';

  @override
  String get pointsIntroGotIt => 'Compris';

  @override
  String get pointsHowToEarn => 'Comment gagner des points';

  @override
  String get pointsEarnWatch =>
      'Regardez le live : des points s’accumulent régulièrement tant qu’il est en cours.';

  @override
  String get pointsEarnBonus =>
      'Récupérez le bonus quand il apparaît dans le chat.';

  @override
  String get pointsEarnStreak =>
      'Entretenez une série de visionnage en revenant à chaque live.';

  @override
  String get pointsEarnFollow => 'Suivez la chaîne.';

  @override
  String get pointsEarnRaid => 'Participez à un raid lancé par la chaîne.';

  @override
  String get pointsEarnSubscriber =>
      'Les abonnés gagnent davantage pour tout ce qui précède.';

  @override
  String get pointsEarnNote =>
      'Chaque chaîne fixe ses propres montants. Regarder depuis cette application ne compte pas forcément autant que sur Twitch.';

  @override
  String get settingsReplayPointsIntro =>
      'Revoir la présentation des points de chaîne';

  @override
  String get settingsReplayPointsIntroDetail =>
      'Elle s’affichera la prochaine fois que vous ouvrirez les points d’une chaîne.';

  @override
  String get settingsPointsIntroReset =>
      'La présentation s’affichera de nouveau.';

  @override
  String get feedbackPromptTitle => 'ONSET vous plaît ?';

  @override
  String get feedbackPromptMessage =>
      'Dites-nous ce qui fonctionne et ce qui coince. Vos retours vont sur la page GitHub du projet, où vous pouvez signaler un bug ou proposer une idée.';

  @override
  String get feedbackPromptSend => 'Donner mon avis';

  @override
  String get feedbackPromptLater => 'Plus tard';

  @override
  String get feedbackPromptNever => 'Ne plus demander';

  @override
  String get settingsSendFeedback => 'Envoyer un avis';

  @override
  String get settingsTwitchHelp => 'Aide et assistance Twitch';

  @override
  String get settingsTwitchProfile => 'Modifier le profil';

  @override
  String get settingsTwitchProfileDetail =>
      'Nom affiché, bio, photo – sur twitch.tv';

  @override
  String get settingsTwitchNotifications => 'E-mails et notifications';

  @override
  String get settingsTwitchNotificationsDetail =>
      'Ce que Twitch vous envoie par e-mail ou en notification – sur twitch.tv';

  @override
  String get settingsTwitchFamilyCenter => 'Espace famille';

  @override
  String get settingsTwitchFamilyCenterDetail =>
      'Outils de supervision parentale – sur twitch.tv';

  @override
  String get settingsTwitchSubscriptions => 'Mes abonnements';

  @override
  String get settingsTwitchSubscriptionsDetail =>
      'Gérer vos abonnements – sur twitch.tv';

  @override
  String get settingsTwitchDrops => 'Inventaire des drops';

  @override
  String get settingsTwitchDropsDetail =>
      'Récompenses gagnées en regardant – sur twitch.tv';

  @override
  String get settingsTwitchTurbo => 'Twitch Turbo';

  @override
  String get settingsTwitchTurboDetail =>
      'Visionnage sans publicité – sur twitch.tv';

  @override
  String get settingsTwitchPrime => 'Prime Gaming';

  @override
  String get settingsTwitchPrimeDetail =>
      'Votre abonnement mensuel gratuit – sur twitch.tv';

  @override
  String get settingsTwitchRecap => 'Bilan de l’année';

  @override
  String get settingsTwitchRecapDetail =>
      'Votre année sur Twitch – sur twitch.tv';

  @override
  String get settingsTwitchSignup => 'Créer un autre compte';

  @override
  String get settingsTwitchSignupDetail =>
      'Un nouveau compte Twitch – sur twitch.tv';

  @override
  String get settingsTwitchDeleteAccount => 'Désactiver ou supprimer le compte';

  @override
  String get settingsTwitchDeleteAccountDetail =>
      'Fermer votre compte Twitch – sur twitch.tv';

  @override
  String get reportOnTwitch => 'Signaler';

  @override
  String get chatReportMessage => 'Signaler le message';

  @override
  String get chatReportEmote => 'Signaler l’emote';

  @override
  String get clipReport => 'Signaler';

  @override
  String get modToolsModView => 'Vue modérateur';

  @override
  String get clipFromPastBroadcast => 'Issu d’une diffusion passée';

  @override
  String streamCheckBackSoon({required String name}) {
    return '$name est hors ligne. Revenez bientôt !';
  }

  @override
  String get streamCheckBackSoonGeneric =>
      'Cette chaîne est hors ligne. Revenez bientôt !';

  @override
  String get streamOfflineLoadFailed => 'Impossible de charger cette chaîne.';

  @override
  String get goalKindSubs => 'Objectif d’abonnements';

  @override
  String get goalKindSubPoints => 'Objectif de points d’abonnement';

  @override
  String get goalKindNewSubs => 'Objectif de nouveaux abonnements';

  @override
  String get goalKindNewSubPoints => 'Objectif de nouveaux points d’abonnement';

  @override
  String get goalKindFollowers => 'Objectif de followers';

  @override
  String get goalKindOther => 'Objectif';

  @override
  String goalOrdinal({required int index, required int count}) {
    return '$index/$count';
  }

  @override
  String goalProgress({required int current, required int target}) {
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat targetNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String targetString = targetNumberFormat.format(target);

    return '$currentString sur $targetString';
  }

  @override
  String get goalReachedTitle => 'Objectif atteint';

  @override
  String get goalReachedBody =>
      'La chaîne a atteint cet objectif. Merci à toutes les personnes qui y ont contribué !';

  @override
  String vodSeekValueChapter({required String value, required String chapter}) {
    return '$value, $chapter';
  }

  @override
  String searchLiveWithTag({required String tag}) {
    return 'Chaînes en direct avec le tag $tag';
  }

  @override
  String get chatGigantifiedEmote => 'Emote géante';

  @override
  String get profileTabCollections => 'Collections';

  @override
  String profileCollectionVideos({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vidéos',
      one: '$count vidéo',
    );
    return '$_temp0';
  }

  @override
  String get clipSortNewest => 'Les plus récents';

  @override
  String get clipSortOldest => 'Les plus anciens';

  @override
  String get clipPickDates => 'Choisir des dates';

  @override
  String clipDateRange({required String start, required String end}) {
    return 'Du $start au $end';
  }

  @override
  String get clipFiltersReset => 'Réinitialiser les filtres';

  @override
  String get clipsNoneLastDay => 'Aucun clip ces dernières 24 heures';

  @override
  String get clipsNoneLastWeek => 'Aucun clip ces 7 derniers jours';

  @override
  String get clipsNoneLastMonth => 'Aucun clip ces 30 derniers jours';

  @override
  String get clipsNoneAllTime => 'Aucun clip pour l’instant';

  @override
  String clipsNoneInRange({required String start, required String end}) {
    return 'Aucun clip entre le $start et le $end';
  }

  @override
  String get clipDownload => 'Télécharger';

  @override
  String get clipDownloadPreparing => 'Préparation du clip…';

  @override
  String get clipDownloadFailed => 'Impossible de télécharger ce clip.';

  @override
  String get myClipsTitle => 'Mes clips';

  @override
  String get myClipsOfMyChannel => 'Ma chaîne';

  @override
  String get myClipsMadeByMe => 'Créés par moi';

  @override
  String get myClipsManage => 'Gérer sur Twitch';

  @override
  String get myClipsSubtitle =>
      'Les clips de votre chaîne et ceux que vous avez créés';

  @override
  String get streamFilterLanguage => 'Langue';

  @override
  String streamFilterFollowSetting({required String language}) {
    return 'Comme dans les Paramètres ($language)';
  }

  @override
  String get streamFilterClear => 'Effacer les filtres';

  @override
  String get streamFilterLabel => 'Filtres';

  @override
  String get streamFilterNoMatch =>
      'Aucune chaîne en direct ne correspond à ces filtres';

  @override
  String get searchRelatedLives => 'Chaînes en direct associées';

  @override
  String get chatBubblesTitle => 'Bulles d’événements';

  @override
  String get chatBubblesDetail =>
      'Affiche les événements du chat que vous choisissez dans des bulles arrondies.';

  @override
  String get chatBubblesOff => 'Désactivées';

  @override
  String chatBubblesCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count types',
      one: '$count type',
    );
    return '$_temp0';
  }

  @override
  String get chatBubblesSubs => 'Abonnements';

  @override
  String get chatBubblesGifts => 'Abonnements offerts';

  @override
  String get chatBubblesRaids => 'Raids';

  @override
  String get chatBubblesAnnouncements => 'Annonces';

  @override
  String get chatBubblesOther => 'Autres événements';

  @override
  String get channelPrefsTitle => 'Préférences de la chaîne';

  @override
  String channelPrefsIntro({required String name}) {
    return 'Ces choix ne s’appliquent qu’à la chaîne $name.';
  }

  @override
  String get channelPrefsNotifications => 'Notifications';

  @override
  String get channelPrefsBell => 'Notifications de live';

  @override
  String channelPrefsBellDetail({required String name}) {
    return 'Recevez une notification quand la chaîne $name lance un live.';
  }

  @override
  String get channelPrefsBellOff =>
      'Activez les notifications de live dans les Paramètres pour utiliser la cloche.';

  @override
  String get channelPrefsBellLoggedOut =>
      'Connectez-vous pour recevoir les notifications de live.';

  @override
  String get channelPrefsChat => 'Chat';

  @override
  String get channelPrefsNotices => 'Afficher les événements';

  @override
  String get channelPrefsNoticesDetail =>
      'Abonnements, cadeaux, raids et annonces dans ce chat.';

  @override
  String get channelPrefsNoticesOff =>
      'Les événements sont masqués dans tous les chats (Paramètres › Chat).';

  @override
  String get channelPrefsLists => 'Listes';

  @override
  String get channelPrefsPin => 'Épingler en haut';

  @override
  String get channelPrefsPinDetail =>
      'Affiche cette chaîne en premier dans Suivis quand elle est en direct.';

  @override
  String get channelPrefsHide => 'Masquer dans Parcourir';

  @override
  String get channelPrefsHideDetail =>
      'Retire cette chaîne de Parcourir et des listes de catégories et de tags. Suivis l’affiche toujours.';

  @override
  String get userActionsChannelPrefs => 'Préférences de la chaîne';

  @override
  String pointsBitsBalance({required String bits}) {
    return 'Solde de Bits : $bits';
  }

  @override
  String pointsGiftedHere({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count abonnements offerts ici depuis votre arrivée',
      one: '$count abonnement offert ici depuis votre arrivée',
    );
    return '$_temp0';
  }

  @override
  String get goalReachedDetails => 'Détails';
}
