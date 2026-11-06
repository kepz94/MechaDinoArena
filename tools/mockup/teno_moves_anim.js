// Teno move animations mockup v0.1 (Mecha Dino Arena) — the animation pass. Kepu 2026-11-05 17:33 "Do the animation pass now",
// 17:40 "some of the tail grab animations ain't looking good", 17:56 "You didn't send me the mockups". Plays each move on the
// real Teno (TenoModelData look E) with the 7 picked v2 looks (Grab-B Pincer Tail, Mortar-B Back Cannon, Stomp-A Quake Hooves,
// Bellow-A Shriek Sacs, Challenge-C Alarm Beacon, Leap-A Chicken-Leg Rams, Shield-B Shield Mane), against a raptor.
// v0.1: Tail Grab & Fling — Now (v461, as the game plays it) vs A Scorpion Strike / B Hammer Spin / C Snap Line, front + behind.
// Units: the model's (game studs / 2). Front = -Z, the camera side = +X. Tail joints: p+ = down, y+ = toward +X.
const ANIM_VERSION = "0.2"; // v0.2 (Kepu 18:32 "Next"): the other six moves, Now vs A / B / C each; the grab's A is live (v465)
const ease = u => u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2;
const lerp = (a, b, u) => a + (b - a) * u;
function mix(A, B, u) { const o = {}; for (const k of new Set([...Object.keys(A), ...Object.keys(B)])) { const a = A[k] || [0, 0, 0], b = B[k] || [0, 0, 0]; o[k] = [lerp(a[0], b[0], u), lerp(a[1], b[1], u), lerp(a[2], b[2], u)]; } return o; }
const IDLE = tt => ({Neck: [Math.sin(tt * 1.3) * 2, Math.sin(tt * 0.5) * 3, 0], Head: [Math.sin(tt * 1.3 + 1) * 3, 0, 0], Tail1: [0, Math.sin(tt * 0.8) * 3, 0], Tail2: [0, Math.sin(tt * 0.8 - 0.5) * 4, 0], Tail3: [0, Math.sin(tt * 0.8 - 1) * 5, 0], Tail4: [0, Math.sin(tt * 0.8 - 1.5) * 6, 0], Tail5: [0, Math.sin(tt * 0.8 - 2) * 7, 0]});
function resize() { const w = cv.clientWidth, h = cv.clientHeight; if (cv.width !== Math.round(w * renderer.getPixelRatio()) || cv.height !== Math.round(h * renderer.getPixelRatio())) { renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); } }
$("ver").textContent = "v" + ANIM_VERSION;
const easeOut = u => 1 - Math.pow(1 - Math.min(1, Math.max(0, u)), 3);
const easeIn = u => Math.pow(Math.min(1, Math.max(0, u)), 2);
const clamp01 = u => Math.min(1, Math.max(0, u));
const seg = (tt, a, b) => clamp01((tt - a) / (b - a));
const lerpV = (a, b, u) => a.clone().lerp(b, u);
const UP = new THREE.Vector3(0, 1, 0);
const bez = (a, b, c, u) => a.clone().multiplyScalar((1 - u) * (1 - u)).addScaledVector(b, 2 * u * (1 - u)).addScaledVector(c, u * u);

// ---------- stage ----------
lab.visible = false; island.visible = true;
island.children.forEach(c => { if (c.type === "Group") c.visible = false; });
scene.background = new THREE.Color(0x8fc6e8); scene.fog = new THREE.Fog(0x8fc6e8, 90, 240);
pose({});
const rig = dino.g;

// ---------- the picked looks (all 7, as in the game) ----------
let jaw = 0.3; // 0 = shut, 1 = wide open (the pincer)
let headOff = null; // C: the pincer head's world offset from its dock (null = docked)
let HEAD = []; // the pincer head's pieces (C flies them)
// v0.2: each look moves by its own use value u and its own clock t (the looks' built-in loops: cannon charge, rear-up, leap)
const LU = {mortar: {u: 0, t: null}, stomp: {u: 0, t: null}, bellow: {u: 0, t: null}, chal: {u: 0, t: null}, leap: {u: 0, t: null}, shield: {u: 0, t: null}};
function lookU(key, u, lt) { LU[key].u = u; LU[key].t = lt === undefined ? null : lt; }
function wrapLook(list, key) {
  const T = tt => LU[key].t === null ? tt : LU[key].t;
  for (const e of list) {
    if (e.place) { const o = e.place; e.place = (u, tt) => o(LU[key].u, T(tt)); }
    if (e.anim) { const o = e.anim; e.anim = (u, tt) => o(LU[key].u, T(tt)); }
    if (e.show) { const o = e.show; e.show = (u, tt) => o(LU[key].u, T(tt)); }
  }
}
function buildRig() {
  clearEquip();
  GLOW = AREA.attack[2]; const g0 = equip.length; grabPincer();
  const grab = equip.slice(g0);
  for (const e of grab) if (e.role === "pincer" && e.place) { const o = e.place; e.place = () => o(jaw, Math.PI / 6); } // sin(3t) = 1: open = 8 + 38 x jaw deg
  HEAD = grab.filter(e => e.part === "Tail5_main" && (e.role === "pincer" || e.role === "tip" || e.key === "iron" || e.key === "brass"));
  const look = (fn, key, area) => { GLOW = AREA[area][2]; const n0 = equip.length; fn(); wrapLook(equip.slice(n0), key); };
  look(mortarCannon, "mortar", "attack"); look(stompQuake, "stomp", "defense"); look(bellowSacs, "bellow", "health");
  look(challengeBeacon, "chal", "defense"); look(leapRams, "leap", "speed"); look(shieldMane, "shield", "defense");
  for (const e of equip) { scene.remove(e.mesh); rig.add(e.mesh); }
  for (const c of cables) for (const m of c.segs) { scene.remove(m); rig.add(m); }
}
buildRig();

// ---------- forward kinematics (no meshes) + tail IK ----------
const TAILJ = ["Tail1", "Tail2", "Tail3", "Tail4", "Tail5"];
const CLAMP_X = -3.7; // TenoPartsServer 1.4 GRIP_X: the middle of the pincer jaws, Tail5_main frame
function jointW(A) { const W = {HRP: new THREE.Matrix4()}; for (const j of dino.joints) { const v = A[j.n] || [0, 0, 0]; W[j.p1] = W[j.p0].clone().multiply(j.c0).multiply(rot(v[0], v[1], v[2])).multiply(j.c1inv); } return W; }
function fkPoint(A, part, p) { // world point of a part-local point for pose A (rig transform included)
  const b = dino.byName[part], W = jointW(A);
  const m = new THREE.Matrix4().makeTranslation(0, -restMinY, 0).multiply(W[b.seg]).multiply(b.local);
  rig.updateMatrix(); return new THREE.Vector3(...p).applyMatrix4(m).applyMatrix4(rig.matrix);
}
const clampOf = A => fkPoint(A, "Tail5_main", [CLAMP_X, 0, 0]);
const partNow = (part, p) => { rig.updateMatrixWorld(true); return new THREE.Vector3(...(p || [0, 0, 0])).applyMatrix4(dino.byName[part].mesh.matrix).applyMatrix4(rig.matrixWorld); };
const LIM_P = [-118, 48], LIM_Y = [-82, 82];
let sol = null, ikMiss = 0;
function ik(base, goal, sweeps, tight) { // tight: the jaws must be ON the target (weak smoothing, more sweeps)
  const A = Object.assign({}, base);
  for (const j of TAILJ) A[j] = (sol && sol[j] ? sol[j] : (base[j] || [0, 0, 0])).slice();
  const cost = () => {
    let c = clampOf(A).distanceToSquared(goal); const w = tight ? 0.08 : 1;
    for (let i = 0; i < 5; i++) { const a = A[TAILJ[i]]; c += w * 0.0006 * (a[0] * a[0] + a[1] * a[1]);
      if (i) { const b = A[TAILJ[i - 1]]; c += w * 0.0012 * ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2); } }
    return c;
  };
  let best = cost();
  const steps = [8, 4, 2, 1, 0.5, 0.25];
  for (let s = 0; s < (sweeps || 6) + (tight ? 4 : 0); s++) {
    const st = steps[Math.min(steps.length - 1, s)];
    for (let i = 4; i >= 0; i--) for (const ax of [0, 1]) {
      const a = A[TAILJ[i]], lim = ax ? LIM_Y : LIM_P;
      for (const dir of [1, -1]) for (let k = 0; k < 5; k++) {
        const old = a[ax]; a[ax] = Math.max(lim[0], Math.min(lim[1], old + dir * st));
        const c = cost(); if (c < best - 1e-6) best = c; else { a[ax] = old; break; }
      }
    }
  }
  sol = {}; for (const j of TAILJ) sol[j] = A[j].slice();
  ikMiss = clampOf(A).distanceTo(goal);
  return A;
}

// ---------- FX kit ----------
const fx = new THREE.Group(); scene.add(fx);
const MATS = {
  steel: new THREE.MeshPhongMaterial({color: 0xb8c0c8, specular: 0xaaaaaa, shininess: 70}), dark: new THREE.MeshPhongMaterial({color: 0x6d737c, specular: 0x888888, shininess: 50}),
  white: new THREE.MeshBasicMaterial({color: 0xffffff, transparent: true, opacity: 0.9, depthWrite: false}),
  dust: new THREE.MeshLambertMaterial({color: 0xd8c9a0, transparent: true, opacity: 0.7, depthWrite: false}),
  miss: new THREE.MeshBasicMaterial({color: 0xff2a1f, transparent: true, opacity: 0.85, depthWrite: false}),
  path: new THREE.MeshBasicMaterial({color: 0xffc21a, transparent: true, opacity: 0.55, depthWrite: false}),
};
function mk(geo, mat) { const m = new THREE.Mesh(geo, mat); m.visible = false; fx.add(m); return m; }
function setSeg(m, a, b, th) { const d = b.clone().sub(a), L = d.length(); if (L < 1e-4) { m.visible = false; return; } m.visible = true; m.position.copy(a).add(b).multiplyScalar(0.5); m.quaternion.setFromUnitVectors(UP, d.normalize()); m.scale.set(th, L, th); }
const CYL = new THREE.CylinderGeometry(0.5, 0.5, 1, 8), BOX = new THREE.BoxGeometry(1, 1, 1), BALL = new THREE.SphereGeometry(0.5, 14, 10);
const LINKS = []; for (let i = 0; i < 60; i++) LINKS.push(mk(BOX, i % 2 ? MATS.steel : MATS.dark));
function chain(a, b, sag) {
  const d = b.clone().sub(a), L = d.length(), n = Math.min(LINKS.length, Math.max(1, Math.floor(L / 0.55)));
  for (let i = 0; i < LINKS.length; i++) {
    const m = LINKS[i]; if (i >= n) { m.visible = false; continue; }
    const u0 = i / n, u1 = (i + 1) / n, P = u => a.clone().addScaledVector(d, u).add(new THREE.Vector3(0, -Math.sin(u * Math.PI) * (sag || 0), 0));
    const p0 = P(u0), p1 = P(u1), dd = p1.clone().sub(p0);
    m.visible = true; m.position.copy(p0).add(p1).multiplyScalar(0.5); m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 0, 1), dd.normalize());
    if (i % 2) m.quaternion.multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 0, 1), Math.PI / 2));
    m.scale.set(0.42, 0.16, 0.75);
  }
}
function label(text, color, w) {
  const c = document.createElement("canvas"); c.width = w || 256; c.height = 96; const g = c.getContext("2d");
  g.font = "800 60px Nunito, Segoe UI, sans-serif"; g.textAlign = "center"; g.lineWidth = 10; g.strokeStyle = "rgba(0,0,0,.75)"; g.strokeText(text, c.width / 2, 70); g.fillStyle = color || "#fff"; g.fillText(text, c.width / 2, 70);
  const s = new THREE.Sprite(new THREE.SpriteMaterial({map: new THREE.CanvasTexture(c), transparent: true, depthTest: false})); s.scale.set(3.2 * c.width / 256, 1.2, 1); s.visible = false; fx.add(s); return s;
}
const NUM = {dmg: label("8", "#ff6b6b"), stun: label("STUN", "#ffd34d"), snap: label("SNAP!", "#ffffff"), yank: label("YANKED", "#ff6b6b", 384), miss: label("CAN'T REACH", "#ff6b6b", 448)};
function pop(s, pos, k, rise) { s.visible = k > 0 && k < 1; if (!s.visible) return; s.position.copy(pos).add(new THREE.Vector3(0, 2.5 + k * (rise === undefined ? 1.6 : rise), 0)); s.material.opacity = 1 - Math.max(0, k - 0.6) / 0.4; }
const PUFFS = []; for (let i = 0; i < 24; i++) PUFFS.push(mk(BALL, MATS.dust.clone()));
let puffIdx = 0;
function puffs(center, k, spread, n) { for (let i = 0; i < n; i++) { const m = PUFFS[puffIdx++ % PUFFS.length]; if (k <= 0 || k >= 1) continue; const a = i / n * Math.PI * 2 + i; m.visible = true; m.position.set(center.x + Math.cos(a) * spread * k, 0.3 + k * 0.8 + (i % 3) * 0.15, center.z + Math.sin(a) * spread * k); m.scale.setScalar(0.6 + k * 1.2); m.material.opacity = 0.7 * (1 - k); } }
const ADD = (c, o) => new THREE.MeshBasicMaterial({color: c, transparent: true, opacity: o, blending: THREE.AdditiveBlending, depthWrite: false});
const BURSTS = [0, 1].map(() => { const m = mk(new THREE.RingGeometry(0.8, 1, 48), ADD(0xffd34d, 0.9)); m.material.side = THREE.DoubleSide; return m; });
let burstIdx = 0;
function burst(pos, k, color, maxR, flat) { const m = BURSTS[burstIdx++ % 2]; m.visible = k > 0 && k < 1; if (!m.visible) return; m.material.color.setHex(color); m.position.copy(pos); if (flat) m.rotation.set(-Math.PI / 2, 0, 0); else m.lookAt(cam.position); m.scale.setScalar(0.5 + (maxR || 3) * easeOut(k)); m.material.opacity = 0.9 * (1 - k); }
const SPEED = []; for (let i = 0; i < 8; i++) SPEED.push(mk(BOX, new THREE.MeshBasicMaterial({color: 0xffffff, transparent: true, opacity: 0.55, depthWrite: false})));
function speedLines(pos, dir, k) { SPEED.forEach((m, i) => { if (k <= 0) { m.visible = false; return; } const off = new THREE.Vector3(((i * 7) % 5 - 2) * 0.45, ((i * 3) % 5 - 2) * 0.45, ((i * 11) % 5 - 2) * 0.45); const a = pos.clone().add(off), b = a.clone().addScaledVector(dir, -(2 + (i % 3)) * k); setSeg(m, a, b, 0.07); m.material.opacity = 0.55 * k; }); }
const TRAIL = []; for (let i = 0; i < 28; i++) TRAIL.push(mk(BALL, MATS.path));
function trail(pts) { TRAIL.forEach((m, i) => { if (!pts || i >= pts.length) { m.visible = false; return; } m.visible = true; m.position.copy(pts[i]); m.scale.setScalar(0.22); }); }
const MISSLINE = mk(CYL, MATS.miss);
const SWEEP = mk(new THREE.RingGeometry(0.85, 1, 64, 1, 0, Math.PI * 1.4), ADD(0xffffff, 0.5)); SWEEP.material.side = THREE.DoubleSide;
function fxOff() { fx.children.forEach(c => c.visible = false); puffIdx = 0; burstIdx = 0; }

