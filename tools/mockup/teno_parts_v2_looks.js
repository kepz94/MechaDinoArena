// Teno parts redesign v0.1 — the looks (Kepu 2026-11-05: "the teno mecha parts and animation is a bit underwhelming" -> "Looks
// first"; 16:16 "look at how other games do it then build our version"). 7 parts x 3 looks, each borrowing one real game part.
// Coordinates: rest model space (scale 1 = studs / 2, HRP frame; front = -Z, +X = the camera side = the model's "...L" parts).
// mountOn(part) frames: local X = along the part toward the head (tail: -X = toward the tip), Y = up, Z = +X (camera side).
// Joint signs (measured, scratchpad jcal.js): p+ lifts Neck / Head / RootJoint front, swings ArmL / LegL forward, Tail p+ = down,
// Jaw p- = open; Tail y+ swings toward +X.
const V3 = (x, y, z) => new THREE.Vector3(x, y, z);
const SIDES = [[1, "L"], [-1, "R"]];
const loop = (period, tt) => ((tt === undefined ? t : tt) % period) / period; // 0..1 sawtooth
const sm = x => { x = Math.max(0, Math.min(1, x)); return x * x * (3 - 2 * x); };
const PURPLE = 0x9646ff, LILAC = 0xcda0ff, ORANGE = 0xff8a1a, RED = 0xe02a2a, GREEN = 0x3ddc84, BLUE = 0x3d9bff, YEL = 0xffc21a;
MAT.dark = [0x3a3f47, "metal"]; MAT.rock = [0x8a8478, "stud"]; MAT.cloth = [0x1d3b7a, "plain"]; MAT.clothW = [0xe8ecf4, "plain"];
// a piece placed every frame by fn(u, t) -> mount-local Matrix4 (position / rotation / scale)
const at = (M, sh, s, key, fn, o) => M.add(sh, s, [0, 0, 0], null, key, Object.assign({}, o || {}, {place: fn}));
// a see-through Neon film whose opacity fn(u, t) sets every frame (colour fixed)
function film(M, sh, s, color, fn, op, o) {
  const e = M.add(sh, s, [0, 0, 0], null, "white", Object.assign({}, o || {}, {color, alpha: 0.5, place: fn}));
  e.anim = (u, tt) => { e.mesh.material.opacity = Math.max(0, Math.min(1, op(u, tt))); return null; };
  return e;
}
const SC = (x, y, z) => new THREE.Matrix4().makeScale(x, y, z);
// a world-aligned mount at pos (rot r), scaled k times about the local point c (coordinates stay the same)
function mountC(part, pos, r, c, k) { return mountM(part, Tm(...pos).multiply(rot(...(r || [0, 0, 0]))).multiply(Tm(...c)).multiply(SC(k, k, k)).multiply(Tm(-c[0], -c[1], -c[2]))); }
// a mount in the part's own frame, scaled k times about the point c (coordinates stay the part's own)
function mountS(part, c, k) { return mountM(part, dino.byName[part].cf.clone().multiply(Tm(...c)).multiply(SC(k, k, k)).multiply(Tm(-c[0], -c[1], -c[2]))); }
// a cylinder from a to b (mount-local), diameter d
function rod(M, a, b, d, key, o) {
  const A = V3(...a), B = V3(...b), dir = B.clone().sub(A), len = dir.length(), q = new THREE.Quaternion().setFromUnitVectors(V3(0, 1, 0), dir.normalize());
  return at(M, "cyl", [d, len, 0], key, () => new THREE.Matrix4().compose(A.clone().add(B).multiplyScalar(0.5), q, V3(1, 1, 1)), o);
}
// a strut between two body parts (rest-space points), spanning fraction f0..f1 of the line: follows both parts every frame
function strut(M, pa, a, pb, b, f0, f1, d, key) {
  const W = new THREE.Matrix4(), Y = V3(0, 1, 0); let e;
  e = M.add("cyl", [d, 1, 0], [0, 0, 0], null, key, {place: () => {
    const A = restOn(pa, a), B = restOn(pb, b), P0 = A.clone().lerp(B, f0), P1 = A.clone().lerp(B, f1), dir = P1.clone().sub(P0), len = dir.length();
    W.compose(P0.clone().add(P1).multiplyScalar(0.5), new THREE.Quaternion().setFromUnitVectors(Y, dir.normalize()), V3(1, len, 1));
    return dino.byName[M.part].mesh.matrix.clone().multiply(e.mountOff).invert().multiply(W);
  }});
  return e;
}
// a glowing beam between two moving mount-local points a(u, t) -> b(u, t) (shown while used)
function beam(M, a, b, d, color, op) { const Y = V3(0, 1, 0);
  return film(M, "cyl", [d, 1, 0], color, (u, tt) => { const A = V3(...a(u, tt)), B = V3(...b(u, tt)), dir = B.clone().sub(A), len = dir.length();
    return new THREE.Matrix4().compose(A.clone().add(B).multiplyScalar(0.5), new THREE.Quaternion().setFromUnitVectors(Y, dir.normalize()), V3(1, len, 1)); }, op, {show: u => u > 0.05}); }
// matrix blend (position lerp, rotation slerp)
function blendM(A, B, k) { const p0 = V3(), q0 = new THREE.Quaternion(), s0 = V3(), p1 = V3(), q1 = new THREE.Quaternion(), s1 = V3();
  A.decompose(p0, q0, s0); B.decompose(p1, q1, s1); return new THREE.Matrix4().compose(p0.lerp(p1, k), q0.slerp(q1, k), s0.lerp(s1, k)); }
// band of 4 thin boxes around a section running along local X (h = y size, d = z size)
function bandX(M, h, d, len, p, key) { const th = 0.07; key = key || "trim";
  M.box([len, th, d + th * 2], [p[0], p[1] + h / 2 + th / 2, p[2]], null, key); M.box([len, th, d + th * 2], [p[0], p[1] - h / 2 - th / 2, p[2]], null, key);
  M.box([len, h, th], [p[0], p[1], p[2] + d / 2 + th / 2], null, key); M.box([len, h, th], [p[0], p[1], p[2] - d / 2 - th / 2], null, key); }
// helix spring around local Y at c (radius r, height h, n turns); sq(u, t) = height factor
function coilY(M, c, r, h, n, th, key, sq) { const N = n * 10;
  for (let i = 0; i < N; i++) { const a = i / 10 * Math.PI * 2, f = i / N - 0.5;
    at(M, "box", [th, th, 2 * Math.PI * r / 10 * 1.15], key, (u, tt) => Tm(c[0] + Math.cos(a) * r, c[1] + f * h * (sq ? sq(u, tt) : 1), c[2] + Math.sin(a) * r).multiply(RYm(-a)).multiply(RXm(0.12))); } }
// rings that travel out along local +Y of base(u, t, d) and fade (sound / shock waves); shown only while used
function waves(M, n, period, base, color, r0, r1, tube) {
  for (let k = 0; k < n; k++) { const d = (tt) => ((tt / period + k / n) % 1);
    film(M, "ring", [1, tube || 0.06], color, (u, tt) => base(u, tt, d(tt)).multiply(RXm(Math.PI / 2)).multiply(SC(r0 + (r1 - r0) * d(tt), r0 + (r1 - r0) * d(tt), 1)), (u, tt) => u * (1 - d(tt)) * 0.9, {show: u => u > 0.05}); } }

// ---------- poses (joint -> [p, y, r] degrees) ----------
const ph = (tt, P) => (tt % P) / P;
function SNATCH(tt) { const g = Math.sin(tt * 5) * 4; return {RootJoint: [-3, 0, 0], Tail1: [-3, 10, 0], Tail2: [-6, 16, 0], Tail3: [-12, 20, 0], Tail4: [-22 + g, 16, 0], Tail5: [-28 + g, 8, 0]}; }
function SCORPION(tt) { const g = Math.sin(tt * 3) * 5; return {RootJoint: [-4, 0, 0], Tail1: [4, 0, 0], Tail2: [-4, 0, 0], Tail3: [-24, 0, 0], Tail4: [-55 + g, 0, 0], Tail5: [-55 + g, 0, 0], Neck: [6, 0, 0]}; }
function AIMTAIL(tt) { const g = Math.sin(tt * 1.5) * 4; return {Tail1: [-4, 6, 0], Tail2: [-8, 12 + g, 0], Tail3: [-10, 16 + g, 0], Tail4: [-8, 14, 0], Tail5: [-4, 10, 0]}; }
function TREB(tt) { const p = ph(tt, 1.8), wind = sm(p / 0.5) * (1 - sm((p - 0.5) / 0.12)), fling = sm((p - 0.5) / 0.14) * (1 - sm((p - 0.8) / 0.2));
  return {RootJoint: [-4 * wind + 6 * fling, 0, 0], Tail1: [16 * wind - 18 * fling, 0, 0], Tail2: [12 * wind - 20 * fling, 0, 0], Tail3: [8 * wind - 18 * fling, 0, 0], Tail4: [4 * wind - 8 * fling, 0, 0], Neck: [4 * fling, 0, 0]}; }
const BRACE = {RootJoint: [-4, 0, 0], Neck: [6, 0, 0]};
// rear up, slam (period 1.6): R = how high, I = the impact bump
function rearK(tt) { const p = ph(tt, 1.6); return {R: p < 0.55 ? sm(p / 0.55) : 1 - sm((p - 0.55) / 0.12), I: p > 0.66 && p < 0.86 ? Math.sin((p - 0.66) / 0.2 * Math.PI) : 0, p}; }
function REAR(tt) { const {R, I} = rearK(tt);
  return {RootJoint: [24 * R - 3 * I, 0, 0], ArmL: [38 * R, 0, 0], ArmR: [38 * R, 0, 0], LegL: [-24 * R, 0, 0], LegR: [-24 * R, 0, 0], Neck: [-12 * R + 8 * I, 0, 0], Head: [6 * I, 0, 0], Tail1: [10 * R, 0, 0], Tail2: [6 * R, 0, 0]}; }
