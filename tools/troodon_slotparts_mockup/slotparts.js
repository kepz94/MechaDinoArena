// troodon_slotparts.js v0.1 (Mecha Dino Arena) — Troodon SLOT parts mockup (Kepu 2026-11-10 01:33 "Bloom Tank for sure" + "We
// need to look at the actual mecha slots"; 01:40 picks from the 20-idea list: 1 Bloom Burst, 3 Shield Dome, 7 Sleep Dart,
// 14 Sentry Pod). The page shows the locked passive (Bloom Tank: no button, no slot) + the 4 picked buttons (each takes a slot).
// Derived from tools/troodon_newparts_mockup/newparts.js v0.1 (Bloom Tank, Bloom Burst and every helper / track kept as they
// were); new here: Shield Dome, Sleep Dart, Sentry Pod looks + tracks, the CFG / CANDS / UI texts. Same pipeline: engine =
// tools/troodon_kit_mockup/engine_part.js + app_tail.js up to "tracks"; tools/mockup/troodon_parts_looks.js up to "extra key
// poses"; then this file. Build: python3 tools/troodon_slotparts_mockup/build.py <three.min.js r128>. Fit: window.__np.measure()
// (measure.js writes measure.json, baked in by the build). Every move: wind-up -> action -> result -> recovery; no landing FX.
const NP_VERSION = "0.1";

// ---------- new-part state ----------
const NS = {};
function nsReset() { Object.assign(NS, {fill: 1, jetTilt: 0, fan: 0, bud: 1, petal: 0, domeGlow: 0, sentLeg: 0, sentYaw: 0, sentFire: 0, sleepKick: 0, walk: 0, walkPh: 0, run: 0, runPh: 0, hud: null}); }
nsReset();
const rotAbout = (at, c, Rm) => at.clone().invert().multiply(T3(c.x, c.y, c.z)).multiply(Rm).multiply(T3(-c.x, -c.y, -c.z)).multiply(at);
const fmt = n => (Math.abs(n - Math.round(n)) < 1e-6 ? String(Math.round(n)) : String(Number(n.toFixed(2))));
const NK = {}; // named points per new look (model space, scale 1)
const LIVE = ["mender.A", "lantern.A", "sapwall.B", "shed.A", "portal.A"]; // the 5 live button looks (TrooPartsLooks 1.0)
GLOWDEF.blue = [0xcfe8ff, 0x2f78d0]; GLOWDEF.violet = [0xe2ccff, 0x7a3ad0];
const DOME_BLUE = 0x6cc4ff, SLEEP_V = 0xb88cff;

// ===== Bloom Tank (passive · the zone; LOCKED by Kepu 01:33): unchanged from newparts.js v0.1 N2 =====
(() => {
  const lk = "bloom.A";
  for (const z of [1.1, 1.68]) { for (const s of [1, -1]) { const h = topHit(0.14 * s, z, onSeg("Tail1")); const F = bracket(lk, "Tail1", h, 0.1, 0.18, 0.05);
      const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Tail1", G.box(0.07, 0.86 - y0, 0.12), MAT.gun, T3(0.14 * s, (y0 + 0.86) / 2, z)); }
    piece(lk, "Tail1", G.box(0.44, 0.05, 0.16), MAT.gun, T3(0, 0.885, z));
    piece(lk, "Tail1", G.tor(0.29, 0.035, Math.PI), MAT.brass, T3(0, 1.17, z).multiply(rotZ(Math.PI))); }
  const C = V(0, 1.17, 1.39); NK.bloomC = C;
  piece(lk, "Tail1", G.cylZ(0.27, 0.27, 0.66), lam(0x9ff6e8, {emissive: 0x0c6a5c, transparent: true, opacity: 0.42}), T3(C.x, C.y, C.z));
  piece(lk, "Tail1", G.cylZ(0.23, 0.23, 0.6), gm("bloom", "teal"), T3(C.x, C.y, C.z), {anim: () => T3(0, -0.23 * (1 - NS.fill), 0).multiply(scl(1, Math.max(0.05, NS.fill), 1))});
  for (const e of [1, -1]) piece(lk, "Tail1", G.sph(0.27, 1, 1, 0.42), MAT.gun, T3(C.x, C.y, C.z + 0.33 * e));
  for (const dz of [-0.17, 0.17]) piece(lk, "Tail1", G.cylZ(0.285, 0.285, 0.05), MAT.brass, T3(C.x, C.y, C.z + dz));
  piece(lk, "Tail1", G.cylY(0.08, 0.08, 0.05), MAT.dark, T3(C.x, C.y + 0.28, C.z - 0.02));
  piece(lk, "Tail1", G.cylY(0.06, 0.06, 0.02), MAT.steel, T3(C.x, C.y + 0.31, C.z - 0.02));
  piece(lk, "Tail1", G.cylZ(0.06, 0.09, 0.14), MAT.brass, T3(C.x, C.y + 0.05, C.z + 0.49));
  NK.bloomNozzle = V(C.x, C.y + 0.05, C.z + 0.58);
})();

// ===== Bloom Burst (button · slot; pick #1): unchanged from newparts.js v0.1 N7 (the bud in a sling under the chest) =====
(() => {
  const lk = "burst.A"; const h = ray(V(0, -3, -1.66), V(0, 1, 0), onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.26, 0.36, 0.04, V(0, 0, 1));
  for (const s of [1, -1]) { piece(lk, "Torso", G.tor(0.17, 0.028, Math.PI), MAT.gun, L(F, 0, 0.1, 0.11 * s)); for (const e of [1, -1]) { const q = V(0.17 * e, 0.1, 0.11 * s).applyMatrix4(F), hy = ray(V(q.x, -3, q.z), V(0, 1, 0), onSeg("Torso")).p.y; piece(lk, "Torso", G.box(0.06, hy - q.y, 0.06), MAT.gun, T3(q.x, (hy + q.y) / 2, q.z)); } }
  const c = V(0, 0.3, 0).applyMatrix4(F); const bud = [];
  bud.push(piece(lk, "Torso", G.sph(0.17, 1, 1.05, 1), gm("burst", "green"), T3(c.x, c.y, c.z)));
  for (let i = 0; i < 4; i++) { const a = i * Math.PI / 2 + Math.PI / 4; const pet = G.box(0.12, 0.3, 0.035); gx(pet, T3(0, 0.12, 0));
    bud.push(piece(lk, "Torso", pet, MAT.plate, T3(c.x, c.y - 0.15, c.z).multiply(rotY(a)).multiply(T3(0, 0, 0.16)).multiply(rotX(rad(-14))))); }
  NK.budCarry = makeCarry(bud, "Torso", c);
})();

// ===== Shield Dome (button · slot; pick #3): a squat dome canister on a side plate on the -X side of the tail base (Tail1, the
// mirror of the clean vent spot); press: thrown, it lands, its cap opens and a blue dome grows over the spot. =====
(() => {
  const lk = "dome.A"; const h = side(-1, 0.34, 1.38, onSeg("Tail1")); const F = bracket(lk, "Tail1", h, 0.32, 0.34, 0.04, V(0, 1, 0));
  const can = [];
  can.push(piece(lk, "Tail1", G.cylY(0.22, 0.24, 0.09), MAT.gun, L(F, 0, 0.065, 0)));
  can.push(piece(lk, "Tail1", G.tor(0.215, 0.03), MAT.brass, L(F, 0, 0.11, 0, 90, 0, 0)));
  can.push(piece(lk, "Tail1", G.sph(0.17, 1, 0.55, 1), gm("dome", "blue"), L(F, 0, 0.12, 0)));
  for (let i = 0; i < 3; i++) can.push(piece(lk, "Tail1", G.box(0.05, 0.05, 0.14), MAT.steel, L(F, 0, 0.13, 0, 0, 120 * i, 0).multiply(T3(0, 0, 0.17))));
  can.push(piece(lk, "Tail1", G.cylY(0.04, 0.04, 0.05), MAT.dark, L(F, 0, 0.215, 0)));
  NK.domeCarry = makeCarry(can, "Tail1", V(0, 0.08, 0).applyMatrix4(F));
})();

// ===== Sleep Dart (button · slot; pick #7): a slim dart launcher clamped on the skull over the +X eye (camera side), a violet
// sleep-serum vial on top; press: the head snaps forward and the dart fires where the head points. =====
(() => {
  const lk = "sleep.A";
  const h = topHit(0.16, -3.05, b => b.seg === "Head" && notThin(b)); const F = bracket(lk, "Head", h, 0.18, 0.26, 0.05, V(0, 0, 1));
  const p0 = V(0, 0, 0).applyMatrix4(F);
  piece(lk, "Head", G.box(0.07, 0.12, 0.16), MAT.gun, T3(p0.x, p0.y + 0.08, p0.z));
  piece(lk, "Head", G.box(0.22, 0.06, 0.12), MAT.gun, T3(p0.x + 0.11, p0.y + 0.15, p0.z));
  const c = V(p0.x + 0.24, p0.y + 0.16, p0.z - 0.06); NK.sleepC = c;
  piece(lk, "Head", G.cylZ(0.075, 0.075, 0.56), MAT.gun, T3(c.x, c.y, c.z), {anim: () => T3(0, 0, 0.06 * NS.sleepKick)});
  for (const dz of [-0.24, 0.0, 0.2]) piece(lk, "Head", G.cylZ(0.088, 0.088, 0.04), MAT.brass, T3(c.x, c.y, c.z + dz), {anim: () => T3(0, 0, 0.06 * NS.sleepKick)});
  piece(lk, "Head", G.cylZ(0.05, 0.05, 0.02), gm("sleep", "violet"), T3(c.x, c.y, c.z - 0.285), {anim: () => T3(0, 0, 0.06 * NS.sleepKick)});
  piece(lk, "Head", G.cylY(0.045, 0.045, 0.16), gm("sleep", "violet"), T3(c.x, c.y + 0.13, c.z + 0.08));
  piece(lk, "Head", G.cylY(0.055, 0.055, 0.03), MAT.brass, T3(c.x, c.y + 0.22, c.z + 0.08));
  piece(lk, "Head", G.box(0.03, 0.07, 0.03), MAT.steel, T3(c.x, c.y + 0.1, c.z - 0.2));
  NK.sleepMuzzle = V(c.x, c.y, c.z - 0.32);
})();
function sleepMuzzle() { return V(0, 0, 0).applyMatrix4(new THREE.Matrix4().makeTranslation(hero.pos.x, hero.y, hero.pos.z).multiply(scl(hero.scale)).multiply(hero.W.Head).multiply(segInv.Head).multiply(T3(NK.sleepMuzzle.x, NK.sleepMuzzle.y, NK.sleepMuzzle.z))); }
function sleepDir() { const M = new THREE.Matrix4().makeTranslation(hero.pos.x, hero.y, hero.pos.z).multiply(scl(hero.scale)).multiply(hero.W.Head).multiply(segInv.Head); return V(0, 0, -1).transformDirection(M); }

// ===== Sentry Pod (button · slot; pick #14): a folded pod turret on a saddle over the lower back (the clean spot behind the Mender
// arch); press: it hops into the hands, is thrown, unfolds 3 legs, turns to the nearest enemy and fires amber pods. =====
(() => {
  const lk = "sentry.A", z = 0.42;
  for (const s of [1, -1]) { const h = topHit(0.2 * s, z, onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.15, 0.34, 0.05);
    const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Torso", G.box(0.09, 0.82 - y0, 0.2), MAT.gun, T3(0.2 * s, (y0 + 0.82) / 2, z)); }
  piece(lk, "Torso", G.box(0.62, 0.07, 0.34), MAT.gun, T3(0, 0.855, z));
  const C = V(0, 0.93, z); NK.sentC = C; const tur = [];
  const head = {anim: p => rotAbout(p.at, C, rotY(NS.sentYaw))};
  tur.push(piece(lk, "Torso", G.cylY(0.2, 0.22, 0.08), MAT.dark, T3(C.x, C.y, C.z)));
  for (let i = 0; i < 3; i++) { const a = i * Math.PI * 2 / 3 + Math.PI / 3; const hp = V(Math.sin(a) * 0.17, C.y - 0.01, C.z + Math.cos(a) * 0.17);
    const leg = G.box(0.05, 0.035, 0.3); gx(leg, T3(0, 0, 0.15));
    tur.push(piece(lk, "Torso", leg, MAT.steel, T3(hp.x, hp.y, hp.z).multiply(rotY(a)), {anim: p => rotAbout(p.at, hp, rotY(a).multiply(rotX(rad(38) * NS.sentLeg)).multiply(rotY(-a)))})); }
  tur.push(piece(lk, "Torso", G.box(0.3, 0.17, 0.32), MAT.gun, T3(C.x, C.y + 0.13, C.z), head));
  tur.push(piece(lk, "Torso", G.box(0.32, 0.03, 0.26), MAT.plate, T3(C.x, C.y + 0.23, C.z + 0.02), head));
  tur.push(piece(lk, "Torso", G.cylZ(0.06, 0.06, 0.36), MAT.steel, T3(C.x, C.y + 0.13, C.z - 0.3), head));
  tur.push(piece(lk, "Torso", G.cylZ(0.075, 0.075, 0.05), MAT.brass, T3(C.x, C.y + 0.13, C.z - 0.46), Object.assign({}, head)));
  tur.push(piece(lk, "Torso", G.sph(0.09), gm("sentry", "amber"), T3(C.x, C.y + 0.28, C.z + 0.08), head));
  tur.push(piece(lk, "Torso", G.cylX(0.04, 0.04, 0.36), MAT.brass, T3(C.x, C.y + 0.05, C.z + 0.13), head));
  NK.sentMuzzle = V(C.x, C.y + 0.13, C.z - 0.5);
  NK.sentCarry = makeCarry(tur, "Torso", C);
})();
// the turret's muzzle in the world while it stands on the ground (carry group matrix · Fi · the head turn)
function sentryMuzzle() { const c = NK.sentCarry, C = NK.sentC, m = NK.sentMuzzle;
  const M = c.g.matrix.clone().multiply(c.Fi).multiply(T3(C.x, C.y, C.z)).multiply(rotY(NS.sentYaw)).multiply(T3(-C.x, -C.y, -C.z)); return V(m.x, m.y, m.z).applyMatrix4(M); }

// ---------- key poses (rig 1.3 angles: + = rear back / nose up for RootJoint / Neck / Head; Arm / Leg + = swing forward;
// Knee - = bend; Tail + = droop) ----------
const TA_WIND_W = addPose(TA_WIND, BOTH({ArmL: [0, 0, -12]}), 1), TA_HOLD_W = addPose(TA_HOLD, BOTH({ArmL: [0, 0, -12]}), 1); // TrooPose 1.3 wider wind-up
const THROW = T0 => [K(T0 + 0.2, TA_WIND_W, "io"), K(T0 + 0.27, TA_HOLD_W, "io"), K(T0 + 0.34, TA_THROW, "in2"), K(T0 + 0.52, TA_FOLLOW, "out"), K(T0 + 1.15, T_READY, "io")];
const QTHROW = T => [K(T + 0.1, TA_WIND_W, "io"), K(T + 0.15, TA_HOLD_W, "io"), K(T + 0.2, TA_THROW, "in2"), K(T + 0.34, TA_FOLLOW, "out")];
function idleIntro(keys, t0) { return [K(0, T_READY), K(t0, T_READY), ...keys]; }
const SHIELD_BLUE = 0x5ab4ff, HEAL_GREEN = 0x46e08a, VOLT = 0x7fe9ff, GOLD = 0xffd56a, MARK = 0xffa21a, WIND = 0xc8fff4;

// ---------- layered VFX helpers (each maps to a Roblox piece: glow = Neon + PointLight, trail = Trail / ParticleEmitter, orb =
// the MineBurst neon ball, aura = TenoBellowAura disc, ring = TenoMovesFX flat neon ring, heal = Med-Station MedWave + MedHealPop) ----------
function textTag(p, text, color, life) {
  const c = document.createElement("canvas"); const x0 = c.getContext("2d"); x0.font = `800 28px "Trebuchet MS", system-ui, sans-serif`; const tw = Math.ceil(x0.measureText(text).width) + 40;
  c.width = Math.max(120, tw); c.height = 64; const x = c.getContext("2d"); x.font = `800 28px "Trebuchet MS", system-ui, sans-serif`;
  x.fillStyle = "rgba(10,20,14,.8)"; x.beginPath(); x.roundRect ? x.roundRect(2, 8, c.width - 4, 48, 24) : x.rect(2, 8, c.width - 4, 48); x.fill();
  x.textAlign = "center"; x.fillStyle = color; x.fillText(text, c.width / 2, 42);
  const s = new THREE.Sprite(new THREE.SpriteMaterial({map: new THREE.CanvasTexture(c), transparent: true, depthTest: false})); s.renderOrder = 9;
  s.position.copy(p); s.scale.set(2.4 * c.width / 64, 2.4, 1);
  return addFx(s, life, (o, u) => { o.material.opacity = u < 0.08 ? u / 0.08 : u > 0.85 ? (1 - u) / 0.15 : 1; });
}
function glowAt(fn, color, size, life, op) { const s = sprite(T_FLASH, color, size, true); return addFx(s, life, (o, u) => { o.position.copy(fn()); o.material.opacity = (op || 0.8) * Math.min(1, u * life / 0.1) * (1 - u * u); o.scale.setScalar(size * (0.9 + 0.1 * Math.sin(clockT * 20))); }); }
function trailOn(fn, color, life, rate, size) { let em = 0; const o = new THREE.Object3D(); return addFx(o, life, (ob, u, dt) => { em += dt * rate; while (em >= 1) { em -= 1; const s = sprite(T_FLASH, color, size || 1.2, true); s.position.copy(fn()); addFx(s, 0.35, (q, uu) => { q.material.opacity = 0.9 * (1 - uu); q.scale.setScalar((size || 1.2) * (1 - uu * 0.7)); }); } }); }
function orb(p, r, color, life) { const m = new THREE.Mesh(new THREE.SphereGeometry(1, 20, 14), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0.7, depthWrite: false}));
  m.position.copy(p); return addFx(m, life || 0.35, (o, u) => { o.scale.setScalar(Math.max(0.01, r * E.out(u))); o.material.opacity = 0.7 * (1 - u); }); }
