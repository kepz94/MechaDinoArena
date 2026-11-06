// Herrera parts redesign v0.2 (Lamellar plates merged, ~50 pieces; export tags — group / role — on the 11 picks, no visual change) — the looks (Kepu 2026-11-05 19:10 "Next it looks good" -> "Herrera looks + animations": the same
// treatment as the Teno / Therizino). 11 parts x 3 looks, each borrowing one real game part, + the Now look (HerreraPartsServer 1.3).
// Coordinates: rest model space (scale 1 = studs / 2, HRP frame; front = -Z, +X = the camera side = the model's "...L" parts).
// mountOn(part) frames: local X = along the part toward the head (tail: -X = toward the tip), Y = up, Z = +X (camera side).
// mount(part, pos, [p, y, r]) frames: world axes (X = +X side, Y = up, Z = back); p rolls about Z, r pitches about X (+ = nose up).
const V3 = (x, y, z) => new THREE.Vector3(x, y, z);
const SIDES = [[1, "L"], [-1, "R"]];
const loop = (period, tt) => ((tt === undefined ? t : tt) % period) / period; // 0..1 sawtooth
const sm = x => { x = Math.max(0, Math.min(1, x)); return x * x * (3 - 2 * x); };
const PURPLE = 0x9646ff, LILAC = 0xcda0ff, ORANGE = 0xff8a1a, RED = 0xe02a2a, GREEN = 0x3ddc84, BLUE = 0x3d9bff, YEL = 0xffc21a;
MAT.dark = [0x3a3f47, "metal"]; MAT.rock = [0x8a8478, "stud"]; MAT.cloth = [0x1d3b7a, "plain"]; MAT.clothW = [0xe8ecf4, "plain"];
// v0.2 export: keep = exported even though hidden at rest (TenoPartsAnim lights it); D = detail (dropped by "lite")
const keep = e => { e.keep = true; return e; }, D = {detail: true};
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
    if (!e.strut) e.strut = {pa, a, pb, b, f0, f1, d, key};
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

// ---------- Herrera kit additions ----------
MAT.dark = [0x3a3f47, "metal"]; MAT.bright = [0xd3dbe6, "metal"]; MAT.sail = [0xffc21a, "plain"]; MAT.sailK = [0x2a2d33, "plain"];
MAT.copper = [0xc8743a, "metal"]; MAT.lime = [0xa6e22e, "neon"]; MAT.blood = [0xd0202a, "neon"]; MAT.adr = [0x46e08a, "neon"];
MAT.cream = [0xfff0c8, "neon"];
const SMOKE = 0x9aa0a8, LIME = 0xa6e22e, BLOODC = 0xd0202a, VOLT = 0x7fe9ff, FLASH = 0xfff4d8;
const QUILLS = [1, 2, 3, 4, 5, 6, 7].map(i => "Torso_quill" + i);
const GROUND = -2.92; // rest-space ground height under the Herrera (its toes)
// the "Now" looks: HerreraPartsServer 1.3's pieces, placed exactly as the game does (anchor CFrame * offset * Angles(x, y, z))
for (const [k, v] of Object.entries(OLDP.colors)) { const kind = v[3].endsWith("Neon") ? "neon" : v[3].endsWith("Metal") ? "metal" : "plain"; MAT["o_" + k] = [(v[0] << 16) | (v[1] << 8) | v[2], kind]; }
function oldPieces(list, o) {
  for (const pc of list) { const [anchor, size, pos, r] = pc, key = pc[4];
    const m = Tm(...pos).multiply(new THREE.Matrix4().makeRotationFromEuler(new THREE.Euler(rad(r[0]), rad(r[1]), rad(r[2]), "XYZ")));
    const tr = OLDP.colors[key][4];
    at(mountOn(anchor), "box", size, "o_" + key, () => m, Object.assign({role: pc[5]}, tr ? {alpha: 1 - tr} : {}, o || {})); }
}
// a cylinder matrix from a to b (local points), for pieces made with size [d, 1, 0]
function lineM(a, b) { const A = V3(...a), B = V3(...b), dir = B.clone().sub(A), len = Math.max(0.001, dir.length());
  return new THREE.Matrix4().compose(A.clone().add(B).multiplyScalar(0.5), new THREE.Quaternion().setFromUnitVectors(V3(0, 1, 0), dir.normalize()), V3(1, len, 1)); }
// a piece placed at fraction f(u, t) of the line from part pa's rest point a to part pb's rest point b (both follow their parts)
function travel(M, pa, a, pb, b, f, sh, s, key, o) { let e;
  e = M.add(sh, s, [0, 0, 0], null, key, Object.assign({}, o || {}, {place: (u, tt) => {
    const P = restOn(pa, a).lerp(restOn(pb, b), f(u, tt));
    return dino.byName[M.part].mesh.matrix.clone().multiply(e.mountOff).invert().multiply(new THREE.Matrix4().makeTranslation(P.x, P.y, P.z)); }}));
  return e; }
// grey smoke puffs that roll out from org along dir and fade (shown while used)
function puffs(M, n, period, org, dir, dist, size, color) {
  for (let k = 0; k < n; k++) { const d = tt => (tt / period + k / n) % 1, j = [Math.sin(k * 7.1) * 0.3, Math.sin(k * 3.7) * 0.2, Math.cos(k * 5.3) * 0.3];
    film(M, "ball", [1, 1, 1], color || SMOKE, (u, tt) => { const q = d(tt), s = size * (0.35 + 1.5 * q);
      return Tm(org[0] + (dir[0] + j[0]) * dist * q, org[1] + (dir[1] + j[1]) * dist * q, org[2] + (dir[2] + j[2]) * dist * q).multiply(SC(s, s * 0.8, s)); },
      (u, tt) => u * (1 - d(tt)) * 0.55, {show: u => u > 0.05}); } }
// a projectile flight: n pieces each on path(d) -> Matrix4 (d 0..1 over period), shown while used
function flights(M, n, period, sh, s, key, path, o) {
  for (let k = 0; k < n; k++) { const d = tt => (tt / period + k / n) % 1;
    at(M, sh, s, key, (u, tt) => path(d(tt), k), Object.assign({show: u => u > 0.3}, o || {})); } }
// a caltrop jack (three crossed spikes) at place(u, t)
function jack(M, place, o) { for (const r of [RXm(0), RXm(Math.PI / 2), RZm(Math.PI / 2)]) at(M, "box", [0.32, 0.05, 0.05], "bone", (u, tt) => place(u, tt).multiply(r).multiply(RYm(0.6)), o); }
// flash pulse 0..1 (every period seconds)
const flash = (tt, P) => Math.max(0, 1 - ((tt % (P || 0.8)) / 0.14));
// pseudo-random jitter for lightning (changes 20 times a second)
const jit = (tt, k) => Math.sin(Math.floor(tt * 20) * 12.9898 + k * 78.233) * 43758.5453 % 1;
// a jagged arc from a to b (mount-local) in n segments
function arc(M, a, b, n, color, amp, show) {
  const pt = (i, tt) => { const f = i / n, w = (i === 0 || i === n) ? 0 : amp; return [a[0] + (b[0] - a[0]) * f + jit(tt, i) * w, a[1] + (b[1] - a[1]) * f + jit(tt, i + 9) * w, a[2] + (b[2] - a[2]) * f + jit(tt, i + 17) * w]; };
  for (let i = 0; i < n; i++) film(M, "cyl", [0.06, 1, 0], color, (u, tt) => lineM(pt(i, tt), pt(i + 1, tt)), (u, tt) => u * (0.6 + 0.4 * Math.abs(jit(tt, i + 3))), {show: (u, tt) => u > 0.2 && (show ? show(u, tt) : true)}); }
// flat rings on the ground around the Herrera (push-back / shock), 1 unit = 2 studs
const groundWaves = (color, r1) => waves(mount("Torso_hips", [0, 0, 0]), 2, 0.8, (u, tt, d) => Tm(0, GROUND + 0.05, 0), color, 0.5, r1, 0.06);

// ---------- poses (joint -> [p, y, r] degrees; p+ lifts Neck / Head / RootJoint front and swings Arm / Leg forward, Tail p- = up,
// Jaw p- = open, Arm r: - spreads ArmL out, + spreads ArmR out) ----------
function SLASH(tt) { const a = Math.sin(tt * 5); return {RootJoint: [-4, 0, 0], Neck: [-6, 0, 0], ArmL: [12 + 28 * a, 0, -8], ArmR: [12 - 28 * a, 0, 8], Jaw: [-10, 0, 0]}; }
function GLIDE(tt) { const f = Math.sin(tt * 1.6) * 3; return {RootJoint: [-6, 0, 0], Neck: [6, 0, 0], ArmL: [20 + f, 0, -62], ArmR: [20 + f, 0, 62], LegL: [-28, 0, 0], LegR: [-28, 0, 0], Tail1: [-4, 0, 0], Tail2: [-3, 0, 0]}; }
const AIM = {RootJoint: [-3, 0, 0], Neck: [-8, 0, 0], Head: [6, 0, 0]};
function TAILUP(tt) { const g = Math.sin(tt * 4) * 3; return {RootJoint: [-4, 0, 0], Neck: [-6, 0, 0], Tail1: [-10, 0, 0], Tail2: [-14 + g, 0, 0], Tail3: [-16 + g, 0, 0], Tail4: [-12, 0, 0], Tail5: [-6, 0, 0]}; }
const BRACE = {RootJoint: [-5, 0, 0], Neck: [-8, 0, 0], Head: [4, 0, 0], Tail1: [-6, 0, 0]};
function SHRUG(tt) { const p = Math.sin(tt * 9) * 2; return {RootJoint: [3 + p, 0, 0], Neck: [10, 0, 0], Head: [-6, 0, 0], ArmL: [10, 0, -20], ArmR: [10, 0, 20]}; }
function SHAKE(tt) { const w = Math.sin(tt * 14); return {Tail1: [-4, 6 * w, 0], Tail2: [-4, 10 * w, 0], Tail3: [-2, 14 * w, 0], Tail4: [0, 16 * w, 0], Tail5: [0, 16 * w, 0]}; }
function SPIT(tt) { const p = (tt % 1.2) / 1.2, k = p < 0.6 ? sm(p / 0.6) : 1 - sm((p - 0.6) / 0.1); return {Neck: [10 * k - 4, 0, 0], Head: [6 * k, 0, 0], Jaw: [p > 0.6 && p < 0.85 ? -30 : -6, 0, 0]}; }
function FLARE(tt) { const p = Math.sin(tt * 3) * 3; return {RootJoint: [4, 0, 0], Neck: [14 + p, 0, 0], Head: [-10, 0, 0], Jaw: [-20, 0, 0]}; }
const RUN = tt => { const a = Math.sin(tt * 9); return {RootJoint: [-8, 0, 0], Neck: [-8, 0, 0], LegL: [30 * a, 0, 0], LegR: [-30 * a, 0, 0], ArmL: [10, 0, 0], ArmR: [10, 0, 0]}; };

