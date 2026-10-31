// Herrera skins mockup app. D = HerreraModelData 1.2 export (tools/mockup/herrera_model.json).
const D = __DATA__;
const $ = id => document.getElementById(id);
const rad = THREE.MathUtils.degToRad;

// ---------- SkinCatalog roles (v1.4) ----------
const ROLES = {"6E6A3A": "main", "2F3320": "stripes", "D3C89A": "belly", "B8414A": "markings", "5A5530": "limbs",
  "2C2620": "claws", "E8C547": "eyes", "B9B26A": "tailbands", "262A1A": "mask", "C9572E": "frill"};
const ROLE_ORDER = ["main", "stripes", "belly", "markings", "limbs", "claws", "eyes", "tailbands", "mask", "frill"];
const NEVER = new Set(["E8E2D2", "111111", "963C3C", "6E342E", "F5F5F0", "A3A2A5"]);
const PRICE = {STARTER: "free", COMMON: "free", RARE: "R$ 149", EPIC: "R$ 499", LEGENDARY: "R$ 999"};

const CLASSIC = {id: "classic", name: "Classic", rarity: "STARTER", vibe: "Swamp olive, the authored look.",
  c: {main: "6E6A3A", stripes: "2F3320", belly: "D3C89A", markings: "B8414A", limbs: "5A5530", claws: "2C2620", eyes: "E8C547",
    tailbands: "B9B26A", mask: "262A1A", frill: "C9572E"}, m: {}};

const SLOTS = [
  {key: "common", label: "Common", rarity: "COMMON", opts: [
    {id: "herrera_canopy", name: "Canopy", vibe: "Leaf-green tree climber with amber blotches; blends into the tree tops it hunts from.",
      c: {main: "4F7A3A", stripes: "24391C", belly: "C8D49A", markings: "D9A23A", limbs: "3F6530", claws: "2A2A1E", eyes: "F0E04A",
        tailbands: "8DB85A", mask: "1D2A16", frill: "6FA83C"}, m: {}},
    {id: "herrera_mudskipper", name: "Mudskipper", vibe: "Swamp-mud brown with teal flecks and a dull ochre frill.",
      c: {main: "6B5A3E", stripes: "3A2E20", belly: "C9B48A", markings: "4E7A6A", limbs: "574A33", claws: "241E18", eyes: "D8C24A",
        tailbands: "A08A5E", mask: "2C241A", frill: "8A6A3A"}, m: {}}]},
  {key: "rare1", label: "Rare 1", rarity: "RARE", opts: [
    {id: "herrera_bloodmoon", name: "Bloodmoon", vibe: "Charcoal hunter with crimson markings and glowing red eyes. Plays off the bleed kit.",
      c: {main: "3A3436", stripes: "1C191A", belly: "8A7E78", markings: "C8202E", limbs: "2E2A2B", claws: "0E0C0C", eyes: "FF3B3B",
        tailbands: "9A1E28", mask: "151213", frill: "B0182A"}, m: {eyes: "Neon"}},
    {id: "herrera_rust", name: "Rust Hide", vibe: "Burnt orange-brown with dark rust bands, like an old machine left in the rain.",
      c: {main: "8A4A2A", stripes: "3E1E10", belly: "D9A878", markings: "5A2A16", limbs: "73401F", claws: "201008", eyes: "FFC832",
        tailbands: "B8683A", mask: "2A140A", frill: "C2552E"}, m: {}}]},
  {key: "rare2", label: "Rare 2", rarity: "RARE", opts: [
    {id: "herrera_ghostbark", name: "Ghost Bark", vibe: "Pale birch-bark grey with black slashes and icy eyes. Reads clearly against green.",
      c: {main: "D8D2C2", stripes: "4A4640", belly: "EFE9DA", markings: "2A2724", limbs: "C4BDAB", claws: "3A3530", eyes: "7FE9FF",
        tailbands: "9A9488", mask: "5A554C", frill: "B8AE9A"}, m: {eyes: "Neon"}},
    {id: "herrera_dartfrog", name: "Dart Frog", vibe: "Poison-frog blue with yellow belly and blotches, orange frill. Loud warning colours.",
      c: {main: "2F7FD6", stripes: "0E1A2E", belly: "F2D23A", markings: "FFE14A", limbs: "2462A8", claws: "0B0F18", eyes: "FF8A1E",
        tailbands: "14243C", mask: "0A1220", frill: "FFB02E"}, m: {}}]},
  {key: "epic", label: "Epic", rarity: "EPIC", opts: [
    {id: "herrera_venom", name: "Venom", vibe: "Near-black with glowing toxic-lime stripes, blotches and frill. Matches the goo blob.",
      c: {main: "1E2420", stripes: "A6E22E", belly: "3A4438", markings: "7CFF4A", limbs: "2A3229", claws: "0D100D", eyes: "C6FF3A",
        tailbands: "5FBF2A", mask: "121612", frill: "8FE03A"}, m: {stripes: "Neon", markings: "Neon", eyes: "Neon", frill: "Neon"}},
    {id: "herrera_vampire", name: "Vampire", vibe: "Deep purple night hunter with glowing blood-red markings and frill.",
      c: {main: "2C1F3A", stripes: "160F20", belly: "5A4A6A", markings: "FF2E4A", limbs: "241A30", claws: "0C080F", eyes: "FF5A6E",
        tailbands: "7A2A8A", mask: "120C18", frill: "C8243C"}, m: {markings: "Neon", eyes: "Neon", frill: "Neon"}}]},
  {key: "legendary", label: "Legendary", rarity: "LEGENDARY", opts: [
    {id: "herrera_idol", name: "Golden Idol", vibe: "A temple statue come alive: gold body, glowing jade blotches, gold-foil frill.",
      c: {main: "D4A72C", stripes: "3A2A08", belly: "F5E4A8", markings: "1FA37A", limbs: "E6C25A", claws: "2A1E06", eyes: "FFF2B0",
        tailbands: "B8862A", mask: "4A3A10", frill: "FFD24A"}, m: {markings: "Neon", eyes: "Neon", frill: "Foil"}},
    {id: "herrera_obsidian", name: "Obsidian Fang", vibe: "Glossy black with glowing blood markings, gold-foil claws and gold eyes.",
      c: {main: "141416", stripes: "2A2A2E", belly: "3A3A40", markings: "D0202A", limbs: "1E1E22", claws: "D4A72C", eyes: "FFD24A",
        tailbands: "B81822", mask: "0A0A0C", frill: "9E1520"}, m: {markings: "Neon", claws: "Foil", eyes: "Neon", frill: "Neon"}}]},
];

