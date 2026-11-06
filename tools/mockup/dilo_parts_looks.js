// dilo_parts_looks.js v0.1 (Mecha Dino Arena) — Dilo mecha button parts, LOOKS mockup (Kepu 2026-11-06 00:41 picks
// "1. 3. 9. 13. 15. 16. 20."). Engine = tools/dilo_kit_mockup/app.js (scene, rigs, springs, FX, projectiles; prepended by
// the build up to its "moves" section). Seven parts x looks A / B / C: each look is a set of meshes fixed to the Dilo's real
// segments (they ride the rig: pushed into dilo.parts with kind "mech"), and plays the maxed-out move: wind-up -> action ->
// result -> recovery. Numbers are the maxed texts at scale 2 (studs). No landing FX (house rule).
const ANIM_VERSION = "0.1";

// ---------- shared state + helpers (as dilo_moves_anim.js) ----------
const R0 = raps[0], R1 = raps[1];
function place(R, x, z, yaw) { R.show = true; R.pos.set(x, 0, z); R.yaw = yaw === undefined ? yawTo(R.pos, new THREE.Vector3()) : yaw; R.path = null; R.run = 0; }
const aim = {on: 0, R: null, cone: null, yaw: 0};
let hitStop = 0, shake = 0, clockT = 0, idleT = 0, fovPunch = 0;
const frill = {open: false, t: 9};
function venomOn(R, rate, dur, style) { R.venom = {left: dur, rate, next: 0.5, drip: 0, style: style || "now", age: 0}; }
const headOf = R => partPoint(R.rig.segs.Head[0]);
function puff(p, v, size, color, life, op) { const s = sprite(T_MIST, color || 0xffffff, size, false); s.position.copy(p);
  addFx(s, life || 0.6, (o, u, dt) => { o.position.addScaledVector(v, dt); o.scale.setScalar(size * (1 + u * 2.4)); o.material.opacity = (op || 0.7) * (1 - u); }); }
function groundRing(center, r1, color, life) {
  const m = new THREE.Mesh(new THREE.RingGeometry(0.86, 1, 56), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0.8, depthWrite: false, side: THREE.DoubleSide}));
  m.rotation.x = -Math.PI / 2; m.position.copy(center).setY(0.15);
  addFx(m, life, (o, u) => { const r = 1 + (r1 - 1) * E.out(u); o.scale.setScalar(r); o.material.opacity = 0.8 * (1 - u); });
}
function spine(p, dir, len) { const g = new THREE.Mesh(new THREE.ConeGeometry(0.3, len, 6), new THREE.MeshLambertMaterial({color: 0x9cf05a, emissive: 0x2d7a10, transparent: true})); g.position.copy(p);
  g.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir.clone().normalize()); const v = dir.clone().normalize().multiplyScalar(60);
  addFx(g, 0.36, (o, u, dt) => { o.position.addScaledVector(v, dt); o.material.opacity = 1 - u * u; }); }
function killFx(obj) { const e = fx.find(f => f.obj === obj); if (e) e.life = Math.min(e.life, e.t + 0.12); }
function lightHit(R, p, n) { hitStop = Math.max(hitStop, 0.02); shake = Math.max(shake, 0.3); flash(p, 4, 0xd8ffb0);
  numberPop(p.clone().add(new THREE.Vector3(0, 5, 0)), n, "hit"); R.flinch = Math.max(R.flinch, 0.6); R.side = 0; R.flash = 0.08; R.flashCol = [0.35, 0.95, 0.15]; R.push = Math.max(R.push, 0.6); R.pushDir.copy(R.pos).sub(dilo.pos).setY(0).normalize(); }
let delayed = [];
function later(d, f) { delayed.push({at: (play ? play.t : 0) + d, f}); }
const K = (t, pose, e) => ({t, pose, e});

// extra key poses (degrees {p, y, r}; + = rear back / nose up for RootJoint / Neck / Head; Jaw - = open; Tail - = lift)
const BRACE = Object.assign(BOTH({RootJoint: [-4, 0, 0], Neck: [-6, 0, 0], Head: [2, 0, 0], ArmL: [-12, 0, 0], KneeL: [-16, 0, 0], AnkleL: [6, 0, 0], Tail1: [-4, 0, 0]}), {LegL: [14, 0, 0], LegR: [-6, 0, 0]});
const BRACE_OPEN = addPose(BRACE, {Jaw: [-18, 0, 0]}, 1);
const CROUCH_FIRE = BOTH({RootJoint: [-6, 0, 0], Neck: [6, 0, 0], Head: [-4, 0, 0], ArmL: [-10, 0, 0], LegL: [18, 0, 0], KneeL: [-34, 0, 0], AnkleL: [14, 0, 0], Tail1: [4, 0, 0]});
const MORTAR_KICK = addPose(CROUCH_FIRE, {RootJoint: [8, 0, 0], Neck: [6, 0, 0], root: {fwd: -1.6}}, 1);
const TAIL_LOAD = BOTH({RootJoint: [-6, 0, 0], Neck: [-8, 0, 0], Head: [4, 0, 0], ArmL: [-8, 0, 0], KneeL: [-14, 0, 0], LegL: [8, 0, 0], Tail1: [22, 0, 0], Tail2: [16, 0, 0], Tail3: [12, 0, 0], Tail4: [8, 0, 0]});
const TAIL_WHIP = BOTH({RootJoint: [-12, 0, 0], Neck: [-14, 0, 0], Head: [8, 0, 0], ArmL: [10, 0, 0], KneeL: [-10, 0, 0], Tail1: [-44, 0, 0], Tail2: [-34, 0, 0], Tail3: [-26, 0, 0], Tail4: [-16, 0, 0], root: {fwd: 0.8}});
const HISS_WIND = addPose(A_WIND, {Jaw: [-22, 0, 0], Head: [-4, 0, 0]}, 1);
const HISS_BLAST = BOTH({RootJoint: [-6, 0, 0], Neck: [-14, 0, 0], Head: [10, 0, 0], Jaw: [-46, 0, 0], ArmL: [-14, 0, 0], KneeL: [-8, 0, 0], Tail1: [-8, 0, 0], Tail2: [-4, 0, 0], root: {fwd: 0.6}});
const CURL = BOTH({RootJoint: [-4, 0, 0], Neck: [18, 0, 0], Head: [-18, 0, 0], Jaw: [-8, 0, 0], ArmL: [-26, 0, 0], LegL: [16, 0, 0], KneeL: [-30, 0, 0], AnkleL: [12, 0, 0], Tail1: [8, 0, 0], Tail2: [6, 0, 0]});
const BURST = BOTH({RootJoint: [12, 0, 0], Neck: [28, 0, 0], Head: [-14, 0, 0], Jaw: [-36, 0, 0], ArmL: [-34, 0, -26], LegL: [-4, 0, 0], KneeL: [-6, 0, 0], Tail1: [-14, 0, 0], Tail2: [-8, 0, 0], root: {fwd: -0.6}});
const SICK = BOTH({RootJoint: [-6, 0, 0], Neck: [-16, 0, 0], Head: [8, 0, 0], Jaw: [-10, 0, 0], ArmL: [8, 0, 0], KneeL: [-10, 0, 0], LegL: [6, 0, 0], Tail1: [10, 0, 0], Tail2: [6, 0, 0]});
const PRIME = BOTH({RootJoint: [2, 0, 0], Neck: [6, 0, 0], Head: [-6, 0, 0], Jaw: [-4, 0, 0], ArmL: [-14, 0, 0], KneeL: [-12, 0, 0], LegL: [6, 0, 0], Tail1: [4, 0, 0]});
const JOLT = BOTH({RootJoint: [14, 0, 0], Neck: [34, 0, 0], Head: [-24, 0, 0], Jaw: [-24, 0, 0], ArmL: [-24, 0, -20], Tail1: [-12, 0, 0], Tail2: [-8, 0, 0], root: {fwd: -0.8}});
const PROUD = BOTH({RootJoint: [4, 0, 0], Neck: [10, 0, 0], Head: [-6, 0, 0], ArmL: [-6, 0, 0], Tail1: [-4, 0, 0]});
const DASH_LOW = BOTH({RootJoint: [-10, 0, 0], Neck: [-6, 0, 0], Head: [8, 0, 0], Jaw: [-6, 0, 0], ArmL: [-10, 0, 0], LegL: [24, 0, 0], KneeL: [-44, 0, 0], AnkleL: [18, 0, 0], Tail1: [-10, 0, 0], Tail2: [-6, 0, 0]});
const DASH_GO = Object.assign(BOTH({RootJoint: [-16, 0, 0], Neck: [-20, 0, 0], Head: [6, 0, 0], ArmL: [30, 0, 0], KneeL: [-8, 0, 0], Tail1: [-14, 0, 0], Tail2: [-8, 0, 0], Tail3: [-4, 0, 0]}), {LegL: [-26, 0, 0], LegR: [22, 0, 0], KneeR: [-26, 0, 0], AnkleL: [-12, 0, 0]});
const DASH_SKID = Object.assign(BOTH({RootJoint: [10, 0, 0], Neck: [18, 0, 0], Head: [-8, 0, 0], ArmL: [-16, 0, 0], Tail1: [10, 0, 0], Tail2: [6, 0, 0]}), {LegL: [28, 0, 0], KneeL: [-30, 0, 0], AnkleL: [10, 0, 0], LegR: [8, 0, 0], KneeR: [-40, 0, 0], AnkleR: [16, 0, 0]});
const ROAR = BOTH({RootJoint: [8, 0, 0], Neck: [22, 0, 0], Head: [8, 0, 0], Jaw: [-44, 0, 0], ArmL: [-24, 0, -14], Tail1: [-10, 0, 0], Tail2: [-6, 0, 0], root: {fwd: -0.4}});
const SPIT_SET = BOTH({RootJoint: [2, 0, 0], Neck: [12, 0, 0], Head: [-10, 0, 0], Jaw: [-10, 0, 0], ArmL: [-12, 0, 0], KneeL: [-8, 0, 0]});
const SPIT_GO = BOTH({RootJoint: [-6, 0, 0], Neck: [-14, 0, 0], Head: [6, 0, 0], Jaw: [-32, 0, 0], ArmL: [8, 0, 0], KneeL: [-6, 0, 0], root: {fwd: 1}});

// ---------- mecha parts on the rig ----------
const segInv = {}; for (const s of DILO.segs) segInv[s.n] = cfm(s.root).invert();
const lam = (c, o) => new THREE.MeshLambertMaterial(Object.assign({color: c}, o || {}));
const MAT = {gun: lam(0x3b4049), dark: lam(0x22252c), steel: lam(0x9aa1ac), yellow: lam(0xffc21a), copper: lam(0xc8843e), rubber: lam(0x16171a),
  green: lam(0x8fe04a, {emissive: 0x2d7a10}), blue: lam(0x9fe6ff, {emissive: 0x1d6f8f}), glassG: lam(0x9cf05a, {emissive: 0x3a9a12, transparent: true, opacity: 0.85}),
  glassB: lam(0x8fd8ff, {emissive: 0x2a86b0, transparent: true, opacity: 0.85}), lit: lam(0x9cf05a, {emissive: 0x5cd22a}), purple: lam(0xb8a6ff, {emissive: 0x4a3a9a})};
