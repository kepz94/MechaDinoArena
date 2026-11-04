// Dilo kit mockup app v0.1 (built on therizino_kit_options v0.2 / v0.3): keyframed moves through springs (wind-up, snap,
// follow-through, settle), feet planted, frill folded at rest and snapping open on an attack, throat sac swell, soft-aim
// cone, venom glob / spray / dart projectiles, hit-stop, camera shake, splashes, venom drips, damage numbers.
// DILO = DiloModelData 1.0 (look E, Bruiser Face) as exported in dilo_model_options.html; RAPTOR = model_json export (target).
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

const dilo = buildDino(DILO, 2);
const P_ = n => dilo.parts.find(p => p.name === n);
const mouthParts = {tip: P_("Head_tip"), skull: P_("Head_skull"), mouth: P_("Head_mouth"), jaw: P_("Jaw_lower")};
const diloFeet = dilo.parts.filter(p => p.seg.startsWith("Foot"));
// frill hub (Neck segment space): the open frill grows out from here when it snaps open
const frillHub = (() => { const v = new THREE.Vector3(), q = new THREE.Vector3(); let n = 0; for (const p of dilo.parts) if (p.kind === "frill" && /[LR]\d?a$|[LR]\da$/.test(p.name)) { q.setFromMatrixPosition(p.local); v.add(q); n++; } v.divideScalar(Math.max(1, n)); v.z = 0; return v; })();
function mouthPoint() { // between the upper and lower jaw tips, pushed a little forward
  const a = partPoint(mouthParts.tip), s = partPoint(mouthParts.skull), j = partPoint(mouthParts.jaw);
  const dir = a.clone().sub(s).normalize();
  return a.clone().lerp(j, 0.35).addScaledVector(dir, 1.6);
}
function headDir() { return partPoint(mouthParts.tip).sub(partPoint(mouthParts.skull)).normalize(); }

const raps = [0, 1].map(() => { const r = buildDino(RAPTOR, 2); return {rig: r, pos: new THREE.Vector3(), yaw: 0, flinch: 0, side: 0, flash: 0, flashCol: [0.9, 0.1, 0.05], push: 0, pushDir: new THREE.Vector3(), venom: null, slow: 0, runPh: 0, run: 0, path: null, show: false}; });
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

// ---------- moves ----------
// Every track: keys (dilo pose), frill [[open, close]], sac [[a, b]] (throat sac swell), ev [{t, f}], update(t, dt) for
// continuous things (spray, meters, a fleeing target), cap [[t, text]] (stage caption), hud, frame (camera framing points).
const R0 = raps[0], R1 = raps[1];
function place(R, x, z, yaw) { R.show = true; R.pos.set(x, 0, z); R.yaw = yaw; R.path = null; R.run = 0; }
const LEAP = {T0: 0.28, AIR: 0.72, DIST: 30, H: 10};
const LEAP2 = {T0: 0.28, AIR: 0.86, DIST: 30, H: 12};
let leapCfg = LEAP;
function leapOffset(t) {
  const u = (t - leapCfg.T0) / leapCfg.AIR;
  if (u <= 0) return {fwd: 0, up: 0, air: false};
  if (u >= 1) return {fwd: leapCfg.DIST, up: 0, air: false};
  return {fwd: leapCfg.DIST * (u * 0.8 + E.out(u) * 0.2), up: 4 * leapCfg.H * u * (1 - u), air: true};
}
const aim = {on: 0, R: null, cone: null, yaw: 0};
function aimAt(R, cone, on) { aim.R = R; aim.cone = cone; aim.on = on; }

function venomHit(R, p, dmg, ven, power) {
  hitStop = 0.085; shake = Math.max(shake, 0.75); fovPunch = 1.8;
  splash(p, Math.round(26 * power), power);
  numberPop(p.clone().add(new THREE.Vector3(0, 5, 0)), dmg, "hit");
  R.flinch = 1; R.side = 0; R.flash = 0.14; R.flashCol = [0.35, 0.95, 0.15]; R.push = 1.4; R.pushDir.copy(p).sub(dilo.pos).setY(0).normalize();
  if (ven) R.venom = {left: ven.dur, rate: ven.rate, next: 1, drip: 0};
  const v = $("vig"); v.style.transition = "none"; v.style.opacity = 0.35; requestAnimationFrame(() => { v.style.transition = "opacity .4s"; v.style.opacity = 0; });
}

