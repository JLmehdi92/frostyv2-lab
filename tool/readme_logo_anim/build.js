const fs = require('fs');
const [tpl, icon, out] = process.argv.slice(2);
fs.writeFileSync(out, fs.readFileSync(tpl, 'utf8').replace('__ICON__', fs.readFileSync(icon, 'utf8')));
