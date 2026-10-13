# frostyv2 — Architecture (Phase 1)

> Analyse en lecture seule de `frostyv2` @ `bb2d838` (« keep chat alive across the mini player and pip »), copiée dans `frostyv2-lab`.
> Toutes les références `fichier:ligne` sont relatives à la racine du repo à ce commit.

## 0. Points d'attention majeurs

| # | Constat | Impact |
|---|---|---|
| 1 | **Aucune DA « ONSET » n'existe dans le code** (ni `lib/`, ni `docs/`, ni l'historique git, ni la branche `low-latency-player`). La DA réelle est le thème Frosty : Material 3 seedé sur un accent (défaut `#9146FF`) + police Inter + kit `lib/widgets/`. | Bloquant pour la Phase 5 : la source de vérité ONSET (Figma, doc, autre repo ?) doit être fournie. |
| 2 | **Aucun outil de modération actif.** Seul l'affichage passif existe (CLEARCHAT/CLEARMSG → « Timed out / Banned / Message deleted »). Aucun scope `moderator:*`. | Toute la modération active est à construire. |
| 3 | **7TV = emotes uniquement** (+ mises à jour live via EventAPI). Pas de badges 7TV (code présent mais map jamais remplie), pas de paints. | Badges/paints 7TV à ajouter (hors Twitch officiel, mais exigence « pas de régression 7TV »). |
| 4 | Le moteur par défaut est **Amazon IVS** (natif Android). Sur iOS, il n'y a aucun code IVS → spinner infini sans fallback. | Viole la règle « iOS-compatible » de `CLAUDE.md`. |
| 5 | Toute erreur IVS (même récupérable) bascule définitivement sur la WebView pour la session. | Risque de régression de latence silencieuse. |
| 6 | `showLatency` est `false` par défaut, alors que `CLAUDE.md` exige une latence visible pour la mesure. | À activer pour les mesures avant/après. |
| 7 | Plusieurs fichiers sont en CRLF (`pubspec.yaml`, `channel.dart`, `auth_store.dart`, `AndroidManifest.xml`…). | Attention aux diffs de fichiers entiers. |

## 1. Stack

- **Flutter 3.38.4 / Dart 3.10.3**, épinglés (`CLAUDE.md` : 3.44+ casse `extended_text_field`/`simple_icons`, 3.35 casse `app_links`). `pubspec.yaml` : `sdk: ^3.9.0`, version `5.0.5+68`.
- **État** : `mobx` 2.6.0 / `flutter_mobx` 2.3.0 (+ `mobx_codegen`, `build_runner`) ; DI via `provider` 6.1.5.
- **Réseau** : `dio` 5.9.2 (client partagé `DioClient.createClient()`), `web_socket_channel` 3.0.3 (IRC, 7TV EventAPI).
- **Vidéo** :
  - Amazon IVS Player `com.amazonaws:ivs-player:1.52.0` (dépendance Gradle, `android/app/build.gradle.kts:65`) — moteur par défaut.
  - `media_kit` 1.2.6 / `media_kit_video` 2.0.1 (libmpv) — moteur « nativeLowLatency ».
  - `webview_flutter` 4.13.1 — lecteur web Twitch (fallback).
  - `simple_pip_mode` (git, `tommyxchow/simple_pip_mode_flutter@0da5255`), `wakelock_plus`, `native_device_orientation`.
- **Stockage** : `flutter_secure_storage` (tokens), `shared_preferences` (réglages JSON, dernière qualité), `flutter_cache_manager` / `cached_network_image`.
- **Firebase** : core, crashlytics, performance, analytics (configs commitées).
- **Divers** : `app_links` (deep links), `extended_text_field` (saisie chat avec emotes inline), `photo_view`, `flutter_markdown_plus`, `advanced_in_app_review`.
- **Tests** : `mocktail`, `http_mock_adapter`.

