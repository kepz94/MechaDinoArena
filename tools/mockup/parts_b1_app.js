const D = __DATA__;
const STEEL = 0x9aa6b8, DARK = 0x5d6878, BRIGHT = 0xd3dbe6, HOT = 0xff8a2a, CANVAS = 0xe0742a, SMOKE = 0xdfe3e8;
const rad = THREE.MathUtils.degToRad;
const $ = id => document.getElementById(id);

// ---------- parts: steps, looks, notes (Kepu 2026-10-31 picks) ----------
const PARTS = [
  {id: "glider", name: "Glider Wings", area: "SPEED", key: "hold JUMP", steps: [
      "Glide: hold JUMP in the air, fall at 8 studs/s, keep your run speed forward",
      "SLASH while gliding = drop attack on anything below (55 studs)",
      "Drop attack from a glide +30% damage",
      "The glide drop lands with a bleed burst (10 studs around)"],
    note: "Works from any jump or tree hop. The wings fold away on landing. No cooldown, so you can glide on every jump.",
    looks: [
      {name: "A · Bat Membranes", sub: "orange skin between steel finger-rods", why: "Steel rods along each forearm unfold a hot-orange membrane, like a bat or flying-lizard wing. It's built on the Herrera's own arms, so you recognize the glider right away and the dino still looks like itself.", parts: "Per arm: forearm rod frame, 3 finger rods, 2 membrane panels. Folded flat against the forearm on the ground."},
      {name: "B · Glider Pack", sub: "back-mounted folding wings", why: "A steel pack on the hump swings out two wide wings like a hang-glider. It reads as mecha gear from far away and leaves the arms free for the drop attack.", parts: "Back pack + 2 wings (spar + canvas + tip light). Folded upright against the back on the ground."}]},
  {id: "quills", name: "Quill Launcher", area: "ATTACK", key: "R", steps: [
      "Fire 5 quills at your target, 4 damage each (40 studs)", "8 quills", "12 quills", "17 quills"],
    note: "Its own slot key, 20 s cooldown (long). Aims at the target in front of you (the same aim as the slash). No bleed, no slow: the steps only add quills.",
    looks: [
      {name: "A · Back Pod", sub: "missile-pod box on the hump", why: "A dark launcher box on the hump. The lid flips up to show the quill tubes, then the volley fans out. It's the clearest 'it shoots' look.", parts: "Pod box, hinged lid, 3×3 orange tube tips. The lid is closed while running."},
      {name: "B · Spine Quills", sub: "the Herrera's own back quills, made of steel", why: "The quills already on its back turn into steel tubes with glowing tips, and they fire straight off the spine. It looks like part of the Herrera, and it's still easy to spot.", parts: "7 steel quill tubes in place of the back quills, each with an orange tip."}]},
  {id: "smoke", name: "Smoke Pods", area: "TRICKSTER", key: "R", steps: [
      "Smoke cloud (12 studs) for 4 s: inside it your name/bar are hidden, bots lose you",
      "Cloud lasts 6 s", "Run 25% faster inside the smoke", "Enemies inside the smoke are slowed 25%"],
    note: "Its own slot key, 18 s cooldown. The cloud stays where you dropped it. Bots that lose you show a \"?\" and go back to wandering.",
    looks: [
      {name: "A · Hip Canisters", sub: "two smoke cans on the hips", why: "Two chunky canisters with orange caps sit on the hips. The caps pop off and the smoke bursts out. Easy to read, and it looks like a tool the dino carries.", parts: "Per side: canister, orange cap, strap. The caps pop and come back."},
      {name: "B · Tail Vents", sub: "a vent block on the tail base", why: "A steel vent block at the base of the tail with three nozzles that blast the smoke out behind you. It looks like an escape move, made for running away.", parts: "Vent block on the tail base, 3 nozzles, orange intake ring."}]},
  {id: "plating", name: "Back Plating", area: "DEFENSE", key: "always on", steps: [
      "Hits from behind -10% damage", "-15%", "-22%", "-30% from behind"],
    note: "On while slotted, no key. Only hits from behind (the back half of the dino) are reduced; hits from the front are unchanged. The spec still needs the ★ wording checked: \"Max -30% damage\" read as from behind.",
    looks: [
      {name: "A · Spine Scutes", sub: "overlapping steel plates down the back", why: "Riveted steel plates overlap along the back and onto the tail base. It looks like armour while keeping the Herrera's lean shape. They spark when hit from behind.", parts: "6 overlapping plates (hips to hump, plus the tail base), dark rims, rivets."},
      {name: "B · Carapace Shell", sub: "one big shell over the back", why: "One chunky shell, like a turtle's, with a steel rim and an orange stripe. It's the most obvious 'I'm protected from behind' shape, and it's bulkier.", parts: "3-piece shell (hips, back, hump), steel rim, orange stripe."}]}];
const BOT_BITE = 20, SLASH = 8;
let part = 0, look = 0, step = 3, slotted = true, labView = false, slow = false;

// ---------- three ----------
const cv = $("cv");
const renderer = new THREE.WebGLRenderer({canvas: cv, antialias: true, preserveDrawingBuffer: true});
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
const scene = new THREE.Scene();
const sky = new THREE.Color(0x8fc6e8), labBg = new THREE.Color(0x141a26);
scene.background = sky; scene.fog = new THREE.Fog(0x8fc6e8, 40, 90);
const cam = new THREE.PerspectiveCamera(38, 16 / 9, 0.1, 300);
scene.add(new THREE.HemisphereLight(0xeaf6ff, 0x5a6a3a, 0.55));
const sun = new THREE.DirectionalLight(0xffffff, 0.9); sun.position.set(-6, 14, 9); scene.add(sun);
const rim = new THREE.DirectionalLight(0xffe2b8, 0.35); rim.position.set(8, 5, -10); scene.add(rim);
const world = new THREE.Group(); scene.add(world);
const scenery = new THREE.Group(); world.add(scenery);
const ground = new THREE.Mesh(new THREE.PlaneGeometry(220, 60), new THREE.MeshLambertMaterial({color: 0x6fae4a}));
ground.rotation.x = -Math.PI / 2; scenery.add(ground);
for (let i = -50; i < 50; i++) {
  const t = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.25 + (Math.abs(i * 7919) % 5) * 0.06, 0.5), new THREE.MeshLambertMaterial({color: i % 3 ? 0x5c9a3c : 0x86c05a}));
  t.position.set(i * 2.1 + (Math.abs(i * 31) % 7) * 0.2, 0.12, -3 - (Math.abs(i * 17) % 9) * 0.6); scenery.add(t);
  if (i % 4 === 0) { const r = new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.45, 0.7), new THREE.MeshLambertMaterial({color: 0x9c9284})); r.position.set(i * 2.1, 0.2, 4 + Math.abs(i * 13) % 5); scenery.add(r); }
}
const sand = new THREE.Mesh(new THREE.PlaneGeometry(220, 3), new THREE.MeshLambertMaterial({color: 0xc9b47a}));
sand.rotation.x = -Math.PI / 2; sand.position.set(0, 0.01, -7); scenery.add(sand);
// palm tree (glider start): leaning trunk + leaf pad
const TREE_X = -20, TREE_TOP = 9;
const tree = new THREE.Group(); scenery.add(tree);
for (let i = 0; i < 9; i++) { const s = new THREE.Mesh(new THREE.BoxGeometry(1.1 - i * 0.04, 1.05, 1.1 - i * 0.04), new THREE.MeshLambertMaterial({color: i % 2 ? 0x8a6a45 : 0x7a5c3a})); s.position.set(TREE_X - 0.6 + i * 0.07, 0.5 + i, 0); tree.add(s); }
for (let a = 0; a < 6; a++) { const l = new THREE.Mesh(new THREE.BoxGeometry(4.2, 0.3, 1.1), new THREE.MeshLambertMaterial({color: a % 2 ? 0x3f8f3a : 0x4fa848}));
  l.position.set(TREE_X + Math.cos(a) * 1.8, TREE_TOP + 0.05, Math.sin(a) * 1.8); l.rotation.y = -a; l.rotation.z = 0.12; tree.add(l); }

