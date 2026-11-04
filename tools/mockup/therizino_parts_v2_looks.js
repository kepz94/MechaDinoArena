// One-sided parts go on the dino's RIGHT = +X = the model's "...L" parts (the L / R names are mirrored): ShoulderCam 1.8 starts
// over the right shoulder, shoulder = focus + RightVector x side, and a dino facing -Z has RightVector = +X.
// Therizino parts redesign v0.3 — the looks (v0.3: export tags only on the 7 picked looks: group / role / detail; no visual change). Coordinates: rest model space (scale 1, HRP frame; front = -Z, left = +X).
// Each look: mounts on body parts (mount = world-aligned, mountOn = in the part's frame, mountM(axisFrame) = along a limb).
const V3 = (x, y, z) => new THREE.Vector3(x, y, z);
const SIDES = [[1, "L"], [-1, "R"]];
const sinc = (u, k) => Math.sin(t * k) * u;
const loop = (period) => (t % period) / period; // 0..1 sawtooth
// limb frames: forearm (Y elbow -> hand, Z = top of the arm, x = s outward)
function foreFrame(s, dy) { return axisFrame([s * 3.89 + s * 0.64 * (dy || 0), 0.12 - 0.24 * (dy || 0), -2.81 - 0.73 * (dy || 0)], [s * 0.64, -0.24, -0.73], [1, 0, 0]); }
// band of 4 thin boxes around a limb running along local Y (w = x size, d = z size)
function bandY(M, w, d, len, p, key) {
  const th = 0.06; key = key || "trim";
  M.box([w + th * 2, len, th], [p[0], p[1], p[2] + d / 2 + th / 2], null, key); M.box([w + th * 2, len, th], [p[0], p[1], p[2] - d / 2 - th / 2], null, key);
  M.box([th, len, d], [p[0] + w / 2 + th / 2, p[1], p[2]], null, key); M.box([th, len, d], [p[0] - w / 2 - th / 2, p[1], p[2]], null, key);
}
// chain of n alternating links along local Y from y0 (link length L)
function chainY(M, x, y0, z, n, L, o) { for (let i = 0; i < n; i++) M.box(i % 2 ? [0.07, L, 0.2] : [0.2, L, 0.07], [x, y0 + i * L * 0.8, z], null, "steel", o ? o(i) : undefined); }
// a flanged drum along local X at p (dia, width): steel core, cable wrap, brass flanges; spin(u, t) -> angle
function drumX(M, p, dia, w, wrapKey, spin, g) { // g (v0.3 export) = {name, speed}: the spinning pieces form a group spinning about local X
  const gn = g ? M.group(g.name, Tm(...p), {type: "spin", axis: "X", amt: g.speed}) : undefined;
  const sp = spin ? {anim: (u, tt) => RYm(spin(u, tt)), group: gn, role: g && "drum"} : undefined;
  M.cyl([dia * 0.8, w, 0], p, [90, 0, 0], wrapKey || "rubber", sp);
  for (let k = 0; k < 4; k++) M.box([w * 0.98, 0.06, dia * 0.82], p, [0, 0, k * 45], "iron", spin ? {anim: (u, tt) => RXm(spin(u, tt)), group: gn} : undefined); // cable wrap ribs (spin with it)
  for (const e of [-1, 1]) M.cyl([dia, 0.07, 0], [p[0] + e * (w / 2 + 0.035), p[1], p[2]], [90, 0, 0], "brass", sp);
  M.cyl([dia * 0.3, w + 0.25, 0], p, [90, 0, 0], "steel");
}
// three-prong grapnel / claw at p pointing along local -Z (fwd) when r = 0; open(u) = how far the prongs open (0..1)
function grapnel(M, p, size, open, key, gx) { // gx (v0.3 export): prefix for the 3 prong groups (swing about X, -45 deg at full open)
  M.ball(size * 0.45, p, "brass");
  M.cyl([size * 0.22, size * 0.7, 0], [p[0], p[1], p[2] + size * 0.35], [0, 0, 90], "steel");
  for (let k = 0; k < 3; k++) {
    const a = k * 120;
    const pl = (u) => new THREE.Matrix4().makeTranslation(...p).multiply(rot(0, 0, 0)).multiply(RZm(rad(a))).multiply(RXm(-rad(15 + 45 * open(u)))).multiply(Tm(0, size * 0.15, -size * 0.45));
    const gn = gx ? M.group(gx + (k + 1), new THREE.Matrix4().makeTranslation(...p).multiply(RZm(rad(a))).multiply(RXm(-rad(15))), {type: "swing", axis: "X", amt: -45}) : undefined;
    M.box([size * 0.14, size * 0.18, size * 0.9], [0, 0, 0], null, key || "bone", {place: (u) => pl(u), group: gn, role: gx && "prong"});
    M.box([size * 0.14, size * 0.5, size * 0.16], [0, 0, 0], null, key || "bone", {place: (u) => pl(u).multiply(Tm(0, -size * 0.18, -size * 0.45)).multiply(RXm(rad(25))), group: gn, role: gx && "prong"});
  }
}
const POSES = {
  ARMS_FWD: {ArmL: [62, 0, 8], ArmR: [62, 0, -8], RootJoint: [-6, 0, 0]},
  ARM_R_FWD: {ArmR: [70, 0, -6], ArmL: [10, 0, 0], RootJoint: [-6, 0, 0], Neck: [-4, 0, 0]},
  ARM_L_FWD: {ArmL: [70, 0, 6], ArmR: [10, 0, 0], RootJoint: [-6, 0, 0], Neck: [-4, 0, 0]},
  STAB: {ArmL: [-10, 0, 10], ArmR: [-10, 0, -10], RootJoint: [-22, 0, 0], Neck: [-14, 0, 0], Head: [-8, 0, 0], LegL: [22, 0, 0], LegR: [22, 0, 0], KneeL: [-30, 0, 0], KneeR: [-30, 0, 0], AnkleL: [10, 0, 0], AnkleR: [10, 0, 0], Tail1: [-14, 0, 0]},
  SWEEP: {ArmL: [55, -50, -30], ArmR: [55, 50, 30], RootJoint: [-4, 0, 0]},
  HOOK_AIM: {RootJoint: [-4, 0, 0], Neck: [-10, 0, 0]},
  TAIL_FLICK: {Tail1: [-30, 0, 0], Tail2: [-30, 0, 0], Tail3: [-25, 0, 0], Tail4: [-20, 0, 0], Tail5: [-15, 0, 0], RootJoint: [-8, 0, 0]},
  CHEST_OUT: {RootJoint: [-8, 0, 0], Neck: [-12, 0, 0], ArmL: [20, 0, 10], ArmR: [20, 0, -10]},
};
function RUN(tt) { const ph = tt * 11, s = Math.sin(ph), c = Math.cos(ph);
  return {RootJoint: [-10, 0, s * 3], LegL: [s * 34, 0, 0], LegR: [-s * 34, 0, 0], KneeL: [-Math.max(0, c) * 50 - 8, 0, 0], KneeR: [-Math.max(0, -c) * 50 - 8, 0, 0],
    AnkleL: [Math.max(0, c) * 20, 0, 0], AnkleR: [Math.max(0, -c) * 20, 0, 0], ArmL: [20 - s * 12, 0, 0], ArmR: [20 + s * 12, 0, 0], Neck: [-6, 0, 0], Tail1: [8, s * 4, 0], Tail2: [0, s * 4, 0]}; }
// the back saddle (on Torso_body, tilted with the back): local Y = out of the back, -Z = toward the head along the spine
const BACK = () => new THREE.Matrix4().makeTranslation(0, 2.2, -0.55).multiply(rot(0, 0, 35));