function BELLOW(tt) { const b = Math.sin(tt * 6) * 3; return {RootJoint: [6, 0, 0], Neck: [22 + b, 0, 0], Head: [6, 0, 0], Jaw: [-28 + b, 0, 0], Tail1: [4, 0, 0]}; }
function HORN(tt) { const b = Math.sin(tt * 6) * 2; return {RootJoint: [6, 0, 0], Neck: [26 + b, 0, 0], Head: [-12, 0, 0], Jaw: [-6, 0, 0]}; }
function CALL(tt) { const b = Math.sin(tt * 2.2) * 6; return {RootJoint: [7, 0, 0], Neck: [16, b, 0], Head: [-4, 0, 0], Jaw: [-18, 0, 0], ArmL: [6, 0, 0], ArmR: [6, 0, 0]}; }
// crouch (charge) then spring (period 1.8): C = crouch, S = spring
function leapK(tt) { const p = ph(tt, 1.8); return {C: p < 0.55 ? sm(p / 0.55) : 1 - sm((p - 0.55) / 0.08), S: p > 0.55 && p < 0.82 ? Math.sin((p - 0.55) / 0.27 * Math.PI) : 0, p}; }
function LEAP(tt) { const {C, S} = leapK(tt);
  return {RootJoint: [-5 * C + 12 * S, 0, 0], LegL: [26 * C - 18 * S, 0, 0], LegR: [26 * C - 18 * S, 0, 0], KneeL: [-42 * C + 14 * S, 0, 0], KneeR: [-42 * C + 14 * S, 0, 0],
    AnkleL: [20 * C - 10 * S, 0, 0], AnkleR: [20 * C - 10 * S, 0, 0], ArmL: [-8 * C + 28 * S, 0, 0], ArmR: [-8 * C + 28 * S, 0, 0], Neck: [-6 * C + 10 * S, 0, 0], Tail1: [6 * C - 14 * S, 0, 0], Tail2: [-6 * S, 0, 0]}; }
function POGO(tt) { const {C, S} = leapK(tt);
  return {RootJoint: [-4 * C + 12 * S, 0, 0], LegL: [18 * C - 12 * S, 0, 0], LegR: [18 * C - 12 * S, 0, 0], KneeL: [-28 * C, 0, 0], KneeR: [-28 * C, 0, 0],
    Tail1: [22 * C - 30 * S, 0, 0], Tail2: [12 * C - 26 * S, 0, 0], Tail3: [6 * C - 20 * S, 0, 0], Tail4: [-10 * S, 0, 0], Neck: [10 * S, 0, 0]}; }
const GUARD = {RootJoint: [-4, 0, 0], Neck: [-10, 0, 0], Head: [4, 0, 0], ArmL: [8, 0, 0], ArmR: [8, 0, 0], Tail1: [-4, 0, 0]};

// ============================================ 1 · TAIL GRAB & FLING (attack) ============================================
// A · Snatch Claw — Horizon Forbidden West Clamberjaw "Snatch and Hurl": a tail that grabs, spins and throws
function grabSnatch() {
  const M = mountS("Tail5_main", [-1.5, 0, 0], 1.6);
  M.box([1.45, 0.66, 0.62], [-0.65, 0, 0], null, "shell"); M.box([1.3, 0.12, 0.7], [-0.65, 0.38, 0], null, "plate");
  M.hazard(1.1, 0.12, [-0.65, -0.12, 0.33], null, 6); M.hazard(1.1, 0.12, [-0.65, -0.12, -0.33], null, 6);
  for (const x of [-0.15, -1.15]) for (const z of [-0.33, 0.33]) M.bolt([x, 0.18, z], "z", 0.1);
  M.cyl([0.86, 0.32, 0], [-1.52, 0, 0], [90, 0, 0], "iron"); M.add("ring", [0.45, 0.06], [-1.52, 0, 0], [0, 90, 0], "brass");
  // the wrist spins (Clamberjaw spins its catch before the throw); fingers open / snap shut
  const spin = (u, tt) => tt * 0.6 + u * tt * 7, grip = (u, tt) => 0.15 + 0.85 * u * (0.5 + 0.5 * Math.sin(tt * 5));
  const W = (u, tt) => Tm(-1.7, 0, 0).multiply(RXm(spin(u, tt)));
  at(M, "box", [0.42, 0.66, 0.66], "shell", (u, tt) => W(u, tt).multiply(Tm(-0.2, 0, 0)));
  for (let k = 0; k < 4; k++) at(M, "box", [0.44, 0.08, 0.16], "brass", (u, tt) => W(u, tt).multiply(RXm(k * Math.PI / 2)).multiply(Tm(-0.2, 0.36, 0)));
  at(M, "cyl", [0.3, 0.06, 0], "glow", (u, tt) => W(u, tt).multiply(Tm(-0.42, 0, 0)).multiply(RZm(Math.PI / 2)));
  for (let k = 0; k < 3; k++) {
    const F = (u, tt) => W(u, tt).multiply(RXm(k * Math.PI * 2 / 3)).multiply(Tm(-0.35, 0.26, 0)).multiply(RZm(-rad(8 + 50 * grip(u, tt))));
    at(M, "ball", [0.24, 0.24, 0.24], "brass", (u, tt) => F(u, tt));
    at(M, "box", [0.85, 0.17, 0.2], "bone", (u, tt) => F(u, tt).multiply(Tm(-0.42, 0, 0)));
    const F2 = (u, tt) => F(u, tt).multiply(Tm(-0.85, 0, 0)).multiply(RZm(rad(60 - 30 * grip(u, tt))));
    at(M, "ball", [0.2, 0.2, 0.2], "brass", (u, tt) => F2(u, tt));
    at(M, "box", [0.62, 0.15, 0.18], "bone", (u, tt) => F2(u, tt).multiply(Tm(-0.3, 0, 0)));
    at(M, "box", [0.24, 0.1, 0.12], "glow", (u, tt) => F2(u, tt).multiply(Tm(-0.66, -0.03, 0)));
  }
  // hydraulic ram along the top of Tail4 into Tail5 (pushes the snap)
  const M4 = mountOn("Tail4_main");
  bandX(M4, 0.71, 0.61, 0.22, [0.6, 0, 0], "iron"); bandX(M4, 0.71, 0.61, 0.22, [-0.6, 0, 0], "iron");
  M4.cyl([0.32, 1.4, 0], [0.2, 0.55, 0], [90, 0, 0], "iron"); M4.box([0.3, 0.2, 0.2], [0.95, 0.45, 0], null, "dark");
  at(M4, "cyl", [0.17, 1.5, 0], "steel", (u, tt) => Tm(-1.1 - u * 0.25 * (0.5 + 0.5 * Math.sin(tt * 5)), 0.55, 0).multiply(RZm(Math.PI / 2)));
  M4.hose([0.9, 0.4, 0.2], [-0.4, 0.2, 0.36], 0.18, 0.12, 5);
}
// B · Pincer Tail — Zoids Death Stinger: a segmented, armour-plated tail ending in a big claw
function grabPincer() {
  const T = [["Tail2_main", 3.48, 1.58, 1.32], ["Tail3_main", 3.43, 1.1, 0.93], ["Tail4_main", 3.38, 0.71, 0.61], ["Tail5_main", 3.28, 0.41, 0.37]];
  for (const [n, L, h, d] of T) { const M = mountOn(n), top = h / 2 + 0.1;
    for (const f of [0.25, -0.25]) { M.box([L * 0.48, 0.14, d + 0.22], [f * L, top + 0.02, 0], [-5, 0, 0], "shell"); M.box([L * 0.4, 0.06, 0.1], [f * L, top + 0.12, 0], [-5, 0, 0], "glow"); }
    for (const s of [1, -1]) M.box([L * 0.9, h * 0.6, 0.08], [0, 0.05, s * (d / 2 + 0.04)], null, "plate");
  }
  const M = mountS("Tail5_main", [-1.6, 0, 0], 1.7);
  M.box([0.6, 0.62, 0.8], [-1.65, 0, 0], null, "iron"); M.cyl([0.3, 0.75, 0], [-1.9, 0, 0], null, "brass");
  M.bolt([-1.65, 0.33, 0.25], "y", 0.12); M.bolt([-1.65, 0.33, -0.25], "y", 0.12);
  const open = (u, tt) => rad(8) + u * rad(38) * Math.pow(Math.abs(Math.sin(tt * 3)), 0.35);
  for (const s of [1, -1]) {
    const H = (u, tt) => Tm(-1.95, 0, s * 0.18).multiply(RYm(s * open(u, tt)));
    at(M, "box", [0.95, 0.34, 0.16], "bone", (u, tt) => H(u, tt).multiply(Tm(-0.47, 0, 0)));
    const H2 = (u, tt) => H(u, tt).multiply(Tm(-0.92, 0, 0)).multiply(RYm(-s * 0.55));
    at(M, "box", [0.8, 0.3, 0.14], "bone", (u, tt) => H2(u, tt).multiply(Tm(-0.38, 0, 0)));
    const H3 = (u, tt) => H2(u, tt).multiply(Tm(-0.76, 0, 0)).multiply(RYm(-s * 0.6));
    at(M, "box", [0.45, 0.22, 0.12], "bone", (u, tt) => H3(u, tt).multiply(Tm(-0.2, 0, 0)));
    at(M, "box", [1.4, 0.06, 0.05], "glow", (u, tt) => H(u, tt).multiply(Tm(-0.7, 0, -s * 0.09)).multiply(RYm(-s * 0.28)));
  }
}
// C · Gravity Grapple — Horizon Forbidden West Rollerback "Gravity Generator" (pulls its own torn-off plates back on)
function grabGrav() {
  const M4 = mountOn("Tail4_main");
  M4.box([1.5, 0.5, 0.86], [0.2, 0.55, 0], null, "shell"); M4.box([1.3, 0.1, 0.92], [0.2, 0.84, 0], null, "trim");
  for (let i = 0; i < 5; i++) M4.box([0.06, 0.32, 0.8], [-0.3 + i * 0.25, 1.05, 0], null, "iron");
  for (const z of [0.46, -0.46]) { M4.cyl([0.16, 1.1, 0], [0.2, 0.45, z], [90, 0, 0], "glow"); M4.cyl([0.24, 0.12, 0], [0.8, 0.45, z], [90, 0, 0], "brass"); M4.cyl([0.24, 0.12, 0], [-0.4, 0.45, z], [90, 0, 0], "brass"); }
  const M = mountS("Tail5_main", [-1.5, 0, 0], 1.5);
  M.box([1.2, 0.56, 0.52], [-0.7, 0, 0], null, "iron");
  M.add("cone", [1.2, 0.55], [-1.75, 0, 0], [-90, 0, 0], "dark"); M.add("ring", [0.6, 0.06], [-2.02, 0, 0], [0, 90, 0], "brass");
  M.ball(0.34, [-1.95, 0, 0], "glow");
  // three gimbal rings that spin around the tail tip, spread apart and spin faster when pulling
  [[0.62, 1.3, 25], [0.8, -1.7, -35], [0.98, 2.1, 50]].forEach(([r, sp, tilt], k) => {
    const R = (u, tt) => Tm(-1.0 - k * (0.32 + 0.35 * u), 0, 0).multiply(RXm(tt * sp * (1 + 3 * u))).multiply(RYm(Math.PI / 2 + rad(tilt)));
    at(M, "ring", [r, 0.07], k === 1 ? "brass" : "steel", R);
    for (let j = 0; j < 3; j++) at(M, "box", [0.14, 0.14, 0.14], "glow", (u, tt) => R(u, tt).multiply(RZm(j * Math.PI * 2 / 3)).multiply(Tm(r, 0, 0)));
  });
  // the pull beam (only while used)
  film(M, "cone", [2.6, 3.2], RED, (u, tt) => Tm(-2.05 - 1.6 * u, 0, 0).multiply(rot(90, 0, 0)).multiply(SC(u, u, u)), (u, tt) => u * (0.25 + 0.08 * Math.sin(tt * 20)), {show: u => u > 0.05});
}
function oldGrab() { const M = mountOn("Tail5_main"); M.box([0.9, 0.55, 0.5], [-1.2, 0, 0], null, "steel");
  for (const s of [1, -1]) { const H = Tm(-1.65, 0, 0).multiply(RYm(s * 0.54));
    at(M, "box", [1.2, 0.18, 0.18], "dark", () => H.clone().multiply(Tm(-0.55, 0, s * 0.18))); at(M, "box", [0.25, 0.25, 0.25], "white", () => H.clone().multiply(Tm(-1.1, 0, s * 0.18)), {color: RED}); } }

