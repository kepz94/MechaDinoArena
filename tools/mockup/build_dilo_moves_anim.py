# build_dilo_moves_anim.py v0.1 (Mecha Dino Arena) — builds docs/mockups/dilo_moves_anim.html: the Dilo move animations
# (Kepu 2026-11-05 22:14 "Next" -> Dilo, "Moves animation pass"). Engine = tools/dilo_kit_mockup/app.js up to its "moves"
# section (scene, rigs, springs, FX, projectiles); DILO = model_json export of src/shared/Models/DiloModelData.luau;
# RAPTOR = tools/mockup/raptor_model.json. Usage: python3 tools/mockup/build_dilo_moves_anim.py [three.min.js r128];
# env ART_OUT=path writes the artifact variant (three.js from cdnjs).
import json, subprocess, sys, os, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
three_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ic/node_modules/three/build/three.min.js"
tmp = tempfile.mkdtemp(); model = os.path.join(tmp, "dilo.json")
subprocess.check_call([sys.executable, os.path.join(HERE, "model_json.py"), os.path.join(ROOT, "src", "shared", "Models", "DiloModelData.luau"), model], stdout=subprocess.DEVNULL)
engine = open(os.path.join(ROOT, "tools", "dilo_kit_mockup", "app.js")).read().split("// ---------- moves ----------")[0]
data = "// DILO = DiloModelData (model_json export); RAPTOR = raptor_model.json (target dummies)\nconst DILO = " + json.dumps(json.load(open(model))) + ";\nconst RAPTOR = " + json.dumps(json.load(open(os.path.join(HERE, "raptor_model.json")))) + ";\n"
anim = open(os.path.join(HERE, "dilo_moves_anim.js")).read()
js = data + engine + "\n" + anim
head = open(os.path.join(HERE, "dilo_moves_anim_head.html")).read()
page = head.replace('<script>/*THREE*/</script>', '<script>\n' + open(three_path).read() + '\n</script>')
open(os.path.join(ROOT, "docs", "mockups", "dilo_moves_anim.html"), "w").write(page + js + "\n</script>\n</body>\n</html>\n")
print("ok")
art = os.environ.get("ART_OUT")
if art:
    p = head.split("<head>", 1)[1].replace("</head>\n<body>\n", "").replace('<meta charset="utf-8">\n', "").replace('<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n', "")
    p = p.replace("<title>Dilo Move Animations</title>", '<title>Dilo Move Animations</title>\n<meta name="claude:viewport-fit-sides" content="cover">')
    p = p.replace('<script>/*THREE*/</script>', '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>')
    open(art, "w").write(p + js + "\n</script>\n")
    print("artifact", art)
