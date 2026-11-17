# build_pachy_sound_pick.py v0.6 (Mecha Dino Arena) — builds the Pachy sound pick page (MDA-552, sound pass round 11): the Pachy
# move storyboard (pachy_moves_anim.js, every move on its A version, the one in the game: Kepu 2026-11-05 "A for everything")
# with an A / B / C sound panel per move, a pick row and the copy-picks bar (as build_teno_sound_pick.py 0.2). Picking an
# option restarts the move and plays each part on its beat; while a sound plays, the storyboard is stepped to the audio clock
# (output latency subtracted; hit-stops are skipped so the picture can't fall behind the sound).
# Beats: docs/sfx/PACHY_BEATS_v1.0.md. Moves with no sound in this pass (Headbutt, Leap, Last Stand, Head Down) say so.
# Usage: python3 tools/mockup/build_pachy_sound_pick.py <sound dir with meta.json + MDA_SFX_pachy2_*.wav> <out.html>
#   [three.min.js r128 path; omitted = cdnjs].
# v0.2 (Kepu 2026-11-17 10:58 "i dont hear it on the mockup you sent"): the Headbutt plays the hit Kepu sent (GameSounds 1.11
#   phbhit) at the storyboard's hit (0.60 s); a move offers the options its sound set has (the headbutt has one).
# v0.3 (Kepu 2026-11-17 11:06 "use that for jump"): the Leap plays the 8-bit jump Kepu sent (GameSounds 1.12 pjump) at the
#   lift-off (0.12 s); the double jump (0.42 s) stays silent.
# v0.4 (Kepu 2026-11-17 11:13 "the double jump should have the jump sound just play again"): the jump plays again at the
#   double jump (0.42 s), GameSounds 1.13.
# v0.5 (Kepu 2026-11-17 11:17 hook C + "add the headbutt sound at the end when the dino is reeled in"): every hook option
#   ends with the headbutt hit at the smash (0.786 s), GameSounds 1.14.
# v0.6 (Kepu 2026-11-17 11:31 "It has dust and steam but not a fucking skid to a stop like the animation"): the dash's end part
#   is a steam hiss (+ dust), not a skid; the storyboard's skid-to-a-stop is not what the game shows. Sounds are not in the repo (Sonniss licence); recipe docs/sfx/gen_pachy_v2_sfx.py.
import base64, json, os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
snd_dir, out_path = sys.argv[1], sys.argv[2]
three_path = sys.argv[3] if len(sys.argv) > 3 else None
SR_PAGE = 32000
tmp = tempfile.mkdtemp(); model = os.path.join(tmp, "pachy.json")
subprocess.check_call([sys.executable, os.path.join(HERE, "model_json.py"), os.path.join(ROOT, "src", "shared", "Models", "PachyModelData.luau"), model], stdout=subprocess.DEVNULL)
engine = open(os.path.join(ROOT, "tools", "dilo_kit_mockup", "app.js")).read().split("// ---------- moves ----------")[0]
data = "const DILO = " + json.dumps(json.load(open(model))) + ";\nconst RAPTOR = " + json.dumps(json.load(open(os.path.join(HERE, "raptor_model.json")))) + ";\n"
pj = json.load(open(os.path.join(HERE, "pachy_parts.json")))
def seg_anchor(pc):
    a = pc["anchor"]
    if a.endswith(".Root"): return {"seg": a[:-5], "anchor": None}
    return {"anchor": a}
PARTS = {"camSide": 1}
for s_, d_ in [("hookArm", "hook"), ("servoDash", "servodash"), ("inkShooter", "ink"), ("tether", "tether"), ("bloodVials", "bloodvial"), ("domeVisor", "visor"), ("mechaLegs", "mechalegs")]:
    P = pj[s_]; PARTS[d_] = {"pieces": [dict(pc, **seg_anchor(pc)) for pc in P["pieces"]]}
