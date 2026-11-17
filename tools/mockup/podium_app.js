// Podium & Leaderboards mockup app v0.2. MODELS = model_json.py exports of src/shared/Models/*ModelData.luau (in-game scale: T-Rex 1, others 2).
const MODELS = __MODELS__;
const $ = id => document.getElementById(id);
const rad = THREE.MathUtils.degToRad;
const C = {gold: 0xffd25a, silver: 0xc9d3e0, bronze: 0xd08a4a, blue: 0x5aa0ff, red: 0xe0284a, yellow: 0xffc832, panel: 0x14141a, steel: 0x2b3242};
const DINO_NAME = {TRex: "T-Rex", Raptor: "Raptor", Pachy: "Pachy", Herrera: "Herrera", Teno: "Teno", Troodon: "Troodon", Therizino: "Therizino", Dilo: "Dilo"};

// ---------------- shared: dino builder (same maths as roster_app.js) ----------------
function cfm(a) { const m = new THREE.Matrix4(); m.set(a[3], a[4], a[5], a[0], a[6], a[7], a[8], a[1], a[9], a[10], a[11], a[2], 0, 0, 0, 1); return m; }
const matCache = {};
function mat(hex) { return matCache[hex] || (matCache[hex] = new THREE.MeshLambertMaterial({color: parseInt(hex, 16)})); }
const corner = new THREE.Vector3();
function buildDino(parent, key) {
  const D = MODELS[key].model, g = new THREE.Group(); parent.add(g);
  const segs = {}, parts = [];
  for (const s of D.segs) {
    const rootInv = cfm(s.root).invert(); segs[s.n] = [];
    for (const p of s.parts) {
      const hidden = (p.t || 0) >= 1 || p.n.includes("_fold");
      const m = new THREE.Mesh(new THREE.BoxGeometry(p.s[0], p.s[1], p.s[2]), mat(p.c)); m.matrixAutoUpdate = false; m.visible = !hidden; g.add(m);
      const info = {mesh: m, local: rootInv.clone().multiply(cfm(p.cf)), size: p.s, hidden}; segs[s.n].push(info); parts.push(info);
    }
  }
  const joints = D.joints.map(j => ({p0: j.p0, p1: j.p1, c0: cfm(j.c0), c1inv: cfm(j.c1).invert()}));
  const d = {key, g, segs, parts, joints, base: MODELS[key].scale, scale: MODELS[key].scale, x: 0, y: 0, z: 0, yaw: 0, pitch: 0, box: new THREE.Box3()};
  pose(d); const sz = d.box.getSize(new THREE.Vector3()); d.len = sz.z; d.wid = sz.x; d.hgt = sz.y; d.unit = {len: sz.z / d.scale, wid: sz.x / d.scale, hgt: sz.y / d.scale};
  return d;
}
function pose(d) {
  const W = {HRP: new THREE.Matrix4().makeRotationY(d.yaw).multiply(new THREE.Matrix4().makeRotationX(d.pitch))};
  for (const j of d.joints) W[j.p1] = W[j.p0].clone().multiply(j.c0).multiply(j.c1inv);
  let minY = Infinity; const box = new THREE.Box3();
  const S = new THREE.Matrix4().makeScale(d.scale, d.scale, d.scale);
  for (const n in d.segs) for (const p of d.segs[n]) {
    const m = S.clone().multiply(W[n]).multiply(p.local); p.mesh.matrix.copy(m);
    if (p.hidden) continue;
    for (let i = 0; i < 8; i++) { corner.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(m); minY = Math.min(minY, corner.y); box.expandByPoint(corner); }
  }
  const lift = new THREE.Matrix4().makeTranslation(d.x, -minY + d.y, d.z);
  for (const p of d.parts) p.mesh.matrix.premultiply(lift);
  box.translate(new THREE.Vector3(d.x, -minY + d.y, d.z)); d.box = box;
}
function setScale(d, s) { d.scale = s; d.len = d.unit.len * s; d.wid = d.unit.wid * s; d.hgt = d.unit.hgt * s; }
function disposeGroup(g) { g.traverse(o => { if (o.geometry) o.geometry.dispose(); if (o.material && o.material.map) o.material.map.dispose(); }); g.parent && g.parent.remove(g); }

// text on a canvas -> texture (Silkscreen = the game's title font since FontSwap 1.0)
function canvasTex(w, h, draw) { const c = document.createElement("canvas"); c.width = w; c.height = h; const x = c.getContext("2d"); draw(x, w, h); const t = new THREE.CanvasTexture(c); t.anisotropy = 4; return {tex: t, cv: c, ctx: x}; }
function plane(w, h, tex, opts = {}) { return new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial(Object.assign({map: tex, transparent: true}, opts))); }
const SILK = '"Silkscreen", "Courier New", monospace';
function box(w, h, d, color, basic) { return new THREE.Mesh(new THREE.BoxGeometry(w, h, d), basic ? new THREE.MeshBasicMaterial({color}) : new THREE.MeshLambertMaterial({color})); }
function hexCss(n) { return "#" + n.toString(16).padStart(6, "0"); }

// frame (PC 16:9 / phone 19.5:9)
let frameMode = "pc";
function setFrame(m) {
  frameMode = m; $("fPC").setAttribute("aria-pressed", m === "pc"); $("fPhone").setAttribute("aria-pressed", m === "phone");
  for (const id of ["podStage", "lbStage"]) { $(id).classList.toggle("pc", m === "pc"); $(id).classList.toggle("phone", m === "phone"); }
  resizeAll();
}
$("fPC").onclick = () => setFrame("pc"); $("fPhone").onclick = () => setFrame("phone");

