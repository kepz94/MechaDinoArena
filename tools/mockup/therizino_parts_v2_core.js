// Therizino mecha parts REDESIGN mockup v0.2 — core (scene, studded dino, piece kit, camera, loop).
// Kepu 2026-11-04 13:25: "redesign these mecha parts ... create models in our styles ... this just looks like slop";
// scope "Therizino first". THERI = TherizinoModelData (look A Reaper, tools/therizino_generator.py --json). Parts: the
// looks file (therizino_parts_v2_looks.js) adds LOOKS[id] = [{name, sub, ref, why, build(k)}], OLD[id] = build(k).
const THERI = __THERI__;
const VERSION = "0.2";
const $ = id => document.getElementById(id);
const rad = THREE.MathUtils.degToRad;
const AREA = {attack: ["ATTACK", "#f05a4f", 0xff3b30], defense: ["DEFENSE", "#5aa0ff", 0x3d9bff], speed: ["SPEED", "#ffd34d", 0xffc21a], eng: ["ENGINEER", "#ff9b2e", 0xff8a1a]};

// ---------- renderer / scene ----------
const cv = $("cv");
const renderer = new THREE.WebGLRenderer({canvas: cv, antialias: true, preserveDrawingBuffer: true});
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
const scene = new THREE.Scene();
const cam = new THREE.PerspectiveCamera(34, 16 / 9, 0.05, 900);
const hemi = new THREE.HemisphereLight(0xf2f8ff, 0x4a4438, 0.8); scene.add(hemi);
const sun = new THREE.DirectionalLight(0xffffff, 0.8); sun.position.set(-20, 40, -25); scene.add(sun);
const rim = new THREE.DirectionalLight(0x9fc4ff, 0.35); rim.position.set(25, 15, 30); scene.add(rim);
// lab backdrop (dark, like the Lab card) and the island (in game view)
const lab = new THREE.Group(); scene.add(lab);
{
  const disc = new THREE.Mesh(new THREE.CylinderGeometry(9, 9, 0.2, 48), new THREE.MeshLambertMaterial({color: 0x1a1f29}));
  disc.position.y = -0.1; lab.add(disc);
  const glowRing = new THREE.Mesh(new THREE.TorusGeometry(9, 0.07, 6, 64), new THREE.MeshBasicMaterial({color: 0x2c6f7a}));
  glowRing.rotation.x = Math.PI / 2; lab.add(glowRing);
}
const island = new THREE.Group(); scene.add(island); island.visible = false;
{
  const g = new THREE.Mesh(new THREE.PlaneGeometry(900, 900), new THREE.MeshLambertMaterial({color: 0x6f9a4a})); g.rotation.x = -Math.PI / 2; island.add(g);
  for (let i = 0; i < 220; i++) {
    const s = 0.3 + Math.random() * 0.6, p = new THREE.Mesh(new THREE.BoxGeometry(s, s * 0.5, s), new THREE.MeshLambertMaterial({color: i % 3 ? 0x7f9a52 : 0x6a5c44}));
    p.position.set((Math.random() - 0.5) * 120, s * 0.2, (Math.random() - 0.5) * 120); island.add(p);
  }
  for (let i = 0; i < 9; i++) { // block trees, like the island's
    const tr = new THREE.Group(), h = 6 + Math.random() * 5;
    const trunk = new THREE.Mesh(new THREE.BoxGeometry(1.2, h, 1.2), new THREE.MeshLambertMaterial({color: 0x6b4a2a})); trunk.position.y = h / 2; tr.add(trunk);
    const crown = new THREE.Mesh(new THREE.BoxGeometry(5, 3, 5), new THREE.MeshLambertMaterial({color: 0x4f8a3a})); crown.position.y = h + 1; tr.add(crown);
    const a = i / 9 * Math.PI * 2; tr.position.set(Math.cos(a) * (24 + Math.random() * 14), 0, Math.sin(a) * (24 + Math.random() * 14)); island.add(tr);
  }
}

