// Teno attacks mockup: tap = Scratch, hold = Tail Slam (3 charges, 8 s each). TENO = TenoModelData 1.0 export, HERRERA = target dummies.
const TENO = __TENO__;
const HERRERA = __HERRERA__;
const $ = id => document.getElementById(id);
const rad = THREE.MathUtils.degToRad;
const OPT = {
  A: {name: "Rear & Crash", sub: "like the video, but bigger", why: "Rears up onto its hind legs with the tail planted like a kickstand, front legs pawing the air while you hold. On release it crashes down chest-first: a shockwave ring, ground cracks, rocks and dust burst out in front, and everything in the cone is launched away.", area: "Cone in front (120°, 22 studs)"},
  B: {name: "Overhead Tail Hammer", sub: "the tail is the weapon", why: "Plants its front legs, hips up, and coils the giant tail up over its back like a scorpion while you hold (the tail glows brighter the longer you hold). On release the tail hammers down over its head into the ground in front: a crater, a tall shockwave, cracks and rocks right where the tip lands.", area: "Circle where the tail tip lands (14 studs), 18-28 studs ahead"},
  C: {name: "Spin Sweep Slam", sub: "hits all around", why: "Crouches and winds the tail around to one side while you hold. On release it spins a full circle with the tail sweeping low, then slams the tail down to finish: a ring shockwave all around it, dust trail along the sweep, everyone nearby launched outward.", area: "Ring all around (28 studs, tail length)"},
};

// ---------- three ----------
const cv = $("cv");
const renderer = new THREE.WebGLRenderer({canvas: cv, antialias: true, preserveDrawingBuffer: true});
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x8fc6e8); scene.fog = new THREE.Fog(0x8fc6e8, 140, 300);
const cam = new THREE.PerspectiveCamera(40, 16 / 9, 0.1, 600);
scene.add(new THREE.HemisphereLight(0xf2f8ff, 0x8a7a5a, 0.85));
const sun = new THREE.DirectionalLight(0xffffff, 0.75); sun.position.set(30, 50, -10); scene.add(sun);
const ground = new THREE.Mesh(new THREE.PlaneGeometry(600, 600), new THREE.MeshLambertMaterial({color: 0xb89f6a}));
ground.rotation.x = -Math.PI / 2; scene.add(ground);
for (let i = 0; i < 120; i++) { // pebbles
  const s = 0.3 + Math.random() * 0.6, p = new THREE.Mesh(new THREE.BoxGeometry(s, s * 0.5, s), new THREE.MeshLambertMaterial({color: i % 3 ? 0x8a7a5a : 0x6a5c44}));
  p.position.set((Math.random() - 0.5) * 140, s * 0.2, (Math.random() - 0.5) * 140); scene.add(p);
}
function cfm(a) { const m = new THREE.Matrix4(); m.set(a[3], a[4], a[5], a[0], a[6], a[7], a[8], a[1], a[9], a[10], a[11], a[2], 0, 0, 0, 1); return m; }
const tmpE = new THREE.Euler();
function rot(p, y, r) { tmpE.set(rad(r), rad(y), rad(p), "ZYX"); return new THREE.Matrix4().makeRotationFromEuler(tmpE); }
function buildDino(D, scale) {
  const g = new THREE.Group(); scene.add(g);
  const segs = {}, parts = [], byName = {};
  for (const s of D.segs) {
    const rootInv = cfm(s.root).invert(); segs[s.n] = [];
    for (const p of s.parts) {
      const mat = new THREE.MeshLambertMaterial({color: parseInt(p.c, 16), emissive: 0x000000});
      const m = new THREE.Mesh(new THREE.BoxGeometry(p.s[0], p.s[1], p.s[2]), mat); m.matrixAutoUpdate = false; g.add(m);
      const info = {mesh: m, local: rootInv.clone().multiply(cfm(p.cf)), size: p.s, seg: s.n, name: p.n}; segs[s.n].push(info); parts.push(info); byName[p.n] = info;
    }
  }
  const joints = D.joints.map(j => ({n: j.n, p0: j.p0, p1: j.p1, c0: cfm(j.c0), c1inv: cfm(j.c1).invert()}));
  return {D, g, segs, parts, byName, joints, scale, x: 0, y: 0, z: 0, yaw: 0, roll: 0, pitchW: 0};
}
const corner = new THREE.Vector3();
function pose(d, A, ground_) {
  const W = {HRP: new THREE.Matrix4().makeRotationY(d.yaw).multiply(new THREE.Matrix4().makeRotationX(d.pitchW || 0)).multiply(new THREE.Matrix4().makeRotationZ(d.roll || 0))};
  for (const j of d.joints) { const v = A[j.n] || [0, 0, 0]; W[j.p1] = W[j.p0].clone().multiply(j.c0).multiply(rot(v[0], v[1], v[2])).multiply(j.c1inv); }
  const S = new THREE.Matrix4().makeScale(d.scale, d.scale, d.scale);
  let minY = Infinity;
  for (const n in d.segs) for (const p of d.segs[n]) {
    const m = S.clone().multiply(W[n]).multiply(p.local); p.mesh.matrix.copy(m);
    for (let i = 0; i < 8; i++) { corner.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(m); minY = Math.min(minY, corner.y); }
  }
  const lift = new THREE.Matrix4().makeTranslation(d.x, (ground_ === false ? 0 : -minY) + d.y, d.z);
  for (const p of d.parts) p.mesh.matrix.premultiply(lift);
}
function partPos(d, name, local) { return new THREE.Vector3(...(local || [0, 0, 0])).applyMatrix4(d.byName[name].mesh.matrix); }

