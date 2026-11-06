# build_herrera_parts_v2.py v0.1 (Mecha Dino Arena) — builds docs/mockups/herrera_parts_redesign.html (Herrerasaurus mecha
# parts REDESIGN mockup; Kepu 2026-11-05 19:10 "Next it looks good" -> "Herrera looks + animations").
# Usage: python3 tools/mockup/build_herrera_parts_v2.py [path/to/three.min.js (r128)]; ART_OUT=<file> also writes the artifact page.
# Needs lupa (pip install lupa) for the "Now" looks (herrera_old_parts.py runs HerreraPartsServer's piece functions).
import json, subprocess, sys, os, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
three_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ic/node_modules/three/build/three.min.js"  # three.js r128
tmp = tempfile.mkdtemp(); model, old = os.path.join(tmp, "herr.json"), os.path.join(tmp, "old.json")
subprocess.check_call([sys.executable, os.path.join(HERE, "model_json.py"), os.path.join(ROOT, "src", "shared", "Models", "HerreraModelData.luau"), model], stdout=subprocess.DEVNULL)
subprocess.check_call([sys.executable, os.path.join(HERE, "herrera_old_parts.py"), os.path.join(ROOT, "src", "server", "HerreraPartsServer.server.luau"), model, old], stdout=subprocess.DEVNULL)
h = open(os.path.join(HERE, "herrera_parts_v2_head.html")).read().replace('<script>/*THREE*/</script>', '<script>/* three.js r128 (MIT), inlined so the page works offline / in previews */\n' + open(three_path).read() + '\n</script>')
js = open(os.path.join(HERE, "herrera_parts_v2_core.js")).read().replace("__HERR__", json.dumps(json.load(open(model)))).replace("__OLDP__", json.dumps(json.load(open(old)))) + "\n" + open(os.path.join(HERE, "herrera_parts_v2_looks.js")).read()
open(os.path.join(ROOT, "docs", "mockups", "herrera_parts_redesign.html"), "w").write(h + js + "\n</script>\n</body>\n</html>\n")
print("ok")
art = os.environ.get("ART_OUT")
if art:
    page = open(os.path.join(HERE, "herrera_parts_v2_head.html")).read()
    page = page.split("<head>", 1)[1].replace("</head>\n<body>\n", "").replace('<meta charset="utf-8">\n', "").replace('<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n', "")
    page = page.replace("<title>Herrera Parts Redesign</title>", '<title>Herrera Parts Redesign</title>\n<meta name="claude:viewport-fit-sides" content="cover">')
    page = page.replace('<script>/*THREE*/</script>', '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>')
    open(art, "w").write(page + js + "\n</script>\n")
    print("artifact", art)
