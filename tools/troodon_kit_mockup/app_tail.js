
// ======================= Troodon kit v0.1 (app part; the engine above is the dilo kit mockup v0.1's, unchanged) =======================
// The real Troodon (TroodonModelData 1.0, look B Night Watcher, 188 blocks) at the 2x game body. Every attack throws one
// "glow pod" that splashes a zone: enemies inside take damage and are slowed, squadmates inside heal, and the troodon heals a
// little for each enemy the splash hits (Kepu 2026-11-06: "Shot that splashes a zone", "Small self-heal on hit").
const HAND = {L: P_("ArmL_hand"), R: P_("ArmR_hand")};
const eyeMat = hero.mats.find(m => m.color.getHex() === 0xf0a62a);
function handsPoint() { return partPoint(HAND.L).add(partPoint(HAND.R)).multiplyScalar(0.5); }
const S = raps[2]; // the squadmate (a raptor on the troodon's squad)
const R0 = raps[0], R1 = raps[1];
S.ally = true;
// the squadmate is drawn in blue so it reads apart from the two (green) enemy raptors
S.rig.mats.forEach(m => { const h = {}; m.color.getHSL(h); m.color.setHSL(0.6, Math.min(0.75, h.s + 0.15), h.l); });

// ---------- key poses (rig 1.3 angles: see the pose maths notes above) ----------
const T_READY = {};
// A · Glow Pod Toss: both long arms swing down and back, chest rears; then an underarm two-hand fling forward and up
const TA_WIND = BOTH({RootJoint: [9, 0, 0], Neck: [18, 0, 0], Head: [-14, 0, 0], Jaw: [-6, 0, 0], ArmL: [-48, 0, 0], LegL: [6, 0, 0], KneeL: [-12, 0, 0], AnkleL: [4, 0, 0], Tail1: [6, 0, 0], Tail2: [3, 0, 0], root: {fwd: -0.9}});
const TA_HOLD = addPose(TA_WIND, {ArmL: [-6, 0, 0], ArmR: [-6, 0, 0], Neck: [3, 0, 0]}, 1);
const TA_THROW = Object.assign(BOTH({RootJoint: [-9, 0, 0], Neck: [-14, 0, 0], Head: [10, 0, 0], Jaw: [-14, 0, 0], ArmL: [88, 0, 0], KneeL: [-6, 0, 0], Tail1: [-10, 0, 0], Tail2: [-5, 0, 0], root: {fwd: 1.7}}), {LegL: [-6, 0, 0], LegR: [12, 0, 0], KneeR: [-16, 0, 0]});
const TA_FOLLOW = Object.assign(BOTH({RootJoint: [-7, 0, 0], Neck: [-10, 0, 0], Head: [6, 0, 0], Jaw: [-6, 0, 0], ArmL: [62, 0, 0], KneeL: [-6, 0, 0], Tail1: [-8, 0, 0], Tail2: [-4, 0, 0], root: {fwd: 2.0}}), {LegL: [-6, 0, 0], LegR: [12, 0, 0], KneeR: [-16, 0, 0]});
// B · Spit Bolt: the neck coils back, then snaps forward and spits a straight bolt
const TB_COIL = BOTH({RootJoint: [5, 0, 0], Neck: [26, 0, 0], Head: [-22, 0, 0], Jaw: [-10, 0, 0], ArmL: [-14, 0, 0], KneeL: [-10, 0, 0], LegL: [5, 0, 0], Tail1: [6, 0, 0], root: {fwd: -0.8}});
const TB_SPIT = Object.assign(BOTH({RootJoint: [-8, 0, 0], Neck: [-22, 0, 0], Head: [6, 0, 0], Jaw: [-36, 0, 0], ArmL: [14, 0, 0], Tail1: [-8, 0, 0], root: {fwd: 1.8}}), {LegL: [-6, 0, 0], LegR: [10, 0, 0], KneeR: [-12, 0, 0]});
// C · Claw rake (tap): both arms wind back and rake forward with a short lunge
const TC_RWIND = BOTH({RootJoint: [5, 0, 0], Neck: [12, 0, 0], Head: [-6, 0, 0], ArmL: [-36, 0, 0], KneeL: [-8, 0, 0], root: {fwd: -0.6}});
const TC_RAKE = Object.assign(BOTH({RootJoint: [-14, 0, 0], Neck: [-26, 0, 0], Head: [4, 0, 0], Jaw: [-18, 0, 0], ArmL: [74, 0, 0], KneeL: [-8, 0, 0], Tail1: [-12, 0, 0], Tail2: [-6, 0, 0], root: {fwd: 3.2}}), {LegL: [-8, 0, 0], LegR: [16, 0, 0], KneeR: [-20, 0, 0]});
// jumps: J1 crouch / push / tuck / plain landing (the dilo leap's leg keys, the long arms tucked up); J2 a low quick hop back
const TJ_CROUCH = BOTH({RootJoint: [-8, 0, 0], Neck: [20, 0, 0], Head: [-16, 0, 0], ArmL: [-20, 0, 0], LegL: [34, 0, 0], KneeL: [-58, 0, 0], AnkleL: [26, 0, 0], Tail1: [6, 0, 0]});
const TJ_PUSH = BOTH({RootJoint: [-4, 0, 0], Neck: [14, 0, 0], Head: [-10, 0, 0], ArmL: [-10, 0, 0], LegL: [-22, 0, 0], KneeL: [-4, 0, 0], AnkleL: [-24, 0, 0], Tail1: [-6, 0, 0]});
const TJ_AIR = BOTH({RootJoint: [-2, 0, 0], Neck: [22, 0, 0], Head: [-20, 0, 0], ArmL: [36, 0, 0], LegL: [40, 0, 0], KneeL: [-72, 0, 0], AnkleL: [34, 0, 0], Tail1: [-8, 0, 0], Tail2: [-4, 0, 0], Tail3: [-3, 0, 0]});
const TJ_DOWN = BOTH({RootJoint: [-6, 0, 0], Neck: [14, 0, 0], Head: [-10, 0, 0], ArmL: [10, 0, 0], LegL: [22, 0, 0], KneeL: [-30, 0, 0], AnkleL: [12, 0, 0], Tail1: [-4, 0, 0]});
const TJ_LAND = BOTH({RootJoint: [-6, 0, 0], Neck: [8, 0, 0], Head: [-6, 0, 0], ArmL: [6, 0, 0], LegL: [24, 0, 0], KneeL: [-42, 0, 0], AnkleL: [18, 0, 0], Tail1: [6, 0, 0]});
const TH_SET = BOTH({RootJoint: [-4, 0, 0], Neck: [10, 0, 0], Head: [-8, 0, 0], ArmL: [-8, 0, 0], LegL: [20, 0, 0], KneeL: [-40, 0, 0], AnkleL: [18, 0, 0], Tail1: [4, 0, 0]});
const TH_AIR = BOTH({RootJoint: [6, 0, 0], Neck: [6, 0, 0], Head: [-4, 0, 0], ArmL: [20, 0, 0], LegL: [-14, 0, 0], KneeL: [-36, 0, 0], AnkleL: [16, 0, 0], Tail1: [-10, 0, 0], Tail2: [-6, 0, 0]});