// ---------- actors ----------
const teno = buildDino(TENO, 2);
const targets = [
  {x: 0, z: -34}, {x: -16, z: -26}, {x: 18, z: -12}, {x: -14, z: 22},
].map((p, i) => { const d = buildDino(HERRERA, 2); d.home = p; d.yaw = Math.PI * (i === 3 ? 0.3 : 1) + (i - 1) * 0.3; return Object.assign(d, {x: p.x, z: p.z, vx: 0, vy: 0, vz: 0, spin: 0, stun: 0, hp: 40, hit: false}); });
const HPOSE = {RootJoint: [-24, 0, 0], Neck: [6, 0, 0], Head: [16, 0, 0], Jaw: [-3, 0, 0], ArmL: [30, 0, -18], ArmR: [30, 0, 18],
  LegL: [48, 0, -16], LegR: [48, 0, 16], KneeL: [-48, 0, 0], KneeR: [-48, 0, 0], AnkleL: [24, 0, 0], AnkleR: [24, 0, 0],
  Tail1: [26, 0, 0], Tail2: [4, 0, 0], Tail3: [8, 0, 0], Tail4: [14, 0, 0], Tail5: [20, 0, 0]};

// ---------- effects ----------
const fx = [];
function addFx(o) { fx.push(o); return o; }
const DUST = 0xcbb487, ROCK = 0x7a6a50, CRACK = 0x3a2e22, WAVE = 0xfff1c8, GLOW = 0xffd24a;
function dust(pos, n, spread, up, size) {
  for (let i = 0; i < n; i++) {
    const m = new THREE.Mesh(new THREE.IcosahedronGeometry(size * (0.6 + Math.random() * 0.8), 0), new THREE.MeshLambertMaterial({color: DUST, transparent: true, opacity: 0.85}));
    const a = Math.random() * Math.PI * 2, r = Math.random() * spread * 0.4;
    m.position.set(pos.x + Math.cos(a) * r, pos.y + 0.5, pos.z + Math.sin(a) * r); scene.add(m);
    addFx({m, t: 0, life: 1.1 + Math.random() * 0.6, v: new THREE.Vector3(Math.cos(a) * spread * (0.6 + Math.random()), up * (0.5 + Math.random()), Math.sin(a) * spread * (0.6 + Math.random())), grow: 1.8, kind: "dust"});
  }
}
function rocks(pos, n, speed) {
  for (let i = 0; i < n; i++) {
    const s = 0.4 + Math.random() * 0.9, m = new THREE.Mesh(new THREE.BoxGeometry(s, s, s), new THREE.MeshLambertMaterial({color: i % 2 ? ROCK : 0x5c4e3a}));
    const a = Math.random() * Math.PI * 2; m.position.copy(pos).add(new THREE.Vector3(0, 0.5, 0)); scene.add(m);
    addFx({m, t: 0, life: 1.6, v: new THREE.Vector3(Math.cos(a) * speed * Math.random(), speed * (0.8 + Math.random()), Math.sin(a) * speed * Math.random()), g: 60, spinv: new THREE.Vector3(Math.random() * 10, Math.random() * 10, 0), kind: "rock"});
  }
}
function ring(pos, r0, r1, life, color, h) {
  const m = new THREE.Mesh(new THREE.RingGeometry(0.85, 1, 48), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0.9, side: THREE.DoubleSide}));
  m.rotation.x = -Math.PI / 2; m.position.set(pos.x, (h || 0.15), pos.z); scene.add(m);
  addFx({m, t: 0, life, r0, r1, kind: "ring"});
  const wall = new THREE.Mesh(new THREE.CylinderGeometry(1, 1, 1, 48, 1, true), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0.35, side: THREE.DoubleSide}));
  wall.position.set(pos.x, 0, pos.z); scene.add(wall);
  addFx({m: wall, t: 0, life: life * 0.8, r0, r1, kind: "wall"});
}
function cracks(pos, n, len, cone) {
  for (let i = 0; i < n; i++) {
    const a = cone ? cone[0] + (Math.random() - 0.5) * cone[1] : Math.random() * Math.PI * 2;
    let p = pos.clone(), ang = a;
    for (let k = 0; k < 3; k++) {
      const L = len * (0.4 + Math.random() * 0.4) / (k + 1);
      const m = new THREE.Mesh(new THREE.BoxGeometry(0.45 / (k + 1) + 0.15, 0.06, L), new THREE.MeshBasicMaterial({color: CRACK, transparent: true, opacity: 1}));
      const dir = new THREE.Vector3(Math.sin(ang), 0, Math.cos(ang));
      m.position.copy(p).add(dir.clone().multiplyScalar(L / 2)); m.position.y = 0.05; m.rotation.y = ang; scene.add(m);
      addFx({m, t: 0, life: 2.4, kind: "crack", delay: k * 0.04});
      p.add(dir.multiplyScalar(L)); ang += (Math.random() - 0.5) * 0.9;
    }
  }
}
function flash(pos, size) {
  const m = new THREE.Mesh(new THREE.SphereGeometry(1, 16, 12), new THREE.MeshBasicMaterial({color: 0xffffff, transparent: true, opacity: 0.9}));
  m.position.copy(pos).add(new THREE.Vector3(0, 1, 0)); scene.add(m); addFx({m, t: 0, life: 0.22, size, kind: "flash"});
}
function claws(from, dir) { // 3 bright claw streaks
  for (let i = 0; i < 3; i++) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(0.25, 0.25, 6), new THREE.MeshBasicMaterial({color: 0xfff0b0, transparent: true, opacity: 1}));
    m.position.copy(from).add(new THREE.Vector3(0, 2 + i * 1.1, 0)); m.lookAt(m.position.clone().add(dir)); m.rotateX(-0.6); m.rotateY((i - 1) * 0.1);
    scene.add(m); addFx({m, t: 0, life: 0.3, kind: "streak", delay: i * 0.03});
  }
}
const pops = $("pops");
function popNum(pos, txt, big) {
  const el = document.createElement("div"); el.className = "pop" + (big ? " big" : ""); el.textContent = txt; pops.appendChild(el);
  addFx({el, pos: pos.clone().add(new THREE.Vector3(0, 8, 0)), t: 0, life: 1.0, kind: "pop"});
}
let shake = 0, hitStop = 0, slow = false;
function updateFx(dt) {
  for (let i = fx.length - 1; i >= 0; i--) {
    const f = fx[i];
    if (f.delay > 0) { f.delay -= dt; if (f.m) f.m.visible = false; continue; } else if (f.m) f.m.visible = true;
    f.t += dt; const u = f.t / f.life;
    if (u >= 1) { if (f.m) { scene.remove(f.m); f.m.geometry.dispose(); } if (f.el) f.el.remove(); fx.splice(i, 1); continue; }
    if (f.kind === "dust") { f.m.position.addScaledVector(f.v, dt); f.v.multiplyScalar(1 - dt * 2.2); f.m.scale.setScalar(1 + u * f.grow); f.m.material.opacity = 0.85 * (1 - u); }
    else if (f.kind === "rock") { f.v.y -= f.g * dt; f.m.position.addScaledVector(f.v, dt); if (f.m.position.y < 0.3) { f.m.position.y = 0.3; f.v.multiplyScalar(0.4); f.v.y = Math.abs(f.v.y) * 0.3; } f.m.rotation.x += f.spinv.x * dt; f.m.rotation.y += f.spinv.y * dt; }
    else if (f.kind === "ring") { const r = f.r0 + (f.r1 - f.r0) * (1 - Math.pow(1 - u, 3)); f.m.scale.set(r, r, r); f.m.material.opacity = 0.9 * (1 - u); }
    else if (f.kind === "wall") { const r = f.r0 + (f.r1 - f.r0) * (1 - Math.pow(1 - u, 3)); f.m.scale.set(r, 6 * (1 - u) + 0.5, r); f.m.position.y = 3 * (1 - u); f.m.material.opacity = 0.35 * (1 - u); }
    else if (f.kind === "crack") { f.m.material.opacity = u < 0.7 ? 1 : (1 - u) / 0.3; }
    else if (f.kind === "flash") { f.m.scale.setScalar(f.size * (0.4 + u)); f.m.material.opacity = 0.9 * (1 - u); }
    else if (f.kind === "streak") { f.m.material.opacity = 1 - u; f.m.scale.z = 0.4 + u; }
    else if (f.kind === "pop") { const p = f.pos.clone().add(new THREE.Vector3(0, u * 5, 0)).project(cam); f.el.style.left = ((p.x + 1) / 2 * 100) + "%"; f.el.style.top = ((1 - p.y) / 2 * 100) + "%"; f.el.style.opacity = u < 0.7 ? 1 : (1 - u) / 0.3; }
  }
}

