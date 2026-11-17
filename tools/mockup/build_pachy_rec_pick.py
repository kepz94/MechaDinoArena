# build_pachy_rec_pick.py v1.0 (Mecha Dino Arena) — builds the Pachy sound pick page on the game's own animation (MDA-552,
# sound pass round 11; Kepu 2026-11-17 11:36 "How about you actually use the fucking animation from the game").
# The picture is a recording of each move made in Studio from the live game (place build v867: every part of the Pachy, the
# target bot and the effects, 30 times a second; tools/studio/move_recorder.luau -> tools/mockup/rec_pack.py ->
# tools/mockup/pachy_rec/<move>.json), played by pachy_rec_player.js. The sound parts sit on the beats the same recording
# stamped (the attributes GameSounds 1.14 plays from), not on storyboard times. Same sound panel, pick row and copy bar as
# build_pachy_sound_pick.py 0.7 (the storyboard version, kept); same saved picks (localStorage mda_pachy_sound_picks_r11).
# Last Stand and Head Down are passives with no sound in this pass: not on this page.
# Usage: python3 tools/mockup/build_pachy_rec_pick.py <sound dir with meta.json + wavs> <out.html> [three.min.js r128 path]
# Sounds are not in the repo (Sonniss / Kepu's files); recipe docs/sfx/gen_pachy_v2_sfx.py.
import base64, json, os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
snd_dir, out_path = sys.argv[1], sys.argv[2]
three_path = sys.argv[3] if len(sys.argv) > 3 else None
SR_PAGE = 32000
tmp = tempfile.mkdtemp()
REC_DIR = os.path.join(HERE, "pachy_rec")
MOVES = [  # page order (the storyboard's, minus the two passives); rec = recording file
    {"id": "headbutt", "name": "Headbutt", "area": "attack", "rec": "headbutt", "snd": "headbutt"},
    {"id": "leap", "name": "Leap + double jump", "area": "speed", "rec": "leap", "snd": "leap"},
    {"id": "hook", "name": "Grappling Hook", "area": "attack", "rec": "hook", "snd": "hook"},
    {"id": "servodash", "name": "Servo Dash", "area": "speed", "rec": "servodash", "snd": "dash"},
    {"id": "visor", "name": "Dome Visor", "area": "defense", "rec": "visor", "snd": "visor"},
    {"id": "ink", "name": "Ink Shooter", "area": "eng", "rec": "ink", "snd": "ink"},
    {"id": "tether", "name": "Tether Spike", "area": "eng", "rec": "tether", "snd": "tether"},
    {"id": "bloodrush", "name": "Blood Rush", "area": "attack", "rec": "bloodrush", "snd": "blood"},
    {"id": "medstation", "name": "Med-Station", "area": "health", "rec": "medstation", "snd": "med"},
]
REC = {m["rec"]: json.load(open(os.path.join(REC_DIR, m["rec"] + ".json"))) for m in MOVES}

def stamp(rec, name, who="me", first=True):  # a server stamp's value (seconds on the page clock), else its change time
    hits = [s for s in REC[rec]["stamps"] if s[1] == who and s[2] == name]
    if not hits: raise KeyError(f"{rec}: no stamp {name}")
    s = hits[0] if first else hits[-1]
    return s[3] if s[4] else s[0]
def when(rec, name, value, who="me"):  # the time an attribute took a value
    for s in REC[rec]["stamps"]:
        if s[1] == who and s[2] == name and s[3] == value: return s[0]
    raise KeyError(f"{rec}: {name}={value}")
def press(rec, k=0): return REC[rec]["presses"][k][0]
def r2(x): return round(x, 3)

