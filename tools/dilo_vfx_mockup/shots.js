// shots.js v0.1 (Mecha Dino Arena) — render check of docs/mockups/dilo_vfx_v0.1.html in headless Chromium: stage screenshots per
// (tab, option, time, camera) into OUT (default the scratchpad). Usage: node tools/dilo_vfx_mockup/shots.js OUT "tab:opt:t:cam:zoom" ...
const {chromium} = require("playwright"); const fs = require("fs"), path = require("path");
const root = path.join(__dirname, "..", "..");
const OUT = process.argv[2]; const LIST = process.argv.slice(3);
(async () => {
  fs.mkdirSync(OUT, {recursive: true});
  const b = await chromium.launch({args: ["--use-gl=swiftshader", "--enable-webgl", "--ignore-gpu-blocklist"]});
  const p = await b.newPage({viewport: {width: 1100, height: 900}});
  p.on("pageerror", e => console.error("PAGEERROR", e.message, e.stack && e.stack.split("\n").slice(0, 3).join(" | ")));
  p.on("console", m => { if (m.type() === "error") console.error("CONSOLE", m.text()); });
  await p.route(/fonts\.(googleapis|gstatic)\.com/, r => r.abort());
  await p.goto("file://" + path.join(root, "docs", "mockups", "dilo_vfx_v0.1.html"));
  await p.waitForFunction(() => window.__ready && window.__vfx, null, {timeout: 90000});
  for (const spec of LIST) { const [tab, opt, t, cam, zoom] = spec.split(":"); const f = path.join(OUT, `${tab}_${opt}_${t}_${cam || "hero"}.png`);
    try { const st = await p.evaluate(([tab, opt, t, cam, zoom]) => { window.__vfx.set(tab, opt, +t, cam || "hero", zoom ? +zoom : undefined); return window.__vfx.state(); }, [tab, opt, t, cam, zoom]);
      await p.waitForTimeout(50); await (await p.$(".stage")).screenshot({path: f, timeout: 30000}); console.log("shot", f, JSON.stringify(st)); }
    catch (e) { console.error("fail", f, String(e).split("\n")[0]); } }
  await b.close();
})();
