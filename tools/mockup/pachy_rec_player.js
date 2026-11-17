// pachy_rec_player.js v1.0 (Mecha Dino Arena) — plays move recordings made in Studio from the live game (MDA-552; Kepu
// 2026-11-17 "How about you actually use the fucking animation from the game"). Every part of the Pachy, the raptor bot and
// the effects near them was sampled 30 times a second (tools/studio/move_recorder.luau, packed by tools/mockup/rec_pack.py);
// this draws those parts where the game had them. Nothing is animated by hand here.
// Needs (set by the builder): REC {id: packed recording}, MOVES [{id, name, area, rec}], PHASES {id: [[t0, t1, label]]},
// INFO {id: {...}}, CAMERA {id: {points: [[x, y, z]] to keep in view (recording frame), pad: studs}}. Globals the sound panel uses: MOVES, cur, variant, play, playing, speed, M(), VV(), start(), step(),
// seek(), syncPlay(), renderAll(), $.
const $ = id => document.getElementById(id);
const AREA = {attack: ["Attack", "#ff6b6b"], speed: ["Speed", "#ffd34d"], defense: ["Defense", "#5fb4ff"], health: ["Health", "#7dff9a"], eng: ["Engineer", "#ff9b2e"]};
const cv = $("cv");
const renderer = new THREE.WebGLRenderer({canvas: cv, antialias: true});
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
renderer.shadowMap.enabled = true;
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x8fc6e8);
scene.fog = new THREE.Fog(0x8fc6e8, 260, 700);
const cam = new THREE.PerspectiveCamera(38, 16 / 9, 0.5, 2000);
scene.add(new THREE.HemisphereLight(0xffffff, 0x58703a, 0.75));
const sun = new THREE.DirectionalLight(0xffffff, 0.75);
sun.castShadow = true; sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, {left: -70, right: 70, top: 70, bottom: -70, near: 1, far: 300});
scene.add(sun, sun.target);
function noiseTex(base, spread, n) {
  const c = document.createElement("canvas"); c.width = c.height = 256; const x = c.getContext("2d");
  x.fillStyle = base; x.fillRect(0, 0, 256, 256);
  let s = 7; const rnd = () => (s = (s * 16807) % 2147483647) / 2147483647;
  for (let i = 0; i < n; i++) { const v = (rnd() - .5) * spread; x.fillStyle = `rgba(${v > 0 ? 255 : 0},${v > 0 ? 255 : 0},${v > 0 ? 200 : 0},${Math.abs(v)})`; x.fillRect(rnd() * 256, rnd() * 256, 3, 3); }
  const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; return t;
}
const gTex = noiseTex("#5f9a40", 0.16, 2600); gTex.repeat.set(80, 80);
const ground = new THREE.Mesh(new THREE.PlaneGeometry(1600, 1600), new THREE.MeshLambertMaterial({map: gTex}));
ground.rotation.x = -Math.PI / 2; ground.receiveShadow = true; scene.add(ground);

// ---------- geometry for Roblox part shapes (unit size; scaled by the part's Size) ----------
const GEO = {Block: new THREE.BoxGeometry(1, 1, 1), Ball: new THREE.SphereGeometry(0.5, 14, 10)};
GEO.Cylinder = new THREE.CylinderGeometry(0.5, 0.5, 1, 16); GEO.Cylinder.rotateZ(Math.PI / 2); // Roblox cylinders run along X
GEO.Wedge = (() => { // the slope rises from the front-bottom edge to the back-top edge (+Z back)
  const v = [[-.5, -.5, -.5], [.5, -.5, -.5], [.5, -.5, .5], [-.5, -.5, .5], [-.5, .5, .5], [.5, .5, .5]];
  const f = [[0, 2, 1], [0, 3, 2], [3, 4, 5], [3, 5, 2], [0, 1, 5], [0, 5, 4], [0, 4, 3], [1, 2, 5]];
  const pos = [];
  f.forEach(t => t.forEach(i => pos.push(...v[i])));
  const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3)); g.computeVertexNormals(); return g;
})();
function cfm(a) { const m = new THREE.Matrix4(); m.set(a[3], a[4], a[5], a[0], a[6], a[7], a[8], a[1], a[9], a[10], a[11], a[2], 0, 0, 0, 1); return m; }
const hexCol = h => new THREE.Color(parseInt(h, 16));