// ---------- troodon FX: the glow pod, the zone, heal crosses, numbers ----------
const AMBER = 0xffb43a, AMBER_D = 0xd9821c, HEALC = 0x6dff8a, ZONEC = 0x2fe6c8, ZONER = 0xa8fff0;
const T_POD = radialTex("rgba(255,236,170,1)", "rgba(255,150,40,0)", 0.45);
const T_HEAL = (() => { const c = document.createElement("canvas"); c.width = c.height = 64; const x = c.getContext("2d"); x.fillStyle = "#e9ffe9"; x.fillRect(24, 8, 16, 48); x.fillRect(8, 24, 48, 16); x.strokeStyle = "#0e5a1e"; x.lineWidth = 4; x.strokeRect(24, 8, 16, 48); x.strokeRect(8, 24, 48, 16); x.fillRect(24, 8, 16, 48); x.fillRect(8, 24, 48, 16); return new THREE.CanvasTexture(c); })();
const podGeo = new THREE.IcosahedronGeometry(1.15, 1), podMat = new THREE.MeshLambertMaterial({color: 0xffc35a, emissive: 0xb85a00});
const boltGeo = new THREE.CylinderGeometry(0.2, 0.6, 4.6, 8); boltGeo.rotateX(Math.PI / 2);
const boltMat = new THREE.MeshBasicMaterial({color: 0xffe3a0});
const tshots = [];
function throwPod(o) { // o: {kind: "pod" | "bolt", from, target: () => Vector3, T, H, onHit}
  const m = new THREE.Mesh(o.kind === "bolt" ? boltGeo : podGeo, o.kind === "bolt" ? boltMat : podMat); m.castShadow = true; scene.add(m);
  const glow = sprite(T_POD, 0xffd27a, o.kind === "bolt" ? 4.2 : 5.5, true); scene.add(glow);
  tshots.push(Object.assign({mesh: m, glow, t: 0, prev: o.from.clone(), em: 0}, o));
}
function updatePods(dt) {
  for (let i = tshots.length - 1; i >= 0; i--) {
    const s = tshots[i]; s.t += dt; const u = Math.min(1, s.t / s.T); const to = s.target();
    const p = s.from.clone().lerp(to, u); p.y += 4 * s.H * u * (1 - u);
    const v = p.clone().sub(s.prev); s.mesh.position.copy(p); s.glow.position.copy(p);
    if (v.lengthSq() > 1e-6) s.mesh.lookAt(p.clone().add(v));
    if (s.kind === "pod") s.mesh.rotateZ(s.t * 8);
    s.em += dt * (s.kind === "bolt" ? 90 : 40);
    while (s.em >= 1) { s.em -= 1; const q = s.prev.clone().lerp(p, Math.random());
      const t = sprite(T_POD, Math.random() < 0.5 ? AMBER : 0xffe7a8, s.kind === "bolt" ? 1.5 : 1.1 + Math.random() * 0.8, true); t.position.copy(q);
      const w = new THREE.Vector3((Math.random() - .5) * 3, s.kind === "bolt" ? 0 : 1.5 + Math.random() * 2, (Math.random() - .5) * 3);
      addFx(t, s.kind === "bolt" ? 0.22 : 0.5, (o, uu, d) => { o.position.addScaledVector(w, d); o.material.opacity = 1 - uu; o.scale.setScalar((s.kind === "bolt" ? 1.5 : 1.3) * (1 - uu * 0.6)); }); }
    s.prev.copy(p);
    if (u >= 1) { scene.remove(s.mesh); scene.remove(s.glow); tshots.splice(i, 1); s.onHit(p); }
  }
}
function popNum(p, text, style) { // style: "hit" (white / yellow), "tick" (small amber), "heal" (green, with +)
  const c = document.createElement("canvas"); c.width = 256; c.height = 128; const x = c.getContext("2d");
  const heal = style === "heal", tick = style === "tick";
  x.font = `900 ${tick ? 62 : heal ? 70 : 80}px "Trebuchet MS", system-ui, sans-serif`; x.textAlign = "center"; x.lineJoin = "round"; x.lineWidth = 14;
  x.strokeStyle = heal ? "#08310f" : tick ? "#3a1c02" : "#2a1504"; x.strokeText(String(text), 128, 100);
  const g = x.createLinearGradient(0, 30, 0, 110);
  if (heal) { g.addColorStop(0, "#eaffe8"); g.addColorStop(1, "#3fe060"); } else if (tick) { g.addColorStop(0, "#fff0c8"); g.addColorStop(1, "#ffa21a"); } else { g.addColorStop(0, "#ffffff"); g.addColorStop(1, "#ffd23a"); }
  x.fillStyle = g; x.fillText(String(text), 128, 100);
  const s = new THREE.Sprite(new THREE.SpriteMaterial({map: new THREE.CanvasTexture(c), transparent: true, depthTest: false}));
  s.renderOrder = 10; s.position.copy(p); const vx = (Math.random() - .5) * 8, base = (tick ? 6 : heal ? 7 : 8) * numScale;
  addFx(s, 0.95, (o, u, dt) => { o.position.y += (14 - u * 22) * dt; o.position.x += vx * dt; const pop = u < 0.12 ? E.back(u / 0.12) : 1; o.scale.set(base * pop, base * 0.5 * pop, 1); o.material.opacity = u > 0.65 ? (1 - u) / 0.35 : 1; });
}
function healCrosses(p, n) { for (let i = 0; i < n; i++) { const s = sprite(T_HEAL, 0xffffff, 1.4 + Math.random() * 0.8, false); s.position.copy(p).add(new THREE.Vector3((Math.random() - .5) * 6, (Math.random() - .5) * 3, (Math.random() - .5) * 6)); const vy = 5 + Math.random() * 4; addFx(s, 0.9, (o, u, d) => { o.position.y += vy * d; o.material.opacity = u < 0.15 ? u / 0.15 : 1 - (u - 0.15) / 0.85; }); } }
// the zone: an amber disc with a bright rim, a ring wave on the splat, spores drifting up, ticks once a second
const ZONE = {R: 10, LIFE: 3, IMPACT: 6, DPS: 3, HEAL: 5, SELF: 2, SLOW: 25};
const zones = [];
function zoneBurst(p) {
  const c = new THREE.Vector3(p.x, 0, p.z);
  hitStop = 0.07; shake = Math.max(shake, 0.6); fovPunch = 1.4;
  flash(p, 11, 0xffe2a0);
  for (let i = 0; i < 22; i++) { const a = Math.random() * Math.PI * 2, sp = 10 + Math.random() * 18; const s = sprite(T_POD, Math.random() < 0.5 ? AMBER : 0xffe7a8, 0.9 + Math.random() * 0.9, true); s.position.copy(p); const v = new THREE.Vector3(Math.cos(a) * sp, 6 + Math.random() * 12, Math.sin(a) * sp); addFx(s, 0.45 + Math.random() * 0.25, (o, u, d) => { v.y -= 50 * d; o.position.addScaledVector(v, d); if (o.position.y < 0.3) { o.position.y = 0.3; v.set(0, 0, 0); } o.material.opacity = 1 - u; }); }
  const g = new THREE.Group(); g.position.copy(c).setY(0.14); scene.add(g);
  const disc = new THREE.Mesh(new THREE.CircleGeometry(ZONE.R, 48), new THREE.MeshBasicMaterial({color: ZONEC, transparent: true, opacity: 0.3, depthWrite: false})); disc.rotation.x = -Math.PI / 2; g.add(disc);
  const rim = new THREE.Mesh(new THREE.RingGeometry(ZONE.R - 0.7, ZONE.R, 48), new THREE.MeshBasicMaterial({color: ZONER, transparent: true, opacity: 0.95, depthWrite: false, side: THREE.DoubleSide})); rim.rotation.x = -Math.PI / 2; rim.position.y = 0.01; g.add(rim);
  const wave = new THREE.Mesh(new THREE.RingGeometry(0.6, 1.4, 48), new THREE.MeshBasicMaterial({color: 0xfff2c8, transparent: true, opacity: 0.9, depthWrite: false, side: THREE.DoubleSide})); wave.rotation.x = -Math.PI / 2; wave.position.y = 0.02; g.add(wave);
  const Z = {c, g, disc, rim, wave, t: 0, next: 1, spore: 0};
  zones.push(Z);
  // the splat: impact damage on enemies inside; the troodon heals a little per enemy hit
  let hits = 0;
  for (const R of raps) if (R.show && inZone(Z, R)) {
    if (R.ally) { popNum(rapChest(R).add(new THREE.Vector3(0, 5, 0)), "+" + ZONE.HEAL, "heal"); healCrosses(rapChest(R), 5); R.heal = 0.4; }
    else { hits++; popNum(rapChest(R).add(new THREE.Vector3(0, 5, 0)), ZONE.IMPACT, "hit"); R.flinch = 1; R.flash = 0.14; R.flashCol = [1, 0.62, 0.12]; R.push = 1.1; R.pushDir.copy(R.pos).sub(c).setY(0).normalize(); R.slow = 1.1;
      if (!R.tagged) { R.tagged = true; textTag(rapChest(R).add(new THREE.Vector3(0, 12, 0)), "SLOWED −" + ZONE.SLOW + "%", "#ffd38a", 2.6); } }
  }
  if (hits) { const hp = partPoint(mouthParts.skull).add(new THREE.Vector3(0, 6, 0)); selfHeal.push({t: 0.35, n: hits * ZONE.SELF, p: hp}); }
  const v = $("vig"); v.style.background = "radial-gradient(ellipse at center, transparent 55%, rgba(255,170,40,.55))"; v.style.transition = "none"; v.style.opacity = 0.3; requestAnimationFrame(() => { v.style.transition = "opacity .4s"; v.style.opacity = 0; });
}
const selfHeal = [];
function inZone(Z, R) { const d = R.rig.pos.clone().setY(0).distanceTo(Z.c); return d <= ZONE.R + 1.5; }
function updateZones(dt) {
  for (let i = selfHeal.length - 1; i >= 0; i--) { const h = selfHeal[i]; h.t -= dt; if (h.t <= 0) { const p = partPoint(mouthParts.skull).add(new THREE.Vector3(0, 6, 0)); popNum(p, "+" + h.n, "heal"); healCrosses(partPoint(hero.segs.Torso[0]), 4); heroHeal = 0.45; textTag(p.clone().add(new THREE.Vector3(0, 6, 0)), "SELF-HEAL", "#7dff98", 1.2); selfHeal.splice(i, 1); } }
  for (let i = zones.length - 1; i >= 0; i--) {
    const Z = zones[i]; Z.t += dt; const u = Z.t / ZONE.LIFE;
    const wv = Math.min(1, Z.t / 0.35); Z.wave.scale.setScalar(0.5 + wv * (ZONE.R / 1.4)); Z.wave.material.opacity = 0.9 * (1 - wv);
    const fade = u > 0.88 ? Math.max(0, (1 - u) / 0.12) : Math.min(1, Z.t / 0.12);
    Z.disc.material.opacity = (0.27 + 0.07 * Math.sin(Z.t * 7)) * fade; Z.rim.material.opacity = 0.95 * fade;
    Z.spore += dt * 26; while (Z.spore >= 1) { Z.spore -= 1; const a = Math.random() * Math.PI * 2, r = Math.sqrt(Math.random()) * ZONE.R; const s = sprite(T_POD, Math.random() < 0.6 ? ZONER : HEALC, 0.8 + Math.random() * 0.8, true); s.position.set(Z.c.x + Math.cos(a) * r, 0.4, Z.c.z + Math.sin(a) * r); const vy = 4 + Math.random() * 5; addFx(s, 0.9, (o, uu, d) => { o.position.y += vy * d; o.material.opacity = (uu < 0.2 ? uu / 0.2 : 1 - uu) * fade; }); }
    if (Z.t >= Z.next && Z.next <= ZONE.LIFE + 0.01) { Z.next += 1;
      for (const R of raps) if (R.show && inZone(Z, R)) {
        if (R.ally) { popNum(rapChest(R).add(new THREE.Vector3((Math.random() - .5) * 3, 5, 0)), "+" + ZONE.HEAL, "heal"); healCrosses(rapChest(R), 3); R.heal = 0.35; }
        else { popNum(rapChest(R).add(new THREE.Vector3((Math.random() - .5) * 3, 5, 0)), ZONE.DPS, "tick"); R.flinch = Math.max(R.flinch, 0.35); R.flash = 0.07; R.flashCol = [0.55, 0.32, 0.05]; R.slow = 1.1; }
      } }
    if (Z.t >= ZONE.LIFE) { scene.remove(Z.g); zones.splice(i, 1); }
  }
}
// squadmate marker: a blue ring under it and a SQUADMATE tag over it
const allyRing = new THREE.Mesh(new THREE.RingGeometry(5.2, 6, 40), new THREE.MeshBasicMaterial({color: 0x5ab4ff, transparent: true, opacity: 0.85, depthWrite: false, side: THREE.DoubleSide})); allyRing.rotation.x = -Math.PI / 2; scene.add(allyRing);
const allyTag = (() => { const c = document.createElement("canvas"); c.width = 320; c.height = 64; const x = c.getContext("2d"); x.font = `800 28px "Trebuchet MS", system-ui, sans-serif`; const w = x.measureText("SQUADMATE").width + 36; x.fillStyle = "rgba(10,26,48,.82)"; x.beginPath(); x.roundRect ? x.roundRect(160 - w / 2, 8, w, 48, 24) : x.rect(160 - w / 2, 8, w, 48); x.fill(); x.textAlign = "center"; x.fillStyle = "#8fd0ff"; x.fillText("SQUADMATE", 160, 42); const s = new THREE.Sprite(new THREE.SpriteMaterial({map: new THREE.CanvasTexture(c), transparent: true, depthTest: false})); s.renderOrder = 9; s.scale.set(12, 2.4, 1); scene.add(s); return s; })();
let heroHeal = 0;