// ============================================ 2 · BOULDER MORTAR (attack) ============================================
// A · Force Loaders — Horizon Zero Dawn Behemoth: anti-grav "Force Loaders" lift boulders and hurl them
function mortarLoader() {
  const M = mountC("Torso_hips", [0, 0, 0.3], null, [0, 1.15, 0], 1.45);
  M.box([2.0, 0.28, 1.0], [0, 1.15, 0], null, "shell"); M.box([2.1, 0.08, 0.6], [0, 1.32, 0], null, "trim");
  const lift = (u, tt) => 2.75 + Math.sin(tt * 1.6) * 0.1 + u * (0.6 + 0.25 * Math.sin(tt * 3));
  for (const s of [1, -1]) {
    M.box([0.5, 0.45, 0.8], [s * 1.05, 1.4, 0], null, "shell"); M.cyl([0.34, 1.3, 0], [s * 1.18, 2.1, 0], [-s * 8, 0, 0], "steel");
    for (const y of [1.75, 2.25]) M.add("ring", [0.22, 0.05], [s * 1.2, y, 0], [0, 0, 90], "brass");
    M.box([0.55, 0.5, 0.7], [s * 1.25, 2.85, 0], null, "shell"); M.wedge([0.55, 0.3, 0.7], [s * 1.25, 3.25, 0], [0, s * 90, 0], "plate");
    M.add("cone", [0.6, 0.3], [s * 0.88, 2.85, 0], [s * 90, 0, 0], "dark"); M.ball(0.22, [s * 0.86, 2.85, 0], "glow");
    at(M, "ring", [0.42, 0.06], "brass", (u, tt) => Tm(s * 1.0, 2.85, 0).multiply(RXm(tt * (1 + 5 * u) * s)).multiply(RYm(Math.PI / 2 + 0.4)));
    M.hose([s * 1.3, 2.6, 0.3], [s * 1.0, 1.4, 0.45], 0.1, 0.14, 4);
    // the beam to the boulder (while used)
    beam(M, () => [s * 0.84, 2.85, 0], (u, tt) => [s * 0.5, lift(u, tt), 0], 0.14, RED, (u, tt) => u * (0.6 + 0.3 * Math.sin(tt * 25)));
  }
  // the floating boulder, spinning
  const B = (u, tt) => Tm(0, lift(u, tt), 0).multiply(RYm(tt * (0.5 + 3 * u))).multiply(RXm(tt * 0.3));
  at(M, "ball", [1.15, 1.15, 1.15], "rock", B);
  for (const [x, y, z, s] of [[0.35, 0.3, 0.1, 0.5], [-0.3, -0.2, 0.3, 0.55], [0.1, -0.35, -0.3, 0.45], [-0.2, 0.35, -0.25, 0.4]]) at(M, "box", [s, s * 0.8, s], "rock", (u, tt) => B(u, tt).multiply(Tm(x, y, z)).multiply(rot(20, 30, 10)));
  at(M, "ring", [0.8, 0.05], "glow", (u, tt) => Tm(0, lift(u, tt), 0).multiply(RXm(Math.PI / 2 + Math.sin(tt * 2) * 0.3)));
}
// B · Back Cannon — Zoids Gordos (guns on the back) + Horizon Ravager Cannon (a short charge-up before each shot)
function mortarCannon() {
  const M = mountC("Torso_barrel", [0, 0, -0.7], null, [0, 1.05, 0], 1.35);
  M.cyl([1.35, 0.16, 0], [0, 1.05, 0], null, "brass"); M.box([1.15, 0.55, 1.25], [0, 1.4, 0.05], null, "shell");
  for (const s of [1, -1]) { M.box([0.14, 0.75, 0.9], [s * 0.5, 1.75, 0], null, "plate"); M.cyl([0.4, 0.16, 0], [s * 0.6, 1.8, 0], [90, 0, 0], "brass"); }
  const cyc = (tt) => (tt % 1.4) / 1.4; // charge 0..0.8, fire at 0.8
  const elev = u => rad(32 + 26 * u), kick = (u, tt) => u * (cyc(tt) > 0.8 ? (1 - (cyc(tt) - 0.8) / 0.2) * 0.4 : 0);
  const Bm = (u, tt) => Tm(0, 1.8, 0).multiply(RXm(elev(u) - Math.PI / 2)).multiply(Tm(0, -kick(u, tt), 0));
  at(M, "box", [0.78, 0.85, 0.78], "iron", (u, tt) => Bm(u, tt));
  at(M, "cyl", [0.66, 2.0, 0], "dark", (u, tt) => Bm(u, tt).multiply(Tm(0, 1.3, 0)));
  at(M, "box", [0.86, 0.38, 0.86], "iron", (u, tt) => Bm(u, tt).multiply(Tm(0, 2.35, 0)));
  for (const a of [0, Math.PI / 2]) at(M, "box", [0.92, 0.1, 0.12], "trim", (u, tt) => Bm(u, tt).multiply(Tm(0, 2.35, 0)).multiply(RYm(a)));
  for (let k = 0; k < 4; k++) {
    at(M, "ring", [0.37, 0.05], "trim", (u, tt) => Bm(u, tt).multiply(Tm(0, 0.65 + k * 0.38, 0)).multiply(RXm(Math.PI / 2)));
    at(M, "ring", [0.38, 0.055], "glow", (u, tt) => Bm(u, tt).multiply(Tm(0, 0.65 + k * 0.38, 0)).multiply(RXm(Math.PI / 2)), {show: (u, tt) => u > 0.3 && cyc(tt) * 5 > k + 0.5});
  }
  film(M, "ball", [1, 1, 1], ORANGE, (u, tt) => Bm(u, tt).multiply(Tm(0, 2.8, 0)).multiply(SC(1.2, 1.6, 1.2)), (u, tt) => u * (cyc(tt) > 0.8 ? 1 - (cyc(tt) - 0.8) / 0.2 : 0), {show: (u, tt) => u > 0.3 && cyc(tt) > 0.8});
  // ammo hopper on the camera side with three boulders feeding the breech
  M.box([0.6, 0.65, 1.0], [0.95, 1.45, 0.25], null, "shell"); M.box([0.66, 0.08, 1.06], [0.95, 1.8, 0.25], null, "hazY");
  for (const z of [-0.05, 0.3, 0.6]) M.ball(0.42, [0.95, 1.98, z], "rock");
  M.hose([0.7, 1.35, -0.2], [0.35, 1.5, -0.3], 0.05, 0.2, 3);
}
// C · Tail Trebuchet — Age of Empires trebuchet: a counterweight swings, the long arm whips the load over the top
function mortarTreb() {
  const M3 = mountS("Tail3_main", [0.15, 0.6, 0], 1.4);
  bandX(M3, 1.1, 0.93, 0.25, [0.8, 0, 0], "iron"); bandX(M3, 1.1, 0.93, 0.25, [-0.5, 0, 0], "iron");
  M3.box([1.25, 0.14, 1.15], [0.15, 0.72, 0], null, "steel");
  for (const z of [0.58, -0.58]) M3.box([1.25, 0.5, 0.1], [0.15, 0.98, z], null, "plate");
  for (const x of [0.78, -0.48]) M3.box([0.1, 0.5, 1.15], [x, 0.98, 0], null, "plate");
  const fly = (u, tt) => { const p = ph(tt, 1.8); return u > 0.3 && p > 0.58 && p < 0.95; };
  M3.ball(0.95, [0.15, 1.3, 0], "rock", {show: (u, tt) => !fly(u, tt)});
  M3.box([0.45, 0.35, 0.4], [0.35, 1.45, 0.2], [15, 20, 0], "rock", {show: (u, tt) => !fly(u, tt)});
  const M1 = mountS("Tail1_main", [-0.3, -1.1, 0], 1.25);
  bandX(M1, 2.25, 1.83, 0.3, [0.9, 0, 0], "iron");
  M1.cyl([0.3, 2.3, 0], [0.4, -1.3, 0], [0, 0, 90], "brass");
  for (const z of [1.0, -1.0]) M1.box([0.25, 0.6, 0.12], [0.4, -1.0, z], null, "iron");
  // the counterweight hangs from a pin under the tail and swings
  const CW = (u, tt) => { const p = ph(tt, 1.8), sw = u * (Math.sin(p * Math.PI * 2) * 0.5); return Tm(0.4, -1.3, 0).multiply(RZm(sw)); };
  at(M1, "box", [0.2, 0.7, 0.2], "steel", (u, tt) => CW(u, tt).multiply(Tm(0, -0.35, 0.6))); at(M1, "box", [0.2, 0.7, 0.2], "steel", (u, tt) => CW(u, tt).multiply(Tm(0, -0.35, -0.6)));
  at(M1, "box", [1.1, 0.85, 1.3], "iron", (u, tt) => CW(u, tt).multiply(Tm(0, -1.05, 0)));
  for (let i = 0; i < 6; i++) at(M1, "box", [0.18, 0.86, 0.03], i % 2 ? "hazK" : "hazY", (u, tt) => CW(u, tt).multiply(Tm(-0.45 + i * 0.18, -1.05, 0.66)));
  M1.cyl([0.9, 0.3, 0], [-0.6, 1.25, 0], [0, 0, 90], "brass"); M1.cyl([0.5, 0.36, 0], [-0.6, 1.25, 0], [0, 0, 90], "steel");
  cable("Tail1_main", M1.toRest([-0.6, 1.3, 0]), "Tail3_main", M3.toRest([0.75, 1.0, 0]), 0.4, 0.1);
}
function oldMortar() { const M = mountOn("Tail3_main"); M.box([1.2, 0.18, 1.1], [0.1, 0.62, 0], null, "steel");
  for (const z of [0.55, -0.55]) M.box([1.2, 0.6, 0.12], [0.1, 0.92, z], null, "dark"); for (const x of [0.66, -0.46]) M.box([0.12, 0.6, 1.1], [x, 0.92, 0], null, "dark");
  M.box([0.85, 0.85, 0.85], [0.1, 1.1, 0], [20, 20, 0], "rock"); }

