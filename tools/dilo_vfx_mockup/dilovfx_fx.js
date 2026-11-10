// dilovfx_fx.js v0.1 (Mecha Dino Arena) — Dilo mecha part EFFECT families for docs/mockups/dilo_vfx_v0.1.html (Kepu 2026-11-10 13:49:
// "the dilo vfx for the mecha animations need a total rework ... all the vfx of the mecha parts are straight ass"; scope "Dilo's parts
// only"). Runs after tools/mockup/dilo_parts_looks.js (engine, rig, the 7 picked part models, the old tracks) up to its player.
// Three effect families, each a full kit used by all 7 parts (wind-up -> action -> result -> recovery; no landing FX):
//   A Liquid Venom  — the venom is the ammo: glossy goo that wobbles and drips, splash crowns, bubbling mist, venom fire.
//   B Reactor Glow  — mecha energy: white-hot cores in green glow, long tracers, hex rings, shockwaves, holo reticles, plasma thrust.
//   C Chem Warfare  — military chem: muzzle smoke + spent casings, smoke-trailed darts, chemical smoke clouds, hazard rings, rocket fire.
const V3 = (x, y, z) => new THREE.Vector3(x || 0, y || 0, z || 0);
const UPV = V3(0, 1, 0);
const rnd = (a) => (Math.random() - 0.5) * 2 * (a === undefined ? 1 : a);
const win = (t, a, b) => Math.max(0, Math.min(1, (t - a) / (b - a)));
const addM = (c, op) => new THREE.MeshBasicMaterial({color: c, transparent: true, opacity: op === undefined ? 1 : op, depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending});
const normM = (c, op) => new THREE.MeshBasicMaterial({color: c, transparent: true, opacity: op === undefined ? 1 : op, depthWrite: false, side: THREE.DoubleSide});
const gloss = (c, e, op) => new THREE.MeshPhongMaterial({color: c, emissive: e || 0x000000, shininess: 110, specular: 0xffffff, transparent: op !== undefined, opacity: op === undefined ? 1 : op, depthWrite: op === undefined});
const SPH = new THREE.SphereGeometry(1, 18, 12);
const CYL = new THREE.CylinderGeometry(1, 1, 1, 8, 1, true);
const CONE = (() => { const g = new THREE.ConeGeometry(1, 1, 14, 1, true); g.translate(0, -0.5, 0); g.rotateX(-Math.PI / 2); return g; })(); // apex at 0, opens toward +Z
function cylBetween(a, b, r, mat) { const d = b.clone().sub(a), L = Math.max(1e-3, d.length()); const m = new THREE.Mesh(CYL, mat);
  m.position.copy(a).addScaledVector(d, 0.5); m.quaternion.setFromUnitVectors(UPV, d.normalize()); m.scale.set(r, L, r); return m; }
function rimMat(color, power, base, k) {
  return new THREE.ShaderMaterial({uniforms: {c: {value: new THREE.Color(color)}, p: {value: power}, b: {value: base}, k: {value: k}, a: {value: 1}},
    vertexShader: "varying vec3 vN; varying vec3 vV; void main(){ vec4 w = modelMatrix * vec4(position, 1.0); vN = normalize(mat3(modelMatrix) * normal); vV = normalize(cameraPosition - w.xyz); gl_Position = projectionMatrix * viewMatrix * w; }",
    fragmentShader: "uniform vec3 c; uniform float p; uniform float b; uniform float k; uniform float a; varying vec3 vN; varying vec3 vV; void main(){ float f = pow(1.0 - abs(dot(normalize(vN), normalize(vV))), p); gl_FragColor = vec4(c, clamp((b + f * k) * a, 0.0, 1.0)); }",
    transparent: true, depthWrite: false, side: THREE.DoubleSide});
}
function canvasTex(w, h, draw) { const c = document.createElement("canvas"); c.width = w; c.height = h; draw(c.getContext("2d"), w, h); return new THREE.CanvasTexture(c); }
const T_SMOKE = canvasTex(128, 128, x => { for (let i = 0; i < 10; i++) { const cx = 64 + rnd(24), cy = 64 + rnd(24), r = 20 + Math.random() * 22; const g = x.createRadialGradient(cx, cy, 0, cx, cy, r);
  g.addColorStop(0, "rgba(255,255,255,0.5)"); g.addColorStop(1, "rgba(255,255,255,0)"); x.fillStyle = g; x.beginPath(); x.arc(cx, cy, r, 0, Math.PI * 2); x.fill(); } });
const T_STAR = canvasTex(128, 128, x => { x.globalCompositeOperation = "lighter"; for (const [sx, sy] of [[1, 0.07], [0.07, 1]]) { x.save(); x.translate(64, 64); x.scale(sx, sy);
  const g = x.createRadialGradient(0, 0, 0, 0, 0, 64); g.addColorStop(0, "rgba(255,255,255,1)"); g.addColorStop(1, "rgba(255,255,255,0)"); x.fillStyle = g; x.beginPath(); x.arc(0, 0, 64, 0, Math.PI * 2); x.fill(); x.restore(); }
  const g = x.createRadialGradient(64, 64, 0, 64, 64, 30); g.addColorStop(0, "rgba(255,255,255,1)"); g.addColorStop(1, "rgba(255,255,255,0)"); x.fillStyle = g; x.fillRect(0, 0, 128, 128); });
const T_RINGS = canvasTex(128, 128, x => { const g = x.createRadialGradient(64, 64, 34, 64, 64, 63); g.addColorStop(0, "rgba(255,255,255,0)"); g.addColorStop(0.62, "rgba(255,255,255,1)"); g.addColorStop(1, "rgba(255,255,255,0)"); x.fillStyle = g; x.fillRect(0, 0, 128, 128); });
const T_HEX = canvasTex(256, 256, x => { x.strokeStyle = "rgba(255,255,255,1)"; x.lineWidth = 2.5; const r = 15, hh = Math.sqrt(3) * r;
  for (let col = -1; col < 13; col++) for (let row = -1; row < 12; row++) { const cx = col * 1.5 * r, cy = row * hh + (col % 2 ? hh / 2 : 0); x.beginPath();
    for (let k = 0; k < 7; k++) { const a = k * Math.PI / 3, px = cx + r * Math.cos(a), py = cy + r * Math.sin(a); k ? x.lineTo(px, py) : x.moveTo(px, py); } x.stroke(); }
  x.globalCompositeOperation = "destination-in"; const g = x.createRadialGradient(128, 128, 0, 128, 128, 128); g.addColorStop(0, "rgba(0,0,0,0.35)"); g.addColorStop(0.86, "rgba(0,0,0,1)"); g.addColorStop(1, "rgba(0,0,0,0)");
  x.fillStyle = g; x.fillRect(0, 0, 256, 256); });
const T_HAZ = canvasTex(256, 256, x => { const n = 28; for (let i = 0; i < n; i++) { const a0 = i / n * Math.PI * 2, a1 = (i + 1) / n * Math.PI * 2; x.fillStyle = i % 2 ? "#1c1d16" : "#ffc21a";
  x.beginPath(); x.arc(128, 128, 126, a0, a1); x.arc(128, 128, 108, a1 + 0.05, a0 + 0.05, true); x.closePath(); x.fill(); } });
const T_RETI = canvasTex(256, 256, x => { x.strokeStyle = "#fff"; x.lineWidth = 6; x.beginPath(); x.arc(128, 128, 120, 0, Math.PI * 2); x.stroke(); x.lineWidth = 2.5; x.beginPath(); x.arc(128, 128, 98, 0, Math.PI * 2); x.stroke();
  for (let i = 0; i < 24; i++) { const a = i / 24 * Math.PI * 2, r0 = i % 2 ? 106 : 100; x.beginPath(); x.moveTo(128 + r0 * Math.cos(a), 128 + r0 * Math.sin(a)); x.lineTo(128 + 117 * Math.cos(a), 128 + 117 * Math.sin(a)); x.stroke(); }
  x.lineWidth = 7; for (let i = 0; i < 4; i++) { const a = i * Math.PI / 2 + Math.PI / 4; x.beginPath(); x.arc(128, 128, 70, a - 0.32, a + 0.32); x.stroke(); }
  x.lineWidth = 3; x.beginPath(); x.moveTo(128, 108); x.lineTo(128, 148); x.moveTo(108, 128); x.lineTo(148, 128); x.stroke(); });
const T_BUB = canvasTex(64, 64, x => { const g = x.createRadialGradient(32, 32, 16, 32, 32, 30); g.addColorStop(0, "rgba(230,255,190,0.12)"); g.addColorStop(0.8, "rgba(230,255,190,0.95)"); g.addColorStop(1, "rgba(230,255,190,0)");
  x.fillStyle = g; x.beginPath(); x.arc(32, 32, 30, 0, Math.PI * 2); x.fill(); x.fillStyle = "rgba(255,255,255,0.95)"; x.beginPath(); x.arc(23, 21, 5, 0, Math.PI * 2); x.fill(); });
const T_CHEV = canvasTex(64, 128, x => { x.strokeStyle = "#fff"; x.lineWidth = 9; x.lineCap = "round"; for (const y of [30, 90]) { x.beginPath(); x.moveTo(10, y + 22); x.lineTo(32, y); x.lineTo(54, y + 22); x.stroke(); } });
T_CHEV.wrapS = T_CHEV.wrapT = THREE.RepeatWrapping;
const T_STRIPE = canvasTex(64, 64, x => { x.fillStyle = "#ffc21a"; x.fillRect(0, 0, 64, 64); x.fillStyle = "#1c1d16"; for (let i = -64; i < 128; i += 22) { x.beginPath(); x.moveTo(i, 0); x.lineTo(i + 11, 0); x.lineTo(i + 75, 64); x.lineTo(i + 64, 64); x.closePath(); x.fill(); } });

