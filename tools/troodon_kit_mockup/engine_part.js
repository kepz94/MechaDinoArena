const $ = id => document.getElementById(id);
const rad = THREE.MathUtils.degToRad, deg = THREE.MathUtils.radToDeg;
const cv = $("cv");
const renderer = new THREE.WebGLRenderer({canvas: cv, antialias: true, preserveDrawingBuffer: true});
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
const scene = new THREE.Scene();
const SKY = 0x8cc3e6;
scene.background = new THREE.Color(SKY); scene.fog = new THREE.Fog(SKY, 170, 420);
const cam = new THREE.PerspectiveCamera(38, 16 / 9, 0.5, 900);
scene.add(new THREE.HemisphereLight(0xdfeeff, 0x4f6a33, 0.62));
const sun = new THREE.DirectionalLight(0xfff1d6, 0.8); sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048); Object.assign(sun.shadow.camera, {left: -80, right: 80, top: 80, bottom: -80, near: 1, far: 240});
sun.shadow.bias = -0.0006; scene.add(sun); scene.add(sun.target);
const fill = new THREE.DirectionalLight(0xbfd9ff, 0.28); fill.position.set(-40, 20, -30); scene.add(fill);

// ---------- ground + props ----------
function noiseTex(base, spread, n) {
  const c = document.createElement("canvas"); c.width = c.height = 256; const x = c.getContext("2d");
  x.fillStyle = base; x.fillRect(0, 0, 256, 256);
  for (let i = 0; i < n; i++) { const v = (Math.random() - .5) * spread; x.fillStyle = `rgba(${v > 0 ? 255 : 0},${v > 0 ? 255 : 0},${v > 0 ? 200 : 0},${Math.abs(v)})`; x.fillRect(Math.random() * 256, Math.random() * 256, 2 + Math.random() * 6, 2 + Math.random() * 6); }
  const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; return t;
}
const gTex = noiseTex("#5f9a40", 0.16, 2600); gTex.repeat.set(60, 60);
const ground = new THREE.Mesh(new THREE.PlaneGeometry(1000, 1000), new THREE.MeshLambertMaterial({map: gTex}));
ground.rotation.x = -Math.PI / 2; ground.receiveShadow = true; scene.add(ground);
const sTex = noiseTex("#c2ad7a", 0.14, 1800); sTex.repeat.set(8, 8);
const arena = new THREE.Mesh(new THREE.CircleGeometry(95, 56), new THREE.MeshLambertMaterial({map: sTex}));
arena.rotation.x = -Math.PI / 2; arena.position.set(0, 0.03, -25); arena.receiveShadow = true; scene.add(arena);
const propMat = new THREE.MeshLambertMaterial({color: 0x8d8f99}), trunkMat = new THREE.MeshLambertMaterial({color: 0x8a6a45}), leafMat = new THREE.MeshLambertMaterial({color: 0x3f8f3a});
function box(w, h, d, m, x, y, z, ry) { const b = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m); b.position.set(x, y, z); b.rotation.y = ry || 0; b.castShadow = b.receiveShadow = true; scene.add(b); return b; }
[[-80, -60, 14, 9], [75, -110, 18, 12], [-105, 30, 22, 15], [95, 15, 12, 8], [-30, -150, 26, 14], [40, 110, 16, 10], [120, -60, 20, 13]].forEach(([x, z, w, h], i) => { box(w, h, w * 0.8, propMat, x, h / 2, z, i); box(w * 0.6, h * 0.5, w * 0.5, propMat, x + w * 0.4, h * 0.25, z + 3, i + 1); });
[[-65, -115], [90, -40], [-100, -20], [55, 80], [-50, 90], [115, -135], [-130, -90]].forEach(([x, z]) => { box(2.4, 26, 2.4, trunkMat, x, 13, z); for (let k = 0; k < 4; k++) box(14, 1, 3.2, leafMat, x + Math.cos(k * 1.57) * 6, 26, z + Math.sin(k * 1.57) * 6, k * 1.57); });

