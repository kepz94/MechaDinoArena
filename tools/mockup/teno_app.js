// Tenontosaurus model mockup app. LOOKS = generator exports (tools/teno_generator.py --json), HERRERA = herrera_model.json.
const LOOKS = __LOOKS__;
const HERRERA = __HERRERA__;
const $ = id => document.getElementById(id);
const rad = THREE.MathUtils.degToRad;
const INFO = {
  A: {sub: "sleepy, kind, a bit slow", why: "A big old softie: huge sleepy half-lidded eyes, a chunky orange beak with a little smile, puffy cheeks and a throat dewlap, a round body with a hump over the hips. The giant tail drags low and level, then the tip curls up like a hook.", tail: "Very long and low, the tip curls up."},
  B: {sub: "cranky, armoured, stubborn", why: "A grumpy tank: half-closed eyes under an angry slanted brow, a frowning hooked grey beak, a wide body on pillar legs, bony plates down its sides, and a thick tail wrapped in dark armour rings.", tail: "Thick and stiff, straight back like a battering ram, armour rings."},
  C: {sub: "goofy, curious, bouncy", why: "A happy noodle: enormous round googly eyes with raised brows, a big yellow beak with a grin, a little crest on the head, the neck held up, and a teal back with red stripes. The tail sweeps up in a huge S-curve and hooks down at the end.", tail: "Swept high in a big S-curve, tip hooked down."},
};

// ---------- three ----------
const cv = $("cv");
const renderer = new THREE.WebGLRenderer({canvas: cv, antialias: true, preserveDrawingBuffer: true});
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
const scene = new THREE.Scene();
const SKY = new THREE.Color(0x8fc6e8), LAB = new THREE.Color(0x141a26);
scene.background = SKY; scene.fog = new THREE.Fog(0x8fc6e8, 120, 260);
const cam = new THREE.PerspectiveCamera(32, 16 / 9, 0.1, 600);
scene.add(new THREE.HemisphereLight(0xf2f8ff, 0x7a8a5a, 0.85));
const sun = new THREE.DirectionalLight(0xffffff, 0.75); sun.position.set(30, 40, -10); scene.add(sun);
const rim = new THREE.DirectionalLight(0xffe2b8, 0.35); rim.position.set(-30, 15, 30); scene.add(rim);
const ground = new THREE.Mesh(new THREE.PlaneGeometry(600, 600), new THREE.MeshLambertMaterial({color: 0x6fae4a}));
ground.rotation.x = -Math.PI / 2; scene.add(ground);
const grid = new THREE.GridHelper(600, 150, 0x5c9a3c, 0x5c9a3c); grid.position.y = 0.02; grid.material.opacity = 0.35; grid.material.transparent = true; scene.add(grid);

function cfm(a) { const m = new THREE.Matrix4(); m.set(a[3], a[4], a[5], a[0], a[6], a[7], a[8], a[1], a[9], a[10], a[11], a[2], 0, 0, 0, 1); return m; }
const tmpE = new THREE.Euler();
function rot(p, y, r) { tmpE.set(rad(r), rad(y), rad(p), "ZYX"); return new THREE.Matrix4().makeRotationFromEuler(tmpE); }
const matCache = {};
function mat(hex) { return matCache[hex] || (matCache[hex] = new THREE.MeshLambertMaterial({color: parseInt(hex, 16)})); }

function buildDino(D, scale) {
  const g = new THREE.Group(); scene.add(g);
  const segs = {}, parts = [];
  for (const s of D.segs) {
    const rootInv = cfm(s.root).invert(); segs[s.n] = [];
    for (const p of s.parts) {
      const m = new THREE.Mesh(new THREE.BoxGeometry(p.s[0], p.s[1], p.s[2]), mat(p.c)); m.matrixAutoUpdate = false; g.add(m);
      const info = {mesh: m, local: rootInv.clone().multiply(cfm(p.cf)), size: p.s}; segs[s.n].push(info); parts.push(info);
    }
  }
  const joints = D.joints.map(j => ({n: j.n, p0: j.p0, p1: j.p1, c0: cfm(j.c0), c1inv: cfm(j.c1).invert()}));
  return {D, g, segs, parts, joints, scale, x: 0, z: 0, yaw: 0};
}
const corner = new THREE.Vector3();
function pose(d, angles) {
  const W = {HRP: new THREE.Matrix4().makeRotationY(d.yaw)};
  for (const j of d.joints) { const v = angles[j.n] || [0, 0, 0]; W[j.p1] = W[j.p0].clone().multiply(j.c0).multiply(rot(v[0], v[1], v[2])).multiply(j.c1inv); }
  let minY = Infinity; const box = new THREE.Box3();
  const S = new THREE.Matrix4().makeScale(d.scale, d.scale, d.scale);
  for (const n in d.segs) for (const p of d.segs[n]) {
    const m = S.clone().multiply(W[n]).multiply(p.local); p.mesh.matrix.copy(m);
    for (let i = 0; i < 8; i++) { corner.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(m); minY = Math.min(minY, corner.y); box.expandByPoint(corner); }
  }
  const lift = new THREE.Matrix4().makeTranslation(d.x, -minY, d.z);
  for (const p of d.parts) p.mesh.matrix.premultiply(lift);
  box.translate(new THREE.Vector3(d.x, -minY, d.z)); d.box = box;
}

