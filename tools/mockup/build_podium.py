# Builds docs/mockups/podium_leaderboard_v0.2.html: podium_head.html + podium_app.js + model_json.py exports of the 8 playable dinos.
# Run from tools/mockup: python3 build_podium.py <three.min.js>
import json, subprocess, sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
three_path = sys.argv[1] if len(sys.argv) > 1 else '/tmp/ic/node_modules/three/build/three.min.js'
os.makedirs("/tmp/podium", exist_ok=True)
SCALE = {"TRex": 1}  # in-game: T-Rex 1, every other dino 2 (docs/ROSTER.md)
models = {}
for key in ["TRex", "Raptor", "Pachy", "Herrera", "Teno", "Troodon", "Therizino", "Dilo"]:
    src = os.path.join(ROOT, "src", "shared", "Models", f"{key}ModelData.luau")
    out = f"/tmp/podium/{key}.json"
    subprocess.check_call([sys.executable, "model_json.py", src, out], stdout=subprocess.DEVNULL)
    models[key] = {"scale": SCALE.get(key, 2), "model": json.load(open(out))}
h = open("podium_head.html").read().replace('<script>/*THREE*/</script>', '<script>/* three.js r128 (MIT), inlined so the page works offline / in previews */\n' + open(three_path).read() + '\n</script>')
js = open("podium_app.js").read().replace("__MODELS__", json.dumps(models, separators=(",", ":")))
open(os.path.join(ROOT, "docs", "mockups", "podium_leaderboard_v0.2.html"), "w").write(h + js + "\n</script>\n</body>\n</html>\n")
print("built", len(models))
