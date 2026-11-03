// ---------- Fourth Cut mockup v0.1 animation core (built on the kit mockup v0.3: springs, solved key poses, planted feet,
// swept claw contact, hit-stop). The combo is Combo A (Reaper Sweeps) unchanged; the 4th tap after the finisher plays one of
// three spinning sweeps. Joint angles [p, y, r] as measured on this rig; root {fwd, up, yaw} (yaw in degrees, whole body).
const E = {
  lin: u => u, io: u => u * u * (3 - 2 * u), out: u => 1 - Math.pow(1 - u, 3), out5: u => 1 - Math.pow(1 - u, 5),
  in: u => u * u * u, in2: u => u * u, out2: u => 1 - (1 - u) * (1 - u),
  back: u => { const c = 1.9; return 1 + (c + 1) * Math.pow(u - 1, 3) + c * Math.pow(u - 1, 2); },
};
function lerpPose(a, b, u) {
  const o = {}; const ks = new Set([...Object.keys(a), ...Object.keys(b)]);
  for (const k of ks) {
    if (k === "root") { const ra = a.root || {}, rb = b.root || {}; o.root = {}; for (const c of ["fwd", "up", "yaw"]) o.root[c] = (ra[c] || 0) + ((rb[c] || 0) - (ra[c] || 0)) * u; continue; }
    const va = a[k] || [0, 0, 0], vb = b[k] || [0, 0, 0]; o[k] = [0, 1, 2].map(i => va[i] + (vb[i] - va[i]) * u);
  }
  return o;
}
function addPose(a, b, w) {
  const o = Object.assign({}, a);
  for (const k in b) {
    if (k === "root") continue;
    const va = a[k] || [0, 0, 0]; o[k] = [0, 1, 2].map(i => va[i] + b[k][i] * w);
  }
  return o;
}
function sample(keys, t) {
  if (t <= keys[0].t) return keys[0].pose;
  for (let i = 1; i < keys.length; i++) if (t <= keys[i].t) { const a = keys[i - 1], b = keys[i]; return lerpPose(a.pose, b.pose, (E[b.e || "io"])((t - a.t) / (b.t - a.t))); }
  return keys[keys.length - 1].pose;
}
const K = KEYS, SP = SPINPOSES;
const pick = (src, names) => { const o = {}; for (const n of names) if (src[n]) o[n] = src[n].slice(); return o; };
const ARMS = ["ArmR", "ElbowR", "WristR", "ArmL", "ElbowL", "WristL"];
const LOWER = ["LegL", "LegR", "KneeL", "KneeR", "AnkleL", "AnkleR"];
const mk = (...parts) => { const o = {}; for (const p of parts) for (const k in p) o[k] = k === "root" ? Object.assign({}, p[k]) : p[k].slice(); return o; };
const tailDrag = d => ({Tail1: [-4, d * 0.6, 0], Tail2: [0, d * 0.8, 0], Tail3: [0, d, 0], Tail4: [0, d * 1.1, 0], Tail5: [0, d * 1.2, 0]});
const BENT = {LegL: [18, 0, 0], LegR: [18, 0, 0], KneeL: [-30, 0, 0], KneeR: [-30, 0, 0], AnkleL: [10, 0, 0], AnkleR: [10, 0, 0]};
// combo A up to the finisher's impact (kit v0.3 timings)
const COMBO_KEYS = [
  {t: 0, pose: K.READY},
  {t: 0.22, pose: K.R_W, e: "io"}, {t: 0.29, pose: K.R_S, e: "in2"}, {t: 0.41, pose: K.R_F, e: "out"},
  {t: 0.6, pose: K.L_W, e: "io"}, {t: 0.67, pose: K.L_S, e: "in2"}, {t: 0.79, pose: K.L_F, e: "out"},
  {t: 1.13, pose: K.REAR, e: "io"}, {t: 1.25, pose: K.REAR2, e: "io"}, {t: 1.34, pose: K.CHOP, e: "in"},
];
const COMBO_HITS = [{a: 0.235, b: 0.36, side: "R", dmg: 9, only: 0}, {a: 0.615, b: 0.74, side: "L", dmg: 9, only: 0}, {a: 1.315, b: 1.45, side: "B", dmg: 20, big: true, only: 0}];
const COMBO_TRAILS = [{a: 0.2, b: 0.4, side: "R"}, {a: 0.58, b: 0.78, side: "L"}, {a: 1.24, b: 1.45, side: "B", hot: true}];
// ---- the three Fourth Cut styles (T = seconds after the 4th tap). Each: keys, the sweep window (hits every dino around,
// once each), trails, an optional ground impact, and the camera height it wants.
const STYLES = {
  A: {name: "Reaper Whirl", tag: "planted pivot spin, arms out flat", turns: 1,
    why: "From the finisher it coils left, then whips one full turn on the spot with both arms straight out at raptor-back height: the claws carve a flat circle all around it, the tail streaming behind. A small hop lets the feet swing round; it lands back in its ready crouch facing forward.",
    trade: "Quickest to read and quickest to come out (hits at about 0.25 s). Flat circle: good against raptors and pachys, it passes over very low targets.",
    build: () => {
      const COIL = mk(BENT, {RootJoint: [-10, 34, 0], Neck: [-10, -24, 0], Head: [0, -10, 0]}, pick(K.R_W, ["ArmR", "ElbowR", "WristR"]), pick(K.L_F, ["ArmL", "ElbowL", "WristL"]), tailDrag(18), {root: {yaw: 40}});
      const OUT = mk(BENT, {RootJoint: [-12, 0, 0], Neck: [-26, 0, 0], Head: [6, 0, 0], Jaw: [-18, 0, 0]}, pick(SP.S_SCREW, ARMS), tailDrag(26));
      return {
        keys: [
          {t: 0.12, pose: COIL, e: "out"},
          {t: 0.18, pose: mk(OUT, {root: {yaw: 10, up: 0.6}}), e: "in2"},
          {t: 0.34, pose: mk(OUT, {root: {yaw: -230, up: 1.6}}), e: "lin"},
          {t: 0.46, pose: mk(OUT, {root: {yaw: -345, up: 0.4}}), e: "out"},
          {t: 0.56, pose: mk(K.CHOP_SET, {root: {yaw: -360, fwd: 1}}), e: "out"},
          {t: 1.15, pose: mk(K.READY, {root: {yaw: -360}}), e: "io"},
        ],
        sweep: {a: 0.17, b: 0.47}, trails: [{a: 0.16, b: 0.5, side: "B", hot: true}], impact: null, ring: {at: 0.2, r: 22},
      };
    }},
  B: {name: "Rising Scythe", tag: "spiral hop, claws low to high", turns: 1,
    why: "It drops into a crouch with the claws swept low and out, then springs up into one rising turn: the claws spiral from the shins of anything around it up past their heads, ending reared up with both arms high. It comes down claws-first into the chop set with a dust ring.",
    trade: "The most dramatic (the whole sweep is a spiral, low and high). Slower (hits from about 0.3 s) and it leaves the ground, so it can be read and dodged.",
    build: () => {
      const LOW = mk(pick(K.J_CROUCH, ["RootJoint", "Neck", "Tail1"].concat(LOWER)), pick(SP.S_TORNADO, ARMS), {root: {yaw: 30}}, tailDrag(14));
      const MID = mk(BENT, {RootJoint: [0, 0, 0], Neck: [-10, 0, 0], Jaw: [-24, 0, 0]}, pick(SP.S_SCREW, ARMS), tailDrag(24));
      const HIGH = mk({LegL: [-6, 0, 0], LegR: [-6, 0, 0], KneeL: [-10, 0, 0], KneeR: [-10, 0, 0]}, {RootJoint: [18, 0, 0], Neck: [12, 0, 0], Head: [10, 0, 0], Jaw: [-32, 0, 0]}, pick(K.REAR2, ARMS), tailDrag(18));
      return {
        keys: [
          {t: 0.14, pose: LOW, e: "out"},
          {t: 0.24, pose: mk(LOW, {root: {yaw: 0, up: 1}}), e: "in2"},
          {t: 0.4, pose: mk(MID, {root: {yaw: -180, up: 4.5}}), e: "lin"},
          {t: 0.56, pose: mk(HIGH, {root: {yaw: -340, up: 5.5}}), e: "out2"},
          {t: 0.7, pose: mk(K.J_LAND, {root: {yaw: -360, up: 0}}), e: "in"},
          {t: 0.95, pose: mk(K.CHOP_SET, {root: {yaw: -360, fwd: 1}}), e: "out"},
          {t: 1.5, pose: mk(K.READY, {root: {yaw: -360}}), e: "io"},
        ],
        sweep: {a: 0.24, b: 0.58}, trails: [{a: 0.22, b: 0.6, side: "B", hot: true}], impact: 0.7, ring: null,
      };
    }},
  C: {name: "Ground Scythe", tag: "two low turns, claws near the ground", turns: 2,
    why: "It drops low over its knees with the arms out and angled down and spins twice fast, the claws skimming just above the ground and throwing up a ring of dust; the tail sweeps flat behind. It rises out of the spin into the chop set.",
    trade: "Two passes around it in half a second (the sweep looks like a buzzsaw on the ground). Low: it hits legs and bellies, good on everything, but it reads less 'big' than B.",
    build: () => {
      const DOWN = mk(pick(K.J_LAND, ["RootJoint", "Neck", "Head"].concat(LOWER)), pick(SP.S_TORNADO, ARMS), tailDrag(20), {Jaw: [-14, 0, 0]});
      return {
        keys: [
          {t: 0.1, pose: mk(DOWN, {root: {yaw: 25}}), e: "out"},
          {t: 0.16, pose: mk(DOWN, {root: {yaw: 0}}), e: "in2"},
          {t: 0.62, pose: mk(DOWN, {root: {yaw: -700}}), e: "lin"},
          {t: 0.72, pose: mk(K.CHOP_SET, {root: {yaw: -720, fwd: 1}}), e: "out"},
          {t: 1.25, pose: mk(K.READY, {root: {yaw: -720}}), e: "io"},
        ],
        sweep: {a: 0.15, b: 0.64}, trails: [{a: 0.14, b: 0.66, side: "B", hot: false}], impact: null, ring: {at: 0.2, r: 20}, dustSpin: [0.16, 0.62],
      };
    }},
};
const T4 = 1.48; // the 4th tap in the full run: right after the finisher lands (1.34) inside its recovery
function buildTrack(styleKey, kind) {
  const st = STYLES[styleKey], f = st.build();
  const off = kind === "full" ? T4 : 0.05;
  const keys = (kind === "full" ? COMBO_KEYS.slice() : [{t: 0, pose: K.CHOP_SET}]).concat(f.keys.map(k => ({t: k.t + off, pose: k.pose, e: k.e})));
  const hits = (kind === "full" ? COMBO_HITS.slice() : []).concat([{a: f.sweep.a + off, b: f.sweep.b + off, side: "B", dmg: 10, sweep: true}]);
  const trails = (kind === "full" ? COMBO_TRAILS.slice() : []).concat(f.trails.map(w => ({a: w.a + off, b: w.b + off, side: w.side, hot: w.hot})));
  return {keys, hits, trails, tremble: kind === "full" ? [1.13, 1.25] : null, impactAt: kind === "full" ? 1.34 : null,
    impact2: f.impact != null ? f.impact + off : null, ring: f.ring ? {at: f.ring.at + off, r: f.ring.r} : null,
    dustSpin: f.dustSpin ? [f.dustSpin[0] + off, f.dustSpin[1] + off] : null, t4: off, len: keys[keys.length - 1].t + 0.35, st};
}

