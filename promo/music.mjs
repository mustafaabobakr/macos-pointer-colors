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
const L = new Float32Array(N), R = new Float32Array(N), SEND = new Float32Array(N), ECHO = new Float32Array(N);   // SEND feeds the reverb, ECHO the ping-pong delay

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
function put(i, v, pan = 0, send = 0, echo = 0) {
  if (i < 0 || i >= N) return;
  L[i] += v * Math.cos((pan + 1) * Math.PI / 4) * Math.SQRT2;
  R[i] += v * Math.sin((pan + 1) * Math.PI / 4) * Math.SQRT2;
  SEND[i] += v * send;
  ECHO[i] += v * echo;
}
/** A note with an AD envelope and a one-pole low-pass. */
function tone(t0, dur, freq, { type = "saw", amp = .2, attack = .005, decay = dur, pan = 0, send = .15, echo = 0, cutoff = 4000, detune = 0, sweep = 0, glideFrom = 0, sidechain = false } = {}) {
  const start = Math.floor(t0 * SR), len = Math.floor((dur + .05) * SR);
  let lp = 0, phase = Math.random();
  for (let n = 0; n < len; n++) {
    const t = n / SR, g = glideFrom ? glideFrom + (freq - glideFrom) * Math.min(1, t / .07) : freq;   // portamento for the lead
    const f = g * (1 + detune) * (1 + sweep * t);
    phase += f / SR;
    const env = Math.min(1, t / attack) * Math.exp(-t / Math.max(decay, .001) * 3) * (t > dur ? Math.max(0, 1 - (t - dur) / .05) : 1);
    const a = 1 - Math.exp(-2 * Math.PI * cutoff / SR);
    lp += a * (osc[type](phase) - lp);
    put(start + n, lp * env * amp * (sidechain ? duck(t0 + t) : 1), pan, send, echo);
  }
}
/** Kick ducking: everything with sidechain dips on each beat during the groove. */
function duck(t) {
  if (t < 5 || t >= 24.5) return 1;
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
    // "gate": the 80s gated-reverb snare, a loud flat tail that is chopped off
    const env = shape === "gate" ? (x < .82 ? 1 - .35 * x : Math.max(0, (1 - x) / .18) * .7) : Math.exp(-t / Math.max(decay, .001) * 4);
    put(s + n, band * env * amp, pan, send);
  }
}
const hat = (t, amp = .06, open = false) => noiseHit(t, open ? .22 : .05, { amp, from: 9000, q: .3, pan: .25, send: .05, decay: open ? .2 : .04 });
const clap = t => { for (const d of [0, .011, .022]) noiseHit(t + d, .16, { amp: .22, from: 1600, q: .5, send: .35, decay: .12 }); };
const click = t => { tone(t, .006, 3200, { type: "sine", amp: .25, decay: .006, send: .05, pan: .2 }); tone(t + .004, .03, 900, { type: "tri", amp: .18, decay: .03, send: .05, pan: .2 }); };

// ---------- the score: synthwave in A minor, 120 BPM
const CHORDS = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]];   // Am F C G
const chordAt = t => CHORDS[Math.floor(Math.max(0, t - 5) / BAR) % 4];
const GROOVE_END = 24.5;

/** Supersaw: five detuned saws per note, spread wide. The classic synthwave pad. */
function supersaw(t0, dur, notes, { amp = .022, cutoff = 2200, attack = .18, decay = 8, sidechain = true, send = .5 } = {}) {
  for (const m of notes) [-.012, -.006, 0, .006, .012].forEach((d, i) =>
    tone(t0, dur, midi(m), { type: "saw", amp, attack, decay, cutoff, detune: d, send, pan: (i - 2) * .32, sidechain }));
}
/** Gated-reverb snare: a short body, a bright burst and a chopped, roomy tail. */
function snare(t) {
  tone(t, .12, 190, { type: "tri", amp: .22, decay: .1, sweep: -1.2, send: .1 });
  noiseHit(t, .3, { amp: .32, from: 2400, q: .55, send: .25, shape: "gate" });
}
const tom = (t, m) => tone(t, .32, midi(m), { type: "sine", amp: .32, decay: .26, sweep: -.9, send: .35 });