// ============================================ 3 · STOMP SHOCKWAVE (defense) ============================================
// a shock ring on the ground in front of the front feet, at the slam of REAR (period 1.6)
function shockRing(color) {
  const M = mount("FootL_meta", [0, -3.33, -2.45]);
  for (const k of [0, 1]) film(M, "ring", [1, 0.1], color, (u, tt) => { const {p} = rearK(tt), d = Math.max(0, (p - 0.66 - k * 0.06) / 0.3); return Tm(-0.72, 0.05, 0).multiply(RXm(Math.PI / 2)).multiply(SC(0.6 + d * 5, 0.6 + d * 5, 1)); },
    (u, tt) => { const {p} = rearK(tt), d = (p - 0.66 - k * 0.06) / 0.3; return d > 0 && d < 1 ? u * (1 - d) : 0; }, {show: u => u > 0.05});
}
// A · Quake Hooves — Horizon Zero Dawn Behemoth "Quake Smash": rears up and smashes down, sending a shockwave forward
function stompQuake() {
  for (const [s, side] of SIDES) {
    const H = mountS(`Arm${side}_hand`, [0, -0.15, 0], 1.25);
    H.box([0.92, 0.52, 0.86], [0.05, 0.08, 0], null, "shell"); H.box([1.02, 0.14, 0.96], [0.05, -0.22, 0], null, "iron");
    H.wedge([0.86, 0.3, 0.3], [0.5, 0.14, 0], [0, -90, 0], "plate");
    for (const [x, z] of [[0.48, 0.3], [0.48, -0.3], [-0.4, 0.3], [-0.4, -0.3]]) H.box([0.14, 0.08, 0.14], [x, -0.3, z], null, "glow");
    const spin = (u, tt) => tt * (0.8 + 12 * u * rearK(tt).R);
    at(H, "ring", [0.62, 0.07], "brass", (u, tt) => Tm(0.05, 0.42, 0).multiply(RXm(Math.PI / 2)).multiply(RZm(spin(u, tt))));
    for (let k = 0; k < 6; k++) at(H, "box", [0.2, 0.18, 0.09], "iron", (u, tt) => Tm(0.05, 0.42, 0).multiply(RYm(spin(u, tt) + k * Math.PI / 3)).multiply(Tm(0.62, 0, 0)));
    for (let k = 0; k < 6; k++) at(H, "box", [0.07, 0.07, 0.07], "glow", (u, tt) => Tm(0.05, 0.42, 0).multiply(RYm(spin(u, tt) + k * Math.PI / 3 + 0.5)).multiply(Tm(0.62, 0.05, 0)));
    const F = mountOn(`Arm${side}_fore`);
    F.cyl([0.28, 0.75, 0], [0.32, 0.15, 0], null, "iron"); F.box([0.34, 0.16, 0.34], [0.32, 0.55, 0], null, "dark");
    at(F, "cyl", [0.15, 0.7, 0], "steel", (u, tt) => Tm(0.32, -0.45 - 0.12 * u * rearK(tt).I, 0));
    bandX(F, 1.0, 0.37, 0.12, [0, 0.4, 0], "trim");
    // shoulder exhaust stacks that puff at the slam
    const S = mountC("Torso_chest", [s * 0.78, 0.25, -2.0], null, [0, 0, 0], 1.6);
    S.cyl([0.3, 0.95, 0], [0, 0.35, 0.15], [0, 0, 18], "iron"); S.cyl([0.38, 0.12, 0], [0, 0.85, 0.3], [0, 0, 18], "brass");
    film(S, "ball", [1, 1, 1], BLUE, (u, tt) => { const I = rearK(tt).I; return Tm(0, 1.05 + I * 0.4, 0.38 + I * 0.2).multiply(SC(0.3 + I * 0.6, 0.3 + I * 0.6, 0.3 + I * 0.6)); }, (u, tt) => u * rearK(tt).I * 0.7, {show: u => u > 0.05});
  }
  shockRing(BLUE);
}
// B · Elbow Rockets — Pacific Rim Gipsy Danger "Elbow Rocket": thrusters on the back of the arm fire to drive the blow
function stompRocket() {
  for (const [s, side] of SIDES) {
    const U = mountS(`Arm${side}_upper`, [-0.42, -0.1, 0], 1.8);
    U.cyl([0.55, 1.05, 0], [-0.42, -0.1, 0], null, "shell"); U.add("ring", [0.29, 0.05], [-0.42, 0.25, 0], [0, 0, 90], "brass"); U.add("ring", [0.29, 0.05], [-0.42, -0.45, 0], [0, 0, 90], "brass");
    U.box([0.36, 0.7, 0.2], [-0.1, -0.1, 0], null, "dark");
    const fire = (u, tt) => { const p = rearK(tt).p; return u * (p > 0.5 && p < 0.72 ? Math.sin((p - 0.5) / 0.22 * Math.PI) : 0); };
    for (const [dx, dz] of [[0, 0.14], [0, -0.14], [-0.16, 0]]) {
      U.add("cone", [0.3, 0.32], [-0.42 + dx, 0.6, dz], [180, 0, 0], "iron");
      film(U, "cone", [0.26, 1], BLUE, (u, tt) => Tm(-0.42 + dx, 0.76 + fire(u, tt) * 0.8, dz).multiply(SC(1, 0.1 + fire(u, tt) * 1.6, 1)), (u, tt) => 0.25 + fire(u, tt) * 0.7, {show: (u, tt) => fire(u, tt) > 0.02});
    }
    for (let k = 0; k < 4; k++) { const a = k * Math.PI / 2 + Math.PI / 4;
      at(U, "box", [0.3, 0.42, 0.05], "plate", (u, tt) => Tm(-0.42, 0.42, 0).multiply(RYm(a)).multiply(Tm(0, 0, 0.3)).multiply(RXm(rad(10 + 35 * Math.min(1, fire(u, tt) * 2 + u * 0.3)))).multiply(Tm(0, 0.2, 0))); }
    const H = mountS(`Arm${side}_hand`, [0, -0.15, 0], 1.2);
    H.box([0.8, 0.46, 0.72], [0.04, 0.03, 0], null, "steel"); H.box([0.86, 0.12, 0.78], [0.04, -0.17, 0], null, "dark");
    for (const z of [0.37, -0.37]) H.box([0.6, 0.08, 0.03], [0.04, 0.12, z], null, "glow");
  }
  shockRing(BLUE);
}
// C · Pile Bunkers — Armored Core pile bunker: a revolver of charges drives a steel spike, then it snaps back
function stompPile() {
  for (const [s, side] of SIDES) {
    const F = mountOn(`Arm${side}_fore`);
    F.box([0.42, 1.0, 0.5], [0.3, 0.05, 0], null, "shell"); bandX(F, 1.0, 0.37, 0.14, [0, 0.42, 0], "trim");
    const turn = (u, tt) => { const p = rearK(tt).p; return Math.floor(tt / 1.6) * Math.PI / 3 + (p > 0.7 ? sm((p - 0.7) / 0.15) * Math.PI / 3 : 0); };
    at(F, "cyl", [0.5, 0.42, 0], "iron", (u, tt) => Tm(0.62, 0.15, 0).multiply(RYm(turn(u, tt))));
    for (let k = 0; k < 6; k++) at(F, "cyl", [0.12, 0.46, 0], "brass", (u, tt) => Tm(0.62, 0.15, 0).multiply(RYm(turn(u, tt) + k * Math.PI / 3)).multiply(Tm(0.21, 0, 0)));
    const drive = (u, tt) => u * rearK(tt).I * 0.55;
    at(F, "cyl", [0.2, 1.3, 0], "steel", (u, tt) => Tm(0.62, -0.7 - drive(u, tt), 0));
    at(F, "cone", [0.32, 0.45, 0], "steel", (u, tt) => Tm(0.62, -1.55 - drive(u, tt), 0).multiply(RXm(Math.PI)));
    at(F, "cyl", [0.36, 0.12, 0], "hazY", (u, tt) => Tm(0.62, -0.32, 0));
    // the spent case flies out at the slam
    at(F, "cyl", [0.12, 0.3, 0], "brass", (u, tt) => { const p = rearK(tt).p, d = Math.max(0, (p - 0.7) / 0.3); return Tm(0.62 + d * 0.6, 0.35 + d * 0.8 - d * d * 1.2, s * d * 0.5).multiply(RZm(d * 8)); }, {show: (u, tt) => u > 0.3 && rearK(tt).p > 0.7});
    const H = mountOn(`Arm${side}_hand`); H.box([0.7, 0.4, 0.64], [-0.05, 0.05, 0], null, "steel");
  }
  shockRing(BLUE);
}
function oldStomp() { for (const [s, side] of SIDES) { const H = mountOn(`Arm${side}_hand`);
  H.box([0.78, 0.46, 0.7], [0.04, 0.03, 0], null, "steel"); H.box([0.84, 0.1, 0.76], [0.04, -0.17, 0], null, "dark");
  for (const x of [-0.24, 0.24]) for (const z of [-0.36, 0.36]) { H.box([0.1, 0.1, 0.05], [0.04 + x, 0.08, z], null, "dark"); H.box([0.1, 0.1, 0.05], [0.04 + x, -0.06, z], null, "dark"); } } }

