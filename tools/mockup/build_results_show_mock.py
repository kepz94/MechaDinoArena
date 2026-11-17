# build_results_show_mock.py v1.0 (Mecha Dino Arena) — the end-of-match presentation mockup: the game's own show, recorded
# in Studio, with the proposed audio laid over it (MDA-552; Kepu 2026-11-17 13:18 "Send me a mock up of the actual
# presentation that we have plus all the new stuff we're proposing to add on to it so I can see it for myself").
# Inputs (none of them in the repo):
#   <rec dir>/rec.json + rec.bin  tools/studio/show_recorder.luau 1.0, a practice match won 999-120 (titles: APEX PREDATOR
#                                 Kepz, BUTTON MASHER Wrench, EXTINCT Yuki, CARRIED Fang), binary rows packed in Studio
#                                 (frame u16, part u16, pos i16 x3 = (p - (0, 3000, 0)) * 50, quaternion i16 x4 * 32767)
#   <rec dir>/rec2.json           the same match end with VictoryTitles off (only the on-screen layers): the scoreboard
#   <audio dir>                   MDA_SFX_win.wav / MDA_SFX_lose.wav (docs/sfx), MDA_SFX_vr_<win|lose><n>_<A|B>.wav and
#                                 MDA_SFX_vt_<title><n>_<A|B>.wav (gen_point_vo.sh 1.4), MDA_MUS_*.wav (gen_results_music.py)
# The page plays the show at the game's speed: in the Studio recording the 3D titles ran slow (Studio was not the focused
# window, so its frames came at about 15 a second and VictoryTitles caps each step at 0.05 s); each title's recorded
# animation is stretched back to its real length (VictoryTitles.LEN) and holds its last frame to the end of its slot, as
# the game does. The lower third's slam keeps real time (it runs on the clock, not the step).
# Usage: python3 -I tools/mockup/build_results_show_mock.py <rec dir> <audio dir> <out.html>
import base64, json, math, os, subprocess, sys, tempfile
rec_dir, aud_dir, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(os.path.join(rec_dir, "rec.json")))
d2 = json.load(open(os.path.join(rec_dir, "rec2.json")))
raw = open(os.path.join(rec_dir, "rec.bin"), "rb").read()
T1 = d["times"]
F1 = max(i + 1 for i, t in enumerate(T1) if t <= 35.0)  # frames kept (1-based last)

def quat(a):
    m00, m01, m02, m10, m11, m12, m20, m21, m22 = a[3:12]
    tr = m00 + m11 + m22
    if tr > 0:
        s = math.sqrt(tr + 1) * 2; w = .25 * s; x = (m21 - m12) / s; y = (m02 - m20) / s; z = (m10 - m01) / s
    elif m00 > m11 and m00 > m22:
        s = math.sqrt(1 + m00 - m11 - m22) * 2; w = (m21 - m12) / s; x = .25 * s; y = (m01 + m10) / s; z = (m02 + m20) / s
    elif m11 > m22:
        s = math.sqrt(1 + m11 - m00 - m22) * 2; w = (m02 - m20) / s; x = (m01 + m10) / s; y = .25 * s; z = (m12 + m21) / s
    else:
        s = math.sqrt(1 + m22 - m00 - m11) * 2; w = (m10 - m01) / s; x = (m02 + m20) / s; y = (m12 + m21) / s; z = .25 * s
    n = math.sqrt(x * x + y * y + z * z + w * w)
    return [round(x / n, 4), round(y / n, 4), round(z / n, 4), round(w / n, 4)]
r3 = lambda v: round(v, 3)
cams = []
for i in range(F1):
    c = d["cams"][i]
    a = c[0]
    cams.append([r3(a[0]), r3(a[1] - 3000), r3(a[2])] + quat(a) + [c[1], 1 if c[2] == "Scriptable" else 0])
rows = bytearray()
for i in range(0, len(raw), 18):
    f = int.from_bytes(raw[i:i + 2], "little")
    if f <= F1: rows += raw[i:i + 18]
def cfy(cf): return [cf[0], r3(cf[1] - 3000)] + cf[2:]
NI = set(range(54, 108)) | set(range(116, 120))  # elements of ScreenGuis that keep the top bar inset (the ability bar, the edge flash)
def fix_gui(src, inset=58):
    out = []
    for f, k, r in src["gch"]:
        if r != 0:
            r = list(r)
            if k in NI: r[0] = round(r[0] - inset, 1)  # the recorder added the inset to x as well; y is right
            else: r[1] = round(r[1] + inset, 1)          # AbsolutePosition starts under the top bar; screen y = y + inset
        out.append([f, k, r])
    return out
meta = {
    "times": T1[:F1], "cams": cams, "parts": [[p["sh"], p["m"]] for p in d["parts"]], "rows": len(rows) // 18,
    "looks": [l for l in d["looks"] if l[0] <= F1], "gone": [g for g in d["gone"] if g[0] <= F1],
    "emitters": [dict(e, cf=cfy(e["cf"])) for e in d["emitters"]],
    "bursts": [[b[0], b[1], cfy(b[2])] for b in d["bursts"] if b[0] <= F1],
    "emits": [[e[0], e[1], cfy(e[2]), e[3]] for e in d["emits"] if e[0] <= F1],
    "g1": {"vp": d["vp"], "times": T1[:F1], "objs": [g["cls"] for g in d["gobjs"]], "ch": [c for c in fix_gui(d) if c[0] <= F1]},
    "g2": {"vp": d2["vp"], "times": d2["times"], "objs": [g["cls"] for g in d2["gobjs"]], "ch": fix_gui(d2)},
}
# ---------- audio (mp3 data URIs) ----------
tmp = tempfile.mkdtemp()
def mp3(path, kbps=96):
    o = os.path.join(tmp, os.path.basename(path) + ".mp3")
    subprocess.check_call(["ffmpeg", "-v", "error", "-y", "-i", path, "-ac", "1", "-ar", "44100", "-c:a", "libmp3lame", "-b:a", f"{kbps}k", o])
    return "data:audio/mpeg;base64," + base64.b64encode(open(o, "rb").read()).decode()