const GLOW_MATS = [MAT.green, MAT.blue, MAT.glassG, MAT.glassB, MAT.lit, MAT.purple];
GLOW_MATS.forEach(m => { m.userData.base = m.emissive.getHex(); });
const G = {
  box: (w, h, d) => new THREE.BoxGeometry(w, h, d),
  cylZ: (r1, r2, len, n) => new THREE.CylinderGeometry(r1, r2, len, n || 12).rotateX(Math.PI / 2), // r1 at +Z, r2 at -Z (muzzle)
  cylY: (r1, r2, len, n) => new THREE.CylinderGeometry(r1, r2, len, n || 12),
  cylX: (r1, r2, len, n) => new THREE.CylinderGeometry(r1, r2, len, n || 12).rotateZ(-Math.PI / 2),
  sph: (r) => new THREE.SphereGeometry(r, 14, 10),
  torus: (r, t) => new THREE.TorusGeometry(r, t, 8, 24),
  cone: (r, len) => new THREE.ConeGeometry(r, len, 10),
};
const MECH = [];
const MF = new THREE.Matrix4();
// pos / rot: rest pose, model space at scale 1 (the model data's own frame), rot in degrees (X, Y, Z)
function piece(look, seg, geo, mat, pos, rot, o) {
  o = o || {};
  const m = new THREE.Mesh(geo, mat); m.matrixAutoUpdate = false; m.castShadow = true; dilo.g.add(m);
  const R = rot || [0, 0, 0];
  const at = new THREE.Matrix4().compose(new THREE.Vector3(pos[0], pos[1], pos[2]), new THREE.Quaternion().setFromEuler(new THREE.Euler(rad(R[0]), rad(R[1]), rad(R[2]))), new THREE.Vector3(1, 1, 1));
  const base = segInv[seg].clone().multiply(at);
  const info = {name: o.name || look, seg, mesh: m, local: base.clone(), base, size: [0, 0, 0], kind: "mech", look, anim: o.anim, marker: !!o.marker, frill: o.frill, show: o.show};
  dilo.parts.push(info); MECH.push(info); return info;
}
const marker = (look, seg, pos, name) => piece(look, seg, G.box(0.05, 0.05, 0.05), MAT.dark, pos, [0, 0, 0], {marker: true, name});
const MS = {spin: 0, spinV: 0, recoil: 0, elev: 0, charge: 0, pump: 0, extend: 0, loaded: 1, fluid: 1, glow: 0, heat: 0, jab: 0, cup: 1, pips: 3};
function msReset() { Object.assign(MS, {spin: 0, spinV: 0, recoil: 0, elev: 0, charge: 0, pump: 0, extend: 0, loaded: 1, fluid: 1, glow: 0, heat: 0, jab: 0, cup: 1, pips: 3}); }
const rotZ = a => new THREE.Matrix4().makeRotationZ(a), rotX = a => new THREE.Matrix4().makeRotationX(a), tr = (x, y, z) => new THREE.Matrix4().makeTranslation(x, y, z);
const scl = (x, y, z) => new THREE.Matrix4().makeScale(x, y, z);
const MK = {}; // markers by name

// ===== 1 · Venom Gatling =====
(() => {
  // A · Chin Gatling: a 4-barrel rotary under the lower jaw (rides the Jaw); ammo drum under the throat feeds it
  const L = "gatling.A";
  piece(L, "Jaw", G.box(0.62, 0.34, 0.9), MAT.gun, [0, 1.46, -3.72]);
  piece(L, "Jaw", G.box(0.64, 0.08, 0.6), MAT.yellow, [0, 1.27, -3.6]);
  piece(L, "Jaw", G.cylZ(0.26, 0.26, 0.2), MAT.dark, [0, 1.46, -4.22]);
  for (let i = 0; i < 4; i++) { const g = G.cylZ(0.075, 0.075, 1.0, 8); const a = i * Math.PI / 2; g.translate(Math.cos(a) * 0.15, Math.sin(a) * 0.15, 0);
    piece(L, "Jaw", g, MAT.steel, [0, 1.46, -4.72], [0, 0, 0], {anim: () => rotZ(MS.spin)}); }
  piece(L, "Jaw", G.cylZ(0.22, 0.22, 0.07), MAT.dark, [0, 1.46, -5.05], [0, 0, 0], {anim: () => rotZ(MS.spin)});
  piece(L, "Neck", G.cylX(0.26, 0.26, 0.42), MAT.gun, [0, 1.25, -2.62]);
  piece(L, "Neck", G.cylX(0.18, 0.18, 0.46), MAT.lit, [0, 1.25, -2.62]);
  MK["gatling.A"] = [marker(L, "Jaw", [0, 1.46, -5.25])];
  // B · Shoulder Minigun: a 6-barrel cannon on a pintle on the +X shoulder, ammo drum on the back, belt between
  const B = "gatling.B";
  piece(B, "Torso", G.box(0.3, 0.32, 0.38), MAT.dark, [0.82, 0.98, -1.3]);
  piece(B, "Torso", G.box(0.42, 0.36, 0.86), MAT.gun, [0.95, 1.24, -1.55]);
  piece(B, "Torso", G.box(0.44, 0.08, 0.6), MAT.yellow, [0.95, 1.45, -1.5]);
  for (let i = 0; i < 6; i++) { const g = G.cylZ(0.05, 0.05, 1.2, 8); const a = i * Math.PI / 3; g.translate(Math.cos(a) * 0.13, Math.sin(a) * 0.13, 0);
    piece(B, "Torso", g, MAT.steel, [0.95, 1.24, -2.55], [0, 0, 0], {anim: () => rotZ(MS.spin)}); }
  piece(B, "Torso", G.cylZ(0.2, 0.2, 0.08), MAT.dark, [0.95, 1.24, -3.1], [0, 0, 0], {anim: () => rotZ(MS.spin)});
  piece(B, "Torso", G.cylX(0.36, 0.36, 0.32), MAT.gun, [0.62, 1.2, -0.2]);
  piece(B, "Torso", G.cylX(0.24, 0.24, 0.34), MAT.lit, [0.62, 1.2, -0.2]);
  piece(B, "Torso", G.box(0.14, 0.1, 0.9), MAT.copper, [0.86, 1.32, -0.72]);
  MK["gatling.B"] = [marker(B, "Torso", [0.95, 1.24, -3.25])];
  // C · Twin Hood Repeaters: a slim repeater on each side of the neck under the frill hub, drum magazines behind
  const C = "gatling.C";
  const sides = [1, -1];
  MK["gatling.C"] = [];
  for (const s of sides) {
    piece(C, "Neck", G.box(0.3, 0.32, 0.72), MAT.gun, [0.6 * s, 1.85, -2.55], [0, 0, 0]);
    piece(C, "Neck", G.box(0.31, 0.07, 0.5), MAT.yellow, [0.6 * s, 2.03, -2.5]);
    const g = G.cylZ(0.09, 0.08, 1.15, 8); piece(C, "Neck", g, MAT.steel, [0.6 * s, 1.85, -3.4], [0, 0, 0], {anim: () => tr(0, 0, MS.recoil * 0.2)});
    piece(C, "Neck", G.cylZ(0.14, 0.14, 0.18, 8), MAT.dark, [0.6 * s, 1.85, -3.9], [0, 0, 0], {anim: () => tr(0, 0, MS.recoil * 0.2)});
    piece(C, "Neck", G.cylX(0.24, 0.24, 0.18), MAT.lit, [0.8 * s, 1.75, -2.3]);
    MK["gatling.C"].push(marker(C, "Neck", [0.6 * s, 1.85, -4.05]));
  }
})();

// ===== 3 · Toxin Mortar =====
(() => {
  // A · Back Mortar: a stubby tube on a turntable on the back, laid back when stowed, up and forward to fire; 3 shells racked on the +X side
  const L = "mortar.A";
  piece(L, "Torso", G.cylY(0.42, 0.46, 0.14, 16), MAT.dark, [0, 1.1, -0.35]);
  piece(L, "Torso", G.box(0.5, 0.24, 0.5), MAT.gun, [0, 1.25, -0.35]);
  const tube = G.cylY(0.24, 0.27, 1.15, 14); tube.translate(0, 0.575, 0);
  const tubeAnim = () => rotX(rad(28 - 72 * MS.elev)).multiply(tr(0, -MS.recoil * 0.25, 0));
  piece(L, "Torso", tube, MAT.gun, [0, 1.33, -0.35], [0, 0, 0], {anim: tubeAnim});
  const band = G.cylY(0.29, 0.29, 0.12, 14); band.translate(0, 0.85, 0); piece(L, "Torso", band, MAT.yellow, [0, 1.33, -0.35], [0, 0, 0], {anim: tubeAnim});
  const mz = G.box(0.05, 0.05, 0.05); mz.translate(0, 1.2, 0); MK["mortar.A"] = [piece(L, "Torso", mz, MAT.dark, [0, 1.33, -0.35], [0, 0, 0], {anim: tubeAnim, marker: true})];
  for (let i = 0; i < 3; i++) { piece(L, "Torso", G.cylY(0.13, 0.13, 0.5, 10), MAT.lit, [0.84, 0.62, -0.95 + i * 0.36], [0, 0, 0], {show: () => i >= 1 || MS.cup > 0.5});
    piece(L, "Torso", G.cylY(0.14, 0.14, 0.1, 10), MAT.dark, [0.84, 0.9, -0.95 + i * 0.36]); }
  piece(L, "Torso", G.box(0.08, 0.5, 1.2), MAT.dark, [0.76, 0.66, -0.6]);
  // B · Tail Sling: a basket on the tail (Tail2) with a shell in it; the tail whips it over the head like a trebuchet
  const B = "mortar.B";
  piece(B, "Tail1", G.box(0.42, 0.14, 0.9), MAT.gun, [0, 0.62, 1.7]);
  piece(B, "Tail2", G.box(0.72, 0.12, 0.8), MAT.dark, [0, 0.68, 3.25]);
  piece(B, "Tail2", G.box(0.08, 0.4, 0.8), MAT.gun, [0.37, 0.9, 3.25]); piece(B, "Tail2", G.box(0.08, 0.4, 0.8), MAT.gun, [-0.37, 0.9, 3.25]);
  piece(B, "Tail2", G.box(0.72, 0.4, 0.08), MAT.gun, [0, 0.9, 3.65]); piece(B, "Tail2", G.box(0.74, 0.07, 0.1), MAT.yellow, [0, 1.12, 2.86]);
  piece(B, "Tail2", G.sph(0.32), MAT.lit, [0, 1.02, 3.22], [0, 0, 0], {show: () => MS.cup > 0.5});
  MK["mortar.B"] = [marker(B, "Tail2", [0, 1.0, 3.22])];
  // C · Chest Launcher: a chem tank slung under the chest and a short launch tube on the +X side of the neck base
  const C = "mortar.C";
  piece(C, "Torso", G.cylX(0.34, 0.34, 0.7, 14), MAT.gun, [0, -0.6, -1.5]);
  piece(C, "Torso", G.cylX(0.26, 0.26, 0.74, 14), MAT.glassG, [0, -0.6, -1.5]);
  piece(C, "Torso", G.box(0.76, 0.1, 0.16), MAT.dark, [0, -0.6, -1.5]);
  const t2 = G.cylY(0.18, 0.2, 0.95, 12); t2.translate(0, 0.47, 0);
  const t2Anim = () => rotX(rad(-20 - 30 * MS.elev)).multiply(tr(0, -MS.recoil * 0.2, 0));
  piece(C, "Torso", G.box(0.36, 0.3, 0.42), MAT.dark, [0.78, 0.9, -1.75]);
  piece(C, "Torso", t2, MAT.gun, [0.8, 1.0, -1.75], [0, 0, -14], {anim: t2Anim});
  const ring = G.cylY(0.22, 0.22, 0.1, 12); ring.translate(0, 0.8, 0); piece(C, "Torso", ring, MAT.yellow, [0.8, 1.0, -1.75], [0, 0, -14], {anim: t2Anim});
  piece(C, "Torso", G.box(0.08, 0.08, 0.6), MAT.copper, [0.5, 0.2, -1.6], [30, 0, 0]);
  const m2 = G.box(0.05, 0.05, 0.05); m2.translate(0, 1.0, 0); MK["mortar.C"] = [piece(C, "Torso", m2, MAT.dark, [0.8, 1.0, -1.75], [0, 0, -14], {anim: t2Anim, marker: true})];
})();

