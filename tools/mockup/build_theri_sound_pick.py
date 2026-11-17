# build_theri_sound_pick.py v0.1 (Mecha Dino Arena) — builds the Therizino sound pick page (MDA-552, sound pass round 9 v2):
# the Therizino move storyboard (therizino_moves_anim.js v0.5, game looks: Dash B Storm Core, Feather A Wing Volley,
# Deflector A Shield Wall, ring 16 studs) with an A / B / C sound panel per move. Picking an option restarts the move and
# plays each sound part at its beat; while a sound plays, the animation clock IS the audio clock (output latency
# subtracted), so what you see is what the game will do with the stamps.
# Beats (storyboard seconds = the game's stamp offsets, TheriPose 1.11 / TheriMovesFX2 1.2):
#   Reaper's Hook: fire 0.30 (claw flies, = TheriReelBrace), winch 0.52..1.00 (= +TheriReelFly, stopped at the finish),
#     slash 1.00 (= finish; claw back +0.22, clunk +0.50 are inside the clip).
#   Harvest Field: start 0 (slam 0.46, sickles 0.58 inside), loop 0.95..3.90 (TheriVortexStart..TheriFieldUntil), end 3.90.
#   Snare Wires: throw 0 (whirls, whip 0.50), hit 1.05 (TheriBolaEnd).
#   Dash: one clip at 0 (charge, jolt 0.16 = TheriDashDelay, landing 0.29, skid 0.42).
#   Feather Barrage: volley 0 (darts 0.42, blades back 1.2), hit 0.97 (each TheriVolleyLanded target).
#   Deflector Claws: up 0, loop 0.15..1.65 (..TheriDeflectUntil), block 0.55 and 1.10 (TheriDeflectBlockAt), down 1.65.
#   Overclock Joints: passive, no sound.
# Usage: python3 tools/mockup/build_theri_sound_pick.py <sound dir with meta.json + MDA_SFX_theri_*.wav> <out.html>
#   [three.min.js r128 path; omitted = cdnjs]. The sound files are not in the repo (Sonniss licence); the recipe is
#   docs/sfx/gen_theri_v2_sfx.py.
import base64, json, os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
snd_dir, out_path = sys.argv[1], sys.argv[2]
three_path = sys.argv[3] if len(sys.argv) > 3 else None
SR_PAGE = 32000  # WAV in the page (not MP3: no encoder delay, so every part starts on its beat in every browser)

tmp = tempfile.mkdtemp()
theri = os.path.join(tmp, "theri_A.json")
subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "therizino_generator.py"), "--look", "A", "--json", theri], stdout=subprocess.DEVNULL)
core = open(os.path.join(HERE, "therizino_parts_v2_core.js")).read().replace("__THERI__", json.dumps(json.load(open(theri))))
core = core.split("// ---------- page state ----------")[0]
looks = open(os.path.join(HERE, "therizino_parts_v2_looks.js")).read().split("// ============================================ the list")[0]
anim = open(os.path.join(HERE, "therizino_moves_anim.js")).read()
HOOK_OLD = "if (playing) { tt += dt * speed; if (tt > m.len) { tt = 0; fxOff(); } }"
assert HOOK_OLD in anim, "storyboard loop changed"
anim = anim.replace(HOOK_OLD, "if (window.__soundClock) { tt = window.__soundClock(m); } else " + HOOK_OLD)

meta = json.load(open(os.path.join(snd_dir, "meta.json")))
snd = {}
for mv, opts in meta.items():
    for opt, d in opts.items():
        parts = {}
        for part, v in d["parts"].items():
            w = os.path.join(tmp, v["file"])
            subprocess.check_call(["ffmpeg", "-v", "error", "-y", "-i", os.path.join(snd_dir, v["file"]), "-ar", str(SR_PAGE), "-ac", "1", "-c:a", "pcm_s16le", w])
            parts[part] = {"src": "data:audio/wav;base64," + base64.b64encode(open(w, "rb").read()).decode(), "len": v["len"], "loop": v["loop"]}
        snd.setdefault(mv, {})[opt] = {"desc": d["desc"], "parts": parts}

