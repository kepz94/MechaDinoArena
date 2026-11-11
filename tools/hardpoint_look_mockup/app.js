// Hardpoint point-look mockup v0.1 app (build.py inlines three.js r128, the island grid and the dino models before this).
(function () {
"use strict";
const $ = id => document.getElementById(id);
const DEG = Math.PI / 180, RADIUS = 45;
const screenEl = $("screen"), canvas = $("gl");
const renderer = new THREE.WebGLRenderer({canvas, antialias: true, preserveDrawingBuffer: true});
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
const scene = new THREE.Scene();
const SKY = 0x8cc3e6; scene.background = new THREE.Color(SKY); scene.fog = new THREE.Fog(SKY, 500, 1500);
const camera = new THREE.PerspectiveCamera(70, 16 / 9, 0.5, 3000);
scene.add(new THREE.HemisphereLight(0xdfefff, 0x5a7a3a, 0.75));
const sun = new THREE.DirectionalLight(0xfff1d8, 0.7); sun.position.set(300, 500, 200); scene.add(sun);

// ---------- the island around Centre Meadow (point 1 of layout B), from the Studio grid ----------
const A = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
const N = 72, R = 1080, CELL = 30, PX = -100, PZ = -40; // the point's world spot; the scene is centred on it
const G = GRID.trim().split("\n").map(r => { const a = []; for (let i = 0; i < N; i++) a.push([r[2 * i], A.indexOf(r[2 * i + 1]) * 5 - 50]); return a; });
function cellAtWorld(x, z) { const i = Math.floor((x + R) / CELL), j = Math.floor((z + R) / CELL); return (i < 0 || j < 0 || i >= N || j >= N) ? ["w", -8] : G[j][i]; }
// the point's floor is levelled (the build places it on one height); outside 75 studs the real cell heights are kept
const FLAT = 75, H0 = cellAtWorld(PX, PZ)[1];
const groundY = (x, z) => { if (Math.hypot(x, z) < FLAT) return H0; const [t, h] = cellAtWorld(x + PX, z + PZ); return "wv".includes(t) ? Math.min(h, -1) : h; };
function rng(seed) { return () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
const rand = rng(11);
function studTex() {
  const c = document.createElement("canvas"); c.width = c.height = 256; const x = c.getContext("2d");
  x.fillStyle = "#fff"; x.fillRect(0, 0, 256, 256);
  for (let i = 0; i < 16; i++) for (let j = 0; j < 16; j++) { const cx = i * 16 + 8, cy = j * 16 + 8;
    x.fillStyle = "rgba(0,0,0,.10)"; x.beginPath(); x.arc(cx + 1, cy + 1, 4.6, 0, 7); x.fill();
    x.fillStyle = "rgba(255,255,255,.55)"; x.beginPath(); x.arc(cx - .6, cy - .6, 4.2, 0, 7); x.fill(); }
  x.strokeStyle = "rgba(0,0,0,.08)"; x.lineWidth = 2; x.strokeRect(1, 1, 254, 254);
  const t = new THREE.CanvasTexture(c); t.anisotropy = 4; return t;
}
const STUD = studTex();
// instanced boxes: one InstancedMesh per material
function instanced(list, mat) {
  const m = new THREE.InstancedMesh(new THREE.BoxGeometry(1, 1, 1), mat, list.length), o = new THREE.Object3D(), col = new THREE.Color();
  list.forEach((b, i) => { o.position.set(b.x, b.y, b.z); o.rotation.set(0, b.ry || 0, b.rz || 0); o.scale.set(b.w, b.h, b.d); o.updateMatrix(); m.setMatrixAt(i, o.matrix); col.setHex(b.c); m.setColorAt(i, col); });
  m.instanceMatrix.needsUpdate = true; if (m.instanceColor) m.instanceColor.needsUpdate = true; scene.add(m); return m;
}
const TCOL = {g: 0x4f9a3d, m: 0x86b44f, r: 0x8a8f98, k: 0x9aa0aa, t: 0xc9a86a, o: 0x7d828b, s: 0xd9c58f, w: 0x2b5a78, v: 0x3b7ea6};
(function terrain() {
  const cells = [], span = 660;
  for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) {
    const wx = -R + (i + .5) * CELL, wz = -R + (j + .5) * CELL, x = wx - PX, z = wz - PZ;
    if (Math.abs(x) > span || Math.abs(z) > span) continue;
    const [t, h0] = G[j][i], k = 0.92 + rand() * 0.12, top = Math.hypot(x, z) < FLAT ? H0 : h0;
    const c = new THREE.Color(TCOL[t] || 0xff00ff).multiplyScalar(k).getHex();
    cells.push({x, y: (top - 60) / 2, z, w: CELL, h: top + 60, d: CELL, c});
  }
  instanced(cells, new THREE.MeshLambertMaterial({map: STUD}));
  const water = new THREE.Mesh(new THREE.PlaneGeometry(2600, 2600), new THREE.MeshLambertMaterial({color: 0x3f8fc0, transparent: true, opacity: .72}));
  water.rotation.x = -Math.PI / 2; water.position.y = -0.6; scene.add(water);
  // trees on grass / meadow, away from the point
  const trunks = [], leaves = [];
  for (let n = 0; n < 900; n++) {
    const x = (rand() * 2 - 1) * span, z = (rand() * 2 - 1) * span, d = Math.hypot(x, z);
    if (d < RADIUS + 28) continue;
    const [t, h] = cellAtWorld(x + PX, z + PZ); if (!"gm".includes(t)) continue;
    if (rand() < (t === "m" ? .75 : .45)) continue;
    const y0 = h, palm = rand() < .55;
    if (palm) { // curved palm: 5 trunk blocks leaning one way, a fan of leaves
      const ry = rand() * 6.28, lean = .1 + rand() * .12, hh = 16 + rand() * 10; let px = x, pz = z, py = y0;
      for (let s = 0; s < 5; s++) { const seg = hh / 5; py += seg; px += Math.sin(ry) * lean * seg * (s + 1) * .5; pz += Math.cos(ry) * lean * seg * (s + 1) * .5;
        trunks.push({x: px, y: py - seg / 2, z: pz, w: 1.6, h: seg + .2, d: 1.6, c: s % 2 ? 0x8a6a45 : 0x75583a, ry}); }
      for (let l = 0; l < 6; l++) { const a = l / 6 * 6.28 + ry; leaves.push({x: px + Math.sin(a) * 4.2, y: py - .6, z: pz + Math.cos(a) * 4.2, w: 2.4, h: .6, d: 9, c: l % 2 ? 0x3f8f3a : 0x4aa045, ry: a, rz: .25}); }
    } else { // broadleaf block tree
      const hh = 10 + rand() * 8, s = 9 + rand() * 6;
      trunks.push({x, y: y0 + hh / 2, z, w: 2.2, h: hh, d: 2.2, c: 0x6b4f33});
      leaves.push({x, y: y0 + hh + 2, z, w: s, h: 5, d: s, c: 0x3d8a37}); leaves.push({x, y: y0 + hh + 6, z, w: s * .65, h: 4, d: s * .65, c: 0x46983f});
    }
  }
  instanced(trunks, new THREE.MeshLambertMaterial({map: STUD})); instanced(leaves, new THREE.MeshLambertMaterial({map: STUD}));
})();

// ---------- dinos (the game's own model data) ----------
function cfm(a) { const m = new THREE.Matrix4(); m.set(a[3], a[4], a[5], a[0], a[6], a[7], a[8], a[1], a[9], a[10], a[11], a[2], 0, 0, 0, 1); return m; }
function buildDino(D, scale) {
  const g = new THREE.Group(); scene.add(g); const cache = {};
  const mat = hex => cache[hex] || (cache[hex] = new THREE.MeshLambertMaterial({color: parseInt(hex, 16)}));
  const W = {HRP: new THREE.Matrix4()};
  for (const j of D.joints) W[j.p1] = W[j.p0].clone().multiply(cfm(j.c0)).multiply(cfm(j.c1).invert());
  for (const s of D.segs) { const rootInv = cfm(s.root).invert();
    for (const p of s.parts) { if (p.t && p.t >= .99) continue; const m = new THREE.Mesh(new THREE.BoxGeometry(p.s[0], p.s[1], p.s[2]), mat(p.c));
      m.matrixAutoUpdate = false; m.matrix.copy(W[s.n]).multiply(rootInv).multiply(cfm(p.cf)); g.add(m); } }
  const inner = g; const outer = new THREE.Group(); scene.remove(g); outer.add(inner); scene.add(outer);
  inner.scale.setScalar(scale); outer.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(inner); inner.position.y = -box.min.y; // feet on the ground
  const size = box.getSize(new THREE.Vector3());
  return {g: outer, top: size.y, len: Math.max(size.x, size.z), wid: Math.min(size.x, size.z)};
}
const me = buildDino(RAPTOR, 2), mate = buildDino(RAPTOR, 2), foe = buildDino(TREX, 1.63);
function place(d, x, z, yaw) { d.g.position.set(x, groundY(x, z), z); d.g.rotation.y = yaw; d.g.visible = true; }

// ---------- the point ----------
const COL = {N: 0xffffff, you: 0x5aa0ff, foe: 0xe0284a, C: 0xffc832, L: 0xb8bec8};
const point = new THREE.Group(); scene.add(point);
const SEG = 72, band = [], wallMats = [];
const add = (m) => (point.add(m), m);
// A + C: the animated border band on the ground (CoD's animated border, as studded neon blocks)
for (let i = 0; i < SEG; i++) {
  const a = (i + .5) / SEG * Math.PI * 2, x = Math.cos(a) * RADIUS, z = Math.sin(a) * RADIUS;
  const m = add(new THREE.Mesh(new THREE.BoxGeometry(2.6, .7, 2 * Math.PI * RADIUS / SEG * .86), new THREE.MeshBasicMaterial({color: 0xffffff})));
  m.position.set(x, groundY(x, z) + .45, z); m.rotation.y = -a; band.push({m, a});
}
// low glowing wall: vertical gradient, scrolling stripes
function wallTex() { const c = document.createElement("canvas"); c.width = 64; c.height = 128; const x = c.getContext("2d");
  const gr = x.createLinearGradient(0, 128, 0, 0); gr.addColorStop(0, "rgba(255,255,255,.75)"); gr.addColorStop(.35, "rgba(255,255,255,.28)"); gr.addColorStop(1, "rgba(255,255,255,0)");
  x.fillStyle = gr; x.fillRect(0, 0, 64, 128); x.globalCompositeOperation = "destination-out"; x.fillStyle = "rgba(0,0,0,.35)"; for (let i = 0; i < 64; i += 16) x.fillRect(i, 0, 6, 128);
  const t = new THREE.CanvasTexture(c); t.wrapS = THREE.RepeatWrapping; t.repeat.set(24, 1); return t; }
const WT = wallTex();
const wall = add(new THREE.Mesh(new THREE.CylinderGeometry(RADIUS, RADIUS, 7, 96, 1, true), new THREE.MeshBasicMaterial({map: WT, transparent: true, side: THREE.DoubleSide, depthWrite: false, blending: THREE.AdditiveBlending})));
wall.position.y = groundY(0, 0) + 3.6; wallMats.push(wall.material);
const floor = add(new THREE.Mesh(new THREE.CircleGeometry(RADIUS, 64), new THREE.MeshBasicMaterial({color: 0xffffff, transparent: true, opacity: .10, depthWrite: false})));
floor.rotation.x = -Math.PI / 2; floor.position.y = groundY(0, 0) + .35;
// B: light column you can see across the island + a pulse ring
function colTex() { const c = document.createElement("canvas"); c.width = 8; c.height = 256; const x = c.getContext("2d"); const gr = x.createLinearGradient(0, 256, 0, 0);
  gr.addColorStop(0, "rgba(255,255,255,.95)"); gr.addColorStop(.25, "rgba(255,255,255,.45)"); gr.addColorStop(1, "rgba(255,255,255,0)"); x.fillStyle = gr; x.fillRect(0, 0, 8, 256); return new THREE.CanvasTexture(c); }
const column = add(new THREE.Mesh(new THREE.CylinderGeometry(5, 7, 320, 24, 1, true), new THREE.MeshBasicMaterial({map: colTex(), transparent: true, side: THREE.DoubleSide, depthWrite: false, blending: THREE.AdditiveBlending})));
column.position.y = groundY(0, 0) + 160;
const pulse = add(new THREE.Mesh(new THREE.RingGeometry(RADIUS - 1.2, RADIUS + 1.2, 96), new THREE.MeshBasicMaterial({color: 0xffffff, transparent: true, side: THREE.DoubleSide, depthWrite: false, blending: THREE.AdditiveBlending})));
pulse.rotation.x = -Math.PI / 2; pulse.position.y = groundY(0, 0) + .6;
// C: mecha pylons (studded metal, hazard band, lamp) joined by energy beams
const PYL = 10, pylons = [], beams = [];
const metal = new THREE.MeshLambertMaterial({color: 0x3a4250, map: STUD}), dark = new THREE.MeshLambertMaterial({color: 0x232a33, map: STUD});
function hazardTex() { const c = document.createElement("canvas"); c.width = c.height = 64; const x = c.getContext("2d"); x.fillStyle = "#f2c230"; x.fillRect(0, 0, 64, 64); x.fillStyle = "#1b1b1b";
  for (let i = -64; i < 128; i += 22) { x.beginPath(); x.moveTo(i, 0); x.lineTo(i + 11, 0); x.lineTo(i + 11 - 64, 64); x.lineTo(i - 64, 64); x.fill(); } return new THREE.CanvasTexture(c); }
const hazard = new THREE.MeshLambertMaterial({map: hazardTex()});
for (let i = 0; i < PYL; i++) {
  const a = i / PYL * Math.PI * 2, x = Math.cos(a) * RADIUS, z = Math.sin(a) * RADIUS, y = groundY(x, z), g = new THREE.Group(); g.position.set(x, y, z); g.rotation.y = -a; add(g);
  const part = (w, h, d, m, py) => { const b = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m); b.position.y = py; g.add(b); return b; };
  part(4.4, 1.2, 4.4, dark, .6); part(3, 7.5, 3, metal, 4.9); part(3.3, 1.1, 3.3, hazard, 3.2); part(3.6, 1, 3.6, dark, 9.1);
  const lamp = part(2.2, 1.6, 2.2, new THREE.MeshBasicMaterial({color: 0xffffff}), 10.4);
  pylons.push({g, lamp, top: new THREE.Vector3(x, y + 8.4, z), low: new THREE.Vector3(x, y + 3.2, z)});
}
for (let i = 0; i < PYL; i++) for (const lvl of ["top", "low"]) {
  const p = pylons[i][lvl], q = pylons[(i + 1) % PYL][lvl], len = p.distanceTo(q);
  const b = add(new THREE.Mesh(new THREE.BoxGeometry(.45, .45, len), new THREE.MeshBasicMaterial({color: 0xffffff, transparent: true, opacity: .9, blending: THREE.AdditiveBlending, depthWrite: false})));
  b.position.copy(p).add(q).multiplyScalar(.5); b.lookAt(q); beams.push({b, lvl, ph: rand() * 6});
}
const LOOKS = {
  A: {title: "A · Neon border", sub: "Call of Duty’s border, as studded neon", band: true, wall: true, column: false, pylons: false,
      info: ["The closest to Call of Duty: a moving border on the ground and a low glow wall, nothing else.", "Clean and cheap on phones (about 75 parts).", "From far away you only see the marker, not the point itself."]},
  B: {title: "B · Border + beacon", sub: "A + a light column seen across the island", band: true, wall: true, column: true, pylons: false,
      info: ["A’s border plus a tall light column in the point’s colour.", "Our island is much bigger than a Call of Duty map: you can see where the point is, and who holds it, from the other side.", "The column is the most visible thing on the island; it can hide the sky on the summit."]},
  C: {title: "C · Mecha pylons", sub: "pylons + energy beams + the border", band: true, wall: false, column: false, pylons: true, rec: true,
      info: ["Ten studded mecha pylons on the border with two energy beams between them, lamps in the point’s colour, plus A’s moving border on the ground.", "Fits the mecha look of the parts; the edge is easy to read at a glance and from the side.", "Dinos run through the beams (they don’t block anything). About 110 parts."]},
};
let look = "C";
function applyLook() {
  const L = LOOKS[look];
  band.forEach(b => b.m.visible = L.band); wall.visible = L.wall; floor.visible = true; column.visible = L.column; pulse.visible = L.column;
  pylons.forEach(p => p.g.visible = L.pylons); beams.forEach(b => b.b.visible = L.pylons);
}

// ---------- states ----------
const STATES = {
  N:   {title: "Open", sub: "nobody on it", lab: "CAPTURE", status: "POINT OPEN"},
  you: {title: "Yours", sub: "your team holds it", lab: "DEFEND", status: "SECURED · +1 / s"},
  foe: {title: "Enemy’s", sub: "the enemy holds it", lab: "CAPTURE", status: "ENEMY HAS THE POINT"},
  C:   {title: "Contested", sub: "both teams on it", lab: "CONTESTED", status: "CONTESTED"},
  L:   {title: "Next (locked)", sub: "opens in 0:07", lab: "LOCKED 0:07", status: "NEXT POINT IN 0:07"},
};
let state = "you";
// ---------- views ----------
const VIEWS = {
  player: {title: "Player view", sub: "running at the point, 80 studs out", me: [8, 92, 0]},
  on:     {title: "On the point", sub: "standing in it", me: [-6, 14, 0.15]},
  far:    {title: "From far away", sub: "320 studs out", me: [30, 330, 0.05]},
  top:    {title: "From above", sub: "the whole point"},
};
let view = "player";
const cam = {yaw: 0, pitch: -10 * DEG, zoom: 1};
function setView(v) { view = v; cam.yaw = VIEWS[v].me ? VIEWS[v].me[2] : 0; cam.pitch = v === "far" ? -6 * DEG : -10 * DEG; cam.zoom = 1; }
function placeActors() {
  const V = VIEWS[view];
  if (V.me) place(me, V.me[0], V.me[1], cam.yaw); else place(me, 8, 92, 0);
  mate.g.visible = foe.g.visible = false;
  if (state === "you" || state === "C") place(mate, 18, -6, 0.6);
  if (state === "foe" || state === "C") place(foe, -14, -20, 2.4);
}
// ShoulderCam framing (src/character/ShoulderCam): distance = CameraStartZoom (raptor 16) x RaptorScale 2, focus 0.75 x top,
// side = max(0.6 x width, 0.9 x top + 1), height 0.35 x top; over the right shoulder.
function placeCamera() {
  if (view === "top") { camera.position.set(0, 230 / cam.zoom, 0.01); camera.lookAt(0, 0, 0); return; }
  const top = me.top, focus = me.g.position.clone().add(new THREE.Vector3(0, .75 * top, 0));
  const look = new THREE.Vector3(-Math.sin(cam.yaw) * Math.cos(cam.pitch), Math.sin(cam.pitch), -Math.cos(cam.yaw) * Math.cos(cam.pitch));
  const right = new THREE.Vector3(Math.cos(cam.yaw), 0, -Math.sin(cam.yaw));
  const side = Math.max(.6 * me.wid, .9 * top + 1) * .55, dist = 32 * cam.zoom;
  camera.position.copy(focus).addScaledVector(right, side).add(new THREE.Vector3(0, .35 * top, 0)).addScaledVector(look, -dist);
  camera.lookAt(camera.position.clone().add(look));
}

// ---------- HUD overlays ----------
const wp = $("wp"), tags = $("tags");
const tagEls = {};
function tagFor(key, cls, text) { if (!tagEls[key]) { const d = document.createElement("div"); d.className = "hud tag " + cls; d.textContent = text; tags.appendChild(d); tagEls[key] = d; } return tagEls[key]; }
function project(v) { const p = v.clone().project(camera); return {x: (p.x + 1) / 2, y: (1 - p.y) / 2, behind: p.z > 1}; }
function hud(t) {
  const S = STATES[state], rel = state;
  wp.className = "hud wp " + rel; $("wpLab").textContent = S.lab; $("wpN").textContent = "1";
  const st = $("hStatus"); st.className = "hud status " + rel; st.textContent = S.status;
  $("hPt").textContent = state === "L" ? "P5 · 0:07" : "P1 · 0:41";
  const center = new THREE.Vector3(0, groundY(0, 0) + 34, 0), p = project(center);
  const d = Math.round(Math.hypot(me.g.position.x, me.g.position.z));
  $("wpDist").textContent = state === "L" ? (d <= RADIUS ? "here" : d + " studs") : d <= RADIUS ? "ON POINT" : d + " studs";
  let x = p.x, y = p.y, edge = false;
  if (p.behind) { x = 1 - x; y = 0.9; edge = true; }
  if (x < .04 || x > .96 || y < .12 || y > .94) edge = true;
  x = Math.min(.96, Math.max(.04, x)); y = Math.min(.94, Math.max(.16, y));
  wp.classList.toggle("edge", edge); wp.style.left = (x * 100) + "%"; wp.style.top = (y * 100) + "%";
  [[mate, "mate", "you", "TEAMMATE"], [foe, "foe", "foe", "ENEMY"]].forEach(([d, k, cls, txt]) => {
    const el = tagFor(k, cls, txt); if (!d.g.visible || view === "top") { el.style.display = "none"; return; }
    const q = project(d.g.position.clone().add(new THREE.Vector3(0, d.top + 3, 0))); el.style.display = q.behind ? "none" : ""; el.style.left = (q.x * 100) + "%"; el.style.top = (q.y * 100) + "%"; });
}

// ---------- animation ----------
const tmp = new THREE.Color();
function colourAt(t) { let c = COL[state]; if (state === "C" && Math.floor(t * 4) % 2) c = 0xffffff; return c; }
function animate(t) {
  const c = colourAt(t), dashed = state === "L";
  band.forEach((b, i) => { const wave = .55 + .45 * Math.max(0, Math.sin(b.a * 9 - t * 5)); tmp.setHex(c).multiplyScalar(dashed ? .6 : wave); b.m.material.color.copy(tmp); b.m.visible = LOOKS[look].band && (!dashed || i % 3 !== 0); });
  WT.offset.x = -t * .25; wall.material.color.setHex(c); wall.material.opacity = 1; wall.visible = LOOKS[look].wall && !dashed;
  floor.material.color.setHex(c); floor.material.opacity = dashed ? .05 : .11;
  column.material.color.setHex(c); column.visible = LOOKS[look].column && !dashed;
  const ph = (t % 2) / 2; pulse.scale.setScalar(1 + ph * .5); pulse.material.opacity = (1 - ph) * .7; pulse.material.color.setHex(c); pulse.visible = LOOKS[look].column && !dashed;
  pylons.forEach((p, i) => { p.lamp.material.color.setHex(c).multiplyScalar(dashed ? .4 : .75 + .25 * Math.sin(t * 6 + i)); });
  beams.forEach(b => { b.b.material.color.setHex(c); b.b.material.opacity = dashed ? 0 : (b.lvl === "top" ? .85 : .55) * (.75 + .25 * Math.sin(t * 13 + b.ph)); b.b.visible = LOOKS[look].pylons && !dashed; });
}

// ---------- input: drag to look, wheel / pinch / buttons to zoom ----------
const ptrs = new Map(); let pinch0 = 0, zoom0 = 1;
canvas.addEventListener("pointerdown", e => { canvas.setPointerCapture(e.pointerId); ptrs.set(e.pointerId, {x: e.clientX, y: e.clientY}); if (ptrs.size === 2) { const [a, b] = [...ptrs.values()]; pinch0 = Math.hypot(a.x - b.x, a.y - b.y); zoom0 = cam.zoom; } });
canvas.addEventListener("pointermove", e => { const p = ptrs.get(e.pointerId); if (!p) return;
  if (ptrs.size === 2) { p.x = e.clientX; p.y = e.clientY; const [a, b] = [...ptrs.values()]; const d = Math.hypot(a.x - b.x, a.y - b.y); if (pinch0) cam.zoom = Math.min(3, Math.max(.4, zoom0 * pinch0 / d)); return; }
  const dx = e.clientX - p.x, dy = e.clientY - p.y; p.x = e.clientX; p.y = e.clientY; cam.yaw -= dx * .006; cam.pitch = Math.max(-75 * DEG, Math.min(25 * DEG, cam.pitch - dy * .005)); });
const up = e => { ptrs.delete(e.pointerId); pinch0 = 0; }; canvas.addEventListener("pointerup", up); canvas.addEventListener("pointercancel", up);
canvas.addEventListener("wheel", e => { e.preventDefault(); cam.zoom = Math.min(3, Math.max(.4, cam.zoom * (e.deltaY > 0 ? 1.1 : 1 / 1.1))); }, {passive: false});
$("zIn").onclick = () => cam.zoom = Math.max(.4, cam.zoom / 1.2); $("zOut").onclick = () => cam.zoom = Math.min(3, cam.zoom * 1.2);

// ---------- tabs ----------
function tabs(id, items, cur, onPick) {
  const el = $(id); el.innerHTML = "";
  Object.entries(items).forEach(([k, v]) => { const b = document.createElement("button"); b.className = "tab" + (v.rec ? " rec" : ""); b.setAttribute("aria-pressed", k === cur);
    b.innerHTML = `${v.title}<small>${v.sub || ""}</small>`; b.onclick = () => { el.querySelectorAll(".tab").forEach(x => x.setAttribute("aria-pressed", x === b)); onPick(k); }; el.appendChild(b); });
}
let dev = "pc";
function resize() { const w = screenEl.clientWidth, h = screenEl.clientHeight; renderer.setSize(w, h, false); camera.aspect = w / h; camera.updateProjectionMatrix(); }
tabs("lookTabs", LOOKS, look, k => { look = k; applyLook(); });
tabs("stateTabs", STATES, state, k => { state = k; });
tabs("viewTabs", VIEWS, view, k => setView(k));
tabs("devTabs", {pc: {title: "PC", sub: "16:9"}, phone: {title: "Phone", sub: "19.5:9"}}, dev, k => { dev = k; screenEl.classList.toggle("phone", k === "phone"); resize(); });
$("looksInfo").innerHTML = Object.entries(LOOKS).map(([k, L]) => `<div class="card"><h2>${L.title}</h2><ul>${L.info.map(s => `<li>${s}</li>`).join("")}</ul></div>`).join("");
window.addEventListener("resize", resize); resize(); applyLook(); setView("player");
const t0 = performance.now();
function frame(now) { const t = (now - t0) / 1000; placeActors(); placeCamera(); animate(t); hud(t); renderer.render(scene, camera); requestAnimationFrame(frame); }
requestAnimationFrame(frame);
window.__mock = {set: (o) => { if (o.look) { look = o.look; applyLook(); } if (o.state) state = o.state; if (o.view) setView(o.view); if (o.dev) { dev = o.dev; screenEl.classList.toggle("phone", o.dev === "phone"); resize(); } }};
})();
