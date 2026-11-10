// dilovfx_tracks.js v0.1 (Mecha Dino Arena) — the 7 Dilo part tracks re-cut for the effect families (dilovfx_fx.js), the Mobility options,
// and the page player. Same poses / timings as tools/mockup/dilo_parts_looks.js v0.1 with the game's current numbers where they changed
// (DiloMovesServer 1.10: mortar wind-up 0.275 s, flight 0.38 s; SkillTree 1.76: mortar cloud 36 studs wide, Spring Jets 65 studs at 200
// studs/s, instant on the press). The parts are the looks in the game (DiloPartsServer 1.0): Twin Hood Repeaters, Chest Launcher, Hood
// Speakers, Frill Barbs, Back Pump, Tail Booster, Venom Reactor.
const VFX_VERSION = "0.1";
const GAMELOOK = {gatling: "C", mortar: "C", hiss: "A", spine: "C", pump: "A", jets: "C", over: "A"};

// ===================================================================================================================================
// part tracks; X = the effect kit
// ===================================================================================================================================
const VT = {};
VT.gatling = S => { const X = KITS[S]; place(R0, -7, -36); place(R1, 9, -42);
  const T0 = 0.6, FIRE = T0 + 0.4, END = FIRE + 1.0; const ms = mk("gatling.C"); const mz = i => partPoint(ms[i % 2]);
  const keys = idleIntro([K(T0 + 0.35, BRACE, "io"), K(END - 0.05, BRACE), K(END + 0.45, READY, "io")], T0);
  const ev = [{t: T0, f: () => { X.charge(() => mz(0), FIRE - T0, 0.7); X.charge(() => mz(1), FIRE - T0, 0.7); }}];
  for (let i = 0; i < 8; i++) ev.push({t: FIRE + i * 0.125, f: () => { const R = i % 2 ? R1 : R0, from = mz(i), to = rapChest(R); const dir = to.clone().sub(from).normalize();
    X.muzzle(from, dir, 1.2); MS.recoil = 1; shake = Math.max(shake, 0.22);
    X.shot({kind: "dart", from, to: () => rapChest(R), T: from.distanceTo(to) / 135, H: 0.2, size: 1.6, onHit: p => { X.impact(p, 1.1); hitR(R, p, 3); venomOn(R, Math.min(8, (R.venom ? R.venom.rate : 0) + 1), 3); }}); }});
  ev.push({t: END, f: () => { X.vent(() => mz(0), 1.3, 0.8); X.vent(() => mz(1), 1.3, 0.8); }});
  return {frame: [V3(0, 0, 2), V3(0, 0, -44)], keys, ev, frill: [[T0 + 0.1, END + 0.2]], len: 3.4,
    update(t, dt) { const want = t < T0 ? 0 : t < T0 + 0.35 ? 32 * (t - T0) / 0.35 : t < END ? 32 : Math.max(0, 32 * (1 - (t - END) / 0.7)); MS.spinV = want; MS.spin += want * dt; MS.recoil = Math.max(0, MS.recoil - dt * 9); },
    extra(target) { if (MS.recoil > 0) { const j = MS.recoil * 3 * Math.sin(clockT * 70); target.Neck[0] += j; target.Head[0] -= j * 0.5; } },
    phases: [[0, T0, "Slotted: the Twin Hood Repeaters at rest"], [T0, FIRE, "Wind-up 0.4 s: braces, the hood flares, the barrels spin up and charge"], [FIRE, END, "8 auto-aimed darts in 1 s, left / right, each adds venom"], [END, END + 0.9, "Recovery: the barrels spin down and vent"], [END + 0.9, 3.4, "The venom stacks tick"]]};
};
VT.mortar = S => { const X = KITS[S]; const C = V3(0, 0, -50), RAD = 18; place(R0, -5, -52); place(R1, 7, -46);
  const T0 = 0.6, F = T0 + 0.3, FLY = 0.42, LAND = F + FLY; const tube = () => partPoint(mk("mortar.C")[0]);
  const keys = idleIntro([K(T0 + 0.25, A_WIND, "io"), K(F + 0.02, addPose(A_WIND, {RootJoint: [6, 0, 0], root: {fwd: -1.2}}, 1), "out5"), K(F + 0.5, A_WIND, "io"), K(F + 1.0, READY, "io")], T0);
  const ev = [{t: T0, f: () => { X.target(C, RAD, LAND - T0 + 0.05); X.charge(tube, F - T0, 1.3); }},
    {t: F, f: () => { const from = tube(); const dir = C.clone().sub(from).setY(0).normalize().add(V3(0, 1.1, 0)).normalize(); X.muzzle(from, dir, 2); MS.recoil = 1; MS.cup = 0; shake = Math.max(shake, 0.55); fovPunch = 1.6;
      X.shot({kind: "shell", from, to: C.clone().setY(1), T: FLY, H: 9, size: 1.5, onHit: () => { shake = Math.max(shake, 1.0); hitStop = 0.06; fovPunch = 2.2; X.cloud(C, RAD, 4.4);
        for (const R of [R0, R1]) { R.flinch = 1; R.flash = 0.12; R.flashCol = [0.35, 0.95, 0.15]; venomOn(R, 2, 5, "cough"); } textTag(C.clone().setY(17), "POISON CLOUD · 5 s", "#b8ff70", 2.2); }}); }},
    {t: F + 0.35, f: () => X.vent(tube, 1.4, 1.2)}];
  return {frame: [V3(0, 0, 4), V3(0, 0, -64)], keys, ev, len: 6.2,
    update(t, dt) { MS.elev = t < T0 ? 0 : t < T0 + 0.25 ? E.io((t - T0) / 0.25) : t < F + 0.7 ? 1 : Math.max(0, 1 - (t - F - 0.7) / 0.5); MS.recoil = Math.max(0, MS.recoil - dt * 4); if (t > F + 1.6) MS.cup = 1; },
    phases: [[0, T0, "Slotted: the Chest Launcher at rest"], [T0, F, "Wind-up 0.3 s: the tube rises, the tank charges, the target shows (36 studs wide)"], [F, LAND, "Fires: the canister arcs over in 0.4 s"], [LAND, LAND + 1, "Bursts into the poison cloud (36 studs wide, 5 s)"], [LAND + 1, 6.2, "Recovery: the tube vents; the cloud keeps ticking"]]};
};
VT.hiss = S => { const X = KITS[S]; place(R0, -5, -19); place(R1, 7, -24); const T0 = 0.6, B = T0 + 0.5; const spk = () => partPoint(mk("hiss.A")[0]);
  const keys = idleIntro([K(T0 + 0.45, HISS_WIND, "io"), K(B + 0.05, HISS_BLAST, "out5"), K(B + 0.4, HISS_BLAST), K(B + 1.0, READY, "io")], T0);
  const ev = [{t: T0, f: () => X.charge(spk, B - T0, 2.2)}, {t: B, f: () => { MS.pump = 1; hitStop = 0.06; shake = 1; fovPunch = 3; X.wave(spk(), V3(0, 0, -1), 30, 35);
      for (const R of [R0, R1]) later(0.08 + Math.abs(R.pos.z) / 120, () => { R.flinch = 1; R.side = 0; R.push = 7; R.pushDir.copy(R.pos).sub(dilo.pos).setY(0).normalize(); R.flash = 0.12; R.flashCol = [0.7, 0.6, 1]; X.status(R, "SILENCED · 3 s", 2.6); }); }},
    {t: B + 0.55, f: () => X.vent(spk, 0.9, 1)}];
  return {frame: [V3(0, 0, 2), V3(0, 0, -32)], keys, ev, frill: [[T0 + 0.15, B + 0.9]], len: 3.8,
    update(t, dt) { MS.charge = t < T0 ? 0 : t < B ? (t - T0) / (B - T0) : Math.max(0, 1 - (t - B) / 0.3); MS.pump = Math.max(0, MS.pump - dt * 3); },
    phases: [[0, T0, "Slotted: the Hood Speakers at rest"], [T0, B, "Wind-up 0.5 s: the hood flares, the speakers charge"], [B, B + 0.5, "Blast: a 30-stud cone knocks back and SILENCES 3 s"], [B + 0.5, 3.8, "Recovery: the speakers vent, the hood folds"]]};
};
VT.spine = S => { const X = KITS[S]; const at = a => V3(Math.sin(a) * 15, 0, -Math.cos(a) * 15); R0.show = true; R0.pos.copy(at(rad(315))); R0.yaw = yawTo(R0.pos, V3()); R1.show = true; R1.pos.copy(at(rad(225))); R1.yaw = yawTo(R1.pos, V3());
  R0._hit = 0; R1._hit = 0; const T0 = 0.6, F = T0 + 0.42; const ms = mk("spine.C"); const st = {};
  const keys = idleIntro([K(T0 + 0.35, CURL, "io"), K(F + 0.04, BURST, "out5"), K(F + 0.4, BURST), K(F + 1.1, READY, "io")], T0);
  const ev = [{t: T0, f: () => addFx(new THREE.Object3D(), F - T0, (o, u, dt) => X.barbs(ms.map(m => partPoint(m)), 0.4 + u, dt, st))},
    {t: F, f: () => { MS.loaded = 0; shake = 0.9; hitStop = 0.05; fovPunch = 2; X.ring(dilo.pos, 22);
      for (let i = 0; i < 12; i++) { const p = partPoint(ms[i]), a = ms[i].name; const dir = V3(Math.sin(a), 0.05, -Math.cos(a)).normalize(); X.muzzle(p, dir, 0.35); let tgt = null;
        for (const R of [R0, R1]) { const to = R.pos.clone().sub(dilo.pos).setY(0).normalize(); if (to.dot(dir.clone().setY(0).normalize()) > Math.cos(rad(16)) && !R._hit) { R._hit = 1; tgt = R; } }
        const end = tgt ? rapChest(tgt) : p.clone().addScaledVector(dir, 44); const R = tgt;
        X.shot({kind: "quill", from: p, to: end, T: 0.05 + 0.13 * p.distanceTo(end) / 44, H: 0, size: 0.8, onHit: q => { if (R) { X.impact(q, 0.9); hitR(R, q, 4); venomOn(R, 2, 3); } else glow(q, 0xffffff, 2, 0.1); }}); } }},
    {t: F + 0.3, f: () => X.vent(() => partPoint(ms[0]), 1.0, 0.8)}];
  return {frame: [V3(-13, 0, -13), V3(13, 0, 13)], keys, ev, tremble: [T0 + 0.05, F], frill: [[T0 + 0.08, F + 0.8]], len: 3.2,
    update(t) { MS.extend = t < T0 ? 0 : t < F ? E.io((t - T0) / (F - T0)) : 0; if (t > F + 1.2) MS.loaded = 1; },
    phases: [[0, T0, "Slotted: the Frill Barbs (magazines on the neck)"], [T0, F, "Wind-up 0.42 s: curls, the hood flares, the barbs charge"], [F, F + 0.4, "12 spines all around, 44 studs, 4 + venom each"], [F + 0.4, 3.2, "Recovery: the barbs vent and reload"]]};
};
VT.pump = S => { const X = KITS[S], P = PB[S]; place(R0, -4, -34); const T0 = 0.8, J = T0 + 0.62; const pump = () => partPoint(mk("pump.A")[0]); let D = null;
  const keys = [K(0, SICK), K(T0, SICK), K(T0 + 0.5, PRIME, "io"), K(J, JOLT, "out5"), K(J + 0.45, PROUD, "io"), K(J + 1.4, READY, "io")]; const tags = [];
  const ev = [{t: 0.01, f: () => { const h = dilo.pos.clone(); tags.push(textTag(h.clone().add(V3(0, 24, 0)), "POISONED", "#b8ff70", 9), textTag(h.clone().add(V3(0, 21, 0)), "SLOWED 40%", "#ffd34d", 9), textTag(h.clone().add(V3(0, 18, 0)), "BLINDED", "#cfd3dc", 9)); }},
    {t: T0, f: () => X.charge(pump, J - T0, 1.6, P)},
    {t: J, f: () => { hitStop = 0.06; shake = 0.6; fovPunch = 2.5; tags.forEach(o => { glow(o.position.clone(), 0xffffff, 6, 0.16); killFx(o); }); X.purge(pump);
      numberPop(dilo.pos.clone().add(V3(0, 22, 0)), "+30", "venom"); textTag(dilo.pos.clone().add(V3(0, 26, 0)), "IMMUNE · 4 s", "#9fe6ff", 4); D = X.shell(() => dilo.pos.clone().setY(8), 11.5, 4, P); }},
    {t: J + 1.5, f: () => { spawnShot({kind: "glob", from: headOf(R0), target: () => dilo.pos.clone().add(V3(0, 8, -10.5)), T: 0.5, H: 1, onHit: p => { if (D) D.hit(p); textTag(p.clone().setY(16), "BLOCKED", "#9fe6ff", 1.2); }}); R0.lunge = 1; }}];
  return {frame: [V3(0, 0, 6), V3(0, 0, -34)], keys, ev, len: 5.6,
    tint: t => t < J ? [0.03, 0.08 + 0.04 * Math.sin(clockT * 7), 0.01] : t < J + 4 ? [0.02, 0.05, 0.1] : null,
    update(t, dt) { MS.pump = t < T0 ? 0 : t < T0 + 0.45 ? E.io((t - T0) / 0.45) : t < J ? 1 - E.in2((t - T0 - 0.45) / (J - T0 - 0.45)) : 0;
      MS.fluid = t < J - 0.05 ? 1 : Math.max(0.15, 1 - (t - J + 0.05) / 0.25); if (t > J + 2.6) MS.fluid = Math.min(1, 0.15 + (t - J - 2.6) / 1.2);
      if (t < J && Math.random() < dt * 14) { const part = dilo.parts[(Math.random() * 120) | 0]; if (part && part.kind !== "mech") droplet(partPoint(part), V3(rnd(1), -3, rnd(1)), 0.9, 0.6, 30); } },
    phases: [[0, T0, "Poisoned, slowed, blinded"], [T0, J, "Wind-up 0.62 s: the Back Pump primes"], [J, J + 0.5, "Jolt: debuffs gone, +30, IMMUNE 4 s"], [J + 0.5, 5.6, "Immune: a raptor's shot is blocked"]]};
};
VT.jets = S => { const X = KITS[S]; place(R0, -7, -38, rad(-90)); const T0 = 0.6, GO = T0 + 0.1, DUR = 0.3, DIST = 65; const nz = () => partPoint(mk("jets.C")[0]);
  const keys = idleIntro([K(T0 + 0.08, DASH_LOW, "io"), K(GO + 0.04, DASH_GO, "out5"), K(GO + DUR, DASH_GO), K(GO + DUR + 0.22, DASH_SKID, "out"), K(GO + DUR + 0.9, READY, "io")], T0);
  const arrow = new THREE.Mesh(new THREE.PlaneGeometry(2.2, 12), new THREE.MeshBasicMaterial({map: dashTex, color: 0xffd34d, transparent: true, opacity: 0.9, depthWrite: false}));
  arrow.rotation.x = -Math.PI / 2; arrow.position.set(0, 0.12, -12); addFx(arrow, GO, (o, u) => { o.material.opacity = 0.85 * Math.min(1, u * 4); dashTex.offset.y = -clockT * 2; });
  const ev = [{t: GO, f: () => { MS.pips = 2; shake = 0.7; fovPunch = 4; hitStop = 0.03; X.muzzle(nz(), V3(0, 0.2, 1).normalize(), 1.6); X.flame(nz, () => V3(0, 0.12, 1).normalize(), DUR + 0.45, 1.5); textTag(dilo.pos.clone().add(V3(0, 22, 0)), "CHARGES 2 / 3", "#ffd34d", 1.4); }},
    {t: GO + DUR, f: () => X.trail(V3(0, 0, -3), V3(0, 0, -DIST), 3.2)},
    {t: GO + DUR + 0.3, f: () => { R0.flinch = 1; R0.flash = 0.12; R0.flashCol = [0.35, 0.95, 0.15]; venomOn(R0, 2, 3, "cough"); }}];
  return {frame: [V3(0, 0, 6), V3(0, 0, -72)], keys, ev, len: 3.8,
    dash: t => t < GO ? 0 : t < GO + DUR ? DIST * E.out((t - GO) / DUR) : DIST + 3 * E.out(Math.min(1, (t - GO - DUR) / 0.25)),
    update(t) { MS.heat = t < T0 ? 0 : t < GO ? (t - T0) / (GO - T0) : t < GO + DUR ? 1 : Math.max(0, 1 - (t - GO - DUR) / 0.5); if (t > GO + 2.4) MS.pips = 3; },
    phases: [[0, T0, "Slotted: the Tail Booster, 3 charges"], [T0, GO, "The press: a 0.1 s crouch, the booster lights"], [GO, GO + DUR, "65-stud dash in 0.3 s"], [GO + DUR, GO + DUR + 0.9, "Skids to a stop (no landing FX)"], [GO + DUR + 0.9, 3.8, "The poison trail hits the raptor beside it"]]};
};
VT.over = S => { const X = KITS[S]; place(R0, -4, -36); const T0 = 0.6, ON = T0 + 0.7, END = ON + 4.6; const core = () => partPoint(mk("over.A")[0]); const st = {};
  const keys = [K(0, READY), K(T0, READY), K(T0 + 0.55, HISS_WIND, "io"), K(ON + 0.05, ROAR, "out5"), K(ON + 0.5, ROAR), K(ON + 0.85, SPIT_SET, "io")];
  const ev = [{t: T0, f: () => X.charge(core, ON - T0, 2.4)}, {t: ON, f: () => { hitStop = 0.07; shake = 0.9; fovPunch = 3; X.nova(core()); textTag(dilo.pos.clone().add(V3(0, 27, 0)), "OVERDRIVE · 8 s", "#b8ff70", 2);
      follow(() => dilo.pos, END - ON, (p, dt) => X.auraTick(st, dt, S === "B" ? 1.2 : 1.8)); }}, {t: END, f: () => X.vent(core, 1.2, 1.6)}];
  for (let i = 0; i < 10; i++) { const t = ON + 1.0 + i * 0.36; keys.push(K(t - 0.08, SPIT_SET, "io"), K(t + 0.02, SPIT_GO, "out5"));
    ev.push({t, f: () => { const from = mouthPoint(), to = rapChest(R0); X.muzzle(from, to.clone().sub(from).normalize(), 0.7);
      X.shot({kind: "dart", from, to: () => rapChest(R0), T: 0.26, H: 0.25, size: 1.0, onHit: p => { X.impact(p, 0.9); hitR(R0, p, 6); venomOn(R0, 4, 3, "now"); if (i === 0) textTag(headOf(R0).setY(18), "VENOM x2", "#b8ff70", 1.6); }}); }}); }
  keys.push(K(END - 0.1, SPIT_SET, "io"), K(END + 0.6, READY, "io"));
  const TINT = {A: [0.03, 0.09, 0.01], B: [0.04, 0.12, 0.06], C: [0.08, 0.06, 0.0]};
  return {frame: [V3(0, 0, 4), V3(0, 0, -38)], keys, ev, frill: [[ON - 0.1, END]], len: END + 1.2,
    tint: () => { const g = MS.glow, c = TINT[S]; return g > 0 ? [c[0] * g, c[1] * g * (1 + 0.3 * Math.sin(clockT * 10)), c[2] * g] : null; }, frillTint: () => MS.glow > 0.3 ? (S === "C" ? 0xb8a020 : 0x5cd22a) : null,
    update(t) { MS.glow = t < T0 ? 0 : t < ON ? (t - T0) / (ON - T0) : t < END ? 1 : Math.max(0, 1 - (t - END) / 0.6); },
    phases: [[0, T0, "Slotted: the Venom Reactor at rest"], [T0, ON, "Wind-up 0.7 s: rears up, the reactor charges"], [ON, ON + 1, "OVERDRIVE: the reactor bursts, the aura starts"], [ON + 1, END, "Darts with no recharge, venom x2 (8 s shown in 4.6)"], [END, END + 1.2, "Recovery: the reactor vents"]]};
};
function oldTrack(id) { const t = BUILD[id](GAMELOOK[id]); t.len = LEN[id]; t.phases = PHASES[id](); return t; }

