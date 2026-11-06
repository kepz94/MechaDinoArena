// dilo_moves_anim.js v0.1 (Mecha Dino Arena) — the Dilo animation pass (Kepu 2026-11-05 22:14 "Next" -> Dilo -> "Moves
// animation pass"). Engine = tools/dilo_kit_mockup/app.js (scene, rigs, springs, FX, projectiles; prepended by the build up
// to its "moves" section). Seven moves, each Now (as the game plays it, v476) + A / B / C, every one wind-up -> action ->
// result -> recovery. Numbers are the game's (DiloModelData 1.3, DiloAttackServer 1.3, SkillTree 1.60 dilo rows) at scale 2.
const ANIM_VERSION = "0.1";

// ---------- shared state + helpers ----------
const R0 = raps[0], R1 = raps[1];
function place(R, x, z, yaw) { R.show = true; R.pos.set(x, 0, z); R.yaw = yaw; R.path = null; R.run = 0; }
const LEAP = {T0: 0.28, AIR: 0.72, DIST: 30, H: 10};
let leapCfg = LEAP;
function leapOffset(t) {
  const u = (t - leapCfg.T0) / leapCfg.AIR;
  if (u <= 0) return {fwd: 0, up: 0, air: false};
  if (u >= 1) return {fwd: leapCfg.DIST, up: 0, air: false};
  let up = 4 * leapCfg.H * u * (1 - u);
  if (leapCfg.hang) up += leapCfg.hang * Math.max(0, Math.sin(Math.PI * Math.min(1, Math.max(0, (u - 0.3) / 0.4))));
  return {fwd: leapCfg.DIST * (u * 0.8 + E.out(u) * 0.2), up, air: true};
}
const aim = {on: 0, R: null, cone: null, yaw: 0};
function aimAt(R, cone, on) { aim.R = R; aim.cone = cone; aim.on = on; }
let hitStop = 0, shake = 0, clockT = 0, idleT = 0, fovPunch = 0;
const frill = {open: false, t: 9};
function vig(color, a) { const v = $("vig"); v.style.transition = "none"; v.style.background = `radial-gradient(ellipse at center, transparent 55%, ${color} 100%)`; v.style.opacity = a; requestAnimationFrame(() => { v.style.transition = "opacity .4s"; v.style.opacity = 0; }); }
function biteHit(R, p, n, big) {
  hitStop = 0.08; shake = Math.max(shake, big ? 1 : 0.8); fovPunch = 2; flash(p, 10); sparks(p, new THREE.Vector3(0, 0.3, -1), 14);
  numberPop(p.clone().add(new THREE.Vector3(0, 5, 0)), n, "hit"); R.flinch = 1; R.side = 1; R.flash = 0.12; R.flashCol = [0.9, 0.1, 0.05]; R.push = 1.2; R.pushDir.set(0, 0, -1);
}
function dartHit(R, p, n, ven, power, style) {
  hitStop = 0.085; shake = Math.max(shake, 0.75); fovPunch = 1.8;
  splash(p, Math.round(26 * power), power);
  numberPop(p.clone().add(new THREE.Vector3(0, 5, 0)), n, "hit");
  R.flinch = 1; R.side = 0; R.flash = 0.14; R.flashCol = [0.35, 0.95, 0.15]; R.push = 1.4; R.pushDir.copy(p).sub(dilo.pos).setY(0).normalize();
  if (ven) venomOn(R, ven.rate, ven.dur, style || "now");
}
function venomOn(R, rate, dur, style) { R.venom = {left: dur, rate, next: 0.5, drip: 0, style, age: 0}; }
const headOf = R => partPoint(R.rig.segs.Head[0]);
// extra FX
const T_BUB = radialTex("rgba(230,255,190,0.15)", "rgba(120,220,60,0)", 0.75);
function bubble(p, size) { const s = sprite(T_DROP, 0xc8ff8a, size, false); s.position.copy(p); const v = new THREE.Vector3((Math.random() - .5) * 2, 4 + Math.random() * 3, (Math.random() - .5) * 2);
  addFx(s, 0.7 + Math.random() * 0.3, (o, u, dt) => { o.position.addScaledVector(v, dt); o.scale.setScalar(size * (0.5 + u * 0.9)); o.material.opacity = u > 0.85 ? 0 : 0.85; if (u > 0.85 && !o.userData.pop) { o.userData.pop = 1; flash(o.position.clone(), size * 1.2, 0xd8ffb0); } }); }
function mote(from, toFn, life, color, onArrive) {
  const s = sprite(T_DROP, color, 2.2, true); s.position.copy(from); const mid = from.clone().lerp(toFn(), 0.5).add(new THREE.Vector3((Math.random() - .5) * 6, 8, (Math.random() - .5) * 6));
  addFx(s, life, (o, u) => { const to = toFn(); const a = from.clone().lerp(mid, u), b = mid.clone().lerp(to, u); o.position.copy(a.lerp(b, u)); o.scale.setScalar(2.2 * (1 - u * 0.4)); if (u >= 1 && !o.userData.done) { o.userData.done = 1; onArrive && onArrive(to); } }); }
function groundRing(center, r1, color, life, thick) {
  const m = new THREE.Mesh(new THREE.RingGeometry(0.86, 1, 56), new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0.8, depthWrite: false, side: THREE.DoubleSide}));
  m.rotation.x = -Math.PI / 2; m.position.copy(center).setY(0.15);
  addFx(m, life, (o, u) => { const r = 1 + (r1 - 1) * E.out(u); o.scale.setScalar(r); o.material.opacity = 0.8 * (1 - u); });
}
function spine(p, dir, len) { const g = new THREE.Mesh(new THREE.ConeGeometry(0.25, len, 6), new THREE.MeshLambertMaterial({color: 0x9cf05a, emissive: 0x2d7a10})); g.position.copy(p);
  g.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir.clone().normalize()); const v = dir.clone().normalize().multiplyScalar(60);
  addFx(g, 0.32, (o, u, dt) => { o.position.addScaledVector(v, dt); o.material.transparent = true; o.material.opacity = 1 - u * u; }); }
function puff(p, v, size, color, life) { const s = sprite(T_MIST, color || 0xffffff, size, false); s.position.copy(p);
  addFx(s, life || 0.6, (o, u, dt) => { o.position.addScaledVector(v, dt); o.scale.setScalar(size * (1 + u * 2.4)); o.material.opacity = 0.7 * (1 - u); }); }
let mouthGlow = null;
function glowAtMouth(on, color, k) {
  if (!mouthGlow) { mouthGlow = sprite(T_FLASH, 0xb8ff70, 4, true); scene.add(mouthGlow); }
  mouthGlow.visible = on; if (!on) return; mouthGlow.material.color.setHex(color || 0xb8ff70); mouthGlow.position.copy(mouthPoint()); mouthGlow.scale.setScalar(3 + (k || 1) * 2.5 * (0.8 + 0.2 * Math.sin(clockT * 30)));
}
const HPTAG = {obj: null};
function hpTag(text, color) { HPTAG.obj = textTag(dilo.pos.clone().add(new THREE.Vector3(6, 29, 0)), text, color, 1.6); }

