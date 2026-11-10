// shots.js v0.1 (Mecha Dino Arena) — render check of docs/mockups/troodon_newparts_options_v0.1.html in headless Chromium:
// one stage screenshot per (candidate, camera, time) into docs/mockups/troodon_newparts_options_v0.1/.
// Usage: node tools/troodon_newparts_mockup/shots.js [id ...]   (default: every candidate, close-up + game camera + key frames)
const {chromium} = require("playwright"); const fs = require("fs"), path = require("path");
const root = path.join(__dirname, "..", "..");
const OUT = path.join(root, "docs", "mockups", "troodon_newparts_options_v0.1");
// [id, mode, rank, t, cam, name]
const PLAN = {
  drum: [["boost", 3, 0.3, "part", "closeup"], ["boost", 3, 0.82, "close", "34_throw"], ["boost", 3, 1.2, "game", "game"], ["boost", 3, 0.3, "front", "front"], ["boost", 3, 0.3, "top", "top"], ["boost", 3, 0.3, "side", "side"]],
  bloom: [["boost", 3, 0.3, "part", "closeup"], ["boost", 3, 2.4, "scene", "scene_zone"], ["boost", 3, 2.4, "game", "game"], ["compare", 3, 2.4, "scene", "compare"], ["boost", 3, 0.3, "side", "side"], ["boost", 3, 0.3, "top", "top"]],
  jets: [["boost", 3, 0.3, "part", "closeup"], ["boost", 3, 0.75, "close", "34_flap"], ["boost", 3, 1.25, "game", "game"], ["compare", 3, 2.6, "scene", "compare"], ["boost", 3, 0.3, "side", "side"], ["boost", 3, 0.3, "front", "front"]],
  horn: [["boost", 3, 0.3, "part", "closeup"], ["boost", 3, 2.33, "close", "34_note"], ["boost", 3, 2.33, "game", "game"], ["boost", 3, 1.45, "scene", "scene_splat"], ["boost", 3, 0.3, "side", "side"]],
  fan: [["boost", 3, 0.3, "part", "closeup"], ["boost", 3, 2.6, "close", "34_glide"], ["boost", 3, 2.6, "game", "game"], ["compare", 3, 3.2, "scene", "compare"], ["boost", 3, 0.3, "side", "side"]],
  lens: [["boost", 3, 0.3, "part", "closeup"], ["boost", 3, 1.55, "scene", "scene_marks"], ["boost", 3, 1.55, "game", "game"], ["boost", 3, 0.3, "front", "front"]],
  burst: [["boost", 3, 0.3, "part", "closeup"], ["boost", 3, 0.88, "close", "34_windup"], ["boost", 3, 1.86, "scene", "scene_burst"], ["boost", 3, 1.86, "game", "game"]],
  vent: [["boost", 3, 0.3, "part", "closeup"], ["boost", 3, 2.1, "scene", "scene_column"], ["boost", 3, 2.6, "game", "game"], ["boost", 3, 2.4, "close", "34_launch"]],
  set: [["boost", 3, 0.3, "part", "closeup"], ["boost", 3, 0.3, "close", "34"], ["boost", 3, 0.3, "game", "game"], ["boost", 3, 1.6, "side", "throw_side"], ["boost", 3, 3.0, "close", "flap"], ["boost", 3, 4.0, "top", "glide_top"], ["boost", 3, 5.3, "side", "run_side"], ["boost", 3, 0.3, "front", "front"]],
};
(async () => {
  fs.mkdirSync(OUT, {recursive: true});
  const ids = process.argv.slice(2).length ? process.argv.slice(2) : Object.keys(PLAN);
  const b = await chromium.launch({args: ["--use-gl=swiftshader", "--enable-webgl", "--ignore-gpu-blocklist"]});
  const p = await b.newPage({viewport: {width: 1200, height: 900}});
  p.on("pageerror", e => console.error("PAGEERROR", e.message));
  p.on("console", m => { if (m.type() === "error") console.error("CONSOLE", m.text()); });
  await p.goto("file://" + path.join(root, "docs", "mockups", "troodon_newparts_options_v0.1.html"));
  await p.waitForFunction(() => window.__ready, null, {timeout: 60000});
  for (const id of ids) for (const [md, rk, t, cm, nm] of PLAN[id]) {
    const f = path.join(OUT, `${id}_${nm}.png`);
    for (let tries = 0; tries < 3; tries++) {
      try { await p.evaluate(([id, md, rk, t, cm]) => window.__np.set(id, md, rk, t, cm, 1), [id, md, rk, t, cm]);
        await p.waitForTimeout(60); await (await p.$(".stage")).screenshot({path: f, timeout: 20000}); console.log("shot", f); break; }
      catch (e) { console.error("retry", f, String(e).split("\n")[0]); await p.reload(); await p.waitForFunction(() => window.__ready, null, {timeout: 60000}); }
    }
  }
  await b.close();
})();
