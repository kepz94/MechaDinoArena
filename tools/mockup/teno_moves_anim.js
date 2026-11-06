// Teno move animations mockup v0.1 (Mecha Dino Arena) — the animation pass. Kepu 2026-11-05 17:33 "Do the animation pass now",
// 17:40 "some of the tail grab animations ain't looking good", 17:56 "You didn't send me the mockups". Plays each move on the
// real Teno (TenoModelData look E) with the 7 picked v2 looks (Grab-B Pincer Tail, Mortar-B Back Cannon, Stomp-A Quake Hooves,
// Bellow-A Shriek Sacs, Challenge-C Alarm Beacon, Leap-A Chicken-Leg Rams, Shield-B Shield Mane), against a raptor.
// v0.1: Tail Grab & Fling — Now (v461, as the game plays it) vs A Scorpion Strike / B Hammer Spin / C Snap Line, front + behind.
// Units: the model's (game studs / 2). Front = -Z, the camera side = +X. Tail joints: p+ = down, y+ = toward +X.
const ANIM_VERSION = "0.1";
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
function buildRig() {
  clearEquip();
  GLOW = AREA.attack[2]; const g0 = equip.length; grabPincer();
  const grab = equip.slice(g0);
  for (const e of grab) if (e.role === "pincer" && e.place) { const o = e.place; e.place = () => o(jaw, Math.PI / 6); } // sin(3t) = 1: open = 8 + 38 x jaw deg
  HEAD = grab.filter(e => e.part === "Tail5_main" && (e.role === "pincer" || e.role === "tip" || e.key === "iron" || e.key === "brass"));
  GLOW = AREA.attack[2]; mortarCannon();
  GLOW = AREA.defense[2]; stompQuake();
  GLOW = AREA.health[2]; bellowSacs();
  GLOW = AREA.defense[2]; challengeBeacon();
  GLOW = AREA.speed[2]; leapRams();
  GLOW = AREA.defense[2]; shieldMane();
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
const GRIP_Y = 2.5; // torso centre above the feet
// o: {pos (feet), yaw, run, runAmt, flash, held (torso centre world pos when held), spin [x, y, z] (radians, about the torso), lie (0..1)}
function raptorPose(o) {
  const R = raptor, u = R.userData, ph = o.run || 0, a = o.runAmt === undefined ? 1 : o.runAmt;
  R.visible = o.visible !== false; if (!R.visible) return;
  if (o.held) R.position.copy(o.held).add(new THREE.Vector3(0, -GRIP_Y, 0)); else R.position.copy(o.pos);
  R.rotation.set(0, o.yaw || 0, 0);
  const sp = o.spin || [0, 0, 0]; u.body.rotation.set(sp[0], sp[1], sp[2] + (o.lie || 0) * Math.PI / 2);
  u.body.position.y = GRIP_Y - (o.lie || 0) * 1.8;
  u.legs.forEach((l, i) => { const s = Math.sin(ph + i * Math.PI); l.L.rotation.x = s * 0.7 * a; l.sh.rotation.x = -Math.max(0, Math.cos(ph + i * Math.PI)) * 0.9 * a; });
  u.neck.rotation.x = 0.5 + (o.held ? Math.sin(ph * 0.7) * 0.4 : 0);
  u.mat.color.setHex(o.flash ? 0xffffff : u.base);
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
let side = "front", variant = "now";
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

const MOVES = [
  {id: "tgrab", name: "Tail Grab & Fling", area: "attack", variants: ["now", "A", "B", "C"],
    part: "Pincer Tail (armoured tail + two pincer blades)", partWhy: "The pincer blades open wide on the wind-up and snap shut on the raptor's back; the armour plates ride along. Red = attack glow on the plates' top line and the blade edges.",
    nums: "Unchanged numbers: 8 damage · stun 1 s · thrown 45 studs (TenoGrabFling) · reach 12 studs · recharge 16 s. Only the animation and when the catch / throw happen change."},
  {id: "tmortar", name: "Boulder Mortar", soon: true}, {id: "tstomp", name: "Stomp Shockwave", soon: true}, {id: "tbellow", name: "Herd Bellow", soon: true},
  {id: "tchallenge", name: "Challenge Call", soon: true}, {id: "tleap", name: "Hydraulic Leap", soon: true}, {id: "tmud", name: "Shield Armor", soon: true},
];

// ---------- UI ----------
let cur = 0, playing = true, speed = 1, view = "side", tt = 0;
const M = () => MOVES[cur], VV = () => V[variant];
function renderAll() {
  $("moves").innerHTML = MOVES.map((m, i) => `<button class="tab" data-i="${i}" aria-pressed="${i === cur}" ${m.soon ? "disabled" : ""}>${m.name}<small style="color:${m.soon ? "var(--muted)" : AREA[m.area][1]}">${m.soon ? "next in this pass" : "4 versions"}</small></button>`).join("");
  $("varRow").innerHTML = '<span class="lbl">Version</span>' + M().variants.map(k => `<button class="var" data-var="${k}" aria-pressed="${k === variant}">${V[k].name}${V[k].rec ? ' <span class="rec">· recommended</span>' : ""}<small>${V[k].sub}</small></button>`).join("");
  const v = VV(), ph = v.phases(side);
  $("phases").innerHTML = ph.map(p => `<button class="ph" data-t="${p[0]}" aria-current="false"><i>${p[0].toFixed(2)}–${p[1].toFixed(2)} s</i>${p[2]}</button>`).join("");
  const rows = M().variants.map(k => `<tr><th>${V[k].name}</th><td>${V[k].timing(side)}</td></tr>`).join("");
  $("info").innerHTML = `<div class="kind" style="color:${AREA.attack[1]}">ATTACK · Tail Grab & Fling · ${v.name} · target ${side === "front" ? "in front" : "behind"}</div><h2>What you see, in order</h2><ul>${ph.slice(1).map(p => `<li>${p[2]}</li>`).join("")}</ul><p class="note"><b>Borrowed from:</b> ${v.ref}</p><table class="cmp">${rows}</table><p class="note">${M().nums}</p>`;
  $("part").innerHTML = `<div class="kind" style="color:${AREA.attack[1]}">The part that does it</div><h2>${M().part}</h2><p class="note">${M().partWhy}</p>${NOTES[variant]}`;
}
const NOTES = {
  now: `<h2 style="margin-top:6px">What's wrong with it now</h2><ul><li>In front, the tail can't reach over your head: it stops short (red line) and the raptor is <b>yanked</b> ~20 studs through the air into the jaws in 0.12 s.</li><li>Behind, it's yanked ~11 studs.</li><li>It's lifted ~32 studs high, much higher than the tail looks like it could hold it.</li><li>The throw misses its aim by up to ~6 studs, so the raptor pops away from the jaws when it's let go.</li></ul>`,
  A: `<h2 style="margin-top:6px">Why it fixes it</h2><ul><li>Your body tips nose-down (front) or rears back (behind), which lifts the tail base so the tail really reaches the raptor: no yank, the jaws close on it where it stands.</li><li>The lift only goes as high as the tail curls over your back (~21 studs), and the throw is a short, low slam-fling (~36 studs), so the raptor never leaves the jaws early.</li><li>You never turn: your camera and steering stay yours.</li></ul><p class="note">Game change: TenoPose's grab path (coil → strike → lift → slam) + the catch / throw times in TenoMovesServer. The 45-stud fling becomes ~36 for the front, ~30 for behind (or keep 45 with a higher arc).</p>`,
  B: `<h2 style="margin-top:6px">Why it fixes it</h2><ul><li>In front, you stomp round first so the tail sweeps low into the raptor: it's caught where it stands, no yank.</li><li>The spin is the clearest wind-up any throw can have: you see it coming and you see where it goes (always ahead of you, ~60 studs).</li><li>Cost: your body (and camera) turns for over a second, and it's the slowest.</li></ul><p class="note">Game change: the body turn needs the server to rotate the teno (TurnLimit off for 1.3 s) + a new TenoPose spin path.</p>`,
  C: `<h2 style="margin-top:6px">Why it fixes it</h2><ul><li>The pull is still there, but now you see what pulls it: the pincer head fires out on a chain, clamps on, and the chain reels it in.</li><li>Reach can grow (the chain sets it, not the tail), so a raptor 12 studs out in front is no problem.</li><li>Cost: a new piece on the Pincer Tail (a chain drum inside the last tail segment) and the slowest catch-to-throw.</li></ul><p class="note">Game change: TenoPartsAnim flies the head group on a chain (Beam), TenoBotMotion follows the reel path.</p>`,
};
$("moves").addEventListener("click", e => { const b = e.target.closest("[data-i]"); if (!b || b.disabled) return; cur = +b.dataset.i; tt = 0; reset(); renderAll(); });
$("varRow").addEventListener("click", e => { const b = e.target.closest("[data-var]"); if (!b) return; variant = b.dataset.var; tt = 0; reset(); renderAll(); });
$("phases").addEventListener("click", e => { const b = e.target.closest("[data-t]"); if (!b) return; tt = +b.dataset.t + 0.06; playing = false; syncPlay(); });
$("play").onclick = () => { playing = !playing; syncPlay(); };
function syncPlay() { $("play").textContent = playing ? "Pause" : "Play"; $("play").setAttribute("aria-pressed", playing); }
document.querySelectorAll("[data-speed]").forEach(b => b.onclick = () => { speed = +b.dataset.speed; document.querySelectorAll("[data-speed]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => { view = b.dataset.view; document.querySelectorAll("[data-view]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
document.querySelectorAll("[data-side]").forEach(b => b.onclick = () => { side = b.dataset.side; tt = 0; reset(); document.querySelectorAll("[data-side]").forEach(x => x.setAttribute("aria-pressed", x === b)); renderAll(); });
$("scrub").addEventListener("input", e => { tt = +e.target.value / 1000 * VV().len; playing = false; syncPlay(); sol = null; });
// test hooks (Playwright): set a frame and read the numbers
window.__teno = {set(v, s, time, cam) { variant = v; side = s; tt = time; playing = false; if (cam) view = cam; reset(); renderAll(); syncPlay(); }, st, get miss() { return ikMiss; }};
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
  fxOff(); raptor.visible = true; use = 0; headOff = null; rig.rotation.y = 0; rig.position.set(0, 0, 0);
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
  const f = new THREE.Vector3(0, 4.5, side === "front" ? 1 : 7).add(rig.position);
  let goalPos, goalLook;
  if (view === "game") { // ShoulderCam: behind-right of the dino, looking ahead (follows the body's facing)
    const h = rig.rotation.y, off = new THREE.Vector3(13, 15.3, 34).applyAxisAngle(UP, h);
    goalPos = off; goalLook = goalPos.clone().add(new THREE.Vector3(-0.05, -0.12, -1).applyAxisAngle(UP, h));
  } else if (view === "top") { goalPos = new THREE.Vector3(0, 70, 4.01); goalLook = new THREE.Vector3(0, 0, 4); }
  else if (view === "side") { goalPos = f.clone().add(new THREE.Vector3(56, 4, 0)); goalLook = f; }
  else { goalPos = f.clone().add(side === "front" ? new THREE.Vector3(40, 18, -22) : new THREE.Vector3(40, 18, 26)); goalLook = f; }
  const fovWant = view === "game" ? 70 : 34;
  if (cam.fov !== fovWant) { cam.fov = fovWant; cam.updateProjectionMatrix(); }
  const kk = playing ? 1 - Math.pow(0.001, dt) : 1;
  camPos.lerp(goalPos, kk); camLook.lerp(goalLook, kk);
  cam.position.copy(camPos); cam.lookAt(camLook);
  resize(); renderer.render(scene, cam);
  requestAnimationFrame(frameM);
}
requestAnimationFrame(frameM);