function makeView(cvId, stageId) {
  const cv = $(cvId), renderer = new THREE.WebGLRenderer({canvas: cv, antialias: true, preserveDrawingBuffer: true});
  renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
  const v = {cv, renderer, stage: $(stageId), cam: new THREE.PerspectiveCamera(34, 16 / 9, 0.1, 3000), yawUser: 0, drag: null};
  cv.addEventListener("pointerdown", e => { v.drag = e.clientX; cv.setPointerCapture(e.pointerId); });
  cv.addEventListener("pointermove", e => { if (v.drag !== null) { v.yawUser += (e.clientX - v.drag) * 0.006; v.drag = e.clientX; } });
  cv.addEventListener("pointerup", () => { v.drag = null; });
  return v;
}
const views = [];
function resizeAll() {
  for (const v of views) {
    const w = v.cv.clientWidth, h = v.cv.clientHeight; if (!w || !h) continue;
    v.renderer.setSize(w, h, false); v.cam.aspect = w / h; v.cam.updateProjectionMatrix(); v.stage.style.setProperty("--u", (h / 100) + "px");
  }
}
window.addEventListener("resize", resizeAll);
function project(v, p) { const q = p.clone().project(v.cam); return [(q.x + 1) / 2 * v.cv.clientWidth, (1 - q.y) / 2 * v.cv.clientHeight, q.z]; }

// ======================================================================================
// 1 · VICTORY PODIUM
// ======================================================================================
const P = makeView("podCv", "podStage"); views.push(P);
const pScene = new THREE.Scene();
pScene.background = new THREE.Color(0x0b1020); pScene.fog = new THREE.Fog(0x0b1020, 200, 900);
pScene.add(new THREE.HemisphereLight(0xdfe8ff, 0x2a2f40, 0.7));
const pKey = new THREE.DirectionalLight(0xffffff, 0.55); pKey.position.set(-20, 60, -60); pScene.add(pKey);
const pRim = new THREE.DirectionalLight(0x8ab8ff, 0.35); pRim.position.set(30, 30, 60); pScene.add(pRim);
// stars (the Studio preview stage sits in the sky at y 600)
{ const g = new THREE.BufferGeometry(), n = 600, a = new Float32Array(n * 3);
  for (let i = 0; i < n; i++) { const th = Math.random() * Math.PI * 2, ph = Math.random() * 0.9 + 0.05, r = 1200; a[i * 3] = Math.cos(th) * Math.sin(ph) * r; a[i * 3 + 1] = Math.cos(ph) * r * 0.6 + 40; a[i * 3 + 2] = Math.sin(th) * Math.sin(ph) * r; }
  g.setAttribute("position", new THREE.BufferAttribute(a, 3)); pScene.add(new THREE.Points(g, new THREE.PointsMaterial({color: 0xffffff, size: 2, sizeAttenuation: false, fog: false}))); }

const SAMPLES = [
  {score: "BLUE 250 – 180 RED", win: "BLUE", top: [["BloxSolid", "Raptor", 11, 2, "1:42"], ["Kiwi", "Dilo", 7, 3, "1:10"], ["Vex", "Pachy", 5, 4, "2:05"], ["Moss", "Herrera", 4, 6, "0:38"]]},
  {score: "BLUE 172 – 250 RED", win: "RED", top: [["Flint", "TRex", 9, 1, "2:31"], ["BloxSolid", "Herrera", 8, 5, "0:44"], ["Kiwi", "Teno", 6, 2, "1:58"], ["Juno", "Troodon", 3, 3, "1:12"]]},
  {score: "BLUE 250 – 241 RED", win: "BLUE", top: [["Vex", "Therizino", 12, 4, "1:05"], ["BloxSolid", "Troodon", 6, 1, "2:20"], ["Moss", "Raptor", 6, 3, "0:51"], ["Kiwi", "Dilo", 5, 2, "1:33"]]},
];
let pod = "A", sampleI = 0, sizeMode = "real", camMove = true, podGroup = null, podDinos = [], podLabels = [], confetti = null, podT0 = performance.now();
const podOv = $("podOv");
let cardsEl = null, cardCams = [];

