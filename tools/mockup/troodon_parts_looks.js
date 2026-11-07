// troodon_parts_looks.js v0.1 (Mecha Dino Arena) — Troodon mecha parts, LOOKS + MOVES mockup (Kepu 2026-11-06 19:44 picks
// H1 Mender Drone, A6 Arc Lantern, D1 Sap Wall, D18 Feather Shed, S6 Portal Feathers (buttons); H7 Last Feather, H12 Overheal
// Plume, D5 Fortify Field, A10 Ricochet Pod (always-on while slotted); plan brainstorm docs/plans/TROODON_PARTS_brainstorm_v1.0.md).
// Engine = tools/troodon_kit_mockup/engine_part.js + app_tail.js up to its "tracks" section (scene, rigs, springs, pod, zone,
// heal pops), prepended by tools/mockup/build_troodon_parts_looks.py. Nine parts x looks A / B / C: each look is a set of meshes
// fixed to the Troodon's real segments (they ride the rig: pushed into hero.parts with kind "mech"), sitting ON the body
// surface (placed by ray casts against the rest-pose body boxes), with mount brackets where they meet it. Every move: wind-up ->
// action -> result -> recovery, at the maxed (star) step; no landing FX (house rule). Measured fit: window.__troo.measure()
// (125-point sample per piece, see tools/mockup/measure_troodon_parts.js) -> MEAS (baked in by the build when present).
const ANIM_VERSION = "0.1";

// ---------- shared state + helpers ----------
let play = null, hitStop = 0, shake = 0, clockT = 0, idleT = 0, fovPunch = 0;
let delayed = [];
function later(d, f) { delayed.push({at: (play ? play.t : 0) + d, f}); }
const K = (t, pose, e) => ({t, pose, e});
const V = (x, y, z) => new THREE.Vector3(x, y, z);
const T3 = (x, y, z) => new THREE.Matrix4().makeTranslation(x, y, z);
const R3 = (x, y, z) => new THREE.Matrix4().makeRotationFromEuler(new THREE.Euler(rad(x || 0), rad(y || 0), rad(z || 0)));
const AT = (x, y, z, rx, ry, rz) => T3(x, y, z).multiply(R3(rx, ry, rz));
const rotX = a => new THREE.Matrix4().makeRotationX(a), rotY = a => new THREE.Matrix4().makeRotationY(a), rotZ = a => new THREE.Matrix4().makeRotationZ(a);
const scl = (x, y, z) => new THREE.Matrix4().makeScale(x, y === undefined ? x : y, z === undefined ? x : z);
const clamp01 = u => Math.max(0, Math.min(1, u));
const win = (t, a, b) => clamp01((t - a) / (b - a)); // 0 before a, 1 after b
function place(R, x, z, yaw) { R.show = true; R.pos.set(x, 0, z); R.yaw = yaw === undefined ? yawTo(R.pos, hero.pos) : yaw; R.path = null; R.run = 0; }
function puff(p, v, size, color, life, op) { const s = sprite(T_MIST, color || 0xffffff, size, false); s.position.copy(p);
  addFx(s, life || 0.6, (o, u, dt) => { o.position.addScaledVector(v, dt); o.scale.setScalar(size * (1 + u * 2.4)); o.material.opacity = (op || 0.7) * (1 - u); }); }
function groundRing(center, r1, color, life, r0) {
  const m = new THREE.Mesh(new THREE.RingGeometry(0.86, 1, 56), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0.85, depthWrite: false, side: THREE.DoubleSide}));
  m.rotation.x = -Math.PI / 2; m.position.copy(center).setY(0.16);
  addFx(m, life, (o, u) => { const r = (r0 || 1) + (r1 - (r0 || 1)) * E.out(u); o.scale.setScalar(r); o.material.opacity = 0.85 * (1 - u); });
}
function killFx(obj) { const e = fx.find(f => f.obj === obj); if (e) e.life = Math.min(e.life, e.t + 0.12); }
const heroHRP = () => V(hero.pos.x, hero.y, hero.pos.z);
const torsoPt = () => partPoint(hero.segs.Torso[2]);

// more raptors: a third enemy (R2) and a second squadmate (S2), drawn like the kit's S
function addRap(ally) {
  const r = buildDino(RAPTOR, 2);
  const R = {rig: r, pos: new THREE.Vector3(), yaw: 0, flinch: 0, side: 0, flash: 0, flashCol: [0.9, 0.1, 0.05], push: 0, pushDir: new THREE.Vector3(), venom: null, slow: 0, runPh: 0, run: 0, path: null, show: false, ally: !!ally};
  if (ally) r.mats.forEach(m => { const h = {}; m.color.getHSL(h); m.color.setHSL(0.6, Math.min(0.75, h.s + 0.15), h.l); });
  raps.push(R); return R;
}
const R2 = addRap(false), S2 = addRap(true);
const ENEMIES = [R0, R1, R2], ALLIES = [S, S2];
raps.forEach(R => { pose(R.rig, {}); R.rig.y = R.rig.rest; R.rig.g.visible = false; });
const allyRing2 = allyRing.clone(); allyRing2.material = allyRing.material; scene.add(allyRing2);
const allyTag2 = allyTag.clone(); scene.add(allyTag2);

// floating HP bars (squadmates, the troodon): a canvas sprite redrawn when the value changes; gold = overheal plume
function hpBar(w) {
  const c = document.createElement("canvas"); c.width = 256; c.height = 56; const tex = new THREE.CanvasTexture(c);
  const s = new THREE.Sprite(new THREE.SpriteMaterial({map: tex, transparent: true, depthTest: false})); s.renderOrder = 11; s.scale.set(w || 9, (w || 9) * 56 / 256, 1); s.visible = false; scene.add(s);
  const o = {s, c, v: -1, max: 1, plume: 0, key: ""};
  o.set = (v, max, plume, col) => { const k = [v, max, plume, col].join(); if (k === o.key) return; o.key = k; const x = c.getContext("2d"); x.clearRect(0, 0, 256, 56);
    x.fillStyle = "rgba(10,14,20,.82)"; x.beginPath(); x.roundRect ? x.roundRect(2, 14, 252, 30, 12) : x.rect(2, 14, 252, 30); x.fill();
    const f = Math.max(0, Math.min(1, v / max)); x.fillStyle = col || (f < 0.25 ? "#ff5a4a" : "#56e07a"); x.fillRect(8, 20, 240 * f, 18);
    if (plume > 0) { x.fillStyle = "#ffe08a"; x.fillRect(8 + 240 * f - Math.min(240 * f, 240 * plume / max), 20, Math.min(240 * f, 240 * plume / max), 18); }
    x.font = "900 22px Trebuchet MS, sans-serif"; x.textAlign = "center"; x.lineWidth = 5; x.strokeStyle = "#0a0e14"; const t = Math.round(v) + " / " + max + (plume > 0 ? "  +" + Math.round(plume) : "");
    x.strokeText(t, 128, 37); x.fillStyle = "#fff"; x.fillText(t, 128, 37); tex.needsUpdate = true; };
  return o;
}
const heroBar = hpBar(10);
ALLIES.forEach(R => { R.bar = hpBar(9); });

