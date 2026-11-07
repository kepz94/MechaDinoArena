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
  tor: (R, r, arc) => shp(new THREE.TorusGeometry(R, r, 10, 32, arc || Math.PI * 2), {t: "tor", R, r, arc: arc || Math.PI * 2}), // XY plane, axis Z
  cone: (r, len, n) => G.cylY(0, r, len, n),
};
const MECH = [], PCOUNT = {};
const segInv = {}; for (const s of TROODON.segs) segInv[s.n] = cfm(s.root).invert();
// at: the piece's rest-pose matrix in model space at scale 1 (the model data's own frame)
function piece(look, seg, geo, mat, at, o) {
  o = o || {};
  const m = new THREE.Mesh(geo, mat); m.matrixAutoUpdate = false; m.castShadow = true; hero.g.add(m);
  const base = segInv[seg].clone().multiply(at);
  PCOUNT[look] = (PCOUNT[look] || 0) + 1;
  const info = {name: look + "#" + PCOUNT[look] + " " + (o.name || geo.userData.shape.t) + "@" + seg, seg, mesh: m, local: base.clone(), base, at: at.clone(), size: [0, 0, 0], kind: "mech", look, part: look.split(".")[0], anim: o.anim, show: o.show, bracket: !!o.bracket, carry: null};
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
const topHit = (x, z, only) => ray(V(x, 4, z), V(0, -1, 0), only);
const side = (s, y, z, only) => ray(V(3 * s, y, z), V(-s, 0, 0), only);
const MK = {}; // named points per look (launch points, centres)

// Layout on the back (rest pose, model z; recommended looks get their own band, alternates share the spare bands):
//   z -1.05 Neck Pylon (D5 B) · z -0.35 Mender Drone dock (H1 A) · z 0.15..0.75 spare band (D1 A, D18 B, H7 C, H12 C)
//   tail base z 0.83..1.27 Last Feather cell (H7 A) · z 1.7 spare (H1 B) · Tail2 rings (S6 A) · Tail3 lure (A6 B) · Tail4 plume (H12 A)
//   +X shoulder side: Sap pod (D1 B) · flanks: Feather Shed plates (D18 A) · +X haunch: Arc Lantern (A6 A) · hands: Ricochet cups (A10 A)
// ===== H1 · Mender Drone (button) =====
(() => {
  const P = "mender";
  // A · Shoulder Dock: a ducted-fan puck drone (a rotor ring round a heal dome), docked on an arch that straddles the back
  // crest between the shoulder blades (two feet plates, posts, the arch)
  { const lk = P + ".A", z = -0.35, drone = [];
    for (const s of [1, -1]) { const h = topHit(0.22 * s, z, onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.17, 0.3, 0.05);
      const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Torso", G.box(0.09, 0.9 - y0, 0.2), MAT.gun, T3(0.22 * s, (y0 + 0.9) / 2, z)); }
    piece(lk, "Torso", G.box(0.6, 0.07, 0.28), MAT.gun, T3(0, 0.925, z));
    piece(lk, "Torso", G.box(0.26, 0.05, 0.18), MAT.brass, T3(0, 0.985, z), {anim: () => T3(0, 0.05 * MS.open, 0)});
    drone.push(piece(lk, "Torso", G.cylY(0.27, 0.31, 0.2), MAT.gun, T3(0, 1.11, z)));
    drone.push(piece(lk, "Torso", G.sph(0.21, 1, 0.6, 1), gm(P, "green"), T3(0, 1.21, z)));
    drone.push(piece(lk, "Torso", G.tor(0.43, 0.055), MAT.brass, AT(0, 1.11, z, 90, 0, 0)));
    for (let i = 0; i < 4; i++) { const a = i * Math.PI / 2 + Math.PI / 4; drone.push(piece(lk, "Torso", G.box(0.12, 0.03, 0.05), MAT.dark, AT(Math.cos(a) * 0.35, 1.11, z + Math.sin(a) * 0.35, 0, -deg(a), 0))); }
    drone.push(piece(lk, "Torso", G.box(0.62, 0.016, 0.08), MAT.steel, T3(0, 1.06, z), {anim: () => rotY(MS.spin)}));
    drone.push(piece(lk, "Torso", G.cylZ(0.08, 0.08, 0.06), gm(P, "green"), T3(0, 1.1, z - 0.3)));
    drone.push(piece(lk, "Torso", G.box(0.04, 0.26, 0.36), MAT.brass, AT(0, 1.3, z + 0.34, -30, 0, 0)));
    MK[lk] = {carry: makeCarry(drone, "Torso", V(0, 1.11, z))}; }
  // B · Tail Perch: a bird-shaped drone with folded brass wings, perched on a bridge over the tail crest (Tail2)
  { const lk = P + ".B", z = 2.68, drone = [];
    for (const s of [1, -1]) { const h = topHit(0.12 * s, z, onSeg("Tail2")); const F = bracket(lk, "Tail2", h, 0.1, 0.2, 0.05);
      const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Tail2", G.box(0.06, 0.85 - y0, 0.12), MAT.gun, T3(0.12 * s, (y0 + 0.85) / 2, z)); }
    piece(lk, "Tail2", G.box(0.34, 0.05, 0.18), MAT.gun, T3(0, 0.875, z));
    drone.push(piece(lk, "Tail2", G.sph(0.24, 0.85, 0.78, 1.15), MAT.gun, T3(0, 1.087, z)));
    drone.push(piece(lk, "Tail2", G.sph(0.14), MAT.plate, T3(0, 1.21, z - 0.3)));
    drone.push(piece(lk, "Tail2", G.cylZ(0.06, 0.06, 0.05), gm(P, "green"), T3(0, 1.24, z - 0.43)));
    drone.push(piece(lk, "Tail2", G.sph(0.13, 1, 0.5, 1), gm(P, "green"), T3(0, 1.24, z + 0.02)));
    for (const s of [1, -1]) drone.push(piece(lk, "Tail2", G.box(0.05, 0.17, 0.48), MAT.brass, AT(0.215 * s, 1.09, z + 0.03, 0, 0, 14 * s), {anim: () => rotZ(rad(-70 * s * MS.flap))}));
    drone.push(piece(lk, "Tail2", G.box(0.22, 0.035, 0.2), MAT.brass, AT(0, 1.13, z + 0.33, 12, 0, 0)));
    MK[lk] = {carry: makeCarry(drone, "Tail2", V(0, 1.087, z))}; }
  // C · Chest Cradle: a capsule drone with a top rotor, held in a two-arm cradle on the front of the chest, between the arms
  { const lk = P + ".C", drone = [];
    const h = ray(V(0, -0.02, -4), V(0, 0, 1), onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.3, 0.22, 0.05, V(0, 1, 0));
    for (const s of [1, -1]) piece(lk, "Torso", G.box(0.06, 0.2, 0.08), MAT.gun, L(F, 0.12 * s, 0.1, 0));
    const c = V(0, 0.2 + 0.2, 0).applyMatrix4(F);
    drone.push(piece(lk, "Torso", G.cylY(0.2, 0.2, 0.4), MAT.gun, T3(c.x, c.y, c.z)));
    drone.push(piece(lk, "Torso", G.cylY(0.208, 0.208, 0.09), gm(P, "green"), T3(c.x, c.y, c.z)));
    drone.push(piece(lk, "Torso", G.sph(0.2, 1, 0.5, 1), MAT.dark, T3(c.x, c.y - 0.2, c.z)));
    drone.push(piece(lk, "Torso", G.cylY(0.06, 0.06, 0.08), MAT.dark, T3(c.x, c.y + 0.24, c.z)));
    drone.push(piece(lk, "Torso", G.box(0.6, 0.02, 0.09), MAT.brass, T3(c.x, c.y + 0.29, c.z), {anim: () => rotY(MS.spin)}));
    MK[lk] = {carry: makeCarry(drone, "Torso", c)}; }
})();

// ===== A6 · Arc Lantern (button) =====
(() => {
  const P = "lantern";
  const lanternAt = (lk, seg, c, k) => { // a caged storm lantern hanging from its handle; c = glass centre (model space), k = size
    const out = [];
    out.push(piece(lk, seg, G.tor(0.1 * k, 0.025 * k), MAT.brass, T3(c.x, c.y + 0.4 * k, c.z)));
    out.push(piece(lk, seg, G.cylY(0.15 * k, 0.22 * k, 0.11 * k), MAT.gun, T3(c.x, c.y + 0.255 * k, c.z)));
    out.push(piece(lk, seg, G.cylY(0.17 * k, 0.17 * k, 0.4 * k), gm(P, "volt"), T3(c.x, c.y, c.z)));
    for (let i = 0; i < 4; i++) { const a = i * Math.PI / 2 + Math.PI / 4; out.push(piece(lk, seg, G.box(0.045 * k, 0.4 * k, 0.045 * k), MAT.dark, T3(c.x + Math.cos(a) * 0.175 * k, c.y, c.z + Math.sin(a) * 0.175 * k))); }
    out.push(piece(lk, seg, G.cylY(0.22 * k, 0.15 * k, 0.11 * k), MAT.gun, T3(c.x, c.y - 0.255 * k, c.z)));
    out.push(piece(lk, seg, G.cone(0.08 * k, 0.14 * k), MAT.dark, AT(c.x, c.y - 0.38 * k, c.z, 180, 0, 0)));
    return out; };
  // A · Hip Lantern: a caged storm lantern hanging from a hook arm on the back of the +X haunch
  { const lk = P + ".A"; const h = side(1, -0.1, 0.36, onSeg("LegL")); const F = bracket(lk, "LegL", h, 0.26, 0.24, 0.05, V(0, 0, 1));
    const x0 = V(0, 0, 0).applyMatrix4(F).x, cx = x0 + 0.3;
    piece(lk, "LegL", G.box(cx - x0 + 0.03, 0.08, 0.08), MAT.gun, T3((x0 + cx) / 2, h.p.y, h.p.z));
    piece(lk, "LegL", G.box(0.07, 0.12, 0.07), MAT.gun, T3(cx, h.p.y - 0.06, h.p.z));
    const c = V(cx, h.p.y - 0.62, h.p.z);
    MK[lk] = {carry: makeCarry(lanternAt(lk, "LegL", c, 1), "LegL", c)}; }
  // B · Tail Lure: a boom on Tail3 that arcs up and back, the bulb hanging from its tip like an angler fish's lure
  { const lk = P + ".B", z = 3.72; const h = topHit(0, z, onSeg("Tail3")); const F = bracket(lk, "Tail3", h, 0.22, 0.24, 0.05);
    const b0 = V(0, 0, 0).applyMatrix4(F);
    piece(lk, "Tail3", G.cylY(0.045, 0.065, 0.84), MAT.gun, AT(0, b0.y + 0.39, z + 0.16, 24, 0, 0));
    const tip = V(0, b0.y + 0.77, z + 0.33);
    piece(lk, "Tail3", G.sph(0.06), MAT.brass, T3(0, tip.y, tip.z));
    piece(lk, "Tail3", G.cylZ(0.04, 0.04, 0.4), MAT.gun, T3(0, tip.y, tip.z + 0.2));
    piece(lk, "Tail3", G.box(0.02, 0.12, 0.02), MAT.dark, T3(0, tip.y - 0.06, tip.z + 0.38));
    const c = V(0, tip.y - 0.36, tip.z + 0.38);
    const bulb = [piece(lk, "Tail3", G.sph(0.2, 1, 1.15, 1), gm(P, "volt"), T3(c.x, c.y, c.z)), piece(lk, "Tail3", G.cylY(0.07, 0.15, 0.1), MAT.brass, T3(c.x, c.y + 0.25, c.z)), piece(lk, "Tail3", G.tor(0.2, 0.025), MAT.dark, AT(c.x, c.y, c.z, 90, 0, 0))];
    MK[lk] = {carry: makeCarry(bulb, "Tail3", c)}; }
  // C · Wrist Lantern: a square storm lantern clipped to the front of the +X forearm (rides the arm into the throw)
  { const lk = P + ".C"; const h = ray(V(0.42, -1.2, -4), V(0, 0, 1), onSeg("ArmL")); const F = bracket(lk, "ArmL", h, 0.16, 0.34, 0.04, V(0, -1, -0.4));
    const out = [piece(lk, "ArmL", G.box(0.3, 0.3, 0.32), gm(P, "volt"), L(F, 0, 0.16, 0))];
    for (const s of [1, -1]) out.push(piece(lk, "ArmL", G.box(0.36, 0.35, 0.05), MAT.gun, L(F, 0, 0.17, 0.185 * s)));
    for (const s of [1, -1]) out.push(piece(lk, "ArmL", G.box(0.04, 0.33, 0.33), MAT.dark, L(F, 0.15 * s, 0.17, 0)));
    out.push(piece(lk, "ArmL", G.tor(0.08, 0.02), MAT.brass, L(F, 0, 0.4, 0, 0, 90, 0)));
    MK[lk] = {carry: makeCarry(out, "ArmL", V(0, 0.16, 0).applyMatrix4(F))}; }
})();

// ===== D1 · Sap Wall (button) =====
(() => {
  const P = "sapwall";
  // A · Saddle Tanks: two big amber sap tanks either side of the crest on the lower back, a manifold over it with the next pod
  { const lk = P + ".A", z = 0.3; let yc = 0;
    for (const s of [1, -1]) { const h = topHit(0.2 * s, z, onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.17, 0.5, 0.05);
      piece(lk, "Torso", G.cylZ(0.15, 0.15, 0.52), gm(P, "glassA"), L(F, 0, 0.15, 0));
      for (const e of [1, -1]) piece(lk, "Torso", G.cylZ(0.17, 0.17, 0.07), MAT.gun, L(F, 0, 0.15, 0.29 * e));
      piece(lk, "Torso", G.cylZ(0.155, 0.155, 0.05), MAT.brass, L(F, 0, 0.15, 0));
      yc = Math.max(yc, V(0, 0.15, 0).applyMatrix4(F).y); }
    piece(lk, "Torso", G.box(0.3, 0.09, 0.18), MAT.gun, T3(0, yc + 0.03, z));
    piece(lk, "Torso", G.cylY(0.1, 0.12, 0.1), MAT.dark, T3(0, yc + 0.125, z));
    MK[lk] = {carry: makeCarry([piece(lk, "Torso", G.sph(0.12), gm(P, "amber"), T3(0, yc + 0.26, z))], "Torso", V(0, yc + 0.26, z))}; }
  // B · Shoulder Pod: one big amber sap pod in a ring cradle on the +X side of the chest, behind the shoulder (the arm takes it)
  { const lk = P + ".B"; const h = side(1, 0.56, -0.95, b => b.seg === "Torso" && notThin(b)); const F = bracket(lk, "Torso", h, 0.3, 0.2, 0.05, V(0, 1, 0));
    piece(lk, "Torso", G.box(0.07, 0.22, 0.07), MAT.gun, L(F, 0, 0.12, -0.04)); piece(lk, "Torso", G.box(0.07, 0.12, 0.3), MAT.gun, L(F, 0, 0.12, 0.13, 0, 0, 0));
    piece(lk, "Torso", G.tor(0.22, 0.04), MAT.brass, L(F, 0, 0.22, 0.16, 90, 0, 0));
    MK[lk] = {carry: makeCarry([piece(lk, "Torso", G.sph(0.26), gm(P, "glassA"), L(F, 0, 0.38, 0.16))], "Torso", V(0, 0.38, 0.16).applyMatrix4(F))}; }
  // C · Belly Pod: a big sap pod slung under the chest in two half-ring straps (it drops straight into the hands)
  { const lk = P + ".C"; const h = ray(V(0, -3, -1.66), V(0, 1, 0), onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.26, 0.36, 0.04, V(0, 0, 1));
    for (const s of [1, -1]) { piece(lk, "Torso", G.tor(0.17, 0.028, Math.PI), MAT.gun, L(F, 0, 0.1, 0.11 * s)); for (const e of [1, -1]) { const q = V(0.17 * e, 0.1, 0.11 * s).applyMatrix4(F), hy = ray(V(q.x, -3, q.z), V(0, 1, 0), onSeg("Torso")).p.y; piece(lk, "Torso", G.box(0.06, hy - q.y, 0.06), MAT.gun, T3(q.x, (hy + q.y) / 2, q.z)); } }
    MK[lk] = {carry: makeCarry([piece(lk, "Torso", G.sph(0.21, 0.7, 0.85, 1.15), gm(P, "glassA"), L(F, 0, 0.28, 0))], "Torso", V(0, 0.28, 0).applyMatrix4(F))}; }
})();

// ===== D18 · Feather Shed (button) =====
(() => {
  const P = "shed";
  // A · Flank Plates: two big steel feather plates on each flank, hung from rail arms over the back edge; amber release bolts
  { const lk = P + ".A", shed = [];
    for (const s of [1, -1]) {
      for (const z of [-0.58, -0.12]) { const h = topHit(0.31 * s, z, onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.13, 0.13, 0.05);
        const y = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Torso", G.box(0.44, 0.06, 0.09), MAT.gun, T3(0.51 * s, y + 0.02, z));
        shed.push(piece(lk, "Torso", G.cylX(0.055, 0.055, 0.08), gm(P, "amber"), T3(0.75 * s, y + 0.02, z))); }
      shed.push(piece(lk, "Torso", G.box(0.045, 0.44, 0.56), MAT.plate, AT(0.73 * s, 0.44, -0.33, 0, 0, 8 * s)));
      shed.push(piece(lk, "Torso", G.box(0.045, 0.4, 0.5), MAT.steel, AT(0.735 * s, 0.42, 0.2, 0, 0, 8 * s)));
      shed.push(piece(lk, "Torso", G.box(0.06, 0.06, 1.12), MAT.brass, T3(0.73 * s, 0.665, -0.06))); }
    MK[lk] = {shed}; }
  // B · Quill Rack: a saddle on the lower back with four big steel quills fanned up and back; they blast off
  { const lk = P + ".B", z = 0.3, shed = [];
    for (const s of [1, -1]) { const h = topHit(0.18 * s, z, onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.14, 0.32, 0.05);
      const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Torso", G.box(0.08, 0.72 - y0, 0.2), MAT.gun, T3(0.18 * s, (y0 + 0.72) / 2, z)); }
    piece(lk, "Torso", G.box(0.5, 0.08, 0.26), MAT.gun, T3(0, 0.76, z));
    [-42, -14, 14, 42].forEach((a, i) => { const q = G.box(0.07, 0.8, 0.16); gx(q, T3(0, 0.4, 0));
      shed.push(piece(lk, "Torso", q, i % 2 ? MAT.plate : MAT.steel, AT(-0.15 + i * 0.1, 0.8, z + 0.02, 34, 0, -a))); });
    shed.push(piece(lk, "Torso", G.box(0.36, 0.05, 0.1), gm(P, "amber"), T3(0, 0.825, z - 0.08)));
    MK[lk] = {shed}; }
  // C · Tail Jacket: a long feather plate clamped on each side of the tail base (Tail1), release bolts on top
  { const lk = P + ".C", shed = [];
    for (const s of [1, -1]) {
      for (const z of [1.02, 1.82]) { const h = side(s, 0.36, z, onSeg("Tail1")); bracket(lk, "Tail1", h, 0.18, 0.16, 0.04, V(0, 0, 1)); }
      const x = side(s, 0.36, 1.02, onSeg("Tail1")).p.x + 0.04 * s;
      shed.push(piece(lk, "Tail1", G.box(0.045, 0.46, 1.1), MAT.plate, T3(x + 0.025 * s, 0.32, 1.42)));
      shed.push(piece(lk, "Tail1", G.box(0.06, 0.06, 1.1), MAT.brass, T3(x + 0.03 * s, 0.57, 1.42)));
      for (const z of [1.02, 1.82]) shed.push(piece(lk, "Tail1", G.cylX(0.05, 0.05, 0.06), gm(P, "amber"), T3(x + 0.075 * s, 0.4, z))); }
    MK[lk] = {shed}; }
})();

// ===== S6 · Portal Feathers (button) =====
(() => {
  const P = "portal";
  const ringAt = (lk, seg, c, ax, R, t, vane) => { // a ring of radius R round axis ax at c, with 4 brass feather vanes on its rim
    const M = new THREE.Matrix4().compose(c, new THREE.Quaternion().setFromUnitVectors(V(0, 0, 1), ax), V(1, 1, 1));
    const parts = [piece(lk, seg, G.tor(R, t), gm(P, "teal"), M)];
    for (let i = 0; i < 4; i++) { const a = Math.PI / 4 + i * Math.PI / 2; parts.push(piece(lk, seg, G.box(0.05, vane, 0.1), MAT.brass, M.clone().multiply(AT(Math.cos(a) * (R + t + vane / 2 - 0.02), Math.sin(a) * (R + t + vane / 2 - 0.02), 0, 0, 0, deg(a) - 90)))); }
    return parts; };
  // A · Tail Rings: two portal rings worn round the tail (Tail2, before and after its crest), clamped top and bottom
  { const lk = P + ".A", cs = [];
    for (const [z, R] of [[2.24, 0.4], [3.12, 0.36]]) { const ht = topHit(0, z, onSeg("Tail2")), hb = ray(V(0, -3, z), V(0, 1, 0), onSeg("Tail2")); const cy = (ht.p.y + hb.p.y) / 2, t = 0.065;
      const parts = ringAt(lk, "Tail2", V(0, cy, z), V(0, 0, 1), R, t, 0.24);
      for (const [hh, sg] of [[ht, 1], [hb, -1]]) { const gap = (cy + sg * (R - t)) - hh.p.y; piece(lk, "Tail2", G.box(0.12, Math.abs(gap) + 0.05, 0.1), MAT.dark, T3(0, hh.p.y + gap / 2, z), {bracket: true, name: "clamp"}); }
      cs.push(makeCarry(parts, "Tail2", V(0, cy, z))); }
    MK[lk] = {carries: cs}; }
  // B · Shin Hoops: a portal hoop round each shin like an anklet, on a clamp at the back of the shin
  { const lk = P + ".B", cs = [];
    for (const s of [1, -1]) { const seg = s > 0 ? "ShinL" : "ShinR"; const sh = BODY.find(b => b.n === seg + "_shin");
      const c = V(0, 0.12, 0).applyMatrix4(sh.m); const ax = V(0, 1, 0).transformDirection(sh.m); const R = 0.26, t = 0.055;
      const ring = ringAt(lk, seg, c, ax, R, t, 0.16);
      const hb = ray(c.clone().add(V(0, 0, 2)), V(0, 0, -1), b => b.n === seg + "_shin"); const gap = R - t - (hb.p.z - c.z);
      piece(lk, seg, G.box(0.1, 0.12, gap + 0.05), MAT.dark, T3(hb.p.x, hb.p.y, hb.p.z + gap / 2), {bracket: true, name: "clamp"});
      cs.push(makeCarry(ring, seg, c)); }
    MK[lk] = {carries: cs}; }
  // C · Disc Launcher: two portal rings stacked flat on a spindle over the lower back, on a saddle over the crest; they spin off
  { const lk = P + ".C", z = 0.27, cs = [];
    for (const sd of [1, -1]) { const h = topHit(0.18 * sd, z, onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.14, 0.3, 0.05);
      const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Torso", G.box(0.08, 0.74 - y0, 0.18), MAT.gun, T3(0.18 * sd, (y0 + 0.74) / 2, z)); }
    piece(lk, "Torso", G.box(0.48, 0.07, 0.24), MAT.gun, T3(0, 0.775, z));
    piece(lk, "Torso", G.cylY(0.045, 0.045, 0.26), MAT.steel, T3(0, 0.92, z));
    for (const [y, R] of [[0.86, 0.28], [0.95, 0.24]]) cs.push(makeCarry(ringAt(lk, "Torso", V(0, y, z), V(0, 1, 0), R, 0.05, 0.1), "Torso", V(0, y, z)));
    MK[lk] = {carries: cs}; }
})();

// ===== H7 · Last Feather (always on) =====
(() => {
  const P = "lastfeather";
  // A · Tail-Base Cell: a reserve cell lying along the top of the tail base on a saddle over the crest; a big amber window
  { const lk = P + ".A", z = 1.1, y = 0.72;
    for (const s of [1, -1]) { const h = topHit(0.14 * s, z, onSeg("Tail1")); const F = bracket(lk, "Tail1", h, 0.12, 0.34, 0.05, V(0, 0, 1));
      const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Tail1", G.box(0.07, y - y0, 0.24), MAT.gun, T3(0.14 * s, (y0 + y) / 2, z)); }
    piece(lk, "Tail1", G.box(0.36, 0.05, 0.3), MAT.gun, T3(0, y + 0.025, z));
    piece(lk, "Tail1", G.cylZ(0.16, 0.16, 0.44), MAT.gun, T3(0, y + 0.21, z));
    piece(lk, "Tail1", G.cylZ(0.168, 0.168, 0.2), gm(P, "amber"), T3(0, y + 0.21, z));
    for (const e of [1, -1]) piece(lk, "Tail1", G.cylZ(0.175, 0.175, 0.05), MAT.brass, T3(0, y + 0.21, z + 0.19 * e));
    piece(lk, "Tail1", G.box(0.035, 0.2, 0.34), MAT.brass, AT(0, y + 0.43, z + 0.02, -12, 0, 0));
    MK[lk] = {c: V(0, y + 0.21, z)}; }
  // B · Heart Core: a round reserve core in a ring frame on the chest (faces the attacker)
  { const lk = P + ".B"; const h = ray(V(0, 0.06, -4), V(0, 0, 1), onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.34, 0.34, 0.04, V(0, 1, 0));
    piece(lk, "Torso", G.cylY(0.22, 0.22, 0.08), MAT.gun, L(F, 0, 0.04, 0));
    piece(lk, "Torso", G.tor(0.21, 0.04), MAT.brass, L(F, 0, 0.09, 0, 90, 0, 0));
    piece(lk, "Torso", G.sph(0.16, 1, 0.7, 1), gm(P, "amber"), L(F, 0, 0.1, 0));
    MK[lk] = {c: V(0, 0.1, 0).applyMatrix4(F)}; }
  // C · Wing Pack: a pack on the lower back over the crest; two folded emergency wing fans swing up when it fires
  { const lk = P + ".C", z = 0.3;
    for (const s of [1, -1]) { const h = topHit(0.19 * s, z, onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.15, 0.36, 0.05);
      const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Torso", G.box(0.15, 0.73 - y0, 0.32), MAT.gun, T3(0.19 * s, (y0 + 0.73) / 2, z)); }
    piece(lk, "Torso", G.box(0.56, 0.09, 0.36), MAT.gun, T3(0, 0.775, z));
    piece(lk, "Torso", G.box(0.3, 0.04, 0.24), gm(P, "amber"), T3(0, 0.84, z));
    for (const s of [1, -1]) { const w = G.box(0.7, 0.035, 0.34); gx(w, T3(0.35 * s, 0, 0)); piece(lk, "Torso", w, MAT.plate, T3(0.16 * s, 0.84, z + 0.02), {anim: () => rotZ(rad(s * 70 * MS.unfold))}); }
    MK[lk] = {c: V(0, 0.82, z)}; }
})();

// ===== H12 · Overheal Plume (always on) =====
(() => {
  const P = "plume";
  const fan = (lk, seg, F, n, len, spread, w) => { for (let i = 0; i < n; i++) { const a = -spread / 2 + spread * i / (n - 1); const b = G.box(0.06, len, w || 0.14); gx(b, T3(0, len / 2, 0)); piece(lk, seg, b, gm(P, "gold"), F.clone().multiply(R3(0, 0, a))); } };
  // A · Tail Plume: a fan of five gold armour feathers standing up from a clamp on the tail (Tail4); they light up as it fills
  { const lk = P + ".A", z = 4.82; const h = topHit(0, z, onSeg("Tail4")); const F = bracket(lk, "Tail4", h, 0.16, 0.28, 0.05);
    piece(lk, "Tail4", G.cylZ(0.09, 0.09, 0.26), MAT.gun, L(F, 0, 0.1, 0));
    fan(lk, "Tail4", L(F, 0, 0.15, 0.02, 30, 0, 0), 5, 0.9, 100);
    MK[lk] = {c: V(0, 0.5, 0).applyMatrix4(F)}; }
  // B · Helm Plume: a crest on the back of the skull, three gold blades swept back
  { const lk = P + ".B"; const h = topHit(0, -2.92, b => b.n === "Head_cranium"); const F = bracket(lk, "Head", h, 0.26, 0.3, 0.05);
    piece(lk, "Head", G.box(0.12, 0.1, 0.26), MAT.gun, L(F, 0, 0.06, 0));
    fan(lk, "Head", L(F, 0, 0.1, 0.05, 56, 0, 0), 3, 0.66, 44);
    MK[lk] = {c: V(0, 0.3, 0.12).applyMatrix4(F)}; }
  // C · Hip Plumes: a gold fan on each hip, on a saddle over the lower-back crest, splayed out to the sides
  { const lk = P + ".C", z = 0.3;
    for (const s of [1, -1]) { const h = topHit(0.18 * s, z, onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.14, 0.28, 0.05);
      const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Torso", G.box(0.07, 0.74 - y0, 0.16), MAT.gun, T3(0.18 * s, (y0 + 0.74) / 2, z)); }
    piece(lk, "Torso", G.box(0.46, 0.07, 0.2), MAT.gun, T3(0, 0.775, z));
    for (const s of [1, -1]) fan(lk, "Torso", AT(0.2 * s, 0.81, z, 10, 0, -45 * s), 3, 0.62, 50);
    MK[lk] = {c: V(0, 1.05, z)}; }
})();

// ===== D5 · Fortify Field (always on) =====
(() => {
  const P = "fortify";
  const hexPlate = (lk, seg, F, k) => { k = k || 1; piece(lk, seg, G.cylY(0.17 * k, 0.17 * k, 0.06, 6), MAT.gun, L(F, 0, 0.03, 0)); piece(lk, seg, G.cylY(0.12 * k, 0.12 * k, 0.05, 6), gm(P, "teal"), L(F, 0, 0.075, 0)); };
  // A · Wrist Bracers: a bracer with a teal hex emitter on the front of each forearm (the pod leaves the hands past them)
  { const lk = P + ".A";
    for (const s of [1, -1]) { const seg = s > 0 ? "ArmL" : "ArmR"; const h = ray(V(0.42 * s, -1.42, -4), V(0, 0, 1), onSeg(seg)); const F = bracket(lk, seg, h, 0.16, 0.42, 0.04, V(0, -1, -0.4));
      piece(lk, seg, G.box(0.22, 0.06, 0.4), MAT.plate, L(F, 0, 0.035, 0)); hexPlate(lk, seg, L(F, 0, 0.065, 0), 0.9); }
    MK[lk] = {}; }
  // B · Neck Pylon: a mast on a bridge over the back crest behind the neck, a teal hex emitter dish on top, tilted back
  { const lk = P + ".B", z = -1.02;
    for (const s of [1, -1]) { const h = topHit(0.2 * s, z, b => b.seg === "Torso" && notThin(b)); const F = bracket(lk, "Torso", h, 0.14, 0.24, 0.05);
      const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Torso", G.box(0.08, 0.98 - y0, 0.14), MAT.gun, T3(0.2 * s, (y0 + 0.98) / 2, z)); }
    piece(lk, "Torso", G.box(0.5, 0.07, 0.2), MAT.gun, T3(0, 1.0, z));
    piece(lk, "Torso", G.cylY(0.05, 0.065, 0.5), MAT.steel, AT(0, 1.27, z + 0.05, 12, 0, 0));
    piece(lk, "Torso", G.cylY(0.3, 0.11, 0.08, 6), MAT.gun, AT(0, 1.54, z + 0.1, 24, 0, 0));
    piece(lk, "Torso", G.cylY(0.22, 0.22, 0.04, 6), gm(P, "teal"), AT(0, 1.585, z + 0.12, 24, 0, 0));
    MK[lk] = {c: V(0, 1.55, z + 0.1)}; }
  // C · Tail Emitters: a teal hex emitter on each side of the tail base (Tail1)
  { const lk = P + ".C";
    for (const s of [1, -1]) { const h = side(s, 0.3, 1.78, onSeg("Tail1")); const F = bracket(lk, "Tail1", h, 0.28, 0.3, 0.04, V(0, 1, 0)); hexPlate(lk, "Tail1", F, 1.0); }
    MK[lk] = {}; }
})();

// ===== A10 · Ricochet Pod (always on) =====
(() => {
  const P = "ricochet";
  // A · Spring Cups: a sprung brass cup on the front of each hand; the pod sits in them and they kick as it leaves
  { const lk = P + ".A";
    for (const s of [1, -1]) { const seg = s > 0 ? "ArmL" : "ArmR"; const h = ray(V(0.42 * s, -1.8, -4), V(0, 0, 1), onSeg(seg)); const F = bracket(lk, seg, h, 0.18, 0.3, 0.04, V(0, -1, 0));
      piece(lk, seg, G.cylY(0.085, 0.085, 0.1), MAT.steel, L(F, 0, 0.06, 0), {anim: () => scl(1, 1 - 0.5 * MS.spring, 1).premultiply(T3(0, -0.025 * MS.spring, 0))});
      for (let i = 0; i < 2; i++) piece(lk, seg, G.tor(0.11, 0.018), MAT.dark, L(F, 0, 0.045 + i * 0.05, 0, 90, 0, 0), {anim: () => T3(0, 0, 0.02 * MS.spring * i)});
      piece(lk, seg, G.cylY(0.19, 0.12, 0.11), MAT.brass, L(F, 0, 0.165, 0), {anim: () => T3(0, -0.05 * MS.spring, 0)});
      piece(lk, seg, G.cylY(0.15, 0.15, 0.025), gm(P, "amber"), L(F, 0, 0.228, 0), {anim: () => T3(0, -0.05 * MS.spring, 0)}); }
    MK[lk] = {}; }
  // B · Forearm Springs: a long coil-spring housing along the front of each forearm, its striker plate glowing at the wrist
  { const lk = P + ".B";
    for (const s of [1, -1]) { const seg = s > 0 ? "ArmL" : "ArmR"; const h = ray(V(0.42 * s, -1.3, -4), V(0, 0, 1), onSeg(seg)); const F = bracket(lk, seg, h, 0.14, 0.46, 0.04, V(0, -1, -0.4));
      piece(lk, seg, G.cylZ(0.085, 0.085, 0.44), MAT.gun, L(F, 0, 0.11, 0));
      for (let i = 0; i < 4; i++) piece(lk, seg, G.tor(0.105, 0.02), MAT.brass, L(F, 0, 0.11, -0.15 + i * 0.1), {anim: () => T3(0, 0, -0.03 * MS.spring * i)});
      piece(lk, seg, G.cylZ(0.11, 0.11, 0.04), gm(P, "amber"), L(F, 0, 0.11, 0.24), {anim: () => T3(0, 0, -0.06 * MS.spring)}); }
    MK[lk] = {}; }
  // C · Chest Pad: a sprung bounce pad on the chest; the pod rolls off it as the arms swing past
  { const lk = P + ".C"; const h = ray(V(0, 0.06, -4), V(0, 0, 1), onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.36, 0.3, 0.04, V(0, 1, 0));
    for (const s of [1, -1]) for (const t of [1, -1]) piece(lk, "Torso", G.cylY(0.035, 0.035, 0.1), MAT.steel, L(F, 0.12 * s, 0.05, 0.09 * t), {anim: () => scl(1, 1 - 0.4 * MS.spring, 1)});
    piece(lk, "Torso", G.box(0.4, 0.05, 0.3), MAT.brass, L(F, 0, 0.125, 0), {anim: () => T3(0, -0.04 * MS.spring, 0)});
    piece(lk, "Torso", G.box(0.3, 0.025, 0.22), gm(P, "amber"), L(F, 0, 0.16, 0), {anim: () => T3(0, -0.04 * MS.spring, 0)});
    MK[lk] = {}; }
})();

// ---------- extra key poses (rig 1.3 angles {p, y, r}: + = rear back / nose up for RootJoint / Neck / Head; Arm / Leg + = swing
// forward; Knee - = bend; Tail + = droop, - = lift; Jaw - = open) ----------
const MEND_SET = BOTH({RootJoint: [4, 0, 0], Neck: [10, 0, 0], Head: [-8, 0, 0], ArmL: [-12, 0, 0], Tail1: [3, 0, 0]});
const MEND_GO = BOTH({RootJoint: [-3, 0, 0], Neck: [22, 0, 0], Head: [-20, 0, 0], Jaw: [-8, 0, 0], ArmL: [6, 0, 0], Tail1: [-4, 0, 0]});
const LANT_GRAB = {RootJoint: [6, 0, -4], Neck: [10, 0, 0], Head: [-8, 0, 0], ArmL: [-62, 0, -14], ArmR: [-12, 0, 0], LegL: [4, 0, 0], KneeL: [-10, 0, 0], Tail1: [4, 0, 0], root: {fwd: -0.6}};
const LANT_COCK = {RootJoint: [8, 0, 4], Neck: [16, 0, 0], Head: [-12, 0, 0], ArmL: [-82, 0, -26], ArmR: [-14, 0, 0], Tail1: [6, 0, 0], root: {fwd: -0.9}};
const LANT_THROW = {RootJoint: [-8, 0, -2], Neck: [-12, 0, 0], Head: [8, 0, 0], ArmL: [105, 0, 10], ArmR: [18, 0, 0], LegL: [-6, 0, 0], LegR: [12, 0, 0], KneeR: [-16, 0, 0], Tail1: [-8, 0, 0], root: {fwd: 1.4}};
const LANT_FOLLOW = {RootJoint: [-6, 0, 0], Neck: [-8, 0, 0], Head: [6, 0, 0], ArmL: [70, 0, 6], ArmR: [10, 0, 0], Tail1: [-6, 0, 0], root: {fwd: 1.6}};
const TAIL_COIL = BOTH({RootJoint: [-6, 0, 0], Neck: [-6, 0, 0], Head: [4, 0, 0], ArmL: [-8, 0, 0], KneeL: [-12, 0, 0], Tail1: [16, 0, 0], Tail2: [14, 0, 0], Tail3: [12, 0, 0], Tail4: [8, 0, 0]});
const TAIL_FLICK = BOTH({RootJoint: [-10, 0, 0], Neck: [-12, 0, 0], Head: [8, 0, 0], ArmL: [8, 0, 0], Tail1: [-16, 0, 0], Tail2: [-34, 0, 0], Tail3: [-28, 0, 0], Tail4: [-18, 0, 0], root: {fwd: 0.8}});
const PINNED = BOTH({RootJoint: [-12, 0, 0], Neck: [-24, 0, 0], Head: [12, 0, 0], Jaw: [-16, 0, 0], ArmL: [-34, 0, -16], LegL: [22, 0, 0], KneeL: [-44, 0, 0], AnkleL: [18, 0, 0], Tail1: [10, 0, 0], Tail2: [6, 0, 0]});
const SHED_TENSE = addPose(PINNED, {RootJoint: [4, 0, 0], Neck: [8, 0, 0], ArmL: [-10, 0, -10], ArmR: [-10, 0, 10]}, 1);
const SHED_BURST = BOTH({RootJoint: [12, 0, 0], Neck: [26, 0, 0], Head: [-14, 0, 0], Jaw: [-30, 0, 0], ArmL: [-26, -20, -100], LegL: [-6, 0, 0], KneeL: [-10, 0, 0], Tail1: [-14, 0, 0], Tail2: [-8, 0, 0], root: {fwd: -1}});
const PORT_SET = BOTH({RootJoint: [6, 0, 0], Neck: [14, 0, 0], Head: [-12, 0, 0], ArmL: [-24, 0, 0], LegL: [8, 0, 0], KneeL: [-16, 0, 0], AnkleL: [6, 0, 0], Tail1: [14, 0, 0], Tail2: [10, 0, 0], Tail3: [8, 0, 0], root: {fwd: -0.6}});
const PORT_FLING = Object.assign(BOTH({RootJoint: [-8, 0, 0], Neck: [-12, 0, 0], Head: [8, 0, 0], ArmL: [60, 0, 0], Tail1: [-16, 0, 0], Tail2: [-30, 0, 0], Tail3: [-22, 0, 0], root: {fwd: 1.2}}), {LegL: [-14, 0, 0], KneeL: [-6, 0, 0], LegR: [10, 0, 0]});
// the throw wind-up with the long arms swung 12 deg wider (so hand / forearm parts pass outside the knees; a TrooPose tweak)
const TA_WIND_W = addPose(TA_WIND, BOTH({ArmL: [0, 0, -12]}), 1), TA_HOLD_W = addPose(TA_HOLD, BOTH({ArmL: [0, 0, -12]}), 1);
const THROW = T0 => [K(T0 + 0.2, TA_WIND_W, "io"), K(T0 + 0.27, TA_HOLD_W, "io"), K(T0 + 0.34, TA_THROW, "in2"), K(T0 + 0.52, TA_FOLLOW, "out"), K(T0 + 1.15, T_READY, "io")];
function idleIntro(keys, t0) { return [K(0, T_READY), K(t0, T_READY), ...keys]; }
const SHIELD_BLUE = 0x5ab4ff, HEAL_GREEN = 0x46e08a, VOLT = 0x7fe9ff, GOLD = 0xffd56a;
function shimmer(target, r, color, life, op) { // a soft see-through shell (the Energy Shield's dome look) that follows target()
  const m = new THREE.Mesh(new THREE.IcosahedronGeometry(r, 1), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0, depthWrite: false, wireframe: true}));
  const s = new THREE.Mesh(new THREE.SphereGeometry(r * 0.98, 20, 14), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0, depthWrite: false})); m.add(s);
  return addFx(m, life, (o, u) => { o.position.copy(target()); o.rotation.y = clockT * 0.6; const k = Math.min(1, u * life / 0.12) * Math.min(1, (1 - u) * life / 0.25); o.material.opacity = (op || 0.45) * k; s.material.opacity = (op || 0.45) * 0.35 * k; });
}
function setHp(R, v) { R.hp = Math.max(0, Math.min(R.max || 60, v)); }
function healTick(R, n, from) { // Med-Station heal look: green ground wave, green + crosses, "+n"
  const c = rapChest(R); groundRing(R.rig.pos, 7, HEAL_GREEN, 0.7, 0.5); healCrosses(c, 4); popNum(c.clone().add(V(0, 5, 0)), "+" + n, "heal"); R.heal = 0.4; setHp(R, R.hp + n);
  if (from) { const a = from.clone(); const beam = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.6, 1, 10, 1, true), new THREE.MeshBasicMaterial({color: HEAL_GREEN, transparent: true, opacity: 0.6, depthWrite: false, side: THREE.DoubleSide}));
    addFx(beam, 0.3, (o, u) => { const b = rapChest(R); o.position.copy(a).lerp(b, 0.5); o.scale.set(1, a.distanceTo(b), 1); o.quaternion.setFromUnitVectors(V(0, 1, 0), b.clone().sub(a).normalize()); o.material.opacity = 0.6 * (1 - u); }); }
}

// ---------- tracks (each returns: keys, ev, update, post (after the pose: carried pieces), move (troodon root), frame, phases) ----------
const isLook = (id, L) => id + "." + L;
function zoneScene() { place(S, -8, -34, 0); place(R0, -1, -40, 0); place(R1, 7, -46, 0); R0.yaw = yawTo(R0.pos, S.pos); R1.yaw = yawTo(R1.pos, S.pos) + 0.3; S.yaw = yawTo(S.pos, R0.pos); }
function menderTrack(L) {
  const c = MK[isLook("mender", L)].carry;
  place(S, -12, -30); place(S2, 13, -40); place(R0, -5, -45); S.yaw = yawTo(S.pos, R0.pos); S2.yaw = yawTo(S2.pos, R0.pos); R0.yaw = yawTo(R0.pos, S.pos);
  S.max = S2.max = 60; setHp(S, 48); setHp(S2, 52); S.hpShow = S2.hpShow = true;
  const T0 = 0.6, GO = T0 + 0.45, ARR = GO + 0.75, TK = 0.75, HOP = ARR + 0.1 + 2 * TK + 0.12, ARR2 = HOP + 0.5, END = ARR2 + 0.1 + TK + 0.3, BACK = END + 0.75;
  const keys = idleIntro([K(T0 + 0.3, MEND_SET, "io"), K(GO + 0.05, MEND_GO, "out"), K(GO + 0.6, T_READY, "io"), K(END + 0.2, T_READY), K(END + 0.45, MEND_SET, "io"), K(BACK + 0.3, T_READY, "io")], T0);
  const orbitP = (R, t, ph) => rapChest(R).add(V(Math.cos(t * 2.6 + ph) * 4.5, 5.5 + Math.sin(t * 5) * 0.4, Math.sin(t * 2.6 + ph) * 4.5));
  let from = null, last = null;
  const bez = (a, b, h, u) => { const m = a.clone().lerp(b, 0.5).add(V(0, h, 0)); return a.clone().multiplyScalar((1 - u) * (1 - u)).add(m.multiplyScalar(2 * u * (1 - u))).add(b.clone().multiplyScalar(u * u)); };
  const ev = [{t: GO, f: () => { textTag(rapChest(S).add(V(0, 13, 0)), "MOST HURT", "#8dffb6", 1.6); flash(carryPos(c), 4, HEAL_GREEN); }},
    {t: HOP - 0.05, f: () => textTag(rapChest(S).add(V(0, 13, 0)), "FULL", "#8dffb6", 1.0)},
    {t: HOP + 0.1, f: () => textTag(rapChest(S2).add(V(0, 13, 0)), "NEXT MOST HURT", "#8dffb6", 1.4)}];
  for (let i = 0; i < 3; i++) ev.push({t: ARR + 0.1 + i * TK, f: () => healTick(S, 4, last)});
  for (let i = 0; i < 2; i++) ev.push({t: ARR2 + 0.1 + i * TK, f: () => healTick(S2, 4, last)});
  return {frame: [V(0, 0, 4), V(0, 0, -44)], keys, ev, eyes: [[GO - 0.1, GO + 0.3]],
    update(t, dt) {
      MS.open = t < T0 ? 0 : t < GO ? win(t, T0, GO) : t < BACK - 0.1 ? 1 : 1 - win(t, BACK - 0.1, BACK + 0.2);
      const sp = t < T0 ? 0 : t < GO ? 40 * win(t, T0, GO) : t < BACK ? 40 : 40 * (1 - win(t, BACK, BACK + 0.6)); MS.spin += sp * dt;
      PGLOW.mender = t > T0 && t < BACK + 0.3 ? 1 : 0; MS.flap = t > GO && t < BACK ? 0.5 + 0.5 * Math.sin(t * 30) : 0;
      if (t > GO && t < BACK && Math.random() < dt * 18) { const s = sprite(T_FLASH, HEAL_GREEN, 0.8, true); s.position.copy(carryPos(c)).add(V((Math.random() - .5), -0.5, (Math.random() - .5))); addFx(s, 0.4, (o, u, d) => { o.position.y -= d * 3; o.material.opacity = 1 - u; }); }
      if (t > GO && R0.show && t > 2.6 && !R0._bit) { R0._bit = 1; R0.lunge = 1; later(0.25, () => { popNum(rapChest(S).add(V(0, 5, 0)), 4, "hit"); S.flinch = 0.6; setHp(S, S.hp - 4); }); }
    },
    post(t) {
      if (t < GO) { carryOff(c); return; }
      const dock = dockWorld(c), dp = V(0, 0, 0).applyMatrix4(dock);
      let p, yaw = 0;
      if (t < ARR) { if (!from) from = dp.clone(); p = bez(from, orbitP(S, t, 0), 8, E.io(win(t, GO, ARR))); }
      else if (t < HOP) p = orbitP(S, t, 0);
      else if (t < ARR2) { const a = orbitP(S, HOP, 0); p = bez(a, orbitP(S2, t, 2), 3, E.io(win(t, HOP, ARR2))); }
      else if (t < END) p = orbitP(S2, t, 2);
      else if (t < BACK) { const a = orbitP(S2, END, 2); p = bez(a, dp, 7, E.io(win(t, END, BACK))); }
      else { carryOff(c); return; }
      if (last) { const v = p.clone().sub(last); if (v.lengthSq() > 1e-4) yaw = Math.atan2(-v.x, -v.z); }
      const M = worldM(p, yaw, 2, 0.15);
      carryAt(c, t < GO + 0.2 ? lerpM(dock, M, E.io(win(t, GO, GO + 0.2))) : t > BACK - 0.2 ? lerpM(M, dock, E.io(win(t, BACK - 0.2, BACK))) : M);
      last = p;
    },
    phases: [[0, T0, "Slotted: the drone sits docked on the troodon"], [T0, GO, "Wind-up: the dock opens, rotors spin up, the heal light comes on"], [GO, ARR, "Lifts off and flies to the most hurt squadmate in reach"], [ARR, HOP, "Orbits it: +4 per second (Med-Station green)"], [HOP, ARR2, "Target full: hops to the next most hurt (star)"], [ARR2, END, "Heals the second squadmate"], [END, BACK + 0.5, "Recovery: flies home and docks"]],
    len: BACK + 0.9};
}

function lanternTrack(L) {
  const c = MK[isLook("lantern", L)].carry;
  place(R0, -3, -38); place(R1, 6, -44); place(R2, -7, -53);
  const T0 = 0.6, REL = T0 + 0.42, FLY = 0.55, LAND = REL + FLY, Z1 = LAND + 0.32, GONE = Z1 + 0.9, BACKIN = GONE + 0.3;
  const Lp = V(-0.5, 0, -40);
  let keys;
  if (L === "B") keys = idleIntro([K(T0 + 0.36, TAIL_COIL, "io"), K(REL + 0.04, TAIL_FLICK, "in2"), K(REL + 0.4, TAIL_FLICK, "out"), K(REL + 1.0, T_READY, "io")], T0);
  else keys = idleIntro([K(T0 + 0.3, L === "A" ? LANT_GRAB : LANT_COCK, "io"), K(REL - 0.06, LANT_COCK, "io"), K(REL + 0.02, LANT_THROW, "in2"), K(REL + 0.22, LANT_FOLLOW, "out"), K(REL + 0.9, T_READY, "io")], T0);
  let p0 = null, landM = null;
  const chain = [R0, R1, R2];
  const ev = [{t: REL, f: () => { p0 = carryPos(c); flash(p0, 3, VOLT); }}];
  chain.forEach((R, i) => ev.push({t: Z1 + i * 0.12, f: () => {
    const a = i === 0 ? () => carryPos(c).add(V(0, 0.8, 0)) : () => rapChest(chain[i - 1]); zap(a, () => rapChest(R), 0.32);
    const cp = rapChest(R); flash(cp, 6, VOLT); sparks(cp, V(0, 0.5, 0), 8, 0xc8f8ff, 0.6); popNum(cp.clone().add(V(0, 5, 0)), 8, "hit"); R.flinch = 1; R.flash = 0.14; R.flashCol = [0.5, 0.9, 1]; hitStop = Math.max(hitStop, 0.03); shake = Math.max(shake, 0.35);
    textTag(cp.clone().add(V(0, 11, 0)), "ZAP " + (i + 1) + " / 3", "#bff6ff", 1.2); }}));
  ev.push({t: GONE - 0.1, f: () => { sparks(carryPos(c), V(0, 0.4, 0), 10, 0xc8f8ff, 0.5); }});
  return {frame: [V(0, 0, 4), V(0, 0, -54)], keys, ev, eyes: [[T0 + 0.1, REL + 0.3]],
    update(t) { PGLOW.lantern = t < T0 ? 0 : t < LAND ? 0.6 : t < Z1 ? 1.4 + Math.sin(t * 60) * 0.6 : t < GONE - 0.2 ? 1.5 : 0; c.k = t < BACKIN ? 1 : E.back(win(t, BACKIN, BACKIN + 0.35)); },
    post(t) {
      if (t < T0 || (L !== "A" && t < REL)) { carryOff(c); return; }
      const dock = dockWorld(c);
      if (t < REL) { // A: the hand takes it off the hip hook
        const hand = partPoint(HAND.L).add(V(0, -1.5, 0)); carryAt(c, lerpM(dock, worldM(hand, 0, 2), E.io(win(t, T0 + 0.05, REL - 0.08)))); return; }
      if (t < LAND) { const u = win(t, REL, LAND); const p = p0.clone().lerp(Lp.clone().setY(1.7), u); p.y += 4 * 6 * u * (1 - u); carryAt(c, worldM(p, t * 9, 2)); return; }
      if (t < GONE) { const k = 2 + 2.6 * E.back(win(t, LAND, LAND + 0.25)), sh = t > GONE - 0.4 ? 1 - win(t, GONE - 0.4, GONE) : 1; landM = worldM(Lp.clone().setY(0.62 * k / 2 * 1.0 + 0.1), 0.5, Math.max(0.01, k * sh)); carryAt(c, landM); return; }
      carryOff(c); },
    phases: [[0, T0, "Slotted: the lantern on its mount"], [T0, REL, L === "B" ? "Wind-up: the tail coils, the lure swings" : L === "A" ? "Wind-up: the hand takes the lantern off the hip hook" : "Wind-up: the arm cocks back"], [REL, LAND, "Throws the lantern in an arc"], [LAND, Z1, "It lands, opens up and charges"], [Z1, Z1 + 0.5, "Zaps the nearest enemy, then chains: 3 enemies, 8 each"], [Z1 + 0.5, GONE, "The lantern burns out"], [GONE, BACKIN + 0.6, "Recovery: a new lantern on the mount"]],
    len: BACKIN + 0.9};
}

function sapTrack(L) {
  const c = MK[isLook("sapwall", L)].carry;
  const Wc = V(0, 0, -24);
  place(R0, -3, -56); place(R1, 9, -46); R0.yaw = yawTo(R0.pos, V(0, 0, 0)); R1.yaw = yawTo(R1.pos, V(0, 0, 0));
  const T0 = 0.6, REL = T0 + 0.34, FLY = 0.5, SPLAT = REL + FLY, HARD = SPLAT + 0.45, END = SPLAT + 3.0, CRUMB = END + 0.6;
  R0.path = [[0, R0.pos.clone(), R0.yaw, 0], [SPLAT - 0.6, R0.pos.clone(), R0.yaw, 0], [SPLAT - 0.4, R0.pos.clone().add(V(0, 0, 2)), R0.yaw, 1], [SPLAT + 0.75, V(-2.2, 0, -27.6), R0.yaw, 1], [SPLAT + 0.95, V(-2.2, 0, -27.6), R0.yaw, 0]];
  const keys = idleIntro(THROW(T0), T0);
  let p0 = null, wall = null;
  const sapM = lam(0xffb43a, {emissive: 0x8a4a00, transparent: true, opacity: 0.6});
  const ev = [{t: REL, f: () => { p0 = carryPos(c); }},
    {t: SPLAT, f: () => { const p = Wc.clone().setY(1); flash(p, 12, 0xffe2a0); splash(p, 30, 1.2); hitStop = 0.05; shake = Math.max(shake, 0.6);
      wall = new THREE.Group(); wall.position.copy(Wc); scene.add(wall);
      [[-7.6, 3.9, 8.4, 0.2], [-3.8, 3.8, 9.6, -0.15], [0, 4.0, 10.2, 0.1], [3.9, 3.8, 9.2, -0.2], [7.6, 3.8, 8.0, 0.15]].forEach(([x, w, h, z]) => { const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, 1.8), sapM); m.position.set(x, h / 2, z); m.rotation.z = z * 0.15; m.castShadow = true; wall.add(m); });
      const rim = new THREE.Mesh(new THREE.BoxGeometry(19.4, 0.5, 2.1), lam(0xffe2a0, {emissive: 0xb86a10})); rim.position.y = 0.25; wall.add(rim);
      wall.scale.set(1, 0.01, 1); textTag(Wc.clone().add(V(0, 13, 0)), "SAP WALL · 19 studs · 4 s", "#ffd38a", 2.6); }},
    {t: SPLAT + 0.78, f: () => { R0.flinch = 1; R0.push = 2.5; R0.pushDir.set(0, 0, -1); flash(V(-2, 5, -24.8), 6, 0xffe2a0); textTag(V(-2, 15, -26), "BLOCKED", "#ffd38a", 1.2); shake = Math.max(shake, 0.4); }},
    {t: SPLAT + 1.05, f: () => { const from = rapChest(R1); flash(from, 4, VOLT); const bolt = new THREE.Mesh(new THREE.CylinderGeometry(0.25, 0.25, 3, 8).rotateX(Math.PI / 2), new THREE.MeshBasicMaterial({color: 0xbff6ff}));
      fly({obj: bolt, from, to: () => V(6, 5, -25), T: 0.3, H: 0.1, trail: VOLT, onHit: p => { flash(p, 7, VOLT); sparks(p, V(0, 0.3, -1), 12, 0xc8f8ff); textTag(p.clone().add(V(0, 8, 0)), "BLOCKED", "#bff6ff", 1.2); }}); R1.lunge = 0.6; }},
    {t: END, f: () => { if (wall) { for (const m of wall.children) { const q = m.clone(); q.material = sapM.clone(); const p = m.getWorldPosition(new THREE.Vector3()); q.position.copy(p); const v = V((Math.random() - .5) * 6, 4 + Math.random() * 6, (Math.random() - .5) * 6);
      addFx(q, 0.6, (o, u, dt) => { v.y -= 30 * dt; o.position.addScaledVector(v, dt); o.rotation.x += dt * 2; o.scale.setScalar(1 - u * 0.8); o.material.opacity = 0.8 * (1 - u); }); } scene.remove(wall); wall = null; } }}];
  return {frame: [V(0, 0, 4), V(0, 0, -50)], keys, ev, eyes: [[T0 + 0.05, REL + 0.4]],
    update(t, dt) {
      PGLOW.sapwall = t > T0 && t < SPLAT ? 1 : 0; c.k = t < END ? 1 : E.back(win(t, END, END + 0.4));
      if (wall) { const g = E.back(win(t, SPLAT, SPLAT + 0.3)); wall.scale.set(1, Math.max(0.01, g), 1); const hd = win(t, SPLAT + 0.2, HARD); sapM.opacity = 0.55 + 0.37 * hd; sapM.emissive.setRGB(0.6 * (1 - hd) + 0.25, 0.32 * (1 - hd) + 0.12, 0); sapM.color.setHex(hd > 0.5 ? 0xd9821c : 0xffb43a);
        if (t > END - 0.5) wall.position.x = Wc.x + Math.sin(t * 70) * 0.08; }
    },
    post(t) {
      if (t < T0) { carryOff(c); return; }
      const dock = dockWorld(c);
      if (t < REL) { carryAt(c, lerpM(dock, worldM(handsPoint(), 0, 2.4), E.io(win(t, T0 + 0.02, REL - 0.04)))); return; }
      if (t < SPLAT) { const u = win(t, REL, SPLAT); const p = p0.clone().lerp(Wc.clone().setY(1), u); p.y += 4 * 6 * u * (1 - u); carryAt(c, worldM(p, t * 8, 2.6)); return; }
      carryOff(c); if (t < END) c.k = 0.001; },
    phases: [[0, T0, "Slotted: the sap pod in its mount"], [T0, REL, "Wind-up: the pod comes into both hands"], [REL, SPLAT, "Two-hand fling (the Glow Pod Toss throw)"], [SPLAT, HARD, "Splats and rises into a sap wall, 19 studs wide"], [HARD, END, "Hardened: blocks the charging raptor and a shot (4 s, shown faster)"], [END, CRUMB + 0.4, "Cracks and crumbles; a new pod grows in the mount"]],
    len: CRUMB + 0.6};
}

function shedTrack(L) {
  const lk = isLook("shed", L), sp = MK[lk].shed;
  place(R0, 0.5, -12.5); R0.yaw = yawTo(R0.pos, V(0, 0, 0)); R0.bite = 1;
  heroBar.on = true; hero.hp = 41; hero.max = 55;
  const PRESS = 0.9, GO = PRESS + 0.15, FREE = GO + 0.45, REG = GO + 1.5;
  const keys = [K(0, PINNED), K(PRESS, PINNED), K(GO - 0.02, SHED_TENSE, "io"), K(GO + 0.06, SHED_BURST, "out5"), K(GO + 0.35, SHED_BURST), K(FREE + 0.15, TJ_LAND, "io"), K(FREE + 0.8, T_READY, "io")];
  let tags = [];
  const ev = [{t: 0.01, f: () => { tags = [textTag(heroHRP().add(V(0, 15, 0)), "PINNED", "#ff8a7a", 9), textTag(heroHRP().add(V(0, 12.4, 0)), "STUNNED", "#ffd38a", 9)]; }},
    {t: 0.3, f: () => { popNum(torsoPt().add(V(0, 5, 0)), 3, "hit"); hero.hp -= 3; }}, {t: 0.7, f: () => { popNum(torsoPt().add(V(0, 5, 0)), 3, "hit"); hero.hp -= 3; }},
    {t: GO, f: () => { const ctr = torsoPt(); burst(sp, ctr, 1.1); MS.regrow = 0; tags.forEach(killFx); hitStop = 0.08; shake = 1; fovPunch = 3;
      flash(ctr, 14, 0xfff4e0); feathers(ctr, 34, [0x8c7e6a, 0xd9cdb6, 0x6b5a48, 0xffffff], 1.4, 8); groundRing(V(hero.pos.x, 0, hero.pos.z), 10, 0xffffff, 0.45);
      R0.bite = 0; R0.flinch = 1; R0.push = 12; R0.pushDir.set(0, 0, -1); R0.slow = 2; textTag(rapChest(R0).add(V(0, 11, 0)), "KNOCKED BACK · SLOWED 2 s", "#ffd38a", 1.6);
      textTag(heroHRP().add(V(0, 15, 0)), "BROKE FREE", "#ffffff", 1.4); later(0.25, () => textTag(heroHRP().add(V(0, 12.5, 0)), "IMMUNE 1.4 s", "#cfe6ff", 1.6)); shimmer(() => heroHRP().add(V(0, 1.5, 0)), 9, 0xe6f2ff, 1.4, 0.3); }}];
  return {frame: [V(0, 0, 10), V(0, 0, -26)], keys, ev, tremble: [0, GO],
    update(t) { PGLOW.shed = t > PRESS && t < GO ? 2 : 0; if (t > REG) MS.regrow = Math.max(0.001, E.back(win(t, REG, REG + 0.5))); },
    move(t) { const u = win(t, GO, FREE); return {z: 8 * E.out(u), up: 3 * 4 * u * (1 - u)}; },
    phases: [[0, PRESS, "A raptor has it pinned and stunned"], [PRESS, GO, "Press: the release bolts flash (wind-up 0.15 s)"], [GO, FREE, "The harness blows: feathers and plates burst off, the raptor is knocked back"], [FREE, REG, "Free: hops clear, immune to stuns / pins / grabs 1.4 s (no landing FX)"], [REG, REG + 0.9, "Recovery: the plates grow back over the recharge"]],
    len: REG + 0.9};
}

function portalTrack(L) {
  const cs = MK[isLook("portal", L)].carries;
  const A = V(0, 0, -10), B = V(0, 0, -62);
  place(S, 7, 4, 0);
  const T0 = 0.6, REL1 = T0 + 0.4, REL2 = T0 + 0.52, OPEN1 = REL1 + 0.35, OPEN2 = REL2 + 0.8, W0 = OPEN2 + 0.25, IN = W0 + 0.7, OUT = IN + 0.08, W1 = OUT + 0.45, SIN = IN + 0.45, CLOSE = W1 + 1.6, RE = CLOSE + 0.5;
  S.path = [[0, S.pos.clone(), 0, 0], [W0 + 0.2, S.pos.clone(), 0, 0], [W0 + 0.3, V(5, 0, 0), yawTo(V(7, 0, 4), A), 1], [SIN, V(0, 0, -10.5), 0, 1], [SIN + 0.02, V(0, 0, -62.5), 0, 1], [SIN + 0.5, V(5, 0, -70), yawTo(V(0, 0, -62), V(5, 0, -70)), 0.5], [SIN + 0.7, V(5, 0, -70), 0, 0]];
  const keys = idleIntro([K(T0 + 0.35, PORT_SET, "io"), K(REL1 + 0.05, PORT_FLING, "in2"), K(REL2 + 0.3, PORT_FLING, "out"), K(W0, T_READY, "io"), K(W1 + 0.3, T_READY)], T0);
  const portals = [];
  const film = (() => { const c = document.createElement("canvas"); c.width = c.height = 128; const x = c.getContext("2d"); const g = x.createRadialGradient(64, 64, 4, 64, 64, 64); g.addColorStop(0, "rgba(220,255,250,.9)"); g.addColorStop(0.6, "rgba(60,230,200,.45)"); g.addColorStop(1, "rgba(30,180,160,.15)"); x.fillStyle = g; x.fillRect(0, 0, 128, 128);
    x.strokeStyle = "rgba(255,255,255,.55)"; x.lineWidth = 5; for (let i = 0; i < 4; i++) { x.beginPath(); x.arc(64, 64, 14 + i * 12, i, i + 2.2); x.stroke(); } return new THREE.CanvasTexture(c); })();
  const openPortal = (at, k) => { const g = new THREE.Group(); g.position.copy(at).setY(4.8); scene.add(g);
    g.add(new THREE.Mesh(new THREE.TorusGeometry(4.2, 0.32, 10, 48), gm("portal", "teal")));
    const f = new THREE.Mesh(new THREE.CircleGeometry(4.0, 40), new THREE.MeshBasicMaterial({map: film, transparent: true, depthWrite: false, side: THREE.DoubleSide})); g.add(f); g.userData.film = f;
    for (let i = 0; i < 8; i++) { const a = i * Math.PI / 4; const v = new THREE.Mesh(new THREE.BoxGeometry(0.3, 1.5, 0.5), MAT.brass); v.position.set(Math.cos(a) * 5.0, Math.sin(a) * 5.0, 0); v.rotation.z = a - Math.PI / 2; g.add(v); }
    g.scale.setScalar(0.05); portals[k] = g; flash(g.position, 10, 0xb8fff0); groundRing(at, 6, 0x2fe6c8, 0.5); return g; };
  let pA = [null, null];
  const ev = [{t: REL1, f: () => { pA[0] = carryPos(cs[0]); }}, {t: REL2, f: () => { pA[1] = carryPos(cs[1]); }},
    {t: OPEN1, f: () => openPortal(A, 0)}, {t: OPEN2, f: () => { openPortal(B, 1); textTag(B.clone().add(V(0, 13, 0)), "LINKED · 54 studs", "#a8fff0", 1.8);
      const line = new THREE.Mesh(new THREE.PlaneGeometry(1.2, 52), new THREE.MeshBasicMaterial({map: dashTex, color: 0x2fe6c8, transparent: true, depthWrite: false})); line.rotation.x = -Math.PI / 2; line.position.set(0, 0.14, -36);
      addFx(line, 1.2, (o, u) => { o.material.opacity = 0.9 * (1 - u); dashTex.offset.y = -clockT * 3; }); }},
    {t: IN, f: () => { flash(A.clone().setY(5), 12, 0xb8fff0); feathers(A.clone().setY(5), 10, [0x8ff7e6, 0xffffff], 0.8, 4); }},
    {t: OUT, f: () => { flash(B.clone().setY(5), 14, 0xb8fff0); feathers(B.clone().setY(5), 12, [0x8ff7e6, 0xffffff], 0.9, 4); shake = 0.3; }},
    {t: RE, f: () => cs.forEach(c => { const p = carryPos(c); flash(p, 3, 0xb8fff0); sparks(p, V(0, 0.5, 0), 5, 0xa8fff0, 0.4); })},
    {t: SIN, f: () => { flash(A.clone().setY(5), 9, 0xb8fff0); later(0.03, () => { flash(B.clone().setY(5), 10, 0xb8fff0); textTag(rapChest(S).add(V(0, 11, 0)), "SQUADMATE THROUGH", "#8fd0ff", 1.3); }); }}];
  return {frame: [V(0, 0, 6), V(0, 0, -72)], keys, ev, eyes: [[T0 + 0.1, REL2 + 0.3]],
    update(t, dt) {
      PGLOW.portal = t > T0 && t < CLOSE ? 1 : 0; MS.walk = (t > W0 && t < W1) ? 1 : 0;
      portals.forEach((g, i) => { if (!g) return; const o = i ? OPEN2 : OPEN1; const k = t < CLOSE ? E.back(win(t, o, o + 0.3)) : 1 - E.io(win(t, CLOSE, CLOSE + 0.35)); g.scale.setScalar(Math.max(0.01, k)); g.userData.film.rotation.z = t * 2; if (t > CLOSE + 0.36) { scene.remove(g); portals[i] = null; } });
      cs.forEach(c => { if (t >= CLOSE) c.k = t >= RE ? 1 : 0.001; });
    },
    post(t) {
      cs.forEach((c, i) => { const r = i ? REL2 : REL1, o = i ? OPEN2 : OPEN1, to = i ? B : A;
        if (t < r) { carryOff(c); return; }
        if (t < o) { const u = win(t, r, o); const p = pA[i].clone().lerp(to.clone().setY(4.8), u); p.y += 4 * (i ? 9 : 2.5) * u * (1 - u); carryAt(c, new THREE.Matrix4().compose(p, new THREE.Quaternion().setFromEuler(new THREE.Euler(0, t * 12, 0)), V(2, 2, 2).multiplyScalar(1 + 4 * u))); return; }
        carryOff(c); if (t < CLOSE) c.k = 0.001; }); },
    move(t) { const w = t < W0 ? 0 : t < IN ? -10.5 * win(t, W0, IN) : t < W1 ? -62.5 - 8 * win(t, OUT, W1) : -70.5; return {z: t < IN ? w : t < OUT ? -10.5 : w}; },
    hide: t => t >= IN && t < OUT,
    phases: [[0, T0, "Slotted: two portal rings on the troodon"], [T0, REL1, "Wind-up: crouch, the rings light up"], [REL1, OPEN2, "Flings both rings: one opens just ahead, one 54 studs away"], [OPEN2, IN, "Linked: walks into the near ring"], [IN, W1, "Out of the far ring; a squadmate follows (star)"], [W1, CLOSE, "The rings stay open 8 s (shown faster)"], [CLOSE, RE + 0.6, "Recovery: they close; new rings grow on the mounts"]],
    len: RE + 0.7};
}

function lastTrack(L) {
  const lk = isLook("lastfeather", L);
  heroBar.on = true; hero.hp = 9; hero.max = 55;
  place(R0, 2.5, 26); place(R1, -8, 30); R0.yaw = yawTo(R0.pos, V(0, 0, 0)); R1.yaw = yawTo(R1.pos, V(0, 0, 0));
  const BITE = 0.95, SAVE = BITE + 0.02, LAUNCH = SAVE + 0.16, UNT = SAVE + 1.0;
  R0.path = [[0, R0.pos.clone(), R0.yaw, 1], [0.72, V(1.2, 0, 10.5), R0.yaw, 1], [0.8, V(1.2, 0, 10.5), R0.yaw, 0]];
  R1.path = [[0, R1.pos.clone(), R1.yaw, 0], [0.5, R1.pos.clone(), R1.yaw, 1], [1.2, V(-2, 0, 10), yawTo(R1.pos, V(0, 0, 0)), 1], [1.3, V(-2, 0, 10), yawTo(R1.pos, V(0, 0, 0)), 0]];
  // escape flight: a wing beat up ~9 studs, then the troodon glide (falls 8 studs/s), forward 30 studs/s
  const Gv = 196.2, V0 = Math.sqrt(2 * Gv * 9), path = []; let y = 0, vy = V0, x = 0, tt = LAUNCH, glide = null, land = null;
  while (tt < 9) { path.push([tt, x, y]); if (glide === null && vy <= 0) glide = tt; vy = glide !== null ? -8 : vy - Gv / 240; y += vy / 240; x += 30 / 240; tt += 1 / 240; if (y <= 0) { land = tt; path.push([tt, x, 0]); break; } }
  const at = q => { if (q <= LAUNCH) return [0, 0]; if (q >= land) return [path[path.length - 1][1], 0]; const k = Math.min(path.length - 1, Math.floor((q - LAUNCH) * 240)); return [path[k][1], path[k][2]]; };
  const keys = [K(0, T_READY), K(BITE - 0.25, T_READY), K(SAVE + 0.04, addPose(TJ_CROUCH, {RootJoint: [8, 0, 0], Neck: [14, 0, 0]}, 1), "out"), K(LAUNCH, TF_DOWN, "in2"), K(glide - 0.08, TF_UP, "io"), K(glide + 0.12, TF_GLIDE, "out"), K(land - 0.12, TF_GLIDE, "io"), K(land, TJ_DOWN, "io"), K(land + 0.12, TJ_LAND, "out"), K(land + 0.7, T_READY, "io")];
  const ev = [{t: BITE - 0.12, f: () => { R0.lunge = 1; }},
    {t: BITE, f: () => { const p = torsoPt(); popNum(p.clone().add(V(0, 5, 0)), 12, "big"); flash(p, 8); hero.hp = 1; hitStop = 0.14; shake = 0.9; fovPunch = 4;
      const v = $("vig"); v.style.background = "radial-gradient(ellipse at center, transparent 45%, rgba(255,215,110,.7))"; v.style.transition = "none"; v.style.opacity = 0.8; requestAnimationFrame(() => { v.style.transition = "opacity .7s"; v.style.opacity = 0; });
      textTag(heroHRP().add(V(0, 16, 0)), "LAST FEATHER · 1 HP", "#ffe08a", 1.8); }},
    {t: SAVE, f: () => { const p = partPoint(hero.segs.Torso[2]); flash(V(0, 0, 0).applyMatrix4(MECH.find(m => m.look === lk && !m.bracket).mesh.matrix), 9, 0xffe08a); feathers(p, 40, [0xffffff, 0xffe08a, 0xd9cdb6], 1.3, 9);
      zoneBurst(V(hero.pos.x, 0.5, hero.pos.z)); textTag(V(hero.pos.x, 12, hero.pos.z + 4), "GLOW ZONE DROPPED (star)", "#a8fff0", 1.6); }},
    {t: SAVE + 0.05, f: () => { textTag(heroHRP().add(V(0, 13, 0)), "UNTOUCHABLE 1 s", "#cfe6ff", 1.2); shimmer(() => heroHRP().add(V(0, 1, 0)), 9, SHIELD_BLUE, 1.0, 0.5); }},
    {t: SAVE + 0.38, f: () => { R1.lunge = 1; later(0.18, () => textTag(V(-1.5, 9, 8), "MISS", "#ffffff", 1.1)); }}];
  return {frame: [V(0, 0, 22), V(0, 0, -40)], keys, ev, eyes: [[BITE, UNT]],
    update(t) { MS.cell = t < SAVE ? 1 : 0; PGLOW.lastfeather = t < BITE ? 0.3 : t < SAVE + 0.25 ? 3 : -1; MS.unfold = L === "C" ? (t < SAVE ? 0 : t < land ? E.out(win(t, SAVE, SAVE + 0.25)) : 1 - win(t, land, land + 0.4)) : 0; },
    move(t) { const [f, u] = at(t); return {z: -f, up: u}; },
    phases: [[0, BITE - 0.25, "Slotted: at 9 HP, the reserve glows; a raptor closes in from behind"], [BITE - 0.25, BITE, "The raptor lunges (the killing hit)"], [BITE, LAUNCH, "Trigger: 12 damage would kill: left at 1 HP instead"], [LAUNCH, UNT, "Bursts up and glides away, untouchable 1 s; a glow zone drops behind (star)"], [UNT, land + 0.8, "Glides down, plain landing; the part is spent until the next life"]],
    len: land + 1.1};
}

function plumeTrack(L) {
  zoneScene(); place(R2, 6.5, -8.5); R2.yaw = yawTo(R2.pos, V(0, 0, 0));
  heroBar.on = true; hero.hp = 55; hero.max = 55; hero.plume = 0; S.max = 60; setHp(S, 60); S.hpShow = true; S.plume = 0;
  const T0 = 0.6, REL = T0 + 0.34, FLY = 0.55, SPLAT = REL + FLY, OVER = SPLAT + 0.35, TICK = SPLAT + 1.0, BITE = SPLAT + 1.35;
  const keys = idleIntro(THROW(T0), T0);
  const ev = [{t: REL, f: () => throwPod({kind: "pod", from: handsPoint(), target: () => R0.pos.clone().setY(1), T: FLY, H: 9, onHit: p => { zoneBurst(p); selfHeal.splice(0); }})},
    {t: OVER, f: () => { const p = partPoint(mouthParts.skull).add(V(0, 6, 0)); popNum(p, "+4", "heal"); textTag(p.clone().add(V(0, 6, 0)), "FULL · +4 PLUME", "#ffe08a", 1.6); hero.plume = 4; heroHeal = 0.4; }},
    {t: TICK + 0.02, f: () => { S.plume = 5; textTag(rapChest(S).add(V(0, 14, 0)), "SQUADMATE +5 PLUME (star)", "#ffe08a", 1.6); shimmer(() => rapChest(S), 6.5, GOLD, 2.2, 0.35); }},
    {t: BITE - 0.3, f: () => { R2.lunge = 1; }},
    {t: BITE, f: () => { const p = torsoPt(); shimmer(() => heroHRP().add(V(0, 1, 0)), 8, 0xffffff, 0.3, 0.7); flash(p, 9, 0xffffff); popNum(p.clone().add(V(0, 5, 0)), 2, "hit"); hero.plume = 0; hero.hp = 53; textTag(heroHRP().add(V(0, 15, 0)), "6 HIT · PLUME SOAKS 4", "#ffe08a", 1.6); shake = 0.4; }}];
  return {frame: [V(0, 0, 2), V(0, 0, -46)], keys, ev, eyes: [[T0, REL + 0.4]],
    update(t) { MS.plume = hero.plume / 14; PGLOW.plume = hero.plume > 0 ? 1.2 + Math.sin(t * 10) * 0.3 : t > BITE && t < BITE + 0.25 ? 3 : -0.6; },
    phases: [[0, T0, "Slotted: the plume is dark (no overheal yet)"], [T0, SPLAT, "At full health it throws a glow pod"], [SPLAT, OVER, "The splat hits 2 enemies: +4 self-heal"], [OVER, TICK, "Already full: the +4 becomes a gold plume (it lights up)"], [TICK, BITE, "The zone heals a full squadmate: its +5 becomes a plume too (star)"], [BITE, BITE + 1.2, "A raptor bites for 6: the plume soaks 4, health takes 2"]],
    len: BITE + 1.3};
}

function fortifyTrack(L) {
  zoneScene(); S.max = 60; setHp(S, 60); S.hpShow = true;
  const T0 = 0.6, REL = T0 + 0.34, FLY = 0.55, SPLAT = REL + FLY, BITE = SPLAT + 0.75, LEAVE = SPLAT + 1.8, OUTZ = LEAVE + 0.5, OFF = OUTZ + 1.4;
  S.path = [[0, S.pos.clone(), S.yaw, 0], [LEAVE, S.pos.clone(), S.yaw, 0], [LEAVE + 0.1, S.pos.clone(), yawTo(S.pos, V(-22, 0, -28)), 1], [OUTZ + 0.3, V(-21, 0, -29), yawTo(S.pos, V(-22, 0, -28)), 1], [OUTZ + 0.5, V(-21, 0, -29), yawTo(S.pos, V(-22, 0, -28)), 0]];
  const keys = idleIntro(THROW(T0), T0);
  let shell = null;
  const ev = [{t: REL, f: () => throwPod({kind: "pod", from: handsPoint(), target: () => R0.pos.clone().setY(1), T: FLY, H: 9, onHit: p => { zoneBurst(p); }})},
    {t: SPLAT + 0.05, f: () => { shell = shimmer(() => rapChest(S), 6.5, 0x2fe6c8, OFF - SPLAT, 0.55); textTag(rapChest(S).add(V(0, 14, 0)), "FORTIFIED · −25% DAMAGE", "#a8fff0", 2); }},
    {t: BITE - 0.25, f: () => { R0.lunge = 1; }},
    {t: BITE, f: () => { const p = rapChest(S); flash(p, 7, 0xa8fff0); popNum(p.clone().add(V(0, 5, 0)), 6, "hit"); textTag(p.clone().add(V(0, 9.5, 0)), "8 → 6", "#a8fff0", 1.3); S.flinch = 0.7; setHp(S, S.hp - 6); }},
    {t: OUTZ, f: () => textTag(rapChest(S).add(V(0, 12, 0)), "LEFT THE ZONE · LINGERS 1.4 s", "#a8fff0", 1.4)}];
  return {frame: [V(0, 0, 2), V(0, 0, -46)], keys, ev, eyes: [[T0, REL + 0.4]],
    update(t) { PGLOW.fortify = t > SPLAT && t < SPLAT + 3 ? 1.2 + Math.sin(t * 8) * 0.4 : 0; },
    phases: [[0, T0, "Slotted: the emitter idles"], [T0, SPLAT, "Throws a glow pod (the normal attack)"], [SPLAT, BITE, "Squadmates inside the zone are fortified: −25% damage"], [BITE, LEAVE, "A raptor bites for 8: the squadmate takes 6"], [LEAVE, OFF, "It walks out: the fortify lingers 1.4 s (III)"], [OFF, OFF + 0.6, "Off"]],
    len: OFF + 0.6};
}

function ricochetTrack(L) {
  place(R0, -2, -40); place(R1, 11, -52); R0.yaw = yawTo(R0.pos, V(0, 0, 0)); R1.yaw = yawTo(R1.pos, V(0, 0, 0));
  const T0 = 0.6, REL = T0 + 0.34, FLY = 0.55, SPLAT = REL + FLY, B2 = SPLAT + 0.47;
  const keys = idleIntro(THROW(T0), T0);
  const ev = [{t: REL, f: () => { MS.kick = 1; throwPod({kind: "pod", from: handsPoint(), target: () => R0.pos.clone().setY(1), T: FLY, H: 9, onHit: p => { zoneBurst(p); selfHeal.splice(0);
      textTag(p.clone().add(V(0, 12, 0)), "BOUNCE", "#ffd38a", 1.1); sparks(p, V(0.6, 1, -0.5), 8, 0xffe7a8, 0.6);
      throwPod({kind: "pod", from: p.clone().add(V(0, 1.5, 0)), target: () => R1.pos.clone().setY(1), T: B2 - SPLAT, H: 6, onHit: q => { zoneBurst(q); selfHeal.splice(0); textTag(q.clone().add(V(0, 12, 0)), "2ND ZONE · 20 studs", "#a8fff0", 1.4); }}); }}); }}];
  return {frame: [V(0, 0, 2), V(0, 0, -56)], keys, ev, eyes: [[T0, REL + 0.4]],
    update(t) { MS.spring = t < T0 ? 0 : t < REL ? E.io(win(t, T0, REL)) : 1 - E.out(win(t, REL, REL + 0.12)); PGLOW.ricochet = t > T0 && t < REL + 0.3 ? 1.5 : t > SPLAT && t < B2 ? 1 : 0; },
    phases: [[0, T0, "Slotted: the springs sit cocked"], [T0, REL, "Wind-up: the pod presses into the springs"], [REL, SPLAT, "They kick as the pod leaves the hands"], [SPLAT, B2, "Splat on the first enemy, then it bounces on"], [B2, B2 + 1.6, "Splats a second full zone on the next enemy (20.3-stud bounce reach)"]],
    len: B2 + 1.8};
}

let allPose = 0;
function allTrack() { // the kit's moves that swing the long arms / tail most: pod throw, flap up / down, glide, one-arm cock
  const keys = [K(0, T_READY), K(1.2, T_READY), K(1.45, TA_HOLD_W, "io"), K(1.75, TA_THROW, "in2"), K(2.2, TA_THROW), K(2.6, TF_UP, "io"), K(2.95, TF_DOWN, "in2"), K(3.3, TF_UP, "io"), K(3.7, TF_GLIDE, "out"), K(4.5, TF_GLIDE), K(4.9, LANT_COCK, "io"), K(5.4, LANT_COCK), K(5.8, T_READY, "io")];
  return {frame: [V(0, 0, 8), V(0, 0, -10)], keys, ev: [], phases: [[0, 1.2, "All chosen parts on at once (idle)"], [1.2, 2.4, "Pod throw (arms forward, neck down)"], [2.4, 3.5, "Flap up / down (arms raised out to the sides)"], [3.5, 4.6, "Glide (arms spread wide)"], [4.6, 6.2, "One-arm wind-up (arm back)"]], len: 6.2};
}

// ---------- layered VFX helpers (each maps to a Roblox piece: glow = Neon + PointLight, trail = Trail / ParticleEmitter,
// orb = the MineBurst neon ball, crackle = MineServer's re-drawn zap Beams, aura = TenoBellowAura disc) ----------
function glowAt(fn, color, size, life, op) { const s = sprite(T_FLASH, color, size, true); return addFx(s, life, (o, u) => { o.position.copy(fn()); o.material.opacity = (op || 0.8) * Math.min(1, u * life / 0.1) * (1 - u * u); o.scale.setScalar(size * (0.9 + 0.1 * Math.sin(clockT * 20))); }); }
function trailOn(fn, color, life, rate, size) { let em = 0; const o = new THREE.Object3D(); return addFx(o, life, (ob, u, dt) => { em += dt * rate; while (em >= 1) { em -= 1; const s = sprite(T_FLASH, color, size || 1.2, true); s.position.copy(fn()); addFx(s, 0.35, (q, uu) => { q.material.opacity = 0.9 * (1 - uu); q.scale.setScalar((size || 1.2) * (1 - uu * 0.7)); }); } }); }
function orb(p, r, color, life) { const m = new THREE.Mesh(new THREE.SphereGeometry(1, 20, 14), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0.7, depthWrite: false}));
  m.position.copy(p); return addFx(m, life || 0.35, (o, u) => { o.scale.setScalar(Math.max(0.01, r * E.out(u))); o.material.opacity = 0.7 * (1 - u); }); }