// ============================================ 1 · REAPER'S HOOK ============================================
function hookGauntlet() {
  const s = 1, M = mountM("ArmL_fore", foreFrame(s));
  // armoured sleeve wrapping the forearm
  M.box([0.66, 1.45, 0.62], [0, -0.05, 0], null, "shell");
  M.box([0.74, 1.25, 0.14], [0, 0.0, 0.39], null, "plate");
  M.wedge([0.74, 0.2, 0.4], [0, 0.72, 0.36], [0, 180, 0], "plate");
  for (const e of [-1, 1]) M.box([0.12, 1.1, 0.5], [e * 0.38, -0.05, 0.02], null, "plate");
  bandY(M, 0.66, 0.62, 0.12, [0, -0.62, 0]); bandY(M, 0.66, 0.62, 0.12, [0, 0.5, 0]);
  for (const [x, y] of [[-0.26, -0.45], [0.26, -0.45], [-0.26, 0.45], [0.26, 0.45]]) M.bolt([x, y, 0.47], "z", 0.11);
  M.box([0.2, 0.55, 0.05], [0, 0.05, 0.47], null, "glow");
  // harpoon barrel under the arm, past the hand
  M.cyl([0.36, 2.1, 0], [0, 0.9, -0.48], null, "iron");
  M.box([0.5, 1.0, 0.42], [0, 0.1, -0.44], null, "shell");
  M.cyl([0.5, 0.2, 0], [0, 1.95, -0.48], null, "brass");
  M.cyl([0.42, 0.05, 0], [0, 2.07, -0.48], null, "glow", {role: "muzzle"});
  for (let i = 0; i < 4; i++) M.box([0.08, 0.16, 0.08], [Math.cos(i * Math.PI / 2) * 0.27, 1.95, -0.48 + Math.sin(i * Math.PI / 2) * 0.27], null, i % 2 ? "hazK" : "hazY", {detail: true});
  // chain drum at the elbow (outer side)
  drumX(M, [s * 0.52, -0.5, 0.05], 0.85, 0.34, "steel", (u, tt) => u * tt * 14, {name: "drum", speed: 14});
  // the hook: a big reaper sickle loaded in the muzzle; fired = flies out on its chain and back
  const out = (u) => u * Math.max(0, Math.sin(loop(1.6) * Math.PI)) * 2.6;
  const H = (u) => Tm(0, 2.25 + out(u), -0.48);
  M.cyl([0.2, 0.55, 0], [0, 0, 0], null, "steel", {place: u => H(u), role: "hookhead"});
  M.box([0.5, 0.14, 0.14], [0, 0, 0], null, "brass", {place: u => H(u).multiply(Tm(0, 0.22, 0)), role: "hookhead"});
  const blade = [[0.36, 0.26, -0.05, 0, 0.62], [0.32, 0.5, -0.32, -40, 0.5], [0.26, 0.48, -0.66, -85, 0.42], [0.2, 0.28, -0.88, -125, 0.32]];
  for (const [w, y, z, a, L] of blade) M.box([0.1, L, w], [0, 0, 0], null, "bone", {place: u => H(u).multiply(Tm(0, y, z)).multiply(RXm(rad(a))), role: "hookhead"});
  M.box([0.11, 0.6, 0.06], [0, 0, 0], null, "glow", {place: u => H(u).multiply(Tm(0, 0.42, -0.2)).multiply(RXm(rad(-40))), role: "hookhead"});
  for (let i = 0; i < 10; i++) M.box(i % 2 ? [0.06, 0.24, 0.16] : [0.16, 0.24, 0.06], [0, 0, 0], null, "steel", {place: u => Tm(0, 2.1 + out(u) * (i + 0.5) / 10, -0.48), show: u => out(u) > 0.2});
  M.hose([0, -0.72, -0.25], [0.1, -1.1, -0.6], 0.15, 0.14, 4);
  cable("ArmL_fore", M.toRest([-0.1, -1.1, -0.6]), "ArmL_upper", [2.6, 1.25, -2.15], 0.2, 0.14);
}
function hookCrane() {
  const S = mountM("Torso_body", BACK());
  // saddle on the back + side skirts
  S.box([1.7, 0.22, 2.2], [0, 0, 0], null, "shell");
  for (const e of [-1, 1]) { S.box([0.16, 0.6, 1.9], [e * 0.9, -0.25, 0], null, "plate"); S.box([0.18, 0.12, 2.0], [e * 0.95, -0.55, 0], null, "trim"); }
  for (const z of [-0.8, 0.8]) S.box([1.95, 0.1, 0.16], [0, -0.05, z], null, "trim");
  for (const [x, z] of [[-0.6, -0.9], [0.6, -0.9], [-0.6, 0.9], [0.6, 0.9]]) S.bolt([x, 0.12, z], "y", 0.13);
  // turret
  S.cyl([1.25, 0.18, 0], [0, 0.2, 0.3], null, "brass");
  S.box([1.05, 0.65, 1.15], [0, 0.6, 0.35], null, "shell");
  S.wedge([1.05, 0.4, 0.5], [0, 0.6, -0.48], null, "plate");
  S.box([0.5, 0.18, 0.05], [0, 0.72, -0.25], [0, 0, -35], "glow");
  drumX(S, [0.72, 0.62, 0.45], 0.8, 0.32, "steel", (u, tt) => u * tt * 10, {name: "drum", speed: 10});
  S.hazard(1.05, 0.08, [0, 0.98, -0.25], null, 6);
  // boom: lower arm on a hinge (rises / dips when used), piston, jib to the front, chain + reaper claw at the tip
  const lift = u => -0.35 * u * Math.max(0, Math.sin(loop(1.6) * Math.PI));
  const B = u => Tm(0, 0.95, 0.5).multiply(RXm(rad(-24) + lift(u)));
  const gb = S.group("boom", B(0), {type: "swing", axis: "X", amt: -20}); // v0.5 export: the boom dips 20 deg when used
  const bo = (role) => ({group: gb, role});
  S.cyl([0.36, 0.95, 0], [0, 0, 0], null, "brass", {place: u => B(u).multiply(RZm(Math.PI / 2)), ...bo()});
  S.box([0.42, 3.9, 0.42], [0, 0, 0], null, "shell", {place: u => B(u).multiply(Tm(0, 1.95, 0)), ...bo()});
  S.box([0.5, 3.0, 0.14], [0, 0, 0], null, "plate", {place: u => B(u).multiply(Tm(0, 1.9, -0.26)), ...bo()});
  S.cyl([0.2, 1.6, 0], [0, 0, 0], null, "steel", {place: u => B(u).multiply(Tm(0, 1.2, 0.42)).multiply(RXm(rad(-10))), ...bo()});
  S.cyl([0.3, 1.1, 0], [0, 0, 0], null, "iron", {place: u => B(u).multiply(Tm(0, 0.35, 0.45)).multiply(RXm(rad(-10))), ...bo()});
  const J = u => B(u).multiply(Tm(0, 3.9, 0)).multiply(RXm(rad(-58)));
  S.cyl([0.46, 0.6, 0], [0, 0, 0], null, "brass", {place: u => B(u).multiply(Tm(0, 3.9, 0)).multiply(RZm(Math.PI / 2)), ...bo()});
  S.box([0.36, 2.2, 0.36], [0, 0, 0], null, "shell", {place: u => J(u).multiply(Tm(0, 1.1, 0)), ...bo()});
  S.box([0.42, 1.6, 0.1], [0, 0, 0], null, "plate", {place: u => J(u).multiply(Tm(0, 1.0, 0.22)), ...bo()});
  S.cyl([0.5, 0.3, 0], [0, 0, 0], null, "steel", {place: u => J(u).multiply(Tm(0, 2.2, 0)).multiply(RZm(Math.PI / 2)), ...bo("jib")});
  S.box([0.14, 0.4, 0.06], [0, 0, 0], null, "glow", {place: u => J(u).multiply(Tm(0, 2.0, 0.24)), ...bo()});
  // hanging chain and the claw (always hangs straight down in the boom's plane)
  const tipM = u => J(u).multiply(Tm(0, 2.2, 0));
  const down = u => { const m = tipM(u); const inv = new THREE.Matrix4().extractRotation(m).invert(); return m.multiply(inv); };
  const gc = S.group("claw", down(0), {type: "swing", axis: "X", amt: 0}, gb); // hangs from the jib tip (rides the boom)
  for (let i = 0; i < 4; i++) S.box(i % 2 ? [0.06, 0.26, 0.18] : [0.18, 0.26, 0.06], [0, 0, 0], null, "steel", {place: u => down(u).multiply(Tm(0, -0.25 - i * 0.22, 0)), group: gc, role: "hookhead"});
  const C = u => down(u).multiply(Tm(0, -1.2, 0)).multiply(rot(0, 0, 90));
  S.ball(0.42, [0, 0, 0], "brass", {place: u => C(u), group: gc, role: "hookhead"});
  for (let k = 0; k < 3; k++) {
    const pr = u => C(u).multiply(RZm(rad(k * 120))).multiply(RXm(-rad(20 + 40 * u))).multiply(Tm(0, 0.2, -0.45));
    const gp = S.group(`prong_${k + 1}`, C(0).multiply(RZm(rad(k * 120))).multiply(RXm(-rad(20))), {type: "swing", axis: "X", amt: -40}, gc);
    S.box([0.12, 0.16, 0.85], [0, 0, 0], null, "bone", {place: pr, group: gp, role: "hookhead"});
    S.box([0.12, 0.45, 0.14], [0, 0, 0], null, "bone", {place: u => pr(u).multiply(Tm(0, -0.18, -0.42)).multiply(RXm(rad(28))), group: gp, role: "hookhead"});
  }
  S.hose([-0.5, 0.35, 0.8], [-0.85, -0.2, 1.3], 0.2, 0.15, 5);
}
function oldHook() { const M = mount("Torso_body", [0, 0, 0]);
  M.box([1.6, 0.8, 1.6], [0, 2.45, -0.6], null, "trim"); M.box([0.6, 4.4, 0.6], [0, 4.5, -1.4], [0, 0, -28], "steel"); M.box([0.7, 0.7, 2.6], [0, 6.6, -3.2], null, "brass"); M.cyl([0.9, 0.9, 0], [0, 2.95, -0.6], [0, 0, 90], "steel"); }