// ---------- checks (the SkinCatalog rule for every new dino) ----------
const problems = [];
for (const s of SLOTS) for (const o of s.opts) {
  const seen = new Set();
  for (const r of ROLE_ORDER) {
    const h = o.c[r];
    if (!/^[0-9A-F]{6}$/.test(h || "")) problems.push(`${o.name}: ${r} bad hex`);
    if (NEVER.has(h)) problems.push(`${o.name}: ${r} uses a never-paint colour`);
    if (seen.has(h)) problems.push(`${o.name}: ${h} used twice`);
    seen.add(h);
  }
}
if (problems.length) console.error("palette problems", problems);

// ---------- three ----------
const cv = $("cv");
const renderer = new THREE.WebGLRenderer({canvas: cv, antialias: true, preserveDrawingBuffer: true});
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x141a26);
const cam = new THREE.PerspectiveCamera(30, 16 / 10, 0.1, 200);
scene.add(new THREE.HemisphereLight(0xeaf6ff, 0x3a4458, 0.62));
const sun = new THREE.DirectionalLight(0xffffff, 0.85); sun.position.set(-6, 12, 9); scene.add(sun);
const rim = new THREE.DirectionalLight(0xbfe6ff, 0.4); rim.position.set(8, 5, -10); scene.add(rim);
const pad = new THREE.Mesh(new THREE.CylinderGeometry(4.2, 4.4, 0.3, 48), new THREE.MeshLambertMaterial({color: 0x2a3446}));
pad.position.y = -0.15; scene.add(pad);
const ring = new THREE.Mesh(new THREE.TorusGeometry(4.3, 0.05, 8, 64), new THREE.MeshBasicMaterial({color: 0x7fe9ff}));
ring.rotation.x = Math.PI / 2; scene.add(ring);

function cfm(a) { const m = new THREE.Matrix4(); m.set(a[3], a[4], a[5], a[0], a[6], a[7], a[8], a[1], a[9], a[10], a[11], a[2], 0, 0, 0, 1); return m; }
const dino = new THREE.Group(); scene.add(dino);
const parts = []; const segs = {};
for (const s of D.segs) {
  const rootInv = cfm(s.root).invert(); segs[s.n] = [];
  for (const p of s.parts) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(p.s[0], p.s[1], p.s[2]), new THREE.MeshLambertMaterial({color: parseInt(p.c, 16)}));
    m.matrixAutoUpdate = false; dino.add(m);
    const info = {mesh: m, local: rootInv.clone().multiply(cfm(p.cf)), size: p.s, authored: p.c, role: ROLES[p.c] || null};
    segs[s.n].push(info); parts.push(info);
  }
}
const joints = D.joints.map(j => ({n: j.n, p0: j.p0, p1: j.p1, c0: cfm(j.c0), c1inv: cfm(j.c1).invert()}));
const tmpE = new THREE.Euler();
function rot(p, y, r) { tmpE.set(rad(r), rad(y), rad(p), "ZYX"); return new THREE.Matrix4().makeRotationFromEuler(tmpE); }
// standing pose: ScurryPose 1.0 rest angles (body pitch, tucked arms, bent legs, tail)
const POSE = {RootJoint: [-24, 0, 0], Neck: [6, 0, 0], Head: [16, 0, 0], Jaw: [-3, 0, 0], ArmL: [30, 0, -18], ArmR: [30, 0, 18],
  LegL: [48, 0, -16], LegR: [48, 0, 16], KneeL: [-48, 0, 0], KneeR: [-48, 0, 0], AnkleL: [24, 0, 0], AnkleR: [24, 0, 0],
  Tail1: [26, 0, 0], Tail2: [4, 0, 0], Tail3: [8, 0, 0], Tail4: [14, 0, 0], Tail5: [20, 0, 0]};
