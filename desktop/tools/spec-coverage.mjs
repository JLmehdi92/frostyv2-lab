import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const opt = (k) => { const i = args.indexOf(k); return i < 0 ? null : args[i + 1]; };
const root = path.resolve(opt('--root') ?? path.join(path.dirname(new URL(import.meta.url).pathname), '..', '..'));
const specs = (opt('--spec') ?? '').split(',').filter(Boolean).map((s) => path.resolve(s));
const prefixes = (opt('--paths') ?? '').split(',').filter(Boolean);
const exclude = (opt('--exclude') ?? '').split(',').filter(Boolean);
if (!specs.length || !prefixes.length) { console.error('usage: --spec a.md[,b.md] --paths lib/x,test/x,android/... [--exclude p1,p2]'); process.exit(2); }

const generated = (f) => /\.(g|freezed|mocks)\.dart$/.test(f) || /lib\/l10n\/app_localizations.*\.dart$/.test(f);
const exts = ['.dart', '.kt', '.swift'];
const walk = (p) => {
  const abs = path.join(root, p);
  if (!fs.existsSync(abs)) return [];
  if (fs.statSync(abs).isFile()) return [p];
  return fs.readdirSync(abs).flatMap((n) => walk(path.posix.join(p, n)));
};
const targets = [...new Set(prefixes.flatMap(walk))]
  .filter((f) => exts.includes(path.extname(f)) && !generated(f) && !exclude.some((e) => f === e || f.startsWith(e + '/')))
  .sort();
if (!targets.length) { console.error('no target files found'); process.exit(1); }

const text = specs.map((s) => fs.existsSync(s) ? fs.readFileSync(s, 'utf8') : '').join('\n');
const lines = text.split('\n');
const sections = new Map();
for (let i = 0; i < lines.length; i++) {
  const m = lines[i].match(/^###\s+`?([^`\s]+)`?\s*$/);
  if (!m) continue;
  let j = i + 1; let body = '';
  while (j < lines.length && !/^#{1,3}\s/.test(lines[j])) { body += lines[j] + '\n'; j++; }
  sections.set(m[1], (sections.get(m[1]) ?? 0) + body.replace(/\s+/g, ' ').trim().length);
}

const problems = [];
for (const f of targets) {
  const isTest = f.startsWith('test/');
  if (isTest) { if (!text.includes(f)) problems.push(`missing test reference: ${f}`); continue; }
  const loc = fs.readFileSync(path.join(root, f), 'utf8').split('\n').length;
  const need = Math.max(120, Math.min(4000, loc * 3));
  const got = sections.get(f);
  if (got === undefined) problems.push(`missing section: ### ${f}`);
  else if (got < need) problems.push(`thin section (${got}/${need} chars): ${f}`);
}
if (problems.length) {
  console.log(problems.slice(0, 200).join('\n'));
  console.log(`SPEC COVERAGE FAILED ${problems.length}/${targets.length}`);
  process.exit(1);
}
console.log(`SPEC COVERAGE OK ${targets.length} files`);
