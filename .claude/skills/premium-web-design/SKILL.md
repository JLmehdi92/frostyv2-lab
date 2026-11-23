---
name: premium-web-design
description: >
  Workflow for building premium, animated, interactive landing pages and
  websites that do not look AI-generated: brand first, a short one-shot
  prompt, self-critique, real design references instead of adjectives,
  structure from one reference and typography from another while keeping
  your own palette, one signature interactive element, generated assets, and
  browser verification. Use when the user wants a new landing page, marketing
  site, portfolio, product page, startup site or a fresh visual direction that
  looks high-end, "premium", "expensive", "Apple-style", animated, 3D or
  scroll-driven, or says a page "looks vibe coded", "looks like AI slop" or
  "looks generic". Not for reproducing an existing mockup or design system
  pixel-for-pixel, not for conformance checks against a reference screen, and
  not for native/Flutter screens unless the user asks for a fresh visual
  direction.
---

# Premium web design

Distilled from a video by Viktor Oddy (@viktoroddy; watermark @n0tisma on X), 8:21, building sites with Claude Fable 5.2. `[m:ss]` = spoken (`references/transcript.md`); `seen m:ss` = on-screen text (`references/prompts.md`, `references/showcase.md`). Lines tagged **(complement)** are not from the video; **(synthesis)** is the analyst's reading of the screens; everything else is from the video. **(Donadon)** = from Tobia Donadon's design article (Nov 2026).

Video setup: Claude desktop app, a new session per project folder, Fable 5.2 at Medium effort, fast mode off.

The video's thesis: one short prompt gets a good page [1:42–2:07], but it only stops looking "vibe coded" once you feed the model **real design references** and mix them deliberately [5:35–7:17].

## Repository rules win

This skill is a default workflow, not an authority. (complement) Apply the rules of the repo that contains the output folder (nearest CLAUDE.md/AGENTS.md walking up); CLAUDE.md files of other repos loaded in the session do not apply, and a folder inside no repo is greenfield. When that repo has any of these, follow the repo and drop the conflicting step here:
- its own design system, art direction, brand palette, reference mockups or pixel-perfect comparison method;
- a rule to ask questions, interview or plan before coding (plan mode, "interview thoroughly", "plan first on changes touching more than N files");
- a font or icon policy (self-hosted fonts only, no third-party/CDN requests, one icon set, no emoji);
- a rule that new patterns go into the design system before code;
- i18n rules, a "no code comments" rule, or an animation rule (never remove one, never gate them behind reduced-motion).

In particular:
- Reuse the existing palette and fonts instead of inventing a brand (step 1); never pull a third-party reference's look over a design system the project already approved (step 4).
- "Do not ask any follow-up questions" (step 1) applies only to the brand-invention prompt for a fresh greenfield site. It never overrides a repo or user that requires asking or planning first.
- In a repo with a design system, mockup or pixel-perfect method (e.g. DropLink), references from step 4 feed a **proposal to the design system** first, written in its vocabulary; never code from them directly. No Google Fonts `<link>` or CDN script if the repo forbids third-party requests.
- **App + website repos** (e.g. ONSET: a Flutter app plus its static landing site in `site/`): on the website the full workflow applies, step 8 checks included, but the brand already exists, so skip step 1 and keep the app's art direction, palette, fonts and screenshots. If the repo restricts who may change the site (e.g. "never touch `site/**` without the user's go"), get that go before editing.
- **Non-web UIs** (e.g. the Flutter app itself): only the design principles apply (steps 3–6: critique, references, structure/type mixing, signature element, restraint). Skip the browser and 375 px checks of step 8; verify with the platform's own tools (`flutter analyze`, widget/golden tests, a run on a device or emulator at a small phone size).

## Paid steps need a yes

Every paid step needs a cost estimate shown to the user and their explicit yes **before** it runs, including when a template below or a subagent triggers it: Higgsfield or any image/video generation, Firecrawl scraping (billed per page), subscribing to MotionSites Studio ($99/month shown) or unlocking Premium designs. (complement)