const corner = new THREE.Vector3();
let bounds = null;
function pose(yaw, breathe) {
  const W = {HRP: new THREE.Matrix4().makeRotationY(yaw)};
  for (const j of joints) {
    const v = POSE[j.n] || [0, 0, 0];
    const extra = j.n === "Tail3" || j.n === "Tail4" ? breathe * 6 : j.n === "Neck" ? breathe * 2 : 0;
    W[j.p1] = W[j.p0].clone().multiply(j.c0).multiply(rot(v[0] + (j.n === "Neck" ? extra : 0), j.n.startsWith("Tail") ? extra : 0, v[2])).multiply(j.c1inv);
  }
  let minY = Infinity; const box = new THREE.Box3();
  for (const n in segs) for (const p of segs[n]) {
    const m = W[n].clone().multiply(p.local); p.mesh.matrix.copy(m);
    for (let i = 0; i < 8; i++) { corner.set((i & 1 ? .5 : -.5) * p.size[0], (i & 2 ? .5 : -.5) * p.size[1], (i & 4 ? .5 : -.5) * p.size[2]).applyMatrix4(m); if (corner.y < minY) minY = corner.y; box.expandByPoint(corner); }
  }
  const lift = new THREE.Matrix4().makeTranslation(0, -minY, 0);
  for (const p of parts) p.mesh.matrix.premultiply(lift);
  box.min.y -= minY; box.max.y -= minY; bounds = box;
}

const neonMats = {}, lamMats = {}, foilMats = {};
function matFor(hex, material) {
  const col = parseInt(hex, 16);
  if (material === "Neon") return neonMats[hex] || (neonMats[hex] = new THREE.MeshBasicMaterial({color: new THREE.Color(col).multiplyScalar(1.15)}));
  if (material === "Foil") return foilMats[hex] || (foilMats[hex] = new THREE.MeshPhongMaterial({color: col, shininess: 120, specular: 0xffffff, emissive: new THREE.Color(col).multiplyScalar(0.18)}));
  if (material === "Glass") return lamMats["g" + hex] || (lamMats["g" + hex] = new THREE.MeshPhongMaterial({color: col, shininess: 90, transparent: true, opacity: 0.8}));
  return lamMats[hex] || (lamMats[hex] = new THREE.MeshLambertMaterial({color: col}));
}
function paint(skin) {
  for (const p of parts) {
    if (!p.role) { p.mesh.material = matFor(p.authored); continue; }
    p.mesh.material = matFor(skin.c[p.role], skin.m[p.role]);
  }
}

// ---------- state ----------
const pick = {}; // slot key -> 0 / 1
let viewKey = "classic"; // "classic" or slot key
try { const s = JSON.parse(localStorage.getItem("mda_herrera_skins_pick") || "{}"); for (const k in s) pick[k] = s[k] ? 1 : 0; } catch (e) {}
SLOTS.forEach(s => { if (pick[s.key] === undefined) pick[s.key] = 0; });
let viewOpt = 0;
function skinOf(key, opt) { if (key === "classic") return CLASSIC; const s = SLOTS.find(x => x.key === key); return Object.assign({rarity: s.rarity}, s.opts[opt]); }
function savePick() { try { localStorage.setItem("mda_herrera_skins_pick", JSON.stringify(pick)); } catch (e) {} }

