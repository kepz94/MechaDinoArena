// Camera options mockup v0.1 app (tools/camera_mockup/build.js inlines three.js r128 before this).
(function () {
"use strict";
const W = 844, H = 390, DEG = Math.PI / 180;
const $ = (s) => document.querySelector(s);
const screenEl = $("#screen"), phone = $("#phone"), viewport = $("#viewport"), canvas = $("#gl");

// ---------------------------------------------------------------- modes + variants
const MODES = {
  classic: { name: "CLASSIC", sub: "Dino faces where it walks · drag to orbit",
    tile: "Roblox's camera. The dino faces where it walks; drag to look around.",
    body: "faces where it walks (TurnLimit \"move\", 180°/s, swings wide on sharp turns)",
    move: "camera-relative; the dino turns toward the stick, then runs where it faces",
    look: "orbits the camera freely around the dino; the dino does not turn with it; no crosshair" },
  shift: { name: "SHIFT LOCK", sub: "Dino faces the camera · drag turns both",
    tile: "Camera centred behind. The dino always faces where you look.",
    body: "always turns to face the camera direction (TurnLimit \"aim\")",
    move: "camera-relative strafe: back = walk backwards, sideways = side-step",
    look: "turns camera and dino together; crosshair dot above the dino" },
  shoulder: { name: "SHOULDER", sub: "Over the right shoulder · today's camera",
    tile: "Today's view: over the right shoulder, dino on the left.",
    body: "always turns to face the camera direction (TurnLimit \"aim\")",
    move: "camera-relative strafe (as Shift Lock)",
    look: "turns camera and dino together; crosshair dot, dino off to the left" },
};
const ORDER = ["classic", "shift", "shoulder"];
const VARIANTS = {
  A: { btn: true, card: false, toggle: false,
    title: "A · Camera button on the HUD",
    opt: ["One tap mid-fight; no menu, the match never stops",
      "The Roblox habit: Blox Fruits and Project Slayers put a lock button on screen",
      "The current camera is named under the icon, so nobody is lost"],
    trade: ["One more button in the corner (Kepu said no shoulder-swap button on mobile before)",
      "It cycles three: Shoulder → Shift Lock means two taps through Classic",
      "No room to explain what each camera does", "MENU still only offers leaving, as today"] },
  B: { btn: false, card: true, toggle: false,
    title: "B · Settings card (MENU card + main menu)",
    opt: ["No new HUD button; the corner stays as it is",
      "Each camera explained with a picture before you pick",
      "Mid-match: tap MENU, pick, STAY; nobody has to leave the island"],
    trade: ["Two taps, and the fight keeps running behind the card",
      "Harder to find: the MENU pill reads as \"leave\" today",
      "The leave check grows a CAMERA row (a change to a card Kepu already picked)"] },
  C: { btn: true, card: true, toggle: true,
    title: "C · Both (recommended)",
    opt: ["The card explains and saves; the button is the one-tap shortcut",
      "Anyone who hates the button turns it off in the same card",
      "One saved setting behind both entry points; the button can ship later if needed"],
    trade: ["Most to build: two places to change one setting",
      "One more HUD button by default on phones (until switched off)"] },
};

const S = {
  variant: "C", mode: "shift", classicAim: "fix", hudBtn: true,
  zoom: 1, camYaw: 0, camPitch: -12 * DEG,
  pos: new THREE.Vector3(0, 0, 8), bodyYaw: 0, vy: 0, ground: true, jumpHeld: false,
  stick: null, looks: new Map(), pinch: null, keys: {}, overlay: null, jets: null, walk: 0,
};

// ---------------------------------------------------------------- svg icons
function camIcon(mode) {
  const st = 'fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"';
  if (mode === "classic") return `<path ${st} d="M5 14a8 8 0 0 1 14.5-4.7"/><path ${st} d="M20.5 5.5v4.2h-4.2"/><path ${st} d="M21 12a8 8 0 0 1-14.5 4.7"/><path ${st} d="M5.5 20.5v-4.2h4.2"/><circle cx="13" cy="13" r="2" fill="#ffc832"/>`;
  if (mode === "shift") return `<rect x="6" y="11.5" width="14" height="10" rx="2.2" fill="#ffc832" stroke="#ffc832"/><path ${st} d="M9 11.5V8.5a4 4 0 0 1 8 0v3"/><circle cx="13" cy="16.5" r="1.6" fill="#1e1a0a"/>`;
  return `<circle cx="16" cy="11" r="6.2" ${st}/><path ${st} d="M16 2.8v3M16 16.2v3M7.8 11h3M21.2 11h3"/><circle cx="16" cy="11" r="1.4" fill="#ffc832"/><rect x="3" y="16" width="6" height="7" rx="1.6" fill="#ffc832"/>`;
}
function diagram(mode) { // top-down: dino arrow + camera + view
  const g = '<circle cx="48" cy="34" r="30" fill="#24304a"/>';
  const cam = (x, y, a) => `<g transform="translate(${x} ${y}) rotate(${a})"><path d="M0 0 L-11 -20 L11 -20 Z" fill="rgba(127,233,255,.22)"/><rect x="-5" y="-3" width="10" height="7" rx="1.5" fill="#7fe9ff"/></g>`;
  const dino = (a, col) => `<g transform="translate(48 34) rotate(${a})"><path d="M0 -11 L7 7 L0 3 L-7 7 Z" fill="${col}"/></g>`;
  if (mode === "classic") return `${g}<circle cx="48" cy="34" r="22" fill="none" stroke="#8f99aa" stroke-dasharray="3 3"/>${cam(66, 52, -45)}${dino(-70, "#ffc832")}<path d="M60 20 l6 -2 -1 6" fill="none" stroke="#8f99aa" stroke-width="1.6"/>`;
  if (mode === "shift") return `${g}<path d="M48 60 V6" stroke="#ffc832" stroke-width="1.4" stroke-dasharray="2 3"/>${cam(48, 60, 0)}${dino(0, "#ffc832")}`;
  return `${g}<path d="M60 58 V6" stroke="#ffc832" stroke-width="1.4" stroke-dasharray="2 3"/>${cam(60, 58, 0)}${dino(0, "#ffc832")}`;
}
$("#mmDino").innerHTML = '<g fill="#4fa38a"><rect x="30" y="28" width="44" height="20" rx="3"/><rect x="66" y="16" width="12" height="20" rx="2" transform="rotate(20 72 26)"/><rect x="74" y="8" width="24" height="12" rx="2"/><rect x="8" y="30" width="26" height="8" rx="2" transform="rotate(-8 20 34)"/><rect x="38" y="46" width="8" height="18" rx="2"/><rect x="58" y="46" width="8" height="18" rx="2"/></g><rect x="82" y="2" width="4" height="12" fill="#e0d040" transform="rotate(-20 84 8)"/><rect x="46" y="20" width="18" height="7" rx="2" fill="#5a5f6b"/><circle cx="91" cy="12" r="1.6" fill="#111"/>';

// ---------------------------------------------------------------- three.js scene
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, preserveDrawingBuffer: true });
renderer.setSize(W, H, false);
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x9fd4f5);
scene.fog = new THREE.Fog(0x9fd4f5, 80, 240);
const camera = new THREE.PerspectiveCamera(70, W / H, 0.2, 600);
scene.add(new THREE.HemisphereLight(0xffffff, 0x4e6b34, 0.8));
const sun = new THREE.DirectionalLight(0xfff1d8, 0.75); sun.position.set(40, 90, 25); scene.add(sun);

