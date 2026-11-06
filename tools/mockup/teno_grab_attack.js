// teno_grab_attack.js v0.1 (Mecha Dino Arena) — Teno options mockup (Kepu 2026-11-06 03:29 "the teno tail grab when there's a
// raptor attached needs a proper animation" + "the teno basic attack looks stupid when I spam it. Give it an actual vfx";
// ~03:40 picks "Mockup all three first" for both). Engine = tools/mockup/teno_moves_anim.js up to its first variant (stage,
// rig with the 7 picked looks, tail IK, FX kit, raptor dummy, flight / landed), prepended by build_teno_grab_attack.py.
// Tab 1 · Tail Grab on a latched raptor: Now (v495: the latch is broken at the press, the raptor leaps off, then snaps to
//   the jaws in 0.05 s at the catch) vs A Back Pluck / B Buck and Snatch / C Swat Off. Server timings for a target behind
//   (TenoMovesServer grabOverTop): catch +0.40 s, throw +1.00 s, flight 0.6 s, peak 8 studs. Latch spot as BotServer.latchOn
//   places it: on the struck part's surface, belly to it (on the back = over the hips; on the flank = the +X barrel side).
// Tab 2 · Basic attack (scratch spam): 6 taps at the 0.5 s gap on a raptor dummy (held in place). Now (TenoPose SCRATCH_UP /
//   DOWN on ArmR, 3 thin streaks at the claw, "8" pop) vs A rake marks + alternating arms / B scratch-scratch-BITE /
//   C swipe arc + impact + hit-stop. Numbers: hit at +0.17 s, reach 5.5 x scale from the claw, 90° cone, 8 damage.
// Units: the model's (game studs / 2). Front = -Z; the camera side = +X (the model's "...L" parts).
const GA_VERSION = "0.1";
$("ver").textContent = "v" + GA_VERSION;

// helpers that live after the engine cut in teno_moves_anim.js (copied, same values)
const plus = (...ps) => { const o = {}; for (const q of ps) for (const k in q) { const a = o[k] || [0, 0, 0]; o[k] = [a[0] + q[k][0], a[1] + q[k][1], a[2] + q[k][2]]; } return o; };
const REAR_HI = {RootJoint: [52, 0, 0], LegL: [-50, 0, 0], LegR: [-50, 0, 0], KneeL: [-26, 0, 0], KneeR: [-26, 0, 0], ArmL: [85, 0, 0], ArmR: [80, 0, 0], Neck: [6, 0, 0], Head: [-10, 0, 0], Jaw: [-28, 0, 0], Tail1: [-36, 0, 0], Tail2: [6, 0, 0], Tail5: [-12, 0, 0]};

// ---------- extra FX ----------
const lbl2 = (t, c, w) => label(t, c, w);
const NUM2 = {latched: lbl2("LATCHED", "#ffd34d", 384), leaps: lbl2("LEAPS OFF", "#ff6b6b", 448), tele: lbl2("TELEPORTS IN", "#ff6b6b", 512),
  pluck: lbl2("PLUCKED!", "#ffffff", 384), swat: lbl2("SWAT!", "#ffffff", 320), dmg: lbl2("8", "#ff6b6b"), dmg2: lbl2("8", "#ff6b6b"),
  bite: lbl2("BITE!", "#ffffff", 320)};
const WHITE_ADD = o => ADD(0xffffff, o);
const STREAK3 = [0, 1, 2].map(() => mk(BOX, new THREE.MeshBasicMaterial({color: 0xfff0b0, transparent: true, opacity: 1, depthWrite: false})));
const RAKE = [0, 1, 2].map(() => mk(BOX, ADD(0xfff4d6, 1)));
const RAKE_CORE = [0, 1, 2].map(() => mk(BOX, new THREE.MeshBasicMaterial({color: 0x8b0000, transparent: true, opacity: 1, depthWrite: false})));
const FAN = [0, 1, 2, 3, 4].map(() => { const m = mk(new THREE.RingGeometry(0.92, 1, 40, 1, 0, Math.PI * 0.55), ADD(0xfff0b0, 0.9)); m.material.side = THREE.DoubleSide; return m; });
const ARC = (() => { const m = mk(new THREE.RingGeometry(0.62, 1, 64, 1, 0, Math.PI), ADD(0xfff4d6, 0.85)); m.material.side = THREE.DoubleSide; return m; })();
const ARC_EDGE = (() => { const m = mk(new THREE.RingGeometry(0.95, 1, 64, 1, 0, Math.PI), ADD(0xffffff, 1)); m.material.side = THREE.DoubleSide; return m; })();
const SPARKS = []; for (let i = 0; i < 14; i++) SPARKS.push(mk(BOX, ADD(i % 2 ? 0xffd34d : 0xffffff, 1)));
const CHUNKS = []; for (let i = 0; i < 10; i++) CHUNKS.push(mk(BOX, new THREE.MeshLambertMaterial({color: i % 3 ? 0x9b2c22 : 0xd9b48a})));
const FLASHBALL = mk(BALL, ADD(0xffffff, 0.9));
function sparks(p, k, n, spd) { SPARKS.forEach((m, i) => { if (i >= n || k <= 0 || k >= 1) { m.visible = false; return; } const a = i * 2.39, e = ((i * 37) % 11) / 11 - 0.3;
  const d = new THREE.Vector3(Math.cos(a), e + 0.4, Math.sin(a)).normalize(); const q = p.clone().addScaledVector(d, spd * easeOut(k)); q.y -= 2 * k * k;
  setSeg(m, q, q.clone().addScaledVector(d, -0.6 * (1 - k)), 0.09); m.material.opacity = 1 - k; }); }
function chunks(p, k) { CHUNKS.forEach((m, i) => { if (k <= 0 || k >= 1) { m.visible = false; return; } const a = i * 2.1, d = new THREE.Vector3(Math.cos(a), 0.9 + (i % 3) * 0.3, Math.sin(a) * 0.6 + 0.6);
  m.visible = true; m.position.copy(p).addScaledVector(d, 3.2 * k); m.position.y -= 5 * k * k; m.rotation.set(k * 9 + i, k * 7, 0); m.scale.setScalar(0.32 * (1 - k * 0.5)); }); }
function flashBall(p, k, r) { const m = FLASHBALL; m.visible = k > 0 && k < 1; if (!m.visible) return; m.position.copy(p); m.scale.setScalar(0.4 + (r || 2) * easeOut(k)); m.material.opacity = 0.9 * (1 - k); }

// ---------- latch spots (BotServer.latchOn: on the struck part's surface, belly to it) ----------
pose({});
function boxWorld(name) { rig.updateMatrixWorld(true); const b = dino.byName[name], s = b.size, mn = new THREE.Vector3(1e9, 1e9, 1e9), mx = mn.clone().multiplyScalar(-1);
  for (const x of [-1, 1]) for (const y of [-1, 1]) for (const z of [-1, 1]) { const p = new THREE.Vector3(x * s[0] / 2, y * s[1] / 2, z * s[2] / 2).applyMatrix4(b.mesh.matrix).applyMatrix4(rig.matrixWorld); mn.min(p); mx.max(p); }
  return {mn, mx, c: mn.clone().add(mx).multiplyScalar(0.5)}; }