// ---------- the enemy (a studded raptor dummy; root = its feet) ----------
function makeRaptor() {
  const R = new THREE.Group(); scene.add(R);
  const mat = new THREE.MeshLambertMaterial({color: 0x9b2c22, map: studTex}), belly = new THREE.MeshLambertMaterial({color: 0xd9b48a, map: studTex}), eye = new THREE.MeshBasicMaterial({color: 0xffe14d});
  const add = (parent, s, p, m) => { const b = new THREE.Mesh(studBox(...s), m || mat); b.position.set(...p); parent.add(b); return b; };
  const body = new THREE.Group(); body.position.y = 2.5; R.add(body); // pivot at the torso centre (where the pincer grips)
  const hips = new THREE.Group(); hips.position.y = -0.2; body.add(hips);
  add(hips, [1.3, 1.2, 2.6], [0, 0.2, 0]); add(hips, [1.0, 0.5, 2.0], [0, -0.35, -0.2], belly);
  const neck = new THREE.Group(); neck.position.set(0, 0.6, -1.2); hips.add(neck); neck.rotation.x = 0.5;
  add(neck, [0.7, 1.4, 0.7], [0, 0.6, 0]); const head = add(neck, [0.9, 0.8, 1.6], [0, 1.3, -0.5]); head.rotation.x = -0.5;
  add(head, [0.15, 0.15, 0.15], [0.42, 0.15, -0.3], eye); add(head, [0.15, 0.15, 0.15], [-0.42, 0.15, -0.3], eye);
  const tail = add(hips, [0.6, 0.6, 2.6], [0, 0.35, 2.4]); tail.rotation.x = 0.15;
  const legs = [];
  for (const e of [-1, 1]) { const L = new THREE.Group(); L.position.set(e * 0.55, -0.2, 0.3); hips.add(L); add(L, [0.45, 1.3, 0.5], [0, -0.6, 0]); const sh = new THREE.Group(); sh.position.y = -1.2; L.add(sh); add(sh, [0.35, 1.0, 0.35], [0, -0.45, 0.2]); add(sh, [0.5, 0.15, 0.8], [0, -0.95, -0.1]); legs.push({L, sh}); }
  for (const e of [-1, 1]) add(hips, [0.2, 0.6, 0.2], [e * 0.5, -0.2, -1.1]);
  R.userData = {body, legs, neck, mat, base: 0x9b2c22};
  return R;
}
const raptor = makeRaptor();
const raptor2 = makeRaptor(), raptor3 = makeRaptor(); // v0.2
const GRIP_Y = 2.5; // torso centre above the feet
// o: {pos (feet), yaw, run, runAmt, flash, held (torso centre world pos when held), spin [x, y, z] (radians, about the torso), lie (0..1)}
function raptorPose(o) {
  const R = o.R || raptor, u = R.userData, ph = o.run || 0, a = o.runAmt === undefined ? 1 : o.runAmt;
  R.visible = o.visible !== false; if (!R.visible) return;
  if (o.held) R.position.copy(o.held).add(new THREE.Vector3(0, -GRIP_Y, 0)); else R.position.copy(o.pos);
  R.rotation.set(0, o.yaw || 0, 0);
  const sp = o.spin || [0, 0, 0]; u.body.rotation.set(sp[0], sp[1], sp[2] + (o.lie || 0) * Math.PI / 2);
  u.body.position.y = GRIP_Y - (o.lie || 0) * 1.8;
  u.legs.forEach((l, i) => { const s = Math.sin(ph + i * Math.PI); l.L.rotation.x = s * 0.7 * a; l.sh.rotation.x = -Math.max(0, Math.cos(ph + i * Math.PI)) * 0.9 * a; });
  u.neck.rotation.x = 0.5 + (o.held ? Math.sin(ph * 0.7) * 0.4 : 0);
  u.mat.color.setHex(o.flash ? 0xffffff : (o.color || u.base));
  u.neck.rotation.y = o.look || 0;
}
const grabPoint = p => p.clone().add(new THREE.Vector3(0, GRIP_Y + 0.15, 0)); // the jaws close on the torso
// a thrown body: from p0 (torso centre) to the landing spot (feet) over T s with a peak; returns {held, spin, done}
function flight(p0, land, T, peak, k, flips) {
  const u = clamp01(k), q = lerpV(p0, land.clone().setY(GRIP_Y), u); q.y += Math.sin(u * Math.PI) * peak + (1 - u) * 0 ;
  return {held: q, spin: [u * Math.PI * 2 * (flips || 1), 0, 0]};
}

// ---------- poses ----------
const BRACE2 = {LegL: [12, 0, 0], LegR: [12, 0, 0], KneeL: [-10, 0, 0], KneeR: [-10, 0, 0]}; // (the looks file has its own BRACE)
const TAIL_DOWN = {Tail1: [14, 0, 0], Tail2: [14, 0, 0], Tail3: [14, 0, 0], Tail4: [12, 0, 0], Tail5: [10, 0, 0], RootJoint: [-4, 0, 0]};
const NOSE_DOWN = {RootJoint: [-12, 0, 0], Neck: [-12, 0, 0], Head: [-8, 0, 0], LegL: [24, 0, 0], LegR: [24, 0, 0], KneeL: [-24, 0, 0], KneeR: [-24, 0, 0], AnkleL: [8, 0, 0], AnkleR: [8, 0, 0], ArmL: [-14, 0, 0], ArmR: [-14, 0, 0]};
const REAR_BACK = {RootJoint: [10, 0, 0], Neck: [8, 0, 0], Head: [-4, 0, 0], LegL: [-6, 0, 0], LegR: [-6, 0, 0], KneeL: [-14, 0, 0], KneeR: [-14, 0, 0], ArmL: [16, 0, 0], ArmR: [16, 0, 0]};
const SPIN_LEAN = {RootJoint: [-6, 0, 8], LegL: [16, 0, -6], LegR: [16, 0, 6], KneeL: [-18, 0, 0], KneeR: [-18, 0, 0], Neck: [-8, -12, 0], Head: [0, -8, 0]};
const HIPS = () => new THREE.Vector3(0, 3.42, 0.25);

// ---------- the scene for one frame ----------
let side = "front", variant = "now"; // (v0.2: "now" opens the Mortar)
const FRONT_Z = -11, BACK_Z = 23; // where the raptor stands (feet): at the edge of TenoGrabRange (12 studs = 6 units from Head_cranium / the tail tip)
const LAND_DIST = 22.5; // 45 studs (TenoGrabFling)
const st = {}; // per-frame scratch shared with the camera / caption
function reset() { sol = null; rig.position.set(0, 0, 0); rig.rotation.set(0, 0, 0); jaw = 0.3; headOff = null; }

// common: the raptor standing / idling at its spot, facing the teno
function standing(tt, z) { raptorPose({pos: new THREE.Vector3(0.6, 0, z), yaw: z < 0 ? Math.PI : 0, run: tt * 3, runAmt: 0.12}); }
function landed(land, tt, tLand, faceTeno) {
  const k = tt - tLand;
  raptorPose({pos: land, yaw: faceTeno, lie: k < 1.4 ? 1 : 1 - clamp01((k - 1.4) / 0.4), run: tt * 3, runAmt: 0, flash: k < 0.08});
  puffs(land, clamp01(k / 0.6), 3, 10); burst(land.clone().setY(0.1), clamp01(k / 0.4), 0xffd34d, 4, true);
  pop(NUM.dmg, land, clamp01(k / 1.1)); pop(NUM.stun, land.clone().add(new THREE.Vector3(0, 1.3, 0)), clamp01((k - 0.15) / 1.0));
}

const V = {}; // variant -> {name, sub, ref, len, phases(side), update(tt), info}
const PRESS = 0.3;

// ===== Now (v461): Over the Top as the game plays it (TenoPose 1.10 grabPath + TenoMovesServer 1.9 timings) =====
V.now = {name: "Now", sub: "as the game plays it (v461)", len: 3.6,
  ref: "Over the Top (your pick from the tail-grab mockup v0.1, 2026-11-03): the tail arcs over the back like a scorpion.",
  timing: s => s === "front" ? "press → catch 0.70 s · throw 1.35 s · flight 0.85 s" : "press → catch 0.45 s · throw 1.10 s · flight 0.85 s",
  phases: s => s === "front"
    ? [[0, PRESS, "A raptor in front of you"], [PRESS, 0.55, "Wind-up · the tail drops"], [0.55, 0.88, "The tail arcs over your back toward it"], [0.88, 1.0, "The raptor is pulled to the jaws (Studio: up to ~40 studs in 0.12 s)"], [1.0, 1.45, "Lifted ~32 studs up over your back"], [1.45, 1.65, "Whip"], [1.65, 2.5, "Thrown out behind you"], [2.5, 3.6, "Lands · 8 damage, stunned"]]
    : [[0, PRESS, "A raptor behind you"], [PRESS, 0.55, "Wind-up · the tail drops"], [0.55, 0.63, "The tail swings down… and can't reach"], [0.63, 0.75, "The raptor is YANKED to the jaws (Studio: ~22 studs in 0.12 s)"], [0.75, 1.2, "Lifted up over your back"], [1.2, 1.4, "Whip"], [1.4, 2.25, "Thrown out in front of you"], [2.25, 3.6, "Lands · 8 damage, stunned"]],
  update(tt) {
    const front = side === "front", z0 = front ? FRONT_Z : BACK_Z, A0 = IDLE(tt), base = Object.assign({}, A0, BRACE2);
    const tW = PRESS + 0.25, tC = PRESS + (front ? 0.70 : 0.45), tT = PRESS + (front ? 1.35 : 1.10), tL = tT + 0.85;
    const lean = front ? {RootJoint: [-10, 0, 0], Neck: [-16, 0, 0], Head: [-10, 0, 0], LegL: [22, 0, 0], LegR: [22, 0, 0], KneeL: [-18, 0, 0], KneeR: [-18, 0, 0]} : {};
    const b2 = Object.assign({}, base, lean);
    const over = new THREE.Vector3(0, 16, HIPS().z + 0.5), whipTo = front ? new THREE.Vector3(0, 6, 21) : new THREE.Vector3(0, 9, -7);
    const target = grabPoint(new THREE.Vector3(0.6, 0, z0));
    const land = new THREE.Vector3(front ? 1 : -1, 0, front ? LAND_DIST : -LAND_DIST);
    let A = A0, held = null, spin = null;
    if (tt < PRESS) { A = A0; jaw = 0.3; standing(tt, z0); }
    else if (tt < tW) { A = mix(A0, Object.assign({}, b2, TAIL_DOWN), ease(seg(tt, PRESS, tW))); jaw = 0.8; sol = null; standing(tt, z0); }
    else if (tt < tC) {
      const u = ease(seg(tt, tW, tC)), from = clampOf(Object.assign({}, b2, TAIL_DOWN));
      A = ik(mix(A0, b2, u), front ? bez(from, new THREE.Vector3(0, 18, HIPS().z - 1), target, u) : from.clone().lerp(target, u), 6); jaw = 1;
      const tip = clampOf(A), yankT = tC - 0.12;
      if (tt < yankT) { standing(tt, z0); if (u > 0.6 && tip.distanceTo(target) > 2) { setSeg(MISSLINE, tip, target, 0.12); pop(NUM.miss, target.clone().add(new THREE.Vector3(0, 0.8, 0)), 0.5, 0); } }
      else { const k = seg(tt, yankT, tC), p = lerpV(target, tip, easeIn(k)); held = p; spin = [0, 0, k * 0.6]; const gap = target.distanceTo(tip); if (gap > 2) { speedLines(p, tip.clone().sub(target).normalize(), 1); pop(NUM.yank, p, 0.4, 0); } st.yank = gap * 2; }
    } else if (tt < tT - 0.2) {
      if (!st.from) st.from = clampOf(ik(b2, target, 6));
      const u = ease(seg(tt, tC, tT - 0.2)), goal = st.from.clone().lerp(over, u).add(new THREE.Vector3(0, Math.sin(u * Math.PI) * 4, 0));
      A = ik(b2, goal, 6); jaw = 0; held = clampOf(A).add(new THREE.Vector3(0, -0.6, 0)); spin = [0, 0, Math.PI * 0.8 * u];
      if (tt - tC < 0.3) pop(NUM.snap, held, seg(tt, tC, tC + 0.6));
    } else if (tt < tT) {
      const u = easeIn(seg(tt, tT - 0.2, tT));
      A = ik(Object.assign({}, b2, front ? {RootJoint: [-14, 0, 0]} : {RootJoint: [-16, 0, 0], Neck: [-14, 0, 0]}), over.clone().lerp(whipTo, u), 6); jaw = 0;
      held = clampOf(A).add(new THREE.Vector3(0, -0.6, 0)); spin = [0, 0, Math.PI * 0.8];
      st.rel = held.clone(); st.relMiss = ikMiss * 2;
    } else {
      const u = ease(seg(tt, tT, tT + 0.9));
      A = mix(ik(base, front ? new THREE.Vector3(0, 8, 17) : new THREE.Vector3(0, 10, 4), 3), A0, u); jaw = 0.3 + 0.7 * (1 - u);
      if (tt < tL) { const f = flight(st.rel || clampOf(A), land, 0.85, 8, seg(tt, tT, tL), 1); held = f.held; spin = f.spin; }
      else landed(land, tt, tL, front ? 0 : Math.PI);
    }
    pose(A);
    if (held) raptorPose({held, spin, yaw: front ? Math.PI : 0, run: tt * 14, runAmt: 1});
    st.reach = clampOf(A).distanceTo(target);
  }};

