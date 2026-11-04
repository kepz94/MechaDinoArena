// Therizino mecha button parts mockup v0.1 (Kepu 2026-11-04 picks from the 20-option list: 1 Reaper's Hook, 3 Feather Barrage,
// 5 Harvest Field, 12 Grapple Zip, 16 Deflector Claws, 18 Overclock Joints, 19 Snare Wires). LOOKS only: where each block-style
// mecha part sits on the body (A / B / C) and a looping preview of the maxed (★) effect. THERI = TherizinoModelData (look A
// Reaper, tools/therizino_generator.py --json), HERRERA = enemy dummies. The step ladder is a draft, to confirm in the plan.
const THERI = __THERI__;
const HERRERA = __HERRERA__;
const VERSION = "0.1";
const $ = id => document.getElementById(id);
const rad = THREE.MathUtils.degToRad;
const AREA = {attack: ["ATTACK", "#f05a4f"], defense: ["DEFENSE", "#5aa0ff"], speed: ["SPEED", "#ffd34d"], health: ["HEALTH", "#5fd16a"], eng: ["ENGINEER", "#ff9b2e"]};
const STEEL = 0x9aa3ad, DARK = 0x3a3f47, BRASS = 0xc9a24a, RED = 0xe02a2a, FEATHER = 0xf0ead8, BLOOD = 0xc0182a, WIRE = 0xdfe6ee,
  GLOW = 0xff7a1a, VOLT = 0x7fe9ff, ROCKC = 0x8a8478, SKY = 0x8fc6e8, BARK = 0x6b4a2a, LEAF = 0x4f8a3a, MUDC = 0x5b3d22;

// ---------- the 7 parts (maxed texts exactly as in the 20-option list) ----------
const PARTS = [
  {id: "hook", n: 1, name: "Reaper's Hook", area: "attack", len: 4.4,
    maxed: "Fires a claw chain 80 studs, yanks the dino in, stuns it 1 s and starts cut 1 on it.",
    ladder: ["Button: fires a claw chain 50 studs and yanks the dino in. Recharges in 18 s", "Chain reaches 65 studs",
      "Chain reaches 80 studs; recharges in 15 s", "The yanked dino is stunned 1 s and cut 1 starts on it"],
    looks: [{name: "A · Wrist Winch", sub: "winch drum on the right forearm", why: "A steel winch drum bolted on the right forearm and a hook launcher on the back of the hand. The chain comes out between the claws and the drum spins as it reels in.", mount: "ArmR_fore"},
      {name: "B · Chest Harpoon", sub: "boxy launcher on the chest", why: "A boxy harpoon launcher strapped to the chest under the neck. The chain fires straight ahead from the barrel, so it reads from far away.", mount: "Torso_chest"},
      {name: "C · Back Crane", sub: "crane arm over the shoulders", why: "A short crane arm on the back that rises over the head. The hook swings out from the crane tip and drags the dino in under it.", mount: "Torso_body"}]},
  {id: "feather", n: 3, name: "Feather Barrage", area: "attack", len: 3.4,
    maxed: "Fires 12 feather blades in a fan (30 studs): 3 damage each, and hit dinos are slowed 25% for 2 s.",
    ladder: ["Button: fires 8 feather blades in a fan (20 studs): 3 damage each, hit dinos slowed 25% for 1 s. Recharges in 14 s", "10 blades, fan reaches 25 studs",
      "Slow lasts 2 s", "12 blades, fan reaches 30 studs"],
    looks: [{name: "A · Arm Racks", sub: "blade racks on both forearms", why: "A steel rack on each forearm holding 6 blades. Both arms sweep out and the blades fly from the racks.", mount: "ArmL_fore"},
      {name: "B · Back Fan", sub: "fan of blades on the back", why: "A mecha fan of 12 blades on the back, spread like a tail fan. It flicks forward and the blades leave from the top.", mount: "Torso_body"},
      {name: "C · Tail Pods", sub: "two blade pods on the tail", why: "Two blade pods on the middle of the tail. The tail whips round and the blades come over the shoulder.", mount: "Tail3_main"}]},
  {id: "harvest", n: 5, name: "Harvest Field", area: "attack", len: 6.6,
    maxed: "Stabs the claws down to make a 20-stud circle for 5 s. Enemies inside bleed 4/s and are slowed 30%.",
    ladder: ["Button: stab the claws down: a 12-stud circle for 3 s. Enemies inside bleed 4/s and are slowed 30%. Recharges in 20 s", "Circle 16 studs",
      "Lasts 4 s", "Circle 20 studs, lasts 5 s"],
    looks: [{name: "A · Claw Spikes", sub: "steel caps on the claw tips", why: "Steel spike caps on every claw tip. The claws stab down and the spikes glow red where they hit the ground.", mount: "ArmL_hand"},
      {name: "B · Arm Pistons", sub: "piston rams on the forearms", why: "A piston ram on each forearm. The rams punch down next to the claws and crack the ground into the circle.", mount: "ArmL_fore"},
      {name: "C · Hand Drills", sub: "drill bits on the hands", why: "A drill bit under each hand. They spin into the ground and the circle spreads out from the two holes.", mount: "ArmL_hand"}]},
  {id: "grapple", n: 12, name: "Grapple Zip", area: "speed", len: 4.8,
    maxed: "Hooks a tree or wall up to 70 studs away and zips there. 2 charges.",
    ladder: ["Button: hook a tree or wall up to 40 studs away and zip there. Recharges in 12 s", "Reaches 55 studs",
      "Reaches 70 studs; recharges in 10 s", "2 charges"],
    looks: [{name: "A · Wrist Grapple", sub: "grapple gun on the left wrist", why: "A grapple gun on the back of the left hand. The arm points and the line shoots from the wrist.", mount: "ArmL_hand"},
      {name: "B · Shoulder Reel", sub: "reel on the left shoulder", why: "A big cable reel on the left shoulder. The line fires from the reel and you can see it spin while you zip.", mount: "ArmL_shoulder"},
      {name: "C · Belly Winch", sub: "winch under the body", why: "A heavy winch under the belly. The line fires from the chest and pulls the whole body low along it.", mount: "Torso_body"}]},
  {id: "deflect", n: 16, name: "Deflector Claws", area: "defense", len: 4.4,
    maxed: "Claws spin in front for 2 s and bounce darts, rockets, boulders and cannon shots back at the shooter.",
    ladder: ["Button: claws spin in front for 1 s and block darts and rockets. Recharges in 16 s", "Spin 1.5 s; blocks boulders and cannon shots too",
      "Spin 2 s; recharges in 13 s", "Blocked shots bounce back at the shooter"],
    looks: [{name: "A · Spinner Hubs", sub: "hub on each hand", why: "A spinner hub on each hand. The arms push forward and the claws turn into two spinning discs.", mount: "ArmL_hand"},
      {name: "B · Chest Rotor", sub: "one big rotor on the chest", why: "A rotor housing on the chest with a ring of mecha claws. It unfolds into one big spinning disc in front of the body.", mount: "Torso_chest"},
      {name: "C · Orbit Claws", sub: "claw blades circling in front", why: "Six claw blades on a track around the front half. They whip round in a half-circle wall in front of the dino.", mount: "Torso_body"}]},
  {id: "overclock", n: 18, name: "Overclock Joints", area: "speed", len: 5.8,
    maxed: "For 5 s, run 40% faster, cut taps come 30% faster, and slows don't work on you.",
    ladder: ["Button: for 3 s, run 40% faster. Recharges in 22 s", "Lasts 4 s; cut taps come 30% faster too",
      "Lasts 5 s; recharges in 18 s", "Slows don't work on you while it's on"],
    looks: [{name: "A · Knee Pistons", sub: "pistons on hips and knees", why: "Piston blocks on the hips and knees. They pump and glow orange while it's on, with steam from the knees.", mount: "LegL_thigh"},
      {name: "B · Back Boiler", sub: "boiler with two stacks", why: "A brass boiler on the back with two stacks. Steam pours from the stacks and the joints glow while it's on.", mount: "Torso_body"},
      {name: "C · Joint Rings", sub: "glow rings on every joint", why: "Steel rings on the shoulders, hips and knees. They light up hot orange while it's on.", mount: "ShinL_knee"}]},
  {id: "snare", n: 19, name: "Snare Wires", area: "eng", len: 5.6,
    maxed: "Lays 3 wire traps. The first dino to cross one is rooted 2 s and takes 12.",
    ladder: ["Button: lay 1 wire trap. The first dino to cross it is rooted 1 s and takes 12. Recharges in 18 s", "2 traps",
      "Rooted 2 s", "3 traps"],
    looks: [{name: "A · Tail Spools", sub: "wire spools on the tail", why: "Three wire spools on the tail. The tail flicks and the traps fly over the head to land in front.", mount: "Tail3_main"},
      {name: "B · Forearm Reels", sub: "a reel on each forearm", why: "A wire reel on each forearm. The arms throw the traps out like nets.", mount: "ArmL_fore"},
      {name: "C · Belly Dispenser", sub: "trap box under the body", why: "A box under the belly that drops the traps and rolls them out on the ground.", mount: "Torso_body"}]},
];
const SLOTS = ["R", "T", "C", "V"];

// ---------- picks (this viewer only; nothing in the game changes) ----------
const PICK_KEY = "theriPartsPick_v0.1";
let PICK = {};
try { PICK = JSON.parse(localStorage.getItem(PICK_KEY) || "{}") || {}; } catch (e) { PICK = {}; }
function savePick() { try { localStorage.setItem(PICK_KEY, JSON.stringify(PICK)); } catch (e) {} }

