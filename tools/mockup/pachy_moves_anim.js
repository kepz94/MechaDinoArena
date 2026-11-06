// pachy_moves_anim.js v0.1 (Mecha Dino Arena) — the Pachy animation pass (Kepu 2026-11-05 23:02 "Next" -> Pachy -> "Moves
// animation pass", scope "All 11" + "Yes, headbutt + hook smash" victim stagger). Engine = tools/dilo_kit_mockup/app.js
// (scene, rigs, springs, FX; prepended by the build up to its "moves" section; its main rig `dilo` is the pachy here, built
// from PachyModelData 1.5 at game scale 2). Mecha parts = PARTS_DATA (pachy_parts.json, read from the server builders:
// HookServer, ServoDashServer, VisorServer, InkServer, TetherServer, BloodVialServer, MechaLegsServer, MedStationServer).
// Eleven moves, each Now (as the game plays it, v479) + A / B / C, every one wind-up -> action -> result -> recovery.
// Numbers are the game's (PachyModelData 1.5, SkillTree 1.68 pachy rows); where a version changes timing it says so.
const ANIM_VERSION = "0.1";
const pachy = dilo;

// ---------- shared state + helpers ----------
const R0 = raps[0], R1 = raps[1];
function place(R, x, z, yaw) { R.show = true; R.pos.set(x, 0, z); R.yaw = yaw; R.path = null; R.run = 0; }
let hitStop = 0, shake = 0, clockT = 0, idleT = 0, fovPunch = 0;
function vig(color, a) { const v = $("vig"); v.style.transition = "none"; v.style.background = `radial-gradient(ellipse at center, transparent 55%, ${color} 100%)`; v.style.opacity = a; requestAnimationFrame(() => { v.style.transition = "opacity .4s"; v.style.opacity = 0; }); }
const PN = n => pachy.parts.find(p => p.name === n);
const PP = {beak: PN("Head_beak"), skull: PN("Head_skull"), dome: PN("Head_dome3") || PN("Head_dome2"), domeFront: PN("Head_domefront"), nostril: PN("Head_nostrilL"),
  torso: PN("Torso_body"), chest: PN("Torso_chest"), hips: PN("Torso_hips"), tail1: pachy.segs.Tail1[0], footL: pachy.segs.FootL[0], footR: pachy.segs.FootR[0]};
const domePoint = () => partPoint(PP.domeFront).lerp(partPoint(PP.dome), 0.3);
const beakPoint = () => partPoint(PP.beak);
const headDirP = () => partPoint(PP.beak).sub(partPoint(PP.skull)).normalize();
const fwdOf = () => new THREE.Vector3(0, 0, -1);
const headOf = R => partPoint(R.rig.segs.Head[0]);
const T_DUST = radialTex("rgba(225,205,160,0.85)", "rgba(200,180,140,0)");
const T_SMOKE = radialTex("rgba(40,40,46,0.9)", "rgba(30,30,36,0)");
const T_INK = radialTex("rgba(20,16,30,1)", "rgba(20,16,30,0)", 0.55);
function puff(p, v, size, color, life, tex) { const s = sprite(tex || T_MIST, color || 0xffffff, size, false); s.position.copy(p);
  addFx(s, life || 0.6, (o, u, dt) => { o.position.addScaledVector(v, dt); o.scale.setScalar(size * (1 + u * 2.4)); o.material.opacity = 0.75 * (1 - u); }); }
function dust(p, n, spread, up, size) { for (let i = 0; i < n; i++) puff(p.clone().add(new THREE.Vector3((Math.random() - .5) * spread, 0.6, (Math.random() - .5) * spread)), new THREE.Vector3((Math.random() - .5) * 8, (up || 3) * Math.random(), (Math.random() - .5) * 8), size || 2.6, 0xe8d8b0, 0.7, T_DUST); }
function groundRing(center, r1, color, life, op) {
  const m = new THREE.Mesh(new THREE.RingGeometry(0.86, 1, 56), new THREE.MeshBasicMaterial({color, transparent: true, opacity: op || 0.8, depthWrite: false, side: THREE.DoubleSide}));
  m.rotation.x = -Math.PI / 2; m.position.copy(center).setY(0.15);
  addFx(m, life, (o, u) => { const r = 1 + (r1 - 1) * E.out(u); o.scale.setScalar(r); o.material.opacity = (op || 0.8) * (1 - u); });
}
function streaks(p, dir, n, color, len) { for (let i = 0; i < n; i++) { const g = new THREE.Mesh(new THREE.BoxGeometry(0.18, 0.18, len || 3.2), new THREE.MeshBasicMaterial({color: color || 0xffffff, transparent: true, depthWrite: false}));
  const q = p.clone().add(new THREE.Vector3((Math.random() - .5) * 8, 2 + Math.random() * 8, (Math.random() - .5) * 6)); g.position.copy(q); g.lookAt(q.clone().add(dir));
  addFx(g, 0.3, (o, u, dt) => { o.position.addScaledVector(dir, -dt * 40); o.material.opacity = 0.8 * (1 - u); }); } }
function hitNum(p, n, style) { numberPop(p.clone().add(new THREE.Vector3(0, 5, 0)), n, style || "hit"); }
function tag(p, text, color, life) { return textTag(p.clone().add(new THREE.Vector3(0, 6, 0)), text, color, life || 1.1); }
// a raptor gets hit: flinch (as now) or the new stagger (victim hit-react)
function hitRaptor(R, p, n, opts) {
  opts = opts || {};
  hitStop = opts.stop || 0.08; shake = Math.max(shake, opts.shake || 0.9); fovPunch = opts.fov || 2;
  flash(p, opts.flashSize || 10, opts.flashCol); dust(p.clone().setY(0.5), 6, 6, 4);
  if (n !== null) hitNum(p, n, opts.big ? "big" : "hit");
  R.flash = 0.12; R.flashCol = opts.flashRGB || [0.9, 0.85, 0.7];
  R.pushDir.copy(R.pos).sub(pachy.pos).setY(0).normalize(); if (R.pushDir.lengthSq() < 0.1) R.pushDir.set(0, 0, -1);
  R.shove = opts.shove || 0; R.shoveT = 0; R.shoveTime = opts.shoveTime || 0.35;
  if (opts.stagger) { R.stagger = 1; R.flinch = 0; } else { R.flinch = 1; }
}

// ---------- mecha parts (PARTS_DATA from the server builders) ----------
const PA = {}; // per-frame part animation state, reset by each track
const hiddenBody = new Set(); // body parts the hook prosthesis replaces (HookServer hideArm)
const partGroups = {}; // id -> [{mesh, seg, local, piece}]
const _pm = new THREE.Matrix4();
function eulerDeg(r) { return new THREE.Matrix4().makeRotationFromEuler(new THREE.Euler(rad(r[0]), rad(r[1]), rad(r[2]), "XYZ")); }
function buildParts() {
  for (const id in PARTS_DATA) {
    const P = PARTS_DATA[id]; if (!P || !P.pieces || P.world) continue; partGroups[id] = [];
    for (const n of (P.hidden || [])) hiddenBody.add(n);
    for (const pc of P.pieces) {
      const sz = pc.size;
      let geo;
      if (pc.shape === "Cylinder") { geo = new THREE.CylinderGeometry(Math.min(sz[1], sz[2]) / 2, Math.min(sz[1], sz[2]) / 2, sz[0], 14); geo.rotateZ(Math.PI / 2); }
      else if (pc.shape === "Ball") geo = new THREE.SphereGeometry(Math.min(sz[0], sz[1], sz[2]) / 2, 14, 10);
      else if (pc.shape === "Wedge") { geo = new THREE.BoxGeometry(sz[0], sz[1], sz[2]); }
      else geo = new THREE.BoxGeometry(sz[0], sz[1], sz[2]);
      const neon = /neon/i.test(pc.material || ""), field = /forcefield/i.test(pc.material || "");
      if ((pc.transp || 0) >= 1) continue; // invisible in the game (the hook's Barrel)
      const m = new THREE.Mesh(geo, field ? new THREE.MeshBasicMaterial({color: parseInt(pc.color, 16), transparent: true, opacity: 0.38, depthWrite: false, side: THREE.DoubleSide})
        : new THREE.MeshLambertMaterial({color: parseInt(pc.color, 16), emissive: neon ? parseInt(pc.color, 16) : 0, emissiveIntensity: neon ? 0.7 : 1, transparent: (pc.transp || 0) > 0, opacity: 1 - (pc.transp || 0)}));
      m.matrixAutoUpdate = false; m.castShadow = !field; pachy.g.add(m);
      const anchor = pc.anchor ? pachy.parts.find(p => p.name === pc.anchor) : null;
      const segName = anchor ? anchor.seg : pc.seg;
      const base = anchor ? anchor.local.clone() : new THREE.Matrix4();
      const local = base.multiply(new THREE.Matrix4().makeTranslation(pc.pos[0], pc.pos[1], pc.pos[2])).multiply(eulerDeg(pc.rotDeg || [0, 0, 0]));
      partGroups[id].push({mesh: m, seg: segName, local, piece: pc, n: pc.n, baseOp: 1 - (pc.transp || 0), baseCol: parseInt(pc.color, 16)});
    }
  }
}

function placeParts() {
  const S = new THREE.Matrix4().makeScale(pachy.scale, pachy.scale, pachy.scale);
  const TS = new THREE.Matrix4().makeTranslation(pachy.pos.x, pachy.y, pachy.pos.z).multiply(S);
  for (const id in partGroups) {
    const on = !!(PA.show && PA.show.includes(id));
    for (const g of partGroups[id]) {
      const anim = PART_ANIM[id] ? PART_ANIM[id](g) : null;
      g.mesh.visible = on && !(anim && anim.hide);
      if (!g.mesh.visible) continue;
      g.mesh.matrix.copy(TS).multiply(pachy.W[g.seg]).multiply(g.local);
      if (anim && anim.m) g.mesh.matrix.multiply(anim.m);
      if (anim && anim.em !== undefined) { g.mesh.material.emissive.setHex(anim.emCol || g.baseCol); g.mesh.material.emissiveIntensity = anim.em; }
      if (anim && anim.op !== undefined) { g.mesh.material.transparent = true; g.mesh.material.opacity = anim.op; }
    }
  }
  for (const p of pachy.parts) p.mesh.visible = !hiddenBody.has(p.name) || !(PA.show && PA.show.includes("hook"));
}
const PT = {claw: () => partPos("hook", "Point"), hookHousing: () => partPos("hook", "Housing"), spool: () => partPos("hook", "Spool"),
  bell: () => partPos("servodash", "Bell_L", 0, 0, -0.18), bellR: () => partPos("servodash", "Bell_R", 0, 0, -0.18),
  lens: () => partPos("visor", "Lens_R"), muzzle: () => partPos("ink", "Barrel", 0, 0, -0.53), tetherTip: () => partPos("tether", "Barrel", 0, 0, -0.71),
  nozzle: () => partPos("bloodvial", Math.random() < 0.5 ? "Nozzle_L" : "Nozzle_R")};
const partPos = (id, n, lx, ly, lz) => { const g = (partGroups[id] || []).find(x => x.n === n); return g ? new THREE.Vector3(lx || 0, ly || 0, lz || 0).applyMatrix4(g.mesh.matrix) : pachy.pos.clone().setY(8); };
// per-part animation hooks: return {hide, m (extra local matrix), em, op}
const PART_ANIM = {
  hook(g) { if (/^(Shank|Bend|Barb|Point)$/.test(g.n) && PA.hookOut) return {hide: true};
    if (/spool/i.test(g.n) && PA.spool) return {m: new THREE.Matrix4().makeRotationX(PA.spool)}; return null; },
  servodash(g) { const r = {}; if (/bell/i.test(g.n) && PA.swivel) r.m = new THREE.Matrix4().makeRotationX(rad(PA.swivel));
    if (/bell|nozzle|glow/i.test(g.n) && PA.glow) { r.em = PA.glow; r.emCol = 0xff8a2a; } return r; },
  visor(g) { if (/^Panel_/.test(g.n)) { const k0 = PA.field || 0; if (k0 <= 0) return {hide: true};
      const i = +g.n.slice(6) - 1, order = Math.abs(i - 4) / 4; let k = k0, sy = 1;
      if (PA.fieldMode === "seq") k = Math.min(1, Math.max(0, k0 * 1.8 - order * 0.8)); if (PA.fieldMode === "grow") sy = Math.max(0.01, k0);
      const rip = PA.ripple ? 0.3 * Math.max(0, Math.sin(clockT * 30 - i)) : 0; return {op: 0.38 * k + rip, m: new THREE.Matrix4().makeScale(1, sy, 1), hide: k <= 0.01}; }
    if (/^Lens/.test(g.n)) return {em: PA.lens || 0.35, emCol: 0x5fe3ff}; return null; },
  ink(g) { if (/tank/i.test(g.n) && PA.pump) { const s = 1 + PA.pump; return {m: new THREE.Matrix4().makeScale(s, s, s)}; }
    if (/barrel|muzzle/i.test(g.n) && PA.kick) return {m: new THREE.Matrix4().makeTranslation(0, 0, PA.kick)}; return null; },
  tether(g) { if (g.n === "Tip" && PA.tipGone) return {hide: true}; if (/^(Barrel|Tip)$/.test(g.n) && PA.recoil) return {m: new THREE.Matrix4().makeTranslation(0, 0, PA.recoil)}; return null; },
  bloodvial(g) { if (/^Blood_/.test(g.n) && PA.level !== undefined) { const L = Math.max(0.02, PA.level); return {m: new THREE.Matrix4().makeTranslation(0, -(1 - L) * g.piece.size[1] / 2, 0).multiply(new THREE.Matrix4().makeScale(1, L, 1)), em: PA.vialGlow || 0, emCol: 0xff2030}; } return null; },
  mechalegs(g) { const r = {}; if (/^Piston/.test(g.n) && PA.piston) r.m = new THREE.Matrix4().makeTranslation(0, -PA.piston * 0.35, 0);
    if (/vent/i.test(g.n) && PA.heat) { r.em = PA.heat; r.emCol = 0xff8a2a; } return r; },
};

// ---------- key poses (degrees {p, y, r}; + = rear back / nose up for RootJoint / Neck / Head; Arm / Leg + = swing forward;
// Knee - = bend; Ankle + = toes up; Tail + = droop, - = lift; Jaw - = open; y + = turn to the dino's R side) ----------
// Now (HeadbuttPose 1.0): rear-up in the first 40% of the 0.15 s wind-up, then low; impact snaps the dome up + shake
const HB_REAR = BOTH({RootJoint: [5, 0, 0], Neck: [12, 0, 0], Head: [8, 0, 0]});
const HB_LOW = BOTH({RootJoint: [-8, 0, 0], Neck: [-26, 0, 0], Head: [-38, 0, 0], ArmL: [-35, 0, 0], Tail1: [6, 0, 0]});
const HB_HIT = BOTH({RootJoint: [3, 0, 0], Neck: [22, 0, 0], Head: [20, 0, 0]});
// A · Bull Charge
const PAW = Object.assign(BOTH({RootJoint: [-10, 0, 0], Neck: [-22, 0, 0], Head: [-34, 0, 0], ArmL: [-34, 0, 0], Tail1: [-8, 0, 0], Tail2: [-4, 0, 0], root: {fwd: -0.8}}),
  {LegL: [20, 0, 0], KneeL: [-34, 0, 0], AnkleL: [12, 0, 0], LegR: [-30, 0, 0], KneeR: [-8, 0, 0], AnkleR: [-22, 0, 0]});
const BULL_LOW = BOTH({RootJoint: [-13, 0, 0], Neck: [-30, 0, 0], Head: [-44, 0, 0], ArmL: [-42, 0, 0], Tail1: [-2, 0, 0], Tail2: [-2, 0, 0]});
const CRUNCH = BOTH({RootJoint: [-15, 0, 0], Neck: [-36, 0, 0], Head: [-48, 0, 0], ArmL: [-40, 0, 0], root: {fwd: 0.6}});
const RECOIL_UP = Object.assign(BOTH({RootJoint: [9, 0, 0], Neck: [26, 0, 0], Head: [24, 0, 0], Jaw: [-10, 0, 0], ArmL: [12, 0, 0], Tail1: [8, 0, 0], root: {fwd: -1.6}}),
  {LegL: [16, 0, 0], KneeL: [-20, 0, 0], LegR: [-6, 0, 0]});
// B · Ram Rear
const RAM_REAR = BOTH({RootJoint: [15, 0, 0], Neck: [30, 0, 0], Head: [18, 0, 0], Jaw: [-14, 0, 0], ArmL: [24, 0, 0], LegL: [8, 0, 0], KneeL: [-22, 0, 0], AnkleL: [10, 0, 0], Tail1: [12, 0, 0], Tail2: [6, 0, 0], root: {fwd: -1.2}});
const RAM_SLAM = BOTH({RootJoint: [-14, 0, 0], Neck: [-30, 0, 0], Head: [-40, 0, 0], ArmL: [-30, 0, 0], LegL: [14, 0, 0], KneeL: [-36, 0, 0], AnkleL: [16, 0, 0], Tail1: [-10, 0, 0], root: {fwd: 0.4}});
const RAM_BOUNCE = BOTH({RootJoint: [14, 0, 0], Neck: [30, 0, 0], Head: [26, 0, 0], Jaw: [-16, 0, 0], ArmL: [30, 0, 0], Tail1: [14, 0, 0], Tail2: [8, 0, 0], root: {fwd: -2}});
// C · Battering Lean
const LEAN_LOW = BOTH({RootJoint: [-17, 0, 0], Neck: [-18, 0, 0], Head: [-50, 0, 0], ArmL: [-45, 0, 0], Tail1: [-12, 0, 0], Tail2: [-6, 0, 0], Tail3: [-4, 0, 0]});
const SKID = Object.assign(BOTH({RootJoint: [10, 0, 0], Neck: [18, 0, 0], Head: [16, 0, 0], Jaw: [-8, 0, 0], ArmL: [20, 0, 0], Tail1: [10, 0, 0], root: {fwd: -3}}),
  {LegL: [34, 0, 0], KneeL: [-12, 0, 0], AnkleL: [20, 0, 0], LegR: [10, 0, 0], KneeR: [-30, 0, 0]});