// ===== A · Scorpion Strike (Zoids Death Stinger = the Pincer Tail's own reference; a scorpion's sting over its back) =====
V.A = {name: "A · Scorpion Strike", sub: "coils over the back, stabs down", len: 3.4, rec: true,
  ref: "Zoids — Death Stinger (the Pincer Tail's look) + a real scorpion: the tail coils high over the back, then strikes forward and down.",
  timing: s => s === "front" ? "press → catch 0.55 s · throw 1.15 s · flight 0.5 s" : "press → catch 0.40 s · throw 1.00 s · flight 0.5 s",
  phases: s => s === "front"
    ? [[0, PRESS, "A raptor in front of you"], [PRESS, 0.7, "Wind-up · nose down, tail coils high over your back, pincer opens wide"], [0.7, 0.85, "STRIKE · the tail stabs down over your head"], [0.85, 1.05, "SNAP · the pincer clamps its back"], [1.05, 1.3, "Lift · raised off its feet, over your back"], [1.3, 1.45, "Slam · swung down behind you"], [1.45, 1.95, "Flung out behind you (short and low)"], [1.95, 3.4, "Lands · 8 damage, stunned · the tail recoils, pincer opens"]]
    : [[0, PRESS, "A raptor behind you"], [PRESS, 0.55, "Wind-up · tail lifts, pincer opens wide"], [0.55, 0.7, "STRIKE · the tail stabs back and down"], [0.7, 0.9, "SNAP · the pincer clamps its back"], [0.9, 1.15, "Lift · over your back"], [1.15, 1.3, "Slam · swung down in front of you"], [1.3, 1.8, "Flung out in front of you"], [1.8, 3.4, "Lands · 8 damage, stunned · the tail recoils"]],
  update(tt) {
    const front = side === "front", z0 = front ? FRONT_Z : BACK_Z, A0 = IDLE(tt);
    const target = grabPoint(new THREE.Vector3(0.6, 0, z0));
    const coil = front ? new THREE.Vector3(0.4, 13.5, 2.5) : new THREE.Vector3(0.4, 11, 13);
    const tW = PRESS + (front ? 0.4 : 0.25), tS = tW + 0.15, tC = tS + 0.2, tLf = tC + 0.25, tT = tLf + 0.15, tL = tT + 0.5;
    const body = front ? NOSE_DOWN : REAR_BACK;
    rig.position.z = (front ? -1.8 : 4.5) * ease(seg(tt, PRESS, tS)); // a quick lunge (front) / back-step (behind): TenoGrabRange reaches 12 studs past the head / tip, further than the tail
    const carry = new THREE.Vector3(0.4, 10.5, front ? 3 : 1), slamTo = front ? new THREE.Vector3(0.6, 5, 16) : new THREE.Vector3(0.6, 5, -9);
    const land = new THREE.Vector3(front ? 1 : -1, 0, front ? 18 : -15);
    let A = A0, held = null, spin = null;
    if (tt < PRESS) { jaw = 0.3; standing(tt, z0); }
    else if (tt < tW) { const u = ease(seg(tt, PRESS, tW)); if (tt - PRESS < 0.03) sol = null; A = ik(mix(A0, body, u), lerpV(clampOf(A0), coil, u), 6); jaw = 0.3 + 0.7 * u; standing(tt, z0); st.coilA = A; }
    else if (tt < tS) { const u = easeIn(seg(tt, tW, tS)); A = ik(Object.assign({}, A0, body), bez(coil, coil.clone().add(new THREE.Vector3(0, 2, front ? -6 : 6)), target, u), 6, u > 0.7); jaw = 1; standing(tt, z0);
      speedLines(clampOf(A), target.clone().sub(coil).normalize(), u); }
    else if (tt < tC) { A = ik(Object.assign({}, A0, body), target, 6, true); jaw = 1 - easeOut(seg(tt, tS, tS + 0.08)); held = clampOf(A); spin = [0, 0, 0];
      burst(held, seg(tt, tS, tS + 0.35), 0xffffff, 2.5); pop(NUM.snap, held, seg(tt, tS, tS + 0.7)); raptorPose({held, spin, yaw: front ? Math.PI : 0, run: tt * 14, runAmt: 1, flash: tt - tS < 0.07}); held = null;
      puffs(new THREE.Vector3(0.6, 0, z0), seg(tt, tS, tS + 0.5), 2, 8); }
    else if (tt < tLf) { const u = ease(seg(tt, tC, tLf)); A = ik(mix(Object.assign({}, A0, body), Object.assign({}, A0, BRACE2), u), bez(target, target.clone().lerp(carry, 0.5).add(new THREE.Vector3(0, 3, 0)), carry, u), 6); jaw = 0; held = clampOf(A); spin = [front ? -u * 0.8 : u * 0.8, 0, 0]; }
    else if (tt < tT) { const u = easeIn(seg(tt, tLf, tT)); A = ik(Object.assign({}, A0, BRACE2, front ? {RootJoint: [6, 0, 0]} : {RootJoint: [-10, 0, 0], Neck: [-10, 0, 0]}), carry.clone().lerp(slamTo, u), 6); jaw = 0; held = clampOf(A); spin = [front ? -0.8 - u * 1.6 : 0.8 + u * 1.6, 0, 0]; st.rel = held.clone(); st.relSpin = spin[0];
      if (front) SWEEP.visible = false; }
    else {
      const u = ease(seg(tt, tT, tT + 0.7)); A = mix(ik(Object.assign({}, A0, BRACE2), front ? new THREE.Vector3(0.4, 7, 15) : new THREE.Vector3(0.4, 8, 9), 3), A0, u);
      jaw = tt < tT + 0.25 ? 1 : 0.3 + 0.7 * (1 - seg(tt, tT + 0.25, tT + 0.9));
      if (tt < tL) { const f = flight(st.rel || clampOf(A), land, 0.5, 2.5, seg(tt, tT, tL), 0.6); held = f.held; spin = [st.relSpin + (front ? -1 : 1) * f.spin[0], 0, 0]; }
      else landed(land, tt, tL, front ? 0 : Math.PI);
    }
    pose(A);
    if (held) raptorPose({held, spin, yaw: front ? Math.PI : 0, run: tt * 14, runAmt: 1});
    st.reach = clampOf(A).distanceTo(target);
  }};

// ===== B · Hammer Spin (the Human Hammer Throw: Mario swings Bowser by the tail; Monster Hunter tail spins) =====
V.B = {name: "B · Hammer Spin", sub: "you spin round and sling it", len: 3.8,
  ref: "The Human Hammer Throw (Super Mario 64 swings Bowser round by the tail; Tekken's spinning throws) + Monster Hunter's tail spins: grab, spin, let go.",
  timing: s => s === "front" ? "press → catch 0.45 s · throw 1.35 s · flight 0.9 s" : "press → catch 0.25 s · throw 1.15 s · flight 0.9 s",
  phases: s => s === "front"
    ? [[0, PRESS, "A raptor in front of you"], [PRESS, 0.75, "Pivot · you stomp round 180°, the tail sweeps low into it"], [0.75, 0.9, "SNAP · the pincer clamps it"], [0.9, 1.65, "Spin · it swings out wide, feet off the ground, dust ring"], [1.65, 1.75, "Let go · it flies out ahead of you"], [1.75, 2.55, "You skid to a stop facing forward"], [2.55, 3.8, "Lands far ahead · 8 damage, stunned"]]
    : [[0, PRESS, "A raptor behind you"], [PRESS, 0.55, "The tail swings down into it"], [0.55, 0.7, "SNAP · the pincer clamps it"], [0.7, 1.45, "Spin · one and a quarter turns, it swings out wide"], [1.45, 1.55, "Let go · it flies out ahead of you"], [1.55, 2.35, "You skid to a stop facing forward"], [2.35, 3.8, "Lands far ahead · 8 damage, stunned"]],
  update(tt) {
    const front = side === "front", z0 = front ? FRONT_Z : BACK_Z, A0 = IDLE(tt), base = Object.assign({}, A0, BRACE2);
    const tP = front ? PRESS + 0.45 : PRESS + 0.3, tC = tP + 0.15, tR = tC + 0.75, tStop = tR + 0.8, tL = tR + 0.9;
    const yawC = front ? -Math.PI : 0, yawR = -2.5 * Math.PI, yawEnd = -2 * Math.PI;
    const p0 = new THREE.Vector3(0.6, 0, z0), target = grabPoint(p0);
    const land = new THREE.Vector3(0, 0, -30);
    let A = A0, held = null, spin = null, yaw = 0;
    if (!front) rig.position.z = 4.5 * ease(seg(tt, PRESS, tP)); // a back-step so the tail reaches
    if (tt < PRESS) { jaw = 0.3; standing(tt, z0); }
    else if (tt < tP) { const u = ease(seg(tt, PRESS, tP)); yaw = yawC * u; rig.rotation.y = yaw; if (tt - PRESS < 0.03) sol = null;
      A = ik(mix(A0, Object.assign({}, base, SPIN_LEAN, {LegL: [12 + Math.sin(u * 10) * 16, 0, 0], LegR: [12 - Math.sin(u * 10) * 16, 0, 0]}), u), lerpV(clampOf(A0), target, u), 6, u > 0.7); jaw = 0.3 + 0.7 * u; standing(tt, z0);
      if (front) { SWEEP.visible = true; SWEEP.position.set(0, 0.15, 0); SWEEP.rotation.set(-Math.PI / 2, 0, -yaw + Math.PI / 2); SWEEP.scale.setScalar(16); SWEEP.material.opacity = 0.35 * (1 - u * 0.5); } }
    else if (tt < tC) { rig.rotation.y = yawC; A = ik(Object.assign({}, base, SPIN_LEAN), target, 6, true); jaw = 1 - easeOut(seg(tt, tP, tP + 0.08)); held = clampOf(A); spin = [0, 0, 0];
      burst(held, seg(tt, tP, tP + 0.35), 0xffffff, 2.5); pop(NUM.snap, held, seg(tt, tP, tP + 0.7)); }
    else if (tt < tR) {
      const u = seg(tt, tC, tR); yaw = yawC + (yawR - yawC) * (u * u * (1.6 - 0.6 * u)); rig.rotation.y = yaw;
      const out = new THREE.Vector3(0.4, 3.2 + 1.2 * u, 19).applyAxisAngle(UP, yaw).add(rig.position); // swung out wide, feet off the ground
      A = ik(Object.assign({}, base, SPIN_LEAN, {RootJoint: [-6, 0, 8 + 6 * u]}), out, 6); jaw = 0; held = clampOf(A); spin = [0, 0, -0.9 * u];
      puffs(new THREE.Vector3(0, 0, 0), (u * 3) % 1, 6 + 4 * u, 6); st.rel = held.clone();
      const tan = new THREE.Vector3(1, 0, 0).applyAxisAngle(UP, yaw); speedLines(held, tan, u);
    } else {
      const u = ease(seg(tt, tR, tStop)); yaw = yawR + (yawEnd - yawR) * u; rig.rotation.y = yaw;
      A = mix(Object.assign({}, base, SPIN_LEAN, {LegL: [30, 0, -10], LegR: [4, 0, 10]}), A0, u); jaw = 0.3 + 0.7 * (1 - u);
      if (u < 0.6) puffs(new THREE.Vector3(0, 0, 0).add(new THREE.Vector3(2, 0, -1)), u / 0.6, 3, 6);
      if (tt < tL) { const f = flight(st.rel, land, 0.9, 7, seg(tt, tR, tL), 1.5); held = f.held; spin = f.spin; }
      else landed(land, tt, tL, 0);
    }
    pose(A);
    if (held) raptorPose({held, spin, yaw: yaw + Math.PI, run: tt * 14, runAmt: 1});
    st.reach = clampOf(A).distanceTo(target); st.yaw = yaw;
  }};

// ===== C · Snap Line (Mortal Kombat Scorpion's spear "Get over here!": fire a line, hook, reel them in) =====
V.C = {name: "C · Snap Line", sub: "the pincer fires out on a chain", len: 3.8,
  ref: "Mortal Kombat — Scorpion's spear (\"Get over here!\"): a bladed line shoots out, hooks the enemy and reels them in. Here the pincer head fires off the tail on a chain.",
  timing: s => s === "front" ? "press → catch 0.55 s · throw 1.45 s · flight 0.7 s" : "press → catch 0.45 s · throw 1.25 s · flight 0.7 s",
  phases: s => s === "front"
    ? [[0, PRESS, "A raptor in front of you"], [PRESS, 0.6, "Wind-up · tail rises over your back, aims"], [0.6, 0.85, "FIRE · the pincer head shoots out on its chain"], [0.85, 0.95, "SNAP · it clamps the raptor"], [0.95, 1.45, "Reel in · the chain hauls it up over your back"], [1.45, 1.75, "Docked · the tail swings it down behind you"], [1.75, 2.45, "Flung out behind you"], [2.45, 3.8, "Lands · 8 damage, stunned"]]
    : [[0, PRESS, "A raptor behind you"], [PRESS, 0.5, "Wind-up · the tail aims back"], [0.5, 0.75, "FIRE · the pincer head shoots out on its chain"], [0.75, 0.85, "SNAP · it clamps the raptor"], [0.85, 1.25, "Reel in · dragged along the ground to your tail"], [1.25, 1.55, "Docked · the tail swings it over your back"], [1.55, 2.25, "Flung out in front of you"], [2.25, 3.8, "Lands · 8 damage, stunned"]],
  update(tt) {
    const front = side === "front", z0 = front ? FRONT_Z : BACK_Z, A0 = IDLE(tt), base = Object.assign({}, A0, BRACE2);
    const p0 = new THREE.Vector3(0.6, 0, z0), target = grabPoint(p0);
    const aim = front ? new THREE.Vector3(0.4, 11, 4) : new THREE.Vector3(0.4, 4.5, 15);
    const tA = PRESS + (front ? 0.3 : 0.2), tF = tA + 0.25, tC = tF + 0.1, tR = tC + (front ? 0.5 : 0.4), tT = tR + 0.3, tL = tT + 0.7;
    const swingTo = front ? new THREE.Vector3(0.6, 5, 17) : new THREE.Vector3(0.6, 9, -6);
    const land = new THREE.Vector3(front ? 1 : -1, 0, front ? 20 : -20);
    let A = A0, held = null, spin = null;
    const aimA = () => ik(Object.assign({}, base, front ? {RootJoint: [-6, 0, 0], Neck: [-6, 0, 0]} : {}), aim, 6);
    if (tt < PRESS) { jaw = 0.3; standing(tt, z0); }
    else if (tt < tA) { const u = ease(seg(tt, PRESS, tA)); if (tt - PRESS < 0.03) sol = null; A = ik(mix(A0, base, u), lerpV(clampOf(A0), aim, u), 6); jaw = 0.3 + 0.7 * u; standing(tt, z0); }
    else {
      if (tt < tR) A = aimA();
      const dock = () => clampOf(A);
      if (tt < tF) { const u = easeOut(seg(tt, tA, tF)); const d = dock(); const hp = bez(d, d.clone().lerp(target, 0.5).add(new THREE.Vector3(0, 3, 0)), target, u); headOff = hp.sub(d); jaw = 1; standing(tt, z0); chain(d, d.clone().add(headOff), 0.4 * (1 - u)); }
      else if (tt < tC) { const d = dock(); headOff = target.clone().sub(d); jaw = 1 - easeOut(seg(tt, tF, tF + 0.08)); chain(d, target, 0);
        burst(target, seg(tt, tF, tF + 0.35), 0xffffff, 2.5); pop(NUM.snap, target, seg(tt, tF, tF + 0.7)); raptorPose({held: target, spin: [0, 0, 0], yaw: front ? Math.PI : 0, run: tt * 14, runAmt: 1, flash: tt - tF < 0.07}); }
      else if (tt < tR) {
        const u = easeIn(seg(tt, tC, tR)), d = dock();
        const p = front ? bez(target, new THREE.Vector3(0.6, 12, (z0 + d.z) / 2), d, u) : lerpV(target, d, u).setY(lerp(target.y, d.y, Math.pow(u, 3)));
        headOff = p.clone().sub(d); jaw = 0; chain(d, p, 0); held = p; spin = [front ? -u * 1.2 : 0, 0, front ? 0 : 0.3];
        if (!front) puffs(new THREE.Vector3(p.x, 0, p.z), (u * 2.5) % 1, 1.2, 5);
        speedLines(p, d.clone().sub(p).normalize(), 0.7);
      } else {
        headOff = null;
        if (tt < tT) { const u = easeIn(seg(tt, tR, tT)); A = ik(Object.assign({}, base, front ? {RootJoint: [4, 0, 0]} : {RootJoint: [-12, 0, 0], Neck: [-10, 0, 0]}), aim.clone().lerp(swingTo, u), 6); jaw = 0; held = clampOf(A); spin = [front ? -1.2 - u * 1.4 : u * 1.4, 0, 0]; st.rel = held.clone(); st.relSpin = spin[0]; }
        else {
          const u = ease(seg(tt, tT, tT + 0.8)); A = mix(ik(base, front ? new THREE.Vector3(0.4, 7, 16) : new THREE.Vector3(0.4, 9, 6), 3), A0, u); jaw = 0.3 + 0.7 * (1 - seg(tt, tT + 0.2, tT + 0.8));
          if (tt < tL) { const f = flight(st.rel, land, 0.7, 4, seg(tt, tT, tL), 0.8); held = f.held; spin = [st.relSpin + (front ? -1 : 1) * f.spin[0], 0, 0]; }
          else landed(land, tt, tL, front ? 0 : Math.PI);
        }
      }
    }
    pose(A);
    if (held) raptorPose({held, spin, yaw: front ? Math.PI : 0, run: tt * 14, runAmt: 1});
    st.reach = clampOf(A).distanceTo(target);
  }};