function aura(fnPos, r, color, life, op) { const m = new THREE.Mesh(new THREE.CircleGeometry(r, 40), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0, depthWrite: false})); m.rotation.x = -Math.PI / 2;
  const rim = new THREE.Mesh(new THREE.RingGeometry(r * 0.9, r, 40), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0, depthWrite: false, side: THREE.DoubleSide})); rim.position.z = 0.01; m.add(rim);
  return addFx(m, life, (o, u) => { o.position.copy(fnPos()).setY(0.15); const k = Math.min(1, u * life / 0.15) * Math.min(1, (1 - u) * life / 0.3); o.material.opacity = (op || 0.25) * k * (0.85 + 0.15 * Math.sin(clockT * 7)); rim.material.opacity = 0.9 * k; }); }
function rising(fnPos, color, life, rate, spread, vy0) { let em = 0; const o = new THREE.Object3D(); return addFx(o, life, (ob, u, dt) => { em += dt * rate; while (em >= 1) { em -= 1; const s = sprite(T_POD, color, 0.7 + Math.random() * 0.6, true); s.position.copy(fnPos()).add(V((Math.random() - .5) * spread, (Math.random() - .5) * spread * 0.6, (Math.random() - .5) * spread)); const vy = (vy0 || 3) + Math.random() * 4; addFx(s, 0.8, (q, uu, d) => { q.position.y += vy * d; q.material.opacity = uu < 0.2 ? uu / 0.2 : 1 - uu; }); } }); }
function shimmer(target, r, color, life, op) {
  const m = new THREE.Mesh(new THREE.IcosahedronGeometry(r, 1), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0, depthWrite: false, wireframe: true}));
  const s = new THREE.Mesh(new THREE.SphereGeometry(r * 0.98, 20, 14), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0, depthWrite: false})); m.add(s);
  return addFx(m, life, (o, u) => { o.position.copy(target()); o.rotation.y = clockT * 0.6; const k = Math.min(1, u * life / 0.12) * Math.min(1, (1 - u) * life / 0.25); o.material.opacity = (op || 0.45) * k; s.material.opacity = (op || 0.45) * 0.35 * k; });
}
function setHp(R, v) { R.hp = Math.max(0, Math.min(R.max || 60, v)); }
// a ring that leaves a point along an axis (the horn's note; TenoMovesFX's flat neon ring, tilted)
function axisRing(p, axis, r1, color, life, w) { const m = new THREE.Mesh(new THREE.RingGeometry(0.8, 1, 48), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0.9, depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending}));
  m.position.copy(p); m.quaternion.setFromUnitVectors(V(0, 0, 1), axis.clone().normalize());
  return addFx(m, life, (o, u, dt) => { o.position.addScaledVector(axis, dt * 9); o.scale.setScalar(0.6 + (r1 - 0.6) * E.out(u)); o.material.opacity = 0.9 * (1 - u); }); }
// a dashed ground circle (today's footprint ghost) and a dashed air path
function dashedCircle(c, r, color, life, label) {
  const pts = []; for (let i = 0; i <= 96; i++) { const a = i / 96 * Math.PI * 2; pts.push(V(c.x + Math.cos(a) * r, 0.35, c.z + Math.sin(a) * r)); }
  const g = new THREE.BufferGeometry().setFromPoints(pts); const ln = new THREE.Line(g, new THREE.LineDashedMaterial({color, dashSize: 2.2, gapSize: 1.4, transparent: true, depthWrite: false})); ln.computeLineDistances();
  const tube = new THREE.Mesh(new THREE.RingGeometry(r - 0.25, r + 0.25, 96), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0.0, depthWrite: false, side: THREE.DoubleSide})); tube.rotation.x = -Math.PI / 2; tube.position.set(c.x, 0.3, c.z);
  const grp = new THREE.Group(); grp.add(ln);
  for (let i = 0; i < 48; i++) { if (i % 2) continue; const a0 = i / 48 * Math.PI * 2; const seg = new THREE.Mesh(new THREE.RingGeometry(r - 0.3, r + 0.3, 6, 1, a0, Math.PI * 2 / 48), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0.9, depthWrite: false, side: THREE.DoubleSide})); seg.rotation.x = -Math.PI / 2; seg.position.set(c.x, 0.32, c.z); grp.add(seg); }
  addFx(grp, life, (o, u) => { o.children.forEach(ch => { ch.material.opacity = 0.85 * Math.min(1, u * life / 0.2) * Math.min(1, (1 - u) * life / 0.3); }); });
  if (label) textTag(V(c.x + r * 0.72, 3.5, c.z + r * 0.72), label, "#e8eef8", life);
}
function dashedPath(pts, color, life, label, at) {
  const grp = new THREE.Group();
  for (let i = 0; i < pts.length - 1; i += 2) { const a = pts[i], b = pts[i + 1]; const m = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.22, 1, 6, 1, true), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0.85, depthWrite: false}));
    m.position.copy(a).lerp(b, 0.5); m.scale.set(1, Math.max(0.01, a.distanceTo(b)), 1); m.quaternion.setFromUnitVectors(V(0, 1, 0), b.clone().sub(a).normalize()); grp.add(m); }
  addFx(grp, life, (o, u) => { o.children.forEach(ch => { ch.material.opacity = 0.8 * Math.min(1, u * life / 0.2); }); });
  if (label && at) textTag(at, label, "#e8eef8", life);
}

// ---------- the glow zone with per-zone numbers (the live TrooFX zone: teal disc, bright rim, ring wave, spores; ticks 1/s) ----------
const NZ = [];
function zoneAt(p, o) {
  o = Object.assign({R: 20, life: 3, impact: 6, dps: 1, heal: 5, self: 2, slow: 25}, o);
  const c = V(p.x, 0, p.z);
  hitStop = 0.07; shake = Math.max(shake, 0.6); fovPunch = 1.4; flash(p, 11, 0xffe2a0);
  for (let i = 0; i < 22; i++) { const a = Math.random() * Math.PI * 2, sp = 10 + Math.random() * 18; const s = sprite(T_POD, Math.random() < 0.5 ? AMBER : 0xffe7a8, 0.9 + Math.random() * 0.9, true); s.position.copy(p); const v = V(Math.cos(a) * sp, 6 + Math.random() * 12, Math.sin(a) * sp); addFx(s, 0.45 + Math.random() * 0.25, (q, u, d) => { v.y -= 50 * d; q.position.addScaledVector(v, d); if (q.position.y < 0.3) { q.position.y = 0.3; v.set(0, 0, 0); } q.material.opacity = 1 - u; }); }
  const g = new THREE.Group(); g.position.copy(c).setY(0.14); scene.add(g);
  const disc = new THREE.Mesh(new THREE.CircleGeometry(o.R, 72), new THREE.MeshBasicMaterial({color: ZONEC, transparent: true, opacity: 0.3, depthWrite: false})); disc.rotation.x = -Math.PI / 2; g.add(disc);
  const rim = new THREE.Mesh(new THREE.RingGeometry(o.R - 0.8, o.R, 72), new THREE.MeshBasicMaterial({color: ZONER, transparent: true, opacity: 0.95, depthWrite: false, side: THREE.DoubleSide})); rim.rotation.x = -Math.PI / 2; rim.position.y = 0.01; g.add(rim);
  const wave = new THREE.Mesh(new THREE.RingGeometry(0.6, 1.4, 72), new THREE.MeshBasicMaterial({color: 0xfff2c8, transparent: true, opacity: 0.9, depthWrite: false, side: THREE.DoubleSide})); wave.rotation.x = -Math.PI / 2; wave.position.y = 0.02; g.add(wave);
  const Z = {c, g, disc, rim, wave, t: 0, next: 1, spore: 0, o};
  NZ.push(Z);
  let hits = 0; const hitL = [], healL = [];
  for (const R of raps) if (R.show && inZ(Z, R)) {
    if (R.ally) { healPop(R, o.heal, o); healL.push(R); }
    else { hits++; hitL.push(R); popNum(rapChest(R).add(V(0, 5, 0)), o.impact, "hit"); R.flinch = 1; R.flash = 0.14; R.flashCol = [1, 0.62, 0.12]; R.push = 1.1; R.pushDir.copy(R.pos).sub(c).setY(0).normalize(); R.slow = Math.max(R.slow, o.life + 0.2);
      if (!R.tagged) { R.tagged = true; textTag(rapChest(R).add(V(0, 12, 0)), "SLOWED −" + o.slow + "%", "#ffd38a", 2.2); } }
  }
  if (hits && o.self) { const hp = partPoint(mouthParts.skull).add(V(0, 6, 0)); selfHeal.push({t: 0.35, n: hits * o.self, p: hp}); }
  if (o.ghost) dashedCircle(c, o.ghost, 0xffffff, o.life + 0.3, "today: " + Math.round(o.ghost * 2) + " studs");
  if (o.onSplat) o.onSplat(Z, hitL, healL);
  const vg = $("vig"); vg.style.background = "radial-gradient(ellipse at center, transparent 55%, rgba(255,170,40,.55))"; vg.style.transition = "none"; vg.style.opacity = 0.3; requestAnimationFrame(() => { vg.style.transition = "opacity .4s"; vg.style.opacity = 0; });
  return Z;
}
function healPop(R, n, o) { if (R.amp > 0) n = n * 1.5; popNum(rapChest(R).add(V((Math.random() - .5) * 3, 5, 0)), "+" + fmt(n), "heal"); healCrosses(rapChest(R), 3); R.heal = 0.4; if (R.hpShow) setHp(R, R.hp + n); if (o && o.onHeal) o.onHeal(R, n); }
function inZ(Z, R) { return R.rig.pos.clone().setY(0).distanceTo(Z.c) <= Z.o.R + 1.5; }
function updateNZ(dt) {
  for (let i = NZ.length - 1; i >= 0; i--) {
    const Z = NZ[i], o = Z.o; Z.t += dt; const u = Z.t / o.life;
    const wv = Math.min(1, Z.t / 0.4); Z.wave.scale.setScalar(0.5 + wv * (o.R / 1.4)); Z.wave.material.opacity = 0.9 * (1 - wv);
    const fade = u > 0.9 ? Math.max(0, (1 - u) / 0.1) : Math.min(1, Z.t / 0.12);
    Z.disc.material.opacity = (0.27 + 0.07 * Math.sin(Z.t * 7)) * fade; Z.rim.material.opacity = 0.95 * fade;
    Z.spore += dt * Math.min(110, 26 * (o.R / 10) * (o.R / 10) * 0.6); while (Z.spore >= 1) { Z.spore -= 1; const a = Math.random() * Math.PI * 2, r = Math.sqrt(Math.random()) * o.R; const s = sprite(T_POD, Math.random() < 0.6 ? ZONER : HEALC, 0.8 + Math.random() * 0.8, true); s.position.set(Z.c.x + Math.cos(a) * r, 0.4, Z.c.z + Math.sin(a) * r); const vy = 4 + Math.random() * 5; addFx(s, 0.9, (q, uu, d) => { q.position.y += vy * d; q.material.opacity = (uu < 0.2 ? uu / 0.2 : 1 - uu) * fade; }); }
    if (Z.t >= Z.next && Z.next <= o.life + 0.01) { Z.next += 1;
      for (const R of raps) if (R.show && inZ(Z, R)) {
        if (R.ally) { if (o.heal) healPop(R, o.heal, o); }
        else { if (o.dps) popNum(rapChest(R).add(V((Math.random() - .5) * 3, 5, 0)), (R.mark > 0 && o.markMul ? fmt(o.dps * o.markMul) : o.dps), "tick"); R.flinch = Math.max(R.flinch, 0.35); R.flash = 0.07; R.flashCol = [0.55, 0.32, 0.05]; R.slow = Math.max(R.slow, 1.1); }
      }
      if (o.onTick) o.onTick(Z); }
    if (Z.t >= o.life) {
      if (o.bloom) { const p = Z.c.clone().setY(1); flash(p, 16, 0xc8fff0); groundRing(Z.c, o.R, 0x9dffd0, 0.6, 2); groundRing(Z.c, o.R * 0.7, 0xffffff, 0.45, 1); rising(() => Z.c.clone().add(V((Math.random() - .5) * o.R * 1.4, 0.5, (Math.random() - .5) * o.R * 1.4)), HEALC, 0.5, 120, 1, 8);
        textTag(Z.c.clone().add(V(0, 14, 0)), "BLOOM: last pulse", "#a8fff0", 1.4);
        for (const R of raps) if (R.show && inZ(Z, R)) { if (R.ally) healPop(R, 5); else { R.slow = 1.5; textTag(rapChest(R).add(V(0, 11, 0)), "SLOWED +1.5 s", "#ffd38a", 1.3); } } }
      scene.remove(Z.g); NZ.splice(i, 1); }
  }
}

