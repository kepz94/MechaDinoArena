// ---------- Spin Dive mockup v0.1 animation core (built on the kit mockup v0.3: springs, solved key poses, planted feet,
// swept claw contact, hit-stop) ----------
// Joint angles [p, y, r] as measured on this rig (kit mockup v0.3). KEYS = the kit's solved key poses; SPINPOSES = the three
// spin bodies (arms solved from claw-tip targets: S_FLIP claws forward, S_SCREW arms straight out, S_TORNADO arms out and down).
const E = {
  lin: u => u, io: u => u * u * (3 - 2 * u), out: u => 1 - Math.pow(1 - u, 3), out5: u => 1 - Math.pow(1 - u, 5),
  in: u => u * u * u, in2: u => u * u,
  back: u => { const c = 1.9; return 1 + (c + 1) * Math.pow(u - 1, 3) + c * Math.pow(u - 1, 2); },
};
function lerpPose(a, b, u) {
  const o = {}; const ks = new Set([...Object.keys(a), ...Object.keys(b)]);
  for (const k of ks) {
    if (k === "root") { const ra = a.root || {}, rb = b.root || {}; o.root = {}; for (const c of ["fwd", "up", "yaw"]) o.root[c] = (ra[c] || 0) + ((rb[c] || 0) - (ra[c] || 0)) * u; continue; }
    const va = a[k] || [0, 0, 0], vb = b[k] || [0, 0, 0]; o[k] = [0, 1, 2].map(i => va[i] + (vb[i] - va[i]) * u);
  }
  return o;
}
function addPose(a, b, w) {
  const o = Object.assign({}, a);
  for (const k in b) {
    if (k === "root") continue;
    const va = a[k] || [0, 0, 0]; o[k] = [0, 1, 2].map(i => va[i] + b[k][i] * w);
  }
  return o;
}
function sample(keys, t) {
  if (t <= keys[0].t) return keys[0].pose;
  for (let i = 1; i < keys.length; i++) if (t <= keys[i].t) { const a = keys[i - 1], b = keys[i]; return lerpPose(a.pose, b.pose, (E[b.e || "io"])((t - a.t) / (b.t - a.t))); }
  return keys[keys.length - 1].pose;
}
const K = KEYS;
// ---- the three Spin Dive styles. T0 = crouch (JumpWindup), AIR = flight time, DIST = leap length, H = arc height,
// turns = full turns in the air (sign = direction), axis = what it spins around
const LEAP = {T0: 0.27, AIR: 0.78, DIST: 32};
const STYLES = {
  A: {name: "Buzzsaw Flip", pose: "S_FLIP", axis: "x", turns: -3, H: 5,
      why: "Tucks into a ball with both claws thrown forward and front-flips three times through the air like a saw blade: the claws carve big vertical circles that chop down through anything it flies over. Lands claws-first."},
  B: {name: "Corkscrew", pose: "S_SCREW", axis: "z", turns: 2, H: 7,
      why: "Stretches out long, neck forward, arms straight out to the sides, and drills through the air rolling twice like a propeller: the claws sweep a tube around its flight line, hitting what is under and beside it."},
  C: {name: "Reaper Tornado", pose: "S_TORNADO", axis: "y", turns: 3, H: 3,
      why: "A low, flat leap spinning like a top with the arms out and angled down: the claws whirl three times in a wide flat circle at raptor-back height, cutting everything around its path. Skids out of the spin."},
};
function spinTrack(st) {
  const SP = SPINPOSES[st.pose];
  const land = LEAP.T0 + LEAP.AIR;
  return {
    keys: [
      {t: 0, pose: K.READY}, {t: LEAP.T0, pose: K.J_CROUCH, e: "io"}, {t: LEAP.T0 + 0.1, pose: SP, e: "out"},
      {t: land - 0.08, pose: SP, e: "io"}, {t: land + 0.04, pose: K.J_LAND, e: "out"}, {t: land + 0.34, pose: K.CHOP_SET, e: "out"},
      {t: land + 0.95, pose: K.READY, e: "io"},
    ],
    hitFrom: LEAP.T0 + 0.05, hitTo: land + 0.05, perHitGap: 0.16, maxHits: 3, dmg: 7,
    impactAt: land, len: land + 1.2, st,
  };
}
function leapOffset(t, H) {
  const u = (t - LEAP.T0) / LEAP.AIR;
  if (u <= 0) return {fwd: 0, up: 0, air: false, u: 0};
  if (u >= 1) return {fwd: LEAP.DIST, up: 0, air: false, u: 1};
  return {fwd: LEAP.DIST * (u * 0.8 + E.out(u) * 0.2), up: 4 * H * u * (1 - u), air: true, u};
}
// spin angle: a fast start that slows to exactly the full turns at the touchdown (it lands facing forward)
function spinAngle(t, turns) {
  const u = Math.min(1, Math.max(0, (t - LEAP.T0 - 0.02) / (LEAP.AIR - 0.04)));
  return turns * Math.PI * 2 * (1 - Math.pow(1 - u, 2.2));
}