// extra key poses (degrees {p, y, r}; + = rear back / nose up for RootJoint / Neck / Head; Jaw - = open; Tail - = lift)
const C_BITE2 = addPose(C_BITE, {Neck: [6, 0, 0]}, 1);
const C_COIL2 = addPose(C_COIL, {Neck: [3, 0, 0], Head: [-2, 0, 0]}, 1);
const C_DART2 = addPose(C_DART, {Neck: [-4, 0, 0]}, 1);
const DRAW = BOTH({RootJoint: [6, 0, 0], Neck: [26, 0, 0], Head: [-18, 0, 0], Jaw: [-6, 0, 0], ArmL: [-12, 0, 0], root: {fwd: -1.2}});
const CLAMP = addPose(C_BITE, {Jaw: [2, 0, 0], root: {fwd: 0.6}}, 1);
const SNAP_SIDE = Object.assign(BOTH({RootJoint: [-10, 0, 0], Neck: [-30, 16, 0], Head: [-2, 8, 0], Jaw: [3, 0, 0], ArmL: [16, 0, 0], root: {fwd: 2.2}}), {});
const LUNGE_LOAD = BOTH({RootJoint: [-10, 0, 0], Neck: [-6, 0, 0], Head: [8, 0, 0], Jaw: [-30, 0, 0], ArmL: [-10, 0, 0], LegL: [26, 0, 0], KneeL: [-48, 0, 0], AnkleL: [20, 0, 0], Tail1: [-10, 0, 0], Tail2: [-6, 0, 0], root: {fwd: -1}});
const LUNGE = Object.assign(BOTH({RootJoint: [-18, 0, 0], Neck: [-26, 0, 0], Head: [2, 0, 0], Jaw: [3, 0, 0], ArmL: [26, 0, 0], Tail1: [-16, 0, 0], Tail2: [-8, 0, 0], root: {fwd: 5.2}}), {LegL: [-30, 0, 0], LegR: [24, 0, 0], KneeL: [-6, 0, 0], KneeR: [-30, 0, 0], AnkleL: [-14, 0, 0]});
const FLARE_COIL = addPose(C_COIL, {Neck: [6, 0, 0], Head: [-4, 0, 0], Jaw: [-10, 0, 0]}, 1);
const THRUST = addPose(C_DART, {Neck: [-8, 0, 0], root: {fwd: 0.8}}, 1);
const RECOIL = addPose(C_DART, {RootJoint: [10, 0, 0], Neck: [10, 0, 0], root: {fwd: -1.6}}, 1);
const REAR_UP = BOTH({RootJoint: [16, 0, 0], Neck: [40, 0, 0], Head: [-34, 0, 0], Jaw: [-10, 0, 0], ArmL: [-20, 0, 0], LegL: [-6, 0, 0], KneeL: [6, 0, 0], Tail1: [10, 0, 0], Tail2: [6, 0, 0], root: {fwd: -1.5}});
const WHIP_DOWN = Object.assign(BOTH({RootJoint: [-12, 0, 0], Neck: [-30, 0, 0], Head: [-10, 0, 0], Jaw: [-38, 0, 0], ArmL: [18, 0, 0], Tail1: [-12, 0, 0], root: {fwd: 2.2}}), {LegL: [-6, 0, 0], LegR: [12, 0, 0], KneeR: [-14, 0, 0]});
const SNIPE = BOTH({RootJoint: [-10, 0, 0], Neck: [-18, 0, 0], Head: [12, 0, 0], Jaw: [-4, 0, 0], ArmL: [-6, 0, 0], LegL: [22, 0, 0], KneeL: [-40, 0, 0], AnkleL: [16, 0, 0], Tail1: [-6, 0, 0], Tail2: [-2, 0, 0], root: {fwd: -0.4}});
const SNIPE_SHOT = addPose(SNIPE, {Jaw: [-30, 0, 0], Neck: [-4, 0, 0], root: {fwd: 0.4}}, 1);
const SNIPE_KICK = addPose(SNIPE, {RootJoint: [8, 0, 0], Neck: [14, 0, 0], Head: [-6, 0, 0], Jaw: [-20, 0, 0], root: {fwd: -1.8}}, 1);
const J_DEEP = addPose(J_CROUCH, {Neck: [10, 0, 0], Head: [-6, 0, 0], KneeL: [-10, 0, 0], KneeR: [-10, 0, 0], Tail1: [6, 0, 0], Tail2: [6, 0, 0], Tail3: [4, 0, 0]}, 1);
const J_STRETCH = BOTH({RootJoint: [-14, 0, 0], Neck: [-18, 0, 0], Head: [6, 0, 0], Jaw: [-14, 0, 0], ArmL: [30, 0, 0], LegL: [-40, 0, 0], KneeL: [-2, 0, 0], AnkleL: [-30, 0, 0], Tail1: [-6, 0, 0]});
const J_SOAR = BOTH({RootJoint: [-6, 0, 0], Neck: [10, 0, 0], Head: [-10, 0, 0], Jaw: [-8, 0, 0], ArmL: [10, 0, -40], LegL: [6, 0, 0], KneeL: [-30, 0, 0], AnkleL: [10, 0, 0], Tail1: [-6, 0, 0], Tail2: [-4, 0, 0]});
const J_TAILPRESS = addPose(J_CROUCH, {Tail1: [18, 0, 0], Tail2: [12, 0, 0], Tail3: [8, 0, 0]}, 1);
const J_TAILWHIP = addPose(J_PUSH, {Tail1: [-26, 0, 0], Tail2: [-18, 0, 0], Tail3: [-10, 0, 0]}, 1);
const J_SOFTLAND = addPose(J_LAND, {KneeL: [-12, 0, 0], KneeR: [-12, 0, 0], Neck: [6, 0, 0]}, 1);
const HIT_REACT = BOTH({RootJoint: [8, 0, 0], Neck: [16, -10, 0], Head: [6, 0, 0], Jaw: [-20, 0, 0], ArmL: [-14, 0, 0], root: {fwd: -1.2}});
const HISS = BOTH({RootJoint: [6, 0, 0], Neck: [22, 0, 0], Head: [-14, 0, 0], Jaw: [-42, 0, 0], ArmL: [-16, 0, 0], root: {fwd: -0.8}});
const LICK = BOTH({Jaw: [-18, 0, 0], Head: [-6, 0, 0]});
const SHIVER = t => ({RootJoint: [0, 0, 6 * Math.sin(t * 50)], Neck: [0, 10 * Math.sin(t * 50 + 1), 0], Head: [0, 8 * Math.sin(t * 50 + 2), 0], Tail1: [0, -8 * Math.sin(t * 50 + 1), 0], Tail2: [0, -10 * Math.sin(t * 50 + 2), 0]});
const K = (t, pose, e) => ({t, pose, e});

// common setups
function setBiteTarget() { place(R0, -1.5, -21.5, 0); R0.yaw = yawTo(R0.pos, dilo.pos); R1.show = false; }
function setFarTarget() { place(R0, -6, -40, 0); R0.yaw = yawTo(R0.pos, dilo.pos) - 0.9; place(R1, 24, -20, 0); R1.yaw = yawTo(R1.pos, dilo.pos) + 0.6; }
function biteKeys(t0) { t0 = t0 || 0; return [K(t0, READY), K(t0 + 0.1, C_BWIND, "io"), K(t0 + 0.17, C_BITE, "in2"), K(t0 + 0.32, C_BITE2, "out")]; }
const BITE_NOW_EV = (t0) => ({t: (t0 || 0) + 0.18, f: () => biteHit(R0, headOf(R0).add(new THREE.Vector3(0, 0, 1)), 10)});
function fireDart(opts) { const from = mouthPoint(); spawnShot(Object.assign({kind: "dart", from, target: () => rapChest(R0), T: 0.44, H: 0.4,
  onHit: p => { dartHit(R0, p, opts && opts.dmg || 6, {rate: 2, dur: 3}, 0.75, opts && opts.style); aim.on = 0; }}, opts || {})); }