// ---------- flight (the live Flap & Glide: leap ~11 studs, each flap ~11 studs, auto glide falls 8 studs/s at 45 studs/s; Roblox
// gravity 196.2) ----------
function flight(o) {
  o = Object.assign({T0: 0.28, leap: 11, flapH: 11, flaps: 2, gap: 0.42, fwd: 45, gfwd: 45, fall: 8}, o);
  const Gv = 196.2, FL = []; for (let i = 0; i < o.flaps; i++) FL.push(o.T0 + o.gap * (i + 1));
  let y = 0, vy = Math.sqrt(2 * Gv * o.leap), x = 0, tt = o.T0, fi = 0, glideAt = null, landAt = null, thermalT = 0; const DT = 1 / 240, path = [];
  while (tt < 16) { path.push([tt, x, y, glideAt !== null]);
    if (fi < FL.length && tt >= FL[fi]) { vy = Math.sqrt(2 * Gv * o.flapH); fi++; }
    if (glideAt === null && fi >= FL.length && vy <= 0) glideAt = tt;
    if (glideAt !== null) { const th = o.thermal && tt < o.thermal.until && Math.abs(x - o.thermal.cz) < o.thermal.R && y < o.thermal.max; vy = th ? o.thermal.up : -o.fall; if (th) thermalT += DT; }
    else vy -= Gv * DT;
    y += vy * DT; x += (glideAt !== null ? o.gfwd : o.fwd) * DT; tt += DT;
    if (y <= 0 && tt > o.T0 + 0.1) { landAt = tt; path.push([tt, x, 0, false]); break; } }
  const peak = Math.max(...path.map(q => q[2]));
  return {o, path, FL, glideAt, landAt, peak, dist: path[path.length - 1][1], thermalT,
    at(q) { if (q <= o.T0) return [0, 0, false]; if (q >= landAt) return [path[path.length - 1][1], 0, false]; const k = Math.min(path.length - 1, Math.floor((q - o.T0) / DT)); return [path[k][1], path[k][2], path[k][3]]; }};
}
function flightKeys(F) {
  const fl = a => [K(a - 0.12, TF_UP, "io"), K(a + 0.06, TF_DOWN, "in2")];
  const ks = [K(0, T_READY), K(F.o.T0, TJ_CROUCH, "io"), K(F.o.T0 + 0.05, TF_DOWN, "in2")]; F.FL.forEach(a => ks.push(...fl(a)));
  ks.push(K(F.glideAt - 0.1, TF_UP, "io"), K(F.glideAt + 0.15, TF_GLIDE, "out"), K(F.landAt - 0.12, TF_GLIDE, "io"), K(F.landAt, TJ_DOWN, "io"), K(F.landAt + 0.12, TJ_LAND, "out"), K(F.landAt + 0.7, T_READY, "io"));
  return ks;
}
function wingPuff() { const p = partPoint(hero.segs.Torso[0]); for (let i = 0; i < 10; i++) { const s = sprite(T_FLASH, 0xd9cdb6, 1.6, false); s.position.copy(p).add(V((Math.random() - .5) * 6, -2 - Math.random() * 2, (Math.random() - .5) * 4)); const v = V((Math.random() - .5) * 8, -6 - Math.random() * 6, (Math.random() - .5) * 8); addFx(s, 0.5, (o, u, d) => { o.position.addScaledVector(v, d); o.material.opacity = 0.5 * (1 - u); o.scale.setScalar(1.6 + u * 3); }); } }
function ghostFlight(F, life) { // today's path as a dashed white line at the body's height, labels at its peak and landing
  const pts = []; for (let i = 0; i < F.path.length; i += 8) { const q = F.path[i]; pts.push(V(0, q[2] + 4.5, -q[1])); }
  const pk = F.path.reduce((a, b) => b[2] > a[2] ? b : a);
  dashedPath(pts, 0xffffff, life, "today: peak " + F.peak.toFixed(0) + " · " + F.dist.toFixed(0) + " studs", V(0, pk[2] + 9, -pk[1]));
}

// ---------- candidates: numbers (I / II / III / star; the 35% rule: each step's number is at least 1.35x the one before), the
// inspiration (game + the component borrowed, with sources), VFX in Roblox pieces ----------
const RANKS = ["I", "II", "III", "★"];
// cfg(id, r): r = -1 today (the live kit, no part), 0..3 = I..star
const CFG = {
  bloom: r => ({R: [20, 27, 27, 36.5, 36.5][r + 1], life: [3, 3, 4.05, 4.05, 4.05][r + 1], bloom: r >= 3}),
  burst: r => ({on: r >= 0, heal: 20, amp: r >= 1 ? 5.4 : 4, cd: r >= 2 ? 13.3 : 18, R: r >= 3 ? 27 : 20}),
  dome: r => ({on: r >= 0, R: r >= 3 ? 20.25 : 15, life: r >= 1 ? 6.75 : 5, cd: r >= 2 ? 18.5 : 25}),
  sleep: r => ({on: r >= 0, sleep: r >= 1 ? 3.4 : 2.5, cd: r >= 2 ? 8.9 : 12, n: r >= 3 ? 2 : 1}),
  sentry: r => ({on: r >= 0, life: r >= 1 ? 10.8 : 8, dmg: 6, per: r >= 3 ? 2 : 1, cd: r >= 2 ? 16.3 : 22, range: 60}),
};
const SRC = {
  ink: ["Super Mario Wiki: Inkling (\"The ink tank on an Inkling's back tracks their remaining ink\")", "https://www.mariowiki.com/Inkling"],
  ana: ["Overwatch Wiki: Biotic Grenade (heals allies, +50% healing received 4 s; enemies can't heal 4 s)", "https://overwatch-archive.fandom.com/wiki/Biotic_Grenade"],
  gib: ["Apex Legends Wiki: Gibraltar (Dome of Protection: blocks incoming and outgoing attacks, 12 s)", "https://apexlegends.wiki.gg/wiki/Gibraltar"],
  sleep: ["Overwatch Wiki: Ana (Sleep Dart: puts an enemy to sleep; damage wakes them early)", "https://overwatch.fandom.com/wiki/Ana"],
  torb: ["Overwatch Wiki: Torbjörn (Deploy Turret: thrown, self-building, targets the nearest enemy, 40 m)", "https://overwatch.fandom.com/wiki/Torbj%C3%B6rn"],
};
const CANDS = [
  {id: "bloom", code: "P", name: "Bloom Tank", kind: "PASSIVE", covers: "Glow zone", rec: true, locked: true,
    one: "A bigger glow zone that lasts longer: a see-through tank of zone fluid on the tail base. Locked in (Kepu 01:33).",
    steps: ["Glow zone 54 studs wide (today 40)", "Zones last 4.05 s (today 3 s)", "73 studs wide", "When a zone ends it blooms: one last pulse, squadmates inside +5, enemies inside slowed 1.5 s more"],
    check: "54 / 40 = 1.35 · 4.05 / 3 = 1.35 · 73 / 54 = 1.35",
    every: "Every throw: the tank's fluid drops and a teal puff leaves its nozzle; the zone lands bigger (today's 40-stud ring is drawn dashed inside it in Compare), and the tank glows teal for as long as the zone is up.",
    insp: [["Splatoon · the ink tank", "the tank on an Inkling's back is the gauge: its fill shows the ink left", ["ink"]]],
    borrow: "A see-through backpack tank whose fill level is the effect's fuel gauge.",
    roblox: "Tank = Glass cylinder (Transparency 0.55, teal) round a Neon fluid cylinder whose Size.Y tweens with the fill; brass bands; nozzle puff = ParticleEmitter (teal mist, 0.4 s); the zone = the live TrooFX zone with TrooZoneRadius / TrooZoneTime raised (a bigger disc + rim + ring wave + more spores); bloom = a second ring wave + a green spore burst + MedHealPop.",
    follows: "TrooFX zone (2FE6C8 / A8FFF0, ring wave, spores), Med-Station MedHealPop for the star pulse."},
  {id: "burst", code: "#1", name: "Bloom Burst", kind: "BUTTON", covers: "Burst heal", rec: true,
    one: "Throw a bloom bud that bursts open: a big instant squad heal plus a heal boost, and enemies inside heal less.",
    steps: ["Throw a bud up to 40 studs; squadmates within 20 studs heal 20 and get 50% more healing for 4 s; enemies inside heal 50% less for 4 s. Recharge 18 s", "The boost lasts 5.4 s", "Recharge 13.3 s", "Bursts 54 studs wide (I: 40)"],
    check: "5.4 / 4 = 1.35 · 18 / 13.3 = 1.35 · 27 / 20 = 1.35",
    every: "Press: the bud drops from its belly sling into the hands (wind-up), is thrown, lands, its petals open, then a green burst wave; squadmates glow green while boosted (their next heals pop bigger); enemies get a purple 'NO HEAL' mark.",
    insp: [["Overwatch · Ana's Biotic Grenade", "a thrown grenade that heals allies and boosts their healing received by 50% for 4 s, while enemies can't heal", ["ana"]]],
    borrow: "The two-sided grenade: heal + healing boost for allies, less healing for enemies, from one throw.",
    roblox: "Bud = welded MeshParts (green Neon core, 4 petal plates) in a strap sling; thrown with the TrooFX pod arc; burst = Neon sphere flash + 2 flat rings + green ParticleEmitter; boost = a green Highlight + aura disc on each squadmate; less healing = a purple BillboardGui tag.",
    follows: "Med-Station heal look, TrooFX pod arc and splat, TenoMovesFX aura disc."},
  {id: "dome", code: "#3", name: "Shield Dome", kind: "BUTTON", covers: "Squad cover", rec: true,
    one: "Throw a canister that opens a blue dome over the spot: enemy shots and pods stop on it, your squad's go out.",
    steps: ["Throw a canister up to 30 studs; a dome 30 studs wide stands for 5 s: enemy shots, darts and pods stop on it; yours pass out. Recharge 25 s", "The dome lasts 6.75 s", "Recharge 18.5 s", "The dome is 40.5 studs wide"],
    check: "6.75 / 5 = 1.35 · 25 / 18.5 = 1.35 · 40.5 / 30 = 1.35",
    every: "Press: the canister leaves its plate on the tail base into the hands (wind-up), is thrown, lands, its cap flips and a blue dome grows out of it (0.35 s); every enemy shot that reaches it flashes a blue hex ripple where it stops; at the end the dome shrinks back into the canister and it fizzles out.",
    insp: [["Apex Legends · Gibraltar's Dome of Protection", "a thrown dome shield that stops incoming and outgoing bullets and projectiles; players can walk through it", ["gib"]]],
    borrow: "The thrown dome you can walk through. Changed for this game: your squad's shots go out (Gibraltar's blocks both ways), so it covers the healer without stopping the fight.",
    roblox: "Canister = welded MeshParts (gunmetal can, brass ring, blue Neon cap) thrown on the TrooFX pod arc; dome = a half-sphere MeshPart (ForceField material, blue, Transparency 0.75, CanCollide false) tweened from 0 to full size + a ground ring (TenoMovesFX ring); blocked shot = the shot's Touched on the dome part (enemy team only) destroys it and plays a small blue hex decal flash + spark burst at the hit point.",
    follows: "Shield blue (5AB4FF) from the shield HUD; TenoMovesFX flat ring; TrooFX pod arc."},
  {id: "sleep", code: "#7", name: "Sleep Dart", kind: "BUTTON", covers: "Stop one enemy", rec: true,
    one: "Fire a fast dart from a launcher on the head: the first enemy hit falls asleep and stops; any hit wakes it.",
    steps: ["Fire a dart (fast, straight, 120 studs): the first enemy hit falls asleep 2.5 s (can't move, attack or use parts); any damage wakes it. Recharge 12 s", "Sleeps 3.4 s", "Recharge 8.9 s", "The dart splits on hit: one more enemy within 15 studs falls asleep too"],
    check: "3.4 / 2.5 = 1.36 · 12 / 8.9 = 1.35 · 2 / 1 = 2",
    every: "Press: the neck coils back (wind-up), the head snaps forward and the launcher kicks; a violet dart with a violet trail; the enemy hit slumps, turns violet and floats Z's with a countdown; a hit wakes it with a jolt.",
    insp: [["Overwatch · Ana's Sleep Dart", "a dart that puts an enemy to sleep; if the sleeping target takes damage it wakes up early", ["sleep"]]],
    borrow: "Sleep that any damage breaks: a long stop that the squad chooses when to end.",
    roblox: "Launcher = welded MeshParts on the Head (gunmetal tube, brass bands, violet Neon vial); kick = a 0.1 s tween back; dart = a small Neon part + Trail (violet) fired by a server raycast; asleep = the live StunnedUntil (no move / attack / parts) + a violet Highlight + a BillboardGui 'Zz 2.5' + ParticleEmitter Z's; wake = the damage handler clears StunnedUntil for sleep (a new SleepUntil attribute) + a white flash.",
    follows: "The Arc Lantern's StunnedUntil stun (now with a wake-on-hit rule), TrooFX bolt trail."},
  {id: "sentry", code: "#14", name: "Sentry Pod", kind: "BUTTON", covers: "Damage over time", rec: true,
    one: "Throw a folded turret: it unfolds 3 legs, turns to the nearest enemy and fires amber pods for 8 s.",
    steps: ["Throw a turret up to 30 studs; for 8 s it shoots the nearest enemy within 60 studs: a pod every 0.5 s, 6 damage each. Recharge 22 s", "Lasts 10.8 s", "Recharge 16.3 s", "Twin pods: 2 per shot"],
    check: "10.8 / 8 = 1.35 · 22 / 16.3 = 1.35 · 2 / 1 = 2",
    every: "Press: the turret hops off its saddle into the hands (wind-up), is thrown, lands, the legs kick out and the head spins up; each shot: a muzzle flash, an amber pod, a hit number; the head turns to the next enemy; at the end it folds and dissolves into teal sparks and a new one builds on the saddle.",
    insp: [["Overwatch · Torbjörn's Deploy Turret", "a thrown, self-building turret that shoots the nearest enemy in sight", ["torb"]]],
    borrow: "The thrown turret that builds itself and picks targets on its own.",
    roblox: "Turret = welded MeshParts (gunmetal head on a HingeConstraint for the turn, 3 steel legs on Motor6Ds that tween out, an amber Neon hopper); target = nearest enemy within 60 studs with a clear raycast every 0.5 s; shot = the TrooFX bolt (amber) + a muzzle Neon flash + PointLight; end = parts tween to 0 + teal ParticleEmitter burst.",
    follows: "TrooFX pod / bolt amber (FFC35A), TrooFX hit numbers."},
  {id: "set", code: "", name: "All picked", kind: "CHECK", covers: "All on at once"},
];
const CID = CANDS.filter(c => c.id !== "set").map(c => c.id);
const RECSET = CANDS.filter(c => c.rec).map(c => c.id);
const SPOT = {bloom: "Top of the tail base (Tail1): two hoop cradles on posts, the tank lying along the tail.",
  burst: "Under the chest: a sling of two half-ring straps on four posts, the bud hanging in it.",
  dome: "-X side of the tail base (Tail1), on a side plate: the canister stands flat against the tail.",
  sleep: "Top of the skull, camera side (+X): a clamp plate, an arm out over the +X eye, the launcher pointing forward.",
  sentry: "Lower back: a saddle on two posts over the crest (behind the Mender Drone arch), the turret folded on it."};
const NOTES = {bloom: ["Ahead of the Portal Rift's tail rings, behind the hips.", "Passive: no button, takes no slot."],
  burst: ["Between the arms and under the chest: hidden from the game camera until it drops into the hands.", "Takes a slot (button)."],
  dome: ["Mirrors the old Updraft Vent spot (measured clean); under the Bloom Tank's cradle on the side away from the camera.", "Takes a slot (button)."],
  sleep: ["Rides the head, so it fires where the head points.", "Takes a slot (button)."],
  sentry: ["Between the Mender Drone arch and the Bloom Tank.", "Takes a slot (button)."]};

// ---------- scenes ----------
function zoneScene2() { place(S, -9, -36); place(S2, 7, -46); place(R0, -1, -42); place(R1, 9, -38); R0.yaw = yawTo(R0.pos, S.pos); R1.yaw = yawTo(R1.pos, S2.pos); S.yaw = yawTo(S.pos, R0.pos); S2.yaw = yawTo(S2.pos, R1.pos); }
let mode = "boost", rank = 3, liveOn = true, cphase = 0; // cphase: Compare mode's current half (0 = today, 1 = with the part)
const boostNow = () => mode === "boost" || (mode === "compare" && cphase === 1);
const ghostNow = () => mode === "compare" && cphase === 1;
const cfgNow = id => CFG[id](boostNow() ? rank : -1);
function hudPods(n, max, u) { NS.hud = {n, max, u}; }


