# build_title_voice_pick.py v1.1 (Mecha Dino Arena) — the post-game title voice line pick page (MDA-552, round 14; Kepu
# 2026-11-17 13:05 "How about some voice lines during the post game titles for the winning team. Couple for each title to make
# them really pop out"). The eight VictoryTitles 1.1 titles (names, captions, roasts as the game shows them), three lines each in
# the announcer voice (Kokoro-82M am_michael, Apache-2.0), in two treatments: R = the radio voice of the point callouts (voice A),
# S = the same voice clean with a big stadium echo. Pick the lines to keep per title (a show picks one of them at random) and one
# treatment. Recipe docs/sfx/gen_point_vo.sh v1.2; audio not in the repo.
# v1.1: Kepu 13:11 "Not like that, look at how call of duty speaks during these types of screens. It's like a commander talking
# to you. This is just a narrator." New lines: a commander on the radio talking to the squad about the player; two voices,
# A = am_michael 0.97 (the point-callout voice), B = bm_george 0.95, both through the radio filter. Files
# MDA_SFX_vt_<title><n>_<A|B>.wav (recipe docs/sfx/gen_point_vo.sh v1.3).
# Usage: python3 tools/mockup/build_title_voice_pick.py <dir with MDA_SFX_vt_<title><n>_<A|B>.wav> <out.html>
import base64, json, os, subprocess, sys, tempfile
src, out_path = sys.argv[1], sys.argv[2]
TITLES = [  # id, name, caption (VictoryTitles 1.1), roast, lines
    ("apex", "APEX PREDATOR", "Top of the food chain", False, ["Command here. Our apex predator owned that field. Outstanding.", "Apex predator. They hunted down everything that moved. Good work.", "Top of the food chain. That's how we win wars, people."]),
    ("king", "KING OF THE HILL", "Wouldn't get off the point", False, ["King of the hill. They held that point like their life depended on it.", "Command here. Our anchor never gave up the hardpoint. Well done.", "That point was ours all match. King of the hill. Outstanding."]),
    ("unkill", "UNKILLABLE", "The asteroid missed. Again.", False, ["Unkillable. They took everything the enemy had, and kept coming.", "Command here. Nothing they threw mattered. Tough as they come.", "Unkillable. Somebody get that dino a medal."]),
    ("medic", "MEDIC", "Patched up the whole team", False, ["Our medic kept this squad standing. Nobody wins without them.", "Command here. Every wound patched, every unit back in the fight.", "Medic. Best support on the field. Outstanding work."]),
    ("masher", "BUTTON MASHER", "Never met a cooldown it liked", False, ["Button masher. Every upgrade, off cooldown, all match. I like it.", "Command here. They burned through every system we gave them.", "Those upgrades never got a rest. Aggressive. Effective."]),
    ("extinct", "EXTINCT", "Died the most. Again.", True, ["Extinct. Most deaths on the team. We won anyway. Somehow.", "Command here. Somebody explain how they died that much.", "Extinct. Respawns aren't free, soldier. Lucky we won."]),
    ("carried", "CARRIED", "Packed up and carried to the win", True, ["Carried. The squad did the heavy lifting. Say thank you.", "Command here. That one rode the team all the way to the win.", "Carried. A win's a win. Don't make it a habit."]),
    ("pacifist", "PACIFIST", "Won without hurting a fly", True, ["Pacifist. Zero damage, full victory. I don't know how.", "Command here. Didn't land a hit, still brought it home.", "Pacifist. Next time, try hitting something."]),
]
tmp = tempfile.mkdtemp()
snd = {}
for tid, _, _, _, lines in TITLES:
    for i in range(len(lines)):
        for st in ("A", "B"):
            f = os.path.join(src, f"MDA_SFX_vt_{tid}{i + 1}_{st}.wav")
            w = os.path.join(tmp, os.path.basename(f))
            subprocess.check_call(["ffmpeg", "-v", "error", "-y", "-i", f, "-ar", "24000", "-ac", "1", "-c:a", "pcm_s16le", w])
            snd[f"{tid}{i + 1}_{st}"] = "data:audio/wav;base64," + base64.b64encode(open(w, "rb").read()).decode()