// ---------- the game's studs (SurfaceType Studs on every face, 1 stud per stud of size; the dino is at scale 2) ----------
const GAME_SCALE = 2;
const studTex = (() => {
  const c = document.createElement("canvas"); c.width = c.height = 64; const g = c.getContext("2d");
  g.fillStyle = "#d8d8d8"; g.fillRect(0, 0, 64, 64);
  g.fillStyle = "rgba(0,0,0,.20)"; g.beginPath(); g.arc(35, 35, 17, 0, Math.PI * 2); g.fill();
  g.fillStyle = "#f2f2f2"; g.beginPath(); g.arc(31, 31, 16, 0, Math.PI * 2); g.fill();
  g.fillStyle = "#e2e2e2"; g.beginPath(); g.arc(33, 33, 11, 0, Math.PI * 2); g.fill();
  g.strokeStyle = "rgba(0,0,0,.10)"; g.lineWidth = 2; g.strokeRect(0, 0, 64, 64);
  const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.anisotropy = 4; return t;
})();
function studBox(sx, sy, sz) {
  const geo = new THREE.BoxGeometry(sx, sy, sz), uv = geo.attributes.uv, k = GAME_SCALE;
  const fs = [[sz, sy], [sz, sy], [sx, sz], [sx, sz], [sx, sy], [sx, sy]];
  for (let f = 0; f < 6; f++) for (let v = 0; v < 4; v++) { const i = f * 4 + v; uv.setXY(i, uv.getX(i) * fs[f][0] * k, uv.getY(i) * fs[f][1] * k); }
  uv.needsUpdate = true; return geo;
}
// Roblox WedgePart: full bottom and back (+Z) faces, the slope runs from the top-back edge down to the bottom-front edge
function wedgeGeo(sx, sy, sz) {
  const x = sx / 2, y = sy / 2, z = sz / 2;
  const A = [-x, -y, -z], B = [x, -y, -z], C = [x, -y, z], D = [-x, -y, z], E = [-x, y, z], F = [x, y, z];
  const tris = [A, C, B, A, D, C, D, F, C, D, E, F, A, B, F, A, F, E, A, E, D, B, C, F];
  const geo = new THREE.BufferGeometry(); geo.setAttribute("position", new THREE.Float32BufferAttribute(tris.flat(), 3)); geo.computeVertexNormals(); return geo;
}

// ---------- the dino ----------
function cfm(a) { const m = new THREE.Matrix4(); m.set(a[3], a[4], a[5], a[0], a[6], a[7], a[8], a[1], a[9], a[10], a[11], a[2], 0, 0, 0, 1); return m; }
const tmpE = new THREE.Euler();
function rot(p, y, r) { tmpE.set(rad(r), rad(y), rad(p), "ZYX"); return new THREE.Matrix4().makeRotationFromEuler(tmpE); } // = Angles(0,0,p)*Angles(0,y,0)*Angles(r,0,0)
const SMOOTH = new Set(["eyes", "pupil", "mouth"]);
function buildDino(D) {
  const g = new THREE.Group(); scene.add(g);
  const segs = {}, parts = [], byName = {};
  for (const s of D.segs) {
    const rootInv = cfm(s.root).invert(); segs[s.n] = [];
    for (const p of s.parts) {
      const smooth = SMOOTH.has(p.k);
      const mat = new THREE.MeshLambertMaterial({color: parseInt(p.c, 16), map: smooth ? null : studTex});
      const m = new THREE.Mesh(smooth ? new THREE.BoxGeometry(...p.s) : studBox(...p.s), mat); m.matrixAutoUpdate = false; g.add(m);
      const info = {mesh: m, local: rootInv.clone().multiply(cfm(p.cf)), cf: cfm(p.cf), size: p.s, seg: s.n, name: p.n}; segs[s.n].push(info); parts.push(info); byName[p.n] = info;
    }
  }
  const joints = D.joints.map(j => ({n: j.n, p0: j.p0, p1: j.p1, c0: cfm(j.c0), c1inv: cfm(j.c1).invert()}));
  return {D, g, segs, parts, byName, joints};
}
const theri = buildDino(THERI);
let restMinY;
function pose(A) {
  const W = {HRP: new THREE.Matrix4()};
  for (const j of theri.joints) { const v = A[j.n] || [0, 0, 0]; W[j.p1] = W[j.p0].clone().multiply(j.c0).multiply(rot(v[0], v[1], v[2])).multiply(j.c1inv); }
  for (const n in theri.segs) for (const p of theri.segs[n]) p.mesh.matrix.copy(W[n]).multiply(p.local);
  if (restMinY === undefined) {
    restMinY = Infinity; const c = new THREE.Vector3();
    for (const p of theri.parts) for (let i = 0; i < 8; i++) { c.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(p.mesh.matrix); restMinY = Math.min(restMinY, c.y); }
  }
  const lift = new THREE.Matrix4().makeTranslation(0, -restMinY, 0);
  for (const p of theri.parts) p.mesh.matrix.premultiply(lift);
}
// a point in the rest model's space, carried by a part as it moves
function restOn(name, p) { const b = theri.byName[name]; return new THREE.Vector3(...p).applyMatrix4(b.cf.clone().invert()).applyMatrix4(b.mesh.matrix); }

