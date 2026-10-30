# Mises à jour dans l'appli — mise en place (une seule fois)

À chaque push sur `main`, GitHub Actions (workflow **ONSET update**,
`.github/workflows/onset-update.yml`) construit un APK arm64 signé et le publie
comme release `build-N` du dépôt (N = 2000 + numéro d'exécution du workflow :
les builds ONSET publiés avant ce dépôt allaient jusqu'aux 1000 et quelques,
et Android n'installe une mise à jour que si son numéro est plus grand).
L'appli installée vérifie la dernière release au démarrage et au retour au
premier plan (au plus toutes les 6 h tant qu'elle est à jour), affiche
« Update available », télécharge l'APK, vérifie son SHA-256 et le confie à
l'installeur d'Android. **Réglages → Check for updates** force une
vérification.

Les builds locaux ne vérifient jamais rien (ils n'ont pas `UPDATE_REPO`) : la
fonction n'existe que dans les APK produits par le workflow (voir l'étape 6
pour les builds locaux).

## 0. Dépôt public ou privé

Le dépôt `JLmehdi92/onset` est **public** : ses builds ne contiennent aucun
jeton, et l'appli lit ses releases anonymement, comme n'importe quel
visiteur. Il n'y a rien à faire pour cela (`UPDATE_TOKEN` n'est pas lu, il
peut manquer).

- Sans jeton, l'appli interroge l'API GitHub sans en-tête `Authorization`. La
  limite anonyme est de 60 requêtes par heure et par adresse IP ; l'appli
  demande au plus une fois toutes les 6 h. Si GitHub refuse quand même (403
  ou 429), l'appli attend aussi 6 h avant de redemander d'elle-même
  (**Check for updates** reste possible à tout moment).
- Le téléchargement suit le lien de l'API puis le lien signé de GitHub en
  `https`, et le SHA-256 est toujours vérifié avant l'installation.

Le workflow sait aussi construire depuis un dépôt **privé** (une copie
privée, par exemple). Il lit la visibilité à chaque build, dans l'événement
qui l'a lancé et en demandant le dépôt tel qu'il est maintenant ; le jeton
`UPDATE_TOKEN` (étape 2) n'est mis dans l'APK que si les deux disent
« privé », et la publication est refusée si le dépôt est devenu public
pendant le build. Un jeton se lit dans un APK : avant de rendre public un
dépôt privé, révoquez `UPDATE_TOKEN` et supprimez les releases faites en
privé. Un build sans jeton ne voit pas les releases d'un dépôt privé (GitHub
répond 404) : l'appli considère alors qu'il n'y a pas de mise à jour.

## 1. La clé de signature (keystore)

Android n'accepte une mise à jour que si elle est signée avec **la même clé**
que l'appli installée.

**Recommandé : une clé dédiée, avec des mots de passe forts.** Coût : une seule
désinstallation de l'appli actuelle (signée avec la clé de debug du PC), donc
une reconnexion à Twitch et des réglages à refaire, une fois.

```powershell
keytool -genkeypair -v -keystore onset-release.jks -keyalg RSA -keysize 4096 -validity 10000 -alias onset
```

Choisissez deux mots de passe longs et différents (keystore et clé), sans `\`.
Sauvegardez le fichier `.jks` et ses mots de passe hors du PC (gestionnaire de
mots de passe) : sans eux, plus aucune mise à jour ne pourra s'installer
par-dessus l'appli. Ne le commitez jamais (le dépôt ignore `*.jks`).

*Alternative* : réutiliser la clé de debug du PC
(`%USERPROFILE%\.android\debug.keystore`, mots de passe `android`, alias
`androiddebugkey`). Plus de désinstallation, mais ce fichier devient alors une
clé de **production** : son mot de passe est public, quiconque le copie peut
signer une « mise à jour » acceptée par vos appareils, et il faut le
sauvegarder comme la clé dédiée (le perdre ou le régénérer coupe les mises à
jour).

Encodez le fichier en base64 avec PowerShell (le résultat va dans le
presse-papiers, à coller dans le secret `ANDROID_KEYSTORE_BASE64`) :

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\chemin\vers\onset-release.jks")) | Set-Clipboard
```