A = lambda n: os.path.join(aud_dir, n)
snd = {"win": mp3(A("MDA_SFX_win.wav")), "lose": mp3(A("MDA_SFX_lose.wav")),
       "mus_vi": mp3(A("MDA_MUS_victory_intro.wav"), 128), "mus_vl": mp3(A("MDA_MUS_victory_loop.wav"), 128),
       "mus_dl": mp3(A("MDA_MUS_defeat_loop.wav"), 128)}
for v in "AB":
    for k in ("win", "lose"):
        for n in (1, 2, 3): snd[f"{k}{n}_{v}"] = mp3(A(f"MDA_SFX_vr_{k}{n}_{v}.wav"))
    for t in ("apex", "masher", "extinct", "carried"):
        for n in (1, 2, 3): snd[f"{t}{n}_{v}"] = mp3(A(f"MDA_SFX_vt_{t}{n}_{v}.wav"))
LINES = {"win": ["Mission accomplished.", "Good work. Match is ours.", "Victory. Well fought."],
         "lose": ["Mission failed.", "We lost this one. Regroup.", "Fall back. Regroup."]}
cl = {}
for l in open(os.path.join(aud_dir, "cmd_lines.txt")):
    if "=" in l: k, v = l.strip().split("=", 1); cl[k] = v
for t in ("apex", "masher", "extinct", "carried"): LINES[t] = [cl[f"{t}{n}"] for n in (1, 2, 3)]