// ============================================ 3 · FEATHER BARRAGE ============================================
function featherWings() {
  for (const [s, side] of SIDES) {
    const M = mountM(`Arm${side}_fore`, foreFrame(s));
    // magazine housing on the forearm (blade feathers hang off its outer edge like wing feathers)
    M.box([0.6, 1.4, 0.6], [0, -0.05, 0.02], null, "shell");
    M.box([0.66, 1.2, 0.13], [0, -0.05, 0.38], null, "plate");
    bandY(M, 0.6, 0.6, 0.12, [0, -0.6, 0.02]); bandY(M, 0.6, 0.6, 0.12, [0, 0.55, 0.02]);
    M.box([0.16, 1.55, 0.18], [s * 0.38, -0.05, -0.18], null, "brass");
    for (let i = 0; i < 6; i++) M.cyl([0.12, 0.1, 0], [s * 0.46, -0.65 + i * 0.24, -0.2], [0, 0, 90], "iron");
    M.box([0.06, 0.9, 0.05], [s * 0.34, -0.05, 0.42], null, "glow");
    // 6 blade feathers: long bone wedges trailing back and down; when used they fan out and their edges light
    for (let i = 0; i < 6; i++) {
      const y = -0.62 + i * 0.24, L = 1.1 + i * 0.12;
      const open = u => u * (0.75 + 0.25 * Math.sin(t * 6)); // fanned out while used, edges quiver
      const F = u => Tm(s * 0.46, y, -0.2).multiply(RXm(rad(-(20 + (5 - i) * 5) - open(u) * (5 - i) * 11 + open(u) * 8)));
      const gn = M.group(`blade_${side}${i + 1}`, F(0), {type: "swing", axis: "X", amt: -(5 - i) * 11 + 8});
      M.box([0.06, 0.26, L], [0, 0, 0], null, "bone", {place: u => F(u).multiply(Tm(0, 0, -L / 2)), group: gn, role: "blade"});
      M.wedge([0.06, 0.26, 0.3], [0, 0, 0], null, "bone", {place: u => F(u).multiply(Tm(0, 0, -L - 0.15)).multiply(rot(0, 180, 0)), group: gn, role: "blade"});
      M.box([0.07, 0.04, L * 0.9], [0, 0, 0], null, "glow", {place: u => F(u).multiply(Tm(0, 0.14, -L / 2)), group: gn, role: "blade"});
    }
    M.hose([0, -0.7, -0.25], [s * 0.05, -1.05, -0.55], 0.1, 0.13, 3);
  }
}
function featherFins() {
  const S = mountM("Torso_body", BACK());
  S.box([1.5, 0.22, 1.9], [0, 0, 0.1], null, "shell");
  for (const e of [-1, 1]) S.box([0.16, 0.55, 1.6], [e * 0.8, -0.22, 0.1], null, "plate");
  S.box([1.1, 0.45, 0.9], [0, 0.32, 0.55], null, "shell");
  S.cyl([0.55, 1.2, 0], [0, 0.45, 0.2], [0, 0, 90], "brass");
  S.box([0.5, 0.06, 0.4], [0, 0.56, 0.55], null, "glow");
  S.hazard(1.1, 0.08, [0, 0.4, 0.07], null, 6);
  // 6 L-shaped fin blades folded like a closed fan / dorsal crest; used = fan spreads and tips forward
  for (let i = 0; i < 6; i++) {
    const a0 = -38 + i * 15.2, L = 2.5 - Math.abs(i - 2.5) * 0.18;
    const F = u => Tm(0, 0.45, 0.2).multiply(RZm(rad(a0 * (0.35 + 0.9 * u)))).multiply(RXm(rad(-14 - 30 * u)));
    S.box([0.1, L, 0.34], [0, 0, 0], null, "bone", {place: u => F(u).multiply(Tm(0, L / 2 + 0.3, 0))});
    S.box([0.1, 0.34, 0.6], [0, 0, 0], null, "bone", {place: u => F(u).multiply(Tm(0, L + 0.3, -0.13))});
    S.box([0.11, L * 0.85, 0.05], [0, 0, 0], null, "glow", {place: u => F(u).multiply(Tm(0, L / 2 + 0.35, -0.19))});
    S.box([0.16, 0.36, 0.42], [0, 0, 0], null, "iron", {place: u => F(u).multiply(Tm(0, 0.35, 0))});
  }
}
function oldFeather() { for (const [s, side] of SIDES) { const M = mount(`Arm${side}_fore`, [0, 0, 0]); M.box([0.35, 1.7, 0.75], [s * 4.15, 0.2, -2.8], null, "trim"); for (let k = 0; k < 6; k++) M.box([0.08, 0.18, 1.1], [s * 4.35, -0.45 + k * 0.26, -2.8], null, "bone"); } }

// ============================================ 5 · HARVEST FIELD ============================================
function harvestPiles() {
  for (const [s, side] of SIDES) {
    const M = mountM(`Arm${side}_fore`, foreFrame(s));
    // the bunker: boxy studded housing under the forearm, heat fins, slide valve, the pile and its wedge tip
    M.box([0.62, 1.4, 0.58], [0, -0.05, 0.03], null, "shell");
    bandY(M, 0.62, 0.58, 0.12, [0, -0.6, 0.03]); bandY(M, 0.62, 0.58, 0.12, [0, 0.55, 0.03]);
    M.box([0.78, 1.3, 0.62], [0, 0.0, -0.58], null, "shell");
    M.box([0.84, 0.16, 0.66], [0, 0.66, -0.58], null, "brass");
    for (let i = 0; i < 5; i++) M.box([0.34, 0.07, 0.56], [s * 0.55, -0.45 + i * 0.2, -0.56], null, "iron");
    M.box([0.3, 0.3, 0.3], [-s * 0.5, -0.45, -0.62], null, "plate");
    M.hazard(0.62, 0.07, [0, 0.4, -0.91], [0, 0, 0], 6);
    M.box([0.5, 0.06, 0.05], [0, 0.66, -0.92], null, "glow");
    M.box([0.06, 0.9, 0.05], [s * 0.4, -0.1, -0.9], null, "glow");
    const ram = u => u * Math.pow(Math.max(0, Math.sin(loop(0.9) * Math.PI * 2)), 0.4) * 0.9;
    const gp = M.group(`pile_${side}`, Tm(0, 1.15, -0.58), {type: "slide", axis: "Y", amt: 0.9});
    M.cyl([0.3, 1.6, 0], [0, 0, 0], null, "steel", {place: u => Tm(0, 1.15 + ram(u), -0.58), group: gp, role: "pile"});
    M.cyl([0.42, 0.14, 0], [0, 0, 0], null, "iron", {place: u => Tm(0, 1.92 + ram(u), -0.58), group: gp, role: "pile"});
    M.add("cone", [0.34, 0.6, 0], [0, 0, 0], null, "steel", {place: u => Tm(0, 2.25 + ram(u), -0.58), group: gp, role: "pile"});
    M.hose([0, -0.72, -0.3], [s * 0.1, -1.05, -0.65], 0.1, 0.14, 3);
  }
}
function harvestSleeves(opt) { // v0.4: opt.fore = false leaves the forearm (wrist cuffs + claw sleeves only)
  const fore = !(opt && opt.fore === false);
  for (const [s, side] of SIDES) {
    // steel sleeves on the 3 claws (segments b and c), a serrated red edge, a wrist cuff with a piston from the forearm
    for (let c = 1; c <= 3; c++) {
      for (const [seg, k] of [["b", 1.0], ["c", 0.9]]) {
        const part = `Arm${side}_claw${c}${seg}`, sz = theri.byName[part].size;
        const M = mountOn(part);
        M.box([sz[0] * 1.5, sz[1] * 0.92, sz[2] * 1.7], [0, 0, 0], null, "iron");
        M.box([sz[0] * 1.6, sz[1] * 0.08, sz[2] * 1.8], [0, sz[1] * 0.42, 0], null, "brass");
        for (let i = 0; i < 3; i++) M.wedge([sz[0] * 1.2, 0.16, 0.14], [0, -sz[1] * 0.3 + i * sz[1] * 0.28, -sz[2] * 0.85 - 0.06], [0, 0, 0], "steel");
        M.box([sz[0] * 0.5, sz[1] * 0.78, 0.05], [0, 0, -sz[2] * 0.87 - 0.13], null, "glow");
      }
    }
    const H = mountOn(`Arm${side}_hand`);
    H.box([0.86, 0.36, 0.84], [0, 0.12, 0], null, "shell");
    H.box([0.9, 0.08, 0.88], [0, 0.33, 0], null, "brass");
    H.box([0.3, 0.06, 0.3], [0, 0.38, 0], null, "glow");
    if (!fore) continue;
    const M = mountM(`Arm${side}_fore`, foreFrame(s));
    M.box([0.56, 1.2, 0.5], [0, -0.1, 0.05], null, "shell");
    bandY(M, 0.56, 0.5, 0.1, [0, -0.55, 0.05]);
    M.cyl([0.24, 1.0, 0], [0, 0.3, 0.42], null, "iron");
    M.cyl([0.14, 0.9, 0], [0, 0, 0], null, "steel", {place: u => Tm(0, 0.95 + u * 0.12 * Math.sin(t * 20), 0.42)});
    M.box([0.06, 0.8, 0.04], [s * 0.3, -0.1, 0.32], null, "glow");
  }
}
function oldHarvest() { for (const [s, side] of SIDES) { const M = mount(`Arm${side}_fore`, [0, 0, 0]); M.box([0.7, 1.5, 0.7], [s * 4.25, 0.2, -2.7], null, "trim"); M.cyl([0.4, 2.2, 0], [s * 4.25, -0.9, -2.7], null, "steel"); M.box([0.9, 0.3, 0.9], [s * 4.25, -2.1, -2.7], null, "brass"); } }