// leap (JumpPose 1.0 values on this rig)
const PJ_CROUCH = BOTH({RootJoint: [-12, 0, 0], Neck: [-18, 0, 0], Head: [6, 0, 0], ArmL: [-25, 0, 0], LegL: [34, 0, 0], KneeL: [-58, 0, 0], AnkleL: [26, 0, 0], Tail1: [10, 0, 0]});
const PJ_PUSH = BOTH({RootJoint: [14, 0, 0], Neck: [10, 0, 0], Head: [-4, 0, 0], ArmL: [-25, 0, 0], LegL: [-22, 0, 0], KneeL: [-4, 0, 0], AnkleL: [-40, 0, 0], Tail1: [-10, 0, 0]});
const PJ_AIR = BOTH({RootJoint: [4, 0, 0], Neck: [10, 0, 0], Head: [-6, 0, 0], ArmL: [-35, 0, 0], LegL: [40, 0, 0], KneeL: [-72, 0, 0], AnkleL: [30, 0, 0], Tail1: [-10, 0, 0], Tail2: [-4, 0, 0]});
const J_REACH = BOTH({RootJoint: [-6, 0, 0], Neck: [12, 0, 0], Head: [-6, 0, 0], ArmL: [-20, 0, 0], LegL: [30, 0, 0], KneeL: [-30, 0, 0], AnkleL: [-10, 0, 0], Tail1: [-6, 0, 0]});
const PJ_LAND = BOTH({RootJoint: [-8, 0, 0], Neck: [-12, 0, 0], Head: [4, 0, 0], ArmL: [6, 0, 0], LegL: [24, 0, 0], KneeL: [-42, 0, 0], AnkleL: [18, 0, 0], Tail1: [8, 0, 0]});
// A · Coiled Spring
const J_COIL = addPose(PJ_CROUCH, {RootJoint: [-4, 0, 0], Neck: [-10, 0, 0], Head: [-16, 0, 0], KneeL: [-12, 0, 0], KneeR: [-12, 0, 0], AnkleL: [6, 0, 0], AnkleR: [6, 0, 0], Tail1: [6, 0, 0], Tail2: [6, 0, 0]}, 1);
const J_FIRE = BOTH({RootJoint: [-10, 0, 0], Neck: [-14, 0, 0], Head: [-20, 0, 0], ArmL: [-40, 0, 0], LegL: [-34, 0, 0], KneeL: [-2, 0, 0], AnkleL: [-44, 0, 0], Tail1: [-14, 0, 0], Tail2: [-8, 0, 0]});
const J_BALL = BOTH({RootJoint: [-10, 0, 0], Neck: [-24, 0, 0], Head: [-30, 0, 0], ArmL: [-40, 0, 0], LegL: [56, 0, 0], KneeL: [-96, 0, 0], AnkleL: [40, 0, 0], Tail1: [14, 0, 0], Tail2: [12, 0, 0], Tail3: [10, 0, 0]});
const J_KICK = BOTH({RootJoint: [6, 0, 0], Neck: [6, 0, 0], Head: [-10, 0, 0], ArmL: [-30, 0, 0], LegL: [-12, 0, 0], KneeL: [-6, 0, 0], AnkleL: [-40, 0, 0], Tail1: [-16, 0, 0], Tail2: [-8, 0, 0]});
const J_ABSORB = addPose(PJ_LAND, {KneeL: [-16, 0, 0], KneeR: [-16, 0, 0], LegL: [6, 0, 0], LegR: [6, 0, 0], Neck: [-6, 0, 0]}, 1);
// B · Dome Dive
const J_DIVE = BOTH({RootJoint: [-22, 0, 0], Neck: [-22, 0, 0], Head: [-34, 0, 0], ArmL: [-40, 0, 0], LegL: [-20, 0, 0], KneeL: [-30, 0, 0], AnkleL: [-20, 0, 0], Tail1: [-18, 0, 0], Tail2: [-10, 0, 0]});
const J_FLIPKICK = BOTH({RootJoint: [18, 0, 0], Neck: [14, 0, 0], Head: [-4, 0, 0], ArmL: [10, 0, 0], LegL: [-30, 0, 0], KneeL: [-4, 0, 0], AnkleL: [-30, 0, 0], Tail1: [14, 0, 0]});
// C · Stomp
const J_SPLAY = Object.assign(BOTH({RootJoint: [6, 0, 0], Neck: [18, 0, 0], Head: [-8, 0, 0], Jaw: [-10, 0, 0], ArmL: [20, 0, 0], Tail1: [-12, 0, 0]}), {LegL: [36, 0, 0], KneeL: [-20, 0, 0], LegR: [-30, 0, 0], KneeR: [-40, 0, 0]});
const J_SCISSOR = Object.assign(BOTH({RootJoint: [6, 0, 0], Neck: [14, 0, 0], ArmL: [10, 0, 0], Tail1: [-10, 0, 0]}), {LegL: [-30, 0, 0], KneeL: [-30, 0, 0], LegR: [40, 0, 0], KneeR: [-16, 0, 0]});
const J_STOMP = BOTH({RootJoint: [-10, 0, 0], Neck: [-22, 0, 0], Head: [-10, 0, 0], Jaw: [-12, 0, 0], ArmL: [-30, 0, 0], LegL: [30, 0, 0], KneeL: [-60, 0, 0], AnkleL: [28, 0, 0], Tail1: [12, 0, 0]});
// Grappling Hook (HookPose 1.2): the hook arm is ArmL (the pachy's real right arm); ARM_LEVEL 56 + the aim pitch
const H_RAISE = {ArmL: [62, 0, 0], RootJoint: [3, 0, 0], Neck: [4, 0, 0]};
const H_DIP = {ArmL: [10, 0, 0], RootJoint: [-6, 0, 0], Neck: [-30, 0, 0], Head: [-40, 0, 0]};
const H_BRACE = Object.assign({ArmL: [62, 0, 0], ArmR: [-20, 0, 0], RootJoint: [-6, 6, 0], Neck: [-4, -6, 0], Head: [-4, 0, 0], Tail1: [4, -8, 0]},
  {LegL: [14, 0, -6], KneeL: [-26, 0, 0], AnkleL: [12, 0, 0], LegR: [-16, 0, 6], KneeR: [-18, 0, 0], AnkleR: [-6, 0, 0], root: {fwd: -0.4}});
const H_KICK = addPose(H_BRACE, {ArmL: [14, 0, 0], RootJoint: [6, 0, 0], Neck: [6, 0, 0], root: {fwd: -0.8}}, 1);
const H_REEL = addPose(H_BRACE, {ArmL: [-26, 0, 0], RootJoint: [8, 0, 0], Neck: [6, 0, 0], Head: [4, 0, 0], root: {fwd: -1.2}}, 1);
const H_COCK = {ArmL: [10, 0, 0], ArmR: [-10, 0, 0], RootJoint: [10, 0, 0], Neck: [22, 0, 0], Head: [16, 0, 0], Jaw: [-10, 0, 0], Tail1: [8, 0, 0], root: {fwd: -1}};
const H_SMASH = {ArmL: [-30, 0, 0], ArmR: [-30, 0, 0], RootJoint: [-12, 0, 0], Neck: [-34, 0, 0], Head: [-46, 0, 0], Tail1: [-6, 0, 0], root: {fwd: 1.4}};
const H_WINDBACK = {ArmL: [-50, 0, -10], RootJoint: [4, -14, 0], Neck: [6, 8, 0], Head: [2, 6, 0], Tail1: [0, 10, 0], root: {fwd: -0.4}};
const H_CAST = {ArmL: [78, 0, 0], RootJoint: [-6, 10, 0], Neck: [-6, -6, 0], Head: [-4, 0, 0], Tail1: [0, -10, 0], root: {fwd: 0.6}};
const H_YANK = {ArmL: [10, 0, 0], RootJoint: [10, -12, 0], Neck: [10, 6, 0], Head: [6, 0, 0], Tail1: [6, 12, 0], LegL: [16, 0, 0], KneeL: [-20, 0, 0], root: {fwd: -1.2}};
const H_UPPER_LOW = {ArmL: [0, 0, 0], RootJoint: [-10, 0, 0], Neck: [-26, 0, 0], Head: [-30, 0, 0], root: {fwd: 0.4}};
const H_UPPER = {ArmL: [20, 0, 0], ArmR: [20, 0, 0], RootJoint: [12, 0, 0], Neck: [28, 0, 0], Head: [30, 0, 0], Jaw: [-10, 0, 0], root: {fwd: 1}};
const H_SIGHT = {ArmL: [60, 0, 0], ArmR: [46, 0, 12], RootJoint: [-4, 0, 0], Neck: [-10, 8, 0], Head: [-6, 6, 0], LegL: [10, 0, 0], KneeL: [-20, 0, 0], LegR: [-6, 0, 0], KneeR: [-14, 0, 0]};
// Servo Dash
const SQUAT = BOTH({RootJoint: [-6, 0, 0], Neck: [-8, 0, 0], Head: [-4, 0, 0], ArmL: [-30, 0, 0], LegL: [30, 0, 0], KneeL: [-56, 0, 0], AnkleL: [24, 0, 0], Tail1: [6, 0, 0]});
const BLAST = BOTH({RootJoint: [-18, 0, 0], Neck: [-14, 0, 0], Head: [-20, 0, 0], Jaw: [-6, 0, 0], ArmL: [-48, 0, 0], LegL: [-30, 0, 0], KneeL: [-10, 0, 0], AnkleL: [-36, 0, 0], Tail1: [-14, 0, 0], Tail2: [-6, 0, 0]});
const DASH_RUN = BOTH({RootJoint: [-10, 0, 0], Neck: [-10, 0, 0], Head: [-14, 0, 0], ArmL: [-40, 0, 0], Tail1: [-8, 0, 0], Tail2: [-4, 0, 0]});
const BRAKE = Object.assign(BOTH({RootJoint: [12, 0, 0], Neck: [16, 0, 0], Head: [10, 0, 0], ArmL: [20, 0, 0], Tail1: [12, 0, 0], root: {fwd: -1.2}}), {LegL: [36, 0, 0], KneeL: [-14, 0, 0], AnkleL: [22, 0, 0], LegR: [14, 0, 0], KneeR: [-34, 0, 0]});
const ROCKET = BOTH({RootJoint: [-18, 0, 0], Neck: [-6, 0, 0], Head: [-18, 0, 0], ArmL: [-50, 0, 0], LegL: [-22, 0, 0], KneeL: [-22, 0, 0], AnkleL: [-24, 0, 0], Tail1: [-18, 0, 0], Tail2: [-8, 0, 0]});
const STUMBLE = Object.assign(BOTH({RootJoint: [-8, 4, 6], Neck: [-10, -10, 0], Head: [6, -8, 0], ArmL: [20, 0, 0], Tail1: [6, 10, 0], root: {fwd: 0.8}}), {LegL: [30, 0, 0], KneeL: [-36, 0, 0], LegR: [-14, 0, 0]});
const HOPSTOP = BOTH({RootJoint: [6, 0, 0], Neck: [12, 0, 0], Head: [6, 0, 0], ArmL: [10, 0, 0], LegL: [20, 0, 0], KneeL: [-44, 0, 0], AnkleL: [20, 0, 0], Tail1: [6, 0, 0]});
// Dome Visor
const BRACE = Object.assign(BOTH({RootJoint: [-6, 0, 0], Neck: [-16, 0, 0], Head: [-22, 0, 0], ArmL: [36, 0, -10], Tail1: [8, 0, 0], Tail2: [4, 0, 0]}),
  {LegL: [22, 0, -6], KneeL: [-40, 0, 0], AnkleL: [18, 0, 0], LegR: [-10, 0, 6], KneeR: [-30, 0, 0], AnkleR: [10, 0, 0]});
const BRACE_HIT = addPose(BRACE, {RootJoint: [6, 0, 0], Neck: [10, 0, 0], Head: [8, 0, 0], root: {fwd: -1.2}}, 1);
const DOME_SHIELD = BOTH({RootJoint: [-10, 0, 0], Neck: [-22, 0, 0], Head: [-52, 0, 0], ArmL: [-30, 0, 0], LegL: [16, 0, 0], KneeL: [-30, 0, 0], AnkleL: [12, 0, 0], Tail1: [-4, 0, 0]});
const PLANT = Object.assign(BOTH({RootJoint: [-4, 0, 0], Neck: [-6, 0, 0], Head: [-10, 0, 0], ArmL: [-20, 0, 0], Tail1: [-6, 0, 0]}), {LegL: [26, 0, -10], KneeL: [-30, 0, 0], AnkleL: [14, 0, 0], LegR: [-22, 0, 10], KneeR: [-26, 0, 0]});
const PLANT_STOMP = addPose(PLANT, {LegL: [12, 0, 0], KneeL: [-16, 0, 0], RootJoint: [-3, 0, 0]}, 1);
const SHAKE_OFF = t => ({Neck: [0, 14 * Math.sin(t * 34) * Math.max(0, 1 - t / 0.45), 0], Head: [0, 10 * Math.sin(t * 34 + 0.6) * Math.max(0, 1 - t / 0.45), 6 * Math.sin(t * 34) * Math.max(0, 1 - t / 0.45)]});
// Ink Shooter (the tank sits on the pachy's shoulder; the shot leaves its muzzle)
const INK_TURN = Object.assign({RootJoint: [-2, -16, 0], Neck: [-4, 14, 0], Head: [-6, 6, 0], ArmL: [-20, 0, 0], ArmR: [-20, 0, 0], Tail1: [0, 12, 0]}, {LegL: [12, 0, 0], KneeL: [-24, 0, 0], LegR: [-10, 0, 0], KneeR: [-18, 0, 0]});
const INK_KICK = addPose(INK_TURN, {RootJoint: [6, 6, -8], Neck: [8, 0, 0], root: {fwd: -1}}, 1);
const PUMP_DIP = BOTH({RootJoint: [-4, 0, 0], Neck: [-14, 0, 0], Head: [-10, 0, 0], ArmL: [-24, 0, 0], KneeL: [-14, 0, 0]});
const SNAP_KICK = BOTH({RootJoint: [8, 0, 0], Neck: [10, 0, 0], Head: [6, 0, 0], root: {fwd: -1.4}});
// Tether Spike (launcher on Tail1)
const SLING_COCK = BOTH({RootJoint: [-8, 0, 0], Neck: [-6, 0, 0], Head: [-6, 0, 0], ArmL: [-20, 0, 0], Tail1: [-34, 0, 0], Tail2: [-26, 0, 0], Tail3: [-20, 0, 0], Tail4: [-14, 0, 0], Tail5: [-10, 0, 0], LegL: [10, 0, 0], KneeL: [-24, 0, 0], AnkleL: [10, 0, 0]});
const SLING_WHIP = BOTH({RootJoint: [4, 0, 0], Neck: [4, 0, 0], Head: [-2, 0, 0], ArmL: [-10, 0, 0], Tail1: [14, 0, 0], Tail2: [10, 0, 0], Tail3: [8, 0, 0], Tail4: [6, 0, 0], root: {fwd: 0.6}});
const SLING_FLICK = BOTH({Tail1: [-10, 12, 0], Tail2: [-6, 14, 0], Tail3: [-4, 16, 0]});
const MORTAR = BOTH({RootJoint: [10, 0, 0], Neck: [10, 0, 0], Head: [-6, 0, 0], ArmL: [-20, 0, 0], LegL: [34, 0, 0], KneeL: [-62, 0, 0], AnkleL: [26, 0, 0], Tail1: [26, 0, 0], Tail2: [10, 0, 0]});
const MORTAR_THUMP = addPose(MORTAR, {RootJoint: [-6, 0, 0], KneeL: [10, 0, 0], KneeR: [10, 0, 0], Tail1: [-8, 0, 0], root: {fwd: -0.6}}, 1);
// Blood Rush
const PACT = BOTH({RootJoint: [10, 0, 0], Neck: [32, 0, 0], Head: [24, 0, 0], Jaw: [-42, 0, 0], ArmL: [30, 0, -16], Tail1: [10, 0, 0], root: {fwd: -1}});
const PUMP = BOTH({RootJoint: [-6, 0, 0], Neck: [-10, 0, 0], Head: [-14, 0, 0], ArmL: [-30, 0, 0], KneeL: [-14, 0, 0]});
const SNORT = Object.assign(BOTH({RootJoint: [-6, 0, 0], Neck: [-10, 0, 0], Head: [-26, 0, 0], ArmL: [-24, 0, 0]}), {LegL: [26, 0, 0], KneeL: [-14, 0, 0], AnkleL: [6, 0, 0]});
// Med-Station
const LAY = BOTH({RootJoint: [-14, 0, 0], Neck: [-14, 0, 0], Head: [6, 0, 0], ArmL: [-20, 0, 0], LegL: [30, 0, 0], KneeL: [-54, 0, 0], AnkleL: [22, 0, 0], Tail1: [-22, 0, 0], Tail2: [-16, 0, 0], Tail3: [-10, 0, 0]});
const STOMP1 = Object.assign(BOTH({RootJoint: [4, 0, 0], Neck: [8, 0, 0], Head: [-4, 0, 0], ArmL: [-10, 0, 0]}), {LegL: [46, 0, 0], KneeL: [-70, 0, 0], AnkleL: [20, 0, 0]});
const STOMP2 = Object.assign(BOTH({RootJoint: [-6, 0, 0], Neck: [-10, 0, 0], Head: [-6, 0, 0], ArmL: [-20, 0, 0]}), {LegL: [28, 0, 0], KneeL: [-30, 0, 0], AnkleL: [8, 0, 0], LegR: [-6, 0, 0], KneeR: [-26, 0, 0]});
const TOSS_DIP = BOTH({RootJoint: [-10, 0, 0], Neck: [-30, 0, 0], Head: [-34, 0, 0], ArmL: [-20, 0, 0], KneeL: [-16, 0, 0]});
const TOSS_UP = BOTH({RootJoint: [8, 0, 0], Neck: [24, 0, 0], Head: [26, 0, 0], Jaw: [-6, 0, 0], ArmL: [10, 0, 0]});
// Last Stand / Head Down
const HURT = BOTH({RootJoint: [8, 0, 4], Neck: [14, -12, 0], Head: [8, -6, 0], Jaw: [-14, 0, 0], ArmL: [-20, 0, 0], root: {fwd: -1}});
const ROAR = BOTH({RootJoint: [10, 0, 0], Neck: [30, 0, 0], Head: [22, 0, 0], Jaw: [-46, 0, 0], ArmL: [30, 0, -20], Tail1: [-8, 0, 0], Tail2: [-6, 0, 0], LegL: [8, 0, 0], KneeL: [-20, 0, 0]});
const HEAVY = BOTH({RootJoint: [-4, 0, 0], Neck: [-8, 0, 0], Head: [-6, 0, 0], Jaw: [-8, 0, 0], ArmL: [-10, 0, 0], KneeL: [-14, 0, 0], LegL: [6, 0, 0]});
const K = (t, pose, e) => ({t, pose, e});
// a run cycle layered on top (the pachy's walk: legs swing, knees fold, a body bob), amt 0..1, ph radians
function gait(ph, amt, stride) { const s = Math.sin(ph), c = Math.cos(ph), A = (stride || 32) * amt;
  return {LegL: [A * s, 0, 0], LegR: [-A * s, 0, 0], KneeL: [-(16 + 34 * Math.max(0, c)) * amt, 0, 0], KneeR: [-(16 + 34 * Math.max(0, -c)) * amt, 0, 0],
    AnkleL: [10 * s * amt, 0, 0], AnkleR: [-10 * s * amt, 0, 0], RootJoint: [2 * Math.cos(2 * ph) * amt, 0, 0], Tail1: [0, 4 * s * amt, 0]}; }