// ---------- the teno's moves (angles in degrees per joint) ----------
const lerp = (a, b, u) => a + (b - a) * u, clamp01 = u => Math.max(0, Math.min(1, u));
const ease = u => 1 - Math.pow(1 - clamp01(u), 3), easeIn = u => Math.pow(clamp01(u), 2.2);
function mix(A, B, u) { const o = {}; for (const k of new Set([...Object.keys(A), ...Object.keys(B)])) { const a = A[k] || [0, 0, 0], b = B[k] || [0, 0, 0]; o[k] = [lerp(a[0], b[0], u), lerp(a[1], b[1], u), lerp(a[2], b[2], u)]; } return o; }
const IDLE = t => ({Neck: [Math.sin(t * 1.3) * 3, Math.sin(t * 0.5) * 6, 0], Head: [Math.sin(t * 1.3 + 1) * 3, 0, 0], Tail1: [0, Math.sin(t * 0.8) * 4, 0], Tail2: [0, Math.sin(t * 0.8 - 0.5) * 5, 0], Tail3: [0, Math.sin(t * 0.8 - 1) * 6, 0], Tail4: [0, Math.sin(t * 0.8 - 1.5) * 7, 0], Tail5: [0, Math.sin(t * 0.8 - 2) * 8, 0]});
// A: rear up (body pitch up about the hips, legs counter-rotated so they stay down, tail flattened as a prop), crash forward
const A_UP = {RootJoint: [52, 0, 0], LegL: [-52, 0, 0], LegR: [-52, 0, 0], Neck: [10, 0, 0], Head: [-10, 0, 0], Jaw: [-22, 0, 0], ArmL: [70, 0, 0], ArmR: [55, 0, 0], Tail1: [-46, 0, 0], Tail2: [-6, 0, 0], Tail3: [4, 0, 0], Tail4: [0, 0, 0], Tail5: [-20, 0, 0]};
const A_DOWN = {RootJoint: [-16, 0, 0], LegL: [16, 0, 0], LegR: [16, 0, 0], Neck: [-14, 0, 0], Head: [-16, 0, 0], Jaw: [-10, 0, 0], ArmL: [-10, 0, 0], ArmR: [-10, 0, 0], Tail1: [-26, 0, 0], Tail2: [-18, 0, 0], Tail3: [-14, 0, 0], Tail4: [-10, 0, 0], Tail5: [-10, 0, 0]};
// B: hips up, tail coiled up over the back (scorpion), then hammered over the head
const B_UP = {RootJoint: [-14, 0, 0], LegL: [14, 0, 0], LegR: [14, 0, 0], ArmL: [-8, 0, 0], ArmR: [-8, 0, 0], Neck: [-20, 0, 0], Head: [22, 0, 0], Tail1: [-62, 0, 0], Tail2: [-48, 0, 0], Tail3: [-44, 0, 0], Tail4: [-36, 0, 0], Tail5: [-20, 0, 0]};
const B_DOWN = {RootJoint: [-18, 0, 0], LegL: [18, 0, 0], LegR: [18, 0, 0], ArmL: [-6, 0, 0], ArmR: [-6, 0, 0], Neck: [-30, 6, 0], Head: [10, 0, 0], Tail1: [-82, 0, 0], Tail2: [-50, 0, 0], Tail3: [-46, 0, 0], Tail4: [-34, 0, 0], Tail5: [-14, 0, 0]};
// C: crouch, tail wound to the side; spin; tail slams down
const C_UP = {RootJoint: [-6, -30, 0], LegL: [6, 0, 0], LegR: [6, 0, 0], Neck: [-6, -30, 0], Head: [0, -20, 0], Tail1: [-8, 30, 0], Tail2: [0, 25, 0], Tail3: [0, 20, 0], Tail4: [0, 15, 0], Tail5: [0, 10, 0], ArmL: [10, 0, 0], ArmR: [10, 0, 0]};
const C_SWEEP = {RootJoint: [0, 0, 0], Neck: [-6, 20, 0], Head: [0, 10, 0], Tail1: [-10, -10, 0], Tail2: [4, -12, 0], Tail3: [4, -14, 0], Tail4: [4, -16, 0], Tail5: [4, -18, 0]};
const C_SLAM = {RootJoint: [10, 0, 0], LegL: [-10, 0, 0], LegR: [-10, 0, 0], Neck: [-10, 0, 0], Tail1: [-30, 0, 0], Tail2: [14, 0, 0], Tail3: [14, 0, 0], Tail4: [12, 0, 0], Tail5: [10, 0, 0]};
const SCRATCH_UP = {ArmR: [95, 0, 30], Neck: [4, -10, 0], Head: [6, 0, 0], RootJoint: [8, 0, 0], LegL: [-8, 0, 0], LegR: [-8, 0, 0], Jaw: [-14, 0, 0]};
const SCRATCH_DOWN = {ArmR: [-20, 0, -10], Neck: [-6, 6, 0], Head: [-6, 0, 0], RootJoint: [-4, 0, 0], LegL: [4, 0, 0], LegR: [4, 0, 0]};

