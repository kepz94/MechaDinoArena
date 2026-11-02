// Teno mecha abilities mockup v0.2 (Kepu 2026-11-01 picks: 3 Tail Grab & Fling, 4 Boulder Mortar, 5 Stomp Shockwave,
// 7 Mud Armor, 9 Herd Bellow, 11 Challenge Call, 14 Hydraulic Leap; v0.2: "Remove the nest beacon"). TENO = TenoModelData 1.3 (look E),
// HERRERA = enemy dummies.
const TENO = __TENO__;
const HERRERA = __HERRERA__;
const $ = id => document.getElementById(id);
const rad = THREE.MathUtils.degToRad;
const AREA = {attack: ["ATTACK", "#f05a4f"], defense: ["DEFENSE", "#5aa0ff"], speed: ["SPEED", "#ffd34d"], health: ["HEALTH", "#5fd16a"], eng: ["ENGINEER", "#ff9b2e"]};
const STEEL = 0x9aa3ad, DARK = 0x3a3f47, BRASS = 0xc9a24a, RED = 0xe02a2a, MUD = 0x5b3d22, MUD2 = 0x7a5530, ROCKC = 0x8a8478, GREEN = 0x5fd16a, SKY = 0x8fc6e8;

const PICK = {grab: 0, mortar: 0, mud: 0, stomp: 1, bellow: 1, leap: 1, challenge: 1}; // + 11 D Target Painter (Kepu "Let's go D") // Kepu 2026-11-01: 3, 4, 7 A; 5, 9, 14 B; 11 redesign
const AB = [
  {id: "grab", n: 3, name: "Tail Grab & Fling", area: "attack", key: "R", len: 4.2,
    steps: ["Button: grab the nearest raptor-size dino within 12 studs with your tail and fling it 30 studs ahead. 8 damage, stunned 1 s when it lands. Recharges in 16 s",
      "Fling 45 studs", "Grabs bigger dinos too (up to pachy size)", "The flung dino crashes into others where it lands: 8 damage to each"],
    note: "The teno's answer to raptors and Herreras sneaking up behind it. I: raptor and Herrera size (a pachy or teno is too heavy until III; a T-Rex never). Works on a latched raptor too. Squadmates are never grabbed.",
    looks: [{name: "A · Clamp Tail", sub: "steel pincer on the tail tip", why: "Two steel pincer jaws bolted to the tail tip. They open as the tail swings in, snap shut on the dino, and spring open to throw it."},
      {name: "B · Hook Winch", sub: "cable hook + winch drum", why: "A winch drum on the middle of the tail and a steel hook on the tip. The hook catches the dino by the back and the cable whips it overhead."}]},
  {id: "mortar", n: 4, name: "Boulder Mortar", area: "attack", key: "T", len: 4.0,
    steps: ["Button: lob a boulder up to 60 studs where you aim. 12 damage in a 10-stud splash, enemies slowed 30% for 2 s. Recharges in 14 s",
      "Splash 14 studs", "Lobs 2 boulders side by side", "Leaves a rubble patch for 4 s: enemies in it are slowed 30%"],
    note: "Gives the slow tank a way to hit from far away. Hold to aim (a landing circle shows where it hits, like the Goo Blob Shooter), release to fire. It flies in a high arc, so it goes over walls and rocks.",
    looks: [{name: "A · Tail Catapult", sub: "a boulder bucket on the tail", why: "A steel bucket on the middle of the tail holds a boulder. The tail dips, then whips up and over the back and flings the rock forward like a catapult."},
      {name: "B · Back Mortar", sub: "a stubby mortar tube on the hips", why: "A short mortar tube on the hips with a rack of boulders on the back. It thumps and kicks back when it fires."}]},
  {id: "stomp", n: 5, name: "Stomp Shockwave", area: "defense", key: "C", len: 3.6,
    steps: ["Button: rear up and stomp. A 14-stud shockwave: 6 damage, stuns 0.5 s and knocks off latched raptors. Recharges in 15 s",
      "Stun 1 s", "Shockwave 20 studs", "Stomped dinos can't jump or pounce for 3 s"],
    note: "Close-range crowd control in front of you, where the tail slam can't reach. The shockwave is part of this button only; the jump stays plain like the other dinos.",
    looks: [{name: "A · Piston Forelegs", sub: "hydraulic pistons on the front legs", why: "Hydraulic pistons along both front legs. They pump up as it rears and fire down on the stomp."},
      {name: "B · Iron Hoof Plates", sub: "heavy steel plates on the front feet", why: "Thick riveted steel plates on both front feet that glow orange as it rears and crack the ground when they land."}]},
  {id: "bellow", n: 9, name: "Herd Bellow", area: "health", key: "V", len: 5.2,
    steps: ["Button: you and squadmates within 25 studs take 50% less damage and run 50% faster for 4 s. Recharges in 30 s",
      "Lasts 6 s", "Reaches 40 studs", "Also clears stuns on everyone it reaches"],
    note: "Your numbers: 50% less damage and 50% faster from the first step. Because that's strong, it's short (4 s) with a long recharge (30 s), and the upgrades only stretch the time and reach. Buffs don't stack with a second Herd Bellow.",
    looks: [{name: "A · Throat Horn", sub: "a brass horn on the throat", why: "A big brass horn on the throat that blares when the teno lifts its head and bellows. Green sound rings roll out."},
      {name: "B · Crest Speakers", sub: "two speakers on the head", why: "Two boxy speakers clamped on the sides of the head. They thump with each bellow, like a herd PA system."}]},
  {id: "challenge", n: 11, name: "Challenge Call", area: "defense", key: "R", len: 5.0,
    steps: ["Button: enemies within 30 studs are marked for 5 s: they deal 40% less damage, and bots go for you. Recharges in 20 s",
      "Mark lasts 7 s", "Reaches 45 studs", "Marked enemies are also slowed 20%"],
    note: "Your number: 40% less damage. It's a debuff tag on the marked dinos (their attacks are weaker while marked), so nothing has to track who hits whom. Bots also come for you.",
    looks: [{name: "C · War Drum", sub: "the tail beats a drum on the back", why: "A big steel war drum with a red skin sits on the hips, and the tail tip wears a padded mallet. On the button the tail swings up over the back and beats the drum twice: BOOM, BOOM. Each beat sends a red shockwave out and marks the enemies it reaches. Uses the teno's own tail, so it reads as a teno move."},
      {name: "D · Target Painter", sub: "a shoulder laser that tags each enemy", why: "A mecha laser turret on the shoulder. On the button it sweeps and fires a thin red beam at every enemy in range, and each one gets a red target ring that stays on them. 'Marked' is something you literally see happen."},
      {name: "E · Tail Bell", sub: "a big bronze bell on the tail tip", why: "A heavy bronze bell hangs from the tail tip. On the button the teno thrashes its tail and the bell clangs, sending red rings out from the tail. A loud, unmistakable challenge from the back end of a tank."}]},
  {id: "leap", n: 14, name: "Hydraulic Leap", area: "speed", key: "C", len: 3.6,
    steps: ["Button: a hydraulic leap 40 studs forward. Landing slams the tail: 10 damage in 12 studs (no slam charge used). Recharges in 14 s",
      "Leap 55 studs", "Landing stuns 0.5 s", "2 leaps (2 charges)"],
    note: "The slow teno's gap-closer and escape. Close to the pachy's Mecha Legs, but the landing is the teno's tail slam, so it plays differently.",
    looks: [{name: "A · Leg Pistons", sub: "pistons on the hind legs", why: "Big hydraulic pistons on both thighs that slam out on take-off and hiss on landing."},
      {name: "B · Spring Coils", sub: "steel coil springs on the shins", why: "Heavy coil springs on both shins that squash down, then fling the teno up."}]},
  {id: "mud", n: 7, name: "Mud Armor", area: "defense", key: "V", len: 5.4,
    steps: ["Button: wallow in mud. A mud coat for 8 s blocks your next 3 hits completely, and each blocked hit slows every enemy within 15 studs 40% for 4 s. Latched raptors slide off. Recharges in 20 s",
      "Blocks 4 hits", "Coat lasts 12 s", "When the coat ends it splashes 12 studs around: enemies slowed 40% for 4 s"],
    note: "Your twist: attackers get slowed for 4 s. It's a slow tag on every enemy near you when the mud blocks a hit (no tracking of who hit). Blocked hits do 0 damage, even a killing blow; the coat ends after the last blocked hit or when the time runs out.",
    looks: [{name: "A · Mud Tank", sub: "a mud tank + spray nozzle", why: "A tank of mud on the back with a spray nozzle. It sprays the teno head to tail and then it rolls in it."},
      {name: "B · Mud Pods", sub: "mud pods on the flanks", why: "Three pods on each flank that burst and splatter mud over the body when you press the button."}]},
];

