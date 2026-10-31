// ---------- data: HerreraModelData 1.2 (parts / segments / joints, exported as-is) ----------
const D = __DATA__;
const STEEL = 0x9aa6b8, DARK = 0x5d6878, BRIGHT = 0xd3dbe6, HOT = 0xff8a2a;
const BASE_SLASH = 8, RAZOR_SLASH = 13, BASE_RUN = 58.5; // SlashDamage 8; Razor Claws I 13; MoveRunSpeed 90 x ArenaSpeedScale 0.65
const STEPS = [
  {k: "I", dmg: 0.10, spd: 0.05}, {k: "II", dmg: 0.20, spd: 0.10},
  {k: "III", dmg: 0.30, spd: 0.15}, {k: "★", dmg: 0.50, spd: 0.25}];
const LOOKS = [
  {id: "A", name: "A · Iron Gauntlets", sub: "steel sleeves, armoured claws",
    why: "The Herrera's own claws, sheathed in steel: longer bright tips, a steel sleeve and cuff on each forearm, a knuckle plate. It still reads as the Herrera's hands, so it's clearly a claw upgrade. The bright claws flash on every rake.",
    parts: "Per arm: forearm sleeve, wrist cuff, elbow plate, knuckle plate, 3 claw sheaths and 3 hook sheaths. 10 parts per arm, steel and dark steel."},
  {id: "B", name: "B · Hook Blades", sub: "one big iron sickle per hand",
    why: "One huge curved iron hook under each hand with a hot-orange edge. It's the most recognizable shape from far away. The rake leaves an orange-edged arc, and the slowdown reads as the weight of the blades.",
    parts: "Per arm: knuckle plate, wrist band, a 3-piece sickle blade with a glowing edge. 7 parts per arm."},
  {id: "C", name: "C · Heavy Knuckles", sub: "iron fists + shoulder plates",
    why: "Blocky iron fists with three forward spikes, a forearm brace and a shoulder plate. It looks the heaviest, so the run slowdown makes sense at a glance. The slash turns into a punchy rake.",
    parts: "Per arm: iron fist block, 3 spikes, forearm brace, shoulder plate. The Herrera's own claws are hidden inside the fist. 6 parts per arm."}];
let look = 0, step = 3, slotted = true, labView = false, slow = false;

// ---------- three ----------
const cv = document.getElementById("cv");
const renderer = new THREE.WebGLRenderer({canvas: cv, antialias: true, preserveDrawingBuffer: true});
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
const scene = new THREE.Scene();
const sky = new THREE.Color(0x8fc6e8), labBg = new THREE.Color(0x141a26);
scene.background = sky;
scene.fog = new THREE.Fog(0x8fc6e8, 30, 70);
const cam = new THREE.PerspectiveCamera(38, 16 / 9, 0.1, 200);
scene.add(new THREE.HemisphereLight(0xeaf6ff, 0x5a6a3a, 0.55));
const sun = new THREE.DirectionalLight(0xffffff, 0.9);
sun.position.set(-6, 14, 9); scene.add(sun);
const rim = new THREE.DirectionalLight(0xffe2b8, 0.35); rim.position.set(8, 5, -10); scene.add(rim);

const world = new THREE.Group(); scene.add(world);
// ground: grass strip with sand stripes (Sandbox island colours)
const ground = new THREE.Mesh(new THREE.PlaneGeometry(160, 40), new THREE.MeshLambertMaterial({color: 0x6fae4a}));
ground.rotation.x = -Math.PI / 2; world.add(ground);
for (let i = -40; i < 40; i++) {
  const t = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.25 + (i * 7919 % 5) * 0.06, 0.5),
    new THREE.MeshLambertMaterial({color: i % 3 ? 0x5c9a3c : 0x86c05a}));
  t.position.set(i * 2.1 + ((i * 31) % 7) * 0.2, 0.12, -3 - ((i * 17) % 9) * 0.6); world.add(t);
  if (i % 4 === 0) { const r = t.clone(); r.material = new THREE.MeshLambertMaterial({color: 0x9c9284}); r.scale.set(1.6, 1.8, 1.4); r.position.z = 4 + ((i * 13) % 5); world.add(r); }
}
const sand = new THREE.Mesh(new THREE.PlaneGeometry(160, 3), new THREE.MeshLambertMaterial({color: 0xc9b47a}));
sand.rotation.x = -Math.PI / 2; sand.position.set(0, 0.01, -7); world.add(sand);

