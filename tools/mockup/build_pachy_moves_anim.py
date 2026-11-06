# build_pachy_moves_anim.py v0.1 (Mecha Dino Arena) — builds docs/mockups/pachy_moves_anim.html: the Pachy move animations
# (Kepu 2026-11-05 23:02 "Next" -> Pachy, "Moves animation pass", all 11 + victim hit-react). Engine = tools/dilo_kit_mockup/app.js up to its "moves"
# section (scene, rigs, springs, FX, projectiles); DILO (= the pachy, so the engine's rig code is reused unchanged) = model_json export of src/shared/Models/PachyModelData.luau;
# RAPTOR = tools/mockup/raptor_model.json. Usage: python3 tools/mockup/build_pachy_moves_anim.py [three.min.js r128];
# env ART_OUT=path writes the artifact variant (three.js from cdnjs).
import json, subprocess, sys, os, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
three_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ic/node_modules/three/build/three.min.js"
tmp = tempfile.mkdtemp(); model = os.path.join(tmp, "pachy.json")
subprocess.check_call([sys.executable, os.path.join(HERE, "model_json.py"), os.path.join(ROOT, "src", "shared", "Models", "PachyModelData.luau"), model], stdout=subprocess.DEVNULL)
engine = open(os.path.join(ROOT, "tools", "dilo_kit_mockup", "app.js")).read().split("// ---------- moves ----------")[0]
data = "// DILO = PachyModelData 1.5 (model_json export; the engine names its main rig 'dilo'); RAPTOR = raptor_model.json (target dummies)\nconst DILO = " + json.dumps(json.load(open(model))) + ";\nconst RAPTOR = " + json.dumps(json.load(open(os.path.join(HERE, "raptor_model.json")))) + ";\n"
# PARTS_DATA: tools/mockup/pachy_parts.json (the mecha parts as the server builders make them, model scale 1), renamed to the
# mockup's ids; the med pad is converted to world studs at game scale 2 (Base / Rim / Core scale, the edge ring does not).
pj = json.load(open(os.path.join(HERE, "pachy_parts.json")))
def seg_anchor(pc):
    a = pc["anchor"]
    if a.endswith(".Root"): return {"seg": a[:-5], "anchor": None}
    return {"anchor": a}
PARTS = {"camSide": 1}
for src, dst in [("hookArm", "hook"), ("servoDash", "servodash"), ("inkShooter", "ink"), ("tether", "tether"), ("bloodVials", "bloodvial"), ("domeVisor", "visor"), ("mechaLegs", "mechalegs")]:
    P = pj[src]; PARTS[dst] = {"pieces": [dict(pc, **seg_anchor(pc)) for pc in P["pieces"]]}
PARTS["hook"]["hidden"] = pj["hookArm"]["hiddenBodyParts"]
med = []
for pc in pj["medStation"]["pieces"]:
    q = dict(pc)
    if pc["n"] in ("Base", "Rim", "Core"): q["size"] = [v * 2 for v in pc["size"]]; q["pos"] = [v * 2 for v in pc["pos"]]
    med.append(q)
PARTS["medstation"] = {"pieces": med, "world": True}
anim = "// PARTS_DATA = tools/mockup/pachy_parts.json (converted by the build)\nconst PARTS_DATA = " + json.dumps(PARTS) + ";\n" + open(os.path.join(HERE, "pachy_moves_anim.js")).read()
js = data + engine + "\n" + anim
head = open(os.path.join(HERE, "pachy_moves_anim_head.html")).read()
page = head.replace('<script>/*THREE*/</script>', '<script>\n' + open(three_path).read() + '\n</script>')
open(os.path.join(ROOT, "docs", "mockups", "pachy_moves_anim.html"), "w").write(page + js + "\n</script>\n</body>\n</html>\n")
print("ok")
art = os.environ.get("ART_OUT")
if art:
    p = head.split("<head>", 1)[1].replace("</head>\n<body>\n", "").replace('<meta charset="utf-8">\n', "").replace('<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n', "")
    p = p.replace("<title>Pachy Move Animations</title>", '<title>Pachy Move Animations</title>\n<meta name="claude:viewport-fit-sides" content="cover">')
    p = p.replace('<script>/*THREE*/</script>', '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>')
    open(art, "w").write(p + js + "\n</script>\n")
    print("artifact", art)