// ---------- tracks ----------
function place(R, x, z, yaw) { R.show = true; R.pos.set(x, 0, z); R.yaw = yaw; R.path = null; R.run = 0; }
const LEAP = {T0: 0.28, AIR: 0.72, DIST: 30, H: 10};
const HOP = {T0: 0.1, AIR: 0.42, DIST: -18, H: 4};
let leapCfg = LEAP;
function leapOffset(t) {
  const u = (t - leapCfg.T0) / leapCfg.AIR;
  if (u <= 0) return {fwd: 0, up: 0, air: false};
  if (u >= 1) return {fwd: leapCfg.DIST, up: 0, air: false};
  return {fwd: leapCfg.DIST * (u * 0.8 + E.out(u) * 0.2), up: 4 * leapCfg.H * u * (1 - u), air: true};
}
const aim = {on: 0, R: null, cone: null, yaw: 0};
function aimAt(R, cone, on) { aim.R = R; aim.cone = cone; aim.on = on; }
const aimConeT = {A: sectorMesh(46, 30, AIMC, 0.11), B: sectorMesh(60, 30, AIMC, 0.11)};
function zoneScene() { // two enemy raptors and the squadmate fighting them, all inside where the pod lands
  place(S, -8, -34, 0); place(R0, -1, -40, 0); place(R1, 7, -46, 0);
  R0.yaw = yawTo(R0.pos, S.pos); R1.yaw = yawTo(R1.pos, S.pos) + 0.3; S.yaw = yawTo(S.pos, R0.pos);
}
const TRACKS = {
  A() {
    zoneScene();
    const REL = 0.34, FLY = 0.55;
    return {kind: "attack", len: 4.7, frame: [new THREE.Vector3(0, 0, 0), new THREE.Vector3(0, 0, -44)],
      keys: [{t: 0, pose: T_READY}, {t: 0.2, pose: TA_WIND, e: "io"}, {t: 0.27, pose: TA_HOLD, e: "io"}, {t: REL, pose: TA_THROW, e: "in2"}, {t: 0.52, pose: TA_FOLLOW, e: "out"}, {t: 1.15, pose: T_READY, e: "io"}],
      eyes: [[0.05, 1.0]],
      ev: [{t: 0, f: () => { hud.press = 0.3; aimAt(R0, aimConeT.A, 1); }},
           {t: REL, f: () => { hud.charges--; hud.refill = 0; const from = handsPoint();
              throwPod({kind: "pod", from, target: () => R0.pos.clone().setY(1), T: FLY, H: 9, onHit: p => { zoneBurst(p); aim.on = 0; }}); }}],
      cap: [[0, "<b>Tap ATTACK</b> · soft aim: the closest enemy in the 30° cone"], [0.12, "Long arms swing back · <b>the big eyes flare amber</b>"], [REL, "<b>Two-hand fling</b>: a glowing pod lobbed in an arc, ~45 studs"], [REL + FLY, "<b>Splat: 6</b> to each enemy · a 20-stud <b>glow zone</b> for 3 s · troodon <b>+2 per enemy hit</b>"], [REL + FLY + 0.6, "In the zone, once a second: <b>enemies −3 and slowed 25%</b> · <b>squadmate +5</b>"]],
      hud: {mode: "pips", hint: "Tap ATTACK", what: "2 charges (pips) · 1 refills every 3 s"}};
  },
  B() {
    zoneScene();
    const REL = 0.3, FLY = 0.2;
    return {kind: "attack", len: 4.3, frame: [new THREE.Vector3(0, 0, 0), new THREE.Vector3(0, 0, -44)],
      keys: [{t: 0, pose: T_READY}, {t: 0.2, pose: TB_COIL, e: "io"}, {t: REL, pose: TB_SPIT, e: "in2"}, {t: REL + 0.2, pose: addPose(TB_SPIT, {Neck: [-4, 0, 0]}, 1), e: "out"}, {t: 0.95, pose: T_READY, e: "io"}],
      eyes: [[0.05, 0.8]], tremble: [0.18, 0.28],
      ev: [{t: 0, f: () => { hud.press = 0.3; hud.cool = 1; aimAt(R0, aimConeT.B, 1); }},
           {t: REL, f: () => { const from = mouthPoint();
              throwPod({kind: "bolt", from, target: () => rapChest(R0), T: FLY, H: 0.3, onHit: p => { zoneBurst(p); aim.on = 0; }}); }}],
      update(t, dt) { if (t > REL) hud.cool = Math.max(0, hud.cool - dt / 1.2); },
      cap: [[0, "<b>Tap ATTACK</b> · soft aim: the closest enemy in the 30° cone"], [0.15, "Neck coils back · eyes flare"], [REL, "<b>Spit bolt</b>: fast and straight, bursts on the first dino it hits"], [REL + FLY, "<b>Burst: 6</b> to each enemy · the same 20-stud glow zone for 3 s · <b>+2 per enemy hit</b>"], [REL + FLY + 0.6, "Enemies −3/s and slowed 25% · squadmate +5/s · ring = 1.2 s cooldown"]],
      hud: {mode: "cool", hint: "Tap ATTACK", what: "ring = cooldown (1.2 s)"}};
  },
  C() {
    place(R0, -1.5, -15, 0); R0.yaw = yawTo(R0.pos, hero.pos);
    place(R1, 7, -46, 0); place(S, -8, -34, 0); R1.yaw = yawTo(R1.pos, S.pos) + 0.3; S.yaw = yawTo(S.pos, R1.pos);
    const end = new THREE.Vector3(-1, 0, -40);
    R0.path = [[0.55, R0.pos.clone(), R0.yaw, 0], [0.7, R0.pos.clone().add(new THREE.Vector3(-0.3, 0, -2)), yawTo(R0.pos, end), 0.6], [1.25, end.clone(), yawTo(R0.pos, end), 1], [1.5, end.clone(), yawTo(end, S.pos), 0]];
    const H0 = 0.9, REL = 1.4, FLY = 0.55;
    return {kind: "attack", len: 5.3, frame: [new THREE.Vector3(0, 0, 0), new THREE.Vector3(0, 0, -44)],
      keys: [{t: 0, pose: T_READY}, {t: 0.1, pose: TC_RWIND, e: "io"}, {t: 0.18, pose: TC_RAKE, e: "in2"}, {t: 0.32, pose: addPose(TC_RAKE, {ArmL: [-8, 0, 0], ArmR: [-8, 0, 0]}, 1), e: "out"}, {t: 0.72, pose: T_READY, e: "io"},
             {t: H0 + 0.25, pose: TA_WIND, e: "io"}, {t: REL - 0.03, pose: TA_HOLD, e: "io"}, {t: REL, pose: TA_THROW, e: "in2"}, {t: REL + 0.18, pose: TA_FOLLOW, e: "out"}, {t: REL + 0.8, pose: T_READY, e: "io"}],
      eyes: [[H0, REL + 0.6]],
      ev: [{t: 0, f: () => { hud.press = 0.25; }},
           {t: 0.17, f: () => { const p = partPoint(R0.rig.segs.Head[0]).add(new THREE.Vector3(0, 0, 1)); hitStop = 0.08; shake = 0.8; fovPunch = 2; flash(p, 10); sparks(p, new THREE.Vector3(0, 0.3, -1), 14);
              popNum(p.clone().add(new THREE.Vector3(0, 5, 0)), 7, "hit"); R0.flinch = 1; R0.side = 1; R0.flash = 0.12; R0.flashCol = [0.9, 0.1, 0.05]; R0.push = 1.2; R0.pushDir.set(0, 0, -1); }},
           {t: H0, f: () => { hud.held = true; aimAt(R0, aimConeT.A, 1); }},
           {t: REL, f: () => { hud.held = false; hud.hold = 0; const from = handsPoint();
              throwPod({kind: "pod", from, target: () => R0.pos.clone().setY(1), T: FLY, H: 9, onHit: p => { zoneBurst(p); aim.on = 0; }}); }}],
      update(t, dt) { if (hud.held) hud.hold = Math.min(1, (t - H0) / 0.4); },
      cap: [[0, "<b>Tap ATTACK: claw rake</b> with both long arms (close range)"], [0.2, "<b>Rake: 7</b> · the raptor backs off"], [H0, "<b>Hold ATTACK</b>: arms swing back, eyes flare, ring fills (0.4 s) · soft aim locks the closest enemy"], [REL, "<b>Let go: pod fling</b>, lobbed ~45 studs"], [REL + FLY, "<b>Splat: 6</b> · 20-stud glow zone for 3 s · +2 per enemy hit · squadmate +5/s"]],
      hud: {mode: "hold", hint: "Tap = claw rake · Hold + let go = pod", what: "ring = hold charge (0.4 s) · pod cooldown 2 s"}};
  },
  J1() {
    R0.show = false; R1.show = false; S.show = false; leapCfg = LEAP;
    const t1 = LEAP.T0 + LEAP.AIR;
    return {kind: "jump", leap: true, len: 2.3, frame: [new THREE.Vector3(0, 0, 4), new THREE.Vector3(0, 0, -LEAP.DIST - 4)],
      keys: [{t: 0, pose: T_READY}, {t: LEAP.T0, pose: TJ_CROUCH, e: "io"}, {t: LEAP.T0 + 0.1, pose: TJ_PUSH, e: "out"}, {t: LEAP.T0 + 0.3, pose: TJ_AIR, e: "io"}, {t: t1 - 0.14, pose: TJ_AIR, e: "io"},
             {t: t1 - 0.02, pose: TJ_DOWN, e: "io"}, {t: t1 + 0.12, pose: TJ_LAND, e: "out"}, {t: t1 + 0.7, pose: T_READY, e: "io"}],
      ev: [{t: 0, f: () => { hud.jpress = 0.3; }}, {t: t1, f: () => { textTag(hero.pos.clone().add(new THREE.Vector3(0, 1.5, -4)), "plain landing", "#ffffff", 1.1); }}],
      cap: [[0, "<b>Tap JUMP</b>: crouch"], [LEAP.T0, "<b>Leap</b>: ~30 studs forward, arms tucked up"], [t1, "<b>Plain landing</b>: no dust, no shockwave (house rule)"]],
      hud: {mode: "jump", hint: "Tap JUMP", what: "the raptor / dilo leap: 0.5 s cooldown, no charges"}};
  },
  J2() {
    leapCfg = HOP; R1.show = false; S.show = false;
    place(R0, 0, -34, 0); R0.yaw = yawTo(R0.pos, hero.pos);
    R0.path = [[0, R0.pos.clone(), R0.yaw, 1], [0.42, new THREE.Vector3(0, 0, -11), R0.yaw, 1], [0.62, new THREE.Vector3(0, 0, -6), R0.yaw, 0.3], [0.9, new THREE.Vector3(0, 0, -6), R0.yaw, 0]];
    const t1 = HOP.T0 + HOP.AIR;
    return {kind: "jump", leap: true, len: 2.6, frame: [new THREE.Vector3(0, 0, 18), new THREE.Vector3(0, 0, -30)],
      keys: [{t: 0, pose: T_READY}, {t: HOP.T0, pose: TH_SET, e: "io"}, {t: HOP.T0 + 0.12, pose: TH_AIR, e: "out"}, {t: t1 - 0.06, pose: TH_AIR, e: "io"}, {t: t1 + 0.1, pose: TJ_LAND, e: "out"}, {t: t1 + 0.6, pose: T_READY, e: "io"}],
      ev: [{t: 0, f: () => { hud.jpress = 0.3; }},
           {t: 0.5, f: () => { R0.lunge = 1; }},
           {t: 0.58, f: () => { textTag(new THREE.Vector3(0, 9, -2), "MISS", "#ffffff", 1.1); }},
           {t: t1, f: () => { textTag(hero.pos.clone().add(new THREE.Vector3(0, 1.5, 4)), "plain landing", "#ffffff", 1.1); }}],
      cap: [[0, "A raptor charges in · <b>tap JUMP</b>"], [HOP.T0, "<b>Evade Hop</b>: a quick low hop ~18 studs <b>back</b>, still facing the fight"], [0.5, "The raptor's bite <b>misses</b>"], [t1, "<b>Plain landing</b> · 2 hops, 1 refills every 4 s"]],
      hud: {mode: "jump", hint: "Tap JUMP", what: "2 hop charges, 1 refills every 4 s"}};
  },
};