// ============================== v0.2: the other six moves ==============================
const AT = (tt, keys) => { // keyframes [[t, pose (object or fn(tt)), ease], ...] -> pose
  const P = k => typeof k[1] === "function" ? k[1](tt) : k[1];
  if (tt <= keys[0][0]) return P(keys[0]);
  for (let i = 1; i < keys.length; i++) if (tt < keys[i][0]) return mix(P(keys[i - 1]), P(keys[i]), (keys[i][2] || ease)(seg(tt, keys[i - 1][0], keys[i][0])));
  return P(keys[keys.length - 1]);
};
const plus = (...ps) => { const o = {}; for (const q of ps) for (const k in q) { const a = o[k] || [0, 0, 0]; o[k] = [a[0] + q[k][0], a[1] + q[k][1], a[2] + q[k][2]]; } return o; };
const sm2 = u => { u = clamp01(u); return u * u * (3 - 2 * u); };
// the game's poses (TenoPose 1.11)
const G_REAR = {RootJoint: [40, 0, 0], LegL: [-40, 0, 0], LegR: [-40, 0, 0], KneeL: [-30, 0, 0], KneeR: [-30, 0, 0], ArmL: [70, 0, 0], ArmR: [60, 0, 0], Neck: [12, 0, 0], Head: [-6, 0, 0], Jaw: [-20, 0, 0], Tail1: [-30, 0, 0], Tail5: [-12, 0, 0]};
const G_STOMP2 = {RootJoint: [-14, 0, 0], LegL: [14, 0, 0], LegR: [14, 0, 0], ArmL: [-12, 0, 0], ArmR: [-12, 0, 0], Neck: [-16, 0, 0], Head: [-12, 0, 0], Jaw: [-8, 0, 0], Tail1: [14, 0, 0]};
const G_BELLOW = {Neck: [34, 0, 0], Head: [18, 0, 0], Jaw: [-38, 0, 0], RootJoint: [6, 0, 0], LegL: [-6, 0, 0], LegR: [-6, 0, 0], Tail1: [-10, 0, 0]};
const G_BRACE = {RootJoint: [10, 0, 0], LegL: [-10, 0, 0], LegR: [-10, 0, 0], ArmL: [35, 0, 0], ArmR: [35, 0, 0], Neck: [16, 0, 0], Head: [-8, 0, 0], Jaw: [-16, 0, 0], Tail1: [-6, 0, 0]};
const G_COIL = {RootJoint: [-8, 0, 0], LegL: [20, 0, 0], LegR: [20, 0, 0], KneeL: [-28, 0, 0], KneeR: [-28, 0, 0], AnkleL: [8, 0, 0], AnkleR: [8, 0, 0], ArmL: [-12, 0, 0], ArmR: [-12, 0, 0], Neck: [-10, 0, 0], Head: [6, 0, 0], Tail1: [28, 0, 0], Tail2: [22, 0, 0], Tail3: [20, 0, 0], Tail4: [18, 0, 0], Tail5: [16, 0, 0]};
const G_WHIP = {RootJoint: [10, 0, 0], LegL: [-10, 0, 0], LegR: [-10, 0, 0], ArmL: [20, 0, 0], ArmR: [20, 0, 0], Neck: [12, 0, 0], Head: [-8, 0, 0], Jaw: [-14, 0, 0], Tail1: [-110, 0, 0], Tail2: [-70, 0, 0], Tail3: [-55, 0, 0], Tail4: [-40, 0, 0], Tail5: [-30, 0, 0]};
const G_JREAR = {RootJoint: [40, 0, 0], LegL: [-40, 0, 0], LegR: [-40, 0, 0], KneeL: [-30, 0, 0], KneeR: [-30, 0, 0], ArmL: [60, 0, 0], ArmR: [60, 0, 0], Neck: [12, 0, 0], Tail1: [-30, 0, 0], Tail5: [-12, 0, 0]};
const G_JAIR = {RootJoint: [10, 0, 0], LegL: [-30, 0, 0], LegR: [-30, 0, 0], KneeL: [-20, 0, 0], KneeR: [-20, 0, 0], ArmL: [55, 0, 0], ArmR: [55, 0, 0], Neck: [12, 0, 0], Head: [-6, 0, 0], Jaw: [-18, 0, 0], Tail1: [-16, 0, 0], Tail2: [-10, 0, 0], Tail3: [-8, 0, 0], Tail4: [-6, 0, 0], Tail5: [-6, 0, 0]};
const G_JLAND = {RootJoint: [-10, 0, 0], LegL: [24, 0, 0], LegR: [24, 0, 0], KneeL: [-30, 0, 0], KneeR: [-30, 0, 0], ArmL: [-20, 0, 0], ArmR: [-20, 0, 0], Neck: [-14, 0, 0], Head: [-8, 0, 0], Tail1: [10, 0, 0], Tail2: [8, 0, 0], Tail3: [6, 0, 0]};
const G_SLAM2 = {RootJoint: [6, 0, 0], LegL: [-6, 0, 0], LegR: [-6, 0, 0], Neck: [-4, 0, 0], Tail1: [26, 0, 0], Tail2: [14, 0, 0], Tail3: [10, 0, 0], Tail4: [4, 0, 0], Tail5: [-4, 0, 0]};
// new poses
const ANCHOR = {RootJoint: [-6, 0, 0], LegL: [26, 18, 0], LegR: [26, -18, 0], KneeL: [-34, 0, 0], KneeR: [-34, 0, 0], AnkleL: [10, 0, 0], AnkleR: [10, 0, 0], ArmL: [-10, 0, 0], ArmR: [-10, 0, 0], Neck: [-8, 0, 0], Tail1: [22, 0, 0], Tail2: [12, 0, 0], Tail3: [4, 0, 0], Tail4: [-2, 0, 0], Tail5: [-4, 0, 0]};
const KICK = {RootJoint: [9, 0, 0], Neck: [8, 0, 0], Head: [-6, 0, 0], ArmL: [10, 0, 0], ArmR: [10, 0, 0]};
const REAR_HI = {RootJoint: [52, 0, 0], LegL: [-50, 0, 0], LegR: [-50, 0, 0], KneeL: [-26, 0, 0], KneeR: [-26, 0, 0], ArmL: [85, 0, 0], ArmR: [80, 0, 0], Neck: [6, 0, 0], Head: [-10, 0, 0], Jaw: [-28, 0, 0], Tail1: [-36, 0, 0], Tail2: [6, 0, 0], Tail5: [-12, 0, 0]};
const SMASH = {RootJoint: [-18, 0, 0], LegL: [18, 0, 0], LegR: [18, 0, 0], KneeL: [-12, 0, 0], KneeR: [-12, 0, 0], ArmL: [-16, 0, 0], ArmR: [-16, 0, 0], Neck: [-20, 0, 0], Head: [-14, 0, 0], Jaw: [-12, 0, 0], Tail1: [18, 0, 0]};
const TUCK = {RootJoint: [4, 0, 0], LegL: [40, 0, 0], LegR: [40, 0, 0], KneeL: [-70, 0, 0], KneeR: [-70, 0, 0], AnkleL: [30, 0, 0], AnkleR: [30, 0, 0], ArmL: [40, 0, 0], ArmR: [40, 0, 0], Neck: [6, 0, 0], Tail1: [-10, 0, 0]};
const SQUAT = {RootJoint: [-6, 0, 0], LegL: [36, 0, 0], LegR: [36, 0, 0], KneeL: [-62, 0, 0], KneeR: [-62, 0, 0], AnkleL: [26, 0, 0], AnkleR: [26, 0, 0], ArmL: [-14, 0, 0], ArmR: [-14, 0, 0], Neck: [-8, 0, 0], Tail1: [10, 0, 0]};
const SLAP_L = {RootJoint: [10, 0, -4], ArmL: [60, 0, 0], Neck: [6, 0, 0], LegL: [-6, 0, 0], LegR: [-6, 0, 0]}, SLAP_R = {RootJoint: [10, 0, 4], ArmR: [60, 0, 0], Neck: [6, 0, 0], LegL: [-6, 0, 0], LegR: [-6, 0, 0]};
const SLAP_DN = {RootJoint: [-6, 0, 0], ArmL: [-14, 0, 0], ArmR: [-14, 0, 0], Neck: [-8, 0, 0]};
const INHALE = {RootJoint: [8, 0, 0], Neck: [24, 0, 0], Head: [26, 0, 0], Jaw: [-6, 0, 0], ArmL: [10, 0, 0], ArmR: [10, 0, 0], Tail1: [-8, 0, 0]};
const SHRIEK = {RootJoint: [-6, 0, 0], Neck: [-4, 0, 0], Head: [-6, 0, 0], Jaw: [-46, 0, 0], LegL: [10, 0, 0], LegR: [-4, 0, 0], KneeL: [-12, 0, 0], Tail1: [6, 0, 0]};
const HOWL = {RootJoint: [12, 0, 0], Neck: [56, 0, 0], Head: [30, 0, 0], Jaw: [-40, 0, 0], LegL: [-8, 0, 0], LegR: [-8, 0, 0], Tail1: [-12, 0, 0]};
const DISPLAY = {RootJoint: [22, 0, 0], LegL: [-20, 0, 0], LegR: [-20, 0, 0], KneeL: [-10, 0, 0], KneeR: [-10, 0, 0], ArmL: [60, 30, 40], ArmR: [60, -30, -40], Neck: [20, 0, 0], Head: [-4, 0, 0], Jaw: [-34, 0, 0], Tail1: [-18, 0, 0]};
const HEADLOW = {RootJoint: [-8, 0, 0], Neck: [-20, 0, 0], Head: [-8, 0, 0], LegL: [8, 0, 0], LegR: [8, 0, 0], KneeL: [-8, 0, 0], KneeR: [-8, 0, 0]};
const PAW = {ArmR: [40, 0, 0]}, PAW_DN = {ArmR: [-24, 0, 0]};
const LIGER = {RootJoint: [-10, 0, 0], Neck: [-18, 0, 0], Head: [-10, 0, 0], ArmL: [10, 16, 10], ArmR: [10, -16, -10], LegL: [16, 10, 0], LegR: [16, -10, 0], KneeL: [-18, 0, 0], KneeR: [-18, 0, 0], Tail1: [6, 0, 0]};
const HUNKER = {RootJoint: [-6, 0, 0], LegL: [40, 0, 0], LegR: [40, 0, 0], KneeL: [-62, 0, 0], KneeR: [-62, 0, 0], AnkleL: [22, 0, 0], AnkleR: [22, 0, 0], ArmL: [-30, 0, 0], ArmR: [-30, 0, 0], Neck: [-14, 0, 0], Head: [-6, 0, 0], Tail1: [14, 0, 0], Tail2: [6, 0, 0]};
const PUSH = {RootJoint: [-4, 0, 0], Neck: [-6, 0, 0], ArmL: [30, 0, 0], ArmR: [30, 0, 0], LegL: [24, 0, 0], LegR: [-10, 0, 0], KneeL: [-24, 0, 0]};
const POUNCE = {RootJoint: [-16, 0, 0], LegL: [-40, 0, 0], LegR: [-40, 0, 0], KneeL: [-10, 0, 0], KneeR: [-10, 0, 0], AnkleL: [-20, 0, 0], AnkleR: [-20, 0, 0], ArmL: [70, 0, 0], ArmR: [70, 0, 0], Neck: [-6, 0, 0], Jaw: [-20, 0, 0], Tail1: [-6, 0, 0], Tail2: [-4, 0, 0]};
const LOWCROUCH = {RootJoint: [-14, 0, 0], LegL: [40, 0, 0], LegR: [40, 0, 0], KneeL: [-66, 0, 0], KneeR: [-66, 0, 0], AnkleL: [24, 0, 0], AnkleR: [24, 0, 0], ArmL: [-6, 0, 0], ArmR: [-6, 0, 0], Neck: [-14, 0, 0], Tail1: [6, 0, 0]};
const FRONTLAND = {RootJoint: [-22, 0, 0], ArmL: [-30, 0, 0], ArmR: [-30, 0, 0], Neck: [-18, 0, 0], LegL: [-10, 0, 0], LegR: [-10, 0, 0], Tail1: [-20, 0, 0], Tail2: [-10, 0, 0]};
const TAILPRESS = {RootJoint: [14, 0, 0], LegL: [-8, 0, 0], LegR: [-8, 0, 0], KneeL: [-30, 0, 0], KneeR: [-30, 0, 0], Tail1: [30, 0, 0], Tail2: [26, 0, 0], Tail3: [18, 0, 0], Tail4: [10, 0, 0], ArmL: [30, 0, 0], ArmR: [30, 0, 0]};
const TAILFLICK = {RootJoint: [20, 0, 0], LegL: [-30, 0, 0], LegR: [-30, 0, 0], Tail1: [-30, 0, 0], Tail2: [-20, 0, 0], Tail3: [-14, 0, 0], ArmL: [50, 0, 0], ArmR: [50, 0, 0], Neck: [10, 0, 0]};
const HINDLAND = {RootJoint: [16, 0, 0], LegL: [20, 0, 0], LegR: [20, 0, 0], KneeL: [-40, 0, 0], KneeR: [-40, 0, 0], ArmL: [40, 0, 0], ArmR: [40, 0, 0], Neck: [6, 0, 0], Tail1: [20, 0, 0], Tail2: [10, 0, 0]};

