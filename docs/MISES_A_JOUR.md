# Mises à jour dans l'appli — mise en place (une seule fois)

À chaque push sur `main`, GitHub Actions (workflow **ONSET update**,
`.github/workflows/onset-update.yml`) construit un APK arm64 signé et le publie
comme release `build-N` du dépôt privé (N = 1000 + numéro d'exécution). L'appli
installée vérifie la dernière release au démarrage et au retour au premier plan
(au plus toutes les 6 h tant qu'elle est à jour), affiche « Update available »,
télécharge l'APK, vérifie son SHA-256 et le confie à l'installeur d'Android.
**Réglages → Check for updates** force une vérification.

Les builds locaux sans `UPDATE_TOKEN` ne vérifient jamais rien : la fonction
n'existe que dans les APK produits par le workflow (voir l'étape 6 pour les
builds locaux).

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

## 2. Le jeton GitHub en lecture seule

github.com → photo de profil → **Settings** → **Developer settings** →
**Personal access tokens** → **Fine-grained tokens** → **Generate new token** :

- **Repository access** : *Only select repositories* → uniquement
  `JLmehdi92/frostyv2-lab` ;
- **Permissions** → **Repository permissions** → **Contents** : *Read-only*
  (rien d'autre) ;
- **Expiration** : 1 an (préférable à *No expiration*). À l'expiration, seules
  les mises à jour s'arrêtent : nouveau jeton, mise à jour du secret, nouveau
  build, installé une fois à la main (étape 4).

**L'APK contient des secrets en clair** — ce jeton, mais aussi `CLIENT_ID` et
`SECRET` de Twitch — et n'importe qui peut les en extraire :

- le jeton lit **tout le code** du dépôt et **tous les APK** de ses releases ;
- si le dépôt devient public un jour, tous les APK publiés (et donc ces
  secrets) le deviennent aussi ;
- ne partagez donc jamais l'APK ; s'il fuite, révoquez le jeton (et créez-en un
  nouveau) **et** régénérez le secret client dans la console développeur
  Twitch, puis mettez à jour les secrets du dépôt.

## 3. Les secrets du dépôt

`JLmehdi92/frostyv2-lab` → **Settings** → **Secrets and variables** →
**Actions** → **New repository secret**, pour chacun :

| Secret | Valeur |
|---|---|
| `CLIENT_ID` | l'identifiant client Twitch (comme pour `--dart-define`) |
| `SECRET` | le secret client Twitch |
| `UPDATE_TOKEN` | le jeton de l'étape 2 |
| `ANDROID_KEYSTORE_BASE64` | le keystore encodé à l'étape 1 |
| `ANDROID_KEYSTORE_PASSWORD` | mot de passe du keystore |
| `ANDROID_KEY_ALIAS` | alias de la clé (`onset` avec la commande ci-dessus) |
| `ANDROID_KEY_PASSWORD` | mot de passe de la clé |

Si l'un d'eux manque, le workflow s'arrête tout de suite en le nommant (sans
jamais afficher de valeur). Le dépôt n'est pas à renseigner : le workflow
utilise celui où il tourne, et déclare lui-même les droits dont il a besoin
(rien à changer dans les réglages Actions du dépôt).

Ne jamais ajouter `-v` (ou `--verbose`) à l'étape de build du workflow : un
build verbeux affiche ses `--dart-define`, donc les secrets, dans les journaux.

## 4. Le premier build, installé à la main

1. Onglet **Actions** → **ONSET update** → **Run workflow** (branche `main` ; sur
   une autre branche, rien n'est publié).
2. Une fois terminé, la release **ONSET build N** apparaît dans **Releases**.
3. Avec une clé dédiée : désinstallez l'appli actuelle.
4. Installez ce premier APK à la main, une seule fois (l'appli actuelle n'a pas
   le jeton, elle ne peut pas le trouver seule) : sur la tablette, ouvrez la page
   de la release dans le navigateur **connecté à GitHub** (le dépôt est privé),
   téléchargez `onset-arm64.apk` et ouvrez-le.

Ensuite, chaque push sur `main` (hors `docs/`, fichiers `.md` et `web/`) produit
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

Un build local sans `UPDATE_TOKEN` ne propose aucune mise à jour : le build CI
suivant devra être installé à la main (étape 4), sauf si vous ajoutez
`--dart-define=UPDATE_TOKEN=<jeton> --dart-define=UPDATE_REPO=JLmehdi92/frostyv2-lab`
à la commande de build.
