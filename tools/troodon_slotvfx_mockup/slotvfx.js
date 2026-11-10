// troodon_slotvfx.js v0.1 (Mecha Dino Arena) — Shield Dome + Bloom Burst EFFECT options (Kepu 2026-11-10 10:38: "make the radius for
// the shield some 3x the size and better vfx it looks so lazy. The bloom burst needs better vfx as well"). Runs after
// tools/troodon_slotparts_mockup/slotparts.js v0.1 (same engine, troodon, canister / bud carry, scenes): keeps only the Bloom Burst
// and Shield Dome tabs, puts the SkillTree 1.86 dome size in (90 / 121.5 studs wide), and adds an Effect row: 3 new options per
// part + "In the game now" (what TrooSlotFX 1.0 / the ForceField ball draw today). Every option: wind-up -> action -> result ->
// recovery; no landing FX. Build: python3 tools/troodon_slotvfx_mockup/build.py <three.min.js r128>.
const VFX_VERSION = "0.1";
const VFX = {burst: "A", dome: "A"};
CFG.dome = r => ({on: r >= 0, R: r >= 3 ? 60.75 : 45, life: r >= 1 ? 6.75 : 5, cd: r >= 2 ? 18.5 : 25}); // SkillTree 1.86
camMode = "scene";

// ---------- shared pieces ----------
const SH_BLUE = 0x5ab4ff, SH_PALE = 0xbfe6ff, SH_WHITE = 0xeaf7ff, LEAF = 0x46e08a, LEAF_PALE = 0xc8ffd8, PETAL = 0xf6fff0, NOHEAL = 0xb36bff;
// edge-glow shell (in Roblox: a ForceField / Glass sphere + a Highlight outline; the bright edge is what makes it readable)
function rimMat(color, power, base, k) {
  return new THREE.ShaderMaterial({uniforms: {c: {value: new THREE.Color(color)}, p: {value: power}, b: {value: base}, k: {value: k}, a: {value: 1}},
    vertexShader: "varying vec3 vN; varying vec3 vV; void main(){ vec4 w = modelMatrix * vec4(position, 1.0); vN = normalize(mat3(modelMatrix) * normal); vV = normalize(cameraPosition - w.xyz); gl_Position = projectionMatrix * viewMatrix * w; }",
    fragmentShader: "uniform vec3 c; uniform float p; uniform float b; uniform float k; uniform float a; varying vec3 vN; varying vec3 vV; void main(){ float f = pow(1.0 - abs(dot(normalize(vN), normalize(vV))), p); gl_FragColor = vec4(c, clamp((b + f * k) * a, 0.0, 1.0)); }",
    transparent: true, depthWrite: false, side: THREE.DoubleSide, blending: THREE.NormalBlending});
}
const HEMI = new THREE.SphereGeometry(1, 56, 28, 0, Math.PI * 2, 0, Math.PI / 2);
const lineMat = (color, op) => new THREE.MeshBasicMaterial({color, transparent: true, opacity: op === undefined ? 0.9 : op, depthWrite: false, side: THREE.DoubleSide}); // tinted (reads blue on bright sand)
const addMat = (color, op) => new THREE.MeshBasicMaterial({color, transparent: true, opacity: op === undefined ? 0.9 : op, depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending});
function ringMesh(r0, r1, color, op) { const m = new THREE.Mesh(new THREE.RingGeometry(r0, r1, 96), addMat(color, op)); m.rotation.x = -Math.PI / 2; return m; }
function torus(R, r, color, op) { return new THREE.Mesh(new THREE.TorusGeometry(R, r, 8, 96), addMat(color, op)); }
function cylBetween(a, b, r, mat) { const d = b.clone().sub(a), L = d.length(); const m = new THREE.Mesh(new THREE.CylinderGeometry(r, r, 1, 6, 1, true), mat);
  m.position.copy(a).addScaledVector(d, 0.5); m.quaternion.setFromUnitVectors(V(0, 1, 0), d.normalize()); m.scale.set(1, L, 1); return m; }
function bolt(a, b, color, life) { // a jagged light arc (Roblox: a Beam with a lightning texture, or 6 thin Neon parts)
  const pts = [a.clone()]; for (let i = 1; i < 6; i++) pts.push(a.clone().lerp(b, i / 6).add(V((Math.random() - .5) * 3, (Math.random() - .5) * 3, (Math.random() - .5) * 3))); pts.push(b.clone());
  const g = new THREE.Group(); const mt = addMat(color, 1); for (let i = 0; i < pts.length - 1; i++) g.add(cylBetween(pts[i], pts[i + 1], 0.22, mt));
  addFx(g, life, (o, u) => { mt.opacity = (1 - u) * (u < 0.5 ? 1 : 0.6 + 0.4 * Math.sin(clockT * 80)); }); }
function spriteAt(p, color, size, life, upd) { const s = sprite(T_FLASH, color, size, true); s.position.copy(p); return addFx(s, life, upd || ((o, u) => { o.material.opacity = 1 - u; })); }
// a leaf / petal sprite (Roblox: a ParticleEmitter with a petal image; needs one image upload)
const T_PETAL = (() => { const c = document.createElement("canvas"); c.width = c.height = 64; const x = c.getContext("2d"); const g = x.createLinearGradient(0, 8, 0, 56); g.addColorStop(0, "#ffffff"); g.addColorStop(1, "#7cf0a8");
  x.fillStyle = g; x.beginPath(); x.moveTo(32, 4); x.bezierCurveTo(58, 20, 52, 50, 32, 60); x.bezierCurveTo(12, 50, 6, 20, 32, 4); x.fill(); x.strokeStyle = "rgba(30,120,70,.7)"; x.lineWidth = 2; x.beginPath(); x.moveTo(32, 8); x.lineTo(32, 56); x.stroke(); return new THREE.CanvasTexture(c); })();
function petalSprite(p, size) { const s = new THREE.Sprite(new THREE.SpriteMaterial({map: T_PETAL, transparent: true, depthWrite: false})); s.position.copy(p); s.scale.set(size, size, 1); return s; }

// ===================================================================================================================================
// SHIELD DOME options: makeDomeX(Dp, R, life, cc) -> {up, hit(p)}; the canister sits at Dp (carry, from slotparts.js)
// ===================================================================================================================================
// A · Lattice Bastion: a geodesic frame of light builds up from the ground row by row, an edge-glow shell fills it, a scan band
// sweeps up; a hit lights the panel it struck + a ripple; at the end the frame drops away top-down into the canister.
const ICO = (() => { const g = new THREE.IcosahedronGeometry(1, 2); const pos = g.attributes.position; const faces = [];
  for (let i = 0; i < pos.count; i += 3) { const a = V(pos.getX(i), pos.getY(i), pos.getZ(i)), b = V(pos.getX(i + 1), pos.getY(i + 1), pos.getZ(i + 1)), c = V(pos.getX(i + 2), pos.getY(i + 2), pos.getZ(i + 2));
    if (Math.min(a.y, b.y, c.y) > -0.02) faces.push([a, b, c]); }
  const key = v => v.toArray().map(n => n.toFixed(4)).join(","); const seen = new Set(), edges = [];
  for (const f of faces) for (let i = 0; i < 3; i++) { const a = f[i], b = f[(i + 1) % 3]; const k = [key(a), key(b)].sort().join("|"); if (!seen.has(k)) { seen.add(k); edges.push([a, b]); } }
  return {faces, edges}; })();
