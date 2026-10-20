# frostyv2 — Architecture (Phase 1)

> Analyse en lecture seule de `frostyv2` @ `bb2d838` (« keep chat alive across the mini player and pip »), copiée dans `frostyv2-lab`.
> Toutes les références `fichier:ligne` sont relatives à la racine du repo à ce commit.

## 0. Points d'attention majeurs

| # | Constat | Impact |
|---|---|---|
| 1 | ~~Aucune DA « ONSET » n'existe dans le code.~~ **Résolu** : la DA et les fonctions de l'appli ONSET (dépôt `JLmehdi92/onset`) ont été portées (`7c0b8e0`), voir §3 « Retour à ONSET » et §5. | — |
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
- **Hermes** (`lib/services/realtime/twitch_realtime_client.dart`) : WebSocket anonyme partagé pour les sujets publics (hype train, highlights).
- **EventSub WebSocket** (`lib/services/realtime/twitch_eventsub_client.dart`) : événements du compte connecté (whispers, `user.whisper.message`), abonnements créés par Helix pour chaque session, `session_reconnect` suivi sans perte, pause après une minute en arrière-plan. Branché dans `main.dart` avec le `WhisperStore` global (`lib/stores/whisper_store.dart`, en mémoire seulement).
- Intercepteurs : `TwitchAuthInterceptor` (Bearer + Client-Id pour Helix/OAuth seulement), `UnauthorizedInterceptor` (401 → dialogue de reconnexion).

### Authentification (`lib/screens/settings/stores/auth_store.dart`)
- OAuth implicit grant dans une WebView (`id.twitch.tv/oauth2/authorize`, `response_type=token`, `redirect_uri=https://twitch.tv/login`), user-agent navigateur pour la connexion Google.
- Scopes : `chat:read chat:edit user:read:follows user:read:blocked_users user:manage:blocked_users user:manage:chat_color moderator:manage:banned_users moderator:manage:chat_messages moderator:manage:chat_settings moderator:manage:warnings` (l.155-171). Les actions de modération passent par `ChatModeration` (`lib/screens/channel/chat/moderation.dart`) ; Helix décide des droits.
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
- **Données** (`apis/twitch_vod_service.dart`) : GQL anonyme (Client-ID web public, documents complets, `Dio` dédié sans intercepteur d'auth), sauf le jeton de lecture : demandé avec le jeton web twitch.tv du viewer (`webToken`, branché dans `main.dart` ; `Authorization: OAuth` vers gql.twitch.tv et cette requête seulement), repli anonyme sur toute erreur hors réseau, renouvellement sur 401 (`onWebTokenRejected`) et jeton web refusé plus renvoyé tant qu'il ne change pas. Cache par VOD et par compte (empreinte sha256, jamais le jeton), jeton refusé jamais gardé, `invalidateToken` après un refus usher, `preloadToken` pendant le chargement des labels. Labels de classification de la vidéo elle-même (`getContentLabels`). Liste des vidéos d'une chaîne (100 plus récentes, sans curseur : la pagination par curseur est bloquée par l'intégrité pour les anonymes), `video(id)`, commentaires par offset (~50 par page), segments muets, jeton VOD → usher `/vod/<id>.m3u8` (mêmes `supported_codecs=av1,h265,h264` que le live → 2K). `diagnoseVodPlaylist` (hôte usher uniquement) traduit un refus en abonnés-seulement / géobloqué / introuvable.
- **Lecture** : `IvsVodStore` (`stores/ivs_vod_store.dart`) sur le même lecteur natif en mode VOD (`IvsTuning.vod` : pas de faible latence ; `seekTo`, `setPlaybackRate`, `getPosition`, ticker de progression 250 ms, seek de départ au premier READY). Une seule « position de départ voulue » protège la reprise (ticks à 0 avant READY, rechargements, seeks pendant le chargement). Reprise d'erreurs via `IvsRecoveryPolicy` ; « non disponible » → diagnostic usher ; un refus d'un jeton qui nomme le viewer (`VodAccessInfo.authenticated`, `user_id` du jeton) → diagnostic usher aussi : abonnés-seulement / géobloqué / introuvable restent dans l'appli (jamais le lecteur web, qui buterait pareil), un jeton expiré est rafraîchi, et après deux refus le jeton anonyme est demandé. Repli `WebVodStore` (`stores/web_vod_store.dart`, embed `player.twitch.tv/?video=…` dans une WebView, `<video>` interrogé chaque seconde) sur iOS, avec le réglage « Twitch web », ou après un échec natif. Les deux implémentent `VodPlayerController`.
- **Replay du chat** : `VodChatReplayStore` piloté par la seconde de lecture ; `VodCommentCache` (couverture par plages, éviction), prefetch 15 s × vitesse, espacement des requêtes, gel « indisponible » sur refus d'intégrité. Chaque commentaire devient un `IRCMessage` (`vod_comment_to_irc.dart`, `IRCMessage.fromString` inchangé) : badges, couleurs, emotes Twitch et 7TV/BTTV/FFZ (sets actuels de la chaîne) rendus comme en live ; utilisateurs bloqués et mots masqués filtrés.
- **Écran** (`vod_screen.dart`, `vod_overlay.dart`, `widgets/`) : portrait (16:9 + infos + replay) et paysage (chat latéral redimensionnable ou overlay plein écran, double-tap central = cycle des modes comme en live), ±10 s, double-tap gauche/droite, vitesse 0,5-2×, qualité, volume, PiP, fit/fill, lien au timecode. `PlaybackFocus` (`services/playback_focus.dart`) : un seul lecteur audible (le live sous une VOD se met en pause et reprend au retour) ; `reclaimPipCallbacks` rend les événements PiP à l'écran revenu au premier plan.
- **Garde de contenu** : `VodScreen` lit les labels de la vidéo (délai 3 s, échec = pas de garde) et affiche `ContentWarningCover` (partagé avec le live, texte de l'officiel) à la place du lecteur, créé seulement après « Start watching » ; acceptation partagée avec le live (`AcceptedContentWarnings`, par chaîne et par session). Lecteurs web : le pont (`web_vod_store.dart`, et `video_store.dart` pour le live) signale l'avertissement web de Twitch quand il est visible (`web_content_gate.dart`, `WebPagePlayer`) et nos contrôles s'effacent tant qu'il est là ; les deux ne le cliquent qu'avec l'accord du viewer : réglage coupé, chaîne acceptée dans la session, ou « Start watching » sur le nôtre (VOD : `window._frostyGateOk` ; live : `WebContentGateClicker`). Sinon il reste à toucher par le viewer.
- **Reprise** (`vod_resume.dart`) : position locale par compte (SharedPreferences, clés `viewer|vod`, 300 vidéos ; les anciennes clés nues restent lisibles), sauvegardée toutes les 20 s, à la pause, en arrière-plan et à la sortie, et écrite sur le compte Twitch (`TwitchVodService.updateViewedVideo`, type VOD, jeton web vers gql.twitch.tv seulement). Départ : `?t=` > local −30 s > `self.viewingHistory` du compte (tel quel, attendu 3 s max) > live quitté −30 s > 0 ; une position enregistrée plus de 2 min plus tard l'emporte sur la précédente ; les 30 dernières secondes repartent de 0 (sauf VOD en cours d'enregistrement). Barre de progression et « Vu » dans les listes, live compris.
- **Progression du live** (`channel/video/live_progress.dart`) : `LiveProgressTracker` suit le lecteur courant (natif, web après repli, fenêtre mini), garde toutes les 20 s en local (`live_progress_v1`, par compte, id du stream → décalage dans la diffusion = maintenant − `startedAt` − latence) et écrit `UpdateUserViewedVideo` type LIVE + id du stream toutes les 5 min, à la pause, en arrière-plan et à la fermeture, comme l'officiel. La VOD d'archive retrouve son live par `broadcast.id`. Erreurs serveur : 401 → renouvellement du jeton une fois ; intégrité → arrêt pour la session ; autres erreurs GQL → arrêt après 3 de suite.
- **Accès** : liste `ChannelVideosScreen` (onglets Rediffusions / Temps forts / Uploads) depuis l'overlay live et hors ligne, l'app bar du mode chat seul, la fiche utilisateur du chat et le menu d'actions utilisateur ; liens `twitch.tv/videos/<id>`, `/v/<id>`, `/<chaîne>/v/<id>`, `?t=` et `/<chaîne>/videos?filter=` ouverts dans l'appli depuis le chat (`utils/link_router.dart`) et les App Links (`main.dart`), jamais dans le navigateur.

