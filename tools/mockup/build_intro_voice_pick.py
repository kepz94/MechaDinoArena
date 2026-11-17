# build_intro_voice_pick.py v1.0 (Mecha Dino Arena) — the pre-match intro voice line pick page (MDA-552, round 13; Kepu
# 2026-11-17 12:58 "how about a voice playing in the background for the brief intro to like get to the Hardpoint. Use your mecha
# upgrades to your advantage. Some type of dialogue like that"). Five lines in the round 12 voice A (Field radio), placed on the
# 10 s pre-match countdown as the game runs it (PrematchCam 1.0: pan out 9-7 s left, orbit the point 7-5, back 5-3; GameSounds
# ticks at 3, 2, 1 and "go" at 0). A line starts with the pan (9 s left) and ends before the first tick. Pick one or more
# (several = a different one each match). Lines: Kokoro-82M (Apache-2.0), recipe docs/sfx/gen_point_vo.sh; audio not in the repo.
# Usage: python3 tools/mockup/build_intro_voice_pick.py <dir with MDA_SFX_vo_intro<n>.wav + MDA_SFX_tick/go.wav> <out.html>
import base64, json, os, sys, wave
src, out_path = sys.argv[1], sys.argv[2]
LINES = [
    ("1", "Hardpoint's up. Get there first, and use your mecha upgrades to your advantage."),
    ("2", "All units, move to the hardpoint. Your mecha upgrades are your edge. Use them."),
    ("3", "Mechs online. Take the hardpoint and hold it. Make every upgrade count."),
    ("4", "Listen up. The hardpoint is marked. Gear up, move out, and hold that ground."),
    ("5", "Systems hot. Get to the hardpoint, and let your upgrades do the talking."),
]
def b64(p): return "data:audio/wav;base64," + base64.b64encode(open(p, "rb").read()).decode()
def dur(p):
    w = wave.open(p); return round(w.getnframes() / w.getframerate(), 2)
