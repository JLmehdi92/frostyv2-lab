# Politique de confidentialité d’ONSET

**Date d’entrée en vigueur :** 1er novembre 2026

ONSET est un client Twitch gratuit et open source (AGPL-3.0-or-later) pour
Android (paquet `app.onset`). C’est un projet indépendant, qui n’est ni
affilié à Twitch Interactive, Inc., ni approuvé ni sponsorisé par elle.

Cette politique décrit ce que l’application ONSET et son site web font des
données. Elle s’appuie sur leur code source, consultable par tous à l’adresse
`https://github.com/JLmehdi92/onset`.

Cette politique est aussi disponible [en anglais](PRIVACY.md).

## En bref

- ONSET n’a **aucun système de compte à lui**. Il communique directement avec
  Twitch et avec plusieurs services tiers listés ci-dessous. Le seul serveur
  de l’application est un petit service de jetons qui donne aux spectateurs
  non connectés un jeton Twitch anonyme ; il ne conserve rien à votre sujet
  (section 4).
- ONSET n’affiche **aucune publicité de son fait**, et le développeur **ne
  vend ni ne loue aucune donnée**.
- Vos identifiants de connexion Twitch et votre historique restent **sur votre
  appareil** ; rien de tout cela n’est envoyé ailleurs qu’à Twitch.
- Les versions publiées sur GitHub incluent Google Firebase, mais n’envoient
  **aucun rapport de plantage, aucune statistique ni donnée de performance**
  tant que vous n’activez pas **Partager les rapports de plantage et
  statistiques** (« Share crash logs and analytics » en anglais), désactivé par défaut (section 5).
- La politique couvre aussi le site onsetapp.app, qui mesure sa fréquentation
  avec Cloudflare Web Analytics (section 12).

## 1. Responsable du traitement

ONSET est développé par Mehdi Seddiki, un particulier établi en France
(contact : `contact@onsetapp.app`). Le développeur est responsable de
l’application, de son service de jetons (section 4), des rapports de plantage
et statistiques recueillis via Google Firebase (section 5) et du site web
(section 12). Tant que vous n’activez pas **Partager les rapports de plantage
et statistiques**, les versions publiées n’envoient aucun rapport de plantage,
aucune statistique ni donnée de performance (les bibliothèques Firebase
démarrent quand même et peuvent contacter les serveurs de Google, mais sans
aucune de ces données ; voir la section 5). Le service de jetons ne voit votre
adresse IP que brièvement (section 4).

Twitch, les services d’emotes et les autres services listés en section 4
décident eux-mêmes de l’usage des données qu’ils reçoivent. Leurs propres
politiques de confidentialité s’y appliquent.

## 2. Connexion

La connexion est facultative : vous pouvez parcourir et regarder sans compte.

Lorsque vous vous connectez, ONSET ouvre dans l’application la page de
connexion et d’autorisation de Twitch elle-même (id.twitch.tv). Vous saisissez
votre mot de passe sur la page de Twitch, pas dans ONSET, qui ne le voit
jamais. Twitch remet ensuite à ONSET un jeton d’accès pour les autorisations
affichées sur cette page (lecture et envoi de messages de chat, vos chaînes
suivies, utilisateurs bloqués, couleur de chat, actions de modération si vous
êtes modérateur, chuchotements, vos emotes et création de clips).

Comme la page de connexion vous connecte à twitch.tv, elle laisse aussi un
cookie de session twitch.tv (`auth-token`) dans la vue web de l’application.
Sur Android, ONSET lit ce cookie et le conserve comme « jeton web » (vous
pouvez aussi le coller ou l’effacer dans **Paramètres › Vidéo › Jeton web
Twitch (2K)**, « Settings › Video › Twitch web token (2K) » en anglais). Il
n’est envoyé qu’à Twitch, pour des fonctions que l’API publique de Twitch
n’offre pas : qualités vidéo supérieures, anciennes diffusions réservées aux
abonnés, vos positions de lecture et « Continue watching », catégories
suivies, séries de visionnage (watch streaks), points de chaîne et
prédictions, et certains événements en temps réel. Pour le garder valide,
ONSET charge de temps en temps twitch.tv dans une vue web masquée pendant que
vous êtes connecté.

