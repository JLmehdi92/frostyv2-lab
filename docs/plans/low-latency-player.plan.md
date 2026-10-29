# Plan — lecteur basse latence (ECC planner)

Généré par l'agent ECC `planner` sur la base `60ba71a`. Couvre GAP.md §5 P0 #1-#6 (PLY-01..06, PLY-10/11, MSC-02).
Contrainte utilisateur : **ne pas toucher au support 2K** (`supported_codecs=av1,h265,h264`, bouton fit/fill).

## Décisions prises sur les questions ouvertes
1. Libellés des réglages en anglais (le reste de l'UI est en anglais).
2. Chaîne hors-ligne : on reste sur IVS avec l'overlay hors-ligne (plus de bascule WebView pour ce cas).
3. `showLatency` : nouveau défaut `true`, la valeur déjà sauvegardée est respectée.
4. Le chemin SurfaceView mort (`IvsPlayerView.kt`, `IvsVideo`, `onset/ivs-player`) sera supprimé dans un commit de nettoyage séparé après C4.

## Infrastructure de test commune (C1)
- `test/helpers/fake_ivs_native.dart` : handlers mock sur `onset/ivs-texture-manager` (`create` → 7, `dispose` enregistré) et `onset/ivs-texture/7` (enregistre `load/setQuality/setMuted/...`), `emit(Map)` qui pousse un `onEvent`.
- `test/screens/channel/video/stores/ivs_video_store_test.dart` : mocktail `MockTwitchApi`, `MockAuthStore`, `MockTwitchStreamService` injecté, `SettingsStore.fromJson({})` réel, `dispose()` en tearDown.

## C1 — PLY-04 latence visible + stats
- Kotlin `IvsPlayerCore` : méthode `setStatsEnabled`, événement `stats` (bitrate, fps, dropped/decoded/rendered, bufferedMs, lowLatency, playbackRate, bandwidth, quality{name,width,height,codecs,framerate,bitrate}), chaque getter en `runCatching`.
- `lib/models/ivs_stats.dart` : `IvsStats.fromEvent(Map)` tolérant.
- `lib/screens/channel/video/latency_stats.dart` : `formatLatency(ms)` (dixièmes entiers), `chatDelaySecondsFromLatency(ms)` (formule actuelle inchangée), `LatencySampler` (anneau 300, median/p90/min/max/reset), `formatBitrate`.
- Store IVS : `_latencyMs`, `_stats`, `_statsVisible`, `_rebufferCount`, `_startupMs`, sampler ; synchro du délai de chat **toujours au changement de seconde entière** ; `toggleStats`/`resetStats`.
- Widget `ivs_stats_panel.dart` dans le Stack vidéo de `channel.dart` (hors overlay auto-masqué, pas dans le mini-player, pas en PiP).
- Overlay : tap sur le badge de latence = stats (IVS), entrées « Video stats » / « Reset stats » dans la feuille réglages.
- `defaultShowLatency = true`.
- Tests : `latency_stats_test`, `ivs_stats_test`, settings store, store IVS (transitions du délai de chat 2→3→4→60 uniquement).

## C2 — PLY-10/11 erreurs IVS récupérables + garde iOS
- Kotlin : `error` envoie aussi `errorType` et `source`.
- `ivs_recovery.dart` : `classifyIvsError` → recoverable / refreshToken / offline / fatal ; `IvsRecoveryPolicy` (backoff 1/2/4 s, fenêtre glissante 60 s, puis fallback) ; `isRetryableTokenError`.
- `player_engine_resolver.dart` : IVS uniquement sur Android, sinon web.
- Store : statut `{loading, playing, reconnecting, offline, failed}`, rechargement du même player (jamais un 2ᵉ `create`), Dio avec timeouts, échec de création de texture → fallback.
- UI : spinner sur la texture pendant loading/reconnecting, « Reconnecting… (n/3) » dans l'overlay ; réglage IVS masqué hors Android.

## C3 — MSC-02 nettoyage usher
- `usherQueryParameters(...)` partagé : `allow_source`, `fast_bread`, **`supported_codecs=av1,h265,h264` inchangé**, `p`, `sig`, `token`, `type=any` ; suppression de `low_latency` et `player=twitchweb`.
- Tests de présence/absence + encodage exact `supported_codecs=av1%2Ch265%2Ch264`.

## C4 — PLY-03/01 IVS 1.57 + rattrapage par accélération
- `ivs-player:1.57.0` ; `IvsTuning.kt` → `MediaPlayer.Builder(ctx).sessionConfig(SessionConfig().setLiveCatchUpSpeedUpEnabled(..)[+ tampons ultra]).build()` avec repli `Player.Factory.create`.
- `setInitialBufferDuration(100)`, `setRebufferToLive` piloté par le réglage (défaut off).
- Réglages : `LiveCatchUpMode {speedUp, jumpToLive}` et `BufferProfile {standard, ultra}` ; `ivs_player_config.dart` → args de `create`.

## C5 — PLY-02 démarrage plus rapide
- Création du player natif en parallèle de la récupération du jeton, `load` dès que l'URL est prête, garde de génération.
- `PlaybackAccessToken` (+ `parseExpiry`), `PlaybackTokenCache` mémoire (marge 60 s, LRU 32, jamais persisté ni loggé) ; `forceFreshToken` sur erreur d'autorisation.

## C6 — PLY-05/06 qualité mémorisée + son
- `qualities` triées par débit, `quality_selection.dart` (`normalizeQualityName`, `pickInitialQuality`).
- `setMuted`/`setVolume` natifs, bouton muet + curseur de volume, état conservé dans le store (mini-player, PiP, refresh).

## Checklist de non-régression (après chaque commit, sur appareil)
1. Live sur IVS, chat connecté, emotes 7TV/BTTV/FFZ (+ mise à jour live 7TV).
2. Délai de chat auto : « (Ns delay) » entier proche de la latence.
3. Mini-player : pas de rechargement à la réduction/restauration, chat conservé.
4. PiP auto et bouton.
5. Paysage : fit/fill, cycle chat, plein écran.
6. Moteur web sélectionnable ; fallback WebView forcé (mode avion 20 s).
7. Chaîne hors-ligne : barre hors-ligne, pas de spinner infini.

## Protocole de mesure de latence (téléphone réel)
- Même téléphone, même Wi-Fi, build release, « Show latency » activé.
- 3 chaînes fixes : A grosse chaîne partenaire, B moyenne, C en enhanced broadcasting 1440p HEVC/AV1 (vérifie la 2K).
- Runs : R1 = C1 (référence « avant »), R2 = C3, R3a/b/c = C4 speedUp+standard / jumpToLive+standard / speedUp+ultra, R4 = C5 (démarrage), R5 = C6.
- Par run : ouvrir, attendre 30 s, ouvrir le panneau stats, « Reset stats », 5 min sans toucher, capture du panneau (médiane, p90, max, rebuffers, frames, qualité/codec, low-latency).
- Démarrage : 5 ouvertures à froid par chaîne (+ 5 réouvertures à chaud pour C5).
- Comparaison avec l'appli officielle (overlay « latency to broadcaster ») et, idéalement, vidéo des deux écrans sur une chaîne affichant une horloge.
- Critères : médiane R3a ≤ R1 (cible 2-4 s), rebuffers R3a ≤ R1 + 1 / 5 min, démarrage R4 < R3a, chaîne C liste toujours 1440p, délai de chat entier.
- Logs : `adb logcat -s OnsetIVS flutter`.