// ---------- rig (HerreraModelData 1.2, Motor6D maths) ----------
function cfm(a) { const m = new THREE.Matrix4(); m.set(a[3], a[4], a[5], a[0], a[6], a[7], a[8], a[1], a[9], a[10], a[11], a[2], 0, 0, 0, 1); return m; }
const segs = {}, partInfo = {}, dino = new THREE.Group(); world.add(dino);
const matCache = {};
function mat(hex) { return matCache[hex] || (matCache[hex] = new THREE.MeshLambertMaterial({color: hex})); }
for (const s of D.segs) {
  const rootInv = cfm(s.root).invert(); segs[s.n] = {parts: []};
  for (const p of s.parts) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(p.s[0], p.s[1], p.s[2]), mat(parseInt(p.c, 16))); m.matrixAutoUpdate = false; dino.add(m);
    const info = {mesh: m, local: rootInv.clone().multiply(cfm(p.cf)), seg: s.n, size: p.s}; segs[s.n].parts.push(info); partInfo[p.n] = info;
  }
}
const joints = D.joints.map(j => ({n: j.n, p0: j.p0, p1: j.p1, c0: cfm(j.c0), c1inv: cfm(j.c1).invert()}));
const tmpE = new THREE.Euler();
function rot(p, y, r) { tmpE.set(rad(r), rad(y), rad(p), "ZYX"); return new THREE.Matrix4().makeRotationFromEuler(tmpE); }
const S = {BodyPitch: -24, Neck: 6, Head: 16, Jaw: -3, ArmTuck: 30, LegTuck: 48, Knee: -48, Foot: 24, Tail: [26, 4, 8, 14, 20],
  ArmSwing: 34, ArmSprawl: 18, ArmLiftSprawl: 10, LegSwing: 30, LegSprawl: 16, KneeLift: -34, FootLift: 20, BodyYaw: 11, BodyRoll: 4,
  NeckYaw: -9, HeadYaw: -6, TailWhip: 8, TailWhipGrow: 4, TailLag: 0.75, Stride: 3.2, MaxHz: 5};
const JN = ["RootJoint", "Neck", "Head", "Jaw", "ArmL", "ArmR", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "LegL", "LegR", "KneeL", "KneeR", "AnkleL", "AnkleR"];
function blank() { const o = {body: [0, 0, 0]}; JN.forEach(n => o[n] = [0, 0, 0]); return o; }
function add(o, n, p, y, r) { o[n][0] += p; o[n][1] += (y || 0); o[n][2] += (r || 0); }
function scurry(phase, amt) { // ScurryPose 1.0 angles(phase) x amt
  const o = blank();
  add(o, "RootJoint", S.BodyPitch); add(o, "Neck", S.Neck); add(o, "Head", S.Head); add(o, "Jaw", S.Jaw);
  add(o, "ArmL", S.ArmTuck); add(o, "ArmR", S.ArmTuck); add(o, "LegL", S.LegTuck); add(o, "LegR", S.LegTuck);
  add(o, "KneeL", S.Knee); add(o, "KneeR", S.Knee); add(o, "AnkleL", S.Foot); add(o, "AnkleR", S.Foot);
  for (let i = 1; i <= 5; i++) add(o, "Tail" + i, S.Tail[i - 1]);
  const pa = {ArmL: phase, LegR: phase, ArmR: phase + Math.PI, LegL: phase + Math.PI};
  for (const n in pa) {
    const sw = Math.sin(pa[n]) * amt, lift = Math.max(0, Math.cos(pa[n])) * amt, side = n.endsWith("L") ? 1 : -1;
    if (n.startsWith("Arm")) add(o, n, S.ArmSwing * sw, 0, -side * (S.ArmSprawl + S.ArmLiftSprawl * lift));
    else { const sf = n.slice(-1); add(o, n, S.LegSwing * sw, 0, -side * S.LegSprawl); add(o, "Knee" + sf, S.KneeLift * lift); add(o, "Ankle" + sf, S.FootLift * lift); }
  }
  const w = Math.sin(phase) * amt;
  o.body[1] = S.BodyYaw * w; o.body[2] = S.BodyRoll * Math.sin(phase + Math.PI / 2) * amt;
  add(o, "Neck", 0, S.NeckYaw * w); add(o, "Head", 0, S.HeadYaw * w);
  for (let i = 1; i <= 5; i++) add(o, "Tail" + i, 0, (S.TailWhip + i * S.TailWhipGrow) * Math.sin(phase - i * S.TailLag) * amt);
  return o;
}
const corner = new THREE.Vector3();
function applyPose(o, pos, yaw, opacity) {
  const W = {HRP: new THREE.Matrix4().makeRotationY(yaw)};
  for (const j of joints) {
    const v = o[j.n] || [0, 0, 0]; let pose = rot(v[0], v[1], v[2]);
    if (j.n === "RootJoint") pose = rot(o.body[0], o.body[1], o.body[2]).multiply(pose);
    W[j.p1] = W[j.p0].clone().multiply(j.c0).multiply(pose).multiply(j.c1inv);
  }
  let minY = Infinity;
  for (const n in segs) for (const p of segs[n].parts) {
    const m = W[n].clone().multiply(p.local); p.mesh.matrix.copy(m);
    if (!p.mesh.visible) continue;
    for (let i = 0; i < 8; i++) { corner.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(m); if (corner.y < minY) minY = corner.y; }
  }
  const lift = new THREE.Matrix4().makeTranslation(pos.x, -minY + pos.y, pos.z);
  for (const n in segs) for (const p of segs[n].parts) p.mesh.matrix.premultiply(lift);
  for (const e of equip) e.mesh.matrix.copy(partInfo[e.anchor].mesh.matrix).multiply(e.off).multiply(e.extra ? e.extra() : new THREE.Matrix4());
  return lift;
}
function partWorld(name, local) { return new THREE.Vector3(...(local || [0, 0, 0])).applyMatrix4(partInfo[name].mesh.matrix); }