// ---------- materials (one accent per function: heal = Med-Station green, zone = the troodon's teal, pod / sap = amber,
// lantern = shock cyan, plume = gold; hardware = gunmetal + brass) ----------
const lam = (c, o) => new THREE.MeshLambertMaterial(Object.assign({color: c}, o || {}));
const MAT = {gun: lam(0x3a3f47), dark: lam(0x23262c), steel: lam(0x9aa1ac), brass: lam(0xc8913a), plate: lam(0x5d544a), rubber: lam(0x17181b)};
const GLOWDEF = {amber: [0xffc35a, 0xb85a00], teal: [0x8ff7e6, 0x14a58c], green: [0x8dffb6, 0x1f9a52], volt: [0xc8f8ff, 0x2a9ac0], gold: [0xffe6a0, 0x7a5600], glassA: [0xffc35a, 0x9a4a00, 0.82], white: [0xffffff, 0x8a8a8a]};
const PMAT = {}; // per part: its own glow materials (so one part can glow while the others stay calm)
function gm(part, k) { const key = part + "." + k; if (!PMAT[key]) { const d = GLOWDEF[k]; PMAT[key] = lam(d[0], Object.assign({emissive: d[1]}, d[2] ? {transparent: true, opacity: d[2]} : {})); PMAT[key].userData = {part, base: d[1]}; } return PMAT[key]; }
const PGLOW = {}; // part id -> current glow level (0 calm .. 1+ bright), written by the tracks

// ---------- geometry with a sample shape (125-point measurement) ----------
function shp(geo, shape) { geo.userData.shape = shape; geo.userData.M = new THREE.Matrix4(); return geo; }
function gx(geo, m) { geo.applyMatrix4(m); geo.userData.M.premultiply(m); return geo; }
const G = {
  box: (w, h, d) => shp(new THREE.BoxGeometry(w, h, d), {t: "box", w, h, d}),
  cylY: (r1, r2, len, n) => shp(new THREE.CylinderGeometry(r1, r2, len, n || 16), {t: "cyl", r1, r2, h: len}), // r1 at +Y
  cylX: (r1, r2, len, n) => gx(G.cylY(r1, r2, len, n), rotZ(-Math.PI / 2)), // r1 at +X
  cylZ: (r1, r2, len, n) => gx(G.cylY(r1, r2, len, n), rotX(Math.PI / 2)), // r1 at +Z
  sph: (r, sx, sy, sz) => { const g = shp(new THREE.SphereGeometry(r, 18, 12), {t: "sph", r}); return sx ? gx(g, scl(sx, sy, sz)) : g; },
  tor: (R, r, arc) => shp(new THREE.TorusGeometry(R, r, 10, 32, arc || Math.PI * 2), {t: "tor", R, r}), // XY plane, axis Z
  cone: (r, len, n) => G.cylY(0, r, len, n),
};
const MECH = [];
const segInv = {}; for (const s of TROODON.segs) segInv[s.n] = cfm(s.root).invert();
// at: the piece's rest-pose matrix in model space at scale 1 (the model data's own frame)
function piece(look, seg, geo, mat, at, o) {
  o = o || {};
  const m = new THREE.Mesh(geo, mat); m.matrixAutoUpdate = false; m.castShadow = true; hero.g.add(m);
  const base = segInv[seg].clone().multiply(at);
  const info = {name: o.name || look, seg, mesh: m, local: base.clone(), base, at: at.clone(), size: [0, 0, 0], kind: "mech", look, part: look.split(".")[0], anim: o.anim, show: o.show, bracket: !!o.bracket, carry: null};
  hero.parts.push(info); MECH.push(info); return info;
}

// rest-pose body boxes (model space, scale 1) for seating: ray casts find the outer surface and its normal
const BODY = []; for (const s of TROODON.segs) for (const p of s.parts) { const m = cfm(p.cf); BODY.push({n: p.n, seg: s.n, m, inv: m.clone().invert(), h: p.s.map(v => v / 2)}); }
function ray(from, dir, only) {
  dir = dir.clone().normalize(); let best = null;
  for (const b of BODY) {
    if (only && !only(b)) continue;
    const o = from.clone().applyMatrix4(b.inv), d = dir.clone().transformDirection(b.inv);
    let t0 = -Infinity, t1 = Infinity, ax = -1, sg = 0, miss = false;
    for (let i = 0; i < 3; i++) {
      const oi = o.getComponent(i), di = d.getComponent(i), h = b.h[i];
      if (Math.abs(di) < 1e-9) { if (Math.abs(oi) > h) { miss = true; break; } continue; }
      let a = (-h - oi) / di, c = (h - oi) / di, s = -1; if (a > c) { const q = a; a = c; c = q; s = 1; }
      if (a > t0) { t0 = a; ax = i; sg = s; } t1 = Math.min(t1, c);
    }
    if (!miss && t0 <= t1 && t0 > 0 && (!best || t0 < best.t)) { const nl = new THREE.Vector3(); nl.setComponent(ax, sg); best = {t: t0, b, n: nl.transformDirection(b.m)}; }
  }
  if (!best) throw new Error("seat ray missed the body from " + from.toArray().map(v => v.toFixed(2)));
  best.p = from.clone().addScaledVector(dir, best.t); return best;
}
const onSeg = (...segs) => b => segs.includes(b.seg);
const notThin = b => !/crest|fan|mane|coat|pants|stripe|plume|tip|band/.test(b.n);
// a frame on a surface hit: +Y = out of the surface, +Z = the hint projected on the surface (default model +Z = toward the tail)
function frame(p, n, zHint) {
  const y = n.clone().normalize(); const z = (zHint || V(0, 0, 1)).clone(); z.addScaledVector(y, -z.dot(y));
  if (z.lengthSq() < 1e-6) z.set(1, 0, 0).addScaledVector(y, -y.x); z.normalize();
  const x = new THREE.Vector3().crossVectors(y, z); return new THREE.Matrix4().makeBasis(x, y, z).setPosition(p);
}
const L = (F, x, y, z, rx, ry, rz) => F.clone().multiply(AT(x, y, z, rx, ry, rz));
// a mount bracket: a flat plate on the surface (40% of its thickness set into it, like a weld pad)
function bracket(look, seg, h, w, d, t, zHint, mat) { const F = frame(h.p, h.n, zHint); piece(look, seg, G.box(w, t, d), mat || MAT.dark, L(F, 0, t * 0.1, 0), {bracket: true, name: "bracket"}); return L(F, 0, t * 0.6, 0); }