// ---------- the moves ----------
// Each version: name, sub, len (s), timing (one line), ref, notes, phases [[t0, t1, text]], rec, build() -> track:
//   {keys, frill [[a, b]], frillMul, sac [[a, b]], tremble [a, b], leap cfg, ev [{t, f}], update(t, dt), frame [p, p], tint(t)}
const VM = {};
VM.bite = {
  now: {name: "Now", sub: "as the game plays it (v476)", len: 1.6, timing: "hit 0.18 s after the press",
    ref: "DiloPose 1.0 bite: a 0.1 s jaw-open draw, a neck snap, the hit at 0.18 s (DiloAttackServer DiloBiteDelay).",
    phases: [[0, 0.1, "Jaw opens, the neck pulls back a little"], [0.1, 0.18, "Snaps forward"], [0.18, 0.32, "Hit · 10"], [0.32, 1.6, "Settles back"]],
    notes: ["The draw is 0.1 s and small: it reads as a twitch, not a strike.", "The frill stays folded, so nothing says 'this dino is about to bite'."],
    build() { setBiteTarget(); return {frame: [new THREE.Vector3(0, 0, 0), R0.pos.clone()], keys: [...biteKeys(), K(0.7, READY, "io")], ev: [BITE_NOW_EV()]}; }},
  A: {name: "A · Cobra Strike", sub: "hood flares, strike, clamp and shake", len: 1.8, rec: true, timing: "hit 0.18 s after the press (as now)",
    ref: "King cobra: the hood flares and the head draws back before the strike; elapids hang on and bite again (2024 high-speed strike study).",
    phases: [[0, 0.1, "Hood flares, the head draws back in an S"], [0.1, 0.18, "Strikes"], [0.18, 0.42, "Hit · 10 · clamps on and shakes its head"], [0.42, 1.8, "Lets go, the hood folds"]],
    notes: ["The hood flare is the tell, for you and for whoever is in front of it.", "The clamp + head shake makes the hit land.", "Timing, damage and reach unchanged."],
    build() { setBiteTarget(); return {frame: [new THREE.Vector3(0, 0, 0), R0.pos.clone()], frill: [[0.01, 0.5]],
      keys: [K(0, READY), K(0.1, DRAW, "io"), K(0.17, addPose(C_BITE, {root: {fwd: 0.6}}, 1), "in2"), K(0.24, CLAMP, "out"), K(0.42, CLAMP, "io"), K(0.6, C_BITE2, "io"), K(1.0, READY, "io")],
      ev: [BITE_NOW_EV(), {t: 0.3, f: () => { const p = headOf(R0); sparks(p, new THREE.Vector3(0, 0.4, -1), 6); R0.flinch = Math.max(R0.flinch, 0.7); shake = Math.max(shake, 0.35); }}],
      update(t) { if (t > 0.2 && t < 0.42) { const w = Math.sin((t - 0.2) * 55) * 12 * (1 - (t - 0.2) / 0.22); this._shake = w; } else this._shake = 0; },
      extra(target) { if (this._shake) { target.Neck = target.Neck.map((v, i) => i === 1 ? v + this._shake : v); target.Head = target.Head.map((v, i) => i === 1 ? v + this._shake * 0.6 : v); } }}; }},
  B: {name: "B · Double Snap", sub: "snap, snap — the first one hits", len: 1.8, timing: "hit 0.18 s after the press (as now); 2nd snap is a look only",
    ref: "Monster Hunter's Great Jagras / Kulu-Ya-Ku quick double bites; elapids biting more than once.",
    phases: [[0, 0.1, "Jaw opens"], [0.1, 0.18, "First snap"], [0.18, 0.26, "Hit · 10"], [0.26, 0.38, "Second snap (no extra damage)"], [0.38, 1.8, "Settles"]],
    notes: ["Feels fast and aggressive; reads well on a phone screen.", "The 2nd snap does no damage: it could look like a missed hit."],
    build() { setBiteTarget(); return {frame: [new THREE.Vector3(0, 0, 0), R0.pos.clone()],
      keys: [...biteKeys(), K(0.26, C_BWIND, "io"), K(0.33, SNAP_SIDE, "in2"), K(0.45, addPose(SNAP_SIDE, {Neck: [6, 0, 0]}, 1), "out"), K(0.9, READY, "io")],
      ev: [BITE_NOW_EV(), {t: 0.34, f: () => { const p = headOf(R0).add(new THREE.Vector3(1, 0, 1)); flash(p, 6); shake = Math.max(shake, 0.4); R0.flinch = Math.max(R0.flinch, 0.6); }}]}; }},
  C: {name: "C · Lunge Bite", sub: "the whole body throws itself in", len: 1.8, timing: "hit 0.18 s after the press (as now)",
    ref: "Komodo dragon ambush lunge: body low, then the whole animal drives forward behind the jaws.",
    phases: [[0, 0.12, "Drops low, jaw wide, tail up"], [0.12, 0.18, "Lunges with the whole body"], [0.18, 0.38, "Hit · 10"], [0.38, 1.8, "Steps back up"]],
    notes: ["Shows the 5-stud reach: the body really travels to the target.", "Heaviest look; feels slower than A even at the same timing."],
    build() { setBiteTarget(); return {frame: [new THREE.Vector3(0, 0, 0), R0.pos.clone()],
      keys: [K(0, READY), K(0.12, LUNGE_LOAD, "io"), K(0.18, LUNGE, "in2"), K(0.38, LUNGE, "out"), K(1.0, READY, "io")], ev: [BITE_NOW_EV()]}; }},
};
const REL = 0.9; // the spit release in the dart tracks (the press at 0 still bites, as in the game)
VM.dart = {
  now: {name: "Now", sub: "as the game plays it (v476)", len: 3.2, timing: "hold 0.4 s, spit on release",
    ref: "DiloPose 1.0 coil / armed / spit; DiloFX 1.1 dart. Only your own screen shows the coil (others see the spit).",
    phases: [[0, 0.15, "Press: the bite snaps"], [0.15, 0.4, "Neck coils into an S, frill opens, sac swells"], [0.4, REL, "Armed: a small tremble"], [REL, REL + 0.44, "Let go: spit dart"], [REL + 0.44, 3.2, "Splash · 6 + venom 2/s for 3 s"]],
    notes: ["Other players never see the coil: to them the spit comes out of nowhere.", "'Armed' is only a small tremble: hard to tell the dart is ready."],
    build() { setFarTarget(); return {frame: [new THREE.Vector3(0, 0, 0), R0.pos.clone()],
      keys: [...biteKeys(), K(0.45, C_COIL, "io"), K(REL - 0.02, C_COIL2, "io"), K(REL + 0.05, C_DART, "in2"), K(REL + 0.25, C_DART2, "out"), K(REL + 0.8, READY, "io")],
      frill: [[0.15, REL + 0.75]], sac: [[0.15, REL + 0.05]], tremble: [0.4, REL],
      ev: [{t: 0.4, f: () => aimAt(R0, aimCone.C, 1)}, {t: REL, f: () => fireDart()}]}; }},
  A: {name: "A · Hood Flare", sub: "full hood, pumping sac, glowing mouth", len: 3.4, rec: true, timing: "hold 0.4 s, spit on release (as now)",
    ref: "ARK's Dilophosaur: it stands still, raises its frill and pulls its head back before it spits; Jurassic Park's dilophosaur hood.",
    phases: [[0, 0.15, "Press: the bite snaps"], [0.15, 0.4, "Hood flares wide with a rattle, the sac pumps"], [0.4, REL, "Armed: the mouth glows green"], [REL, REL + 0.12, "Thrusts the head, then rocks back with the recoil"], [REL + 0.12, 3.4, "Dart + a spray of droplets · splash · hood folds"]],
    notes: ["Everyone can read 'armed': full hood + green mouth.", "Game change: other players see the coil too (the server stamps it).", "Hold time, damage and range unchanged."],
    build() { setFarTarget(); return {frame: [new THREE.Vector3(0, 0, 0), R0.pos.clone()], frillMul: 1.25,
      keys: [...biteKeys(), K(0.42, FLARE_COIL, "io"), K(REL - 0.02, addPose(FLARE_COIL, {Neck: [3, 0, 0]}, 1), "io"), K(REL + 0.05, THRUST, "in2"), K(REL + 0.18, RECOIL, "out"), K(REL + 0.9, READY, "io")],
      frill: [[0.15, REL + 0.8]], sac: [[0.18, 0.3], [0.42, 0.54], [0.66, 0.78], [REL - 0.1, REL + 0.05]], tremble: [0.4, REL],
      ev: [{t: 0.4, f: () => aimAt(R0, aimCone.C, 1)}, {t: REL, f: () => { fireDart(); const m = mouthPoint(), d = headDir();
        for (let i = 0; i < 9; i++) droplet(m.clone(), d.clone().multiplyScalar(30 + Math.random() * 20).add(new THREE.Vector3((Math.random() - .5) * 14, 4 + Math.random() * 6, (Math.random() - .5) * 14)), 0.9, 0.45, 40); }}],
      update(t) { glowAtMouth(t > 0.4 && t < REL + 0.05, 0xb8ff70, 1); }}; }},
  B: {name: "B · Rear & Spit", sub: "rears up tall, whips down to spit", len: 3.4, timing: "hold 0.4 s, spit on release (as now)",
    ref: "Spitting cobras rear up and aim for the eyes before they spray.",
    phases: [[0, 0.15, "Press: the bite snaps"], [0.15, 0.4, "Rears up tall, hood open"], [0.4, REL, "Armed: sways at the top"], [REL, REL + 0.15, "Whips down: spit"], [REL + 0.15, 3.4, "Dart dives at the target · splash"]],
    notes: ["Tall and readable from far away.", "The rear-up hides the head behind the hood from the player camera."],
    build() { setFarTarget(); return {frame: [new THREE.Vector3(0, 0, 0), R0.pos.clone()],
      keys: [...biteKeys(), K(0.45, REAR_UP, "io"), K(REL - 0.02, addPose(REAR_UP, {Neck: [4, 0, 0]}, 1), "io"), K(REL + 0.06, WHIP_DOWN, "in2"), K(REL + 0.25, addPose(WHIP_DOWN, {Neck: [-4, 0, 0]}, 1), "out"), K(REL + 0.9, READY, "io")],
      frill: [[0.15, REL + 0.75]], sac: [[0.15, REL + 0.05]], sway: [0.42, REL],
      ev: [{t: 0.4, f: () => aimAt(R0, aimCone.C, 1)}, {t: REL, f: () => fireDart({H: -1.2})}]}; }},
  C: {name: "C · Sniper Crouch", sub: "drops low, locks still, snap + kick", len: 3.4, timing: "hold 0.4 s, spit on release (as now)",
    ref: "An archerfish / chameleon: it locks on and goes dead still, then fires all at once.",
    phases: [[0, 0.15, "Press: the bite snaps"], [0.15, 0.4, "Drops low, neck stretched flat at the target"], [0.4, REL, "Armed: dead still, a thin green line to the target"], [REL, REL + 0.1, "Snap: spit"], [REL + 0.1, 3.4, "Kicks back from the recoil · splash"]],
    notes: ["The aim line shows exactly who will be hit.", "Low and quiet: less of a show than A."],
    build() { setFarTarget(); return {frame: [new THREE.Vector3(0, 0, 0), R0.pos.clone()],
      keys: [...biteKeys(), K(0.42, SNIPE, "io"), K(REL - 0.02, SNIPE, "io"), K(REL + 0.04, SNIPE_SHOT, "in2"), K(REL + 0.16, SNIPE_KICK, "out"), K(REL + 0.9, READY, "io")],
      frill: [[REL - 0.05, REL + 0.6]], sac: [[REL - 0.1, REL + 0.05]],
      ev: [{t: 0.4, f: () => aimAt(R0, aimCone.C, 1)}, {t: REL, f: () => fireDart({T: 0.38})}]}; }},
};
function leapTrack(cfg, keys, frill, extra) { R0.show = false; R1.show = false; leapCfg = cfg; return Object.assign({frame: [new THREE.Vector3(0, 0, 4), new THREE.Vector3(0, 0, -cfg.DIST - 4)], leap: cfg, keys, frill}, extra || {}); }
const t1 = LEAP.T0 + LEAP.AIR;
VM.leap = {
  now: {name: "Now", sub: "as the game plays it (v476)", len: 2.3, timing: "crouch 0.28 s, ~0.72 s in the air",
    ref: "DiloPose 1.0 Cobra Leap: crouch with the neck coiled, push, tuck, plain landing (house rule: no landing FX).",
    phases: [[0, LEAP.T0, "Crouch, the neck coils, the frill flares"], [LEAP.T0, t1, "Leaps ~30 studs, legs tucked"], [t1, t1 + 0.7, "Plain landing, frill folds"], [t1 + 0.7, 2.3, "Ready"]],
    notes: ["Clear enough, but the push is small: it looks more like a hop than a cobra strike.", "The landing is plain on purpose (no dust / shockwave)."],
    build() { return leapTrack(LEAP, [K(0, READY), K(LEAP.T0, J_CROUCH, "io"), K(LEAP.T0 + 0.1, J_PUSH, "out"), K(LEAP.T0 + 0.3, J_AIR, "io"), K(t1 - 0.14, J_AIR, "io"), K(t1 - 0.02, J_DOWN, "io"), K(t1 + 0.12, J_LAND, "out"), K(t1 + 0.7, READY, "io")], [[0.16, t1 + 0.32]]); }},
  A: {name: "A · Spring Coil", sub: "deep coil, full-body strike, soft catch", len: 2.4, rec: true, timing: "as now",
    ref: "A striking cobra's full-length extension; a jumping spider's launch from a deep crouch.",
    phases: [[0, LEAP.T0, "Deep crouch, the neck and tail coil into an S"], [LEAP.T0, LEAP.T0 + 0.12, "Uncoils: the whole body stretches out like a strike"], [LEAP.T0 + 0.12, t1, "Tucks in the air, frill open"], [t1, t1 + 0.8, "Catches itself low, rises"], [t1 + 0.8, 2.4, "Ready"]],
    notes: ["The stretch sells the 'cobra' in Cobra Leap.", "Same timing and distance; still no landing FX."],
    build() { return leapTrack(LEAP, [K(0, READY), K(LEAP.T0, J_DEEP, "io"), K(LEAP.T0 + 0.08, J_STRETCH, "out5"), K(LEAP.T0 + 0.32, J_AIR, "io"), K(t1 - 0.14, J_AIR, "io"), K(t1 - 0.02, J_DOWN, "io"), K(t1 + 0.14, J_SOFTLAND, "out"), K(t1 + 0.8, READY, "io")], [[0.1, t1 + 0.32]]); }},
  B: {name: "B · Frill Glide", sub: "hood spreads like a sail at the top", len: 2.6, timing: "+0.14 s in the air (game change)",
    ref: "Frilled lizards and Draco gliding lizards spreading their skin flaps.",
    phases: [[0, LEAP.T0, "Crouch, frill flares"], [LEAP.T0, LEAP.T0 + 0.25, "Leaps"], [LEAP.T0 + 0.25, LEAP.T0 + 0.7, "Hood spreads wide, arms out: hangs a moment"], [LEAP.T0 + 0.7, LEAP.T0 + 0.86, "Drops in"], [LEAP.T0 + 0.86, 2.6, "Plain landing"]],
    notes: ["Most playful; the hang gives a beat to aim the next spit.", "Game change: a little more hang time (0.86 s vs 0.72 s)."],
    build() { const C = {T0: 0.28, AIR: 0.86, DIST: 30, H: 10, hang: 2.2}; const e = C.T0 + C.AIR;
      return leapTrack(C, [K(0, READY), K(C.T0, J_CROUCH, "io"), K(C.T0 + 0.1, J_PUSH, "out"), K(C.T0 + 0.3, J_SOAR, "io"), K(e - 0.18, J_SOAR, "io"), K(e - 0.02, J_DOWN, "io"), K(e + 0.12, J_LAND, "out"), K(e + 0.7, READY, "io")], [[0.16, e + 0.25]], {frillMul: 1.45}); }},
  C: {name: "C · Tail Spring", sub: "tail slaps the ground to launch", len: 2.4, timing: "as now",
    ref: "A kangaroo's tail push; a mudskipper flicking itself off the ground with its tail.",
    phases: [[0, LEAP.T0, "Crouch, the tail presses into the ground"], [LEAP.T0, LEAP.T0 + 0.1, "Tail whips up and throws it forward"], [LEAP.T0 + 0.1, t1, "Flies, the tail steers"], [t1, 2.4, "Plain landing"]],
    notes: ["Unusual and readable from behind (the player camera).", "The tail slap looks like it should hit something (it doesn't)."],
    build() { return leapTrack(LEAP, [K(0, READY), K(LEAP.T0, J_TAILPRESS, "io"), K(LEAP.T0 + 0.1, J_TAILWHIP, "out5"), K(LEAP.T0 + 0.3, J_AIR, "io"), K(t1 - 0.14, J_AIR, "io"), K(t1 - 0.02, J_DOWN, "io"), K(t1 + 0.12, J_LAND, "out"), K(t1 + 0.7, READY, "io")], [[0.16, t1 + 0.32]],
      {update(t) { this._tail = t > LEAP.T0 + 0.3 && t < t1 - 0.1 ? Math.sin(t * 9) * 12 : 0; }, extra(T) { if (this._tail) for (const n of ["Tail2", "Tail3", "Tail4"]) T[n] = (T[n] || [0, 0, 0]).map((v, i) => i === 1 ? v + this._tail : v); }}); }},
};
function venomTrack(style, extra) { // a dart lands at 0.25; the venom then ticks every 0.5 s for 3 s (DiloAttackServer VENOM_TICK, VenomDps 2)
  place(R0, -3, -26, 0); R0.yaw = yawTo(R0.pos, dilo.pos) - 0.6; R1.show = false;
  return Object.assign({frame: [new THREE.Vector3(0, 0, -6), R0.pos.clone()], keys: [K(0, C_DART2), K(0.5, READY, "io")],
    ev: [{t: 0.05, f: () => { const from = mouthPoint(); spawnShot({kind: "dart", from, target: () => rapChest(R0), T: 0.22, H: 0.2, onHit: p => dartHit(R0, p, 6, {rate: 2, dur: 3}, 0.6, style)}); }},
      {t: 1.4, f: () => { R0.path = [[1.4, R0.pos.clone(), R0.yaw, 0], [1.8, R0.pos.clone().add(new THREE.Vector3(-4, 0, -6)), R0.yaw + 2.6, 0.7], [3.4, R0.pos.clone().add(new THREE.Vector3(-14, 0, -18)), R0.yaw + 2.6, 0.7]]; }}]}, extra || {});
}
VM.venom = {
  now: {name: "Now", sub: "as the game plays it (v476)", len: 3.8, timing: "1 every 0.5 s for 3 s",
    ref: "DiloFX 1.1: a green glow on the poisoned dino, droplets dripping off it, a small green number per tick.",
    phases: [[0, 0.3, "A dart lands"], [0.3, 3.3, "Poisoned: glows green, drips, '1' every 0.5 s"], [3.3, 3.8, "Wears off"]],
    notes: ["The glow is faint in daylight; the ticks are small.", "Hard to tell a poisoned raptor from a healthy one at a distance."],
    build() { return venomTrack("now"); }},
  A: {name: "A · Toxic Bubbles", sub: "bubbles rise and pop on each tick", len: 3.8, rec: true, timing: "as now",
    ref: "Poison bubbles from classic RPGs (Pokémon, Zelda); Monster Hunter's poison status.",
    phases: [[0, 0.3, "A dart lands"], [0.3, 3.3, "Green bubbles stream up; each tick a burst + '1'"], [3.3, 3.8, "Wears off"]],
    notes: ["Reads from far away and from any side.", "A few more parts on screen while it lasts (light)."],
    build() { return venomTrack("bubbles"); }},
  B: {name: "B · Sick Cough", sub: "flashes green and coughs each tick", len: 3.8, timing: "as now",
    ref: "Monster Hunter: a poisoned monster flinches and a cloud puffs on each tick.",
    phases: [[0, 0.3, "A dart lands"], [0.3, 3.3, "Each tick: a green flash, a cough (head dips), a puff of mist"], [3.3, 3.8, "Wears off"]],
    notes: ["The cough sells 'it hurts'.", "Moves the target's head: may look like a stun (it isn't)."],
    build() { return venomTrack("cough"); }},
  C: {name: "C · Creeping Green", sub: "green spreads over the body", len: 3.8, timing: "as now",
    ref: "Venom spreading under the skin (the 'veins' look of many survival games).",
    phases: [[0, 0.3, "A dart lands"], [0.3, 3.3, "Its body turns green from the hit spot outward; each tick pulses"], [3.3, 3.8, "The green fades"]],
    notes: ["Shows how long is left (it fades as it wears off).", "Tinting the whole body clashes with skins."],
    build() { return venomTrack("creep"); }},
};
function toxicTrack(style) { // the raptor bites the dilo at 0.45; Toxic Blood poisons it (DiloToxicDps, close range)
  place(R0, 0, -15, 0); R0.yaw = yawTo(R0.pos, dilo.pos); R1.show = false;
  const BIT = 0.45;
  const keys = style === "hiss" ? [K(0, READY), K(BIT, READY), K(BIT + 0.06, HIT_REACT, "out"), K(BIT + 0.16, HISS, "out5"), K(BIT + 0.6, HISS, "io"), K(BIT + 1.2, READY, "io")]
    : [K(0, READY), K(BIT, READY), K(BIT + 0.06, HIT_REACT, "out"), K(BIT + 0.7, READY, "io")];
  return {frame: [new THREE.Vector3(0, 0, 0), R0.pos.clone()], keys, frill: style === "hiss" ? [[BIT + 0.08, BIT + 1.0]] : [],
    ev: [{t: 0.2, f: () => { R0.lunge = 1; }},
      {t: BIT, f: () => { const p = partPoint(dilo.segs.Neck[0]); hitStop = 0.07; shake = 0.7; numberPop(p.clone().add(new THREE.Vector3(0, 6, 0)), 8, "hit"); vig("rgba(255,40,30,.6)", 0.4);
        if (style === "now") { flash(p, 7, 0xff7a6a); venomOn(R0, 1, 2, "now"); }
        if (style === "spines") { flash(p, 7, 0xd8ffb0); for (let i = 0; i < 9; i++) { const d = rapChest(R0).sub(p).normalize().add(new THREE.Vector3((Math.random() - .5) * 0.8, (Math.random() - .2) * 0.6, (Math.random() - .5) * 0.8)); spine(p.clone(), d, 2.4); }
          textTag(p.clone().add(new THREE.Vector3(0, 10, 0)), "TOXIC BLOOD", "#b8ff70", 1.4); setTimeout0(0.12, () => { R0.flinch = 1; R0.flash = 0.14; R0.flashCol = [0.35, 0.95, 0.15]; venomOn(R0, 1, 2, "now"); }); }
        if (style === "hiss") { flash(p, 6, 0xff7a6a); setTimeout0(0.16, () => { const m = mouthPoint(), d = rapChest(R0).sub(m).normalize(); for (let i = 0; i < 7; i++) puff(m.clone(), d.clone().multiplyScalar(26 + Math.random() * 10).add(new THREE.Vector3((Math.random() - .5) * 6, (Math.random() - .5) * 4, 0)), 2.5, 0xb8ff70, 0.55);
          setTimeout0(0.22, () => { R0.flinch = 1; R0.flash = 0.14; R0.flashCol = [0.35, 0.95, 0.15]; venomOn(R0, 1, 2, "now"); }); }); }
        if (style === "blood") { flash(p, 7, 0xd8ffb0); for (let i = 0; i < 18; i++) { const d = rapChest(R0).sub(p); d.y = 0; d.normalize(); droplet(p.clone(), d.multiplyScalar(14 + Math.random() * 14).add(new THREE.Vector3((Math.random() - .5) * 8, 10 + Math.random() * 8, (Math.random() - .5) * 8)), 1 + Math.random(), 0.6, 50); }
          setTimeout0(0.3, () => { R0.flinch = 0.8; R0.flash = 0.14; R0.flashCol = [0.35, 0.95, 0.15]; venomOn(R0, 1, 2, "now"); }); }
      }}]};
}
// delayed one-shots inside a track (play time, so scrubbing / slow motion stay in step)
let delayed = [];
function setTimeout0(d, f) { delayed.push({at: (play ? play.t : 0) + d, f}); }
VM.toxic = {
  now: {name: "Now", sub: "as the game plays it (v476)", len: 3, timing: "on a close hit",
    ref: "DiloAttackServer 1.1 Toxic Blood: the attacker gets venom; DiloFX shows the usual venom glow on it.",
    phases: [[0, 0.45, "A raptor lunges in"], [0.45, 0.6, "Bites the dilo · 8"], [0.6, 3, "The raptor starts glowing green (Toxic Blood)"]],
    notes: ["Nothing shows the poison came from the dilo's blood.", "Easy to miss that the passive did anything."],
    build() { return toxicTrack("now"); }},
  A: {name: "A · Spine Burst", sub: "green spines shoot back at the biter", len: 3, rec: true, timing: "as now",
    ref: "Porcupine / hedgehog counters and 'thorns' auras in RPGs.",
    phases: [[0, 0.45, "A raptor lunges in"], [0.45, 0.6, "Bites the dilo · 8"], [0.6, 0.8, "Green spines burst out of the hit spot into the raptor · TOXIC BLOOD"], [0.8, 3, "The raptor is poisoned"]],
    notes: ["Cause and effect in one beat: you hit it, it stung you.", "A text tag on every close hit could get noisy in a crowd."],
    build() { return toxicTrack("spines"); }},
  B: {name: "B · Hiss", sub: "hood flares, hisses venom mist back", len: 3, timing: "as now",
    ref: "Jurassic Park's dilophosaur: the hood snaps open with a hiss before it spits.",
    phases: [[0, 0.45, "A raptor lunges in"], [0.45, 0.6, "Bites the dilo · 8"], [0.6, 0.9, "Hood snaps open, it hisses a green cloud in the raptor's face"], [0.9, 3, "The raptor is poisoned"]],
    notes: ["Most in character for a dilo.", "The hiss pose looks like an attack you pressed (it's automatic)."],
    build() { return toxicTrack("hiss"); }},
  C: {name: "C · Green Blood", sub: "the wound splashes green venom", len: 3, timing: "as now",
    ref: "Alien's acid blood: hitting it hurts you.",
    phases: [[0, 0.45, "A raptor lunges in"], [0.45, 0.6, "Bites the dilo · 8 · green blood sprays out"], [0.6, 0.9, "The droplets hit the raptor"], [0.9, 3, "The raptor is poisoned"]],
    notes: ["Simple and clear: green blood = toxic blood.", "Busy when the dilo is hit often."],
    build() { return toxicTrack("blood"); }},
};
function feastTrack(style) { // the raptor is poisoned; each tick heals the dilo (Venom Feast I: 20% of the poison damage)
  place(R0, -2, -26, 0); R0.yaw = yawTo(R0.pos, dilo.pos) - 0.4; R1.show = false;
  const ticks = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0];
  const lick = style === "lick";
  const keys = [K(0, READY)];
  if (lick) ticks.forEach(t => { keys.push(K(t + 0.42, READY, "io"), K(t + 0.5, LICK, "out"), K(t + 0.62, READY, "io")); });
  keys.push(K(3.6, READY));
  return {frame: [new THREE.Vector3(0, 0, -4), R0.pos.clone()], keys, sac: style === "sac" ? ticks.map(t => [t + 0.42, t + 0.62]) : [],
    ev: [{t: 0.01, f: () => venomOn(R0, 2, 3.1, "now")}, ...ticks.map(t => ({t, f: () => {
      const back = () => partPoint(mouthParts.mouth);
      if (style === "now") return;
      if (style === "motes" || style === "lick") mote(rapChest(R0), back, 0.42, 0x9cf05a, p => { flash(p, 3, 0xb8ff70); numberPop(dilo.pos.clone().add(new THREE.Vector3(1, 17, 0)), "+0.2", "venom"); });
      if (style === "sac") setTimeout0(0.42, () => { flash(partPoint(P_("Jaw_sac")), 5, 0x9cf05a); numberPop(dilo.pos.clone().add(new THREE.Vector3(1, 17, 0)), "+0.2", "venom"); });
    }}))],
    update(t) { if (style === "sac") this._glow = inWin(this.sac, t) ? 1 : 0; },
    tint(t) { return style === "sac" && this._glow ? [0.1, 0.45, 0.05] : null; }};
}
VM.feast = {
  now: {name: "Now", sub: "as the game plays it (v476)", len: 3.6, timing: "+20% of each tick",
    ref: "DiloAttackServer 1.1 Venom Feast: the heal happens on the server; nothing on screen.",
    phases: [[0, 0.5, "The raptor is poisoned"], [0.5, 3.6, "Each tick heals the dilo a little · nothing shows"]],
    notes: ["You can't see the passive working at all."],
    build() { return feastTrack("now"); }},
  A: {name: "A · Life Motes", sub: "green motes fly back into its mouth", len: 3.6, rec: true, timing: "as now",
    ref: "Life-steal orbs in Diablo / Hades: the stolen life flies back to you.",
    phases: [[0, 0.5, "The raptor is poisoned"], [0.5, 0.92, "Each tick a green mote flies from the raptor to the dilo"], [0.92, 3.6, "It lands in the mouth: '+0.2'"]],
    notes: ["Shows where the heal comes from and that it's working.", "With several poisoned dinos, several mote streams."],
    build() { return feastTrack("motes"); }},
  B: {name: "B · Glowing Sac", sub: "the throat sac swells and glows", len: 3.6, timing: "as now",
    ref: "The dilo's own throat sac (DiloPose's spit swell) used as a 'drinking' tell.",
    phases: [[0, 0.5, "The raptor is poisoned"], [0.5, 3.6, "Each tick the sac swells and glows green · '+0.2'"]],
    notes: ["Uses a part the dilo already has; no flying effects.", "Only visible from the front / side."],
    build() { return feastTrack("sac"); }},
  C: {name: "C · Lick", sub: "a mote + it licks its lips", len: 3.6, timing: "as now",
    ref: "Predators licking their lips: a small 'tasty' beat.",
    phases: [[0, 0.5, "The raptor is poisoned"], [0.5, 3.6, "Each tick: a mote flies back and the dilo licks its jaws · '+0.2'"]],
    notes: ["Most character.", "The lick moves the head every 0.5 s while it lasts (busy)."],
    build() { return feastTrack("lick"); }},
};
function coldTrack(style) { // a raptor hit drops the dilo under 30%: Cold Blood (darts x1.25; star: the dart recharges at once)
  place(R0, -2, -15, 0); R0.yaw = yawTo(R0.pos, dilo.pos); R1.show = false;
  const HIT = 0.45, D = 1.9;
  const keys = [K(0, READY), K(HIT, READY), K(HIT + 0.06, HIT_REACT, "out"), K(HIT + 0.6, READY, "io"), K(D - 0.5, READY), K(D - 0.3, C_COIL, "io"), K(D, C_COIL2, "io"), K(D + 0.05, C_DART, "in2"), K(D + 0.25, C_DART2, "out"), K(D + 0.8, READY, "io")];
  return {frame: [new THREE.Vector3(0, 0, 0), new THREE.Vector3(-8, 0, -34)], keys, frill: [[D - 0.45, D + 0.7]], sac: [[D - 0.45, D + 0.05]],
    ev: [{t: 0.2, f: () => { R0.lunge = 1; }},
      {t: HIT, f: () => { const p = partPoint(dilo.segs.Neck[0]); hitStop = 0.07; shake = 0.7; numberPop(p.clone().add(new THREE.Vector3(0, 6, 0)), 12, "hit"); flash(p, 7, 0xff7a6a); vig("rgba(255,40,30,.6)", 0.45);
        hpTag("HP 28% · COLD BLOOD", style === "now" ? "#ffffff" : "#bfe8ff");
        if (style === "frost") { flash(dilo.pos.clone().add(new THREE.Vector3(0, 8, 0)), 22, 0xbfe8ff); groundRing(dilo.pos.clone(), 16, 0xbfe8ff, 0.6); vig("rgba(140,200,255,.7)", 0.5); }
        if (style === "heart") groundRing(dilo.pos.clone(), 10, 0x7fc8ff, 0.7);
      }},
      {t: 1.1, f: () => { R0.path = [[1.1, R0.pos.clone(), R0.yaw, 0], [1.4, R0.pos.clone().add(new THREE.Vector3(-2, 0, -6)), R0.yaw + 3, 0.8], [2.3, new THREE.Vector3(-8, 0, -34), R0.yaw + 3, 0.6], [2.6, new THREE.Vector3(-8, 0, -34), yawTo(new THREE.Vector3(-8, 0, -34), dilo.pos), 0]]; }},
      {t: D, f: () => { const from = mouthPoint(); const ice = style !== "now";
        spawnShot({kind: "dart", from, target: () => rapChest(R0), T: 0.36, H: 0.3, onHit: p => { dartHit(R0, p, 8, {rate: 2, dur: 3}, 0.85); if (ice) { flash(p, 9, 0xbfe8ff); textTag(p.clone().add(new THREE.Vector3(0, 9, 0)), "×1.25", "#bfe8ff", 1.1); } }});
        if (ice) { const s = shots[shots.length - 1]; s.mesh.material = new THREE.MeshBasicMaterial({color: 0xcff4ff}); s.glow.material.color.setHex(0x9fdcff); } }}],
    update(t, dt) {
      const on = t > HIT + 0.05;
      if (style === "frost" && on) { this._em = (this._em || 0) + dt * 2.2; while (this._em >= 1) { this._em -= 1; puff(mouthPoint(), headDir().multiplyScalar(4).add(new THREE.Vector3(0, 1.5, 0)), 1.4, 0xeaf6ff, 0.8); } }
      if (style === "heart" && on) { this._hb = (this._hb || 0) + dt; if (this._hb > 0.8) { this._hb = 0; groundRing(dilo.pos.clone(), 9, 0x7fc8ff, 0.7); } }
      this._sh = style === "shiver" && t > HIT + 0.1 && t < HIT + 0.55 ? 1 : 0; this._on = on;
    },
    extra(T) { if (this._sh) { const s = SHIVER(clockT); for (const n in s) T[n] = (T[n] || [0, 0, 0]).map((v, i) => v + s[n][i]); } },
    tint() { if (!this._on) return null; if (style === "frost") return [0.05, 0.14, 0.24]; if (style === "shiver") return [0.03, 0.08, 0.16]; return null; },
    frillTint() { return style === "shiver" && this._on ? 0x7fd0ff : null; }};
}
VM.cold = {
  now: {name: "Now", sub: "as the game plays it (v476)", len: 3.4, timing: "under 30% health",
    ref: "DiloAttackServer 1.1 Cold Blood: darts x1.25 (and the star's dart reset) while low; nothing on screen.",
    phases: [[0, 0.45, "A raptor lunges in"], [0.45, 1.4, "Hit · the dilo drops under 30% (Cold Blood on) · nothing shows"], [1.4, 3.4, "Next dart hits harder (8 instead of 6)"]],
    notes: ["Neither you nor the enemy can see the dilo is now more dangerous."],
    build() { return coldTrack("now"); }},
  A: {name: "A · Frost Breath", sub: "icy flash, blue tint, cold breath", len: 3.4, rec: true, timing: "as now",
    ref: "'Cold-blooded' read literally: frost auras and breath puffs from winter-themed status effects.",
    phases: [[0, 0.45, "A raptor lunges in"], [0.45, 0.8, "Hit · drops under 30% · an icy flash + ring"], [0.8, 1.4, "Tinted icy blue, cold breath puffs from the mouth"], [1.4, 3.4, "Its darts fly icy · ×1.25"]],
    notes: ["Clear 'danger mode' for both sides.", "Blue on a green dino: may not suit every skin."],
    build() { return coldTrack("frost"); }},
  B: {name: "B · Shiver", sub: "a hard shiver, the hood edges glow blue", len: 3.4, timing: "as now",
    ref: "A lizard shivering in the cold; Monster Hunter's 'enraged' tells.",
    phases: [[0, 0.45, "A raptor lunges in"], [0.45, 1.0, "Hit · drops under 30% · shivers hard"], [1.0, 1.4, "The hood glows blue while Cold Blood lasts"], [1.4, 3.4, "Icy darts · ×1.25"]],
    notes: ["The shiver is a strong one-time tell.", "The hood glow is only seen when the hood is open."],
    build() { return coldTrack("shiver"); }},
  C: {name: "C · Cold Heart", sub: "a slow blue heartbeat ring", len: 3.4, timing: "as now",
    ref: "Low-health heartbeat effects (the ring pulses at your feet).",
    phases: [[0, 0.45, "A raptor lunges in"], [0.45, 1.4, "Hit · drops under 30% · a blue ring pulses every 0.8 s"], [1.4, 3.4, "Icy darts · ×1.25"]],
    notes: ["Doubles as a 'low health' warning.", "Rings on the ground are hidden in tall grass."],
    build() { return coldTrack("heart"); }},
};