function makeDomeA(Dp, R, life) {
  const g = new THREE.Group(); g.position.copy(Dp).setY(0);
  const shellM = rimMat(0x3f9cff, 2.0, 0.08, 0.7); const shell = new THREE.Mesh(HEMI, shellM); g.add(shell);
  const N = ICO.edges.length, im = new THREE.InstancedMesh(new THREE.CylinderGeometry(1, 1, 1, 5, 1, true), lineMat(0x7cc4ff, 0.85), N); g.add(im);
  const mats = ICO.edges.map(([a, b]) => { const d = b.clone().sub(a), L = d.length(); const q = new THREE.Quaternion().setFromUnitVectors(V(0, 1, 0), d.clone().normalize()); return {mid: a.clone().addScaledVector(d, 0.5), q, L, h: Math.max(a.y, b.y)}; });
  const M4 = new THREE.Matrix4(), S3 = V(1, 1, 1);
  const base = ringMesh(0.97, 1.03, SH_WHITE, 0.95); base.position.y = 0.012; g.add(base);
  const band = torus(1, 0.012, SH_WHITE, 0.9); band.rotation.x = Math.PI / 2; g.add(band);
  const pillars = []; for (let i = 0; i < 10; i++) { const a = i / 10 * Math.PI * 2; const p = cylBetween(V(Math.cos(a), 0, Math.sin(a)), V(Math.cos(a), 0.5, Math.sin(a)), 0.012, addMat(SH_PALE, 0)); g.add(p); pillars.push(p); }
  const D = {up: false, R, g, pulse: 0};
  const BUILD = 0.55, FALL = 0.45, thick = 0.011 * 45 / R; // the frame keeps ~0.5-stud beams at any size
  addFx(g, life, (o, u, dt) => { const t = u * life; g.scale.setScalar(R);
    const hb = t < BUILD ? E.out(t / BUILD) * 1.02 : t > life - FALL ? 1.02 * (1 - E.io((t - (life - FALL)) / FALL)) : 1.02; // build height (unit), drops top-down at the end
    for (let i = 0; i < N; i++) { const e = mats[i]; const on = e.h <= hb; M4.compose(e.mid, e.q, on ? S3.set(thick, e.L, thick) : S3.set(0, 0, 0)); im.setMatrixAt(i, M4); }
    im.instanceMatrix.needsUpdate = true;
    D.up = t > BUILD * 0.6 && t < life - FALL * 0.5; D.pulse = Math.max(0, D.pulse - dt * 3);
    shellM.uniforms.a.value = Math.min(1, hb) * (0.9 + 0.1 * Math.sin(clockT * 4)) + 0.6 * D.pulse;
    im.material.opacity = 0.55 + 0.25 * Math.sin(clockT * 3) + 0.4 * D.pulse;
    const sweep = t < BUILD ? hb : (clockT * 0.7) % 1; band.position.y = Math.min(0.999, sweep); band.scale.setScalar(Math.sqrt(Math.max(0, 1 - sweep * sweep)) + 0.001); band.material.opacity = t < BUILD ? 1 : 0.55 * Math.sin(Math.PI * sweep) * (t > life - FALL ? 0 : 1);
    pillars.forEach((p, i) => { p.material.opacity = t < BUILD + 0.3 ? 0.9 * (1 - win(t, BUILD, BUILD + 0.3)) : 0.25 + 0.15 * Math.sin(clockT * 5 + i); });
    base.material.opacity = 0.95 * Math.min(1, t / 0.1) * (t > life - 0.1 ? (life - t) / 0.1 : 1); });
  D.hit = p => { D.pulse = 1; const q = p.clone().sub(Dp.clone().setY(0)).divideScalar(R); let best = null, bd = 9;
    for (const f of ICO.faces) { const c = f[0].clone().add(f[1]).add(f[2]).divideScalar(3); const d = c.distanceTo(q); if (d < bd) { bd = d; best = f; } }
    if (best) { const geo = new THREE.BufferGeometry().setFromPoints(best.map(v => v.clone().multiplyScalar(1.004))); const tri = new THREE.Mesh(geo, addMat(SH_WHITE, 1)); tri.scale.setScalar(R); tri.position.copy(Dp).setY(0);
      addFx(tri, 0.45, (o, u) => { o.material.opacity = 1 - u; }); }
    const n = p.clone().sub(Dp.clone().setY(0)).normalize(); flash(p, 8, SH_WHITE); axisRing(p, n, 6, SH_PALE, 0.4); sparks(p, n.clone().negate(), 6, SH_PALE, 0.35); };
  return D;
}
// B · Bubble Shield: a glossy bubble inflates out of the canister with a wobble, its colour drifts cyan -> violet; 3 energy bands
// orbit inside; a hit sends ripples across it and makes it jiggle; at the end it pops into droplets.
function makeDomeB(Dp, R, life) {
  const g = new THREE.Group(); g.position.copy(Dp).setY(0);
  const sm = rimMat(0x6cd6ff, 1.6, 0.1, 0.85); const shell = new THREE.Mesh(HEMI, sm); g.add(shell);
  const gloss = spriteAt(V(0, 0, 0), 0xffffff, 1, life, () => {}); scene.remove(gloss); g.add(gloss); gloss.material.opacity = 0.35;
  const bands = [0.2, 1.1, 2.0].map((a, i) => { const t = torus(0.96, 0.006, i === 1 ? 0xd7b8ff : SH_PALE, 0.7); t.userData = {a, s: 0.6 + i * 0.25}; g.add(t); return t; });
  const D = {up: false, R, g, w: 0, v: 0};
  const INF = 0.5, POP = 0.12;
  rising(() => Dp.clone().add(V((Math.random() - .5) * R * 1.2, 0.5, (Math.random() - .5) * R * 1.2)), SH_PALE, life - 0.3, 14, 1, 3);
  addFx(g, life, (o, u, dt) => { const t = u * life;
    const grow = t < INF ? E.back(t / INF) : 1; for (let i = 0; i < 6; i++) { D.v += (-60 * D.w - 6 * D.v) * dt / 6; D.w += D.v * dt / 6; }
    const k = Math.max(0.001, R * grow); g.scale.set(k * (1 + D.w), k * (1 - D.w * 0.8), k * (1 + D.w));
    if (t < 0.05) D.v = 2.2;
    const hue = 0.6 + 0.12 * Math.sin(clockT * 0.9); // cyan -> blue -> violet (never the heal green) sm.uniforms.c.value.setHSL(hue, 0.85, 0.62); sm.uniforms.a.value = 0.95 + 0.4 * Math.abs(D.w) * 4;
    bands.forEach((b, i) => { b.rotation.set(Math.PI / 2 + Math.sin(clockT * b.userData.s + b.userData.a) * 0.9, clockT * b.userData.s * 1.3 + b.userData.a, 0); b.position.y = 0; b.material.opacity = 0.55 + 0.2 * Math.sin(clockT * 4 + i); });
    gloss.position.set(-0.35, 0.72, 0.35); gloss.scale.set(0.45, 0.25, 1);
    D.up = t > 0.25 && t < life - POP; });
  D.hit = p => { D.v += 1.4; const n = p.clone().sub(Dp.clone().setY(0)).normalize();
    for (let i = 0; i < 3; i++) later(i * 0.08, () => axisRing(p, n, 7 + i * 5, i ? 0xd7b8ff : SH_WHITE, 0.45)); flash(p, 7, SH_WHITE); };
  later(life - POP, () => { const c = Dp.clone().setY(0); flash(c.clone().setY(R * 0.5), R * 1.4, SH_PALE); groundRing(c, R * 1.1, SH_PALE, 0.4, R);
    for (let i = 0; i < 60; i++) { const th = Math.random() * Math.PI * 2, ph = Math.random() * Math.PI / 2; const n = V(Math.cos(th) * Math.sin(ph), Math.cos(ph), Math.sin(th) * Math.sin(ph));
      const s = sprite(T_FLASH, i % 3 ? SH_PALE : 0xd7b8ff, 1.6, true); s.position.copy(c).addScaledVector(n, R); const v = n.clone().multiplyScalar(14 + Math.random() * 10);
      addFx(s, 0.6, (o, u, d) => { v.y -= 50 * d; o.position.addScaledVector(v, d); o.material.opacity = 1 - u; }); } });
  return D;
}
// C · Aurora Pylon: the canister stands up into a pylon with 3 floating rings; a light beam goes up to the top of the dome and 16
// curtains of light fan open around it like an umbrella; light runs down the curtains; a hit cracks a bolt to the nearest
// curtain; at the end the curtains fold back into the pylon and it sinks.
function makeDomeC(Dp, R, life) {
  const g = new THREE.Group(); g.position.copy(Dp).setY(0);
  const sm = rimMat(0x3f9cff, 2.4, 0.05, 0.5); const shell = new THREE.Mesh(HEMI, sm); g.add(shell);
  const NR = 16, rib = [], arc = []; for (let i = 0; i <= 24; i++) { const th = i / 24 * Math.PI / 2; arc.push(V(Math.sin(th), Math.cos(th), 0)); }
  const ribGeo = new THREE.TubeGeometry(new THREE.CatmullRomCurve3(arc), 48, 0.008, 6, false);
  for (let i = 0; i < NR; i++) { const pv = new THREE.Group(); const m = new THREE.Mesh(ribGeo, lineMat(i % 2 ? 0x7cc4ff : 0x5fe0ff, 0.9)); pv.add(m); g.add(pv); rib.push({pv, m, a: i / NR * Math.PI * 2}); }
  const pyl = new THREE.Group(); pyl.position.copy(Dp).setY(0); scene.add(pyl); OWNED.push(pyl);
  const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.7, 1.2, 10, 8), new THREE.MeshStandardMaterial({color: 0x3b4352, metalness: 0.6, roughness: 0.4})); pole.position.y = 5; pyl.add(pole);
  const tip = new THREE.Mesh(new THREE.SphereGeometry(1.1, 16, 10), addMat(SH_WHITE, 1)); tip.position.y = 10.6; pyl.add(tip);
  const prings = [0, 1, 2].map(i => { const t = torus(2 + i * 0.9, 0.12, i === 1 ? 0x9ff0ff : SH_PALE, 0.95); t.position.y = 7 + i * 1.6; pyl.add(t); return t; });
  const beam = cylBetween(V(0, 10.6, 0), V(0, 1, 0), 0.5, addMat(SH_WHITE, 0)); pyl.add(beam);
  const D = {up: false, R, g};
  const RISE = 0.3, FAN = 0.55, FOLD = 0.45;
  addFx(g, life + 0.3, (o, u, dt) => { const t = u * (life + 0.3);
    pyl.visible = t < life + 0.28; const rise = E.back(win(t, 0, RISE)) * (t > life ? 1 - win(t, life, life + 0.3) : 1); pyl.scale.set(1, Math.max(0.01, rise), 1);
    prings.forEach((r, i) => { r.rotation.set(Math.PI / 2 + Math.sin(clockT * 2 + i) * 0.3, 0, clockT * (2 + i)); });
    tip.material.opacity = 0.7 + 0.3 * Math.sin(clockT * 9);
    beam.position.set(0, 10.6 + (R - 10.6) * 0.5, 0); beam.scale.set(1, Math.max(0.01, (R - 10.6)), 1); beam.material.opacity = t < RISE ? 0 : t < RISE + 0.25 ? 1 - win(t, RISE, RISE + 0.25) * 0.6 : t > life - FOLD ? 0 : 0.25 + 0.1 * Math.sin(clockT * 7);
    const fan = t < RISE ? 0 : t < RISE + FAN ? E.out(win(t, RISE, RISE + FAN)) : t > life - FOLD ? 1 - E.io(win(t, life - FOLD, life)) : 1;
    const k = Math.max(0.001, R * (t < RISE ? 0.001 : Math.min(1, 0.3 + fan))); g.scale.setScalar(k);
    rib.forEach((r, i) => { r.pv.rotation.y = r.a * fan; r.m.material.opacity = (0.55 + 0.35 * Math.sin(clockT * 6 - i * 0.7)) * Math.min(1, fan * 2); });
    sm.uniforms.a.value = fan; D.up = fan > 0.6 && t < life - FOLD * 0.5; });
  // light running down the curtains (Roblox: the Beam texture scrolling, TextureSpeed)
  const flow = new THREE.Object3D(); let em = 0; addFx(flow, life, (o, u, dt) => { if (!D.up) return; em += dt * 30; while (em >= 1) { em -= 1; const r = rib[Math.floor(Math.random() * NR)];
    const s = sprite(T_FLASH, SH_WHITE, 2.4, true); scene.add(s); const a = r.a; addFx(s, 0.7, (q, uu) => { const th = uu * Math.PI / 2; q.position.copy(Dp).setY(0).add(V(Math.sin(th) * Math.cos(-a) * R, Math.cos(th) * R, Math.sin(th) * Math.sin(-a) * R)); q.material.opacity = Math.sin(uu * Math.PI); }); } });
  D.hit = p => { let best = null, bd = 1e9; const c = Dp.clone().setY(0);
    for (const r of rib) { for (let i = 2; i < 24; i += 3) { const th = i / 24 * Math.PI / 2; const q = c.clone().add(V(Math.sin(th) * Math.cos(-r.a) * R, Math.cos(th) * R, Math.sin(th) * Math.sin(-r.a) * R)); const d = q.distanceTo(p); if (d < bd) { bd = d; best = q; } } }
    flash(p, 7, SH_WHITE); if (best) bolt(p, best, SH_WHITE, 0.3); sparks(p, p.clone().sub(c).normalize().negate(), 8, SH_PALE, 0.4); };
  return D;
}
// L · in the game now: the server's ForceField ball (barely visible from inside) + TrooSlotFX's small blue ripple on a block
function makeDomeL(Dp, R, life) {
  const g = new THREE.Group(); g.position.copy(Dp).setY(0); const sm = rimMat(0x6cc4ff, 3, 0.0, 0.12); const shell = new THREE.Mesh(HEMI, sm); g.add(shell);
  const D = {up: false, R, g};
  addFx(g, life, (o, u) => { const t = u * life; const k = Math.max(0.001, R * (t < 0.35 ? E.back(t / 0.35) : t > life - 0.3 ? (life - t) / 0.3 : 1)); g.scale.setScalar(k); D.up = t > 0.3 && t < life - 0.3; });
  D.hit = p => { const n = p.clone().sub(Dp.clone().setY(0)).normalize(); flash(p, 4, SH_PALE); sparks(p, n.negate(), 4, SH_PALE, 0.25); };
  return D;
}
const DOMES = {A: makeDomeA, B: makeDomeB, C: makeDomeC, L: makeDomeL};

