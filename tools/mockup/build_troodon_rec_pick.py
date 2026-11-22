# build_troodon_rec_pick.py v1.0 (Mecha Dino Arena) — the Troodon sound pick page on the game's own animation (MDA-552, sound
# pass round 20; Kepu 2026-11-22 05:06 "next" after the GameSounds 1.20 publish: the Troodon gets the record-the-game page after
# the Herrera). Copy of build_herrera_rec_pick.py 1.0 with the Troodon's nine part buttons, beats and recordings
# (tools/mockup/troodon_rec, Studio 2026-11-22, place build v888). Sounds: docs/sfx/gen_troodon_v2_sfx.py (Sonniss, not in the
# repo). Original header follows.
# --- build_herrera_rec_pick.py v1.0: the Herrera sound pick page on the game's own animation (MDA-552, sound
# pass round 19; Kepu 2026-11-17 21:12 "then next": the Herrera gets the record-the-game page after the Dilo).
# Copy of build_dilo_rec_pick.py 1.0 with the Herrera's eight part buttons, beats and recordings (tools/mockup/herrera_rec,
# Studio 2026-11-17, place build v886). The Adrenaline Injector plays the Raptor's beat-timed sounds (GameSounds 1.18) and is
# not on this page. Sounds: docs/sfx/gen_herrera_v2_sfx.py (Sonniss, not in the repo). Original header follows.
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
REC_DIR = os.path.join(HERE, "troodon_rec")
MOVES = [  # page order = the Troodon's part buttons (TrooMovesServer, then TrooSlotServer); rec = recording, snd = generator key
    {"id": "mender", "name": "Mender Drone", "area": "health", "rec": "mender", "snd": "mender"},
    {"id": "lantern", "name": "Arc Lantern", "area": "attack", "rec": "lantern", "snd": "lantern"},
    {"id": "sap", "name": "Sap Wall", "area": "defense", "rec": "sap", "snd": "sap"},
    {"id": "shed", "name": "Feather Shed", "area": "defense", "rec": "shed", "snd": "shed"},
    {"id": "portal", "name": "Portal Feathers", "area": "speed", "rec": "portal", "snd": "portal"},
    {"id": "burst", "name": "Bloom Burst", "area": "health", "rec": "burst", "snd": "burst"},
    {"id": "dome", "name": "Shield Dome", "area": "defense", "rec": "dome", "snd": "dome"},
    {"id": "sleep", "name": "Sleep Dart", "area": "attack", "rec": "sleep", "snd": "sleep"},
    {"id": "sentry", "name": "Sentry Pod", "area": "attack", "rec": "sentry", "snd": "sentry"},
]
REC = {m["rec"]: json.load(open(os.path.join(REC_DIR, m["rec"] + ".json"))) for m in MOVES}
FORCEFIELD_SEE = 0.8  # Roblox draws the ForceField material (the Shield Dome) as a see-through shimmer whatever its Transparency
for _d in REC.values():  # (recorded 0); the page draws it at this transparency so the dome does not hide the dinos inside it
    for _p in _d["parts"]:
        if _p.get("m") == "ForceField":
            _p["t0"] = max(_p.get("t0", 0), FORCEFIELD_SEE)
            for _c in _p.get("ch", []):
                if len(_c) > 2: _c[2] = max(_c[2], FORCEFIELD_SEE)

def stamp(rec, name, who="me", first=True):  # a server stamp's value (seconds on the page clock), else its change time
    hits = [s for s in REC[rec]["stamps"] if s[1] == who and s[2] == name]
    if not hits: raise KeyError(f"{rec}: no stamp {name}")
    s = hits[0] if first else hits[-1]
    return s[3] if s[4] else s[0]
def stamps(rec, name, who="me"): return [s[3] if s[4] else s[0] for s in REC[rec]["stamps"] if s[1] == who and s[2] == name]
def when(rec, name, value, who="me"):  # the time an attribute took a value
    for s in REC[rec]["stamps"]:
        if s[1] == who and s[2] == name and s[3] == value: return s[0]
    raise KeyError(f"{rec}: {name}={value}")
def press(rec, k=0): return REC[rec]["presses"][k][0]
def r2(x): return round(x, 3)
L = {m["id"]: REC[m["rec"]]["len"] for m in MOVES}

