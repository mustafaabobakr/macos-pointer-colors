#!/usr/bin/env node
// Composes the promo soundtrack and sound effects from scratch (no samples, no packages) and
// writes promo/out/music.wav. 120 BPM, so a beat is 0.5 s and a bar is 2 s, the same grid as
// the video's timeline in index.html: cuts, clicks and colour changes land on beats.
//
//   node promo/music.mjs [--out file.wav]
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = resolve(process.argv.includes("--out") ? process.argv[process.argv.indexOf("--out") + 1] : join(HERE, "out", "music.wav"));
const SR = 48000, DUR = 30, N = SR * DUR, BEAT = 0.5, BAR = 2;
const L = new Float32Array(N), R = new Float32Array(N), SEND = new Float32Array(N);   // SEND feeds the reverb

// ---------- tiny DSP kit
let seed = 1;
const noise = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 2147483648 - 1; };
const midi = m => 440 * Math.pow(2, (m - 69) / 12);
const osc = {
  sine: p => Math.sin(2 * Math.PI * p),
  saw: p => 2 * (p - Math.floor(p + .5)),
  square: p => (p % 1 < .5 ? 1 : -1),
  tri: p => 1 - 4 * Math.abs((p % 1) - .5),
};
function put(i, v, pan = 0, send = 0) {
  if (i < 0 || i >= N) return;
  L[i] += v * Math.cos((pan + 1) * Math.PI / 4) * Math.SQRT2;
  R[i] += v * Math.sin((pan + 1) * Math.PI / 4) * Math.SQRT2;
  SEND[i] += v * send;
}
/** A note with an AD envelope and a one-pole low-pass. */
function tone(t0, dur, freq, { type = "saw", amp = .2, attack = .005, decay = dur, pan = 0, send = .15, cutoff = 4000, detune = 0, sweep = 0, sidechain = false } = {}) {
  const start = Math.floor(t0 * SR), len = Math.floor((dur + .05) * SR);
  let lp = 0, phase = Math.random();
  for (let n = 0; n < len; n++) {
    const t = n / SR, f = freq * (1 + detune) * (1 + sweep * t);
    phase += f / SR;
    const env = Math.min(1, t / attack) * Math.exp(-t / Math.max(decay, .001) * 3) * (t > dur ? Math.max(0, 1 - (t - dur) / .05) : 1);
    const a = 1 - Math.exp(-2 * Math.PI * cutoff / SR);
    lp += a * (osc[type](phase) - lp);
    put(start + n, lp * env * amp * (sidechain ? duck(t0 + t) : 1), pan, send);
  }
}
/** Kick ducking: everything with sidechain dips on each beat during the groove. */
function duck(t) {
  if (t < 5 || t >= 24) return 1;
  const k = ((t - 5) % BEAT) / BEAT;
  return .35 + .65 * Math.min(1, k * 2.6);
}
function kick(t0, amp = .9) {
  const s = Math.floor(t0 * SR);
  let phase = 0;
  for (let n = 0; n < SR * .45; n++) {
    const t = n / SR, f = 45 + 95 * Math.exp(-t * 28);
    phase += f / SR;
    put(s + n, Math.sin(2 * Math.PI * phase) * Math.exp(-t * 7.5) * amp + (n < 90 ? noise() * .25 * (1 - n / 90) : 0));
  }
}
/** Filtered noise: hp/bp shaped by a moving centre frequency. */
function noiseHit(t0, dur, { amp = .2, from = 6000, to = from, q = .7, pan = 0, send = .2, shape = "decay", decay = dur } = {}) {
  const s = Math.floor(t0 * SR), len = Math.floor(dur * SR);
  let low = 0, band = 0;
  for (let n = 0; n < len; n++) {
    const t = n / SR, x = n / len;
    const fc = from * Math.pow(to / from, x), f = 2 * Math.sin(Math.PI * Math.min(fc, SR / 6) / SR);
    const input = noise();
    low += f * band; const high = input - low - q * band; band += f * high;
    const env = shape === "swell" ? Math.sin(Math.PI * x) ** 2 : shape === "rise" ? x ** 2.2 : Math.exp(-t / Math.max(decay, .001) * 4);
    put(s + n, band * env * amp, pan, send);
  }
}
const hat = (t, amp = .06, open = false) => noiseHit(t, open ? .22 : .05, { amp, from: 9000, q: .3, pan: .25, send: .05, decay: open ? .2 : .04 });
const clap = t => { for (const d of [0, .011, .022]) noiseHit(t + d, .16, { amp: .22, from: 1600, q: .5, send: .35, decay: .12 }); };
const click = t => { tone(t, .006, 3200, { type: "sine", amp: .25, decay: .006, send: .05, pan: .2 }); tone(t + .004, .03, 900, { type: "tri", amp: .18, decay: .03, send: .05, pan: .2 }); };