function bloomTrack() {
  const c = cfgNow("bloom"), on = boostNow();
  zoneScene2(); place(R2, -24, -50); place(S2, 21, -36); R2.yaw = yawTo(R2.pos, V(-1, 0, -42)); S2.yaw = yawTo(S2.pos, R1.pos);
  S.max = S2.max = 60; setHp(S, 44); setHp(S2, 46); S.hpShow = S2.hpShow = true;
  const T0 = 0.6, REL = T0 + 0.34, FLY = 0.37, SPLAT = REL + FLY, END = SPLAT + c.life;
  const keys = idleIntro(THROW(T0), T0);
  const ev = [{t: T0, f: () => { if (on) glowAt(() => tankPoint(), ZONEC, 5, 0.5, 0.6); }},
    {t: REL, f: () => { if (on) { const p = tankPoint(true); for (let i = 0; i < 8; i++) puff(p.clone(), V((Math.random() - .5) * 6, 4 + Math.random() * 4, 4 + Math.random() * 4), 1.1, 0xa8fff0, 0.6, 0.7); flash(p, 3, 0xa8fff0); }
      throwPod({kind: "pod", from: handsPoint(), target: () => V(-1, 1, -42), T: FLY, H: 8, onHit: p => { zoneAt(p, {R: c.R, life: c.life, bloom: c.bloom, ghost: ghostNow() ? 20 : 0}); later(0.3, () => textTag(V(-1, 16, -42 + c.R * 0.3), "GLOW ZONE · " + Math.round(c.R * 2) + " studs · " + fmt(c.life) + " s", "#a8fff0", 1.8)); }}); }}];
  return {frame: [V(0, 0, 4), V(0, 0, -44 - c.R)], keys, ev, eyes: [[T0, REL + 0.3]],
    update(t) { NS.fill = !on ? 1 : t < REL ? 1 : t < REL + 0.25 ? 1 - 0.3 * win(t, REL, REL + 0.25) : t < END ? 0.7 + 0.3 * win(t, REL + 0.25, END) : 1;
      PGLOW.bloom = !on ? 0 : t > SPLAT && t < END ? 0.9 + 0.3 * Math.sin(t * 7) : t > T0 && t < REL ? 0.8 : 0.1; },
    phases: [[0, T0, on ? "Slotted (no slot used): the tank glows calm on the tail base" : "Today: no part"], [T0, REL, "Wind-up: the pod comes into both hands" + (on ? ", the tank pressurises" : "")], [REL, SPLAT, on ? "Throw: the tank's fluid drops, a teal puff leaves the nozzle" : "Throw"], [SPLAT, SPLAT + 0.6, "Splat: a " + Math.round(c.R * 2) + "-stud glow zone" + (on ? " (today 40)" : "")], [SPLAT + 0.6, END, "Enemies −1/s and slowed, squadmates +5/s, for " + fmt(c.life) + " s"], [END, END + 1.1, c.bloom ? "Star: it ends in a bloom pulse (+5 squad, enemies slowed 1.5 s more)" : "The zone fades"]],
    len: END + 1.2};
}
function tankPoint(nozzle) { const q = nozzle ? NK.bloomNozzle : NK.bloomC; return V(0, 0, 0).applyMatrix4(new THREE.Matrix4().makeTranslation(hero.pos.x, hero.y, hero.pos.z).multiply(scl(hero.scale)).multiply(hero.W.Tail1).multiply(segInv.Tail1).multiply(T3(q.x, q.y, q.z))); }

function burstTrack() {
  const c = cfgNow("burst"), on = boostNow();
  zoneScene2(); S.max = S2.max = 60; setHp(S, 24); setHp(S2, 30); S.hpShow = S2.hpShow = true;
  const cc = NK.budCarry; const B = V(-1, 0, -41);
  const T0 = 0.6, REL = T0 + 0.34, FLY = 0.5, LAND = REL + FLY, OPEN = LAND + 0.3, POD = OPEN + 1.3, END = POD + 0.37 + 2.2;
  const keys = idleIntro([...THROW(T0), ...THROW(POD - 0.34).slice(0, 4), K(POD + 0.8, T_READY, "io")], T0);
  let p0 = null;
  const ev = [];
  if (on) ev.push({t: T0, f: () => glowAt(() => carryPos(cc), HEAL_GREEN, 5, REL - T0, 0.9)},
    {t: REL, f: () => { p0 = carryPos(cc); trailOn(() => carryPos(cc), HEAL_GREEN, FLY, 40, 1.1); }},
    {t: LAND, f: () => { groundRing(B, 5, HEAL_GREEN, 0.4, 1); textTag(B.clone().add(V(0, 9, 0)), "BLOOMING…", "#8dffb6", 0.5); }},
    {t: OPEN, f: () => { const p = B.clone().setY(2); flash(p, 18, 0xd8ffe0); orb(p, c.R * 0.6, HEAL_GREEN, 0.45); groundRing(B, c.R, HEAL_GREEN, 0.6, 2); groundRing(B, c.R * 0.75, 0xffffff, 0.45, 1); hitStop = 0.06; shake = 0.6;
      rising(() => B.clone().add(V((Math.random() - .5) * c.R * 1.6, 0.5, (Math.random() - .5) * c.R * 1.6)), HEALC, 0.6, 90, 1, 8);
      for (const R of raps) { if (!R.show) continue; const d = R.rig.pos.clone().setY(0).distanceTo(B); if (d > c.R + 1.5) continue;
        if (R.ally) { healPop(R, c.heal); R.amp = c.amp; aura(() => R.rig.pos, 5.5, HEAL_GREEN, c.amp, 0.3); textTag(rapChest(R).add(V(0, 14.5, 0)), "+50% HEALING · " + fmt(c.amp) + " s", "#8dffb6", 1.8); }
        else { R.noheal = c.amp; R.flash = 0.2; R.flashCol = [0.6, 0.2, 0.9]; textTag(rapChest(R).add(V(0, 11, 0)), "NO HEAL −50% · " + fmt(c.amp) + " s", "#d9a8ff", 1.8); } } }});
  ev.push({t: POD, f: () => throwPod({kind: "pod", from: handsPoint(), target: () => V(-1, 1, -42), T: 0.37, H: 8, onHit: p => { zoneAt(p, {heal: 5, self: 2, onHeal: (R, n) => {}, ampFn: true}); }})});
  return {frame: [V(0, 0, 4), V(0, 0, -46)], keys, ev, eyes: [[T0, REL + 0.3], [POD - 0.3, POD + 0.2]],
    update(t, dt) { PGLOW.burst = on ? 0.5 : 0; for (const R of raps) { R.amp = Math.max(0, (R.amp || 0) - dt); R.noheal = Math.max(0, (R.noheal || 0) - dt); }
      cc.k = !on ? 1 : t < END - 1.2 ? 1 : E.back(win(t, END - 1.2, END - 0.8)); if (on && t > OPEN && t < END - 1.2) cc.k = 0.001; },
    post(t) { if (!on || t < T0) { carryOff(cc); return; } const dock = dockWorld(cc);
      if (t < REL) { carryAt(cc, lerpM(dock, worldM(handsPoint(), 0, 3.4), E.io(win(t, T0 + 0.02, REL - 0.04)))); return; }
      if (t < LAND) { const u = win(t, REL, LAND); const p = p0.clone().lerp(B.clone().setY(0.8), u); p.y += 4 * 7 * u * (1 - u); carryAt(cc, worldM(p, t * 6, 3.4)); return; }
      if (t < OPEN + 0.1) { const k = 3.4 + 2.6 * E.back(win(t, LAND, OPEN)); carryAt(cc, worldM(B.clone().setY(0.6 + k * 0.17), 0, k)); return; }
      carryOff(cc); },
    phases: on ? [[0, T0, "Slotted (takes a slot): the bud hangs in its belly sling"], [T0, REL, "Press: wind-up, the bud drops into both hands"], [REL, LAND, "Throws the bud (the pod arc)"], [LAND, OPEN, "It lands and swells"], [OPEN, POD, "Bursts: squadmates within " + c.R + " studs +20 and +50% healing " + fmt(c.amp) + " s; enemies can't heal"], [POD, END - 1.2, "Next pod: the zone heals the boosted squadmates +7.5/s (5 x 1.5)"], [END - 1.2, END, "Recovery: a new bud grows in the sling (" + c.cd + " s recharge)"]]
      : [[0, T0, "Today: no burst heal; the squad only heals in the zone"], [T0, POD, "The normal pod throw: squadmates +5 on the splat"], [POD, END, "Another pod: squadmates +5/s in the zone"]],
    len: END};
}

// ---------- slot part tracks (v0.1 new: Shield Dome, Sleep Dart, Sentry Pod) ----------
// carry helper shared by the thrown parts: dock -> hands (wind-up) -> arc to the landing spot; ground(t) places it once landed
function throwCarry(cc, t, T0, REL, LAND, land, H, sHand, ground) {
  if (t < T0) { carryOff(cc); return; } const dock = dockWorld(cc);
  if (t < REL) { carryAt(cc, lerpM(dock, worldM(handsPoint(), 0, sHand), E.io(win(t, T0 + 0.02, REL - 0.04)))); return; }
  if (t < LAND) { const u = win(t, REL, LAND); if (!cc.p0) cc.p0 = handsPoint(); const p = cc.p0.clone().lerp(land, u); p.y += 4 * H * u * (1 - u); carryAt(cc, worldM(p, t * 7, sHand, t * 5)); return; }
  ground(t);
}
function regrow(cc, on, t, gone, back) { cc.k = !on ? 1 : t < gone ? 1 : t < back ? 0.001 : E.back(win(t, back, back + 0.4)); }
const T_Z = (() => { const c = document.createElement("canvas"); c.width = c.height = 64; const x = c.getContext("2d"); x.font = "900 52px Trebuchet MS, sans-serif"; x.textAlign = "center"; x.lineWidth = 8; x.strokeStyle = "#2a1050"; x.strokeText("Z", 32, 50); x.fillStyle = "#e6d4ff"; x.fillText("Z", 32, 50); return new THREE.CanvasTexture(c); })();
function zzz(R) { const s = sprite(T_Z, 0xffffff, 3.4, false); const p0 = rapChest(R).add(V(1.5, 5, 0)); s.position.copy(p0); const dx = (Math.random() - .5) * 2;
  addFx(s, 1.3, (o, u, d) => { o.position.y += 3.2 * d; o.position.x += Math.sin(u * 6) * 1.6 * d + dx * d; o.scale.setScalar(2.8 + 2.6 * u); o.material.opacity = u < 0.15 ? u / 0.15 : 1 - u; }); }
// a straight-line shot from a to b (a small glowing ball + trail)
function shot(from, to, T, color, size, onHit) { const s = sprite(T_FLASH, color, size || 1.6, true); fly({obj: s, from: from.clone(), to: typeof to === "function" ? to : () => to, T, H: 0, trail: color, onHit}); }

