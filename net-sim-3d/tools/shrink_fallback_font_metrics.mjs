// Lowers the line metrics (ascent/descent) of a WOFF2 font so it can be a glyph
// fallback without making lines taller.
//
// Godot's Font.get_height() takes the largest ascent and descent over a font AND
// all of its fallbacks, so a symbol font with tall metrics (the Noto symbol fonts)
// would make every Mitr/Sarabun line taller, even lines with no symbols in them.
// This rewrites hhea and OS/2 (typo + win) to ascent 0.9 em / descent 0.2 em, which
// is below both Mitr (1.15 / 0.42) and Sarabun (1.068 / 0.232). Glyph outlines are
// untouched; a symbol taller than the new ascent still draws in full.
//
//   node tools/shrink_fallback_font_metrics.mjs <in.woff2> <out.woff2>
//
// Only plain (non-collection) WOFF2 files without metadata/private blocks are
// handled. hhea and OS/2 are never transformed in WOFF2, so only the Brotli
// stream changes; the table directory stays as it was.
import { readFileSync, writeFileSync } from 'node:fs';
import { brotliCompressSync, brotliDecompressSync, constants } from 'node:zlib';

const ASCENT_EM = 0.9;
const DESCENT_EM = 0.2;

const KNOWN_TAGS = ['cmap', 'head', 'hhea', 'hmtx', 'maxp', 'name', 'OS/2', 'post', 'cvt ', 'fpgm', 'glyf', 'loca', 'prep', 'CFF ', 'VORG', 'EBDT', 'EBLC', 'gasp', 'hdmx', 'kern', 'LTSH', 'PCLT', 'VDMX', 'vhea', 'vmtx', 'BASE', 'GDEF', 'GPOS', 'GSUB', 'EBSC', 'JSTF', 'MATH', 'CBDT', 'CBLC', 'COLR', 'CPAL', 'SVG ', 'sbix', 'acnt', 'avar', 'bdat', 'bloc', 'bsln', 'cvar', 'fdsc', 'feat', 'fmtx', 'fvar', 'gvar', 'hsty', 'just', 'lcar', 'mort', 'morx', 'opbd', 'prop', 'trak', 'Zapf', 'Silf', 'Glat', 'Gloc', 'Feat', 'Sill'];

const [input, output] = process.argv.slice(2);
if (!input || !output) {
  console.error('usage: node tools/shrink_fallback_font_metrics.mjs <in.woff2> <out.woff2>');
  process.exit(2);
}

const src = readFileSync(input);
if (src.toString('latin1', 0, 4) !== 'wOF2') throw new Error(`${input} is not WOFF2`);
if (src.toString('latin1', 4, 8) === 'ttcf') throw new Error('font collections are not supported');
const numTables = src.readUInt16BE(12);
const compressedSize = src.readUInt32BE(20);
if (src.readUInt32BE(28) || src.readUInt32BE(40)) throw new Error('metadata/private blocks are not supported');

// Table directory: find where each table sits in the decompressed stream.
let pos = 48;
const readBase128 = () => {
  let value = 0;
  for (let i = 0; i < 5; i++) {
    const byte = src[pos++];
    value = value * 128 + (byte & 0x7f);
    if (!(byte & 0x80)) return value;
  }
  throw new Error('bad UIntBase128');
};
const tables = {};
let offset = 0;
for (let i = 0; i < numTables; i++) {
  const flags = src[pos++];
  let tag;
  if ((flags & 0x3f) === 0x3f) {
    tag = src.toString('latin1', pos, pos + 4);
    pos += 4;
  } else {
    tag = KNOWN_TAGS[flags & 0x3f];
  }
  const version = flags >> 6;
  let length = readBase128();
  const transformed = tag === 'glyf' || tag === 'loca' ? version === 0 : version !== 0;
  if (transformed) length = readBase128();
  tables[tag] = { offset, length };
  offset += length;
}
const streamStart = pos;
const stream = brotliDecompressSync(src.subarray(streamStart, streamStart + compressedSize));
if (stream.length !== offset) throw new Error(`stream is ${stream.length} bytes, directory says ${offset}`);

for (const tag of ['head', 'hhea', 'OS/2']) if (!tables[tag]) throw new Error(`no ${tag} table`);
const at = (tag, field) => tables[tag].offset + field;
const upm = stream.readUInt16BE(at('head', 18));
const ascent = Math.round(ASCENT_EM * upm);
const descent = Math.round(DESCENT_EM * upm);
const before = `hhea ${stream.readInt16BE(at('hhea', 4))}/${stream.readInt16BE(at('hhea', 6))}, win ${stream.readUInt16BE(at('OS/2', 74))}/${stream.readUInt16BE(at('OS/2', 76))}`;

stream.writeInt16BE(ascent, at('hhea', 4)); // ascender
stream.writeInt16BE(-descent, at('hhea', 6)); // descender
stream.writeInt16BE(0, at('hhea', 8)); // lineGap
stream.writeInt16BE(ascent, at('OS/2', 68)); // sTypoAscender
stream.writeInt16BE(-descent, at('OS/2', 70)); // sTypoDescender
stream.writeInt16BE(0, at('OS/2', 72)); // sTypoLineGap
stream.writeUInt16BE(ascent, at('OS/2', 74)); // usWinAscent
stream.writeUInt16BE(descent, at('OS/2', 76)); // usWinDescent

const packed = brotliCompressSync(stream, {
  params: {
    [constants.BROTLI_PARAM_MODE]: constants.BROTLI_MODE_FONT,
    [constants.BROTLI_PARAM_QUALITY]: 11,
    [constants.BROTLI_PARAM_SIZE_HINT]: stream.length,
  },
});
const header = Buffer.from(src.subarray(0, streamStart));
const padding = (4 - ((streamStart + packed.length) % 4)) % 4;
const out = Buffer.concat([header, packed, Buffer.alloc(padding)]);
out.writeUInt32BE(out.length, 8); // length
out.writeUInt32BE(packed.length, 20); // totalCompressedSize
writeFileSync(output, out);
console.log(`${output}: upm ${upm}, ${before} -> ascent ${ascent} / descent ${descent}, ${src.length} -> ${out.length} bytes`);