// ===================================================================================================================================
// MOBILITY: a small movement simulator (measured in Studio 2026-11-10: run 50.7 studs/s = 78 x StatSpeedScale 0.65; Cobra Leap
// wind-up ~0.3 s with the run speed kept, then 0.6 s in the air at run + JumpBoost 14 = 64.5 studs/s, ~9 studs high)
// ===================================================================================================================================
const NOWP = {run: 50.7, turn: 360, wind: 0.27, boost: 14, air: 0.6, h: 9};
const KAP = Object.assign({}, NOWP, {turn: 540, wind: 0.12, boost: 28});
const GRAV = 8 * NOWP.h / (NOWP.air * NOWP.air), V0 = 4 * NOWP.h / NOWP.air; // 200, 60
const fwdOf = yaw => V3(-Math.sin(yaw), 0, -Math.cos(yaw));
function simulate(prof, sc, len, start, blocks) {
  const dt = 1 / 120, F = []; const pos = start.clone(); let yaw = 0, st = "run", stT = 0, y = sc.y0 || 0, vy = 0, hs = prof.run, dist = 0, dashLeft = 0, dashV = 0, dashDir = null, boostEnd = -1, zip = null, lastDash = -9, rushEnd = -1;
  const gY = (x, z) => { let g = 0; for (const b of blocks || []) if (x > b.x0 && x < b.x1 && z > b.z0 && z < b.z1) g = Math.max(g, b.h); return g; };
  const hit = (list, t) => (list || []).some(e => (typeof e === "number" ? e : e[0]) > t - dt - 1e-9 && (typeof e === "number" ? e : e[0]) <= t + 1e-9);
  const evAt = (list, t) => (list || []).find(e => e[0] > t - dt - 1e-9 && e[0] <= t + 1e-9);
  for (let t = 0; t <= len + 1e-9; t += dt) {
    let want = 0; for (const [tt, yd] of sc.turns || []) if (t >= tt) want = rad(yd);
    const holding = (sc.hold || []).some(([a, b]) => t >= a && t < b);
    if (hit(sc.jumps, t) && (st === "run" || st === "dash" && sc.dashJump)) { const carry = st === "dash" ? dashV * 0.5 : 0; st = "wind"; stT = t; hs = Math.max(prof.run, carry); if (st === "dash") dashLeft = 0; }
    const de = evAt(sc.dash, t); if (de && (y <= gY(pos.x, pos.z) + 0.01 || sc.airDash)) { dashDir = fwdOf(yaw); dashV = de[1] / de[2]; dashLeft = de[2]; st = y > gY(pos.x, pos.z) + 0.01 ? "airdash" : "dash"; stT = t; lastDash = t; }
    const be = evAt(sc.boost, t); if (be) { boostEnd = t + be[1]; st = "boost"; stT = t; }
    const ze = evAt(sc.zip, t); if (ze) { zip = {t0: t, T: ze[2], from: pos.clone(), y0: y, to: ze[1].clone()}; st = "zip"; stT = t; }
    const re = evAt(sc.rush, t); if (re) rushEnd = t + re[1];
    const rush = t < rushEnd ? (sc.rushMul || 1.25) : 1;
    // turning
    if (st !== "dash" && st !== "airdash" && st !== "zip") { let d = want - yaw; while (d > Math.PI) d -= 2 * Math.PI; while (d < -Math.PI) d += 2 * Math.PI; const mx = rad(prof.turn) * dt; yaw += Math.max(-mx, Math.min(mx, d)); }
    let v = V3();
    if (st === "run" || st === "wind") { v = fwdOf(yaw).multiplyScalar(prof.run * rush); if (st === "wind" && t - stT >= prof.wind) { st = "air"; stT = t; vy = V0; hs = Math.max(hs, prof.run * rush) + prof.boost; } }
    else if (st === "air" || st === "glide") { v = fwdOf(yaw).multiplyScalar(hs); vy -= GRAV * dt; if (holding && vy < -(sc.glideFall || 8)) { vy = -(sc.glideFall || 8); st = "glide"; } if (!holding && st === "glide") st = "air"; }
    else if (st === "dash" || st === "airdash") { v = dashDir.clone().multiplyScalar(dashV); dashLeft -= dt; if (dashLeft <= 0) { if (st === "airdash") { st = "air"; vy = Math.min(vy, 0); hs = prof.run + prof.boost; } else st = "run"; } }
    else if (st === "boost") { v = fwdOf(yaw).multiplyScalar(prof.run * 2); if (t >= boostEnd) st = y > gY(pos.x, pos.z) + 0.01 ? "air" : "run"; }
    else if (st === "zip") { const u = Math.min(1, (t - zip.t0) / zip.T); const p = zip.from.clone().lerp(zip.to, E.io(u)); v = p.clone().sub(pos).divideScalar(dt).setY(0); y = zip.y0 + (zip.to.y - zip.y0) * E.out(u) + 6 * Math.sin(Math.PI * u); if (u >= 1) { st = "run"; y = zip.to.y; } }
    // move, with walls (a block taller than the body's feet stops it)
    const nx = pos.x + v.x * dt, nz = pos.z + v.z * dt; const g1 = gY(nx, nz);
    if (st !== "zip" && g1 > y + 2) { /* blocked */ if (st === "run" || st === "boost") v.set(0, 0, 0); else { v.set(0, 0, 0); hs = 0; } }
    else { dist += Math.hypot(nx - pos.x, nz - pos.z); pos.x = nx; pos.z = nz; }
    if (st === "air" || st === "glide" || st === "airdash") { if (st !== "airdash") y += vy * dt; const g = gY(pos.x, pos.z); if (y <= g && vy <= 0) { y = g; vy = 0; st = "run"; } }
    if ((st === "run" || st === "boost") && y > gY(pos.x, pos.z) + 0.01) { st = "air"; vy = 0; hs = Math.max(prof.run, v.length()); }
    if (st === "run") y = gY(pos.x, pos.z);
    const run = st === "run" ? 1 : st === "wind" ? 0.7 : st === "boost" ? 1.3 : 0;
    F.push({t, x: pos.x, z: pos.z, y, yaw, st, run, dist, spd: v.length() * (st === "run" ? 1 : 1), rush: rush > 1});
  }
  return F;
}
function sampler(F) { return t => F[Math.max(0, Math.min(F.length - 1, Math.round(t * 120)))]; }
function statePose(m) { switch (m.st) { case "wind": return J_CROUCH; case "air": case "zip": return J_AIR; case "glide": return addPose(J_AIR, BOTH({ArmL: [-40, 0, -34], Neck: [-14, 0, 0], Tail1: [-10, 0, 0], LegL: [-10, 0, 0], KneeL: [20, 0, 0]}), 1);
  case "dash": case "airdash": case "boost": return DASH_GO; default: return READY; } }