// ============================================ 1 · IRON CLAW (attack) ============================================
// A · Wing Blades — Monster Hunter Nargacuga: blades along the back edge of its wing-arms, swung in its slashes
function clawWing() {
  for (const [s, side] of SIDES) {
    const F = mountOn(`Arm${side}_fore`); // Y = along the forearm (hand at -Y), X = forward, Z = +X world
    F.box([0.42, 0.95, 0.4], [0, -0.05, 0], null, "shell");
    for (const y of [0.32, -0.4]) F.box([0.48, 0.07, 0.46], [0, y, 0], null, "trim");
    F.box([0.06, 0.5, 0.16], [0.22, -0.05, 0], null, "glow"); F.bolt([0.22, 0.28, 0.12], "x"); F.bolt([0.22, 0.28, -0.12], "x");
    for (let i = 0; i < 3; i++) {
      const root = [-0.2, 0.25 - i * 0.3, 0], len = 1.05 - i * 0.12, a0 = 200 + i * 14, a1 = 292 - i * 10;
      const th = (u, tt) => rad(lerp(a0, a1, u) + u * 8 * Math.sin(tt * 5));
      const g = F.group(`blade_${side}${i + 1}`, Tm(...root).multiply(RZm(rad(a0))), {type: "swing", axis: "Z", amt: a1 - a0}); // v0.2 export
      at(F, "box", [len, 0.16, 0.07], "bone", (u, tt) => Tm(...root).multiply(RZm(th(u, tt))).multiply(Tm(len / 2, 0, 0)), {role: "blade", group: g});
      at(F, "box", [len * 0.9, 0.05, 0.09], "glow", (u, tt) => Tm(...root).multiply(RZm(th(u, tt))).multiply(Tm(len * 0.5, -0.08, 0)), {role: "edge", group: g});
      F.cyl([0.16, 0.14, 0], root, [0, 0, 90], "brass");
    }
  }
}
// B · Chain Claw — Gears of War: the Lancer's chainsaw bayonet (a chain of teeth running round a bar)
function clawSaw() {
  for (const [s, side] of SIDES) {
    const H = mountOn(`Arm${side}_hand`); // X = forward, Y = up, Z = +X world
    H.box([0.62, 0.42, 0.5], [0.05, 0.1, 0], null, "shell"); H.box([0.66, 0.06, 0.54], [0.05, -0.1, 0], null, "trim");
    H.cyl([0.3, 0.56, 0], [-0.12, 0.38, 0], [0, 0, 90], "dark"); H.cyl([0.18, 0.6, 0], [-0.12, 0.38, 0], [0, 0, 90], "brass");
    H.cyl([0.08, 0.3, 0], [-0.3, 0.55, s * 0.16], null, "iron");
    H.box([0.04, 0.26, 0.5], [0.37, 0.1, 0], null, "glow");
    H.box([1.45, 0.2, 0.07], [1.03, -0.02, 0], null, "steel"); H.cyl([0.2, 0.07, 0], [1.75, -0.02, 0], [0, 0, 90], "steel");
    const L = 1.45, R = 0.12, P = 2 * L + 2 * Math.PI * R, N = 18;
    for (let k = 0; k < N; k++) at(H, "box", [0.09, 0.09, 0.1], "bone", (u, tt) => {
      let d = ((k / N) * P + tt * (0.25 + 3.5 * u)) % P, x, y, a;
      if (d < L) { x = 0.3 + d; y = 0.11; a = 0; } else if ((d -= L) < Math.PI * R) { a = -d / R; x = 1.75 + Math.sin(-a) * R; y = -0.02 + Math.cos(a) * R + 0.01; }
      else if ((d -= Math.PI * R) < L) { x = 1.75 - d; y = -0.15; a = Math.PI; } else { d -= L; a = Math.PI - d / R; x = 0.3 - Math.sin(d / R) * R; y = -0.02 - Math.cos(d / R) * R; }
      return Tm(x, y, 0).multiply(RZm(a)).multiply(RZm(Math.PI / 4)); }, {role: "tooth"});
  }
}
// C · Spring Blades — Assassin's Creed: the Hidden Blade that springs out of the wrist bracer
function clawSpring() {
  for (const [s, side] of SIDES) {
    const F = mountOn(`Arm${side}_fore`); F.box([0.4, 0.75, 0.38], [0, -0.2, 0], null, "plate");
    for (const y of [0.1, -0.5]) F.box([0.46, 0.07, 0.44], [0, y, 0], null, "trim");
    const H = mountOn(`Arm${side}_hand`);
    H.box([0.86, 0.2, 0.36], [0.05, -0.21, 0], null, "shell"); H.box([0.04, 0.08, 0.3], [0.49, -0.21, 0], null, "glow");
    H.bolt([-0.2, -0.21, 0.19], "z"); H.bolt([0.25, -0.21, 0.19], "z");
    for (const z of [0.1, -0.1]) {
      const ext = (u, tt) => u * (0.55 + 0.45 * Math.max(0, Math.sin(tt * 5 + (z > 0 ? 0 : 1.2))));
      at(H, "box", [0.8, 0.05, 0.06], "bone", (u, tt) => Tm(0.08 + ext(u, tt) * 1.05, -0.21, z), {role: "blade"});
      at(H, "box", [0.12, 0.06, 0.08], "glow", (u, tt) => Tm(0.46 + ext(u, tt) * 1.05, -0.21, z), {show: u => u > 0.1});
    }
    at(H, "box", [0.3, 0.05, 0.05], "brass", (u, tt) => Tm(-0.15, -0.07, s * 0.12).multiply(RZm(-u * 0.6 * Math.max(0, Math.sin(tt * 5)))));
  }
}
function oldClaw() { oldPieces(OLDP.pieces.ironclaw); }

// ============================================ 2 · GLIDER WINGS (speed) ============================================
// A · Sword Wings — Zoids Storm Sworder: a pteranodon Zoid whose wings are a row of long blades
function wingSword() {
  for (const [s, side] of SIDES) {
    const M = mount("Torso_chest", [s * 0.42, 1.05, -1.05]);
    M.box([0.36, 0.3, 0.62], [0, 0, 0], null, "shell"); M.box([0.4, 0.06, 0.66], [0, -0.13, 0], null, "trim");
    M.cyl([0.24, 0.36, 0], [0, 0.12, 0], null, "brass"); M.ball(0.18, [s * 0.18, 0.05, -0.2], "glow");
    for (let i = 0; i < 4; i++) {
      const len = [2.7, 2.3, 1.85, 1.35][i], sw = 8 + 17 * i;
      const af = rad(-90 + 4 * s), ao = s > 0 ? rad(-sw) : rad(-180 + sw), d0 = rad(-12 - 2 * i), d1 = rad(6 - 3 * i);
      const base = Tm(0, 0.16 - 0.05 * i, 0.06 * i);
      const gy = M.group(`wing_${side}${i + 1}`, base.clone().multiply(RYm(af)), {type: "swing", axis: "Y", amt: THREE.MathUtils.radToDeg(ao - af)}); // v0.2 export
      const gd = M.group(`droop_${side}${i + 1}`, base.clone().multiply(RYm(af)).multiply(RZm(d0)), {type: "swing", axis: "Z", amt: THREE.MathUtils.radToDeg(d1 - d0)}, gy);
      const fr = u => base.clone().multiply(RYm(lerp(af, ao, u))).multiply(RZm(lerp(d0, d1, u)));
      at(M, "box", [len, 0.07, 0.24], "steel", u => fr(u).multiply(Tm(len / 2, 0, 0)), {role: "blade", group: gd});
      at(M, "box", [len * 0.95, 0.05, 0.06], "bone", u => fr(u).multiply(Tm(len * 0.5, 0, -0.15 * s)), {group: gd});
      film(M, "box", [len * 0.92, 0.03, 0.5], 0xffb340, u => fr(u).multiply(Tm(len * 0.48, -0.02, 0.36 * s)), u => u * 0.55, {show: u => u > 0.15, role: "membrane", group: gd});
    }
  }
}
// B · Paraglider — Zelda: Breath of the Wild's paraglider, a canopy that pops out of the back pack
function wingPara() {
  const M = mount("Torso_hump", [0, 1.45, -0.95]);
  M.box([0.75, 0.42, 0.7], [0, 0.05, 0], null, "shell"); M.box([0.8, 0.08, 0.74], [0, -0.14, 0], null, "trim");
  M.box([0.5, 0.08, 0.05], [0, 0.1, -0.37], null, "glow");
  for (const s of [1, -1]) M.box([0.06, 0.9, 0.12], [s * 0.46, -0.45, 0.05], null, "trim");
  at(M, "cyl", [0.34, 0.95, 0], "sail", () => Tm(0, 0.42, 0.08).multiply(RZm(Math.PI / 2)), {show: u => u < 0.15});
  const R = 2.4, Cy = 0.3, top = V3(0, 0.3, 0), N = 7;
  const grow = u => Math.max(0.02, sm((u - 0.05) / 0.8));
  const pt = (phi, z) => [R * Math.sin(phi), Cy + R * Math.cos(phi), z];
  for (let j = 0; j < N; j++) { const phi = rad(-66 + 22 * j);
    at(M, "box", [0.96, 0.06, 1.7], j % 2 ? "sail" : "clothW", u => { const k = grow(u); return Tm(0, 0.3, 0).multiply(SC(k, k, k)).multiply(Tm(0, -0.3, 0)).multiply(Tm(...pt(phi, -0.1))).multiply(RZm(-phi)); }, {show: u => u > 0.1, role: "canopy"}); }
  for (const [phi, z] of [[-77, -0.85], [-77, 0.65], [77, -0.85], [77, 0.65], [0, -0.85], [0, 0.65]]) {
    at(M, "cyl", [0.03, 1, 0], "rubber", u => { const k = grow(u), P = pt(rad(phi), z); return lineM([Math.sign(phi) * 0.3, 0.25, z * 0.3], [P[0] * k, 0.3 + (P[1] - 0.3) * k, P[2] * k]); }, {show: u => u > 0.2}); }
}
// C · Feather Fans — Microraptor: the four-winged gliding dinosaur (long feathers on its arms and legs)
function wingFeather() {
  for (const [s, side] of SIDES) {
    const F = mountOn(`Arm${side}_fore`);
    F.box([0.36, 0.9, 0.34], [0, -0.1, 0], null, "shell"); F.box([0.42, 0.07, 0.4], [0, 0.3, 0], null, "trim"); F.box([0.05, 0.5, 0.12], [0.19, -0.1, 0], null, "glow");
    for (let i = 0; i < 6; i++) { const root = [-0.17, 0.35 - i * 0.17, 0], len = 0.75 + 0.22 * i;
      const fr = u => Tm(...root).multiply(RZm(rad(lerp(266 - i, 192 + i * 13, u))));
      at(F, "box", [len, 0.2, 0.04], i % 2 ? "steel" : "plate", u => fr(u).multiply(Tm(len / 2, 0, 0)), {role: "feather"});
      at(F, "box", [0.18, 0.21, 0.05], "glow", u => fr(u).multiply(Tm(len - 0.09, 0, 0)), {detail: true}); }
    const S = mountOn(`Shin${side}_shin`);
    S.box([0.3, 0.6, 0.3], [0, 0.1, 0], null, "shell");
    for (let i = 0; i < 3; i++) { const root = [-0.13, 0.3 - i * 0.2, 0], len = 0.6 + 0.18 * i;
      const fr = u => Tm(...root).multiply(RZm(rad(lerp(262, 178 + i * 14, u))));
      at(S, "box", [len, 0.18, 0.04], "steel", u => fr(u).multiply(Tm(len / 2, 0, 0)), {role: "feather"});
      at(S, "box", [0.14, 0.19, 0.05], "glow", u => fr(u).multiply(Tm(len - 0.07, 0, 0)), {detail: true}); }
  }
}
function oldGlider() { oldPieces(OLDP.pieces.glider, {show: u => u < 0.5}); oldPieces(OLDP.pieces.glider_open, {show: u => u >= 0.5}); }