// ---------- rigs ----------
function cfm(a) { const m = new THREE.Matrix4(); m.set(a[3], a[4], a[5], a[0], a[6], a[7], a[8], a[1], a[9], a[10], a[11], a[2], 0, 0, 0, 1); return m; }
const tmpE = new THREE.Euler();
function rot(p, y, r) { tmpE.set(rad(r), rad(y), rad(p), "ZYX"); return new THREE.Matrix4().makeRotationFromEuler(tmpE); }
function buildDino(D, scale) {
  const g = new THREE.Group(); scene.add(g);
  const cache = {}, mats = [];
  const mat = hex => cache[hex] || (cache[hex] = (m => (mats.push(m), m))(new THREE.MeshLambertMaterial({color: parseInt(hex, 16), emissive: 0x000000})));
  const segs = {}, parts = [];
  for (const s of D.segs) {
    const rootInv = cfm(s.root).invert(); segs[s.n] = [];
    for (const p of s.parts) {
      const m = new THREE.Mesh(new THREE.BoxGeometry(p.s[0], p.s[1], p.s[2]), mat(p.c)); m.matrixAutoUpdate = false; m.castShadow = true; g.add(m);
      const kind = p.n.includes("_frill") ? "frill" : p.n.includes("_fold") ? "fold" : p.n === "Jaw_sac" ? "sac" : "";
      const info = {name: p.n, seg: s.n, mesh: m, local: rootInv.clone().multiply(cfm(p.cf)), size: p.s, kind}; segs[s.n].push(info); parts.push(info);
    }
  }
  const joints = D.joints.map(j => ({n: j.n, p0: j.p0, p1: j.p1, c0: cfm(j.c0), c1inv: cfm(j.c1).invert()}));
  return {D, g, segs, parts, joints, scale, mats, pos: new THREE.Vector3(), yaw: 0, y: 0, rest: null, frillS: 0, frillM: new THREE.Matrix4(), sac: 1, W: {}};
}
const _c = new THREE.Vector3(), _sacM = new THREE.Matrix4();
function pose(d, A) {
  const W = {HRP: new THREE.Matrix4().makeRotationY(d.yaw)};
  for (const j of d.joints) { const v = A[j.n] || [0, 0, 0]; W[j.p1] = W[j.p0].clone().multiply(j.c0).multiply(rot(v[0], v[1], v[2])).multiply(j.c1inv); }
  const S = new THREE.Matrix4().makeScale(d.scale, d.scale, d.scale);
  if (d.rest === null) { // ground offset from the rest pose's feet
    let minY = Infinity;
    for (const n in d.segs) for (const p of d.segs[n]) { const m = S.clone().multiply(W[n]).multiply(p.local); for (let i = 0; i < 8; i++) { _c.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(m); minY = Math.min(minY, _c.y); } }
    d.rest = -minY;
  }
  const TS = new THREE.Matrix4().makeTranslation(d.pos.x, d.y, d.pos.z).multiply(S);
  _sacM.makeScale(d.sac, d.sac, d.sac);
  for (const p of d.parts) {
    const m = p.mesh.matrix.copy(TS).multiply(W[p.seg]);
    if (p.kind === "frill") { p.mesh.visible = d.frillS > 0; m.multiply(d.frillM); }
    else if (p.kind === "fold") p.mesh.visible = !(d.frillS > 0);
    m.multiply(p.local);
    if (p.kind === "sac" && d.sac !== 1) m.multiply(_sacM);
  }
  d.W = W;
}
const partPoint = (part, lx, ly, lz) => new THREE.Vector3(lx || 0, ly || 0, lz || 0).applyMatrix4(part.mesh.matrix);

