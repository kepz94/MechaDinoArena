// titles_engine.js v0.1 (Mecha Dino Arena) — engine for the Victory Titles mockup: scene, rigs (every dino shares the rig
// joint names RootJoint / Neck / Head / Jaw / ArmL,R / Tail1..5 / LegL,R / KneeL,R / AnkleL,R), springs, foot planting,
// whole-body squash / tumble, props, FX, camera. Joint angles [p, y, r] as in the moves mockups: p = pitch (RootJoint /
// Neck / Head + = rear back / nose up; Arm / Leg + = swing forward; Knee - = bend; Ankle + = toes up; Tail + = droop,
// - = lift; Jaw - = open), y = yaw (+ = turn to the dino's R side), r = roll. MODELS = model_json.py exports.
const MODELS = __MODELS__;
const $ = id => document.getElementById(id);
const rad = THREE.MathUtils.degToRad;
const clamp = (x, a, b) => Math.min(b, Math.max(a, x)), lerp = (a, b, u) => a + (b - a) * u, sat = x => clamp(x, 0, 1);
const win = (t, a, b) => sat((t - a) / (b - a));
const V = (x, y, z) => new THREE.Vector3(x, y, z);
const E = {
  lin: u => u, io: u => u * u * (3 - 2 * u), out: u => 1 - Math.pow(1 - u, 3), out5: u => 1 - Math.pow(1 - u, 5),
  in: u => u * u * u, in2: u => u * u,
  back: u => { const c = 1.9; return 1 + (c + 1) * Math.pow(u - 1, 3) + c * Math.pow(u - 1, 2); },
  elastic: u => u <= 0 ? 0 : u >= 1 ? 1 : Math.pow(2, -10 * u) * Math.sin((u * 10 - 0.75) * (2 * Math.PI / 3)) + 1,
  bounce: u => { const n = 7.5625, d = 2.75; if (u < 1 / d) return n * u * u; if (u < 2 / d) return n * (u -= 1.5 / d) * u + 0.75; if (u < 2.5 / d) return n * (u -= 2.25 / d) * u + 0.9375; return n * (u -= 2.625 / d) * u + 0.984375; },
};
// scalar keyframes: [[t, v, ease?], ...]
function kf(t, keys) {
  if (t <= keys[0][0]) return keys[0][1];
  for (let i = 1; i < keys.length; i++) if (t <= keys[i][0]) { const a = keys[i - 1], b = keys[i]; return lerp(a[1], b[1], E[b[2] || "io"]((t - a[0]) / (b[0] - a[0]))); }
  return keys[keys.length - 1][1];
}
function kv(t, keys) { // vector keyframes: [[t, [x,y,z], ease?], ...]
  if (t <= keys[0][0]) return keys[0][1].slice();
  for (let i = 1; i < keys.length; i++) if (t <= keys[i][0]) { const a = keys[i - 1], b = keys[i], u = E[b[2] || "io"]((t - a[0]) / (b[0] - a[0])); return a[1].map((v, k) => lerp(v, b[1][k], u)); }
  return keys[keys.length - 1][1].slice();
}

// ---------- renderer / scene ----------
const cv = $("cv");
const renderer = new THREE.WebGLRenderer({canvas: cv, antialias: true, preserveDrawingBuffer: true});
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
const scene = new THREE.Scene();
const SKY = new THREE.Color(0x8cc3e6), SKY_DOOM = new THREE.Color(0xd8774a);
scene.background = SKY.clone(); scene.fog = new THREE.Fog(SKY.clone(), 260, 700);
const cam = new THREE.PerspectiveCamera(36, 16 / 9, 0.6, 2000);
const hemi = new THREE.HemisphereLight(0xdfeeff, 0x4f6a33, 0.62); scene.add(hemi);
const sun = new THREE.DirectionalLight(0xfff1d6, 0.85); sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048); Object.assign(sun.shadow.camera, {left: -110, right: 110, top: 110, bottom: -110, near: 1, far: 400});
sun.shadow.bias = -0.0006; sun.position.set(-60, 120, -50); scene.add(sun); scene.add(sun.target);
const fill = new THREE.DirectionalLight(0xbfd9ff, 0.3); fill.position.set(50, 30, 40); scene.add(fill);