### Clips — `lib/screens/clips/`
- **Données** (`apis/twitch_clip_service.dart`, `models/clip.dart`) : GQL anonyme sur le même `Dio` que les VOD. Top 100 d'une chaîne par période (`LAST_DAY`… `ALL_TIME`) et tri (`VIEWS_DESC`, `TRENDING` ; les autres tris renvoient « server error ») sans curseur ; `clip(slug)` ; jeton de clip + rendus MP4 de l'asset `SOURCE` (le `RECOMPOSED` vertical est ignoré), filtrés sur https et CDN Twitch, signés `?sig=&token=` (`signClipUrl`). Les slugs sont validés (`isValidClipSlug`) avant tout usage dans une URL.
- **Lecture** : `ClipPlayerStore` (`stores/clip_player_store.dart`) implémente `VodPlayerController` sur un `ClipMediaBackend` ; l'implémentation réelle est un `Player` media_kit dédié (configuration par défaut, jamais les réglages basse latence du live). Qualité mémorisée (`last_stream_quality`), boucle mémorisée (`clip_loop`), une seule reprise sur erreur avec un jeton neuf, puis repli `WebVodStore.forUrl(webClipEmbedUrl(slug))`. Refus du jeton → `VodErrorView(subject: 'clip')`.
- **Écran** (`clip_screen.dart`) : `VodOverlay` généralisé par `PlayerMedia` (titre, chaîne, lien de partage ; sans ±10 s, avec bouton boucle), `ClipInfoPanel` (chaîne, « Clipped by », vues, catégorie, « Watch full video » → `VodScreen` à `videoOffsetSeconds`, copie du lien). Portrait : infos puis replay du chat de la VOD (`createVodChatReplay`, position = offset + seconde du clip) ou, sans VOD, `MoreClipsSliver`. Paysage : vidéo seule, sur tablette comme sur téléphone (pas de panneau latéral depuis le retour à ONSET). Même `PlaybackFocus`, PiP et mini-player que les VOD.
- **Accès** : onglet « Clips » de `ChannelVideosScreen` (`ChannelClipsStore` : cache par puce, requêtes jointes, réponse périmée ignorée) ; `ClipCard` sur `VideoCardLayout` (mise en page partagée avec `VodCard`) ; liens `clips.twitch.tv/<slug>`, `/embed?clip=`, `/<chaîne>/clip/<slug>`, `/clip/<slug>` et `/<chaîne>/clips?range=` ouverts dans l'appli (`TwitchLink.opensInApp`) depuis le chat et les App Links (hôte `clips.twitch.tv` ajouté au manifeste).