// a part-local point for a world point at rest (so the latched raptor rides the body when the teno moves)
function localOf(name, w) { rig.updateMatrixWorld(true); const b = dino.byName[name]; return w.clone().applyMatrix4(new THREE.Matrix4().copy(rig.matrixWorld).invert()).applyMatrix4(new THREE.Matrix4().copy(b.mesh.matrix).invert()).toArray(); }
const HIPBOX = boxWorld("Torso_dorsalHips"), BARREL = boxWorld("Torso_barrel");
const LATCH = {
  back: {part: "Torso_dorsalHips", world: new THREE.Vector3(HIPBOX.c.x, HIPBOX.mx.y + 2.3, HIPBOX.c.z + 0.6), spin: [-0.45, 0, 0] /* feet on the back plates, body above them */, away: new THREE.Vector3(0, 0, 1)},
  flank: {part: "Torso_barrel", world: new THREE.Vector3(BARREL.mx.x + 0.95, BARREL.c.y + 0.3, BARREL.c.z), spin: [0, 0, -Math.PI / 2], away: new THREE.Vector3(1, 0, 0)},
};
for (const k in LATCH) LATCH[k].local = localOf(LATCH[k].part, LATCH[k].world);
const latchAt = (A, s) => fkPoint(A, LATCH[s].part, LATCH[s].local);
function latched(tt, A, s, extra) { // the raptor clinging on: scrabbling legs, biting (neck), riding the body
  const L = LATCH[s]; raptorPose(Object.assign({held: latchAt(A, s), spin: L.spin, yaw: 0, run: tt * 16, runAmt: 0.55, flash: (tt % 0.6) < 0.05}, extra || {})); }

// ---------- shared grab tail: coil -> strike -> SNAP -> peel / lift -> slam -> fling (TenoMovesServer behind timings) ----------
const CURL = s => ({Tail1: [-30, s === "flank" ? 12 : 0, 0], Tail2: [-32, s === "flank" ? 12 : 0, 0], Tail3: [-32, 0, 0], Tail4: [-28, 0, 0], Tail5: [-22, 0, 0]});
const G_PRESS = PRESS, G_CATCH = PRESS + 0.40, G_THROW = PRESS + 1.00, G_FLIGHT = 0.6, G_PEAK = 4; // 8 studs
const CARRY = new THREE.Vector3(0.4, 10.5, 1), SLAM_TO = new THREE.Vector3(0.6, 5, -9), G_LAND = new THREE.Vector3(-1, 0, -15);
// after the catch (the clamp holds the raptor at `from` at G_CATCH): lift over the back, slam forward, fling (same as A · Scorpion Strike, behind)
function liftAndFling(tt, A0, body, from, spin0) {
  const tC = G_CATCH + 0.2, tLf = G_THROW - 0.15, tT = G_THROW, tL = tT + G_FLIGHT;
  let A, held = null, spin = null;
  if (tt < tC) { A = ik(Object.assign({}, A0, body), from, 6, true); jaw = 1 - easeOut(seg(tt, G_CATCH, G_CATCH + 0.08)); held = clampOf(A); spin = spin0.slice();
    burst(held, seg(tt, G_CATCH, G_CATCH + 0.35), 0xffffff, 2.5); }
  else if (tt < tLf) { const u = ease(seg(tt, tC, tLf)); A = ik(mix(Object.assign({}, A0, body), Object.assign({}, A0, BRACE2), u), bez(from, from.clone().lerp(CARRY, 0.5).add(new THREE.Vector3(0, 3, 0)), CARRY, u), 6); jaw = 0; held = clampOf(A);
    spin = [spin0[0] * (1 - u) + u * 0.8, spin0[1] * (1 - u), spin0[2] * (1 - u)]; }
  else if (tt < tT) { const u = easeIn(seg(tt, tLf, tT)); A = ik(Object.assign({}, A0, BRACE2, {RootJoint: [-10, 0, 0], Neck: [-10, 0, 0]}), CARRY.clone().lerp(SLAM_TO, u), 6); jaw = 0; held = clampOf(A); spin = [0.8 + u * 1.6, 0, 0]; st.rel = held.clone(); st.relSpin = spin[0]; }
  else { const u = ease(seg(tt, tT, tT + 0.7)); A = mix(ik(Object.assign({}, A0, BRACE2), new THREE.Vector3(0.4, 8, 9), 3), A0, u);
    jaw = tt < tT + 0.25 ? 1 : 0.3 + 0.7 * (1 - seg(tt, tT + 0.25, tT + 0.9));
    if (tt < tL) { const f = flight(st.rel || clampOf(A), G_LAND, G_FLIGHT, G_PEAK, seg(tt, tT, tL), 0.6); held = f.held; spin = [st.relSpin + f.spin[0], 0, 0]; }
    else landed(G_LAND, tt, tL, Math.PI); }
  return {A, held, spin};
}
const GV = {};
const GPH_TAIL = [[G_CATCH, G_CATCH + 0.2, "SNAP · the pincer clamps it"], [G_CATCH + 0.2, G_THROW - 0.15, "Lift · over your back"], [G_THROW - 0.15, G_THROW, "Slam · swung down in front of you"],
  [G_THROW, G_THROW + G_FLIGHT, "Flung out in front of you (8-stud peak, 0.6 s)"], [G_THROW + G_FLIGHT, 3.6, "Lands · 8 damage, stunned · the tail recoils"]];