function runLayer(rn, ph) { const s = Math.sin(ph), c = Math.cos(ph); return {RootJoint: [-6 * rn, 0, 0], Neck: [-4 * rn, 0, 0], LegL: [34 * s * rn, 0, 0], LegR: [-34 * s * rn, 0, 0], KneeL: [-(18 + 22 * Math.max(0, c)) * rn, 0, 0], KneeR: [-(18 + 22 * Math.max(0, -c)) * rn, 0, 0],
  ArmL: [-18 * rn, 0, 0], ArmR: [-18 * rn, 0, 0], Tail1: [-6 * rn, Math.sin(ph * 0.5) * 6 * rn, 0]}; }
// the "now" ghost (a see-through copy of the Dilo doing the same input with today's numbers)
const ghost = buildDino(DILO, 2); ghost.mats.forEach(m => { m.transparent = true; m.opacity = 0.32; m.depthWrite = false; m.emissive.setHex(0x16263a); }); ghost.g.visible = false; ghost.frillS = 0; pose(ghost, {}); ghost.ph = 0;
let mobBlocks = []; const mobProps = [];
function mobScene(blocks, len) { mobBlocks = blocks; mobProps.splice(0).forEach(o => scene.remove(o));
  const stripeM = new THREE.MeshBasicMaterial({color: 0xffffff, transparent: true, opacity: 0.55, depthWrite: false});
  for (let z = 40; z >= -520; z -= 10) { const m = new THREE.Mesh(new THREE.PlaneGeometry(z % 50 === 0 ? 46 : 30, z % 50 === 0 ? 0.6 : 0.3), stripeM); m.rotation.x = -Math.PI / 2; m.position.set(0, 0.12 + gYw(0, z), z); scene.add(m); mobProps.push(m);
    if (z % 50 === 0 && z <= 0) { const tg = textTag(V3(-26, 3 + gYw(0, z), z), (-z) + " studs", "#ffffff", 999); mobProps.push(tg); } }
  const rockM = new THREE.MeshLambertMaterial({color: 0x9c8f78, transparent: true, opacity: 0.6, depthWrite: false}); for (const b of blocks) { const m = new THREE.Mesh(new THREE.BoxGeometry(b.x1 - b.x0, b.h, b.z1 - b.z0), rockM); m.position.set((b.x0 + b.x1) / 2, b.h / 2, (b.z0 + b.z1) / 2); m.castShadow = m.receiveShadow = true; scene.add(m); mobProps.push(m); } }