// ---------- equipment ----------
const equip = [], hidden = new Set();
let deploy = 0, lid = 0, capPop = 0, flashT = 0;
function piece(anchor, size, pos, rotd, color, o) {
  o = o || {};
  const m = new THREE.Mesh(new THREE.BoxGeometry(size[0], size[1], size[2]),
    o.glow ? new THREE.MeshBasicMaterial({color}) : new THREE.MeshLambertMaterial({color, emissive: 0x000000, transparent: !!o.alpha, opacity: o.alpha || 1, side: o.alpha ? THREE.DoubleSide : THREE.FrontSide}));
  m.matrixAutoUpdate = false; dino.add(m);
  const off = new THREE.Matrix4().compose(new THREE.Vector3(...pos), new THREE.Quaternion().setFromEuler(new THREE.Euler(rad(rotd[0] || 0), rad(rotd[1] || 0), rad(rotd[2] || 0))), new THREE.Vector3(1, 1, 1));
  const e = {mesh: m, anchor, off, glow: !!o.glow, extra: o.extra}; equip.push(e); return e;
}
// fold helper: scale about the piece's own centre along one local axis by k(t)
function foldScale(axis, k0) { return () => { const k = k0 + (1 - k0) * deploy; const v = [1, 1, 1]; v[axis] = Math.max(0.02, k); return new THREE.Matrix4().makeScale(...v); }; }
function foldEdge(axis, edge, k0) { return () => { const k = Math.max(0.03, k0 + (1 - k0) * deploy); const v = [1, 1, 1]; v[axis] = k; const t = [0, 0, 0]; t[axis] = edge;
  return new THREE.Matrix4().makeTranslation(...t).multiply(new THREE.Matrix4().makeScale(...v)).multiply(new THREE.Matrix4().makeTranslation(-t[0], -t[1], -t[2])); }; }
function hinge(px, py, pz, axis, getAngle) { return () => { const a = getAngle(); const r = new THREE.Matrix4().makeRotationAxis(new THREE.Vector3(...axis), a);
  return new THREE.Matrix4().makeTranslation(px, py, pz).multiply(r).multiply(new THREE.Matrix4().makeTranslation(-px, -py, -pz)); }; }
function buildLook() {
  equip.forEach(e => { dino.remove(e.mesh); e.mesh.geometry.dispose(); }); equip.length = 0; hidden.clear();
  if (slotted) {
    const P = PARTS[part].id;
    if (P === "glider" && look === 0) for (const z of [1, -1]) {
      for (const sd of ["L", "R"]) piece("Arm" + sd + "_fore", [0.22, 1.25, 0.22], [0, -0.05, 0], [0, 0, 0], STEEL);
      const base = 0.62, span = 3.6;
      // three membrane panels, longest chord at the body, a scalloped trailing edge
      const panels = [[0.25, 1.9, 1.3], [0.0, 1.6, 2.4], [-0.25, 1.15, span]];
      for (const [x, chord, len] of panels) {
        const zc = (base + len / 2) * z;
        piece("Torso_chest", [chord, 0.05, len], [x - chord / 2 + 0.4, 0.2, zc], [0, 0, 0], CANVAS, {alpha: 0.9, extra: foldEdge(2, -len / 2 * z, 0.05)});
      }
      // leading-edge spar + finger rods
      piece("Torso_chest", [0.16, 0.16, span + 0.2], [0.55, 0.24, (base + span / 2) * z], [0, 0, 0], STEEL, {extra: foldEdge(2, -(span / 2) * z, 0.05)});
      for (const [a, len] of [[-25, 3.4], [-50, 2.6], [-75, 1.7]]) {
        const ra = rad(a), cx = 0.5 + Math.sin(ra) * len / 2 * 0.9, cz = (base + Math.cos(ra) * len / 2) * z;
        piece("Torso_chest", [0.1, 0.1, len], [cx, 0.26, cz], [0, a * z * -1, 0], DARK, {extra: () => { const k = Math.max(0.05, deploy); return new THREE.Matrix4().makeScale(1, 1, k); }});
      }
      piece("Torso_chest", [0.4, 0.4, 0.4], [0.5, 0.25, base * z], [0, 0, 0], HOT, {glow: true});
    }
    if (P === "glider" && look === 1) {
      piece("Torso_hump", [1.0, 0.45, 0.9], [0, 0.35, 0], [0, 0, 0], DARK);
      piece("Torso_hump", [0.4, 0.3, 0.4], [0.35, 0.55, 0], [0, 0, 0], HOT, {glow: true});
      for (const z of [1, -1]) {
        // wing spans out sideways (hump local Z = side), folds up against the back
        const fold = () => { const a = -(1 - deploy) * rad(78) * z; return new THREE.Matrix4().makeTranslation(0, 0.4, 0.45 * z).multiply(new THREE.Matrix4().makeRotationY(a)).multiply(new THREE.Matrix4().makeTranslation(0, -0.4, -0.45 * z)); };
        piece("Torso_hump", [1.5, 0.08, 3.4], [-0.2, 0.42, (0.45 + 1.7) * z], [0, 0, 0], CANVAS, {alpha: 0.95, extra: fold});
        piece("Torso_hump", [0.16, 0.16, 3.6], [0.55, 0.45, (0.45 + 1.8) * z], [0, 0, 0], STEEL, {extra: fold});
        piece("Torso_hump", [1.2, 0.12, 0.14], [-0.15, 0.45, (0.45 + 3.5) * z], [0, 0, 0], STEEL, {extra: fold});
        piece("Torso_hump", [0.25, 0.14, 0.25], [0.55, 0.46, (0.45 + 3.5) * z], [0, 0, 0], HOT, {glow: true, extra: fold});
      }
    }
    if (P === "quills" && look === 0) {
      piece("Torso_hump", [1.05, 0.55, 1.0], [0, 0.42, 0], [0, 0, 0], DARK);
      piece("Torso_hump", [1.1, 0.12, 1.05], [0, 0.75, 0], [0, 0, 0], STEEL, {extra: hinge(-0.55, 0.75, 0, [0, 0, 1], () => lid * rad(105))});
      for (let i = 0; i < 3; i++) for (let k = 0; k < 3; k++) piece("Torso_hump", [0.16, 0.06, 0.16], [-0.3 + i * 0.3, 0.71, -0.3 + k * 0.3], [0, 0, 0], HOT, {glow: true});
      piece("Torso_hump", [0.12, 0.6, 1.05], [-0.5, 0.2, 0], [0, 0, 0], STEEL);
    }
    if (P === "quills" && look === 1) {
      for (let i = 1; i <= 7; i++) {
        const q = "Torso_quill" + i; hidden.add(q); const sz = partInfo[q].size;
        piece(q, [sz[0] * 1.9, sz[1] * 1.15, sz[2] * 1.9], [0, 0, 0], [0, 0, 0], STEEL);
        piece(q, [sz[0] * 2.3, 0.12, sz[2] * 2.3], [0, sz[1] * 0.58, 0], [0, 0, 0], HOT, {glow: true});
        piece(q, [sz[0] * 2.4, 0.1, sz[2] * 2.4], [0, -sz[1] * 0.45, 0], [0, 0, 0], DARK);
      }
    }
    if (P === "smoke" && look === 0) for (const z of [1, -1]) {
      piece("Torso_hips", [0.56, 0.82, 0.56], [0.05, -0.05, 0.66 * z], [0, 0, 0], DARK);
      piece("Torso_hips", [0.64, 0.12, 0.64], [0.05, 0.08, 0.66 * z], [0, 0, 0], STEEL);
      piece("Torso_hips", [0.6, 0.2, 0.6], [0.05, 0.44, 0.66 * z], [0, 0, 0], HOT, {extra: () => new THREE.Matrix4().makeTranslation(0, capPop * 0.9, capPop * 0.4 * z)});
      piece("Torso_hips", [0.1, 0.5, 0.75], [0.05, 0.0, 0.36 * z], [0, 0, 0], DARK);
    }
    if (P === "smoke" && look === 1) {
      piece("Tail1_main", [0.7, 0.62, 0.62], [0.1, 0.32, 0], [0, 0, 0], DARK);
      piece("Tail1_main", [0.72, 0.1, 0.66], [0.1, 0.05, 0], [0, 0, 0], HOT, {glow: true});
      for (const zz of [-0.2, 0, 0.2]) piece("Tail1_main", [0.14, 0.38, 0.14], [-0.15, 0.62, zz], [0, 0, 25], STEEL);
    }
    if (P === "plating" && look === 0) {
      const plates = [["Torso_hips", [0.95, 0.12, 0.85], [0, 0.36, 0]], ["Torso_waist", [0.95, 0.12, 0.85], [0, 0.37, 0]], ["Torso_chest", [1.05, 0.12, 1.1], [0, 0.68, 0.0]],
        ["Torso_hump", [1.0, 0.12, 1.05], [0, 0.3, 0]], ["Tail1_main", [1.2, 0.12, 0.6], [0, 0.27, 0]], ["Tail2_main", [1.0, 0.1, 0.46], [0, 0.2, 0]]];
      for (const [a, s, p] of plates) {
        piece(a, s, p, [0, 0, -6], STEEL);
        piece(a, [s[0] * 0.98, 0.05, s[2] + 0.06], [p[0] - s[0] * 0.35, p[1] - 0.02, p[2]], [0, 0, -6], DARK);
        for (const zz of [-s[2] * 0.35, s[2] * 0.35]) piece(a, [0.08, 0.06, 0.08], [p[0], p[1] + 0.08, zz], [0, 0, 0], BRIGHT);
      }
      for (let i = 1; i <= 7; i++) hidden.add("Torso_quill" + i);
    }
    if (P === "plating" && look === 1) {
      piece("Torso_hips", [1.3, 0.35, 1.25], [0.0, 0.4, 0], [0, 0, -8], DARK);
      piece("Torso_chest", [1.5, 0.4, 1.55], [0.0, 0.72, 0], [0, 0, 0], DARK);
      piece("Torso_hump", [1.3, 0.35, 1.3], [0, 0.32, 0], [0, 0, 0], DARK);
      piece("Torso_chest", [1.6, 0.1, 1.65], [0, 0.52, 0], [0, 0, 0], STEEL);
      piece("Torso_hips", [1.4, 0.1, 1.35], [0, 0.22, 0], [0, 0, -8], STEEL);
      piece("Torso_chest", [1.52, 0.42, 0.2], [0, 0.73, 0], [0, 0, 0], HOT);
      for (let i = 1; i <= 7; i++) hidden.add("Torso_quill" + i);
    }
  }
  for (const n in partInfo) partInfo[n].mesh.visible = !hidden.has(n);
}

