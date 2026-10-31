// ---------- scenario state ----------
let T = 0, sc = {pulse: 0};
const quills = []; function updateQuills() {}
const beads = [], stars = [];
function stepIdx() { return slotted ? step : -1; }
function setDinoGlow(k) { for (const key in matCache) if (matCache[key].emissive) matCache[key].emissive.setScalar(k); }
function flashParts(k) { const w = new THREE.Color(0xffffff); for (const e of equip) if (e.flash) e.mesh.material.color.setHex(e.base).lerp(w, k); }
function starRing(target, getPos) { // dizzy stars spinning over a head
  const g = new THREE.Group(); world.add(g);
  for (let i = 0; i < 4; i++) { const m = new THREE.Mesh(new THREE.BoxGeometry(0.34, 0.34, 0.1), new THREE.MeshBasicMaterial({color: 0xffd23a})); m.rotation.z = Math.PI / 4; g.add(m); }
  const s = {g, getPos, until: Infinity}; stars.push(s); return s;
}
function clearStars() { stars.forEach(s => world.remove(s.g)); stars.length = 0; }
function reset() {
  clearFx(); clearStars(); beads.forEach(b => world.remove(b.m)); beads.length = 0;
  T = 0; deploy = 0; lid = 0; capPop = 0; setDinoGlow(0); flashParts(0);
  const P = PARTS[part].id;
  sc = {x: 0, alt: 0, phase: 0, mode: "idle", done: {}, meHp: 20, z: 0, pulse: 0, stun: 0};
  bots.forEach(b => { b.g.visible = false; b.hp = 200; b.flash = b.knock = 0; b.ko = 0; b.push = 0; b.lunge = 0; b.g.rotation.set(0, Math.PI, 0); b.body.rotation.set(0, 0, 0); b.body.position.set(0, 0, 0); });
  if (P === "siphon") { sc.x = 0; [[-1.0, -6.4], [-8.0, -5.5]].forEach(([x, z], i) => { const b = bots[i]; b.g.visible = true; b.g.position.set(x, 0, z); b.g.rotation.y = Math.atan2(z, -x); }); }
  if (P === "strobe") { sc.x = -18; sc.mode = "run"; bots[0].g.visible = true; bots[0].g.position.set(4, 0, 0); bots[1].g.visible = true; bots[1].g.position.set(1.5, 0, -5); }
  if (P === "breaker") { sc.x = 0; bots[0].g.visible = true; bots[0].g.position.set(6.2, 0, 0); sc.b0x = 6.2; bots[1].g.visible = true; bots[1].g.position.set(-5.5, 0, 3); bots[1].g.rotation.y = -0.5; }
  tree.visible = false;
}
const RUN = 58.5 / 2;
function poseFor(dt) {
  const P = PARTS[part].id;
  let o;
  if (labView) return scurry(0, 0);
  if (sc.mode === "run") { sc.phase += Math.min(S.MaxHz * 2 * Math.PI, (sc.spd || RUN) / S.Stride * 2 * Math.PI) * dt; o = scurry(sc.phase, Math.min(1, (sc.spd || RUN) / RUN + 0.2)); }
  else o = scurry(sc.phase, 0);
  const b = Math.sin(T * 3) * 2; add(o, "Neck", b); add(o, "Tail2", b);
  if (sc.mode === "flare") { const k = Math.min(1, (T - sc.t0) / 0.15) * Math.max(0, 1 - Math.max(0, T - sc.t0 - 0.55) / 0.3);
    add(o, "RootJoint", 18 * k); add(o, "Neck", 18 * k); add(o, "Head", -12 * k); add(o, "Jaw", -25 * k); add(o, "ArmL", -25 * k); add(o, "ArmR", -25 * k); }
  if (sc.mode === "dash") { const u = Math.min(1, (T - sc.t0) / 0.3), k = u > 0.2 && u < 0.8 ? Math.sin(Math.PI * (u - 0.2) / 0.6) : 0;
    add(o, "ArmL", 60 * k, 0, -20 * k); add(o, "ArmR", -40 * k, 0, 20 * k); add(o, "Jaw", -18 * k); }
  if (sc.stun > 0) { const w = Math.sin(T * 14); add(o, "RootJoint", -10 + 5 * w); add(o, "Neck", -20); add(o, "Head", -10 + 8 * w); o.body[2] += 8 * w; add(o, "ArmL", -10); add(o, "ArmR", -10); }
  if (sc.breakK > 0) { const k = sc.breakK; add(o, "RootJoint", 16 * k); add(o, "Neck", 22 * k); add(o, "Head", -14 * k); add(o, "Jaw", -30 * k); add(o, "ArmL", -40 * k, 0, -30 * k); add(o, "ArmR", -40 * k, 0, 30 * k); sc.breakK = Math.max(0, k - dt * 2.5); }
  if (sc.flinch) { add(o, "RootJoint", 10 * sc.flinch); add(o, "Neck", 12 * sc.flinch); sc.flinch = Math.max(0, sc.flinch - dt * 4); }
  return o;
}
function chest(b) { return new THREE.Vector3(b.g.position.x, 2.8, b.g.position.z); }
function siphonPoint() { return look === 0 ? partWorld("Neck_main", [0, -0.6, 0]) : partWorld("Jaw_lower", [0.75, 0.45, 0]); }
function inRange(b) { const r = stepIdx() >= 2 ? 12.5 : 7.5; return Math.hypot(b.g.position.x - sc.x, b.g.position.z) <= r; }
function bolt(from, dir, len) { // zigzag lightning made of thin boxes
  let p = from.clone(); const n = 4;
  for (let i = 0; i < n; i++) {
    const q = from.clone().addScaledVector(dir, len * (i + 1) / n).add(new THREE.Vector3((Math.random() - .5) * 0.8, (Math.random() - .5) * 0.8, (Math.random() - .5) * 0.8));
    const d = q.clone().sub(p), L = d.length();
    const m = new THREE.Mesh(new THREE.BoxGeometry(0.09, 0.09, L), new THREE.MeshBasicMaterial({color: i % 2 ? 0xffffff : VOLT, transparent: true}));
    m.position.copy(p).addScaledVector(d, 0.5); m.lookAt(q); world.add(m);
    fx.push({m, v: new THREE.Vector3(), life: 0.2, max: 0.2, g: 0}); p = q;
  }
}
function stepScenario(dt) {
  const P = PARTS[part].id, si = stepIdx(); T += dt; sc.pulse = Math.max(0, sc.pulse - dt * 3);
  const [b0, b1, b2] = bots;
  if (P === "siphon") {
    const healPer = si >= 1 ? 1.5 : 1;
    [b0, b1].forEach((b, i) => {
      if (b.ko) { b.body.rotation.z = Math.min(Math.PI / 2, b.body.rotation.z + dt * 6); return; }
      b.dripT = (b.dripT || 0) + dt; if (b.dripT > 0.22) { b.dripT = 0; bit(chest(b).add(new THREE.Vector3((Math.random() - .5), 0, (Math.random() - .5))), BLOOD, new THREE.Vector3(0, -1, 0), 0.6, -12, 0.16, {glow: true}); }
      b.tickT = (b.tickT || 0) + dt; if (b.tickT > 1) { b.tickT = 0; b.flash = 0.6; pop("-3", "#ff4a5a", 18, chest(b).add(new THREE.Vector3(0.6, 2.2, 0)), 0.7); }
      if (si >= 0 && inRange(b)) {
        b.beadT = (b.beadT || 0) + dt; if (b.beadT > 0.12) { b.beadT = 0; spawnBead(chest(b), 0.5); }
        b.healT = (b.healT || 0) + dt; if (b.healT > 1) { b.healT = 0; sc.meHp = Math.min(40, sc.meHp + healPer); sc.pulse = 1; pop("+" + healPer, "#5fd16a", 22, partWorld("Head_cranium", [0, 2.2, 0]).add(new THREE.Vector3(i * 0.8 - 0.4, 0, 0)), 0.8); }
      }
    });
    if (T > 3.2 && !sc.done.ko) { sc.done.ko = 1; b0.ko = 1; b0.flash = 1; pop("KO<small>BLEED</small>", "#ff4a5a", 28, chest(b0).add(new THREE.Vector3(0, 2.6, 0)), 1.1);
      if (si >= 3) { for (let i = 0; i < 22; i++) spawnBead(chest(b0).add(new THREE.Vector3((Math.random() - .5) * 2, Math.random() * 1.5, (Math.random() - .5) * 2)), 0.35 + Math.random() * 0.25);
        setTimeout(() => { sc.meHp = Math.min(40, sc.meHp + 10); sc.pulse = 1; pop("+10<small>BLEED KILL · 25%</small>", "#5fd16a", 40, partWorld("Head_cranium", [0, 2.6, 0]), 1.3); }, 450); } }
    if (T > 5.4) reset();
  }
  if (P === "strobe") {
    if (sc.mode === "run") { sc.spd = RUN * Math.max(0.12, Math.min(1, (-4 - sc.x) / 5)); sc.x += sc.spd * dt; if (sc.x > -4.3) { sc.mode = "flare"; sc.t0 = T; tileFlash(); } }
    if (sc.mode === "flare") {
      const t = T - sc.t0;
      if (slotted && t > 0.15 && !sc.done.flash) { sc.done.flash = 1; doStrobe(); }
      if (slotted) flashParts(t > 0.15 && t < 0.5 ? (Math.sin((t - 0.15) * 40) > 0 ? 1 : 0.2) : 0);
      if (t > 0.6) { if (si >= 3 && slotted) { sc.mode = "dash"; sc.t0 = T; sc.from = sc.x; } else { sc.mode = "wait"; sc.t0 = T; } }
    }
    if (sc.mode === "dash") { const u = Math.min(1, (T - sc.t0) / 0.3); sc.x = sc.from + (b0.g.position.x - 1.2 - sc.from) * (1 - Math.pow(1 - u, 2));
      if (u >= 1 && !sc.done.hit) { sc.done.hit = 1; b0.flash = 1; b0.knock = 1; b0.hp -= 10; sparks(chest(b0), 0xffe08a, 12, 8);
        pop("10<small>+20% DAZED</small>", "#ffc832", 38, chest(b0).add(new THREE.Vector3(0, 2.4, 0)), 1.1); sc.mode = "wait"; sc.t0 = T; } }
    if (sc.mode === "wait" && T - sc.t0 > 1.6) reset();
    for (const b of [b0, b1]) if (b.dazeUntil && T < b.dazeUntil) { b.body.rotation.x = Math.sin(T * 10) * 0.08; } else if (b.dazeUntil) { b.body.rotation.x = 0; }
  }
  if (P === "breaker") {
    // bot 0 lunges and bites (stun), the Herrera breaks out, bots are shoved, a second bite hits the immunity
    if (T > 0.25 && T < 0.6) b0.body.rotation.z = -0.5 * Math.sin(Math.PI * (T - 0.25) / 0.35);
    if (T > 0.45 && !sc.done.bite) { sc.done.bite = 1; sc.stun = 1; sc.meHp -= 5; sc.flinch = 1; sparks(partWorld("Head_cranium", [0, 0, 0]), 0xff6a5a, 6, 6);
      pop("STUNNED", "#ffd23a", 26, partWorld("Head_cranium", [0, 2.4, 0]), 0.9); sc.st = starRing(null, () => partWorld("Head_cranium", [0, 1.6, 0])); }
    const breakAt = 1.0, freeAt = 2.4;
    if (slotted && T > breakAt && !sc.done.brk) { sc.done.brk = 1; sc.stun = 0; sc.breakK = 1; tileFlash(); clearStars(); doBreak(); }
    if (!slotted && T > freeAt && !sc.done.free) { sc.done.free = 1; sc.stun = 0; clearStars(); pop("free (2 s stun)", "#ffffff", 16, partWorld("Head_cranium", [0, 2.4, 0])); }
    if (slotted) flashParts(T > breakAt && T < breakAt + 0.35 ? (Math.sin((T - breakAt) * 50) > 0 ? 1 : 0.3) : 0);
    // shove
    for (const b of [b0, b1]) if (b.push > 0) { const d = Math.min(b.push, dt * 18); b.push -= d; const dir = new THREE.Vector3(b.g.position.x - sc.x, 0, b.g.position.z).normalize(); b.g.position.addScaledVector(dir, d); }
    // immunity blink
    const immune = slotted && si >= 3 && T > breakAt && T < breakAt + 1.0;
    setDinoGlow(immune ? (Math.sin(T * 30) > 0 ? 0.55 : 0.1) : 0);
    if (slotted && si >= 3 && T > breakAt + 0.35 && T < breakAt + 0.9) { // bot 0 rushes back in and bites the immune Herrera
      const tx = sc.x + 6.2; b0.g.position.x += (tx - b0.g.position.x) * Math.min(1, dt * 8);
      if (T > breakAt + 0.6 && !sc.done.b2) { sc.done.b2 = 1; b0.body.rotation.z = -0.4; setTimeout(() => b0.body.rotation.z = 0, 200);
        pop("0<small>IMMUNE</small>", "#ffffff", 34, partWorld("Head_cranium", [1.5, 3.4, 0]), 0.9); sparks(partWorld("Head_cranium", [0, 0, 0]), 0xffffff, 8, 6); } }
    if (T > 3.4) reset();
  }
  // stars follow their heads
  for (const s of stars) { const p = s.getPos(); s.g.position.copy(p); s.g.children.forEach((m, i) => { const a = T * 6 + i * Math.PI / 2; m.position.set(Math.cos(a) * 0.9, Math.sin(a * 2) * 0.1, Math.sin(a) * 0.9); m.rotation.y = a; }); if (T > s.until) { world.remove(s.g); s.dead = 1; } }
  for (let i = stars.length - 1; i >= 0; i--) if (stars[i].dead) stars.splice(i, 1);
}
function spawnBead(from, tt) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.3, 0.3), new THREE.MeshBasicMaterial({color: 0xff3040})); m.position.copy(from); world.add(m);
  beads.push({m, from: from.clone(), t: 0, tt, arc: 1 + Math.random() * 1.2, side: (Math.random() - .5) * 1.4});
}
function updateBeads(dt) {
  const to = siphonPoint();
  for (let i = beads.length - 1; i >= 0; i--) { const b = beads[i]; b.t += dt; const u = Math.min(1, b.t / b.tt);
    const p = b.from.clone().lerp(to, u); p.y += Math.sin(Math.PI * u) * b.arc; p.z += Math.sin(Math.PI * u) * b.side; b.m.position.copy(p); b.m.scale.setScalar(1 - 0.5 * u);
    if (u >= 1) { world.remove(b.m); beads.splice(i, 1); } }
}
function doStrobe() {
  const si = stepIdx(), half = si >= 2 ? 45 : 30, range = si >= 2 ? 12.5 : 10, daze = si >= 1 ? 1.5 : 1;
  const head = partWorld("Head_cranium", [0.5, 0.4, 0]);
  for (let i = 0; i < 13; i++) { // light rays across the cone
    const a = rad(-half + (2 * half) * i / 12), dir = new THREE.Vector3(Math.cos(a), 0.05 + (i % 3) * 0.04, Math.sin(a)).normalize(), L = range * (0.8 + (i % 2) * 0.2);
    const m = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.2, L), new THREE.MeshBasicMaterial({color: i % 2 ? 0xffffff : LED, transparent: true}));
    m.position.copy(head).addScaledVector(dir, L / 2); m.lookAt(head.clone().addScaledVector(dir, L)); world.add(m); fx.push({m, v: new THREE.Vector3(), life: 0.4, max: 0.4, g: 0});
  }
  const flare = new THREE.Mesh(new THREE.SphereGeometry(1.4, 16, 12), new THREE.MeshBasicMaterial({color: 0xffffff, transparent: true}));
  flare.position.copy(head); world.add(flare); fx.push({m: flare, v: new THREE.Vector3(), life: 0.3, max: 0.3, g: 0, grow: 2.2});
  pop("FLASH!", "#fff3c4", 30, head.clone().add(new THREE.Vector3(-1.5, 3.2, 0)), 0.7);
  bots.slice(0, 2).forEach(b => {
    const d = new THREE.Vector3(b.g.position.x - sc.x, 0, b.g.position.z), ang = Math.abs(Math.atan2(d.z, d.x)) * 180 / Math.PI;
    if (d.length() <= range && ang <= half) { b.dazeUntil = T + daze; b.flash = 0.8; const s = starRing(null, () => new THREE.Vector3(b.g.position.x + 1.6, 4.6, b.g.position.z)); s.until = T + daze;
      pop(`DAZED ${daze} s`, "#ffd23a", 22, new THREE.Vector3(b.g.position.x + 1.5, 6.2, b.g.position.z), 1.0); }
    else pop("outside the cone", "#9aa6b6", 14, new THREE.Vector3(b.g.position.x, 5.2, b.g.position.z), 0.9);
  });
}
function doBreak() {
  const si = stepIdx();
  const srcs = look === 0 ? [1, 3, 5, 6, 7, 9, 11].map(i => partWorld("Head_frillrim" + i, [0, 0.6, 0])) : [partWorld("Torso_hump", [0, 1.85, 0.25]), partWorld("Torso_hump", [0, 1.85, -0.25])];
  for (const s of srcs) for (let k = 0; k < (look === 0 ? 2 : 5); k++) { const a = Math.random() * Math.PI * 2; bolt(s, new THREE.Vector3(Math.cos(a), 0.3 + Math.random() * 0.6, Math.sin(a)).normalize(), 2.5 + Math.random() * 2.5); }
  pop("BREAK!", "#7fe9ff", 40, partWorld("Head_cranium", [-2.5, 3.0, 0]), 0.9);
  if (si >= 1) for (const b of bots.slice(0, 2)) { const d = Math.hypot(b.g.position.x - sc.x, b.g.position.z); if (d < 7.5) { b.push = 5; b.knock = 1; b.flash = 0.8; for (let i = 0; i < 3; i++) dust(new THREE.Vector3(b.g.position.x, 0.2, b.g.position.z + i - 1), true); } }
  if (si >= 1) pop("PUSHED 10 studs", "#ffffff", 16, new THREE.Vector3(sc.x + 7, 5, 0), 0.9);
}
function tileFlash() { const t = $("tPart"); if (t) { t.classList.add("flash"); setTimeout(() => t.classList.remove("flash"), 240); } }