// ---------- rig ----------
function cfm(a) { const m = new THREE.Matrix4(); m.set(a[3], a[4], a[5], a[0], a[6], a[7], a[8], a[1], a[9], a[10], a[11], a[2], 0, 0, 0, 1); return m; }
const segs = {}, partInfo = {};
const dino = new THREE.Group(); world.add(dino);
const matCache = {};
function mat(hex, glow) {
  const key = hex + (glow ? "g" : "");
  if (!matCache[key]) matCache[key] = glow ? new THREE.MeshBasicMaterial({color: hex})
    : new THREE.MeshLambertMaterial({color: hex});
  return matCache[key];
}
for (const s of D.segs) {
  const rootInv = cfm(s.root).invert();
  segs[s.n] = {world: new THREE.Matrix4(), parts: []};
  for (const p of s.parts) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(p.s[0], p.s[1], p.s[2]), mat(parseInt(p.c, 16)));
    m.matrixAutoUpdate = false;
    const local = rootInv.clone().multiply(cfm(p.cf));
    dino.add(m);
    const info = {mesh: m, local, seg: s.n, size: p.s};
    segs[s.n].parts.push(info); partInfo[p.n] = info;
  }
}
const joints = D.joints.map(j => ({n: j.n, p0: j.p0, p1: j.p1, c0: cfm(j.c0), c1inv: cfm(j.c1).invert()}));
const rad = THREE.MathUtils.degToRad;
const tmpE = new THREE.Euler(), tmpM = new THREE.Matrix4();
function rot(p, y, r) { tmpE.set(rad(r), rad(y), rad(p), "ZYX"); return new THREE.Matrix4().makeRotationFromEuler(tmpE); }

// ScurryPose 1.0 defaults + angles(phase) (ported 1:1)
const S = {BodyPitch: -24, Neck: 6, Head: 16, Jaw: -3, ArmTuck: 30, LegTuck: 48, Knee: -48, Foot: 24,
  Tail: [26, 4, 8, 14, 20], ArmSwing: 34, ArmSprawl: 18, ArmLiftSprawl: 10, LegSwing: 30, LegSprawl: 16,
  KneeLift: -34, FootLift: 20, BodyYaw: 11, BodyRoll: 4, NeckYaw: -9, HeadYaw: -6, TailWhip: 8, TailWhipGrow: 4,
  TailLag: 0.75, Stride: 3.2, MaxHz: 5};
const JN = ["RootJoint", "Neck", "Head", "Jaw", "ArmL", "ArmR", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5",
  "LegL", "LegR", "KneeL", "KneeR", "AnkleL", "AnkleR"];
function blank() { const o = {body: [0, 0, 0]}; JN.forEach(n => o[n] = [0, 0, 0]); return o; }
function add(o, n, p, y, r) { o[n][0] += p; o[n][1] += (y || 0); o[n][2] += (r || 0); }
function scurry(phase, amt) {
  const o = blank();
  add(o, "RootJoint", S.BodyPitch); add(o, "Neck", S.Neck); add(o, "Head", S.Head); add(o, "Jaw", S.Jaw);
  add(o, "ArmL", S.ArmTuck); add(o, "ArmR", S.ArmTuck); add(o, "LegL", S.LegTuck); add(o, "LegR", S.LegTuck);
  add(o, "KneeL", S.Knee); add(o, "KneeR", S.Knee); add(o, "AnkleL", S.Foot); add(o, "AnkleR", S.Foot);
  for (let i = 1; i <= 5; i++) add(o, "Tail" + i, S.Tail[i - 1]);
  const pa = {ArmL: phase, LegR: phase, ArmR: phase + Math.PI, LegL: phase + Math.PI};
  for (const n in pa) {
    const sw = Math.sin(pa[n]) * amt, lift = Math.max(0, Math.cos(pa[n])) * amt, side = n.endsWith("L") ? 1 : -1;
    if (n.startsWith("Arm")) add(o, n, S.ArmSwing * sw, 0, -side * (S.ArmSprawl + S.ArmLiftSprawl * lift));
    else { const sf = n.slice(-1); add(o, n, S.LegSwing * sw, 0, -side * S.LegSprawl); add(o, "Knee" + sf, S.KneeLift * lift); add(o, "Ankle" + sf, S.FootLift * lift); }
  }
  const w = Math.sin(phase) * amt;
  o.body[1] = S.BodyYaw * w; o.body[2] = S.BodyRoll * Math.sin(phase + Math.PI / 2) * amt;
  add(o, "Neck", 0, S.NeckYaw * w); add(o, "Head", 0, S.HeadYaw * w);
  for (let i = 1; i <= 5; i++) add(o, "Tail" + i, 0, (S.TailWhip + i * S.TailWhipGrow) * Math.sin(phase - i * S.TailLag) * amt);
  return o;
}