function domeTrackV() {
  const st = VFX.dome, c = cfgNow("dome"), cc = NK.domeCarry; cc.p0 = null;
  const Dp = V(0, 0, -12); // MechaButtons 1.45 body-aim landing: 12 studs ahead
  place(S, -6, -24); place(S2, 12, -8); place(R0, -16, -104); place(R1, 18, -100);
  [S, S2].forEach(R => { R.yaw = yawTo(R.pos, V(0, 0, -100)); }); R0.yaw = yawTo(R0.pos, S.pos); R1.yaw = yawTo(R1.pos, S.pos);
  S.max = 60; setHp(S, 44); S.hpShow = true;
  const T0 = 0.6, REL = T0 + 0.34, FLY = 0.45, LAND = REL + FLY, OPEN = LAND + 0.2, DOWN = OPEN + c.life, END = DOWN + 1.0, OUT = OPEN + 1.6;
  const keys = idleIntro([...THROW(T0), ...THROW(OUT - 0.34)], T0);
  const GS = 4.5; let dome = null, told = false;
  const ev = [{t: T0, f: () => glowAt(() => carryPos(cc), SH_BLUE, 4, REL - T0, 0.7)}, {t: REL, f: () => trailOn(() => carryPos(cc), SH_BLUE, FLY, 40, 1)},
    {t: OPEN, f: () => { dome = DOMES[st](Dp, c.R, c.life); if (st !== "L") { flash(Dp.clone().setY(3), 22, SH_WHITE); shake = 0.45; hitStop = 0.04; }
      later(0.6, () => textTag(Dp.clone().add(V(0, c.R + 5, 0)), "SHIELD DOME · " + fmt(c.R * 2) + " studs wide · " + fmt(c.life) + " s", "#bfe6ff", 1.8)); }}];
  for (let i = 0, t = OPEN + 0.7; t < DOWN - 0.3; i++, t += 0.45) { const R = i % 2 ? R1 : R0;
    ev.push({t, f: () => { const A = rapChest(R).add(V(0, 1, 0)), B = rapChest(S); flash(A, 3, VOLT); R.flinch = Math.max(R.flinch, 0.25);
      const k = dome && dome.up ? sphereEntry(A, B, Dp.clone().setY(0), c.R) : null;
      if (k !== null) { const P = A.clone().lerp(B, k); shot(A, P, A.distanceTo(P) / 160, VOLT, 1.8, p => { dome.hit(p); if (!told) { told = true; textTag(p.clone().add(V(0, 6, 0)), "BLOCKED", "#bfe6ff", 1.2); } }); }
      else shot(A, () => rapChest(S), A.distanceTo(B) / 160, VOLT, 1.8, p => { popNum(p.clone().add(V(0, 5, 0)), 8, "hit"); S.flinch = 0.8; S.flash = 0.12; S.flashCol = [0.4, 0.8, 1]; setHp(S, S.hp - 8); }); }}); }
  ev.push({t: OUT, f: () => throwPod({kind: "pod", from: handsPoint(), target: () => R0.pos.clone().setY(1), T: 0.8, H: 14, onHit: p => { zoneAt(p, {self: 0}); textTag(p.clone().add(V(0, 15, 0)), "YOUR POD GOES OUT", "#ffd38a", 1.4); }})});
  const O = OPTS.dome.find(o => o.k === st);
  return {frame: [V(0, 0, c.R * 1.5), V(0, 0, -110)], keys, ev, eyes: [[T0, REL + 0.3], [OUT - 0.3, OUT + 0.2]],
    update(t) { NS.domeGlow = 0; PGLOW.dome = t < REL ? 0.2 + 0.8 * win(t, T0, REL) : 0.2; regrow(cc, true, t, LAND, DOWN + 0.4); },
    post(t) { throwCarry(cc, t, T0, REL, LAND, Dp.clone().setY(0.6), 6, 3.4, tt => { if (tt > DOWN || (st === "C" && tt > OPEN + 0.05)) { carryOff(cc); return; }
      const k = GS * (tt < OPEN ? E.back(win(tt, LAND, OPEN)) * 0.9 + 0.1 : 1); carryAt(cc, new THREE.Matrix4().compose(Dp.clone().setY(0.25 * k), new THREE.Quaternion().setFromEuler(new THREE.Euler(0, 0, -Math.PI / 2)), V(k, k, k))); }); },
    phases: [[0, T0, "Slotted: the dome canister on the tail base"], [T0, REL, "Wind-up: the canister comes into both hands"], [REL, LAND, "Throw: it lands 12 studs ahead (up to 30)"],
      [LAND, OPEN + 0.6, O.ph[0]], [OPEN + 0.6, OUT, O.ph[1]], [OUT, DOWN - 0.5, "Your pod goes out through it; the dome holds " + fmt(c.life) + " s"], [DOWN - 0.5, END, O.ph[2]]],
    len: END};
}

