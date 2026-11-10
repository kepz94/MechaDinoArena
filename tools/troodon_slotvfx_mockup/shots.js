// shots.js v0.1 (Mecha Dino Arena) — render check of docs/mockups/troodon_slotvfx_v0.1.html in headless Chromium: stage screenshots
// per (part, option, time, camera) into docs/mockups/troodon_slotvfx_v0.1/. Usage: node tools/troodon_slotvfx_mockup/shots.js [part ...]
const {chromium} = require("playwright"); const fs = require("fs"), path = require("path");
const root = path.join(__dirname, "..", "..");
const OUT = path.join(root, "docs", "mockups", "troodon_slotvfx_v0.1");
// [option, rank, t, cam, name]; dome: open 1.59, up from ~2.2, hits every 0.45 s from 2.29; burst: open 1.74 (C 1.86)
const PLAN = {dome: [], burst: []};
for (const k of ["A", "B", "C", "L"]) {
  PLAN.dome.push([k, 3, 1.85, "scene", k + "_open"], [k, 3, 3.05, "scene", k + "_up"], [k, 3, 3.05, "game", k + "_game"], [k, 0, 3.05, "close", k + "_inside"]);
  const o = k === "C" ? 1.86 : 1.74;
  PLAN.burst.push([k, 3, o + 0.12, "scene", k + "_burst"], [k, 3, o + 0.45, "scene", k + "_result"], [k, 3, o + 0.3, "game", k + "_game"]);
}
(async () => {
  fs.mkdirSync(OUT, {recursive: true});
  const ids = process.argv.slice(2).length ? process.argv.slice(2) : Object.keys(PLAN);
  const b = await chromium.launch({args: ["--use-gl=swiftshader", "--enable-webgl", "--ignore-gpu-blocklist"]});
  const p = await b.newPage({viewport: {width: 1200, height: 900}});
  p.on("pageerror", e => console.error("PAGEERROR", e.message));
  p.on("console", m => { if (m.type() === "error") console.error("CONSOLE", m.text()); });
  await p.route(/fonts\.(googleapis|gstatic)\.com/, r => r.abort());
  await p.goto("file://" + path.join(root, "docs", "mockups", "troodon_slotvfx_v0.1.html"));
  await p.waitForFunction(() => window.__ready && window.__vfx, null, {timeout: 60000});
  for (const id of ids) for (const [k, rk, t, cm, nm] of PLAN[id]) {
    const f = path.join(OUT, `${id}_${nm}.png`);
    for (let tries = 0; tries < 3; tries++) {
      try { await p.evaluate(([id, k, rk, t, cm]) => window.__vfx.set(id, k, rk, t, cm), [id, k, rk, t, cm]);
        await p.waitForTimeout(60); await (await p.$(".stage")).screenshot({path: f, timeout: 20000}); console.log("shot", f); break; }
      catch (e) { console.error("retry", f, String(e).split("\n")[0]); await p.reload(); await p.waitForFunction(() => window.__ready && window.__vfx, null, {timeout: 60000}); }
    }
  }
  await b.close();
})();