If no user can answer (subagent, autopilot, no-cost run), never run a paid step; take each step's free route: step 4 uses `references/showcase.md`, step 7 draws assets in code, step 8 needs nothing paid. (complement)

## Workflow

### 1. Brand first [4:36–5:28]
Before any page, create (or load) the brand: name, logo, colour palette, fonts. Show it, then build. The video's prompt ends:
> Start from the logo and show me what you created first
> Do not ask any follow-up questions

What came out and is worth copying: a `brand.html` sheet with the logo, lockups (mono, app icon, nav size 28px), **named colours with roles** (Stage black, Wing, Smoke, Drumskin, Brass, Signal) and a three-face type system (display Bricolage Grotesque 800 / body Inter / utility JetBrains Mono). Claude also used memory and local context to "learn about you" (seen ~5:16).
- When the user gives a brief and no repo rule asks for an interview or plan first, do not stall on clarifying questions: make the calls, state them, move on.
- (complement) If the project already has a brand, the brand sheet is just a list of its existing tokens.
- (complement) "Show it" = write `brand.html` next to the page and give its path (or a screenshot); wait for approval only if the user asked to review it.
- (complement) Fonts: with no font policy, load them with a Google Fonts `<link>` (`display=swap`) plus a fallback stack; if the repo self-hosts fonts or forbids CDNs, follow it.

### 2. Short one-shot prompt, v1 [1:42–1:53]
Keep the first prompt short: subject + "animated premium landing page" + the three look words. If step 1 ran, v1 uses that brand (the "Brand + site in one go" template does steps 1–2 together, as P4 did). Sent verbatim (seen 1:56):
> Build an animated landing page premium for a minimalist electronic bike brand, scroll animation, bold type, mobile first.
> Make it quick, no testing.

"Make it quick, no testing" is the presenter's speed setting for a draft; do not carry "no testing" into the final version (see step 8). (complement) Drafts still get the checklist's "look" section; its Technical section runs on the version you hand over.

### Alternative start: remix a proven design [3:11–4:32]
Open a design in a library (MotionSites Studio → "Download code", a single 289 KB HTML file), attach it in a new session and prompt the transformation (P3 turned the Moss Island landing page into a 3D flying game). The result inherits the source's palette, type and micro-copy (`references/showcase.md` §3). Premium designs and Studio are paid: see "Paid steps need a yes".

### 3. Self-critique, then one improvement pass [2:07–2:58]
Claude closed v1 with its own critique (seen 2:13): what carries the page, what is plain, and "the one thing worth cutting is the sliding type band, which is the most generic element". Do the same after every version: name the weakest, most generic element and fix or cut it.
- (Donadon) **Default-look test.** Generated pages land in four looks: the paper edition (serif headline with one italic word in the accent colour, tiny mono labels everywhere), the launch page (black, purple glow, tilted screenshot), the dashboard (four KPI cards with sparklines), the dark dev tool. If the page shares three features with one of them, go back to the idea, not the styling.
- (Donadon) **Swap test.** Put a competitor's logo on the page; if nothing feels off, the idea never made it onto the page.
- (Donadon) **Do not overcorrect.** "Don't be generic" yields the studio portfolio (off-white, giant headline, numbered mono labels, a clock in the header). Aim for specific; minimal is only one way to get there.

The improvement prompt [2:17–2:37]:
> Instead of having just backgrounds, just generate some assets to have on the page as well, but make it quick also.
> And also make it a little bit more premium, similar to Apple style or something.

Result (OHM v2): huge tight centred headline, grey subcopy, pill CTAs, sentence case, photoreal product images, bento stat cards, pinned scroll sections, one accent colour, a working colour picker, a full-bleed photo transition. "Apple style" here means **restraint**: fewer, bigger elements, one accent.

### 4. Pull real references, not adjectives [5:29–5:56]
Presenter's verdict on a complete but conventional v1: "it is pretty good, but again, it doesn't look that impressive" [5:31]. Fix: ask a design library for matching designs.
> Using Motionsites MCP, find me a few options of the designs that we can apply to this website

Claude filtered the 631-design library by theme ("video, launch and dark-with-orange"), showed nine with a "Why it fits" table and a pick, and the user chose **by name** ("Let's use the Reelmark design (id: reelmark-v2).").

