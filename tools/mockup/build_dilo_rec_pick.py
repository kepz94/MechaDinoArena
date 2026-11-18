# build_dilo_rec_pick.py v1.0 (Mecha Dino Arena) — the Dilo sound pick page on the game's own animation (MDA-552, sound pass
# round 18; Kepu 2026-11-17 19:52 "Next": the Dilo gets the record-the-game page the Pachy and the Raptor got).
# Copy of build_raptor_rec_pick.py 1.0 with the Dilo's seven buttons, beats and recordings (tools/mockup/dilo_rec, Studio
# 2026-11-17, place build v885; Spring Jets keeps its sound and is not on this page). Sounds: docs/sfx/gen_dilo_v2_sfx.py
# (Sonniss, not in the repo). Repeated beats (the gatling's 8 darts and 8 hits) share one lane. Original header follows.
# --- build_pachy_rec_pick.py v1.0 ---
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
REC_DIR = os.path.join(HERE, "dilo_rec")
MOVES = [  # page order = the Dilo's buttons in the parts tree; rec = recording file, snd = the generator's move key
    {"id": "scope", "name": "Sniper Scope", "area": "attack", "rec": "scope", "snd": "scope"},
    {"id": "gatling", "name": "Venom Gatling", "area": "attack", "rec": "gatling", "snd": "gatling"},
    {"id": "mortar", "name": "Toxin Mortar", "area": "attack", "rec": "mortar", "snd": "mortar"},
    {"id": "spine", "name": "Spine Burst", "area": "defense", "rec": "spine", "snd": "spine"},
    {"id": "hiss", "name": "Sonic Hiss", "area": "eng", "rec": "hiss", "snd": "hiss"},
    {"id": "pump", "name": "Antivenom Pump", "area": "health", "rec": "pump", "snd": "pump"},
    {"id": "over", "name": "Venom Overdrive", "area": "eng", "rec": "over", "snd": "over"},
]
REC = {m["rec"]: json.load(open(os.path.join(REC_DIR, m["rec"] + ".json"))) for m in MOVES}

def stamp(rec, name, who="me", first=True):  # a server stamp's value (seconds on the page clock), else its change time
    hits = [s for s in REC[rec]["stamps"] if s[1] == who and s[2] == name]
    if not hits: raise KeyError(f"{rec}: no stamp {name}")
    s = hits[0] if first else hits[-1]
    return s[3] if s[4] else s[0]
def val(rec, name, who="me"):  # an attribute's (first) value
    for s in REC[rec]["stamps"]:
        if s[1] == who and s[2] == name: return s[3]
    raise KeyError(f"{rec}: {name}")
def changes(rec, name, who="me"):  # every change time of an attribute (per-dart strings: no server time)
    return [s[0] for s in REC[rec]["stamps"] if s[1] == who and s[2] == name]
def press(rec, k=0): return REC[rec]["presses"][k][0]
def r2(x): return round(x, 3)
L = {m["id"]: REC[m["rec"]]["len"] for m in MOVES}

# beats: [part, at, stopAt?] from the recording's stamps (gen_dilo_v2_sfx.py's header). A loop that outlasts the clip stops
# at the clip's end; the Overdrive's end (8 s in) is moved onto the clip (OVER_END_PAGE) and the page says so.
g_at = stamp("gatling", "DiloGatlingAt"); g_spin = g_at + val("gatling", "DiloGatlingWindup"); g_end = g_spin + val("gatling", "DiloGatlingTime")
m_land = stamp("mortar", "DiloMortarLandAt")
o_start = stamp("over", "DiloOverdriveStartAt")
OVER_END_PAGE = r2(L["over"] - 1.2)
B = {}
B["scope"] = [["in", stamp("scope", "DiloScopeStartAt")], ["charge", stamp("scope", "DiloScopeStartAt") + 0.15, stamp("scope", "DiloScopeShotAt")],
              ["shot", stamp("scope", "DiloScopeShotAt")], ["hit", changes("scope", "DiloScopeMarkUntil", who="bot")[0]]]
B["gatling"] = ([["spinup", g_at], ["whirr", g_spin, g_end], ["spindown", g_end]] + [["shot", t] for t in changes("gatling", "DiloGatlingShot")]
                + [["hit", t] for t in changes("gatling", "DiloGatlingHit")])
B["mortar"] = [["load", stamp("mortar", "DiloMortarAt")], ["fire", stamp("mortar", "DiloMortarFireAt")], ["land", m_land],
               ["cloud", m_land + 0.15, min(m_land + val("mortar", "DiloMortarTime"), L["mortar"] - 0.05)]]