function crackle(R, life) { for (let i = 0; i < 3; i++) later(i * 0.06, () => { const a = () => rapChest(R).add(V((Math.random() - .5) * 5, (Math.random() - .5) * 4, (Math.random() - .5) * 5)); zap(a, a, Math.max(0.1, life - i * 0.06), 0xe1faff); }); }
function aura(fnPos, r, color, life, op) { const m = new THREE.Mesh(new THREE.CircleGeometry(r, 40), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0, depthWrite: false})); m.rotation.x = -Math.PI / 2;
  const rim = new THREE.Mesh(new THREE.RingGeometry(r * 0.9, r, 40), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0, depthWrite: false, side: THREE.DoubleSide})); rim.position.z = 0.01; m.add(rim);
  return addFx(m, life, (o, u) => { o.position.copy(fnPos()).setY(0.15); const k = Math.min(1, u * life / 0.15) * Math.min(1, (1 - u) * life / 0.3); o.material.opacity = (op || 0.25) * k * (0.85 + 0.15 * Math.sin(clockT * 7)); rim.material.opacity = 0.9 * k; }); }
function rising(fnPos, color, life, rate, spread) { let em = 0; const o = new THREE.Object3D(); return addFx(o, life, (ob, u, dt) => { em += dt * rate; while (em >= 1) { em -= 1; const s = sprite(T_POD, color, 0.7 + Math.random() * 0.6, true); s.position.copy(fnPos()).add(V((Math.random() - .5) * spread, (Math.random() - .5) * spread * 0.6, (Math.random() - .5) * spread)); const vy = 3 + Math.random() * 4; addFx(s, 0.8, (q, uu, d) => { q.position.y += vy * d; q.material.opacity = uu < 0.2 ? uu / 0.2 : 1 - uu; }); } }); }