// ---------- state ----------
let attack = "A", jump = "J1", camMode = "hero", slowMo = false, seq = "attack";
let play = null, hitStop = 0, shake = 0, clockT = 0, idleT = 0, fovPunch = 0;
const hud = {mode: "pips", charges: 2, refill: 1, cool: 0, hold: 0, held: false, press: 0, jpress: 0};
function resetFx() { fx.splice(0).forEach(e => scene.remove(e.obj)); tshots.splice(0).forEach(s => { scene.remove(s.mesh); scene.remove(s.glow); }); zones.splice(0).forEach(Z => scene.remove(Z.g)); selfHeal.splice(0); }
function start(kind) {
  resetFx(); seq = kind;
  const key = kind === "attack" ? attack : jump;
  for (const R of raps) { R.flinch = 0; R.flash = 0; R.push = 0; R.slow = 0; R.tagged = false; R.path = null; R.run = 0; R.heal = 0; R.lunge = 0; }
  leapCfg = LEAP;
  const track = TRACKS[key]();
  play = {track, t: 0, fired: new Set(), key, kind, cap: -1};
  Object.assign(hud, {mode: track.hud.mode, held: false, hold: 0, press: 0, jpress: 0, cool: 0, charges: 2, refill: 1});
  for (const k in aimConeT) aimConeT[k].visible = false; for (const k in aimCone) aimCone[k].visible = false;
  aim.on = 0; aim.R = null; aim.cone = null;
  $("hudHint").textContent = track.hud.hint; $("hudWhat").textContent = track.hud.what;
  $("tag").textContent = (kind === "attack" ? "Attack " : "Jump ") + key + " · " + INFO[key].name;
  hero.pos.set(0, 0, 0); rootSpring.x = 0; rootSpring.v = 0;
}
function idleLayer(t) {
  const b = Math.sin(t * 2.3), b2 = Math.sin(t * 2.3 + 1.2);
  return {RootJoint: [b * 1.0, 0, 0], Neck: [b * 1.6, Math.sin(t * 0.8) * 5, 0], Head: [-b * 1.4, Math.sin(t * 1.1 + 1) * 5, 0], Jaw: [Math.max(0, Math.sin(t * 0.5)) * -2, 0, 0],
    ArmL: [b2 * 3, 0, 0], ArmR: [b2 * 3, 0, 0],
    Tail1: [b * 1.2, Math.sin(t * 1.3) * 4, 0], Tail2: [0, Math.sin(t * 1.3 - .6) * 5, 0], Tail3: [0, Math.sin(t * 1.3 - 1.2) * 6, 0], Tail4: [0, Math.sin(t * 1.3 - 1.8) * 7, 0], Tail5: [0, Math.sin(t * 1.3 - 2.4) * 8, 0]};
}
function inWin(list, t) { return (list || []).some(([a, b]) => t >= a && t < b); }
function rapPose(R, dt) {
  R.rig.g.visible = R.show; if (!R.show) return;
  const tt = play ? play.t : 0;
  if (R.path && play) {
    const P = R.path; let i = 0; while (i < P.length - 1 && tt > P[i + 1][0]) i++;
    if (tt <= P[0][0]) { R.pos.copy(P[0][1]); R.yaw = P[0][2]; R.run = P[0][3]; }
    else if (i >= P.length - 1) { R.pos.copy(P[P.length - 1][1]); R.yaw = P[P.length - 1][2]; R.run = 0; }
    else { const a = P[i], b = P[i + 1], u = (tt - a[0]) / (b[0] - a[0]); R.pos.lerpVectors(a[1], b[1], u); let dy = b[2] - a[2]; while (dy > Math.PI) dy -= 2 * Math.PI; while (dy < -Math.PI) dy += 2 * Math.PI; R.yaw = a[2] + dy * E.io(Math.min(1, u * 1.6)); R.run = a[3] + (b[3] - a[3]) * u; }
  }
  const slowK = R.slow > 0 ? 0.55 : 1;
  R.flinch = Math.max(0, R.flinch - dt * 2.6); R.flash = Math.max(0, R.flash - dt); R.push *= Math.pow(0.03, dt); R.slow = Math.max(0, R.slow - dt); R.heal = Math.max(0, (R.heal || 0) - dt); R.lunge = Math.max(0, (R.lunge || 0) - dt * 2.2);
  R.runPh += dt * 15 * R.run * slowK;
  const f = E.out(R.flinch), s = Math.sin(R.runPh), c = Math.cos(R.runPh), rn = R.run, l = Math.sin(Math.min(1, R.lunge) * Math.PI);
  const ct = clockT * slowK;
  R.rig.yaw = R.yaw; R.rig.pos.copy(R.pos).addScaledVector(R.pushDir, R.push);
  pose(R.rig, {RootJoint: [10 * f - 6 * rn - 14 * l, 0, R.side * 8 * f], Neck: [12 * f - 4 * rn - 22 * l, R.side * -18 * f + Math.sin(ct * 0.8) * 4 * (1 - f), 0], Head: [10 * f, 0, 0], Jaw: [-22 * f - 34 * l, 0, 0],
    ArmL: [-25 * f + 20 * l, 0, 0], ArmR: [-25 * f + 20 * l, 0, 0], Tail1: [-10 * f, Math.sin(ct * 1.3) * 4, 0], Tail2: [0, Math.sin(ct * 1.3 - .7) * 5, 0],
    LegL: [-8 * f + 34 * s * rn, 0, 0], LegR: [-8 * f - 34 * s * rn, 0, 0], KneeL: [-10 * f - (18 + 22 * Math.max(0, c)) * rn, 0, 0], KneeR: [-10 * f - (18 + 22 * Math.max(0, -c)) * rn, 0, 0]});
  if (R.rig.rest !== null) { R.rig.y = R.rig.rest + Math.abs(c) * 1.2 * rn; pose(R.rig, {}); }
  const g = R.slow > 0 ? 0.12 : 0, h = R.heal > 0 ? R.heal / 0.4 : 0, fl = R.flash > 0 ? 1 : 0;
  R.rig.mats.forEach(m => m.emissive.setRGB(fl * R.flashCol[0] + (1 - fl) * (g * 0.9 + h * 0.05), fl * R.flashCol[1] + (1 - fl) * (g * 0.55 + h * 0.55), fl * R.flashCol[2] + (1 - fl) * (h * 0.12)));
}
raps.forEach(R => { pose(R.rig, {}); R.rig.y = R.rig.rest; R.rig.g.visible = false; });