// ---------- three ----------
const cv = $("cv");
const renderer = new THREE.WebGLRenderer({canvas: cv, antialias: true, preserveDrawingBuffer: true});
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
const scene = new THREE.Scene();
scene.background = new THREE.Color(SKY); scene.fog = new THREE.Fog(SKY, 180, 380);
const cam = new THREE.PerspectiveCamera(40, 16 / 9, 0.1, 800);
scene.add(new THREE.HemisphereLight(0xf2f8ff, 0x8a7a5a, 0.85));
const sun = new THREE.DirectionalLight(0xffffff, 0.75); sun.position.set(30, 50, -10); scene.add(sun);
const ground = new THREE.Mesh(new THREE.PlaneGeometry(900, 900), new THREE.MeshLambertMaterial({color: 0x9fbf6a}));
ground.rotation.x = -Math.PI / 2; scene.add(ground);
for (let i = 0; i < 260; i++) {
  const s = 0.3 + Math.random() * 0.6, p = new THREE.Mesh(new THREE.BoxGeometry(s, s * 0.5, s), new THREE.MeshLambertMaterial({color: i % 3 ? 0x7f9a52 : 0x6a5c44}));
  p.position.set((Math.random() - 0.5) * 160, s * 0.2, 60 - Math.random() * 260); scene.add(p);
}
function cfm(a) { const m = new THREE.Matrix4(); m.set(a[3], a[4], a[5], a[0], a[6], a[7], a[8], a[1], a[9], a[10], a[11], a[2], 0, 0, 0, 1); return m; }
const tmpE = new THREE.Euler();
function rot(p, y, r) { tmpE.set(rad(r), rad(y), rad(p), "ZYX"); return new THREE.Matrix4().makeRotationFromEuler(tmpE); }
function buildDino(D, scale, tint, alpha) {
  const g = new THREE.Group(); scene.add(g);
  const segs = {}, parts = [], byName = {};
  for (const s of D.segs) {
    const rootInv = cfm(s.root).invert(); segs[s.n] = [];
    for (const p of s.parts) {
      const base = new THREE.Color(parseInt(p.c, 16)); if (tint) base.lerp(new THREE.Color(tint[0]), tint[1]);
      const mat = new THREE.MeshLambertMaterial({color: base.clone(), emissive: 0x000000, transparent: !!alpha, opacity: alpha || 1, depthWrite: !alpha});
      const m = new THREE.Mesh(new THREE.BoxGeometry(p.s[0], p.s[1], p.s[2]), mat); m.matrixAutoUpdate = false; g.add(m);
      const info = {mesh: m, local: rootInv.clone().multiply(cfm(p.cf)), cf: cfm(p.cf), size: p.s, seg: s.n, name: p.n, base}; segs[s.n].push(info); parts.push(info); byName[p.n] = info;
    }
  }
  const joints = D.joints.map(j => ({n: j.n, p0: j.p0, p1: j.p1, c0: cfm(j.c0), c1inv: cfm(j.c1).invert()}));
  return {D, g, segs, parts, byName, joints, scale, x: 0, y: 0, z: 0, yaw: 0, roll: 0, pitchW: 0};
}
const corner = new THREE.Vector3();
function pose(d, A) {
  const W = {HRP: new THREE.Matrix4().makeRotationY(d.yaw).multiply(new THREE.Matrix4().makeRotationX(d.pitchW || 0)).multiply(new THREE.Matrix4().makeRotationZ(d.roll || 0))};
  for (const j of d.joints) { const v = A[j.n] || [0, 0, 0]; W[j.p1] = W[j.p0].clone().multiply(j.c0).multiply(rot(v[0], v[1], v[2])).multiply(j.c1inv); }
  const S = new THREE.Matrix4().makeScale(d.scale, d.scale, d.scale);
  let minY = Infinity;
  for (const n in d.segs) for (const p of d.segs[n]) {
    const m = S.clone().multiply(W[n]).multiply(p.local); p.mesh.matrix.copy(m);
    if (d.restMinY === undefined) for (let i = 0; i < 8; i++) { corner.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(m); minY = Math.min(minY, corner.y); }
  }
  if (d.restMinY === undefined) d.restMinY = minY; // stand on the rest pose's lowest point
  const lift = new THREE.Matrix4().makeTranslation(d.x, -d.restMinY + d.y, d.z);
  for (const p of d.parts) p.mesh.matrix.premultiply(lift);
}
function partPos(d, name, local) { return new THREE.Vector3(...(local || [0, 0, 0])).applyMatrix4(d.byName[name].mesh.matrix); }
// a point given in the rest model's HRP space, carried by a part as it moves
function restOn(d, name, p) { const inv = d.byName[name].cf.clone().invert(); return new THREE.Vector3(...p).applyMatrix4(inv).applyMatrix4(d.byName[name].mesh.matrix); }

// ---------- actors ----------
const theri = buildDino(THERI, 1);
const ghost = buildDino(THERI, 1, [0xbfd8ff, 0.6], 0.28); ghost.g.visible = false;
const foes = [0, 1, 2, 3].map(() => { const d = buildDino(HERRERA, 1.6, [0xd0202a, 0.25]); d.g.visible = false; return Object.assign(d, {active: false}); });
const HPOSE = {RootJoint: [-24, 0, 0], Neck: [6, 0, 0], Head: [16, 0, 0], Jaw: [-3, 0, 0], ArmL: [30, 0, -18], ArmR: [30, 0, 18],
  LegL: [48, 0, -16], LegR: [48, 0, 16], KneeL: [-48, 0, 0], KneeR: [-48, 0, 0], AnkleL: [24, 0, 0], AnkleR: [24, 0, 0],
  Tail1: [26, 0, 0], Tail2: [4, 0, 0], Tail3: [8, 0, 0], Tail4: [14, 0, 0], Tail5: [20, 0, 0]};
const stars = foes.map(() => [0, 1, 2].map(() => { const m = new THREE.Mesh(new THREE.OctahedronGeometry(0.45), new THREE.MeshBasicMaterial({color: 0xffe04a})); m.visible = false; scene.add(m); return m; }));
const wraps = foes.map(() => [0, 1, 2].map(() => { const m = new THREE.Mesh(new THREE.TorusGeometry(1.6, 0.12, 6, 24), new THREE.MeshBasicMaterial({color: WIRE})); m.rotation.x = Math.PI / 2; m.visible = false; scene.add(m); return m; }));

// ---------- effects ----------
const fx = [];
function addFx(o) { fx.push(o); return o; }
function dust(pos, n, spread, up, size, color, life) {
  for (let i = 0; i < n; i++) {
    const m = new THREE.Mesh(new THREE.IcosahedronGeometry(size * (0.6 + Math.random() * 0.8), 0), new THREE.MeshLambertMaterial({color: color || 0xcbb487, transparent: true, opacity: 0.85}));
    const a = Math.random() * Math.PI * 2, r = Math.random() * spread * 0.4;
    m.position.set(pos.x + Math.cos(a) * r, pos.y + 0.5, pos.z + Math.sin(a) * r); scene.add(m);
    addFx({m, t: 0, life: (life || 1.0) + Math.random() * 0.6, v: new THREE.Vector3(Math.cos(a) * spread * (0.6 + Math.random()), up * (0.5 + Math.random()), Math.sin(a) * spread * (0.6 + Math.random())), grow: 1.6, kind: "dust"});
  }
}
function steam(pos, n, dir) {
  for (let i = 0; i < n; i++) {
    const m = new THREE.Mesh(new THREE.IcosahedronGeometry(0.35 + Math.random() * 0.3, 0), new THREE.MeshLambertMaterial({color: 0xf4f6f8, transparent: true, opacity: 0.8}));
    m.position.copy(pos); scene.add(m);
    const v = (dir || new THREE.Vector3(0, 1, 0)).clone().multiplyScalar(4 + Math.random() * 3).add(new THREE.Vector3((Math.random() - 0.5) * 2, Math.random() * 2, (Math.random() - 0.5) * 2));
    addFx({m, t: 0, life: 0.7 + Math.random() * 0.4, v, grow: 2.4, kind: "dust"});
  }
}
function ring(pos, r1, life, color, y) {
  const m = new THREE.Mesh(new THREE.RingGeometry(0.85, 1, 56), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0.9, side: THREE.DoubleSide}));
  m.rotation.x = -Math.PI / 2; m.position.set(pos.x, y === undefined ? 0.2 : y, pos.z); scene.add(m);
  addFx({m, t: 0, life, r0: 1, r1, kind: "ring"});
}
function flash(pos, size, color) {
  const m = new THREE.Mesh(new THREE.SphereGeometry(1, 16, 12), new THREE.MeshBasicMaterial({color: color || 0xffffff, transparent: true, opacity: 0.85}));
  m.position.copy(pos); scene.add(m); addFx({m, t: 0, life: 0.3, size, kind: "flash"});
}
function sparks(pos, n, color) {
  for (let i = 0; i < n; i++) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.12, 0.9), new THREE.MeshBasicMaterial({color: color || 0xfff1a0, transparent: true}));
    const v = new THREE.Vector3(Math.random() - 0.5, Math.random() * 0.8, Math.random() - 0.5).normalize().multiplyScalar(14 + Math.random() * 10);
    m.position.copy(pos); m.lookAt(pos.clone().add(v)); scene.add(m); addFx({m, t: 0, life: 0.35 + Math.random() * 0.2, v, grow: 0, kind: "spark"});
  }
}
function slashMark(pos, color) { // three claw slash marks facing the side camera
  for (let k = -1; k <= 1; k++) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(0.25, 6, 0.25), new THREE.MeshBasicMaterial({color: color || 0xff4a4a, transparent: true}));
    m.position.set(pos.x + 1.2, pos.y, pos.z + k * 1.3); m.rotation.x = 0.5; scene.add(m); addFx({m, t: 0, life: 0.6, kind: "slash"});
  }
}
function streak(pos, len) { // speed line left behind a runner
  const m = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.12, len), new THREE.MeshBasicMaterial({color: 0xffffff, transparent: true, opacity: 0.8}));
  m.position.copy(pos); scene.add(m); addFx({m, t: 0, life: 0.35, kind: "streak"});
}
function drip(pos) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(0.35, 0.35, 0.35), new THREE.MeshBasicMaterial({color: BLOOD, transparent: true}));
  m.position.copy(pos); scene.add(m); addFx({m, t: 0, life: 0.6, v: new THREE.Vector3((Math.random() - 0.5) * 3, 3, (Math.random() - 0.5) * 3), grow: 0, kind: "drip"});
}
const popsEl = $("pops");
function popNum(pos, txt, cls) {
  const el = document.createElement("div"); el.className = "pop " + (cls || ""); el.textContent = txt; popsEl.appendChild(el);
  addFx({el, pos: pos.clone().add(new THREE.Vector3(0, 9, 0)), t: 0, life: 1.1, kind: "pop"});
}
function clearFx() { for (const f of fx) { if (f.m) { scene.remove(f.m); f.m.geometry.dispose(); } if (f.el) f.el.remove(); } fx.length = 0; }
let shake = 0;
function updateFx(dt) {
  for (let i = fx.length - 1; i >= 0; i--) {
    const f = fx[i]; f.t += dt; const u = f.t / f.life;
    if (u >= 1) { if (f.m) { scene.remove(f.m); f.m.geometry.dispose(); } if (f.el) f.el.remove(); fx.splice(i, 1); continue; }
    if (f.kind === "dust") { f.m.position.addScaledVector(f.v, dt); f.v.multiplyScalar(1 - dt * 2.2); f.m.scale.setScalar(1 + u * f.grow); f.m.material.opacity = 0.85 * (1 - u); }
    else if (f.kind === "spark") { f.m.position.addScaledVector(f.v, dt); f.v.y -= 30 * dt; f.m.material.opacity = 1 - u; }
    else if (f.kind === "drip") { f.m.position.addScaledVector(f.v, dt); f.v.y -= 25 * dt; if (f.m.position.y < 0.1) f.m.position.y = 0.1; f.m.material.opacity = 1 - u * u; }
    else if (f.kind === "ring") { const r = f.r0 + (f.r1 - f.r0) * (1 - Math.pow(1 - u, 3)); f.m.scale.set(r, r, r); f.m.material.opacity = 0.9 * (1 - u); }
    else if (f.kind === "flash") { f.m.scale.setScalar(f.size * (0.4 + u)); f.m.material.opacity = 0.85 * (1 - u); }
    else if (f.kind === "slash" || f.kind === "streak") { f.m.material.opacity = 0.9 * (1 - u); }
    else if (f.kind === "pop") { const p = f.pos.clone().add(new THREE.Vector3(0, u * 5, 0)).project(cam); f.el.style.left = ((p.x + 1) / 2 * 100) + "%"; f.el.style.top = ((1 - p.y) / 2 * 100) + "%"; f.el.style.opacity = u < 0.7 ? 1 : (1 - u) / 0.3; }
  }
}
const tagsEl = $("tags"), tagEls = new Map();
function setTag(key, actor, text, cls, h) {
  let el = tagEls.get(key);
  if (!text) { if (el) { el.remove(); tagEls.delete(key); } return; }
  if (!el) { el = document.createElement("div"); tagsEl.appendChild(el); tagEls.set(key, el); }
  el.className = "st " + (cls || ""); el.textContent = text;
  const p = new THREE.Vector3(actor.x, (actor.y || 0) + (h || 12), actor.z).project(cam);
  el.style.left = ((p.x + 1) / 2 * 100) + "%"; el.style.top = ((1 - p.y) / 2 * 100) + "%"; el.style.display = p.z < 1 ? "block" : "none";
}
function clearTags() { for (const el of tagEls.values()) el.remove(); tagEls.clear(); }