function rng(seed) { return function () { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
const R = rng(7);
{ // ground
  const c = document.createElement("canvas"); c.width = c.height = 128; const x = c.getContext("2d");
  x.fillStyle = "#71ad4b"; x.fillRect(0, 0, 128, 128);
  for (let i = 0; i < 900; i++) { x.fillStyle = R() < 0.5 ? "rgba(40,90,30,.18)" : "rgba(170,220,110,.16)"; x.fillRect(R() * 128, R() * 128, 2 + R() * 3, 2 + R() * 3); }
  x.strokeStyle = "rgba(40,80,30,.22)"; x.lineWidth = 2; x.strokeRect(0, 0, 128, 128);
  const tex = new THREE.CanvasTexture(c); tex.wrapS = tex.wrapT = THREE.RepeatWrapping; tex.repeat.set(90, 90); tex.anisotropy = 4;
  const g = new THREE.Mesh(new THREE.PlaneGeometry(720, 720), new THREE.MeshLambertMaterial({ map: tex }));
  g.rotation.x = -Math.PI / 2; scene.add(g);
}
const mat = {}; const M = (c) => mat[c] || (mat[c] = new THREE.MeshLambertMaterial({ color: c }));
function box(w, h, d, c, x, y, z, parent) { const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), M(c)); m.position.set(x, y, z); parent.add(m); return m; }
const trees = [], blockers = [];
for (let i = 0; i < 120; i++) {
  const a = R() * Math.PI * 2, r = 30 + Math.pow(R(), 0.8) * 150;
  const x = Math.cos(a) * r, z = Math.sin(a) * r;
  if (Math.hypot(x, z - 8) < 32) continue;
  const t = new THREE.Group(); t.position.set(x, 0, z); t.rotation.y = R() * 3;
  const h = 5 + R() * 4, s = 0.85 + R() * 0.5;
  box(1.2 * s, h, 1.2 * s, 0x7a5232, 0, h / 2, 0, t);
  const greens = [0x3f8f3a, 0x4fa244, 0x5bb04c];
  box(6 * s, 2.4 * s, 6 * s, greens[i % 3], 0, h + 0.6, 0, t);
  box(4.4 * s, 2.2 * s, 4.4 * s, greens[(i + 1) % 3], 0, h + 2.6 * s, 0, t);
  box(2.6 * s, 1.8 * s, 2.6 * s, greens[(i + 2) % 3], 0, h + 4.3 * s, 0, t);
  scene.add(t); trees.push({ x, z, r: 0.9 * s + 0.9 }); t.children.forEach((c) => blockers.push(c));
}
for (let i = 0; i < 40; i++) {
  const a = R() * Math.PI * 2, r = 12 + R() * 140, x = Math.cos(a) * r, z = Math.sin(a) * r;
  if (Math.hypot(x, z - 8) < 18) continue;
  const s = 0.8 + R() * 2.2;
  const m = new THREE.Mesh(new THREE.DodecahedronGeometry(s, 0), new THREE.MeshLambertMaterial({ color: R() < 0.5 ? 0x8c8f96 : 0x9a9488, flatShading: true }));
  m.position.set(x, s * 0.35, z); m.scale.y = 0.6; m.rotation.set(R(), R(), R()); scene.add(m); blockers.push(m);
  if (s > 1.6) trees.push({ x, z, r: s * 0.9 });
}