// ---------- a loaded recording ----------
let R = null; // {d, tracks (Int16Array), meshes, parts}
const _q0 = new THREE.Quaternion(), _q1 = new THREE.Quaternion(), _p0 = new THREE.Vector3(), _p1 = new THREE.Vector3(), _s1 = new THREE.Vector3(1, 1, 1);
function decode(b64) { const bin = atob(b64), u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i); return new Int16Array(u.buffer); }
function unload() {
  if (!R) return;
  R.parts.forEach(p => { if (p.mesh) { scene.remove(p.mesh); p.mesh.material.dispose(); } });
  R.pool.forEach(m => { scene.remove(m); m.userData.glow.dispose(); m.userData.flat.dispose(); });
  R.beams.forEach(m => { scene.remove(m); m.material.dispose(); });
  R = null;
}
function load(id) {
  unload();
  const d = REC[id];
  const tracks = d._tr || (d._tr = decode(d.tracks));
  const parts = d.parts.map((p, i) => {
    const e = {i, p, mesh: null, rel: p.rel ? cfm(p.rel) : null, ch: p.ch || []};
    if (!p.hid) {
      const neon = p.m === "Neon", glass = p.m === "Glass" || p.m === "ForceField";
      const mat = neon ? new THREE.MeshBasicMaterial({color: 0xffffff}) : new THREE.MeshLambertMaterial({color: 0xffffff});
      if (glass) mat.transparent = true;
      const mesh = new THREE.Mesh(GEO[p.sh] || GEO.Block, mat);
      mesh.matrixAutoUpdate = false; mesh.castShadow = !neon; mesh.receiveShadow = false;
      scene.add(mesh); e.mesh = mesh; e.neon = neon;
    }
    return e;
  });
  // particles: every one is worked out up front from the recorded emitters (seeded), so scrubbing is exact
  let seed = 12345; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  const P = [], dt = 1 / 30;
  const DIR = {Top: [0, 1, 0], Bottom: [0, -1, 0], Front: [0, 0, -1], Back: [0, 0, 1], Right: [1, 0, 0], Left: [-1, 0, 0]};
  function spawn(E, cf, t0, n) {
    const m = cfm(cf), o = new THREE.Vector3().setFromMatrixPosition(m), rot = new THREE.Matrix4().extractRotation(m);
    const base = new THREE.Vector3(...(DIR[E.dir] || DIR.Top)).applyMatrix4(rot).normalize();
    for (let k = 0; k < n; k++) {
      const sp = rad(E.spread || 0) * rnd(), az = rnd() * Math.PI * 2;
      // a direction inside the spread cone around base
      const a = Math.abs(base.y) < 0.9 ? new THREE.Vector3(0, 1, 0) : new THREE.Vector3(1, 0, 0);
      const u = new THREE.Vector3().crossVectors(base, a).normalize(), w = new THREE.Vector3().crossVectors(base, u);
      const dir = base.clone().multiplyScalar(Math.cos(sp)).addScaledVector(u, Math.sin(sp) * Math.cos(az)).addScaledVector(w, Math.sin(sp) * Math.sin(az));
      const speed = E.sp0 + (E.sp - E.sp0) * rnd(), life = Math.max(0.05, E.life0 + (E.life - E.life0) * rnd());
      P.push({t0, o, v: dir.multiplyScalar(speed), life, E, c0: hexCol(E.c0), c1: hexCol(E.c1)});
    }
  }
  (d.bursts || []).forEach(b => { const E = d.emitters[b.e]; spawn(E, E.cf, d.times[b.f] || 0, 12); });
  const acc = {};
  (d.emits || []).forEach(([f, k, cf, rate]) => { const E = d.emitters[k]; acc[k] = (acc[k] || 0) + rate * dt; const n = Math.floor(acc[k]); acc[k] -= n; if (n > 0) spawn(E, cf, d.times[f] || 0, Math.min(n, 8)); });
  const pool = [];
  const pgeo = new THREE.IcosahedronGeometry(0.5, 1);
  const matGlow = () => new THREE.MeshBasicMaterial({transparent: true, depthWrite: false, blending: THREE.AdditiveBlending});
  for (let k = 0; k < Math.min(700, P.length); k++) { const m = new THREE.Mesh(pgeo, new THREE.MeshBasicMaterial({transparent: true, depthWrite: false})); m.userData.glow = matGlow(); m.userData.flat = m.material; m.visible = false; scene.add(m); pool.push(m); }
  R = {id, d, tracks, parts, P, pool, beams: [], meCache: null};
  R.root = parts.find(e => e.p.o === "me" && e.p.n === "HumanoidRootPart");
  R.bot = parts.find(e => e.p.o === "bot" && e.p.n === "HumanoidRootPart");
  R.skull = parts.find(e => e.p.o === "me" && e.p.n === "Head_skull");
}
const rad = x => x * Math.PI / 180;

