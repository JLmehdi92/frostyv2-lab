# Rapport de la phase 5 (suite) — fonctionnalités Twitch

Ce rapport couvre les fonctionnalités livrées après la modération (E11). Pour chacune : ce qui marche, comment l'essayer sur la tablette et ce qui reste. L'état de chaque ligne et les comptes sont dans `docs/GAP.md`, la structure du code dans `docs/ARCHITECTURE.md`.

Méthode suivie pour chaque fonctionnalité : plan, tests écrits d'abord, revue par des agents relecteurs (code, erreurs silencieuses, sécurité), corrections dans des commits séparés, puis validation commit par commit (`flutter analyze` propre, tous les tests verts, APK de debug construit) avant l'intégration sur `main`.

## À faire une fois sur la tablette

- **Se reconnecter.** De nouveaux scopes OAuth ont été ajoutés (whispers, emotes de l'utilisateur, `user:read:chat`). Un ancien jeton continue de marcher pour le reste, mais ces fonctions restent muettes jusqu'à la reconnexion.
- **Whispers** : Twitch exige un numéro de téléphone vérifié sur le compte pour en envoyer.

## Fonctionnalités

### Whispers et fiche utilisateur (E12) — sur `main`
- Boîte de réception (non lus), conversation, envoi, `/w` dans le chat, bouton « Whisper » dans la fiche d'un utilisateur. Réception en temps réel par EventSub (WebSocket du compte).
- La fiche utilisateur montre les badges (mois d'abonnement), la date de création du compte et « suit depuis ».
- À tester : recevoir et envoyer un whisper, l'ouvrir depuis l'accueil (« ! » si Twitch refuse).

### Live et hors ligne en direct (PLY-09/10) — sur `main`
- Connecté, le lecteur natif démarre dès qu'une chaîne hors ligne passe en live (événement `stream.online`), sinon il vérifie chaque minute. Une chaîne hors ligne à l'ouverture garde le lecteur natif.

### Notifications de live (SOC-05/06) — sur `main`
- Réglage « Go-live notifications » (Général › Notifications) et cloche par chaîne dans son menu. Vérification en arrière-plan environ toutes les 15 min (Android décide), notification qui ouvre la chaîne dans l'appli.
- Limite : ce n'est pas du push Twitch (impossible sans les serveurs de Twitch), d'où le délai.

### Cheermotes (INT-11) — sur `main`
- Les messages avec Bits affichent l'image animée du palier et le montant en couleur.

### Partage (SOC-15) — sur `main`
- Partager une chaîne, un clip ou une vidéo par la feuille système, ou « Copy link ».

### Emotes utilisables (CHT-23)
- Le menu d'emotes et l'autocomplétion proposent toutes les emotes que le compte peut utiliser, y compris les emotes « follower » de la chaîne sans abonnement.

### Lecteur d'écran (ACC-30)
- TalkBack lit le nom des boutons, des emotes et des badges. La vidéo s'annonce « Video player », et ses gestes de double tap sont proposés comme actions (±10 s, disposition du chat). Le séparateur du chat se règle comme un curseur, la catégorie s'ouvre comme un lien.
- À tester : activer TalkBack, parcourir une chaîne et son chat.

### Lives refusés expliqués (PLY-26/27)
- Live réservé aux abonnés, géobloqué ou chaîne qui t'a banni : bascule immédiate vers le lecteur web avec la raison (« X is streaming for subscribers only. Trying the web player. »), au lieu d'environ 7 s de rechargements inutiles et d'aucune explication.
- Limite : pas de bannière « aperçu gratuit » native ; un abonné passe par le lecteur web (le jeton natif est anonyme).

### AutoMod côté émetteur (CHT-44)
- Quand AutoMod retient un de tes messages, une notice dit ensuite s'il a été approuvé, refusé ou s'il a expiré.

### Audio en arrière-plan et contrôles média (PLY-14/15)
- Réglage « Background audio » (Vidéo, désactivé par défaut) : le live continue appli fermée ou écran éteint, avec une notification média, l'écran verrouillé et les boutons du casque.
- À tester : activer le réglage, lancer un live, éteindre l'écran, utiliser pause/lecture du casque, puis « Stop » dans la notification.

### Focus audio (PLY-06)
- Un appel ou une autre appli qui joue du son met le live en pause ; la fin d'un appel le relance. Débrancher le casque met en pause.
- À tester : appel entrant, musique dans une autre appli, casque débranché.

### Lives labellisés masqués (DSC-19, ACC-22 en local)
- Réglage « Hide labeled streams » (Général › Browse) : choisis les labels (jeux d'argent, thèmes sexuels…). Top, catégories et tags les laissent de côté, avec une bannière « N streams hidden… · Show ». Les chaînes suivies s'affichent toujours.

### Préchargement du jeton (PLY-02)
- Le jeton de lecture est demandé dès que le doigt touche une carte de live, pendant que la page s'ouvre. Le lecteur reprend cette requête au lieu d'en relancer une. Gain à mesurer sur la tablette (temps de démarrage dans l'overlay de stats).

### Suivre les raids (INT-19)
- Quand la chaîne regardée lance un raid, tu pars avec à la fin du compte à rebours, comme sur Twitch. « Stay here » pour rester. Ne se déclenche pas depuis une VOD ou le PiP.

### Vidéos des chaînes suivies (PRF-16)
- « Followed videos » dans l'onglet Following (visible même quand personne n'est en live) : les dernières vidéos de tes chaînes suivies, les plus récentes d'abord, ouvertes dans le lecteur VOD de l'appli.

## Retour à ONSET

L'appli reprend l'apparence et les fonctions d'ONSET (ton appli d'origine), par-dessus le travail du labo. Ce qui change pour toi :

- **Apparence ONSET** : nom, icône, écran de démarrage, thème noir et accent citron, police Inter. Le hype train et les notices d'abonnement suivent maintenant le style de l'appli Twitch, en vert là où Twitch met du violet.
- **Tablette comme ONSET** : barre de navigation en bas, listes sur une colonne, le bouton plein écran fait pivoter. Dans le chat paysage, sous 30 % de la largeur un crayon remplace la zone de saisie (le toucher élargit le chat), à partir de 30 % la saisie et le bouton d'envoi sont là. Un clip en paysage montre la vidéo seule. Gardés du labo : grilles des vidéos et des clips, largeur de lecture des whispers et du profil.
- **Points de chaîne** : solde en bas à gauche du chat (« 1.5K », « 1M »), icône cadeau quand un coffre est disponible, graphique quand une prédiction est ouverte. Le toucher ouvre la feuille : récompenses (confirmation, texte si demandé), coffre, prédiction et mise. Rien n'est jamais dépensé tout seul, et un second appui pendant l'envoi est refusé (plus de double dépense). Twitch refuse la réclamation du coffre hors de ses applis (contrôle anti-bot) : l'appli le dit et renvoie vers twitch.tv. Les échanges et les paris peuvent subir le même refus, affiché tel quel.
- **Célébrations** : une animation sur la chaîne quand quelqu'un offre des subs (réglage « Show celebrations » dans Chat).
- **Gift bombs** : chaque gift apparaît dans le chat (ou seulement le premier avec « Collapse gift bombs »), et une bannière avec compte à rebours reste au-dessus du chat, même quand les détails du hype train sont ouverts.
- **2K et jeton web** : le jeton de la session twitch.tv est récupéré à la connexion et rafraîchi au lancement. Le réglage « Twitch web token (2K) » ne l'affiche plus jamais en clair : il dit seulement s'il est présent et propose Remplacer / Effacer. Se déconnecter efface aussi la session twitch.tv.
- **Fiabilité** : les messages du viewer (points, prédictions) arrivent maintenant (le temps réel s'authentifie avant de s'abonner), une trame inattendue ne coupe plus rien, et une erreur de session expirée s'affiche comme telle au lieu de « Could not reach Twitch ».

À tester sur la tablette :

- Paysage, chat étroit (moins de 30 %) : le crayon apparaît et élargit le chat ; chat à 30 % ou plus : saisie et bouton d'envoi.
- Ouvrir un clip en paysage : vidéo seule ; le bouton plein écran revient en portrait.
- Connecté, sur une chaîne avec points : solde, feuille, un petit échange (vérifier qu'un seul est débité), une mise de 10 points sur une prédiction ouverte ; noter tout refus « anti-bot ».
- Attendre un coffre : l'icône cadeau apparaît ; « Collect bonus » doit afficher le refus de Twitch puis l'explication.
- Un gift de subs pendant un hype train ouvert : la bannière de gift bomb reste visible ; la célébration joue une fois (désactivable).
- Réglages › Vidéo › « Twitch web token (2K) » : le jeton n'apparaît pas, « Effacer » le retire ; puis se déconnecter et se reconnecter : le 2K revient.
- Écran d'accueil (onboarding) tenu en paysage : rien ne déborde.

## Ce qui reste et pourquoi

- **Suivre et voter en natif** : la mutation GQL exige `Client-Integrity`, que je ne contourne pas. Ces actions passent par les pages twitch.tv dans l'appli. Les points et les paris sont natifs depuis le retour à ONSET, mais Twitch peut les refuser pour la même raison (le coffre l'est toujours) : le refus est affiché, sans contournement.
- **Suggestions de recherche, notifications push Twitch, centre de notifications, avertissement viewer** : GQL privé ou serveurs Twitch.
- **Chromecast, lecteur flottant au-dessus des autres applis, flux vertical de découverte** : gros chantiers, peu utiles avec le PiP actuel ; non faits.
- **Validation sur appareil** : tout ce qui est marqué « à valider sur appareil » dans `docs/GAP.md` doit être essayé sur la Pad 7 (son, notifications, TalkBack, raids, latence).