// ============================================ 3 · QUILL LAUNCHER (attack) ============================================
// A · Spike Tail — Monster Hunter Nargacuga: it raises its tail and flicks the spikes on it at you
function quillTail() {
  for (const [seg, n, h] of [["Tail2_main", 3, 0.42], ["Tail3_main", 3, 0.36], ["Tail4_main", 2, 0.28]]) {
    const M = mountOn(seg), sz = dino.byName[seg].size, top = sz[1] / 2 + 0.06;
    M.box([sz[0] * 0.8, sz[1] + 0.12, sz[2] + 0.12], [0, 0, 0], null, "shell");
    for (const x of [-sz[0] * 0.42, sz[0] * 0.42]) M.box([0.07, sz[1] + 0.18, sz[2] + 0.18], [x, 0, 0], null, "trim");
    for (let j = 0; j < n; j++) { const x = (j / (n - 1) - 0.5) * sz[0] * 0.6;
      for (const zs of [1, -1]) { const z = zs * sz[2] * 0.32;
        at(M, "cone", [0.13, h], "bone", (u, tt) => { const k = 0.65 + 0.35 * u; return Tm(x, top + h * k / 2, z).multiply(rot(32 - 22 * u, 0, 18 * zs)).multiply(SC(1, k, 1)); }, {role: "spike"});
        M.box([0.16, 0.04, 0.16], [x, top, z], null, "glow", D); } }
  }
  const W = mountOn("Tail3_main");
  flights(W, 5, 0.9, "cone", [0.1, 0.45], "bone", (d, k) => Tm(12 * d, 0.45 + 3.4 * d - 1.2 * d * d, 0.25 * Math.sin(k * 2.3)).multiply(RZm(-Math.PI / 2 + 0.3 * (1 - d))));
}
// B · Missile Pods — Zoids Gun Sniper: two 8-shot missile pods on its back that open from a rear hinge
function quillPods() {
  for (const [s, side] of SIDES) {
    const M = mount("Torso_hump", [s * 0.56, 1.15, -0.95], [-10 * s, 0, 0]);
    M.box([0.42, 0.44, 1.1], [0, 0, 0], null, "shell"); M.box([0.46, 0.08, 1.14], [0, -0.2, 0], null, "trim");
    M.cyl([0.12, 0.46, 0], [0, 0.22, 0.55], [90, 0, 0], "brass");
    for (const x of [-0.1, 0.1]) for (const y of [-0.08, 0.1]) M.cyl([0.13, 0.04, 0], [x, y, -0.56], [0, 0, 90], "glow", {role: "tip"});
    const gl = M.group(`lid_${side}`, Tm(0, 0.25, 0.55), {type: "swing", axis: "X", amt: 58}); // v0.2 export
    at(M, "box", [0.46, 0.08, 1.12], "plate", u => Tm(0, 0.25, 0.55).multiply(RXm(u * rad(58))).multiply(Tm(0, 0, -0.56)), {role: "lid", group: gl});
    at(M, "box", [0.4, 0.04, 0.08], "hazY", u => Tm(0, 0.25, 0.55).multiply(RXm(u * rad(58))).multiply(Tm(0, 0.05, -1.06)), {detail: true, group: gl});
    for (const x of [-0.1, 0.1]) M.add("cone", [0.09, 0.4], [x, 0.12, -0.25], [0, 0, -90], "bone");
    flights(M, 4, 0.8, "cone", [0.1, 0.45], "bone", (d, k) => Tm((k % 2 ? 0.1 : -0.1) + s * 0.6 * d, 0.1 + 2.4 * d - 1.4 * d * d, -0.6 - 13 * d).multiply(RXm(-Math.PI / 2)));
    M.hose([0, -0.15, 0.4], [-s * 0.45, -0.35, 0.2], 0.1, 0.1, 4);
  }
}
// C · Quill Revolver — Horizon Zero Dawn Stalker: its Dart Gun, a small turret that fires darts
function quillRevolver() {
  hideBody(["Torso_quill5", "Torso_quill6", "Torso_quill7"]);
  const M = mount("Torso_hump", [0, 1.48, -1.05]);
  const yaw = (u, tt) => 0.35 * Math.sin(tt * 0.7) * (1 - u);
  M.cyl([0.75, 0.14, 0], [0, 0, 0], null, "dark"); M.cyl([0.62, 0.06, 0], [0, 0.1, 0], null, "brass");
  at(M, "box", [0.5, 0.36, 0.7], "shell", (u, tt) => RYm(yaw(u, tt)).multiply(Tm(0, 0.3, 0.05)));
  at(M, "cyl", [0.44, 0.48, 0], "iron", (u, tt) => RYm(yaw(u, tt)).multiply(Tm(0, 0.36, -0.42)).multiply(RXm(Math.PI / 2)));
  for (let k = 0; k < 6; k++) at(M, "cone", [0.08, 0.62], "bone", (u, tt) => RYm(yaw(u, tt)).multiply(Tm(0, 0.36, -0.42)).multiply(RZm(tt * (0.5 + 10 * u) + k * Math.PI / 3)).multiply(Tm(0, 0.15, 0)).multiply(RXm(-Math.PI / 2)), {role: "quill"});
  at(M, "cyl", [0.15, 0.7, 0], "steel", (u, tt) => RYm(yaw(u, tt)).multiply(Tm(0, 0.36, -0.95 + u * 0.08 * Math.abs(Math.sin(tt * 10)))).multiply(RXm(Math.PI / 2)));
  at(M, "cyl", [0.18, 0.05, 0], "glow", (u, tt) => RYm(yaw(u, tt)).multiply(Tm(0, 0.36, -1.3)).multiply(RXm(Math.PI / 2)));
  M.hose([0.2, 0.05, 0.3], [0.32, -0.35, 0.65], 0.12, 0.12, 4);
  flights(M, 6, 0.6, "cone", [0.08, 0.45], "bone", (d, k) => Tm(0, 0.36 + 0.5 * d, -1.35 - 14 * d).multiply(RXm(-Math.PI / 2)));
}
function oldQuills() { hideBody(QUILLS); oldPieces(OLDP.pieces.quills); }

// ============================================ 4 · SMOKE PODS (engineer) ============================================
// A · Stealth Generator — Horizon Zero Dawn Stalker: the Stealth Generator that cloaks it
function smokeStealth() {
  const M = mountOn("Tail1_main"); // X = toward the body, Y = up
  M.box([0.85, 0.3, 0.56], [0, 0.36, 0], null, "shell"); M.box([0.9, 0.06, 0.6], [0, 0.22, 0], null, "trim");
  M.box([0.5, 0.06, 0.2], [0, 0.53, 0], null, "glow", {role: "nozzle"});
  for (let k = 0; k < 4; k++) { const x = -0.3 + k * 0.2, sg = k % 2 ? 1 : -1;
    const g = M.group(`fin_${k + 1}`, Tm(x, 0.5, 0), {type: "swing", axis: "X", amt: sg * 40}); // v0.2 export
    at(M, "box", [0.05, 0.5, 0.32], k % 2 ? "steel" : "plate", (u, tt) => Tm(x, 0.5, 0).multiply(RXm(sg * u * 0.7 * (0.8 + 0.2 * Math.sin(tt * 6 + k)))).multiply(Tm(0, 0.25, 0)), {role: "fin", group: g}); }
  M.hose([0.4, 0.25, 0.22], [0.75, 0.05, 0.25], 0.08, 0.1, 4);
  puffs(M, 8, 2.2, [0, 0.8, 0], [0, 0.25, 1], 3.2, 0.9); puffs(M, 8, 2.2, [0, 0.8, 0], [0, 0.25, -1], 3.2, 0.9);
  film(mount("Torso_hips", [0, 0, 0]), "ball", [1, 1, 1], 0x9fc4ff, (u, tt) => Tm(0, -0.4, -0.6).multiply(SC(5.5, 4, 7)), u => u * 0.05, {show: u => u > 0.05});
}
// B · Smoke Dischargers — real tanks: banks of smoke-grenade tubes on the turret sides
function smokeDisch() {
  for (const [s, side] of SIDES) {
    const M = mount("Torso_chest", [s * 0.57, 0.85, -1.15]);
    M.box([0.12, 0.42, 0.52], [0, 0, 0], null, "dark"); M.box([0.16, 0.06, 0.56], [s * 0.02, -0.2, 0], null, "trim");
    const v = V3(s * 0.75, 0.6, -0.28).normalize();
    for (const y of [-0.1, 0.1]) for (const z of [-0.14, 0.14]) {
      const base = [s * 0.12, y, z], tip = [base[0] + v.x * 0.42, y + v.y * 0.42, z + v.z * 0.42];
      at(M, "cyl", [0.14, 1, 0], "iron", () => lineM(base, tip));
      at(M, "cyl", [0.15, 0.05, 0], "glow", (u, tt) => { const q = (tt / 1.6 + (y + z) * 2) % 1, fly = u > 0.3 && q < 0.5 ? q * 2 : 0;
        return Tm(tip[0] + v.x * fly * 3, tip[1] + v.y * fly * 3 - 2 * fly * fly, tip[2] + v.z * fly * 3).multiply(new THREE.Matrix4().makeRotationFromQuaternion(new THREE.Quaternion().setFromUnitVectors(V3(0, 1, 0), v))); }, {role: "cap"});
    }
    puffs(M, 6, 1.6, [s * 2.4, -0.7, 0.2], [s * 0.6, 0.15, 0.2], 2.5, 1.0);
  }
}
// C · Exhaust Stacks — Mad Max: Fury Road: the war cars' tall chrome exhaust stacks with flapping caps
function smokeStacks() {
  for (const [s, side] of SIDES) {
    const M = mount("Torso_hips", [s * 0.3, 0.42, 0.55]);
    const top = [s * 0.18, 1.55, 0.35];
    M.box([0.28, 0.12, 0.34], [0, 0, 0], null, "dark"); at(M, "cyl", [0.2, 1, 0], "bright", () => lineM([0, 0.05, 0], top));
    for (const f of [0.35, 0.7]) at(M, "cyl", [0.26, 1, 0], "brass", () => lineM([top[0] * f, 1.55 * f - 0.04, top[2] * f], [top[0] * f, 1.55 * f + 0.04, top[2] * f]));
    M.cyl([0.17, 0.05, 0], [top[0], top[1] - 0.02, top[2]], null, "glow");
    at(M, "box", [0.24, 0.04, 0.24], "iron", (u, tt) => Tm(top[0], top[1] + 0.02, top[2] + 0.12).multiply(RXm(-(0.15 + u * 0.9 * Math.abs(Math.sin(tt * 9 + s))))).multiply(Tm(0, 0, -0.12)), {role: "flap"});
    puffs(M, 7, 1.4, [top[0], top[1] + 0.2, top[2]], [s * 0.1, 1, 0.5], 2.6, 0.55);
  }
}
function oldSmoke() { oldPieces(OLDP.pieces.smoke); }