// ---------- the parts (Kepu's picks; numbers proposed: 4 steps I / II / III / star, the 35% rule: a step's number is at
// least 1.35x the step before; steps extend time / reach / count / recharge (the Herrera trim); main % never restacked) ----------
const MOVES = [
  {id: "mender", code: "H1", name: "Mender Drone", area: "health", kind: "Button"},
  {id: "lantern", code: "A6", name: "Arc Lantern", area: "attack", kind: "Button"},
  {id: "sapwall", code: "D1", name: "Sap Wall", area: "defense", kind: "Button"},
  {id: "shed", code: "D18", name: "Feather Shed", area: "defense", kind: "Button"},
  {id: "portal", code: "S6", name: "Portal Feathers", area: "speed", kind: "Button"},
  {id: "lastfeather", code: "H7", name: "Last Feather", area: "health", kind: "Always on"},
  {id: "plume", code: "H12", name: "Overheal Plume", area: "health", kind: "Always on"},
  {id: "fortify", code: "D5", name: "Fortify Field", area: "defense", kind: "Always on"},
  {id: "ricochet", code: "A10", name: "Ricochet Pod", area: "attack", kind: "Always on"},
  {id: "all", code: "", name: "All 9 / any 4", area: "all", kind: "Clash check"},
];
const AREA = {attack: ["Attack", "#ff6b6b"], speed: ["Speed", "#e0a800"], defense: ["Defense", "#3d9be0"], health: ["Health", "#2fae5a"], all: ["Clash check", "#8f99aa"]};
const NUMS = {
  mender: {max: "A little feathered drone flies to the most hurt squadmate within 40 studs, orbits it and heals it 4 per second; when that one is full it moves on to the next most hurt. With no squad it orbits you.",
    steps: ["Button: the drone heals the most hurt squadmate within 40 studs (you, with no squad) 4/s for 4 s (16). Recharges in 20 s", "Heals for 5.4 s (21.6)", "Recharges in 14.8 s", "When its target is full it moves on to the next most hurt squadmate"],
    check: "5.4 / 4 = 1.35 · 20 / 14.8 = 1.35 · star: 1 → every squadmate in reach",
    trade: "The only heal the troodon can aim at one squadmate, and it keeps healing while the troodon keeps throwing pods. 4/s is slower than standing in a zone (5/s), the drone is out of play for its whole run, and with no squad it is a small self-heal.",
    design: "A support drone that leaves its carrier and orbits the patient (the idea behind Overwatch's Mercy beam / Apex Lifeline's D.O.C. heal drone): our own feathered puck / bird / capsule drone, healing in the Med-Station's green.",
    roblox: "Drone = welded Model that un-welds and is tweened (or AlignPosition) to an orbit; Beam (green, 0.3 s) per tick + the Med-Station's MedWave ring + MedHealPop '+4'; Trail on the drone; PointLight in the dome; ParticleEmitter for the heal sparkles.",
    follows: "MedStationServer (MedWave ring, MedHealPop green +N), TrooFX heal pop, TenoMovesFX bellow aura disc under the healed squadmate."},
  lantern: {max: "Throw a lantern up to 40 studs; it opens and zaps the nearest enemy within 16 studs, then chains to up to 2 more (3 in all), 8 damage each.",
    steps: ["Button: throw a lantern up to 40 studs; it zaps the nearest enemy near it, then chains to 1 more within 12 studs: 8 damage each. Recharges in 14 s", "Chains reach 16.2 studs", "Recharges in 10.3 s", "Chains to 3 enemies"],
    check: "16.2 / 12 = 1.35 · 14 / 10.3 = 1.36 · star: 2 → 3 targets (1.5x)",
    trade: "Hurts a group the pod can't (no arc needed once it lands) and the arcs show exactly who it hits. Only 8 per enemy, it needs enemies close together, and the troodon has to throw it (no pod in those hands for ~0.5 s).",
    design: "A chain-lightning device (Risk of Rain's Ukulele, Dota's Zeus arcs): a caged storm lantern that hops lightning from enemy to enemy, in the raptor Shock Mine's cyan.",
    roblox: "Lantern = a welded Model flung on an arc (TweenService / BodyPosition), Neon glass + PointLight; arcs = Beams with 6-8 re-drawn Attachments every 0.06 s (MineZapArc), MineBurst Neon ball at each hit, 'MineZapSparks' ParticleEmitter on the target.",
    follows: "MineServer shock look (VOLT 127,233,255 / core 225,250,255, MineBurst, MineZapArc beams, sparks); TrooFX pod arc for the throw."},
  sapwall: {max: "Throw a sap pod up to 40 studs; it splats and hardens into a 19-stud wall that blocks dinos and shots for 4 s.",
    steps: ["Button: throw a sap pod up to 40 studs: it hardens into a 14-stud wall that blocks dinos and shots for 2.1 s. Recharges in 18 s", "Wall 19 studs wide", "Lasts 2.9 s", "Lasts 4 s"],
    check: "19 / 14 = 1.36 · 2.9 / 2.1 = 1.38 · 4 / 2.9 = 1.38",
    trade: "Splits a fight: stops a charge or a shot line and covers a hurt squadmate. Blocks your own squad's shots and paths too, and a badly thrown wall can trap a squadmate on the wrong side.",
    design: "An instant wall from a thrown canister (Overwatch Mei's Ice Wall, Apex Catalyst's ferrofluid wall), made of the troodon's own amber sap: it lands glossy and wet, then sets hard.",
    roblox: "Wall = 5 anchored Glass / SmoothPlastic parts (amber, Transparency 0.45 → 0.1 as it sets) that tween up from the ground (CanCollide true, blocks raycasts), a Neon rim at the base; splat = the TrooFX splat flash + amber embers; crumble = the parts thrown off and faded.",
    follows: "TrooFX pod + splat (FFC35A pod, FFE2A0 flash, FFB43A embers); TenoMovesFX boulder rubble for the crumble."},
  shed: {max: "Shed your feathers: break out of a stun, pin or grab at once; the burst knocks dinos within 10 studs back and slows them 25% for 2 s; you're immune to stuns, pins and grabs for 1.4 s.",
    steps: ["Button: shed your feathers to break out of a stun, pin or grab; immune to them for 1 s. Recharges in 24 s", "Immune 1.4 s", "Recharges in 17.7 s", "The burst knocks dinos within 10 studs back and slows them 25% for 2 s"],
    check: "1.4 / 1 = 1.4 · 24 / 17.7 = 1.36",
    trade: "The troodon's only answer to a pounce or a grab (55 HP doesn't last long pinned). Usable while stunned (the one part that is). Does nothing if you aren't held, and the long recharge means the second pin in a fight sticks.",
    design: "A stun breaker made visible (League's Quicksilver / QSS-style cleanse, a lizard dropping its tail): quick-release feather armour that blows off in a burst of feathers and plates.",
    roblox: "Plates = welded parts un-welded and flung (AssemblyLinearVelocity, then faded); feathers = ParticleEmitter (feather texture, Drag); shockwave = flat Neon ring; immune = ForceField-material shell (the Energy Shield dome) for 1.4 s.",
    follows: "EnergyShieldServer dome look (immune), TenoMovesFX shockwave ring, TheriMovesFX feather blades (feather shapes)."},
  portal: {max: "Fling two linked feather rings: one opens just ahead, the other up to 54 studs away; walking into one puts you out of the other. They stay 8 s, and squadmates can use them too.",
    steps: ["Button: fling two linked feather rings, one just ahead and one up to 40 studs away; walk into one, come out of the other. Last 6 s, you only. Recharges in 20 s", "The far ring reaches 54 studs", "Last 8.1 s", "Squadmates can use them too"],
    check: "54 / 40 = 1.35 · 8.1 / 6 = 1.35",
    trade: "Moves the whole squad (star) and both ends are visible, so it is a set-up, not an escape button. Enemies see the rings too and can wait at the far one.",
    design: "A two-ended portal you set up and walk through (Apex Wraith's Dimensional Rift, League Bard's Magical Journey), made of the troodon's feathers: brass feather vanes round a teal ring.",
    roblox: "Ring = Neon torus MeshPart + 8 brass vane parts + a SurfaceGui / Decal swirl film rotating; open = flash + ring wave; travel = PivotTo with a teal flash and feather ParticleEmitter at both ends; Trail on the flung rings.",
    follows: "TrooFX zone teal (2FE6C8 / A8FFF0) and its ring wave; TheriMovesFX feather blades."},
  lastfeather: {max: "Once per life, a killing hit leaves you at 1 HP: you burst up and glide away, untouchable for 1 s, and drop a glow zone where you were.",
    steps: ["Always on (takes a slot): once per life a killing hit leaves you at 1 HP, untouchable for 0.7 s", "You also burst up into a glide (a free flap)", "Untouchable 1 s", "You drop a glow zone where you were"],
    check: "1 / 0.7 = 1.43 · II and star add the escape and the zone",
    trade: "Saves the squishiest dino in the roster once per life and turns the save into a getaway. It uses a slot that could be a button, does nothing until you'd die, and 1 HP after the glide is still 1 HP.",
    design: "A clutch save (Overwatch Baptiste's Immortality Field, a 'second chance' perk): a reserve cell that spends itself in one golden burst of feathers.",
    roblox: "Cell = Neon part (amber → dark when spent); save = gold screen vignette (ScreenGui) + Neon burst + feather ParticleEmitter; untouchable = ForceField-material dome (Energy Shield) 1 s; glide = the existing GliderAuto glide.",
    follows: "EnergyShieldServer dome + white ripple, the troodon Flap & Glide (TF poses), TrooFX zone for the star drop."},
  plume: {max: "Healing above your max health becomes a gold armour plume that soaks up to 14 damage; it fades after 7 s. Squadmates you heal above their max get a plume too.",
    steps: ["Always on (takes a slot): healing above your max becomes a plume that soaks up to 10 damage; it fades after 5 s", "Soaks up to 14", "Fades after 7 s", "Squadmates you heal above their max get a plume too"],
    check: "14 / 10 = 1.4 · 7 / 5 = 1.4",
    trade: "Makes every pod splat worth something at full health (the self-heal is wasted otherwise) and, at star, the zone heal too. Needs the troodon to be full and hitting enemies; it is extra health, not a block.",
    design: "Overhealth shown as armour (Overwatch Brigitte's overhealth, Monster Hunter's 'extra' health bars): gold armour feathers that light up as they fill.",
    roblox: "Plume = Neon gold blades whose Transparency follows the plume amount; fill = gold motes (ParticleEmitter) rising into it; soak = white ForceField flash shell + 'SOAKED' pop; a gold segment on the HP bar.",
    follows: "TrooFX heal pop and self-heal, EnergyShieldServer white ripple on a block."},
  fortify: {max: "Squadmates inside your glow zones take 25% less damage, and keep it 1.4 s after they leave. You're fortified too inside your own zones.",
    steps: ["Always on (takes a slot): squadmates inside your glow zones take 25% less damage", "It lingers 1 s after they leave", "Lingers 1.4 s", "You're fortified too inside your own zones"],
    check: "1.4 / 1 = 1.4 · the 25% is never restacked (upgrade rule)",
    trade: "Turns the zone into a place to stand and fight, not just a heal puddle. Only works where your zones are, so a squad that won't stand in them gets nothing; 25% of a raptor bite is 2.",
    design: "A damage-reduction field (Overwatch's Baptiste / Lucio support fields): a teal hex emitter that marks who is fortified with a hex shell.",
    roblox: "Emitter = Neon hex part + PointLight that pulses while a zone is up; fortified = a ForceField-material shell (teal) + a TenoBellowAura-style disc; '8 → 6' pop on hits.",
    follows: "TrooFX zone teal, TenoMovesFX bellow aura disc, EnergyShieldServer dome shell."},
  ricochet: {max: "Your glow pod bounces once off the first enemy it splats and lands a second full zone on the next enemy within 20.3 studs.",
    steps: ["Always on (takes a slot): the pod bounces once and splats a second, half-size zone (10 studs) on the next enemy within 15 studs; it lasts 2.2 s", "Bounce reach 20.3 studs", "The second zone lasts the full 3 s", "The second zone is full size (20 studs)"],
    check: "20.3 / 15 = 1.35 · 3 / 2.2 = 1.36 · 20 / 10 = 2x",
    trade: "Doubles the zone on grouped enemies with no new button. Needs a second enemy near the first; the bounce can drag the second zone away from where your squad is standing.",
    design: "A bouncing grenade (Overwatch Junkrat's bouncing bombs, Moira's orb rebound): sprung cups / pads that kick the pod and send it hopping on.",
    roblox: "Springs = welded parts tweened on the throw; the bounce = the TrooFX pod (Neon ball + Trail + embers) re-launched from the splat; the second zone = the same TrooFX zone.",
    follows: "TrooFX pod, splat, zone and embers (all reused)."},
};
const LOOKS = {
  mender: {A: {name: "A · Shoulder Dock", sub: "puck drone on an arch over the back", rec: "Sits high and central, so it reads from behind and from both sides, and the drone leaves from where a player looks.",
      mount: "Back, between the shoulder blades: two feet plates, posts, an arch over the crest; the drone docks on the arch.", notes: ["Two rotors + a green heal dome: a drone silhouette even at the game camera's 70 studs.", "Takes the high middle of the back; the spare lower-back spot is shared by five alternative looks."]},
    B: {name: "B · Tail Perch", sub: "bird-shaped drone riding the tail", mount: "Top of the tail (Tail2), on a bridge over the tail crest.", notes: ["Reads as a pet bird riding the tail: very troodon.", "The tail sways, so the drone bobs; behind the dino it's at the bottom of the game camera's view."]},
    C: {name: "C · Chest Cradle", sub: "capsule drone in a cradle on the chest", mount: "Front of the chest between the arms, in a two-arm cradle.", notes: ["Faces the squad in front; the rotor disc is the read.", "Hidden from the game camera (behind / above)."]}},
  lantern: {A: {name: "A · Hip Lantern", sub: "caged lantern on a hook at the +X hip", rec: "A real lantern shape on a hook reads at once, it's on the camera side, and the hand reaching back for it is a clear wind-up.",
      mount: "Back of the +X haunch: a hook arm on a plate, the lantern hangs from it.", notes: ["Swings a little with the leg.", "One-sided (camera side)."]},
    B: {name: "B · Tail Lure", sub: "an angler-fish lure over the tail", mount: "Tail3: a boom arcs up and back, the bulb hangs from its tip; the tail flicks it.", notes: ["The most creature-like look: a glowing lure the tail flings.", "Sits high behind the dino: the biggest read from the game camera, but it's far from the hands."]},
    C: {name: "C · Wrist Lantern", sub: "square lantern on the +X forearm", mount: "Front of the +X forearm, on a clip plate.", notes: ["Rides the arm into the throw (one-arm overhand).", "Small; hidden behind the body from straight behind."]}},
  sapwall: {A: {name: "A · Saddle Tanks", sub: "two amber tanks over the lower back", mount: "Lower back: a tank on each side of the crest, a manifold over it with the next pod in its hatch.", notes: ["Symmetric and readable from behind; the pod hops up into the hands.", "Same spot as the Quill Rack (D18 B), Wing Pack (H7 C), Hip Plumes (H12 C), Disc Launcher (S6 C)."]},
    B: {name: "B · Shoulder Pod", sub: "one big amber pod behind the +X shoulder", rec: "One big glowing ball is the clearest 'this throws a big thing' shape, and the arm takes it straight into the two-hand fling.",
      mount: "+X side of the chest just behind the shoulder, in a ring cradle on two struts (above the flank plates, clear of the flapping arm).", notes: ["Big amber ball on the camera side: the strongest silhouette.", "One-sided."]},
    C: {name: "C · Belly Pod", sub: "sap pod slung under the chest", mount: "Under the chest in two half-ring straps.", notes: ["Drops straight into the hands (short wind-up).", "Hidden from the game camera (behind / above)."]}},
  shed: {A: {name: "A · Flank Plates", sub: "steel feather plates on both flanks", rec: "Covers the biggest area, so the burst (plates flying off both sides) is the most readable 'broke free' moment, and it widens the silhouette.",
      mount: "Both flanks, over the feather coats: rail arms over the back edge, two plates each side, amber release bolts.", notes: ["Plates and bolts blow off; they grow back over the recharge.", "Both sides: reads the same from either shoulder."]},
    B: {name: "B · Quill Rack", sub: "four steel quills fanned on the lower back", mount: "Lower back: saddle over the crest, 4 quills standing up and back.", notes: ["A crest of blades: the burst sends them up.", "Same spot as the Wing Pack (H7 C)."]},
    C: {name: "C · Tail Jacket", sub: "long feather plates on the tail base", mount: "Both sides of the tail base (Tail1), two clamps each.", notes: ["Low and behind: smaller burst.", "Same spot as the Tail Emitters (D5 C)."]}},
  portal: {A: {name: "A · Tail Rings", sub: "two portal rings worn round the tail", rec: "Two rings round the tail are a unique silhouette nobody else has, they read from behind, and a tail flick flinging them is a clear wind-up.",
      mount: "Round the tail (Tail2, before and after its crest), clamped top and bottom.", notes: ["The tail passes through the rings (they never touch it).", "The tail flick flings both."]},
    B: {name: "B · Shin Hoops", sub: "a hoop round each shin", mount: "Round both shins like anklets, clamped at the back.", notes: ["Two hoops = two portals, one per leg.", "Low on the legs: busy next to the walk."]},
    C: {name: "C · Disc Launcher", sub: "two rings stacked on a spindle on the back", mount: "Lower back: a saddle over the crest, a spindle, two rings stacked flat.", notes: ["The rings spin up and fly off the spindle.", "Same spot as the Saddle Tanks (D1 A), Quill Rack (D18 B), Wing Pack (H7 C), Hip Plumes (H12 C)."]}},
  lastfeather: {A: {name: "A · Tail-Base Cell", sub: "reserve cell lying on the tail base", rec: "Glows in the middle of the game camera's view, it's where the brainstorm put it, and 'lit = ready, dark = spent' reads at a glance.",
      mount: "Top of the tail base (Tail1), on a saddle over the crest.", notes: ["Amber window: lit while it's ready, dark after it saved you.", "Small; reads by its glow."]},
    B: {name: "B · Heart Core", sub: "round core in a ring frame on the chest", mount: "Chest front.", notes: ["Faces whoever is about to land the killing hit.", "Hidden from the game camera."]},
    C: {name: "C · Wing Pack", sub: "pack with two fold-out emergency wings", mount: "Lower back, saddle over the crest; two wing fans fold out for the glide.", notes: ["The fans swing out as it glides: the save becomes the escape.", "Same spot as the Quill Rack (D18 B)."]}},
  plume: {A: {name: "A · Tail Plume", sub: "five gold armour feathers on the tail", rec: "A fan standing up on the tail is the biggest, highest gold shape from behind, and it's the brainstorm's 'feather fan that lights up on the tail'.",
      mount: "Tail4, on a clamp; the fan stands up and back.", notes: ["Dark when empty, gold when full of plume.", "Sways with the tail."]},
    B: {name: "B · Helm Plume", sub: "three gold blades on the back of the skull", mount: "Back of the skull (cranium top).", notes: ["Moves with the head: a knight's helmet plume.", "Small, and it moves a lot when it aims."]},
    C: {name: "C · Hip Plumes", sub: "a gold fan splayed out over each hip", mount: "Lower back: a saddle over the crest, a three-blade fan to each side.", notes: ["Widens the silhouette from behind.", "Same spot as the Saddle Tanks (D1 A) and the Disc Launcher (S6 C)."]}},
  fortify: {A: {name: "A · Wrist Bracers", sub: "a hex emitter on each forearm", mount: "Front of both forearms.", notes: ["The pod leaves the hands past them: 'the zone is charged here'.", "Hard to see from behind."]},
    B: {name: "B · Neck Pylon", sub: "a mast with a teal dish behind the neck", rec: "A tall teal dish over the back is a support 'aura' shape that reads from everywhere, including the game camera.",
      mount: "Chest top behind the neck: a bridge over the crest, a mast, a teal hex dish.", notes: ["Pulses teal while one of your zones is up.", "Tall: the neck and head move in front of it."]},
    C: {name: "C · Tail Emitters", sub: "a hex emitter on each side of the tail base", mount: "Both sides of the tail base (Tail1).", notes: ["Low, small.", "Same spot as the Tail Jacket (D18 C)."]}},
  ricochet: {A: {name: "A · Spring Cups", sub: "sprung brass cups on both hands", rec: "On the hands that throw the pod: the springs compress and kick on every throw, so the always-on part is seen working.",
      mount: "Front of both hands, on strap plates.", notes: ["Compress in the wind-up, kick at the release.", "Small: reads by its motion."]},
    B: {name: "B · Forearm Springs", sub: "coil-spring housings along both forearms", mount: "Front of both forearms.", notes: ["The coils squeeze in the wind-up and the striker kicks at the release.", "Same spot as the Wrist Bracers (D5 A) and the Wrist Lantern (A6 C)."]},
    C: {name: "C · Chest Pad", sub: "a sprung bounce pad on the chest", mount: "Chest front, on four springs.", notes: ["The pod rolls off it as the arms swing past.", "Hidden from behind."]}},
};
LOOKS.all = {R: {name: "Recommended", sub: "the recommended look of each"}, A: {name: "All A", sub: "every part's A look"}, B: {name: "All B", sub: "every part's B look"}, C: {name: "All C", sub: "every part's C look"}};
const REC = {mender: "A", lantern: "A", sapwall: "B", shed: "A", portal: "A", lastfeather: "A", plume: "A", fortify: "B", ricochet: "A"};
const BUILD = {mender: menderTrack, lantern: lanternTrack, sapwall: sapTrack, shed: shedTrack, portal: portalTrack, lastfeather: lastTrack, plume: plumeTrack, fortify: fortifyTrack, ricochet: ricochetTrack, all: allTrack};
const PIDS = MOVES.filter(m => m.id !== "all").map(m => m.id);
const MEAS = typeof TROO_MEAS !== "undefined" ? TROO_MEAS : null;

