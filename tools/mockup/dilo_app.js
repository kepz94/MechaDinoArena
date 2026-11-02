// Dilo model mockup app v0.5 (side by side with the troodon). LOOKS = generator exports (tools/dilo_generator.py --json); RAPTOR / TREX = model_json.py exports.
const LOOKS = __LOOKS__;
const RAPTOR = __RAPTOR__;
const TREX = __TREX__;
const TROODON = __TROODON__; // TroodonModelData 1.0 (model_json.py export)
const $ = id => document.getElementById(id);
const rad = THREE.MathUtils.degToRad;
const INFO = {
  A: {why: "Slender, with a long S-shaped neck held high. The frill is a solid rounded hood around the head, like a spitting cobra, with two dark eye-spots and a dark rim. Tall, thin, arched twin crests run along the snout, and a long whip tail balances it.", pose: "Tall and alert, head high above the hood."},
  B: {why: "Stocky and upright with a bigger head. The frill is a full round sail like a frilled lizard: teal membrane, pale spines poking past the edge, dark eye-spots. A tall notched mohawk of double crests, and a thick tail.", pose: "Upright, chest out, sail flared."},
  D: {why: "The Cobra Hood made thicker (body, neck, tail, legs and arms 35% thicker, head 18% bigger; long S-neck held high, the split hood around the head, tall thin twin crests, a long whip tail) with the frill itself red and yellow: rings out from the neck, red, yellow, red, then the dark rim, like the Quill Stalker's banded quills. The throat sac is yellow; everything else stays as A.", pose: "Tall and alert, head high above the hood."},
  C: {why: "Low and horizontal like a sprinter, neck stretched forward. The frill is a ruff of long banded red-and-white quills, like a lionfish. Short crests sweep back like horns, and the long tail is held level.", pose: "Low, neck out, quills up."},
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
      const info = {mesh: m, local: rootInv.clone().multiply(cfm(p.cf)), size: p.s, name: p.n}; segs[s.n].push(info); parts.push(info);
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
  if (d.D.roles) for (const p of d.parts) {
    const isF = p.name.includes("_frill"), isFold = p.name.includes("_fold");
    if (isF || isFold) p.mesh.visible = d.frill === undefined ? (isF ? frillOpen : !frillOpen) : (isF ? d.frill : !d.frill);
  }
  const lift = new THREE.Matrix4().makeTranslation(d.x, -minY, d.z);
  for (const p of d.parts) p.mesh.matrix.premultiply(lift);
  box.translate(new THREE.Vector3(d.x, -minY, d.z)); d.box = box;
}

// ---------- state ----------
let look = "A", view = "three", spin = false, swingT = -1, compare = false, frillOpen = true, vsTroo = false;
const dinos = {};
for (const k in LOOKS) { dinos[k] = buildDino(LOOKS[k], 2); dinos[k].g.visible = false; }
const herr = buildDino(TREX, 1); herr.g.visible = false;
const rap = buildDino(RAPTOR, 2); rap.g.visible = false;
const troo = buildDino(TROODON, 2); troo.g.visible = false;
const HERR_POSE = {RootJoint: [-24, 0, 0], Neck: [6, 0, 0], Head: [16, 0, 0], Jaw: [-3, 0, 0], ArmL: [30, 0, -18], ArmR: [30, 0, 18],
  LegL: [48, 0, -16], LegR: [48, 0, 16], KneeL: [-48, 0, 0], KneeR: [-48, 0, 0], AnkleL: [24, 0, 0], AnkleR: [24, 0, 0],
  Tail1: [26, 0, 0], Tail2: [4, 0, 0], Tail3: [8, 0, 0], Tail4: [14, 0, 0], Tail5: [20, 0, 0]};

function runPose(t) { // preview spit: rear back with the frill flaring, lunge forward with the jaw open, recover
  const u = t / 1.3;
  let k;
  if (u < 0.4) k = -Math.sin(u / 0.4 * Math.PI / 2);
  else if (u < 0.55) k = -1 + 2 * Math.sin((u - 0.4) / 0.15 * Math.PI / 2);
  else k = 1 - (u - 0.55) / 0.45;
  const jaw = u > 0.4 && u < 0.85 ? 22 : 4;
  return {RootJoint: [-k * 6, 0, 0], Neck: [-k * 14, 0, 0], Head: [-k * 10, 0, 0], Jaw: [jaw, 0, 0], ArmL: [k * 10, 0, 0], ArmR: [k * 10, 0, 0],
    LegL: [k * 8, 0, 0], LegR: [-k * 4, 0, 0], KneeL: [-Math.abs(k) * 10, 0, 0], KneeR: [-Math.abs(k) * 10, 0, 0], Tail1: [k * 4, 0, 0], Tail2: [k * 3, 0, 0]};
}