// ---------- generic pieces ----------
function spr(tex, color, size, add, p) { const s = sprite(tex, color, size, add); if (p) s.position.copy(p); return s; }
function glow(p, color, size, life, grow) { const s = spr(T_FLASH, color, size, true, p); return addFx(s, life || 0.16, (o, u) => { o.scale.setScalar(size * (0.5 + u * (grow || 1.3))); o.material.opacity = 1 - u; }); }
function star(p, color, size, life) { const s = spr(T_STAR, color, size, true, p); s.material.rotation = Math.random() * Math.PI; return addFx(s, life || 0.14, (o, u) => { o.scale.setScalar(size * (0.6 + u * 0.8)); o.material.opacity = 1 - u * u; }); }
function smoke(p, v, size, color, life, op, grow, rise) { const s = spr(T_SMOKE, color, size, false, p); s.material.rotation = Math.random() * 6; const sp = rnd(1.2);
  return addFx(s, life, (o, u, dt) => { v.multiplyScalar(Math.pow(0.12, dt)); v.y += (rise || 0) * dt; o.position.addScaledVector(v, dt); o.material.rotation += sp * dt; o.scale.setScalar(size * (1 + u * (grow === undefined ? 1.6 : grow))); o.material.opacity = (op || 0.7) * (u < 0.1 ? u * 10 : 1 - E.in2((u - 0.1) / 0.9)); }); }
function drop(p, v, size, life, color, grav) { const s = spr(T_DROP, color, size, false, p);
  return addFx(s, life, (o, u, dt) => { v.y -= (grav === undefined ? 55 : grav) * dt; o.position.addScaledVector(v, dt); if (o.position.y < 0.5) { o.position.y = 0.5; v.multiplyScalar(0); } o.material.opacity = u > 0.55 ? (1 - u) / 0.45 : 1; o.scale.setScalar(size * (1 - u * 0.5)); }); }
function spark(p, v, color, life, size, grav, drag) { const s = spr(T_SPARK, color, size, true, p);
  return addFx(s, life, (o, u, dt) => { v.y -= (grav === undefined ? 40 : grav) * dt; if (drag) v.multiplyScalar(Math.pow(drag, dt)); o.position.addScaledVector(v, dt); o.material.opacity = 1 - u; o.scale.setScalar(size * (1 - u * 0.7)); }); }
function sparkBurst(p, dir, n, color, spd, spread, life, size, grav) { for (let i = 0; i < n; i++) { const v = dir.clone().normalize().multiplyScalar(spd * (0.5 + Math.random() * 0.7)).add(V3(rnd(spd * spread), rnd(spd * spread), rnd(spd * spread)));
  spark(p.clone(), v, color, (life || 0.35) * (0.6 + Math.random() * 0.6), (size || 1) * (0.7 + Math.random() * 0.6), grav, 0.08); } }
function streak(a, b, r, color, life, op) { const m = cylBetween(a, b, r, addM(color, op === undefined ? 1 : op)); return addFx(m, life, (o, u) => { o.material.opacity = (op === undefined ? 1 : op) * (1 - u); o.scale.x = o.scale.z = r * (1 - u * 0.6); }); }
function bolt(a, b, color, life, jit, r) { const pts = [a.clone()]; const n = 6; for (let i = 1; i < n; i++) pts.push(a.clone().lerp(b, i / n).add(V3(rnd(jit), rnd(jit), rnd(jit)))); pts.push(b.clone());
  const g = new THREE.Group(); const mt = addM(color, 1); for (let i = 0; i < pts.length - 1; i++) g.add(cylBetween(pts[i], pts[i + 1], r || 0.18, mt));
  return addFx(g, life, (o, u) => { mt.opacity = (1 - u) * (0.6 + 0.4 * Math.sin(clockT * 90)); }); }
function axisRing(p, n, R, color, life, thick, add) { const m = new THREE.Mesh(new THREE.TorusGeometry(1, thick || 0.06, 6, 48), add === false ? normM(color, 0.9) : addM(color, 1)); m.position.copy(p);
  m.quaternion.setFromUnitVectors(V3(0, 0, 1), n.clone().normalize()); return addFx(m, life, (o, u) => { o.scale.setScalar(Math.max(0.01, R * E.out(u))); o.material.opacity = (add === false ? 0.9 : 1) * (1 - u); }); }
function flatRing(center, R, color, life, w, add, y) { const m = new THREE.Mesh(new THREE.RingGeometry(1 - (w || 0.1), 1, 72), add ? addM(color, 1) : normM(color, 0.85)); m.rotation.x = -Math.PI / 2; m.position.copy(center).setY(y || 0.16);
  return addFx(m, life, (o, u) => { o.scale.setScalar(Math.max(0.01, R * E.out(u))); o.material.opacity = (add ? 1 : 0.85) * (1 - u); }); }
function decal(center, R, tex, color, life, upd, add) { const m = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), new THREE.MeshBasicMaterial({map: tex, color, transparent: true, depthWrite: false, side: THREE.DoubleSide, blending: add ? THREE.AdditiveBlending : THREE.NormalBlending}));
  m.rotation.x = -Math.PI / 2; m.position.copy(center).setY((center.y || 0) + 0.14); m.scale.set(R, R, 1); return addFx(m, life, upd || ((o, u) => { o.material.opacity = 1 - u; })); }
function shockSphere(p, R, color, life, power, k) { const m = new THREE.Mesh(SPH, rimMat(color, power || 2.2, 0.0, k || 1.2)); m.position.copy(p);
  return addFx(m, life, (o, u) => { o.scale.setScalar(Math.max(0.01, R * E.out(u))); o.material.uniforms.a.value = 1 - u; }); }
function bubble(p, size, life, color, pop) { const s = spr(T_BUB, color || 0xe0ffb0, size, false, p); const ph = Math.random() * 6, vy = 2.5 + Math.random() * 3;
  return addFx(s, life, (o, u, dt) => { o.position.y += vy * dt; o.position.x += Math.sin(clockT * 6 + ph) * dt * 0.8; const k = u < 0.15 ? u / 0.15 : 1; o.scale.setScalar(size * k * (1 + 0.08 * Math.sin(clockT * 14 + ph)));
    if (u > 0.98 && !o.userData.p) { o.userData.p = 1; if (pop !== false) { glow(o.position, 0xeaffb0, size * 1.6, 0.1); for (let i = 0; i < 3; i++) drop(o.position.clone(), V3(rnd(6), 4 + Math.random() * 4, rnd(6)), 0.5, 0.35, GREEN); } } }); }
function casing(p, dir) { const m = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.16, 0.55, 8), new THREE.MeshLambertMaterial({color: 0xd9a441, emissive: 0x3a2400})); m.position.copy(p);
  const v = dir.clone().multiplyScalar(14 + Math.random() * 6).add(V3(rnd(3), 12 + Math.random() * 5, rnd(3))); const w = V3(rnd(20), rnd(20), rnd(20));
  return addFx(m, 0.7, (o, u, dt) => { v.y -= 60 * dt; o.position.addScaledVector(v, dt); o.rotation.x += w.x * dt; o.rotation.z += w.z * dt; if (o.position.y < 0.6) { o.position.y = 0.6; v.multiplyScalar(0); } o.material.transparent = true; o.material.opacity = u > 0.7 ? (1 - u) / 0.3 : 1; }); }
function debris(p, n, color, spd) { for (let i = 0; i < n; i++) { const m = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.5, 0.5), new THREE.MeshLambertMaterial({color, transparent: true})); m.position.copy(p); const s = 0.5 + Math.random();
  m.scale.setScalar(s); const v = V3(rnd(spd), spd * (0.5 + Math.random()), rnd(spd)); const w = V3(rnd(12), rnd(12), rnd(12));
  addFx(m, 0.8, (o, u, dt) => { v.y -= 70 * dt; o.position.addScaledVector(v, dt); o.rotation.x += w.x * dt; o.rotation.y += w.y * dt; if (o.position.y < 0.4) { o.position.y = 0.4; v.multiplyScalar(0); } o.material.opacity = u > 0.6 ? (1 - u) / 0.4 : 1; }); } }
// a projectile on an arc; o: {from, to (Vector3 or fn), T, H, obj, tick(p, vel, dt, u, prev, obj), onHit(p)}
function fly(o) { const toF = typeof o.to === "function" ? o.to : () => o.to; const prev = o.from.clone(); let done = false; const obj = o.obj || new THREE.Object3D(); obj.position.copy(o.from);
  return addFx(obj, o.T, (ob, u, dt) => { const p = o.from.clone().lerp(toF(), u); p.y += 4 * (o.H || 0) * u * (1 - u); const vel = p.clone().sub(prev);
    if (vel.lengthSq() > 1e-8) ob.quaternion.setFromUnitVectors(V3(0, 0, 1), vel.clone().normalize()); ob.position.copy(p); if (o.tick) o.tick(p, vel, dt, u, prev.clone(), ob); prev.copy(p);
    if (u >= 1 && !done) { done = true; if (o.onHit) o.onHit(p); } }); }
