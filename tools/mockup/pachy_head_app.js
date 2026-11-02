// Pachy head mockup app v0.2 (E / F: Kepu's pick with a bulkier mid section). LOOKS = tools/pachy_generator.py --head X --json exports; RAPTOR / TREX / TROODON = model_json.py exports.
const LOOKS = __LOOKS__;
const RAPTOR = __RAPTOR__;
const TREX = __TREX__;
const TROODON = __TROODON__; // TroodonModelData 1.0 (model_json.py export)
const $ = id => document.getElementById(id);
const rad = THREE.MathUtils.degToRad;
const INFO = {
  A: {why: "The head in the game now (PachyModelData 1.3): a three-tier cream dome stacked on the skull with a ring of small knobs. For comparison.", pose: "Current."},
  B: {why: "War Helm: a long, low helmet of bone that sweeps back over the neck and forward into a brow shelf hanging over the eyes, bone cheek guards down the sides, a row of big knobs along the back rim, deep-set eyes in a dark mask, and a heavier, down-turned snout.", pose: "Head-down brawler."},
  C: {why: "Battering Ram: the dome thrust forward into a flat, near-vertical bone face made for hitting, with a ridge of horn knobs along its top edge and another round the back, a heavy brow, and a shorter, deeper snout tucked under. When it lowers its head to charge, the flat face leads.", pose: "Built to charge."},
  E: {why: "Your pick: the Crowned Skull with the Battering Dome spikes always on, and the mid section 25% bulkier (the body 25% thicker and taller, the chest, hips and throat 15%, the belly lower, the legs and arms set wider to match).", pose: "Bulkier, spikes always out."},
  F: {why: "The same, but the mid section 40% bulkier (chest, hips and throat 24%). Compare with E to pick how heavy it should be.", pose: "Heaviest."},
  D: {why: "Crowned Skull: a low, broad dome studded all over with knobs and ringed by a crown of short cone knobs round the back and sides, dark skull-like eye sockets, and knobs down the nose.", pose: "Spiky and armoured."},
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
      const info = {mesh: m, local: rootInv.clone().multiply(cfm(p.cf)), size: p.s, name: p.n, t: p.t || 0, hex: p.c}; segs[s.n].push(info); parts.push(info);
    }
  }
  const joints = D.joints.map(j => ({n: j.n, p0: j.p0, p1: j.p1, c0: cfm(j.c0), c1inv: cfm(j.c1).invert()}));
  return {D, g, segs, parts, joints, scale, x: 0, z: 0, yaw: 0};
}
const corner = new THREE.Vector3();
function pose(d, angles) {
  const W = {HRP: new THREE.Matrix4().makeRotationY(d.yaw)};
  for (const j of d.joints) { const v = angles[j.n] || [0, 0, 0]; W[j.p1] = W[j.p0].clone().multiply(j.c0).multiply(rot(v[0], v[1], v[2])).multiply(j.c1inv); }
  let minY = Infinity; const box = new THREE.Box3(), hbox = new THREE.Box3();
  const S = new THREE.Matrix4().makeScale(d.scale, d.scale, d.scale);
  for (const n in d.segs) for (const p of d.segs[n]) {
    const m = S.clone().multiply(W[n]).multiply(p.local); p.mesh.matrix.copy(m);
    for (let i = 0; i < 8; i++) { corner.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(m); minY = Math.min(minY, corner.y); box.expandByPoint(corner); if (n === "Head" || n === "Jaw") hbox.expandByPoint(corner); }
  }
  for (const p of d.parts) if (p.t >= 1) p.mesh.visible = !!(d.D.roles && spikesOn); // hidden in the data: the Battering Dome spikes
  const lift = new THREE.Matrix4().makeTranslation(d.x, -minY, d.z);
  for (const p of d.parts) p.mesh.matrix.premultiply(lift);
  box.translate(new THREE.Vector3(d.x, -minY, d.z)); d.box = box; hbox.translate(new THREE.Vector3(d.x, -minY, d.z)); d.hbox = hbox;
}