const MOVES = [
  {id: "bite", name: "Bite", area: "attack", nums: "Damage 10, reach 5 studs, hit 0.18 s after the press, 1.0 s between bites: unchanged."},
  {id: "dart", name: "Spit Dart", area: "attack", nums: "Hold 0.4 s, dart 6 + venom 2/s for 3 s, 30-stud soft aim, 1.5 s recharge: unchanged."},
  {id: "leap", name: "Cobra Leap", area: "speed", nums: "Distance and recharge unchanged (B adds a little hang time)."},
  {id: "venom", name: "Venom", area: "attack", nums: "Venom 2/s, a tick every 0.5 s, 3 s: unchanged. Seen on whoever is poisoned."},
  {id: "toxic", name: "Toxic Blood", area: "defense", nums: "Toxic Blood I: a close attacker is poisoned 1/s for 2 s: unchanged."},
  {id: "feast", name: "Venom Feast", area: "health", nums: "Venom Feast I: heal 20% of the poison damage you deal: unchanged."},
  {id: "cold", name: "Cold Blood", area: "speed", nums: "Cold Blood: under 30% health, darts x1.25 (star: the dart recharges once): unchanged."},
];
const AREA = {attack: ["Attack", "#ff6b6b"], speed: ["Speed", "#ffd34d"], defense: ["Defense", "#5fb4ff"], health: ["Health", "#7dff9a"], eng: ["Engineer", "#ff9b2e"]};

