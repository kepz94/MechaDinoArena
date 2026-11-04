// Therizino move animations mockup v0.1 (Mecha Dino Arena) — Kepu 2026-11-04 16:27: picks "Harvest-C, Snare-B, Dash-C,
// Hook-B" + "take into deep consideration the animations and the mecha ... it has to look good like a quality mecha part AND
// fit the dinosaur ... the animation has to be crystal clear what the intent is". Plays each move on the real model
// (core + looks of the redesign mockup v0.5, picked looks: Reaper Crane, Reaper Sleeves, Belly Winch, Tail Spool Rig).
// Units: the model's (game studs / 2). Front = -Z, the camera side = +X.
const ANIM_VERSION = "0.3"; // v0.3: the Reaper's Hook moves to the chest (Kepu 16:54 "can move to the chest now cause it looks so goofy like that")
// v0.2: the dash gets its own part (Kepu 16:47): A Flank Thrusters, B Storm Core (lightning), C Shoulder Jets
// (from the redesign core's page section, which this page leaves out)
const ease = u => u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2;
const lerp = (a, b, u) => a + (b - a) * u;
function mix(A, B, u) { const o = {}; for (const k of new Set([...Object.keys(A), ...Object.keys(B)])) { const a = A[k] || [0, 0, 0], b = B[k] || [0, 0, 0]; o[k] = [lerp(a[0], b[0], u), lerp(a[1], b[1], u), lerp(a[2], b[2], u)]; } return o; }
const IDLE = tt => ({Neck: [Math.sin(tt * 1.3) * 2, Math.sin(tt * 0.5) * 3, 0], Head: [Math.sin(tt * 1.3 + 1) * 3, 0, 0], Tail1: [0, Math.sin(tt * 0.8) * 3, 0], Tail2: [0, Math.sin(tt * 0.8 - 0.5) * 4, 0], Tail3: [0, Math.sin(tt * 0.8 - 1) * 5, 0], Tail4: [0, Math.sin(tt * 0.8 - 1.5) * 6, 0], Tail5: [0, Math.sin(tt * 0.8 - 2) * 7, 0]});
function resize() { const w = cv.clientWidth, h = cv.clientHeight; if (cv.width !== Math.round(w * renderer.getPixelRatio()) || cv.height !== Math.round(h * renderer.getPixelRatio())) { renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); } }
$("ver").textContent = "v" + ANIM_VERSION;
const easeIO = u => u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2;
const easeOut = u => 1 - Math.pow(1 - Math.min(1, Math.max(0, u)), 3);
const easeIn = u => Math.pow(Math.min(1, Math.max(0, u)), 2);
const clamp01 = u => Math.min(1, Math.max(0, u));
const seg = (tt, a, b) => clamp01((tt - a) / (b - a));
const lerpV = (a, b, u) => a.clone().lerp(b, u);
function mixP(...pairs) { // mixP([A, w], [B, w2]...) applied in order: start from first, blend each next by its weight
  let o = pairs[0][0];
  for (let i = 1; i < pairs.length; i++) o = mix(o, pairs[i][0], pairs[i][1]);
  return o;
}