PARTS["hook"]["hidden"] = pj["hookArm"]["hiddenBodyParts"]
med = []
for pc in pj["medStation"]["pieces"]:
    q = dict(pc)
    if pc["n"] in ("Base", "Rim", "Core"): q["size"] = [v * 2 for v in pc["size"]]; q["pos"] = [v * 2 for v in pc["pos"]]
    med.append(q)
PARTS["medstation"] = {"pieces": med, "world": True}
anim = open(os.path.join(HERE, "pachy_moves_anim.js")).read()
HOOK_OLD = "if (playing && !window.__manual) { step(dt); if (play.t >= VV().len) start(); }"
assert HOOK_OLD in anim, "storyboard loop changed"
anim = anim.replace(HOOK_OLD, "if (window.__soundClock) { const want = window.__soundClock(); if (want < play.t - 1e-3) start(); hitStop = 0; let g = want - play.t, n = 0; while (g > 1 / 30 && n++ < 150) { step(1 / 30, true); hitStop = 0; g = want - play.t; } step(Math.max(0, g)); hitStop = 0; } else " + HOOK_OLD)
anim = "const PARTS_DATA = " + json.dumps(PARTS) + ";\n" + anim
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

head = open(os.path.join(HERE, "pachy_moves_anim_head.html")).read()
head = head.split("<head>", 1)[1].replace("</head>\n<body>\n", "")
for s_ in ('<meta charset="utf-8">\n', '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'):
    head = head.replace(s_, "")
head = head.replace("<title>Pachy Move Animations</title>", '<title>Sound Pick Board</title>\n<meta name="claude:viewport-fit-sides" content="cover">')
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
head = head.replace('<h1><span>Pachy</span> · move animations <span id="ver" style="color:var(--muted);font-size:.6em"></span></h1>',
                    '<h1><span>Pachy</span> · sounds on the real animation <span style="color:var(--muted);font-size:.6em">round 11</span><span id="ver" hidden></span></h1>')
