# build_teno_sound_pick.py v0.2 (Mecha Dino Arena) — builds the Teno sound pick page (MDA-552, sound pass round 10): the Teno
# move storyboard (teno_moves_anim.js v0.2, each move on the version in the game: Grab A Scorpion, Mortar A Anchored Shot, Stomp A
# Quake Smash, Bellow A Concussion Shriek, Challenge A Watcher Alarm, Leap A Piston Launch, Shield C Shield Pulse) with an
# A / B / C sound panel per move. Same page as build_theri_sound_pick.py 0.2: picking an option restarts the move and plays
# each part on its beat, and while a sound plays the animation clock IS the audio clock.
# The sound plan is in GAME seconds after the press (docs/sfx/TENO_BEATS_v1.0.md); the storyboard is shown through a time
# warp where it no longer matches the game (Mortar: the 1.17 fast shot, fire 0.35 and a ~0.25 s flight; Leap: lift-off 0.12,
# landing ~1.02; Grab: flight 0.6 s; Shield: the disc at 0.20), so the picture plays at the game's speed.
# Usage: python3 tools/mockup/build_teno_sound_pick.py <sound dir with meta.json + MDA_SFX_teno2_*.wav> <out.html>
#   [three.min.js r128 path; omitted = cdnjs].
# v0.2 (Kepu 2026-11-16 22:05 "Provide a way for me to just copy my selections through the mockup like before"): a Pick A / B / C
#   row per move and a bar at the bottom with every move's pick and a Copy button ("Grab A, Mortar B, ..."); picks are kept
#   in this browser (localStorage, best effort). Sounds are not in the repo (Sonniss licence); recipe docs/sfx/gen_teno_v2_sfx.py.
import base64, json, os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
snd_dir, out_path = sys.argv[1], sys.argv[2]
three_path = sys.argv[3] if len(sys.argv) > 3 else None
SR_PAGE = 32000  # WAV in the page (not MP3: no encoder delay, so every part starts on its beat in every browser)

tmp = tempfile.mkdtemp()
teno = os.path.join(tmp, "teno_E.json")
subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "teno_generator.py"), "--look", "E", "--json", teno], stdout=subprocess.DEVNULL)
core = open(os.path.join(HERE, "teno_parts_v2_core.js")).read().replace("__TENO__", json.dumps(json.load(open(teno))))
core = core.split("// ---------- page state ----------")[0]
looks = open(os.path.join(HERE, "teno_parts_v2_looks.js")).read().split("// ============================================ the list")[0]
anim = open(os.path.join(HERE, "teno_moves_anim.js")).read()
HOOK_OLD = "if (playing) { tt += dt * speed; if (tt > v.len) { tt = 0; reset(); } }"
assert HOOK_OLD in anim, "storyboard loop changed"
anim = anim.replace(HOOK_OLD, "if (window.__soundClock) { tt = window.__soundClock(v); } else " + HOOK_OLD)

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

head = open(os.path.join(HERE, "teno_moves_anim_head.html")).read()
head = head.split("<head>", 1)[1].replace("</head>\n<body>\n", "")
for s in ('<meta charset="utf-8">\n', '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'):
    head = head.replace(s, "")
head = head.replace("<title>Teno Move Animations</title>", '<title>Sound Pick Board</title>\n<meta name="claude:viewport-fit-sides" content="cover">')
CSS = """
/* sound pick v0.1 */
#varRow { display: none !important; }
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
.pickrow { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
.pk { font: 800 14px var(--body); color: var(--fg); background: var(--card); border: 2px solid var(--line); border-radius: 10px; padding: 6px 14px; cursor: pointer; }
.pk[aria-pressed="true"] { background: var(--good); border-color: var(--good); color: #062010; }
.picks { position: sticky; bottom: env(safe-area-inset-bottom, 0px); z-index: 5; display: flex; flex-wrap: wrap; gap: 10px; align-items: center; justify-content: space-between; background: var(--panel); border: 2px solid var(--good); border-radius: 14px; padding: 10px 14px; box-shadow: 0 -6px 24px rgba(0,0,0,.45); }
.picks code { font: 800 14px/1.4 var(--body); color: var(--fg); white-space: normal; overflow-wrap: anywhere; min-width: 0; flex: 1 1 260px; }
.picks small { color: var(--muted); font-weight: 700; }
"""
head = head.replace("</style>", CSS + "</style>")
head = head.replace('<h1><span>Teno</span> · move animations <span id="ver" style="color:var(--muted);font-size:.6em"></span></h1>',
                    '<h1><span>Teno</span> · sounds on the real animation <span style="color:var(--muted);font-size:.6em">round 10</span><span id="ver" hidden></span></h1>')