### Android
- `applicationId`/`namespace` : `com.tommychow.frosty` ; `minSdk = max(flutter.minSdk, 23)` (exigence IVS) ; Java/JVM 17 ; AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14.
- `MainActivity` : `singleTop`, `supportsPictureInPicture="true"`, deep links auto-vérifiés `twitch.tv`, `www.twitch.tv`, `m.twitch.tv`.
- Kotlin natif (`android/app/src/main/kotlin/com/tommychow/frosty/`) :
  - `MainActivity.kt` — étend `PipCallbackHelperActivityWrapper`, enregistre la PlatformView `frosty/ivs-player` et le `IvsTextureManager`.
  - `IvsPlayerCore.kt` — pont contrôle/événements IVS (play, pause, setAutoQuality, setQuality, load ; événements state/qualities/error/rebuffering/quality/latency).
  - `IvsTexturePlayer.kt` — rendu IVS dans une texture Flutter (`SurfaceProducer`), canal `frosty/ivs-texture-manager` (`create {url}` → textureId, `dispose`).
  - `IvsPlayerView.kt` — SurfaceView, **code mort** (plus utilisé).

### iOS
- Projet présent (iOS 15.0), `AppDelegate.swift` n'enregistre que les plugins. **Aucun lecteur natif iOS.**

## 2. Architecture applicative

```
lib/
  apis/            services HTTP (tous étendent BaseApiClient) + intercepteurs Dio
  models/          modèles @JsonSerializable (+ .g.dart commités), hls_variant.dart manuel
  screens/
    channel/       écran chaîne : video/, chat/ (stores co-localisés)
    home/          Following / Top / Search / catégories (stores co-localisés)
    onboarding/
    settings/      réglages + auth_store, settings_store, user_store
  stores/          stores globaux : global_assets_store, mini_player_store
  services/        shared_timer_service
  widgets/         kit UI partagé (dont global_mini_player)
  utils/ utils.dart constants.dart theme.dart cache_manager.dart
  dev_player_harness.dart   point d'entrée de test du lecteur mpv (sans identifiants)
```

### Démarrage (`lib/main.dart`)
1. `MediaKit.ensureInitialized()` (l.44) → Firebase + Crashlytics (l.48-57).
2. Premier lancement : `FlutterSecureStorage().deleteAll()` (l.66-77) — contournement Android/iOS, **à ne pas supprimer** (AGENTS.md).
3. `SettingsStore.fromJson(prefs['settings'])` (l.86) + `autorun` de persistance (l.102) : chaque observable modifié est resérialisé.
4. Dio partagé (l.106) → services → `GlobalAssetsStore`, `AuthStore` → intercepteurs `TwitchAuthInterceptor` / `UnauthorizedInterceptor` (l.126-129) → `authStore.init()`.
5. `MultiProvider` (l.137-151) : AuthStore, SettingsStore, TwitchApi, BTTVApi, FFZApi, SevenTVApi, GlobalAssetsStore, MiniPlayerStore. Raccourcis dans `lib/utils/context_extensions.dart`.

### Navigation
- `Navigator` impératif + `MaterialPageRoute` (pas de package de routage), `navigatorKey` global (`main.dart:155`).
- `home` = `OnboardingIntro` (premier lancement) ou `Home` : `IndexedStack` + `NavigationBar` Following / Top / Search (`lib/screens/home/home.dart:140-160`).
- `MaterialApp.builder` superpose `GlobalMiniPlayer` à toutes les routes (`main.dart:209-214`).
- Deep links : `app_links` → `handleDeepLink` → `getUser` → `VideoChat` (`main.dart:241-298`).

### Stores (MobX, mixin généré `Foo = FooBase with _$Foo`)
- Globaux : `GlobalAssetsStore`, `MiniPlayerStore`.
- Réglages : `screens/settings/stores/{auth_store,settings_store,user_store}.dart` (exemple canonique : `auth_store.dart`).
- Chat : `screens/channel/chat/stores/{chat_tabs_store,chat_store,chat_assets_store}.dart`, `chat/details/chat_details_store.dart`.
- Vidéo : `screens/channel/video/video_store.dart` (WebView), `video/stores/{ivs_video_store,native_video_store}.dart`.
- Home : `home_store`, `stream_list_store`, `search_store`, `categories_store`.

### Couche API (`lib/apis/base_api_client.dart`)
`BaseApiClient` fournit `get/post/put/delete<T>` génériques (l.65-150), accepte les URL absolues (l.55) et mappe `DioException` → `ApiException` (Network, Timeout, Server, NotFound, Unauthorized ; l.160-258).