function noiseTex(base, spread, n, size) {
  const c = document.createElement("canvas"); c.width = c.height = size || 256; const x = c.getContext("2d"); x.fillStyle = base; x.fillRect(0, 0, c.width, c.height);
  const b = new THREE.Color(base);
  for (let i = 0; i < n; i++) { const k = 1 + (Math.random() - .5) * spread * 2; x.fillStyle = `rgb(${clamp(b.r * 255 * k, 0, 255) | 0},${clamp(b.g * 255 * k, 0, 255) | 0},${clamp(b.b * 255 * k, 0, 255) | 0})`; x.fillRect(Math.random() * c.width, Math.random() * c.height, 2 + Math.random() * 3, 2 + Math.random() * 3); }
  const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; return t;
}
const gTex = noiseTex("#5f9a40", 0.16, 2600); gTex.repeat.set(70, 70);
const ground = new THREE.Mesh(new THREE.PlaneGeometry(2400, 2400), new THREE.MeshLambertMaterial({map: gTex}));
ground.rotation.x = -Math.PI / 2; ground.receiveShadow = true; scene.add(ground);
const dTex = noiseTex("#b9a57a", 0.14, 1800); dTex.repeat.set(10, 10);
const pad = new THREE.Mesh(new THREE.CircleGeometry(150, 64), new THREE.MeshLambertMaterial({map: dTex}));
pad.rotation.x = -Math.PI / 2; pad.position.y = 0.08; pad.receiveShadow = true; scene.add(pad);
// far trees (blocky, like the island)
{ const tm = new THREE.MeshLambertMaterial({color: 0x7a5a38}), lm = [new THREE.MeshLambertMaterial({color: 0x3f8a3a}), new THREE.MeshLambertMaterial({color: 0x4f9c44})];
  let s = 11; const rnd = () => (s = (s * 16807) % 2147483647) / 2147483647;
  for (let i = 0; i < 70; i++) { const a = rnd() * Math.PI * 2, r = 230 + rnd() * 260, h = 22 + rnd() * 26;
    const tr = new THREE.Mesh(new THREE.BoxGeometry(4, h, 4), tm); tr.position.set(Math.cos(a) * r, h / 2, Math.sin(a) * r); scene.add(tr);
    const lf = new THREE.Mesh(new THREE.BoxGeometry(18 + rnd() * 8, 14 + rnd() * 6, 18 + rnd() * 8), lm[i % 2]); lf.position.set(tr.position.x, h + 5, tr.position.z); scene.add(lf); } }