// ---------- world helpers ----------
const world = [];
function wmesh(geo, color, o) {
  o = o || {};
  const mat = o.basic ? new THREE.MeshBasicMaterial({color, transparent: !!o.alpha, opacity: o.alpha || 1, side: o.side || THREE.FrontSide, depthWrite: !o.alpha})
    : new THREE.MeshLambertMaterial({color, emissive: o.glow ? color : 0x000000, emissiveIntensity: o.glow || 0, transparent: !!o.alpha, opacity: o.alpha || 1});
  const m = new THREE.Mesh(geo, mat); scene.add(m); world.push(m); return m;
}
function clearWorld() { for (const m of world) { scene.remove(m); m.geometry.dispose(); } world.length = 0; }
const UP = new THREE.Vector3(0, 1, 0);
function beam(m, a, b, r) { // a unit cylinder (height 1 along y) stretched from a to b
  const d = b.clone().sub(a), L = d.length(); m.visible = L > 0.05;
  m.position.copy(a).addScaledVector(d, 0.5); m.scale.set(r, Math.max(L, 0.01), r); if (L > 0) m.quaternion.setFromUnitVectors(UP, d.normalize());
}
// chain: a pool of links between two points
const links = [];
for (let i = 0; i < 120; i++) { const m = new THREE.Mesh(new THREE.BoxGeometry(0.42, 0.42, 0.9), new THREE.MeshLambertMaterial({color: i % 2 ? 0x7c848e : 0xb8c0c8})); m.visible = false; scene.add(m); links.push(m); }
let linkUsed = 0;
function chain(a, b, step) {
  const d = b.clone().sub(a), L = d.length(), n = Math.min(links.length - linkUsed, Math.floor(L / (step || 0.85)));
  for (let k = 0; k < n; k++) { const m = links[linkUsed++]; m.visible = true; m.position.copy(a).addScaledVector(d, (k + 0.5) / Math.max(1, n)); m.lookAt(b); if (k % 2) m.rotateZ(Math.PI / 2); }
}
function hideLinks() { for (let i = 0; i < links.length; i++) links[i].visible = false; linkUsed = 0; }
const lineM = new THREE.Mesh(new THREE.CylinderGeometry(1, 1, 1, 6), new THREE.MeshBasicMaterial({color: WIRE})); lineM.visible = false; scene.add(lineM);

// ---------- mecha pieces (follow a part of the therizino; positions given in rest model space) ----------
const equip = [];
function piece(partName, size, pos, rotd, color, o) {
  o = o || {};
  const geo = o.cyl ? new THREE.CylinderGeometry(size[0] / 2, (o.cone ? 0.02 : size[0]) / 2, size[1], 14) : o.torus ? new THREE.TorusGeometry(size[0], size[1], 8, 24) : new THREE.BoxGeometry(size[0], size[1], size[2]);
  const mat = new THREE.MeshLambertMaterial({color, emissive: 0x000000});
  const m = new THREE.Mesh(geo, mat); m.matrixAutoUpdate = false; scene.add(m);
  const part = theri.byName[partName];
  const off = part.cf.clone().invert().multiply(new THREE.Matrix4().makeTranslation(...pos)).multiply(rot(...(rotd || [0, 0, 0])));
  const e = {mesh: m, partName, off, extra: o.extra, show: o.show, glowable: o.glowable, color};
  equip.push(e); return e;
}
function updateEquip() {
  for (const e of equip) {
    const m = theri.byName[e.partName].mesh.matrix.clone().multiply(e.off); if (e.extra) m.multiply(e.extra());
    e.mesh.matrix.copy(m); e.mesh.visible = e.show ? e.show() : true;
  }
}
function clearEquip() { for (const e of equip) { scene.remove(e.mesh); e.mesh.geometry.dispose(); } equip.length = 0; }
function glowEquip(k, color) { for (const e of equip) if (e.glowable) e.mesh.material.emissive.setHex(color || GLOW).multiplyScalar(k); }
const RYm = a => new THREE.Matrix4().makeRotationY(a), RXm = a => new THREE.Matrix4().makeRotationX(a), RZm = a => new THREE.Matrix4().makeRotationZ(a);
const SCm = (x, y, z) => new THREE.Matrix4().makeScale(x, y, z), Tm = (x, y, z) => new THREE.Matrix4().makeTranslation(x, y, z);

// ---------- state ----------
let cur = 0, look = 0, view = "three", slow = false, loop = true, closeup = false;
let t = 0, done = {}, sc = {};
const lerp = (a, b, u) => a + (b - a) * u, clamp01 = u => Math.max(0, Math.min(1, u));
const ease = u => 1 - Math.pow(1 - clamp01(u), 3), smooth = u => { u = clamp01(u); return u * u * (3 - 2 * u); };
const V = (x, y, z) => new THREE.Vector3(x, y, z);
function mix(A, B, u) { const o = {}; for (const k of new Set([...Object.keys(A), ...Object.keys(B)])) { const a = A[k] || [0, 0, 0], b = B[k] || [0, 0, 0]; o[k] = [lerp(a[0], b[0], u), lerp(a[1], b[1], u), lerp(a[2], b[2], u)]; } return o; }
const once = (k, c) => { if (c && !done[k]) { done[k] = true; return true; } return false; };
const P = () => PARTS[cur];
const IDLE = tt => ({Neck: [Math.sin(tt * 1.3) * 2, Math.sin(tt * 0.5) * 4, 0], Head: [Math.sin(tt * 1.3 + 1) * 3, 0, 0], Tail1: [0, Math.sin(tt * 0.8) * 3, 0], Tail2: [0, Math.sin(tt * 0.8 - 0.5) * 4, 0], Tail3: [0, Math.sin(tt * 0.8 - 1) * 5, 0], Tail4: [0, Math.sin(tt * 0.8 - 1.5) * 6, 0], Tail5: [0, Math.sin(tt * 0.8 - 2) * 7, 0]});
// therizino poses (arm angles in the rig's [p, y, r] convention; tuned by eye against the side view)
const ARMS_UP = {ArmL: [75, 30, 25], ArmR: [75, -30, -25], RootJoint: [6, 0, 0], Neck: [8, 0, 0]};
const ARMS_FWD = {ArmL: [62, 0, 8], ArmR: [62, 0, -8], RootJoint: [-6, 0, 0]};
const ARM_R_FWD = {ArmR: [70, 0, -6], ArmL: [10, 0, 0], RootJoint: [-6, 0, 0], Neck: [-4, 0, 0]};
const ARM_L_FWD = {ArmL: [70, 0, 6], ArmR: [10, 0, 0], RootJoint: [-6, 0, 0], Neck: [-4, 0, 0]};
const STAB = {ArmL: [-10, 0, 10], ArmR: [-10, 0, -10], RootJoint: [-22, 0, 0], Neck: [-14, 0, 0], Head: [-8, 0, 0], LegL: [22, 0, 0], LegR: [22, 0, 0], KneeL: [-30, 0, 0], KneeR: [-30, 0, 0], AnkleL: [10, 0, 0], AnkleR: [10, 0, 0], Tail1: [-14, 0, 0]};
const SWEEP = {ArmL: [55, -50, -30], ArmR: [55, 50, 30], RootJoint: [-4, 0, 0]};
const SWIPE_R = {ArmR: [85, 40, 20], ArmL: [20, 0, 0], RootJoint: [-10, -10, 0]};
const TAIL_FLICK = {Tail1: [-30, 0, 0], Tail2: [-30, 0, 0], Tail3: [-25, 0, 0], Tail4: [-20, 0, 0], Tail5: [-15, 0, 0], RootJoint: [-8, 0, 0]};
const TAIL_WHIP = {Tail1: [0, 40, 0], Tail2: [0, 30, 0], Tail3: [0, 25, 0], Tail4: [0, 20, 0], Tail5: [0, 15, 0], RootJoint: [0, -12, 0]};
function RUN(ph, k) { // ph = gait phase (rad), k = stride size
  const s = Math.sin(ph), c = Math.cos(ph);
  return {RootJoint: [-10, 0, s * 3], LegL: [s * 34 * k, 0, 0], LegR: [-s * 34 * k, 0, 0], KneeL: [-Math.max(0, c) * 50 * k - 8, 0, 0], KneeR: [-Math.max(0, -c) * 50 * k - 8, 0, 0],
    AnkleL: [Math.max(0, c) * 20 * k, 0, 0], AnkleR: [Math.max(0, -c) * 20 * k, 0, 0], ArmL: [20 - s * 12, 0, 0], ArmR: [20 + s * 12, 0, 0], Neck: [-6, 0, 0], Tail1: [8, s * 4, 0], Tail2: [0, s * 4, 0]};
}

