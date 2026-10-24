#!/usr/bin/env node
// Renders promo/index.html to video by stepping its timeline one frame at a time in headless Chrome.
// No npm packages: it speaks the Chrome DevTools Protocol over Node's built-in WebSocket.
//
//   node promo/render.mjs                         → promo/out/pointer-colors-promo.mp4 (1080p, 60 fps)
//   node promo/render.mjs --fps 30 --out x.mp4
//   node promo/render.mjs --stills 0,5.6,18,24    → promo/out/still-<t>.png, for checking shots
import { spawn } from "node:child_process";
import { mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const CHROME = process.env.CHROME || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const args = Object.fromEntries(process.argv.slice(2).reduce((acc, a, i, all) => (a.startsWith("--") ? [...acc, [a.slice(2), all[i + 1]?.startsWith("--") ? true : all[i + 1] ?? true]] : acc), []));
const FPS = Number(args.fps || 60);
const OUT_DIR = join(HERE, "out");
const OUT = resolve(args.out || join(OUT_DIR, "pointer-colors-promo.mp4"));
const PORT = 9300 + Math.floor(Math.random() * 500);

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function launch() {
  const profile = join(tmpdir(), `promo-chrome-${PORT}`);
  const chrome = spawn(CHROME, [
    "--headless=new", `--remote-debugging-port=${PORT}`, `--user-data-dir=${profile}`,
    "--window-size=1920,1080", "--hide-scrollbars", "--force-device-scale-factor=1",
    "--allow-file-access-from-files", "--disable-gpu-vsync", "--mute-audio", "about:blank",
  ], { stdio: "ignore" });
  for (let i = 0; i < 100; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${PORT}/json/list`);
      const page = (await res.json()).find(t => t.type === "page");
      if (page) return { chrome, profile, ws: page.webSocketDebuggerUrl };
    } catch { /* not up yet */ }
    await sleep(100);
  }
  chrome.kill();
  throw new Error("Chrome didn't start");
}

function connect(url) {
  const ws = new WebSocket(url);
  let id = 0;
  const pending = new Map(), waiters = [];
  ws.onmessage = ({ data }) => {
    const msg = JSON.parse(data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve: ok, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      msg.error ? reject(new Error(msg.error.message)) : ok(msg.result);
    } else if (msg.method) {
      waiters.filter(w => w.method === msg.method).forEach(w => w.resolve(msg.params));
    }
  };
  const send = (method, params = {}) => new Promise((ok, reject) => { pending.set(++id, { resolve: ok, reject }); ws.send(JSON.stringify({ id, method, params })); });
  const once = method => new Promise(r => waiters.push({ method, resolve: r }));
  return new Promise(r => { ws.onopen = () => r({ send, once, close: () => ws.close() }); });
}

async function evaluate(cdp, expression) {
  const { result, exceptionDetails } = await cdp.send("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
  if (exceptionDetails) throw new Error(exceptionDetails.exception?.description || exceptionDetails.text);
  return result.value;
}

async function capture(cdp, format = "jpeg") {
  const { data } = await cdp.send("Page.captureScreenshot", { format, quality: format === "jpeg" ? 94 : undefined, captureBeyondViewport: false });
  return Buffer.from(data, "base64");
}

async function main() {
  const { chrome, profile, ws } = await launch();
  const cdp = await connect(ws);
  try {
    await cdp.send("Page.enable");
    await cdp.send("Emulation.setDeviceMetricsOverride", { width: 1920, height: 1080, deviceScaleFactor: 1, mobile: false });
    const loaded = cdp.once("Page.loadEventFired");
    await cdp.send("Page.navigate", { url: pathToFileURL(join(HERE, "index.html")).href + "?render=1" });
    await loaded;
    await evaluate(cdp, "document.fonts.ready.then(() => true)");
    const duration = await evaluate(cdp, "window.DURATION");
    mkdirSync(OUT_DIR, { recursive: true });

    if (args.stills) {
      for (const t of String(args.stills).split(",").map(Number)) {
        await evaluate(cdp, `seek(${t})`);
        await sleep(60);
        const file = join(OUT_DIR, `still-${t.toFixed(2)}.png`);
        writeFileSync(file, await capture(cdp, "png"));
        console.log("Wrote", file);
      }
      return;
    }

    const frames = Math.round(duration * FPS);
    const ffmpeg = spawn("ffmpeg", ["-y", "-loglevel", "error", "-f", "image2pipe", "-framerate", String(FPS), "-c:v", "mjpeg", "-i", "-",
      "-c:v", "libx264", "-preset", "slow", "-crf", "16", "-pix_fmt", "yuv420p", "-movflags", "+faststart", OUT], { stdio: ["pipe", "inherit", "inherit"] });
    const started = Date.now();
    for (let f = 0; f < frames; f++) {
      await evaluate(cdp, `seek(${(f / FPS).toFixed(5)})`);
      const jpg = await capture(cdp);
      if (!ffmpeg.stdin.write(jpg)) await new Promise(r => ffmpeg.stdin.once("drain", r));
      if (f % FPS === 0) process.stdout.write(`\r${f}/${frames} frames, ${((Date.now() - started) / 1000).toFixed(0)}s`);
    }
    ffmpeg.stdin.end();
    await new Promise((ok, fail) => ffmpeg.on("close", code => (code === 0 ? ok() : fail(new Error("ffmpeg exited " + code)))));
    console.log(`\nWrote ${OUT}`);
  } finally {
    cdp.close();
    const exited = new Promise(r => chrome.once("exit", r));
    chrome.kill();
    await exited;
    try { rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 }); } catch { /* temp dir; the OS cleans it */ }
  }
}

main().catch(err => { console.error(err); process.exit(1); });
