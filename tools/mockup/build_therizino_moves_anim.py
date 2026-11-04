# build_therizino_moves_anim.py v0.1 (Mecha Dino Arena) — builds docs/mockups/therizino_moves_anim.html: the Therizino move
# animations (Kepu 2026-11-04 picks Harvest-C, Snare-B, Dash-C, Hook-B) on the real model with the picked part looks.
# Reuses the redesign mockup's core (scene, dino, kit; up to its page section) and looks (up to its list).
# Usage: python3 tools/mockup/build_therizino_moves_anim.py [three.min.js r128]; env ART_OUT=path writes the artifact variant.
import json, subprocess, sys, os, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
three_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ic/node_modules/three/build/three.min.js"
out = os.path.join(tempfile.mkdtemp(), "theri_A.json")
subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "therizino_generator.py"), "--look", "A", "--json", out], stdout=subprocess.DEVNULL)
core = open(os.path.join(HERE, "therizino_parts_v2_core.js")).read().replace("__THERI__", json.dumps(json.load(open(out))))
core = core.split("// ---------- page state ----------")[0]
looks = open(os.path.join(HERE, "therizino_parts_v2_looks.js")).read().split("// ============================================ the list")[0]
anim = open(os.path.join(HERE, "therizino_moves_anim.js")).read()
js = core + "\n" + looks + "\n" + anim
head = open(os.path.join(HERE, "therizino_moves_anim_head.html")).read()
page = head.replace('<script>/*THREE*/</script>', '<script>\n' + open(three_path).read() + '\n</script>')
open(os.path.join(ROOT, "docs", "mockups", "therizino_moves_anim.html"), "w").write(page + js + "\n</script>\n</body>\n</html>\n")
print("ok")
art = os.environ.get("ART_OUT")
if art:
    p = head.split("<head>", 1)[1].replace("</head>\n<body>\n", "").replace('<meta charset="utf-8">\n', "").replace('<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n', "")
    p = p.replace("<title>Therizino Move Animations</title>", '<title>Therizino Move Animations</title>\n<meta name="claude:viewport-fit-sides" content="cover">')
    p = p.replace('<script>/*THREE*/</script>', '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>')
    open(art, "w").write(p + js + "\n</script>\n")
    print("artifact", art)
