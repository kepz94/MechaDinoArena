// troodon_newparts.js v0.1 (Mecha Dino Arena) — Troodon NEW parts options mockup (Kepu 2026-11-10: the 4 passives Last Feather,
// Overheal Plume, Fortify Field, Ricochet Pod removed; "4 new ones, shown as options in a mockup like we usually do").
// Rules (Kepu): a PASSIVE has no button and takes NO slot (like the raptor's Blade Claws): always on once bought, visible hardware,
// makes a core move stronger every time; a BUTTON takes a slot. Nothing that only triggers in rare situations; no overlap with the
// live buttons (Mender Drone, Arc Lantern, Sap Wall, Feather Shed, Portal Rift).
// Built on the Troodon parts looks pipeline: engine = tools/troodon_kit_mockup/engine_part.js + app_tail.js up to "tracks";
// then tools/mockup/troodon_parts_looks.js up to its "extra key poses" (the piece / bracket / seat / carry helpers and the 9 old
// part meshes: the 5 live button looks are shown with "5 button parts on"); then this file. Build:
// python3 tools/troodon_newparts_mockup/build.py <three.min.js r128>. Fit: window.__np.measure() (tools/troodon_newparts_mockup/
// measure.js writes measure.json, baked in by the build). Every move: wind-up -> action -> result -> recovery; no landing FX.
const NP_VERSION = "0.1";

// ---------- new-part state ----------
const NS = {};
function nsReset() { Object.assign(NS, {drumA: 0, drumT: 0, cham: [1, 1, 1, 1, 1, 1], charges: 6, refillU: 1, fill: 1, jetTilt: 0, jetFire: 0, jetIdle: 0, hornPulse: 0, fan: 0, lens: 0, bud: 1, petal: 0, vent: 1, ventOpen: 0, ventSpin: 0, walk: 0, walkPh: 0, run: 0, runPh: 0, hud: null}); }
nsReset();
const rotAbout = (at, c, Rm) => at.clone().invert().multiply(T3(c.x, c.y, c.z)).multiply(Rm).multiply(T3(-c.x, -c.y, -c.z)).multiply(at);
const fmt = n => (Math.abs(n - Math.round(n)) < 1e-6 ? String(Math.round(n)) : String(Number(n.toFixed(2))));
const NK = {}; // named points per new look (model space, scale 1)
const LIVE = ["mender.A", "lantern.A", "sapwall.B", "shed.A", "portal.A"]; // the 5 live button looks (TrooPartsLooks 1.0)

