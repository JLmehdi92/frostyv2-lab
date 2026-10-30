# Mises à jour dans l'appli — mise en place (une seule fois)

À chaque push sur `main`, GitHub Actions (workflow **ONSET update**,
`.github/workflows/onset-update.yml`) construit un APK arm64 signé et le publie
comme release `build-N` du dépôt (N = 1000 + numéro d'exécution). L'appli
installée vérifie la dernière release au démarrage et au retour au premier plan
(au plus toutes les 6 h tant qu'elle est à jour), affiche « Update available »,
télécharge l'APK, vérifie son SHA-256 et le confie à l'installeur d'Android.
**Réglages → Check for updates** force une vérification.

Les builds locaux ne vérifient jamais rien (ils n'ont pas `UPDATE_REPO`) : la
fonction n'existe que dans les APK produits par le workflow (voir l'étape 6
pour les builds locaux).

## 0. Dépôt public ou privé

> **Avant de rendre le dépôt public, révoquez `UPDATE_TOKEN`** (étape 2 →
> **Delete**). Tout ce qui a été fait en privé devient public avec le dépôt :
> les releases `build-*` (leurs APK contiennent le jeton), mais aussi les
> **artefacts** des exécutions récentes (l'APK reste un jour dans l'exécution
> qui l'a construit), et un build en cours au moment du changement. Un jeton
> révoqué ne vaut plus rien, quel que soit l'endroit où on le retrouve.
> Conséquence : l'appli installée depuis un build privé ne trouve plus de mise
> à jour seule ; installez à la main le premier build public (étape 4).

Le workflow lit la visibilité du dépôt **à chaque build**, deux fois : dans
l'événement qui l'a lancé (`github.event.repository.private`) et en demandant
le dépôt tel qu'il est maintenant. Le jeton n'est utilisé que si les deux
disent « privé » ; si la visibilité est illisible, le build s'arrête.

| Dépôt | Le build | L'appli installée |
|---|---|---|
| **Privé** | contient `UPDATE_TOKEN` (secret obligatoire) | lit les releases avec le jeton |
| **Public** | **ne contient aucun jeton** (`UPDATE_TOKEN` vide, le secret n'est même pas lu ; il peut manquer) | lit les releases **sans jeton**, comme n'importe quel visiteur |

Pourquoi : les releases d'un dépôt public — donc leurs APK — sont
téléchargeables par tout le monde, et un jeton se lit dans un APK.

- Sans jeton, l'appli interroge l'API GitHub anonymement (aucun en-tête
  `Authorization`). La limite anonyme est de 60 requêtes par heure et par
  adresse IP ; l'appli demande au plus une fois toutes les 6 h, c'est large.
  Si GitHub refuse quand même (403 ou 429, limite atteinte), l'appli attend
  aussi 6 h avant de redemander d'elle-même (**Check for updates** reste
  possible à tout moment).
  Le téléchargement suit le même chemin qu'avant (lien de l'API, puis lien
  signé de GitHub en `https`), et le SHA-256 est toujours vérifié avant
  l'installation.
- Un build **sans jeton** sur un dépôt redevenu **privé** ne voit plus rien
  (GitHub répond 404) : l'appli considère qu'il n'y a pas de mise à jour, sans
  message d'erreur, et ne redemande qu'au bout de 6 h. Il faudra installer à
  la main le premier build fait en privé (étape 4).
- Le dépôt passe en public **pendant** un build qui a pris le jeton (ou dont
  on ne sait pas s'il l'a pris) : la publication est refusée (« The
  repository is not private ») et l'artefact de l'exécution, qui contient
  l'APK, est supprimé ; relancez le workflow, le nouveau build n'aura pas de
  jeton. Le jeton, révoqué avant le changement (encadré ci-dessus), ne
  servirait de toute façon plus à rien.
- Supprimez aussi les releases `build-*` faites en privé (**Releases** →
  chaque release → **Delete**) : même avec un jeton révoqué, elles
  contiennent `CLIENT_ID` et `SECRET` de Twitch (point suivant).
- `CLIENT_ID` et `SECRET` de Twitch restent dans **tous** les APK, publics
  compris : quiconque télécharge une release publique peut les en extraire.
  Tenez-les pour publiés dès le premier build public, et régénérez le secret
  Twitch au passage au dépôt définitif (liste du 1er novembre, étape 7).

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
signer une « mise à jour » acceptée par votre tablette, et il faut le
sauvegarder comme la clé dédiée (le perdre ou le régénérer coupe les mises à
jour).

Encodez le fichier en base64 avec PowerShell (le résultat va dans le
presse-papiers, à coller dans le secret `ANDROID_KEYSTORE_BASE64`) :

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\chemin\vers\onset-release.jks")) | Set-Clipboard
```

## 2. Le jeton GitHub en lecture seule (dépôt privé seulement)

Inutile tant que le dépôt est public : le workflow ne le lit pas.

github.com → photo de profil → **Settings** → **Developer settings** →
**Personal access tokens** → **Fine-grained tokens** → **Generate new token** :

- **Repository access** : *Only select repositories* → uniquement
  `JLmehdi92/onset` ;
- **Permissions** → **Repository permissions** → **Contents** : *Read-only*
  (rien d'autre) ;
- **Expiration** : 1 an (préférable à *No expiration*). À l'expiration, seules
  les mises à jour s'arrêtent : nouveau jeton, mise à jour du secret, nouveau
  build, installé une fois à la main (étape 4).

**L'APK contient des secrets en clair** — ce jeton, mais aussi `CLIENT_ID` et
`SECRET` de Twitch — et n'importe qui peut les en extraire :

- le jeton lit **tout le code** du dépôt et **tous les APK** de ses releases ;
- si le dépôt devient public un jour, tous les APK publiés (et donc ces
  secrets) le deviennent aussi : supprimez d'abord les releases faites en
  privé (étape 0) ;
- ne partagez donc jamais l'APK ; s'il fuite, révoquez le jeton (et créez-en un
  nouveau) **et** régénérez le secret client dans la console développeur
  Twitch, puis mettez à jour les secrets du dépôt.

## 3. Les secrets du dépôt

`JLmehdi92/onset` → **Settings** → **Secrets and variables** →
**Actions** → **New repository secret**, pour chacun :

| Secret | Valeur |
|---|---|
| `CLIENT_ID` | l'identifiant client Twitch (comme pour `--dart-define`) |
| `SECRET` | le secret client Twitch |
| `UPDATE_TOKEN` | le jeton de l'étape 2 (dépôt privé seulement) |
| `ANDROID_KEYSTORE_BASE64` | le keystore encodé à l'étape 1 |
| `ANDROID_KEYSTORE_PASSWORD` | mot de passe du keystore |
| `ANDROID_KEY_ALIAS` | alias de la clé (`onset` avec la commande ci-dessus) |
| `ANDROID_KEY_PASSWORD` | mot de passe de la clé |

Si l'un d'eux manque, le workflow s'arrête tout de suite en le nommant (sans
jamais afficher de valeur). `UPDATE_TOKEN` n'est exigé que si le dépôt est
privé.

**Facultatifs — Firebase** (Crashlytics, Analytics, Performance) : sans eux,
l'appli tourne simplement sans Firebase. Pour l'activer, créez votre projet
Firebase (console Firebase → ajouter une appli Android `app.onset`, et iOS
`app.onset` si besoin), puis ajoutez :

| Secret | Valeur |
|---|---|
| `FIREBASE_API_KEY` | clé API Web/Android du projet |
| `FIREBASE_APP_ID_ANDROID` | identifiant d'appli Android (`1:…:android:…`) |
| `FIREBASE_APP_ID_IOS` | identifiant d'appli iOS (`1:…:ios:…`), vide sinon |
| `FIREBASE_MESSAGING_SENDER_ID` | numéro du projet |
| `FIREBASE_PROJECT_ID` | identifiant du projet |
| `FIREBASE_STORAGE_BUCKET` | facultatif | Le dépôt n'est pas à renseigner : le workflow
utilise celui où il tourne, et déclare lui-même les droits dont il a besoin
(rien à changer dans les réglages Actions du dépôt).

Ne jamais ajouter `-v` (ou `--verbose`) à l'étape de build du workflow : un
build verbeux affiche ses `--dart-define`, donc les secrets, dans les journaux.

## 4. Le premier build, installé à la main

1. Onglet **Actions** → **ONSET update** → **Run workflow** (branche `main` ; sur
   une autre branche, rien n'est publié).
2. Une fois terminé, la release **ONSET build N** apparaît dans **Releases**.
3. Avec une clé dédiée : désinstallez l'appli actuelle.
4. Installez ce premier APK à la main, une seule fois (l'appli actuelle ne peut
   pas le trouver seule) : sur la tablette, ouvrez la page de la release dans le
   navigateur (**connecté à GitHub** si le dépôt est privé), téléchargez
   `onset-arm64.apk` et ouvrez-le.

Ensuite, chaque push sur `main` (hors `docs/` et fichiers `.md`) produit
une release que l'appli propose d'elle-même.

## 5. Ce que l'on voit sur la tablette

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
`pubspec.yaml` (68) est bien inférieur aux builds CI (1001 et plus), et
`flutter run` n'accepte pas `--build-number` : on construit donc l'APK avec le
bon numéro, puis on le lance.

Ce numéro est **celui du dernier build CI installé** (release `build-1023` →
`1023`), pas plus : un numéro supérieur empêcherait l'appli de proposer les
builds CI suivants tant qu'ils ne l'ont pas dépassé.

Avec la clé de debug du PC (alternative de l'étape 1) :

```powershell
flutter build apk --debug --build-number=1023 --dart-define=CLIENT_ID=<id> --dart-define=SECRET=<secret>
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
flutter build apk --release --build-number=1023 --dart-define=CLIENT_ID=<id> --dart-define=SECRET=<secret>
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

Un build local sans `UPDATE_REPO` ne propose aucune mise à jour : le build CI
suivant devra être installé à la main (étape 4), sauf si vous ajoutez
`--dart-define=UPDATE_REPO=JLmehdi92/onset` à la commande de build (plus
`--dart-define=UPDATE_TOKEN=<jeton>` si le dépôt est privé ; ne partagez alors
jamais cet APK).

## 7. Liste du 1er novembre (passage au dépôt public `JLmehdi92/onset`)

Dans cet ordre :

1. **Twitch** : console développeur Twitch → l'application → **New Secret**,
   puis mettez à jour le secret `SECRET` du dépôt (l'ancien a pu sortir dans un
   APK public).
2. **Jeton GitHub** : révoquez `UPDATE_TOKEN` (Developer settings → Personal
   access tokens → le jeton → **Delete**) **avant** de rendre un dépôt public
   (étape 0), et supprimez le secret du dépôt. Ne le recréez (étape 2, limité
   au seul dépôt de build) que si les builds repartent d'un dépôt **privé** :
   un dépôt public n'en a pas besoin.
3. Vérifiez qu'aucune release faite en privé n'est restée dans un dépôt
   public (étape 0).
4. **Lancez le build** : **Actions** → **ONSET update** → **Run workflow** sur
   `main`. Dans un dépôt public, le journal affiche « The build carries no
   update token (event or repository is public). »
5. **Désinstallez l'ancienne appli** `com.tommychow.frosty.onset` (réglages
   Android → Applications). Ses données (connexion Twitch, réglages) ne
   passent pas à la nouvelle : un autre identifiant d'appli est une autre
   appli pour Android.
6. **Installez `app.onset`** à la main depuis la page de la release (étape 4),
   reconnectez-vous à Twitch. Les builds suivants arrivent ensuite d'eux-mêmes,
   sans jeton.