const TRACKS = {
  A() {
    place(R0, -8, -40, 0); R0.yaw = yawTo(R0.pos, dilo.pos) - 1.25;
    place(R1, 23, -17, 0); R1.yaw = yawTo(R1.pos, dilo.pos) + 0.5;
    const REL = 0.4;
    return {kind: "attack", len: 4.6, frame: [new THREE.Vector3(0, 0, 0), R0.pos.clone()],
      keys: [{t: 0, pose: READY}, {t: 0.24, pose: A_WIND, e: "io"}, {t: 0.34, pose: A_HOLD, e: "io"}, {t: REL, pose: A_SPIT, e: "in2"}, {t: 0.56, pose: A_FOLLOW, e: "out"}, {t: 1.15, pose: READY, e: "io"}],
      frill: [[0.12, 1.25]], sac: [[0.08, 0.42]], tremble: [0.26, 0.36],
      ev: [{t: 0, f: () => { hud.press = 0.3; aimAt(R0, aimCone.A, 1); }},
           {t: REL, f: () => { hud.charges--; hud.refill = 0; const from = mouthPoint();
              spawnShot({kind: "glob", from, target: () => rapChest(R0), T: 0.62, H: 7, onHit: p => { venomHit(R0, p, 12, {rate: 3, dur: 3}, 1); aim.on = 0; }}); }}],
      cap: [[0, "<b>Tap ATTACK</b> · soft aim: the closest enemy in the 30° cone (the other raptor is outside it)"], [0.12, "Rears back · <b>frill snaps open</b> · throat sac swells"], [REL, "<b>Spit!</b> A venom glob lobbed in an arc, ~40 studs"], [1.02, "<b>Splat: 12</b> + venom 3/s for 3 s (green drip) · pip refills in 2.5 s"], [1.3, "Frill folds back · venom ticking: 3 · 3 · 3"]],
      hud: {mode: "pips", hint: "Tap ATTACK", what: "3 charges (pips) · 1 refills per 2.5 s"}};
  },
  B() {
    place(R0, -4, -18, 0); R0.yaw = yawTo(R0.pos, dilo.pos) + 1.45;
    place(R1, 5, -27, 0); R1.yaw = yawTo(R1.pos, dilo.pos) + 1.6;
    const S0 = 0.2, S1 = 2.0;
    let tick = S0 + 0.12, em = 0;
    return {kind: "attack", len: 3.7, frame: [new THREE.Vector3(0, 0, 2), new THREE.Vector3(0, 0, -28)],
      keys: [{t: 0, pose: READY}, {t: 0.16, pose: B_SET, e: "out"}, {t: S1, pose: B_SET, e: "io"}, {t: S1 + 0.5, pose: READY, e: "io"}],
      frill: [[0.08, S1 + 0.25]], sac: [[0.04, 0.3]], sway: [S0, S1],
      ev: [{t: 0, f: () => { hud.held = true; }}, {t: S1, f: () => { hud.held = false; }}],
      update(t, dt) {
        setCone(sprayCone, t > 0.1 && t < S1 + 0.3, Math.min(1, (t - 0.1) / 0.15) * (t > S1 ? Math.max(0, 1 - (t - S1) / 0.3) : 1));
        { const m0 = mouthPoint(); sprayCone.position.set(m0.x, 0.09, m0.z); } // the cone starts at the mouth
        if (t > S0 && t < S1) { // meter drains (2 s full); droplets stream out of the mouth inside the cone
          hud.meter = Math.max(0, 1 - (t - S0) / 2.0);
          em += dt * 170; const m = mouthPoint(), hd = headDir(); const base = Math.atan2(hd.x, hd.z);
          if (Math.random() < dt * 30) { const c = sprite(T_DROP, 0xd8ffa0, 3.2 + Math.random() * 1.5, true); c.position.copy(m); addFx(c, 0.12, (o, u) => { o.material.opacity = 1 - u; }); }
          while (em >= 1) { em -= 1; const a = base + rad((Math.random() - .5) * 38), e = rad(-4 + (Math.random() - .5) * 10), sp = 40 + Math.random() * 16;
            droplet(m.clone(), new THREE.Vector3(Math.sin(a) * Math.cos(e) * sp, Math.sin(e) * sp, Math.cos(a) * Math.cos(e) * sp), 0.9 + Math.random() * 1.0, 0.36 + Math.random() * 0.1, 26);
            if (Math.random() < 0.35) { const s = sprite(T_MIST, 0xffffff, 2, false); s.position.copy(m); const v = new THREE.Vector3(Math.sin(a) * sp * 0.42, 0.5, Math.cos(a) * sp * 0.42); addFx(s, 0.6, (o, u, dd) => { o.position.addScaledVector(v, dd); o.scale.setScalar(2.2 + u * 8); o.material.opacity = 0.5 * (1 - u); }); } }
          if (t >= tick) { tick += 0.25; for (const R of [R0, R1]) { const p = rapChest(R); numberPop(p.clone().add(new THREE.Vector3((Math.random() - .5) * 3, 4, 0)), 4, "venom"); R.flinch = Math.max(R.flinch, 0.45); R.flash = 0.08; R.flashCol = [0.3, 0.9, 0.12]; R.slow = 1.2;
            if (!R.tagged) { R.tagged = true; textTag(p.clone().add(new THREE.Vector3(0, 13, 0)), "SLOWED −30%", "#a8f0ff", 2.4); } }
            hitStop = Math.max(hitStop, 0.02); shake = Math.max(shake, 0.25); }
        } else if (t >= S1) hud.meter = Math.min(1, hud.meter + dt / 3.0 * (t > S1 + 0.5 ? 1 : 0));
      },
      cap: [[0, "<b>Hold ATTACK</b>"], [0.08, "<b>Frill snaps open</b>, jaw gapes"], [S0, "<b>Spraying</b>: 4 every 0.25 s to everything in the green cone (18 studs, 40°) · <b>slowed 30%</b>"], [S1, "Let go (or the 2 s meter runs out) · frill folds · meter refills"]],
      hud: {mode: "meter", hint: "Hold ATTACK", what: "spit meter (ring): 2 s of spray, refills"}};
  },
  C() {
    place(R0, -1.5, -23.5, 0); R0.yaw = yawTo(R0.pos, dilo.pos);
    place(R1, 26, -24, 0); R1.yaw = yawTo(R1.pos, dilo.pos) + 0.7;
    const end = new THREE.Vector3(-11, 0, -46);
    R0.path = [[0.62, R0.pos.clone(), R0.yaw, 0], [0.78, R0.pos.clone().add(new THREE.Vector3(-0.5, 0, -2)), yawTo(R0.pos, end), 0.6], [1.32, end.clone(), yawTo(R0.pos, end), 1], [1.55, end.clone(), yawTo(end, dilo.pos) + 1.2, 0]];
    const H0 = 0.86, REL = 1.4;
    return {kind: "attack", len: 6.2, frame: [new THREE.Vector3(0, 0, 0), end.clone()],
      keys: [{t: 0, pose: READY}, {t: 0.1, pose: C_BWIND, e: "io"}, {t: 0.17, pose: C_BITE, e: "in2"}, {t: 0.32, pose: addPose(C_BITE, {Neck: [6, 0, 0]}, 1), e: "out"}, {t: 0.7, pose: READY, e: "io"},
             {t: H0 + 0.3, pose: C_COIL, e: "io"}, {t: REL - 0.02, pose: addPose(C_COIL, {Neck: [3, 0, 0], Head: [-2, 0, 0]}, 1), e: "io"}, {t: REL + 0.05, pose: C_DART, e: "in2"}, {t: REL + 0.25, pose: addPose(C_DART, {Neck: [-4, 0, 0]}, 1), e: "out"}, {t: REL + 0.8, pose: READY, e: "io"}],
      frill: [[H0 + 0.08, REL + 0.75]], sac: [[H0 + 0.05, REL + 0.05]], tremble: [REL - 0.2, REL],
      ev: [{t: 0, f: () => { hud.press = 0.25; }},
           {t: 0.16, f: () => { const p = partPoint(R0.rig.segs.Head[0]).add(new THREE.Vector3(0, 0, 1)); hitStop = 0.08; shake = 0.8; fovPunch = 2; flash(p, 10); sparks(p, new THREE.Vector3(0, 0.3, -1), 14);
              numberPop(p.clone().add(new THREE.Vector3(0, 5, 0)), 10, "hit"); R0.flinch = 1; R0.side = 1; R0.flash = 0.12; R0.flashCol = [0.9, 0.1, 0.05]; R0.push = 1.2; R0.pushDir.set(0, 0, -1); }},
           {t: H0, f: () => { hud.held = true; aimAt(R0, aimCone.C, 1); }},
           {t: REL, f: () => { hud.held = false; hud.hold = 0; const from = mouthPoint();
              spawnShot({kind: "dart", from, target: () => rapChest(R0), T: 0.24, H: 0.4, onHit: p => { venomHit(R0, p, 8, {rate: 2, dur: 4}, 0.7); aim.on = 0; }}); }}],
      update(t, dt) { if (hud.held) hud.hold = Math.min(1, (t - H0) / 0.4); },
      cap: [[0, "<b>Tap ATTACK: bite</b> (close range, frill stays folded)"], [0.2, "<b>Bite: 10</b> · the raptor runs"], [H0, "<b>Hold ATTACK</b>: neck coils, <b>frill snaps open</b>, ring fills · soft aim locks the closest raptor in the 30° cone"], [REL, "<b>Let go: spit dart</b>, fast and straight, ~60 studs"], [REL + 0.3, "<b>Dart: 8</b> + venom 2/s for 4 s"]],
      hud: {mode: "hold", hint: "Tap = bite · Hold + let go = dart", what: "ring = hold charge (0.4 s)"}};
  },
  J1() {
    R0.show = false; R1.show = false; leapCfg = LEAP;
    const t1 = LEAP.T0 + LEAP.AIR;
    return {kind: "jump", leap: true, len: 2.3, frame: [new THREE.Vector3(0, 0, 4), new THREE.Vector3(0, 0, -LEAP.DIST - 4)],
      keys: [{t: 0, pose: READY}, {t: LEAP.T0, pose: J_CROUCH, e: "io"}, {t: LEAP.T0 + 0.1, pose: J_PUSH, e: "out"}, {t: LEAP.T0 + 0.3, pose: J_AIR, e: "io"}, {t: t1 - 0.14, pose: J_AIR, e: "io"},
             {t: t1 - 0.02, pose: J_DOWN, e: "io"}, {t: t1 + 0.12, pose: J_LAND, e: "out"}, {t: t1 + 0.7, pose: READY, e: "io"}],
      frill: [[0.16, t1 + 0.32]], sac: [],
      ev: [{t: 0, f: () => { hud.jpress = 0.3; }}, {t: t1, f: () => { textTag(dilo.pos.clone().add(new THREE.Vector3(0, 1.5, -4)), "plain landing", "#ffffff", 1.1); }}],
      cap: [[0, "<b>Tap JUMP</b>: crouch, neck coils back like a cobra, <b>frill flares</b>"], [LEAP.T0, "<b>Cobra Leap</b>: ~30 studs forward"], [t1, "<b>Plain landing</b>: no dust, no shockwave (house rule) · frill folds"]],
      hud: {mode: "jump", hint: "Tap JUMP", what: "no damage: it is a get-away / close-the-gap move"}};
  },
  J2() {
    leapCfg = LEAP2;
    const t1 = LEAP2.T0 + LEAP2.AIR, top = LEAP2.T0 + LEAP2.AIR * 0.42;
    place(R0, -7, -53, 0); R0.yaw = yawTo(R0.pos, dilo.pos) + 1.2; R1.show = false;
    return {kind: "jump", leap: true, len: 4.6, frame: [new THREE.Vector3(0, 0, 4), new THREE.Vector3(0, 0, -54)],
      keys: [{t: 0, pose: READY}, {t: LEAP2.T0, pose: J_CROUCH, e: "io"}, {t: LEAP2.T0 + 0.1, pose: J_PUSH, e: "out"}, {t: top - 0.1, pose: J_AIR, e: "io"}, {t: top + 0.02, pose: J2_SPIT, e: "in2"}, {t: top + 0.2, pose: J2_SPIT, e: "out"}, {t: t1 - 0.12, pose: J_AIR, e: "io"},
             {t: t1 - 0.02, pose: J_DOWN, e: "io"}, {t: t1 + 0.12, pose: J_LAND, e: "out"}, {t: t1 + 0.7, pose: READY, e: "io"}],
      frill: [[0.16, t1 + 0.32]], sac: [[top - 0.18, top + 0.02]],
      ev: [{t: 0, f: () => { hud.jpress = 0.3; aimAt(R0, aimCone.J, 1); }},
           {t: top, f: () => { const from = mouthPoint(); spawnShot({kind: "glob", from, target: () => rapChest(R0).setY(3), T: 0.4, H: 1, onHit: p => { venomHit(R0, p, 8, {rate: 2, dur: 3}, 0.9); aim.on = 0; }}); }},
           {t: t1, f: () => { textTag(dilo.pos.clone().add(new THREE.Vector3(0, 1.5, -4)), "plain landing", "#ffffff", 1.1); }}],
      cap: [[0, "<b>Tap JUMP</b>: crouch, neck coils, <b>frill flares</b>"], [LEAP2.T0, "Leap · soft aim picks the raptor in the 30° cone"], [top, "<b>Top of the leap: spits one glob</b> down and forward"], [top + 0.4, "<b>Splat: 8</b> + venom 2/s for 3 s"], [t1, "<b>Plain landing</b>: no dust, no shockwave · frill folds"]],
      hud: {mode: "jump", hint: "Tap JUMP", what: "the spit fires by itself at the top"}};
  },
};