// frame lookup: index i and blend u for time t
function frameAt(t) {
  const T = R.d.times, n = T.length;
  if (t <= T[0]) return [0, 0];
  if (t >= T[n - 1]) return [n - 1, 0];
  let lo = 0, hi = n - 1;
  while (hi - lo > 1) { const m = (lo + hi) >> 1; if (T[m] <= t) lo = m; else hi = m; }
  return [lo, (t - T[lo]) / (T[lo + 1] - T[lo])];
}
const Y0 = () => -R.d.ground; // the recording's ground sits at y = ground under the start root; the page ground is y 0
function trackMatrix(k, i, u, out) {
  const F = R.d.frames, a = (k * F + i) * 7, tr = R.tracks;
  if (tr[a] === -32768) return false;
  _p0.set(tr[a] / 100, tr[a + 1] / 100 + Y0(), tr[a + 2] / 100); _q0.set(tr[a + 3] / 32767, tr[a + 4] / 32767, tr[a + 5] / 32767, tr[a + 6] / 32767);
  if (u > 0 && i + 1 < F) {
    const b = a + 7;
    if (tr[b] !== -32768) {
      _p1.set(tr[b] / 100, tr[b + 1] / 100 + Y0(), tr[b + 2] / 100); _q1.set(tr[b + 3] / 32767, tr[b + 4] / 32767, tr[b + 5] / 32767, tr[b + 6] / 32767);
      if (_q0.dot(_q1) < 0) _q1.set(-_q1.x, -_q1.y, -_q1.z, -_q1.w);
      _p0.lerp(_p1, u); _q0.set(_q0.x + (_q1.x - _q0.x) * u, _q0.y + (_q1.y - _q0.y) * u, _q0.z + (_q1.z - _q0.z) * u, _q0.w + (_q1.w - _q0.w) * u).normalize();
    }
  }
  out.compose(_p0, _q0.normalize(), _s1);
  return true;
}
function stateAt(e, fi) { // size, transparency, colour, gone at frame fi
  let s = e.p.s0, t = e.p.t0, c = e.p.c0, gone = !!e.p.gone0;
  for (const ch of e.ch) { if (ch[0] > fi) break; if (ch.length === 2 || ch[1] === 0) { gone = true; } else { s = ch[1]; t = ch[2]; c = ch[3]; gone = false; } }
  return {s, t, c, gone};
}
const _m = new THREE.Matrix4(), _sc = new THREE.Matrix4();
function drawAt(t) {
  const [i, u] = frameAt(t), fi = u > 0.5 ? i + 1 : i;
  const W = new Array(R.parts.length);
  const world = e => {
    if (W[e.i] !== undefined) return W[e.i];
    let m = null;
    if (e.p.k !== undefined) { const mm = new THREE.Matrix4(); if (trackMatrix(e.p.k, i, u, mm)) m = mm; }
    else if (e.p.seg !== undefined) { const sm = world(R.parts[e.p.seg]); if (sm) m = sm.clone().multiply(e.rel); }
    W[e.i] = m; return m;
  };
  for (const e of R.parts) {
    if (!e.mesh) { world(e); continue; }
    const st = stateAt(e, fi), m = world(e);
    if (!m || st.gone || st.t >= 0.99) { e.mesh.visible = false; continue; }
    e.mesh.visible = true;
    e.mesh.matrix.copy(m).multiply(_sc.makeScale(st.s[0], st.s[1], st.s[2]));
    const mat = e.mesh.material;
    if (e._c !== st.c) { mat.color.set(hexCol(st.c)); if (e.neon) mat.color.multiplyScalar(1.15); e._c = st.c; }
    const op = 1 - st.t;
    mat.transparent = op < 0.999 || mat.transparent; mat.opacity = op; mat.depthWrite = op > 0.6;
  }
  R.W = W;
  // particles
  let n = 0;
  for (const q of R.P) {
    const a = t - q.t0;
    if (a < 0 || a > q.life || n >= R.pool.length) continue;
    const E = q.E, k = a / q.life, drag = E.drag || 0;
    const f = drag > 0 ? (1 - Math.exp(-drag * a)) / drag : a;
    const m = R.pool[n++];
    m.visible = true;
    m.material = (E.le || 0) > 0.3 ? m.userData.glow : m.userData.flat; // light-emitting particles add light, as in the game
    m.position.copy(q.o).addScaledVector(q.v, f);
    m.position.x += 0.5 * E.acc[0] * a * a; m.position.y += 0.5 * E.acc[1] * a * a + Y0(); m.position.z += 0.5 * E.acc[2] * a * a;
    m.scale.setScalar(Math.max(0.05, E.s0 + (E.s1 - E.s0) * k));
    m.material.color.copy(q.c0).lerp(q.c1, k);
    m.material.opacity = Math.max(0, (1 - E.t0) * (1 - k) * 0.7);
  }
  for (; n < R.pool.length; n++) R.pool[n].visible = false;
  // beams and ropes on this frame (the tether chain)
  const L = (R.d.lines || []).filter(b => b[0] === fi);
  while (R.beams.length < L.length) { const m = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.5, 1, 6), new THREE.MeshLambertMaterial({color: 0xffffff})); scene.add(m); R.beams.push(m); }
  R.beams.forEach((m, k) => {
    const b = L[k]; m.visible = !!b; if (!b) return;
    const a = new THREE.Vector3(b[1], b[2] + Y0(), b[3]), c = new THREE.Vector3(b[4], b[5] + Y0(), b[6]), len = a.distanceTo(c);
    m.position.copy(a).lerp(c, 0.5); m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), c.clone().sub(a).normalize());
    m.scale.set(Math.max(0.15, b[7]), len, Math.max(0.15, b[7])); m.material.color.set(hexCol(b[8])); m.material.transparent = b[9] > 0; m.material.opacity = 1 - b[9];
  });
}
function posOf(e) { if (!e || !R.W) return null; const m = R.W[e.i]; return m ? new THREE.Vector3().setFromMatrixPosition(m) : null; }