// ===================================================================================================================================
// BLOOM BURST options: BURSTS[k](B, c) plays the burst at the bud's spot and calls applyBurst at its result moment
// ===================================================================================================================================
function applyBurst(B, c, allyFx, enemyFx) {
  for (const R of raps) { if (!R.show) continue; const d = R.rig.pos.clone().setY(0).distanceTo(B); if (d > c.R + 1.5) continue;
    if (R.ally) { healPop(R, c.heal); R.amp = c.amp; if (allyFx) allyFx(R); textTag(rapChest(R).add(V(0, 14.5, 0)), "+50% HEALING · " + fmt(c.amp) + " s", "#8dffb6", 1.8); }
    else { R.noheal = c.amp; R.flash = 0.2; R.flashCol = [0.6, 0.2, 0.9]; if (enemyFx) enemyFx(R); textTag(rapChest(R).add(V(0, 11, 0)), "NO HEAL −50% · " + fmt(c.amp) + " s", "#d9a8ff", 1.8); } } }
// A · Blossom Nova: 6 big petals unfold flat on the ground, a column of light shoots up, a white-green shockwave rolls out; petals
// drift over the squad (each squadmate gets a petal swirl); enemies get a violet wilt ring.
function burstA(B, c) {
  const p = B.clone().setY(1.5); flash(p, 26, 0xeaffea); hitStop = 0.06; shake = 0.7;
  const g = new THREE.Group(); g.position.copy(B).setY(0.3); scene.add(g);
  const pm = new THREE.MeshBasicMaterial({color: 0xbaffd0, transparent: true, opacity: 0.95, depthWrite: false, side: THREE.DoubleSide});
  for (let i = 0; i < 6; i++) { const pv = new THREE.Group(); pv.rotation.y = i / 6 * Math.PI * 2; const m = new THREE.Mesh(new THREE.CircleGeometry(1, 24), pm); m.scale.set(0.46, 1, 1); m.position.z = 1; pv.add(m); g.add(pv); pv.userData.m = m; }
  const inner = new THREE.Mesh(new THREE.CircleGeometry(0.45, 32), addMat(0xffffff, 1)); inner.rotation.x = -Math.PI / 2; inner.position.y = 0.05; g.add(inner);
  addFx(g, 1.3, (o, u) => { const t = u * 1.3, open = E.back(Math.min(1, t / 0.28)); const s = c.R * 0.55 * open; o.scale.setScalar(Math.max(0.01, s));
    o.children.forEach(pv => { if (pv.userData.m) { pv.userData.m.rotation.x = -Math.PI / 2 + (1 - open) * 1.3; } }); pm.opacity = 0.95 * (1 - win(t, 0.6, 1.3)); inner.material.opacity = 1 - win(t, 0.2, 0.9); o.rotation.y = t * 0.6; });
  const col = new THREE.Mesh(new THREE.CylinderGeometry(1, 1.6, 1, 24, 1, true), addMat(0xd8ffe0, 0.9)); col.position.copy(B); scene.add(col);
  addFx(col, 0.7, (o, u) => { const h = 40 * E.out(Math.min(1, u * 2.5)); o.scale.set(3 * (1 - u * 0.6), h, 3 * (1 - u * 0.6)); o.position.y = h / 2; o.material.opacity = 0.9 * (1 - u); });
  groundRing(B, c.R, 0xffffff, 0.55, 2); later(0.08, () => groundRing(B, c.R * 1.02, LEAF, 0.7, 2));
  for (let i = 0; i < 26; i++) { const a = Math.random() * Math.PI * 2, r = Math.random() * c.R; const s = petalSprite(B.clone().add(V(Math.cos(a) * 2, 3, Math.sin(a) * 2)), 1.8 + Math.random()); const tgt = B.clone().add(V(Math.cos(a) * r, 8 + Math.random() * 8, Math.sin(a) * r));
    addFx(s, 1.6, (o, u) => { o.position.lerpVectors(B.clone().setY(3), tgt, E.out(Math.min(1, u * 1.6))); o.position.y -= u * u * 7; o.material.rotation = u * 6 + i; o.material.opacity = 1 - win(u, 0.7, 1); }); scene.add(s); }
  later(0.1, () => applyBurst(B, c, R => { for (let i = 0; i < 6; i++) { const s = petalSprite(rapChest(R), 1.6); scene.add(s); addFx(s, 1.1, (o, u) => { const a = u * 9 + i; o.position.copy(rapChest(R)).add(V(Math.cos(a) * 4, -3 + u * 8, Math.sin(a) * 4)); o.material.opacity = 1 - u; }); } aura(() => R.rig.pos, 5.5, LEAF, c.amp, 0.3); },
    R => { const r = ringMesh(0.8, 1, NOHEAL, 0.9); r.position.copy(R.rig.pos).setY(0.2); scene.add(r); addFx(r, 1.2, (o, u) => { o.scale.setScalar(6 * (1 - u * 0.5)); o.material.opacity = 0.9 * (1 - u); }); puff(rapChest(R), V(0, -6, 0), 4, 0x6a3a8a, 0.8, 0.6); }));
}
// B · Spore Geyser: the bud bursts into the ground (green cracks run out to the edge), a geyser of light shoots up and spores rain
// over the whole area; a rune circle turns on the ground; heal beams reach from the geyser to each squadmate.
function burstB(B, c) {
  const g0 = B.clone().setY(0.2); flash(g0.clone().setY(2), 16, 0xd8ffe0); shake = 0.5; hitStop = 0.04;
  for (let i = 0; i < 9; i++) { const a = i / 9 * Math.PI * 2 + Math.random() * 0.3; const end = B.clone().add(V(Math.cos(a) * c.R, 0, Math.sin(a) * c.R)); const mt = addMat(LEAF_PALE, 1); const m = cylBetween(g0, g0.clone().lerp(end.setY(0.2), 0.01), 0.35, mt); scene.add(m);
    addFx(m, 1.0, (o, u) => { const L = c.R * E.out(Math.min(1, u * 4)); o.scale.set(1, Math.max(0.01, L), 1); o.position.copy(g0).add(V(Math.cos(a) * L / 2, 0, Math.sin(a) * L / 2)); mt.opacity = 1 - win(u, 0.4, 1); }); }
  later(0.22, () => { const core = new THREE.Mesh(new THREE.CylinderGeometry(1.2, 2.2, 1, 20, 1, true), addMat(0xd8ffe0, 0.95)); core.position.copy(B); scene.add(core); shake = 0.6;
      addFx(core, 0.9, (o, u) => { const h = 34 * E.out(Math.min(1, u * 3)); o.scale.set(1 + u, h, 1 + u); o.position.y = h / 2; o.material.opacity = 0.95 * (1 - u); });
      rising(() => B.clone().add(V((Math.random() - .5) * 3, 1, (Math.random() - .5) * 3)), LEAF_PALE, 0.5, 120, 1, 30);
      const rune = new THREE.Group(); rune.position.copy(B).setY(0.18); scene.add(rune);
      [1, 0.72, 0.42].forEach((r, i) => { const m = ringMesh(r - 0.025, r, i === 1 ? 0xffffff : LEAF, 0.9); rune.add(m); });
      for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2; const m = cylBetween(V(Math.cos(a) * 0.42, 0, Math.sin(a) * 0.42), V(Math.cos(a + 2.1) * 1, 0, Math.sin(a + 2.1) * 1), 0.012, addMat(LEAF, 0.8)); rune.add(m); }
      addFx(rune, 1.8, (o, u) => { o.scale.setScalar(c.R * E.out(Math.min(1, u * 5))); o.rotation.y = u * 1.6; o.children.forEach(m => { m.material.opacity = 0.9 * (1 - win(u, 0.5, 1)); }); });
      const rain = new THREE.Object3D(); let em = 0; addFx(rain, 1.3, (o, u, dt) => { em += dt * 110; while (em >= 1) { em -= 1; const a = Math.random() * Math.PI * 2, r = Math.sqrt(Math.random()) * c.R; const s = sprite(T_POD, LEAF_PALE, 0.9 + Math.random() * 0.6, true);
        s.position.copy(B).add(V(Math.cos(a) * r, 22 + Math.random() * 8, Math.sin(a) * r)); scene.add(s); const vy = -24 - Math.random() * 10; addFx(s, 1.0, (q, uu, d) => { q.position.y = Math.max(0.4, q.position.y + vy * d); q.material.opacity = uu < 0.1 ? uu * 10 : 1 - uu; }); } });
      later(0.15, () => applyBurst(B, c, R => { const a = B.clone().setY(16); const mt = addMat(LEAF_PALE, 1); const m = cylBetween(a, rapChest(R), 0.45, mt); scene.add(m); addFx(m, 0.6, (o, u) => { mt.opacity = 1 - u; }); aura(() => R.rig.pos, 5.5, LEAF, c.amp, 0.3); },
        R => { puff(rapChest(R).add(V(0, 3, 0)), V(0, -3, 0), 5, 0x5a2f78, 1.2, 0.7); })); });
}
// C · Pollen Shock: the bud spins and squeezes tight (the wind-up of the burst), then a double flash: a green shell of pollen blows
// out to the edge, pollen and leaves skid across the ground; a green ring climbs each squadmate; enemies are left in a grey-violet
// pollen haze.
function burstC(B, c) {
  const p = B.clone().setY(2); flash(p, 10, 0xffffff); later(0.07, () => { flash(p, 30, 0xeaffd8); hitStop = 0.07; shake = 0.8; });
  later(0.07, () => { const sh = new THREE.Mesh(new THREE.SphereGeometry(1, 40, 20, 0, Math.PI * 2, 0, Math.PI / 2), rimMat(0x8dffb6, 1.6, 0.06, 1.0)); sh.position.copy(B).setY(0); scene.add(sh);
    addFx(sh, 0.6, (o, u) => { o.scale.setScalar(Math.max(0.01, c.R * E.out(u))); o.material.uniforms.a.value = 1 - u; });
    for (let i = 0; i < 70; i++) { const a = Math.random() * Math.PI * 2; const v = V(Math.cos(a), 0, Math.sin(a)).multiplyScalar(c.R * (1.6 + Math.random() * 1.4)); const s = i % 4 ? sprite(T_POD, i % 2 ? 0xe9ff9a : LEAF_PALE, 1 + Math.random(), true) : petalSprite(V(0, 0, 0), 1.6);
      s.position.copy(B).add(V(0, 0.8 + Math.random() * 3, 0)); scene.add(s); addFx(s, 1.0, (o, u, d) => { v.multiplyScalar(Math.pow(0.04, d)); o.position.addScaledVector(v, d); if (o.material.rotation !== undefined) o.material.rotation += d * 4; o.material.opacity = 1 - u; }); }
    applyBurst(B, c, R => { const r = torus(4.5, 0.25, LEAF_PALE, 1); r.rotation.x = Math.PI / 2; scene.add(r); addFx(r, 0.9, (o, u) => { o.position.copy(R.rig.pos).setY(u * 14); o.material.opacity = 1 - u; }); aura(() => R.rig.pos, 5.5, LEAF, c.amp, 0.3); },
      R => { const o0 = new THREE.Object3D(); let em = 0; addFx(o0, c.amp, (o, u, dt) => { em += dt * 10; while (em >= 1) { em -= 1; puff(rapChest(R).add(V((Math.random() - .5) * 5, 2 + Math.random() * 3, (Math.random() - .5) * 5)), V(0, 1, 0), 3, 0x7a6a8a, 0.9, 0.45); } }); }); });
}
// L · in the game now (TrooSlotFX 1.0): a green flash, two flat rings out to the radius, green sparks
function burstL(B, c) { const p = B.clone().setY(2); flash(p, 14, 0xd8ffe0); groundRing(B, c.R, LEAF, 0.6, 2); groundRing(B, c.R * 0.75, 0xffffff, 0.45, 1); sparks(p, V(0, 1, 0), 12, LEAF_PALE, 0.5); applyBurst(B, c); }
const BURSTS = {A: burstA, B: burstB, C: burstC, L: burstL};