// ============================================ 5 · BACK PLATING (defense) ============================================
// A · Lamellar Armour — samurai o-yoroi: rows of small steel plates laced together with coloured cord
function plateLamellar() {
  hideBody(QUILLS);
  let n0 = 0, r = 0;
  for (const seg of ["Torso_hips", "Torso_waist", "Torso_chest", "Torso_hump", "Tail1_main", "Tail2_main"]) {
    const M = mountOn(seg), sz = dino.byName[seg].size, n = Math.max(2, Math.round(sz[0] / 0.42)), top = sz[1] / 2 + 0.04, side = seg.startsWith("Torso") && seg !== "Torso_hump";
    const g = M.group(`row_${++r}`, Tm(0, 0, 0), {type: "slide", axis: "Y", amt: 0.05}); // v0.2 export: one ripple row per body segment
    const cols = [[0, top, -1], [1, top, 1]]; // v0.2: merged plates (Kepu red-team "Merge to ~60")
    for (let i = 0; i < n; i++) { const x = (i + 0.5) / n * sz[0] - sz[0] / 2, k = n0 + i;
      for (const [c, y, zc] of cols) at(M, "box", [sz[0] / n + 0.06, 0.05, sz[2] / 2 + 0.06], c ? "plate" : "steel", (u, tt) => Tm(x, y + u * 0.05 * Math.max(0, Math.sin(tt * 8 - k * 0.7)), zc * sz[2] / 4).multiply(RZm(rad(-10))), {role: "plate", group: g});
      if (side) for (const zs of [1, -1]) at(M, "box", [sz[0] / n + 0.06, sz[1] * 0.4, 0.05], "steel", (u, tt) => Tm(x, sz[1] * 0.18, zs * (sz[2] / 2 + 0.04 + u * 0.04 * Math.max(0, Math.sin(tt * 8 - k * 0.7)))).multiply(RZm(rad(-10))), {role: "plate", group: g}); }
    n0 += n;
    M.box([sz[0], 0.03, 0.05], [0, top + 0.035, 0], null, "glow", {detail: true, group: g});
  }
}
// B · Riot Shield — Rainbow Six Siege: Montagne's shield that extends to cover him
function plateRiot() {
  hideBody(["Torso_quill1", "Torso_quill2", "Torso_quill3", "Torso_quill4"]);
  const M = mount("Torso_waist", [0, 0.68, 0.12], [0, 0, 11]);
  M.box([0.55, 0.1, 0.9], [0, 0, 0], null, "dark"); M.cyl([0.12, 0.6, 0], [0, 0.04, 0.45], [90, 0, 0], "brass");
  for (let k = 0; k < 3; k++) {
    const sec = (u) => { const e = u * (0.55 + 0.62 * k); return Tm(0, 0.1 + 0.09 * (2 - k) - u * 0.12 * k, -0.45 + e).multiply(RXm(u * rad(30 + 24 * k))).multiply(Tm(0, 0, 0.45)); };
    at(M, "box", [1.0 + 0.12 * k, 0.12, 0.9], k === 1 ? "plate" : "shell", u => sec(u), {role: "shield"});
    at(M, "box", [0.9 + 0.12 * k, 0.03, 0.06], "glow", u => sec(u).multiply(Tm(0, 0.05, 0.4)));
    at(M, "box", [0.2, 0.03, 0.3], "hazY", u => sec(u).multiply(Tm(0, 0.05, -0.1)), {detail: true, show: () => k === 0});
  }
  film(M, "box", [1.4, 0.04, 1.6], BLUE, u => Tm(0, -0.05 - u * 0.25, 1.4).multiply(RXm(rad(40))), (u, tt) => u * 0.25 * (0.6 + 0.4 * Math.sin(tt * 6)), {show: u => u > 0.3});
}
// C · Spike Ridge — Kentrosaurus: a stegosaur with plates on its neck and long spikes down its back, tail and shoulders
function plateSpikes() {
  hideBody(QUILLS);
  QUILLS.forEach((q, i) => { const c = dino.byName[q].cf, p = V3().setFromMatrixPosition(c), M = mount("Torso_" + (i < 2 ? "hips" : i < 4 ? "waist" : "chest"), [0, p.y - dino.byName[q].size[1] / 2, p.z]);
    if (i >= 4) { // plates in front
      at(M, "box", [0.07, 0.75, 0.55], "plate", (u, tt) => Tm(0, 0.38 + u * 0.06, 0).multiply(RXm(rad(14 - 10 * u))), {role: "plate"});
      at(M, "box", [0.09, 0.06, 0.5], "glow", u => Tm(0, 0.72 + u * 0.06, 0.08).multiply(RXm(rad(14 - 10 * u))));
    } else {
      at(M, "cone", [0.18, 0.8], "bone", (u, tt) => Tm(0, 0.35 + u * 0.05, 0).multiply(RXm(rad(32 - 18 * u))), {role: "spike"});
      M.box([0.22, 0.05, 0.22], [0, 0.02, 0], null, "glow", D);
    } });
  for (const [s, side] of SIDES) {
    const M = mount("Torso_chest", [s * 0.52, 0.55, -1.0]);
    M.box([0.12, 0.42, 0.42], [0, 0, 0], null, "shell"); M.box([0.04, 0.3, 0.3], [s * 0.08, 0, 0], null, "glow");
    at(M, "cone", [0.24, 1.4], "bone", u => (new THREE.Matrix4().compose(V3(s * 0.4, 0.2, 0.55), new THREE.Quaternion().setFromUnitVectors(V3(0, 1, 0), V3(s * (0.55 + 0.25 * u), 0.3 + 0.2 * u, 0.8).normalize()), V3(1, 1, 1))), {role: "spike"});
  }
  for (const [seg, h] of [["Tail1_main", 0.6], ["Tail2_main", 0.5]]) { const M = mountOn(seg), sz = dino.byName[seg].size;
    M.box([sz[0] * 0.4, 0.08, sz[2] + 0.1], [0, sz[1] / 2 + 0.03, 0], null, "shell");
    for (const zs of [1, -1]) at(M, "cone", [0.14, h], "bone", u => Tm(0, sz[1] / 2 + h / 2, zs * 0.12).multiply(rot(38 - 15 * u, 0, zs * (35 + 15 * u))), {role: "spike"}); }
}
function oldPlating() { hideBody(QUILLS); oldPieces(OLDP.pieces.plating); }

// ============================================ 6 · BLOOD SIPHON (health) ============================================
// A · Fang Siphons — Monster Hunter Rise: Sunbreak Malzeno: it drains its prey's life (the Bloodblight)
function siphonFang() {
  const J = mountOn("Jaw_lower"), N = mountOn("Neck_main");
  for (const [s, side] of SIDES) {
    J.box([0.4, 0.14, 0.12], [0.75, 0.05, s * 0.42], null, "dark");
    J.add("cone", [0.1, 0.42], [0.82, -0.18, s * 0.42], [180, 0, 0], "bone", {role: "fang"});
    film(N, "cyl", [0.32, 0.62, 0], 0xcfe8ff, () => Tm(0, -0.02, s * 0.37).multiply(RZm(Math.PI / 2)), () => 0.3, {role: "glass"}).solid = 0.3;
    at(N, "cyl", [0.26, 1, 0], "blood", (u, tt) => { const lv = 0.15 + 0.4 * (u ? (0.5 + 0.5 * Math.sin(tt * 1.4)) : 0.2); return Tm(-0.3 + lv / 2, -0.02, s * 0.37).multiply(RZm(Math.PI / 2)).multiply(SC(1, lv, 1)); }, {role: "core"});
    for (const x of [-0.33, 0.33]) N.cyl([0.36, 0.06, 0], [x, -0.02, s * 0.37], [0, 0, 90], "brass");
    N.cyl([0.2, 0.05, 0], [0.37, -0.02, s * 0.37], [0, 0, 90], "glow");
    cable("Jaw_lower", [s * 0.42, -0.05, -4.5], "Neck_main", [s * 0.37, 0.64, -2.2], 0.15, 0.08);
    for (let k = 0; k < 4; k++) travel(N, "Jaw_lower", [s * 0.42, -0.05, -4.5], "Neck_main", [s * 0.37, 0.64, -2.2], (u, tt) => (tt * 0.9 + k / 4) % 1, "ball", [0.1, 0.1, 0.1], "blood", {show: u => u > 0.2});
  }
  N.box([0.2, 0.3, 0.86], [0.05, 0.25, 0], null, "shell");
}
// B · Medic Tank — Team Fortress 2: the Medic's backpack tank, with a hose to his Medi Gun
function siphonMedic() {
  hideBody(["Torso_quill5", "Torso_quill6", "Torso_quill7"]);
  const M = mount("Torso_hump", [0, 1.55, -0.95]);
  M.cyl([0.6, 1.0, 0], [0, 0, 0], [90, 0, 0], "steel"); for (const x of [-0.5, 0.5]) M.cyl([0.66, 0.08, 0], [x, 0, 0], [90, 0, 0], "brass");
  M.box([0.7, 0.14, 0.4], [0, -0.32, 0], null, "trim");
  film(M, "box", [0.5, 0.22, 0.04], 0xcfe8ff, () => Tm(0, 0.02, -0.31), () => 0.35);
  at(M, "box", [1, 0.18, 0.03], "blood", (u, tt) => { const lv = 0.15 + 0.3 * (u ? 0.5 + 0.5 * Math.sin(tt * 1.2) : 0.3); return Tm(-0.24 + lv / 2, 0.02, -0.31).multiply(SC(lv, 1, 1)); });
  M.cyl([0.3, 0.04, 0], [0.32, 0.18, 0.31], [90, 0, 0], "clothW");
  at(M, "box", [0.02, 0.12, 0.02], "trim", (u, tt) => Tm(0.32, 0.18, 0.34).multiply(RZm(-0.8 + u * 1.6 * (0.5 + 0.5 * Math.sin(tt * 3)))).multiply(Tm(0, 0.05, 0)));
  M.box([0.36, 0.1, 0.1], [0, 0.32, 0], null, "glow"); M.box([0.1, 0.1, 0.36], [0, 0.32, 0], null, "glow");
  cable("Torso_hump", [0.5, 1.5, -0.9], "Neck_main", [0.4, 0.7, -2.1], 0.35, 0.1);
  for (let k = 0; k < 6; k++) { const a = k / 6 * Math.PI * 2; film(M, "ball", [0.14, 0.14, 0.14], BLOODC, (u, tt) => { const d = (tt * 0.7 + k / 6) % 1, r = 5 * (1 - d); return Tm(Math.cos(a) * r, 0.3 + (1 - d) * -1.2, Math.sin(a) * r); }, (u, tt) => u * 0.9, {show: u => u > 0.2}); }
}
// C · Blood Vials — Bloodborne: the glass blood vials hunters carry on their belts
function siphonVials() {
  const M = mountOn("Torso_waist"), sz = dino.byName["Torso_waist"].size;
  M.box([0.2, 0.05, sz[2] + 0.12], [0, sz[1] / 2 + 0.02, 0], null, "trim"); M.box([0.2, 0.05, sz[2] + 0.12], [0, -sz[1] / 2 - 0.02, 0], null, "trim");
  for (const zs of [1, -1]) M.box([0.2, sz[1] + 0.1, 0.05], [0, 0, zs * (sz[2] / 2 + 0.04)], null, "trim");
  M.box([0.16, 0.16, 0.06], [0, 0.05, sz[2] / 2 + 0.08], null, "brass");
  let k = 0;
  for (const [s, side] of SIDES) for (let i = 0; i < 3; i++) { const x = -0.3 + i * 0.3, z = s * (sz[2] / 2 + 0.13), kk = k++;
    film(M, "cyl", [0.17, 0.4, 0], 0xcfe8ff, () => Tm(x, -0.08, z), () => 0.3, {role: "vial"});
    at(M, "cyl", [0.13, 1, 0], "blood", (u, tt) => { const f = u ? Math.min(1, Math.max(0.08, ((tt * 0.5) % 1) * 6 - kk)) : 0.25 + 0.1 * kk; const h = 0.36 * f; return Tm(x, -0.26 + h / 2, z).multiply(SC(1, Math.max(0.01, h), 1)); });
    M.cyl([0.18, 0.07, 0], [x, 0.15, z], null, "glow"); M.box([0.06, 0.1, 0.06], [x, 0.22, z - s * 0.04], null, "trim", D); }
}
function oldSiphon() { oldPieces(OLDP.pieces.siphon); }