function makeDino(c) {
  const root = new THREE.Group(), rig = new THREE.Group(); root.add(rig);
  const sh = new THREE.Mesh(new THREE.CircleGeometry(2.4, 20), new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.22, depthWrite: false }));
  sh.rotation.x = -Math.PI / 2; sh.position.y = 0.03; root.add(sh);
  box(2.2, 1.9, 3.8, c.body, 0, 2.75, 0.2, rig);
  box(1.9, 0.6, 3.2, c.belly, 0, 1.95, 0.2, rig);
  const neck = new THREE.Group(); neck.position.set(0, 3.1, -1.5); neck.rotation.x = 0.55; rig.add(neck);
  box(1.0, 1.0, 2.0, c.body, 0, 0, -0.9, neck);
  const head = new THREE.Group(); head.position.set(0, 4.25, -2.75); rig.add(head);
  box(1.3, 1.1, 1.8, c.body, 0, 0, -0.2, head);
  box(1.0, 0.7, 1.1, c.body, 0, -0.1, -1.5, head);
  box(1.0, 0.32, 1.6, c.belly, 0, -0.58, -0.9, head);
  box(0.14, 0.2, 0.2, 0x111111, 0.66, 0.2, -0.5, head); box(0.14, 0.2, 0.2, 0x111111, -0.66, 0.2, -0.5, head);
  if (c.frill) { const f1 = box(0.1, 1.3, 1.2, c.frill, 0.78, 0.15, 0.35, head); f1.rotation.z = -0.55; const f2 = box(0.1, 1.3, 1.2, c.frill, -0.78, 0.15, 0.35, head); f2.rotation.z = 0.55; box(0.14, 0.55, 1.5, c.accent, 0, 0.75, -0.3, head); }
  const tail = []; let p = rig; const tw = [[1.5, 1.3], [1.0, 0.9], [0.6, 0.55]]; let zz = 2.1;
  for (let i = 0; i < 3; i++) { const t = new THREE.Group(); t.position.set(0, i === 0 ? 2.95 : 0, i === 0 ? zz : 2.2); p.add(t); box(tw[i][0], tw[i][1], 2.3, i === 2 ? c.accent : c.body, 0, 0, 1.1, t); tail.push(t); p = t; }
  const legs = [];
  for (const sd of [1, -1]) {
    const hip = new THREE.Group(); hip.position.set(sd * 0.95, 2.4, 0.5); rig.add(hip);
    box(0.75, 1.5, 1.0, c.body, 0, -0.6, 0, hip);
    const knee = new THREE.Group(); knee.position.set(0, -1.3, 0.15); hip.add(knee);
    box(0.5, 1.2, 0.55, c.body, 0, -0.5, 0, knee); box(0.85, 0.3, 1.25, c.accent, 0, -1.05, -0.3, knee);
    legs.push({ hip, knee });
    box(0.3, 0.8, 0.3, c.body, sd * 0.85, 2.5, -1.7, rig);
  }
  if (c.mecha) {
    box(0.55, 0.55, 1.8, 0x5a5f6b, 0.85, 3.95, 0.4, rig); box(0.2, 0.2, 0.7, 0x2b2f38, 0.85, 3.95, -0.8, rig);
    const tube = new THREE.Mesh(new THREE.CylinderGeometry(0.38, 0.38, 1.3, 10), M(0x5a5f6b)); tube.position.set(-0.85, 4.1, 0.8); tube.rotation.x = -0.5; rig.add(tube);
    box(0.95, 0.25, 0.95, c.accent, -0.85, 3.6, 0.9, rig);
  }
  return { root, rig, head, tail, legs };
}
const me = makeDino({ body: 0x4fa38a, belly: 0xd9e6c3, accent: 0xe0b23a, frill: 0xe8d24a, mecha: true });
scene.add(me.root);
const bot = makeDino({ body: 0xd8743a, belly: 0xf0d0a8, accent: 0x5a3a24 });
bot.root.scale.setScalar(0.9); scene.add(bot.root);
const B = { pos: new THREE.Vector3(-4, 0, -16), yaw: 0, target: new THREE.Vector3(6, 0, -24), hp: 60, max: 60, flash: 0, walk: 0, wait: 0 };
const hpC = document.createElement("canvas"); hpC.width = 128; hpC.height = 34;
const hpTex = new THREE.CanvasTexture(hpC);
const hpSprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: hpTex, depthTest: false, transparent: true }));
hpSprite.scale.set(4.4, 1.17, 1); scene.add(hpSprite);
function drawBotHp() {
  const x = hpC.getContext("2d"); x.clearRect(0, 0, 128, 34);
  x.font = "600 13px Fredoka, sans-serif"; x.fillStyle = "#fff"; x.textAlign = "center"; x.strokeStyle = "rgba(0,0,0,.7)"; x.lineWidth = 3;
  x.strokeText("BOT RAPTOR", 64, 12); x.fillText("BOT RAPTOR", 64, 12);
  x.fillStyle = "rgba(20,20,26,.85)"; x.fillRect(4, 18, 120, 12);
  x.fillStyle = B.hp / B.max > 0.3 ? "#5fd16a" : "#f05a4f"; x.fillRect(6, 20, 116 * B.hp / B.max, 8);
  hpTex.needsUpdate = true;
}
drawBotHp();

// ---------------------------------------------------------------- math helpers
const fwdOf = (yaw) => new THREE.Vector3(-Math.sin(yaw), 0, -Math.cos(yaw));
const rightOf = (yaw) => new THREE.Vector3(Math.cos(yaw), 0, -Math.sin(yaw));
const yawOf = (v) => Math.atan2(-v.x, -v.z);
const wrap = (a) => { a = (a + Math.PI) % (2 * Math.PI); if (a < 0) a += 2 * Math.PI; return a - Math.PI; };
function turnToward(a, b, step) { const e = wrap(b - a); return a + Math.max(-step, Math.min(step, e)); }
const lookDir = (yaw, pitch) => new THREE.Vector3(-Math.sin(yaw) * Math.cos(pitch), Math.sin(pitch), -Math.cos(yaw) * Math.cos(pitch));

// framing (ShoulderCam 1.8 formulas on the mockup dino: top 3.2 above the HRP, width 2.6)
const HRP_Y = 2.4, TOP = 3.2, WID = 2.6;
const FOCUS_H = 0.75 * TOP, SIDE = Math.max(0.6 * WID, 0.9 * TOP + 1), SH_H = 0.35 * TOP, LIFT = 0.8 * TOP;
const DIST = 15, TURN = 180 * DEG, SPEED = 22;