// ===== 9 · Sonic Hiss =====
const FRILL_B = n => DILO.segs.find(s => s.n === "Neck").parts.find(p => p.n === n).cf;
(() => {
  // A · Hood Speakers: six speaker cones set into the frill (3 a side); they fold with it and fan out when the hood flares
  const L = "hiss.A";
  MK["hiss.A"] = [marker(L, "Neck", [0, 2.6, -3.3])];
  for (const n of ["L2b", "L4b", "L6b", "R2b", "R4b", "R6b"]) {
    const c = FRILL_B("Neck_frill" + n);
    const pulse = () => scl(1 + MS.charge * 0.18 + MS.pump * 0.35, 1 + MS.charge * 0.18 + MS.pump * 0.35, 1 + MS.pump * 0.8);
    piece(L, "Neck", G.cylZ(0.27, 0.27, 0.08, 14), MAT.dark, [c[0], c[1], c[2] - 0.07], [0, 0, 0], {frill: true, anim: pulse});
    piece(L, "Neck", G.cylZ(0.2, 0.06, 0.14, 14), MAT.purple, [c[0], c[1], c[2] - 0.14], [0, 0, 0], {frill: true, anim: pulse});
    piece(L, "Neck", G.torus(0.27, 0.035), MAT.steel, [c[0], c[1], c[2] - 0.12], [0, 0, 0], {frill: true, anim: pulse});
  }
  piece(L, "Neck", G.box(0.22, 0.6, 0.5), MAT.gun, [0.5, 1.6, -2.3]); piece(L, "Neck", G.box(0.23, 0.07, 0.5), MAT.yellow, [0.5, 1.94, -2.3]);
  for (let j = 0; j < 3; j++) piece(L, "Neck", G.box(0.235, 0.05, 0.36), MAT.purple, [0.5, 1.45 + j * 0.13, -2.3], [0, 0, 0], {anim: () => scl(1, 1 + MS.charge * 0.6, 1)});
  piece(L, "Neck", G.box(0.06, 0.06, 0.4), MAT.rubber, [0.42, 2.05, -2.45], [-50, 0, 0]);
  // B · Throat Horn: a brass horn under the throat, a compressor on the chest; the bell flares at the blast
  const B = "hiss.B";
  const horn = G.cylZ(0.12, 0.42, 0.9, 16); piece(B, "Neck", horn, MAT.copper, [0, 1.12, -3.02], [16, 0, 0], {anim: () => scl(1 + MS.pump * 0.25, 1 + MS.pump * 0.25, 1)});
  piece(B, "Neck", G.torus(0.42, 0.04), MAT.yellow, [0, 1.0, -3.45], [16, 0, 0], {anim: () => scl(1 + MS.pump * 0.25, 1 + MS.pump * 0.25, 1)});
  piece(B, "Neck", G.cylZ(0.34, 0.1, 0.06, 16), MAT.purple, [0, 1.0, -3.42], [16, 0, 0]);
  piece(B, "Neck", G.box(0.34, 0.26, 0.5), MAT.gun, [0, 1.2, -2.4]);
  piece(B, "Torso", G.box(0.62, 0.42, 0.4), MAT.gun, [0, 0.1, -2.22]);
  for (let j = 0; j < 3; j++) piece(B, "Torso", G.box(0.5, 0.05, 0.04), MAT.purple, [0, 0.0 + j * 0.12, -2.43], [0, 0, 0], {anim: () => scl(1, 1 + MS.charge * 0.8, 1)});
  MK["hiss.B"] = [marker(B, "Neck", [0, 0.92, -3.6])];
  // C · Crest Resonators: a pair of tuning-fork prongs on the head crests, emitter knobs on the tips; they buzz while charging
  const C = "hiss.C";
  for (const s of [1, -1]) {
    const buzz = () => tr(Math.sin(clockT * 90) * 0.03 * MS.charge * s, 0, 0);
    piece(C, "Head", G.box(0.16, 0.18, 0.7), MAT.gun, [0.33 * s, 3.62, -3.9]);
    piece(C, "Head", G.box(0.06, 0.6, 0.08), MAT.steel, [0.33 * s, 3.95, -3.7], [0, 0, 0], {anim: buzz});
    piece(C, "Head", G.box(0.06, 0.6, 0.08), MAT.steel, [0.33 * s, 3.95, -4.1], [0, 0, 0], {anim: buzz});
    piece(C, "Head", G.sph(0.11), MAT.purple, [0.33 * s, 4.28, -3.7], [0, 0, 0], {anim: buzz}); piece(C, "Head", G.sph(0.11), MAT.purple, [0.33 * s, 4.28, -4.1], [0, 0, 0], {anim: buzz});
  }
  MK["hiss.C"] = [marker(C, "Head", [0, 4.1, -4.2])];
})();

// ===== 13 · Spine Burst =====
(() => {
  // A · Quill Collar: 12 launch tubes in a ring round the neck base; the spines poke out while it winds up
  const L = "spine.A"; MK["spine.A"] = [];
  piece(L, "Neck", G.torus(0.64, 0.1), MAT.gun, [0, 1.0, -2.2], [90, 0, 0]);
  for (let i = 0; i < 12; i++) {
    const a = i * Math.PI / 6 + Math.PI / 12, x = Math.sin(a), z = -Math.cos(a);
    const yaw = deg(Math.atan2(x, z));
    piece(L, "Neck", G.cylZ(0.09, 0.09, 0.32, 8), MAT.dark, [x * 0.74, 1.0, -2.2 + z * 0.74], [0, yaw, 0]);
    const sp = G.cone(0.07, 0.42); sp.rotateX(Math.PI / 2); // tip toward +Z of the piece (outward)
    piece(L, "Neck", sp, MAT.green, [x * 0.84, 1.0, -2.2 + z * 0.84], [0, yaw, 0], {anim: () => tr(0, 0, -0.14 + 0.2 * MS.extend), show: () => MS.loaded > 0.5});
    MK["spine.A"].push(marker(L, "Neck", [x * 1.0, 1.0, -2.2 + z * 1.0], a));
  }
  // B · Back Quiver: two racks of 6 spines along the back, angled out like a stegosaur's plates
  const B = "spine.B"; MK["spine.B"] = [];
  let k = 0;
  for (const s of [1, -1]) {
    piece(B, "Torso", G.box(0.16, 0.16, 2.0), MAT.gun, [0.28 * s, 1.08, -0.45]);
    for (let i = 0; i < 6; i++) {
      const z = -1.3 + i * 0.34;
      piece(B, "Torso", G.box(0.12, 0.2, 0.14), MAT.dark, [0.3 * s, 1.2, z], [0, 0, -30 * s]);
      const sp = G.cone(0.08, 0.6); sp.translate(0, 0.3, 0);
      piece(B, "Torso", sp, MAT.green, [0.32 * s, 1.26, z], [0, 0, -34 * s], {anim: () => tr(0, 0.12 * MS.extend - 0.1, 0), show: () => MS.loaded > 0.5});
      // the +X rack covers the +X half of the circle, the -X rack the other half
      MK["spine.B"].push(marker(B, "Torso", [0.5 * s, 1.5, z], s > 0 ? Math.PI / 2 + (i - 2.5) * Math.PI / 6 : -Math.PI / 2 - (i - 2.5) * Math.PI / 6)); k++;
    }
  }
  // C · Frill Barbs: a barb on each of the 12 frill rims, out only when the hood flares; two barb magazines show on the neck when folded
  const C = "spine.C"; MK["spine.C"] = [];
  for (const sd of ["L", "R"]) for (let i = 1; i <= 6; i++) {
    const c = FRILL_B(`Neck_frill${sd}rim${i}`), hub = [0, 2.65, c[2]];
    const ang = Math.atan2(c[1] - hub[1], c[0] - hub[0]);
    const sp = G.cone(0.08, 0.5); sp.translate(0, 0.25, 0);
    piece(C, "Neck", sp, MAT.green, [c[0], c[1], c[2] - 0.02], [0, 0, deg(ang) - 90], {frill: true, anim: () => tr(0, 0.08 * MS.extend, 0), show: () => MS.loaded > 0.5});
    MK["spine.C"].push(marker(C, "Neck", [c[0] * 1.15, c[1], c[2]], (sd === "L" ? 1 : -1) * rad(15 + (i - 1) * 30))); // compass angle: L rims cover the +X half, R the -X half
  }
  for (const s of [1, -1]) { piece(C, "Neck", G.box(0.18, 0.5, 0.34), MAT.gun, [0.52 * s, 1.55, -2.35]); piece(C, "Neck", G.box(0.19, 0.08, 0.35), MAT.yellow, [0.52 * s, 1.84, -2.35]);
    for (let j = 0; j < 3; j++) { const g = G.cone(0.05, 0.22); piece(C, "Neck", g, MAT.green, [0.52 * s, 1.92, -2.45 + j * 0.1]); } }
})();

// ===== 15 · Antivenom Pump =====
(() => {
  // A · Back Pump: a glass cylinder of blue antivenom on the back, a pump piston on top, two hoses into the neck base
  const L = "pump.A";
  piece(L, "Torso", G.box(0.6, 0.12, 1.1), MAT.dark, [0, 1.1, 0.35]);
  piece(L, "Torso", G.cylZ(0.3, 0.3, 0.95, 16), MAT.gun, [0, 1.42, 0.35]);
  const fl = G.cylZ(0.25, 0.25, 0.97, 16); piece(L, "Torso", fl, MAT.glassB, [0, 1.42, 0.35], [0, 0, 0], {anim: () => scl(1, Math.max(0.05, MS.fluid), 1).premultiply(tr(0, -0.25 * (1 - MS.fluid), 0))});
  for (const z of [-0.05, 0.75]) piece(L, "Torso", G.torus(0.3, 0.04), MAT.yellow, [0, 1.42, z]);
  piece(L, "Torso", G.cylY(0.07, 0.07, 0.5, 8), MAT.steel, [0, 1.72, 0.35], [0, 0, 0], {anim: () => tr(0, 0.32 * MS.pump, 0)});
  piece(L, "Torso", G.box(0.32, 0.08, 0.14), MAT.dark, [0, 1.98, 0.35], [0, 0, 0], {anim: () => tr(0, 0.32 * MS.pump, 0)});
  for (const s of [1, -1]) piece(L, "Torso", G.box(0.08, 0.08, 0.95), MAT.rubber, [0.2 * s, 1.24, -0.6], [-12, 0, 0]);
  MK["pump.A"] = [marker(L, "Torso", [0, 0.6, -2.0])];
  // B · Vial Bandolier: a strap round the neck base with four glass vials; they drain at once into the neck
  const B = "pump.B";
  piece(B, "Neck", G.torus(0.48, 0.06), MAT.rubber, [0, 1.1, -2.2], [90, 0, 0]);
  [65, 30, -30, -65].forEach(d => { const a = rad(d), at = r => [Math.sin(a) * r, -2.2 - Math.cos(a) * r];
    const [hx, hz] = at(0.5), [vx, vz] = at(0.58);
    piece(B, "Neck", G.box(0.12, 0.5, 0.12), MAT.dark, [hx, 1.1, hz], [0, d, 0]);
    piece(B, "Neck", G.cylY(0.1, 0.1, 0.44, 10), MAT.glassB, [vx, 1.1, vz], [0, 0, 0], {anim: () => scl(1, Math.max(0.05, MS.fluid), 1).premultiply(tr(0, -0.2 * (1 - MS.fluid), 0))});
    piece(B, "Neck", G.cylY(0.11, 0.11, 0.06, 10), MAT.steel, [vx, 1.35, vz]);
  });
  MK["pump.B"] = [marker(B, "Neck", [0, 1.1, -2.3])];
  // C · Arm Injector: an injector gauntlet on the +X arm; the arm swings in and jabs the chest
  const C = "pump.C";
  piece(C, "ArmL", G.box(0.26, 0.3, 0.6), MAT.gun, [0.85, -0.3, -1.95]);
  piece(C, "ArmL", G.box(0.27, 0.06, 0.5), MAT.yellow, [0.85, -0.13, -1.95]);
  piece(C, "ArmL", G.cylZ(0.1, 0.1, 0.5, 10), MAT.glassB, [0.85, -0.3, -2.4], [0, 0, 0], {anim: () => scl(1, 1, Math.max(0.1, MS.fluid)).premultiply(tr(0, 0, 0.2 * (1 - MS.fluid)))});
  piece(C, "ArmL", G.cylX(0.04, 0.04, 0.12, 8), MAT.dark, [0.69, -0.3, -1.95]);
  piece(C, "ArmL", G.cylX(0.02, 0.02, 0.4, 6), MAT.steel, [0.5, -0.3, -1.95], [0, 0, 0], {anim: () => tr(-0.18 * MS.jab, 0, 0)}); // needle points in, at the chest
  MK["pump.C"] = [marker(C, "ArmL", [0.4, -0.2, -1.95])];
})();