function gYw(x, z) { let g = 0; for (const b of mobBlocks) if (x > b.x0 && x < b.x1 && z > b.z0 && z < b.z1) g = Math.max(g, b.h); return g; }
function followTag(fn, text, color, life) { const s = textTag(fn(), text, color, life); s.scale.set(16, 3.2, 1); addFx(new THREE.Object3D(), life, () => s.position.copy(fn())); return s; }
const LANE = 9;
function mobTrack(o) {
  const len = o.len || 4.6; const blocks = o.blocks || []; mobBlocks = blocks; const s0 = V3(-LANE, 0, 30), g0 = V3(LANE, 0, 30);
  const FN = simulate(o.newP, o.newS, len, s0, blocks), FG = simulate(o.nowP, o.nowS, len, g0, blocks); const sn = sampler(FN), sg = sampler(FG);
  mobScene(blocks, len); R0.show = false; R1.show = false; if (o.setup) o.setup();
  followTag(() => { const m = sn(play.t); return V3(m.x, m.y + 22, m.z); }, "NEW", "#ffd34d", len + 0.5); followTag(() => { const m = sg(play.t); return V3(m.x, m.y + 22, m.z); }, "NOW", "#cfd3dc", len + 0.5);
  const st = {}; let lastSt = "run", lastGSt = "run";
  return {keys: [K(0, READY)], move: sn, ghost: sg, len, ev: o.ev || [], phases: o.phases, frameFn: t => { const a = sn(t), b = sg(t); return [V3(Math.min(a.x, b.x), 0, Math.max(a.z, b.z) + 8), V3(Math.max(a.x, b.x), 0, Math.min(a.z, b.z) - 30)]; },
    frillFn: t => { const m = sn(t); return m.st === "air" || m.st === "glide" || m.st === "wind" || m.st === "zip" || m.st === "boost"; },
    update(t, dt) { const m = sn(t), g = sg(t); if (m.st !== lastSt) { if (o.onState) o.onState(m.st, lastSt, m, t, "new"); lastSt = m.st; } if (g.st !== lastGSt) { if (o.onState) o.onState(g.st, lastGSt, g, t, "now"); lastGSt = g.st; }
      if (o.tick) o.tick(m, g, t, dt, st);
      mobInfo = {n: m.dist, g: g.dist, ns: m.st, gs: g.st}; }};
}
let mobInfo = null;
const dPos = (m) => V3(m.x, m.y, m.z);
function dust(p, n) { for (let i = 0; i < (n || 6); i++) smoke(p.clone().add(V3(rnd(2), 0.6, rnd(2))), V3(rnd(8), 2 + Math.random() * 3, rnd(8)), 2.6, 0xc2ad7a, 0.7, 0.6, 1.6); }
const nozzleNow = () => partPoint(mk("jets.C")[0]);
const MOB = {
  ka: () => mobTrack({newP: KAP, nowP: NOWP, newS: {jumps: [0.5, 2.7], turns: [[1.7, 40], [2.35, 0]]}, nowS: {jumps: [0.5, 2.7], turns: [[1.7, 40], [2.35, 0]]},
    onState(s, prev, m, t, who) { if (s === "air" && prev === "wind") { dust(V3(m.x, m.y, m.z), who === "new" ? 8 : 4); if (who === "new") { KB.ring(V3(m.x, m.y, m.z), 6, PV.B); } } },
    tick(m, g, t, dt, st) { if (m.st === "air") rate(st, "f", 30, dt, () => { const p = partPoint(P_("Neck_frillL1a") || dilo.parts[0]); spark(p, V3(rnd(2), 1, 6), PV.B.main, 0.3, 0.8, 0); }); },
    phases: [[0, 0.5, "Both run at 50.7 studs/s and press JUMP at 0.5 s"], [0.5, 1.3, "NEW leaves the ground after 0.12 s (NOW 0.27 s) and pushes +28 (NOW +14)"], [1.3, 2.6, "Both swerve 40° and back: NEW turns at 540°/s (NOW 360°/s)"], [2.6, 4.6, "Second leap; watch the distance markers"]]}),
  kb: () => mobTrack({len: 5.2, blocks: [{x0: -40, x1: 40, z0: -12, z1: 60, h: 24}], newP: NOWP, nowP: NOWP, newS: {y0: 24, jumps: [0.55], hold: [[0.55, 5.2]]}, nowS: {y0: 24, jumps: [0.55]},
    tick(m, g, t, dt, st) { if (m.st === "glide") { rate(st, "w", 40, dt, () => { const side = Math.random() < 0.5 ? -1 : 1; const p = dPos(m).add(V3(side * 7, 13, 2)); streak(p, p.clone().add(V3(0, 0, 6)), 0.08, 0xffffff, 0.15, 0.7); });
      rate(st, "g", 24, dt, () => { const fr = dilo.parts.filter(p => p.kind === "frill"); const q = partPoint(fr[(Math.random() * fr.length) | 0]); spark(q, V3(rnd(1), -1, 5), PV.A.glow, 0.35, 0.9, 0); }); } },
    phases: [[0, 0.55, "Both run off the end of a 24-stud ledge"], [0.55, 1.0, "Cobra Leap off the edge"], [1.0, 5.2, "NEW holds JUMP: the frill spreads and it glides down at 8 studs/s; NOW drops"]]}),
  kc: () => mobTrack({newP: NOWP, nowP: NOWP, newS: {rush: [[0.75, 2], [2.75, 2]], rushMul: 1.25}, nowS: {},
    setup() { place(R0, -34, -40, rad(-90)); },
    ev: [0.55, 2.55].map(t0 => ({t: t0, f: () => { const from = mouthPoint(), R = R0; R0.pos.z = dilo.pos.z - 40; KB.muzzle(from, V3(-1, 0, -1).normalize(), 0.6); spawnShot({kind: "dart", from, target: () => rapChest(R), T: 0.2, H: 0.2, onHit: p => { hitR(R, p, 6); KB.impact(p, 0.7); textTag(dilo.pos.clone().add(V3(0, 24, 0)), "VENOM RUSH x1.25 · 2 s", "#b8ff70", 1.6); }}); }})),
    tick(m, g, t, dt, st) { R0.pos.z = Math.min(R0.pos.z, m.z - 20); if (m.rush) { rate(st, "r", 50, dt, () => { const part = dilo.parts[(Math.random() * 140) | 0]; if (part && part.kind !== "mech") { const q = partPoint(part); streak(q, q.clone().add(V3(0, 0, 5)), 0.1, PV.B.main, 0.14, 0.8); } });
      rate(st, "d", 20, dt, () => smoke(dPos(m).add(V3(rnd(3), 0.6, 3)), V3(0, 1, 4), 2.4, PV.A.glow, 0.6, 0.45)); } },
    phases: [[0, 0.75, "Both run; NEW spits a raptor at 0.55 s"], [0.75, 2.75, "Hit: Venom Rush, run x1.25 (63.4 studs/s) for 2 s"], [2.75, 4.6, "Second hit, second rush"]]}),
  ma: () => mobTrack({newP: NOWP, nowP: NOWP, newS: {boost: [[0.6, 1.85]], turns: [[1.25, 30], [1.9, -10], [2.5, 0]]}, nowS: {dash: [[0.6, 65, 0.325]], turns: [[1.25, 30], [1.9, -10], [2.5, 0]]},
    onState(s, prev, m, t, who) { if (s === "boost") { fovPunch = 4; shake = 0.5; KC.flame(nozzleNow, () => V3(Math.sin(dilo.yaw), 0.1, Math.cos(dilo.yaw)).normalize(), 1.85, 1.7); }
      if (who === "now" && s === "dash") { const gp = () => { const g = play.track.ghost(play.t); return V3(g.x, g.y + 9, g.z + 6); }; KC.flame(gp, () => V3(0, 0.1, 1), 0.4, 1.1); } },
    phases: [[0, 0.6, "Both run"], [0.6, 2.45, "NEW: Tail Thrusters, 1.85 s at 2x run (101 studs/s), steering through the swerve; NOW: Spring Jets, 65 studs in 0.3 s, straight"], [2.45, 4.6, "Back to running; the gap stays"]]}),
  mb: () => mobTrack({newP: NOWP, nowP: NOWP, newS: {dash: [[0.5, 65, 0.325], [1.25, 65, 0.325], [2.6, 65, 0.325]], jumps: [0.85], airDash: true, dashJump: true}, nowS: {dash: [[0.5, 65, 0.325], [2.6, 65, 0.325]], jumps: [0.85]},
    onState(s, prev, m, t, who) { if (who === "new" && (s === "dash" || s === "airdash")) { fovPunch = 3; KB.flame(nozzleNow, () => V3(0, 0.1, 1), 0.4, 1.3); }
      if (who === "now" && s === "dash") { const gp = () => { const g = play.track.ghost(play.t); return V3(g.x, g.y + 9, g.z + 6); }; KB.flame(gp, () => V3(0, 0.1, 1), 0.4, 1.0); } },
    phases: [[0, 0.5, "Both run"], [0.5, 0.85, "Dash 65 studs"], [0.85, 1.25, "Jump right out of it: NEW keeps half the dash speed into the leap"], [1.25, 2.2, "NEW dashes again in mid-air (NOW can't)"], [2.2, 4.6, "Third dash: NEW has 3 charges from I that refill in 3 s"]]}),
  mc: () => { const top = 22; return mobTrack({len: 4.6, blocks: [{x0: -40, x1: 40, z0: -200, z1: -40, h: top}], newP: NOWP, nowP: NOWP, newS: {zip: [[0.62, V3(-LANE, top, -48), 0.45]]}, nowS: {jumps: [1.1]},
    ev: [{t: 0.5, f: () => { const from = mouthPoint(), to = V3(-LANE, top, -42); KB.muzzle(from, to.clone().sub(from).normalize(), 0.8);
      const mt = addM(0x8affa0, 0.95); const line = cylBetween(from, to, 0.25, mt); addFx(line, 0.6, (o, u) => { const a = mouthPoint(); const d = to.clone().sub(a), L = d.length(); o.position.copy(a).addScaledVector(d, 0.5); o.quaternion.setFromUnitVectors(UPV, d.normalize()); o.scale.set(0.3, L * Math.min(1, u * 8), 0.3); mt.opacity = 0.95 * (1 - win(u, 0.75, 1)); });
      later(0.1, () => KB.impact(to, 1)); }}],
    tick(m, g, t, dt, st) { if (m.st === "zip") rate(st, "z", 60, dt, () => { const q = dPos(m).add(V3(rnd(3), 8 + rnd(3), rnd(3))); streak(q, q.clone().add(V3(0, -1, 7)), 0.12, PV.B.main, 0.15, 0.8); }); },
    phases: [[0, 0.5, "Both run at a 22-stud ledge"], [0.5, 1.1, "NEW spits a venom tether onto the ledge and zips up in 0.45 s"], [1.1, 4.6, "NEW runs on top; NOW leaps (9 studs high) and is stuck at the wall"]]}); },
};