// ---------- springs (as kit v0.3) ----------
const SPR = (n) => /^(Arm|Elbow|Wrist)/.test(n) ? [38, 0.6] : n === "RootJoint" ? [30, 0.85] : /^(Leg|Knee|Ankle)/.test(n) ? [34, 0.9]
  : n === "Neck" ? [20, 0.6] : n === "Head" ? [16, 0.55] : n === "Jaw" ? [28, 0.45] : /^Tail(\d)/.test(n) ? [18 - 2.2 * (+n.slice(4)), 0.42] : [24, 0.8];
const springs = {};
function springStep(target, dt) {
  const n = Math.max(1, Math.ceil(dt * 300)); let out = {};
  for (let i = 0; i < n; i++) out = springStep1(target, dt / n);
  return out;
}
function springStep1(target, dt) {
  const out = {};
  for (const n in target) {
    if (n === "root") continue;
    let s = springs[n]; if (!s) s = springs[n] = {x: target[n].slice(), v: [0, 0, 0], k: SPR(n)};
    const [w, z] = s.k;
    for (let i = 0; i < 3; i++) { const a = w * w * (target[n][i] - s.x[i]) - 2 * z * w * s.v[i]; s.v[i] += a * dt; s.x[i] += s.v[i] * dt; }
    out[n] = s.x.slice();
  }
  for (const n in springs) if (!out[n]) { const s = springs[n]; const [w, z] = s.k; for (let i = 0; i < 3; i++) { const a = w * w * (0 - s.x[i]) - 2 * z * w * s.v[i]; s.v[i] += a * dt; s.x[i] += s.v[i] * dt; } out[n] = s.x.slice(); }
  return out;
}

