// Dino roster mockup app v1.0. DINOS = model_json.py exports of every src/shared/Models/*ModelData.luau + roster meta.
const DINOS = __DINOS__;
const $ = id => document.getElementById(id);
const rad = THREE.MathUtils.degToRad;
const cv = $("cv");
const renderer = new THREE.WebGLRenderer({canvas: cv, antialias: true, preserveDrawingBuffer: true});
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x8fc6e8); scene.fog = new THREE.Fog(0x8fc6e8, 260, 700);
const cam = new THREE.PerspectiveCamera(32, 16 / 9, 0.1, 1500);
scene.add(new THREE.HemisphereLight(0xf2f8ff, 0x7a8a5a, 0.85));
const sun = new THREE.DirectionalLight(0xffffff, 0.75); sun.position.set(30, 40, -10); scene.add(sun);
const rim = new THREE.DirectionalLight(0xffe2b8, 0.35); rim.position.set(-30, 15, 30); scene.add(rim);
const ground = new THREE.Mesh(new THREE.PlaneGeometry(1500, 1500), new THREE.MeshLambertMaterial({color: 0x6fae4a}));
ground.rotation.x = -Math.PI / 2; scene.add(ground);
const grid = new THREE.GridHelper(1500, 300, 0x5c9a3c, 0x5c9a3c); grid.position.y = 0.02; grid.material.opacity = 0.35; grid.material.transparent = true; scene.add(grid);

function cfm(a) { const m = new THREE.Matrix4(); m.set(a[3], a[4], a[5], a[0], a[6], a[7], a[8], a[1], a[9], a[10], a[11], a[2], 0, 0, 0, 1); return m; }
const matCache = {};
function mat(hex) { return matCache[hex] || (matCache[hex] = new THREE.MeshLambertMaterial({color: parseInt(hex, 16)})); }
const corner = new THREE.Vector3();

function buildDino(D, scale) {
  const g = new THREE.Group(); scene.add(g);
  const segs = {}, parts = [];
  for (const s of D.segs) {
    const rootInv = cfm(s.root).invert(); segs[s.n] = [];
    for (const p of s.parts) {
      const hidden = (p.t || 0) >= 1 || p.n.includes("_fold"); // hidden in the data (pachy spikes) or the dilo's folded frill
      const m = new THREE.Mesh(new THREE.BoxGeometry(p.s[0], p.s[1], p.s[2]), mat(p.c)); m.matrixAutoUpdate = false; m.visible = !hidden; g.add(m);
      const info = {mesh: m, local: rootInv.clone().multiply(cfm(p.cf)), size: p.s, hidden}; segs[s.n].push(info); parts.push(info);
    }
  }
  const joints = D.joints.map(j => ({p0: j.p0, p1: j.p1, c0: cfm(j.c0), c1inv: cfm(j.c1).invert()}));
  return {g, segs, parts, joints, scale, x: 0, z: 0, yaw: 0, box: new THREE.Box3()};
}
function pose(d) {
  const W = {HRP: new THREE.Matrix4().makeRotationY(d.yaw)};
  for (const j of d.joints) W[j.p1] = W[j.p0].clone().multiply(j.c0).multiply(j.c1inv);
  let minY = Infinity; const box = new THREE.Box3();
  const S = new THREE.Matrix4().makeScale(d.scale, d.scale, d.scale);
  for (const n in d.segs) for (const p of d.segs[n]) {
    const m = S.clone().multiply(W[n]).multiply(p.local); p.mesh.matrix.copy(m);
    if (p.hidden) continue;
    for (let i = 0; i < 8; i++) { corner.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(m); minY = Math.min(minY, corner.y); box.expandByPoint(corner); }
  }
  const lift = new THREE.Matrix4().makeTranslation(d.x, -minY, d.z);
  for (const p of d.parts) p.mesh.matrix.premultiply(lift);
  box.translate(new THREE.Vector3(d.x, -minY, d.z)); d.box = box;
}