head = open(os.path.join(HERE, "therizino_moves_anim_head.html")).read()
head = head.split("<head>", 1)[1].replace("</head>\n<body>\n", "")
for s in ('<meta charset="utf-8">\n', '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'):
    head = head.replace(s, "")
head = head.replace("<title>Therizino Move Animations</title>", '<title>Sound Pick Board</title>\n<meta name="claude:viewport-fit-sides" content="cover">')
CSS = """
/* sound pick v0.1 */
#dashRow, #featherRow, #deflectRow, #clockRow, #sizeRow { display: none !important; }
.snd { background: var(--panel); border: 2px solid var(--accent); border-radius: 14px; padding: 12px 16px; display: grid; gap: 10px; min-width: 0; }
.snd h2 span { color: var(--accent); }
.opts { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px; }
@media (max-width: 720px) { .opts { grid-template-columns: minmax(0, 1fr); } }
.opt { text-align: left; font: 600 13px/1.4 var(--body); color: var(--grey); background: var(--card); border: 2px solid var(--line); border-radius: 12px; padding: 10px 12px; cursor: pointer; min-width: 0; }
.opt b { display: flex; align-items: center; gap: 8px; font: 700 17px/1.2 var(--display); color: var(--fg); margin-bottom: 4px; }
.opt b i { font: 800 11px var(--body); font-style: normal; letter-spacing: .06em; text-transform: uppercase; color: #1a0f00; background: var(--yellow); border-radius: 6px; padding: 1px 6px; visibility: hidden; }
.opt[aria-pressed="true"] { border-color: var(--yellow); box-shadow: 0 0 0 3px rgba(255,194,26,.2); }
.opt[aria-pressed="true"] b i { visibility: visible; }
.lane { position: relative; height: 0; }
.lanes { display: grid; gap: 3px; }
.trk { position: relative; height: 18px; background: var(--card); border-radius: 5px; overflow: hidden; }
.trk span { position: absolute; top: 0; bottom: 0; background: rgba(255,155,46,.35); border-left: 2px solid var(--accent); font: 800 10px/18px var(--body); color: var(--fg); padding-left: 4px; white-space: nowrap; overflow: hidden; }
.trk span.lp { background: repeating-linear-gradient(90deg, rgba(125,255,154,.28) 0 6px, rgba(125,255,154,.14) 6px 12px); border-left-color: var(--good); }
.trk em { position: absolute; top: 0; bottom: 0; width: 2px; background: var(--yellow); left: 0; }
.game { color: var(--muted); font-size: 13px; }
"""
head = head.replace("</style>", CSS + "</style>")
head = head.replace('<h1><span>Therizino</span> · move animations <span id="ver" style="color:var(--muted);font-size:.6em"></span></h1>',
                    '<h1><span>Therizino</span> · sounds on the real animation <span style="color:var(--muted);font-size:.6em">round 9 · v2</span><span id="ver" hidden></span></h1>')
lede_start = head.index('<p class="lede">')
lede_end = head.index("</p>", lede_start) + 4
head = head[:lede_start] + ('<p class="lede">Pick a move, then press an option. The move restarts and each sound plays on its beat, the way the game '
                            'will fire it from the move\'s own timing. The bars under the scrubber show where every sound part sits. '
                            'The looks are the ones in the game: Storm Core dash, Wing Volley, Shield Wall. Turn your sound on.</p>') + head[lede_end:]
PANEL = """  <section class="snd" id="snd" aria-label="Sound options">
    <div class="row" style="justify-content:space-between"><h2 id="sndTitle"></h2><span class="row"><button class="btn" id="sndLoop" aria-pressed="true">Repeat</button><button class="btn" id="sndStop">Stop sound</button></span></div>
    <div class="opts" id="opts"></div>
    <p class="game" id="sndGame"></p>
  </section>
"""
head = head.replace('  <input class="scrub" id="scrub"', PANEL + '  <input class="scrub" id="scrub"')
head = head.replace('  <div class="phases" id="phases"></div>', '  <div class="lanes" id="lanes"></div>\n  <div class="phases" id="phases"></div>')
three = ('<script>\n' + open(three_path).read() + '\n</script>') if three_path else '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>'
head = head.replace('<script>/*THREE*/</script>', three)