// ============================================ 12 · GRAPPLE ZIP ============================================
function grappleODM() {
  // twin anchor launchers on the hips (ODM gear), two gas tanks on the lower back, hoses between them
  for (const [s, side] of SIDES) {
    const M = mount(`Leg${side}_haunch`, [s * 1.55, -0.35, -0.25]);
    M.box([0.14, 1.0, 1.15], [-s * 0.18, 0, 0.15], null, "plate");
    M.box([0.12, 0.12, 1.3], [-s * 0.2, 0.55, 0.15], null, "trim"); M.box([0.12, 0.12, 1.3], [-s * 0.2, -0.55, 0.15], null, "trim");
    M.box([0.5, 0.62, 1.0], [s * 0.12, 0, 0.05], null, "shell");
    drumX(M, [s * 0.12, 0.05, 0.62], 0.85, 0.42, "steel", (u, tt) => u * tt * 18);
    M.cyl([0.34, 1.3, 0], [s * 0.12, 0, -0.85], [0, 0, 90], "iron");
    M.cyl([0.46, 0.16, 0], [s * 0.12, 0, -1.45], [0, 0, 90], "brass");
    M.cyl([0.36, 0.05, 0], [s * 0.12, 0, -1.55], [0, 0, 90], "glow");
    M.box([0.08, 0.5, 0.06], [s * 0.38, 0.0, -0.3], null, "glow");
    const out = u => u * Math.max(0, Math.sin(loop(1.4) * Math.PI)) * 1.8;
    const A = u => Tm(s * 0.12, 0, -1.75 - out(u)).multiply(rot(0, 0, 90));
    M.add("cone", [0.3, 0.45, 0], [0, 0, 0], null, "steel", {place: u => A(u).multiply(RXm(Math.PI)).multiply(Tm(0, 0.1, 0))});
    for (let k = 0; k < 3; k++) M.box([0.07, 0.36, 0.1], [0, 0, 0], null, "bone", {place: u => A(u).multiply(RYm(rad(k * 120))).multiply(Tm(0.17, 0.1, 0)).multiply(RZm(rad(-30 - 30 * u)))});
  }
  const B = mount("Torso_hips", [0, 1.35, 0.85]);
  B.box([1.7, 0.2, 1.0], [0, -0.15, 0], [0, 0, -18], "shell");
  for (const s of [1, -1]) {
    B.cyl([0.6, 1.7, 0], [s * 0.55, 0.15, 0.35], [0, 0, 72], "steel");
    B.cyl([0.64, 0.12, 0], [s * 0.55, 0.42, -0.45], [0, 0, 72], "brass");
    B.cyl([0.64, 0.12, 0], [s * 0.55, -0.12, 1.15], [0, 0, 72], "brass");
    B.cyl([0.3, 0.2, 0], [s * 0.55, -0.22, 1.32], [0, 0, 72], "iron");
    B.box([0.08, 0.06, 1.2], [s * 0.55, 0.47, 0.35], [0, 0, -18], "hazY");
    cable("Torso_hips", B.toRest([s * 0.55, -0.1, 1.0]), `Leg${side4(s)}_haunch`, [s * 1.55, -0.1, 0.4], 0.35, 0.13);
  }
}
const side4 = s => s > 0 ? "L" : "R";
function grappleBelly() {
  const M = mount("Torso_body", [0, -1.25, -1.25]);
  M.box([2.1, 0.22, 1.8], [0, -0.55, 0], null, "shell");
  for (const e of [-1, 1]) { M.box([0.2, 1.15, 1.5], [e * 0.95, -0.05, 0], null, "plate"); M.cyl([0.55, 0.12, 0], [e * 1.08, -0.05, 0], [0, 0, 90], "brass"); M.bolt([e * 1.15, -0.05, 0], "x", 0.18, "iron"); }
  drumX(M, [0, -0.05, 0], 1.3, 1.5, "steel", (u, tt) => u * tt * 16, {name: "drum", speed: 16});
  M.hazard(1.6, 0.1, [0, -0.5, -0.92], null, 8);
  M.box([0.6, 0.06, 0.05], [0, -0.42, -0.92], null, "glow");
  for (const e of [-1, 1]) for (const z of [-0.55, 0.55]) { M.box([0.1, 2.3, 0.2], [e * 1.3, 0.95, z], [e * -10, 0, 0], "plate"); M.box([0.16, 0.22, 0.28], [e * 1.36, 0.45, z], null, "brass"); } // straps up the flanks
  const C = mount("Torso_chest", [0, 1.55, -3.45]);
  C.box([0.95, 0.85, 0.8], [0, 0, 0], null, "shell");
  C.box([1.05, 0.12, 0.9], [0, 0.48, 0], null, "plate");
  C.cyl([0.4, 0.9, 0], [0, -0.05, -0.6], [0, 0, 90], "iron");
  C.cyl([0.54, 0.14, 0], [0, -0.05, -1.05], [0, 0, 90], "brass");
  C.cyl([0.44, 0.05, 0], [0, -0.05, -1.13], [0, 0, 90], "glow", {role: "nozzle"});
  grapnel(C, [0, -0.05, -1.45], 0.7, u => u, null, "prong_");
  C.hose([0, -0.45, 0.25], [0, -1.6, 1.2], 0.15, 0.14, 5);
}
function grappleWrist() {
  const s = 1, M = mountM("ArmL_fore", foreFrame(s));
  M.box([0.58, 1.45, 0.55], [0, -0.05, 0.02], null, "shell");
  bandY(M, 0.58, 0.55, 0.12, [0, -0.62, 0.02]); bandY(M, 0.58, 0.55, 0.12, [0, 0.55, 0.02]);
  // low launcher plating on top of the arm, rails, a folded grapnel at the wrist, a range lamp, a side spool
  M.box([0.5, 1.3, 0.22], [0, 0.05, 0.42], null, "plate");
  for (const e of [-1, 1]) M.box([0.07, 1.4, 0.1], [e * 0.22, 0.1, 0.57], null, "brass");
  M.cyl([0.24, 0.9, 0], [0, 0.55, 0.62], null, "iron");
  grapnel(M, [0, 1.15, 0.62], 0.55, u => u * Math.max(0, Math.sin(loop(1.4) * Math.PI)));
  M.ball(0.22, [s * 0.25, -0.35, 0.6], "glow");
  drumX(M, [s * 0.45, -0.25, 0.0], 0.7, 0.26, "steel", (u, tt) => u * tt * 18);
  M.hose([0, -0.72, -0.2], [0.05, -1.05, -0.55], 0.1, 0.13, 3);
}
function oldGrapple() { const M = mount("Torso_body", [0, 0, 0]); M.box([1.9, 1.0, 1.8], [0, -0.75, -1.2], null, "trim"); M.cyl([1.2, 1.4, 0], [0, -0.75, -1.2], [0, 0, 90], "steel"); const C = mount("Torso_chest", [0, 0, 0]); C.box([0.5, 0.5, 1.2], [0, 1.4, -3.5], null, "brass"); }

