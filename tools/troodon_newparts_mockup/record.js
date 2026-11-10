// record.js v0.1 (Mecha Dino Arena) — records a short MP4 per recommended part from docs/mockups/troodon_newparts_options_v0.1.html:
// headless Chromium steps the page frame by frame (window.__np.frame), screenshots the stage, ffmpeg (-preset veryfast) encodes.
// Output: docs/mockups/troodon_newparts_options_v0.1/<id>.mp4 (<= 10 s each). Usage: node tools/troodon_newparts_mockup/record.js [id ...]
const {chromium} = require("playwright"); const fs = require("fs"), path = require("path"), {execFileSync} = require("child_process"), os = require("os");
const root = path.join(__dirname, "..", "..");
const OUT = path.join(root, "docs", "mockups", "troodon_newparts_options_v0.1");
const FPS = 24;
// camera schedule per part: [from t, camera]
const CAMS = {drum: [[0, "close"], [2.6, "scene"]], bloom: [[0, "close"], [1.0, "scene"]], jets: [[0, "close"]], horn: [[0, "close"], [1.05, "scene"]]};
(async () => {
  const ids = process.argv.slice(2).length ? process.argv.slice(2) : Object.keys(CAMS);
  const b = await chromium.launch({args: ["--use-gl=swiftshader", "--enable-webgl", "--ignore-gpu-blocklist"]});
  const p = await b.newPage({viewport: {width: 1000, height: 760}});
  p.on("pageerror", e => console.error("PAGEERROR", e.message));
  await p.goto("file://" + path.join(root, "docs", "mockups", "troodon_newparts_options_v0.1.html"));
  await p.waitForFunction(() => window.__ready, null, {timeout: 60000});
  const stage = await p.$(".stage");
  for (const id of ids) {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "np_" + id + "_"));
    await p.evaluate(id => window.__np.set(id, "boost", 3, 0, "close", 1), id);
    const len = Math.min(10, await p.evaluate(() => window.__np.len()));
    const n = Math.floor(len * FPS);
    for (let i = 0; i < n; i++) {
      const t = i / FPS, cm = CAMS[id].filter(c => t >= c[0]).pop()[1];
      await p.evaluate(([cm]) => { document.querySelector(`[data-view="${cm}"]`).click(); window.__np.frame(1 / 24); }, [cm]);
      await stage.screenshot({path: path.join(tmp, String(i).padStart(4, "0") + ".png")});
    }
    const mp4 = path.join(OUT, id + ".mp4");
    execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-framerate", String(FPS), "-i", path.join(tmp, "%04d.png"), "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", "-c:v", "libx264", "-preset", "veryfast", "-crf", "26", "-pix_fmt", "yuv420p", "-movflags", "+faststart", mp4]);
    fs.rmSync(tmp, {recursive: true, force: true});
    console.log("mp4", mp4, n, "frames", (n / FPS).toFixed(1), "s", fs.statSync(mp4).size);
  }
  await b.close();
})();