// ---------- three ----------
const cv = $("cv");
const renderer = new THREE.WebGLRenderer({canvas: cv, antialias: true, preserveDrawingBuffer: true});
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
const scene = new THREE.Scene();
scene.background = new THREE.Color(SKY); scene.fog = new THREE.Fog(SKY, 160, 340);
const cam = new THREE.PerspectiveCamera(40, 16 / 9, 0.1, 700);
scene.add(new THREE.HemisphereLight(0xf2f8ff, 0x8a7a5a, 0.85));
const sun = new THREE.DirectionalLight(0xffffff, 0.75); sun.position.set(30, 50, -10); scene.add(sun);
const ground = new THREE.Mesh(new THREE.PlaneGeometry(700, 700), new THREE.MeshLambertMaterial({color: 0x9fbf6a}));
ground.rotation.x = -Math.PI / 2; scene.add(ground);
for (let i = 0; i < 140; i++) {
  const s = 0.3 + Math.random() * 0.6, p = new THREE.Mesh(new THREE.BoxGeometry(s, s * 0.5, s), new THREE.MeshLambertMaterial({color: i % 3 ? 0x7f9a52 : 0x6a5c44}));
  p.position.set((Math.random() - 0.5) * 180, s * 0.2, (Math.random() - 0.5) * 180); scene.add(p);
}
function cfm(a) { const m = new THREE.Matrix4(); m.set(a[3], a[4], a[5], a[0], a[6], a[7], a[8], a[1], a[9], a[10], a[11], a[2], 0, 0, 0, 1); return m; }
const tmpE = new THREE.Euler();
function rot(p, y, r) { tmpE.set(rad(r), rad(y), rad(p), "ZYX"); return new THREE.Matrix4().makeRotationFromEuler(tmpE); }
function buildDino(D, scale, tint) {
  const g = new THREE.Group(); scene.add(g);
  const segs = {}, parts = [], byName = {};
  for (const s of D.segs) {
    const rootInv = cfm(s.root).invert(); segs[s.n] = [];
    for (const p of s.parts) {
      const base = new THREE.Color(parseInt(p.c, 16)); if (tint) base.lerp(new THREE.Color(tint[0]), tint[1]);
      const mat = new THREE.MeshLambertMaterial({color: base.clone(), emissive: 0x000000});
      const m = new THREE.Mesh(new THREE.BoxGeometry(p.s[0], p.s[1], p.s[2]), mat); m.matrixAutoUpdate = false; g.add(m);
      const info = {mesh: m, local: rootInv.clone().multiply(cfm(p.cf)), size: p.s, seg: s.n, name: p.n, base}; segs[s.n].push(info); parts.push(info); byName[p.n] = info;
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
    for (let i = 0; i < 8; i++) { corner.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(m); minY = Math.min(minY, corner.y); }
  }
  if (d.restMinY === undefined) d.restMinY = minY; // stand on the rest pose's lowest point (poses don't bob the body)
  const lift = new THREE.Matrix4().makeTranslation(d.x, -d.restMinY + d.y, d.z);
  for (const p of d.parts) p.mesh.matrix.premultiply(lift);
}
function partPos(d, name, local) { return new THREE.Vector3(...(local || [0, 0, 0])).applyMatrix4(d.byName[name].mesh.matrix); }

// ---------- actors ----------
const teno = buildDino(TENO, 2);
const squad = [0, 1].map(() => { const d = buildDino(TENO, 1.5, [0x9ad6a0, 0.25]); d.g.visible = false; return d; });
const squadRings = squad.map(() => { const m = new THREE.Mesh(new THREE.RingGeometry(5.2, 6, 40), new THREE.MeshBasicMaterial({color: GREEN, side: THREE.DoubleSide, transparent: true, opacity: 0.8})); m.rotation.x = -Math.PI / 2; m.position.y = 0.12; scene.add(m); return m; });
const foes = [0, 1, 2, 3].map(() => { const d = buildDino(HERRERA, 2, [0xd0202a, 0.25]); d.g.visible = false; return Object.assign(d, {vx: 0, vy: 0, vz: 0, spin: 0, stun: 0, slowT: 0, mark: 0, attach: null, latched: false, active: false}); });
const HPOSE = {RootJoint: [-24, 0, 0], Neck: [6, 0, 0], Head: [16, 0, 0], Jaw: [-3, 0, 0], ArmL: [30, 0, -18], ArmR: [30, 0, 18],
  LegL: [48, 0, -16], LegR: [48, 0, 16], KneeL: [-48, 0, 0], KneeR: [-48, 0, 0], AnkleL: [24, 0, 0], AnkleR: [24, 0, 0],
  Tail1: [26, 0, 0], Tail2: [4, 0, 0], Tail3: [8, 0, 0], Tail4: [14, 0, 0], Tail5: [20, 0, 0]};
const stars = foes.map(() => [0, 1, 2].map(() => { const m = new THREE.Mesh(new THREE.OctahedronGeometry(0.5), new THREE.MeshBasicMaterial({color: 0xffe04a})); m.visible = false; scene.add(m); return m; }));

// ---------- effects ----------
const fx = [];
function addFx(o) { fx.push(o); return o; }
function dust(pos, n, spread, up, size, color) {
  for (let i = 0; i < n; i++) {
    const m = new THREE.Mesh(new THREE.IcosahedronGeometry(size * (0.6 + Math.random() * 0.8), 0), new THREE.MeshLambertMaterial({color: color || 0xcbb487, transparent: true, opacity: 0.85}));
    const a = Math.random() * Math.PI * 2, r = Math.random() * spread * 0.4;
    m.position.set(pos.x + Math.cos(a) * r, pos.y + 0.5, pos.z + Math.sin(a) * r); scene.add(m);
    addFx({m, t: 0, life: 1.0 + Math.random() * 0.6, v: new THREE.Vector3(Math.cos(a) * spread * (0.6 + Math.random()), up * (0.5 + Math.random()), Math.sin(a) * spread * (0.6 + Math.random())), grow: 1.6, kind: "dust"});
  }
}
function ring(pos, r1, life, color, wall) {
  const m = new THREE.Mesh(new THREE.RingGeometry(0.85, 1, 56), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0.9, side: THREE.DoubleSide}));
  m.rotation.x = -Math.PI / 2; m.position.set(pos.x, 0.2, pos.z); scene.add(m);
  addFx({m, t: 0, life, r0: 1, r1, kind: "ring"});
  if (wall) {
    const w = new THREE.Mesh(new THREE.CylinderGeometry(1, 1, 1, 48, 1, true), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0.3, side: THREE.DoubleSide}));
    w.position.set(pos.x, 0, pos.z); scene.add(w); addFx({m: w, t: 0, life: life * 0.8, r0: 1, r1, kind: "wall", h: wall});
  }
}
function sphereRing(pos, r1, life, color) { // a sound ring that rolls out at head height
  const m = new THREE.Mesh(new THREE.TorusGeometry(1, 0.08, 6, 48), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0.9}));
  m.position.copy(pos); m.rotation.x = Math.PI / 2; scene.add(m); addFx({m, t: 0, life, r0: 1, r1, kind: "ring"});
}
function cracks(pos, n, len) {
  for (let i = 0; i < n; i++) {
    let p = pos.clone(), ang = Math.random() * Math.PI * 2;
    for (let k = 0; k < 3; k++) {
      const L = len * (0.4 + Math.random() * 0.4) / (k + 1);
      const m = new THREE.Mesh(new THREE.BoxGeometry(0.45 / (k + 1) + 0.15, 0.06, L), new THREE.MeshBasicMaterial({color: 0x3a2e22, transparent: true, opacity: 1}));
      const dir = new THREE.Vector3(Math.sin(ang), 0, Math.cos(ang));
      m.position.copy(p).add(dir.clone().multiplyScalar(L / 2)); m.position.y = 0.06; m.rotation.y = ang; scene.add(m);
      addFx({m, t: 0, life: 2.2, kind: "crack"});
      p.add(dir.multiplyScalar(L)); ang += (Math.random() - 0.5) * 0.9;
    }
  }
}
function flash(pos, size, color) {
  const m = new THREE.Mesh(new THREE.SphereGeometry(1, 16, 12), new THREE.MeshBasicMaterial({color: color || 0xffffff, transparent: true, opacity: 0.85}));
  m.position.copy(pos); scene.add(m); addFx({m, t: 0, life: 0.3, size, kind: "flash"});
}
function patch(pos, r, life, color) { // a flat patch left on the ground (rubble, mud)
  const m = new THREE.Mesh(new THREE.CircleGeometry(r, 32), new THREE.MeshLambertMaterial({color, transparent: true, opacity: 0.9}));
  m.rotation.x = -Math.PI / 2; m.position.set(pos.x, 0.1, pos.z); scene.add(m); addFx({m, t: 0, life, kind: "patch"});
  for (let i = 0; i < 10; i++) { const s = 0.6 + Math.random(); const b = new THREE.Mesh(new THREE.BoxGeometry(s, s * 0.6, s), new THREE.MeshLambertMaterial({color: ROCKC}));
    const a = Math.random() * Math.PI * 2, rr = Math.random() * r * 0.9; b.position.set(pos.x + Math.cos(a) * rr, s * 0.3, pos.z + Math.sin(a) * rr); scene.add(b); addFx({m: b, t: 0, life, kind: "patch"}); }
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
    else if (f.kind === "ring") { const r = f.r0 + (f.r1 - f.r0) * (1 - Math.pow(1 - u, 3)); f.m.scale.set(r, r, r); f.m.material.opacity = 0.9 * (1 - u); }
    else if (f.kind === "wall") { const r = f.r0 + (f.r1 - f.r0) * (1 - Math.pow(1 - u, 3)); f.m.scale.set(r, f.h * (1 - u) + 0.5, r); f.m.position.y = f.h / 2 * (1 - u); f.m.material.opacity = 0.3 * (1 - u); }
    else if (f.kind === "crack") { f.m.material.opacity = u < 0.7 ? 1 : (1 - u) / 0.3; }
    else if (f.kind === "flash") { f.m.scale.setScalar(f.size * (0.4 + u)); f.m.material.opacity = 0.85 * (1 - u); }
    else if (f.kind === "patch") { if (f.m.material.opacity !== undefined && u > 0.8) { f.m.material.transparent = true; f.m.material.opacity = (1 - u) / 0.2; } }
    else if (f.kind === "pop") { const p = f.pos.clone().add(new THREE.Vector3(0, u * 5, 0)).project(cam); f.el.style.left = ((p.x + 1) / 2 * 100) + "%"; f.el.style.top = ((1 - p.y) / 2 * 100) + "%"; f.el.style.opacity = u < 0.7 ? 1 : (1 - u) / 0.3; }
  }
}
// status tags over actors
const tagsEl = $("tags"), tagEls = new Map();
function setTag(key, actor, text, cls, h) {
  let el = tagEls.get(key);
  if (!text) { if (el) { el.remove(); tagEls.delete(key); } return; }
  if (!el) { el = document.createElement("div"); tagsEl.appendChild(el); tagEls.set(key, el); }
  el.className = "st " + (cls || ""); el.textContent = text;
  const p = new THREE.Vector3(actor.x, (actor.y || 0) + (h || 14), actor.z).project(cam);
  el.style.left = ((p.x + 1) / 2 * 100) + "%"; el.style.top = ((1 - p.y) / 2 * 100) + "%"; el.style.display = p.z < 1 ? "block" : "none";
}
function clearTags() { for (const el of tagEls.values()) el.remove(); tagEls.clear(); }

