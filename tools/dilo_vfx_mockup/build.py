# build.py v0.1 (Mecha Dino Arena) — builds docs/mockups/dilo_vfx_v0.1.html: the Dilo mecha part EFFECT families + MOBILITY options
# (Kepu 2026-11-10 13:49; scope "Dilo's parts only", mobility "Show me both kinds"). Pipeline = tools/mockup/build_dilo_parts_looks.py
# (DILO model_json export, RAPTOR, tools/dilo_kit_mockup/app.js up to its moves, tools/mockup/dilo_parts_looks.js up to its player),
# then dilovfx_fx.js (the 3 effect kits) and dilovfx_tracks.js (tracks, mobility simulator, player). head.html = the page.
# Usage: python3 tools/dilo_vfx_mockup/build.py [three.min.js r128]; env ART_OUT=path also writes the artifact variant (three.js from cdnjs).
import json, subprocess, sys, os, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
MK = os.path.join(ROOT, "tools", "mockup")
three_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ic/node_modules/three/build/three.min.js"
tmp = tempfile.mkdtemp(); model = os.path.join(tmp, "dilo.json")
subprocess.check_call([sys.executable, os.path.join(MK, "model_json.py"), os.path.join(ROOT, "src", "shared", "Models", "DiloModelData.luau"), model], stdout=subprocess.DEVNULL)
engine = open(os.path.join(ROOT, "tools", "dilo_kit_mockup", "app.js")).read().split("// ---------- moves ----------")[0]
looks = open(os.path.join(MK, "dilo_parts_looks.js")).read().split("// ---------- the player ----------")[0]
data = "const DILO = " + json.dumps(json.load(open(model))) + ";\nconst RAPTOR = " + json.dumps(json.load(open(os.path.join(MK, "raptor_model.json")))) + ";\n"
js = (data + engine + "\n// ===== tools/mockup/dilo_parts_looks.js (to its player) =====\n" + looks + "\n// ===== tools/dilo_vfx_mockup/dilovfx_fx.js =====\n"
      + open(os.path.join(HERE, "dilovfx_fx.js")).read() + "\n// ===== tools/dilo_vfx_mockup/dilovfx_tracks.js =====\n" + open(os.path.join(HERE, "dilovfx_tracks.js")).read())
head = open(os.path.join(HERE, "head.html")).read()
page = head.replace('<script>/*THREE*/</script>', '<script>/* three.js r128 (MIT) */\n' + open(three_path).read() + '\n</script>')
out = os.path.join(ROOT, "docs", "mockups", "dilo_vfx_v0.1.html")
open(out, "w").write(page + js + "\n</script>\n</body>\n</html>\n")
print("ok", out, os.path.getsize(out))
art = os.environ.get("ART_OUT")
if art:
    p = head.split("<head>", 1)[1].replace("</head>\n<body>\n", "").replace('<meta charset="utf-8">\n', "").replace('<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n', "")
    p = p.replace("<title>Dilo Effects + Mobility</title>", '<title>Dilo Effects + Mobility</title>\n<meta name="claude:viewport-fit-sides" content="cover">')
    p = p.replace('<script>/*THREE*/</script>', '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>')
    open(art, "w").write(p + js + "\n</script>\n")
    print("artifact", art, os.path.getsize(art))