const ray = new THREE.Raycaster();
function placeCamera() {
  const ld = lookDir(S.camYaw, S.camPitch);
  let focus, pos;
  if (S.mode === "classic") {
    focus = S.pos.clone().add(new THREE.Vector3(0, HRP_Y + 2.1, 0));
    pos = focus.clone().addScaledVector(ld, -DIST * 1.05 * S.zoom);
  } else {
    focus = S.pos.clone().add(new THREE.Vector3(0, HRP_Y + FOCUS_H, 0));
    const side = S.mode === "shoulder" ? SIDE : 0, up = S.mode === "shoulder" ? SH_H : LIFT;
    pos = focus.clone().addScaledVector(rightOf(S.camYaw), side).add(new THREE.Vector3(0, up, 0)).addScaledVector(ld, -DIST * S.zoom);
  }
  if (pos.y < 0.8) pos.y = 0.8;
  // pulled in to just before trees / rocks (ShoulderCam clearSpot, WALL_PAD 0.6; Roblox's camera does the same)
  const dir = pos.clone().sub(focus), L = dir.length(); dir.normalize();
  ray.set(focus, dir); ray.far = L;
  const hit = ray.intersectObjects(blockers, false)[0];
  if (hit) pos = focus.clone().addScaledVector(dir, Math.max(0.5, hit.distance - 0.6));
  camera.position.copy(pos);
  if (S.mode === "classic") camera.lookAt(focus); else camera.lookAt(pos.clone().add(ld));
}

// ---------------------------------------------------------------- input
const k = { v: 1 };
function toLocal(e) { const r = screenEl.getBoundingClientRect(); return { x: (e.clientX - r.left) / k.v, y: (e.clientY - r.top) / k.v }; }
const stickEl = $("#stick"), knob = stickEl.querySelector(".knob");
function stickIdle() { stickEl.className = "idle"; stickEl.style.left = "120px"; stickEl.style.top = "262px"; knob.style.transform = ""; }
stickIdle();
screenEl.addEventListener("pointerdown", (e) => {
  if (S.overlay) return;
  if (e.target.closest && e.target.closest(".hit")) return;
  const p = toLocal(e);
  screenEl.setPointerCapture(e.pointerId);
  $("#hint").style.opacity = "0";
  if (p.x < W * 0.4 && !S.stick) {
    S.stick = { id: e.pointerId, ox: p.x, oy: p.y, x: 0, y: 0 };
    stickEl.className = ""; stickEl.style.left = p.x + "px"; stickEl.style.top = p.y + "px";
  } else {
    S.looks.set(e.pointerId, p);
    if (S.looks.size === 2) { const [a, b] = [...S.looks.values()]; S.pinch = { d: Math.hypot(a.x - b.x, a.y - b.y), z: S.zoom }; }
  }
  e.preventDefault();
});
screenEl.addEventListener("pointermove", (e) => {
  const p = toLocal(e);
  if (S.stick && e.pointerId === S.stick.id) {
    let dx = p.x - S.stick.ox, dy = p.y - S.stick.oy; const L = Math.hypot(dx, dy), R0 = 48;
    if (L > R0) { dx *= R0 / L; dy *= R0 / L; }
    S.stick.x = dx / R0; S.stick.y = -dy / R0;
    knob.style.transform = `translate(${dx}px, ${dy}px)`;
    return;
  }
  const prev = S.looks.get(e.pointerId);
  if (!prev) return;
  S.looks.set(e.pointerId, p);
  if (S.looks.size >= 2 && S.pinch) {
    const [a, b] = [...S.looks.values()]; const d = Math.hypot(a.x - b.x, a.y - b.y);
    if (d > 10) S.zoom = clampZoom(S.pinch.z * S.pinch.d / d);
    return;
  }
  const kk = 0.35 * DEG; // ShoulderCamTouchSensitivity 0.35 deg / px
  S.camYaw = wrap(S.camYaw - (p.x - prev.x) * kk);
  S.camPitch -= (p.y - prev.y) * kk;
  clampPitch();
});
function endPointer(e) {
  if (S.stick && e.pointerId === S.stick.id) { S.stick = null; stickIdle(); }
  S.looks.delete(e.pointerId); if (S.looks.size < 2) S.pinch = null;
}
screenEl.addEventListener("pointerup", endPointer);
screenEl.addEventListener("pointercancel", endPointer);
screenEl.addEventListener("wheel", (e) => { if (S.overlay) return; S.zoom = clampZoom(S.zoom * (1 + 0.1 * Math.sign(e.deltaY))); e.preventDefault(); }, { passive: false });
const clampZoom = (z) => Math.max(0.6, Math.min(1.5, z));
function clampPitch() {
  const lo = S.mode === "classic" ? -70 : -55, hi = S.mode === "classic" ? 35 : 65;
  S.camPitch = Math.max(lo * DEG, Math.min(hi * DEG, S.camPitch));
}
addEventListener("keydown", (e) => {
  if (e.target && e.target.tagName === "INPUT") return;
  const c = e.code; S.keys[c] = true;
  if (c === "Space") { S.jumpHeld = true; e.preventDefault(); }
  if (c === "KeyF") attack();
  if (c === "KeyG") slot(1, false);
  if (c === "KeyH") slot(2, false);
});
addEventListener("keyup", (e) => { S.keys[e.code] = false; if (e.code === "Space") S.jumpHeld = false; });