// ---------- the parts kit ----------
// MAT keys -> [colour, kind]; kind: "stud" (Plastic, Studs on every face, like the dino), "plain" (SmoothPlastic),
// "metal" (Metal), "neon" (Neon; the part's glow colour when colour is null).
const MAT = {
  shell: [0x5a636f, "stud"], plate: [0x828c99, "stud"], trim: [0x26292f, "plain"], bone: [0xe2dccb, "plain"], ivory: [0xcfc6ae, "stud"],
  brass: [0xc9a24a, "metal"], steel: [0x9aa3ad, "metal"], iron: [0x5d636c, "metal"], rubber: [0x16171b, "plain"],
  hazY: [0xffc832, "plain"], hazK: [0x1a1a1a, "plain"], glow: [null, "neon"], white: [0xf4f8ff, "neon"],
};
const equip = []; // {mesh, part, off, anim, glow, show, key}
let GLOW = 0xff3b30;
function material(key, color) {
  const [c, kind] = MAT[key];
  if (kind === "neon") return new THREE.MeshBasicMaterial({color: color || c || GLOW});
  if (kind === "metal") return new THREE.MeshPhongMaterial({color: c, specular: 0x9a9a9a, shininess: 60});
  return new THREE.MeshLambertMaterial({color: c, map: kind === "stud" ? studTex : null});
}
function geometry(sh, s) {
  if (sh === "cyl") return new THREE.CylinderGeometry(s[0] / 2, s[0] / 2, s[1], 18); // axis = local Y (size: diameter, length)
  if (sh === "cone") return new THREE.CylinderGeometry(0.01, s[0] / 2, s[1], 14);
  if (sh === "ball") return new THREE.SphereGeometry(s[0] / 2, 16, 12);
  if (sh === "wedge") return wedgeGeo(...s);
  if (sh === "ring") return new THREE.TorusGeometry(s[0], s[1], 8, 28); // radius, tube (axis = local Z)
  return null;
}
// Mount: a frame on a body part (pos / rot in the rest model's space); pieces are placed in the mount's own frame.
// a frame whose local Y runs along ydir (rest space) and local X as close to xhint as it can; Z = X x Y
function axisFrame(origin, ydir, xhint) {
  const Y = new THREE.Vector3(...ydir).normalize(), X = new THREE.Vector3(...(xhint || [1, 0, 0]));
  X.sub(Y.clone().multiplyScalar(X.dot(Y))).normalize(); const Z = X.clone().cross(Y);
  return new THREE.Matrix4().makeBasis(X, Y, Z).setPosition(...origin);
}
function mount(part, pos, r) { return mountM(part, new THREE.Matrix4().makeTranslation(...pos).multiply(rot(...(r || [0, 0, 0])))); }
function mountOn(part, pos, r) { return mountM(part, theri.byName[part].cf.clone().multiply(new THREE.Matrix4().makeTranslation(...(pos || [0, 0, 0]))).multiply(rot(...(r || [0, 0, 0])))); } // in the part's own frame
function mountM(part, base) {
  const self = {part, base, toRest: p => new THREE.Vector3(...p).applyMatrix4(base).toArray(),
    // add a piece: shape, size, local position, local rot [p, y, r] (deg), material key, options {anim(u,t)->Matrix4, glow, show, role}
    add(sh, s, p, r2, key, o) {
      o = o || {};
      const mat = material(key, o.color);
      const geo = geometry(sh, s) || (MAT[key][1] === "stud" ? studBox(...s) : new THREE.BoxGeometry(...s));
      const m = new THREE.Mesh(geo, mat); m.matrixAutoUpdate = false; scene.add(m);
      const local = new THREE.Matrix4().makeTranslation(...p).multiply(rot(...(r2 || [0, 0, 0])));
      const rest = base.clone().multiply(local); // rest model space
      const mountOff = theri.byName[part].cf.clone().invert().multiply(base);
      const e = {mesh: m, part, off: mountOff.clone().multiply(local), mountOff, place: o.place, rest, anim: o.anim, pivot: o.pivot, glow: key === "glow", show: o.show, sh, s, key, role: o.role, alpha: o.alpha};
      if (o.alpha) { mat.transparent = true; mat.opacity = o.alpha; mat.depthWrite = false; }
      equip.push(e); return e;
    },
    box(s, p, r2, key, o) { return self.add("box", s, p, r2, key, o); },
    cyl(s, p, r2, key, o) { return self.add("cyl", s, p, r2, key, o); },
    wedge(s, p, r2, key, o) { return self.add("wedge", s, p, r2, key, o); },
    ball(s, p, key, o) { return self.add("ball", [s, s, s], p, [0, 0, 0], key, o); },
    // a bolt head (brass) at p, facing local axis dir ("x" / "y" / "z")
    bolt(p, dir, d, key) { const r2 = dir === "x" ? [90, 0, 0] : dir === "z" ? [0, 0, 90] : [0, 0, 0]; return self.add("cyl", [d || 0.13, 0.06, 0], p, r2, key || "brass"); },
    // a strap band around a box-shaped limb section (w x h) at local p, thickness th
    band(w, h, len, p, key) { const th = 0.06; key = key || "trim";
      self.box([w + th * 2, th, len], [p[0], p[1] + h / 2 + th / 2, p[2]], null, key); self.box([w + th * 2, th, len], [p[0], p[1] - h / 2 - th / 2, p[2]], null, key);
      self.box([th, h, len], [p[0] + w / 2 + th / 2, p[1], p[2]], null, key); self.box([th, h, len], [p[0] - w / 2 - th / 2, p[1], p[2]], null, key); },
    // yellow / black launch stripes on a flat strip (along local x)
    hazard(len, h, p, r2, n) { n = n || 6; const w = len / n; for (let i = 0; i < n; i++) self.box([w, h, 0.03], [p[0] - len / 2 + w * (i + 0.5), p[1], p[2]], r2, i % 2 ? "hazK" : "hazY"); },
    // a hose of n cylinder links from a to b (local) sagging by sag along -y
    hose(a, b, sag, d, n) { n = n || 6; d = d || 0.16; const P = u => { const x = a[0] + (b[0] - a[0]) * u, y = a[1] + (b[1] - a[1]) * u - Math.sin(u * Math.PI) * sag, z = a[2] + (b[2] - a[2]) * u; return new THREE.Vector3(x, y, z); };
      for (let i = 0; i < n; i++) { const p0 = P(i / n), p1 = P((i + 1) / n), mid = p0.clone().add(p1).multiplyScalar(0.5), dir = p1.clone().sub(p0), len = dir.length() + d * 0.4;
        const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir.normalize()), e2 = new THREE.Euler().setFromQuaternion(q, "ZYX");
        self.add("cyl", [d, len, 0], mid.toArray(), [THREE.MathUtils.radToDeg(e2.z), THREE.MathUtils.radToDeg(e2.y), THREE.MathUtils.radToDeg(e2.x)], "rubber"); } },
  };
  return self;
}
// a cable between two body parts that follows both (drawn every frame; a Beam in the game)
const cables = [];
function cable(pa, a, pb, b, sag, d) {
  const n = 8, segs = [];
  for (let i = 0; i < n; i++) { const m = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.5, 1, 8), material("rubber")); m.matrixAutoUpdate = false; scene.add(m); segs.push(m); }
  const c = {pa, a, pb, b, sag: sag || 0.3, d: d || 0.14, segs}; cables.push(c); return c;
}
function updateCables() {
  for (const c of cables) {
    const A = restOn(c.pa, c.a), B = restOn(c.pb, c.b), n = c.segs.length;
    const P = u => A.clone().lerp(B, u).add(new THREE.Vector3(0, -Math.sin(u * Math.PI) * c.sag, 0));
    for (let i = 0; i < n; i++) { const p0 = P(i / n), p1 = P((i + 1) / n), dir = p1.clone().sub(p0), len = dir.length() + c.d * 0.3;
      const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir.normalize());
      c.segs[i].matrix.compose(p0.clone().add(p1).multiplyScalar(0.5), q, new THREE.Vector3(c.d, len, c.d)); c.segs[i].visible = true; }
  }
}
function clearEquip() {
  for (const e of equip) { scene.remove(e.mesh); e.mesh.geometry.dispose(); } equip.length = 0;
  for (const c of cables) for (const m of c.segs) { scene.remove(m); m.geometry.dispose(); } cables.length = 0;
}
const Tm = (x, y, z) => new THREE.Matrix4().makeTranslation(x, y, z), RXm = a => new THREE.Matrix4().makeRotationX(a),
  RYm = a => new THREE.Matrix4().makeRotationY(a), RZm = a => new THREE.Matrix4().makeRotationZ(a);