// travel along -Z: list of [t, z] (z = studs forward, piecewise; eased by e)
function travelAt(list, t) { if (!list) return 0; if (t <= list[0][0]) return list[0][1];
  for (let i = 1; i < list.length; i++) if (t <= list[i][0]) { const a = list[i - 1], b = list[i], u = (t - a[0]) / (b[0] - a[0]); return a[1] + (b[1] - a[1]) * (E[b[2] || "lin"])(u); }
  return list[list.length - 1][1]; }
// jumps: [t0, vUp] launches; gravity G (studs/s^2). JumpLaunchPower 59 (x scale... the game's arc: ~0.6 s, ~9 studs at 196.2)
const G = 196.2;
function jumpUp(launches, t, landAt) { let y = 0, v = 0, last = -1;
  for (const [t0, v0] of launches) if (t >= t0) last = t0;
  if (last < 0) return {up: 0, air: false};
  // integrate from the first launch
  let tt = launches[0][0]; y = 0; v = launches[0][1]; let i = 1;
  const dt = 1 / 240;
  while (tt < t) { if (i < launches.length && tt >= launches[i][0]) { v = launches[i][1]; i++; } v -= G * dt; y += v * dt; tt += dt; if (y <= 0 && v < 0 && tt > launches[0][0] + 0.05) { y = 0; return {up: 0, air: false, landed: true}; } }
  return {up: Math.max(0, y), air: y > 0.01}; }

// target setups
const HB_DIST = 34, HB_STOP = 12; // the raptor stands 34 studs ahead (a full run-up: 25 damage); the pachy's root stops 12 short (its head meets the raptor's)
function setFront(d) { place(R0, 0, -(d || HB_DIST), 0); R0.yaw = Math.PI; R1.show = false; }
function setTwo() { place(R0, -4, -36, 0); R0.yaw = Math.PI - 0.3; place(R1, 10, -30, 0); R1.yaw = Math.PI + 0.5; }
const rapChestP = R => partPoint(R.rig.segs.Torso[0]);

// ---------- med-station pad (world object; MedStationServer builds it on the ground where the pachy drops it) ----------
const med = new THREE.Group(); scene.add(med); med.visible = false;
const medPieces = {};
function buildMed() {
  const D = PARTS_DATA.medstation; if (!D) return;
  for (const pc of D.pieces) {
    const sz = pc.size; let geo;
    if (pc.shape === "Cylinder") { geo = new THREE.CylinderGeometry(Math.min(sz[1], sz[2]) / 2, Math.min(sz[1], sz[2]) / 2, sz[0], 24); geo.rotateZ(Math.PI / 2); }
    else if (pc.shape === "Ball") geo = new THREE.SphereGeometry(Math.min(...sz) / 2, 16, 12); else geo = new THREE.BoxGeometry(sz[0], sz[1], sz[2]);
    const neon = /neon/i.test(pc.material || "");
    const m = new THREE.Mesh(geo, new THREE.MeshLambertMaterial({color: parseInt(pc.color, 16), emissive: neon ? parseInt(pc.color, 16) : 0, emissiveIntensity: 0.6, transparent: (pc.transp || 0) > 0, opacity: 1 - (pc.transp || 0)}));
    m.position.set(pc.pos[0], pc.pos[1], pc.pos[2]); m.rotation.set(rad((pc.rotDeg || [0, 0, 0])[0]), rad((pc.rotDeg || [0, 0, 0])[1]), rad((pc.rotDeg || [0, 0, 0])[2]));
    m.userData.y0 = m.position.y; m.castShadow = true; med.add(m); medPieces[pc.n] = m;
  }
}
// unfold u 0..1: pieces rise out of the base (higher pieces later)
function medState(at, unfold, scale) { med.visible = unfold > 0; med.position.copy(at); const s = Math.max(0.001, scale === undefined ? 1 : scale); med.scale.set(s, s, s);
  for (const n in medPieces) { const m = medPieces[n]; const edge = /^Edge/.test(n); const k = Math.min(1, Math.max(0, edge ? (unfold - 0.5) * 2 : unfold * 1.5));
    if (edge) { m.visible = k > 0; m.material.opacity = k; m.material.transparent = true; } else { m.scale.set(Math.max(0.05, E.out(Math.min(1, k))), Math.max(0.05, E.back(Math.min(1, k))), Math.max(0.05, E.back(Math.min(1, k)))); } } }
function healWave(at, r) { groundRing(at, r, 0x7dff9a, 0.9, 0.7); const s = sprite(T_FLASH, 0x7dff9a, 6, true); s.position.copy(at).setY(3); addFx(s, 0.5, (o, u) => { o.scale.setScalar(6 + u * 10); o.material.opacity = 0.6 * (1 - u); }); }

// ---------- projectiles (claw, ink glob, tether spike) ----------
function proj(mesh, from, toFn, T, arc, onHit, trail) { scene.add(mesh); const prev = from.clone();
  return addFx(mesh, T, (o, u, dt) => { const to = toFn(); const p = from.clone().lerp(to, u); p.y += 4 * (arc || 0) * u * (1 - u); const v = p.clone().sub(prev);
    o.position.copy(p); if (v.lengthSq() > 1e-6) o.lookAt(p.clone().add(v)); if (trail) trail(p, prev); prev.copy(p); if (u >= 1 && !o.userData.hit) { o.userData.hit = 1; onHit && onHit(p); } }); }
const chainMat = new THREE.MeshLambertMaterial({color: 0x3c4048});
function chainLine(fromFn, toFn, life, opts) { const g = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.22, 1, 6), opts && opts.mat || chainMat); g.geometry.translate(0, 0.5, 0); g.geometry.rotateX(Math.PI / 2);
  return addFx(g, life, (o, u) => { const a = fromFn(), b = toFn(); o.position.copy(a); o.lookAt(b); o.scale.set(1, 1, Math.max(0.01, a.distanceTo(b))); if (opts && opts.fade) o.material.opacity = 1 - u; }); }
const clawMesh = () => { const g = new THREE.Group(); const m = new THREE.MeshLambertMaterial({color: 0xb8c0cc}); const b = new THREE.Mesh(new THREE.BoxGeometry(1.4, 1.4, 2), m); g.add(b);
  for (const s of [-1, 1]) { const c = new THREE.Mesh(new THREE.BoxGeometry(0.35, 0.35, 1.8), m); c.position.set(s * 0.8, 0, -1.4); c.rotation.y = s * 0.4; g.add(c); } return g; };
const inkMesh = () => new THREE.Mesh(new THREE.IcosahedronGeometry(1.3, 1), new THREE.MeshLambertMaterial({color: 0x1a1426, emissive: 0x0a0812}));
const spikeMesh = () => { const g = new THREE.Group(); const m = new THREE.MeshLambertMaterial({color: 0x9aa6b8}); const s = new THREE.Mesh(new THREE.ConeGeometry(0.6, 3.2, 8), m); s.rotation.x = -Math.PI / 2; g.add(s);
  const y = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.5, 1.2), new THREE.MeshLambertMaterial({color: 0xffd23a, emissive: 0x6a4a00})); y.position.z = 1.6; g.add(y); return g; };

// ---------- the moves ----------
// Each version: name, sub, len, timing, ref, phases [[t0, t1, text]], notes, rec, build() -> track:
//   {keys, frame [p, p], parts [ids], travel [[t, z, e]], jumps [[t, v]], gait [t0, t1, rate, amt], ev [{t, f}], update(t, dt),
//    extra(target, t), tint(t) -> [r, g, b], pa(t) -> part anim state}
const VM = {};
const CHARGE_T = 0.15, HIT_T = 0.6; // wind-up 0.15 s (HeadbuttWindup); 30 studs at ~67 studs/s -> the hit at 0.6 s
function hbTravel(stop) { return [[0, 0], [CHARGE_T, 0], [HIT_T, HB_DIST - HB_STOP, "in2"], [HIT_T + 0.25, HB_DIST - HB_STOP - (stop || 0), "out"]]; }
function hbHitEv(stagger, extra) { return {t: HIT_T, f: () => { hitRaptor(R0, headOf(R0).add(new THREE.Vector3(0, -1, 2)), 25, {stagger, shove: 12, big: true, stop: 0.1, shake: 1.2}); extra && extra(); }}; }
VM.headbutt = {
  now: {name: "Now", sub: "as the game plays it (v479)", len: 2.0, timing: "wind-up 0.15 s, charge up to 1.8 s, impact 0.3 s",
    ref: "HeadbuttPose 1.0 (rear-up in the first 40% of the wind-up, then low; impact: the dome snaps up and shakes 0.3 s) + HeadbuttFX 1.2 (dust, two dome trails, flash, thud, number).",
    phases: [[0, 0.06, "Tiny rear-up"], [0.06, CHARGE_T, "Head drops"], [CHARGE_T, HIT_T, "Charges, head low, a small bob"], [HIT_T, HIT_T + 0.3, "Hit · 25 · the dome snaps up and shakes"], [HIT_T + 0.3, 2.0, "Eases back to idle"]],
    notes: ["The rear-up lasts 0.06 s: nobody sees it coming.", "The legs don't change for the charge (just the walk sped up), so it doesn't look like a charge.", "The hit raptor just slides 40 studs: no reaction."],
    build() { setFront(); return {frame: [new THREE.Vector3(0, 0, 0), R0.pos.clone()], travel: hbTravel(), gait: [CHARGE_T, HIT_T, 22, 0.8],
      keys: [K(0, READY), K(0.06, HB_REAR, "io"), K(CHARGE_T, HB_LOW, "io"), K(HIT_T, HB_LOW), K(HIT_T + 0.04, HB_HIT, "out"), K(HIT_T + 0.3, HB_HIT, "lin"), K(HIT_T + 0.6, READY, "io")],
      ev: [{t: CHARGE_T, f: () => { this._trail = true; }}, hbHitEv(false)],
      update(t, dt) { if (t > CHARGE_T && t < HIT_T && Math.random() < dt * 30) dust(pachy.pos.clone(), 1, 3, 2, 2); },
      extra(target, t) { if (t > CHARGE_T && t < HIT_T) target.Neck[0] += 2.5 * Math.sin(t * 2 * Math.PI * 4.5); if (t > HIT_T && t < HIT_T + 0.3) { const w = 9 * Math.sin(t * 2 * Math.PI * 10) * (1 - (t - HIT_T) / 0.3); target.Neck[1] += w * 0.5; target.Head[1] += w; } }}; }},
  A: {name: "A · Bull Charge", sub: "paw, snort, charge, crunch, shake it off", len: 2.2, rec: true, timing: "as now (wind-up 0.15 s)",
    ref: "A bull pawing and snorting before it charges; bighorn rams' head clash (the whole body drives through the head, then a dazed shake).",
    phases: [[0, CHARGE_T, "Snorts, scrapes a back foot, drops low"], [CHARGE_T, HIT_T, "Charges: head locked low, legs pounding"], [HIT_T, HIT_T + 0.12, "CRUNCH · 25 · the raptor staggers back"], [HIT_T + 0.12, HIT_T + 0.5, "Bounces off, rocks back"], [HIT_T + 0.5, 2.2, "Shakes it off, back to ready"]],
    notes: ["The paw + snort is the tell: other players read 'charge coming' in 0.15 s.", "The legs really run (long, fast strides) and dust kicks up.", "The raptor staggers instead of sliding (the new hit-react)."],
    build() { setFront(); return {frame: [new THREE.Vector3(0, 0, 0), R0.pos.clone()], travel: hbTravel(1.6), gait: [CHARGE_T, HIT_T, 26, 1],
      keys: [K(0, READY), K(0.1, PAW, "io"), K(CHARGE_T, BULL_LOW, "io"), K(HIT_T, BULL_LOW), K(HIT_T + 0.04, CRUNCH, "in2"), K(HIT_T + 0.16, RECOIL_UP, "out"), K(HIT_T + 0.5, addPose(READY, {Neck: [6, 0, 0]}, 1), "io"), K(HIT_T + 1.0, READY, "io")],
      ev: [{t: 0.03, f: () => puff(beakPoint(), new THREE.Vector3(0, -2, -6), 1.6, 0xffffff, 0.45)}, {t: 0.08, f: () => dust(partPoint(PP.footR), 5, 3, 3, 2.4)},
        {t: CHARGE_T, f: () => { dust(pachy.pos.clone(), 6, 4, 4, 3); }}, hbHitEv(true, () => sparks(domePoint(), new THREE.Vector3(0, 0.5, -1), 10))],
      update(t, dt) { if (t > CHARGE_T && t < HIT_T && Math.random() < dt * 50) dust(pachy.pos.clone().add(new THREE.Vector3(0, 0, 3)), 1, 3, 3, 2.6); },
      extra(target, t) { if (t > HIT_T + 0.5 && t < HIT_T + 0.95) { const s = SHAKE_OFF(t - HIT_T - 0.5); target.Neck[1] += s.Neck[1]; target.Head[1] += s.Head[1]; target.Head[2] += s.Head[2]; } }}; }},
  B: {name: "B · Ram Rear", sub: "rears up tall, slams down into the run", len: 2.2, timing: "as now (wind-up 0.15 s)",
    ref: "Mountain goats rearing on their hind legs before they crash heads.",
    phases: [[0, 0.1, "Rears up tall"], [0.1, CHARGE_T, "Slams down (a ground stamp)"], [CHARGE_T, HIT_T, "Charges"], [HIT_T, HIT_T + 0.4, "Hit · 25 · bounces back onto its tail"], [HIT_T + 0.4, 2.2, "Recovers"]],
    notes: ["The biggest, clearest tell; good from far away.", "A tall rear in 0.1 s is fast: it can look twitchy on a phone."],
    build() { setFront(); return {frame: [new THREE.Vector3(0, 0, 0), R0.pos.clone()], travel: hbTravel(2), gait: [CHARGE_T, HIT_T, 24, 0.9],
      keys: [K(0, READY), K(0.1, RAM_REAR, "out"), K(CHARGE_T, RAM_SLAM, "in2"), K(CHARGE_T + 0.1, HB_LOW, "io"), K(HIT_T, HB_LOW), K(HIT_T + 0.12, RAM_BOUNCE, "out"), K(HIT_T + 0.5, RAM_BOUNCE, "io"), K(HIT_T + 1.0, READY, "io")],
      ev: [{t: CHARGE_T, f: () => { dust(pachy.pos.clone(), 8, 6, 3, 3); groundRing(pachy.pos.clone(), 10, 0xe8d8b0, 0.4, 0.6); shake = Math.max(shake, 0.4); }}, hbHitEv(true)]}; }},
  C: {name: "C · Battering Lean", sub: "no rear: leans in deeper and deeper", len: 2.2, timing: "as now (wind-up 0.15 s)",
    ref: "A rugby tackle / a charging rhino: the body tips forward until it has to run.",
    phases: [[0, CHARGE_T, "Tips forward, tail up"], [CHARGE_T, HIT_T, "Charges flatter and flatter"], [HIT_T, HIT_T + 0.35, "Hit · 25 · bounces back, feet skidding"], [HIT_T + 0.35, 2.2, "Stands back up"]],
    notes: ["Reads as 'heavy and unstoppable'.", "The tell is a lean, not a pose change: weaker from the front."],
    build() { setFront(); return {frame: [new THREE.Vector3(0, 0, 0), R0.pos.clone()], travel: [[0, 0], [CHARGE_T, 0.6], [HIT_T, HB_DIST - HB_STOP, "in2"], [HIT_T + 0.3, HB_DIST - HB_STOP - 3.5, "out"]], gait: [CHARGE_T, HIT_T, 30, 1],
      keys: [K(0, READY), K(CHARGE_T, addPose(LEAN_LOW, {RootJoint: [6, 0, 0], Head: [10, 0, 0]}, 1), "io"), K(HIT_T, LEAN_LOW, "io"), K(HIT_T + 0.1, SKID, "out"), K(HIT_T + 0.4, SKID, "io"), K(HIT_T + 0.9, READY, "io")],
      ev: [hbHitEv(true, () => { for (let i = 0; i < 8; i++) setTimeout0(i * 0.03, () => dust(pachy.pos.clone(), 1, 2, 2, 2.4)); })]}; }},
};
let delayed = [];
function setTimeout0(d, f) { delayed.push({at: (play ? play.t : 0) + d, f}); }