// HUD buttons (pointer events; a press scales to 0.92 like ArenaTouch / MechaButtons)
function press(el, down, up) {
  el.addEventListener("pointerdown", (e) => { if (S.overlay) return; e.stopPropagation(); el.classList.add("pressed"); el.setPointerCapture(e.pointerId); down && down(e); });
  const end = (e) => { el.classList.remove("pressed"); up && up(e); };
  el.addEventListener("pointerup", end); el.addEventListener("pointercancel", end);
}
press($("#jump"), () => { S.jumpHeld = true; }, () => { S.jumpHeld = false; });
let holdAt = null;
press($("#attack"), () => { holdAt = performance.now(); attack(); }, () => { holdAt = null; });
for (const el of [$("#slot1"), $("#slot2")]) {
  let y0 = null, pulling = false;
  press(el, (e) => { y0 = toLocal(e).y; pulling = false; }, () => { if (y0 !== null) slot(+el.dataset.n, pulling); y0 = null; el.classList.remove("pulling"); });
  el.addEventListener("pointermove", (e) => { if (y0 === null) return; pulling = toLocal(e).y - y0 >= 18; el.classList.toggle("pulling", pulling); });
}
press($("#camBtn"), () => { setMode(ORDER[(ORDER.indexOf(S.mode) + 1) % 3], true); });
$("#menuPill").addEventListener("pointerdown", (e) => { e.stopPropagation(); if (!S.overlay) openOv("menu"); });
$("#skills").addEventListener("pointerdown", (e) => { e.stopPropagation(); toast("SKILLS", "The Lab opens here in the game (not in this mockup)"); });

// ---------------------------------------------------------------- overlays
function openOv(which) {
  S.overlay = which; S.stick = null; stickIdle(); S.looks.clear();
  $("#ovMenu").classList.toggle("on", which === "menu");
  $("#mainmenu").classList.toggle("on", which === "main" || which === "settings");
  $("#ovSettings").classList.toggle("on", which === "settings");
  refreshUI();
}
function closeOv() { openOv(null); }
document.querySelectorAll("[data-close]").forEach((d) => d.addEventListener("click", () => { d.dataset.close === "2" ? openOv("main") : closeOv(); }));
$("#stayBtn").addEventListener("click", closeOv);
$("#leaveBtn").addEventListener("click", () => openOv("main"));
$("#setPill").addEventListener("click", () => { $("#setPill").classList.remove("new"); openOv("settings"); });
$("#setX").addEventListener("click", () => openOv("main"));
for (const id of ["#playSb", "#playAr"]) $(id).addEventListener("click", () => { respawn(); closeOv(); });
for (const id of ["#menuSw", "#setSw"]) $(id).addEventListener("click", () => { S.hudBtn = !S.hudBtn; refreshUI(); });

function buildPickers() {
  $("#menuChips").innerHTML = ORDER.map((m) => `<div class="chip" data-mode="${m}"><svg viewBox="0 0 96 68">${diagram(m)}</svg><b>${MODES[m].name}</b></div>`).join("");
  $("#tiles").innerHTML = ORDER.map((m) => `<div class="tile" data-mode="${m}">${m === "shift" ? '<span class="def">PHONE DEFAULT</span>' : m === "shoulder" ? '<span class="def">PC DEFAULT</span>' : ""}<span class="use">✓ IN USE</span><svg viewBox="0 0 96 68">${diagram(m)}</svg><b>${MODES[m].name}</b><span>${MODES[m].tile}</span></div>`).join("");
  document.querySelectorAll("[data-mode]").forEach((el) => el.addEventListener("click", () => setMode(el.dataset.mode, false)));
}
buildPickers();

// ---------------------------------------------------------------- mode / variant
function setMode(m, fromBtn) {
  if (m === S.mode) { refreshUI(); return; }
  const was = S.mode; S.mode = m;
  if (m === "classic") { S.camPitch = -22 * DEG; }
  else if (was === "classic") { S.camPitch = -12 * DEG; }
  clampPitch();
  toast(MODES[m].name, MODES[m].sub);
  refreshUI();
}
let toastT = 0;
function toast(t, s) { $("#toastT").textContent = t; $("#toastS").textContent = s; $("#toast").classList.add("show"); toastT = performance.now() + 1700; }
function setVariant(v) {
  S.variant = v;
  try { localStorage.setItem("camMockVariant", v); } catch (e) { /* private mode */ }
  document.querySelectorAll(".tab").forEach((t) => t.setAttribute("aria-selected", String(t.dataset.variant === v)));
  const V = VARIANTS[v];
  $("#caption").innerHTML = `<div class="box"><h3>${V.title} · optimizes</h3><ul>${V.opt.map((x) => `<li class="opt"><span style="color:var(--fg)">${x}</span></li>`).join("")}</ul></div>` +
    `<div class="box"><h3>trades off</h3><ul>${V.trade.map((x) => `<li class="trade"><span style="color:var(--fg)">${x}</span></li>`).join("")}</ul></div>`;
  closeOv();
}
document.querySelectorAll(".tab").forEach((t) => t.addEventListener("click", () => setVariant(t.dataset.variant)));
document.querySelectorAll("#aimSeg button").forEach((b) => b.addEventListener("click", () => {
  S.classicAim = b.dataset.aim; document.querySelectorAll("#aimSeg button").forEach((x) => x.setAttribute("aria-pressed", String(x === b))); refreshUI();
}));

function refreshUI() {
  const V = VARIANTS[S.variant];
  const showBtn = V.btn && (!V.toggle || S.hudBtn);
  $("#camBtn").style.display = showBtn ? "" : "none";
  $("#camIcon").innerHTML = camIcon(S.mode);
  $("#camLabel").textContent = MODES[S.mode].name;
  $("#dot").style.display = S.mode === "classic" ? "none" : "";
  $("#menuCam").style.display = V.card ? "" : "none";
  $("#menuToggleRow").style.display = V.toggle ? "" : "none";
  $("#setToggleRow").style.display = V.toggle ? "" : "none";
  $("#setPill").style.display = V.card ? "" : "none";
  $("#menuCard").classList.toggle("wide", V.card);
  for (const id of ["#menuSw", "#setSw"]) { $(id).classList.toggle("on", S.hudBtn); $(id).textContent = S.hudBtn ? "ON" : "OFF"; }
  document.querySelectorAll(".chip, .tile").forEach((el) => el.classList.toggle("sel", el.dataset.mode === S.mode));
  const Mo = MODES[S.mode];
  $("#roMode").textContent = Mo.name; $("#roBody").textContent = Mo.body; $("#roMove").textContent = Mo.move; $("#roLook").textContent = Mo.look;
  $("#roAim").textContent = S.mode !== "classic"
    ? "ATTACK dart: body facing + soft aim (30°). Gatling / mortar: the camera look and the crosshair point, so they go where the dot is. Same code as today."
    : S.classicAim === "fix"
      ? "ATTACK dart: body facing + soft aim (unchanged). Gatling / mortar: proposed fix, the dino's facing (mortar lands 25 studs ahead, or on a target in front)."
      : "ATTACK dart: body facing (fine). Gatling / mortar: TODAY'S CODE sends the camera look: orbit the camera sideways and they fly off sideways; the mortar ray from the screen centre lands just past the dino.";
}

