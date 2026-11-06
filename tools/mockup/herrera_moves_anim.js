// Herrera move animations mockup v0.1 (Mecha Dino Arena) — the Herrera's animation pass (Kepu 2026-11-05 20:25 "Next" after
// the looks went live in v472). Plays each move on the real Herrera (HerreraModelData) with the 11 picked v2 looks (Iron Claw
// Wing Blades, Glider Sword Wings, Quill Missile Pods, Smoke Stealth Generator, Lamellar Armour, Fang Siphons, Flash Crest,
// Tesla Coils, Drop Chute, Spit Sacs, Stim Shot), against raptor dummies. Each move: Now (as the game plays it, v472) vs
// A / B / C, every version shows wind-up -> action -> result -> recovery.
// Units: the model's (game studs / 2). Front = -Z, the camera side = +X. Joints: p+ lifts the front / swings a limb forward,
// Tail p- = up, Jaw p- = open, Arm r- spreads ArmL out.
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
const sm2 = u => { u = clamp01(u); return u * u * (3 - 2 * u); };
const AT = (tt, keys) => { // keyframes [[t, pose (object or fn(tt)), ease], ...] -> pose
  const P = k => typeof k[1] === "function" ? k[1](tt) : k[1];
  if (tt <= keys[0][0]) return P(keys[0]);
  for (let i = 1; i < keys.length; i++) if (tt < keys[i][0]) return mix(P(keys[i - 1]), P(keys[i]), (keys[i][2] || ease)(seg(tt, keys[i - 1][0], keys[i][0])));
  return P(keys[keys.length - 1]);
};
const plus = (...ps) => { const o = {}; for (const q of ps) for (const k in q) { const a = o[k] || [0, 0, 0]; o[k] = [a[0] + q[k][0], a[1] + q[k][1], a[2] + q[k][2]]; } return o; };
const hump = (tt, a, b) => tt > a && tt < b ? Math.sin(seg(tt, a, b) * Math.PI) : 0; // 0 -> 1 -> 0 between a and b

// ---------- stage ----------
lab.visible = false; island.visible = true;
island.children.forEach(c => { if (c.type === "Group") c.visible = false; });
scene.background = new THREE.Color(0x8fc6e8); scene.fog = new THREE.Fog(0x8fc6e8, 70, 200);
pose({});
const rig = dino.g;
function hideBody(names) { for (const n of names) if (dino.byName[n]) dino.byName[n].mesh.visible = false; }

// ---------- the 11 picked looks (as in the game since v472), each driven by its own use value / clock ----------
const LU = {};
function lookU(key, u, lt) { LU[key].u = u; LU[key].t = lt === undefined ? null : lt; }
function wrapLook(list, key) {
  LU[key] = {u: 0, t: null};
  for (const e of list) e.lookKey = key;
  const T = tt => LU[key].t === null ? tt : LU[key].t;
  for (const e of list) {
    if (e.place) { const o = e.place; e.place = (u, tt) => o(LU[key].u, T(tt)); }
    if (e.anim) { const o = e.anim; e.anim = (u, tt) => o(LU[key].u, T(tt)); }
    if (e.show) { const o = e.show; e.show = (u, tt) => o(LU[key].u, T(tt)); }
  }
}
const LOOKS = [["claw", clawWing, "attack"], ["wing", wingSword, "speed"], ["quill", quillPods, "attack"], ["smoke", smokeStealth, "eng"], ["plate", plateLamellar, "defense"],
  ["siphon", siphonFang, "health"], ["strobe", strobeCrest, "eng"], ["coil", breakTesla, "defense"], ["chute", calChute, "eng"], ["goo", gooSpit, "eng"], ["stim", adrStim, "health"]];
function buildRig() {
  clearEquip();
  for (const [key, fn, area] of LOOKS) { GLOW = AREA[area][2]; const n0 = equip.length; fn(); wrapLook(equip.slice(n0), key); }
  for (const e of equip) { scene.remove(e.mesh); rig.add(e.mesh); }
  for (const c of cables) for (const m of c.segs) { scene.remove(m); rig.add(m); }
}
buildRig();
const partNow = (part, p) => { rig.updateMatrixWorld(true); return new THREE.Vector3(...(p || [0, 0, 0])).applyMatrix4(dino.byName[part].mesh.matrix).applyMatrix4(rig.matrixWorld); };
function pieceAt(role, key, i) { const L = equip.filter(x => x.role === role && (!key || x.lookKey === key)); const e = L[i || 0]; if (!e) return new THREE.Vector3(); rig.updateMatrixWorld(true); return new THREE.Vector3().setFromMatrixPosition(e.mesh.matrix).applyMatrix4(rig.matrixWorld); }

// ---------- FX kit ----------
const fx = new THREE.Group(); scene.add(fx);
function mk(geo, mat) { const m = new THREE.Mesh(geo, mat); m.visible = false; fx.add(m); return m; }
const ADD = (c, o) => new THREE.MeshBasicMaterial({color: c, transparent: true, opacity: o, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide});
const CYL = new THREE.CylinderGeometry(0.5, 0.5, 1, 8), BOX = new THREE.BoxGeometry(1, 1, 1), BALL = new THREE.SphereGeometry(0.5, 14, 10);
function setSeg(m, a, b, th) { const d = b.clone().sub(a), L = d.length(); if (L < 1e-4) { m.visible = false; return; } m.visible = true; m.position.copy(a).add(b).multiplyScalar(0.5); m.quaternion.setFromUnitVectors(UP, d.normalize()); m.scale.set(th, L, th); }
function label(text, color, w) {
  const c = document.createElement("canvas"); c.width = w || 256; c.height = 96; const g = c.getContext("2d");
  g.font = "800 60px Nunito, Segoe UI, sans-serif"; g.textAlign = "center"; g.lineWidth = 10; g.strokeStyle = "rgba(0,0,0,.75)"; g.strokeText(text, c.width / 2, 70); g.fillStyle = color || "#fff"; g.fillText(text, c.width / 2, 70);
  const s = new THREE.Sprite(new THREE.SpriteMaterial({map: new THREE.CanvasTexture(c), transparent: true, depthTest: false})); s.scale.set(2.4 * c.width / 256, 0.9, 1); s.visible = false; fx.add(s); return s;
}
const POP = {hit: label("HIT", "#ff6b6b"), dazed: label("DAZED", "#ffd34d", 320), flash: label("FLASH!", "#fff4d8", 320), brk: label("BREAK!", "#7fe9ff", 320), poof: label("POOF!", "#e8ecf4", 320),
  lost: [label("?", "#ffffff"), label("?", "#ffffff")], heal: label("+25%", "#7dffb0"), speed: label("x1.4 SPEED", "#7dffb0", 448), quills: label("5 QUILLS", "#ffd34d", 384), slow: label("SLOWED", "#a6e22e", 320), bleed: label("BLEED", "#ff5a4e", 320)};
function pop(s, pos, k, rise) { s.visible = k > 0 && k < 1; if (!s.visible) return; s.position.copy(pos).add(new THREE.Vector3(0, 2.6 + k * (rise === undefined ? 1.2 : rise), 0)); s.material.opacity = 1 - Math.max(0, k - 0.6) / 0.4; }
const DUST = []; for (let i = 0; i < 24; i++) DUST.push(mk(BALL, new THREE.MeshLambertMaterial({color: 0xd8c9a0, transparent: true, opacity: 0.7, depthWrite: false})));
let dustIdx = 0;
function dust(center, k, spread, n) { for (let i = 0; i < n; i++) { const m = DUST[dustIdx++ % DUST.length]; if (k <= 0 || k >= 1) continue; const a = i / n * Math.PI * 2 + i; m.visible = true; m.position.set(center.x + Math.cos(a) * spread * k, 0.25 + k * 0.6 + (i % 3) * 0.12, center.z + Math.sin(a) * spread * k); m.scale.setScalar(0.4 + k * 0.9); m.material.opacity = 0.7 * (1 - k); } }
const SMOKES = []; for (let i = 0; i < 26; i++) SMOKES.push(mk(BALL, new THREE.MeshLambertMaterial({color: 0xc9ced6, transparent: true, opacity: 0.6, depthWrite: false})));
let smokeIdx = 0;
function smoke(pos, dir, k, n, spread, size) { for (let i = 0; i < n; i++) { const m = SMOKES[smokeIdx++ % SMOKES.length]; if (k <= 0 || k >= 1) continue; const j = new THREE.Vector3(Math.sin(i * 7.1), Math.sin(i * 3.7) * 0.5, Math.cos(i * 5.3)).multiplyScalar(spread * k); m.visible = true; m.position.copy(pos).addScaledVector(dir, k * spread * 1.5).add(j); m.scale.setScalar((size || 1) * (0.5 + 1.6 * k)); m.material.opacity = 0.65 * (1 - k * k); } }
const GRINGS = [0, 1, 2].map(() => mk(new THREE.RingGeometry(0.9, 1, 64), ADD(0x3d9bff, 0.9)));
function gring(i, pos, k, R, color) { const m = GRINGS[i]; m.visible = k > 0 && k < 1; if (!m.visible) return; m.position.copy(pos).setY(0.1); m.rotation.set(-Math.PI / 2, 0, 0); m.scale.setScalar(0.5 + R * easeOut(k)); m.material.color.setHex(color || 0x3d9bff); m.material.opacity = 0.9 * (1 - k); }
const ARCS = [0, 1, 2].map(() => mk(new THREE.RingGeometry(0.86, 1, 40, 1, 0, Math.PI * 0.9), new THREE.MeshBasicMaterial({color: 0xff3b30, transparent: true, opacity: 0.9, depthWrite: false, side: THREE.DoubleSide})));
function slashArc(i, pos, k, R, tilt, color) { const m = ARCS[i]; m.visible = k > 0 && k < 1; if (!m.visible) return; m.position.copy(pos); m.rotation.set(0, Math.PI / 2, tilt); m.scale.setScalar(R * (0.7 + 0.3 * k)); m.material.color.setHex(color || 0xff3b30); m.material.opacity = 0.95 * (1 - k); }
const QFX = []; for (let i = 0; i < 12; i++) QFX.push(mk(new THREE.ConeGeometry(0.08, 0.7, 6), new THREE.MeshBasicMaterial({color: 0xe2dccb})));
function quill(i, a, b, k, peak) { const m = QFX[i]; m.visible = k > 0 && k < 1; if (!m.visible) return; const p = lerpV(a, b, k); p.y += Math.sin(k * Math.PI) * (peak || 0.6); const p2 = lerpV(a, b, Math.min(1, k + 0.02)); p2.y += Math.sin(Math.min(1, k + 0.02) * Math.PI) * (peak || 0.6); m.position.copy(p); m.quaternion.setFromUnitVectors(UP, p2.sub(p).normalize()); }
const QTRAIL = []; for (let i = 0; i < 12; i++) QTRAIL.push(mk(CYL, ADD(0xff8a4a, 0.5)));
const BLOB = mk(BALL, new THREE.MeshBasicMaterial({color: 0xa6e22e})), PUDDLE = mk(new THREE.CircleGeometry(1, 32), new THREE.MeshBasicMaterial({color: 0xa6e22e, transparent: true, opacity: 0.7, depthWrite: false}));
function blob(a, b, k, peak, kp) { BLOB.visible = k > 0 && k < 1; if (BLOB.visible) { const p = lerpV(a, b, k); p.y += Math.sin(k * Math.PI) * peak; BLOB.position.copy(p); BLOB.scale.setScalar(0.6 + 0.15 * Math.sin(k * 20)); }
  PUDDLE.visible = kp > 0 && kp < 1; if (PUDDLE.visible) { PUDDLE.position.copy(b).setY(0.06); PUDDLE.rotation.set(-Math.PI / 2, 0, 0); PUDDLE.scale.setScalar(0.5 + 7.5 * easeOut(Math.min(1, kp * 3))); PUDDLE.material.opacity = 0.7 * (1 - Math.max(0, kp - 0.7) / 0.3); } }