// ---------- stage ----------
lab.visible = false; island.visible = true;
island.children.forEach(c => { if (c.type === "Group") c.visible = false; }); // no trees in the way
scene.background = new THREE.Color(0x8fc6e8); scene.fog = new THREE.Fog(0x8fc6e8, 90, 240);
const LY = () => 0; // pose() already stands the model on y = 0
pose({});
// ---------- v0.2: the dash parts (Kepu 16:47 "remove the grapple to dash mecha design and just give another mecha look like a
// thruster basically or something new to switch it like lightning jolt"). Free spots (the other picks): flanks / belly / shoulders.
let thrustYaw = 0, jetYaw = 0;
function flankThrusters() { // A: two thruster pods on the flanks that swivel to blast away from the dash
  const M = mount("Torso_body", [0, 0, 0]);
  for (const [s, side] of SIDES) {
    const podM = () => Tm(s * 1.78, 0.5, -0.75).multiply(RYm(thrustYaw)).multiply(new THREE.Matrix4().makeScale(1.35, 1.35, 1.35));
    const add = (sh, size, p, r, key, role) => M.add(sh, size, [0, 0, 0], [0, 0, 0], key, {place: () => podM().multiply(Tm(...p)).multiply(rot(...(r || [0, 0, 0]))), role});
    // mount arm from the flank armour
    M.box([0.5, 0.8, 1.1], [s * 1.3, 0.5, -0.75], null, "shell"); M.box([0.56, 0.1, 1.16], [s * 1.3, 0.94, -0.75], null, "trim");
    add("cyl", [0.62, 0.36, 0], [0, 0, 0], null, "brass", "pod" + side); // swivel ring
    add("box", [0.86, 0.86, 1.5], [0, 0, 0.15], null, "shell"); // pod body (studded)
    add("box", [0.92, 0.12, 1.2], [0, 0.48, 0.1], null, "plate");
    add("box", [0.08, 0.5, 0.9], [s * 0.47, 0, 0.1], null, "glow"); // side vent strip
    add("cyl", [0.78, 0.5, 0], [0, 0, 1.1], [90, 0, 0], "iron"); // nozzle collar (axis Z after the turn)
    add("cone", [1.0, 0.6, 0], [0, 0, 1.55], [-90, 0, 0], "steel"); // flared bell (opens backward)
    add("cyl", [0.5, 0.06, 0], [0, 0, 1.86], [90, 0, 0], "glow", "jet" + side); // the burner face
    add("wedge", [0.12, 0.5, 0.7], [0, 0.55, -0.35], null, "plate"); // fin
    M.hose([s * 1.1, 0.0, -0.2], [s * 1.5, 0.15, -0.3], 0.1, 0.12, 3);
  }
  M.hazard(1.4, 0.08, [0, -0.32, -1.92], null, 7);
}
function stormCore() { // B: a lightning capacitor under the belly + two Tesla coil horns on the shoulders
  const M = mount("Torso_body", [0, 0, 0]);
  M.box([1.9, 0.26, 1.5], [0, -0.42, -1.2], null, "shell"); // belly cradle
  for (const e of [-1, 1]) { M.box([0.16, 0.9, 1.3], [e * 0.95, -0.85, -1.2], null, "plate"); M.cyl([0.5, 0.12, 0], [e * 0.86, -1.05, -1.2], [0, 0, 90], "brass"); }
  M.cyl([0.86, 1.6, 0], [0, -1.05, -1.2], [0, 0, 90], "white", {alpha: 0.35}); // glass tank
  M.cyl([0.4, 1.5, 0], [0, -1.05, -1.2], [0, 0, 90], "glow", {role: "core"}); // charged coil inside
  for (let i = 0; i < 4; i++) M.cyl([0.92, 0.05, 0], [-0.6 + i * 0.4, -1.05, -1.2], [0, 0, 90], "brass", {detail: true}); // ribs
  M.hazard(1.2, 0.07, [0, -0.28, -1.96], null, 6);
  for (const [s, side] of SIDES) {
    const C = mount(`Arm${side}_shoulder`, [0, 0, 0]);
    const base = [s * 1.6, 2.05, -2.6];
    C.box([0.9, 0.3, 0.8], base, null, "shell");
    C.cyl([0.18, 1.3, 0], [base[0] + s * 0.15, base[1] + 0.75, base[2] + 0.1], [s * -12, 0, 0], "iron"); // rod
    for (let r = 0; r < 3; r++) C.add("ring", [0.32 - r * 0.06, 0.07], [base[0] + s * (0.08 + r * 0.06), base[1] + 0.45 + r * 0.32, base[2] + 0.1], [0, 0, 90], "brass"); // coil rings
    C.ball(0.36, [base[0] + s * 0.3, base[1] + 1.45, base[2] + 0.12], "glow", {role: "horn" + side}); // terminal
    C.hose([base[0] - s * 0.3, base[1] - 0.1, base[2] + 0.3], [base[0] - s * 1.2, base[1] - 1.6, base[2] + 1.0], 0.2, 0.1, 5);
  }
}
function shoulderJets() { // C: jump-jet pauldrons on both shoulders that swivel and fire
  for (const [s, side] of SIDES) {
    const M = mount(`Arm${side}_shoulder`, [0, 0, 0]);
    const base = [s * 1.62, 2.05, -2.55];
    M.box([1.3, 0.42, 1.3], base, null, "shell"); M.box([1.36, 0.08, 1.36], [base[0], base[1] + 0.25, base[2]], null, "trim");
    M.wedge([1.0, 0.3, 0.5], [base[0], base[1] + 0.05, base[2] - 0.72], [0, 180, 0], "plate");
    const jM = () => Tm(base[0] + s * 0.1, base[1] + 0.45, base[2] + 0.35).multiply(RYm(jetYaw)).multiply(RXm(rad(35))).multiply(new THREE.Matrix4().makeScale(1.5, 1.5, 1.5));
    const add = (sh, size, p, r, key, role) => M.add(sh, size, [0, 0, 0], [0, 0, 0], key, {place: () => jM().multiply(Tm(...p)).multiply(rot(...(r || [0, 0, 0]))), role});
    add("cyl", [0.5, 0.2, 0], [0, -0.1, 0], null, "brass", "jpod" + side);
    for (const dx of [-0.24, 0.24]) {
      add("cyl", [0.36, 0.9, 0], [dx, 0.25, 0.25], [90, 0, 0], "iron");
      add("cone", [0.5, 0.4, 0], [dx, 0.25, 0.85], [-90, 0, 0], "steel");
      add("cyl", [0.26, 0.05, 0], [dx, 0.25, 1.06], [90, 0, 0], "glow", dx < 0 ? "jjet" + side : undefined);
    }
    add("box", [0.7, 0.08, 0.5], [0, 0.55, 0.2], null, "glow");
  }
}
// v0.3: Reaper's Hook on the chest (the winch's old spot): a studded chest plate, a launcher barrel with the reaper claw seated
// in its muzzle, and a chain drum under it that reels you in. The claw leaves the muzzle when fired (role "hookhead").
let hookDrumSpin = 0;
function chestHook() {
  const M = mount("Torso_chest", [0, 0, 0]);
  // chest plate (studded) with trim, bolts, a red glow strip and launch stripes
  M.box([1.9, 1.7, 0.32], [0, 1.95, -3.45], null, "shell");
  M.box([2.0, 0.12, 0.38], [0, 2.82, -3.45], null, "trim"); M.box([2.0, 0.12, 0.38], [0, 1.08, -3.45], null, "trim");
  for (const [x, y] of [[-0.8, 2.6], [0.8, 2.6], [-0.8, 1.3], [0.8, 1.3]]) M.bolt([x, y, -3.63], "z", 0.14);
  for (const e of [-1, 1]) { M.box([0.3, 1.5, 0.5], [e * 1.02, 1.95, -3.2], null, "plate"); M.box([0.06, 1.1, 0.04], [e * 0.72, 1.95, -3.63], null, "glow"); }
  M.hazard(1.5, 0.1, [0, 1.18, -3.64], null, 8);
  // launcher barrel (along -Z) with a brass muzzle and a red glow ring inside
  M.box([0.95, 0.8, 0.9], [0, 2.2, -3.95], null, "plate");
  M.cyl([0.66, 1.25, 0], [0, 2.2, -4.45], [90, 0, 0], "iron");
  M.cyl([0.84, 0.2, 0], [0, 2.2, -5.05], [90, 0, 0], "brass");
  M.cyl([0.5, 0.06, 0], [0, 2.2, -5.16], [90, 0, 0], "glow", {role: "muzzle"});
  for (const e of [-1, 1]) M.cyl([0.16, 1.0, 0], [e * 0.42, 2.55, -4.4], [90, 0, 0], "steel"); // recoil rails
  // the reaper claw seated in the muzzle (prongs folded forward)
  grapnel(M, [0, 2.2, -5.45], 0.95, () => 0.15, "bone");
  for (const e of equip.slice(-7)) e.role = "hookhead";
  // chain drum under the barrel (spins while reeling) + brass flanges
  const drum = () => Tm(0, 1.45, -3.95).multiply(RXm(hookDrumSpin));
  M.add("cyl", [0.78, 1.25, 0], [0, 0, 0], [0, 0, 0], "steel", {place: () => drum().multiply(rot(0, 0, 90))});
  for (let k = 0; k < 4; k++) M.add("box", [1.24, 0.06, 0.82], [0, 0, 0], [0, 0, 0], "iron", {place: () => drum().multiply(RXm(k * Math.PI / 4))});
  for (const e of [-1, 1]) M.add("cyl", [0.98, 0.08, 0], [0, 0, 0], [0, 0, 0], "brass", {place: () => drum().multiply(Tm(e * 0.66, 0, 0)).multiply(rot(0, 0, 90))});
  // hoses up to the shoulders
  for (const e of [-1, 1]) M.hose([e * 0.6, 2.6, -3.3], [e * 1.4, 2.2, -2.7], 0.15, 0.12, 4);
}
const DASH_LOOKS = {A: flankThrusters, B: stormCore, C: shoulderJets};
let dashLook = "A";
let clawOut = false, harpoonOut = false;
let boomA = 0;
function buildRig() {
  for (const e of equip) if (e.mesh.parent) e.mesh.parent.remove(e.mesh); // they live under the rig (clearEquip only takes them off the scene)
  for (const c of cables) for (const m of c.segs) if (m.parent) m.parent.remove(m);
  clearEquip();
  GLOW = AREA.attack[2]; chestHook();
  GLOW = AREA.attack[2]; harvestSleeves({fore: false});
  GLOW = AREA.speed[2]; DASH_LOOKS[dashLook]();
  GLOW = AREA.eng[2]; snareSpools();
  for (const e of equip) theri.g.add(e.mesh);
  for (const c of cables) for (const m of c.segs) theri.g.add(m);
  // the crane's boom swings about its hinge (extra angle on top of the look's own motion)
  const hinge = Tm(0, 0.95, 0.5), hingeInv = Tm(0, -0.95, -0.5);
  for (const e of equip) if (e.place && (e.group === "boom" || e.group === "claw" || (e.group || "").startsWith("prong_")) && e.part === "Torso_body") {
    const orig = e.place; e.place = (u, tt) => hinge.clone().multiply(RXm(boomA)).multiply(hingeInv).multiply(orig(u, tt));
  }
  for (const e of equip) if (e.role === "hookhead") e.show = () => !clawOut;
}
buildRig();
const rig = theri.g;
function worldOf(part, p) { rig.updateMatrixWorld(true); return rig.localToWorld(restOn(part, p)); }
function centreOf(part, dp) { const e = theri.byName[part].cf.elements; return worldOf(part, [e[12] + (dp ? dp[0] : 0), e[13] + (dp ? dp[1] : 0), e[14] + (dp ? dp[2] : 0)]); }
function pieceWorld(role, part) { const e = equip.find(x => x.role === role && (!part || x.part === part)); if (!e) return new THREE.Vector3(); rig.updateMatrixWorld(true); return new THREE.Vector3().setFromMatrixPosition(e.mesh.matrix).applyMatrix4(rig.matrixWorld); }