// ===== 16 · Spring Jets =====
(() => {
  // A · Hip Jet Pods: a jet pod on each hip, nozzles back; three charge lights on the +X pod
  const L = "jets.A"; MK["jets.A"] = [];
  for (const s of [1, -1]) {
    piece(L, "Torso", G.box(0.32, 0.42, 0.9), MAT.gun, [0.9 * s, 0.42, 0.15]);
    piece(L, "Torso", G.box(0.33, 0.08, 0.6), MAT.yellow, [0.9 * s, 0.66, 0.1]);
    piece(L, "Torso", G.cylZ(0.24, 0.16, 0.34, 12), MAT.dark, [0.9 * s, 0.42, 0.72]);
    MK["jets.A"].push(marker(L, "Torso", [0.9 * s, 0.42, 0.95]));
  }
  for (let i = 0; i < 3; i++) piece(L, "Torso", G.box(0.04, 0.09, 0.12), MAT.lit, [1.07, 0.42, -0.1 + i * 0.18], [0, 0, 0], {show: () => MS.pips > i});
  // B · Calf Springs: coil springs down the back of each shin with a jet at the heel
  const B = "jets.B"; MK["jets.B"] = [];
  for (const s of [1, -1]) {
    const shin = s > 0 ? "ShinL" : "ShinR";
    for (let i = 0; i < 4; i++) piece(B, shin, G.torus(0.16, 0.035), MAT.steel, [0.71 * s, -1.85 - i * 0.2, -0.05 + i * 0.1], [70, 0, 0], {anim: () => tr(0, 0.05 * i * MS.extend, 0)});
    piece(B, shin, G.box(0.2, 0.9, 0.12), MAT.gun, [0.71 * s, -2.1, 0.12], [-25, 0, 0]);
    piece(B, shin, G.cylZ(0.13, 0.09, 0.26, 10), MAT.dark, [0.71 * s, -2.5, 0.36], [-25, 0, 0]);
    MK["jets.B"].push(marker(B, shin, [0.71 * s, -2.55, 0.52]));
  }
  for (let i = 0; i < 3; i++) piece(B, "ShinL", G.box(0.04, 0.09, 0.09), MAT.lit, [0.83, -1.75 - i * 0.14, 0.05], [-25, 0, 0], {show: () => MS.pips > i});
  // C · Tail Booster: one big booster along the top of the tail base with fins; three charge lights on its +X side
  const C = "jets.C";
  piece(C, "Tail1", G.cylZ(0.3, 0.3, 1.5, 14), MAT.gun, [0, 0.82, 1.75]);
  piece(C, "Tail1", G.cylZ(0.31, 0.31, 0.16, 14), MAT.yellow, [0, 0.82, 1.3]);
  piece(C, "Tail1", G.cylZ(0.34, 0.22, 0.4, 14), MAT.dark, [0, 0.82, 2.65]);
  for (const r of [0, 90, 270]) { const f = G.box(0.04, 0.34, 0.4); f.translate(0, 0.42, 0); piece(C, "Tail1", f, MAT.gun, [0, 0.82, 2.25], [0, 0, r]); }
  piece(C, "Tail1", G.box(0.2, 0.18, 0.5), MAT.dark, [0, 0.55, 1.6]);
  for (let i = 0; i < 3; i++) piece(C, "Tail1", G.box(0.04, 0.09, 0.14), MAT.lit, [0.31, 0.82, 1.55 + i * 0.2], [0, 0, 0], {show: () => MS.pips > i});
  MK["jets.C"] = [marker(C, "Tail1", [0, 0.82, 2.95])];
})();

// ===== 20 · Venom Overdrive =====
(() => {
  // A · Venom Reactor: a glowing core set in the chest inside a ring frame, cooling fins along the back
  const L = "over.A";
  piece(L, "Torso", G.cylZ(0.4, 0.4, 0.14, 18), MAT.gun, [0, 0.45, -2.2]);
  piece(L, "Torso", G.sph(0.27), MAT.lit, [0, 0.45, -2.27], [0, 0, 0], {anim: () => { const k = 1 + MS.glow * 0.18 * (1 + Math.sin(clockT * 14)); return scl(k, k, k); }});
  piece(L, "Torso", G.torus(0.36, 0.05), MAT.yellow, [0, 0.45, -2.3]);
  for (let i = 0; i < 4; i++) piece(L, "Torso", G.box(0.06, 0.06, 0.4), MAT.steel, [0, 0.45, -2.31], [0, 0, 45 + i * 90]);
  for (let i = 0; i < 4; i++) piece(L, "Torso", G.box(0.5, 0.26, 0.06), MAT.gun, [0, 1.18, -1.55 + i * 0.2], [0, 0, 0], {anim: () => rotX(rad(-MS.glow * 22))});
  MK["over.A"] = [marker(L, "Torso", [0, 0.45, -2.4])];
  // B · Gland Tanks: two tall venom tanks on the back, hoses running up the neck to the jaw hinge
  const B = "over.B";
  for (const s of [1, -1]) {
    piece(B, "Torso", G.cylY(0.19, 0.19, 0.8, 14), MAT.gun, [0.3 * s, 1.45, -0.35]);
    piece(B, "Torso", G.cylY(0.15, 0.15, 0.82, 14), MAT.glassG, [0.3 * s, 1.45, -0.35], [0, 0, 0], {anim: () => scl(1, 0.6 + 0.4 * (1 - MS.glow * 0.5), 1)});
    piece(B, "Torso", G.cylY(0.21, 0.21, 0.08, 14), MAT.yellow, [0.3 * s, 1.85, -0.35]);
    piece(B, "Torso", G.box(0.07, 0.07, 0.95), MAT.rubber, [0.3 * s, 1.55, -1.1], [-24, 0, 0]);
  }
  piece(B, "Torso", G.box(0.85, 0.12, 0.45), MAT.dark, [0, 1.07, -0.35]);
  MK["over.B"] = [marker(B, "Torso", [0, 1.9, -0.35])];
  // C · Crest Capacitors: capacitor plates along both head crests with glowing strips, a heat sink behind the skull
  const C = "over.C";
  for (const s of [1, -1]) {
    piece(C, "Head", G.box(0.08, 0.32, 0.95), MAT.gun, [0.45 * s, 3.5, -3.95]);
    piece(C, "Head", G.box(0.09, 0.06, 0.85), MAT.lit, [0.46 * s, 3.62, -3.95]);
    piece(C, "Head", G.box(0.09, 0.06, 0.85), MAT.lit, [0.46 * s, 3.44, -3.95]);
  }
  for (let i = 0; i < 4; i++) piece(C, "Head", G.box(0.5, 0.05, 0.22), MAT.steel, [0, 3.2 + i * 0.09, -2.95]);
  MK["over.C"] = [marker(C, "Head", [0, 3.7, -4.0])];
})();
MECH.forEach(p => { if (p.marker) p.mesh.visible = false; });

// ---------- the parts (maxed texts from the 20-option list, Kepu 2026-11-06) ----------
const MOVES = [
  {id: "gatling", name: "Venom Gatling", area: "attack", max: "A jaw-mounted barrel fires 8 auto-aimed darts in 1 second, and every dart adds venom."},
  {id: "mortar", name: "Toxin Mortar", area: "attack", max: "Lob a canister up to 60 studs. It bursts into a 24-stud poison cloud for 5 s."},
  {id: "hiss", name: "Sonic Hiss", area: "attack", max: "Frill speakers blast a 30-stud cone that knocks dinos back and silences their mecha parts for 3 s."},
  {id: "spine", name: "Spine Burst", area: "defense", max: "The frill fires 12 spines all around, each 4 damage plus venom."},
  {id: "pump", name: "Antivenom Pump", area: "defense", max: "Clear all debuffs, heal 30, and become immune to slows, stuns and blinds for 4 s."},
  {id: "jets", name: "Spring Jets", area: "speed", max: "A 40-stud dash in the direction you move, with 3 charges. It leaves a poison trail."},
  {id: "over", name: "Venom Overdrive", area: "sig", max: "For 8 s, your darts recharge instantly and your venom is doubled."},
  {id: "all", name: "All 7", area: "all", max: "Every part of one letter at once, to check that they don't clash (a player slots only 4)."},
];
const AREA = {attack: ["Attack", "#ff6b6b"], speed: ["Speed", "#ffd34d"], defense: ["Defense", "#5fb4ff"], health: ["Health", "#7dff9a"], sig: ["Signature", "#c9a2ff"], all: ["Clash check", "#cfd3dc"]};

// ---------- tracks ----------
let play = null;
const cone30 = sectorMesh(30, 35, 0xb8a6ff, 0.1);
const mk = id => MK[id];
const mpt = (m, i) => partPoint(m[i || 0]);
function idleIntro(keys, t0) { return [K(0, READY), K(t0, READY), ...keys]; }

function gatlingTrack(L) {
  place(R0, -7, -36); place(R1, 9, -42);
  const T0 = 0.6; // idle (slotted look), then the move
  const pose0 = L === "B" ? addPose(BRACE, {RootJoint: [0, 0, -4]}, 1) : BRACE;
  const keys = idleIntro([K(T0 + 0.35, pose0, "io"), K(T0 + 1.35, pose0), K(T0 + 1.8, READY, "io")], T0);
  const ev = [];
  for (let i = 0; i < 8; i++) ev.push({t: T0 + 0.4 + i * 0.125, f: () => {
    const R = i % 2 ? R1 : R0, ms = mk("gatling." + L), m = ms[L === "C" ? i % 2 : 0], from = partPoint(m);
    flash(from, 3.2, 0xd8ff8a); MS.recoil = 1; shake = Math.max(shake, 0.18);
    sparks(from, new THREE.Vector3(L === "B" ? 1 : 0.6, 0.6, 0.3), 1, 0xc8a050, 0.4);
    spawnShot({kind: "dart", from, target: () => rapChest(R), T: 0.3, H: 0.12, onHit: p => { lightHit(R, p, 3); venomOn(R, Math.min(8, (R.venom ? R.venom.rate : 0) + 1), 3); }});
  }});
  return {frame: [new THREE.Vector3(0, 0, 2), new THREE.Vector3(0, 0, -44)], keys, ev, frill: L === "C" ? [[T0 + 0.1, T0 + 1.6]] : [],
    update(t, dt) {
      const want = t < T0 ? 0 : t < T0 + 0.35 ? 32 * (t - T0) / 0.35 : t < T0 + 1.4 ? 32 : Math.max(0, 32 * (1 - (t - T0 - 1.4) / 0.7));
      MS.spinV = want; MS.spin += want * dt; MS.recoil = Math.max(0, MS.recoil - dt * 9);
      if (t > T0 + 1.4 && t < T0 + 2.2 && Math.random() < dt * 14) { const ms = mk("gatling." + L); puff(partPoint(ms[(Math.random() * ms.length) | 0]), new THREE.Vector3(0, 3, -1), 0.9, 0xe8e8e8, 0.7, 0.5); }
    },
    extra(target) { if (MS.recoil > 0) { const j = MS.recoil * (L === "B" ? 2 : 3) * Math.sin(clockT * 70); if (L === "B") target.RootJoint[2] += j; else { target.Neck[0] += j; target.Head[0] -= j * 0.5; } } }};
}