const JACKS = []; for (let i = 0; i < 10; i++) { const g = new THREE.Group(); for (const r of [[0, 0, 0], [Math.PI / 2, 0, 0], [0, 0, Math.PI / 2]]) { const b = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.07, 0.07), new THREE.MeshPhongMaterial({color: 0xb8c0c8, shininess: 60})); b.rotation.set(...r); g.add(b); } g.visible = false; fx.add(g); JACKS.push(g); }
function jackFx(i, a, b, k, peak) { const m = JACKS[i]; m.visible = k > 0; if (!m.visible) return; const u = clamp01(k); const p = lerpV(a, b, u); p.y += Math.sin(u * Math.PI) * peak; m.position.copy(p); m.rotation.set(u * 9 + i, u * 7, 0); }
const BOLTS = []; for (let i = 0; i < 30; i++) BOLTS.push(mk(BOX, ADD(0x7fe9ff, 1)));
let boltIdx = 0;
function bolt(a, b, k, n, amp, seed) { if (k <= 0 || k >= 1) return; const pts = []; for (let i = 0; i <= n; i++) { const f = i / n, w = (i === 0 || i === n) ? 0 : amp; pts.push(lerpV(a, b, f).add(new THREE.Vector3(Math.sin(seed * 9 + i * 12.9 + Math.floor(k * 14)) * w, Math.sin(seed * 5 + i * 7.3 + Math.floor(k * 14)) * w, Math.cos(seed * 3 + i * 4.1 + Math.floor(k * 14)) * w))); }
  for (let i = 0; i < n; i++) { const m = BOLTS[boltIdx++ % BOLTS.length]; setSeg(m, pts[i], pts[i + 1], 0.08); m.material.opacity = 1 - k * 0.6; } }
const CONE = mk(new THREE.ConeGeometry(1, 1, 32, 1, true), ADD(0xfff4d8, 0.4));
function coneFx(from, dir, k, len, ang) { CONE.visible = k > 0 && k < 1; if (!CONE.visible) return; dir = dir.clone().setY(Math.max(-0.15, Math.min(0.15, dir.y))).normalize(); const L = len || 10, R = Math.tan((ang || 30) * Math.PI / 180) * L; CONE.scale.set(R, L, R); CONE.position.copy(from).addScaledVector(dir, L / 2); CONE.quaternion.setFromUnitVectors(new THREE.Vector3(0, -1, 0), dir.clone().normalize()); CONE.material.opacity = 0.55 * (1 - k); }
const GLARE = mk(BALL, ADD(0xffffff, 0.9));
function glare(pos, k, size) { GLARE.visible = k > 0 && k < 1; if (!GLARE.visible) return; GLARE.position.copy(pos); GLARE.scale.setScalar((size || 2) * (0.5 + k)); GLARE.material.opacity = 0.9 * (1 - k); }
const DOME = mk(new THREE.SphereGeometry(1, 32, 16), ADD(0x7fe9ff, 0.25));
function dome(pos, k, R, color) { DOME.visible = k > 0 && k < 1; if (!DOME.visible) return; DOME.position.copy(pos); DOME.scale.setScalar(0.5 + R * easeOut(k)); DOME.material.color.setHex(color || 0x7fe9ff); DOME.material.opacity = 0.3 * (1 - k); }
const SPEED = []; for (let i = 0; i < 10; i++) SPEED.push(mk(BOX, new THREE.MeshBasicMaterial({color: 0x9dffc8, transparent: true, opacity: 0.6, depthWrite: false})));
function speedLines(pos, k) { SPEED.forEach((m, i) => { if (k <= 0) return; const a = pos.clone().add(new THREE.Vector3(((i * 7) % 5 - 2) * 0.5, 0.5 + ((i * 3) % 5) * 0.5, ((i * 11) % 5) * 0.4)); setSeg(m, a, a.clone().add(new THREE.Vector3(0, 0, (2 + (i % 3)) * k)), 0.06); m.material.opacity = 0.6 * k; }); }
const SHADOWD = mk(new THREE.CircleGeometry(1, 24), new THREE.MeshBasicMaterial({color: 0x000000, transparent: true, opacity: 0.25, depthWrite: false}));
function fxOff() { fx.children.forEach(c => c.visible = false); dustIdx = 0; smokeIdx = 0; boltIdx = 0; }

// ---------- the enemies (studded raptor dummies; root = the feet) ----------
function makeRaptor() {
  const R = new THREE.Group(); scene.add(R);
  const mat = new THREE.MeshLambertMaterial({color: 0x9b2c22, map: studTex}), belly = new THREE.MeshLambertMaterial({color: 0xd9b48a, map: studTex}), eye = new THREE.MeshBasicMaterial({color: 0xffe14d});
  const add = (parent, s, p, m) => { const b = new THREE.Mesh(studBox(...s), m || mat); b.position.set(...p); parent.add(b); return b; };
  const body = new THREE.Group(); body.position.y = 2.5; R.add(body);
  const hips = new THREE.Group(); hips.position.y = -0.2; body.add(hips);
  add(hips, [1.3, 1.2, 2.6], [0, 0.2, 0]); add(hips, [1.0, 0.5, 2.0], [0, -0.35, -0.2], belly);
  const neck = new THREE.Group(); neck.position.set(0, 0.6, -1.2); hips.add(neck); neck.rotation.x = 0.5;
  add(neck, [0.7, 1.4, 0.7], [0, 0.6, 0]); const head = add(neck, [0.9, 0.8, 1.6], [0, 1.3, -0.5]); head.rotation.x = -0.5;
  add(head, [0.15, 0.15, 0.15], [0.42, 0.15, -0.3], eye); add(head, [0.15, 0.15, 0.15], [-0.42, 0.15, -0.3], eye);
  const tail = add(hips, [0.6, 0.6, 2.6], [0, 0.35, 2.4]); tail.rotation.x = 0.15;
  const legs = [];
  for (const e of [-1, 1]) { const L = new THREE.Group(); L.position.set(e * 0.55, -0.2, 0.3); hips.add(L); add(L, [0.45, 1.3, 0.5], [0, -0.6, 0]); const sh = new THREE.Group(); sh.position.y = -1.2; L.add(sh); add(sh, [0.35, 1.0, 0.35], [0, -0.45, 0.2]); add(sh, [0.5, 0.15, 0.8], [0, -0.95, -0.1]); legs.push({L, sh}); }
  R.userData = {body, legs, neck, mat, base: 0x9b2c22};
  return R;
}
const FOES = [makeRaptor(), makeRaptor(), makeRaptor()];
// o: {pos (feet), yaw, run, runAmt, flash, lie (0..1), color, tint (0..1 to colour), stars}
function foe(i, o) {
  const R = FOES[i], u = R.userData, ph = o.run || 0, a = o.runAmt === undefined ? 0.15 : o.runAmt;
  R.visible = true; R.position.copy(o.pos); R.rotation.set(0, o.yaw === undefined ? 0 : o.yaw, 0);
  u.body.rotation.set(o.pitch || 0, 0, (o.lie || 0) * Math.PI / 2); u.body.position.y = 2.5 - (o.lie || 0) * 1.8;
  u.legs.forEach((l, j) => { const s = Math.sin(ph + j * Math.PI); l.L.rotation.x = s * 0.7 * a; l.sh.rotation.x = -Math.max(0, Math.cos(ph + j * Math.PI)) * 0.9 * a; });
  u.mat.color.setHex(o.flash ? 0xffffff : (o.color || u.base));
}
const STARS = [0, 1, 2].map(() => label("★ ★", "#ffd34d"));
const faceMe = p => Math.atan2(p.x, p.z); // yaw that faces the Herrera at the origin