// ---------- the player ----------
let cur = 0, variant = "A", playing = true, speed = 1, camMode = "hero", play = {t: 0};
const M = () => MOVES[cur], VV = () => ({len: REC[M().rec].len, phases: PHASES[M().id]});
function start() { play.t = 0; }
const camPos = new THREE.Vector3(40, 26, -10), camLook = new THREE.Vector3(0, 6, -10);
let snapCam = true;
function step(dt, noRender) {
  play.t = Math.min(VV().len, play.t + dt * speed);
  if (noRender) return;
  render();
}
function seek(t) { play.t = Math.max(0, Math.min(VV().len, t)); snapCam = true; render(); }
function render() {
  drawAt(play.t);
  const me = posOf(R.root) || new THREE.Vector3(0, 8, 0), bot = posOf(R.bot);
  const focus = [me];
  if (bot && bot.distanceTo(me) < 70) focus.push(bot);
  for (const p of (CAMERA[M().id] && CAMERA[M().id].points) || []) focus.push(new THREE.Vector3(p[0], p[1], p[2]));
  const lo = focus[0].clone(), hi = focus[0].clone();
  focus.forEach(p => { lo.min(p); hi.max(p); });
  let mid = lo.clone().lerp(hi, 0.5), span = lo.distanceTo(hi) + ((CAMERA[M().id] && CAMERA[M().id].pad) || 34);
  mid.y = Math.max(7, mid.y);
  const hfov = 2 * Math.atan(Math.tan(rad(cam.fov / 2)) * cam.aspect), vfit = span * 0.5 / Math.tan(hfov / 2);
  let cp, look = mid;
  if (camMode === "hero") cp = mid.clone().add(new THREE.Vector3(1, 0.4, -0.16).normalize().multiplyScalar(vfit * 1.08));
  else if (camMode === "side") cp = mid.clone().add(new THREE.Vector3(1, 0.14, 0).normalize().multiplyScalar(vfit * 1.1));
  else if (camMode === "game") { cp = me.clone().setY(0).add(new THREE.Vector3(10, 30, 44)); look = me.clone().setY(0).add(new THREE.Vector3(0, 8, -26)); }
  else { const h = posOf(R.skull) || me; cp = h.clone().add(new THREE.Vector3(15, 3, -15)); look = h.clone().add(new THREE.Vector3(0, -1.5, 0)); }
  const k = snapCam ? 1 : (camMode === "close" ? 0.3 : 0.15);
  camPos.lerp(cp, k); camLook.lerp(look, k); snapCam = false;
  cam.position.copy(camPos); cam.lookAt(camLook); cam.updateProjectionMatrix();
  sun.position.copy(me).add(new THREE.Vector3(30, 70, 30)); sun.target.position.copy(me);
  renderer.render(scene, cam);
}