// ---------- the player ----------
let cur = 0, variant = "now", playing = true, speed = 1, camMode = "hero", play = null;
const M = () => MOVES[cur], VV = () => VM[M().id][variant];
function resetFx() { fx.splice(0).forEach(e => scene.remove(e.obj)); shots.splice(0).forEach(s => { scene.remove(s.mesh); scene.remove(s.glow); }); delayed = []; if (mouthGlow) mouthGlow.visible = false; }
function start() {
  resetFx();
  for (const R of raps) { R.flinch = 0; R.flash = 0; R.push = 0; R.venom = null; R.slow = 0; R.path = null; R.run = 0; R.lunge = 0; R.show = false; R.tint = 0; }
  leapCfg = LEAP; aim.on = 0; aim.R = null; aim.cone = null; aim.yaw = 0;
  for (const k in aimCone) aimCone[k].visible = false;
  const track = VV().build();
  play = {track, t: 0, fired: new Set()};
  frill.open = false; frill.t = 9; dilo.sac = 1; springs = {}; rootSpring.x = 0; rootSpring.v = 0; hitStop = 0; shake = 0; fovPunch = 0;
  dilo.pos.set(0, 0, 0);
}
function idleLayer(t) {
  const b = Math.sin(t * 2.1), b2 = Math.sin(t * 2.1 + 1.2);
  return {RootJoint: [b * 1.0, 0, 0], Neck: [b * 1.6, Math.sin(t * 0.7) * 4, 0], Head: [-b * 1.4, Math.sin(t * 0.9 + 1) * 3, 0], Jaw: [Math.max(0, Math.sin(t * 0.5)) * -3, 0, 0],
    ArmL: [b2 * 3, 0, 0], ArmR: [b2 * 3, 0, 0],
    Tail1: [b * 1.2, Math.sin(t * 1.3) * 4, 0], Tail2: [0, Math.sin(t * 1.3 - .6) * 5, 0], Tail3: [0, Math.sin(t * 1.3 - 1.2) * 6, 0], Tail4: [0, Math.sin(t * 1.3 - 1.8) * 7, 0], Tail5: [0, Math.sin(t * 1.3 - 2.4) * 8, 0]};
}
function inWin(list, t) { return (list || []).some(([a, b]) => t >= a && t < b); }
function frillScale() {
  if (frill.open) { const u = Math.min(1, frill.t / 0.13); let s = 0.2 + 0.8 * E.back(u); if (frill.t < 0.3) s += Math.sin(frill.t * 95) * 0.035 * (1 - frill.t / 0.3); return s; }
  return frill.t < 0.1 ? 1 - 0.75 * (frill.t / 0.1) : 0;
}
const frillMeshes = dilo.parts.filter(p => p.kind === "frill");
frillMeshes.forEach(p => { p.mesh.material = p.mesh.material.clone(); p.baseEm = 0; });

