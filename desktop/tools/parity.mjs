import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', '..');
const rel = (p) => path.join(root, p);
const walk = (p) => !fs.existsSync(rel(p)) ? [] : fs.statSync(rel(p)).isDirectory() ? fs.readdirSync(rel(p)).flatMap((n) => walk(path.posix.join(p, n))) : [p];
const generated = (f) => /\.(g|freezed|mocks)\.dart$/.test(f) || /lib\/l10n\/app_localizations.*\.dart$/.test(f);
const sources = ['lib', 'android/app/src/main/kotlin', 'ios/Runner', 'packages/simple_pip_mode/lib', 'packages/simple_pip_mode/android']
  .flatMap(walk).filter((f) => /\.(dart|kt|swift)$/.test(f) && !generated(f)).sort();
const tests = new Set(walk('test').filter((f) => f.endsWith('_test.dart')));
const specs = fs.readdirSync(rel('desktop/SPEC')).filter((f) => /^\d\d-.*\.md$/.test(f) && !f.startsWith('00') && !f.startsWith('12')).sort();
const specText = Object.fromEntries(specs.map((s) => [s, fs.readFileSync(rel(`desktop/SPEC/${s}`), 'utf8')]));
const specOf = (f) => specs.find((s) => specText[s].includes(`### ${f}\n`) || specText[s].includes(`### \`${f}\`\n`));