// ---------- FX kit ----------
const fx = new THREE.Group(); scene.add(fx);
const MATS = {
  steel: new THREE.MeshPhongMaterial({color: 0xb8c0c8, specular: 0xaaaaaa, shininess: 70}), dark: new THREE.MeshPhongMaterial({color: 0x6d737c, specular: 0x888888, shininess: 50}),
  brass: new THREE.MeshPhongMaterial({color: 0xc9a24a, specular: 0xaaaaaa, shininess: 60}), bone: new THREE.MeshLambertMaterial({color: 0xe2dccb}),
  wire: new THREE.MeshBasicMaterial({color: 0xdfe6ee}), red: new THREE.MeshBasicMaterial({color: 0xff3b30, transparent: true, opacity: 0.9}),
  redSoft: new THREE.MeshBasicMaterial({color: 0xc0182a, transparent: true, opacity: 0.25, depthWrite: false}),
  white: new THREE.MeshBasicMaterial({color: 0xffffff, transparent: true, opacity: 0.9, depthWrite: false}),
  dust: new THREE.MeshLambertMaterial({color: 0xd8c9a0, transparent: true, opacity: 0.7, depthWrite: false}),
  orange: new THREE.MeshBasicMaterial({color: 0xff8a1a}), yellow: new THREE.MeshBasicMaterial({color: 0xffc21a}), blood: new THREE.MeshBasicMaterial({color: 0xc0182a}),
};
function mk(geo, mat) { const m = new THREE.Mesh(geo, mat); m.visible = false; fx.add(m); return m; }
const UP = new THREE.Vector3(0, 1, 0);
function setSeg(m, a, b, th) { const d = b.clone().sub(a), L = d.length(); if (L < 1e-4) { m.visible = false; return; } m.visible = true; m.position.copy(a).add(b).multiplyScalar(0.5); m.quaternion.setFromUnitVectors(UP, d.normalize()); m.scale.set(th, L, th); }
const CYL = new THREE.CylinderGeometry(0.5, 0.5, 1, 8), BOX = new THREE.BoxGeometry(1, 1, 1), BALL = new THREE.SphereGeometry(0.5, 14, 10);
// chain: alternating links
const LINKS = []; for (let i = 0; i < 70; i++) LINKS.push(mk(BOX, i % 2 ? MATS.steel : MATS.dark));
function chain(a, b) {
  const d = b.clone().sub(a), L = d.length(), n = Math.min(LINKS.length, Math.max(1, Math.floor(L / 0.75)));
  const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 0, 1), d.clone().normalize());
  for (let i = 0; i < LINKS.length; i++) {
    const m = LINKS[i]; if (i >= n) { m.visible = false; continue; }
    m.visible = true; m.position.copy(a).addScaledVector(d, (i + 0.5) / n); m.quaternion.copy(q);
    if (i % 2) m.quaternion.multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 0, 1), Math.PI / 2));
    m.scale.set(0.3, 0.1, 0.9);
  }
}
function chainOff() { for (const m of LINKS) m.visible = false; }
// a 3-prong reaper claw (the crane's own claw, flying)
const claw = new THREE.Group(); fx.add(claw); claw.visible = false; claw.scale.setScalar(1.8);
{
  const ball = new THREE.Mesh(BALL, MATS.brass); ball.scale.setScalar(0.5); claw.add(ball);
  claw.userData.prongs = [];
  for (let k = 0; k < 3; k++) {
    const g = new THREE.Group(); g.rotation.z = k * Math.PI * 2 / 3; claw.add(g);
    const arm = new THREE.Group(); g.add(arm);
    const a = new THREE.Mesh(BOX, MATS.bone); a.scale.set(0.14, 0.18, 1.0); a.position.set(0, 0.2, -0.5); arm.add(a);
    const tip = new THREE.Mesh(BOX, MATS.bone); tip.scale.set(0.14, 0.5, 0.16); tip.position.set(0, 0.05, -1.0); tip.rotation.x = 0.5; arm.add(tip);
    claw.userData.prongs.push(arm);
  }
}
function clawAt(pos, dir, open) { claw.visible = true; claw.position.copy(pos); claw.quaternion.setFromUnitVectors(new THREE.Vector3(0, 0, -1), dir.clone().normalize()); for (const p of claw.userData.prongs) p.rotation.x = -(0.25 + 0.75 * open); }
// harpoon (belly winch grapnel, flying) — same kit, smaller, brass prongs
const harp = claw.clone(); fx.add(harp); harp.visible = false; harp.scale.setScalar(1.3);
harp.userData.prongs = harp.children.filter(c => c.type === "Group").map(g => g.children[0]);
function harpAt(pos, dir, open) { harp.visible = true; harp.position.copy(pos); harp.quaternion.setFromUnitVectors(new THREE.Vector3(0, 0, -1), dir.clone().normalize()); for (const p of harp.userData.prongs) p.rotation.x = -(0.25 + 0.75 * open); }
const WIRE = mk(CYL, MATS.wire), WIRE2 = mk(CYL, MATS.wire);
// floating numbers
function label(text, color) {
  const c = document.createElement("canvas"); c.width = 256; c.height = 96; const g = c.getContext("2d");
  g.font = "800 64px Nunito, Segoe UI, sans-serif"; g.textAlign = "center"; g.lineWidth = 10; g.strokeStyle = "rgba(0,0,0,.75)"; g.strokeText(text, 128, 70); g.fillStyle = color || "#fff"; g.fillText(text, 128, 70);
  const s = new THREE.Sprite(new THREE.SpriteMaterial({map: new THREE.CanvasTexture(c), transparent: true, depthTest: false})); s.scale.set(3.2, 1.2, 1); s.visible = false; fx.add(s); return s;
}
const NUM = {n12: label("12"), n10: label("10"), n2: label("-2", "#ff6b6b"), n2b: label("-2", "#ff6b6b"), stun: label("STUN", "#ffd34d"), held: label("HELD", "#dfe6ee")};
function pop(s, pos, k) { s.visible = k > 0 && k < 1; if (!s.visible) return; s.position.copy(pos).add(new THREE.Vector3(0, 2.5 + k * 1.6, 0)); s.material.opacity = 1 - Math.max(0, k - 0.6) / 0.4; }
// dust puffs, ground rings, slash arcs, speed lines, drops
const PUFFS = []; for (let i = 0; i < 18; i++) PUFFS.push(mk(BALL, MATS.dust));
function puffs(center, k, spread, n, y0) { for (let i = 0; i < PUFFS.length; i++) { const m = PUFFS[i]; if (i >= n || k <= 0 || k >= 1) { m.visible = false; continue; } const a = i / n * Math.PI * 2 + i; m.visible = true; m.material = MATS.dust; m.position.set(center.x + Math.cos(a) * spread * k, (y0 || 0.3) + k * 0.8 + (i % 3) * 0.15, center.z + Math.sin(a) * spread * k); m.scale.setScalar(0.6 + k * 1.2); m.material.opacity = 0.7 * (1 - k); } }
const RING = mk(new THREE.RingGeometry(0.92, 1, 64), new THREE.MeshBasicMaterial({color: 0xff3b30, transparent: true, opacity: 0.9, side: THREE.DoubleSide, depthWrite: false})); RING.rotation.x = -Math.PI / 2;
const DISC = mk(new THREE.CircleGeometry(1, 64), MATS.redSoft); DISC.rotation.x = -Math.PI / 2;
const SPIRAL = new THREE.Group(); fx.add(SPIRAL); SPIRAL.visible = false;
for (let arm = 0; arm < 3; arm++) for (let i = 0; i < 14; i++) { const u = i / 14, a = arm * Math.PI * 2 / 3 + u * 2.4, r = 0.15 + u * 0.85; const m = new THREE.Mesh(BOX, new THREE.MeshBasicMaterial({color: 0xff3b30, transparent: true, opacity: 0.35 + 0.4 * u, depthWrite: false})); m.position.set(Math.cos(a) * r, 0.02, Math.sin(a) * r); m.rotation.y = -a; m.scale.set(0.05 + 0.08 * u, 0.02, 0.12); SPIRAL.add(m); }
const CRACKS = []; for (let i = 0; i < 6; i++) { const m = mk(BOX, MATS.red); CRACKS.push(m); }
const SLASH = []; for (let i = 0; i < 2; i++) { const m = mk(new THREE.TorusGeometry(4, 0.2, 6, 40, Math.PI * 0.9), MATS.white); SLASH.push(m); }
const SPEED = []; for (let i = 0; i < 10; i++) SPEED.push(mk(BOX, new THREE.MeshBasicMaterial({color: 0xffffff, transparent: true, opacity: 0.5, depthWrite: false})));
const DROPS = []; for (let i = 0; i < 24; i++) DROPS.push(mk(BALL, MATS.blood));
const WRAP = []; for (let i = 0; i < 4; i++) { const m = mk(new THREE.TorusGeometry(0.55, 0.06, 6, 24), MATS.wire); WRAP.push(m); }
const DART = mk(BOX, new THREE.MeshBasicMaterial({color: 0xff5a4e}));
// sickle blades (Harvest): bone blade + red edge, spinning
const SICKLES = [];
for (let i = 0; i < 6; i++) {
  const g = new THREE.Group(); fx.add(g); g.visible = false;
  const b = new THREE.Mesh(BOX, MATS.bone); b.scale.set(1.5, 0.12, 0.42); b.position.x = 0.5; g.add(b);
  const tip = new THREE.Mesh(BOX, MATS.bone); tip.scale.set(0.45, 0.12, 0.3); tip.position.set(1.35, 0, -0.25); tip.rotation.y = 0.6; g.add(tip);
  const e = new THREE.Mesh(BOX, MATS.red); e.scale.set(1.5, 0.13, 0.06); e.position.set(0.5, 0, -0.22); g.add(e);
  const hub = new THREE.Mesh(BALL, MATS.brass); hub.scale.setScalar(0.32); g.add(hub);
  g.scale.setScalar(1.8); SICKLES.push(g);
}
// bola: two brass weights + wire + orange core
const BOLA = new THREE.Group(); fx.add(BOLA); BOLA.visible = false; BOLA.scale.setScalar(1.8);
{ for (const e of [-1, 1]) { const w = new THREE.Mesh(BALL, MATS.brass); w.scale.setScalar(0.55); w.position.x = e * 1.1; BOLA.add(w); const c = new THREE.Mesh(BALL, MATS.orange); c.scale.setScalar(0.25); c.position.set(e * 1.1, 0.22, 0); BOLA.add(c); }
  const wr = new THREE.Mesh(CYL, MATS.wire); wr.scale.set(0.06, 2.2, 0.06); wr.rotation.z = Math.PI / 2; BOLA.add(wr); }