const hero = buildDino(TROODON, 2);
const P_ = n => hero.parts.find(p => p.name === n);
const mouthParts = {tip: P_("Head_tip"), skull: P_("Head_cranium"), mouth: P_("Head_mouth"), jaw: P_("Jaw_lower")};
const heroFeet = hero.parts.filter(p => p.seg.startsWith("Foot"));
// frill hub (Neck segment space): the open frill grows out from here when it snaps open
const frillHub = (() => { const v = new THREE.Vector3(), q = new THREE.Vector3(); let n = 0; for (const p of hero.parts) if (p.kind === "frill" && /[LR]\d?a$|[LR]\da$/.test(p.name)) { q.setFromMatrixPosition(p.local); v.add(q); n++; } v.divideScalar(Math.max(1, n)); v.z = 0; return v; })();
function mouthPoint() { // between the upper and lower jaw tips, pushed a little forward
  const a = partPoint(mouthParts.tip), s = partPoint(mouthParts.skull), j = partPoint(mouthParts.jaw);
  const dir = a.clone().sub(s).normalize();
  return a.clone().lerp(j, 0.35).addScaledVector(dir, 1.6);
}
function headDir() { return partPoint(mouthParts.tip).sub(partPoint(mouthParts.skull)).normalize(); }

const raps = [0, 1, 2].map(() => { const r = buildDino(RAPTOR, 2); return {rig: r, pos: new THREE.Vector3(), yaw: 0, flinch: 0, side: 0, flash: 0, flashCol: [0.9, 0.1, 0.05], push: 0, pushDir: new THREE.Vector3(), venom: null, slow: 0, runPh: 0, run: 0, path: null, show: false}; });
function yawTo(from, to) { return Math.atan2(-(to.x - from.x), -(to.z - from.z)); }
function rapChest(R) { return partPoint(R.rig.segs.Torso[0]); }

// ---------- pose maths (v0.3) ----------
// Joint angles [p, y, r] on this rig (rig 1.3): p = pitch (RootJoint / Neck / Head + = rear back / nose up, - = lunge or nod
// forward; Arm / Leg + = swing forward; Knee - = bend; Ankle + = toes up; Tail + = droop, - = lift; Jaw - = open),
// y = yaw (+ = turn to the dino's R side), r = roll.
const E = {
  lin: u => u, io: u => u * u * (3 - 2 * u), out: u => 1 - Math.pow(1 - u, 3), out5: u => 1 - Math.pow(1 - u, 5),
  in: u => u * u * u, in2: u => u * u,
  back: u => { const c = 1.9; return 1 + (c + 1) * Math.pow(u - 1, 3) + c * Math.pow(u - 1, 2); },
};
function lerpPose(a, b, u) {
  const o = {}; const ks = new Set([...Object.keys(a), ...Object.keys(b)]);
  for (const k of ks) {
    if (k === "root") { const ra = a.root || {}, rb = b.root || {}; o.root = {}; for (const c of ["fwd", "up"]) o.root[c] = (ra[c] || 0) + ((rb[c] || 0) - (ra[c] || 0)) * u; continue; }
    const va = a[k] || [0, 0, 0], vb = b[k] || [0, 0, 0]; o[k] = [0, 1, 2].map(i => va[i] + (vb[i] - va[i]) * u);
  }
  return o;
}
function addPose(a, b, w) {
  const o = Object.assign({}, a);
  for (const k in b) {
    if (k === "root") { o.root = Object.assign({fwd: 0, up: 0}, a.root); for (const c in b.root) o.root[c] = (o.root[c] || 0) + b.root[c] * w; continue; }
    const va = a[k] || [0, 0, 0]; o[k] = [0, 1, 2].map(i => va[i] + b[k][i] * w);
  }
  return o;
}
function sample(keys, t) {
  if (t <= keys[0].t) return keys[0].pose;
  for (let i = 1; i < keys.length; i++) if (t <= keys[i].t) { const a = keys[i - 1], b = keys[i]; return lerpPose(a.pose, b.pose, (E[b.e || "io"])((t - a.t) / (b.t - a.t))); }
  return keys[keys.length - 1].pose;
}
const BOTH = o => { const r = Object.assign({}, o); for (const k in o) if (/L$/.test(k)) { const v = o[k]; r[k.slice(0, -1) + "R"] = [v[0], -v[1], -v[2]]; } return r; };