// ---------- state ----------
let attack = "A", jump = "J1", camMode = "hero", slowMo = false, seq = "attack";
let play = null, hitStop = 0, shake = 0, clockT = 0, idleT = 0, fovPunch = 0, frill = {open: false, t: 9};
const hud = {mode: "pips", charges: 3, refill: 1, meter: 1, hold: 0, held: false, press: 0, jpress: 0};
function resetFx() { fx.splice(0).forEach(e => scene.remove(e.obj)); shots.splice(0).forEach(s => { scene.remove(s.mesh); scene.remove(s.glow); }); }
function start(kind) {
  resetFx();
  seq = kind;
  const key = kind === "attack" ? attack : jump;
  for (const R of raps) { R.flinch = 0; R.flash = 0; R.push = 0; R.venom = null; R.slow = 0; R.tagged = false; R.path = null; R.run = 0; }
  leapCfg = LEAP;
  const track = TRACKS[key]();
  play = {track, t: 0, fired: new Set(), key, kind, cap: -1};
  Object.assign(hud, {mode: track.hud.mode, held: false, hold: 0, press: 0, jpress: 0, meter: 1, charges: 3, refill: 1});
  frill.open = false; frill.t = 9; dilo.sac = 1;
  for (const k in aimCone) aimCone[k].visible = false; sprayCone.visible = false;
  aim.on = 0; aim.R = null; aim.cone = null;
  $("hudHint").textContent = track.hud.hint; $("hudWhat").textContent = track.hud.what;
  $("tag").textContent = (kind === "attack" ? "Attack " : "Jump ") + key + " · " + INFO[key].name;
  dilo.pos.set(0, 0, 0); rootSpring.x = 0; rootSpring.v = 0;
}
function idleLayer(t) {
  const b = Math.sin(t * 2.1), b2 = Math.sin(t * 2.1 + 1.2);
  return {RootJoint: [b * 1.0, 0, 0], Neck: [b * 1.6, Math.sin(t * 0.7) * 4, 0], Head: [-b * 1.4, Math.sin(t * 0.9 + 1) * 3, 0], Jaw: [Math.max(0, Math.sin(t * 0.5)) * -3, 0, 0],
    ArmL: [b2 * 3, 0, 0], ArmR: [b2 * 3, 0, 0],
    Tail1: [b * 1.2, Math.sin(t * 1.3) * 4, 0], Tail2: [0, Math.sin(t * 1.3 - .6) * 5, 0], Tail3: [0, Math.sin(t * 1.3 - 1.2) * 6, 0], Tail4: [0, Math.sin(t * 1.3 - 1.8) * 7, 0], Tail5: [0, Math.sin(t * 1.3 - 2.4) * 8, 0]};
}
function inWin(list, t) { return (list || []).some(([a, b]) => t >= a && t < b); }
function frillScale() { // open: grows out of the hub with an overshoot (+ a short rattle); closing: shrinks, then the folded blocks show
  if (frill.open) { const u = Math.min(1, frill.t / 0.13); let s = 0.2 + 0.8 * E.back(u); if (frill.t < 0.3) s += Math.sin(frill.t * 95) * 0.035 * (1 - frill.t / 0.3); return s; }
  return frill.t < 0.1 ? 1 - 0.75 * (frill.t / 0.1) : 0;
}

