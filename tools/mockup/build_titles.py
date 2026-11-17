# build_titles.py v0.1 (Mecha Dino Arena) — builds docs/mockups/victory_titles_v0.1.html: titles_head.html + titles_engine.js
# + titles_anims.js + titles_app.js + model_json.py exports of the 8 playable dinos (in-game scale: T-Rex 1, others 2).
# Run from tools/mockup: python3 build_titles.py [three.min.js r128]
import json, subprocess, sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
three_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ic/node_modules/three/build/three.min.js"
os.makedirs("/tmp/titles", exist_ok=True)
models = {}
for key in ["TRex", "Raptor", "Pachy", "Herrera", "Teno", "Troodon", "Therizino", "Dilo"]:
    src = os.path.join(ROOT, "src", "shared", "Models", f"{key}ModelData.luau"); out = f"/tmp/titles/{key}.json"
    subprocess.check_call([sys.executable, "model_json.py", src, out], stdout=subprocess.DEVNULL)
    models[key] = {"scale": 1 if key == "TRex" else 2, "model": json.load(open(out))}
js = open("titles_engine.js").read().replace("__MODELS__", json.dumps(models, separators=(",", ":"))) + "\n" + open("titles_anims.js").read() + "\n" + open("titles_app.js").read()
h = open("titles_head.html").read().replace("<script>/*THREE*/</script>", "<script>/* three.js r128 (MIT), inlined so the page works offline / in previews */\n" + open(three_path).read() + "\n</script>")
open(os.path.join(ROOT, "docs", "mockups", "victory_titles_v0.1.html"), "w").write(h + js + "\n</script>\n</body>\n</html>\n")
print("built")
