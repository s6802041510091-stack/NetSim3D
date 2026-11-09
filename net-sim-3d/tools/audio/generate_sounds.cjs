// Generates the game's own sounds (no outside files needed): room ambience,
// computer boot/shutdown, keyboard and mouse clicks, the dialogue typing tick
// and the result jingles. Writes 16-bit mono WAV files to
// net-sim-3d/assets/audio/generated/. Loops carry a "smpl" chunk so Godot
// imports them as looping.
//
//   node net-sim-3d/tools/audio/generate_sounds.cjs
//
// Deterministic: a fixed random seed gives the same files every run.

const fs = require("fs");
const path = require("path");

const RATE = 44100;
const OUT = path.join(__dirname, "..", "..", "assets", "audio", "generated");

// --- helpers ------------------------------------------------------------------

let seed = 12345;
function rand() {
	// mulberry32
	seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
	let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
	t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
	return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
const white = () => rand() * 2 - 1;
const buf = (sec) => new Float32Array(Math.round(sec * RATE));

// RBJ biquad filter, processed in place.
function biquad(x, type, freq, q = 0.707) {
	const w = 2 * Math.PI * freq / RATE, c = Math.cos(w), s = Math.sin(w), a = s / (2 * q);
	let b0, b1, b2, a0, a1, a2;
	if (type === "lp") { b0 = (1 - c) / 2; b1 = 1 - c; b2 = (1 - c) / 2; }
	else if (type === "hp") { b0 = (1 + c) / 2; b1 = -(1 + c); b2 = (1 + c) / 2; }
	else { b0 = a; b1 = 0; b2 = -a; } // band-pass (0 dB peak)
	a0 = 1 + a; a1 = -2 * c; a2 = 1 - a;
	let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
	for (let i = 0; i < x.length; i++) {
		const y = (b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0;
		x2 = x1; x1 = x[i]; y2 = y1; y1 = y; x[i] = y;
	}
	return x;
}

function noise(sec) { const x = buf(sec); for (let i = 0; i < x.length; i++) x[i] = white(); return x; }

// Brown-ish noise: leaky integrated white noise.
function brown(sec) {
	const x = buf(sec); let v = 0;
	for (let i = 0; i < x.length; i++) { v = v * 0.997 + white() * 0.06; x[i] = v; }
	return x;
}

function normalize(x, peak) {
	let m = 0; for (const v of x) m = Math.max(m, Math.abs(v));
	if (m > 0) for (let i = 0; i < x.length; i++) x[i] *= peak / m;
	return x;
}

function mixInto(dst, src, at = 0, gain = 1) {
	const o = Math.round(at * RATE);
	for (let i = 0; i < src.length && o + i < dst.length; i++) if (o + i >= 0) dst[o + i] += src[i] * gain;
	return dst;
}

// Makes a loop seamless: the last `fade` seconds are cross-faded into the
// start and cut off, so sample N-1 flows into sample 0.
function seamless(x, fade) {
	const f = Math.round(fade * RATE), n = x.length - f, out = new Float32Array(n);
	for (let i = 0; i < n; i++) out[i] = x[i];
	for (let i = 0; i < f; i++) { const t = i / f; out[i] = x[i] * t + x[n + i] * (1 - t); }
	return out;
}

function envelope(x, attack, release) {
	const a = Math.max(1, Math.round(attack * RATE)), r = Math.max(1, Math.round(release * RATE));
	for (let i = 0; i < x.length; i++) {
		let g = 1;
		if (i < a) g = i / a;
		const tail = x.length - i;
		if (tail < r) g *= tail / r;
		x[i] *= g;
	}
	return x;
}

// A struck tone: partials [ratio, gain, decay seconds].
function tone(freq, sec, partials) {
	const x = buf(sec);
	for (const [ratio, gain, decay] of partials) {
		const f = freq * ratio;
		for (let i = 0; i < x.length; i++) {
			const t = i / RATE;
			x[i] += Math.sin(2 * Math.PI * f * t) * gain * Math.exp(-t / decay);
		}
	}
	return envelope(x, 0.003, 0.02);
}
const marimba = (f, sec = 0.9) => tone(f, sec, [[1, 1, 0.35], [3.9, 0.35, 0.06], [10, 0.08, 0.015]]);
const bell = (f, sec = 1.2) => tone(f, sec, [[1, 1, 0.5], [2.76, 0.45, 0.25], [5.4, 0.2, 0.1], [8.9, 0.08, 0.05]]);
const note = (name) => {
	const n = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };
	const m = /^([A-G])(b|#)?(\d)$/.exec(name);
	const semis = n[m[1]] + (m[2] === "#" ? 1 : m[2] === "b" ? -1 : 0) + (parseInt(m[3]) + 1) * 12;
	return 440 * Math.pow(2, (semis - 69) / 12);
};

// A short noise click through a band-pass filter.
function click(sec, center, q, decay) {
	const x = noise(sec);
	biquad(x, "bp", center, q);
	for (let i = 0; i < x.length; i++) x[i] *= Math.exp(-(i / RATE) / decay);
	return envelope(x, 0.0005, 0.002);
}

function writeWav(name, x, loop = false, peak = 0.89) {
	normalize(x, peak);
	const n = x.length, dataBytes = n * 2;
	const smpl = loop ? 36 + 24 : 0;
	const b = Buffer.alloc(44 + dataBytes + (smpl ? smpl + 8 : 0));
	let o = 0;
	const str = (s) => { b.write(s, o, "ascii"); o += 4; };
	const u32 = (v) => { b.writeUInt32LE(v >>> 0, o); o += 4; };
	const u16 = (v) => { b.writeUInt16LE(v, o); o += 2; };
	str("RIFF"); u32(b.length - 8); str("WAVE");
	str("fmt "); u32(16); u16(1); u16(1); u32(RATE); u32(RATE * 2); u16(2); u16(16);
	str("data"); u32(dataBytes);
	for (let i = 0; i < n; i++) { b.writeInt16LE(Math.max(-32767, Math.min(32767, Math.round(x[i] * 32767))), o); o += 2; }
	if (smpl) {
		str("smpl"); u32(smpl);
		u32(0); u32(0); u32(Math.round(1e9 / RATE)); u32(60); u32(0); u32(0); u32(0); u32(1); u32(0);
		u32(0); u32(0); u32(0); u32(n - 1); u32(0); u32(0); // loop: id, forward, start, end, fraction, play count
	}
	fs.writeFileSync(path.join(OUT, name + ".wav"), b);
	console.log(name.padEnd(18), (n / RATE).toFixed(2) + " s", loop ? "loop" : "");
}

// --- sounds -------------------------------------------------------------------

fs.mkdirSync(OUT, { recursive: true });

// Outside through the windows: soft wind and distant birds.
{
	const sec = 26, fade = 2;
	const wind = biquad(biquad(brown(sec), "lp", 500), "hp", 60);
	for (let i = 0; i < wind.length; i++) {
		const t = i / RATE;
		wind[i] *= 0.55 + 0.25 * Math.sin(2 * Math.PI * 0.07 * t) + 0.2 * Math.sin(2 * Math.PI * 0.19 * t + 1.3);
	}
	normalize(wind, 0.5);
	const birds = buf(sec);
	let t = 0.6;
	while (t < sec - fade - 1) {
		const base = 2600 + rand() * 1800, count = 2 + Math.floor(rand() * 4);
		for (let k = 0; k < count; k++) {
			const len = 0.05 + rand() * 0.07, x = buf(len);
			const f0 = base * (0.9 + rand() * 0.2), f1 = f0 * (1.15 + rand() * 0.35);
			let ph = 0;
			for (let i = 0; i < x.length; i++) {
				const u = i / x.length, f = f0 + (f1 - f0) * u + 180 * Math.sin(2 * Math.PI * 38 * u * len);
				ph += 2 * Math.PI * f / RATE;
				x[i] = Math.sin(ph) * Math.sin(Math.PI * u);
			}
			mixInto(birds, x, t, 0.5 + rand() * 0.5);
			t += len + 0.04 + rand() * 0.08;
		}
		t += 1.2 + rand() * 3.5;
	}
	biquad(birds, "lp", 6000);
	normalize(birds, 0.22);
	const out = buf(sec);
	mixInto(out, wind); mixInto(out, birds);
	writeWav("amb_outdoor", seamless(out, fade), true, 0.6);
}

// Air conditioner: steady airy hiss with a faint mains hum.
{
	const sec = 12, fade = 1.5;
	const air = biquad(biquad(noise(sec), "lp", 1400), "hp", 120);
	const low = biquad(brown(sec), "lp", 180);
	normalize(air, 0.5); normalize(low, 0.4);
	const out = buf(sec);
	mixInto(out, air); mixInto(out, low);
	for (let i = 0; i < out.length; i++) {
		const tt = i / RATE;
		out[i] += 0.03 * Math.sin(2 * Math.PI * 100 * tt) + 0.015 * Math.sin(2 * Math.PI * 200 * tt);
	}
	writeWav("amb_aircon", seamless(out, fade), true, 0.6);
}

// Many computers running: fan whoosh with a little blade tone.
{
	const sec = 12, fade = 1.5;
	const out = biquad(biquad(noise(sec), "bp", 900, 0.5), "lp", 3500);
	normalize(out, 0.5);
	for (let i = 0; i < out.length; i++) {
		const tt = i / RATE, wob = 1 + 0.004 * Math.sin(2 * Math.PI * 0.3 * tt);
		out[i] += 0.025 * Math.sin(2 * Math.PI * 140 * wob * tt) + 0.012 * Math.sin(2 * Math.PI * 280 * wob * tt);
	}
	writeWav("amb_pc_fans", seamless(out, fade), true, 0.6);
}

// Computer power on: fan spins up, a drive clicks, then a start-up chime.
{
	const sec = 2.8, out = buf(sec);
	const fan = noise(sec);
	biquad(fan, "bp", 700, 0.6);
	for (let i = 0; i < fan.length; i++) {
		const tt = i / RATE;
		fan[i] *= Math.min(1, tt / 1.0) * (tt > 2.3 ? Math.max(0, 1 - (tt - 2.3) / 0.5) * 0.6 + 0.4 : 1) * 0.25;
	}
	mixInto(out, fan);
	for (const at of [0.35, 0.5, 0.62, 0.9]) mixInto(out, click(0.03, 2200, 2, 0.006), at, 0.5);
	mixInto(out, bell(note("E5"), 1.2), 1.25, 0.6);
	mixInto(out, bell(note("B5"), 1.2), 1.45, 0.5);
	writeWav("pc_boot", envelope(out, 0.01, 0.2));
}

// Computer power off: falling chime and the fan winding down.
{
	const sec = 1.6, out = buf(sec);
	mixInto(out, bell(note("B5"), 0.8), 0, 0.5);
	mixInto(out, bell(note("E5"), 1.0), 0.18, 0.55);
	const fan = noise(sec);
	biquad(fan, "bp", 600, 0.6);
	for (let i = 0; i < fan.length; i++) fan[i] *= 0.2 * Math.max(0, 1 - i / fan.length);
	mixInto(out, fan);
	writeWav("pc_off", envelope(out, 0.005, 0.2));
}

// Dialogue typing: a very soft tick (pitch is varied in the game).
writeWav("type_tick", (() => {
	const x = click(0.035, 2400, 1.5, 0.007);
	mixInto(x, tone(1500, 0.035, [[1, 0.25, 0.008]]));
	return x;
})(), false, 0.5);

// Keyboard key: a light click then the key bottoming out.
writeWav("key_tap", (() => {
	const x = buf(0.07);
	mixInto(x, click(0.02, 3200, 1.8, 0.004), 0, 0.8);
	mixInto(x, click(0.05, 900, 1.2, 0.012), 0.008, 1.0);
	return x;
})(), false, 0.8);

// Mouse button.
writeWav("mouse_click", (() => {
	const x = click(0.03, 4200, 2.5, 0.003);
	mixInto(x, tone(2100, 0.03, [[1, 0.3, 0.006]]));
	return x;
})(), false, 0.7);

// Opening an install point: a soft, rounded "pop" — low notes, slow attack
// and nothing above ~2.5 kHz, so it never sounds sharp.
writeWav("popup_soft", (() => {
	const out = buf(0.45);
	const soft = (f, len) => envelope(tone(f, len, [[1, 1, 0.13], [2, 0.12, 0.05]]), 0.012, 0.05);
	mixInto(out, soft(note("G4"), 0.32), 0, 0.8);
	mixInto(out, soft(note("C5"), 0.38), 0.06, 0.7);
	return biquad(out, "lp", 2500);
})(), false, 0.55);

// Result jingles.
{
	const out = buf(1.9);
	["C5", "E5", "G5"].forEach((n, i) => mixInto(out, marimba(note(n), 0.8), i * 0.11, 0.8));
	for (const n of ["C6", "E5", "G5"]) mixInto(out, marimba(note(n), 1.5), 0.36, n === "C6" ? 0.9 : 0.45);
	writeWav("jingle_pass", out);
}
{
	const out = buf(1.6);
	["G4", "Eb4", "C4"].forEach((n, i) => mixInto(out, marimba(note(n), 1.0), i * 0.22, i === 2 ? 0.9 : 0.75));
	writeWav("jingle_fail", out, false, 0.7);
}
writeWav("star", bell(note("E6"), 0.9), false, 0.7);