// something that follows a moving point for its life (per-frame emitters); f(p, dt, u, t)
function follow(pFn, life, f) { let t = 0; return addFx(new THREE.Object3D(), life, (o, u, dt) => { t += dt; f(pFn(), dt, u, t); }); }
function rate(state, key, r, dt, fn) { state[key] = (state[key] || 0) + r * dt; while (state[key] >= 1) { state[key] -= 1; fn(); } }
function randIn(R) { const a = Math.random() * Math.PI * 2, r = Math.sqrt(Math.random()) * R; return V3(Math.cos(a) * r, 0, Math.sin(a) * r); }
function hitR(R, p, n, col, push) { hitStop = Math.max(hitStop, 0.03); shake = Math.max(shake, 0.32); if (n) numberPop(p.clone().add(V3(0, 5, 0)), n, "hit");
  R.flinch = Math.max(R.flinch, 0.7); R.side = 0; R.flash = 0.1; R.flashCol = col || [0.35, 0.95, 0.15]; R.push = Math.max(R.push, push === undefined ? 0.9 : push); R.pushDir.copy(R.pos).sub(dilo.pos).setY(0).normalize(); }
function sector(center, dir, range, half, color, life, add) { const th = Math.atan2(-dir.z, dir.x); const m = new THREE.Mesh(new THREE.RingGeometry(0.0, 1, 48, 1, th - rad(half), rad(half * 2)), add ? addM(color, 0.5) : normM(color, 0.35));
  m.rotation.x = -Math.PI / 2; m.position.copy(center).setY(0.13); return addFx(m, life, (o, u) => { o.scale.setScalar(Math.max(0.01, range * E.out(Math.min(1, u * 2.2)))); o.material.opacity = (add ? 0.5 : 0.35) * (1 - u); }); }
function arcFront(center, dir, R, half, color, life, y, thick) { const th = Math.atan2(-dir.z, dir.x); const m = new THREE.Mesh(new THREE.TorusGeometry(1, thick || 0.025, 6, 40, rad(half * 2)), addM(color, 1));
  const g = new THREE.Group(); g.add(m); m.rotation.x = -Math.PI / 2; m.rotation.z = th - rad(half); g.position.copy(center).setY(y || center.y); return g; }

// ---------- palettes ----------
const PV = {A: {main: 0x8fe04a, hi: 0xeaffb0, deep: 0x3d8f14, glow: 0xb8ff70, gl: 0x2d7a10},
  B: {main: 0x5cff7e, hi: 0xf0fff4, deep: 0x1f8f4a, glow: 0x8affa0, acc: 0x45e0ff},
  C: {main: 0xc8ff3a, hi: 0xfff6c8, deep: 0x6a8a1a, glow: 0xe0ff70, haz: 0xffc21a, smoke: 0x9aa47a, fire: 0xff8a2a}};
const PB = {A: {main: 0x7fd8ff, hi: 0xe8fbff, deep: 0x2a86b0, glow: 0x9fe6ff, gl: 0x1d6f8f},
  B: {main: 0x55c8ff, hi: 0xf0fbff, deep: 0x1a6fa8, glow: 0x8fdcff, acc: 0xb8f0ff},
  C: {main: 0x7fd0ff, hi: 0xeaf8ff, deep: 0x3a7fa0, glow: 0xa8e4ff, haz: 0xffc21a, smoke: 0xc8d6de, fire: 0xff8a2a}};