// ===================================================================================================================================
// option texts
// ===================================================================================================================================
const FAM = {
  N: {name: "In the game now", short: "Now", one: "The first effects (the mockup they were built from; the game draws them 2–3x bigger since 2026-11-09): small flashes, green dots and flat rings.", roblox: "DiloMovesFX 1.5.", cost: "—"},
  A: {name: "Liquid Venom", short: "A · Liquid Venom", one: "The venom is the ammo: glossy goo that wobbles and drips, splash crowns on every hit, bubbling venom mist, venom fire. The most 'Dilo', organic.",
    roblox: "Ball parts (Glass / SmoothPlastic, Reflectance 0.3) for the goo, stretched along the flight; ParticleEmitters for droplets (1 image upload: a droplet) and mist (the built-in smoke texture); Trails for drips.", cost: "Medium (~25 parts + 4 emitters per big effect)."},
  B: {name: "Reactor Glow", short: "B · Reactor Glow", one: "Mecha energy: white-hot cores in green glow, long tracers, hex rings, shockwaves, holo reticles, plasma thrust. Reads best at range and on a phone.",
    roblox: "Neon parts + Beams / Trails for tracers and rings, ParticleEmitters with the built-in sparkle texture, Highlight edges for shells; 2 image uploads (hex grid, reticle).", cost: "Light (~15 parts + 3 emitters per big effect)."},
  C: {name: "Chem Warfare", short: "C · Chem Warfare", one: "Military chem weapons: muzzle smoke and spent casings, smoke-trailed darts, rolling chemical smoke clouds, hazard-stripe rings, rocket fire.",
    roblox: "ParticleEmitters with the built-in smoke / fire textures (most particles of the three), small casing / debris parts, a Beam for the laser; 1 image upload (hazard ring).", cost: "Heaviest (~40% more particles than B)."},
};
const LINE = {
  gatling: {A: "Each barrel spits a glossy goo dart that wobbles and drips; hits splash a crown of venom that sizzles.", B: "The barrels charge with spiralling sparks, then fire white-hot tracers with long green streaks; hits flash a hex ring and crackle.", C: "Each shot kicks a flash, a smoke puff and a spent casing; darts leave smoke tracers and burst in chemical puffs with sparks."},
  mortar: {A: "The target drips; a wobbling goo ball lobs over and bursts into a huge splash crown and a bubbling venom mist.", B: "A holo reticle and a beam lock the spot; a glowing hex canister arcs over and detonates in a shockwave, leaving a glowing hex field with a light wall at its edge.", C: "A laser dot and a hazard ring mark the spot; a smoking chem canister lands and blows into a rolling yellow-green smoke cloud inside a hazard ring."},
  hiss: {A: "Venom gathers at the speakers, then the blast sprays a cone of venom mist and droplets; the silenced drip violet.", B: "The speakers charge with rings, then 6 neon sound fronts and a shock shell roll out; the silenced get a spinning mute ring.", C: "The blast kicks up a cone of sand and dust with shock fronts and debris; the silenced spark with static."},
  spine: {A: "The barbs ooze venom, then 12 glossy venom quills fly out dripping; a splash ring circles the dino.", B: "Arcs crackle between the barbs, then 12 needles of light streak out; a hex shock ring circles the dino.", C: "The barbs steam and spark, then 12 metal barbs fly with smoke tracers; a hazard ring and a dust ring kick out."},
  pump: {A: "Antivenom gathers at the pump; the jolt splashes blue and flings green venom off the body; a glossy water bubble shields you.", B: "Light spirals into the pump; the jolt sweeps scan rings down the body, purge sparks fly off, a blue hex shield wraps you.", C: "Steam hisses and an alarm light flashes as it primes; the jolt blasts a ring of steam and blue mist; pressurised mist swirls round you."},
  jets: {A: "The booster burns green venom fire with dripping droplets; the trail is a bubbling venom mist.", B: "A plasma thrust cone with a white core and shock diamonds; the trail is a glowing chevron strip on the ground.", C: "Orange rocket fire and thick smoke (the Raptor's Thrusters family); the trail is a drifting chemical smoke wall."},
  over: {A: "Venom swirls into the reactor, it bursts in a splash; for 8 s the dino drips venom and fumes; darts are goo.", B: "Energy spirals into the core, it detonates in a shock sphere; for 8 s rings rise up the body and arcs crackle across it; darts are tracers.", C: "Alarm lights and steam, then a blast; for 8 s the fins pour exhaust smoke with warning lights and sparks; darts are smoke-trailed."},
};
const REC_FX = {gatling: "B", mortar: "B", hiss: "B", spine: "B", pump: "B", jets: "B", over: "B"};
const MOBO = [
  {k: "ka", name: "Cobra Spring", kind: "Base kit · no slot", rec: true, one: "Fixes the feel for every Dilo: the Raptor's quick leap wind-up and turn rate, and twice the leap push.",
    nums: [["Leap wind-up", "0.27 s", "0.12 s (Raptor)"], ["Turn rate", "360°/s", "540°/s (Raptor)"], ["Full-run turn circle", "8.1-stud radius", "5.4-stud radius"], ["Leap push", "+14 (64.5 studs/s)", "+28 (78.7 studs/s)"], ["Leap length", "~39 studs", "~47 studs"]],
    roblox: "DiloModelData numbers only: JumpWindup 0.12, TurnLimitRate 540, JumpBoost 28. No new code.", fx: "Frill flares in the air, a dust kick at take-off (no landing FX)."},
  {k: "kb", name: "Frill Glide", kind: "Base kit · no slot", one: "Hold JUMP after the leap: the frill spreads into a wing and you glide, falling 8 studs/s (the Troodon's glide). A small gain on flat ground, huge off hills, ledges and the mountain.",
    nums: [["Off a 24-stud ledge", "~0.9 s in the air, ~56 studs", "~4.4 s, ~280 studs"], ["Flat ground leap", "0.6 s", "0.6 s + ~1.1 s glide"]], roblox: "GliderTest (the Troodon's glide) on the Dilo: GliderEnabled, GliderAuto false (hold JUMP), GliderFall 8; a DiloPose wing pose.", fx: "Frill-edge streaks and wind lines while gliding."},
  {k: "kc", name: "Venom Rush", kind: "Base kit · no slot", one: "Every dart or bite that hits gives +25% run speed for 2 s. Fits a ranged spitter: hit, then kite.",
    nums: [["Run after a hit", "50.7 studs/s", "63.4 studs/s for 2 s"]], roblox: "DiloAttackServer stamps DiloRushUntil on a hit; SprintTest multiplies the run (the Quick Feet hook).", fx: "Green speed streaks along the body and venom mist at the feet while it runs."},
  {k: "ma", name: "Tail Thrusters", kind: "Mecha part · Speed · takes a slot", rec: true, one: "The Raptor's Thrusters on the Dilo's Tail Booster: hold to boost at 2x run and steer. It would replace Spring Jets in the Speed area (or sit beside it: your call).",
    nums: [["Burst", "Spring Jets: 65 studs in 0.3 s, straight", "1.37 s boost (1.85 s at III) at 101 studs/s, steerable"], ["Distance", "65 studs", "~139 studs (~187 at III)"], ["Charges", "1 / 2 / 3 (★), 4.2 s each", "2 from II, as the Raptor"]],
    roblox: "MechaServer / MechaButtons Thrusters reused for the Dilo (owner rule), flame at the Tail Booster nozzle, the Raptor's FX recipe (MechaServer 1.2).", fx: "The Raptor's orange thruster flame + smoke out of the Tail Booster."},
  {k: "mb", name: "Spring Jets+", kind: "Mecha part · Speed · upgrade", one: "Keep the dash but make it chain: 3 charges from I that refill in 3 s, it works in mid-air, and a jump right out of a dash keeps half the dash speed.",
    nums: [["Charges", "1 / 2 / 3", "3 from I"], ["Refill", "4.2 s each", "3 s each"], ["In the air", "no", "yes"], ["Dash → leap", "a normal leap", "a leap at half the dash speed"]], roblox: "DiloMovesServer / DiloJetsLaunch: air dash allowed, JumpTest keeps the dash speed for 0.2 s.", fx: "Short plasma bursts per dash."},
  {k: "mc", name: "Venom Tether", kind: "Mecha part · Speed · new", one: "Spit a venom tether up to 70 studs at a wall, ledge or the ground ahead and zip to it in 0.45 s. Gets you onto rocks and the mountain the Dilo can't leap up.",
    nums: [["Range", "—", "70 studs"], ["Zip time", "—", "0.45 s"], ["Charges", "—", "2, 5 s each"]], roblox: "TheriGrappleZip 1.3 pattern (world ray, LinearVelocity drive); a Beam for the tether.", fx: "A green tether line, a splat where it sticks, speed streaks on the zip."},
];