// ---------- v0.2 FX ----------
const ROCK = mk(new THREE.DodecahedronGeometry(1, 0), new THREE.MeshLambertMaterial({color: 0x8a8478, map: studTex}));
const CASING = mk(new THREE.CylinderGeometry(0.3, 0.3, 0.9, 10), new THREE.MeshPhongMaterial({color: 0xc9a24a, specular: 0xaaaaaa, shininess: 60}));
const SMOKES = []; for (let i = 0; i < 10; i++) SMOKES.push(mk(BALL, new THREE.MeshLambertMaterial({color: 0xb9bdc4, transparent: true, opacity: 0.6, depthWrite: false})));
function smoke(pos, dir, k, n, spread) { for (let i = 0; i < (n || 6); i++) { const m = SMOKES[i]; if (k <= 0 || k >= 1) continue; m.visible = true; m.position.copy(pos).addScaledVector(dir, k * (1.5 + i * 0.5)).add(new THREE.Vector3(((i * 7) % 5 - 2) * 0.3 * (spread || 1) * k, k * (0.5 + (i % 3) * 0.3), ((i * 3) % 5 - 2) * 0.3 * (spread || 1) * k)); m.scale.setScalar(0.6 + k * 1.8); m.material.opacity = 0.6 * (1 - k); } }
const GRINGS = [0, 1, 2].map(() => { const m = mk(new THREE.RingGeometry(0.9, 1, 64), new THREE.MeshBasicMaterial({color: 0x3d9bff, transparent: true, opacity: 0.9, side: THREE.DoubleSide, depthWrite: false})); m.rotation.x = -Math.PI / 2; return m; });
function gring(i, pos, k, R, color) { const m = GRINGS[i]; m.visible = k > 0 && k < 1; if (!m.visible) return; m.position.copy(pos).setY(0.12); m.scale.setScalar(0.5 + R * easeOut(k)); m.material.color.setHex(color || 0x3d9bff); m.material.opacity = 0.9 * (1 - k * k); }
const CRACK2 = []; for (let i = 0; i < 10; i++) CRACK2.push(mk(BOX, new THREE.MeshBasicMaterial({color: 0x3d9bff})));
function cracksFwd(from, k, len, spreadDeg) { CRACK2.forEach((m, i) => { if (k <= 0 || k >= 1.4) { m.visible = false; return; } const a = rad(-spreadDeg / 2 + spreadDeg * i / 9), L = len * Math.min(1, k) * (0.6 + 0.4 * ((i * 7) % 5) / 4); m.visible = true; m.position.set(from.x + Math.sin(a) * L / 2, 0.05, from.z - Math.cos(a) * L / 2); m.rotation.set(0, -a, 0); m.scale.set(0.18, 0.05, L); m.material.opacity = 1; }); }
const CONE2 = mk(new THREE.CircleGeometry(1, 40, Math.PI / 2 - 0.35, 0.7), new THREE.MeshBasicMaterial({color: 0x3d9bff, transparent: true, opacity: 0.3, side: THREE.DoubleSide, depthWrite: false})); CONE2.rotation.x = -Math.PI / 2;
const MARKS = [0, 1, 2].map(() => label("!", "#ffd34d"));
const HEALS = [0, 1].map(() => label("+HEAL", "#7dffb0", 384));
const DARTS2 = [0, 1, 2].map(() => mk(BOX, new THREE.MeshBasicMaterial({color: 0xff5a4e})));
const SPARK2 = []; for (let i = 0; i < 16; i++) SPARK2.push(mk(BOX, new THREE.MeshBasicMaterial({color: 0xcda0ff, transparent: true, opacity: 1, depthWrite: false})));
function sparks2(n0, pos, k) { for (let j = 0; j < 8; j++) { const m = SPARK2[n0 * 8 + j]; if (k <= 0 || k >= 1) continue; const a = j / 8 * Math.PI * 2; const o = pos.clone().add(new THREE.Vector3(Math.cos(a) * k * 2, Math.sin(a * 1.3) * k * 1.4, Math.sin(a) * k * 0.6)); setSeg(m, o.clone().lerp(pos, 0.5), o, 0.1); m.material.opacity = 1 - k; } }
const STEAMS = []; for (let i = 0; i < 8; i++) STEAMS.push(mk(BALL, new THREE.MeshLambertMaterial({color: 0xf2f4f8, transparent: true, opacity: 0.6, depthWrite: false})));
function steamAt(i0, pos, k, up) { for (let i = 0; i < 4; i++) { const m = STEAMS[i0 * 4 + i]; if (k <= 0 || k >= 1) continue; m.visible = true; m.position.copy(pos).add(new THREE.Vector3(((i * 5) % 3 - 1) * 0.4, k * (up || 2.5) * (0.6 + i * 0.2), ((i * 3) % 3 - 1) * 0.4)); m.scale.setScalar(0.3 + k * 1.1); m.material.opacity = 0.6 * (1 - k); } }
const GDOME = mk(new THREE.SphereGeometry(1, 32, 16, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshBasicMaterial({color: 0x3ddc84, transparent: true, opacity: 0.18, side: THREE.DoubleSide, depthWrite: false}));
const PRING = mk(new THREE.TorusGeometry(1, 0.08, 6, 48), new THREE.MeshBasicMaterial({color: 0xcda0ff, transparent: true, opacity: 0.9, depthWrite: false}));
function pieceAt(role) { const e = equip.find(x => x.role === role); if (!e) return new THREE.Vector3(); rig.updateMatrixWorld(true); return new THREE.Vector3().setFromMatrixPosition(e.mesh.matrix).applyMatrix4(rig.matrixWorld); }
function arcPos(a, b, k, peak) { const p = lerpV(a, b, clamp01(k)); p.y += Math.sin(clamp01(k) * Math.PI) * peak; return p; }
const ENEMY = 0x9b2c22, ALLY = 0x2f8f6a;

// ---------- Boulder Mortar (Back Cannon) ----------
const MORT_T = new THREE.Vector3(1.5, 0, -30); // the target raptor (60 studs ahead)
function mortarScene(tt, tFire, tHit, peak, from) {
  const R = raptor; const hitK = tt - tHit;
  if (tt < tHit) raptorPose({pos: MORT_T, yaw: Math.PI, run: tt * 3, runAmt: 0.15, color: ENEMY});
  else raptorPose({pos: MORT_T, yaw: Math.PI, lie: hitK < 1.2 ? 1 : 1 - clamp01((hitK - 1.2) / 0.4), flash: hitK < 0.08, color: ENEMY});
  if (tt >= tFire && tt < tHit) { if (!st.rockFrom) st.rockFrom = from(); ROCK.visible = true; ROCK.position.copy(arcPos(st.rockFrom, MORT_T.clone().setY(1.5), seg(tt, tFire, tHit), peak)); ROCK.rotation.set(tt * 7, tt * 5, 0); ROCK.scale.setScalar(1.1); }
  if (tt < tFire) st.rockFrom = null;
  if (hitK > 0) { puffs(MORT_T, clamp01(hitK / 0.7), 4, 12); burst(MORT_T.clone().setY(0.2), clamp01(hitK / 0.45), 0xff8a1a, 6, true); pop(NUM.dmg, MORT_T, clamp01(hitK / 1.1)); }
}
const VM = {}; // move id -> {now, A, B, C}
VM.tmortar = {
  now: {name: "Now", sub: "as the game plays it (v465)", len: 3.2, timing: "fire 0.55 s after the press",
    ref: "Big wind-up + whip (Kepu 2026-11-02), from when the boulder came off the tail; since v460 it leaves the Back Cannon.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.8, "Crouch · the tail curls down low behind"], [0.8, 0.9, "The tail cracks up over the back"], [0.85, 1.0, "…and the boulder pops out of the cannon"], [1.0, 2.05, "The boulder flies"], [2.05, 3.2, "Hit · the raptor goes down"]],
    notes: ["The tail does a big whip, but the boulder comes out of the back cannon: the two don't match, so it reads as a tail throw from nowhere.", "The cannon barely moves: no aim, no kick, no smoke."],
    update(tt) { const A0 = IDLE(tt); pose(AT(tt, [[PRESS, A0], [0.8, G_COIL, sm2], [0.9, G_WHIP, easeIn], [1.05, G_WHIP], [1.75, A0, sm2]])); lookU("mortar", tt > PRESS && tt < 1.4 ? 1 : 0, tt - 0.85 + 1.12);
      mortarScene(tt, 0.85, 2.05, 14, () => pieceAt("muzzle")); }},
  A: {name: "A · Anchored Shot", sub: "brace, aim, BOOM with recoil", len: 3.4, rec: true, timing: "fire 0.70 s after the press",
    ref: "Anchored Attack Stance (TV Tropes): C&C Juggernaut walkers and Warframe's Voidrig plant themselves before firing big guns; Zoids Gordos carries its guns on its back.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.65, "Brace · legs spread, tail drops flat as an anchor, barrel swings up to aim"], [0.65, 1.0, "Charge · red rings fill up the barrel"], [1.0, 1.15, "BOOM · recoil shoves the body back, smoke, a casing flies out"], [1.15, 2.1, "The boulder flies"], [2.1, 3.4, "Hit · the raptor goes down · the stance lifts"]],
    notes: ["Every part of the body tells you it's a cannon shot: the stance, the aim, the kick.", "The tail stays on the ground as the anchor, so nothing whips around for no reason.", "Game change: TenoPose's mortar poses + the release moves from 0.55 s to 0.70 s after the press."],
    update(tt) { const A0 = IDLE(tt); let P = AT(tt, [[PRESS, A0], [0.65, ANCHOR, sm2], [1.0, ANCHOR], [1.06, plus(ANCHOR, KICK), easeOut], [1.4, ANCHOR, sm2], [2.2, ANCHOR], [2.8, A0, sm2]]);
      pose(P); rig.position.z = 0.7 * (tt > 1.0 ? Math.exp(-(tt - 1.0) * 5) * Math.min(1, (tt - 1.0) / 0.04) : 0);
      lookU("mortar", sm2(seg(tt, PRESS, 0.65)) * (tt < 2.6 ? 1 : 0), tt - 1.0 + 1.12);
      if (tt > 1.0) { const k = (tt - 1.0) / 0.9; smoke(pieceAt("muzzle"), new THREE.Vector3(0, 0.6, -0.8).normalize(), k, 8, 1.4);
        if (tt < 1.7) { CASING.visible = true; const c0 = partNow("Torso_barrel").add(new THREE.Vector3(2.2, 1.5, 0)); const u = tt - 1.0; CASING.position.copy(c0).add(new THREE.Vector3(u * 6, 5 * u - 12 * u * u, u * 2)); CASING.position.y = Math.max(0.3, CASING.position.y); CASING.rotation.set(u * 14, 0, u * 9); } }
      if (tt > 1.0 && tt < 1.6) puffs(partNow("Tail4_main").setY(0), (tt - 1.0) / 0.6, 2, 6);
      mortarScene(tt, 1.0, 2.1, 14, () => pieceAt("muzzle")); }},
  B: {name: "B · Quick Lob", sub: "barrel snaps up, fire on the move", len: 3.0, timing: "fire 0.30 s after the press",
    ref: "Horizon Zero Dawn Ravager Cannon (a short charge-up, then the shot) and tank-style turret recoil: only the gun moves.",
    phases: [[0, PRESS, "Ready (you can keep walking)"], [PRESS, 0.5, "The barrel snaps up and a quick charge glows"], [0.6, 0.72, "Fire · the barrel kicks back, puff of smoke"], [0.72, 1.7, "The boulder flies"], [1.7, 3.0, "Hit · the raptor goes down"]],
    notes: ["The fastest and the least in the way: your body barely moves, only the cannon fires.", "Less weight than A: it reads as a gun shot, not a siege cannon.", "Game change: release from 0.55 s to 0.30 s after the press (faster), TenoPose plays only a small flinch."],
    update(tt) { const A0 = IDLE(tt); pose(AT(tt, [[0.6, A0], [0.66, plus(A0, {RootJoint: [4, 0, 0], Neck: [4, 0, 0]}), easeOut], [1.0, A0, sm2]]));
      lookU("mortar", tt > PRESS ? sm2(seg(tt, PRESS, 0.45)) * (tt < 1.6 ? 1 : 1 - seg(tt, 1.6, 2.0)) : 0, tt - 0.6 + 1.12);
      if (tt > 0.6) smoke(pieceAt("muzzle"), new THREE.Vector3(0, 0.6, -0.8).normalize(), (tt - 0.6) / 0.7, 5, 0.8);
      mortarScene(tt, 0.6, 1.7, 14, () => pieceAt("muzzle")); }},
  C: {name: "C · Rear-Up Mortar", sub: "rears up, fires sky-high", len: 3.6, timing: "fire 0.60 s after the press",
    ref: "A real mortar fires almost straight up so the shell drops on the target; Horizon's Behemoth rears up before its big moves.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.85, "Rears up on the hind legs, the back cannon points at the sky"], [0.9, 1.0, "FIRE straight up · smoke"], [1.0, 1.35, "Drops back down on all fours · dust"], [1.0, 2.5, "The boulder goes sky-high and drops"], [2.5, 3.6, "It lands on the raptor from above"]],
    notes: ["The most dramatic: the boulder visibly rises and comes straight down, so the raptor sees it coming (shadow).", "Slower to land (about 1.6 s of flight).", "Game change: TenoPose rear-up + release at 0.60 s, and the server flight time grows (1.0 s → 1.6 s)."],
    update(tt) { const A0 = IDLE(tt); pose(AT(tt, [[PRESS, A0], [0.85, plus(G_REAR, {RootJoint: [14, 0, 0]}), sm2], [0.95, plus(G_REAR, {RootJoint: [18, 0, 0]})], [1.3, G_STOMP2, easeIn], [2.0, A0, sm2]]));
      lookU("mortar", tt > PRESS && tt < 2.2 ? 1 : 0, tt - 0.9 + 1.12);
      if (tt > 0.9) smoke(pieceAt("muzzle"), new THREE.Vector3(0, 1, 0.2).normalize(), (tt - 0.9) / 0.8, 6, 1);
      if (tt > 1.28 && tt < 1.9) puffs(new THREE.Vector3(0, 0, -3), (tt - 1.28) / 0.6, 3, 8);
      mortarScene(tt, 0.9, 2.5, 34, () => pieceAt("muzzle")); }},
};

// ---------- Stomp Shockwave (Quake Hooves) ----------
const STOMP_R = 9; // ring radius (units)
function stompScene(tt, tHit, wave) {
  const k = tt - tHit, foes = [[raptor, new THREE.Vector3(6, 0, -12)], [raptor2, new THREE.Vector3(-7, 0, -10)]];
  foes.forEach(([Rp, p0], i) => { const hit = k > 0.05 * (i + 1); const away = p0.clone().setY(0).normalize();
    if (!hit) raptorPose({R: Rp, pos: p0, yaw: Math.atan2(-p0.x, -p0.z) + Math.PI, run: tt * 3, runAmt: 0.15, color: ENEMY});
    else { const u = clamp01((k - 0.05) / 0.5); raptorPose({R: Rp, pos: p0.clone().addScaledVector(away, 4 * easeOut(u)).setY(Math.sin(u * Math.PI) * 1.5), yaw: Math.atan2(-p0.x, -p0.z) + Math.PI, lie: k < 1.4 ? Math.min(1, u * 2) : 1 - clamp01((k - 1.4) / 0.4), flash: k < 0.15, color: ENEMY}); } });
  if (k > 0) { const c = partNow("ArmL_hand").lerp(partNow("ArmR_hand"), 0.5).setY(0); gring(0, c, clamp01(k / 0.6), STOMP_R); gring(1, c, clamp01((k - 0.1) / 0.6), STOMP_R * 0.7); puffs(c, clamp01(k / 0.8), 4, 12); if (wave) cracksFwd(c, k / 0.45, 12, 40); }
}
VM.tstomp = {
  now: {name: "Now", sub: "as the game plays it", len: 3.0, timing: "hit 0.50 s after the press",
    ref: "Horizon Zero Dawn Behemoth \"Quake Smash\" (the Quake Hooves' reference): rears up and smashes down.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.7, "Rears up"], [0.7, 0.8, "Stomps down"], [0.8, 1.1, "Shockwave ring · raptors knocked back"], [1.1, 3.0, "Recover"]],
    notes: ["It already reads, but it's small: a quick rear and a flat stomp, no pause at the top, no weight on the landing.", "The resonator rings spin but nothing builds up before the hit."],
    update(tt) { const A0 = IDLE(tt); pose(AT(tt, [[PRESS, A0], [0.7, G_REAR, sm2], [0.8, G_STOMP2, easeIn], [1.1, G_STOMP2], [2.0, A0, sm2]])); lookU("stomp", tt > PRESS && tt < 2 ? 1 : 0, tt - 0.8 + 1.06); stompScene(tt, 0.8); }},
  A: {name: "A · Quake Smash", sub: "higher rear, hang, crushing slam", len: 3.2, rec: true, timing: "hit 0.60 s after the press",
    ref: "Horizon Zero Dawn Behemoth \"Quake Smash\": \"rears up and smashes down, sending a forward-moving seismic shockwave\".",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.68, "Rears up HIGH, the resonator rings spin up"], [0.68, 0.82, "Hangs at the top (the tell)"], [0.82, 0.9, "SMASH · both hooves, the body drops with it"], [0.9, 1.3, "Shockwave ring + cracks racing forward · raptors thrown"], [1.3, 3.2, "Stands back up"]],
    notes: ["The hang at the top is the warning everyone can read, and the slam has weight (the whole body drops).", "Forward cracks show where the shockwave goes.", "Game change: TenoPose stomp poses + the hit moves from 0.50 s to 0.60 s after the press."],
    update(tt) { const A0 = IDLE(tt); pose(AT(tt, [[PRESS, A0], [0.68, REAR_HI, sm2], [0.82, plus(REAR_HI, {RootJoint: [3, 0, 0]})], [0.9, SMASH, easeIn], [1.25, SMASH], [2.1, A0, sm2]]));
      rig.position.y = tt > 0.9 && tt < 1.2 ? -0.35 * Math.sin(seg(tt, 0.9, 1.2) * Math.PI) : 0;
      lookU("stomp", tt > PRESS && tt < 2.1 ? 1 : 0, tt - 0.9 + 1.06); stompScene(tt, 0.9, true); }},
  B: {name: "B · Ground Pound", sub: "hop up, tuck, slam down", len: 3.0, timing: "hit 0.50 s after the press",
    ref: "Super Mario 64's Ground Pound: jump, freeze for a beat in the air, then drop straight down.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.6, "A short hop, legs tucked"], [0.6, 0.7, "Hangs in the air"], [0.7, 0.8, "Drops straight down"], [0.8, 1.2, "All four feet hit · big ring · raptors thrown"], [1.2, 3.0, "Recover"]],
    notes: ["Very readable and fun, the same timing as now.", "The whole dino leaves the ground (~3 studs), so it looks lighter than a rear-up."],
    update(tt) { const A0 = IDLE(tt); pose(AT(tt, [[PRESS, A0], [0.42, SQUAT, sm2], [0.6, TUCK, easeOut], [0.7, TUCK], [0.8, SMASH, easeIn], [1.2, SMASH], [2.0, A0, sm2]]));
      rig.position.y = tt < 0.42 ? 0 : tt < 0.7 ? 1.6 * Math.sin(seg(tt, 0.42, 0.7) * Math.PI / 2) : tt < 0.8 ? 1.6 * (1 - easeIn(seg(tt, 0.7, 0.8))) : 0;
      lookU("stomp", tt > PRESS && tt < 2 ? 1 : 0, tt - 0.8 + 1.06); stompScene(tt, 0.8); }},
  C: {name: "C · Hoof Drum", sub: "left, right, left… BOOM", len: 3.2, timing: "hit 0.55 s after the press",
    ref: "Donkey Kong's Hand Slap: quick slaps on the ground in a rhythm, then the big one.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.48, "Left hoof slap (small ring)"], [0.48, 0.62, "Right hoof slap"], [0.62, 0.75, "Rears a little"], [0.75, 0.85, "BOOM · both hooves · the real shockwave"], [0.85, 3.2, "Recover"]],
    notes: ["The rhythm builds up to the hit, so you can feel it coming.", "Busier: three small rings before the real one could be read as three hits."],
    update(tt) { const A0 = IDLE(tt); pose(AT(tt, [[PRESS, A0], [0.38, plus(A0, SLAP_L), easeOut], [0.44, plus(A0, SLAP_DN), easeIn], [0.52, plus(A0, SLAP_R), easeOut], [0.58, plus(A0, SLAP_DN), easeIn], [0.75, plus(G_REAR, {RootJoint: [-12, 0, 0]}), sm2], [0.85, G_STOMP2, easeIn], [1.15, G_STOMP2], [2.0, A0, sm2]]));
      for (const [i, th] of [[2, 0.44]]) gring(i, partNow("ArmL_hand").setY(0), (tt - th) / 0.35, 2.5, 0x9fd0ff);
      if (tt > 0.58 && tt < 0.95) gring(1, partNow("ArmR_hand").setY(0), (tt - 0.58) / 0.35, 2.5, 0x9fd0ff);
      lookU("stomp", tt > PRESS && tt < 2 ? 1 : 0, tt - 0.85 + 1.06); stompScene(tt, 0.85); }},
};