// ============================================ 16 · DEFLECTOR CLAWS ============================================
function deflectUmbrella(sides) { // v0.4: sides = which arms (default both)
  for (const [s, side] of (sides || SIDES)) {
    const M = mountM(`Arm${side}_fore`, foreFrame(s));
    M.box([0.56, 1.3, 0.52], [0, -0.15, 0.02], null, "shell");
    bandY(M, 0.56, 0.52, 0.12, [0, -0.7, 0.02]);
    // the hub at the wrist (axis along the arm) and 6 folded claw-ribs lying back along the arm
    M.cyl([0.86, 0.32, 0], [0, 0.62, 0], null, "shell");
    M.cyl([0.94, 0.08, 0], [0, 0.8, 0], null, "brass");
    M.cyl([0.34, 0.06, 0], [0, 0.85, 0], null, "glow", {role: "hub"});
    const spin = u => u * t * 14 * s;
    const gh = M.group(`hub_${side}`, Tm(0, 0.8, 0), {type: "spin", axis: "Y", amt: 14 * s});
    for (let i = 0; i < 6; i++) {
      const phi = i * 60 + 30;
      const R = u => Tm(0, 0.8, 0).multiply(RYm(rad(phi) + spin(u))).multiply(Tm(0, 0, 0.42)).multiply(RXm(rad(-170 + 95 * u)));
      const gr = M.group(`rib_${side}${i + 1}`, R(0), {type: "swing", axis: "X", amt: 95}, gh);
      M.box([0.1, 1.35, 0.14], [0, 0, 0], null, "bone", {place: u => R(u).multiply(Tm(0, 0.68, 0)), group: gr, role: "rib"});
      M.wedge([0.1, 0.28, 0.2], [0, 0, 0], null, "bone", {place: u => R(u).multiply(Tm(0, 1.45, -0.03)).multiply(RXm(rad(90))), group: gr, role: "rib"});
      M.box([0.16, 0.18, 0.18], [0, 0, 0], null, "brass", {place: u => R(u), group: gr, role: "rib"});
    }
    M.cyl([2.9, 0.04, 0], [0, 0, 0], null, "glow", {alpha: 0.35, place: u => Tm(0, 0.95, 0), show: u => u > 0.05, group: gh, role: "film"});
  }
}
function deflectMane() {
  // Shield Liger: a ring of claw-fins around the base of the neck that spins up and throws a shield disc in front
  const N = mountM("Torso_chest", axisFrame([0, 3.3, -2.95], [0, 0.94, -0.34], [1, 0, 0]));
  N.cyl([2.3, 0.32, 0], [0, -0.1, 0], null, "shell", {role: "hub"});
  N.add("ring", [1.2, 0.08, 0], [0, 0.1, 0], [0, 0, 90], "brass");
  for (let i = 0; i < 8; i++) N.box([0.2, 0.08, 0.2], [Math.cos(i * Math.PI / 4) * 1.15, 0.17, Math.sin(i * Math.PI / 4) * 1.15], null, "glow");
  const spin = u => u * t * 10;
  const gcol = N.group("collar", Tm(0, 0, 0), {type: "spin", axis: "Y", amt: 10}); // v0.5 export
  for (let i = 0; i < 8; i++) {
    const R = u => RYm(rad(i * 45 + 22.5) + spin(u)).multiply(Tm(0, 0.1, 1.05)).multiply(RXm(rad(28 + 50 * u)));
    const gf = N.group(`fin_${i + 1}`, R(0), {type: "swing", axis: "X", amt: 50}, gcol);
    N.wedge([0.14, 1.1, 0.5], [0, 0, 0], null, "bone", {place: u => R(u).multiply(Tm(0, 0.55, 0)).multiply(rot(0, 180, 0)), group: gf, role: "fin"});
    N.box([0.2, 0.3, 0.3], [0, 0, 0], null, "iron", {place: u => R(u), group: gf, role: "fin"});
  }
  const D = mount("Torso_chest", [0, 3.0, -4.7]);
  D.cyl([4.6, 0.05, 0], [0, 0, 0], [0, 0, 90], "glow", {alpha: 0.35, show: u => u > 0.05, role: "film"});
  D.add("ring", [2.3, 0.06, 0], [0, 0, 0], null, "glow", {show: u => u > 0.05});
}
function deflectSaw() {
  const C = mountM("Torso_chest", axisFrame([0, 2.25, -3.55], [0, 0, -1], [1, 0, 0])); // local Y points forward out of the chest
  C.box([1.9, 0.3, 1.7], [0, -0.25, 0], null, "shell");
  for (const e of [-1, 1]) C.wedge([0.4, 0.3, 1.7], [e * 1.1, -0.25, 0], [e * 90, 0, 0], "plate");
  C.cyl([1.25, 0.32, 0], [0, 0.05, 0], null, "plate");
  C.add("ring", [0.68, 0.06, 0], [0, 0.22, 0], [0, 0, 90], "brass");
  C.cyl([0.45, 0.12, 0], [0, 0.3, 0], null, "glow");
  const spin = u => t * (0.6 + u * 16);
  for (let i = 0; i < 6; i++) {
    const R = u => Tm(0, 0.32, 0).multiply(RYm(rad(i * 60) + spin(u))).multiply(Tm(0, 0, 0.35 + 0.35 * u));
    C.box([0.16, 0.08, 0.95], [0, 0, 0], null, "bone", {place: u => R(u).multiply(Tm(0, 0, 0.3))});
    C.box([0.14, 0.08, 0.6], [0, 0, 0], null, "bone", {place: u => R(u).multiply(Tm(0.18, 0, 0.82)).multiply(RYm(rad(-45)))});
  }
  C.cyl([5.0, 0.04, 0], [0, 0.4, 0], null, "glow", {alpha: 0.3, show: u => u > 0.05});
  C.hazard(1.2, 0.1, [0, -0.25, -0.86], [0, 0, 0], 6);
}
function oldDeflect() { for (const [s, side] of SIDES) { const M = mount(`Arm${side}_hand`, [0, 0, 0]); M.cyl([0.9, 0.5, 0], [s * 4.39, 0.05, -3.39], [0, 0, 90], "steel"); M.box([0.4, 0.4, 0.4], [s * 4.39, 0.05, -3.9], null, "brass"); } }