// ===== N1 · Pod Drum (passive · the pod): a 6-chamber revolver drum across the shoulders, on a cradle bridged over the crest
// behind the neck. Lit chambers = pods loaded; it turns one chamber per throw and relights as pods refill. =====
const CHAM = [0, 1, 2, 3, 4, 5].map(() => lam(0xffc35a, {emissive: 0xb85a00}));
(() => {
  const lk = "drum.A", z = -1.05;
  for (const s of [1, -1]) { const h = topHit(0.21 * s, z, b => b.seg === "Torso" && notThin(b)); const F = bracket(lk, "Torso", h, 0.15, 0.26, 0.05);
    const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Torso", G.box(0.09, 1.02 - y0, 0.16), MAT.gun, T3(0.21 * s, (y0 + 1.02) / 2, z)); }
  piece(lk, "Torso", G.box(0.88, 0.07, 0.3), MAT.gun, T3(0, 1.052, z));
  for (const s of [1, -1]) { piece(lk, "Torso", G.box(0.06, 0.5, 0.3), MAT.gun, T3(0.41 * s, 1.335, z)); piece(lk, "Torso", G.cylX(0.075, 0.075, 0.07), MAT.brass, T3(0.465 * s, 1.42, z)); }
  const C = V(0, 1.42, z); NK.drumC = C;
  const spin = {anim: p => rotAbout(p.at, C, rotX(NS.drumA))};
  piece(lk, "Torso", G.cylX(0.255, 0.255, 0.7), MAT.gun, T3(C.x, C.y, C.z), spin);
  for (const x of [-0.25, 0.25]) piece(lk, "Torso", G.cylX(0.268, 0.268, 0.06), MAT.brass, T3(x, C.y, C.z), spin);
  NK.cham = [];
  for (let i = 0; i < 6; i++) { const a = i * Math.PI / 3; const at = T3(0, C.y + Math.cos(a) * 0.2, C.z - Math.sin(a) * 0.2);
    for (const x of [-0.12, 0.12]) NK.cham.push({i, p: piece(lk, "Torso", G.sph(0.105), CHAM[i], T3(x, 0, 0).premultiply(at), spin)}); }
})();

// ===== N2 · Bloom Tank (passive · the zone): a big see-through teal tank lying on the tail base (Tail1) on a two-hoop cradle;
// its fluid is the zone: it drops a little on every throw, glows while the zone is up, vents at the end. =====
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

// ===== N3 · Wing Jets (passive · the flaps): two swivel thrusters on a saddle over the lower back, a fuel cell between them;
// on every wing beat they swing down and fire. =====
(() => {
  const lk = "jets.A", z = 0.42;
  for (const s of [1, -1]) { const h = topHit(0.2 * s, z, onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.15, 0.34, 0.05);
    const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Torso", G.box(0.09, 0.82 - y0, 0.2), MAT.gun, T3(0.2 * s, (y0 + 0.82) / 2, z)); }
  piece(lk, "Torso", G.box(0.78, 0.07, 0.3), MAT.gun, T3(0, 0.855, z));
  piece(lk, "Torso", G.box(0.24, 0.2, 0.34), MAT.plate, T3(0, 0.99, z));
  piece(lk, "Torso", G.box(0.16, 0.03, 0.24), gm("jets", "teal"), T3(0, 1.105, z));
  NK.jet = [];
  for (const s of [1, -1]) { const pv = V(0.39 * s, 0.97, z); const sw = {anim: p => rotAbout(p.at, pv, rotX(NS.jetTilt))};
    piece(lk, "Torso", G.box(0.08, 0.1, 0.12), MAT.dark, T3(0.39 * s, 0.92, z));
    const B = AT(pv.x, pv.y + 0.03, pv.z + 0.02, 22, 0, 0);
    piece(lk, "Torso", G.cylZ(0.13, 0.13, 0.5), MAT.gun, B.clone(), sw);
    piece(lk, "Torso", G.tor(0.13, 0.03), MAT.brass, B.clone().multiply(T3(0, 0, -0.25)), sw);
    piece(lk, "Torso", G.cylZ(0.165, 0.11, 0.14), MAT.brass, B.clone().multiply(T3(0, 0, 0.31)), sw);
    piece(lk, "Torso", G.cylZ(0.11, 0.11, 0.02), gm("jets", "teal"), B.clone().multiply(T3(0, 0, 0.38)), sw);
    NK.jet.push({pv, B}); }
})();
function jetWorld(i, dz) { const j = NK.jet[i]; return V(0, 0, 0).applyMatrix4(new THREE.Matrix4().makeTranslation(hero.pos.x, hero.y, hero.pos.z).multiply(scl(hero.scale)).multiply(hero.W.Torso).multiply(segInv.Torso)
  .multiply(T3(j.pv.x, j.pv.y, j.pv.z)).multiply(rotX(NS.jetTilt)).multiply(T3(-j.pv.x, -j.pv.y, -j.pv.z)).multiply(j.B).multiply(T3(0, 0, dz))); }
function jetMouth(i) { return jetWorld(i, 0.42); }
function jetDir(i) { return jetWorld(i, 1.2).sub(jetWorld(i, 0.42)).normalize(); }

// ===== N4 · Chorus Horn (passive · healing): a brass horn clamped along the top of the tail (Tail3), its bell turned up behind
// the dino; every heal you give plays a note: a green ring from the bell. =====
(() => {
  const lk = "horn.A";
  for (const z of [3.58, 4.08]) { const h = topHit(0, z, onSeg("Tail3")); const F = bracket(lk, "Tail3", h, 0.22, 0.16, 0.05);
    const y0 = V(0, 0, 0).applyMatrix4(F).y; piece(lk, "Tail3", G.box(0.09, 0.8 - y0, 0.1), MAT.gun, T3(0, (y0 + 0.8) / 2, z)); }
  piece(lk, "Tail3", G.cylZ(0.085, 0.085, 0.78), MAT.brass, T3(0, 0.87, 3.81));
  piece(lk, "Tail3", G.tor(0.135, 0.04), MAT.gun, T3(0, 0.87, 3.5));
  for (const [i, z] of [[0, 3.66], [1, 3.8], [2, 3.94]].map(a => a)) { piece(lk, "Tail3", G.cylY(0.04, 0.04, 0.14), MAT.dark, T3(0, 1.0, z)); piece(lk, "Tail3", G.cylY(0.055, 0.055, 0.03), gm("horn", "green"), T3(0, 1.08, z)); }
  const c = V(0, 1.03, 4.2); // the bend: a quarter torus in the YZ plane from the tube end (+Z) up to the bell
  const bend = G.tor(0.16, 0.085, Math.PI / 2); gx(bend, rotZ(-Math.PI / 2)); gx(bend, rotY(-Math.PI / 2));
  piece(lk, "Tail3", bend, MAT.brass, T3(c.x, c.y, c.z));
  const bellB = AT(0, c.y, c.z + 0.16, 18, 0, 0);
  piece(lk, "Tail3", G.cylY(0.33, 0.085, 0.46), MAT.brass, bellB.clone().multiply(T3(0, 0.23, 0)));
  const rimM = bellB.clone().multiply(AT(0, 0.46, 0, 90, 0, 0));
  piece(lk, "Tail3", G.tor(0.33, 0.035), MAT.gun, rimM);
  piece(lk, "Tail3", G.cylY(0.27, 0.27, 0.02), gm("horn", "green"), bellB.clone().multiply(T3(0, 0.39, 0)), {anim: () => scl(1 + 0.12 * NS.hornPulse, 1, 1 + 0.12 * NS.hornPulse)});
  NK.bell = bellB.clone().multiply(T3(0, 0.5, 0)); NK.bellUp = bellB;
})();
function bellPoint() { return V(0, 0, 0).applyMatrix4(new THREE.Matrix4().makeTranslation(hero.pos.x, hero.y, hero.pos.z).multiply(scl(hero.scale)).multiply(hero.W.Tail3).multiply(segInv.Tail3).multiply(NK.bell)); }
function bellAxis() { const M = new THREE.Matrix4().makeTranslation(hero.pos.x, hero.y, hero.pos.z).multiply(scl(hero.scale)).multiply(hero.W.Tail3).multiply(segInv.Tail3).multiply(NK.bellUp); return V(0, 1, 0).transformDirection(M); }

// ===== N5 · Glide Fan (passive · the glide): a rudder hub clamped on the top of the tail fan (Tail4); two long vanes lie folded
// along the tail and swing out when it glides, like a bird spreading its tail. =====
(() => {
  const lk = "fan.A", z = 5.12;
  const h = topHit(0, z, b => b.seg === "Tail4"); const F = bracket(lk, "Tail4", h, 0.3, 0.3, 0.05);
  const y0 = V(0, 0, 0).applyMatrix4(F).y;
  piece(lk, "Tail4", G.cylY(0.1, 0.14, 0.34), MAT.gun, T3(0, y0 + 0.17, z));
  const hub = V(0, y0 + 0.39, z); NK.fanHub = hub;
  piece(lk, "Tail4", G.cylY(0.1, 0.1, 0.1), MAT.brass, T3(hub.x, hub.y, hub.z));
  const fin = G.box(0.04, 0.42, 0.7); gx(fin, T3(0, 0.21, 0.3)); piece(lk, "Tail4", fin, MAT.plate, T3(0, hub.y + 0.04, z));
  piece(lk, "Tail4", G.box(0.05, 0.045, 0.68), gm("fan", "teal"), T3(0, hub.y + 0.47, z + 0.36));
  for (const s of [1, -1]) {
    const vane = G.box(0.6, 0.045, 1.9); gx(vane, T3(0.12 * s, 0, 0.97));
    const edge = G.box(0.07, 0.055, 1.84); gx(edge, T3(0.43 * s, 0, 0.97));
    const at = T3(0.1 * s, hub.y, z);
    const sw = {anim: p => rotAbout(p.at, V(0.1 * s, hub.y, z), rotY(rad(62) * s * NS.fan).multiply(rotZ(rad(-8) * s * NS.fan)))};
    piece(lk, "Tail4", vane, MAT.steel, at.clone(), sw);
    piece(lk, "Tail4", edge, gm("fan", "teal"), at.clone(), sw); }
})();

// ===== N6 · Watcher Lens (passive · support): one oversized Watcher eye in a brass scope over the +X eye (camera side), on a
// clamp on the skull; every splat it scans and marks each enemy hit. =====
(() => {
  const lk = "lens.A";
  const h = topHit(0.16, -3.05, b => b.seg === "Head" && notThin(b)); const F = bracket(lk, "Head", h, 0.18, 0.26, 0.05, V(0, 0, 1));
  const p0 = V(0, 0, 0).applyMatrix4(F);
  piece(lk, "Head", G.box(0.07, 0.12, 0.16), MAT.gun, T3(p0.x, p0.y + 0.08, p0.z));
  const arm = G.box(0.24, 0.06, 0.12); piece(lk, "Head", arm, MAT.gun, T3(p0.x + 0.12, p0.y + 0.15, p0.z));
  const c = V(p0.x + 0.26, p0.y + 0.17, p0.z - 0.04); NK.lensC = c;
  piece(lk, "Head", G.cylZ(0.15, 0.15, 0.34), MAT.gun, T3(c.x, c.y, c.z));
  piece(lk, "Head", G.cylZ(0.165, 0.165, 0.05), MAT.brass, T3(c.x, c.y, c.z - 0.15));
  piece(lk, "Head", G.cylZ(0.165, 0.165, 0.04), MAT.brass, T3(c.x, c.y, c.z + 0.12));
  piece(lk, "Head", G.sph(0.125, 1, 1, 0.5), lam(0xffd27a, {emissive: 0xd96a00}), T3(c.x, c.y, c.z - 0.18));
  piece(lk, "Head", G.box(0.34, 0.03, 0.14), MAT.plate, T3(c.x, c.y + 0.17, c.z - 0.08));
  NK.lensFront = V(c.x, c.y, c.z - 0.24);
})();
const lensMat = MECH.filter(p => p.look === "lens.A" && p.mesh.material.emissive && p.mesh.material.emissive.getHex() === 0xd96a00)[0];
function lensPoint() { return V(0, 0, 0).applyMatrix4(new THREE.Matrix4().makeTranslation(hero.pos.x, hero.y, hero.pos.z).multiply(scl(hero.scale)).multiply(hero.W.Head).multiply(segInv.Head).multiply(T3(NK.lensFront.x, NK.lensFront.y, NK.lensFront.z))); }

// ===== N7 · Bloom Burst (button · slot): a closed green bloom bud slung under the chest in two half-ring straps; press: it drops
// into the hands, is thrown, opens and bursts. =====
(() => {
  const lk = "burst.A"; const h = ray(V(0, -3, -1.66), V(0, 1, 0), onSeg("Torso")); const F = bracket(lk, "Torso", h, 0.26, 0.36, 0.04, V(0, 0, 1));
  for (const s of [1, -1]) { piece(lk, "Torso", G.tor(0.17, 0.028, Math.PI), MAT.gun, L(F, 0, 0.1, 0.11 * s)); for (const e of [1, -1]) { const q = V(0.17 * e, 0.1, 0.11 * s).applyMatrix4(F), hy = ray(V(q.x, -3, q.z), V(0, 1, 0), onSeg("Torso")).p.y; piece(lk, "Torso", G.box(0.06, hy - q.y, 0.06), MAT.gun, T3(q.x, (hy + q.y) / 2, q.z)); } }
  const c = V(0, 0.3, 0).applyMatrix4(F); const bud = [];
  bud.push(piece(lk, "Torso", G.sph(0.17, 1, 1.05, 1), gm("burst", "green"), T3(c.x, c.y, c.z)));
  for (let i = 0; i < 4; i++) { const a = i * Math.PI / 2 + Math.PI / 4; const pet = G.box(0.12, 0.3, 0.035); gx(pet, T3(0, 0.12, 0));
    bud.push(piece(lk, "Torso", pet, MAT.plate, T3(c.x, c.y - 0.15, c.z).multiply(rotY(a)).multiply(T3(0, 0, 0.16)).multiply(rotX(rad(-14))))); }
  NK.budCarry = makeCarry(bud, "Torso", c);
})();

// ===== N8 · Updraft Vent (button · slot): a folded fan vent on a plate on the +X side of the tail base; press: thrown ahead, it
// opens on the ground and blows a column that launches you and your squad into a glide. =====
(() => {
  const lk = "vent.A"; const h = side(1, 0.34, 1.38, onSeg("Tail1")); const F = bracket(lk, "Tail1", h, 0.3, 0.32, 0.04, V(0, 1, 0));
  const ven = [];
  ven.push(piece(lk, "Tail1", G.cylY(0.24, 0.26, 0.07), MAT.gun, L(F, 0, 0.055, 0)));
  ven.push(piece(lk, "Tail1", G.tor(0.215, 0.03), gm("vent", "teal"), L(F, 0, 0.1, 0, 90, 0, 0)));
  for (let i = 0; i < 4; i++) ven.push(piece(lk, "Tail1", G.box(0.36, 0.02, 0.07), MAT.steel, L(F, 0, 0.1, 0, 0, 45 * i + 20, 0), {anim: () => rotY(NS.ventSpin)}));
  ven.push(piece(lk, "Tail1", G.cylY(0.06, 0.06, 0.05), MAT.brass, L(F, 0, 0.11, 0)));
  NK.ventCarry = makeCarry(ven, "Tail1", V(0, 0.07, 0).applyMatrix4(F));
})();

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
  drum: r => ({charges: [3, 4, 4, 4, 6][r + 1], refill: [2, 2, 1.48, 1.48, 1.48][r + 1], fly: [0.37, 0.37, 0.37, 0.27, 0.27][r + 1]}),
  bloom: r => ({R: [20, 27, 27, 36.5, 36.5][r + 1], life: [3, 3, 4.05, 4.05, 4.05][r + 1], bloom: r >= 3}),
  jets: r => ({flapH: r >= 0 ? 14.9 : 11, fwd: r >= 1 ? 61 : 45, flaps: r >= 2 ? 3 : 2, fall: r >= 3 ? 5.9 : 8}),
  fan: r => ({fall: [8, 5.9, 5.9, 4.4, 4.4][r + 1], gfwd: r >= 1 ? 61 : 45, thermal: r >= 3}),
  horn: r => ({heal: r >= 0 ? 7 : 5, note: [0, 0, 6, 8.1, 8.1][r + 1], speed: r >= 3}),
  lens: r => ({mark: [0, 3, 4.05, 4.05, 4.05][r + 1], walls: r >= 2, heal: r >= 3}),
  burst: r => ({on: r >= 0, heal: 20, amp: r >= 1 ? 5.4 : 4, cd: r >= 2 ? 13.3 : 18, R: r >= 3 ? 27 : 20}),
  vent: r => ({on: r >= 0, life: r >= 1 ? 8.1 : 6, up: r >= 2 ? 40.5 : 30, float: r >= 3}),
};
const SRC = {
  thunder: ["Horizon Wiki: Thunderjaw (disc launchers on its hips)", "https://horizon.fandom.com/wiki/Thunderjaw"],
  disc: ["Fextralife: Disc Launcher (a Thunderjaw heavy weapon you can shoot off and carry)", "https://horizonzerodawn.wiki.fextralife.com/Disc+Launcher"],
  ac6: ["Fextralife: Armored Core VI Back Units (shoulder launchers, total rounds)", "https://armoredcore6.wiki.fextralife.com/Back+Units"],
  ink: ["Super Mario Wiki: Inkling (\"The ink tank on an Inkling's back tracks their remaining ink\")", "https://www.mariowiki.com/Inkling"],
  valk: ["Apex Legends Wiki: Valkyrie (VTOL Jets, a jetpack with a fuel gauge; Skyward Dive)", "https://apexlegends.fandom.com/wiki/Valkyrie"],
  zoid: ["The Iron Bible: Storm Sworder (flight from engine pods on its back)", "https://theironbible.com/IndexZoids/StormSworder.php"],
  sunwing: ["Samurai Gamers: Sunwing (photovoltaic wings)", "https://samurai-gamers.com/horizon-forbidden-west/sunwing-machine-guide"],
  updraft: ["Zelda Wiki: Updraft (fire makes a rising gust the paraglider rides)", "https://zeldawiki.wiki/wiki/Updraft"],
  horn: ["Icy Veins: Hunting Horn guide (melodies buff the whole party; Echo Bubbles, health regeneration)", "https://www.icy-veins.com/monster-hunter-wilds/hunting-horn-guide"],
  watcher: ["Fextralife: Watcher (the glowing eye; a recon machine)", "https://horizonzerodawn.wiki.fextralife.com/Watcher"],
  discord: ["Overwatch Wiki: Zenyatta (Orb of Discord: +30% damage taken, a visual identifier on the target)", "https://overwatch.fandom.com/wiki/Zenyatta"],
  ana: ["Overwatch Wiki: Biotic Grenade (heals allies, +50% healing received 4 s; enemies can't heal 4 s)", "https://overwatch-archive.fandom.com/wiki/Biotic_Grenade"],
  octane: ["Apex Legends Wiki: Octane (Launch Pad catapults anyone, squad included)", "https://apexlegends.wiki.gg/wiki/Octane"],
};
const CANDS = [
  {id: "drum", code: "N1", name: "Pod Drum", kind: "PASSIVE", covers: "Pod throw", rec: true,
    one: "More pods, faster refills, a faster pod: a revolver drum of glowing pods across the shoulders.",
    steps: ["4 pod charges (today 3)", "A charge refills in 1.48 s (today 2 s)", "Pods fly 35% faster: 0.27 s to land (today 0.37 s)", "6 pod charges"],
    check: "2 / 1.48 = 1.35 · 0.37 / 0.27 = 1.37 · 6 / 4 = 1.5 (counts can't step by a fraction)",
    every: "Every throw: the drum turns one chamber with a clack, a pod drops from the top chamber into the hands, the chamber goes dark; every refill: a chamber relights with a flash. The lit chambers ARE the charge count.",
    insp: [["Horizon Zero Dawn · Thunderjaw", "two disc launchers worn on the hips: heavy weapons on the machine's body that fire bursts of discs (and can be shot off)", ["thunder", "disc"]], ["Armored Core VI · back units", "a launcher mounted on the shoulders with a visible set of rounds", ["ac6"]]],
    borrow: "The rack itself: a revolving magazine worn on the body, its loaded rounds visible.",
    roblox: "Drum = welded MeshParts (gun-metal drum, brass bands) on a Motor6D / Weld that tweens 60° per throw; 6 chambers = Neon spheres (amber lit, SmoothPlastic dark when spent); clack = 0.1 s Neon flash + 4 sparks (ParticleEmitter burst); the feed = a small Neon ball tweened from the top chamber to ArmL_hand / ArmR_hand during the 0.34 s wind-up.",
    follows: "TrooFX pod (FFC35A Neon ball, embers) and the attack bar's pod pips."},
  {id: "bloom", code: "N2", name: "Bloom Tank", kind: "PASSIVE", covers: "Glow zone", rec: true,
    one: "A bigger glow zone that lasts longer: a see-through tank of zone fluid on the tail base.",
    steps: ["Glow zone 54 studs wide (today 40)", "Zones last 4.05 s (today 3 s)", "73 studs wide", "When a zone ends it blooms: one last pulse, squadmates inside +5, enemies inside slowed 1.5 s more"],
    check: "54 / 40 = 1.35 · 4.05 / 3 = 1.35 · 73 / 54 = 1.35",
    every: "Every throw: the tank's fluid drops and a teal puff leaves its nozzle; the zone lands bigger (today's 40-stud ring is drawn dashed inside it in Compare), and the tank glows teal for as long as the zone is up.",
    insp: [["Splatoon · the ink tank", "the tank on an Inkling's back is the gauge: its fill shows the ink left", ["ink"]]],
    borrow: "A see-through backpack tank whose fill level is the effect's fuel gauge.",
    roblox: "Tank = Glass cylinder (Transparency 0.55, teal) round a Neon fluid cylinder whose Size.Y tweens with the fill; brass bands; nozzle puff = ParticleEmitter (teal mist, 0.4 s); the zone = the live TrooFX zone with TrooZoneRadius / TrooZoneTime raised (a bigger disc + rim + ring wave + more spores); bloom = a second ring wave + a green spore burst + MedHealPop.",
    follows: "TrooFX zone (2FE6C8 / A8FFF0, ring wave, spores), Med-Station MedHealPop for the star pulse."},
  {id: "jets", code: "N3", name: "Wing Jets", kind: "PASSIVE", covers: "Flaps", rec: true,
    one: "Every wing beat flies higher: two swivel thrusters on the lower back fire on each flap.",
    steps: ["Every flap 35% higher: 14.9 studs (today 11)", "Flaps push forward 35% faster: 61 studs/s (today 45)", "A 3rd flap (leap + 3 beats; today leap + 2)", "The jets hold the glide: it falls 5.9 studs/s (today 8)"],
    check: "14.9 / 11 = 1.35 · 61 / 45 = 1.36 · 3 / 2 = 1.5 · 8 / 5.9 = 1.36",
    every: "Every flap: both nozzles swing down and fire a teal-white blast (flame cone, shock ring, heat puffs, light) while the wings beat; at star they idle with a small flame through the glide.",
    insp: [["Apex Legends · Valkyrie", "VTOL Jets: press jump again in the air to fire a jetpack (fuel gauge); Skyward Dive", ["valk"]], ["Zoids · Storm Sworder", "flight from engine pods mounted on its back", ["zoid"]]],
    borrow: "Twin swivel thrusters on the back that fire with the jump input.",
    roblox: "Nacelles = welded parts on a Motor6D that tweens 40° down per flap; nozzle = Neon disc + PointLight (teal) that flares; blast = 2 Beams (cone texture) + ParticleEmitter (white-teal flame, 0.25 s) + a flat Neon shock ring under the jets; idle flame at star = a small ParticleEmitter left on while GliderAuto glides.",
    follows: "The Flap & Glide wing-beat puffs (kept), TenoMovesFX flat neon ring for the shock ring."},
  {id: "horn", code: "N4", name: "Chorus Horn", kind: "PASSIVE", covers: "Healing", rec: true,
    one: "Your zones heal your squad more and every splat plays a heal note: a brass horn along the tail.",
    steps: ["Your zones heal squadmates 7/s (today 5/s)", "Every splat plays a note: squadmates inside heal 6 at once", "The note heals 8.1", "Squadmates your horn heals run 15% faster while they're in your zone"],
    check: "7 / 5 = 1.4 · 8.1 / 6 = 1.35",
    every: "Every heal tick: the bell's membrane flares green and a green ring leaves the bell; every splat (II+): a big note ring from the bell and a green wave on each squadmate in the zone.",
    insp: [["Monster Hunter · Hunting Horn", "an instrument weapon whose melodies buff the whole party; Echo Bubbles give health regeneration to hunters inside", ["horn"]]],
    borrow: "The instrument as the healer's tool: each heal is played, and you can see the note leave the horn.",
    roblox: "Horn = welded brass MeshParts (tube, bend, bell) + a Neon membrane disc in the bell (Transparency pulses per tick) + PointLight; note = a flat Neon ring (TenoMovesFX ring) tweened out of the bell along its axis; heals = the live MedWave ring + MedHealPop; speed at star = the raptor sprint streak Trail on the squadmate.",
    follows: "Med-Station heal look (MedWave, MedHealPop green +N), TrooFX zone heal, TenoMovesFX ring."},
  {id: "fan", code: "N5", name: "Glide Fan", kind: "PASSIVE", covers: "Glide",
    one: "A slower, faster glide: two vanes on the tail fan spread out as soon as it glides.",
    steps: ["The glide falls 5.9 studs/s (today 8)", "Glides 61 studs/s (today 45)", "Falls 4.4 studs/s", "Gliding over your own glow zone lifts you (a thermal: +6 studs/s up)"],
    check: "8 / 5.9 = 1.36 · 61 / 45 = 1.36 · 5.9 / 4.4 = 1.34 (rounded)",
    every: "Every glide: the vanes swing out to the sides with a teal edge glow and wind streaks peel off their tips; at star a rising teal column shows where your zone lifts you.",
    insp: [["Horizon Forbidden West · Sunwing", "a flying machine with photovoltaic wings", ["sunwing"]], ["Zelda: Breath of the Wild · updraft", "fire makes a rising gust the paraglider rides up", ["updraft"]]],
    borrow: "Fold-out wing panels that open only to fly; your own zone as the updraft.",
    roblox: "Vanes = welded parts on Motor6Ds that tween out 62° when GliderAuto starts and back on landing; teal Neon edge strips; tip streaks = Trails on two Attachments at the vane tips; thermal = GliderFall replaced by a small upward speed while over your TrooZone, shown with rising teal ParticleEmitter motes.",
    follows: "The Flap & Glide glide (GliderAuto, GliderFall), TrooFX zone spores for the thermal column."},
  {id: "lens", code: "N6", name: "Watcher Lens", kind: "PASSIVE", covers: "Support (marks)",
    one: "Your splats mark every enemy they hit: the squad does more damage to marked enemies. A big Watcher eye over the camera-side eye.",
    steps: ["Enemies your splat hits are marked 3 s: they take 15% more damage from your squad", "Marks last 4.05 s", "Your squad sees marked enemies through walls", "Squadmates heal 2 each time they hit a marked enemy"],
    check: "4.05 / 3 = 1.35 · the 15% is never restacked",
    every: "Every splat: the lens flares amber, scan beams jump to each enemy hit, an amber Watcher-eye mark pops over each one and their body glows amber until it runs out.",
    insp: [["Horizon Zero Dawn · Watcher", "the recon machine whose one big glowing eye is its signature (and weak spot)", ["watcher"]], ["Overwatch · Zenyatta's Orb of Discord", "+30% damage taken, with a visible marker on the target", ["discord"]]],
    borrow: "One oversized sensor eye on the head + a mark that floats over the target.",
    roblox: "Lens = brass scope + a Neon amber lens with a PointLight; scan = 0.25 s Beams from the lens to each hit enemy; mark = a BillboardGui eye icon (AlwaysOnTop from III) + a Highlight (amber, OutlineTransparency 0.2) on the enemy for the mark time.",
    follows: "The Night Watcher's own amber eye glow (eyeMat F0A62A), TrooFX hit flash."},
  {id: "burst", code: "N7", name: "Bloom Burst", kind: "BUTTON", covers: "Burst heal",
    one: "Button: throw a bloom bud that bursts open: a big instant squad heal plus a heal boost, and enemies can't heal.",
    steps: ["Button: throw a bud up to 40 studs; squadmates within 20 studs heal 20 and get 50% more healing for 4 s; enemies inside heal 50% less for 4 s. Recharge 18 s", "The boost lasts 5.4 s", "Recharge 13.3 s", "Bursts 54 studs wide (today's I: 40)"],
    check: "5.4 / 4 = 1.35 · 18 / 13.3 = 1.35 · 27 / 20 = 1.35",
    every: "Press: the bud drops from its belly sling into the hands (wind-up), is thrown, lands, its petals open, then a green burst wave; squadmates glow green while boosted (their next heals pop bigger); enemies get a purple 'NO HEAL' mark.",
    insp: [["Overwatch · Ana's Biotic Grenade", "a thrown grenade that heals allies and boosts their healing received by 50% for 4 s, while enemies can't heal", ["ana"]]],
    borrow: "The two-sided grenade: heal + healing boost for allies, anti-heal for enemies, from one throw.",
    roblox: "Bud = welded MeshParts (green Neon core, 4 petal plates) in a strap sling; thrown with the TrooFX pod arc; burst = Neon sphere flash + 2 flat rings + green ParticleEmitter; boost = a green Highlight + aura disc on each squadmate; anti-heal = a purple BillboardGui tag.",
    follows: "Med-Station heal look, TrooFX pod arc and splat, TenoMovesFX aura disc."},
  {id: "vent", code: "N8", name: "Updraft Vent", kind: "BUTTON", covers: "Squad lift",
    one: "Button: throw a fan vent that blows a wind column: you and your squad step in and shoot up into a glide.",
    steps: ["Button: throw a vent up to 30 studs; for 6 s you and squadmates stepping on it shoot 30 studs up (your flaps reset into a glide). Recharge 20 s", "Lasts 8.1 s", "Launches 40.5 studs up", "Launched squadmates float down slowly (8 studs/s) like your glide"],
    check: "8.1 / 6 = 1.35 · 40.5 / 30 = 1.35",
    every: "Press: the vent leaves its plate on the tail base, lands, unfolds and spins up; a teal wind column of streaks and rings stands on it; each dino that steps in is thrown up with a burst ring.",
    insp: [["Apex Legends · Octane's Launch Pad", "a pad that catapults anyone who touches it, squad included", ["octane"]], ["Apex Legends · Valkyrie's Skyward Dive", "lifts her and her squad high into the air", ["valk"]], ["Zelda: Breath of the Wild · updraft", "a rising gust you ride up with the glider", ["updraft"]]],
    borrow: "A thrown launch pad that the whole squad can use, made of wind (a rising column) instead of a spring.",
    roblox: "Vent = welded parts (disc, Neon teal ring, 4 spinning blades on a HingeConstraint / tween); column = 2 Beams (vertical, scrolling streak texture) + ParticleEmitter (rising teal motes) + 3 flat Neon rings rising; launch = AssemblyLinearVelocity up + a white ring burst; the troodon then uses GliderAuto.",
    follows: "TrooFX zone teal, TenoMovesFX flat ring, the Flap & Glide glide."},
  {id: "set", code: "", name: "Rec. set", kind: "CHECK", covers: "All on at once"},
];
const CID = CANDS.filter(c => c.id !== "set").map(c => c.id);
const RECSET = CANDS.filter(c => c.rec).map(c => c.id);
const SPOT = {drum: "Behind the neck: a cradle on two posts bridged over the crest, the drum lying across the shoulders (axis left-right).",
  bloom: "Top of the tail base (Tail1): two hoop cradles on posts, the tank lying along the tail.",
  jets: "Lower back: a saddle on two posts over the crest, a fuel cell in the middle, one swivel thruster at each end.",
  horn: "Top of the tail (Tail3): two clamps on posts; the tube runs along the tail, the bell turns up at its end.",
  fan: "Top of the tail fan (Tail4): a hub on a clamp plate; a rudder fin and two vanes that lie folded along the tail.",
  lens: "Top of the skull, camera side (+X): a clamp plate, an arm out over the +X eye, the scope looking forward.",
  burst: "Under the chest: a sling of two half-ring straps on four posts, the bud hanging in it.",
  vent: "+X side of the tail base (Tail1), on a side plate: the vent stands folded flat against the tail."};
const NOTES = {drum: ["In front of the Mender Drone's arch, beside the Sap Wall pod (closest gap and clash numbers measured below).", "Camera reads: the lit / dark chambers are the charge count."],
  bloom: ["Ahead of the Portal Rift's tail rings, behind the hips.", "The biggest glowing shape in the middle of the game camera's view."],
  jets: ["Between the Feather Shed flank rails and the Bloom Tank.", "The nozzles point down-back so the blast reads from behind."],
  horn: ["Past the Portal Rift's second ring; the bell stands above the tail feathers.", "The bell is the highest shape on the dino from behind."],
  fan: ["Over the tail feathers (0% inside them in every pose, measured below).", "Shares the tail with the Chorus Horn (the vanes start behind the bell)."],
  lens: ["Rides the head, so it turns with every aim.", "Small from 70 studs; it reads by its glow and the marks."],
  burst: ["Between the arms and under the chest: hidden from the game camera until it drops into the hands.", "Takes a slot (button)."],
  vent: ["Under the Bloom Tank's cradle on the camera side.", "Takes a slot (button)."]};

// ---------- scenes ----------
function zoneScene2() { place(S, -9, -36); place(S2, 7, -46); place(R0, -1, -42); place(R1, 9, -38); R0.yaw = yawTo(R0.pos, S.pos); R1.yaw = yawTo(R1.pos, S2.pos); S.yaw = yawTo(S.pos, R0.pos); S2.yaw = yawTo(S2.pos, R1.pos); }
let mode = "boost", rank = 3, liveOn = true, cphase = 0; // cphase: Compare mode's current half (0 = today, 1 = with the part)
const boostNow = () => mode === "boost" || (mode === "compare" && cphase === 1);
const ghostNow = () => mode === "compare" && cphase === 1;
const cfgNow = id => CFG[id](boostNow() ? rank : -1);
function hudPods(n, max, u) { NS.hud = {n, max, u}; }

// ---------- tracks (each returns keys, ev, update, post, move, frame, phases, len) ----------
function drumTrack() {
  const c = cfgNow("drum"), on = boostNow();
  place(R0, -2, -44); place(R1, 9, -50); place(R2, -11, -52);
  const tg = [R0, R1, R2];
  const T0 = 0.6, GAP = 0.5, n = c.charges, RELS = []; for (let i = 0; i < n; i++) RELS.push(T0 + i * GAP + 0.2);
  const last = RELS[n - 1], REF0 = last + 0.25, nRef = 2, END = REF0 + nRef * c.refill;
  const keys = [K(0, T_READY), K(T0, T_READY)]; for (let i = 0; i < n; i++) keys.push(...QTHROW(T0 + i * GAP)); keys.push(K(last + 0.75, T_READY, "io"));
  NS.charges = on ? c.charges : 6; NS.cham = [0, 1, 2, 3, 4, 5].map(i => i < c.charges ? 1 : 0); NS.drumT = 0; NS.drumA = 0;
  let loaded = n;
  const ev = [];
  RELS.forEach((rel, i) => {
    ev.push({t: rel - 0.2, f: () => { if (on) { const from = chamberWorld(i); flash(from, 2.6, 0xffe7a8); sparks(from, V(0, 1, 0), 4, 0xffe7a8, 0.25); const s = sprite(T_POD, 0xffd27a, 2.4, true); addFx(s, 0.2, (o, u) => { o.position.copy(chamberWorld(i)).lerp(handsPoint(), E.io(u)); o.position.y += Math.sin(u * Math.PI) * 2; }); NS.cham[i] = 0; NS.drumT = (i + 1) * Math.PI / 3; } }});
    ev.push({t: rel, f: () => { loaded--; const R = tg[i % 3]; const off = V((i % 2 ? 1 : -1) * (i > 2 ? 3 : 0), 0, 0);
      throwPod({kind: "pod", from: handsPoint(), target: () => R.pos.clone().add(off).setY(1), T: c.fly, H: c.fly > 0.3 ? 9 : 6, onHit: p => { zoneAt(p, {R: 20, life: 3, self: 0}); }});
      if (i === n - 1) later(0.35, () => textTag(heroHRP().add(V(0, 15, 0)), on ? n + " PODS IN A ROW" : "EMPTY · 3 pods", on ? "#ffd38a" : "#e8eef8", 1.4)); }});
  });
  for (let k = 0; k < nRef; k++) ev.push({t: REF0 + (k + 1) * c.refill, f: () => { loaded++; if (on) { NS.cham[k] = 1; const p = chamberWorld(k); flash(p, 3.2, 0xffd27a); sparks(p, V(0, 1, 0), 6, 0xffe7a8, 0.3); } textTag(heroHRP().add(V(0, 13, 0)), "+1 POD · " + c.refill + " s", "#ffd38a", 1.0); }});
  return {frame: [V(0, 0, 4), V(0, 0, -52)], keys, ev, eyes: [[T0, last + 0.3]],
    update(t, dt) { NS.drumA += (NS.drumT - NS.drumA) * Math.min(1, dt * 22); PGLOW.drum = 0.4;
      let u = 1; if (t > REF0 && t < END) u = ((t - REF0) % c.refill) / c.refill; hudPods(loaded, c.charges, loaded < c.charges ? u : 1); },
    phases: [[0, T0, on ? "Slotted (no slot used): " + n + " lit chambers = " + n + " pods" : "Today: 3 pods (pips top left)"], [T0, last + 0.3, on ? "Throws " + n + " pods in a row: the drum turns a chamber per throw" + (c.fly < 0.3 ? ", pods land in 0.27 s" : "") : "Throws its 3 pods in a row"], [last + 0.3, REF0 + 0.2, "Empty"], [REF0 + 0.2, END + 0.6, "Refills one pod every " + c.refill + " s" + (on ? ": a chamber relights" : "")]],
    len: END + 0.6};
}
function chamberWorld(i) { const ch = NK.cham[i * 2]; return V(0, 0, 0).applyMatrix4(ch.p.mesh.matrix).add(V(0, 0.6, 0)); }

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

function jetsTrack() {
  const c = cfgNow("jets"), on = boostNow();
  const F = flight({flapH: c.flapH, fwd: c.fwd, flaps: c.flaps, fall: c.fall});
  const T = flight({});
  const ev = [{t: 0, f: () => { if (ghostNow()) ghostFlight(T, F.landAt + 0.8); }}, {t: F.o.T0 + 0.05, f: () => { wingPuff(); if (on) jetBlast(0.9); }}];
  F.FL.forEach((a, i) => ev.push({t: a, f: () => { wingPuff(); if (on) { jetBlast(1); if (i === F.FL.length - 1 && c.flaps > 2) textTag(heroHRP().add(V(0, 12, 0)), "3RD FLAP", "#a8fff0", 1); } }}));
  ev.push({t: F.glideAt, f: () => textTag(heroHRP().add(V(0, 12, 0)), "GLIDE · falls " + fmt(c.fall) + " studs/s", "#e8eef8", 1.4)});
  ev.push({t: F.landAt, f: () => textTag(hero.pos.clone().add(V(0, 2, -4)), "peak " + F.peak.toFixed(0) + " · " + F.dist.toFixed(0) + " studs (today " + T.peak.toFixed(0) + " · " + T.dist.toFixed(0) + ")", "#ffffff", 1.4)});
  return {follow: true, frame: [V(0, 0, 4), V(0, 0, -F.dist - 6)], keys: flightKeys(F), ev,
    update(t, dt) { NS.jetFire = Math.max(0, NS.jetFire - dt * 3.2); const glide = t > F.glideAt && t < F.landAt;
      const tgt = !on ? 0 : NS.jetFire > 0.05 ? rad(40) : glide && c.fall < 8 ? rad(28) : t > F.o.T0 && t < F.landAt ? rad(12) : 0; NS.jetTilt += (tgt - NS.jetTilt) * Math.min(1, dt * 18);
      PGLOW.jets = !on ? 0 : NS.jetFire * 2.2 + (glide && c.fall < 8 ? 0.7 : 0.15);
      if (on && glide && c.fall < 8 && Math.random() < dt * 40) jetFlame(0.45);
      if (on && NS.jetFire > 0.3 && Math.random() < dt * 70) jetFlame(NS.jetFire); },
    move(t) { const [f, u] = F.at(t); return {z: -f, up: u}; },
    phases: [[0, F.o.T0, on ? "Slotted (no slot used): the jets sit level" : "Today: no part"], [F.o.T0, F.FL[0] - 0.1, "Leap: the first wing beat" + (on ? " + a jet blast" : "")], [F.FL[0] - 0.1, F.glideAt, (on ? c.flaps + " flaps, " + fmt(c.flapH) + " studs each, the jets fire on every beat" : "2 flaps, 11 studs each")], [F.glideAt, F.landAt, "Auto glide: falls " + fmt(c.fall) + " studs/s" + (on && c.fall < 8 ? " (the jets hold it up)" : "")], [F.landAt, F.landAt + 1, "Plain landing (no landing FX) · peak " + F.peak.toFixed(0) + " studs, " + F.dist.toFixed(0) + " covered"]],
    len: F.landAt + 1.0};
}
function jetBlast(k) { NS.jetFire = k; for (let i = 0; i < 2; i++) { const m = jetMouth(i), d = jetDir(i); flash(m, 4 * k, 0xc8fff4); orb(m.clone().addScaledVector(d, 1.2), 1.8 * k, 0xa8fff0, 0.22);
    for (let j = 0; j < 6; j++) puff(m.clone().addScaledVector(d, 1 + Math.random() * 2), d.clone().multiplyScalar(14 + Math.random() * 10).add(V((Math.random() - .5) * 4, 0, (Math.random() - .5) * 4)), 1.2, 0xe8f4f2, 0.55, 0.6); }
  const c = heroHRP().add(V(0, -1, 2)); const ring = new THREE.Mesh(new THREE.RingGeometry(0.8, 1, 40), new THREE.MeshBasicMaterial({color: 0xc8fff4, transparent: true, opacity: 0.9, depthWrite: false, side: THREE.DoubleSide})); ring.rotation.x = -Math.PI / 2; ring.position.copy(c);
  addFx(ring, 0.35, (o, u) => { o.scale.setScalar(1 + 7 * E.out(u)); o.material.opacity = 0.9 * (1 - u); o.position.y = c.y - u * 2; }); }
function jetFlame(k) { for (let i = 0; i < 2; i++) { const m = jetMouth(i), d = jetDir(i); const s = sprite(T_FLASH, Math.random() < 0.5 ? 0xffffff : 0x8ff7e6, (1.2 + Math.random()) * (0.6 + k), true); s.position.copy(m); const v = d.clone().multiplyScalar(18 + 20 * k);
  addFx(s, 0.16 + 0.1 * k, (o, u, dt) => { o.position.addScaledVector(v, dt); o.material.opacity = 1 - u; o.scale.multiplyScalar(0.96); }); } }

function hornTrack() {
  const c = cfgNow("horn"), on = boostNow();
  zoneScene2(); S.max = S2.max = 60; setHp(S, 31); setHp(S2, 36); S.hpShow = S2.hpShow = true;
  const T0 = 0.6, REL = T0 + 0.34, FLY = 0.37, SPLAT = REL + FLY, END = SPLAT + 3;
  const keys = idleIntro(THROW(T0), T0);
  const note = big => { NS.hornPulse = big ? 1.6 : 1; const p = bellPoint(), a = bellAxis(); axisRing(p, a, big ? 9 : 5, HEAL_GREEN, big ? 0.8 : 0.55); if (big) { axisRing(p, a, 6, 0xd8ffe0, 0.6); flash(p, 6, 0xbfffd6); } glowAt(() => bellPoint(), HEAL_GREEN, big ? 6 : 3.5, 0.35, 0.8); };
  const ev = [{t: REL, f: () => throwPod({kind: "pod", from: handsPoint(), target: () => V(-1, 1, -42), T: FLY, H: 8, onHit: p => { zoneAt(p, {heal: c.heal, self: 2,
      onSplat: (Z, hits, heals) => { if (on && c.note) { later(0.12, () => { note(true); heals.forEach(R => { groundRing(R.rig.pos, 8, HEAL_GREEN, 0.7, 0.5); healPop(R, c.note); textTag(rapChest(R).add(V(0, 14.5, 0)), "NOTE +" + fmt(c.note), "#8dffb6", 1.3); }); }); } },
      onTick: () => { if (on) note(false); },
      onHeal: (R, n) => { if (on && c.speed && !R.fastT) { R.fastT = 2.4; textTag(rapChest(R).add(V(0, 17, 0)), "+15% SPEED", "#8dffb6", 1.5); } if (on && c.speed) R.fastT = 2.4; }}); }})}];
  return {frame: [V(0, 0, 4), V(0, 0, -46)], keys, ev, eyes: [[T0, REL + 0.3]],
    update(t, dt) { NS.hornPulse = Math.max(0, NS.hornPulse - dt * 3); PGLOW.horn = on ? 0.2 + NS.hornPulse * 1.4 : 0;
      if (on && c.speed && t > SPLAT + 1.1 && t < END) { for (const R of [S, S2]) { if (!R.pathSet) { R.pathSet = 1; const a = R.pos.clone(), b = a.clone().add(V(R === S ? -6 : 6, 0, -5)); R.path = [[t, a, yawTo(a, b), 0.2], [t + 0.2, a.clone().lerp(b, 0.1), yawTo(a, b), 1.2], [END, b, yawTo(a, b), 1.2], [END + 0.3, b, yawTo(a, b), 0]]; } } } },
    phases: [[0, T0, on ? "Slotted (no slot used): the horn on the tail" : "Today: no part"], [T0, SPLAT, "Throws a pod at the fight (2 hurt squadmates inside)"], [SPLAT, SPLAT + 0.6, on && c.note ? "Splat: the horn plays a note: squadmates +" + fmt(c.note) + " at once" : "Splat"], [SPLAT + 0.6, END, "Every second: squadmates +" + fmt(c.heal) + (on ? " (today +5); a green ring leaves the bell each tick" : "")], [END, END + 0.9, on && c.speed ? "Star: healed squadmates run 15% faster in the zone" : "The zone fades"]],
    len: END + 1.0};
}

function fanTrack() {
  const c = cfgNow("fan"), on = boostNow();
  const ZC = 64, ZR = 20, SPL = 0.9; // a pod thrown ahead first: a 40-stud zone centred 64 studs out, alive 0.9 .. 3.9 s
  const J0 = 1.05;
  const F = flight({T0: J0, fall: c.fall, gfwd: c.gfwd, thermal: c.thermal ? {cz: ZC, R: ZR, until: SPL + 3, up: 6, max: 30} : null});
  const T = flight({T0: J0});
  const keys = [K(0, T_READY), K(0.12, TA_WIND_W, "io"), K(0.2, TA_HOLD_W, "io"), K(0.26, TA_THROW, "in2"), K(0.45, TA_FOLLOW, "out"), K(0.85, T_READY, "io"), ...flightKeys(F).slice(1)];
  const ev = [{t: 0, f: () => { if (ghostNow()) ghostFlight(T, F.landAt + 0.8); }}, {t: 0.26, f: () => throwPod({kind: "pod", from: handsPoint(), target: () => V(0, 1, -ZC), T: SPL - 0.26, H: 10, onHit: p => zoneAt(p, {self: 0})})},
    {t: J0 + 0.05, f: wingPuff}, ...F.FL.map(a => ({t: a, f: wingPuff})),
    {t: F.glideAt, f: () => { if (on) { flash(fanTip(1), 3, 0xa8fff0); flash(fanTip(-1), 3, 0xa8fff0); textTag(heroHRP().add(V(0, 12, 0)), "FAN OPEN · falls " + fmt(c.fall) + " studs/s", "#a8fff0", 1.4); } }},
    {t: F.landAt, f: () => textTag(hero.pos.clone().add(V(0, 2, -4)), "glided " + (F.dist).toFixed(0) + " studs (today " + T.dist.toFixed(0) + ")", "#ffffff", 1.5)}];
  let thermTag = false;
  return {follow: true, frame: [V(0, 0, 4), V(0, 0, -F.dist - 6)], keys, ev,
    update(t, dt) { const glide = t > F.glideAt && t < F.landAt - 0.05; NS.fan += ((on && glide ? 1 : 0) - NS.fan) * Math.min(1, dt * 9); PGLOW.fan = on ? 0.2 + NS.fan * 1.2 : 0;
      if (on && NS.fan > 0.6) { for (const s of [1, -1]) if (Math.random() < dt * 30) { const p = fanTip(s); const q = sprite(T_FLASH, 0xe8fffb, 0.9, true); q.position.copy(p); addFx(q, 0.45, (o, u) => { o.material.opacity = 0.7 * (1 - u); }); } }
      const [f, u, g] = F.at(t); if (on && c.thermal && g && t < SPL + 3 && Math.abs(f - ZC) < ZR) { if (!thermTag) { thermTag = true; textTag(heroHRP().add(V(0, 12, 0)), "THERMAL · lifts 6 studs/s", "#a8fff0", 1.4); }
        if (Math.random() < dt * 40) { const s = sprite(T_POD, ZONER, 1.2, true); s.position.set((Math.random() - .5) * 8, Math.random() * u, -f + (Math.random() - .5) * 6); const vy = 14 + Math.random() * 8; addFx(s, 0.7, (o, uu, d) => { o.position.y += vy * d; o.material.opacity = 0.9 * (1 - uu); }); } } },
    move(t) { const [f, u] = F.at(t); return {z: -f, up: u}; },
    phases: [[0, J0, "Throws a pod ahead (a glow zone 64 studs out)"], [J0, F.glideAt, "Leap + 2 flaps (the live jump)"], [F.glideAt, F.landAt, on ? "Glide: the vanes spread, falls " + fmt(c.fall) + " studs/s at " + c.gfwd + " studs/s" + (c.thermal ? "; over the zone it climbs" : "") : "Glide: falls 8 studs/s at 45 studs/s"], [F.landAt, F.landAt + 1, "Plain landing · " + F.dist.toFixed(0) + " studs (today " + T.dist.toFixed(0) + ")"]],
    len: F.landAt + 1.0};
}
function fanTip(s) { const q = NK.fanHub; const M = new THREE.Matrix4().makeTranslation(hero.pos.x, hero.y, hero.pos.z).multiply(scl(hero.scale)).multiply(hero.W.Tail4).multiply(segInv.Tail4).multiply(T3(0.1 * s, q.y, q.z)).multiply(rotY(rad(62) * s * NS.fan)).multiply(T3(0.43 * s, 0, 1.92)); return V(0, 0, 0).applyMatrix4(M); }

function lensTrack() {
  const c = cfgNow("lens"), on = boostNow();
  zoneScene2(); place(R2, 4, -50); R2.yaw = yawTo(R2.pos, S2.pos);
  const T0 = 0.6, REL = T0 + 0.34, FLY = 0.37, SPLAT = REL + FLY, BITE = SPLAT + 1.2;
  const keys = idleIntro(THROW(T0), T0);
  const ev = [{t: REL, f: () => throwPod({kind: "pod", from: handsPoint(), target: () => V(1, 1, -44), T: FLY, H: 8, onHit: p => { zoneAt(p, {self: 2, onSplat: (Z, hits) => { if (!on) return;
      NS.lens = 1.6; flash(lensPoint(), 4, 0xffd27a); hits.forEach((R, i) => later(0.08 + i * 0.07, () => { tether(() => lensPoint(), () => rapChest(R), MARK, 0.28, 0.16, 0.8); markOn(R, c.mark, c.walls); })); } }); }})},
    {t: BITE - 0.3, f: () => { S.lunge = 1; }},
    {t: BITE, f: () => { const p = rapChest(R0); R0.flinch = 1; R0.flash = 0.12; R0.flashCol = [0.9, 0.1, 0.05]; flash(p, 6); if (on && R0.mark > 0) { popNum(p.clone().add(V(0, 5, 0)), "9.2", "hit"); textTag(p.clone().add(V(0, 9.5, 0)), "MARKED: 8 → 9.2 (+15%)", "#ffc070", 1.5); if (c.heal) later(0.15, () => { healPop(S, 2); textTag(rapChest(S).add(V(0, 13, 0)), "+2 (hit a mark)", "#8dffb6", 1.2); }); } else popNum(p.clone().add(V(0, 5, 0)), 8, "hit"); }}];
  return {frame: [V(0, 0, 4), V(0, 0, -50)], keys, ev, eyes: [[T0, REL + 0.3]],
    update(t, dt) { NS.lens = Math.max(0, NS.lens - dt * 2); PGLOW.lens = 0; if (lensMat) lensMat.mesh.material.emissiveIntensity = on ? 0.7 + NS.lens * 1.2 + 0.15 * Math.sin(t * 3) : 0.7; },
    phases: [[0, T0, on ? "Slotted (no slot used): the Watcher eye glows over the +X eye" : "Today: no part"], [T0, SPLAT, "Throws a pod at 3 enemies"], [SPLAT, SPLAT + 0.6, on ? "Splat: the lens flares, scan beams jump to each enemy hit, an eye mark pops over each" : "Splat"], [SPLAT + 0.6, BITE + 0.2, on ? "Marked " + fmt(c.mark) + " s: a squadmate's bite does 8 → 9.2" + (c.heal ? ", and it heals 2" : "") : "A squadmate bites for 8"], [BITE + 0.2, BITE + 2.2, "The marks fade"]],
    len: BITE + 2.2};
}
const T_EYE = (() => { const cv2 = document.createElement("canvas"); cv2.width = cv2.height = 96; const x = cv2.getContext("2d"); x.fillStyle = "rgba(20,10,0,.75)"; x.beginPath(); x.moveTo(48, 6); x.lineTo(90, 48); x.lineTo(48, 90); x.lineTo(6, 48); x.closePath(); x.fill(); x.strokeStyle = "#ffb43a"; x.lineWidth = 6; x.stroke();
  x.fillStyle = "#ffe2a0"; x.beginPath(); x.ellipse(48, 48, 24, 13, 0, 0, Math.PI * 2); x.fill(); x.fillStyle = "#d96a00"; x.beginPath(); x.arc(48, 48, 9, 0, Math.PI * 2); x.fill(); x.fillStyle = "#1a0c00"; x.beginPath(); x.arc(48, 48, 4, 0, Math.PI * 2); x.fill(); return new THREE.CanvasTexture(cv2); })();
function markOn(R, life, walls) { R.mark = life; const s = new THREE.Sprite(new THREE.SpriteMaterial({map: T_EYE, transparent: true, depthTest: !walls, depthWrite: false})); s.renderOrder = 8; flash(rapChest(R), 5, 0xffc070);
  addFx(s, life, (o, u) => { o.position.copy(rapChest(R)).add(V(0, 9 + Math.sin(clockT * 4) * 0.3, 0)); const pop = u * life < 0.15 ? E.back(u * life / 0.15) : 1; o.scale.setScalar(3.6 * pop); o.material.opacity = u > 0.85 ? (1 - u) / 0.15 : 1; }); }

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

function ventTrack() {
  const c = cfgNow("vent"), on = boostNow();
  const cc = NK.ventCarry, Vp = V(0, 0, -22);
  place(S, -26, 0); S.yaw = yawTo(S.pos, Vp);
  const T0 = 0.6, REL = T0 + 0.3, FLY = 0.45, LAND = REL + FLY, OPEN = LAND + 0.35, W0 = OPEN + 0.3, IN = W0 + 0.55;
  const F = flight({T0: IN, leap: on ? c.up : 11, flaps: on ? 0 : 2, fwd: 26, gfwd: 45});
  const SIN = IN + 0.55;
  const keys = [K(0, T_READY), K(T0, T_READY), K(T0 + 0.25, addPose(TA_WIND_W, {Tail1: [10, 0, 0]}, 1), "io"), K(REL, TA_THROW, "in2"), K(REL + 0.2, TA_FOLLOW, "out"), K(W0, T_READY, "io"), K(IN - 0.05, TJ_CROUCH, "io"), K(IN + 0.08, TF_UP, "out"), K(IN + 0.35, TF_DOWN, "io"), K(F.glideAt - 0.1, TF_UP, "io"), K(F.glideAt + 0.15, TF_GLIDE, "out"), K(F.landAt - 0.12, TF_GLIDE, "io"), K(F.landAt, TJ_DOWN, "io"), K(F.landAt + 0.12, TJ_LAND, "out"), K(F.landAt + 0.7, T_READY, "io")];
  let p0 = null, col = null;
  const sUp = on ? c.up : 0, sDur = on ? (c.float ? sUp / 8 + 0.4 : Math.sqrt(2 * sUp / 196.2) * 2) : 0;
  S.path = [[0, S.pos.clone(), S.yaw, 0], [IN - 0.3, S.pos.clone(), S.yaw, 0], [SIN, Vp.clone().add(V(-1, 0, 1)), S.yaw, 1], [SIN + 0.02, Vp.clone().add(V(-1, 0, 0)), S.yaw, 1], [SIN + sDur + 0.6, Vp.clone().add(V(-2, 0, -14)), S.yaw, on ? 0.2 : 0], [SIN + sDur + 0.9, Vp.clone().add(V(-2, 0, -15)), S.yaw, 0]];
  const ev = [];
  if (on) ev.push({t: T0, f: () => glowAt(() => carryPos(cc), ZONEC, 3, REL - T0, 0.7)}, {t: REL, f: () => { p0 = carryPos(cc); trailOn(() => carryPos(cc), ZONEC, FLY, 40, 1); }},
    {t: LAND, f: () => { groundRing(Vp, 6, ZONEC, 0.4, 1); }},
    {t: OPEN, f: () => { flash(Vp.clone().setY(1.5), 10, 0xc8fff4); groundRing(Vp, 9, WIND, 0.5, 1); col = windColumn(Vp, c.up, IN + 2.2 - OPEN); textTag(Vp.clone().add(V(0, 12, 0)), "UPDRAFT · " + c.life + " s", "#a8fff0", 1.4); }},
    {t: IN, f: () => { launchFx(Vp); textTag(heroHRP().add(V(0, 12, 0)), "LAUNCH " + Math.round(c.up) + " studs", "#ffffff", 1.2); }},
    {t: SIN, f: () => { launchFx(Vp); textTag(rapChest(S).add(V(0, 12, 0)), "SQUADMATE LAUNCHED", "#8fd0ff", 1.2); }});
  else ev.push({t: IN, f: () => wingPuff()}, ...F.FL.map(a => ({t: a, f: wingPuff})));
  return {follow: true, frame: [V(0, 0, 8), V(0, 0, -F.dist - 6)], keys, ev,
    update(t, dt) { PGLOW.vent = on ? 0.5 : 0; NS.ventOpen = 0; NS.ventSpin += dt * (on && t > OPEN ? 30 : 0);
      cc.k = !on ? 1 : t < IN + 2.2 ? 1 : t < F.landAt + 0.2 ? 0.001 : E.back(win(t, F.landAt + 0.2, F.landAt + 0.6));
      S.up = !on || t < SIN ? 0 : (() => { const q = t - SIN; if (c.float) { const v0 = Math.sqrt(2 * 196.2 * sUp), tp = v0 / 196.2; return q < tp ? v0 * q - 98.1 * q * q : Math.max(0, sUp - 8 * (q - tp)); } const v0 = Math.sqrt(2 * 196.2 * sUp); return Math.max(0, v0 * q - 98.1 * q * q); })(); },
    post(t) { if (!on || t < T0 || t > IN + 2.2) { carryOff(cc); return; } const dock = dockWorld(cc);
      if (t < REL) { carryAt(cc, dock); return; }
      if (t < LAND) { const u = win(t, REL, LAND); const p = p0.clone().lerp(Vp.clone().setY(0.6), u); p.y += 4 * 6 * u * (1 - u); carryAt(cc, new THREE.Matrix4().compose(p, new THREE.Quaternion().setFromEuler(new THREE.Euler(t * 9, 0, Math.PI / 2 * u)), V(2.4, 2.4, 2.4))); return; }
      const k = 2.4 + 5.6 * E.back(win(t, LAND, OPEN)), sh = t > IN + 1.9 ? 1 - win(t, IN + 1.9, IN + 2.2) : 1;
      carryAt(cc, new THREE.Matrix4().compose(Vp.clone().setY(0.35), new THREE.Quaternion().setFromEuler(new THREE.Euler(0, 0, Math.PI / 2)), V(1, 1, 1).multiplyScalar(Math.max(0.01, k * sh)))); },
    move(t) { if (t < W0) return {}; if (t < IN) return {z: -22 * win(t, W0, IN)}; const [f, u] = F.at(t); return {z: -22 - f, up: u}; },
    extra(target) { if (play.t > W0 && play.t < IN) walkLayer(target, 1, play.t * 11); },
    phases: on ? [[0, T0, "Slotted (takes a slot): the vent folded on the tail base"], [T0, REL, "Press: a tail flick and the arm swings it"], [REL, OPEN, "Throws the vent 22 studs; it lands and unfolds"], [OPEN, IN, "A wind column stands on it (" + c.life + " s)"], [IN, F.glideAt, "Steps in: shot " + Math.round(c.up) + " studs up, the squadmate follows"], [F.glideAt, F.landAt + 1, "Glides down (flaps reset); plain landing"]]
      : [[0, IN, "Today: no vent; it walks up"], [IN, F.glideAt, "Leap + 2 flaps (peak " + F.peak.toFixed(0) + " studs)"], [F.glideAt, F.landAt + 1, "Glide; the squadmate stays on the ground"]],
    len: F.landAt + 1.0};
}
function windColumn(p, h, life) { const g = new THREE.Group(); g.position.copy(p);
  const cyl = new THREE.Mesh(new THREE.CylinderGeometry(4.2, 5, h, 24, 1, true), new THREE.MeshBasicMaterial({color: WIND, transparent: true, opacity: 0.12, depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending})); cyl.position.y = h / 2; g.add(cyl);
  const pad = new THREE.Mesh(new THREE.CircleGeometry(5, 40), new THREE.MeshBasicMaterial({color: ZONEC, transparent: true, opacity: 0.35, depthWrite: false})); pad.rotation.x = -Math.PI / 2; pad.position.y = 0.2; g.add(pad);
  let em = 0, er = 0;
  return addFx(g, life, (o, u, dt) => { const k = Math.min(1, u * life / 0.2) * Math.min(1, (1 - u) * life / 0.4); cyl.material.opacity = 0.14 * k * (0.8 + 0.2 * Math.sin(clockT * 9)); pad.material.opacity = 0.35 * k;
    em += dt * 60; while (em >= 1) { em -= 1; const s = sprite(T_FLASH, Math.random() < 0.5 ? 0xffffff : 0xa8fff0, 0.9, true); const a = Math.random() * Math.PI * 2, r = Math.random() * 4; s.position.set(p.x + Math.cos(a) * r, 0.5, p.z + Math.sin(a) * r); s.scale.set(0.5, 2.6, 1); const vy = 30 + Math.random() * 20; addFx(s, h / vy, (q, uu, d) => { q.position.y += vy * d; q.material.opacity = 0.8 * (1 - uu) * k; }); }
    er += dt * 2.2; while (er >= 1) { er -= 1; const ring = new THREE.Mesh(new THREE.RingGeometry(3.6, 4.2, 40), new THREE.MeshBasicMaterial({color: WIND, transparent: true, opacity: 0.7, depthWrite: false, side: THREE.DoubleSide})); ring.rotation.x = -Math.PI / 2; ring.position.set(p.x, 0.5, p.z); addFx(ring, 1.1, (q, uu) => { q.position.y = 0.5 + h * uu; q.material.opacity = 0.7 * (1 - uu) * k; q.scale.setScalar(1 + 0.2 * uu); }); } }); }
function launchFx(p) { const c = p.clone().setY(1); flash(c, 10, 0xffffff); groundRing(p, 10, 0xffffff, 0.45, 1); for (let i = 0; i < 10; i++) puff(c.clone().add(V((Math.random() - .5) * 4, 0, (Math.random() - .5) * 4)), V((Math.random() - .5) * 10, 3, (Math.random() - .5) * 10), 1.6, 0xe8f4f2, 0.5, 0.6); }

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
const BUILD = {drum: drumTrack, bloom: bloomTrack, jets: jetsTrack, horn: hornTrack, fan: fanTrack, lens: lensTrack, burst: burstTrack, vent: ventTrack, set: setTrack, kit: kitTrack};

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
  for (const R of raps) { Object.assign(R, {flinch: 0, flash: 0, push: 0, slow: 0, tagged: false, path: null, run: 0, heal: 0, lunge: 0, bite: 0, show: false, hpShow: false, plume: 0, _bit: 0, up: 0, mark: 0, fastT: 0, amp: 0, noheal: 0, pathSet: 0}); }
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
  R.rig.yaw = R.yaw; R.rig.pos.copy(R.pos).addScaledVector(R.pushDir, R.push);
  pose(R.rig, {RootJoint: [10 * f - 6 * rn - 14 * l, 0, R.side * 8 * f], Neck: [12 * f - 4 * rn - 22 * l, R.side * -18 * f + Math.sin(ct * 0.8) * 4 * (1 - f), 0], Head: [10 * f, 0, 0], Jaw: [R.bite ? -2 : -22 * f - 34 * l, 0, 0],
    ArmL: [-25 * f + 20 * l, 0, 0], ArmR: [-25 * f + 20 * l, 0, 0], Tail1: [-10 * f, Math.sin(ct * 1.3) * 4, 0], Tail2: [0, Math.sin(ct * 1.3 - .7) * 5, 0],
    LegL: [-8 * f + 34 * s * rn, 0, 0], LegR: [-8 * f - 34 * s * rn, 0, 0], KneeL: [-10 * f - (18 + 22 * Math.max(0, c)) * rn, 0, 0], KneeR: [-10 * f - (18 + 22 * Math.max(0, -c)) * rn, 0, 0]});
  if (R.rig.rest !== null) { R.rig.y = R.rig.rest + Math.abs(c) * 1.2 * rn + (R.up || 0); pose(R.rig, {}); }
  const g = R.slow > 0 ? 0.12 : 0, h = R.heal > 0 ? R.heal / 0.4 : 0, fl = R.flash > 0 ? 1 : 0, mk = R.mark > 0 ? 0.35 + 0.1 * Math.sin(clockT * 6) : 0, am = R.amp > 0 ? 0.12 : 0, nh = R.noheal > 0 ? 0.14 : 0;
  R.rig.mats.forEach(m => m.emissive.setRGB(fl * R.flashCol[0] + (1 - fl) * (g * 0.9 + h * 0.05 + mk * 1.0 + nh * 0.7), fl * R.flashCol[1] + (1 - fl) * (g * 0.55 + h * 0.55 + mk * 0.42 + am * 1.4), fl * R.flashCol[2] + (1 - fl) * (h * 0.12 + am * 0.5 + nh * 1.2)));
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
  // the drum's chambers: lit = loaded, dark = spent, steel caps past the charge count
  for (const q of NK.cham) { const i = q.i; q.p.mesh.material = i < NS.charges ? CHAM[i] : MAT.steel; }
  CHAM.forEach((m, i) => { const lit = NS.cham[i]; m.color.setHex(lit ? 0xffc35a : 0x5a4a32); m.emissive.setHex(lit ? 0xb85a00 : 0x000000); m.emissiveIntensity = lit ? 1 + 0.25 * Math.sin(clockT * 5 + i) : 0; });
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
const PARTDIR = {drum: V(0.75, 0.6, 0.35), bloom: V(0.8, 0.55, 0.5), jets: V(0.75, 0.6, 0.55), horn: V(0.8, 0.45, 0.6), fan: V(0.7, 0.6, 0.7), lens: V(0.85, 0.35, -0.6), burst: V(0.55, -0.4, -0.75), vent: V(1, 0.3, 0.25), set: V(0.8, 0.5, 0.5)};
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
    <tr><th>Clips another part</th><td>${clashes.length ? '<span class="badn">' + clashes.map(([k, v]) => k.split(" × ").map(lookLabel).join(" × ") + " " + v + "%").join(", ") + "</span>" : '<span class="ok">none</span> (with the ' + (RECSET.includes(id) ? "other 3 recommended" : "4 recommended") + " + the 5 button parts, in its move and the kit poses)"}</td></tr>
    ${g ? `<tr><th>Closest other part at rest</th><td class="n">${g.studs} studs (${lookLabel(g.to)})</td></tr>` : ""}</table></div>
    <p class="note">${r.worst <= 5 ? "Passes the ≤ 5% rule" : "Over the 5% rule"} (worst ${r.worst}%). Measured ${MEAS.when} UTC, page v${MEAS.version}.</p>`;
}
function renderRec() {
  const recs = CANDS.filter(c => c.rec);
  $("recCard").innerHTML = `<div class="kind" style="color:var(--good)">Recommended set of 4 · all passives (no slots used)</div>
    <ol>${recs.map(c => `<li><b>${c.name}</b> (${c.covers.toLowerCase()}): ${c.one}</li>`).join("")}</ol>
    <p class="note"><b>Why these 4:</b> one per core verb of the kit (throw → zone → fly → heal), so every thing the troodon does gets visibly stronger and none of them waits for a rare moment. All four are passives, so the 4 slots stay free for the 5 buttons (Mender Drone, Arc Lantern, Sap Wall, Feather Shed, Portal Rift) and nothing overlaps them: no single-target heal (Mender), no stun (Lantern), no wall (Sap), no break-free (Shed), no teleport (Rift). Each sits on its own spot (behind the neck, lower back, tail base, tail) clear of the 5 button parts. Swaps: <b>Glide Fan</b> for Wing Jets if longer glides matter more than higher flaps; <b>Watcher Lens</b> for Chorus Horn for a damage-support troodon; <b>Bloom Burst</b> if you want one pressed move (it takes a slot).</p>`;
}
function renderAll() {
  const c = CUR(), id = c.id;
  $("moves").innerHTML = CANDS.map((m, i) => `<button class="tab" data-i="${i}" aria-pressed="${i === cur}">${m.rec ? '<span class="star" title="Recommended">★</span>' : ""}${m.code ? m.code + " · " : ""}${m.name}<small>${m.kind === "PASSIVE" ? '<span class="pill pas">Passive</span>' : m.kind === "BUTTON" ? '<span class="pill btn2">Button</span>' : ""}${m.covers}</small></button>`).join("");
  $("rankRow").innerHTML = RANKS.map((r, i) => `<button class="chip" data-rank="${i}" aria-pressed="${i === rank}">${r}</button>`).join("");
  document.querySelectorAll("[data-mode]").forEach(b => b.setAttribute("aria-pressed", b.dataset.mode === mode));
  $("liveChip").setAttribute("aria-pressed", liveOn); $("liveChip").textContent = liveOn ? "5 button parts on" : "5 button parts off";
  const ph = play ? play.track.phases : [];
  $("phases").innerHTML = ph.map(p => `<button class="ph" data-t="${p[0]}" aria-current="false"><i>${p[0].toFixed(2)}–${p[1].toFixed(2)} s</i>${p[2]}</button>`).join("");
  if (id === "set") {
    $("info").innerHTML = `<div class="kind" style="color:var(--good)">Clash check</div><h2>Every ticked part on at once</h2><p class="note">Passives don't use slots, so all 4 picked passives are on together, plus whichever buttons are slotted. Tick any candidate; the 5 button parts follow the chip above. It cycles idle → pod throw → flaps → glide → run, the poses that move the arms, tail and legs most.</p>
      <div class="row">${CID.map(p => `<button class="chip" data-chip="${p}" aria-pressed="${!!setOn[p]}">${NAME(p)}</button>`).join("")}</div>`;
    let m = '<div class="kind">Measured clashes</div>';
    if (MEAS) { const recP = Object.entries(MEAS.rec || {}).filter(([, v]) => v > 0);
      m += `<p><b>Recommended 4 + the 5 button parts</b>, every recommended part's move + the kit poses: ${recP.length ? '<span class="badn">' + recP.map(([k, v]) => k.split(" × ").map(lookLabel).join(" × ") + " " + v + "%").join(", ") + "</span>" : '<span class="ok">no piece of one part inside a piece of another (0%)</span>'}.</p>`;
      m += `<p><b>Each alternative added to that set:</b></p><ul>${CID.filter(i => !RECSET.includes(i)).map(i => { const a = Object.entries((MEAS.alt || {})[i] || {}); return `<li>${NAME(i)}: ${a.length ? '<span class="badn">' + a.map(([k, v]) => k.split(" × ").map(lookLabel).join(" × ") + " " + v + "%").join(", ") + "</span>" : '<span class="ok">0%</span>'}</li>`; }).join("")}</ul>`;
      m += `<div class="tw"><table class="cmp"><tr><th>Part</th><th>Worst in body (idle / move / throw / flaps / glide / run)</th><th>Closest part at rest</th></tr>${CID.map(i => { const r = MEAS.looks[i + ".A"], g = MEAS.gaps[i]; return `<tr><th>${NAME(i)}</th><td class="n">${r.idle} / ${r.move} / ${r.kit.throw} / ${r.kit.flaps} / ${r.kit.glide} / ${r.kit.run} %</td><td class="n">${g.studs} studs · ${lookLabel(g.to)}</td></tr>`; }).join("")}</table></div>`; }
    else m += '<p class="note">Not measured in this build.</p>';
    $("part").innerHTML = m; return;
  }
  const kindTxt = c.kind === "PASSIVE" ? "Passive · no button · no slot" : "Button · takes a slot";
  const rows = RANKS.map((r, i) => `<tr class="${i === rank ? "cur" : ""}"><th>${r}</th><td>${c.steps[i]}</td></tr>`).join("");
  const today = cmpRows(id);
  $("info").innerHTML = `<div class="kind" style="color:${c.kind === "PASSIVE" ? "#14a58c" : "#c25e08"}">${c.code} · ${kindTxt} · boosts: ${c.covers}${c.rec ? ' <span class="rec">Recommended</span>' : ""}</div><h2>${c.name}</h2><p>${c.one}</p>
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
  const L = {drum: [["Pod charges", "charges"], ["Refill per pod (s)", "refill"], ["Pod flight (s)", "fly"]], bloom: [["Zone width (studs)", "R", v => fmt(v * 2)], ["Zone time (s)", "life"], ["End bloom", "bloom", v => v ? "yes" : "no"]],
    jets: [["Flap height (studs)", "flapH"], ["Forward while flapping (studs/s)", "fwd"], ["Flaps after the leap", "flaps"], ["Glide fall (studs/s)", "fall"]], fan: [["Glide fall (studs/s)", "fall"], ["Glide speed (studs/s)", "gfwd"], ["Thermal over zones", "thermal", v => v ? "yes" : "no"]],
    horn: [["Zone heal / s (squad)", "heal"], ["Splat note", "note", v => v ? "+" + fmt(v) : "none"], ["Speed in zone", "speed", v => v ? "+15%" : "none"]], lens: [["Mark time (s)", "mark", v => v ? fmt(v) : "no marks"], ["Seen through walls", "walls", v => v ? "yes" : "no"], ["Heal on hitting a mark", "heal", v => v ? "+2" : "no"]],
    burst: [["Burst heal", "heal", (v, o) => o.on ? "+" + v : "none"], ["Heal boost (s)", "amp", (v, o) => o.on ? fmt(v) : "none"], ["Width (studs)", "R", (v, o) => o.on ? v * 2 : "—"], ["Recharge (s)", "cd", (v, o) => o.on ? v : "—"]],
    vent: [["Launch (studs up)", "up", (v, o) => o.on ? fmt(v) : "jump only (peak ~15)"], ["Vent lasts (s)", "life", (v, o) => o.on ? fmt(v) : "—"], ["Squad lifted", "on", v => v ? "yes" : "no"]]}[id];
  return L.map(([n, k, f]) => `<tr><th>${n}</th><td class="n">${f ? f(a[k], a) : fmt(a[k])}</td><td class="n">${f ? f(b[k], b) : fmt(b[k])}</td></tr>`).join("");
}
function foot() {
  $("foot").innerHTML = `<b>Notes</b><ol>
  <li><b>Kepu's rules applied.</b> Passive = no button, no slot, always on once bought, visible hardware, makes a core move stronger every time (the raptor's Blade Claws, the therizino's Overclock Joints). Button = takes a slot. Nothing that waits for a rare moment (the 4 removed parts all did: a killing hit, overheal, standing in a zone, a second enemy). No overlap with the 5 live buttons.</li>
  <li><b>Readability.</b> Each part is 1–3 big shapes on posts and brackets on the body surface (no greebles), one accent per job (pod amber, zone teal, heal green, mark amber-orange), and it moves or glows on the move it boosts so the passive is seen working. Checked up close (face, 3/4, side, front, top) and from the 70-stud game camera.</li>
  <li><b>Inspiration only.</b> The games named on each card give the component's idea; no shape, texture or colour scheme is copied. Sources were looked up for this page (links on each card).</li>
  <li><b>VFX consistency.</b> Pods, splats and zones are the live TrooFX ones (amber pod, teal zone, ring wave, spores); heals are the Med-Station's green MedWave + MedHealPop; rings follow TenoMovesFX's flat neon rings; the flight is the live Flap & Glide (leap 11 studs, flaps ~11 studs, glide 8 studs/s down at 45 studs/s). No landing FX anywhere.</li>
  <li><b>Fit measurement.</b> Each piece (box / cylinder / sphere / torus) is sampled at 125 points through its volume; inside = inside any visible Troodon body box (188 parts, feathers included). Idle and the move every 0.05 s at ★; the kit poses every frame: throw wind-up (arms 12° wider, TrooPose 1.3), flaps, glide, run (legs ±42°, knees to −68°, arms ±16°). Brackets are set 40% into the surface on purpose and listed apart. Clashes: every piece's points against every other part's pieces, recommended 4 + the 5 live button looks (TrooPartsLooks 1.0: Mender A, Lantern A, Sap Wall B, Shed A, Portal A), in every recommended move and the kit poses; each alternative is added to that set and checked the same way. Source: tools/troodon_newparts_mockup/newparts.js (window.__np.measure), run by measure.js.</li>
  <li><b>Game camera</b> = ShoulderCam 1.8 for the troodon at the 2x body: 70 studs back, 12° down, right shoulder, FOV 70. <b>Numbers</b> are proposals; the live kit is TroodonModelData 1.10 (pod 6, zone 40 studs / 3 s / 1 per s / squad +5 per s / slow 25%, 3 charges refilling 2 s, flight 0.37 s).</li></ol>`;
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
