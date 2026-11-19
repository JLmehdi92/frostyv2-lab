# Resources named or shown in the video

Costs are only those shown on screen. Nothing here is verified beyond the video.

## Models
| Name | Use in the video | Cost info shown |
|---|---|---|
| Claude Fable 5.2 (effort Medium, fast mode off) | All builds | X card [0:30]: "up to 30 percent faster with 20 percent lower prices, available on paid plans". Model-picker tooltip: "Fable is the most capable model and draws down usage much faster than Opus." claude.com shows "Try it on Pro or Max". Presenter: "it's very cheap right now" [0:27]. |
| Claude Mythos 5.2 | Named in the @claudeai launch tweet only | — |
| GPT Image 2.6 (ChatGPT Images) | His viral posts: "GPT Image 2.6 is insane for fashion websites. zero photoshoot. zero models. one afternoon." | — |
| "GPT image 2.5" | Only as a past session name in his sidebar ("GPT image 2.5 human replac…") | — |

## Examples shown
- Felix Rieseberg's one-shot Fable 5.2 FPS game (tweet [0:40–0:51]), shown as an example of scale: "~$550 at API pricing, ~2.7M output and 445M input tokens, heavily cached. Took 8 hours!"

## Apps
| Name | What for |
|---|---|
| Claude desktop app (Code view, built-in browser pane) | New session → choose folder → pick model → prompt; previews local files (`file://…/index.html`, `localhost:8765`). "just go to Claude download … download it for free" [1:17–1:22]. |
| VoiceOS ("voiceos PRO") | Dictating every prompt, then pasting. |
| Rize | Probably the time-tracking app whose overlay is on screen [?]; the screen only says Claude "used Rize" with memory to learn about the user for the startup prompt. |
| Higgsfield ("Higgs field") | Asset generation for the game (sprites of islands, jet). Named in P3's second line. |
| Figma | Named only as "the era of static websites" being gone [0:07–0:10]. |

## Design-reference libraries
| Name | What it is | Cost / access shown |
|---|---|---|
| **motionsites.ai** (MotionSites) | The presenter's own prompt library: "All of the prompts that I create, I upload here" [3:06]. Categories Sites, Dashboards, Social, Backgrounds, 3D, Academy… Each card: "Copy prompt", "Edit in Studio". "800+ 3D Scrolling Websites, Motion Backgrounds…" (his post); the MCP library returned 631 designs. Some designs marked Free, others Premium. | "Go Unlimited →" on the site. |
| **studio.motionsites.ai** (MotionSites Studio, "Studio AI") | Open a design ("Customize Moss Island"), chat to change it, "Download code" → single HTML file (moss-island (1).html, 289 KB). | Sidebar [3:34–3:42]: **"Basic · $99/month"** and **"$42.58 of $99.00 AI budget used"** — the only cost figure shown for building, despite the promise at 0:19–0:27 to share "the cost of building this website". |
| **MotionSites MCP** | Inside Claude: search the library, render a widget of designs with View / Use; Use inserts "Let's use the X design (id: …)". Must be enabled with `/mcp` (Claude: "If it isn't listed, this session can't load it, because it was added after the session started"). | Premium vs Free per design. |
| jiro.build | "1,400+ designs your agent can pull in via MCP" (Threads post by heytanzil, shown 8:06–8:08) | — |
| designspells.com | "micro-interactions" (same post) | — |
| styles.refero.design | "real color and type systems" (same post) | — |
| supahero.io | "hero sections" (same post) | — |
| mobbin.com | "real app flows" (same post) | — |
| designrocket.io | In his Threads bio and Chrome shortcuts ("Design Rocket"); not explained | — |

The post's framing: "Stop designing slop with AI. Give your agent these references … you will get a much better outcome."

## MotionSites designs named
- Used in the demo: **Moss Island** (Mossline), **Reelmark** (id reelmark-v2, Creator Platform, Free), **Orange Horse** (id orange-horse, Creative, Premium).
- Offered by the MCP for Drumroll: Peakline Redshift (Premium, Claude's pick), Data Signal (Free), Reelmark, Eclipsio (Free), Draftwise, Motion Frame (Premium), LTX Video (Free), Orange Horse, Cosmo Forge (Premium).
- Palette widget: FinancialFocus, Cobalt Hour (Free, Claude's pick), DeepThink (Free), Max Reed Portfolio, … Waitlist, NimBus Pricing, Smart Pricing, Velorix IIC.
- Seen on the site: Spin Product, Card Story, Shelf Hero, Loops Virtual Store, Halo Prism, Video Ribbon, Sun Timeline, Runway Lookbook, Robot Jellyfish, Infinite Gallery, Helion Dispatch, Mars Trips, Fog, Portrait, Backpack Hero, Gridcore, Future Fashion (ORBE), Crystal Koi, Automation Machines, Particle Self, Outfit Carousel, Anchor AI, Orbit Sphere, Golden Portal, Ink Reveal, Particle Brain, Flower Valley, Halftone FAQ, Jellyfish Scroll, Solar Fog, Velaris, Oda Hero, Nightmast Studio, Internet Alchemist, Scanner Comparison, Tide Footer, Year Recap, VHS Archive, Virtual Fitting, Pink Rider, Glass Tree, Saffron, Zapline, Vertex3D.

## Fonts (chosen by Claude, not by the presenter)
Bricolage Grotesque 800 (display), Inter (body), JetBrains Mono (utility) for Drumroll v1. v3 switches to a condensed heavy caps display face (Anton/Bebas-like; name not shown), a mono body and a serif wordmark.

## Distribution (closing section, 7:18–8:21)
X/Twitter and Threads: "Just post simple designs of what you build", reuse your viral post's format with the trending model name, attach the screen recording, cross-post to Threads. Out of scope for this skill.

## Available in this environment (complement, not from the video)
- Firecrawl MCP (`firecrawl_scrape` with `formats: ["screenshot", "branding"]`) or a browser tool can open the reference libraries above when no MotionSites MCP exists. Firecrawl is paid per page: shortlist from one or two library pages, not a crawl, and get the user's yes first.
- MotionSites: prefer designs marked Free; never subscribe to Studio or unlock Premium content without the user's yes; borrow structure and type, never copy assets or code verbatim from a paid design.
- Higgsfield MCP (`generate_image`, default model gpt_image_2_6; `estimate_image_cost`, `balance`) can generate assets. It spends paid credits: estimate first and get the user's go-ahead.
- `frontend-design` skill for general aesthetic direction.
