# build_therizino_parts_v2.py v0.2 (Mecha Dino Arena) — builds docs/mockups/therizino_parts_redesign.html (Therizino mecha
# parts REDESIGN mockup v0.2; Kepu 2026-11-04 13:25 "redesign these mecha parts ... in our styles"; scope "Therizino first").
# Usage: python3 tools/mockup/build_therizino_parts_v2.py [path/to/three.min.js (r128)]
import json, subprocess, sys, os, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
three_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ic/node_modules/three/build/three.min.js"  # three.js r128
out = os.path.join(tempfile.mkdtemp(), "theri_A.json")
subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "therizino_generator.py"), "--look", "A", "--json", out], stdout=subprocess.DEVNULL)
h = open(os.path.join(HERE, "therizino_parts_v2_head.html")).read().replace('<script>/*THREE*/</script>', '<script>/* three.js r128 (MIT), inlined so the page works offline / in previews */\n' + open(three_path).read() + '\n</script>')
js = open(os.path.join(HERE, "therizino_parts_v2_core.js")).read().replace("__THERI__", json.dumps(json.load(open(out)))) + "\n" + open(os.path.join(HERE, "therizino_parts_v2_looks.js")).read()
open(os.path.join(ROOT, "docs", "mockups", "therizino_parts_redesign.html"), "w").write(h + js + "\n</script>\n</body>\n</html>\n")
print("ok")
# artifact variant (published page): no document skeleton (the publisher adds it), three.js r128 from cdnjs
art = os.environ.get("ART_OUT")
if art:
    page = open(os.path.join(HERE, "therizino_parts_v2_head.html")).read()
    page = page.split("<head>", 1)[1].replace("</head>\n<body>\n", "").replace('<meta charset="utf-8">\n', "").replace('<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n', "")
    page = page.replace("<title>Therizino Parts Redesign</title>", '<title>Therizino Parts Redesign</title>\n<meta name="claude:viewport-fit-sides" content="cover">')
    page = page.replace('<script>/*THREE*/</script>', '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>')
    open(art, "w").write(page + js + "\n</script>\n")
    print("artifact", art)