// jump: J1 heavy hop (crouch, spring, tail counterbalances, front-first landing); J2 rearing leap (rear up, launch forward, land on all fours)
const J_CROUCH = {RootJoint: [-8, 0, 0], LegL: [30, 0, 0], LegR: [30, 0, 0], KneeL: [-40, 0, 0], KneeR: [-40, 0, 0], AnkleL: [12, 0, 0], AnkleR: [12, 0, 0], ArmL: [-25, 0, 0], ArmR: [-25, 0, 0], Neck: [-10, 0, 0], Tail1: [8, 0, 0], Tail2: [6, 0, 0]};
const J_AIR = {RootJoint: [10, 0, 0], LegL: [-30, 0, 0], LegR: [-30, 0, 0], KneeL: [-20, 0, 0], KneeR: [-20, 0, 0], ArmL: [55, 0, 0], ArmR: [55, 0, 0], Neck: [12, 0, 0], Head: [-6, 0, 0], Jaw: [-18, 0, 0], Tail1: [-16, 0, 0], Tail2: [-10, 0, 0], Tail3: [-8, 0, 0], Tail4: [-6, 0, 0], Tail5: [-6, 0, 0]};
const J_REAR = {RootJoint: [40, 0, 0], LegL: [-40, 0, 0], LegR: [-40, 0, 0], KneeL: [-30, 0, 0], KneeR: [-30, 0, 0], ArmL: [60, 0, 0], ArmR: [60, 0, 0], Neck: [12, 0, 0], Tail1: [-30, 0, 0], Tail2: [0, 0, 0], Tail5: [-12, 0, 0]};
const J_LAND = {RootJoint: [-10, 0, 0], LegL: [24, 0, 0], LegR: [24, 0, 0], KneeL: [-30, 0, 0], KneeR: [-30, 0, 0], ArmL: [-20, 0, 0], ArmR: [-20, 0, 0], Neck: [-14, 0, 0], Head: [-8, 0, 0], Tail1: [10, 0, 0], Tail2: [8, 0, 0], Tail3: [6, 0, 0]};
let jopt = "J1", jumpY = 0;
document.querySelectorAll("[data-jump]").forEach(b => b.onclick = () => { jopt = b.dataset.jump; document.querySelectorAll("[data-jump]").forEach(x => x.setAttribute("aria-pressed", x === b)); if (state === "idle") { state = "jump"; st = 0; impactDone = false; } });
function jumpAngles(t, A) {
  const H = 9; // studs of hop at game size
  if (jopt === "J1") {
    const T0 = 0.18, TA = 0.6, TL = 0.35;
    if (st < T0) { jumpY = 0; return mix(A, J_CROUCH, ease(st / T0)); }
    if (st < T0 + TA) { const u = (st - T0) / TA; jumpY = H * 4 * u * (1 - u); if (st - T0 < 0.02) dust(new THREE.Vector3(teno.x, 0, teno.z + 4), 6, 6, 3, 1.2); return mix(J_CROUCH, J_AIR, ease(u * 2.5)); }
    if (st < T0 + TA + TL) { jumpY = 0; if (!impactDone) { impactDone = true; shake = 0.6; ring(new THREE.Vector3(teno.x, 0, teno.z - 4), 2, 12, 0.5, WAVE); dust(new THREE.Vector3(teno.x, 0, teno.z - 4), 12, 9, 3, 1.4); } const u = (st - T0 - TA) / TL; return mix(u < 0.3 ? mix(J_AIR, J_LAND, u / 0.3) : J_LAND, A, u < 0.3 ? 0 : ease((u - 0.3) / 0.7)); }
  } else {
    const T0 = 0.28, TA = 0.62, TL = 0.4;
    if (st < T0) { jumpY = 0; return mix(A, J_REAR, ease(st / T0)); }
    if (st < T0 + TA) { const u = (st - T0) / TA; jumpY = H * 1.15 * 4 * u * (1 - u); if (st - T0 < 0.02) dust(new THREE.Vector3(teno.x, 0, teno.z + 4), 8, 7, 3, 1.3); return mix(J_REAR, J_AIR, ease(u * 1.8)); }
    if (st < T0 + TA + TL) { jumpY = 0; if (!impactDone) { impactDone = true; shake = 0.8; ring(new THREE.Vector3(teno.x, 0, teno.z - 2), 2, 14, 0.55, WAVE); dust(new THREE.Vector3(teno.x, 0, teno.z - 2), 16, 10, 3, 1.5); rocks(new THREE.Vector3(teno.x, 0, teno.z - 2), 6, 14); } const u = (st - T0 - TA) / TL; return mix(u < 0.3 ? mix(J_AIR, J_LAND, u / 0.3) : J_LAND, A, u < 0.3 ? 0 : ease((u - 0.3) / 0.7)); }
  }
  state = "idle"; jumpY = 0; return A;
}