// Leap + the Mecha Legs double jump (star). The game's arc: JumpLaunchPower 59 -> ~0.6 s, ~8.9 studs; the double jump at
// 80% of a leap's height (vertical speed x0.89), any time in the air.
const J_T0 = 0.12, V0 = 59, V2 = 59 * 0.89, DJ = 0.42;
function leapTrack(o) { R0.show = false; R1.show = false; return Object.assign({frame: [new THREE.Vector3(0, 0, 4), new THREE.Vector3(0, 0, -36)], parts: ["mechalegs"],
  jumps: [[J_T0, V0], [DJ, V2]], travel: [[0, 0], [J_T0, 0], [1.38, 30, "lin"]]}, o); }
function landT() { let t = J_T0 + 0.02; while (t < 3 && jumpUp([[J_T0, V0], [DJ, V2]], t).air) t += 1 / 240; return t; }
const LAND_T = landT();
function legFire(n, big) { for (const f of [PP.footL, PP.footR]) { const p = partPoint(f).add(new THREE.Vector3(0, 0.5, 1)); for (let i = 0; i < n; i++) puff(p, new THREE.Vector3((Math.random() - .5) * 4, -6 - Math.random() * 6, 6 + Math.random() * 6), big ? 2.4 : 1.8, 0xff9a3a, 0.35, T_SPARK); } }
VM.leap = {
  now: {name: "Now", sub: "as the game plays it (v479)", len: 2.3, timing: "crouch 0.12 s, ~0.6 s in the air; double jump any time in the air",
    ref: "JumpPose 1.0 (the biped leap: crouch, push, tuck, reach, squash 0.22 s) + MechaLegsFX 1.1 (heel fire + speed lines; the double jump: a bigger burst + a ring).",
    phases: [[0, J_T0, "Short crouch"], [J_T0, DJ, "Leaps, tucks"], [DJ, DJ + 0.1, "Double jump (Mecha Legs star): a fire burst, no change in the pose"], [DJ + 0.1, LAND_T, "Falls, reaches"], [LAND_T, 2.3, "Lands (squash 0.22 s)"]],
    notes: ["The crouch is 0.12 s and shallow.", "The double jump has no pose: the body just goes up again.", "The piston shins never move."],
    build() { return leapTrack({keys: [K(0, READY), K(J_T0, PJ_CROUCH, "io"), K(J_T0 + 0.06, PJ_PUSH, "out"), K(J_T0 + 0.21, PJ_AIR, "io"), K(DJ, PJ_AIR), K(LAND_T - 0.12, J_REACH, "io"), K(LAND_T + 0.05, PJ_LAND, "out"), K(LAND_T + 0.25, READY, "io")],
      ev: [{t: J_T0, f: () => legFire(6)}, {t: DJ, f: () => { legFire(10, true); groundRing(pachy.pos.clone().setY(pachy.y), 8, 0xffb070, 0.35, 0.6); }}]}); }},
  A: {name: "A · Coiled Spring", sub: "deep coil, pistons fire, ball, kick", len: 2.3, rec: true, timing: "as now",
    ref: "A kangaroo's coil-and-release; mech-game jump jets (Titanfall's double jump kick).",
    phases: [[0, J_T0, "Coils deep, dome tucked, pistons compress"], [J_T0, J_T0 + 0.08, "Pistons fire: a heel blast"], [J_T0 + 0.08, DJ, "Tucks into a ball"], [DJ, DJ + 0.12, "Double jump: legs kick down, pistons punch"], [DJ + 0.12, LAND_T, "Re-tucks, reaches"], [LAND_T, 2.3, "Lands soft, pistons absorb, vents steam"]],
    notes: ["The pistons sell the mecha legs: they compress, punch and absorb.", "The double jump gets its own kick, so you see it even without the fire.", "Same heights and timing."],
    build() { return leapTrack({keys: [K(0, READY), K(J_T0, J_COIL, "io"), K(J_T0 + 0.06, J_FIRE, "out5"), K(J_T0 + 0.22, J_BALL, "io"), K(DJ, J_BALL), K(DJ + 0.05, J_KICK, "out5"), K(DJ + 0.22, J_BALL, "io"), K(LAND_T - 0.12, J_REACH, "io"), K(LAND_T + 0.08, J_ABSORB, "out"), K(LAND_T + 0.4, READY, "io")],
      ev: [{t: J_T0, f: () => { legFire(10, true); dust(pachy.pos.clone(), 6, 4, 2, 2.6); }}, {t: DJ, f: () => { legFire(12, true); groundRing(pachy.pos.clone().setY(pachy.y), 9, 0xffb070, 0.35, 0.6); }},
        {t: LAND_T + 0.02, f: () => { for (const f of [PP.footL, PP.footR]) puff(partPoint(f).add(new THREE.Vector3(0, 2, 1)), new THREE.Vector3(0, 6, 2), 2, 0xffffff, 0.8); }}],
      pa(t) { const coil = t < J_T0 ? -E.io(t / J_T0) : t < J_T0 + 0.08 ? 1 : (t > DJ && t < DJ + 0.12) ? 1 : (t >= LAND_T && t < LAND_T + 0.25) ? -1 + (t - LAND_T) / 0.25 : 0;
        return {piston: coil, heat: (t > J_T0 && t < J_T0 + 0.4) || (t > DJ && t < DJ + 0.35) ? 1 : (t > LAND_T && t < LAND_T + 0.8 ? 0.5 : 0)}; }}); }},
  B: {name: "B · Dome Dive", sub: "flies dome-first, flips to land", len: 2.3, timing: "as now",
    ref: "A diving goat / a flying headbutt: the dome leads the whole arc.",
    phases: [[0, J_T0, "Crouches"], [J_T0, DJ, "Leaps nose-down, dome first"], [DJ, DJ + 0.15, "Double jump: a flip kick"], [DJ + 0.15, LAND_T, "Dives again"], [LAND_T, 2.3, "Lands, skids"]],
    notes: ["Looks aggressive: 'I'm coming at you'.", "Nose-down in the air hides the landing from the player camera."],
    build() { return leapTrack({keys: [K(0, READY), K(J_T0, PJ_CROUCH, "io"), K(J_T0 + 0.08, PJ_PUSH, "out"), K(J_T0 + 0.25, J_DIVE, "io"), K(DJ, J_DIVE), K(DJ + 0.08, J_FLIPKICK, "out5"), K(DJ + 0.28, J_DIVE, "io"), K(LAND_T - 0.1, J_REACH, "io"), K(LAND_T + 0.06, PJ_LAND, "out"), K(LAND_T + 0.4, READY, "io")],
      ev: [{t: J_T0, f: () => legFire(6)}, {t: DJ, f: () => legFire(10, true)}, {t: LAND_T, f: () => { for (let i = 0; i < 6; i++) setTimeout0(i * 0.04, () => dust(pachy.pos.clone(), 1, 2, 2, 2.4)); }}],
      pa(t) { return {piston: (t > DJ && t < DJ + 0.12) ? 1 : 0, heat: t > DJ && t < DJ + 0.35 ? 1 : 0}; }}); }},
  C: {name: "C · Stomp Landing", sub: "splayed hop, scissor kick, stomp", len: 2.3, timing: "as now",
    ref: "A sumo stomp; Mario's ground pound landing.",
    phases: [[0, J_T0, "Crouches"], [J_T0, DJ, "Hops, legs splayed"], [DJ, DJ + 0.15, "Double jump: a scissor kick"], [DJ + 0.15, LAND_T, "Falls"], [LAND_T, 2.3, "Lands with a stomp: dust ring + shake"]],
    notes: ["The stomp makes every landing feel heavy.", "The landing ring is landing FX: the house rule says no landing FX (it would need your OK)."],
    build() { return leapTrack({keys: [K(0, READY), K(J_T0, PJ_CROUCH, "io"), K(J_T0 + 0.08, PJ_PUSH, "out"), K(J_T0 + 0.24, J_SPLAY, "io"), K(DJ, J_SPLAY), K(DJ + 0.08, J_SCISSOR, "out5"), K(DJ + 0.26, PJ_AIR, "io"), K(LAND_T - 0.1, J_REACH, "io"), K(LAND_T + 0.05, J_STOMP, "out"), K(LAND_T + 0.45, READY, "io")],
      ev: [{t: J_T0, f: () => legFire(6)}, {t: DJ, f: () => legFire(10, true)}, {t: LAND_T, f: () => { dust(pachy.pos.clone(), 10, 8, 3, 3); groundRing(pachy.pos.clone(), 12, 0xe8d8b0, 0.45, 0.7); shake = Math.max(shake, 0.6); }}],
      pa(t) { return {piston: (t > DJ && t < DJ + 0.12) ? 1 : (t > LAND_T && t < LAND_T + 0.2 ? -1 : 0), heat: t > DJ && t < DJ + 0.35 ? 1 : 0}; }}); }},
};

// Grappling Hook: raise 0.15 s, the claw flies 220 studs/s, a 0.5 s pull to 1 body length in front, the smash (10, shove 30)
const HK = {L: 0.15, D: 30}; HK.C = HK.L + HK.D / 220; HK.S = HK.C + 0.5;
function hookTrack(o, style) {
  setFront(HK.D); const pullTo = -9;
  R0.path = [[0, new THREE.Vector3(0, 0, -HK.D), Math.PI, 0], [HK.C, new THREE.Vector3(0, 0, -HK.D), Math.PI, 0], [HK.S, new THREE.Vector3(0, 0, pullTo), Math.PI, 0]];
  const claw = {};
  return Object.assign({frame: [new THREE.Vector3(0, 0, 0), new THREE.Vector3(0, 0, -HK.D)], parts: ["hook"],
    ev: [{t: HK.L, f: () => { const from = PT.claw(); claw.out = true; flash(from, 3, 0xffffff);
        proj(clawMesh(), from, () => headOf(R0), HK.C - HK.L, 0, p => { flash(p, 5, 0xfff2a0); sparks(p, new THREE.Vector3(0, 0.3, 1), 6); claw.on = true; });
        chainLine(() => PT.claw(), () => claw.on ? headOf(R0) : (fx.find(e => e.obj.userData && e.obj.userData.claw) || {obj: {position: headOf(R0)}}).obj.position.clone(), HK.S - HK.L + 0.02); }},
      {t: HK.S, f: () => { claw.on = false; hitRaptor(R0, headOf(R0), 10, {stagger: style !== "now", shove: 6, big: false, stop: 0.08}); }}],
    pa(t) { return {hookOut: t >= HK.L && t < HK.S + 0.02, spool: (t > HK.C && t < HK.S) ? (t - HK.C) * 40 : 0}; }}, o);
}
VM.hook = {
  now: {name: "Now", sub: "as the game plays it (v479)", len: 2.0, timing: "raise 0.15 s, claw 220 studs/s, pull 0.5 s, smash 0.3 s",
    ref: "HookPose 1.2 (arm up 56° + the aim; hold; the smash dips the head 0.3 s) + HookFX 1.2 (claw on a chain, clamp flash, reel, smash flash + thud + number).",
    phases: [[0, HK.L, "Arm lifts"], [HK.L, HK.C, "Claw flies"], [HK.C, HK.S, "Reels in (nothing moves)"], [HK.S, HK.S + 0.3, "Smash · 10 · the head dips"], [HK.S + 0.3, 2.0, "Back to idle"]],
    notes: ["Nothing moves while it reels: no effort, no weight.", "The head only starts to dip as the raptor arrives, so the smash has no wind-up.", "The raptor just gets pushed away."],
    build() { return hookTrack({keys: [K(0, READY), K(HK.L, H_RAISE, "io"), K(HK.S, H_RAISE), K(HK.S + 0.08, H_DIP, "in2"), K(HK.S + 0.3, READY, "io")]}, "now"); }},
  A: {name: "A · Brace & Reel", sub: "brace, recoil, three tugs, cock the head, smash", len: 2.2, rec: true, timing: "as now",
    ref: "A fisherman setting the hook and reeling against a heavy fish; Scorpion's 'Get over here!' pull-in then a punch.",
    phases: [[0, HK.L, "Plants its feet wide, arm up"], [HK.L, HK.C, "Fires: the arm kicks, the body rocks"], [HK.C, HK.S - 0.12, "Reels: three hard tugs, the spool spins, it leans back"], [HK.S - 0.12, HK.S, "Cocks its head back"], [HK.S, HK.S + 0.25, "SMASH · 10 · the raptor staggers"], [HK.S + 0.25, 2.2, "Arm down, back to ready"]],
    notes: ["Every phase has a body motion, so the hook reads as heavy and strong.", "The head cocks just before the smash: you see it coming.", "Same timing."],
    build() { return hookTrack({keys: [K(0, READY), K(HK.L, H_BRACE, "io"), K(HK.L + 0.05, H_KICK, "out5"), K(HK.C, H_BRACE, "io"), K(HK.C + 0.08, H_REEL, "out"), K(HK.C + 0.16, H_BRACE, "io"), K(HK.C + 0.24, H_REEL, "out"), K(HK.C + 0.3, H_BRACE, "io"), K(HK.C + 0.36, H_REEL, "out"),
      K(HK.S - 0.12, H_COCK, "io"), K(HK.S, H_COCK), K(HK.S + 0.06, H_SMASH, "in2"), K(HK.S + 0.3, H_SMASH, "io"), K(HK.S + 0.7, READY, "io")]}, "A"); }},
  B: {name: "B · Overhead Cast", sub: "winds back, casts, yanks, uppercut", len: 2.2, timing: "as now",
    ref: "A fishing cast and a hard yank; a headbutt uppercut (Street Fighter's rising headbutt).",
    phases: [[0, 0.08, "Winds the arm back"], [0.08, HK.L, "Casts it forward"], [HK.L, HK.C, "Claw flies"], [HK.C, HK.S, "Yanks with its whole body"], [HK.S - 0.1, HK.S + 0.25, "Uppercut with the dome · 10"], [HK.S + 0.25, 2.2, "Settles"]],
    notes: ["The cast is very readable from the side.", "The wind-back points the arm away from the target for a moment."],
    build() { return hookTrack({keys: [K(0, READY), K(0.08, H_WINDBACK, "io"), K(HK.L, H_CAST, "out5"), K(HK.C, H_CAST), K(HK.C + 0.14, H_YANK, "out"), K(HK.S - 0.1, H_UPPER_LOW, "io"), K(HK.S + 0.06, H_UPPER, "out5"), K(HK.S + 0.3, H_UPPER, "io"), K(HK.S + 0.75, READY, "io")]}, "B"); }},
  C: {name: "C · Steady Aim", sub: "both arms aim, steady reel, quick smash", len: 2.0, timing: "as now",
    ref: "A harpoon gunner bracing the gun with both hands.",
    phases: [[0, HK.L, "Both arms up, sights down the arm"], [HK.L, HK.C, "Fires: a puff from the housing"], [HK.C, HK.S, "Reels steady: sparks off the spool"], [HK.S, HK.S + 0.25, "Quick smash · 10"], [HK.S + 0.25, 2.0, "Back to idle"]],
    notes: ["Calm and precise; less effort than A.", "The second arm is on the far side: hard to see from the player camera."],
    build() { const tr = hookTrack({keys: [K(0, READY), K(HK.L, H_SIGHT, "io"), K(HK.S - 0.05, H_SIGHT), K(HK.S + 0.05, H_SMASH, "in2"), K(HK.S + 0.25, H_SMASH, "io"), K(HK.S + 0.6, READY, "io")]}, "C");
      tr.update = (t, dt) => { if (t > HK.C && t < HK.S && Math.random() < dt * 30) sparks(PT.spool(), new THREE.Vector3(0, 0.5, 0.5), 1, 0xfff4c8, 0.4); };
      tr.ev.push({t: HK.L, f: () => puff(PT.hookHousing(), new THREE.Vector3(0, 2, 4), 1.6, 0xdddddd, 0.5)}); return tr; }},
};

// Overclocked Servo Dash: the thrusters shove 22 studs over 0.25 s, then 2x top speed (you steer) for 1 s
const SD = {S: 0.25, RUN: 1.25};
function dashTrack(o, delay) { R0.show = false; R1.show = false; const d = delay || 0;
  return Object.assign({frame: [new THREE.Vector3(0, 0, 0), new THREE.Vector3(0, 0, -60)], parts: ["servodash"],
    travel: [[0, 0], [d, 0], [d + SD.S, 22, "out"], [d + SD.RUN, 22 + 34, "lin"], [d + SD.RUN + 0.3, 22 + 34 + 4, "out"]],
    update(t, dt) { if (t > d && t < d + SD.RUN) { if (Math.random() < dt * 40) puff(PT.bell().add(new THREE.Vector3(0, 0, 2)), new THREE.Vector3(0, 1, 12), 1.6, 0xff9a3a, 0.25, T_SPARK); if (Math.random() < dt * 20) dust(pachy.pos.clone().add(new THREE.Vector3(0, 0, 3)), 1, 3, 2, 2.2); } }}, o); }