// ---------- poses (Herrera joints; IDLE is the two-legged stand) ----------
const CROUCH = {RootJoint: [-10, 0, 0], LegL: [28, 0, 0], LegR: [28, 0, 0], KneeL: [-40, 0, 0], KneeR: [-40, 0, 0], AnkleL: [12, 0, 0], AnkleR: [12, 0, 0], Neck: [-6, 0, 0], Head: [6, 0, 0]};
const COCK = plus(CROUCH, {ArmL: [-45, 0, -10], ArmR: [-45, 0, 10], Jaw: [-10, 0, 0], Tail1: [-6, 0, 0]});
const RAKE_X = {RootJoint: [-18, 0, 0], ArmL: [75, 0, -22], ArmR: [75, 0, 22], Neck: [-10, 0, 0], Head: [10, 0, 0], Jaw: [-26, 0, 0], LegL: [-18, 0, 0], LegR: [24, 0, 0], KneeR: [-20, 0, 0], Tail1: [-8, 0, 0]};
const SWIPE_L = {RootJoint: [-14, 0, 0], ArmL: [70, 0, -20], ArmR: [-30, 0, 15], Jaw: [-18, 0, 0], Neck: [-6, 10, 0]};
const SWIPE_R = {RootJoint: [-14, 0, 0], ArmR: [70, 0, 20], ArmL: [-30, 0, -15], Jaw: [-18, 0, 0], Neck: [-6, -10, 0]};
const SCURRY = {RootJoint: [-24, 0, 0], Neck: [6, 0, 0], Head: [16, 0, 0], ArmL: [30, 0, -8], ArmR: [30, 0, 8], LegL: [48, 0, 0], LegR: [48, 0, 0], KneeL: [-48, 0, 0], KneeR: [-48, 0, 0], AnkleL: [24, 0, 0], AnkleR: [24, 0, 0], Tail1: [10, 0, 0]};
const GLIDE_NOW = {RootJoint: [14, 0, 0], ArmL: [20, 0, -55], ArmR: [20, 0, 55], LegL: [-45, 0, 0], LegR: [-45, 0, 0], Neck: [-4, 0, 0], Tail1: [-4, 0, 0]};
const STOOP = {RootJoint: [-40, 0, 0], ArmL: [-30, 0, -10], ArmR: [-30, 0, 10], LegL: [-60, 0, 0], LegR: [-60, 0, 0], Neck: [-8, 0, 0], Head: [10, 0, 0], Jaw: [-20, 0, 0], Tail1: [-10, 0, 0], Tail2: [-6, 0, 0]};
const FLARE_W = {RootJoint: [30, 0, 0], ArmL: [40, 0, -70], ArmR: [40, 0, 70], LegL: [40, 0, 0], LegR: [40, 0, 0], KneeL: [-30, 0, 0], KneeR: [-30, 0, 0], Neck: [-10, 0, 0], Tail1: [10, 0, 0]};
const LANDSQ = {RootJoint: [-16, 0, 0], LegL: [36, 0, 0], LegR: [36, 0, 0], KneeL: [-56, 0, 0], KneeR: [-56, 0, 0], AnkleL: [22, 0, 0], AnkleR: [22, 0, 0], ArmL: [40, 0, -10], ArmR: [40, 0, 10], Neck: [-14, 0, 0], Jaw: [-20, 0, 0]};
const ANCHOR = {RootJoint: [-8, 0, 0], LegL: [26, 16, 0], LegR: [26, -16, 0], KneeL: [-36, 0, 0], KneeR: [-36, 0, 0], AnkleL: [12, 0, 0], AnkleR: [12, 0, 0], ArmL: [10, 0, -12], ArmR: [10, 0, 12], Neck: [-10, 0, 0], Head: [8, 0, 0], Tail1: [10, 0, 0], Tail2: [6, 0, 0]};
const RECOIL = {RootJoint: [6, 0, 0], Neck: [6, 0, 0]};
const REAR = {RootJoint: [30, 0, 0], LegL: [-26, 0, 0], LegR: [-26, 0, 0], KneeL: [-18, 0, 0], KneeR: [-18, 0, 0], ArmL: [40, 0, -10], ArmR: [40, 0, 10], Neck: [10, 0, 0], Head: [-8, 0, 0], Tail1: [10, 0, 0]};
const LOW = {RootJoint: [-18, 0, 0], LegL: [40, 0, 0], LegR: [40, 0, 0], KneeL: [-62, 0, 0], KneeR: [-62, 0, 0], AnkleL: [22, 0, 0], AnkleR: [22, 0, 0], ArmL: [30, 0, -10], ArmR: [30, 0, 10], Neck: [-12, 0, 0], Head: [6, 0, 0], Tail1: [16, 0, 0], Tail2: [8, 0, 0]};
const STAMP = {RootJoint: [-10, 0, 0], LegL: [30, 0, 0], LegR: [-6, 0, 0], KneeL: [-36, 0, 0], ArmL: [-20, 0, 0], ArmR: [-20, 0, 0], Neck: [-14, 0, 0], Tail1: [-10, 0, 0]};
const STROBE_NOW = {RootJoint: [18, 0, 0], Neck: [18, 0, 0], Jaw: [-20, 0, 0]};
const PULLBACK = {RootJoint: [10, 0, 0], Neck: [28, 0, 0], Head: [-18, 0, 0], Jaw: [-10, 0, 0], ArmL: [10, 0, 0], ArmR: [10, 0, 0]};
const SNAPFWD = {RootJoint: [-10, 0, 0], Neck: [-16, 0, 0], Head: [8, 0, 0], Jaw: [-34, 0, 0], LegL: [16, 0, 0], KneeL: [-16, 0, 0]};
const HEADUP = {RootJoint: [8, 0, 0], Neck: [30, 0, 0], Head: [12, 0, 0], Jaw: [-14, 0, 0]};
const HEADDOWN = {RootJoint: [-12, 0, 0], Neck: [-24, 0, 0], Head: [-10, 0, 0], Jaw: [-28, 0, 0]};
const HUNCH = {RootJoint: [-6, 0, 0], Neck: [-10, 0, 0], Head: [-8, 0, 0], ArmL: [-10, 0, 6], ArmR: [-10, 0, -6], LegL: [16, 0, 0], LegR: [16, 0, 0], KneeL: [-24, 0, 0], KneeR: [-24, 0, 0], Tail1: [8, 0, 0]};
const SHAKE_OFF = tt => ({RootJoint: [0, 0, 14 * Math.sin(tt * 40)], Neck: [0, 18 * Math.sin(tt * 40 + 1), 10 * Math.sin(tt * 40)], Head: [0, 14 * Math.sin(tt * 40 + 2), 0], Tail1: [0, -14 * Math.sin(tt * 40 + 1), 0], Tail2: [0, -18 * Math.sin(tt * 40 + 2), 0], Tail3: [0, -20 * Math.sin(tt * 40 + 3), 0]});
const ROARUP = {RootJoint: [14, 0, 0], Neck: [32, 0, 0], Head: [10, 0, 0], Jaw: [-40, 0, 0], ArmL: [20, 0, -20], ArmR: [20, 0, 20], Tail1: [-10, 0, 0]};
const TAIL_UP = {Tail1: [-20, 0, 0], Tail2: [-14, 0, 0], Tail3: [-8, 0, 0], RootJoint: [-6, 0, 0]};
const TAILFLICK = tt => ({Tail1: [-10, 30 * Math.sin(tt * 16), 0], Tail2: [-6, 34 * Math.sin(tt * 16 - 0.6), 0], Tail3: [0, 34 * Math.sin(tt * 16 - 1.2), 0], Tail4: [0, 30 * Math.sin(tt * 16 - 1.8), 0], RootJoint: [-6, 6 * Math.sin(tt * 16), 0]});
const HOPTUCK = {RootJoint: [-6, 0, 0], LegL: [40, 0, 0], LegR: [40, 0, 0], KneeL: [-60, 0, 0], KneeR: [-60, 0, 0], Tail1: [-14, 0, 0], ArmL: [20, 0, 0], ArmR: [20, 0, 0]};
const LOOKSHOULDER = {Neck: [-6, 34, 0], Head: [-14, 20, 0], ArmL: [16, 0, 0], RootJoint: [-4, 0, 0]};
const CHESTOUT = {RootJoint: [8, 0, 0], Neck: [14, 0, 0], Head: [-6, 0, 0], ArmL: [10, 0, -24], ArmR: [10, 0, 24]};
const PUMP = tt => ({RootJoint: [3 * Math.sin(tt * 18), 0, 0], Neck: [6 * Math.sin(tt * 18), 0, 0]});
const RUNNING = tt => { const a = Math.sin(tt * 12); return plus(SCURRY, {ArmL: [30 * a, 0, 0], ArmR: [-30 * a, 0, 0], LegL: [-26 * a, 0, 0], LegR: [26 * a, 0, 0], Tail1: [0, 8 * a, 0], Tail2: [0, 10 * a, 0]}); };

// ---------- one frame ----------
let variant = "now";
const PRESS = 0.3;
const st = {};
const FWD = (d, y) => new THREE.Vector3(0, y || 0, -d);
const RP = (x, z) => new THREE.Vector3(x, 0, z);
const VM = {};
function standFoe(i, p, tt, o) { foe(i, Object.assign({pos: p, yaw: faceMe(p), run: tt * 3}, o || {})); }
function knocked(i, p0, dir, tt, tHit, dist, lieFor) { // pushed back along dir and down, then back up
  const k = tt - tHit; if (k < 0) { standFoe(i, p0, tt); return p0; }
  const u = clamp01(k / 0.4), p = p0.clone().addScaledVector(dir, dist * easeOut(u)); p.y = Math.sin(u * Math.PI) * 0.8;
  foe(i, {pos: p, yaw: faceMe(p0), lie: k < (lieFor || 1.2) ? Math.min(1, u * 2) : 1 - clamp01((k - (lieFor || 1.2)) / 0.4), flash: k < 0.1, runAmt: 0}); return p;
}

// ============================================ 1 · SLASH (Iron Claw: Wing Blades) ============================================
const SL_T = RP(0.3, -9);
function slashHit(tt, tHit, arcs) {
  const k = tt - tHit;
  if (k < 0) standFoe(0, SL_T, tt); else { foe(0, {pos: SL_T.clone().add(new THREE.Vector3(0, 0, -0.6 * easeOut(clamp01(k / 0.2)))), yaw: faceMe(SL_T), flash: k < 0.1, runAmt: 0, pitch: -0.25 * hump(tt, tHit, tHit + 0.4)}); pop(POP.hit, SL_T, clamp01(k / 1)); pop(POP.bleed, SL_T.clone().add(new THREE.Vector3(0, 0.9, 0)), clamp01((k - 0.15) / 1.1)); }
  (arcs || [[0, 0.5]]).forEach(([dt, tilt], i) => slashArc(i, SL_T.clone().add(new THREE.Vector3(0, 2.6, 0.6)), (tt - tHit - dt) / 0.3, 2.6, tilt));
}
const dashZ = (tt, a, b, d) => -d * ease(seg(tt, a, b));
VM.slash = {
  now: {name: "Now", sub: "as the game plays it (v472)", len: 2.6, timing: "dash 0.30 s, rake mid-dash",
    ref: "SlashPose 1.1 \"ground\" kind: one arm rakes forward, the other back, during the dash; the Wing Blades swing forward (HerreraPartsAnim 1.0).",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.6, "Dashes forward · one claw rakes, blades swing out"], [0.6, 1.0, "Hit"], [1.0, 2.6, "Stands back up"]],
    notes: ["No wind-up: the claws start moving the moment you press, so there's no build-up to read.", "The rake is one-armed and small next to the new blades; the blades swing but the body doesn't sell the hit."],
    update(tt) { const k = sm2(seg(tt, PRESS, 0.6)), sw = Math.sin(Math.PI * clamp01((seg(tt, PRESS, 0.6) - 0.2) / 0.6));
      pose(plus(IDLE(tt), {ArmL: [60 * sw * 1.35, 0, -20 * sw], ArmR: [-40 * sw * 1.35, 0, 20 * sw], Jaw: [-18 * sw, 0, 0]}, tt > 0.6 ? {} : {}));
      rig.position.z = dashZ(tt, PRESS, 0.6, 3.2); lookU("claw", hump(tt, PRESS, 1.0) > 0 ? 1 : 0); slashHit(tt, 0.5); }},
  A: {name: "A · Cross Rake", sub: "coil, dash, both blades in an X", len: 2.8, rec: true, timing: "dash starts 0.15 s after the press (the coil)",
    ref: "Monster Hunter — Nargacuga: it draws its wing blades back, then lunges and cuts with both.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.45, "Coil · body drops, both arms pull back, blades fold flat"], [0.45, 0.72, "Lunge · both arms cross forward, blades swing out"], [0.62, 0.95, "X-cut on the raptor · it staggers back"], [0.95, 2.8, "Blades fold back, stands up"]],
    notes: ["The coil is the tell: you see the blades fold back, then cut.", "Both arms and all 6 blades hit at once, so the hit lands with weight.", "Game change: SlashPose gets a 0.15 s coil before the dash; damage, reach and dash distance unchanged."],
    update(tt) { pose(AT(tt, [[PRESS, IDLE(tt)], [0.45, COCK, sm2], [0.65, RAKE_X, easeOut], [0.95, RAKE_X], [1.6, IDLE(tt), sm2]]));
      rig.position.z = dashZ(tt, 0.45, 0.7, 3.2); lookU("claw", tt < 0.45 ? 0 : tt < 1.2 ? 1 : 1 - seg(tt, 1.2, 1.5), 0); slashHit(tt, 0.68, [[0, 0.6], [0.04, -0.6]]); }},
  B: {name: "B · Pounce Slash", sub: "hop at it, slash on the way down", len: 3.0, timing: "hit 0.55 s after the press",
    ref: "Monster Hunter Rise — the Dual Blades' Demon Flight: leap at the monster, cut on the way down.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.45, "Crouch"], [0.45, 0.75, "Hops at the raptor, arms raised, blades open"], [0.75, 0.85, "Both claws slash down as it lands"], [0.85, 1.3, "Hit · the raptor is pushed down"], [1.3, 3.0, "Recover"]],
    notes: ["Reads as a pounce (raptors' signature move) and covers the dash with a jump.", "A little slower (0.55 s to the hit) and the hop can clip low branches.", "Game change: SlashPose \"dive\" for every slash + the hit time moves to the landing."],
    update(tt) { const air = seg(tt, 0.45, 0.82); pose(AT(tt, [[PRESS, IDLE(tt)], [0.45, CROUCH, sm2], [0.6, plus(REAR, {ArmL: [60, 0, -20], ArmR: [60, 0, 20]}), easeOut], [0.82, LANDSQ, easeIn], [1.3, LANDSQ], [2.0, IDLE(tt), sm2]]));
      rig.position.z = -3.2 * ease(air); rig.position.y = tt > 0.45 && tt < 0.82 ? 2 * Math.sin(air * Math.PI) : 0;
      lookU("claw", tt > 0.5 && tt < 1.4 ? 1 : 0, 0); slashHit(tt, 0.82, [[0, 1.3], [0.03, 1.1]]); if (tt > 0.82) dust(new THREE.Vector3(0, 0, -3.2), (tt - 0.82) / 0.6, 2, 8); }},
  C: {name: "C · Flurry", sub: "left, right, left in one dash", len: 2.8, timing: "3 rakes in the 0.30 s dash",
    ref: "Monster Hunter — the Dual Blades' Demon Mode flurry: fast alternating cuts.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.4, "Quick dip"], [0.4, 0.72, "Dash · left, right, left rakes, blades flick each time"], [0.72, 1.1, "Three slash marks on the raptor"], [1.1, 2.8, "Recover"]],
    notes: ["Feels the fastest and the most 'raptor'.", "Busy: three small arcs read less clearly than one big hit (damage is still one hit).", "Game change: SlashPose rake pattern only."],
    update(tt) { pose(AT(tt, [[PRESS, IDLE(tt)], [0.4, CROUCH, sm2], [0.5, SWIPE_L, easeOut], [0.6, SWIPE_R, easeOut], [0.7, SWIPE_L, easeOut], [0.9, SWIPE_L], [1.6, IDLE(tt), sm2]]));
      rig.position.z = dashZ(tt, 0.4, 0.72, 3.2); lookU("claw", tt > 0.4 && tt < 1.3 ? 0.5 + 0.5 * Math.abs(Math.sin((tt - 0.4) * 30)) : 0, 0); slashHit(tt, 0.6, [[-0.08, 0.8], [0, -0.8], [0.08, 0.5]]); }},
};