Lorsque vous n’êtes pas connecté, ONSET utilise un jeton anonyme que Twitch
délivre à l’application elle-même ; il n’est pas lié à vous. L’application
l’obtient auprès du service de jetons d’ONSET (section 4), afin que le secret
de l’application Twitch n’ait jamais à se trouver dans l’application.

## 3. Données stockées sur votre appareil

| Quoi | Où | Détails |
|---|---|---|
| Votre jeton d’accès Twitch, le jeton web twitch.tv, votre identifiant utilisateur Twitch (la connexion enregistrée), le jeton anonyme de l’application | Stockage chiffré de l’application (`flutter_secure_storage`, clé conservée dans l’Android Keystore) | Supprimés à la déconnexion, sauf le jeton anonyme. |
| Cookies, cache web et stockage des sites de twitch.tv | La vue web de l’application | Les cookies sont effacés à la déconnexion ; le cache web et le stockage des sites restent jusqu’à ce que vous effaciez les données de l’application ou la désinstalliez. |
| Vos réglages | Préférences de l’application | Thème, options de chat, de vidéo et de notifications, y compris les interrupteurs cités plus bas. |
| Historique de recherche (8 recherches au plus), emotes récemment utilisées (48 au plus), dernière qualité vidéo choisie | Préférences de l’application | |
| L’endroit où vous vous êtes arrêté dans les anciennes diffusions (300 au plus) et dans les directs (300 au plus, identifiants et horaires seulement) | Préférences de l’application | Conservé séparément pour chaque compte sous son identifiant utilisateur Twitch, et utilisé pour « Continue watching » et la reprise. Conservé après la déconnexion. |
| Historique des notifications (écran Activité, 100 entrées au plus) | Préférences de l’application | Notifications de live, rappels du planning et mentions dans le chat, y compris le texte de la mention. |
| État des notifications de live, rappels du planning, règles de chat acceptées, vérifications de mises à jour | Préférences de l’application | Votre identifiant utilisateur Twitch (pour la vérification des lives et les règles de chat acceptées), chaînes mises en sourdine, chaînes déjà annoncées, heures des rappels. Conservé après la déconnexion. |
| Images (emotes, badges, avatars, miniatures) | Cache | Supprimées après 30 jours sans utilisation. À vider dans **Paramètres › Autres › Vider le cache des images** (« Settings › Other › Clear image cache » en anglais). |
| Mises à jour téléchargées | Cache | Supprimées une fois la version installée. |
| Rapports de plantage en attente d’envoi, et les identifiants aléatoires utilisés par les bibliothèques Firebase | Stockage de l’application (bibliothèques Firebase) | Les rapports attendent ici d’être envoyés tant que **Partager les rapports de plantage et statistiques** est activé ; réglage désactivé, les rapports non envoyés sont supprimés au démarrage et quand vous le désactivez (section 5). |

ONSET désactive la sauvegarde Android de ses données (`allowBackup="false"`,
et les règles d’extraction de données excluent tout) : rien n’est copié dans
une sauvegarde en ligne ni vers un nouvel appareil.

## 4. Données envoyées sur le réseau

Toutes les connexions passent par HTTPS ou par des WebSockets sécurisés. Tout
service auquel l’application se connecte voit aussi votre adresse IP et des
informations techniques de base (comme l’agent utilisateur de l’application).

