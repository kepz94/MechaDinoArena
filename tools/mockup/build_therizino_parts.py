# build_therizino_parts.py v0.1 (Mecha Dino Arena) — builds docs/mockups/therizino_parts_options.html (Therizino mecha button
# parts LOOKS mockup v0.1; Kepu 2026-11-04 picks 1, 3, 5, 12, 16, 18, 19). Same pattern as build_teno_abilities.py.
# Usage: python3 tools/mockup/build_therizino_parts.py [path/to/three.min.js (r128)]
import json, subprocess, sys, os, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
three_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ic/node_modules/three/build/three.min.js"  # three.js r128
out = os.path.join(tempfile.mkdtemp(), "theri_A.json")
subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "therizino_generator.py"), "--look", "A", "--json", out], stdout=subprocess.DEVNULL)
h = open(os.path.join(HERE, "therizino_parts_head.html")).read().replace('<script>/*THREE*/</script>', '<script>/* three.js r128 (MIT), inlined so the page works offline / in previews */\n' + open(three_path).read() + '\n</script>')
js = open(os.path.join(HERE, "therizino_parts_app.js")).read().replace("__THERI__", json.dumps(json.load(open(out)))).replace("__HERRERA__", json.dumps(json.load(open(os.path.join(HERE, "herrera_model.json")))))
open(os.path.join(ROOT, "docs", "mockups", "therizino_parts_options.html"), "w").write(h + js + "\n</script>\n</body>\n</html>\n")