// ---------- the player ----------
let cur = 0, variant = REC.mender, playing = true, speed = 1, camMode = "game";
const allOn = {}; PIDS.forEach(p => { allOn[p] = true; });
let lookOverride = null; // measurement: a set of looks to show
const M = () => MOVES[cur];
function lookOn(look) {
  if (lookOverride) return lookOverride.has(look);
  const id = M().id; const [pid, L] = look.split(".");
  if (id !== "all") return pid === id && L === variant;
  return allOn[pid] && (variant === "R" ? REC[pid] === L : L === variant);
}
function resetFx() { fx.splice(0).forEach(e => scene.remove(e.obj)); tshots.splice(0).forEach(s => { scene.remove(s.mesh); scene.remove(s.glow); }); zones.splice(0).forEach(Z => scene.remove(Z.g)); selfHeal.splice(0); flies.splice(0).forEach(f => scene.remove(f.obj)); delayed = []; CARRY.forEach(c => { carryOff(c); c.k = 1; }); }
function start() {
  resetFx(); msReset();
  for (const R of raps) { Object.assign(R, {flinch: 0, flash: 0, push: 0, slow: 0, tagged: false, path: null, run: 0, heal: 0, lunge: 0, bite: 0, show: false, hpShow: false, plume: 0, _bit: 0}); }
  heroBar.on = false; hero.plume = 0;
  play = {track: null, t: 0, fired: new Set()};
  play.track = BUILD[M().id](variant);
  springs = {}; rootSpring.x = 0; rootSpring.v = 0; hitStop = 0; shake = 0; fovPunch = 0;
  hero.pos.set(0, 0, 0);
}
function idleLayer(t) {
  const b = Math.sin(t * 2.3), b2 = Math.sin(t * 2.3 + 1.2);
  return {RootJoint: [b * 1.0, 0, 0], Neck: [b * 1.6, Math.sin(t * 0.8) * 5, 0], Head: [-b * 1.4, Math.sin(t * 1.1 + 1) * 5, 0], Jaw: [Math.max(0, Math.sin(t * 0.5)) * -2, 0, 0],
    ArmL: [b2 * 3, 0, 0], ArmR: [b2 * 3, 0, 0],
    Tail1: [b * 1.2, Math.sin(t * 1.3) * 4, 0], Tail2: [0, Math.sin(t * 1.3 - .6) * 5, 0], Tail3: [0, Math.sin(t * 1.3 - 1.2) * 6, 0], Tail4: [0, Math.sin(t * 1.3 - 1.8) * 7, 0], Tail5: [0, Math.sin(t * 1.3 - 2.4) * 8, 0]};
}
function inWin(list, t) { return (list || []).some(([a, b]) => t >= a && t < b); }
function rapPose(R, dt) {
  R.rig.g.visible = R.show; if (!R.show) { if (R.bar) R.bar.s.visible = false; return; }
  const tt = play ? play.t : 0;
  if (R.path && play) {
    const P = R.path; let i = 0; while (i < P.length - 1 && tt > P[i + 1][0]) i++;
    if (tt <= P[0][0]) { R.pos.copy(P[0][1]); R.yaw = P[0][2]; R.run = P[0][3]; }
    else if (i >= P.length - 1) { R.pos.copy(P[P.length - 1][1]); R.yaw = P[P.length - 1][2]; R.run = 0; }
    else { const a = P[i], b = P[i + 1], u = (tt - a[0]) / (b[0] - a[0]); R.pos.lerpVectors(a[1], b[1], u); let dy = b[2] - a[2]; while (dy > Math.PI) dy -= 2 * Math.PI; while (dy < -Math.PI) dy += 2 * Math.PI; R.yaw = a[2] + dy * E.io(Math.min(1, u * 1.6)); R.run = a[3] + (b[3] - a[3]) * u; }
  }
  const slowK = R.slow > 0 ? 0.55 : 1;
  R.flinch = Math.max(0, R.flinch - dt * 2.6); R.flash = Math.max(0, R.flash - dt); R.push *= Math.pow(0.03, dt); R.slow = Math.max(0, R.slow - dt); R.heal = Math.max(0, (R.heal || 0) - dt); R.lunge = Math.max(0, (R.lunge || 0) - dt * 2.2);
  R.runPh += dt * 15 * R.run * slowK;
  const f = E.out(R.flinch), s = Math.sin(R.runPh), c = Math.cos(R.runPh), rn = R.run, l = Math.max(Math.sin(Math.min(1, R.lunge) * Math.PI), R.bite ? 0.85 : 0);
  const ct = clockT * slowK;
  R.rig.yaw = R.yaw; R.rig.pos.copy(R.pos).addScaledVector(R.pushDir, R.push);
  pose(R.rig, {RootJoint: [10 * f - 6 * rn - 14 * l, 0, R.side * 8 * f], Neck: [12 * f - 4 * rn - 22 * l, R.side * -18 * f + Math.sin(ct * 0.8) * 4 * (1 - f), 0], Head: [10 * f, 0, 0], Jaw: [R.bite ? -2 : -22 * f - 34 * l, 0, 0],
    ArmL: [-25 * f + 20 * l, 0, 0], ArmR: [-25 * f + 20 * l, 0, 0], Tail1: [-10 * f, Math.sin(ct * 1.3) * 4, 0], Tail2: [0, Math.sin(ct * 1.3 - .7) * 5, 0],
    LegL: [-8 * f + 34 * s * rn, 0, 0], LegR: [-8 * f - 34 * s * rn, 0, 0], KneeL: [-10 * f - (18 + 22 * Math.max(0, c)) * rn, 0, 0], KneeR: [-10 * f - (18 + 22 * Math.max(0, -c)) * rn, 0, 0]});
  if (R.rig.rest !== null) { R.rig.y = R.rig.rest + Math.abs(c) * 1.2 * rn; pose(R.rig, {}); }
  const g = R.slow > 0 ? 0.12 : 0, h = R.heal > 0 ? R.heal / 0.4 : 0, fl = R.flash > 0 ? 1 : 0;
  R.rig.mats.forEach(m => m.emissive.setRGB(fl * R.flashCol[0] + (1 - fl) * (g * 0.9 + h * 0.05), fl * R.flashCol[1] + (1 - fl) * (g * 0.55 + h * 0.55), fl * R.flashCol[2] + (1 - fl) * (h * 0.12)));
  if (R.bar) { R.bar.s.visible = !!R.hpShow; if (R.hpShow) { R.bar.set(R.hp, R.max || 60, R.plume || 0); R.bar.s.position.copy(rapChest(R)).add(V(0, 9.5, 0)); } }
}
function mechLocals() {
  for (const p of MECH) {
    const on = lookOn(p.look);
    let vis = on && (!p.show || p.show());
    let Lm;
    if (p.carry) { const c = p.carry; if (c.on) vis = false; const k = c.k === undefined ? 1 : c.k; if (k < 0.01) vis = false; Lm = segInv[p.seg].clone().multiply(c.F).multiply(scl(Math.max(0.001, k))).multiply(c.Fi).multiply(p.at); }
    else Lm = p.base.clone();
    if (p.part === "shed" && MK[p.look].shed.includes(p)) { if (MS.regrow < 0.01) vis = false; Lm.multiply(scl(Math.max(0.001, MS.regrow))); }
    if (p.anim) Lm.multiply(p.anim(p));
    p.local = Lm; p.mesh.visible = vis;
  }
}
const _feetC = new THREE.Vector3();
function walkLayer(target, w, ph) { if (w <= 0) return; const s = Math.sin(ph), c = Math.cos(ph);
  for (const [n, v] of [["LegL", 30 * s], ["LegR", -30 * s], ["KneeL", -(14 + 26 * Math.max(0, c))], ["KneeR", -(14 + 26 * Math.max(0, -c))], ["ArmL", 6 * s], ["ArmR", -6 * s], ["RootJoint", -4]]) target[n] = target[n].map((x, i) => i === 0 ? x + v * w : x); }