// ---------- looks (block-style mecha pieces) ----------
function buildLook() {
  clearEquip();
  const id = P().id, L = look;
  const tt = () => t;
  if (id === "hook") {
    if (L === 0) {
      piece("ArmR_fore", [1.1, 0.9, 1.1], [-3.95, 0.25, -2.75], [0, 0, 90], STEEL, {cyl: true, extra: () => RYm(sc.reel ? t * 14 : 0)});
      piece("ArmR_fore", [0.5, 0.5, 1.2], [-3.95, 0.25, -2.75], [0, 0, 0], BRASS);
      piece("ArmR_hand", [0.6, 0.55, 1.3], [-4.45, 0.35, -3.6], [0, 0, 0], DARK);
      piece("ArmR_hand", [0.25, 0.25, 0.4], [-4.45, 0.35, -4.35], [0, 0, 0], RED, {glowable: true});
    } else if (L === 1) {
      piece("Torso_chest", [1.7, 1.2, 1.4], [0, 2.4, -3.5], [0, 0, 0], DARK);
      piece("Torso_chest", [0.55, 1.6, 0.55], [0, 2.5, -4.6], [90, 0, 0], STEEL, {cyl: true});
      piece("Torso_chest", [2.2, 0.3, 0.5], [0, 3.05, -3.1], [0, 0, 0], BRASS);
      piece("Torso_chest", [0.4, 0.4, 0.3], [0, 2.5, -5.4], [0, 0, 0], RED, {glowable: true, show: () => !sc.hookOut});
    } else {
      piece("Torso_body", [1.6, 0.8, 1.6], [0, 2.45, -0.6], [0, 0, 0], DARK);
      piece("Torso_body", [0.6, 4.4, 0.6], [0, 4.5, -1.4], [-28, 0, 0], STEEL, {extra: () => RXm(-(sc.crane || 0) * 0.35)});
      piece("Torso_body", [0.7, 0.7, 2.6], [0, 6.6, -3.2], [0, 0, 0], BRASS);
      piece("Torso_body", [0.9, 0.9, 0.9], [0, 2.95, -0.6], [0, 0, 90], STEEL, {cyl: true, extra: () => RYm(sc.reel ? t * 14 : 0)});
    }
  }
  if (id === "feather") {
    if (L === 0) {
      for (const [s, arm] of [[1, "ArmL_fore"], [-1, "ArmR_fore"]]) {
        piece(arm, [0.35, 1.7, 0.75], [s * 4.15, 0.2, -2.8], [0, 0, 0], DARK);
        for (let k = 0; k < 6; k++) piece(arm, [0.08, 0.18, 1.1], [s * (4.35 + 0.0), -0.45 + k * 0.26, -2.8], [0, 0, 0], FEATHER, {show: () => !sc.fired, glowable: true});
      }
    } else if (L === 1) {
      piece("Torso_body", [2.0, 0.8, 1.3], [0, 2.4, 0.2], [0, 0, 0], DARK);
      for (let k = 0; k < 12; k++) { const a = -66 + k * 12; piece("Torso_body", [0.14, 3.6, 0.5], [Math.sin(rad(a)) * 1.9, 2.6 + Math.cos(rad(a)) * 1.9, 0.6], [0, 0, -a], FEATHER, {show: () => !sc.fired, glowable: true, extra: () => RXm(-(sc.fan || 0) * 0.6)}); }
      piece("Torso_body", [0.9, 0.9, 0.9], [0, 2.7, 0.6], [90, 0, 0], BRASS, {cyl: true});
    } else {
      for (const tail of ["Tail2_main", "Tail3_main"]) {
        const z = theri.byName[tail].cf.elements[14], y = theri.byName[tail].cf.elements[13];
        for (const s of [1, -1]) {
          piece(tail, [0.6, 0.7, 1.4], [s * 0.85, y + 0.1, z], [0, 0, 0], DARK);
          piece(tail, [0.12, 0.5, 1.0], [s * 0.85, y + 0.6, z], [0, 0, 0], FEATHER, {show: () => !sc.fired, glowable: true});
        }
      }
    }
  }
  if (id === "harvest") {
    for (const side of ["L", "R"]) {
      const s = side === "L" ? 1 : -1;
      if (L === 0) {
        for (let c = 1; c <= 3; c++) piece(`Arm${side}_claw${c}d`, [0.28, 0.9, 0.28], [0, 0, 0], [0, 0, 0], STEEL, {cyl: true, cone: true, glowable: true,
          extra: () => Tm(0, -0.55, 0).multiply(RXm(Math.PI))});
        piece(`Arm${side}_hand`, [0.9, 0.35, 0.9], [s * 4.39, 0.25, -3.39], [0, 0, 0], DARK);
      } else if (L === 1) {
        piece(`Arm${side}_fore`, [0.7, 1.5, 0.7], [s * 4.25, 0.2, -2.7], [0, 0, 0], DARK);
        piece(`Arm${side}_fore`, [0.4, 2.2, 0.4], [s * 4.25, -0.9, -2.7], [0, 0, 0], STEEL, {cyl: true, glowable: true, extra: () => Tm(0, -(sc.ram || 0) * 2.2, 0)});
        piece(`Arm${side}_fore`, [0.9, 0.3, 0.9], [s * 4.25, -2.1, -2.7], [0, 0, 0], BRASS, {extra: () => Tm(0, -(sc.ram || 0) * 2.2, 0)});
      } else {
        piece(`Arm${side}_hand`, [0.9, 0.5, 0.9], [s * 4.39, -0.4, -3.39], [0, 0, 0], DARK);
        piece(`Arm${side}_hand`, [0.7, 1.6, 0.7], [s * 4.39, -1.4, -3.39], [180, 0, 0], STEEL, {cyl: true, cone: true, glowable: true, extra: () => RYm((sc.drill || 0) * t * 30)});
      }
    }
  }
  if (id === "grapple") {
    if (L === 0) {
      piece("ArmL_hand", [0.7, 0.6, 1.4], [4.4, 0.45, -3.5], [0, 0, 0], DARK);
      piece("ArmL_hand", [0.3, 1.0, 0.3], [4.4, 0.45, -4.4], [90, 0, 0], STEEL, {cyl: true});
      piece("ArmL_hand", [0.35, 0.35, 0.35], [4.4, 0.45, -5.0], [0, 0, 0], BRASS, {show: () => !sc.lineOut});
    } else if (L === 1) {
      piece("ArmL_shoulder", [1.4, 0.7, 1.4], [1.7, 2.35, -2.6], [0, 0, 0], STEEL, {cyl: true, extra: () => RYm(sc.reel ? t * 16 : 0)});
      piece("ArmL_shoulder", [0.5, 0.5, 1.4], [1.7, 2.35, -3.6], [0, 0, 0], DARK);
      piece("ArmL_shoulder", [0.35, 0.35, 0.35], [1.7, 2.35, -4.4], [0, 0, 0], BRASS, {show: () => !sc.lineOut});
    } else {
      piece("Torso_body", [1.9, 1.0, 1.8], [0, -0.75, -1.2], [0, 0, 0], DARK);
      piece("Torso_body", [1.2, 1.4, 1.2], [0, -0.75, -1.2], [0, 0, 90], STEEL, {cyl: true, extra: () => RYm(sc.reel ? t * 16 : 0)});
      piece("Torso_chest", [0.5, 0.5, 1.2], [0, 1.4, -3.5], [0, 0, 0], BRASS);
    }
  }
  if (id === "deflect") {
    if (L === 0) {
      for (const [s, side] of [[1, "L"], [-1, "R"]]) { piece(`Arm${side}_hand`, [0.9, 0.5, 0.9], [s * 4.39, 0.05, -3.39], [90, 0, 0], STEEL, {cyl: true}); piece(`Arm${side}_hand`, [0.4, 0.4, 0.4], [s * 4.39, 0.05, -3.9], [0, 0, 0], BRASS); }
    } else if (L === 1) {
      piece("Torso_chest", [1.9, 1.6, 0.8], [0, 2.2, -3.4], [0, 0, 0], DARK);
      piece("Torso_chest", [1.0, 0.5, 1.0], [0, 2.2, -3.9], [90, 0, 0], BRASS, {cyl: true});
      for (let k = 0; k < 4; k++) piece("Torso_chest", [0.18, 1.4, 0.18], [0, 2.2, -3.9], [0, 0, k * 90 + 45], 0xe2dccb, {show: () => !sc.spinOn, extra: () => Tm(0, 0.7, 0)});
    } else {
      piece("Torso_body", [5.2, 0.35, 0.35], [0, 1.4, -3.1], [0, 0, 0], DARK);
      piece("Torso_body", [0.35, 0.35, 2.2], [2.6, 1.4, -2.1], [0, 0, 0], DARK);
      piece("Torso_body", [0.35, 0.35, 2.2], [-2.6, 1.4, -2.1], [0, 0, 0], DARK);
      for (let k = 0; k < 6; k++) piece("Torso_body", [0.2, 1.6, 0.2], [-2.5 + k, 2.2, -3.1], [0, 0, 0], 0xe2dccb, {show: () => !sc.spinOn});
    }
  }
  if (id === "overclock") {
    if (L === 0) {
      for (const [s, side] of [[1, "L"], [-1, "R"]]) {
        piece(`Leg${side}_thigh`, [0.55, 2.0, 0.55], [s * 1.45, -1.2, -0.3], [0, 0, 0], STEEL, {glowable: true, extra: () => Tm(0, Math.sin(t * 30) * (sc.on || 0) * 0.25, 0)});
        piece(`Leg${side}_haunch`, [0.9, 0.7, 0.9], [s * 1.5, -0.2, -0.2], [0, 0, 0], DARK);
        piece(`Shin${side}_knee`, [0.9, 0.7, 0.9], [s * 0.85, -2.62, -1.3], [0, 0, 0], BRASS, {glowable: true});
        piece(`Shin${side}_shin`, [0.4, 1.6, 0.4], [s * 0.85, -3.6, -0.8], [0, 0, 0], STEEL, {cyl: true, glowable: true});
      }
    } else if (L === 1) {
      piece("Torso_body", [1.8, 2.4, 1.8], [0, 3.0, 0.1], [0, 0, 0], BRASS, {cyl: true, glowable: true});
      piece("Torso_body", [2.0, 0.3, 2.0], [0, 2.0, 0.1], [0, 0, 0], DARK, {cyl: true});
      for (const s of [1, -1]) piece("Torso_body", [0.5, 1.8, 0.5], [s * 0.55, 4.9, 0.5], [0, 0, 0], DARK, {cyl: true});
      for (const j of ["ShinL_knee", "ShinR_knee"]) piece(j, [0.8, 0.8, 0.8], [j === "ShinL_knee" ? 0.85 : -0.85, -2.62, -0.85], [0, 0, 0], DARK, {glowable: true});
    } else {
      const R = [["ArmL_shoulder", [1.54, 1.62, -2.62], [0, 0, 90]], ["ArmR_shoulder", [-1.54, 1.62, -2.62], [0, 0, 90]], ["LegL_haunch", [0.85, -0.54, -0.15], [0, 0, 90]], ["LegR_haunch", [-0.85, -0.54, -0.15], [0, 0, 90]],
        ["ShinL_knee", [0.85, -2.62, -0.85], [0, 0, 90]], ["ShinR_knee", [-0.85, -2.62, -0.85], [0, 0, 90]], ["ArmL_elbow", [3.39, 0.31, -2.23], [0, 0, 90]], ["ArmR_elbow", [-3.39, 0.31, -2.23], [0, 0, 90]]];
      for (const [pn, pos, r] of R) piece(pn, [pn.includes("elbow") ? 0.38 : 0.62, 0.11], pos, [90, 0, 0], STEEL, {torus: true, glowable: true});
    }
  }
  if (id === "snare") {
    if (L === 0) {
      for (let k = 0; k < 3; k++) { const tail = ["Tail2_main", "Tail3_main", "Tail4_main"][k]; const z = theri.byName[tail].cf.elements[14], y = theri.byName[tail].cf.elements[13];
        piece(tail, [0.9, 0.6, 0.9], [0, y + 0.55, z], [0, 0, 90], STEEL, {cyl: true, show: () => !(sc.thrown > k)}); piece(tail, [0.5, 0.65, 0.5], [0, y + 0.55, z], [0, 0, 90], RED, {cyl: true, glowable: true, show: () => !(sc.thrown > k)}); }
    } else if (L === 1) {
      for (const [s, side] of [[1, "L"], [-1, "R"]]) { piece(`Arm${side}_fore`, [1.0, 0.5, 1.0], [s * 4.3, 0.3, -2.8], [0, 0, 90], STEEL, {cyl: true, extra: () => RYm(sc.reel ? t * 14 : 0)}); piece(`Arm${side}_fore`, [0.3, 0.55, 0.3], [s * 4.3, 0.3, -2.8], [0, 0, 90], RED, {cyl: true, glowable: true}); }
    } else {
      piece("Torso_body", [2.0, 1.1, 2.0], [0, -0.7, -0.9], [0, 0, 0], DARK);
      piece("Torso_body", [1.6, 0.2, 0.3], [0, -1.3, -1.9], [0, 0, 0], RED, {glowable: true});
    }
  }
}