// ============================================ 18 · OVERCLOCK JOINTS ============================================
function clockPistons() {
  for (const [s, side] of SIDES) {
    const H = mount(`Leg${side}_haunch`, [s * 1.42, -0.5, -0.15]);
    H.box([0.16, 1.15, 1.05], [0, 0, 0], null, "plate");
    H.box([0.2, 0.12, 1.15], [0, 0.6, 0], null, "trim");
    // a glowing coolant canister in a brass cage, heat fins that flip open when used
    H.cyl([0.42, 0.75, 0], [s * 0.3, 0.05, 0.1], null, "glow", {role: "ring"});
    for (const y of [-0.38, 0.48]) H.cyl([0.5, 0.1, 0], [s * 0.3, y, 0.1], null, "brass");
    for (let k = 0; k < 3; k++) H.box([0.05, 0.85, 0.05], [s * 0.3 + Math.cos(k * 2.1) * 0.24, 0.05, 0.1 + Math.sin(k * 2.1) * 0.24], null, "brass");
    for (let i = 0; i < 4; i++) { const gf = H.group(`fin_${side}${i + 1}`, Tm(s * 0.12, -0.05, -0.42 + i * 0.12).multiply(RZm(s * rad(10))), {type: "swing", axis: "Z", amt: s * 40});
      H.box([0.08, 0.55, 0.14], [0, 0, 0], null, "iron", {place: u => Tm(s * 0.12, -0.05, -0.42 + i * 0.12).multiply(RZm(s * rad(10 + 40 * u))), group: gf, role: "fin"}); }
    // telescoping piston haunch -> knee: outer barrel on the thigh, rod on the knee
    const T = mount(`Leg${side}_thigh`, [s * 1.4, -1.55, -0.62]);
    T.cyl([0.3, 1.3, 0], [0, 0, 0], [0, 0, -14], "iron");
    T.cyl([0.36, 0.12, 0], [0, -0.62, -0.15], [0, 0, -14], "brass");
    const K = mount(`Shin${side}_knee`, [s * 1.18, -2.62, -0.85]);
    K.cyl([0.17, 1.2, 0], [s * 0.18, 0.58, 0.12], [0, 0, -14], "steel");
    // the knee: a gear cap with teeth and a hot core
    const gg = K.group(`gear_${side}`, Tm(0, 0, 0), {type: "spin", axis: "X", amt: 12});
    K.cyl([0.8, 0.2, 0], [0, 0, 0], [90, 0, 0], "brass", {anim: u => RYm(u * t * 12), group: gg, role: "gear"});
    for (let k = 0; k < 8; k++) K.box([0.2, 0.12, 0.14], [0, 0, 0], null, "brass", {place: u => RXm(u * t * 12 + k * Math.PI / 4).multiply(Tm(0, 0.45, 0)), group: gg, role: "gear"});
    K.cyl([0.36, 0.24, 0], [0, 0, 0], [90, 0, 0], "glow", {role: "ring"});
    const S2 = mountOn(`Shin${side}_shin`, [0, 0.2, 0]);
    S2.box([0.68, 1.2, 0.66], [0, 0, 0], null, "shell");
    S2.box([0.7, 0.1, 0.68], [0, 0.6, 0], null, "trim");
    S2.box([0.05, 0.9, 0.06], [0, 0, -0.35], null, "glow", {role: "ring"});
  }
}
function clockTurbine() {
  const S = mountM("Torso_body", BACK());
  S.box([1.6, 0.22, 1.9], [0, 0, 0.1], null, "shell");
  for (const e of [-1, 1]) S.box([0.16, 0.6, 1.7], [e * 0.85, -0.25, 0.1], null, "plate");
  // the turbine: a studded nacelle pointing back, a brass intake ring and a fan that spins up
  S.cyl([1.45, 1.5, 0], [0, 0.75, 0.35], [0, 0, 90], "shell");
  S.cyl([1.6, 0.16, 0], [0, 0.75, -0.42], [0, 0, 90], "brass");
  S.cyl([1.55, 0.16, 0], [0, 0.75, 1.1], [0, 0, 90], "brass");
  S.cyl([1.2, 0.1, 0], [0, 0.75, 1.18], [0, 0, 90], "trim");
  S.cyl([0.45, 0.3, 0], [0, 0.75, 1.22], [0, 0, 90], "glow");
  for (let i = 0; i < 8; i++) S.box([0.08, 0.5, 0.06], [0, 0, 0], null, "steel", {place: u => Tm(0, 0.75, 1.25).multiply(RZm(t * (1 + 25 * u) + i * Math.PI / 4)).multiply(Tm(0, 0.36, 0)).multiply(RYm(rad(30)))});
  for (const e of [-1, 1]) { S.cyl([0.3, 0.9, 0], [e * 0.55, 1.45, 0.75], [0, 0, 20], "iron"); S.cyl([0.22, 0.05, 0], [e * 0.55, 1.88, 0.92], [0, 0, 20], "glow"); }
  S.hazard(1.3, 0.08, [0, 0.12, -0.75], null, 6);
  // coolant lines from the turbine down to the knee caps
  for (const [s, side] of SIDES) {
    const K = mount(`Shin${side}_knee`, [s * 1.2, -2.62, -0.85]);
    K.cyl([0.75, 0.22, 0], [0, 0, 0], [90, 0, 0], "brass");
    K.cyl([0.34, 0.26, 0], [0, 0, 0], [90, 0, 0], "glow");
    K.box([0.12, 0.5, 0.5], [-s * 0.1, 0.0, 0], null, "shell");
    cable("Torso_body", S.toRest([s * 0.75, 0.3, 0.8]), `Shin${side}_knee`, [s * 1.3, -2.45, -0.75], 0.25, 0.14);
  }
}
function clockCogs() {
  const R = [["ArmL_shoulder", [1.62, 1.72, -2.62], 1, 0.95], ["ArmR_shoulder", [-1.62, 1.72, -2.62], -1, 0.95], ["LegL_haunch", [1.4, -0.54, -0.15], 1, 1.2],
    ["LegR_haunch", [-1.4, -0.54, -0.15], -1, 1.2], ["ShinL_knee", [1.2, -2.62, -0.85], 1, 0.8], ["ShinR_knee", [-1.2, -2.62, -0.85], -1, 0.8], ["ArmL_elbow", [3.65, 0.35, -2.23], 1, 0.6], ["ArmR_elbow", [-3.65, 0.35, -2.23], -1, 0.6]];
  for (const [pn, pos, s, d] of R) {
    const M = mount(pn, pos);
    const sp = u => s * (t * 0.3 + u * t * 14);
    M.cyl([d, 0.16, 0], [0, 0, 0], [90, 0, 0], "brass", {anim: u => RYm(sp(u))});
    const n = d > 0.9 ? 12 : 9;
    for (let k = 0; k < n; k++) M.box([0.14, d * 0.14, d * 0.2], [0, 0, 0], null, "brass", {place: u => RXm(sp(u) + k * Math.PI * 2 / n).multiply(Tm(0, d * 0.55, 0))});
    M.cyl([d * 0.55, 0.2, 0], [s * 0.02, 0, 0], [90, 0, 0], "glow");
    M.cyl([d * 0.25, 0.26, 0], [s * 0.04, 0, 0], [90, 0, 0], "iron");
    if (d >= 1.1) for (let i = 0; i < 3; i++) M.box([0.06, 0.5, 0.12], [-s * 0.08, 0.55 + 0.02 * i, -0.3 + i * 0.22], null, "iron");
  }
}
function oldClock() { const R = [["ArmL_shoulder", [1.54, 1.62, -2.62]], ["ArmR_shoulder", [-1.54, 1.62, -2.62]], ["LegL_haunch", [0.85, -0.54, -0.15]], ["LegR_haunch", [-0.85, -0.54, -0.15]], ["ShinL_knee", [0.85, -2.62, -0.85]], ["ShinR_knee", [-0.85, -2.62, -0.85]], ["ArmL_elbow", [3.39, 0.31, -2.23]], ["ArmR_elbow", [-3.39, 0.31, -2.23]]];
  for (const [pn, pos] of R) { const M = mount(pn, pos); M.add("ring", [pn.includes("elbow") ? 0.38 : 0.62, 0.11], [0, 0, 0], [0, 90, 0], "steel"); } }

// ============================================ 19 · SNARE WIRES ============================================
function snareSpools() {
  const tails = ["Tail2_main", "Tail3_main", "Tail4_main"];
  tails.forEach((tp, k) => {
    const sz = theri.byName[tp].size, M = mountOn(tp); // part frame: X along the tail, Y up, Z = sideways
    // studded collar armour around the tail
    M.box([sz[0] * 0.55, sz[1] + 0.2, sz[2] + 0.2], [0, 0, 0], null, "shell");
    M.box([sz[0] * 0.6, 0.08, sz[2] + 0.26], [0, sz[1] / 2 + 0.14, 0], null, "trim");
    // the spool on top (axis sideways), wire wrapped on it, an orange core
    const d = 0.85 - k * 0.12, w = 0.6 - k * 0.06, y = sz[1] / 2 + 0.2 + d / 2;
    const gs = M.group(`spool_${k + 1}`, Tm(0, y, 0), {type: "spin", axis: "Z", amt: 16});
    M.cyl([d * 0.78, w, 0], [0, y, 0], [90, 0, 90], "rubber", {anim: u => RYm(u * t * 16), group: gs, role: "spool"});
    for (let r = 0; r < 4; r++) M.box([d * 0.8, 0.05, w * 0.98], [0, 0, 0], null, "iron", {place: u => Tm(0, y, 0).multiply(RZm(u * t * 16 + r * Math.PI / 4)), group: gs, role: "spool"});
    for (const e of [-1, 1]) M.cyl([d, 0.07, 0], [0, y, e * (w / 2 + 0.035)], [90, 0, 90], "brass");
    M.cyl([d * 0.3, w + 0.2, 0], [0, y, 0], [90, 0, 90], "glow");
    for (const e of [-1, 1]) M.box([sz[0] * 0.3, d * 0.6, 0.08], [0, y - d * 0.28, e * (w / 2 + 0.12)], null, "plate");
    // a folded trap (jaw teeth) clipped on each side of the collar
    for (const e of [-1, 1]) {
      M.box([sz[0] * 0.45, 0.2, 0.08], [0, -0.05, e * (sz[2] / 2 + 0.16)], null, "iron");
      for (let i = 0; i < 3; i++) M.wedge([0.1, 0.16, 0.08], [-sz[0] * 0.15 + i * sz[0] * 0.15, 0.13, e * (sz[2] / 2 + 0.16)], null, "steel", {detail: true});
      M.box([0.1, 0.08, 0.05], [0, -0.05, e * (sz[2] / 2 + 0.22)], null, "glow");
    }
  });
}
function snareBandolier() {
  // a strap across the back holding 3 trap posts (anchor post + jaw + glowing lens) that pop up when used
  const S = mountM("Torso_body", BACK());
  for (let i = 0; i < 5; i++) S.box([0.32, 0.12, 0.62], [-0.85 + i * 0.42, 0.02, 0.5 - i * 0.25], [0, -30, 0], "trim");
  S.box([1.7, 0.18, 1.6], [0, -0.05, 0.05], null, "shell");
  for (let k = 0; k < 3; k++) {
    const x = -0.55 + k * 0.55;
    S.box([0.42, 0.5, 0.42], [x, 0.32, 0.05], null, "plate");
    S.box([0.46, 0.08, 0.46], [x, 0.58, 0.05], null, "hazY");
    const pop = u => u * Math.max(0, Math.sin(Math.min(1, Math.max(0, loop(1.8) * 3 - k * 0.6)) * Math.PI)) * 1.1;
    const P2 = u => Tm(x, 0.65 + pop(u), 0.05);
    S.cyl([0.24, 0.9, 0], [0, 0, 0], null, "iron", {place: u => P2(u)});
    S.ball(0.3, [0, 0, 0], "glow", {place: u => P2(u).multiply(Tm(0, 0.55, 0))});
    S.cyl([0.36, 0.08, 0], [0, 0, 0], null, "brass", {place: u => P2(u).multiply(Tm(0, 0.38, 0))});
    for (let i = 0; i < 4; i++) S.wedge([0.08, 0.2, 0.14], [0, 0, 0], null, "steel", {place: u => P2(u).multiply(RYm(i * Math.PI / 2)).multiply(Tm(0, 0.05, 0.18))});
  }
  S.hose([0.85, 0.05, 0.6], [0.95, -0.4, 1.2], 0.12, 0.14, 4);
}
function oldSnare() { for (const tp of ["Tail2_main", "Tail3_main", "Tail4_main"]) { const y = theri.byName[tp].cf.elements[13], z = theri.byName[tp].cf.elements[14]; const M = mount(tp, [0, 0, 0]); M.cyl([0.9, 0.6, 0], [0, y + 0.55, z], [0, 0, 90], "steel"); M.cyl([0.5, 0.65, 0], [0, y + 0.55, z], [0, 0, 90], "glow"); } }