### Temps réel (Hermes) — `lib/services/realtime/`
- **Client** `TwitchRealtimeClient` (fourni dans `main.dart`, `context.realtimeClient`) : une seule connexion WebSocket anonyme à `wss://hermes.twitch.tv/v1?clientId=<web public>` pour les sujets PubSub publics, séparée du chat et de la vidéo (une panne n'atteint que les abonnés du sujet, sous forme de `RealtimeUnavailable`).
- **Cycle de vie** : connexion paresseuse au premier abonnement, sujets comptés (désabonnement différé de 500 ms), chien de garde keepalive + 5 s, reconnexion 1/2/4/8/16/30 s ±20 % (immédiate après une session saine), réabonnement de tous les sujets (`RealtimeSubscribed(isResubscribe)` → le consommateur recharge son état), fermeture après 30 s sans sujet, pause après 60 s en arrière-plan. Codes fatals (4010, 411x, 412x, 4130/4131) → arrêt, nouvel essai au plus toutes les 5 min. Trames `reconnect` limitées à une immédiate par 30 s.
- **Protocole** (`hermes_protocol.dart`) : décodage qui ne lève jamais, trames ≤ 256 Ko, keepalive borné à 1-120 s ; les sujets liés à un compte sont refusés côté client.
- Ce client anonyme coexiste avec le `HermesClient` d'ONSET (ci-dessous), qui seul porte les sujets du viewer.

### Retour à ONSET — événements de chaîne, points, jeton web
- **`HermesClient`** (`lib/services/hermes_client.dart`, modèles `lib/models/hermes.dart`) : un socket par chaîne regardée, possédé par `ChannelEventsStore`. Après le `welcome`, il s'authentifie d'abord (jeton web, s'il y en a un) puis s'abonne : un `*-user-v1` envoyé avant l'`authenticate` est refusé. Table id d'abonnement → sujet (les notifications ne nomment pas leur sujet), un sujet n'est envoyé qu'une fois, un sujet abandonné avant la réponse est libéré côté serveur, une révocation réabonne. Keepalive du serveur borné à 5-120 s (ping à 60 %, silence à ×3), reconnexion exponentielle avec gigue jusqu'à 60 s (remise à zéro au `welcome` et sur une trame `reconnect`), pause en arrière-plan. Une trame mal formée ne coûte qu'elle-même ; un `parseError` n'est journalisé que par son code (la trame renvoie ce qu'on a envoyé, jeton compris).
- **`ChannelEventsStore`** (`lib/screens/channel/stores/channel_events_store.dart`) : sujets de la chaîne (prédictions, points, objectifs créateur, célébrations) et, connecté, ceux du viewer (points, prédictions). Célébrations dédupliquées par id (50 derniers) ; objectif créateur gardé brut ; un événement de points relance une lecture GQL, regroupée sur 2 s, plus une lecture par minute si connecté. Actions de points (échanger, parier, coffre) : drapeau « en cours » levé avant toute attente (pas de double dépense), jamais automatiques, refus d'intégrité mémorisé par action et affiché tel quel, aucun contournement de `Client-Integrity`. Journal des points en debug seulement.
- **`TwitchPointsService`** (`lib/apis/twitch_points_service.dart`, `BaseApiClient`, `Dio` à 5 s / 10 s) : GQL avec le client-id web public ; une requête pour solde, coffre, nom et icône, récompenses intégrées et personnalisées (fusionnées, actives, par coût ; un coût nul = power-up en Bits, écarté) et prédictions. Mutations `redeemCommunityPointsCustomReward`, `claimCommunityPoints`, `makePrediction` avec `Authorization: OAuth <jeton web>` et un `transactionID` par dépense ; réponse ramenée à un code (`null` = succès ; 401 → non authentifié ; charge vide → `unknown_error` ; échec réseau → `request_failed`).
- **Interface** : `ChannelPointsButton` en bas à gauche du chat de la chaîne regardée (solde « 1.5K », icône de la chaîne, cadeau si coffre, graphique si prédiction ouverte) → `ChannelPointsSheet` (récompenses, confirmation et texte, coffre, prédiction et feuille de mise) ; `CelebrationOverlay` (Lottie recolorées, zone chat/vidéo/partout, réglage « Show celebrations »).
- **Jeton web** (`auth_store.dart`, `services/twitch_web_token_service.dart`, `TwitchCookies.kt`) : le cookie `auth-token` de twitch.tv, lu dans le bocal des WebView à la connexion, rafraîchi au lancement par une WebView cachée (navigation limitée à https `*.twitch.tv`, garée sur `about:blank` après lecture) et renouvelé après un refus (au plus toutes les 5 min, en attendant un rafraîchissement déjà en cours). Seul Android a ce bocal : ailleurs, un jeton collé à la main n'est jamais déclaré expiré. Un résultat lu à travers une déconnexion est jeté (époque d'authentification) ; la déconnexion efface jeton, cookies et page cachée avant tout le reste. Réglage « Twitch web token (2K) » : jamais affiché en clair, champ masqué, Remplacer / Effacer. `getCookie` natif limité aux URL https twitch.tv.