function burstTrackV() {
  const st = VFX.burst, c = cfgNow("burst");
  zoneScene2(); S.max = S2.max = 60; setHp(S, 24); setHp(S2, 30); S.hpShow = S2.hpShow = true;
  const cc = NK.budCarry; const B = V(-1, 0, -41);
  const T0 = 0.6, REL = T0 + 0.34, FLY = 0.5, LAND = REL + FLY, OPEN = LAND + (st === "C" ? 0.42 : 0.3), POD = OPEN + 1.8, END = POD + 0.37 + 2.0;
  const keys = idleIntro([...THROW(T0), ...THROW(POD - 0.34).slice(0, 4), K(POD + 0.8, T_READY, "io")], T0);
  let p0 = null;
  const ev = [{t: T0, f: () => glowAt(() => carryPos(cc), LEAF, 5, REL - T0, 0.9)}, {t: REL, f: () => { p0 = carryPos(cc); trailOn(() => carryPos(cc), LEAF, FLY, 40, 1.1); }},
    {t: OPEN, f: () => BURSTS[st](B, c)},
    {t: POD, f: () => throwPod({kind: "pod", from: handsPoint(), target: () => V(-1, 1, -42), T: 0.37, H: 8, onHit: p => { zoneAt(p, {heal: 5, self: 2, onHeal: () => {}, ampFn: true}); }})}];
  const O = OPTS.burst.find(o => o.k === st);
  return {frame: [V(0, 0, 4), V(0, 0, -46 - c.R * 0.5)], keys, ev, eyes: [[T0, REL + 0.3], [POD - 0.3, POD + 0.2]],
    update(t, dt) { PGLOW.burst = 0.5; for (const R of raps) { R.amp = Math.max(0, (R.amp || 0) - dt); R.noheal = Math.max(0, (R.noheal || 0) - dt); }
      cc.k = t < END - 1.2 ? 1 : E.back(win(t, END - 1.2, END - 0.8)); if (t > OPEN && t < END - 1.2) cc.k = 0.001; },
    post(t) { if (t < T0) { carryOff(cc); return; } const dock = dockWorld(cc);
      if (t < REL) { carryAt(cc, lerpM(dock, worldM(handsPoint(), 0, 3.4), E.io(win(t, T0 + 0.02, REL - 0.04)))); return; }
      if (t < LAND) { const u = win(t, REL, LAND); const p = p0.clone().lerp(B.clone().setY(0.8), u); p.y += 4 * 7 * u * (1 - u); carryAt(cc, worldM(p, t * 6, 3.4)); return; }
      if (t < OPEN) { const u = win(t, LAND, OPEN);
        if (st === "C") { const k = 3.4 * (1 + 0.5 * E.out(Math.min(1, u * 2))) * (u > 0.5 ? 1 - 0.55 * E.in2((u - 0.5) * 2) : 1); carryAt(cc, worldM(B.clone().setY(1.2 + u * 2), t * 30 * u, k)); return; } // spin + squeeze
        if (st === "B") { carryAt(cc, worldM(B.clone().setY(0.8 - 1.4 * E.in2(u)), t * 4, 3.4 * (1 + 0.4 * E.out(u)))); return; } // swells and sinks into the ground
        const k = 3.4 + 2.6 * E.back(u); carryAt(cc, worldM(B.clone().setY(0.6 + k * 0.17), 0, k)); return; }
      carryOff(cc); },
    phases: [[0, T0, "Slotted: the bud hangs in its belly sling"], [T0, REL, "Wind-up: the bud drops into both hands"], [REL, LAND, "Throw: the bud flies on the pod arc"],
      [LAND, OPEN, O.ph[0]], [OPEN, OPEN + 1.0, O.ph[1]], [OPEN + 1.0, POD, "Squadmates within " + c.R + " studs: +20 and +50% healing " + fmt(c.amp) + " s; enemies heal 50% less"], [POD, END - 1.2, "Next pod: the boosted squadmates heal +7.5/s in the zone (5 x 1.5)"], [END - 1.2, END, O.ph[2]]],
    len: END};
}
BUILD.dome = domeTrackV; BUILD.burst = burstTrackV;