# beats: [part, at, stopAt?] from the recording's stamps, scheduled the way GameSounds 1.14 / PACHY_BEATS v1.1 do
B = {}
hb = "headbutt"; B["headbutt"] = [["hit", stamp(hb, "HeadbuttHitAt")]]
lp = "leap"; B["leap"] = [["jump", stamp(lp, "JumpStartedAt") + 0.12], ["jump", stamp(lp, "JumpDoubleAt")]]  # JumpWindup 0.12
hk = "hook"; B["hook"] = [["fire", stamp(hk, "HookLaunchAt") - 0.15], ["reel", stamp(hk, "HookContactAt"), stamp(hk, "HookSmashAt")], ["smash", stamp(hk, "HookSmashAt")]]
sd = "servodash"; B["servodash"] = [["blast", stamp(sd, "ServoDashBlastAt") - 0.06], ["burn", stamp(sd, "ServoDashBlastAt") + 0.25, stamp(sd, "ServoDashUntil")], ["steam", stamp(sd, "ServoDashUntil")]]
vs = "visor"; B["visor"] = [["up", stamp(vs, "VisorStartedAt")], ["field", stamp(vs, "VisorStartedAt") + 0.10, stamp(vs, "VisorUntil")], ["down", stamp(vs, "VisorUntil")]]
ik = "ink"; B["ink"] = [["fire", stamp(ik, "InkFireAt") - 0.10], ["splat", stamp(ik, "InkArriveAt")]]
th = "tether"; B["tether"] = [["cock", when(th, "TetherAiming", True)], ["throw", stamp(th, "TetherStartedAt")], ["land", stamp(th, "TetherLandAt")]]
br = "bloodrush"; B["bloodrush"] = [["pact", stamp(br, "HeadbuttSacrificeAt")]]
md = "medstation"; B["medstation"] = [["drop", stamp(md, "MedDroppedAt")], ["hum", stamp(md, "MedDroppedAt") + 0.60, stamp(md, "MedActiveUntil", first=False)], ["fold", stamp(md, "MedActiveUntil", first=False)]]
B = {k: [[p[0]] + [r2(x) for x in p[1:]] for p in v] for k, v in B.items()}

# phases (what you see, in order) from the same stamps
def phases(points, end):
    out = []
    for k, (t, label) in enumerate(points):
        t1 = points[k + 1][0] if k + 1 < len(points) else end
        out.append([r2(t), r2(t1), label])
    return out
L = {m["id"]: REC[m["rec"]]["len"] for m in MOVES}
PHASES = {
    "headbutt": phases([(0, "Standing"), (press(hb), "F pressed: the head dips (wind-up)"), (when(hb, "HeadbuttPoseState", "charge"), "Charge"), (stamp(hb, "HeadbuttHitAt"), "Hit: the bot is shoved"), (when(hb, "HeadbuttPoseState", "none"), "Back to standing")], L["headbutt"]),
    "leap": phases([(0, "Standing"), (press(lp), "Jump pressed: crouch"), (when(lp, "JumpState", "push"), "Lift-off"), (stamp(lp, "JumpDoubleAt"), "Double jump (pressed again)"), (when(lp, "JumpState", "fall"), "Falling"), (when(lp, "JumpState", "land"), "Landing")], L["leap"]),
    "hook": phases([(0, "Standing"), (press(hk), "Pressed: brace"), (stamp(hk, "HookLaunchAt"), "The claw flies"), (stamp(hk, "HookContactAt"), "Grabbed: reeled in"), (stamp(hk, "HookSmashAt"), "Head smash"), (stamp(hk, "HookSmashAt") + 0.5, "Recover")], L["hook"]),
    "servodash": phases([(0, "Standing"), (press(sd), "Pressed: squat"), (stamp(sd, "ServoDashBlastAt"), "Blast: 22 studs in 0.25 s"), (stamp(sd, "ServoDashBlastAt") + 0.25, "Boosted run (W held)"), (stamp(sd, "ServoDashUntil"), "Dash ends: dust and steam")], L["servodash"]),
    "visor": phases([(0, "Standing"), (press(vs), "Pressed: the visor slams down"), (stamp(vs, "VisorStartedAt") + 0.10, "Field up"), (stamp(vs, "VisorUntil"), "Visor folds")], L["visor"]),
    "ink": phases([(0, "Standing"), (press(ik), "Pressed: turn + pump"), (stamp(ik, "InkFireAt"), "Shot"), (stamp(ik, "InkArriveAt"), "Splat on the bot")], L["ink"]),
    "tether": phases([(0, "Standing"), (press(th), "Aiming: the tail cocks"), (stamp(th, "TetherStartedAt"), "Fired: the spike is thrown"), (stamp(th, "TetherLandAt"), "The spike lands: the bot is chained")], L["tether"]),
    "bloodrush": phases([(0, "Standing (no headbutt charges left)"), (press(br), "F pressed: Blood Rush pays health"), (when(br, "HeadbuttPoseState", "charge"), "The extra headbutt charges")], L["bloodrush"]),
    "medstation": phases([(0, "Standing"), (press(md), "Pressed: the capsule pops out"), (stamp(md, "MedDroppedAt") + 0.30, "Lands and unfolds"), (stamp(md, "MedDroppedAt") + 0.60, "Healing (its full time)"), (stamp(md, "MedActiveUntil", first=False), "Folds away")], L["medstation"]),
}
HOW = ("Recorded in Studio from the game as it is now (build v867): the Pachy, the target bot and the effects, 30 times a "
       "second, played back here exactly. Times are seconds on this clip; the press is at 0.30 s.")
