# Builds docs/mockups/pachy_head_options.html: pachy_head_head.html + pachy_head_app.js + the 3 generator exports
# + raptor_model.json + trex_model.json (tools/mockup/model_json.py). Run from tools/mockup: python3 build_dilo.py <three.min.js>
import json, subprocess, sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
three_path = sys.argv[1] if len(sys.argv) > 1 else '/tmp/ic/node_modules/three/build/three.min.js'
os.makedirs("/tmp/troo", exist_ok=True)
looks = {}
VARIANTS = {"A": ["--head", "egg"], "B": ["--head", "helm"], "C": ["--head", "ram"], "D": ["--head", "crown"],
            # v0.2: Kepu's pick (Crowned Skull, the Battering Dome spikes always on) with a bulkier mid section
            "E": ["--head", "crown", "--spikes", "--bulk", "1.25"], "F": ["--head", "crown", "--spikes", "--bulk", "1.4"]}
for k, args in VARIANTS.items():
    out = f"/tmp/troo/p_{k}.json"
    subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "pachy_generator.py"), *args, "--json", out], stdout=subprocess.DEVNULL)
    looks[k] = json.load(open(out))
h = open("pachy_head_head.html").read().replace('<script>/*THREE*/</script>', '<script>/* three.js r128 (MIT), inlined so the page works offline / in previews */\n' + open(three_path).read() + '\n</script>')
js = open("pachy_head_app.js").read().replace("__LOOKS__", json.dumps(looks)).replace("__RAPTOR__", json.dumps(json.load(open("raptor_model.json")))).replace("__TREX__", json.dumps(json.load(open("trex_model.json")))).replace("__TROODON__", json.dumps(json.load(open("troodon_model.json"))))
open(os.path.join(ROOT, "docs", "mockups", "pachy_head_options.html"), "w").write(h + js + "\n</script>\n</body>\n</html>\n")
print("built")