// ---------- state ----------
let opt = "A", state = "idle", st = 0, hold = 0, charges = 3, rechargeT = 0, tGlobal = 0, view = "behind", impactDone = false, spinYaw = 0;
const RECHARGE = 8, HOLD_MIN = 0.22, MAX_HOLD = 1.0;
const glowRing = new THREE.Mesh(new THREE.RingGeometry(0.8, 1, 48), new THREE.MeshBasicMaterial({color: GLOW, transparent: true, opacity: 0, side: THREE.DoubleSide}));
glowRing.rotation.x = -Math.PI / 2; glowRing.position.y = 0.2; scene.add(glowRing);
function setGlow(k) { for (const p of teno.parts) if (/Tail|Arm|Torso_band|scute/.test(p.name)) p.mesh.material.emissive.setRGB(k * 1.0, k * 0.75, k * 0.15); }

function tenoFront() { return new THREE.Vector3(teno.x, 0, teno.z).add(new THREE.Vector3(-Math.sin(teno.yaw), 0, -Math.cos(teno.yaw)).multiplyScalar(1)); }
function forward() { return new THREE.Vector3(-Math.sin(teno.yaw), 0, -Math.cos(teno.yaw)); }
function hitTargets(center, radius, coneDir, coneDeg, dmg, launch, big) {
  for (const d of targets) {
    if (d.stun > 0.4) continue;
    const to = new THREE.Vector3(d.x - center.x, 0, d.z - center.z), dist = to.length();
    if (dist > radius) continue;
    if (coneDir && to.clone().normalize().dot(coneDir) < Math.cos(rad(coneDeg / 2))) continue;
    const dir = to.lengthSq() > 0.01 ? to.normalize() : forward();
    d.vx = dir.x * launch; d.vz = dir.z * launch; d.vy = launch * 0.9; d.spin = (Math.random() > 0.5 ? 1 : -1) * 9; d.stun = big ? 1.4 : 0.35; d.airborne = big;
    d.hp = Math.max(0, d.hp - dmg); popNum(new THREE.Vector3(d.x, 0, d.z), "-" + dmg, big);
    if (big) { dust(new THREE.Vector3(d.x, 0, d.z), 6, 6, 4, 1.2); }
  }
}
function slamImpact(point, kind) {
  hitStop = 0.09; shake = kind === "B" ? 1.7 : 1.3; impactDone = true;
  flash(point, kind === "B" ? 9 : 7);
  ring(point, 2, kind === "C" ? 30 : 24, 0.7, WAVE); ring(point, 1, kind === "C" ? 20 : 16, 0.9, 0xffd24a, 0.25);
  dust(point, 26, 18, 7, 1.8); rocks(point, 18, 26);
  const f = forward();
  if (kind === "A") { cracks(point, 7, 14, [Math.atan2(f.x, f.z), 2.2]); hitTargets(point, 24, f, 130, 40, 34, true); }
  if (kind === "B") { cracks(point, 10, 12); hitTargets(point, 15, null, 0, 40, 38, true); }
  if (kind === "C") { cracks(point, 12, 13); hitTargets(new THREE.Vector3(teno.x, 0, teno.z), 30, null, 0, 40, 30, true); }
  $("hud").classList.add("bang"); setTimeout(() => $("hud").classList.remove("bang"), 180);
}
function useCharge() { if (charges <= 0) return false; charges--; if (rechargeT <= 0) rechargeT = RECHARGE; return true; }

