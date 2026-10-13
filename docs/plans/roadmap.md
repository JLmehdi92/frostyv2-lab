# Feuille de route — parité Twitch Android 31.5.2 dans ONSET

Ordre fixé avec l'utilisateur (2026-10-13) : **VOD d'abord**, puis **Hype Train** (animations comprises, dans la DA ONSET), puis le reste de `GAP.md` par priorité. Chaque épopée suit le cycle ECC : plan (`planner`) → TDD (`tdd-workflow`) → review (`flutter-reviewer` / `kotlin-reviewer`) → build → un commit par feature.

Règles transverses :
- DA ONSET = `lib/theme.dart` + `lib/widgets/` (+ `FrostyColors`). Aucun asset, texte ou animation Twitch n'est copié : tout est redessiné.
- GQL privé autorisé par l'utilisateur, isolé dans un service dédié (`BaseApiClient`), avec repli propre si Twitch change l'API.
- Aucune régression : latence (panneau stats), 7TV/BTTV/FFZ, affichage modération (messages supprimés, durées de ban/TO), mini-player, PiP, WebView.

| # | Épopée | IDs GAP | Dépend de | Accès requis |
|---|---|---|---|---|
| E1 | **VOD** : liste des vidéos d'une chaîne, lecteur VOD natif (IVS : seek, ±10/30 s, vitesse, qualité, reprise), replay du chat synchronisé avec emotes 7TV/BTTV/FFZ, deep links `/videos/<id>` et `?t=` dans l'appli (plus de navigateur) | PRF-07→11, PRF-16, CHT-replay, MSC-01 | — | GQL anonyme (Client-ID public) + Helix |
| E2 ✅ (cartes chat reportées) | **Clips** : onglet Clips (période, tri), lecteur in-app media_kit (boucle, qualité, vitesse, PiP, tablette), replay du chat de la VOD, « Voir la vidéo complète », autres clips, liens `clips.twitch.tv` et `/clip/` dans l'appli — voir `clips.plan.md` | PRF-17, PRF-18, CHT-45 (liens) | E1 | GQL anonyme |
| E3 ⚠️ (Hermes fait ; EventSub non fait) | **Couche temps réel** : client PubSub/Hermes (+ EventSub `stream.online/offline`) partagé, reconnexion, sujets par chaîne | MSC-03, PLY-09 | — | anonyme pour les sujets publics |
| E4 ✅ | **Hype Train** : état initial GQL + événements temps réel, bannière au-dessus du chat, feuille détaillée, niveaux, progression, minuteurs, conducteurs, récompenses, variantes (Golden Kappa, Treasure, Mythic, Community, All-Time-High, partagé) et animations ONSET | INT-15→17 | E3 | anonyme (lecture) |
| E5 | **Bandeau « community highlights »** : sondages, prédictions, raids, épinglés, drops affichés en temps réel | INT-01→07, INT-19, CHT-13 | E3 | anonyme (lecture) ; voter/parier = session utilisateur |
| E6 | **Page profil de chaîne** : à propos, panneaux, planning, vidéos, clips, collections | PRF-01→06, PRF-12→15, PRF-20→29 | E1, E2 | Helix + GQL anonyme |
| E7 | **Chat** : commandes slash, verrouillage timeout/ban, bannières de mode, épinglés, filtres, couleurs lisibles | CHT-* restants | — | IRC + Helix |
| E8 | **Découverte** : flux d'accueil, recommandations, filtres langue/tags, flux vertical | DSC-* | — | Helix + GQL anonyme |
| E9 | **Fonctions liées au compte** : follow, notifications, whispers, channel points (gagner/dépenser), vote aux sondages/prédictions, abonnements affichés | SOC-*, INT-* écriture | E3 | **session Twitch de l'utilisateur pour le GQL** — décision à prendre avec l'utilisateur |
| E10 | Réglages et accessibilité restants | ACC-* | — | — |
| T ✅ | **Tablette** (Xiaomi Pad 7, ≥ 600 dp) : grilles, rail de navigation, plein écran sans rotation, chat paysage dimensionné en dp, hype train borné, réglages centrés, vignettes à la taille affichée, 120 Hz demandé — voir `tablet.plan.md` | MSC-14, DSC-01 | — | — |

Hors périmètre proposé (à confirmer avec l'utilisateur) : achats réels (Play Billing, Bits, abonnements), DRM, SDK publicitaire, outils de diffusion/streaming (ingest), Guest Star, fonctions staff/debug internes. Raison : impossibles à reproduire proprement hors de l'appli officielle (paiement et licences liés à Twitch) ou hors mission du spectateur.
