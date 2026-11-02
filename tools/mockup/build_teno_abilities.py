# Builds docs/mockups/teno_abilities_options.html: teno_abilities_head.html + teno_abilities_app.js + teno E export + herrera_model.json
import json, subprocess, sys, os, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
three_path = sys.argv[1]  # three.js r128 three.min.js
out = os.path.join(tempfile.mkdtemp(), "teno_E.json")
subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "teno_generator.py"), "--look", "E", "--json", out], stdout=subprocess.DEVNULL)
h = open(os.path.join(HERE, "teno_abilities_head.html")).read().replace('<script>/*THREE*/</script>', '<script>/* three.js r128 (MIT), inlined so the page works offline / in previews */\n' + open(three_path).read() + '\n</script>')
js = open(os.path.join(HERE, "teno_abilities_app.js")).read().replace("__TENO__", json.dumps(json.load(open(out)))).replace("__HERRERA__", json.dumps(json.load(open(os.path.join(HERE, "herrera_model.json")))))
open(os.path.join(ROOT, "docs", "mockups", "teno_abilities_options.html"), "w").write(h + js + "\n</script>\n</body>\n</html>\n")
print("built")
