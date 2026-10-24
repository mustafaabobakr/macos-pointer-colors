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
// --sfx-only writes just the click and slider sounds (out/sfx.wav), to lay over a licensed track.
const SFX_ONLY = process.argv.includes("--sfx-only");
const OUT = resolve(process.argv.includes("--out") ? process.argv[process.argv.indexOf("--out") + 1] : join(HERE, "out", SFX_ONLY ? "sfx.wav" : "music.wav"));
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

if (!SFX_ONLY) {
// ---------- the score: minimal electronic in F major, 120 BPM. Clean, bright and spacious.
const CHORDS = [[53, 57, 60, 64], [57, 60, 64, 67], [50, 53, 57, 60], [46, 50, 53, 57]];   // Fmaj7 Am7 Dm7 B♭maj7
const chordAt = t => CHORDS[Math.floor(Math.max(0, t - 5) / BAR) % 4];
const GROOVE_END = 24.5;

/** A soft, bell-like pluck: a sine with a quiet octave partial and a fast decay. */
function pluck(t, m, { amp = .08, decay = .35, pan = 0, send = .35, echo = .35, cutoff = 5000 } = {}) {
  tone(t, decay, midi(m), { type: "sine", amp, attack: .003, decay, pan, send, echo, cutoff });
  tone(t, decay * .5, midi(m + 12), { type: "sine", amp: amp * .28, attack: .002, decay: decay * .4, pan, send, echo, cutoff });
}
/** A warm pad: triangles, slightly detuned, slow attack. */
function pad(t0, dur, notes, { amp = .028, attack = .6, send = .55 } = {}) {
  for (const m of notes) for (const d of [-.003, .003]) tone(t0, dur, midi(m), { type: "tri", amp, attack, decay: 12, cutoff: 1800, detune: d, send, pan: d > 0 ? .45 : -.45, sidechain: true });
}
const softKick = t => kick(t, .3);
const rim = t => { tone(t, .02, 1700, { type: "tri", amp: .1, decay: .02, send: .2, pan: -.15 }); noiseHit(t, .03, { amp: .06, from: 4000, q: .6, send: .2, decay: .02 }); };
const shaker = (t, amp = .018) => noiseHit(t, .05, { amp, from: 8000, q: .4, pan: .3, send: .05, decay: .04 });

// Intro, the problem (0–5): a sparse motif on the beat, ringing in the echo, over a soft pad. No drums.
pad(0, 4.9, [41, 53, 57, 60, 64], { amp: .03, attack: 1.4 });
[[.5, 72], [1.0, 76], [1.5, 79], [2.5, 77], [3.0, 76], [3.5, 72], [4.25, 74]].forEach(([t, m]) => pluck(t, m, { amp: .09, decay: .6, echo: .5, pan: (m % 2 ? -.25 : .25) }));

// The groove (5–24.5): soft kick, rim on 2 and 4, a quiet shaker, sub bass, pad and a gentle arpeggio.
for (let t = 5; t < GROOVE_END - 1e-9; t += BEAT) {
  softKick(t);
  const beat = Math.round((t - 5) / BEAT);
  if (beat % 2 === 1) rim(t);
}
for (let t = 5; t < GROOVE_END - 1e-9; t += .25) shaker(t, (Math.round((t - 5) / .25) % 2 ? .02 : .012) * (t >= 16 ? 1.3 : 1));
for (let bar = 0; 5 + bar * BAR < GROOVE_END; bar++) {
  const t = 5 + bar * BAR, ch = CHORDS[bar % 4], dur = Math.min(BAR, GROOVE_END - t);
  for (const off of [0, 1.0]) if (t + off < GROOVE_END) tone(t + off, .9, midi(ch[0] - 12), { type: "sine", amp: .11, attack: .01, decay: .9, send: .02, sidechain: true });   // sub, half notes
  pad(t, dur, ch, { amp: .022, attack: .25 });
}
for (let t = 5; t < GROOVE_END - 1e-9; t += .25) {       // 8th-note pluck arpeggio
  const ch = chordAt(t), i = Math.round((t - 5) / .25);
  pluck(t, ch[[0, 2, 1, 3, 2, 1][i % 6]] + 12, { amp: .045, decay: .28, pan: i % 2 ? -.3 : .3, echo: .25, send: .25 });
}
// A glassy bell melody over the feature scenes.
const MELODY = [[16.0, 84], [16.75, 81], [17.0, 79], [18.0, 84], [18.5, 86], [19.0, 81], [20.0, 77], [20.75, 79], [21.0, 81], [22.0, 76], [22.5, 77], [23.0, 79], [24.0, 81]];
MELODY.forEach(([t, m]) => pluck(t, m, { amp: .07, decay: .9, echo: .4, send: .5, pan: .1 }));

// End card (24.5–30): drums stop; a held Fmaj9 and three last bell notes.
pad(24.5, 5.2, [41, 53, 57, 60, 64, 67], { amp: .032, attack: .3 });
[[24.7, 84], [25.45, 81], [26.2, 77]].forEach(([t, m]) => pluck(t, m, { amp: .08, decay: 1.4, echo: .5, send: .6 }));

}

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
const gain = SFX_ONLY ? .5 : .89 / peak;   // the score peaks near -1 dBFS; effects keep a fixed level for mixing

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