| Service | Quand | Ce qui est envoyé |
|---|---|---|
| **Service de jetons d’ONSET** (un Cloudflare Worker géré par le développeur, sur workers.dev) | Lorsque vous n’êtes pas connecté et que l’application n’a pas de jeton anonyme que Twitch accepte encore : au premier lancement, puis quand le jeton enregistré a expiré ou a été révoqué | Une requête sans aucune information de compte. Le service répond par le même jeton Twitch anonyme partagé pour tous les spectateurs. Il n’utilise votre adresse IP que pour limiter le nombre de demandes d’une même adresse (un compteur de courte durée) ; il ne la journalise pas, ne l’enregistre pas et ne conserve rien à votre sujet. Cloudflare, qui l’héberge, traite la connexion selon sa propre politique de confidentialité. |
| **Twitch** (api.twitch.tv, id.twitch.tv, gql.twitch.tv, irc-ws.chat.twitch.tv, eventsub.wss.twitch.tv, hermes.twitch.tv, usher.ttvnw.net, static-cdn.jtvnw.net, twitch.tv, player.twitch.tv et les serveurs vidéo de Twitch) | Dès que vous utilisez l’application | Votre jeton d’accès ou votre jeton web si vous êtes connecté ; quand vous ouvrez le chat d’une chaîne en étant connecté, une demande des messages récents de ce chat, envoyée avec votre jeton web twitch.tv ; les chaînes, vidéos, catégories et recherches que vous ouvrez ; les messages de chat, chuchotements et actions de modération que vous envoyez ; les chaînes que vous suivez ; les blocages, clips et actions sur les points de chaîne et les prédictions que vous effectuez ; si vous êtes connecté, votre position dans les anciennes diffusions (enregistrée sur votre compte Twitch). Quand les notifications de live sont activées, l’application vérifie vos chaînes suivies environ toutes les 15 minutes en arrière-plan. À la déconnexion, ONSET demande à Twitch de révoquer votre jeton d’accès. |
| **Lecteur Amazon IVS** (intégré à l’application) | Quand un direct ou une vidéo est lu dans le lecteur natif | La vidéo provient des serveurs de Twitch. La bibliothèque du lecteur IVS peut aussi envoyer des statistiques de qualité de lecture au service IVS d’Amazon (player.stats.live-video.net). ONSET ne configure pas ces données et ne les reçoit pas. |
| **Lecteur web de Twitch** (dans une vue web) | Quand vous choisissez le lecteur web dans **Paramètres › Vidéo**, ou quand le lecteur natif échoue | La page du lecteur de Twitch fonctionne comme sur twitch.tv, selon la politique de confidentialité de Twitch, et peut afficher des publicités de Twitch. |
| **7TV** (7tv.io, events.7tv.io et ses serveurs d’images) | À l’ouverture d’une chaîne, sauf si **Afficher les emotes 7TV** (« Show 7TV emotes » en anglais) est désactivé | L’identifiant Twitch de la chaîne ; une connexion en direct pour les changements d’emotes de cette chaîne. |
| **BetterTTV** (api.betterttv.net, cdn.betterttv.net) | À l’ouverture d’une chaîne, sauf si **Afficher les emotes BTTV** et **Afficher les badges BTTV** (« Show BTTV emotes » et « Show BTTV badges » en anglais) sont désactivés | L’identifiant Twitch de la chaîne ; des requêtes pour les listes globales d’emotes et de badges. |
| **FrankerFaceZ** (api.frankerfacez.com et ses serveurs d’images) | À l’ouverture d’une chaîne, sauf si **Afficher les emotes FFZ** et **Afficher les badges FFZ** (« Show FFZ emotes » et « Show FFZ badges » en anglais) sont désactivés | L’identifiant Twitch de la chaîne ; des requêtes pour les listes globales d’emotes et de badges. |
| **recent-messages.robotty.de** | Seulement si vous activez **Historique de secours du chat (tiers)** (« Fallback chat history (third-party) » en anglais), désactivé par défaut, et seulement quand l’historique récent de Twitch n’est pas disponible, échoue ou est vide (par exemple quand vous n’êtes pas connecté) | Le nom de connexion (login) de la chaîne dont vous ouvrez le chat. |
| **GIPHY** (giphy.com et ses sous-domaines) | Quand un message de chat contient un GIF du clavier GIF de Twitch, sauf si **Afficher les GIF dans le chat** (« Show GIFs in Chat » en anglais) est désactivé | Une requête pour cette image GIF. Seules les adresses d’images de GIPHY et de Twitch sont chargées. |
| **GitHub** (api.github.com, github.com, objects.githubusercontent.com, release-assets.githubusercontent.com) | Dans les versions qui incluent le système de mise à jour (c’est le cas des APK des versions publiées sur GitHub, page Releases du dépôt ONSET ; une version construite sans lui ne contacte jamais GitHub) : au lancement et au retour au premier plan (au plus toutes les 6 heures une fois à jour), et quand vous appuyez sur **Mettre à jour** ou **Rechercher des mises à jour** (« Update » et « Check for updates » en anglais) | Une requête pour la dernière version publiée du dépôt ONSET ; le téléchargement du nouvel APK quand vous appuyez sur Mettre à jour. Aucune information de compte. |
| **Google Firebase** (Crashlytics, Google Analytics for Firebase et Performance Monitoring, exploités par Google) | Rapports, statistiques et données de performance : seulement tant que **Partager les rapports de plantage et statistiques** est activé (désactivé par défaut), dans l’application comme pendant la vérification des lives en arrière-plan ; jamais dans les versions de débogage. Les bibliothèques peuvent contacter Google à chaque ouverture de l’application, quel que soit le réglage | Rapports de plantage et d’erreurs, noms des écrans de l’application que vous ouvrez, durées des requêtes réduites au domaine du service, informations sur l’appareil et l’application. Aucun identifiant utilisateur Twitch, nom d’utilisateur ni nom de chaîne. Voir la section 5. |
| **Google Play** (avis dans l’application) | Après plusieurs lancements, si Google Play est installé | L’application peut demander à Google Play d’afficher sa fenêtre de notation, via le service d’avis dans l’application de Google Play. |