function step(dt, noRender) {
  let mdt = dt * speed;
  if (hitStop > 0) { hitStop -= mdt; mdt *= 0.05; }
  idleT += mdt; clockT += mdt;
  let target = idleLayer(idleT);
  const tr0 = play.track; play.t += mdt;
  const mv = sample(tr0.keys, play.t);
  target = addPose(mv, target, 1);
  if (tr0.tremble && play.t > tr0.tremble[0] && play.t < tr0.tremble[1]) for (const n of ["Neck", "Head", "RootJoint"]) target[n] = target[n].map((v, i) => v + (i === 2 ? Math.sin(clockT * 80 + n.length) * 1.6 : i === 0 ? Math.sin(clockT * 70) * 1.2 : 0));
  const rootFwd = (mv.root && mv.root.fwd) || 0;
  for (const e of (tr0.ev || [])) { const k = "e" + e.t + e.f.toString().length; if (!play.fired.has(k) && play.t >= e.t) { play.fired.add(k); e.f(); } }
  for (let i = delayed.length - 1; i >= 0; i--) if (play.t >= delayed[i].at) { const d = delayed[i]; delayed.splice(i, 1); d.f(); }
  if (tr0.update) tr0.update(play.t, mdt);
  for (const j of hero.joints) if (!target[j.n]) target[j.n] = [0, 0, 0];
  MS.walkPh += mdt * 11 * MS.walk; walkLayer(target, MS.walk, MS.walkPh);
  if (tr0.extra) tr0.extra(target);
  const P = springStep(target, mdt);
  for (let i = 0, n = Math.max(1, Math.ceil(mdt * 300)); i < n; i++) { const h = mdt / n; rootSpring.v += (400 * (rootFwd - rootSpring.x) - 2 * 0.9 * 20 * rootSpring.v) * h; rootSpring.x += rootSpring.v * h; }
  const m = tr0.move ? tr0.move(play.t) : {};
  hero.yaw = 0; hero.pos.set(m.x || 0, 0, (m.z || 0) - rootSpring.x);
  mechLocals();
  hero.y = 0; pose(hero, P);
  let minY = Infinity;
  for (const p of heroFeet) for (let i = 0; i < 8; i++) { _feetC.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(p.mesh.matrix); minY = Math.min(minY, _feetC.y); }
  hero.y = -minY + (m.up || 0); pose(hero, P);
  hero.g.visible = !(tr0.hide && tr0.hide(play.t));
  if (tr0.post) tr0.post(play.t);
  const eyes = inWin(tr0.eyes, play.t) ? 1 : 0; heroGlow.e += (eyes - heroGlow.e) * Math.min(1, dt * 14);
  if (eyeMat) eyeMat.emissive.setRGB(0.85 * heroGlow.e, 0.42 * heroGlow.e, 0.02 * heroGlow.e);
  heroHeal = Math.max(0, heroHeal - mdt); const hh = heroHeal / 0.45;
  hero.mats.forEach(mm => { if (mm !== eyeMat) mm.emissive.setRGB(0.02 * hh, 0.4 * hh, 0.08 * hh); });
  raps.forEach(R => rapPose(R, mdt));
  allyRing.visible = allyTag.visible = S.show; allyRing2.visible = allyTag2.visible = S2.show;
  if (S.show) { allyRing.position.set(S.rig.pos.x, 0.13, S.rig.pos.z); allyTag.position.copy(rapChest(S)).add(V(0, S.hpShow ? 12.5 : 10, 0)); }
  if (S2.show) { allyRing2.position.set(S2.rig.pos.x, 0.13, S2.rig.pos.z); allyTag2.position.copy(rapChest(S2)).add(V(0, S2.hpShow ? 12.5 : 10, 0)); }
  heroBar.s.visible = !!heroBar.on && hero.g.visible; if (heroBar.on) { heroBar.set(hero.hp, hero.max, hero.plume || 0); heroBar.s.position.copy(partPoint(mouthParts.skull)).add(V(0, 6, 0)); }
  updatePods(mdt); updateZones(mdt); updateFlies(mdt);
  for (const k in PMAT) { const mt = PMAT[k], g = PGLOW[mt.userData.part] || 0; mt.emissive.setHex(mt.userData.base); mt.emissiveIntensity = g < 0 ? Math.max(0.05, 1 + g) : 1 + g * 1.4 * (0.8 + 0.2 * Math.sin(clockT * 12)); }
  for (let i = fx.length - 1; i >= 0; i--) { const e = fx[i]; const fdt = dt * speed * (hitStop > 0 ? 0.2 : 1); e.t += fdt; const u = Math.min(1, e.t / e.life); e.update(e.obj, u, fdt); if (u >= 1) { scene.remove(e.obj); fx.splice(i, 1); } }
  if (noRender) return;
  render(dt);
}
const heroGlow = {e: 0};
// ShoulderCam 1.8 framing for the troodon at the 2x body: distance = CameraStartZoom 35 x 2 = 70 studs (zoom 1), pitch -12 deg
// (ShoulderCamPitchStart), right shoulder: side = max(0.6 x width, 0.9 x top + 1), height = 0.35 x top, focus = 0.75 x top
// above the root (top = model top above the HumanoidRootPart, measured from the rest pose); Roblox's default FOV 70.
const CAMF = (() => { let top = -Infinity, w0 = Infinity, w1 = -Infinity; for (const b of BODY) for (let i = 0; i < 8; i++) { const q = V((i & 1 ? .5 : -.5) * b.h[0] * 2, (i & 2 ? .5 : -.5) * b.h[1] * 2, (i & 4 ? .5 : -.5) * b.h[2] * 2).applyMatrix4(b.m); top = Math.max(top, q.y); w0 = Math.min(w0, q.x); w1 = Math.max(w1, q.x); }
  top *= 2; const width = (w1 - w0) * 2; return {top, side: Math.max(0.6 * width, 0.9 * top + 1), height: 0.35 * top, focus: 0.75 * top, dist: 70, pitch: rad(12)}; })();