// ---------- state ----------
let camMode = "hero", slowMo = false, style = "A";
let play = null, hitStop = 0, shake = 0, clockT = 0, idleT = 0, fovPunch = 0;
const rapPos = new THREE.Vector3(0, 0, -16);
const rapState = {flinch: 0, side: 0, flash: 0, push: 0, big: 0};
// spin pivot: the middle of the torso (HRP space, scale 1)
const pivot = (() => { const v = new THREE.Vector3(); let n = 0; pose(theri, {}); const inv = theri.T.clone().multiply(theri.S).invert(); for (const p of theri.segs.Torso) { v.add(new THREE.Vector3().setFromMatrixPosition(p.mesh.matrix).applyMatrix4(inv)); n++; } return v.divideScalar(Math.max(1, n)); })();
function spinMatrix(axis, ang) {
  const R = axis === "x" ? new THREE.Matrix4().makeRotationX(ang) : axis === "z" ? new THREE.Matrix4().makeRotationZ(ang) : new THREE.Matrix4().makeRotationY(ang);
  return new THREE.Matrix4().makeTranslation(pivot.x, pivot.y, pivot.z).multiply(R).multiply(new THREE.Matrix4().makeTranslation(-pivot.x, -pivot.y, -pivot.z));
}
function start() {
  play = {track: spinTrack(STYLES[style]), t: 0, hits: 0, lastHit: -9, fired: {}, lock0: 0};
}
function idleLayer(t) {
  const b = Math.sin(t * 2.1), b2 = Math.sin(t * 2.1 + 1.2);
  return {RootJoint: [b * 1.2, b2 * 1.2, 0], Neck: [-b * 1.6, Math.sin(t * 0.7) * 5, 0], Head: [0, Math.sin(t * 0.9 + 1) * 4, 0], Jaw: [Math.max(0, Math.sin(t * 0.5)) * -3, 0, 0],
    ArmL: [b2 * 2, 0, b * 1.5], ArmR: [b2 * 2, 0, -b * 1.5], WristL: [Math.sin(t * 3.1) * 3, 0, 0], WristR: [Math.sin(t * 2.9 + 2) * 3, 0, 0],
    Tail1: [b * 1.2, Math.sin(t * 1.3) * 4, 0], Tail2: [0, Math.sin(t * 1.3 - .6) * 5, 0], Tail3: [0, Math.sin(t * 1.3 - 1.2) * 6, 0], Tail4: [0, Math.sin(t * 1.3 - 1.8) * 7, 0], Tail5: [0, Math.sin(t * 1.3 - 2.4) * 8, 0]};
}
function rapBox() {
  const box = new THREE.Box3(), c = new THREE.Vector3();
  for (const n of ["Torso", "Neck", "Tail1", "Tail2", "Head"]) for (const p of rap.segs[n]) for (let i = 0; i < 8; i++) { c.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(p.mesh.matrix); box.expandByPoint(c); }
  return box.expandByScalar(1.2);
}
const prevPts = {};
function clawContact() { // swept: each claw point's motion since the last frame, against the target's box
  const box = rapBox(); let hitP = null; const ray = new THREE.Ray(), hit = new THREE.Vector3();
  for (const s of ["L", "R"]) clawParts[s].forEach((cp, ci) => {
    [partPoint(theri, cp.d, 0, cp.d.size[1] / 2, 0), partPoint(theri, cp.d, 0, 0, 0), partPoint(theri, cp.b, 0, 0, 0)].forEach((pt, pi) => {
      const key = s + ci + pi, q = prevPts[key]; prevPts[key] = pt.clone();
      if (hitP) return;
      if (box.containsPoint(pt)) { hitP = pt; return; }
      if (q) { const d = pt.clone().sub(q), L = d.length(); if (L > 1e-4) { ray.set(q, d.divideScalar(L)); if (ray.intersectBox(box, hit) && hit.distanceTo(q) <= L) hitP = hit.clone(); } }
    });
  });
  return hitP;
}
const stats = {contacts: []};
function onHit(p, n, last) {
  const big = !!last;
  hitStop = big ? 0.12 : 0.06; shake = big ? 1.4 : 0.8; fovPunch = big ? 4 : 2;
  const dir = p.clone().sub(theri.pos).setY(0).normalize().add(new THREE.Vector3(0, 0.4, 0));
  flash(p, big ? 16 : 11); sparks(p, dir, big ? 26 : 16, true);
  clawMarks(p.clone(), (n % 2 ? 0.9 : -0.9) + (Math.random() - .5) * 0.6, big);
  numberPop(p.clone().add(new THREE.Vector3(0, 5, 0)), play.track.dmg, big);
  rapState.flinch = 1; rapState.side = n % 2 ? 1 : -1; rapState.flash = 0.12; rapState.push = big ? 2 : 1; rapState.big = big ? 1 : 0;
  stats.contacts.push({t: Math.round(play.t * 100) / 100, n, at: p.toArray().map(v => Math.round(v))});
}
function onLand() {
  const g = theri.pos.clone().add(new THREE.Vector3(0, 0, -6));
  ring(g, 18, 0xfff0c0, 0.45); dust(g, 26, 9, 9); debris(g, 10);
  shake = Math.max(shake, 1.2);
}