Les liens de vidéos et de clips Twitch sur lesquels vous appuyez s’ouvrent
dans ONSET ; les autres liens web s’ouvrent dans un onglet de navigateur
intégré à l’application, ou dans votre navigateur si **Ouvrir les liens dans
un navigateur externe** (« Open links in external browser » en anglais) est
activé. Les liens que vous partagez passent par le menu de partage d’Android.
ONSET ne récupère pas d’aperçus d’autres sites : le chat n’affiche d’aperçu
que pour les liens de clips et de vidéos Twitch, obtenu auprès de Twitch.

## 5. Rapports de plantage et statistiques (Firebase)

Les versions publiées sur GitHub incluent Google Firebase : Crashlytics
(rapports de plantage), Google Analytics for Firebase (statistiques
d’utilisation) et Performance Monitoring (mesures de rapidité). Ces
bibliothèques ne recueillent des données que si vous activez **Partager les
rapports de plantage et statistiques**.

**Désactivé par défaut.** Le réglage est désactivé sur une nouvelle
installation. Vous pouvez l’activer dans les écrans de configuration du
premier lancement ou dans **Paramètres › Autres › Confidentialité**
(« Settings › Other › Privacy » en anglais), et le désactiver à tout moment au
même endroit. **Réinitialiser les paramètres** (« Reset settings » en anglais,
dans **Paramètres › Autres**) le désactive à nouveau. Les versions de débogage
ne recueillent jamais rien, quel que soit le réglage.

**Réglage désactivé, aucun rapport de plantage, aucune statistique ni donnée
de performance n’est envoyé.** À l’ouverture de l’application, les
bibliothèques Firebase démarrent quand même et peuvent contacter les serveurs
de Google (par exemple pour enregistrer l’installation), sans aucune de ces
données ; la vérification des lives en arrière-plan ne les démarre pas du
tout. L’application ne transmet aucune erreur, ligne de journal ni mesure à
Crashlytics ou à Performance Monitoring. Les trois collectes sont déclarées
désactivées jusqu’à ce que l’application applique votre choix au démarrage :
Analytics n’enregistre donc rien non plus. Normalement, Crashlytics conserve
les rapports de plantage sur l’appareil pour les envoyer plus tard. Réglage
désactivé, l’application ne lui transmet rien, et tout rapport que Crashlytics
a conservé de lui-même (pour un plantage du code Android de l’application, par
exemple) est supprimé sans être envoyé à chaque démarrage et chaque fois que
vous désactivez le réglage. Ce qui a été envoyé pendant que le réglage était
activé n’est pas retiré pour autant (la section 7 indique pendant combien de
temps ces données sont conservées).