def info(mid, rows): return {"how": HOW, "stamps": [[k, f"{v:.2f} s"] for k, v in rows]}
INFO = {
    "headbutt": info("headbutt", [("Press", press(hb)), ("HeadbuttStartedAt", stamp(hb, "HeadbuttStartedAt")), ("HeadbuttHitAt", stamp(hb, "HeadbuttHitAt"))]),
    "leap": info("leap", [("Press", press(lp)), ("JumpStartedAt", stamp(lp, "JumpStartedAt")), ("Lift-off (+ JumpWindup 0.12)", stamp(lp, "JumpStartedAt") + 0.12), ("Second press", press(lp, 1)), ("JumpDoubleAt", stamp(lp, "JumpDoubleAt")), ("Landing", when(lp, "JumpState", "land"))]),
    "hook": info("hook", [("Press", press(hk)), ("HookLaunchAt", stamp(hk, "HookLaunchAt")), ("HookContactAt", stamp(hk, "HookContactAt")), ("HookSmashAt", stamp(hk, "HookSmashAt"))]),
    "servodash": info("servodash", [("Press", press(sd)), ("ServoDashBlastAt", stamp(sd, "ServoDashBlastAt")), ("ServoDashUntil", stamp(sd, "ServoDashUntil"))]),
    "visor": info("visor", [("Press", press(vs)), ("VisorStartedAt", stamp(vs, "VisorStartedAt")), ("VisorUntil", stamp(vs, "VisorUntil"))]),
    "ink": info("ink", [("Press", press(ik)), ("InkFireAt", stamp(ik, "InkFireAt")), ("InkArriveAt", stamp(ik, "InkArriveAt"))]),
    "tether": info("tether", [("Aim starts", press(th)), ("Fired", press(th, 1)), ("TetherStartedAt", stamp(th, "TetherStartedAt")), ("TetherLandAt", stamp(th, "TetherLandAt"))]),
    "bloodrush": info("bloodrush", [("Press", press(br)), ("HeadbuttSacrificeAt", stamp(br, "HeadbuttSacrificeAt"))]),
    "medstation": info("medstation", [("Press", press(md)), ("MedDroppedAt", stamp(md, "MedDroppedAt")), ("MedActiveUntil", stamp(md, "MedActiveUntil", first=False))]),
}
GAME = {
    "headbutt": "In the game: on the hit (HeadbuttHitAt), heard by everyone nearby. The old built-in thud still plays under it.",
    "leap": "In the game: at the lift-off (the press + the 0.12 s crouch), and again the moment the double jump fires.",
    "hook": "In the game: the fire 0.15 s before the claw flies, the reel from the grab until the head smash, and your headbutt hit on the smash.",
    "servodash": "In the game: the blast on the squat, the burn while it runs (W held here), a steam hiss when the dash ends (the game shows dust and steam there).",
    "visor": "In the game: up on the press, the hum while the field is up, down when it folds. A block sound plays on every blocked hit; nothing hit the visor in this recording, so you don't hear it here.",
    "ink": "In the game: the pump on the press and the shot, the splat where the ink lands (farther shots land later).",
    "tether": "In the game: the cock when you start aiming, the throw when you fire, the landing where the spike hits. Here the aim is held 0.53 s and the spike lands on the bot 30 studs away.",
    "bloodrush": "In the game: on the press (HeadbuttSacrificeAt); the headbutt itself keeps its own sounds.",
    "medstation": "In the game: the drop on the press, the hum while it heals (its full 10.3 s here), the fold when it ends.",
}
PLAN = {m["id"]: {"mv": m["snd"], "parts": B[m["id"]], "game": GAME[m["id"]]} for m in MOVES}
# camera: extra points to keep in view (recording frame: -Z ahead) and padding
CAMERA = {"leap": {"points": [[0, 40, 0]], "pad": 40}, "tether": {"pad": 50}, "medstation": {"pad": 44},
          "servodash": {"pad": 40}}