// ===== Now (v495): the latch breaks at the press, the raptor leaps off, then snaps into the jaws at the catch =====
GV.now = {name: "Now", sub: "as the game plays it (v495)", len: 3.6,
  ref: "Today's Scorpion Strike (picked A, live since v465) used on a raptor that is latched on: BotServer's normal leap-off runs first, then TenoBotMotion pulls it to the jaws in 0.05 s.",
  timing: () => "press → leap-off at once · catch 0.40 s (snap 0.05 s) · throw 1.00 s · flight 0.6 s",
  phases: s => [[0, G_PRESS, `A raptor latched on your ${s}`], [G_PRESS, G_PRESS + 0.1, "Press · the latch breaks (ShakeOffReason \"grabbed\"): it LEAPS OFF (away ×30, up 35)"],
    [G_PRESS + 0.1, G_CATCH - 0.05, "The tail strikes at the spot it was on… which is now empty"], [G_CATCH - 0.05, G_CATCH, "It TELEPORTS from the ground into the jaws (0.05 s)"], ...GPH_TAIL],
  update(tt) {
    const A0 = IDLE(tt), s = side, L = LATCH[s];
    const G0 = latchAt(A0, s), coil = G0.clone().add(new THREE.Vector3(s === "flank" ? 2.5 : 0.3, 5.5, 4));
    let A = A0, held = null, spin = null;
    if (tt < G_PRESS) { jaw = 0.3; latched(tt, A0, s); pop(NUM2.latched, G0, 0.35, 0); }
    else if (tt < G_CATCH) {
      const u = ease(seg(tt, G_PRESS, G_CATCH - 0.15)); if (tt - G_PRESS < 0.03) sol = null; A = ik(Object.assign(mix(A0, REAR_BACK, u * 0.6), sol ? {} : CURL(s)), u < 1 ? lerpV(clampOf(A0), coil, u) : bez(coil, coil.clone().add(new THREE.Vector3(0, 1, -2)), G0, seg(tt, G_CATCH - 0.15, G_CATCH)), 6); jaw = 0.3 + 0.7 * u;
      // the leap-off: v = away x 15 + up 17.5 (units/s), gravity 98.1 (units/s²); stands where it lands
      const k = tt - G_PRESS, v = L.away.clone().multiplyScalar(15), tGround = (17.5 + Math.sqrt(17.5 * 17.5 + 2 * 98.1 * (G0.y - GRIP_Y))) / 98.1;
      const kk = Math.min(k, tGround), p = G0.clone().addScaledVector(v, kk); p.y += 17.5 * kk - 49.05 * kk * kk;
      st.leap = p.clone();
      if (tt < G_CATCH - 0.05) { raptorPose({held: p, spin: [L.spin[0] * (1 - clamp01(k / 0.25)), 0, L.spin[2] * (1 - clamp01(k / 0.25))], yaw: s === "flank" ? -Math.PI / 2 : Math.PI, run: tt * 12, runAmt: k > tGround ? 0.3 : 1});
        pop(NUM2.leaps, p, clamp01(k / 0.5)); if (k > tGround) puffs(p.clone().setY(0), clamp01((k - tGround) / 0.5), 2, 8); }
      else { const tip = clampOf(A), q = lerpV(st.leap, tip, easeIn(seg(tt, G_CATCH - 0.05, G_CATCH))); raptorPose({held: q, spin: [0, 0, 0.6], yaw: Math.PI, run: tt * 14});
        speedLines(q, tip.clone().sub(st.leap).normalize(), 1); pop(NUM2.tele, q, 0.4, 0); setSeg(MISSLINE, st.leap, tip, 0.1); }
      st.from = G0.clone();
    } else { const r = liftAndFling(tt, A0, REAR_BACK, st.from || G0, [0, 0, 0.6]); A = r.A; held = r.held; spin = r.spin; if (tt - G_CATCH < 0.4) pop(NUM.snap, clampOf(A), seg(tt, G_CATCH, G_CATCH + 0.6)); }
    pose(A);
    if (held) raptorPose({held, spin, yaw: Math.PI, run: tt * 14, runAmt: 1});
  }};

// ===== A · Back Pluck: the raptor stays latched; the tail curls over to it, clamps it where it clings, peels it off =====
GV.A = {name: "A · Back Pluck", sub: "the tail plucks it off where it clings", len: 3.6, rec: true,
  ref: "A scorpion picking prey off its own back + Monster Hunter's Rathalos tail-flick at a mounted hunter: the tail comes to the rider, not the rider to the tail.",
  timing: () => "press → catch 0.40 s on the latch spot · peel 0.6 s · throw 1.00 s · flight 0.6 s",
  phases: s => [[0, G_PRESS, `A raptor latched on your ${s}`], [G_PRESS, G_PRESS + 0.25, "Wind-up · you hunch, the tail coils up over your back, pincer wide · it keeps clinging"],
    [G_PRESS + 0.25, G_CATCH, "STRIKE · the tail stabs down onto it, right where it clings"], [G_CATCH, G_CATCH + 0.2, "SNAP · clamped on your back"], [G_CATCH + 0.2, G_THROW - 0.15, "PLUCKED · peeled off and lifted, legs kicking"],
    ...GPH_TAIL.slice(2)],
  update(tt) {
    const A0 = IDLE(tt), s = side, hunch = {RootJoint: [-6, 0, 0], Neck: [-10, 0, 0], Head: [-6, 0, 0], LegL: [12, 0, 0], LegR: [12, 0, 0], KneeL: [-14, 0, 0], KneeR: [-14, 0, 0]};
    const G0 = latchAt(A0, s), coil = G0.clone().add(new THREE.Vector3(s === "flank" ? 3 : 0.3, 6, 4.5));
    let A = A0, held = null, spin = null;
    if (tt < G_PRESS) { jaw = 0.3; latched(tt, A0, s); pop(NUM2.latched, G0, 0.35, 0); }
    else if (tt < G_PRESS + 0.25) { const u = ease(seg(tt, G_PRESS, G_PRESS + 0.25)); if (tt - G_PRESS < 0.03) sol = null; A = ik(Object.assign(mix(A0, hunch, u), sol ? {} : CURL(s)), lerpV(clampOf(A0), coil, u), 6); jaw = 0.3 + 0.7 * u; latched(tt, A, s); }
    else if (tt < G_CATCH) { const u = easeIn(seg(tt, G_PRESS + 0.25, G_CATCH)), G = latchAt(Object.assign({}, A0, hunch), s);
      A = ik(Object.assign({}, A0, hunch), bez(coil, coil.clone().add(new THREE.Vector3(0, 1.5, -1.5)), G, u), 6, u > 0.7); jaw = 1; latched(tt, A, s);
      speedLines(clampOf(A), G.clone().sub(coil).normalize(), u); st.from = G.clone(); }
    else { const r = liftAndFling(tt, A0, hunch, st.from || G0, LATCH[s].spin); A = r.A; held = r.held; spin = r.spin;
      if (tt < G_CATCH + 0.2) { pop(NUM.snap, held, seg(tt, G_CATCH, G_CATCH + 0.6)); puffs(held.clone().add(new THREE.Vector3(0, -1, 0)), seg(tt, G_CATCH, G_CATCH + 0.4), 1.2, 6); }
      else if (tt < G_THROW) pop(NUM2.pluck, held, seg(tt, G_CATCH + 0.2, G_THROW + 0.2)); }
    pose(A);
    if (held) raptorPose({held, spin, yaw: Math.PI, run: tt * 16, runAmt: 1, flash: tt - G_CATCH < 0.07 && tt >= G_CATCH});
  }};