// ===================================================================================================================================
// the player
// ===================================================================================================================================
const PARTS = MOVES.filter(m => m.id !== "all");
Object.assign(PARTS.find(m => m.id === "gatling"), {max: "Twin hood repeaters fire 8 auto-aimed darts in 1 second; every dart adds venom."});
Object.assign(PARTS.find(m => m.id === "mortar"), {max: "Lob a canister up to 120 studs. It bursts into a 36-stud poison cloud for 5 s."});
Object.assign(PARTS.find(m => m.id === "spine"), {max: "The frill fires 12 spines all around, 44 studs, each 4 damage plus venom."});
Object.assign(PARTS.find(m => m.id === "jets"), {max: "A 65-stud dash the way you move, 3 charges, and it leaves a poison trail."});
const TABS = [...PARTS, {id: "mob", name: "Mobility", area: "speed"}];
let cur = 0, playing = true, speed = 1, camMode = "hero";
const pick = Object.assign({mob: "ka"}, REC_FX);
const TAB = () => TABS[cur];
const view = {yaw: 0, pitch: 0, zoom: 0.72};
function lookOn(look) { const id = TAB().id; if (id === "mob") return (pick.mob === "ma" || pick.mob === "mb") && look === "jets.C"; return look === id + "." + GAMELOOK[id]; }
function resetFx() { fx.splice(0).forEach(e => scene.remove(e.obj)); shots.splice(0).forEach(s => { scene.remove(s.mesh); scene.remove(s.glow); }); delayed = []; cone30.visible = false; }
function start() {
  resetFx(); msReset(); mobProps.splice(0).forEach(o => scene.remove(o)); mobBlocks = []; mobInfo = null;
  for (const R of raps) { R.flinch = 0; R.flash = 0; R.push = 0; R.venom = null; R.slow = 0; R.path = null; R.run = 0; R.lunge = 0; R.show = false; }
  for (const k in aimCone) aimCone[k].visible = false;
  play = {track: null, t: 0, fired: new Set()}; dilo.pos.set(0, 0, 0); dilo.yaw = 0; ghost.g.visible = false; dilo.ph = 0;
  const id = TAB().id; play.track = id === "mob" ? MOB[pick.mob]() : pick[id] === "N" ? oldTrack(id) : VT[id](pick[id]);
  frill.open = false; frill.t = 9; dilo.sac = 1; springs = {}; rootSpring.x = 0; rootSpring.v = 0; hitStop = 0; shake = 0; fovPunch = 0;
}
function idleLayer(t) { const b = Math.sin(t * 2.1), b2 = Math.sin(t * 2.1 + 1.2);
  return {RootJoint: [b * 1.0, 0, 0], Neck: [b * 1.6, Math.sin(t * 0.7) * 4, 0], Head: [-b * 1.4, Math.sin(t * 0.9 + 1) * 3, 0], Jaw: [Math.max(0, Math.sin(t * 0.5)) * -3, 0, 0], ArmL: [b2 * 3, 0, 0], ArmR: [b2 * 3, 0, 0],
    Tail1: [b * 1.2, Math.sin(t * 1.3) * 4, 0], Tail2: [0, Math.sin(t * 1.3 - .6) * 5, 0], Tail3: [0, Math.sin(t * 1.3 - 1.2) * 6, 0], Tail4: [0, Math.sin(t * 1.3 - 1.8) * 7, 0], Tail5: [0, Math.sin(t * 1.3 - 2.4) * 8, 0]}; }
function inWin(list, t) { return (list || []).some(([a, b]) => t >= a && t < b); }
function frillScale() { if (frill.open) { const u = Math.min(1, frill.t / 0.13); let s = 0.2 + 0.8 * E.back(u); if (frill.t < 0.3) s += Math.sin(frill.t * 95) * 0.035 * (1 - frill.t / 0.3); return s; } return frill.t < 0.1 ? 1 - 0.75 * (frill.t / 0.1) : 0; }
const frillMeshes = dilo.parts.filter(p => p.kind === "frill"); frillMeshes.forEach(p => { p.mesh.material = p.mesh.material.clone(); });
function rapPose(R, dt) {
  R.rig.g.visible = R.show; if (!R.show) return;
  R.flinch = Math.max(0, R.flinch - dt * 2.6); R.flash = Math.max(0, R.flash - dt); R.push *= Math.pow(0.03, dt); if (R.lunge) R.lunge = Math.max(0, R.lunge - dt * 2.2);
  const L = R.lunge ? Math.sin(Math.PI * Math.min(1, (1 - R.lunge) * 1.4)) : 0; const f = E.out(R.flinch); let cough = 0; if (R.venom && R.venom.style === "cough") cough = R.venom.next < 0.5 && R.venom.next > 0.25 ? 1 : 0;
  R.rig.yaw = R.yaw; R.rig.pos.copy(R.pos).addScaledVector(R.pushDir, R.push);
  pose(R.rig, {RootJoint: [10 * f - 14 * L, 0, R.side * 8 * f], Neck: [12 * f - 20 * L - 18 * cough, Math.sin(clockT * 0.8) * 4 * (1 - f), 0], Head: [10 * f, 0, 0], Jaw: [-22 * f - 30 * L - 20 * cough, 0, 0],
    ArmL: [-25 * f + 20 * L, 0, 0], ArmR: [-25 * f + 20 * L, 0, 0], Tail1: [-10 * f, Math.sin(clockT * 1.3) * 4, 0], Tail2: [0, Math.sin(clockT * 1.3 - .7) * 5, 0], LegL: [-8 * f, 0, 0], LegR: [-8 * f, 0, 0], KneeL: [-10 * f, 0, 0], KneeR: [-10 * f, 0, 0]});
  if (R.rig.rest !== null) { R.rig.y = R.rig.rest; pose(R.rig, {}); }
  let g = 0;
  if (R.venom) { const Vn = R.venom; Vn.left -= dt; Vn.next -= dt; Vn.age += dt; Vn.drip += dt * 12; g = 0.1 + 0.06 * Math.sin(clockT * 9);
    while (Vn.drip >= 1) { Vn.drip -= 1; const part = R.rig.parts[(Math.random() * R.rig.parts.length) | 0]; const p = partPoint(part); if (p.y > 3) droplet(p, V3(rnd(1), -3, rnd(1)), 0.9 + Math.random() * 0.7, 0.6, 30); }
    if (Vn.next <= 0 && Vn.left > -0.05) { Vn.next += 0.5; const cp = rapChest(R); numberPop(cp.clone().add(V3(rnd(1.5), 5, 0)), Vn.rate * 0.5, "venom"); R.flash = Math.max(R.flash, 0.06); R.flashCol = [0.3, 0.9, 0.12];
      if (Vn.style === "cough") puff(partPoint(R.rig.segs.Head[0]), V3(0, 2, -3), 2.2, 0xb8ff70, 0.6); }
    if (Vn.left <= 0) R.venom = null; }
  const fl = R.flash > 0 ? 1 : 0; R.rig.mats.forEach(m => { m.emissive.setRGB(fl * R.flashCol[0] + (1 - fl) * g * 0.25, fl * R.flashCol[1] + (1 - fl) * g, fl * R.flashCol[2] + (1 - fl) * g * 0.1); });
}
raps.forEach(R => { pose(R.rig, {}); R.rig.y = R.rig.rest; R.rig.g.visible = false; });
const _fm = new THREE.Matrix4();
function frillMat(s) { s = Math.max(0.001, s); return _fm.makeTranslation(frillHub.x, frillHub.y, frillHub.z).multiply(new THREE.Matrix4().makeScale(s, s, s)).multiply(new THREE.Matrix4().makeTranslation(-frillHub.x, -frillHub.y, -frillHub.z)).clone(); }
function mechLocals() { for (const p of MECH) { const on = lookOn(p.look); let vis = on && !p.marker && (!p.show || p.show()); let L = p.base;
  if (p.frill) { const s = p.frill === "min" ? Math.max(0.45, dilo.frillS) : dilo.frillS; if (p.frill !== "min" && s <= 0) vis = false; L = frillMat(s).multiply(p.base); }
  p.local = p.anim ? L.clone().multiply(p.anim(p)) : L.clone(); p.mesh.visible = vis; } }