// ---------- frame ----------
const footParts = theri.parts.filter(p => p.name.startsWith("Foot"));
function lowest(parts) { let minY = Infinity; const c = new THREE.Vector3(); for (const p of parts) for (let i = 0; i < 8; i++) { c.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(p.mesh.matrix); minY = Math.min(minY, c.y); } return minY; }
let skidDust = 0;
function step(dt) {
  if (slowMo) dt *= 0.3;
  let mdt = dt;
  if (hitStop > 0) { hitStop -= dt; mdt = dt * 0.05; }
  idleT += mdt; clockT += dt;
  let target = idleLayer(idleT), leap = {fwd: 0, up: 0, air: false, u: 0}, trailOn = {L: false, R: false}, ang = 0, st = STYLES[style];
  if (play) {
    const tr = play.track; st = tr.st;
    play.t = Math.min(play.t + mdt, tr.len);
    target = addPose(sample(tr.keys, play.t), target, 1);
    leap = leapOffset(play.t, st.H);
    ang = spinAngle(play.t, st.turns);
    if (play.t >= tr.hitFrom && play.t <= tr.hitTo) {
      trailOn.L = trailOn.R = true;
      const p = clawContact();
      if (p && play.hits < tr.maxHits && play.t - play.lastHit >= tr.perHitGap) { play.hits++; play.lastHit = play.t; onHit(p, play.hits, play.hits === tr.maxHits); }
    } else clawContact();
    if (!play.fired.land && play.t >= tr.impactAt) { play.fired.land = true; onLand(); skidDust = 0.35; }
    if (play.t >= tr.len && window.__loop) start();
  }
  const P = springStep(target, mdt);
  theri.yaw = 0;
  theri.spin = ang !== 0 && ang % (Math.PI * 2) !== 0 ? spinMatrix(st.axis, ang) : null;
  theri.pos.set(0, 0, -leap.fwd);
  theri.up = 0; pose(theri, P);
  // ground: feet planted on the ground before take-off and after landing; in the air the leap arc lifts the body and
  // nothing goes under the ground; the step from one to the other eases over the first / last 0.1 s of the flight
  const lock = -lowest(footParts);
  const all = -lowest(theri.parts);
  let up;
  if (leap.air) {
    const k = Math.min(1, leap.u / 0.13, (1 - leap.u) / 0.13);
    up = lock * (1 - k) + leap.up;
    up = Math.max(up, all + 0.2 + leap.up * 0.15);
  } else up = lock;
  theri.up = up; pose(theri, P);
  if (skidDust > 0) { skidDust -= dt; if (Math.random() < dt * 40) dust(theri.pos.clone().add(new THREE.Vector3((Math.random() - .5) * 8, 0, -3)), 1, 2, 3); }
  // target raptor: broadside, flinches, flashes red
  rapState.flinch = Math.max(0, rapState.flinch - dt * 2.6); rapState.flash = Math.max(0, rapState.flash - dt); rapState.push *= Math.pow(0.03, dt);
  const f = E.out(rapState.flinch), fb = f * (rapState.big ? 1.6 : 1);
  rap.yaw = Math.PI / 2; rap.pos.set(rapPos.x, 0, rapPos.z);
  pose(rap, {RootJoint: [10 * fb, 0, rapState.side * 8 * f], Neck: [12 * fb, rapState.side * -18 * f, 0], Head: [10 * f, 0, 0], Jaw: [-22 * f, 0, 0],
    ArmL: [-25 * f, 0, 0], ArmR: [-25 * f, 0, 0], Tail1: [-10 * fb, Math.sin(clockT * 1.3) * 4, 0], Tail2: [0, Math.sin(clockT * 1.3 - .7) * 5, 0], LegL: [-8 * fb, 0, 0], LegR: [-8 * fb, 0, 0], KneeL: [-10 * fb, 0, 0], KneeR: [-10 * fb, 0, 0]});
  rap.mats.forEach(m => m.emissive.setRGB(rapState.flash > 0 ? 0.9 : 0, rapState.flash > 0 ? 0.1 : 0, rapState.flash > 0 ? 0.05 : 0));
  updateTrails(clockT, trailOn, true);
  for (let i = fx.length - 1; i >= 0; i--) { const e = fx[i]; const fdt = dt * (hitStop > 0 ? 0.2 : 1); e.t += fdt; const u = Math.min(1, e.t / e.life); e.update(e.obj, u, fdt); if (u >= 1) { scene.remove(e.obj); fx.splice(i, 1); } }
  // camera
  shake = Math.max(0, shake - dt * 4.2); fovPunch = Math.max(0, fovPunch - dt * 14);
  const focus = new THREE.Vector3(0, 12, -LEAP.DIST * 0.5).lerp(theri.pos.clone().setY(12), 0.35); focus.y += leap.up * 0.7;
  let cp;
  if (camMode === "hero") cp = focus.clone().add(new THREE.Vector3(-66, 16, -24));
  else if (camMode === "game") cp = theri.pos.clone().add(new THREE.Vector3(-10, 28, 46));
  else cp = focus.clone().add(new THREE.Vector3(-72, 10, 0));
  camPos.lerp(cp, 0.2); camLook.lerp(focus, 0.25);
  const sh = shake * shake * 1.1;
  cam.position.copy(camPos).add(new THREE.Vector3((Math.random() - .5) * sh, (Math.random() - .5) * sh, (Math.random() - .5) * sh));
  cam.lookAt(camLook);
  cam.fov = 40 + fovPunch; cam.updateProjectionMatrix();
  sun.position.copy(focus).add(new THREE.Vector3(-30, 70, 30)); sun.target.position.copy(focus);
  renderer.render(scene, cam);
}
const camPos = new THREE.Vector3(-58, 26, -28), camLook = new THREE.Vector3(0, 12, -16);