function dashBlast(at) { return {t: at, f: () => { const p = PT.bell(); flash(p, 8, 0xffb060); groundRing(pachy.pos.clone(), 10, 0xffc080, 0.35, 0.6); dust(pachy.pos.clone(), 8, 6, 3, 3); fovPunch = 6; shake = Math.max(shake, 0.5); streaks(pachy.pos.clone(), new THREE.Vector3(0, 0, -1), 12); }}; }
VM.servodash = {
  now: {name: "Now", sub: "as the game plays it (v479)", len: 2.2, timing: "blast at the press, 22 studs in 0.25 s, then 2x speed for 1 s",
    ref: "ServoDashServer 1.1 (flames, light, a ground ring, dust) + ServoDashLaunch 1.1 (FOV +20, shake, streaks; your screen only). No pose.",
    phases: [[0, SD.S, "Blast: shoved 22 studs (the body doesn't move)"], [SD.S, SD.RUN, "Runs 2x speed, flames on"], [SD.RUN, 2.2, "Flames off, normal speed"]],
    notes: ["No wind-up and no lean: the pachy slides like it's on ice.", "The end just stops: no braking."],
    build() { return dashTrack({keys: [K(0, READY)], gait: [SD.S, SD.RUN + 0.2, 26, 0.8], ev: [dashBlast(0)], pa(t) { return {glow: t < SD.RUN ? 1 : 0}; }}); }},
  A: {name: "A · Thruster Kick", sub: "squat, blast out low, skid to a stop", len: 2.4, rec: true, timing: "+0.06 s before the blast (the squat)",
    ref: "A sprinter in the blocks; Overwatch's Tracer-style blink lean; a car's nose dipping under braking.",
    phases: [[0, 0.06, "Squats, the hip bells glow"], [0.06, 0.06 + SD.S, "BLAST: shoots out low and flat"], [0.06 + SD.S, 0.06 + SD.RUN, "Sprints leaning in"], [0.06 + SD.RUN, 0.06 + SD.RUN + 0.35, "Skids to a stop, steam from the bells"], [0.06 + SD.RUN + 0.35, 2.4, "Back to ready"]],
    notes: ["The squat says 'something is about to fire'; the low flat body sells the speed.", "Costs 0.06 s at the start.", "The skid is the recovery: you see the dash end."],
    build() { const d = 0.06; return dashTrack({keys: [K(0, READY), K(d, SQUAT, "io"), K(d + 0.06, BLAST, "out5"), K(d + SD.S, BLAST), K(d + SD.S + 0.12, DASH_RUN, "io"), K(d + SD.RUN, DASH_RUN), K(d + SD.RUN + 0.12, BRAKE, "out"), K(d + SD.RUN + 0.35, BRAKE, "io"), K(d + SD.RUN + 0.8, READY, "io")],
      gait: [d + SD.S, d + SD.RUN, 30, 1], ev: [dashBlast(d), {t: d + SD.RUN, f: () => { for (let i = 0; i < 8; i++) setTimeout0(i * 0.04, () => dust(pachy.pos.clone(), 1, 2, 2, 2.4)); }},
        {t: d + SD.RUN + 0.1, f: () => { for (let i = 0; i < 4; i++) puff(PT.bell(), new THREE.Vector3(0, 6, 2), 1.8, 0xffffff, 0.9); }}],
      pa(t) { return {glow: t < d ? t / d : t < d + SD.RUN ? 1 : 0}; }}, d); }},
  B: {name: "B · Rocket Lean", sub: "the bells swivel back, it rides the blast", len: 2.4, timing: "as now",
    ref: "A rocket-skate / jet-pack lean (Sonic-style 'peel out' body angle).",
    phases: [[0, SD.S, "The bells swivel back; it rides the blast, legs trailing"], [SD.S, SD.RUN, "Runs 2x, still leaning"], [SD.RUN, SD.RUN + 0.35, "Bells swing back, a stumble step"], [SD.RUN + 0.35, 2.4, "Recovers"]],
    notes: ["Shows the thrusters are doing the work.", "No wind-up: the timing stays the same."],
    build() { return dashTrack({keys: [K(0, READY), K(0.05, ROCKET, "out5"), K(SD.S, ROCKET), K(SD.S + 0.1, DASH_RUN, "io"), K(SD.RUN, DASH_RUN), K(SD.RUN + 0.15, STUMBLE, "out"), K(SD.RUN + 0.6, READY, "io")],
      gait: [SD.S, SD.RUN, 28, 1], ev: [dashBlast(0)], pa(t) { return {glow: t < SD.RUN ? 1 : 0, swivel: t < SD.RUN ? -50 * E.out(Math.min(1, t / 0.06)) : -50 * (1 - Math.min(1, (t - SD.RUN) / 0.2))}; }}); }},
  C: {name: "C · Sprinter", sub: "blast, then arms pump hard, hop-stop", len: 2.4, timing: "as now",
    ref: "An Olympic 100 m sprint start + finish.",
    phases: [[0, SD.S, "Blast"], [SD.S, SD.RUN, "Sprints: arms pump, head bobs"], [SD.RUN, SD.RUN + 0.3, "Hops to a stop on both feet"], [SD.RUN + 0.3, 2.4, "Back to ready"]],
    notes: ["The legs and arms make the speed obvious.", "Still slides for the first 0.25 s (no pose for the blast)."],
    build() { return dashTrack({keys: [K(0, READY), K(SD.S, DASH_RUN, "io"), K(SD.RUN, DASH_RUN), K(SD.RUN + 0.12, HOPSTOP, "out"), K(SD.RUN + 0.55, READY, "io")], gait: [SD.S, SD.RUN, 32, 1], ev: [dashBlast(0)],
      extra(target, t) { if (t > SD.S && t < SD.RUN) { const a = 40 * Math.sin(t * 34); target.ArmL[0] += a; target.ArmR[0] -= a; target.Neck[0] += 4 * Math.sin(t * 68); } },
      pa(t) { return {glow: t < SD.RUN ? 1 : 0}; }}); }},
};

// Dome Visor: the goggles project a field (9 panels on a ±60° arc) for 1.5 s; panels fade in 0.1 s, out 0.2 s
const VIS = {ON: 0.1, END: 1.6, BITE: 0.7};
function visorTrack(o) { place(R0, 0, -11, 0); R0.yaw = Math.PI; R1.show = false;
  R0.path = [[0, new THREE.Vector3(0, 0, -30), Math.PI, 1], [VIS.BITE - 0.25, new THREE.Vector3(0, 0, -19), Math.PI, 1], [VIS.BITE, new THREE.Vector3(0, 0, -19), Math.PI, 0]];
  return Object.assign({frame: [new THREE.Vector3(0, 0, 0), new THREE.Vector3(0, 0, -18)], parts: ["visor"]}, o); }
function biteBlocked(p, kb) { return {t: VIS.BITE, f: () => { R0.lunge = 1; setTimeout0(0.12, () => { const q = p(); flash(q, 7, 0x7fe9ff); sparks(q, new THREE.Vector3(0, 0.4, -1), 10, 0xc8f6ff); tag(q, "BLOCK", "#7fe9ff", 0.9); hitStop = 0.06; shake = Math.max(shake, 0.5); if (kb) { R0.pushDir.set(0, 0, -1); R0.shove = 10; R0.shoveT = 0; R0.shoveTime = 0.35; R0.flinch = 1; } }); }}; }
const fieldPoint = () => pachy.pos.clone().add(new THREE.Vector3(0, 6, -13));
VM.visor = {
  now: {name: "Now", sub: "as the game plays it (v479)", len: 2.2, timing: "field on at the press, 1.5 s",
    ref: "VisorServer 1.1 (goggles always worn; 9 cyan panels on a ±60° arc fade in 0.1 s / out 0.2 s) + BoneCrest 1.5 (BLOCK sparks).",
    phases: [[0, VIS.ON, "The field fades in"], [VIS.ON, VIS.BITE + 0.1, "Stands as normal"], [VIS.BITE + 0.1, VIS.BITE + 0.4, "Bite blocked: sparks + BLOCK"], [VIS.BITE + 0.4, VIS.END, "Field up"], [VIS.END, 2.2, "Fades out"]],
    notes: ["The body does nothing: it looks like a screen effect, not the pachy blocking.", "No wind-up and no end motion."],
    build() { return visorTrack({keys: [K(0, READY)], ev: [biteBlocked(fieldPoint)], field(t) { return t < VIS.ON ? t / VIS.ON : t < VIS.END ? 1 : Math.max(0, 1 - (t - VIS.END) / 0.2); }}); }},
  A: {name: "A · Turtle Brace", sub: "tucks the dome, guards, panels slam in", len: 2.4, rec: true, timing: "as now (the field still comes up in 0.1 s)",
    ref: "A boxer's high guard; Halo's bubble-shield deploy; Reinhardt raising his barrier.",
    phases: [[0, VIS.ON, "Tucks the dome, arms up, lenses flash; panels slam in from the middle out"], [VIS.ON, VIS.BITE + 0.1, "Holds the brace"], [VIS.BITE + 0.1, VIS.BITE + 0.4, "Bite blocked: slides back a step, panels ripple"], [VIS.BITE + 0.4, VIS.END, "Braced"], [VIS.END, 2.4, "Panels fold away from the edges, a head shake"]],
    notes: ["The body tells you it's blocking, from any angle.", "The slide-back makes a block feel like a hit you absorbed.", "Same timing."],
    build() { return visorTrack({keys: [K(0, READY), K(VIS.ON, BRACE, "out5"), K(VIS.BITE + 0.12, BRACE), K(VIS.BITE + 0.18, BRACE_HIT, "out"), K(VIS.BITE + 0.4, BRACE, "io"), K(VIS.END, BRACE), K(VIS.END + 0.25, READY, "io")],
      ev: [biteBlocked(fieldPoint), {t: 0, f: () => flash(PT.lens(), 4, 0x7fe9ff)}], fieldMode: "seq",
      field(t) { return t < VIS.ON ? t / VIS.ON : t < VIS.END ? 1 : Math.max(0, 1 - (t - VIS.END) / 0.25); },
      extra(target, t) { if (t > VIS.END + 0.1 && t < VIS.END + 0.6) { const s = SHAKE_OFF(t - VIS.END - 0.1); target.Neck[1] += s.Neck[1] * 0.6; target.Head[1] += s.Head[1] * 0.6; } },
      pa(t) { return {lens: t < VIS.END ? (t < 0.15 ? 2 : 0.8) : 0, ripple: t > VIS.BITE + 0.1 && t < VIS.BITE + 0.4 ? 1 : 0}; }}); }},
  B: {name: "B · Dome Forward", sub: "the dome lowers and the field grows out of it", len: 2.4, timing: "as now",
    ref: "A riot shield; a pachy's dome as a battering shield.",
    phases: [[0, VIS.ON, "Lowers the dome like a shield; the field grows from it"], [VIS.ON, VIS.BITE + 0.1, "Holds"], [VIS.BITE + 0.1, VIS.BITE + 0.4, "Bite blocked: a shock ring off the dome"], [VIS.BITE + 0.4, VIS.END, "Holds"], [VIS.END, 2.4, "Lifts the head"]],
    notes: ["Ties the field to the dome (the pachy's identity).", "Head down means the pachy looks at the ground."],
    build() { return visorTrack({keys: [K(0, READY), K(VIS.ON, DOME_SHIELD, "out5"), K(VIS.END, DOME_SHIELD), K(VIS.END + 0.3, READY, "io")], fieldMode: "grow",
      ev: [biteBlocked(fieldPoint), {t: VIS.BITE + 0.12, f: () => { const s = sprite(T_FLASH, 0x7fe9ff, 6, true); s.position.copy(domePoint()); addFx(s, 0.4, (o, u) => { o.scale.setScalar(6 + u * 16); o.material.opacity = 0.8 * (1 - u); }); }}],
      field(t) { return t < VIS.ON ? E.out(t / VIS.ON) : t < VIS.END ? 1 : Math.max(0, 1 - (t - VIS.END) / 0.2); }, pa(t) { return {lens: t < VIS.END ? 0.8 : 0}; }}); }},
  C: {name: "C · Plant Feet", sub: "a wide stomp, the attacker bounces off", len: 2.4, timing: "as now",
    ref: "A sumo's shiko stomp before the clash.",
    phases: [[0, VIS.ON, "Stomps into a wide stance (dust)"], [VIS.ON, VIS.BITE + 0.1, "Planted"], [VIS.BITE + 0.1, VIS.BITE + 0.45, "Bite blocked: the pachy doesn't budge, the raptor bounces off"], [VIS.BITE + 0.45, VIS.END, "Planted"], [VIS.END, 2.4, "Stands up"]],
    notes: ["Feels immovable.", "The bounce matches the star (knockback) only: at I–III the raptor shouldn't fly back."],
    build() { return visorTrack({keys: [K(0, READY), K(0.06, PLANT_STOMP, "out5"), K(VIS.ON + 0.1, PLANT, "io"), K(VIS.END, PLANT), K(VIS.END + 0.3, READY, "io")],
      ev: [biteBlocked(fieldPoint, true), {t: 0.06, f: () => { dust(pachy.pos.clone(), 8, 7, 2, 2.8); shake = Math.max(shake, 0.3); }}],
      field(t) { return t < VIS.ON ? t / VIS.ON : t < VIS.END ? 1 : Math.max(0, 1 - (t - VIS.END) / 0.2); }, pa(t) { return {lens: t < VIS.END ? 0.8 : 0}; }}); }},
};

// Ink Shooter: the glob leaves the shoulder muzzle at 160 studs/s; the first dino hit is blinded 2 s
const INK_D = 36;
function inkTrack(o, delay) { setFront(INK_D); R0.pos.x = -6; R0.yaw = Math.PI - 0.15; const d = delay || 0;
  return Object.assign({frame: [new THREE.Vector3(0, 0, 0), R0.pos.clone()], parts: ["ink"], camSide: -1,
    ev: [{t: d, f: () => { const from = PT.muzzle(); flash(from, 4, 0x8a7aff);
      proj(inkMesh(), from, () => headOf(R0), INK_D / 160, 0.3, p => { flash(p, 7, 0x6a5aff); for (let i = 0; i < 14; i++) puff(p, new THREE.Vector3((Math.random() - .5) * 20, Math.random() * 10, (Math.random() - .5) * 20), 1.4, 0x1a1426, 0.6, T_INK);
          R0.flinch = 1; R0.ink = 2; tag(p, "BLINDED", "#c9b8ff", 1.6); }, (p, prev) => { if (Math.random() < 0.6) puff(p, new THREE.Vector3(0, -2, 0), 0.9, 0x1a1426, 0.35, T_INK); }); }}]}, o); }
VM.ink = {
  now: {name: "Now", sub: "as the game plays it (v479)", len: 2.0, timing: "glob at the press, 160 studs/s",
    ref: "InkServer 1.6 (glob from the shoulder muzzle, splat, drips, BLINDED tag) + InkBlind 1.0 (the victim's screen).",
    phases: [[0, INK_D / 160, "Glob flies (no body motion)"], [INK_D / 160, 2.0, "Splat · BLINDED 2 s"]],
    notes: ["The shot comes out of a still body: no aim, no kick.", "Hard to tell who fired it."],
    build() { return inkTrack({keys: [K(0, READY)]}); }},
  A: {name: "A · Shoulder Cannon", sub: "turns the shoulder in, pump, kick", len: 2.2, rec: true, timing: "+0.1 s before the shot",
    ref: "A tank turret turning, then the recoil; Splatoon's ink splat sounds/looks.",
    phases: [[0, 0.1, "Turns the shoulder at the target, the tank pumps"], [0.1, 0.12, "FIRE: muzzle flash, black smoke ring"], [0.12, 0.35, "Recoil rocks the body"], [0.1 + INK_D / 160, 2.2, "Splat · BLINDED · untwists"]],
    notes: ["You can see who fired and where it's going.", "Costs 0.1 s before the shot."],
    build() { const d = 0.1; const tr = inkTrack({keys: [K(0, READY), K(d, INK_TURN, "io"), K(d + 0.03, INK_KICK, "out5"), K(d + 0.3, INK_TURN, "io"), K(d + 0.8, READY, "io")],
      pa(t) { return {pump: t < d ? 0.18 * Math.sin(Math.PI * t / d) : 0, kick: (t > d && t < d + 0.15) ? 0.6 * (1 - (t - d) / 0.15) : 0}; }}, d);
      tr.ev.push({t: d, f: () => { const p = PT.muzzle(); const s = new THREE.Mesh(new THREE.TorusGeometry(1, 0.3, 6, 18), new THREE.MeshBasicMaterial({color: 0x222228, transparent: true})); s.position.copy(p); s.lookAt(headOf(R0)); addFx(s, 0.5, (o, u, dt) => { o.scale.setScalar(1 + u * 3); o.material.opacity = 0.8 * (1 - u); o.translateZ(dt * 8); }); shake = Math.max(shake, 0.4); }}); return tr; }},
  B: {name: "B · Pump Action", sub: "two pumps, then the shot", len: 2.2, timing: "+0.12 s before the shot",
    ref: "A pump shotgun; a squid squeezing ink.",
    phases: [[0, 0.12, "The tank pumps twice, the pachy dips"], [0.12, 0.12 + INK_D / 160, "Fires"], [0.12 + INK_D / 160, 2.2, "Splat · BLINDED · ink drips from the muzzle"]],
    notes: ["The pumps read well from far away.", "Costs 0.12 s; the pumping looks the same as the Blood Rush heart pump (C)."],
    build() { const d = 0.12; const tr = inkTrack({keys: [K(0, READY), K(0.06, PUMP_DIP, "io"), K(d, PUMP_DIP), K(d + 0.06, SNAP_KICK, "out"), K(d + 0.5, READY, "io")], pa(t) { return {pump: t < d ? 0.16 * Math.abs(Math.sin(Math.PI * t / 0.06)) : 0}; },
      update(t, dt) { if (t > d && t < d + 1.2 && Math.random() < dt * 8) puff(PT.muzzle(), new THREE.Vector3(0, -6, 0), 0.7, 0x1a1426, 0.6, T_INK); }}, d); return tr; }},
  C: {name: "C · Quick Draw", sub: "fires at once with a hard kick", len: 2.0, timing: "as now",
    ref: "A snap shot: no aim, all recoil.",
    phases: [[0, 0.03, "FIRE (at the press)"], [0.03, 0.3, "Kick: the body jolts back"], [INK_D / 160, 2.0, "Splat · BLINDED"]],
    notes: ["Keeps the instant shot.", "No wind-up, so other players still can't see it coming."],
    build() { return inkTrack({keys: [K(0, READY), K(0.04, SNAP_KICK, "out5"), K(0.45, READY, "io")], pa(t) { return {kick: t < 0.15 ? 0.6 * (1 - t / 0.15) : 0}; }}); }},
};

