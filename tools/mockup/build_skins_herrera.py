# Builds docs/mockups/herrera_skins_options.html from skins_herrera_head.html + skins_herrera_app.js + herrera_model.json
import json, sys
three_path = sys.argv[1] if len(sys.argv) > 1 else '/tmp/ic/node_modules/three/build/three.min.js'
h = open('skins_herrera_head.html').read()
three = open(three_path).read()
h = h.replace('<script>/*THREE*/</script>', '<script>/* three.js r128 (MIT), inlined so the page works offline / in previews */\n' + three + '\n</script>')
js = open('skins_herrera_app.js').read().replace('__DATA__', json.dumps(json.load(open('herrera_model.json'))))
open('../../docs/mockups/herrera_skins_options.html', 'w').write(h + js + '\n</script>\n</body>\n</html>\n')
print('built')