DOME_TIME = 6.75      # TrooPartDomeTime at the star (TrooSlotServer: TrooDomeUntil = open + time)
SENTRY_TIME = 10.8    # TrooPartSentryTime at II (TrooSentryUntil = open + time; re-stamped to the fold time when it folds)
SENTRY_FLIGHT = 12 / 220  # a pod from the turret (18 studs out) to the bot (30) at TrooSlot_sentryShotSpeed 220
SAP_END_PAGE = r2(L["sap"] - 0.7)    # the wall stands 8 s in the game; the clip ends sooner (the page says so)
DOME_END_PAGE = r2(L["dome"] - 0.7)  # the dome holds 6.75 s in the game
dome_open = stamp("dome", "TrooDomeUntil") - DOME_TIME
sentry_until = stamps("sentry", "TrooSentryUntil")
sentry_open, sentry_fold = sentry_until[0] - SENTRY_TIME, sentry_until[-1]
sentry_hits = [t for t in stamps("sentry", "TrooHitAt", who="bot") if t < sentry_fold + 0.1]
B = {}
B["mender"] = [["launch", stamp("mender", "TrooMenderAt")], ["arrive", stamp("mender", "TrooMenderArriveAt")],
               ["loop", stamp("mender", "TrooMenderArriveAt") + 0.1, stamp("mender", "TrooMenderUntil")], ["end", stamp("mender", "TrooMenderEndAt")]]
B["lantern"] = [["throw", stamp("lantern", "TrooLanternAt")], ["land", stamp("lantern", "TrooLanternLandAt")]] + [["zap", t] for t in stamps("lantern", "TrooLanternZapAt")]
B["sap"] = [["throw", stamp("sap", "TrooSapAt")], ["rise", stamp("sap", "TrooSapSplatAt")], ["end", SAP_END_PAGE]]
B["shed"] = [["snap", stamp("shed", "TrooShedAt")], ["burst", stamp("shed", "TrooShedBurstAt")]]
B["portal"] = [["tear", stamp("portal", "TrooRiftAt")], ["trail", stamp("portal", "TrooRiftAt") + 0.1, stamp("portal", "TrooRiftOpenAt")],
               ["open", stamp("portal", "TrooRiftOpenAt")]] + [["travel", t] for t in stamps("portal", "TrooRiftTravelAt")]
B["burst"] = [["throw", stamp("burst", "TrooBurstAt")], ["bloom", stamp("burst", "TrooBurstLandAt")]]
B["dome"] = [["throw", stamp("dome", "TrooDomeAt")], ["open", dome_open], ["loop", dome_open + 0.2, DOME_END_PAGE], ["close", DOME_END_PAGE]]
B["sleep"] = [["coil", stamp("sleep", "TrooSleepAt")], ["fire", stamp("sleep", "TrooSleepFireAt")], ["hit", stamp("sleep", "TrooSleepAt", who="bot")],
              ["snore", stamp("sleep", "TrooSleepAt", who="bot") + 0.6, min(L["sleep"] - 0.05, stamp("sleep", "TrooSleepUntil", who="bot"))]]
B["sentry"] = [["throw", stamp("sentry", "TrooSentryAt")], ["deploy", sentry_open]] + [["shot", t - SENTRY_FLIGHT] for t in sentry_hits] + [["fold", sentry_fold]]
B = {k: [[p[0]] + [r2(x) for x in p[1:]] for p in v] for k, v in B.items()}

def phases(points, end):
    out = []
    for k, (t, label) in enumerate(points):
        t1 = points[k + 1][0] if k + 1 < len(points) else end
        out.append([r2(t), r2(t1), label])
    return out