// ---------- rigs ----------
function cfm(a) { const m = new THREE.Matrix4(); m.set(a[3], a[4], a[5], a[0], a[6], a[7], a[8], a[1], a[9], a[10], a[11], a[2], 0, 0, 0, 1); return m; }
const _e = new THREE.Euler(), _v = new THREE.Vector3(), _m = new THREE.Matrix4(), _m2 = new THREE.Matrix4(), I4 = new THREE.Matrix4();
function rotM(v) { _e.set(rad(v[2]), rad(v[1]), rad(v[0]), "ZYX"); return new THREE.Matrix4().makeRotationFromEuler(_e); }
const STONE = new THREE.Color(0xcbbf9f);
function buildRig(key, opt) {
  opt = opt || {};
  const D = MODELS[key].model, g = new THREE.Group(); scene.add(g);
  const cache = {}, mats = [];
  const ghostMat = opt.ghost ? new THREE.MeshBasicMaterial({color: 0xeaf6ff, transparent: true, opacity: 0.45, depthWrite: false}) : null;
  const mat = hex => ghostMat || cache[hex] || (cache[hex] = (m => { m.userData.base = m.color.clone(); mats.push(m); return m; })(new THREE.MeshLambertMaterial({color: parseInt(hex, 16)})));
  const segs = {}, parts = [], segBox = {};
  for (const s of D.segs) {
    const rootInv = cfm(s.root).invert(); segs[s.n] = []; segBox[s.n] = new THREE.Box3();
    for (const p of s.parts) {
      const hidden = (p.t || 0) >= 1 || p.n.includes("_fold");
      const m = new THREE.Mesh(new THREE.BoxGeometry(p.s[0], p.s[1], p.s[2]), mat(p.c)); m.matrixAutoUpdate = false; m.visible = !hidden; m.castShadow = !opt.ghost; g.add(m);
      const local = rootInv.clone().multiply(cfm(p.cf));
      const info = {name: p.n, seg: s.n, mesh: m, local, size: p.s, hidden, color: p.c}; segs[s.n].push(info); parts.push(info);
      if (!hidden) for (let i = 0; i < 8; i++) segBox[s.n].expandByPoint(V((i & 1 ? .5 : -.5) * p.s[0], (i & 2 ? .5 : -.5) * p.s[1], (i & 4 ? .5 : -.5) * p.s[2]).applyMatrix4(local));
    }
  }
  const joints = D.joints.map(j => ({n: j.n, p0: j.p0, p1: j.p1, c0: cfm(j.c0), c1inv: cfm(j.c1).invert()}));
  const r = {key, D, g, segs, parts, segBox, joints, mats, ghostMat, base: MODELS[key].scale, scale: MODELS[key].scale,
    pos: V(0, 0, 0), yaw: 0, rx: 0, rz: 0, sq: 1, sqx: null, sqz: null, plant: "feet", segW: {}, A: {}, springs: {}, restMinY: 0, quad: false};
  // rest measures (scale 1 = in-game)
  r.restMinY = 0; r.plant = "none"; poseRig(r, {});
  const box = worldBox(r); r.restMinY = box.min.y / r.scale; poseRig(r, {}); // model units
  const b2 = worldBox(r), k = 1 / r.scale;
  r.m = {H: b2.max.y * k, L: (b2.max.z - b2.min.z) * k, Wd: (b2.max.x - b2.min.x) * k, zMin: b2.min.z * k, zMax: b2.max.z * k,
    piv: worldBox(r, p => p.seg === "Torso").getCenter(V(0, 0, 0)).multiplyScalar(k)}; // tumble pivot (rest, feet on 0)
  setRigScale(r, r.scale);
  const feet = worldBox(r, p => /^Foot/.test(p.seg)), arms = worldBox(r, p => /^(Arm|Fore|Hand)/.test(p.seg));
  r.quad = arms.min.y < feet.min.y + 0.06 * r.H; // the Teno walks on its arms
  // local landmark points (segment space): mouth tip, head top, tail tip
  r.mouthL = segLocalExtreme(r, "Head", "front"); r.headTopL = segLocalExtreme(r, "Head", "top"); r.tailTipL = segLocalExtreme(r, "Tail5", "back");
  r.plant = "feet";
  return r;
}
function setRigScale(r, sc) { r.scale = sc; const m = r.m; r.H = m.H * sc; r.L = m.L * sc; r.Wd = m.Wd * sc; r.zMin = m.zMin * sc; r.zMax = m.zMax * sc; r.U = Math.max(r.H, 0.55 * r.L); r.piv = m.piv.clone().multiplyScalar(sc); }
function segLocalExtreme(r, seg, which) { // point on a segment's parts that is furthest front / top / back at rest, in segment space
  const inv = r.segW[seg].clone().invert(); let best = null, bv = -Infinity;
  for (const p of r.segs[seg]) { if (p.hidden) continue; for (let i = 0; i < 8; i++) { const w = V((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(p.mesh.matrix);
    const s = which === "front" ? -w.z : which === "back" ? w.z : w.y; if (s > bv) { bv = s; best = w; } } }
  // centre it sideways / blend toward the segment centre so the point sits on the surface middle
  const c = r.segBox[seg].getCenter(V(0, 0, 0)).applyMatrix4(r.segW[seg]);
  if (which === "top") best.set(c.x, best.y, c.z); else best.set(c.x, lerp(best.y, c.y, 0.5), best.z);
  return best.applyMatrix4(inv);
}
function worldBox(r, filter) {
  const b = new THREE.Box3();
  for (const p of r.parts) { if (p.hidden || (filter && !filter(p))) continue; for (let i = 0; i < 8; i++) b.expandByPoint(_v.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(p.mesh.matrix)); }
  return b;
}
// World = T(pos) · Ry(yaw) · [pivot · Rx(rx) · Rz(rz) · pivot⁻¹] · Squash · T(0, -restMinY, 0) · S · W[seg]
function poseRig(r, A) {
  const W = {HRP: I4};
  for (const j of r.joints) { const v = A[j.n]; W[j.p1] = v ? W[j.p0].clone().multiply(j.c0).multiply(rotM(v)).multiply(j.c1inv) : W[j.p0].clone().multiply(j.c0).multiply(j.c1inv); }
  const sy = r.sq, sx = r.sqx !== null ? r.sqx : 1 / Math.sqrt(Math.max(0.05, sy)), sz = r.sqz !== null ? r.sqz : sx;
  const piv = r.piv || V(0, r.H ? r.H * 0.5 : 0, 0);
  const base = new THREE.Matrix4().makeRotationY(r.yaw)
    .multiply(_m.makeTranslation(piv.x * sx, piv.y * sy, piv.z * sz))
    .multiply(new THREE.Matrix4().makeRotationX(r.rx)).multiply(new THREE.Matrix4().makeRotationZ(r.rz))
    .multiply(_m.makeTranslation(-piv.x * sx, -piv.y * sy, -piv.z * sz))
    .multiply(new THREE.Matrix4().makeScale(sx, sy, sz))
    .multiply(new THREE.Matrix4().makeScale(r.scale, r.scale, r.scale))
    .multiply(_m.makeTranslation(0, -r.restMinY, 0));
  for (const n in r.segs) r.segW[n] = base.clone().multiply(W[n] || I4);
  for (const p of r.parts) p.mesh.matrix.copy(r.segW[p.seg]).multiply(p.local);
  let lift = r.pos.y;
  if (r.plant !== "none") {
    let minY = Infinity;
    for (const p of r.parts) {
      if (p.hidden) continue;
      if (r.plant === "feet" && !(/^Foot/.test(p.seg) || (r.quad && /^(Arm|Fore|Hand)/.test(p.seg)))) continue;
      for (let i = 0; i < 8; i++) { _v.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(p.mesh.matrix); if (_v.y < minY) minY = _v.y; }
    }
    if (minY < Infinity) lift -= minY;
  }
  const T = _m2.makeTranslation(r.pos.x, lift, r.pos.z);
  for (const n in r.segW) r.segW[n].premultiply(T);
  for (const p of r.parts) p.mesh.matrix.premultiply(T);
  r.A = A;
}
const segPt = (r, seg, l) => l.clone().applyMatrix4(r.segW[seg]);
const segC = (r, seg) => r.segBox[seg].getCenter(V(0, 0, 0)).applyMatrix4(r.segW[seg]);
const headC = r => segC(r, "Head");
const mouthPt = r => segPt(r, "Head", r.mouthL), headTop = r => segPt(r, "Head", r.headTopL), tailTip = r => segPt(r, "Tail5", r.tailTipL);
function setTint(r, col, k) { for (const m of r.mats) m.color.copy(m.userData.base).lerp(col, k); }
function stoneTint(r, k) { for (const m of r.mats) { const l = m.userData.base.getHSL({}).l; m.color.copy(m.userData.base).lerp(STONE.clone().multiplyScalar(0.55 + l * 0.8), k); } }

// pose maths
function lerpPose(a, b, u) { const o = {}; for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) { const va = a[k] || [0, 0, 0], vb = b[k] || [0, 0, 0]; o[k] = [lerp(va[0], vb[0], u), lerp(va[1], vb[1], u), lerp(va[2], vb[2], u)]; } return o; }
function addPose(a, b, w) { const o = Object.assign({}, a); for (const k in b) { const va = a[k] || [0, 0, 0]; o[k] = [va[0] + b[k][0] * (w === undefined ? 1 : w), va[1] + b[k][1] * (w === undefined ? 1 : w), va[2] + b[k][2] * (w === undefined ? 1 : w)]; } return o; }
function pk(t, keys) { // pose keyframes [[t, pose, ease?], ...]
  if (t <= keys[0][0]) return keys[0][1];
  for (let i = 1; i < keys.length; i++) if (t <= keys[i][0]) { const a = keys[i - 1], b = keys[i]; return lerpPose(a[1], b[1], E[b[2] || "io"]((t - a[0]) / (b[0] - a[0]))); }
  return keys[keys.length - 1][1];
}
const BOTH = o => { const r = Object.assign({}, o); for (const k in o) if (/L$/.test(k)) { const v = o[k]; r[k.slice(0, -1) + "R"] = [v[0], -v[1], -v[2]]; } return r; };
// springs: the body follows the key poses with overlap and a little overshoot (follow-through on the neck, arms, tail)
const SPR = n => /^(Arm|Elbow|Wrist)/.test(n) ? [26, 0.5] : n === "RootJoint" ? [30, 0.8] : /^(Leg|Knee|Ankle)/.test(n) ? [40, 0.85]
  : n === "Neck" ? [24, 0.55] : n === "Head" ? [22, 0.5] : n === "Jaw" ? [36, 0.5] : /^Tail(\d)/.test(n) ? [17 - 2 * (+n.slice(4)), 0.38] : [24, 0.7];
function springStep(r, target, dt) {
  const steps = Math.max(1, Math.ceil(dt * 300)), h = dt / steps, out = {};
  const names = new Set([...Object.keys(target), ...Object.keys(r.springs)]);
  for (const n of names) {
    let s = r.springs[n]; const tg = target[n] || [0, 0, 0];
    if (!s) s = r.springs[n] = {x: tg.slice(), v: [0, 0, 0], k: SPR(n)};
    const [w, z] = s.k;
    for (let k = 0; k < steps; k++) for (let i = 0; i < 3; i++) { const a = w * w * (tg[i] - s.x[i]) - 2 * z * w * s.v[i]; s.v[i] += a * h; s.x[i] += s.v[i] * h; }
    out[n] = s.x.slice();
  }
  return out;
}
function snapSprings(r, target) { r.springs = {}; for (const n in target) r.springs[n] = {x: target[n].slice(), v: [0, 0, 0], k: SPR(n)}; }
function kick(r, n, dp, dy, dr) { const s = r.springs[n] || (r.springs[n] = {x: [0, 0, 0], v: [0, 0, 0], k: SPR(n)}); s.v[0] += dp || 0; s.v[1] += dy || 0; s.v[2] += dr || 0; }
// a scalar spring (body squash etc.)
function sSpring(x, w, z) { return {x, v: 0, w: w || 22, z: z || 0.35, tg: x}; }
function sStep(s, dt) { const n = Math.max(1, Math.ceil(dt * 300)), h = dt / n; for (let i = 0; i < n; i++) { s.v += (s.w * s.w * (s.tg - s.x) - 2 * s.z * s.w * s.v) * h; s.x += s.v * h; } return s.x; }
// procedural layers
function walkLayer(ph, amp, r) { // ph in cycles; amp 0..1
  const s = Math.sin(ph * Math.PI * 2), c = Math.cos(ph * Math.PI * 2), A = {};
  A.LegL = [28 * s * amp, 0, 0]; A.LegR = [-28 * s * amp, 0, 0];
  A.KneeL = [-(22 + 22 * Math.max(0, c)) * amp, 0, 0]; A.KneeR = [-(22 + 22 * Math.max(0, -c)) * amp, 0, 0];
  A.AnkleL = [10 * Math.max(0, -s) * amp, 0, 0]; A.AnkleR = [10 * Math.max(0, s) * amp, 0, 0];
  if (r && r.quad) { A.ArmL = [-24 * s * amp, 0, 0]; A.ArmR = [24 * s * amp, 0, 0]; } else { A.ArmL = [-8 * s * amp, 0, 0]; A.ArmR = [8 * s * amp, 0, 0]; }
  A.Tail1 = [0, 8 * c * amp, 0]; A.Tail2 = [0, 10 * c * amp, 0]; A.Tail3 = [0, 12 * c * amp, 0];
  A.Neck = [3 * Math.abs(s) * amp, -3 * c * amp, 0]; A.RootJoint = [0, 4 * c * amp, 3 * s * amp];
  return A;
}
function flailLayer(t, amp) { const A = {}, f = 9;
  A.LegL = [40 * Math.sin(t * f * 2) * amp, 0, 10 * amp]; A.LegR = [40 * Math.sin(t * f * 2 + 2.1) * amp, 0, -10 * amp];
  A.KneeL = [-30 - 30 * Math.sin(t * f * 2 + 1) * amp, 0, 0]; A.KneeR = [-30 - 30 * Math.sin(t * f * 2 + 3) * amp, 0, 0];
  A.ArmL = [-40 + 35 * Math.sin(t * f * 2.4) * amp, 0, 20 * amp]; A.ArmR = [-40 + 35 * Math.sin(t * f * 2.4 + 1.7) * amp, 0, -20 * amp];
  A.Jaw = [-28 - 10 * Math.sin(t * 30) * amp, 0, 0];
  A.Neck = [8 * Math.sin(t * 7), 14 * Math.sin(t * 5.3) * amp, 0]; A.Head = [6 * Math.sin(t * 9), 0, 10 * Math.sin(t * 6) * amp];
  for (let i = 1; i <= 5; i++) A["Tail" + i] = [0, 10 * Math.sin(t * 8 - i * 0.6) * amp, 0];
  return A; }
function breathe(t, amp) { const s = Math.sin(t * 2.2); return {RootJoint: [1.2 * s * amp, 0, 0], Neck: [1.6 * s * amp, 0, 0], Head: [-1 * s * amp, 0, 0], Tail2: [0, 3 * Math.sin(t * 1.3) * amp, 0], Tail3: [0, 4 * Math.sin(t * 1.3 - 0.6) * amp, 0], Tail4: [0, 5 * Math.sin(t * 1.3 - 1.2) * amp, 0], Tail5: [0, 6 * Math.sin(t * 1.3 - 1.8) * amp, 0]}; }

// key poses shared by the titles (degrees)
const P = {
  IDLE: {},
  CROUCH: BOTH({RootJoint: [-8, 0, 0], Neck: [12, 0, 0], Head: [-10, 0, 0], ArmL: [-18, 0, 0], LegL: [34, 0, 0], KneeL: [-62, 0, 0], AnkleL: [28, 0, 0], Tail1: [-8, 0, 0], Tail2: [-4, 0, 0]}),
  STALK: BOTH({RootJoint: [-10, 0, 0], Neck: [-12, 0, 0], Head: [10, 0, 0], ArmL: [-12, 0, 0], LegL: [18, 0, 0], KneeL: [-34, 0, 0], AnkleL: [14, 0, 0], Tail1: [-6, 0, 0], Tail2: [-4, 0, 0]}),
  PUSH: BOTH({RootJoint: [-6, 0, 0], Neck: [18, 0, 0], Head: [-12, 0, 0], ArmL: [-24, 0, 0], LegL: [-22, 0, 0], KneeL: [-4, 0, 0], AnkleL: [-24, 0, 0], Tail1: [-8, 0, 0]}),
  AIR: BOTH({RootJoint: [-4, 0, 0], Neck: [26, 0, 0], Head: [-22, 0, 0], Jaw: [-10, 0, 0], ArmL: [-34, 0, 0], LegL: [42, 0, 0], KneeL: [-76, 0, 0], AnkleL: [36, 0, 0], Tail1: [-10, 0, 0], Tail2: [-6, 0, 0], Tail3: [-4, 0, 0]}),
  LAND: BOTH({RootJoint: [-10, 0, 0], Neck: [-6, 0, 0], Head: [4, 0, 0], ArmL: [14, 0, 0], LegL: [30, 0, 0], KneeL: [-58, 0, 0], AnkleL: [26, 0, 0], Tail1: [8, 0, 0]}),
  ROAR_WIND: BOTH({RootJoint: [16, 0, 0], Neck: [40, 0, 0], Head: [-24, 0, 0], Jaw: [-14, 0, 0], ArmL: [-30, 0, 0], LegL: [6, 0, 0], KneeL: [-10, 0, 0], Tail1: [10, 0, 0], Tail2: [6, 0, 0]}),
  ROAR: BOTH({RootJoint: [-8, 0, 0], Neck: [-14, 0, 0], Head: [24, 0, 0], Jaw: [-50, 0, 0], ArmL: [30, 0, 0], LegL: [10, 0, 0], KneeL: [-18, 0, 0], AnkleL: [6, 0, 0], Tail1: [-14, 0, 0], Tail2: [-10, 0, 0], Tail3: [-6, 0, 0]}),
  PROUD: BOTH({RootJoint: [8, 0, 0], Neck: [22, 0, 0], Head: [-14, 0, 0], ArmL: [-22, 0, 0], Tail1: [-6, 0, 0], Tail2: [-4, 0, 0]}),
  SIT: BOTH({RootJoint: [8, 0, 0], Neck: [16, 0, 0], Head: [-10, 0, 0], ArmL: [-12, 0, 0], LegL: [58, 0, 0], KneeL: [-118, 0, 0], AnkleL: [60, 0, 0], Tail1: [16, 0, 0], Tail2: [8, 0, 0], Tail3: [4, 0, 0]}),
  PECK: BOTH({RootJoint: [-18, 0, 0], Neck: [-42, 0, 0], Head: [-16, 0, 0], Jaw: [-4, 0, 0], ArmL: [10, 0, 0], LegL: [12, 0, 0], KneeL: [-22, 0, 0], AnkleL: [8, 0, 0], Tail1: [-16, 0, 0], Tail2: [-8, 0, 0]}),
  PECK_UP: BOTH({RootJoint: [-8, 0, 0], Neck: [-14, 0, 0], Head: [-4, 0, 0], ArmL: [0, 0, 0], LegL: [8, 0, 0], KneeL: [-16, 0, 0], AnkleL: [6, 0, 0], Tail1: [-10, 0, 0], Tail2: [-6, 0, 0]}),
  LOOK_UP: BOTH({RootJoint: [8, 0, 0], Neck: [42, 0, 0], Head: [30, 0, 0], Jaw: [-30, 0, 0], ArmL: [-34, 0, 0], Tail1: [4, 0, 0]}),
  SHRUG: BOTH({RootJoint: [4, 0, 0], Neck: [8, 0, 10], Head: [-6, 0, 16], ArmL: [-62, 0, -18], Tail1: [-8, 0, 0], Tail2: [-4, 0, 0]}),
  SNIFF: BOTH({RootJoint: [-16, 0, 0], Neck: [-40, 0, 0], Head: [-8, 0, 0], ArmL: [6, 0, 0], LegL: [8, 0, 0], KneeL: [-14, 0, 0], AnkleL: [6, 0, 0], Tail1: [-12, 0, 0]}),
  STARTLED: BOTH({RootJoint: [12, 0, 0], Neck: [32, 0, 0], Head: [-10, 0, 0], Jaw: [-34, 0, 0], ArmL: [-56, 0, 0], Tail1: [-22, 0, 0], Tail2: [-12, 0, 0]}),
  CHILL: BOTH({RootJoint: [2, 0, 0], Neck: [8, -8, 0], Head: [-4, -6, 4], ArmL: [-4, 0, 0], Tail1: [4, 0, 0]}),
  HAPPY: BOTH({RootJoint: [4, 0, 0], Neck: [14, 0, 0], Head: [-6, 0, 0], Jaw: [-16, 0, 0], ArmL: [-40, 0, 0], Tail1: [-10, 0, 0], Tail2: [-6, 0, 0]}),
  FLAT: BOTH({RootJoint: [-6, 0, 0], Neck: [-10, 0, 0], Head: [4, 0, 0], Jaw: [-30, 0, 0], ArmL: [10, 0, 30], LegL: [10, 0, 22], KneeL: [-10, 0, 0], Tail1: [6, 0, 0], Tail2: [4, 0, 0]}),
};

// ---------- FX ----------
function canvasTex(w, h, draw) { const c = document.createElement("canvas"); c.width = w; c.height = h; draw(c.getContext("2d"), w, h); return new THREE.CanvasTexture(c); }
function radialTex(inner, outer, mid) { return canvasTex(128, 128, (x) => { const g = x.createRadialGradient(64, 64, 0, 64, 64, 64); g.addColorStop(0, inner); g.addColorStop(mid || 0.35, inner.replace(/[\d.]+\)$/, "0.6)")); g.addColorStop(1, outer); x.fillStyle = g; x.fillRect(0, 0, 128, 128); }); }
const T = {
  flash: radialTex("rgba(255,255,240,1)", "rgba(255,230,160,0)"),
  spark: radialTex("rgba(255,250,220,1)", "rgba(255,170,60,0)"),
  fire: radialTex("rgba(255,230,140,1)", "rgba(255,90,20,0)", 0.45),
  smoke: radialTex("rgba(255,255,255,0.9)", "rgba(255,255,255,0)", 0.5),
  star: canvasTex(128, 128, (x) => { x.translate(64, 64); x.beginPath(); for (let i = 0; i < 10; i++) { const r = i % 2 ? 24 : 58, a = -Math.PI / 2 + i * Math.PI / 5; x.lineTo(Math.cos(a) * r, Math.sin(a) * r); } x.closePath(); x.fillStyle = "#ffe14a"; x.fill(); x.lineWidth = 8; x.strokeStyle = "#a86a00"; x.stroke(); }),
  heart: canvasTex(128, 128, (x) => { x.translate(64, 70); x.beginPath(); x.moveTo(0, 40); x.bezierCurveTo(-70, -10, -40, -60, 0, -26); x.bezierCurveTo(40, -60, 70, -10, 0, 40); x.fillStyle = "#ff5a7a"; x.fill(); x.lineWidth = 7; x.strokeStyle = "#a01836"; x.stroke(); x.fillStyle = "rgba(255,255,255,.6)"; x.beginPath(); x.ellipse(-22, -18, 9, 6, -0.6, 0, Math.PI * 2); x.fill(); }),
  plus: canvasTex(128, 128, (x) => { x.fillStyle = "#3ad46a"; x.strokeStyle = "#0d5a26"; x.lineWidth = 8; x.beginPath(); x.rect(46, 14, 36, 100); x.rect(14, 46, 100, 36); x.fill(); x.stroke(); x.fillRect(50, 18, 28, 92); x.fillRect(18, 50, 92, 28); }),
  bang: canvasTex(128, 128, (x) => { x.font = "900 112px 'Trebuchet MS', sans-serif"; x.textAlign = "center"; x.lineWidth = 12; x.strokeStyle = "#2a1504"; x.strokeText("!", 64, 108); x.fillStyle = "#ffd23a"; x.fillText("!", 64, 108); }),
  petal: canvasTex(64, 128, (x) => { x.fillStyle = "#ffffff"; x.beginPath(); x.ellipse(32, 64, 20, 58, 0, 0, Math.PI * 2); x.fill(); x.strokeStyle = "#d8d8e8"; x.lineWidth = 4; x.stroke(); }),
  leaf: canvasTex(64, 64, (x) => { x.fillStyle = "#5fb04a"; x.beginPath(); x.ellipse(32, 32, 12, 28, 0.6, 0, Math.PI * 2); x.fill(); }),
};
const fx = [];
function addFx(obj, life, update) { scene.add(obj); fx.push({obj, life, t: 0, update}); return obj; }
function stepFx(dt) { for (let i = fx.length - 1; i >= 0; i--) { const f = fx[i]; f.t += dt; const u = Math.min(1, f.t / f.life); f.update && f.update(f.obj, u, dt); if (f.t >= f.life) { scene.remove(f.obj); if (f.obj.material) { f.obj.material.dispose(); } fx.splice(i, 1); } } }
function clearFx() { fx.splice(0).forEach(f => scene.remove(f.obj)); }
function sprite(tex, color, size, additive) { const s = new THREE.Sprite(new THREE.SpriteMaterial({map: tex, color: color === undefined ? 0xffffff : color, transparent: true, depthWrite: false, blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending})); s.scale.set(size, size, 1); return s; }
function flash(p, size, color, life) { const s = sprite(T.flash, color || 0xffffff, size, true); s.position.copy(p); addFx(s, life || 0.18, (o, u) => { o.scale.setScalar(size * (0.6 + u * 1.3)); o.material.opacity = 1 - u; }); }
function sparks(p, n, size, color, spd, grav) {
  for (let i = 0; i < n; i++) { const s = sprite(T.spark, color || 0xfff4c8, size * (0.6 + Math.random() * 0.7), true); s.position.copy(p);
    const a = Math.random() * Math.PI * 2, e = Math.random() * 1.3, v = V(Math.cos(a) * Math.cos(e), Math.sin(e) + 0.2, Math.sin(a) * Math.cos(e)).multiplyScalar(spd * (0.5 + Math.random()));
    addFx(s, 0.3 + Math.random() * 0.3, (o, u, dt) => { v.y -= (grav || 60) * dt; o.position.addScaledVector(v, dt); o.material.opacity = 1 - u; o.scale.setScalar(size * (1 - u)); }); }
}
function puff(p, v, size, color, life, grow, op) { const s = sprite(T.smoke, color === undefined ? 0xffffff : color, size, false); s.position.copy(p); const vv = v.clone();
  addFx(s, life || 0.7, (o, u, dt) => { vv.multiplyScalar(Math.pow(0.12, dt)); o.position.addScaledVector(vv, dt); o.scale.setScalar(size * (1 + u * (grow === undefined ? 2.2 : grow))); o.material.opacity = (op || 0.75) * (1 - u) * Math.min(1, u * 8); }); }
