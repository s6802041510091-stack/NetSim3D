// Phase B / R3: make every character and hand GLB use ONE copy of the shared
// MakeHuman textures (skin, eyes, eyebrows, shirt, shoes) instead of embedding
// the same 2048px PNG eight times.
//
// Run from the repository root:  node net-sim-3d/tools/share_character_textures.cjs
//
// For each GLB, embedded images whose name matches a shared texture are
// written once to assets/models/shared_textures/ (if not there yet) and
// replaced by an external "uri"; the binary chunk is then compacted. Godot's
// glTF importer resolves the uri to the same res:// texture, so the export
// carries one texture instead of one per model. Re-run after re-exporting any
// of these GLBs from Blender (the exporters embed the images again).
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const MODELS = path.join(__dirname, '..', 'assets', 'models');
const SHARED_DIR = path.join(MODELS, 'shared_textures');
const SHARED = {
  young_lightskinned_male_diffuse3: 'skin_young_lightskinned_male_diffuse3.png',
  short04_diffuse: 'shirt_short04_diffuse.png',
  shoes04_diffuse: 'shoes04_diffuse.png',
  shoes04_normal: 'shoes04_normal.png',
  brown_eye: 'eye_brown.png',
  eyebrow001: 'eyebrow001.png',
};
const GLBS = [
  'it_support_male_180cm.glb',
  'it_support_supervisor_male_170cm.glb',
  'teacher_male_khaki_180cm.glb',
  'player_right_arm.glb',
  'player_right_arm_relaxed.glb',
  'tools/hand_cable_stripper.glb',
  'tools/hand_cable_tester.glb',
  'tools/hand_crimping_tool.glb',
];

const align4 = (n) => (n + 3) & ~3;

function readGlb(file) {
  const buf = fs.readFileSync(file);
  if (buf.readUInt32LE(0) !== 0x46546c67) throw new Error(`${file} is not a GLB`);
  const jsonLen = buf.readUInt32LE(12);
  const json = JSON.parse(buf.slice(20, 20 + jsonLen).toString('utf8'));
  const binHeader = 20 + jsonLen;
  const bin = binHeader < buf.length ? buf.slice(binHeader + 8, binHeader + 8 + buf.readUInt32LE(binHeader)) : Buffer.alloc(0);
  return { json, bin };
}

function writeGlb(file, json, bin) {
  let jsonBuf = Buffer.from(JSON.stringify(json), 'utf8');
  jsonBuf = Buffer.concat([jsonBuf, Buffer.alloc(align4(jsonBuf.length) - jsonBuf.length, 0x20)]);
  const binPadded = Buffer.concat([bin, Buffer.alloc(align4(bin.length) - bin.length)]);
  const header = Buffer.alloc(12);
  header.writeUInt32LE(0x46546c67, 0);
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(12 + 8 + jsonBuf.length + 8 + binPadded.length, 8);
  const jsonHead = Buffer.alloc(8); jsonHead.writeUInt32LE(jsonBuf.length, 0); jsonHead.writeUInt32LE(0x4e4f534a, 4);
  const binHead = Buffer.alloc(8); binHead.writeUInt32LE(binPadded.length, 0); binHead.writeUInt32LE(0x004e4942, 4);
  fs.writeFileSync(file, Buffer.concat([header, jsonHead, jsonBuf, binHead, binPadded]));
}

/** Drop unused bufferViews and rebuild the binary chunk without their bytes. */
function compact(json, bin) {
  const used = new Set();
  (json.accessors || []).forEach((a) => a.bufferView !== undefined && used.add(a.bufferView));
  (json.images || []).forEach((i) => i.bufferView !== undefined && used.add(i.bufferView));
  const remap = new Map();
  const parts = [];
  let offset = 0;
  (json.bufferViews || []).forEach((view, index) => {
    if (!used.has(index)) return;
    const bytes = bin.slice(view.byteOffset || 0, (view.byteOffset || 0) + view.byteLength);
    const pad = align4(offset) - offset;
    if (pad) parts.push(Buffer.alloc(pad));
    offset += pad;
    remap.set(index, { ...view, byteOffset: offset });
    parts.push(bytes);
    offset += bytes.length;
  });
  const order = [...remap.keys()];
  json.bufferViews = order.map((i) => remap.get(i));
  const newIndex = new Map(order.map((oldIndex, i) => [oldIndex, i]));
  (json.accessors || []).forEach((a) => { if (a.bufferView !== undefined) a.bufferView = newIndex.get(a.bufferView); });
  (json.images || []).forEach((i) => { if (i.bufferView !== undefined) i.bufferView = newIndex.get(i.bufferView); });
  const newBin = Buffer.concat(parts);
  json.buffers = [{ byteLength: newBin.length }];
  return newBin;
}

fs.mkdirSync(SHARED_DIR, { recursive: true });
const hashes = {};
for (const rel of GLBS) {
  const file = path.join(MODELS, rel);
  const before = fs.statSync(file).size;
  const { json, bin } = readGlb(file);
  let replaced = 0;
  for (const image of json.images || []) {
    const sharedName = SHARED[image.name];
    if (!sharedName || image.bufferView === undefined) continue;
    const view = json.bufferViews[image.bufferView];
    const bytes = bin.slice(view.byteOffset || 0, (view.byteOffset || 0) + view.byteLength);
    const hash = crypto.createHash('sha256').update(bytes).digest('hex');
    const target = path.join(SHARED_DIR, sharedName);
    if (!fs.existsSync(target)) fs.writeFileSync(target, bytes);
    // Refuse to share images that only happen to have the same name.
    hashes[sharedName] = hashes[sharedName] || crypto.createHash('sha256').update(fs.readFileSync(target)).digest('hex');
    if (hashes[sharedName] !== hash) throw new Error(`${rel}: ${image.name} differs from shared ${sharedName}`);
    delete image.bufferView;
    delete image.mimeType;
    image.uri = path.relative(path.dirname(file), target).split(path.sep).join('/');
    replaced++;
  }
  if (!replaced) { console.log(`skip ${rel} (already shared)`); continue; }
  const newBin = compact(json, bin);
  writeGlb(file, json, newBin);
  console.log(`${rel}: ${replaced} images -> shared, ${(before / 1048576).toFixed(2)} MB -> ${(fs.statSync(file).size / 1048576).toFixed(2)} MB`);
}