// ---------- part pieces (follow a part of the teno) ----------
const equip = [];
function piece(partName, size, pos, rotd, color, o) {
  o = o || {};
  const geo = o.cyl ? new THREE.CylinderGeometry(size[0] / 2, (o.cyl === "cone" ? size[2] : size[0]) / 2, size[1], 14) : o.sphere ? new THREE.SphereGeometry(size[0] / 2, 16, 12) : new THREE.BoxGeometry(size[0], size[1], size[2]);
  const mat = new THREE.MeshLambertMaterial({color, emissive: o.glow ? color : 0x000000, emissiveIntensity: o.glow ? 0.5 : 0, transparent: !!o.alpha, opacity: o.alpha || 1});
  const m = new THREE.Mesh(geo, mat); m.matrixAutoUpdate = false; scene.add(m);
  const e = {mesh: m, partName, off: new THREE.Matrix4().makeTranslation(...pos).multiply(rot(rotd[0], rotd[1], rotd[2])), extra: o.extra, glow: o.glow, show: o.show};
  equip.push(e); return e;
}
function updateEquip() {
  for (const e of equip) {
    const pm = teno.byName[e.partName].mesh.matrix;
    const m = pm.clone().multiply(e.off); if (e.extra) m.multiply(e.extra());
    e.mesh.matrix.copy(m); e.mesh.visible = e.show ? e.show() : true;
  }
}
function clearEquip() { for (const e of equip) { scene.remove(e.mesh); e.mesh.geometry.dispose(); } equip.length = 0; }
const T = (x, y, z) => new THREE.Matrix4().makeTranslation(x, y, z);
const RZ = a => new THREE.Matrix4().makeRotationZ(a), RY = a => new THREE.Matrix4().makeRotationY(a), RX = a => new THREE.Matrix4().makeRotationX(a);
const SC = (x, y, z) => new THREE.Matrix4().makeScale(x, y, z);

// ---------- state ----------
let cur = 0, look = 0, step = 3, view = "side", slow = false, loop = true, closeup = false;
let t = 0, done = {}, sc = {}, cdLeft = 0;
const lerp = (a, b, u) => a + (b - a) * u, clamp01 = u => Math.max(0, Math.min(1, u));
const ease = u => 1 - Math.pow(1 - clamp01(u), 3), easeIn = u => Math.pow(clamp01(u), 2.2), smooth = u => { u = clamp01(u); return u * u * (3 - 2 * u); };
function mix(A, B, u) { const o = {}; for (const k of new Set([...Object.keys(A), ...Object.keys(B)])) { const a = A[k] || [0, 0, 0], b = B[k] || [0, 0, 0]; o[k] = [lerp(a[0], b[0], u), lerp(a[1], b[1], u), lerp(a[2], b[2], u)]; } return o; }
const once = (k, c) => { if (c && !done[k]) { done[k] = true; return true; } return false; };
const IDLE = tt => ({Neck: [Math.sin(tt * 1.3) * 3, Math.sin(tt * 0.5) * 6, 0], Head: [Math.sin(tt * 1.3 + 1) * 3, 0, 0], Tail1: [0, Math.sin(tt * 0.8) * 4, 0], Tail2: [0, Math.sin(tt * 0.8 - 0.5) * 5, 0], Tail3: [0, Math.sin(tt * 0.8 - 1) * 6, 0], Tail4: [0, Math.sin(tt * 0.8 - 1.5) * 7, 0], Tail5: [0, Math.sin(tt * 0.8 - 2) * 8, 0]});
const REAR = {RootJoint: [40, 0, 0], LegL: [-40, 0, 0], LegR: [-40, 0, 0], KneeL: [-30, 0, 0], KneeR: [-30, 0, 0], ArmL: [70, 0, 0], ArmR: [60, 0, 0], Neck: [12, 0, 0], Head: [-6, 0, 0], Jaw: [-20, 0, 0], Tail1: [-30, 0, 0], Tail2: [0, 0, 0], Tail5: [-12, 0, 0]};
const STOMP = {RootJoint: [-14, 0, 0], LegL: [14, 0, 0], LegR: [14, 0, 0], ArmL: [-12, 0, 0], ArmR: [-12, 0, 0], Neck: [-16, 0, 0], Head: [-12, 0, 0], Jaw: [-8, 0, 0], Tail1: [-20, 0, 0], Tail2: [-10, 0, 0]};
const BELLOW = {Neck: [34, 0, 0], Head: [18, 0, 0], Jaw: [-38, 0, 0], RootJoint: [6, 0, 0], LegL: [-6, 0, 0], LegR: [-6, 0, 0], Tail1: [-10, 0, 0]};
const CROUCH = {RootJoint: [-8, 0, 0], LegL: [30, 0, 0], LegR: [30, 0, 0], KneeL: [-40, 0, 0], KneeR: [-40, 0, 0], AnkleL: [12, 0, 0], AnkleR: [12, 0, 0], ArmL: [-25, 0, 0], ArmR: [-25, 0, 0], Neck: [-10, 0, 0], Tail1: [8, 0, 0], Tail2: [6, 0, 0]};
const AIR = {RootJoint: [10, 0, 0], LegL: [-30, 0, 0], LegR: [-30, 0, 0], KneeL: [-20, 0, 0], KneeR: [-20, 0, 0], ArmL: [55, 0, 0], ArmR: [55, 0, 0], Neck: [12, 0, 0], Head: [-6, 0, 0], Jaw: [-18, 0, 0], Tail1: [-16, 0, 0], Tail2: [-10, 0, 0], Tail3: [-8, 0, 0], Tail4: [-6, 0, 0], Tail5: [-6, 0, 0]};
const SLAM_UP = {RootJoint: [-12, 0, 0], LegL: [12, 0, 0], LegR: [12, 0, 0], ArmL: [-14, 0, 0], ArmR: [-14, 0, 0], Neck: [-14, 0, 0], Head: [14, 0, 0], Jaw: [-16, 0, 0], Tail1: [-58, 0, 0], Tail2: [-24, 0, 0], Tail3: [-12, 0, 0], Tail4: [6, 0, 0], Tail5: [14, 0, 0]};
const SLAM_DOWN = {RootJoint: [6, 0, 0], LegL: [-6, 0, 0], LegR: [-6, 0, 0], Neck: [-4, 0, 0], Tail1: [16, 0, 0], Tail2: [8, 0, 0], Tail3: [6, 0, 0], Tail4: [-2, 0, 0], Tail5: [-6, 0, 0]};
const LEAP_SLAM = {RootJoint: [-6, 0, 0], LegL: [6, 0, 0], LegR: [6, 0, 0], ArmL: [-10, 0, 0], ArmR: [-10, 0, 0], Neck: [-8, 0, 0], Tail1: [-30, 0, 0], Tail2: [-12, 0, 0], Tail3: [-6, 0, 0], Tail4: [4, 0, 0], Tail5: [8, 0, 0]};
const DRUM_UP = {Tail1: [-6, 0, 0], Tail2: [-34, 0, 0], Tail3: [-96, 0, 0], Tail4: [-45, 0, 0], Tail5: [-48, 0, 0], RootJoint: [-4, 0, 0]};
const DRUM_HIT = {Tail1: [-1, 0, 0], Tail2: [-32, 0, 0], Tail3: [-100, 0, 0], Tail4: [-67, 0, 0], Tail5: [-94, 0, 0], RootJoint: [-4, 0, 0]}; // tip lands on the drum (searched in the page)
const TAIL_DOWN = {Tail1: [14, 0, 0], Tail2: [14, 0, 0], Tail3: [14, 0, 0], Tail4: [12, 0, 0], Tail5: [10, 0, 0], RootJoint: [-4, 0, 0]};
const TAIL_OVER = {Tail1: [-80, 0, 0], Tail2: [-48, 0, 0], Tail3: [-42, 0, 0], Tail4: [-30, 0, 0], Tail5: [-20, 0, 0], RootJoint: [-10, 0, 0], LegL: [10, 0, 0], LegR: [10, 0, 0], Neck: [-10, 0, 0]};
const TAIL_THROW = {Tail1: [-95, 0, 0], Tail2: [-60, 0, 0], Tail3: [-50, 0, 0], Tail4: [-35, 0, 0], Tail5: [-25, 0, 0], RootJoint: [-16, 0, 0], LegL: [16, 0, 0], LegR: [16, 0, 0], Neck: [-14, 0, 0]};
const WALLOW = {RootJoint: [-6, 0, 0], LegL: [40, 0, 0], LegR: [40, 0, 0], KneeL: [-60, 0, 0], KneeR: [-60, 0, 0], ArmL: [-40, 0, 0], ArmR: [-40, 0, 0], Neck: [-20, 0, 0]};
const lvl = i => step >= i; // step index 0..3