// ---------------------------------------------------------------- actions
const fx = [];
function snout() { return S.pos.clone().add(new THREE.Vector3(0, 4.1, 0)).addScaledVector(fwdOf(S.bodyYaw), 4.3); }
function ball(color, r) { const m = new THREE.Mesh(new THREE.SphereGeometry(r, 10, 8), new THREE.MeshBasicMaterial({ color })); scene.add(m); return m; }
function botCenter() { return B.pos.clone().add(new THREE.Vector3(0, 2.6, 0)); }
function softPick(dirFlat, cone, range) {
  const d = botCenter().sub(S.pos); d.y = 0; const L = d.length();
  if (L > range || L < 0.1) return null;
  return Math.acos(Math.max(-1, Math.min(1, d.normalize().dot(dirFlat)))) <= cone * DEG ? botCenter() : null;
}
function hitBot(dmg) { B.hp = Math.max(0, B.hp - dmg); B.flash = 0.18; if (B.hp <= 0) { B.hp = B.max; B.pos.set(S.pos.x + (R() - 0.5) * 30, 0, S.pos.z - 25); } drawBotHp(); }
let lastDart = -9;
function attack() {
  if (S.overlay) return;
  const now = performance.now() / 1000; if (now - lastDart < 0.35) return; lastDart = now;
  const f = fwdOf(S.bodyYaw), from = snout(), tgt = softPick(f, 30, 30);
  const to = tgt || from.clone().addScaledVector(f, 30);
  fx.push({ kind: "dart", m: ball(0x9cff4a, 0.32), from, to, t: 0, T: from.distanceTo(to) / 60, hit: !!tgt, dmg: 6 });
}
function aim() { // what the part aims with in this camera mode
  if (S.mode === "classic" && S.classicAim === "fix") return { look: fwdOf(S.bodyYaw), point: null, body: true };
  const ld = new THREE.Vector3(); camera.getWorldDirection(ld);
  let point = null;
  const o = camera.position.clone(), botC = botCenter();
  const tb = botC.clone().sub(o).dot(ld);
  if (tb > 0 && o.clone().addScaledVector(ld, tb).distanceTo(botC) < 2.4) point = B.pos.clone();
  else if (ld.y < -1e-3) { const t = -o.y / ld.y; if (t < 400) point = o.clone().addScaledVector(ld, t); }
  return { look: ld, point, body: false };
}
function slot(n, pull) {
  if (S.overlay) return;
  const a = aim();
  if (n === 1 && !pull) { // Venom Gatling: flat aim heading, locks a target inside 25 deg, else straight (DiloMovesServer rule)
    const h = a.look.clone(); h.y = 0; if (h.lengthSq() < 1e-6) return; h.normalize();
    { const lock0 = softPick(h, 25, 32); aimGuide(S.pos, lock0 ? B.pos : S.pos.clone().addScaledVector(h, 32), 0x9cff4a); }
    for (let i = 0; i < 6; i++) {
      const from = snout(), lock = softPick(h, 25, 32);
      const to = lock || from.clone().addScaledVector(h, 32).add(new THREE.Vector3((R() - 0.5) * 1.2, (R() - 0.5) * 0.6, 0));
      fx.push({ kind: "dart", m: ball(0x6fe03a, 0.3), from, to, t: -i * 0.1, T: from.distanceTo(to) / 70, hit: !!lock, dmg: 3, live: true });
    }
    cooldown(1, 1.6);
  } else if (n === 2 && !pull) { // Toxin Mortar: aimPoint (crosshair) else heading x reach; clamped to range
    const f = a.look.clone(); f.y = 0; f.normalize();
    let p = a.point;
    if (a.body) { const tg = softPick(f, 30, 40); p = tg ? B.pos.clone() : S.pos.clone().addScaledVector(f, 25); }
    if (!p) p = S.pos.clone().addScaledVector(f, 25);
    const off = p.clone().sub(S.pos); off.y = 0; if (off.length() > 40) off.setLength(40);
    const to = S.pos.clone().add(off); to.y = 0.1;
    const from = S.pos.clone().add(new THREE.Vector3(0, 5, 0));
    aimGuide(S.pos, to, 0xffe36a);
    fx.push({ kind: "mortar", m: ball(0xb3ff5a, 0.55), from, to, t: 0, T: 1.0 });
    const ring = new THREE.Mesh(new THREE.RingGeometry(4.2, 5, 32), new THREE.MeshBasicMaterial({ color: 0xb3ff5a, transparent: true, opacity: 0.6, side: THREE.DoubleSide, depthWrite: false }));
    ring.rotation.x = -Math.PI / 2; ring.position.copy(to).setY(0.08); scene.add(ring);
    fx.push({ kind: "marker", m: ring, t: 0, T: 1.0 });
    cooldown(2, 2.2);
  } else if (n === 1 && pull) { // Spring Jets: move direction, else the camera's flat look (fix: body facing)
    let d = new THREE.Vector3(); const mv = moveInput();
    if (mv.lengthSq() > 0.01) d.copy(mv).normalize(); else { d.copy(a.look); d.y = 0; d.normalize(); }
    S.jets = { dir: d, t: 0 }; S.vy = 14; S.ground = false;
    cooldown(1, 1.2);
  } else { // Sonic Hiss ring
    const ring = new THREE.Mesh(new THREE.RingGeometry(0.8, 1.4, 40), new THREE.MeshBasicMaterial({ color: 0xffe36a, transparent: true, opacity: 0.8, side: THREE.DoubleSide, depthWrite: false }));
    ring.rotation.x = -Math.PI / 2; scene.add(ring); fx.push({ kind: "hiss", m: ring, t: 0, T: 0.6 });
    if (botCenter().distanceTo(S.pos) < 14) hitBot(4);
    cooldown(2, 2.0);
  }
}
function aimGuide(from, to, color) { // flat strip on the ground from the dino to where the shot goes (0.9 s)
  const a = from.clone().setY(0.1), b = to.clone().setY(0.1), L = a.distanceTo(b); if (L < 0.5) return;
  const m = new THREE.Mesh(new THREE.PlaneGeometry(0.7, L), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.75, side: THREE.DoubleSide, depthWrite: false }));
  m.position.copy(a).lerp(b, 0.5);
  m.rotation.set(-Math.PI / 2, 0, Math.atan2(-(b.x - a.x), -(b.z - a.z)));
  scene.add(m); fx.push({ kind: "marker", m, t: 0, T: 0.9 });
}
const cds = { 1: 0, 2: 0 }, cdT = { 1: 1, 2: 1 };
function cooldown(n, t) { cds[n] = t; cdT[n] = t; }
function respawn() { S.pos.set(0, 0, 8); S.bodyYaw = 0; S.camYaw = 0; S.camPitch = (S.mode === "classic" ? -22 : -12) * DEG; S.vy = 0; }