// ---------- springs ----------
const SPR = (n) => /^(Arm|Elbow|Wrist)/.test(n) ? [38, 0.6] : n === "RootJoint" ? [30, 0.85] : /^(Leg|Knee|Ankle)/.test(n) ? [34, 0.9]
  : n === "Neck" ? [20, 0.6] : n === "Head" ? [16, 0.55] : n === "Jaw" ? [28, 0.45] : /^Tail(\d)/.test(n) ? [18 - 2.2 * (+n.slice(4)), 0.42] : [24, 0.8];
const springs = {};
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

// ---------- targets: one raptor in front (the combo's), two more behind-left / behind-right (the 4th cut hits all around) ----------
const rap2 = buildDino(RAPTOR, 2), rap3 = buildDino(RAPTOR, 2);
const TARGETS = [
  {d: rap, pos: new THREE.Vector3(0, 0, -19), yaw: Math.PI / 2},
  {d: rap2, pos: new THREE.Vector3(-17, 0, 9), yaw: Math.PI * 0.15},
  {d: rap3, pos: new THREE.Vector3(17, 0, 7), yaw: -Math.PI * 0.2},
].map(o => Object.assign(o, {flinch: 0, side: 0, flash: 0, push: 0, big: 0}));
function boxOf(r) {
  const box = new THREE.Box3(), c = new THREE.Vector3();
  for (const n of ["Torso", "Neck", "Tail1", "Tail2", "Head"]) for (const p of r.segs[n]) for (let i = 0; i < 8; i++) { c.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(p.mesh.matrix); box.expandByPoint(c); }
  box.expandByScalar(1.2); box.min.y = 0; // legs: the game's hitboxes reach the ground
  return box;
}
const prevPts = {};
function clawContact(side, box, tag) {
  let hitP = null; const ray = new THREE.Ray(), hit = new THREE.Vector3();
  for (const s of side === "B" ? ["L", "R"] : [side]) clawParts[s].forEach((cp, ci) => {
    [partPoint(theri, cp.d, 0, cp.d.size[1] / 2, 0), partPoint(theri, cp.d, 0, 0, 0), partPoint(theri, cp.b, 0, 0, 0)].forEach((pt, pi) => {
      const key = tag + s + ci + pi, q = prevPts[key]; prevPts[key] = pt.clone();
      if (hitP) return;
      if (box.containsPoint(pt)) { hitP = pt; return; }
      if (q) { const d = pt.clone().sub(q), L = d.length(); if (L > 1e-4) { ray.set(q, d.divideScalar(L)); if (ray.intersectBox(box, hit) && hit.distanceTo(q) <= L) hitP = hit.clone(); } }
    });
  });
  return hitP;
}