// ---------- state ----------
let look = "A", view = "three", spin = false, swingT = -1, compare = false, frillOpen = true, vsTroo = false, spikesOn = false, darkBone = false;
const dinos = {};
for (const k in LOOKS) { dinos[k] = buildDino(LOOKS[k], 2); dinos[k].g.visible = false; }
const herr = buildDino(TREX, 1); herr.g.visible = false;
const rap = buildDino(RAPTOR, 2); rap.g.visible = false;
const troo = buildDino(TROODON, 2); troo.g.visible = false;
const HERR_POSE = {RootJoint: [-24, 0, 0], Neck: [6, 0, 0], Head: [16, 0, 0], Jaw: [-3, 0, 0], ArmL: [30, 0, -18], ArmR: [30, 0, 18],
  LegL: [48, 0, -16], LegR: [48, 0, 16], KneeL: [-48, 0, 0], KneeR: [-48, 0, 0], AnkleL: [24, 0, 0], AnkleR: [24, 0, 0],
  Tail1: [26, 0, 0], Tail2: [4, 0, 0], Tail3: [8, 0, 0], Tail4: [14, 0, 0], Tail5: [20, 0, 0]};

function runPose(t) { // preview headbutt: lower the head and neck, lean in, charge, recover
  const u = t / 1.3;
  const k = u < 0.25 ? Math.sin(u / 0.25 * Math.PI / 2) : u < 0.8 ? 1 : 1 - (u - 0.8) / 0.2;
  const w = Math.sin(t * Math.PI * 2 * 2.2);
  return {RootJoint: [-k * 14, 0, 0], Neck: [-k * 30, 0, 0], Head: [-k * 22, 0, 0], Jaw: [0, 0, 0],
    LegL: [w * 28 * k, 0, 0], LegR: [-w * 28 * k, 0, 0], KneeL: [-Math.abs(w) * 25 * k, 0, 0], KneeR: [-Math.abs(w) * 25 * k, 0, 0],
    Tail1: [k * 8, 0, 0], Tail2: [k * 4, 0, 0]};
}

function setLook(k) {
  look = k;
  document.querySelectorAll("[data-look]").forEach(b => b.setAttribute("aria-pressed", b.dataset.look === k));
  const D = LOOKS[k], I = INFO[k];
  const NAMES = {A: "Now (egg dome)", B: "War Helm", C: "Battering Ram", D: "Crowned Skull", E: "Crowned Skull + spikes, body +25%", F: "Crowned Skull + spikes, body +40%"};
  $("info").innerHTML = `<h2>${k} · ${NAMES[k]}</h2><p>${I.why}</p><p><b>Feel:</b> ${I.pose}</p>
    <div class="sw">${Object.entries(D.roles).map(([r, h]) => `<span title="${r} #${h}" style="background:#${h}"></span>`).join("")}</div>
    <p class="muted">Colour groups: ${Object.keys(D.roles).join(", ")} (skin-ready, 10 groups). ${D.segs.reduce((n, s) => n + s.parts.length, 0)} blocks.</p>`;
}
function setView(v) { view = v; document.querySelectorAll("[data-view]").forEach(b => b.setAttribute("aria-pressed", b.dataset.view === v)); }
document.querySelectorAll("[data-look]").forEach(b => b.onclick = () => setLook(b.dataset.look));
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => setView(b.dataset.view));
$("run").onclick = () => { swingT = 0; };
$("spikes").onclick = e => { spikesOn = !spikesOn; e.currentTarget.setAttribute("aria-pressed", spikesOn); };
// preview only: a darker, weathered bone colour for the dome (changing it for real touches the pachy's skins)
const BONE = "E6DCC4", DARK = "A89470";
$("bone").onclick = e => { darkBone = !darkBone; e.currentTarget.setAttribute("aria-pressed", darkBone); e.currentTarget.textContent = darkBone ? "Dome colour: dark bone" : "Dome colour: cream";
  for (const k in dinos) for (const p of dinos[k].parts) if (p.hex === BONE || p.hex === DARK) { p.hex = darkBone ? DARK : BONE; p.mesh.material = mat(p.hex); } };
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
  if (view === "face" && !compare && !vsTroo) { // close-up of the head, from the front-left
    const hc = d.hbox.getCenter(new THREE.Vector3()), hs = d.hbox.getSize(new THREE.Vector3());
    const hr = Math.max(hs.x, hs.y, hs.z) * 0.5 / Math.tan(rad(cam.fov / 2)) * 1.5;
    cam.position.set(hc.x + hr * 0.75, hc.y + hr * 0.2, hc.z - hr * 0.65); cam.lookAt(hc.x, hc.y, hc.z);
  }
  renderer.render(scene, cam);
  requestAnimationFrame(frame);
}
resize(); setLook("E"); setView("three");
requestAnimationFrame(frame);
window.__ready = true;
window.__run = t => { swingT = t; };
window.__set = (k, v, c, sp, so) => { setLook(k); setView(v); compare = !!c; spin = false; yawUser = sp || 0; spikesOn = !!so; vsTroo = false; };
window.__state = () => ({swingT, look, view});