function buildPodium() {
  if (podGroup) disposeGroup(podGroup); podGroup = new THREE.Group(); pScene.add(podGroup);
  podOv.innerHTML = ""; podLabels = []; podDinos = []; confetti = null; cardsEl = null; cardCams = [];
  const S = SAMPLES[sampleI];
  const teamCol = S.win === "BLUE" ? C.blue : C.red;
  if (pod === "C") return buildCards(S);
  const n = pod === "A" ? 3 : 4;
  const players = S.top.slice(0, n);
  podDinos = players.map(p => buildDino(podGroup, p[1]));
  // "Same height": every dino scaled so it stands as tall as an in-game raptor; "Real": in-game scale
  const refH = 13;
  podDinos.forEach(d => setScale(d, sizeMode === "same" ? d.base * refH / d.hgt : d.base));
  // slots, left -> right on screen = +X -> -X (camera at -Z looking +Z)
  let order, heights, cols;
  if (pod === "A") { order = [1, 0, 2]; heights = [8, 5.5, 3.5]; cols = [C.gold, C.silver, C.bronze]; } // heights / cols by rank, order = slots left -> right
  else { order = [1, 0, 2, 3]; heights = [6, 2, 2, 2]; cols = [C.gold, teamCol, teamCol, teamCol]; }
  // each dino turned 3/4 toward the camera, footprint measured after the turn
  podDinos.forEach(d => { d.yaw0 = rad(32); d.yaw = d.yaw0; d.x = 0; d.y = 0; d.pitch = 0; pose(d); const sz = d.box.getSize(new THREE.Vector3()); d.fw = sz.x; d.fd = sz.z; d.hgt = sz.y; });
  const slotW = i => Math.max(14, podDinos[i].fw + 4);
  const depth = Math.max(18, ...podDinos.map(d => d.fd)) + 6;
  const total = order.reduce((s, i) => s + slotW(i), 0);
  let off = total / 2; const xs = [];
  for (const i of order) { xs[i] = off - slotW(i) / 2; off -= slotW(i); }
  const floorW = total + 26, floorD = depth + 22, floorZ = 4;
  // floor (diamond plate look: dark steel + plate lines) with the gold neon front rim
  const floor = box(floorW, 2, floorD, C.steel); floor.position.set(0, -1, floorZ); podGroup.add(floor);
  const lines = new THREE.GridHelper(Math.max(floorW, floorD), Math.round(Math.max(floorW, floorD) / 3), 0x3a4356, 0x3a4356); lines.position.set(0, 0.03, floorZ); lines.scale.set(floorW / Math.max(floorW, floorD), 1, floorD / Math.max(floorW, floorD)); podGroup.add(lines);
  const rim = box(floorW, 0.5, 0.6, pod === "A" ? C.gold : teamCol, true); rim.position.set(0, 0.25, floorZ - floorD / 2); podGroup.add(rim);
  // backdrop with neon strips + the banner
  const topY = Math.max(...podDinos.map((d, i) => heights[i] + d.hgt));
  const bdH = Math.max(34, topY + 30), bdZ = floorZ + floorD / 2 + 1;
  const bd = box(floorW, bdH, 2, C.panel); bd.position.set(0, bdH / 2, bdZ); podGroup.add(bd);
  for (let k = 0; k < 3; k++) { const s = box(floorW - 4, 0.4, 0.3, teamCol, true); s.position.set(0, 3 + k * 2.2, bdZ - 1.1); podGroup.add(s); }
  for (const sx of [-1, 1]) { const s = box(0.4, bdH - 4, 0.3, teamCol, true); s.position.set(sx * (floorW / 2 - 2), bdH / 2, bdZ - 1.1); podGroup.add(s); }
  const title = pod === "A" ? "VICTORY" : S.win + " WINS";
  const ban = canvasTex(1024, 300, (x, w, h) => {
    x.textAlign = "center"; x.textBaseline = "middle";
    x.font = `700 150px ${SILK}`; x.fillStyle = "#6b4a00"; x.fillText(title, w / 2 + 6, 112); x.fillStyle = pod === "A" ? "#ffc832" : hexCss(teamCol); x.fillText(title, w / 2, 104);
    x.font = `700 46px ${SILK}`; x.fillStyle = "#cfd3dc"; x.fillText(S.score + " · HARDPOINT", w / 2, 250);
  });
  const bw = Math.min(floorW - 8, 70), banner = plane(bw, bw * 300 / 1024, ban.tex); banner.position.set(0, bdH - bw * 300 / 1024 / 2 - 3, bdZ - 1.2); banner.rotation.y = Math.PI; podGroup.add(banner);
  // steps + number plates + spotlights
  order.forEach((i, slot) => {
    const h = heights[i], w = slotW(i), col = cols[i];
    const st = box(w - 1, h, depth, col); st.material.emissive = new THREE.Color(col).multiplyScalar(0.12); st.position.set(xs[i], h / 2, 0); podGroup.add(st);
    const lip = box(w - 0.6, 0.4, depth + 0.4, 0xffffff, true); lip.material.color.set(col).multiplyScalar(1.15); lip.position.set(xs[i], h + 0.2, 0); podGroup.add(lip);
    const label = pod === "A" ? String(i + 1) : (i === 0 ? "MVP" : "");
    if (label) {
      const t = canvasTex(256, 256, (x, W, H) => { x.textAlign = "center"; x.textBaseline = "middle"; x.font = `700 ${label.length > 1 ? 92 : 190}px ${SILK}`; x.fillStyle = "rgba(0,0,0,.35)"; x.fillText(label, W / 2 + 6, H / 2 + 10); x.fillStyle = "#1b1406"; x.fillText(label, W / 2, H / 2 + 4); });
      const s = Math.min(h * 0.85, w * 0.5, 6.5) * (label.length > 1 ? 1.6 : 1); const pl = plane(s, s, t.tex); pl.position.set(xs[i], h / 2, -depth / 2 - 0.05); pl.rotation.y = Math.PI; podGroup.add(pl);
    }
    const spot = new THREE.SpotLight(0xfff2d0, i === 0 ? 1.3 : 0.8, 160, rad(i === 0 ? 16 : 13), 0.5, 1); spot.position.set(xs[i], h + 60, -14); spot.target.position.set(xs[i], h, 0); podGroup.add(spot, spot.target);
    const d = podDinos[i]; d.x = xs[i]; d.z = 0; d.baseY = h; d.y = h; d.yaw = d.yaw0; pose(d); const cc = d.box.getCenter(new THREE.Vector3()); d.x += xs[i] - cc.x; d.z -= cc.z; d.bx = d.x; pose(d);
    const pl = players[i], el = document.createElement("div"); el.className = "lbl";
    const cls = pod === "A" ? "p" + (i + 1) : (i === 0 ? "mvp" : "");
    el.innerHTML = `<b class="${cls}">${pod === "A" ? (i + 1) + " · " : (i === 0 ? "★ MVP · " : "")}${pl[0]}</b><span>${DINO_NAME[pl[1]]} · ${pl[2]} K</span>`;
    podOv.appendChild(el); podLabels[i] = el;
  });
  if (pod === "B") confetti = makeConfetti(podGroup, floorW, topY + 30, floorZ, floorD);
  const tm = document.createElement("div"); tm.className = "timer"; tm.id = "podTimer"; podOv.appendChild(tm);
  P.fit = {floorW, topY, depth};
  podT0 = performance.now();
}
function makeConfetti(parent, w, h, z0, d) {
  const n = 260, geo = new THREE.PlaneGeometry(0.7, 0.45), m = new THREE.MeshBasicMaterial({side: THREE.DoubleSide, vertexColors: false});
  const im = new THREE.InstancedMesh(geo, new THREE.MeshBasicMaterial({side: THREE.DoubleSide}), n);
  const cols = [0xffc832, 0x5aa0ff, 0xff6b84, 0x46e08a, 0x7fe9ff, 0xffffff], st = [];
  for (let i = 0; i < n; i++) { st.push({x: (Math.random() - .5) * w, y: Math.random() * h, z: z0 + (Math.random() - .6) * d, vy: 4 + Math.random() * 5, r: Math.random() * 6, vr: (Math.random() - .5) * 8, h}); im.setColorAt(i, new THREE.Color(cols[i % cols.length])); }
  parent.add(im); return {im, st, o: new THREE.Object3D()};
}
function tickConfetti(c, dt) {
  c.st.forEach((s, i) => { s.y -= s.vy * dt; s.r += s.vr * dt; if (s.y < 0) s.y = s.h; c.o.position.set(s.x + Math.sin(s.r) * 0.8, s.y, s.z); c.o.rotation.set(s.r, s.r * 0.7, 0); c.o.updateMatrix(); c.im.setMatrixAt(i, c.o.matrix); });
  c.im.instanceMatrix.needsUpdate = true;
}
// option C: the HardpointHUD MVP / SVP cards, each with a small 3D window; the dino now stands on a gold / silver step
function buildCards(S) {
  cardsEl = document.createElement("div"); cardsEl.className = "cards";
  cardsEl.innerHTML = `<div class="vic">VICTORY</div>` + [0, 1].map(i => { const p = S.top[i]; return `<div class="hc ${i ? "svp" : ""}"><h3>${i ? "SVP" : "MVP"}</h3><div class="vp" data-i="${i}"></div><div class="nm">${p[0]}</div><div class="st">${p[2]} K · ${p[3]} D · ${p[4]} ON POINT</div></div>`; }).join("");
  podOv.appendChild(cardsEl);
  [0, 1].forEach(i => {
    const p = S.top[i], gx = i ? 400 : -400;
    const d = buildDino(podGroup, p[1]); // each card frames its own dino, so sizes don't change the look
    const stW = Math.max(12, d.wid + 4), stD = Math.max(12, d.len + 4), h = 2.5;
    const st = box(stW, h, stD, i ? C.silver : C.gold); st.material.emissive = new THREE.Color(i ? C.silver : C.gold).multiplyScalar(0.12); st.position.set(gx, h / 2, 0); podGroup.add(st);
    const fl = box(80, 1, 80, 0x26303c); fl.position.set(gx, -0.5, 0); podGroup.add(fl);
    d.x = gx; d.z = 0; d.baseY = h; d.y = h; d.yaw0 = 0; d.yaw = 0; pose(d); podDinos[i] = d;
    const cam = new THREE.PerspectiveCamera(30, 1, 0.1, 1000); cardCams[i] = {cam, d, gx};
  });
  podOv.querySelectorAll(".vp").forEach(e => e.style.background = "rgba(38,46,58,.0)");
}
function podInfo() {
  const t = {
    A: "<b class='k'>A · Top 3 podium.</b> After the VICTORY banner the camera cuts to a stage in the sky with the match's top 3 players' own dinos on gold, silver and bronze steps (most kills, ties by time on point), a spotlight on each, then the scoreboard. Replaces the MVP / SVP cards. Same for both teams: everyone sees the top 3 of the whole match.",
    B: "<b class='k'>B · Winning team on stage.</b> The whole winning team (up to 4) on a stage in their team colour, the MVP on the high gold step, confetti. The losing team isn't shown. Same 6 s slot, replaces the cards.",
    C: "<b class='k'>C · Keep the cards, add steps.</b> Smallest change: today's MVP / SVP cards stay where they are, the dino in each card's window now stands on a gold or silver step and does a victory pose. No new stage.",
  }[pod];
  $("podInfo").innerHTML = `<p>${t}</p><p class="muted" style="color:var(--muted);font-size:13px;margin:0">${sizeMode === "real" ? "Real sizes: each dino at its in-game size, so a T-Rex dwarfs a Herrera and the steps widen to fit it." : "Same height: every dino scaled to the same height on the podium so nobody looks small."} Sample match ${sampleI + 1} of ${SAMPLES.length}: ${SAMPLES[sampleI].score}.</p>`;
}
document.querySelectorAll("[data-pod]").forEach(b => b.onclick = () => { pod = b.dataset.pod; document.querySelectorAll("[data-pod]").forEach(x => x.setAttribute("aria-pressed", x === b)); P.yawUser = 0; buildPodium(); podInfo(); updatePicks(); });
$("sample").onclick = () => { sampleI = (sampleI + 1) % SAMPLES.length; buildPodium(); podInfo(); };
$("szReal").onclick = () => { sizeMode = "real"; $("szReal").setAttribute("aria-pressed", true); $("szSame").setAttribute("aria-pressed", false); buildPodium(); podInfo(); updatePicks(); };
$("szSame").onclick = () => { sizeMode = "same"; $("szReal").setAttribute("aria-pressed", false); $("szSame").setAttribute("aria-pressed", true); buildPodium(); podInfo(); updatePicks(); };
$("podPlay").onclick = e => { camMove = !camMove; e.currentTarget.setAttribute("aria-pressed", camMove); e.currentTarget.textContent = camMove ? "Camera move on" : "Camera move off"; };