const camPos = new THREE.Vector3(60, 26, -20), camLook = new THREE.Vector3(0, 9, -20);
function partCentre() {
  const c = new THREE.Vector3(); let n = 0;
  for (const p of MECH) if (p.mesh.visible && !p.bracket) { c.add(_pa.setFromMatrixPosition(p.mesh.matrix)); n++; }
  return n ? c.divideScalar(n) : partPoint(hero.segs.Torso[2]);
}
function render(dt) {
  const tr0 = play.track;
  shake = Math.max(0, shake - dt * 4.2); fovPunch = Math.max(0, fovPunch - dt * 14);
  const fr = tr0.frame; const mid = fr[0].clone().lerp(fr[1], 0.5).setY(8), span = fr[0].distanceTo(fr[1]) + 30;
  let fov = 38, cp, look = mid, snap = 0.15;
  const hfov = 2 * Math.atan(Math.tan(rad(fov / 2)) * cam.aspect), vfit = span * 0.5 / Math.tan(Math.min(hfov, rad(fov)) / 2);
  if (camMode === "game") { fov = 70; const f = heroHRP().add(V(0, CAMF.focus, 0)); const back = V(0, Math.sin(CAMF.pitch), Math.cos(CAMF.pitch)).multiplyScalar(CAMF.dist);
    cp = f.clone().add(V(CAMF.side, CAMF.height, 0)).add(back); look = cp.clone().sub(back); snap = 0.25; }
  else if (camMode === "hero") cp = mid.clone().add(V(1, 0.5, -0.6).normalize().multiplyScalar(vfit * 1.0));
  else if (camMode === "side") cp = mid.clone().add(V(1, 0.14, 0).normalize().multiplyScalar(vfit * 1.05));
  else if (camMode === "top") { cp = mid.clone().add(V(0.12, 1, 0.3).normalize().multiplyScalar(vfit * 0.95)); }
  else { const c = M().id === "all" ? partPoint(hero.segs.Torso[0]).add(V(0, 1, 0)) : partCentre(); const d = M().id === "all" ? 34 : 17; cp = c.clone().add(V(0.78, 0.42, -0.46).normalize().multiplyScalar(d)); look = c; snap = 0.3; }
  camPos.lerp(cp, snap); camLook.lerp(look, snap + 0.05);
  const sh = shake * shake;
  cam.position.copy(camPos).add(V((Math.random() - .5) * sh, (Math.random() - .5) * sh, (Math.random() - .5) * sh));
  cam.lookAt(camLook); cam.fov = fov + fovPunch; cam.updateProjectionMatrix();
  sun.position.copy(mid).add(V(30, 70, 30)); sun.target.position.copy(mid);
  renderer.render(scene, cam);
}
function seek(t) { start(); const sp = speed; speed = 1; let n = 0; while (play.t < t - 1e-6 && n < 3000) { step(1 / 60, true); n++; } speed = sp; camSnap(); step(0); }
function camSnap() { for (let i = 0; i < 40; i++) render(0); }
const LEN = () => play.track.len;