// Shield Dome: the canister is thrown 14 studs ahead; the dome covers the troodon and a hurt squadmate; 2 enemies fire at the
// squadmate (blocked on the dome); the troodon's own pod goes out through it.
function makeDome(D, R, life) {
  const g = new THREE.Group(); g.position.copy(D).setY(0);
  const shell = new THREE.Mesh(new THREE.SphereGeometry(1, 40, 20, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshBasicMaterial({color: DOME_BLUE, transparent: true, opacity: 0.16, depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending})); g.add(shell);
  const hex = new THREE.Mesh(new THREE.IcosahedronGeometry(1.002, 2), new THREE.MeshBasicMaterial({color: 0xbfe6ff, transparent: true, opacity: 0.4, depthWrite: false, wireframe: true})); g.add(hex);
  const rim = new THREE.Mesh(new THREE.RingGeometry(0.95, 1.02, 72), new THREE.MeshBasicMaterial({color: 0xbfe6ff, transparent: true, opacity: 0.9, depthWrite: false, side: THREE.DoubleSide})); rim.rotation.x = -Math.PI / 2; rim.position.y = 0.02; g.add(rim);
  const D0 = {g, shell, hex, rim, R, pulse: 0, up: false};
  addFx(g, life, (o, u, dt) => { const t = u * life; const grow = E.back(Math.min(1, t / 0.35)), shrink = t > life - 0.3 ? Math.max(0.001, (life - t) / 0.3) : 1; const k = Math.max(0.001, R * grow * shrink);
    o.scale.set(k, k, k); D0.up = t > 0.3 && t < life - 0.3; D0.pulse = Math.max(0, D0.pulse - dt * 3);
    shell.material.opacity = 0.14 + 0.1 * D0.pulse + 0.03 * Math.sin(clockT * 5); hex.material.opacity = 0.32 + 0.4 * D0.pulse; hex.rotation.y = clockT * 0.15; NS.domeGlow = 1; });
  return D0;
}
function sphereEntry(A, B, C, R) { const d = B.clone().sub(A), f = A.clone().sub(C); const a = d.dot(d), b = 2 * f.dot(d), c = f.dot(f) - R * R; const disc = b * b - 4 * a * c; if (disc < 0) return null; const t = (-b - Math.sqrt(disc)) / (2 * a); return t > 0 && t < 1 ? t : null; }
function domeTrack() {
  const c = cfgNow("dome"), on = boostNow(), cc = NK.domeCarry; cc.p0 = null;
  const Dp = V(0, 0, -14);
  place(S, -4, -22); place(S2, 10, -7); place(R0, -12, -66); place(R1, 14, -62);
  [S, S2].forEach(R => { R.yaw = yawTo(R.pos, V(0, 0, -64)); }); R0.yaw = yawTo(R0.pos, S.pos); R1.yaw = yawTo(R1.pos, S.pos);
  S.max = 60; setHp(S, 44); S.hpShow = true;
  const T0 = 0.6, REL = T0 + 0.34, FLY = 0.45, LAND = REL + FLY, OPEN = LAND + 0.2, DOWN = OPEN + (on ? c.life : 5), END = DOWN + 0.9, OUT = OPEN + 1.4;
  const keys = idleIntro([...THROW(T0), ...THROW(OUT - 0.34)], T0);
  const GS = 4.5; let dome = null, told = false;
  const ev = [];
  if (on) ev.push({t: T0, f: () => glowAt(() => carryPos(cc), DOME_BLUE, 4, REL - T0, 0.7)}, {t: REL, f: () => trailOn(() => carryPos(cc), DOME_BLUE, FLY, 40, 1)},
    {t: LAND, f: () => { groundRing(Dp, 5, DOME_BLUE, 0.4, 1); flash(Dp.clone().setY(1), 6, 0xcfe8ff); }},
    {t: OPEN, f: () => { dome = makeDome(Dp, c.R, c.life); flash(Dp.clone().setY(2), 16, 0xcfe8ff); groundRing(Dp, c.R, 0xbfe6ff, 0.5, 1); shake = 0.3;
      textTag(Dp.clone().add(V(0, c.R + 4, 0)), "SHIELD DOME · " + fmt(c.R * 2) + " studs · " + fmt(c.life) + " s", "#bfe6ff", 1.8); }});
  // enemy shots at the hurt squadmate, every 0.5 s from 1.6 s, alternating shooters
  for (let i = 0, t = OPEN + 0.45; t < DOWN - 0.2; i++, t += 0.5) { const R = i % 2 ? R1 : R0;
    ev.push({t, f: () => { const A = rapChest(R).add(V(0, 1, 0)), B = rapChest(S); flash(A, 3, VOLT); R.flinch = Math.max(R.flinch, 0.25);
      const up = on && dome && dome.up; const k = up ? sphereEntry(A, B, Dp, c.R) : null;
      if (k !== null) { const P = A.clone().lerp(B, k); shot(A, P, A.distanceTo(P) / 140, VOLT, 1.6, p => { dome.pulse = 1; const n = p.clone().sub(Dp).normalize(); flash(p, 7, 0xcfe8ff); axisRing(p, n, 3.5, 0xbfe6ff, 0.35); sparks(p, n, 6, 0xcfe8ff, 0.3);
          if (!told) { told = true; textTag(p.clone().add(V(0, 5, 0)), "BLOCKED", "#bfe6ff", 1.2); } }); }
      else shot(A, () => rapChest(S), A.distanceTo(B) / 140, VOLT, 1.6, p => { popNum(p.clone().add(V(0, 5, 0)), 8, "hit"); S.flinch = 0.8; S.flash = 0.12; S.flashCol = [0.4, 0.8, 1]; setHp(S, S.hp - 8); }); }}); }
  ev.push({t: OUT, f: () => throwPod({kind: "pod", from: handsPoint(), target: () => R0.pos.clone().setY(1), T: 0.5, H: 9, onHit: p => { zoneAt(p, {self: 0}); if (on) textTag(p.clone().add(V(0, 15, 0)), "YOUR POD GOES OUT", "#ffd38a", 1.4); }})});
  if (on) ev.push({t: DOWN - 0.3, f: () => { sparks(Dp.clone().setY(1), V(0, 1, 0), 10, 0xcfe8ff, 0.4); }});
  return {frame: [V(0, 0, 6), V(0, 0, -66)], keys, ev, eyes: [[T0, REL + 0.3], [OUT - 0.3, OUT + 0.2]],
    update(t) { NS.domeGlow = 0; PGLOW.dome = !on ? 0 : t < REL ? 0.2 + 0.8 * win(t, T0, REL) : 0.2; regrow(cc, on, t, LAND, DOWN + 0.2); },
    post(t) { if (!on) { carryOff(cc); return; }
      throwCarry(cc, t, T0, REL, LAND, Dp.clone().setY(0.6), 6, 3.4, tt => { if (tt > DOWN) { carryOff(cc); return; } const k = GS * (tt < OPEN ? E.back(win(tt, LAND, OPEN)) * 0.9 + 0.1 : 1);
        carryAt(cc, new THREE.Matrix4().compose(Dp.clone().setY(0.25 * k), new THREE.Quaternion().setFromEuler(new THREE.Euler(0, 0, -Math.PI / 2)), V(k, k, k))); }); },
    phases: on ? [[0, T0, "Slotted (takes a slot): the dome canister on the tail base"], [T0, REL, "Press: wind-up, the canister comes into both hands"], [REL, LAND, "Throws it 14 studs (up to 30)"], [LAND, OPEN + 0.35, "It lands, the cap flips, the dome grows: " + fmt(c.R * 2) + " studs wide"], [OPEN + 0.35, OUT, "Enemy shots stop on the dome (blue ripples); the squadmate keeps its HP"], [OUT, DOWN, "Your pod goes out through it; the dome holds " + fmt(c.life) + " s"], [DOWN, END, "Recovery: the dome shrinks away; a new canister builds on the tail (" + c.cd + " s recharge)"]]
      : [[0, OPEN + 0.45, "Today: no dome"], [OPEN + 0.45, OUT, "2 enemies shoot the hurt squadmate: 8 per shot"], [OUT, END, "Your pod throw; the squadmate keeps getting hit"]],
    len: END};
}

// Sleep Dart: an enemy raptor runs at a hurt squadmate; the troodon fires a dart; it sleeps where it stands, then wakes and runs on
function runPath(A, B, speed, t0, stopAt, wakeAt) { // A -> B at speed from t0; optional stop at stopAt, resume at wakeAt
  const len = A.distanceTo(B), tArr = t0 + len / speed, yaw = yawTo(A, B);
  if (stopAt === undefined || stopAt >= tArr) return {path: [[0, A.clone(), yaw, 0], [t0, A.clone(), yaw, 1], [tArr, B.clone(), yaw, 1], [tArr + 0.15, B.clone(), yaw, 0]], tArr};
  const P = A.clone().lerp(B, (stopAt - t0) * speed / len), rem = P.distanceTo(B), back = wakeAt + 0.2 + rem / speed;
  return {path: [[0, A.clone(), yaw, 0], [t0, A.clone(), yaw, 1], [stopAt, P.clone(), yaw, 1], [stopAt + 0.06, P.clone(), yaw, 0], [wakeAt, P.clone(), yaw, 0], [wakeAt + 0.2, P.clone(), yaw, 1], [back, B.clone(), yaw, 1], [back + 0.15, B.clone(), yaw, 0]], tArr: back, P};
}
function sleepTrack() {
  const c = cfgNow("sleep"), on = boostNow();
  place(S, -14, -18); S.yaw = yawTo(S.pos, V(8, 0, -74)); S.max = 60; setHp(S, 30); S.hpShow = true;
  place(R0, 8, -74); place(R1, 24, -80);
  const T0 = 0.6, FIRE = T0 + 0.3, SPD = 30, A0 = V(8, 0, -74), B0 = V(-9, 0, -27), A1 = V(24, 0, -80), B1 = V(-1, 0, -32);
  const flyT = 0.28, HIT = FIRE + flyT, HIT2 = HIT + 0.2, WAKE = HIT + c.sleep, WAKE2 = HIT2 + c.sleep;
  const p0 = on ? runPath(A0, B0, SPD, 0.2, HIT, WAKE) : runPath(A0, B0, SPD, 0.2);
  const two = on && c.n > 1, p1 = two ? runPath(A1, B1, SPD * 0.92, 0.2, HIT2, WAKE2) : runPath(A1, B1, SPD * 0.92, 0.2);
  R0.path = p0.path; R1.path = p1.path;
  const END = Math.max(p0.tArr, on ? WAKE : 0) + 1.6;
  const keys = [K(0, T_READY), K(T0, T_READY), K(T0 + 0.22, TB_COIL, "io"), K(FIRE, TB_SPIT, "in2"), K(FIRE + 0.5, T_READY, "io")];
  const ev = [];
  const asleep = (R, until, tag) => { R.zzT = 1; R.sleepT = until; R.flash = 0.2; R.flashCol = [0.7, 0.5, 1]; flash(rapChest(R), 7, 0xe2ccff); textTag(rapChest(R).add(V(0, 12, 0)), tag, "#d9c2ff", c.sleep); };
  if (on) {
    ev.push({t: T0 + 0.05, f: () => glowAt(() => sleepMuzzle(), SLEEP_V, 2.6, FIRE - T0, 0.8)});
    ev.push({t: FIRE, f: () => { NS.sleepKick = 1; const m = sleepMuzzle(); flash(m, 4, 0xe2ccff); sparks(m, sleepDir(), 5, 0xe2ccff, 0.3);
      shot(m, () => rapChest(R0), flyT, SLEEP_V, 1.5, p => { asleep(R0, WAKE, "ASLEEP · " + fmt(c.sleep) + " s");
        if (two) shot(p, () => rapChest(R1), 0.2, SLEEP_V, 1.3, () => asleep(R1, WAKE2, "SPLIT: ASLEEP · " + fmt(c.sleep) + " s")); }); }});
    ev.push({t: WAKE, f: () => { R0.zzT = 0; flash(rapChest(R0), 5, 0xffffff); textTag(rapChest(R0).add(V(0, 12, 0)), "AWAKE (a hit wakes it sooner)", "#ffffff", 1.4); }});
    if (two) ev.push({t: WAKE2, f: () => { R1.zzT = 0; flash(rapChest(R1), 5, 0xffffff); }});
    if (p0.tArr < END - 0.3) ev.push({t: p0.tArr - 0.05, f: () => { R0.lunge = 1; later(0.18, () => { popNum(rapChest(S).add(V(0, 5, 0)), 10, "hit"); S.flinch = 0.8; setHp(S, S.hp - 10); }); }});
  } else {
    ev.push({t: FIRE, f: () => throwPod({kind: "bolt", from: partPoint(mouthParts.skull), target: () => rapChest(R0), T: 0.3, H: 0.5, onHit: p => { popNum(p.clone().add(V(0, 5, 0)), 6, "hit"); R0.flinch = 0.5; }})});
    ev.push({t: p0.tArr - 0.05, f: () => { R0.lunge = 1; later(0.18, () => { popNum(rapChest(S).add(V(0, 5, 0)), 10, "hit"); S.flinch = 0.8; setHp(S, S.hp - 10); textTag(rapChest(S).add(V(0, 14, 0)), "IT REACHES THE SQUADMATE", "#ffb0a0", 1.4); }); }});
  }
  let zt = 0;
  return {frame: [V(0, 0, 6), V(0, 0, -76)], keys, ev, eyes: [[T0, FIRE + 0.3]],
    update(t, dt) { NS.sleepKick = Math.max(0, NS.sleepKick - dt * 6); PGLOW.sleep = on ? 0.2 + (t > T0 && t < FIRE ? 1.2 : 0) + NS.sleepKick : 0;
      for (const R of [R0, R1]) R.zz = (R.zz || 0) + ((R.zzT || 0) - (R.zz || 0)) * Math.min(1, dt * 9);
      zt += dt; if (zt > 0.45) { zt = 0; for (const R of [R0, R1]) if (R.zzT > 0) zzz(R); } },
    phases: on ? [[0, T0, "Slotted (takes a slot): the launcher over the +X eye"], [T0, FIRE, "Press: the neck coils back (wind-up)"], [FIRE, HIT, "The head snaps forward, the launcher kicks: a violet dart"], [HIT, WAKE, "Hit: the raptor falls asleep where it stands for " + fmt(c.sleep) + " s" + (two ? "; the dart splits into the one behind it" : "")], [WAKE, END, "It wakes and runs on (any damage wakes it sooner) · " + c.cd + " s recharge"]]
      : [[0, FIRE, "Today: a raptor runs at the hurt squadmate"], [FIRE, p0.tArr, "The troodon's shot: 6 damage, it keeps coming"], [p0.tArr, END, "It reaches the squadmate and bites"]],
    len: END};
}

// Sentry Pod: thrown 18 studs ahead; it unfolds and fires at the nearest enemy; the first one runs out of range and it turns to
// the next; shown for 4.5 s of its time
function sentryTrack() {
  const c = cfgNow("sentry"), on = boostNow(), cc = NK.sentCarry; cc.p0 = null;
  const Pp = V(6, 0, -18);
  place(R0, -6, -58); place(R1, 16, -64); place(S, -20, -4); S.yaw = yawTo(S.pos, V(0, 0, -60));
  R0.yaw = yawTo(R0.pos, Pp); R1.yaw = yawTo(R1.pos, Pp);
  const T0 = 0.6, REL = T0 + 0.34, FLY = 0.5, LAND = REL + FLY, OPEN = LAND + 0.15, F0 = OPEN + 0.5, SHOW = on ? 4.5 : 3, FOLD = F0 + SHOW, END = FOLD + 1.0;
  const RUN = F0 + 1.75, away = V(-34, 0, -96); R0.path = [[0, R0.pos.clone(), R0.yaw, 0], [RUN, R0.pos.clone(), R0.yaw, 0], [RUN + 0.2, R0.pos.clone(), yawTo(R0.pos, away), 1], [RUN + 1.5, away.clone(), yawTo(R0.pos, away), 1]];
  const keys = idleIntro(THROW(T0), T0);
  const GS = 14; let tgt = R0, told = false;
  const ev = [];
  if (on) {
    ev.push({t: T0, f: () => glowAt(() => carryPos(cc), AMBER, 4, REL - T0, 0.7)}, {t: REL, f: () => trailOn(() => carryPos(cc), AMBER, FLY, 40, 1)},
      {t: LAND, f: () => { groundRing(Pp, 6, AMBER, 0.4, 1); }},
      {t: OPEN + 0.3, f: () => { flash(Pp.clone().setY(3), 8, 0xffe2a0); textTag(Pp.clone().add(V(0, 10, 0)), "SENTRY · " + fmt(c.life) + " s · range " + c.range, "#ffd38a", 1.6); }});
    for (let t = F0; t < FOLD - 0.05; t += 0.5) ev.push({t, f: () => {
      const inR = R => R.rig.pos.clone().setY(0).distanceTo(Pp) <= c.range; tgt = inR(R0) ? R0 : R1;
      if (tgt === R1 && !told) { told = true; textTag(rapChest(R0).add(V(0, 10, 0)), "OUT OF RANGE", "#e8eef8", 1.2); textTag(Pp.clone().add(V(0, 8, 0)), "NEXT TARGET", "#ffd38a", 1.0); }
      for (let k = 0; k < c.per; k++) later(k * 0.07, () => { const m = sentryMuzzle(), R = tgt; NS.sentFire = 1; flash(m, 3.2, 0xffe2a0); const off = V((k ? 1 : -1) * (c.per > 1 ? 0.8 : 0), 0, 0);
        throwPod({kind: "bolt", from: m, target: () => rapChest(R).add(off), T: Math.max(0.12, m.distanceTo(rapChest(R)) / 220), H: 0.3, onHit: p => { popNum(p.clone().add(V(0, 5, 0)), c.dmg, "hit"); R.flinch = Math.max(R.flinch, 0.5); R.flash = 0.1; R.flashCol = [1, 0.62, 0.12]; }}); }); }});
    ev.push({t: FOLD + 0.3, f: () => { const p = Pp.clone().setY(2); for (let i = 0; i < 14; i++) puff(p.clone(), V((Math.random() - .5) * 8, 4 + Math.random() * 6, (Math.random() - .5) * 8), 0.9, ZONER, 0.6, 0.8); sparks(p, V(0, 1, 0), 10, ZONER, 0.4); }});
  } else ev.push({t: REL, f: () => throwPod({kind: "pod", from: handsPoint(), target: () => R0.pos.clone().setY(1), T: 0.55, H: 9, onHit: p => zoneAt(p, {self: 0})})});
  return {frame: [V(0, 0, 6), V(0, 0, -64)], keys, ev, eyes: [[T0, REL + 0.3]],
    update(t, dt) { NS.sentFire = Math.max(0, NS.sentFire - dt * 6); PGLOW.sentry = on ? 0.2 + NS.sentFire * 1.4 + (t > T0 && t < REL ? 0.8 : 0) : 0;
      const grounded = on && t > LAND && t < FOLD + 0.3; NS.sentLeg = grounded ? (t < FOLD ? E.back(win(t, LAND, OPEN + 0.25)) : 1 - win(t, FOLD, FOLD + 0.3)) : 0;
      const want = grounded && t > OPEN ? yawTo(Pp, tgt.rig.pos) : 0; let d = want - NS.sentYaw; while (d > Math.PI) d -= 2 * Math.PI; while (d < -Math.PI) d += 2 * Math.PI; NS.sentYaw = grounded ? NS.sentYaw + d * Math.min(1, dt * 12) : 0;
      regrow(cc, on, t, LAND, FOLD + 0.6); },
    post(t) { if (!on) { carryOff(cc); return; }
      throwCarry(cc, t, T0, REL, LAND, Pp.clone().setY(0.6), 7, 3.4, tt => { if (tt > FOLD + 0.3) { carryOff(cc); return; } const k = GS * (tt < OPEN ? 0.55 + 0.45 * E.back(win(tt, LAND, OPEN)) : tt > FOLD ? Math.max(0.01, 1 - win(tt, FOLD, FOLD + 0.3)) : 1);
        carryAt(cc, worldM(Pp.clone().setY((0.04 + 0.19 * NS.sentLeg) * k), 0, k)); }); },
    phases: on ? [[0, T0, "Slotted (takes a slot): the turret folded on the lower back"], [T0, REL, "Press: wind-up, the turret hops into both hands"], [REL, LAND, "Throws it 18 studs (up to 30)"], [LAND, F0, "It lands, kicks out 3 legs, turns to the nearest enemy"], [F0, RUN + 0.6, (c.per > 1 ? "2 pods" : "A pod") + " every 0.5 s, " + c.dmg + " damage each"], [RUN + 0.6, FOLD, "That raptor runs out of range (60 studs): it turns to the next one"], [FOLD, END, "Shown 4.5 s here (it fires for " + fmt(c.life) + " s), then folds and dissolves; a new one builds on the back (" + c.cd + " s recharge)"]]
      : [[0, REL, "Today: no turret"], [REL, END, "The pod throw only"]],
    len: END};
}


// the kit poses every part is measured in (the moves that swing the long arms / tail / legs most): throw wind-up, flaps, glide, run
const KITPH = [["idle", 0, 1.2], ["throw", 1.2, 2.4], ["flaps", 2.4, 3.5], ["glide", 3.5, 4.6], ["run", 4.6, 6.8]];
function kitTrack() {
  const keys = [K(0, T_READY), K(1.2, T_READY), K(1.42, TA_WIND_W, "io"), K(1.55, TA_HOLD_W, "io"), K(1.75, TA_THROW, "in2"), K(2.2, TA_THROW), K(2.6, TF_UP, "io"), K(2.95, TF_DOWN, "in2"), K(3.3, TF_UP, "io"), K(3.7, TF_GLIDE, "out"), K(4.5, TF_GLIDE), K(4.8, T_READY, "io")];
  return {frame: [V(0, 0, 8), V(0, 0, -10)], keys, ev: [],
    update(t) { NS.run = t > 4.7 && t < 6.7 ? Math.min(1, (t - 4.7) / 0.2) : 0; NS.fan = t > 3.5 && t < 4.6 ? 1 : 0; NS.jetTilt = t > 2.4 && t < 3.5 ? rad(40) * (0.5 + 0.5 * Math.sin(t * 9)) : 0; },
    extra(target) { runLayer(target, NS.run, play.t * 13); },
    phases: [[0, 1.2, "Idle (every part on that's ticked)"], [1.2, 2.4, "Pod throw: wind-up (arms back 12° wider), fling"], [2.4, 3.5, "Flaps: up / down strokes"], [3.5, 4.6, "Glide: arms spread"], [4.6, 6.8, "Run (legs and arms at full swing)"]], len: 6.8};
}
function runLayer(target, w, ph) { if (w <= 0) return; const s = Math.sin(ph), c = Math.cos(ph);
  for (const [n, v] of [["LegL", 42 * s], ["LegR", -42 * s], ["KneeL", -(16 + 52 * Math.max(0, c))], ["KneeR", -(16 + 52 * Math.max(0, -c))], ["AnkleL", 18 * Math.max(0, -s)], ["AnkleR", 18 * Math.max(0, s)], ["ArmL", -16 * s], ["ArmR", 16 * s], ["RootJoint", -8 + 2 * Math.abs(c)], ["Neck", -6], ["Head", 6], ["Tail1", -4]]) target[n] = target[n].map((x, i) => i === 0 ? x + v * w : x); }
function walkLayer(target, w, ph) { if (w <= 0) return; const s = Math.sin(ph), c = Math.cos(ph);
  for (const [n, v] of [["LegL", 30 * s], ["LegR", -30 * s], ["KneeL", -(14 + 26 * Math.max(0, c))], ["KneeR", -(14 + 26 * Math.max(0, -c))], ["ArmL", 6 * s], ["ArmR", -6 * s], ["RootJoint", -4]]) target[n] = target[n].map((x, i) => i === 0 ? x + v * w : x); }
function setTrack() { return kitTrack(); }
const BUILD = {bloom: bloomTrack, burst: burstTrack, dome: domeTrack, sleep: sleepTrack, sentry: sentryTrack, set: setTrack, kit: kitTrack};

// ---------- the player ----------
let cur = 0, playing = true, speed = 1, camMode = "close";
const view = {zoom: 1, yaw: 0, pitch: 0}; // the viewer's own zoom / orbit (wheel, pinch, drag, + / - buttons)
const setOn = {}; CID.forEach(p => { setOn[p] = RECSET.includes(p); });
let lookOverride = null, trackOverride = null;
const CUR = () => CANDS[cur];
function lookOn(look) {
  if (lookOverride) return lookOverride.has(look);
  if (LIVE.includes(look)) return liveOn;
  const pid = look.split(".")[0]; if (!CID.includes(pid)) return false;
  const id = CUR().id; if (id === "set") return !!setOn[pid];
  return pid === id && boostNow();
}
function resetFx() { fx.splice(0).forEach(e => scene.remove(e.obj)); tshots.splice(0).forEach(s => { scene.remove(s.mesh); scene.remove(s.glow); }); zones.splice(0).forEach(Z => scene.remove(Z.g)); NZ.splice(0).forEach(Z => scene.remove(Z.g)); selfHeal.splice(0); flies.splice(0).forEach(f => scene.remove(f.obj)); OWNED.splice(0).forEach(o => scene.remove(o)); delayed = []; CARRY.forEach(c => { carryOff(c); c.k = 1; }); }
function start() {
  resetFx(); msReset(); nsReset();
  for (const R of raps) { Object.assign(R, {flinch: 0, flash: 0, push: 0, slow: 0, tagged: false, path: null, run: 0, heal: 0, lunge: 0, bite: 0, show: false, hpShow: false, plume: 0, _bit: 0, up: 0, mark: 0, fastT: 0, amp: 0, noheal: 0, pathSet: 0, zz: 0, zzT: 0, sleepT: 0}); }
  heroBar.on = false; hero.plume = 0;
  play = {track: null, t: 0, fired: new Set()};
  play.track = BUILD[trackOverride || CUR().id]();
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
  R.flinch = Math.max(0, R.flinch - dt * 2.6); R.flash = Math.max(0, R.flash - dt); R.push *= Math.pow(0.03, dt); R.slow = Math.max(0, R.slow - dt); R.heal = Math.max(0, (R.heal || 0) - dt); R.lunge = Math.max(0, (R.lunge || 0) - dt * 2.2); R.mark = Math.max(0, (R.mark || 0) - dt); R.fastT = Math.max(0, (R.fastT || 0) - dt);
  R.runPh += dt * 15 * R.run * slowK;
  const f = E.out(R.flinch), s = Math.sin(R.runPh), c = Math.cos(R.runPh), rn = Math.min(1, R.run), l = Math.max(Math.sin(Math.min(1, R.lunge) * Math.PI), R.bite ? 0.85 : 0);
  const ct = clockT * slowK;
  const zz = R.zz || 0; R.rig.yaw = R.yaw; R.rig.pos.copy(R.pos).addScaledVector(R.pushDir, R.push);
  pose(R.rig, R._A = {RootJoint: [10 * f - 6 * rn - 14 * l - 8 * zz, 0, R.side * 8 * f], Neck: [12 * f - 4 * rn - 22 * l - 30 * zz, R.side * -18 * f + Math.sin(ct * 0.8) * 4 * (1 - f), 0], Head: [10 * f - 12 * zz, 0, 0], Jaw: [R.bite ? -2 : (-22 * f - 34 * l) * (1 - zz), 0, 0],
    ArmL: [-25 * f + 20 * l - 30 * zz, 0, 0], ArmR: [-25 * f + 20 * l - 30 * zz, 0, 0], Tail1: [-10 * f + 12 * zz, Math.sin(ct * 1.3) * 4, 0], Tail2: [0, Math.sin(ct * 1.3 - .7) * 5, 0],
    LegL: [-8 * f + 34 * s * rn + 26 * zz, 0, 0], LegR: [-8 * f - 34 * s * rn + 26 * zz, 0, 0], KneeL: [-10 * f - (18 + 22 * Math.max(0, c)) * rn - 52 * zz, 0, 0], KneeR: [-10 * f - (18 + 22 * Math.max(0, -c)) * rn - 52 * zz, 0, 0]});
  if (R.rig.rest !== null) { R.rig.y = R.rig.rest + Math.abs(c) * 1.2 * rn + (R.up || 0) - 2.4 * zz; pose(R.rig, R._A); } // v0.1: re-pose with the same angles (pose(R.rig, {}) reset every raptor to its rest pose)
  const g = R.slow > 0 ? 0.12 : 0, h = R.heal > 0 ? R.heal / 0.4 : 0, fl = R.flash > 0 ? 1 : 0, mk = R.mark > 0 ? 0.35 + 0.1 * Math.sin(clockT * 6) : 0, am = R.amp > 0 ? 0.12 : 0, nh = R.noheal > 0 ? 0.14 : 0;
  R.rig.mats.forEach(m => m.emissive.setRGB(fl * R.flashCol[0] + (1 - fl) * (g * 0.9 + h * 0.05 + mk * 1.0 + nh * 0.7), fl * R.flashCol[1] + (1 - fl) * (g * 0.55 + h * 0.55 + mk * 0.42 + am * 1.4), fl * R.flashCol[2] + (1 - fl) * (h * 0.12 + am * 0.5 + nh * 1.2)));
  if (zz > 0 && !(R.flash > 0)) { const zt = zz * (0.5 + 0.1 * Math.sin(clockT * 3)); R.rig.mats.forEach(m => m.emissive.setRGB(m.emissive.r + 0.35 * zt, m.emissive.g + 0.15 * zt, m.emissive.b + 0.6 * zt)); }
  if (R.fastT > 0 && Math.random() < dt * 30) { const p = rapChest(R).add(V((Math.random() - .5) * 3, (Math.random() - .5) * 3, 0)); const q = sprite(T_FLASH, 0xc8ffd8, 1.2, true); q.position.copy(p); q.scale.set(0.5, 0.5, 1); addFx(q, 0.35, (o, u) => { o.material.opacity = 0.8 * (1 - u); o.scale.set(0.4, 0.4 + 2.6 * u, 1); }); }
  if (R.bar) { R.bar.s.visible = !!R.hpShow; if (R.hpShow) { R.bar.set(R.hp, R.max || 60, 0, R.amp > 0 ? "#9dffc0" : null); R.bar.s.position.copy(rapChest(R)).add(V(0, 9.5 + (R.up || 0) * 0, 0)); } }
}
function mechLocals() {
  for (const p of MECH) {
    const on = lookOn(p.look);
    let vis = on && (!p.show || p.show());
    let Lm;
    if (p.carry) { const c = p.carry; if (c.on) vis = false; const k = c.k === undefined ? 1 : c.k; if (k < 0.01) vis = false; Lm = segInv[p.seg].clone().multiply(c.F).multiply(scl(Math.max(0.001, k))).multiply(c.Fi).multiply(p.at); }
    else Lm = p.base.clone();
    if (p.part === "shed" && MK[p.look] && MK[p.look].shed && MK[p.look].shed.includes(p)) { if (MS.regrow < 0.01) vis = false; Lm.multiply(scl(Math.max(0.001, MS.regrow))); }
    if (p.anim) Lm.multiply(p.anim(p));
    p.local = Lm; p.mesh.visible = vis;
  }
}

function step(dt, noRender) {
  let mdt = dt * speed;
  if (hitStop > 0) { hitStop -= mdt; mdt *= 0.05; }
  idleT += mdt; clockT += mdt;
  let target = idleLayer(idleT);
  const tr0 = play.track; play.t += mdt;
  const mv = sample(tr0.keys, play.t);
  target = addPose(mv, target, 1);
  const rootFwd = (mv.root && mv.root.fwd) || 0;
  for (const e of (tr0.ev || [])) { const k = "e" + e.t + e.f.toString().length; if (!play.fired.has(k) && play.t >= e.t) { play.fired.add(k); e.f(); } }
  for (let i = delayed.length - 1; i >= 0; i--) if (play.t >= delayed[i].at) { const d = delayed[i]; delayed.splice(i, 1); d.f(); }
  if (tr0.update) tr0.update(play.t, mdt);
  for (const j of hero.joints) if (!target[j.n]) target[j.n] = [0, 0, 0];
  if (tr0.extra) tr0.extra(target);
  const P = springStep(target, mdt);
  for (let i = 0, n = Math.max(1, Math.ceil(mdt * 300)); i < n; i++) { const h = mdt / n; rootSpring.v += (400 * (rootFwd - rootSpring.x) - 2 * 0.9 * 20 * rootSpring.v) * h; rootSpring.x += rootSpring.v * h; }
  const m = tr0.move ? tr0.move(play.t) : {};
  hero.yaw = 0; hero.pos.set(m.x || 0, 0, (m.z || 0) - rootSpring.x);
  mechLocals();
  hero.y = 0; pose(hero, P);
  let minY = Infinity;
  for (const p of heroFeet) for (let i = 0; i < 8; i++) { _c.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(p.mesh.matrix); minY = Math.min(minY, _c.y); }
  hero.y = -minY + (m.up || 0); pose(hero, P);
  if (tr0.post) tr0.post(play.t);
  const eyes = inWin(tr0.eyes, play.t) ? 1 : 0; heroGlow.e += (eyes - heroGlow.e) * Math.min(1, dt * 14);
  if (eyeMat) eyeMat.emissive.setRGB(0.85 * heroGlow.e, 0.42 * heroGlow.e, 0.02 * heroGlow.e);
  heroHeal = Math.max(0, heroHeal - mdt); const hh = heroHeal / 0.45;
  hero.mats.forEach(mm => { if (mm !== eyeMat) mm.emissive.setRGB(0.02 * hh, 0.4 * hh, 0.08 * hh); });
  raps.forEach(R => rapPose(R, mdt));
  allyRing.visible = allyTag.visible = S.show; allyRing2.visible = allyTag2.visible = S2.show;
  if (S.show) { allyRing.position.set(S.rig.pos.x, 0.13, S.rig.pos.z); allyTag.position.copy(rapChest(S)).add(V(0, S.hpShow ? 12.5 : 10, 0)); }
  if (S2.show) { allyRing2.position.set(S2.rig.pos.x, 0.13, S2.rig.pos.z); allyTag2.position.copy(rapChest(S2)).add(V(0, S2.hpShow ? 12.5 : 10, 0)); }
  heroBar.s.visible = false;
  updatePods(mdt); updateZones(mdt); updateNZ(mdt); updateFlies(mdt);
  for (const k in PMAT) { const mt = PMAT[k], g = PGLOW[mt.userData.part] || 0; mt.emissive.setHex(mt.userData.base); mt.emissiveIntensity = g < 0 ? Math.max(0.05, 1 + g) : 1 + g * 1.4 * (0.8 + 0.2 * Math.sin(clockT * 12)); }
  for (let i = fx.length - 1; i >= 0; i--) { const e = fx[i]; const fdt = dt * speed * (hitStop > 0 ? 0.2 : 1); e.t += fdt; const u = Math.min(1, e.t / e.life); e.update(e.obj, u, fdt); if (u >= 1) { scene.remove(e.obj); fx.splice(i, 1); } }
  if (noRender) return;
  render(dt);
}
const heroGlow = {e: 0};
// ShoulderCam 1.8 framing for the troodon at the 2x body: distance = CameraStartZoom 35 x 2 = 70 studs, pitch 12 deg down, right
// shoulder offset; Roblox's default FOV 70 (the parts looks page's game camera, unchanged)
const CAMF = (() => { let top = -Infinity, w0 = Infinity, w1 = -Infinity; for (const b of BODY) for (let i = 0; i < 8; i++) { const q = V((i & 1 ? .5 : -.5) * b.h[0] * 2, (i & 2 ? .5 : -.5) * b.h[1] * 2, (i & 4 ? .5 : -.5) * b.h[2] * 2).applyMatrix4(b.m); top = Math.max(top, q.y); w0 = Math.min(w0, q.x); w1 = Math.max(w1, q.x); }
  top *= 2; const width = (w1 - w0) * 2; return {top, side: Math.max(0.6 * width, 0.9 * top + 1), height: 0.35 * top, focus: 0.75 * top, dist: 70, pitch: rad(12)}; })();
const camPos = new THREE.Vector3(30, 20, 30), camLook = new THREE.Vector3(0, 6, 0);
function partCentre() { const id = CUR().id; const c = new THREE.Vector3(); let n = 0;
  for (const p of MECH) if (p.mesh.visible && !p.bracket && (id === "set" ? CID.includes(p.part) : p.part === id)) { c.add(_pa.setFromMatrixPosition(p.mesh.matrix)); n++; }
  return n ? c.divideScalar(n) : partPoint(hero.segs.Torso[2]); }
const PARTDIR = {bloom: V(0.8, 0.55, 0.5), burst: V(0.55, -0.4, -0.75), dome: V(-1, 0.3, 0.25), sleep: V(0.85, 0.35, -0.6), sentry: V(0.75, 0.6, 0.55), set: V(0.8, 0.5, 0.5)};
function render(dt) {
  const tr0 = play.track;
  shake = Math.max(0, shake - dt * 4.2); fovPunch = Math.max(0, fovPunch - dt * 14);
  const fr = tr0.frame; const mid = fr[0].clone().lerp(fr[1], 0.5).setY(8), span = fr[0].distanceTo(fr[1]) + 12;
  let fov = 38, cp, look, snap = 0.18;
  const hfov = 2 * Math.atan(Math.tan(rad(fov / 2)) * cam.aspect), vfit = span * 0.5 / Math.tan(Math.min(hfov, rad(fov)) / 2);
  const H = heroHRP().add(V(0, 3, 0));
  const dirOf = k => ({close: V(0.85, 0.5, 0.75), side: V(1, 0.14, 0), front: V(0.35, 0.25, -1), top: V(0.1, 1, 0.3)})[k];
  if (camMode === "game") { fov = 70; const f = heroHRP().add(V(0, CAMF.focus, 0)); const back = V(0, Math.sin(CAMF.pitch), Math.cos(CAMF.pitch)).multiplyScalar(CAMF.dist);
    cp = f.clone().add(V(CAMF.side, CAMF.height, 0)).add(back); look = cp.clone().sub(back); snap = 0.3; }
  else if (camMode === "scene") { look = tr0.follow ? H.clone() : mid; cp = look.clone().add(V(1, 0.55, 0.45).normalize().multiplyScalar(tr0.follow ? 60 : vfit * 0.62)); }
  else if (camMode === "part") { const c = partCentre(); look = c; cp = c.clone().add((PARTDIR[CUR().id] || V(0.8, 0.5, 0.5)).clone().normalize().multiplyScalar(CUR().id === "set" ? 16 : 10)); snap = 0.35; }
  else { look = H.clone(); cp = H.clone().add(dirOf(camMode).normalize().multiplyScalar(camMode === "top" ? 34 : 30)); snap = 0.3; }
  { const off = cp.clone().sub(look);
    off.applyAxisAngle(V(0, 1, 0), view.yaw);
    const horiz = Math.hypot(off.x, off.z), el = Math.atan2(off.y, horiz) + view.pitch, len = off.length() * view.zoom;
    const e = Math.max(-0.35, Math.min(1.45, el)), hd = horiz > 1e-4 ? V(off.x / horiz, 0, off.z / horiz) : V(1, 0, 0);
    cp = look.clone().add(hd.multiplyScalar(Math.cos(e) * len)).add(V(0, Math.sin(e) * len, 0)); }
  if (cp.y < 0.8) cp.y = 0.8;
  camPos.lerp(cp, snap); camLook.lerp(look, snap + 0.05);
  const sh = shake * shake * 0.5;
  cam.position.copy(camPos).add(V((Math.random() - .5) * sh, (Math.random() - .5) * sh, (Math.random() - .5) * sh));
  cam.lookAt(camLook); cam.fov = fov + fovPunch; cam.updateProjectionMatrix();
  sun.position.copy(H).add(V(30, 70, 30)); sun.target.position.copy(H);
  renderer.render(scene, cam);
}
function seek(t) { start(); const sp = speed; speed = 1; let n = 0; while (play.t < t - 1e-6 && n < 4000) { step(1 / 60, true); n++; } speed = sp; camSnap(); step(0); }
function camSnap() { for (let i = 0; i < 40; i++) render(0); }
const LEN = () => play.track.len;

// ---------- measurement (the parts looks page's 125-point sample per piece: inside = inside any visible Troodon body box) ----------
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
function floating(look) {
  const ps = MECH.filter(p => p.look === look && p.mesh.visible).map(pieceNow), body = bodyNow(), m = 0.03;
  const touchBody = pn => pn.s.e.some(v => { const w = v.clone().applyMatrix4(pn.p.mesh.matrix); return body.some(b => { _q.copy(w).applyMatrix4(b.inv); return Math.abs(_q.x) <= b.h[0] + m && Math.abs(_q.y) <= b.h[1] + m && Math.abs(_q.z) <= b.h[2] + m; }); });
  const touch = (a, b) => a.s.e.some(v => { _q.copy(v).applyMatrix4(a.p.mesh.matrix).applyMatrix4(b.Wi); return insideShape(b.p.mesh.geometry.userData.shape, _q, m); }) || b.s.e.some(v => { _q.copy(v).applyMatrix4(b.p.mesh.matrix).applyMatrix4(a.Wi); return insideShape(a.p.mesh.geometry.userData.shape, _q, m); });
  const ok = new Set(ps.filter(touchBody)); let grew = true;
  while (grew) { grew = false; for (const a of ps) if (!ok.has(a)) for (const b of ok) if (a.c.distanceTo(b.c) < a.r + b.r && touch(a, b)) { ok.add(a); grew = true; break; } }
  return ps.filter(a => !ok.has(a)).map(a => a.p.name);
}
const pct = x => Math.round(x * 1000) / 10;
function runT(id, each, dtS, trk) { cur = CANDS.findIndex(c => c.id === id); trackOverride = trk || null; start(); const len = LEN(); let nextT = 0;
  while (play.t < len) { step(1 / 60, true); if (play.t >= nextT) { nextT += dtS; each(play.t); } } trackOverride = null; }
function measureAll() {
  const out = {version: NP_VERSION, when: new Date().toISOString().slice(0, 16), looks: {}, rec: {}, alt: {}, gaps: {}};
  const save = {cur, mode, rank, liveOn, speed}; speed = 1; mode = "boost"; rank = 3;
  for (const id of CID) {
    const look = id + ".A"; lookOverride = new Set([look]);
    const r = {idle: 0, move: 0, idleWorst: "", moveWorst: "", bracketIdle: 0, bracketMove: 0, pieces: 0, brackets: 0, floating: [], kit: {}, kitWorst: {}};
    let flDone = false;
    runT(id, t => { const body = bodyNow(); const idle = t < 0.58;
      for (const p of MECH) { if (p.look !== look || !p.mesh.visible) continue; const s = shareInBody(pieceNow(p), body), key = p.bracket ? (idle ? "bracketIdle" : "bracketMove") : (idle ? "idle" : "move");
        if (s > r[key]) { r[key] = s; if (!p.bracket) r[idle ? "idleWorst" : "moveWorst"] = p.name + " " + pct(s) + "% at " + t.toFixed(2) + " s"; } }
      if (!flDone && t > 0.3) { flDone = true; r.floating = floating(look); r.pieces = MECH.filter(p => p.look === look && !p.bracket).length; r.brackets = MECH.filter(p => p.look === look && p.bracket).length; } }, 0.05);
    KITPH.forEach(k => { r.kit[k[0]] = 0; });
    cur = CANDS.findIndex(c => c.id === "set"); trackOverride = "kit"; lookOverride = new Set([look]); start();
    while (play.t < LEN()) { step(1 / 60, true); const ph = KITPH.find(k => play.t >= k[1] && play.t < k[2]); if (!ph) continue; const body = bodyNow();
      for (const p of MECH) { if (p.look !== look || !p.mesh.visible || p.bracket) continue; const s = shareInBody(pieceNow(p), body); if (s > r.kit[ph[0]]) { r.kit[ph[0]] = s; r.kitWorst[ph[0]] = p.name + " " + pct(s) + "% at " + play.t.toFixed(2) + " s"; } } }
    trackOverride = null;
    ["idle", "move", "bracketIdle", "bracketMove"].forEach(k => { r[k] = pct(r[k]); }); for (const k in r.kit) r.kit[k] = pct(r.kit[k]);
    r.worst = Math.max(r.idle, r.move, ...Object.values(r.kit));
    out.looks[look] = r;
  }
  // clash, the recommended set + the 5 live button looks: every recommended part's move + the kit poses
  const recSet = new Set([...RECSET.map(p => p + ".A"), ...LIVE]); const pairMax = {};
  const clashFrame = (set, rec, only) => { const ps = MECH.filter(p => set.has(p.look) && p.mesh.visible).map(pieceNow);
    for (const a of ps) { if (only && a.p.look !== only) continue; const others = ps.filter(b => b.p.look !== a.p.look); const s = shareInPieces(a, others); if (s > 0) { for (const b of others) { if (shareInPieces(a, [b]) > 0) { const k = [a.p.look, b.p.look].sort().join(" × "); rec[k] = Math.max(rec[k] || 0, s); } } } } };
  for (const id of RECSET) { lookOverride = recSet; runT(id, () => clashFrame(recSet, pairMax), 0.05); }
  lookOverride = recSet; runT("set", () => clashFrame(recSet, pairMax), 1 / 60, "kit");
  out.rec = Object.fromEntries(Object.entries(pairMax).map(([k, v]) => [k, pct(v)]));
  // each alternative with the recommended set + the live looks on (its move + the kit poses)
  for (const id of CID.filter(i => !RECSET.includes(i))) { const set = new Set([...recSet, id + ".A"]); const mx = {}; lookOverride = set; runT(id, () => clashFrame(set, mx), 0.05); lookOverride = set; runT("set", () => clashFrame(set, mx), 1 / 30, "kit");
    out.alt[id] = Object.fromEntries(Object.entries(mx).map(([k, v]) => [k, pct(v)]).filter(([k]) => k.includes(id + ".A"))); }
  // closest gap at rest between each new look and every other on-body look (recommended + live)
  lookOverride = new Set([...CID.map(p => p + ".A"), ...LIVE]); cur = CANDS.findIndex(c => c.id === "set"); trackOverride = "kit"; start(); for (let i = 0; i < 20; i++) step(1 / 60, true); trackOverride = null;
  const ps = MECH.filter(p => lookOverride.has(p.look) && p.mesh.visible).map(pieceNow);
  for (const id of CID) { const mine = ps.filter(q => q.p.look === id + ".A"), others = ps.filter(q => q.p.look !== id + ".A" && (LIVE.includes(q.p.look) || RECSET.includes(q.p.part))); let best = Infinity, who = "";
    for (const a of mine) for (const b of others) { if (a.c.distanceTo(b.c) > a.r + b.r + 3) continue; for (const v of a.s.e) { const w = v.clone().applyMatrix4(a.p.mesh.matrix); for (const u of b.s.e) { const d = w.distanceTo(_pb.copy(u).applyMatrix4(b.p.mesh.matrix)); if (d < best) { best = d; who = b.p.look; } } } }
    out.gaps[id] = {studs: Math.round(best * 2 * 100) / 100, to: who}; }
  lookOverride = null; cur = save.cur; mode = save.mode; rank = save.rank; liveOn = save.liveOn; speed = save.speed; renderAll(); start();
  return out;
}
const MEAS = typeof NP_MEAS !== "undefined" ? NP_MEAS : null;

// ---------- UI ----------
const NAME = id => CANDS.find(c => c.id === id).name;
const LOOKNAME = {"mender.A": "Mender Drone", "lantern.A": "Arc Lantern", "sapwall.B": "Sap Wall", "shed.A": "Feather Shed", "portal.A": "Portal Rift"};
const lookLabel = l => LOOKNAME[l] || NAME(l.split(".")[0]);
const srcLinks = keys => keys.map(k => `<a href="${SRC[k][1]}" target="_blank" rel="noopener">${SRC[k][0]}</a>`).join(" · ");
function fitTable(id) {
  if (!MEAS || !MEAS.looks[id + ".A"]) return '<p class="note">Fit not measured in this build.</p>';
  const r = MEAS.looks[id + ".A"], c = v => `<span class="${v <= 5 ? "ok" : "badn"}">${v}%</span>`;
  const clashes = RECSET.includes(id) ? Object.entries(MEAS.rec || {}).filter(([k]) => k.split(" × ").includes(id + ".A")) : Object.entries((MEAS.alt || {})[id] || {});
  const g = (MEAS.gaps || {})[id];
  return `<h3>Fit (measured on this page's geometry)</h3><div class="tw"><table class="cmp">
    <tr><th>Worst piece inside the body</th><td class="n">${c(r.idle)} idle · ${c(r.move)} in its move (★)</td></tr>
    <tr><th>Kit poses</th><td class="n">throw wind-up ${c(r.kit.throw)} · flaps ${c(r.kit.flaps)} · glide ${c(r.kit.glide)} · run ${c(r.kit.run)}</td></tr>
    <tr><th>Worst piece</th><td>${r.moveWorst || Object.values(r.kitWorst)[0] || "none inside"}</td></tr>
    <tr><th>Pieces / brackets</th><td>${r.pieces} / ${r.brackets} (brackets ${r.bracketIdle}% · ${r.bracketMove}%: set into the surface on purpose)</td></tr>
    <tr><th>Floating pieces</th><td>${r.floating.length ? '<span class="badn">' + r.floating.join(", ") + "</span>" : '<span class="ok">none</span>'}</td></tr>
    <tr><th>Clips another part</th><td>${clashes.length ? '<span class="badn">' + clashes.map(([k, v]) => k.split(" × ").map(lookLabel).join(" × ") + " " + v + "%").join(", ") + "</span>" : '<span class="ok">none</span> (with the ' + (RECSET.includes(id) ? "other 4 picked" : "5 picked") + " + the 5 button parts, in its move and the kit poses)"}</td></tr>
    ${g ? `<tr><th>Closest other part at rest</th><td class="n">${g.studs} studs (${lookLabel(g.to)})</td></tr>` : ""}</table></div>
    <p class="note">${r.worst <= 5 ? "Passes the ≤ 5% rule" : "Over the 5% rule"} (worst ${r.worst}%). Measured ${MEAS.when} UTC, page v${MEAS.version}.</p>`;
}
function renderRec() {
  const recs = CANDS.filter(c => c.rec);
  $("recCard").innerHTML = `<div class="kind" style="color:var(--good)">Kepu's picks · Bloom Tank (passive, no slot) + 4 slot parts</div>
    <ol>${recs.map(c => `<li><b>${c.name}</b> (${c.kind === "PASSIVE" ? "passive, no slot" : "button, takes a slot"} · ${c.covers.toLowerCase()}): ${c.one}</li>`).join("")}</ol>
    <p class="note"><b>Slots:</b> the troodon has 4 slots. With these 4 buttons it has 9 slot parts to choose from (these 4 + Mender Drone, Arc Lantern, Sap Wall, Feather Shed, Portal Rift), so a player picks 4 of the 9. Bloom Tank takes no slot. None of the 4 repeats a live button: no single-target heal (Mender), no chain stun (Lantern; Sleep Dart stops one enemy until it's hit), no wall (Sap Wall; the dome only stops enemy shots and you walk through it), no break-free (Shed), no teleport (Rift).</p>`;
}
function renderAll() {
  const c = CUR(), id = c.id;
  $("moves").innerHTML = CANDS.map((m, i) => `<button class="tab" data-i="${i}" aria-pressed="${i === cur}">${m.rec ? '<span class="star" title="Picked">★</span>' : ""}${m.code ? m.code + " · " : ""}${m.name}<small>${m.kind === "PASSIVE" ? '<span class="pill pas">Passive</span>' : m.kind === "BUTTON" ? '<span class="pill btn2">Button</span>' : ""}${m.covers}</small></button>`).join("");
  $("rankRow").innerHTML = RANKS.map((r, i) => `<button class="chip" data-rank="${i}" aria-pressed="${i === rank}">${r}</button>`).join("");
  document.querySelectorAll("[data-mode]").forEach(b => b.setAttribute("aria-pressed", b.dataset.mode === mode));
  $("liveChip").setAttribute("aria-pressed", liveOn); $("liveChip").textContent = liveOn ? "5 button parts on" : "5 button parts off";
  const ph = play ? play.track.phases : [];
  $("phases").innerHTML = ph.map(p => `<button class="ph" data-t="${p[0]}" aria-current="false"><i>${p[0].toFixed(2)}–${p[1].toFixed(2)} s</i>${p[2]}</button>`).join("");
  if (id === "set") {
    $("info").innerHTML = `<div class="kind" style="color:var(--good)">Clash check</div><h2>Every ticked part on at once</h2><p class="note">Bloom Tank takes no slot; the 4 picked buttons fill the 4 slots, so this is that full loadout on at once. Tick any candidate; the 5 button parts follow the chip above. It cycles idle → pod throw → flaps → glide → run, the poses that move the arms, tail and legs most.</p>
      <div class="row">${CID.map(p => `<button class="chip" data-chip="${p}" aria-pressed="${!!setOn[p]}">${NAME(p)}</button>`).join("")}</div>`;
    let m = '<div class="kind">Measured clashes</div>';
    if (MEAS) { const recP = Object.entries(MEAS.rec || {}).filter(([, v]) => v > 0);
      m += `<p><b>The 5 picked parts + the 5 live button parts</b>, every picked part's move + the kit poses: ${recP.length ? '<span class="badn">' + recP.map(([k, v]) => k.split(" × ").map(lookLabel).join(" × ") + " " + v + "%").join(", ") + "</span>" : '<span class="ok">no piece of one part inside a piece of another (0%)</span>'}.</p>`;
      m += `${CID.some(i => !RECSET.includes(i)) ? "<p><b>Each alternative added to that set:</b></p>" : ""}<ul>${CID.filter(i => !RECSET.includes(i)).map(i => { const a = Object.entries((MEAS.alt || {})[i] || {}); return `<li>${NAME(i)}: ${a.length ? '<span class="badn">' + a.map(([k, v]) => k.split(" × ").map(lookLabel).join(" × ") + " " + v + "%").join(", ") + "</span>" : '<span class="ok">0%</span>'}</li>`; }).join("")}</ul>`;
      m += `<div class="tw"><table class="cmp"><tr><th>Part</th><th>Worst in body (idle / move / throw / flaps / glide / run)</th><th>Closest part at rest</th></tr>${CID.map(i => { const r = MEAS.looks[i + ".A"], g = MEAS.gaps[i]; return `<tr><th>${NAME(i)}</th><td class="n">${r.idle} / ${r.move} / ${r.kit.throw} / ${r.kit.flaps} / ${r.kit.glide} / ${r.kit.run} %</td><td class="n">${g.studs} studs · ${lookLabel(g.to)}</td></tr>`; }).join("")}</table></div>`; }
    else m += '<p class="note">Not measured in this build.</p>';
    $("part").innerHTML = m; return;
  }
  const kindTxt = c.kind === "PASSIVE" ? "Passive · no button · no slot" : "Button · takes a slot";
  const rows = RANKS.map((r, i) => `<tr class="${i === rank ? "cur" : ""}"><th>${r}</th><td>${c.steps[i]}</td></tr>`).join("");
  const today = cmpRows(id);
  $("info").innerHTML = `<div class="kind" style="color:${c.kind === "PASSIVE" ? "#14a58c" : "#c25e08"}">${c.code} · ${kindTxt} · boosts: ${c.covers}${c.locked ? ' <span class="rec">Locked in</span>' : c.rec ? ' <span class="rec">Picked</span>' : ""}</div><h2>${c.name}</h2><p>${c.one}</p>
    <h3>Steps (proposed; the 35% rule)</h3><div class="tw"><table class="cmp">${rows}</table></div><p class="note">${c.check}.</p>
    <h3>Today vs with the part</h3><div class="tw"><table class="cmp"><tr><th></th><th>Today</th><th>${RANKS[rank]}</th></tr>${today}</table></div>
    <h3>Visible every time</h3><p>${c.every}</p>
    <h3>Inspiration (the component it borrows)</h3><ul>${c.insp.map(q => `<li><b>${q[0]}</b>: ${q[1]} (${srcLinks(q[2])})</li>`).join("")}</ul><p><b>Borrowed:</b> ${c.borrow}</p>
    <h3>VFX, in Roblox pieces</h3><p class="note">${c.roblox}</p><p class="note"><b>Follows:</b> ${c.follows}</p>`;
  $("part").innerHTML = `<div class="kind">Where it sits</div><p>${SPOT[id]}</p><ul>${NOTES[id].map(n => `<li>${n}</li>`).join("")}</ul>
    <h3>What you see, in order</h3><ul>${ph.map(p => `<li>${p[2]}</li>`).join("")}</ul>${fitTable(id)}`;
}
function cmpRows(id) {
  const a = CFG[id](-1), b = CFG[id](rank);
  const L = {bloom: [["Zone width (studs)", "R", v => fmt(v * 2)], ["Zone time (s)", "life"], ["End bloom", "bloom", v => v ? "yes" : "no"]],
    burst: [["Burst heal", "heal", (v, o) => o.on ? "+" + v : "none"], ["Heal boost (s)", "amp", (v, o) => o.on ? fmt(v) : "none"], ["Width (studs)", "R", (v, o) => o.on ? v * 2 : "—"], ["Recharge (s)", "cd", (v, o) => o.on ? v : "—"]],
    dome: [["Dome width (studs)", "R", (v, o) => o.on ? fmt(v * 2) : "no dome"], ["Lasts (s)", "life", (v, o) => o.on ? fmt(v) : "—"], ["Enemy shots blocked", "on", v => v ? "yes (yours go out)" : "no"], ["Recharge (s)", "cd", (v, o) => o.on ? fmt(v) : "—"]],
    sleep: [["Sleep (s)", "sleep", (v, o) => o.on ? fmt(v) : "no sleep"], ["Enemies put to sleep", "n", (v, o) => o.on ? v : 0], ["Recharge (s)", "cd", (v, o) => o.on ? fmt(v) : "—"]],
    sentry: [["Turret lasts (s)", "life", (v, o) => o.on ? fmt(v) : "no turret"], ["Damage", "dmg", (v, o) => o.on ? v + " every 0.5 s" : "—"], ["Pods per shot", "per", (v, o) => o.on ? v : "—"], ["Range (studs)", "range", (v, o) => o.on ? v : "—"], ["Recharge (s)", "cd", (v, o) => o.on ? fmt(v) : "—"]]}[id];
  return L.map(([n, k, f]) => `<tr><th>${n}</th><td class="n">${f ? f(a[k], a) : fmt(a[k])}</td><td class="n">${f ? f(b[k], b) : fmt(b[k])}</td></tr>`).join("");
}
function foot() {
  $("foot").innerHTML = `<b>Notes</b><ol>
  <li><b>Kepu's picks (2026-11-10).</b> 01:33 "Bloom Tank for sure" (passive: no button, no slot, always on once bought). 01:40 from the 20-idea list: #1 Bloom Burst, #3 Shield Dome, #7 Sleep Dart, #14 Sentry Pod (buttons: each takes a slot).</li>
  <li><b>Numbers are proposals</b> (the 35% rule: every step at least 1.35x the one before). Live kit today: TroodonModelData 1.10 (pod 6, zone 40 studs / 3 s / 1 per s / squad +5 per s / slow 25%, 3 charges refilling 2 s). Enemy shots in the dome scene are drawn as 8 damage each, a stand-in.</li>
  <li><b>Readability.</b> Each part is 1–3 big shapes on posts and brackets on the body surface, one accent per job (zone teal, heal green, shield blue, sleep violet, pod amber), and it glows or moves on the press. Checked up close and from the 70-stud game camera.</li>
  <li><b>Inspiration only.</b> The games named on each card give the idea; no shape, texture or colour scheme is copied. Sources were looked up for this page (links on each card).</li>
  <li><b>VFX consistency.</b> Pods, splats and zones are the live TrooFX ones; heals are the Med-Station's green MedWave + MedHealPop; rings follow TenoMovesFX's flat neon rings; the sleep uses the Arc Lantern's StunnedUntil stun with a wake-on-hit rule. Thrown parts follow the pod arc. No landing FX anywhere.</li>
  <li><b>Fit measurement.</b> Each piece is sampled at 125 points through its volume; inside = inside any visible Troodon body box. Idle and the move every 0.05 s at ★; the kit poses every frame (throw wind-up, flaps, glide, run). Brackets sit 40% into the surface on purpose and are listed apart. Clashes: every piece against every other part's pieces, the 5 picked + the 5 live button looks, in every picked move and the kit poses. Source: tools/troodon_slotparts_mockup/slotparts.js (window.__np.measure), run by measure.js.</li>
  <li><b>Game camera</b> = ShoulderCam 1.8 for the troodon at the 2x body: 70 studs back, 12° down, right shoulder, FOV 70.</li></ol>`;
}
function setMode(m) { mode = m; cphase = m === "compare" ? 0 : cphase; start(); renderAll(); }
$("moves").addEventListener("click", e => { const b = e.target.closest("[data-i]"); if (!b) return; cur = +b.dataset.i; cphase = 0; start(); renderAll(); });
$("rankRow").addEventListener("click", e => { const b = e.target.closest("[data-rank]"); if (!b) return; rank = +b.dataset.rank; start(); renderAll(); });
document.querySelectorAll("[data-mode]").forEach(b => b.onclick = () => setMode(b.dataset.mode));
$("liveChip").onclick = () => { liveOn = !liveOn; renderAll(); };
$("part").addEventListener("click", e => { const b = e.target.closest("[data-chip]"); if (!b) return; setOn[b.dataset.chip] = !setOn[b.dataset.chip]; renderAll(); });
$("info").addEventListener("click", e => { const b = e.target.closest("[data-chip]"); if (!b) return; setOn[b.dataset.chip] = !setOn[b.dataset.chip]; renderAll(); });
$("phases").addEventListener("click", e => { const b = e.target.closest("[data-t]"); if (!b) return; seek(+b.dataset.t + 0.06); playing = false; syncPlay(); });
$("play").onclick = () => { playing = !playing; syncPlay(); };
$("again").onclick = () => { start(); playing = true; syncPlay(); };
function syncPlay() { $("play").textContent = playing ? "Pause" : "Play"; $("play").setAttribute("aria-pressed", playing); }
document.querySelectorAll("[data-speed]").forEach(b => b.onclick = () => { speed = +b.dataset.speed; document.querySelectorAll("[data-speed]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
const CAMNAME = {game: "Game camera (ShoulderCam, 70 studs)", close: "3/4 close", side: "Side (+X)", front: "Front", top: "Top", part: "Part close-up", scene: "Whole move"};
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => { camMode = b.dataset.view; document.querySelectorAll("[data-view]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
$("scrub").addEventListener("input", e => { seek(+e.target.value / 1000 * LEN()); playing = false; syncPlay(); });
const THEMES = ["auto", "light", "dark"]; let themeI = 0;
$("theme").onclick = () => { themeI = (themeI + 1) % 3; const t = THEMES[themeI]; if (t === "auto") document.documentElement.removeAttribute("data-theme"); else document.documentElement.setAttribute("data-theme", t); $("theme").textContent = "Theme: " + t; };
$("ver").textContent = "v" + NP_VERSION;
function resize() { const w = cv.clientWidth, h = cv.clientHeight; if (renderer.domElement.width !== Math.round(w * renderer.getPixelRatio())) { renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); } }
window.addEventListener("resize", resize);
function overlays() {
  $("scrub").value = Math.round(Math.min(1, play.t / LEN()) * 1000);
  $("clock").textContent = `${play.t.toFixed(2)} s${speed !== 1 ? " · 0.3×" : ""}`; $("camtag").textContent = CAMNAME[camMode];
  const ph = play.track.phases.find(p => play.t >= p[0] && play.t < p[1]);
  $("cap").textContent = ph ? ph[2] : "…";
  document.querySelectorAll(".ph").forEach(b => b.setAttribute("aria-current", !!ph && +b.dataset.t === ph[0]));
  const mt = $("modetag"), id = CUR().id; mt.hidden = id === "set";
  if (id !== "set") { const b = boostNow(); mt.className = "modetag " + (b ? "boost" : "today"); mt.textContent = b ? "WITH " + CUR().name.toUpperCase() + " · " + RANKS[rank] + (ghostNow() ? " · dashed = today" : "") : "TODAY · no part"; }
  const hd = $("hud"); const hs = NS.hud; hd.hidden = !hs;
  if (hs) hd.innerHTML = "POD " + Array.from({length: 6}, (_, i) => i < hs.max ? `<i class="${i < hs.n ? "on" : ""}"></i>` : "").join("") + (hs.n < hs.max ? `<span class="rf"><b style="width:${Math.round(hs.u * 100)}%"></b></span>` : "");
}
let last = performance.now();
function loop(now) {
  const dt = Math.min(0.05, (now - last) / 1000); last = now;
  resize();
  if (!window.__manual) { if (playing) { step(dt); if (play.t >= LEN()) { if (mode === "compare") cphase = 1 - cphase; start(); renderAll(); } } else step(0); }
  overlays();
  requestAnimationFrame(loop);
}
start(); renderRec(); renderAll(); foot(); resize();
requestAnimationFrame(loop);
// test hooks: __np.set(id, mode, rank, t, cam) seeks there and pauses; __np.measure() returns the fit / clash numbers
window.__np = {set(id, md, rk, time, cm, ph) { window.__manual = true; cur = CANDS.findIndex(c => c.id === id); mode = md || "boost"; cphase = ph === undefined ? 1 : ph; if (rk !== undefined) rank = rk; if (cm) camMode = cm; view.zoom = 1; view.yaw = 0; view.pitch = 0; start(); renderAll(); seek(time); overlays(); },
  frame(dt) { step(dt); overlays(); }, view, measure: () => { window.__manual = true; return measureAll(); }, len: () => LEN(), cap: () => $("cap").textContent, state: () => ({t: play.t, fx: fx.length, vis: MECH.filter(p => p.mesh.visible).length})};
window.__ready = true;
// ---------- viewer zoom / orbit: wheel, pinch, drag, + / - buttons (on the whole stage) ----------
(function () {
  const st = document.getElementById("cv").parentNode, clampZ = z => Math.max(0.15, Math.min(3.5, z));
  st.addEventListener("wheel", e => { e.preventDefault(); view.zoom = clampZ(view.zoom * Math.exp(e.deltaY * 0.0012)); }, {passive: false});
  const pts = new Map(); let pinch0 = 0, zoom0 = 1;
  st.addEventListener("pointerdown", e => { if (e.target.closest(".zoomctl")) return; st.setPointerCapture(e.pointerId); pts.set(e.pointerId, {x: e.clientX, y: e.clientY});
    if (pts.size === 2) { const [a, b] = [...pts.values()]; pinch0 = Math.hypot(a.x - b.x, a.y - b.y); zoom0 = view.zoom; } });
  st.addEventListener("pointermove", e => { const p = pts.get(e.pointerId); if (!p) return;
    if (pts.size === 1) { view.yaw -= (e.clientX - p.x) * 0.008; view.pitch = Math.max(-0.7, Math.min(1.1, view.pitch + (e.clientY - p.y) * 0.006)); }
    p.x = e.clientX; p.y = e.clientY;
    if (pts.size === 2 && pinch0 > 0) { const [a, b] = [...pts.values()]; view.zoom = clampZ(zoom0 * pinch0 / Math.max(1, Math.hypot(a.x - b.x, a.y - b.y))); } });
  const up = e => { pts.delete(e.pointerId); if (pts.size < 2) pinch0 = 0; };
  st.addEventListener("pointerup", up); st.addEventListener("pointercancel", up);
  const bar = document.createElement("div"); bar.className = "zoomctl"; bar.setAttribute("aria-label", "Zoom");
  bar.innerHTML = '<button type="button" id="zin" aria-label="Zoom in">+</button><button type="button" id="zout" aria-label="Zoom out">&minus;</button><button type="button" id="zreset" aria-label="Reset view">Reset</button>';
  st.appendChild(bar);
  document.getElementById("zin").onclick = () => { view.zoom = clampZ(view.zoom * 0.7); };
  document.getElementById("zout").onclick = () => { view.zoom = clampZ(view.zoom / 0.7); };
  document.getElementById("zreset").onclick = () => { view.zoom = 1; view.yaw = 0; view.pitch = 0; };
})();