function hop(d, t, i) { // stand-in victory pose: a hop and a head-up, staggered per dino
  const ph = (t * 1.6 + i * 0.37) % 1.6;
  const k = ph < 0.5 ? Math.sin(ph / 0.5 * Math.PI) : 0;
  d.y = d.baseY + k * Math.min(3, d.hgt * 0.18); if (d.bx !== undefined) d.x = d.bx; d.pitch = -k * 0.12; d.yaw = d.yaw0 + Math.sin(t * 0.9 + i) * 0.08; pose(d);
}
function renderPodium(now, dt) {
  const t = Math.max(0, (now - podT0) / 1000);
  const v = P, W = v.cv.clientWidth, H = v.cv.clientHeight;
  if (pod === "C") {
    v.renderer.setScissorTest(false); v.renderer.setClearColor(0x0d1218); v.renderer.clear();
    podDinos.forEach((d, i) => hop(d, t, i));
    v.renderer.setScissorTest(true);
    const cr = v.cv.getBoundingClientRect();
    podOv.querySelectorAll(".hc").forEach(el => { const r = el.getBoundingClientRect(), x = r.left - cr.left, y = cr.bottom - r.bottom; v.renderer.setViewport(x, y, r.width, r.height); v.renderer.setScissor(x, y, r.width, r.height); v.renderer.setClearColor(0x14141a); v.renderer.clear(); });
    podOv.querySelectorAll(".vp").forEach(el => {
      const i = +el.dataset.i, r = el.getBoundingClientRect(), cc = cardCams[i]; if (!cc) return;
      const x = r.left - cr.left, y = cr.bottom - r.bottom, w = r.width, h = r.height;
      v.renderer.setViewport(x, y, w, h); v.renderer.setScissor(x, y, w, h); v.renderer.setClearColor(0x262e3a); v.renderer.clear();
      cc.cam.aspect = w / h; cc.cam.updateProjectionMatrix();
      const d = cc.d, c = new THREE.Vector3(cc.gx, (d.baseY + d.hgt) * 0.5, 0), span = Math.max(d.hgt + d.baseY, d.wid * 1.1 / cc.cam.aspect) * 1.25;
      const r0 = span * 0.5 / Math.tan(rad(cc.cam.fov / 2)) + d.len * 0.3, a = rad(25) + Math.sin(t * 0.4) * 0.15 + v.yawUser;
      cc.cam.position.set(c.x + Math.sin(a) * r0, c.y + r0 * 0.22, -Math.cos(a) * r0); cc.cam.lookAt(c);
      v.renderer.render(pScene, cc.cam);
    });
    v.renderer.setScissorTest(false); v.renderer.setViewport(0, 0, W, H);
    return;
  }
  podDinos.forEach((d, i) => hop(d, t, i));
  if (confetti) tickConfetti(confetti, dt);
  const f = P.fit, cam = v.cam;
  const target = new THREE.Vector3(0, f.topY * 0.5 + 2, 0);
  const fitW = (f.floorW * 0.5 + 2) / (Math.tan(rad(cam.fov / 2)) * cam.aspect), fitH = (f.topY * 0.5 + 16) / Math.tan(rad(cam.fov / 2));
  let r = Math.max(fitW, fitH) + f.depth * 0.5;
  // camera move: a slow push-in and drift across, like a 6 s cutscene (loops)
  const k = camMove ? (t % 8) / 8 : 0.5, ease = k * k * (3 - 2 * k);
  r *= camMove ? 1.18 - 0.16 * ease : 1.05;
  const a = (camMove ? rad(-14 + 24 * ease) : 0) + v.yawUser;
  cam.position.set(target.x + Math.sin(a) * r, target.y + r * 0.2, target.z - Math.cos(a) * r); cam.lookAt(target);
  v.renderer.render(pScene, cam);
  podDinos.forEach((d, i) => {
    const el = podLabels[i]; if (!el) return;
    const [x, y, z] = project(v, new THREE.Vector3((d.box.min.x + d.box.max.x) / 2, d.box.max.y + 1.2, (d.box.min.z + d.box.max.z) / 2));
    el.style.display = z < 1 ? "block" : "none"; el.style.left = x + "px"; el.style.top = y + "px";
  });
  const tm = $("podTimer"); if (tm) tm.textContent = `SCOREBOARD IN ${Math.max(0, 6 - Math.floor(t % 8))}`;
}

