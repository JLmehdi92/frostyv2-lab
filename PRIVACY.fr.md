# Politique de confidentialité d'ONSET

**Date d'entrée en vigueur :** 30 octobre 2026

ONSET est un client Twitch gratuit et open source (AGPL-3.0-or-later) pour
Android (paquet `app.onset`). C'est un projet indépendant, qui n'est ni
affilié à Twitch Interactive, Inc., ni approuvé ni sponsorisé par elle.

Cette politique décrit ce que l'application ONSET fait des données. Elle
s'appuie sur le code source de l'application, consultable par tous à
l'adresse `https://github.com/JLmehdi92/onset`.

En cas de divergence, la version anglaise (`PRIVACY.md`) fait foi.

## En bref

- ONSET n'a **aucun système de compte à lui**. Il communique directement avec
  Twitch et avec quelques services tiers listés ci-dessous. Son seul serveur est
  un petit service de jetons qui donne aux spectateurs non connectés un jeton
  Twitch anonyme ; il ne conserve rien à votre sujet (section 4).
- ONSET n'affiche **aucune publicité de son fait**, et le développeur **ne
  vend ni ne loue aucune donnée**.
- Vos identifiants Twitch et votre historique restent **sur votre appareil** et
  ne sont envoyés qu'à Twitch.
- Les versions publiées sur GitHub n'envoient **aucun rapport de plantage,
  aucune statistique d'utilisation ni donnée de performance** (section 5).

## 1. Responsable du traitement

L'application est développée par un particulier établi en France, responsable
de l'application et de son service de jetons (section 4) : Mehdi SEDDIKI,
contact : `onsetapp.contact@gmail.com`. Les versions publiées n'envoient
aucune donnée personnelle au développeur ; le service de jetons ne voit votre
adresse IP qu'un instant (sections 4 et 5).

Twitch, les services d'emotes et les autres services listés en section 4
décident eux-mêmes de l'usage des données qu'ils reçoivent. Leurs propres
politiques de confidentialité s'y appliquent.

## 2. Connexion

La connexion est facultative : vous pouvez parcourir et regarder sans compte.

Lorsque vous vous connectez, ONSET ouvre dans l'application la page de
connexion et d'autorisation de Twitch elle-même (id.twitch.tv). Vous saisissez
votre mot de passe sur la page de Twitch, pas dans ONSET, qui ne le voit
jamais. Twitch remet ensuite à ONSET un jeton d'accès pour les autorisations
affichées sur cette page (lire et envoyer des messages de chat, chaînes
suivies, utilisateurs bloqués, couleur de chat, actions de modération si vous
êtes modérateur, chuchotements, vos emotes, création de clips).

Comme la page de connexion vous connecte à twitch.tv, elle laisse aussi un
cookie de session twitch.tv (`auth-token`) dans la vue web de l'application.
Sur Android, ONSET lit ce cookie et le conserve comme « jeton web » (vous
pouvez aussi le coller ou l'effacer dans **Settings › Video › Twitch web token
(2K)**). Il n'est envoyé qu'à Twitch, pour des fonctions que l'API publique de
Twitch n'offre pas : qualités vidéo supérieures, rediffusions réservées aux
abonnés, vos positions de lecture et « Continue watching », catégories
suivies, séries de visionnage (watch streaks), points de chaîne et
prédictions, et certains événements en temps réel. Pour le garder valide,
ONSET charge de temps en temps twitch.tv dans une vue web masquée pendant que
vous êtes connecté.

Lorsque vous n'êtes pas connecté, ONSET utilise un jeton anonyme que Twitch
délivre à l'application elle-même ; il n'est pas lié à vous. L'application
l'obtient auprès du service de jetons d'ONSET (section 4), afin que le secret
de l'application Twitch n'ait jamais à se trouver dans l'application.

## 3. Données stockées sur votre appareil

