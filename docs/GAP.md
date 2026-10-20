# Écarts de fonctionnalités — Twitch Android 31.5.2 vs frostyv2

> Ce document compare, ligne par ligne, le catalogue `docs/TWITCH_FEATURES.md` (317 lignes) au code de `frostyv2-lab` (base `bb2d838`).
> Chaque statut ✅ ou ⚠️ a été vérifié dans le code par `grep` et lecture ; l'inventaire de `docs/ARCHITECTURE.md` n'a servi que de point de départ.
> Ce document ne contient que de l'analyse : aucun code n'a été modifié.

## Mises à jour depuis la validation

| Date | Commits | Lignes mises à jour |
|---|---|---|
| 2026-10-13 | `bbe7ca3` → `d0c9be5` (épopée « lecteur basse latence », C1-C6) + nettoyage SurfaceView | PLY-01, 02, 03, 04, 05, 06, 10, 11. Comptes de synthèse recalculés pour PLY et P0. « À valider sur appareil » : l'émulateur du conteneur ne permet ni l'affichage fluide ni le réseau. |
| 2026-10-13 | `1838137` → `5c8dbf2` (épopée E1 « rediffusions », V1-V7) | PRF-07, 08, 09, 10, 11, 12, 14, 15 ; PLY-06, PLY-10, MSC-01 (remarques). Comptes de synthèse recalculés. Lecture, replay et reprise à valider sur appareil. |
| 2026-10-13 | épopées E3 « temps réel » et E4 « Hype Train » | INT-15, 16, 17 ✅ ; MSC-03, CHT-41 ⚠️ ; PLY-09 (remarque). Comptes de synthèse recalculés à partir des tableaux. Affichage à valider sur appareil. |
| 2026-10-13 | épopée tablette (Xiaomi Pad 7) | MSC-14 ✅ ; DSC-01 (rail). Comptes recalculés. |
| 2026-10-13 | épopée E2 « clips » | PRF-17, PRF-18 ✅ ; CHT-45 ⚠️ ; PRF-19 (compte requis) ; MSC-01 (remarques). Comptes recalculés. Lecture à valider sur appareil. |
| 2026-10-13 | épopée E7 « chat » (1re partie) | CHT-03, 06, 12, 15, 18 ✅ ; CHT-05, 17, 28 ⚠️ (remarques). Comptes recalculés. À valider sur appareil. |
| 2026-10-13 | épopée E6 « profil de chaîne » | PRF-01, 02, 03, 04, 05, 28 ✅ ; PRF-25 ⚠️ (remarque). Comptes recalculés. Affichage à valider sur appareil. |
| 2026-10-14 | épopée E10 « réglages » (2e partie) | PLY-25 ✅. Avertissement de contenu mature avant d'entrer sur une chaîne. Comptes recalculés. |
| 2026-10-14 | épopée E9 « compte » (1re partie) | SOC-01, INT-04 ⚠️ ; INT-01, INT-02 (remarques). Suivre, voter, parier et points passent par les pages twitch.tv dans l'appli, sans GQL privé ni contournement de `Client-Integrity`. Comptes recalculés. |
| 2026-10-14 | épopée E10 « réglages et lecteur » (1re partie) | ACC-04, PLY-07, PLY-12, PLY-20 ✅ ; ACC-12, PLY-23 ⚠️ (remarques). Comptes recalculés. Gestes à valider sur appareil. |
| 2026-10-14 | épopée E7 « chat » (2e partie) | CHT-10, CHT-25, CHT-45 ✅ ; CHT-22 ⚠️ (remarque). Comptes recalculés. À valider sur appareil. |
| 2026-10-13 | épopée E8 « découverte » | DSC-04, DSC-05, DSC-06 ✅ ; DSC-08, DSC-09 ⚠️ (remarques). Comptes recalculés. Affichage à valider sur appareil. |
| 2026-10-13 | épopée E5 « highlights communautaires » | CHT-41, CHT-42 ✅ ; INT-01, INT-02 ⚠️ (lecture seule) ; INT-19 (raid sortant). Comptes recalculés. Affichage à valider sur appareil. |
| 2026-10-15 | GIF du chat (branche `gifs`) | CHT-26 ⚠️ (affichage) ; CHT-25 (remarque). Comptes recalculés. À valider sur appareil avec un vrai GIF. |
| 2026-10-15 | retour à ONSET (portage de l'appli ONSET, hype train et notices au style Twitch, retour de la tablette) et passe finale | INT-25 ✅ ; INT-05, INT-06, INT-07 ⚠️ ; INT-02, INT-04, INT-15, INT-16, CHT-36, MON-07 (remarques) ; MSC-14 ⚠️, DSC-01, PRF-18 (tablette). Comptes recalculés. À valider sur la tablette. |
| 2026-10-17 | VOD : jeton du viewer et écran de garde (branche `vodfix`) | PRF-08, PRF-15, PLY-25 (remarques). Statuts inchangés, comptes inchangés. À valider sur appareil avec une VOD labellisée et une VOD réservée aux abonnés. |
| 2026-10-20 | pack « chat » (branche `chatpack`) | CHT-16, CHT-28, CHT-29, PLY-23 ✅. Comptes recalculés. Comportements relevés dans l'appli décompilée (`/tmp/claude-0/port/chatpack_re.md`). À valider sur appareil : feuille des règles connecté, filtres sur un chat actif, sous-titres sur un stream et une VOD qui en ont. |
| 2026-10-20 | reprise live → VOD (branche `resume`) | PRF-11 ✅. Comptes recalculés. Comportement relevé dans l'appli décompilée (`/tmp/claude-0/port/live_resume_re.md`). Écriture et lecture de la position sur le compte (jeton web) non vérifiables ici : à valider sur appareil connecté. |
| 2026-10-20 | pack « follows » (branche `followpack`) | SOC-04, INT-21, MON-01, MON-06 ⚠️ ; MON-11 ✅ ; SOC-02, SOC-03 (remarques). Comptes recalculés. Lectures GQL avec le jeton web non vérifiables ici (pas de jeton) : à valider sur appareil connecté. |
| 2026-10-20 | pack « notifications » (branche `notifpack`) | PRF-06 ✅ ; SOC-07, SOC-08 ⚠️ ; SOC-06, CHT-05 (remarques). Comptes recalculés. Go-live toutes les 90 s appli vivante, mentions en arrière-plan/PiP, « Remind Me », écran Activity local. À valider sur appareil. |
| 2026-10-20 | pack « vod & clips » (branche `vodclippack`) | DSC-07, DSC-12, PRF-13, PRF-19 ✅ ; PRF-20 ⚠️. Comptes recalculés. Comportements relevés dans l'appli décompilée (`/tmp/claude-0/port/vodclippack_re.md`). Création de clip non vérifiable ici (pas de jeton utilisateur) : à valider sur appareil connecté, comme la lecture du flux et la carte Up Next. |

## 0. Légende et conventions

| Statut | Sens |
|---|---|
| ✅ | Implémentée et conforme au comportement officiel (de petits écarts peuvent figurer en remarque) |
| ⚠️ | Partielle |
| ❌ | Absente |
| ➕ | frostyv2 fait clairement mieux que l'officiel ou va au-delà |

| Faisabilité | Sens |
|---|---|
| « OK » | Faisable avec des API publiques (Helix, IRC, EventSub, 7TV/BTTV/FFZ) ou avec le GQL/usher déjà utilisé pour la lecture (`PlaybackAccessToken`) |
| « GQL privé » | Exige le GQL privé de Twitch (client-id web, souvent un `auth-token` web et `Client-Integrity`). Fragile, contraire aux CGU, à isoler derrière un flag |
| « Compte requis » | Exige un rôle modérateur, diffuseur, affilié ou partenaire que l'utilisateur n'a peut-être pas |
| « Impossible proprement » | Achats Play Billing, DRM signé Twitch, SDK pub, ingest de diffusion, services internes Twitch… |

**Chemins abrégés.** Les références `fichier:ligne` donnent le nom du fichier seul. Correspondance :
`channel.dart`, `video_overlay.dart`, `stream_info_bar.dart`, `ivs_video.dart`, `video_store.dart` → `lib/screens/channel/video/` (sauf `channel.dart` : `lib/screens/channel/`) · `ivs_video_store.dart`, `native_video_store.dart` → `lib/screens/channel/video/stores/` · `chat_store.dart`, `chat_tabs_store.dart`, `chat_assets_store.dart` → `lib/screens/channel/chat/stores/` · `chat_message.dart`, `chat_bottom_bar.dart`, `chat_user_modal.dart`, `reply_thread.dart` → `lib/screens/channel/chat/widgets/` · `chat_details.dart`, `chat_details_store.dart`, `chat_modes.dart`, `chat_users_list.dart` → `lib/screens/channel/chat/details/` · `chat.dart` → `lib/screens/channel/chat/` · `irc.dart` → `lib/models/` · `twitch_api.dart`, `twitch_stream_service.dart`, `seventv_api.dart` → `lib/apis/` · `settings_store.dart`, `auth_store.dart` → `lib/screens/settings/stores/` · `video_settings.dart`, `chat_settings.dart`, `other_settings.dart`, `settings.dart` → `lib/screens/settings/` · `account_options.dart`, `blocked_users.dart`, `profile_card.dart` → `lib/screens/settings/account/` (et `widgets/`) · `settings_muted_words.dart`, `release_notes.dart` → `lib/screens/settings/widgets/` · `streams_list.dart`, `stream_card.dart`, `offline_channel_card.dart` → `lib/screens/home/stream_list/` · `home.dart` → `lib/screens/home/` · `search.dart`, `search_store.dart`, `search_results_channels.dart` → `lib/screens/home/search/` · `categories.dart`, `category_streams.dart` → `lib/screens/home/top/categories/` · `mini_player_store.dart` → `lib/stores/` · `global_mini_player.dart`, `user_actions_modal.dart`, `live_indicator.dart` → `lib/widgets/` · `utils.dart`, `main.dart`, `theme.dart`, `dev_player_harness.dart` → `lib/` · `onboarding_intro.dart` → `lib/screens/onboarding/` · `IvsPlayerCore.kt` → `android/app/src/main/kotlin/com/tommychow/frosty/` · `AndroidManifest.xml` → `android/app/src/main/`.

**Constats de vérification** (par rapport à `ARCHITECTURE.md`, tous confirmés dans le code) :

- Temps réel : IRC, EventAPI 7TV, Hermes anonyme (hype train, highlights), le client Hermes d'ONSET (célébrations, objectifs, points et prédictions ; authentifié par le jeton web pour les sujets du viewer) et, depuis l'épique whispers, EventSub WebSocket avec le jeton utilisateur (`user.whisper.message`).
- Scopes OAuth : `chat:read chat:edit user:read:follows user:read:blocked_users user:manage:blocked_users user:manage:chat_color` puis, depuis l'épique modération, `moderator:manage:banned_users moderator:manage:chat_messages moderator:manage:chat_settings moderator:manage:warnings` (`auth_store.dart:164`). Puis `moderator:read:followers`, `user:manage:whispers` et `user:read:emotes` (fiche utilisateur, whispers, menu d'emotes). Aucun scope `user:read:chat`. **Ajouter un scope oblige à se reconnecter.**
- iOS : `ready` réussit (usher résolu), mais `_createTexture` échoue faute de canal natif. L'échec est avalé par `catchError` (`ivs_video_store.dart:115`) : `onFatalError` n'est jamais appelé et le spinner tourne à l'infini.
- Mots masqués : `chat_store.dart:548-555`. Le `return` abandonne tout le lot IRC en cours, et `split('')` compare caractère par caractère si « mot entier » est désactivé.
- Deep links : `android:autoVerify="true"` sur `twitch.tv`/`www.`/`m.` (`AndroidManifest.xml:40-47`). La vérification échouera toujours, car `assetlinks.json` appartient à Twitch. Android affichera donc un sélecteur ou ouvrira l'app officielle.

## 1. Tableaux par domaine

### Lecture vidéo (PLY)

