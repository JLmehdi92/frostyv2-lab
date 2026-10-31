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
}