// ---------- looks ----------
function buildLook() {
  clearEquip();
  const id = AB[cur].id;
  if (id === "grab" && look === 0) {
    const open = () => sc.clamp === undefined ? 0.6 : sc.clamp;
    piece("Tail5_main", [0.9, 0.55, 0.5], [-1.2, 0, 0], [0, 0, 0], STEEL);
    for (const s of [1, -1]) piece("Tail5_main", [1.2, 0.18, 0.18], [0, 0, 0], [0, 0, 0], DARK, {extra: () => T(-1.65, 0, 0).multiply(RY(s * open() * 0.9)).multiply(T(-0.55, 0, s * 0.18))});
    for (const s of [1, -1]) piece("Tail5_main", [0.25, 0.25, 0.25], [0, 0, 0], [0, 0, 0], RED, {glow: true, extra: () => T(-1.65, 0, 0).multiply(RY(s * open() * 0.9)).multiply(T(-1.1, 0, s * 0.18))});
  }
  if (id === "grab" && look === 1) {
    piece("Tail3_main", [0.7, 0.7, 1.2], [0.4, 0.55, 0], [0, 0, 0], DARK, {cyl: false});
    piece("Tail3_main", [0.5, 0.5, 1.3], [0.4, 0.55, 0], [0, 0, 45], STEEL);
    piece("Tail5_main", [0.18, 0.18, 0.18], [0, 0, 0], [0, 0, 0], STEEL, {extra: () => T(-1.6, 0, 0)});
    piece("Tail5_main", [0.7, 0.16, 0.16], [-1.9, -0.2, 0], [0, 0, 60], STEEL);
    piece("Tail5_main", [0.45, 0.16, 0.16], [-2.1, -0.5, 0], [0, 0, -30], RED, {glow: true});
    for (let i = 0; i < 6; i++) piece(["Tail3_main", "Tail4_main", "Tail5_main"][Math.floor(i / 2)], [1.4, 0.06, 0.06], [i % 2 ? -0.8 : 0.6, 0.45 - Math.floor(i / 2) * 0.12, 0], [0, 0, 0], 0x222222);
  }
  if (id === "mortar" && look === 0) {
    piece("Tail3_main", [1.2, 0.18, 1.1], [0.1, 0.62, 0], [0, 0, 0], STEEL);
    for (const z of [0.55, -0.55]) piece("Tail3_main", [1.2, 0.6, 0.12], [0.1, 0.92, z], [0, 0, 0], DARK);
    for (const x of [0.66, -0.46]) piece("Tail3_main", [0.12, 0.6, 1.1], [x, 0.92, 0], [0, 0, 0], DARK);
    piece("Tail3_main", [0.85, 0.85, 0.85], [0.1, 1.1, 0], [20, 20, 0], ROCKC, {show: () => !sc.rockOut || sc.reload});
  }
  if (id === "mortar" && look === 1) {
    const kick = () => T(-0.3 * (sc.kick || 0), -0.2 * (sc.kick || 0), 0);
    piece("Torso_hips", [1.0, 0.15, 1.0], [0, 1.02, 0], [0, 0, 0], DARK);
    piece("Torso_hips", [0.75, 1.3, 0.75], [0.25, 1.6, 0], [-35, 0, 0], STEEL, {cyl: true, extra: kick});
    piece("Torso_hips", [0.85, 0.16, 0.85], [0.62, 2.12, 0], [-35, 0, 0], RED, {cyl: true, glow: true, extra: kick});
    for (let i = 0; i < 3; i++) piece("Torso_barrel", [0.55, 0.55, 0.55], [-0.6 + i * 0.6, 1.25, 0.45], [i * 30, i * 20, 0], ROCKC);
    piece("Torso_barrel", [1.9, 0.12, 0.2], [0, 1.0, 0.45], [0, 0, 0], DARK);
  }
  if (id === "stomp" && look === 0) {
    for (const s of ["L", "R"]) {
      const z = s === "L" ? 0.28 : -0.28;
      piece("Arm" + s + "_upper", [0.24, 1.0, 0.24], [0.18, 0.15, z], [0, 0, 0], STEEL, {cyl: true});
      piece("Arm" + s + "_upper", [0.14, 0.9, 0.14], [0.18, -0.5, z], [0, 0, 0], 0xd8dde3, {cyl: true, extra: () => T(0, -0.35 * (sc.piston || 0), 0)});
      piece("Arm" + s + "_upper", [0.3, 0.12, 0.3], [0.18, 0.66, z], [0, 0, 0], RED, {glow: true});
    }
  }
  if (id === "stomp" && look === 1) {
    for (const s of ["L", "R"]) {
      piece("Arm" + s + "_hand", [0.95, 0.24, 0.85], [0.08, -0.2, 0], [0, 0, 0], STEEL);
      piece("Arm" + s + "_hand", [0.9, 0.08, 0.8], [0.08, -0.36, 0], [0, 0, 0], 0xff7a1a, {glow: true, show: () => (sc.heat || 0) > 0.05});
      for (const x of [-0.3, 0.3]) for (const zz of [-0.28, 0.28]) piece("Arm" + s + "_hand", [0.1, 0.06, 0.1], [0.08 + x, -0.05, zz], [0, 0, 0], DARK);
    }
  }
  if (id === "bellow" && look === 0) {
    const puff = () => { const k = 1 + 0.15 * (sc.blare || 0); return SC(k, k, k); };
    piece("Neck_upper", [0.3, 0.9, 0.3], [0.3, -0.55, 0], [-70, 0, 0], BRASS, {cyl: true});
    piece("Neck_upper", [0.75, 0.6, 0.3], [0.85, -0.38, 0], [-80, 0, 0], BRASS, {cyl: "cone", extra: puff});
    piece("Neck_upper", [0.7, 0.05, 0.7], [1.15, -0.35, 0], [-80, 0, 0], 0x2a2014, {cyl: true, extra: puff});
  }
  if (id === "bellow" && look === 1) {
    for (const z of [0.6, -0.6]) {
      const thump = () => T(0, 0, (z > 0 ? 1 : -1) * 0.08 * (sc.blare || 0) * Math.abs(Math.sin(t * 30)));
      piece("Head_cranium", [0.55, 0.6, 0.25], [-0.05, 0.05, z], [0, 0, 0], DARK);
      piece("Head_cranium", [0.38, 0.38, 0.06], [-0.05, 0.05, z + (z > 0 ? 0.14 : -0.14)], [0, 0, 0], 0x7fe9ff, {glow: true, extra: thump});
    }
    piece("Head_cranium", [0.2, 0.12, 1.25], [-0.05, 0.42, 0], [0, 0, 0], STEEL);
  }
  if (id === "challenge" && look === 0) { // C War Drum
    piece("Torso_hips", [1.6, 0.18, 1.6], [-0.1, 1.05, 0], [0, 0, 0], DARK, {cyl: true});
    piece("Torso_hips", [1.5, 0.9, 1.5], [-0.1, 1.55, 0], [0, 0, 0], STEEL, {cyl: true});
    piece("Torso_hips", [1.42, 0.06, 1.42], [-0.1, 2.02, 0], [0, 0, 0], RED, {cyl: true, glow: true, extra: () => SC(1, 1 + 3 * (sc.beat || 0), 1)});
    for (const y of [1.2, 1.9]) piece("Torso_hips", [1.58, 0.08, 1.58], [-0.1, y, 0], [0, 0, 0], BRASS, {cyl: true});
    piece("Tail5_main", [0.75, 0.75, 0.75], [-1.75, 0, 0], [0, 0, 0], BRASS, {sphere: true});
    piece("Tail5_main", [0.5, 0.5, 0.5], [-2.05, 0, 0], [0, 0, 0], RED, {sphere: true, glow: true});
  }
  if (id === "challenge" && look === 1) { // D Target Painter
    const aim = () => RY(sc.sweep || 0);
    piece("Torso_chest", [0.7, 0.35, 0.7], [0.1, 1.05, 0.45], [0, 0, 0], DARK);
    piece("Torso_chest", [0.55, 0.45, 0.55], [0.1, 1.42, 0.45], [0, 0, 0], STEEL, {extra: aim});
    piece("Torso_chest", [0.7, 0.16, 0.16], [0.1, 1.45, 0.45], [0, 0, 0], STEEL, {extra: () => aim().multiply(T(0.45, 0, 0))});
    piece("Torso_chest", [0.22, 0.22, 0.22], [0.1, 1.45, 0.45], [0, 0, 0], RED, {sphere: true, glow: true, extra: () => aim().multiply(T(0.82, 0, 0))});
  }
  if (id === "challenge" && look === 2) { // E Tail Bell
    const swing = () => RX(Math.sin(t * 22) * 0.5 * (sc.clang || 0));
    piece("Tail5_main", [0.5, 0.2, 0.5], [-1.4, -0.25, 0], [0, 0, 0], DARK);
    piece("Tail5_main", [0.5, 1.0, 1.1], [0, 0, 0], [0, 0, 0], BRASS, {cyl: "cone", extra: () => T(-1.4, -0.3, 0).multiply(swing()).multiply(T(0, -0.55, 0))});
    piece("Tail5_main", [1.25, 0.1, 1.25], [0, 0, 0], [0, 0, 0], 0x8a6a2a, {cyl: true, extra: () => T(-1.4, -0.3, 0).multiply(swing()).multiply(T(0, -1.05, 0))});
    piece("Tail5_main", [0.3, 0.3, 0.3], [0, 0, 0], [0, 0, 0], DARK, {sphere: true, extra: () => T(-1.4, -0.3, 0).multiply(swing()).multiply(T(0, -1.1, 0))});
  }
  if (id === "beacon" && look === 0) {
    const onBack = () => !sc.planted;
    piece("Torso_barrel", [1.3, 0.2, 1.1], [0, 1.15, 0], [0, 0, 0], DARK, {show: onBack});
    piece("Torso_barrel", [0.9, 1.25, 0.9], [0, 1.85, 0], [0, 0, 0], 0xd8e6ef, {sphere: true, show: onBack, extra: () => SC(1, 1.35, 1)});
    piece("Torso_barrel", [0.5, 0.5, 0.5], [0, 1.85, 0], [0, 0, 0], GREEN, {sphere: true, glow: true, show: onBack});
  }
  if (id === "beacon" && look === 1) {
    const onBack = () => !sc.planted;
    piece("Torso_barrel", [0.18, 3.0, 0.18], [0.1, 0.4, 0.92], [-75, 0, 0], STEEL, {cyl: true, show: onBack});
    piece("Torso_barrel", [0.4, 0.4, 0.4], [-1.35, 0.8, 0.92], [0, 0, 0], GREEN, {glow: true, show: onBack});
    for (const x of [-0.4, 0.5]) piece("Torso_barrel", [0.12, 0.12, 1.8], [x, 0.5, 0], [0, 0, 0], 0x3a2e22, {show: onBack});
  }
  if (id === "leap" && look === 0) {
    for (const s of ["L", "R"]) {
      const z = s === "L" ? 0.4 : -0.4;
      piece("Leg" + s + "_thigh", [0.32, 1.3, 0.32], [-0.1, 0.25, z], [0, 0, 0], STEEL, {cyl: true});
      piece("Leg" + s + "_thigh", [0.18, 1.1, 0.18], [-0.1, -0.5, z], [0, 0, 0], 0xd8dde3, {cyl: true, extra: () => T(0, -0.55 * (sc.piston || 0), 0)});
      piece("Leg" + s + "_thigh", [0.38, 0.12, 0.38], [-0.1, 0.92, z], [0, 0, 0], 0xffd34d, {glow: true});
    }
  }
  if (id === "leap" && look === 1) {
    for (const s of ["L", "R"]) {
      const z = s === "L" ? 0.3 : -0.3;
      for (let i = 0; i < 6; i++) piece("Shin" + s + "_shin", [0.62, 0.07, 0.62], [0, 0, z], [0, 0, 0], STEEL, {cyl: true, extra: () => T(0, (-0.45 + i * 0.18) * (1 - 0.45 * (sc.squash || 0) + 0.35 * (sc.piston || 0)), 0)});
      piece("Shin" + s + "_shin", [0.7, 0.1, 0.7], [0, 0.62, z], [0, 0, 0], 0xffd34d, {cyl: true, glow: true});
    }
  }
  if (id === "mud" && look === 0) {
    piece("Torso_barrel", [1.5, 0.95, 1.0], [0, 1.6, 0], [0, 0, 90], STEEL, {cyl: true});
    piece("Torso_barrel", [1.3, 0.75, 0.8], [0, 1.6, 0], [0, 0, 90], MUD, {cyl: true, extra: () => SC(1, Math.max(0.15, 1 - (sc.drain || 0)), 1)});
    piece("Torso_barrel", [0.2, 0.9, 0.2], [0.75, 2.05, 0], [-50, 0, 0], DARK, {cyl: true});
    piece("Torso_barrel", [0.3, 0.2, 0.3], [1.1, 2.35, 0], [-50, 0, 0], 0x9b6b3a, {cyl: true});
  }
  if (id === "mud" && look === 1) {
    for (const s of [1, -1]) for (let i = 0; i < 3; i++) {
      piece("Torso_barrel", [0.5, 0.5, 0.5], [-0.6 + i * 0.6, 0.15, s * 0.88], [0, 0, 0], MUD2, {sphere: true, show: () => !sc.burst});
      piece("Torso_barrel", [0.56, 0.1, 0.56], [-0.6 + i * 0.6, 0.15, s * 0.82], [90, 0, 0], STEEL, {cyl: true});
    }
  }
}
// mud coat pieces (shown while coated)
const coat = [];
function buildCoat() {
  for (const c of coat) { scene.remove(c.mesh); } coat.length = 0;
  const names = ["Torso_hips", "Torso_barrel", "Torso_chest", "Neck_base", "Neck_upper", "Tail1_main", "Tail2_main", "Tail3_main", "LegL_thigh", "LegR_thigh", "ArmL_upper", "ArmR_upper", "Head_cranium"];
  for (const n of names) for (let i = 0; i < 3; i++) {
    const p = teno.byName[n]; if (!p) continue;
    const s = [p.size[0] * (0.3 + Math.random() * 0.3), 0.12, p.size[2] * (0.4 + Math.random() * 0.3)];
    const m = new THREE.Mesh(new THREE.BoxGeometry(s[0], s[1], s[2]), new THREE.MeshLambertMaterial({color: i % 2 ? MUD : MUD2})); m.matrixAutoUpdate = false; scene.add(m);
    coat.push({mesh: m, part: p, off: T((Math.random() - 0.5) * p.size[0] * 0.6, p.size[1] / 2 + 0.03, (Math.random() - 0.5) * p.size[2] * 0.4)});
  }
}
buildCoat();
function setMud(k) { // 0..1 body tint + coat pieces
  for (const p of teno.parts) p.mesh.material.color.copy(p.base).lerp(new THREE.Color(MUD), k * 0.55);
  for (const c of coat) { c.mesh.visible = k > 0.3; c.mesh.matrix.copy(c.part.mesh.matrix).multiply(c.off); }
}
function setGlow(color, k) { for (const p of teno.parts) p.mesh.material.emissive.setHex(color).multiplyScalar(k); }
function squadGlow(k) { for (const d of squad) for (const p of d.parts) p.mesh.material.emissive.setHex(GREEN).multiplyScalar(k); }