// ---------- the score
const CHORDS = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]];   // Am F C G
const chordAt = t => CHORDS[Math.floor(Math.max(0, t - 5) / BAR) % 4];

// Intro, the problem (0–4.8): a low Am pad that slowly opens, a clock-like tick, a heartbeat.
for (const m of [45, 57, 60, 64]) tone(0, 4.75, midi(m), { type: "saw", amp: .055, attack: 1.2, decay: 30, cutoff: 700, detune: (m % 3) * .002, send: .5, pan: (m % 2 ? -.4 : .4) });
for (let t = 0; t < 4.75; t += .25) hat(t, t % BEAT === 0 ? .035 : .018);
for (let t = 0; t < 4.6; t += BEAT) tone(t, .18, 55, { type: "sine", amp: .22, decay: .16, send: .05 });

// Groove (5–24): kick, clap, hats, bass, ducked pad, then an arpeggio.
for (let t = 5; t < 24 - 1e-9; t += BEAT) {
  kick(t);
  const beat = Math.round((t - 5) / BEAT);
  if (beat % 2 === 1) clap(t);
  hat(t + .25, beat % 4 === 3 ? .07 : .05, beat % 4 === 3);
}
for (let bar = 0; bar < 9.5; bar++) {
  const t = 5 + bar * BAR, ch = CHORDS[bar % 4];
  for (let i = 0; i < 8; i++) {                   // 8th-note bass, root and octave
    const bt = t + i * .25;
    if (bt >= 24) break;
    tone(bt, .22, midi(ch[0] - 24 + (i % 4 === 3 ? 12 : 0)), { type: "saw", amp: .16, decay: .2, cutoff: 520, send: .02, sidechain: true });
    tone(bt, .22, midi(ch[0] - 24), { type: "sine", amp: .14, decay: .2, send: 0, sidechain: true });
  }
  for (const m of ch) for (const d of [-.003, .003]) tone(t, Math.min(BAR, 24 - t), midi(m), { type: "saw", amp: .03, attack: .05, decay: 6, cutoff: 1800, detune: d, send: .45, pan: d > 0 ? .5 : -.5, sidechain: true });
}
for (let t = 7; t < 24 - 1e-9; t += .125) {       // 16th-note arpeggio from the first colour change
  const ch = chordAt(t), i = Math.round((t - 7) / .125);
  const note = ch[[0, 1, 2, 1][i % 4]] + 12 + (t >= 16 && i % 8 >= 4 ? 12 : 0);
  tone(t, .1, midi(note), { type: "square", amp: t >= 16 ? .045 : .035, decay: .09, cutoff: t >= 16 ? 3800 : 2400, send: .35, pan: Math.sin(i * .7) * .5, sidechain: true });
}
for (let t = 16; t < 23.5; t += .25) noiseHit(t, .06, { amp: .03, from: 5000, q: .5, pan: -.35, send: .1, decay: .05 });   // shaker in the features
for (let i = 0; i < 8; i++) noiseHit(23.5 + i * .0625, .07, { amp: .06 + i * .02, from: 1800, q: .5, send: .3, decay: .06 });  // fill