function rapPose(R, dt) {
  R.rig.g.visible = R.show; if (!R.show) return;
  const tt = play ? play.t : 0;
  if (R.path && play) { // keyed path: [t, pos, yaw, run]
    const P = R.path; let i = 0; while (i < P.length - 1 && tt > P[i + 1][0]) i++;
    if (tt <= P[0][0]) { R.pos.copy(P[0][1]); R.yaw = P[0][2]; R.run = P[0][3]; }
    else if (i >= P.length - 1) { R.pos.copy(P[P.length - 1][1]); R.yaw = P[P.length - 1][2]; R.run = 0; }
    else { const a = P[i], b = P[i + 1], u = (tt - a[0]) / (b[0] - a[0]); R.pos.lerpVectors(a[1], b[1], u); let dy = b[2] - a[2]; while (dy > Math.PI) dy -= 2 * Math.PI; while (dy < -Math.PI) dy += 2 * Math.PI; R.yaw = a[2] + dy * E.io(Math.min(1, u * 1.6)); R.run = a[3] + (b[3] - a[3]) * u; }
  }
  const slowK = R.slow > 0 ? 0.55 : 1;
  R.flinch = Math.max(0, R.flinch - dt * 2.6); R.flash = Math.max(0, R.flash - dt); R.push *= Math.pow(0.03, dt); R.slow = Math.max(0, R.slow - dt);
  R.runPh += dt * 15 * R.run;
  const f = E.out(R.flinch), s = Math.sin(R.runPh), c = Math.cos(R.runPh), rn = R.run;
  const ct = clockT * slowK;
  R.rig.yaw = R.yaw; R.rig.pos.copy(R.pos).addScaledVector(R.pushDir, R.push);
  pose(R.rig, {RootJoint: [10 * f - 6 * rn, 0, R.side * 8 * f], Neck: [12 * f - 4 * rn, R.side * -18 * f + Math.sin(ct * 0.8) * 4 * (1 - f), 0], Head: [10 * f, 0, 0], Jaw: [-22 * f, 0, 0],
    ArmL: [-25 * f, 0, 0], ArmR: [-25 * f, 0, 0], Tail1: [-10 * f, Math.sin(ct * 1.3) * 4, 0], Tail2: [0, Math.sin(ct * 1.3 - .7) * 5, 0],
    LegL: [-8 * f + 34 * s * rn, 0, 0], LegR: [-8 * f - 34 * s * rn, 0, 0], KneeL: [-10 * f - (18 + 22 * Math.max(0, c)) * rn, 0, 0], KneeR: [-10 * f - (18 + 22 * Math.max(0, -c)) * rn, 0, 0]});
  if (R.rig.rest !== null) { R.rig.y = R.rig.rest + Math.abs(c) * 1.2 * rn; pose(R.rig, {}); }
  // venom on it: a green pulse, droplets dripping off the body (they fade before they reach the ground), ticks every second
  let g = 0;
  if (R.venom) { const V = R.venom; V.left -= dt; V.next -= dt; V.drip += dt * 20; g = 0.1 + 0.06 * Math.sin(clockT * 9);
    while (V.drip >= 1) { V.drip -= 1; const part = R.rig.parts[(Math.random() * R.rig.parts.length) | 0]; const p = partPoint(part); if (p.y > 3) droplet(p, new THREE.Vector3((Math.random() - .5) * 2, -3, (Math.random() - .5) * 2), 0.9 + Math.random() * 0.7, 0.6, 30); }
    if (V.next <= 0 && V.left > -0.05) { V.next += 1; numberPop(rapChest(R).add(new THREE.Vector3((Math.random() - .5) * 3, 5, 0)), V.rate, "venom"); R.flash = 0.06; R.flashCol = [0.3, 0.9, 0.12]; }
    if (V.left <= 0) R.venom = null; }
  if (R.slow > 0) g = Math.max(g, 0.12);
  const fl = R.flash > 0 ? 1 : 0;
  R.rig.mats.forEach(m => m.emissive.setRGB(fl * R.flashCol[0] + (1 - fl) * g * 0.25, fl * R.flashCol[1] + (1 - fl) * g, fl * R.flashCol[2] + (1 - fl) * g * 0.1));
}
// the raptor rig was posed once with d.rest === null to find its rest offset; do that now
raps.forEach(R => { pose(R.rig, {}); R.rig.y = R.rig.rest; R.rig.g.visible = false; });