// ===== B · Buck and Snatch: you rear and buck, it's thrown up off your back, the tail snatches it out of the air =====
GV.B = {name: "B · Buck and Snatch", sub: "buck it off, catch it in the air", len: 3.6,
  ref: "A bucking bronco (rodeo) + Shadow of the Colossus shaking a climber off; the tail catch is Zoids Death Stinger's.",
  timing: () => "press → rear 0.15 s · buck 0.25 s (it pops up) · caught in the air 0.40 s · throw 1.00 s",
  phases: s => [[0, G_PRESS, `A raptor latched on your ${s}`], [G_PRESS, G_PRESS + 0.15, "Wind-up · you rear up, front hooves high · the tail coils"],
    [G_PRESS + 0.15, G_PRESS + 0.25, "BUCK · you slam your front down: it's thrown up off your back"], [G_PRESS + 0.25, G_CATCH, "It flies up · the tail rises to meet it"],
    [G_CATCH, G_CATCH + 0.2, "SNAP · caught in mid-air"], ...GPH_TAIL.slice(1)],
  update(tt) {
    const A0 = IDLE(tt), s = side, rear = mix({}, REAR_HI, 0.55), buck = {RootJoint: [-14, 0, 0], LegL: [16, 0, 0], LegR: [16, 0, 0], KneeL: [-14, 0, 0], KneeR: [-14, 0, 0], ArmL: [-14, 0, 0], ArmR: [-14, 0, 0], Neck: [-14, 0, 0], Head: [-8, 0, 0]};
    const meet = new THREE.Vector3(0.4, 11.5, 2.5);
    let A = A0, held = null, spin = null;
    const tR = G_PRESS + 0.15, tB = G_PRESS + 0.25;
    if (tt < G_PRESS) { jaw = 0.3; latched(tt, A0, s); pop(NUM2.latched, latchAt(A0, s), 0.35, 0); }
    else if (tt < tR) { const u = ease(seg(tt, G_PRESS, tR)); if (tt - G_PRESS < 0.03) sol = null; const B = Object.assign(mix(A0, Object.assign({}, A0, rear), u), sol ? {} : CURL(s)); A = ik(B, lerpV(clampOf(A0), meet.clone().add(new THREE.Vector3(0, -2, 4)), u), 6); jaw = 0.3 + 0.5 * u; latched(tt, A, s); }
    else if (tt < tB) { const u = easeIn(seg(tt, tR, tB)); const B = mix(Object.assign({}, A0, rear), Object.assign({}, A0, buck), u); A = ik(B, meet.clone().add(new THREE.Vector3(0, -2, 4)), 6); jaw = 0.8; latched(tt, A, s);
      st.pop0 = latchAt(A, s); if (u > 0.85) { burst(st.pop0, seg(tt, tB - 0.03, tB + 0.3), 0xffd34d, 2.5); } }
    else if (tt < G_CATCH) { const u = seg(tt, tB, G_CATCH), p0 = st.pop0 || latchAt(A0, s);
      A = ik(mix(Object.assign({}, A0, buck), A0, ease(u)), lerpV(meet.clone().add(new THREE.Vector3(0, -2, 4)), meet, ease(u)), 6, u > 0.6); jaw = 1;
      const p = bez(p0, p0.clone().lerp(meet, 0.5).add(new THREE.Vector3(0, 5, 0)), meet, easeOut(u));
      raptorPose({held: p, spin: [LATCH[s].spin[0] * (1 - u) + u * 1.2, 0, LATCH[s].spin[2] * (1 - u)], yaw: Math.PI, run: tt * 18, runAmt: 1}); st.from = meet.clone();
      puffs(p0.clone().setY(0), u, 3, 8); }
    else { const r = liftAndFling(tt, A0, {}, st.from || meet, [1.2, 0, 0]); A = r.A; held = r.held; spin = r.spin; if (tt < G_CATCH + 0.3) pop(NUM.snap, held, seg(tt, G_CATCH, G_CATCH + 0.6)); }
    pose(A);
    if (held) raptorPose({held, spin, yaw: Math.PI, run: tt * 14, runAmt: 1, flash: tt - G_CATCH < 0.07 && tt >= G_CATCH});
  }};

// ===== C · Swat Off: no catch — the tail sweeps along your body and slaps it off with a toss + stun =====
GV.C = {name: "C · Swat Off", sub: "no catch: the tail slaps it off", len: 3.0,
  ref: "A horse's tail swatting a fly + Monster Hunter tail sweeps (Rathalos / Nargacuga) knocking a mounted hunter off.",
  timing: () => "press → wind-up 0.32 s · swat 0.40 s · tossed 0.6 s (no throw, no carry)",
  phases: s => [[0, G_PRESS, `A raptor latched on your ${s}`], [G_PRESS, G_PRESS + 0.32, "Wind-up · the tail cocks to the far side, low"],
    [G_PRESS + 0.32, G_CATCH + 0.05, "SWAT · it sweeps across your " + s + " and slaps the raptor"], [G_CATCH + 0.05, G_CATCH + 0.65, "Tossed off to the side · spinning"],
    [G_CATCH + 0.65, 3.0, "Lands · 8 damage, stunned · the tail settles"]],
  update(tt) {
    const A0 = IDLE(tt), s = side, G0 = latchAt(A0, s);
    const cock = s === "flank" ? new THREE.Vector3(-7, 6, 7) : new THREE.Vector3(-6, 8.5, 6), thru = s === "flank" ? new THREE.Vector3(8, 5, -1) : new THREE.Vector3(7, 7, -1);
    const tW = G_PRESS + 0.32, tHit = G_CATCH, tE = G_CATCH + 0.08, land = s === "flank" ? new THREE.Vector3(13, 0, 1) : new THREE.Vector3(12, 0, -2), tL = tHit + 0.6;
    const twist = {RootJoint: [0, -10, 0], Neck: [0, 14, 0], LegL: [6, 0, 0], LegR: [6, 0, 0]};
    let A = A0;
    if (tt < G_PRESS) { jaw = 0.3; latched(tt, A0, s); pop(NUM2.latched, G0, 0.35, 0); }
    else if (tt < tW) { const u = ease(seg(tt, G_PRESS, tW)); if (tt - G_PRESS < 0.03) sol = null; A = ik(mix(A0, Object.assign({}, A0, twist), u), lerpV(clampOf(A0), cock, u), 6); jaw = 0.3; latched(tt, A, s); }
    else if (tt < tE) { const u = seg(tt, tW, tE), G = latchAt(A0, s), via = G.clone().add(new THREE.Vector3(0, 0.6, 0.4)).multiplyScalar(2).sub(cock.clone().add(thru).multiplyScalar(0.5)); A = ik(mix(Object.assign({}, A0, twist), A0, u), bez(cock, via, thru, u), 6); jaw = 0.3;
      speedLines(clampOf(A), thru.clone().sub(cock).normalize(), u);
      if (tt < tHit) latched(tt, A, s); st.swat0 = G.clone(); }
    else { const u = ease(seg(tt, tE, tE + 0.9)); A = ik(mix(A0, A0, u), lerpV(thru, clampOf(A0), u), 3); jaw = 0.3; }
    if (tt >= tHit) {
      const k = tt - tHit, p0 = st.swat0 || G0;
      if (tt < tL) { const f = flight(p0, land, 0.6, 3, seg(tt, tHit, tL), 1.2); raptorPose({held: f.held, spin: [0, 0, -f.spin[0] + LATCH[s].spin[2]], yaw: s === "flank" ? -Math.PI / 2 : Math.PI / 2, run: tt * 14, runAmt: 1, flash: k < 0.07});
        burst(p0, clamp01(k / 0.35), 0xffffff, 3); flashBall(p0, clamp01(k / 0.2), 1.6); pop(NUM2.swat, p0, clamp01(k / 0.7)); sparks(p0, clamp01(k / 0.35), 10, 2.5); }
      else landed(land, tt, tL, s === "flank" ? -Math.PI / 2 : Math.PI / 2);
    }
    pose(A);
  }};