function startScratch() { if (state !== "idle") return; state = "scratch"; st = 0; impactDone = false; }
function startHold() { if (state !== "idle") return; if (charges <= 0) { flashNoCharge(); return; } state = "hold"; st = 0; hold = 0; impactDone = false; }
function release() {
  if (state === "hold") {
    if (hold < HOLD_MIN) { state = "scratch"; st = 0; return; } // tap = scratch
    if (!useCharge()) { state = "idle"; return; }
    state = "slam"; st = 0; impactDone = false; spinYaw = 0;
  }
}
function flashNoCharge() { const e = $("pips"); e.classList.add("empty"); setTimeout(() => e.classList.remove("empty"), 300); }

// input: tap / hold on the button, mouse anywhere on the stage, Space key
const atk = $("atk");
let pressAt = -1;
function down() { pressAt = performance.now(); if (state === "idle") { state = "hold"; st = 0; hold = 0; } }
function up() { if (state === "hold") { if (hold < HOLD_MIN) { state = "scratch"; st = 0; impactDone = false; } else if (useCharge()) { state = "slam"; st = 0; impactDone = false; spinYaw = 0; } else { state = "idle"; flashNoCharge(); } } }
atk.addEventListener("pointerdown", e => { e.preventDefault(); down(); });
window.addEventListener("pointerup", up);
window.addEventListener("keydown", e => { if (e.code === "Space" && !e.repeat) { e.preventDefault(); down(); } });
window.addEventListener("keyup", e => { if (e.code === "Space") up(); });
$("demoScratch").onclick = () => { if (state === "idle") { state = "scratch"; st = 0; impactDone = false; } };
$("demoSlam").onclick = () => { if (state === "idle" && charges > 0) { state = "hold"; st = 0; hold = 0; autoRelease = 0.9; } else flashNoCharge(); };
let autoRelease = -1;
$("slow").onclick = e => { slow = !slow; e.currentTarget.setAttribute("aria-pressed", slow); };
$("reset").onclick = () => { charges = 3; rechargeT = 0; for (const d of targets) Object.assign(d, {x: d.home.x, z: d.home.z, y: 0, vx: 0, vy: 0, vz: 0, stun: 0, hp: 40, airborne: false}); };
document.querySelectorAll("[data-opt]").forEach(b => b.onclick = () => { opt = b.dataset.opt; drawInfo(); });
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => { view = b.dataset.view; document.querySelectorAll("[data-view]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
function drawInfo() {
  document.querySelectorAll("[data-opt]").forEach(b => b.setAttribute("aria-pressed", b.dataset.opt === opt));
  const o = OPT[opt];
  $("info").innerHTML = `<h2>${opt} · ${o.name}</h2><p class="sub">${o.sub}</p><p>${o.why}</p><p><b>Hits:</b> ${o.area}</p>`;
}

function tenoAngles(dt) {
  const t = tGlobal;
  let A = IDLE(t);
  if (state === "jump") { st += dt; return jumpAngles(t, A); }
  if (state === "scratch") {
    st += dt; const T1 = 0.12, T2 = 0.1, T3 = 0.25;
    if (st < T1) A = mix(A, SCRATCH_UP, ease(st / T1));
    else if (st < T1 + T2) { A = mix(SCRATCH_UP, SCRATCH_DOWN, easeIn((st - T1) / T2)); if (!impactDone && st - T1 > T2 * 0.5) { impactDone = true; const p = partPos(teno, "ArmR_hand"); claws(p, forward()); hitTargets(new THREE.Vector3(p.x, 0, p.z).add(forward().multiplyScalar(6)), 11, null, 0, 8, 7, false); shake = 0.25; } }
    else if (st < T1 + T2 + T3) A = mix(SCRATCH_DOWN, IDLE(t), ease((st - T1 - T2) / T3));
    else state = "idle";
  } else if (state === "hold") {
    st += dt; hold = Math.min(MAX_HOLD, hold + dt);
    if (autoRelease > 0 && st >= autoRelease) { autoRelease = -1; if (useCharge()) { state = "slam"; st = 0; impactDone = false; spinYaw = 0; } else state = "idle"; }
    const u = ease(hold / 0.55), jitter = Math.sin(t * 40) * hold * 1.5;
    const UP = opt === "A" ? A_UP : opt === "B" ? B_UP : C_UP;
    A = mix(IDLE(t), UP, hold < HOLD_MIN ? 0 : u);
    if (hold >= HOLD_MIN) { A.ArmL = [A.ArmL[0] + (opt === "A" ? Math.sin(t * 14) * 18 : 0), A.ArmL[1], A.ArmL[2]]; A.ArmR = [A.ArmR[0] + (opt === "A" ? Math.sin(t * 14 + 2) * 18 : 0), A.ArmR[1], A.ArmR[2]]; A.Tail5 = [A.Tail5[0] + jitter, A.Tail5[1], 0]; }
  } else if (state === "slam") {
    st += dt;
    const UP = opt === "A" ? A_UP : opt === "B" ? B_UP : C_UP, DOWN = opt === "A" ? A_DOWN : opt === "B" ? B_DOWN : C_SLAM;
    if (opt === "C") {
      const TS = 0.45, TD = 0.14;
      if (st < TS) { const u = st / TS; spinYaw = -u * Math.PI * 2; A = mix(UP, C_SWEEP, ease(u * 3)); if (Math.random() < 0.6) { const tip = partPos(teno, "Tail5_main"); dust(new THREE.Vector3(tip.x, 0, tip.z), 1, 3, 2, 1); } }
      else if (st < TS + TD) { spinYaw = -Math.PI * 2; A = mix(C_SWEEP, DOWN, easeIn((st - TS) / TD)); }
      else { if (!impactDone) { const tip = partPos(teno, "Tail4_main"); slamImpact(new THREE.Vector3(tip.x, 0, tip.z), "C"); } A = mix(DOWN, IDLE(t), ease((st - TS - TD) / 0.6)); if (st > TS + TD + 0.6) { state = "idle"; spinYaw = 0; } }
    } else {
      const TD = opt === "B" ? 0.2 : 0.16;
      if (st < TD) A = mix(UP, DOWN, easeIn(st / TD));
      else {
        if (!impactDone) {
          let p;
          if (opt === "A") { p = partPos(teno, "ArmL_hand").add(partPos(teno, "ArmR_hand")).multiplyScalar(0.5).add(forward().multiplyScalar(4)); }
          else { p = partPos(teno, "Tail5_main"); }
          slamImpact(new THREE.Vector3(p.x, 0, p.z), opt);
        }
        const r = (st - TD) / 0.7; A = mix(DOWN, IDLE(t), ease(r)); if (r >= 1) state = "idle";
      }
    }
  }
  return A;
}

function resize() { const w = cv.clientWidth, h = cv.clientHeight; renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); }
window.addEventListener("resize", resize);
let last = performance.now();
function frame(now) {
  let dt = Math.min(0.05, (now - last) / 1000); last = now;
  if (slow) dt *= 0.25;
  if (hitStop > 0) { hitStop -= dt; dt = 0.0001; }
  tGlobal += dt;
  // recharge (one charge at a time, 8 s each)
  if (charges < 3) { rechargeT -= dt; if (rechargeT <= 0) { charges++; rechargeT = charges < 3 ? RECHARGE : 0; } }
  const A = tenoAngles(dt);
  teno.yaw = spinYaw; teno.y = jumpY;
  pose(teno, A);
  // charge glow
  const g = state === "hold" && hold >= HOLD_MIN ? clamp01((hold - HOLD_MIN) / 0.5) : 0;
  setGlow(g * (0.55 + 0.45 * Math.sin(tGlobal * 18) * 0.5));
  glowRing.material.opacity = g * 0.8; glowRing.scale.setScalar(6 + g * 6 + Math.sin(tGlobal * 10) * 0.6);
  // targets
  for (const d of targets) {
    if (d.airborne || d.vy !== 0 || Math.abs(d.vx) > 0.01) {
      d.vy -= 70 * dt; d.x += d.vx * dt; d.z += d.vz * dt; d.y = (d.y || 0) + d.vy * dt; d.roll += d.spin * dt;
      if (d.y <= 0) { d.y = 0; if (d.vy < -20) dust(new THREE.Vector3(d.x, 0, d.z), 4, 5, 3, 1); d.vy = 0; d.vx *= 0.5; d.vz *= 0.5; if (Math.abs(d.vx) < 0.5) { d.vx = d.vz = 0; d.airborne = false; } }
    }
    if (!d.airborne && d.y <= 0) d.roll *= 0.85;
    d.stun = Math.max(0, d.stun - dt);
    const a = Object.assign({}, HPOSE); if (d.stun > 0) a.Head = [16 + Math.sin(tGlobal * 20) * 10, 0, 0];
    pose(d, a, d.y > 0 ? true : true);
    if (d.y > 0) for (const p of d.parts) p.mesh.matrix.premultiply(new THREE.Matrix4().makeTranslation(0, d.y, 0));
  }
  updateFx(dt);
  // camera
  const tgt = new THREE.Vector3(0, 6, -6);
  let cp;
  if (view === "behind") cp = new THREE.Vector3(10, 26, 58);
  else if (view === "side") cp = new THREE.Vector3(68, 14, -4);
  else cp = new THREE.Vector3(52, 30, -48);
  if (shake > 0) { cp.add(new THREE.Vector3((Math.random() - 0.5) * shake * 3, (Math.random() - 0.5) * shake * 3, (Math.random() - 0.5) * shake * 3)); shake = Math.max(0, shake - dt * 3); }
  cam.position.copy(cp); cam.lookAt(tgt);
  renderer.render(scene, cam);
  // HUD
  $("pips").innerHTML = [0, 1, 2].map(i => `<i class="${i < charges ? "on" : ""}"></i>`).join("");
  $("cd").textContent = charges < 3 ? `next in ${Math.max(0, rechargeT).toFixed(1)} s` : "full";
  $("holdbar").style.width = (state === "hold" ? clamp01(hold / 0.55) * 100 : 0) + "%";
  $("state").textContent = state === "jump" ? "jump" : state === "hold" ? (hold < HOLD_MIN ? "tap = scratch" : "SLAM charging... release!") : state === "slam" ? "TAIL SLAM" : state === "scratch" ? "scratch" : "hold to slam · tap to scratch";
  requestAnimationFrame(frame);
}
resize(); drawInfo();
requestAnimationFrame(frame);
window.__api = {demo: (o, t) => { opt = o; drawInfo(); state = "hold"; st = 0; hold = 0; autoRelease = t || 0.9; }, scratch: () => { state = "scratch"; st = 0; impactDone = false; }, state: () => ({state, st, hold, charges, opt})};