// ---------- scenarios ----------
const FWD = -1; // the teno faces -z
const world = [];  // loose meshes (rock, beacon) owned by a scenario
function clearWorld() { for (const m of world) scene.remove(m); world.length = 0; }
function foe(i, x, z, yaw, extra) { const d = foes[i]; Object.assign(d, {x, z, y: 0, yaw: yaw === undefined ? 0 : yaw, roll: 0, vx: 0, vy: 0, vz: 0, spin: 0, stun: 0, slowT: 0, mark: 0, attach: null, latched: false, active: true, nojump: 0, hit: 0}, extra || {}); d.g.visible = true; return d; }
function hitFoe(d, dmg, txt, cls) { popNum(new THREE.Vector3(d.x, d.y, d.z), txt || ("-" + dmg), cls); d.hit = 0.25; }
function launch(d, vx, vy, vz, spin) { d.vx = vx; d.vy = vy; d.vz = vz; d.spin = spin || 4; d.airborne = true; }
function resetScene() {
  clearFx(); clearTags(); clearWorld(); done = {}; sc = {}; t = 0; cdLeft = 0;
  teno.x = teno.z = teno.y = 0; teno.yaw = 0; teno.roll = 0; teno.g.visible = true;
  for (const p of teno.parts) { p.mesh.material.opacity = 1; p.mesh.material.transparent = false; }
  for (const d of foes) { d.active = false; d.g.visible = false; }
  squad.forEach((d, i) => { d.g.visible = false; squadRings[i].visible = false; });
  setMud(0); setGlow(0, 0); squadGlow(0);
  const id = AB[cur].id;
  if (id === "grab") { foe(0, 0, 30, 0, {walk: [30, 15]}); if (lvl(3)) foe(1, 3, lvl(1) ? -52 : -37, Math.PI); }
  if (id === "mortar") { foe(0, -3, -60, Math.PI); foe(1, 5, -64, Math.PI); if (lvl(1)) foe(2, 10, -58, Math.PI); }
  if (id === "stomp") { foe(0, 10, -22, Math.PI * 0.8); foe(1, -12, -20, Math.PI * 1.2); foe(2, 0, 2, 0, {latched: true}); if (lvl(2)) foe(3, 17, -6, Math.PI * 0.6); }
  if (id === "bellow") { squad.forEach((d, i) => { d.g.visible = true; squadRings[i].visible = true; d.x = i ? -14 : 16; d.z = i ? 10 : -6; d.yaw = 0; d.stunned = lvl(3) && i === 1; });
    if (lvl(2)) { squad[1].x = -30; squad[1].z = 16; } foe(0, 18, -28, Math.PI); }
  if (id === "challenge") { squad[0].g.visible = true; squadRings[0].visible = true; squad[0].x = -18; squad[0].z = -6; squad[0].yaw = 0;
    foe(0, -24, -26, Math.PI * 0.85); foe(1, 14, -24, Math.PI * 1.1); foe(2, 22, 6, Math.PI * 1.5); if (lvl(2)) foe(3, -36, 20, Math.PI * 0.4); }
  if (id === "beacon") { squad[0].g.visible = true; squadRings[0].visible = true; squad[0].x = -22; squad[0].z = 4; squad[0].yaw = 0; foe(0, -26, -34, Math.PI * 0.8); }
  if (id === "leap") { const L = lvl(1) ? 55 : 40; foe(0, 13, -L - 6, Math.PI * 0.7); foe(1, -13, -L + 8, Math.PI * 1.3); }
  if (id === "mud") { foe(0, 16, -22, Math.PI * 0.75); foe(1, 22, 6, Math.PI * 1.5); foe(2, 0, 2, 0, {latched: true}); }
  buildLook();
}
function hitsLeft(n) { $("hits").innerHTML = Array.from({length: n}, () => "<i></i>").join(""); }