// ============================================ 4 · HERD BELLOW (health) ============================================
const mouthWaves = (color) => waves(mountOn("Head_snout"), 3, 0.9, (u, tt, d) => Tm(0.9 + d * 2.6, -0.2, 0).multiply(RZm(-Math.PI / 2)), color, 0.4, 1.6, 0.07);
// A · Shriek Sacs — Horizon Zero Dawn Longleg: inflatable "concussion sacs" on its chest for a sonic shriek
function bellowSacs() {
  const M = mountOn("Neck_base");
  for (const s of [1, -1]) {
    const pump = (u, tt) => 1 + u * 0.35 * (0.5 + 0.5 * Math.sin(tt * 6)) + 0.04 * Math.sin(tt * 2);
    film(M, "ball", [1, 1, 1], 0x7dffb0, (u, tt) => Tm(0.05, -0.25, s * 0.62).multiply(SC(0.95 * pump(u, tt), 0.8 * pump(u, tt), 0.7 * pump(u, tt))), (u, tt) => 0.55 + 0.25 * u);
    for (const r of [-0.25, 0, 0.25]) at(M, "ring", [0.44, 0.04], "iron", (u, tt) => Tm(0.05 + r, -0.25, s * 0.62).multiply(RYm(Math.PI / 2)).multiply(SC(pump(u, tt) * (1 - Math.abs(r)), pump(u, tt) * 0.85 * (1 - Math.abs(r)), 1)));
    M.box([0.9, 0.12, 0.12], [0.05, 0.2, s * 0.6], null, "iron"); M.cyl([0.2, 0.25, 0], [0.05, 0.32, s * 0.66], null, "brass"); M.cyl([0.12, 0.1, 0], [0.05, 0.47, s * 0.66], null, "glow");
  }
  bandX(M, 1.22, 1.01, 0.16, [0.4, 0, 0], "trim");
  mouthWaves(GREEN);
}
// B · Crest Horn — Monster Hunter Hunting Horn (a horn whose songs buff the whole team), built as a duck-bill dino crest
function bellowHorn() {
  const M = mountS("Head_cranium", [0.2, 0.5, 0], 1.3);
  const P = [[0.95, 0.42, 0], [0.45, 0.62, 0], [-0.15, 0.82, 0], [-0.75, 1.1, 0], [-1.25, 1.45, 0]];
  for (let i = 0; i < P.length - 1; i++) rod(M, P[i], P[i + 1], 0.3, "brass");
  for (let i = 1; i < P.length - 1; i++) M.ball(0.34, P[i], "brass");
  M.box([0.9, 0.16, 0.5], [0.35, 0.5, 0], null, "dark");
  M.add("cone", [0.95, 0.75], [-1.5, 1.68, 0], [-215, 0, 0], "brass"); M.cyl([0.75, 0.04, 0], [-1.63, 1.86, 0], [-125, 0, 0], "glow");
  for (let k = 0; k < 3; k++) { const x = 0.25 - k * 0.32, y = 0.82 - (x < -0.15 ? (x + 0.15) * 0.45 : -(x + 0.15) * 0.33);
    M.cyl([0.18, 0.3, 0], [x, y + 0.22, 0], null, "iron");
    at(M, "cyl", [0.1, 0.3, 0], "steel", (u, tt) => Tm(x, y + 0.42 - 0.12 * u * Math.abs(Math.sin(tt * 8 + k * 1.3)), 0));
    at(M, "cyl", [0.2, 0.06, 0], "glow", (u, tt) => Tm(x, y + 0.58 - 0.12 * u * Math.abs(Math.sin(tt * 8 + k * 1.3)), 0)); }
  waves(M, 3, 0.9, (u, tt, d) => Tm(-1.75 - d * 1.6, 1.9 + d * 1.1, 0).multiply(RZm(rad(55))), GREEN, 0.45, 1.5, 0.07);
}
// C · Amp Stack — Overwatch Lúcio: his songs give the team a speed boost and "Sound Barrier" shields
function bellowAmp() {
  const M = mountC("Torso_barrel", [0, 1.02, -1.1], [0, 0, -8], [0, 0, 0], 1.3);
  M.box([1.7, 0.2, 1.8], [0, 0, 0], null, "shell"); for (const s of [1, -1]) M.box([0.12, 0.35, 1.8], [s * 0.86, -0.1, 0], null, "trim");
  for (const s of [1, -1]) {
    const C = new THREE.Matrix4().makeTranslation(s * 0.5, 0.6, 0.25).multiply(rot(0, s * 18, -28));
    at(M, "box", [0.85, 1.0, 0.7], "dark", () => C.clone());
    at(M, "ring", [0.34, 0.05], "brass", () => C.clone().multiply(Tm(0, 0.05, 0.36)));
    at(M, "cyl", [0.62, 0.1, 0], "rubber", (u, tt) => C.clone().multiply(Tm(0, 0.05, 0.36 + u * 0.06 * Math.max(0, Math.sin(tt * 12)))).multiply(RXm(Math.PI / 2)));
    at(M, "cyl", [0.22, 0.06, 0], "glow", (u, tt) => C.clone().multiply(Tm(0, 0.05, 0.43 + u * 0.06 * Math.max(0, Math.sin(tt * 12)))).multiply(RXm(Math.PI / 2)));
    at(M, "cyl", [0.22, 0.06, 0], "steel", () => C.clone().multiply(Tm(0, -0.35, 0.36)).multiply(RXm(Math.PI / 2)));
    waves(M, 2, 0.7, (u, tt, d) => C.clone().multiply(Tm(0, 0.05, 0.45 + d * 1.6)).multiply(RXm(-Math.PI / 2)), GREEN, 0.35, 1.2, 0.06);
  }
  // the record deck in the middle spins; the level bars bounce to the beat
  at(M, "cyl", [0.7, 0.06, 0], "rubber", (u, tt) => Tm(0, 0.14, -0.6).multiply(RYm(tt * (1 + 6 * u))));
  at(M, "box", [0.6, 0.07, 0.06], "glow", (u, tt) => Tm(0, 0.18, -0.6).multiply(RYm(tt * (1 + 6 * u))));
  for (let i = 0; i < 6; i++) at(M, "box", [0.1, 1, 0.1], "glow", (u, tt) => { const h = 0.1 + (0.15 + 0.5 * u) * Math.abs(Math.sin(tt * (5 + i) + i)); return Tm(-0.5 + i * 0.2, 0.1 + h / 2, 0.75).multiply(SC(1, h, 1)); });
}
function oldBellow() { const M = mountOn("Head_cranium");
  for (const z of [0.6, -0.6]) { M.box([0.55, 0.6, 0.25], [-0.05, 0.05, z], null, "dark"); M.box([0.38, 0.38, 0.06], [-0.05, 0.05, z + (z > 0 ? 0.14 : -0.14)], null, "white", {color: 0x7fe9ff}); }
  M.box([0.2, 0.12, 1.25], [-0.05, 0.42, 0], null, "steel"); }

