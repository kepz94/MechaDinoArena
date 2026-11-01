# Builds docs/mockups/teno_attacks_options.html: teno_attacks_head.html + teno_attacks_app.js + teno C export + herrera_model.json
import json, subprocess, sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
three_path = sys.argv[1] if len(sys.argv) > 1 else '/tmp/ic/node_modules/three/build/three.min.js'
out = "/tmp/teno/teno_C.json"
subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "teno_generator.py"), "--look", "C", "--json", out], stdout=subprocess.DEVNULL)
h = open("teno_attacks_head.html").read().replace('<script>/*THREE*/</script>', '<script>/* three.js r128 (MIT), inlined so the page works offline / in previews */\n' + open(three_path).read() + '\n</script>')
js = open("teno_attacks_app.js").read().replace("__TENO__", json.dumps(json.load(open(out)))).replace("__HERRERA__", json.dumps(json.load(open("herrera_model.json"))))
open(os.path.join(ROOT, "docs", "mockups", "teno_attacks_options.html"), "w").write(h + js + "\n</script>\n</body>\n</html>\n")
print("built")