PHASES = {
    "mender": phases([(0, "Standing, hurt (a test: 40% health)"), (press("mender"), "Pressed: the drone lifts off its back"), (stamp("mender", "TrooMenderArriveAt"), "It arrives: healing (5.4 s)"), (stamp("mender", "TrooMenderEndAt"), "Done: it flies home")], L["mender"]),
    "lantern": phases([(0, "Standing"), (press("lantern"), "Pressed: the lantern is lobbed"), (stamp("lantern", "TrooLanternLandAt"), "It lands on the bot: zap + 1 s stun")], L["lantern"]),
    "sap": phases([(0, "Standing"), (press("sap"), "Pressed: the pod is thrown"), (stamp("sap", "TrooSapSplatAt"), "The wall goes up (80 studs out, 8 s in the game)"), (SAP_END_PAGE, "Here: the end sound, moved onto the clip")], L["sap"]),
    "shed": phases([(0, "Stunned (a test stun)"), (press("shed"), "Pressed: it breaks free"), (stamp("shed", "TrooShedBurstAt"), "The feather burst")], L["shed"]),
    "portal": phases([(0, "Standing"), (press("portal"), "Pressed: placing the rift, walking"), (stamp("portal", "TrooRiftOpenAt"), "Pressed again: the rift opens"), (stamp("portal", "TrooRiftTravelAt"), "Back at the start: it rides the rift")], L["portal"]),
    "burst": phases([(0, "Standing"), (press("burst"), "Pressed: the bud is thrown"), (stamp("burst", "TrooBurstLandAt"), "It bursts: heal + boost, the bot's heals cut")], L["burst"]),
    "dome": phases([(0, "Standing"), (press("dome"), "Pressed: it is thrown"), (dome_open, "The dome opens (6.75 s in the game)"), (DOME_END_PAGE, "Here: the close sound, moved onto the clip")], L["dome"]),
    "sleep": phases([(0, "Standing"), (press("sleep"), "Pressed: the neck coils"), (stamp("sleep", "TrooSleepFireAt"), "The dart flies"), (stamp("sleep", "TrooSleepAt", who="bot"), "The bot sleeps (3.4 s)")], L["sleep"]),
    "sentry": phases([(0, "Standing"), (press("sentry"), "Pressed: the pod is thrown"), (sentry_open, "The turret unfolds"), (sentry_hits[0] - SENTRY_FLIGHT, f"It fires ({len(sentry_hits)} pods)"), (sentry_fold, "20 damage dealt: it folds away")], L["sentry"]),
}
HOW = ("Recorded in Studio from the game as it is now (build v888): the Troodon, a target bot and the effects, 30 times a "
       "second, played back here exactly. Times are seconds on this clip; the press is at 0.30 s.")
def info(rows): return {"how": HOW, "stamps": [[k, f"{v:.2f} s"] for k, v in rows]}
INFO = {
    "mender": info([("Press", press("mender")), ("TrooMenderAt", stamp("mender", "TrooMenderAt")), ("TrooMenderArriveAt", stamp("mender", "TrooMenderArriveAt")), ("TrooMenderUntil", stamp("mender", "TrooMenderUntil")), ("TrooMenderEndAt", stamp("mender", "TrooMenderEndAt"))]),
    "lantern": info([("Press", press("lantern")), ("TrooLanternAt", stamp("lantern", "TrooLanternAt")), ("TrooLanternLandAt", stamp("lantern", "TrooLanternLandAt")), ("TrooLanternZapAt", stamp("lantern", "TrooLanternZapAt"))]),
    "sap": info([("Press", press("sap")), ("TrooSapAt", stamp("sap", "TrooSapAt")), ("TrooSapSplatAt", stamp("sap", "TrooSapSplatAt"))]),
    "shed": info([("Press", press("shed")), ("TrooShedAt", stamp("shed", "TrooShedAt")), ("TrooShedBurstAt", stamp("shed", "TrooShedBurstAt"))]),
    "portal": info([("Press 1", press("portal")), ("TrooRiftAt", stamp("portal", "TrooRiftAt")), ("Press 2", press("portal", 4)), ("TrooRiftOpenAt", stamp("portal", "TrooRiftOpenAt")), ("TrooRiftTravelAt", stamp("portal", "TrooRiftTravelAt")), ("TrooRiftTravelEndAt", stamp("portal", "TrooRiftTravelEndAt"))]),
    "burst": info([("Press", press("burst")), ("TrooBurstAt", stamp("burst", "TrooBurstAt")), ("TrooBurstLandAt", stamp("burst", "TrooBurstLandAt"))]),
    "dome": info([("Press", press("dome")), ("TrooDomeAt", stamp("dome", "TrooDomeAt")), ("Opens (TrooDomeUntil - 6.75)", dome_open), ("TrooDomeUntil", stamp("dome", "TrooDomeUntil"))]),
    "sleep": info([("Press", press("sleep")), ("TrooSleepAt (coil)", stamp("sleep", "TrooSleepAt")), ("TrooSleepFireAt", stamp("sleep", "TrooSleepFireAt")), ("Bot TrooSleepAt", stamp("sleep", "TrooSleepAt", who="bot")), ("Bot TrooSleepUntil", stamp("sleep", "TrooSleepUntil", who="bot"))]),
    "sentry": info([("Press", press("sentry")), ("TrooSentryAt", stamp("sentry", "TrooSentryAt")), ("Opens (TrooSentryUntil - 10.8)", sentry_open), ("First bot hit", sentry_hits[0]), ("Last bot hit", sentry_hits[-1]), ("Folds (TrooSentryUntil re-stamped)", sentry_fold)]),
}
GAME = {
    "mender": "In the game: the lift-off on the press, the arrival when it reaches the most hurt ally (here you), the heal hum while it heals (5.4 s), the end as it flies home.",
    "lantern": "In the game: the lob on the press, the landing, a zap on every dino it zaps (the chain, up to 3).",
    "sap": "In the game: the throw on the press, the rise when the wall goes up, the end when it crumbles (8 s). The clip is 3.8 s, so here the end plays at 3.1 s.",
    "shed": "In the game: the snap when you break the stun, pin or snare (the press), the burst when the feathers blast out.",
    "portal": "In the game: the tear on the first press, the trail while you walk the path, the open on the second press, a ride sound whenever a dino is carried along it (30 s open).",
    "burst": "In the game: the throw on the press, the bloom where the bud bursts.",
    "dome": "In the game: the throw on the press, the open when the dome snaps up, the hum while it holds (6.75 s), the close when it fades. The clip is 3.8 s, so here the close plays at 3.1 s.",
    "sleep": "In the game: the coil on the press, the shot when the dart flies, the hit and the sleep sound on the dino it puts to sleep (until it wakes).",
    "sentry": "In the game: the throw on the press, the unfold when the turret opens, a shot for every pod it fires (from the turret), the fold when it has dealt its 20 damage or its time is up.",
}
PLAN = {m["id"]: {"mv": m["snd"], "parts": B[m["id"]], "game": GAME[m["id"]]} for m in MOVES}
CAMERA = {"lantern": {"points": [[0, 0, -30]], "pad": 40}, "sleep": {"points": [[0, 0, -30]], "pad": 40},
          "sentry": {"points": [[0, 0, -30]], "pad": 40}, "burst": {"points": [[0, 0, -30]], "pad": 40},
          "dome": {"points": [[-50, 0, -12], [50, 0, -12]], "pad": 10}, "sap": {"points": [[0, 0, 0], [0, 0, -80]], "pad": 50},
          "portal": {"points": [[0, 0, 0], [-25, 0, 25], [-28, 0, 49]], "pad": 24}}  # the rift path (the dino walked away from the camera's side)