function fxOff() { fx.children.forEach(c => c.visible = false); boltIdx = 0; }
// v0.2 dash FX: flames, shock rings, lightning bolts, afterimages, steam, the dino's flash
const ADD = (c, o) => new THREE.MeshBasicMaterial({color: c, transparent: true, opacity: o, blending: THREE.AdditiveBlending, depthWrite: false});
const CONE = new THREE.ConeGeometry(0.5, 1, 14); CONE.translate(0, 0.5, 0); CONE.rotateX(Math.PI); CONE.translate(0, 1, 0); // base at 0, tip at +1
const FLAMES = [0, 1].map(() => ({outer: mk(CONE, ADD(0xff8a1a, 0.75)), inner: mk(CONE, ADD(0xfff3b0, 0.95))}));
function flame(i, at, out, len, w) {
  const F = FLAMES[i]; if (len <= 0.05) return;
  for (const [m, ww, ll] of [[F.outer, w, len], [F.inner, w * 0.55, len * 0.6]]) { m.visible = true; m.position.copy(at); m.quaternion.setFromUnitVectors(UP, out); m.scale.set(ww, ll, ww); }
}
const BURSTS = [0, 1].map(() => { const m = mk(new THREE.RingGeometry(0.8, 1, 48), ADD(0xffd34d, 0.9)); m.material.side = THREE.DoubleSide; return m; });
let burstIdx = 0;
function burst(pos, k, color, maxR) { const m = BURSTS[burstIdx++ % 2]; m.visible = k > 0 && k < 1; if (!m.visible) return; m.material.color.setHex(color); m.position.copy(pos); m.rotation.set(-Math.PI / 2, 0, 0); m.scale.setScalar(0.5 + (maxR || 3) * easeOut(k)); m.material.opacity = 0.9 * (1 - k); }
const BOLTS = [], BOLTGLOW = [];
for (let i = 0; i < 160; i++) { BOLTS.push(mk(CYL, ADD(0xfffbe0, 1))); BOLTGLOW.push(mk(CYL, ADD(0xffc21a, 0.45))); }
let boltIdx = 0;
function rnd(n) { const x = Math.sin(n * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); }
function bolt(a, b, n, amp, seed) {
  const d = b.clone().sub(a), side = new THREE.Vector3().crossVectors(d, UP); if (side.length() < 1e-3) side.set(1, 0, 0); side.normalize();
  const up2 = new THREE.Vector3().crossVectors(side, d).normalize();
  let prev = a.clone();
  for (let i = 1; i <= n; i++) {
    const u = i / n, j = i === n ? 0 : 1;
    const p = a.clone().addScaledVector(d, u).addScaledVector(side, (rnd(seed * 13 + i) - 0.5) * 2 * amp * j).addScaledVector(up2, (rnd(seed * 7 + i * 3) - 0.5) * 2 * amp * j);
    if (boltIdx < BOLTS.length) { setSeg(BOLTS[boltIdx], prev, p, 0.12); setSeg(BOLTGLOW[boltIdx], prev, p, 0.45); boltIdx++; }
    prev = p;
  }
}
const GHOSTS = [];
function ghosts(on, positions, alpha) {
  if (!GHOSTS.length) for (let g = 0; g < 3; g++) { const G = new THREE.Group(); fx.add(G); G.visible = false; G.userData.ms = theri.parts.map(pt => { const m = new THREE.Mesh(pt.mesh.geometry, ADD(0xffd34d, 0.3)); m.matrixAutoUpdate = false; G.add(m); return m; }); GHOSTS.push(G); }
  GHOSTS.forEach((G, g) => { G.visible = on; if (!on) return; G.position.copy(positions[g]); G.userData.ms.forEach((m, i) => { m.matrix.copy(theri.parts[i].mesh.matrix); m.material.opacity = 0.32 * alpha * (0.5 + g * 0.25); }); });
}
function dinoFlash(k) { for (const pt of theri.parts) { if (!pt.mesh.material.emissive) continue; pt.mesh.material.emissive.setRGB(1 * k * 0.7, 0.85 * k * 0.7, 0.2 * k * 0.7); } }
const SMOKE = new THREE.MeshBasicMaterial({color: 0xb9bdc4, transparent: true, opacity: 0.6, depthWrite: false});
const STEAM = []; for (let i = 0; i < 8; i++) STEAM.push(mk(BALL, new THREE.MeshLambertMaterial({color: 0xf2f4f8, transparent: true, opacity: 0.6, depthWrite: false})));
function steam(k) { ["jjetL", "jjetR"].forEach((r, s2) => { const n = pieceWorld(r); for (let i = 0; i < 4; i++) { const m = STEAM[s2 * 4 + i], kk = (k + i * 0.25) % 1; m.visible = true; m.position.copy(n).add(new THREE.Vector3((i - 1.5) * 0.2, kk * 2.5, 0)); m.scale.setScalar(0.3 + kk * 0.8); m.material.opacity = 0.55 * (1 - kk) * (1 - k * 0.5); } }); }
const DASH_TEXT = {
  A: {sub: "A · Flank Thrusters", part: "Flank Thrusters (two swivel pods on the flanks)", why: "Two studded rocket pods on the flanks, hung on brass swivel rings. They turn to point away from where you're going and fire. Yellow = speed glow on the vents and burners.",
    does: ["You move right; both pods swivel to point the other way and ignite", "The blast shoves you sideways, low and fast, with a flame and smoke trail", "A raptor's shot flies through where you were standing", "The pods cut out and swing back; you skid to a stop"],
    phases: [[0, 0.12, "Pods swivel away from the dash and ignite"], [0.12, 0.42, "Blast · shoved sideways, flame + smoke trail"], [0.2, 0.7, "The shot misses behind you"], [0.42, 0.85, "Pods cut out · skid to a stop"], [0.85, 3.2, "—"]]},
  B: {sub: "B · Storm Core (lightning)", part: "Storm Core (belly capacitor + two shoulder coils)", why: "A glass capacitor under the belly with a charged coil inside, and a Tesla coil on each shoulder. It charges, then the Therizino jolts across in a lightning bolt. Yellow = speed glow, as lightning.",
    does: ["Lightning crackles between the two shoulder coils and the belly core: it's charging", "You jolt across in a bolt of lightning, the body flashing, leaving yellow afterimages", "A raptor's shot flies through where you were standing", "You land in a crackle: a shock ring and sparks fade out"],
    phases: [[0, 0.16, "Charge · arcs between the shoulder coils and the core"], [0.16, 0.3, "Jolt · a lightning bolt across, afterimages"], [0.2, 0.7, "The shot misses behind you"], [0.3, 0.95, "Discharge · shock ring and sparks on landing"], [0.95, 3.2, "—"]]},
  C: {sub: "C · Shoulder Jets", part: "Shoulder Jets (jump-jet pauldrons)", why: "Armoured pauldrons on both shoulders, each with twin jets on a swivel. They turn and fire for a short hop to the side. Yellow = speed glow on the burners and the pauldron strip.",
    does: ["Both shoulder jets swivel away from the dash and ignite", "You hop sideways on two jet plumes, legs tucked", "A raptor's shot flies through where you were standing", "You land; the jets swing back and vent steam"],
    phases: [[0, 0.12, "Shoulder jets swivel and ignite"], [0.12, 0.45, "Burst · a low hop sideways on two plumes"], [0.2, 0.7, "The shot misses behind you"], [0.45, 0.9, "Land · jets vent steam"], [0.9, 3.2, "—"]]},
};