// Tether Spike: hold to aim (your screen only), release lobs a spike in 0.8 s (22 studs up); the dino in the 8-stud circle is
// chained 2.5 s within 10 studs of the spike; the spike sinks 0.3 s at the end
const TS = {REL: 0.5, FLY: 0.8, CHAIN: 2.5};
function tetherTrack(o) { setFront(34); R0.pos.x = 4; R0.path = [[0, new THREE.Vector3(4, 0, -34), Math.PI + 0.6, 0.6], [TS.REL + TS.FLY, new THREE.Vector3(9, 0, -40), Math.PI + 0.6, 0.6], [TS.REL + TS.FLY + 0.4, new THREE.Vector3(12, 0, -44), Math.PI + 0.9, 0.5], [TS.REL + TS.FLY + 0.8, new THREE.Vector3(10, 0, -43), Math.PI + 2.4, 0.2]];
  const spikeAt = new THREE.Vector3(4, 0, -36); const st = {};
  const sharedEv = () => [{t: TS.REL, f: () => { const from = PT.tetherTip(); flash(from, 4, 0xffd23a); st.out = true;
        proj(spikeMesh(), from, () => spikeAt.clone().setY(1.6), TS.FLY, 22, p => { dust(p.clone().setY(0.5), 8, 5, 3, 2.6); groundRing(spikeAt, 8, 0xffd23a, 0.3, 0.8); st.landed = true;
          const sp = spikeMesh(); sp.rotation.x = -Math.PI / 2; sp.position.copy(spikeAt).setY(1.4); addFx(sp, TS.CHAIN + 0.3, (oo, u) => { const tt = u * (TS.CHAIN + 0.3); oo.position.y = tt > TS.CHAIN ? 1.4 - (tt - TS.CHAIN) / 0.3 * 3 : 1.4; });
          chainLine(() => spikeAt.clone().setY(1), () => rapChestP(R0), TS.CHAIN); tag(rapChestP(R0), "CHAINED", "#ffd23a", 1.2); R0.flinch = 1; },
          (p, prev) => { if (Math.random() < 0.7) { const s = sprite(T_SPARK, 0xffd23a, 1.2, true); s.position.copy(p); addFx(s, 0.25, (oo, u) => { oo.material.opacity = 1 - u; }); } }); }}];
  return Object.assign({frame: [new THREE.Vector3(0, 0, 0), new THREE.Vector3(4, 0, -36)], parts: ["tether"], len: 4,
    aimRing: [0, TS.REL], aimAt: spikeAt, pa(t) { return {tipGone: t >= TS.REL && t < TS.REL + TS.FLY + TS.CHAIN}; }}, o, {ev: [].concat(sharedEv(), o.ev || [])}); }
VM.tether = {
  now: {name: "Now", sub: "as the game plays it (v479)", len: 4.0, timing: "aim while held, lob 0.8 s on release",
    ref: "TetherServer 1.3 (the spike lobs from the tail launcher, dust + a yellow ring, a chain, sinks 0.3 s) + MechaButtons 1.22 (top-down aim, your screen only).",
    phases: [[0, TS.REL, "Aims (only you see the circle; the body does nothing)"], [TS.REL, TS.REL + TS.FLY, "Spike lobs (no body motion)"], [TS.REL + TS.FLY, TS.REL + TS.FLY + TS.CHAIN, "Lands · CHAINED 2.5 s"], [TS.REL + TS.FLY + TS.CHAIN, 4.0, "Spike sinks"]],
    notes: ["Nothing on the body moves: other players see a spike come from nowhere.", "The launcher tip stays put while the spike flies."],
    build() { return tetherTrack({keys: [K(0, READY)], pa(t) { return {}; }}); }},
  A: {name: "A · Tail Sling", sub: "the tail cocks over the back, whips, flicks the chain", len: 4.0, rec: true, timing: "as now; others see the aim (one more message per aim)",
    ref: "A scorpion's tail; a trebuchet's arm; a sling.",
    phases: [[0, TS.REL, "Aiming: the tail cocks up over the back (others see it too)"], [TS.REL, TS.REL + 0.12, "Whips the tail: the spike flies, the launcher kicks"], [TS.REL + 0.12, TS.REL + TS.FLY, "Spike lobs"], [TS.REL + TS.FLY, TS.REL + TS.FLY + 0.4, "Lands · CHAINED · the tail flicks to pull the chain tight"], [TS.REL + TS.FLY + 0.4, 4.0, "Tail back down"]],
    notes: ["The cocked tail is a clear 'incoming' warning for the victim.", "Others only see the aim if the server tells them (a new 'aiming' stamp)."],
    build() { return tetherTrack({keys: [K(0, READY), K(0.25, SLING_COCK, "io"), K(TS.REL, SLING_COCK), K(TS.REL + 0.08, SLING_WHIP, "out5"), K(TS.REL + 0.4, READY, "io"), K(TS.REL + TS.FLY, READY), K(TS.REL + TS.FLY + 0.1, SLING_FLICK, "out"), K(TS.REL + TS.FLY + 0.5, READY, "io")],
      pa(t) { return {tipGone: t >= TS.REL && t < TS.REL + TS.FLY + TS.CHAIN, recoil: t > TS.REL && t < TS.REL + 0.15 ? 0.6 * (1 - (t - TS.REL) / 0.15) : 0}; }}); }},
  B: {name: "B · Mortar Squat", sub: "squats, the launcher thumps", len: 4.0, timing: "as now",
    ref: "A mortar crew; a heavy artillery 'thump'.",
    phases: [[0, TS.REL, "Squats, tail pressed down, launcher points up"], [TS.REL, TS.REL + 0.15, "THUMP: a hop, smoke from the launcher"], [TS.REL + 0.15, TS.REL + TS.FLY, "Spike lobs"], [TS.REL + TS.FLY, 4.0, "Lands · CHAINED · stands up"]],
    notes: ["Heavy and weapon-like.", "A long squat while aiming: you look stuck."],
    build() { return tetherTrack({keys: [K(0, READY), K(0.25, MORTAR, "io"), K(TS.REL, MORTAR), K(TS.REL + 0.05, MORTAR_THUMP, "out5"), K(TS.REL + 0.2, MORTAR, "io"), K(TS.REL + 0.7, READY, "io")],
      ev: [{t: TS.REL, f: () => { puff(PT.tetherTip(), new THREE.Vector3(0, 6, 3), 2.6, 0xbbbbbb, 0.9); shake = Math.max(shake, 0.4); }}],
      pa(t) { return {tipGone: t >= TS.REL && t < TS.REL + TS.FLY + TS.CHAIN, recoil: t > TS.REL && t < TS.REL + 0.15 ? 0.8 * (1 - (t - TS.REL) / 0.15) : 0}; }}); }},
  C: {name: "C · Quick Lob", sub: "a tail flick at the release only", len: 4.0, timing: "as now",
    ref: "A flick of the wrist.",
    phases: [[0, TS.REL, "Aims (no body motion)"], [TS.REL, TS.REL + 0.15, "A tail flick throws the spike"], [TS.REL + 0.15, 4.0, "Lob · lands · CHAINED"]],
    notes: ["Light touch; keeps the aim private.", "Small: easy to miss from the player camera."],
    build() { return tetherTrack({keys: [K(0, READY), K(TS.REL, READY), K(TS.REL + 0.06, BOTH({Tail1: [-18, 0, 0], Tail2: [-10, 0, 0]}), "out5"), K(TS.REL + 0.3, READY, "io")],
      pa(t) { return {tipGone: t >= TS.REL && t < TS.REL + TS.FLY + TS.CHAIN}; }}); }},
};

// Blood Rush: out of charges, ATTACK pays 25% of max health for one more headbutt (a red flash, the cost, the vials drain)
function bloodTrack(o) { const tr = VM.headbutt.A.build(); tr.parts = ["bloodvial"]; tr.ev = tr.ev.filter(e => e.t >= HIT_T - 0.01);
  tr.ev.push({t: 0.02, f: () => { tag(pachy.pos.clone().add(new THREE.Vector3(0, 14, 0)), "-17 HP", "#ff5a5a", 0.9); }});
  return Object.assign(tr, o); }
function bloodSpray() { for (let i = 0; i < 10; i++) { const p = PT.nozzle(); const s = sprite(T_DROP, 0xd0202a, 1, false); s.position.copy(p);
  const v = new THREE.Vector3((Math.random() - .5) * 10, 6 + Math.random() * 8, (Math.random() - .5) * 10); addFx(s, 0.45, (o, u, dt) => { v.y -= 50 * dt; o.position.addScaledVector(v, dt); o.material.opacity = 1 - u; }); } }
const redTint = (a, b) => t => (t >= a && t < b) ? [0.35 * (1 - (t - a) / (b - a)), 0, 0] : null;
VM.bloodrush = {
  now: {name: "Now", sub: "as the game plays it (v479)", len: 2.2, timing: "as a headbutt (wind-up 0.15 s)",
    ref: "HeadbuttFX 1.1 sacrifice: red Highlight 0.35 s, the cost number, red dust; BloodVialServer 1.1: the vials drain 0.3 s and spray 0.45 s.",
    phases: [[0, 0.35, "A red flash, the cost, the vials drain"], [0.06, HIT_T, "The same headbutt"], [HIT_T, 2.2, "Hit · 25 (31 at II)"]],
    notes: ["It looks like a normal headbutt with a red tint.", "Nothing says 'I paid health for this'."],
    build() { const tr = VM.headbutt.now.build(); tr.parts = ["bloodvial"]; tr.tint = redTint(0, 0.35); tr.ev.push({t: 0.02, f: () => { tag(pachy.pos.clone().add(new THREE.Vector3(0, 14, 0)), "-17 HP", "#ff5a5a", 0.9); bloodSpray(); }});
      tr.pa = t => ({level: t < 0.3 ? 1 - t / 0.3 : 0}); return tr; }},
  A: {name: "A · Blood Pact", sub: "a jolt, a roar, the vials empty into it", len: 2.4, rec: true, timing: "as now (inside the 0.15 s wind-up)",
    ref: "A berserker's battle cry; Bloodborne's blood-vial jab.",
    phases: [[0, 0.15, "Jolts, throws its head back roaring; the vials empty with a red spray"], [0.15, HIT_T, "Charges with red eyes and a red streak"], [HIT_T, HIT_T + 0.4, "CRUNCH · 31 (II)"], [HIT_T + 0.4, 2.4, "Shakes it off"]],
    notes: ["You see the price being paid.", "The roar is fast (0.15 s); it lands as a 'jolt'."],
    build() { const tr = bloodTrack({tint: redTint(0, 0.5)}); tr.keys = [K(0, READY), K(0.07, PACT, "out5"), K(CHARGE_T, BULL_LOW, "in2"), ...tr.keys.filter(k => k.t >= HIT_T)];
      tr.ev.push({t: 0.04, f: bloodSpray}, {t: 0.05, f: () => { vig("rgba(200,0,0,.55)", 1); shake = Math.max(shake, 0.4); }});
      const up = tr.update; tr.update = (t, dt) => { up && up(t, dt); if (t > CHARGE_T && t < HIT_T && Math.random() < dt * 40) puff(pachy.pos.clone().add(new THREE.Vector3(0, 6, 3)), new THREE.Vector3(0, 1, 10), 1.6, 0xd0202a, 0.3, T_SPARK); };
      tr.pa = t => ({level: t < 0.15 ? 1 - t / 0.15 : 0, vialGlow: t < 0.4 ? 1 : 0}); return tr; }},
  B: {name: "B · Heart Pump", sub: "three hard heartbeats, red veins", len: 2.4, timing: "as now",
    ref: "A heartbeat UI pulse; Hulk-style vein glow.",
    phases: [[0, 0.15, "Three quick heartbeats: the chest pumps, the vials pulse"], [0.15, HIT_T, "Charges, veins glowing red"], [HIT_T, 2.4, "Hit · 31 (II)"]],
    notes: ["Clear 'powering up' read.", "3 beats in 0.15 s is a flicker; slower would need a longer wind-up."],
    build() { const tr = bloodTrack({}); tr.keys = [K(0, READY), K(0.05, PUMP, "out"), K(0.1, READY, "io"), K(CHARGE_T, BULL_LOW, "io"), ...tr.keys.filter(k => k.t >= HIT_T)];
      tr.tint = t => t < 0.15 ? [0.4 * Math.abs(Math.sin(t * Math.PI / 0.05)), 0, 0] : t < HIT_T ? [0.14 + 0.06 * Math.sin(t * 30), 0, 0] : null;
      tr.pa = t => ({level: t < 0.15 ? 1 - t / 0.15 : 0, vialGlow: t < 0.15 ? Math.abs(Math.sin(t * Math.PI / 0.05)) : 0}); return tr; }},
  C: {name: "C · Bleed Snort", sub: "snorts red mist, a stomp", len: 2.4, timing: "as now",
    ref: "A bull snorting; Monster Hunter's enraged breath.",
    phases: [[0, 0.15, "Snorts red mist and stomps"], [0.15, HIT_T, "Charges trailing red"], [HIT_T, 2.4, "Hit · 31 (II)"]],
    notes: ["Fits the bull charge (Headbutt A).", "Mist can be mistaken for a fire / poison effect."],
    build() { const tr = bloodTrack({}); tr.keys = [K(0, READY), K(0.08, SNORT, "out5"), K(CHARGE_T, BULL_LOW, "io"), ...tr.keys.filter(k => k.t >= HIT_T)];
      tr.ev.push({t: 0.04, f: () => { for (let i = 0; i < 6; i++) puff(beakPoint(), new THREE.Vector3((Math.random() - .5) * 4, -2, -6 - Math.random() * 4), 1.8, 0xd0202a, 0.6); }}, {t: 0.08, f: () => { dust(partPoint(PP.footL), 6, 4, 2, 2.4); shake = Math.max(shake, 0.3); }});
      tr.pa = t => ({level: t < 0.15 ? 1 - t / 0.15 : 0}); return tr; }},
};

// Med-Station: drops a machine that heals everyone nearby (a wave every second); the pad lasts its time, then goes
const MS = {DROP: 0.3, LIFE: 3.0, R: 15};
function medTrack(o) { R0.show = false; R1.show = false; place(R1, -14, 4, 0); R1.yaw = -Math.PI / 2 - 0.3;
  const at = o.at || new THREE.Vector3(0, 0, 6); const T0 = o.T0 || 0; const st = {};
  return Object.assign({frame: [new THREE.Vector3(0, 0, -6), new THREE.Vector3(0, 0, 8)], parts: [], len: 4.4,
    update(t) { const u = o.unfold ? o.unfold(t) : (t >= T0 && t < T0 + MS.LIFE ? 1 : 0); medState(at, u, o.scale ? o.scale(t) : 1);
      const k = Math.floor((t - T0 - (o.wave0 || 0)) / 1.0); if (t >= T0 + (o.wave0 || 0) && t < T0 + MS.LIFE && k !== st.k) { st.k = k; healWave(at, MS.R); hitNum(pachy.pos.clone().add(new THREE.Vector3(0, 10, 0)), "+4", "venom"); hitNum(rapChestP(R1), "+4", "venom"); } }}, o); }