function step(dt) {
  if (slowMo) dt *= 0.3;
  let mdt = dt;
  if (hitStop > 0) { hitStop -= dt; mdt = dt * 0.05; }
  idleT += mdt; clockT += mdt;
  let target = idleLayer(idleT), leap = {fwd: 0, up: 0, air: false}, rootFwd = 0;
  const tr = play && play.track;
  if (play) {
    play.t = Math.min(play.t + mdt, tr.len);
    const mv = sample(tr.keys, play.t);
    target = addPose(mv, target, 1);
    if (tr.tremble && play.t > tr.tremble[0] && play.t < tr.tremble[1]) for (const n of ["Neck", "Head"]) target[n] = target[n].map((v, i) => v + (i === 0 ? Math.sin(clockT * 80 + n.length) * 1.6 : 0));
    if (tr.sway && play.t > tr.sway[0] && play.t < tr.sway[1]) { const w = Math.sin((play.t - tr.sway[0]) * 6.5) * 7; target.Neck = target.Neck.map((v, i) => i === 1 ? v + w : v); target.Head = target.Head.map((v, i) => i === 1 ? v + w * 0.6 : v); }
    rootFwd = (mv.root && mv.root.fwd) || 0;
    if (tr.leap) leap = leapOffset(play.t);
    for (const e of tr.ev) { const k = "e" + e.t; if (!play.fired.has(k) && play.t >= e.t) { play.fired.add(k); e.f(); } }
    if (tr.update) tr.update(play.t, mdt);
    // caption
    let ci = -1; tr.cap.forEach((c, i) => { if (play.t >= c[0]) ci = i; });
    if (ci !== play.cap) { play.cap = ci; $("cap").innerHTML = ci >= 0 ? tr.cap[ci][1] : ""; }
    const want = inWin(tr.frill, play.t); if (want !== frill.open) { frill.open = want; frill.t = 0; }
    dilo.sac = 1 + 0.55 * (inWin(tr.sac, play.t) ? 1 : 0);
    if (play.t >= tr.len && !window.__manual) { if (seq === "attack") start("jump"); else start("attack"); }
  }
  // soft aim: head turns toward the chosen target (yaw), the cone + line + ring show who gets the shot
  let aimYaw = 0;
  if (aim.R && aim.R.show) { const rp = aim.R.rig.pos; aimYaw = deg(yawTo(dilo.pos, rp)); }
  aim.yaw += ((aim.on ? aimYaw : 0) - aim.yaw) * Math.min(1, dt * 12);
  target.Neck = (target.Neck || [0, 0, 0]).map((v, i) => i === 1 ? v + aim.yaw * 0.4 : v); target.Head = (target.Head || [0, 0, 0]).map((v, i) => i === 1 ? v + aim.yaw * 0.35 : v);
  frill.t += mdt; dilo.frillS = frillScale();
  const fs = Math.max(0.001, dilo.frillS);
  dilo.frillM.makeTranslation(frillHub.x, frillHub.y, frillHub.z).multiply(new THREE.Matrix4().makeScale(fs, fs, fs)).multiply(new THREE.Matrix4().makeTranslation(-frillHub.x, -frillHub.y, -frillHub.z));
  const P = springStep(target, mdt);
  for (let i = 0, n = Math.max(1, Math.ceil(mdt * 300)); i < n; i++) { const h = mdt / n; rootSpring.v += (400 * (rootFwd - rootSpring.x) - 2 * 0.9 * 20 * rootSpring.v) * h; rootSpring.x += rootSpring.v * h; }
  dilo.yaw = 0;
  dilo.pos.set(0, 0, -(rootSpring.x + leap.fwd));
  // feet stay on the ground (the crouch comes from the legs); in the air the leap arc lifts the body
  dilo.y = 0; pose(dilo, P);
  let minY = Infinity;
  for (const p of diloFeet) for (let i = 0; i < 8; i++) { _c.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(p.mesh.matrix); minY = Math.min(minY, _c.y); }
  dilo.y = -minY + leap.up; pose(dilo, P);
  raps.forEach(R => rapPose(R, mdt));
  // aim decals
  const aimFade = Math.min(1, aim.on);
  for (const k in aimCone) { const g = aimCone[k]; const on = aim.on && aim.cone === g; setCone(g, on, aimFade); if (on) { g.position.x = dilo.pos.x; g.position.z = dilo.pos.z; } }
  if (aim.on && aim.R && aim.R.show) {
    const a = dilo.pos.clone(), b = aim.R.rig.pos.clone(); const L = a.distanceTo(b) - 6;
    aimLine.visible = true; aimLine.scale.set(1, Math.max(0.1, L - 8), 1); dashTex.repeat.set(1, Math.max(1, (L - 8) / 3.2)); dashTex.offset.y = -clockT * 2.2; aimLineG.position.set(a.x, 0.11, a.z); aimLineG.rotation.y = yawTo(a, b); aimLine.position.set(0, 0, -(8 + (L - 8) / 2));
    aimLine.material.opacity = 0.95 * aimFade;
    reticle.visible = true; reticle.position.set(b.x, 0.12, b.z); reticle.scale.setScalar(1 + 0.08 * Math.sin(clockT * 8));
  } else { aimLine.visible = false; reticle.visible = false; }
  updateShots(mdt);
  for (let i = fx.length - 1; i >= 0; i--) { const e = fx[i]; const fdt = dt * (hitStop > 0 ? 0.2 : 1); e.t += fdt; const u = Math.min(1, e.t / e.life); e.update(e.obj, u, fdt); if (u >= 1) { scene.remove(e.obj); fx.splice(i, 1); } }
  // HUD
  hud.press = Math.max(0, hud.press - mdt); hud.jpress = Math.max(0, hud.jpress - mdt);
  if (hud.mode === "pips" && hud.charges < 3) { hud.refill += mdt / 2.5; if (hud.refill >= 1) { hud.charges++; hud.refill = hud.charges < 3 ? 0 : 1; } }
  drawHud();
  // camera
  shake = Math.max(0, shake - dt * 4.2); fovPunch = Math.max(0, fovPunch - dt * 14);
  const fr = tr ? tr.frame : [new THREE.Vector3(), new THREE.Vector3(0, 0, -30)];
  const mid = fr[0].clone().lerp(fr[1], 0.5).setY(9), span = fr[0].distanceTo(fr[1]) + 30;
  const hfov = 2 * Math.atan(Math.tan(rad(cam.fov / 2)) * cam.aspect), vfit = span * 0.5 / Math.tan(hfov / 2);
  let cp, look = mid;
  if (camMode === "hero") cp = mid.clone().add(new THREE.Vector3(-1, 0.4, -0.16).normalize().multiplyScalar(vfit * 1.08));
  else if (camMode === "side") cp = mid.clone().add(new THREE.Vector3(-1, 0.14, 0).normalize().multiplyScalar(vfit * 1.1));
  else if (camMode === "game") { cp = dilo.pos.clone().add(new THREE.Vector3(-10, 30, 44)); look = dilo.pos.clone().add(new THREE.Vector3(0, 8, -26)); }
  else { const h = partPoint(mouthParts.skull); cp = h.clone().add(new THREE.Vector3(-15, 3, -15)); look = h.clone().add(new THREE.Vector3(0, -1.5, 0)); }
  camPos.lerp(cp, camMode === "close" ? 0.3 : 0.15); camLook.lerp(look, camMode === "close" ? 0.35 : 0.2);
  const sh = shake * shake * 1.0;
  cam.position.copy(camPos).add(new THREE.Vector3((Math.random() - .5) * sh, (Math.random() - .5) * sh, (Math.random() - .5) * sh));
  cam.lookAt(camLook);
  cam.fov = 38 + fovPunch; cam.updateProjectionMatrix();
  sun.position.copy(mid).add(new THREE.Vector3(-30, 70, 30)); sun.target.position.copy(mid);
  renderer.render(scene, cam);
}
const camPos = new THREE.Vector3(-60, 26, -20), camLook = new THREE.Vector3(0, 9, -20);