# sounds
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
css = head.split("<style>", 1)[1].split("</style>", 1)[0]
CSS = """
/* sound pick on the recordings v1.0 */
.snd { background: var(--panel); border: 2px solid var(--accent); border-radius: 14px; padding: 12px 16px; display: grid; gap: 10px; min-width: 0; }
.snd h2 span { color: var(--accent); }
.opts { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px; }
@media (max-width: 720px) { .opts { grid-template-columns: minmax(0, 1fr); } }
.opt { text-align: left; font: 600 13px/1.4 var(--body); color: var(--grey); background: var(--card); border: 2px solid var(--line); border-radius: 12px; padding: 10px 12px; cursor: pointer; min-width: 0; }
.opt b { display: flex; align-items: center; gap: 8px; font: 700 17px/1.2 var(--display); color: var(--fg); margin-bottom: 4px; }
.opt b i { font: 800 11px var(--body); font-style: normal; letter-spacing: .06em; text-transform: uppercase; color: #1a0f00; background: var(--yellow); border-radius: 6px; padding: 1px 6px; visibility: hidden; }
.opt[aria-pressed="true"] { border-color: var(--yellow); box-shadow: 0 0 0 3px rgba(255,194,26,.2); }
.opt[aria-pressed="true"] b i { visibility: visible; }
.lanes { display: grid; gap: 3px; }
.trk { position: relative; height: 18px; background: var(--card); border-radius: 5px; overflow: hidden; }
.trk span { position: absolute; top: 0; bottom: 0; background: rgba(255,155,46,.35); border-left: 2px solid var(--accent); font: 800 10px/18px var(--body); color: var(--fg); padding-left: 4px; white-space: nowrap; overflow: hidden; }
.trk span.lp { background: repeating-linear-gradient(90deg, rgba(125,255,154,.28) 0 6px, rgba(125,255,154,.14) 6px 12px); border-left-color: var(--good); }
.trk em { position: absolute; top: 0; bottom: 0; width: 2px; background: var(--yellow); left: 0; }
.game { color: var(--muted); font-size: 13px; }
.pickrow { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
.pk { font: 800 14px var(--body); color: var(--fg); background: var(--card); border: 2px solid var(--line); border-radius: 10px; padding: 6px 14px; cursor: pointer; }
.pk[aria-pressed="true"] { background: var(--good); border-color: var(--good); color: #062010; }
.picks { position: sticky; bottom: env(safe-area-inset-bottom, 0px); z-index: 5; display: flex; flex-wrap: wrap; gap: 10px; align-items: center; justify-content: space-between; background: var(--panel); border: 2px solid var(--good); border-radius: 14px; padding: 10px 14px; }
.picks code { font: 800 14px/1.4 var(--body); color: var(--fg); white-space: normal; overflow-wrap: anywhere; min-width: 0; flex: 1 1 260px; }
.picks small { color: var(--muted); font-weight: 700; }
.moves { grid-template-columns: repeat(5, minmax(0, 1fr)); }
@media (max-width: 900px) { .moves { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
"""
three = ('<script>\n' + open(three_path).read() + '\n</script>') if three_path else '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>'
BODY = """<main>
  <header>
    <h1><span>Pachy</span> · sounds on the game's own animation <span style="color:var(--muted);font-size:.6em">round 11</span></h1>
    <p class="lede">This is the game, not a storyboard: every move was recorded in Studio from the live build (the Pachy, the target bot and the effects, 30 times a second) and plays back here exactly. Pick a move, then press an option: the move restarts and each sound plays on the beat the game stamped in that same recording. The bars under the scrubber show where every sound part sits. Mark your pick under the options; the bar at the bottom copies all of them. Turn your sound on.</p>
  </header>
  <div class="moves" role="group" aria-label="Move" id="moves"></div>
  <div class="row">
    <button class="btn go" id="play" aria-pressed="true">Pause</button>
    <span class="lbl">Speed</span><button class="btn" data-speed="1" aria-pressed="true">1×</button><button class="btn" data-speed="0.3" aria-pressed="false">0.3×</button>
    <span class="lbl" style="margin-left:6px">Camera</span>
    <button class="btn" data-view="hero" aria-pressed="true">3/4</button><button class="btn" data-view="side" aria-pressed="false">Side</button>
    <button class="btn" data-view="game" aria-pressed="false">Player camera</button><button class="btn" data-view="close" aria-pressed="false">Close-up</button>
  </div>
  <div class="stage">
    <canvas id="cv" aria-label="The Pachy doing the selected move, recorded from the game"></canvas>
    <div class="clock" id="clock"></div>
    <div class="cap"><b id="cap"></b></div>
  </div>
  <section class="snd" id="snd" aria-label="Sound options">
    <div class="row" style="justify-content:space-between"><h2 id="sndTitle"></h2><span class="row"><button class="btn" id="sndLoop" aria-pressed="true">Repeat</button><button class="btn" id="sndStop">Stop sound</button></span></div>
    <div class="opts" id="opts"></div>
    <div class="pickrow" id="pickRow"></div>
    <p class="game" id="sndGame"></p>
  </section>
  <input class="scrub" id="scrub" type="range" min="0" max="1000" value="0" aria-label="Scrub the move">
  <div class="lanes" id="lanes"></div>
  <div class="phases" id="phases"></div>
  <div class="cols">
    <div class="card" id="info"></div>
    <div class="card" id="part"></div>
  </div>
  <div class="picks" id="picks" aria-live="polite"><code id="pickText"></code><button class="btn go" id="copyPicks">Copy picks</button></div>
</main>
"""
SOUND_JS = r"""
// ---------- sound pick (Pachy, on the recordings) ----------
const SND = __SND__;
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
function schedule(parts, set, t0, b) { // t0 = the audio time of clip time 0
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
  const parts = pl.parts, cycle = VV().len;
  const live = {m, t0: actx.currentTime + 0.1, next: false, nodes: []};
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
  $("sndStop").hidden = !sndLive;
  $("opts").innerHTML = Object.keys(SND[pl.mv]).sort().map(o => { const d = SND[pl.mv][o].desc, i = d.indexOf(":"); return `<button class="opt" data-opt="${o}" aria-pressed="${!!sndLive && sndOpt[m.id] === o}"><b>${o} · ${d.slice(0, i)}<i>Playing</i></b>${d.slice(i + 1).trim()}</button>`; }).join("");
  $("sndGame").textContent = pl.game;
  const set = SND[pl.mv][sndOpt[m.id] || "A"], len = VV().len;
  $("lanes").innerHTML = pl.parts.map(([p, at, stop]) => {
    const info = set.parts[p], e = Math.min(len, stop != null ? stop : at + info.len);
    return `<div class="trk"><span class="${info.loop ? "lp" : ""}" style="left:${at / len * 100}%;width:${Math.max(0.6, (e - at) / len * 100)}%">${p} ${at.toFixed(2)} s</span><em></em></div>`;
  }).join("");
}
const PICK_NAME = {headbutt: "Headbutt", leap: "Jump", hook: "Hook", servodash: "Dash", visor: "Visor", ink: "Ink", tether: "Tether", bloodrush: "Blood Rush", medstation: "Med"};
const PICK_KEY = "mda_pachy_sound_picks_r11";
let myPicks = {};
try { myPicks = JSON.parse(localStorage.getItem(PICK_KEY) || "{}") || {}; } catch (e) { myPicks = {}; }
function pickText() { return MOVES.map(mm => `${PICK_NAME[mm.id]} ${myPicks[mm.id] || "?"}`).join(", "); }
function renderPicks() {
  const id = M().id, n = MOVES.filter(mm => myPicks[mm.id]).length;
  $("pickRow").innerHTML = `<span class="lbl">Your pick for ${PICK_NAME[id]}</span>` + Object.keys(SND[PLAN[id].mv]).sort().map(o => `<button class="pk" data-pick="${o}" aria-pressed="${myPicks[id] === o}">${o}</button>`).join("");
  $("pickText").innerHTML = `<span id="pickStr">${pickText()}</span> <small>· ${n} of ${MOVES.length} picked</small>`;
}
$("pickRow").addEventListener("click", e => { const b = e.target.closest("[data-pick]"); if (!b) return; myPicks[M().id] = b.dataset.pick; try { localStorage.setItem(PICK_KEY, JSON.stringify(myPicks)); } catch (err) {} renderPicks(); });
$("copyPicks").addEventListener("click", () => {
  const txt = pickText(), btn = $("copyPicks");
  const done = ok => { btn.textContent = ok ? "Copied ✓" : "Select + copy the text"; setTimeout(() => { btn.textContent = "Copy picks"; }, 1800); };
  const fallback = () => { const r = document.createRange(); r.selectNodeContents($("pickStr")); const sel = getSelection(); sel.removeAllRanges(); sel.addRange(r); let ok = false; try { ok = document.execCommand("copy"); } catch (err) {} done(ok); };
  try { navigator.clipboard.writeText(txt).then(() => done(true), fallback); } catch (err) { fallback(); }
});
function usePick() { renderSnd(); renderPicks(); }
$("opts").addEventListener("click", e => { const b = e.target.closest("[data-opt]"); if (b) playOpt(b.dataset.opt).catch(err => { $("sndGame").textContent = "Sound failed to start: " + err; }); });
$("sndStop").onclick = stopSound;
$("sndLoop").onclick = () => { sndRepeat = !sndRepeat; $("sndLoop").setAttribute("aria-pressed", sndRepeat); };
["moves", "phases", "scrub", "play"].forEach(id => $(id).addEventListener(id === "scrub" ? "input" : "click", () => { if (sndLive) stopSound(); }, true));
document.querySelectorAll("[data-speed]").forEach(b => b.addEventListener("click", () => { if (sndLive) stopSound(); }, true));
$("moves").addEventListener("click", usePick);
(function lanesHead() { document.querySelectorAll(".trk em").forEach(e => e.style.left = (play.t / VV().len * 100) + "%"); requestAnimationFrame(lanesHead); })();
cur = Math.max(0, MOVES.findIndex(mm => mm.id === "servodash")); renderAll(); start(); usePick();
"""
data = ("const REC = " + json.dumps({k: v for k, v in REC.items()}, separators=(",", ":")) + ";\n"
        + "const MOVES = " + json.dumps([{k: m[k] for k in ("id", "name", "area", "rec")} for m in MOVES]) + ";\n"
        + "const CAMERA = " + json.dumps(CAMERA) + ";\n" + "const PHASES = " + json.dumps(PHASES) + ";\nconst INFO = " + json.dumps(INFO) + ";\nconst PLAN = " + json.dumps(PLAN) + ";\n")
player = open(os.path.join(HERE, "pachy_rec_player.js")).read()
html = ('<title>Sound Pick Board</title>\n<meta name="claude:viewport-fit-sides" content="cover">\n'
        '<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=Fredoka:wght@600;700&family=Nunito:wght@600;700;800&display=swap" rel="stylesheet">\n'
        "<style>" + css + CSS + "</style>\n" + BODY + three + "\n<script>\n" + data + player + "\n" + SOUND_JS.replace("__SND__", json.dumps(snd)) + "\n</script>\n")
open(out_path, "w").write(html)
print("ok", out_path, round(os.path.getsize(out_path) / 1e6, 2), "MB")
for m in MOVES: print(m["id"], "len", L[m["id"]], "beats", PLAN[m["id"]]["parts"])