// ---------- key poses ----------
const READY = {};
// A · glob: rear back (neck up and back, chest up, head level), hold, whip forward and lob (head tipped up), follow through
const A_WIND = BOTH({RootJoint: [10, 0, 0], Neck: [32, 0, 0], Head: [-22, 0, 0], Jaw: [-8, 0, 0], ArmL: [-14, 0, 0], LegL: [5, 0, 0], KneeL: [-8, 0, 0], Tail1: [7, 0, 0], Tail2: [4, 0, 0], root: {fwd: -1.2}});
const A_HOLD = addPose(A_WIND, {Neck: [4, 0, 0], Head: [-3, 0, 0], Jaw: [-6, 0, 0]}, 1);
const A_SPIT = Object.assign(BOTH({RootJoint: [-7, 0, 0], Neck: [-22, 0, 0], Head: [42, 0, 0], Jaw: [-38, 0, 0], ArmL: [16, 0, 0], KneeL: [-6, 0, 0], Tail1: [-9, 0, 0], Tail2: [-5, 0, 0], root: {fwd: 2.2}}), {LegL: [-6, 0, 0], LegR: [12, 0, 0], KneeR: [-16, 0, 0]});
const A_FOLLOW = Object.assign(BOTH({RootJoint: [-9, 0, 0], Neck: [-28, 0, 0], Head: [38, 0, 0], Jaw: [-24, 0, 0], ArmL: [10, 0, 0], KneeL: [-6, 0, 0], Tail1: [-11, 0, 0], Tail2: [-6, 0, 0], root: {fwd: 2.6}}), {LegL: [-6, 0, 0], LegR: [12, 0, 0], KneeR: [-16, 0, 0]});
// B · spray: low and forward, jaw wide, mouth level, legs braced
const B_SET = Object.assign(BOTH({RootJoint: [-6, 0, 0], Neck: [-12, 0, 0], Head: [-6, 0, 0], Jaw: [-40, 0, 0], ArmL: [-10, 0, 0], KneeL: [-14, 0, 0], AnkleL: [6, 0, 0], Tail1: [-6, 0, 0], root: {fwd: 0.8}}), {LegL: [14, 0, 0], LegR: [-4, 0, 0]});
// C · bite: quick neck snap; dart: coil into an S, then strike straight
const C_BWIND = BOTH({RootJoint: [4, 0, 0], Neck: [14, 0, 0], Head: [-4, 0, 0], Jaw: [-34, 0, 0], ArmL: [-8, 0, 0], root: {fwd: -0.6}});
const C_BITE = Object.assign(BOTH({RootJoint: [-14, 0, 0], Neck: [-36, 0, 0], Head: [-2, 0, 0], Jaw: [3, 0, 0], ArmL: [22, 0, 0], KneeL: [-8, 0, 0], Tail1: [-12, 0, 0], Tail2: [-6, 0, 0], root: {fwd: 3.4}}), {LegL: [-8, 0, 0], LegR: [16, 0, 0], KneeR: [-20, 0, 0]});
const C_COIL = BOTH({RootJoint: [6, 0, 0], Neck: [30, 0, 0], Head: [-26, 0, 0], Jaw: [-12, 0, 0], ArmL: [-16, 0, 0], KneeL: [-10, 0, 0], LegL: [6, 0, 0], Tail1: [6, 0, 0], Tail2: [4, 0, 0], root: {fwd: -1}});
const C_DART = Object.assign(BOTH({RootJoint: [-8, 0, 0], Neck: [-20, 0, 0], Head: [4, 0, 0], Jaw: [-34, 0, 0], ArmL: [14, 0, 0], Tail1: [-8, 0, 0], root: {fwd: 2}}), {LegL: [-6, 0, 0], LegR: [10, 0, 0], KneeR: [-12, 0, 0]});
// jumps: crouch with the neck coiled, tucked in the air, plain landing (a short knee absorb, nothing else)
const J_CROUCH = BOTH({RootJoint: [-8, 0, 0], Neck: [24, 0, 0], Head: [-20, 0, 0], Jaw: [-6, 0, 0], ArmL: [-24, 0, 0], LegL: [34, 0, 0], KneeL: [-58, 0, 0], AnkleL: [26, 0, 0], Tail1: [6, 0, 0]});
const J_PUSH = BOTH({RootJoint: [-4, 0, 0], Neck: [18, 0, 0], Head: [-14, 0, 0], ArmL: [-20, 0, 0], LegL: [-22, 0, 0], KneeL: [-4, 0, 0], AnkleL: [-24, 0, 0], Tail1: [-6, 0, 0]});
const J_AIR = BOTH({RootJoint: [-2, 0, 0], Neck: [28, 0, 0], Head: [-26, 0, 0], Jaw: [-12, 0, 0], ArmL: [-30, 0, 0], LegL: [40, 0, 0], KneeL: [-72, 0, 0], AnkleL: [34, 0, 0], Tail1: [-8, 0, 0], Tail2: [-4, 0, 0], Tail3: [-3, 0, 0]});
const J_DOWN = BOTH({RootJoint: [-6, 0, 0], Neck: [16, 0, 0], Head: [-12, 0, 0], ArmL: [-10, 0, 0], LegL: [22, 0, 0], KneeL: [-30, 0, 0], AnkleL: [12, 0, 0], Tail1: [-4, 0, 0]});
const J_LAND = BOTH({RootJoint: [-6, 0, 0], Neck: [8, 0, 0], Head: [-6, 0, 0], ArmL: [6, 0, 0], LegL: [24, 0, 0], KneeL: [-42, 0, 0], AnkleL: [18, 0, 0], Tail1: [6, 0, 0]});
const J2_SPIT = BOTH({RootJoint: [-14, 0, 0], Neck: [-26, 0, 0], Head: [-26, 0, 0], Jaw: [-38, 0, 0], ArmL: [-10, 0, 0], LegL: [40, 0, 0], KneeL: [-70, 0, 0], AnkleL: [30, 0, 0], Tail1: [-14, 0, 0], Tail2: [-6, 0, 0]});

