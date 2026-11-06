# build_teno_moves_anim.py v0.1 (Mecha Dino Arena) — builds docs/mockups/teno_moves_anim.html: the Teno move
# animations (the animation pass, Kepu 2026-11-05 17:33) on the real model with the 7 picked v2 part looks.
# Reuses the redesign mockup's core (scene, dino, kit; up to its page section) and looks (up to its list).
# Usage: python3 tools/mockup/build_teno_moves_anim.py [three.min.js r128]; env ART_OUT=path writes the artifact variant.
import json, subprocess, sys, os, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
three_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ic/node_modules/three/build/three.min.js"
out = os.path.join(tempfile.mkdtemp(), "teno_E.json")
subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "teno_generator.py"), "--look", "E", "--json", out], stdout=subprocess.DEVNULL)
core = open(os.path.join(HERE, "teno_parts_v2_core.js")).read().replace("__TENO__", json.dumps(json.load(open(out))))
core = core.split("// ---------- page state ----------")[0]
looks = open(os.path.join(HERE, "teno_parts_v2_looks.js")).read().split("// ============================================ the list")[0]
anim = open(os.path.join(HERE, "teno_moves_anim.js")).read()
js = core + "\n" + looks + "\n" + anim
head = open(os.path.join(HERE, "teno_moves_anim_head.html")).read()
page = head.replace('<script>/*THREE*/</script>', '<script>\n' + open(three_path).read() + '\n</script>')
open(os.path.join(ROOT, "docs", "mockups", "teno_moves_anim.html"), "w").write(page + js + "\n</script>\n</body>\n</html>\n")
print("ok")
art = os.environ.get("ART_OUT")
if art:
    p = head.split("<head>", 1)[1].replace("</head>\n<body>\n", "").replace('<meta charset="utf-8">\n', "").replace('<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n', "")
    p = p.replace("<title>Teno Move Animations</title>", '<title>Teno Move Animations</title>\n<meta name="claude:viewport-fit-sides" content="cover">')
    p = p.replace('<script>/*THREE*/</script>', '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>')
    open(art, "w").write(p + js + "\n</script>\n")
    print("artifact", art)