// ---------- UI ----------
function setStyle(k) { style = k; document.querySelectorAll("[data-style]").forEach(b => b.setAttribute("aria-pressed", b.dataset.style === k)); $("info").innerHTML = `<h2>${k} · ${STYLES[k].name}</h2><p>${STYLES[k].why}</p>`; start(); }
document.querySelectorAll("[data-style]").forEach(b => b.onclick = () => setStyle(b.dataset.style));
$("replay").onclick = () => start();
$("slow").onclick = e => { slowMo = !slowMo; e.currentTarget.setAttribute("aria-pressed", slowMo); };
document.querySelectorAll("[data-cam]").forEach(b => b.onclick = () => { camMode = b.dataset.cam; document.querySelectorAll("[data-cam]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
function resize() { const w = cv.clientWidth, h = cv.clientHeight; renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); }
window.addEventListener("resize", resize);
let last = performance.now();
window.__loop = true;
function loop(now) { const dt = Math.min(0.05, (now - last) / 1000); last = now; if (!window.__manual) step(dt); requestAnimationFrame(loop); }
resize(); document.querySelector('[data-cam="hero"]').setAttribute("aria-pressed", true); setStyle("A");
requestAnimationFrame(loop);
window.__ready = true;
window.__setup = (k, cm) => { window.__manual = true; window.__loop = false; camMode = cm || "hero"; fx.splice(0).forEach(e => scene.remove(e.obj)); for (const q in trails) trails[q].pts = []; style = k; play = null; for (let i = 0; i < 40; i++) step(1 / 30); start(); stats.contacts = []; };
window.__step = dt => step(dt);
window.__len = () => play ? play.track.len : 0;
window.__stats = () => stats;