// ---------- Herd Bellow (Shriek Sacs) ----------
function bellowScene(tt, tHeal) {
  const allies = [[raptor, new THREE.Vector3(-7, 0, -4)], [raptor2, new THREE.Vector3(8, 0, 4)]];
  allies.forEach(([Rp, p0], i) => { const k = tt - tHeal - 0.12 * i; raptorPose({R: Rp, pos: p0, yaw: Math.atan2(-p0.x, -p0.z) + Math.PI, run: tt * 3, runAmt: 0.15, color: k > 0 && k < 0.15 ? 0x7dffb0 : ALLY}); pop(HEALS[i], p0, clamp01(k / 1.2)); });
  if (tt > tHeal) { gring(0, new THREE.Vector3(0, 0, 0), clamp01((tt - tHeal) / 0.8), 12, 0x3ddc84); }
}
VM.tbellow = {
  now: {name: "Now", sub: "as the game plays it", len: 3.2, timing: "the call lands 0.50 s after the press",
    ref: "Horizon Zero Dawn Longleg's concussion sacs (the Shriek Sacs' reference).",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.8, "Head lifts, jaw opens"], [0.8, 2.0, "Holds the pose · sacs pump · green rings"], [2.0, 3.2, "Head comes down"]],
    notes: ["A long, static hold: the body stops for 1.2 s and nothing builds up before the call.", "The sacs pump the same way the whole time."],
    update(tt) { const A0 = IDLE(tt); pose(AT(tt, [[PRESS, A0], [0.8, G_BELLOW, sm2], [2.0, G_BELLOW], [2.6, A0, sm2]])); lookU("bellow", tt > 0.8 && tt < 2.0 ? 1 : 0); bellowScene(tt, 0.8); }},
  A: {name: "A · Concussion Shriek", sub: "inhale, sacs balloon, SHRIEK", len: 3.0, rec: true, timing: "the call lands 0.50 s after the press",
    ref: "Horizon Zero Dawn Longleg \"Stun Blast\": it shrieks at the target using its concussion sacs.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.7, "Inhale · head pulls back, the sacs balloon up"], [0.7, 0.8, "SHRIEK · head thrusts forward, sacs squeeze flat"], [0.8, 1.4, "Green rings blast out · allies heal"], [1.4, 3.0, "Sacs refill, head comes back"]],
    notes: ["A clear in-out: big breath in (sacs grow), then the push out (sacs shrink) is the moment it happens.", "Shorter hold (0.6 s instead of 1.2 s), so you're back in control sooner.", "Game change: TenoPose bellow poses, TenoPartsAnim sac size follows the inhale / shriek."],
    update(tt) { const A0 = IDLE(tt); pose(AT(tt, [[PRESS, A0], [0.7, INHALE, sm2], [0.8, SHRIEK, easeIn], [1.4, SHRIEK], [2.1, A0, sm2]]));
      const u = tt < PRESS ? 0 : tt < 0.7 ? sm2(seg(tt, PRESS, 0.7)) * 1.6 : tt < 0.8 ? 1.6 - 1.4 * seg(tt, 0.7, 0.8) : tt < 1.4 ? 0.9 : 0.9 * (1 - seg(tt, 1.4, 1.9));
      lookU("bellow", u, tt < 0.8 ? Math.PI / 12 : t); bellowScene(tt, 0.8); }},
  B: {name: "B · Sky Howl", sub: "head to the sky, three pulses", len: 3.4, timing: "the call lands 0.50 s after the press",
    ref: "A wolf's howl / Monster Hunter's Hunting Horn (its songs buff the whole team): the call goes up and comes down over everyone.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.8, "Head goes straight up"], [0.8, 2.0, "Three pulses: sacs squeeze, rings rise up"], [0.8, 2.0, "A green dome falls over the herd"], [2.0, 3.4, "Head comes down"]],
    notes: ["The dome shows exactly who gets healed.", "Same long hold as now (1.2 s)."],
    update(tt) { const A0 = IDLE(tt); pose(AT(tt, [[PRESS, A0], [0.8, HOWL, sm2], [2.0, HOWL], [2.6, A0, sm2]]));
      const pulse = tt > 0.8 && tt < 2.0 ? Math.max(0, Math.sin((tt - 0.8) / 0.4 * Math.PI)) : 0; lookU("bellow", tt > 0.8 && tt < 2 ? 0.4 + 0.6 * pulse : 0);
      if (tt > 0.8 && tt < 2.4) { GDOME.visible = true; GDOME.position.set(0, 0, 0); GDOME.scale.setScalar(12 * easeOut(seg(tt, 0.8, 1.3))); GDOME.material.opacity = 0.18 * (1 - seg(tt, 2.0, 2.4)); }
      bellowScene(tt, 0.9); }},
  C: {name: "C · Rally Sweep", sub: "sweeps the call left to right", len: 3.2, timing: "the call lands 0.50 s after the press",
    ref: "Monster Hunter's Hunting Horn performance: the player swings the horn round while playing so the song reaches everyone.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.8, "Head lifts, turns to the left"], [0.8, 1.9, "Bellows while sweeping left → right · rings fan out"], [1.9, 3.2, "Head comes back"]],
    notes: ["Shows the call going round you (it heals all around).", "Your head turns away from where you're looking for about a second."],
    update(tt) { const A0 = IDLE(tt); const sw = tt < 0.8 ? -30 * sm2(seg(tt, PRESS, 0.8)) : tt < 1.9 ? -30 + 60 * sm2(seg(tt, 0.8, 1.9)) : 30 * (1 - sm2(seg(tt, 1.9, 2.5)));
      pose(plus(AT(tt, [[PRESS, A0], [0.8, G_BELLOW, sm2], [1.9, G_BELLOW], [2.5, A0, sm2]]), {Neck: [0, sw, 0], RootJoint: [0, sw * 0.3, 0]})); lookU("bellow", tt > 0.8 && tt < 1.9 ? 1 : 0); bellowScene(tt, 0.8); }},
};

