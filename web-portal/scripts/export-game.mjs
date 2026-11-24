// Exports the NetSim3D game for the web into web-portal/game-build/ and pre-compresses
// the big files so nginx can send them gzipped without compressing on every download.
//
//   node scripts/export-game.mjs            (Godot on PATH as "godot")
//   GODOT="C:\path\to\godot.exe" node scripts/export-game.mjs
import { spawnSync } from 'node:child_process';
import { createReadStream, createWriteStream, existsSync, mkdirSync, readdirSync, rmSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { pipeline } from 'node:stream/promises';
import { fileURLToPath } from 'node:url';
import { createGzip, constants } from 'node:zlib';

const here = dirname(fileURLToPath(import.meta.url));
const project = resolve(here, '..', '..', 'net-sim-3d');
const out = resolve(here, '..', 'game-build');
const godot = process.env.GODOT || 'godot';

if (!existsSync(join(project, 'project.godot'))) throw new Error(`Godot project not found at ${project}`);

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });

console.log(`Exporting ${project} -> ${out} (preset "Web") ...`);
const run = spawnSync(godot, ['--headless', '--path', project, '--export-release', 'Web', join(out, 'index.html')], {
  stdio: 'inherit',
});
if (run.status !== 0 || !existsSync(join(out, 'index.pck'))) {
  console.error('Godot export failed. Is Godot 4.7 with the Web export templates installed? Set GODOT to its path if needed.');
  process.exit(1);
}

const mb = (n) => `${(n / 1024 / 1024).toFixed(1)} MB`;
for (const file of readdirSync(out)) {
  if (!/\.(wasm|pck|js)$/.test(file)) continue;
  const src = join(out, file);
  await pipeline(createReadStream(src), createGzip({ level: constants.Z_BEST_COMPRESSION }), createWriteStream(`${src}.gz`));
  console.log(`${file}: ${mb(statSync(src).size)} -> ${mb(statSync(`${src}.gz`).size)} gzipped`);
}
console.log('Done. Start or refresh the site with:  docker compose up -d --build');