// ---------- the iron (built on the model's own parts, like MechaLegsServer: anchor.CFrame * offset) ----------
const equip = [];
function piece(anchor, size, pos, rotd, color, glow) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(size[0], size[1], size[2]), glow ? mat(color, true)
    : new THREE.MeshLambertMaterial({color, emissive: 0x000000}));
  m.matrixAutoUpdate = false; dino.add(m);
  const off = new THREE.Matrix4().compose(new THREE.Vector3(pos[0], pos[1], pos[2]),
    new THREE.Quaternion().setFromEuler(new THREE.Euler(rad(rotd[0] || 0), rad(rotd[1] || 0), rad(rotd[2] || 0))), new THREE.Vector3(1, 1, 1));
  equip.push({mesh: m, anchor, off, glow: !!glow, base: color});
}
const hidden = new Set();
function buildLook() {
  equip.forEach(e => { dino.remove(e.mesh); e.mesh.geometry.dispose(); });
  equip.length = 0; hidden.clear();
  if (!slotted) return;
  for (const sd of ["L", "R"]) {
    const A = "Arm" + sd, z = sd === "L" ? 1 : -1; // outward = local +Z on the left arm
    if (look === 0) {
      piece(A + "_fore", [0.58, 1.05, 0.54], [0, -0.08, 0], [0, 0, 0], STEEL);
      piece(A + "_fore", [0.68, 0.24, 0.64], [0, -0.58, 0], [0, 0, 0], DARK);
      piece(A + "_fore", [0.62, 0.16, 0.58], [0, 0.42, 0], [0, 0, 0], DARK);
      for (const yy of [-0.25, 0.1]) piece(A + "_fore", [0.1, 0.1, 0.1], [0.3, yy, 0.27 * z], [0, 0, 0], BRIGHT);
      piece(A + "_hand", [0.74, 0.22, 0.6], [0, 0.16, 0], [0, 0, 0], STEEL);
      for (let i = 1; i <= 3; i++) {
        piece(A + "_claw" + i, [0.2, 0.9, 0.17], [0, -0.2, 0], [0, 0, 0], BRIGHT);
        piece(A + "_hook" + i, [0.17, 0.66, 0.15], [0, -0.22, 0], [0, 0, 0], BRIGHT);
      }
    } else if (look === 1) {
      piece(A + "_hand", [0.72, 0.24, 0.6], [0, 0.15, 0], [0, 0, 0], DARK);
      piece(A + "_fore", [0.5, 0.26, 0.48], [0, -0.52, 0], [0, 0, 0], STEEL);
      // sickle: a chain of boxes along a curve that runs forward from the hand and hooks down (hand local +X = forward)
      const pts = [[0.05, 0.0], [0.75, 0.12], [1.35, 0.0], [1.75, -0.35], [1.9, -0.8]], th = [0.3, 0.26, 0.2, 0.15];
      for (let i = 0; i < pts.length - 1; i++) {
        const [x0, y0] = pts[i], [x1, y1] = pts[i + 1], len = Math.hypot(x1 - x0, y1 - y0), a = Math.atan2(y1 - y0, x1 - x0);
        const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2, nx = Math.sin(a), ny = -Math.cos(a); // the inner (lower) side
        piece(A + "_hand", [len + 0.1, th[i], 0.13], [cx, cy, 0], [0, 0, a * 180 / Math.PI], STEEL);
        piece(A + "_hand", [len + 0.08, 0.07, 0.15], [cx + nx * th[i] / 2, cy + ny * th[i] / 2, 0], [0, 0, a * 180 / Math.PI], HOT, true);
      }
    } else {
      piece(A + "_hand", [1.05, 0.74, 0.9], [0.1, -0.06, 0], [0, 0, 0], DARK);
      for (const sz of [-0.28, 0, 0.28]) piece(A + "_hand", [0.5, 0.2, 0.2], [0.82, -0.08, sz], [0, 0, 0], BRIGHT);
      piece(A + "_fore", [0.56, 0.8, 0.52], [0, -0.12, 0], [0, 0, 0], STEEL);
      piece(A + "_upper", [0.74, 0.62, 0.7], [0, 0.32, 0.08 * z], [0, 0, 0], STEEL);
      piece(A + "_upper", [0.8, 0.14, 0.76], [0, 0.02, 0.08 * z], [0, 0, 0], DARK);
      for (let i = 1; i <= 3; i++) { hidden.add(A + "_claw" + i); hidden.add(A + "_hook" + i); }
    }
  }
  for (const n in partInfo) partInfo[n].mesh.visible = !hidden.has(n);
}