// ---------- the options (what each one is, how it plays, what it is built from in Roblox) ----------
const OPTS = {
  dome: [
    {k: "A", name: "Lattice Bastion", rec: true, one: "A frame of light builds up from the ground row by row into a full dome, with a glowing edge so you always see where cover ends. A hit lights up the exact panel it struck.",
      ph: ["The canister fires up a ring; the frame builds from the ground up, light pillars flare at the base", "Built: a scan band sweeps up the dome; each blocked shot lights the panel it hit + a ripple", "Recovery: the frame drops away top-down into the canister; a new canister builds on the tail"],
      roblox: "Frame = ~270 thin Neon parts (a geodesic half-sphere, built by the server or saved as one Model) that turn on row by row (Transparency tween); shell = a ForceField half-sphere + a Highlight for the bright edge; base = Neon ring MeshPart + 10 Beam pillars; scan band = a Neon ring tweened up; hit = the struck panel (a Neon wedge pair) flashes white + a flat ring + sparks. No new images.",
      cost: "Most parts (~290 per dome); only one dome per troodon at a time.", follows: "Shield blue 5AB4FF / BFE6FF; TenoMovesFX flat rings; the Sap Wall's 'solid cover' read."},
    {k: "B", name: "Bubble Shield", one: "A glossy bubble inflates out of the canister with a wobble, its colour drifting from cyan to violet; bands of energy orbit inside. Hits send ripples across it and make it jiggle; it pops at the end.",
      ph: ["The canister pops open; the bubble inflates with a springy overshoot", "Up: colour drifts, energy bands orbit, motes rise inside; each hit = ripples + a jiggle", "Recovery: the bubble pops into droplets and a ring; a new canister builds"],
      roblox: "Bubble = a Glass half-sphere (Transparency 0.7, Reflectance 0.3) + Highlight outline, Color tweened cyan ↔ violet; wobble = Size tween with Elastic easing (and a short squish on each hit); bands = 3 thin Neon ring MeshParts spun by a client loop; motes / droplets = ParticleEmitters; ripples = TenoMovesFX flat rings placed on the hit. No new images.",
      cost: "Light (~8 parts + 2 emitters).", follows: "Shield blue + a violet hint (the Sleep Dart violet); Med-Station soft glow."},
    {k: "C", name: "Aurora Pylon", one: "The canister stands up into a pylon with 3 spinning rings; a beam shoots to the top of the dome and 16 curtains of light fan open around it like an umbrella, with light running down them. A hit cracks a bolt to the nearest curtain.",
      ph: ["The canister stands up into a pylon; a beam goes up and the curtains fan open", "Up: light runs down the curtains, the pylon rings spin; each hit cracks a bolt to the nearest curtain", "Recovery: the curtains fold back into the pylon and it sinks into the ground"],
      roblox: "Pylon = the canister pieces + 3 Neon ring MeshParts (client spin); curtains = 16 Beams from the top Attachment to ground Attachments, curved (CurveSize) with a scrolling light texture (TextureSpeed); shell = a faint ForceField half-sphere; bolt = a Beam with a lightning texture. Needs 2 image uploads (light streak, lightning).",
      cost: "Light (~6 parts + 17 Beams); 2 images to upload.", follows: "Arc Lantern's lightning bolts; shield blue."},
    {k: "L", name: "In the game now", one: "What the game draws today: the server's ForceField ball (nearly invisible, most of all from inside) and a small blue ripple on a blocked hit.",
      ph: ["The ball grows out of the canister", "Up: almost invisible; a small ripple on a block", "The ball shrinks away"], roblox: "TrooSlotServer 1.1 ForceField Ball + TrooSlotFX 1.0 ripple.", cost: "—", follows: "—"}],
  burst: [
    {k: "A", name: "Blossom Nova", rec: true, one: "The bud blooms: 6 big petals unfold flat on the ground, a column of light shoots up and a white-green shockwave rolls out to the edge. Petals drift over the squad, each squadmate gets a petal swirl; enemies get a violet wilt ring.",
      ph: ["Lands and swells: the petals tremble", "Bloom: petals unfold, the light column shoots up, the shockwave rolls out", "Recovery: the petals fade and drift down; a new bud grows in the sling"],
      roblox: "Petals = 6 Neon MeshParts tweened open (CFrame) then faded; column = a Neon cylinder tweened up + faded; shockwave = 2 TenoMovesFX flat rings; drifting petals + swirls = ParticleEmitters with a petal image (1 upload); wilt = a flat violet ring + dark puff.",
      cost: "Light; 1 image to upload (petal).", follows: "Med-Station green, the Bloom Tank / glow zone flower theme, TenoMovesFX rings."},
    {k: "B", name: "Spore Geyser", one: "The bud dives into the ground: green cracks run out to the edge, then a geyser of light shoots up and spores rain over the whole area while a rune circle turns on the ground. Heal beams reach from the geyser to each squadmate.",
      ph: ["Lands: the bud swells and sinks into the ground", "Cracks run out, the geyser erupts, spores rain over the area, the rune circle turns", "Recovery: the rain thins out; a new bud grows in the sling"],
      roblox: "Cracks = 9 thin Neon parts tweened out; geyser = a Neon cylinder + an upward ParticleEmitter; spore rain = a ParticleEmitter on an invisible disc 25 studs up; rune = 3 Neon ring MeshParts + 6 Neon spokes (no image); heal beams = Beams from the geyser to each squadmate.",
      cost: "Medium (~20 parts + 2 emitters).", follows: "The glow zone's spores, Med-Station heal beams."},
    {k: "C", name: "Pollen Shock", one: "The bud spins and squeezes tight, then a double flash: a green shell of pollen blows out to the edge and pollen and leaves skid across the ground. A green ring climbs each squadmate; enemies stay in a grey-violet pollen haze while they can't heal.",
      ph: ["Lands, spins and squeezes tight (the burst's wind-up)", "Double flash; the pollen shell blows out to the edge; pollen skids across the ground", "Recovery: the pollen settles; a new bud grows in the sling"],
      roblox: "Squeeze = bud Size/CFrame tween; shell = a ForceField half-sphere tweened out + faded; pollen = a ParticleEmitter burst (flat SpreadAngle, Drag); rings = a Neon ring MeshPart tweened up each squadmate; haze = a ParticleEmitter parented to each enemy for the heal cut.",
      cost: "Light (~4 parts + emitters).", follows: "The Bloom Tank's zone spores, the hit-stop 'punch' of the live pods."},
    {k: "L", name: "In the game now", one: "What the game draws today (TrooSlotFX 1.0): a green flash, two flat rings out to the edge and a few green sparks.",
      ph: ["The bud lands and swells", "A flash, two rings and sparks", "The bud regrows"], roblox: "TrooSlotFX 1.0.", cost: "—", follows: "—"}]};