function step(dt) {
  if (slowMo) dt *= 0.3;
  let mdt = dt;
  if (hitStop > 0) { hitStop -= dt; mdt = dt * 0.05; }
  idleT += mdt; clockT += mdt;
  let target = idleLayer(idleT), leap = {fwd: 0, up: 0, air: false}, rootFwd = 0, eyes = 0;
  const tr = play && play.track;
  if (play) {
    play.t = Math.min(play.t + mdt, tr.len);
    const mv = sample(tr.keys, play.t);
    target = addPose(mv, target, 1);
    if (tr.tremble && play.t > tr.tremble[0] && play.t < tr.tremble[1]) for (const n of ["Neck", "Head"]) target[n] = target[n].map((v, i) => v + (i === 0 ? Math.sin(clockT * 80 + n.length) * 1.6 : 0));
    rootFwd = (mv.root && mv.root.fwd) || 0;
    if (tr.leap) leap = leapOffset(play.t);
    for (const e of tr.ev) { const k = "e" + e.t; if (!play.fired.has(k) && play.t >= e.t) { play.fired.add(k); e.f(); } }
    if (tr.update) tr.update(play.t, mdt);
    let ci = -1; tr.cap.forEach((c, i) => { if (play.t >= c[0]) ci = i; });
    if (ci !== play.cap) { play.cap = ci; $("cap").innerHTML = ci >= 0 ? tr.cap[ci][1] : ""; }
    eyes = inWin(tr.eyes, play.t) ? 1 : 0;
    if (play.t >= tr.len && !window.__manual) { if (seq === "attack") start("jump"); else start("attack"); }
  }
  let aimYaw = 0;
  if (aim.R && aim.R.show) aimYaw = deg(yawTo(hero.pos, aim.R.rig.pos));
  aim.yaw += ((aim.on ? aimYaw : 0) - aim.yaw) * Math.min(1, dt * 12);
  target.Neck = (target.Neck || [0, 0, 0]).map((v, i) => i === 1 ? v + aim.yaw * 0.4 : v); target.Head = (target.Head || [0, 0, 0]).map((v, i) => i === 1 ? v + aim.yaw * 0.35 : v);
  const P = springStep(target, mdt);
  for (let i = 0, n = Math.max(1, Math.ceil(mdt * 300)); i < n; i++) { const h = mdt / n; rootSpring.v += (400 * (rootFwd - rootSpring.x) - 2 * 0.9 * 20 * rootSpring.v) * h; rootSpring.x += rootSpring.v * h; }
  hero.yaw = 0; hero.pos.set(0, 0, -(rootSpring.x + leap.fwd));
  hero.y = 0; pose(hero, P);
  let minY = Infinity;
  for (const p of heroFeet) for (let i = 0; i < 8; i++) { _c.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(p.mesh.matrix); minY = Math.min(minY, _c.y); }
  hero.y = -minY + leap.up; pose(hero, P);
  // the Night Watcher's eyes flare amber while it throws; a green pulse when it heals itself
  heroGlow.e += ((eyes ? 1 : 0) - heroGlow.e) * Math.min(1, dt * 14);
  if (eyeMat) eyeMat.emissive.setRGB(0.85 * heroGlow.e, 0.42 * heroGlow.e, 0.02 * heroGlow.e);
  heroHeal = Math.max(0, heroHeal - mdt); const hh = heroHeal / 0.45;
  hero.mats.forEach(m => { if (m !== eyeMat) m.emissive.setRGB(0.02 * hh, 0.4 * hh, 0.08 * hh); });
  raps.forEach(R => rapPose(R, mdt));
  allyRing.visible = allyTag.visible = S.show;
  if (S.show) { allyRing.position.set(S.rig.pos.x, 0.13, S.rig.pos.z); allyTag.position.copy(rapChest(S)).add(new THREE.Vector3(0, 10, 0)); }
  const aimFade = Math.min(1, aim.on);
  for (const k in aimConeT) { const g = aimConeT[k]; const on = aim.on && aim.cone === g; setCone(g, on, aimFade); if (on) { g.position.x = hero.pos.x; g.position.z = hero.pos.z; } }
  if (aim.on && aim.R && aim.R.show) {
    const a = hero.pos.clone(), b = aim.R.rig.pos.clone(); const L = a.distanceTo(b) - 6;
    aimLine.visible = true; aimLine.scale.set(1, Math.max(0.1, L - 8), 1); dashTex.repeat.set(1, Math.max(1, (L - 8) / 3.2)); dashTex.offset.y = -clockT * 2.2; aimLineG.position.set(a.x, 0.11, a.z); aimLineG.rotation.y = yawTo(a, b); aimLine.position.set(0, 0, -(8 + (L - 8) / 2));
    aimLine.material.opacity = 0.95 * aimFade;
    reticle.visible = true; reticle.position.set(b.x, 0.12, b.z); reticle.scale.setScalar(1 + 0.08 * Math.sin(clockT * 8));
  } else { aimLine.visible = false; reticle.visible = false; }
  updatePods(mdt); updateZones(mdt);
  for (let i = fx.length - 1; i >= 0; i--) { const e = fx[i]; const fdt = dt * (hitStop > 0 ? 0.2 : 1); e.t += fdt; const u = Math.min(1, e.t / e.life); e.update(e.obj, u, fdt); if (u >= 1) { scene.remove(e.obj); fx.splice(i, 1); } }
  hud.press = Math.max(0, hud.press - mdt); hud.jpress = Math.max(0, hud.jpress - mdt);
  if (hud.mode === "pips" && hud.charges < 2) { hud.refill += mdt / 3; if (hud.refill >= 1) { hud.charges++; hud.refill = hud.charges < 2 ? 0 : 1; } }
  drawHud();
  shake = Math.max(0, shake - dt * 4.2); fovPunch = Math.max(0, fovPunch - dt * 14);
  const fr = tr ? tr.frame : [new THREE.Vector3(), new THREE.Vector3(0, 0, -30)];
  const mid = fr[0].clone().lerp(fr[1], 0.5).setY(9), span = fr[0].distanceTo(fr[1]) + 30;
  const hfov = 2 * Math.atan(Math.tan(rad(cam.fov / 2)) * cam.aspect), vfit = span * 0.5 / Math.tan(hfov / 2);
  let cp, look = mid;
  if (camMode === "hero") cp = mid.clone().add(new THREE.Vector3(-1, 0.4, -0.16).normalize().multiplyScalar(vfit * 1.08));
  else if (camMode === "side") cp = mid.clone().add(new THREE.Vector3(-1, 0.14, 0).normalize().multiplyScalar(vfit * 1.1));
  else if (camMode === "game") { cp = hero.pos.clone().add(new THREE.Vector3(-10, 30, 44)); look = hero.pos.clone().add(new THREE.Vector3(0, 8, -26)); }
  else { const h = partPoint(mouthParts.skull); cp = h.clone().add(new THREE.Vector3(-15, 3, -15)); look = h.clone().add(new THREE.Vector3(0, -3, 0)); }
  camPos.lerp(cp, camMode === "close" ? 0.3 : 0.15); camLook.lerp(look, camMode === "close" ? 0.35 : 0.2);
  const sh = shake * shake * 1.0;
  cam.position.copy(camPos).add(new THREE.Vector3((Math.random() - .5) * sh, (Math.random() - .5) * sh, (Math.random() - .5) * sh));
  cam.lookAt(camLook); cam.fov = 38 + fovPunch; cam.updateProjectionMatrix();
  sun.position.copy(mid).add(new THREE.Vector3(-30, 70, 30)); sun.target.position.copy(mid);
  renderer.render(scene, cam);
}
const heroGlow = {e: 0};
const camPos = new THREE.Vector3(-60, 26, -20), camLook = new THREE.Vector3(0, 9, -20);