function dustRing(p, n, size, spd, color) { for (let i = 0; i < n; i++) { const a = i / n * Math.PI * 2 + Math.random() * 0.3; puff(p.clone().add(V(Math.cos(a) * size * 0.3, size * 0.15, Math.sin(a) * size * 0.3)), V(Math.cos(a) * spd, spd * 0.15, Math.sin(a) * spd), size, color === undefined ? 0xd9c9a0 : color, 0.8 + Math.random() * 0.3, 1.6, 0.8); } }
function shockRing(p, normal, r1, color, life, thick) {
  const m = new THREE.Mesh(new THREE.RingGeometry(1 - (thick || 0.12), 1, 48), new THREE.MeshBasicMaterial({color: color || 0xffffff, transparent: true, opacity: 0.85, depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending}));
  m.position.copy(p); m.lookAt(p.clone().add(normal));
  addFx(m, life || 0.45, (o, u) => { o.scale.setScalar(0.2 + r1 * E.out(u)); o.material.opacity = 0.6 * (1 - u); o.position.addScaledVector(normal, r1 * 0.02); });
}
function iconPop(tex, p, size, life, rise) { const s = sprite(tex, 0xffffff, size, false); s.position.copy(p); s.renderOrder = 5;
  addFx(s, life, (o, u, dt) => { const k = u < 0.18 ? E.back(u / 0.18) : 1; o.scale.setScalar(size * k); o.position.y += (rise || 0) * dt; o.material.opacity = u > 0.8 ? (1 - u) / 0.2 : 1; }); return s; }
