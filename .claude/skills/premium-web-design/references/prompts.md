# Every prompt in the video, verbatim

Typos and dictation errors are kept as they appear on screen. "Spoken" = the subtitle wording; "Sent" = the text read in the chat bubble or prompt box. Model for all sessions: Claude Fable 5.2, effort Medium, in the Claude desktop app (Code view). Most prompts are dictated by voice (VoiceOS) and pasted.

## P1 — e-bike landing page, one shot [1:42–1:53]

Spoken:
> Build an animated premium landing page for a minimalist electric bike brand. Scroll animation, bold type, mobile first.

Sent (seen at 1:56):
> Build an animated landing page premium for a minimalist electronic bike brand, scroll animation, bold type, mobile first.
> Make it quick, no testing.

Produced: **OHM v1** — "One electric bike. Nothing extra.", giant black grotesque wordmark over a self-drawing line bike, pinned black "Anatomy 01/03–03/03" sections, a "NO SCREEN / JUST RIDE" marquee, a finish picker, reserve form. Verdict [2:07]: "It doesn't look vibe coded like what we've seen before with the previous model, but I still think it can be improved."

Claude ended its answer with a self-critique (seen 2:13):
> Critique: the wordmark and the self-drawing bike carry the page, and the specs section is plain by comparison. The one thing worth cutting is the sliding type band, which is the most generic element and delays the finish picker.

## P1b — off-camera tweak (seen in chat history at 2:13–2:16)

> make the bike lighter color, now it's too black

Claude: hero bike set to a light warm grey (#A19F98), finish-picker tyres softened; "I haven't checked it in a browser."

## P2 — improvement pass: real assets + Apple-style [2:17–2:37]

Sent as one bubble (second part dictated and queued, seen at 2:40):
> Instead of having just backgrounds, just generate some assets to have on the page as well, but make it quick also.
>
> And also make it a little bit more premium, similar to Apple style or something.

Spoken: "Generate, instead of having just backgrounds, generate some assets to have on the page as well, but make it quick." / "And also make it a little bit more premium, similar to Apple style or something."

Produced: **OHM v2** — Apple-like hero ("Nothing extra.", grey subcopy, black pill CTA), photoreal silver e-bike, bento stat cards, working colour picker, full-bleed "Just ride." street photo, footer. The generated assets were four image files (`assets/hero.jpg`, …). How they were generated is not shown. Verdict [2:58]: "Pretty good for one prompt."

## P2b — off-camera bug report (seen in chat history at 3:36–3:39)

> iamges not displaying

Claude's reply (verbatim):
> The images were missing because the Browser pane loads the page as a standalone snapshot, so the assets/hero.jpg-style paths had nothing to resolve against. I've embedded all four images directly inside index.html, so the page no longer depends on the assets folder. I couldn't confirm the fix in the pane: it is still showing the old copy and wouldn't reload, possibly because the file is now about 1.2 MB. A local preview server also failed, because it isn't allowed to read the Downloads folder. To see the current version, open the file in your own browser: open "/Users/viktor/Downloads/fable 5.2/index…"

Lesson: relative asset paths broke in the preview; the fix was embedding the images directly in index.html (probably as base64 data URIs; page grew to ~1.2 MB). The fix was never confirmed on screen.

## P3 — turn a downloaded landing page into a 3D game [3:43–4:05]

Attachment: `moss-island (1).html` (289 KB, downloaded from MotionSites Studio via "Download code").

Sent:
> Based on this landing page, I want to basically do a finding experiment. I want to turn this landing page into a 3D endless runner, maybe like a flying game in one HTML using 3D or whatever. So just make that and make it quick.
> Use Higgs field for assets generation for the game but make it quick please.

("finding" = dictation of "fun"; the second line was added off-camera. Spoken: "Based on this landing page, I want to do a fun experiment. I want to turn this landing page into a 3D endless runner, maybe like a flying game, in one HTML file using 3D or whatever. So, just make that and make it quick.")

Claude's progress: "Assets are generated and the game code is written — now cutting the sprite backgrounds out and assembling the single HTML file."

Produced: **Mossline "Fly the Living Planet"** game at localhost:8765. "Well, not 3 seconds, more like 30 seconds." [4:17]; "it works exactly as you would expect" [4:29].

## P4 — invent a startup, brand first [4:36–5:09]

Sent (read at 5:10):
> Invent a startup based on everything about me and create a name, logo, color palette, and then build a one-page website with hero, pricing, sign-up, features, anything that can make money for my startup. That would be it
>
> Start from the logo and show me what you created first
>
> Do not ask any follow-up questions

(Spoken: "everything you know about me".) Claude used memory and local context ("used Rize": probably the time-tracking app whose overlay is on screen [?]) to "learn about you".

Produced: **Drumroll** brand sheet (`brand.html`: logo, lockups, 6-colour named palette, Bricolage Grotesque 800 / Inter / JetBrains Mono) then **Drumroll v1** landing. Verdict [5:29–5:34]: "it is pretty good, but again, it doesn't look that impressive."

## P4b — off-camera (seen in chat)

> no new session i need to dit this site

Claude explained that the MotionSites MCP must be enabled via `/mcp` in the session.

## P5 — pull real design references [5:35–5:44]

Sent (VoiceOS history):
> Using Motionsites MCP, find me a few options of the designs that we can apply to this website

Produced: widget of 9 designs from the 631-design MotionSites library, plus a "Why it fits" table and Claude's pick (Peakline Redshift). Claude: "I picked them by filtering the 631-design library for video, launch and dark-with-orange themes rather than reading every entry."

## P6 — pick by name [~5:50]

Clicked **Use** on Reelmark, which inserted and sent:
> Let's use the Reelmark design (id: reelmark-v2).

## P7 — structure only, keep own colours [6:04–6:14]

Queued while P6 ran:
> But make sure to keep our own colors and the background dark. Do not apply the new color style, just the structure from the website that I selected.

Produced: **Drumroll v2** — centred hero, handwritten annotations, curved 3D carousel of 9:16 video cards. Verdict [6:23–6:34]: "It does look much better for the hero section. We have this interactive element. But overall, it looks vibe coded in terms of colors and structure."

## (Palette widget, no visible prompt) [?]

Between P7 and P8 Claude shows "Here are nine MotionSites designs to take a color palette from, all on a dark background so the current layout carries over." (pick: Cobalt Hour). No user message asking for it is visible; it was either sent off-camera or offered by Claude unprompted. He ignores it.

## P8 — typography and element structure from a second reference [6:35–6:57]

Sent (read at 6:52–6:56), dictated text + Use click on Orange Horse:
> For the typography, the structure of the elements, and the fonts, let's use this version.Let's use the Orange Horse design (id: orange-horse).

Produced: **Drumroll v3** — cursor-reactive ASCII field hero, condensed heavy red-orange caps, mono body, serif wordmark, bracketed mono section labels, Reelmark carousel kept as a "Sample cuts" section. Claude's report:
> Checked in the browser: no console errors, the carousel still scrolls, and there is no horizontal scroll at desktop or 375px. On phones the scroll button is hidden because it overlapped the headline. I did not test dragging the carousel by hand.
> The version before this change is saved as index.before-orangehorse.html; the current page is index.html.

Then offered [Keep current colors] / [Apply Cobalt Hour] (no click is shown; the video ends on the site). Verdict [7:01–7:17]: second section, third, features, pricing, "the promo codes, which is great … we can launch it, run ads, or make social media content for this and start making money just like that."
