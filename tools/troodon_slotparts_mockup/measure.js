// measure.js v0.1 (Mecha Dino Arena) — runs window.__np.measure() on docs/mockups/troodon_slotparts_v0.1.html in headless
// Chromium (Playwright) and writes tools/troodon_slotparts_mockup/measure.json (125-point fit per piece: idle, its move, the kit
// poses throw / flaps / glide / run; clashes with the recommended set + the 5 live button looks). Then rebuild with build.py.
// Usage: node tools/troodon_slotparts_mockup/measure.js
const {chromium} = require("playwright"); const fs = require("fs"), path = require("path");
(async () => {
  const root = path.join(__dirname, "..", "..");
  const b = await chromium.launch({args: ["--use-gl=swiftshader", "--enable-webgl", "--ignore-gpu-blocklist"]});
  const p = await b.newPage({viewport: {width: 900, height: 700}});
  p.on("pageerror", e => console.error("PAGEERROR", e.message));
  await p.route(/fonts\.(googleapis|gstatic)\.com/, r => r.abort());
  await p.goto("file://" + path.join(root, "docs", "mockups", "troodon_slotparts_v0.1.html"));
  await p.waitForFunction(() => window.__ready, null, {timeout: 60000});
  const r = await p.evaluate(() => window.__np.measure());
  fs.writeFileSync(path.join(__dirname, "measure.json"), JSON.stringify(r, null, 1));
  for (const [k, v] of Object.entries(r.looks)) console.log(k.padEnd(9), "idle", v.idle, "move", v.move, "kit", JSON.stringify(v.kit), "|", v.moveWorst || "-", "|", JSON.stringify(v.kitWorst), "| br", v.bracketIdle, v.bracketMove, v.floating.length ? "FLOAT " + v.floating.join(",") : "");
  console.log("rec clashes", JSON.stringify(r.rec)); console.log("alt", JSON.stringify(r.alt)); console.log("gaps", JSON.stringify(r.gaps));
  await b.close();
})();