VM.medstation = {
  now: {name: "Now", sub: "as the game plays it (v479)", len: 4.4, timing: "the pad appears at the press, a wave every second",
    ref: "MedStationServer 1.2 (the pad is built where you stand, a heal wave every second for 0.9 s, '+N' pops; at the end it is destroyed).",
    phases: [[0, 0.02, "The pad pops into existence"], [0.02, MS.LIFE, "Heal waves every second"], [MS.LIFE, 4.4, "It vanishes"]],
    notes: ["No drop, no build-up, no shut-down: it blinks in and out.", "The pachy doesn't do anything."],
    build() { return medTrack({keys: [K(0, READY)], at: new THREE.Vector3(0, 0, 4)}); }},
  A: {name: "A · Deploy Drop", sub: "lays it from its back, it unfolds, then folds away", len: 4.6, rec: true, timing: "+0.3 s before the first wave",
    ref: "TF2's Engineer dispenser build; a mech dropping a supply pod.",
    phases: [[0, MS.DROP, "Crouches, tail up: a capsule pops out of its back and drops behind it"], [MS.DROP, MS.DROP + 0.3, "Thud: the capsule unfolds into the station"], [MS.DROP + 0.3, MS.DROP + MS.LIFE, "Heal waves every second"], [MS.DROP + MS.LIFE, 4.6, "Folds up and sinks"]],
    notes: ["You see where it came from and when it ends.", "The first wave is 0.3 s later than now."],
    build() { const T0 = MS.DROP; const at = new THREE.Vector3(0, 0, 8);
      const tr = medTrack({T0, at, wave0: 0.3, keys: [K(0, READY), K(0.15, LAY, "io"), K(MS.DROP, LAY), K(MS.DROP + 0.4, READY, "io")],
        unfold(t) { return t < T0 ? 0 : t < T0 + 0.3 ? 0.15 + 0.85 * E.out((t - T0) / 0.3) : t < T0 + MS.LIFE ? 1 : Math.max(0, 1 - (t - T0 - MS.LIFE) / 0.4); }});
      tr.ev = [{t: 0.08, f: () => { const from = partPoint(PP.hips).add(new THREE.Vector3(0, 2, 0)); const c = new THREE.Mesh(new THREE.BoxGeometry(3, 2.4, 3), new THREE.MeshLambertMaterial({color: 0xdfe6ee}));
          proj(c, from, () => at.clone().setY(1.2), MS.DROP - 0.08, 6, p => { dust(p.clone().setY(0.5), 8, 5, 2, 2.6); shake = Math.max(shake, 0.3); }); }}];
      return tr; }},
  B: {name: "B · Stomp Plant", sub: "a stomp, the station rises out of the ground", len: 4.6, timing: "+0.25 s before the first wave",
    ref: "Overwatch's Torbjörn turret build; a plant growing out of the ground.",
    phases: [[0, 0.25, "Lifts a foot and stomps"], [0.25, 0.55, "The station rises out of a dust ring"], [0.55, 0.25 + MS.LIFE, "Heal waves"], [0.25 + MS.LIFE, 4.6, "Sinks back into the ground"]],
    notes: ["Strong and simple; the stomp matches the pachy's weight.", "Rising from the ground looks odd on a wooden floor / bridge."],
    build() { const T0 = 0.25; const at = new THREE.Vector3(0, 0, -7);
      const tr = medTrack({T0, at, wave0: 0.3, keys: [K(0, READY), K(0.15, STOMP1, "io"), K(0.25, STOMP2, "in2"), K(0.6, READY, "io")],
        unfold(t) { return t < T0 ? 0 : t < T0 + 0.3 ? E.out((t - T0) / 0.3) : t < T0 + MS.LIFE ? 1 : Math.max(0, 1 - (t - T0 - MS.LIFE) / 0.4); }});
      tr.ev = [{t: 0.25, f: () => { dust(at.clone(), 10, 7, 3, 3); groundRing(at, 9, 0xe8d8b0, 0.4, 0.6); shake = Math.max(shake, 0.4); }}]; return tr; }},
  C: {name: "C · Head Toss", sub: "flicks a capsule ahead with the dome", len: 4.6, timing: "+0.45 s before the first wave",
    ref: "A goat tossing its head; a grenade toss.",
    phases: [[0, 0.15, "Dips the head"], [0.15, 0.45, "Tosses: the capsule arcs ahead"], [0.45, 0.75, "Lands and unfolds"], [0.75, 0.45 + MS.LIFE, "Heal waves"], [0.45 + MS.LIFE, 4.6, "Folds away"]],
    notes: ["You can place it a bit ahead (a teammate in front).", "Slowest to start (0.45 s)."],
    build() { const T0 = 0.45; const at = new THREE.Vector3(0, 0, -16);
      const tr = medTrack({T0, at, wave0: 0.3, keys: [K(0, READY), K(0.15, TOSS_DIP, "io"), K(0.22, TOSS_UP, "out5"), K(0.6, READY, "io")],
        unfold(t) { return t < T0 ? 0 : t < T0 + 0.3 ? 0.15 + 0.85 * E.out((t - T0) / 0.3) : t < T0 + MS.LIFE ? 1 : Math.max(0, 1 - (t - T0 - MS.LIFE) / 0.4); }});
      tr.frame = [new THREE.Vector3(0, 0, 0), new THREE.Vector3(0, 0, -16)];
      tr.ev = [{t: 0.2, f: () => { const c = new THREE.Mesh(new THREE.BoxGeometry(3, 2.4, 3), new THREE.MeshLambertMaterial({color: 0xdfe6ee})); proj(c, domePoint(), () => at.clone().setY(1.2), T0 - 0.2, 8, p => dust(p.clone().setY(0.5), 8, 5, 2, 2.6)); }}];
      return tr; }},
};

// Last Stand: a raptor bite drops the pachy under 30%; below the line it takes 15-25% less (star: untouchable 1.5 s, once)
const LS_HIT = 0.5;
function lastStandTrack(o) { place(R0, 0, -11, 0); R0.yaw = Math.PI; R1.show = false;
  R0.path = [[0, new THREE.Vector3(0, 0, -30), Math.PI, 1], [LS_HIT - 0.25, new THREE.Vector3(0, 0, -19), Math.PI, 1], [LS_HIT, new THREE.Vector3(0, 0, -19), Math.PI, 0]];
  const tr = Object.assign({frame: [new THREE.Vector3(0, 0, 0), new THREE.Vector3(0, 0, -18)], len: 3.6,
    ev: [{t: LS_HIT - 0.1, f: () => { R0.lunge = 1; }}, {t: LS_HIT, f: () => { const p = domePoint(); flash(p, 7); hitNum(p, 12, "hit"); hitStop = 0.06; shake = Math.max(shake, 0.6); tag(pachy.pos.clone().add(new THREE.Vector3(0, 14, 0)), "HP 28%", "#ff8a8a", 1.0); }},
      {t: 2.2, f: () => { R0.lunge = 1; }}, {t: 2.32, f: () => { const p = domePoint(); flash(p, 5); hitNum(p, 9, "hit"); }}]}, o);
  tr.ev = (o.evx || []).concat(tr.ev); return tr; }
VM.laststand = {
  now: {name: "Now", sub: "as the game plays it (v479)", len: 3.6, timing: "under 30% health",
    ref: "PachyStatsServer 1.0: the damage cut and the star's untouchable 1.5 s are an invisible ForceField; nothing reads PachyLastStand* on any screen.",
    phases: [[0, LS_HIT, "A raptor lunges in"], [LS_HIT, LS_HIT + 0.3, "Hit · drops under 30%"], [LS_HIT + 0.3, 3.6, "Nothing shows; the next bite does 9 instead of 12"]],
    notes: ["Nobody can see that Last Stand is on, or the star's 1.5 s of untouchable."],
    build() { return lastStandTrack({keys: [K(0, READY), K(LS_HIT, READY), K(LS_HIT + 0.05, HURT, "out"), K(LS_HIT + 0.4, READY, "io")]}); }},
  A: {name: "A · Battle Roar", sub: "roars, a red-gold ring, the dome glows", len: 3.6, rec: true, timing: "as now",
    ref: "A 'second wind' (Diablo's barbarian battle cry, Dark Souls' red low-HP glow).",
    phases: [[0, LS_HIT, "A raptor lunges in"], [LS_HIT, LS_HIT + 0.2, "Hit · drops under 30%"], [LS_HIT + 0.2, LS_HIT + 0.8, "ROARS: a red-gold ring bursts out (star: a gold shell for 1.5 s)"], [LS_HIT + 0.8, 3.6, "The dome glows red while it lasts; the next bite pings: 9"]],
    notes: ["Everyone sees 'this pachy is in Last Stand'.", "The star's gold shell matches its 1.5 s untouchable."],
    build() { const tr = lastStandTrack({keys: [K(0, READY), K(LS_HIT, READY), K(LS_HIT + 0.05, HURT, "out"), K(LS_HIT + 0.25, ROAR, "out5"), K(LS_HIT + 0.75, ROAR, "io"), K(LS_HIT + 1.1, READY, "io")],
      evx: [{t: LS_HIT + 0.25, f: () => { groundRing(pachy.pos.clone(), 16, 0xffb030, 0.6, 0.9); flash(domePoint(), 10, 0xffc040); shake = Math.max(shake, 0.6); shell.on = 1.5; }}],
      domeGlow(t) { return t > LS_HIT + 0.25 ? 0.5 + 0.2 * Math.sin(clockT * 5) : 0; }}); return tr; }},
  B: {name: "B · Heavy Breath", sub: "breathes hard, steam, a red outline", len: 3.6, timing: "as now",
    ref: "A boxer on the ropes; Resident Evil's limping 'danger' state.",
    phases: [[0, LS_HIT, "A raptor lunges in"], [LS_HIT, LS_HIT + 0.3, "Hit · drops under 30%"], [LS_HIT + 0.3, 3.6, "Heavy breathing, steam from the nose, a pulsing red outline"]],
    notes: ["Reads as 'hurt but dangerous'.", "Can read as 'weak': enemies may push in."],
    build() { return lastStandTrack({keys: [K(0, READY), K(LS_HIT, READY), K(LS_HIT + 0.05, HURT, "out"), K(LS_HIT + 0.5, HEAVY, "io")],
      extra(target, t) { if (t > LS_HIT + 0.5) { const b = Math.sin(t * 6); target.RootJoint[0] += 2 * b; target.Neck[0] += 4 * b; target.Jaw[0] += -4 * Math.max(0, b); } },
      update(t, dt) { if (t > LS_HIT + 0.5 && Math.random() < dt * 3) puff(beakPoint(), new THREE.Vector3(0, 1, -3), 1.2, 0xffffff, 0.6); },
      tint(t) { return t > LS_HIT + 0.3 ? [0.12 + 0.1 * Math.sin(t * 6), 0, 0] : null; }}); }},
  C: {name: "C · Stand Firm", sub: "a stomp crack ring, red embers", len: 3.6, timing: "as now",
    ref: "Street Fighter's 'V-Trigger' stomp.",
    phases: [[0, LS_HIT, "A raptor lunges in"], [LS_HIT, LS_HIT + 0.3, "Hit · drops under 30%"], [LS_HIT + 0.3, LS_HIT + 0.6, "Stomps: a crack ring"], [LS_HIT + 0.6, 3.6, "Red embers rise while it lasts"]],
    notes: ["Light on the screen; the embers last.", "The stomp ring is close to the 'no landing FX' rule (it isn't a landing)."],
    build() { return lastStandTrack({keys: [K(0, READY), K(LS_HIT, READY), K(LS_HIT + 0.05, HURT, "out"), K(LS_HIT + 0.3, STOMP1, "io"), K(LS_HIT + 0.42, STOMP2, "in2"), K(LS_HIT + 0.8, READY, "io")],
      evx: [{t: LS_HIT + 0.42, f: () => { groundRing(pachy.pos.clone(), 13, 0xff5030, 0.5, 0.8); dust(pachy.pos.clone(), 8, 6, 2, 2.6); shake = Math.max(shake, 0.5); }}],
      update(t, dt) { if (t > LS_HIT + 0.6 && Math.random() < dt * 10) { const s = sprite(T_SPARK, 0xff5030, 0.8, true); s.position.copy(pachy.pos).add(new THREE.Vector3((Math.random() - .5) * 8, 2, (Math.random() - .5) * 6)); addFx(s, 1, (o, u, dt2) => { o.position.y += dt2 * 6; o.material.opacity = 1 - u; }); } }}); }},
};
const shell = {on: 0, m: null};

// Head Down: while charging a headbutt, take 15-25% less (III: no shove; star: no stun) — a raptor bites the charging pachy
const HDB = 0.42;
function headDownTrack(o) { const tr = VM.headbutt.A.build(); place(R1, -12, -14, 0); R1.yaw = -Math.PI / 2 + 0.2;
  tr.ev = tr.ev.concat([{t: HDB - 0.12, f: () => { R1.lunge = 1; }}, {t: HDB, f: () => { const p = domePoint().add(new THREE.Vector3(-2, 0, 0)); hitNum(p, 9, "hit"); hitStop = 0.04; (o.onBite || (() => flash(p, 5)))(p); }}]);
  return Object.assign(tr, o); }
VM.headdown = {
  now: {name: "Now", sub: "as the game plays it (v479)", len: 2.2, timing: "while charging",
    ref: "HeadbuttServer 1.15: the cut (and no shove / no stun) applies while charging; the pose is the plain charge; nothing shows it.",
    phases: [[0, CHARGE_T, "Wind-up"], [CHARGE_T, HDB, "Charging"], [HDB, HDB + 0.2, "A raptor bites from the side: 9 (was 12)"], [HDB + 0.2, 2.2, "Keeps charging · hit"]],
    notes: ["Nothing shows the pachy is tougher while it charges."],
    build() { return headDownTrack({}); }},
  A: {name: "A · Steel Dome", sub: "the dome glows steel-blue while charging", len: 2.2, rec: true, timing: "as now",
    ref: "Armour 'hardening' glows (Smash Bros super armour flash).",
    phases: [[0, CHARGE_T, "Wind-up"], [CHARGE_T, HDB, "Charging: the dome glows steel-blue"], [HDB, HDB + 0.2, "Bite: a blue flash, sparks, 9"], [HDB + 0.2, 2.2, "Keeps charging · hit"]],
    notes: ["Always on while charging, so it's easy to learn.", "Only the dome changes: small from far away."],
    build() { return headDownTrack({domeGlow(t) { return t > CHARGE_T && t < HIT_T ? 0.7 : 0; }, domeCol: 0x6fb8ff, onBite: p => { flash(p, 7, 0x6fb8ff); sparks(p, new THREE.Vector3(-1, 0.4, 0), 8, 0xc8e6ff); }}); }},
  B: {name: "B · Bow Shield", sub: "a faint shield arc in front while charging", len: 2.2, timing: "as now",
    ref: "A ship's bow wave; Reinhardt's charge.",
    phases: [[0, CHARGE_T, "Wind-up"], [CHARGE_T, HDB, "Charging behind a faint shield arc"], [HDB, HDB + 0.2, "Bite: the arc flashes, 9"], [HDB + 0.2, 2.2, "Keeps charging · hit"]],
    notes: ["Very readable.", "Looks like it blocks from the front only, but the cut works from every side."],
    build() { return headDownTrack({bow: [CHARGE_T, HIT_T], onBite: p => { flash(p, 8, 0x9fd8ff); bowFlash = 1; }}); }},
  C: {name: "C · Spark Only", sub: "nothing while charging; hits spark", len: 2.2, timing: "as now",
    ref: "A metal-on-metal hit spark.",
    phases: [[0, CHARGE_T, "Wind-up"], [CHARGE_T, HDB, "Charging (as now)"], [HDB, HDB + 0.2, "Bite: blue sparks + '-25%'"], [HDB + 0.2, 2.2, "Keeps charging · hit"]],
    notes: ["Minimal.", "You only learn it's on when you get hit."],
    build() { return headDownTrack({onBite: p => { sparks(p, new THREE.Vector3(1, 0.4, 0), 10, 0xc8e6ff); tag(p, "-25%", "#9fd8ff", 0.8); }}); }},
};
let bowFlash = 0;
const bow = new THREE.Mesh(new THREE.CylinderGeometry(9, 9, 10, 32, 1, true, Math.PI - Math.PI / 3, Math.PI * 2 / 3), new THREE.MeshBasicMaterial({color: 0x9fd8ff, transparent: true, opacity: 0.18, side: THREE.DoubleSide, depthWrite: false}));
bow.visible = false; scene.add(bow);
shell.m = new THREE.Mesh(new THREE.SphereGeometry(13, 28, 18), new THREE.MeshBasicMaterial({color: 0xffc040, transparent: true, opacity: 0.2, depthWrite: false})); shell.m.visible = false; scene.add(shell.m);

const MOVES = [
  {id: "headbutt", name: "Headbutt", area: "attack", nums: "Damage 25 (a short run-up 18), shove 40, 2 charges, wind-up 0.15 s: unchanged. The raptor's stagger is new (looks only)."},
  {id: "leap", name: "Leap + double jump", area: "speed", nums: "Leap and the Mecha Legs double jump (80% height): heights, distance and recharge unchanged."},
  {id: "hook", name: "Grappling Hook", area: "attack", nums: "Range 60, claw 220 studs/s, pull 0.5 s, smash 10 + shove 30, recharge 8 s: unchanged. The stagger is new (looks only)."},
  {id: "servodash", name: "Servo Dash", area: "speed", nums: "22 studs in 0.25 s, then 2x speed for 1 s, recharge 12 s: unchanged (A adds a 0.06 s squat first)."},
  {id: "visor", name: "Dome Visor", area: "defense", nums: "Field 1.5 s, blocks from the front, recharge 14 s: unchanged."},
  {id: "ink", name: "Ink Shooter", area: "eng", nums: "60 studs, blind 2 s, recharge 15 s: unchanged (A / B add 0.1 / 0.12 s before the shot)."},
  {id: "tether", name: "Tether Spike", area: "eng", nums: "Lob 0.8 s, 8-stud circle, chained 2.5 s within 10 studs: unchanged."},
  {id: "bloodrush", name: "Blood Rush", area: "attack", nums: "Pays 25% of max health for one more headbutt: unchanged."},
  {id: "medstation", name: "Med-Station", area: "health", nums: "Heal waves every second for its time: unchanged (A / B / C start the waves 0.3 / 0.25 / 0.45 s later)."},
  {id: "laststand", name: "Last Stand", area: "health", nums: "Below 30%: 15-25% less damage (star: untouchable 1.5 s once): unchanged. Only looks are new."},
  {id: "headdown", name: "Head Down", area: "defense", nums: "While charging: 15-25% less damage (III no shove, star no stun): unchanged. Only looks are new."},
];
const AREA = {attack: ["Attack", "#ff6b6b"], speed: ["Speed", "#ffd34d"], defense: ["Defense", "#5fb4ff"], health: ["Health", "#7dff9a"], eng: ["Engineer", "#ff9b2e"]};