const GNOTES = {
  now: `<h2 style="margin-top:6px">What's wrong with it now</h2><ul><li>The press breaks the latch first (ShakeOffReason "grabbed"), so BotServer's normal leap-off runs: the raptor jumps ~6 studs <b>away</b> from you.</li><li>The tail strikes at the empty spot it was on; at the catch the server anchors it wherever it landed and TenoBotMotion pulls it into the jaws in 0.05 s: a <b>teleport</b>.</li><li>On the flank the "front or behind" pick is a coin flip (its Z ≈ yours).</li></ul>`,
  A: `<h2 style="margin-top:6px">Why it fixes it</h2><ul><li>The raptor never leaves the spot it clings to until the pincer has it: no leap-off, no teleport.</li><li>Same catch / throw / flight times as now (catch 0.40 s, throw 1.00 s), so the server timings, damage and stun don't change.</li><li>Reads instantly: "the tail came round and plucked it off my back".</li></ul><p class="note">Game change: BotServer endLatch skips the leap-off for reason "grabbed" (keeps it anchored on its latch spot, one guarded branch) · TenoPose aims the strike at the latch spot (TenoGrabTargetRef's live position) · TenoBotMotion holds it there until the catch.</p>`,
  B: `<h2 style="margin-top:6px">Why it fixes it</h2><ul><li>The raptor leaving your back is caused by you (the buck), and you see every frame of its flight into the jaws.</li><li>Big, readable wind-up: rear, buck, catch.</li><li>Cost: your front lifts for 0.15 s (you can't steer during the buck), and the catch point moves (mid-air above your back).</li></ul><p class="note">Game change: a buck pose in TenoPose · TenoBotMotion draws the pop arc (latch spot → jaws over 0.15 s) instead of the 0.05 s snap · BotServer skips the leap-off for "grabbed".</p>`,
  C: `<h2 style="margin-top:6px">Why it fixes it</h2><ul><li>Simplest: no catch, so nothing can teleport. The tail meets the raptor where it clings and it flies off.</li><li>Fastest to finish (all over by ~1 s).</li><li>Cost: for a latched raptor the move becomes a swat (toss + stun) instead of a grab-and-fling, so it plays differently from a free-standing grab.</li></ul><p class="note">Game change: TenoMovesServer branches on PounceLatched at the press (swat path: 8 damage + the slam's toss + stun) · a swat sweep in TenoPose.</p>`,
};

// ============================== Tab 2 · Basic attack (scratch spam) ==============================
const SCRATCH_UP = {ArmR: [95, 0, 30], Neck: [4, -10, 0], Head: [6, 0, 0], RootJoint: [8, 0, 0], LegL: [-8, 0, 0], LegR: [-8, 0, 0], Jaw: [-14, 0, 0]};
const SCRATCH_DOWN = {ArmR: [-20, 0, -10], Neck: [-6, 6, 0], Head: [-6, 0, 0], RootJoint: [-4, 0, 0], LegL: [4, 0, 0], LegR: [4, 0, 0]};
const mirror = P => { const o = {}; for (const k in P) { const v = P[k], nk = /^(Arm|Leg|Knee|Ankle)[LR]$/.test(k) ? k.slice(0, -1) + (k.endsWith("R") ? "L" : "R") : k; o[nk] = [v[0], -v[1], -v[2]]; } return o; };
const SCRATCH_UP_L = mirror(SCRATCH_UP), SCRATCH_DOWN_L = mirror(SCRATCH_DOWN);
const BITE_DIP = {RootJoint: [-6, 0, 0], Neck: [-30, 0, 0], Head: [-12, 0, 0], Jaw: [-44, 0, 0], LegL: [10, 0, 0], LegR: [10, 0, 0], KneeL: [-10, 0, 0], KneeR: [-10, 0, 0]};
const BITE_SHUT = {RootJoint: [-10, 0, 0], Neck: [-38, 0, 0], Head: [-16, 0, 0], Jaw: [2, 0, 0], LegL: [14, 0, 0], LegR: [14, 0, 0], KneeL: [-12, 0, 0], KneeR: [-12, 0, 0]};
const TAPS = 6, GAP = 0.5, HIT = 0.17, T1 = 0.12, T2 = 0.10, T3 = 0.25;
function scratchPose(s, up, down) { if (s < 0) return {}; if (s < T1) return mix({}, up, ease(s / T1)); if (s < T1 + T2) return mix(up, down, easeIn((s - T1) / T2)); return mix(down, {}, ease(clamp01((s - T1 - T2) / T3))); }
function bitePose(s) { if (s < 0) return {}; if (s < 0.12) return mix({}, BITE_DIP, ease(s / 0.12)); if (s < 0.2) return mix(BITE_DIP, BITE_SHUT, easeIn((s - 0.12) / 0.08)); return mix(BITE_SHUT, {}, ease(clamp01((s - 0.2) / 0.27))); }
pose({});
const CLAW_R0 = partNow("ArmR_hoof2"), HEAD0 = partNow("Head_beak");
const DUMMY = new THREE.Vector3(2.6, 0, CLAW_R0.z - 3.7); // front-right: 5.0 units from the right claw (reach 5.5), 41° off the facing (cone 45°), clear of the head
const DUMMY_YAW = Math.atan2(-(CLAW_R0.x - DUMMY.x), -(CLAW_R0.z - DUMMY.z)); // facing the teno
const dummyTorso = () => grabPoint(DUMMY).add(new THREE.Vector3(0, -0.15, 0));
function faceDir() { const d = cam.position.clone().sub(dummyTorso()); d.y = 0; return d.normalize(); } // toward the camera, flat
function onFace(off) { return dummyTorso().addScaledVector(faceDir(), 0.75).add(new THREE.Vector3(0, off || 0, 0)); }
function tapIdx(tt) { const k = Math.floor((tt - PRESS) / GAP); return k >= 0 && k < TAPS ? k : -1; }
function dummy(tt, hits, tintK) { // hits: [{t, side}] -> knock-back recoil + flash
  let push = 0, fl = false, tint = null;
  for (const h of hits) { const k = tt - h.t; if (k >= 0 && k < 0.35) { push = Math.max(push, Math.sin(clamp01(k / 0.35) * Math.PI) * 0.55); if (k < 0.04) fl = true; if (tintK && k < tintK) tint = 0xff8f80; } }
  raptorPose({pos: DUMMY.clone().add(new THREE.Vector3(Math.sin(DUMMY_YAW) * push, 0, Math.cos(DUMMY_YAW) * push)), yaw: DUMMY_YAW, run: tt * 3, runAmt: 0.12, flash: fl, color: tint || undefined});
}
function popDmg(tt, hits, label) { const h = hits.filter(x => tt >= x.t && tt < x.t + 1).pop(); if (h) pop(label || NUM2.dmg, dummyTorso().add(new THREE.Vector3(0.6 * (hits.indexOf(h) % 2 ? 1 : -1), 0.6, 0)), clamp01((tt - h.t) / 0.9)); }
const SV = {};
const tapPhases = (what) => { const o = [[0, PRESS, "A raptor dummy in front of you (held in place: the game shoves it 12 studs per hit)"]];
  for (let i = 0; i < TAPS; i++) o.push([PRESS + i * GAP, PRESS + (i + 1) * GAP, `Tap ${i + 1} · ${what(i)}`]); o.push([PRESS + TAPS * GAP, 3.9, "Stop · back to idle"]); return o; };