// rigid debris: rocks / petals / props that fall and bounce
const debris = [];
function addDebris(mesh, v, w, opt) { opt = opt || {}; scene.add(mesh); debris.push({mesh, v, w, life: opt.life || 3, t: 0, bounce: opt.bounce === undefined ? 0.35 : opt.bounce, grav: opt.grav === undefined ? 70 : opt.grav, r: opt.r || 0.5, drag: opt.drag || 0, flutter: opt.flutter || 0, fade: opt.fade !== false}); }
function stepDebris(dt) {
  for (let i = debris.length - 1; i >= 0; i--) { const d = debris[i]; d.t += dt;
    d.v.y -= d.grav * dt; if (d.drag) d.v.multiplyScalar(Math.pow(1 - d.drag, dt * 60));
    if (d.flutter) { d.v.x += Math.sin(d.t * 7 + i) * d.flutter * dt; d.v.z += Math.cos(d.t * 5 + i) * d.flutter * dt; }
    d.mesh.position.addScaledVector(d.v, dt);
    d.mesh.rotation.x += d.w.x * dt; d.mesh.rotation.y += d.w.y * dt; d.mesh.rotation.z += d.w.z * dt;
    if (d.mesh.position.y < d.r) { d.mesh.position.y = d.r; if (d.v.y < 0) { d.v.y = -d.v.y * d.bounce; d.v.x *= 0.6; d.v.z *= 0.6; d.w.multiplyScalar(0.6); if (Math.abs(d.v.y) < 2) { d.v.y = 0; d.w.multiplyScalar(0.8); } } }
    if (d.fade && d.t > d.life - 0.5) { d.mesh.traverse(o => { if (o.material) { o.material.transparent = true; o.material.opacity = Math.max(0, (d.life - d.t) / 0.5); } }); }
    if (d.t >= d.life) { scene.remove(d.mesh); debris.splice(i, 1); } }
}
function clearDebris() { debris.splice(0).forEach(d => scene.remove(d.mesh)); }
function rock(size, color) { const m = new THREE.Mesh(new THREE.IcosahedronGeometry(size, 0), new THREE.MeshLambertMaterial({color: color || 0x6b5a4a, flatShading: true})); m.castShadow = true; return m; }