If the library MCP is configured but its tools are absent, it was added after the session started (Claude in the video: type `/mcp`; "If it isn't listed, this session can't load it"): ask the user to enable it with `/mcp` or start a new session; otherwise use the route below.

**Without the MotionSites MCP** (complement): browse the same kind of library with a browser tool, or Firecrawl (`firecrawl_scrape` with screenshot; paid per page: shortlist from one or two library pages, not a crawl), and shortlist 3–9 named designs with one line each on why they fit:
- motionsites.ai (the presenter's library: animated/3D hero and landing prompts)
- jiro.build (1,400+ designs, has an MCP), designspells.com (micro-interactions), styles.refero.design (real colour and type systems), supahero.io (hero sections), mobbin.com (real app flows): the list from a Threads post (seen 8:07).
- (complement) Prefer designs marked Free; never subscribe or unlock Premium content without the user's yes; borrow structure and type, never copy assets or code verbatim from a paid design.

- (complement) **Free route** (no library access or no budget): name two entries from `references/showcase.md`, one for structure and one for typography, say why, and borrow their listed traits (descriptions, not code). With no user to pick, pick yourself and say why.

Let the user pick, or pick and say why. A named reference gives the model concrete structure, type and motion to imitate; "make it premium" does not. (Donadon) Slop is every choice left on the default, and a model defaults when it has nothing to look at: references are what it looks at.

### 5. Structure from one reference, typography from another, palette from you [6:04–7:17]
The decisive moves of the video:
- After picking Reelmark: "But make sure to keep our own colors and the background dark. Do not apply the new color style, just the structure from the website that I selected." [6:04–6:14] → better hero and an interactive carousel, but "overall, it looks vibe coded in terms of colors and structure" [6:29].
- Then a second, more distinctive reference: "For the typography, the structure of the elements, and the fonts, let's use this version. Let's use the Orange Horse design (id: orange-horse)." [6:35–6:57] → the final v3.
- Claude kept the earlier signature element (the carousel) as its own section instead of deleting it, and offered a palette change ([Keep current colors] / [Apply Cobalt Hour]; no click is shown). He had already ignored its palette-widget suggestion (Cobalt Hour).

Rule: borrow **layout/structure** and **type** from references, never their colours; your palette and background stay. Keep good elements from previous versions unless told to drop them.
- (complement) When both references are already chosen, both may be applied in one pass; back up before each pass (step 8).

### 6. One signature interactive element (synthesis from the screens; the presenter only says "We have this interactive element" [6:26])
Each page shown is built around one: Saffron's cursor-reactive particle field, Vante's 3D ribbon, Leon Vasari's VHS spines that pull out on hover, Mossline's floating island with scroll zoom, Offcut's clothing rail, OHM's self-drawing line bike, Drumroll v2's curved 9:16 card carousel (kept in v3 as "Sample cuts", where the ASCII field became the hero). Pick one that fits the product's story and make it the hero. (Donadon) It is a signature move: an interaction someone would describe to a friend; fade-up on scroll and hover lift do not count. Patterns and traits: `references/showcase.md`.

### 7. Generate real assets
"Instead of having just backgrounds" [2:20]: photoreal product shots, scenes, sprites. In the video: four images for OHM v2 (generator not shown), **Higgsfield** for the game sprites ("Use Higgs field for assets generation…", P3), and **GPT Image 2.6** in his fashion posts.
- (complement) In this environment the `higgsfield` MCP may be available (`generate_image`, default gpt_image_2_6). It spends paid credits: run `estimate_image_cost`, tell the user the cost, and wait for a yes before generating. Otherwise use the project's own images; never hotlink random images.
- (complement) **Free route**: draw the assets in code (inline SVG product illustration, canvas, CSS) as real content that shows the product. Placeholders only as a last resort, and then mark the checklist's "real assets" item as not met.

### 8. Back up, then verify [3:36, 7:01]
- Before each restyle, save the previous version (`index.before-orangehorse.html`), so a worse result can be reverted.
- Check in a real browser, as Claude did for v3: no console errors; no horizontal scroll at desktop **and** 375 px; nothing overlaps on phones (it hid the scroll button that overlapped the headline); interactive elements still work.
- **Images must actually load.** OHM v2's images vanished in the preview ("iamges not displaying") because relative `assets/hero.jpg` paths had nothing to resolve against in a snapshot preview. Claude embedded them directly in index.html (probably as base64 data URIs; file ~1.2 MB) but could not confirm the fix. Serve the folder over a local server, as the Drumroll demo did on `localhost:8765` (complement: e.g. `python3 -m http.server 8765` in the site folder, then open `http://localhost:8765/`; preferred, keeps the page light), or embed small images, then re-open and look.
- Report what you checked and what you did not ("I did not test dragging the carousel by hand").
- (complement) How to run each check (widths, tool, overflow and overlap methods, asset and font loading, scroll pages): `references/checklist.md` § "How to check".

### 9. Iterate, with a stop rule
Each round: look at it, name what is generic (colours? structure? type? assets?), fix that one axis with a reference or a targeted prompt, verify. The video stopped after 3 versions.
- (complement) **Stop** when every item of `references/checklist.md` passes, or after 3 rounds without a clear gain: then show the versions side by side and let the user choose. With no user, hand over the best version and list the others with their paths.

## Prompt templates

Verbatim prompts with what each produced: `references/prompts.md`. Cleaned reusable versions (complement, wording mine, intent from the video). Use "Brand + site" only for a fresh greenfield site with no repo rule against skipping questions. (complement) When you are the builder, treat each template as that step's instructions.

**Brand + site in one go**
```
Create a brand for <product/idea>: name, logo (show lockups), a named colour palette with roles, and a display/body/utility font system. Start from the logo and show me the brand sheet first, then build a one-page website with hero, features, pricing, sign-up. Do not ask any follow-up questions.
```

**v1 one-shot**
```
Build an animated premium landing page for <subject> using the brand in <brand.html / the project's tokens>. Scroll animation, bold type, mobile first. End with a short critique: what carries the page and the most generic element to cut.
```

**Improvement pass**
```
Instead of plain backgrounds, generate real assets for the page (<what: product shots, scene, objects>). Make it more premium, Apple-style restraint: fewer, bigger elements, one accent colour. (If the generator is paid, e.g. Higgsfield: estimate the cost, tell me, and wait for my yes before generating.)
```

**Find references**
```
Find 5-9 design references from <library> that fit this site (<theme, palette, mood>). For each: name, link, Free or Premium, why it fits. Recommend one. Do not unlock or pay for anything, and ask me before any paid scraping.
```

**Apply structure only**
```
Use the structure and layout of <reference name>. Keep our own colours and background; do not apply its colour style. Keep <signature element> from the current version as its own section. Save the current file as <name>.before-<ref>.html first.
```

**Apply typography**
```
For the typography, the structure of the elements and the fonts, use <second reference>. Keep our palette. Then check in the browser: no console errors, no horizontal scroll at desktop and 375px, images load, interactions still work. Tell me what you did not test.
```

**Remix into a game** (P3)
```
Based on this landing page (attached), turn it into a 3D endless runner / flying game in one HTML file, reusing its palette, type and micro-copy. Generate the game assets with <tool>. (If the tool is paid, e.g. Higgsfield: estimate the cost, tell me, and wait for my yes before generating.)
```

## References
- `references/transcript.md`: full timestamped transcript 0:00–8:21.
- `references/prompts.md`: every prompt verbatim, off-camera follow-ups included, and what it produced.
- `references/showcase.md`: every site shown, with the traits that make it read as premium (pattern library).
- `references/resources.md`: tools, libraries, models, and the costs shown (MotionSites Studio "Basic · $99/month").
- `references/checklist.md`: review checklist for any result.

## Not claimed by the video / out of scope
- The video does not show how OHM v2's images were generated and gives no full cost breakdown (only the MotionSites Studio plan). Do not repeat these as facts.
- The video's last minute (posting the screen recording on X and Threads, 7:18–8:21) is summarised in `references/resources.md` and is not part of this workflow.