// ---------- FX ----------
function radialTex(inner, outer, mid) {
  const c = document.createElement("canvas"); c.width = c.height = 128; const x = c.getContext("2d");
  const g = x.createRadialGradient(64, 64, 0, 64, 64, 64); g.addColorStop(0, inner); g.addColorStop(mid || 0.35, inner.replace(/[\d.]+\)$/, "0.6)")); g.addColorStop(1, outer);
  x.fillStyle = g; x.fillRect(0, 0, 128, 128); return new THREE.CanvasTexture(c);
}
const T_FLASH = radialTex("rgba(255,255,240,1)", "rgba(255,230,160,0)");
const T_SPARK = radialTex("rgba(255,250,220,1)", "rgba(255,170,60,0)");
const T_DROP = radialTex("rgba(225,255,170,1)", "rgba(90,200,40,0)", 0.5);
const T_MIST = radialTex("rgba(170,240,110,0.8)", "rgba(110,200,60,0)");
const fx = [];
function addFx(obj, life, update) { scene.add(obj); fx.push({obj, life, t: 0, update}); return obj; }
function sprite(tex, color, size, additive) {
  const s = new THREE.Sprite(new THREE.SpriteMaterial({map: tex, color, transparent: true, depthWrite: false, blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending}));
  s.scale.set(size, size, 1); return s;
}
function flash(p, size, color) { const s = sprite(T_FLASH, color || 0xffffff, size, true); s.position.copy(p); addFx(s, 0.16, (o, u) => { o.scale.setScalar(size * (0.6 + u * 1.2)); o.material.opacity = 1 - u; }); }
function sparks(p, dir, n, color, spd) {
  for (let i = 0; i < n; i++) {
    const s = sprite(T_SPARK, color || 0xfff4c8, 0.9 + Math.random() * 0.9, true); s.position.copy(p);
    const v = dir.clone().multiplyScalar((spd || 1) * (14 + Math.random() * 22)).add(new THREE.Vector3((Math.random() - .5) * 22, 6 + Math.random() * 14, (Math.random() - .5) * 22));
    addFx(s, 0.3 + Math.random() * 0.25, (o, u, dt) => { v.y -= 60 * dt; o.position.addScaledVector(v, dt); o.material.opacity = 1 - u; o.scale.setScalar((1 - u) * 1.5); });
  }
}
const GREEN = 0x9cf05a, GREEN_D = 0x5cc22a;
function droplet(p, v, size, life, grav) { // a venom droplet that falls and fades out before it could pool (no puddles)
  const s = sprite(T_DROP, Math.random() < 0.5 ? GREEN : GREEN_D, size, false); s.position.copy(p);
  addFx(s, life, (o, u, dt) => { v.y -= (grav === undefined ? 50 : grav) * dt; o.position.addScaledVector(v, dt); if (o.position.y < 0.4) { o.position.y = 0.4; v.set(0, 0, 0); } o.material.opacity = u > 0.6 ? (1 - u) / 0.4 : 1; o.scale.setScalar(size * (1 - u * 0.5)); });
}
function splash(p, n, power) { // glob splat: green flash, a burst of droplets, a puff of mist; nothing left on the ground
  flash(p, 9 * power, 0xd8ffb0);
  for (let i = 0; i < n; i++) { const a = Math.random() * Math.PI * 2, e = Math.random() * 1.2 - 0.2; const sp = (10 + Math.random() * 22) * power; droplet(p.clone(), new THREE.Vector3(Math.cos(a) * Math.cos(e) * sp, Math.sin(e) * sp + 8, Math.sin(a) * Math.cos(e) * sp), 0.8 + Math.random() * 1.1, 0.5 + Math.random() * 0.35); }
  for (let i = 0; i < 6; i++) { const s = sprite(T_MIST, 0xffffff, 3, false); s.position.copy(p).add(new THREE.Vector3((Math.random() - .5) * 3, (Math.random() - .5) * 2, (Math.random() - .5) * 3)); addFx(s, 0.55, (o, u) => { o.scale.setScalar(3 + u * 7 * power); o.material.opacity = 0.55 * (1 - u); }); }
}
let numScale = 1.35;
function numberPop(p, n, style) { // style: "hit" (white / yellow), "venom" (small green tick), "big"
  const c = document.createElement("canvas"); c.width = 256; c.height = 128; const x = c.getContext("2d");
  const big = style === "big", ven = style === "venom";
  x.font = `900 ${big ? 96 : ven ? 64 : 80}px "Trebuchet MS", system-ui, sans-serif`; x.textAlign = "center"; x.lineJoin = "round"; x.lineWidth = 14; x.strokeStyle = ven ? "#0f2a06" : "#2a1504";
  x.strokeText(String(n), 128, 100); const g = x.createLinearGradient(0, 30, 0, 110);
  if (ven) { g.addColorStop(0, "#e6ffc2"); g.addColorStop(1, "#7fdc3a"); } else { g.addColorStop(0, big ? "#ffe08a" : "#ffffff"); g.addColorStop(1, big ? "#ff7a1a" : "#ffd23a"); }
  x.fillStyle = g; x.fillText(String(n), 128, 100);
  const s = new THREE.Sprite(new THREE.SpriteMaterial({map: new THREE.CanvasTexture(c), transparent: true, depthTest: false}));
  s.renderOrder = 10; s.position.copy(p); const vx = (Math.random() - .5) * 8, base = (big ? 10 : ven ? 6 : 8) * numScale;
  addFx(s, ven ? 0.8 : 0.95, (o, u, dt) => { o.position.y += (14 - u * 22) * dt; o.position.x += vx * dt; const pop = u < 0.12 ? E.back(u / 0.12) : 1; o.scale.set(base * pop, base * 0.5 * pop, 1); o.material.opacity = u > 0.65 ? (1 - u) / 0.35 : 1; });
}
function textTag(p, text, color, life) {
  const c = document.createElement("canvas"); c.width = 320; c.height = 64; const x = c.getContext("2d");
  x.font = `800 28px "Trebuchet MS", system-ui, sans-serif`; const w = Math.min(310, x.measureText(text).width + 36);
  x.fillStyle = "rgba(10,20,14,.78)"; x.beginPath(); x.roundRect ? x.roundRect(160 - w / 2, 8, w, 48, 24) : x.rect(160 - w / 2, 8, w, 48); x.fill();
  x.textAlign = "center"; x.fillStyle = color; x.fillText(text, 160, 42);
  const s = new THREE.Sprite(new THREE.SpriteMaterial({map: new THREE.CanvasTexture(c), transparent: true, depthTest: false})); s.renderOrder = 9;
  s.position.copy(p); s.scale.set(12, 2.4, 1);
  return addFx(s, life, (o, u) => { o.material.opacity = u < 0.08 ? u / 0.08 : u > 0.85 ? (1 - u) / 0.15 : 1; });
}

