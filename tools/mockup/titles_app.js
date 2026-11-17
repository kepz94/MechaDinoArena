// titles_app.js v0.1 — page shell: title / dino pickers, single play (loops), the full show (sample winning team), the
// in-game overlay (lower third, banner, counter, screen plasters), PC / phone frames.
const DINO_NAME = {TRex: "T-Rex", Raptor: "Raptor", Pachy: "Pachy", Herrera: "Herrera", Teno: "Teno", Troodon: "Troodon", Therizino: "Therizino", Dilo: "Dilo"};
const DINO_KEYS = ["Raptor", "TRex", "Dilo", "Pachy", "Herrera", "Teno", "Troodon", "Therizino"];
const PRIORITY = ["apex", "king", "unkill", "medic", "masher", "extinct", "carried", "pacifist"];
const byId = id => TITLES.find(x => x.id === id);
const TEAM = [
  {name: "BloxSolid", dino: "Raptor", k: 11, d: 2, pt: "1:42", heal: 120, ab: 31, score: 310, title: "apex", stat: "11 KILLS"},
  {name: "Vex", dino: "Pachy", k: 3, d: 3, pt: "2:05", heal: 0, ab: 18, score: 220, title: "king", stat: "2:05 ON POINT"},
  {name: "Kiwi", dino: "Dilo", k: 7, d: 0, pt: "1:10", heal: 0, ab: 24, score: 240, title: "unkill", stat: "0 DEATHS · 7 KILLS"},
  {name: "Moss", dino: "Herrera", k: 0, d: 2, pt: "0:12", heal: 0, ab: 9, score: 40, title: "carried", stat: "40 SCORE · LOWEST"},
];
const rigs = {}, mates = {}, ghosts = {};
const getRig = (cache, key, opt) => cache[key] || (cache[key] = buildRig(key, opt));
function resetRig(r) {
  setRigScale(r, r.base); r.pos.set(0, 0, 0); r.yaw = 0; r.rx = 0; r.rz = 0; r.sq = 1; r.sqx = null; r.sqz = null; r.plant = "feet"; r.springs = {};
  for (const m of r.mats) m.color.copy(m.userData.base); r.g.visible = true; poseRig(r, {});
}
let cur = null, mode = "single", titleId = "carried", dinoKey = "Raptor", slow = false, showQ = [], showI = 0, holdT = 0, frameMode = "pc";
const ov = {lower: $("lower"), banner: $("banner"), counter: $("counter"), flash: $("flashov"), pl1: $("pl1"), pl2: $("pl2"), dots: $("dots")};
function clearOverlay() { ov.counter.style.opacity = 0; ov.pl1.style.opacity = 0; ov.pl2.style.opacity = 0; ov.flash.style.transition = "none"; ov.flash.style.opacity = 0; ov.lower.style.opacity = 0; ov.banner.style.opacity = 0; }
function start(id, key, player) {
  clearFx(); clearDebris(); hitStop = 0; camState.shake = 0; camF.t = null;
  if (cur && cur.c.props) scene.remove(cur.c.props);
  scene.background.copy(SKY); scene.fog.color.copy(SKY);
  for (const cache of [rigs, mates, ghosts]) for (const k in cache) cache[k].g.visible = false;
  const T_ = byId(id), r = getRig(rigs, key); resetRig(r);
  const c = {r, t: 0, fired: {}, o: V(0, 0, 0), props: new THREE.Group(), sq: sSpring(1, 20, 0.3)};
  scene.add(c.props);
  if (id === "carried") { const mk = player ? TEAM[0].dino : (key === "Raptor" ? "Dilo" : "Raptor"); c.m = getRig(mates, mk); resetRig(c.m); }
  if (id === "extinct") { c.gh = getRig(ghosts, key, {ghost: true}); resetRig(c.gh); c.gh.g.visible = false; }
  T_.setup(c); poseRig(r, {}); snapSprings(r, {});
  cur = {T: T_, c, player};
  clearOverlay();
  $("lwName").textContent = player ? player.name : "BloxSolid"; $("lwDino").textContent = DINO_NAME[key].toUpperCase(); $("lwTitle").textContent = T_.name; $("lwCap").textContent = T_.cap;
  $("lwStat").textContent = player ? player.stat : T_.stat; ov.lower.classList.toggle("roast", T_.kind === "roast");
  info();
}
function info() {
  const T_ = cur.T;
  $("info").innerHTML = `<p><b style="font-family:var(--silk);color:${T_.kind === "good" ? "var(--green)" : "var(--pink)"}">${T_.name}</b> · ${T_.kind === "good" ? "good title" : "roast"} · ${DINO_NAME[cur.c.r.key]}${cur.c.m ? " (carried by a " + DINO_NAME[cur.c.m.key] + ")" : ""}</p>
    <p><b>Earned by:</b> ${T_.rule} <span style="color:${T_.isNew ? "var(--yellow)" : "var(--muted)"}">(${T_.src})</span></p><p><b>Animation:</b> ${T_.beats}</p>`;
}
function setPressed(sel, attr, v) { document.querySelectorAll(sel).forEach(b => b.setAttribute("aria-pressed", b.dataset[attr] === v)); }
function playSingle() { mode = "single"; ov.dots.innerHTML = ""; start(titleId, dinoKey); setPressed("[data-title]", "title", titleId); setPressed("[data-dino]", "dino", dinoKey); }
function playShow() {
  mode = "show"; showQ = [{banner: true, len: 1.9}].concat(TEAM.map(p => ({p, len: byId(p.title).len + 0.4}))); showI = 0;
  ov.dots.innerHTML = TEAM.map((p, i) => `<span data-i="${i}">${p.name}</span>`).join("");
  start(TEAM[0].title, TEAM[0].dino, TEAM[0]); cur.banner = true; setPressed("[data-title]", "title", ""); setPressed("[data-dino]", "dino", "");
}
function nextShow() {
  showI++; if (showI >= showQ.length) { playShow(); return; }
  const q = showQ[showI]; start(q.p.title, q.p.dino, q.p);
  ov.dots.querySelectorAll("span").forEach((s, i) => s.classList.toggle("on", i === showI - 1));
}
// pickers
const tt = $("titleTabs");
PRIORITY.map(byId).forEach(T_ => { const b = document.createElement("button"); b.className = "tab " + T_.kind; b.dataset.title = T_.id; b.innerHTML = `${T_.name}<small>${T_.kind === "good" ? "good" : "roast"}${T_.isNew ? " · new stat" : ""}</small>`; b.onclick = () => { titleId = T_.id; playSingle(); }; tt.appendChild(b); });
const dt_ = $("dinoTabs");
DINO_KEYS.forEach(k => { const b = document.createElement("button"); b.className = "btn"; b.dataset.dino = k; b.textContent = DINO_NAME[k]; b.onclick = () => { dinoKey = k; playSingle(); }; dt_.appendChild(b); });
$("replay").onclick = () => mode === "show" ? playShow() : playSingle();
$("show").onclick = playShow;
$("slow").onclick = e => { slow = !slow; e.currentTarget.setAttribute("aria-pressed", slow); };
function setFrame(m) { frameMode = m; $("fPC").setAttribute("aria-pressed", m === "pc"); $("fPhone").setAttribute("aria-pressed", m === "phone"); $("stage").className = "stage " + m; resize(); }
$("fPC").onclick = () => setFrame("pc"); $("fPhone").onclick = () => setFrame("phone");
// lists
$("tlist").innerHTML = PRIORITY.map(byId).map(T_ => `<div class="tcard"><b class="${T_.kind}">${T_.name}</b><span>${T_.rule}</span><em>${T_.cap}${T_.isNew ? ' · <span class="new">new counting</span>' : ""}</em></div>`).join("");
$("rules").innerHTML = `<thead><tr><th>Order</th><th>Title</th><th>Who gets it</th><th>Counted</th></tr></thead><tbody>` + PRIORITY.map((id, i) => { const T_ = byId(id); return `<tr><td>${i + 1}</td><td style="font-family:var(--silk);color:${T_.kind === "good" ? "var(--green)" : "var(--pink)"}">${T_.name}</td><td>${T_.rule}</td><td style="color:${T_.isNew ? "var(--yellow)" : "var(--muted)"}">${T_.src}</td></tr>`; }).join("") + "</tbody>";
$("sampleT").innerHTML = `<thead><tr><th>Player</th><th>Dino</th><th>Kills</th><th>Deaths</th><th>On point</th><th>Healed</th><th>Abilities</th><th>Score</th><th>Title</th></tr></thead><tbody>` + TEAM.map(p => `<tr><td>${p.name}</td><td>${DINO_NAME[p.dino]}</td><td>${p.k}</td><td>${p.d}</td><td>${p.pt}</td><td>${p.heal}</td><td>${p.ab}</td><td>${p.score}</td><td style="font-family:var(--silk);color:${byId(p.title).kind === "good" ? "var(--green)" : "var(--pink)"}">${byId(p.title).name}</td></tr>`).join("") + "</tbody>";