function scenario(dt) {
  const id = AB[cur].id, A = IDLE(t);
  let stateTxt = "";
  if (id === "grab") {
    const f = foes[0], reach = 1.2, catchT = 1.5, throwT = 2.4, dist = lvl(1) ? 45 : 30;
    if (t < reach) { f.z = lerp(30, 17, smooth(t / reach)); return [A, "a Herrera sneaks up behind you..."]; }
    let P;
    if (t < catchT) { const u = smooth((t - reach) / (catchT - reach)); P = mix(A, TAIL_DOWN, u); sc.clamp = 0.6; stateTxt = "R: the tail swings round"; }
    else if (t < throwT) { const u = smooth((t - catchT) / (throwT - catchT)); P = mix(TAIL_DOWN, TAIL_OVER, u); sc.clamp = 0; if (once("grab", true)) { f.attach = "tail"; flash(partPos(teno, "Tail5_main", [-1.6, 0, 0]), 2, 0xffffff); } stateTxt = "GRAB! lifted over your back"; }
    else { const u = smooth((t - throwT) / 0.3); P = mix(TAIL_OVER, TAIL_THROW, u); if (t > throwT + 0.6) P = mix(TAIL_THROW, A, smooth((t - throwT - 0.6) / 0.8));
      sc.clamp = 0.9;
      if (once("throw", t >= throwT + 0.12)) { const tip = partPos(teno, "Tail5_main", [-1.6, 0, 0]); f.attach = null; f.x = tip.x; f.y = tip.y; f.z = tip.z;
        const flight = 1.1, tz = -dist; launch(f, 0, 32, (tz - tip.z) / flight, 9); f.flingLand = true; stateTxt = "FLING!"; }
      stateTxt = done.landed ? (lvl(3) ? "it crashes into the dino it lands on" : "8 damage + stunned 1 s") : "FLING!"; }
    if (f.attach === "tail") { const tip = partPos(teno, "Tail5_main", [-2.0, -0.6, 0]); f.x = tip.x; f.y = tip.y - 5; f.z = tip.z; f.roll = Math.PI * 0.8; }
    return [P, stateTxt];
  }
  if (id === "mortar") {
    const fire = 1.0, flight = 1.3, land = fire + flight;
    let P = A;
    if (look === 0) { if (t < fire) P = mix(A, TAIL_DOWN, smooth(t / fire)); else if (t < fire + 0.35) P = mix(TAIL_DOWN, TAIL_THROW, smooth((t - fire) / 0.25)); else P = mix(TAIL_THROW, A, smooth((t - fire - 0.35) / 1)); }
    else { sc.kick = t > fire && t < fire + 0.4 ? 1 - (t - fire) / 0.4 : 0; }
    const shots = lvl(2) ? [[-3, -62], [6, -62]] : [[1, -62]];
    if (once("fire", t >= fire)) {
      sc.rockOut = true;
      const from = look === 0 ? partPos(teno, "Tail3_main", [0.1, 1.1, 0]) : partPos(teno, "Torso_hips", [0.8, 2.3, 0]);
      if (look === 1) { flash(from, 2, 0xffe2a0); dust(from, 6, 3, 4, 0.8, 0xdddddd); }
      sc.rocks = shots.map(([x, z]) => { const m = new THREE.Mesh(new THREE.IcosahedronGeometry(1.4, 0), new THREE.MeshLambertMaterial({color: ROCKC})); scene.add(m); world.push(m); return {m, from: from.clone(), to: new THREE.Vector3(x, 0, z)}; });
    }
    if (sc.rocks) for (const r of sc.rocks) { const u = clamp01((t - fire) / flight); r.m.visible = u < 1; r.m.position.lerpVectors(r.from, r.to, u); r.m.position.y = lerp(r.from.y, 0, u) + Math.sin(u * Math.PI) * 30; r.m.rotation.x += dt * 8; }
    if (once("land", t >= land)) {
      const R = lvl(1) ? 14 : 10; shake = 0.6;
      for (const r of sc.rocks) { ring(r.to, R, 0.7, 0xffe2a0, 4); dust(r.to, 10, 7, 6, 1.2); if (lvl(3)) patch(r.to, R * 0.8, 5, 0x6a5c44); }
      for (const d of foes) if (d.active) { const near = sc.rocks.some(r => Math.hypot(d.x - r.to.x, d.z - r.to.z) <= R + 1); if (near) { hitFoe(d, 12); d.slowT = 2; launch(d, (d.x - 1) * 0.6, 14, 4, 2); } }
    }
    stateTxt = t < fire ? "T: hold to aim · release to fire" : t < land ? "boulder in the air (high arc, goes over walls)" : (lvl(3) ? "12 splash + slowed 30% · rubble patch slows for 4 s" : "12 damage in the splash + slowed 30% for 2 s");
    if (t > fire + 2.4) sc.reload = true;
    return [P, stateTxt];
  }
  if (id === "stomp") {
    const up = 0.8, hit = 1.0, R = lvl(2) ? 20 : 14, stun = lvl(1) ? 1 : 0.5;
    let P;
    if (t < up) { P = mix(A, REAR, smooth(t / up)); sc.piston = -smooth(t / up) * 0.6; sc.heat = smooth(t / up); }
    else if (t < hit) { P = mix(REAR, STOMP, easeIn((t - up) / (hit - up))); sc.piston = 1; }
    else { P = mix(STOMP, A, smooth((t - hit - 0.3) / 0.9)); sc.piston = Math.max(0, 1 - (t - hit) * 2); sc.heat = Math.max(0, 1 - (t - hit)); }
    if (once("hit", t >= hit)) {
      const c = partPos(teno, "ArmL_hand"); c.y = 0; c.x = 0; shake = 0.8;
      ring(c, R, 0.8, 0xfff1c8, 6); cracks(c, 7, 9); dust(c, 12, 8, 5, 1.2);
      for (const d of foes) if (d.active) {
        if (d.latched) { d.latched = false; launch(d, 12, 22, 6, 6); popNum(new THREE.Vector3(d.x, 10, d.z), "SHAKEN OFF", "big"); continue; }
        if (Math.hypot(d.x - c.x, d.z - c.z) <= R + 2) { hitFoe(d, 6); d.stun = stun; if (lvl(3)) d.nojump = 3; launch(d, 0, 8, 0, 0); }
      }
    }
    stateTxt = t < hit ? "C: rear up..." : `STOMP · ${R}-stud shockwave · 6 damage · stun ${stun} s`;
    return [P, stateTxt];
  }
  if (id === "bellow") {
    const go = 0.5, dur = lvl(1) ? 6 : 4, R = lvl(2) ? 40 : 25, k = t >= go + 0.3 ? 1 : 0, left = Math.max(0, go + 0.3 + dur * 0.55 - t) / 0.55; // demo time runs ~1.8x
    let P = t < go ? mix(A, BELLOW, smooth(t / go)) : t < go + 1.2 ? BELLOW : mix(BELLOW, A, smooth((t - go - 1.2) / 0.6));
    sc.blare = t > go && t < go + 1.2 ? 1 : 0;
    if (t > go && t < go + 1.2 && Math.floor((t - go) * 5) !== sc.lastRing) { sc.lastRing = Math.floor((t - go) * 5); sphereRing(partPos(teno, "Head_cranium"), R, 1.0, GREEN); }
    if (once("buff", t >= go + 0.3)) { ring(new THREE.Vector3(0, 0, 0), R, 1.0, GREEN, 3); }
    const buffed = left > 0 && t >= go + 0.3;
    setGlow(GREEN, buffed ? 0.25 + 0.1 * Math.sin(t * 8) : 0); squadGlow(buffed ? 0.25 : 0);
    squad.forEach((d, i) => { const inR = Math.hypot(d.x, d.z) <= R; if (buffed && inR) { d.z -= dt * 22; if (d.stunned) { d.stunned = false; popNum(new THREE.Vector3(d.x, 0, d.z), "STUN CLEARED", "good"); } }
      else if (t > go) d.z -= dt * 6;
      setTag("sq" + i, d, d.stunned ? "STUNNED" : buffed && inR ? `-50% DMG · +50% SPEED · ${Math.ceil(left * dur / (dur))}` : !inR && t > go ? "out of range" : "", d.stunned ? "yellow" : inR ? "green" : "", 11); });
    setTag("me", teno, buffed ? "-50% DMG · +50% SPEED" : "", "green", 16);
    const f = foes[0];
    if (once("bite", t >= go + 1.4)) { const s0 = squad[0]; f.x = s0.x + 4; f.z = s0.z - 8; popNum(new THREE.Vector3(s0.x, 0, s0.z), "-5 (was 10)", "good"); }
    stateTxt = t < go ? "V: bellow" : buffed ? `HERD BELLOW · ${dur} s · ${R} studs` : "buff over";
    return [P, stateTxt];
  }
  if (id === "challenge") {
    const go = 0.5, R = lvl(2) ? 45 : 30, mark = lvl(1) ? 7 : 5;
    let P;
    const markAll = () => { for (const d of foes) if (d.active && Math.hypot(d.x, d.z) <= R) d.mark = mark; };
    if (look === 0) { // War Drum: tail up over the back, two beats
      const beats = [go, go + 0.45];
      const bt = beats.map(b => Math.abs(t - b)), near = Math.min(...bt);
      P = t < go - 0.35 ? mix(A, DRUM_UP, smooth(t / (go - 0.35))) : t < go + 0.8 ? mix(DRUM_UP, DRUM_HIT, near < 0.12 ? 1 - near / 0.12 : 0) : mix(DRUM_UP, A, smooth((t - go - 0.8) / 0.6));
      sc.beat = near < 0.1 ? 1 - near / 0.1 : 0;
      beats.forEach((b, k) => { if (once("beat" + k, t >= b)) { const dp = partPos(teno, "Torso_hips", [-0.1, 2.0, 0]); ring(new THREE.Vector3(0, 0, 0), R, 1.0, RED, 4); sphereRing(dp, R * 0.6, 0.8, RED); flash(dp, 2.5, 0xff8080); shake = 0.35; popNum(dp.clone().add(new THREE.Vector3(0, -4, 0)), "BOOM", "big"); if (k === 0) markAll(); } });
    } else if (look === 1) { // Target Painter: sweep, one beam per enemy
      P = t < go ? mix(A, BELLOW, smooth(t / go) * 0.4) : mix(mix(A, BELLOW, 0.4), A, smooth((t - go - 0.9) / 0.6));
      sc.sweep = t < go ? 0 : Math.sin((t - go) * 7) * 0.8 * Math.max(0, 1 - (t - go) / 1.2);
      if (once("paint", t >= go)) { markAll(); sc.beams = foes.filter(d => d.active && d.mark > 0).map((d, k) => { const m = new THREE.Mesh(new THREE.BoxGeometry(0.25, 0.25, 1), new THREE.MeshBasicMaterial({color: 0xff2a2a, transparent: true, opacity: 0.9})); scene.add(m); world.push(m); return {m, d, k}; });
        sc.reticles = foes.filter(d => d.active && d.mark > 0).map(d => { const m = new THREE.Mesh(new THREE.RingGeometry(3.2, 3.8, 32), new THREE.MeshBasicMaterial({color: 0xff2a2a, side: THREE.DoubleSide, transparent: true, opacity: 0.9})); m.rotation.x = -Math.PI / 2; scene.add(m); world.push(m); return {m, d}; }); }
      if (sc.beams) { const from = partPos(teno, "Torso_chest", [0.1, 1.45, 0.45]); for (const b of sc.beams) { const on = t >= go + b.k * 0.15 && t < go + 0.9 + b.k * 0.15; b.m.visible = on; if (on) { const to = new THREE.Vector3(b.d.x, b.d.y + 5, b.d.z); b.m.position.lerpVectors(from, to, 0.5); b.m.lookAt(to); b.m.scale.set(1, 1, from.distanceTo(to)); b.m.material.opacity = 0.6 + 0.4 * Math.random(); } } }
      if (sc.reticles) for (const r of sc.reticles) { r.m.visible = r.d.mark > 0; r.m.position.set(r.d.x, 0.25, r.d.z); r.m.rotation.z = t * 2; }
    } else { // Tail Bell: thrash the tail, clang clang clang
      const on = t >= go - 0.2 && t < go + 1.0;
      sc.clang = on ? 1 : Math.max(0, (sc.clang || 0) - 0.05);
      const thrash = on ? Math.sin((t - go) * 14) * 26 : 0;
      P = Object.assign({}, A, {Tail1: [-18, thrash * 0.4, 0], Tail2: [-10, thrash * 0.6, 0], Tail3: [-6, thrash * 0.8, 0], Tail4: [-4, thrash, 0], Tail5: [0, thrash * 1.2, 0], Neck: [10, 0, 0], Jaw: [-20, 0, 0]});
      if (on && Math.floor((t - go) * 14 / Math.PI) !== sc.lastClang) { sc.lastClang = Math.floor((t - go) * 14 / Math.PI); const bp = partPos(teno, "Tail5_main", [-1.4, -1.2, 0]); sphereRing(bp, 9, 0.6, RED); popNum(bp.clone().add(new THREE.Vector3(0, -6, 0)), "CLANG", "soft"); }
      if (once("bell", t >= go)) { ring(new THREE.Vector3(0, 0, 14), R, 1.0, RED, 4); markAll(); }
    }
    for (const [i, d] of foes.entries()) if (d.active) setTag("m" + i, d, d.mark > 0 ? (lvl(3) ? "◆ MARKED · -40% DMG · SLOW" : "◆ MARKED · -40% DMG") : t > go ? "too far" : "", d.mark > 0 ? "red" : "", 12);
    if (t > go + 0.6) { for (const d of foes) if (d.active && d.mark > 0) { const dx = -d.x, dz = -d.z, L = Math.hypot(dx, dz); if (L > 18) { d.x += dx / L * dt * 12; d.z += dz / L * dt * 12; } d.yaw = Math.atan2(-dx, -dz); } }
    if (once("hitSquad", t >= go + 1.6)) popNum(new THREE.Vector3(squad[0].x, 0, squad[0].z), "-6 (was 10)", "soft");
    if (once("hitMe", t >= go + 2.4)) popNum(new THREE.Vector3(0, 0, 0), "-6 (was 10)", "soft");
    stateTxt = t < go ? "R: challenge call" : `MARKED ${mark} s · marked dinos deal 40% less damage · bots come for you${lvl(3) ? " · slowed 20%" : ""}`;
    return [P, stateTxt];
  }
  if (id === "beacon") {
    const plant = 0.9, ko = 2.4, back = 3.4;
    let P = A;
    if (t < plant) P = mix(A, CROUCH, smooth(t / plant)); else if (t < plant + 0.6) P = mix(CROUCH, A, smooth((t - plant) / 0.6));
    if (once("plant", t >= plant)) {
      sc.planted = true;
      const pos = new THREE.Vector3(12, 0, 8); sc.bpos = pos;
      const g = new THREE.Group(); g.position.copy(pos); scene.add(g); world.push(g);
      if (look === 0) { const shell = new THREE.Mesh(new THREE.SphereGeometry(1.6, 16, 12), new THREE.MeshLambertMaterial({color: 0xd8e6ef})); shell.scale.set(1, 1.35, 1); shell.position.y = 2.1; g.add(shell);
        const core = new THREE.Mesh(new THREE.SphereGeometry(0.95, 16, 12), new THREE.MeshLambertMaterial({color: GREEN, emissive: GREEN, emissiveIntensity: 0.6})); core.position.y = 2.1; g.add(core); sc.core = core;
        const base = new THREE.Mesh(new THREE.CylinderGeometry(2.2, 2.6, 0.5, 16), new THREE.MeshLambertMaterial({color: DARK})); base.position.y = 0.25; g.add(base); }
      else { const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.25, 0.08, 7, 10), new THREE.MeshLambertMaterial({color: STEEL})); pole.position.y = 3.2; g.add(pole);
        const lamp = new THREE.Mesh(new THREE.BoxGeometry(1.1, 1.1, 1.1), new THREE.MeshLambertMaterial({color: GREEN, emissive: GREEN, emissiveIntensity: 0.6})); lamp.position.y = 7; g.add(lamp); sc.core = lamp; }
      dust(pos, 6, 3, 3, 0.8); ring(pos, 6, 0.6, GREEN);
    }
    if (sc.core) sc.core.material.emissiveIntensity = 0.4 + 0.4 * Math.abs(Math.sin(t * 3));
    if (sc.bpos) setTag("b", {x: sc.bpos.x, y: 0, z: sc.bpos.z}, `NEST BEACON · ${lvl(1) ? 100 : 60} HP · ${lvl(2) ? 2 : 1} respawn${lvl(2) ? "s" : ""}`, "green", 11);
    if (t >= ko && t < back) { const u = clamp01((t - ko) / 0.5); for (const p of teno.parts) { p.mesh.material.transparent = true; p.mesh.material.opacity = 1 - u; } for (const e of equip) e.mesh.visible = false; stateTxt = "you get knocked out..."; }
    if (once("respawn", t >= back)) { teno.x = sc.bpos.x + 6; teno.z = sc.bpos.z + 2; for (const p of teno.parts) { p.mesh.material.opacity = 1; p.mesh.material.transparent = false; } ring(new THREE.Vector3(teno.x, 0, teno.z), 10, 0.8, GREEN, 6); flash(new THREE.Vector3(teno.x, 6, teno.z), 6, GREEN); }
    if (t >= back) { stateTxt = lvl(3) ? "RESPAWNED AT THE BEACON · 3 s shield" : "RESPAWNED AT THE BEACON"; setGlow(0x7fe9ff, lvl(3) && t < back + 1.6 ? 0.45 : 0); }
    else if (t < ko) stateTxt = t < plant ? "T: plant the beacon" : "beacon planted";
    return [P, stateTxt];
  }
  if (id === "leap") {
    const crouch = 0.4, air = 1.0, dist = lvl(1) ? 55 : 40;
    let P;
    if (t < crouch) { P = mix(A, CROUCH, smooth(t / crouch)); sc.squash = smooth(t / crouch); sc.piston = 0; }
    else if (t < crouch + air) { const u = (t - crouch) / air; P = u < 0.8 ? mix(CROUCH, AIR, smooth(u / 0.25)) : mix(AIR, LEAP_SLAM, smooth((u - 0.8) / 0.2)); teno.z = -dist * u; teno.y = Math.sin(u * Math.PI) * 16; sc.squash = 0; sc.piston = Math.max(0, 1 - u * 3);
      if (once("launch", true)) { dust(new THREE.Vector3(0, 0, 0), 10, 6, 4, 1); } }
    else { const u = t - crouch - air; teno.y = 0; teno.z = -dist; P = u < 0.15 ? mix(LEAP_SLAM, SLAM_DOWN, easeIn(u / 0.15)) : mix(SLAM_DOWN, A, smooth((u - 0.3) / 0.8));
      if (once("land", true)) { const c = new THREE.Vector3(0, 0, -dist); shake = 0.7; ring(c, 18, 0.7, 0xfff1c8, 5); dust(c, 10, 6, 5, 1.2); cracks(c, 5, 7);
        for (const d of foes) if (d.active && Math.hypot(d.x - c.x, d.z - c.z) <= 20) { hitFoe(d, 10); if (lvl(2)) d.stun = 0.5; launch(d, Math.sign(d.x) * 6, 14, 0, 3); } } }
    stateTxt = t < crouch ? "C: crouch on the pistons" : t < crouch + air ? `HYDRAULIC LEAP · ${dist} studs` : `tail-slam landing · 10 damage${lvl(2) ? " · stun 0.5 s" : ""}${lvl(3) ? " · 1 leap left" : ""}`;
    return [P, stateTxt];
  }
  if (id === "mud") {
    const wal = 1.2, coatT = lvl(2) ? 12 : 8, hits = lvl(1) ? 4 : 3;
    let P = A;
    if (t < wal) { P = mix(A, WALLOW, smooth(t / 0.3)); teno.roll = Math.sin(t * 9) * 0.35 * Math.min(1, t * 3) * (1 - t / wal); sc.drain = t / wal;
      if (Math.floor(t * 10) !== sc.lastDust) { sc.lastDust = Math.floor(t * 10); dust(new THREE.Vector3((Math.random() - 0.5) * 8, 0, (Math.random() - 0.5) * 10), 2, 4, 3, 1, MUD2); } }
    else { P = mix(WALLOW, A, smooth((t - wal) / 0.5)); teno.roll *= 0.8; }
    if (once("burst", look === 1 && t > 0.15)) { sc.burst = true; for (let i = 0; i < 6; i++) dust(partPos(teno, "Torso_barrel", [-0.6 + (i % 3) * 0.6, 0.2, i < 3 ? 0.9 : -0.9]), 2, 3, 3, 0.6, MUD2); }
    if (once("spray", look === 0 && t > 0.1)) { for (let i = 0; i < 8; i++) dust(partPos(teno, "Torso_barrel", [1.1, 2.4, 0]), 1, 6, 2, 0.6, MUD2); }
    setMud(clamp01(t / wal));
    if (once("slide", t >= 0.7)) { const d = foes[2]; d.latched = false; launch(d, -10, 10, 8, 3); popNum(new THREE.Vector3(d.x, 8, d.z), "SLID OFF", "big"); }
    if (sc.hits === undefined) sc.hits = hits;
    const attacks = [[1.8, 0], [2.6, 1]];
    for (const [at, i] of attacks) if (once("atk" + i, t >= at)) { const d = foes[i]; d.x = lerp(d.x, 0, 0.45); d.z = lerp(d.z, 0, 0.45); sc.hits--; popNum(new THREE.Vector3(0, 0, 0), "BLOCKED", "soft"); for (const o of foes) if (o.active && !o.latched && Math.hypot(o.x, o.z) < 30) o.slowT = 4; }
    for (const [i, d] of foes.entries()) if (d.active && !d.latched) setTag("s" + i, d, d.slowT > 0 ? `SLOWED 40% · ${d.slowT.toFixed(1)} s` : "", "blue", 11);
    hitsLeft(t >= wal ? sc.hits : 0);
    if (lvl(3) && once("end", t >= 4.2)) { ring(new THREE.Vector3(0, 0, 0), 12, 0.8, MUD2, 3); dust(new THREE.Vector3(0, 0, 0), 14, 8, 4, 1.2, MUD2); for (const d of foes) if (d.active && Math.hypot(d.x, d.z) < 16) d.slowT = 4; }
    stateTxt = t < wal ? "V: wallow in the mud" : `MUD COAT · ${coatT} s · soaks ${hits} hits · attackers slowed 40% for 4 s`;
    if (lvl(3) && t >= 4.2) stateTxt = "coat ends · mud splash: enemies around slowed 40% for 4 s";
    return [P, stateTxt];
  }
  return [A, ""];
}