## 2. Le jeton GitHub en lecture seule (dépôt privé seulement)

Inutile pour un dépôt public : le workflow ne le lit pas.

github.com → photo de profil → **Settings** → **Developer settings** →
**Personal access tokens** → **Fine-grained tokens** → **Generate new token** :
accès au seul dépôt de build, permission **Contents** en *Read-only* (rien
d'autre), expiration d'un an. **L'APK contient ce jeton en clair** : il lit
tout le code du dépôt et tous les APK de ses releases. Ne partagez jamais un
tel APK ; s'il fuite, révoquez le jeton, créez-en un autre et mettez à jour le
secret `UPDATE_TOKEN`.

## 3. Les secrets du dépôt

`JLmehdi92/onset` → **Settings** → **Secrets and variables** →
**Actions** → **New repository secret**, pour chacun :

| Secret | Valeur |
|---|---|
| `CLIENT_ID` | l'identifiant client de l'application Twitch **ONSET** du compte ONSET (étape 7, point 7) |
| `UPDATE_TOKEN` | le jeton de l'étape 2 (dépôt privé seulement) |
| `ANDROID_KEYSTORE_BASE64` | le keystore encodé à l'étape 1 |
| `ANDROID_KEYSTORE_PASSWORD` | mot de passe du keystore |
| `ANDROID_KEY_ALIAS` | alias de la clé (`onset` avec la commande ci-dessus) |
| `ANDROID_KEY_PASSWORD` | mot de passe de la clé |

Si l'un d'eux manque, le workflow s'arrête tout de suite en le nommant (sans
jamais afficher de valeur). `UPDATE_TOKEN` n'est exigé que si le dépôt est
privé. Aucun secret client Twitch n'est un secret du dépôt : celui de
l'application « ONSET public » va dans le Worker (étape 7), et l'application
de connexion « ONSET » n'en a pas.

**Une variable, obligatoire** — même page, onglet **Variables** (pas
*Secrets*) → **New repository variable** :

| Variable | Valeur |
|---|---|
| `TOKEN_PROXY_URL` | l'adresse du proxy de jeton (étape 7), par exemple `https://onset-token.votre-nom.workers.dev`, **sans** `/app-token` |

C'est une variable et non un secret parce que l'adresse est dans chaque APK de
toute façon. Si elle manque ou n'est pas une simple adresse `https://` (rien
d'autre que l'adresse : ni `?`, ni `#`, ni espace, ni `nom:motdepasse@`, comme
l'appli l'exige), le workflow s'arrête avec « The repository variable
TOKEN_PROXY_URL is missing or is not a plain https:// URL ». Ce refus est voulu : sans elle, toutes les applis
installées recevraient une mise à jour où, déconnecté, on n'a plus ni
émotes ni badges Twitch, ni Parcourir, ni Recherche, sans rien dans le journal
pour dire pourquoi.

**Facultatifs — Firebase** (Crashlytics, Analytics, Performance) : sans eux,
l'appli tourne simplement sans Firebase, et c'est le cas des builds publiés
par ce dépôt (voir [`PRIVACY.fr.md`](../PRIVACY.fr.md)). Pour l'activer dans
vos propres builds, créez votre projet Firebase (console Firebase → ajouter
une appli Android `app.onset`, et iOS `app.onset` si besoin), puis ajoutez :

| Secret | Valeur |
|---|---|
| `FIREBASE_API_KEY` | clé API Web/Android du projet |
| `FIREBASE_APP_ID_ANDROID` | identifiant d'appli Android (`1:…:android:…`) |
| `FIREBASE_APP_ID_IOS` | identifiant d'appli iOS (`1:…:ios:…`), vide sinon |
| `FIREBASE_MESSAGING_SENDER_ID` | numéro du projet |
| `FIREBASE_PROJECT_ID` | identifiant du projet |
| `FIREBASE_STORAGE_BUCKET` | facultatif |

Le dépôt n'est pas à renseigner : le workflow utilise celui où il tourne, et
déclare lui-même les droits dont il a besoin (rien à changer dans les réglages
Actions du dépôt).