// ============================================ 2 · GLIDE (Sword Wings) ============================================
const GL_T = RP(0.5, -26);
function glideFoe(tt, tHit) { const k = tt - tHit; if (k < 0) standFoe(0, GL_T, tt); else { knocked(0, GL_T, new THREE.Vector3(0, 0, -1), tt, tHit, 2.5, 1.0); pop(POP.hit, GL_T, clamp01(k / 1)); gring(0, GL_T, clamp01(k / 0.5), 5, 0xff5a4e); } }
function glideFlight(tt, tUp, tTop, tDrop, tHit, topY, dropZ) { // jump up to topY by tTop, glide down slowly to tDrop, then dive to the target by tHit
  let y = 0, z = 0;
  if (tt > tUp && tt < tTop) { const u = seg(tt, tUp, tTop); y = topY * Math.sin(u * Math.PI / 2); z = -2 * u; }
  else if (tt >= tTop && tt < tDrop) { const u = seg(tt, tTop, tDrop); y = topY - 1.2 * u; z = -2 - (dropZ - 2) * u; }
  else if (tt >= tDrop && tt < tHit) { const u = easeIn(seg(tt, tDrop, tHit)); y = (topY - 1.2) * (1 - u); z = -dropZ - (-GL_T.z - 1.5 - dropZ) * u; }
  else if (tt >= tHit) { y = 0; z = GL_T.z + 1.5; }
  rig.position.set(0, y, z); SHADOWD.visible = y > 0.3; SHADOWD.position.set(0, 0.05, z); SHADOWD.rotation.set(-Math.PI / 2, 0, 0); SHADOWD.scale.setScalar(2.2 - Math.min(1.2, y * 0.12));
}
VM.glide = {
  now: {name: "Now", sub: "as the game plays it (v472)", len: 4.2, timing: "glide on JUMP held · drop on SLASH",
    ref: "HerreraMovesPose 1.1 glide pose (arms out, legs back, nose up 14°) + the Sword Wings spreading (HerreraPartsAnim 1.0); the drop uses the slash dive.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.8, "Jumps"], [0.8, 2.6, "Holds JUMP · wings spread, glides"], [2.6, 3.2, "SLASH · drop attack"], [3.2, 4.2, "Hit · stands up"]],
    notes: ["The wings just open; nothing pushes off or catches air, so the glide looks like falling slowly.", "The drop is the normal slash dive: no fold, no impact on landing."],
    update(tt) { glideFlight(tt, PRESS, 0.8, 2.6, 3.2, 6, 14); const air = tt > 0.8 && tt < 3.2;
      pose(AT(tt, [[PRESS, IDLE(tt)], [0.8, REAR, sm2], [1.0, GLIDE_NOW, sm2], [2.6, GLIDE_NOW], [3.0, STOOP, easeIn], [3.2, LANDSQ], [4.0, IDLE(tt), sm2]])); lookU("wing", air ? 1 : 0); lookU("claw", tt > 2.8 && tt < 3.5 ? 1 : 0, 0); glideFoe(tt, 3.2); }},
  A: {name: "A · Falcon Stoop", sub: "flap open, glide, fold and dive", len: 4.4, rec: true, timing: "same buttons · the drop's hit when it lands (as now)",
    ref: "A peregrine falcon's stoop (wings tucked, the fastest dive of any animal) and Horizon's Stormbird diving at you.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.8, "Jumps · wings snap open with one big flap"], [0.8, 2.6, "Glides · body level, tail as a rudder"], [2.6, 3.1, "Drop · wings fold back tight, nose-dive"], [3.1, 3.4, "Wings flare open at the bottom · claws hit"], [3.4, 4.4, "Lands in a crouch · dust ring"]],
    notes: ["The fold before the dive is the tell, and the flare at the bottom sells the impact.", "Game change: HerreraMovesPose glide + dive poses and the wings' fold during the drop (HerreraPartsAnim); numbers unchanged."],
    update(tt) { glideFlight(tt, PRESS, 0.8, 2.6, 3.25, 6, 14); const flap = hump(tt, 0.7, 1.0);
      pose(AT(tt, [[PRESS, IDLE(tt)], [0.7, REAR, sm2], [1.0, plus(GLIDE_NOW, {RootJoint: [-10, 0, 0], ArmL: [0, 0, -20 * flap], ArmR: [0, 0, 20 * flap]}), sm2], [2.6, plus(GLIDE_NOW, {RootJoint: [-10, 0, 0]})], [2.9, STOOP, easeIn], [3.15, FLARE_W, easeOut], [3.4, LANDSQ, easeIn], [4.2, IDLE(tt), sm2]]));
      lookU("wing", tt < 0.7 ? 0 : tt < 2.6 ? 1 - 0.3 * flap : tt < 3.05 ? 1 - seg(tt, 2.6, 2.9) : tt < 3.4 ? seg(tt, 3.05, 3.2) : 1 - seg(tt, 3.4, 3.8)); lookU("claw", tt > 3.0 && tt < 3.6 ? 1 : 0, 0);
      glideFoe(tt, 3.25); if (tt > 3.25) dust(new THREE.Vector3(0, 0, GL_T.z + 1.5), (tt - 3.25) / 0.7, 3, 12); }},
  B: {name: "B · Banking Glide", sub: "swoops side to side, corkscrew drop", len: 4.4, timing: "same buttons",
    ref: "Hang-glider / wingsuit banking turns; Zoids Storm Sworder's rolling dives in the anime.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.8, "Jumps, wings open"], [0.8, 2.6, "Banks left and right, wing tips tilt"], [2.6, 3.25, "Corkscrew dive"], [3.25, 4.4, "Hit · lands"]],
    notes: ["Looks the most alive in the air.", "The roll moves the camera horizon if the camera follows the body (it won't: only the model rolls).", "Game change: glide pose adds a roll from your steering."],
    update(tt) { glideFlight(tt, PRESS, 0.8, 2.6, 3.25, 6, 14); const bank = tt > 0.9 && tt < 2.6 ? Math.sin((tt - 0.9) * 3.5) * 0.45 : 0;
      rig.rotation.z = bank + (tt > 2.6 && tt < 3.25 ? seg(tt, 2.6, 3.25) * Math.PI * 2 : 0); rig.position.x = Math.sin((tt - 0.9) * 3.5) * (tt > 0.9 && tt < 2.6 ? 1.2 : 0);
      pose(AT(tt, [[PRESS, IDLE(tt)], [0.8, REAR, sm2], [1.0, GLIDE_NOW, sm2], [2.6, GLIDE_NOW], [3.0, STOOP, easeIn], [3.25, LANDSQ], [4.1, IDLE(tt), sm2]]));
      lookU("wing", tt > 0.7 && tt < 3.25 ? 1 : 0); lookU("claw", tt > 3.0 && tt < 3.6 ? 1 : 0, 0); glideFoe(tt, 3.25); }},
  C: {name: "C · Kite Hover", sub: "flaps to hang, then drops straight", len: 4.6, timing: "same buttons",
    ref: "A kestrel hovering on the spot before it drops on its prey.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.8, "Jumps"], [0.8, 2.6, "Glides, then three strong flaps to hang over the raptor"], [2.6, 3.0, "Hangs · wings beat fast"], [3.0, 3.3, "Drops straight down, claws first"], [3.3, 4.6, "Hit · lands"]],
    notes: ["The hang lines the drop up, so it's easy to aim.", "The flaps make the glide look powered (the speed stays the same).", "Game change: glide pose flaps (no physics change)."],
    update(tt) { glideFlight(tt, PRESS, 0.8, 2.6, 3.3, 6, 22); if (tt > 2.6 && tt < 3.0) rig.position.y += 0.4 * Math.sin((tt - 2.6) * 30);
      const flap = tt > 1.8 && tt < 3.0 ? Math.sin(tt * 18) : 0;
      pose(AT(tt, [[PRESS, IDLE(tt)], [0.8, REAR, sm2], [1.0, GLIDE_NOW, sm2], [2.6, plus(GLIDE_NOW, {RootJoint: [10, 0, 0]})], [3.1, STOOP, easeIn], [3.3, LANDSQ], [4.3, IDLE(tt), sm2]]));
      lookU("wing", tt > 0.7 && tt < 3.3 ? 0.75 + 0.25 * flap : 0); lookU("claw", tt > 3.0 && tt < 3.6 ? 1 : 0, 0); glideFoe(tt, 3.3); }},
};