| Service | Base | Endpoints |
|---|---|---|
| `TwitchApi` | `https://api.twitch.tv/helix` | `/chat/emotes/global`, `/chat/emotes`, `/chat/emotes/set`, `/chat/badges/global`, `/chat/badges`, `/chat/color` (GET/PUT), `/users`, `/users/blocks` (GET/PUT/DELETE), `/streams` (top, login, ids, game), `/streams/followed`, `/channels/followed`, `/channels`, `/search/channels`, `/games/top`, `/games`, `/search/categories`, `/subscriptions`, `/shared_chat/session` ; OAuth `id.twitch.tv/oauth2/token` (client_credentials), `/oauth2/validate` ; `recent-messages.robotty.de/api/v2/recent-messages/{login}` |
| `TwitchStreamService` | `https://gql.twitch.tv/gql` + `usher.ttvnw.net` | `PlaybackAccessToken_Template` (Client-ID web public, requête complète, pas de hash persisté) ; URL usher `api/channel/hls/{login}.m3u8` |
| `BTTVApi` | `https://api.betterttv.net/3/cached` | `/emotes/global`, `/users/twitch/{id}`, `/badges` |
| `FFZApi` | `https://api.frankerfacez.com/v1` | `/set/global`, `/room/id/{id}`, `/badges/ids` |
| `SevenTVApi` | `https://7tv.io/v3` | `/emote-sets/global`, `/users/twitch/{id}` |

- **IRC** : pas un service ; `ChatStore.connectToChat` ouvre `wss://irc-ws.chat.twitch.tv:443` (`chat_store.dart:897`), `CAP REQ :twitch.tv/tags twitch.tv/commands`, `PASS`, `NICK` (`justinfan888` en anonyme), `JOIN`.
- **7TV EventAPI** : `wss://events.7tv.io/v3`, souscription `emote_set.update` (`chat_store.dart:797-881`).
- **Aucun EventSub ni PubSub.**
- Intercepteurs : `TwitchAuthInterceptor` (Bearer + Client-Id pour Helix/OAuth seulement), `UnauthorizedInterceptor` (401 → dialogue de reconnexion).

### Authentification (`lib/screens/settings/stores/auth_store.dart`)
- OAuth implicit grant dans une WebView (`id.twitch.tv/oauth2/authorize`, `response_type=token`, `redirect_uri=https://twitch.tv/login`), user-agent navigateur pour la connexion Google.
- Scopes : `chat:read chat:edit user:read:follows user:read:blocked_users user:manage:blocked_users user:manage:chat_color` (l.155-169).
- Tokens dans `FlutterSecureStorage` (`user_token`, `default_token`) ; anonyme = app token client_credentials (nécessite `--dart-define=SECRET`).
- `init()` valide le token ; boucle de reconnexion 10 s × 5 en cas d'erreur réseau (l.323-363).

### Réglages (`lib/screens/settings/stores/settings_store.dart`)
Un seul store MobX `@JsonSerializable`. Ajout du fork : `playerEngine` (défaut `PlayerEngine.ivs`, enum `{ivs, nativeLowLatency, twitchWeb}`, l.69, 93-98, 429-442). `syncedChatDelay` exclu du JSON, `effectiveChatDelay` calculé (l.226-231).

## 3. Lecture vidéo basse latence

### Sélection du moteur (`lib/screens/channel/channel.dart`)
- `_buildPlayerController` (l.116-148) : IVS → `IvsVideoStore` (ou adoption du store du mini-player si même chaîne, l.118-130) ; `nativeLowLatency` → `NativeVideoStore` ; sinon `VideoStore` (WebView).
- Fallback runtime (l.164-177) : `fallbackToWeb()` reconstruit avec `forceWeb: true` (déclenché par `ready.catchError` et `IvsVideoStore.onFatalError`).
- Les 3 moteurs implémentent `PlayerController` (`video/player_controller.dart`), consommé par l'overlay.
- UI : un seul interrupteur IVS ↔ web (`settings/video_settings.dart:25-32`). mpv non sélectionnable dans l'UI.