// ---------- the enemy (a studded raptor dummy) ----------
function makeRaptor() {
  const R = new THREE.Group(); scene.add(R);
  const mat = new THREE.MeshLambertMaterial({color: 0x9b2c22, map: studTex}), belly = new THREE.MeshLambertMaterial({color: 0xd9b48a, map: studTex}), eye = new THREE.MeshBasicMaterial({color: 0xffe14d});
  const add = (parent, s, p, m) => { const b = new THREE.Mesh(studBox(...s), m || mat); b.position.set(...p); parent.add(b); return b; };
  const hips = new THREE.Group(); hips.position.y = 2.3; R.add(hips);
  add(hips, [1.3, 1.2, 2.6], [0, 0.2, 0]); add(hips, [1.0, 0.5, 2.0], [0, -0.35, -0.2], belly);
  const neck = new THREE.Group(); neck.position.set(0, 0.6, -1.2); hips.add(neck); neck.rotation.x = 0.5;
  add(neck, [0.7, 1.4, 0.7], [0, 0.6, 0]); const head = add(neck, [0.9, 0.8, 1.6], [0, 1.3, -0.5]); head.rotation.x = -0.5;
  add(head, [0.15, 0.15, 0.15], [0.42, 0.15, -0.3], eye); add(head, [0.15, 0.15, 0.15], [-0.42, 0.15, -0.3], eye);
  const tail = add(hips, [0.6, 0.6, 2.6], [0, 0.35, 2.4]); tail.rotation.x = 0.15;
  const legs = [];
  for (const e of [-1, 1]) { const L = new THREE.Group(); L.position.set(e * 0.55, -0.2, 0.3); hips.add(L); add(L, [0.45, 1.3, 0.5], [0, -0.6, 0]); const sh = new THREE.Group(); sh.position.y = -1.2; L.add(sh); add(sh, [0.35, 1.0, 0.35], [0, -0.45, 0.2]); add(sh, [0.5, 0.15, 0.8], [0, -0.95, -0.1]); legs.push({L, sh}); }
  for (const e of [-1, 1]) add(hips, [0.2, 0.6, 0.2], [e * 0.5, -0.2, -1.1]);
  R.userData = {hips, legs, neck, mat, base: 0x9b2c22};
  return R;
}
const raptors = [makeRaptor(), makeRaptor(), makeRaptor()];
function raptorPose(R, o) { // o: {pos, yaw, run (phase), runAmt, flash, trip (0..1), visible}
  R.visible = o.visible !== false; if (!R.visible) return;
  R.position.copy(o.pos); R.rotation.y = o.yaw || 0;
  const u = R.userData, ph = o.run || 0, a = o.runAmt === undefined ? 1 : o.runAmt;
  u.legs.forEach((l, i) => { const s = Math.sin(ph + i * Math.PI); l.L.rotation.x = s * 0.7 * a; l.sh.rotation.x = -Math.max(0, Math.cos(ph + i * Math.PI)) * 0.9 * a; });
  u.hips.position.y = 2.3 + Math.abs(Math.sin(ph)) * 0.15 * a - (o.trip || 0) * 0.9;
  u.hips.rotation.x = (o.trip || 0) * 0.55; u.hips.rotation.z = o.roll || 0;
  u.mat.color.setHex(o.flash ? 0xffffff : u.base);
}
const raptorFeet = R => new THREE.Vector3(R.position.x, 0.6, R.position.z);

// ---------- the four moves ----------
const P = POSES;
const ARMS_UP = {ArmL: [75, 30, 25], ArmR: [75, -30, -25], RootJoint: [6, 0, 0], Neck: [8, 0, 0], Tail1: [-6, 0, 0]};
const VORTEX = {...P.STAB, ArmL: [-14, 12, 18], ArmR: [-14, -12, -18]};
const BOLA_WIND = {RootJoint: [-6, 18, 0], Neck: [0, -14, 0], Tail1: [-6, -22, 0], Tail2: [-6, -24, 0], Tail3: [-4, -26, 0], Tail4: [0, -26, 0], Tail5: [4, -26, 0], LegL: [8, 0, 0], KneeL: [-14, 0, 0]};
const BOLA_THROW = {RootJoint: [-10, -16, 0], Neck: [-4, 16, 0], Tail1: [-18, 26, 0], Tail2: [-18, 30, 0], Tail3: [-14, 30, 0], Tail4: [-10, 28, 0], Tail5: [-6, 26, 0], LegR: [10, 0, 0], KneeR: [-16, 0, 0]};
const DODGE = {RootJoint: [-14, 0, 16], LegL: [36, 0, 0], LegR: [26, 0, 0], KneeL: [-62, 0, 0], KneeR: [-52, 0, 0], AnkleL: [22, 0, 0], AnkleR: [18, 0, 0], ArmL: [34, 0, 16], ArmR: [34, 0, -16], Neck: [-6, 0, -10], Tail1: [8, 0, -10], Tail2: [6, 0, -8]};
const SKID = {RootJoint: [-6, 0, 6], LegL: [18, 0, 0], LegR: [-10, 0, 0], KneeL: [-30, 0, 0], KneeR: [-20, 0, 0], ArmL: [20, 0, 10], ArmR: [20, 0, -10]};
const HOOK_SET = {RootJoint: [-6, 0, 0], Neck: [-14, 0, 0], ArmL: [40, 0, 40], ArmR: [40, 0, -40], LegL: [12, 0, 0], LegR: [-6, 0, 0], KneeL: [-20, 0, 0], KneeR: [-10, 0, 0]};
const REEL = {RootJoint: [-20, 0, 0], Neck: [-10, 0, 0], ArmL: [100, -20, 20], ArmR: [100, 20, -20], LegL: [48, 0, 0], LegR: [36, 0, 0], KneeL: [-74, 0, 0], KneeR: [-62, 0, 0], AnkleL: [24, 0, 0], AnkleR: [20, 0, 0], Tail1: [12, 0, 0], Tail2: [8, 0, 0]};
const SLASH_P = {RootJoint: [-26, 0, 0], Neck: [-16, 0, 0], Head: [-6, 0, 0], ArmL: [-24, 30, 34], ArmR: [-24, -30, -34], LegL: [26, 0, 0], LegR: [-8, 0, 0], KneeL: [-38, 0, 0], KneeR: [-16, 0, 0], Tail1: [-10, 0, 0]};