### Hype Train — `lib/screens/channel/hype_train/`
- **Données** : `TwitchHypeTrainService` (GQL anonyme, même `Dio` sans auth que les VOD) donne l'instantané (`GetHypeTrainExecution`, document allégé sans `levels`), les récompenses à venir (paresseux) et les statuts pour les cartes (`allActiveHypeTrainStatuses`, par 100). Événements temps réel : sujet `hype-train-events-v2.<channelId>` (`models/hype_train_event.dart`). Faits vérifiés : `data.id` est l'id du train (le même qu'en GQL), `sequence_id == total`, montée de niveau et progression dans les deux ordres, `time_to_expire` en ms epoch.
- **Logique pure** : réducteur (`hype_train_reducer.dart` : déduplication `trainId:sequence`, report d'une progression du niveau suivant, transitions record/trésor/communauté), file (`hype_train_queue.dart` : regroupement des rafales, plafond 100), planificateur de séquences (`hype_train_sequence.dart` + `hype_train_timings.dart`, minutages de l'appli officielle ; modes compact, réduction des animations, présentateur invisible), maths (`hype_train_math.dart`), horloge serveur (`hype_train_clock.dart`, médiane des 5 derniers décalages).
- **Store** `HypeTrainStore` (`stores/`) : un par chaîne principale (D2), créé par `channel.dart` si le réglage « Show Hype Trains » est actif, détruit à la sortie (jamais dans le mini-lecteur, D17). Instantané au démarrage, au réabonnement et au retour de l'appli (une requête à la fois, ≥ 2 s d'écart, aucune perdue) ; sondage toutes les 20 s si le temps réel tombe (D12) ; fin synthétisée à expiration + 10 s (D5), annulée si le train bouge encore ; événements d'un autre train ignorés (rechargement).
- **Style Twitch** (`bd3d554`) : bannières par défaut et compacte, feuille, pastilles, bandes de fin et effets redessinés d'après l'appli Android, en vert là où Twitch met du violet (`widgets/hype_train_tokens.dart` : rampe `HtGreen`, neutres ; `hype_train_palette.dart`).
- **Interface** (`widgets/`) : `HypeTrainSlot` au-dessus du chat, dans l'étage supérieur de `channel/channel_top_overlays.dart` (placement par `hypeTrainPlacement` : bannière complète, compacte en paysage, pastille sur la vidéo quand le chat est masqué, rien avec le clavier en paysage), bannière (niveau, étape en cours, barre, %, minuteur), pastille réduite, bannière d'approche, bandes de fin 20 s, feuille détaillée (variante, objectif de niveau D6, conducteurs, récompenses verrouillées/débloquées/à venir, record, guide), effets peints sans assets (`effects/` : pièce, fusée, arc-en-ciel, trophée, roulette Mythic, fusion). Couleurs du thème Frosty, contraste ≥ 4,5:1, sémantique (un libellé, régions live), RTL. Aucun bouton d'achat (D4). Pastille de niveau sur les cartes des chaînes suivies.
- **Outil** : `lib/dev_hype_train_harness.dart` (`flutter run -t …`, non livré) — trains actifs en direct et scénarios rejoués.