const platform = /(services\/(floating_player|background_audio|audio_focus|cast_bridge|network_metering|locale_bridge|notification_settings_link|launch_info|onset_installer|twitch_web_token_service|telemetry|profile_image_picker)|services\/go_live\/go_live_worker|services\/notifications\/|utils\/pip_callbacks)/;
const player = /(screens\/channel\/video\/(latency_controller|live_edge_guard|buffer_fallback|ivs_recovery|ivs_player_config|latency_stats|player_engine_resolver|live_progress|live_state_watcher|stores\/)|screens\/vod\/(stores\/|vod_player_controller|player_media)|screens\/clips\/(clip_media_backend|stores\/clip_player_store)|home\/live_feed\/live_preview|services\/playback_)/;
const core = /^lib\/(apis|models|l10n|stores)\/|^lib\/services\/|\/stores\/|_(reducer|queue|sequence|math|clock|timings|placement|filters|commands|history|delay_queue|restrictions|tracker)\.dart$|^lib\/utils\/(?!pip_callbacks)|^lib\/constants\.dart$/;
const overrides = {
  'lib/utils/context_extensions.dart': 'onset-ui', 'lib/utils/modal_bottom_sheet.dart': 'onset-ui', 'lib/utils/share_link.dart': 'onset-platform',
  'lib/utils/link_router.dart': 'onset-core + onset-platform (parse in core, launch via UrlLauncher)', 'lib/services/font_licenses.dart': 'onset-ui', 'lib/services/cache_manager.dart': 'onset-platform',
  'lib/screens/vod/stores/channel_videos_store.dart': 'onset-core', 'lib/services/notifications/activity_log.dart': 'onset-core',
  'lib/stores/mini_player_store.dart': 'onset-player', 'lib/screens/channel/video/player_controller.dart': 'onset-player',
  'lib/screens/channel/video/quality_selection.dart': 'onset-player', 'lib/screens/channel/video/web_page_init.dart': 'onset-player',
  'lib/screens/channel/video/web_content_gate.dart': 'onset-player', 'lib/screens/vod/stores/up_next_store.dart': 'onset-core', 'lib/screens/vod/stores/vod_chat_replay_store.dart': 'onset-core',
};
const widgets = (f) => /import\s+'package:flutter\/(material|widgets|cupertino|rendering|painting|gestures|animation|scheduler)\.dart'/.test(fs.readFileSync(rel(f), 'utf8'));
const crate = (f) => {
  if (overrides[f]) return overrides[f];
  if (/kotlin\/app\/onset\/Ivs/.test(f)) return 'onset-player (replaced by LL-HLS + libmpv)';
  if (!f.startsWith('lib/')) return f.includes('simple_pip_mode') || f.startsWith('android/') || f.startsWith('ios/') ? 'onset-platform (replaced)' : 'onset-platform';
  if (f === 'lib/main.dart') return 'onset-app';
  if (platform.test(f)) return 'onset-platform';
  if (player.test(f)) return 'onset-player';
  if (core.test(f)) return widgets(f) ? 'onset-core + onset-ui (split)' : 'onset-core';
  return widgets(f) ? 'onset-ui' : 'onset-core';
};
const credit = new Map();
const claimed = new Set();
for (const tf of tests) {
  const src = fs.readFileSync(rel(tf), 'utf8');
  const mirror = tf.replace(/^test\//, 'lib/').replace(/_test\.dart$/, '.dart');
  const targets = new Set([...src.matchAll(/import\s+'package:onset\/([^']+\.dart)'/g)].map((m) => `lib/${m[1]}`).filter((x) => !generated(x)));
  if (fs.existsSync(rel(mirror))) targets.add(mirror);
  for (const x of targets) { if (!credit.has(x)) credit.set(x, []); credit.get(x).push(tf); claimed.add(tf); }
}
const repoWide = [...tests].filter((x) => !claimed.has(x)).sort();
const testsFor = (f) => {
  const all = credit.get(f) ?? [];
  const mirror = f.replace(/^lib\//, 'test/').replace(/\.dart$/, '_test.dart');
  return all.sort((a, b) => (b === mirror) - (a === mirror) || a.localeCompare(b));
};
const proof = (f, c, t) => {
  const p = [];
  if (t.length) p.push(`ported tests (${t.length}): ${t.slice(0, 6).map((x) => '`' + x + '`').join(', ')}${t.length > 6 ? `, +${t.length - 6} more importing it` : ''}`);
  if (c.includes('onset-ui')) p.push('screen/state golden vs Flutter reference + spec values');
  if (c.startsWith('onset-platform')) p.push('Windows integration check on device');
  if (c === 'onset-player') p.push(/screens\/(vod|clips)\//.test(f) ? 'VOD/clip playback check: start position, seek, rates, qualities, captions, fallback' : 'latency gate on a live stream (target 1.2-1.5 s Ultra)');
  if (!p.length) p.push('behaviour per spec, covered by area tests in 12-tests-index.md');
  return p.join('; ');
};

const rank = (c) => c.startsWith('onset-core') && !c.includes('+') ? 0 : c.startsWith('onset-player') || c.startsWith('onset-platform') ? 1 : c.includes('onset-ui') ? 2 : 3;
const importsOf = (f) => f.startsWith('lib/') ? [...fs.readFileSync(rel(f), 'utf8').matchAll(/import\s+'package:onset\/([^']+\.dart)'/g)].map((m) => `lib/${m[1]}`).filter((x) => !generated(x)) : [];
let splits = 0;
const missing = [];
let rows = '';
for (const f of sources) {
  const s = specOf(f);
  if (!s) missing.push(f);
  let c = crate(f); const t = testsFor(f);
  const up = importsOf(f).filter((x) => fs.existsSync(rel(x)) && rank(crate(x)) > rank(c));
  if (up.length && !c.includes('split')) { c += ` (split: ${up.length} import(s) from higher layers move behind core types/traits)`; splits++; }
  rows += `| \`${f}\` | ${s ? `\`${s}\`` : '**MISSING**'} | ${c} | ${proof(f, c, t)} | pending |\n`;
}

const defects = specs.map((s) => {
  const t = specText[s];
  const i = t.search(/\n(?:#{2,3} |\*\*|- \*\*|- )Known Android defects[^\n]*\n/);
  if (i < 0) return `### ${s}\n\n(none recorded)\n`;
  const start = t.indexOf('\n', i + 1) + 1;
  const rest = t.slice(start);
  const bullet = /^\n?- /.test(t.slice(i, i + 3)); const end = rest.search(bullet ? /\n#{1,3} |\n- |\n\n(?![ |0-9])/ : /\n#{1,3} /);
  const block = (end < 0 ? rest : rest.slice(0, end)).replace(/\s+$/, ''); const ind = Math.min(...block.split('\n').filter((l) => l.trim()).map((l) => l.match(/^ */)[0].length)); return `### ${s}\n\n${block.split('\n').map((l) => l.slice(ind)).join('\n')}\n`;
}).join('\n');

const out = `# ONSET PC parity matrix

Generated by \`desktop/tools/parity.mjs\` from the area specs. One row per Android source file: where it is specified, which Rust crate owns its PC equivalent, and the proof that closes the row. Status moves from \`pending\` to \`verified\` only when its proof passes in a later phase.

## Mobile-only behaviour and its PC replacement

| Android | PC |
|---|---|
| Screen rotation, orientation lock, immersive mode, landscapeCutout | Fullscreen, window resize, borderless fullscreen |
| Back button / predictive back | Esc and mouse back button, same pop order |
| Touch gestures (swipe, drag, pinch, long press) | Mouse/trackpad equivalents (drag, wheel, right-click, Ctrl+wheel) plus touch on touch screens; keyboard shortcuts added |
| Haptics | No-op (decision D12), visual feedback kept |
| Play Store in-app review | None (no store) |
| Audio focus / headphone unplug | Pause on device removal and communications ducking (decision D8) |
| Background audio service + media notification | Keeps playing when minimised; SMTC media controls (decision D13) |
| Refresh-rate request | Vertical sync |
| Per-app language (Android 13) | ONSET language setting |
| Picture-in-picture and floating overlay window | Always-on-top mini-player window; in-app mini player kept (decision D5) |
| WorkManager background go-live check | Tray-resident app running the 90 s poller (decision D6) |
| Local notifications + permission prompt + notification settings link | WinRT toasts (decision D7); Windows notification settings via \`ms-settings:notifications\` |
| IVS Android player | Rust LL-HLS fetcher (Twitch prefetch) + libmpv, same event contract (decisions D1, D2) |
| media_kit | libmpv directly |
| webview_flutter + TwitchCookies | wry (WebView2), cookie read via WebView2 cookie manager, loaded only when needed |
| Metered-network bridge | WinRT \`NetworkInformation\` connection cost |
| Launch info / splash tile | Launch intro storyboard drawn in-app; single instance + protocol links (\`twitch://\`, \`ttv://\`) |
| flutter_secure_storage | OS keyring (Credential Manager) |
| SharedPreferences | JSON settings file with identical keys and defaults |
| Firebase Crashlytics/Analytics/Performance (optional) | Off by default, same consent rules; optional crash reporting backend behind the \`Telemetry\` trait |
| image_picker | Native file dialog (rfd) |
| wakelock | Power request (decision D9) |
| share_plus | Windows Share UI + copy link (decision D11) |
| Clip download to gallery | "Save as…" dialog |
| APK installer | Velopack installer + updater with SHA-256 (decision D4) |
| Google Cast SDK | rust_cast + mdns-sd (decision D10) |
| AndroidManifest permissions/intents | Windows app manifest, protocol registration, autostart entry |
| assets/ (fonts, icons, celebrations) and lib/l10n ARB files | Reused as-is: Inter fonts, PNG/SVG art, ARB strings compiled into the Rust i18n |

## Files (${sources.length})

| Android file | Spec | PC crate | Proof | Status |
|---|---|---|---|---|
${rows}
## Repo-wide tests (no single source file)\n\n${repoWide.map((x) => '- `' + x + '`').join('\n') || '- none'}\n\n## Known Android defects fixed on PC

Collected verbatim from each area spec.

${defects}`;
fs.writeFileSync(rel('desktop/PARITY.md'), out);
if (missing.length) { console.log(missing.join('\n')); console.log(`PARITY FAILED ${missing.length} files without a spec section`); process.exit(1); }
const credited = new Set([...credit.values()].flat());
if ([...tests].some((x) => !credited.has(x) && !repoWide.includes(x))) { console.log('PARITY FAILED unaccounted tests'); process.exit(1); }
console.log(`PARITY OK ${sources.length} files, ${splits} split rows, ${tests.size} tests (${claimed.size} credited to files, ${repoWide.length} repo-wide)`);
