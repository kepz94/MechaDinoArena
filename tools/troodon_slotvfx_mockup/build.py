# build.py v0.1 (Mecha Dino Arena) — builds docs/mockups/troodon_slotvfx_v0.1.html: Shield Dome + Bloom Burst EFFECT options (Kepu
# 2026-11-10 10:38 "better vfx it looks so lazy"). Same pipeline as tools/troodon_slotparts_mockup/build.py (troodon body, raptor,
# engine, the old part helpers, slotparts.js v0.1), then slotvfx.js (this folder) on top. head.html = the slot parts page head with
# this page's title and intro.
# Usage: python3 tools/troodon_slotvfx_mockup/build.py [three.min.js r128]
import json, subprocess, sys, os, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SP = os.path.join(ROOT, "tools", "troodon_slotparts_mockup")
three_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ic/node_modules/three/build/three.min.js"
tmp = tempfile.mkdtemp(); model = os.path.join(tmp, "troodon.json")
subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "troodon_generator.py"), "--look", "B", "--json", model], stdout=subprocess.DEVNULL)
K = os.path.join(ROOT, "tools", "troodon_kit_mockup")
engine = open(os.path.join(K, "engine_part.js")).read() + "\n" + open(os.path.join(K, "app_tail.js")).read().split("// ---------- tracks ----------")[0]
old = open(os.path.join(ROOT, "tools", "mockup", "troodon_parts_looks.js")).read().split("// ---------- extra key poses")[0]
data = "const TROODON = " + json.dumps(json.load(open(model))) + ";\nconst RAPTOR = " + json.dumps(json.load(open(os.path.join(ROOT, "tools", "dilo_kit_mockup", "raptor.json")))) + ";\n"
mp = os.path.join(SP, "measure.json")
if os.path.exists(mp): data += "const NP_MEAS = " + json.dumps(json.load(open(mp))) + ";\n"
js = (data + engine + "\n// ===== tools/mockup/troodon_parts_looks.js =====\n" + old + "\n// ===== tools/troodon_slotparts_mockup/slotparts.js =====\n"
      + open(os.path.join(SP, "slotparts.js")).read() + "\n// ===== tools/troodon_slotvfx_mockup/slotvfx.js =====\n" + open(os.path.join(HERE, "slotvfx.js")).read())
head = open(os.path.join(SP, "head.html")).read()
head = head.replace("<title>Troodon Slot Parts</title>", "<title>Troodon Slot Effects</title>", 1)
h0 = head.index("<h1>"); h1 = head.index("</h1>", h0)
head = head[:h0] + '<h1><span>Troodon</span> · Shield Dome + Bloom Burst effects <span id="ver" style="color:var(--muted);font-size:.6em"></span>' + head[h1:]
l0 = head.index('<p class="lede">'); l1 = head.index("</p>", l0)
head = head[:l0] + '<p class="lede">3 new effect options for each part, plus <b>In the game now</b> to compare. Pick the tab, then the <b>Effect</b>. The dome is the new size (90 studs wide, 121.5 at ★).' + head[l1:]
page = head.replace('<script>/*THREE*/</script>', '<script>/* three.js r128 (MIT) */\n' + open(three_path).read() + '\n</script>')
out = os.path.join(ROOT, "docs", "mockups", "troodon_slotvfx_v0.1.html")
open(out, "w").write(page + js + "\n</script>\n</body>\n</html>\n")
print("ok", out, os.path.getsize(out))