| Quoi | Où | Détails |
|---|---|---|
| Votre jeton d'accès Twitch, le jeton web twitch.tv, votre identifiant utilisateur Twitch (la connexion enregistrée), le jeton anonyme de l'application | Stockage chiffré de l'application (`flutter_secure_storage`, clé conservée dans l'Android Keystore) | Supprimés à la déconnexion, sauf le jeton anonyme. |
| Cookies, cache web et stockage des sites de twitch.tv | La vue web de l'application | Les cookies sont effacés à la déconnexion ; le cache web et le stockage des sites restent jusqu'à ce que vous effaciez les données de l'application ou la désinstalliez. |
| Vos réglages | Préférences de l'application | Thème, options de chat, de vidéo et de notifications, y compris les interrupteurs cités plus bas. |
| Historique de recherche (8 recherches au plus), emotes récemment utilisées (48 au plus), dernière qualité vidéo choisie | Préférences de l'application | |
| L'endroit où vous vous êtes arrêté dans les rediffusions (300 au plus) et dans les directs (300 au plus, identifiants et horaires seulement) | Préférences de l'application | Conservé séparément pour chaque compte, sous son identifiant utilisateur Twitch, sert à « Continue watching » et à la reprise. Conservé après la déconnexion. |
| Historique des notifications (écran Activity, 100 entrées au plus) | Préférences de l'application | Annonces de mise en direct, rappels de programmes et mentions dans le chat, y compris le texte de la mention. |
| État des notifications de mise en direct, rappels de programmes, règles de chat acceptées, vérifications de mises à jour | Préférences de l'application | Votre identifiant utilisateur Twitch (pour la vérification des mises en direct et les règles de chat acceptées), chaînes mises en sourdine, chaînes déjà annoncées, heures des rappels. Conservé après la déconnexion. |
| Images (emotes, badges, avatars, miniatures) | Cache | Supprimées après 30 jours sans utilisation. À vider dans **Settings › Other › Clear image cache**. |
| Mises à jour téléchargées | Cache | Supprimées une fois la version installée. |