// ============================================ 7 · STROBE FRILL (engineer) ============================================
const FRILL = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
// the forward flash cone from the head (the daze cone; 60° in the game, drawn shorter)
function flashCone(period) { const H = mountOn("Head_cranium");
  film(H, "cone", [7, 9, 0], FLASH, (u, tt) => Tm(5.2, 0, 0).multiply(RZm(Math.PI / 2)), (u, tt) => u * 0.3 * flash(tt, period), {show: u => u > 0.1}); }
// A · Flash Crest — Monster Hunter Gypceros: it flashes the crest on its head to blind hunters
function strobeCrest() {
  for (const k of FRILL) {
    const F = mountOn(`Head_frill${k}`), R = mountOn(`Head_frillrim${k}`); // frill: X = forward, Y = out from the head
    F.box([0.04, 0.78, 0.44], [0.07, 0, 0], null, "bright");
    R.box([0.12, 0.2, 0.36], [0.02, 0, 0], null, "dark");
    R.ball(0.2, [0.12, 0.05, 0], "glow", {role: "led"});
    film(R, "ball", [0.5, 0.5, 0.5], FLASH, () => Tm(0.14, 0.05, 0), (u, tt) => u * flash(tt), {show: u => u > 0.1});
  }
  flashCone();
}
// B · Stage Rig — concert moving-head lights: spotlights that pan and tilt, then strobe
function strobeStage() {
  for (const k of FRILL) { const F = mountOn(`Head_frill${k}`); F.box([0.03, 0.7, 0.2], [0.06, -0.02, 0], null, "trim"); }
  for (const k of [2, 4, 6, 8, 10]) {
    const R = mountOn(`Head_frillrim${k}`);
    R.box([0.16, 0.12, 0.32], [0, 0.04, 0], null, "dark");
    const aim = (u, tt) => RYm((1 - u) * 0.6 * Math.sin(tt * 1.3 + k)).multiply(RZm((1 - u) * 0.4 * Math.sin(tt * 1.7 + k * 2)));
    at(R, "box", [0.06, 0.3, 0.36], "iron", (u, tt) => Tm(0.05, 0.22, 0).multiply(aim(u, tt)));
    at(R, "cyl", [0.28, 0.36, 0], "dark", (u, tt) => Tm(0.05, 0.3, 0).multiply(aim(u, tt)).multiply(Tm(0.1, 0, 0)).multiply(RZm(-Math.PI / 2)), {role: "can"});
    at(R, "cyl", [0.22, 0.04, 0], "glow", (u, tt) => Tm(0.05, 0.3, 0).multiply(aim(u, tt)).multiply(Tm(0.29, 0, 0)).multiply(RZm(-Math.PI / 2)));
    film(R, "cone", [0.9, 3, 0], FLASH, (u, tt) => Tm(0.05, 0.3, 0).multiply(aim(u, tt)).multiply(Tm(1.8, 0, 0)).multiply(RZm(Math.PI / 2)), (u, tt) => 0.08 + u * 0.3 * flash(tt, 0.5), {});
  }
  flashCone(0.5);
}
// C · Lighthouse Lamp — a lighthouse's turning lens lantern (and the flashbang's white-out)
function strobeLighthouse() {
  for (const k of FRILL) { const F = mountOn(`Head_frill${k}`); F.box([0.04, 0.78, 0.44], [0.07, 0, 0], null, "bright"); }
  const L = mountOn("Head_cranium");
  const c = [0.12, 0.6, 0];
  L.cyl([0.55, 0.14, 0], c, null, "dark"); L.cyl([0.6, 0.05, 0], [c[0], c[1] + 0.08, 0], null, "brass");
  film(L, "cyl", [0.46, 0.5, 0], 0xcfe8ff, () => Tm(c[0], c[1] + 0.35, 0), () => 0.3);
  for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2; L.box([0.04, 0.5, 0.04], [c[0] + Math.cos(a) * 0.23, c[1] + 0.35, Math.sin(a) * 0.23], null, "brass"); }
  L.add("cone", [0.56, 0.3], [c[0], c[1] + 0.75, 0], null, "dark"); L.ball(0.1, [c[0], c[1] + 0.95, 0], "brass");
  const spin = (u, tt) => u ? 0 : tt * 1.4;
  at(L, "box", [0.3, 0.3, 0.12], "glow", (u, tt) => Tm(c[0], c[1] + 0.35, 0).multiply(RYm(spin(u, tt))), {role: "lens"});
  film(L, "box", [5, 0.22, 0.22], FLASH, (u, tt) => Tm(c[0], c[1] + 0.35, 0).multiply(RYm(spin(u, tt))).multiply(Tm(2.6, 0, 0)), (u, tt) => 0.18 + u * 0.4 * flash(tt), {});
  flashCone();
}
function oldStrobe() { oldPieces(OLDP.pieces.strobe); }

// ============================================ 8 · STUN BREAKER (defense) ============================================
// A · Tesla Coils — Command & Conquer: Red Alert's Tesla Coil tower (a copper coil under a ring and ball that throws arcs)
function breakTesla() {
  const tops = [];
  for (const [s, side] of SIDES) {
    const M = mount("Torso_hump", [s * 0.4, 1.32, -1.0]); tops.push(M);
    M.cyl([0.36, 0.18, 0], [0, 0, 0], null, "dark"); M.cyl([0.14, 0.9, 0], [0, 0.5, 0], null, "steel");
    M.cyl([0.3, 0.6, 0], [0, 0.45, 0], null, "copper"); for (const y of [0.25, 0.45, 0.65]) M.cyl([0.33, 0.035, 0], [0, y, 0], null, "trim"); // v0.2: the winding as a copper drum (export: 5 parts, not 50)
    M.cyl([0.46, 0.06, 0], [0, 0.95, 0], null, "brass", {role: "band"}); M.ball(0.24, [0, 1.06, 0], "bright", {role: "tip"});
    M.ball(0.12, [0, 1.06, 0.13], "glow");
    arc(M, [0, 1.06, 0], [s * 1.6, GROUND - 1.32, 0.3], 6, VOLT, 0.35);
  }
  arc(tops[0], [0, 1.06, 0], [-0.8, 1.06, 0], 5, VOLT, 0.18);
  groundWaves(BLUE, 5);
}
// B · Reactive Bricks — real tanks' explosive reactive armour: bricks that blow outward when hit
function breakBricks() {
  let k = 0;
  for (const seg of ["Torso_chest", "Torso_waist"]) { const M = mountOn(seg), sz = dino.byName[seg].size;
    const nx = seg === "Torso_chest" ? 3 : 2, ny = 2;
    for (const zs of [1, -1]) for (let i = 0; i < nx; i++) for (let j = 0; j < ny; j++) { const x = (i - (nx - 1) / 2) * 0.34, y = (j - 0.5) * 0.3 + (seg === "Torso_chest" ? 0.15 : 0.05), kk = k++;
      M.box([0.34, 0.3, 0.05], [x, y, zs * (sz[2] / 2 + 0.03)], null, "trim");
      const out = (u, tt) => { const q = (tt / 1.4 + kk * 0.03) % 1; return u > 0.3 ? (q < 0.35 ? sm(q / 0.35) : 1 - sm((q - 0.35) / 0.5)) : 0; };
      at(M, "box", [0.3, 0.26, 0.1], "plate", (u, tt) => { const o = out(u, tt); return Tm(x, y, zs * (sz[2] / 2 + 0.1 + o * 1.1)).multiply(RXm(o * 1.2 * zs)).multiply(RYm(o * 0.6)); }, {role: "brick"});
      at(M, "box", [0.24, 0.04, 0.11], "glow", (u, tt) => { const o = out(u, tt); return Tm(x, y + 0.1, zs * (sz[2] / 2 + 0.1 + o * 1.1)).multiply(RXm(o * 1.2 * zs)).multiply(RYm(o * 0.6)); }, {detail: true}); } }
  groundWaves(BLUE, 5);
}
// C · Shock Collar — Horizon Forbidden West Shell-Walker: its Lightning Gun, a shock weapon built into its claw
function breakCollar() {
  const N = mountOn("Neck_main");
  N.add("ring", [0.42, 0.07], [0.1, 0, 0], [0, 90, 0], "iron"); N.add("ring", [0.42, 0.04], [-0.12, 0, 0], [0, 90, 0], "brass");
  for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2, y = Math.cos(a) * 0.45, z = Math.sin(a) * 0.45;
    N.cyl([0.17, 0.32, 0], [0, y, z], [90, 0, 0], "steel");
    N.cyl([0.12, 0.05, 0], [0.18, y, z], [90, 0, 0], "glow"); }
  N.hose([-0.2, 0.3, 0.2], [-0.45, 0.1, 0.45], 0.08, 0.1, 4);
  film(N, "ball", [1, 1, 1], VOLT, (u, tt) => { const d = (tt % 0.9) / 0.9, r = 1 + 9 * d; return SC(r, r, r); }, (u, tt) => u * 0.35 * (1 - (tt % 0.9) / 0.9), {show: u => u > 0.2});
  for (let i = 0; i < 3; i++) arc(N, [0.1, 0.45 * Math.cos(i * 2.1), 0.45 * Math.sin(i * 2.1)], [0.1, 0.45 * Math.cos(i * 2.1 + 1), 0.45 * Math.sin(i * 2.1 + 1)], 3, VOLT, 0.12);
  groundWaves(BLUE, 5);
}
function oldBreaker() { oldPieces(OLDP.pieces.breaker); }

// ============================================ 9 · RAZOR CALTROPS (engineer) ============================================
// spikes falling from a start point to spots on the ground behind (world mount frame), lying there, then fading
function drops(M, n, period, start, land, arcH) {
  for (let k = 0; k < n; k++) { const L = land(k), d = tt => (tt / period + k / n) % 1;
    jack(M, (u, tt) => { const q = d(tt), f = Math.min(1, q / 0.35), y = lerp(start[1], L[1], f * f) + arcH * Math.sin(f * Math.PI);
      return Tm(lerp(start[0], L[0], f), y, lerp(start[2], L[2], f)).multiply(RXm(q < 0.35 ? q * 18 : 0.5)); }, {show: u => u > 0.25}); } }