function mortarTrack(L) {
  const C = new THREE.Vector3(0, 0, -50);
  place(R0, -5, -52); place(R1, 6, -47);
  const T0 = 0.6, F = T0 + 0.55, FLY = 1.15;
  let keys;
  if (L === "A") keys = idleIntro([K(T0 + 0.45, CROUCH_FIRE, "io"), K(F + 0.02, MORTAR_KICK, "out5"), K(F + 0.5, CROUCH_FIRE, "io"), K(F + 1.0, READY, "io")], T0);
  else if (L === "B") keys = idleIntro([K(T0 + 0.5, TAIL_LOAD, "io"), K(F + 0.06, TAIL_WHIP, "in2"), K(F + 0.45, TAIL_WHIP, "out"), K(F + 1.1, READY, "io")], T0);
  else keys = idleIntro([K(T0 + 0.45, A_WIND, "io"), K(F + 0.02, addPose(A_WIND, {RootJoint: [6, 0, 0], root: {fwd: -1.2}}, 1), "out5"), K(F + 0.5, A_WIND, "io"), K(F + 1.0, READY, "io")], T0);
  // the 24-stud target circle (shown while it winds up and flies), then the cloud
  const ringM = new THREE.Mesh(new THREE.RingGeometry(11.4, 12, 64), new THREE.MeshBasicMaterial({color: 0xfff2a0, transparent: true, opacity: 0.7, depthWrite: false, side: THREE.DoubleSide}));
  ringM.rotation.x = -Math.PI / 2; ringM.position.copy(C).setY(0.14);
  addFx(ringM, F + FLY, (o, u) => { o.material.opacity = 0.7 * Math.min(1, play.t / (T0 + 0.2)); o.scale.setScalar(1 + 0.03 * Math.sin(clockT * 8)); });
  const ev = [{t: L === "B" ? F + 0.04 : F, f: () => {
    const from = partPoint(mk("mortar." + L)[0]); MS.recoil = 1; MS.cup = 0; flash(from, 5, 0xd8ffb0); shake = Math.max(shake, 0.5); fovPunch = 1.5;
    for (let i = 0; i < 6; i++) puff(from, new THREE.Vector3((Math.random() - .5) * 4, 4 + Math.random() * 3, (Math.random() - .5) * 4), 1.6, 0xe8e8e8, 0.8);
    spawnShot({kind: "glob", from, target: () => C.clone().setY(1), T: FLY, H: L === "B" ? 8 : 6.5, onHit: p => {
      splash(p, 46, 1.5); shake = Math.max(shake, 0.7); hitStop = 0.05; groundRing(C, 12, 0xb8ff70, 0.5);
      const disc = new THREE.Mesh(new THREE.CircleGeometry(12, 48), new THREE.MeshBasicMaterial({color: 0x7ed040, transparent: true, opacity: 0, depthWrite: false}));
      disc.rotation.x = -Math.PI / 2; disc.position.copy(C).setY(0.1);
      addFx(disc, 5, (o, u) => { o.material.opacity = 0.22 * Math.min(1, u * 12) * Math.min(1, (1 - u) * 6); });
      for (let i = 0; i < 34; i++) { const a = Math.random() * Math.PI * 2, r = Math.sqrt(Math.random()) * 11; const s = sprite(T_MIST, 0x9cf05a, 7 + Math.random() * 5, false);
        s.position.set(C.x + Math.cos(a) * r, 2 + Math.random() * 5, C.z + Math.sin(a) * r); const ph = Math.random() * 6;
        addFx(s, 5, (o, u, dt) => { o.position.y += Math.sin(clockT * 1.3 + ph) * dt * 0.8; o.material.opacity = 0.42 * Math.min(1, u * 10) * Math.min(1, (1 - u) * 5); o.scale.setScalar((7 + ph) * (0.7 + 0.3 * Math.min(1, u * 6))); }); }
      for (const R of [R0, R1]) { R.flinch = 1; R.flash = 0.12; R.flashCol = [0.35, 0.95, 0.15]; venomOn(R, 2, 5, "cough"); }
      textTag(C.clone().setY(16), "POISON CLOUD · 5 s", "#b8ff70", 2.2);
    }});
  }}];
  return {frame: [new THREE.Vector3(0, 0, 4), new THREE.Vector3(0, 0, -60)], keys, ev,
    update(t, dt) { const e = L === "B" ? 0 : t < T0 ? 0 : t < T0 + 0.4 ? E.io((t - T0) / 0.4) : t < F + 0.7 ? 1 : Math.max(0, 1 - (t - F - 0.7) / 0.5);
      MS.elev = e; MS.recoil = Math.max(0, MS.recoil - dt * 4); if (t > F + 1.6) MS.cup = 1; }};
}

function hissTrack(L) {
  place(R0, -5, -19); place(R1, 7, -24);
  const T0 = 0.6, B = T0 + 0.5;
  const keys = idleIntro([K(T0 + 0.45, HISS_WIND, "io"), K(B + 0.05, HISS_BLAST, "out5"), K(B + 0.4, HISS_BLAST), K(B + 1.0, READY, "io")], T0);
  const ev = [{t: B, f: () => {
    MS.pump = 1; hitStop = 0.06; shake = 1; fovPunch = 3;
    const from = partPoint(mk("hiss." + L)[0]);
    for (let i = 0; i < 6; i++) later(i * 0.05, () => {
      const m = new THREE.Mesh(new THREE.TorusGeometry(1, 0.08, 6, 40, rad(80)), new THREE.MeshBasicMaterial({color: 0xd8ccff, transparent: true, opacity: 0.9, depthWrite: false}));
      m.position.copy(from); m.rotation.set(0, 0, rad(50)); addFx(m, 0.55, (o, u) => { o.position.set(from.x, from.y - u * 4, from.z - 30 * u); const r = 1 + 17 * u; o.scale.set(r, r * 0.55, r); o.material.opacity = 0.9 * (1 - u); });
    });
    for (const R of [R0, R1]) later(0.08 + Math.abs(R.pos.z) / 120, () => {
      R.flinch = 1; R.side = 0; R.push = 7; R.pushDir.copy(R.pos).sub(dilo.pos).setY(0).normalize(); R.flash = 0.12; R.flashCol = [0.7, 0.6, 1];
      flash(rapChest(R), 6, 0xd8ccff);
      textTag(headOf(R).add(R.pushDir.clone().multiplyScalar(6)).setY(18), "SILENCED · 3 s", "#c9b8ff", 3);
    });
  }}];
  return {frame: [new THREE.Vector3(0, 0, 2), new THREE.Vector3(0, 0, -32)], keys, ev, frill: [[T0 + 0.15, B + 0.9]],
    update(t, dt) { MS.charge = t < T0 ? 0 : t < B ? (t - T0) / (B - T0) : Math.max(0, 1 - (t - B) / 0.3); MS.pump = Math.max(0, MS.pump - dt * 3);
      const on = t > B && t < B + 0.6; cone30.visible = on || (t > T0 + 0.1 && t < B); cone30.position.set(0, 0.09, 0);
      if (cone30.visible) setCone(cone30, true, on ? 1.8 * (1 - (t - B) / 0.6) + 0.2 : 0.6); }};
}

function spineTrack(L) {
  const at = a => new THREE.Vector3(Math.sin(a) * 15, 0, -Math.cos(a) * 15);
  const a0 = rad(315), a1 = rad(225); // both on spine directions of every look, and away from the +X camera side
  R0.show = true; R0.pos.copy(at(a0)); R0.yaw = yawTo(R0.pos, new THREE.Vector3()); R1.show = true; R1.pos.copy(at(a1)); R1.yaw = yawTo(R1.pos, new THREE.Vector3());
  const T0 = 0.6, F = T0 + 0.42;
  const keys = idleIntro([K(T0 + 0.35, CURL, "io"), K(F + 0.04, BURST, "out5"), K(F + 0.4, BURST), K(F + 1.1, READY, "io")], T0);
  const ev = [{t: F, f: () => {
    MS.loaded = 0; shake = 0.9; hitStop = 0.05; fovPunch = 2;
    const ms = mk("spine." + L);
    for (let i = 0; i < 12; i++) {
      const p = partPoint(ms[i]); let dir;
      const a = ms[i].name; dir = new THREE.Vector3(Math.sin(a), 0.1, -Math.cos(a)); // every look: 12 directions, 30 deg apart
      dir.normalize(); spine(p, dir, 2.6); flash(p, 2, 0xd8ffb0);
      for (const R of [R0, R1]) { const to = R.pos.clone().sub(dilo.pos).setY(0).normalize(); const f2 = dir.clone().setY(0).normalize();
        if (to.dot(f2) > Math.cos(rad(16)) && !R._hit) { R._hit = 1; later(0.22, () => { const cp = rapChest(R); flash(cp, 4, 0xd8ffb0); numberPop(cp.clone().add(new THREE.Vector3(0, 5, 0)), 4, "hit"); R.flinch = 1; R.flash = 0.12; R.flashCol = [0.35, 0.95, 0.15]; R.push = 1.5; R.pushDir.copy(to); venomOn(R, 2, 3); }); } }
    }
    groundRing(dilo.pos, 20, 0xb8ff70, 0.45);
  }}];
  R0._hit = 0; R1._hit = 0;
  // A / B: the 12 directions are fixed; make sure each raptor sits on one of them (A: every 30 deg from 15; B: the racks' fans)
  return {frame: [new THREE.Vector3(-13, 0, -13), new THREE.Vector3(13, 0, 13)], keys, ev, tremble: [T0 + 0.05, F], frill: [[T0 + 0.08, F + 0.8]],
    update(t) { MS.extend = t < T0 ? 0 : t < F ? E.io((t - T0) / (F - T0)) : 0; if (t > F + 1.2) MS.loaded = 1; }};
}

function pumpTrack(L) {
  place(R0, -4, -34);
  const T0 = 0.8, J = T0 + 0.62;
  let keys = [K(0, SICK), K(T0, SICK), K(T0 + 0.5, PRIME, "io"), K(J, JOLT, "out5"), K(J + 0.45, PROUD, "io"), K(J + 1.4, READY, "io")];
  const tags = [];
  const ev = [{t: 0.01, f: () => { const h = dilo.pos.clone(); tags.push(textTag(h.clone().add(new THREE.Vector3(0, 24, 0)), "POISONED", "#b8ff70", 9), textTag(h.clone().add(new THREE.Vector3(0, 21, 0)), "SLOWED 40%", "#ffd34d", 9), textTag(h.clone().add(new THREE.Vector3(0, 18, 0)), "BLINDED", "#cfd3dc", 9)); }},
    {t: J, f: () => {
      hitStop = 0.06; shake = 0.6; fovPunch = 2.5;
      const p = partPoint(mk("pump." + L)[0]); flash(p, 12, 0xbfefff);
      tags.forEach(o => { flash(o.position.clone(), 6, 0xffffff); killFx(o); });
      numberPop(dilo.pos.clone().add(new THREE.Vector3(0, 22, 0)), "+30", "venom");
      textTag(dilo.pos.clone().add(new THREE.Vector3(0, 26, 0)), "IMMUNE · 4 s", "#9fe6ff", 4);
      groundRing(dilo.pos, 12, 0x9fe6ff, 0.5);
      const sh = new THREE.Mesh(new THREE.SphereGeometry(11, 24, 16), new THREE.MeshBasicMaterial({color: 0x9fe6ff, transparent: true, opacity: 0.0, depthWrite: false, wireframe: true}));
      addFx(sh, 4, (o, u) => { o.position.copy(dilo.pos).setY(8); o.rotation.y = clockT * 0.4; o.material.opacity = 0.32 * Math.min(1, u * 15) * Math.min(1, (1 - u) * 8); });
    }},
    {t: J + 1.5, f: () => { spawnShot({kind: "glob", from: headOf(R0), target: () => dilo.pos.clone().add(new THREE.Vector3(0, 8, -9)), T: 0.5, H: 1, onHit: p => { flash(p, 8, 0x9fe6ff); sparks(p, new THREE.Vector3(0, 0.3, -1), 10, 0xbfefff); textTag(p.clone().setY(16), "BLOCKED", "#9fe6ff", 1.2); }}); R0.lunge = 1; }}];
  return {frame: [new THREE.Vector3(0, 0, 6), new THREE.Vector3(0, 0, -34)], keys, ev,
    tint: t => t < J ? [0.03, 0.08 + 0.04 * Math.sin(clockT * 7), 0.01] : t < J + 4 ? [0.02, 0.06, 0.1] : null,
    update(t, dt) { MS.pump = t < T0 ? 0 : t < T0 + 0.45 ? E.io((t - T0) / 0.45) : t < J ? 1 - E.in2((t - T0 - 0.45) / (J - T0 - 0.45)) : 0;
      MS.fluid = t < J - 0.05 ? 1 : Math.max(0.15, 1 - (t - J + 0.05) / 0.25); if (t > J + 2.6) MS.fluid = Math.min(1, 0.15 + (t - J - 2.6) / 1.2);
      MS.jab = L === "C" ? (t > J - 0.08 && t < J + 0.2 ? 1 : 0) : 0;
      if (t < J && Math.random() < dt * 14) { const part = dilo.parts[(Math.random() * 120) | 0]; if (part && part.kind !== "mech") droplet(partPoint(part), new THREE.Vector3((Math.random() - .5) * 2, -3, (Math.random() - .5) * 2), 0.9, 0.6, 30); } },
    extra(target) { if (L === "C" && play.t > T0 + 0.2 && play.t < J + 0.4) { const w = play.t < J - 0.05 ? E.io((play.t - T0 - 0.2) / (J - T0 - 0.25)) : 1 - E.io((play.t - J) / 0.4); target.ArmL = [target.ArmL[0] - 34 * w, target.ArmL[1], target.ArmL[2]]; } }};
}