// ---------- UI ----------
function renderAll() {
  $("moves").innerHTML = MOVES.map((m, i) => `<button class="tab" data-i="${i}" aria-pressed="${i === cur}">${m.name}<small style="color:${AREA[m.area][1]}">${AREA[m.area][0]}</small></button>`).join("");
  const ph = VV().phases, I = INFO[M().id], AR = AREA[M().area];
  $("phases").innerHTML = ph.map(p => `<button class="ph" data-t="${p[0]}" aria-current="false"><i>${p[0].toFixed(2)}–${p[1].toFixed(2)} s</i>${p[2]}</button>`).join("");
  $("info").innerHTML = `<div class="kind" style="color:${AR[1]}">${AR[0]} · ${M().name} · recorded in the game</div><h2>What you see, in order</h2><ul>${ph.map(p => `<li>${p[2]}</li>`).join("")}</ul><p class="note">${I.how}</p>`;
  $("part").innerHTML = `<div class="kind" style="color:${AR[1]}">The game's own timing (from this recording)</div><table class="cmp">${I.stamps.map(s => `<tr><th>${s[0]}</th><td>${s[1]}</td></tr>`).join("")}</table>`;
  if (!R || R.id !== M().rec) { load(M().rec); snapCam = true; }
}
$("moves").addEventListener("click", e => { const b = e.target.closest("[data-i]"); if (!b) return; cur = +b.dataset.i; renderAll(); start(); });
$("phases").addEventListener("click", e => { const b = e.target.closest("[data-t]"); if (!b) return; seek(+b.dataset.t + 0.02); playing = false; syncPlay(); });
$("play").onclick = () => { playing = !playing; syncPlay(); };
function syncPlay() { $("play").textContent = playing ? "Pause" : "Play"; $("play").setAttribute("aria-pressed", playing); }
document.querySelectorAll("[data-speed]").forEach(b => b.onclick = () => { speed = +b.dataset.speed; document.querySelectorAll("[data-speed]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => { camMode = b.dataset.view; snapCam = true; document.querySelectorAll("[data-view]").forEach(x => x.setAttribute("aria-pressed", x === b)); });
$("scrub").addEventListener("input", e => { seek(+e.target.value / 1000 * VV().len); playing = false; syncPlay(); });
function resize() { const w = cv.clientWidth, h = cv.clientHeight; if (renderer.domElement.width !== Math.round(w * renderer.getPixelRatio())) { renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); } }
window.addEventListener("resize", resize);
let last = performance.now();
function loop(now) {
  const dt = Math.min(0.05, (now - last) / 1000); last = now;
  resize();
  if (window.__soundClock) { const want = window.__soundClock(); play.t = Math.max(0, Math.min(VV().len, want)); render(); } // the sound's clock drives the picture
  else if (playing && !window.__manual) { step(dt); if (play.t >= VV().len - 1e-6) start(); }
  else render();
  $("scrub").value = Math.round(Math.min(1, play.t / VV().len) * 1000);
  $("clock").textContent = `${play.t.toFixed(2)} s${speed !== 1 ? " · 0.3×" : ""}`;
  const ph = VV().phases.find(p => play.t >= p[0] && play.t < p[1]);
  $("cap").textContent = ph ? ph[2] : "…";
  document.querySelectorAll(".ph").forEach(b => b.setAttribute("aria-current", !!ph && +b.dataset.t === ph[0]));
  requestAnimationFrame(loop);
}
renderAll(); start(); resize();
requestAnimationFrame(loop);
// test hook: __rec.set(move, t, cam) seeks there and pauses
window.__rec = {set(mv, time, cm) { window.__manual = true; cur = MOVES.findIndex(m => m.id === mv); if (cm) camMode = cm; renderAll(); seek(time); }, state: () => ({t: play.t, parts: R.parts.filter(e => e.mesh && e.mesh.visible).length, particles: R.pool.filter(m => m.visible).length})};
window.__ready = true;