Ne jamais ajouter `-v` (ou `--verbose`) à l'étape de build du workflow : un
build verbeux affiche ses `--dart-define`, donc les secrets, dans les journaux.

## 4. Le premier build, installé à la main

1. Onglet **Actions** → **ONSET update** → **Run workflow** (branche `main` ; sur
   une autre branche, rien n'est publié).
2. Une fois terminé, la release **ONSET build N** apparaît dans **Releases**.
3. Avec une clé dédiée : désinstallez l'appli actuelle.
4. Installez ce premier APK à la main, une seule fois (l'appli actuelle ne peut
   pas le trouver seule) : sur l'appareil, ouvrez la page de la release dans le
   navigateur (**connecté à GitHub** si le dépôt est privé), téléchargez
   `onset-arm64.apk` et ouvrez-le.

Ensuite, chaque push sur `main` (hors `docs/` et fichiers `.md`) produit
une release que l'appli propose d'elle-même.

## 5. Ce que l'on voit sur l'appareil

1. Popup **Update available** : « ONSET build N is ready. » et le titre du
   commit. **Later** la fait taire 24 h pour ce build (un build plus récent
   reprend la main) ; **Update** lance la mise à jour.
2. La première fois seulement : Android demande d'autoriser ONSET à installer
   des applis → **Open settings** → activer *Autoriser cette source* → revenir
   dans ONSET, le téléchargement démarre. (Si Android redémarre l'appli à ce
   moment-là, la popup revient au démarrage suivant.)
3. Barre de progression (Mo téléchargés / total), annulable, puis
   « Installing update ».
4. L'écran d'installation d'Android demande confirmation → **Mettre à jour**.
   L'appli se ferme ; rouvrez-la depuis le lanceur.

En cas d'échec : « Download failed » (réseau, ou plus rien reçu pendant 30 s),
« The download was corrupted — try again » (SHA-256 différent : le fichier est
supprimé, rien n'est installé), « Android could not install the update » (le
plus souvent : APK signé avec une autre clé que l'appli installée, voir
l'étape 1). L'APK téléchargé est effacé au démarrage suivant une fois installé.

## 6. Builds locaux après le premier build CI

Android refuse d'installer un build dont le numéro (versionCode) est inférieur
à celui installé ; `flutter run` réagit en **désinstallant** l'appli, ce qui
efface la connexion Twitch et les réglages. Le numéro par défaut du
`pubspec.yaml` (1) est bien inférieur aux builds CI (2001 et plus), et
`flutter run` n'accepte pas `--build-number` : on construit donc l'APK avec le
bon numéro, puis on le lance.

Ce numéro est **celui du dernier build CI installé** (release `build-2023` →
`2023`), pas plus : un numéro supérieur empêcherait l'appli de proposer les
builds CI suivants tant qu'ils ne l'ont pas dépassé.

Avec la clé de debug du PC (alternative de l'étape 1) :

```powershell
flutter build apk --debug --build-number=2023 --dart-define=CLIENT_ID=<id> --dart-define=TOKEN_PROXY_URL=<adresse du proxy>
flutter run --use-application-binary=build\app\outputs\flutter-apk\app-debug.apk
```

Avec une clé dédiée, un build de debug est signé avec la clé de debug du PC :
Android le refuse par-dessus un build CI, et `flutter run` désinstalle quand
même. Pour garder ses données, construisez un build *release* signé avec la
même clé (fichier `android/key.properties` sur le PC, jamais commité :
`storePassword=…`, `keyPassword=…`, `keyAlias=onset`,
`storeFile=C:/chemin/vers/onset-release.jks`, avec des `/`) et installez-le
par-dessus avec `adb` (`flutter install` désinstalle d'abord) :

```powershell
flutter build apk --release --build-number=2023 --dart-define=CLIENT_ID=<id> --dart-define=TOKEN_PROXY_URL=<adresse du proxy>
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

Un build local sans `UPDATE_REPO` ne propose aucune mise à jour : le build CI
suivant devra être installé à la main (étape 4), sauf si vous ajoutez
`--dart-define=UPDATE_REPO=JLmehdi92/onset` à la commande de build (plus
`--dart-define=UPDATE_TOKEN=<jeton>` si le dépôt est privé ; ne partagez alors
jamais cet APK).

## 7. Le proxy de jeton : compte ONSET et Cloudflare Worker

Déconnecté, ONSET a besoin d'un « jeton d'application » Twitch pour les émotes
et badges Twitch du chat, Parcourir, Recherche, les catégories et les infos de
chaîne des lecteurs. L'obtenir demande un **secret client** Twitch, et tout ce qui est dans un APK
peut en être extrait. Donc :

- ONSET a **son propre compte Twitch**, réservé au développement, avec
  **deux applications** :

  | Application | Sert à | Secret client |
  |---|---|---|
  | **ONSET** | se connecter à ONSET ; son Client ID va dans le secret GitHub `CLIENT_ID` | **aucun, jamais** : la connexion n'en a pas besoin |
  | **ONSET public** | le jeton des utilisateurs déconnectés, fabriqué par le Worker | dans le Worker seulement |

- Un petit **Cloudflare Worker** (gratuit), dans votre compte Cloudflare,
  fabrique ce jeton pour « ONSET public » ; l'appli ne connaît que son
  adresse. Une application à laquelle personne ne se connecte n'atteint les
  données privées de personne, alors qu'un jeton de l'application de
  connexion permettrait, par exemple, de recevoir les chuchotements de ses
  utilisateurs.

**La règle des secrets** : un secret client ne se colle **que** dans les
champs secrets de Cloudflare (point 4). Jamais dans GitHub, dans l'appli,
dans un fichier, un site, une discussion ou un message, et ne l'envoyez
**jamais à personne**, pas même à quelqu'un qui vous aide : personne d'autre
n'en a besoin.

Le guide détaillé, écran par écran, est en anglais :
[`tool/token_proxy/README.md`](../tool/token_proxy/README.md). Ses étapes 1 à
8 portent les mêmes numéros que les points ci-dessous, et le point 9 est son
étape 10 ; ses étapes 9, 11 et 12 ne servent qu'à qui remplace une ancienne
application de connexion. Dans l'ordre :

1. **Créer le compte Twitch ONSET et activer la double authentification** :
   déconnecté de Twitch (ou en navigation privée), créez un nouveau compte
   sur <https://www.twitch.tv/signup>, réservé à ONSET. Puis photo de profil
   → **Settings** → **Security and Privacy** → **Two-Factor Authentication**
   et suivez les étapes (Twitch l'exige pour créer des applications).
2. **Créer les deux applications**, connecté avec le compte ONSET, sur
   <https://dev.twitch.tv/console/apps> → **Register Your Application** :
   - **ONSET** : adresse de redirection `https://twitch.tv/login`
     (exactement), catégorie *Application Integration*, type *Confidential*.
     **Manage** → notez son **Client ID**. Ne cliquez **pas** sur
     **New Secret** : cette application n'en a jamais besoin.
   - **ONSET public** : adresse de redirection `http://localhost`, même
     catégorie, type *Confidential*. **Manage** → notez son **Client ID**,
     puis **New Secret** → notez son **Client Secret** (pour le point 4
     seulement).
3. **Créer le Worker et son stockage** : compte Cloudflare gratuit →
   **Workers & Pages** → **Create application** → modèle *Hello World* → nom
   `onset-token` → **Deploy** → **Edit code** → remplacer tout le code par
   celui de `tool/token_proxy/worker.js` → **Deploy**. Notez son adresse
   (`https://onset-token.votre-nom.workers.dev`). Puis **Storage &
   Databases** → **Workers KV** → créez `onset-token-cache`, et reliez-le au
   Worker (**Settings** → **Bindings** → **KV namespace**) sous le nom
   `TOKEN_CACHE`. Ce stockage est **obligatoire** : sans lui le Worker refuse
   de fonctionner.
4. **Ajouter les 2 secrets du Worker** : le Worker → **Settings** →
   **Variables and Secrets** → **Add**, type **Secret** : `TWITCH_CLIENT_ID`
   et `TWITCH_CLIENT_SECRET`, ceux d'**ONSET public** (point 2). Ensuite,
   fermez la page Twitch qui affiche le secret.
5. **Vérifier `/app-token`** : ouvrez
   `https://onset-token.votre-nom.workers.dev/app-token` dans un navigateur ;
   vous devez voir `{"access_token":"…","expires_in":…,"client_id":"…"}`,
   avec le Client ID d'**ONSET public** (pas celui d'ONSET).
6. **Variable GitHub `TOKEN_PROXY_URL`** : dépôt → **Settings** → **Secrets
   and variables** → **Actions** → onglet **Variables** → **New repository
   variable** → nom `TOKEN_PROXY_URL`, valeur l'adresse du Worker **sans**
   `/app-token` (point 3).
7. **Secret GitHub `CLIENT_ID`** : même page, onglet **Secrets** → le secret
   `CLIENT_ID` (étape 3) → le Client ID de l'application **ONSET** (point 2,
   pas ONSET public).
8. **Lancer un build et l'installer** : **Actions** → **ONSET update** →
   **Run workflow** sur `main`, puis installez la mise à jour (proposée par
   l'appli, ou à la main depuis la release, étape 4).
9. **Tester déconnecté** : déconnectez-vous (ou utilisez une appli jamais
   connectée). Ouvrez **Parcourir**, une catégorie, la **Recherche**, puis le
   chat d'une chaîne : les émotes et badges Twitch doivent s'afficher, sans
   popup « Session expired ». Si rien ne s'affiche, ouvrez l'adresse
   `/app-token` du point 5 pour voir si le Worker répond, et vérifiez que son
   `client_id` est bien celui d'**ONSET public** : l'appli refuse un jeton de
   l'application de connexion « ONSET » (un Worker réglé avec les
   identifiants d'ONSET exposerait les événements privés des utilisateurs),
   et cette confusion se voit justement comme « rien ne marche déconnecté »
   (dépannage dans le guide).

**Facultatif : le script de nettoyage EventSub**, documenté dans le guide
(« Optional: cleaning up a login application you keep »), pour qui garde une
application de connexion dont le secret a fuité : il liste les abonnements
*webhook* et les *conduits* de cette application et ne supprime rien tant
qu'on n'a pas tapé `DELETE`. Il tourne sur votre ordinateur, seule exception
à la règle des secrets ci-dessus.

Limites, honnêtement :

- L'adresse du Worker est publique (elle est dans l'APK), donc le jeton
  aussi. Avec « ONSET public », il lit des données publiques de Twitch et
  rien d'aucun utilisateur d'ONSET. Quelqu'un pourrait quand même le
  **révoquer** (chaque copie du Worker s'en aperçoit en 10 minutes au plus,
  sans rien écrire dans KV, et il en fabrique
  un autre, au plus une fois par minute : quelqu'un qui s'acharnerait
  priverait les utilisateurs déconnectés d'émotes, de badges et de
  Parcourir tant qu'il continue), **épuiser sa limite de débit** Twitch,
  partagée par toutes les applis déconnectées, ou faire **suspendre « ONSET
  public »** par Twitch en en abusant. Les utilisateurs connectés ne sont
  jamais touchés : leur application, « ONSET », est une autre.
- Le Worker limite chaque adresse IP (chaque bloc `/64` en IPv6) à 10
  demandes par minute, mais depuis le tableau de bord cette limite est
  approximative (comptée séparément par chaque copie du Worker).
- Le plan gratuit autorise 100 000 requêtes par jour, et une demande refusée
  (429) **compte quand même**. Si quelqu'un les épuisait, seuls les
  utilisateurs déconnectés qui ont besoin d'un nouveau jeton ce jour-là s'en
  passeraient jusqu'à minuit UTC. **Restez sur le plan gratuit** : c'est un
  plafond strict, un abus ne peut rien vous coûter. Si vous passez un jour à
  un plan payant, réglez d'abord une alerte de facturation. Amélioration
  possible : avec votre propre domaine chez Cloudflare, une règle de
  limitation de débit du pare-feu (WAF) arrête les rafales avant qu'elles
  n'atteignent le Worker et ne comptent.
- Si le Worker est en panne, l'appli démarre quand même, la connexion marche,
  et ce qui demande le jeton échoue sans popup ; l'appli redemande au plus une
  fois par minute.