// ---------- measurement (125-point sample per piece; window.__troo.measure) ----------
// Each piece's shape (box / cylinder / sphere / torus) is sampled at 125 points spread through its volume (5 x 5 x 5 cells;
// a cylinder's cross-section is the square grid mapped onto the disc; a torus: 25 spots round the ring x 5 across the tube).
// Inside the body = inside any visible Troodon body box (the 188 parts, feathers included). Brackets are listed apart.
function concentric(u, v) { if (u === 0 && v === 0) return [0, 0]; let r, f; if (Math.abs(u) > Math.abs(v)) { r = u; f = Math.PI / 4 * (v / u); } else { r = v; f = Math.PI / 2 - Math.PI / 4 * (u / v); } return [r * Math.cos(f), r * Math.sin(f)]; }
function canon(sh, edge) {
  const out = [], N = 5, g = i => edge ? i / (N - 1) - 0.5 : (i + 0.5) / N - 0.5;
  if (sh.t === "box") { for (let i = 0; i < N; i++) for (let j = 0; j < N; j++) for (let k = 0; k < N; k++) out.push(V(g(i) * sh.w, g(j) * sh.h, g(k) * sh.d)); }
  else if (sh.t === "cyl") { for (let k = 0; k < N; k++) { const y = g(k) * sh.h, r = sh.r2 + (sh.r1 - sh.r2) * (y / sh.h + 0.5); for (let i = 0; i < N; i++) for (let j = 0; j < N; j++) { const [a, b] = concentric(2 * g(i), 2 * g(j)); out.push(V(a * r, y, b * r)); } } }
  else if (sh.t === "sph") { for (let i = 0; i < N; i++) for (let j = 0; j < N; j++) for (let k = 0; k < N; k++) { const p = V(2 * g(i), 2 * g(j), 2 * g(k)); const m = Math.max(Math.abs(p.x), Math.abs(p.y), Math.abs(p.z)), l = p.length(); out.push(l < 1e-9 ? p : p.multiplyScalar(m / l * sh.r)); } }
  else if (sh.t === "tor") { const cs = edge ? [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]] : [[0, 0], [0.6, 0], [-0.6, 0], [0, 0.6], [0, -0.6]]; for (let a = 0; a < 25; a++) { const t = sh.arc < 6.28 ? (a + 0.5) / 25 * sh.arc : a / 25 * Math.PI * 2; for (const [dx, dz] of cs) out.push(V(Math.cos(t) * (sh.R + dx * sh.r), Math.sin(t) * (sh.R + dx * sh.r), dz * sh.r)); } }
  return out;
}
function insideShape(sh, q, m) {
  if (sh.t === "box") return Math.abs(q.x) <= sh.w / 2 + m && Math.abs(q.y) <= sh.h / 2 + m && Math.abs(q.z) <= sh.d / 2 + m;
  if (sh.t === "cyl") { if (Math.abs(q.y) > sh.h / 2 + m) return false; const r = sh.r2 + (sh.r1 - sh.r2) * clamp01(q.y / sh.h + 0.5); return Math.hypot(q.x, q.z) <= r + m; }
  if (sh.t === "sph") return q.length() <= sh.r + m;
  if (sh.t === "tor") { if (sh.arc < 6.28) { let an = Math.atan2(q.y, q.x); if (an < 0) an += Math.PI * 2; if (an > sh.arc) return false; } const d = Math.hypot(q.x, q.y) - sh.R; return d * d + q.z * q.z <= (sh.r + m) * (sh.r + m); }
  return false;
}
const SAMP = new Map();
function samplesOf(geo) { let s = SAMP.get(geo.uuid); if (s) return s; const sh = geo.userData.shape, M0 = geo.userData.M;
  const c = canon(sh, false).map(v => v.applyMatrix4(M0)), e = canon(sh, true).map(v => v.applyMatrix4(M0)); const ctr = new THREE.Vector3(); e.forEach(v => ctr.add(v)); ctr.divideScalar(e.length);
  let rad0 = 0; e.forEach(v => { rad0 = Math.max(rad0, v.distanceTo(ctr)); }); s = {c, e, ctr, rad: rad0}; SAMP.set(geo.uuid, s); return s; }
function bodyNow() { return hero.parts.filter(p => p.kind !== "mech" && p.mesh.visible).map(p => ({inv: p.mesh.matrix.clone().invert(), h: p.size.map(v => v / 2), c: V(0, 0, 0).applyMatrix4(p.mesh.matrix), r: Math.hypot(...p.size) + 0.1, name: p.name})); }
function pieceNow(p) { const s = samplesOf(p.mesh.geometry); const W = p.mesh.matrix.clone().multiply(p.mesh.geometry.userData.M); return {p, s, W, Wi: W.clone().invert(), c: s.ctr.clone().applyMatrix4(p.mesh.matrix), r: s.rad * 2 + 0.1}; }
const _q = new THREE.Vector3();
function shareInBody(pn, body) {
  const near = body.filter(b => b.c.distanceTo(pn.c) < b.r + pn.r); if (!near.length) return 0; let n = 0;
  for (const v of pn.s.c) { const w = v.clone().applyMatrix4(pn.p.mesh.matrix); for (const b of near) { _q.copy(w).applyMatrix4(b.inv); if (Math.abs(_q.x) <= b.h[0] && Math.abs(_q.y) <= b.h[1] && Math.abs(_q.z) <= b.h[2]) { n++; break; } } }
  return n / pn.s.c.length;
}
function shareInPieces(pn, others) {
  const near = others.filter(o => o.c.distanceTo(pn.c) < o.r + pn.r); if (!near.length) return 0; let n = 0;
  for (const v of pn.s.c) { const w = v.clone().applyMatrix4(pn.p.mesh.matrix); for (const o of near) { _q.copy(w).applyMatrix4(o.Wi); if (insideShape(o.p.mesh.geometry.userData.shape, _q, 0)) { n++; break; } } }
  return n / pn.s.c.length;
}
function floating(look) { // pieces not connected (through touching pieces of the same look) to the body; margin 0.06 studs
  const ps = MECH.filter(p => p.look === look && p.mesh.visible).map(pieceNow), body = bodyNow(), m = 0.03;
  const touchBody = pn => pn.s.e.some(v => { const w = v.clone().applyMatrix4(pn.p.mesh.matrix); return body.some(b => { _q.copy(w).applyMatrix4(b.inv); return Math.abs(_q.x) <= b.h[0] + m && Math.abs(_q.y) <= b.h[1] + m && Math.abs(_q.z) <= b.h[2] + m; }); });
  const touch = (a, b) => a.s.e.some(v => { _q.copy(v).applyMatrix4(a.p.mesh.matrix).applyMatrix4(b.Wi); return insideShape(b.p.mesh.geometry.userData.shape, _q, m); }) || b.s.e.some(v => { _q.copy(v).applyMatrix4(b.p.mesh.matrix).applyMatrix4(a.Wi); return insideShape(a.p.mesh.geometry.userData.shape, _q, m); });
  const ok = new Set(ps.filter(touchBody)); let grew = true;
  while (grew) { grew = false; for (const a of ps) if (!ok.has(a)) for (const b of ok) if (a.c.distanceTo(b.c) < a.r + b.r && touch(a, b)) { ok.add(a); grew = true; break; } }
  return ps.filter(a => !ok.has(a)).map(a => a.p.name + "#" + MECH.indexOf(a.p));
}
function runTrack(id, L, each, dtS) { // play part id with look L from 0 to its end, calling each(t) every dtS (no rendering)
  cur = MOVES.findIndex(m => m.id === id); variant = L; start(); const len = LEN(); let nextT = 0;
  while (play.t < len) { step(1 / 60, true); if (play.t >= nextT) { nextT += dtS; each(play.t); } } }