// ======================================================================================
// 2 · LEADERBOARDS
// ======================================================================================
const L = makeView("lbCv", "lbStage"); views.push(L);
const lScene = new THREE.Scene();
lScene.background = new THREE.Color(0x8fc6e8); lScene.fog = new THREE.Fog(0x8fc6e8, 260, 900);
lScene.add(new THREE.HemisphereLight(0xf2f8ff, 0x7a8a5a, 0.85));
const lSun = new THREE.DirectionalLight(0xffffff, 0.75); lSun.position.set(30, 60, 40); lScene.add(lSun);
{ const gnd = new THREE.Mesh(new THREE.PlaneGeometry(2000, 2000), new THREE.MeshLambertMaterial({color: 0x6fae4a})); gnd.rotation.x = -Math.PI / 2; lScene.add(gnd);
  const grid = new THREE.GridHelper(2000, 400, 0x5c9a3c, 0x5c9a3c); grid.position.y = 0.02; grid.material.opacity = 0.3; grid.material.transparent = true; lScene.add(grid);
  // a few trees for scale / island feel (blocky, like the island's)
  const rnd = (s => () => (s = (s * 16807) % 2147483647) / 2147483647)(7);
  for (let i = 0; i < 40; i++) { const a = rnd() * Math.PI * 2, rr = 80 + rnd() * 260, x = Math.cos(a) * rr, z = Math.sin(a) * rr - 60; if (Math.abs(x) < 40 && z > -90 && z < 40) continue;
    const h = 14 + rnd() * 12, tr = box(2.4, h, 2.4, 0x6b4a2b); tr.position.set(x, h / 2, z); lScene.add(tr);
    const lf = box(11, 9, 11, rnd() > .5 ? 0x3f8a3a : 0x4c9a40); lf.position.set(x, h + 3, z); lScene.add(lf); }
  // spawn pad (SpawnLocation on the island at (88, 0.1, 904), facing -Z; the board 48 studs in front of it)
  const pad = box(12, 1, 12, 0xa3a8b0); pad.position.set(0, 0.5, 0); lScene.add(pad);
}
const BOARD_Z = -48;
const board = new THREE.Group(); lScene.add(board); board.position.set(0, 0, BOARD_Z);
const BW = 30, BH = 20, BY = 7 + BH / 2;
{ for (const sx of [-1, 1]) { const p = box(1.6, BY + BH / 2, 1.6, C.steel); p.position.set(sx * (BW / 2 - 2), (BY + BH / 2) / 2, -1.4); board.add(p); }
  const fr = box(BW + 2, BH + 2, 1.2, C.panel); fr.position.set(0, BY, 0); board.add(fr);
  const top = box(BW + 2.4, 0.6, 1.4, C.gold, true); top.position.set(0, BY + BH / 2 + 1.3, 0); board.add(top);
  const bot = box(BW + 2.4, 0.4, 1.4, C.gold, true); bot.position.set(0, BY - BH / 2 - 1.2, 0); board.add(bot); }