B["spine"] = [["flare", stamp("spine", "DiloSpineAt")], ["burst", stamp("spine", "DiloSpineBurstAt")], ["hit", stamp("spine", "DiloSpineBurstAt") + val("spine", "DiloSpineFlight")]]
B["hiss"] = [["charge", stamp("hiss", "DiloHissAt")], ["blast", stamp("hiss", "DiloHissBlastAt")]]
B["pump"] = [["prime", stamp("pump", "DiloPumpAt")], ["jolt", stamp("pump", "DiloPumpJoltAt")]]
B["over"] = [["charge", stamp("over", "DiloOverdriveAt")], ["loop", o_start, OVER_END_PAGE], ["end", OVER_END_PAGE]]
B = {k: [[p[0]] + [r2(x) for x in p[1:]] for p in v] for k, v in B.items()}

def phases(points, end):
    out = []
    for k, (t, label) in enumerate(points):
        t1 = points[k + 1][0] if k + 1 < len(points) else end
        out.append([r2(t), r2(t1), label])
    return out
PHASES = {
    "scope": phases([(0, "Standing"), (press("scope"), "R held: the scope comes up"), (stamp("scope", "DiloScopeStartAt") + 0.15, "Aiming (the charge)"), (stamp("scope", "DiloScopeShotAt"), "Released: the shot"), (changes("scope", "DiloScopeMarkUntil", who="bot")[0], "Hit: the bot is marked")], L["scope"]),
    "gatling": phases([(0, "Standing"), (press("gatling"), "Pressed: the barrels spin up"), (changes("gatling", "DiloGatlingShot")[0], "8 darts in 1 s"), (g_end, "The barrels stop")], L["gatling"]),
    "mortar": phases([(0, "Standing"), (press("mortar"), "Pressed: it loads"), (stamp("mortar", "DiloMortarFireAt"), "Fired: the shell flies"), (m_land, "It lands: the toxin cloud (5 s in the game)")], L["mortar"]),
    "spine": phases([(0, "Standing"), (press("spine"), "Pressed: the frill flares"), (stamp("spine", "DiloSpineBurstAt"), "The spines burst out all round"), (stamp("spine", "DiloSpineBurstAt") + val("spine", "DiloSpineFlight"), "A spine hits the bot")], L["spine"]),
    "hiss": phases([(0, "Standing"), (press("hiss"), "Pressed: the hood flares"), (stamp("hiss", "DiloHissBlastAt"), "The blast: the bot is pushed and silenced")], L["hiss"]),
    "pump": phases([(0, "Standing"), (press("pump"), "Pressed: the piston primes"), (stamp("pump", "DiloPumpJoltAt"), "The jolt: debuffs cleared, healed")], L["pump"]),
    "over": phases([(0, "Standing"), (press("over"), "Pressed: the reactor charges, a roar"), (o_start, "Overdrive on (8 s in the game)"), (OVER_END_PAGE, "Here: the end sound, moved onto the clip")], L["over"]),
}
HOW = ("Recorded in Studio from the game as it is now (build v885): the Dilo, a target bot and the effects, 30 times a "
       "second, played back here exactly. Times are seconds on this clip; the press is at 0.30 s.")