const hitsOf = (fn) => { const o = []; for (let i = 0; i < TAPS; i++) o.push({t: PRESS + i * GAP + (fn ? fn(i) : HIT), i}); return o; };

SV.now = {name: "Now", sub: "as the game plays it (v495)", len: 3.9,
  ref: "TenoPose 1.x scratch (SCRATCH_UP → SCRATCH_DOWN on the right front leg) + TenoFX scratchFX (3 thin neon streaks at your own claw, 0.3 s) + the \"8\" pop.",
  timing: () => "tap every 0.5 s · up 0.12 + down 0.10 + back 0.25 s · hit at +0.17 s · same right leg every time",
  phases: () => tapPhases(() => "right leg chops · thin streaks at your claw"),
  update(tt) {
    const k = tapIdx(tt), s = k < 0 ? -1 : tt - PRESS - k * GAP, A0 = IDLE(tt);
    const A = plus(A0, scratchPose(s, SCRATCH_UP, SCRATCH_DOWN)); pose(A);
    const hits = hitsOf(); dummy(tt, hits); popDmg(tt, hits);
    if (s >= HIT && s < HIT + 0.36) { const claw = fkPoint(A, "ArmR_hoof2", [0, 0, 0]), fwd = new THREE.Vector3(0, 0, -1);
      STREAK3.forEach((m, i) => { const kk = s - HIT - i * 0.03; if (kk < 0 || kk > 0.3) return; const at = claw.clone().addScaledVector(fwd, 1).add(new THREE.Vector3(0, (1 + (i - 1) * 0.55) * 0.5, 0));
        m.visible = true; m.position.copy(at); m.rotation.set(-0.6, (i - 1) * 0.1, 0); m.scale.set(0.125, 0.125, 3); m.material.opacity = 1 - kk / 0.3; }); }
  }};

// A · rake marks on the target + alternating front legs
function rake(tt, h, side) { const k = tt - h.t; if (k < 0 || k > 0.38) return; const dir = faceDir(), c = onFace(0.1), right = new THREE.Vector3().crossVectors(UP, dir).normalize(), grow = clamp01(k / 0.06), fade = 1 - clamp01((k - 0.12) / 0.26);
  const place = (m, i, out, w, L) => { m.visible = true; m.position.copy(c).addScaledVector(right, (i - 1) * 0.42).addScaledVector(dir, out).add(new THREE.Vector3(0, (i - 1) * 0.06 * side, 0)); m.lookAt(m.position.clone().add(dir)); m.rotateZ(side * 0.75); m.scale.set(w, L * grow, 0.1); m.material.opacity = fade; };
  RAKE.forEach((m, i) => place(m, i, 0, 0.34, 3.0)); RAKE_CORE.forEach((m, i) => place(m, i, 0.08, 0.16, 2.7)); }
SV.A = {name: "A · Rake marks + both legs", sub: "left / right alternate, claw marks on the target", len: 3.9, rec: true,
  ref: "Monster Hunter / Dark Souls claw-hit decals + this game's own SlashFX (3 thick claw bars across the target, a 0.25 s flash): the hit shows on the victim, not on you.",
  timing: () => "tap every 0.5 s · legs alternate R, L, R… · hit at +0.17 s: 3 thick claw marks across the raptor + 0.25 s flash",
  phases: () => tapPhases(i => (i % 2 ? "left" : "right") + " leg rakes · 3 claw marks on it + flash"),
  update(tt) {
    const k = tapIdx(tt), s = k < 0 ? -1 : tt - PRESS - k * GAP, left = k % 2 === 1, A0 = IDLE(tt);
    const A = plus(A0, scratchPose(s, left ? SCRATCH_UP_L : SCRATCH_UP, left ? SCRATCH_DOWN_L : SCRATCH_DOWN)); pose(A);
    const hits = hitsOf(); dummy(tt, hits, 0.25); popDmg(tt, hits);
    for (const h of hits) rake(tt, h, h.i % 2 ? -1 : 1);
    if (s >= HIT && s < HIT + 0.2) burst(onFace(0.1), (s - HIT) / 0.2, 0xffffff, 1.4);
  }};

// B · scratch, scratch, BITE
const isBite = i => i % 3 === 2;
SV.B = {name: "B · Scratch-scratch-BITE", sub: "every 3rd tap is a head-dip bite", len: 3.9,
  ref: "Fighting-game 3-hit strings (Street Fighter target combos) + Monster Hunter's Tigrex claw-claw-bite: the 3rd tap changes shape so spam has a rhythm.",
  timing: () => "tap every 0.5 s · R, L, BITE, R, L, BITE · swipes: a fan of 5 curved streaks · bite (+0.20 s): flash + chunks · 8 each (bite number = your call)",
  phases: () => tapPhases(i => isBite(i) ? "BITE · head dips, jaws snap, flash + chunks" : (i % 3 ? "left" : "right") + " swipe · fan of 5 streaks"),
  update(tt) {
    const k = tapIdx(tt), s = k < 0 ? -1 : tt - PRESS - k * GAP, A0 = IDLE(tt);
    const part = k < 0 ? {} : isBite(k) ? bitePose(s) : scratchPose(s, k % 3 ? SCRATCH_UP_L : SCRATCH_UP, k % 3 ? SCRATCH_DOWN_L : SCRATCH_DOWN);
    const A = plus(A0, part); pose(A);
    const hits = hitsOf(i => isBite(i) ? 0.20 : HIT); dummy(tt, hits, 0.12);
    const h = hits.filter(x => tt >= x.t && tt < x.t + 1).pop(); if (h) pop(isBite(h.i) ? NUM2.bite : NUM2.dmg, dummyTorso().add(new THREE.Vector3(isBite(h.i) ? 0 : 0.6 * (h.i % 2 ? 1 : -1), isBite(h.i) ? 1.2 : 0.6, 0)), clamp01((tt - h.t) / 0.9));
    if (k >= 0) { const hk = s - (isBite(k) ? 0.2 : HIT);
      if (isBite(k)) { const p = onFace(0.6); flashBall(p, clamp01(hk / 0.18), 1.8); chunks(p, clamp01(hk / 0.5)); burst(p, clamp01(hk / 0.3), 0xffffff, 2); }
      else if (hk >= -0.06 && hk < 0.22) { const left = k % 3 === 1, claw = fkPoint(A, left ? "ArmL_hoof2" : "ArmR_hoof2", [0, 0, 0]);
        FAN.forEach((m, i) => { const kk = hk + 0.06 - i * 0.012; if (kk < 0 || kk > 0.28) return; m.visible = true; m.position.copy(claw).add(new THREE.Vector3((i - 2) * 0.22, 1.2, -1.2));
          m.rotation.set(0, Math.PI / 2, -0.4 + (i - 2) * 0.08); m.scale.setScalar(1.8 + i * 0.12); m.material.opacity = 0.9 * (1 - kk / 0.28); }); } }
  }};