let use = 0, t = 0; // use: 0..1 how far the "Use it" motion is (eased), t: seconds
function updateEquip() {
  for (const e of equip) {
    const m = theri.byName[e.part].mesh.matrix.clone().multiply(e.place ? e.mountOff.clone().multiply(e.place(use, t)) : e.off);
    if (e.anim) { // anim gives a local matrix applied about the piece's own pivot (default: its centre)
      const a = e.anim(use, t);
      if (a) { if (e.pivot) m.multiply(Tm(...e.pivot)).multiply(a).multiply(Tm(-e.pivot[0], -e.pivot[1], -e.pivot[2])); else m.multiply(a); }
    }
    e.mesh.matrix.copy(m); e.mesh.visible = e.show ? e.show(use, t) : true;
    if (e.glow) { const k = 0.6 + 0.4 * Math.max(use, 0.5 + 0.5 * Math.sin(t * 3)); e.mesh.material.color.setHex(GLOW).multiplyScalar(k); if (e.alpha) e.mesh.material.opacity = e.alpha * use; }
  }
  updateCables();
}

// ---------- page state ----------
const PICK_KEY = "theriPartsRedesignPick_v0.2";
let PICK = {};
try { PICK = JSON.parse(localStorage.getItem(PICK_KEY) || "{}") || {}; } catch (e) { PICK = {}; }
function savePick() { try { localStorage.setItem(PICK_KEY, JSON.stringify(PICK)); } catch (e) {} }
let cur = 0, look = 0, old = false, using = false, spin = true, view = "lab";
const P = () => PARTS[cur];
const ease = u => u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2;
const lerp = (a, b, u) => a + (b - a) * u;
function mix(A, B, u) { const o = {}; for (const k of new Set([...Object.keys(A), ...Object.keys(B)])) { const a = A[k] || [0, 0, 0], b = B[k] || [0, 0, 0]; o[k] = [lerp(a[0], b[0], u), lerp(a[1], b[1], u), lerp(a[2], b[2], u)]; } return o; }
const IDLE = tt => ({Neck: [Math.sin(tt * 1.3) * 2, Math.sin(tt * 0.5) * 3, 0], Head: [Math.sin(tt * 1.3 + 1) * 3, 0, 0], Tail1: [0, Math.sin(tt * 0.8) * 3, 0], Tail2: [0, Math.sin(tt * 0.8 - 0.5) * 4, 0], Tail3: [0, Math.sin(tt * 0.8 - 1) * 5, 0], Tail4: [0, Math.sin(tt * 0.8 - 1.5) * 6, 0], Tail5: [0, Math.sin(tt * 0.8 - 2) * 7, 0]});