// ---------- the bot (stand-in target: a simple block T-Rex bot) ----------
const bot = new THREE.Group(); world.add(bot);
const botMat = new THREE.MeshLambertMaterial({color: 0x7f8c9e});
function bb(s, p, c) { const m = new THREE.Mesh(new THREE.BoxGeometry(...s), c ? new THREE.MeshLambertMaterial({color: c}) : botMat); m.position.set(...p); bot.add(m); return m; }
const botBody = new THREE.Group(); bot.add(botBody);
[[[2.6, 1.8, 1.6], [0, 2.6, 0]], [[1.6, 1.3, 1.3], [1.7, 3.5, 0]], [[1.2, 0.5, 1.1], [2.2, 3.0, 0]], [[2.4, 0.6, 0.6], [-2.2, 2.6, 0]],
 [[0.6, 2.0, 0.6], [0.2, 1.0, 0.45]], [[0.6, 2.0, 0.6], [0.2, 1.0, -0.45]]].forEach(([s, p]) => { const m = new THREE.Mesh(new THREE.BoxGeometry(...s), botMat); m.position.set(...p); botBody.add(m); });
const eye = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.2, 0.2), new THREE.MeshBasicMaterial({color: 0xffd23a})); eye.position.set(2.2, 3.8, 0.66); botBody.add(eye);
const BOT_X = 0; bot.position.set(BOT_X, 0, -0.6); bot.rotation.y = Math.PI; // faces the incoming dino
let botHp = 200, botFlash = 0, botKnock = 0;

// ---------- FX ----------
const fx = [];
function spark(pos, color, n, spd) {
  for (let i = 0; i < n; i++) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.12, 0.12), new THREE.MeshBasicMaterial({color, transparent: true}));
    m.position.copy(pos); world.add(m);
    const a = Math.random() * Math.PI * 2, u = Math.random() * 0.8 + 0.2;
    fx.push({m, v: new THREE.Vector3(Math.cos(a) * spd * u + 2, Math.random() * spd, Math.sin(a) * spd * u), life: 0.45, max: 0.45, g: -22});
  }
}
function arc(pos, color, edge) {
  const g = new THREE.RingGeometry(1.6, 2.3, 24, 1, -0.4, 2.6);
  const m = new THREE.Mesh(g, new THREE.MeshBasicMaterial({color, transparent: true, side: THREE.DoubleSide, depthWrite: false}));
  m.position.copy(pos); m.rotation.y = 0; world.add(m);
  fx.push({m, v: new THREE.Vector3(6, 0, 0), life: 0.22, max: 0.22, g: 0, grow: 1.8});
  if (edge) { const e = new THREE.Mesh(new THREE.RingGeometry(2.25, 2.45, 24, 1, -0.4, 2.6), new THREE.MeshBasicMaterial({color: edge, transparent: true, side: THREE.DoubleSide, depthWrite: false}));
    e.position.copy(pos); world.add(e); fx.push({m: e, v: new THREE.Vector3(6, 0, 0), life: 0.22, max: 0.22, g: 0, grow: 1.8}); }
}
function dust(pos, big) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.3, 0.3), new THREE.MeshLambertMaterial({color: 0xd8cfb4, transparent: true}));
  m.position.copy(pos); world.add(m);
  fx.push({m, v: new THREE.Vector3(-2, 1.2, (Math.random() - .5) * 2), life: big ? 0.5 : 0.35, max: big ? 0.5 : 0.35, g: -2, grow: big ? 2.2 : 1.2});
}
const stage = document.getElementById("stage");
const pops = [];
function pop(text, sub, color, size, worldPos) {
  const el = document.createElement("div"); el.className = "pop"; el.style.color = color; el.style.fontSize = size + "px";
  el.innerHTML = text + (sub ? "<small>" + sub + "</small>" : ""); stage.appendChild(el);
  pops.push({el, p: worldPos.clone(), t: 0, life: 0.9, size});
}