// ---------- foes per frame ----------
function updateFoes(dt) {
  foes.forEach((d, i) => {
    if (!d.active) { stars[i].forEach(s => s.visible = false); return; }
    if (d.latched) { const back = partPos(teno, "Torso_dorsalBack"); d.x = back.x; d.z = back.z + 1; d.y = back.y - 6.5; d.roll = Math.sin(t * 6) * 0.15;
      pose(d, Object.assign({}, HPOSE, {Head: [-10 + Math.sin(t * 12) * 12, 0, 0], Jaw: [-30, 0, 0]})); stars[i].forEach(s => s.visible = false); return; }
    if (d.attach) { pose(d, HPOSE); return; }
    if (d.airborne) { d.vy -= 70 * dt; d.x += d.vx * dt; d.z += d.vz * dt; d.y += d.vy * dt; d.roll += d.spin * dt;
      if (d.y <= 0) { d.y = 0; d.airborne = false; d.vx = d.vz = 0; d.vy = 0; dust(new THREE.Vector3(d.x, 0, d.z), 5, 5, 3, 1);
        if (d.flingLand) { d.flingLand = false; done.landed = true; hitFoe(d, 8); d.stun = 1; shake = 0.4;
          if (lvl(3)) { ring(new THREE.Vector3(d.x, 0, d.z), 8, 0.6, 0xfff1c8, 3); for (const o of foes) if (o !== d && o.active && Math.hypot(o.x - d.x, o.z - d.z) < 10) { hitFoe(o, 8); o.stun = 1; launch(o, 4, 12, -4, 3); } } } } }
    if (!d.airborne) d.roll *= 0.85;
    d.stun = Math.max(0, d.stun - dt); d.slowT = Math.max(0, d.slowT - dt); d.mark = Math.max(0, d.mark - dt * 0.6); d.nojump = Math.max(0, (d.nojump || 0) - dt);
    const a = Object.assign({}, HPOSE); if (d.stun > 0) a.Head = [16 + Math.sin(t * 20) * 10, 0, 0];
    pose(d, a);
    stars[i].forEach((s, k) => { s.visible = d.stun > 0; if (s.visible) { const an = t * 5 + k * 2.1; s.position.set(d.x + Math.cos(an) * 2.4, d.y + 9, d.z + Math.sin(an) * 2.4); s.rotation.y += dt * 6; } });
    if (AB[cur].id === "stomp") setTag("nj" + i, d, d.nojump > 0 && !d.latched ? `NO JUMP / POUNCE · ${d.nojump.toFixed(1)} s` : "", "yellow", 12);
    if (AB[cur].id === "mortar") setTag("sl" + i, d, d.slowT > 0 ? "SLOWED 30%" : "", "blue", 12);
    for (const p of d.parts) p.mesh.material.emissive.setHex(d.hit > 0 ? 0xffffff : 0x000000).multiplyScalar(d.hit > 0 ? 0.6 : 0); d.hit = Math.max(0, (d.hit || 0) - dt);
  });
}