# the Shield Dome is about 120 studs across (both dinos inside): the dome camera frames the whole dome

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
    <h1><span>Troodon</span> · sounds on the game's own animation <span style="color:var(--muted);font-size:.6em">round 20</span></h1>
    <p class="lede">This is the game, not a storyboard: every move was recorded in Studio from the live build (the Troodon, a target bot and the effects, 30 times a second) and plays back here exactly. Pick a move, then press an option: the move restarts and each sound plays on the beat the game stamped in that same recording. The bars under the scrubber show where every sound part sits. Mark your pick under the options; the bar at the bottom copies all of them. Turn your sound on.</p>
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
    <canvas id="cv" aria-label="The Troodon doing the selected move, recorded from the game"></canvas>
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
// ---------- sound pick (Troodon, on the recordings) ----------
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
  const lanes = []; // repeated beats of one part (the gatling's darts) share a lane
  pl.parts.forEach(([p, at, stop]) => { let l = lanes.find(x => x.p === p); if (!l) lanes.push(l = {p, beats: []}); l.beats.push([at, stop]); });
  $("lanes").innerHTML = lanes.map(({p, beats}) => {
    const info = set.parts[p], n = beats.length;
    return `<div class="trk">` + beats.map(([at, stop], k) => { const e = Math.min(len, stop != null ? stop : at + info.len);
      return `<span class="${info.loop ? "lp" : ""}" style="left:${at / len * 100}%;width:${Math.max(0.6, (e - at) / len * 100)}%">${k === 0 ? `${p} ${at.toFixed(2)} s${n > 1 ? ` ×${n}` : ""}` : ""}</span>`; }).join("") + `<em></em></div>`;
  }).join("");
}
const PICK_NAME = {mender: "Mender", lantern: "Lantern", sap: "Sap", shed: "Shed", portal: "Portal", burst: "Burst", dome: "Dome", sleep: "Sleep", sentry: "Sentry"};
const PICK_KEY = "mda_troodon_sound_picks_r20";
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