ONSET désactive la sauvegarde Android de ses données (`allowBackup="false"`,
et les règles d'extraction de données excluent tout) : rien n'est copié dans
une sauvegarde en ligne ni vers un nouvel appareil.

## 4. Données envoyées sur le réseau

Toutes les connexions passent par HTTPS ou par des WebSockets sécurisés. Tout
service auquel l'application se connecte voit aussi votre adresse IP et des
informations techniques de base (comme l'agent utilisateur de l'application).

| Service | Quand | Ce qui est envoyé |
|---|---|---|
| **Service de jetons d'ONSET** (un Cloudflare Worker géré par le développeur, sur workers.dev) | Lorsque vous n'êtes pas connecté et que l'application n'a pas de jeton anonyme que Twitch accepte encore : au premier lancement, puis quand le jeton enregistré a expiré ou a été révoqué | Une requête sans aucune information de compte. Le service répond par le même jeton Twitch anonyme partagé pour tous les spectateurs. Il n'utilise votre adresse IP que pour limiter le nombre de demandes d'une même adresse (un compteur de courte durée) ; il ne la journalise pas, ne l'enregistre pas et ne conserve rien à votre sujet. Cloudflare, qui l'héberge, traite la connexion selon sa propre politique de confidentialité. |
| **Twitch** (api.twitch.tv, id.twitch.tv, gql.twitch.tv, irc-ws.chat.twitch.tv, eventsub.wss.twitch.tv, hermes.twitch.tv, usher.ttvnw.net, static-cdn.jtvnw.net, twitch.tv, player.twitch.tv et les serveurs vidéo de Twitch) | Dès que vous utilisez l'application | Votre jeton d'accès ou votre jeton web si vous êtes connecté ; quand vous ouvrez le chat d'une chaîne en étant connecté (avec un jeton web twitch.tv), une demande des messages récents de ce chat, envoyée avec votre jeton web ; les chaînes, vidéos, catégories et recherches que vous ouvrez ; les messages de chat, chuchotements et actions de modération que vous envoyez ; les abonnements (follows), blocages, clips, actions sur les points de chaîne et les prédictions que vous effectuez ; si vous êtes connecté, votre position dans les rediffusions (enregistrée sur votre compte Twitch). Quand les notifications de mise en direct sont activées, l'application vérifie vos chaînes suivies environ toutes les 15 minutes en arrière-plan. À la déconnexion, ONSET demande à Twitch de révoquer votre jeton d'accès. |
| **Lecteur Amazon IVS** (intégré à l'application) | Quand un direct ou une vidéo est lu dans le lecteur natif | La vidéo provient des serveurs de Twitch. La bibliothèque du lecteur IVS peut aussi envoyer des statistiques de qualité de lecture au service IVS d'Amazon (player.stats.live-video.net). ONSET ne configure pas ces données et ne les reçoit pas. |
| **Lecteur web de Twitch** (dans une vue web) | Quand vous choisissez le lecteur web dans **Settings › Video**, ou quand le lecteur natif échoue | La page du lecteur de Twitch fonctionne comme sur twitch.tv, sous la politique de confidentialité de Twitch, et peut afficher des publicités de Twitch. |
| **7TV** (7tv.io, events.7tv.io et ses serveurs d'images) | À l'ouverture d'une chaîne, sauf si **Show 7TV emotes** est désactivé | L'identifiant Twitch de la chaîne ; une connexion en direct pour les changements d'emotes de cette chaîne. |
| **BetterTTV** (api.betterttv.net, cdn.betterttv.net) | À l'ouverture d'une chaîne, sauf si **Show BTTV emotes** et **Show BTTV badges** sont désactivés | L'identifiant Twitch de la chaîne ; des requêtes pour les listes globales d'emotes et de badges. |
| **FrankerFaceZ** (api.frankerfacez.com et ses serveurs d'images) | À l'ouverture d'une chaîne, sauf si **Show FFZ emotes** et **Show FFZ badges** sont désactivés | L'identifiant Twitch de la chaîne ; des requêtes pour les listes globales d'emotes et de badges. |
| **recent-messages.robotty.de** | Seulement si vous activez **Fallback chat history (third-party)** (désactivé par défaut), et seulement quand l'historique récent de Twitch n'est pas disponible, échoue ou est vide (par exemple quand vous n'êtes pas connecté) | Le nom de la chaîne dont vous ouvrez le chat. |
| **GIPHY** (giphy.com et ses sous-domaines) | Quand un message de chat contient un GIF du clavier GIF de Twitch, sauf si **Show GIFs in Chat** est désactivé | Une requête pour cette image GIF. Seules les adresses d'images de GIPHY et de Twitch sont chargées. |
| **GitHub** (api.github.com, github.com, objects.githubusercontent.com, release-assets.githubusercontent.com) | Dans les versions qui incluent le système de mise à jour (c'est le cas des APK publiés dans les releases de ce dépôt ; une version construite sans lui ne contacte jamais GitHub) : au lancement et au retour au premier plan (au plus toutes les 6 heures une fois à jour), et quand vous touchez **Update** ou **Check for updates** | Une requête pour la dernière version publiée du dépôt ONSET ; le téléchargement du nouvel APK quand vous touchez Update. Aucune information de compte. |
| **Google Play** (avis dans l'application) | Après plusieurs lancements, si Google Play est installé | L'application peut demander à Google Play d'afficher sa fenêtre de notation, via le service d'avis dans l'application de Google Play. |

Les liens que vous touchez dans le chat ou dans l'application s'ouvrent dans
votre navigateur ou dans l'application ; les liens que vous partagez passent
par le menu de partage d'Android. ONSET ne récupère pas d'aperçus d'autres
sites : le chat n'affiche d'aperçu que pour les liens de clips et de vidéos
Twitch, obtenu auprès de Twitch.

## 5. Rapports de plantage et statistiques (Firebase)

Les versions publiées dans les releases de ce dépôt n'incluent aucune
configuration Firebase : elles n'envoient à personne ni rapport de plantage,
ni statistique d'utilisation, ni donnée de performance, et le réglage **Share
crash logs and analytics** n'y a aucun effet. Si cela devait changer, cette
politique serait mise à jour avant.

Le code étant public : il contient les bibliothèques Firebase Crashlytics,
Analytics et Performance Monitoring de Google, qui ne démarrent que dans une
version construite avec une configuration Firebase.

## 6. Autorisations Android

| Autorisation | Pourquoi |
|---|---|
| Internet, état du réseau | Se connecter à Twitch et aux services ci-dessus ; savoir si vous êtes en données mobiles (pour des options comme la lecture automatique en Wi-Fi seulement). |
| Notifications | Annonces de mise en direct, mentions dans le chat, rappels de programmes, notification multimédia. Android 13 et plus vous le demande d'abord. |
| Service au premier plan (lecture multimédia) | Continuer la lecture audio en arrière-plan. |
| Lancement au démarrage | Rétablir vos rappels de programmes après un redémarrage. |
| Installation d'applications inconnues | Installer une mise à jour d'ONSET que vous avez choisi de télécharger. Android vous demande de l'autoriser la première fois. |

Les bibliothèques incluses dans l'application en ajoutent quelques-unes, par
exemple : vibration (notifications), maintien de l'appareil éveillé et service
court au premier plan (vérification des mises en direct en arrière-plan), état
du Wi-Fi (lecteur IVS). Les autorisations d'identifiant publicitaire et de
services publicitaires qu'ajouterait la bibliothèque Firebase Analytics sont
retirées de l'application. ONSET ne demande pas d'accès à l'appareil photo, au
micro, à la position, aux contacts ni au stockage.

## 7. Durée de conservation

- **Sur votre appareil :** jusqu'à ce que vous vous déconnectiez (jetons,
  connexion enregistrée et cookies web), vidiez le cache d'images, effaciez
  les données de l'application ou la désinstalliez (tout le reste, y compris
  l'identifiant Twitch conservé avec les listes locales, comme indiqué en
  section 3). Les listes sont plafonnées comme indiqué en section 3.
- **Twitch et les autres services :** selon leurs propres politiques.

## 8. Supprimer vos données

- **Déconnexion** (Profile ou Settings) : ONSET demande à Twitch de révoquer
  votre jeton d'accès, supprime de l'appareil vos jetons et la connexion
  enregistrée (votre identifiant Twitch dans le stockage chiffré) et efface
  les cookies de la vue web. Vos réglages et votre historique local restent
  sur l'appareil, de même que l'identifiant Twitch conservé avec ces listes
  locales (positions de lecture, règles de chat acceptées, vérification des
  mises en direct), jusqu'à ce que vous effaciez les données de l'application
  ou la désinstalliez. ONSET ne demande pas à Twitch de fermer la session web
  twitch.tv elle-même ; vous pouvez aussi retirer l'accès d'ONSET dans vos
  paramètres Twitch, rubrique **Connexions**.
- **Effacer les données de l'application** (Paramètres Android › Applications ›
  ONSET › Stockage) ou **désinstaller** ONSET : tout ce qu'ONSET a enregistré
  sur l'appareil est supprimé.
- Les données détenues par Twitch et les autres services se suppriment auprès
  d'eux.

## 9. Enfants

ONSET est un client pour Twitch, destiné aux personnes autorisées à utiliser
Twitch. Les conditions d'utilisation de Twitch exigent d'avoir au moins 13 ans
(ou plus si la loi locale fixe un âge minimum plus élevé), et les utilisateurs
qui n'ont pas atteint la majorité ne peuvent utiliser Twitch que sous la
supervision et avec l'accord d'un parent ou d'un tuteur. Vous devez remplir
les conditions d'âge de Twitch pour utiliser ONSET. ONSET ne s'adresse pas aux
enfants de moins de 13 ans.

## 10. Vos droits

En vertu du RGPD, vous disposez d'un droit d'accès, de rectification et
d'effacement de vos données personnelles, d'un droit d'opposition et de
limitation du traitement, et d'un droit à la portabilité. Le développeur ne
détient aucune donnée vous concernant issue des versions publiées (sections 4
et 5). Pour exercer un droit, ou pour toute question, écrivez à
`onsetapp.contact@gmail.com`. Vous pouvez aussi adresser une réclamation à
l'autorité française de protection des données, la CNIL
(https://www.cnil.fr).

Pour les données détenues par Twitch ou les autres services, adressez-vous
directement à eux.

## 11. Politiques de confidentialité des tiers

- Twitch : https://legal.twitch.com/legal/privacy-notice/
- 7TV : https://7tv.app/legal/privacy
- BetterTTV : https://betterttv.com/privacy
- FrankerFaceZ : https://www.frankerfacez.com/privacy
- recent-messages (robotty) : https://recent-messages.robotty.de/ (la page du service décrit ce qu'il conserve)
- GIPHY : https://giphy.com/privacy
- Cloudflare (service de jetons) : https://www.cloudflare.com/privacypolicy/
- GitHub : https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement
- Amazon Web Services (lecteur IVS) : https://aws.amazon.com/privacy/
- Google (Google Play) : https://policies.google.com/privacy

## 12. Modifications

Si ONSET se met à traiter les données différemment, cette politique sera mise
à jour et sa date d'entrée en vigueur modifiée. L'historique de ce fichier est
public dans le dépôt.

## 13. Contact

`onsetapp.contact@gmail.com`