// ============================================ the list ============================================
const PARTS = [
  {id: "hook", short: "Hook", name: "Reaper's Hook", area: "attack", focus: [-3.2, 2.0, -3.6],
    oldText: "Back Crane (in the game now): a box on the back, one grey bar and a yellow bar over the head, a grey drum.",
    looks: [
      {name: "Harpoon Gauntlet", sub: "right arm · Roadhog / Sekiro", build: hookGauntlet, pose: POSES.ARM_L_FWD, focus: [-4.3, 1.0, -3.6], closeYaw: 0.8, closePitch: 0.2, closeSide: 1,
        ref: "Roadhog's chain hook (Overwatch) and Sekiro's arm prosthetic: the launcher is built into the arm, with one oversized hook you can read from across the map.",
        why: "A studded armour sleeve wraps the right forearm, strapped and bolted on. A harpoon barrel runs under it past the claws with a big bone reaper sickle loaded in the muzzle, and a chain drum sits at the elbow. A hose runs into the upper arm, and the red glow is the lamp on top plus the muzzle ring.",
        use: "the arm points, the drum spins, and the sickle flies out on a real chain and is reeled back in.", on: "the right forearm, the camera side (the model's ArmL_fore: its L / R names are mirrored), with a hose into the upper arm."},
      {name: "Reaper Crane", sub: "back · rebuilt crane", build: hookCrane, pose: POSES.HOOK_AIM, focus: [0, 6, -2], closeYaw: 2.2, closePitch: 0.3,
        ref: "your old Back Crane pick, rebuilt like a Horizon machine part: a saddle that follows the back, visible hinges and pistons, and a real claw instead of a bar.",
        why: "A studded saddle is strapped to the back with a turret on it. A two-part crane arm, with a hydraulic piston, a brass hinge and a chain drum, reaches up and over the head. A chain hangs from the tip to a three-pronged bone claw. Red glows on the turret window and the jib tip.",
        use: "the boom dips forward, the claw's prongs open, and the drum winds.", on: "the back (Torso_body), the same spot as now."},
    ]},
  {id: "feather", short: "Feathers", name: "Feather Barrage", area: "attack", focus: [3.6, 0.6, -2.8],
    oldText: "Arm Racks (in the game now): a flat dark block on each forearm with 6 thin white sticks.",
    looks: [
      {name: "Blade Wings", sub: "both forearms · Storm Sworder", build: featherWings, pose: POSES.SWEEP, focus: [4.2, 0.0, -2.6], closeYaw: 1.2, closePitch: 0.2, closeSide: 1,
        ref: "Storm Sworder's wing swords (Zoids), which tuck flush and light up along their edges, plus the real Therizinosaurus' arm feathers.",
        why: "Each forearm gets a strapped magazine and a brass spar. Six long bone blade-feathers hang off the spar like wing feathers, getting longer toward the hand, and every blade has a thin red edge. It reads as a feathered arm made of knives.",
        use: "the arms sweep out, the blades fan open with their edges glowing, and then they fire.", on: "both forearms (ArmL_fore / ArmR_fore), with a hose into each upper arm."},
      {name: "Fin Rack", sub: "back · ν Gundam fin funnels", build: featherFins, pose: POSES.SWEEP, focus: [0, 5.5, -0.5], closeYaw: 2.3, closePitch: 0.35,
        ref: "ν Gundam's fin funnels: big L-shaped blades carried in a rack on the back, folded like a closed fan.",
        why: "A studded rack on the back holds six big L-shaped bone fins, folded up like a dorsal crest, each with a red edge strip. A brass hinge drum sits at the root, with launch stripes in front of it.",
        use: "the fins spread into a full fan behind the shoulders and tip forward to fire.", on: "the back (Torso_body)."},
    ]},
  {id: "harvest", short: "Harvest", name: "Harvest Field", area: "attack", focus: [3.8, 0.4, -3.0],
    oldText: "Arm Pistons (in the game now): a dark box, a grey stick and a yellow plate on each forearm.",
    looks: [
      {name: "Pile Bunkers", sub: "both forearms · Zoids / Armored Core", build: harvestPiles, pose: POSES.STAB, focus: [4.0, 0.0, -3.0], closeYaw: 1.0, closePitch: 0.2, closeSide: 1,
        ref: "the Zoids Twin Pile Bunker (heat fins plus a slide valve) and Armored Core's pile bunker, a short boxy housing with a long piston that slams out.",
        why: "Under each forearm sits a heavy studded bunker with stacked heat fins, a valve block, launch stripes and a red heat seam. A steel pile with a wedge tip points down past the claws.",
        use: "the dino crouches and both piles slam into the ground again and again.", on: "both forearms (ArmL_fore / ArmR_fore)."},
      {name: "Reaper Sleeves", sub: "the claws · Thunderjaw", build: () => harvestSleeves({fore: false}), pose: POSES.STAB, focus: [5.6, -1.6, -3.8], closeYaw: 0.9, closePitch: 0.15, closeSide: 1,
        ref: "Horizon's Thunderjaw and Rockbreaker: heavy machine claws for ripping the ground.",
        why: "Steel sleeves with serrated teeth go over all three claws on each hand, each with a red glowing edge and a brass collar. The hands get studded wrist cuffs; the forearms stay free for other parts.",
        use: "the claws stab down and the edges burn red.", on: "the claws and hands."},
    ]},
  {id: "grapple", short: "Grapple", name: "Grapple Zip", area: "speed", focus: [0, 0.5, -1.0],
    oldText: "Belly Winch (in the game now): a dark box and grey drum under the belly, a small yellow block on the chest.",
    looks: [
      {name: "Hip Gear", sub: "both hips · Attack on Titan", build: grappleODM, pose: POSES.ARMS_FWD, focus: [1.6, -0.2, -0.6], closeYaw: 1.7, closePitch: 0.2, closeSide: 1,
        ref: "Attack on Titan's ODM gear: twin anchor launchers on the hips and gas tanks behind, joined by hoses.",
        why: "A launcher sits on each hip, with a strapped side plate, a cable reel and a forward barrel ending in a three-barb anchor. Two brass-capped tanks lie across the lower back, with hoses running to each launcher. Yellow glows at the muzzles.",
        use: "both reels spin and the anchors shoot forward on their cables.", on: "both hips (LegL_haunch / LegR_haunch) and the lower back (Torso_hips)."},
      {name: "Belly Winch", sub: "belly + chest · rebuilt", build: grappleBelly, pose: POSES.ARMS_FWD, focus: [0, 0.2, -2.2], closeYaw: 0.6, closePitch: -0.05,
        ref: "your old Belly Winch pick, rebuilt: a cradle strapped round the body, a real cable drum, and a grapnel launcher on the chest (Horizon's ropecaster bolt).",
        why: "A studded cradle under the belly holds a wide cable drum between two brass-bossed cheeks, with straps up both flanks. A chest launcher carries a folded three-pronged grapnel, fed by a hose from the drum. Yellow glows at the muzzle and the cradle stripe.",
        use: "the drum spins and the grapnel's prongs open.", on: "under the body (Torso_body), with the launcher on the chest (Torso_chest)."},
      {name: "Arm Grapnel", sub: "right arm · Sekiro / Titanfall", build: grappleWrist, pose: POSES.ARM_L_FWD, focus: [4.3, 1.0, -3.6], closeYaw: 1.0, closePitch: 0.25, closeSide: 1,
        ref: "Sekiro's prosthetic grapple (built into the arm) and Titanfall 2's wrist grapple, with Pathfinder's \"in range\" light.",
        why: "Low launcher plating lies along the top of the right forearm, with brass rails and a folded grapnel at the wrist. A side spool and a round yellow range lamp complete it, so the arm looks like a tool.",
        use: "the arm points, the grapnel snaps open and the spool spins.", on: "the right forearm, the camera side (the model's ArmL_fore: its L / R names are mirrored)."},
    ]},
  {id: "deflect", short: "Deflect", name: "Deflector Claws", area: "defense", focus: [4.2, 0.4, -3.4],
    oldText: "Spinner Hubs (in the game now): a grey puck and a small yellow cube on each hand.",
    looks: [
      {name: "Umbrella Gauntlets", sub: "both wrists · Sekiro umbrella", build: deflectUmbrella, pose: POSES.ARMS_FWD, focus: [4.4, 0.6, -3.6], closeYaw: 0.8, closePitch: 0.2, closeSide: 1,
        ref: "Sekiro's Loaded Umbrella (a shield that opens out of the arm) with Therizinosaurus claw-ribs.",
        why: "Each wrist has a studded hub with a blue core. Six bone claw-ribs lie folded back along the forearm like a closed umbrella.",
        use: "the ribs swing forward into a spinning claw disc in front of each hand, with a blue shield film between them.", on: "both forearms / wrists (ArmL_fore / ArmR_fore)."},
      {name: "Mane Rotor", sub: "neck collar · Shield Liger", build: deflectMane, pose: POSES.CHEST_OUT, focus: [0, 3.6, -3.2], closeYaw: 0.5, closePitch: 0.3,
        ref: "Shield Liger (Zoids): the shield generator is in its mane, a ring of fins that turns forward to throw a shield over the front.",
        why: "A studded collar ring around the base of the neck carries eight bone fins and eight blue gems on a brass rim. It reads as a mane of blades.",
        use: "the fins tilt forward and the collar spins, and a big blue shield disc appears in front of the chest.", on: "the base of the neck (Torso_chest)."},
      {name: "Chest Buzzsaw", sub: "chest · rotary blade", build: deflectSaw, pose: POSES.CHEST_OUT, focus: [0, 2.4, -3.6], closeYaw: 0.35, closePitch: 0.15,
        ref: "rotary saw-blade shields (buzzsaw arms in mech games) with Therizinosaurus claws as the teeth.",
        why: "A studded chest plate with angled cheeks holds a rotor with a blue core. Six hooked bone blades sit folded in a star, with launch stripes along the lower edge.",
        use: "the blades slide out and spin into a big saw, with a blue shield film around it.", on: "the chest (Torso_chest)."},
    ]},
  {id: "overclock", short: "Overclock", name: "Overclock Joints", area: "speed", focus: [1.3, -1.6, -0.6], pose: RUN,
    oldText: "Joint Rings (in the game now): thin grey rings on the shoulders, hips, knees and elbows.",
    looks: [
      {name: "Piston Legs", sub: "hips + knees · Horizon pistons", build: clockPistons, pose: RUN, focus: [1.3, -1.6, -0.5], closeYaw: 1.6, closePitch: 0.15, closeSide: 1,
        ref: "Horizon's machine joints (visible hydraulic pistons and glass element canisters) plus Zoids heat fins.",
        why: "Each hip gets a studded plate holding a glowing yellow canister in a brass cage, with heat fins beside it. A telescoping piston runs from the thigh to the knee. Each knee is a toothed brass gear with a hot core, and the shins get studded greaves.",
        use: "the legs run, the knee gears spin, the fins flip open and everything glows.", on: "both legs (haunch, thigh, knee, shin)."},
      {name: "Turbine Heart", sub: "back + knees · Trans-Am", build: clockTurbine, pose: RUN, focus: [0, 3.5, 0.2], closeYaw: 2.5, closePitch: 0.35,
        ref: "Gundam's Trans-Am glow and jet nacelles: one engine that visibly spins up and feeds the joints.",
        why: "A studded turbine nacelle on the back has brass rings, a fan, two exhaust stacks and a hot yellow centre. Coolant hoses run down to brass caps on both knees.",
        use: "the fan spins up hard, the exhausts and knee caps glow, and the legs run.", on: "the back (Torso_body), with caps on the knees."},
      {name: "Cog Joints", sub: "every joint · rebuilt rings", build: clockCogs, pose: RUN, focus: [1.4, -0.4, -1.2], closeYaw: 1.5, closePitch: 0.15, closeSide: 1,
        ref: "your old Joint Rings pick, rebuilt as real clockwork: toothed brass cogs with glowing hubs.",
        why: "Every big joint (shoulders, hips, knees, elbows) gets a toothed brass cog with a yellow glowing ring and an iron axle cap. The hips also get heat fins.",
        use: "every cog spins hard while the dino runs.", on: "the shoulders, hips, knees and elbows."},
    ]},
  {id: "snare", short: "Snare", name: "Snare Wires", area: "eng", focus: [0, 0.6, 4.4],
    oldText: "Tail Spools (in the game now): three grey pucks with red middles on the tail.",
    looks: [
      {name: "Tail Spool Rig", sub: "tail · Horizon tripcaster", build: snareSpools, pose: POSES.TAIL_FLICK, focus: [0, 0.8, 4.4], closeYaw: 2.0, closePitch: 0.3,
        ref: "Horizon's tripcaster and Rainbow Six's jaw traps: wire on visible spools plus folded traps you can recognise.",
        why: "The tail gets three studded armour collars. Each carries a wire spool with brass flanges and an orange core, and a folded jaw trap clipped on each side.",
        use: "the tail flicks, the spools spin and the traps go out.", on: "the tail (Tail2 / Tail3 / Tail4)."},
      {name: "Trap Bandolier", sub: "back strap · Cypher / Kapkan", build: snareBandolier, pose: POSES.TAIL_FLICK, focus: [0, 4.5, -0.5], closeYaw: 2.4, closePitch: 0.4,
        ref: "Valorant Cypher's trapwire posts and Rainbow Six Kapkan's door traps: small anchor posts with a lens.",
        why: "A strap across the back holds three holsters. Each holds a trap post with steel jaw teeth and a glowing orange lens.",
        use: "the posts pop out of their holsters one after another.", on: "the back (Torso_body)."},
    ]},
];
// v0.4: Loadouts — all 7 parts on at once, no two on the same spot (Kepu 2026-11-04 "Move some off the arms": keep 2 on the arms)
const ARMS_FREE_HARVEST = () => harvestSleeves({fore: false});
const LOADOUTS = [
  {name: "Hook + Harvest on the arms", sub: "feathers to the back, deflect to the neck",
    why: "The hook keeps your camera-side forearm and Harvest moves down onto the claws. Feathers become the Fin Rack on the back, and Deflect becomes the Mane Rotor around the neck, so the left forearm stays bare.",
    parts: [["hook", hookGauntlet], ["harvest", ARMS_FREE_HARVEST], ["feather", featherFins], ["deflect", deflectMane], ["grapple", grappleBelly], ["overclock", clockPistons], ["snare", snareSpools]],
    rows: [["hook", "Harpoon Gauntlet · camera-side forearm (your pick)"], ["harvest", "Reaper Sleeves · steel sleeves on the claws + wrist cuffs (moved off the forearm)"], ["feather", "Fin Rack · back (moved off the arms)"], ["deflect", "Mane Rotor · neck collar (moved off the arms)"], ["grapple", "Belly Winch · belly + chest (your pick)"], ["overclock", "Piston Legs · legs (your pick)"], ["snare", "Tail Spool Rig · tail (your pick)"]]},
  {name: "Weapon arm + shield arm", sub: "hook on one arm, deflector on the other",
    why: "A classic mech split: the harpoon on the camera-side forearm and the umbrella shield on the other forearm only. Harvest moves onto the claws, and Feathers become the Fin Rack on the back.",
    parts: [["hook", hookGauntlet], ["deflect", () => deflectUmbrella([[-1, "R"]])], ["harvest", ARMS_FREE_HARVEST], ["feather", featherFins], ["grapple", grappleBelly], ["overclock", clockPistons], ["snare", snareSpools]],
    rows: [["hook", "Harpoon Gauntlet · camera-side forearm (your pick)"], ["deflect", "Umbrella Gauntlet · the other forearm only (one shield, not two)"], ["harvest", "Reaper Sleeves · claws + wrist cuffs (moved off the forearm)"], ["feather", "Fin Rack · back (moved off the arms)"], ["grapple", "Belly Winch · belly + chest (your pick)"], ["overclock", "Piston Legs · legs (your pick)"], ["snare", "Tail Spool Rig · tail (your pick)"]]},
  {name: "Feathers + Harvest on the arms", sub: "hook to the back crane, deflect to the neck",
    why: "The Blade Wings keep both forearms and Harvest moves down onto the claws. The hook becomes the Reaper Crane on the back, and Deflect becomes the Mane Rotor around the neck.",
    parts: [["feather", featherWings], ["harvest", ARMS_FREE_HARVEST], ["hook", hookCrane], ["deflect", deflectMane], ["grapple", grappleBelly], ["overclock", clockPistons], ["snare", snareSpools]],
    rows: [["feather", "Blade Wings · both forearms (your pick)"], ["harvest", "Reaper Sleeves · claws + wrist cuffs (moved off the forearm)"], ["hook", "Reaper Crane · back (moved off the arm)"], ["deflect", "Mane Rotor · neck collar (moved off the arms)"], ["grapple", "Belly Winch · belly + chest (your pick)"], ["overclock", "Piston Legs · legs (your pick)"], ["snare", "Tail Spool Rig · tail (your pick)"]]},
];
const OLD = {hook: oldHook, feather: oldFeather, harvest: oldHarvest, grapple: oldGrapple, deflect: oldDeflect, overclock: oldClock, snare: oldSnare};
pose({}); camGoal(); renderAll(); requestAnimationFrame(frame);