// ---------- carried pieces (drone, lantern, sap pod, portal rings): clones that leave the body and come back ----------
const CARRY = [];
function makeCarry(pieces, seg, cen) {
  const F = T3(cen.x, cen.y, cen.z), Fi = F.clone().invert();
  const g = new THREE.Group(); g.matrixAutoUpdate = false; g.visible = false; scene.add(g);
  const kids = pieces.map(p => { const m = new THREE.Mesh(p.mesh.geometry, p.mesh.material); m.matrixAutoUpdate = false; m.castShadow = true; g.add(m); return {p, m}; });
  const c = {pieces, seg, F, Fi, g, kids, on: false, part: pieces[0].part, look: pieces[0].look};
  pieces.forEach(p => { p.carry = c; });
  CARRY.push(c); return c;
}
function dockWorld(c) { return new THREE.Matrix4().makeTranslation(hero.pos.x, hero.y, hero.pos.z).multiply(scl(hero.scale)).multiply(hero.W[c.seg]).multiply(segInv[c.seg]).multiply(c.F); }
function carryAt(c, M) { c.on = true; c.g.visible = true; c.g.matrix.copy(M); c.g.matrixWorldNeedsUpdate = true; for (const k of c.kids) { k.m.matrix.copy(c.Fi).multiply(k.p.at); if (k.p.anim) k.m.matrix.multiply(k.p.anim(k.p)); } }
function carryOff(c) { c.on = false; c.g.visible = false; }
const _pa = new THREE.Vector3(), _pb = new THREE.Vector3(), _qa = new THREE.Quaternion(), _qb = new THREE.Quaternion(), _sa = new THREE.Vector3(), _sb = new THREE.Vector3();
function lerpM(A, B, u) { A.decompose(_pa, _qa, _sa); B.decompose(_pb, _qb, _sb); return new THREE.Matrix4().compose(_pa.lerp(_pb, u), _qa.slerp(_qb, u), _sa.lerp(_sb, u)); }
function worldM(p, yaw, s, tilt) { return new THREE.Matrix4().compose(p, new THREE.Quaternion().setFromEuler(new THREE.Euler(tilt || 0, yaw || 0, 0, "YXZ")), V(s || 2, s || 2, s || 2)); }
const carryPos = c => V(0, 0, 0).applyMatrix4(c.on ? c.g.matrix : dockWorld(c));
// pieces that blow off (Feather Shed): world clones flung out, spinning, shrinking away
function burst(pieces, center, power) {
  for (const p of pieces) {
    const m = new THREE.Mesh(p.mesh.geometry, p.mesh.material); m.matrixAutoUpdate = false; m.matrix.copy(p.mesh.matrix);
    const c0 = V(0, 0, 0).applyMatrix4(p.mesh.matrix); const dir = c0.clone().sub(center).setY(0).normalize(); dir.y = 0.9 + Math.random() * 0.5;
    const v = dir.multiplyScalar((power || 1) * (16 + Math.random() * 10)); const ax = V(Math.random() - .5, Math.random() - .5, Math.random() - .5).normalize(); const spin = 8 + Math.random() * 10;
    const M0 = p.mesh.matrix.clone(); const pos = c0.clone(); const q0 = new THREE.Quaternion(), s0 = new THREE.Vector3(); M0.decompose(_pa, q0, s0);
    addFx(m, 0.9, (o, u, dt) => { v.y -= 40 * dt; pos.addScaledVector(v, dt); const q = q0.clone().premultiply(new THREE.Quaternion().setFromAxisAngle(ax, spin * u)); o.matrix.compose(pos, q, s0.clone().multiplyScalar(u < 0.7 ? 1 : 1 - (u - 0.7) / 0.3)); });
  }
}
// feather sprites (loose feathers: shed, last feather): a soft elongated sprite that tumbles down
const T_FEATHER = (() => { const c = document.createElement("canvas"); c.width = 32; c.height = 96; const x = c.getContext("2d"); const g = x.createLinearGradient(0, 0, 0, 96); g.addColorStop(0, "rgba(255,255,255,1)"); g.addColorStop(1, "rgba(255,255,255,0.2)");
  x.fillStyle = g; x.beginPath(); x.ellipse(16, 48, 11, 44, 0, 0, Math.PI * 2); x.fill(); x.strokeStyle = "rgba(80,70,60,.8)"; x.lineWidth = 2; x.beginPath(); x.moveTo(16, 6); x.lineTo(16, 92); x.stroke(); return new THREE.CanvasTexture(c); })();
function feathers(p, n, colors, power, up) {
  for (let i = 0; i < n; i++) { const s = sprite(T_FEATHER, colors[i % colors.length], 1.6 + Math.random() * 1.2, false); s.position.copy(p).add(V((Math.random() - .5) * 3, (Math.random() - .5) * 2, (Math.random() - .5) * 3));
    const a = Math.random() * Math.PI * 2, sp = (power || 1) * (8 + Math.random() * 16); const v = V(Math.cos(a) * sp, (up || 6) + Math.random() * 10, Math.sin(a) * sp); const ph = Math.random() * 6;
    s.material.rotation = Math.random() * 6;
    addFx(s, 1.3 + Math.random() * 0.5, (o, u, dt) => { v.multiplyScalar(Math.pow(0.12, dt)); v.y -= 9 * dt; o.position.addScaledVector(v, dt); o.position.x += Math.sin(clockT * 5 + ph) * dt * 2; o.material.rotation += dt * 3; o.material.opacity = u > 0.7 ? (1 - u) / 0.3 : 1; }); }
}
// a jagged lightning arc between two points (re-rolled every frame it lives)
function zap(a, b, life, color) {
  const n = 9, pts = []; for (let i = 0; i <= n; i++) pts.push(new THREE.Vector3());
  const geo = new THREE.BufferGeometry().setFromPoints(pts);
  const line = new THREE.Line(geo, new THREE.LineBasicMaterial({color: color || 0xc8f8ff, transparent: true, depthWrite: false}));
  const glowS = []; for (let i = 0; i < 4; i++) { const s = sprite(T_FLASH, 0x7fe9ff, 2.2, true); scene.add(s); glowS.push(s); }
  addFx(line, life, (o, u) => { const A = typeof a === "function" ? a() : a, B = typeof b === "function" ? b() : b; const d = B.clone().sub(A), L0 = d.length(); const side = V(-d.z, 0, d.x).normalize();
    const arr = o.geometry.attributes.position; for (let i = 0; i <= n; i++) { const k = i / n, w = Math.sin(Math.PI * k) * L0 * 0.08; const p = A.clone().lerp(B, k).addScaledVector(side, (Math.random() - .5) * w * 2).add(V(0, (Math.random() - .5) * w * 2, 0)); arr.setXYZ(i, p.x, p.y, p.z); }
    arr.needsUpdate = true; o.material.opacity = (u < 0.7 ? 1 : (1 - u) / 0.3) * (0.6 + 0.4 * Math.random());
    glowS.forEach((s, i) => { const k = (i + 0.5) / glowS.length; s.position.copy(A.clone().lerp(B, k)); s.material.opacity = o.material.opacity * 0.6; if (u >= 0.99) scene.remove(s); }); });
}
// a simple projectile: any mesh / group from a point to a target along an arc
const flies = [];
function fly(o) { // o: {obj, from, to: () => V, T, H, spin, onHit, trail: color}
  scene.add(o.obj); flies.push(Object.assign({t: 0, prev: o.from.clone(), em: 0}, o));
}
function updateFlies(dt) {
  for (let i = flies.length - 1; i >= 0; i--) {
    const s = flies[i]; s.t += dt; const u = Math.min(1, s.t / s.T), to = s.to();
    const p = s.from.clone().lerp(to, u); p.y += 4 * s.H * u * (1 - u);
    if (s.obj.matrixAutoUpdate === false) { const M = s.mat ? s.mat(p, u) : worldM(p, 0, 2); s.obj.matrix.copy(M); } else { s.obj.position.copy(p); if (s.spin) s.obj.rotation.y += s.spin * dt; }
    if (s.trail) { s.em += dt * 40; while (s.em >= 1) { s.em -= 1; const q = s.prev.clone().lerp(p, Math.random()); const t = sprite(T_FLASH, s.trail, 1.4, true); t.position.copy(q); addFx(t, 0.3, (o2, uu) => { o2.material.opacity = 1 - uu; o2.scale.setScalar(1.4 * (1 - uu * 0.6)); }); } }
    s.prev.copy(p);
    if (u >= 1) { flies.splice(i, 1); if (!s.keep) scene.remove(s.obj); if (s.onHit) s.onHit(p); }
  }
}