// ---------- scenario helpers ----------
function foe(i, x, z, yaw, extra) { const d = foes[i]; Object.assign(d, {x, z, y: 0, yaw: yaw === undefined ? Math.PI : yaw, roll: 0, vx: 0, vz: 0, stun: 0, root: 0, slowT: 0, slowPct: 0, bleed: 0, hit: 0, ph: Math.random() * 6, active: true, label: ""}, extra || {}); d.g.visible = true; return d; }
function hitFoe(d, txt, cls) { popNum(V(d.x, d.y, d.z), txt, cls); d.hit = 0.25; }
const FWD = V(0, 0, -1);
function yawTo(dx, dz) { return Math.atan2(-dx, -dz); }
function srcPoint() { // where the part fires from (per look)
  const id = P().id, L = look;
  if (id === "hook") return L === 0 ? restOn(theri, "ArmR_hand", [-4.45, 0.35, -4.4]) : L === 1 ? restOn(theri, "Torso_chest", [0, 2.5, -5.4]) : restOn(theri, "Torso_body", [0, 6.6, -4.4]);
  if (id === "grapple") return L === 0 ? restOn(theri, "ArmL_hand", [4.4, 0.45, -5.0]) : L === 1 ? restOn(theri, "ArmL_shoulder", [1.7, 2.35, -4.4]) : restOn(theri, "Torso_chest", [0, 1.4, -4.1]);
  return partPos(theri, "Torso_chest");
}