// ---------------------------------------------------------------- simulation
function moveInput() {
  let x = 0, y = 0;
  if (S.stick) { x = S.stick.x; y = S.stick.y; }
  if (S.keys.KeyW || S.keys.ArrowUp) y += 1; if (S.keys.KeyS || S.keys.ArrowDown) y -= 1;
  if (S.keys.KeyD || S.keys.ArrowRight) x += 1; if (S.keys.KeyA || S.keys.ArrowLeft) x -= 1;
  const w = rightOf(S.camYaw).multiplyScalar(x).add(fwdOf(S.camYaw).multiplyScalar(y));
  if (w.length() > 1) w.normalize();
  return w.length() < 0.12 ? new THREE.Vector3() : w;
}
function step(dt) {
  if (!S.overlay) {
    const w = moveInput(), str = w.length();
    let vel = new THREE.Vector3();
    if (S.mode === "classic") { // TurnLimit "move"
      if (str > 0) { S.bodyYaw = turnToward(S.bodyYaw, yawOf(w), TURN * dt); vel = fwdOf(S.bodyYaw).multiplyScalar(SPEED * str); }
    } else { // TurnLimit "aim"
      S.bodyYaw = turnToward(S.bodyYaw, S.camYaw, TURN * dt);
      vel = w.clone().multiplyScalar(SPEED);
    }
    if (S.jets) { S.jets.t += dt; const k2 = Math.max(0, 1 - S.jets.t / 0.35); vel.addScaledVector(S.jets.dir, 46 * k2); if (S.jets.t > 0.35) S.jets = null; }
    S.pos.addScaledVector(vel, dt);
    for (const t of trees) { const dx = S.pos.x - t.x, dz = S.pos.z - t.z, L = Math.hypot(dx, dz), m = t.r + 1.3; if (L < m && L > 1e-3) { S.pos.x = t.x + dx / L * m; S.pos.z = t.z + dz / L * m; } }
    if (S.jumpHeld && S.ground) { S.vy = 24; S.ground = false; }
    S.vy -= 70 * dt; S.pos.y += S.vy * dt;
    if (S.pos.y <= 0) { S.pos.y = 0; S.vy = 0; S.ground = true; }
    S.walk += vel.length() * dt * 0.45;
    // keys turn the camera too (Q / E) for keyboard viewers
    if (S.keys.KeyQ) S.camYaw = wrap(S.camYaw + 120 * DEG * dt);
    if (S.keys.KeyE) S.camYaw = wrap(S.camYaw - 120 * DEG * dt);
    animDino(me, S.walk, vel.length() > 1, S.ground);
    me.root.position.copy(S.pos); me.root.rotation.y = S.bodyYaw;
  }
  // bot wander
  if (B.wait > 0) B.wait -= dt; else {
    const d = B.target.clone().sub(B.pos); d.y = 0;
    if (d.length() < 1.5) { B.wait = 0.6 + R() * 1.2; const a = R() * Math.PI * 2, r = 10 + R() * 18; B.target.set(S.pos.x + Math.cos(a) * r, 0, S.pos.z + Math.sin(a) * r); }
    else { B.yaw = turnToward(B.yaw, yawOf(d), 200 * DEG * dt); B.pos.addScaledVector(fwdOf(B.yaw), 9 * dt); B.walk += 9 * dt * 0.45; }
  }
  animDino(bot, B.walk, B.wait <= 0, true);
  bot.root.position.copy(B.pos); bot.root.rotation.y = B.yaw;
  B.flash = Math.max(0, B.flash - dt);
  bot.root.scale.setScalar(0.9 * (1 + B.flash * 0.6));
  hpSprite.position.copy(B.pos).add(new THREE.Vector3(0, 7.2, 0));
  // fx
  for (let i = fx.length - 1; i >= 0; i--) {
    const f = fx[i]; f.t += dt;
    if (f.t < 0) { f.m.visible = false; continue; } f.m.visible = true;
    const u = Math.min(1, f.t / f.T);
    if (f.kind === "dart") {
      if (f.live && f.hit) f.to = botCenter();
      f.m.position.lerpVectors(f.from, f.to, u);
    } else if (f.kind === "mortar") {
      f.m.position.lerpVectors(f.from, f.to, u); f.m.position.y += Math.sin(u * Math.PI) * (6 + f.from.distanceTo(f.to) * 0.25);
    } else if (f.kind === "marker") { f.m.material.opacity = 0.65 * (1 - u * 0.3); }
    else if (f.kind === "hiss") { f.m.position.copy(S.pos).setY(0.3); f.m.scale.setScalar(1 + u * 9); f.m.material.opacity = 0.8 * (1 - u); }
    else if (f.kind === "cloud") { f.m.material.opacity = 0.35 * (1 - u); f.m.scale.setScalar(1 + u * 0.3); }
    if (u >= 1) {
      if (f.kind === "dart" && f.hit) hitBot(f.dmg);
      if (f.kind === "mortar") {
        const c = new THREE.Mesh(new THREE.CircleGeometry(5, 28), new THREE.MeshBasicMaterial({ color: 0x9cff4a, transparent: true, opacity: 0.35, depthWrite: false }));
        c.rotation.x = -Math.PI / 2; c.position.copy(f.to).setY(0.12); scene.add(c); fx.push({ kind: "cloud", m: c, t: 0, T: 1.6 });
        const d = B.pos.clone().sub(f.to); d.y = 0; if (d.length() < 5.5) hitBot(10);
      }
      scene.remove(f.m); fx.splice(i, 1);
    }
  }
  for (const n of [1, 2]) { cds[n] = Math.max(0, cds[n] - dt); document.querySelector(`#slot${n} .cd`).style.height = (100 * cds[n] / cdT[n]) + "%"; }
  const held = holdAt ? Math.min(1, (performance.now() - holdAt) / 400) : 0;
  $("#disc").style.inset = (50 - held * 50) + "%";
  if (toastT && performance.now() > toastT) { $("#toast").classList.remove("show"); toastT = 0; }
}
function animDino(d, ph, moving, ground) {
  const a = moving && ground ? Math.sin(ph) * 0.65 : (ground ? 0 : 0.35);
  d.legs[0].hip.rotation.x = a; d.legs[1].hip.rotation.x = moving && ground ? -a : -0.2;
  d.legs[0].knee.rotation.x = moving ? Math.max(0, -Math.sin(ph)) * 0.6 : 0; d.legs[1].knee.rotation.x = moving ? Math.max(0, Math.sin(ph)) * 0.6 : 0;
  d.rig.position.y = moving && ground ? Math.abs(Math.cos(ph)) * 0.18 : 0;
  d.tail.forEach((t, i) => { t.rotation.y = Math.sin(ph * 0.5 + i * 0.7) * (moving ? 0.12 : 0.05); t.rotation.x = i === 0 ? -0.08 : 0.06; });
}