function build() {
  clearEquip();
  GLOW = AREA[P().area][2];
  if (old) OLD[P().id](); else P().looks[look].build();
}
function renderTabs() {
  $("parts").innerHTML = "";
  PARTS.forEach((p, i) => {
    const b = document.createElement("button"); b.className = "tab"; b.setAttribute("aria-pressed", i === cur);
    const pk = PICK[p.id] !== undefined ? `<span class="pk">✓ ${"ABC"[PICK[p.id]]}</span>` : "";
    b.innerHTML = `${pk}${p.name}<small style="color:${AREA[p.area][1]}">${AREA[p.area][0]}</small>`;
    b.onclick = () => { cur = i; look = PICK[p.id] !== undefined ? PICK[p.id] : 0; old = false; using = false; useT = 0; renderAll(); };
    $("parts").appendChild(b);
  });
  $("looks").innerHTML = "";
  P().looks.forEach((L, i) => {
    const b = document.createElement("button"); b.className = "tab"; b.setAttribute("aria-pressed", i === look && !old);
    b.innerHTML = `${"ABC"[i]} · ${L.name}<small style="color:var(--muted)">${L.sub}</small>`;
    b.onclick = () => { look = i; old = false; renderAll(); };
    $("looks").appendChild(b);
  });
  $("pickbtn").setAttribute("aria-pressed", PICK[P().id] === look && !old);
  $("pickbtn").textContent = PICK[P().id] === look && !old ? "Picked ✓" : "Pick this look";
  $("old").setAttribute("aria-pressed", old); $("use").setAttribute("aria-pressed", using);
  const line = PARTS.filter(p => PICK[p.id] !== undefined).map(p => `${p.short}-${"ABC"[PICK[p.id]]}`);
  $("pickline").textContent = line.length ? line.join(", ") : "none yet";
}
function renderInfo() {
  const p = P(), L = p.looks[look], a = AREA[p.area];
  $("info").innerHTML = old ? `<div class="kind" style="color:${a[1]}">${a[0]} · ${p.name}</div><h2>Old look (in the game now)</h2><p>${p.oldText}</p>`
    : `<div class="kind" style="color:${a[1]}">${a[0]} · ${p.name} · look ${"ABC"[look]}</div><h2>${L.name}</h2><p>${L.why}</p>
      <p class="note"><b style="color:var(--grey)">Borrowed from:</b> ${L.ref}</p><p class="note"><b style="color:var(--grey)">When used:</b> ${L.use}</p>
      <p class="note"><b style="color:var(--grey)">Sits on:</b> ${L.on}</p>`;
  $("state").textContent = old ? `${p.name} · old look` : `${p.name} · ${"ABC"[look]} ${L.name}`;
}
function renderAll() { renderTabs(); renderInfo(); build(); pose(IDLE(t)); updateEquip(); camGoal(); }
$("pickbtn").onclick = () => { if (old) return; if (PICK[P().id] === look) delete PICK[P().id]; else PICK[P().id] = look; savePick(); renderTabs(); };
$("copy").onclick = () => { const s = $("pickline").textContent; try { navigator.clipboard.writeText(s); $("copy").textContent = "Copied"; setTimeout(() => $("copy").textContent = "Copy", 1200); } catch (e) {} };
$("use").onclick = () => { using = !using; renderTabs(); };
$("old").onclick = () => { old = !old; renderAll(); };
$("spin").onclick = () => { spin = !spin; $("spin").setAttribute("aria-pressed", spin); };
document.querySelectorAll("[data-view]").forEach(b => b.onclick = () => { view = b.dataset.view; document.querySelectorAll("[data-view]").forEach(x => x.setAttribute("aria-pressed", x === b)); camGoal(); });
$("ver").textContent = "v" + VERSION;
{
  const sw = [["shell", "studded armour"], ["plate", "panels"], ["bone", "blades"], ["brass", "moving joints"], ["steel", "pistons / chain"], ["rubber", "hoses"]];
  $("swatches").innerHTML = sw.map(([k, n]) => `<span class="chip"><span class="sw" style="background:#${MAT[k][0].toString(16).padStart(6, "0")}"></span>${n}</span>`).join("") +
    Object.values(AREA).map(a => `<span class="chip"><span class="sw" style="background:${a[1]}"></span>${a[0].toLowerCase()} glow</span>`).join("");
}