| ID | Feature | Priorité | Statut | Implémentation frostyv2 (fichier:ligne) | Ce qui manque / remarque | Faisabilité |
|---|---|---|---|---|---|---|
| PLY-01 | Lecture live native | P0 | ⚠️ | `IvsTuning.kt`, `IvsPlayerCore.kt`, `ivs_video_store.dart` (`d4ca773`, `fe2e1c1`) | IVS 1.57 avec la config de session de l'officiel, reprise gérée (C2). Reste : jeton demandé en `platform:"web"`/`playerType:"embed"` au lieu de `android`/`mobile_player` (A/B à mesurer, impact pubs inconnu). À valider sur appareil. | OK |
| PLY-02 | Préchargement du théâtre | P0 | ⚠️ | `ivs_video_store.dart`, `playback_token_cache.dart` (`d4ca773`), `playback_preloader.dart`, `stream_card.dart` | Le lecteur natif est créé en parallèle du jeton, et le jeton est mis en cache jusqu'à son expiration. Le jeton est préchargé dès l'appui sur une carte de live (`PlaybackPreloader`, `onTapDown`) ; le lecteur reprend la requête en cours (`PlaybackTokenCache.pending`) au lieu d'en relancer une. Reste : pas de requête unique jeton + métadonnées + chat comme `TheatrePortalPreloadQuery`. Gain à mesurer sur appareil. | OK |
| PLY-03 | Mode faible latence | P0 | ⚠️ | `IvsTuning.kt`, `ivs_player_config.dart`, `live_edge_guard.dart`, `ivs_video_store.dart`, `video_store.dart` (branche `latency`) | Comme l'officiel : accélération IVS, tampon initial 100 ms, `fast_bread` (2 parties prefetch, sondé), jeton `embed` (pas de pre-roll cousu, sondé). En plus : retour automatique au direct après dérive (> max(5 s, plancher + 2,5 s) pendant 10 s, borné), reprise au direct d'un live en pause ≥ 3 s, mode faible latence forcé dans le lecteur web. Reste : pas de mode « latence normale ». Latence attendue ~2-3,5 s (badge), à mesurer sur appareil. | OK |
| PLY-04 | Statistiques vidéo et latence | P0 | ✅ | `ivs_stats_panel.dart`, `latency_stats.dart`, `IvsPlayerCore.kt` (`bbe7ca3`) | Latence au dixième, visible par défaut ; panneau stats (médiane/p90/max, buffer, débit, images, qualité/codec, faible latence, vitesse, mode, démarrage, rebuffers, sauts au direct). Latence au diffuseur (horodatage PDT), pas glass-to-glass (+ encodeur/ingest ~1 s). À valider sur appareil. | OK |
| PLY-05 | Choix de qualité | P0 | ✅ | `quality_selection.dart`, `ivs_video_store.dart`, `IvsPlayerCore.kt` (`d0c9be5`) | Qualité de la session, sinon sauvegardée, sinon la plus haute (meilleur rendu en premier, 2K en tête), réappliquée après chaque rechargement. À valider sur appareil. | OK |
| PLY-06 | Son et volume | P0 | ✅ | `ivs_video_store.dart` (`_onAudioFocus`), `audio_focus.dart`, `AudioFocusBridge.kt`, `video_overlay.dart`, `IvsPlayerCore.kt` (`d0c9be5`) | Mute (paysage + feuille) et volume, conservés en mini-player/PiP/rechargement. Un seul lecteur audible entre le live et les VOD (`playback_focus.dart`, `55ffb66`). Focus audio Android pour le live : un appel ou une autre appli met en pause (reprise à la fin d'un appel), un casque débranché aussi ; le système baisse le son pour une notification. VOD sans focus audio. À valider sur appareil. | OK |
| PLY-07 | Plein écran, ajuster, rogner, zoom | P0 | ✅ | `video_overlay.dart`, `ivs_video.dart`, `pinch_to_fill.dart`, `channel.dart` | Plein écran immersif, ajuster/remplir par bouton ou en pinçant la vidéo (écarter remplit, pincer ajuste ; événements bruts, sans gêner tap, double tap ni glisser vers le PiP). IVS en paysage seulement. | OK |
| PLY-08 | Overlay de métadonnées | P0 | ✅ | `stream_info_bar.dart:13-220`, `video_overlay.dart:424-472` | Titre, catégorie, uptime, spectateurs. Tags absents. | OK |
| PLY-09 | État du live en temps réel | P0 | ✅ | `live_state_watcher.dart`, `ivs_video_store.dart` (`_onLiveChange`, `_justWentLive`), `channel.dart` | Connecté : EventSub `stream.online` (aucun scope). Le lecteur hors ligne redémarre tout seul quand la chaîne repasse en live (3 s pour que la playlist existe) ; pendant 90 s après l'événement, une réponse « hors ligne » (Helix en retard, playlist pas prête) est réessayée toutes les 3 s hors du budget de reprise, même si l'événement arrive pendant une reprise. Après une coupure, il vérifie s'il a manqué un retour. Hors ligne, connecté ou non, le lecteur revérifie aussi la chaîne chaque minute. `stream.offline` n'est pas suivi (le lecteur le voit d'abord, et chaque sujet coûte sur un budget de 10). Anonyme : sondage Helix comme avant. | OK |
| PLY-10 | Fin de diffusion, chaîne hors ligne | P0 | ✅ | `ivs_recovery.dart`, `ivs_video_store.dart` (`_settleFailedStart`, `offlineAtStart`), `channel.dart` | Une erreur « non disponible » confirmée hors ligne par Helix affiche l'état hors ligne au lieu de basculer sur la WebView, et une chaîne déjà hors ligne à l'ouverture garde aussi le lecteur natif (seulement si Helix confirme : sinon WebView). Bouton « Past broadcasts » (`46b4ed2`) ; redémarrage automatique au retour en live si connecté (PLY-09). | OK |
| PLY-11 | Erreurs et relance du flux | P0 | ✅ | `ivs_recovery.dart`, `ivs_video_store.dart`, `channel.dart` (`4d50b89`) | Erreurs classées, relance 1/2/4 s sur le même lecteur avec nouvelle URL, « ↻ n/3 », jeton neuf si refusé, repli WebView après 3 échecs en 60 s ou erreur fatale ; IVS seulement sur Android. À valider sur appareil. | OK |
| PLY-12 | Audio seul | P1 | ✅ | `twitch_stream_service.dart` (`allow_audio_only`), `quality_selection.dart`, `ivs_video.dart` | Qualité « Audio only » dans le menu (comme l'appli officielle : usher `allow_audio_only=true`, jamais choisie par l'adaptatif), pastille sur l'image ; non mémorisée d'un stream à l'autre. Pas encore en arrière-plan (PLY-14). | OK |
| PLY-13 | Chat seul | P1 | ✅ | `settings_store.dart:77-79`, `channel.dart:492-573` | Réglage global « Enable video ». Pas de paramètre de deep link. | OK |
| PLY-14 | Audio en arrière-plan | P1 | ✅ | `BackgroundAudioService.kt`, `background_audio.dart`, `ivs_video_store.dart`, `video_settings.dart` | Réglage « Background audio » (Vidéo, Android, désactivé par défaut) : un service de premier plan `mediaPlayback` garde le live audible hors de l'appli ou écran éteint, avec une notification média. Live IVS seulement (pas les VOD ni le lecteur web). À valider sur appareil. | OK |
| PLY-15 | Contrôles média et casque | P1 | ✅ | `BackgroundAudioService.kt` (`MediaSession`), `ivs_video_store.dart` (`_onMediaCommand`) | Avec l'audio en arrière-plan : MediaSession (écran verrouillé, casque, Bluetooth) et notification lecture/pause et arrêt, qui pilotent le lecteur ; « Stop » met en pause et retire la notification jusqu'à la prochaine lecture. À valider sur appareil. | OK |
| PLY-16 | PiP natif Android | P1 | ✅ | `ivs_video_store.dart:119-130,270-275`, `channel.dart:845`, `video_overlay.dart:521-544` | Auto-PiP Android 12+ pour IVS uniquement. | OK |
| PLY-17 | Lecteur pop-out flottant | P1 | ❌ | — | Pas de fenêtre `SYSTEM_ALERT_WINDOW` (le PiP couvre l'essentiel). | OK |
| PLY-18 | Mini-lecteur intégré | P1 | ✅ | `mini_player_store.dart:41-58`, `global_mini_player.dart:18-202`, `channel.dart:275-293` | Déplaçable, aimanté aux coins, chat conservé. Moteur IVS seulement (les autres basculent en PiP). | OK |
| PLY-19 | Modes de chat en paysage | P1 | ➕ | `channel.dart:407-439,576-805`, `settings_store.dart:249-267` | Colonne gauche/droite à largeur réglable, overlay à opacité réglable, masqué. Cycle au double-tap, gestion de l'encoche. | OK |
| PLY-20 | Taille du chat en portrait | P1 | ✅ | `portrait_split.dart`, `channel.dart` | Poignée entre vidéo et chat : glisser réduit la vidéo jusqu'à 40 % de la largeur sur tablette (au moins 300 dp, pour garder les contrôles et la latence lisibles), double tap la remet en pleine largeur ; taille mémorisée (`portraitVideoScale`). | OK |
| PLY-21 | Disposition verticale / classique (dual format) | P1 | ❌ | — | Ni `multigroup_video` ni usher `/api/v2/`. | OK |
| PLY-22 | Minuteur de veille | P1 | ✅ | `chat_details.dart:70-150`, `chat_store.dart:1296-1325` | — | OK |
| PLY-23 | Sous-titres (CC) | P1 | ✅ | `IvsPlayerCore.kt` (`setCaptions`, `setTextTrack`, évènement `textTracks`, `onCue`), `captions.dart`, `stores/caption_store.dart`, `caption_menu.dart`, `ivs_video.dart`, `video_overlay.dart`, `vod/widgets/vod_video.dart`, `vod/vod_overlay.dart`, `settings/widgets/caption_style_setting.dart` | Interrupteur « Closed Captions » comme Twitch (feuille du lecteur live, feuille de la VOD, Réglages › Vidéo). Ajouts ONSET : choix de la piste quand le flux en offre plusieurs (la langue choisie est reprise au flux suivant), taille (Small à Extra large) et fond (Black, Translucent, None) de la ligne ; par défaut celle de Twitch, blanc 15 sur noir. VOD IVS couvertes. Android seulement (IVS). À valider sur un stream et une VOD sous-titrés. | OK |
| PLY-24 | Chromecast | P1 | ❌ | — | Pas de Cast SDK. Le récepteur Twitch est propriétaire, mais le Default Media Receiver peut lire l'URL usher. | OK |
| PLY-25 | Écran de garde classification (CCL) | P1 | ✅ | `content_warning_gate.dart`, `content_labels.dart`, `models/channel.dart`, `video_settings.dart` | Avertissement au texte de l'appli officielle (« Just one second… », « <chaîne>'s content is intended for certain audiences. », « It may contain: … », « Start watching », « Go back ») tant qu'on n'a pas touché « Start watching », quand la chaîne porte des labels (Helix `content_classification_labels`). Aussi avant une VOD, avec les labels de la vidéo elle-même comme l'officiel (`getContentLabels`), le lecteur n'étant créé qu'après acceptation. Accepté une fois par session et par chaîne, partagé live/VOD (l'officiel garde l'acceptation par label et la persiste) ; réglage « Warn about mature content » (actif). Échec ou lenteur (> 3 s) de requête = pas de blocage. Si l'avertissement web de Twitch reste à l'écran dans un lecteur web, nos contrôles s'effacent pour qu'il soit touchable ; en live comme en VOD web, il n'est cliqué qu'avec l'accord du viewer (réglage coupé, chaîne acceptée, ou « Start watching » sur le nôtre). | OK |
| PLY-26 | Live réservé aux abonnés + aperçu gratuit | P1 | ⚠️ | `twitch_stream_service.dart` (`refusalFor`), `playback_access_token.dart` (`PlaybackRefusal`), `ivs_video_store.dart` (`_failExplained`), `channel.dart` | Le jeton demande `authorization.forbiddenReasonCode` : un 403 sur un live réservé aux abonnés (ou géobloqué, ou chaîne qui a banni le viewer) passe tout de suite au lecteur web (plus de 3 rechargements inutiles) avec « X is streaming for subscribers only. Trying the web player. ». Pas de bannière ni de minuteur d'aperçu gratuit natifs ; l'abonné passe par le lecteur web (jeton natif anonyme). À valider sur appareil. | OK |
| PLY-27 | Erreurs de lecture usher | P1 | ⚠️ | `twitch_stream_service.dart` (`usherRefusal`), `ivs_video_store.dart` | Après des jetons refusés sans raison connue, la playlist usher est relue une fois (4 s max) et son message d'erreur (région, proxy, VPN…) est affiché en basculant vers le lecteur web. Messages de Twitch tels quels, en anglais ; pas de cas « Wi-Fi exigé » ou DRM (contenus premium seulement). | OK |
| PLY-28 | Contenu premium DRM | P2 | ❌ | — | Licences Widevine/PlayReady délivrées par KeyOS pour Twitch. | Impossible proprement |
| PLY-29 | Proposition de version en langue locale | P2 | ❌ | — | Confiance faible dans le catalogue. | GQL privé |
| PLY-30 | Signaler un problème de lecture | P2 | ❌ | — | — | GQL privé |
| PLY-31 | Publicités vidéo (SSAI) | P2 | ❌ | — | Aucune gestion des pubs : les segments SSAI sont lus tels quels, sans overlay. | Impossible proprement |
| PLY-32 | Pubs interactives, display, picture-by-picture | P2 | ❌ | — | SDK et serveurs pub Twitch. | Impossible proprement |
| PLY-33 | Transparence publicitaire (DSA) | P2 | ❌ | — | Lié à la diffusion des pubs. | Impossible proprement |

### Chat (CHT)

| ID | Feature | Priorité | Statut | Implémentation frostyv2 (fichier:ligne) | Ce qui manque / remarque | Faisabilité |
|---|---|---|---|---|---|---|
| CHT-01 | Connexion au chat | P0 | ✅ | `chat_store.dart:884-1005,1058-1061,678-679` | Anonyme `justinfan888`, PING/PONG, 5 tentatives avec backoff. `RECONNECT` non géré explicitement. | OK |
| CHT-02 | Historique récent | P0 | ✅ | `chat_store.dart:402-405,1328`, `twitch_api.dart:460`, `irc.dart:165` | Via `recent-messages.robotty.de` (tiers), avec marqueur d'historique. | OK |
| CHT-03 | Envoi de message | P0 | ✅ | `chat_store.dart`, `chat_bottom_bar.dart`, `chat_character_counter.dart` | Envoi IRC confirmé par USERSTATE, rejets en toast ; saisie limitée à 500 caractères avec compte à rebours des 50 derniers (épopée E7). | OK |
| CHT-04 | Réponses et fils | P0 | ✅ | `chat_store.dart:1187,1226-1230`, `chat_message.dart:192,251-263`, `reply_thread.dart` | — | OK |
| CHT-05 | Mentions | P0 | ⚠️ | `irc.dart` (`mentionsUser`), `chat_message.dart:315-316`, `mention_alerts.dart`, `chat_store.dart`, `mention_notification_setting.dart` | Mention détectée comme mot entier (avec ou sans @), plus de faux positifs (E7). Notification locale « Chat Mentions » quand un chat connecté mentionne le viewer et que l'appli est en arrière-plan ou en PiP (réglage activé par défaut, une par chaîne toutes les 30 s, ni historique ni ses propres messages), listée dans Activity. Pas de push quand l'appli est fermée (FCM de Twitch). | OK |
| CHT-06 | Autocomplétion | P0 | ✅ | `chat_bottom_bar.dart`, `chat_commands.dart` | Emotes (tous fournisseurs), @mentions et commandes `/` (E7). | OK |
| CHT-07 | Menu d'un message | P0 | ✅ | `chat_message.dart:102-200,599`, `user_actions_modal.dart:36-151` | Copier, copier-coller, répondre. Les actions sur l'utilisateur passent par le pseudo. | OK |
| CHT-08 | Défilement auto et nouveaux messages | P0 | ✅ | `chat_store.dart:221`, `chat_tabs_store.dart:151-252` | Pastille « N new messages ». | OK |
| CHT-09 | Rendu des messages supprimés | P0 | ➕ | `irc.dart:106-127`, `chat_message.dart:342-403` | Le contenu supprimé reste révélable au tap pour tous ; l'officiel le réserve aux mods. | OK |
| CHT-10 | Rendu des timeouts et bans | P0 | ✅ | `irc.dart` (`clearChat`), `chat_message.dart`, `moderation_notice.dart`, `chat_store.dart` (`_addModerationNotice`) | Messages marqués avec la durée, contenu révélable, et ligne « X has been timed out for 10 minutes. » / « X has been permanently banned. » à l'heure de Twitch, même sans message visible (réglage « Show timeouts and bans », actif par défaut). | OK |
| CHT-11 | Affichage des messages supprimés (option) | P1 | ➕ | `settings_store.dart:202-204`, `chat_settings.dart:147`, `chat_message.dart:380-388` | Réglage local plus révélation au cas par cas. | OK |
| CHT-12 | Restriction : timeout ou ban (côté viewer) | P0 | ✅ | `chat_restrictions.dart`, `chat_restriction_bar.dart` | Le CLEARCHAT qui vise son propre compte (ou le rejet `msg_timedout`/`msg_banned`) verrouille la saisie avec un compte à rebours ; le ban reste jusqu'à un envoi réussi (E7). | OK |
| CHT-13 | Avertissement (côté viewer) | P0 | ❌ | — | L'acquittement existe seulement en GQL (`AcknowledgeChatWarning`). | GQL privé |
| CHT-14 | Demande de déban (côté viewer) | P1 | ❌ | — | Helix `/moderation/unban_requests` est réservé aux mods ; la création d'une demande passe par GQL. | GQL privé |
| CHT-15 | Bannières de restriction de mode | P0 | ✅ | `chat_restrictions.dart`, `chat_bottom_bar.dart` | Mode lent : saisie verrouillée avec le temps restant après un envoi ; emotes seules, abonnés, followers (durée) dans le texte d'aide de la saisie. Modérateurs, VIP et diffuseur exemptés (E7). | OK |
| CHT-16 | Règles du chat | P1 | ✅ | `apis/twitch_chat_rules_service.dart`, `models/chat_rules.dart`, `chat/stores/chat_rules_store.dart`, `chat/widgets/chat_rules_sheet.dart`, `chat.dart`, `details/chat_details.dart` | Requête `ChatRules` de l'appli officielle, en GQL anonyme (testée le 2026-10-20). Comme Twitch : la première fois qu'un viewer connecté touche le champ du chat d'une chaîne qui a des règles, la feuille « Chat Rules » s'ouvre à la place du clavier ; « OK, Got it! » est retenu sur l'appareil par viewer et par chaîne. Ajout ONSET : entrée « Chat rules » dans le menu du chat pour les relire. Pas la variante « unbanned » (demandes de débannissement privées). Échec de la requête : rien n'est montré. | GQL privé |
| CHT-17 | Commandes slash (viewer) | P0 | ✅ | `chat_commands.dart`, `chat_store.dart` | `/me`, `/color` (noms Twitch ou hex), `/block`, `/unblock`, `/w`, `/help` exécutées par l'appli (Helix), plus les commandes de modération (MOD-08). Les commandes diffuseur non faites (`/mod`, `/vip`, `/raid`, `/commercial`, `/announce`…) expliquent qu'elles ne sont pas disponibles au lieu de partir en texte. | OK |
| CHT-18 | Annonces | P0 | ✅ | `chat_message.dart`, `announcement_color.dart` | Rendu « Announcement » avec la couleur `msg-param-color` (bleu, vert, orange, violet) (E7). | OK |
| CHT-19 | Badges | P0 | ✅ | `twitch_api.dart:83-123`, `irc.dart:248-300` | Badges Twitch plus FFZ/BTTV. Badges 7TV codés mais jamais alimentés (`chat_assets_store.dart:94-96`). | OK |
| CHT-20 | Sélecteur d'emotes | P0 | ➕ | `chat.dart:261-337` | Récents, Twitch (emotes sub grisées), 7TV, BTTV, FFZ. | OK |
| CHT-21 | Rendu des emotes et types | P0 | ➕ | `irc.dart:950-1154`, `chat_assets_store.dart:153-230` | Plages `emotes` plus 7TV/BTTV/FFZ (zero-width, alias) et mises à jour live 7TV (`chat_store.dart:797-881`). | OK |
| CHT-22 | Carte d'emote | P1 | ⚠️ | `irc.dart` (`showEmoteDetailsBottomSheet`), `emotes.dart` (`unlockHint`, `subTier`) | Fiche avec nom, source, auteur, copier, ouvrir et condition de déblocage des emotes Twitch (palier d'abonnement Helix, follow, Bits). Ni emotes liées, ni signalement. | OK |
| CHT-23 | Emotes follower | P1 | ✅ | `twitch_api.dart` (`getUserEmotes`, `getUsersByIds`), `chat_assets_store.dart` (`userEmotesFromHelix`), `chat_store.dart` (`_loadUserEmotes`) | Le menu d'emotes et l'autocomplétion reçoivent toutes les emotes utilisables (Helix `GET /chat/emotes/user`, `user:read:emotes`) : abonnements partout, emotes follower de la chaîne, débloquées et globales, rangées par chaîne. Un ancien jeton sans le scope échoue sans dialogue et retombe sur les sets de GLOBALUSERSTATE. | OK |
| CHT-24 | Modificateurs d'emotes | P2 | ❌ | — | — | GQL privé |
| CHT-25 | Animation des emotes et GIF | P1 | ✅ | `emotes.dart` (`staticUrl`, `urlFor`), `irc.dart`, `chat_settings.dart` | Réglage local « Animate emotes » : éteint, le chat (live, replay, réponses, épinglé) affiche l'image fixe fournie par Twitch, 7TV, BTTV ou FFZ. Réglage distinct « Animated GIFs » pour les GIF (CHT-26). Non synchronisés avec le compte. | OK |
| CHT-26 | GIF dans le chat (GIPHY) | P2 | ⚠️ | `chat_gif.dart`, `irc.dart` (`gifParts`), `chat_gif_image.dart`, `first_frame_image.dart`, `chat_settings.dart` | Affichage au comportement de l'appli Twitch : tag `gifs`, GIF sous le pseudo à la place de son titre (128 px, 72 en paysage ou en surimpression), réglages « Show GIFs in Chat » et « Animated GIFs », fiche au tap. Écarts voulus : seulement `https` sur giphy.com ou jtvnw.net, titre affiché en cas d'échec, « Reply » gardé. Manque l'envoi (onglet GIF, palier 2+) et « Report GIF ». | GQL privé |
| CHT-27 | Couleurs lisibles et contraste | P1 | ✅ | `utils.dart:19-47`, `irc.dart:416` | Ajustement automatique du contraste, sans option. | OK |
| CHT-28 | Masquer le langage offensant | P1 | ✅ | `settings_muted_words.dart`, `muted_words.dart`, `chat/chat_filters.dart` | Mots masqués manuels conservés (mot entier ou sous-chaîne, expressions). Le masquage AutoMod de Twitch est couvert par les filtres de CHT-29 (catégorie Profanity). | OK |
| CHT-29 | Filtres de chat personnels | P1 | ✅ | `chat/chat_filters.dart`, `models/irc.dart` (`textAsSent`, `isFiltered`, `shownText`), `chat/widgets/chat_message.dart`, `chat/widgets/filtered_message_sheet.dart`, `settings/widgets/chat_filters_setting.dart` | « Edit Chat Filters » dans Réglages › Chat, libellés de Twitch : « Enable filtering in chat », Discrimination, Sexually Explicit Language, Harassment, Profanity. Lit la balise IRC `flags` comme `ac6.java` : un mot noté 3 ou plus dans une catégorie active devient des `*` ; un toucher ouvre « Message Blocked », « Show Message » le révèle. Une emote Twitch reste une emote ; rien n'est filtré dans une chaîne modérée par le viewer. `flags` vérifiée le 2026-10-20 sur une connexion anonyme (justinfan). Pas pour le replay des VOD ni les notices d'abonnement. | OK |
| CHT-30 | Menu des réglages du chat | P0 | ✅ | `chat_details.dart`, `chat_settings.dart`, `chat_mode_controls.dart` | Menu « More » et page des réglages du chat, avec pour les modérateurs l'entrée « Chat modes » (modes du salon, vider le chat). | OK |
| CHT-31 | Couleur du pseudo | P1 | ✅ | `chat_details.dart:351-355,573-611`, `twitch_api.dart:419-458` | 15 couleurs nommées. Ni hex (Turbo/Prime) ni `/color`. | OK |
| CHT-32 | Badge affiché | P1 | ❌ | — | — | GQL privé |
| CHT-33 | Progression des badges | P2 | ❌ | — | — | GQL privé |
| CHT-34 | Délai de chat (sync vidéo) | P1 | ➕ | `settings_store.dart` (`autoSyncChatDelay`, `chatSyncDefaultApplied`), `chat_store.dart`, `chat_delay_queue.dart`, `ivs_video_store.dart` | Synchronisé sur la latence mesurée **par défaut** (natif : chaque seconde ; web : toutes les 60 s), activé une fois pour les réglages sans délai manuel ; délai manuel 0-30 s sinon. Ordre d'arrivée garanti quand le délai baisse. Ses propres messages et les notices passent sans délai. Le délai imposé par la chaîne n'est pas lu. | OK |
| CHT-35 | Horodatage des messages | P1 | ✅ | `settings_store.dart:210-215`, `irc.dart:130-140` | — | OK |
| CHT-36 | Notices d'abonnement et de gift | P0 | ✅ | `user_notice_row.dart`, `user_notice.dart`, `user_notice_text.dart`, `user_notice_presentation.dart`, `gift_bomb_tracker.dart` | Rangée de notice au style de l'appli Android de Twitch (barre d'accent, icône, phrase, message du viewer), en vert là où Twitch met du violet ; libellés de Twitch pour subs, resubs, gifts (mois offerts, anonymes), Prime, raids, objectifs de subs ; gift sponsorisé teinté à la couleur du sponsor ; notice gardée si son message est supprimé ou son auteur banni ; chaque gift d'un gift bomb est affiché, avec l'option « Collapse gift bombs ». Aussi dans le chat en surimpression. | OK |
| CHT-37 | Partage d'anniversaire de resub | P2 | ❌ | — | — | GQL privé |
| CHT-38 | Callouts privés | P1 | ❌ | — | Topic privé. | GQL privé |
| CHT-39 | Notice de don caritatif | P2 | ✅ | `chat_message.dart:447-475` | Rendu générique de `system-msg` (`charitydonation`). | OK |
| CHT-40 | Chat partagé (Shared Chat) | P1 | ➕ | `twitch_api.dart:400-418`, `irc.dart:187`, `chat_tabs_store.dart:73-121` | Avatar de la chaîne source, plus **multi-chat** (10 onglets, vue fusionnée). Un ban partagé n'est pas signalé. | OK |
| CHT-41 | Pile de « highlights » communautaires | P1 | ✅ | `channel/channel_top_overlays.dart`, `community_highlights/highlight_stack.dart` | Deux étages au-dessus du chat (E5) : Hype Train, puis une carte communautaire avec pagination « 1 / 3 » et pastille « New » ; ordre par récence comme le réducteur web de Twitch. Repliée sur téléphone, dépliée sur tablette ; pastille sur la vidéo quand le chat est masqué ; fermeture par carte. | GQL privé |
| CHT-42 | Messages épinglés (lecture) | P1 | ✅ | `community_highlights/widgets/pinned_chat_text.dart` | Carte « Pinned » (E5) : auteur avec badges et couleur, emotes Twitch et 7TV/BTTV/FFZ via les assets du chat, épinglé par, fin. GQL anonyme `pinnedChatMessages` + `pinned-chat-updates-v1.<id>` ; expiration locale (aucun événement Twitch). | GQL privé |
| CHT-43 | Messages épinglés payants et cheers épinglés | P2 | ❌ | — | — | GQL privé |
| CHT-44 | AutoMod (côté émetteur) | P1 | ✅ | `held_messages.dart` (`HeldMessageWatcher`), `chat_store.dart` (`_watchHeldMessages`) | `msg_rejected` en toast quand AutoMod retient le message (IRC), puis notice dans le chat quand les modérateurs l'approuvent, le refusent ou qu'il expire (EventSub `channel.chat.user_message_update`, scope `user:read:chat`, reconnexion nécessaire), avec le message cité sur une ligne. À valider sur appareil. | OK |
| CHT-45 | Cartes clip et vidéo dans le chat | P1 | ✅ | `chat_link_card.dart`, `chat_message.dart`, `utils/link_router.dart` | Carte de hauteur fixe sous le message (miniature, titre, chaîne, durée, vues ; GQL anonyme, cache des 64 derniers), ouverte dans l'appli. Réglage « Preview clips and videos ». | OK |
| CHT-46 | Liste des spectateurs (chatters) | P1 | ⚠️ | `chat_users_list.dart:16-200`, `chat_details_store.dart:39` | Seulement les pseudos vus en IRC, sans rôles. Helix `GET /chat/chatters` exige `moderator:read:chatters` et un rôle mod ; sinon GQL. | Compte requis |
| CHT-47 | Effets de message animés | P2 | ❌ | — | — | GQL privé |
| CHT-48 | Chat hors ligne | P1 | ✅ | `channel.dart:556-559` | L'IRC ne dépend pas du live. | OK |

### Interactions communautaires (INT)

| ID | Feature | Priorité | Statut | Implémentation frostyv2 (fichier:ligne) | Ce qui manque / remarque | Faisabilité |
|---|---|---|---|---|---|---|
| INT-01 | Sondages (vote) | P1 | ⚠️ | `community_highlights/widgets/highlight_cards.dart` | Lecture en direct (épopée E5) : question, barres et %, votes, temps restant, résultats finaux puis disparition. GQL anonyme `viewablePoll` + sujet Hermes public `polls.<id>`. Voter : bouton « Vote on Twitch » sur la carte ouverte, qui ouvre le chat de la chaîne sur twitch.tv dans l'appli (E9) ; pas de vote natif (mutation réservée à twitch.tv, protégée par `Client-Integrity`). | GQL privé |
| INT-02 | Prédictions (parier) | P1 | ⚠️ | `community_highlights/widgets/highlight_cards.dart` | Lecture en direct (E5) : 2 à 10 issues avec couleurs, points, participants, cote « 1:x » et meilleurs parieurs ; verrouillée, en attente, gagnante, remboursée. GQL anonyme + `predictions-channel-v1.<id>`. Pari natif depuis la feuille des points (`channel_points_sheet.dart`, portage ONSET) : mise minimale 10, préréglages, Max, mutation GQL `makePrediction` avec le jeton web du viewer, jamais automatique ; Twitch peut la refuser (contrôle d'intégrité, refus affiché tel quel) : à valider sur appareil. « Predict on Twitch » reste disponible (E9). | GQL privé |
| INT-03 | Conditions des prédictions | P1 | ❌ | — | — | GQL privé |
| INT-04 | Points de chaîne : solde et gains | P1 | ⚠️ | `channel_points_button.dart`, `channel_points_sheet.dart`, `channel_events_store.dart`, `twitch_points_service.dart` | Solde natif (portage ONSET) en bas à gauche du chat, au format de Twitch (1.5K, 1M), avec l'icône de la chaîne ; lu par GQL avec le jeton web (session twitch.tv), rafraîchi après un événement Hermes de points (regroupés sur 2 s) et chaque minute si connecté. Pas d'animation de gain. Le menu « More » ouvre toujours la page twitch.tv. | GQL privé |
| INT-05 | Bonus à réclamer | P1 | ⚠️ | `channel_points_sheet.dart` (`_ClaimButton`), `channel_events_store.dart` (`claimBonus`) | Le coffre disponible est détecté (icône cadeau sur le bouton des points, bouton « Collect bonus »), mais Twitch refuse la réclamation hors de ses clients (`failed integrity check`, mesuré) : après un refus le bouton laisse place à une explication et renvoie vers twitch.tv. Aucun contournement de `Client-Integrity`. | GQL privé |
| INT-06 | Récompenses intégrées | P1 | ⚠️ | `community_points.dart` (`tryParseAutomatic`), `channel_points_sheet.dart` | Listées dans la feuille des points avec le nom de Twitch et leur coût (les power-ups payés en Bits, sans coût en points, sont écartés), mais pas échangeables : chacune exige un sélecteur (emote) que l'appli n'a pas. Les messages surlignés reçus sont rendus (`chat_message.dart:222`). | GQL privé |
| INT-07 | Récompenses personnalisées | P1 | ⚠️ | `channel_points_sheet.dart`, `twitch_points_service.dart` (`redeemReward`) | Liste de la chaîne (actives seulement, triées par coût, couleur et image) ; échange après confirmation, texte demandé si la récompense l'exige, mutation GQL `redeemCommunityPointsCustomReward` avec le jeton web et un identifiant de transaction par dépense ; un second appui pendant l'envoi est refusé. Acceptation par Twitch à valider sur appareil (refus d'intégrité affiché tel quel). | GQL privé |
| INT-08 | Power-ups (Bits) | P2 | ❌ | — | Paiement en Bits. | Impossible proprement |
| INT-09 | Objectifs communautaires (challenges) | P2 | ❌ | — | — | GQL privé |
| INT-10 | Objectifs créateur (sub goals) | P1 | ❌ | — | EventSub `channel.goal.*` exige `channel:read:goals` (diffuseur). | GQL privé |
| INT-11 | Rendu des cheermotes | P1 | ✅ | `cheermote.dart`, `chat_assets_store.dart` (`cheermotes`), `irc.dart` | Helix `GET /bits/cheermotes` par chaîne (globaux et personnalisés). Dans un message de cheer (tag `bits`), `Cheer100` devient l'image du palier atteint (animée ou non, thème sombre ou clair) suivie du montant à la couleur du palier ; ailleurs le mot reste du texte, comme Twitch. Images acceptées seulement depuis les hôtes Twitch. | OK |
| INT-12 | Cheer (envoyer des Bits) | P2 | ❌ | — | Dépense de Bits (argent réel). | GQL privé |
| INT-13 | Campagnes de bonus Bits | P2 | ❌ | — | — | GQL privé |
| INT-14 | Combos (Bits en un tap) | P2 | ❌ | — | — | GQL privé |
| INT-15 | Hype Train | P1 | ✅ | `lib/screens/channel/hype_train/` (store, bannière, feuille), `lib/apis/twitch_hype_train_service.dart`, `lib/services/realtime/` | Anonyme : état initial par GQL `GetHypeTrainExecution` (vérifié en direct) puis événements Hermes `hype-train-events-v2.<id>` ; approche, départ, niveaux avec % et minuteur (horloge serveur), contributions importantes, conducteurs, récompenses par niveau, fin et bande de récompenses 20 s, repli à expiration + 10 s, sondage GQL toutes les 20 s si le temps réel tombe. Mis au style de Twitch (bannières par défaut et compacte, feuille de détails, pastilles, bandes de fin) en vert là où Twitch met du violet (`hype_train_tokens.dart`, `hype_train_palette.dart`). Réglage « Show Hype Trains ». Pas de bouton d'achat (D4). À valider sur appareil. | GQL privé |
| INT-16 | Variantes de Hype Train | P2 | ✅ | `hype_train/widgets/effects/` | Golden Kappa, Treasure (pièce + cadenas), Community (fusée), Mythic (roulette + révélation), record historique (trophée), pinata rendu comme régulier ; effets redessinés au style de Twitch. Formes Golden/Treasure/record vérifiées en direct ; Community/Mythic d'après la RE (non observées). | GQL privé |
| INT-17 | Hype Train partagé | P2 | ✅ | `hype_train_reducer.dart`, `hype_train_sequence.dart` | Train partagé vérifié en direct (GQL `sharedHypeTrainDetails`) : avatars, top 3, arc-en-ciel, fusion et départ d'une chaîne (formes d'événements non observées). | GQL privé |
| INT-18 | Récompenses partagées | P2 | ❌ | — | — | GQL privé |
| INT-19 | Raids (côté viewer) | P1 | ✅ | `chat_message.dart:447-460`, `community_highlights/widgets/highlight_cards.dart`, `community_highlights_store.dart` (`onGoAlong`, `stayOnRaid`) | Notice de raid entrant (USERNOTICE). Raid sortant (E5, sujet public `raid.<id>`) : « Raiding <cible> with N viewers », compte à rebours, « Watch <cible> » ouvre la chaîne dans l'appli, et le viewer suit le raid à son départ comme sur Twitch (« Stay here » pour rester ; pas depuis une VOD ou le PiP). À valider sur un vrai raid. | OK |
| INT-20 | Shoutouts (côté viewer) | P1 | ❌ | — | EventSub `channel.shoutout.*` exige `moderator:read:shoutouts`. | GQL privé |
| INT-21 | Séries de visionnage (watch streaks) | P1 | ⚠️ | `twitch_watch_streak_service.dart`, `models/watch_streak.dart`, `channel_points_sheet.dart` (`WatchStreakCard`), `channel_events_store.dart` (`refreshWatchStreak`), `watch_streak_tag.dart` | Lecture seule, avec le jeton web : carte en tête de la feuille des points comme Twitch (`WatchStreakMilestoneQuery` : « Your Watch Streak: N », prochain palier et son bonus, état suspendu en live ou hors ligne avec le temps restant, N/palier), lue à l'ouverture de la chaîne et de la feuille (1 fois par minute au plus, 10 min après un échec), et tag « Watch Streak N » sur les cartes suivies (`BatchGetWatchStreaksQuery`). Rien n'est affiché sur un échec, un refus ou un opt-out. Ni partage dans le chat ni « Save Streak » (mutations). L'appli n'envoie aucun événement de visionnage : regarder ici ne fait sans doute pas avancer la série, et la carte le dit. | GQL privé |
| INT-22 | Récompenses hebdomadaires | P2 | ❌ | — | — | GQL privé |
| INT-23 | Moments communautaires | P2 | ❌ | — | — | GQL privé |
| INT-24 | Classements | P2 | ❌ | — | Helix `/bits/leaderboard` est réservé au diffuseur. | GQL privé |
| INT-25 | Célébrations à l'écran | P2 | ✅ | `celebration_overlay.dart`, `celebration.dart`, `channel_events_store.dart`, `hermes_client.dart` | Portage ONSET : sujet Hermes `celebration-events-v1.<id>` (gifts de la communauté, alertes du diffuseur) ; cinq effets en animation Lottie recolorée, taille et opacité selon l'intensité, zone chat/vidéo/partout respectée, durée bornée à 0,5-15 s, jamais deux fois le même événement, jamais interactive. Réglage « Show celebrations ». À valider sur un vrai gift. | GQL privé |
| INT-26 | Drops en stream | P1 | ❌ | — | Intégrité exigée : risque élevé. | GQL privé |
| INT-27 | Campagnes et inventaire de drops | P1 | ❌ | — | Intégrité exigée : risque élevé. | GQL privé |
| INT-28 | Extensions | P2 | ❌ | — | Exige un JWT d'extension et l'helper Twitch. | Impossible proprement |
| INT-29 | Stream Together : demande à rejoindre | P2 | ❌ | — | Guest Star repose sur du WebRTC propriétaire. | Impossible proprement |
| INT-30 | Liste des co-streamers et invités | P2 | ❌ | — | — | GQL privé |
| INT-31 | Alerte de resub personnalisée | P2 | ❌ | — | — | GQL privé |

### Modération (MOD)

| ID | Feature | Priorité | Statut | Implémentation frostyv2 (fichier:ligne) | Ce qui manque / remarque | Faisabilité |
|---|---|---|---|---|---|---|
| MOD-01 | Actions de modération rapides [M] | P0 | ✅ | `chat_moderation_bar.dart`, `chat_user_modal.dart`, `moderation.dart` (`ChatModeration`), `chat_store.dart` (`moderate`, `canModerate`) | Barre Timeout (1 s purge → 2 semaines) / Ban / Unban / Warn dans la fiche, visible si mod (USERSTATE) ou diffuseur, cachée sur soi et le diffuseur. Résultat sous la barre et en ligne de chat. Scopes `moderator:*` demandés à la connexion : un ancien jeton reçoit un 401 → dialogue « Log in again ». | Compte requis |
| MOD-02 | Bannir avec motif [M] | P0 | ✅ | `twitch_api.dart` (`banUser`), `chat_moderation_bar.dart` (dialogue de motif) | Confirmation avec motif facultatif (500 caractères max). | Compte requis |
| MOD-03 | Timeout avec durée [M] | P0 | ✅ | `twitch_api.dart` (`banUser` + `duration`), `chat_moderation_bar.dart` (`kTimeoutPresets`) | Durées de 1 s à 14 jours, refusées hors bornes. | Compte requis |
| MOD-04 | Débannir, fin de timeout [M] | P0 | ✅ | `twitch_api.dart` (`unbanUser`) | Bouton Unban et `/unban`, `/untimeout`. | Compte requis |
| MOD-05 | Avertir [M] | P0 | ✅ | `twitch_api.dart` (`warnUser`) | Motif obligatoire (dialogue et `/warn`). | Compte requis |
| MOD-06 | Supprimer un message [M] | P0 | ✅ | `twitch_api.dart` (`deleteChatMessages`), `chat_message.dart` (`_canDelete`) | « Delete message » dans l'appui long, sauf messages du diffuseur et d'une autre chaîne du chat partagé. `/delete <id>`. | Compte requis |
| MOD-07 | Modes de chat [M] | P0 | ✅ | `twitch_api.dart` (`updateChatSettings`, verbe `patch`), `chat_mode_controls.dart`, `chat_details.dart` | Feuille « Chat modes » : interrupteurs lent (3–120 s), followers (0 → 3 mois), abonnés, emotes, unique ; l'état suit ROOMSTATE. | Compte requis |
| MOD-08 | Commandes slash de modération [M] | P0 | ✅ | `chat_commands.dart` (`ModerationCommand`, `parseCommandLength`), `chat_store.dart` (`_runCommand`) | `/ban /unban /timeout /untimeout /warn /delete /clear /slow(off) /followers(off) /subscribers(off) /emoteonly(off) /uniquechat(off)` (et `/r9kbeta`). Suggérées aux mods, une à la fois, Helix décide des droits. `/mod /vip /raid /commercial /announce…` restent refusées avec un message. | Compte requis |
| MOD-09 | Vider le chat [M] | P1 | ✅ | `chat_mode_controls.dart` (« Clear chat », confirmation), `/clear` | Helix `DELETE /moderation/chat` sans `message_id`. | Compte requis |
| MOD-10 | Épingler / désépingler [M] | P1 | ❌ | — | Aucune API publique. | GQL privé |
| MOD-11 | Annonces [M] | P1 | ❌ | — | Helix `POST /chat/announcements` (`moderator:manage:announcements`). | Compte requis |
| MOD-12 | Rôles : mod, lead mod, VIP [M][C] | P1 | ❌ | — | Helix `POST/DELETE /moderation/moderators` (`channel:manage:moderators`, diffuseur) et `/channels/vips` (`channel:manage:vips`). Lead mod : GQL. | Compte requis |
| MOD-13 | Listes des mods et VIP [M] | P1 | ❌ | — | Helix `GET /moderation/moderators` (`moderation:read`) et `GET /channels/vips` (`channel:read:vips`), réservés au diffuseur ; un mod passe par GQL. | Compte requis |
| MOD-14 | Contexte modération de la carte [M] | P1 | ⚠️ | `user_card_info.dart`, `twitch_api.dart` (`getFollowedAt`) | Date de création du compte (pour tous) et date de follow (mods et diffuseur, `moderator:read:followers` ; un ancien jeton échoue sans dialogue). Historique des sanctions : GQL. | Compte requis |
| MOD-15 | Logs de modération de l'utilisateur [M] | P1 | ❌ | — | — | GQL privé |
| MOD-16 | Tableau de bord mobile [M] | P1 | ❌ | — | Assemblage des autres lignes MOD. | Compte requis |
| MOD-17 | File AutoMod [M] | P1 | ❌ | — | EventSub `automod.message.hold` v2 et `POST /moderation/automod/message` (`moderator:manage:automod`). | Compte requis |
| MOD-18 | Shield Mode [M] | P1 | ❌ | — | Helix `PUT /moderation/shield_mode` (`moderator:manage:shield_mode`) et EventSub `channel.shield_mode.begin/end`. | Compte requis |
| MOD-19 | Créer et gérer les sondages [M] | P1 | ❌ | — | Helix `POST/PATCH /polls` (`channel:manage:polls`, diffuseur seulement). | Compte requis |
| MOD-20 | Créer et gérer les prédictions [M] | P1 | ❌ | — | Helix `POST/PATCH /predictions` (`channel:manage:predictions`, diffuseur). | Compte requis |
| MOD-21 | File des récompenses [M] | P2 | ❌ | — | Helix `PATCH /channel_points/custom_rewards/redemptions` (`channel:manage:redemptions`), limité aux récompenses créées par le même client-id. | Compte requis |
| MOD-22 | Raids et réglages du stream depuis Mod View [M] | P2 | ❌ | — | Helix `POST /raids` (`channel:manage:raids`). | Compte requis |
| MOD-23 | Modération des commentaires de clip [M] | P2 | ❌ | — | — | GQL privé |
| MOD-24 | Utilisateurs suspects (low-trust) [M] | P2 | ❌ | — | EventSub `channel.suspicious_user.*` (`moderator:read:suspicious_users`). | Compte requis |
| MOD-25 | Revue des demandes de déban [M] | P2 | ❌ | — | Helix `GET/PATCH /moderation/unban_requests` (`moderator:manage:unban_requests`). | Compte requis |
| MOD-26 | Équipe de modération [C] | P2 | ❌ | — | Helix `/moderation/moderators` (diffuseur). | Compte requis |
| MOD-27 | Réglages de modération [C] | P2 | ❌ | — | Helix `/moderation/blocked_terms` (`moderator:manage:blocked_terms`) et `/moderation/automod/settings`. | Compte requis |
| MOD-28 | Analytics de modération [C] | P2 | ❌ | — | — | GQL privé |
| MOD-29 | Modération rapide en direct [C] | P2 | ❌ | — | Exige d'être le diffuseur, en live. | Compte requis |
| MOD-30 | Alertes push de modération [M] | P2 | ❌ | — | Les push FCM sont émis par Twitch. | Impossible proprement |
| MOD-31 | Callouts et anniversaire de mod [M] | P2 | ❌ | — | — | GQL privé |

### Social & notifications (SOC)

| ID | Feature | Priorité | Statut | Implémentation frostyv2 (fichier:ligne) | Ce qui manque / remarque | Faisabilité |
|---|---|---|---|---|---|---|
| SOC-01 | Suivre / ne plus suivre | P0 | ⚠️ | `user_actions_modal.dart`, `widgets/twitch_web_page.dart` | « Follow X on Twitch » dans le menu d'actions d'une chaîne : la page de la chaîne sur twitch.tv dans l'appli, connectée. Pas de bouton natif : Helix n'a plus d'endpoint de follow et la mutation GQL exige `Client-Integrity` (non contourné). | GQL privé |
| SOC-02 | Liste des chaînes suivies | P0 | ✅ | `twitch_api.dart:177-207`, `streams_list.dart`, `stream_list_store.dart` (`sortFollowedStreams`), `stream_sort_button.dart` (`FollowedSortButton`) | Live et hors ligne (« followed since »). « Sorted by » au-dessus des lives, comme Twitch, mémorisé (`settingsStore.followedSort`) : Viewers (High to Low) (ordre de Helix, inchangé), Recently Started, Name (A-Z), Category ; un ordre local charge d'abord les pages restantes (5 au plus). « Recommended For You » est un classement serveur privé : absent. | OK |
| SOC-03 | Page Following | P0 | ⚠️ | `streams_list.dart`, `followed_categories_section.dart`, `twitch_followed_categories_service.dart`, `watch_streak_tag.dart` | Épinglés (➕), live, hors ligne. Section « Categories » (catégories suivies, spectateurs, toucher = ses lives) lue par `FollowedGamesQuery` avec le jeton web, masquée sur tout échec (30 min avant de redemander). Tag « Watch Streak N » sur les cartes suivies (INT-21). Pas de lives recommandés ni de « continuer à regarder ». | GQL privé |
| SOC-04 | Suivre une catégorie | P1 | ⚠️ | `category_streams.dart` (`_followOnTwitch`), `twitch_followed_categories_service.dart` (`categoryPageUrl`) | Cœur « Follow on Twitch » (connecté) sur la page catégorie : la catégorie sur twitch.tv dans l'appli (`/directory/category/<slug>`, slug lu en GQL anonyme, sinon par le nom), où le viewer touche le vrai bouton de Twitch. Pas de mutation native : `FollowGameMutation` est soumise à `Client-Integrity` (non contourné). | GQL privé |
| SOC-05 | Cloche de notification par chaîne | P0 | ⚠️ | `go_live_setting.dart` (`GoLiveBellTile`), `user_actions_modal.dart`, `go_live.dart` (`muted`) | Cloche locale dans le menu d'une chaîne : comme Twitch, toute chaîne suivie notifie sauf si sa cloche est coupée. Non synchronisée avec la cloche du compte Twitch (GQL privé). | GQL privé |
| SOC-06 | Notifications push | P0 | ⚠️ | `go_live.dart`, `go_live_poller.dart`, `go_live_worker.dart`, `go_live_setting.dart`, `mention_alerts.dart`, `schedule_reminders.dart`, `main.dart` | Notifications de passage en live par vérification locale (`GET /streams/followed`) : toutes les 90 s tant que l'appli vit (premier plan, PiP, son en arrière-plan), sinon WorkManager environ toutes les 15 min selon Android ; état commun, une seule notice par diffusion (`started_at`), la tâche saute si l'appli vient de vérifier. Une notice par chaîne (5 au plus, puis un résumé), un toucher ouvre la chaîne, rien au premier passage ni après un changement de compte. Android seulement (iOS n'offre pas de tâche périodique fiable). S'y ajoutent les mentions du chat (CHT-05) et les rappels de programme (PRF-06). Le push FCM de Twitch reste impossible : pas d'alerte quand l'appli est fermée hors go-live, pas de whispers hors appli. À valider sur appareil (branche `notifpack`). | OK |
| SOC-07 | Centre de notifications | P0 | ⚠️ | `activity_screen.dart`, `activity_bell.dart`, `activity_store.dart`, `activity_log.dart` | Écran Activity comme Twitch (onglets Notifications et Whispers, « Most Recent » puis « Earlier », « Mark all as read », non lus en gras avec pastille, catégorie Live / Chat Mentions / Events, état vide de Twitch), ouvert par une cloche de l'accueil avec le nombre de nouveautés. Liste locale des notifications postées par ONSET (go-live, mentions, rappels), 100 au plus, sur l'appareil. Les notifications onsite de Twitch (`OnsiteNotificationsForUserQuery`) ne sont pas lues : lecture sûre non vérifiable sans jeton utilisateur. | GQL privé |
| SOC-08 | Notifications in-app | P1 | ⚠️ | `activity_bell.dart`, `activity_screen.dart` | Pastille de la cloche (nouveautés depuis la dernière ouverture, comme l'onglet Activity) et liste locale ; pas de notifications onsite de Twitch (GQL privé). | GQL privé |
| SOC-09 | Whispers (messages privés) | P1 | ✅ | `twitch_eventsub_client.dart`, `whisper_store.dart`, `lib/screens/whispers/`, `home.dart`, `chat_user_modal.dart`, `chat_commands.dart` (`/w`) | Réception par EventSub `user.whisper.message` (WebSocket, migration de session, keepalive, reconnexion), envoi par Helix `POST /whispers` (`user:manage:whispers`, téléphone vérifié). Boîte de réception (non lus en pastille sur l'accueil), conversation, notice in-app, bouton Whisper dans la fiche et `/w`. En mémoire seulement (pas d'historique public, rien d'écrit sur le disque) ; rien n'arrive après une minute en arrière-plan. | OK |
| SOC-10 | Confidentialité des whispers | P1 | ❌ | — | — | GQL privé |
| SOC-11 | Restrictions des whispers | P2 | ❌ | — | — | GQL privé |
| SOC-12 | Bloquer / ignorer | P0 | ✅ | `twitch_api.dart:335-398`, `blocked_users.dart`, `user_actions_modal.dart:57-67`, `chat_store.dart:531-541` | Pas de motif. Le blocage filtre le chat, pas les listes de streams. | OK |
| SOC-13 | Carte utilisateur (viewer card) | P0 | ✅ | `chat_user_modal.dart`, `user_card_info.dart`, `chat_moderation_bar.dart` | Avatar, badges du dernier message (mois d'abonnement), date de création du compte, date de follow pour les mods, messages de la session, Reply, Whisper, Profil, et dans « More » vidéos, Block, Follow (twitch.tv), Report. Actions de modération (MOD-01). | OK |
| SOC-14 | Signaler | P1 | ⚠️ | `user_actions_modal.dart:98-151` | Utilisateur seulement, via la page web `twitch.tv/<login>/report`. | OK |
| SOC-15 | Partager | P1 | ✅ | `share_link.dart` (share_plus 12.0.2), `user_actions_modal.dart`, `channel_profile_screen.dart`, `clip_info_panel.dart`, `vod_overlay.dart` | Feuille de partage du système pour une chaîne (menu et profil), un clip et une vidéo au moment en cours ; « Copy link » reste à côté (pour une chaîne, dans son menu, ouvert aussi depuis le profil par « More »). Un second toucher pendant que la feuille s'ouvre est ignoré. Sans feuille de partage, le lien est copié. | OK |
| SOC-16 | Stories (côté viewer) | P2 | ❌ | — | — | GQL privé |
| SOC-17 | Réactions | P2 | ❌ | — | — | GQL privé |
| SOC-18 | Commentaires de clips | P2 | ❌ | — | — | GQL privé |
| SOC-19 | Confidentialité des Stories | P2 | ❌ | — | — | GQL privé |
| SOC-20 | Shouts (messages de créateurs) | P2 | ❌ | — | — | GQL privé |
| SOC-21 | Recap annuel | P2 | ❌ | — | Simple lien web. | OK |
| SOC-22 | Suggestions de follow | P2 | ❌ | — | — | GQL privé |

### Découverte & recherche (DSC)

| ID | Feature | Priorité | Statut | Implémentation frostyv2 (fichier:ligne) | Ce qui manque / remarque | Faisabilité |
|---|---|---|---|---|---|---|
| DSC-01 | Navigation principale | P0 | ⚠️ | `home.dart` | Following, Top, Search ; l'avatar mène aux réglages ; barre de navigation du bas sur téléphone comme sur tablette (le rail latéral a été retiré avec le retour à ONSET). Ni Activité, ni Profil. | OK |
| DSC-02 | Catégories | P0 | ✅ | `twitch_api.dart:292-300`, `categories.dart` | Pas de pastille « nouveau ». | OK |
| DSC-03 | Chaînes live | P0 | ✅ | `twitch_api.dart:167-175`, `streams_list.dart:335-340` | — | OK |
| DSC-04 | Page catégorie | P0 | ✅ | `category_streams.dart` (`CategorySection`), `twitch_vod_service.dart` (`getCategoryVideos`), `twitch_clip_service.dart` (`getCategoryClips`) | Sections Live, Videos (100 plus vues, GQL anonyme sans pagination) et Clips (période et tri), chaîne nommée sur chaque carte. Le follow de catégorie reste à faire (compte requis, E9). | OK |
| DSC-05 | Tri et filtres | P1 | ✅ | `stream_languages.dart`, `stream_language_setting.dart`, `twitch_directory_service.dart`, `stream_sort_button.dart` | Langue des listes Top, catégorie et tag (Réglages › Général › Browse ; Helix `language`, GQL `broadcasterLanguages`). Tri des lives d'une catégorie ou d'un tag : spectateurs ↓ (Helix, paginé), Recommended, spectateurs ↑, Recently started (GQL anonyme, une seule page : 100 par catégorie, 30 par tag, la pagination GQL exige l'intégrité). | OK |
| DSC-06 | Tags | P1 | ✅ | `stream_tags.dart`, `tags/tag_streams.dart` | Quatre tags par carte sur une ligne ; un tag ouvre la page de ses lives (GQL anonyme `freeformTags`, triable, suit la langue). | GQL privé |
| DSC-07 | Recherche globale | P0 | ✅ | `search_store.dart:70-120`, `search.dart` (`_SearchTab`), `search_videos_store.dart`, `search_results_videos.dart`, `twitch_vod_service.dart` (`searchVideos`) | Onglets de l'officiel : Top (chaînes puis catégories, comme avant), Channels, Categories, Videos. Résultats pendant la saisie (debounce 300 ms). Videos : GQL anonyme `searchFor(target:{index:VOD, limit:25})`, page suivante au défilement avec le curseur de Twitch (une page refusée arrête la pagination sans message), « No search results found ». Pas de flux liés (DSC-09). | OK |
| DSC-08 | Suggestions et recherches récentes | P0 | ⚠️ | `search_store.dart` (`removeFromHistory`), `search.dart`, `search_results_channels.dart` | Historique (8 entrées) effaçable en entier ou entrée par entrée, « Go to channel ». Pas de suggestions. | OK |
| DSC-09 | Résultat mis en avant, flux liés, chaînes hors ligne | P1 | ⚠️ | `featured_channel.dart`, `search_results_channels.dart` | La chaîne dont le login ou le nom est exactement la recherche passe en tête, en grande carte (titre, catégorie, direct ou hors ligne). Indicateur live, chaînes hors ligne incluses. Pas de flux liés. | OK |
| DSC-10 | Suivre depuis la recherche | P1 | ❌ | — | Dépend de SOC-01. | GQL privé |
| DSC-11 | Flux de découverte vertical | P1 | ❌ | — | Helix `/streams` + IVS en aperçu. Coûteux en mémoire. | OK |
| DSC-12 | Flux de clips vertical | P1 | ✅ | `clips_feed_screen.dart`, `clips_feed_store.dart`, `twitch_clip_service.dart` (`getTopClips`) | Bouton « Clips » à côté des onglets Top : top clips de Twitch (GQL anonyme `topClips`, 20 par page avec le curseur, langue des listes Top, 200 au plus), plein écran, un swipe par clip, double-tap lecture/pause, « Open clip » vers l'écran de clip (replay du chat, VOD). Un seul clip joue ; seul le suivant est préchargé (en pause), les autres lecteurs sont libérés. Focus de lecture, mini-lecteur et PiP comme l'écran de clip. Pas de recommandations personnalisées ni de commentaires. À valider sur appareil. | GQL privé |
| DSC-13 | Sous-flux (puces) | P2 | ❌ | — | — | GQL privé |
| DSC-14 | Retours sur le flux | P2 | ❌ | — | — | GQL privé |
| DSC-15 | Recommandations | P1 | ❌ | — | — | GQL privé |
| DSC-16 | Lives sponsorisés | P2 | ❌ | — | Publicité. | Impossible proprement |
| DSC-17 | Recaps de streams récents | P2 | ❌ | — | — | GQL privé |
| DSC-18 | Rangée de Stories | P2 | ❌ | — | — | GQL privé |
| DSC-19 | Masquage des contenus labellisés | P1 | ✅ | `stream_list_store.dart` (`hiddenByLabels`), `hidden_content_labels_setting.dart`, `streams_list.dart` (`HiddenStreamsBanner`), `twitch_api.dart` (`getChannelsByIds`) | Réglage local « Hide labeled streams » (Général › Browse) : Top, catégories et tags lisent les labels de chaque page (`GET /channels`, 100 par appel) et laissent de côté les lives labellisés, avec une bannière « N streams hidden… · Show ». Les chaînes suivies s'affichent toujours ; labels illisibles = rien de masqué. Pas dans la recherche (résultats de chaînes, pas de lives). | OK |
| DSC-20 | Chaînes de l'équipe | P2 | ❌ | — | Helix `GET /teams/channel`. | OK |
| DSC-21 | Onboarding de personnalisation | P2 | ❌ | — | — | GQL privé |
| DSC-22 | Recommandations sur l'écran d'accueil Android | P2 | ❌ | — | Le SDK Engage exige une liste blanche Google. | Impossible proprement |

### Profil de chaîne & contenus (VOD / clips) (PRF)

| ID | Feature | Priorité | Statut | Implémentation frostyv2 (fichier:ligne) | Ce qui manque / remarque | Faisabilité |
|---|---|---|---|---|---|---|
| PRF-01 | Page chaîne | P1 | ✅ | `channel_profile/channel_profile_screen.dart` | Profil de chaîne (épopée E6) : bannière, avatar (anneau rouge en direct), nom et badge partenaire, followers, Regarder/Chat, Partager, Plus ; onglets Accueil, À propos, Programme, Vidéos, Clips. Ouvert depuis une chaîne hors ligne, la recherche, l'avatar sous la vidéo, la carte d'utilisateur du chat, le menu d'actions et les liens `/about`, `/schedule`. GQL anonyme, en-tête Helix en repli. | OK |
| PRF-02 | Accueil de profil | P1 | ✅ | `channel_profile/widgets/profile_home_tab.dart` | Direct en cours (aperçu) ou image hors ligne avec la dernière diffusion, puis 4 rediffusions et 4 clips de la semaine avec « View all ». | OK |
| PRF-03 | À propos | P1 | ✅ | `channel_profile/widgets/profile_about_tab.dart` | Bio, followers, date d'inscription, partenaire/affilié, liens sociaux avec icônes (ouverts via `LinkRouter`). GQL anonyme. | OK |
| PRF-04 | Panneaux | P1 | ✅ | `channel_profile/widgets/profile_about_tab.dart` | Image (lien), titre et description Markdown ; images du Markdown jamais chargées, liens http(s) seulement ; panneaux d'extension ignorés ; deux colonnes sur tablette. GQL anonyme. | GQL privé |
| PRF-05 | Programme | P1 | ✅ | `channel_profile/widgets/profile_schedule_tab.dart` | Prochain stream (« dans 3 heures »), segments à venir par jour local, annulés barrés, catégorie. GQL anonyme (semaine en cours et suivante). | OK |
| PRF-06 | Rappel d'un stream programmé | P2 | ✅ | `schedule_reminders.dart`, `profile_schedule_tab.dart`, `channel_profile_screen.dart`, `AndroidManifest.xml` | « Remind Me » / « Reminder Set » sur le prochain stream et sur chaque segment à venir, comme Twitch. Notification locale programmée au début du segment (inexacte sauf si les alarmes exactes sont déjà permises), gardée sur l'appareil et reprogrammée après redémarrage ; un segment déplacé déplace le rappel, un segment annulé le retire ; listée dans Activity. Pas de `SetScheduleReminderMutation` (GQL privé) : rappel propre au téléphone. À valider sur appareil. | OK |
| PRF-07 | Liste des vidéos | P1 | ✅ | `channel_videos.dart`, `channel_videos_store.dart`, `vod_card.dart` (`46b4ed2`) | Onglets rediffusions / temps forts / uploads, 100 plus récentes par onglet (la pagination par curseur est bloquée par l'intégrité pour les anonymes), progression de reprise et « Vu » sur les cartes. Accès depuis l'overlay live et hors ligne, le mode chat seul, la fiche utilisateur et le menu d'actions. | OK |
| PRF-08 | Lecture VOD | P1 | ✅ | `twitch_vod_service.dart`, `ivs_vod_store.dart`, `web_vod_store.dart`, `vod_screen.dart` (`b1a41fe`, `5ecf601`, `ad3cf94`, `021c827`) | Dans l'appli, jamais dans le navigateur : IVS en mode VOD (mêmes codecs AV1/HEVC → 2K), repli embed WebView sur iOS ou après échec natif, reprise d'erreurs, diagnostic usher. Jeton VOD demandé avec le jeton web du viewer (comme l'officiel avec l'OAuth), repli anonyme ; le jeton est demandé pendant le chargement des labels. À valider sur appareil. | OK |
| PRF-09 | Contrôles VOD | P1 | ✅ | `vod_overlay.dart`, `vod_seek_bar.dart` (`021c827`) | Barre de progression (tampon, segments muets), ±10 s, double-tap gauche/droite, qualité, volume, PiP, fit/fill, plein écran, lien au timecode. | OK |
| PRF-10 | Vitesse de lecture | P1 | ✅ | `ivs_vod_store.dart`, `vod_overlay.dart` (`5ecf601`, `021c827`) | 0,5× à 2× par 0,25 ; le replay du chat suit la vitesse. | OK |
| PRF-11 | Reprise de lecture | P1 | ✅ | `vod_resume.dart` (`021c827`), `live_progress.dart`, `TwitchVodService.getViewingHistory`/`updateViewedVideo` | Cadence de l'officiel (VOD : 20 s, pause, arrière-plan, sortie ; live : 5 min + pause/arrêt, J:r200), reprise à −30 s, `?t=` prioritaire, 300 vidéos par magasin, par compte. Synchro serveur avec le jeton web (`UpdateUserViewedVideo`, VOD ou LIVE + id du stream ; `self.viewingHistory`). Une VOD d'archive reprend où le live a été quitté (`broadcast.id` = id du stream, repli chaîne + début ±10 min). Écart : position live = début du stream − latence (l'officiel lit l'ID3 `ld_lat_data.stream_offset`). Non vérifiable ici : écriture/lecture authentifiées (gating d'intégrité éventuel → repli local silencieux). | OK |
| PRF-12 | Revoir le chat (chat replay) | P1 | ⚠️ | `vod_chat_replay_store.dart`, `vod_comment_cache.dart`, `vod_comment_to_irc.dart` (`6cc7ba0`) | Commentaires par offset en anonyme, rendus comme le live (badges, couleurs, emotes Twitch et 7TV/BTTV/FFZ, mentions, bloqués et mots masqués). Limites : seconde très chargée tronquée à une page (pas de curseur anonyme) ; emotes tierces = sets actuels de la chaîne. | GQL privé |
| PRF-13 | Vidéo suivante, lecture auto, revoir | P2 | ✅ | `up_next.dart`, `stores/up_next_store.dart`, `widgets/up_next_overlay.dart`, `vod_screen.dart`, `network_metering.dart`, `NetworkBridge.kt` | « Up Next » de l'officiel à la fin d'une VOD : vidéo suivante de la chaîne (tous types, plus récentes d'abord, ni vue ni réservée aux abonnés, règle `isWatched` de Twitch sur les positions locales), sinon une vidéo de la catégorie ; compte à rebours de 10 s, Cancel, lecture immédiate ; « Replay » reste sur l'overlay. Réglage « Video Autoplaying » (Mobile data & Wi-Fi par défaut, Wi-Fi Only via le réseau mesuré d'Android, Never). Écarts : sans lecture auto la carte attend le viewer ; pas de compte à rebours en PiP ; rien pour une VOD encore en enregistrement. La vidéo suivante remplace l'écran (sa propre garde de contenu, sa reprise et son replay). | OK |
| PRF-14 | Segments muets | P2 | ✅ | `twitch_vod_service.dart`, `vod_seek_bar.dart` (`b1a41fe`, `021c827`) | Repères sur la barre de progression. | OK |
| PRF-15 | VOD réservées aux abonnés | P2 | ⚠️ | `ivs_vod_store.dart`, `vod_error_view.dart`, `vod_card.dart` (`ad3cf94`, `021c827`) | Cadenas dans la liste. Le jeton VOD est demandé avec le jeton web twitch.tv du viewer : un abonné lit la VOD dans le lecteur natif. Refusée malgré ce jeton : message de l'officiel (« This video is only available to subscribers. » / « Subscribe now to watch and support this channel. ») avec rafraîchissement, jamais le lecteur web. Sans jeton web : repli web (cookies twitch.tv) comme avant. À valider avec un compte abonné. | OK |
| PRF-16 | Vidéos des chaînes suivies | P1 | ✅ | `followed_videos_screen.dart`, `followed_videos_store.dart`, `twitch_vod_service.dart` (`getFollowedVideos`) | « Followed videos » en tête des chaînes hors ligne de Following : les 100 premières chaînes suivies (Helix), puis 5 vidéos de chacune en une requête GQL anonyme par lot de 50 (`users(ids:)`), les plus récentes d'abord, ouvertes dans le lecteur VOD de l'appli. Tirer pour rafraîchir, erreur avec « Retry ». | OK |
| PRF-17 | Clips de la chaîne | P1 | ✅ | `apis/twitch_clip_service.dart`, `screens/clips/widgets/channel_clips_tab.dart` | Onglet « Clips » des vidéos de la chaîne : 24 h / 7 j / 30 j / tout, Top ou Tendances, 100 premiers (pagination bloquée par l'intégrité en anonyme), grille sur tablette. GQL anonyme. | OK |
| PRF-18 | Lecture de clip | P1 | ✅ | `screens/clips/clip_screen.dart`, `stores/clip_player_store.dart` | MP4 signé (jeton GQL anonyme) lu par media_kit : qualité, boucle, vitesse, volume, PiP, fit/fill, vidéo seule en paysage (téléphone comme tablette ; le plein écran repasse en portrait, où sont les infos), « Voir la vidéo complète » au bon instant, replay du chat de la VOD, autres clips de la chaîne. Repli embed Twitch en WebView. À valider sur appareil. | GQL privé |
| PRF-19 | Créer un clip | P1 | ✅ | `twitch_api.dart` (`createClip`, `getCreatedClip`, `getTokenScopes`), `create_clip_store.dart`, `create_clip_sheet.dart`, `video_overlay.dart`, `auth_store.dart` (`loginScopes`) | Bouton « Clip » en haut de l'overlay live, panneau « Create Clip » de l'officiel : Helix `POST /clips` avec le jeton utilisateur, « Generating Clipperino... », « Rendering Clip » (Get Clips toutes les 5 s, abandon après 60 s comme le conseille Twitch), puis Edit (éditeur twitch.tv dans l'appli), Share Clip, Copy link (« Clip link copied »). `clips:edit` ajouté à la connexion sans déconnecter personne : un ancien jeton (vu par `/oauth2/validate`) propose « Reconnect to Twitch ». Refus 400/403/404/429 expliqués, Retry. Pas de « Share via Whisper » ni de règles d'éligibilité préalables (GQL privé). Pas de clip depuis une VOD (Helix exige un scope d'éditeur). À valider sur appareil connecté. | Compte requis |
| PRF-20 | Éditer et publier un clip | P1 | ⚠️ | `create_clip_sheet.dart`, `twitch_web_page.dart` | Titre, extrait de 5 à 60 s et publication dans l'éditeur twitch.tv ouvert dans l'appli (`edit_url` de Helix, valable 24 h), pas d'éditeur natif (mutations privées). | GQL privé |
| PRF-21 | Télécharger ou exporter un clip | P2 | ❌ | — | — | GQL privé |
| PRF-22 | Clips automatiques | P2 | ❌ | — | — | GQL privé |
| PRF-23 | Collections | P2 | ❌ | — | — | GQL privé |
| PRF-24 | Bande-annonce de la chaîne | P2 | ❌ | — | — | GQL privé |
| PRF-25 | Badges d'état de chaîne | P1 | ⚠️ | `live_indicator.dart`, `offline_channel_card.dart:53`, `channel_profile/widgets/profile_header.dart` | LIVE et hors ligne partout ; sur le profil, RERUN et badge partenaire vérifié. Pas encore sur les cartes de flux. | OK |
| PRF-26 | Couleur d'accent et skins de chaîne | P2 | ❌ | — | — | GQL privé |
| PRF-27 | Stories et clips sur le profil | P2 | ❌ | — | — | GQL privé |
| PRF-28 | Options de chaîne | P1 | ✅ | `user_actions_modal.dart`, `stream_card.dart:89,215`, `channel_profile/channel_profile_screen.dart` | Profil, vidéos, épingler, bloquer et signaler depuis les cartes ; partage (copie du lien) depuis le profil. | OK |
| PRF-29 | Profil personnel | P1 | ⚠️ | `account_options.dart:47`, `profile_card.dart` | « My channel » et carte de profil. Pas de hub de clips. | OK |

### Monétisation (MON)

| ID | Feature | Priorité | Statut | Implémentation frostyv2 (fichier:ligne) | Ce qui manque / remarque | Faisabilité |
|---|---|---|---|---|---|---|
| MON-01 | S'abonner | P2 | ⚠️ | `profile_header.dart` (`onSubscribe`), `channel_profile_screen.dart`, `chat_details.dart`, `utils/twitch_links.dart` (`twitchSubscribeUrl`) | « Subscribe » sur l'en-tête du profil (partenaire ou affilié) et dans le menu du chat (connecté), jamais sur sa propre chaîne : la page `twitch.tv/subs/<login>` dans l'appli. L'achat natif (Google Play Billing de Twitch) reste impossible. | Impossible proprement |
| MON-02 | Avantages d'abonné | P2 | ❌ | — | — | GQL privé |
| MON-03 | Mes abonnements | P2 | ❌ | — | — | Impossible proprement |
| MON-04 | Abonnement Prime Gaming | P2 | ❌ | — | — | Impossible proprement |
| MON-05 | Turbo | P2 | ❌ | — | — | Impossible proprement |
| MON-06 | Offrir un abonnement | P2 | ⚠️ | `chat_details.dart` | « Gift a Sub » dans le menu du chat (connecté) : la page `twitch.tv/subs/<login>` dans l'appli, qui propose l'offre. Pas d'offre native. | Impossible proprement |
| MON-07 | Gifts à la communauté | P2 | ❌ | — | Offrir reste impossible proprement. Affichage seulement : bannière de gift bomb épinglée au-dessus du chat avec compte à rebours (`gift_bomb_tracker.dart`, `gift_bomb_feed.dart`), et chaque gift dans le chat (CHT-36). | Impossible proprement |
| MON-08 | Réglages des gifts | P2 | ❌ | — | — | GQL privé |
| MON-09 | Promotions | P2 | ❌ | — | — | Impossible proprement |
| MON-10 | Récompenses de dépense | P2 | ❌ | — | — | Impossible proprement |
| MON-11 | Paiement web | P2 | ✅ | `utils/twitch_links.dart` (`twitchSubscribeUrl`), `widgets/twitch_web_page.dart` | `twitch.tv/subs/<login>` s'ouvre dans l'appli (WebView connectée, hôte vérifié) depuis Subscribe et Gift a Sub (MON-01, MON-06). | OK |
| MON-12 | Acheter des Bits | P2 | ❌ | — | — | Impossible proprement |
| MON-13 | Solde et informations Bits | P2 | ❌ | — | — | GQL privé |
| MON-14 | Gestion des erreurs d'achat | P2 | ❌ | — | — | Impossible proprement |
| MON-15 | Page commerce unifiée et repli web | P2 | ❌ | — | — | Impossible proprement |

### Compte & réglages (ACC)

| ID | Feature | Priorité | Statut | Implémentation frostyv2 (fichier:ligne) | Ce qui manque / remarque | Faisabilité |
|---|---|---|---|---|---|---|
| ACC-01 | Connexion | P0 | ✅ | `auth_store.dart:101-170,264` | OAuth implicite dans une WebView (pas `passport`). Le CAPTCHA est géré par la page Twitch. | OK |
| ACC-02 | Vérification à la connexion | P1 | ✅ | `auth_store.dart:101-170` | Délégué à la page OAuth Twitch. | OK |
| ACC-03 | Mode invité | P0 | ✅ | `auth_store.dart:216`, `chat_store.dart:1061`, `chat_bottom_bar.dart:76` | Jeton d'app `client_credentials` (exige `SECRET`). | OK |
| ACC-04 | Déconnexion | P0 | ✅ | `auth_store.dart` (`logout`, `_revoke`), `twitch_api.dart` (`revokeToken`), `account_options.dart` | Jeton révoqué chez Twitch (`id.twitch.tv/oauth2/revoke`, sans bloquer la déconnexion) puis supprimé en local. | OK |
| ACC-05 | Passkeys | P2 | ❌ | — | Passkeys non disponibles dans la WebView OAuth. | Impossible proprement |
| ACC-06 | Connexion Google ou Amazon | P2 | ⚠️ | `auth_store.dart:104-110` | Google via un user-agent navigateur dans la WebView. | OK |
| ACC-07 | Inscription | P2 | ❌ | — | WebView `twitch.tv/signup`. | OK |
| ACC-08 | Récupération du compte | P2 | ❌ | — | WebView. | OK |
| ACC-09 | Structure des réglages | P1 | ⚠️ | `settings.dart`, `general_settings.dart` | Compte, Général, Vidéo, Chat, Autre. Notifications (live) et contenu (labels masqués) sont dans Général ; pas de section sécurité (gérée sur twitch.tv). | OK |
| ACC-10 | Thème | P0 | ➕ | `settings_store.dart:30-36,419`, `theme.dart` | Système, clair ou sombre (noir OLED), plus couleur d'accent libre. | OK |
| ACC-11 | Lecture auto des vidéos | P1 | ❌ | — | Pas d'aperçu en lecture auto (à faire avec DSC-11). | OK |
| ACC-12 | Préférences de lecture | P1 | ⚠️ | `video_settings.dart`, `general_settings.dart` (« Open the app on ») | Vidéo on/off, plus haute qualité, écran allumé, onglet d'ouverture (Following, Top ou Search). Audio en arrière-plan (Android). | OK |
| ACC-13 | Catégories de notifications | P1 | ❌ | — | — | GQL privé |
| ACC-14 | Modifier le profil | P2 | ❌ | — | Helix `PUT /users?description=` (`user:edit`) ; le reste en WebView. | OK |
| ACC-15 | Changement de pseudo | P2 | ❌ | — | WebView des réglages Twitch. | OK |
| ACC-16 | Authentification à deux facteurs | P2 | ❌ | — | WebView des réglages Twitch. | OK |
| ACC-17 | Mot de passe, email, téléphone | P2 | ⚠️ | `account_options.dart` | « Security and privacy » ouvre `twitch.tv/settings/security` dans l'appli, connecté. | OK |
| ACC-18 | Vérification du compte | P1 | ⚠️ | `account_options.dart` | Par la page sécurité de twitch.tv dans l'appli (vérification email/téléphone). Pas de bannière d'incitation native. | OK |
| ACC-19 | Comptes liés | P2 | ⚠️ | `account_options.dart` | « Connections » ouvre `twitch.tv/settings/connections` dans l'appli. | OK |
| ACC-20 | Consentements et vie privée | P2 | ❌ | — | WebView. Frostyv2 n'a qu'un opt-out Crashlytics (`other_settings.dart:105`). | OK |
| ACC-21 | Demande de données personnelles | P2 | ❌ | — | Lien web. | OK |
| ACC-22 | Préférences de contenu | P1 | ⚠️ | `hidden_content_labels_setting.dart`, `stream_list_store.dart`, `content_warning_gate.dart` | Version locale : choix des labels masqués en exploration (DSC-19) et avertissement avant une chaîne labellisée (PLY-25). Non synchronisée avec le compte (mutation GQL privée), sans tuteur. | GQL privé |
| ACC-23 | Gestion des retours de recommandation | P2 | ❌ | — | — | GQL privé |
| ACC-24 | Âge et contrôle parental | P2 | ❌ | — | Play Age Signals et Family Center sont propres à Twitch. | Impossible proprement |
| ACC-25 | Cycle de vie du compte | P2 | ❌ | — | WebView. | OK |
| ACC-26 | Sanctions et violations | P1 | ❌ | — | — | GQL privé |
| ACC-27 | Mises à jour des conditions | P2 | ❌ | — | Géré par le site Twitch. | OK |
| ACC-28 | À propos, aide, avis | P2 | ⚠️ | `settings.dart:127-190`, `other_settings.dart:65-70`, `main.dart:174` | Version, notes de version, invite d'avis, lien GitHub. | OK |
| ACC-29 | Mise à jour forcée ou suggérée | P2 | ❌ | — | Non pertinent pour un build personnel. | OK |
| ACC-30 | Accessibilité | P1 | ✅ | `overlay_common.dart` (`VideoSurfaceSemantics`), `irc.dart`, `frosty_cached_network_image.dart` (`semanticLabel`), `draggable_divider.dart`, `stream_info_bar.dart` (`_CategoryLink`) | Boutons icônes nommés (réglages vidéo, réessayer, fermer, etc.). Emotes, badges et piles zero-width lus par leur nom (chat, menu, récents, autocomplétion). Surfaces vidéo live et VOD : « Video player » avec indice afficher/masquer, double-tap proposé en actions (±10 s, disposition du chat). Catégorie ouvrable comme lien, séparateur du chat réglable comme un curseur, aperçus de miniature nommés, appui long des messages annoncé. À valider avec TalkBack sur appareil. | OK |
| ACC-31 | Défis anti-abus | P2 | ❌ | — | Play Integrity et `Client-Integrity`. | Impossible proprement |
| ACC-32 | Informations légales Corée | P2 | ❌ | — | Non pertinent. | OK |

### Créateur (CRE)

| ID | Feature | Priorité | Statut | Implémentation frostyv2 (fichier:ligne) | Ce qui manque / remarque | Faisabilité |
|---|---|---|---|---|---|---|
| CRE-01 | Mode créateur [C] | P2 | ❌ | — | UI locale. | OK |
| CRE-02 | Menu Créer [C] | P2 | ❌ | — | UI locale. | OK |
| CRE-03 | Diffusion caméra IRL [C] | P2 | ❌ | — | Ingest RTMPS et SDK de diffusion. | Impossible proprement |
| CRE-04 | Diffusion de jeux mobiles [C] | P2 | ❌ | — | MediaProjection plus encodeur et ingest. | Impossible proprement |
| CRE-05 | Overlay de diffusion et bulles [C] | P2 | ❌ | — | Dépend de CRE-03/04. | Impossible proprement |
| CRE-06 | Informations du stream [C] | P2 | ❌ | — | Helix `PATCH /channels` (`channel:manage:broadcast`). | OK |
| CRE-07 | Qualité de diffusion [C] | P2 | ❌ | — | Dépend de l'ingest. | Impossible proprement |
| CRE-08 | Éligibilité à la diffusion [C] | P2 | ❌ | — | — | GQL privé |
| CRE-09 | Contrôles en direct et fin [C] | P2 | ❌ | — | Dépend de l'ingest. | Impossible proprement |
| CRE-10 | Stream Manager [C] | P2 | ❌ | — | Les statistiques passent par GQL. | GQL privé |
| CRE-11 | Flux d'activité [C] | P2 | ❌ | — | EventSub `channel.follow` v2, `channel.subscribe`, `channel.cheer`, `channel.raid`, sur sa propre chaîne. | OK |
| CRE-12 | Alertes IRL [C] | P2 | ❌ | — | — | GQL privé |
| CRE-13 | Lancer une pub [C] | P2 | ❌ | — | Helix `POST /channels/commercial` (`channel:edit:commercial`, affilié). | Compte requis |
| CRE-14 | Marqueurs de stream [C][M] | P2 | ❌ | — | Helix `POST /streams/markers` (`channel:manage:broadcast`). | OK |
| CRE-15 | Raid sortant [C][M] | P2 | ❌ | — | Helix `POST/DELETE /raids` (`channel:manage:raids`). | OK |
| CRE-16 | Réglages des raids entrants [C] | P2 | ❌ | — | — | GQL privé |
| CRE-17 | Auto-hosting (héritage) [C] | P2 | ❌ | — | Fonction supprimée par Twitch en 2022. | Impossible proprement |
| CRE-18 | Shoutout sortant [C][M] | P2 | ❌ | — | Helix `POST /chat/shoutouts` (`moderator:manage:shoutouts`). | OK |
| CRE-19 | Messages aux spectateurs [C] | P2 | ❌ | — | — | GQL privé |
| CRE-20 | Résumé de stream [C] | P2 | ❌ | — | — | GQL privé |
| CRE-21 | Analytics détaillées [C] | P2 | ❌ | — | — | GQL privé |
| CRE-22 | Performance des notifications go-live [C] | P2 | ❌ | — | — | GQL privé |
| CRE-23 | Lien de parrainage [C] | P2 | ❌ | — | — | GQL privé |
| CRE-24 | Accueil créateur [C] | P2 | ❌ | — | — | GQL privé |
| CRE-25 | Gestionnaire de clips [C] | P2 | ❌ | — | Liste via Helix `/clips`. La suppression passe par GQL. | GQL privé |
| CRE-26 | Gestion du programme [C] | P2 | ❌ | — | Helix `/schedule/segment` (`channel:manage:schedule`, affilié ou partenaire). | Compte requis |
| CRE-27 | Réglages de contenus de chaîne [C] | P2 | ❌ | — | — | GQL privé |
| CRE-28 | Classification du contenu [C] | P2 | ❌ | — | Helix `PATCH /channels` `content_classification_labels`. | OK |
| CRE-29 | Contenu sponsorisé [C] | P2 | ❌ | — | Helix `PATCH /channels` `is_branded_content`. | OK |
| CRE-30 | Création de Stories [C] | P2 | ❌ | — | — | GQL privé |
| CRE-31 | Partager vers Stories depuis une autre app [C] | P2 | ❌ | — | — | GQL privé |
| CRE-32 | Récaps vers Stories [C] | P2 | ❌ | — | — | GQL privé |
| CRE-33 | Stream Together / Guest Star [C] | P2 | ❌ | — | WebRTC Guest Star. | Impossible proprement |
| CRE-34 | Monétisation (affilié / partenaire) [C] | P2 | ❌ | — | Affilié ou partenaire. | Compte requis |
| CRE-35 | Programme DJ [C] | P2 | ❌ | — | Programme DJ. | Compte requis |
| CRE-36 | Objectifs créateur [C] | P2 | ❌ | — | — | GQL privé |
| CRE-37 | Réglages des emotes [C] | P2 | ❌ | — | Affilié. | Compte requis |

### Divers / technique (MSC)

| ID | Feature | Priorité | Statut | Implémentation frostyv2 (fichier:ligne) | Ce qui manque / remarque | Faisabilité |
|---|---|---|---|---|---|---|
| MSC-01 | Deep links et App Links | P0 | ⚠️ | `AndroidManifest.xml:40-48`, `main.dart`, `twitch_links.dart`, `link_router.dart` | `twitch.tv`, `www.`, `m.` et `clips.twitch.tv` : chaîne, `/videos/<id>`, `/v/<id>`, `/<chaîne>/v/<id>`, `?t=`, `/<chaîne>/videos?filter=`, clips (`clips.twitch.tv/<slug>`, `/<chaîne>/clip/<slug>`, `/embed?clip=`) et `/<chaîne>/clips?range=` ouverts dans l'appli, y compris depuis le chat. Pas de schéma `twitch://`. | OK |
| MSC-02 | Transport GraphQL | P0 | ⚠️ | `twitch_stream_service.dart:20-34,98-113` | Une seule requête GQL, non persistée (choix volontaire contre la rotation des hashes). Ni APQ ni intégrité. | GQL privé |
| MSC-03 | Temps réel Hermes | P0 | ✅ | `lib/services/realtime/` | Client Hermes anonyme partagé (`TwitchRealtimeClient`) pour les sujets publics, et client EventSub WebSocket (`TwitchEventSubClient`) pour les événements du compte : connexion paresseuse, abonnements Helix par session, `session_reconnect` sans perte, keepalive, reconnexion avec backoff, dédoublonnage, pause en arrière-plan. Branché aussi pour `stream.online` (PLY-09). | OK |
| MSC-04 | Client chat Kotlin Multiplatform | P1 | ✅ | `chat_store.dart:884-1005`, `chat_tabs_store.dart:151-200` | Buffer flushé toutes les 200 ms, backoff, PING/PONG. | OK |
| MSC-05 | Gestion des permissions | P1 | ⚠️ | `go_live_setting.dart`, `go_live_worker.dart` (`requestPermission`, `allowed`) | Notifications (Android 13+) demandées en activant les notifications de live, avec explication ; si elles sont bloquées, le réglage le dit et renvoie aux réglages système (sans bouton direct). Service média : permissions de manifeste seulement. | OK |
| MSC-06 | Pile React Native « Ultralight » | P2 | ❌ | — | Pile RN interne à Twitch. | Impossible proprement |
| MSC-07 | Portails web « Candlelight » | P2 | ❌ | — | Portails Twilight internes. | Impossible proprement |
| MSC-08 | Mises à jour OTA du bundle RN | P2 | ❌ | — | — | Impossible proprement |
| MSC-09 | Flags et configuration distante | P2 | ❌ | — | Des flags locaux suffisent. | OK |
| MSC-10 | Télémétrie et mesure d'audience | P2 | ⚠️ | `main.dart:48-57` | Firebase Crashlytics, Analytics et Performance. Pas de télémétrie Twitch (non souhaitable). | Impossible proprement |
| MSC-11 | Enquêtes in-app | P2 | ❌ | — | — | Impossible proprement |
| MSC-12 | Menu debug | P2 | ⚠️ | `dev_player_harness.dart`, `video_overlay.dart:487-516` | Harness mpv et badge de latence. Pas de menu debug. | OK |
| MSC-13 | Rapports de crash QA | P2 | ⚠️ | `main.dart:48-57`, `other_settings.dart:105` | Crashlytics avec opt-out. | OK |
| MSC-14 | Mises en page tablette et bureau | P2 | ⚠️ | `context_extensions.dart` (`isLargeScreen`), `adaptive_sliver_list.dart`, `readable_width.dart`, `channel_top_overlays.dart`, `MainActivity.kt` | Retour à la mise en page ONSET sur tablette : barre de navigation du bas, listes de lives et de catégories sur une colonne, plein écran qui fait pivoter, crayon du chat paysage sous 30 % de la largeur, clip paysage en vidéo seule. Gardé : grilles des vidéos et des clips, largeur de lecture des whispers et du profil, bannière du hype train bornée, highlights dépliés, 120 Hz demandé. Bureau hors périmètre. | OK |
| MSC-15 | WebView in-app | P2 | ✅ | `user_actions_modal.dart:115`, `auth_store.dart:101`, `settings_store.dart:48-50` | WebView pour le signalement et la connexion, option navigateur externe. | OK |
| MSC-16 | Éducation utilisateur | P2 | ⚠️ | `onboarding_intro.dart`, `release_notes.dart` | Onboarding et notes de version. Pas de coach-marks. | OK |
| MSC-17 | Liens différés et attribution | P2 | ❌ | — | Clé Branch propre à Twitch. | Impossible proprement |

## 2. Synthèse

Comptes générés à partir des tableaux ci-dessus (317 lignes).

| Domaine | ✅ | ⚠️ | ❌ | ➕ | Total |
|---|---|---|---|---|---|
| Lecture vidéo (PLY) | 18 | 5 | 9 | 1 | 33 |
| Chat (CHT) | 29 | 4 | 9 | 6 | 48 |
| Interactions communautaires (INT) | 6 | 7 | 18 | 0 | 31 |
| Modération (MOD) | 9 | 1 | 21 | 0 | 31 |
| Social & notifications (SOC) | 5 | 8 | 9 | 0 | 22 |
| Découverte & recherche (DSC) | 8 | 3 | 11 | 0 | 22 |
| Profil de chaîne & contenus (VOD / clips) (PRF) | 18 | 5 | 6 | 0 | 29 |
| Monétisation (MON) | 1 | 2 | 12 | 0 | 15 |
| Compte & réglages (ACC) | 5 | 8 | 18 | 1 | 32 |
| Créateur (CRE) | 0 | 0 | 37 | 0 | 37 |
| Divers / technique (MSC) | 3 | 8 | 6 | 0 | 17 |
| **Total** | **102** | **51** | **156** | **8** | **317** |

| Priorité | ✅ | ⚠️ | ❌ | ➕ | Total |
|---|---|---|---|---|---|
| P0 | 42 | 13 | 1 | 4 | 60 |
| P1 | 51 | 25 | 28 | 4 | 108 |
| P2 | 9 | 13 | 127 | 0 | 149 |
| **Total** | **102** | **51** | **156** | **8** | **317** |

| Faisabilité (lignes non ✅/➕) | P0 | P1 | P2 | Total |
|---|---|---|---|---|
| OK | 8 | 16 | 32 | 56 |
| GQL privé | 6 | 27 | 59 | 92 |
| Compte requis | 0 | 10 | 12 | 22 |
| Impossible proprement | 0 | 0 | 37 | 37 |

Lecture : sur 60 lignes P0, **46** sont entièrement couvertes (42 ✅ et 4 ➕), 13 sont partielles et 1 absente. La ligne P0 absente est l'avertissement côté viewer (CHT-13), en GQL privé ; le centre de notifications (SOC-07) est partiel (liste locale). Les ➕ sont le délai de chat synchronisé, la révélation des messages supprimés, le multi-chat et le chat partagé, les emotes 7TV/BTTV/FFZ, la disposition paysage et le thème avec accent.

## 3. Lecture / latence : écarts concrets avec le lecteur officiel

Colonne « Latence » : ↓ = peut réduire la latence glass-to-glass, ⏱ = réduit seulement le temps de démarrage, 📏 = mesure seulement, ↔ = neutre.

| # | Sujet | Officiel 31.5.2 | frostyv2 (fichier:ligne) | Changement proposé | Latence | Risque |
|---|---|---|---|---|---|---|
| L1 | Version IVS | `ivs-player` 1.57.0-rc.2 | 1.52.0 (`android/app/build.gradle.kts:65`) | Passer à 1.57.x. C'est un prérequis de L2 ; vérifier sur Maven Central si une version stable existe. | ↓ (indirect) | Moyen : changements d'API possibles, régression du rendu texture à revérifier |
| L2 | Rattrapage par accélération | `setLiveCatchUpSpeedUpEnabled(true)` sur chaque lecteur | Absent (setter inexistant en 1.52) | Activer après L1, dans un `try` comme `IvsPlayerCore.kt:81-86` | **↓** rattrape la dérive sans saut | Faible : son légèrement accéléré pendant le rattrapage |
| L3 | Rebuffer to live | **Jamais** activé (stratégie « speedup ») | `setRebufferToLive(true)` (`IvsPlayerCore.kt:83`) | Désactivé par défaut avec L2, gardé en option avancée | ↔ à ↓ (moins de sauts ; avec L2 la latence moyenne ne remonte pas) | Faible. À mesurer : sans L2, désactiver seul **augmente** la latence après un rebuffer |
| L4 | Buffer initial | `setInitialBufferDuration(100)` en théâtre live | Valeur par défaut du core | Fixer à 100 ms | ⏱ et ↓ au démarrage | Faible : un peu plus de rebuffers au tout début |
| L5 | Préchargement du jeton | `TheatrePortalPreloadQuery` avant l'UI, puis `preload()` → `loadSource()` | PAT puis usher puis texture, en série après `initState` (`ivs_video_store.dart:114-115`, `channel.dart:150-177`) | Précharger PAT + URL usher dès que l'intention apparaît (appui sur une carte, carte visible en tête de liste), avec un cache par login jusqu'à `expires` | ⏱ | Nul à faible : jeton expiré → re-fetch sur 403 |
| L6 | Paramètres usher hérités | `low_latency` et `player=twitchweb` sont absents de toute l'app officielle ; `fast_bread=true` est le vrai drapeau LL-HLS | Présents (`twitch_stream_service.dart:54,61,77,85`) | Les retirer. Ajouter `allow_audio_only=true` et `include_unavailable=true` | ↔ | **Sans risque** si on mesure avant et après |
| L7 | Plateforme du jeton | `platform=android`, `playerType=mobile_player` | `platform:"web"`, `playerBackend:"mediaplayer"`, `playerType:"embed"` (`twitch_stream_service.dart:26-31,110`) | A/B derrière un réglage développeur (cf. questions ouvertes) | Inconnu : variantes, pubs et LL peuvent différer | Moyen : refus éventuel ou traitement pub différent ; le fallback web couvre le cas |
| L8 | Affichage de la latence | Overlay stats (latence au diffuseur) | `showLatency=false` par défaut (`settings_store.dart:74`). Latence arrondie à 1 s et bornée à 60 s (`ivs_video_store.dart:195`) | Activer par défaut. Afficher 0,1 s plus débit, résolution et buffer (`getStatistics`). Garder des **secondes entières** pour `syncedChatDelay` | 📏 | **Sans risque** |
| L9 | Erreurs | `setNetworkRecoveryMode(NONE)` + refetch avec backoff + relance au `stream-up` | **Toute** erreur IVS → WebView pour toute la session (`ivs_video_store.dart:203-206` → `channel.dart:164-177`) | Classer les erreurs : réseau → retry 1/2/4 s avec nouveau jeton ; 403 usher → message ; hors ligne → écran de fin. WebView seulement après N échecs | **↓** en pratique : évite une chute silencieuse à 8-15 s | Faible |
| L10 | iOS | n/a | Aucun code IVS → spinner infini (`ivs_video_store.dart:115`) | Sur iOS, forcer `twitchWeb` (ou mpv) dans `_buildPlayerController` (`channel.dart:116-148`) | ↔ | **Sans risque** (respecte la règle iOS de `CLAUDE.md`) |
| L11 | ABR | `setAutoMaxVideoSize(3840,2160)`, débit initial réglé | Auto, `supported_codecs=av1,h265,h264` (`twitch_stream_service.dart:81`) | Garder Auto. Exposer le plafond. Restaurer la qualité mémorisée **après** l'événement `qualities` | ↔ | Faible : le décodage HEVC/AV1 coûte cher sur certains SoC, à surveiller |
| L12 | Moteur mpv | n/a | `cache=no`, `demuxer-readahead-secs=0` (`native_video_store.dart:144-157`), non sélectionnable dans l'UI (`video_settings.dart:29-31`) | Garder comme harness ou fallback n° 2 | ↔ | — |
| L13 | Latence WebView | n/a | Lue dans les stats toutes les 60 s (`video_store.dart:494-648`) | Inchangé (fallback) | 📏 | — |

**Sans risque, à faire en premier :** L6, L8, L10, puis L4 et L5. **Ce qui peut réduire la latence :** L2 (+ L1), L3 combiné à L2, L9, et L4 au démarrage. **À mesurer en A/B :** L3 et L7.

## 4. Régressions à surveiller (garde-fous pour chaque feature future)

**7TV (et BTTV/FFZ)**

- Emotes globales et de chaîne (`seventv_api.dart:10-39`, `chat_assets_store.dart:153-230`) : la chaîne prime sur le global, zero-width (flag 256), alias, AVIF ignoré. Ne pas réordonner la résolution des emotes.
- EventAPI `wss://events.7tv.io/v3` `emote_set.update` (`chat_store.dart:797-881`) : ajout et retrait avec message système, **mis en file derrière le délai de chat** (`_pendingSevenTVCallbacks`). Tout nouveau socket (EventSub) doit vivre à côté, sans remplacer ce flux.
- Onglets 7TV/BTTV/FFZ du menu d'emotes (`chat.dart:280-320`), autocomplétion multi-fournisseurs (`chat_store.dart:276-300`), réglages `show7TVEmotes`…
- Chat partagé : sets 7TV par diffuseur (`chat_assets_store.dart:34`).
- Tout nouveau rendu (cheermotes, couleur d'annonce, AutoMod, cartes clip) doit passer par `IRCMessage.generateSpan` pour garder les emotes tierces.
- Dettes connues à ne pas aggraver : badges 7TV jamais alimentés (`chat_assets_store.dart:94-96`), seul `.first` de pushed/pulled traité, pas de heartbeat ni de resume 7TV.

**Affichage de la modération**

- CLEARMSG marque le message sans effacer son contenu (`irc.dart:106-127`). Un CLEARCHAT ciblé marque **tous** les messages de l'utilisateur avec `ban-duration`, y compris le buffer (`irc.dart:60-103`). Un CLEARCHAT global affiche une notice.
- Rendu : opacité 50 %, en-têtes « Message deleted / Permanently banned / Timed out for N », révélation au tap, réglage `showDeletedMessages` (`chat_message.dart:342-403`). Les actions Helix futures (ban, delete) **ne doivent pas** supprimer localement un message de façon optimiste : il faut laisser revenir le CLEARCHAT/CLEARMSG IRC.
- CLEARCHAT et CLEARMSG passent par la file de délai, car ils sont absents de `_delayBypassCommands` (`chat_store.dart:34-39`). Les événements EventSub de modération doivent emprunter la même file : sinon ils s'appliquent à des messages pas encore affichés.
- Les modérateurs voient les utilisateurs bloqués (`chat_store.dart:532`) : ne pas casser l'exception.
- Garder la vue fusionnée multi-chat, les fils de réponse et la fiche utilisateur cohérents avec ces marquages.

**Latence et lecteur**

- Le moteur par défaut reste IVS. Le fallback WebView doit toujours se lancer (`channel.dart:141-147,164-177`) et l'interrupteur doit fonctionner (`video_settings.dart:22-32`) (cf. `CLAUDE.md`, Definition of done).
- `syncedChatDelay` est alimenté par la latence IVS en secondes entières (`ivs_video_store.dart:199-201`) et remis à 0 à la création (`ivs_video_store.dart:113`). Plus de précision à l'affichage ne doit pas changer l'unité du délai.
- Le mini-player récupère le lecteur sans rechargement (`channel.dart:118-123`, `mini_player_store.dart:41-58`), et le chat reste vivant. Le préchargement et les retries ne doivent pas créer un 2ᵉ lecteur pour la même chaîne.
- Auto-PiP Android (`ivs_video_store.dart:119-130`) : le service d'audio en arrière-plan ne doit pas le désactiver.
- Le ticker de latence (1 s, `IvsPlayerCore.kt:92-100`) doit rester léger. Les nouveaux sockets se lancent **après** `ready`, pour ne pas retarder le premier frame.
- `IvsVideoStore` crée son propre `Dio()` (`ivs_video_store.dart:112`), fermé dans `dispose` (l. 313). Un cache de préchargement ne doit pas fuir de clients.
- Mesure obligatoire avant et après chaque changement de lecteur : latence médiane sur 5 min, sur 3 chaînes, sur un appareil réel, overlay activé.

## 5. Ordre d'implémentation proposé

Un commit par groupe, dans l'ordre. Les lignes [C] seules et « Impossible proprement » sont exclues. Les groupes « Compte requis » dépendent de la question 2.

### P0

| # | Commit (feature) | IDs | Approche | Scopes / endpoints | Risque |
|---|---|---|---|---|---|
| 1 | Latence visible et stats IVS | PLY-04 | `showLatency=true` par défaut. Événement `stats` natif (débit, résolution, buffer) via `getStatistics()`. Latence à 0,1 s à l'écran. | — | Nul |
| 2 | iOS et erreurs IVS récupérables | PLY-11, PLY-10 (+ PLY-26, PLY-27 en P1) | WebView forcée sur iOS. Classement des `PlayerException` : retry avec backoff et nouveau jeton, message pour 403/abonnés, écran hors ligne. Fallback WebView seulement après N échecs. | Réponse GQL PAT existante | Faible |
| 3 | Nettoyage usher | PLY-01 (partiel), MSC-02 | Retirer `low_latency` et `player=twitchweb` ; ajouter `allow_audio_only`, `include_unavailable`. Le jeton reste `web` (L7 en A/B séparé). | usher | Faible |
| 4 | IVS 1.57 + rattrapage par accélération + buffer 100 ms | PLY-03, PLY-01 | Montée de version Gradle, `setLiveCatchUpSpeedUpEnabled(true)`, `setInitialBufferDuration(100)`, `rebufferToLive` désactivé par défaut et réglable. | — | Moyen (SDK) |
| 5 | Préchargement du jeton | PLY-02 | Cache `login → (token, sig, expires)` alimenté depuis les cartes de stream ; `_resolveUrl` le consomme. | GQL PAT existant | Faible |
| 6 | Qualité mémorisée, son, zoom | PLY-05, PLY-06, PLY-07 | Restaurer `last_stream_quality`/la plus haute après `qualities`. `setMuted`/`setVolume` dans le pont. Pincer-zoomer (`InteractiveViewer`) sur la texture. | — | Faible |
| 7 | Client EventSub WebSocket + état du live | MSC-03, PLY-09 | Service `EventSubApi extends BaseApiClient` (`POST /eventsub/subscriptions`) + `wss://eventsub.wss.twitch.tv/ws` (keepalive, `session_reconnect`). `stream.online` relance le lecteur, `stream.offline` affiche l'écran de fin, `channel.update` met à jour la barre. | Aucun scope pour ces 3 types ; jeton **utilisateur** obligatoire en WebSocket | Moyen (quotas : 3 WS et 300 coûts par user/client) |
| 8 | Correctifs de rendu du chat | CHT-05, CHT-18, CHT-10 | Mention par mot entier sur le login. Couleur d'annonce `msg-param-color`. Ligne système « X exclu/banni » si aucun message n'est visible. | IRC | Faible (garde-fous §4) |
| 9 | Saisie : limite et restrictions | CHT-03, CHT-12, CHT-15, CHT-30 | Compteur de 500 caractères. Verrouillage et compte à rebours sur un CLEARCHAT qui vise son propre `user-id`. Bannière ROOMSTATE (slow : temps restant ; followers-only : durée). | IRC | Faible |
| 10 | Commandes slash côté client | CHT-17, CHT-06 | Parseur local et autocomplétion des commandes. `/color` → `PUT /chat/color`, `/block` et `/unblock` → `/users/blocks`, aide `/help`. `/w` arrive au commit 22. | Scopes actuels | Faible |
| 11 | Modération active Helix | MOD-01→MOD-08 | Actions dans la fiche utilisateur et l'appui long, visibles si `_userState.mod` ou diffuseur. Confirmations. Commandes `/ban /timeout /unban /untimeout /slow /followers /subscribers /emoteonly /uniquechat /warn` → Helix. | `POST/DELETE /moderation/bans` (`moderator:manage:banned_users`), `DELETE /moderation/chat` (`moderator:manage:chat_messages`), `POST /moderation/warnings` (`moderator:manage:warnings`), `PATCH /chat/settings` (`moderator:manage:chat_settings`) ; reconnexion requise | Moyen, **Compte requis** |
| 12 | Fiche utilisateur enrichie | SOC-13 (+ MOD-14 partiel) | Date de création (`GET /users`), badges du dernier message, boutons whisper et follow quand ils existent. Contexte mod si autorisé. | `GET /users` ; `GET /channels/followers?user_id=` (`moderator:read:followers`) | Faible |
| 13 | Révocation à la déconnexion | ACC-04 | `POST id.twitch.tv/oauth2/revoke` avant la suppression locale. | — | Nul |
| 14 | Deep links étendus | MSC-01 | `clips.twitch.tv`, `/videos/<id>`, `t=`, schéma `twitch://`. Retirer `autoVerify` (invérifiable). Routage VOD et clips après les commits 18-19. | Manifeste | Faible |
| 15 | Notifications de passage en live (approximation) | SOC-06, SOC-05 (local), MSC-05 | WorkManager périodique (≥ 15 min) sur `GET /streams/followed`, `flutter_local_notifications`, cloche locale par chaîne, permission `POST_NOTIFICATIONS`. | `user:read:follows` (déjà présent) | Moyen (batterie, délai, iOS limité) |
| 16 | Navigation, recherche et page catégorie | DSC-01, DSC-04, DSC-07, DSC-08 | Onglets Vidéos/Clips dans la recherche et les catégories (après les commits 18-19). Suppression unitaire de l'historique. Onglet Profil/Activité si on le retient. | `/videos?game_id`, `/clips?game_id` | Faible |
| 17 | Couche GQL privée P0 (flag, désactivée par défaut) | SOC-01, SOC-03, SOC-07, CHT-13 | `TwitchGqlApi extends BaseApiClient`, isolé et masqué à la moindre erreur. Exige l'`auth-token` web de l'utilisateur, pas notre jeton OAuth. Fallback « ouvrir la chaîne sur twitch.tv » pour le follow. | GQL privé (`FollowUserMutation`, `FollowedGamesQuery`, `OnsiteNotifications…`, `AcknowledgeChatWarning`) | **Élevé** (intégrité, CGU, cassures) |

### P1

| # | Commit (feature) | IDs | Approche | Scopes / endpoints | Risque |
|---|---|---|---|---|---|
| 18 | Lecture VOD | PRF-07, PRF-08, PRF-09, PRF-10, PRF-11, PRF-16 | Liste `GET /videos`. Jeton `videoPlaybackAccessToken` (déjà dans la requête existante), usher `/vod/<id>.m3u8`. IVS `seekTo`/`setPlaybackRate`. Reprise stockée en local et sur le compte Twitch (jeton web), y compris depuis le live. Contrôleur séparé du live. | Helix `/videos` | Faible à moyen |
| 19 | Clips | PRF-17, PRF-18, PRF-19, CHT-45 | `GET /clips`, `POST /clips`. Lecture via le jeton de clip GQL. Cartes de clip et de VOD dans le chat. | `clips:edit` ; GQL clip (sans intégrité) | Moyen |
| 20 | Page profil de chaîne | PRF-01, PRF-02, PRF-03, PRF-05, PRF-25, PRF-28, PRF-29 | En-tête (`/users`, `/channels`), Accueil, À propos, Programme (`/schedule`), Vidéos, Clips. Pastilles rediffusion et vérifié. Partager, bloquer, signaler. | Helix public | Faible |
| 21 | Audio seul + arrière-plan + MediaSession | PLY-12, PLY-14, PLY-15, ACC-12 | Variante `audio_only`. `audio_service` en service de premier plan `mediaPlayback`. Contrôles notification et casque. | Permissions `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Moyen (cohabitation PiP et mini-player) |
| 22 | Whispers | SOC-09 | Envoi Helix, réception EventSub (commit 7), historique local seulement. | `user:manage:whispers`, `user:read:whispers` ; `user.whisper.message` | Moyen (téléphone vérifié, quotas) |
| 23 | Événements chat EventSub | CHT-44, INT-19 | Statut AutoMod de ses propres messages. Notice de raid sortant, et le lecteur suit la cible. | `user:read:chat` (`channel.chat.user_message_hold`/`_update`) ; `channel.raid` sans scope | Moyen |
| 24 | Finitions du chat | CHT-22, CHT-23, CHT-25, CHT-28, CHT-29, INT-11 | Correction des 2 bugs des mots masqués et listes de filtres. Bascule d'animation. Emotes utilisables (`GET /chat/emotes/user`). Fiche emote enrichie. Cheermotes (`GET /bits/cheermotes`). | `user:read:emotes` | Faible (garde-fous 7TV) |
| 25 | Classification du contenu | PLY-25, DSC-19 (+ ACC-22 en local) | Interstitiel et filtre basés sur `content_classification_labels`, préférences locales. | `GET /channels` | Faible |
| 26 | Extras du lecteur | PLY-20, PLY-23, PLY-26, PLY-27 | Poignée de taille du chat en portrait. CC via cues texte IVS (`onCue`). Messages abonnés-only et géoblocage (si non faits au commit 2). | — | Faible |
| 27 | Format double et Cast | PLY-21, PLY-24, PLY-17 | Un commit chacun : usher `multigroup_video` + `setSourceGroup` ; Cast via Default Media Receiver ; fenêtre flottante. | usher ; Cast SDK | Moyen à élevé (formats non documentés) |
| 28 | Partage et signalement | SOC-14, SOC-15 | `share_plus` pour chaîne, clip et VOD (avec `t=`). Signalement de stream et de clip en WebView. | — | Nul |
| 29 | Modération P1 | MOD-09, MOD-11, MOD-13, MOD-14, MOD-17, MOD-18, CHT-46, puis MOD-12, MOD-19, MOD-20, MOD-16 | `/clear`, annonces, file AutoMod en temps réel, Shield Mode, chatters par rôle. Ensuite rôles, sondages et prédictions (diffuseur seulement en Helix), puis tableau de bord. | `moderator:manage:announcements`, `moderator:manage:automod` (+ `automod.message.hold`), `moderator:manage:shield_mode`, `moderator:read:chatters`, `channel:manage:vips`/`moderators`/`polls`/`predictions` | Moyen, **Compte requis** |
| 30 | Découverte P1 | DSC-05, DSC-09, DSC-11, ACC-11 | Filtre de langue. Résultat mis en avant. Flux vertical avec aperçu IVS (un seul lecteur actif), réglage de lecture auto. | `/streams?language=` | Moyen (mémoire, plusieurs lecteurs) |
| 31 | Réglages et accessibilité | ACC-09, ACC-18, ACC-30 | Restructuration des réglages, liens WebView (vérification), `Semantics` sur l'overlay et le chat. | — | Nul |
| 32 | Couche GQL privée P1 (flag) | INT-01→INT-07, INT-10, INT-15, INT-20, INT-21, CHT-14, CHT-16, CHT-32, CHT-38, CHT-41, CHT-42, MOD-10, MOD-15, SOC-04, SOC-08, SOC-10, DSC-06, DSC-10, DSC-12, DSC-15, PRF-04, PRF-12, PRF-18 (si non fait), PRF-20, ACC-13, ACC-22, ACC-26 | Même service que le commit 17, plus un client PubSub/Hermes pour les topics viewer (sondages, prédictions, points, hype train). Une feature par commit, chacune masquable. INT-26/27 (drops) et PRF-12 (chat replay) exigent `Client-Integrity` : à ne tenter qu'en dernier. | GQL privé + Hermes | **Élevé** |

## 6. Hors périmètre proposé

| Exclusion | IDs | Raison |
|---|---|---|
| Outils créateur | CRE-01→CRE-37, MOD-26→MOD-29 | Hors mission (spectateur et latence). Ingest et broadcast (CRE-03/04/05/07/09) impossibles proprement. Les réglages simples de sa chaîne (CRE-06/14/15/18/28/29) resteraient faisables en Helix plus tard. |
| Achats et monétisation | MON-01→MON-15, INT-08, INT-12→INT-14 | Play Billing et checkout sont propres à Twitch ; dépense de Bits en argent réel. Seul un lien web vers twitch.tv (MON-11) est envisageable. |
| Publicités | PLY-31, PLY-32, PLY-33, DSC-16 | SDK et tracking pub Twitch. Les segments SSAI restent lus tels quels. |
| DRM | PLY-28 | Licences Widevine/PlayReady signées pour Twitch. |
| Stories, réactions, shouts, recap | SOC-16→SOC-20, SOC-22, DSC-17, DSC-18, PRF-26, PRF-27 | Uniquement en GQL privé, faible valeur pour le viewer. |
| Guest Star, extensions | INT-28→INT-31 | WebRTC propriétaire, JWT d'extension. |
| Sécurité et cycle de vie du compte | ACC-05→ACC-08, ACC-14→ACC-17, ACC-19→ACC-21, ACC-23→ACC-25, ACC-27, ACC-31, ACC-32 | Déléguer à twitch.tv en WebView ou navigateur. Ne pas reproduire. |
| Technique interne, staff, debug | MSC-06→MSC-11, MSC-17, ACC-29 | RN, portails, OTA, Eppo, télémétrie Spade, Sprig et Branch sont internes à Twitch. Un menu debug maison (MSC-12) reste utile pour la latence. |
| Push FCM Twitch, Engage | MOD-30, DSC-22 | Clés et backend Twitch, liste blanche Google. |
| Divers P2 à faible valeur | PLY-29, PLY-30, CHT-24, CHT-26, CHT-33, CHT-37, CHT-43, CHT-47, INT-09, INT-16→INT-18, INT-22→INT-25, MOD-21→MOD-25, MOD-31, DSC-13, DSC-14, DSC-20, DSC-21, PRF-06, PRF-13→PRF-15, PRF-21→PRF-24 | À reconsidérer après P0/P1. PRF-13→15 viennent presque gratuitement avec le commit 18. |

## 7. Questions ouvertes

1. **Design system ONSET** : il n'existe nulle part dans le repo (ni `lib/`, ni `docs/`, ni l'historique). Le seul thème est Frosty : Material 3 seedé sur `#9146FF`, police Inter, kit `lib/widgets/` (`theme.dart`). Où est la source de vérité (Figma, doc, autre repo) ? Sans elle, les nouveaux écrans suivront le thème Frosty.
2. **Compte modérateur ou diffuseur** : l'utilisateur est-il modérateur, ou diffuseur, d'une chaîne active pour tester MOD-xx, CHT-46 et le commit 29 ? Lesquelles ? Sinon, ces groupes ne sont pas vérifiables et doivent passer après le reste.
3. **Jeton GQL `platform=android` / `playerType=mobile_player`** au lieu de `web`/`embed` (L7) ? Proposition : un réglage développeur, puis un A/B de latence et de pubs sur 3 chaînes avant de changer le défaut.
4. **GQL privé** : faut-il accepter les features qui exigent l'`auth-token` web (cookie twitch.tv) en plus de notre OAuth ? Cela pose une question de sécurité (stockage d'un second jeton), de CGU et de risque pour le compte.
5. **IVS 1.57** : la version officielle est une RC (1.57.0-rc.2). Accepte-t-on une RC si aucune 1.57.x stable n'est publiée ?
6. **Rebuffer to live** : le préfère-t-on désactivé (lecture fluide et rattrapage par accélération, comme l'officiel) ou activé (toujours au plus près du direct, avec des sauts) ? Proposition : désactivé par défaut avec le rattrapage, et une option.
7. **iOS** : est-il dans le périmètre à court terme ? WebView forcée maintenant, ou lecteur natif AVPlayer LL-HLS plus tard ?
8. **Notifications** : une approximation par polling (≥ 15 min, sans push) est-elle acceptable pour SOC-06 ?
9. **Reconnexion** : l'ajout de scopes (modération, whispers, `user:read:chat`, `user:read:emotes`) force une reconnexion. Faut-il tout demander d'un coup, ou ajouter les scopes progressivement ?
10. **Pubs SSAI** : elles passent aujourd'hui telles quelles dans IVS. Est-ce acceptable, ou faut-il au moins détecter et afficher le cue `X-TV-TWITCH-AD-*` ?
11. **Messages récents** : garde-t-on le service tiers `recent-messages.robotty.de` (CHT-02), ou cherche-t-on une source officielle (GQL privé) ?