// C · big swipe arc + sparks / dust + hit-stop
const STOP = 0.06;
SV.C = {name: "C · Swipe arc + impact", sub: "a crescent along the claw, sparks + dust, hit-stop", len: 3.9,
  ref: "Hollow Knight / Monster Hunter Rise slash arcs + hit-stop (a 60 ms freeze on contact) and Street Fighter hit sparks: weight comes from the pause, not the size.",
  timing: () => "tap every 0.5 s (right leg) · arc 0.15 s along the claw path · hit at +0.17 s: sparks + dust burst · 0.06 s hit-stop",
  phases: () => tapPhases(() => "right leg swipe · crescent arc · sparks + dust · tiny freeze"),
  update(tt) {
    const k = tapIdx(tt), raw = k < 0 ? -1 : tt - PRESS - k * GAP, A0 = IDLE(tt);
    const s = raw < HIT ? raw : raw < HIT + STOP ? HIT : raw - STOP; // hit-stop: the pose holds for 0.06 s at contact
    const A = plus(A0, scratchPose(s, SCRATCH_UP, SCRATCH_DOWN)); pose(A);
    const hits = hitsOf(); dummy(tt, hits, 0.1); popDmg(tt, hits);
    if (raw >= 0.1 && raw < 0.34) { const sh = fkPoint(A0, "ArmR_upper", [0, 0, 0]), u = clamp01((raw - 0.1) / 0.15), fade = 1 - clamp01((raw - 0.25) / 0.09);
      for (const m of [ARC, ARC_EDGE]) { m.visible = true; m.position.copy(sh).add(new THREE.Vector3(-0.4, -0.6, 0)); m.rotation.set(0, Math.PI / 2, 0); m.scale.setScalar(4.6); m.material.opacity = (m === ARC ? 0.55 : 0.95) * fade;
        m.geometry.setDrawRange(0, Math.floor(m.geometry.index.count * Math.max(0.05, u) / 6) * 6); } }
    if (raw >= HIT && raw < HIT + 0.45) { const p = onFace(0.2), kk = (raw - HIT);
      sparks(p, clamp01(kk / 0.3), 14, 2.2); flashBall(p, clamp01(kk / 0.12), 1.2); puffs(DUMMY.clone(), clamp01(kk / 0.45), 1.6, 8); }
    st.shake = raw >= HIT && raw < HIT + 0.12 ? 1 - (raw - HIT) / 0.12 : 0;
  }};
const SNOTES = {
  now: `<h2 style="margin-top:6px">What's wrong with it now</h2><ul><li>The same right-leg chop restarts every 0.5 s: spammed, it reads as one leg pumping.</li><li>The streaks are hair-thin (0.25 studs) and appear at your own claw, not on the raptor.</li><li>A hit shows nothing on the target but the number: no flash, no marks.</li></ul>`,
  A: `<h2 style="margin-top:6px">Why it fixes it</h2><ul><li>Alternating legs turns spam into a rhythm (left, right, left…), like a real flurry.</li><li>Every hit lands ON the raptor: three thick claw marks across it + a white-then-red flash, so you know each tap connected.</li><li>Cheapest: reuses SlashFX's claw-bar look; the pose is the current one, mirrored.</li></ul><p class="note">Game change: TenoPose mirrors SCRATCH_UP / DOWN to ArmL on odd taps (TenoScratchCount) · TenoAttackServer's claw point follows the leg · TenoFX draws the rake on the hit target (TenoScratchHit) instead of streaks at the claw.</p>`,
  B: `<h2 style="margin-top:6px">Why it fixes it</h2><ul><li>Spam becomes a 3-hit string with a payoff: the bite is the big, readable hit.</li><li>Swipes get a fan of curved streaks so their path is visible.</li><li>Cost: a new bite pose + bite hit rules (reach from the beak, not the claw), and the bite's damage needs your call.</li></ul><p class="note">Game change: TenoAttackServer counts taps (3rd = bite: beak reach, its own hit time 0.20 s) · TenoPose bite keys · TenoFX bite flash + chunks (BiteFX's look).</p>`,
  C: `<h2 style="margin-top:6px">Why it fixes it</h2><ul><li>The crescent shows the whole swing path at a glance; sparks + dust say "contact".</li><li>The 0.06 s hit-stop gives each tap weight (the pose freezes on contact).</li><li>Cost: still one leg, so spam keeps the same pumping rhythm; the hit-stop on your own dino only (other players see it without).</li></ul><p class="note">Game change: TenoFX arc mesh + sparks / dust (TheriFX cut-flash pattern) · TenoPose holds SCRATCH for 0.06 s on a local hit.</p>`,
};