function setLook(k) {
  look = k;
  document.querySelectorAll("[data-look]").forEach(b => b.setAttribute("aria-pressed", b.dataset.look === k));
  const D = LOOKS[k], I = INFO[k];
  $("info").innerHTML = `<h2>${k} · ${D.name}</h2><p>${I.why}</p><p><b>Pose:</b> ${I.pose}</p><p class="muted">Length ${D.stats.length} studs at scale 1 (~${Math.round(D.stats.length * 2)} in game), standing height ${D.stats.height} (~${Math.round(D.stats.height * 2)}).</p>
    <div class="sw">${Object.entries(D.roles).map(([r, h]) => `<span title="${r} #${h}" style="background:#${h}"></span>`).join("")}</div>
    <p class="muted">Colour groups: ${Object.keys(D.roles).join(", ")} (skin-ready, 10 groups). ${D.segs.reduce((n, s) => n + s.parts.length, 0)} blocks.</p>`;
}
function setView(v) { view = v; document.querySelectorAll("[data-view]").forEach(b => b.setAttribute("aria-pressed", b.dataset.view === v)); }
document.querySelectorAll("[data-look]").forEach(b => b.onclick = () => setLook(b.dataset.look));
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => setView(b.dataset.view));
$("run").onclick = () => { swingT = 0; };
$("frill").onclick = e => { frillOpen = !frillOpen; e.currentTarget.setAttribute("aria-pressed", frillOpen); e.currentTarget.textContent = frillOpen ? "Frill open" : "Frill folded"; };
$("spin").onclick = e => { spin = !spin; e.currentTarget.setAttribute("aria-pressed", spin); };
$("compare").onclick = e => { compare = !compare; e.currentTarget.setAttribute("aria-pressed", compare); if (compare) { vsTroo = false; $("troo").setAttribute("aria-pressed", false); } };
$("troo").onclick = e => { vsTroo = !vsTroo; e.currentTarget.setAttribute("aria-pressed", vsTroo); if (vsTroo) { compare = false; $("compare").setAttribute("aria-pressed", false); } };

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
  dinos[look].frill = swingT >= 0 && swingT < 1.2 ? true : undefined;
  if (swingT >= 0) { swingT += dt; angles = runPose(swingT); if (swingT > 1.3) swingT = -1; }
  pose(d, angles);
  herr.g.visible = compare; rap.g.visible = compare;
  if (compare) {
    // side by side across the screen: the offset is perpendicular to the camera's view direction (flat), 26 studs apart
    const vd = {three: [0.78, -0.55], side: [1, 0], front: [0, -0.7], top: [0, 1]}[view];
    const vl = Math.hypot(vd[0], vd[1]), ox = -vd[1] / vl * 34, oz = vd[0] / vl * 34;
    herr.yaw = yawUser; herr.x = -ox; herr.z = -oz; pose(herr, {});
    rap.yaw = yawUser; rap.x = ox; rap.z = oz; pose(rap, {});
  }
  troo.g.visible = vsTroo;
  if (vsTroo) { // the troodon right beside it, 12 studs apart across the screen
    const vd = {three: [0.78, -0.55], side: [1, 0], front: [0, -0.7], top: [0, 1]}[view];
    const vl = Math.hypot(vd[0], vd[1]);
    const sep = view === "side" ? 15 : 9;
    d.x = vd[1] / vl * sep; d.z = -vd[0] / vl * sep; pose(d, angles);
    troo.yaw = yawUser; troo.x = -d.x; troo.z = -d.z; pose(troo, {});
  }
  const b = d.box.clone(); if (compare) { b.union(herr.box); b.union(rap.box); } if (vsTroo) b.union(troo.box);
  const c = b.getCenter(new THREE.Vector3()), size = b.getSize(new THREE.Vector3());
  // the dino faces -Z (HRP space = (z, y, -x)); length runs along Z
  const span = Math.max(size.z, size.x * (compare || vsTroo ? 1 : 0.6), size.y * 1.8);
  const r = span * 0.5 / Math.tan(rad(cam.fov / 2)) / Math.min(1.6, cam.aspect) * 1.25;
  if (view === "side") cam.position.set(c.x + r, c.y + r * 0.06, c.z);
  else if (view === "front") cam.position.set(c.x + 0.001, c.y + r * 0.1, c.z - r * 0.7);
  else if (view === "top") cam.position.set(c.x + 0.01, c.y + r, c.z);
  else cam.position.set(c.x + r * 0.78, c.y + r * 0.3, c.z - r * 0.55);
  cam.lookAt(c.x, c.y * 0.8, c.z);
  renderer.render(scene, cam);
  requestAnimationFrame(frame);
}
resize(); setLook("D"); setView("three");
requestAnimationFrame(frame);
window.__ready = true;
window.__run = t => { swingT = t; };
window.__set = (k, v, c, sp, fo, vt) => { setLook(k); setView(v); compare = !!c; spin = false; yawUser = sp || 0; frillOpen = fo === undefined ? true : fo; vsTroo = !!vt; };
window.__state = () => ({swingT, look, view});