**Réglage activé, l’application envoie** (de même que la vérification des
lives en arrière-plan, pour ses propres erreurs) :

- **Rapports de plantage (Crashlytics) :** les plantages et erreurs non
  interceptées, et certaines erreurs inattendues dont l’application se remet
  (par exemple une erreur de serveur, une erreur de connexion du chat ou du
  temps réel, une défaillance du lecteur vidéo). Chaque rapport contient le
  type et le message de l’erreur, la trace d’appels et un court libellé de
  l’endroit où elle s’est produite ; pour une requête en échec, sa méthode et
  l’adresse du service réduite au domaine (par exemple
  `https://api.twitch.tv`), jamais le chemin ni les paramètres. De courtes
  lignes de journal s’y ajoutent lors de certaines défaillances (tentatives de
  reconnexion au chat et de reconnexion au compte ; requête de l’annuaire des
  lives ou des temps forts de Twitch qui a cessé de fonctionner, avec son
  message d’erreur), ainsi qu’une valeur oui/non indiquant si vous êtes
  connecté. Crashlytics ajoute des informations techniques comme le modèle de
  l’appareil, la version d’Android, la version de l’application,
  l’orientation, la mémoire et le stockage libres.
- **Statistiques (Google Analytics for Firebase) :** le nom de chaque écran
  de l’application que vous ouvrez. Ce sont des noms fixes comme
  `VideoChat`, `VodScreen`, `Settings` ou `/search`, jamais la chaîne, la
  vidéo ou la recherche concernée. ONSET n’enregistre aucun autre événement
  de son fait. La bibliothèque Analytics enregistre aussi d’elle-même des
  événements (comme la première ouverture, les sessions, le temps passé dans
  l’application, les mises à jour de l’application) avec des informations
  sur l’appareil et l’application (modèle de l’appareil, version d’Android,
  version de l’application, langue) et une localisation approximative (pays
  ou région) que Google déduit de votre adresse IP.
- **Performances (Performance Monitoring) :** pour chaque requête que
  l’application fait par son propre client HTTP, le domaine du service
  seulement (ni chemin ni paramètres), la méthode, le code de réponse et la
  durée. La bibliothèque Performance mesure aussi certaines choses d’elle-même,
  comme le temps de démarrage de l’application et l’affichage des écrans
  (images lentes ou figées). Google reçoit aussi votre adresse IP, dont il se
  sert pour déterminer le pays, et l’identifiant d’installation Firebase.

**Ce qui n’en fait pas partie.** ONSET ne met dans ces rapports aucun
identifiant utilisateur Twitch, nom d’utilisateur ni nom de chaîne, et aucun
jeton. Les adresses des requêtes sont réduites au domaine. Les bibliothèques
Firebase distinguent les installations par des identifiants aléatoires
qu’elles génèrent (un identifiant d’installation Firebase et un identifiant
d’instance d’application Analytics), qui ne sont pas liés à votre compte
Twitch et sont remplacés quand vous effacez les données de l’application ou la
réinstallez. L’identifiant publicitaire n’est pas recueilli : l’application
retire les autorisations d’identifiant publicitaire, désactive la collecte de
l’identifiant publicitaire dans Analytics et désactive les signaux de
personnalisation des annonces.

**Base légale.** Votre consentement (article 6, paragraphe 1, point a) du
RGPD), donné en activant le réglage. Vous pouvez le retirer à tout moment en
désactivant le réglage ; cela ne remet pas en cause ce qui a été recueilli
auparavant.