// ---------- the player ----------
let cur = 0, variant = "now", playing = true, speed = 1, camMode = "hero", play = null;
const M = () => MOVES[cur], VV = () => VM[M().id][variant];
function resetFx() { fx.splice(0).forEach(e => scene.remove(e.obj)); delayed = []; }
function start() {
  resetFx();
  for (const R of raps) { R.flinch = 0; R.flash = 0; R.push = 0; R.shove = 0; R.stagger = 0; R.ink = 0; R.path = null; R.run = 0; R.lunge = 0; R.show = false; }
  for (const k in PA) delete PA[k];
  const track = VV().build();
  play = {track, t: 0, fired: new Set()};
  springs = {}; rootSpring.x = 0; rootSpring.v = 0; hitStop = 0; shake = 0; fovPunch = 0; shell.on = 0; bowFlash = 0; gaitPh = 0;
  pachy.pos.set(0, 0, 0); med.visible = false;
}
let gaitPh = 0;
function idleLayer(t) {
  const b = Math.sin(t * 2.1), b2 = Math.sin(t * 2.1 + 1.2);
  return {RootJoint: [b * 1.0, 0, 0], Neck: [b * 1.6, Math.sin(t * 0.7) * 4, 0], Head: [-b * 1.4, Math.sin(t * 0.9 + 1) * 3, 0], Jaw: [0, 0, 0],
    ArmL: [b2 * 3, 0, 0], ArmR: [b2 * 3, 0, 0],
    Tail1: [b * 1.2, Math.sin(t * 1.3) * 4, 0], Tail2: [0, Math.sin(t * 1.3 - .6) * 5, 0], Tail3: [0, Math.sin(t * 1.3 - 1.2) * 6, 0], Tail4: [0, Math.sin(t * 1.3 - 1.8) * 7, 0], Tail5: [0, Math.sin(t * 1.3 - 2.4) * 8, 0]};
}
function rapPose(R, dt) {
  R.rig.g.visible = R.show; if (!R.show) return;
  const tt = play ? play.t : 0;
  if (R.path && play) {
    const P = R.path; let i = 0; while (i < P.length - 1 && tt > P[i + 1][0]) i++;
    if (tt <= P[0][0]) { R.pos.copy(P[0][1]); R.yaw = P[0][2]; R.run = P[0][3]; }
    else if (i >= P.length - 1) { R.pos.copy(P[P.length - 1][1]); R.yaw = P[P.length - 1][2]; R.run = 0; }
    else { const a = P[i], b = P[i + 1], u = (tt - a[0]) / (b[0] - a[0]); R.pos.lerpVectors(a[1], b[1], u); let dy = b[2] - a[2]; while (dy > Math.PI) dy -= 2 * Math.PI; while (dy < -Math.PI) dy += 2 * Math.PI; R.yaw = a[2] + dy * E.io(Math.min(1, u * 1.6)); R.run = a[3] + (b[3] - a[3]) * u; }
  }
  R.flinch = Math.max(0, R.flinch - dt * 2.6); R.flash = Math.max(0, R.flash - dt); R.stagger = Math.max(0, (R.stagger || 0) - dt * 1.4); R.ink = Math.max(0, (R.ink || 0) - dt);
  if (R.shove) { R.shoveT += dt; }
  R.runPh += dt * 15 * R.run;
  if (R.lunge) R.lunge = Math.max(0, R.lunge - dt * 2.2);
  const L = R.lunge ? Math.sin(Math.PI * Math.min(1, (1 - R.lunge) * 1.4)) : 0;
  const f = E.out(R.flinch), s = Math.sin(R.runPh), c = Math.cos(R.runPh), rn = R.run;
  // the new hit-react: a stagger (head snapped back + to the side, stumbling steps back, arms flung, then a wobble)
  const sg = R.stagger || 0, st = sg > 0 ? E.out(Math.min(1, (1 - sg) * 6)) * Math.min(1, sg * 2.2) : 0, wob = sg > 0 ? Math.sin((1 - sg) * 22) * sg : 0;
  const shoveK = R.shove ? E.out(Math.min(1, R.shoveT / R.shoveTime)) : 0;
  R.rig.yaw = R.yaw; R.rig.pos.copy(R.pos).addScaledVector(R.pushDir, (R.shove || 0) * shoveK);
  const fwd = new THREE.Vector3(-Math.sin(R.yaw), 0, -Math.cos(R.yaw)); R.rig.pos.addScaledVector(fwd, L * 5);
  const stepL = st * Math.sin((1 - sg) * 18) * 24;
  pose(R.rig, {RootJoint: [10 * f - 6 * rn - 14 * L + 16 * st, 0, R.side * 8 * f + 10 * wob], Neck: [12 * f - 4 * rn - 20 * L + 26 * st, R.side * -18 * f + Math.sin(clockT * 0.8) * 4 * (1 - f) - 24 * st + 12 * wob, 0], Head: [10 * f + 12 * st, 10 * wob, 0], Jaw: [-22 * f - 30 * L - 26 * st, 0, 0],
    ArmL: [-25 * f + 20 * L + 30 * st, 0, -20 * st], ArmR: [-25 * f + 20 * L + 30 * st, 0, 20 * st], Tail1: [-10 * f - 14 * st, Math.sin(clockT * 1.3) * 4 + 10 * wob, 0], Tail2: [0, Math.sin(clockT * 1.3 - .7) * 5, 0],
    LegL: [-8 * f + 34 * s * rn - 20 * st + stepL, 0, 0], LegR: [-8 * f - 34 * s * rn - 6 * st - stepL, 0, 0], KneeL: [-10 * f - (18 + 22 * Math.max(0, c)) * rn - 20 * st, 0, 0], KneeR: [-10 * f - (18 + 22 * Math.max(0, -c)) * rn - 30 * st, 0, 0]});
  if (R.rig.rest !== null) { R.rig.y = R.rig.rest + Math.abs(c) * 1.2 * rn; pose(R.rig, {}); }
  const fl = R.flash > 0 ? 1 : 0, ink = R.ink > 0 ? Math.min(1, R.ink) : 0;
  R.rig.mats.forEach(m => m.emissive.setRGB(fl * R.flashCol[0], fl * R.flashCol[1], fl * R.flashCol[2]));
  if (ink) { R.rig.mats.forEach(m => m.emissive.setRGB(0, 0, 0)); if (Math.random() < 0.3) puff(headOf(R), new THREE.Vector3(0, -3, 0), 0.8, 0x1a1426, 0.5, T_INK); }
}
raps.forEach(R => { pose(R.rig, {}); R.rig.y = R.rig.rest; R.rig.g.visible = false; });

function step(dt, noRender) {
  let mdt = dt * speed;
  if (hitStop > 0) { hitStop -= mdt; mdt *= 0.05; }
  idleT += mdt; clockT += mdt;
  let target = idleLayer(idleT), rootFwd = 0;
  const tr = play.track;
  play.t = play.t + mdt;
  const t = play.t;
  const mv = sample(tr.keys, t);
  target = addPose(mv, target, 1);
  if (tr.gait && t > tr.gait[0] && t < tr.gait[1] + 0.15) { const amt = Math.min(1, (t - tr.gait[0]) / 0.08) * Math.min(1, Math.max(0, (tr.gait[1] + 0.15 - t) / 0.15)) * (tr.gait[3] || 1); gaitPh += mdt * tr.gait[2]; target = addPose(target, gait(gaitPh, amt), 1); }
  rootFwd = (mv.root && mv.root.fwd) || 0;
  for (const e of (tr.ev || [])) { const k = "e" + e.t + (e.f.name || "") + tr.ev.indexOf(e); if (!play.fired.has(k) && t >= e.t) { play.fired.add(k); e.f(); } }
  for (let i = delayed.length - 1; i >= 0; i--) if (t >= delayed[i].at) { const d = delayed[i]; delayed.splice(i, 1); d.f(); }
  if (tr.update) tr.update(t, mdt);
  for (const n of pachy.joints.map(j => j.n)) if (!target[n]) target[n] = [0, 0, 0];
  if (tr.extra) tr.extra(target, t);
  for (const k in PA) delete PA[k];
  PA.show = tr.parts || [];
  if (tr.pa) Object.assign(PA, tr.pa(t));
  if (tr.field) { PA.field = tr.field(t); PA.fieldMode = tr.fieldMode; }
  const P = springStep(target, mdt);
  for (let i = 0, n = Math.max(1, Math.ceil(mdt * 300)); i < n; i++) { const h = mdt / n; rootSpring.v += (400 * (rootFwd - rootSpring.x) - 2 * 0.9 * 20 * rootSpring.v) * h; rootSpring.x += rootSpring.v * h; }
  const jump = tr.jumps ? jumpUp(tr.jumps, t) : {up: 0};
  pachy.yaw = 0; pachy.pos.set(0, 0, -(rootSpring.x + travelAt(tr.travel, t)));
  pachy.y = 0; pose(pachy, P);
  let minY = Infinity;
  for (const p of diloFeet) for (let i = 0; i < 8; i++) { _c.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(p.mesh.matrix); minY = Math.min(minY, _c.y); }
  pachy.y = -minY + jump.up; pose(pachy, P);
  placeParts();
  const tint = tr.tint ? tr.tint(t) : null;
  pachy.mats.forEach(m => m.emissive.setRGB(tint ? tint[0] : 0, tint ? tint[1] : 0, tint ? tint[2] : 0));
  // dome glow (Last Stand A, Head Down A)
  const dg = tr.domeGlow ? tr.domeGlow(t) : 0;
  for (const p of pachy.segs.Head) if (/dome/.test(p.name)) { if (!p.ownMat) { p.mesh.material = p.mesh.material.clone(); p.ownMat = true; } p.mesh.material.emissive.setHex(dg ? (tr.domeCol || 0xff4020) : 0); p.mesh.material.emissiveIntensity = dg || 0; }
  // the visor field, the bow shield, the gold shell
  bow.visible = !!(tr.bow && t > tr.bow[0] && t < tr.bow[1]); if (bow.visible) { bow.position.copy(pachy.pos).setY(6); bow.position.z -= 2; bowFlash = Math.max(0, bowFlash - mdt * 3); bow.material.opacity = 0.16 + 0.4 * bowFlash; }
  shell.on = Math.max(0, shell.on - mdt); shell.m.visible = shell.on > 0; if (shell.m.visible) { shell.m.position.copy(pachy.pos).setY(9); shell.m.material.opacity = 0.18 + 0.06 * Math.sin(clockT * 12); }
  // tether aim ring (your screen only)
  if (tr.aimRing && t > tr.aimRing[0] && t < tr.aimRing[1]) { reticle.visible = true; reticle.position.set(tr.aimAt.x, 0.12, tr.aimAt.z); reticle.scale.setScalar(1.33); } else reticle.visible = false;
  raps.forEach(R => rapPose(R, mdt));
  for (let i = fx.length - 1; i >= 0; i--) { const e = fx[i]; const fdt = mdt * (hitStop > 0 ? 0.2 : 1); e.t += fdt; const u = Math.min(1, e.t / e.life); e.update(e.obj, u, fdt); if (u >= 1) { scene.remove(e.obj); fx.splice(i, 1); } }
  if (noRender) return;
  shake = Math.max(0, shake - dt * 4.2); fovPunch = Math.max(0, fovPunch - dt * 14);
  CAM_SIDE = tr.camSide || 1;
  const fr = tr.frame;
  const mid = fr[0].clone().lerp(fr[1], 0.5).setY(9), span = fr[0].distanceTo(fr[1]) + 30;
  const hfov = 2 * Math.atan(Math.tan(rad(cam.fov / 2)) * cam.aspect), vfit = span * 0.5 / Math.tan(hfov / 2);
  let cp, look = mid;
  if (camMode === "hero") cp = mid.clone().add(new THREE.Vector3(CAM_SIDE, 0.4, -0.16).normalize().multiplyScalar(vfit * 1.08));
  else if (camMode === "side") cp = mid.clone().add(new THREE.Vector3(CAM_SIDE, 0.14, 0).normalize().multiplyScalar(vfit * 1.1));
  else if (camMode === "game") { cp = pachy.pos.clone().add(new THREE.Vector3(CAM_SIDE * 10, 30, 44)); look = pachy.pos.clone().add(new THREE.Vector3(0, 8, -26)); }
  else { const h = partPoint(PP.skull); cp = h.clone().add(new THREE.Vector3(CAM_SIDE * 15, 3, -15)); look = h.clone().add(new THREE.Vector3(0, -1.5, 0)); }
  camPos.lerp(cp, camMode === "close" ? 0.3 : 0.15); camLook.lerp(look, camMode === "close" ? 0.35 : 0.2);
  const sh = shake * shake;
  cam.position.copy(camPos).add(new THREE.Vector3((Math.random() - .5) * sh, (Math.random() - .5) * sh, (Math.random() - .5) * sh));
  cam.lookAt(camLook); cam.fov = 38 + fovPunch; cam.updateProjectionMatrix();
  sun.position.copy(mid).add(new THREE.Vector3(CAM_SIDE * 30, 70, 30)); sun.target.position.copy(mid);
  renderer.render(scene, cam);
}
let CAM_SIDE = 1; // the camera looks at the side the one-sided parts are on (+X = the dino's right = the hook / tether drum side)
const camPos = new THREE.Vector3(60, 26, -20), camLook = new THREE.Vector3(0, 9, -20);
function seek(t) { start(); const sp = speed; speed = 1; let n = 0; while (play.t < t - 1e-6 && n < 4000) { step(1 / 60, true); n++; } speed = sp; step(0); }

// ---------- UI ----------
function renderAll() {
  const VS = VM[M().id];
  $("moves").innerHTML = MOVES.map((m, i) => `<button class="tab" data-i="${i}" aria-pressed="${i === cur}">${m.name}<small style="color:${AREA[m.area][1]}">${AREA[m.area][0]}</small></button>`).join("");
  $("varRow").innerHTML = '<span class="lbl">Version</span>' + ["now", "A", "B", "C"].map(k => `<button class="var" data-var="${k}" aria-pressed="${k === variant}">${VS[k].name}${VS[k].rec ? ' <span class="rec">· recommended</span>' : ""}<small>${VS[k].sub}</small></button>`).join("");
  const v = VV(), ph = v.phases;
  $("phases").innerHTML = ph.map(p => `<button class="ph" data-t="${p[0]}" aria-current="false"><i>${p[0].toFixed(2)}–${p[1].toFixed(2)} s</i>${p[2]}</button>`).join("");
  const rows = ["now", "A", "B", "C"].map(k => `<tr><th>${VS[k].name}</th><td>${VS[k].timing}</td></tr>`).join("");
  const AR = AREA[M().area];
  $("info").innerHTML = `<div class="kind" style="color:${AR[1]}">${AR[0]} · ${M().name} · ${v.name}</div><h2>What you see, in order</h2><ul>${ph.map(p => `<li>${p[2]}</li>`).join("")}</ul><p class="note"><b>Borrowed from:</b> ${v.ref}</p><table class="cmp">${rows}</table><p class="note">${M().nums}</p>`;
  $("part").innerHTML = `<div class="kind" style="color:${AR[1]}">${variant === "now" ? "What's off about it now" : "What it does better · what it costs"}</div><ul>${v.notes.map(n => `<li>${n}</li>`).join("")}</ul>`;
}
$("moves").addEventListener("click", e => { const b = e.target.closest("[data-i]"); if (!b) return; cur = +b.dataset.i; variant = "now"; renderAll(); start(); });
$("varRow").addEventListener("click", e => { const b = e.target.closest("[data-var]"); if (!b) return; variant = b.dataset.var; renderAll(); start(); });
$("phases").addEventListener("click", e => { const b = e.target.closest("[data-t]"); if (!b) return; seek(+b.dataset.t + 0.06); playing = false; syncPlay(); });
$("play").onclick = () => { playing = !playing; syncPlay(); };
function syncPlay() { $("play").textContent = playing ? "Pause" : "Play"; $("play").setAttribute("aria-pressed", playing); }
document.querySelectorAll("[data-speed]").forEach(b => b.onclick = () => { speed = +b.dataset.speed; document.querySelectorAll("[data-speed]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => { camMode = b.dataset.view; document.querySelectorAll("[data-view]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
$("scrub").addEventListener("input", e => { seek(+e.target.value / 1000 * VV().len); playing = false; syncPlay(); });
$("ver").textContent = "v" + ANIM_VERSION;
function resize() { const w = cv.clientWidth, h = cv.clientHeight; if (renderer.domElement.width !== Math.round(w * renderer.getPixelRatio())) { renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); } }
window.addEventListener("resize", resize);
buildParts(); buildMed();
let last = performance.now();
function loop(now) {
  const dt = Math.min(0.05, (now - last) / 1000); last = now;
  resize();
  if (playing && !window.__manual) { step(dt); if (play.t >= VV().len) start(); }
  else if (!window.__manual) step(0);
  $("scrub").value = Math.round(Math.min(1, play.t / VV().len) * 1000);
  $("clock").textContent = `${play.t.toFixed(2)} s${speed !== 1 ? " · 0.3×" : ""}`;
  const ph = VV().phases.find(p => play.t >= p[0] && play.t < p[1]);
  $("cap").textContent = ph ? ph[2] : "…";
  document.querySelectorAll(".ph").forEach(b => b.setAttribute("aria-current", !!ph && +b.dataset.t === ph[0]));
  requestAnimationFrame(loop);
}
renderAll(); start(); resize();
requestAnimationFrame(loop);
// test hook: __pachy.set(move, variant, t, cam) seeks there and pauses
window.__pachy = {set(mv, v, time, cm) { window.__manual = true; cur = MOVES.findIndex(m => m.id === mv); variant = v; if (cm) camMode = cm; renderAll(); seek(time); for (let i = 0; i < 30; i++) step(0); }, len: () => VV().len, state: () => ({t: play.t, fx: fx.length, y: pachy.y, z: pachy.pos.z})};
window.__ready = true;