lede_start = head.index('<p class="lede">')
lede_end = head.index("</p>", lede_start) + 4
head = head[:lede_start] + ('<p class="lede">Pick a move, then press an option. The move restarts and each sound plays on its beat, the way the game '
                            'will fire it from the move\'s own timing. The bars under the scrubber show where every sound part sits. '
                            'Each move plays the version that is in the game, at the game\'s speed (the Mortar and the Leap '
                            'got faster since this storyboard was made, so they are sped up to match). Turn your sound on.</p>') + head[lede_end:]
PANEL = """  <section class="snd" id="snd" aria-label="Sound options">
    <div class="row" style="justify-content:space-between"><h2 id="sndTitle"></h2><span class="row"><button class="btn" id="sndLoop" aria-pressed="true">Repeat</button><button class="btn" id="sndStop">Stop sound</button></span></div>
    <div class="opts" id="opts"></div>
    <div class="pickrow" id="pickRow"></div>
    <p class="game" id="sndGame"></p>
  </section>
"""
head = head.replace('  <input class="scrub" id="scrub"', PANEL + '  <input class="scrub" id="scrub"')
head = head.replace('</main>', '  <div class="picks" id="picks" aria-live="polite"><code id="pickText"></code><button class="btn go" id="copyPicks">Copy picks</button></div>\n</main>', 1)
head = head.replace('  <div class="phases" id="phases"></div>', '  <div class="lanes" id="lanes"></div>\n  <div class="phases" id="phases"></div>')
three = ('<script>\n' + open(three_path).read() + '\n</script>') if three_path else '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>'
head = head.replace('<script>/*THREE*/</script>', three)