function jetsTrack(L) {
  place(R0, -7, -24, rad(-90)); // beside the path, on the far side from the +X camera
  const T0 = 0.6, GO = T0 + 0.34, DUR = 0.28;
  const keys = idleIntro([K(T0 + 0.3, DASH_LOW, "io"), K(GO + 0.04, DASH_GO, "out5"), K(GO + DUR, DASH_GO), K(GO + DUR + 0.22, DASH_SKID, "out"), K(GO + DUR + 0.9, READY, "io")], T0);
  // move-direction arrow on the ground
  const arrow = new THREE.Mesh(new THREE.PlaneGeometry(2.2, 12), new THREE.MeshBasicMaterial({map: dashTex, color: 0xffd34d, transparent: true, opacity: 0.9, depthWrite: false}));
  arrow.rotation.x = -Math.PI / 2; arrow.position.set(0, 0.12, -12);
  addFx(arrow, GO, (o, u) => { o.material.opacity = 0.85 * Math.min(1, u * 4); dashTex.offset.y = -clockT * 2; });
  return {frame: [new THREE.Vector3(0, 0, 6), new THREE.Vector3(0, 0, -48)], keys,
    ev: [{t: GO, f: () => { MS.pips = 2; shake = 0.7; fovPunch = 4; hitStop = 0.03; for (const m of mk("jets." + L)) flash(partPoint(m), 7, 0xffb050); textTag(dilo.pos.clone().add(new THREE.Vector3(0, 22, 0)), "CHARGES 2 / 3", "#ffd34d", 1.6); }},
      {t: GO + 0.25, f: () => { R0.flinch = 1; R0.flash = 0.12; R0.flashCol = [0.35, 0.95, 0.15]; venomOn(R0, 2, 3, "cough"); }}],
    dash: t => t < GO ? 0 : t < GO + DUR ? 40 * E.out((t - GO) / DUR) : 40 + 2 * E.out(Math.min(1, (t - GO - DUR) / 0.25)),
    update(t, dt) {
      MS.heat = t < T0 ? 0 : t < GO ? (t - T0) / (GO - T0) : t < GO + DUR ? 1 : Math.max(0, 1 - (t - GO - DUR) / 0.5);
      MS.extend = L === "B" ? (t < T0 ? 0 : t < GO ? E.io((t - T0) / (GO - T0)) : Math.max(0, 1 - (t - GO) / 0.08) * -0.5) : 0;
      if (t > GO + 2.2) MS.pips = 3;
      if (t > T0 && t < GO + DUR + 0.1) for (const m of mk("jets." + L)) { const p = partPoint(m);
        if (t > GO) { const s = sprite(T_SPARK, 0xffb050, 3.2, true); s.position.copy(p); addFx(s, 0.14, (o, u) => { o.material.opacity = 1 - u; o.scale.setScalar(3.2 * (1 - u * 0.6)); }); }
        else if (Math.random() < dt * 30) { const s = sprite(T_FLASH, 0xffd090, 1.6 * MS.heat + 0.4, true); s.position.copy(p); addFx(s, 0.08, (o, u) => { o.material.opacity = 1 - u; }); } }
      if (t > GO && t < GO + DUR + 0.05 && Math.random() < dt * 90) { const p = dilo.pos.clone().add(new THREE.Vector3((Math.random() - .5) * 4, 1.5 + Math.random() * 2, 4 + Math.random() * 3));
        const s = sprite(T_MIST, 0x9cf05a, 5, false); s.position.copy(p); addFx(s, 3, (o, u, d) => { o.position.y += d * 0.5; o.scale.setScalar(5 * (1 + u)); o.material.opacity = 0.45 * Math.min(1, u * 10) * Math.min(1, (1 - u) * 4); }); }
    }};
}

function overTrack(L) {
  place(R0, -4, -36);
  const T0 = 0.6, ON = T0 + 0.7, END = ON + 4.6;
  const keys = [K(0, READY), K(T0, READY), K(T0 + 0.55, HISS_WIND, "io"), K(ON + 0.05, ROAR, "out5"), K(ON + 0.5, ROAR), K(ON + 0.85, SPIT_SET, "io")];
  const ev = [{t: ON, f: () => { hitStop = 0.06; shake = 0.8; fovPunch = 3; const p = partPoint(mk("over." + L)[0]); flash(p, 14, 0xd8ffb0); groundRing(dilo.pos, 16, 0xb8ff70, 0.6);
    textTag(dilo.pos.clone().add(new THREE.Vector3(0, 27, 0)), "OVERDRIVE · 8 s", "#b8ff70", 2); }},
    {t: ON + 0.9, f: () => textTag(dilo.pos.clone().add(new THREE.Vector3(0, 24, 0)), "NO DART RECHARGE", "#ffd34d", 1.6)}];
  for (let i = 0; i < 10; i++) { const t = ON + 1.0 + i * 0.36;
    keys.push(K(t - 0.08, SPIT_SET, "io"), K(t + 0.02, SPIT_GO, "out5"));
    ev.push({t, f: () => { const from = mouthPoint(); flash(from, 3, 0xd8ff8a); spawnShot({kind: "dart", from, target: () => rapChest(R0), T: 0.28, H: 0.25, onHit: p => {
      lightHit(R0, p, 6); venomOn(R0, 4, 3, "now"); if (i === 0) textTag(headOf(R0).setY(18), "VENOM x2", "#b8ff70", 1.6); }}); }});
  }
  keys.push(K(END - 0.1, SPIT_SET, "io"), K(END + 0.6, READY, "io"));
  // the 8 s timer ring round the dilo (played faster here)
  const tm = new THREE.Mesh(new THREE.RingGeometry(9.2, 10, 64, 1, Math.PI / 2, Math.PI * 2), new THREE.MeshBasicMaterial({color: 0xb8ff70, transparent: true, opacity: 0, depthWrite: false, side: THREE.DoubleSide}));
  tm.rotation.x = -Math.PI / 2;
  addFx(tm, END + 0.4, (o, u) => { const t = play.t; o.position.copy(dilo.pos).setY(0.13); const k = t < ON ? 0 : Math.max(0, 1 - (t - ON) / (END - ON));
    o.material.opacity = t < ON ? 0 : 0.6; o.geometry.dispose(); o.geometry = new THREE.RingGeometry(9.2, 10, 64, 1, Math.PI / 2, Math.max(0.001, Math.PI * 2 * k)); });
  return {frame: [new THREE.Vector3(0, 0, 4), new THREE.Vector3(0, 0, -38)], keys, ev, frill: [[ON - 0.1, END]],
    tint: t => { const g = MS.glow; return g > 0 ? [0.02 * g, (0.06 + 0.03 * Math.sin(clockT * 10)) * g, 0.01 * g] : null; },
    frillTint: () => MS.glow > 0.3 ? 0x5cd22a : null,
    update(t) { MS.glow = t < T0 ? 0 : t < ON ? (t - T0) / (ON - T0) : t < END ? 1 : Math.max(0, 1 - (t - END) / 0.6); }};
}

function allTrack() { R0.show = false; R1.show = false; return {frame: [new THREE.Vector3(0, 0, 8), new THREE.Vector3(0, 0, -10)], keys: [K(0, READY)]}; }

// looks: name, ref (borrowed from), mount, notes; one rec per part
const LOOKS = {
  gatling: {
    A: {name: "A · Chin Gatling", sub: "4-barrel rotary under the jaw", rec: "Fires from the mouth line, where the darts already come from: reads as 'spit, but a machine gun'.",
      ref: "The A-10's nose cannon and the Zoids Gun Sniper's chin gun.", mount: "Lower jaw (rides the bite), drum under the throat.",
      notes: ["Spins up while it braces, then 8 darts alternate between the two raptors.", "Small: hidden from straight behind, so the player camera sees mostly the drum."]},
    B: {name: "B · Shoulder Minigun", sub: "6-barrel cannon on the +X shoulder", ref: "Armored Core shoulder gatlings; the Zoids Command Wolf's back cannon.", mount: "+X shoulder (camera side), drum on the back, belt between.",
      notes: ["Biggest, most 'mecha' silhouette; easy to read from the player camera.", "Fires off-centre from the mouth, so it reads less like the dilo's own venom."]},
    C: {name: "C · Twin Hood Repeaters", sub: "a repeater each side of the neck", ref: "Horizon's Ravager head cannon; twin-linked guns on a gunship.", mount: "Both sides of the neck under the frill; the hood flares while it fires.",
      notes: ["Left / right alternate, and the hood flare is the tell.", "Two barrels each side of a slim neck look busy next to the frill."]},
  },
  mortar: {
    A: {name: "A · Back Mortar", sub: "stubby tube on a turntable on the back", rec: "Clear from every angle: the tube rises, kicks and lays back, and the lob starts above the body.",
      ref: "Zoids Cannon Tortoise / a Stokes mortar.", mount: "Back (Torso), 3 spare shells racked on the +X side.",
      notes: ["Laid back while slotted; rises to 45° in the wind-up.", "The body crouches into the recoil (no landing FX)."]},
    B: {name: "B · Tail Sling", sub: "a basket on the tail flings the shell", ref: "A trebuchet; Monster Hunter Uragaan's tail slam lobbing debris.", mount: "Tail (Tail1 rail, Tail2 basket), shell visible in the basket.",
      notes: ["Most animal: the whole tail whips over the back.", "A 60-stud throw from the tail looks a bit like magic."]},
    C: {name: "C · Chest Launcher", sub: "chem tank under the chest, tube at the neck", ref: "Horizon's Bellowback fluid sac and its launcher.", mount: "Tank under the chest; tube on the +X side of the neck base.",
      notes: ["The green tank says 'toxin' at a glance.", "The tube hides behind the neck from the left side."]},
  },
  hiss: {
    A: {name: "A · Hood Speakers", sub: "6 speaker cones set into the frill", rec: "Matches the text ('frill speakers') and uses the dilo's signature hood: the flare is the tell.",
      ref: "An LRAD sound cannon; Monster Hunter Rajang / Tigrex roar shockwaves.", mount: "Frill (fan out with the hood; small on the folded frill).",
      notes: ["The hood flares in the wind-up, the speakers swell, then the cone fires.", "When folded they sit small on the neck, so the part is easy to miss while slotted."]},
    B: {name: "B · Throat Horn", sub: "brass horn bell under the throat", ref: "A gramophone horn / Fallout's sonic emitter.", mount: "Under the throat, compressor on the chest.",
      notes: ["Always visible; the bell flares at the blast.", "Brass reads more steampunk than the other parts."]},
    C: {name: "C · Crest Resonators", sub: "tuning-fork prongs on the head crests", ref: "A tuning fork; Monster Hunter Zinogre's charged horns.", mount: "Head crests (top of the head).",
      notes: ["Buzzes visibly while charging.", "Thin: hard to see at range and from the player camera."]},
  },
  spine: {
    A: {name: "A · Quill Collar", sub: "a ring of 12 launch tubes round the neck base", ref: "Monster Hunter Nargacuga's tail spikes; a porcupine.", mount: "Neck base ring (fires out on every side).",
      notes: ["Shows all 12 at rest, so the count reads.", "The collar hides the frill hinge."]},
    B: {name: "B · Back Quiver", sub: "two angled racks of 6 along the back", ref: "A stegosaur's plates; Monster Hunter Espinas' back thorns.", mount: "Back, two rows (each covers one side).",
      notes: ["Biggest silhouette, readable from the player camera.", "Fires from the back, not the frill (the text says frill)."]},
    C: {name: "C · Frill Barbs", sub: "a barb on each of the 12 frill rims", rec: "The text's own idea: the frill fires them. 12 rims = 12 spines, and the hood flare is the tell.",
      ref: "The Jurassic Park dilophosaur's hood + Halo's Needler.", mount: "Frill rims (out with the hood); 2 barb magazines on the neck show while folded.",
      notes: ["Barbs only show on the flared hood; the magazines keep the part visible while slotted.", "Spines leave from head height, so they read well over the ground."]},
  },
  pump: {
    A: {name: "A · Back Pump", sub: "glass tank of blue antivenom, piston on top", rec: "Biggest, clearest motion (piston + draining tank) and it leaves the head and arms free for the other parts.",
      ref: "BioShock's Big Daddy tanks; a dialysis pump.", mount: "Back, two hoses into the neck base.",
      notes: ["The tank drains in one stroke and refills over the recharge.", "Competes for the back with the Back Mortar / Back Quiver / Gland Tanks."]},
    B: {name: "B · Vial Bandolier", sub: "4 vials on a strap round the neck base", ref: "Bloodborne's blood vials; a bandolier.", mount: "Neck base strap.",
      notes: ["Compact and readable from the front.", "Sits where the Quill Collar would go."]},
    C: {name: "C · Arm Injector", sub: "injector gauntlet on the +X arm", ref: "Fallout's Stimpak; Apex medics' injectors.", mount: "+X arm (camera side).",
      notes: ["The arm jab is a very clear 'I used a heal' gesture.", "Small arms: the gauntlet is tiny at range."]},
  },
  jets: {
    A: {name: "A · Hip Jet Pods", sub: "a jet pod on each hip", ref: "Armored Core quick boost.", mount: "Both hips; 3 charge lights on the +X pod.",
      notes: ["Clean and symmetrical.", "Close to the Pachy's hip-thruster Servo Dash."]},
    B: {name: "B · Calf Springs", sub: "coil springs + heel jets on the shins", ref: "Spring-heeled stilts; Titanfall's jump kit.", mount: "Back of both shins; charge lights on the +X shin.",
      notes: ["'Spring' Jets taken literally: the coils compress, then fire.", "Low on the legs: busy next to the walk cycle."]},
    C: {name: "C · Tail Booster", sub: "one big booster along the tail base", rec: "Different from the Pachy's hip thrusters, and its thrust line points straight along the dash.",
      ref: "Zoids Blade Liger boosters.", mount: "Top of the tail base (Tail1); 3 charge lights on its +X side.",
      notes: ["One big flame behind the dino reads at any range.", "The tail can't swing as freely with a booster on it (looks only; nothing changes)."]},
  },
  over: {
    A: {name: "A · Venom Reactor", sub: "a glowing core in the chest, fins on the back", rec: "Visible from the front and the side for the whole 8 s, and it doesn't fight the head parts.",
      ref: "Iron Man's arc reactor; a Zoids core.", mount: "Chest front; cooling fins along the back open in Overdrive.",
      notes: ["The core pulses and the fins open while it's on.", "Front-facing: from the player camera you see the fins, not the core."]},
    B: {name: "B · Gland Tanks", sub: "two tall venom tanks on the back", ref: "Mad Max nitrous bottles.", mount: "Back, hoses up the neck to the jaw.",
      notes: ["Easy to read from behind (player camera).", "Back slot again (clashes with the mortar / pump / quiver looks)."]},
    C: {name: "C · Crest Capacitors", sub: "glowing plates along the head crests", ref: "Monster Hunter Zinogre's charged state.", mount: "Head crests, heat sink behind the skull.",
      notes: ["Puts the glow where the darts come from.", "Same spot as the Crest Resonators (Sonic Hiss C)."]},
  },
};
LOOKS.all = {A: {name: "All A", sub: "every part's A look", ref: "—", mount: "—", notes: ["Clash check only: a player slots 4 of the 7."]},
  B: {name: "All B", sub: "every part's B look", ref: "—", mount: "—", notes: ["Clash check only: a player slots 4 of the 7."]},
  C: {name: "All C", sub: "every part's C look", ref: "—", mount: "—", notes: ["Clash check only: a player slots 4 of the 7."]},
  R: {name: "Recommended", sub: "the recommended look of each", ref: "—", mount: "—", notes: ["Clash check only: a player slots 4 of the 7.", "Mortar A, Pump A and the Reactor fins all use the back."]}};