// ============================================ 3 · QUILL LAUNCHER (Missile Pods) ============================================
const QL_T = RP(1.5, -20);
function volley(tt, t0, gap, n, fly, from, peak, burstAt) {
  let landed = 0;
  for (let i = 0; i < n; i++) { const ts = t0 + i * gap, k = (tt - ts) / fly; const a = from(i), b = QL_T.clone().add(new THREE.Vector3(Math.sin(i * 2.1) * 0.6, 2.4 + Math.cos(i * 1.7) * 0.4, 0)); quill(i, a, b, k, peak); if (k > 0 && k < 1) { const p = lerpV(a, b, Math.max(0, k - 0.08)); p.y += Math.sin(Math.max(0, k - 0.08) * Math.PI) * peak; setSeg(QTRAIL[i], p, QFX[i].position, 0.06); } if (k >= 1) landed++; }
  const tl = t0 + (n - 1) * gap + fly;
  if (tt < t0 + fly) standFoe(0, QL_T, tt); else { foe(0, {pos: QL_T, yaw: faceMe(QL_T), flash: Math.floor(tt * 20) % 2 === 0 && tt < tl + 0.05, runAmt: 0, pitch: -0.1}); }
  pop(POP.quills, QL_T, clamp01((tt - tl) / 1.2));
}
const podTip = i => pieceAt("tip", "quill", i % 8);
VM.quills = {
  now: {name: "Now", sub: "as the game plays it (v472)", len: 2.8, timing: "quills leave at once, one every 0.045 s",
    ref: "HerreraMovesServer 1.4 + HerreraMovesFX 1.5: quills from the pod tubes (role tip) on a slight arc at 90 studs/s; the lids open (HerreraPartsAnim 1.0). No body pose.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.6, "Lids pop open and quills stream out"], [0.6, 1.3, "Quills hit"], [1.3, 2.8, "Lids close"]],
    notes: ["The body does nothing: it looks like the pods fire by themselves.", "No recoil or smoke, so 5–17 quills feel light."],
    update(tt) { pose(IDLE(tt)); lookU("quill", tt > PRESS && tt < 1.6 ? 1 : 0, 0); volley(tt, PRESS + 0.05, 0.045, 8, 0.25, podTip, 0.4); }},
  A: {name: "A · Anchor & Volley", sub: "dig in, pods fire left-right", len: 3.2, rec: true, timing: "first quill 0.35 s after the press",
    ref: "Zoids — Gun Sniper: it digs its foot claws into the ground to lock itself before it fires.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.65, "Anchor · crouches, toes dig in (dust), tail drops, lids open"], [0.65, 1.1, "Volley · pods fire left, right, left… each shot kicks the body"], [1.0, 1.4, "Quills hit · count pops up"], [1.4, 3.2, "Lids close, stands up"]],
    notes: ["The anchor and the per-shot kick make each quill feel like a real shot.", "Game change: a 0.35 s wind-up before the first quill (the stream itself unchanged)."],
    update(tt) { const kick = tt > 0.65 && tt < 1.1 ? Math.max(0, Math.sin((tt - 0.65) * 70)) : 0;
      pose(plus(AT(tt, [[PRESS, IDLE(tt)], [0.65, ANCHOR, sm2], [1.3, ANCHOR], [2.0, IDLE(tt), sm2]]), {RootJoint: [3 * kick, 0, 0], Neck: [3 * kick, 0, 0]}));
      lookU("quill", tt > 0.4 && tt < 1.8 ? 1 : 0, 0); if (tt > PRESS && tt < 1.0) dust(new THREE.Vector3(0, 0, 0.3), (tt - 0.5) / 0.5, 1.6, 8);
      volley(tt, 0.66, 0.05, 8, 0.25, podTip, 0.35); if (tt > 0.65) smoke(podTip(0), new THREE.Vector3(0, 0.3, 1), (tt - 0.65) / 0.9, 6, 0.6, 0.6); }},
  B: {name: "B · Sky Salvo", sub: "rears up, quills rain down", len: 3.4, timing: "first quill 0.30 s after the press, flight 0.6 s",
    ref: "Rocket artillery (MLRS): fire high, the rockets come down on the target.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.6, "Rears up, pods point at the sky"], [0.6, 1.0, "Quills shoot high"], [1.0, 1.7, "They rain down on the raptor"], [1.7, 3.4, "Drops back down"]],
    notes: ["Very readable from far away and over cover.", "Slower to land (the arc), so it's easier to dodge.", "Game change: QUILL flight arc much higher (server path)."],
    update(tt) { pose(AT(tt, [[PRESS, IDLE(tt)], [0.6, REAR, sm2], [1.2, REAR], [1.8, IDLE(tt), sm2]])); lookU("quill", tt > 0.4 && tt < 1.8 ? 1 : 0, 0); volley(tt, 0.6, 0.045, 8, 0.7, podTip, 9); }},
  C: {name: "C · Run & Gun", sub: "fires while scurrying", len: 2.8, timing: "as now (no stop)",
    ref: "Armored Core — shoulder missiles fired on the move without stopping.",
    phases: [[0, PRESS, "Running"], [PRESS, 0.45, "Lids snap open mid-stride"], [0.45, 0.9, "Quills stream out with a puff each"], [0.9, 1.5, "Hit"], [1.5, 2.8, "Keeps running"]],
    notes: ["Never slows you down.", "Least weight; the stride shakes the pods so it looks less precise."],
    update(tt) { pose(RUNNING(tt)); rig.position.z = 0; lookU("quill", tt > PRESS && tt < 1.5 ? 1 : 0, 0); volley(tt, 0.45, 0.045, 8, 0.25, podTip, 0.4); if (tt > 0.45) smoke(podTip(1), new THREE.Vector3(0, 0.2, 1), (tt - 0.45) / 0.8, 4, 0.5, 0.5); }},
};

// ============================================ 4 · SMOKE PODS (Stealth Generator) ============================================
const SM_F = [RP(5, -12), RP(-6, -10)];
function smokeCloud(tt, t0, center, R, n) { for (let i = 0; i < (n || 22); i++) { const m = SMOKES[i]; const k = clamp01((tt - t0) / 0.5), a = i / (n || 22) * Math.PI * 2 + i, r = R * (0.3 + 0.7 * ((i * 37) % 10) / 10) * easeOut(k); if (k <= 0) continue; m.visible = true; m.position.set(center.x + Math.cos(a) * r, 0.8 + (i % 4) * 0.7 + Math.sin(tt * 2 + i) * 0.15, center.z + Math.sin(a) * r); m.scale.setScalar(1.6 + (i % 3) * 0.6); m.material.opacity = 0.45 * k * (tt > 3.6 ? 1 - seg(tt, 3.6, 4.2) : 1); } smokeIdx = n || 22; }
function smokeFoes(tt, t0) { SM_F.forEach((p, i) => { standFoe(i, p, tt, {yaw: faceMe(p) + (tt > t0 + 0.4 ? Math.sin(tt * 2 + i) * 0.8 : 0)}); if (tt > t0 + 0.4) pop(POP.lost[i], p, clamp01((tt - t0 - 0.4) / 1.2)); }); }
VM.smoke = {
  now: {name: "Now", sub: "as the game plays it (v472)", len: 4.2, timing: "cloud at once",
    ref: "HerreraMovesFX 1.5: puffs pop out of the generator's nozzle to fill the 28-stud cloud; the fins fan (HerreraPartsAnim 1.0). No body pose.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.8, "Puffs pop out, the cloud fills"], [0.8, 3.6, "Inside the cloud · bots lose you"], [3.6, 4.2, "Fades"]],
    notes: ["Nothing on the body tells you it's coming: the cloud just appears.", "The generator's fins open but the haze doesn't come from them."],
    update(tt) { pose(IDLE(tt)); lookU("smoke", tt > PRESS && tt < 3.6 ? 1 : 0); smokeCloud(tt, PRESS, new THREE.Vector3(0, 0, -1), 9); smokeFoes(tt, PRESS); pop(POP.poof, new THREE.Vector3(0, 1, 0), clamp01((tt - PRESS) / 1)); }},
  A: {name: "A · Vanish", sub: "hunker, haze pours out, shimmer", len: 4.4, rec: true, timing: "cloud 0.25 s after the press",
    ref: "Horizon Zero Dawn — Stalker: it shimmers and fades as its Stealth Generator cloaks it.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.55, "Hunkers low, tail lifts the generator, fins fan open"], [0.55, 1.2, "Haze pours out of the fins and rolls outward"], [1.2, 3.6, "Inside · a faint shimmer outline · slinks"], [3.6, 4.4, "Fades, stands"]],
    notes: ["The hunker + haze from the fins makes it read as 'going stealth'.", "Game change: a 0.25 s wind-up before the cloud; HerreraMovesFX puffs start at the fins."],
    update(tt) { pose(AT(tt, [[PRESS, IDLE(tt)], [0.55, plus(LOW, TAIL_UP), sm2], [3.4, plus(LOW, TAIL_UP)], [4.0, IDLE(tt), sm2]])); lookU("smoke", tt > PRESS && tt < 3.8 ? 1 : 0);
      if (tt > 0.55 && tt < 1.4) smoke(partNow("Tail1_main").add(new THREE.Vector3(0, 0.8, 0)), new THREE.Vector3(0, 0.1, 0), (tt - 0.55) / 0.85, 10, 3, 1.2);
      smokeCloud(tt, 0.7, new THREE.Vector3(0, 0, -1), 9); dome(new THREE.Vector3(0, 2.5, 0), tt > 1.2 && tt < 3.6 ? 0.5 + 0.1 * Math.sin(tt * 6) : 0, 4, 0x9fc4ff); smokeFoes(tt, 0.7); }},
  B: {name: "B · Tail Fan", sub: "tail sweeps the smoke around", len: 4.4, timing: "cloud 0.30 s after the press",
    ref: "A squid's ink cloud + escape (the whole body pumps it out behind).",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.6, "Tail lifts and sweeps left-right, smoke trails off it"], [0.6, 1.1, "A ring of smoke closes round you"], [1.1, 3.6, "Inside"], [3.6, 4.4, "Fades"]],
    notes: ["Shows where the cloud comes from and its edge.", "The sweep takes a moment, so the cloud fills a bit later."],
    update(tt) { pose(AT(tt, [[PRESS, IDLE(tt)], [0.4, TAIL_UP, sm2], [1.1, TAILFLICK, sm2], [1.6, IDLE(tt), sm2]])); lookU("smoke", tt > PRESS && tt < 3.6 ? 1 : 0);
      if (tt > 0.4 && tt < 1.2) smoke(partNow("Tail4_main"), new THREE.Vector3(0, 0, 1), (tt - 0.4) / 0.8, 10, 2.5, 1.2); smokeCloud(tt, 0.6, new THREE.Vector3(0, 0, 0), 9); smokeFoes(tt, 0.6); }},
  C: {name: "C · Smoke Bomb", sub: "stamp, POOF, gone", len: 4.2, timing: "cloud 0.20 s after the press",
    ref: "The ninja smoke-bomb escape: a stamp, a burst of smoke, and you're gone.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.5, "Lifts a foot, stamps"], [0.5, 0.8, "POOF · the smoke bursts out in a ring"], [0.8, 3.6, "Inside"], [3.6, 4.2, "Fades"]],
    notes: ["The fastest and most readable 'escape'.", "Less 'mecha': the generator isn't the star."],
    update(tt) { pose(AT(tt, [[PRESS, IDLE(tt)], [0.42, {LegL: [40, 0, 0], KneeL: [-50, 0, 0], RootJoint: [6, 0, 0]}, sm2], [0.5, STAMP, easeIn], [0.9, STAMP], [1.5, IDLE(tt), sm2]])); lookU("smoke", tt > 0.5 && tt < 3.6 ? 1 : 0);
      gring(0, new THREE.Vector3(0, 0, 0), (tt - 0.5) / 0.5, 8, 0xe8ecf4); smokeCloud(tt, 0.5, new THREE.Vector3(0, 0, -1), 9); smokeFoes(tt, 0.5); pop(POP.poof, new THREE.Vector3(0, 1, 0), clamp01((tt - 0.5) / 1)); }},
};