HTML = r"""<meta charset="utf-8">
<title>Results Show Mockup</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=Fredoka:wght@500;600;700&family=Nunito:wght@600;700;800&family=Silkscreen:wght@400;700&family=Montserrat:wght@800;900&display=swap" rel="stylesheet">
<style>
:root { --page: #0d0f14; --panel: #14141a; --card: #1d2230; --line: #2b3242; --fg: #ffffff; --grey: #cfd3dc; --muted: #8f99aa;
  --accent: #ff9b2e; --yellow: #ffc21a; --good: #7dff9a; --blue: #5fb4ff; --pink: #ff6fb5; --new: #b88cff;
  --display: "Fredoka", "Trebuchet MS", system-ui, sans-serif; --body: "Nunito", "Segoe UI", system-ui, sans-serif; color-scheme: dark; }
* { box-sizing: border-box; }
[hidden] { display: none !important; }
body { margin: 0; background: var(--page); color: var(--fg); font: 15px/1.5 var(--body); padding-block: 18px 48px; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
main { max-width: 1120px; margin: 0 auto; display: grid; gap: 14px; }
main > * { min-width: 0; }
h1 { margin: 0; font: 700 clamp(22px, 4vw, 30px)/1.1 var(--display); text-wrap: balance; }
h1 span { color: var(--accent); }
h2 { margin: 0; font: 700 18px/1.2 var(--display); }
p { margin: 0; }
.lede { color: var(--muted); max-width: 92ch; }
.mode { display: flex; flex-wrap: wrap; gap: 8px; }
.mode button { font: 700 15px/1.2 var(--display); color: var(--fg); background: var(--card); border: 2px solid var(--line); border-radius: 12px; padding: 9px 14px; cursor: pointer; text-align: left; }
.mode button small { display: block; font: 700 12px var(--body); color: var(--muted); }
.mode button[aria-pressed="true"] { border-color: var(--yellow); box-shadow: 0 0 0 3px rgba(255,194,26,.2); }
.mode button.newm[aria-pressed="true"] { border-color: var(--new); box-shadow: 0 0 0 3px rgba(184,140,255,.25); }
.view { position: relative; width: 100%; aspect-ratio: 844 / 517; border-radius: 14px; overflow: hidden; border: 2px solid var(--line);
  background: linear-gradient(#5d9fd8, #bfe0f5 70%); }
.view canvas { position: absolute; inset: 0; width: 100%; height: 100%; display: block; }
.arena { position: absolute; inset: 0; background: radial-gradient(120% 80% at 50% 110%, #3c6b2d 0 38%, transparent 39%), linear-gradient(#6aa7d6, #a9d3ee 55%, #7fb15a 56%, #4f7f3a); filter: saturate(.9); }
.arena::after { content: "the arena (live game view, not recorded)"; position: absolute; left: 10px; top: 8px; font: 800 11px var(--body); color: rgba(255,255,255,.75); text-shadow: 0 1px 2px #000; }
.gui { position: absolute; left: 0; top: 0; transform-origin: 0 0; pointer-events: none; }
.gui > div { position: absolute; display: flex; overflow: visible; white-space: pre; }
.badge { position: absolute; right: 10px; bottom: 10px; font: 800 12px var(--body); background: rgba(13,15,20,.78); border: 1px solid var(--line); border-radius: 999px; padding: 4px 10px; color: var(--grey); pointer-events: none; }
.sub { position: absolute; left: 50%; top: 3%; transform: translateX(-50%); max-width: 80%; text-align: center; font: 800 clamp(11px, 1.8vw, 16px)/1.3 var(--body); color: #fff; background: rgba(13,15,20,.72); border-radius: 10px; padding: 5px 12px; pointer-events: none; }
.sub b { color: var(--new); }
.start { position: absolute; inset: 0; display: grid; place-items: center; background: rgba(8,10,14,.55); border: 0; cursor: pointer; color: #fff; font: 700 clamp(18px, 3vw, 26px) var(--display); }
.start span { background: var(--accent); color: #1a0f00; border-radius: 999px; padding: 12px 26px; }
.bar { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
.btn { font: 800 13px var(--body); color: var(--fg); background: var(--card); border: 2px solid var(--line); border-radius: 10px; padding: 7px 12px; cursor: pointer; }
.btn.go { background: var(--accent); border-color: var(--accent); color: #1a0f00; }
.btn[aria-pressed="true"] { border-color: var(--yellow); }
button:focus-visible { outline: 3px solid var(--yellow); outline-offset: 2px; }
.clock { font: 800 13px var(--body); color: var(--muted); font-variant-numeric: tabular-nums; margin-left: auto; }
.tl { background: var(--panel); border: 2px solid var(--line); border-radius: 14px; padding: 10px 12px; display: grid; gap: 6px; }
.lane { display: grid; grid-template-columns: 150px minmax(0, 1fr); gap: 8px; align-items: center; }
@media (max-width: 640px) { .lane { grid-template-columns: 92px minmax(0, 1fr); } }
.lane > span { font: 800 11px var(--body); color: var(--muted); text-transform: uppercase; letter-spacing: .05em; }
.lane > span.n { color: var(--new); }
.track { position: relative; height: 22px; background: var(--card); border-radius: 6px; overflow: hidden; cursor: pointer; }
.seg { position: absolute; top: 0; bottom: 0; font: 800 10px/22px var(--body); padding-left: 5px; white-space: nowrap; overflow: hidden; border-left: 2px solid var(--page); color: #10131a; }
.head { position: absolute; top: 0; bottom: 0; width: 2px; background: #fff; pointer-events: none; }
.cols { display: grid; grid-template-columns: minmax(0, 1.15fr) minmax(0, 1fr); gap: 12px; }
@media (max-width: 860px) { .cols { grid-template-columns: minmax(0, 1fr); } }
.card { background: var(--panel); border: 2px solid var(--line); border-radius: 14px; padding: 12px 14px; display: grid; gap: 10px; align-content: start; min-width: 0; }
.card.newc { border-color: rgba(184,140,255,.45); }
.sw { display: grid; grid-template-columns: auto minmax(0, 1fr); gap: 10px; align-items: start; }
.sw input { width: 20px; height: 20px; margin-top: 2px; accent-color: var(--new); }
.sw b { font: 700 15px var(--display); }
.sw small { display: block; color: var(--grey); font-size: 13px; }
.picks { display: grid; gap: 6px; }
.pk { display: grid; grid-template-columns: 112px minmax(0, 1fr); gap: 8px; align-items: center; }
@media (max-width: 640px) { .pk { grid-template-columns: minmax(0, 1fr); } }
.pk > span { font: 800 12px var(--body); color: var(--yellow); }
.pk.roast > span { color: var(--pink); }
.opts { display: flex; flex-wrap: wrap; gap: 4px; }
.opts button { font: 700 12px/1.25 var(--body); color: var(--grey); background: var(--card); border: 2px solid var(--line); border-radius: 8px; padding: 4px 8px; cursor: pointer; text-align: left; max-width: 100%; }
.opts button[aria-pressed="true"] { border-color: var(--new); color: #fff; }
ul { margin: 0; padding-left: 18px; color: var(--grey); }
li + li { margin-top: 4px; }
.k { color: var(--muted); font-size: 13px; }
</style>
<main>
  <header>
    <h1><span>End of match</span> · today's show + the proposed audio</h1>
    <p class="lede">The picture is the game itself: recorded in Studio from a real practice match (you won 999 to 120), every part and every bit of on-screen text where the game drew it. Switch between what the game does today and the proposed version to hear the difference. Turn your sound on.</p>
  </header>
  <div class="mode" role="group" aria-label="Version">
    <button id="mToday" aria-pressed="false">Today<small>what's in the game now</small></button>
    <button id="mNew" class="newm" aria-pressed="true">Proposed<small>today + the new layers below</small></button>
  </div>
  <div class="view" id="view">
    <div class="arena" id="arena"></div>
    <canvas id="cv"></canvas>
    <div class="gui" id="gui1"></div>
    <div class="gui" id="gui2"></div>
    <div class="sub" id="sub" hidden></div>
    <div class="badge" id="badge"></div>
    <button class="start" id="startB"><span>▶ Play the end of the match</span></button>
  </div>
  <div class="bar">
    <button class="btn go" id="play">Pause</button>
    <button class="btn" id="restart">Restart</button>
    <button class="btn" id="skip">Tap to skip (next title)</button>
    <span class="clock" id="clock">0.0 s</span>
  </div>
  <section class="tl" aria-label="Timeline">
    <div class="lane"><span>Screen</span><div class="track" id="tScreen"></div></div>
    <div class="lane"><span>Win sting</span><div class="track" id="tSting"></div></div>
    <div class="lane"><span class="n">Result line</span><div class="track" id="tRes"></div></div>
    <div class="lane"><span class="n">Victory music</span><div class="track" id="tMus"></div></div>
    <div class="lane"><span class="n">Title lines</span><div class="track" id="tTit"></div></div>
  </section>
  <div class="cols">
    <section class="card newc" aria-label="The new layers">
      <h2>The new layers <span class="k">(each one its own switch in the game)</span></h2>
      <label class="sw"><input type="checkbox" id="swRes" checked><span><b>Commander result line</b><small>Right after the win sting, while the VICTORY banner is up. Ends before the first title.</small></span></label>
      <label class="sw"><input type="checkbox" id="swMus" checked><span><b>Victory music</b><small>Takes over from the island music for the whole results; fades out when the lobby comes back. Placeholder track (made for this page); the real one gets picked later.</small></span></label>
      <label class="sw"><input type="checkbox" id="swTit" checked><span><b>Commander title lines</b><small>One line as each title slams in. Only the winning team hears them. Never two voices at once.</small></span></label>
      <label class="sw"><input type="checkbox" id="swDuck" checked><span><b>Music dips under the voice</b><small>To about a third while the commander talks, back up after.</small></span></label>
      <div class="bar"><span class="k">Commander</span>
        <button class="btn" data-voice="A" aria-pressed="true">A · US</button><button class="btn" data-voice="B" aria-pressed="false">B · British</button></div>
      <div class="picks" id="picks"></div>
    </section>
    <section class="card" aria-label="What you're seeing">
      <h2>What you're seeing</h2>
      <ul>
        <li><b>0–2 s</b> the HUD's VICTORY banner over the arena (the arena itself wasn't recorded, so it's a plain backdrop here).</li>
        <li><b>2–26 s</b> the four titles on the stage in the sky, exactly as recorded: APEX PREDATOR, BUTTON MASHER, EXTINCT, CARRIED.</li>
        <li><b>26–33 s</b> the scoreboard, then the lobby. The scoreboard is from a second run of the same test (in the first run Studio played the titles too slowly and they ran over it), so its numbers don't match the titles.</li>
        <li>Today the island music (Bit Quest) keeps playing under all of this; it isn't in this page. In the proposed version it fades out at the end of the match.</li>
        <li>Recorded in Studio: Studio wasn't the focused window, so the titles ran slow there. This page plays each one at the game's real speed.</li>
      </ul>
      <h2>The losing team</h2>
      <p class="k">Same screens. They hear the lose sting, a defeat line and calmer music, and no title lines.</p>
      <div class="bar"><button class="btn" id="loseB">▶ Hear the losing side</button><span class="k" id="loseL"></span></div>
    </section>
  </div>
</main>
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
<script>
const META = __META__, BIN = "__BIN__", SND = __SND__, LINES = __LINES__;
const $ = id => document.getElementById(id);
// ---------- the show's timeline (game seconds from the end of the match) ----------
const PRE = -1.0, BANNER = 2.0, S = [2.0, 7.7, 13.4, 19.5], SLOT = [5.7, 5.7, 6.1, 6.7], LEN = [5.4, 5.4, 5.8, 6.4];
const RS = [3.896, 10.915, 18.37, 26.431], RD = [7.019, 7.455, 8.061, 8.51], R1 = 1.802, R2 = 1.784;
const SHOW_END = 26.2, END = 33.2;
const TITLES = [["apex", "APEX PREDATOR", false], ["masher", "BUTTON MASHER", false], ["extinct", "EXTINCT", true], ["carried", "CARRIED", true]];
function mapT(g) {
  if (g < BANNER) return {d3: null, gsrc: 1, gt: R1 + g};
  if (g < SHOW_END) {
    let i = 3; while (i > 0 && g < S[i]) i--;
    const a = g - S[i];
    const rt = a < LEN[i] ? RS[i] + a * RD[i] / LEN[i] : RS[i] + RD[i] - 0.034;
    return {d3: rt, gsrc: 1, gt: a < 0.55 ? RS[i] + a : Math.max(RS[i] + 0.55, rt), i};
  }
  return {d3: null, gsrc: 2, gt: R2 + Math.min(g, END)};
}
// ---------- 3D ----------
const cv = $("cv"), view = $("view");
const renderer = new THREE.WebGLRenderer({canvas: cv, antialias: true, alpha: true});
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
renderer.shadowMap.enabled = true;
const scene = new THREE.Scene();
scene.fog = new THREE.Fog(0xbfdcef, 500, 1500);
const cam = new THREE.PerspectiveCamera(36, 844 / 517, 0.5, 4000);
scene.add(new THREE.HemisphereLight(0xffffff, 0x6d7f4c, 0.8));
const sun = new THREE.DirectionalLight(0xffffff, 0.7);
sun.position.set(60, 120, 40); sun.castShadow = true; sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, {left: -60, right: 60, top: 60, bottom: -60, near: 1, far: 400});
scene.add(sun, sun.target);
const GEO = {Block: new THREE.BoxGeometry(1, 1, 1), Ball: new THREE.SphereGeometry(0.5, 14, 10)};
GEO.Cylinder = new THREE.CylinderGeometry(0.5, 0.5, 1, 20); GEO.Cylinder.rotateZ(Math.PI / 2);
GEO.Wedge = (() => { const v = [[-.5, -.5, -.5], [.5, -.5, -.5], [.5, -.5, .5], [-.5, -.5, .5], [-.5, .5, .5], [.5, .5, .5]];
  const f = [[0, 2, 1], [0, 3, 2], [3, 4, 5], [3, 5, 2], [0, 1, 5], [0, 5, 4], [0, 4, 3], [1, 2, 5]]; const pos = [];
  f.forEach(t => t.forEach(i => pos.push(...v[i]))); const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3)); g.computeVertexNormals(); return g; })();
const bin = (() => { const s = atob(BIN), u = new Uint8Array(s.length); for (let i = 0; i < s.length; i++) u[i] = s.charCodeAt(i); return new DataView(u.buffer); })();
const NP = META.parts.length, NR = META.rows;
const P = META.parts.map(([sh, m]) => ({sh, m, rows: [], looks: [], gone: [], mesh: null}));
for (let r = 0; r < NR; r++) { const o = r * 18; P[bin.getUint16(o + 2, true) - 1].rows.push(r); }
META.looks.forEach(l => P[l[1] - 1].looks.push(l));
META.gone.forEach(g => P[g[1] - 1].gone.push(g[0]));
const rf = r => bin.getUint16(r * 18, true);
P.forEach(p => {
  if (!p.rows.length) return;
  const neon = p.m === "Neon";
  const mat = neon ? new THREE.MeshBasicMaterial({color: 0xffffff}) : new THREE.MeshLambertMaterial({color: 0xffffff});
  const mesh = new THREE.Mesh(GEO[p.sh] || GEO.Block, mat); mesh.matrixAutoUpdate = false; mesh.castShadow = !neon; mesh.receiveShadow = true; mesh.visible = false;
  scene.add(mesh); p.mesh = mesh; p.neon = neon; p.f0 = rf(p.rows[0]);
});
const _p0 = new THREE.Vector3(), _p1 = new THREE.Vector3(), _q0 = new THREE.Quaternion(), _q1 = new THREE.Quaternion(), _s = new THREE.Vector3();
function rowPose(r, pos, q) { const o = r * 18 + 4; pos.set(bin.getInt16(o, true) / 50, bin.getInt16(o + 2, true) / 50, bin.getInt16(o + 4, true) / 50);
  q.set(bin.getInt16(o + 6, true) / 32767, bin.getInt16(o + 8, true) / 32767, bin.getInt16(o + 10, true) / 32767, bin.getInt16(o + 12, true) / 32767).normalize(); }
function lastLE(arr, key, v) { let lo = 0, hi = arr.length - 1, ans = -1; while (lo <= hi) { const m = (lo + hi) >> 1; if (key(arr[m]) <= v) { ans = m; lo = m + 1; } else hi = m - 1; } return ans; }
function frameOf(times, t) { const i = lastLE(times, x => x, t); if (i < 0) return [1, 0]; if (i >= times.length - 1) return [times.length, 0]; return [i + 1, (t - times[i]) / (times[i + 1] - times[i])]; }
function draw3D(rt) {
  const [f, u] = frameOf(META.times, rt);
  for (const p of P) {
    if (!p.mesh) continue;
    const k = lastLE(p.rows, rf, f);
    if (k < 0) { p.mesh.visible = false; continue; }
    const r = p.rows[k], fr = rf(r);
    const gi = lastLE(p.gone, x => x, f);
    if (gi >= 0 && p.gone[gi] > fr) { p.mesh.visible = false; continue; }
    const li = lastLE(p.looks, l => l[0], f); const L = li >= 0 ? p.looks[li] : null;
    if (!L || L[3] >= 0.99) { p.mesh.visible = false; continue; }
    rowPose(r, _p0, _q0);
    if (u > 0 && k + 1 < p.rows.length && rf(p.rows[k + 1]) === fr + 1) { rowPose(p.rows[k + 1], _p1, _q1); _p0.lerp(_p1, u); _q0.slerp(_q1, u); }
    _s.set(L[2][0], L[2][1], L[2][2]);
    p.mesh.matrix.compose(_p0, _q0, _s); p.mesh.visible = true;
    if (p._c !== L[4]) { p.mesh.material.color.set("#" + L[4]); p._c = L[4]; }
    const op = 1 - L[3]; if (p._o !== op) { p.mesh.material.transparent = op < 0.999; p.mesh.material.opacity = op; p.mesh.material.depthWrite = op > 0.6; p._o = op; }
  }
  const C = META.cams, i = Math.min(C.length - 1, f - 1), j = Math.min(C.length - 1, i + 1), a = C[i], b = C[j];
  cam.position.set(a[0], a[1], a[2]); _q0.set(a[3], a[4], a[5], a[6]);
  if (u > 0) { cam.position.lerp(_p1.set(b[0], b[1], b[2]), u); _q0.slerp(_q1.set(b[3], b[4], b[5], b[6]), u); }
  cam.quaternion.copy(_q0); cam.fov = a[7]; cam.updateProjectionMatrix();
  drawParticles(rt);
  renderer.render(scene, cam);
}
// particles (the few the titles make), worked out up front, seeded
const PT = [];
(() => { let seed = 99; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647; const DIR = {Top: [0, 1, 0], Bottom: [0, -1, 0], Front: [0, 0, -1], Back: [0, 0, 1], Right: [1, 0, 0], Left: [-1, 0, 0]};
  function spawn(E, cf, t0, n) { const m = new THREE.Matrix4().set(cf[3], cf[4], cf[5], cf[0], cf[6], cf[7], cf[8], cf[1], cf[9], cf[10], cf[11], cf[2], 0, 0, 0, 1);
    const o = new THREE.Vector3().setFromMatrixPosition(m), base = new THREE.Vector3(...(DIR[E.dir] || DIR.Top)).applyMatrix4(new THREE.Matrix4().extractRotation(m)).normalize();
    for (let k = 0; k < n; k++) { const sp = (E.spread || 0) * Math.PI / 180 * rnd(), az = rnd() * Math.PI * 2; const a = Math.abs(base.y) < 0.9 ? new THREE.Vector3(0, 1, 0) : new THREE.Vector3(1, 0, 0);
      const u1 = new THREE.Vector3().crossVectors(base, a).normalize(), w = new THREE.Vector3().crossVectors(base, u1);
      const dir = base.clone().multiplyScalar(Math.cos(sp)).addScaledVector(u1, Math.sin(sp) * Math.cos(az)).addScaledVector(w, Math.sin(sp) * Math.sin(az));
      PT.push({t0, o, v: dir.multiplyScalar(E.sp0 + (E.sp - E.sp0) * rnd()), life: Math.max(0.05, E.life0 + (E.life - E.life0) * rnd()), E, c0: new THREE.Color("#" + E.c0), c1: new THREE.Color("#" + E.c1)}); } }
  META.bursts.forEach(([f, k, cf]) => spawn(META.emitters[k - 1], cf, META.times[f - 1], 12));
  const acc = {}; META.emits.forEach(([f, k, cf, rate]) => { acc[k] = (acc[k] || 0) + rate / 30; const n = Math.floor(acc[k]); acc[k] -= n; if (n > 0) spawn(META.emitters[k - 1], cf, META.times[f - 1], Math.min(n, 6)); });
})();
const pool = []; const pgeo = new THREE.IcosahedronGeometry(0.5, 1);
for (let k = 0; k < 300; k++) { const m = new THREE.Mesh(pgeo, new THREE.MeshBasicMaterial({transparent: true, depthWrite: false})); m.visible = false; scene.add(m); pool.push(m); }
function drawParticles(t) { let n = 0;
  for (const q of PT) { const a = t - q.t0; if (a < 0 || a > q.life || n >= pool.length) continue; const m = pool[n++], k = a / q.life, E = q.E;
    m.visible = true; m.material.blending = E.le > 0.3 ? THREE.AdditiveBlending : THREE.NormalBlending; m.position.copy(q.o).addScaledVector(q.v, a);
    m.scale.setScalar(Math.max(0.05, E.s0 + (E.s1 - E.s0) * k)); m.material.color.copy(q.c0).lerp(q.c1, k); m.material.opacity = Math.max(0, (1 - E.t0) * (1 - k) * 0.7); }
  for (; n < pool.length; n++) pool[n].visible = false; }
// ---------- on-screen layers, replayed from the recordings ----------
const FONT = {Unknown: ["Silkscreen", 700], GothamBlack: ["Montserrat", 900], GothamBold: ["Montserrat", 800], FredokaOne: ["Fredoka", 700], Legacy: ["Arial", 400]};
const rgba = (h, tr) => { const n = parseInt(h, 16); return `rgba(${n >> 16},${(n >> 8) & 255},${n & 255},${(1 - tr).toFixed(3)})`; };
function rich(s) { const esc = s.replace(/&(?!amp;|lt;|gt;)/g, "&amp;"); return esc.replace(/<font([^>]*)>/g, (m, a) => { const c = /color="([^"]+)"/.exec(a), z = /size="(\d+)"/.exec(a);
  return `<span style="${c ? "color:" + c[1] + ";" : ""}${z ? "font-size:" + z[1] + "px;" : ""}">`; }).replace(/<\/font>/g, "</span>").replace(/<(?!\/?(span|b|i)\b)/g, "&lt;"); }
function makeGui(G, el) {
  el.style.width = G.vp[0] + "px"; el.style.height = G.vp[1] + "px";
  return {G, el, f: 0, st: new Map(), divs: new Map(), ci: 0};
}
const GU = [makeGui(META.g1, $("gui1")), makeGui(META.g2, $("gui2"))];
function paint(div, r) {
  const s = div.style;
  s.left = r[0] + "px"; s.top = r[1] + "px"; s.width = r[2] + "px"; s.height = r[3] + "px"; s.transform = r[4] ? `rotate(${r[4]}deg)` : "";
  s.zIndex = r[8]; s.borderRadius = r[7] ? r[7] + "px" : "";
  const grad = r[10];
  s.background = r[6] >= 0.999 ? "transparent" : grad ? `linear-gradient(${90 + grad[2]}deg, ${rgba(grad[0], r[6])}, ${rgba(grad[1], r[6])})` : rgba(r[5], r[6]);
  const st = r[9];
  s.outline = st && st[3] === "Border" ? `${st[0]}px solid ${rgba(st[1], st[2])}` : "";
  const t = r[11];
  if (t && t[0] !== "" && t[2] < 0.999) {
    const [txt, col, tt, sto, stc, font, size, xa, ya, wrap, isRich] = t, F = FONT[font] || FONT.Unknown;
    s.fontFamily = `"${F[0]}", system-ui, sans-serif`; s.fontWeight = F[1]; s.fontSize = size + "px"; s.lineHeight = "1"; s.color = rgba(col, tt);
    s.justifyContent = xa === "Left" ? "flex-start" : xa === "Right" ? "flex-end" : "center"; s.alignItems = ya === "Top" ? "flex-start" : ya === "Bottom" ? "flex-end" : "center";
    s.textAlign = xa.toLowerCase(); s.whiteSpace = wrap ? "normal" : "pre";
    const sh = [];
    if (sto < 0.999) { const c = rgba(stc, sto); sh.push(`1px 0 0 ${c}`, `-1px 0 0 ${c}`, `0 1px 0 ${c}`, `0 -1px 0 ${c}`, `1px 1px 0 ${c}`, `-1px -1px 0 ${c}`); }
    if (st && st[3] === "Contextual") { const c = rgba(st[1], st[2]), w = Math.max(1, st[0]); for (let a = 0; a < 8; a++) sh.push(`${(Math.cos(a * Math.PI / 4) * w).toFixed(1)}px ${(Math.sin(a * Math.PI / 4) * w).toFixed(1)}px 0 ${c}`); }
    s.textShadow = sh.join(",");
    const html = isRich ? rich(txt) : txt.replace(/&/g, "&amp;").replace(/</g, "&lt;");
    if (div._h !== html) { div.innerHTML = `<span>${html}</span>`; div._h = html; }
  } else if (div._h) { div.innerHTML = ""; div._h = ""; }
}
function guiTo(U, t) {
  const [f] = frameOf(U.G.times, t);
  if (f < U.f) { U.st.clear(); U.ci = 0; U.divs.forEach(d => d.remove()); U.divs.clear(); }
  const ch = U.G.ch;
  const dirty = new Set();
  while (U.ci < ch.length && ch[U.ci][0] <= f) { const [, k, r] = ch[U.ci++]; if (r === 0) U.st.delete(k); else U.st.set(k, r); dirty.add(k); }
  U.f = f;
  dirty.forEach(k => {
    const r = U.st.get(k);
    let div = U.divs.get(k);
    if (!r) { if (div) { div.remove(); U.divs.delete(k); } return; }
    if (!div) { div = document.createElement("div"); U.el.appendChild(div); U.divs.set(k, div); }
    paint(div, r);
  });
}
function fitGui() {
  const w = view.clientWidth, h = view.clientHeight;
  GU.forEach(U => { U.el.style.transform = `scale(${w / U.G.vp[0]}, ${h / U.G.vp[1]})`; });
  const pr = renderer.getPixelRatio();
  if (cv.width !== Math.round(w * pr) || cv.height !== Math.round(h * pr)) { renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); }
}
// ---------- audio ----------
let actx = null, master = null, musGain = null, live = [];
const bufs = {};
function ctx() { if (!actx) { actx = new (window.AudioContext || window.webkitAudioContext)(); master = actx.createGain(); master.connect(actx.destination); } if (actx.state === "suspended") actx.resume(); return actx; }
function decode(k) { if (!bufs[k]) { const s = SND[k], b = atob(s.slice(s.indexOf(",") + 1)), u = new Uint8Array(b.length); for (let i = 0; i < b.length; i++) u[i] = b.charCodeAt(i); bufs[k] = new Promise((ok, no) => actx.decodeAudioData(u.buffer, ok, no)); } return bufs[k]; }
const VOL = {sting: 0.7, voice: 0.8, music: 0.4};
let mode = "new", voice = "A", pick = {win: 0, apex: 0, masher: 0, extinct: 0, carried: 0};
const sw = () => ({res: $("swRes").checked, mus: $("swMus").checked, tit: $("swTit").checked, duck: $("swDuck").checked});
let DUR = {};
async function loadAll() { ctx(); const ks = Object.keys(SND); const bs = await Promise.all(ks.map(decode)); ks.forEach((k, i) => DUR[k] = bs[i].duration); }
function plan() { // the events, in game seconds
  const s = sw(), ev = [];
  ev.push({lane: "sting", key: "win", at: 0, vol: VOL.sting, label: "win sting"});
  if (mode === "today") return ev;
  let busy = -1;
  if (s.res) { const k = `win${pick.win + 1}_${voice}`; ev.push({lane: "res", key: k, at: 0.3, vol: VOL.voice, voice: true, label: LINES.win[pick.win]}); busy = 0.3 + (DUR[k] || 1.5); }
  if (s.tit) TITLES.forEach(([id, name], i) => {
    const k = `${id}${pick[id] + 1}_${voice}`; let at = S[i] + 0.3; const d = DUR[k] || 3;
    if (at < busy + 0.15) at = busy + 0.15; // one voice at a time
    if (at > S[i] + 1.3) return; // too late: skipped
    ev.push({lane: "tit", key: k, at, vol: VOL.voice, voice: true, label: `${name}: ${LINES[id][pick[id]]}`}); busy = at + d;
  });
  if (s.mus) ev.push({lane: "mus", key: "music", at: 1.0, end: END, label: "victory music"});
  return ev;
}
let play = {on: false, g0: PRE, t0: 0, g: PRE, started: false};
function stopAll() { live.forEach(n => { try { n.stop(); } catch (e) {} }); live = []; if (musGain) { try { musGain.disconnect(); } catch (e) {} musGain = null; } }
function src(key, when, offset, gain, dest) { const b = bufs[key]; if (!b) return; b.then(buf => { if (!play.on && !loseOn) return; const s = actx.createBufferSource(); s.buffer = buf; const g = actx.createGain(); g.gain.value = gain; s.connect(g).connect(dest || master); s.start(when, offset); live.push(s); }); }
function schedule() {
  stopAll(); if (!play.on) return;
  const ev = plan(), now = actx.currentTime, g = play.g;
  const at = x => now + Math.max(0, x - g);
  ev.forEach(e => {
    if (e.key === "music") {
      musGain = actx.createGain(); musGain.connect(master);
      const G = musGain.gain, base = VOL.music;
      G.setValueAtTime(0, now);
      const fadeIn = e.at, fadeEnd = END - 1.5;
      const lvl = x => (x < fadeIn ? 0 : x < fadeIn + 0.6 ? base * (x - fadeIn) / 0.6 : x < fadeEnd ? base : x < END ? base * (END - x) / 1.5 : 0);
      G.setValueAtTime(lvl(g), now);
      if (g < fadeIn + 0.6) G.linearRampToValueAtTime(base, at(fadeIn + 0.6));
      const duck = sw().duck ? ev.filter(v => v.voice) : [];
      duck.forEach(v => { const d = DUR[v.key] || 2; if (v.at + d < g) return; const a0 = Math.max(g, v.at - 0.12);
        G.setValueAtTime(lvl(a0), at(a0)); G.linearRampToValueAtTime(base * 0.35, at(Math.max(a0, v.at))); G.setValueAtTime(base * 0.35, at(v.at + d)); G.linearRampToValueAtTime(lvl(v.at + d + 0.4), at(v.at + d + 0.4)); });
      G.setValueAtTime(base, at(Math.max(g, fadeEnd))); G.linearRampToValueAtTime(0, at(END));
      const iL = DUR.mus_vi || 3.64, lL = DUR.mus_vl || 7.27;
      // intro then the loop
      if (g < e.at + iL) src("mus_vi", at(e.at), Math.max(0, g - e.at), 1, musGain);
      bufs.mus_vl.then(buf => { if (!play.on || !musGain) return; const s = actx.createBufferSource(); s.buffer = buf; s.loop = true; s.connect(musGain);
        const st = e.at + iL; if (g < st) s.start(at(st)); else s.start(now, (g - st) % lL); live.push(s); });
      return;
    }
    const d = DUR[e.key] || 2;
    if (e.at + d < g) return;
    src(e.key, at(e.at), Math.max(0, g - e.at), e.vol);
  });
  drawLanes(ev);
}
// ---------- loop ----------
function gNow() { return play.on ? play.g0 + (actx.currentTime - play.t0) : play.g; }
function setG(g) { play.g = Math.max(PRE, Math.min(END, g)); if (play.on) { play.g0 = play.g; play.t0 = actx.currentTime; schedule(); } render(); }
function render() {
  const g = play.g, m = mapT(Math.max(g, PRE));
  fitGui();
  const in3d = m.d3 !== null;
  cv.style.visibility = in3d ? "visible" : "hidden"; $("arena").hidden = in3d;
  if (in3d) draw3D(m.d3);
  GU[0].el.hidden = m.gsrc !== 1; GU[1].el.hidden = m.gsrc !== 2;
  guiTo(GU[m.gsrc - 1], m.gt);
  $("clock").textContent = `${g.toFixed(1)} s`;
  const seg = g < 0 ? "Match ends" : g < BANNER ? "VICTORY banner" : g < SHOW_END ? TITLES[m.i][1] : "Scoreboard";
  $("badge").textContent = `${mode === "today" ? "Today" : "Proposed"} · ${seg}`;
  document.querySelectorAll(".head").forEach(h => h.style.left = `${(g - PRE) / (END - PRE) * 100}%`);
  // what the commander is saying right now
  const ev = mode === "today" ? [] : plan().filter(e => e.voice && g >= e.at && g < e.at + (DUR[e.key] || 2));
  $("sub").hidden = !ev.length; if (ev.length) $("sub").innerHTML = `<b>Commander:</b> ${ev[0].label.replace(/^[A-Z ]+: /, "")}`;
}
function frame() {
  if (play.on) { play.g = gNow(); if (play.g >= END) { play.g = END; pause(); } }
  render(); requestAnimationFrame(frame);
}
function pause() { play.on = false; stopAll(); $("play").textContent = "Play"; }
async function start(g) {
  ctx(); if (!Object.keys(DUR).length) await loadAll();
  play.on = true; play.g0 = g; play.g = g; play.t0 = actx.currentTime; $("play").textContent = "Pause"; $("startB").hidden = true; schedule();
}
// ---------- timeline lanes ----------
const pct = x => `${(Math.max(PRE, x) - PRE) / (END - PRE) * 100}%`, wid = (a, b) => `${(Math.min(END, b) - Math.max(PRE, a)) / (END - PRE) * 100}%`;
function lane(el, segs) { el.innerHTML = segs.map(([a, b, c, l]) => `<div class="seg" style="left:${pct(a)};width:${wid(a, b)};background:${c}" title="${l}">${l}</div>`).join("") + `<div class="head"></div>`; }
lane($("tScreen"), [[PRE, 0, "#3a4252", "match"], [0, BANNER, "#9fb6d6", "VICTORY"]].concat(TITLES.map(([, n, r], i) => [S[i], S[i] + SLOT[i], r ? "#ff9fc8" : "#ffd45a", n])).concat([[SHOW_END, END, "#9fb6d6", "Scoreboard"]]));
function drawLanes(ev) {
  const by = l => ev.filter(e => e.lane === l).map(e => [e.at, e.key === "music" ? e.end : e.at + (DUR[e.key] || 1.5), e.lane === "sting" ? "#ffc21a" : e.lane === "mus" ? "#7dff9a" : "#c9a8ff", e.lane === "tit" ? e.label.split(":")[0] : e.label]);
  lane($("tSting"), by("sting")); lane($("tRes"), by("res")); lane($("tMus"), by("mus")); lane($("tTit"), by("tit"));
}
document.querySelectorAll(".track").forEach(t => t.addEventListener("click", e => { const r = t.getBoundingClientRect(); const g = PRE + (e.clientX - r.left) / r.width * (END - PRE); if (!play.on && !play.started) { play.started = true; start(g); } else setG(g); }));
// ---------- controls ----------
function picksUI() {
  const rows = [["win", "Result line", false]].concat(TITLES.map(([id, n, r]) => [id, n, r]));
  $("picks").innerHTML = rows.map(([id, n, r]) => `<div class="pk${r ? " roast" : ""}"><span>${n}</span><div class="opts">${LINES[id].map((l, i) => `<button data-pk="${id}" data-i="${i}" aria-pressed="${pick[id] === i}">${l}</button>`).join("")}</div></div>`).join("");
}
$("picks").addEventListener("click", e => { const b = e.target.closest("[data-pk]"); if (!b) return; pick[b.dataset.pk] = +b.dataset.i; picksUI(); if (play.on) setG(gNow()); else drawLanes(plan()); });
document.querySelectorAll("[data-voice]").forEach(b => b.onclick = () => { voice = b.dataset.voice; document.querySelectorAll("[data-voice]").forEach(x => x.setAttribute("aria-pressed", x === b)); if (play.on) setG(gNow()); });
["swRes", "swMus", "swTit", "swDuck"].forEach(id => $(id).addEventListener("change", () => { if (play.on) setG(gNow()); else drawLanes(plan()); }));
function setMode(m) { mode = m; $("mToday").setAttribute("aria-pressed", m === "today"); $("mNew").setAttribute("aria-pressed", m === "new"); if (play.on) setG(gNow()); else drawLanes(plan()); }
$("mToday").onclick = () => setMode("today"); $("mNew").onclick = () => setMode("new");
$("startB").onclick = () => { play.started = true; start(PRE); };
$("play").onclick = () => { if (play.on) pause(); else { play.started = true; start(play.g >= END ? PRE : play.g); } };
$("restart").onclick = () => { play.started = true; if (play.on) setG(PRE); else start(PRE); };
$("skip").onclick = () => { const g = play.on ? gNow() : play.g; const nx = S.find(s => s > g + 0.05); const to = nx !== undefined ? nx : SHOW_END; if (play.on) setG(to); else { play.g = to; render(); } };
// the losing side, on its own
let loseOn = false;
$("loseB").onclick = async () => {
  ctx(); if (!Object.keys(DUR).length) await loadAll();
  pause(); loseOn = true;
  const n = actx.currentTime, k = `lose${pick.win + 1}_${voice}`;
  src("lose", n, 0, VOL.sting); src(k, n + 0.3, 0, VOL.voice);
  musGain = actx.createGain(); musGain.connect(master); const G = musGain.gain; const d = DUR[k] || 1.5;
  G.setValueAtTime(0, n); G.linearRampToValueAtTime(VOL.music, n + 1.6); if (sw().duck) { G.setValueAtTime(VOL.music, n + 1.0); }
  G.setValueAtTime(VOL.music, n + 9); G.linearRampToValueAtTime(0, n + 10.5);
  src("mus_dl", n + 1.0, 0, 1, musGain);
  $("loseL").textContent = `lose sting · "${LINES.lose[pick.win]}" · defeat music`;
  setTimeout(() => { if (loseOn) { loseOn = false; stopAll(); $("loseL").textContent = ""; } }, 10800);
};
picksUI(); drawLanes(plan());
window.addEventListener("resize", render);
play.g = 4.6; // first look: a title on screen behind the start button
requestAnimationFrame(frame);
window.__show = {seek(g) { play.g = g; render(); }, state: () => ({g: play.g, parts: P.filter(p => p.mesh && p.mesh.visible).length, gui: GU.map(U => U.divs.size)})};
</script>
"""
html = (HTML.replace("__META__", json.dumps(meta, separators=(",", ":")))
        .replace("__BIN__", base64.b64encode(bytes(rows)).decode())
        .replace("__SND__", json.dumps(snd))
        .replace("__LINES__", json.dumps(LINES)))
open(out_path, "w").write(html)
print("ok", out_path, round(os.path.getsize(out_path) / 1e6, 2), "MB", "frames", F1, "rows", len(rows) // 18)