// A · Drop Chute — Spy Hunter: the spy car that drops oil slicks and smoke out of its rear
function calChute() {
  const M = mountOn("Tail1_main"); // X = toward the body
  M.box([0.62, 0.4, 0.56], [0.15, 0.42, 0], null, "shell"); M.box([0.66, 0.06, 0.6], [0.15, 0.24, 0], null, "trim");
  M.box([0.1, 0.06, 0.4], [0.47, 0.6, 0], null, "glow");
  M.box([0.5, 0.05, 0.36], [-0.4, 0.3, 0], [24, 0, 0], "steel", {role: "chute"});
  const g = M.group("door", Tm(-0.16, 0.6, 0), {type: "swing", axis: "Z", amt: -THREE.MathUtils.radToDeg(1.2)}); // v0.2 export
  at(M, "box", [0.05, 0.36, 0.5], "plate", u => Tm(-0.16, 0.6, 0).multiply(RZm(-u * 1.2)).multiply(Tm(0, -0.18, 0)), {role: "door", group: g});
  M.hazard(0.5, 0.06, [0.15, 0.62, 0.29], null, 6);
  drops(mount("Tail1_main", [0, 0.75, 1.5]), 8, 2.4, [0, 0, 0.3], k => [Math.sin(k * 2.4) * 1.6, GROUND - 0.75 + 0.05, 1.2 + (k % 4) * 0.7], 0.3);
}
// B · Mine Launcher — Horizon Zero Dawn Stalker: its Mine Launcher, which lobs mines onto the ground
function calLauncher() {
  for (const [s, side] of SIDES) {
    const M = mount("Torso_hips", [s * 0.45, 0.25, 0.55]);
    M.box([0.26, 0.5, 0.6], [0, 0, 0], null, "shell"); M.box([0.3, 0.06, 0.64], [0, -0.22, 0], null, "trim");
    at(M, "cyl", [0.36, 0.24, 0], "iron", (u, tt) => Tm(s * 0.15, 0.05, 0).multiply(RZm(Math.PI / 2)).multiply(RYm(tt * (0.3 + 4 * u))));
    const v = V3(s * 0.25, 0.65, 0.72).normalize();
    at(M, "cyl", [0.18, 0.55, 0], "steel", (u, tt) => { const rc = u * 0.07 * Math.abs(Math.sin(tt * 4)); return new THREE.Matrix4().compose(V3(v.x * (0.35 - rc), 0.25 + v.y * (0.35 - rc), 0.15 + v.z * (0.35 - rc)), new THREE.Quaternion().setFromUnitVectors(V3(0, 1, 0), v), V3(1, 1, 1)); });
    M.cyl([0.2, 0.05, 0], [v.x * 0.63, 0.25 + v.y * 0.63, 0.15 + v.z * 0.63], null, "glow");
    drops(M, 5, 1.6, [v.x * 0.65, 0.25 + v.y * 0.65, 0.15 + v.z * 0.65], k => [s * (0.6 + Math.sin(k * 3.1) * 0.9), GROUND - 0.25 + 0.05, 1.5 + k * 0.6], 1.2);
  }
}
// C · Bladescale Tail — Monster Hunter Seregios: it flings the blade-like scales off its tail; they stick in the ground
function calScales() {
  for (const [seg, n] of [["Tail1_main", 3], ["Tail2_main", 3], ["Tail3_main", 2]]) { const M = mountOn(seg), sz = dino.byName[seg].size;
    for (let i = 0; i < n; i++) { const x = (i - (n - 1) / 2) * sz[0] / n;
      for (const zs of [1, -1]) {
        at(M, "box", [0.36, 0.04, 0.2], "steel", (u, tt) => Tm(x, sz[1] / 2, zs * sz[2] * 0.35).multiply(rot(14, 0, zs * 28)).multiply(Tm(-0.1, 0, zs * 0.06)), {role: "scale"});
        at(M, "box", [0.36, 0.045, 0.05], "glow", (u, tt) => Tm(x, sz[1] / 2, zs * sz[2] * 0.35).multiply(rot(14, 0, zs * 28)).multiply(Tm(-0.1, 0.005, zs * 0.15)), D); } }
  }
  const W = mount("Tail2_main", [0, 0.9, 2.6]);
  for (let k = 0; k < 8; k++) { const zs = k % 2 ? 1 : -1, L = [zs * (0.8 + (k % 3) * 0.5), GROUND - 0.9 + 0.12, 1 + k * 0.45], d = tt => (tt / 2 + k / 8) % 1;
    at(W, "box", [0.36, 0.04, 0.2], "steel", (u, tt) => { const q = d(tt), f = Math.min(1, q / 0.3); return Tm(lerp(0, L[0], f), lerp(0, L[1], f * f) + Math.sin(f * Math.PI) * 0.6, lerp(0, L[2], f)).multiply(RXm(f * 1.4)).multiply(RZm(f * zs * 1.2)); }, {show: u => u > 0.25}); }
}
function oldCaltrops() { oldPieces(OLDP.pieces.caltrops); }

// ============================================ 10 · GOO BLOB SHOOTER (engineer) ============================================
// a lime goo blob that arcs from start (world mount frame) to a spot 15 units (30 studs) ahead and splats into a puddle
function blobShot(M, start, period, delay) {
  const end = [start[0], GROUND - M.toRest([0, 0, 0])[1] + 0.03, start[2] - 15];
  film(M, "ball", [0.5, 0.5, 0.5], LIME, (u, tt) => { const q = ((tt + (delay || 0)) % period) / period, f = Math.min(1, q / 0.45);
    return Tm(lerp(start[0], end[0], f), lerp(start[1], end[1], f) + Math.sin(f * Math.PI) * 3, lerp(start[2], end[2], f)); }, () => 0.95, {show: (u, tt) => u > 0.3 && (((tt + (delay || 0)) % period) / period) < 0.45});
  film(M, "cyl", [1, 0.05, 0], LIME, (u, tt) => { const q = ((tt + (delay || 0)) % period) / period, g = Math.max(0, (q - 0.45) / 0.55); return Tm(end[0], end[1], end[2]).multiply(SC(0.5 + 7.5 * sm(g * 3), 1, 0.5 + 7.5 * sm(g * 3))); },
    (u, tt) => u * 0.5 * (1 - Math.max(0, ((((tt + (delay || 0)) % period) / period) - 0.75) * 4)), {show: (u, tt) => u > 0.3 && (((tt + (delay || 0)) % period) / period) >= 0.45});
}
// A · Spit Sacs — Horizon Forbidden West Bilegut: a frog-like machine that spits acid from the sacs on its body
function gooSpit() {
  const N = mountOn("Neck_main");
  for (const [s, side] of SIDES) {
    const sq = (u, tt) => { const p = (tt % 1.2) / 1.2; return 1 + 0.12 * Math.sin(tt * 2) - u * (p > 0.55 && p < 0.7 ? 0.35 : 0); };
    film(N, "ball", [0.62, 0.55, 0.5], LIME, (u, tt) => Tm(-0.02, -0.1, s * 0.38).multiply(SC(sq(u, tt), sq(u, tt), sq(u, tt))), () => 0.6, {role: "sac"}).solid = 0.6;
    for (const x of [-0.03]) at(N, "ring", [0.3, 0.035], "iron", (u, tt) => Tm(x, -0.1, s * 0.38).multiply(RYm(Math.PI / 2)).multiply(SC(sq(u, tt), sq(u, tt), 1)));
    N.cyl([0.14, 0.12, 0], [-0.02, 0.2, s * 0.38], null, "brass"); N.cyl([0.1, 0.05, 0], [-0.02, 0.28, s * 0.38], null, "glow");
  }
  const J = mountOn("Jaw_lower"); J.box([0.5, 0.14, 0.36], [0.55, -0.25, 0], null, "shell"); J.cyl([0.16, 0.3, 0], [0.9, -0.25, 0], [0, 0, -90], "steel", {role: "tube"}); J.cyl([0.17, 0.04, 0], [1.05, -0.25, 0], [0, 0, -90], "glow", {role: "muzzle"});
  blobShot(mount("Head_cranium", [0, 0, 0]), [0, -0.2, -4.6], 1.2, 0.5);
}
// B · Ink Tank — Splatoon: the ink tank on the back that feeds the ink gun through a hose
function gooTank() {
  hideBody(["Torso_quill5", "Torso_quill6", "Torso_quill7"]);
  const M = mount("Torso_hump", [0, 1.62, -0.85]);
  film(M, "cyl", [0.56, 0.85, 0], 0xe0ffd0, () => Tm(0, 0, 0), () => 0.3, {role: "glass"});
  at(M, "cyl", [0.48, 1, 0], "lime", (u, tt) => { const lv = 0.75 - u * 0.4 * ((tt % 1.4) / 1.4); return Tm(0, -0.4 + lv / 2, 0).multiply(SC(1, lv, 1)); });
  for (const y of [-0.45, 0.45]) M.cyl([0.62, 0.08, 0], [0, y, 0], null, "brass"); M.box([0.12, 0.12, 0.12], [0, 0.52, 0], null, "glow");
  const N = mount("Torso_chest", [0.6, 0.85, -1.5]);
  N.box([0.2, 0.26, 0.4], [0, 0, 0], null, "shell"); N.cyl([0.16, 0.65, 0], [0.06, 0.05, -0.45], [0, 0, -90], "steel");
  N.cyl([0.18, 0.05, 0], [0.06, 0.05, -0.78], [0, 0, -90], "glow");
  cable("Torso_hump", [0.25, 1.3, -0.75], "Torso_chest", [0.6, 0.95, -1.3], 0.3, 0.1);
  blobShot(N, [0.06, 0.05, -0.85], 1.4, 0);
}
// C · Goo Catapult — Plants vs. Zombies: the Cabbage-pult / Melon-pult, a spoon arm that lobs its ammo
function gooPult() {
  hideBody(["Torso_quill1", "Torso_quill2", "Torso_quill3", "Torso_quill4"]);
  const M = mount("Torso_waist", [0, 0.72, 0.2]);
  M.box([0.5, 0.16, 0.7], [0, 0, 0], null, "shell"); M.box([0.06, 0.3, 0.2], [0.2, 0.2, -0.1], null, "dark"); M.box([0.06, 0.3, 0.2], [-0.2, 0.2, -0.1], null, "dark");
  M.cyl([0.12, 0.5, 0], [0, 0.3, -0.1], [0, 0, 90], "brass"); M.box([0.3, 0.06, 0.06], [0, 0.1, -0.36], null, "glow");
  coilY(M, [0, 0.18, 0.18], 0.08, 0.18, 3, 0.03, "steel");
  const th = (u, tt) => { const p = (tt % 1.4) / 1.4; return u ? lerp(rad(70), rad(-28), p < 0.55 ? 0 : p < 0.65 ? sm((p - 0.55) / 0.1) : 1 - sm((p - 0.65) / 0.35)) : rad(70); };
  const arm = (u, tt) => Tm(0, 0.3, -0.1).multiply(RXm(th(u, tt)));
  at(M, "box", [0.12, 1.4, 0.12], "steel", (u, tt) => arm(u, tt).multiply(Tm(0, 0.7, 0)), {role: "arm"});
  at(M, "cyl", [0.42, 0.12, 0], "dark", (u, tt) => arm(u, tt).multiply(Tm(0, 1.42, 0)).multiply(RXm(Math.PI / 2)));
  film(M, "ball", [0.34, 0.34, 0.34], LIME, (u, tt) => arm(u, tt).multiply(Tm(0, 1.45, -0.12)), () => 0.9, {show: (u, tt) => !u || ((tt % 1.4) / 1.4) < 0.6 || ((tt % 1.4) / 1.4) > 0.95});
  blobShot(M, [0, 1.6, -1.2], 1.4, -0.6 * 1.4 + 1.4);
}
function oldGoo() { oldPieces(OLDP.pieces.goo); }

// ============================================ 11 · ADRENALINE INJECTOR (health) ============================================
// green veins that glow along the flanks while it works
function veins() { for (const seg of ["Torso_chest", "Torso_waist", "Torso_hips"]) { const M = mountOn(seg), sz = dino.byName[seg].size;
  for (const zs of [1, -1]) for (const y of [0.1, -0.12]) film(M, "box", [sz[0] * 0.9, 0.04, 0.03], GREEN, (u, tt) => Tm(0, y, zs * (sz[2] / 2 + 0.02)), (u, tt) => u * (0.5 + 0.5 * Math.sin(tt * 10 - y * 20)), {show: u => u > 0.1}); } }