// ---------- scenarios (all show the maxed ★ effect) ----------
function scenario(dt) {
  const id = P().id, L = look;
  let A = IDLE(t), txt = "";
  if (id === "hook") {
    const f = foes[0];
    const aimPose = L === 0 ? ARM_R_FWD : L === 1 ? {RootJoint: [-6, 0, 0], Neck: [10, 0, 0], ArmL: [20, 0, 0], ArmR: [20, 0, 0]} : {RootJoint: [-4, 0, 0], Neck: [-10, 0, 0]};
    sc.crane = L === 2 ? smooth((t - 0.1) / 0.4) * (t < 3.4 ? 1 : 1 - smooth((t - 3.4) / 0.5)) : 0;
    A = Object.assign(IDLE(t), mix({}, aimPose, smooth((t - 0.1) / 0.35) * (t < 2.0 ? 1 : 1 - smooth((t - 2.0) / 0.3))));
    const s = srcPoint(), target = V(f.x, 5, f.z);
    if (t < 0.5) txt = "Reaper's Hook ★ · aim at a dino 80 studs away";
    else if (t < 1.0) { const u = (t - 0.5) / 0.5; sc.hookOut = true; const h = s.clone().lerp(target, u); chain(s, h); sc.head.position.copy(h); sc.head.visible = true; sc.head.lookAt(target); txt = "the claw chain flies 80 studs"; }
    else if (t < 1.8) { const u = ease((t - 1.0) / 0.8); f.z = lerp(-80, -9, u); sc.reel = true; if (once("bite", true)) { flash(target, 2, 0xffffff); hitFoe(f, "HOOKED", "soft"); } const h = V(f.x, 5, f.z); chain(s, h); sc.head.position.copy(h); txt = "…and yanks it in"; }
    else { sc.reel = false; sc.head.visible = false;
      if (once("stun", true)) { f.stun = 1.0; hitFoe(f, "STUNNED 1 s", "big"); shake = 0.3; dust(V(f.x, 0, f.z), 6, 4, 2, 0.8); }
      if (t > 2.1) { A = Object.assign(A, mix({}, SWIPE_R, smooth((t - 2.1) / 0.18) * (1 - smooth((t - 2.45) / 0.3)))); }
      if (once("cut1", t > 2.25)) { slashMark(V(f.x, 6, f.z)); popNum(V(f.x, f.y, f.z + 1), "CUT 1", "red"); f.hit = 0.25; sc.cut = true; }
      txt = t < 2.2 ? "stunned 1 s" : "cut 1 starts on it"; }
    if (sc.cut) setTag("cut", f, "CUT 1 ●○○○", "red", 13); if (f.stun > 0) setTag("st", f, "STUNNED " + f.stun.toFixed(1) + " s", "yellow", 15.5); else setTag("st", f, "");
  }
  if (id === "feather") {
    const pre = L === 0 ? {ArmL: [40, 60, 40], ArmR: [40, -60, -40], RootJoint: [4, 0, 0]} : L === 1 ? {RootJoint: [10, 0, 0], Neck: [8, 0, 0]} : {Tail1: [0, -35, 0], Tail2: [0, -25, 0], Tail3: [0, -20, 0], RootJoint: [0, 14, 0]};
    const rel = L === 0 ? SWEEP : L === 1 ? {RootJoint: [-14, 0, 0], Neck: [-10, 0, 0]} : TAIL_WHIP;
    sc.fan = L === 1 ? smooth((t - 0.6) / 0.15) * (1 - smooth((t - 1.2) / 0.4)) : 0;
    A = Object.assign(IDLE(t), t < 0.7 ? mix({}, pre, smooth((t - 0.15) / 0.4)) : mix(pre, rel, smooth((t - 0.7) / 0.15)));
    if (t > 1.3) A = Object.assign(A, mix(rel, {}, smooth((t - 1.3) / 0.5)));
    if (once("fan", t > 0.4)) { const m = wmesh(new THREE.CircleGeometry(30, 40, rad(90 - 35), rad(70)), 0xffffff, {basic: true, alpha: 0.16, side: THREE.DoubleSide}); m.rotation.x = -Math.PI / 2; m.position.y = 0.15; sc.fanMesh = m; }
    if (sc.fanMesh) sc.fanMesh.material.opacity = 0.16 * (t < 2.4 ? 1 : 1 - clamp01((t - 2.4) / 0.6));
    if (once("fire", t > 0.75)) {
      sc.fired = true; sc.blades = [];
      for (let k = 0; k < 12; k++) {
        const a = rad(-35 + k * (70 / 11)), dir = V(Math.sin(a), 0, -Math.cos(a));
        let o;
        if (L === 0) o = partPos(theri, k % 2 ? "ArmL_fore" : "ArmR_fore"); else if (L === 1) o = restOn(theri, "Torso_body", [0, 4.4, 0.6]); else o = partPos(theri, "Torso_chest").add(V(0, 2, 0));
        const m = wmesh(new THREE.BoxGeometry(0.16, 0.5, 2.0), FEATHER, {glow: 0.35});
        m.position.copy(o); sc.blades.push({m, dir, y0: o.y, d: 0, live: true, delay: k * 0.015});
      }
    }
    if (sc.blades) for (const b of sc.blades) { if (!b.live) continue; if (t - 0.75 < b.delay) continue;
      b.d += 48 * dt; const p = V(b.dir.x * b.d, lerp(b.y0, 4.5, clamp01(b.d / 8)), b.dir.z * b.d - 2); b.m.position.copy(p); b.m.lookAt(p.clone().add(b.dir)); b.m.rotateZ(b.d * 0.4);
      if (b.d > 30) { b.live = false; b.m.visible = false; dust(p.setY(0), 1, 1, 1, 0.3); continue; }
      for (const f of foes) if (f.active && Math.hypot(f.x - p.x, f.z - p.z) < 2.6) { b.live = false; b.m.visible = false; hitFoe(f, "-3"); f.slowT = 2; f.slowPct = 25; sparks(V(p.x, 5, p.z), 3, FEATHER); break; } }
    for (const [i, f] of foes.entries()) if (f.active) setTag("sl" + i, f, f.slowT > 0 ? "SLOWED 25% · " + f.slowT.toFixed(1) + " s" : "", "blue", 11);
    txt = t < 0.75 ? "Feather Barrage ★ · wind up" : t < 1.6 ? "12 feather blades in a 30-stud fan · 3 damage each" : "hit dinos are slowed 25% for 2 s";
  }
  if (id === "harvest") {
    const R = 10, c0 = V(0, 0, -3);
    sc.ram = L === 1 ? smooth((t - 0.75) / 0.12) * (t < 5.9 ? 1 : 1 - smooth((t - 5.9) / 0.4)) : 0;
    sc.drill = L === 2 && t > 0.6 && t < 5.9 ? 1 : 0;
    const on = t > 0.85 && t < 5.85;
    if (t < 0.85) A = Object.assign(IDLE(t), mix({}, ARMS_UP, smooth((t - 0.1) / 0.45)), t > 0.6 ? mix(ARMS_UP, STAB, smooth((t - 0.6) / 0.2)) : {});
    else if (t < 5.85) A = Object.assign(IDLE(t), STAB);
    else A = Object.assign(IDLE(t), mix(STAB, {}, smooth((t - 5.85) / 0.5)));
    if (once("stab", t > 0.85)) {
      shake = 0.5; dust(c0, 14, 10, 3, 1.1); ring(c0, R, 0.6, 0xff4a4a);
      const disc = wmesh(new THREE.CircleGeometry(R, 56), BLOOD, {basic: true, alpha: 0.28, side: THREE.DoubleSide}); disc.rotation.x = -Math.PI / 2; disc.position.set(c0.x, 0.14, c0.z);
      const edge = wmesh(new THREE.RingGeometry(R - 0.5, R, 64), 0xff4a4a, {basic: true, alpha: 0.85, side: THREE.DoubleSide}); edge.rotation.x = -Math.PI / 2; edge.position.set(c0.x, 0.16, c0.z);
      for (let k = 0; k < 18; k++) { const a = Math.random() * Math.PI * 2, r = 2 + Math.random() * (R - 3); const m = wmesh(new THREE.BoxGeometry(0.2, 0.05, 2.4), 0x5a0e14, {basic: true}); m.position.set(c0.x + Math.cos(a) * r, 0.17, c0.z + Math.sin(a) * r); m.rotation.y = Math.random() * 3; }
      sc.disc = disc; sc.edge = edge;
    }
    if (sc.disc) { const k = on ? 1 : clamp01(1 - (t - 5.85) / 0.4); sc.disc.material.opacity = 0.28 * k * (0.85 + 0.15 * Math.sin(t * 6)); sc.edge.material.opacity = 0.85 * k; }
    glowEquip(on ? 0.6 + 0.3 * Math.sin(t * 8) : 0, 0xff2a2a);
    for (const [i, f] of foes.entries()) { if (!f.active) continue;
      const inside = on && Math.hypot(f.x - c0.x, f.z - c0.z) < R;
      f.slowPct = inside ? 30 : 0; f.slowT = inside ? 0.1 : 0;
      if (inside) { f.bleedT = (f.bleedT || 0) + dt; if (f.bleedT >= 1) { f.bleedT -= 1; hitFoe(f, "-4", "red"); for (let k = 0; k < 4; k++) drip(V(f.x, 4, f.z)); } } else f.bleedT = 0.6;
      setTag("bl" + i, f, inside ? "BLEED 4/s · SLOWED 30%" : "", "red", 11); }
    txt = t < 0.85 ? "Harvest Field ★ · claws up…" : on ? `20-stud circle · ${(5.85 - t).toFixed(1)} s left · bleed 4/s, slowed 30%` : "the field fades";
  }
  if (id === "grapple") {
    const legs = [[V(16, 9, -58), V(12.5, 0, -54.5)], [V(-26, 9, -102), V(-22, 0, -98)]]; // [hook point, landing point]
    const st = [0, 0.4, 0.75, 1.55], gap = 2.0;
    let leg = t < st[0] + gap ? 0 : 1; const lt = t - leg * gap;
    const from = leg === 0 ? V(0, 0, 0) : legs[0][1], [hp, land] = legs[leg];
    const reach = ARM_L_FWD;
    sc.lineOut = false; sc.reel = false; lineM.visible = false;
    if (lt < st[1]) { theri.yaw = lerp(leg === 0 ? 0 : sc.yaw0, yawTo(hp.x - from.x, hp.z - from.z), smooth(lt / st[1])); A = Object.assign(IDLE(t), mix({}, L === 0 ? reach : {RootJoint: [-6, 0, 0]}, smooth(lt / st[1]))); txt = leg === 0 ? "Grapple Zip ★ · aim at a tree (60 studs)" : "charge 2 · aim at a wall"; }
    else if (lt < st[2]) { const u = (lt - st[1]) / (st[2] - st[1]); const s = srcPoint(); sc.lineOut = true; const h = s.clone().lerp(hp, u); beam(lineM, s, h, 0.09); sc.head.visible = true; sc.head.position.copy(h); A = Object.assign(IDLE(t), L === 0 ? reach : {RootJoint: [-6, 0, 0]}); txt = "the hook flies…"; if (once("pip" + leg, true)) sc.charges = 1 - leg; }
    else if (lt < st[3]) { const u = smooth((lt - st[2]) / (st[3] - st[2])); sc.lineOut = true; sc.reel = true; theri.x = lerp(from.x, land.x, u); theri.z = lerp(from.z, land.z, u); theri.y = Math.sin(u * Math.PI) * (L === 2 ? 1.5 : 4);
      const s = srcPoint(); beam(lineM, s, hp, 0.09); sc.head.position.copy(hp); A = Object.assign({}, L === 0 ? reach : ARMS_FWD, {LegL: [-30, 0, 0], LegR: [-20, 0, 0], KneeL: [-50, 0, 0], KneeR: [-60, 0, 0], RootJoint: [L === 2 ? -18 : -8, 0, 0], Tail1: [10, 0, 0]});
      if (Math.random() < 0.6) streak(partPos(theri, "Torso_body").add(V((Math.random() - 0.5) * 6, (Math.random() - 0.5) * 6, 0)).add(V(-(land.x - from.x), 0, -(land.z - from.z)).normalize().multiplyScalar(3)), 4);
      txt = "…and zips there"; if (once("hit" + leg, true)) { flash(hp, 1.5, 0xffffff); sparks(hp, 6); } }
    else { theri.y = 0; sc.head.visible = false; if (once("land" + leg, true)) { dust(V(land.x, 0, land.z), 8, 5, 2, 0.9); sc.yaw0 = theri.yaw; } A = Object.assign(IDLE(t), mix(ARMS_FWD, {}, smooth((lt - st[3]) / 0.3))); txt = leg === 0 ? "1 charge left" : "both charges used · recharging"; }
    $("hits").innerHTML = [0, 1].map(k => `<i class="${k < sc.charges ? "on" : ""}"></i>`).join("");
  }
  if (id === "deflect") {
    const shooter = foes[0], on = t > 0.4 && t < 2.4;
    sc.spinOn = on;
    const guard = L === 1 ? {RootJoint: [-4, 0, 0], ArmL: [30, 0, 30], ArmR: [30, 0, -30]} : L === 2 ? {RootJoint: [-4, 0, 0], ArmL: [40, 0, 20], ArmR: [40, 0, -20]} : ARMS_FWD;
    A = Object.assign(IDLE(t), mix({}, guard, smooth((t - 0.1) / 0.3) * (1 - smooth((t - 2.4) / 0.4))));
    const spin = on ? t * 22 : 0, k = on ? 1 : 0;
    const centers = L === 0 ? [restOn(theri, "ArmL_hand", [4.39, 0.05, -4.6]), restOn(theri, "ArmR_hand", [-4.39, 0.05, -4.6])] : [V(theri.x, 7.5, -5.2)];
    for (const [j, g] of sc.rotors.entries()) { g.visible = on && j < centers.length; if (g.visible) { g.position.copy(centers[j]); g.rotation.set(0, 0, spin * (j ? -1 : 1)); g.scale.setScalar(L === 1 ? 1.6 : L === 2 ? 1.0 : 1); } }
    if (L === 2) { sc.rotors[0].visible = false; sc.orbit.visible = on; sc.orbit.position.set(0, 6.5, 0); sc.orbit.rotation.y = 0; sc.orbit.children.forEach((b, i) => { const a = -Math.PI / 2 + Math.sin(t * 9 + i) * 0.0 + ((t * 9 + i * 1.05) % (Math.PI)) - Math.PI / 2; b.position.set(Math.sin(a) * 7, 0, -Math.cos(a) * 7); b.rotation.y = -a; }); }
    else sc.orbit.visible = false;
    const KINDS = [["DART", 0.7, 70], ["ROCKET", 1.15, 50], ["BOULDER", 1.6, 38], ["CANNON SHOT", 2.0, 60]];
    for (const [i, [name, t0, sp]] of KINDS.entries()) {
      const pr = sc.shots[i], mz = V(shooter.x, 5.5, shooter.z + 2), wall = V(0, 6.5, L === 2 ? -6.5 : -6);
      if (t < t0) { pr.visible = false; continue; }
      if (once("muz" + i, true)) { flash(mz, 1.2, 0xffd36a); }
      const L1 = mz.distanceTo(wall), t1 = t0 + L1 / sp;
      if (t < t1) { const u = (t - t0) / (t1 - t0); pr.visible = true; pr.position.copy(mz).lerp(wall, u); if (name === "BOULDER") pr.position.y += Math.sin(u * Math.PI) * 6; pr.lookAt(wall); if (name === "ROCKET" && Math.random() < 0.7) dust(pr.position.clone().setY(pr.position.y - 0.5), 1, 0.5, 0.5, 0.4, 0x8a8a8a, 0.4); }
      else { if (once("bounce" + i, true)) { flash(wall, 2.2, 0x9fe8ff); sparks(wall, 10); popNum(wall, "BOUNCED!", "soft"); }
        const t2 = t1 + L1 / (sp * 1.1);
        if (t < t2) { const u = (t - t1) / (t2 - t1); pr.visible = true; pr.position.copy(wall).lerp(mz, u); if (name === "BOULDER") pr.position.y += Math.sin(u * Math.PI) * 5; pr.lookAt(mz); }
        else { pr.visible = false; if (once("back" + i, true)) { hitFoe(shooter, name + " back", "red"); flash(mz, 1.6, 0xffa040); shake = 0.15; } } }
    }
    txt = t < 0.4 ? "Deflector Claws ★ · a Herrera opens fire" : on ? `claws spin in front · ${(2.4 - t).toFixed(1)} s · darts, rockets, boulders, cannon shots bounce back` : "every shot went back at the shooter";
  }
  if (id === "overclock") {
    const on = t > 0.3 && t < 5.3, base = 14;
    sc.on = on ? 1 : 0;
    const mud = [-46, -64]; // a slow patch across both lanes
    const inMud = z => z < mud[0] && z > mud[1];
    const speedT = on ? base * 1.4 : base;
    theri.z -= speedT * dt; sc.ph = (sc.ph || 0) + dt * speedT * 0.42;
    ghost.z -= base * (inMud(ghost.z) ? 0.5 : 1) * dt; sc.gph = (sc.gph || 0) + dt * base * (inMud(ghost.z) ? 0.5 : 1) * 0.42;
    A = RUN(sc.ph, 1);
    if (on) { const tap = (t * 3.0 * 1.3) % 1; const side = Math.floor(t * 3.0 * 1.3) % 2; if (tap < 0.35) Object.assign(A, side ? {ArmR: [80, 30, 10]} : {ArmL: [80, -30, -10]}); }
    pose(ghost, RUN(sc.gph, 1));
    glowEquip(on ? 0.7 + 0.3 * Math.sin(t * 20) : 0);
    for (const p of theri.parts) p.mesh.material.emissive.setHex(GLOW).multiplyScalar(on && /elbow|knee|shoulder|haunch/.test(p.name) ? 0.6 : 0);
    if (on && Math.random() < 0.8) { const b = partPos(theri, "Torso_body"); streak(V(b.x + (Math.random() - 0.5) * 7, 1 + Math.random() * 9, b.z + 6 + Math.random() * 4), 5 + Math.random() * 4); }
    if (on && (sc.stm = (sc.stm || 0) + dt) > 0.12) { sc.stm = 0;
      if (L === 1) for (const s of [1, -1]) steam(restOn(theri, "Torso_body", [s * 0.55, 5.9, 0.5]), 1, V(0, 1, 1).normalize());
      else steam(partPos(theri, Math.random() < 0.5 ? "ShinL_knee" : "ShinR_knee"), 1, V(0, 0.6, 1).normalize()); }
    if (once("cut", t > 1.2)) popNum(V(theri.x, theri.y + 4, theri.z), "CUT TAPS 30% FASTER", "soft");
    if (inMud(theri.z) && on) setTag("mud", theri, "SLOWS DON'T WORK", "green", 16); else setTag("mud", theri, "");
    setTag("gh", ghost, inMud(ghost.z) ? "normal · SLOWED" : "normal speed", "blue", 15);
    txt = on ? `Overclock Joints ★ · ${(5.3 - t).toFixed(1)} s · run 40% faster` : t < 0.3 ? "Overclock Joints ★" : "back to normal speed";
  }
  if (id === "snare") {
    const spots = [V(-11, 0, -20), V(0, 0, -22), V(11, 0, -20)];
    const castPose = L === 0 ? TAIL_FLICK : L === 1 ? SWEEP : {RootJoint: [8, 0, 0], LegL: [-10, 0, 0], LegR: [-10, 0, 0]};
    A = Object.assign(IDLE(t), mix({}, castPose, smooth((t - 0.2) / 0.25) * (1 - smooth((t - 1.2) / 0.4))));
    sc.reel = L === 1 && t > 0.4 && t < 1.3;
    for (const [k, tr] of sc.traps.entries()) {
      const t0 = 0.45 + k * 0.18, t1 = t0 + 0.55;
      if (t < t0) { tr.g.visible = false; continue; }
      if (once("throw" + k, true)) { sc.thrown = k + 1; tr.from = L === 0 ? partPos(theri, "Tail4_main") : L === 1 ? partPos(theri, k % 2 ? "ArmR_fore" : "ArmL_fore") : partPos(theri, "Torso_body").setY(1); }
      tr.g.visible = true;
      if (t < t1) { const u = (t - t0) / (t1 - t0); tr.g.position.copy(tr.from).lerp(spots[k], u); tr.g.position.y += Math.sin(u * Math.PI) * (L === 2 ? 1.5 : 9) * (1 - u * 0.3); tr.g.rotation.y = u * 8; tr.wire.visible = false; }
      else { if (once("land" + k, true)) { dust(spots[k], 4, 3, 1.5, 0.5); } tr.g.position.copy(spots[k]); tr.g.rotation.y = 0; tr.wire.visible = !tr.sprung; tr.light.material.color.setHex(tr.sprung ? 0x444444 : (Math.sin(t * 8 + k) > 0 ? 0xff3030 : 0x661010)); }
    }
    for (const [i, f] of foes.entries()) { if (!f.active) continue;
      if (t > f.go && f.root <= 0 && !f.caught) { f.vz = f.spd; }
      if (!f.caught) for (const [k, tr] of sc.traps.entries()) if (!tr.sprung && t > 0.45 + k * 0.18 + 0.55 && Math.abs(f.x - spots[k].x) < 3.6 && Math.abs(f.z - spots[k].z) < 1.2) {
        tr.sprung = true; f.caught = true; f.root = 2; f.vz = 0; hitFoe(f, "-12", "big"); flash(V(f.x, 2, f.z), 2, WIRE); sparks(V(f.x, 1.5, f.z), 8, WIRE); shake = 0.2; }
      setTag("rt" + i, f, f.root > 0 ? "ROOTED " + f.root.toFixed(1) + " s" : "", "yellow", 11);
      if (f.caught && f.root <= 0) f.vz = f.spd; }
    txt = t < 1.2 ? "Snare Wires ★ · lay 3 wire traps" : "the first dino to cross one is rooted 2 s and takes 12";
  }
  return [A, txt];
}