const camPos = V3(60, 26, -20), camLook = V3(0, 9, -20);
function step(dt, noRender) {
  let mdt = dt * speed; if (hitStop > 0) { hitStop -= mdt; mdt *= 0.05; }
  idleT += mdt; clockT += mdt;
  const tr0 = play.track; play.t += mdt;
  let target = idleLayer(idleT); const mv = sample(tr0.keys, play.t); target = addPose(mv, target, 1);
  let mo = null; if (tr0.move) { mo = tr0.move(play.t); dilo.ph += mdt * 15 * mo.run; target = addPose(addPose(statePose(mo), runLayer(mo.run, dilo.ph), 1), target, 1); }
  if (tr0.tremble && play.t > tr0.tremble[0] && play.t < tr0.tremble[1]) for (const n of ["Neck", "Head", "RootJoint"]) target[n] = target[n].map((v, i) => v + (i === 2 ? Math.sin(clockT * 80 + n.length) * 1.6 : i === 0 ? Math.sin(clockT * 70) * 1.2 : 0));
  const rootFwd = (mv.root && mv.root.fwd) || 0;
  for (const e of (tr0.ev || [])) { const k = "e" + e.t; if (!play.fired.has(k) && play.t >= e.t) { play.fired.add(k); e.f(); } }
  for (let i = delayed.length - 1; i >= 0; i--) if (play.t >= delayed[i].at) { const d = delayed[i]; delayed.splice(i, 1); d.f(); }
  if (tr0.update) tr0.update(play.t, mdt);
  for (const n of dilo.joints.map(j => j.n)) if (!target[n]) target[n] = [0, 0, 0];
  if (tr0.extra) tr0.extra(target);
  const want = tr0.frillFn ? tr0.frillFn(play.t) : inWin(tr0.frill, play.t); if (want !== frill.open) { frill.open = want; frill.t = 0; }
  frill.t += mdt; dilo.frillS = frillScale(); const fs = Math.max(0.001, dilo.frillS);
  dilo.frillM.makeTranslation(frillHub.x, frillHub.y, frillHub.z).multiply(new THREE.Matrix4().makeScale(fs, fs, fs)).multiply(new THREE.Matrix4().makeTranslation(-frillHub.x, -frillHub.y, -frillHub.z));
  const P = springStep(target, mdt);
  for (let i = 0, n = Math.max(1, Math.ceil(mdt * 300)); i < n; i++) { const h = mdt / n; rootSpring.v += (400 * (rootFwd - rootSpring.x) - 2 * 0.9 * 20 * rootSpring.v) * h; rootSpring.x += rootSpring.v * h; }
  if (mo) { dilo.yaw = mo.yaw; dilo.pos.set(mo.x, 0, mo.z); } else { const dash = tr0.dash ? tr0.dash(play.t) : 0; dilo.yaw = 0; dilo.pos.set(0, 0, -(rootSpring.x + dash)); }
  mechLocals(); dilo.y = 0; pose(dilo, P);
  let minY = Infinity; for (const p of diloFeet) for (let i = 0; i < 8; i++) { _c.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(p.mesh.matrix); minY = Math.min(minY, _c.y); }
  dilo.y = -minY + (mo ? mo.y : 0); pose(dilo, P);
  if (tr0.ghost) { const g = tr0.ghost(play.t); ghost.g.visible = true; ghost.ph += mdt * 15 * g.run; ghost.yaw = g.yaw; ghost.pos.set(g.x, 0, g.z); const gp = addPose(statePose(g), runLayer(g.run, ghost.ph), 1); ghost.y = ghost.rest + g.y; pose(ghost, gp); }
  const tint = tr0.tint ? tr0.tint(play.t) : null; dilo.mats.forEach(m => m.emissive.setRGB(tint ? tint[0] : 0, tint ? tint[1] : 0, tint ? tint[2] : 0));
  const ft = tr0.frillTint ? tr0.frillTint() : null; frillMeshes.forEach(p => { p.mesh.material.emissive.setHex(ft || 0x000000); p.mesh.material.emissiveIntensity = ft ? 0.35 + 0.15 * Math.sin(clockT * 6) : 1; });
  const gl = Math.max(MS.glow, MS.charge * 0.8, MS.heat * 0.6); GLOW_MATS.forEach(m => { m.emissive.setHex(m.userData.base); m.emissiveIntensity = 1 + gl * 1.6 * (0.8 + 0.2 * Math.sin(clockT * 12)); });
  raps.forEach(R => rapPose(R, mdt)); updateShots(mdt);
  for (let i = fx.length - 1; i >= 0; i--) { const e = fx[i]; const fdt = mdt * (hitStop > 0 ? 0.2 : 1); e.t += fdt; const u = Math.min(1, e.t / e.life); e.update(e.obj, u, fdt); if (u >= 1) { scene.remove(e.obj); fx.splice(i, 1); } }
  if (noRender) return;
  shake = Math.max(0, shake - dt * 4.2); fovPunch = Math.max(0, fovPunch - dt * 14);
  const fr = tr0.frameFn ? tr0.frameFn(play.t) : tr0.frame;
  const mid = fr[0].clone().lerp(fr[1], 0.5).setY(9 + (mo ? mo.y * 0.7 : 0)), span = fr[0].distanceTo(fr[1]) + 30;
  const hfov = 2 * Math.atan(Math.tan(rad(cam.fov / 2)) * cam.aspect), vfit = span * 0.5 / Math.tan(hfov / 2);
  let cp, look = mid;
  if (camMode === "hero") cp = mid.clone().add(V3(1, 0.42, 0.12).normalize().multiplyScalar(vfit * 1.08));
  else if (camMode === "side") cp = mid.clone().add(V3(1, 0.14, 0).normalize().multiplyScalar(vfit * 1.1));
  else if (camMode === "game") { const f = fwdOf(dilo.yaw); cp = dilo.pos.clone().add(V3(0, 30 + (mo ? mo.y : 0), 0)).addScaledVector(f, -44).add(V3(10, 0, 0)); look = dilo.pos.clone().add(V3(0, 8 + (mo ? mo.y : 0), 0)).addScaledVector(f, 26); }
  else { const c = V3(); let n = 0; for (const p of MECH) if (p.mesh.visible) { c.add(_c.setFromMatrixPosition(p.mesh.matrix)); n++; } if (!n) c.copy(partPoint(mouthParts.skull)); else c.divideScalar(n); cp = c.clone().add(V3(17, 6, 5)); look = c; }
  const fol = !!mo || camMode === "part"; camPos.lerp(cp, fol ? 0.3 : 0.15); camLook.lerp(look, fol ? 0.35 : 0.2);
  const off = camPos.clone().sub(camLook); off.applyAxisAngle(UPV, view.yaw); const side = off.clone().cross(UPV).normalize(); const el = Math.atan2(off.y, Math.hypot(off.x, off.z));
  const pitch = Math.max(-el + 0.05, Math.min(1.45 - el, view.pitch)); off.applyAxisAngle(side, -pitch); off.multiplyScalar(view.zoom);
  const sh = shake * shake; cam.position.copy(camLook).add(off).add(V3(rnd(sh / 2), rnd(sh / 2), rnd(sh / 2)));
  cam.lookAt(camLook); cam.fov = 38 + fovPunch; cam.updateProjectionMatrix();
  sun.position.copy(mid).add(V3(30, 70, 30)); sun.target.position.copy(mid);
  renderer.render(scene, cam);
}
function seek(t) { start(); const sp = speed; speed = 1; let n = 0; while (play.t < t - 1e-6 && n < 3000) { step(1 / 60, true); n++; } speed = sp; step(0); }
const LENF = () => play.track.len;