// ---------- state ----------
let camMode = "hero", slowMo = false, style = "A", runKind = "full";
let play = null, hitStop = 0, shake = 0, clockT = 0, idleT = 0, fovPunch = 0;
const stats = {contacts: []};
function start(kind) {
  runKind = kind || runKind;
  play = {track: buildTrack(style, runKind), t: 0, fired: {}};
  stats.contacts = [];
}
function idleLayer(t) {
  const b = Math.sin(t * 2.1), b2 = Math.sin(t * 2.1 + 1.2);
  return {RootJoint: [b * 1.2, b2 * 1.2, 0], Neck: [-b * 1.6, Math.sin(t * 0.7) * 5, 0], Head: [0, Math.sin(t * 0.9 + 1) * 4, 0], Jaw: [Math.max(0, Math.sin(t * 0.5)) * -3, 0, 0],
    ArmL: [b2 * 2, 0, b * 1.5], ArmR: [b2 * 2, 0, -b * 1.5], WristL: [Math.sin(t * 3.1) * 3, 0, 0], WristR: [Math.sin(t * 2.9 + 2) * 3, 0, 0],
    Tail1: [b * 1.2, Math.sin(t * 1.3) * 4, 0], Tail2: [0, Math.sin(t * 1.3 - .6) * 5, 0], Tail3: [0, Math.sin(t * 1.3 - 1.2) * 6, 0], Tail4: [0, Math.sin(t * 1.3 - 1.8) * 7, 0], Tail5: [0, Math.sin(t * 1.3 - 2.4) * 8, 0]};
}
function onHit(h, p, tg) {
  const big = !!h.big, sw = !!h.sweep;
  hitStop = big ? 0.15 : sw ? 0.06 : 0.08; shake = big ? 1.7 : sw ? 1.0 : 0.8; fovPunch = big ? 5 : sw ? 2.6 : 2.2;
  const dir = p.clone().sub(theri.pos).setY(0).normalize().add(new THREE.Vector3(0, 0.3, 0));
  flash(p, big ? 18 : sw ? 13 : 11); sparks(p, dir, big ? 30 : sw ? 20 : 16, big || sw);
  clawMarks(p.clone(), sw ? 0.5 : h.side === "R" ? 0.9 : h.side === "L" ? -0.9 : 0.05, big);
  numberPop(p.clone().add(new THREE.Vector3(0, 5, 0)), h.dmg, big);
  tg.flinch = 1; tg.side = sw ? 0 : h.side === "R" ? 1 : h.side === "L" ? -1 : 0; tg.flash = 0.12; tg.push = big ? 2.4 : sw ? 1.8 : 1.2; tg.big = big ? 1 : 0;
  stats.contacts.push({t: play ? Math.round(play.t * 100) / 100 : 0, target: TARGETS.indexOf(tg), dmg: h.dmg});
}
function groundAhead(dist) { return theri.pos.clone().add(new THREE.Vector3(-Math.sin(theri.yaw) * dist, 0, -Math.cos(theri.yaw) * dist)); }
function onImpact(g, big) {
  ring(g, big ? 24 : 18, 0xfff0c0, 0.55); ring(g, big ? 14 : 10, 0xffffff, 0.35); dust(g, big ? 22 : 16, 7, 11); debris(g, big ? 16 : 8); if (big) cracks(g, 8, 10);
  shake = Math.max(shake, big ? 1.9 : 1.3);
  const v = $("vig"); v.style.transition = "none"; v.style.opacity = big ? 0.5 : 0.3; requestAnimationFrame(() => { v.style.transition = "opacity .4s"; v.style.opacity = 0; });
}