**Google, sous-traitant.** Google traite ces données en tant que
sous-traitant du développeur, selon les conditions de traitement des données
de Firebase (le partage des données Analytics avec Google est désactivé dans
le projet), et peut les traiter hors de l’Union européenne, notamment aux
États-Unis, avec les garanties que prévoient ces conditions.

## 6. Autorisations Android

| Autorisation | Pourquoi |
|---|---|
| Internet, état du réseau | Se connecter à Twitch et aux services ci-dessus ; savoir si vous êtes en données mobiles (pour des options comme la lecture automatique en Wi-Fi seulement). |
| Notifications | Notifications de live, mentions dans le chat, rappels du planning, notification multimédia. Android 13 ou version ultérieure vous le demande d’abord. |
| Service au premier plan (lecture multimédia) | Continuer la lecture audio en arrière-plan. |
| Lancement au démarrage | Rétablir vos rappels du planning après un redémarrage. |
| Installation d’applications inconnues | Installer une mise à jour d’ONSET que vous avez choisi de télécharger. Android vous demande de l’autoriser la première fois. |

Les bibliothèques incluses dans l’application en ajoutent quelques-unes, par
exemple : vibration (notifications), maintien de l’appareil éveillé et service
court au premier plan (vérification des lives en arrière-plan), état du Wi-Fi
(lecteur IVS). Les autorisations d’identifiant publicitaire et de services
publicitaires qu’ajouterait la bibliothèque Firebase Analytics sont retirées
de l’application, et l’identifiant publicitaire n’est pas recueilli (section
5). ONSET ne demande pas d’accès à l’appareil photo, au micro, à la position,
aux contacts ni au stockage.

## 7. Durée de conservation

- **Sur votre appareil :** jusqu’à ce que vous vous déconnectiez (jetons,
  connexion enregistrée et cookies web), vidiez le cache d’images, effaciez
  les données de l’application ou la désinstalliez (tout le reste, y compris
  l’identifiant Twitch conservé avec les listes locales). Les listes sont
  plafonnées comme indiqué en section 3.
- **Firebase** (seulement ce qui a été envoyé pendant que **Partager les
  rapports de plantage et statistiques** était activé) : Crashlytics conserve
  les données de plantage et leurs identifiants pendant 90 jours. Performance
  Monitoring conserve les événements liés à une adresse IP pendant 30 jours et
  les autres données de performance pendant 60 jours. Google Analytics
  conserve les données au niveau de l’utilisateur et des événements pendant 2
  mois (le réglage du projet) ; les rapports agrégés, qui n’identifient
  personne, ne sont pas concernés par cette limite. L’identifiant
  d’installation Firebase est conservé jusqu’à ce que le développeur le
  supprime.
- **Twitch et les autres services :** selon leurs propres politiques.

## 8. Supprimer vos données

- **Se déconnecter** (« Log out » en anglais, dans Profil ou Paramètres) :
  ONSET demande à Twitch de révoquer votre jeton d’accès, supprime de
  l’appareil vos jetons et la connexion enregistrée (votre identifiant Twitch
  dans le stockage chiffré) et efface les cookies de la vue web. Vos réglages
  et votre historique local restent sur l’appareil, de même que l’identifiant
  Twitch conservé avec ces listes locales (positions de lecture, règles de
  chat acceptées, vérification des lives), jusqu’à ce que vous effaciez les
  données de l’application ou la désinstalliez. ONSET ne demande pas à Twitch
  de fermer la session web twitch.tv elle-même. Pour retirer à ONSET l’accès à
  votre compte, passez par vos paramètres Twitch, rubrique **Connexions**.
- **Effacer les données de l’application** (Paramètres Android › Applications ›
  ONSET › Stockage) ou **désinstaller** ONSET : tout ce qu’ONSET a enregistré
  sur l’appareil est supprimé, y compris les rapports de plantage non envoyés
  et les identifiants Firebase.