### Moteur IVS (défaut)
- `IvsVideoStore` (`ivs_video_store.dart:104-130`) : remet le délai de chat synchronisé à zéro, `ready = _resolveUrl()` (usher via un `Dio()` dédié), `_createTexture()` (l.164-172), auto-PiP Android.
- **URL usher** (`twitch_stream_service.dart:60-80`) : `allow_source=true`, `fast_bread=true`, `low_latency=true`, `supported_codecs=av1,h265,h264` (= support 2K/HEVC/AV1, commit `b2e90a0`), `p` aléatoire, `sig`, `token`, `player=twitchweb`, `type=any`. Le token GQL est demandé avec `platform:"web"`, `playerBackend:"mediaplayer"`, `playerType:"embed"` (l.98-123).
- **Natif** (`IvsPlayerCore.kt`) : `setLiveLowLatencyEnabled(true)`, `setRebufferToLive(true)` (l.81-86) ; ticker de latence `player.liveLatency` toutes les 1 s (l.92-100) ; lecture auto à READY. Pas de logique maison de rattrapage du direct ni de vitesse de lecture : IVS gère seul.
- **Dart** (`ivs_video_store.dart:174-208`) : qualités `['Auto', …]` ; latence arrondie à la seconde, bornée 0-60 s, affichée « Ns », et recopiée dans `syncedChatDelay` si la synchro auto est active ; toute erreur → `onFatalError` → WebView.
- Qualité : non restaurée au démarrage (démarre sur Auto ; `defaultToHighestQuality` / `last_stream_quality` ignorés). Refresh = nouvelle URL usher + `load` (l.233-246).
- **Pas de gestion des pubs**, quel que soit le moteur.
- Rendu : `IvsTextureVideo` (`ivs_video.dart:39-96`). Fit/fill par `LayoutBuilder` + `ClipRect`/`OverflowBox`/`SizedBox(Texture)` (un `FittedBox` autour d'une `Texture` rend noir). Bouton « tablette » en paysage, IVS uniquement (`video_overlay.dart:115-135, 383`).

### Moteur mpv (`video/stores/native_video_store.dart`)
`Player(bufferSize: 8 MiB)` ; `cache=no`, `demuxer-readahead-secs=0`, `demuxer-lavf-o=live=1`, `video-sync=display-resample`, `hwdec=mediacodec-copy` (l.144-157) ; parse la playlist maître (`models/hls_variant.dart`) et ouvre la variante voulue ; latence ≈ `duration - position` ; pas de PiP.

### Moteur WebView (`video/video_store.dart`, `video.dart`)
`https://player.twitch.tv/?channel=$login&muted=false&parent=frosty` (l.212) ; JS injecté (file d'attente de promesses, `_asyncQuerySelector`, l.711-843) ; CSS masquant l'overlay Twitch (l.430-455) ; qualités lues dans le menu Twitch (l.348-424) ; latence lue dans les statistiques vidéo toutes les 60 s (l.494-648) ; appui long = overlay Twitch ↔ overlay custom.

### Overlay et latence (`video/video_overlay.dart`)
Retour, chat en overlay (paysage), fit/fill, qualité (l.137-185), refresh (l.187-198), plein écran immersif (l.200-229), rotation (l.231-250), PiP (l.521-544), badge de latence si `showLatency` (l.487-516, **désactivé par défaut**).

### Mise en page (`channel.dart`)
Portrait : vidéo 16:9 au-dessus du chat (l.806-836). Paysage (l.576-805) : chat en colonne (gauche/droite, largeur ajustable par `DraggableDivider`) ou en overlay plein écran ; double-tap = overlay → colonne → masqué (l.407-421) ; UI système immersive (l.315-332) ; remplissage de l'encoche.

### Mini-player et PiP
- Glisser la vidéo vers le bas (≥ 80 px ou vitesse > 600, l.211-266) → `_minimizeToMiniPlayer` : le `IvsVideoStore` **et** le `ChatTabsStore` vivants sont confiés à `MiniPlayerStore.adopt` (`stores/mini_player_store.dart:40-58`), l'écran se ferme sans dispose.
- `GlobalMiniPlayer` (`widgets/global_mini_player.dart`) : 42 % de la largeur, 16:9, déplaçable (`ValueNotifier` + `Transform.translate`), aimanté aux coins, tap = retour à `VideoChat`, enveloppé dans un `PipWidget` pour le PiP système.
- PiP système sur l'écran chaîne : `PipWidget` (`channel.dart:844-858`) ; auto-PiP Android 12+ uniquement pour IVS.

### Rediffusions (VOD) — `lib/screens/vod/`
- **Données** (`apis/twitch_vod_service.dart`) : GQL anonyme (Client-ID web public, documents complets, `Dio` dédié sans intercepteur d'auth). Liste des vidéos d'une chaîne (100 plus récentes, sans curseur : la pagination par curseur est bloquée par l'intégrité pour les anonymes), `video(id)`, commentaires par offset (~50 par page), segments muets, jeton VOD → usher `/vod/<id>.m3u8` (mêmes `supported_codecs=av1,h265,h264` que le live → 2K). `diagnoseVodPlaylist` (hôte usher uniquement) traduit un refus en abonnés-seulement / géobloqué / introuvable.
- **Lecture** : `IvsVodStore` (`stores/ivs_vod_store.dart`) sur le même lecteur natif en mode VOD (`IvsTuning.vod` : pas de faible latence ; `seekTo`, `setPlaybackRate`, `getPosition`, ticker de progression 250 ms, seek de départ au premier READY). Une seule « position de départ voulue » protège la reprise (ticks à 0 avant READY, rechargements, seeks pendant le chargement). Reprise d'erreurs via `IvsRecoveryPolicy` ; « non disponible » → diagnostic usher. Repli `WebVodStore` (`stores/web_vod_store.dart`, embed `player.twitch.tv/?video=…` dans une WebView, `<video>` interrogé chaque seconde) sur iOS, avec le réglage « Twitch web », ou après un échec natif. Les deux implémentent `VodPlayerController`.
- **Replay du chat** : `VodChatReplayStore` piloté par la seconde de lecture ; `VodCommentCache` (couverture par plages, éviction), prefetch 15 s × vitesse, espacement des requêtes, gel « indisponible » sur refus d'intégrité. Chaque commentaire devient un `IRCMessage` (`vod_comment_to_irc.dart`, `IRCMessage.fromString` inchangé) : badges, couleurs, emotes Twitch et 7TV/BTTV/FFZ (sets actuels de la chaîne) rendus comme en live ; utilisateurs bloqués et mots masqués filtrés.
- **Écran** (`vod_screen.dart`, `vod_overlay.dart`, `widgets/`) : portrait (16:9 + infos + replay) et paysage (chat latéral redimensionnable ou overlay plein écran, double-tap central = cycle des modes comme en live), ±10 s, double-tap gauche/droite, vitesse 0,5-2×, qualité, volume, PiP, fit/fill, lien au timecode. `PlaybackFocus` (`services/playback_focus.dart`) : un seul lecteur audible (le live sous une VOD se met en pause et reprend au retour) ; `reclaimPipCallbacks` rend les événements PiP à l'écran revenu au premier plan.
- **Reprise** (`vod_resume.dart`) : position locale (SharedPreferences, 300 vidéos), sauvegardée toutes les 20 s, à la pause, en arrière-plan et à la sortie ; reprise à −30 s, un `?t=` l'emporte. Barre de progression et « Vu » dans les listes.
- **Accès** : liste `ChannelVideosScreen` (onglets Rediffusions / Temps forts / Uploads) depuis l'overlay live et hors ligne, l'app bar du mode chat seul, la fiche utilisateur du chat et le menu d'actions utilisateur ; liens `twitch.tv/videos/<id>`, `/v/<id>`, `/<chaîne>/v/<id>`, `?t=` et `/<chaîne>/videos?filter=` ouverts dans l'appli depuis le chat (`utils/link_router.dart`) et les App Links (`main.dart`), jamais dans le navigateur.

### Temps réel (Hermes) — `lib/services/realtime/`
- **Client** `TwitchRealtimeClient` (fourni dans `main.dart`, `context.realtimeClient`) : une seule connexion WebSocket anonyme à `wss://hermes.twitch.tv/v1?clientId=<web public>` pour les sujets PubSub publics, séparée du chat et de la vidéo (une panne n'atteint que les abonnés du sujet, sous forme de `RealtimeUnavailable`).
- **Cycle de vie** : connexion paresseuse au premier abonnement, sujets comptés (désabonnement différé de 500 ms), chien de garde keepalive + 5 s, reconnexion 1/2/4/8/16/30 s ±20 % (immédiate après une session saine), réabonnement de tous les sujets (`RealtimeSubscribed(isResubscribe)` → le consommateur recharge son état), fermeture après 30 s sans sujet, pause après 60 s en arrière-plan. Codes fatals (4010, 411x, 412x, 4130/4131) → arrêt, nouvel essai au plus toutes les 5 min. Trames `reconnect` limitées à une immédiate par 30 s.
- **Protocole** (`hermes_protocol.dart`) : décodage qui ne lève jamais, trames ≤ 256 Ko, keepalive borné à 1-120 s ; les sujets liés à un compte sont refusés côté client.

### Hype Train — `lib/screens/channel/hype_train/`
- **Données** : `TwitchHypeTrainService` (GQL anonyme, même `Dio` sans auth que les VOD) donne l'instantané (`GetHypeTrainExecution`, document allégé sans `levels`), les récompenses à venir (paresseux) et les statuts pour les cartes (`allActiveHypeTrainStatuses`, par 100). Événements temps réel : sujet `hype-train-events-v2.<channelId>` (`models/hype_train_event.dart`). Faits vérifiés : `data.id` est l'id du train (le même qu'en GQL), `sequence_id == total`, montée de niveau et progression dans les deux ordres, `time_to_expire` en ms epoch.
- **Logique pure** : réducteur (`hype_train_reducer.dart` : déduplication `trainId:sequence`, report d'une progression du niveau suivant, transitions record/trésor/communauté), file (`hype_train_queue.dart` : regroupement des rafales, plafond 100), planificateur de séquences (`hype_train_sequence.dart` + `hype_train_timings.dart`, minutages de l'appli officielle ; modes compact, réduction des animations, présentateur invisible), maths (`hype_train_math.dart`), horloge serveur (`hype_train_clock.dart`, médiane des 5 derniers décalages).
- **Store** `HypeTrainStore` (`stores/`) : un par chaîne principale (D2), créé par `channel.dart` si le réglage « Show Hype Trains » est actif, détruit à la sortie (jamais dans le mini-lecteur, D17). Instantané au démarrage, au réabonnement et au retour de l'appli (une requête à la fois, ≥ 2 s d'écart, aucune perdue) ; sondage toutes les 20 s si le temps réel tombe (D12) ; fin synthétisée à expiration + 10 s (D5), annulée si le train bouge encore ; événements d'un autre train ignorés (rechargement).
- **Interface** (`widgets/`) : `HypeTrainSlot` au-dessus du chat (placement par `hypeTrainPlacement` : bannière complète, compacte en paysage, pastille sur la vidéo quand le chat est masqué, rien avec le clavier en paysage), bannière (niveau, étape en cours, barre, %, minuteur), pastille réduite, bannière d'approche, bandes de fin 20 s, feuille détaillée (variante, objectif de niveau D6, conducteurs, récompenses verrouillées/débloquées/à venir, record, guide), effets peints sans assets (`effects/` : pièce, fusée, arc-en-ciel, trophée, roulette Mythic, fusion). Couleurs du thème Frosty, contraste ≥ 4,5:1, sémantique (un libellé, régions live), RTL. Aucun bouton d'achat (D4). Pastille de niveau sur les cartes des chaînes suivies.
- **Outil** : `lib/dev_hype_train_harness.dart` (`flutter run -t …`, non livré) — trains actifs en direct et scénarios rejoués.

## 4. Chat

- **Connexion IRC** (`chat_store.dart`) : reconnexion ×5 avec backoff 0/1/2/4/8 s, notices de compte à rebours, action « Reconnect » ; `RECONNECT` non géré explicitement ; buffer flushé toutes les 200 ms ; historique plafonné à 5000 (purge de 20 %) ; 100 derniers messages rendus en autoscroll ; pastille « N new messages ».
- **Parsing** (`lib/models/irc.dart`, `IRCMessage.fromString` l.950-1154) : PRIVMSG, CLEARCHAT, CLEARMSG, NOTICE, USERNOTICE, ROOMSTATE, USERSTATE, GLOBALUSERSTATE ; emotes Twitch par plages, `/me`, mentions, emojis.
- **Rendu** (`generateSpan` l.651-715) : horodatage, marqueur historique, avatar de la chaîne source (shared chat), badges, pseudo avec couleur ajustée au contraste, emotes (zero-width empilées), liens, mentions cliquables. Fiche emote/badge (copier nom/URL, ouvrir, zoom).
- **Emotes** : Twitch (global, chaîne bits/follower/sub, sets utilisateur), 7TV (global + chaîne, zero-width via flag 256, AVIF ignoré, alias), BTTV (global + chaîne + partagées, liste zero-width codée en dur), FFZ (global + room). Les emotes de chaîne priment sur les globales.
- **7TV live** : EventAPI v3, `emote_set.update` → ajout/retrait + message système, respecte le délai de chat. Limites : seul `.first` de pushed/pulled traité, `updated` (renommage) ignoré, pas de `user.update` (changement de set actif), pas de heartbeat/resume/reconnexion du socket 7TV.
- **Badges** : Twitch, FFZ (badge Bot remplace Moderator, badges mod/VIP custom), BTTV (SVG). 7TV : rendu codé mais jamais alimenté.
- **Modération (affichage passif)** : CLEARMSG → message marqué supprimé ; CLEARCHAT global → « Chat was cleared by a moderator » ; CLEARCHAT ciblé → tous les messages de l'utilisateur marqués avec `ban-duration`. Rendu (`chat_message.dart:342-403`) : opacité 50 %, en-tête « Message deleted » / « Permanently banned » / « Timed out for N seconds », corps `<message deleted>` révélable au tap, réglage « Show deleted messages ». Pas de ligne système « X was timed out » si l'utilisateur n'a aucun message visible.
- **USERNOTICE** : subs, resubs, gifts, raids, Prime, annonces (couleur ignorée), messages surlignés (Channel Points) ; NOTICE en gris ; rejets de message (slow, r9k, AutoMod `msg_rejected`…) en toast.
- **Délai de chat** : fixe 0-30 s ou synchronisé sur la latence mesurée (IVS l.200, mpv l.123, WebView l.72/330) ; file d'attente avec heure de sortie, drainée toutes les 200 ms ; les messages d'état sautent le délai ; compte à rebours « Chat will sync in Ns ».
- **Envoi** : anti double envoi, confirmation via USERSTATE (timeout 10 s), `/me`, écho optimiste ; **les commandes slash partent en texte brut** (inopérantes depuis la fin des commandes IRC en 2023).
- **Réponses** : appui long → « Reply », tag `reply-parent-msg-id`, en-tête « ↳ parent », vue `ReplyThread`.
- **Autocomplétion** : emotes (sous-chaîne, tous fournisseurs) et `@mentions` (chatters vus).
- **Mentions / surlignage** : mention = barre rouge + teinte 10 % (détection par sous-chaîne → faux positifs) ; premier message = barre `#9146FF`. Pas de mots-clés de surlignage personnalisés.
- **Menu d'emotes** (`chat.dart:261-337`) : Récents (48 max), Twitch (par propriétaire, emotes sub grisées si non abonné), 7TV, BTTV, FFZ (Channel/Global).
- **Autres** : fiche utilisateur (historique dans la session, Reply, Block, Report via WebView), copier / copier-coller, filtre des bloqués, mots masqués (2 bugs : `return` qui coupe le lot, correspondance partielle via `split('')`), menu « More » (modes du salon en lecture seule, chat seul, rafraîchir emotes, reconnecter, couleur du pseudo (15 couleurs, Helix `/chat/color`), chatters (vus en IRC), ajouter un chat, minuteur de veille), **multi-chat** (10 onglets, réordonnables, persistables, vue fusionnée), **shared chat**.

## 5. Design system existant (thème Frosty — pas d'ONSET)

- `lib/theme.dart` : `FrostyThemes` M3 light/dark via `ColorScheme.fromSeed(accent)` ; fond clair `#F8F8F8`, sombre `#000000` (OLED de fait) ; mode Système/Clair/Sombre ; accent par défaut `#9146FF`, modifiable (sélecteur HSV + « Random »).
- `FrostyColors` (ThemeExtension, `context.frostyColors`) :

| Token | Clair | Sombre |
|---|---|---|
| highlightedMessage | `#9146FF` | `#9146FF` |
| emoteOnly | `#FFB74D` | `#FFCC80` |
| followersOnly | `#F44336` | `#E57373` |
| slowMode | `#2196F3` | `#64B5F6` |
| subOnly | `#4CAF50` | `#81C784` |
| uniqueMode | `#AB47BC` | `#BA68C8` |
| overlayOnSurface | `#FFFFFF` | `#FFFFFF` |

- Rôles : liens → `primary`, mentions → `error`. Constantes : badge mod `#00AD03`, `kOverlayShadow` (noir 30 %, flou 4, offset 0,1), bordures `outlineVariant` 50 % / 0.5 px, 15 couleurs de chat nommées (`constants.dart:55-90`).
- **Typographie** : Inter (9 graisses + italiques). `headlineSmall` 18/w600, `titleLarge` 24/w600, `titleSmall` 16/w600, `label*` w500, `bodyLarge` w500 ; letter-spacing négatif léger. Chat : police 12, badge 18 px, emote 28 px (ajustables).
- **Rayons** : carte/miniature 8 (`kCardBorderRadius`), menus/tooltip/snackbar 12, dialogues 16, champs « pill », mini-player 10.
- **Effets** : flou sigma 16, fond 0.6 (clair) / 0.3 (sombre) (`BlurredContainer`).
- **Composants** (`lib/widgets/`) : `BlurredContainer`, `FrostyDialog`, `FrostyNotification`, `AlertMessage`, `SectionHeader` / `ExpandableSectionHeader`, `SettingsPageLayout` + `SettingsList*`, `FrostyPageView`, `FrostyScrollbar`, `AnimatedScrollBorder`, `ScrollToTopButton`, `FrostyCachedNetworkImage`, `FrostyPhotoViewDialog`, `ProfilePicture`, `LiveIndicator`, `Uptime`, `SkeletonLoader*`, `LoadingIndicator`, `DraggableDivider`, `GlobalMiniPlayer`, `UserActionsModal`, `ThemeSelectionSetting`, `AccentColorSetting`, `FrostyAppBar`, `EmoteTextSpanBuilder`.

## 6. Inventaire fonctionnel (base de la gap analysis)

- **Shell** : onboarding (intro → login OAuth → réglages → bienvenue), notes de version auto, deep links, demande d'avis, navigation Following / Top / Search, avatar → Réglages.
- **Following** : lives suivis (pull-to-refresh, pagination), section épinglés, section hors-ligne repliable (« followed since »).
- **Cartes de stream** : miniature rafraîchie toutes les 5 min (zoom), uptime, titre, catégorie, spectateurs, appui long = épingler / bloquer / signaler, style compact/large, miniature on/off.
- **Top** : streams populaires, catégories populaires → page catégorie.
- **Recherche** : chaînes + catégories, historique (8), « Go to channel ».
- **Chaîne** : 3 moteurs (IVS, mpv, WebView), overlay complet, barre d'info, PiP système, mini-player in-app, paysage (colonne/overlay), chat seul, « My channel », réveil de l'écran, minuteur de veille.
- **Chat** : voir §4.
- **Réglages** : Compte (anonyme/connecté, utilisateurs bloqués, déconnexion), Général (thème, accent, cartes, miniatures, navigateur externe), Vidéo (IVS, vidéo on/off, plus haute qualité, rendu rapide, réveil, overlay custom, appui long, latence), Chat (tailles, apparence, délai, alertes, disposition, paysage, mots masqués, autocomplétion, fournisseurs d'emotes/badges, messages récents), Autre (notes de version, cache, reset, crash logs).
- **Absent** : follow/unfollow, notifications, whispers, abonnements/gifts/Turbo, multi-comptes, profil/à propos/panneaux, VODs, clips, highlights, planning, filtres tags/langue, recommandations, Bits, Channel Points, prédictions, sondages, Hype Train, Drops, modération active, mots-clés de surlignage, badges/paints 7TV, Chromecast, audio seul, streaming.

## 7. Tests

23 fichiers sous `test/` (~4800 lignes), uniquement des tests unitaires Dart. API : un fichier par service (`DioAdapter`, URL complètes). Modèles : badges, catégories, chaînes, chatters, emotes, events, IRC (635 lignes, `fixtures/irc_messages.dart`), shared chat, stream, user, `hls_variant`. Store : `settings_store_test.dart`. Aucun test pour `IvsVideoStore`, `NativeVideoStore`, `MiniPlayerStore`, le fallback de moteur, ni le Kotlin.

## 8. Commandes

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze && flutter test
flutter build apk --debug --dart-define=CLIENT_ID=<id> --dart-define=SECRET=<secret>
flutter run -t lib/dev_player_harness.dart        # harness mpv, sans identifiants
dart run scripts/get_twitch_token.dart             # token utilisateur pour émulateur
```

Les noms des `--dart-define` sont en majuscules (`CLIENT_ID`, `SECRET`) ; `AGENTS.md` se trompe sur ce point. La CI GitHub n'épingle pas Flutter. Le repo exécute `dart format` via un hook `.claude/settings.json` à chaque Edit/Write.