// ---------- UI ----------
function optList() { const id = TAB().id; return id === "mob" ? MOBO.map(o => ({k: o.k, label: o.name, sub: o.kind, rec: o.rec})) : ["N", "A", "B", "C"].map(k => ({k, label: k === "N" ? "In the game now" : FAM[k].short, sub: k === "N" ? "for comparison" : FAM[k].name === "Reactor Glow" ? "energy" : FAM[k].name === "Liquid Venom" ? "goo" : "smoke + fire", rec: k !== "N" && REC_FX[id] === k})); }
function renderAll() {
  $("moves").innerHTML = TABS.map((m, i) => `<button class="tab" data-i="${i}" aria-pressed="${i === cur}">${m.name}<small style="color:${AREA[m.area][1]}">${m.id === "mob" ? "Movement" : AREA[m.area][0]} · ${m.id === "mob" ? MOBO.find(o => o.k === pick.mob).name : pick[m.id] === "N" ? "Now" : FAM[pick[m.id]].name}</small></button>`).join("");
  const id = TAB().id, sel = pick[id];
  $("varRow").innerHTML = `<span class="lbl">${id === "mob" ? "Option" : "Effect"}</span>` + optList().map(o => `<button class="var" data-var="${o.k}" aria-pressed="${o.k === sel}">${o.label}${o.rec ? ' <span class="rec">· my pick</span>' : ""}<small>${o.sub}</small></button>`).join("");
  const ph = play.track.phases || []; $("phases").innerHTML = ph.map(p => `<button class="ph" data-t="${p[0]}" aria-current="false"><i>${p[0].toFixed(2)}–${p[1].toFixed(2)} s</i>${p[2]}</button>`).join("");
  if (id === "mob") { const o = MOBO.find(x => x.k === sel);
    $("info").innerHTML = `<div class="kind" style="color:var(--yellow)">Mobility · ${o.kind}${o.rec ? ' <span class="rec">my pick</span>' : ""}</div><h2>${o.name}</h2><p>${o.one}</p>
      <div class="tw"><table class="cmp"><tr><th></th><th>Now</th><th>${o.name}</th></tr>${o.nums.map(r => `<tr><th>${r[0]}</th><td>${r[1]}</td><td>${r[2]}</td></tr>`).join("")}</table></div>
      <h3>What you see</h3><ul>${ph.map(p => `<li>${p[2]}</li>`).join("")}</ul><p class="note"><b>Effects:</b> ${o.fx}</p><h3>Built in Roblox from</h3><p class="note">${o.roblox}</p>`;
    $("part").innerHTML = `<div class="kind">All mobility options</div><div class="tw"><table class="cmp"><tr><th>Option</th><th>Kind</th></tr>${MOBO.map(x => `<tr class="${x.k === sel ? "cur" : ""}"><th>${x.name}${x.rec ? " ★" : ""}</th><td>${x.kind}</td></tr>`).join("")}</table></div>
      <h3>Measured in Studio today</h3><ul><li>The Dilo runs 50.7 studs/s, the same as the Raptor (both 78 × the arena speed scale 0.65).</li><li>Its leap winds up ~0.3 s (Raptor 0.12 s), then flies 0.6 s at 64.5 studs/s (~39 studs, ~9 high): only ~8 studs more than running.</li><li>It turns at 360°/s (Raptor 540°/s) and has no Pounce; the Raptor's Thrusters cover ~187 studs, Spring Jets 65.</li></ul>
      <p class="note">★ = my picks: <b>Cobra Spring</b> for every Dilo (it fixes the measured gaps, numbers only) + <b>Tail Thrusters</b> as the part (your idea; proven on the Raptor). The see-through dino is <b>today's Dilo</b> doing the same input. You can pick any mix.</p>`;
    return; }
  const P = PARTS.find(m => m.id === id), fam = FAM[sel];
  $("info").innerHTML = `<div class="kind" style="color:${AREA[P.area][1]}">${AREA[P.area][0]} · ${P.name} · ${sel === "N" ? "in the game now" : "effect " + sel}${REC_FX[id] === sel ? ' <span class="rec">my pick</span>' : ""}</div><h2>${sel === "N" ? "In the game now" : fam.name}</h2>
    <p>${sel === "N" ? fam.one : LINE[id][sel]}</p><h3>Wind-up → action → result → recovery</h3><ul>${ph.map(p => `<li>${p[2]}</li>`).join("")}</ul>
    ${sel === "N" ? "" : `<h3>The family</h3><p class="note">${fam.one}</p><h3>Built in Roblox from</h3><p class="note">${fam.roblox}</p>`}`;
  $("part").innerHTML = `<div class="kind">All ${P.name} options</div><div class="tw"><table class="cmp"><tr><th>Option</th><th>Look</th></tr>${["N", "A", "B", "C"].map(k => `<tr class="${k === sel ? "cur" : ""}"><th>${k === "N" ? "Now" : k}${REC_FX[id] === k ? " ★" : ""}</th><td>${k === "N" ? FAM.N.one : LINE[id][k]}</td></tr>`).join("")}</table></div>
    <h3>Cost</h3><ul>${["A", "B", "C"].map(k => `<li><b>${k}</b> ${FAM[k].cost}</li>`).join("")}</ul><p class="note"><b>Maxed out:</b> ${P.max} The part model is the one in the game; only its effects and motion change. ${id === "mortar" ? "Shown at 50 studs (it reaches 120 at max) so it fits the view. " : ""}★ = my pick: one family (B) on all 7 keeps the Dilo consistent and glows read on a phone; you can mix families per part.</p>`;
}
$("moves").addEventListener("click", e => { const b = e.target.closest("[data-i]"); if (!b) return; cur = +b.dataset.i; view.zoom = TAB().id === "mob" ? 1 : 0.72; view.yaw = 0; view.pitch = 0; start(); renderAll(); });
$("varRow").addEventListener("click", e => { const b = e.target.closest("[data-var]"); if (!b) return; pick[TAB().id] = b.dataset.var; start(); renderAll(); });
$("phases").addEventListener("click", e => { const b = e.target.closest("[data-t]"); if (!b) return; seek(+b.dataset.t + 0.06); playing = false; syncPlay(); });
$("play").onclick = () => { playing = !playing; syncPlay(); };
function syncPlay() { $("play").textContent = playing ? "Pause" : "Play"; $("play").setAttribute("aria-pressed", playing); }
document.querySelectorAll("[data-speed]").forEach(b => b.onclick = () => { speed = +b.dataset.speed; document.querySelectorAll("[data-speed]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => { camMode = b.dataset.view; document.querySelectorAll("[data-view]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
$("zin").onclick = () => { view.zoom = Math.max(0.25, view.zoom / 1.25); }; $("zout").onclick = () => { view.zoom = Math.min(3, view.zoom * 1.25); }; $("zreset").onclick = () => { view.zoom = TAB().id === "mob" ? 1 : 0.72; view.yaw = 0; view.pitch = 0; };
(function orbit() { const pts = new Map(); let pinch0 = 0, zoom0 = 1;
  cv.addEventListener("pointerdown", e => { cv.setPointerCapture(e.pointerId); pts.set(e.pointerId, {x: e.clientX, y: e.clientY}); if (pts.size === 2) { const [a, b] = [...pts.values()]; pinch0 = Math.hypot(a.x - b.x, a.y - b.y); zoom0 = view.zoom; } });
  cv.addEventListener("pointermove", e => { if (!pts.has(e.pointerId)) return; const p = pts.get(e.pointerId); const dx = e.clientX - p.x, dy = e.clientY - p.y; p.x = e.clientX; p.y = e.clientY;
    if (pts.size === 1) { view.yaw -= dx * 0.008; view.pitch = Math.max(-1.2, Math.min(1.2, view.pitch + dy * 0.006)); } else if (pts.size === 2 && pinch0) { const [a, b] = [...pts.values()]; view.zoom = Math.max(0.25, Math.min(3, zoom0 * pinch0 / Math.max(1, Math.hypot(a.x - b.x, a.y - b.y)))); } });
  const up = e => { pts.delete(e.pointerId); if (pts.size < 2) pinch0 = 0; }; cv.addEventListener("pointerup", up); cv.addEventListener("pointercancel", up);
  cv.addEventListener("wheel", e => { e.preventDefault(); view.zoom = Math.max(0.25, Math.min(3, view.zoom * (e.deltaY > 0 ? 1.1 : 1 / 1.1))); }, {passive: false}); })();
$("scrub").addEventListener("input", e => { seek(+e.target.value / 1000 * LENF()); playing = false; syncPlay(); });
$("ver").textContent = "v" + VFX_VERSION;
function resize() { const w = cv.clientWidth, h = cv.clientHeight; if (renderer.domElement.width !== Math.round(w * renderer.getPixelRatio())) { renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); } }
window.addEventListener("resize", resize);
let last = performance.now();
function loop(now) { const dt = Math.min(0.05, (now - last) / 1000); last = now; resize();
  if (playing && !window.__manual) { step(dt); if (play.t >= LENF()) { start(); } } else if (!window.__manual) step(0);
  $("scrub").value = Math.round(Math.min(1, play.t / LENF()) * 1000);
  $("clock").textContent = `${play.t.toFixed(2)} s${speed !== 1 ? " · 0.3×" : ""}` + (mobInfo ? ` · NEW ${Math.round(mobInfo.n)} studs · NOW ${Math.round(mobInfo.g)}` : "");
  const ph = (play.track.phases || []).find(p => play.t >= p[0] && play.t < p[1]); $("cap").textContent = ph ? ph[2] : "…";
  document.querySelectorAll(".ph").forEach(b => b.setAttribute("aria-current", !!ph && +b.dataset.t === ph[0]));
  requestAnimationFrame(loop); }
start(); renderAll(); resize(); requestAnimationFrame(loop);
window.__vfx = {set(tab, opt, time, cm, zoom) { window.__manual = true; cur = TABS.findIndex(m => m.id === tab); if (opt) pick[tab] = opt; if (cm) camMode = cm; view.yaw = 0; view.pitch = 0; view.zoom = zoom || (tab === "mob" ? 1 : 0.72); camPos.set(60, 26, -20); start(); renderAll(); seek(time); for (let i = 0; i < 40; i++) step(0); },
  state: () => ({t: play.t, fx: fx.length, shots: shots.length, mob: mobInfo}), view};
window.__ready = true;