let ringStuds = 16;
const MOVES = [
  { id: "harvest", name: "Harvest Field", sub: "C · Reaper Vortex", area: "attack", len: 4.8,
    part: "Reaper Sleeves (claws + wrist cuffs)", partWhy: "The claw sleeves are the business end: they punch into the ground and the wrist cuffs fire their bone sickles out to form the spinning ring. Red = attack glow on the sleeves and the sickle edges.",
    does: ["Rears up, claw sleeves glow red", "Slams both claws into the ground: red cracks race out to the ring's edge", "Six bone sickles shoot out of the wrist cuffs and lock into a spinning ring", "Everyone inside is dragged toward you and bleeds (-2 ticks)", "Sickles fly back into the cuffs, you stand up"],
    nums: "Ring 12 / 16 / 20 studs wide (your pick) · pulls 6 studs/s · bleed 4/s · 3 / 4 / 5 s · recharge 20 s",
    phases: [[0, 0.4, "Wind-up · rears up, sleeves glow"], [0.4, 0.58, "Stab · claws into the ground, cracks race out"], [0.58, 0.95, "Sickles launch from the wrist cuffs"], [0.95, 3.9, "Vortex · ring spins, drags them in, they bleed"], [3.9, 4.3, "Sickles return · stand up"], [4.3, 4.8, "—"]],
    close: ["ArmL_hand", [7, 3, -9]], focus: () => new THREE.Vector3(0, 3, -5), side: [37.5, 7.5, -1.5], three: [24.0, 16.5, 22.5], top: [0, 52, -5],
    update(tt) {
      const R = ringStuds / 4; // radius in model units (studs / 2 / 2)
      const centre = new THREE.Vector3(0, 0, -5);
      rig.position.set(0, LY(), 0); rig.rotation.set(0, 0, 0);
      let A = IDLE(tt);
      A = mix(A, ARMS_UP, easeIO(seg(tt, 0, 0.4)));
      A = mix(A, VORTEX, easeIn(seg(tt, 0.4, 0.52)));
      if (tt > 3.9) A = mix(VORTEX, IDLE(tt), easeIO(seg(tt, 3.9, 4.3)));
      pose(A); use = tt > 0.15 && tt < 4.1 ? 1 : 0;
      // stab: cracks + dust
      const kc = seg(tt, 0.48, 0.75);
      CRACKS.forEach((m, i) => { const a = i / 6 * Math.PI * 2 + 0.3, L = R * kc; m.visible = tt > 0.48 && tt < 3.9; m.position.set(centre.x + Math.cos(a) * L / 2, 0.04, centre.z + Math.sin(a) * L / 2); m.rotation.set(0, -a, 0); m.scale.set(L, 0.04, 0.16); });
      puffs(centre, seg(tt, 0.48, 1.1), 2.2, 10);
      // ground: disc + spiral + edge ring
      const on = tt > 0.7 && tt < 4.0, fade = 1 - seg(tt, 3.9, 4.0);
      DISC.visible = on; DISC.position.set(centre.x, 0.03, centre.z); DISC.scale.setScalar(R * seg(tt, 0.7, 0.95)); DISC.material.opacity = 0.25 * fade;
      RING.visible = on; RING.position.set(centre.x, 0.05, centre.z); RING.scale.setScalar(R * seg(tt, 0.7, 0.95));
      SPIRAL.visible = on; SPIRAL.position.set(centre.x, 0.04, centre.z); SPIRAL.scale.setScalar(R * seg(tt, 0.7, 0.95)); SPIRAL.rotation.y = -tt * 2.2;
      // sickles: from the wrist cuffs out to the ring, orbit, back
      const cuffs = [centreOf("ArmL_hand"), centreOf("ArmR_hand")];
      SICKLES.forEach((g, i) => {
        const a0 = i / 6 * Math.PI * 2, spin = tt * 3.2, ang = a0 + (tt > 0.95 ? (tt - 0.95) * 3.2 : 0);
        const ringPos = new THREE.Vector3(centre.x + Math.cos(ang) * R, 1.4, centre.z + Math.sin(ang) * R);
        const from = cuffs[i % 2];
        let pos, vis = true;
        if (tt < 0.58) vis = false;
        else if (tt < 0.95) pos = lerpV(from, ringPos, easeOut(seg(tt, 0.58, 0.95)));
        else if (tt < 3.9) pos = ringPos;
        else if (tt < 4.25) pos = lerpV(ringPos, from, easeIn(seg(tt, 3.9, 4.25)));
        else vis = false;
        g.visible = vis; if (!vis) return;
        g.position.copy(pos); g.rotation.set(0, -ang - spin * 4, 0);
      });
      // enemies: two inside (dragged in), one outside (unaffected)
      const starts = [[R * 0.8, -R * 0.55], [-R * 0.65, -R * 0.75], [R * 2.2, -R * 1.4]];
      raptors.forEach((Rp, i) => {
        const s = new THREE.Vector3(centre.x + starts[i][0], 0, centre.z + starts[i][1]);
        const inside = i < 2;
        const pull = inside ? clamp01((tt - 0.95) * 6 / 2 / (s.distanceTo(centre) || 1)) : 0;
        const k = Math.min(0.62, pull);
        const pos = lerpV(s, centre, k);
        const away = s.clone().sub(centre).setY(0);
        raptorPose(Rp, {pos, yaw: Math.atan2(away.x, away.z) + Math.PI, run: tt * (inside && tt > 0.95 && tt < 3.9 ? 9 : 4), runAmt: inside && tt > 0.95 && tt < 3.9 ? 1 : 0.15, flash: inside && tt > 0.95 && tt < 3.9 && (tt % 0.5) < 0.07});
      });
      // bleed drops + ticks
      DROPS.forEach((d, j) => { const Rp = raptors[j % 2]; const on2 = tt > 1 && tt < 3.9; d.visible = on2; if (!on2) return; const ph = ((tt * 1.6 + j * 0.13) % 1); d.position.set(Rp.position.x + ((j * 7) % 5 - 2) * 0.25, 3 - ph * 2.8, Rp.position.z + ((j * 3) % 5 - 2) * 0.25); d.scale.setScalar(0.18); });
      const tick = (tt - 1) % 0.5 / 0.5; pop(NUM.n2, raptors[0].position, tt > 1 && tt < 3.9 ? tick : -1); pop(NUM.n2b, raptors[1].position, tt > 1 && tt < 3.9 ? tick : -1);
    } },
  { id: "snare", name: "Snare Wires", sub: "B · Bola", area: "eng", len: 3.8,
    part: "Tail Spool Rig (three spools on the tail)", partWhy: "The wire comes off the tail spools: the tail winds up like a sling, the bola whirls off the last spool and the tail whips to throw it. Orange = engineer glow on the spool cores and the bola weights.",
    does: ["Tail swings out to the side, the spools spin, the bola unspools and whirls at the tail tip", "The tail whips across and slings the bola at the nearest enemy ahead", "The bola spins through the air (you can see it coming)", "It wraps around the raptor's legs: it trips and stops dead, 12 damage", "Held in place, wire glinting on its legs; then the wire snaps off"],
    nums: "Reach 35 / 45 studs · auto-aims at the nearest enemy within 25° · held 1 / 2 s · 12 damage · recharge 14 s",
    phases: [[0, 0.45, "Wind-up · tail swings out, bola whirls"], [0.45, 0.6, "Throw · the tail whips"], [0.6, 1.05, "Bola flies at the raptor"], [1.05, 1.25, "Wraps its legs: it trips, 12 damage"], [1.25, 3.0, "Held in place"], [3.0, 3.8, "Wire snaps off · raptor runs on"]],
    close: ["Tail3_main", [10, 5, 7]], focus: () => new THREE.Vector3(2, 3, -7), side: [42.0, 9.0, -3.0], three: [30.0, 19.5, 24.0], top: [2, 60, -7],
    update(tt) {
      rig.position.set(0, LY(), 0); rig.rotation.set(0, 0, 0);
      let A = IDLE(tt);
      A = mix(A, BOLA_WIND, easeIO(seg(tt, 0, 0.45)));
      A = mix(A, BOLA_THROW, easeOut(seg(tt, 0.45, 0.6)));
      if (tt > 0.9) A = mix(A, IDLE(tt), easeIO(seg(tt, 0.9, 1.5)));
      pose(A); use = tt > 0.05 && tt < 0.7 ? 1 : 0;
      const tip = centreOf("Tail5_main", [0, 0.3, 1.2]);
      // the raptor runs across ahead; the bola meets it at T
      const T = new THREE.Vector3(5, 0, -20);
      const runDir = new THREE.Vector3(-1, 0, 0.15).normalize();
      const hitT = 1.05;
      const Rp = raptors[0];
      let rpos, trip = 0, run = tt * 10, runAmt = 1;
      if (tt < hitT) rpos = T.clone().addScaledVector(runDir, (tt - hitT) * 9);
      else if (tt < 3.0) { rpos = T.clone().addScaledVector(runDir, Math.min(0.6, (tt - hitT) * 3)); trip = Math.min(1, (tt - hitT) / 0.2) * (tt < 2.6 ? 1 : 1 - (tt - 2.6) / 0.4); run = hitT * 10; runAmt = 0.2; }
      else rpos = T.clone().addScaledVector(runDir, 0.6 + (tt - 3.0) * 9);
      raptorPose(Rp, {pos: rpos, yaw: Math.atan2(runDir.x, runDir.z) + Math.PI, run, runAmt, trip, flash: tt > hitT && tt < hitT + 0.08});
      raptors[1].visible = raptors[2].visible = false;
      // bola: whirl at the tail tip, fly in an arc, wrap
      BOLA.visible = tt > 0.05 && tt < hitT;
      if (tt < 0.55) { const a = tt * 22; BOLA.position.copy(tip).add(new THREE.Vector3(Math.cos(a) * 1.4, 1.2 + Math.sin(a) * 1.4, 0)); BOLA.rotation.set(0, 0, a * 1.5); WIRE.visible = tt > 0.05; if (WIRE.visible) setSeg(WIRE, tip, BOLA.position, 0.05); }
      else if (tt < hitT) { WIRE.visible = false; const u = (tt - 0.55) / (hitT - 0.55); const from = tip.clone().add(new THREE.Vector3(0, 1.2, 0)), to = raptorFeet(Rp).add(new THREE.Vector3(0, 0.6, 0)); BOLA.position.copy(lerpV(from, to, u)).add(new THREE.Vector3(0, Math.sin(u * Math.PI) * 4, 0)); BOLA.rotation.set(0, u * 30, 0); }
      else WIRE.visible = false;
      WRAP.forEach((w, i) => { const on2 = tt > hitT && tt < 3.0; w.visible = on2; if (!on2) return; w.position.copy(Rp.position).add(new THREE.Vector3(0, 0.5 + i * 0.35, 0)); w.rotation.set(Math.PI / 2 + (i % 2 ? 0.4 : -0.4), 0, tt * 0.5); const sc = 1 + (i % 2) * 0.15 - Math.min(1, (tt - hitT) / 0.15) * 0.0; w.scale.setScalar(1.6 * sc * (0.6 + 0.4 * Math.min(1, (tt - hitT) / 0.12))); });
      pop(NUM.n12, Rp.position, tt > hitT ? (tt - hitT) / 0.9 : -1);
      pop(NUM.held, Rp.position.clone().add(new THREE.Vector3(0, 1.2, 0)), tt > 1.4 && tt < 3.0 ? 0.3 : -1);
      puffs(Rp.position, seg(tt, hitT, hitT + 0.6), 1.6, 6);
    } },
  { id: "dash", name: "Dash", get sub() { return DASH_TEXT[dashLook].sub; }, area: "speed", len: 3.2,
    get part() { return DASH_TEXT[dashLook].part; }, get partWhy() { return DASH_TEXT[dashLook].why; },
    get does() { return DASH_TEXT[dashLook].does; },
    nums: "Dashes the way you're moving (stick / WASD; standing still = forward) · 30 / 40 / 50 studs · 2 charges (3 at the star) · recharge 6 / 5 s",
    get phases() { return DASH_TEXT[dashLook].phases; },
    close: () => ({A: ["Torso_body", [11, 3, -4]], B: ["Torso_body", [9, -1, -11]], C: ["ArmL_shoulder", [8, 5, -9]]})[dashLook], focus: () => new THREE.Vector3(rig.position.x * 0.6 + 2, 3, -3), side: [4.5, 9.0, 39.0], three: [25.5, 16.5, 30.0], top: [8, 56, -3],
    update(tt) {
      const D = 20; // 40 studs
      const L = dashLook;
      let k, hop;
      if (L === "B") { k = easeIO(seg(tt, 0.16, 0.28)); hop = 0; }
      else if (L === "C") { k = easeOut(seg(tt, 0.12, 0.45)); hop = Math.sin(seg(tt, 0.12, 0.5) * Math.PI) * 2.4; }
      else { k = easeOut(seg(tt, 0.12, 0.42)); hop = Math.sin(seg(tt, 0.12, 0.42) * Math.PI) * 0.4; }
      const skid = easeOut(seg(tt, L === "B" ? 0.28 : 0.42, 0.8));
      const x = D * k + (L === "B" ? 0.6 : 1.4) * skid;
      rig.position.set(x, hop, 0); rig.rotation.set(0, 0, 0);
      let A = IDLE(tt);
      A = mix(A, DODGE, easeOut(seg(tt, 0.02, 0.14)));
      if (L === "C") A = mix(A, {LegL: [40, 0, 0], LegR: [40, 0, 0], KneeL: [-80, 0, 0], KneeR: [-80, 0, 0]}, Math.sin(seg(tt, 0.12, 0.5) * Math.PI));
      if (tt > 0.42) A = mix(A, SKID, easeOut(seg(tt, 0.42, 0.6)));
      if (tt > 0.75) A = mix(A, IDLE(tt), easeIO(seg(tt, 0.75, 1.2)));
      pose(A); use = tt < 0.6 ? 1 : 0;
      thrustYaw = -Math.PI / 2 * easeOut(seg(tt, 0, 0.1)) * (1 - easeIO(seg(tt, 0.8, 1.1)));
      jetYaw = -Math.PI / 2 * easeOut(seg(tt, 0, 0.1)) * (1 - easeIO(seg(tt, 0.8, 1.1)));
      updateEquip();
      const start = new THREE.Vector3(0, 0, 0), dir = new THREE.Vector3(1, 0, 0);
      if (L === "A" || L === "C") {
        const jets = L === "A" ? ["jetL", "jetR"] : ["jjetL", "jjetR"], pods = L === "A" ? ["podL", "podR"] : ["jpodL", "jpodR"];
        const burn = tt > 0.06 && tt < (L === "A" ? 0.46 : 0.5) ? 1 : 0;
        jets.forEach((role, i) => {
          const n = pieceWorld(role), c = pieceWorld(pods[i]);
          const out = n.clone().sub(c).normalize();
          const len = (L === "A" ? 3.6 : 3.4) * (0.85 + 0.15 * Math.sin(tt * 90 + i)) * burn * (tt < 0.12 ? seg(tt, 0.06, 0.12) : 1);
          flame(i, n, out, len * 1.5, L === "A" ? 1.4 : 0.9);
        });
        if (tt > 0.06 && tt < 0.3) burst(pieceWorld(jets[0]).lerp(pieceWorld(jets[1]), 0.5), seg(tt, 0.06, 0.3), 0xffd34d);
        for (let i = 0; i < 9; i++) { const u = i / 9; const bt = 0.12 + u * 0.3; const kk = seg(tt, bt, bt + 0.8); if (kk > 0 && kk < 1) { const m = PUFFS[i]; m.visible = true; m.material = SMOKE; m.position.set(D * easeOut(u) - 1.5, 1 + (L === "C" ? 2 : 0.3) + kk * 0.8, (i % 3 - 1) * 0.7); m.scale.setScalar(0.8 + kk * 1.8); m.material.opacity = 0.55 * (1 - kk); } }
        if (L === "C" && tt > 0.45 && tt < 1.4) steam(seg(tt, 0.45, 1.4));
      } else { // B: lightning
        const core = pieceWorld("core"), hL = pieceWorld("hornL"), hR = pieceWorld("hornR");
        if (tt < 0.18) { bolt(hL, hR, 9, 0.5, tt); bolt(hL, core, 9, 0.45, tt + 1); bolt(hR, core, 9, 0.45, tt + 2); }
        const flashK = tt > 0.12 && tt < 0.34 ? 1 - Math.abs(seg(tt, 0.12, 0.34) * 2 - 1) : 0;
        dinoFlash(flashK);
        if (tt > 0.16 && tt < 0.45) { const fade = 1 - seg(tt, 0.3, 0.45); bolt(new THREE.Vector3(0, 4, 0), new THREE.Vector3(D, 4, 0), 16, 1.2 * fade + 0.2, Math.floor(tt * 30)); bolt(new THREE.Vector3(0, 1, 0), new THREE.Vector3(D, 1.5, 0), 14, 0.9 * fade + 0.2, Math.floor(tt * 30) + 7); }
        ghosts(tt > 0.16 && tt < 0.5, [0.25, 0.5, 0.75].map(f => new THREE.Vector3(D * f * k, 0, 0)), 1 - seg(tt, 0.3, 0.5));
        if (tt > 0.28 && tt < 0.95) { burst(new THREE.Vector3(x, 0.1, 0), seg(tt, 0.28, 0.95), 0xfff1a8, 6); for (let a = 0; a < 3; a++) { const r = 2 + a; const ang = a * 2.1 + tt * 3; bolt(new THREE.Vector3(x, 3, 0), new THREE.Vector3(x + Math.cos(ang) * r, 0.05, Math.sin(ang) * r), 6, 0.35, Math.floor(tt * 24) + a * 5); } }
      }
      // the raptor on the left fires a dart at where you stood
      const Rp = raptors[0];
      raptorPose(Rp, {pos: new THREE.Vector3(-20, 0, -6), yaw: -Math.PI / 2 + 0.2, run: 0, runAmt: 0});
      raptors[1].visible = raptors[2].visible = false;
      const dk = seg(tt, 0.2, 0.75);
      DART.visible = dk > 0 && dk < 1; if (DART.visible) { DART.position.set(-18 + dk * 40, 3.2, -6 + dk * 5.5); DART.scale.set(2.6, 0.35, 0.35); DART.rotation.y = -0.14; }
    } },
  { id: "hook", name: "Reaper's Hook", sub: "B · Reaper Reel", area: "attack", len: 3.8,
    part: "Reaper Launcher (chest: launcher barrel + reaper claw + chain drum)", partWhy: "Moved off the back onto the chest. The reaper claw sits in the launcher's muzzle; it fires on its chain, clamps on, and the drum under the barrel reels YOU in. Red = attack glow on the chest strips and the muzzle.",
    does: ["Brace: chest out, arms swing wide, the claw opens in the muzzle", "The claw shoots out on its chain at the nearest enemy ahead and clamps on", "The drum reels you in: you fly at it with both claws raised", "You land a big double claw slash: 10 damage", "The claw lets go and reels back into the muzzle"],
    nums: "Reach 50 / 65 / 80 studs · auto-aims at the nearest enemy within 35° · slash 10 · recharge 14 s",
    phases: [[0, 0.3, "Brace · chest out, arms wide, claw opens"], [0.3, 0.52, "Claw flies out and clamps the raptor"], [0.52, 1.0, "Reel · the drum pulls YOU in, claws up"], [1.0, 1.22, "Slash · double claw, 10 damage"], [1.22, 1.8, "Claw lets go, reels back into the chest"], [1.8, 3.8, "—"]],
    close: ["Torso_chest", [8, 2, -12]], focus: () => new THREE.Vector3(rig.position.x * 0.5 + 1, 3, (rig.position.z - 25) * 0.5), side: [42.0, 9.0, -4.5], three: [30.0, 18.0, 21.0], top: [0, 64, -12],
    update(tt) {
      const target = new THREE.Vector3(2.5, 0, -25);
      const stop = target.clone().add(new THREE.Vector3(0, 0, 8.5));
      const reel = easeIn(seg(tt, 0.52, 1.0));
      const root = lerpV(new THREE.Vector3(0, 0, 0), new THREE.Vector3(stop.x * 0.9, 0, stop.z), reel);
      const back = tt > 1.0 ? easeOut(seg(tt, 1.0, 1.4)) * 1.2 : 0;
      rig.position.set(root.x, LY() + Math.sin(reel * Math.PI) * 2.0, root.z - back * 0); rig.rotation.set(0, -Math.atan2(target.x, -target.z) * reel * 0.6, 0);
      let A = IDLE(tt);
      A = mix(A, HOOK_SET, easeIO(seg(tt, 0, 0.3)));
      A = mix(A, REEL, easeIO(seg(tt, 0.5, 0.62)));
      A = mix(A, SLASH_P, easeOut(seg(tt, 0.98, 1.12)));
      if (tt > 1.25) A = mix(A, IDLE(tt), easeIO(seg(tt, 1.25, 1.8)));
      pose(A);
      hookDrumSpin = tt > 0.3 && tt < 1.8 ? (tt - 0.3) * (tt < 1.0 ? -18 : 12) : 0;
      use = tt < 1.3 ? 1 : 0;
      const Rp = raptors[0];
      const hit = tt > 1.02;
      raptorPose(Rp, {pos: hit ? target.clone().add(new THREE.Vector3(0, 0, -easeOut(seg(tt, 1.02, 1.3)) * 2)) : target, yaw: 0.2, run: tt * 3, runAmt: tt < 0.4 ? 0.3 : 0, trip: hit ? (1 - seg(tt, 1.5, 2.2)) * 0.5 : 0, flash: (tt > 0.5 && tt < 0.56) || (tt > 1.02 && tt < 1.12)});
      raptors[1].visible = raptors[2].visible = false;
      // chain from the jib tip to the claw
      updateEquip();
      const jib = pieceWorld("muzzle", "Torso_chest");
      const grip = target.clone().add(new THREE.Vector3(0, 2.8, 0.6));
      clawOut = tt > 0.3 && tt < 1.5;
      if (tt <= 0.3 || tt >= 1.5) { claw.visible = false; chainOff(); }
      else if (tt < 0.52) { const p = lerpV(jib, grip, easeOut(seg(tt, 0.3, 0.52))); clawAt(p, grip.clone().sub(jib), 1); chain(jib, p); }
      else if (tt < 1.22) { clawAt(grip, grip.clone().sub(jib), 0); chain(jib, grip); }
      else { const u = easeIn(seg(tt, 1.22, 1.5)); const p = lerpV(grip, jib, u); clawAt(p, grip.clone().sub(jib), u); chain(jib, p); }
      SLASH.forEach((s, i) => { const k = seg(tt, 1.0, 1.25); s.visible = k > 0 && k < 1; if (!s.visible) return; const c = rig.position.clone().add(new THREE.Vector3(0, 4, -7)); s.position.copy(c); s.rotation.set(0.4, (i ? 1 : -1) * 0.5, (i ? -1 : 1) * (0.6 + k * 2.2)); s.material.opacity = 0.9 * (1 - k); });
      pop(NUM.n10, Rp.position, tt > 1.05 ? (tt - 1.05) / 0.9 : -1);
      SPEED.forEach((m, i) => { const on2 = tt > 0.6 && tt < 1.0; m.visible = on2; if (!on2) return; m.position.set(rig.position.x - 2 + (i % 5) * 1.0, 2 + (i * 1.3) % 5, rig.position.z + 4 + (i * 1.1) % 4); m.scale.set(0.06, 0.06, 3); });
      puffs(new THREE.Vector3(rig.position.x, 0, rig.position.z - 3), seg(tt, 1.0, 1.6), 2.2, 8);
    } },
];

