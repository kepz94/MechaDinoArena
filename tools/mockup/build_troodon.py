# Builds docs/mockups/troodon_model_options.html: troodon_head.html + troodon_app.js + the 3 generator exports
# + herrera_model.json + raptor_model.json (tools/mockup/model_json.py). Run from tools/mockup: python3 build_troodon.py <three.min.js>
import json, subprocess, sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
three_path = sys.argv[1] if len(sys.argv) > 1 else '/tmp/ic/node_modules/three/build/three.min.js'
os.makedirs("/tmp/troo", exist_ok=True)
looks = {}
for k in "ABC":
    out = f"/tmp/troo/t_{k}.json"
    subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "troodon_generator.py"), "--look", k, "--json", out], stdout=subprocess.DEVNULL)
    looks[k] = json.load(open(out))
h = open("troodon_head.html").read().replace('<script>/*THREE*/</script>', '<script>/* three.js r128 (MIT), inlined so the page works offline / in previews */\n' + open(three_path).read() + '\n</script>')
js = open("troodon_app.js").read().replace("__LOOKS__", json.dumps(looks)).replace("__HERRERA__", json.dumps(json.load(open("herrera_model.json")))).replace("__RAPTOR__", json.dumps(json.load(open("raptor_model.json"))))
open(os.path.join(ROOT, "docs", "mockups", "troodon_model_options.html"), "w").write(h + js + "\n</script>\n</body>\n</html>\n")
print("built")
