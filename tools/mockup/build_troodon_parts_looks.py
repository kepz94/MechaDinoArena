# build_troodon_parts_looks.py v0.1 (Mecha Dino Arena) — builds docs/mockups/troodon_parts_options.html: the Troodon mecha parts
# LOOKS + MOVES mockup (Kepu 2026-11-06 19:44 picks H1 A6 D1 D18 S6 H7 H12 D5 A10). Engine = tools/troodon_kit_mockup/engine_part.js
# + app_tail.js up to its "tracks" section (scene, rigs, springs, FX, pod, zone, heal pops); TROODON = tools/troodon_generator.py
# --look B --json (TroodonModelData 1.4 body); RAPTOR = tools/dilo_kit_mockup/raptor.json. Measured fit (optional):
# tools/mockup/troodon_parts_measure.json, written by tools/mockup/measure_troodon_parts.js (run it, then build again).
# Usage: python3 tools/mockup/build_troodon_parts_looks.py [three.min.js r128]
import json, subprocess, sys, os, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
three_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ic/node_modules/three/build/three.min.js"
tmp = tempfile.mkdtemp(); model = os.path.join(tmp, "troodon.json")
subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "troodon_generator.py"), "--look", "B", "--json", model], stdout=subprocess.DEVNULL)
K = os.path.join(ROOT, "tools", "troodon_kit_mockup")
engine = open(os.path.join(K, "engine_part.js")).read() + "\n" + open(os.path.join(K, "app_tail.js")).read().split("// ---------- tracks ----------")[0]
data = "// TROODON = TroodonModelData 1.4 body (troodon_generator --look B --json); RAPTOR = dilo kit raptor.json (enemies + squadmates)\nconst TROODON = " + json.dumps(json.load(open(model))) + ";\nconst RAPTOR = " + json.dumps(json.load(open(os.path.join(ROOT, "tools", "dilo_kit_mockup", "raptor.json")))) + ";\n"
mp = os.path.join(HERE, "troodon_parts_measure.json")
if os.path.exists(mp): data += "const TROO_MEAS = " + json.dumps(json.load(open(mp))) + ";\n"
js = data + engine + "\n" + open(os.path.join(HERE, "troodon_parts_looks.js")).read()
head = open(os.path.join(HERE, "troodon_parts_looks_head.html")).read()
page = head.replace('<script>/*THREE*/</script>', '<script>/* three.js r128 (MIT) */\n' + open(three_path).read() + '\n</script>')
out = os.path.join(ROOT, "docs", "mockups", "troodon_parts_options.html")
open(out, "w").write(page + js + "\n</script>\n</body>\n</html>\n")
print("ok", out, os.path.getsize(out))