html = """<meta charset="utf-8">
<title>Sound Pick Board</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=Fredoka:wght@600;700&family=Nunito:wght@600;700;800&display=swap" rel="stylesheet">
<style>
:root { --page: #0d0f14; --panel: #14141a; --card: #1d2230; --line: #2b3242; --fg: #ffffff; --grey: #cfd3dc; --muted: #8f99aa;
  --accent: #ff9b2e; --yellow: #ffc21a; --pink: #ff6fb5; --good: #7dff9a;
  --display: "Fredoka", "Trebuchet MS", system-ui, sans-serif; --body: "Nunito", "Segoe UI", system-ui, sans-serif; color-scheme: dark; }
* { box-sizing: border-box; }
body { margin: 0; background: var(--page); color: var(--fg); font: 15px/1.5 var(--body); padding-block: 18px 64px; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
main { max-width: 1120px; margin: 0 auto; display: grid; gap: 14px; }
main > * { min-width: 0; }
h1 { margin: 0; font: 700 clamp(22px, 4vw, 30px)/1.1 var(--display); text-wrap: balance; }
h1 span { color: var(--accent); }
p { margin: 0; }
.lede { color: var(--muted); max-width: 90ch; }
.styles { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; background: var(--panel); border: 2px solid var(--line); border-radius: 14px; padding: 10px 14px; }
.lbl { font: 800 11px var(--body); letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }
.st { font: 700 14px/1.2 var(--display); color: var(--fg); background: var(--card); border: 2px solid var(--line); border-radius: 12px; padding: 8px 12px; cursor: pointer; text-align: left; }
.st small { display: block; font: 700 12px var(--body); color: var(--muted); }
.st[aria-pressed="true"] { border-color: var(--yellow); box-shadow: 0 0 0 3px rgba(255,194,26,.2); }
.grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
@media (max-width: 820px) { .grid { grid-template-columns: minmax(0, 1fr); } }
.t { background: var(--panel); border: 2px solid var(--line); border-radius: 16px; padding: 12px 14px; display: grid; gap: 8px; min-width: 0; }
.t h2 { margin: 0; font: 700 22px/1 var(--display); color: var(--yellow); letter-spacing: .02em; }
.t.roast h2 { color: var(--pink); }
.t .cap { color: var(--grey); font-size: 13px; }
.ln { display: grid; grid-template-columns: auto minmax(0, 1fr) auto; gap: 10px; align-items: center; background: var(--card); border: 2px solid var(--line); border-radius: 12px; padding: 7px 10px; }
.ln[data-on="true"] { border-color: var(--good); }
.pl { width: 32px; height: 32px; border-radius: 50%; border: 0; background: var(--accent); color: #1a0f00; font-weight: 800; cursor: pointer; }
.pl[aria-pressed="true"] { background: var(--yellow); }
.ln span { font: 700 14px/1.3 var(--body); }
.ln small { display: block; color: var(--muted); font-size: 11px; font-weight: 700; }
.keep { font: 800 12px var(--body); color: var(--fg); background: var(--panel); border: 2px solid var(--line); border-radius: 9px; padding: 5px 10px; cursor: pointer; white-space: nowrap; }
.keep[aria-pressed="true"] { background: var(--good); border-color: var(--good); color: #062010; }
button:focus-visible { outline: 3px solid var(--yellow); outline-offset: 2px; }
.picks { position: sticky; bottom: env(safe-area-inset-bottom, 0px); display: flex; flex-wrap: wrap; gap: 10px; align-items: center; justify-content: space-between; background: var(--panel); border: 2px solid var(--good); border-radius: 14px; padding: 10px 14px; }
.picks code { font: 800 13px/1.4 var(--body); flex: 1 1 280px; min-width: 0; overflow-wrap: anywhere; }
.go { font: 800 13px var(--body); background: var(--accent); border: 2px solid var(--accent); color: #1a0f00; border-radius: 10px; padding: 7px 12px; cursor: pointer; }
</style>
<main>
  <header>
    <h1><span>Post-game titles</span> · command talks to your squad</h1>
    <p class="lede">When each title slams in on the winners' show, your commander comes on the radio and talks to the squad about that player: praise for the good titles, a dressing-down for the roasts. Three lines for each title; keep the ones you like (keep two or more and each show picks one at random). Then pick the commander's voice. Turn your sound on.</p>
  </header>
  <div class="styles" role="group" aria-label="Voice treatment"><span class="lbl">Voice</span>
    <button class="st" data-st="A" aria-pressed="true">A · US commander<small>your point-callout voice, on the radio</small></button>
    <button class="st" data-st="B" aria-pressed="false">B · British commander<small>older, drier, on the radio</small></button>
  </div>
  <div class="grid" id="grid"></div>
  <div class="picks"><code id="pickText"></code><button class="go" id="copy">Copy picks</button></div>
</main>
<script>
const SND = __SND__, TITLES = __TITLES__;
const SHORT = {apex: "Apex", king: "King", unkill: "Unkillable", medic: "Medic", masher: "Masher", extinct: "Extinct", carried: "Carried", pacifist: "Pacifist"};
const KEY = "mda_title_voice_picks_r14b";
let st = "A", keep = {}, actx = null, cur = null;
try { const s = JSON.parse(localStorage.getItem(KEY) || "{}"); st = (s.st === "A" || s.st === "B") ? s.st : "A"; keep = s.keep || {}; } catch (e) {}
const save = () => { try { localStorage.setItem(KEY, JSON.stringify({st, keep})); } catch (e) {} };
const bufs = {};
function ctx() { if (!actx) actx = new (window.AudioContext || window.webkitAudioContext)(); if (actx.state === "suspended") actx.resume(); return actx; }
function buf(src) { if (!bufs[src]) { const bin = atob(src.slice(src.indexOf(",") + 1)), u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i); bufs[src] = new Promise((ok, no) => actx.decodeAudioData(u.buffer, ok, no)); } return bufs[src]; }
async function play(key, el) {
  ctx(); if (cur) { try { cur.s.stop(); } catch (e) {} cur.el.setAttribute("aria-pressed", "false"); }
  const b = await buf(SND[key + "_" + st]); const s = actx.createBufferSource(); s.buffer = b; s.connect(actx.destination); s.start();
  el.setAttribute("aria-pressed", "true"); cur = {s, el}; s.onended = () => el.setAttribute("aria-pressed", "false");
}
function render() {
  document.querySelectorAll(".st").forEach(b => b.setAttribute("aria-pressed", b.dataset.st === st));
  document.getElementById("grid").innerHTML = TITLES.map(([id, name, cap, roast, lines]) => `<section class="t${roast ? " roast" : ""}"><h2>${name}</h2><div class="cap">${cap}${roast ? " · roast" : ""}</div>
    ${lines.map((l, i) => { const k = id + (i + 1), on = (keep[id] || []).includes(i + 1); return `<div class="ln" data-on="${on}"><button class="pl" data-play="${k}" aria-pressed="false" aria-label="Play line ${i + 1}">▶</button><span>“${l}”<small>line ${i + 1}</small></span><button class="keep" data-keep="${id}" data-n="${i + 1}" aria-pressed="${on}">${on ? "Kept ✓" : "Keep"}</button></div>`; }).join("")}
  </section>`).join("");
  const parts = TITLES.map(([id]) => `${SHORT[id]} ${(keep[id] || []).length ? keep[id].slice().sort().join("+") : "?"}`);
  document.getElementById("pickText").textContent = `Commander ${st}; ` + parts.join(", ");
}
document.querySelector(".styles").addEventListener("click", e => { const b = e.target.closest("[data-st]"); if (!b) return; st = b.dataset.st; save(); render(); });
document.getElementById("grid").addEventListener("click", e => {
  const p = e.target.closest("[data-play]"), k = e.target.closest("[data-keep]");
  if (p) play(p.dataset.play, p).catch(err => console.log(err));
  else if (k) { const id = k.dataset.keep, n = +k.dataset.n, a = keep[id] || []; keep[id] = a.includes(n) ? a.filter(x => x !== n) : a.concat(n); save(); render(); }
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
html = html.replace("__SND__", json.dumps(snd)).replace("__TITLES__", json.dumps(TITLES))
open(out_path, "w").write(html)
print("ok", out_path, round(os.path.getsize(out_path) / 1e6, 2), "MB")