// ---------- page: 2 tabs (Bloom Burst, Shield Dome), the Effect row, option cards ----------
(function () { const keep = CANDS.filter(c => c.id === "burst" || c.id === "dome"); CANDS.splice(0, CANDS.length, ...keep); cur = 0; })();
CANDS.find(c => c.id === "dome").steps = ["Throw a canister up to 30 studs; a dome 90 studs wide stands for 5 s: enemy shots stop on it; yours pass out. Recharge 25 s", "The dome lasts 6.75 s", "Recharge 18.5 s", "The dome is 121.5 studs wide"];
CANDS.find(c => c.id === "dome").covers = "Effect options"; CANDS.find(c => c.id === "burst").covers = "Effect options";
mode = "boost"; rank = 3;
document.querySelectorAll("[data-mode]").forEach(b => { b.hidden = true; }); $("liveChip").hidden = true;
(function () { const moves = $("moves"); moves.style.gridTemplateColumns = "repeat(2, minmax(0, 1fr))";
  const row = document.createElement("div"); row.className = "row"; row.innerHTML = '<span class="lbl">Effect</span><span id="optRow" class="row"></span>'; moves.after(row);
  row.addEventListener("click", e => { const b = e.target.closest("[data-opt]"); if (!b) return; VFX[CUR().id] = b.dataset.opt; start(); renderAll(); }); })();