const boardTex = canvasTex(1200, 800, () => {});
const screen = plane(BW, BH, boardTex.tex, {transparent: false}); screen.position.set(0, BY, 0.62); board.add(screen);
const glow = new THREE.PointLight(0xffd25a, 0.6, 40); glow.position.set(0, BY, 6); board.add(glow);
const playerDino = buildDino(lScene, "Raptor"); playerDino.x = 10; playerDino.z = 6; playerDino.yaw = 0.25; pose(playerDino);

const NAMES = ["Raptorlord", "Kiwi", "Vex", "Flint", "Moss", "Juno", "Sable", "Torque", "Pixel", "Ember", "Quill", "Rook", "Nova", "Bramble", "Cinder", "Gale", "Hex", "Ivy", "Jolt", "Koda", "Lux", "Mako", "Nix", "Onyx", "Pike", "Reef", "Sly", "Tusk", "Umbra", "Volt", "Wren", "Yeti", "Zed", "Ash", "Bolt", "Clay", "Dune", "Echo", "Fang", "Grit", "Haze", "Iron", "Jinx", "Kite", "Lynx", "Mint", "Nash", "Oak", "Prism", "Quake"];
const DINOS8 = ["Raptor", "TRex", "Dilo", "Pachy", "Herrera", "Teno", "Troodon", "Therizino"];
function rows(stat, tf) {
  const base = {WINS: 212, KILLS: 1840, STREAK: 19, LEVEL: 30}[stat], wk = tf === "week" ? {WINS: 0.11, KILLS: 0.09, STREAK: 0.5, LEVEL: 1}[stat] : 1;
  const seed = {WINS: 1, KILLS: 5, STREAK: 11, LEVEL: 17}[stat] + (tf === "week" ? 3 : 0);
  const out = []; let v = base * wk;
  for (let i = 0; i < 50; i++) { out.push({name: NAMES[(i * 7 + seed) % NAMES.length], dino: DINOS8[(i * 3 + seed) % 8], v: Math.max(1, Math.round(v))}); v *= stat === "LEVEL" ? 0.985 : 0.955; }
  const me = {WINS: 32, KILLS: 245, STREAK: 4, LEVEL: 12}[stat], meW = tf === "week" ? Math.max(1, Math.round(me * wk)) : me;
  return {list: out, me: {rank: tf === "week" ? 27 : 41, v: meW}};
}
const STAT_LABEL = {WINS: "ARENA WINS", KILLS: "KILLS", STREAK: "BEST STREAK", LEVEL: "DINO LEVEL"};
function statsOn() { return [...document.querySelectorAll("[data-st]")].filter(b => b.getAttribute("aria-pressed") === "true").map(b => b.dataset.st); }
function weeklyOn() { return document.querySelector('[data-tf="week"]').getAttribute("aria-pressed") === "true"; }
// the island board cycles every stat (and all-time / this week) every 8 s
function boardPages() { const p = []; for (const s of statsOn()) { p.push([s, "all"]); if (weeklyOn()) p.push([s, "week"]); } return p.length ? p : [["WINS", "all"]]; }
let lastPage = "";
function drawBoard(t) {
  const pages = boardPages(), pi = Math.floor(t / 8) % pages.length, [stat, tf] = pages[pi], key = stat + tf + pages.length + pi;
  const x = boardTex.ctx, w = 1200, h = 800, prog = (t % 8) / 8;
  x.fillStyle = "#14141a"; x.fillRect(0, 0, w, h);
  x.textBaseline = "middle";
  x.font = `700 64px ${SILK}`; x.fillStyle = "#ffc832"; x.textAlign = "left"; x.fillText("TOP PLAYERS", 40, 60);
  x.textAlign = "right"; x.font = `700 36px ${SILK}`; x.fillStyle = tf === "week" ? "#7fe9ff" : "#cfd3dc"; x.fillText(tf === "week" ? "THIS WEEK" : "ALL-TIME", w - 40, 62);
  // tab strip
  let tx = 40; x.textAlign = "left"; x.font = `700 30px ${SILK}`;
  for (const s of statsOn().length ? statsOn() : ["WINS"]) { const lab = STAT_LABEL[s], tw = x.measureText(lab).width + 32; x.fillStyle = s === stat ? "#ffc832" : "#2b3542"; roundRect(x, tx, 108, tw, 48, 10); x.fill(); x.fillStyle = s === stat ? "#1b1406" : "#cfd3dc"; x.fillText(lab, tx + 16, 133); tx += tw + 12; }
  const R = rows(stat, tf); const top = R.list.slice(0, 10), rh = 52, y0 = 178;
  top.forEach((r, i) => {
    const y = y0 + i * rh; x.fillStyle = i % 2 ? "#1a1f2a" : "#1d2230"; roundRect(x, 30, y, w - 60, rh - 6, 8); x.fill();
    x.font = `700 32px ${SILK}`; x.textAlign = "left"; x.fillStyle = ["#ffd25a", "#c9d3e0", "#d08a4a"][i] || "#8f99aa"; x.fillText(String(i + 1), 52, y + rh / 2 - 2);
    x.fillStyle = "#ffffff"; x.fillText(r.name, 140, y + rh / 2 - 2);
    x.font = `700 24px ${SILK}`; x.fillStyle = "#8f99aa"; x.fillText(DINO_NAME[r.dino].toUpperCase(), 620, y + rh / 2 - 2);
    x.font = `700 32px ${SILK}`; x.textAlign = "right"; x.fillStyle = "#ffffff"; x.fillText(r.v.toLocaleString("en-US"), w - 56, y + rh / 2 - 2);
  });
  // your own row (each player's screen shows their own rank)
  const y = y0 + 10 * rh + 4; x.fillStyle = "#2a2410"; roundRect(x, 30, y, w - 60, rh, 8); x.fill(); x.strokeStyle = "#ffc832"; x.lineWidth = 4; x.stroke();
  x.font = `700 32px ${SILK}`; x.textAlign = "left"; x.fillStyle = "#ffc832"; x.fillText("#" + R.me.rank, 52, y + rh / 2); x.fillStyle = "#ffffff"; x.fillText("YOU · BloxSolid", 170, y + rh / 2);
  x.textAlign = "right"; x.fillText(String(R.me.v), w - 56, y + rh / 2);
  // flip timer
  x.fillStyle = "#2b3542"; x.fillRect(30, h - 14, w - 60, 6); x.fillStyle = "#ffc832"; x.fillRect(30, h - 14, (w - 60) * prog, 6);
  boardTex.tex.needsUpdate = true;
}
function roundRect(x, a, b, w, h, r) { x.beginPath(); x.moveTo(a + r, b); x.arcTo(a + w, b, a + w, b + h, r); x.arcTo(a + w, b + h, a, b + h, r); x.arcTo(a, b + h, a, b, r); x.arcTo(a, b, a + w, b, r); x.closePath(); }