// ---------- UI ----------
let cur = 0, playing = true, speed = 1, view = "three", tt = 0;
function renderMoves() {
  $("moves").innerHTML = MOVES.map((m, i) => `<button class="tab" data-i="${i}" aria-pressed="${i === cur}">${m.name}<small style="color:${AREA[m.area][1]}">${m.sub}</small></button>`).join("");
  const m = MOVES[cur];
  $("phases").innerHTML = m.phases.filter(p => p[2] !== "—").map((p, i) => `<button class="ph" data-t="${p[0]}" aria-current="false"><i>${p[0].toFixed(2)}–${p[1].toFixed(2)} s</i>${p[2]}</button>`).join("");
  $("info").innerHTML = `<div class="kind" style="color:${AREA[m.area][1]}">${AREA[m.area][0]} · ${m.name} · ${m.sub}</div><h2>What you see, in order</h2><ul>${m.does.map(d => `<li>${d}</li>`).join("")}</ul><p class="note">${m.nums}</p>`;
  $("part").innerHTML = `<div class="kind" style="color:${AREA[m.area][1]}">The part that does it</div><h2>${m.part}</h2><p class="note">${m.partWhy}</p>`;
  $("sizeRow").hidden = m.id !== "harvest";
  $("dashRow").hidden = m.id !== "dash";
  document.querySelectorAll("[data-dash]").forEach(x => x.setAttribute("aria-pressed", x.dataset.dash === dashLook));
}
$("moves").addEventListener("click", e => { const b = e.target.closest("[data-i]"); if (!b) return; cur = +b.dataset.i; tt = 0; fxOff(); renderMoves(); });
$("phases").addEventListener("click", e => { const b = e.target.closest("[data-t]"); if (!b) return; tt = +b.dataset.t + 0.06; playing = false; syncPlay(); });
$("play").onclick = () => { playing = !playing; syncPlay(); };
function syncPlay() { $("play").textContent = playing ? "Pause" : "Play"; $("play").setAttribute("aria-pressed", playing); }
document.querySelectorAll("[data-speed]").forEach(b => b.onclick = () => { speed = +b.dataset.speed; document.querySelectorAll("[data-speed]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => { view = b.dataset.view; document.querySelectorAll("[data-view]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
document.querySelectorAll("[data-size]").forEach(b => b.onclick = () => { ringStuds = +b.dataset.size; document.querySelectorAll("[data-size]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
document.querySelectorAll("[data-dash]").forEach(b => b.onclick = () => { dashLook = b.dataset.dash; buildRig(); tt = 0; fxOff(); renderMoves(); });
$("scrub").addEventListener("input", e => { tt = +e.target.value / 1000 * MOVES[cur].len; playing = false; syncPlay(); });
renderMoves();

// ---------- loop ----------
let lastNow = performance.now(), camPos = new THREE.Vector3(20, 14, 16), camLook = new THREE.Vector3(0, 2, -4);
function frameM(now) {
  const dt = Math.min(0.05, (now - lastNow) / 1000); lastNow = now; t += dt;
  const m = MOVES[cur];
  if (playing) { tt += dt * speed; if (tt > m.len) { tt = 0; fxOff(); } }
  fxOff(); raptors.forEach(r => r.visible = true);
  boomA = 0; clawOut = false; harpoonOut = false; thrustYaw = 0; jetYaw = 0; burstIdx = 0; dinoFlash(0);
  m.update(tt);
  updateEquip();
  $("scrub").value = Math.round(tt / m.len * 1000);
  $("clock").textContent = `${tt.toFixed(2)} s${speed !== 1 ? " · 0.3×" : ""}`;
  const ph = m.phases.find(p => tt >= p[0] && tt < p[1] && p[2] !== "—");
  $("cap").textContent = ph ? ph[2] : "…";
  document.querySelectorAll(".ph").forEach(b => b.setAttribute("aria-current", ph && +b.dataset.t === ph[0]));
  // camera
  const f = m.focus();
  let goalPos, goalLook;
  if (view === "game") { // ShoulderCam: behind-right of the dino, looking ahead
    const top = 8, h = rig.rotation.y;
    const off = new THREE.Vector3(0.9 * top + 0.5, 0.75 * top + 0.35 * top + 2, 26).applyAxisAngle(UP, h); // pulled back a little to match the game's framing in Studio
    goalPos = rig.position.clone().setY(-(restMinY || 0)).add(off); // the redesign mockup's ShoulderCam framing (its height includes the rest lift)
    goalLook = goalPos.clone().add(new THREE.Vector3(0, -1.2, -10).applyAxisAngle(UP, h));
  } else if (view === "close") { // the part itself, up close (follows the dino)
    const c = typeof m.close === "function" ? m.close() : m.close;
    goalLook = centreOf(c[0]); goalPos = goalLook.clone().add(new THREE.Vector3(...c[1]));
  } else if (view === "top") { const o = m.top; goalPos = new THREE.Vector3(o[0], o[1], o[2] + 0.01); goalLook = new THREE.Vector3(o[0], 0, o[2]); }
  else { const o = m[view]; goalPos = f.clone().add(new THREE.Vector3(o[0], o[1], o[2])); goalLook = f; }
  const kk = 1 - Math.pow(0.001, dt);
  camPos.lerp(goalPos, kk); camLook.lerp(goalLook, kk);
  cam.position.copy(camPos); cam.lookAt(camLook);
  resize(); renderer.render(scene, cam);
  requestAnimationFrame(frameM);
}
requestAnimationFrame(frameM);