// ---------- Challenge Call (Alarm Beacon) ----------
const CH_FOES = [new THREE.Vector3(9, 0, -14), new THREE.Vector3(-10, 0, -12), new THREE.Vector3(14, 0, -2)];
function chalScene(tt, tCall, turnAt) {
  [raptor, raptor2, raptor3].forEach((Rp, i) => { const p0 = CH_FOES[i], toMe = Math.atan2(-p0.x, -p0.z) + Math.PI, away = toMe + Math.PI * 0.7;
    const k = tt - (turnAt ? turnAt[i] : tCall); const yaw = k > 0 ? lerp(away, toMe, easeOut(clamp01(k / 0.3))) : away;
    raptorPose({R: Rp, pos: p0, yaw, run: tt * 3, runAmt: 0.15, color: ENEMY, flash: k > 0 && k < 0.08}); pop(MARKS[i], p0, k > 0 ? Math.min(0.55, k / 1.4) : -1, 0.6); });
}
VM.tchallenge = {
  now: {name: "Now", sub: "as the game plays it", len: 3.0, timing: "the call lands 0.50 s after the press",
    ref: "The mockup v0.3 \"painter's turn\" (a small head lift).",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.8, "Head lifts a little"], [0.8, 1.7, "Holds · antennae up, the beacon spins and flashes"], [1.7, 3.0, "Head comes down"]],
    notes: ["The body barely does anything, so it doesn't look like a challenge.", "You can't tell which raptors got called."],
    update(tt) { const A0 = IDLE(tt); pose(AT(tt, [[PRESS, A0], [0.8, mix({}, G_BELLOW, 0.4), sm2], [1.7, mix({}, G_BELLOW, 0.4)], [2.3, A0, sm2]])); lookU("chal", tt > PRESS && tt < 1.9 ? 1 : 0); chalScene(tt, 0.8); }},
  A: {name: "A · Watcher Alarm", sub: "snap to the enemy, scan, alarm", len: 3.2, rec: true, timing: "the call lands 0.50 s after the press",
    ref: "Horizon Zero Dawn Watcher: its head snaps toward a threat, the eye scans, then it raises the alarm for the herd (the Alarm Beacon's family).",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.5, "Head snaps toward the nearest raptor, antennae spring up"], [0.5, 0.95, "A blue scan cone sweeps across them · each one pinged (!)"], [0.95, 1.6, "ALARM · the beacon spins fast and flashes · they all turn to you"], [1.6, 3.2, "Head comes back"]],
    notes: ["You see who got called: the cone passes over them and they turn.", "Quick snap at the start, so the move reads at once.", "Game change: TenoPose head-turn toward the target + the cone FX; the server picks the same targets."],
    update(tt) { const A0 = IDLE(tt); const yaw = -26 * (tt < PRESS ? 0 : tt < 0.5 ? easeOut(seg(tt, PRESS, 0.5)) : tt < 0.95 ? 1 - 2 * sm2(seg(tt, 0.5, 0.95)) : -1 + sm2(seg(tt, 1.6, 2.2)));
      pose(plus(AT(tt, [[PRESS, A0], [0.5, mix({}, G_BELLOW, 0.3), easeOut], [1.6, mix({}, G_BELLOW, 0.5)], [2.2, A0, sm2]]), {Neck: [0, yaw, 0], Head: [0, yaw * 0.5, 0]}));
      lookU("chal", tt > PRESS && tt < 1.9 ? (tt > 0.95 ? 1 : 0.5) : 0);
      if (tt > 0.5 && tt < 0.95) { CONE2.visible = true; const hd = partNow("Head_cranium"); CONE2.position.set(hd.x, 0.15, hd.z); CONE2.scale.setScalar(22); CONE2.rotation.set(-Math.PI / 2, 0, rad(-60 + 120 * sm2(seg(tt, 0.5, 0.95)))); }
      chalScene(tt, 0.95, [0.62, 0.86, 0.95]); if (tt > 0.95) gring(0, new THREE.Vector3(0, 0, -1), clamp01((tt - 0.95) / 0.7), 16, 0x3d9bff); }},
  B: {name: "B · Threat Display", sub: "rears tall, arms wide, roars", len: 3.0, timing: "the call lands 0.50 s after the press",
    ref: "Real animal threat displays (a frilled lizard spreading its frill, a bear standing tall): look as big as possible to pull attention.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.8, "Rears tall, arms spread wide, jaw open"], [0.8, 1.5, "The beacon flares · a big blue pulse · they all turn"], [1.5, 3.0, "Drops back down"]],
    notes: ["Very clear \"look at me\" body language.", "Rearing makes the move feel slow and leaves your belly open."],
    update(tt) { const A0 = IDLE(tt); pose(AT(tt, [[PRESS, A0], [0.8, DISPLAY, sm2], [1.5, DISPLAY], [2.1, A0, sm2]])); lookU("chal", tt > 0.6 && tt < 1.7 ? 1 : 0);
      chalScene(tt, 0.85); if (tt > 0.8) gring(0, new THREE.Vector3(0, 0, -1), clamp01((tt - 0.8) / 0.7), 16, 0x3d9bff); }},
  C: {name: "C · Bull Paw", sub: "paws the ground, snorts, calls", len: 3.2, timing: "the call lands 0.50 s after the press",
    ref: "A bull pawing the ground before it charges: everyone knows what's coming.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.85, "Head down, the front hoof paws the ground twice · dust · steam snorts"], [0.85, 1.5, "Beacon flashes with each paw · they turn to face you"], [1.5, 3.2, "Head comes up"]],
    notes: ["Reads as \"come at me\" without rearing up, and you keep looking ahead.", "Small: from far away only the dust and the beacon show."],
    update(tt) { const A0 = IDLE(tt); const paw = tt > PRESS && tt < 1.1 ? Math.max(0, Math.sin((tt - PRESS) / 0.4 * Math.PI * 2)) : 0;
      pose(plus(AT(tt, [[PRESS, A0], [0.5, plus(A0, HEADLOW), sm2], [1.5, plus(A0, HEADLOW)], [2.1, A0, sm2]]), mix(PAW_DN, PAW, paw)));
      lookU("chal", tt > 0.5 && tt < 1.8 ? 1 : 0);
      for (const [i, th] of [[0, 0.5], [1, 0.9]]) { if (tt > th && tt < th + 0.6) puffs(partNow("ArmR_hand").setY(0), (tt - th) / 0.6, 1.5, 4); if (tt > th) steamAt(i, partNow("Head_snout"), (tt - th) / 0.6, 1.2); }
      chalScene(tt, 0.85, [0.55, 0.95, 0.95]); }},
};

// ---------- Hydraulic Leap (Chicken-Leg Rams, on JUMP) ----------
function leapPath(tt, t0, t1, dist, peak) { const u = seg(tt, t0, t1); return {u, z: -dist * u, y: tt > t0 && tt < t1 ? Math.sin(u * Math.PI) * peak : 0}; }
function leapScene(tt, tLand, z) { const p = new THREE.Vector3(0, 0, z); if (tt > tLand) { gring(0, p, clamp01((tt - tLand) / 0.6), 6, 0xffc21a); puffs(p, clamp01((tt - tLand) / 0.8), 4, 12); }
  const p0 = new THREE.Vector3(5, 0, z - 3); const k = tt - tLand; raptorPose({pos: k > 0.05 ? p0.clone().add(new THREE.Vector3(3 * easeOut(clamp01(k / 0.4)), 0, 0)) : p0, yaw: -Math.PI / 2, lie: k > 0.05 ? (k < 1.3 ? 1 : 1 - clamp01((k - 1.3) / 0.4)) : 0, flash: k > 0 && k < 0.1, run: tt * 3, runAmt: 0.15, color: ENEMY}); }
VM.tleap = {
  now: {name: "Now", sub: "as the game plays it (v461 landing fix)", len: 3.2, timing: "JUMP · lands ~1.0 s later",
    ref: "Rearing leap J2 (Kepu 2026-10-31 \"I want the second leap\") + the landing tail slam.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.55, "Rears up (the crouch)"], [0.55, 1.55, "In the air"], [1.55, 1.7, "Lands · the tail slams down"], [1.7, 3.2, "Recover"]],
    notes: ["The take-off rears up instead of crouching, so the leg rams don't look like they push.", "The rams and the gauge barely show during the jump."],
    update(tt) { const A0 = IDLE(tt); const L = leapPath(tt, 0.55, 1.55, 12, 5); rig.position.set(0, L.y, tt > 1.55 ? -12 : L.z);
      pose(AT(tt, [[PRESS, A0], [0.55, G_JREAR, sm2], [0.95, G_JAIR, sm2], [1.55, G_JAIR], [1.67, G_SLAM2, easeIn], [1.85, G_SLAM2], [2.45, A0, sm2]]));
      lookU("leap", tt > PRESS && tt < 1.6 ? 1 : 0, tt < 0.55 ? (tt - PRESS) / 0.25 * 0.99 : 1.0); leapScene(tt, 1.55, -12); }},
  A: {name: "A · Piston Launch", sub: "deep crouch, rams fire, absorb", len: 3.4, rec: true, timing: "JUMP · lifts off 0.25 s later (as now)",
    ref: "Armored Core 6 reverse-joint legs (the Chicken-Leg Rams' reference): a deep crouch charges the jump, the legs fire like pistons.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.55, "Deep crouch · the rams squeeze, the gauge fills, the knee gears spin"], [0.55, 0.65, "The rams FIRE · steam blasts out"], [0.65, 1.55, "In the air, legs tucked"], [1.55, 1.75, "Lands on the rams (they squash) · dust ring"], [1.75, 1.95, "The tail slams"], [1.95, 3.4, "Stands up"]],
    notes: ["The parts do the work you see: squeeze → fire → squash.", "Same take-off timing as now (0.25 s), so nothing changes in how the jump plays.", "Game change: TenoPose leap poses (crouch, tuck, absorb), TenoPartsAnim ram squeeze + steam."],
    update(tt) { const A0 = IDLE(tt); const L = leapPath(tt, 0.6, 1.55, 12, 5.5); rig.position.set(0, L.y - (tt > 1.55 && tt < 1.8 ? 0.4 * Math.sin(seg(tt, 1.55, 1.8) * Math.PI) : 0), tt > 1.55 ? -12 : L.z);
      pose(AT(tt, [[PRESS, A0], [0.55, LOWCROUCH, sm2], [0.66, G_JAIR, easeOut], [0.95, TUCK, sm2], [1.45, TUCK], [1.55, G_JLAND, sm2], [1.72, SQUAT, easeOut], [1.88, plus(SQUAT, {Tail1: [24, 0, 0], Tail2: [12, 0, 0]}), easeIn], [2.6, A0, sm2]]));
      lookU("leap", tt > PRESS && tt < 1.9 ? 1 : 0, tt < 0.55 ? 0.99 * sm2(seg(tt, PRESS, 0.55)) : tt < 1.55 ? 1.05 : 0.99 * sm2(seg(tt, 1.55, 1.72)));
      if (tt > 0.55) { steamAt(0, partNow("FootL_meta"), (tt - 0.55) / 0.6, 2); steamAt(1, partNow("FootR_meta"), (tt - 0.58) / 0.6, 2); }
      if (tt > 0.55 && tt < 1.1) puffs(new THREE.Vector3(0, 0, 0), (tt - 0.55) / 0.55, 3, 8);
      leapScene(tt, 1.55, -12); }},
  B: {name: "B · Pounce", sub: "low and long, lands front-first", len: 3.2, timing: "JUMP · lifts off 0.20 s later",
    ref: "A raptor's pounce (the game's own Pounce, and Path of Titans' pounce update): low, long and front-first.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.5, "Low crouch, head down"], [0.5, 1.35, "Long flat leap, arms reaching forward"], [1.35, 1.5, "Lands front-first on the hooves · ring"], [1.5, 3.2, "Back up"]],
    notes: ["Feels fast and aggressive; the landing hits where you're looking.", "No tail slam, so the landing looks different from the old one."],
    update(tt) { const A0 = IDLE(tt); const L = leapPath(tt, 0.5, 1.35, 14, 3); rig.position.set(0, L.y, tt > 1.35 ? -14 : L.z);
      pose(AT(tt, [[PRESS, A0], [0.5, LOWCROUCH, sm2], [0.62, POUNCE, easeOut], [1.25, POUNCE], [1.38, FRONTLAND, easeIn], [1.6, FRONTLAND], [2.3, A0, sm2]]));
      lookU("leap", tt > PRESS && tt < 1.4 ? 1 : 0, tt < 0.5 ? 0.99 * sm2(seg(tt, PRESS, 0.5)) : 1.05); leapScene(tt, 1.35, -14); }},
  C: {name: "C · Spring Tail", sub: "tail pushes off like a spring", len: 3.4, timing: "JUMP · lifts off 0.30 s later",
    ref: "A kangaroo's tail (it pushes off with it) and Horizon's Rollerback hammer tail.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.6, "The tail presses into the ground, the body tips up"], [0.6, 0.7, "The tail flicks · launch"], [0.7, 1.65, "High arc"], [1.65, 1.85, "Lands on the hind legs · the tail slams"], [1.85, 3.4, "Recover"]],
    notes: ["Unusual and very \"teno\" (big tail).", "The rams on the legs aren't the ones doing the work here, so the part and the move don't match."],
    update(tt) { const A0 = IDLE(tt); const L = leapPath(tt, 0.65, 1.65, 11, 7); rig.position.set(0, L.y, tt > 1.65 ? -11 : L.z);
      pose(AT(tt, [[PRESS, A0], [0.6, TAILPRESS, sm2], [0.7, TAILFLICK, easeOut], [1.0, G_JAIR, sm2], [1.6, G_JAIR], [1.7, HINDLAND, easeIn], [1.85, G_SLAM2, easeIn], [2.6, A0, sm2]]));
      if (tt > 0.6 && tt < 1.2) puffs(partNow("Tail3_main").setY(0), (tt - 0.6) / 0.6, 2.5, 8);
      lookU("leap", 0); leapScene(tt, 1.65, -11); }},
};

// ---------- Shield Armor (Shield Mane) ----------
const SH_FOES = [new THREE.Vector3(8, 0, -22), new THREE.Vector3(-9, 0, -20)];
function shieldScene(tt, tUp, up, push) {
  SH_FOES.forEach((p0, i) => raptorPose({R: i ? raptor2 : raptor, pos: push && tt > push ? p0.clone().add(p0.clone().setY(0).normalize().multiplyScalar(3 * easeOut(clamp01((tt - push) / 0.4)))) : p0, yaw: Math.atan2(-p0.x, -p0.z) + Math.PI, run: tt * 3, runAmt: 0.15, color: ENEMY}));
  const disc = pieceAt("disc"), shots = [[0, 1.0], [1, 1.5], [0, 2.1]];
  shots.forEach(([fi, t0], j) => { const k = (tt - t0) / 0.4, from = SH_FOES[fi].clone().setY(3.5), m = DARTS2[j]; if (k < 0 || k > 1.6) return;
    const hitAt = up(t0 + 0.4) > 0.5 ? disc : partNow("Torso_chest"); if (k < 1) { m.visible = true; m.position.copy(lerpV(from, hitAt, k)); m.lookAt(hitAt); m.scale.set(0.2, 0.2, 1.2); } else sparks2(j % 2, hitAt, (k - 1) / 0.6); });
}
VM.tmud = {
  now: {name: "Now", sub: "as the game plays it", len: 3.2, timing: "shield up 0.20 s after the press",
    ref: "Zoids Shield Liger (the Shield Mane's reference): its shield generator sits in the mane.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.55, "Chest up, arms forward (brace)"], [0.5, 1.2, "Mane blades swing forward, purple disc"], [1.0, 2.6, "Shots hit the disc"], [1.2, 3.2, "The body relaxes, the shield stays"]],
    notes: ["The brace lifts the chest up, which looks like a bellow, not like hiding behind a shield.", "The disc sits in front of the chest while the head pokes out above it."],
    update(tt) { const A0 = IDLE(tt); pose(AT(tt, [[PRESS, A0], [0.55, G_BRACE, sm2], [1.2, G_BRACE], [1.7, A0, sm2]])); const up = x => x > 0.5 ? sm2(seg(x, 0.5, 0.65)) : 0; lookU("shield", up(tt)); shieldScene(tt, 0.5, up); }},
  A: {name: "A · Liger Guard", sub: "head down behind the mane", len: 3.2, rec: true, timing: "shield up 0.20 s after the press",
    ref: "Zoids Shield Liger: it lowers its head and the mane blades fan forward into the shield in front of it.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.5, "Head drops low, forelegs plant wide"], [0.4, 0.55, "The mane blades fan forward into a ring, the purple disc fills"], [1.0, 2.6, "Shots spark off the disc"], [0.55, 3.2, "Holds the guard while the shield lasts"]],
    notes: ["The head and chest are behind the disc, so it reads as \"protected\".", "Same shield-up timing as now.", "Game change: TenoPose shield pose (held while TenoMudUntil), TenoPartsAnim unchanged."],
    update(tt) { const A0 = IDLE(tt); pose(AT(tt, [[PRESS, A0], [0.5, plus(A0, LIGER), sm2]])); const up = x => x > 0.4 ? sm2(seg(x, 0.4, 0.55)) : 0; lookU("shield", up(tt)); shieldScene(tt, 0.4, up); }},
  B: {name: "B · Turtle Hunker", sub: "drops low, shield over the head", len: 3.2, timing: "shield up 0.20 s after the press",
    ref: "Horizon Forbidden West Shellsnapper: it pulls into its shell to soak hits.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.5, "Drops low to the ground, tail tucked"], [0.4, 0.55, "Mane closes over the head, disc"], [1.0, 2.6, "Shots spark off"], [0.55, 3.2, "Stays low while the shield lasts"]],
    notes: ["The most \"hiding\" look.", "Looks slow and defensive; the low body can look stuck."],
    update(tt) { const A0 = IDLE(tt); pose(AT(tt, [[PRESS, A0], [0.5, HUNKER, sm2]])); rig.position.y = -0.5 * sm2(seg(tt, PRESS, 0.5)); const up = x => x > 0.4 ? sm2(seg(x, 0.4, 0.55)) : 0; lookU("shield", up(tt)); shieldScene(tt, 0.4, up); }},
  C: {name: "C · Shield Pulse", sub: "shield forms with a push-wave", len: 3.2, timing: "shield up 0.20 s after the press",
    ref: "Overwatch Reinhardt's barrier / the Shield Liger: the shield snaps up with a pulse that shoves the air in front.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.5, "Shoulders forward, a short shove"], [0.45, 0.6, "The disc snaps up with a lilac pulse ring"], [0.6, 1.0, "The pulse pushes the raptors back a bit (look only)"], [1.0, 3.2, "Guard pose while the shield lasts · shots spark"]],
    notes: ["A clear \"shield ON\" moment.", "The push is only a look: the raptors don't really move in the game unless we add that."],
    update(tt) { const A0 = IDLE(tt); pose(AT(tt, [[PRESS, A0], [0.45, plus(A0, PUSH), easeOut], [0.9, plus(A0, mix({}, LIGER, 0.6)), sm2]])); const up = x => x > 0.45 ? sm2(seg(x, 0.45, 0.55)) : 0; lookU("shield", up(tt));
      if (tt > 0.45 && tt < 1.2) { PRING.visible = true; PRING.position.copy(pieceAt("disc")); PRING.rotation.set(0, 0, 0); PRING.scale.setScalar(1.5 + 9 * easeOut(seg(tt, 0.45, 1.2))); PRING.material.opacity = 0.9 * (1 - seg(tt, 0.45, 1.2)); }
      shieldScene(tt, 0.45, up, 0.6); }},
};
const MOVE_META = {
  tmortar: {area: "attack", part: "Back Cannon (turret, barrel, charge rings, ammo hopper)", partWhy: "The barrel lifts to aim, the red rings charge up it one by one, then it fires with a kick and a muzzle flash. Red = attack glow.", focus: new THREE.Vector3(0, 5, -10), side: 70, nums: "Numbers unchanged: only the animation and (A / B / C) the moment the boulder leaves change."},
  tstomp: {area: "defense", part: "Quake Hooves (boots, spinning resonators, forearm rams, shoulder exhausts)", partWhy: "The resonator rings spin up on the rear-up, the forearm rams punch at the slam and the shoulder stacks puff. Blue = defense glow.", focus: new THREE.Vector3(0, 4, -3), side: 52, nums: "Numbers unchanged: radius, damage and knock-back as now."},
  tbellow: {area: "health", part: "Shriek Sacs (two green sacs in iron cages on the neck)", partWhy: "The sacs pump and the green rings roll out of the mouth. Green = health glow.", focus: new THREE.Vector3(0, 5, -2), side: 50, nums: "Numbers unchanged: heal / buff and radius as now."},
  tchallenge: {area: "defense", part: "Alarm Beacon (head antennae + shoulder siren)", partWhy: "The antennae stand up and buzz, the siren light spins fast and flashes. Blue = defense glow.", focus: new THREE.Vector3(2, 5, -6), side: 60, nums: "Numbers unchanged: who gets called and for how long."},
  tleap: {area: "speed", part: "Chicken-Leg Rams (leg rams, knee gears, thigh gauge)", partWhy: "The gauge fills while crouching, the knee gears spin, the rams push. Yellow = speed glow.", focus: new THREE.Vector3(0, 5, -6), side: 62, nums: "Numbers unchanged: leap distance, slam damage and radius."},
  tmud: {area: "defense", part: "Shield Mane (ten blades round the neck + generators)", partWhy: "The mane blades swing forward into a ring and the purple disc fills it. Purple = the shield.", focus: new THREE.Vector3(0, 5, -8), side: 60, nums: "Numbers unchanged: shield time and what it blocks."},
};