// End (24–30): a long Am(add9) chord with a bell on top.
for (const m of [45, 57, 60, 64, 71]) tone(24, 5.6, midi(m), { type: "saw", amp: .05, attack: .02, decay: 9, cutoff: 1600, send: .7, pan: (m % 2 ? -.4 : .4) });
[81, 76, 72, 69].forEach((m, i) => tone(24 + i * .25, 2.5, midi(m), { type: "sine", amp: .07, decay: 2.2, send: .8, pan: (i - 1.5) * .4 }));

// ---------- sound effects, matched to the picture: only clicks and the size slider
[6.0, 7.0, 8.0, 10.0].forEach(click);

// The slider drags from 1× to 2.4× between 8.0 s and 9.0 s with the video's in-out cubic easing.
// One soft tick per 0.1× step, so the ticks speed up and slow down with the thumb.
const easeInOut = x => (x < .5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2);
const sliderTick = t => tone(t, .012, 2600, { type: "sine", amp: .07, decay: .012, send: .02, pan: .25 });
for (let n = 0, last = 10; n <= 1000; n++) {
  const t = 8.0 + n / 1000, step = Math.floor((1 + 1.4 * easeInOut(n / 1000)) * 10 + 1e-9);
  if (step !== last) { sliderTick(t); last = step; }
}

// ---------- reverb (Schroeder: four combs into two all-passes) and master
function reverb(input) {
  const combs = [1557, 1617, 1491, 1422].map(d => ({ buf: new Float32Array(d), i: 0, fb: .8, damp: 0 }));
  const aps = [225, 556].map(d => ({ buf: new Float32Array(d), i: 0 }));
  const out = new Float32Array(N);
  for (let n = 0; n < N; n++) {
    let acc = 0;
    for (const c of combs) { const y = c.buf[c.i]; c.damp = y * .7 + c.damp * .3; c.buf[c.i] = input[n] + c.damp * c.fb; c.i = (c.i + 1) % c.buf.length; acc += y; }
    for (const a of aps) { const y = a.buf[a.i]; a.buf[a.i] = acc + y * .5; acc = y - acc * .5; a.i = (a.i + 1) % a.buf.length; }
    out[n] = acc * .25;
  }
  return out;
}
const wet = reverb(SEND);
let peak = 0;
for (let n = 0; n < N; n++) {
  const t = n / SR, fade = Math.min(1, t / .05) * Math.min(1, (DUR - t) / 1.2);
  L[n] = Math.tanh((L[n] + wet[Math.max(0, n - 7)]) * 1.1) * fade;
  R[n] = Math.tanh((R[n] + wet[n]) * 1.1) * fade;
  peak = Math.max(peak, Math.abs(L[n]), Math.abs(R[n]));
}
const gain = .89 / peak;   // about -1 dBFS

// ---------- 16-bit stereo WAV
const data = Buffer.alloc(N * 4);
for (let n = 0; n < N; n++) {
  data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, L[n] * gain)) * 32767), n * 4);
  data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, R[n] * gain)) * 32767), n * 4 + 2);
}
const header = Buffer.alloc(44);
header.write("RIFF", 0); header.writeUInt32LE(36 + data.length, 4); header.write("WAVE", 8);
header.write("fmt ", 12); header.writeUInt32LE(16, 16); header.writeUInt16LE(1, 20); header.writeUInt16LE(2, 22);
header.writeUInt32LE(SR, 24); header.writeUInt32LE(SR * 4, 28); header.writeUInt16LE(4, 32); header.writeUInt16LE(16, 34);
header.write("data", 36); header.writeUInt32LE(data.length, 40);
mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, Buffer.concat([header, data]));
console.log(`Wrote ${OUT} (${DUR}s, ${SR} Hz stereo)`);