const PHASES = {
  gatling: T => [[0, 0.6, "Slotted: the part at rest"], [0.6, 0.95, "Braces, the barrels spin up"], [0.95, 1.95, "8 auto-aimed darts in 1 s, each adds venom"], [1.95, 2.6, "Spins down, smoke"], [2.6, 3.2, "Recovers; the venom stacks tick"]],
  mortar: T => [[0, 0.6, "Slotted: the part at rest"], [0.6, 1.15, "Crouches / loads, the 24-stud circle shows"], [1.15, 2.3, "Fires: the shell lobs 50 studs"], [2.3, 4.6, "Bursts into a 24-stud poison cloud (5 s)"], [4.6, 7.3, "Recovered; the cloud keeps ticking"]],
  hiss: T => [[0, 0.6, "Slotted: the part at rest"], [0.6, 1.1, "Hood flares, the emitters charge, the 30-stud cone shows"], [1.1, 1.6, "Blast: knock-back, SILENCED 3 s"], [1.6, 3.8, "Hood folds, recovers"]],
  spine: T => [[0, 0.6, "Slotted: the part at rest"], [0.6, 1.02, "Curls and shivers, the hood flares, spines poke out"], [1.02, 1.5, "12 spines all around, 4 + venom each"], [1.5, 3.2, "Recovers; the spines reload"]],
  pump: T => [[0, 0.8, "Poisoned, slowed, blinded"], [0.8, 1.42, "Primes the pump"], [1.42, 1.9, "Injects: debuffs gone, +30, IMMUNE 4 s"], [1.9, 5.4, "Immune: a raptor's shot is blocked"]],
  jets: T => [[0, 0.6, "Slotted: the part at rest, 3 charges"], [0.6, 0.94, "Drops low, the jets heat (move direction shown)"], [0.94, 1.22, "40-stud dash, poison trail"], [1.22, 2.2, "Skids to a stop (no landing FX), 2 charges left"], [2.2, 3.4, "The trail poisons the raptor beside it"]],
  over: T => [[0, 0.6, "Slotted: the part at rest"], [0.6, 1.3, "Rears up, the part charges"], [1.3, 2.3, "OVERDRIVE: glow, hood flared"], [2.3, 5.9, "Darts with no recharge, venom x2 (8 s shown faster)"], [5.9, 6.8, "Fades out"]],
  all: T => [[0, 4, "All 7 parts of this letter on the dino at once"]],
};
const LEN = {gatling: 3.2, mortar: 7.3, hiss: 3.8, spine: 3.2, pump: 5.4, jets: 3.4, over: 6.8, all: 4};
const BUILD = {gatling: gatlingTrack, mortar: mortarTrack, hiss: hissTrack, spine: spineTrack, pump: pumpTrack, jets: jetsTrack, over: overTrack, all: allTrack};
const REC = {gatling: "A", mortar: "A", hiss: "A", spine: "C", pump: "A", jets: "C", over: "A"};

// ---------- the player ----------
let cur = 0, variant = REC.gatling, playing = true, speed = 1, camMode = "hero";
const M = () => MOVES[cur], LK = () => LOOKS[M().id][variant];
function lookOn(look) {
  const id = M().id;
  if (id !== "all") return look === id + "." + variant;
  const [pid, L] = look.split(".");
  return variant === "R" ? REC[pid] === L : L === variant;
}
function resetFx() { fx.splice(0).forEach(e => scene.remove(e.obj)); shots.splice(0).forEach(s => { scene.remove(s.mesh); scene.remove(s.glow); }); delayed = []; cone30.visible = false; }
function start() {
  resetFx(); msReset();
  for (const R of raps) { R.flinch = 0; R.flash = 0; R.push = 0; R.venom = null; R.slow = 0; R.path = null; R.run = 0; R.lunge = 0; R.show = false; }
  aim.on = 0; aim.R = null; aim.yaw = 0;
  for (const k in aimCone) aimCone[k].visible = false;
  play = {track: null, t: 0, fired: new Set()};
  play.track = BUILD[M().id](variant);
  frill.open = false; frill.t = 9; dilo.sac = 1; springs = {}; rootSpring.x = 0; rootSpring.v = 0; hitStop = 0; shake = 0; fovPunch = 0;
  dilo.pos.set(0, 0, 0);
}
function idleLayer(t) {
  const b = Math.sin(t * 2.1), b2 = Math.sin(t * 2.1 + 1.2);
  return {RootJoint: [b * 1.0, 0, 0], Neck: [b * 1.6, Math.sin(t * 0.7) * 4, 0], Head: [-b * 1.4, Math.sin(t * 0.9 + 1) * 3, 0], Jaw: [Math.max(0, Math.sin(t * 0.5)) * -3, 0, 0],
    ArmL: [b2 * 3, 0, 0], ArmR: [b2 * 3, 0, 0],
    Tail1: [b * 1.2, Math.sin(t * 1.3) * 4, 0], Tail2: [0, Math.sin(t * 1.3 - .6) * 5, 0], Tail3: [0, Math.sin(t * 1.3 - 1.2) * 6, 0], Tail4: [0, Math.sin(t * 1.3 - 1.8) * 7, 0], Tail5: [0, Math.sin(t * 1.3 - 2.4) * 8, 0]};
}
function inWin(list, t) { return (list || []).some(([a, b]) => t >= a && t < b); }
function frillScale() {
  if (frill.open) { const u = Math.min(1, frill.t / 0.13); let s = 0.2 + 0.8 * E.back(u); if (frill.t < 0.3) s += Math.sin(frill.t * 95) * 0.035 * (1 - frill.t / 0.3); return s; }
  return frill.t < 0.1 ? 1 - 0.75 * (frill.t / 0.1) : 0;
}
const frillMeshes = dilo.parts.filter(p => p.kind === "frill");
frillMeshes.forEach(p => { p.mesh.material = p.mesh.material.clone(); });

function rapPose(R, dt) {
  R.rig.g.visible = R.show; if (!R.show) return;
  R.flinch = Math.max(0, R.flinch - dt * 2.6); R.flash = Math.max(0, R.flash - dt); R.push *= Math.pow(0.03, dt);
  if (R.lunge) R.lunge = Math.max(0, R.lunge - dt * 2.2);
  const L = R.lunge ? Math.sin(Math.PI * Math.min(1, (1 - R.lunge) * 1.4)) : 0;
  const f = E.out(R.flinch);
  let cough = 0;
  if (R.venom && R.venom.style === "cough") cough = R.venom.next < 0.5 && R.venom.next > 0.25 ? 1 : 0;
  R.rig.yaw = R.yaw; R.rig.pos.copy(R.pos).addScaledVector(R.pushDir, R.push);
  pose(R.rig, {RootJoint: [10 * f - 14 * L, 0, R.side * 8 * f], Neck: [12 * f - 20 * L - 18 * cough, Math.sin(clockT * 0.8) * 4 * (1 - f), 0], Head: [10 * f, 0, 0], Jaw: [-22 * f - 30 * L - 20 * cough, 0, 0],
    ArmL: [-25 * f + 20 * L, 0, 0], ArmR: [-25 * f + 20 * L, 0, 0], Tail1: [-10 * f, Math.sin(clockT * 1.3) * 4, 0], Tail2: [0, Math.sin(clockT * 1.3 - .7) * 5, 0],
    LegL: [-8 * f, 0, 0], LegR: [-8 * f, 0, 0], KneeL: [-10 * f, 0, 0], KneeR: [-10 * f, 0, 0]});
  if (R.rig.rest !== null) { R.rig.y = R.rig.rest; pose(R.rig, {}); }
  let g = 0;
  if (R.venom) { const V = R.venom; V.left -= dt; V.next -= dt; V.age += dt; V.drip += dt * 12; g = 0.1 + 0.06 * Math.sin(clockT * 9);
    while (V.drip >= 1) { V.drip -= 1; const part = R.rig.parts[(Math.random() * R.rig.parts.length) | 0]; const p = partPoint(part); if (p.y > 3) droplet(p, new THREE.Vector3((Math.random() - .5) * 2, -3, (Math.random() - .5) * 2), 0.9 + Math.random() * 0.7, 0.6, 30); }
    if (V.next <= 0 && V.left > -0.05) { V.next += 0.5; const cp = rapChest(R); numberPop(cp.clone().add(new THREE.Vector3((Math.random() - .5) * 3, 5, 0)), V.rate * 0.5, "venom"); R.flash = Math.max(R.flash, 0.06); R.flashCol = [0.3, 0.9, 0.12];
      if (V.style === "cough") puff(partPoint(R.rig.segs.Head[0]), new THREE.Vector3(0, 2, -3), 2.2, 0xb8ff70, 0.6); }
    if (V.left <= 0) R.venom = null; }
  const fl = R.flash > 0 ? 1 : 0;
  R.rig.mats.forEach(m => { m.emissive.setRGB(fl * R.flashCol[0] + (1 - fl) * g * 0.25, fl * R.flashCol[1] + (1 - fl) * g, fl * R.flashCol[2] + (1 - fl) * g * 0.1); });
}
raps.forEach(R => { pose(R.rig, {}); R.rig.y = R.rig.rest; R.rig.g.visible = false; });

const _fm = new THREE.Matrix4();
function frillMat(s) { s = Math.max(0.001, s); return _fm.makeTranslation(frillHub.x, frillHub.y, frillHub.z).multiply(new THREE.Matrix4().makeScale(s, s, s)).multiply(new THREE.Matrix4().makeTranslation(-frillHub.x, -frillHub.y, -frillHub.z)).clone(); }
function mechLocals() {
  for (const p of MECH) {
    const on = lookOn(p.look);
    let vis = on && !p.marker && (!p.show || p.show());
    let L = p.base;
    if (p.frill) { const s = p.frill === "min" ? Math.max(0.45, dilo.frillS) : dilo.frillS; if (p.frill !== "min" && s <= 0) vis = false; L = frillMat(s).multiply(p.base); }
    p.local = p.anim ? L.clone().multiply(p.anim(p)) : L.clone();
    p.mesh.visible = vis;
  }
}