// ---------- UI ----------
const tabs = $("tabs"), opts = $("opts"), info = $("info"), lineup = $("lineup");
function rarCls(r) { return "r-" + r.toLowerCase(); }
function drawTabs() {
  tabs.innerHTML = "";
  const all = [{key: "classic", label: "Classic", rarity: "STARTER"}].concat(SLOTS);
  for (const s of all) {
    const b = document.createElement("button");
    b.className = "tab " + rarCls(s.rarity); b.setAttribute("aria-pressed", viewKey === s.key);
    b.innerHTML = `${s.label}<small>${s.rarity} · ${PRICE[s.rarity]}</small>`;
    b.onclick = () => { viewKey = s.key; viewOpt = s.key === "classic" ? 0 : pick[s.key]; redraw(); };
    tabs.appendChild(b);
  }
}
function swatches(sk) {
  return `<div class="sw">${ROLE_ORDER.map(r => `<span title="${r} #${sk.c[r]}${sk.m[r] ? " · " + sk.m[r] : ""}" style="background:#${sk.c[r]}" class="${sk.m[r] === "Neon" ? "neon" : sk.m[r] === "Foil" ? "foil" : ""}"></span>`).join("")}</div>`;
}
function drawOpts() {
  opts.innerHTML = "";
  if (viewKey === "classic") { opts.innerHTML = `<p class="muted">Classic stays as it is (STARTER, free). Pick a rarity tab to compare the two options for that slot.</p>`; return; }
  const s = SLOTS.find(x => x.key === viewKey);
  s.opts.forEach((o, i) => {
    const sk = Object.assign({rarity: s.rarity}, o);
    const b = document.createElement("button");
    b.className = "opt"; b.setAttribute("aria-pressed", viewOpt === i);
    b.innerHTML = `<div class="oh"><b>${"AB"[i]} · ${o.name}</b>${pick[s.key] === i ? '<span class="chosen">IN LINEUP</span>' : ""}</div><div class="vibe">${o.vibe}</div>${swatches(sk)}`;
    b.onclick = () => { viewOpt = i; pick[s.key] = i; savePick(); redraw(); };
    opts.appendChild(b);
  });
}
function drawInfo() {
  const sk = skinOf(viewKey, viewOpt);
  const mats = Object.entries(sk.m).map(([r, m]) => `${r} ${m}`).join(", ") || "none";
  info.innerHTML = `<div class="card-h"><span class="rar ${rarCls(sk.rarity)}">${sk.rarity}</span><b>${sk.name}</b><span class="price">${PRICE[sk.rarity]}</span></div>
    <table>${ROLE_ORDER.map(r => `<tr><td>${r}</td><td><span class="chip" style="background:#${sk.c[r]}"></span>${sk.c[r]}</td><td>${sk.m[r] || ""}</td></tr>`).join("")}</table>
    <p class="muted">id <code>${sk.id}</code> · materials: ${mats}</p>`;
}
const thumbs = {};
function thumb(key, opt) {
  const k = key + ":" + opt; if (thumbs[k]) return thumbs[k];
  paint(skinOf(key, opt)); pose(-0.7, 0); frameCam(1.0);
  renderer.render(scene, cam); thumbs[k] = cv.toDataURL("image/png"); return thumbs[k];
}
function drawLineup() {
  const keys = [["classic", 0]].concat(SLOTS.map(s => [s.key, pick[s.key]]));
  lineup.innerHTML = keys.map(([k, o]) => { const sk = skinOf(k, o); return `<figure class="${rarCls(sk.rarity)}"><img alt="${sk.name}" src="${thumb(k, o)}"><figcaption><b>${sk.name}</b><span>${sk.rarity} · ${PRICE[sk.rarity]}</span></figcaption></figure>`; }).join("");
}
function frameCam(zoom) {
  const c = bounds.getCenter(new THREE.Vector3()), size = bounds.getSize(new THREE.Vector3());
  const r = Math.max(size.x, size.y, size.z) * 0.5 / Math.tan(rad(cam.fov / 2)) * (zoom || 1.15);
  cam.position.set(c.x + r * 0.15, c.y + r * 0.28, c.z + r); cam.lookAt(c.x, c.y * 0.9, c.z);
}
function redraw() { drawTabs(); drawOpts(); drawInfo(); drawLineup(); paint(skinOf(viewKey, viewOpt)); }

// size + loop
function resize() { const w = cv.clientWidth, h = cv.clientHeight; renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); }
window.addEventListener("resize", resize);
let yaw = -0.6, drag = null, auto = true;
cv.addEventListener("pointerdown", e => { drag = e.clientX; auto = false; cv.setPointerCapture(e.pointerId); });
cv.addEventListener("pointermove", e => { if (drag !== null) { yaw += (e.clientX - drag) * 0.01; drag = e.clientX; } });
cv.addEventListener("pointerup", () => { drag = null; });
$("spin").onclick = () => { auto = !auto; $("spin").setAttribute("aria-pressed", auto); };
const t0 = performance.now();
pose(yaw, 0); resize(); redraw(); paint(skinOf(viewKey, viewOpt));
function frame(now) {
  const t = (now - t0) / 1000;
  if (auto) yaw -= 0.006;
  pose(yaw, Math.sin(t * 1.6));
  frameCam(1.12);
  renderer.render(scene, cam);
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
window.__problems = problems;