### Highlights communautaires — `lib/screens/channel/community_highlights/`
- **Données** : `TwitchCommunityHighlightsService` (GQL anonyme, documents complets, réponse partielle tolérée) pour l'état initial : `viewablePoll`, `GetActivePrediction` (active, verrouillée, dernière résolue), `pinnedChatMessages(first:1, MOD)`. Temps réel : quatre sujets publics sur le `TwitchRealtimeClient` partagé, `polls`, `predictions-channel-v1`, `pinned-chat-updates-v1`, `raid` (`models/community_highlight_event.dart`, analyse qui ne lève jamais, tailles bornées, id de chaîne vérifié).
- **Logique pure** : réducteurs (`highlight_reducers.dart` : statuts qui ne reculent pas, votes monotones, mises à jour de prédiction ordonnées par horodatage, épingle par id, raid de cette chaîne seulement), pile (`highlight_stack.dart`, règles du réducteur web de Twitch : récence, même id en place, épingle initiale en fin, nouvelle carte derrière une carte dépliée avec pastille « New », fermeture par id pour la session), maths (`highlight_math.dart` : % au plus fort reste, cote « 1:x »), minutages (`highlight_timings.dart`).
- **Store** `CommunityHighlightsStore` (`stores/`) : un par chaîne principale, créé par `channel.dart` si le réglage « Show community highlights » est actif, détruit à la sortie (jamais dans le mini-lecteur). Rendu groupé (≤ 2 par seconde, immédiat pour un nouvel id ou statut) ; échéances (sondage 60 s après la fin, prédiction résolue 60 s / annulée 30 s, épingle à `endsAt`, raid 60 s après le départ) ; une requête GQL à la fois par sujet, ≥ 2 s d'écart, relancée si on la redemande pendant qu'elle tourne ; une réponse GQL partie avant un événement temps réel est ignorée (plus ancienne), et un instantané ne fait jamais reculer un statut ; trois échecs d'API (hors réseau et délai dépassé) coupent l'instantané du sujet jusqu'à la prochaine reconnexion Hermes, avec une trace Crashlytics ; une erreur GQL sur le champ demandé est un échec, pas un « rien » ; sondage GQL toutes les 30 s si un sujet est indisponible. Charges utiles bornées (listes, texte de 500 unités sans surrogate isolé, dates 2000-2200, durées ≤ 1 jour). Fins ancrées à la première observation : un raid sans « go » part 90 s après son départ prévu. Sur grand écran, les nouveaux sondages, prédictions et raids arrivent dépliés (jamais l'épingle).
- **Interface** (`widgets/`) : cartes `PollCard`, `PredictionCard`, `PinnedCard` (message rendu par `PinnedChatText` avec les assets 7TV/BTTV/FFZ de l'onglet principal), `RaidCard` (« Watch » → `pushReplacement` vers la cible, id et login validés), toutes sur `HighlightCardShell` ; `HighlightSlot` (une carte, pagination, pastille « New ») et `HighlightVideoPill` / `showHighlightDetails` (feuille qui se ferme seule). Placement partagé avec le Hype Train (`channel_top_overlays.dart`) : étage sous le train, une ligne sous un train en cours sur téléphone et pendant la saisie, masqué quand les détails du train sont ouverts, jamais sous la zone de saisie (défilement), pastille sous celle du train quand le chat est masqué. Aucun bouton de vote ni de pari.

### Profil de chaîne — `lib/screens/channel_profile/`
- **Données** : `TwitchChannelProfileService` (GQL anonyme, `user(login)` : bio, followers, rôles, bannière, image hors ligne, couleur, réseaux, panneaux, dernière diffusion, direct ; `channel.schedule` : segments de la semaine et de la suivante, prochain départ). Modèles `models/channel_profile.dart` : images limitées à `static-cdn.jtvnw.net` et `panels.twitch.tv` en https, liens http(s) seulement, textes bornés, rien ne lève.
- **Store** `ChannelProfileStore` : profil (une requête à la fois), en-tête Helix `/users` si le GQL échoue, programme chargé à la première ouverture de l'onglet.
- **Écran** `ChannelProfileScreen` : `NestedScrollView` (l'en-tête défile, la barre d'onglets reste), onglets Accueil, À propos, Programme, Vidéos (`ChannelVideosTab`, extrait de `ChannelVideosScreen`, avec sa progression) et Clips (`ChannelClipsTab`), en mode `nested` (contrôleur partagé, sans barre de défilement ni bouton « haut »). Ouvert depuis une chaîne suivie hors ligne, un résultat de recherche hors ligne, l'avatar sous la vidéo (`fromChannel` : Regarder revient au lecteur), la carte d'utilisateur du chat, le menu d'actions (« Profile ») et les liens `/<login>/about`, `/schedule`.

### Compte (E9)
- Aucune action de compte par le GQL privé. `TwitchWebPage` (`widgets/twitch_web_page.dart`) ouvre une page twitch.tv (hôte vérifié) dans un WebView qui partage les cookies de la page de connexion : « Follow X on Twitch » (menu d'actions d'une chaîne), « Vote/Predict on Twitch » (cartes de sondage et de prédiction ouvertes, `HighlightCardContext.onTakePart`, chat `/popout/<login>/chat`), « Channel points, polls and predictions » (menu « More » du chat), et le signalement.

### Réglages et gestes (E10)
- Déconnexion : `AuthStore.logout` révoque le jeton utilisateur (`TwitchApi.revokeToken`, formulaire `client_id` + `token`, 5 s max, jamais bloquant) avant de l'effacer.
- `settingsStore.startTab` (`HomeTab`) choisit l'onglet d'ouverture ; `HomeStore` y revient à la connexion ou déconnexion (`HomeTab.indexWhen`, sans Following hors connexion).
- `PinchToFill` (`video/pinch_to_fill.dart`) lit les pointeurs bruts autour de l'overlay en paysage (IVS) : un pincement par geste, `IvsVideoStore.setFillScreen` ; pendant un pincement (`_pinching`), le glisser vers le PiP revient en place et le tap est ignoré.
- Sous-titres : `setCaptions` côté Kotlin choisit la piste demandée par `setTextTrack` si le flux l'a, sinon la première `TextTrack` (rien si le stream n'en a pas), relaie les `TextCue` et envoie la liste des pistes (`textTracks`, à chaque changement). `CaptionStore` (`video/stores/caption_store.dart`), partagé par `IvsVideoStore` et `IvsVodStore`, garde la ligne la durée du cue (1 à 8 s), la liste des pistes et la langue choisie (`settingsStore.captionLanguage`, reprise au flux suivant) ; `CaptionMenu` (interrupteur « Closed Captions » et pistes) est dans la feuille du lecteur live et de la VOD ; `CaptionText` suit `captionSize` et `captionBackground` (Réglages › Vidéo, par défaut blanc 15 sur noir comme Twitch).
- Audio seul : usher reçoit `allow_audio_only=true` ; la qualité `audio_only` s'affiche « Audio only » (`qualityLabel`), une pastille la signale sur l'image, et `pickInitialQuality` ne la restaure jamais au stream suivant.
- **Lives refusés** : le jeton GQL demande `authorization { forbiddenReasonCode }` (`PlaybackRefusal` : abonnés seulement, région, ban, refus). Un 401/403 IVS sur une chaîne dont le jeton portait déjà un refus abandonne aussitôt (`_failExplained`) ; sinon, après les rechargements, la playlist usher est relue une fois (4 s) pour son message. `refusalNotice` est affiché en SnackBar au passage sur WebView. Un jeton refusé n'est pas mis en cache ; si Twitch rejette le champ, le jeton est redemandé sans lui.
- **Audio en arrière-plan** (Android, `settingsStore.backgroundAudio`) : `BackgroundAudio` (`services/background_audio.dart`, canal `frosty/background-audio`, un seul propriétaire) ; `IvsVideoStore` affiche la notification tant que le live joue ou se reconnecte, suit play/pause et reçoit les commandes (play, pause, stop). Côté Kotlin, `BackgroundAudioService` (service de premier plan `mediaPlayback`, `MediaSession`, `Notification.MediaStyle`) garde le processus en vie ; le lecteur IVS reste celui de la texture.
- **Focus audio** (Android) : `AudioFocus` (`services/audio_focus.dart`, canal `frosty/audio-focus`) ; `IvsVideoStore` le prend tant que le live joue, le rend à la pause (sauf pause due à un appel, reprise au `gain`) ; `AudioFocusBridge.kt` relaie aussi `ACTION_AUDIO_BECOMING_NOISY`.
- **Préchargement** : `PlaybackPreloader` demande le jeton à l'appui sur une carte (`onTapDown`) ; `PlaybackTokenCache.pending` partage la requête en cours avec le lecteur, dont l'échec revient à la politique de reprise du lecteur.
- **Lecteur d'écran** : `VideoSurfaceSemantics` (`overlay_common.dart`) nomme les surfaces vidéo et propose les doubles-taps en actions ; `FrostyCachedNetworkImage.semanticLabel` nomme emotes et badges ; `DraggableDivider` se règle comme un curseur.
- Portrait : `PortraitSplitHandle` (`channel/portrait_split.dart`) règle `settingsStore.portraitVideoScale` (40 % à 100 %, jamais sous 300 dp de large ; suivi local pendant le glisser, une seule écriture à la fin) ; la vidéo reste 16:9, centrée dans la hauteur réservée, le chat prend le reste.