// =====================================================================================================================================
// A · LIQUID VENOM
// =====================================================================================================================================
const KA = {
  muzzle(p, dir, s, P) { P = P || PV.A; s = s || 1; glow(p, P.hi, 4.5 * s, 0.14);
    const b = new THREE.Mesh(SPH, gloss(P.main, P.gl, 0.95)); b.position.copy(p); addFx(b, 0.16, (o, u) => { o.scale.setScalar(Math.max(0.01, 1.3 * s * E.out(u))); o.material.opacity = 0.95 * (1 - u); });
    for (let i = 0; i < 12 * s; i++) drop(p.clone(), dir.clone().multiplyScalar(22 + Math.random() * 26).add(V3(rnd(9), rnd(6) + 4, rnd(9))), (0.6 + Math.random() * 0.7) * s, 0.5, i % 2 ? P.main : P.deep);
    for (let i = 0; i < 3; i++) smoke(p.clone(), dir.clone().multiplyScalar(10 + i * 6).add(V3(rnd(2), 2, rnd(2))), 1.6 * s, P.glow, 0.5, 0.45); },
  shot(o) { const P = o.P || PV.A, s = o.size || 1, quill = o.kind === "quill", shell = o.kind === "shell"; const g = new THREE.Group();
    const body = new THREE.Mesh(SPH, gloss(P.main, P.gl)); g.add(body); const hl = spr(T_FLASH, 0xffffff, 0.9 * s, true); hl.position.set(0.3 * s, 0.35 * s, 0.2 * s); g.add(hl);
    g.add(spr(T_DROP, P.glow, (shell ? 7 : 4.2) * s, true)); let em = {}; const ph = Math.random() * 6;
    fly(Object.assign({}, o, {obj: g, tick(p, vel, dt, u, prev) { const w = 1 + 0.18 * Math.sin(clockT * 30 + ph); const L = quill ? 3.2 : shell ? 1.25 : 1.9;
      body.scale.set(0.72 * s * w, 0.72 * s / w, L * s * (1 + Math.min(0.5, vel.length() / Math.max(1e-3, dt) / 400))); if (shell) g.rotateZ(dt * 8);
      rate(em, "d", (shell ? 70 : 45) * s, dt, () => drop(prev.clone().lerp(p, Math.random()), V3(rnd(3), -2 - Math.random() * 4, rnd(3)), (0.45 + Math.random() * 0.55) * s, 0.5, Math.random() < 0.5 ? P.main : P.deep));
      if (u < 0.15) { const back = p.clone().sub(vel.clone().normalize().multiplyScalar(2.5 * s)); streak(back, p, 0.25 * s, P.main, 0.08, 0.7); }
      if (shell) rate(em, "m", 30, dt, () => smoke(p.clone(), V3(rnd(1), 1, rnd(1)), 2.2, P.glow, 0.6, 0.35)); }})); },
  impact(p, s, P) { P = P || PV.A; s = s || 1; glow(p, P.hi, 7 * s, 0.18); const b = new THREE.Mesh(SPH, gloss(P.main, P.gl, 0.95)); b.position.copy(p);
    addFx(b, 0.28, (o, u) => { o.scale.set(1.7 * s * E.out(u) + 0.01, 0.9 * s * (1 - u) + 0.01, 1.7 * s * E.out(u) + 0.01); o.material.opacity = 0.95 * (1 - u); });
    const n = Math.round(14 * s); for (let i = 0; i < n; i++) { const a = i / n * Math.PI * 2; drop(p.clone(), V3(Math.cos(a) * (10 + Math.random() * 6) * s, (16 + Math.random() * 10) * Math.sqrt(s), Math.sin(a) * (10 + Math.random() * 6) * s), (0.7 + Math.random() * 0.6) * s, 0.55, i % 2 ? P.main : P.hi); }
    for (let i = 0; i < 8 * s; i++) drop(p.clone(), V3(rnd(22 * s), 6 + Math.random() * 14, rnd(22 * s)), (0.5 + Math.random() * 0.8) * s, 0.5, P.deep);
    for (let i = 0; i < 4; i++) smoke(p.clone().add(V3(rnd(1.5 * s), 0.5, rnd(1.5 * s))), V3(rnd(2), 3 + Math.random() * 3, rnd(2)), 1.8 * s, 0xe8ffd8, 0.9, 0.5, 1.8, 2); },
  charge(pFn, dur, s, P) { P = P || PV.A; s = s || 1; const b = new THREE.Mesh(SPH, gloss(P.main, P.gl, 0.92)); const st = {};
    addFx(b, dur, (o, u, dt) => { o.position.copy(pFn()); const w = 1 + 0.15 * Math.sin(clockT * 26); o.scale.set(0.9 * s * E.out(u) * w + 0.01, 0.9 * s * E.out(u) / w + 0.01, 0.9 * s * E.out(u) + 0.01);
      rate(st, "c", 50 * s, dt, () => { const from = V3(rnd(1), rnd(1), rnd(1)).normalize().multiplyScalar(6 * s); const d = spr(T_DROP, Math.random() < 0.5 ? P.main : P.hi, 0.7 * s, false); scene.add(d);
        addFx(d, 0.22, (q, uu) => { q.position.copy(pFn()).addScaledVector(from, 1 - E.in2(uu)); q.material.opacity = uu < 0.2 ? uu * 5 : 1; }); });
      rate(st, "f", 10, dt, () => drop(pFn().clone(), V3(rnd(1), -3, rnd(1)), 0.6 * s, 0.4, P.deep)); }); },
  target(C, R, life) { const P = PV.A; const ring = new THREE.Mesh(new THREE.RingGeometry(0.9, 1, 72), normM(P.main, 0.8)); ring.rotation.x = -Math.PI / 2; ring.position.copy(C).setY(0.15);
    addFx(ring, life, (o, u) => { o.scale.setScalar(R * (1 + 0.02 * Math.sin(clockT * 9))); o.material.opacity = 0.8 * Math.min(1, u * 6); });
    const inner = new THREE.Mesh(new THREE.RingGeometry(0.9, 1, 72), normM(P.hi, 0.7)); inner.rotation.x = -Math.PI / 2; inner.position.copy(C).setY(0.16);
    addFx(inner, life, (o, u) => { o.scale.setScalar(Math.max(0.01, R * (1 - u))); o.material.opacity = 0.7 * u; });
    const st = {}; follow(() => C, life, (p, dt) => rate(st, "d", 24, dt, () => drop(C.clone().add(randIn(R * 0.8)).setY(9 + Math.random() * 6), V3(0, -20, 0), 0.8, 0.45, P.main, 30))); },
  cloud(C, R, life) { const P = PV.A; for (let i = 0; i < 46; i++) { const a = i / 46 * Math.PI * 2; drop(C.clone().add(V3(0, 1, 0)), V3(Math.cos(a) * (R * 1.2 + rnd(4)), 26 + Math.random() * 14, Math.sin(a) * (R * 1.2 + rnd(4))), 1.4 + Math.random(), 0.75, i % 2 ? P.main : P.hi); }
    for (let i = 0; i < 30; i++) drop(C.clone().add(V3(0, 1, 0)), V3(rnd(R * 1.6), 14 + Math.random() * 22, rnd(R * 1.6)), 1 + Math.random(), 0.7, P.deep);
    glow(C.clone().setY(3), P.hi, R * 1.4, 0.3); flatRing(C, R, P.main, 0.6, 0.12);
    const disc = new THREE.Mesh(new THREE.CircleGeometry(1, 56), normM(P.deep, 0)); disc.rotation.x = -Math.PI / 2; disc.position.copy(C).setY(0.1); disc.scale.setScalar(R);
    addFx(disc, life, (o, u) => { o.material.opacity = 0.3 * Math.min(1, u * 10) * Math.min(1, (1 - u) * 6); });
    for (let i = 0; i < 44; i++) { const q = C.clone().add(randIn(R)).setY(1.5 + Math.random() * 4); const sz = 7 + Math.random() * 7; const s = spr(T_SMOKE, i % 3 ? P.main : P.glow, sz, false, q); s.material.rotation = Math.random() * 6; const ph = Math.random() * 6;
      addFx(s, life, (o, u, dt) => { o.position.y += Math.sin(clockT * 1.2 + ph) * dt * 0.8; o.material.rotation += dt * 0.25; o.scale.setScalar(sz * (0.6 + 0.4 * Math.min(1, u * 8))); o.material.opacity = 0.5 * Math.min(1, u * 12) * Math.min(1, (1 - u) * 5); }); }
    const st = {}; follow(() => C, life * 0.92, (p, dt) => { rate(st, "b", 26, dt, () => bubble(C.clone().add(randIn(R * 0.95)).setY(0.6), 1.2 + Math.random() * 1.4, 0.7 + Math.random() * 0.6, P.hi));
      rate(st, "e", 6, dt, () => { const a = Math.random() * Math.PI * 2; smoke(C.clone().add(V3(Math.cos(a) * R, 1, Math.sin(a) * R)), V3(Math.cos(a) * 2, 0.6, Math.sin(a) * 2), 4, P.main, 1.4, 0.45); }); }); },
  wave(from, dir, range, half) { const P = PV.A; glow(from, P.hi, 12, 0.22); this.impact(from, 1.2);
    for (let i = 0; i < 70; i++) { const a = rad(rnd(half)); const d = V3(dir.x * Math.cos(a) - dir.z * Math.sin(a), 0, dir.x * Math.sin(a) + dir.z * Math.cos(a)); const sp = range * (1.7 + Math.random() * 0.9);
      smoke(from.clone(), d.clone().multiplyScalar(sp).add(V3(0, rnd(6) - 3, 0)), 3.6 + Math.random() * 2.5, i % 2 ? P.main : P.glow, 0.8, 0.6, 2.6); }
    for (let i = 0; i < 40; i++) { const a = rad(rnd(half)); const d = V3(dir.x * Math.cos(a) - dir.z * Math.sin(a), 0, dir.x * Math.sin(a) + dir.z * Math.cos(a)); drop(from.clone(), d.multiplyScalar(range * (1 + Math.random())).add(V3(0, 6 + rnd(5), 0)), 0.8 + Math.random() * 0.8, 0.55, i % 2 ? P.main : P.hi, 35); }
    sector(dilo.pos, dir, range, half, P.main, 0.9); },
  status(R, text, life, col) { textTag(headOf(R).add(V3(0, 7, 0)), text, col || "#c9b8ff", life); const st = {};
    follow(() => headOf(R), life, (p, dt, u) => rate(st, "d", 12, dt, () => drop(p.clone().add(V3(rnd(1.5), 0, rnd(1.5))), V3(rnd(1), -2, rnd(1)), 0.7, 0.45, 0xb8a6ff, 30))); },
  purge(pumpFn) { const P = PB.A; const p = pumpFn(); glow(p, P.hi, 14, 0.22); this.impact(p.clone().add(V3(0, 1, 0)), 1.6, P);
    for (let i = 0; i < 46; i++) { const part = dilo.parts[(Math.random() * 140) | 0]; if (!part || part.kind === "mech") continue; const q = partPoint(part); const v = q.clone().sub(dilo.pos.clone().setY(8)).normalize().multiplyScalar(16 + Math.random() * 14).add(V3(0, 6, 0)); drop(q, v, 0.9 + Math.random() * 0.6, 0.6, i % 3 ? PV.A.main : PV.A.deep); }
    flatRing(dilo.pos, 14, P.main, 0.55, 0.14); },
  shell(cFn, r, life, P) { P = P || PB.A; const m = new THREE.Mesh(SPH, gloss(P.main, P.gl, 0.16)); const rim = new THREE.Mesh(SPH, rimMat(P.glow, 2.4, 0.0, 0.9)); const D = {j: 0};
    addFx(m, life, (o, u, dt) => { D.j = Math.max(0, D.j - dt * 3); const k = Math.min(1, u * life / 0.25), w = 1 + 0.04 * Math.sin(clockT * 7) + 0.12 * D.j * Math.sin(clockT * 40); o.position.copy(cFn()); o.scale.set(r * E.back(k) * w, r * E.back(k) / w, r * E.back(k) * w);
      o.material.opacity = 0.16 * Math.min(1, (1 - u) * 8); rim.position.copy(o.position); rim.scale.copy(o.scale); rim.material.uniforms.a.value = Math.min(1, (1 - u) * 8) * (0.8 + 0.4 * D.j); });
    addFx(rim, life, () => {}); D.hit = p => { D.j = 1; glow(p, P.hi, 8, 0.2); for (let i = 0; i < 10; i++) drop(p.clone(), V3(rnd(10), 6 + Math.random() * 8, rnd(10)), 0.8, 0.5, P.main); }; return D; },
  auraTick(st, dt, k) { rate(st, "a", 34 * k, dt, () => { const part = dilo.parts[(Math.random() * 140) | 0]; if (part && part.kind !== "mech") { const q = partPoint(part); if (q.y > 3) drop(q, V3(rnd(1), -2, rnd(1)), 0.9 + Math.random() * 0.6, 0.55, Math.random() < 0.5 ? PV.A.main : PV.A.hi, 30); } });
    rate(st, "m", 8 * k, dt, () => smoke(mouthPoint(), V3(rnd(1), 3, rnd(1)), 1.6, PV.A.glow, 0.8, 0.45, 2, 1)); },
  vent(pFn, life, s) { const st = {}; follow(pFn, life, (p, dt, u) => { rate(st, "d", 16 * (1 - u), dt, () => drop(p.clone(), V3(rnd(1.5), -1, rnd(1.5)), 0.7 * (s || 1), 0.45, PV.A.main));
    rate(st, "s", 10 * (1 - u), dt, () => smoke(p.clone(), V3(rnd(1), 3, rnd(1)), 1.2 * (s || 1), 0xf0fff0, 0.8, 0.4, 2, 2)); }); },
  flame(pFn, dirFn, life, s, P) { P = P || PV.A; const st = {}; s = s || 1; follow(pFn, life, (p, dt, u) => { const d = dirFn(); const k = u > 0.75 ? (1 - u) / 0.25 : 1;
    rate(st, "f", 150 * k, dt, () => { const q = p.clone().addScaledVector(d, Math.random() * 1.5); const v = d.clone().multiplyScalar(26 + Math.random() * 16).add(V3(rnd(4), rnd(4), rnd(4))); const sz = (2.4 + Math.random() * 1.6) * s;
      const f = spr(T_FLASH, Math.random() < 0.35 ? P.hi : P.main, sz, true, q); addFx(f, 0.28, (o, uu, ddt) => { o.position.addScaledVector(v, ddt); o.scale.setScalar(sz * (1 - uu * 0.7)); o.material.opacity = 1 - uu; }); });
    rate(st, "d", 40 * k, dt, () => drop(p.clone(), d.clone().multiplyScalar(14).add(V3(rnd(5), 2 + rnd(3), rnd(5))), 0.8 * s, 0.5, P.main));
    if (Math.random() < dt * 30) glow(p, P.hi, 5 * s * k, 0.06); }); },
  trail(from, to, life) { const P = PV.A; const st = {}; const d = to.clone().sub(from);
    follow(() => from, life, (p, dt, u) => { const k = u > 0.8 ? (1 - u) / 0.2 : 1; rate(st, "m", 26 * k, dt, () => smoke(from.clone().addScaledVector(d, Math.random()).add(V3(rnd(2.5), 1.2, rnd(2.5))), V3(rnd(1), 0.8, rnd(1)), 3.2, Math.random() < 0.5 ? P.main : P.glow, 1.3, 0.42, 1.2));
      rate(st, "b", 14 * k, dt, () => bubble(from.clone().addScaledVector(d, Math.random()).add(V3(rnd(2), 0.5, rnd(2))), 1 + Math.random(), 0.6, P.hi)); }); },
  ring(center, R, P) { P = P || PV.A; flatRing(center, R, P.main, 0.5, 0.12); const n = 22; for (let i = 0; i < n; i++) { const a = i / n * Math.PI * 2; drop(center.clone().add(V3(0, 2, 0)), V3(Math.cos(a) * R * 2, 10 + Math.random() * 6, Math.sin(a) * R * 2), 1, 0.5, i % 2 ? P.main : P.hi); } },
  nova(p, s) { this.impact(p, 2.2 * (s || 1)); this.ring(dilo.pos, 18); glow(p, PV.A.hi, 22, 0.3); },
  barbs(pts, k, dt, st) { rate(st, "bd", 30 * k, dt, () => { const q = pts[(Math.random() * pts.length) | 0]; drop(q.clone(), V3(rnd(1), -1, rnd(1)), 0.6, 0.4, PV.A.main); }); },
};