// ---------- foes per frame ----------
function updateFoes(dt) {
  foes.forEach((d, i) => {
    if (!d.active) { stars[i].forEach(s => s.visible = false); wraps[i].forEach(w => w.visible = false); return; }
    d.stun = Math.max(0, d.stun - dt); d.root = Math.max(0, d.root - dt); d.slowT = Math.max(0, d.slowT - dt);
    const held = d.stun > 0 || d.root > 0;
    const mul = held ? 0 : d.slowT > 0 ? 1 - d.slowPct / 100 : 1;
    d.x += d.vx * mul * dt; d.z += d.vz * mul * dt;
    const moving = !held && (Math.abs(d.vx) + Math.abs(d.vz)) * mul > 0.1;
    if (moving) d.ph += dt * 9 * mul;
    const a = Object.assign({}, HPOSE);
    if (moving) { const s = Math.sin(d.ph); a.LegL = [48 + s * 24, 0, -16]; a.LegR = [48 - s * 24, 0, 16]; }
    if (d.stun > 0) a.Head = [16 + Math.sin(t * 20) * 10, 0, 0];
    if (d.root > 0) { a.Head = [10 + Math.sin(t * 16) * 8, Math.sin(t * 9) * 14, 0]; a.Tail3 = [0, Math.sin(t * 12) * 20, 0]; }
    pose(d, a);
    stars[i].forEach((s, k) => { s.visible = d.stun > 0; if (s.visible) { const an = t * 5 + k * 2.1; s.position.set(d.x + Math.cos(an) * 2.2, d.y + 8.5, d.z + Math.sin(an) * 2.2); s.rotation.y += dt * 6; } });
    wraps[i].forEach((w, k) => { w.visible = d.root > 0; if (w.visible) { w.position.set(d.x, 0.6 + k * 1.1, d.z); w.rotation.z = Math.sin(t * 10 + k) * 0.2; } });
    for (const p of d.parts) p.mesh.material.emissive.setHex(d.hit > 0 ? 0xffffff : d.slowT > 0 ? 0x2a6aff : 0x000000).multiplyScalar(d.hit > 0 ? 0.6 : d.slowT > 0 ? 0.25 : 0); d.hit = Math.max(0, d.hit - dt);
  });
}