### Découverte (E8) — `lib/screens/home/`
- **Page catégorie** (`top/categories/category_streams.dart`) : puces Live / Videos / Clips. Videos et Clips réutilisent `ChannelVideosTab` et `ChannelClipsTab` avec un `gameId` (stores créés à la première ouverture) ; les cartes nomment la chaîne (`showChannel`).
- **Langue** : `settingsStore.streamLanguage` (`utils/stream_languages.dart`, '' = toutes) filtre Top, catégorie et tag ; un changement relance la liste et `ListStore` ignore une page demandée avant (`_streamsGeneration`).
- **Tri et tags** : `TwitchDirectoryService` (GQL anonyme) donne les lives d'une catégorie ou d'un tag dans un ordre `StreamSort` ; une catégorie en « Viewers (high to low) » reste sur Helix et pagine, les autres ordres et les tags tiennent en une réponse (pagination GQL soumise à l'intégrité). Nœuds validés (ids numériques, login, direct seulement, miniature reconstruite depuis le login). `StreamSortButton` sur la page catégorie et `TagStreams` (`top/tags/`), ouverte depuis les tags d'une carte (`StreamTags.onTap`).
- **Recherche** : entrée d'historique supprimable, résultat exact mis en avant (`search/featured_channel.dart`).
- **Labels de contenu masqués** : `settingsStore.hiddenContentLabels` ; pour Top, catégorie et tag, `ListStore` lit les labels de chaque page (`TwitchApi.getChannelsByIds`) avant de l'afficher, garde les ids masqués (`hiddenByLabels`, `showLabeledStreams`) ; `HiddenStreamsBanner` le dit en tête de liste. Jamais pour les chaînes suivies.
- `StreamsList` détruit son `ListStore` (réactions, écouteur de défilement) ; le contrôleur de défilement reste à son propriétaire.

### Pack « follows » — Following, séries, abonnement
- **Tri de Following** : `settingsStore.followedSort` (`FollowedSort` : viewers, recent, name, category), choisi par `FollowedSortButton` (« Sorted by … », `stream_sort_button.dart`) ; `ListStore.streams` et `allPinnedChannels` gardent l'ordre de Helix pour viewers et passent sinon par `sortFollowedStreams` (tri stable), après avoir chargé les pages restantes (`_loadAllForSort`, 5 au plus).
- **Catégories suivies** : `TwitchFollowedCategoriesService` (`BaseApiClient`, `Dio` GQL anonyme, le jeton web ajouté par requête vers `gql.twitch.tv` seulement) lit `FollowedGamesQuery` ; tout échec rend `null`. `ListStore` (Following) garde `followedCategories`, sans redemander pendant 30 min après un échec ; `FollowedCategoriesSection` (carrousel de jaquettes, toucher = `CategoryStreams`) avant « Offline ». Sur la page catégorie, « Follow on Twitch » ouvre `/directory/category/<slug>` dans `TwitchWebPage` (slug en GQL anonyme, sinon le nom) : aucune mutation de follow.
- **Séries de visionnage** : `TwitchWatchStreakService` (même `Dio`, jeton web par requête) lit `WatchStreakMilestoneQuery` (une chaîne) et `BatchGetWatchStreaksQuery` (toutes) ; `models/watch_streak.dart` valide la réponse et reprend le texte de Twitch (`WatchStreak.copy`). `ChannelEventsStore.refreshWatchStreak` (à la connexion et à l'ouverture de la feuille, 1 min entre deux lectures, 10 min après un échec) nourrit `WatchStreakCard` en tête de `ChannelPointsSheet` ; `ListStore.watchStreaks` nourrit `WatchStreakTag` sur les cartes suivies. Lecture seule : aucun partage, aucune sauvegarde de série, aucun événement de visionnage envoyé.
- **Subscribe / Gift a Sub** : `twitchSubscribeUrl` (`utils/twitch_links.dart`, login validé) ouvre `twitch.tv/subs/<login>` dans `TwitchWebPage`, depuis l'en-tête du profil (partenaire ou affilié) et le menu du chat (connecté), jamais sur la chaîne du viewer.

### Notifications locales — `lib/services/go_live/`, `lib/services/notifications/`, `lib/screens/activity/`
- **Go-live** : `checkGoLive` (`go_live.dart`) lit `GET /streams/followed` et annonce les nouveaux lives ; état dans `GoLivePrefs` (préférences partagées avec l'isolat WorkManager, relues par `reload()`), une notice par diffusion (`started_at` déjà vu), `checkedAt` commun : la tâche de fond (`go_live_worker.dart`, ~15 min) saute si l'appli vient de vérifier. `GoLivePoller` (`go_live_poller.dart`) vérifie toutes les 90 s tant que l'appli est au premier plan, en PiP (`inactive`) ou joue du son en arrière-plan (`BackgroundAudio.playing`), s'arrête sinon ; il attend `GoLiveNotifications.ready`.
- **Mentions** : `ChatStore` passe chaque PRIVMSG à `chatMentionOf` (mention du viewer, ni historique ni ses propres messages) puis à `MentionAlerts.shared` (`mention_alerts.dart`), qui notifie hors premier plan (`appInFront`), une fois par chaîne et par 30 s, canal Android « Chat Mentions ». Réglage `settingsStore.mentionNotifications` (activé par défaut).
- **Rappels** : `ScheduleReminders` (`schedule_reminders.dart`, `ChangeNotifier`, `shared` posé dans `main.dart`) garde les rappels dans les préférences et les programme par `LocalReminderPlatform` (`zonedSchedule` en UTC, inexact sauf alarmes exactes déjà permises ; récepteurs de redémarrage du plugin dans le manifeste). `ProfileScheduleContent` affiche « Remind Me » / « Reminder Set » ; `ChannelProfileScreen` resynchronise les segments déplacés ou annulés.
- **Activity** : `ActivityLog` (`activity_log.dart`, 100 entrées JSON dans les préférences, une par événement, relu avant chaque écriture car l'isolat de fond y ajoute ses go-live) et `ActivityStore` (`screens/activity/stores/`, non lus, nouveautés depuis `viewedAt`). `ActivityBell` dans la barre de l'accueil ouvre `ActivityScreen` (Notifications locales, Whispers via `WhispersList`). Rappels passés et liste relus au retour au premier plan. Ids de notification stables par `stableNoticeId` (`notice_ids.dart`).

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

### Ajouts E7 (chat)
- **Commandes** (`chat/chat_commands.dart`) : `parseChatCommand` classe la saisie ; `/me` part en IRC, `/color`, `/block`, `/unblock`, `/help` s'exécutent via Helix dans `ChatStore._runCommand` (résultat en notice), le reste est expliqué sans être envoyé. `matchCommands` alimente l'autocomplétion.
- **Restrictions** (`chat/chat_restrictions.dart`) : `chatRestriction` donne, par priorité, ban, timeout, attente du mode lent puis modes du salon ; `ChatStore._restriction` est recalculée sur CLEARCHAT visant son compte, rejets `msg_banned`/`msg_timedout`/`msg_slowmode`, ROOMSTATE, USERSTATE (VIP lu dans les badges) et à l'échéance. La saisie est verrouillée et `ChatRestrictionBar` affiche le compte à rebours ; les modes non bloquants vont dans le texte d'aide.
- **2e partie** : ligne de modération pour chaque CLEARCHAT ciblé (`moderation_notice.dart`, insérée dans le tampon à l'heure `tmi-sent-ts`, nom affiché repris du dernier message), emotes fixes (`Emote.staticUrl`, `urlFor(animate:)`, réglage `animateEmotes` passé à `generateSpan`), cartes de clip et de vidéo (`chat_link_card.dart` : premier lien du message, cache LRU partagé, échec non mis en cache, miniatures limitées aux hôtes Twitch), condition de déblocage dans la fiche d'emote (`Emote.unlockHint`).
- **AutoMod côté émetteur** : `HeldMessageWatcher` (`chat/held_messages.dart`, EventSub `channel.chat.user_message_update`, scope `user:read:chat`) ajoute une notice quand les modérateurs approuvent, refusent ou laissent expirer un message retenu ; `ChatStore` le recrée à chaque compte ou jeton.
- **Divers** : saisie limitée à 500 caractères (`chat_character_counter.dart`), mots masqués via `isMuted` (`muted_words.dart`), mentions en mot entier (`mentionsUser`).

### Pack « chat » (règles et filtres)
- **Règles** : `TwitchChatRulesService` (GQL anonyme, document `ChatRules` de l'appli officielle, par id de chaîne) → `ChatRules` ; `ChatRulesStore` (créé par `ChatTabsStore` pour chaque `ChatStore`) écoute le `FocusNode` de la saisie : la première prise de focus d'un viewer connecté dans une chaîne qui a des règles est annulée et `prompting` passe à vrai ; `ChatRulesPrompt` (autour de `ChatBottomBar`) ouvre `ChatRulesSheet`, « OK, Got it! » enregistre `chat_rules_accepted_<viewer>_<chaîne>` dans les SharedPreferences et rend le focus. `ChatRulesTile` les remontre depuis le menu du chat. Tout échec : rien n'est montré.
- **Filtres** : `chat/chat_filters.dart` (pur) lit la balise IRC `flags` (`AutoModFlag`), applique le seuil 3 de l'appli officielle par catégorie active (`ChatFilterSettings`) et masque les plages (positions en points de code, règles de plage de Twitch) avec `kFilteredUnit`, une unité par unité UTF-16 : espaces, emojis et caractère invisible restent, donc le texte masqué se découpe en mêmes mots. `IRCMessage` garde `textAsSent` et calcule (en cache par réglage) les mots masqués, alignés sur `split` et `gifParts` ; `generateSpan(chatFilters:, onTapFiltered:)` dessine `*` et garde les emotes Twitch. `ChatMessage` n'applique rien si le viewer modère la chaîne ou a révélé le message (`ChatStore.revealedFilteredMessageIds`), et l'aperçu de lien lit `shownText`.

### Notices d'abonnement et gift bombs (retour à ONSET)
- **Rangée de notice** (`chat/widgets/user_notice_row.dart`) : la rangée spéciale de l'appli Android de Twitch (barre d'accent 4 dp, icône 18 dp, phrase, message du viewer), en vert ; mise en page choisie par type (`models/user_notice_presentation.dart`), libellés de Twitch (`models/user_notice_text.dart`), champs `USERNOTICE` lus par `models/user_notice.dart` (mois offerts, anonymat, clé de gift bomb). Aussi dans le chat en surimpression.
- **Gift bombs** (`chat/gift_bomb_tracker.dart`, pur) : regroupe l'en-tête `submysterygift` et ses `subgift` ; chaque gift est affiché, ou seulement l'en-tête avec « Collapse gift bombs ». `community_highlights/gift_bomb_feed.dart` épingle la bannière au-dessus du chat avec son compte à rebours ; elle reste visible quand les détails du hype train sont ouverts.

### GIF du chat (clavier GIF de Twitch)
- **Parsing** (`models/chat_gif.dart`, `IRCMessage.fromString`) : tag `gifs` (`<début>-<fin>|<id>|<url>`, séparés par des virgules) lu sur la ligne brute et déséchappé une fois (`UserNotice.unescapeTag`) ; entrées ignorées comme chez Twitch (3 champs, id et URL non vides, plage `a-b`). Positions en caractères (comme `emotes`), à défaut en unités UTF-16 (comme l'appli Twitch), comptées après le préfixe `/me`, sans couper un emoji ; pas de chevauchement, 5 GIF au plus. `IRCMessage.gifParts` découpe le message ; `message` et `split` gardent tout le texte (copie, recherche, mentions inchangées). Le séparateur de tags ne coupe plus une valeur au 2e `=`.
- **Rendu** (`generateSpan` → `chat/widgets/chat_gif_image.dart`) : comme l'appli Twitch, retour à la ligne puis le GIF à la place de son titre, 128 px de haut (72 en paysage ou dans le chat en surimpression), largeur selon l'image, carré vide pendant le chargement, titre comme libellé d'accessibilité ; appui → fiche (copier le titre ou l'URL, ouvrir). Titre en texte si « Show GIFs in Chat » est éteint, si l'URL n'est pas `https` sur giphy.com ou jtvnw.net (l'historique tiers peut porter le tag), ou si le chargement échoue (même hauteur). « Animated GIFs » éteint : première image seulement (`widgets/first_frame_image.dart`). L'aperçu de réponse de la saisie montre le titre.
- **Hors champ** : envoi de GIF (GQL privé `sendGifMessage`, palier 2+), « Report GIF », rediffusions et messages épinglés (leurs requêtes ne portent pas de GIF).

## 5. Design system existant

> Depuis le retour à ONSET, `lib/theme.dart` porte la DA d'ONSET (`FrostyTokens` : fonds `#0A0A0A` / `#F8F8F8`, accent citron électrique `#C8FF3D` réservé au live et à la sélection, filets 0,5 px, Inter partout avec chiffres tabulaires). La description ci-dessous est celle du thème Frosty d'origine, gardée comme historique.

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
- **Recherche** : chaînes + catégories, résultat exact mis en avant, historique (8, suppression unitaire), « Go to channel ».
- **Découverte** : page catégorie Live / Videos / Clips, tri des lives, pages de tag, filtre de langue.
- **Chaîne** : 3 moteurs (IVS, mpv, WebView), overlay complet, barre d'info, PiP système, mini-player in-app, paysage (colonne/overlay), chat seul, « My channel », réveil de l'écran, minuteur de veille.
- **Chat** : voir §4.
- **Réglages** : Compte (anonyme/connecté, utilisateurs bloqués, déconnexion), Général (thème, accent, cartes, miniatures, navigateur externe), Vidéo (IVS, vidéo on/off, plus haute qualité, rendu rapide, réveil, overlay custom, appui long, latence), Chat (tailles, apparence, délai, alertes, disposition, paysage, mots masqués, autocomplétion, fournisseurs d'emotes/badges, messages récents), Autre (notes de version, cache, reset, crash logs).
- **Absent** : follow/unfollow, notifications, whispers, abonnements/gifts/Turbo, multi-comptes, profil/à propos/panneaux, VODs, clips, highlights, planning, recommandations, Bits, Channel Points, prédictions, sondages, Hype Train, Drops, modération active, mots-clés de surlignage, badges/paints 7TV, Chromecast, audio seul, streaming.

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