let lb = "C", lbView = "island", panelOpen = false, pStat = "WINS", pTf = "all";
const lbOv = $("lbOv");
function buildLbOverlay() {
  lbOv.innerHTML = "";
  const showMenu = lb === "B" || (lb === "C" && lbView === "menu");
  if (showMenu) {
    const m = document.createElement("div"); m.className = "menu";
    m.innerHTML = `<div class="t1">MECHA DINO</div><div class="t2">ARENA</div>
      <div class="rec">ARENA RECORD<b>32 W · 21 L</b>60% · <i>W3</i></div>
      <div class="col"><div class="gbtn y">SANDBOX<small>Island with bots · no player damage</small></div><div class="gbtn o">ARENA<small>Same island · no bots · player damage on</small></div><div class="gbtn y play">PLAY</div></div>
      <div class="bot"><button class="chipb lb" id="lbOpen">LEADERBOARD</button><span class="chipb">CREDITS</span></div>`;
    lbOv.appendChild(m);
    m.querySelector("#lbOpen").onclick = () => { panelOpen = true; buildLbOverlay(); };
    if (panelOpen) lbOv.appendChild(buildPanel());
  }
  if (lb === "C") {
    const vt = document.createElement("div"); vt.className = "vtoggle";
    vt.innerHTML = `<button data-v="island" aria-pressed="${lbView === "island"}">ISLAND BOARD</button><button data-v="menu" aria-pressed="${lbView === "menu"}">MAIN MENU</button>`;
    vt.querySelectorAll("button").forEach(b => b.onclick = () => { lbView = b.dataset.v; panelOpen = false; buildLbOverlay(); });
    lbOv.appendChild(vt);
  }
}
function buildPanel() {
  const st = statsOn().length ? statsOn() : ["WINS"]; if (!st.includes(pStat)) pStat = st[0]; if (!weeklyOn()) pTf = "all";
  const R = rows(pStat, pTf);
  const veil = document.createElement("div"); veil.className = "veil";
  veil.innerHTML = `<div class="lbp" role="dialog" aria-label="Leaderboard">
    <div class="hd"><b>LEADERBOARD</b><button class="x" aria-label="Close">X</button></div>
    <div class="tabs">${st.map(s => `<button data-s="${s}" aria-pressed="${s === pStat}">${STAT_LABEL[s]}</button>`).join("")}</div>
    <div class="tf">${weeklyOn() ? `<button data-t="all" aria-pressed="${pTf === "all"}">ALL-TIME</button><button data-t="week" aria-pressed="${pTf === "week"}">THIS WEEK</button>` : `<button aria-pressed="true">ALL-TIME</button>`}</div>
    <div class="list">${R.list.map((r, i) => `<div class="lbr g${i + 1}"><span class="r">${i + 1}</span><span>${r.name}</span><span class="d">${DINO_NAME[r.dino].toUpperCase()}</span><span class="v">${r.v.toLocaleString("en-US")}</span></div>`).join("")}</div>
    <div class="lbr me"><span class="r" style="color:var(--yellow)">#${R.me.rank}</span><span>YOU · BloxSolid</span><span class="d"></span><span class="v">${R.me.v}</span></div>
  </div>`;
  veil.querySelector(".x").onclick = () => { panelOpen = false; buildLbOverlay(); };
  veil.onclick = e => { if (e.target === veil) { panelOpen = false; buildLbOverlay(); } };
  veil.querySelectorAll("[data-s]").forEach(b => b.onclick = () => { pStat = b.dataset.s; buildLbOverlay(); });
  veil.querySelectorAll("[data-t]").forEach(b => b.onclick = () => { pTf = b.dataset.t; buildLbOverlay(); });
  return veil;
}
function lbInfo() {
  const t = {
    A: "<b class='k'>A · Big board on the island.</b> A 30 × 20 stud screen on posts, 48 studs in front of the island spawn, so you see it every time you spawn (like the big boards in top Roblox games). Top 10; flips to the next stat (and to this week) every 8 s. The bottom row shows your own rank — each player sees their own.",
    B: "<b class='k'>B · LEADERBOARD in the menu.</b> A new LEADERBOARD button next to CREDITS on the main menu opens a full panel: a tab per stat, all-time / this week, top 50 and your rank pinned at the bottom. Easiest to read on a phone. Tap LEADERBOARD above to open it.",
    C: "<b class='k'>C · Both.</b> The island board for show (everyone sees it while walking around) plus the menu panel for the full list and your rank. Use ISLAND BOARD / MAIN MENU in the bottom-left corner to see each.",
  }[lb];
  $("lbInfo").innerHTML = `<p>${t}</p>`;
}
document.querySelectorAll("[data-lb]").forEach(b => b.onclick = () => { lb = b.dataset.lb; lbView = lb === "B" ? "menu" : "island"; panelOpen = false; document.querySelectorAll("[data-lb]").forEach(x => x.setAttribute("aria-pressed", x === b)); L.yawUser = 0; buildLbOverlay(); lbInfo(); updatePicks(); });
let lbT0 = performance.now();
function renderLb(now) {
  const t = Math.max(0, (now - lbT0) / 1000), cam = L.cam;
  drawBoard(t);
  const menu = lb === "B" || (lb === "C" && lbView === "menu");
  if (menu) {
    // main menu backdrop: the player's dino on display (the real menu shows your dino, Prev / Next to change)
    playerDino.yaw = 0.6 + t * 0.25; pose(playerDino);
    const c = playerDino.box.getCenter(new THREE.Vector3()), r = playerDino.hgt * 2.6;
    cam.position.set(c.x - r * 0.25, c.y + r * 0.12, c.z - r); cam.lookAt(c.x - r * 0.25 * (cam.aspect > 2 ? 0.2 : 0), c.y, c.z);
  } else {
    playerDino.yaw = 0.25; pose(playerDino);
    // standing at the spawn behind your T-Rex, looking at the board
    const a = Math.sin(t * 0.15) * 0.12 + L.yawUser, tgt = new THREE.Vector3(0, BY - 1, BOARD_Z), r = 92;
    cam.position.set(tgt.x + Math.sin(a) * r, 24, tgt.z + Math.cos(a) * r); cam.lookAt(tgt);
  }
  L.renderer.render(lScene, cam);
}