// ---------- HUD strip ----------
const ringC = 2 * Math.PI * 46;
function drawHud() {
  const atk = $("hAtk"), jmp = $("hJump"), ring = $("ring"), pips = $("pips");
  atk.classList.toggle("on", hud.press > 0.001 || hud.held);
  jmp.classList.toggle("on", hud.jpress > 0.001);
  let ringV = 0, col = "#ffb43a";
  if (hud.mode === "cool") { ringV = 1 - hud.cool; }
  else if (hud.mode === "hold") { ringV = hud.hold; col = "#ffffff"; }
  ring.setAttribute("stroke", col); ring.setAttribute("stroke-dashoffset", String(ringC * (1 - ringV)));
  ring.parentNode.style.display = hud.mode === "cool" || hud.mode === "hold" ? "" : "none";
  atk.classList.toggle("dim", (hud.mode === "pips" && hud.charges === 0) || (hud.mode === "cool" && hud.cool > 0));
  const want = attack === "A" ? 2 : 0;
  if (pips.childElementCount !== want) { pips.innerHTML = ""; for (let i = 0; i < want; i++) { const q = document.createElement("div"); q.className = "pip"; q.innerHTML = "<i></i>"; pips.appendChild(q); } }
  [...pips.children].forEach((q, i) => { const h = i < hud.charges ? 100 : i === hud.charges ? Math.round(Math.min(1, hud.refill) * 100) : 0; q.firstChild.style.height = h + "%"; });
}