// ============================================ 5 · STROBE FRILL (Flash Crest) ============================================
const ST_F = [RP(2, -12), RP(-4, -10)];
function strobeFoes(tt, tFlash) { ST_F.forEach((p, i) => { if (tt < tFlash) standFoe(i, p, tt); else { foe(i, {pos: p, yaw: faceMe(p) + Math.sin(tt * 3 + i) * 0.4, runAmt: 0, flash: tt - tFlash < 0.12, pitch: 0.15}); pop(STARS[i], p, clamp01((tt - tFlash) / 1.5), 0.2); } }); pop(POP.dazed, ST_F[0], clamp01((tt - tFlash - 0.1) / 1.2)); }
const headDir = () => partNow("Head_snout").sub(partNow("Head_cranium")).normalize();
VM.strobe = {
  now: {name: "Now", sub: "as the game plays it (v472)", len: 2.8, timing: "flash 0.15 s after the press",
    ref: "HerreraMovesPose 1.1 rear-up (body +18°, neck +18°, jaw open) for 0.55 s; HerreraMovesFX 1.5 strobes the frill bulbs 5 times and fans light rays across the cone.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.45, "Rears up a little"], [0.45, 0.8, "Flash · bulbs strobe"], [0.8, 2.8, "Raptors dazed · settles"]],
    notes: ["The rear-up is short and the frill doesn't open or aim: the flash doesn't come from anywhere.", "No tell before it fires (0.15 s)."],
    update(tt) { pose(AT(tt, [[PRESS, IDLE(tt)], [0.45, STROBE_NOW, sm2], [0.65, STROBE_NOW], [0.85, IDLE(tt), sm2]])); lookU("strobe", tt > 0.45 && tt < 0.8 ? 1 : 0, (tt - 0.45) * 7);
      coneFx(partNow("Head_cranium"), headDir(), (tt - 0.45) / 0.35, 10, 30); strobeFoes(tt, 0.45); }},
  A: {name: "A · Frill Display", sub: "head back, bulbs charge, FLASH", len: 3.0, rec: true, timing: "flash 0.40 s after the press",
    ref: "ARK — Dilophosaur: it opens its frill before it spits (players watch for it); Monster Hunter Gypceros' crest flash.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.7, "Head pulls back, frill bulbs light up one by one round the rim"], [0.7, 0.8, "Head snaps forward · FLASH cone"], [0.8, 1.3, "Raptors dazed · stars"], [1.3, 3.0, "Head settles"]],
    notes: ["The bulb charge-up is a clear tell for both sides, and the snap aims the cone.", "Game change: the flash moves from 0.15 s to 0.40 s after the press (HerreraMovesServer STROBE_WINDUP)."],
    update(tt) { pose(AT(tt, [[PRESS, IDLE(tt)], [0.7, PULLBACK, sm2], [0.78, SNAPFWD, easeOut], [1.2, SNAPFWD], [1.9, IDLE(tt), sm2]])); lookU("strobe", tt > 0.7 && tt < 1.0 ? 1 : 0, (tt - 0.7) * 7);
      const ch = seg(tt, PRESS, 0.7); for (let i = 0; i < 11; i++) { const e = equip.filter(x => x.role === "led")[i]; if (e) e.mesh.material.color.setHex(i / 11 < ch && tt < 1.0 ? 0xfff4d8 : 0xff8a1a); }
      coneFx(partNow("Head_cranium"), headDir(), (tt - 0.75) / 0.4, 10, 30); glare(partNow("Head_frill6"), (tt - 0.75) / 0.3, 3); strobeFoes(tt, 0.76); }},
  B: {name: "B · Head Toss", sub: "bob up, whip down, flash at the bottom", len: 2.8, timing: "flash 0.35 s after the press",
    ref: "Monster Hunter — Gypceros: it bobs its head up then down to flash its crest.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.55, "Head bobs up"], [0.55, 0.65, "Whips down · FLASH"], [0.65, 1.2, "Dazed"], [1.2, 2.8, "Settles"]],
    notes: ["A funny, animal-like tell.", "The flash points at the ground for a moment, less clear where the cone goes."],
    update(tt) { pose(AT(tt, [[PRESS, IDLE(tt)], [0.55, HEADUP, sm2], [0.65, HEADDOWN, easeIn], [1.0, HEADDOWN], [1.6, IDLE(tt), sm2]])); lookU("strobe", tt > 0.6 && tt < 0.9 ? 1 : 0, (tt - 0.6) * 7);
      coneFx(partNow("Head_cranium"), headDir(), (tt - 0.62) / 0.35, 10, 30); glare(partNow("Head_frill6"), (tt - 0.62) / 0.3, 3); strobeFoes(tt, 0.63); }},
  C: {name: "C · Strobe Sweep", sub: "three fast flashes while turning", len: 2.8, timing: "flashes 0.15 / 0.30 / 0.45 s",
    ref: "Club strobe lights / a police light bar: rapid flashes sweeping across.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.85, "Three quick flashes, the head sweeps left to right"], [0.85, 1.4, "Dazed"], [1.4, 2.8, "Settles"]],
    notes: ["Covers a wider area visually.", "Three flashes but one daze: could read as three hits."],
    update(tt) { const sw = tt > PRESS && tt < 0.95 ? lerp(25, -25, seg(tt, PRESS, 0.95)) : 0; pose(plus(IDLE(tt), {Neck: [10, sw, 0], Head: [0, sw * 0.5, 0], Jaw: [-16 * hump(tt, PRESS, 1.1), 0, 0]})); lookU("strobe", tt > 0.4 && tt < 0.95 ? 1 : 0, (tt - 0.4) * 7);
      for (const t0 of [0.45, 0.6, 0.75]) if (tt > t0 && tt < t0 + 0.12) coneFx(partNow("Head_cranium"), headDir(), (tt - t0) / 0.12, 10, 25); strobeFoes(tt, 0.6); }},
};

// ============================================ 6 · STUN BREAKER (Tesla Coils) ============================================
const BR_F = [RP(5, -5), RP(-5, -3)];
function breakerScene(tt, tBoom) {
  BR_F.forEach((p, i) => { const dir = p.clone().normalize(); knocked(i, p, dir, tt, tBoom + 0.02, 5, 0.9); });
  if (tt > tBoom) { gring(0, new THREE.Vector3(0, 0, 0), (tt - tBoom) / 0.5, 7); gring(1, new THREE.Vector3(0, 0, 0), (tt - tBoom - 0.08) / 0.5, 5); dome(new THREE.Vector3(0, 2.5, 0), (tt - tBoom) / 0.4, 6); pop(POP.brk, new THREE.Vector3(0, 2, 0), clamp01((tt - tBoom) / 1)); }
  const L = pieceAt("tip", "coil", 0), R = pieceAt("tip", "coil", 1);
  if (tt > tBoom - 0.02 && tt < tBoom + 0.3) { bolt(L, R, (tt - tBoom + 0.02) / 0.32, 6, 0.25, 1); BR_F.forEach((p, i) => bolt(i ? R : L, p.clone().setY(2.5), (tt - tBoom) / 0.3, 6, 0.4, 3 + i)); }
}
const STUNNED = tt => ({RootJoint: [-8, 0, 6 * Math.sin(tt * 8)], Neck: [-14, 8 * Math.sin(tt * 5), 0], Head: [-10, 0, 0], ArmL: [-10, 0, 0], ArmR: [-10, 0, 0], LegL: [12, 0, 0], LegR: [12, 0, 0], KneeL: [-16, 0, 0], KneeR: [-16, 0, 0]});
VM.breaker = {
  now: {name: "Now", sub: "as the game plays it (v472)", len: 2.8, timing: "break-free at once",
    ref: "HerreraMovesServer 1.4: break free, enemies near you pushed 10 studs over 0.3 s; HerreraMovesFX 1.5: 10 bolts from the coil tips, the band flashes, you blink while immune. No body pose.",
    phases: [[0, PRESS, "Stunned (stars)"], [PRESS, 0.6, "Press · bolts from the coils, raptors pushed"], [0.6, 2.8, "Free · blinking while immune"]],
    notes: ["The stunned pose just stops: no effort, no 'breaking out'.", "The push comes from nowhere on the body."],
    update(tt) { pose(tt < PRESS ? STUNNED(tt) : AT(tt, [[PRESS, STUNNED(tt)], [0.6, IDLE(tt), sm2]])); lookU("coil", tt > PRESS && tt < 0.6 ? 1 : 0, tt * 3);
      if (tt < PRESS) pop(STARS[2], new THREE.Vector3(0, 2.4, -2), 0.3); breakerScene(tt, PRESS); }},
  A: {name: "A · Shake-Off", sub: "violent shake, coils charge, BOOM", len: 3.0, rec: true, timing: "push 0.30 s after the press",
    ref: "A wet dog shaking itself dry; Monster Hunter monsters shaking off a trap or a stun.",
    phases: [[0, PRESS, "Stunned (stars)"], [PRESS, 0.6, "Shakes hard · arcs build between the coils"], [0.6, 0.75, "BOOM · blue shock dome + ring"], [0.75, 1.3, "Raptors thrown off"], [1.3, 3.0, "Shakes out, stands tall"]],
    notes: ["You see the effort of breaking out, and the arcs say where the blast comes from.", "Game change: the push lands 0.30 s after the press (immune from the press, so it's not weaker)."],
    update(tt) { pose(tt < PRESS ? STUNNED(tt) : AT(tt, [[PRESS, STUNNED(tt)], [0.4, SHAKE_OFF(tt), easeOut], [0.6, SHAKE_OFF(tt)], [0.7, ROARUP, easeOut], [1.1, ROARUP], [1.8, IDLE(tt), sm2]])); lookU("coil", tt > PRESS && tt < 0.9 ? 1 : 0, tt * 3);
      if (tt < PRESS) pop(STARS[2], new THREE.Vector3(0, 2.4, -2), 0.3); if (tt > 0.35 && tt < 0.6) bolt(pieceAt("tip", "coil", 0), pieceAt("tip", "coil", 1), (tt - 0.35) / 0.25, 5, 0.2, 7); breakerScene(tt, 0.6); }},
  B: {name: "B · Rear & Discharge", sub: "rears up, slams down, ring", len: 3.0, timing: "push 0.35 s after the press",
    ref: "Command & Conquer: Red Alert — the Tesla Coil's charge-up crackle before it fires.",
    phases: [[0, PRESS, "Stunned"], [PRESS, 0.6, "Rears up, arcs gather on the coils"], [0.6, 0.68, "Slams down · ring"], [0.68, 1.3, "Raptors thrown"], [1.3, 3.0, "Stands"]],
    notes: ["Big and clear, like a stomp.", "Slightly slower to fire."],
    update(tt) { pose(tt < PRESS ? STUNNED(tt) : AT(tt, [[PRESS, STUNNED(tt)], [0.6, REAR, sm2], [0.68, STAMP, easeIn], [1.1, STAMP], [1.8, IDLE(tt), sm2]])); lookU("coil", tt > PRESS && tt < 0.9 ? 1 : 0, tt * 3);
      if (tt < PRESS) pop(STARS[2], new THREE.Vector3(0, 2.4, -2), 0.3); if (tt > 0.4 && tt < 0.66) bolt(pieceAt("tip", "coil", 0), pieceAt("tip", "coil", 1), (tt - 0.4) / 0.26, 5, 0.2, 7); breakerScene(tt, 0.66); if (tt > 0.66) dust(new THREE.Vector3(0, 0, -1), (tt - 0.66) / 0.6, 3, 10); }},
  C: {name: "C · Static Pop", sub: "instant jolt, no wind-up", len: 2.6, timing: "push at once (as now)",
    ref: "An electric shock jolt: a sharp flinch, a crackle and a pop.",
    phases: [[0, PRESS, "Stunned"], [PRESS, 0.45, "Jolts upright · POP"], [0.45, 1.0, "Raptors thrown"], [1.0, 2.6, "Settles"]],
    notes: ["Same timing as now, just adds the body jolt and the dome.", "Less of a show than A / B."],
    update(tt) { pose(tt < PRESS ? STUNNED(tt) : AT(tt, [[PRESS, STUNNED(tt)], [0.36, ROARUP, easeOut], [0.7, ROARUP], [1.3, IDLE(tt), sm2]])); lookU("coil", tt > PRESS && tt < 0.6 ? 1 : 0, tt * 3);
      if (tt < PRESS) pop(STARS[2], new THREE.Vector3(0, 2.4, -2), 0.3); breakerScene(tt, PRESS + 0.02); }},
};