// ---------- UI ----------
const $ = id => document.getElementById(id);
function pctTxt(x) { return Math.round(x * 100) + "%"; }
function dmgFor(base, si) { return Math.floor(base * (si < 0 ? 1 : 1 + STEPS[si].dmg) + 0.5); }
function runFor(si) { return si < 0 ? BASE_RUN : BASE_RUN * (1 - STEPS[si].spd); }
function curStep() { return slotted ? step : -1; }
function drawUI() {
  $("looks").innerHTML = ""; $("steps").innerHTML = "";
  LOOKS.forEach((L, i) => { const b = document.createElement("button"); b.className = "tab"; b.setAttribute("aria-pressed", i === look);
    b.innerHTML = L.name + "<small>" + L.sub + "</small>"; b.onclick = () => { look = i; buildLook(); drawUI(); }; $("looks").appendChild(b); });
  STEPS.forEach((st, i) => { const b = document.createElement("button"); b.className = "tab step"; b.setAttribute("aria-pressed", i === step);
    b.innerHTML = st.k + "<small>+" + pctTxt(st.dmg) + " / −" + pctTxt(st.spd) + "</small>"; b.onclick = () => { step = i; drawUI(); }; $("steps").appendChild(b); });
  $("lookName").textContent = LOOKS[look].name; $("lookWhy").textContent = LOOKS[look].why; $("lookParts").textContent = LOOKS[look].parts;
  $("stepList").innerHTML = STEPS.map((st, i) => `<li class="${i === step ? "cur" : ""}"><b>${st.k}</b><span>Slash damage +${pctTxt(st.dmg)}, run ${pctTxt(st.spd)} slower</span></li>`).join("");
  $("numRows").innerHTML = `<tr class="${slotted ? "" : "cur"}"><td>not slotted</td><td>${BASE_SLASH}</td><td>${RAZOR_SLASH}</td><td>${BASE_RUN.toFixed(1)}</td></tr>` +
    STEPS.map((st, i) => `<tr class="${slotted && i === step ? "cur" : ""}"><td>${st.k}</td><td class="up">${dmgFor(BASE_SLASH, i)}</td><td class="up">${dmgFor(RAZOR_SLASH, i)}</td><td class="dn">${runFor(i).toFixed(1)}</td></tr>`).join("");
  const si = curStep();
  $("hud").innerHTML = `<div>SLASH <b>${dmgFor(BASE_SLASH, si)}</b> ${si >= 0 ? `<span style="color:var(--yellow)">(+${pctTxt(STEPS[si].dmg)})</span>` : ""}</div>` +
    `<div>RUN <b>${runFor(si).toFixed(1)}</b> ${si >= 0 ? `<span class="dn">(−${pctTxt(STEPS[si].spd)})</span>` : ""}</div>`;
  $("bar").innerHTML = `<div class="tile" id="tSlash"><span class="k">ATK</span><span class="pips"><i></i><i></i></span>SLASH</div>` +
    `<div class="tile"><span class="k">SPC</span>JUMP</div>` +
    (slotted ? `<div class="tile iron" id="tIron"><span class="k">R</span>IRON<br>CLAW</div>` : `<div class="tile empty"><span class="k">R</span>—</div>`) +
    `<div class="tile empty"><span class="k">C</span>—</div>`;
  $("slotBtn").textContent = "Slotted: " + (slotted ? "ON" : "OFF"); $("slotBtn").setAttribute("aria-pressed", slotted);
  $("viewBtn").setAttribute("aria-pressed", labView); $("slowBtn").setAttribute("aria-pressed", slow);
}
$("slotBtn").onclick = () => { slotted = !slotted; buildLook(); drawUI(); };
$("viewBtn").onclick = () => { labView = !labView; resetRun(); drawUI(); };
$("slowBtn").onclick = () => { slow = !slow; drawUI(); };
$("slashBtn").onclick = () => { if (labView) { labView = false; drawUI(); } resetRun(BOT_X - 9); };

// ---------- the run / slash loop ----------
const FWD = new THREE.Vector3(1, 0, 0);
let state, st;
function resetRun(x) { state = "run"; st = {t: 0, x: x !== undefined ? x : BOT_X - 24, phase: 0, hit: false, slashT: 0, lastStepSide: 0, out: 0}; }
resetRun();
const WINDUP = 0.12, DASH = 0.30, DASH_LEN = 12.5, RECOVER = 0.2;
let hitStop = 0, shake = 0, glint = 0, camX = BOT_X - 8;