const MOVES = [
  {id: "tgrab", name: "Tail Grab & Fling", area: "attack", variants: ["now", "A", "B", "C"],
    part: "Pincer Tail (armoured tail + two pincer blades)", partWhy: "The pincer blades open wide on the wind-up and snap shut on the raptor's back; the armour plates ride along. Red = attack glow on the plates' top line and the blade edges.",
    nums: "Unchanged numbers: 8 damage · stun 1 s · thrown 45 studs (TenoGrabFling) · reach 12 studs · recharge 16 s. Only the animation and when the catch / throw happen change."},
  ...["tmortar", "tstomp", "tbellow", "tchallenge", "tleap", "tmud"].map(id => Object.assign({id, name: {tmortar: "Boulder Mortar", tstomp: "Stomp Shockwave", tbellow: "Herd Bellow", tchallenge: "Challenge Call", tleap: "Hydraulic Leap", tmud: "Shield Armor"}[id], variants: ["now", "A", "B", "C"]}, MOVE_META[id])),
];
// the grab's versions as a move too; A is in the game since v465
VM.tgrab = V;
V.A.sub = "picked · in the game since v465"; V.A.rec = false; V.now.name = "Before"; V.now.sub = "v461 (before the pick)";
for (const id in VM) if (id !== "tgrab") for (const k in VM[id]) { const v = VM[id][k], ph = v.phases, tm = v.timing; v.phases = () => ph; v.timing = () => tm; }

// ---------- UI ----------
let cur = 1, playing = true, speed = 1, view = "side", tt = 0; // v0.2: opens on the Mortar
const M = () => MOVES[cur], VV = () => VM[M().id][variant];
function renderAll() {
  const VS = VM[M().id];
  $("moves").innerHTML = MOVES.map((m, i) => `<button class="tab" data-i="${i}" aria-pressed="${i === cur}">${m.name}<small style="color:${AREA[m.area][1]}">${m.id === "tgrab" ? "A picked · live" : "4 versions"}</small></button>`).join("");
  $("varRow").innerHTML = '<span class="lbl">Version</span>' + M().variants.map(k => `<button class="var" data-var="${k}" aria-pressed="${k === variant}">${VS[k].name}${VS[k].rec ? ' <span class="rec">· recommended</span>' : ""}<small>${VS[k].sub}</small></button>`).join("");
  document.querySelectorAll("[data-side]").forEach(x => x.parentElement && (x.style.display = M().id === "tgrab" ? "" : "none"));
  const v = VV(), ph = v.phases(side);
  $("phases").innerHTML = ph.map(p => `<button class="ph" data-t="${p[0]}" aria-current="false"><i>${p[0].toFixed(2)}–${p[1].toFixed(2)} s</i>${p[2]}</button>`).join("");
  const rows = M().variants.map(k => `<tr><th>${VS[k].name}</th><td>${VS[k].timing(side)}</td></tr>`).join("");
  const AR = AREA[M().area];
  $("info").innerHTML = `<div class="kind" style="color:${AR[1]}">${AR[0]} · ${M().name} · ${v.name}${M().id === "tgrab" ? " · target " + (side === "front" ? "in front" : "behind") : ""}</div><h2>What you see, in order</h2><ul>${ph.slice(1).map(p => `<li>${p[2]}</li>`).join("")}</ul><p class="note"><b>Borrowed from:</b> ${v.ref}</p><table class="cmp">${rows}</table><p class="note">${M().nums}</p>`;
  const notes = M().id === "tgrab" ? NOTES[variant] : `<h2 style="margin-top:6px">${variant === "now" ? "What's off about it now" : "What it does better · what it costs"}</h2><ul>${v.notes.map(n => `<li>${n}</li>`).join("")}</ul>`;
  $("part").innerHTML = `<div class="kind" style="color:${AR[1]}">The part that does it</div><h2>${M().part}</h2><p class="note">${M().partWhy}</p>${notes}`;
}
const NOTES = {
  now: `<h2 style="margin-top:6px">What's wrong with it now</h2><ul><li>In front, the tail can't reach over your head: it stops short (red line) and the raptor is <b>yanked</b> ~20 studs through the air into the jaws in 0.12 s.</li><li>Behind, it's yanked ~11 studs.</li><li>It's lifted ~32 studs high, much higher than the tail looks like it could hold it.</li><li>The throw misses its aim by up to ~6 studs, so the raptor pops away from the jaws when it's let go.</li></ul>`,
  A: `<h2 style="margin-top:6px">Why it fixes it</h2><ul><li>Your body tips nose-down (front) or rears back (behind), which lifts the tail base so the tail really reaches the raptor: no yank, the jaws close on it where it stands.</li><li>The lift only goes as high as the tail curls over your back (~21 studs), and the throw is a short, low slam-fling (~36 studs), so the raptor never leaves the jaws early.</li><li>You never turn: your camera and steering stay yours.</li></ul><p class="note">Game change: TenoPose's grab path (coil → strike → lift → slam) + the catch / throw times in TenoMovesServer. The 45-stud fling becomes ~36 for the front, ~30 for behind (or keep 45 with a higher arc).</p>`,
  B: `<h2 style="margin-top:6px">Why it fixes it</h2><ul><li>In front, you stomp round first so the tail sweeps low into the raptor: it's caught where it stands, no yank.</li><li>The spin is the clearest wind-up any throw can have: you see it coming and you see where it goes (always ahead of you, ~60 studs).</li><li>Cost: your body (and camera) turns for over a second, and it's the slowest.</li></ul><p class="note">Game change: the body turn needs the server to rotate the teno (TurnLimit off for 1.3 s) + a new TenoPose spin path.</p>`,
  C: `<h2 style="margin-top:6px">Why it fixes it</h2><ul><li>The pull is still there, but now you see what pulls it: the pincer head fires out on a chain, clamps on, and the chain reels it in.</li><li>Reach can grow (the chain sets it, not the tail), so a raptor 12 studs out in front is no problem.</li><li>Cost: a new piece on the Pincer Tail (a chain drum inside the last tail segment) and the slowest catch-to-throw.</li></ul><p class="note">Game change: TenoPartsAnim flies the head group on a chain (Beam), TenoBotMotion follows the reel path.</p>`,
};
$("moves").addEventListener("click", e => { const b = e.target.closest("[data-i]"); if (!b || b.disabled) return; cur = +b.dataset.i; variant = MOVES[cur].id === "tgrab" ? "A" : "now"; tt = 0; reset(); renderAll(); });
$("varRow").addEventListener("click", e => { const b = e.target.closest("[data-var]"); if (!b) return; variant = b.dataset.var; tt = 0; reset(); renderAll(); });
$("phases").addEventListener("click", e => { const b = e.target.closest("[data-t]"); if (!b) return; tt = +b.dataset.t + 0.06; playing = false; syncPlay(); });
$("play").onclick = () => { playing = !playing; syncPlay(); };
function syncPlay() { $("play").textContent = playing ? "Pause" : "Play"; $("play").setAttribute("aria-pressed", playing); }
document.querySelectorAll("[data-speed]").forEach(b => b.onclick = () => { speed = +b.dataset.speed; document.querySelectorAll("[data-speed]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => { view = b.dataset.view; document.querySelectorAll("[data-view]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
document.querySelectorAll("[data-side]").forEach(b => b.onclick = () => { side = b.dataset.side; tt = 0; reset(); document.querySelectorAll("[data-side]").forEach(x => x.setAttribute("aria-pressed", x === b)); renderAll(); });
$("scrub").addEventListener("input", e => { tt = +e.target.value / 1000 * VV().len; playing = false; syncPlay(); sol = null; });
// test hooks (Playwright): set a frame and read the numbers
window.__teno = {set(v, s, time, cam, mv) { if (mv) cur = MOVES.findIndex(m => m.id === mv); variant = v; side = s; tt = time; playing = false; if (cam) view = cam; reset(); renderAll(); syncPlay(); }, st, get miss() { return ikMiss; }};
window.__tt = x => { tt = x; };
renderAll();

// ---------- loop ----------
let lastNow = performance.now(), camPos = new THREE.Vector3(26, 14, 18), camLook = new THREE.Vector3(0, 3, 4), lastTT = -1;
function frameM(now) {
  const dt = Math.min(0.05, (now - lastNow) / 1000); lastNow = now; t += dt;
  const v = VV();
  if (playing) { tt += dt * speed; if (tt > v.len) { tt = 0; reset(); } }
  if (tt < lastTT) { sol = null; for (const k in st) delete st[k]; }
  lastTT = tt;
  fxOff(); raptor.visible = true; raptor2.visible = raptor3.visible = false; use = 0; headOff = null; rig.rotation.y = 0; rig.position.set(0, 0, 0);
  for (const k in LU) lookU(k, 0); jaw = 0.3;
  // replay from the start of the move each frame for the scratch values that depend on order (from / rel)
  v.update(tt);
  updateEquip();
  if (headOff) for (const e of HEAD) { rig.updateMatrixWorld(true); const inv = new THREE.Matrix4().copy(rig.matrixWorld).invert(); const o = headOff.clone().transformDirection(inv).multiplyScalar(headOff.length()); e.mesh.matrix.premultiply(new THREE.Matrix4().makeTranslation(o.x, o.y, o.z)); }
  $("scrub").value = Math.round(tt / v.len * 1000);
  $("clock").textContent = `${tt.toFixed(2)} s${speed !== 1 ? " · 0.3×" : ""}`;
  const ph = v.phases(side).find(p => tt >= p[0] && tt < p[1]);
  $("cap").textContent = ph ? ph[2] : "…";
  document.querySelectorAll(".ph").forEach(b => b.setAttribute("aria-current", ph && +b.dataset.t === ph[0]));
  // camera
  const MM = M(); const f = MM.focus ? MM.focus.clone().add(new THREE.Vector3(0, rig.position.y * 0.5, rig.position.z * 0.5)) : new THREE.Vector3(0, 4.5, side === "front" ? 1 : 7).add(rig.position);
  let goalPos, goalLook;
  if (view === "game") { // ShoulderCam: behind-right of the dino, looking ahead (follows the body's facing)
    const h = rig.rotation.y, off = new THREE.Vector3(13, 15.3, 34).applyAxisAngle(UP, h);
    goalPos = off; goalLook = goalPos.clone().add(new THREE.Vector3(-0.05, -0.12, -1).applyAxisAngle(UP, h));
  } else if (view === "top") { const fz = MM.focus ? MM.focus.z : 4; goalPos = new THREE.Vector3(0, 80, fz + 0.01); goalLook = new THREE.Vector3(0, 0, fz); }
  else if (view === "side") { goalPos = f.clone().add(new THREE.Vector3(MM.side || 56, 4, 0)); goalLook = f; }
  else { goalPos = f.clone().add(MM.focus ? new THREE.Vector3(0.7, 0.32, -0.45).multiplyScalar(MM.side || 56) : side === "front" ? new THREE.Vector3(40, 18, -22) : new THREE.Vector3(40, 18, 26)); goalLook = f; }
  const fovWant = view === "game" ? 70 : 34;
  if (cam.fov !== fovWant) { cam.fov = fovWant; cam.updateProjectionMatrix(); }
  const kk = playing ? 1 - Math.pow(0.001, dt) : 1;
  camPos.lerp(goalPos, kk); camLook.lerp(goalLook, kk);
  cam.position.copy(camPos); cam.lookAt(camLook);
  resize(); renderer.render(scene, cam);
  requestAnimationFrame(frameM);
}
requestAnimationFrame(frameM);