// ground decals: soft-aim cone (faint white sector + brighter edges), the chosen target's ring, the line to it; spray cone (green)
function sectorMesh(r, halfDeg, color, op) {
  const g = new THREE.Group();
  const m = new THREE.Mesh(new THREE.CircleGeometry(r, 40, Math.PI / 2 - rad(halfDeg), rad(halfDeg * 2)), new THREE.MeshBasicMaterial({color, transparent: true, opacity: op, depthWrite: false}));
  m.rotation.x = -Math.PI / 2; g.add(m);
  for (const s of [-1, 1]) { const e = new THREE.Mesh(new THREE.PlaneGeometry(0.35, r), new THREE.MeshBasicMaterial({color, transparent: true, opacity: op * 3.2, depthWrite: false})); e.rotation.x = -Math.PI / 2; const a = rad(halfDeg) * s; e.rotation.z = a; e.position.set(-Math.sin(a) * r / 2, 0.01, -Math.cos(a) * r / 2); g.add(e); }
  const arc = new THREE.Mesh(new THREE.RingGeometry(r - 0.35, r, 40, 1, Math.PI / 2 - rad(halfDeg), rad(halfDeg * 2)), new THREE.MeshBasicMaterial({color, transparent: true, opacity: op * 2.2, depthWrite: false})); arc.rotation.x = -Math.PI / 2; arc.position.y = 0.01; g.add(arc);
  g.position.y = 0.09; g.visible = false; scene.add(g); g.userData.op = op; return g;
}
const AIMC = 0xc8f6ff;
const aimCone = {A: sectorMesh(44, 30, AIMC, 0.11), C: sectorMesh(60, 30, AIMC, 0.11), J: sectorMesh(40, 30, AIMC, 0.11)};
const sprayCone = sectorMesh(18, 20, 0x8ee05a, 0.12);
const dashTex = (() => { const c = document.createElement("canvas"); c.width = 16; c.height = 64; const x = c.getContext("2d"); x.fillStyle = "#fff"; x.beginPath(); x.moveTo(2, 40); x.lineTo(8, 24); x.lineTo(14, 40); x.lineTo(14, 52); x.lineTo(8, 36); x.lineTo(2, 52); x.fill(); const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; return t; })();
const aimLine = new THREE.Mesh(new THREE.PlaneGeometry(2.4, 1), new THREE.MeshBasicMaterial({map: dashTex, color: 0xffffff, transparent: true, opacity: 1, depthWrite: false})); aimLine.rotation.x = -Math.PI / 2; aimLine.visible = false;
const aimLineG = new THREE.Group(); aimLineG.add(aimLine); aimLineG.position.y = 0.11; scene.add(aimLineG);
const reticle = new THREE.Mesh(new THREE.RingGeometry(5.2, 6, 40), new THREE.MeshBasicMaterial({color: 0xfff2a0, transparent: true, opacity: 0.7, depthWrite: false, side: THREE.DoubleSide})); reticle.rotation.x = -Math.PI / 2; reticle.position.y = 0.12; reticle.visible = false; scene.add(reticle);
function setCone(g, vis, fade) { vis = !!vis; g.visible = vis; if (vis) g.children.forEach((m, i) => m.material.opacity = g.userData.op * (i === 0 ? 1 : i === 3 ? 2.2 : 3.2) * fade); }