function poseNow(dt) {
  const si = curStep();
  const speed = runFor(si) / 2; // model units (the game model is x2)
  let o, k = 0;
  if (labView) { o = scurry(0, 0); add(o, "ArmL", 20); add(o, "ArmR", -10); return o; }
  if (state === "run" || state === "out") {
    st.phase += Math.min(S.MaxHz * 2 * Math.PI, speed / S.Stride * 2 * Math.PI) * dt;
    o = scurry(st.phase, 1);
  } else {
    o = scurry(st.phase, 0.35);
  }
  if (state === "windup") { // cock both claws back, crouch (arcade anticipation)
    const w = Math.min(1, st.slashT / WINDUP);
    add(o, "RootJoint", -10 * w); add(o, "ArmL", -55 * w, 0, 10 * w); add(o, "ArmR", -35 * w, 0, -10 * w); add(o, "Neck", -8 * w); add(o, "Jaw", -10 * w);
  }
  if (state === "dash" || state === "recover") { // SlashPose 1.0 "ground" rake, pushed harder for the iron
    const u = state === "dash" ? Math.min(1, st.slashT / DASH) : 1;
    k = u > 0.2 && u < 0.8 ? Math.sin(Math.PI * (u - 0.2) / 0.6) : 0;
    const f = state === "recover" ? Math.max(0, 1 - st.slashT / RECOVER) : 1;
    const amp = slotted ? 1.35 : 1;
    add(o, "ArmL", (60 * k * amp - 55 * (1 - u) * f), 0, -20 * k);
    add(o, "ArmR", (-40 * k * amp - 35 * (1 - u) * f), 0, 20 * k);
    add(o, "Jaw", -18 * k - 6); add(o, "RootJoint", -6 * f);
    o.body[1] += 14 * Math.sin(Math.PI * u) * f; // body twist with the rake
  }
  return o;
}

const corner = new THREE.Vector3();
function applyPose(o, rootPos, yaw) {
  const hrp = new THREE.Matrix4().makeRotationY(yaw);
  const W = {HRP: hrp};
  for (const j of joints) {
    const v = o[j.n] || [0, 0, 0];
    let pose = rot(v[0], v[1], v[2]);
    if (j.n === "RootJoint") pose = rot(o.body[0], o.body[1], o.body[2]).multiply(pose);
    W[j.p1] = W[j.p0].clone().multiply(j.c0).multiply(pose).multiply(j.c1inv);
  }
  // ground fit: the lowest corner of any visible body part sits on the ground
  let minY = Infinity;
  for (const n in segs) {
    for (const p of segs[n].parts) {
      const m = W[n].clone().multiply(p.local);
      p.mesh.matrix.copy(m);
      if (!p.mesh.visible) continue;
      const h = p.size;
      for (let i = 0; i < 8; i++) {
        corner.set((i & 1 ? .5 : -.5) * h[0], (i & 2 ? .5 : -.5) * h[1], (i & 4 ? .5 : -.5) * h[2]).applyMatrix4(m);
        if (corner.y < minY) minY = corner.y;
      }
    }
  }
  const lift = new THREE.Matrix4().makeTranslation(rootPos.x, -minY + rootPos.y, rootPos.z);
  for (const n in segs) for (const p of segs[n].parts) p.mesh.matrix.premultiply(lift);
  for (const e of equip) {
    const a = partInfo[e.anchor];
    e.mesh.matrix.copy(a.mesh.matrix).multiply(e.off);
  }
  return W;
}