// ---------- props ----------
function mesh(geo, color, opt) { const m = new THREE.Mesh(geo, (opt && opt.basic) ? new THREE.MeshBasicMaterial({color}) : new THREE.MeshLambertMaterial(Object.assign({color}, (opt && opt.mat) || {}))); m.castShadow = !(opt && opt.noShadow); m.receiveShadow = true; return m; }
const bx = (w, h, d, color, opt) => mesh(new THREE.BoxGeometry(w, h, d), color, opt);
function textBoard(w, h, draw) { return new THREE.MeshLambertMaterial({map: canvasTex(w, h, draw)}); }

// ---------- camera ----------
// keys: [[t, pos[x,y,z] in U, look[x,y,z] in U, ease?]] relative to the stage origin
const camState = {shake: 0, fov: 36, fovKick: 0};
function camKeys(t, keys, U, o, lookOverride, lookW) {
  const p = kv(t, keys.map(k => [k[0], k[1], k[3]])), l = kv(t, keys.map(k => [k[0], k[2], k[3]]));
  cam.position.set(o.x + p[0] * U, o.y + p[1] * U, o.z + p[2] * U);
  const look = V(o.x + l[0] * U, o.y + l[1] * U, o.z + l[2] * U);
  if (lookOverride) look.lerp(lookOverride, lookW === undefined ? 1 : lookW);
  if (camState.shake > 0) { const s = camState.shake * U * 0.03; cam.position.add(V((Math.random() - .5) * s, (Math.random() - .5) * s, (Math.random() - .5) * s)); look.add(V((Math.random() - .5) * s, (Math.random() - .5) * s, 0)); }
  cam.lookAt(look);
}