// ---------- camera: orbit around a focus point ----------
let yaw = 0.9, pitch = 0.18, dist = 26, focus = new THREE.Vector3(0, 6, -1);
let gYaw = yaw, gPitch = pitch, gDist = dist, gFocus = focus.clone(), userTurned = 0;
function camGoal() {
  const L = old ? null : P().looks[look];
  const f = (L && L.focus) || P().focus || [0, 6, -1];
  const ly = -(restMinY || 0); // the model stands on y = 0 (lifted by the rest pose's lowest point)
  if (view === "lab") { gDist = 31; gPitch = 0.16; gFocus.set(0, 1.5 + ly, -0.5); }
  if (view === "close") { // frame the part itself (its pieces' box; one side only when the look says so)
    scene.updateMatrixWorld(true);
    const box = new THREE.Box3(), side = L && L.closeSide;
    for (const e of equip) { if (!e.mesh.visible) continue; const c = new THREE.Vector3().setFromMatrixPosition(e.mesh.matrix); if (side && Math.sign(c.x) !== side) continue; box.expandByPoint(c); }
    if (!box.isEmpty()) { box.getCenter(gFocus); gDist = Math.max(7, box.getSize(new THREE.Vector3()).length() * 1.6); } else gFocus.set(f[0], f[1] + ly, f[2]);
    if (L && L.closeDist) gDist = L.closeDist; gPitch = (L && L.closePitch !== undefined) ? L.closePitch : 0.22; if (L && L.closeYaw !== undefined) gYaw = L.closeYaw; }
  if (view === "side") { gDist = 30; gPitch = 0.05; gYaw = Math.PI / 2; gFocus.set(0, 1.5 + ly, -0.5); }
  if (view === "front") { gDist = 28; gPitch = 0.08; gYaw = 0; gFocus.set(0, 1.5 + ly, -2); }
  if (view === "game") { gDist = 46; gPitch = 0.32; gYaw = 2.5; gFocus.set(0, 1.5 + ly, 0); }
  lab.visible = view !== "game"; island.visible = view === "game";
  scene.background = new THREE.Color(view === "game" ? 0x8fc6e8 : 0x101218); scene.fog = view === "game" ? new THREE.Fog(0x8fc6e8, 120, 300) : null;
}
let drag = null;
cv.addEventListener("pointerdown", e => { drag = {x: e.clientX, y: e.clientY}; cv.setPointerCapture(e.pointerId); });
cv.addEventListener("pointermove", e => { if (!drag) return; gYaw -= (e.clientX - drag.x) * 0.008; gPitch = Math.max(-0.2, Math.min(1.2, gPitch + (e.clientY - drag.y) * 0.006)); drag = {x: e.clientX, y: e.clientY}; userTurned = 3; });
cv.addEventListener("pointerup", () => { drag = null; });
cv.addEventListener("wheel", e => { e.preventDefault(); gDist = Math.max(5, Math.min(70, gDist * (1 + Math.sign(e.deltaY) * 0.1))); }, {passive: false});
let pinch = null;
cv.addEventListener("touchmove", e => { if (e.touches.length === 2) { const d = Math.hypot(e.touches[0].clientX - e.touches[1].clientX, e.touches[0].clientY - e.touches[1].clientY); if (pinch) gDist = Math.max(5, Math.min(70, gDist * pinch / d)); pinch = d; drag = null; } }, {passive: true});
cv.addEventListener("touchend", () => { pinch = null; });