// ---------- reset ----------
function rotor(nb, len) { // a disc of mecha claw blades + hub, spins about its z axis
  const g = new THREE.Group(); scene.add(g); world.push(g);
  const hub = new THREE.Mesh(new THREE.CylinderGeometry(0.6, 0.6, 0.5, 12), new THREE.MeshLambertMaterial({color: BRASS})); hub.rotation.x = Math.PI / 2; g.add(hub);
  for (let k = 0; k < nb; k++) { const b = new THREE.Mesh(new THREE.BoxGeometry(0.35, len, 0.2), new THREE.MeshLambertMaterial({color: 0xe2dccb})); b.position.set(Math.sin(k / nb * Math.PI * 2) * len / 2, Math.cos(k / nb * Math.PI * 2) * len / 2, 0); b.rotation.z = -k / nb * Math.PI * 2; g.add(b); }
  const blur = new THREE.Mesh(new THREE.CircleGeometry(len, 32), new THREE.MeshBasicMaterial({color: VOLT, transparent: true, opacity: 0.18, side: THREE.DoubleSide, depthWrite: false})); g.add(blur);
  g.visible = false; return g;
}
function resetScene() {
  clearFx(); clearTags(); clearWorld(); hideLinks(); lineM.visible = false; done = {}; sc = {}; t = 0; shake = 0;
  theri.x = theri.z = theri.y = 0; theri.yaw = 0; theri.roll = 0;
  for (const p of theri.parts) p.mesh.material.emissive.setHex(0);
  for (const d of foes) { d.active = false; d.g.visible = false; d.caught = false; }
  ghost.g.visible = false; $("hits").innerHTML = "";
  const id = P().id;
  sc.head = wmesh(new THREE.ConeGeometry(0.7, 1.8, 4), STEEL); sc.head.geometry.rotateX(Math.PI / 2); sc.head.geometry.rotateY(Math.PI); sc.head.visible = false;
  if (id === "hook") { foe(0, 0, -80); const m = wmesh(new THREE.RingGeometry(79.6, 80.4, 96, 1, rad(70), rad(40)), 0xffffff, {basic: true, alpha: 0.5, side: THREE.DoubleSide}); m.rotation.x = -Math.PI / 2; m.position.y = 0.12; }
  if (id === "feather") { foe(0, -9, -24, Math.PI, {vz: 3}); foe(1, 2, -27, Math.PI, {vz: 3}); foe(2, 12, -21, Math.PI, {vz: 3}); foe(3, -27, -6, Math.PI * 0.6); }
  if (id === "harvest") { foe(0, 6, -9, Math.PI * 0.9); foe(1, -5, -12, Math.PI * 1.1); foe(2, -24, -15, -Math.PI / 2, {vx: 4.5}); foe(3, 22, 8, Math.PI * 1.4); }
  if (id === "grapple") { sc.charges = 2;
    const tree = (x, z) => { const tr = wmesh(new THREE.BoxGeometry(2.4, 18, 2.4), BARK); tr.position.set(x, 9, z); const lf = wmesh(new THREE.BoxGeometry(10, 7, 10), LEAF); lf.position.set(x, 20, z); };
    tree(16, -60); const wall = wmesh(new THREE.BoxGeometry(14, 16, 3), ROCKC); wall.position.set(-26, 8, -104);
    const m = wmesh(new THREE.RingGeometry(69.5, 70.5, 96), 0xffffff, {basic: true, alpha: 0.35, side: THREE.DoubleSide}); m.rotation.x = -Math.PI / 2; m.position.y = 0.12; }
  if (id === "deflect") { foe(0, 0, -46);
    sc.rotors = [rotor(6, 3.0), rotor(6, 3.0)]; sc.orbit = new THREE.Group(); scene.add(sc.orbit); world.push(sc.orbit);
    for (let k = 0; k < 6; k++) { const b = new THREE.Mesh(new THREE.BoxGeometry(0.4, 4, 1.4), new THREE.MeshLambertMaterial({color: 0xe2dccb, emissive: VOLT, emissiveIntensity: 0.2})); sc.orbit.add(b); }
    sc.orbit.visible = false;
    sc.shots = [wmesh(new THREE.ConeGeometry(0.25, 1.6, 6).rotateX(-Math.PI / 2), 0x6bd16a), wmesh(new THREE.CylinderGeometry(0.4, 0.4, 2.2, 8).rotateX(Math.PI / 2), 0xd04030),
      wmesh(new THREE.DodecahedronGeometry(1.3), ROCKC), wmesh(new THREE.SphereGeometry(0.8, 12, 10), 0x202226)];
    sc.shots.forEach(s => s.visible = false); }
  if (id === "overclock") { ghost.g.visible = true; ghost.x = 13; ghost.z = 0; ghost.yaw = 0;
    const mud = wmesh(new THREE.PlaneGeometry(40, 18), MUDC, {alpha: 0.9}); mud.rotation.x = -Math.PI / 2; mud.position.set(6, 0.1, -55);
    const lane = wmesh(new THREE.PlaneGeometry(0.4, 200), 0xffffff, {basic: true, alpha: 0.4}); lane.rotation.x = -Math.PI / 2; lane.position.set(6.5, 0.11, -80); }
  if (id === "snare") {
    sc.traps = [0, 1, 2].map(() => { const g = new THREE.Group(); scene.add(g); world.push(g);
      for (const s of [-1, 1]) { const post = new THREE.Mesh(new THREE.BoxGeometry(0.5, 1.4, 0.5), new THREE.MeshLambertMaterial({color: DARK})); post.position.set(s * 3, 0.7, 0); g.add(post); }
      const wire = new THREE.Mesh(new THREE.BoxGeometry(6, 0.1, 0.1), new THREE.MeshBasicMaterial({color: WIRE})); wire.position.y = 0.9; g.add(wire);
      const box = new THREE.Mesh(new THREE.BoxGeometry(1.1, 0.5, 0.8), new THREE.MeshLambertMaterial({color: STEEL})); box.position.y = 0.25; g.add(box);
      const light = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.2, 0.3), new THREE.MeshBasicMaterial({color: 0xff3030})); light.position.y = 0.6; g.add(light);
      g.visible = false; return {g, wire, light, sprung: false}; });
    foe(0, 0.5, -52, Math.PI, {go: 1.5, spd: 15}); foe(1, 10.5, -50, Math.PI, {go: 2.4, spd: 14}); }
  buildLook();
}

// ---------- UI ----------
function pickLine() {
  const got = PARTS.filter(p => p.id in PICK).map(p => `${p.n}-${"ABC"[PICK[p.id]]}`);
  return got.length ? got.join(", ") : "none yet";
}
function drawTabs() {
  $("parts").innerHTML = PARTS.map((a, i) => { const [an, ac] = AREA[a.area]; return `<button class="tab" data-p="${i}" aria-pressed="${i === cur}"><span style="color:${ac}">#${a.n}</span> ${a.name}<small style="color:${ac}">${an}${a.id in PICK ? ` · <span style="color:#7dff9a">${"ABC"[PICK[a.id]]} picked</span>` : ""}</small></button>`; }).join("");
  document.querySelectorAll("[data-p]").forEach(b => b.onclick = () => { cur = +b.dataset.p; look = PICK[P().id] !== undefined ? PICK[P().id] : 0; drawAll(); resetScene(); });
  $("looks").innerHTML = P().looks.map((l, i) => `<button class="tab" data-look="${i}" aria-pressed="${i === look}">${l.name}${PICK[P().id] === i ? ' <span style="color:#7dff9a">✓</span>' : ""}<small style="color:#8f99aa">${l.sub}</small></button>`).join("");
  document.querySelectorAll("[data-look]").forEach(b => b.onclick = () => { look = +b.dataset.look; drawAll(); resetScene(); });
  const picked = PICK[P().id] === look;
  $("pickbtn").textContent = picked ? `✓ ${P().n}-${"ABC"[look]} picked (tap to clear)` : `Pick ${P().n}-${"ABC"[look]}`;
  $("pickbtn").setAttribute("aria-pressed", picked);
  $("pickline").textContent = pickLine();
}
function drawInfo() {
  const a = P(), [an, ac] = AREA[a.area], Lk = a.looks[look];
  $("info").innerHTML = `<div class="kind" style="color:${ac}">${an} · MECHA PART · BUTTON (any slot: R / T / C / V)</div><h2 style="margin-top:4px">${a.name} <span style="color:var(--muted);font-size:15px">(your #${a.n})</span></h2>
    <p class="maxed"><span class="b" style="background:${ac}">★</span> <b>Maxed:</b> ${a.maxed}</p>
    <p><b>Look ${Lk.name}:</b> ${Lk.why}</p>`;
  $("akey").textContent = SLOTS[cur % 4]; $("aname").textContent = a.name.replace(/^Reaper's /, "").split(" ")[0].toUpperCase();
}
function drawLadder() {
  $("ladder").innerHTML = `<tr><th>#</th><th>Part</th><th>I</th><th>II</th><th>III</th><th>★ (your pick)</th></tr>` + PARTS.map(a => `<tr><td>${a.n}</td><td><b>${a.name}</b><br><small style="color:${AREA[a.area][1]}">${AREA[a.area][0]}</small></td>${a.ladder.slice(0, 3).map(s => `<td>${s.replace(/^Button: /, "")}</td>`).join("")}<td class="star">${a.maxed}</td></tr>`).join("");
}
function drawAll() { drawTabs(); drawInfo(); }
$("pickbtn").onclick = () => { const id = P().id; if (PICK[id] === look) delete PICK[id]; else PICK[id] = look; savePick(); drawTabs(); };
$("copy").onclick = () => { const s = "Therizino parts looks: " + pickLine(); try { navigator.clipboard.writeText(s).then(() => { $("copy").textContent = "Copied"; setTimeout(() => $("copy").textContent = "Copy", 1200); }, () => {}); } catch (e) {} };
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => { view = b.dataset.view; document.querySelectorAll("[data-view]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
$("play").onclick = () => resetScene();
$("abtn").onclick = () => resetScene();
$("loop").onclick = e => { loop = !loop; e.currentTarget.setAttribute("aria-pressed", loop); };
$("slow").onclick = e => { slow = !slow; e.currentTarget.setAttribute("aria-pressed", slow); };
$("closeup").onclick = e => { closeup = !closeup; e.currentTarget.setAttribute("aria-pressed", closeup); };

// ---------- frame ----------
function resize() { const w = cv.clientWidth, h = cv.clientHeight; renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); }
window.addEventListener("resize", resize);
const CAM = {hook: [[0, 5, -40], 92], feather: [[0, 5, -13], 56], harvest: [[0, 4, -4], 50], grapple: [[-4, 6, -50], 118], deflect: [[0, 6, -22], 64], overclock: [null, 52], snare: [[2, 4, -22], 54]};
let last = performance.now(), paused = false;
function step(dt) {
  t += dt;
  hideLinks();
  const [A, txt] = scenario(dt);
  pose(theri, A);
  updateEquip();
  updateFoes(dt);
  updateFx(dt);
  return txt;
}
function frame(now) {
  let dt = Math.min(0.05, (now - last) / 1000); last = now;
  if (slow) dt *= 0.3;
  if (paused) dt = 0;
  const a = P(), txt = step(dt);
  const cdTotal = +((a.ladder[2].match(/recharges in (\d+) s/i) || a.ladder[0].match(/Recharges in (\d+) s/) || [0, 0])[1]) || 15;
  const frac = t < 0.4 ? 0 : clamp01(1 - (t - 0.4) * 5 / cdTotal);
  $("cdfill").style.height = (frac * 100) + "%"; $("cdtxt").textContent = frac > 0 ? Math.ceil(frac * cdTotal) + "s" : "";
  $("state").textContent = txt;
  const [cc, d] = CAM[a.id];
  const c = cc ? V(...cc) : V(6, 5, theri.z - 8);
  let cp;
  if (closeup) { const pp = partPos(theri, a.looks[look].mount); c.copy(pp); cp = pp.clone().add(V(14, 6, -8)); }
  else if (view === "side") cp = c.clone().add(V(d, d * 0.2, 0));
  else if (view === "three") cp = c.clone().add(V(d * 0.72, d * 0.42, d * 0.55));
  else cp = c.clone().add(V(0.01, d * 1.2, d * 0.18));
  if (shake > 0) { cp.add(V((Math.random() - 0.5) * shake * 2, (Math.random() - 0.5) * shake * 2, 0)); shake = Math.max(0, shake - dt * 3); }
  cam.position.copy(cp); cam.lookAt(c);
  renderer.render(scene, cam);
  if (loop && t > a.len + 1.0) resetScene();
  requestAnimationFrame(frame);
}
resize(); drawAll(); drawLadder(); resetScene();
$("ver").textContent = "v" + VERSION;
requestAnimationFrame(frame);
window.__ready = true;
window.__api = {set: (i, l) => { cur = i; look = l || 0; drawAll(); resetScene(); }, seek: tt => { const n = Math.round(tt / 0.02); for (let k = 0; k < n; k++) step(0.02); }, view: v => { view = v; }, closeup: v => { closeup = v; },
  poseTest: A => { theri.x = theri.z = 0; pose(theri, A); updateEquip(); }, freeze: () => { loop = false; slow = false; paused = true; }};