lede_start = head.index('<p class="lede">')
lede_end = head.index("</p>", lede_start) + 4
head = head[:lede_start] + ('<p class="lede">Pick a move, then press an option. The move restarts and each sound plays on its beat, the way the game '
                            'will fire it from the move\'s own timing. The bars under the scrubber show where every sound part sits. '
                            'Each move plays its A version, the one in the game. Mark your pick under the options; the bar at the bottom '
                            'copies all of them. Turn your sound on.</p>') + head[lede_end:]
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
assert '#varRow' in CSS
three = ('<script>\n' + open(three_path).read() + '\n</script>') if three_path else '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>'
head = head.replace('<script>/*THREE*/</script>', three)
SOUND_JS = r"""
// ---------- sound pick v0.1 (Pachy) ----------
const SND = __SND__;
// game seconds after the press = storyboard seconds (every move plays its A version, the one in the game)
// [part, at, stopAt?]; a part listed twice plays twice
const PLAN = {
  headbutt: {mv: "headbutt", parts: () => [["hit", 0.60]],
    game: "In the game: on the hit (HeadbuttHitAt), heard by everyone nearby. The old built-in thud still plays under it. Wind-up and charge have no sound yet."},
  leap: {mv: "leap", parts: () => [["jump", J_T0], ["jump", DJ]],
    game: "In the game: at the lift-off (the press + the 0.12 s crouch), and again the moment the double jump fires, heard by everyone nearby."},
  hook: {mv: "hook", parts: () => [["fire", 0], ["reel", 0.286, 0.786], ["smash", 0.786]],
    game: "In the game: the fire 0.15 s before the claw flies (the brace), the reel from when the claw grabs until the head smash, and your headbutt hit on the smash. Here the target is 30 studs away."},
  servodash: {mv: "dash", parts: () => [["blast", 0], ["burn", 0.31, 1.31], ["steam", 1.31]],
    game: "In the game: the blast on the squat (it kicks off 0.06 s in), the burn while it sprints, a steam hiss when the dash ends (the game shows dust and steam there; this storyboard's skid-to-a-stop is not in the game)."},
  visor: {mv: "visor", parts: () => [["up", 0], ["field", 0.10, 1.60], ["block", 0.80], ["down", 1.60]],
    game: "In the game: up on the press (the panels slam in at 0.10 s), the hum while the field is up, a block sound on every blocked hit, down when it ends."},
  ink: {mv: "ink", parts: () => [["fire", 0], ["splat", 0.325]],
    game: "In the game: the pump on the press and the shot at 0.10 s, the splat where the ink lands (farther shots land later)."},
  tether: {mv: "tether", parts: () => [["cock", 0], ["throw", 0.5], ["land", 1.3]],
    game: "In the game: the cock when you start aiming, the throw when you let go, the landing where the spike hits (0.8 s later). Here the aim is held 0.5 s."},
  bloodrush: {mv: "blood", parts: () => [["pact", 0]],
    game: "In the game: on the press, inside the headbutt's 0.15 s wind-up; the headbutt itself keeps its own sounds."},
  medstation: {mv: "med", parts: () => [["drop", 0], ["hum", 0.60, 3.30], ["fold", 3.30]],
    game: "In the game: the drop on the press (it lands at 0.30 s), the hum while it heals, the fold when it ends. Here it runs 2.7 s; in the game it runs its full time."},
};
const NOSOUND = {
  laststand: "Last Stand is a passive: no sound in this pass.", headdown: "Head Down is a passive: no sound in this pass."};
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
  playing = true; syncPlay(); start();
  const lat = (actx.outputLatency || 0) + (actx.baseLatency || 0);
  const parts = pl.parts(), cycle = VV().len;
  const live = {m, t0: actx.currentTime + 0.1, next: false, nodes: []}; // t0 = when the press plays
  live.nodes = schedule(parts, set, live.t0, b);
  sndLive = live;
  window.__soundClock = () => {
    if (!sndLive || M() !== live.m) return play.t;
    let g = actx.currentTime - lat - live.t0;
    if (sndRepeat && !live.next && g > cycle - 0.3) { live.nodes = live.nodes.concat(schedule(parts, set, live.t0 + cycle, b)); live.next = true; }
    if (g >= cycle) {
      if (!sndRepeat) { stopSound(); return 0; }
      live.t0 += cycle; live.next = false; g -= cycle;
    }
    return Math.max(0, g);
  };
  renderSnd();
}
function renderSnd() {
  const m = M(), pl = PLAN[m.id];
  $("sndTitle").innerHTML = `${m.name} <span>· sound</span>`;
  $("sndStop").hidden = !sndLive; $("sndLoop").hidden = !pl; $("pickRow").hidden = !pl;
  if (!pl) { $("opts").innerHTML = `<p class="note">${NOSOUND[m.id] || "No sound in this pass."}</p>`; $("sndGame").textContent = ""; $("lanes").innerHTML = ""; return; }
  $("opts").innerHTML = Object.keys(SND[pl.mv]).sort().map(o => { const d = SND[pl.mv][o].desc, i = d.indexOf(":"); return `<button class="opt" data-opt="${o}" aria-pressed="${!!sndLive && sndOpt[m.id] === o}"><b>${o} · ${d.slice(0, i)}<i>Playing</i></b>${d.slice(i + 1).trim()}</button>`; }).join("");
  $("sndGame").textContent = pl.game;
  const set = SND[pl.mv][sndOpt[m.id] || "A"], len = VV().len;
  $("lanes").innerHTML = pl.parts().map(([p, at, stop]) => {
    const info = set.parts[p], e = Math.min(len, stop != null ? stop : at + info.len);
    return `<div class="trk"><span class="${info.loop ? "lp" : ""}" style="left:${at / len * 100}%;width:${Math.max(0.6, (e - at) / len * 100)}%">${p} ${at.toFixed(2)} s</span><em></em></div>`;
  }).join("");
}
// v0.2 picks + copy
const PICK_NAME = {headbutt: "Headbutt", leap: "Jump", hook: "Hook", servodash: "Dash", visor: "Visor", ink: "Ink", tether: "Tether", bloodrush: "Blood Rush", medstation: "Med"};
const PICK_MOVES = () => MOVES.filter(mm => PLAN[mm.id]);
const PICK_KEY = "mda_pachy_sound_picks_r11";
let myPicks = {};
try { myPicks = JSON.parse(localStorage.getItem(PICK_KEY) || "{}") || {}; } catch (e) { myPicks = {}; }
function pickText() { return PICK_MOVES().map(mm => `${PICK_NAME[mm.id]} ${myPicks[mm.id] || "?"}`).join(", "); }
function renderPicks() {
  const id = M().id, n = PICK_MOVES().filter(mm => myPicks[mm.id]).length;
  if (!PLAN[id]) { $("pickRow").innerHTML = ""; }
  if (PLAN[id]) $("pickRow").innerHTML = `<span class="lbl">Your pick for ${PICK_NAME[id]}</span>` + Object.keys(SND[PLAN[id].mv]).sort().map(o => `<button class="pk" data-pick="${o}" aria-pressed="${myPicks[id] === o}">${o}</button>`).join("");
  $("pickText").innerHTML = `<span id="pickStr">${pickText()}</span> <small>· ${n} of ${PICK_MOVES().length} picked</small>`;
}
$("pickRow").addEventListener("click", e => { const b = e.target.closest("[data-pick]"); if (!b || !PLAN[M().id]) return; myPicks[M().id] = b.dataset.pick; try { localStorage.setItem(PICK_KEY, JSON.stringify(myPicks)); } catch (err) {} renderPicks(); });
$("copyPicks").addEventListener("click", () => {
  const txt = pickText(), btn = $("copyPicks");
  const done = ok => { btn.textContent = ok ? "Copied ✓" : "Select + copy the text"; setTimeout(() => { btn.textContent = "Copy picks"; }, 1800); };
  const fallback = () => { const r = document.createRange(); r.selectNodeContents($("pickStr")); const sel = getSelection(); sel.removeAllRanges(); sel.addRange(r); let ok = false; try { ok = document.execCommand("copy"); } catch (err) {} done(ok); };
  try { navigator.clipboard.writeText(txt).then(() => done(true), fallback); } catch (err) { fallback(); }
});
function usePick() { variant = "A"; renderAll(); start(); renderSnd(); renderPicks(); }
$("opts").addEventListener("click", e => { const b = e.target.closest("[data-opt]"); if (b) playOpt(b.dataset.opt).catch(err => { $("sndGame").textContent = "Sound failed to start: " + err; }); });
$("sndStop").onclick = stopSound;
$("sndLoop").onclick = () => { sndRepeat = !sndRepeat; $("sndLoop").setAttribute("aria-pressed", sndRepeat); };
["moves", "phases", "scrub", "play"].forEach(id => $(id).addEventListener(id === "scrub" ? "input" : "click", () => { if (sndLive) stopSound(); }, true));
document.querySelectorAll("[data-speed]").forEach(b => b.addEventListener("click", () => { if (sndLive) stopSound(); }, true));
$("moves").addEventListener("click", usePick); // after the storyboard's own handler has switched the move
(function lanesHead() { document.querySelectorAll(".trk em").forEach(e => e.style.left = (play.t / VV().len * 100) + "%"); requestAnimationFrame(lanesHead); })();
cur = Math.max(0, MOVES.findIndex(mm => mm.id === "hook")); usePick();
"""
js = data + engine + "\n" + anim + "\n" + SOUND_JS.replace("__SND__", json.dumps(snd))
open(out_path, "w").write(head + js + "\n</script>\n")
print("ok", out_path, round(os.path.getsize(out_path) / 1e6, 2), "MB")