// projectiles
const globGeo = new THREE.IcosahedronGeometry(1.25, 1);
const globMat = new THREE.MeshLambertMaterial({color: 0x86e04a, emissive: 0x2d7a10});
const dartGeo = new THREE.CylinderGeometry(0.18, 0.55, 5.2, 8); dartGeo.rotateX(Math.PI / 2);
const dartMat = new THREE.MeshBasicMaterial({color: 0xd8ff7a});
const shots = [];
function spawnShot(o) { // o: {kind: "glob" | "dart", from, target: () => Vector3, T, H, onHit}
  const m = new THREE.Mesh(o.kind === "dart" ? dartGeo : globGeo, o.kind === "dart" ? dartMat : globMat); m.castShadow = true; scene.add(m);
  const glow = sprite(T_DROP, 0xb8ff70, o.kind === "dart" ? 4.5 : 5.5, true); scene.add(glow);
  shots.push(Object.assign({mesh: m, glow, t: 0, prev: o.from.clone(), em: 0}, o));
}
function updateShots(dt) {
  for (let i = shots.length - 1; i >= 0; i--) {
    const s = shots[i]; s.t += dt; const u = Math.min(1, s.t / s.T);
    const to = s.target();
    const p = s.from.clone().lerp(to, u); p.y += 4 * s.H * u * (1 - u);
    const v = p.clone().sub(s.prev); const sp = v.length() / Math.max(1e-4, dt);
    s.mesh.position.copy(p); s.glow.position.copy(p);
    if (v.lengthSq() > 1e-6) { s.mesh.lookAt(p.clone().add(v)); }
    if (s.kind === "glob") { const st = 1 + Math.min(0.45, sp / 260); s.mesh.scale.set(1 / Math.sqrt(st), 1 / Math.sqrt(st), st); s.mesh.rotateZ(s.t * 9); }
    // trail: drips falling off the glob / a bright streak behind the dart
    s.em += dt * (s.kind === "dart" ? 90 : 34);
    while (s.em >= 1) { s.em -= 1; const q = s.prev.clone().lerp(p, Math.random());
      if (s.kind === "dart") { const t = sprite(T_DROP, 0xd8ff8a, 1.6, true); t.position.copy(q); addFx(t, 0.22, (o, uu) => { o.material.opacity = 1 - uu; o.scale.setScalar(1.6 * (1 - uu * 0.7)); }); }
      else droplet(q, new THREE.Vector3((Math.random() - .5) * 4, -2 - Math.random() * 3, (Math.random() - .5) * 4), 0.5 + Math.random() * 0.6, 0.45, 40); }
    s.prev.copy(p);
    if (u >= 1) { scene.remove(s.mesh); scene.remove(s.glow); shots.splice(i, 1); s.onHit(p); }
  }
}