// ---------------------------------------------------------------- sizing
function placePills() { // SKILLS 8 px left of MENU (Lab 1.5), SQUAD right edge under SKILLS (SquadHUD 1.0)
  const mw = $("#menuPill").offsetWidth, sw = $("#skills").offsetWidth;
  $("#skills").style.right = (16 + mw + 8) + "px";
  $("#hud .pill.squad").style.right = (16 + mw + 8) + "px";
  return sw;
}
function fit() {
  const fs = document.body.classList.contains("fs-on");
  const pad = fs ? 0 : (innerWidth < 760 ? 16 : 28);
  const availW = fs ? innerWidth : Math.min($("main").clientWidth, 1080) - pad;
  const availH = fs ? innerHeight : Infinity;
  k.v = Math.max(0.3, Math.min(availW / W, availH / H, fs ? 9 : Math.max(0.8, (innerHeight - 40) / H), fs ? 9 : 1.28));
  placePills();
  viewport.style.width = W * k.v + "px"; viewport.style.height = H * k.v + "px";
  screenEl.style.transform = `scale(${k.v})`;
  renderer.setPixelRatio(Math.min(3, (devicePixelRatio || 1) * k.v));
  renderer.setSize(W, H, false);
  canvas.style.width = W + "px"; canvas.style.height = H + "px";
}
addEventListener("resize", fit);
$("#fsBtn").addEventListener("click", () => { document.body.classList.add("fs-on"); fit(); });
$("#fsExit").addEventListener("click", () => { document.body.classList.remove("fs-on"); fit(); });

// ---------------------------------------------------------------- loop
let last = performance.now();
function frame(now) {
  const dt = Math.min(0.05, (now - last) / 1000); last = now;
  if (!S.paused) step(dt);
  placeCamera(); renderer.render(scene, camera);
  requestAnimationFrame(frame);
}
let v0 = "C"; try { v0 = localStorage.getItem("camMockVariant") || "C"; } catch (e) { /* private mode */ }
const hv = (location.hash.match(/v=([ABC])/) || [])[1]; if (hv) v0 = hv;
const hm = (location.hash.match(/m=(classic|shift|shoulder)/) || [])[1];
if (hm) S.mode = hm;
if (S.mode === "classic") S.camPitch = -22 * DEG;
setVariant(v0); fit(); refreshUI();
if (document.fonts && document.fonts.ready) document.fonts.ready.then(placePills);
requestAnimationFrame(frame);

// test hook for the render check (tools/camera_mockup/shot.js)
window.MOCK = {
  S, B, setMode: (m) => setMode(m), setVariant, openOv, closeOv, attack, slot,
  sim(seconds, opts) { // run the simulation without real input: opts {x, y, look (deg/s yaw)}
    const n = Math.round(seconds * 60);
    for (let i = 0; i < n; i++) {
      S.stick = opts && (opts.x || opts.y) ? { id: -1, ox: 0, oy: 0, x: opts.x || 0, y: opts.y || 0 } : null;
      if (opts && opts.look) S.camYaw = wrap(S.camYaw - opts.look * DEG / 60);
      step(1 / 60);
    }
    S.stick = null; placeCamera(); renderer.render(scene, camera);
  },
  render() { placeCamera(); renderer.render(scene, camera); },
};
})();
