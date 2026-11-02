# T-Rex redesign mockup builder (from build_pachy_head.py). Builds docs/mockups/trex_redesign_options.html: trex_head.html + trex_app.js + the 3 generator exports
# + raptor_model.json + trex_model.json (tools/mockup/model_json.py). Run from tools/mockup: python3 build_dilo.py <three.min.js>
import json, subprocess, sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
three_path = sys.argv[1] if len(sys.argv) > 1 else '/tmp/ic/node_modules/three/build/three.min.js'
os.makedirs("/tmp/troo", exist_ok=True)
looks = {}
VARIANTS = {"A": ["--look", "A"], "B": ["--look", "B"], "C": ["--look", "C"],
            # v0.2: A2 true to life at today's size, and X = A2 at roster scale (62 studs)
            "A2": ["--look", "A2"], "X": ["--look", "A2", "--len", "62"]}
for k, args in VARIANTS.items():
    out = f"/tmp/troo/tr_{k}.json"
    subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "trex_generator.py"), *args, "--json", out], stdout=subprocess.DEVNULL)
    looks[k] = json.load(open(out))
subprocess.check_call([sys.executable, "model_json.py", os.path.join(ROOT, "src", "shared", "Models", "TRexModelData.luau"), "/tmp/troo/tr_N.json"], stdout=subprocess.DEVNULL)
looks = {"N": dict(json.load(open("/tmp/troo/tr_N.json")), roles={"main": "666A4A", "dark": "50523A", "belly": "B2A278"}), **looks}
h = open("trex_head.html").read().replace('<script>/*THREE*/</script>', '<script>/* three.js r128 (MIT), inlined so the page works offline / in previews */\n' + open(three_path).read() + '\n</script>')
js = open("trex_app.js").read().replace("__LOOKS__", json.dumps(looks)).replace("__RAPTOR__", json.dumps(json.load(open("raptor_model.json")))).replace("__TREX__", json.dumps(json.load(open("trex_model.json")))).replace("__TROODON__", json.dumps(json.load(open("troodon_model.json"))))
open(os.path.join(ROOT, "docs", "mockups", "trex_redesign_options.html"), "w").write(h + js + "\n</script>\n</body>\n</html>\n")
print("built")