// ============================================ 7 · RAZOR CALTROPS (Drop Chute) ============================================
const CA_F = RP(1, 10);
function spikes(tt, t0, gap, fly, from, n, peak, spread) {
  for (let i = 0; i < n; i++) { const a = from(i), b = new THREE.Vector3(Math.sin(i * 2.4) * (spread || 3), 0.1, 3.5 + (i % 4) * 1.1); jackFx(i, a, b, (tt - t0 - i * gap) / fly, peak); }
  const k = tt - (t0 + 1.4);
  if (k < 0) standFoe(0, CA_F, tt, {run: tt * 6, runAmt: 0.5, pos: CA_F.clone().add(new THREE.Vector3(0, 0, -2.2 * clamp01(tt / 1.4)))});
  else { const p = CA_F.clone().add(new THREE.Vector3(0, 0, -2.2)); foe(0, {pos: p, yaw: faceMe(p), flash: k < 0.1, runAmt: 0, pitch: 0.2 * hump(tt, t0 + 1.4, t0 + 1.8)}); pop(POP.bleed, p, clamp01(k / 1.2)); }
}
const chuteAt = () => pieceAt("chute", "chute");
VM.caltrops = {
  now: {name: "Now", sub: "as the game plays it (v472)", len: 3.4, timing: "spikes leave 0.035 s apart, land 0.42 s later",
    ref: "HerreraMovesFX 1.5: spikes fly from the chute (role chute) on arcs to their spots; the hopper shakes; the door opens (HerreraPartsAnim 1.0). No body pose.",
    phases: [[0, PRESS, "Ready (the raptor chases you)"], [PRESS, 0.9, "Spikes spray out of the chute"], [0.9, 1.7, "They land behind"], [1.7, 3.4, "The raptor steps on one · bleed"]],
    notes: ["The body ignores it: spikes spray while you stand still.", "No sense of 'dropping something behind you'."],
    update(tt) { pose(IDLE(tt)); lookU("chute", 0); spikes(tt, PRESS, 0.035, 0.42, chuteAt, 8, 1.5); }},
  A: {name: "A · Tail Lift Drop", sub: "tail up, door opens, spikes tumble", len: 3.4, rec: true, timing: "as now",
    ref: "Spy Hunter: the spy car drops oil slicks and smoke out of its rear.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.5, "Tail lifts, hopper tips back, door drops open"], [0.5, 1.0, "Spikes tumble out and bounce behind"], [1.0, 1.7, "Tail comes down"], [1.7, 3.4, "The raptor steps on one"]],
    notes: ["The tail lift shows where they come from and that they go behind you.", "Game change: TenoPose-style tail-lift pose only; the spikes' timing unchanged."],
    update(tt) { pose(AT(tt, [[PRESS, IDLE(tt)], [0.5, plus(IDLE(tt), TAIL_UP, {RootJoint: [-4, 0, 0]}), sm2], [1.0, plus(IDLE(tt), TAIL_UP)], [1.6, IDLE(tt), sm2]])); spikes(tt, 0.45, 0.035, 0.42, chuteAt, 8, 0.6); }},
  B: {name: "B · Hop & Scatter", sub: "a hop kicks them out in a fan", len: 3.4, timing: "spikes 0.40 s after the press",
    ref: "Seed-spreader trailers: the spinning disc throws seed out in a fan behind.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.6, "A little hop"], [0.6, 1.1, "Lands · spikes burst out in a wide fan"], [1.1, 1.7, "Recover"], [1.7, 3.4, "The raptor steps on one"]],
    notes: ["Lively and covers a wider patch.", "The hop is a small delay."],
    update(tt) { const air = seg(tt, PRESS, 0.6); pose(AT(tt, [[PRESS, IDLE(tt)], [0.45, HOPTUCK, easeOut], [0.6, LANDSQ, easeIn], [1.2, IDLE(tt), sm2]])); rig.position.y = tt > PRESS && tt < 0.6 ? 0.9 * Math.sin(air * Math.PI) : 0;
      spikes(tt, 0.6, 0.02, 0.45, chuteAt, 10, 1.2, 4.5); if (tt > 0.6) dust(new THREE.Vector3(0, 0, 0), (tt - 0.6) / 0.5, 2, 8); }},
  C: {name: "C · Tail Flick", sub: "tail whips, spikes fling off it", len: 3.4, timing: "as now",
    ref: "Monster Hunter — Seregios flings its blade-scales off with a whip of its tail.",
    phases: [[0, PRESS, "Ready"], [PRESS, 1.0, "Tail whips left-right, spikes fling off in arcs"], [1.0, 1.7, "Settles"], [1.7, 3.4, "The raptor steps on one"]],
    notes: ["Very visible from behind.", "Spikes come off the tail, not the chute (looks less like the Drop Chute)."],
    update(tt) { pose(tt > PRESS && tt < 1.0 ? plus(IDLE(tt), TAILFLICK(tt)) : IDLE(tt)); spikes(tt, PRESS + 0.1, 0.07, 0.5, i => partNow("Tail" + (2 + (i % 3)) + "_main"), 8, 1.4, 4); }},
};

// ============================================ 8 · GOO BLOB SHOOTER (Spit Sacs) ============================================
const GO_T = RP(0.5, -15);
function gooScene(tt, tFire, peak) { const a = pieceAt("muzzle", "goo"), k = (tt - tFire) / 0.85; if (tt < tFire) st.gooFrom = null; else if (!st.gooFrom) st.gooFrom = a.clone(); blob(st.gooFrom || a, GO_T, k, peak, (tt - tFire - 0.85) / 2.0);
  if (tt < tFire + 0.85) standFoe(0, GO_T, tt, {run: tt * 6, runAmt: 0.4}); else { foe(0, {pos: GO_T, yaw: faceMe(GO_T), run: tt * 1.5, runAmt: 0.25, color: 0x6f8f22}); pop(POP.slow, GO_T, clamp01((tt - tFire - 0.85) / 1.3)); } }
VM.goo = {
  now: {name: "Now", sub: "as the game plays it (v472)", len: 3.4, timing: "blob at once (from the jaw since v472)",
    ref: "HerreraMovesPose 1.1 gooKick: body pitch -7° for 0.35 s; the blob flies 0.85 s from the jaw nozzle; the sacs squeeze (HerreraPartsAnim 1.0).",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.65, "Small dip · the blob leaves the mouth"], [0.65, 1.15, "Flies"], [1.15, 3.4, "Splat · puddle slows the raptor"]],
    notes: ["A tiny dip: it reads as a hiccup, not a spit.", "The sacs squeeze, but the head doesn't aim or lunge."],
    update(tt) { pose(plus(IDLE(tt), {RootJoint: [-7 * hump(tt, PRESS, PRESS + 0.35), 0, 0]})); lookU("goo", 0); gooScene(tt, PRESS, 3.5); }},
  A: {name: "A · Frill Spit", sub: "sacs swell, head back, lunge-spit", len: 3.6, rec: true, timing: "blob 0.35 s after the press",
    ref: "ARK — Dilophosaur: its frill opens before it spits (the tell players dodge on).",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.65, "Sacs swell, head pulls back, frill opens a little"], [0.65, 0.75, "Lunges · jaw open · SPIT"], [0.75, 1.5, "Recoil · the blob flies"], [1.5, 3.6, "Splat · raptor slowed"]],
    notes: ["The swell + pull-back is the tell, the lunge aims it.", "Game change: the blob leaves 0.35 s after the press (HerreraMovesServer)."],
    update(tt) { pose(AT(tt, [[PRESS, IDLE(tt)], [0.65, PULLBACK, sm2], [0.72, SNAPFWD, easeOut], [0.95, plus(SNAPFWD, RECOIL)], [1.6, IDLE(tt), sm2]]));
      for (const e of equip.filter(x => x.role === "sac")) e.mesh.scale.multiplyScalar(1); lookU("goo", tt > 0.65 && tt < 1.2 ? 1 : 0, tt < 0.72 ? 0 : (tt - 0.72) * 1.2 / 1.2 + 0.66); gooScene(tt, 0.7, 3.5); }},
  B: {name: "B · Head Lob", sub: "dips low, flings up and over", len: 3.6, timing: "blob 0.35 s after the press",
    ref: "A trebuchet / Plants vs. Zombies' Melon-pult: dip, then fling it high.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.6, "Head dips low"], [0.6, 0.72, "Flings up · blob lobbed high"], [0.72, 1.6, "Sky-high arc"], [1.6, 3.6, "Splat"]],
    notes: ["Clear high arc, good over walls.", "A higher arc reads slower (same 0.85 s flight)."],
    update(tt) { pose(AT(tt, [[PRESS, IDLE(tt)], [0.6, HEADDOWN, sm2], [0.72, HEADUP, easeOut], [1.1, HEADUP], [1.7, IDLE(tt), sm2]])); lookU("goo", tt > 0.6 && tt < 1.1 ? 1 : 0, 0.66); gooScene(tt, 0.7, 7); }},
  C: {name: "C · Double Pump", sub: "neck pumps twice, quick spit", len: 3.4, timing: "blob 0.25 s after the press",
    ref: "A spitting cobra's quick pump-and-spit.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.55, "Neck pumps twice (sacs squeeze)"], [0.55, 0.65, "Spit"], [0.65, 1.5, "Flies"], [1.5, 3.4, "Splat"]],
    notes: ["Fast and lively.", "Less of a tell than A."],
    update(tt) { pose(plus(IDLE(tt), tt > PRESS && tt < 0.55 ? PUMP(tt) : {}, tt > 0.55 && tt < 0.9 ? {Jaw: [-30 * hump(tt, 0.55, 0.9), 0, 0], Neck: [-6, 0, 0]} : {})); lookU("goo", tt > PRESS && tt < 0.8 ? 1 : 0, tt * 2); gooScene(tt, 0.58, 3.5); }},
};

// ============================================ 9 · ADRENALINE INJECTOR (Stim Shot) ============================================
function stimRun(tt, t0, dist) { if (tt > t0) { const u = tt - t0; rig.position.z = -Math.min(dist, u * 9); speedLines(new THREE.Vector3(0, 0, rig.position.z + 3), clamp01(u / 0.3)); pop(POP.speed, new THREE.Vector3(0, 1.2, rig.position.z), clamp01(u / 1.4)); } }
VM.stim = {
  now: {name: "Now", sub: "as the game plays it (v472)", len: 3.4, timing: "heal + speed at once",
    ref: "AdrenalineServer: heal 25% over 3 s and run 1.4× for 3 s; HerreraPartsServer drains the green fluid; the plunger pushes in (HerreraPartsAnim 1.0). No body pose.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.8, "Plunger pushes in, fluid drains"], [0.8, 3.4, "Runs faster"]],
    notes: ["Nothing on the body shows the boost: you only see a number.", "The syringe plunger moves, but it's tiny."],
    update(tt) { pose(tt > 0.8 ? RUNNING(tt) : IDLE(tt)); lookU("stim", tt > PRESS ? 1 : 0, tt > PRESS ? Math.min(0.75, (tt - PRESS) * 1.5) : 0); stimRun(tt, 0.8, 26); pop(POP.heal, new THREE.Vector3(0, 0.6, 0), clamp01((tt - PRESS) / 1.2)); }},
  A: {name: "A · Jab & Sprint", sub: "looks, jabs, shivers, bolts off", len: 3.6, rec: true, timing: "boost 0.45 s after the press",
    ref: "Apex Legends — Octane jabs his stim and takes off running.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.6, "Turns its head to the shoulder · the plunger slams in"], [0.6, 0.8, "Shivers, green veins light up"], [0.8, 1.0, "Roars"], [1.0, 3.6, "Bolts off at 1.4× · green speed lines"]],
    notes: ["The jab, shiver and roar make the boost something you watch happen.", "Game change: heal / speed start 0.45 s after the press."],
    update(tt) { pose(AT(tt, [[PRESS, IDLE(tt)], [0.55, LOOKSHOULDER, sm2], [0.6, LOOKSHOULDER], [0.8, plus(IDLE(tt), SHAKE_OFF(tt * 0.5)), sm2], [0.95, ROARUP, easeOut], [1.1, RUNNING(tt), sm2], [3.6, RUNNING(tt)]]));
      lookU("stim", tt > 0.45 ? 1 : 0, tt > 0.45 ? Math.min(0.75, (tt - 0.45) * 3) : 0); stimRun(tt, 1.0, 22); pop(POP.heal, new THREE.Vector3(0, 0.6, 0), clamp01((tt - 0.6) / 1.2)); if (tt > 0.6 && tt < 0.9) gring(0, new THREE.Vector3(0, 0, 0), (tt - 0.6) / 0.4, 4, 0x3ddc84); }},
  B: {name: "B · Heartbeat", sub: "chest swells, 3 beats, dash", len: 3.6, timing: "boost 0.60 s after the press",
    ref: "A heartbeat-pulse power-up (green rings with each beat), like a defibrillator restart.",
    phases: [[0, PRESS, "Ready"], [PRESS, 0.9, "Chest out · three heavy beats, green ring with each"], [0.9, 1.1, "Launches"], [1.1, 3.6, "Runs faster"]],
    notes: ["Shows the heal (the beats) and the speed (the launch) as two beats.", "The slowest to kick in."],
    update(tt) { const beat = [0.4, 0.6, 0.8].reduce((s, t0) => s + hump(tt, t0, t0 + 0.12), 0);
      pose(AT(tt, [[PRESS, IDLE(tt)], [0.4, CHESTOUT, sm2], [0.9, plus(CHESTOUT, {RootJoint: [4 * beat, 0, 0]})], [1.1, RUNNING(tt), sm2], [3.6, RUNNING(tt)]])); lookU("stim", tt > 0.4 ? 1 : 0, tt > 0.4 ? Math.min(0.75, (tt - 0.4) * 2) : 0);
      [0.4, 0.6, 0.8].forEach((t0, i) => gring(i, new THREE.Vector3(0, 0, 0), (tt - t0) / 0.5, 3.5, 0x3ddc84)); stimRun(tt, 1.0, 22); pop(POP.heal, new THREE.Vector3(0, 0.6, 0), clamp01((tt - 0.6) / 1.2)); }},
  C: {name: "C · On The Run", sub: "never stops: jab while running", len: 3.2, timing: "as now",
    ref: "Racing games' nitro button: the boost while you're already moving.",
    phases: [[0, PRESS, "Running"], [PRESS, 0.6, "Plunger slams in mid-stride, green flash"], [0.6, 3.2, "Kicks into 1.4×"]],
    notes: ["Never costs you a step.", "Easy to miss that it happened."],
    update(tt) { pose(RUNNING(tt)); lookU("stim", tt > PRESS ? 1 : 0, tt > PRESS ? Math.min(0.75, (tt - PRESS) * 3) : 0); rig.position.z = -tt * (tt > 0.5 ? 9 : 6.5) + (tt > 0.5 ? 0.5 * 2.5 : 0);
      speedLines(new THREE.Vector3(0, 0, rig.position.z + 3), clamp01((tt - 0.5) / 0.3)); glare(partNow("Torso_chest", [0.3, 0.6, 0.4]), (tt - PRESS) / 0.3, 1.5); pop(POP.speed, new THREE.Vector3(0, 1.2, rig.position.z), clamp01((tt - 0.5) / 1.4)); }},
};

