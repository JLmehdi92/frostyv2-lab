import fs from 'node:fs';

const files = process.argv.slice(2);
const required = [
  '## Purpose',
  '## Screens and layouts',
  '## Behaviour and state',
  '## Animations and motion',
  '## Settings',
  '## Strings',
  '## Network and data',
  '## Tested behaviour',
  '## Wide and tablet layout',
  '## PC equivalent',
];
if (!files.length) { console.error('usage: spec-sections.mjs <spec.md>...'); process.exit(2); }
const problems = [];
for (const f of files) {
  if (!fs.existsSync(f)) { problems.push(`${f}: missing file`); continue; }
  const t = fs.readFileSync(f, 'utf8');
  for (const h of required) {
    const i = t.indexOf(`\n${h}\n`);
    if (i < 0) { problems.push(`${f}: missing "${h}"`); continue; }
    const rest = t.slice(i + h.length + 2);
    const next = rest.search(/\n## /);
    const body = (next < 0 ? rest : rest.slice(0, next)).replace(/\s+/g, ' ').trim();
    if (body.length < 80) problems.push(`${f}: "${h}" too thin (${body.length} chars)`);
  }
}
if (problems.length) { console.log(problems.join('\n')); console.log(`SPEC SECTIONS FAILED ${problems.length}`); process.exit(1); }
console.log(`SPEC SECTIONS OK ${files.length} files`);