- Désactiver le réglage **Partager les rapports de plantage et statistiques**
  (**Paramètres › Autres › Confidentialité**) : plus aucun rapport de
  plantage, aucune statistique ni donnée de performance n’est envoyé, et les
  rapports de plantage conservés sur l’appareil et pas encore envoyés sont
  supprimés. Ce que Firebase a déjà reçu ne porte aucun identifiant de compte
  (ni identifiant utilisateur Twitch ni nom d’utilisateur, seulement les
  identifiants aléatoires de la section 5) : le développeur peut ne pas
  parvenir à rattacher à vos données une demande de suppression envoyée par
  e-mail. Vous pouvez tout de même écrire à `contact@onsetapp.app` ; dans tous
  les cas, ces données expirent avec les durées de conservation de la section
  7.
- Les données détenues par Twitch et les autres services se suppriment auprès
  d’eux.

## 9. Enfants

ONSET est un client pour Twitch, destiné aux personnes autorisées à utiliser
Twitch. Les conditions d’utilisation de Twitch exigent d’avoir au moins 13 ans
(ou plus si la loi locale fixe un âge minimum plus élevé), et les utilisateurs
qui n’ont pas atteint la majorité ne peuvent utiliser Twitch que sous la
supervision et avec l’accord d’un parent ou d’un tuteur. Vous devez remplir
les conditions d’âge de Twitch pour utiliser ONSET. ONSET ne s’adresse pas aux
enfants de moins de 13 ans.

## 10. Vos droits