// ======================================================================================
// picks
// ======================================================================================
function single(groupSel, attr) { document.querySelectorAll(groupSel).forEach(b => b.onclick = () => { document.querySelectorAll(groupSel).forEach(x => x.setAttribute("aria-pressed", x === b)); afterPick(); }); }
single("[data-tf]"); single("[data-mx]");
document.querySelectorAll("[data-st]").forEach(b => b.onclick = () => { b.setAttribute("aria-pressed", b.getAttribute("aria-pressed") !== "true"); afterPick(); });
function afterPick() { lastPage = ""; if (panelOpen) buildLbOverlay(); updatePicks(); }
function updatePicks() {
  const pressed = sel => { const b = document.querySelector(sel + '[aria-pressed="true"]'); return b ? b.textContent.split("\n")[0].trim() : "—"; };
  const st = statsOn().map(s => ({WINS: "wins", KILLS: "kills", STREAK: "best streak", LEVEL: "dino level"})[s]).join(" + ") || "none";
  const tf = document.querySelector('[data-tf="week"]').getAttribute("aria-pressed") === "true" ? "all-time + weekly" : "all-time only";
  const mx = document.querySelector('[data-mx][aria-pressed="true"]').dataset.mx;
  $("out").value = `podium ${pod} (${sizeMode === "real" ? "real sizes" : "same height"}), boards ${lb}, ranked: ${st}, ${tf}, max-all test: ${{off: "turn off", on: "keep on", later: "decide later"}[mx]}`;
}
$("copy").onclick = () => { const v = $("out").value; const done = () => { $("copy").textContent = "Copied"; setTimeout(() => $("copy").textContent = "Copy picks", 1500); };
  try { navigator.clipboard.writeText(v).then(done, () => { $("out").select(); }); } catch (e) { $("out").select(); } };

// ======================================================================================
let last = performance.now();
function frame(now) {
  const dt = Math.min(0.05, (now - last) / 1000); last = now;
  renderPodium(now, dt); renderLb(now);
  requestAnimationFrame(frame);
}
const fontsReady = (document.fonts && document.fonts.load) ? Promise.all([document.fonts.load(`700 40px Silkscreen`), document.fonts.load(`400 40px Silkscreen`)]).catch(() => {}) : Promise.resolve();
Promise.race([fontsReady, new Promise(r => setTimeout(r, 2500))]).then(() => {
  resizeAll(); buildPodium(); podInfo(); buildLbOverlay(); lbInfo(); updatePicks();
  requestAnimationFrame(frame); window.__ready = true;
});
window.__set = (p, l, v, f) => { if (f) setFrame(f); if (p) document.querySelector(`[data-pod="${p}"]`).onclick(); if (l) document.querySelector(`[data-lb="${l}"]`).onclick(); if (v) { lbView = v; buildLbOverlay(); } };
window.__open = () => { panelOpen = true; buildLbOverlay(); };