const OPT = () => OPTS[CUR().id].find(o => o.k === VFX[CUR().id]);
renderRec = function () {
  $("recCard").innerHTML = `<div class="kind" style="color:var(--good)">Pick one effect for each part</div>
    <p>Kepu 10:38: "better vfx, it looks so lazy". Each part has 3 new options (A, B, C) and <b>In the game now</b> for comparison. The dome here is the new size from SkillTree 1.86: <b>90 studs wide</b> (I–III), <b>121.5 at ★</b>. Bloom Burst numbers are unchanged (40 wide, 54 at ★).</p>
    <p class="note">Pick e.g. "Dome A, Burst B". Drag to orbit, wheel / pinch or + / − to zoom; "Whole move" camera is the default here, "3/4 close" and "Part close-up" go in close.</p>`;
};
renderAll = function () {
  const c = CUR(), id = c.id, o = OPT();
  $("moves").innerHTML = CANDS.map((m, i) => `<button class="tab" data-i="${i}" aria-pressed="${i === cur}">${m.name}<small><span class="pill btn2">Button</span>${OPTS[m.id].find(x => x.k === VFX[m.id]).name}</small></button>`).join("");
  $("rankRow").innerHTML = RANKS.map((r, i) => `<button class="chip" data-rank="${i}" aria-pressed="${i === rank}">${r}</button>`).join("");
  $("optRow").innerHTML = OPTS[id].map(x => `<button class="chip" data-opt="${x.k}" aria-pressed="${x.k === VFX[id]}">${x.k === "L" ? "" : x.k + " · "}${x.name}${x.rec ? " ★" : ""}</button>`).join("");
  const ph = play.track.phases; $("phases").innerHTML = ph.map(p => `<button class="ph" data-t="${p[0]}" aria-current="false"><i>${p[0].toFixed(2)}–${p[1].toFixed(2)} s</i>${p[2]}</button>`).join("");
  $("info").innerHTML = `<div class="kind" style="color:${o.k === "L" ? "var(--muted)" : "#c25e08"}">${c.name} · ${o.k === "L" ? "in the game now" : "effect option " + o.k}${o.rec ? ' <span class="rec">My pick</span>' : ""}</div><h2>${o.name}</h2><p>${o.one}</p>
    <h3>Wind-up → action → result → recovery</h3><ul>${play.track.phases.map(p => `<li>${p[2]}</li>`).join("")}</ul>
    <h3>Built in Roblox from</h3><p class="note">${o.roblox}</p>${o.k === "L" ? "" : `<h3>Matches the roster</h3><p class="note">${o.follows}</p>`}`;
  $("part").innerHTML = `<div class="kind">All ${c.name} options</div><div class="tw"><table class="cmp"><tr><th>Option</th><th>Look</th><th>Cost</th></tr>${OPTS[id].map(x => `<tr class="${x.k === VFX[id] ? "cur" : ""}"><th>${x.k === "L" ? "Now" : x.k}${x.rec ? " ★" : ""}</th><td>${x.name}</td><td>${x.cost}</td></tr>`).join("")}</table></div>
    <h3>${c.name} numbers</h3><ul>${c.steps.map((s, i) => `<li><b>${RANKS[i]}</b> ${s}</li>`).join("")}</ul>
    <p class="note">★ = my pick${id === "dome" ? ": the frame shows exactly where cover ends from inside and outside, and the panel flash shows each block" : ": it reads as a bloom (the part's name) and the shockwave shows the heal edge"}. Your call.</p>`;
};
foot = function () { $("foot").innerHTML = `<b>Notes</b><ol><li><b>Same rules as every part:</b> wind-up → action → result → recovery; no landing FX (the bud and canister land quietly, the effect starts on their own opening).</li>
  <li><b>Scene:</b> the troodon throws 12 studs ahead (the body-aim landing in MechaButtons 1.45); 2 enemy raptors ~100 studs out shoot the hurt squadmate; your pod goes out through the dome.</li>
  <li><b>In the game now</b> is drawn the way the game draws it, so you can compare like for like.</li>
  <li><b>Sizes</b> are game studs; the dome is a half-sphere on the ground (the server's ball is centred on the ground).</li></ol>`; };
const overlays0 = overlays;
overlays = function () { overlays0(); const mt = $("modetag"); mt.className = "modetag " + (VFX[CUR().id] === "L" ? "today" : "boost"); mt.textContent = CUR().name.toUpperCase() + " · " + OPT().name.toUpperCase() + " · rank " + RANKS[rank]; };
document.querySelectorAll("[data-view]").forEach(x => x.setAttribute("aria-pressed", x.dataset.view === "scene"));
$("ver").textContent = "v" + VFX_VERSION;
start(); renderRec(); renderAll(); foot();
window.__vfx = {set(id, opt, rk, time, cm) { window.__manual = true; cur = CANDS.findIndex(c => c.id === id); VFX[id] = opt; if (rk !== undefined) rank = rk; if (cm) camMode = cm; view.zoom = 1; view.yaw = 0; view.pitch = 0; start(); renderAll(); seek(time); overlays(); }, view};