// ---------- loop ----------
let last = performance.now(), useT = 0;
function resize() { const w = cv.clientWidth, h = cv.clientHeight; if (cv.width !== Math.round(w * renderer.getPixelRatio()) || cv.height !== Math.round(h * renderer.getPixelRatio())) { renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); } }
function frame(now) {
  const dt = Math.min(0.05, (now - last) / 1000); last = now; t += dt;
  // use: rises to 1 over 0.45 s while "Use it" is on, the motion loops inside the look's own anim (via t)
  useT = using ? Math.min(1, useT + dt / 0.45) : Math.max(0, useT - dt / 0.45); use = ease(useT);
  const L = old ? null : P().looks[look];
  const PZ = (L && L.pose) || P().pose || {};
  const A = mix(IDLE(t), typeof PZ === "function" ? PZ(t) : PZ, use);
  pose(A); updateEquip();
  if (spin && !drag && userTurned <= 0 && view !== "side" && view !== "front") gYaw += dt * 0.35; userTurned -= dt;
  yaw = lerp(yaw, gYaw, 1 - Math.pow(0.002, dt)); pitch = lerp(pitch, gPitch, 1 - Math.pow(0.002, dt)); dist = lerp(dist, gDist, 1 - Math.pow(0.002, dt)); focus.lerp(gFocus, 1 - Math.pow(0.002, dt));
  cam.position.set(focus.x + Math.sin(yaw) * Math.cos(pitch) * dist, focus.y + Math.sin(pitch) * dist, focus.z - Math.cos(yaw) * Math.cos(pitch) * dist);
  cam.lookAt(focus);
  resize(); renderer.render(scene, cam);
  requestAnimationFrame(frame);
}