En vertu du RGPD, vous disposez d’un droit d’accès, de rectification et
d’effacement de vos données personnelles, d’un droit d’opposition et de
limitation du traitement, ainsi que d’un droit à la portabilité. Vous pouvez
aussi retirer à tout moment votre consentement aux rapports de plantage et aux
statistiques en désactivant **Partager les rapports de plantage et
statistiques**. Le développeur ne détient aucune donnée vous concernant issue
des versions publiées, sauf si vous avez activé ce réglage ; ces données ne
sont liées à aucun compte, si bien que le développeur peut ne pas retrouver
les vôtres (sections 5 et 8). Pour exercer un droit, ou pour toute question,
écrivez à `contact@onsetapp.app`. Vous pouvez aussi adresser une réclamation à
l’autorité française de protection des données, la CNIL (https://www.cnil.fr).

Pour les données détenues par Twitch ou les autres services, adressez-vous
directement à eux.

## 11. Politiques de confidentialité des tiers

- Twitch : https://legal.twitch.com/legal/privacy-notice/
- 7TV : https://7tv.app/legal/privacy
- BetterTTV : https://betterttv.com/privacy
- FrankerFaceZ : https://www.frankerfacez.com/privacy
- recent-messages (robotty) : https://recent-messages.robotty.de/ (la page du service décrit ce qu’il conserve)
- GIPHY : https://giphy.com/privacy
- Cloudflare (service de jetons, hébergement du site et Web Analytics) : https://www.cloudflare.com/privacypolicy/
- GitHub : https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement
- Amazon Web Services (lecteur IVS) : https://aws.amazon.com/privacy/
- Google (Google Play, Firebase) : https://policies.google.com/privacy
- Google Firebase (rapports de plantage et statistiques) : https://firebase.google.com/support/privacy

## 12. Le site web

Cette politique couvre aussi le site onsetapp.app, géré par le développeur.

- **Hébergement :** le site est hébergé sur Cloudflare Pages. Pour servir les
  pages et protéger le site contre les abus, Cloudflare traite des données
  techniques sur chaque requête, comme votre adresse IP et l’agent utilisateur
  (user agent) de votre navigateur, selon sa propre politique de
  confidentialité (https://www.cloudflare.com/privacypolicy/). Le site
  lui-même ne dépose aucun cookie, mais Cloudflare peut déposer un cookie de
  sécurité strictement nécessaire (comme `__cf_bm` ou `cf_clearance`) s’il
  doit vérifier qu’une requête ne vient pas d’un robot.
- **Statistiques de visite :** le site utilise Cloudflare Web Analytics. Sur
  chaque page, un petit script de Cloudflare (static.cloudflareinsights.com)
  transmet à Cloudflare des informations sur la visite, comme l’adresse de la
  page (sans ses paramètres ni son ancre), celle de la page d’où vous venez
  (s’il y en a une), des mesures de performance (temps de chargement et
  signaux Web essentiels, ou Core Web Vitals, dont le sélecteur CSS et
  l’adresse de l’image du plus grand élément de la page), la taille transférée
  et le protocole réseau, une estimation grossière de la mémoire, les versions
  de votre navigateur et de votre système d’exploitation, ainsi qu’un
  identifiant aléatoire propre à ce chargement de page. Cloudflare reçoit
  aussi votre adresse IP avec la requête et en déduit votre pays. Le
  développeur ne voit que des chiffres agrégés, comme les pages vues, les
  visites, les pages les plus consultées, les sites référents, les pays, les
  navigateurs, les systèmes d’exploitation, les types d’appareils et les temps
  de chargement. Selon Cloudflare, Web Analytics n’utilise ni cookie ni
  stockage local pour recueillir ces statistiques, n’a pas recours à
  l’empreinte numérique (fingerprinting) pour les établir et ne suit pas les
  visiteurs d’un site à l’autre parmi ceux qui utilisent Cloudflare. Toujours
  selon Cloudflare, les données détaillées sont conservées 7 jours, puis seul
  un échantillon d’environ 10 % en est gardé ; le développeur peut consulter
  les chiffres des six derniers mois.
- **Choix de la langue :** quand vous choisissez l’anglais ou le français dans
  le sélecteur de langue, le site enregistre ce choix dans le stockage local
  de votre navigateur (localStorage), sous la clé `onset.lang`. Il sert
  uniquement à déterminer la version de la page d’accueil qui s’ouvrira la
  prochaine fois, et il ne quitte jamais votre navigateur. Quand vous ouvrez
  la page d’accueil anglaise sans avoir choisi l’anglais, le site vous
  redirige vers la page d’accueil française si vous avez choisi le français,
  ou si la langue préférée de votre navigateur est le français et que vous
  n’arrivez pas d’une autre page du site.
- **Base légale :** l’intérêt légitime du développeur à servir et à protéger
  le site, et à mesurer sa fréquentation au moyen de statistiques agrégées
  (article 6, paragraphe 1, point f) du RGPD). Vous pouvez vous y opposer à
  tout moment (section 10) ; la plupart des bloqueurs de contenu bloquent déjà
  le script de statistiques. Cloudflare traite ces données pour le compte du
  développeur (pour celles qu’il utilise afin de protéger son propre réseau,
  il agit selon sa propre politique de confidentialité) et peut les traiter
  hors de l’Union européenne, notamment aux États-Unis ; selon Cloudflare, ces
  transferts reposent sur le cadre de protection des données UE-États-Unis
  (Data Privacy Framework) ou, à défaut, sur des clauses contractuelles types.
- **Rien d’autre :** le site n’affiche aucune publicité et ne fait appel à
  aucun autre service tiers. Le lien de téléchargement, le lien vers GitHub et
  celui de la liste d’attente iPhone mènent tous à GitHub, qui applique sa
  propre déclaration de confidentialité.

## 13. Modifications

Si ONSET se met à traiter les données différemment, cette politique sera mise
à jour et sa date d’entrée en vigueur modifiée. L’historique de cette
politique est public dans le dépôt GitHub d’ONSET.

- 31 octobre 2026 : les versions publiées incluent les rapports de plantage et
  les statistiques de Firebase, désactivés sauf si vous les activez. Sur les
  installations mises à jour depuis une version plus ancienne, où le réglage
  était activé par défaut, cette mise à jour l’a désactivé : réactivez-le si
  vous voulez partager les rapports de plantage et les statistiques.
- 31 octobre 2026 : formulation clarifiée ; aucun changement dans le
  traitement des données.
- 1er novembre 2026 : ajout d’une section sur le site web.

## 14. Contact

`contact@onsetapp.app`