// ---------- HUD strip ----------
const ringC = 2 * Math.PI * 46;
function drawHud() {
  const atk = $("hAtk"), jmp = $("hJump"), ring = $("ring"), pips = $("pips");
  atk.classList.toggle("on", hud.press > 0.001 || hud.held);
  jmp.classList.toggle("on", hud.jpress > 0.001);
  let ringV = 0, col = "#8ee05a";
  if (hud.mode === "meter") { ringV = hud.meter; }
  else if (hud.mode === "hold") { ringV = hud.hold; col = "#ffffff"; }
  ring.setAttribute("stroke", col); ring.setAttribute("stroke-dashoffset", String(ringC * (1 - ringV)));
  ring.parentNode.style.display = hud.mode === "meter" || hud.mode === "hold" ? "" : "none";
  atk.classList.toggle("dim", hud.mode === "pips" && hud.charges === 0);
  const want = attack === "A" ? 3 : 0;
  if (pips.childElementCount !== want) { pips.innerHTML = ""; for (let i = 0; i < want; i++) { const q = document.createElement("div"); q.className = "pip"; q.innerHTML = "<i></i>"; pips.appendChild(q); } }
  [...pips.children].forEach((q, i) => { const h = i < hud.charges ? 100 : i === hud.charges ? Math.round(Math.min(1, hud.refill) * 100) : 0; q.firstChild.style.height = h + "%"; });
}