// ---------- bots (stand-in block bots) ----------
function makeBot() {
  const g = new THREE.Group(), body = new THREE.Group(); g.add(body);
  const m = new THREE.MeshLambertMaterial({color: 0x7f8c9e, emissive: 0x000000});
  [[[2.6, 1.8, 1.6], [0, 2.6, 0]], [[1.6, 1.3, 1.3], [1.7, 3.5, 0]], [[1.2, 0.5, 1.1], [2.2, 3.0, 0]], [[2.4, 0.6, 0.6], [-2.2, 2.6, 0]],
   [[0.6, 2.0, 0.6], [0.2, 1.0, 0.45]], [[0.6, 2.0, 0.6], [0.2, 1.0, -0.45]]].forEach(([s, p]) => { const b = new THREE.Mesh(new THREE.BoxGeometry(...s), m); b.position.set(...p); body.add(b); });
  const eye = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.2, 0.2), new THREE.MeshBasicMaterial({color: 0xffd23a})); eye.position.set(2.2, 3.8, 0.66); body.add(eye);
  world.add(g); return {g, body, m, flash: 0, knock: 0, hp: 200};
}
const bots = [makeBot(), makeBot()];

// ---------- fx ----------
const fx = [];
function bit(pos, color, v, life, g, size, opts) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(size, size, size), new THREE.MeshLambertMaterial({color, emissive: opts && opts.glow ? color : 0x000000, transparent: true}));
  m.position.copy(pos); world.add(m);
  const f = Object.assign({m, v, life, max: life, g}, opts || {}); fx.push(f); return f;
}
function sparks(pos, color, n, spd) { for (let i = 0; i < n; i++) { const a = Math.random() * Math.PI * 2, u = Math.random() * .8 + .2;
  bit(pos, color, new THREE.Vector3(Math.cos(a) * spd * u, Math.random() * spd, Math.sin(a) * spd * u), 0.45, -22, 0.12, {glow: true}); } }
function dust(pos, big) { bit(pos, 0xd8cfb4, new THREE.Vector3(-1.5, 1.2, (Math.random() - .5) * 2), big ? 0.5 : 0.35, -2, 0.3, {grow: big ? 2.4 : 1.4}); }
const stage = $("stage"), pops = [];
function pop(html, color, size, at, life) {
  const el = document.createElement("div"); el.className = "pop"; el.style.color = color; el.style.fontSize = size + "px"; el.innerHTML = html; stage.appendChild(el);
  pops.push({el, p: at.clone(), t: 0, life: life || 0.9});
}
function clearFx() { if (sc && sc.cloud) sc.cloud.puffs.forEach(p => world.remove(p.m)); fx.forEach(f => world.remove(f.m)); fx.length = 0; pops.forEach(p => p.el.remove()); pops.length = 0; quills.forEach(q => world.remove(q.m)); quills.length = 0; }

// ---------- scenario state ----------
let T = 0, sc = {};
const quills = [];
function stepIdx() { return slotted ? step : -1; }
function reset() {
  clearFx(); T = 0; deploy = 0; lid = 0; capPop = 0;
  const P = PARTS[part].id;
  sc = {x: -18, alt: 0, phase: 0, yaw: -Math.PI / 2, mode: "run", done: {}, meHp: 40, hiddenA: 1, z: 0};
  bots.forEach((b, i) => { b.g.visible = false; b.hp = 200; b.flash = b.knock = 0; b.g.rotation.set(0, Math.PI, 0); b.body.rotation.set(0, 0, 0); b.body.position.set(0, 0, 0); });
  if (P === "glider") { sc.x = TREE_X + 0.5; sc.alt = TREE_TOP; sc.mode = "perch"; bots[0].g.visible = true; bots[0].g.position.set(24, 0, -0.6);
    bots[1].g.visible = true; bots[1].g.position.set(27.5, 0, 2.6); }
  if (P === "quills") { sc.x = -20; bots[0].g.visible = true; bots[0].g.position.set(8, 0, -0.6); }
  if (P === "smoke") { sc.x = -16; bots[0].g.visible = true; bots[0].g.position.set(-24, 0, 0); bots[0].g.rotation.y = 0; sc.botX = -24; sc.botDir = 1; }
  if (P === "plating") { sc.x = 0; sc.mode = "idle"; bots[0].g.visible = true; bots[0].g.position.set(-11, 0, 0); bots[0].g.rotation.y = 0; sc.botX = -11; sc.botZ = 0; }
  tree.visible = P === "glider";
}