// =====================================================================================================================================
// B · REACTOR GLOW
// =====================================================================================================================================
const KB = {
  muzzle(p, dir, s, P) { P = P || PV.B; s = s || 1; star(p, P.hi, 9 * s, 0.12); glow(p, P.main, 6 * s, 0.16); axisRing(p, dir, 3.2 * s, P.acc || P.hi, 0.22, 0.07);
    streak(p, p.clone().addScaledVector(dir, 5 * s), 0.35 * s, P.hi, 0.08); sparkBurst(p, dir, 6 * s, P.main, 40, 0.35, 0.25, 0.9); },
  shot(o) { const P = o.P || PV.B, s = o.size || 1, shell = o.kind === "shell", quill = o.kind === "quill"; const g = new THREE.Group();
    const core = new THREE.Mesh(SPH, new THREE.MeshBasicMaterial({color: P.hi})); core.scale.set(0.35 * s, 0.35 * s, (quill ? 2.6 : shell ? 0.9 : 1.6) * s); g.add(core);
    if (shell) { const sh = new THREE.Mesh(new THREE.IcosahedronGeometry(1, 0), new THREE.MeshBasicMaterial({color: P.main, wireframe: true, transparent: true, opacity: 0.9})); sh.scale.setScalar(1.3 * s); g.add(sh); g.userData.sh = sh; }
    g.add(spr(T_FLASH, P.main, (shell ? 9 : 5) * s, true)); g.add(spr(T_STAR, P.hi, (shell ? 6 : 3) * s, true)); const em = {};
    fly(Object.assign({}, o, {obj: g, tick(p, vel, dt, u, prev) { if (vel.lengthSq() > 1e-6) streak(prev, p, (quill ? 0.22 : 0.4) * s, P.main, quill ? 0.1 : 0.16, 0.95);
      if (vel.lengthSq() > 1e-6) streak(prev, p, (quill ? 0.08 : 0.14) * s, P.hi, 0.07);
      if (g.userData.sh) { g.userData.sh.rotation.x += dt * 9; g.userData.sh.rotation.y += dt * 7; }
      rate(em, "r", shell ? 16 : 0, dt, () => axisRing(p.clone(), vel, 2.2 * s, P.acc || P.hi, 0.25, 0.05));
      rate(em, "s", (shell ? 40 : 18) * s, dt, () => spark(p.clone(), V3(rnd(6), rnd(6), rnd(6)), P.main, 0.3, 0.8 * s, 0)); }})); },
  impact(p, s, P) { P = P || PV.B; s = s || 1; star(p, P.hi, 14 * s, 0.16); glow(p, P.main, 10 * s, 0.22); shockSphere(p, 4.5 * s, P.main, 0.3, 2.0, 1.4);
    const hx = decal(p.clone().setY(0), 5 * s, T_HEX, P.main, 0.5, (o, u) => { o.scale.setScalar(Math.max(0.01, 5 * s * E.out(Math.min(1, u * 2.5)))); o.material.opacity = 1 - u; o.rotation.z = u; }, false);
    flatRing(p.clone().setY(0), 6 * s, P.acc || P.hi, 0.35, 0.1, true); for (let i = 0; i < 3; i++) bolt(p, p.clone().add(V3(rnd(4 * s), rnd(3 * s) + 1, rnd(4 * s))), P.hi, 0.12, 0.8 * s, 0.1 * s);
    sparkBurst(p, UPV, 12 * s, P.main, 30, 0.9, 0.4, 1); },
  charge(pFn, dur, s, P) { P = P || PV.B; s = s || 1; const st = {}; const ring = new THREE.Mesh(new THREE.TorusGeometry(1, 0.05, 6, 40), addM(P.acc || P.hi, 1)); const g = spr(T_FLASH, P.main, 1, true);
    addFx(g, dur, (o, u) => { o.position.copy(pFn()); o.scale.setScalar((1 + 5 * E.in2(u)) * s); o.material.opacity = 0.6 + 0.4 * Math.sin(clockT * 40); });
    addFx(ring, dur, (o, u) => { o.position.copy(pFn()); o.scale.setScalar(Math.max(0.01, 4 * s * (1 - E.io(u)))); o.rotation.x = clockT * 5; o.rotation.y = clockT * 3; o.material.opacity = Math.min(1, u * 5); });
    addFx(new THREE.Object3D(), dur, (o, u, dt) => rate(st, "p", 70 * s, dt, () => { const a = Math.random() * Math.PI * 2, b = rnd(1.2), r0 = 7 * s; const m = spr(T_SPARK, Math.random() < 0.5 ? P.main : P.hi, 0.9 * s, true); scene.add(m);
      addFx(m, 0.3, (q, uu) => { const r = r0 * (1 - E.in2(uu)), aa = a + uu * 3; q.position.copy(pFn()).add(V3(Math.cos(aa) * Math.cos(b) * r, Math.sin(b) * r, Math.sin(aa) * Math.cos(b) * r)); q.material.opacity = uu < 0.2 ? uu * 5 : 1; }); })); },
  target(C, R, life) { const P = PV.B; decal(C, R, T_RETI, P.main, life, (o, u) => { o.rotation.z = clockT * 0.8; o.scale.setScalar(R * (1.15 - 0.15 * E.out(Math.min(1, u * 4)))); o.material.opacity = Math.min(1, u * 8) * (0.75 + 0.25 * Math.sin(clockT * 20)); }, false);
    decal(C, R * 0.9, T_HEX, P.main, life, (o, u) => { o.material.opacity = 0.45 * Math.min(1, u * 6); }, false);
    const beam = cylBetween(C.clone().setY(0), C.clone().setY(40), 0.5, addM(P.main, 0.5)); addFx(beam, life, (o, u) => { o.material.opacity = 0.5 * Math.min(1, u * 8) * (0.7 + 0.3 * Math.sin(clockT * 30)); }); },
  cloud(C, R, life) { const P = PV.B; star(C.clone().setY(3), P.hi, R * 2.6, 0.22); glow(C.clone().setY(3), P.main, R * 2, 0.35); shockSphere(C.clone().setY(0), R * 1.15, P.main, 0.45, 1.8, 1.3); flatRing(C, R * 1.3, P.hi, 0.45, 0.06, true);
    sparkBurst(C.clone().setY(2), UPV, 40, P.main, 50, 0.8, 0.7, 1.4, 30);
    decal(C, R, T_HEX, P.main, life, (o, u) => { o.material.opacity = 0.85 * Math.min(1, u * 10) * Math.min(1, (1 - u) * 5) * (0.75 + 0.25 * Math.sin(clockT * 3)); }, false);
    const wall = new THREE.Mesh(new THREE.CylinderGeometry(1, 1, 1, 64, 1, true), rimMat(P.main, 0.6, 0.0, 0.9)); wall.position.copy(C).setY(3); addFx(wall, life, (o, u) => { o.scale.set(R, 6 * Math.min(1, u * 8), R); o.material.uniforms.a.value = Math.min(1, u * 10) * Math.min(1, (1 - u) * 5); });
    const edge = new THREE.Mesh(new THREE.RingGeometry(0.97, 1, 96), addM(P.hi, 1)); edge.rotation.x = -Math.PI / 2; edge.position.copy(C).setY(0.17); addFx(edge, life, (o, u) => { o.scale.setScalar(R); o.material.opacity = Math.min(1, (1 - u) * 5) * (0.7 + 0.3 * Math.sin(clockT * 8)); });
    const st = {}; follow(() => C, life * 0.95, (p, dt) => { rate(st, "m", 40, dt, () => { const q = C.clone().add(randIn(R)).setY(0.4); spark(q, V3(0, 6 + Math.random() * 8, 0), Math.random() < 0.6 ? P.main : P.acc, 0.9, 1.1, 0); });
      rate(st, "p", 1.6, dt, () => flatRing(C, R, P.main, 0.9, 0.05, true)); }); },
  wave(from, dir, range, half) { const P = PV.B; star(from, P.hi, 16, 0.16); glow(from, P.main, 12, 0.2);
    for (let i = 0; i < 6; i++) later(i * 0.05, () => { const g = arcFront(from, dir, 1, half, i % 2 ? P.acc : P.main, 0.5, from.y - 2, 0.03); addFx(g, 0.55, (o, u) => { o.scale.setScalar(Math.max(0.01, range * E.out(u))); o.position.y = from.y - 2 - u * 4; o.children[0].material.opacity = 1 - u; }); });
    const sh = new THREE.Mesh(new THREE.SphereGeometry(1, 32, 16, 0, Math.PI * 2, 0, Math.PI / 2), rimMat(P.main, 1.6, 0.04, 1.0)); sh.position.copy(from); sh.quaternion.setFromUnitVectors(UPV, dir.clone().normalize());
    addFx(sh, 0.45, (o, u) => { o.scale.set(range * 0.6 * E.out(u), range * E.out(u), range * 0.3 * E.out(u)); o.material.uniforms.a.value = 1 - u; });
    sector(dilo.pos, dir, range, half, P.main, 0.6, true); for (let i = 0; i < 26; i++) { const a = rad(rnd(half)); const d = V3(dir.x * Math.cos(a) - dir.z * Math.sin(a), 0, dir.x * Math.sin(a) + dir.z * Math.cos(a)); spark(from.clone(), d.multiplyScalar(range * 2.2 * (0.6 + Math.random() * 0.5)).add(V3(0, rnd(4), 0)), P.hi, 0.45, 1.2, 0, 0.3); } },
  status(R, text, life, col) { textTag(headOf(R).add(V3(0, 7, 0)), text, col || "#c9b8ff", life); const ring = new THREE.Mesh(new THREE.TorusGeometry(3.2, 0.12, 6, 40), addM(0xb8a6ff, 0.9)); ring.rotation.x = Math.PI / 2;
    const x1 = cylBetween(V3(-2.2, 0, -2.2), V3(2.2, 0, 2.2), 0.16, addM(0xff6b8a, 0.9)), x2 = cylBetween(V3(-2.2, 0, 2.2), V3(2.2, 0, -2.2), 0.16, x1.material); const g = new THREE.Group(); g.add(ring, x1, x2);
    addFx(g, life, (o, u) => { o.position.copy(headOf(R)).add(V3(0, 3.5, 0)); o.rotation.y = clockT * 2; const k = u > 0.9 ? (1 - u) / 0.1 : 1; ring.material.opacity = 0.9 * k; x1.material.opacity = 0.9 * k * (0.6 + 0.4 * Math.sin(clockT * 10)); }); },
  purge(pumpFn) { const P = PB.B; const p = pumpFn(); star(p, P.hi, 22, 0.2); glow(p, P.main, 16, 0.25); shockSphere(dilo.pos.clone().setY(8), 14, P.main, 0.45, 1.8, 1.4);
    for (let i = 0; i < 4; i++) later(i * 0.06, () => { const r = new THREE.Mesh(new THREE.TorusGeometry(1, 0.06, 6, 56), addM(i % 2 ? P.acc : P.main, 1)); r.rotation.x = Math.PI / 2;
      addFx(r, 0.45, (o, u) => { o.position.copy(dilo.pos).setY(20 - 19 * E.io(u)); o.scale.setScalar(9 + 3 * Math.sin(u * Math.PI)); o.material.opacity = 1 - u * 0.6; }); });
    for (let i = 0; i < 40; i++) { const part = dilo.parts[(Math.random() * 140) | 0]; if (!part || part.kind === "mech") continue; const q = partPoint(part); spark(q, q.clone().sub(dilo.pos.clone().setY(8)).normalize().multiplyScalar(20 + Math.random() * 12), Math.random() < 0.5 ? PV.B.main : 0xffffff, 0.5, 1.2, -10); }
    flatRing(dilo.pos, 16, P.hi, 0.5, 0.06, true); decal(dilo.pos, 14, T_HEX, P.main, 0.6, null, false); },
  shell(cFn, r, life, P) { P = P || PB.B; const m = new THREE.Mesh(new THREE.IcosahedronGeometry(1, 2), new THREE.MeshBasicMaterial({color: P.main, wireframe: true, transparent: true, opacity: 0.35, depthWrite: false}));
    const rim = new THREE.Mesh(SPH, rimMat(P.main, 2.0, 0.02, 1.0)); const D = {j: 0};
    addFx(m, life, (o, u, dt) => { D.j = Math.max(0, D.j - dt * 3); const k = E.out(Math.min(1, u * life / 0.2)); o.position.copy(cFn()); o.scale.setScalar(r * k); o.rotation.y = clockT * 0.5;
      const f = Math.min(1, (1 - u) * 8) * (u > 0.85 ? (Math.sin(clockT * 40) > 0 ? 1 : 0.3) : 1); o.material.opacity = (0.3 + 0.5 * D.j) * f; rim.position.copy(o.position); rim.scale.copy(o.scale); rim.material.uniforms.a.value = f * (0.8 + 0.6 * D.j); });
    addFx(rim, life, () => {}); D.hit = p => { D.j = 1; star(p, P.hi, 12, 0.16); axisRing(p, p.clone().sub(cFn()), 5, P.hi, 0.35, 0.08); sparkBurst(p, p.clone().sub(cFn()), 10, P.main, 26, 0.6); }; return D; },
  auraTick(st, dt, k) { rate(st, "o", 2.2 * k, dt, () => { const r = new THREE.Mesh(new THREE.TorusGeometry(1, 0.05, 6, 48), addM(Math.random() < 0.5 ? PV.B.main : PV.B.acc, 1)); r.rotation.x = Math.PI / 2;
      addFx(r, 0.9, (o, u) => { o.position.copy(dilo.pos).setY(1 + u * 18); o.scale.setScalar(8 - 3 * u); o.material.opacity = 1 - u; }); });
    rate(st, "b", 7 * k, dt, () => { const a = dilo.parts[(Math.random() * 140) | 0], b = dilo.parts[(Math.random() * 140) | 0]; if (a && b && a.kind !== "mech" && b.kind !== "mech") bolt(partPoint(a), partPoint(b), PV.B.hi, 0.08, 1.2, 0.08); });
    rate(st, "s", 30 * k, dt, () => { const part = dilo.parts[(Math.random() * 140) | 0]; if (part && part.kind !== "mech") spark(partPoint(part), V3(rnd(2), 5, rnd(2)), PV.B.main, 0.4, 0.9, 0); }); },
  vent(pFn, life, s) { const st = {}; follow(pFn, life, (p, dt, u) => { rate(st, "h", 14 * (1 - u), dt, () => { const h = spr(T_MIST, 0xffffff, 1.4 * (s || 1), false, p.clone()); const ph = Math.random() * 6; addFx(h, 0.7, (o, uu, ddt) => { o.position.y += 5 * ddt; o.position.x += Math.sin(clockT * 9 + ph) * ddt; o.scale.setScalar(1.4 * (s || 1) * (1 + uu * 2)); o.material.opacity = 0.25 * (1 - uu); }); });
    rate(st, "m", 20 * (1 - u), dt, () => spark(p.clone(), V3(rnd(2), 4 + Math.random() * 3, rnd(2)), PV.B.main, 0.5, 0.7, 0)); if (u < 0.3 && Math.random() < dt * 20) glow(p, PV.B.main, 3 * (s || 1) * (1 - u), 0.08); }); },
  flame(pFn, dirFn, life, s, P) { P = P || PV.B; s = s || 1; const st = {}; const outer = new THREE.Mesh(CONE, addM(P.main, 0.6)), inner = new THREE.Mesh(CONE, addM(P.hi, 0.9)); const dia = [0, 1, 2].map(() => spr(T_FLASH, P.hi, 2.2 * s, true));
    const g = new THREE.Group(); g.add(outer, inner, ...dia);
    addFx(g, life, (o, u, dt) => { const d = dirFn(), p = pFn(); const k = u > 0.8 ? (1 - u) / 0.2 : Math.min(1, u * life / 0.05); o.position.copy(p); o.quaternion.setFromUnitVectors(V3(0, 0, 1), d.clone().normalize()); const fl = 1 + 0.15 * Math.sin(clockT * 70);
      outer.scale.set(1.8 * s * k, 1.8 * s * k, 11 * s * k * fl); inner.scale.set(0.8 * s * k, 0.8 * s * k, 6 * s * k / fl); outer.material.opacity = 0.6 * k; inner.material.opacity = 0.9 * k; dia.forEach((q, i) => { q.position.set(0, 0, (2 + i * 2.6) * s * k); q.material.opacity = (0.9 - i * 0.25) * k * (0.6 + 0.4 * Math.sin(clockT * 60 + i)); });
      rate(st, "s", 60 * k, dt, () => spark(p.clone(), d.clone().multiplyScalar(40 + Math.random() * 30).add(V3(rnd(6), rnd(6), rnd(6))), Math.random() < 0.5 ? P.main : P.acc, 0.3, 1, 0)); }); },
  trail(from, to, life) { const P = PV.B; const d = to.clone().sub(from), L = d.length(); const m = new THREE.Mesh(new THREE.PlaneGeometry(4, L), new THREE.MeshBasicMaterial({map: T_CHEV, color: P.main, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide}));
    m.material.map = T_CHEV.clone(); m.material.map.needsUpdate = true; m.material.map.repeat.set(1, L / 6); m.rotation.x = -Math.PI / 2; m.rotation.z = Math.atan2(d.x, d.z); m.position.copy(from).addScaledVector(d, 0.5).setY(0.15);
    addFx(m, life, (o, u) => { o.material.map.offset.y = -clockT * 1.5; o.material.opacity = Math.min(1, u * 20) * Math.min(1, (1 - u) * 5) * 0.9; });
    const st = {}; follow(() => from, life, (p, dt, u) => rate(st, "s", 30 * (1 - u), dt, () => spark(from.clone().addScaledVector(d, Math.random()).add(V3(rnd(1.8), 0.3, rnd(1.8))), V3(0, 5 + Math.random() * 4, 0), Math.random() < 0.6 ? P.main : P.acc, 0.7, 1, 0))); },
  ring(center, R, P) { P = P || PV.B; flatRing(center, R, P.hi, 0.4, 0.05, true); flatRing(center, R * 0.8, P.main, 0.5, 0.1, true); decal(center, R, T_HEX, P.main, 0.5, (o, u) => { o.scale.setScalar(Math.max(0.01, R * E.out(u))); o.material.opacity = 1 - u; }, false); },
  nova(p, s) { this.impact(p, 2 * (s || 1)); this.ring(dilo.pos, 20); shockSphere(dilo.pos.clone().setY(6), 16, PV.B.main, 0.5, 1.6, 1.5); },
  barbs(pts, k, dt, st) { rate(st, "bb", 20 * k, dt, () => { const a = pts[(Math.random() * pts.length) | 0], b = pts[(Math.random() * pts.length) | 0]; if (a !== b && a.distanceTo(b) < 6) bolt(a, b, PV.B.hi, 0.07, 0.4, 0.07); });
    rate(st, "bg", 40 * k, dt, () => glow(pts[(Math.random() * pts.length) | 0], PV.B.main, 2.4, 0.08)); },
};

