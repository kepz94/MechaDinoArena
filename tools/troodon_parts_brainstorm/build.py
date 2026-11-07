# builds docs/mockups/troodon_parts_brainstorm_v1.0.html and docs/plans/TROODON_PARTS_brainstorm_v1.0.md from data.py
import html, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from data import AREAS
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
esc = html.escape
nav = "".join(f'<a href="#{a}" class="navchip" style="--c:{rgb}">{name} <span>{len(items)}</span></a>' for a, name, rgb, _, items in AREAS)
secs = []
for a, name, rgb, blurb, items in AREAS:
    cards = "".join(f'''<li class="card"><label for="pk-{i}"><input type="checkbox" id="pk-{i}" data-id="{i}"><span class="id">{i}</span><span class="body"><span class="nm">{esc(n)}</span><span class="what">{esc(w)}</span><span class="meta"><span class="k">Looks like</span> {esc(l)}</span><span class="meta"><span class="k">Inspired by</span> {esc(s)}</span></span></label></li>''' for i, n, w, l, s in items)
    secs.append(f'<section id="{a}" style="--c:{rgb}"><header class="sech"><h2>{name}</h2><p>{esc(blurb)}</p></header><ol class="cards">{cards}</ol></section>')
page = '''<title>Troodon Part Ideas</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@600;700&family=Nunito+Sans:opsz,wght@6..12,400;6..12,600;6..12,800&display=swap">
<style>
/* Layout: a field notebook of part ideas, one colour band per skill area (the game's own skill-tree area colours), a sticky pick bar. */
:root{--bg:#f3f1ec;--panel:#ffffff;--ink:#1d2026;--muted:#5d636e;--line:#dcd8cf;--eye:#c77a10;--glow:#138a7a;--pick:#fff3dc;
 --f-display:"Chakra Petch",ui-sans-serif,system-ui,sans-serif;--f-body:"Nunito Sans",ui-sans-serif,system-ui,sans-serif}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#14171c;--panel:#1c2027;--ink:#eceae4;--muted:#a3a8b1;--line:#2d333c;--eye:#f0a62a;--glow:#3fe0c8;--pick:#2a2418;color-scheme:dark}}
:root[data-theme="dark"]{--bg:#14171c;--panel:#1c2027;--ink:#eceae4;--muted:#a3a8b1;--line:#2d333c;--eye:#f0a62a;--glow:#3fe0c8;--pick:#2a2418;color-scheme:dark}
body{background:var(--bg);color:var(--ink);font:15px/1.5 var(--f-body)}
.wrap{max-width:1080px;margin:0 auto;padding-block:20px 96px;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}
h1{font:700 clamp(26px,5vw,40px)/1.1 var(--f-display);letter-spacing:.01em;margin:0 0 6px;text-wrap:balance}
h1 em{font-style:normal;color:var(--eye)}
.lede{color:var(--muted);max-width:68ch;margin:0 0 14px}
.rules{display:flex;flex-wrap:wrap;gap:8px;margin:0 0 16px;padding:0;list-style:none}
.rules li{font-size:12.5px;border:1px solid var(--line);border-radius:999px;padding:4px 10px;color:var(--muted)}
nav.areas{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:20px}
.navchip{--c:0,0,0;text-decoration:none;color:var(--ink);font:700 13px var(--f-display);letter-spacing:.06em;text-transform:uppercase;padding:6px 12px;border-radius:8px;border:1px solid rgb(var(--c));background:rgba(var(--c),.12)}
.navchip span{color:var(--muted);font-weight:600}
section{--c:0,0,0;margin-top:28px}
.sech{border-left:6px solid rgb(var(--c));padding:2px 0 2px 12px;margin-bottom:12px}
.sech h2{font:700 22px var(--f-display);letter-spacing:.05em;text-transform:uppercase;margin:0}
.sech p{margin:2px 0 0;color:var(--muted)}
.cards{list-style:none;margin:0;padding:0;display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:10px}
.card label{display:flex;gap:10px;align-items:flex-start;background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:12px;cursor:pointer;height:100%;box-sizing:border-box}
.card input{margin-top:3px;width:18px;height:18px;accent-color:rgb(var(--c));flex:none}
.card input:focus-visible{outline:2px solid var(--glow);outline-offset:2px}
.card label:has(input:checked){background:var(--pick);border-color:rgb(var(--c))}
.id{flex:none;font:700 12px var(--f-display);color:rgb(var(--c));border:1px solid rgb(var(--c));border-radius:6px;padding:1px 6px;margin-top:1px;font-variant-numeric:tabular-nums;min-width:30px;text-align:center}
.body{display:flex;flex-direction:column;gap:3px;min-width:0}
.nm{font-weight:800;font-size:15.5px}
.what{font-size:14px}
.meta{font-size:12.5px;color:var(--muted)}
.k{font-weight:800;text-transform:uppercase;font-size:10.5px;letter-spacing:.08em;color:var(--muted)}
.bar{position:fixed;left:0;right:0;bottom:0;background:var(--panel);border-top:1px solid var(--line);padding-block:10px calc(10px + env(safe-area-inset-bottom,0px));padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px));display:flex;gap:10px;align-items:center;flex-wrap:wrap}
.bar .count{font:700 14px var(--f-display);letter-spacing:.04em}
.bar .list{flex:1;min-width:0;font-size:13px;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.bar button{font:700 13px var(--f-display);letter-spacing:.05em;text-transform:uppercase;border-radius:8px;padding:8px 12px;border:1px solid var(--eye);background:var(--eye);color:#1b1306;cursor:pointer}
.bar button.ghost{background:transparent;color:var(--ink);border-color:var(--line)}
.bar button:focus-visible{outline:2px solid var(--glow);outline-offset:2px}
#copyout{width:100%;font:13px var(--f-body);background:var(--bg);color:var(--ink);border:1px solid var(--line);border-radius:6px;padding:6px}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
</style>
<div class="wrap">
<h1>Troodon <em>part ideas</em></h1>
<p class="lede">100 mecha parts for the Troodon (area control + support, 55 HP, Glow Pod Toss, Flap &amp; Glide), 20 per skill area, each borrowed from a move in another game and bent to fit a small feathered dino with big eyes and long arms. Every one is visible hardware on the body and works against any dino. Tick the ones you like and copy your picks.</p>
<ul class="rules"><li>No repeats of live parts on other dinos</li><li>Heals reach squadmates only (Arena squads)</li><li>Numbers come later, in the plan</li></ul>
<nav class="areas" aria-label="Skill areas">NAV</nav>
SECS
</div>
<div class="bar" role="region" aria-label="Your picks"><span class="count" id="count">0 picked</span><span class="list" id="list">Tick parts to pick them</span><button type="button" class="ghost" id="clear">Clear</button><button type="button" id="copy">Copy picks</button><textarea id="copyout" rows="2" hidden readonly></textarea></div>
<script>
(function(){
 var KEY="troodonPartPicks";
 var boxes=[].slice.call(document.querySelectorAll('input[type=checkbox][data-id]'));
 function load(){try{var v=JSON.parse(localStorage.getItem(KEY)||"[]");boxes.forEach(function(b){b.checked=v.indexOf(b.dataset.id)>=0});}catch(e){}}
 function picks(){return boxes.filter(function(b){return b.checked}).map(function(b){return b.dataset.id+" "+b.closest("label").querySelector(".nm").textContent})}
 function render(){var p=picks();document.getElementById("count").textContent=p.length+" picked";document.getElementById("list").textContent=p.length?p.map(function(s){return s.split(" ")[0]}).join(", "):"Tick parts to pick them";try{localStorage.setItem(KEY,JSON.stringify(boxes.filter(function(b){return b.checked}).map(function(b){return b.dataset.id})))}catch(e){}}
 boxes.forEach(function(b){b.addEventListener("change",render)});
 document.getElementById("clear").addEventListener("click",function(){boxes.forEach(function(b){b.checked=false});render();document.getElementById("copyout").hidden=true});
 document.getElementById("copy").addEventListener("click",function(){var t="Troodon picks: "+picks().join(", ");var out=document.getElementById("copyout");var btn=this;
  function fallback(){out.hidden=false;out.value=t;out.focus();out.select();btn.textContent="Select + copy";}
  try{navigator.clipboard.writeText(t).then(function(){btn.textContent="Copied";setTimeout(function(){btn.textContent="Copy picks"},1500)},fallback)}catch(e){fallback()}});
 load();render();
})();
</script>
'''.replace("NAV", nav).replace("SECS", "\n".join(secs))
open(os.path.join(ROOT, "docs/mockups/troodon_parts_brainstorm_v1.0.html"), "w").write(page)
md = ["# Mecha Dino Arena — Troodon mecha part ideas v1.0 (brainstorm)", "",
      "**Ask (Kepu 2026-11-06 19:34):** \"create a list of 20 different abilities for each stat category. I want you to pull inspiration from different games to create something unique for this Dino\".",
      "**Page:** docs/mockups/troodon_parts_brainstorm_v1.0.html (source tools/troodon_parts_brainstorm). Rules: visible hardware, works against any dino, no repeat of a live part, heals reach squadmates only. Numbers come with the plan after Kepu picks.", ""]
for a, name, rgb, blurb, items in AREAS:
    md += [f"## {name} — {blurb}", "", "| # | Part | What it does | Looks like | Inspired by |", "|---|---|---|---|---|"]
    md += [f"| {i} | {n} | {w} | {l} | {s} |" for i, n, w, l, s in items] + [""]
open(os.path.join(ROOT, "docs/plans/TROODON_PARTS_brainstorm_v1.0.md"), "w").write("\n".join(md))
print("ok", sum(len(x[4]) for x in AREAS))
