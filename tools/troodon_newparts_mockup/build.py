# build.py v0.1 (Mecha Dino Arena) — builds docs/mockups/troodon_newparts_options_v0.1.html: the Troodon NEW parts options
# mockup (Kepu 2026-11-10: 4 new parts to replace Last Feather / Overheal Plume / Fortify Field / Ricochet Pod). Same pipeline as
# tools/mockup/build_troodon_parts_looks.py: TROODON = tools/troodon_generator.py --look B --json; RAPTOR = tools/dilo_kit_mockup/
# raptor.json; engine = tools/troodon_kit_mockup/engine_part.js + app_tail.js up to "tracks"; then tools/mockup/
# troodon_parts_looks.js up to "extra key poses" (piece / bracket / seat / carry helpers + the old part meshes, so the 5 live
# button looks can be shown); then newparts.js. Measured fit (optional): measure.json here, written by measure.js.
# Usage: python3 tools/troodon_newparts_mockup/build.py [three.min.js r128]
import json, subprocess, sys, os, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
three_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ic/node_modules/three/build/three.min.js"
tmp = tempfile.mkdtemp(); model = os.path.join(tmp, "troodon.json")
subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "troodon_generator.py"), "--look", "B", "--json", model], stdout=subprocess.DEVNULL)
K = os.path.join(ROOT, "tools", "troodon_kit_mockup")
engine = open(os.path.join(K, "engine_part.js")).read() + "\n" + open(os.path.join(K, "app_tail.js")).read().split("// ---------- tracks ----------")[0]
old = open(os.path.join(ROOT, "tools", "mockup", "troodon_parts_looks.js")).read().split("// ---------- extra key poses")[0]
data = "// TROODON = TroodonModelData body (troodon_generator --look B --json); RAPTOR = dilo kit raptor.json (enemies + squadmates)\nconst TROODON = " + json.dumps(json.load(open(model))) + ";\nconst RAPTOR = " + json.dumps(json.load(open(os.path.join(ROOT, "tools", "dilo_kit_mockup", "raptor.json")))) + ";\n"
mp = os.path.join(HERE, "measure.json")
if os.path.exists(mp): data += "const NP_MEAS = " + json.dumps(json.load(open(mp))) + ";\n"
js = data + engine + "\n// ===== tools/mockup/troodon_parts_looks.js (helpers + the old part meshes) =====\n" + old + "\n// ===== tools/troodon_newparts_mockup/newparts.js =====\n" + open(os.path.join(HERE, "newparts.js")).read()
head = open(os.path.join(HERE, "head.html")).read()
page = head.replace('<script>/*THREE*/</script>', '<script>/* three.js r128 (MIT) */\n' + open(three_path).read() + '\n</script>')
out = os.path.join(ROOT, "docs", "mockups", "troodon_newparts_options_v0.1.html")
open(out, "w").write(page + js + "\n</script>\n</body>\n</html>\n")
print("ok", out, os.path.getsize(out))
