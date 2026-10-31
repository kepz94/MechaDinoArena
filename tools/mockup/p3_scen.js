// ---------- scenario state ----------
let T = 0, sc = {pulse: 0};
const quills = []; function updateQuills() {}
const props = [], spikes = [], blobs = [], puddles = [];
function stepIdx() { return slotted ? step : -1; }
function setDinoGlow(k) { for (const key in matCache) if (matCache[key].emissive) matCache[key].emissive.setRGB(0, k * 0.55, k * 0.3); }
function flashParts(k) { const w = new THREE.Color(0xffffff); for (const e of equip) if (e.flash) e.mesh.material.color.setHex(e.base).lerp(w, k); }
function prop(m) { world.add(m); props.push(m); return m; }
function box(s, c, o) { o = o || {}; return new THREE.Mesh(new THREE.BoxGeometry(s[0], s[1], s[2]), o.glow ? new THREE.MeshBasicMaterial({color: c, transparent: true, opacity: o.alpha || 1}) : new THREE.MeshLambertMaterial({color: c, transparent: true, opacity: o.alpha || 1})); }
function reset() {
  clearFx(); props.forEach(m => world.remove(m)); props.length = 0; spikes.length = 0; blobs.length = 0; puddles.length = 0;
  T = 0; deploy = 0; lid = 0; capPop = 0; setDinoGlow(0); flashParts(0);
  const P = PARTS[part].id;
  sc = {x: 0, alt: 0, phase: 0, mode: "idle", done: {}, meHp: 30, z: 0, pulse: 0, spd: 0, rattle: 0, spin: 0, kick: 0, drain: 0, plunge: 0, pips: 2, glow: 0};
  bots.forEach(b => { b.g.visible = false; b.hp = 200; b.flash = b.knock = 0; b.ko = 0; b.g.rotation.set(0, Math.PI, 0); b.body.rotation.set(0, 0, 0); b.body.position.set(0, 0, 0);
    b.slowUntil = 0; b.bleedUntil = 0; b.tick = 0; b.gooed = 0; b.spd = 0; b.said = 0; });
  if (P === "caltrops") { sc.x = -6; sc.mode = "run"; sc.spd = 6; const b = bots[0]; b.g.visible = true; b.g.position.set(-15, 0, 0); b.g.rotation.y = 0; b.spd = 6.6; b.lastHit = -9; }
  if (P === "blob") { sc.x = -10; [[8, -1.6], [11.5, 2.2]].forEach(([x, z], i) => { const b = bots[i]; b.g.visible = true; b.g.position.set(x, 0, z); b.spd = 1.8; });
    sc.target = new THREE.Vector3(5.2, 0, 0); }
  if (P === "adren") { sc.x = -6; sc.meHp = 16; sc.pips = 0; const b = bots[0]; b.g.visible = true; b.g.position.set(-12.4, 0, 0); b.g.rotation.y = 0; b.spd = 6; }
  tree.visible = false;
}
const RUN = 58.5 / 2;
function poseFor(dt) {
  const P = PARTS[part].id;
  if (labView) return scurry(0, 0);
  let o;
  if (sc.mode === "run") { sc.phase += Math.min(S.MaxHz * 2 * Math.PI, sc.spd / S.Stride * 2 * Math.PI) * dt; o = scurry(sc.phase, Math.min(1, sc.spd / RUN + 0.45)); }
  else o = scurry(sc.phase, 0);
  const b = Math.sin(T * 3) * 2; add(o, "Neck", b); add(o, "Tail2", b);
  if (P === "caltrops" && sc.rattle > 0) { add(o, "Tail1", 8 * sc.rattle * Math.sin(T * 40)); add(o, "Tail2", -10 * sc.rattle); }
  if (P === "blob" && sc.fireAt !== undefined) { const t = T - sc.fireAt;
    if (look === 0) { const k = t >= 0 && t < 0.35 ? 1 - t / 0.35 : 0; add(o, "RootJoint", -7 * k); add(o, "Neck", -6 * k); }
    else { const w = t > -0.3 && t < 0 ? (t + 0.3) / 0.3 : 0, s = t >= 0 && t < 0.4 ? 1 - t / 0.4 : 0;
      add(o, "RootJoint", 14 * w - 4 * s); add(o, "Neck", 18 * w - 14 * s); add(o, "Head", -8 * w + 6 * s); add(o, "Jaw", -14 * w - 34 * s); } }
  if (P === "adren" && sc.shotAt !== undefined) { const t = T - sc.shotAt, k = t >= 0 && t < 0.6 ? Math.sin(Math.PI * t / 0.6) : 0;
    add(o, "RootJoint", 12 * k); add(o, "Neck", 20 * k); add(o, "Head", -10 * k); add(o, "Jaw", -32 * k); add(o, "ArmL", -30 * k, 0, -20 * k); add(o, "ArmR", -30 * k, 0, 20 * k); }
  if (sc.flinch) { add(o, "RootJoint", 10 * sc.flinch); add(o, "Neck", 12 * sc.flinch); sc.flinch = Math.max(0, sc.flinch - dt * 4); }
  return o;
}
function chest(b) { return new THREE.Vector3(b.g.position.x, 2.8, b.g.position.z); }
function walkBot(b, spd, dt) { const dir = b.g.rotation.y === 0 ? 1 : -1; b.g.position.x += dir * spd * dt; b.walk = (b.walk || 0) + spd * dt; b.body.position.y = Math.abs(Math.sin(b.walk * 1.4)) * 0.18; }
// ---- caltrops ----
function makeSpike() { const g = new THREE.Group();
  [[0, 0, 0], [0, Math.PI / 2, 0], [Math.PI / 2, 0, 0]].forEach(r => { const a = box([0.2, 1.1, 0.2], BRIGHT); a.rotation.set(r[0], r[1], r[2] + 0.6); g.add(a); });
  [[0, 0.33, 0], [0, -0.33, 0]].forEach(p => { const t = box([0.26, 0.26, 0.26], 0xff2a3a, {glow: true}); t.position.set(p[0], p[1] * 1.75, p[2]); g.children[0].add(t); });
  return prop(g); }