const TRAIL_LIFE = 0.11, trails = {};
const TIP = {0: [[0, -0.55, 0], [0, -0.2, 0], "_claw2"], 1: [[1.9, -0.8, 0], [1.78, -0.42, 0], "_hand"], 2: [[0.95, -0.08, 0], [0.4, -0.08, 0], "_hand"]};
for (const sd of ["L", "R"]) {
  const max = 40, geo = new THREE.BufferGeometry();
  geo.setAttribute("position", new THREE.BufferAttribute(new Float32Array(max * 2 * 3), 3));
  geo.setAttribute("tcol", new THREE.BufferAttribute(new Float32Array(max * 2 * 3), 3));
  geo.setAttribute("talpha", new THREE.BufferAttribute(new Float32Array(max * 2), 1));
  const idx = []; for (let i = 0; i < max - 1; i++) { const a = i * 2; idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2); }
  geo.setIndex(idx);
  const mesh = new THREE.Mesh(geo, new THREE.ShaderMaterial({side: THREE.DoubleSide, transparent: true, depthWrite: false,
    vertexShader: "attribute vec3 tcol; attribute float talpha; varying vec3 vc; varying float va; void main(){ vc = tcol; va = talpha; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }",
    fragmentShader: "varying vec3 vc; varying float va; void main(){ gl_FragColor = vec4(vc, va); }"}));
  mesh.frustumCulled = false; scene.add(mesh);
  trails[sd] = {mesh, hist: [], max};
}
function updateTrail(sd, on, dt) {
  const T = trails[sd], cfg = TIP[look];
  for (const h of T.hist) h.age += dt;
  while (T.hist.length && T.hist[0].age > TRAIL_LIFE) T.hist.shift();
  if (on && dt > 0) {
    const m = partInfo["Arm" + sd + cfg[2]].mesh.matrix;
    T.hist.push({a: new THREE.Vector3(...cfg[0]).applyMatrix4(m), b: new THREE.Vector3(...cfg[1]).applyMatrix4(m), age: 0});
    if (T.hist.length > T.max) T.hist.shift();
  }
  const pos = T.mesh.geometry.attributes.position, col = T.mesh.geometry.attributes.tcol, al = T.mesh.geometry.attributes.talpha, n = T.hist.length;
  const c0 = new THREE.Color(look === 1 ? HOT : 0xdfe8f5), c1 = new THREE.Color(0xffffff);
  for (let i = 0; i < T.max; i++) {
    const h = T.hist[Math.min(i, n - 1)];
    if (!h) { pos.setXYZ(i * 2, 0, -50, 0); pos.setXYZ(i * 2 + 1, 0, -50, 0); al.setX(i * 2, 0); al.setX(i * 2 + 1, 0); continue; }
    const f = Math.max(0, 1 - h.age / TRAIL_LIFE) * (i < n ? 1 : 0); // fades to nothing (additive black = invisible)
    pos.setXYZ(i * 2, h.a.x, h.a.y, h.a.z); pos.setXYZ(i * 2 + 1, h.b.x, h.b.y, h.b.z);
    const tip = c1.clone().lerp(c0, 0.95);
    col.setXYZ(i * 2, tip.r, tip.g, tip.b); col.setXYZ(i * 2 + 1, c0.r, c0.g, c0.b);
    al.setX(i * 2, 0.9 * f); al.setX(i * 2 + 1, 0.15 * f);
  }
  pos.needsUpdate = true; col.needsUpdate = true; al.needsUpdate = true;
  T.mesh.visible = n > 1 && !labView;
}
function handWorld(sd) { const m = partInfo["Arm" + sd + "_hand"].mesh.matrix; return new THREE.Vector3().setFromMatrixPosition(m); }