snd = {k: b64(os.path.join(src, f"MDA_SFX_vo_intro{k}.wav")) for k, _ in LINES}
lens = {k: dur(os.path.join(src, f"MDA_SFX_vo_intro{k}.wav")) for k, _ in LINES}
extra = {n: b64(os.path.join(src, f"MDA_SFX_{n}.wav")) for n in ("tick", "go")}
html = """<meta charset="utf-8">
<title>Sound Pick Board</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=Fredoka:wght@600;700&family=Nunito:wght@600;700;800&display=swap" rel="stylesheet">
<style>
:root { --page: #0d0f14; --panel: #14141a; --card: #1d2230; --line: #2b3242; --fg: #ffffff; --grey: #cfd3dc; --muted: #8f99aa;
  --accent: #ff9b2e; --yellow: #ffc21a; --good: #7dff9a; --blue: #5fb4ff;
  --display: "Fredoka", "Trebuchet MS", system-ui, sans-serif; --body: "Nunito", "Segoe UI", system-ui, sans-serif; color-scheme: dark; }
* { box-sizing: border-box; }
body { margin: 0; background: var(--page); color: var(--fg); font: 15px/1.5 var(--body); padding-block: 18px 64px; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
main { max-width: 1000px; margin: 0 auto; display: grid; gap: 14px; }
main > * { min-width: 0; }
h1 { margin: 0; font: 700 clamp(22px, 4vw, 30px)/1.1 var(--display); text-wrap: balance; }
h1 span { color: var(--accent); }
h2 { margin: 0; font: 700 18px/1.2 var(--display); }
p { margin: 0; }
.lede { color: var(--muted); max-width: 86ch; }
.tl { background: var(--panel); border: 2px solid var(--line); border-radius: 14px; padding: 12px 16px; display: grid; gap: 8px; }
.bar { position: relative; height: 54px; background: var(--card); border-radius: 8px; overflow: hidden; }
.seg { position: absolute; top: 0; height: 24px; font: 800 11px/24px var(--body); color: var(--fg); padding-left: 6px; white-space: nowrap; overflow: hidden; border-left: 2px solid var(--page); }
.vo { position: absolute; top: 28px; height: 22px; background: rgba(255,155,46,.4); border-left: 2px solid var(--accent); border-radius: 0 6px 6px 0; font: 800 11px/22px var(--body); padding-left: 6px; white-space: nowrap; overflow: hidden; }
.mark { position: absolute; top: 28px; height: 22px; width: 2px; background: var(--yellow); }
.head { position: absolute; top: 0; bottom: 0; width: 2px; background: #fff; left: 0; }
.ticks { display: flex; justify-content: space-between; color: var(--muted); font: 800 11px var(--body); font-variant-numeric: tabular-nums; }
.lines { display: grid; gap: 10px; }
.ln { display: grid; grid-template-columns: auto minmax(0, 1fr) auto; gap: 12px; align-items: center; background: var(--panel); border: 2px solid var(--line); border-radius: 14px; padding: 10px 12px; }
.ln[data-picked="true"] { border-color: var(--good); box-shadow: 0 0 0 3px rgba(125,255,154,.15); }
.ln b { font: 700 22px var(--display); color: var(--yellow); width: 28px; text-align: center; }
.ln q { quotes: "\\201C" "\\201D"; font: 700 15px/1.35 var(--body); }
.ln small { display: block; color: var(--muted); font-weight: 700; font-size: 12px; margin-top: 2px; }
.row { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; justify-content: flex-end; }
.btn { font: 800 13px var(--body); color: var(--fg); background: var(--card); border: 2px solid var(--line); border-radius: 10px; padding: 7px 12px; cursor: pointer; }
.btn.play { background: var(--accent); border-color: var(--accent); color: #1a0f00; }
.btn.pick[aria-pressed="true"] { background: var(--good); border-color: var(--good); color: #062010; }
button:focus-visible { outline: 3px solid var(--yellow); outline-offset: 2px; }
@media (max-width: 640px) { .ln { grid-template-columns: auto minmax(0, 1fr); } .ln .row { grid-column: 1 / -1; justify-content: flex-start; } }
.picks { position: sticky; bottom: env(safe-area-inset-bottom, 0px); display: flex; flex-wrap: wrap; gap: 10px; align-items: center; justify-content: space-between; background: var(--panel); border: 2px solid var(--good); border-radius: 14px; padding: 10px 14px; }
.picks code { font: 800 14px/1.4 var(--body); flex: 1 1 240px; min-width: 0; }
.picks small { color: var(--muted); }
</style>
<main>
  <header>
    <h1><span>Match intro</span> · the voice over the countdown <span style="color:var(--muted);font-size:.6em">voice A, Field radio</span></h1>
    <p class="lede">During the 10-second countdown before a match the camera flies out to the hardpoint and back. A line in your announcer's voice plays over that fly-over and ends before the 3-2-1. Press "Play in the countdown" to hear it the way the match will (with the ticks and the go). Pick one, or several to hear a different one each match.</p>
  </header>
  <section class="tl" aria-label="The countdown">
    <h2>The countdown, as the game runs it</h2>
    <div class="bar" id="bar"></div>
    <div class="ticks"><span>10 s left</span><span>8</span><span>6</span><span>4</span><span>2</span><span>GO</span></div>
  </section>
  <div class="lines" id="lines"></div>
  <div class="picks"><code id="pickText"></code><button class="btn play" id="copy">Copy picks</button></div>
</main>
<script>
const SND = __SND__, LENS = __LENS__, LINES = __LINES__, EXTRA = __EXTRA__;
const START = 9, TOTAL = 10; // the line starts when the camera pan starts (9 s left)
let actx = null, live = [], picks = [], playingLine = null, t0 = 0;
const KEY = "mda_intro_voice_picks_r13";
try { picks = JSON.parse(localStorage.getItem(KEY) || "[]") || []; } catch (e) { picks = []; }
const bufs = {};
function ctx() { if (!actx) actx = new (window.AudioContext || window.webkitAudioContext)(); if (actx.state === "suspended") actx.resume(); return actx; }
function buf(src) { if (!bufs[src]) { const bin = atob(src.slice(src.indexOf(",") + 1)), u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i); bufs[src] = new Promise((ok, no) => actx.decodeAudioData(u.buffer, ok, no)); } return bufs[src]; }
function stop() { live.forEach(s => { try { s.stop(); } catch (e) {} }); live = []; playingLine = null; drawBar(); }
async function at(src, when) { const b = await buf(src); const s = actx.createBufferSource(); s.buffer = b; s.connect(actx.destination); s.start(when); live.push(s); }
async function playLine(k, withCountdown) {
  ctx(); stop(); playingLine = k;
  const base = actx.currentTime + 0.1;
  if (withCountdown) {
    t0 = base; // 10 s left at t0
    await at(SND[k], base + (TOTAL - START));
    for (const s of [3, 2, 1]) await at(EXTRA.tick, base + (TOTAL - s));
    await at(EXTRA.go, base + TOTAL);
    setTimeout(() => { if (playingLine === k) stop(); }, (TOTAL + 1.2) * 1000);
  } else { t0 = base - (TOTAL - START); await at(SND[k], base); setTimeout(() => { if (playingLine === k) stop(); }, (LENS[k] + 0.3) * 1000); }
  drawBar();
}
const pct = left => ((TOTAL - left) / TOTAL * 100) + "%";
function drawBar() {
  const k = playingLine || picks[0] || "1";
  const segs = [[10, 9, "normal camera", "#2b3242"], [9, 7, "camera flies out", "#3a4a6a"], [7, 5, "circles the point", "#4b5d84"], [5, 3, "flies back", "#3a4a6a"], [3, 0, "3 · 2 · 1", "#6b5a2a"]];
  document.getElementById("bar").innerHTML = segs.map(([a, b, n, c]) => `<span class="seg" style="left:${pct(a)};width:${(a - b) / TOTAL * 100}%;background:${c}">${n}</span>`).join("")
    + `<span class="vo" style="left:${pct(START)};width:${LENS[k] / TOTAL * 100}%">line ${k} · ${LENS[k].toFixed(1)} s</span>`
    + [3, 2, 1, 0].map(s => `<span class="mark" style="left:calc(${pct(s)} - 1px)"></span>`).join("") + `<span class="head" id="head"></span>`;
}
(function head() { const h = document.getElementById("head"); if (h && actx && playingLine) { const g = actx.currentTime - t0; h.style.left = Math.max(0, Math.min(100, g / TOTAL * 100)) + "%"; } else if (h) h.style.left = "0"; requestAnimationFrame(head); })();
function render() {
  document.getElementById("lines").innerHTML = LINES.map(([k, text]) => `<div class="ln" data-picked="${picks.includes(k)}"><b>${k}</b><div><q>${text}</q><small>${LENS[k].toFixed(1)} s · ends ${(START - LENS[k]).toFixed(1)} s before GO</small></div>
    <div class="row"><button class="btn" data-play="${k}">Play</button><button class="btn play" data-count="${k}">Play in the countdown</button><button class="btn pick" data-pick="${k}" aria-pressed="${picks.includes(k)}">${picks.includes(k) ? "Picked ✓" : "Pick"}</button></div></div>`).join("");
  document.getElementById("pickText").innerHTML = "Intro lines " + (picks.length ? picks.slice().sort().join(", ") : "?") + (picks.length > 1 ? " <small>(a different one each match)</small>" : "");
  drawBar();
}
document.getElementById("lines").addEventListener("click", e => {
  const p = e.target.closest("[data-play]"), c = e.target.closest("[data-count]"), k = e.target.closest("[data-pick]");
  if (p) playLine(p.dataset.play, false); else if (c) playLine(c.dataset.count, true);
  else if (k) { const id = k.dataset.pick; picks = picks.includes(id) ? picks.filter(x => x !== id) : picks.concat(id); try { localStorage.setItem(KEY, JSON.stringify(picks)); } catch (err) {} render(); }
});
document.getElementById("copy").addEventListener("click", () => {
  const txt = document.getElementById("pickText").textContent, btn = document.getElementById("copy");
  const done = ok => { btn.textContent = ok ? "Copied ✓" : "Select + copy the text"; setTimeout(() => btn.textContent = "Copy picks", 1800); };
  const fb = () => { const r = document.createRange(); r.selectNodeContents(document.getElementById("pickText")); const s = getSelection(); s.removeAllRanges(); s.addRange(r); let ok = false; try { ok = document.execCommand("copy"); } catch (err) {} done(ok); };
  try { navigator.clipboard.writeText(txt).then(() => done(true), fb); } catch (err) { fb(); }
});
render();
</script>
"""
html = (html.replace("__SND__", json.dumps(snd)).replace("__LENS__", json.dumps(lens)).replace("__LINES__", json.dumps(LINES))
        .replace("__EXTRA__", json.dumps(extra)))
open(out_path, "w").write(html)
print("ok", out_path, round(os.path.getsize(out_path) / 1e6, 2), "MB", lens)
