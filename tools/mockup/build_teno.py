# Builds docs/mockups/teno_model_options.html: teno_head.html + teno_app.js + the 3 generator exports + herrera_model.json
import json, subprocess, sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
three_path = sys.argv[1] if len(sys.argv) > 1 else '/tmp/ic/node_modules/three/build/three.min.js'
looks = {}
for k in "ABC":
    out = f"/tmp/teno/teno_{k}.json"
    subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "teno_generator.py"), "--look", k, "--json", out], stdout=subprocess.DEVNULL)
    looks[k] = json.load(open(out))
h = open("teno_head.html").read().replace('<script>/*THREE*/</script>', '<script>/* three.js r128 (MIT), inlined so the page works offline / in previews */\n' + open(three_path).read() + '\n</script>')
js = open("teno_app.js").read().replace("__LOOKS__", json.dumps(looks)).replace("__HERRERA__", json.dumps(json.load(open("herrera_model.json"))))
open(os.path.join(ROOT, "docs", "mockups", "teno_model_options.html"), "w").write(h + js + "\n</script>\n</body>\n</html>\n")
print("built")