// ---------- frame ----------
const footParts = theri.parts.filter(p => p.name.startsWith("Foot"));
function step(dt) {
  if (slowMo) dt *= 0.3;
  let mdt = dt;
  if (hitStop > 0) { hitStop -= dt; mdt = dt * 0.04; }
  idleT += mdt; clockT += dt;
  let target = idleLayer(idleT), trailOn = {L: false, R: false}, hot = false, rootFwd = 0, rootUp = 0, rootYaw = 0;
  if (play) {
    const tr = play.track;
    play.t = Math.min(play.t + mdt, tr.len);
    const mv = sample(tr.keys, play.t);
    target = addPose(mv, target, 1);
    if (tr.tremble && play.t > tr.tremble[0] && play.t < tr.tremble[1]) for (const n of ["ArmL", "ArmR", "WristL", "WristR"]) target[n] = target[n].map((v, i) => v + Math.sin(clockT * 70 + i * 2 + n.length) * 2.2);
    rootFwd = (mv.root && mv.root.fwd) || 0; rootUp = (mv.root && mv.root.up) || 0; rootYaw = (mv.root && mv.root.yaw) || 0;
    if (tr.impactAt && !play.fired.imp && play.t >= tr.impactAt) { play.fired.imp = true; onImpact(groundAhead(9), true); }
    if (tr.impact2 && !play.fired.imp2 && play.t >= tr.impact2) { play.fired.imp2 = true; onImpact(theri.pos.clone(), false); }
    if (tr.ring && !play.fired.ring && play.t >= tr.ring.at) { play.fired.ring = true; ring(theri.pos.clone().setY(0.4), tr.ring.r, 0xfff0c0, 0.5); }
    if (tr.dustSpin && play.t >= tr.dustSpin[0] && play.t <= tr.dustSpin[1] && Math.random() < mdt * 60) {
      const a = Math.random() * Math.PI * 2; dust(theri.pos.clone().add(new THREE.Vector3(Math.cos(a) * 14, 0, Math.sin(a) * 14)), 1, 2, 3);
    }
    for (const w of tr.trails) if (play.t >= w.a && play.t <= w.b) { if (w.side === "B") trailOn.L = trailOn.R = true; else trailOn[w.side] = true; hot = hot || !!w.hot; }
    if (play.t >= tr.len && window.__loop) start(runKind);
  }
  const P = springStep(target, mdt);
  for (let i = 0, n = Math.max(1, Math.ceil(mdt * 300)); i < n; i++) { const h = mdt / n; rootSpring.v += (400 * (rootFwd - rootSpring.x) - 2 * 0.9 * 20 * rootSpring.v) * h; rootSpring.x += rootSpring.v * h; }
  theri.yaw = rad(rootYaw);
  theri.pos.set(0, 0, -rootSpring.x);
  theri.up = 0; pose(theri, P);
  let minY = Infinity; const c = new THREE.Vector3();
  for (const p of footParts) for (let i = 0; i < 8; i++) { c.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(p.mesh.matrix); minY = Math.min(minY, c.y); }
  theri.up = -minY + rootUp; pose(theri, P);
  // targets
  for (const tg of TARGETS) {
    tg.flinch = Math.max(0, tg.flinch - dt * 2.6); tg.flash = Math.max(0, tg.flash - dt); tg.push *= Math.pow(0.03, dt);
    const f = E.out(tg.flinch), fb = f * (tg.big ? 1.6 : 1);
    const away = tg.pos.clone().setY(0).normalize();
    tg.d.yaw = tg.yaw; tg.d.pos.copy(tg.pos).addScaledVector(away, tg.push);
    pose(tg.d, {RootJoint: [10 * fb, 0, tg.side * 8 * f], Neck: [12 * fb, tg.side * -18 * f, 0], Head: [10 * f, 0, 0], Jaw: [-22 * f, 0, 0],
      ArmL: [-25 * f, 0, 0], ArmR: [-25 * f, 0, 0], Tail1: [-10 * fb, Math.sin(clockT * 1.3) * 4, 0], Tail2: [0, Math.sin(clockT * 1.3 - .7) * 5, 0], LegL: [-8 * fb, 0, 0], LegR: [-8 * fb, 0, 0], KneeL: [-10 * fb, 0, 0], KneeR: [-10 * fb, 0, 0]});
    tg.d.mats.forEach(m => m.emissive.setRGB(tg.flash > 0 ? 0.9 : 0, tg.flash > 0 ? 0.1 : 0, tg.flash > 0 ? 0.05 : 0));
  }
  if (play) {
    const tr = play.track;
    for (const h of tr.hits) if (play.t >= h.a && play.t <= h.b) {
      const list = h.only != null ? [TARGETS[h.only]] : TARGETS;
      for (const tg of list) {
        const key = "h" + h.a + "_" + TARGETS.indexOf(tg);
        const p = clawContact(h.side, boxOf(tg.d), key);
        if (!play.fired[key] && p) { play.fired[key] = true; onHit(h, p, tg); }
      }
    }
  }
  updateTrails(clockT, trailOn, hot);
  for (let i = fx.length - 1; i >= 0; i--) { const e = fx[i]; const fdt = dt * (hitStop > 0 ? 0.2 : 1); e.t += fdt; const u = Math.min(1, e.t / e.life); e.update(e.obj, u, fdt); if (u >= 1) { scene.remove(e.obj); fx.splice(i, 1); } }
  // camera: during the 4th cut it pulls up and back so all three raptors are in frame
  shake = Math.max(0, shake - dt * 4.2); fovPunch = Math.max(0, fovPunch - dt * 14);
  const four = play ? E.io(Math.min(1, Math.max(0, (play.t - play.track.t4 + 0.25) / 0.35))) : 0;
  const focusCombo = theri.pos.clone().lerp(rap.pos, 0.42).setY(12), focusFour = theri.pos.clone().setY(8);
  const focus = focusCombo.lerp(focusFour, four);
  let cp;
  if (camMode === "hero") cp = focus.clone().add(new THREE.Vector3(-45, 13, -22).lerp(new THREE.Vector3(-40, 44, -38), four));
  else if (camMode === "game") cp = theri.pos.clone().add(new THREE.Vector3(-14, 30, 44));
  else cp = focus.clone().add(new THREE.Vector3(0, 95, 1)); // top-down
  camPos.lerp(cp, 0.2); camLook.lerp(focus, 0.25);
  const sh = shake * shake * 1.1;
  cam.position.copy(camPos).add(new THREE.Vector3((Math.random() - .5) * sh, (Math.random() - .5) * sh, (Math.random() - .5) * sh));
  cam.lookAt(camLook);
  cam.fov = 38 + fovPunch + four * 4; cam.updateProjectionMatrix();
  sun.position.copy(focus).add(new THREE.Vector3(-30, 70, 30)); sun.target.position.copy(focus);
  renderer.render(scene, cam);
}
const camPos = new THREE.Vector3(-50, 20, -4), camLook = new THREE.Vector3(0, 12, -6);

