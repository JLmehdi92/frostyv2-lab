import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const opt = (k) => { const i = args.indexOf(k); return i < 0 ? null : args[i + 1]; };
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', '..');
const spec = opt('--spec');
const prefixes = (opt('--paths') ?? '').split(',').filter(Boolean);
const exclude = (opt('--exclude') ?? '').split(',').filter(Boolean);
if (!spec || !prefixes.length) { console.error('usage: --spec a.md --paths lib/x[,lib/y] [--exclude ...]'); process.exit(2); }

const arb = (f) => JSON.parse(fs.readFileSync(path.join(root, 'lib/l10n', f), 'utf8'));
const en = arb('app_en.arb'); const fr = arb('app_fr.arb');
const walk = (p) => {
  const abs = path.join(root, p);
  if (!fs.existsSync(abs)) return [];
  if (fs.statSync(abs).isFile()) return [p];
  return fs.readdirSync(abs).flatMap((n) => walk(path.posix.join(p, n)));
};
const files = [...new Set(prefixes.flatMap(walk))].filter((f) => f.endsWith('.dart') && !/\.g\.dart$/.test(f) && f.startsWith('lib/') && !exclude.some((e) => f.startsWith(e + '/') || f === e));
const used = new Set();
for (const f of files) {
  const src = fs.readFileSync(path.join(root, f), 'utf8');
  for (const m of src.matchAll(/\b(?:l10n|L10n\.current|l)\s*\.\s*([a-z][A-Za-z0-9]*)/g)) if (typeof en[m[1]] === 'string') used.add(m[1]);
}
if (!used.size) { console.error('no ARB keys found in area'); process.exit(1); }
if (args.includes('--emit')) {
  const esc = (s) => String(s ?? '').replace(/\|/g, '\\|').replace(/\n/g, '\\n');
  console.log('| Key | EN | FR |\n|---|---|---|');
  for (const k of [...used].sort()) console.log(`| \`${k}\` | ${esc(en[k])} | ${esc(fr[k])} |`);
  process.exit(0);
}
const text = fs.readFileSync(spec, 'utf8').replace(/\\\|/g, '|');
const probe = (s) => {
  const parts = s.split(/\{[^}]*\}/).map((p) => p.trim()).filter((p) => p.length >= 3).sort((a, b) => b.length - a.length);
  return parts.length ? parts[0].slice(0, 24) : null;
};
const problems = [];
for (const k of [...used].sort()) {
  if (!new RegExp(`\\b${k}\\b`).test(text)) { problems.push(`missing key: ${k}`); continue; }
  for (const [lang, table] of [['EN', en], ['FR', fr]]) {
    const p = probe(table[k] ?? '');
    if (p && !text.includes(p)) problems.push(`missing ${lang} text for ${k}: "${p}"`);
  }
}
if (problems.length) { console.log(problems.slice(0, 300).join('\n')); console.log(`SPEC STRINGS FAILED ${problems.length} (${used.size} keys used)`); process.exit(1); }
console.log(`SPEC STRINGS OK ${used.size} keys`);