function resize() { const w = cv.clientWidth, h = cv.clientHeight; if (!w || !h) return; renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); $("stage").style.setProperty("--u", (h / 100) + "px"); }
window.addEventListener("resize", resize);

function overlay(t, len) {
  const u = win(t, 0.3, 0.55), k = u <= 0 ? 0 : E.back(u);
  ov.lower.style.opacity = u > 0 ? Math.min(1, u * 3) * (1 - win(t, len - 0.25, len)) : 0;
  ov.lower.style.transform = `scale(${lerp(1.7, 1, k)}) rotate(${lerp(-6, 0, k)}deg)`;
}
let last = performance.now(), bannerT = 0;
function loop(now) {
  const rdt = Math.min(0.05, (now - last) / 1000); last = now;
  if (!window.__manual) step(rdt * (slow ? 0.33 : 1));
  requestAnimationFrame(loop);
}
let noRender = false;
const render = () => { if (!noRender) renderer.render(scene, cam); };
function step(dt) {
  if (!cur) return;
  camState.shake *= Math.pow(0.015, dt);
  if (hitStop > 0) { hitStop -= dt; render(); return; }
  const c = cur.c, T_ = cur.T;
  if (cur.banner) { // the VICTORY banner before the first title: the first dino idles under it
    bannerT += dt; const b = bannerT;
    ov.banner.style.opacity = sat(b / 0.2) * (1 - win(b, 1.6, 1.9)); ov.banner.style.transform = `scale(${lerp(1.5, 1, E.back(sat(b / 0.3)))})`;
    T_.update(c, 0, dt); stepFx(dt); stepDebris(dt);
    if (b >= 1.9) { cur.banner = false; bannerT = 0; showI = 1; ov.dots.querySelectorAll("span").forEach((s, i) => s.classList.toggle("on", i === 0)); }
    render(); $("prog").style.width = "0%"; return;
  }
  c.t += dt; T_.update(c, c.t, dt); stepFx(dt); stepDebris(dt);
  overlay(c.t, T_.len + (mode === "show" ? 0.4 : 1.2));
  $("prog").style.width = (100 * Math.min(1, c.t / T_.len)) + "%";
  if (mode === "show" && c.t >= T_.len + 0.4) nextShow();
  else if (mode === "single" && c.t >= T_.len + 1.2) playSingle();
  render();
}
// deterministic seek for screenshots: replay from 0 to t in small steps
window.__seek = (id, key, t) => { titleId = id; dinoKey = key; playSingle(); noRender = true; const n = Math.ceil(t / (1 / 30)); for (let i = 0; i < n; i++) step(1 / 30); noRender = false; renderer.render(scene, cam); };
window.__step = step;
const fontsReady = (document.fonts && document.fonts.load) ? Promise.all([document.fonts.load("700 40px Silkscreen")]).catch(() => {}) : Promise.resolve();
Promise.race([fontsReady, new Promise(r => setTimeout(r, 2500))]).then(() => { resize(); playSingle(); requestAnimationFrame(loop); window.__ready = true; });