let last = performance.now(), auto = 0;
function frame(now) {
  let dt = Math.min(0.05, (now - last) / 1000); last = now;
  if (slow) dt *= 0.3;
  if (hitStop > 0) { hitStop -= dt; dt = 0; }
  const si = curStep();
  const speed = runFor(si) / 2;
  st.t += dt;
  if (!labView) {
    if (state === "run") {
      st.x += speed * dt;
      if (st.x >= BOT_X - 8.5) { state = "windup"; st.slashT = 0; glint = 1; flashTile(); }
    } else if (state === "windup") {
      st.slashT += dt; st.x += speed * 0.25 * dt;
      if (st.slashT >= WINDUP) { state = "dash"; st.slashT = 0; st.dashFrom = st.x; }
    } else if (state === "dash") {
      st.slashT += dt;
      const u = Math.min(1, st.slashT / DASH);
      st.x = st.dashFrom + DASH_LEN * (1 - Math.pow(1 - u, 2));
      if (!st.hit && st.x >= BOT_X - 1.0) onHit();
      if (u >= 1) { state = "recover"; st.slashT = 0; }
    } else if (state === "recover") {
      st.slashT += dt; st.x += speed * 0.5 * dt;
      if (st.slashT >= RECOVER) { state = "out"; }
    } else if (state === "out") {
      st.x += speed * dt; st.out += dt;
      if (st.out > 0.9) resetRun();
    }
  }
  // footfall dust (heavier with the iron)
  if ((state === "run" || state === "out") && !labView) {
    const side = Math.sin(st.phase) > 0 ? 1 : -1;
    if (side !== st.lastStepSide) { st.lastStepSide = side; dust(new THREE.Vector3(st.x - 0.5, 0.15, side * 0.4), slotted && step >= 2); }
  }
  const o = poseNow(dt);
  applyPose(o, new THREE.Vector3(labView ? 0 : st.x, 0, labView ? 0 : 0), -Math.PI / 2 + (labView ? (now / 1000) * 0.6 : 0));
  // blade-tip trails (like a Roblox Trail between two attachments on each blade: mid-blade and tip)
  const swinging = slotted && (state === "windup" || state === "dash" || state === "recover");
  for (const sd of ["L", "R"]) updateTrail(sd, swinging, dt);
  // the iron glint (windup) and hit flash
  glint = Math.max(0, glint - dt * 4);
  for (const e of equip) if (!e.glow) e.mesh.material.emissive.setScalar(glint * 0.9);
  // bot reaction
  botFlash = Math.max(0, botFlash - dt * 5); botKnock = Math.max(0, botKnock - dt * 3);
  botMat.emissive = botMat.emissive || new THREE.Color(); botMat.emissive.setRGB(botFlash, botFlash * 0.2, botFlash * 0.1);
  botBody.rotation.z = -botKnock * 0.35; botBody.position.x = -botKnock * 0.6;
  bot.visible = !labView; ground.visible = !labView; world.children.forEach(c => { if (c !== dino && c !== bot && c !== ground && !c.userData.fx) c.visible = !labView; });
  dino.visible = true;
  // fx
  for (let i = fx.length - 1; i >= 0; i--) {
    const f = fx[i]; f.life -= dt;
    if (f.life <= 0) { world.remove(f.m); f.m.geometry.dispose(); fx.splice(i, 1); continue; }
    f.v.y += f.g * dt; f.m.position.addScaledVector(f.v, dt);
    const a = f.life / f.max; f.m.material.opacity = a;
    if (f.grow) f.m.scale.setScalar(1 + (1 - a) * (f.grow - 1));
  }
  // camera
  scene.background = labView ? labBg : sky; scene.fog.near = labView ? 1000 : 30; scene.fog.far = labView ? 2000 : 70;
  if (labView) {
    cam.position.set(4, 4.5, 15); cam.lookAt(0, 1.3, 0); cam.fov = 28;
  } else {
    camX += ((st.x + 2.5) - camX) * Math.min(1, dt * 5 + (dt === 0 ? 0 : 0));
    const sx = (Math.random() - .5) * shake, sy = (Math.random() - .5) * shake;
    shake = Math.max(0, shake - (dt || 0.016) * 3);
    cam.position.set(camX + 6 + sx, 5 + sy, 16); cam.lookAt(camX, 1.3, 0); cam.fov = 38;
  }
  cam.updateProjectionMatrix();
  renderer.render(scene, cam);
  // pops + bot bar
  const r = cv.getBoundingClientRect();
  for (let i = pops.length - 1; i >= 0; i--) {
    const p = pops[i]; p.t += (slow ? 0.3 : 1) * 0.016;
    const v = p.p.clone(); v.y += p.t * 2.2; v.project(cam);
    const sc = p.t < 0.08 ? 1.7 - p.t * 8 : 1;
    p.el.style.left = ((v.x + 1) / 2 * r.width) + "px"; p.el.style.top = ((1 - v.y) / 2 * r.height) + "px";
    p.el.style.transform = `translate(-50%,-50%) scale(${sc})`; p.el.style.opacity = Math.min(1, (p.life - p.t) * 3);
    if (p.t > p.life) { p.el.remove(); pops.splice(i, 1); }
  }
  const hb = new THREE.Vector3(BOT_X, 5.0, -0.6).project(cam);
  $("hp").style.display = labView ? "none" : "block";
  $("hp").style.left = ((hb.x + 1) / 2 * r.width) + "px"; $("hp").style.top = ((1 - hb.y) / 2 * r.height) + "px";
  $("hpfill").style.width = (botHp / 2) + "%";
  requestAnimationFrame(frame);
}
function flashTile() { const t = $("tIron"); if (t) { t.classList.add("flash"); setTimeout(() => t.classList.remove("flash"), 220); } }
function onHit() {
  st.hit = true;
  const si = curStep();
  const d = dmgFor(BASE_SLASH, si);
  botHp -= d; if (botHp < 40) botHp = 200;
  botFlash = 1; botKnock = slotted ? 1 : 0.5;
  hitStop = slotted ? 0.09 : 0.04; shake = 0; // no camera shake (Kepu 2026-10-31)
  const at = new THREE.Vector3(BOT_X, 3.2, -0.6);
  spark(at, slotted ? (look === 1 ? HOT : 0xffe08a) : 0xffffff, slotted ? 18 : 6, slotted ? 9 : 5);
  if (slotted) spark(at, 0xffffff, 6, 12);
  pop(String(d), slotted ? "CLANG!" : "", slotted ? "#ffc832" : "#ffffff", slotted ? 40 : 28, new THREE.Vector3(BOT_X, 4.6, -0.6));
  const t0 = setTimeout(() => { pop("-3", "", "#ff5a4a", 18, new THREE.Vector3(BOT_X + 2.2, 3.6, -0.6)); botHp -= 3; }, 1000);
}
function resize() { const w = stage.clientWidth; renderer.setSize(w, w * 9 / 16, false); cam.aspect = 16 / 9; }
window.addEventListener("resize", resize);
buildLook(); drawUI(); resize(); requestAnimationFrame(frame);
