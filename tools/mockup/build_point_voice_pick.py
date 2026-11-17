# build_point_voice_pick.py v1.0 (Mecha Dino Arena) — the Hardpoint voice callout pick page (MDA-552; Kepu 2026-11-17 12:42
# "I don't like the point sounds switching over and all that, it sounds stupid and does call of duty even do that?", then picked
# "Voice callouts" and "Keep them" (the moving warning, the countdown ticks and the go stay)). Three announcer voices, each saying
# the three lines that match the HUD's status words (SECURED / ENEMY HAS THE POINT / CONTESTED). Lines are synthesized with
# Kokoro-82M (Apache-2.0) and processed with ffmpeg (recipe docs/sfx/gen_point_vo.sh); the audio is not in the repo.
# Usage: python3 tools/mockup/build_point_voice_pick.py <dir with MDA_SFX_vo_<line>_<opt>.wav> <out.html>
import base64, json, os, sys
src, out_path = sys.argv[1], sys.argv[2]
OPTS = {
    "A": ("Field radio", "A US male voice through a radio: band-limited and a little crunchy, like a squad comms call."),
    "B": ("Commander", "A British male voice, dry and close, with a touch of room."),
    "C": ("Mech AI", "A US female voice with a light metallic shimmer, like the mech's onboard system talking."),
}
LINES = [("secured", "Hardpoint secured.", "Your team takes the point and holds it."),
         ("lost", "Enemy has the hardpoint.", "The other team takes it from you and holds it."),
         ("contested", "Hardpoint contested.", "Both teams are on it and it stays that way.")]