// auto framing: keep a box of points in view from a given direction (smoothed); used where the action moves around
const camF = {t: null, d: 0};
function camFrame(box, dir, dt, pad, minR) {
  const c = box.getCenter(V(0, 0, 0)), r = Math.max(minR || 0, box.getSize(V(0, 0, 0)).length() / 2) * (pad || 1);
  const vf = rad(cam.fov / 2), hf = Math.atan(Math.tan(vf) * cam.aspect), d = r / Math.tan(Math.min(vf, hf));
  if (!camF.t) { camF.t = c.clone(); camF.d = d; } else { const k = 1 - Math.exp(-dt * 3.2); camF.t.lerp(c, k); camF.d = lerp(camF.d, d, k); }
  cam.position.copy(camF.t).addScaledVector(dir.clone().normalize(), camF.d);
  const look = camF.t.clone();
  if (camState.shake > 0) { const s = camState.shake * camF.d * 0.012; cam.position.add(V((Math.random() - .5) * s, (Math.random() - .5) * s, (Math.random() - .5) * s)); }
  cam.lookAt(look);
}
// key-framed shot on a framed box: keys [[t, dir[x,y,z] (from the target to the camera), zoom (1 = the whole box fits),
// yBias (× box height), headW (0..1 pull the target to the head), ease?]]; smoothed so the camera glides; c.camHold freezes it
function camShot(c, t, dt, keys, box, head, over, overW) {
  if (c.camHold && camF.t) { const s = camState.shake * camF.d * 0.012; cam.position.copy(c.camHoldPos).add(V((Math.random() - .5) * s, (Math.random() - .5) * s, (Math.random() - .5) * s)); cam.lookAt(c.camHoldLook); return; }
  const dir = V(...kv(t, keys.map(k => [k[0], k[1], k[5]]))).normalize(), zoom = kf(t, keys.map(k => [k[0], k[2], k[5]])), yb = kf(t, keys.map(k => [k[0], k[3] || 0, k[5]])), hw = kf(t, keys.map(k => [k[0], k[4] || 0, k[5]]));
  const ctr = box.getCenter(V(0, 0, 0)), size = box.getSize(V(0, 0, 0)), rr = size.length() / 2;
  if (head) ctr.lerp(head, hw);
  // yBias and the "over" point only tilt the look; the camera stays put relative to the subject (low shots look up)
  const lk = ctr.clone(); lk.y += yb * size.y; if (over) lk.lerp(over, overW || 0);
  const vf = rad(cam.fov / 2), hf = Math.atan(Math.tan(vf) * cam.aspect), d = rr / Math.tan(Math.min(vf, hf)) * zoom;
  if (!camF.t || c.camSnap) { camF.t = ctr.clone(); camF.lk = lk.clone(); camF.d = d; c.camSnap = false; }
  else { const k = 1 - Math.exp(-dt * 4); camF.t.lerp(ctr, k); camF.lk.lerp(lk, k); camF.d = lerp(camF.d, d, k); }
  cam.position.copy(camF.t).addScaledVector(dir, camF.d);
  const look = camF.lk.clone(), right = dir.clone().cross(V(0, 1, 0)).normalize(), off = -0.16 * camF.d * Math.tan(hf); // subject a little right of centre, clear of the title
  cam.position.addScaledVector(right, -off); look.addScaledVector(right, -off);
  if (camState.shake > 0) { const s = camState.shake * camF.d * 0.012; cam.position.add(V((Math.random() - .5) * s, (Math.random() - .5) * s, (Math.random() - .5) * s)); }
  cam.lookAt(look); c.camHoldPos = cam.position.clone(); c.camHoldLook = look;
}