// ---------- springs (v0.3: the body follows the key poses through springs: overlap, settle, a little overshoot) ----------
const SPR = (n) => /^Arm/.test(n) ? [30, 0.55] : n === "RootJoint" ? [30, 0.85] : /^(Leg|Knee|Ankle)/.test(n) ? [36, 0.9]
  : n === "Neck" ? [26, 0.58] : n === "Head" ? [22, 0.55] : n === "Jaw" ? [34, 0.5] : /^Tail(\d)/.test(n) ? [18 - 2.2 * (+n.slice(4)), 0.42] : [24, 0.8];
let springs = {};
function springStep(target, dt) { const n = Math.max(1, Math.ceil(dt * 300)); let out = {}; for (let i = 0; i < n; i++) out = springStep1(target, dt / n); return out; }
function springStep1(target, dt) {
  const out = {};
  for (const n in target) {
    if (n === "root") continue;
    let s = springs[n]; if (!s) s = springs[n] = {x: target[n].slice(), v: [0, 0, 0], k: SPR(n)};
    const [w, z] = s.k;
    for (let i = 0; i < 3; i++) { const a = w * w * (target[n][i] - s.x[i]) - 2 * z * w * s.v[i]; s.v[i] += a * dt; s.x[i] += s.v[i] * dt; }
    out[n] = s.x.slice();
  }
  for (const n in springs) if (!out[n]) { const s = springs[n]; const [w, z] = s.k; for (let i = 0; i < 3; i++) { const a = w * w * (0 - s.x[i]) - 2 * z * w * s.v[i]; s.v[i] += a * dt; s.x[i] += s.v[i] * dt; } out[n] = s.x.slice(); }
  return out;
}
const rootSpring = {x: 0, v: 0};
