# build.py v0.1 — Hardpoint point-look mockup: head.html + three.js r128 (inlined) + island grid + RAPTOR / TREX model JSON + app.js
# Usage: python3 build.py THREE_MIN_JS GRID_TXT RAPTOR_JSON TREX_JSON OUT_HTML
import sys, json
three, grid, rap, trex, out = sys.argv[1:6]
here = __file__.rsplit("/", 1)[0]
head = open(f"{here}/head.html").read().replace("<script>/*THREE*/</script>", "<script>/* three.js r128 (MIT), inlined so the page works offline */\n" + open(three).read() + "\n</script>")
data = "const GRID = `" + open(grid).read().strip() + "`;\nconst RAPTOR = " + json.dumps(json.load(open(rap))) + ";\nconst TREX = " + json.dumps(json.load(open(trex))) + ";\n"
open(out, "w").write(head + data + open(f"{here}/app.js").read() + "\n</script>\n</body>\n</html>\n")
print(out)
