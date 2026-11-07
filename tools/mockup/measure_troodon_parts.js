// measure_troodon_parts.js v0.1 (Mecha Dino Arena) — runs window.__troo.measure() on docs/mockups/troodon_parts_options.html in
// headless Chromium (Playwright) and writes tools/mockup/troodon_parts_measure.json (125-point fit per piece, idle + move;
// part-vs-part clashes for the recommended set and for any mix). Then rebuild: python3 tools/mockup/build_troodon_parts_looks.py.
// Usage: node tools/mockup/measure_troodon_parts.js   (needs require('playwright'))
const {chromium} = require("playwright"); const fs = require("fs"), path = require("path");
(async () => {
  const root = path.join(__dirname, "..", "..");
  const b = await chromium.launch({args: ["--use-gl=swiftshader", "--enable-webgl", "--ignore-gpu-blocklist"]});
  const p = await b.newPage({viewport: {width: 900, height: 700}});
  p.on("pageerror", e => console.error("PAGEERROR", e.message));
  await p.goto("file://" + path.join(root, "docs", "mockups", "troodon_parts_options.html"));
  await p.waitForFunction(() => window.__ready, null, {timeout: 60000});
  const r = await p.evaluate(() => window.__troo.measure());
  fs.writeFileSync(path.join(__dirname, "troodon_parts_measure.json"), JSON.stringify(r, null, 1));
  for (const [k, v] of Object.entries(r.looks)) console.log(k.padEnd(15), "idle", String(v.idle).padStart(5), "move", String(v.move).padStart(5), "kit", String(v.kit).padStart(5), "|", v.moveWorst || "-", "|", v.kitWorst || "-", "| br", v.bracketIdle, v.bracketMove, v.floating.length ? "FLOAT " + v.floating.join(",") : "");
  console.log("rec clashes", JSON.stringify(r.rec)); console.log("any", JSON.stringify(r.any)); console.log("busy", JSON.stringify(r.busy));
  await b.close();
})();
