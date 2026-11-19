# Review checklist

Run the "Does it still look vibe coded?" section on every version; run the Technical section on the version you hand over (complement). Items marked (video) come from the presenter's verdicts or Claude's own checks in the video; items marked (complement) are added.

## Does it still look vibe coded?
The presenter judged each version by eye (2:07, 5:31, 6:29). Ask the same questions he implicitly answered:
- [ ] (video) Is there one **signature interactive element** a visitor would remember? ("We have this interactive element" [6:26])
- [ ] (video) Are the **colours** distinctive, or a default dark-SaaS / purple-gradient look? ("vibe coded in terms of colors" [6:29])
- [ ] (video) Is the **structure** more than the standard hero → 3 cards → features grid → pricing → FAQ stack? ("…and structure" [6:31])
- [ ] (video) Is the **typography** a deliberate system (one loud display face + a utility face), not one default sans? (the v3 fix [6:35])
- [ ] (video) Are there **real assets** instead of "just backgrounds"? [2:20]
- [ ] (video) Did you name the weakest, most generic element and cut or fix it? (Claude's critique of the marquee, seen 2:13)
- [ ] (complement) Type at poster scale with tight tracking somewhere above the fold.
- [ ] (complement) Palette = base + one accent; secondary colours only in small doses.

## Brand
- [ ] (video) Name, logo, named palette and type system exist and were shown before the page (P4).
- [ ] (video) When a reference was applied, **your own colours and background survived** (P7: "keep our own colors… do not apply the new color style").
- [ ] (complement) In an existing project, the project's own tokens/design system were used, not new ones.

## Technical (Claude's checks in the video, 7:01)
Web pages only. For non-web UIs (e.g. Flutter), replace this section with the platform's own checks: `flutter analyze`, widget/golden tests, a run on a device or emulator at a small phone size.

- [ ] (video) No console errors.
- [ ] (video) No horizontal scroll at desktop **and** at 375 px.
- [ ] (complement) Every brand face loaded (`document.fonts.check()` true for each).
- [ ] (video) Nothing overlaps on phones (v3 hid the scroll button because it overlapped the headline).
- [ ] (video) Interactive elements still work after the restyle (carousel still scrolls). State what you did **not** test (Claude: "I did not test dragging the carousel by hand").
- [ ] (video) **Images actually display** in the real preview, not just on disk. Relative `assets/` paths broke in a snapshot preview ("iamges not displaying", 3:36). Fix: serve over a local server (e.g. `python3 -m http.server 8765`, complement), or embed the images directly in the HTML (probably as base64 data URIs), then re-check; watch page weight (embedding pushed it to ~1.2 MB).
- [ ] (video) A backup of the previous version exists before a restyle (`index.before-orangehorse.html`).
- [ ] (complement) Mobile first (P1 asked for it): check 375 px before desktop.
- [ ] (complement) Animations run smoothly; heavy canvas/WebGL effects degrade on small screens. Reduced motion: greenfield default = a static canvas frame and reveals visible at once; a repo's animation rule wins (e.g. a repo that forbids gating animations on reduced motion).
- [ ] (complement) Text contrast readable on the chosen palette; tap targets at least 44 px.

## How to check (complement)
- **Widths and tool:** desktop 1440×900, phone 375×812, with Playwright (or the browser tool); save a screenshot at each width.
- **Horizontal scroll:** `document.documentElement.scrollWidth <= clientWidth` **and** no element's `getBoundingClientRect().right` exceeds the viewport width. `overflow-x: hidden` masks overflow; do not rely on it.
- **Overlap:** at 375 px compare the bounding boxes of the headline, the CTA and fixed controls, and look at the screenshot.
- **Assets loaded:** not only `<img>` (`complete && naturalWidth > 0`): canvases painted, fonts loaded (`document.fonts.check()` per brand face), CSS backgrounds loaded.
- **Scroll pages:** scroll through before a full-page screenshot (so reveals fire), and take a viewport screenshot inside each pinned/sticky section.

## Business sections (when the page sells something) (video, P4 / v3)
- [ ] Hero with one clear action, pricing, sign-up, features.
- [ ] (optional, from the video) Pricing architecture: tiers + a one-off option + a partner/referral offer ("the pricing, the promo codes, which is great" [7:09]).

## Paid steps (complement)
- [ ] Every paid step (image generation, Firecrawl scraping, Premium designs or a Studio subscription) had a cost estimate and the user's yes before it ran.

## Honesty of the report
- [ ] (video) Say what was checked and what was not (Claude: "I haven't checked it in a browser", "I couldn't confirm the fix in the pane").
- [ ] (complement) Do not claim "verified" without having opened the page.