const RUN = 58.5 / 2; // Arena run speed in model units (game model x2)
function poseFor(dt) {
  const P = PARTS[part].id, si = stepIdx();
  let o;
  if (labView) { o = scurry(0, 0); return o; }
  if (sc.mode === "run" || sc.mode === "out" || sc.mode === "hideRun") { sc.phase += Math.min(S.MaxHz * 2 * Math.PI, (sc.spd || RUN) / S.Stride * 2 * Math.PI) * dt; o = scurry(sc.phase, 1); }
  else o = scurry(sc.phase, 0);
  if (sc.mode === "perch") { const c = Math.min(1, Math.max(0, (T - 0.35) / 0.25)); add(o, "RootJoint", -8 * c); add(o, "LegL", 18 * c); add(o, "LegR", 18 * c); add(o, "KneeL", -20 * c); add(o, "KneeR", -20 * c); }
  if (sc.mode === "glide" || sc.mode === "leap" || sc.mode === "fall") {
    const k = P === "glider" && slotted && sc.mode !== "fall" ? deploy : 0.3;
    add(o, "ArmL", 20 * k, 0, -55 * k); add(o, "ArmR", 20 * k, 0, 55 * k); // arms out sideways (outward = -roll on the left, as ScurryPose's sprawl)
    add(o, "LegL", -45 * k); add(o, "LegR", -45 * k); add(o, "KneeL", 30 * k); add(o, "KneeR", 30 * k);
    for (let i = 1; i <= 5; i++) add(o, "Tail" + i, -S.Tail[i - 1] * 0.8 * k);
    add(o, "RootJoint", 14 * k); add(o, "Neck", 6 * k);
  }
  if (sc.mode === "dive") { const u = sc.u || 0; const d = Math.min(1, 3 * u);
    add(o, "ArmL", 50 * d); add(o, "ArmR", 50 * d); add(o, "LegL", -40 * d); add(o, "LegR", -40 * d); add(o, "Jaw", -20 * d); add(o, "RootJoint", -35 * Math.sin(Math.PI * Math.min(1, 1.3 * u))); }
  if (sc.mode === "aim") { add(o, "RootJoint", 6); add(o, "Neck", 10); add(o, "Head", -6); add(o, "Tail1", -8);
    const r = sc.recoil || 0; add(o, "RootJoint", -4 * r); }
  if (sc.mode === "idle" || sc.mode === "hit") { const b = Math.sin(T * 3) * 2; add(o, "Neck", b); add(o, "Tail2", b); }
  if (sc.flinch) { add(o, "RootJoint", 10 * sc.flinch); add(o, "Neck", 12 * sc.flinch); sc.flinch = Math.max(0, sc.flinch - dt * 4); }
  return o;
}