function dropSpikes() {
  const si = stepIdx(), n = si >= 1 ? 10 : 6, r = si >= 1 ? 3.5 : 2.5, c = new THREE.Vector3(sc.x - 4.8, 0, 0); sc.patchX = c.x;
  const srcs = look === 0 ? [partWorld("Tail1_main", [0, 0.85, 0])] : [partWorld("Torso_hips", [-0.05, -0.02, 0.6]), partWorld("Torso_hips", [-0.05, -0.02, -0.6])];
  for (let i = 0; i < n; i++) { const a = i * 2.39996, d = r * Math.sqrt((i + 0.5) / n);
    const to = new THREE.Vector3(c.x + Math.cos(a) * d, 0.18, c.z + Math.sin(a) * d), from = srcs[i % srcs.length].clone();
    spikes.push({m: makeSpike(), from, to, t0: T + i * 0.04, tt: 0.4 + (i % 3) * 0.08, armed: false, used: false}); }
  pop(`CALTROPS ×${n}`, "#ff6a5a", 28, partWorld("Head_cranium", [0, 2.6, 0]), 0.9);
}
// ---- blob ----
function ring(r, color) { const g = new THREE.Group(); const n = 28;
  for (let i = 0; i < n; i++) { if (i % 2) continue; const a = i / n * Math.PI * 2, m = box([0.5, 0.06, 0.16], color, {glow: true, alpha: 0.9}); m.position.set(Math.cos(a) * r, 0.05, Math.sin(a) * r); m.rotation.y = -a + Math.PI / 2; g.add(m); }
  return prop(g); }