SOUND_JS = r"""
// ---------- sound pick v0.1 (Teno) ----------
const SND = __SND__;
const PICK = {tgrab: "A", tmortar: "A", tstomp: "A", tbellow: "A", tchallenge: "A", tleap: "A", tmud: "C"}; // the game's versions
// game seconds after the press -> storyboard seconds: points [g, sb]; slope 1 before the first and after the last
const WARP = {
  tgrab_front: [[0, 0.3], [1.15, 1.45], [1.75, 1.95]], tgrab_back: [[0, 0.3], [1.0, 1.3], [1.6, 1.8]],
  tmortar: [[0, 0.3], [0.35, 1.0], [0.6, 2.1]], tleap: [[0, 0.3], [0.12, 0.6], [1.02, 1.55]], tmud: [[0, 0.3], [0.2, 0.45]],
  def: [[0, 0.3]],
};
// [part, at, stopAt?] in GAME seconds after the press; a part listed twice plays twice
const PLAN = {
  tgrab: {mv: "grab", parts: s => s === "front" ? [["wind", 0], ["snap", 0.40], ["throw", 1.00], ["land", 1.75]] : [["wind", 0], ["snap", 0.25], ["throw", 0.85], ["land", 1.60]],
    game: "In the game: the wind-up on the press, the snap 0.15 s before the catch (front 0.55 s, behind 0.40 s), the throw 0.15 s before the release, the landing where the dino hits the ground."},
  tmortar: {mv: "mortar", parts: () => [["brace", 0], ["fire", 0.35], ["boom", 0.60]],
    game: "In the game: the brace on the press, the fire when the boulder leaves (0.35 s), the boom where it lands (~0.25 s later, longer for far shots)."},
  tstomp: {mv: "stomp", parts: () => [["rear", 0], ["smash", 0.60]],
    game: "In the game: the rear-up on the press, the smash on the hit (0.60 s)."},
  tbellow: {mv: "bellow", parts: () => [["inhale", 0], ["shriek", 0.40]],
    game: "In the game: the inhale on the press, the shriek as the head thrusts forward (0.40 s; the call lands at 0.50 s)."},
  tchallenge: {mv: "challenge", parts: () => [["call", 0]],
    game: "In the game: one sound on the press: the head snap, the scan from 0.20 s, the alarm at 0.65 s."},
  tleap: {mv: "leap", parts: () => [["launch", 0.12], ["land", 1.02]],
    game: "In the game: the launch on the lift-off, the landing on the touchdown (the tail slams 0.12 s later). Here the jump lasts 0.9 s; a real jump's length varies."},
  tmud: {mv: "shield", parts: () => [["up", 0], ["loop", 0.20, 2.25], ["block", 1.15], ["block", 1.65], ["block", 2.25], ["down", 2.25]],
    game: "In the game: up on the press, the hum from when the shield is on (0.20 s) until it ends, a block sound on every blocked hit, down when it ends (8 s, or the 3rd block, as here)."},
};
function warpPts() { const id = M().id; return WARP[id === "tgrab" ? "tgrab_" + side : id] || WARP.def; }
function warp(g, P) { P = P || warpPts(); if (g <= P[0][0]) return P[0][1] + (g - P[0][0]); for (let i = 1; i < P.length; i++) if (g <= P[i][0]) { const [g0, s0] = P[i - 1], [g1, s1] = P[i]; return s0 + (g - g0) / (g1 - g0) * (s1 - s0); } const L = P[P.length - 1]; return L[1] + (g - L[0]); }
function unwarp(sb, P) { P = P || warpPts(); if (sb <= P[0][1]) return P[0][0] + (sb - P[0][1]); for (let i = 1; i < P.length; i++) if (sb <= P[i][1]) { const [g0, s0] = P[i - 1], [g1, s1] = P[i]; return g0 + (sb - s0) / (s1 - s0) * (g1 - g0); } const L = P[P.length - 1]; return L[0] + (sb - L[1]); }
let actx = null, sndOpt = {}, sndLive = null, sndRepeat = true;
const bufs = {};
function ctxGet() { if (!actx) actx = new (window.AudioContext || window.webkitAudioContext)(); if (actx.state === "suspended") actx.resume(); return actx; }
async function buf(src) {
  if (!bufs[src]) { // decoded from the base64 here (the artifact's CSP blocks fetch() of data: URLs)
    const bin = atob(src.slice(src.indexOf(",") + 1)), u = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i);
    bufs[src] = new Promise((ok, no) => actx.decodeAudioData(u.buffer, ok, no));
  }
  return bufs[src];
}
function schedule(parts, set, t0, b) { // t0 = the audio time of the press
  const nodes = [];
  parts.forEach(([p, at, stop]) => {
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
  const m = M(), pl = PLAN[m.id]; if (!pl) return;
  ctxGet(); stopSound();
  sndOpt[m.id] = opt; renderSnd();
  const set = SND[pl.mv][opt], b = {};
  await Promise.all(Object.keys(set.parts).map(async p => { b[p] = await buf(set.parts[p].src); }));
  if (M() !== m || sndOpt[m.id] !== opt) return;
  speed = 1; document.querySelectorAll("[data-speed]").forEach(x => x.setAttribute("aria-pressed", x.dataset.speed === "1"));
  playing = true; syncPlay(); tt = 0; reset();
  const lat = (actx.outputLatency || 0) + (actx.baseLatency || 0);
  const P = warpPts(), parts = pl.parts(side), gStart = unwarp(0, P), gEnd = unwarp(VV().len, P), cycle = gEnd - gStart;
  const live = {m, t0: actx.currentTime + 0.1 - gStart, next: false, nodes: []}; // t0 = when the press plays
  live.nodes = schedule(parts, set, live.t0, b);
  sndLive = live;
  window.__soundClock = v => {
    if (!sndLive || M() !== live.m) return tt;
    let g = actx.currentTime - lat - live.t0;
    if (sndRepeat && !live.next && g > gEnd - 0.3) { live.nodes = live.nodes.concat(schedule(parts, set, live.t0 + cycle, b)); live.next = true; }
    if (g >= gEnd) {
      if (!sndRepeat) { stopSound(); return 0; }
      live.t0 += cycle; live.next = false; g -= cycle; reset();
    }
    return Math.max(0, warp(g, P));
  };
  renderSnd();
}
function renderSnd() {
  const m = M(), pl = PLAN[m.id];
  $("sndTitle").innerHTML = `${m.name} <span>· sound</span>`;
  $("sndStop").hidden = !sndLive;
  $("opts").innerHTML = ["A", "B", "C"].map(o => { const d = SND[pl.mv][o].desc, i = d.indexOf(":"); return `<button class="opt" data-opt="${o}" aria-pressed="${!!sndLive && sndOpt[m.id] === o}"><b>${o} · ${d.slice(0, i)}<i>Playing</i></b>${d.slice(i + 1).trim()}</button>`; }).join("");
  $("sndGame").textContent = pl.game;
  const set = SND[pl.mv][sndOpt[m.id] || "A"], len = VV().len, P = warpPts();
  $("lanes").innerHTML = pl.parts(side).map(([p, at, stop]) => {
    const info = set.parts[p], a = warp(at, P), e = Math.min(len, warp(stop != null ? stop : at + info.len, P));
    return `<div class="trk"><span class="${info.loop ? "lp" : ""}" style="left:${a / len * 100}%;width:${Math.max(0.6, (e - a) / len * 100)}%">${p} ${at.toFixed(2)} s</span><em></em></div>`;
  }).join("");
}
// v0.2 picks + copy
const PICK_NAME = {tgrab: "Grab", tmortar: "Mortar", tstomp: "Stomp", tbellow: "Bellow", tchallenge: "Challenge", tleap: "Leap", tmud: "Shield"};
const PICK_KEY = "mda_teno_sound_picks_r10";
let myPicks = {};
try { myPicks = JSON.parse(localStorage.getItem(PICK_KEY) || "{}") || {}; } catch (e) { myPicks = {}; }
function pickText() { return MOVES.map(mm => `${PICK_NAME[mm.id]} ${myPicks[mm.id] || "?"}`).join(", "); }
function renderPicks() {
  const id = M().id, n = MOVES.filter(mm => myPicks[mm.id]).length;
  $("pickRow").innerHTML = `<span class="lbl">Your pick for ${PICK_NAME[id]}</span>` + ["A", "B", "C"].map(o => `<button class="pk" data-pick="${o}" aria-pressed="${myPicks[id] === o}">${o}</button>`).join("");
  $("pickText").innerHTML = `<span id="pickStr">${pickText()}</span> <small>· ${n} of ${MOVES.length} picked</small>`;
}
$("pickRow").addEventListener("click", e => { const b = e.target.closest("[data-pick]"); if (!b) return; myPicks[M().id] = b.dataset.pick; try { localStorage.setItem(PICK_KEY, JSON.stringify(myPicks)); } catch (err) {} renderPicks(); });
$("copyPicks").addEventListener("click", () => {
  const txt = pickText(), btn = $("copyPicks");
  const done = ok => { btn.textContent = ok ? "Copied ✓" : "Select + copy the text"; setTimeout(() => { btn.textContent = "Copy picks"; }, 1800); };
  const fallback = () => { const r = document.createRange(); r.selectNodeContents($("pickStr")); const sel = getSelection(); sel.removeAllRanges(); sel.addRange(r); let ok = false; try { ok = document.execCommand("copy"); } catch (err) {} done(ok); };
  try { navigator.clipboard.writeText(txt).then(() => done(true), fallback); } catch (err) { fallback(); }
});
function usePick() { variant = PICK[M().id] || "A"; tt = 0; reset(); renderAll(); renderSnd(); renderPicks(); }
$("opts").addEventListener("click", e => { const b = e.target.closest("[data-opt]"); if (b) playOpt(b.dataset.opt).catch(err => { $("sndGame").textContent = "Sound failed to start: " + err; }); });
$("sndStop").onclick = stopSound;
$("sndLoop").onclick = () => { sndRepeat = !sndRepeat; $("sndLoop").setAttribute("aria-pressed", sndRepeat); };
["moves", "phases", "scrub", "play"].forEach(id => $(id).addEventListener(id === "scrub" ? "input" : "click", () => { if (sndLive) stopSound(); }, true));
document.querySelectorAll("[data-speed], [data-side]").forEach(b => b.addEventListener("click", () => { if (sndLive) stopSound(); }, true));
$("moves").addEventListener("click", usePick); // after the storyboard's own handler has switched the move
document.querySelectorAll("[data-side]").forEach(b => b.addEventListener("click", () => renderSnd()));
(function lanesHead() { document.querySelectorAll(".trk em").forEach(e => e.style.left = (tt / VV().len * 100) + "%"); requestAnimationFrame(lanesHead); })();
cur = 0; side = "front"; usePick();
"""
js = core + "\n" + looks + "\n" + anim + "\n" + SOUND_JS.replace("__SND__", json.dumps(snd))
open(out_path, "w").write(head + js + "\n</script>\n")
print("ok", out_path, round(os.path.getsize(out_path) / 1e6, 2), "MB")
