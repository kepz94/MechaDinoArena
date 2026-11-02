# Builds docs/mockups/dino_roster.html: roster_head.html + roster_app.js + every model's model_json.py export + roster meta.
# Run from tools/mockup: python3 build_roster.py <three.min.js>
import json, subprocess, sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
three_path = sys.argv[1] if len(sys.argv) > 1 else '/tmp/ic/node_modules/three/build/three.min.js'
os.makedirs("/tmp/roster", exist_ok=True)
# roster meta (docs/ROSTER.md 1.18): in-game scale (T-Rex 1, every other dino doubled), role, status, HP / run speed where set
META = [
    ("TRex", "T-Rex", "Tyrannosaurus rex", "The heavy", True, 200, 44, 1,
     "The heavy hitter: bite and roar. The biggest playable dino, the starting dino."),
    ("Raptor", "Raptor", "Velociraptor (movie-style raptor)", "Pounce / latch hunter", True, 60, 78, 2,
     "Fast pack hunter that pounces and latches on."),
    ("Pachy", "Pachy", "Pachycephalosaurus", "Headbutt / ram", True, 90, 56.9, 2,
     "Dome-headed rammer: headbutts and charges."),
    ("Herrera", "Herrera", "Herrerasaurus", "Utility / hit-and-run", True, 40, 90, 2,
     "\"A pain to deal with but easy to kill\": the most mecha utility and the fastest dino; hit-and-run slash, climbs."),
    ("Teno", "Teno", "Tenontosaurus", "Tank", True, 150, 52, 2,
     "The tank: scratch up front, rear tail slam behind, on four legs with a huge tail."),
    ("Troodon", "Troodon", "Troodon (Night Watcher)", "Skirmisher", False, None, None, 2,
     "Night Watcher: dusk grey-brown, big orange eyes, full feather coat, long drooping arms, raised sickle claws."),
    ("Therizino", "Therizino", "Therizinosaurus (Reaper)", "Slasher", False, None, None, 2,
     "Reaper: tall and gaunt, ragged feather cloak, skull-like hooked beak, the longest scythe claws held out wide."),
    ("Zuul", "Zuul", "Zuul (Battering Ram)", "Counter-attacker", False, None, None, 2,
     "Battering Ram: high armoured shoulders with huge forward spikes, keeled plates, brow horns, a spiked mace tail."),
    ("Dilo", "Dilo", "Dilophosaurus (Bruiser face)", "Ranged spitter", False, None, None, 2,
     "Thick-bodied with a red and yellow split hood frill, a wide Bruiser face with a heavy brow, twin crests and a venom throat sac."),
]
dinos = []
for key, name, full, role, live, hp, speed, scale, blurb in META:
    src = os.path.join(ROOT, "src", "shared", "Models", f"{key}ModelData.luau")
    out = f"/tmp/roster/{key}.json"
    subprocess.check_call([sys.executable, "model_json.py", src, out], stdout=subprocess.DEVNULL)
    ver = open(src).readline().split(" v", 1)[1].split(" ", 1)[0]
    dinos.append({"key": key, "name": name, "full": full, "role": role, "live": live, "hp": hp, "speed": speed, "scale": scale,
                  "blurb": blurb, "file": f"{key}ModelData", "version": ver, "model": json.load(open(out))})
h = open("roster_head.html").read().replace('<script>/*THREE*/</script>', '<script>/* three.js r128 (MIT), inlined so the page works offline / in previews */\n' + open(three_path).read() + '\n</script>')
js = open("roster_app.js").read().replace("__DINOS__", json.dumps(dinos))
open(os.path.join(ROOT, "docs", "mockups", "dino_roster.html"), "w").write(h + js + "\n</script>\n</body>\n</html>\n")
print("built", len(dinos))