function step(dt, noRender) {
  let mdt = dt * speed;
  if (hitStop > 0) { hitStop -= mdt; mdt *= 0.05; }
  idleT += mdt; clockT += mdt;
  let target = idleLayer(idleT);
  const tr0 = play.track;
  play.t = play.t + mdt;
  const mv = sample(tr0.keys, play.t);
  target = addPose(mv, target, 1);
  if (tr0.tremble && play.t > tr0.tremble[0] && play.t < tr0.tremble[1]) for (const n of ["Neck", "Head", "RootJoint"]) target[n] = target[n].map((v, i) => v + (i === 2 ? Math.sin(clockT * 80 + n.length) * 1.6 : i === 0 ? Math.sin(clockT * 70) * 1.2 : 0));
  const rootFwd = (mv.root && mv.root.fwd) || 0;
  for (const e of (tr0.ev || [])) { const k = "e" + e.t; if (!play.fired.has(k) && play.t >= e.t) { play.fired.add(k); e.f(); } }
  for (let i = delayed.length - 1; i >= 0; i--) if (play.t >= delayed[i].at) { const d = delayed[i]; delayed.splice(i, 1); d.f(); }
  if (tr0.update) tr0.update(play.t, mdt);
  for (const n of dilo.joints.map(j => j.n)) if (!target[n]) target[n] = [0, 0, 0];
  if (tr0.extra) tr0.extra(target);
  const want = inWin(tr0.frill, play.t); if (want !== frill.open) { frill.open = want; frill.t = 0; }
  frill.t += mdt; dilo.frillS = frillScale();
  const fs = Math.max(0.001, dilo.frillS);
  dilo.frillM.makeTranslation(frillHub.x, frillHub.y, frillHub.z).multiply(new THREE.Matrix4().makeScale(fs, fs, fs)).multiply(new THREE.Matrix4().makeTranslation(-frillHub.x, -frillHub.y, -frillHub.z));
  const P = springStep(target, mdt);
  for (let i = 0, n = Math.max(1, Math.ceil(mdt * 300)); i < n; i++) { const h = mdt / n; rootSpring.v += (400 * (rootFwd - rootSpring.x) - 2 * 0.9 * 20 * rootSpring.v) * h; rootSpring.x += rootSpring.v * h; }
  const dash = tr0.dash ? tr0.dash(play.t) : 0;
  dilo.yaw = 0; dilo.pos.set(0, 0, -(rootSpring.x + dash));
  mechLocals();
  dilo.y = 0; pose(dilo, P);
  let minY = Infinity;
  for (const p of diloFeet) for (let i = 0; i < 8; i++) { _c.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(p.mesh.matrix); minY = Math.min(minY, _c.y); }
  dilo.y = -minY; pose(dilo, P);
  const tint = tr0.tint ? tr0.tint(play.t) : null;
  dilo.mats.forEach(m => m.emissive.setRGB(tint ? tint[0] : 0, tint ? tint[1] : 0, tint ? tint[2] : 0));
  const ft = tr0.frillTint ? tr0.frillTint() : null;
  frillMeshes.forEach(p => { p.mesh.material.emissive.setHex(ft || 0x000000); p.mesh.material.emissiveIntensity = ft ? 0.35 + 0.15 * Math.sin(clockT * 6) : 1; });
  const gl = Math.max(MS.glow, MS.charge * 0.8, MS.heat * 0.6);
  GLOW_MATS.forEach(m => { m.emissive.setHex(m.userData.base); m.emissiveIntensity = 1 + gl * 1.6 * (0.8 + 0.2 * Math.sin(clockT * 12)); });
  raps.forEach(R => rapPose(R, mdt));
  updateShots(mdt);
  for (let i = fx.length - 1; i >= 0; i--) { const e = fx[i]; const fdt = mdt * (hitStop > 0 ? 0.2 : 1); e.t += fdt; const u = Math.min(1, e.t / e.life); e.update(e.obj, u, fdt); if (u >= 1) { scene.remove(e.obj); fx.splice(i, 1); } }
  if (noRender) return;
  shake = Math.max(0, shake - dt * 4.2); fovPunch = Math.max(0, fovPunch - dt * 14);
  const fr = tr0.frame;
  const mid = fr[0].clone().lerp(fr[1], 0.5).setY(9), span = fr[0].distanceTo(fr[1]) + 30;
  const hfov = 2 * Math.atan(Math.tan(rad(cam.fov / 2)) * cam.aspect), vfit = span * 0.5 / Math.tan(hfov / 2);
  let cp, look = mid;
  if (camMode === "hero") cp = mid.clone().add(new THREE.Vector3(1, 0.42, 0.12).normalize().multiplyScalar(vfit * 1.08));
  else if (camMode === "side") cp = mid.clone().add(new THREE.Vector3(1, 0.14, 0).normalize().multiplyScalar(vfit * 1.1));
  else if (camMode === "game") { cp = dilo.pos.clone().add(new THREE.Vector3(10, 30, 44)); look = dilo.pos.clone().add(new THREE.Vector3(0, 8, -26)); }
  else { // part close-up: the middle of the visible part pieces, seen from the +X side and a little in front
    const c = new THREE.Vector3(); let n = 0; for (const p of MECH) if (p.mesh.visible) { c.add(_c.setFromMatrixPosition(p.mesh.matrix)); n++; }
    if (!n) c.copy(partPoint(mouthParts.skull)); else c.divideScalar(n);
    cp = c.clone().add(new THREE.Vector3(17, 6, 5)); look = c; }
  camPos.lerp(cp, camMode === "part" ? 0.3 : 0.15); camLook.lerp(look, camMode === "part" ? 0.35 : 0.2);
  const sh = shake * shake;
  cam.position.copy(camPos).add(new THREE.Vector3((Math.random() - .5) * sh, (Math.random() - .5) * sh, (Math.random() - .5) * sh));
  cam.lookAt(camLook); cam.fov = 38 + fovPunch; cam.updateProjectionMatrix();
  sun.position.copy(mid).add(new THREE.Vector3(30, 70, 30)); sun.target.position.copy(mid);
  renderer.render(scene, cam);
}
const camPos = new THREE.Vector3(60, 26, -20), camLook = new THREE.Vector3(0, 9, -20);
function seek(t) { start(); const sp = speed; speed = 1; let n = 0; while (play.t < t - 1e-6 && n < 2000) { step(1 / 60, true); n++; } speed = sp; step(0); }

// ---------- UI ----------
const VARS = () => M().id === "all" ? ["R", "A", "B", "C"] : ["A", "B", "C"];
function renderAll() {
  const LS = LOOKS[M().id];
  $("moves").innerHTML = MOVES.map((m, i) => `<button class="tab" data-i="${i}" aria-pressed="${i === cur}">${m.name}<small style="color:${AREA[m.area][1]}">${AREA[m.area][0]}</small></button>`).join("");
  $("varRow").innerHTML = '<span class="lbl">Look</span>' + VARS().map(k => `<button class="var" data-var="${k}" aria-pressed="${k === variant}">${LS[k].name}${LS[k].rec ? ' <span class="rec">· recommended</span>' : ""}<small>${LS[k].sub}</small></button>`).join("");
  const v = LK(), ph = PHASES[M().id]();
  $("phases").innerHTML = ph.map(p => `<button class="ph" data-t="${p[0]}" aria-current="false"><i>${p[0].toFixed(2)}–${p[1].toFixed(2)} s</i>${p[2]}</button>`).join("");
  const AR = AREA[M().area];
  if (M().id === "all") {
    $("info").innerHTML = `<div class="kind" style="color:${AR[1]}">Clash check · ${v.name}</div><h2>All 7 parts, one letter</h2><table class="cmp">${MOVES.slice(0, 7).map(m => { const k = variant === "R" ? REC[m.id] : variant; return `<tr><th>${m.name}</th><td>${LOOKS[m.id][k].name} · ${LOOKS[m.id][k].mount}</td></tr>`; }).join("")}</table>`;
    $("part").innerHTML = `<div class="kind" style="color:${AR[1]}">Notes</div><ul>${v.notes.map(n => `<li>${n}</li>`).join("")}</ul>`;
    return;
  }
  const rows = ["A", "B", "C"].map(k => `<tr><th>${LS[k].name}${LS[k].rec ? " ★" : ""}</th><td>${LS[k].mount}</td></tr>`).join("");
  $("info").innerHTML = `<div class="kind" style="color:${AR[1]}">${AR[0]} · ${M().name} · ${v.name}</div><h2>Maxed out</h2><p>${M().max}</p><h2>What you see, in order</h2><ul>${ph.map(p => `<li>${p[2]}</li>`).join("")}</ul><p class="note"><b>Looks like:</b> ${v.ref}</p><table class="cmp">${rows}</table>`;
  const rk = REC[M().id], rl = LS[rk];
  $("part").innerHTML = `<div class="kind" style="color:${AR[1]}">${v.name} · where it sits</div><p>${v.mount}</p><ul>${v.notes.map(n => `<li>${n}</li>`).join("")}</ul><p class="note"><b>Recommended: ${rl.name}.</b> ${rl.rec}</p>` +
    (M().id === "gatling" ? '<p class="note">Damage per dart is not set yet; the mockup shows 3.</p>' : M().id === "mortar" ? '<p class="note">The cloud\'s poison per second is not set yet; the mockup shows the dart venom (2/s).</p>' : M().id === "jets" ? '<p class="note">Shows one dash of the 3; the trail\'s poison is not set yet (shown as the dart venom).</p>' : M().id === "over" ? '<p class="note">8 s shown in 4.6 s; darts here 6 each with x2 venom.</p>' : "");
}
$("moves").addEventListener("click", e => { const b = e.target.closest("[data-i]"); if (!b) return; cur = +b.dataset.i; variant = M().id === "all" ? "R" : REC[M().id]; renderAll(); start(); });
$("varRow").addEventListener("click", e => { const b = e.target.closest("[data-var]"); if (!b) return; variant = b.dataset.var; renderAll(); start(); });
$("phases").addEventListener("click", e => { const b = e.target.closest("[data-t]"); if (!b) return; seek(+b.dataset.t + 0.06); playing = false; syncPlay(); });
$("play").onclick = () => { playing = !playing; syncPlay(); };
function syncPlay() { $("play").textContent = playing ? "Pause" : "Play"; $("play").setAttribute("aria-pressed", playing); }
document.querySelectorAll("[data-speed]").forEach(b => b.onclick = () => { speed = +b.dataset.speed; document.querySelectorAll("[data-speed]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => { camMode = b.dataset.view; document.querySelectorAll("[data-view]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
$("scrub").addEventListener("input", e => { seek(+e.target.value / 1000 * LEN[M().id]); playing = false; syncPlay(); });
$("ver").textContent = "v" + ANIM_VERSION;
function resize() { const w = cv.clientWidth, h = cv.clientHeight; if (renderer.domElement.width !== Math.round(w * renderer.getPixelRatio())) { renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); } }
window.addEventListener("resize", resize);
let last = performance.now();
function loop(now) {
  const dt = Math.min(0.05, (now - last) / 1000); last = now;
  resize();
  if (playing && !window.__manual) { step(dt); if (play.t >= LEN[M().id]) start(); }
  else if (!window.__manual) step(0);
  $("scrub").value = Math.round(Math.min(1, play.t / LEN[M().id]) * 1000);
  $("clock").textContent = `${play.t.toFixed(2)} s${speed !== 1 ? " · 0.3×" : ""}`;
  const ph = PHASES[M().id]().find(p => play.t >= p[0] && play.t < p[1]);
  $("cap").textContent = ph ? ph[2] : "…";
  document.querySelectorAll(".ph").forEach(b => b.setAttribute("aria-current", !!ph && +b.dataset.t === ph[0]));
  requestAnimationFrame(loop);
}
renderAll(); start(); resize();
requestAnimationFrame(loop);
// test hook: __dilo.set(part, look, t, cam) seeks there and pauses
window.__dilo = {set(id, v, time, cm) { window.__manual = true; cur = MOVES.findIndex(m => m.id === id); variant = v; if (cm) { camMode = cm; camPos.set(60, 26, -20); } renderAll(); seek(time); for (let i = 0; i < 40; i++) step(0); },
  len: () => LEN[M().id], state: () => ({t: play.t, frill: dilo.frillS, fx: fx.length, shots: shots.length, vis: MECH.filter(p => p.mesh.visible).length})};
window.__ready = true;