function rapPose(R, dt) {
  R.rig.g.visible = R.show; if (!R.show) return;
  const tt = play ? play.t : 0;
  if (R.path && play) {
    const P = R.path; let i = 0; while (i < P.length - 1 && tt > P[i + 1][0]) i++;
    if (tt <= P[0][0]) { R.pos.copy(P[0][1]); R.yaw = P[0][2]; R.run = P[0][3]; }
    else if (i >= P.length - 1) { R.pos.copy(P[P.length - 1][1]); R.yaw = P[P.length - 1][2]; R.run = 0; }
    else { const a = P[i], b = P[i + 1], u = (tt - a[0]) / (b[0] - a[0]); R.pos.lerpVectors(a[1], b[1], u); let dy = b[2] - a[2]; while (dy > Math.PI) dy -= 2 * Math.PI; while (dy < -Math.PI) dy += 2 * Math.PI; R.yaw = a[2] + dy * E.io(Math.min(1, u * 1.6)); R.run = a[3] + (b[3] - a[3]) * u; }
  }
  R.flinch = Math.max(0, R.flinch - dt * 2.6); R.flash = Math.max(0, R.flash - dt); R.push *= Math.pow(0.03, dt);
  R.runPh += dt * 15 * R.run;
  if (R.lunge) R.lunge = Math.max(0, R.lunge - dt * 2.2);
  const L = R.lunge ? Math.sin(Math.PI * Math.min(1, (1 - R.lunge) * 1.4)) : 0;
  const f = E.out(R.flinch), s = Math.sin(R.runPh), c = Math.cos(R.runPh), rn = R.run;
  let cough = 0;
  if (R.venom && R.venom.style === "cough") cough = Math.max(0, 1 - (0.5 - R.venom.next) / 0.25) * (R.venom.next < 0.5 && R.venom.next > 0.25 ? 1 : 0);
  R.rig.yaw = R.yaw; R.rig.pos.copy(R.pos).addScaledVector(R.pushDir, R.push);
  const fwd = new THREE.Vector3(-Math.sin(R.yaw), 0, -Math.cos(R.yaw)); R.rig.pos.addScaledVector(fwd, L * 5);
  pose(R.rig, {RootJoint: [10 * f - 6 * rn - 14 * L, 0, R.side * 8 * f], Neck: [12 * f - 4 * rn - 20 * L - 18 * cough, R.side * -18 * f + Math.sin(clockT * 0.8) * 4 * (1 - f), 0], Head: [10 * f, 0, 0], Jaw: [-22 * f - 30 * L - 20 * cough, 0, 0],
    ArmL: [-25 * f + 20 * L, 0, 0], ArmR: [-25 * f + 20 * L, 0, 0], Tail1: [-10 * f, Math.sin(clockT * 1.3) * 4, 0], Tail2: [0, Math.sin(clockT * 1.3 - .7) * 5, 0],
    LegL: [-8 * f + 34 * s * rn, 0, 0], LegR: [-8 * f - 34 * s * rn, 0, 0], KneeL: [-10 * f - (18 + 22 * Math.max(0, c)) * rn, 0, 0], KneeR: [-10 * f - (18 + 22 * Math.max(0, -c)) * rn, 0, 0]});
  if (R.rig.rest !== null) { R.rig.y = R.rig.rest + Math.abs(c) * 1.2 * rn; pose(R.rig, {}); }
  let g = 0, creep = 0;
  if (R.venom) { const V = R.venom; V.left -= dt; V.next -= dt; V.age += dt;
    if (V.style === "now" || V.style === "cough" || V.style === "creep") { V.drip += dt * (V.style === "now" ? 20 : 10); g = 0.1 + 0.06 * Math.sin(clockT * 9); }
    while (V.drip >= 1) { V.drip -= 1; const part = R.rig.parts[(Math.random() * R.rig.parts.length) | 0]; const p = partPoint(part); if (p.y > 3) droplet(p, new THREE.Vector3((Math.random() - .5) * 2, -3, (Math.random() - .5) * 2), 0.9 + Math.random() * 0.7, 0.6, 30); }
    if (V.style === "bubbles" && Math.random() < dt * 16) { const part = R.rig.parts[(Math.random() * R.rig.parts.length) | 0]; bubble(partPoint(part), 1.2 + Math.random() * 0.8); }
    if (V.style === "creep") creep = Math.min(1, V.age / 0.8) * Math.min(1, Math.max(0, V.left) / 0.5);
    if (V.next <= 0 && V.left > -0.05) { V.next += 0.5; const cp = rapChest(R); numberPop(cp.clone().add(new THREE.Vector3((Math.random() - .5) * 3, 5, 0)), V.rate * 0.5 === 1 ? 1 : V.rate * 0.5, "venom"); R.flash = 0.06; R.flashCol = [0.3, 0.9, 0.12];
      if (V.style === "bubbles") for (let i = 0; i < 6; i++) bubble(cp.clone().add(new THREE.Vector3((Math.random() - .5) * 4, (Math.random() - .5) * 3, (Math.random() - .5) * 4)), 1.8);
      if (V.style === "cough") { R.flash = 0.12; puff(partPoint(R.rig.segs.Head[0]), new THREE.Vector3(0, 2, -3), 2.2, 0xb8ff70, 0.6); for (let i = 0; i < 3; i++) puff(R.rig.pos.clone().add(new THREE.Vector3((Math.random() - .5) * 6, 1, (Math.random() - .5) * 6)), new THREE.Vector3(0, 0.6, 0), 3, 0x9cf05a, 1); }
      if (V.style === "creep") R.flash = 0.1; }
    if (V.left <= 0) R.venom = null; }
  const fl = R.flash > 0 ? 1 : 0;
  R.rig.mats.forEach((m, i) => { const cg = creep * (0.18 + 0.06 * Math.sin(clockT * 6 + i)); m.emissive.setRGB(fl * R.flashCol[0] + (1 - fl) * (g * 0.25 + cg * 0.25), fl * R.flashCol[1] + (1 - fl) * (g + cg), fl * R.flashCol[2] + (1 - fl) * (g * 0.1 + cg * 0.1)); });
}
raps.forEach(R => { pose(R.rig, {}); R.rig.y = R.rig.rest; R.rig.g.visible = false; });

