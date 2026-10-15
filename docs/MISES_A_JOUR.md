# Mises à jour dans l'appli — mise en place (une seule fois)

À chaque push sur `main`, GitHub Actions (workflow **ONSET update**,
`.github/workflows/onset-update.yml`) construit un APK arm64 signé et le publie
comme release `build-N` du dépôt privé. L'appli installée vérifie la dernière
release au démarrage et au retour au premier plan (au plus toutes les 6 h),
affiche « Update available », télécharge l'APK, vérifie son SHA-256 et ouvre
l'installeur Android. **Réglages → Check for updates** force une vérification.

Les builds locaux (sans `UPDATE_TOKEN`) ne vérifient jamais rien : la fonction
n'existe que dans les APK produits par le workflow.

## 1. La clé de signature (keystore)

Android n'accepte une mise à jour que si elle est signée avec **la même clé**
que l'appli installée. Deux choix :

- **Réutiliser la clé de debug du PC** (recommandé : la première mise à jour
  remplace l'appli installée par `flutter run` / `flutter build apk --debug`
  sans désinstaller, donc sans perdre la connexion Twitch ni les réglages) :
  - fichier : `%USERPROFILE%\.android\debug.keystore`
  - mot de passe du keystore : `android`
  - alias : `androiddebugkey`
  - mot de passe de la clé : `android`
- **Créer une clé dédiée** (une désinstallation sera nécessaire une fois, puis
  tout se met à jour normalement) :

  ```powershell
  keytool -genkeypair -v -keystore onset-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias onset
  ```

  Évitez les `\` dans les mots de passe. Gardez ce fichier et ses mots de
  passe en lieu sûr : sans eux, plus aucune mise à jour ne pourra s'installer
  par-dessus l'appli.

Encodez le fichier en base64 avec PowerShell (le résultat est copié dans le
presse-papiers, à coller dans le secret `ANDROID_KEYSTORE_BASE64`) :

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\.android\debug.keystore")) | Set-Clipboard
```

(remplacez le chemin par celui de `onset-release.jks` si vous avez créé une clé
dédiée).

## 2. Le jeton GitHub en lecture seule

github.com → photo de profil → **Settings** → **Developer settings** →
**Personal access tokens** → **Fine-grained tokens** → **Generate new token** :

- **Repository access** : *Only select repositories* → uniquement
  `JLmehdi92/frostyv2-lab` ;
- **Permissions** → **Repository permissions** → **Contents** : *Read-only*
  (rien d'autre) ;
- **Expiration** : *No expiration* ou la plus longue possible (à l'expiration,
  l'appli ne trouvera plus de mise à jour : il faudra un nouveau jeton, un
  nouveau build, et l'installer à la main).

Ce jeton est inclus dans l'APK : quiconque obtient l'APK peut le lire et lire
ce dépôt. Ne partagez donc pas l'APK. Il ne peut rien modifier.

## 3. Les secrets du dépôt

`JLmehdi92/frostyv2-lab` → **Settings** → **Secrets and variables** →
**Actions** → **New repository secret**, pour chacun :

| Secret | Valeur |
|---|---|
| `CLIENT_ID` | l'identifiant client Twitch (comme pour `--dart-define`) |
| `SECRET` | le secret client Twitch |
| `UPDATE_TOKEN` | le jeton de l'étape 2 |
| `ANDROID_KEYSTORE_BASE64` | le keystore encodé à l'étape 1 |
| `ANDROID_KEYSTORE_PASSWORD` | mot de passe du keystore (`android` pour la clé de debug) |
| `ANDROID_KEY_ALIAS` | alias de la clé (`androiddebugkey` pour la clé de debug) |
| `ANDROID_KEY_PASSWORD` | mot de passe de la clé (`android` pour la clé de debug) |

Si l'un d'eux manque, le workflow s'arrête tout de suite en le nommant (sans
jamais afficher de valeur). Le dépôt n'est pas à renseigner : le workflow
utilise celui où il tourne.

## 4. Le premier build, installé à la main

1. Onglet **Actions** → **ONSET update** → **Run workflow** (branche `main`).
2. Une fois terminé, la release **ONSET build N** apparaît dans **Releases**.
3. Installez ce premier APK à la main, une seule fois (l'appli actuelle n'a pas
   encore le jeton, elle ne peut pas le trouver seule) : sur la tablette, ouvrez
   la page de la release dans le navigateur **connecté à GitHub** (le dépôt est
   privé), téléchargez `onset-arm64.apk` et ouvrez-le.

Ensuite, chaque push sur `main` (hors `docs/`, fichiers `.md` et `web/`) produit
une release que l'appli propose d'elle-même.

Si la création de la release échoue avec une erreur 403 : **Settings** →
**Actions** → **General** → **Workflow permissions** → *Read and write
permissions*.

## 5. Ce que l'on voit sur la tablette

1. Popup **Update available** : « ONSET build N is ready. » et le titre du
   commit. **Later** la fait taire 24 h pour ce build (un build plus récent
   reprend la main) ; **Update** lance la mise à jour.
2. La première fois seulement : Android demande d'autoriser ONSET à installer
   des applis → **Open settings** → activer *Autoriser cette source* → revenir
   dans ONSET, le téléchargement démarre.
3. Barre de progression (Mo téléchargés / total), annulable.
4. L'installeur Android s'ouvre → **Mettre à jour** → **Ouvrir**.

En cas d'échec : « Download failed » (réseau), « The download was corrupted —
try again » (SHA-256 différent : le fichier est supprimé, rien n'est installé).
Si Android refuse l'installation, c'est que l'APK n'est pas signé avec la même
clé que l'appli installée (voir l'étape 1).