// ---------- moves ----------
const MOVES = [
  {id: "slash", name: "Slash", area: "attack", part: "Iron Claw · Wing Blades", partWhy: "Three bone blades per forearm swing forward with the slash; red edges = attack.", focus: new THREE.Vector3(0, 2.5, -4), side: 24, nums: "Damage, reach, dash and recharge unchanged."},
  {id: "glide", name: "Glide + Drop", area: "speed", part: "Glider Wings · Sword Wings", partWhy: "Four blades per side spread into wings with glowing yellow panels; yellow = speed.", focus: new THREE.Vector3(0, 4, -12), side: 40, nums: "Fall speed, drop range and damage unchanged."},
  {id: "quills", name: "Quill Launcher", area: "attack", part: "Quill Launcher · Missile Pods", partWhy: "The pod lids open and quills leave the red tube mouths.", focus: new THREE.Vector3(0, 3, -9), side: 34, nums: "Quill count, damage, range and recharge unchanged."},
  {id: "smoke", name: "Smoke Pods", area: "eng", part: "Smoke Pods · Stealth Generator", partWhy: "The fins on the tail-base generator fan open; orange = engineer.", focus: new THREE.Vector3(0, 2.5, -3), side: 34, nums: "Cloud size, time and effects unchanged."},
  {id: "strobe", name: "Strobe Frill", area: "eng", part: "Strobe Frill · Flash Crest", partWhy: "The 11 frill bulbs flash white from the mirror-steel crest.", focus: new THREE.Vector3(0, 3, -6), side: 30, nums: "Cone, range, daze time unchanged."},
  {id: "breaker", name: "Stun Breaker", area: "defense", part: "Stun Breaker · Tesla Coils", partWhy: "Arcs jump between the two shoulder coils and out to the raptors; blue = defense.", focus: new THREE.Vector3(0, 2.5, -1), side: 28, nums: "Push distance, immunity and recharge unchanged."},
  {id: "caltrops", name: "Razor Caltrops", area: "eng", part: "Razor Caltrops · Drop Chute", partWhy: "The trap door on the tail-base hopper drops open and spikes slide out.", focus: new THREE.Vector3(0, 2, 4), side: 30, nums: "Spike count, patch size, bleed and slow unchanged."},
  {id: "goo", name: "Goo Blob", area: "eng", part: "Goo Blob Shooter · Spit Sacs", partWhy: "The lime sacs on the neck squeeze and the blob leaves the jaw nozzle.", focus: new THREE.Vector3(0, 3, -7), side: 32, nums: "Range, puddle size, slow and recharge unchanged."},
  {id: "stim", name: "Adrenaline", area: "health", part: "Adrenaline Injector · Stim Shot", partWhy: "The syringe's plunger slams in and the green fluid drains; green = health.", focus: new THREE.Vector3(0, 2.5, -6), side: 34, nums: "Heal, speed, time and recharge unchanged."},
];

// ---------- UI ----------
let cur = 0, playing = true, speed = 1, view = "side", tt = 0;
const M = () => MOVES[cur], VV = () => VM[M().id][variant];
function renderAll() {
  const VS = VM[M().id];
  $("moves").innerHTML = MOVES.map((m, i) => `<button class="tab" data-i="${i}" aria-pressed="${i === cur}">${m.name}<small style="color:${AREA[m.area][1]}">4 versions</small></button>`).join("");
  $("varRow").innerHTML = '<span class="lbl">Version</span>' + ["now", "A", "B", "C"].map(k => `<button class="var" data-var="${k}" aria-pressed="${k === variant}">${VS[k].name}${VS[k].rec ? ' <span class="rec">· recommended</span>' : ""}<small>${VS[k].sub}</small></button>`).join("");
  const v = VV(), ph = v.phases;
  $("phases").innerHTML = ph.map(p => `<button class="ph" data-t="${p[0]}" aria-current="false"><i>${p[0].toFixed(2)}–${p[1].toFixed(2)} s</i>${p[2]}</button>`).join("");
  const rows = ["now", "A", "B", "C"].map(k => `<tr><th>${VS[k].name}</th><td>${VS[k].timing}</td></tr>`).join("");
  const AR = AREA[M().area];
  $("info").innerHTML = `<div class="kind" style="color:${AR[1]}">${AR[0]} · ${M().name} · ${v.name}</div><h2>What you see, in order</h2><ul>${ph.slice(1).map(p => `<li>${p[2]}</li>`).join("")}</ul><p class="note"><b>Borrowed from:</b> ${v.ref}</p><table class="cmp">${rows}</table><p class="note">${M().nums}</p>`;
  $("part").innerHTML = `<div class="kind" style="color:${AR[1]}">The part that does it</div><h2>${M().part}</h2><p class="note">${M().partWhy}</p><h2 style="margin-top:6px">${variant === "now" ? "What's off about it now" : "What it does better · what it costs"}</h2><ul>${v.notes.map(n => `<li>${n}</li>`).join("")}</ul>`;
}
function reset() { rig.position.set(0, 0, 0); rig.rotation.set(0, 0, 0); for (const k in st) delete st[k]; }
$("moves").addEventListener("click", e => { const b = e.target.closest("[data-i]"); if (!b) return; cur = +b.dataset.i; variant = "now"; tt = 0; reset(); renderAll(); });
$("varRow").addEventListener("click", e => { const b = e.target.closest("[data-var]"); if (!b) return; variant = b.dataset.var; tt = 0; reset(); renderAll(); });
$("phases").addEventListener("click", e => { const b = e.target.closest("[data-t]"); if (!b) return; tt = +b.dataset.t + 0.06; playing = false; syncPlay(); });
$("play").onclick = () => { playing = !playing; syncPlay(); };
function syncPlay() { $("play").textContent = playing ? "Pause" : "Play"; $("play").setAttribute("aria-pressed", playing); }
document.querySelectorAll("[data-speed]").forEach(b => b.onclick = () => { speed = +b.dataset.speed; document.querySelectorAll("[data-speed]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => { view = b.dataset.view; document.querySelectorAll("[data-view]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
$("scrub").addEventListener("input", e => { tt = +e.target.value / 1000 * VV().len; playing = false; syncPlay(); });
window.__herr = {set(mv, v, time, camv) { cur = MOVES.findIndex(m => m.id === mv); variant = v; tt = time; playing = false; if (camv) view = camv; reset(); renderAll(); syncPlay(); }};
renderAll();

// ---------- loop ----------
let lastNow = performance.now(), camPos = new THREE.Vector3(26, 10, 8), camLook = new THREE.Vector3(0, 2.5, -2);
const LED_BASE = 0xff8a1a;
function frameM(now) {
  const dt = Math.min(0.05, (now - lastNow) / 1000); lastNow = now; t += dt;
  const v = VV();
  if (playing) { tt += dt * speed; if (tt > v.len) { tt = 0; reset(); } }
  fxOff(); FOES.forEach(R => R.visible = false); rig.position.set(0, 0, 0); rig.rotation.set(0, 0, 0); use = 0;
  for (const k in LU) lookU(k, 0);
  for (const e of equip) if (e.role === "led") e.mesh.material.color.setHex(LED_BASE);
  v.update(tt);
  updateEquip();
  $("scrub").value = Math.round(tt / v.len * 1000);
  $("clock").textContent = `${tt.toFixed(2)} s${speed !== 1 ? " · 0.3×" : ""}`;
  const ph = v.phases.find(p => tt >= p[0] && tt < p[1]);
  $("cap").textContent = ph ? ph[2] : "…";
  document.querySelectorAll(".ph").forEach(b => b.setAttribute("aria-current", ph && +b.dataset.t === ph[0]));
  const MM = M(), f = MM.focus.clone().add(new THREE.Vector3(0, rig.position.y * 0.4, rig.position.z * 0.5));
  let goalPos, goalLook;
  if (view === "game") { const off = new THREE.Vector3(4.5, 5.5, 11.5); goalPos = rig.position.clone().setY(0).add(off); goalLook = goalPos.clone().add(new THREE.Vector3(-0.05, -0.15, -1)); }
  else if (view === "top") { goalPos = new THREE.Vector3(0, 60, MM.focus.z + 0.01); goalLook = new THREE.Vector3(0, 0, MM.focus.z); }
  else if (view === "side") { goalPos = f.clone().add(new THREE.Vector3(MM.side, 3, 0)); goalLook = f; }
  else { goalPos = f.clone().add(new THREE.Vector3(0.7, 0.32, -0.55).multiplyScalar(MM.side)); goalLook = f; }
  const fovWant = view === "game" ? 70 : 34; if (cam.fov !== fovWant) { cam.fov = fovWant; cam.updateProjectionMatrix(); }
  const kk = playing ? 1 - Math.pow(0.001, dt) : 1;
  camPos.lerp(goalPos, kk); camLook.lerp(goalLook, kk);
  cam.position.copy(camPos); cam.lookAt(camLook);
  resize(); renderer.render(scene, cam);
  requestAnimationFrame(frameM);
}
requestAnimationFrame(frameM);