// ---------- tabs + UI ----------
const VM2 = {grab: GV, scratch: SV};
const MOVES2 = [
  {id: "grab", name: "Tail Grab on a latched raptor", area: "attack", sides: [["back", "On its back"], ["flank", "On its flank"]], focus: new THREE.Vector3(0, 6.5, 0.5), dist: 40, notes: GNOTES,
    nums: "Unchanged numbers in every version: 8 damage · stun 1 s · catch 0.40 s / throw 1.00 s (target behind) · flight 0.6 s, peak 8 studs · recharge 16 s. Only what the raptor and the tail do changes."},
  {id: "scratch", name: "Basic attack (scratch spam)", area: "attack", focus: new THREE.Vector3(1.0, 3.6, -5.2), dist: 30, notes: SNOTES,
    nums: "Unchanged numbers: tap gap 0.5 s · hit at +0.17 s · reach 5.5 × scale (11 studs) from the claw · 90° cone · 8 damage · shove 6 × scale (the dummy is held still so the spam stays in frame)."},
];
let cur2 = 0, playing2 = true, speed2 = 1, view2 = "side", tt2 = 0; // grab opens on the side camera, scratch on 3/4
side = "back"; variant = "now";
const M2 = () => MOVES2[cur2], VV2 = () => VM2[M2().id][variant];
function renderAll2() {
  const VS = VM2[M2().id];
  $("moves").innerHTML = MOVES2.map((m, i) => `<button class="tab" data-i="${i}" aria-pressed="${i === cur2}">${m.name}<small style="color:${AREA[m.area][1]}">Now + 3 options</small></button>`).join("");
  $("varRow").innerHTML = '<span class="lbl">Version</span>' + ["now", "A", "B", "C"].map(k => `<button class="var" data-var="${k}" aria-pressed="${k === variant}">${VS[k].name}${VS[k].rec ? ' <span class="rec">· recommended</span>' : ""}<small>${VS[k].sub}</small></button>`).join("");
  const sb = $("sideRow"); sb.style.display = M2().sides ? "" : "none"; if (!M2().sides) sb.innerHTML = "";
  if (M2().sides) sb.innerHTML = '<span class="lbl">Raptor latched</span>' + M2().sides.map(([k, n]) => `<button class="btn" data-side="${k}" aria-pressed="${k === side}">${n}</button>`).join("");
  const v = VV2(), ph = v.phases(side);
  $("phases").innerHTML = ph.map(p => `<button class="ph" data-t="${p[0]}" aria-current="false"><i>${p[0].toFixed(2)}–${p[1].toFixed(2)} s</i>${p[2]}</button>`).join("");
  const rows = ["now", "A", "B", "C"].map(k => `<tr><th>${VS[k].name}</th><td>${VS[k].timing(side)}</td></tr>`).join("");
  const AR = AREA[M2().area];
  $("info").innerHTML = `<div class="kind" style="color:${AR[1]}">${M2().name} · ${v.name}${M2().sides ? " · latched on its " + side : ""}</div><h2>What you see, in order</h2><ul>${ph.slice(1).map(p => `<li>${p[2]}</li>`).join("")}</ul><p class="note"><b>Borrowed from:</b> ${v.ref}</p><table class="cmp">${rows}</table><p class="note">${M2().nums}</p>`;
  $("part").innerHTML = `<div class="kind" style="color:${AR[1]}">${variant === "now" ? "Today" : v.name}${v.rec ? " · recommended" : ""}</div>${M2().notes[variant]}`;
}
$("moves").addEventListener("click", e => { const b = e.target.closest("[data-i]"); if (!b) return; cur2 = +b.dataset.i; variant = "now"; tt2 = 0; reset(); for (const k in st) delete st[k]; view2 = cur2 ? "three" : "side"; syncView2(); renderAll2(); });
$("varRow").addEventListener("click", e => { const b = e.target.closest("[data-var]"); if (!b) return; variant = b.dataset.var; tt2 = 0; reset(); for (const k in st) delete st[k]; renderAll2(); });
$("sideRow").addEventListener("click", e => { const b = e.target.closest("[data-side]"); if (!b) return; side = b.dataset.side; tt2 = 0; reset(); for (const k in st) delete st[k]; renderAll2(); });
$("phases").addEventListener("click", e => { const b = e.target.closest("[data-t]"); if (!b) return; tt2 = +b.dataset.t + 0.06; playing2 = false; syncPlay2(); });
$("play").onclick = () => { playing2 = !playing2; syncPlay2(); };
function syncPlay2() { $("play").textContent = playing2 ? "Pause" : "Play"; $("play").setAttribute("aria-pressed", playing2); }
document.querySelectorAll("[data-speed]").forEach(b => b.onclick = () => { speed2 = +b.dataset.speed; document.querySelectorAll("[data-speed]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
function syncView2() { document.querySelectorAll("[data-view]").forEach(x => x.setAttribute("aria-pressed", x.dataset.view === view2)); }
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => { view2 = b.dataset.view; syncView2(); });
syncView2();
$("scrub").addEventListener("input", e => { tt2 = +e.target.value / 1000 * VV2().len; playing2 = false; syncPlay2(); sol = null; });
window.__ga = {set(mv, v, s, time, camv) { cur2 = MOVES2.findIndex(m => m.id === mv); variant = v; if (s) side = s; tt2 = time; playing2 = false; if (camv) view2 = camv; syncView2(); reset(); for (const k in st) delete st[k]; renderAll2(); syncPlay2(); }, st, get miss() { return ikMiss; }};
renderAll2();

// ---------- loop ----------
let last2 = performance.now(), camP2 = new THREE.Vector3(40, 16, 30), camL2 = new THREE.Vector3(0, 4, 0), lastTT2 = -1;
function frame2(now) {
  const dt = Math.min(0.05, (now - last2) / 1000); last2 = now; t += dt;
  const v = VV2();
  if (playing2) { tt2 += dt * speed2; if (tt2 > v.len) { tt2 = 0; reset(); } }
  if (tt2 < lastTT2 - 1e-6) { sol = null; for (const k in st) delete st[k]; }
  // scrubbing / stepping: replay the move from the start so order-dependent scratch values (st.from, st.rel) exist
  if (!playing2 && Math.abs(tt2 - lastTT2) > 0.05) { sol = null; for (const k in st) delete st[k]; for (let x = 0; x < tt2; x += 1 / 60) { fxOff(); v.update(x); } }
  lastTT2 = tt2;
  fxOff(); raptor.visible = true; raptor2.visible = raptor3.visible = false; use = 0; headOff = null; rig.rotation.set(0, 0, 0); rig.position.set(0, 0, 0);
  for (const k in LU) lookU(k, 0); jaw = 0.3; st.shake = 0;
  v.update(tt2);
  updateEquip();
  $("scrub").value = Math.round(tt2 / v.len * 1000);
  $("clock").textContent = `${tt2.toFixed(2)} s${speed2 !== 1 ? " · 0.3×" : ""}`;
  const ph = v.phases(side).find(p => tt2 >= p[0] && tt2 < p[1]);
  $("cap").textContent = ph ? ph[2] : "…";
  document.querySelectorAll(".ph").forEach(b => b.setAttribute("aria-current", ph && +b.dataset.t === ph[0]));
  const MM = M2(), f = MM.focus.clone();
  let gp, gl;
  if (view2 === "game") { gp = new THREE.Vector3(13, 15.3, 34); gl = gp.clone().add(new THREE.Vector3(-0.05, -0.12, -1)); }
  else if (view2 === "top") { gp = new THREE.Vector3(0, 80, f.z + 0.01); gl = new THREE.Vector3(0, 0, f.z); }
  else if (view2 === "side") { gp = f.clone().add(new THREE.Vector3(MM.dist, 4, 0)); gl = f; }
  else { gp = f.clone().add(MM.id === "scratch" ? new THREE.Vector3(0.82, 0.5, -0.3).multiplyScalar(MM.dist) : new THREE.Vector3(0.86, 0.36, 0.36).multiplyScalar(MM.dist)); gl = f; }
  const fovWant = view2 === "game" ? 70 : 34;
  if (cam.fov !== fovWant) { cam.fov = fovWant; cam.updateProjectionMatrix(); }
  const kk = playing2 ? 1 - Math.pow(0.001, dt) : 1;
  camP2.lerp(gp, kk); camL2.lerp(gl, kk);
  cam.position.copy(camP2); cam.lookAt(camL2);
  if (st.shake) cam.position.add(new THREE.Vector3(Math.sin(t * 90), Math.cos(t * 77), 0).multiplyScalar(0.12 * st.shake));
  resize(); renderer.render(scene, cam);
  requestAnimationFrame(frame2);
}
requestAnimationFrame(frame2);