// A · Stim Shot — Apex Legends: Octane's Stim, a syringe he jabs for a burst of speed
function adrStim() {
  const M = mountM("Torso_chest", axisFrame([0.36, 0.95, -1.45], [0.55, 0.8, 0.25], [0, 0, -1]));
  M.add("cone", [0.06, 0.35], [0, -0.2, 0], [180, 0, 0], "steel");
  film(M, "cyl", [0.32, 0.9, 0], 0xd8fff0, () => Tm(0, 0.45, 0), () => 0.3, {role: "glass"}).solid = 0.3;
  const inj = (u, tt) => u ? sm(((tt % 1.6) / 1.6) / 0.5) : 0;
  at(M, "cyl", [0.26, 1, 0], "adr", (u, tt) => { const lv = 0.82 * (1 - inj(u, tt)) + 0.02; return Tm(0, 0.04 + lv / 2, 0).multiply(SC(1, lv, 1)); }, {role: "fluid"});
  for (const y of [0, 0.9]) M.cyl([0.38, 0.06, 0], [0, y, 0], null, "brass");
  M.box([0.6, 0.06, 0.12], [0, 0.95, 0], null, "trim");
  const g = M.group("plunger", Tm(0, 1.35, 0), {type: "slide", axis: "Y", amt: -0.8}); // v0.2 export
  at(M, "cyl", [0.08, 0.9, 0], "steel", (u, tt) => Tm(0, 1.35 - inj(u, tt) * 0.8, 0), {group: g});
  at(M, "cyl", [0.3, 0.07, 0], "glow", (u, tt) => Tm(0, 1.82 - inj(u, tt) * 0.8, 0), {group: g});
  veins();
}
// B · Nitro Bottles — racing games' nitrous bottles (Need for Speed's NOS): open the valve for a burst of speed
function adrNitro() {
  for (const [s, side] of SIDES) {
    const M = mount("Torso_hips", [s * 0.36, 0.55, 0.45]);
    M.cyl([0.26, 0.9, 0], [0, 0, 0], [90, 0, 0], "dark"); M.cyl([0.27, 0.12, 0], [0, 0, -0.1], [90, 0, 0], "glow");
    M.add("cone", [0.26, 0.18], [0, 0, -0.54], [-90, 0, 0], "dark"); M.cyl([0.1, 0.12, 0], [0, 0, -0.66], [90, 0, 0], "brass");
    at(M, "box", [0.04, 0.16, 0.04], "brass", (u, tt) => Tm(0, 0.06, -0.72).multiply(RZm(u * 1.4)).multiply(Tm(0, 0.08, 0)));
    for (const z of [-0.3, 0.3]) M.box([0.3, 0.05, 0.08], [0, -0.12, z], null, "trim");
    const N = mount("Torso_hips", [s * 0.62, -0.35, 0.75]);
    N.cyl([0.18, 0.3, 0], [0, 0, 0], [70, 0, 0], "iron"); N.cyl([0.2, 0.05, 0], [0, -0.05, 0.15], [70, 0, 0], "glow");
    film(N, "cone", [0.24, 0.9, 0], GREEN, (u, tt) => Tm(0, -0.2, 0.55).multiply(RXm(rad(-110))).multiply(SC(1, 0.7 + 0.3 * Math.sin(tt * 30), 1)), u => u * 0.7, {show: u => u > 0.2});
    cable("Torso_hips", [s * 0.36, 0.55, -0.15], `Leg${side}_haunch`, [s * 0.6, -0.25, 0.5], 0.1, 0.08);
  }
  veins();
}
// C · Zoid Core — Zoids: every Zoid has a living core in its chest that powers it
function adrCore() {
  const B = mountOn("Torso_breast"); // X = forward-up out of the chest
  B.box([0.14, 0.85, 0.85], [0.22, 0, 0], null, "shell");
  film(B, "ball", [0.8, 0.8, 0.8], 0xd8fff0, () => Tm(0.55, 0, 0), () => 0.25, {role: "glass"});
  const beat = (u, tt) => { const q = (tt * (1 + 1.6 * u)) % 1; return 1 + 0.25 * Math.max(0, 1 - q / 0.15) + 0.12 * Math.max(0, 1 - Math.abs(q - 0.28) / 0.1); };
  at(B, "ball", [0.46, 0.46, 0.46], "adr", (u, tt) => Tm(0.55, 0, 0).multiply(SC(beat(u, tt), beat(u, tt), beat(u, tt))), {role: "core"});
  for (const r of [0, Math.PI / 2]) B.add("ring", [0.42, 0.04], [0.55, 0, 0], [0, 90, r ? 90 : 0], "iron");
  for (const zs of [1, -1]) { B.cyl([0.14, 0.3, 0], [0.3, 0.3 * zs, 0.3 * zs], null, "dark");
    at(B, "cyl", [0.08, 0.3, 0], "steel", (u, tt) => Tm(0.3, 0.3 * zs + 0.2 * zs * (beat(u, tt) - 1), 0.3 * zs).multiply(Tm(0, 0.12 * zs, 0))); }
  waves(B, 2, 0.6, (u, tt, d) => Tm(0.55 + d * 1.5, 0, 0).multiply(RZm(-Math.PI / 2)), GREEN, 0.4, 1.4, 0.05);
  veins();
}
function oldAdren() { oldPieces(OLDP.pieces.hadren); }