// =====================================================================================================================================
// C · CHEM WARFARE
// =====================================================================================================================================
const KC = {
  muzzle(p, dir, s, P) { P = P || PV.C; s = s || 1; star(p, P.hi, 8 * s, 0.09); glow(p, P.haz, 5 * s, 0.12); for (let i = 0; i < 4; i++) smoke(p.clone(), dir.clone().multiplyScalar(14 + i * 5).add(V3(rnd(3), 2 + rnd(2), rnd(3))), 2 * s, 0xb9bcae, 0.9, 0.6, 2, 1.5);
    sparkBurst(p, dir, 5 * s, P.fire, 36, 0.4, 0.25, 0.8); casing(p.clone(), V3(dir.z, 0, -dir.x).normalize()); },
  shot(o) { const P = o.P || PV.C, s = o.size || 1, shell = o.kind === "shell", quill = o.kind === "quill"; const g = new THREE.Group();
    if (shell) { const c = new THREE.Mesh(new THREE.CylinderGeometry(0.9, 0.9, 2.6, 12), new THREE.MeshLambertMaterial({color: 0x4a5040})); c.rotation.x = Math.PI / 2; g.add(c);
      const band = new THREE.Mesh(new THREE.CylinderGeometry(0.95, 0.95, 0.7, 12), new THREE.MeshBasicMaterial({map: T_STRIPE})); band.rotation.x = Math.PI / 2; g.add(band);
      const tip = new THREE.Mesh(new THREE.SphereGeometry(0.9, 12, 8), new THREE.MeshLambertMaterial({color: P.main, emissive: P.deep})); tip.position.z = 1.3; g.add(tip); g.scale.setScalar(s * 0.9); }
    else { const b = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.2, quill ? 3.2 : 2.2, 6), new THREE.MeshLambertMaterial({color: 0x9aa1ac})); b.rotation.x = Math.PI / 2; g.add(b);
      const t = new THREE.Mesh(new THREE.ConeGeometry(0.28, 0.9, 6), new THREE.MeshLambertMaterial({color: P.main, emissive: P.deep})); t.rotation.x = Math.PI / 2; t.position.z = (quill ? 1.9 : 1.4); g.add(t); g.scale.setScalar(s); }
    g.add(spr(T_FLASH, P.haz, (shell ? 4 : 2.2) * s, true)); const em = {};
    fly(Object.assign({}, o, {obj: g, tick(p, vel, dt, u, prev) { if (shell) g.rotateZ(dt * 10); if (vel.lengthSq() > 1e-6) streak(prev, p, 0.1 * s, P.haz, 0.06, 0.8);
      rate(em, "s", (shell ? 70 : 40) * s, dt, () => smoke(prev.clone().lerp(p, Math.random()), V3(rnd(1), 0.5, rnd(1)), (shell ? 2.4 : 1.2) * s, shell ? 0xb9bcae : 0xd0d4c4, shell ? 1.1 : 0.6, 0.5, 1.4));
      if (shell) rate(em, "c", 20, dt, () => smoke(p.clone(), V3(rnd(1), 0, rnd(1)), 1.6, P.main, 0.8, 0.45)); }})); },
  impact(p, s, P) { P = P || PV.C; s = s || 1; star(p, P.hi, 11 * s, 0.1); glow(p, P.haz, 8 * s, 0.16);
    for (let i = 0; i < 7; i++) smoke(p.clone(), V3(rnd(14 * s), 4 + Math.random() * 10 * s, rnd(14 * s)), (2.4 + Math.random()) * s, i % 2 ? P.main : P.smoke, 1.1, 0.7, 1.8, 1);
    sparkBurst(p, UPV, 9 * s, P.fire, 30, 0.9, 0.35, 0.9, 60); debris(p.clone(), Math.round(4 * s), 0x3b4049, 14 * Math.sqrt(s)); },
  charge(pFn, dur, s, P) { P = P || PV.C; s = s || 1; const st = {}; const l = spr(T_FLASH, 0xff3b30, 2.2 * s, true);
    addFx(l, dur, (o, u, dt) => { o.position.copy(pFn()).add(V3(0, 1.2 * s, 0)); o.material.opacity = (Math.sin(clockT * 30) > 0 ? 1 : 0.15); o.material.color.setHex(Math.sin(clockT * 15) > 0 ? 0xff3b30 : P.haz);
      rate(st, "v", 40 * s, dt, () => { const a = Math.random() * Math.PI * 2; smoke(pFn().clone(), V3(Math.cos(a) * 10, 4 + Math.random() * 4, Math.sin(a) * 10), 0.9 * s, 0xf4f4ec, 0.45, 0.55, 2.2); });
      if (Math.random() < dt * 12) sparkBurst(pFn(), UPV, 2, P.fire, 16, 0.8, 0.25, 0.6); }); },
  target(C, R, life) { const P = PV.C; decal(C, R, T_HAZ, 0xffffff, life, (o, u) => { o.rotation.z = -clockT * 0.6; o.material.opacity = Math.min(1, u * 8) * 0.95; });
    const dot = spr(T_FLASH, 0xff3b30, 4, true, C.clone().setY(0.6)); addFx(dot, life, (o, u) => { o.material.opacity = Math.sin(clockT * 25) > 0 ? 1 : 0.3; });
    const laser = cylBetween(partPoint(mk("mortar.C")[0]), C.clone().setY(0.6), 0.12, addM(0xff3b30, 0.7)); addFx(laser, life * 0.6, (o, u) => { o.material.opacity = 0.7 * (1 - u); }); },
  cloud(C, R, life) { const P = PV.C; star(C.clone().setY(3), P.hi, R * 2.2, 0.14); glow(C.clone().setY(3), P.haz, R * 1.6, 0.25); debris(C.clone().setY(1), 14, 0x4a5040, 26);
    sparkBurst(C.clone().setY(2), UPV, 26, P.fire, 46, 0.9, 0.5, 1.2, 60); for (let i = 0; i < 16; i++) { const a = i / 16 * Math.PI * 2; smoke(C.clone().setY(2), V3(Math.cos(a) * R * 3, 6 + Math.random() * 6, Math.sin(a) * R * 3), 6, i % 2 ? P.main : P.smoke, 1.2, 0.75, 1.4); }
    decal(C, R * 1.06, T_HAZ, 0xffffff, life, (o, u) => { o.material.opacity = Math.min(1, u * 10) * Math.min(1, (1 - u) * 5) * 0.9; o.rotation.z = clockT * 0.15; });
    for (let i = 0; i < 52; i++) { const q = C.clone().add(randIn(R * 0.95)).setY(2 + Math.random() * 6); const sz = 9 + Math.random() * 8; const s = spr(T_SMOKE, i % 3 === 0 ? P.smoke : i % 3 === 1 ? P.main : P.glow, sz, false, q); s.material.rotation = Math.random() * 6; const ph = Math.random() * 6, rs = rnd(0.5);
      addFx(s, life, (o, u, dt) => { o.position.x += Math.sin(clockT * 0.7 + ph) * dt * 1.2; o.position.y += dt * 0.4; o.material.rotation += rs * dt; o.scale.setScalar(sz * (0.5 + 0.5 * Math.min(1, u * 5))); o.material.opacity = 0.62 * Math.min(1, u * 8) * Math.min(1, (1 - u) * 4); }); }
    const st = {}; follow(() => C, life * 0.9, (p, dt) => rate(st, "k", 4, dt, () => sparkBurst(C.clone().add(randIn(R * 0.8)).setY(2), UPV, 3, P.main, 12, 1, 0.4, 0.8, 0))); },
  wave(from, dir, range, half) { const P = PV.C; star(from, P.hi, 12, 0.1); shake = Math.max(shake, 1.2);
    for (let i = 0; i < 44; i++) { const a = rad(rnd(half)); const d = V3(dir.x * Math.cos(a) - dir.z * Math.sin(a), 0, dir.x * Math.sin(a) + dir.z * Math.cos(a)); const r0 = 2 + Math.random() * 6;
      smoke(dilo.pos.clone().addScaledVector(d, r0).setY(0.8), d.clone().multiplyScalar(range * (1.6 + Math.random())).setY(1 + Math.random() * 2), 3 + Math.random() * 2.5, 0xc2ad7a, 1.0, 0.75, 2.2); }
    for (let i = 0; i < 4; i++) later(i * 0.06, () => { const g = arcFront(dilo.pos, dir, 1, half, 0xf8f0d8, 0.45, 0.4, 0.05); addFx(g, 0.5, (o, u) => { o.scale.setScalar(Math.max(0.01, range * E.out(u))); o.children[0].material.opacity = 0.8 * (1 - u); }); });
    debris(from.clone().setY(1), 8, 0x8d8f99, 16); for (let i = 0; i < 12; i++) { const a = rad(rnd(half)); const d = V3(dir.x * Math.cos(a) - dir.z * Math.sin(a), 0, dir.x * Math.sin(a) + dir.z * Math.cos(a)); smoke(from.clone(), d.multiplyScalar(range * 1.8), 2.2, 0xe8e2cc, 0.5, 0.5, 2); } },
  status(R, text, life, col) { textTag(headOf(R).add(V3(0, 7, 0)), text, col || "#c9b8ff", life); const st = {};
    follow(() => headOf(R), life, (p, dt) => { rate(st, "s", 10, dt, () => sparkBurst(p.clone().add(V3(rnd(1.5), 1, rnd(1.5))), UPV, 1, 0xd8d0ff, 10, 1, 0.25, 0.6, 0)); rate(st, "m", 4, dt, () => smoke(p.clone(), V3(0, 2, 0), 1.4, 0x8a80a8, 0.8, 0.4)); }); },
  purge(pumpFn) { const P = PB.C; const p = pumpFn(); star(p, P.hi, 16, 0.12); for (let i = 0; i < 22; i++) { const a = i / 22 * Math.PI * 2; smoke(dilo.pos.clone().setY(6), V3(Math.cos(a) * 30, 6 + Math.random() * 8, Math.sin(a) * 30), 4, i % 2 ? P.main : 0xf4f8fa, 0.9, 0.7, 1.8); }
    for (let i = 0; i < 6; i++) smoke(p.clone(), V3(rnd(3), 26 + Math.random() * 8, rnd(3)), 2.4, 0xffffff, 0.7, 0.8, 2.2);
    for (let i = 0; i < 18; i++) { const part = dilo.parts[(Math.random() * 140) | 0]; if (!part || part.kind === "mech") continue; smoke(partPoint(part), V3(rnd(6), 3, rnd(6)), 2, PV.C.main, 0.8, 0.6); }
    decal(dilo.pos, 13, T_HAZ, 0x9fe6ff, 0.8, (o, u) => { o.scale.setScalar(Math.max(0.01, 13 * E.out(Math.min(1, u * 3)))); o.material.opacity = 1 - u; }); },
  shell(cFn, r, life, P) { P = P || PB.C; const st = {}; const D = {j: 0}; const base = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), new THREE.MeshBasicMaterial({map: T_HAZ, color: 0x9fe6ff, transparent: true, depthWrite: false})); base.rotation.x = -Math.PI / 2;
    addFx(base, life, (o, u) => { o.position.copy(dilo.pos).setY(0.15); o.scale.setScalar(r * 0.9); o.rotation.z = clockT * 0.4; o.material.opacity = 0.8 * Math.min(1, u * 10) * Math.min(1, (1 - u) * 6); });
    follow(cFn, life, (p, dt, u) => { rate(st, "m", 36 * (1 - u * 0.5), dt, () => { const a = Math.random() * Math.PI * 2, y = Math.random() * 14; smoke(dilo.pos.clone().add(V3(Math.cos(a) * r * 0.85, y, Math.sin(a) * r * 0.85)), V3(-Math.sin(a) * 6, 1, Math.cos(a) * 6), 3.2, Math.random() < 0.5 ? P.main : 0xffffff, 0.9, 0.45, 0.8); }); });
    D.hit = p => { star(p, P.hi, 10, 0.12); for (let i = 0; i < 6; i++) smoke(p.clone(), V3(rnd(10), rnd(6), rnd(10)), 2.4, 0xffffff, 0.6, 0.7); sparkBurst(p, UPV, 8, 0xffffff, 20, 1, 0.3, 0.8); }; return D; },
  auraTick(st, dt, k) { rate(st, "x", 26 * k, dt, () => { const f = mk("over.A")[0]; const p = partPoint(f).add(V3(rnd(1.5), 3 + Math.random() * 2, 2 + rnd(2))); smoke(p, V3(rnd(1), 5 + Math.random() * 3, 1), 1.8, 0xb9bcae, 1.0, 0.55, 2, 1); });
    rate(st, "h", 4 * k, dt, () => { const l = spr(T_FLASH, Math.random() < 0.5 ? 0xff3b30 : PV.C.haz, 3, true, partPoint(mk("over.A")[0]).add(V3(0, 1, 0))); addFx(l, 0.12, (o, u) => { o.material.opacity = 1 - u; }); });
    rate(st, "s", 14 * k, dt, () => { const part = dilo.parts[(Math.random() * 140) | 0]; if (part && part.kind !== "mech") sparkBurst(partPoint(part), UPV, 1, PV.C.fire, 10, 1, 0.3, 0.6); }); },
  vent(pFn, life, s) { const st = {}; follow(pFn, life, (p, dt, u) => rate(st, "s", 26 * (1 - u), dt, () => smoke(p.clone(), V3(rnd(2), 5 + Math.random() * 4, rnd(2)), 1.4 * (s || 1), u < 0.3 ? 0x8f8f86 : 0xe8e8e0, 1.1, 0.55, 2.2, 2))); },
  flame(pFn, dirFn, life, s, P) { P = P || PV.C; s = s || 1; const st = {}; const fire = new THREE.Mesh(CONE, addM(P.fire, 0.75)), core = new THREE.Mesh(CONE, addM(0xfff2c8, 0.9)); const g = new THREE.Group(); g.add(fire, core);
    addFx(g, life, (o, u, dt) => { const d = dirFn(), p = pFn(); const k = u > 0.8 ? (1 - u) / 0.2 : 1; o.position.copy(p); o.quaternion.setFromUnitVectors(V3(0, 0, 1), d.clone().normalize()); const fl = 1 + 0.2 * Math.sin(clockT * 80);
      fire.scale.set(1.7 * s * k, 1.7 * s * k, 8 * s * k * fl); core.scale.set(0.7 * s * k, 0.7 * s * k, 3.5 * s * k); fire.material.opacity = 0.75 * k; core.material.opacity = 0.9 * k;
      rate(st, "f", 110 * k, dt, () => { const sz = (2.2 + Math.random() * 1.8) * s; const f = spr(T_FLASH, Math.random() < 0.4 ? 0xffd27a : P.fire, sz, true, p.clone().addScaledVector(d, 2 * s)); const v = d.clone().multiplyScalar(24 + Math.random() * 14).add(V3(rnd(3), rnd(3), rnd(3)));
        addFx(f, 0.22, (q, uu, ddt) => { q.position.addScaledVector(v, ddt); q.scale.setScalar(sz * (1 - uu * 0.6)); q.material.opacity = 1 - uu; }); });
      rate(st, "s", 70 * k, dt, () => smoke(p.clone().addScaledVector(d, 4 * s), d.clone().multiplyScalar(8).add(V3(rnd(2), 2, rnd(2))), 2.6 * s, 0x7c7c74, 1.5, 0.6, 2.4, 1)); }); },
  trail(from, to, life) { const P = PV.C; const st = {}; const d = to.clone().sub(from);
    follow(() => from, life, (p, dt, u) => { const k = u > 0.8 ? (1 - u) / 0.2 : 1; rate(st, "m", 30 * k, dt, () => smoke(from.clone().addScaledVector(d, Math.random()).add(V3(rnd(2.5), 1.5 + Math.random() * 2, rnd(2.5))), V3(rnd(1), 0.6, rnd(1)), 4.2, Math.random() < 0.6 ? P.main : P.smoke, 1.6, 0.5, 1.2)); }); },
  ring(center, R, P) { P = P || PV.C; decal(center, R, T_HAZ, 0xffffff, 0.55, (o, u) => { o.scale.setScalar(Math.max(0.01, R * E.out(u))); o.material.opacity = 1 - u; });
    for (let i = 0; i < 18; i++) { const a = i / 18 * Math.PI * 2; smoke(center.clone().setY(1), V3(Math.cos(a) * R * 2.4, 2, Math.sin(a) * R * 2.4), 3, 0xc2ad7a, 0.7, 0.65, 1.6); } },
  nova(p, s) { this.impact(p, 2 * (s || 1)); this.ring(dilo.pos, 18); for (let i = 0; i < 10; i++) smoke(p.clone(), V3(rnd(6), 14 + Math.random() * 8, rnd(6)), 3, 0xffffff, 0.9, 0.7, 2); },
  barbs(pts, k, dt, st) { rate(st, "bs", 30 * k, dt, () => { const q = pts[(Math.random() * pts.length) | 0]; smoke(q.clone(), V3(rnd(2), 3, rnd(2)), 0.9, 0xf4f4ec, 0.5, 0.5, 2); }); rate(st, "bk", 8 * k, dt, () => sparkBurst(pts[(Math.random() * pts.length) | 0], UPV, 1, PV.C.fire, 10, 1, 0.2, 0.6)); },
};
const KITS = {A: KA, B: KB, C: KC};