function stepScenario(dt) {
  const P = PARTS[part].id, si = stepIdx(); T += dt;
  const b0 = bots[0], b1 = bots[1];
  if (P === "glider") {
    if (sc.mode === "perch" && T > 0.6) { sc.mode = "leap"; sc.vy = 9; sc.t0 = T; tileFlash(); }
    if (sc.mode === "leap") { sc.x += RUN * 0.7 * dt; sc.vy -= 30 * dt; sc.alt += sc.vy * dt; if (slotted) deploy = Math.min(1, deploy + dt * 5);
      if (sc.vy < 0) sc.mode = slotted ? "glide" : "fall"; }
    if (sc.mode === "glide") { sc.x += RUN * 0.75 * dt; sc.alt = Math.max(0, sc.alt - 4 * dt); deploy = Math.min(1, deploy + dt * 5);
      if (si >= 1 && sc.x > b0.g.position.x - 13) { sc.mode = "dive"; sc.u = 0; sc.from = {x: sc.x, alt: sc.alt}; deploy = 1; tileFlash(); }
      else if (sc.alt <= 0.01) { sc.mode = "out"; dust(new THREE.Vector3(sc.x, 0.2, 0), true); dust(new THREE.Vector3(sc.x, 0.2, 0.6), true); } }
    if (sc.mode === "fall") { sc.x += RUN * 0.7 * dt; sc.vy -= 30 * dt; sc.alt = Math.max(0, sc.alt + sc.vy * dt); if (sc.alt <= 0) { sc.mode = "out"; dust(new THREE.Vector3(sc.x, 0.2, 0), true); } }
    if (sc.mode === "dive") { sc.u = Math.min(1, sc.u + dt / 0.32); deploy = 1 - 0.7 * sc.u;
      const tx = b0.g.position.x - 1.2; sc.x = sc.from.x + (tx - sc.from.x) * sc.u; sc.alt = sc.from.alt * (1 - sc.u * sc.u);
      if (sc.u >= 1) { sc.mode = "recover"; sc.t0 = T; landHit(); } }
    if (sc.mode === "recover") { deploy = Math.max(0, deploy - dt * 4); if (T - sc.t0 > 0.45) sc.mode = "out"; }
    if (sc.mode === "out") { deploy = Math.max(0, deploy - dt * 4); sc.x += RUN * dt; sc.outT = (sc.outT || 0) + dt; if (sc.outT > 0.9) reset(); }
  }
  if (P === "quills") {
    if (sc.mode === "run") { sc.spd = RUN * Math.max(0.15, Math.min(1, (-14 - sc.x) / 4)); sc.x += sc.spd * dt; if (sc.x > -14.2) { sc.mode = "aim"; sc.t0 = T; tileFlash(); } }
    if (sc.mode === "aim") {
      const t = T - sc.t0; lid = slotted ? Math.min(1, t / 0.18) : 0;
      const n = [5, 8, 12, 17][Math.max(0, si)];
      if (slotted && t > 0.22) { const k = Math.floor((t - 0.22) / 0.045); while ((sc.fired || 0) < Math.min(n, k + 1)) fireQuill(sc.fired = (sc.fired || 0) + 1, n); }
      sc.recoil = Math.max(0, (sc.recoil || 0) - dt * 6);
      if (!slotted && t > 0.6) { sc.mode = "out"; }
      if (slotted && t > 0.22 + n * 0.045 + 0.9) { sc.mode = "out"; sc.cdAt = T; }
    }
    if (sc.mode === "out") { lid = Math.max(0, lid - dt * 4); sc.spd = RUN; sc.x += RUN * dt; sc.outT = (sc.outT || 0) + dt; if (sc.outT > 1.2) reset(); }
  }
  if (P === "smoke") {
    const dur = si >= 1 ? 6 : 4, inside = sc.cloud && Math.abs(sc.x - sc.cloud.x) < 6;
    if (sc.mode === "run") { sc.spd = RUN * 0.55; sc.x += sc.spd * dt; if (sc.x > -6 && slotted) { sc.mode = "hide"; sc.t0 = T; dropSmoke(); tileFlash(); } else if (sc.x > -6 && !slotted) sc.mode = "out"; }
    if (sc.mode === "hide") { sc.spd = 0; if (T - sc.t0 > 1.1) { sc.mode = "hideRun"; } }
    if (sc.mode === "hideRun") { sc.spd = RUN * 0.45 * (si >= 2 && inside ? 1.25 : 1); sc.x += sc.spd * dt; if (!inside) sc.mode = "out"; }
    if (sc.mode === "out") { sc.spd = RUN * 0.55; sc.x += sc.spd * dt; sc.outT = (sc.outT || 0) + dt; if (sc.outT > (slotted ? 2.4 : 1.6)) reset(); }
    capPop = sc.cloud && T - sc.cloud.t < 0.6 ? Math.sin(Math.PI * (T - sc.cloud.t) / 0.6) : 0;
    // the chasing bot
    let bs = RUN * 0.5;
    const botIn = sc.cloud && Math.abs(sc.botX - sc.cloud.x) < 6;
    if (sc.lost) { bs = RUN * 0.25; sc.botDir = -1; } else if (botIn && si >= 3) { bs *= 0.75; if (!sc.done.slow) { sc.done.slow = 1; pop("SLOWED -25%", "#6fb6ff", 20, new THREE.Vector3(sc.botX - 2, 4.6, 0)); } }
    if (sc.cloud && !sc.lost && Math.abs(sc.botX - sc.cloud.x) < 6.5 && (Math.abs(sc.x - sc.cloud.x) < 6 || true) && T - sc.cloud.t > 0.6) {
      if (!sc.done.lost && sc.botX > sc.cloud.x - 6.2) { sc.done.lost = 1; sc.lost = true; pop("?", "#ffffff", 46, new THREE.Vector3(sc.botX + 1, 6, 0), 1.4); }
    }
    if (!slotted && sc.x - sc.botX < 3) {}
    sc.botX += bs * sc.botDir * dt; b0.g.position.x = sc.botX; b0.g.rotation.y = sc.botDir > 0 ? 0 : Math.PI;
    if (sc.cloud) { const age = T - sc.cloud.t; if (age > dur) sc.cloud.fade = Math.min(1, (age - dur) / 0.6); }
  }
  if (P === "plating") {
    const red = slotted ? [0.10, 0.15, 0.22, 0.30][step] : 0;
    // bot: comes from behind, bites the back; then walks round to the front and bites the face
    if (!sc.phaseB) sc.phaseB = "approach";
    if (sc.phaseB === "approach") { sc.botX += RUN * 0.35 * dt; if (sc.botX > -6.2) { sc.phaseB = "bite1"; sc.t0 = T; } }
    if (sc.phaseB === "bite1") { const t = T - sc.t0; b0.body.rotation.z = -0.5 * Math.sin(Math.PI * Math.min(1, t / 0.35));
      if (t > 0.2 && !sc.done.b1) { sc.done.b1 = 1; const dmg = Math.floor(BOT_BITE * (1 - red) + 0.5); sc.meHp -= dmg / 4; sc.flinch = 0.5;
        const at = partWorld(look === 1 && slotted ? "Torso_hips" : "Torso_hips", [0, 0.4, 0]);
        sparks(at, slotted ? 0xffd27a : 0xff6a5a, slotted ? 16 : 6, 8); equip.forEach(e => { if (!e.glow) e.mesh.material.emissive.setScalar(0.8); }); flashT = 0.25;
        pop((slotted ? `<s>${BOT_BITE}</s>` : "") + dmg, slotted ? "#ffc832" : "#ff6a5a", slotted ? 38 : 30, new THREE.Vector3(sc.x - 2, 4.5, 0));
        if (slotted) pop(`-${Math.round(red * 100)}% PLATED`, "#ffffff", 16, new THREE.Vector3(sc.x - 2, 3.4, 0)); }
      if (t > 0.7) { sc.phaseB = "around"; sc.t0 = T; } }
    if (sc.phaseB === "around") { const t = Math.min(1, (T - sc.t0) / 1.3), a = Math.PI * t;
      sc.botX = sc.x - 6.2 * Math.cos(a) + 1.5 * Math.sin(a); sc.botZ = -7 * Math.sin(a); b0.g.rotation.y = a; if (t >= 1) { sc.phaseB = "bite2"; sc.t0 = T; } }
    if (sc.phaseB === "bite2") { const t = T - sc.t0; b0.body.rotation.z = -0.5 * Math.sin(Math.PI * Math.min(1, t / 0.35));
      if (t > 0.2 && !sc.done.b2) { sc.done.b2 = 1; sc.meHp -= BOT_BITE / 4; sc.flinch = 1; sparks(partWorld("Head_cranium", [0, 0, 0]).setY(2), 0xff6a5a, 6, 7);
        pop(String(BOT_BITE), "#ff6a5a", 30, new THREE.Vector3(sc.x + 3, 4.2, 0)); pop("FRONT: full damage", "#ffffff", 14, new THREE.Vector3(sc.x + 3, 3.2, 0)); }
      if (t > 1.3) reset(); }
    b0.g.position.set(sc.botX, 0, sc.botZ || 0);
    flashT = Math.max(0, flashT - dt); if (flashT <= 0) equip.forEach(e => { if (!e.glow) e.mesh.material.emissive.setScalar(0); });
  }
}
function tileFlash() { const t = $("tPart"); if (t) { t.classList.add("flash"); setTimeout(() => t.classList.remove("flash"), 240); } }
function landHit() {
  const si = stepIdx(), b0 = bots[0];
  const dmg = Math.floor(SLASH * (si >= 2 ? 1.3 : 1) + 0.5);
  b0.flash = 1; b0.knock = 1; b0.hp -= dmg; sparks(new THREE.Vector3(b0.g.position.x, 2.6, -0.6), 0xffe08a, 14, 9);
  for (let i = 0; i < 4; i++) dust(new THREE.Vector3(sc.x + (Math.random() - .5) * 2, 0.2, (Math.random() - .5) * 2), true);
  pop(String(dmg) + (si >= 2 ? "<small>GLIDE DROP +30%</small>" : "<small>DROP ATTACK</small>"), "#ffc832", 38, new THREE.Vector3(b0.g.position.x, 5, -0.6));
  if (si >= 3) { // bleed burst: blood-red drops thrown out in a ring, every dino within 10 studs (5 model units) bleeds
    for (let i = 0; i < 26; i++) { const a = i / 26 * Math.PI * 2; bit(new THREE.Vector3(sc.x, 1.2, 0), i % 2 ? 0xc0182a : 0xff3b3b, new THREE.Vector3(Math.cos(a) * 9, 5 + Math.random() * 3, Math.sin(a) * 9), 0.55, -26, 0.22, {glow: true}); }
    pop("BLEED BURST", "#ff4a5a", 20, new THREE.Vector3(sc.x, 6.4, 0));
    bots.forEach((b, i) => { b.flash = Math.max(b.flash, 0.7); setTimeout(() => pop("-3", "#ff4a5a", 18, new THREE.Vector3(b.g.position.x + 0.8, 4.3, b.g.position.z)), 700 + i * 120); });
  }
}
function fireQuill(i, n) {
  const P = look; sc.recoil = 1;
  const from = P === 0 ? partWorld("Torso_hump", [0, 0.8, 0]) : partWorld("Torso_quill" + (1 + (i - 1) % 7), [0, 0.3, 0]);
  const b = bots[0].g.position, spread = (i / n - 0.5) * 2;
  const to = new THREE.Vector3(b.x - 0.4, 2.2 + Math.sin(i * 2.3) * 0.9, b.z + spread * 1.2);
  const m = new THREE.Mesh(new THREE.BoxGeometry(1.3, 0.16, 0.16), new THREE.MeshLambertMaterial({color: BRIGHT}));
  const tip = new THREE.Mesh(new THREE.BoxGeometry(0.34, 0.24, 0.24), new THREE.MeshBasicMaterial({color: HOT})); tip.position.x = 0.75; m.add(tip);
  const fl = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.34, 0.06), new THREE.MeshLambertMaterial({color: DARK})); fl.position.x = -0.6; m.add(fl);
  m.position.copy(from); world.add(m);
  const dist = from.distanceTo(to), tt = dist / 45;
  quills.push({m, from, to, t: 0, tt, arc: 1.5 + Math.random() * 1.2, dmgAt: 4});
  dust(from.clone(), false);
}
function dropSmoke() {
  sc.cloud = {x: sc.x + 0.5, t: T, fade: 0, puffs: []};
  const src = look === 0 ? partWorld("Torso_hips", [0, 0, 0]) : partWorld("Tail1_main", [0, 0.5, 0]);
  for (let i = 0; i < 70; i++) {
    const a = Math.random() * Math.PI * 2, r = Math.sqrt(Math.random()) * 5.6, s = 0.8 + Math.random() * 1.3;
    const m = new THREE.Mesh(new THREE.SphereGeometry(s, 14, 10), new THREE.MeshLambertMaterial({color: i % 4 ? 0xf1f3f6 : 0xd5dae2, transparent: true, opacity: 0.0}));
    m.position.copy(src); m.rotation.set(Math.random(), Math.random(), Math.random()); world.add(m);
    sc.cloud.puffs.push({m, target: new THREE.Vector3(sc.cloud.x + Math.cos(a) * r, 0.5 + Math.random() * 3.0 * (1 - r / 7), Math.sin(a) * r * 0.8), d: Math.random() * 0.25, spin: 0});
  }
  pop("POOF!", "#ffffff", 30, new THREE.Vector3(sc.x + 3, 6.5, 0));
}
function updateQuills(dt) {
  for (let i = quills.length - 1; i >= 0; i--) {
    const q = quills[i]; q.t += dt; const u = Math.min(1, q.t / q.tt);
    const p = q.from.clone().lerp(q.to, u); p.y += Math.sin(Math.PI * u) * q.arc; const prev = q.m.position.clone(); q.m.position.copy(p);
    const d = p.clone().sub(prev); if (d.lengthSq() > 1e-6) q.m.rotation.set(0, Math.atan2(-d.z, d.x), Math.atan2(d.y, Math.hypot(d.x, d.z)));
    if (u >= 1) { world.remove(q.m); quills.splice(i, 1); const b = bots[0]; b.flash = 1; b.knock = Math.min(1, b.knock + 0.25); b.hp -= 4;
      sparks(q.to, 0xffe08a, 3, 6); pop("4", "#ffffff", 20, q.to.clone().add(new THREE.Vector3(0, 1.4, 0)), 0.6);
      sc.hits = (sc.hits || 0) + 1; const n = [5, 8, 12, 17][Math.max(0, stepIdx())];
      if (sc.hits === n) pop(`${n * 4}<small>${n} QUILLS × 4</small>`, "#ffc832", 40, new THREE.Vector3(b.g.position.x, 6.2, -0.6), 1.3); }
  }
}