// ---------- UI ----------
const INFO = {
  A: {name: "Venom Glob", input: "Tap ATTACK",
    look: "The neck rears back, the frill snaps open around the head and the yellow throat sac swells; then the neck whips forward and lobs a fat green glob in an arc. It splats on the target in a green burst and leaves it dripping venom for 3 seconds. Nothing is left on the ground.",
    nums: ["12 damage on hit + venom 3/s for 3 s (21 total)", "Range ~40 studs, lobbed arc (~0.6 s flight)", "Soft aim: closest enemy within 30° of facing", "3 charges (pips under ATTACK), 1 refills every 2.5 s", "~0.4 s from tap to the glob leaving the mouth"],
    trade: "The clearest ranged identity and the simplest on a phone: tap and it aims itself. The arc is slow enough to dodge at long range, and it is weak up close; with all 3 charges spent you wait 2.5 s for the next one."},
  B: {name: "Venom Spray", input: "Hold ATTACK",
    look: "While you hold ATTACK the frill stays open, the jaw gapes and a short fan of green droplets sprays out of the mouth, the head sweeping a little from side to side. Everything inside the fan takes damage and is slowed. Let go and the frill folds.",
    nums: ["4 damage every 0.25 s (16/s) to every enemy in the cone", "Cone: 18 studs long, 40° wide, straight ahead (no aim assist needed: the cone is the aim)", "Slowed 30% while in the spray (+1 s after)", "Spit meter (ring on ATTACK): 2 s of spray when full, refills in ~3 s after you let go"],
    trade: "Highest damage and it hits groups, but it is a short-range move on a dino whose role is ranged spitter: you have to walk into bite range to use it. While holding you can't do anything else."},
  C: {name: "Bite + Spit Dart", input: "Tap = bite · Hold + let go = dart",
    look: "Tap ATTACK for a quick snap bite in front (the frill stays folded). Hold ATTACK and the neck coils into an S, the frill snaps open and the ring on the button fills; let go and it fires a fast, straight spit dart at the target.",
    nums: ["Bite: 10 damage, ~10 studs in front, tap", "Dart: hold 0.4 s, let go: 8 damage + venom 2/s for 4 s (16 total)", "Dart range ~60 studs, straight and fast (~0.25 s)", "Soft aim on the dart: closest enemy within 30°", "Dart cooldown 1.5 s (proposed)"],
    trade: "Most flexible (something for close and far), but two moves on one button: tap vs hold is easy to mix up on a phone, and the 0.4 s hold makes the dart feel slow to start. More to learn for younger players."},
  J1: {name: "Cobra Leap", input: "Tap JUMP",
    look: "It sinks into a crouch with the neck coiled back like a cobra about to strike and the frill flared, springs ~30 studs forward with the legs tucked, and lands plainly on its feet: no dust, no shockwave. The frill folds again after it lands.",
    nums: ["~30-stud leap, ~0.7 s in the air", "No damage", "Same jump rules as the other dinos (charges / cooldown like the raptor leap)"],
    trade: "Pure movement: gets you out of bite range so you can spit again, or over a gap. No damage, so nothing to aim or mistime on a phone."},
  J2: {name: "Air Spit", input: "Tap JUMP",
    look: "The same coiled leap, but at the top it snaps its head down and spits one glob at the ground ahead, which splats on whoever is standing there. It lands plainly, like J1.",
    nums: ["8 damage + venom 2/s for 3 s (proposed)", "Splash ~6 studs where the glob lands, ~15 studs past where you land", "Soft aim: lands on the closest enemy within 30°, else on the ground ahead", "Same leap as J1 (a little higher, ~0.85 s in the air)"],
    trade: "Adds damage to the jump, but it overlaps the attack (two spits), and you can't steer it mid-air on a phone, so it often splats where nobody is. Busier to read: a green splash right as you land."},
};
const REC = {A: true, J1: true};
function infoCard(k, kind) {
  const I = INFO[k];
  return `<div class="kind">${kind} · ${I.input}</div><h2>${k} · ${I.name}${REC[k] ? '<span class="badge">Recommended</span>' : ""}</h2>
    <h3>What it looks like</h3><p>${I.look}</p><h3>Numbers</h3><ul>${I.nums.map(n => `<li>${n}</li>`).join("")}</ul><h3>Trade-off</h3><p>${I.trade}</p>`;
}
function setPressed(sel, attr, v) { document.querySelectorAll(sel).forEach(b => b.setAttribute("aria-pressed", b.dataset[attr] === v)); }
function info() { $("infoAtk").innerHTML = infoCard(attack, "Attack"); $("infoJump").innerHTML = infoCard(jump, "Jump"); setPressed("[data-attack]", "attack", attack); setPressed("[data-jump]", "jump", jump); }
document.querySelectorAll("[data-attack]").forEach(b => b.onclick = () => { attack = b.dataset.attack; info(); start("attack"); });
document.querySelectorAll("[data-jump]").forEach(b => b.onclick = () => { jump = b.dataset.jump; info(); start("jump"); });
document.querySelectorAll("[data-cam]").forEach(b => b.onclick = () => { camMode = b.dataset.cam; setPressed("[data-cam]", "cam", camMode); });
$("again").onclick = () => start(seq); $("runAtk").onclick = () => start("attack"); $("runJump").onclick = () => start("jump");
$("slow").onclick = e => { slowMo = !slowMo; e.currentTarget.setAttribute("aria-pressed", slowMo); };
function resize() { const w = cv.clientWidth, h = cv.clientHeight; renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); }
window.addEventListener("resize", resize);
let last = performance.now();
function loop(now) { const dt = Math.min(0.05, (now - last) / 1000); last = now; if (!window.__manual) step(dt); requestAnimationFrame(loop); }
resize(); info(); setPressed("[data-cam]", "cam", camMode); start("attack");
requestAnimationFrame(loop);
// hooks for scripted screenshots: __setup(attack, jump, kind = "attack", cam = "hero") switches to manual stepping and
// restarts that move at t = 0 (after a short settle); __step(dt) advances; __len() / __t() give the track length / time.
window.__ready = true;
window.__setup = (a, j, kind, cm) => { window.__manual = true; attack = a || attack; jump = j || jump; camMode = cm || "hero"; info(); setPressed("[data-cam]", "cam", camMode); start(kind || "attack"); const p = play; play = null; for (let i = 0; i < 40; i++) step(1 / 30); start(kind || "attack"); };
window.__step = dt => step(dt);
window.__len = () => play ? play.track.len : 0;
window.__t = () => play ? play.t : 0;
window.__state = () => ({attack, jump, seq, t: play && play.t, frill: dilo.frillS, hud: Object.assign({}, hud), shots: shots.length, fx: fx.length, hub: frillHub.toArray()});
window.__pose = (P, view) => { // static pose check (dilo at the origin facing -Z): view "side" | "front" | "three"
  window.__manual = true; dilo.yaw = 0; dilo.pos.set(0, 0, 0); dilo.y = 0; pose(dilo, P);
  let minY = Infinity; for (const p of diloFeet) for (let i = 0; i < 8; i++) { _c.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(p.mesh.matrix); minY = Math.min(minY, _c.y); }
  dilo.y = -minY; pose(dilo, P); raps.forEach(R => R.rig.g.visible = false);
  const C = {side: [-48, 10, -2], front: [-6, 12, -46], three: [-34, 16, -30]}[view || "side"]; cam.position.set(C[0], C[1], C[2]); cam.lookAt(0, 8, -3); cam.fov = 38; cam.updateProjectionMatrix();
  renderer.render(scene, cam);
};