// ============================================ 5 · CHALLENGE CALL (defense) ============================================
// A · War Banner — the samurai sashimono (Total War: Shogun 2 units wear them): a back flag on an L-frame that says "come at me"
function challengeBanner() {
  const M = mount("Torso_barrel", [0, 0, -0.6]);
  M.box([0.7, 0.3, 0.7], [0, 1.08, 0], null, "shell"); M.cyl([0.36, 0.3, 0], [0, 1.3, 0], null, "brass");
  const lean = (u, tt) => RXm(-u * rad(12) + Math.sin(tt * 1.3) * 0.02);
  const Pm = (u, tt) => Tm(0, 1.3, 0).multiply(lean(u, tt));
  at(M, "cyl", [0.16, 3.6, 0], "iron", (u, tt) => Pm(u, tt).multiply(Tm(0, 1.8, 0)));
  at(M, "ring", [0.16, 0.05], "brass", (u, tt) => Pm(u, tt).multiply(Tm(0, 1.0, 0)).multiply(RXm(Math.PI / 2)));
  at(M, "cyl", [0.12, 1.5, 0], "iron", (u, tt) => Pm(u, tt).multiply(Tm(0, 3.5, 0.72)).multiply(RXm(Math.PI / 2)));
  at(M, "ball", [0.26, 0.26, 0.26], "glow", (u, tt) => Pm(u, tt).multiply(Tm(0, 3.68, 0)));
  const N = 6, W = 1.38 / N;
  for (let k = 0; k < N; k++) {
    const wave = (u, tt) => Math.sin(tt * (2.5 + 5 * u) - k * 0.9) * (0.06 + 0.1 * u) * (k + 1) / N;
    at(M, "box", [0.05, 2.3, W * 1.05], k === 0 ? "clothW" : "cloth", (u, tt) => Pm(u, tt).multiply(Tm(wave(u, tt), 2.3, 0.08 + W * (k + 0.5))).multiply(RYm(wave(u, tt) * 2)));
    if (k >= 2 && k <= 3) for (const y of [2.0, 2.6]) at(M, "box", [0.07, 0.36, W * 1.06], "glow", (u, tt) => Pm(u, tt).multiply(Tm(wave(u, tt) + 0.02, y, 0.08 + W * (k + 0.5))).multiply(RYm(wave(u, tt) * 2)).multiply(RXm(Math.PI / 4)));
  }
  for (let k = 0; k < N; k++) at(M, "box", [0.06, 0.12, W * 1.05], "clothW", (u, tt) => { const w = Math.sin(tt * (2.5 + 5 * u) - k * 0.9) * (0.06 + 0.1 * u) * (k + 1) / N; return Pm(u, tt).multiply(Tm(w, 1.2, 0.08 + W * (k + 0.5))); });
}
// B · Watcher Eye — Horizon Zero Dawn Watcher: one big glowing eye on a long neck that tracks threats and calls the herd
function challengeEye() {
  const M = mount("Torso_chest", [0, 0.42, -1.95]);
  M.box([0.85, 0.35, 0.85], [0, 0.05, 0], null, "shell"); M.cyl([0.6, 0.15, 0], [0, 0.28, 0], null, "brass");
  const ext = u => 0.35 + 0.65 * u;
  [[0.4, "iron"], [0.3, "steel"], [0.22, "steel"]].forEach(([d, k], i) => at(M, "cyl", [d, 1.05, 0], k, u => Tm(0, 0.8 + i * 0.85 * ext(u), 0)));
  const Hd = (u, tt) => Tm(0, 0.8 + 2 * 0.85 * ext(u) + 0.65, 0).multiply(RYm(Math.sin(tt * 1.1) * (0.9 - 0.5 * u))).multiply(RXm(-0.15 + 0.1 * Math.sin(tt * 0.7)));
  at(M, "box", [0.75, 0.6, 0.7], "shell", Hd); at(M, "box", [0.8, 0.12, 0.75], "trim", (u, tt) => Hd(u, tt).multiply(Tm(0, 0.33, 0)));
  at(M, "cyl", [0.5, 0.12, 0], "dark", (u, tt) => Hd(u, tt).multiply(Tm(0, 0, -0.38)).multiply(RXm(Math.PI / 2)));
  at(M, "cyl", [0.38, 0.08, 0], "glow", (u, tt) => Hd(u, tt).multiply(Tm(0, 0, -0.44)).multiply(RXm(Math.PI / 2)));
  const blink = (tt) => (tt % 3.2) > 3.05 ? 1 : 0;
  for (const s of [1, -1]) at(M, "box", [0.6, 0.06, 0.12], "plate", (u, tt) => Hd(u, tt).multiply(Tm(0, s * (0.28 - 0.17 * blink(tt)), -0.46)));
  at(M, "box", [0.06, 0.5, 0.06], "steel", (u, tt) => Hd(u, tt).multiply(Tm(0.25, 0.55, 0.2))); at(M, "ball", [0.12, 0.12, 0.12], "glow", (u, tt) => Hd(u, tt).multiply(Tm(0.25, 0.82, 0.2)));
  film(M, "cone", [3.2, 6], BLUE, (u, tt) => Hd(u, tt).multiply(Tm(0, 0, -0.5 - 3)).multiply(RXm(Math.PI / 2)), (u, tt) => u * 0.22, {show: u => u > 0.05});
}
// C · Alarm Beacon — Horizon Zero Dawn Longleg / Behemoth "antenna" parts that call other machines; a siren light on top
function challengeBeacon() {
  const H = mountOn("Head_cranium");
  for (const z of [0.28, -0.28]) {
    const A = (u, tt) => Tm(-0.2, 0.5, z).multiply(RZm(rad(55 - 35 * u) + Math.sin(tt * 30) * 0.03 * u));
    at(H, "box", [0.2, 0.2, 0.2], "iron", A); at(H, "cyl", [0.07, 1.6, 0], "steel", (u, tt) => A(u, tt).multiply(Tm(0, 0.8, 0)));
    for (const y of [0.5, 1.0]) at(H, "box", [0.3, 0.05, 0.05], "steel", (u, tt) => A(u, tt).multiply(Tm(0, y, 0)));
    at(H, "ball", [0.16, 0.16, 0.16], "glow", (u, tt) => A(u, tt).multiply(Tm(0, 1.62, 0)));
  }
  const M = mount("Torso_chest", [0, 0.42, -1.95]);
  M.box([0.9, 0.3, 0.9], [0, 0.05, 0], null, "shell"); M.cyl([0.75, 0.2, 0], [0, 0.3, 0], null, "brass");
  film(M, "cyl", [0.7, 0.8, 0], BLUE, () => Tm(0, 0.8, 0), (u, tt) => 0.35 + 0.2 * u);
  at(M, "cyl", [0.2, 0.7, 0], "steel", () => Tm(0, 0.8, 0));
  at(M, "box", [0.55, 0.45, 0.06], "glow", (u, tt) => Tm(0, 0.8, 0).multiply(RYm(tt * (1.5 + 10 * u))));
  M.cyl([0.78, 0.12, 0], [0, 1.26, 0], null, "iron");
  M.add("cone", [0.5, 0.25], [0, 1.44, 0], null, "iron");
  for (const s of [1, -1]) { M.add("cone", [0.45, 0.5], [s * 0.62, 0.2, 0], [s * 90, 0, 0], "dark"); M.cyl([0.36, 0.04, 0], [s * 0.86, 0.2, 0], [90, 0, 0], "glow"); }
  film(M, "ball", [1, 1, 1], BLUE, (u, tt) => Tm(0, 0.8, 0).multiply(SC(1.6, 1.6, 1.6)), (u, tt) => u * Math.max(0, Math.sin(tt * (1.5 + 10 * u) * 2)) * 0.35, {show: u => u > 0.05});
}
function oldChallenge() { const M = mountOn("Torso_chest");
  M.box([0.7, 0.35, 0.7], [0.1, 1.05, 0.45], null, "dark"); M.box([0.55, 0.45, 0.55], [0.1, 1.42, 0.45], null, "steel");
  M.box([0.7, 0.16, 0.16], [0.55, 1.45, 0.45], null, "steel"); M.ball(0.22, [0.92, 1.45, 0.45], "white", {color: RED}); }

// ============================================ 6 · HYDRAULIC LEAP (speed) ============================================
// A · Chicken-Leg Rams — Armored Core reverse-joint legs: strong jumps after a short charge; big rams down the back of the leg
function leapRams() {
  for (const [s, side] of SIDES) {
    const hp = [s * 0.98, -0.2, 0.55], fp = [s * 0.98, -2.85, 0.2];
    const Hm = mountOn(`Leg${side}_haunch`);
    Hm.box([0.7, 0.6, 0.18], [-0.35, 0.25, s * 0.3], null, "shell"); Hm.cyl([0.36, 0.3, 0], [-0.4, 0.3, s * 0.42], [0, 0, 90], "brass");
    strut(Hm, `Leg${side}_haunch`, hp, `Foot${side}_meta`, fp, 0.02, 0.58, 0.48, "iron");
    strut(Hm, `Leg${side}_haunch`, hp, `Foot${side}_meta`, fp, 0.5, 0.96, 0.26, "steel");
    strut(Hm, `Leg${side}_haunch`, hp, `Foot${side}_meta`, fp, 0.5, 0.56, 0.56, "brass");
    const Fm = mountOn(`Foot${side}_meta`); Fm.box([0.3, 0.3, 0.34], [-0.15, 0.1, s * 0.25], null, "dark");
    // charge gauge on the thigh fills while crouching
    const T = mountOn(`Leg${side}_thigh`);
    T.box([0.55, 1.35, 0.06], [0, 0.05, s * 0.36], null, "trim");
    for (let k = 0; k < 5; k++) T.box([0.36, 0.16, 0.05], [0, -0.48 + k * 0.24, s * 0.4], null, "glow", {show: (u, tt) => u > 0.3 && (leapK(tt).p < 0.62 ? leapK(tt).C * 5 > k + 0.3 : false)});
    const K = mountOn(`Shin${side}_knee`);
    at(K, "cyl", [0.62, 0.12, 0], "brass", (u, tt) => Tm(0, 0, s * 0.33).multiply(RXm(Math.PI / 2)).multiply(RYm(tt * 0.5 + u * leapK(tt).C * 6)));
    for (let k = 0; k < 8; k++) at(K, "box", [0.12, 0.12, 0.12], "brass", (u, tt) => Tm(0, 0, s * 0.33).multiply(RZm(tt * 0.5 + u * leapK(tt).C * 6 + k * Math.PI / 4)).multiply(Tm(0.34, 0, 0)));
  }
}
// B · Haunch Thrusters — Horizon Forbidden West Rollerback "Thruster": a booster that launches its charge
function leapJets() {
  for (const [s, side] of SIDES) {
    const M = mountS(`Leg${side}_haunch`, [0, 0.15, s * 0.42], 1.45);
    M.box([1.15, 0.95, 0.42], [0, 0.15, s * 0.42], null, "shell"); M.box([1.0, 0.12, 0.5], [0, 0.66, s * 0.42], null, "trim");
    M.hazard(0.9, 0.12, [0, -0.25, s * 0.64], null, 6);
    at(M, "ring", [0.26, 0.05], "brass", () => Tm(0.62, 0.25, s * 0.42).multiply(RYm(Math.PI / 2)));
    for (let k = 0; k < 4; k++) at(M, "box", [0.04, 0.44, 0.08], "steel", (u, tt) => Tm(0.62, 0.25, s * 0.42).multiply(RXm(tt * (2 + 20 * u) + k * Math.PI / 4)));
    const fire = (u, tt) => u * (leapK(tt).S + 0.15 * leapK(tt).C);
    for (const dy of [0.3, -0.05]) {
      M.add("cone", [0.38, 0.4], [-0.72, dy, s * 0.42], [-90, 0, 0], "iron");
      film(M, "cone", [0.34, 1], YEL, (u, tt) => Tm(-0.92 - (0.2 + 1.4 * fire(u, tt)) / 2, dy - 0.1, s * 0.42).multiply(rot(90 - 12, 0, 0)).multiply(SC(1, 0.2 + 1.4 * fire(u, tt), 1)), (u, tt) => 0.3 + 0.6 * fire(u, tt), {show: (u, tt) => fire(u, tt) > 0.03});
    }
    M.hose([0.3, -0.3, s * 0.6], [-0.2, -0.7, s * 0.4], 0.1, 0.14, 4);
  }
}
// C · Hammer-Tail Spring — Horizon Forbidden West Rollerback "Hammer Tail": a weighted tail that slams; leaf springs load it
function leapHammer() {
  // multi-leaf springs along the top of the tail base (they bend with the tail), yellow clamps
  for (const [n, L, h] of [["Tail1_main", 3.54, 2.25], ["Tail2_main", 3.48, 1.58]]) { const M = mountOn(n), top = h / 2 + 0.2;
    for (let i = 0; i < 4; i++) M.box([L * (1 - i * 0.2), 0.12, 0.9 - i * 0.08], [0, top + 0.06 + i * 0.13, 0], null, i % 2 ? "steel" : "iron");
    for (const x of [L * 0.3, -L * 0.3]) M.box([0.22, 0.7, 1.05], [x, top + 0.25, 0], null, "hazY");
    M.box([0.5, 0.12, 0.2], [0, top + 0.6, 0], null, "glow"); }
  const H = mountS("Tail5_main", [-1.15, 0, 0], 1.9);
  H.box([1.1, 0.95, 0.9], [-1.15, 0, 0], null, "iron"); H.box([1.16, 0.2, 0.96], [-1.15, 0.0, 0], null, "hazY");
  for (const [y, z] of [[0.55, 0], [-0.55, 0], [0, 0.52], [0, -0.52]]) H.add("cone", [0.3, 0.35], [-1.15, y, z], y > 0 ? [0, 0, 0] : y < 0 ? [180, 0, 0] : [0, 0, z > 0 ? 90 : -90], "steel");
  H.box([0.12, 0.5, 0.95], [-0.55, 0, 0], null, "glow");
  bandX(mountOn("Tail4_main"), 0.71, 0.61, 0.2, [-0.6, 0, 0], "iron");
  // the slam ring when the hammer lands (end of the spring)
  const G = mount("FootL_meta", [0, -3.33, 0]);
  film(G, "ring", [1, 0.1], YEL, (u, tt) => { const d = Math.max(0, (leapK(tt).p - 0.8) / 0.2); return Tm(-0.72, 0.05, 9).multiply(RXm(Math.PI / 2)).multiply(SC(0.5 + d * 5, 0.5 + d * 5, 1)); },
    (u, tt) => { const d = (leapK(tt).p - 0.8) / 0.2; return d > 0 && d < 1 ? u * (1 - d) : 0; }, {show: u => u > 0.05});
}
function oldLeap() { for (const [s, side] of SIDES) { const M = mountOn(`Shin${side}_shin`), z = side === "L" ? 0.3 : -0.3;
  for (let i = 0; i <= 5; i++) M.cyl([0.62, 0.07, 0], [0, -0.45 + i * 0.18, z], null, "steel"); M.cyl([0.7, 0.1, 0], [0, 0.62, z], null, "white", {color: 0xffd34d}); } }