// Intro, the problem (0–5): a dark pad that slowly brightens and an arpeggio in the echo. No drums yet.
supersaw(0, 4.9, [45, 57, 60, 64], { amp: .042, cutoff: 900, attack: 1.4, decay: 30, sidechain: false, send: .6 });
supersaw(2.4, 2.5, [57, 60, 64], { amp: .03, cutoff: 2400, attack: 1.2, decay: 30, sidechain: false, send: .6 });
for (let t = .5; t < 4.9; t += .125) {
  const i = Math.round(t / .125), note = [57, 60, 64, 69][i % 4] + 12;
  tone(t, .09, midi(note), { type: "saw", amp: .03 + .035 * (t / 4.9), decay: .08, cutoff: 1400 + 1800 * (t / 4.9), send: .2, echo: .55, pan: i % 2 ? -.3 : .3 });
}
[[4.5, 50], [4.625, 47], [4.75, 43], [4.875, 40]].forEach(([t, m]) => tom(t, m));     // tom fill into the drop

// The drive (5–24.5): kick on every beat, gated snare on 2 and 4, hats, pumping bass, pads, arpeggio.
for (let t = 5; t < GROOVE_END - 1e-9; t += BEAT) {
  kick(t, .72);
  const beat = Math.round((t - 5) / BEAT);
  if (beat % 2 === 1) snare(t);
  hat(t + .25, .045);
  if (beat % 2 === 1) hat(t + .25, .035, true);
}
for (let bar = 0; 5 + bar * BAR < GROOVE_END; bar++) {
  const t = 5 + bar * BAR, ch = CHORDS[bar % 4];
  for (let i = 0; i < 8; i++) {                   // 8th-note bass: root, octave, root, octave
    const bt = t + i * .25;
    if (bt >= GROOVE_END) break;
    tone(bt, .2, midi(ch[0] - 24 + (i % 2 ? 12 : 0)), { type: "saw", amp: .15, decay: .18, cutoff: 900, send: .02, sidechain: true });
    tone(bt, .2, midi(ch[0] - 24), { type: "sine", amp: .12, decay: .18, send: 0, sidechain: true });
  }
  supersaw(t, Math.min(BAR, GROOVE_END - t), ch, { amp: .016, cutoff: t >= 16 ? 3000 : 2200 });
}
for (let t = 5; t < GROOVE_END - 1e-9; t += .125) {   // 16th-note arpeggio through the ping-pong echo
  const ch = chordAt(t), i = Math.round((t - 5) / .125);
  const note = ch[[0, 1, 2, 1][i % 4]] + 12 + (i % 8 >= 4 ? 12 : 0);
  tone(t, .09, midi(note), { type: "square", amp: .026, decay: .08, cutoff: t >= 16 ? 3600 : 2600, send: .2, echo: .45, pan: i % 2 ? -.35 : .35, sidechain: true });
}
// Lead melody over the feature scenes, with a little portamento between notes.
const LEAD = [[16.0, .5, 76], [16.5, .5, 74], [17.0, 1.0, 76], [18.0, .5, 79], [18.5, .5, 76], [19.0, 1.0, 74], [20.0, .5, 71], [20.5, .5, 74],
              [21.0, .5, 72], [21.5, .5, 71], [22.0, 1.0, 69], [23.0, .5, 69], [23.5, .5, 72], [24.0, .7, 76]];
LEAD.forEach(([t, d, m], i) => {
  const from = i ? midi(LEAD[i - 1][2]) : 0;
  for (const det of [-.004, .004]) tone(t, d, midi(m), { type: "saw", amp: .05, attack: .01, decay: 3, cutoff: 3200, detune: det, glideFrom: from, send: .35, echo: .3, pan: det > 0 ? .15 : -.15 });
  tone(t, d, midi(m - 12), { type: "square", amp: .02, attack: .01, decay: 3, cutoff: 2000, glideFrom: from / 2, send: .3, echo: .2 });
});
[[23.75, 48], [23.875, 45], [24.0, 43], [24.125, 40]].forEach(([t, m]) => tom(t, m));   // fill into the end card

// End card (24.7–30): drums stop; a wide Am(add9) chord and echoing bells.
supersaw(24.6, 5.0, [45, 57, 60, 64, 71], { amp: .045, cutoff: 2600, attack: .05, decay: 12, sidechain: false, send: .75 });
[81, 76, 72, 69].forEach((m, i) => tone(24.7 + i * .375, 1.8, midi(m), { type: "sine", amp: .13, decay: 1.6, send: .6, echo: .5, pan: (i - 1.5) * .4 }));

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
// Ping-pong echo, a dotted eighth (0.375 s) left then right, feeding back.
const D = Math.round(.375 * SR), echoL = new Float32Array(N), echoR = new Float32Array(N);
for (let n = D; n < N; n++) {
  echoL[n] = ECHO[n - D] + echoR[n - D] * .42;
  echoR[n] = echoL[n - D] * .42;
}
for (let n = 0; n < N; n++) { L[n] += echoL[n] * .55; R[n] += echoR[n] * .55; }
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
