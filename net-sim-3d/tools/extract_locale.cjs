const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const entries = new Map();
function walk(dir) {
  for (const entry of fs.readdirSync(dir, {withFileTypes:true})) {
    if (entry.name.startsWith('.') || entry.name === 'tools' || entry.name === 'assets') continue;
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) {walk(file); continue;}
    if (!/\.(gd|tres|tscn|json)$/.test(file)) continue;
    const text = fs.readFileSync(file, 'utf8');
    const pattern = /#[^\n]*|"((?:\\.|[^"\\])*)"|'((?:\\.|[^'\\])*)'/g;
    for (const match of text.matchAll(pattern)) {
      if (match[0].startsWith('#')) continue;
      const raw = match[1] ?? match[2];
      if (!/[ก-๙]/.test(raw)) continue;
      const value = raw.replace(/\\n/g,'\n').replace(/\\t/g,'\t').replace(/\\"/g,'"').replace(/\\'/g,"'").replace(/\\\\/g,'\\');
      if (!entries.has(value)) entries.set(value, path.relative(root,file).replaceAll('\\','/'));
    }
  }
}
walk(root);
const out = [...entries].map(([th,source],i)=>({id:i,th,source}));
fs.writeFileSync(path.join(root,'tools','locale-source.json'),JSON.stringify(out,null,2));
console.log(JSON.stringify({count:out.length,chars:out.reduce((n,x)=>n+x.th.length,0)}));