// ---------- UI ----------
function areaStyle(a) { return AREA[a]; }
function drawTabs() {
  $("abil").innerHTML = AB.map((a, i) => `<button class="tab" data-ab="${i}" aria-pressed="${i === cur}"><span style="color:${areaStyle(a.area)[1]}">#${a.n}</span> ${a.name}<small style="color:${areaStyle(a.area)[1]}">${areaStyle(a.area)[0]}${a.id in PICK ? ` · <span style="color:#7dff9a">${a.looks[PICK[a.id]].name[0]} picked</span>` : a.id === "challenge" ? ' · <span style="color:#ffc832">new looks</span>' : ""}</small></button>`).join("");
  document.querySelectorAll("[data-ab]").forEach(b => b.onclick = () => { cur = +b.dataset.ab; look = PICK[AB[cur].id] || 0; drawAll(); resetScene(); });
  $("looks").innerHTML = AB[cur].looks.map((l, i) => `<button class="tab" data-look="${i}" aria-pressed="${i === look}">${l.name}${PICK[AB[cur].id] === i ? ' <span style="color:#7dff9a">✓ your pick</span>' : ""}<small style="color:#8f99aa">${l.sub}</small></button>`).join("");
  document.querySelectorAll("[data-look]").forEach(b => b.onclick = () => { look = +b.dataset.look; drawAll(); resetScene(); });
  document.querySelectorAll("[data-step]").forEach(b => b.setAttribute("aria-pressed", +b.dataset.step === step));
}
function drawInfo() {
  const a = AB[cur], [an, ac] = areaStyle(a.area), L = a.looks[look];
  $("info").innerHTML = `<div class="kind" style="color:${ac}">${an} · MECHA ABILITY · BUTTON</div><h2 style="margin-top:4px">${a.name} <span style="color:var(--muted);font-size:15px">(your #${a.n})</span></h2>
    <div class="steps">${a.steps.map((s, i) => `<div class="stp ${i <= step ? "got" : ""} ${i === step ? "cur" : ""}"><span class="b" style="${i <= step ? `background:${ac}` : ""}">${["I", "II", "III", "★"][i]}</span><span>${s}</span></div>`).join("")}</div>
    <p><b>Look ${L.name}:</b> ${L.why}</p><p class="note">${a.note}</p>`;
  $("akey").textContent = a.key; $("aname").textContent = a.name.split(" ")[0].toUpperCase();
}
function drawGlance() {
  $("glance").innerHTML = `<tr><th>#</th><th>Ability</th><th>Area</th><th>Step I</th><th>Upgrades</th><th>Recharge</th></tr>` + AB.map(a => `<tr><td>${a.n}</td><td><b>${a.name}</b></td><td style="color:${areaStyle(a.area)[1]}">${areaStyle(a.area)[0]}</td><td>${a.steps[0].replace(/^Button: /, "").replace(/\. Recharges in .*$|; recharges .*$/, "")}</td><td>${a.steps.slice(1).join(" · ")}</td><td>${(a.steps[0].match(/[Rr]echarges (?:in )?(\d+ s|.*after.*$)/) || ["", ""])[1]}</td></tr>`).join("");
}
function drawAll() { drawTabs(); drawInfo(); }
document.querySelectorAll("[data-step]").forEach(b => b.onclick = () => { step = +b.dataset.step; drawAll(); resetScene(); });
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => { view = b.dataset.view; document.querySelectorAll("[data-view]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
$("play").onclick = () => resetScene();
$("abtn").onclick = () => resetScene();
$("loop").onclick = e => { loop = !loop; e.currentTarget.setAttribute("aria-pressed", loop); };
$("slow").onclick = e => { slow = !slow; e.currentTarget.setAttribute("aria-pressed", slow); };
$("closeup").onclick = e => { closeup = !closeup; e.currentTarget.setAttribute("aria-pressed", closeup); };

// ---------- frame ----------
function resize() { const w = cv.clientWidth, h = cv.clientHeight; renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); }
window.addEventListener("resize", resize);
const CENTER = {grab: [0, 6, 0], mortar: [0, 6, -26], stomp: [0, 6, -6], bellow: [0, 6, 2], challenge: [0, 6, -4], beacon: [6, 6, 4], leap: [0, 8, -26], mud: [0, 6, -4]};
const PARTFOCUS = {grab: ["Tail5_main", 18], mortar: [look => look ? "Torso_hips" : "Tail3_main", 20], stomp: ["ArmL_hand", 16], bellow: ["Neck_upper", 14], challenge: [look => ["Torso_hips", "Torso_chest", "Tail5_main"][look], 22], beacon: ["Torso_barrel", 18], leap: [look => look ? "ShinL_shin" : "LegL_thigh", 16], mud: ["Torso_barrel", 18]};
let last = performance.now();
function frame(now) {
  let dt = Math.min(0.05, (now - last) / 1000); last = now;
  if (slow) dt *= 0.3;
  t += dt;
  const a = AB[cur];
  const [A, txt] = scenario(dt);
  pose(teno, A);
  updateEquip();
  if (a.id === "mud") setMud(clamp01(t / 1.2)); else setMud(0);
  squad.forEach((d, i) => { if (d.g.visible) { pose(d, IDLE(t + i)); squadRings[i].position.set(d.x, 0.12, d.z); } });
  updateFoes(dt);
  updateFx(dt);
  // ability button cooldown
  const cdTotal = +((a.steps[0].match(/Recharges in (\d+) s/) || [0, 0])[1]) || 60;
  const since = Math.max(0, t - 0.5);
  const frac = t < 0.5 ? 0 : clamp01(1 - since * 6 / cdTotal);
  $("cdfill").style.height = (frac * 100) + "%"; $("cdtxt").textContent = frac > 0 ? Math.ceil(frac * cdTotal) + "s" : "";
  if (a.id !== "mud") $("hits").innerHTML = "";
  $("state").textContent = txt;
  // camera
  const c = new THREE.Vector3(...CENTER[a.id]);
  if (a.id === "leap") c.z = Math.min(c.z, teno.z * 0.6 - 4);
  let cp;
  if (closeup) { const pf = PARTFOCUS[a.id]; const pn = typeof pf[0] === "function" ? pf[0](look) : pf[0]; const pp = partPos(teno, pn); c.copy(pp); cp = pp.clone().add(new THREE.Vector3(pf[1], pf[1] * 0.45, pf[1] * 0.35)); }
  else if (view === "side") cp = c.clone().add(new THREE.Vector3(86, 18, 0));
  else if (view === "three") cp = c.clone().add(new THREE.Vector3(62, 38, 52));
  else cp = c.clone().add(new THREE.Vector3(0.01, 110, 18));
  if (shake > 0) { cp.add(new THREE.Vector3((Math.random() - 0.5) * shake * 3, (Math.random() - 0.5) * shake * 3, 0)); shake = Math.max(0, shake - dt * 3); }
  cam.position.copy(cp); cam.lookAt(c);
  renderer.render(scene, cam);
  if (loop && t > a.len + 1.2) resetScene();
  requestAnimationFrame(frame);
}
cur = AB.findIndex(a => a.id === "challenge"); resize(); drawAll(); drawGlance(); resetScene();
requestAnimationFrame(frame);
window.__ready = true;
window.__api = {set: (i, l, s) => { cur = i; look = l || 0; step = s === undefined ? 3 : s; drawAll(); resetScene(); }, seek: tt => { const n = Math.round(tt / 0.02); for (let k = 0; k < n; k++) { t += 0.02; const [A] = scenario(0.02); pose(teno, A); updateEquip(); updateFoes(0.02); updateFx(0.02); } }, view: v => { view = v; }, closeup: v => { closeup = v; }};