const dinos = DINOS.map(D => buildDino(D.model, D.scale));
// measure each at rest, facing -Z: length along Z, width along X, height along Y
dinos.forEach((d, i) => { pose(d); const sz = d.box.getSize(new THREE.Vector3()); d.len = sz.z; d.wid = sz.x; d.hgt = sz.y; });
const order = dinos.map((d, i) => i).sort((a, b) => dinos[a].len - dinos[b].len); // lineup: smallest to biggest

let mode = "one", idx = 0, view = "three", spin = false, yawUser = 0, lineTotal = 0;
const picker = $("picker");
DINOS.forEach((D, i) => {
  const b = document.createElement("button"); b.className = "tab"; b.dataset.i = i;
  b.innerHTML = `${i + 1} · ${D.name}<small>${D.live ? "live" : "saved"} · ${D.role}</small>`;
  b.onclick = () => { setMode("one"); setIdx(i); }; picker.appendChild(b);
});
function setIdx(i) {
  idx = (i + DINOS.length) % DINOS.length;
  picker.querySelectorAll("button").forEach(b => b.setAttribute("aria-pressed", +b.dataset.i === idx));
  showInfo();
}
function setMode(m) {
  mode = m; $("modeOne").setAttribute("aria-pressed", m === "one"); $("modeLine").setAttribute("aria-pressed", m === "line");
  if (m === "line") picker.querySelectorAll("button").forEach(b => b.setAttribute("aria-pressed", false)); else setIdx(idx);
  showInfo();
}
function fmt(v) { return v === null || v === undefined ? "—" : v; }
function showInfo() {
  if (mode === "line") {
    const rows = order.map(i => { const D = DINOS[i], d = dinos[i]; return `<tr><td>${D.name}</td><td>${D.role}</td><td>${Math.round(d.len)}</td><td>${Math.round(d.hgt)}</td><td>${fmt(D.hp)}</td><td>${fmt(D.speed)}</td><td>${D.live ? "Live" : "Saved"}</td></tr>`; }).join("");
    $("info").innerHTML = `<h2>Lineup · ${DINOS.length} dinos, smallest to biggest</h2><table style="width:100%;border-collapse:collapse;font-size:13px"><thead><tr style="color:var(--muted);text-align:left"><th>Dino</th><th>Role</th><th>Length</th><th>Height</th><th>HP</th><th>Run speed</th><th>Status</th></tr></thead><tbody>${rows}</tbody></table>`;
    return;
  }
  const D = DINOS[idx], d = dinos[idx];
  $("info").innerHTML = `<h2>${idx + 1} · ${D.full}<span class="tag ${D.live ? "live" : "saved"}">${D.live ? "Live" : "Saved, not installed"}</span></h2>
    <p class="sub">${D.role}</p><p>${D.blurb}</p>
    <div class="stats"><div class="stat"><b>Length in game</b>${d.len.toFixed(1)} studs</div><div class="stat"><b>Height in game</b>${d.hgt.toFixed(1)} studs</div>
    <div class="stat"><b>HP</b>${fmt(D.hp)}</div><div class="stat"><b>Run speed</b>${fmt(D.speed)}</div><div class="stat"><b>Model</b>${D.file} ${D.version}</div><div class="stat"><b>Blocks</b>${d.parts.filter(p => !p.hidden).length}</div></div>`;
}
$("modeOne").onclick = () => setMode("one");
$("modeLine").onclick = () => setMode("line");
$("prev").onclick = () => { if (mode === "line") setMode("one"); setIdx(idx - 1); };
$("next").onclick = () => { if (mode === "line") setMode("one"); setIdx(idx + 1); };
document.addEventListener("keydown", e => { if (e.key === "ArrowRight") $("next").onclick(); if (e.key === "ArrowLeft") $("prev").onclick(); });
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => { view = b.dataset.view; document.querySelectorAll("[data-view]").forEach(x => x.setAttribute("aria-pressed", x.dataset.view === view)); });
$("spin").onclick = e => { spin = !spin; e.currentTarget.setAttribute("aria-pressed", spin); };