// ---------- part state (written by the tracks, read by the piece anims) ----------
const MS = {};
function msReset() { Object.assign(MS, {spin: 0, spinV: 0, open: 0, flap: 0, hand: 0, lantern: 1, pod: 1, shed: 0, regrow: 1, rings: 1, cell: 1, unfold: 0, plume: 0, fort: 0, spring: 0, walk: 0, walkPh: 0}); for (const k in PGLOW) PGLOW[k] = 0; }
msReset();
const top = (x, z, only) => ray(V(x, 4, z), V(0, -1, 0), only);
const side = (s, y, z, only) => ray(V(3 * s, y, z), V(-s, 0, 0), only);
const MK = {}; // named points per look (launch points, centres)

// ===== H1 · Mender Drone (button) =====
(() => {
  const P = "mender";
  // A · Shoulder Dock: a feathered puck drone with two rotors, docked on an arch that straddles the back crest between the
  // shoulder blades (two feet plates on the back, posts, an arch over the crest)
  { const lk = P + ".A", z = -0.5, drone = [];
    for (const s of [1, -1]) { const h = top(0.2 * s, z, onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.14, 0.26, 0.05);
      const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Torso", G.box(0.07, 0.905 - y0, 0.15), MAT.gun, T3(0.2 * s, (y0 + 0.905) / 2, z)); }
    piece(lk, "Torso", G.box(0.52, 0.06, 0.2), MAT.gun, T3(0, 0.93, z));
    piece(lk, "Torso", G.box(0.2, 0.05, 0.14), MAT.brass, T3(0, 0.985, z), {anim: () => T3(0, 0.04 * MS.open, 0)}); // the clamp tongue lifts as it undocks
    drone.push(piece(lk, "Torso", G.cylY(0.21, 0.24, 0.12), MAT.gun, T3(0, 1.07, z)));
    drone.push(piece(lk, "Torso", G.cylY(0.245, 0.245, 0.04), MAT.brass, T3(0, 1.045, z)));
    drone.push(piece(lk, "Torso", G.sph(0.13, 1, 0.55, 1), gm(P, "green"), T3(0, 1.13, z)));
    drone.push(piece(lk, "Torso", G.cylZ(0.065, 0.065, 0.06), gm(P, "green"), T3(0, 1.06, z - 0.235)));
    drone.push(piece(lk, "Torso", G.cylX(0.03, 0.03, 0.7), MAT.dark, T3(0, 1.08, z)));
    for (const s of [1, -1]) { drone.push(piece(lk, "Torso", G.cylY(0.085, 0.1, 0.1), MAT.gun, T3(0.37 * s, 1.08, z)));
      drone.push(piece(lk, "Torso", G.box(0.42, 0.014, 0.07), MAT.brass, T3(0.37 * s, 1.14, z), {anim: () => rotY(MS.spin * s)})); }
    drone.push(piece(lk, "Torso", G.box(0.025, 0.16, 0.22), MAT.brass, AT(0, 1.16, z + 0.2, -28, 0, 0)));
    MK[lk] = {carry: makeCarry(drone, "Torso", V(0, 1.08, z))}; }
  // B · Tail Perch: a bird-shaped drone with folded feather wings, perched on a bridge over the tail crest (Tail1)
  { const lk = P + ".B", z = 1.45, drone = [];
    for (const s of [1, -1]) { const h = top(0.13 * s, z, onSeg("Tail1")); const F = bracket(lk, "Tail1", h, 0.1, 0.22, 0.05);
      const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Tail1", G.box(0.06, 0.8 - y0, 0.12), MAT.gun, T3(0.13 * s, (y0 + 0.8) / 2, z)); }
    piece(lk, "Tail1", G.box(0.34, 0.05, 0.16), MAT.gun, T3(0, 0.825, z));
    drone.push(piece(lk, "Tail1", G.sph(0.17, 0.85, 0.78, 1.5), MAT.gun, T3(0, 0.98, z)));
    drone.push(piece(lk, "Tail1", G.sph(0.105), MAT.plate, T3(0, 1.06, z - 0.27)));
    drone.push(piece(lk, "Tail1", G.cylZ(0.045, 0.045, 0.04), gm(P, "green"), T3(0, 1.08, z - 0.37)));
    drone.push(piece(lk, "Tail1", G.sph(0.09, 1, 0.5, 1), gm(P, "green"), T3(0, 1.1, z + 0.02)));
    for (const s of [1, -1]) drone.push(piece(lk, "Tail1", G.box(0.035, 0.12, 0.42), MAT.brass, AT(0.15 * s, 0.98, z + 0.04, 0, 0, 14 * s), {anim: () => rotZ(rad(-70 * s * MS.flap))}));
    drone.push(piece(lk, "Tail1", G.box(0.16, 0.025, 0.2), MAT.brass, AT(0, 1.0, z + 0.32, 12, 0, 0)));
    MK[lk] = {carry: makeCarry(drone, "Tail1", V(0, 0.98, z))}; }
  // C · Thigh Hangar: a capsule drone with a top rotor, held in a two-arm cradle on the outer +X thigh
  { const lk = P + ".C", drone = [];
    const h = side(1, -0.75, -0.18, onSeg("LegL")); const F = bracket(lk, "LegL", h, 0.3, 0.26, 0.05, V(0, 0, 1));
    for (const s of [1, -1]) piece(lk, "LegL", G.box(0.05, 0.16, 0.06), MAT.gun, L(F, 0.1 * s, 0.08, 0));
    const c = V(0, 0.16 + 0.15, 0).applyMatrix4(F);
    drone.push(piece(lk, "LegL", G.cylY(0.15, 0.15, 0.34), MAT.gun, T3(c.x, c.y, c.z)));
    drone.push(piece(lk, "LegL", G.cylY(0.155, 0.155, 0.07), gm(P, "green"), T3(c.x, c.y, c.z)));
    drone.push(piece(lk, "LegL", G.sph(0.15, 1, 0.55, 1), MAT.dark, T3(c.x, c.y - 0.17, c.z)));
    drone.push(piece(lk, "LegL", G.cylY(0.05, 0.05, 0.08), MAT.dark, T3(c.x, c.y + 0.21, c.z)));
    drone.push(piece(lk, "LegL", G.box(0.5, 0.014, 0.07), MAT.brass, T3(c.x, c.y + 0.255, c.z), {anim: () => rotY(MS.spin)}));
    MK[lk] = {carry: makeCarry(drone, "LegL", c)}; }
})();

// ===== A6 · Arc Lantern (button) =====
(() => {
  const P = "lantern";
  const lanternAt = (lk, seg, c, mats) => { // a caged lantern hanging from its handle; c = glass centre (model space)
    const out = [];
    out.push(piece(lk, seg, G.tor(0.065, 0.016), MAT.brass, T3(c.x, c.y + 0.255, c.z)));
    out.push(piece(lk, seg, G.cylY(0.1, 0.14, 0.07), MAT.gun, T3(c.x, c.y + 0.165, c.z)));
    out.push(piece(lk, seg, G.cylY(0.11, 0.11, 0.26), gm(P, "volt"), T3(c.x, c.y, c.z)));
    for (let i = 0; i < 4; i++) { const a = i * Math.PI / 2 + Math.PI / 4; out.push(piece(lk, seg, G.box(0.03, 0.26, 0.03), MAT.dark, T3(c.x + Math.cos(a) * 0.115, c.y, c.z + Math.sin(a) * 0.115))); }
    out.push(piece(lk, seg, G.cylY(0.14, 0.1, 0.07), MAT.gun, T3(c.x, c.y - 0.165, c.z)));
    out.push(piece(lk, seg, G.cone(0.05, 0.09), MAT.dark, AT(c.x, c.y - 0.245, c.z, 180, 0, 0)));
    return out; };
  // A · Hip Lantern: a caged lantern hanging from a hook arm on the back of the +X haunch
  { const lk = P + ".A"; const h = side(1, -0.08, 0.36, onSeg("LegL")); const F = bracket(lk, "LegL", h, 0.22, 0.2, 0.05, V(0, 0, 1));
    const x0 = V(0, 0, 0).applyMatrix4(F).x, cx = x0 + 0.21;
    piece(lk, "LegL", G.box(cx - x0 + 0.02, 0.06, 0.06), MAT.gun, T3((x0 + cx) / 2, h.p.y, h.p.z));
    piece(lk, "LegL", G.box(0.05, 0.1, 0.05), MAT.gun, T3(cx, h.p.y - 0.05, h.p.z));
    const c = V(cx, h.p.y - 0.42, h.p.z);
    MK[lk] = {carry: makeCarry(lanternAt(lk, "LegL", c), "LegL", c)}; }
  // B · Tail Lure: a boom on Tail3 that arcs up and back, the lantern bulb hanging from its tip like an angler fish's lure
  { const lk = P + ".B", z = 3.72; const h = top(0, z, onSeg("Tail3")); const F = bracket(lk, "Tail3", h, 0.2, 0.2, 0.05);
    const b0 = V(0, 0, 0).applyMatrix4(F);
    piece(lk, "Tail3", G.cylY(0.035, 0.05, 0.62), MAT.gun, AT(0, b0.y + 0.28, z + 0.12, 22, 0, 0));
    const tip = V(0, b0.y + 0.56, z + 0.24);
    piece(lk, "Tail3", G.cylZ(0.03, 0.03, 0.34), MAT.gun, T3(0, tip.y, tip.z + 0.16));
    piece(lk, "Tail3", G.box(0.016, 0.1, 0.016), MAT.dark, T3(0, tip.y - 0.05, tip.z + 0.32));
    const c = V(0, tip.y - 0.25, tip.z + 0.32);
    const bulb = [piece(lk, "Tail3", G.sph(0.13, 1, 1.2, 1), gm(P, "volt"), T3(c.x, c.y, c.z)), piece(lk, "Tail3", G.cylY(0.05, 0.1, 0.07), MAT.brass, T3(c.x, c.y + 0.16, c.z))];
    MK[lk] = {carry: makeCarry(bulb, "Tail3", c)}; }
  // C · Wrist Lantern: a square lantern clipped to the front of the +X forearm (rides the arm into the throw)
  { const lk = P + ".C"; const h = ray(V(0.42, -1.18, -4), V(0, 0, 1), onSeg("ArmL")); const F = bracket(lk, "ArmL", h, 0.13, 0.26, 0.04, V(0, -1, -0.4));
    const out = [piece(lk, "ArmL", G.box(0.2, 0.2, 0.22), gm(P, "volt"), L(F, 0, 0.11, 0))];
    for (const s of [1, -1]) out.push(piece(lk, "ArmL", G.box(0.25, 0.24, 0.04), MAT.gun, L(F, 0, 0.12, 0.13 * s)));
    out.push(piece(lk, "ArmL", G.tor(0.06, 0.015), MAT.brass, L(F, 0, 0.27, 0, 0, 90, 0)));
    MK[lk] = {carry: makeCarry(out, "ArmL", V(0, 0.11, 0).applyMatrix4(F))}; }
})();

// ===== D1 · Sap Wall (button) =====
(() => {
  const P = "sapwall";
  // A · Saddle Tanks: two amber sap tanks either side of the back crest, a manifold over it with the next pod in its hatch
  { const lk = P + ".A", z = -0.02; let yc = 0;
    for (const s of [1, -1]) { const h = top(0.17 * s, z, onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.14, 0.46, 0.05);
      piece(lk, "Torso", G.cylZ(0.105, 0.105, 0.5), gm(P, "glassA"), L(F, 0, 0.1, 0));
      for (const e of [1, -1]) piece(lk, "Torso", G.cylZ(0.12, 0.12, 0.06), MAT.gun, L(F, 0, 0.1, 0.27 * e));
      yc = V(0, 0.1, 0).applyMatrix4(F).y; }
    piece(lk, "Torso", G.box(0.24, 0.07, 0.14), MAT.gun, T3(0, yc + 0.02, z));
    piece(lk, "Torso", G.cylY(0.075, 0.09, 0.08), MAT.dark, T3(0, yc + 0.095, z));
    MK[lk] = {carry: makeCarry([piece(lk, "Torso", G.sph(0.085), gm(P, "amber"), T3(0, yc + 0.2, z))], "Torso", V(0, yc + 0.2, z))}; }
  // B · Shoulder Pod: one big amber pod in a ring cradle on the +X shoulder (the arm reaches up and takes it)
  { const lk = P + ".B"; const h = ray(V(1.2, 1.6, -1.05), V(-0.55, -0.83, 0), b => b.seg === "Torso" && notThin(b)); const F = bracket(lk, "Torso", h, 0.2, 0.24, 0.05);
    for (const s of [1, -1]) piece(lk, "Torso", G.box(0.04, 0.15, 0.05), MAT.gun, L(F, 0.15 * s, 0.1, 0));
    piece(lk, "Torso", G.tor(0.19, 0.032), MAT.brass, L(F, 0, 0.17, 0, 90, 0, 0));
    MK[lk] = {carry: makeCarry([piece(lk, "Torso", G.sph(0.19), gm(P, "glassA"), L(F, 0, 0.23, 0))], "Torso", V(0, 0.23, 0).applyMatrix4(F))}; }
  // C · Belly Pod: a big sap pod slung under the chest in two half-ring straps (it drops straight into the hands)
  { const lk = P + ".C"; const h = ray(V(0, -3, -1.0), V(0, 1, 0), onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.3, 0.34, 0.04, V(0, 0, 1));
    for (const s of [1, -1]) piece(lk, "Torso", G.tor(0.205, 0.025, Math.PI), MAT.gun, L(F, 0, 0.0, 0.12 * s));
    MK[lk] = {carry: makeCarry([piece(lk, "Torso", G.sph(0.19, 1, 0.85, 1.3), gm(P, "glassA"), L(F, 0, 0.19, 0))], "Torso", V(0, 0.19, 0).applyMatrix4(F))}; }
})();

// ===== D18 · Feather Shed (button) =====
(() => {
  const P = "shed";
  // A · Flank Plates: two big steel feather plates on each flank, hung from rail arms over the back edge; release bolts glow
  { const lk = P + ".A", shed = [];
    for (const s of [1, -1]) {
      for (const z of [-0.62, 0.0]) { const h = top(0.31 * s, z, onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.12, 0.12, 0.05);
        const y = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Torso", G.box(0.42, 0.05, 0.07), MAT.gun, T3(0.5 * s, y + 0.02, z));
        shed.push(piece(lk, "Torso", G.cylX(0.04, 0.04, 0.06), gm(P, "amber"), T3(0.72 * s, y + 0.02, z))); }
      shed.push(piece(lk, "Torso", G.box(0.035, 0.36, 0.62), MAT.plate, AT(0.71 * s, 0.48, -0.6, 0, 0, 7 * s)));
      shed.push(piece(lk, "Torso", G.box(0.035, 0.32, 0.56), MAT.plate, AT(0.715 * s, 0.46, -0.02, 0, 0, 7 * s)));
      shed.push(piece(lk, "Torso", G.box(0.045, 0.05, 1.18), MAT.brass, T3(0.71 * s, 0.665, -0.31))); }
    MK[lk] = {shed}; }
  // B · Quill Rack: a saddle on the lower back with four big steel quills fanned up and back; they blast off
  { const lk = P + ".B", z = 0.5, shed = [];
    for (const s of [1, -1]) { const h = top(0.17 * s, z, onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.12, 0.3, 0.05);
      const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Torso", G.box(0.07, 0.72 - y0, 0.18), MAT.gun, T3(0.17 * s, (y0 + 0.72) / 2, z)); }
    piece(lk, "Torso", G.box(0.44, 0.07, 0.22), MAT.gun, T3(0, 0.75, z));
    [-42, -14, 14, 42].forEach((a, i) => { const q = G.box(0.05, 0.56, 0.12); gx(q, T3(0, 0.28, 0));
      shed.push(piece(lk, "Torso", q, i % 2 ? MAT.plate : MAT.steel, AT(-0.13 + i * 0.087, 0.78, z + 0.02, 34, 0, -a))); });
    shed.push(piece(lk, "Torso", G.box(0.3, 0.05, 0.08), gm(P, "amber"), T3(0, 0.8, z - 0.06)));
    MK[lk] = {shed}; }
  // C · Tail Jacket: a long feather plate clamped on each side of the tail base (Tail1), release bolts on top
  { const lk = P + ".C", shed = [];
    for (const s of [1, -1]) {
      for (const z of [1.02, 1.82]) { const h = side(s, 0.36, z, onSeg("Tail1")); bracket(lk, "Tail1", h, 0.16, 0.14, 0.04, V(0, 0, 1)); }
      const x = side(s, 0.36, 1.02, onSeg("Tail1")).p.x + 0.04 * s;
      shed.push(piece(lk, "Tail1", G.box(0.035, 0.34, 1.02), MAT.plate, AT(x + 0.02 * s, 0.32, 1.42, 0, 0, 0)));
      shed.push(piece(lk, "Tail1", G.box(0.05, 0.05, 1.02), MAT.brass, T3(x + 0.025 * s, 0.505, 1.42)));
      for (const z of [1.02, 1.82]) shed.push(piece(lk, "Tail1", G.cylX(0.035, 0.035, 0.05), gm(P, "amber"), T3(x + 0.06 * s, 0.4, z))); }
    MK[lk] = {shed}; }
})();

// ===== S6 · Portal Feathers (button) =====
(() => {
  const P = "portal";
  const ringAround = (lk, seg, z, R, t) => { // a ring round the tail at z, clamped top and bottom; 4 feather vanes on the rim
    const ht = top(0, z, onSeg(seg)), hb = ray(V(0, -3, z), V(0, 1, 0), onSeg(seg)); const cy = (ht.p.y + hb.p.y) / 2;
    const parts = [piece(lk, seg, G.tor(R, t), gm(P, "teal"), T3(0, cy, z))];
    for (let i = 0; i < 4; i++) { const a = Math.PI / 4 + i * Math.PI / 2; const q = G.box(0.035, 0.17, 0.08); parts.push(piece(lk, seg, q, MAT.brass, AT(Math.cos(a) * (R + t + 0.07), cy + Math.sin(a) * (R + t + 0.07), z, 0, 0, deg(a) - 90))); }
    for (const [hh, sg] of [[ht, 1], [hb, -1]]) { const gap = (cy + sg * (R - t)) - hh.p.y; piece(lk, seg, G.box(0.1, Math.abs(gap) + 0.04, 0.09), MAT.dark, T3(0, hh.p.y + gap / 2, z), {bracket: true, name: "clamp"}); }
    return {parts, c: V(0, cy, z)}; };
  // A · Tail Rings: two portal rings worn round the tail (Tail2), clamped top and bottom
  { const lk = P + ".A"; const r1 = ringAround(lk, "Tail2", 2.24, 0.37, 0.05), r2 = ringAround(lk, "Tail2", 3.12, 0.33, 0.05);
    MK[lk] = {carries: [makeCarry(r1.parts, "Tail2", r1.c), makeCarry(r2.parts, "Tail2", r2.c)]}; }
  // B · Shin Hoops: a portal hoop round each shin like an anklet, on a clamp at the back of the shin
  { const lk = P + ".B", cs = [];
    for (const s of [1, -1]) { const seg = s > 0 ? "ShinL" : "ShinR"; const sh = BODY.find(b => b.n === seg + "_shin");
      const c = V(0, -0.15, 0).applyMatrix4(sh.m); const ax = V(0, 1, 0).transformDirection(sh.m);
      const q = new THREE.Quaternion().setFromUnitVectors(V(0, 0, 1), ax); const M = new THREE.Matrix4().compose(c, q, V(1, 1, 1));
      const ring = [piece(lk, seg, G.tor(0.21, 0.045), gm(P, "teal"), M)];
      for (let i = 0; i < 4; i++) { const a = i * Math.PI / 2 + Math.PI / 4; ring.push(piece(lk, seg, G.box(0.03, 0.12, 0.06), MAT.brass, M.clone().multiply(AT(Math.cos(a) * 0.3, Math.sin(a) * 0.3, 0, 0, 0, deg(a) - 90)))); }
      const hb = ray(c.clone().add(V(0, 0, 2)), V(0, 0, -1), b => b.n === seg + "_shin"); const gap = 0.21 - 0.045 - (hb.p.z - c.z);
      piece(lk, seg, G.box(0.08, 0.1, gap + 0.04), MAT.dark, T3(hb.p.x, hb.p.y, hb.p.z + gap / 2), {bracket: true, name: "clamp"});
      cs.push(makeCarry(ring, seg, c)); }
    MK[lk] = {carries: cs}; }
  // C · Arm Hoops: a portal hoop round each upper arm, on a clamp at the outside of the arm
  { const lk = P + ".C", cs = [];
    for (const s of [1, -1]) { const seg = s > 0 ? "ArmL" : "ArmR"; const up = BODY.find(b => b.n === seg + "_upper");
      const c = V(0, 0.22, 0).applyMatrix4(up.m); const ax = V(0, 1, 0).transformDirection(up.m);
      const q = new THREE.Quaternion().setFromUnitVectors(V(0, 0, 1), ax); const M = new THREE.Matrix4().compose(c, q, V(1, 1, 1));
      const ring = [piece(lk, seg, G.tor(0.21, 0.045), gm(P, "teal"), M)];
      for (let i = 0; i < 4; i++) { const a = i * Math.PI / 2 + Math.PI / 4; ring.push(piece(lk, seg, G.box(0.03, 0.12, 0.06), MAT.brass, M.clone().multiply(AT(Math.cos(a) * 0.3, Math.sin(a) * 0.3, 0, 0, 0, deg(a) - 90)))); }
      const hs = side(s, c.y, c.z, b => b.n === seg + "_upper"); const gap = 0.21 - 0.045 - Math.abs(hs.p.x - c.x);
      piece(lk, seg, G.box(gap + 0.04, 0.1, 0.08), MAT.dark, T3(hs.p.x + s * gap / 2, hs.p.y, hs.p.z), {bracket: true, name: "clamp"});
      cs.push(makeCarry(ring, seg, c)); }
    MK[lk] = {carries: cs}; }
})();

// ===== H7 · Last Feather (always on) =====
(() => {
  const P = "lastfeather";
  // A · Tail-Base Cell: a reserve cell lying along the top of the tail base, on a saddle over the crest; amber window
  { const lk = P + ".A", z = 1.0; let y = 0;
    for (const s of [1, -1]) { const h = top(0.13 * s, z, onSeg("Tail1")); const F = bracket(lk, "Tail1", h, 0.1, 0.3, 0.05, V(0, 0, 1));
      const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Tail1", G.box(0.06, 0.7 - y0, 0.2), MAT.gun, T3(0.13 * s, (y0 + 0.7) / 2, z)); y = 0.7; }
    piece(lk, "Tail1", G.box(0.32, 0.04, 0.24), MAT.gun, T3(0, y + 0.02, z));
    piece(lk, "Tail1", G.cylZ(0.11, 0.11, 0.42), MAT.gun, T3(0, y + 0.15, z));
    piece(lk, "Tail1", G.cylZ(0.115, 0.115, 0.16), gm(P, "amber"), T3(0, y + 0.15, z));
    for (const e of [1, -1]) piece(lk, "Tail1", G.cylZ(0.12, 0.12, 0.05), MAT.brass, T3(0, y + 0.15, z + 0.2 * e));
    piece(lk, "Tail1", G.box(0.025, 0.14, 0.24), MAT.brass, AT(0, y + 0.3, z + 0.02, -12, 0, 0));
    MK[lk] = {c: V(0, y + 0.15, z)}; }
  // B · Heart Core: a round reserve core in a ring frame on the chest (faces the attacker)
  { const lk = P + ".B"; const h = ray(V(0, 0.18, -4), V(0, 0, 1), onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.3, 0.3, 0.04, V(0, 1, 0));
    piece(lk, "Torso", G.cylY(0.16, 0.16, 0.06), MAT.gun, L(F, 0, 0.03, 0));
    piece(lk, "Torso", G.tor(0.15, 0.03), MAT.brass, L(F, 0, 0.07, 0, 90, 0, 0));
    piece(lk, "Torso", G.sph(0.12, 1, 0.7, 1), gm(P, "amber"), L(F, 0, 0.09, 0));
    MK[lk] = {c: V(0, 0.09, 0).applyMatrix4(F)}; }
  // C · Wing Pack: a pack on the lower back over the crest; two folded emergency wing fans swing up when it fires
  { const lk = P + ".C", z = 0.55;
    for (const s of [1, -1]) { const h = top(0.18 * s, z, onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.14, 0.34, 0.05);
      const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Torso", G.box(0.14, 0.73 - y0, 0.3), MAT.gun, T3(0.18 * s, (y0 + 0.73) / 2, z)); }
    piece(lk, "Torso", G.box(0.5, 0.08, 0.32), MAT.gun, T3(0, 0.77, z));
    piece(lk, "Torso", G.box(0.26, 0.04, 0.2), gm(P, "amber"), T3(0, 0.82, z));
    for (const s of [1, -1]) { const w = G.box(0.5, 0.03, 0.26); gx(w, T3(0.25 * s, 0, 0)); piece(lk, "Torso", w, MAT.plate, T3(0.13 * s, 0.825, z + 0.02), {anim: () => rotZ(rad(s * 70 * MS.unfold))}); }
    MK[lk] = {c: V(0, 0.8, z)}; }
})();

// ===== H12 · Overheal Plume (always on) =====
(() => {
  const P = "plume";
  const fan = (lk, seg, F, n, len, spread, mat) => { for (let i = 0; i < n; i++) { const a = -spread / 2 + spread * i / (n - 1); const b = G.box(0.05, len, 0.1); gx(b, T3(0, len / 2, 0)); piece(lk, seg, b, mat || gm(P, "gold"), F.clone().multiply(R3(0, 0, a))); } };
  // A · Tail Plume: a fan of five gold armour feathers standing up from a clamp on the tail (Tail4); they light up as it fills
  { const lk = P + ".A", z = 4.82; const h = top(0, z, onSeg("Tail4")); const F = bracket(lk, "Tail4", h, 0.14, 0.24, 0.05);
    piece(lk, "Tail4", G.cylZ(0.07, 0.07, 0.2), MAT.gun, L(F, 0, 0.07, 0));
    fan(lk, "Tail4", L(F, 0, 0.1, 0.02, 28, 0, 0), 5, 0.62, 100);
    MK[lk] = {c: V(0, 0.35, 0).applyMatrix4(F)}; }
  // B · Helm Plume: a short armour crest on the back of the skull, three gold blades swept back
  { const lk = P + ".B"; const h = top(0, -2.9, b => b.n === "Head_cranium"); const F = bracket(lk, "Head", h, 0.24, 0.26, 0.05);
    piece(lk, "Head", G.box(0.1, 0.08, 0.22), MAT.gun, L(F, 0, 0.05, 0));
    fan(lk, "Head", L(F, 0, 0.08, 0.04, 52, 0, 0), 3, 0.5, 44);
    MK[lk] = {c: V(0, 0.25, 0.1).applyMatrix4(F)}; }
  // C · Back Plume: a tall fan of five gold feathers on a saddle over the mid back
  { const lk = P + ".C", z = -0.02;
    for (const s of [1, -1]) { const h = top(0.15 * s, z, onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.12, 0.24, 0.05);
      const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Torso", G.box(0.06, 0.74 - y0, 0.14), MAT.gun, T3(0.15 * s, (y0 + 0.74) / 2, z)); }
    piece(lk, "Torso", G.box(0.38, 0.06, 0.18), MAT.gun, T3(0, 0.77, z));
    fan(lk, "Torso", AT(0, 0.8, z, 22, 0, 0), 5, 0.6, 110);
    MK[lk] = {c: V(0, 1.05, z)}; }
})();

// ===== D5 · Fortify Field (always on) =====
(() => {
  const P = "fortify";
  const hexPlate = (lk, seg, F) => { piece(lk, seg, G.cylY(0.12, 0.12, 0.05, 6), MAT.gun, L(F, 0, 0.025, 0)); piece(lk, seg, G.cylY(0.085, 0.085, 0.04, 6), gm(P, "teal"), L(F, 0, 0.06, 0)); };
  // A · Wrist Bracers: a bracer with a teal hex emitter on the front of each forearm (the pod leaves the hands past them)
  { const lk = P + ".A";
    for (const s of [1, -1]) { const seg = s > 0 ? "ArmL" : "ArmR"; const h = ray(V(0.42 * s, -1.42, -4), V(0, 0, 1), onSeg(seg)); const F = bracket(lk, seg, h, 0.14, 0.34, 0.04, V(0, -1, -0.4));
      piece(lk, seg, G.box(0.17, 0.05, 0.3), MAT.plate, L(F, 0, 0.03, 0)); hexPlate(lk, seg, L(F, 0, 0.055, 0)); }
    MK[lk] = {}; }
  // B · Neck Pylon: a mast on a bridge over the back crest behind the neck, a teal emitter dish on top
  { const lk = P + ".B", z = -1.28;
    for (const s of [1, -1]) { const h = top(0.19 * s, z, b => b.seg === "Torso" && notThin(b)); const F = bracket(lk, "Torso", h, 0.12, 0.2, 0.05);
      const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Torso", G.box(0.06, 0.97 - y0, 0.12), MAT.gun, T3(0.19 * s, (y0 + 0.97) / 2, z)); }
    piece(lk, "Torso", G.box(0.44, 0.06, 0.16), MAT.gun, T3(0, 1.0, z));
    piece(lk, "Torso", G.cylY(0.035, 0.045, 0.42), MAT.steel, T3(0, 1.24, z + 0.02));
    piece(lk, "Torso", G.cylY(0.2, 0.08, 0.06), MAT.gun, AT(0, 1.47, z + 0.04, 18, 0, 0));
    piece(lk, "Torso", G.cylY(0.15, 0.15, 0.03, 6), gm(P, "teal"), AT(0, 1.505, z + 0.05, 18, 0, 0));
    MK[lk] = {c: V(0, 1.5, z)}; }
  // C · Tail Emitters: a teal hex emitter on each side of the tail base (Tail1)
  { const lk = P + ".C";
    for (const s of [1, -1]) { const h = side(s, 0.3, 1.0, onSeg("Tail1")); const F = bracket(lk, "Tail1", h, 0.24, 0.26, 0.04, V(0, 1, 0)); hexPlate(lk, "Tail1", F); }
    MK[lk] = {}; }
})();

// ===== A10 · Ricochet Pod (always on) =====
(() => {
  const P = "ricochet";
  // A · Spring Cups: a sprung brass cup on the front of each hand; the pod sits in them and they kick as it leaves
  { const lk = P + ".A";
    for (const s of [1, -1]) { const seg = s > 0 ? "ArmL" : "ArmR"; const h = ray(V(0.42 * s, -1.8, -4), V(0, 0, 1), onSeg(seg)); const F = bracket(lk, seg, h, 0.15, 0.24, 0.04, V(0, -1, 0));
      piece(lk, seg, G.cylY(0.06, 0.06, 0.08), MAT.steel, L(F, 0, 0.05, 0), {anim: () => scl(1, 1 - 0.5 * MS.spring, 1).premultiply(T3(0, -0.02 * MS.spring, 0))});
      piece(lk, seg, G.cylY(0.13, 0.09, 0.08), MAT.brass, L(F, 0, 0.12, 0), {anim: () => T3(0, -0.04 * MS.spring, 0)});
      piece(lk, seg, G.cylY(0.1, 0.1, 0.02), gm(P, "amber"), L(F, 0, 0.165, 0), {anim: () => T3(0, -0.04 * MS.spring, 0)}); }
    MK[lk] = {}; }
  // B · Elbow Springs: a coil-spring housing on the outside of each elbow, a bounce gauge on top
  { const lk = P + ".B";
    for (const s of [1, -1]) { const seg = s > 0 ? "ArmL" : "ArmR"; const h = side(s, -0.62, -1.4, b => b.n === seg + "_upper"); const F = bracket(lk, seg, h, 0.3, 0.16, 0.04, V(0, 1, 0));
      piece(lk, seg, G.cylZ(0.07, 0.07, 0.24), MAT.gun, L(F, 0, 0.09, 0, 90, 0, 0));
      for (let i = 0; i < 3; i++) piece(lk, seg, G.tor(0.085, 0.018), MAT.brass, L(F, 0, 0.09, -0.08 + i * 0.08, 90, 0, 0), {anim: () => T3(0, 0, -0.03 * MS.spring * (i - 1))});
      piece(lk, seg, G.cylY(0.05, 0.05, 0.03), gm(P, "amber"), L(F, 0, 0.09, 0.14, 90, 0, 0)); }
    MK[lk] = {}; }
  // C · Chest Pad: a sprung bounce pad on the chest; the pod rolls off it as the arms swing past
  { const lk = P + ".C"; const h = ray(V(0, 0.32, -4), V(0, 0, 1), onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.32, 0.34, 0.04, V(0, 1, 0));
    for (const s of [1, -1]) piece(lk, "Torso", G.cylY(0.04, 0.04, 0.1), MAT.steel, L(F, 0.1 * s, 0.05, 0), {anim: () => scl(1, 1 - 0.4 * MS.spring, 1)});
    piece(lk, "Torso", G.box(0.36, 0.04, 0.3), MAT.brass, L(F, 0, 0.12, 0), {anim: () => T3(0, -0.04 * MS.spring, 0)});
    piece(lk, "Torso", G.box(0.26, 0.02, 0.2), gm(P, "amber"), L(F, 0, 0.145, 0), {anim: () => T3(0, -0.04 * MS.spring, 0)});
    MK[lk] = {}; }
})();