// ---------- state ----------
let look = "A", view = "three", spin = false, swingT = -1, compare = false;
const dinos = {};
for (const k in LOOKS) { dinos[k] = buildDino(LOOKS[k], 2); dinos[k].g.visible = false; }
const herr = buildDino(HERRERA, 2); herr.g.visible = false;
const HERR_POSE = {RootJoint: [-24, 0, 0], Neck: [6, 0, 0], Head: [16, 0, 0], Jaw: [-3, 0, 0], ArmL: [30, 0, -18], ArmR: [30, 0, 18],
  LegL: [48, 0, -16], LegR: [48, 0, 16], KneeL: [-48, 0, 0], KneeR: [-48, 0, 0], AnkleL: [24, 0, 0], AnkleR: [24, 0, 0],
  Tail1: [26, 0, 0], Tail2: [4, 0, 0], Tail3: [8, 0, 0], Tail4: [14, 0, 0], Tail5: [20, 0, 0]};

function tailSwing(t) { // a demo of the tail attack: wind up one way, whip across, recover (yaw grows toward the tip)
  const o = {};
  let a;
  if (t < 0.35) a = -Math.sin(t / 0.35 * Math.PI / 2) * 0.6;
  else if (t < 0.6) a = -0.6 + Math.sin((t - 0.35) / 0.25 * Math.PI / 2) * 1.6;
  else a = 1.0 * (1 - (t - 0.6) / 0.6);
  for (let i = 1; i <= 5; i++) {
    const lag = Math.max(0, Math.min(1, (t - i * 0.03) / 1));
    o["Tail" + i] = [0, a * (10 + i * 7) * (lag > 0 ? 1 : 0), 0];
  }
  o.RootJoint = [0, -a * 14, a * 3]; o.Neck = [0, a * 12, 0]; o.Head = [0, a * 8, 0];
  o.LegL = [a * 6, 0, 0]; o.LegR = [-a * 6, 0, 0];
  return o;
}

function setLook(k) {
  look = k;
  document.querySelectorAll("[data-look]").forEach(b => b.setAttribute("aria-pressed", b.dataset.look === k));
  const D = LOOKS[k], I = INFO[k];
  $("info").innerHTML = `<h2>${k} · ${D.name}</h2><p class="sub">${I.sub}</p><p>${I.why}</p><p><b>Tail:</b> ${I.tail}</p>
    <div class="sw">${Object.entries(D.roles).map(([r, h]) => `<span title="${r} #${h}" style="background:#${h}"></span>`).join("")}</div>
    <p class="muted">Colour groups: ${Object.keys(D.roles).join(", ")} (skin-ready, 10 groups). ${D.segs.reduce((n, s) => n + s.parts.length, 0)} blocks.</p>`;
}
function setView(v) { view = v; document.querySelectorAll("[data-view]").forEach(b => b.setAttribute("aria-pressed", b.dataset.view === v)); }
document.querySelectorAll("[data-look]").forEach(b => b.onclick = () => setLook(b.dataset.look));
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => setView(b.dataset.view));
$("swing").onclick = () => { swingT = 0; };
$("spin").onclick = e => { spin = !spin; e.currentTarget.setAttribute("aria-pressed", spin); };
$("compare").onclick = e => { compare = !compare; e.currentTarget.setAttribute("aria-pressed", compare); };

function resize() { const w = cv.clientWidth, h = cv.clientHeight; renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); }
window.addEventListener("resize", resize);
let yawUser = 0, drag = null;
cv.addEventListener("pointerdown", e => { drag = e.clientX; cv.setPointerCapture(e.pointerId); });
cv.addEventListener("pointermove", e => { if (drag !== null) { yawUser += (e.clientX - drag) * 0.01; drag = e.clientX; } });
cv.addEventListener("pointerup", () => { drag = null; });

let last = performance.now();
function frame(now) {
  const dt = Math.min(0.05, (now - last) / 1000); last = now;
  for (const k in dinos) dinos[k].g.visible = k === look;
  const d = dinos[look];
  if (spin) yawUser -= dt * 0.4;
  d.yaw = yawUser; d.x = 0; d.z = 0;
  let angles = {};
  if (swingT >= 0) { swingT += dt; angles = tailSwing(swingT); if (swingT > 1.2) swingT = -1; }
  pose(d, angles);
  herr.g.visible = compare;
  if (compare) { herr.yaw = yawUser; herr.x = 0; herr.z = -26; pose(herr, HERR_POSE); }
  const b = d.box.clone(); if (compare) b.union(herr.box);
  const c = b.getCenter(new THREE.Vector3()), size = b.getSize(new THREE.Vector3());
  // the dino faces -Z (HRP space = (z, y, -x)); length runs along Z
  const span = Math.max(size.z, size.x * (compare ? 1 : 0.6), size.y * 1.8);
  const r = span * 0.5 / Math.tan(rad(cam.fov / 2)) / Math.min(1.6, cam.aspect) * 1.25;
  if (view === "side") cam.position.set(c.x + r, c.y + r * 0.06, c.z);
  else if (view === "front") cam.position.set(c.x + 0.001, c.y + r * 0.1, c.z - r * 0.7);
  else if (view === "top") cam.position.set(c.x + 0.01, c.y + r, c.z);
  else cam.position.set(c.x + r * 0.78, c.y + r * 0.3, c.z - r * 0.55);
  cam.lookAt(c.x, c.y * 0.8, c.z);
  renderer.render(scene, cam);
  requestAnimationFrame(frame);
}
resize(); setLook("A"); setView("three");
requestAnimationFrame(frame);
window.__ready = true;
window.__swing = t => { swingT = t; };
window.__state = () => ({swingT, look, view});