// ---------- UI ----------
function drawUI() {
  const P = PARTS[part];
  $("parts").innerHTML = ""; $("looks").innerHTML = ""; $("steps").innerHTML = "";
  PARTS.forEach((p, i) => { const b = document.createElement("button"); b.className = "tab"; b.setAttribute("aria-pressed", i === part); b.innerHTML = p.name + "<small>" + p.area + " · " + p.key + "</small>";
    b.onclick = () => { part = i; look = 0; buildLook(); reset(); drawUI(); }; $("parts").appendChild(b); });
  P.looks.forEach((L, i) => { const b = document.createElement("button"); b.className = "tab"; b.setAttribute("aria-pressed", i === look); b.innerHTML = L.name + "<small>" + L.sub + "</small>";
    b.onclick = () => { look = i; buildLook(); reset(); drawUI(); }; $("looks").appendChild(b); });
  ["I", "II", "III", "★"].forEach((k, i) => { const b = document.createElement("button"); b.className = "tab step"; b.setAttribute("aria-pressed", i === step); b.textContent = k;
    b.onclick = () => { step = i; reset(); drawUI(); }; $("steps").appendChild(b); });
  $("lookName").textContent = P.looks[look].name; $("lookWhy").textContent = P.looks[look].why; $("lookParts").textContent = P.looks[look].parts;
  $("partTitle").textContent = P.name + " · " + P.area + " · mecha part";
  $("stepList").innerHTML = P.steps.map((s, i) => `<li class="${i === step ? "cur" : ""}"><b>${["I", "II", "III", "★"][i]}</b><span>${s}</span></li>`).join("");
  $("partNote").textContent = P.note;
  const si = stepIdx(), hud = {glider: si >= 0 ? `GLIDE <b>8 studs/s fall</b>${si >= 1 ? " · DROP <b>55 studs</b>" : ""}` : "no glider",
    quills: si >= 0 ? `QUILLS <b>${[5, 8, 12, 17][si]} × 4</b> · cooldown <b>20 s</b>` : "no launcher",
    smoke: si >= 0 ? `CLOUD <b>${si >= 1 ? 6 : 4} s</b> · 12 studs${si >= 2 ? " · <b>+25% run</b> inside" : ""}` : "no smoke",
    plating: si >= 0 ? `FROM BEHIND <b>-${[10, 15, 22, 30][si]}%</b> · front unchanged` : "no plating"}[P.id];
  $("hud").innerHTML = `<div>${hud}</div>`;
  $("bar").innerHTML = `<div class="tile"><span class="k">ATK</span>SLASH</div><div class="tile"><span class="k">SPC</span>JUMP</div>` +
    (slotted ? `<div class="tile part" id="tPart"><span class="k">R</span>${P.name.toUpperCase().replace(" ", "<br>")}<div class="cd" id="cd"></div><span class="cdt" id="cdt"></span></div>` : `<div class="tile empty"><span class="k">R</span>—</div>`) +
    `<div class="tile empty"><span class="k">C</span>—</div>`;
  $("slotBtn").textContent = "Slotted: " + (slotted ? "ON" : "OFF"); $("slotBtn").setAttribute("aria-pressed", slotted);
  $("viewBtn").setAttribute("aria-pressed", labView); $("slowBtn").setAttribute("aria-pressed", slow);
}
$("slotBtn").onclick = () => { slotted = !slotted; buildLook(); reset(); drawUI(); };
$("viewBtn").onclick = () => { labView = !labView; reset(); drawUI(); };
$("slowBtn").onclick = () => { slow = !slow; drawUI(); };
$("goBtn").onclick = () => { labView = false; reset(); drawUI(); };