snd = {o: {l: "data:audio/wav;base64," + base64.b64encode(open(os.path.join(src, f"MDA_SFX_vo_{l}_{o}.wav"), "rb").read()).decode()
           for l, _, _ in LINES} for o in OPTS}
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
main { max-width: 1080px; margin: 0 auto; display: grid; gap: 14px; }
main > * { min-width: 0; }
h1 { margin: 0; font: 700 clamp(22px, 4vw, 30px)/1.1 var(--display); text-wrap: balance; }
h1 span { color: var(--accent); }
h2 { margin: 0; font: 700 20px/1.2 var(--display); }
p { margin: 0; }
.lede { color: var(--muted); max-width: 88ch; }
.rules { background: var(--panel); border: 2px solid var(--line); border-radius: 14px; padding: 12px 16px; display: grid; gap: 6px; }
.rules ul { margin: 0; padding-left: 18px; color: var(--grey); }
.opts { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; }
@media (max-width: 860px) { .opts { grid-template-columns: minmax(0, 1fr); } }
.opt { background: var(--panel); border: 2px solid var(--line); border-radius: 16px; padding: 14px; display: grid; gap: 10px; align-content: start; min-width: 0; }
.opt[data-picked="true"] { border-color: var(--good); box-shadow: 0 0 0 3px rgba(125,255,154,.18); }
.opt h2 b { color: var(--yellow); margin-right: 6px; }
.opt p { color: var(--grey); font-size: 14px; }
.line { display: flex; align-items: center; gap: 10px; background: var(--card); border: 2px solid var(--line); border-radius: 12px; padding: 8px 10px; cursor: pointer; color: var(--fg); font: 700 14px/1.3 var(--body); text-align: left; width: 100%; }
.line i { font-style: normal; display: grid; place-items: center; width: 30px; height: 30px; border-radius: 50%; background: var(--accent); color: #1a0f00; flex: none; font-size: 13px; }
.line small { display: block; color: var(--muted); font-weight: 700; font-size: 12px; }
.line[aria-pressed="true"] { border-color: var(--yellow); }
.btn { font: 800 13px var(--body); color: var(--fg); background: var(--card); border: 2px solid var(--line); border-radius: 10px; padding: 7px 12px; cursor: pointer; }
.btn.pick[aria-pressed="true"] { background: var(--good); border-color: var(--good); color: #062010; }
.btn.go { background: var(--accent); border-color: var(--accent); color: #1a0f00; }
button:focus-visible { outline: 3px solid var(--yellow); outline-offset: 2px; }
.row { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
.picks { position: sticky; bottom: env(safe-area-inset-bottom, 0px); display: flex; flex-wrap: wrap; gap: 10px; align-items: center; justify-content: space-between; background: var(--panel); border: 2px solid var(--good); border-radius: 14px; padding: 10px 14px; }
.picks code { font: 800 14px/1.4 var(--body); flex: 1 1 240px; min-width: 0; }
</style>
<main>
  <header>
    <h1><span>Hardpoint</span> · voice callouts <span style="color:var(--muted);font-size:.6em">replaces the captured / lost / contested sounds</span></h1>
    <p class="lede">Instead of a sound every time the point flips, an announcer says what happened, once it has settled. Press a line to hear it, or play all three. Mark the voice you want; the bar at the bottom copies it. Turn your sound on.</p>
  </header>
  <section class="rules" aria-label="When the voice speaks">
    <h2>When it speaks (same for every voice)</h2>
    <ul>
      <li>Only when the point has stayed in its new state for a moment (about 1 second), so a scramble on the point doesn't set it off again and again.</li>
      <li>At least a few seconds between callouts, and never the same line twice in a row.</li>
      <li>Only you hear it (2D, like the other point sounds). The "point moving" warning, the 3-2-1 ticks and the "go" stay as they are.</li>
    </ul>
  </section>
  <div class="opts" id="opts"></div>
  <div class="picks"><code id="pickText"></code><button class="btn go" id="copy">Copy pick</button></div>
</main>
<script>
const SND = __SND__, OPTS = __OPTS__, LINES = __LINES__;
let actx = null, live = [], pick = null;
const KEY = "mda_point_voice_pick_r12";
try { pick = localStorage.getItem(KEY); } catch (e) {}
const bufs = {};
function ctx() { if (!actx) actx = new (window.AudioContext || window.webkitAudioContext)(); if (actx.state === "suspended") actx.resume(); return actx; }
function buf(src) {
  if (!bufs[src]) { const bin = atob(src.slice(src.indexOf(",") + 1)), u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i); bufs[src] = new Promise((ok, no) => actx.decodeAudioData(u.buffer, ok, no)); }
  return bufs[src];
}
function stop() { live.forEach(s => { try { s.stop(); } catch (e) {} }); live = []; document.querySelectorAll(".line").forEach(b => b.setAttribute("aria-pressed", "false")); }
async function play(o, lines) {
  ctx(); stop();
  let t = actx.currentTime + 0.05;
  for (const l of lines) {
    const b = await buf(SND[o][l]); const s = actx.createBufferSource(); s.buffer = b; s.connect(actx.destination); s.start(t);
    const el = document.querySelector(`.line[data-o="${o}"][data-l="${l}"]`);
    setTimeout(() => el && el.setAttribute("aria-pressed", "true"), (t - actx.currentTime) * 1000);
    s.onended = () => el && el.setAttribute("aria-pressed", "false");
    live.push(s); t += b.duration + 0.6;
  }
}
function render() {
  document.getElementById("opts").innerHTML = Object.entries(OPTS).map(([o, [name, desc]]) => `<section class="opt" data-picked="${pick === o}">
    <h2><b>${o}</b>${name}</h2><p>${desc}</p>
    ${LINES.map(([l, text, when]) => `<button class="line" data-o="${o}" data-l="${l}" aria-pressed="false"><i aria-hidden="true">▶</i><span>“${text}”<small>${when}</small></span></button>`).join("")}
    <div class="row"><button class="btn" data-all="${o}">Play all three</button><button class="btn pick" data-pick="${o}" aria-pressed="${pick === o}">${pick === o ? "Picked ✓" : "Pick " + o}</button></div>
  </section>`).join("");
  document.getElementById("pickText").textContent = "Point voice " + (pick || "?");
}
document.getElementById("opts").addEventListener("click", e => {
  const ln = e.target.closest(".line"), all = e.target.closest("[data-all]"), pk = e.target.closest("[data-pick]");
  if (ln) play(ln.dataset.o, [ln.dataset.l]).catch(err => console.log(err));
  else if (all) play(all.dataset.all, LINES.map(x => x[0]));
  else if (pk) { pick = pk.dataset.pick; try { localStorage.setItem(KEY, pick); } catch (err) {} render(); }
});
document.getElementById("copy").addEventListener("click", () => {
  const txt = document.getElementById("pickText").textContent, btn = document.getElementById("copy");
  const done = ok => { btn.textContent = ok ? "Copied ✓" : "Select + copy the text"; setTimeout(() => btn.textContent = "Copy pick", 1800); };
  const fb = () => { const r = document.createRange(); r.selectNodeContents(document.getElementById("pickText")); const s = getSelection(); s.removeAllRanges(); s.addRange(r); let ok = false; try { ok = document.execCommand("copy"); } catch (err) {} done(ok); };
  try { navigator.clipboard.writeText(txt).then(() => done(true), fb); } catch (err) { fb(); }
});
render();
</script>
"""
html = html.replace("__SND__", json.dumps(snd)).replace("__OPTS__", json.dumps(OPTS)).replace("__LINES__", json.dumps(LINES))
open(out_path, "w").write(html)
print("ok", out_path, round(os.path.getsize(out_path) / 1e6, 2), "MB")