// ---------- UI ----------
const ZTXT = "Zone: 20 studs wide, 3 s · enemies inside: 6 on the splat, then 3/s and slowed 25% (15 total) · squadmates inside: +5/s (+15 with the splat tick) · the troodon heals +2 per enemy the splat hits";
const INFO = {
  A: {name: "Glow Pod Toss", input: "Tap ATTACK",
    look: "Both long drooping arms swing down and back and the big eyes flare amber; then it flings a glowing pod underarm with both hands. The pod arcs over and splats into a teal glowing zone with a bright rim and spores drifting up. Enemies standing in it flash orange and slow down; squadmates in it get green crosses and heal numbers.",
    nums: [ZTXT, "Range ~45 studs, lobbed arc (~0.55 s flight): it can land behind a squadmate's back or over a rock", "Soft aim: lands on the closest enemy within 30° of facing, else ~45 studs ahead", "2 charges (pips under ATTACK), 1 refills every 3 s", "~0.35 s from tap to the pod leaving the hands"],
    trade: "Uses the troodon's own body (the long arms: no other dino throws), and the arc drops the zone on a group or over cover. The slow arc can be walked out of at long range, and it has no close-range answer: up close you jump away."},
  B: {name: "Spit Bolt", input: "Tap ATTACK",
    look: "The neck coils back, the eyes flare, and it snaps forward spitting a fast, straight amber bolt that bursts into the same glow zone on the first dino it hits (or on the ground at max range).",
    nums: [ZTXT, "Range ~60 studs, straight and fast (~0.2 s)", "Soft aim: closest enemy within 30°", "Cooldown 1.2 s (ring on ATTACK)"],
    trade: "Easiest to land and the fastest to fire, but it looks and feels like the Dilo's spit dart (two spitters in the roster), and a straight shot stops on the first dino in the way, so it can't drop the zone behind a squadmate."},
  C: {name: "Claw Rake + Pod", input: "Tap = claw rake · Hold + let go = pod",
    look: "Tap ATTACK for a quick two-arm rake in front. Hold ATTACK and the arms swing back, the eyes flare and the ring on the button fills; let go and it flings the glow pod like A.",
    nums: ["Rake: 7 damage, ~10 studs in front, tap", "Pod: hold 0.4 s, let go · " + ZTXT, "Pod cooldown 2 s (proposed); the rake has none beyond its 0.35 s swing", "Soft aim on the pod: closest enemy within 30°"],
    trade: "Has something for close range, but two moves on one button (the same tap vs hold as the Dilo), and the 0.4 s hold makes every zone slower to start. A support that is busy raking is not keeping its zone on the fight."},
  J1: {name: "Leap", input: "Tap JUMP",
    look: "Crouch, spring ~30 studs forward with the long arms tucked up, and land plainly: no dust, no shockwave.",
    nums: ["~30-stud leap, ~0.7 s in the air", "No damage", "Same jump as the Raptor and the Dilo: 0.5 s cooldown, no charges (JumpServer reused as is)"],
    trade: "Consistent with the other leaping dinos and nothing new to build. It moves you toward the fight, not away from it."},
  J2: {name: "Evade Hop", input: "Tap JUMP",
    look: "A quick low hop ~18 studs straight back, still facing the fight, so whatever was lunging at it bites air. Plain landing.",
    nums: ["~18 studs back, ~0.4 s in the air, low (~4 studs high)", "No damage", "2 hop charges, 1 refills every 4 s (proposed)"],
    trade: "Fits a dino that wants to stay at range and keep its zone on the fight, and it's a real dodge. New jump behaviour (backwards), so it is more to build and test than J1; it can't jump up onto ledges as well as a forward leap."},
};
const REC = {A: true, J2: true};
function infoCard(k, kind) {
  const I = INFO[k];
  return `<div class="kind">${kind} · ${I.input}</div><h2>${k} · ${I.name}${REC[k] ? '<span class="badge">Recommended</span>' : ""}</h2>
    <h3>What it looks like</h3><p>${I.look}</p><h3>Numbers</h3><ul>${I.nums.map(n => `<li>${n}</li>`).join("")}</ul><h3>Trade-off</h3><p>${I.trade}</p>`;
}
function setPressed(sel, attr, v) { document.querySelectorAll(sel).forEach(b => b.setAttribute("aria-pressed", b.dataset[attr] === v)); }
function info() { $("infoAtk").innerHTML = infoCard(attack, "Attack"); $("infoJump").innerHTML = infoCard(jump, "Jump"); setPressed("[data-attack]", "attack", attack); setPressed("[data-jump]", "jump", jump); }
document.querySelectorAll("[data-attack]").forEach(b => b.onclick = () => { attack = b.dataset.attack; info(); start("attack"); });
document.querySelectorAll("[data-jump]").forEach(b => b.onclick = () => { jump = b.dataset.jump; info(); start("jump"); });
document.querySelectorAll("[data-cam]").forEach(b => b.onclick = () => { camMode = b.dataset.cam; setPressed("[data-cam]", "cam", camMode); });
$("again").onclick = () => start(seq); $("runAtk").onclick = () => start("attack"); $("runJump").onclick = () => start("jump");
$("slow").onclick = e => { slowMo = !slowMo; e.currentTarget.setAttribute("aria-pressed", slowMo); };
function resize() { const w = cv.clientWidth, h = cv.clientHeight; renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); }
window.addEventListener("resize", resize);
let last = performance.now();
function loop(now) { const dt = Math.min(0.05, (now - last) / 1000); last = now; if (!window.__manual) step(dt); requestAnimationFrame(loop); }
resize(); info(); setPressed("[data-cam]", "cam", camMode); start("attack");
requestAnimationFrame(loop);
window.__ready = true;
window.__setup = (a, j, kind, cm) => { window.__manual = true; attack = a || attack; jump = j || jump; camMode = cm || "hero"; info(); setPressed("[data-cam]", "cam", camMode); start(kind || "attack"); play = null; for (let i = 0; i < 40; i++) step(1 / 30); start(kind || "attack"); };
window.__step = dt => step(dt);
window.__len = () => play ? play.track.len : 0;
window.__t = () => play ? play.t : 0;