// ---------- frame ----------
let last = performance.now(), camX = 0, camY = 3;
function frame(now) {
  let dt = Math.min(0.05, (now - last) / 1000); last = now; if (slow) dt *= 0.3;
  const P = PARTS[part].id;
  if (!labView) stepScenario(dt); else { deploy = 1; lid = 0.6; capPop = 0; }
  const o = poseFor(dt);
  applyPose(o, new THREE.Vector3(labView ? 0 : sc.x, labView ? 0 : sc.alt, 0), labView ? -Math.PI / 2 + now / 1000 * 0.6 : -Math.PI / 2);
  if ((sc.mode === "run" || sc.mode === "out" || sc.mode === "hideRun") && !labView && sc.alt <= 0.01) {
    const side = Math.sin(sc.phase) > 0 ? 1 : -1; if (side !== sc.lastSide) { sc.lastSide = side; dust(new THREE.Vector3(sc.x - 0.5, 0.15, side * 0.4), false); } }
  updateQuills(dt);
  // smoke puffs
  if (sc.cloud) for (const p of sc.cloud.puffs) { const age = T - sc.cloud.t - p.d; if (age < 0) continue; const k = Math.min(1, age / 0.35);
    p.m.position.lerp(p.target, Math.min(1, dt * 8)); p.m.rotation.y += p.spin * dt; const wob = 1 + 0.06 * Math.sin(T * 3 + p.d * 20);
    p.m.scale.setScalar((0.3 + 0.7 * k) * wob * (1 - 0.5 * (sc.cloud.fade || 0))); p.m.material.opacity = 0.93 * k * (1 - (sc.cloud.fade || 0)); }
  // bots
  for (const b of bots) { b.flash = Math.max(0, b.flash - dt * 5); b.knock = Math.max(0, b.knock - dt * 3); b.m.emissive.setRGB(b.flash, b.flash * 0.2, b.flash * 0.1);
    if (P !== "plating") { b.body.rotation.z = -b.knock * 0.35; b.body.position.x = -b.knock * 0.6; } b.g.visible = b.g.visible && !labView; }
  // fx
  for (let i = fx.length - 1; i >= 0; i--) { const f = fx[i]; f.life -= dt; if (f.life <= 0) { world.remove(f.m); fx.splice(i, 1); continue; }
    f.v.y += f.g * dt; f.m.position.addScaledVector(f.v, dt); const a = f.life / f.max; f.m.material.opacity = a; if (f.grow) f.m.scale.setScalar(1 + (1 - a) * (f.grow - 1)); }
  scenery.visible = !labView; scene.background = labView ? labBg : sky; scene.fog.near = labView ? 1000 : 40; scene.fog.far = labView ? 2000 : 90;
  // camera
  if (labView) { const g = PARTS[part].id === "glider"; cam.position.set(5, g ? 11 : 5, g ? 17 : 15); cam.lookAt(0, 1.6, 0); cam.fov = 30; }
  else { const tx = P === "plating" ? sc.x - 1 : (P === "smoke" ? (sc.x + sc.botX) / 2 + 1 : P === "quills" ? -4.5 : sc.x + 3);
    const ty = 1.4 + sc.alt * 0.85; camX += (tx - camX) * Math.min(1, dt * 4 + 0.001); camY += (ty - camY) * Math.min(1, dt * 4 + 0.001);
    const dist = P === "quills" ? 25 : P === "smoke" ? 20 : 16 + sc.alt * 0.4;
    if (P === "glider") { cam.position.set(camX + 4, camY + 9, 17); cam.lookAt(camX + 1, camY - 0.5, 0); }
    else cam.position.set(camX + (P === "quills" ? 0 : 6), camY + 4 + (P === "plating" ? 2 : 0), dist), cam.lookAt(camX, camY, 0);
    cam.fov = 38; }
  cam.updateProjectionMatrix(); renderer.render(scene, cam);
  // overlays
  const r = cv.getBoundingClientRect();
  for (let i = pops.length - 1; i >= 0; i--) { const p = pops[i]; p.t += (slow ? 0.3 : 1) * 0.016; const v = p.p.clone(); v.y += p.t * 2.2; v.project(cam);
    const s = p.t < 0.08 ? 1.7 - p.t * 8 : 1; p.el.style.left = ((v.x + 1) / 2 * r.width) + "px"; p.el.style.top = ((1 - v.y) / 2 * r.height) + "px";
    p.el.style.transform = `translate(-50%,-50%) scale(${s})`; p.el.style.opacity = Math.min(1, (p.life - p.t) * 3); if (p.t > p.life) { p.el.remove(); pops.splice(i, 1); } }
  const head = partWorld("Head_cranium", [0, 1.6, 0]).project(cam), meT = $("tagMe");
  const hiddenNow = P === "smoke" && sc.cloud && Math.abs(sc.x - sc.cloud.x) < 6 && !(sc.cloud.fade >= 1);
  meT.style.display = labView || P === "glider" || P === "quills" ? "none" : "block"; meT.style.opacity = hiddenNow ? 0 : 1;
  meT.style.left = ((head.x + 1) / 2 * r.width) + "px"; meT.style.top = ((1 - head.y) / 2 * r.height) + "px"; $("meFill").style.width = (sc.meHp / 40 * 100) + "%";
  meT.querySelector("span").textContent = hiddenNow ? "" : "you (Herrera)";
  const b0 = bots[0], bh = new THREE.Vector3(b0.g.position.x, 5.2, b0.g.position.z).project(cam), bt = $("tagBot");
  bt.style.display = labView || !b0.g.visible || P === "plating" || P === "smoke" ? "none" : "block";
  bt.style.left = ((bh.x + 1) / 2 * r.width) + "px"; bt.style.top = ((1 - bh.y) / 2 * r.height) + "px"; $("botFill").style.width = Math.max(0, b0.hp / 2) + "%";
  const cd = $("cd"), cdt = $("cdt");
  if (cd) { const total = P === "quills" ? 20 : P === "smoke" ? 18 : 0; const since = sc.cdAt !== undefined ? T - sc.cdAt : (sc.cloud ? T - sc.cloud.t : -1);
    if (total && since >= 0) { cd.style.height = "100%"; cdt.textContent = Math.ceil(total - since * 4) + "s"; } else { cd.style.height = "0"; cdt.textContent = P === "glider" ? "" : ""; } }
  requestAnimationFrame(frame);
}
function resize() { const w = stage.clientWidth; renderer.setSize(w, w * 9 / 16, false); cam.aspect = 16 / 9; }
window.addEventListener("resize", resize);
buildLook(); reset(); drawUI(); resize(); requestAnimationFrame(frame);