function resize() { const w = cv.clientWidth, h = cv.clientHeight; renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); }
window.addEventListener("resize", resize);
let drag = null;
cv.addEventListener("pointerdown", e => { drag = e.clientX; cv.setPointerCapture(e.pointerId); });
cv.addEventListener("pointermove", e => { if (drag !== null) { yawUser += (e.clientX - drag) * 0.01; drag = e.clientX; } });
cv.addEventListener("pointerup", () => { drag = null; });

const labels = $("labels"), lblEls = DINOS.map(D => { const e = document.createElement("div"); e.className = "lbl"; e.innerHTML = `${D.name}<small>${D.role}</small>`; labels.appendChild(e); return e; });
let last = performance.now();
function frame(now) {
  const dt = Math.min(0.05, (now - last) / 1000); last = now;
  if (spin) yawUser -= dt * 0.4;
  const b = new THREE.Box3();
  if (mode === "one") {
    dinos.forEach((d, i) => { d.g.visible = i === idx; });
    const d = dinos[idx]; d.yaw = yawUser; d.x = 0; d.z = 0; pose(d); b.copy(d.box);
  } else {
    // side by side across the screen (perpendicular to the view), each in a slot as wide as the dino's footprint
    const vd = {three: [0.78, -0.55], side: [1, 0], front: [0, -0.7], top: [0, 1]}[view], vl = Math.hypot(vd[0], vd[1]);
    const ax = [vd[1] / vl, -vd[0] / vl]; // screen left -> right
    const slot = i => (view === "side" ? dinos[i].len : Math.max(dinos[i].wid, 8)) + (view === "side" ? 6 : 10);
    let total = order.reduce((s, i) => s + slot(i), 0), off = -total / 2; lineTotal = total;
    for (const i of order) {
      const d = dinos[i]; d.g.visible = true; d.yaw = yawUser;
      const o = off + slot(i) / 2; off += slot(i);
      d.x = ax[0] * o; d.z = ax[1] * o; pose(d);
      // keep each centred on its slot
      const c = d.box.getCenter(new THREE.Vector3()); d.x += ax[0] * o - c.x; d.z += ax[1] * o - c.z; pose(d);
      b.union(d.box);
    }
  }
  const c = b.getCenter(new THREE.Vector3()), size = b.getSize(new THREE.Vector3());
  const span = Math.max(size.z, size.x * 0.6, size.y * 1.8);
  const r = mode === "line" ? (lineTotal * 0.5 + 6) / (Math.tan(rad(cam.fov / 2)) * cam.aspect) * (view === "three" ? 1.05 : 1.0) : span * 0.5 / Math.tan(rad(cam.fov / 2)) / Math.min(1.6, cam.aspect) * 1.25;
  if (view === "side") cam.position.set(c.x + r, c.y + r * 0.06, c.z);
  else if (view === "front") cam.position.set(c.x + 0.001, c.y + r * 0.12, c.z - r);
  else if (view === "top") cam.position.set(c.x + 0.01, c.y + r, c.z);
  else cam.position.set(c.x + r * 0.78, c.y + r * 0.3, c.z - r * 0.55);
  cam.lookAt(c.x, c.y * 0.8, c.z);
  renderer.render(scene, cam);
  // labels over each dino in the lineup
  const W = cv.clientWidth, H = cv.clientHeight;
  dinos.forEach((d, i) => {
    const show = mode === "line" && view !== "top";
    lblEls[i].style.display = show ? "block" : "none";
    if (!show) return;
    const p = new THREE.Vector3((d.box.min.x + d.box.max.x) / 2, d.box.max.y + 1, (d.box.min.z + d.box.max.z) / 2).project(cam);
    lblEls[i].style.left = ((p.x + 1) / 2 * W) + "px"; lblEls[i].style.top = ((1 - p.y) / 2 * H) + "px";
  });
  requestAnimationFrame(frame);
}
resize(); setIdx(0); document.querySelector('[data-view="three"]').setAttribute("aria-pressed", true);
requestAnimationFrame(frame);
window.__ready = true;
window.__set = (m, i, v) => { view = v; setMode(m); if (m === "one") setIdx(i); };