function step(dt, noRender) {
  let mdt = dt * speed;
  if (hitStop > 0) { hitStop -= mdt; mdt *= 0.05; }
  idleT += mdt; clockT += mdt;
  let target = idleLayer(idleT), leap = {fwd: 0, up: 0, air: false}, rootFwd = 0;
  const tr = play.track;
  play.t = play.t + mdt;
  const mv = sample(tr.keys, play.t);
  target = addPose(mv, target, 1);
  if (tr.tremble && play.t > tr.tremble[0] && play.t < tr.tremble[1]) for (const n of ["Neck", "Head"]) target[n] = target[n].map((v, i) => v + (i === 0 ? Math.sin(clockT * 80 + n.length) * 1.6 : 0));
  if (tr.sway && play.t > tr.sway[0] && play.t < tr.sway[1]) { const w = Math.sin((play.t - tr.sway[0]) * 6.5) * 7; target.Neck = target.Neck.map((v, i) => i === 1 ? v + w : v); target.Head = target.Head.map((v, i) => i === 1 ? v + w * 0.6 : v); }
  rootFwd = (mv.root && mv.root.fwd) || 0;
  if (tr.leap) leap = leapOffset(play.t);
  for (const e of (tr.ev || [])) { const k = "e" + e.t; if (!play.fired.has(k) && play.t >= e.t) { play.fired.add(k); e.f(); } }
  for (let i = delayed.length - 1; i >= 0; i--) if (play.t >= delayed[i].at) { const d = delayed[i]; delayed.splice(i, 1); d.f(); }
  if (tr.update) tr.update(play.t, mdt);
  for (const n of dilo.joints.map(j => j.n)) if (!target[n]) target[n] = [0, 0, 0];
  if (tr.extra) tr.extra(target);
  const want = inWin(tr.frill, play.t); if (want !== frill.open) { frill.open = want; frill.t = 0; }
  dilo.sac = 1 + 0.55 * (inWin(tr.sac, play.t) ? 1 : 0);
  let aimYaw = 0;
  if (aim.R && aim.R.show) aimYaw = deg(yawTo(dilo.pos, aim.R.rig.pos));
  aim.yaw += ((aim.on ? aimYaw : 0) - aim.yaw) * Math.min(1, mdt * 12);
  target.Neck = target.Neck.map((v, i) => i === 1 ? v + aim.yaw * 0.4 : v); target.Head = target.Head.map((v, i) => i === 1 ? v + aim.yaw * 0.35 : v);
  frill.t += mdt; dilo.frillS = frillScale() * (tr.frillMul || 1);
  const fs = Math.max(0.001, dilo.frillS);
  dilo.frillM.makeTranslation(frillHub.x, frillHub.y, frillHub.z).multiply(new THREE.Matrix4().makeScale(fs, fs, fs)).multiply(new THREE.Matrix4().makeTranslation(-frillHub.x, -frillHub.y, -frillHub.z));
  const P = springStep(target, mdt);
  for (let i = 0, n = Math.max(1, Math.ceil(mdt * 300)); i < n; i++) { const h = mdt / n; rootSpring.v += (400 * (rootFwd - rootSpring.x) - 2 * 0.9 * 20 * rootSpring.v) * h; rootSpring.x += rootSpring.v * h; }
  dilo.yaw = 0; dilo.pos.set(0, 0, -(rootSpring.x + leap.fwd));
  dilo.y = 0; pose(dilo, P);
  let minY = Infinity;
  for (const p of diloFeet) for (let i = 0; i < 8; i++) { _c.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(p.mesh.matrix); minY = Math.min(minY, _c.y); }
  dilo.y = -minY + leap.up; pose(dilo, P);
  const tint = tr.tint ? tr.tint(play.t) : null;
  dilo.mats.forEach(m => m.emissive.setRGB(tint ? tint[0] : 0, tint ? tint[1] : 0, tint ? tint[2] : 0));
  const ft = tr.frillTint ? tr.frillTint() : null;
  frillMeshes.forEach(p => p.mesh.material.emissive.setHex(ft ? ft : 0x000000));
  if (ft) frillMeshes.forEach(p => p.mesh.material.emissiveIntensity = 0.35 + 0.15 * Math.sin(clockT * 6));
  raps.forEach(R => rapPose(R, mdt));
  const aimFade = Math.min(1, aim.on);
  for (const k in aimCone) { const g = aimCone[k]; const on = aim.on && aim.cone === g; setCone(g, on, aimFade); if (on) { g.position.x = dilo.pos.x; g.position.z = dilo.pos.z; } }
  if (aim.on && aim.R && aim.R.show) {
    const a = dilo.pos.clone(), b = aim.R.rig.pos.clone(); const L = a.distanceTo(b) - 6;
    aimLine.visible = true; aimLine.scale.set(1, Math.max(0.1, L - 8), 1); dashTex.repeat.set(1, Math.max(1, (L - 8) / 3.2)); dashTex.offset.y = -clockT * 2.2; aimLineG.position.set(a.x, 0.11, a.z); aimLineG.rotation.y = yawTo(a, b); aimLine.position.set(0, 0, -(8 + (L - 8) / 2));
    aimLine.material.opacity = 0.95 * aimFade;
    reticle.visible = true; reticle.position.set(b.x, 0.12, b.z); reticle.scale.setScalar(1 + 0.08 * Math.sin(clockT * 8));
  } else { aimLine.visible = false; reticle.visible = false; }
  updateShots(mdt);
  for (let i = fx.length - 1; i >= 0; i--) { const e = fx[i]; const fdt = mdt * (hitStop > 0 ? 0.2 : 1); e.t += fdt; const u = Math.min(1, e.t / e.life); e.update(e.obj, u, fdt); if (u >= 1) { scene.remove(e.obj); fx.splice(i, 1); } }
  if (noRender) return;
  shake = Math.max(0, shake - dt * 4.2); fovPunch = Math.max(0, fovPunch - dt * 14);
  const fr = tr.frame;
  const mid = fr[0].clone().lerp(fr[1], 0.5).setY(9), span = fr[0].distanceTo(fr[1]) + 30;
  const hfov = 2 * Math.atan(Math.tan(rad(cam.fov / 2)) * cam.aspect), vfit = span * 0.5 / Math.tan(hfov / 2);
  let cp, look = mid;
  if (camMode === "hero") cp = mid.clone().add(new THREE.Vector3(-1, 0.4, -0.16).normalize().multiplyScalar(vfit * 1.08));
  else if (camMode === "side") cp = mid.clone().add(new THREE.Vector3(-1, 0.14, 0).normalize().multiplyScalar(vfit * 1.1));
  else if (camMode === "game") { cp = dilo.pos.clone().add(new THREE.Vector3(-10, 30, 44)); look = dilo.pos.clone().add(new THREE.Vector3(0, 8, -26)); }
  else { const h = partPoint(mouthParts.skull); cp = h.clone().add(new THREE.Vector3(-15, 3, -15)); look = h.clone().add(new THREE.Vector3(0, -1.5, 0)); }
  camPos.lerp(cp, camMode === "close" ? 0.3 : 0.15); camLook.lerp(look, camMode === "close" ? 0.35 : 0.2);
  const sh = shake * shake;
  cam.position.copy(camPos).add(new THREE.Vector3((Math.random() - .5) * sh, (Math.random() - .5) * sh, (Math.random() - .5) * sh));
  cam.lookAt(camLook); cam.fov = 38 + fovPunch; cam.updateProjectionMatrix();
  sun.position.copy(mid).add(new THREE.Vector3(-30, 70, 30)); sun.target.position.copy(mid);
  renderer.render(scene, cam);
}
const camPos = new THREE.Vector3(-60, 26, -20), camLook = new THREE.Vector3(0, 9, -20);
function seek(t) { start(); const sp = speed; speed = 1; let n = 0; while (play.t < t - 1e-6 && n < 2000) { step(1 / 60, true); n++; } speed = sp; step(0); }

// ---------- UI ----------
function renderAll() {
  const VS = VM[M().id];
  $("moves").innerHTML = MOVES.map((m, i) => `<button class="tab" data-i="${i}" aria-pressed="${i === cur}">${m.name}<small style="color:${AREA[m.area][1]}">4 versions</small></button>`).join("");
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
// test hook: __dilo.set(move, variant, t, cam) seeks there and pauses
window.__dilo = {set(mv, v, time, cm) { window.__manual = true; cur = MOVES.findIndex(m => m.id === mv); variant = v; if (cm) camMode = cm; renderAll(); seek(time); for (let i = 0; i < 30; i++) step(0); }, len: () => VV().len, state: () => ({t: play.t, frill: dilo.frillS, sac: dilo.sac, fx: fx.length, shots: shots.length})};
window.__ready = true;