// ============================================ the parts (SkillTree names / areas) ============================================
const PARTS = [
  {id: "ironclaw", short: "Claw", name: "Iron Claw", area: "attack", focus: [0, -1.5, -2], oldText: "Hook Blades: a steel sickle curving forward out of each hand, with an orange glowing edge, and a steel cuff on the forearm. Nothing moves; the slash shows a trail.",
    looks: [
      {name: "Wing Blades", sub: "blades on the forearms", build: clawWing, pose: SLASH, ref: "Monster Hunter — Nargacuga: blades along the back edge of its wing-arms, swung in its slashes.",
        why: "A studded bracer on each forearm with three bone-white blades hinged on its back edge, red edges glowing. At rest they lie back along the arm; when it slashes they swing forward past the claws.", use: "Blades swing forward with each slash.", on: "Both forearms."},
      {name: "Chain Claw", sub: "chainsaw bar", build: clawSaw, pose: SLASH, ref: "Gears of War — the Lancer's chainsaw bayonet.",
        why: "A motor housing on each hand with a steel bar sticking out forward and a chain of bone-white teeth running round it. It idles slowly; when it slashes the chain races.", use: "Chain spins fast while slashing.", on: "Both hands (reaches as far as the old sickle)."},
      {name: "Spring Blades", sub: "blades shoot out", build: clawSpring, pose: SLASH, ref: "Assassin's Creed — the Hidden Blade that springs out of the wrist bracer.",
        why: "A plated bracer on each forearm and a slim housing under each hand. Two straight blades hide inside it; with each slash they spring out forward, red tips glowing, and snap back.", use: "Twin blades shoot out with each slash.", on: "Both forearms + under the hands."},
    ]},
  {id: "glider", short: "Glider", name: "Glider Wings", area: "speed", focus: [0, 1, -1], oldText: "Bat Membranes: three orange canvas panels per side on a steel spar from the chest, folded to a stub while running and opened while gliding (finger rods show when open).",
    looks: [
      {name: "Sword Wings", sub: "blade fan wings", build: wingSword, pose: GLIDE, ref: "Zoids — Storm Sworder: a pteranodon Zoid whose wings are a row of long blades.",
        why: "Four long steel blades on a hinge block on each shoulder. Folded, they lie back along the flanks like swords in a sheath; when it glides they fan out sideways into a wing, with glowing yellow panels between them.", use: "Blades fan out into a wing; yellow panels light.", on: "Both shoulders (folded along the flanks)."},
      {name: "Paraglider", sub: "canopy from a pack", build: wingPara, pose: GLIDE, ref: "Zelda: Breath of the Wild — the paraglider, a canopy that pops out over Link.",
        why: "A backpack on the hump with the canopy rolled up on top. When it glides a big striped yellow canopy pops open above it on lines; when it lands it rolls back into the pack.", use: "Canopy pops open above; rolls up on landing.", on: "Top of the back (the hump)."},
      {name: "Feather Fans", sub: "steel feathers", build: wingFeather, pose: GLIDE, ref: "Microraptor — the real four-winged gliding dinosaur, with long feathers on its arms and legs.",
        why: "Six steel feathers on a bracer on each forearm and three on each shin, yellow tips. Folded, they lie flat along the limbs; when it glides they fan back into four wings.", use: "Feathers fan out on the arms and legs.", on: "Both forearms + both shins."},
    ]},
  {id: "quills", short: "Quills", name: "Quill Launcher", area: "attack", focus: [0, 1.5, 0], oldText: "Spine Quills: the 7 back quills replaced by thicker steel quills with orange glowing tips and dark collars. Nothing moves; the quills fly from the back.",
    looks: [
      {name: "Spike Tail", sub: "tail spike rows", build: quillTail, pose: TAILUP, ref: "Monster Hunter — Nargacuga: it raises its tail and flicks the spikes on it at you.",
        why: "Studded sheaths on the tail with rows of bone-white spikes, red glow at their roots. When used the tail lifts, the spikes stand up and quills fly forward over the head.", use: "Tail lifts, spikes rise, quills fly forward.", on: "Middle of the tail (back quills stay)."},
      {name: "Missile Pods", sub: "twin back pods", build: quillPods, pose: AIM, ref: "Zoids — Gun Sniper: two 8-shot missile pods on its back that open from a rear hinge.",
        why: "A studded pod on each shoulder with red tube mouths and a hazard-striped lid hinged at the back. When used the lids swing up and quills launch from both pods in turn.", use: "Lids open, quills launch from both pods.", on: "Both shoulders on the back (back quills stay)."},
      {name: "Quill Revolver", sub: "spinning turret", build: quillRevolver, pose: AIM, ref: "Horizon Zero Dawn — Stalker: its Dart Gun, a small turret that fires darts.",
        why: "A small turret on the hump with a six-quill revolving drum and a barrel. It turns slowly to look around; when used it locks forward, the drum spins and quills fire in a fast stream.", use: "Drum spins, barrel kicks, quill stream.", on: "The hump (hides the 3 front back quills)."},
    ]},
  {id: "smoke", short: "Smoke", name: "Smoke Pods", area: "eng", focus: [0, 0.5, 1.2], oldText: "Tail Vents: a dark vent box with an orange glow band and grilles on the tail base. Nothing moves; the smoke comes from the tail.",
    looks: [
      {name: "Stealth Generator", sub: "fins + haze", build: smokeStealth, pose: {}, ref: "Horizon Zero Dawn — Stalker: the Stealth Generator that cloaks it.",
        why: "A studded generator on the tail base with four fins standing on it and an orange core. When used the fins fan open and grey haze rolls out both sides, with a faint shimmer over the body.", use: "Fins fan open, haze rolls out sideways.", on: "Tail base (same spot as now)."},
      {name: "Smoke Dischargers", sub: "grenade tubes", build: smokeDisch, pose: {}, ref: "Real tanks — banks of smoke-grenade tubes on the turret sides.",
        why: "A bracket of four short tubes on each side of the chest pointing up and out, with orange caps. When used the caps fire off in arcs and burst into smoke beside it.", use: "Caps fire out, smoke bursts at both sides.", on: "Both sides of the chest."},
      {name: "Exhaust Stacks", sub: "chrome pipes", build: smokeStacks, pose: {}, ref: "Mad Max: Fury Road — the war cars' tall chrome exhaust stacks with flapping caps.",
        why: "Two tall chrome pipes up behind the hips with brass bands, orange glow inside and flap caps. When used the caps rattle open and thick grey smoke chugs out and up.", use: "Caps rattle, smoke chugs out.", on: "Both hips (pipes rise behind the back)."},
    ]},
  {id: "plating", short: "Plating", name: "Back Plating", area: "defense", focus: [0, 0.8, 0.3], oldText: "Spine Scutes: steel armour scutes along the back and tail base (they replace the 7 back quills). Nothing moves.",
    looks: [
      {name: "Lamellar Armour", sub: "laced plate rows", build: plateLamellar, pose: BRACE, ref: "Samurai o-yoroi — rows of small steel plates laced together with coloured cord.",
        why: "Rows of small overlapping plates over the back, flanks and tail base, laced with glowing blue cords. When hit from behind a ripple runs down the rows.", use: "A ripple runs down the plates.", on: "Whole back + tail base (replaces the back quills)."},
      {name: "Riot Shield", sub: "folding back shield", build: plateRiot, pose: BRACE, ref: "Rainbow Six Siege — Montagne's shield that extends to cover him.",
        why: "Three shield plates folded flat on the lower back with blue light strips. When hit from behind they slide back and tilt down over the tail base like a wall, with a blue glow.", use: "Sections slide back and drop over the rear.", on: "Lower back (hides the 4 rear back quills)."},
      {name: "Spike Ridge", sub: "plates + spikes", build: plateSpikes, pose: BRACE, ref: "Kentrosaurus — a real stegosaur with plates at the front and long spikes down its back, tail and shoulders.",
        why: "Steel plates at the shoulders, bone-white spikes down the back and tail and a long spike out of each shoulder, all with blue glow at their roots. When hit they flare up.", use: "Spikes and plates flare up.", on: "Spine, tail base and shoulders (replaces the back quills)."},
    ]},
  {id: "siphon", short: "Siphon", name: "Blood Siphon", area: "health", focus: [0, 0.5, -2.8], oldText: "Throat Pump: a steel pump box on the neck with a glass chamber and a red glowing core, and a hose down to the throat. Nothing moves.",
    looks: [
      {name: "Fang Siphons", sub: "fangs + neck tanks", build: siphonFang, pose: {Jaw: [-14, 0, 0]}, ref: "Monster Hunter Rise: Sunbreak — Malzeno: it drains its prey's life (the Bloodblight).",
        why: "Two bone needle fangs under the jaw with tubes back to glass tanks on the neck sides. When it heals red drops run up the tubes and the tanks fill, with green glow caps.", use: "Red drops run up the tubes, tanks fill.", on: "Lower jaw + both sides of the neck."},
      {name: "Medic Tank", sub: "back tank + gauge", build: siphonMedic, pose: {}, ref: "Team Fortress 2 — the Medic's backpack tank, with a hose to his Medi Gun.",
        why: "A steel tank across the hump with a red level window, a gauge dial and a green cross on top, and a hose to the neck. When it heals red drops fly in from around it and the needle swings.", use: "Red drops fly in, level rises, needle swings.", on: "The hump (hides the 3 front back quills)."},
      {name: "Blood Vials", sub: "belt of vials", build: siphonVials, pose: {}, ref: "Bloodborne — the glass blood vials hunters carry on their belts.",
        why: "A belt round the waist with three glass vials hanging on each side, green caps. While it heals the vials fill red one after another.", use: "Vials fill red one by one.", on: "Round the waist."},
    ]},
  {id: "strobe", short: "Strobe", name: "Strobe Frill", area: "eng", focus: [0, 1, -3], oldText: "LED Frill: warm LED strips on each of the 11 frill blades and rim lights, plus a strip on the neck. Nothing moves; the frill flashes.",
    looks: [
      {name: "Flash Crest", sub: "bulbs on the frill", build: strobeCrest, pose: FLARE, ref: "Monster Hunter — Gypceros: it flashes the crest on its head to blind hunters.",
        why: "Mirror-steel backing on every frill blade and an orange bulb on each rim. When used the frill spreads, every bulb flashes white and a flash cone fires forward.", use: "Bulbs flash white, flash cone forward.", on: "The frill (all 11 blades)."},
      {name: "Stage Rig", sub: "moving spotlights", build: strobeStage, pose: FLARE, ref: "Concert moving-head lights — spotlights that pan and tilt, then strobe.",
        why: "Five small spotlights on yokes on the frill rim, sweeping around with faint beams. When used they all snap forward and strobe together.", use: "Lights snap forward and strobe.", on: "Frill rim (5 lights)."},
      {name: "Lighthouse Lamp", sub: "turning lens", build: strobeLighthouse, pose: FLARE, ref: "A lighthouse's turning lens lantern — plus the flashbang's white-out.",
        why: "A brass-ribbed glass lantern between the horns with a turning orange lens and a slow sweeping beam, and mirror-steel frill blades. When used the lens stops forward and flashes.", use: "Beam stops forward, flashes.", on: "Top of the head + frill."},
    ]},
  {id: "breaker", short: "Breaker", name: "Stun Breaker", area: "defense", focus: [0, 1, -1], oldText: "Back Capacitor: a capacitor block on the hump with glass cells and blue volt glow. Nothing moves; the break-free shows a blast.",
    looks: [
      {name: "Tesla Coils", sub: "two arc towers", build: breakTesla, pose: SHRUG, ref: "Command & Conquer: Red Alert — the Tesla Coil tower.",
        why: "Two copper-wound coils on the shoulders with brass rings and steel balls on top. When it breaks free blue arcs jump between them and down to the ground, and a blue ring pushes out.", use: "Arcs between the coils and to the ground, push ring.", on: "Both shoulders."},
      {name: "Reactive Bricks", sub: "blow-off armour", build: breakBricks, pose: SHRUG, ref: "Real tanks — explosive reactive armour: bricks that blow outward when hit.",
        why: "Rows of plated bricks on both flanks with blue seams. When it breaks free the bricks burst outward, tumble and click back, with a blue ring on the ground.", use: "Bricks burst out and click back, push ring.", on: "Both flanks (chest + waist)."},
      {name: "Shock Collar", sub: "capacitor ring", build: breakCollar, pose: SHRUG, ref: "Horizon Forbidden West — Shell-Walker: its Lightning Gun, a shock weapon built into its claw.",
        why: "A ring of six capacitor cans round the neck with blue glowing ends. When it breaks free arcs crackle round the ring and a blue shock bubble blasts out from the neck.", use: "Arcs round the collar, shock bubble blasts out.", on: "Base of the neck."},
    ]},
  {id: "caltrops", short: "Caltrops", name: "Razor Caltrops", area: "eng", focus: [0, -0.5, 2], oldText: "Tail Spreader: a hopper box with an orange glow and a spreader disc on the tail base. Nothing moves; the spikes appear behind.",
    looks: [
      {name: "Drop Chute", sub: "hopper + trap door", build: calChute, pose: {}, ref: "Spy Hunter — the spy car that drops oil slicks and smoke out of its rear.",
        why: "A studded hopper on the tail base with a hazard-striped lid, a trap door at the back and a slide. When used the door drops open and spike jacks tumble out onto the ground behind.", use: "Door opens, jacks tumble out behind.", on: "Tail base (same spot as now)."},
      {name: "Mine Launcher", sub: "hip mortars", build: calLauncher, pose: {}, ref: "Horizon Zero Dawn — Stalker: its Mine Launcher, which lobs mines onto the ground.",
        why: "A drum launcher on each hip with a short barrel aimed up and back. When used the drums turn and the barrels lob spike jacks in arcs onto the ground behind.", use: "Drums turn, jacks lobbed behind.", on: "Both hips."},
      {name: "Bladescale Tail", sub: "shed tail scales", build: calScales, pose: SHAKE, ref: "Monster Hunter — Seregios: it flings the blade-like scales off its body; they stick in the ground.",
        why: "Rows of steel blade-scales with orange edges along the top of the tail. When used the tail shakes and scales fling off behind it and stick in the ground.", use: "Tail shakes, scales fly off and stick in the ground.", on: "Top of the tail (first half)."},
    ]},
  {id: "goo", short: "Goo", name: "Goo Blob Shooter", area: "eng", focus: [0, 0.8, -1.5], oldText: "Hump Mortar: a short mortar tube on the hump with a lime glass tank and an orange glow. Nothing moves; the blob flies from the hump.",
    looks: [
      {name: "Spit Sacs", sub: "neck sacs + nozzle", build: gooSpit, pose: SPIT, ref: "Horizon Forbidden West — Bilegut: a frog-like machine that spits acid from the sacs on its body.",
        why: "Two see-through lime sacs in iron rings on the neck and a nozzle under the jaw. When used the head pulls back, the sacs squeeze and a goo blob arcs 30 studs ahead and splats.", use: "Sacs squeeze, blob spat from the mouth, splat.", on: "Both sides of the neck + under the jaw."},
      {name: "Ink Tank", sub: "back tank + nozzle", build: gooTank, pose: AIM, ref: "Splatoon — the ink tank on the back that feeds the ink gun through a hose.",
        why: "A glass tank of lime goo on the hump with a hose to a nozzle on the shoulder. When used a blob shoots out of the nozzle and the tank level drops.", use: "Blob from the shoulder nozzle, level drops.", on: "The hump + left shoulder (hides the 3 front back quills)."},
      {name: "Goo Catapult", sub: "spoon arm", build: gooPult, pose: {}, ref: "Plants vs. Zombies — the Cabbage-pult / Melon-pult, a spoon arm that lobs its ammo.",
        why: "A spring-loaded spoon arm on the lower back holding a lime blob. When used the arm whips forward over the head and lobs the blob ahead; it refills on the way back.", use: "Arm whips forward, blob lobbed, splat.", on: "Lower back (hides the 4 rear back quills)."},
    ]},
  {id: "hadren", short: "Adrenaline", name: "Adrenaline Injector", area: "health", focus: [0, 0.8, -1], oldText: "Back Tanks: glass tanks of green adrenaline on the hump with a glow. Nothing moves.",
    looks: [
      {name: "Stim Shot", sub: "big syringe", build: adrStim, pose: RUN, ref: "Apex Legends — Octane's Stim, a syringe he jabs for a burst of speed.",
        why: "A big syringe of green adrenaline stuck in the left shoulder. When used the plunger pushes down, the level drops and green veins light up along the flanks while it runs.", use: "Plunger pushes in, green veins light up.", on: "Left shoulder (the camera side)."},
      {name: "Nitro Bottles", sub: "hip bottles + flames", build: adrNitro, pose: RUN, ref: "Racing games' nitrous bottles (Need for Speed's NOS) — open the valve for a burst of speed.",
        why: "Two dark bottles with green bands on the hips, hoses to the legs and exhaust nozzles behind the haunches. When used the valves turn and green flames blast out behind.", use: "Valves open, green flames from the nozzles.", on: "Both hips + behind the haunches."},
      {name: "Zoid Core", sub: "glowing chest core", build: adrCore, pose: RUN, ref: "Zoids — every Zoid has a living core in its chest that powers it.",
        why: "A glass sphere in an iron cage on the chest with a beating green core and two pistons. When used it beats much faster, green rings pulse out and the veins light up.", use: "Core beats fast, rings pulse, veins glow.", on: "Front of the chest."},
    ]},
];
const OLD = {ironclaw: oldClaw, glider: oldGlider, quills: oldQuills, smoke: oldSmoke, plating: oldPlating, siphon: oldSiphon, strobe: oldStrobe, breaker: oldBreaker, caltrops: oldCaltrops, goo: oldGoo, hadren: oldAdren};
const LOADOUTS = [
  {name: "All A", sub: "every A look", why: "All eleven A looks at once, to check they fit together (in the game 4 are slotted at a time).", parts: PARTS.map(p => [p.id, p.looks[0].build]), rows: PARTS.map(p => [p.id, p.looks[0].name])},
  {name: "All B", sub: "every B look", why: "All eleven B looks at once.", parts: PARTS.map(p => [p.id, p.looks[1].build]), rows: PARTS.map(p => [p.id, p.looks[1].name])},
  {name: "All C", sub: "every C look", why: "All eleven C looks at once.", parts: PARTS.map(p => [p.id, p.looks[2].build]), rows: PARTS.map(p => [p.id, p.looks[2].name])},
];
pose({}); camGoal(); renderAll(); requestAnimationFrame(frame);