function blobTargets() { const si = stepIdx(), r = si >= 1 ? 5.5 : 4; return si >= 2 ? [new THREE.Vector3(sc.target.x, 0, -r * 0.85), new THREE.Vector3(sc.target.x, 0, r * 0.85)] : [sc.target.clone()]; }
function fireBlobs() {
  const from = look === 0 ? partWorld("Torso_hump", [0.62, 1.45, 0]) : partWorld("Head_snout", [0.9, 0.02, 0]);
  blobTargets().forEach((to, i) => { const g = new THREE.Group();
    for (let k = 0; k < 4; k++) { const m = box([0.9 - k * 0.15, 0.9 - k * 0.15, 0.9 - k * 0.15], k % 2 ? GOO_D : GOO, {glow: k % 2 === 0}); m.position.set((Math.random() - .5) * 0.4, (Math.random() - .5) * 0.4, (Math.random() - .5) * 0.4); g.add(m); }
    prop(g); g.position.copy(from); blobs.push({g, from: from.clone(), to, t0: T + i * 0.12, tt: 0.85, landed: false}); });
  sc.kick = 1; pop(look === 0 ? "THUMP!" : "PTOO!", "#c8ff6a", 30, from.clone().add(new THREE.Vector3(0, 1.6, 0)), 0.7);
}
function splat(at) {
  const si = stepIdx(), r = si >= 1 ? 5.5 : 4, life = si >= 3 ? 8 : 5;
  const g = new THREE.Group();
  const disc = new THREE.Mesh(new THREE.CylinderGeometry(r, r, 0.08, 40), new THREE.MeshBasicMaterial({color: GOO, transparent: true, opacity: 0.78})); disc.position.y = 0.05; g.add(disc);
  const rim = new THREE.Mesh(new THREE.CylinderGeometry(r + 0.25, r + 0.25, 0.05, 40), new THREE.MeshBasicMaterial({color: GOO_D, transparent: true, opacity: 0.8})); rim.position.y = 0.03; g.add(rim);
  const bub = []; for (let i = 0; i < 14; i++) { const a = Math.random() * Math.PI * 2, d = Math.random() * r * 0.9, m = box([0.35, 0.35, 0.35], i % 2 ? 0xd6ff8a : GOO, {glow: true}); m.position.set(Math.cos(a) * d, 0.1, Math.sin(a) * d); g.add(m); bub.push({m, ph: Math.random() * 6}); }
  g.position.set(at.x, 0, at.z); g.scale.set(0.05, 1, 0.05); prop(g);
  puddles.push({g, c: at.clone(), r, t0: T, until: T + life, bub, disc, rim, life});
  for (let i = 0; i < 18; i++) { const a = Math.random() * Math.PI * 2; bit(at.clone().add(new THREE.Vector3(0, 0.4, 0)), i % 2 ? GOO : GOO_D, new THREE.Vector3(Math.cos(a) * 9, 4 + Math.random() * 5, Math.sin(a) * 9), 0.6, -22, 0.35, {glow: true}); }
  pop("SPLAT!", "#c8ff6a", 34, at.clone().add(new THREE.Vector3(0, 3, 0)), 0.8);
}
function inGoo(p) { for (const q of puddles) if (T < q.until && Math.hypot(p.x - q.c.x, p.z - q.c.z) <= q.r) return true; return false; }
function stepScenario(dt) {
  const P = PARTS[part].id, si = stepIdx(); T += dt;
  const [b0, b1] = bots;
  sc.kick = Math.max(0, sc.kick - dt * 3);
  if (P === "caltrops") {
    sc.x += sc.spd * dt;
    if (slotted && T > 0.7 && !sc.done.drop) { sc.done.drop = 1; tileFlash(); sc.rattle = 1; sc.cdAt = T; dropSpikes(); }
    sc.rattle = Math.max(0, sc.rattle - dt * 2); sc.spin += dt * 24 * sc.rattle;
    for (const s of spikes) { const u = (T - s.t0) / s.tt;
      if (u < 0) { s.m.visible = false; continue; } s.m.visible = !s.used;
      if (u < 1) { s.m.position.copy(s.from).lerp(s.to, u); s.m.position.y += Math.sin(Math.PI * u) * 1.8; s.m.rotation.set(T * 14, T * 9, 0); }
      else if (!s.armed) { s.armed = true; s.m.position.copy(s.to); s.m.rotation.set(0, Math.random() * 3, 0); sparks(s.to, 0xffe08a, 3, 3);
        if (si >= 3) s.m.traverse(c => { if (c.material) c.material.opacity = 0.45; }); } }
    if (si >= 3 && slotted && T > 1.35 && !sc.done.hid) { sc.done.hid = 1; pop("HIDDEN<small>ENEMIES CAN'T SEE THEM</small>", "#ffffff", 22, new THREE.Vector3(sc.x - 9, 3.4, 0), 1.4); }
    const slowed = T < b0.slowUntil; walkBot(b0, b0.spd * (slowed ? 0.7 : 1), dt);
    if (slowed) { b0.m.emissive.setRGB(0.05, 0.12, 0.3); }
    for (const s of spikes) if (s.armed && !s.used && T - b0.lastHit > 0.35 && Math.abs(s.to.x - (b0.g.position.x + 0.2)) < 1.0 && Math.abs(s.to.z - b0.g.position.z) < 1.3) {
      s.used = true; s.m.visible = false; b0.lastHit = T; b0.flash = 1; b0.knock = 0.6; b0.slowUntil = T + 1; b0.bleedUntil = T + 3; b0.tick = T; sparks(s.to.clone().add(new THREE.Vector3(0, 0.5, 0)), 0xff3040, 10, 6);
      pop("-3<small>BLEED 3 s</small>", "#ff4a5a", 30, chest(b0).add(new THREE.Vector3(0, 2.4, 0)), 0.9);
      if (!b0.said) { b0.said = 1; pop("SLOWED 30%", "#7fd0ff", 20, new THREE.Vector3(b0.g.position.x, 1.2, 1.8), 0.9); } b0.hp -= 3; }
    if (T < b0.bleedUntil) { if (T - b0.tick >= 1) { b0.tick = T; b0.hp -= 3; b0.flash = 0.5; pop("-3", "#ff4a5a", 20, chest(b0).add(new THREE.Vector3(0.5, 2.4, 0)), 0.7); }
      b0.dripT = (b0.dripT || 0) + dt; if (b0.dripT > 0.12) { b0.dripT = 0; bit(chest(b0).add(new THREE.Vector3(Math.random() - .5, 0, Math.random() - .5)), BLOOD, new THREE.Vector3(0, -1, 0), 0.5, -12, 0.16, {glow: true}); } }
    if (T > 5.2) reset();
  }
  if (P === "blob") {
    for (const b of [b0, b1]) { const g = inGoo(b.g.position); walkBot(b, b.spd * (g ? 0.6 : 1), dt);
      if (g) { if (!b.gooed) { b.gooed = 1; b.flash = 0.4; pop("SLOWED 40%", "#c8ff6a", 22, chest(b).add(new THREE.Vector3(0, 2.6, 0)), 1.0); }
        b.gooT = (b.gooT || 0) + dt; if (b.gooT > 0.18) { b.gooT = 0; bit(new THREE.Vector3(b.g.position.x + (Math.random() - .5) * 1.5, 0.6, b.g.position.z + (Math.random() - .5)), GOO, new THREE.Vector3(0, 1.5, 0), 0.5, -6, 0.22, {glow: true}); }
        b.m.emissive.setRGB(0.12, 0.25, 0); } else { if (b.gooed && !b.out) { b.out = 1; } } }
    if (slotted) {
      if (T > 0.15 && !sc.done.aim) { sc.done.aim = 1; sc.rings = blobTargets().map(t => { const g = ring(stepIdx() >= 1 ? 5.5 : 4, 0xffffff); g.position.set(t.x, 0, t.z); return g; });
        pop("HOLD TO AIM", "#ffffff", 18, new THREE.Vector3(sc.target.x, 3.5, 0), 0.9); }
      if (sc.rings) sc.rings.forEach(g => { g.rotation.y = T * 0.6; g.children.forEach(c => c.material.opacity = 0.55 + 0.4 * Math.sin(T * 10)); });
      if (T > 1.0 && !sc.done.fire) { sc.done.fire = 1; sc.fireAt = T; tileFlash(); sc.cdAt = T; sc.rings.forEach(g => g.visible = false); fireBlobs(); }
      if (sc.fireAt === undefined && T > 0.7) sc.fireAt = 1.0;
    }
    sc.drain = sc.done.fire ? Math.min(1, (T - sc.fireAt) * 3) : 0;
    for (const bl of blobs) { const u = (T - bl.t0) / bl.tt; if (bl.landed) continue;
      if (u < 0) { bl.g.visible = false; continue; } bl.g.visible = true;
      bl.g.position.copy(bl.from).lerp(bl.to, Math.min(1, u)); bl.g.position.y = bl.from.y * (1 - u) + Math.sin(Math.PI * Math.min(1, u)) * 7 + 0.4 * u;
      bl.g.rotation.set(T * 5, T * 7, 0); bl.g.children.forEach((c, k) => c.scale.setScalar(1 + 0.15 * Math.sin(T * 20 + k)));
      bl.dT = (bl.dT || 0) + dt; if (bl.dT > 0.05) { bl.dT = 0; bit(bl.g.position.clone(), GOO, new THREE.Vector3(0, -2, 0), 0.4, -10, 0.2, {glow: true}); }
      if (u >= 1) { bl.landed = true; bl.g.visible = false; splat(bl.to); } }
    for (const q of puddles) { const age = T - q.t0, k = Math.min(1, age / 0.25), left = q.until - T, fade = Math.max(0, Math.min(1, left / 0.6));
      q.g.scale.set(k * (1 + 0.03 * Math.sin(T * 4)), 1, k * (1 + 0.03 * Math.cos(T * 4))); q.disc.material.opacity = 0.78 * fade; q.rim.material.opacity = 0.8 * fade;
      q.bub.forEach(b => { const s = Math.max(0, Math.sin(T * 3 + b.ph)); b.m.scale.setScalar(0.3 + s); b.m.material.opacity = fade; });
      const sec = Math.ceil(left); if (left > 0 && sec !== q.sec) { q.sec = sec; pop(sec + " s", "#ffffff", 16, q.c.clone().add(new THREE.Vector3(0, 0.6, q.r + 0.6)), 0.6); } }
    const end = puddles.length ? Math.max(...puddles.map(q => q.until)) + 0.5 : (slotted ? 99 : 4.5);
    if (T > end) reset();
  }
  if (P === "adren") {
    const healPct = si >= 1 ? 0.34 : 0.25, boostEnd = 0.8 + 3;
    if (T < 0.55) walkBot(b0, b0.spd, dt);
    if (T > 0.3 && T < 0.6) b0.body.rotation.z = -0.5 * Math.sin(Math.PI * (T - 0.3) / 0.3);
    if (T > 0.45 && !sc.done.bite) { sc.done.bite = 1; sc.meHp -= 4; sc.flinch = 1; sparks(partWorld("Tail1_main", [0, 0, 0]), 0xff6a5a, 6, 6); pop("-4", "#ff4a5a", 24, partWorld("Head_cranium", [0, 2.3, 0]), 0.8); }
    if (slotted && T > 0.8 && !sc.done.shot) { sc.done.shot = 1; sc.shotAt = T; tileFlash(); sc.healLeft = 40 * healPct; sc.healTick = T;
      pop("ADRENALINE!", "#7dffb0", 32, partWorld("Head_cranium", [0, 2.8, 0]), 1.0);
      const at = look === 0 ? partWorld("Torso_hump", [-0.1, 1.2, 0]) : partWorld("Neck_main", [0, 0.1, 0.5]); sparks(at, ADR, 14, 6);
      if (si >= 3) { sc.pips = 2; setTimeout(() => pop("SLASH ×2<small>CHARGES REFILLED</small>", "#ffc832", 26, partWorld("Head_cranium", [0, 1.3, 0]), 1.3), 250); } }
    if (sc.done.shot) { const t = T - sc.shotAt; sc.plunge = Math.min(1, t / 0.12); sc.drain = Math.min(1, t / 3);
      const on = T < boostEnd; sc.glow = on ? 0.55 + 0.25 * Math.sin(T * 12) : Math.max(0, sc.glow - dt * 3); setDinoGlow(sc.glow); flashParts(on ? 0.25 + 0.25 * Math.sin(T * 12) : 0);
      if (on) { const per = 40 * healPct / 3; sc.meHp = Math.min(40, sc.meHp + per * dt);
        if (T - sc.healTick >= 0.75) { sc.healTick = T; pop("+" + (per * 0.75).toFixed(1), "#5fd16a", 22, partWorld("Head_cranium", [0, 2.2, 0]), 0.8); }
        if (t > 0.35) { sc.mode = "run"; sc.spd = 8 * 1.4; if (!sc.done.runPop) { sc.done.runPop = 1; pop("RUN ×1.4", "#7dffb0", 26, partWorld("Head_cranium", [-2, 2.6, 0]), 0.9); }
          sc.lineT = (sc.lineT || 0) + dt; if (sc.lineT > 0.05) { sc.lineT = 0; const m = box([1.6, 0.06, 0.06], 0xd8fff0, {glow: true}); m.position.set(sc.x - 3 - Math.random() * 2, 0.8 + Math.random() * 2.6, (Math.random() - .5) * 2.4); world.add(m); fx.push({m, v: new THREE.Vector3(-6, 0, 0), life: 0.25, max: 0.25, g: 0}); } } }
      else { sc.spd = Math.max(0, sc.spd - dt * 14); if (sc.spd <= 0.1) sc.mode = "idle"; if (!sc.done.end) { sc.done.end = 1; sc.cdAt = T; pop("boost over · cooldown starts", "#9aa6b6", 15, partWorld("Head_cranium", [0, 2.4, 0]), 1.0); } }
      if (T > 1.0) walkBot(b0, b0.spd, dt); }
    if (sc.mode === "run") sc.x += sc.spd * dt;
    if (T > (slotted ? 5.6 : 2.6)) reset();
  }
}
function updateP3(dt) {}
function tileFlash() { const t = $("tPart"); if (t) { t.classList.add("flash"); setTimeout(() => t.classList.remove("flash"), 240); } }