// ============================================ 7 · SHIELD ARMOR (defense, purple) ============================================
// A · Snapper Shell — Horizon Forbidden West Shellsnapper: its shell shield soaks hits, shifts colour as it fills, then bursts
function shieldShell() {
  const M = mount("Torso_barrel", [0, 0, 0]);
  const cy = 0.0, R0 = 1.45;
  for (const z of [-2.1, -0.95, 0.2]) {
    for (let k = 0; k <= 6; k++) { const a = rad(15 + k * 25); M.box([0.16, 0.5, 0.2], [Math.cos(a) * R0, cy + 0.15 + Math.sin(a) * R0 * 0.75, z], [a * 180 / Math.PI, 0, 0], "iron"); }
    M.ball(0.26, [0, cy + 0.15 + R0 * 0.75, z], "white", {color: PURPLE});
    for (const s of [1, -1]) M.ball(0.22, [s * Math.cos(rad(15)) * R0, cy + 0.15 + Math.sin(rad(15)) * R0 * 0.75, z], "white", {color: LILAC});
  }
  const fill = tt => (tt % 3) / 3; // hits soaked: purple -> orange, burst at the end
  for (let zi = 0; zi < 5; zi++) for (let k = 0; k < 6; k++) {
    const a = rad(18 + k * 28.8), z = -2.5 + zi * 0.75;
    const e = film(M, "box", [0.7, 0.05, 0.72], PURPLE, (u, tt) => { const b = fill(tt) > 0.92 ? (fill(tt) - 0.92) / 0.08 : 0, R = (1.45 + 0.6 * u) * (1 + b * 0.25);
      return Tm(Math.cos(a) * R, cy + 0.15 + Math.sin(a) * R * 0.8, z * (0.95 + 0.1 * u)).multiply(RZm(a - Math.PI / 2)); },
      (u, tt) => u * (0.35 + 0.15 * Math.sin(tt * 3 + zi + k)) * (fill(tt) > 0.92 ? 1 - (fill(tt) - 0.92) / 0.08 : 1), {show: u => u > 0.05});
    const an = e.anim; e.anim = (u, tt) => { an(u, tt); e.mesh.material.color.setHex(PURPLE).lerp(new THREE.Color(ORANGE), sm(fill(tt) / 0.9)); return null; };
  }
}
// B · Shield Mane — Zoids Shield Liger: the shield generator is in its mane, the shield covers the front half
function shieldMane() {
  const M = mount("Torso_chest", [0, -0.25, -2.85]);
  M.add("ring", [0.92, 0.12], [0, 0, 0.05], null, "iron"); M.add("ring", [0.8, 0.06], [0, 0, -0.04], null, "brass");
  const fold = u => rad(72 - 82 * u);
  for (let k = 0; k < 10; k++) {
    const a = k * Math.PI / 5 + Math.PI / 10, B = u => Tm(0, 0, 0).multiply(RZm(a)).multiply(Tm(0, 0.85, 0)).multiply(RXm(fold(u)));
    at(M, "box", [0.42, 1.35, 0.08], k % 2 ? "plate" : "shell", u => B(u).multiply(Tm(0, 0.62, 0)));
    at(M, "box", [0.1, 1.1, 0.1], "white", u => B(u).multiply(Tm(0, 0.65, -0.06)), {color: PURPLE});
    at(M, "cyl", [0.16, 0.36, 0], "brass", u => B(u).multiply(RZm(Math.PI / 2)));
  }
  film(M, "cyl", [3.9, 0.04, 0], PURPLE, (u, tt) => Tm(0, 0, -0.35).multiply(RXm(Math.PI / 2)).multiply(SC(u, 1, u)), (u, tt) => u * (0.3 + 0.08 * Math.sin(tt * 4)), {show: u => u > 0.1});
  film(M, "ring", [1.95, 0.07], LILAC, (u, tt) => Tm(0, 0, -0.35).multiply(SC(u, u, 1)), (u, tt) => u * 0.9, {show: u => u > 0.1});
  for (const s of [1, -1]) { M.cyl([0.55, 0.5, 0], [s * 0.85, 0.75, 1.0], [90, 0, 0], "iron"); M.cyl([0.3, 0.54, 0], [s * 0.85, 0.75, 1.0], [90, 0, 0], "white", {color: PURPLE}); }
}
// C · Gravity Plates — Horizon Forbidden West Rollerback "Gravity Generator": it pulls its armour plates back into place
function shieldPlates() {
  const M = mount("Torso_barrel", [0, 0, -0.9]);
  M.box([0.9, 0.2, 0.9], [0, 1.0, 0], null, "shell");
  for (const [x, z] of [[0.35, 0.35], [-0.35, 0.35], [0.35, -0.35], [-0.35, -0.35]]) M.box([0.1, 0.9, 0.1], [x, 1.5, z], null, "iron");
  M.box([0.9, 0.12, 0.9], [0, 1.98, 0], null, "trim");
  at(M, "ball", [0.5, 0.5, 0.5], "white", (u, tt) => Tm(0, 1.5, 0).multiply(SC(1 + 0.1 * Math.sin(tt * 4), 1 + 0.1 * Math.sin(tt * 4), 1 + 0.1 * Math.sin(tt * 4))), {color: PURPLE});
  for (let k = 0; k < 2; k++) at(M, "ring", [0.38, 0.04], "brass", (u, tt) => Tm(0, 1.5, 0).multiply(RYm(tt * (1 + 3 * u) * (k ? -1 : 1))).multiply(RXm(k ? 0.9 : -0.9)));
  // six plates: lying on the flanks at rest, lifting off to orbit the body when used
  const REST = [[1, -1.4], [1, -0.3], [1, 0.8], [-1, -1.4], [-1, -0.3], [-1, 0.8]];
  REST.forEach(([s, z], k) => {
    const R0 = Tm(s * 1.0, 0.1, z + 0.9).multiply(RZm(s * rad(8))), O = (tt) => { const a = k * Math.PI / 3 + tt * 0.9; return Tm(Math.cos(a) * 2.4, 0.6 + 0.2 * Math.sin(tt * 2 + k), 0.4 + Math.sin(a) * 2.6).multiply(RYm(-a)); };
    const P = (u, tt) => blendM(R0, O(tt), u);
    at(M, "box", [0.14, 0.95, 1.0], "shell", P);
    at(M, "box", [0.16, 0.08, 1.02], "white", (u, tt) => P(u, tt).multiply(Tm(0, 0.48, 0)), {color: PURPLE});
    at(M, "box", [0.16, 0.08, 1.02], "white", (u, tt) => P(u, tt).multiply(Tm(0, -0.48, 0)), {color: PURPLE});
  });
}
function oldShield() { const M = mountOn("Torso_dorsalShoulder");
  for (const x of [-0.45, 0.45]) { M.box([0.225, 0.65, 0.225], [x, 0.434, -0.2], null, "dark"); M.box([0.275, 0.06, 0.275], [x, 0.634, -0.2], null, "white", {color: LILAC}); M.ball(0.25, [x, 0.859, -0.2], "white", {color: PURPLE}); } }