// ---------- UI ----------
function showInfo() {
  const s = STYLES[style];
  $("info").innerHTML = `<h2>${style} · ${s.name}</h2><p>${s.why}</p><p class="muted"><b>Trade-off:</b> ${s.trade}</p>`;
  document.querySelectorAll("[data-style]").forEach(b => b.setAttribute("aria-pressed", b.dataset.style === style));
}
document.querySelectorAll("[data-style]").forEach(b => b.onclick = () => { style = b.dataset.style; showInfo(); start(runKind); });
$("runFull").onclick = () => start("full"); $("runFour").onclick = () => start("four");
$("slow").onclick = e => { slowMo = !slowMo; e.currentTarget.setAttribute("aria-pressed", slowMo); };
document.querySelectorAll("[data-cam]").forEach(b => b.onclick = () => { camMode = b.dataset.cam; document.querySelectorAll("[data-cam]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
function resize() { const w = cv.clientWidth, h = cv.clientHeight; renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); }
window.addEventListener("resize", resize);
let last = performance.now();
function loop(now) { const dt = Math.min(0.05, (now - last) / 1000); last = now; if (!window.__manual) step(dt); requestAnimationFrame(loop); }
resize(); document.querySelector('[data-cam="hero"]').setAttribute("aria-pressed", true); showInfo();
window.__loop = true; start("full");
requestAnimationFrame(loop);
window.__ready = true;
window.__setup = (k, kind, cm) => { window.__manual = true; window.__loop = false; camMode = cm || "hero"; fx.splice(0).forEach(e => scene.remove(e.obj)); for (const q in trails) trails[q].pts = []; style = k; play = null; for (let i = 0; i < 40; i++) step(1 / 30); start(kind); };
window.__step = dt => step(dt);
window.__len = () => play ? play.track.len : 0;
window.__stats = () => stats;
window.__tips = () => { const out = {}; for (const s of ["L", "R"]) out[s] = partPoint(theri, clawParts[s][1].d, 0, clawParts[s][1].d.size[1] / 2, 0).toArray().map(v => Math.round(v * 10) / 10); return out; };