const pct = x => Math.round(x * 1000) / 10;
function measureAll() {
  const out = {version: ANIM_VERSION, when: new Date().toISOString().slice(0, 16), looks: {}, rec: {}, any: {}, busy: []};
  const save = {cur, variant, lookOverride, speed}; speed = 1;
  for (const id of PIDS) for (const L of ["A", "B", "C"]) {
    const look = id + "." + L; lookOverride = new Set([look]);
    const r = {idle: 0, move: 0, idleWorst: "", moveWorst: "", bracketIdle: 0, bracketMove: 0, pieces: 0, brackets: 0, floating: []};
    let T0 = 0.6, flDone = false;
    runTrack(id, L, t => { const body = bodyNow(); const idle = t < T0 - 0.02;
      for (const p of MECH) { if (p.look !== look || !p.mesh.visible) continue; const s = shareInBody(pieceNow(p), body), key = p.bracket ? (idle ? "bracketIdle" : "bracketMove") : (idle ? "idle" : "move");
        if (s > r[key]) { r[key] = s; if (!p.bracket) r[idle ? "idleWorst" : "moveWorst"] = p.name + " " + pct(s) + "% at " + t.toFixed(2) + " s"; } }
      if (!flDone && t > 0.3) { flDone = true; r.floating = floating(look); r.pieces = MECH.filter(p => p.look === look && !p.bracket).length; r.brackets = MECH.filter(p => p.look === look && p.bracket).length; } }, 0.05);
    lookOverride = new Set([look]); cur = MOVES.findIndex(m => m.id === "all"); variant = "R"; start(); r.kit = 0; r.kitWorst = "";
    while (play.t < LEN()) { step(1 / 60, true); const body = bodyNow(); for (const p of MECH) { if (p.look !== look || !p.mesh.visible || p.bracket) continue; const s = shareInBody(pieceNow(p), body); if (s > r.kit) { r.kit = s; r.kitWorst = p.name + " " + pct(s) + "% at " + play.t.toFixed(2) + " s"; } } }
    ["idle", "move", "kit", "bracketIdle", "bracketMove"].forEach(k => { r[k] = pct(r[k]); });
    out.looks[look] = r;
  }
  // clash, recommended set: every part's move played with all 9 recommended looks on
  const recSet = new Set(PIDS.map(p => p + "." + REC[p])); const pairMax = {};
  const clashFrame = (set, rec) => { const ps = MECH.filter(p => set.has(p.look) && p.mesh.visible).map(pieceNow);
    for (const a of ps) { const others = ps.filter(b => b.p.part !== a.p.part); const s = shareInPieces(a, others); if (s > 0) { for (const b of others) { if (shareInPieces(a, [b]) > 0) { const k = [a.p.look, b.p.look].sort().join(" × "); rec[k] = Math.max(rec[k] || 0, s); } } } } };
  for (const id of PIDS) { lookOverride = recSet; runTrack(id, REC[id], () => clashFrame(recSet, pairMax), 0.05); }
  lookOverride = recSet; cur = MOVES.findIndex(m => m.id === "all"); variant = "R"; start(); while (play.t < LEN()) { step(1 / 60, true); clashFrame(recSet, pairMax); }
  out.rec = Object.fromEntries(Object.entries(pairMax).map(([k, v]) => [k, pct(v)]));
  // any mix: each look's move played with every look of every other part on (a superset of every 4-part combo)
  const all = new Set(MECH.map(p => p.look)); const anyMax = {};
  for (const id of PIDS) for (const L of ["A", "B", "C"]) { const set = new Set([...all].filter(l => !l.startsWith(id + ".") || l === id + "." + L)); lookOverride = set; runTrack(id, L, () => clashFrame(set, anyMax), 0.1); }
  out.any = Object.fromEntries(Object.entries(anyMax).map(([k, v]) => [k, pct(v)]).filter(([k, v]) => v > 0));
  // busiest 4-part combos of the recommended set: most neighbouring pairs (pieces within 0.6 studs of each other at rest)
  lookOverride = recSet; cur = MOVES.findIndex(m => m.id === "all"); variant = "R"; start(); for (let i = 0; i < 30; i++) step(1 / 60, true);
  const ps = MECH.filter(p => recSet.has(p.look) && p.mesh.visible).map(pieceNow); const gap = {};
  for (const a of ps) for (const b of ps) if (a.p.part < b.p.part) { let d = Infinity; for (const v of a.s.e) { const w = v.clone().applyMatrix4(a.p.mesh.matrix); for (const u of b.s.e) d = Math.min(d, w.distanceTo(_pb.copy(u).applyMatrix4(b.p.mesh.matrix))); } const k = a.p.part + "|" + b.p.part; gap[k] = Math.min(gap[k] === undefined ? Infinity : gap[k], d); }
  out.gaps = Object.fromEntries(Object.entries(gap).map(([k, v]) => [k, Math.round(v * 100) / 100]));
  const combos = []; const ids = PIDS;
  for (let a = 0; a < 9; a++) for (let b = a + 1; b < 9; b++) for (let c = b + 1; c < 9; c++) for (let d = c + 1; d < 9; d++) { const set = [ids[a], ids[b], ids[c], ids[d]]; let score = 0, minGap = Infinity, worst = 0;
    for (let i = 0; i < 4; i++) for (let j = i + 1; j < 4; j++) { const k = [set[i], set[j]].sort().join("|"); const g = gap[k] === undefined ? Infinity : gap[k]; minGap = Math.min(minGap, g); if (g < 1.5) score += 1.5 - g;
      const pk = [set[i] + "." + REC[set[i]], set[j] + "." + REC[set[j]]].sort().join(" × "); worst = Math.max(worst, out.rec[pk] || 0); }
    combos.push({parts: set, score: Math.round(score * 100) / 100, minGap: Math.round(minGap * 100) / 100, clash: worst}); }
  combos.sort((x, y) => y.score - x.score); out.busy = combos.slice(0, 4);
  lookOverride = save.lookOverride; cur = save.cur; variant = save.variant; speed = save.speed; renderAll(); start();
  return out;
}

// ---------- UI ----------
const VARS = () => M().id === "all" ? ["R", "A", "B", "C"] : ["A", "B", "C"];
const NAME = id => MOVES.find(m => m.id === id).name;
function fitLine(look) {
  if (!MEAS || !MEAS.looks[look]) return '<p class="note">Fit not measured in this build.</p>';
  const r = MEAS.looks[look], ok = r.idle <= 5 && r.move <= 5 && !r.floating.length;
  const clashes = Object.entries(MEAS.any || {}).filter(([k]) => k.split(" × ").includes(look)).map(([k, v]) => k.split(" × ").find(x => x !== look) + " " + v + "%");
  return `<h3>Fit (measured)</h3><table class="cmp"><tr><th>Inside the body, worst piece</th><td class="n"><span class="${r.idle <= 5 ? "ok" : "badn"}">${r.idle}%</span> idle · <span class="${r.move <= 5 ? "ok" : "badn"}">${r.move}%</span> in its move</td></tr>
    <tr><th>Worst piece in the move</th><td>${r.moveWorst || "none inside"}</td></tr><tr><th>Pieces / brackets</th><td class="n">${r.pieces} / ${r.brackets} (brackets ${r.bracketIdle}% · ${r.bracketMove}% in the body: set into the surface on purpose)</td></tr>
    <tr><th>Floating pieces</th><td>${r.floating.length ? '<span class="badn">' + r.floating.join(", ") + "</span>" : '<span class="ok">none</span>'}</td></tr>
    <tr><th>Clips another part's look</th><td>${clashes.length ? '<span class="badn">' + clashes.join(", ") + "</span> (don't slot those together)" : '<span class="ok">no look of any other part, in any move</span>'}</td></tr></table>
    <p class="note">${ok ? "Passes the ≤ 5% rule." : "Over the 5% rule."} Measured ${MEAS.when} UTC, page v${MEAS.version}.</p>`;
}
function renderAll() {
  const id = M().id, LS = LOOKS[id];
  $("moves").innerHTML = MOVES.map((m, i) => `<button class="tab" data-i="${i}" aria-pressed="${i === cur}">${m.code ? m.code + " · " : ""}${m.name}<small style="color:${AREA[m.area][1]}">${AREA[m.area][0]} · ${m.kind}</small></button>`).join("");
  $("varRow").innerHTML = '<span class="lbl">Look</span>' + VARS().map(k => `<button class="var" data-var="${k}" aria-pressed="${k === variant}">${LS[k].name}${id !== "all" && REC[id] === k ? '<span class="rec">Recommended</span>' : ""}<small>${LS[k].sub}</small></button>`).join("");
  $("allRow").hidden = id !== "all";
  if (id === "all") $("allRow").innerHTML = '<span class="lbl">Slotted</span>' + PIDS.map(p => `<button class="chip" data-chip="${p}" aria-pressed="${allOn[p]}">${NAME(p)}</button>`).join("") + (MEAS && MEAS.busy ? '<span class="lbl" style="margin-left:6px">Busiest 4</span>' + MEAS.busy.slice(0, 3).map((b, i) => `<button class="chip" data-busy="${i}">#${i + 1}</button>`).join("") : "") + '<button class="chip" data-chip="*">all 9</button>';
  const ph = play ? play.track.phases : [];
  $("phases").innerHTML = ph.map(p => `<button class="ph" data-t="${p[0]}" aria-current="false"><i>${p[0].toFixed(2)}–${p[1].toFixed(2)} s</i>${p[2]}</button>`).join("");
  const AR = AREA[M().area];
  if (id === "all") {
    const rows = PIDS.map(p => { const k = variant === "R" ? REC[p] : variant; return `<tr><th>${NAME(p)}${allOn[p] ? "" : " (off)"}</th><td>${LOOKS[p][k].name} · ${LOOKS[p][k].mount}</td></tr>`; }).join("");
    $("info").innerHTML = `<div class="kind" style="color:${AR[1]}">Clash check · ${LS[variant].name}</div><h2>Every chosen part on at once</h2><p class="note">A player slots 4 of the 9; this shows all 9 (or the ones ticked) so every 4-part mix is covered. It cycles idle → pod throw → glide → one-arm wind-up, the poses that move the arms and neck most.</p><div class="tw"><table class="cmp">${rows}</table></div>`;
    let m = '<div class="kind">Measured clashes</div>';
    if (MEAS) { const recP = Object.entries(MEAS.rec || {}).filter(([, v]) => v > 0);
      m += `<p><b>Recommended set, all 9 on, every part's move + these poses:</b> ${recP.length ? '<span class="badn">' + recP.map(([k, v]) => k + " " + v + "%").join(", ") + "</span>" : '<span class="ok">no piece of one part inside a piece of another (0%)</span>'}.</p>`;
      m += `<p><b>Busiest 4-part combos</b> (recommended looks closest together; gap = nearest pieces at rest):</p><ul>${MEAS.busy.slice(0, 3).map((b, i) => `<li>#${i + 1} ${b.parts.map(NAME).join(" + ")}: closest gap ${b.minGap} studs, clash ${b.clash}%</li>`).join("")}</ul>`;
      const any = Object.entries(MEAS.any || {}); m += `<p><b>Any mix</b> (every look of every part on, each look's move played): ${any.length ? any.length + " look pairs clip: " + any.map(([k, v]) => k + " " + v + "%").join(", ") + ". Every one of these is two non-recommended looks, or noted on the look's card." : '<span class="ok">no two looks of different parts clip.</span>'}</p>`; }
    else m += '<p class="note">Not measured in this build.</p>';
    $("part").innerHTML = m; return;
  }
  const N = NUMS[id], v = LS[variant], mv = M();
  $("info").innerHTML = `<div class="kind" style="color:${AR[1]}">${mv.code} · ${AR[0]} · ${mv.kind}${mv.kind === "Always on" ? " (takes a slot)" : ""}</div><h2>${mv.name}</h2><p>${N.max}</p>
    <h3>Steps (proposed)</h3><div class="tw"><table class="cmp">${["I", "II", "III", "★"].map((s, i) => `<tr><th>${s}</th><td>${N.steps[i]}</td></tr>`).join("")}</table></div><p class="note">35% rule: ${N.check}.</p>
    <h3>Trade-off</h3><p>${N.trade}</p><h3>Design idea it borrows</h3><p>${N.design}</p><h3>VFX, in Roblox pieces</h3><p class="note">${N.roblox}</p><p class="note"><b>Follows:</b> ${N.follows}</p>`;
  const rk = REC[id];
  $("part").innerHTML = `<div class="kind" style="color:${AR[1]}">${v.name} · where it sits</div><p>${v.mount}</p><ul>${v.notes.map(n => `<li>${n}</li>`).join("")}</ul><p class="note"><b>Recommended: ${LS[rk].name}.</b> ${LS[rk].rec}</p>
    <h3>What you see, in order</h3><ul>${ph.map(p => `<li>${p[2]}</li>`).join("")}</ul>${fitLine(id + "." + variant)}`;
}
function foot() {
  $("foot").innerHTML = `<b>Notes</b><ol>
  <li><b>Readability research, applied.</b> Riot's "Clarity in League": one defining primary shape per champion, readable in silhouette; an effect's attention should match its importance; projectiles show their direction; telegraphs match the hit area (<a href="https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/">leagueoflegends.com</a>). Capcom on Monster Hunter Rise: Sunbreak gear: build gear from the creature's own features, openings in a silhouette make it read lighter, keep the signature colour clear (<a href="https://news.capcomusa.com/2023/01/12/forging-the-gear-of-monster-hunter-rise-sunbreak">news.capcomusa.com</a>). TF2 vs Overwatch art direction: big shapes and areas of visual rest read at range, small noisy detail doesn't (<a href="https://80.lv/articles/comparing-team-fortress-2-and-overwatch-art-direction">80.lv</a>). So: each look is 1–3 big shapes plus brackets (no greebles), one accent colour per job (heal green, zone teal, sap amber, shock cyan, plume gold), always-on parts stay dim until they trigger, and every look was checked from the game camera.</li>
  <li><b>Inspiration only.</b> The design ideas named on each card (Mercy / Lifeline drones, chain lightning, Mei / Catalyst walls, Wraith / Bard portals, Baptiste, Brigitte, Junkrat…) are the mechanic's idea; no shape, texture or colour scheme is copied.</li>
  <li><b>VFX consistency.</b> Heals use the Med-Station's green waves and "+N" pops (MedStationServer, TrooFX); everything thrown uses the Glow Pod's arc, embers and splat (TrooFX); zones are the troodon's teal (TrooFX); shock is the raptor Shock Mine's cyan with re-drawn arcs and a neon burst (MineServer); immune / untouchable shells are the Energy Shield dome (EnergyShieldServer); rings and shockwaves follow TenoMovesFX's flat neon rings; feathers follow TheriMovesFX's blades; the escape glide is the troodon's own Flap & Glide. No landing FX anywhere.</li>
  <li><b>Fit measurement.</b> Each piece's shape (box / cylinder / sphere / torus) is sampled at 125 points spread through its volume; a point counts as inside when it lies in any visible Troodon body box (all 188 parts, feathers included). Idle = every 0.05 s of the slotted idle; move = every 0.05 s of the move. Brackets (flat mount plates and clamps) are reported apart: they are set into the surface by 40% of their thickness on purpose. Floating = a piece that doesn't touch the body or another piece of its look (0.06-stud margin). Clashes: every piece's 125 points tested against the other parts' pieces, every 0.05 s of every part's move with all 9 recommended looks on, and every 0.1 s with every look of every part on (any mix). Source: tools/mockup/troodon_parts_looks.js (window.__troo.measure), run by tools/mockup/measure_troodon_parts.js.</li>
  <li><b>Game camera</b> = ShoulderCam 1.8's default framing for the troodon at the 2x body: 70 studs back (CameraStartZoom 35 x 2), 12° down, right shoulder, Roblox's default 70° field of view. Close = 17 studs from the part.</li>
  <li><b>Numbers</b> are proposals for the plan; the moves play the ★ step. Distances are studs at the 2x body. Zone, pod and heal numbers are the live kit's (TroodonModelData 1.4).</li></ol>`;
}
$("moves").addEventListener("click", e => { const b = e.target.closest("[data-i]"); if (!b) return; cur = +b.dataset.i; variant = M().id === "all" ? "R" : REC[M().id]; start(); renderAll(); });
$("varRow").addEventListener("click", e => { const b = e.target.closest("[data-var]"); if (!b) return; variant = b.dataset.var; start(); renderAll(); });
$("allRow").addEventListener("click", e => { const b = e.target.closest("[data-chip],[data-busy]"); if (!b) return;
  if (b.dataset.busy !== undefined) { const set = MEAS.busy[+b.dataset.busy].parts; PIDS.forEach(p => { allOn[p] = set.includes(p); }); }
  else if (b.dataset.chip === "*") PIDS.forEach(p => { allOn[p] = true; }); else allOn[b.dataset.chip] = !allOn[b.dataset.chip]; renderAll(); });
$("phases").addEventListener("click", e => { const b = e.target.closest("[data-t]"); if (!b) return; seek(+b.dataset.t + 0.06); playing = false; syncPlay(); });
$("play").onclick = () => { playing = !playing; syncPlay(); };
$("again").onclick = () => { start(); playing = true; syncPlay(); };
function syncPlay() { $("play").textContent = playing ? "Pause" : "Play"; $("play").setAttribute("aria-pressed", playing); }
document.querySelectorAll("[data-speed]").forEach(b => b.onclick = () => { speed = +b.dataset.speed; document.querySelectorAll("[data-speed]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
const CAMNAME = {game: "Game camera (ShoulderCam, 70 studs)", hero: "3/4", side: "Side (+X)", top: "Top", part: "Close"};
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => { camMode = b.dataset.view; document.querySelectorAll("[data-view]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
$("scrub").addEventListener("input", e => { seek(+e.target.value / 1000 * LEN()); playing = false; syncPlay(); });
const THEMES = ["auto", "light", "dark"]; let themeI = 0;
$("theme").onclick = () => { themeI = (themeI + 1) % 3; const t = THEMES[themeI]; if (t === "auto") document.documentElement.removeAttribute("data-theme"); else document.documentElement.setAttribute("data-theme", t); $("theme").textContent = "Theme: " + t; };
$("ver").textContent = "v" + ANIM_VERSION;
function resize() { const w = cv.clientWidth, h = cv.clientHeight; if (renderer.domElement.width !== Math.round(w * renderer.getPixelRatio())) { renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); } }
window.addEventListener("resize", resize);
let last = performance.now();
function loop(now) {
  const dt = Math.min(0.05, (now - last) / 1000); last = now;
  resize();
  if (!window.__manual) { if (playing) { step(dt); if (play.t >= LEN()) start(); } else step(0); }
  $("scrub").value = Math.round(Math.min(1, play.t / LEN()) * 1000);
  $("clock").textContent = `${play.t.toFixed(2)} s${speed !== 1 ? " · 0.3×" : ""}`; $("camtag").textContent = CAMNAME[camMode];
  const ph = play.track.phases.find(p => play.t >= p[0] && play.t < p[1]);
  $("cap").textContent = ph ? ph[2] : "…";
  document.querySelectorAll(".ph").forEach(b => b.setAttribute("aria-current", !!ph && +b.dataset.t === ph[0]));
  requestAnimationFrame(loop);
}
start(); renderAll(); foot(); resize();
requestAnimationFrame(loop);
// test hooks: __troo.set(part, look, t, cam) seeks there and pauses; __troo.measure() returns the fit / clash numbers
window.__troo = {set(id, v, time, cm) { window.__manual = true; cur = MOVES.findIndex(m => m.id === id); variant = v; if (cm) camMode = cm; start(); renderAll(); seek(time); },
  measure: () => { window.__manual = true; return measureAll(); }, len: () => LEN(), cap: () => $("cap").textContent, state: () => ({t: play.t, fx: fx.length, vis: MECH.filter(p => p.mesh.visible).length})};
window.__ready = true;