SOUND_JS = r"""
// ---------- sound pick v0.1 ----------
const SND = __SND__;
// [part, at, stopAt?] in storyboard seconds; a part listed twice plays twice
const PLAN = {
  hook: {mv: "reel", parts: [["fire", 0.30], ["winch", 0.52, 1.00], ["slash", 1.00]],
    game: "In the game: fire when the claw flies (Reel start + brace), the winch from the clamp until the slash (+ fly, stopped at the finish), the slash at the finish."},
  harvest: {mv: "vortex", parts: [["start", 0], ["loop", 0.95, 3.90], ["end", 3.90]],
    game: "In the game: start on the cast, the loop from when the ring starts spinning until the field ends (it stops on time even if the field is cut short), the end as the sickles fly back."},
  snare: {mv: "bola", parts: [["throw", 0], ["hit", 1.05]],
    game: "In the game: the throw on the cast, the hit when the bola lands (after its flight time), only if it caught someone."},
  dash: {mv: "dash", parts: [["dash", 0]],
    game: "In the game: one sound on the dash, built to the dash delay (0.16 s) and the dash time."},
  feather: {mv: "volley", parts: [["volley", 0], ["hit", 0.97]],
    game: "In the game: the volley on the cast, one hit at each target a dart lands on."},
  deflect: {mv: "deflect", parts: [["up", 0], ["loop", 0.15, 1.65], ["block", 0.55], ["block", 1.10], ["down", 1.65]],
    game: "In the game: up on the cast, the loop while the wall is up (stops when it ends), a block sound every time it blocks, down as it rolls back. Here a dart is blocked at 0.55 s and the boulder at 1.10 s."},
};
let actx = null, sndOpt = {}, sndLive = null, sndRepeat = true;
const bufs = {};
function ctxGet() { if (!actx) actx = new (window.AudioContext || window.webkitAudioContext)(); if (actx.state === "suspended") actx.resume(); return actx; }
async function buf(src) {
  if (!bufs[src]) bufs[src] = fetch(src).then(r => r.arrayBuffer()).then(a => new Promise((ok, no) => actx.decodeAudioData(a, ok, no)));
  return bufs[src];
}
function schedule(pl, set, t0, b) { // queue every part of one pass; returns the nodes so Stop can cut them
  const nodes = [];
  pl.parts.forEach(([p, at, stop]) => {
    const info = set.parts[p]; if (!info) return;
    const s = actx.createBufferSource(), g = actx.createGain();
    s.buffer = b[p]; s.connect(g); g.connect(actx.destination);
    const on = t0 + at;
    if (info.loop) { s.loop = true; g.gain.setValueAtTime(0, on); g.gain.linearRampToValueAtTime(0.85, on + 0.06); }
    s.start(Math.max(actx.currentTime, on), Math.max(0, actx.currentTime - on));
    if (stop != null) { const off = t0 + stop, f = info.loop ? 0.08 : 0.04; g.gain.setValueAtTime(info.loop ? 0.85 : 1, off - f); g.gain.linearRampToValueAtTime(0, off); s.stop(off + 0.01); }
    nodes.push(s);
  });
  return nodes;
}
function stopSound() {
  if (sndLive) { sndLive.nodes.forEach(n => { try { n.stop(); } catch (e) {} }); sndLive = null; }
  window.__soundClock = null;
  renderSnd();
}
async function playOpt(opt) {
  const m = MOVES[cur], pl = PLAN[m.id]; if (!pl) return;
  ctxGet(); stopSound();
  sndOpt[m.id] = opt; renderSnd();
  const set = SND[pl.mv][opt], b = {};
  await Promise.all(Object.keys(set.parts).map(async p => { b[p] = await buf(set.parts[p].src); }));
  if (MOVES[cur] !== m || sndOpt[m.id] !== opt) return;
  speed = 1; document.querySelectorAll("[data-speed]").forEach(x => x.setAttribute("aria-pressed", x.dataset.speed === "1"));
  playing = true; syncPlay(); tt = 0; fxOff();
  const lat = (actx.outputLatency || 0) + (actx.baseLatency || 0);
  const live = {m, pl, set, b, t0: actx.currentTime + 0.1, next: false, nodes: []};
  live.nodes = schedule(pl, set, live.t0, b);
  sndLive = live;
  window.__soundClock = mm => {
    if (!sndLive || mm !== live.m) return tt;
    let x = actx.currentTime - lat - live.t0;
    if (sndRepeat && !live.next && x > mm.len - 0.3) { live.nodes = live.nodes.concat(schedule(pl, set, live.t0 + mm.len, b)); live.next = true; }
    if (x >= mm.len) {
      if (!sndRepeat) { stopSound(); return 0; }
      live.t0 += mm.len; live.next = false; x -= mm.len; fxOff();
    }
    return Math.max(0, x);
  };
  renderSnd();
}
function renderSnd() {
  const m = MOVES[cur], pl = PLAN[m.id];
  $("sndTitle").innerHTML = `${m.name} <span>· sound</span>`;
  $("sndStop").hidden = !sndLive; $("sndLoop").hidden = !pl;
  if (!pl) { $("opts").innerHTML = `<p class="note">Overclock Joints is a passive: it has no sound.</p>`; $("sndGame").textContent = ""; $("lanes").innerHTML = ""; return; }
  $("opts").innerHTML = ["A", "B", "C"].map(o => { const d = SND[pl.mv][o].desc, i = d.indexOf(":"); return `<button class="opt" data-opt="${o}" aria-pressed="${!!sndLive && sndOpt[m.id] === o}"><b>${o} · ${d.slice(0, i)}<i>Playing</i></b>${d.slice(i + 1).trim()}</button>`; }).join("");
  $("sndGame").textContent = pl.game;
  const set = SND[pl.mv][sndOpt[m.id] || "A"];
  $("lanes").innerHTML = pl.parts.map(([p, at, stop]) => {
    const info = set.parts[p], end = stop != null ? stop : at + info.len;
    return `<div class="trk"><span class="${info.loop ? "lp" : ""}" style="left:${at / m.len * 100}%;width:${Math.max(0.6, (Math.min(end, m.len) - at) / m.len * 100)}%">${p} ${at.toFixed(2)} s</span><em></em></div>`;
  }).join("");
}
$("opts").addEventListener("click", e => { const b = e.target.closest("[data-opt]"); if (b) playOpt(b.dataset.opt); });
$("sndStop").onclick = stopSound;
$("sndLoop").onclick = () => { sndRepeat = !sndRepeat; $("sndLoop").setAttribute("aria-pressed", sndRepeat); };
["moves", "phases", "scrub", "play"].forEach(id => $(id).addEventListener(id === "scrub" ? "input" : "click", () => { if (sndLive) stopSound(); }, true));
$("moves").addEventListener("click", () => renderSnd()); // after the storyboard's own handler has switched the move
document.querySelectorAll("[data-speed]").forEach(b => b.addEventListener("click", () => { if (sndLive) stopSound(); }, true));
(function lanesHead() { document.querySelectorAll(".trk em").forEach(e => e.style.left = (tt / MOVES[cur].len * 100) + "%"); requestAnimationFrame(lanesHead); })();
// the game's looks
dashLook = "B"; featherLook = "A"; deflectLook = "A"; ringStuds = 16; buildRig();
cur = Math.max(0, MOVES.findIndex(mm => mm.id === "harvest")); tt = 0; fxOff(); renderMoves(); renderSnd();
"""
js = core + "\n" + looks + "\n" + anim + "\n" + SOUND_JS.replace("__SND__", json.dumps(snd))
open(out_path, "w").write(head + js + "\n</script>\n")
print("ok", out_path, round(os.path.getsize(out_path) / 1e6, 2), "MB")