def info(rows): return {"how": HOW, "stamps": [[k, f"{v:.2f} s"] for k, v in rows]}
INFO = {
    "scope": info([("Press (aim)", press("scope")), ("Release", press("scope", 1)), ("DiloScopeStartAt", stamp("scope", "DiloScopeStartAt")), ("DiloScopeShotAt", stamp("scope", "DiloScopeShotAt")), ("Bot marked", changes("scope", "DiloScopeMarkUntil", who="bot")[0])]),
    "gatling": info([("Press", press("gatling")), ("DiloGatlingAt", g_at), ("First dart", changes("gatling", "DiloGatlingShot")[0]), ("Last dart", changes("gatling", "DiloGatlingShot")[-1]), ("At + wind-up + time", g_end)]),
    "mortar": info([("Press", press("mortar")), ("DiloMortarAt", stamp("mortar", "DiloMortarAt")), ("DiloMortarFireAt", stamp("mortar", "DiloMortarFireAt")), ("DiloMortarLandAt", m_land)]),
    "spine": info([("Press", press("spine")), ("DiloSpineAt", stamp("spine", "DiloSpineAt")), ("DiloSpineBurstAt", stamp("spine", "DiloSpineBurstAt")), ("Burst + DiloSpineFlight", stamp("spine", "DiloSpineBurstAt") + val("spine", "DiloSpineFlight"))]),
    "hiss": info([("Press", press("hiss")), ("DiloHissAt", stamp("hiss", "DiloHissAt")), ("DiloHissBlastAt", stamp("hiss", "DiloHissBlastAt"))]),
    "pump": info([("Press", press("pump")), ("DiloPumpAt", stamp("pump", "DiloPumpAt")), ("DiloPumpJoltAt", stamp("pump", "DiloPumpJoltAt"))]),
    "over": info([("Press", press("over")), ("DiloOverdriveAt", stamp("over", "DiloOverdriveAt")), ("DiloOverdriveStartAt", o_start), ("DiloOverdriveUntil", stamp("over", "DiloOverdriveUntil"))]),
}
GAME = {
    "scope": "In the game: the scope-in when you start aiming, the charge while you hold it, the shot on release, the hit on the dino you mark (here the bot 30 studs ahead).",
    "gatling": "In the game: the spin-up on the press, the whirr while the darts fly (1 s), one pop per dart and one splat per hit (8 each here), the spin-down at the end.",
    "mortar": "In the game: the load on the press, the launch, the landing where the shell comes down, the cloud sound there while the cloud lasts (5 s; the clip ends sooner).",
    "spine": "In the game: the flare on the press, the burst when the spines fly out all round, a hit on every dino a spine strikes.",
    "hiss": "In the game: the charge on the press, the blast that pushes and silences the dinos in front.",
    "pump": "In the game: the prime on the press, the jolt when it clears your debuffs and heals.",
    "over": "In the game: the charge and roar on the press, the loop while Overdrive lasts (8 s), the end when it runs out. The clip is 4 s, so here the end plays at 2.9 s.",
}
PLAN = {m["id"]: {"mv": m["snd"], "parts": B[m["id"]], "game": GAME[m["id"]]} for m in MOVES}
CAMERA = {"scope": {"points": [[0, 0, -30]], "pad": 40}, "gatling": {"points": [[0, 0, -30]], "pad": 40}, "mortar": {"points": [[0, 0, -30]], "pad": 40},
          "spine": {"points": [[0, 0, -16]], "pad": 26}, "hiss": {"points": [[0, 0, -16]], "pad": 26}, "over": {"points": [[0, 0, -16]], "pad": 26}}

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
.moves { grid-template-columns: repeat(4, minmax(0, 1fr)); }
@media (max-width: 900px) { .moves { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
"""
three = ('<script>\n' + open(three_path).read() + '\n</script>') if three_path else '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>'
BODY = """<main>
  <header>
    <h1><span>Dilo</span> · sounds on the game's own animation <span style="color:var(--muted);font-size:.6em">round 18</span></h1>
    <p class="lede">This is the game, not a storyboard: every move was recorded in Studio from the live build (the Dilo, a target bot and the effects, 30 times a second) and plays back here exactly. Pick a move, then press an option: the move restarts and each sound plays on the beat the game stamped in that same recording. The bars under the scrubber show where every sound part sits. Mark your pick under the options; the bar at the bottom copies all of them. Turn your sound on.</p>
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
    <canvas id="cv" aria-label="The Dilo doing the selected move, recorded from the game"></canvas>
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
// ---------- sound pick (Dilo, on the recordings) ----------
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
  const lanes = []; // v1.0 Dilo: repeated beats of one part (the gatling's darts) share a lane
  pl.parts.forEach(([p, at, stop]) => { let l = lanes.find(x => x.p === p); if (!l) lanes.push(l = {p, beats: []}); l.beats.push([at, stop]); });
  $("lanes").innerHTML = lanes.map(({p, beats}) => {
    const info = set.parts[p], n = beats.length;
    return `<div class="trk">` + beats.map(([at, stop], k) => { const e = Math.min(len, stop != null ? stop : at + info.len);
      return `<span class="${info.loop ? "lp" : ""}" style="left:${at / len * 100}%;width:${Math.max(0.6, (e - at) / len * 100)}%">${k === 0 ? `${p} ${at.toFixed(2)} s${n > 1 ? ` ×${n}` : ""}` : ""}</span>`; }).join("") + `<em></em></div>`;
  }).join("");
}
const PICK_NAME = {scope: "Scope", gatling: "Gatling", mortar: "Mortar", spine: "Spine", hiss: "Hiss", pump: "Pump", over: "Overdrive"};
const PICK_KEY = "mda_dilo_sound_picks_r18";
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
cur = 0; renderAll(); start(); usePick();
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