// ============================================ the list ============================================
const PARTS = [
  {id: "tgrab", short: "Grab", name: "Tail Grab & Fling", area: "attack", focus: [0, 3, 12], oldText: "Clamp Tail: a small steel box on the tail tip with two thin dark jaws and red tips. Nothing on it moves when you grab.",
    looks: [
      {name: "Snatch Claw", sub: "spinning 3-finger claw", build: grabSnatch, pose: SNATCH, ref: "Horizon Forbidden West — Clamberjaw, whose tail snatches things, spins them and hurls them (\"Snatch and Hurl\").",
        why: "A big three-finger claw on the tail tip with a hydraulic ram on the tail behind it. When used the tail curls up toward the camera, the fingers open and snap shut and the wrist spins (the fling).", use: "Fingers open / snap, wrist spins, ram pumps; tail curls up.", on: "Tail tip (Tail5) + ram and bands on Tail4."},
      {name: "Pincer Tail", sub: "armoured scorpion tail", build: grabPincer, pose: SCORPION, ref: "Zoids — Death Stinger, a scorpion Zoid whose armoured tail ends in a big claw.",
        why: "The whole tail gets overlapping armour plates with a red line down the top, ending in two big curved pincer blades. When used the tail arcs up like a scorpion and the pincers snap.", use: "Tail arcs up over the back, pincers snap.", on: "Tail2 – Tail5 (plates), pincers on the tip."},
      {name: "Gravity Grapple", sub: "spinning grav rings", build: grabGrav, pose: AIMTAIL, ref: "Horizon Forbidden West — Rollerback's Gravity Generator, which pulls its torn-off armour plates back to its body.",
        why: "A cooled generator box on the tail with glowing tubes, and three gimbal rings spinning around a dish on the tip. When used the rings spread out, spin fast and a red pull-beam reaches out.", use: "Rings spread and spin up, red beam out of the dish; tail swings to aim.", on: "Tail4 (generator) + tail tip (dish and rings)."},
    ]},
  {id: "tmortar", short: "Mortar", name: "Boulder Mortar", area: "attack", focus: [0, 4, 2], oldText: "Tail Catapult: a steel tray with dark walls on the tail holding one rock. It doesn't move.",
    looks: [
      {name: "Force Loaders", sub: "floating boulder", build: mortarLoader, pose: BRACE, ref: "Horizon Zero Dawn — Behemoth's Force Loaders: anti-gravity generators that lift boulders and hurl them.",
        why: "Two generator towers on the hips hold a boulder floating between them, slowly turning. When used the boulder lifts higher and spins fast, red beams lock onto it and the rings whirl.", use: "Boulder rises and spins, beams on, rings spin up.", on: "Hips (towers) — the boulder floats above the back."},
      {name: "Back Cannon", sub: "charge-up mortar", build: mortarCannon, ref: "Zoids — Gordos (guns on its back) + Horizon Zero Dawn Ravager Cannon (a short charge-up before each shot).",
        why: "A turret on the back with a fat mortar barrel and an ammo hopper of boulders on the camera side. When used the barrel lifts, red rings charge up the barrel one by one, then it fires with a kick and a flash.", use: "Barrel lifts, 4 rings charge, recoil + muzzle flash.", on: "Middle of the back; hopper on the camera side."},
      {name: "Tail Trebuchet", sub: "counterweight sling", build: mortarTreb, pose: TREB, ref: "Age of Empires — the Trebuchet: a counterweight swings and the long arm whips the load over the top.",
        why: "A boulder basket on the tail and a striped counterweight swinging under the tail base, with a pulley cable. When used the tail winds down, then whips up over the back and the boulder leaves.", use: "Tail winds down, whips over; counterweight swings; boulder leaves.", on: "Tail3 (basket), under Tail1 (counterweight)."},
    ]},
  {id: "tstomp", short: "Stomp", name: "Stomp Shockwave", area: "defense", focus: [0, 1, -2.5], oldText: "Iron Hoof Plates: a plain steel boot around each front hand with rivets. Only a heat strip glows on the stomp.",
    looks: [
      {name: "Quake Hooves", sub: "spinning resonators", build: stompQuake, pose: REAR, ref: "Horizon Zero Dawn — Behemoth's \"Quake Smash\": it rears up, smashes down and sends a shockwave forward.",
        why: "Heavy boots with glowing vents, a spinning resonator ring around each wrist, a ram down each forearm and two exhaust stacks on the shoulders. When used it rears up, the rings spin up, it slams, the stacks puff and a blue ring rolls out.", use: "Rear up → rings spin up → slam, stacks puff, shock ring.", on: "Both front hands + forearms, stacks on the shoulders."},
      {name: "Elbow Rockets", sub: "thrusters drive it down", build: stompRocket, pose: REAR, ref: "Pacific Rim — Gipsy Danger's \"Elbow Rocket\": thrusters on the back of the arm fire to drive the punch.",
        why: "A booster pod on the back of each upper arm with three nozzles and petal flaps. When used it rears up, the flaps open and blue flames blast out on the way down, driving the hooves into the ground.", use: "Flaps open, flames fire on the way down, shock ring.", on: "Back of both upper arms; caps on the hands."},
      {name: "Pile Bunkers", sub: "spike + revolver", build: stompPile, pose: REAR, ref: "Armored Core — the pile bunker: a charge drives a heavy steel spike, a revolver turns to the next charge.",
        why: "A steel spike runs down the front of each forearm past the hoof, fed by a brass revolver of charges. When used it rears up and the spikes punch into the ground at the slam; the revolver turns and a spent case flies out.", use: "Spikes punch down at the slam, revolver turns, case ejects.", on: "Front of both forearms."},
    ]},
  {id: "tbellow", short: "Bellow", name: "Herd Bellow", area: "health", focus: [0, 3, -4.5], oldText: "Crest Speakers: two dark boxes with cyan squares on the sides of the head and a steel band. Nothing moves.",
    looks: [
      {name: "Shriek Sacs", sub: "pumping throat sacs", build: bellowSacs, pose: BELLOW, ref: "Horizon Zero Dawn — Longleg's concussion sacs: inflatable sacs on its chest for a sonic shriek.",
        why: "Two see-through green sacs in iron cages on the sides of the neck, with valves on top. When used the head lifts, the jaw opens, the sacs pump and green sound rings roll out of the mouth.", use: "Sacs pump, jaw open, green rings from the mouth.", on: "Both sides of the neck base."},
      {name: "Crest Horn", sub: "brass horn crest", build: bellowHorn, pose: HORN, ref: "Monster Hunter — the Hunting Horn (its songs buff the whole team), built like a duck-bill dino's crest.",
        why: "A brass horn pipe runs from the snout over the head to a big bell pointing back, with three valve pistons on top. When used the head lifts, the valves pump and green rings blow out of the bell — the camera sees them.", use: "Valves pump, rings out of the bell.", on: "Top of the head (moves with it)."},
      {name: "Amp Stack", sub: "speakers + deck", build: bellowAmp, pose: BELLOW, ref: "Overwatch — Lúcio: his songs give the team speed (Speed Boost) and a damage shield (Sound Barrier).",
        why: "A speaker rack on the back: two big speakers facing up and back toward the camera, a spinning record deck and bouncing level bars. When used the cones pump and green rings blast back.", use: "Cones pump, deck spins fast, bars jump, rings out.", on: "Middle of the back."},
    ]},
  {id: "tchallenge", short: "Challenge", name: "Challenge Call", area: "defense", focus: [0, 4, -1], oldText: "Target Painter: a small dark turret block on the chest with a red ball lens. Nothing moves.",
    looks: [
      {name: "War Banner", sub: "waving back flag", build: challengeBanner, pose: CALL, ref: "Total War: Shogun 2 — samurai units wear the sashimono, a back banner on an L-frame that shows who you are.",
        why: "A tall flag on the back on an L-frame, dark blue with a white edge and a glowing blue mark. It waves gently; when used the pole leans forward, the flag whips and the head calls out.", use: "Flag whips, pole leans; head up and calling.", on: "Middle of the back (tall — seen from far)."},
      {name: "Watcher Eye", sub: "scanning eye mast", build: challengeEye, pose: CALL, ref: "Horizon Zero Dawn — Watcher: one big glowing eye on a long neck that tracks threats and alerts the herd.",
        why: "A telescoping mast on the shoulders with a big blue eye that looks left and right and blinks. When used the mast extends, the eye locks forward and a blue scan cone sweeps out.", use: "Mast extends, eye locks on, blue scan cone.", on: "Shoulders (behind the neck)."},
      {name: "Alarm Beacon", sub: "siren + antennae", build: challengeBeacon, pose: CALL, ref: "Horizon Zero Dawn — Longleg / Behemoth antenna parts that call other machines in, plus a siren light.",
        why: "Two antennae on the head and a siren beacon on the shoulders with a spinning blue light and horn speakers. When used the antennae stand up and buzz, the light spins fast and flashes.", use: "Antennae up, light spins and flashes.", on: "Head (antennae) + shoulders (beacon)."},
    ]},
  {id: "tleap", short: "Leap", name: "Hydraulic Leap", area: "speed", focus: [0, 0, 0.3], oldText: "Spring Coils: six thin steel discs stacked on each shin with a yellow ring. They don't squash or move.",
    looks: [
      {name: "Chicken-Leg Rams", sub: "big leg rams + gauge", build: leapRams, pose: LEAP, ref: "Armored Core 6 — reverse-joint legs: the strongest jumps, after a short charge.",
        why: "A big hydraulic ram down the back of each hind leg from hip to heel, a gear on each knee and a charge gauge on the thigh. When used it crouches, the gauge fills, the gears turn, then the rams fire it up.", use: "Crouch: gauge fills, gears turn → spring.", on: "Both hind legs (hip to heel)."},
      {name: "Haunch Thrusters", sub: "booster packs", build: leapJets, pose: LEAP, ref: "Horizon Forbidden West — Rollerback's Thruster, which launches its rolling charge.",
        why: "A booster pack on each hip with two nozzles pointing back and a spinning intake fan. When used it crouches with a small flame, then both nozzles blast yellow on the jump.", use: "Fans spin up, yellow flames on the jump.", on: "Both hips (outer side)."},
      {name: "Hammer-Tail Spring", sub: "leaf springs + hammer", build: leapHammer, pose: POGO, ref: "Horizon Forbidden West — Rollerback's Hammer Tail, a weighted tail it slams down.",
        why: "Stacked leaf springs with yellow clamps along the top of the tail base and a big spiked hammer weight on the tail tip. When used the tail presses down to load the springs, flicks up as it jumps, and a yellow ring shows the hammer slam.", use: "Tail loads down, flicks up, slam ring.", on: "Top of Tail1 / Tail2, tail tip."},
    ]},
  {id: "tmud", short: "Shield", name: "Shield Armor", area: "defense", focus: [0, 2, -1], oldText: "Shield pylons: two small dark posts on the shoulders with lilac bands and purple balls. Nothing moves.",
    looks: [
      {name: "Snapper Shell", sub: "purple shell → burst", build: shieldShell, pose: GUARD, ref: "Horizon Forbidden West — Shellsnapper: its shell shield soaks hits, changes colour as it fills, then bursts.",
        why: "Three iron ribs arch over the back with purple nodes. When used a purple panel shell grows over the back, turns orange as it soaks hits, then bursts outward (the ★ burst).", use: "Shell forms, purple → orange, bursts.", on: "Back (ribs over the body)."},
      {name: "Shield Mane", sub: "fan collar → disc", build: shieldMane, pose: GUARD, ref: "Zoids — Shield Liger: the shield generator sits in its mane and covers the front half.",
        why: "Ten armour blades lie back around the neck like a mane, with purple lines, and two generators behind. When used the blades swing forward into a ring and a purple shield disc fills the front.", use: "Blades swing forward, purple disc in front.", on: "Around the neck base + shoulders."},
      {name: "Gravity Plates", sub: "orbiting armour", build: shieldPlates, pose: GUARD, ref: "Horizon Forbidden West — Rollerback's Gravity Generator, which pulls its armour plates back onto it.",
        why: "A caged purple core on the back and six armour plates on the flanks. When used the plates lift off and orbit around the body, the core pulses and its rings spin.", use: "Plates lift off and orbit, core pulses.", on: "Back (core) + both flanks (plates)."},
    ]},
];
const OLD = {tgrab: oldGrab, tmortar: oldMortar, tstomp: oldStomp, tbellow: oldBellow, tchallenge: oldChallenge, tleap: oldLeap, tmud: oldShield};
const LOADOUTS = [
  {name: "Horizon set", sub: "every A look", why: "All seven A looks at once, to check they fit together and what the camera sees.", parts: PARTS.map(p => [p.id, p.looks[0].build]), rows: PARTS.map(p => [p.id, p.looks[0].name])},
  {name: "Arsenal set", sub: "every B look", why: "All seven B looks at once.", parts: PARTS.map(p => [p.id, p.looks[1].build]), rows: PARTS.map(p => [p.id, p.looks[1].name])},
];
pose({}); camGoal(); renderAll(); requestAnimationFrame(frame);
