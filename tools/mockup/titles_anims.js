// titles_anims.js v0.1 — the 8 victory titles. Each: setup(c) builds its props, update(c, t, dt) drives the dino(s),
// props, FX and camera. Every distance is in U (the dino's size: max(height, 0.55 × length)) so any dino fits any title.
let hitStop = 0;
function at(c, label, t0, fn) { if (c.t >= t0 && !c.fired[label]) { c.fired[label] = 1; fn(); } }
function drive(r, target, dt, layer, direct) {
  let A;
  if (direct) { snapSprings(r, target); A = target; } else A = springStep(r, target, dt);
  if (layer) A = addPose(A, layer);
  poseRig(r, A);
}
function yawTo(from, to) { return Math.atan2(-(to.x - from.x), -(to.z - from.z)); }
function textSprite(text, color, size, stroke) {
  const tex = canvasTex(512, 160, (x) => { x.font = "900 112px 'Trebuchet MS', sans-serif"; x.textAlign = "center"; x.lineJoin = "round"; x.lineWidth = 16; x.strokeStyle = stroke || "#2a1504"; x.strokeText(text, 256, 118); x.fillStyle = color; x.fillText(text, 256, 118); });
  const s = new THREE.Sprite(new THREE.SpriteMaterial({map: tex, transparent: true, depthTest: false})); s.renderOrder = 6; s.scale.set(size * 3.2, size, 1); return s;
}
function orbitStars(c, r, n, life, rad_) { // dizzy stars circling over the head (follow the head)
  for (let i = 0; i < n; i++) { const s = sprite(T.star, 0xffffff, r.U * 0.09, false); s.renderOrder = 4;
    addFx(s, life, (o, u) => { const h = headTop(r), a = c.t * 7 + i * Math.PI * 2 / n; o.position.set(h.x + Math.cos(a) * r.U * (rad_ || 0.16), h.y + r.U * 0.07 + Math.sin(a * 2) * r.U * 0.02, h.z + Math.sin(a) * r.U * (rad_ || 0.16)); o.material.opacity = u > 0.8 ? (1 - u) / 0.2 : 1; }); }
}
function peckPoint(r, pose) { // where the mouth tip lands in a given pose (rig at the origin)
  const s = {pos: r.pos.clone(), yaw: r.yaw}; r.pos.set(0, 0, 0); r.yaw = 0; poseRig(r, pose); const p = mouthPt(r); r.pos.copy(s.pos); r.yaw = s.yaw; poseRig(r, {}); return p;
}
function meteorMesh(radius, hot) {
  const g = new THREE.Group();
  const m = new THREE.Mesh(new THREE.IcosahedronGeometry(radius, 1), new THREE.MeshLambertMaterial({color: 0x5a4a3e, emissive: hot ? 0x6a2000 : 0x2a0a00, flatShading: true}));
  m.castShadow = true; g.add(m);
  const glow = sprite(T.fire, 0xffa040, radius * 4.2, true); g.add(glow);
  const light = new THREE.PointLight(0xff8a3a, 1.4, radius * 30); g.add(light);
  g.userData = {rock: m, glow, light}; return g;
}
function trail(p, U, size, n) { for (let i = 0; i < (n || 2); i++) { const s = sprite(T.fire, i % 2 ? 0xffd070 : 0xff6a20, size, true); s.position.copy(p).add(V((Math.random() - .5) * size * .4, (Math.random() - .5) * size * .4, (Math.random() - .5) * size * .4));
  addFx(s, 0.35 + Math.random() * 0.2, (o, u) => { o.scale.setScalar(size * (1 - u * 0.6)); o.material.opacity = 0.9 * (1 - u); }); }
  if (Math.random() < 0.6) puff(p.clone(), V(0, U * 0.2, 0), size * 0.8, 0x5a5048, 0.9, 1.8, 0.55); }

const TITLES = [];
// =====================================================================================================================
// 1 · APEX PREDATOR — stalks up a mound of bones and red-team scrap, hops on top, ROARS (shockwaves, leaves blown off,
// bones rattling), chest out.
TITLES.push({
  id: "apex", name: "APEX PREDATOR", kind: "good", cap: "Top of the food chain", stat: "11 KILLS", len: 5.4,
  rule: "Most kills on the team (at least 3)", src: "counted today", beats: "Stalks up a mound of bones and red-team mech scrap, hops on top, lets out a roar that rattles the bones and blows the leaves off, then puffs its chest.",
  setup(c) {
    const r = c.r, U = r.U; c.mh = 0.12 * r.H;
    const mnd = mesh(new THREE.CylinderGeometry(0.34 * U, 0.66 * U, c.mh, 28), 0x7d6040); mnd.position.set(0, c.mh / 2, 0); c.props.add(mnd);
    const top = mesh(new THREE.CylinderGeometry(0.3 * U, 0.34 * U, c.mh * 0.08, 28), 0x6a8a3a); top.position.set(0, c.mh, 0); c.props.add(top);
    c.bones = [];
    const surf = rr => rr < 0.32 * U ? c.mh : c.mh * Math.max(0, 1 - (rr - 0.32 * U) / (0.34 * U));
    let seed = 5; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
    for (let i = 0; i < 18; i++) {
      const a = rnd() * Math.PI * 2, rr = 0.16 * U + rnd() * 0.5 * U, g = new THREE.Group();
      if (i % 6 === 5) { // red-team mech helmet
        g.add(bx(0.13 * U, 0.09 * U, 0.15 * U, 0xe0284a)); const vz = bx(0.11 * U, 0.03 * U, 0.02 * U, 0x1b1b22); vz.position.set(0, 0.01 * U, -0.075 * U); g.add(vz);
        const fin = bx(0.02 * U, 0.04 * U, 0.1 * U, 0x8a1a30); fin.position.y = 0.06 * U; g.add(fin);
      } else { // cartoon bone
        const L = (0.12 + rnd() * 0.08) * U, th = 0.028 * U; g.add(bx(L, th, th, 0xeee6d2));
        for (const sx of [-1, 1]) for (const sz of [-1, 1]) { const k = bx(th * 1.6, th * 1.6, th * 1.6, 0xf6f0e0); k.position.set(sx * L / 2, 0, sz * th * 0.7); g.add(k); }
      }
      g.position.set(Math.cos(a) * rr, surf(rr) + 0.02 * U, Math.sin(a) * rr); g.rotation.set((rnd() - .5) * 0.5, rnd() * 6.28, (rnd() - .5) * 0.5);
      c.props.add(g); c.bones.push({g, base: g.position.clone(), rot: g.rotation.clone(), y: 0, vy: 0});
    }
    r.pos.set(0, 0, 0.8 * U);
  },
  update(c, t, dt) {
    const r = c.r, U = r.U;
    const z0 = 0.82 * U, z1 = 0.6 * U;
    const z = t < 0.78 ? lerp(z0, z1, E.io(win(t, 0, 0.78))) : t < 1.1 ? z1 : t < 1.5 ? lerp(z1, 0, E.io(win(t, 1.1, 1.5))) : 0;
    let y = 0; if (t >= 1.1 && t < 1.5) { const u = win(t, 1.1, 1.5); y = lerp(0, c.mh, u) + 4 * 0.32 * r.H * u * (1 - u); } else if (t >= 1.5) y = c.mh;
    r.pos.set(0, y, z);
    let A = pk(t, [[0, P.STALK], [0.75, P.STALK], [1.02, P.CROUCH], [1.12, P.PUSH, "out"], [1.24, P.AIR, "out"], [1.44, P.AIR], [1.53, P.LAND, "out"], [1.85, P.IDLE], [2.1, P.ROAR_WIND], [2.26, P.ROAR, "out5"], [3.5, P.ROAR], [3.75, P.PROUD, "out"], [5.4, P.PROUD]]);
    let layer = null;
    if (t < 0.8) { A = addPose(A, walkLayer(t * 1.7, 0.7 * (1 - win(t, 0.6, 0.8)), r)); A = addPose(A, {Neck: [0, 16 * Math.sin(t * 4.4), 0], Head: [0, 8 * Math.sin(t * 4.4 - 0.5), 0]}); }
    if (t > 2.26 && t < 3.5) { const k = 1 - win(t, 3.3, 3.5); layer = {Neck: [0, 3 * Math.sin(t * 47) * k, 0], Head: [2 * Math.sin(t * 39) * k, 0, 3.5 * Math.sin(t * 43) * k], Jaw: [5 * Math.sin(t * 55) * k, 0, 0], Tail4: [0, 6 * Math.sin(t * 30) * k, 0], Tail5: [0, 9 * Math.sin(t * 30 - 1) * k, 0]}; camState.shake = Math.max(camState.shake, 0.9 * k); }
    if (t > 3.75) layer = {Tail1: [0, 10 * Math.sin((t - 3.75) * 3.2), 0], Tail2: [0, 12 * Math.sin((t - 3.75) * 3.2 - 0.6), 0], Tail3: [0, 14 * Math.sin((t - 3.75) * 3.2 - 1.2), 0], Neck: [0, -10 * E.io(win(t, 4.3, 4.9)), 0], Head: [-6 * Math.max(0, Math.sin((t - 4.9) * 9)) * (t > 4.9 && t < 5.25 ? 1 : 0), 0, 0]};
    at(c, "land", 1.5, () => { c.sq.v -= 7; kick(r, "Neck", -260); dustRing(V(0, c.mh, 0), 12, 0.22 * U, 0.9 * U); camState.shake = 0.6;
      c.bones.forEach(b => { b.vy = (0.6 + Math.random() * 0.8) * U; }); });
    at(c, "roar", 2.26, () => { c.sq.v += 3; flash(mouthPt(r), 0.5 * U, 0xfff2c0); });
    if (t > 2.26 && t < 3.45) { c.roarT = (c.roarT || 0) - dt; if (c.roarT <= 0) { c.roarT = 0.15; const m = mouthPt(r), d = m.clone().sub(headC(r)).normalize(); d.lerp(cam.position.clone().sub(m).normalize(), 0.35).normalize();
      shockRing(m.clone().addScaledVector(d, 0.08 * U), d, 0.65 * U, 0xfff6d8, 0.45, 0.08);
      for (let i = 0; i < 4; i++) { const s = sprite(T.leaf, 0xffffff, 0.06 * U, false); s.position.copy(m).add(V((Math.random() - .5) * .4 * U, (Math.random() - .3) * .3 * U, (Math.random() - .5) * .4 * U)); const v = d.clone().multiplyScalar((1.2 + Math.random()) * U).add(V((Math.random() - .5) * U, Math.random() * 0.5 * U, (Math.random() - .5) * U));
        addFx(s, 0.9, (o, u, dt2) => { o.position.addScaledVector(v, dt2); o.material.rotation += dt2 * 8; o.material.opacity = 1 - u; }); }
      puff(m.clone(), d.clone().multiplyScalar(1.4 * U), 0.12 * U, 0xffffff, 0.5, 3, 0.35); } }
    c.bones.forEach((b, i) => { b.vy -= 5 * U * dt; b.y += b.vy * dt; if (b.y < 0) { b.y = 0; b.vy = Math.abs(b.vy) > 0.3 * U ? -b.vy * 0.35 : 0; }
      const rat = t > 2.26 && t < 3.45 ? 0.012 * U : 0; b.g.position.set(b.base.x + (Math.random() - .5) * rat, b.base.y + b.y + (Math.random()) * rat, b.base.z + (Math.random() - .5) * rat);
      b.g.rotation.set(b.rot.x + b.y * 3 / U, b.rot.y + b.y * 2 / U, b.rot.z + (Math.random() - .5) * rat * 6 / U); });
    r.sq = sStep(c.sq, dt);
    drive(r, A, dt, layer);
    camShot(c, t, dt, [[0, [-0.55, 0.3, -1], 1.0, 0, 0], [1.4, [-0.5, 0.28, -1], 0.95, 0, 0], [2.15, [-0.42, 0.12, -1], 0.8, 0.06, 0.3], [3.5, [-0.36, 0.1, -1], 0.7, 0.06, 0.4, "lin"], [3.95, [-0.48, 0.24, -1], 0.85, 0, 0.15], [5.4, [-0.52, 0.26, -1], 0.9, 0, 0.15]], worldBox(r).union(new THREE.Box3(V(-0.5 * U, 0, -0.5 * U), V(0.5 * U, 0.2 * U, 0.5 * U))), headC(r));
  },
});

// =====================================================================================================================
// 2 · KING OF THE HILL — sits on the point; a crown drops out of the sky, BONKS it, bounces, lands crooked; a head-shake
// snaps it straight (ding), it stands up proud, flag flapping.
TITLES.push({
  id: "king", name: "KING OF THE HILL", kind: "good", cap: "Wouldn't get off the point", stat: "2:05 ON POINT", len: 5.4,
  rule: "Most time on the point (at least 30 s)", src: "counted today", beats: "Sits on the point. A crown falls out of the sky and bonks it on the head, bounces off and lands crooked. A head shake snaps it straight (ding!), then it stands up proud while the team flag flaps.",
  setup(c) {
    const r = c.r, U = r.U; c.mh = 0.09 * r.H;
    const mnd = mesh(new THREE.CylinderGeometry(0.36 * U, 0.6 * U, c.mh, 28), 0x7d6040); mnd.position.y = c.mh / 2; c.props.add(mnd);
    const ring = new THREE.Mesh(new THREE.RingGeometry(0.86 * U, 0.92 * U, 72), new THREE.MeshBasicMaterial({color: 0x5aa0ff, transparent: true, opacity: 0.85, side: THREE.DoubleSide}));
    ring.rotation.x = -Math.PI / 2; ring.position.y = 0.05; c.props.add(ring); c.ring = ring;
    const fill2 = new THREE.Mesh(new THREE.CircleGeometry(0.86 * U, 72), new THREE.MeshBasicMaterial({color: 0x5aa0ff, transparent: true, opacity: 0.12, depthWrite: false})); fill2.rotation.x = -Math.PI / 2; fill2.position.y = 0.04; c.props.add(fill2);
    // flag
    const fx0 = 0.5 * U, fz0 = 0.38 * U, ph = 1.05 * r.H;
    const pole = bx(0.025 * U, ph, 0.025 * U, 0xd8dce4); pole.position.set(fx0, ph / 2, fz0); c.props.add(pole);
    const knob = mesh(new THREE.SphereGeometry(0.03 * U, 10, 8), 0xffd25a); knob.position.set(fx0, ph + 0.02 * U, fz0); c.props.add(knob);
    c.flag = []; const n = 9, fw = 0.5 * U, fh = 0.3 * U;
    for (let i = 0; i < n; i++) { const st = bx(fw / n * 1.12, fh, 0.01 * U, 0x5aa0ff); c.props.add(st); c.flag.push({m: st, i}); }
    c.flagBase = V(fx0, ph - fh / 2 - 0.02 * U, fz0); c.fw = fw; c.fn = n;
    // crown (built in head-segment units so it sits on any head)
    const hb = r.segBox.Head, hw = Math.max(hb.max.x - hb.min.x, (hb.max.z - hb.min.z) * 0.6), cr = hw * 0.42, g = new THREE.Group();
    const gold = 0xffd25a;
    for (let i = 0; i < 10; i++) { const a = i / 10 * Math.PI * 2; const seg = bx(cr * 0.68, cr * 0.36, cr * 0.12, gold, {mat: {emissive: 0x3a2800}}); seg.position.set(Math.cos(a) * cr, cr * 0.18, Math.sin(a) * cr); seg.rotation.y = -a + Math.PI / 2; g.add(seg);
      const sp = new THREE.Mesh(new THREE.ConeGeometry(cr * 0.16, cr * 0.5, 4), new THREE.MeshLambertMaterial({color: gold, emissive: 0x3a2800})); sp.position.set(Math.cos(a) * cr, cr * 0.6, Math.sin(a) * cr); sp.castShadow = true; g.add(sp);
      if (i % 2 === 0) { const gem = bx(cr * 0.14, cr * 0.14, cr * 0.06, i % 4 === 0 ? 0xe0284a : 0x5aa0ff, {mat: {emissive: i % 4 === 0 ? 0x400010 : 0x0a2040}}); gem.position.set(Math.cos(a) * cr * 1.06, cr * 0.18, Math.sin(a) * cr * 1.06); gem.rotation.y = -a + Math.PI / 2; g.add(gem); } }
    g.matrixAutoUpdate = false; c.props.add(g); c.crown = g; c.crownR = cr;
    r.pos.set(0, c.mh, 0);
  },
  update(c, t, dt) {
    const r = c.r, U = r.U;
    r.pos.set(0, c.mh, 0);
    const A = pk(t, [[0, P.SIT], [0.45, P.SIT], [0.8, addPose(P.SIT, {Neck: [18, 0, 0], Head: [16, 0, 0], Jaw: [-8, 0, 0]})], [0.98, addPose(P.SIT, {Neck: [22, 0, 0], Head: [18, 0, 0], Jaw: [-12, 0, 0]})], [1.05, P.SIT, "out"], [2.6, P.SIT], [3.15, P.PROUD, "back"], [5.4, P.PROUD]]);
    let layer = breathe(t, 1);
    if (t > 1.0 && t < 1.85) { const k = 1 - win(t, 1.4, 1.85); layer = addPose(layer, {Neck: [6 * Math.sin(t * 11) * k, 16 * Math.sin(t * 6.5) * k, 10 * Math.cos(t * 6.5) * k], Head: [0, 0, 10 * Math.sin(t * 6.5 + 1) * k]}); }
    if (t > 1.9 && t < 2.55) { const u = win(t, 1.9, 2.55); layer = addPose(layer, {Neck: [0, 26 * Math.sin(u * Math.PI * 2 * 3.5) * Math.sin(u * Math.PI), 0], Head: [0, 10 * Math.sin(u * Math.PI * 2 * 3.5 - 0.7) * Math.sin(u * Math.PI), 0]}); }
    if (t > 3.2) layer = addPose(layer, {Tail2: [0, 8 * Math.sin(t * 2.4), 0], Tail3: [0, 12 * Math.sin(t * 2.4 - .6), 0], Tail4: [0, 14 * Math.sin(t * 2.4 - 1.2), 0]});
    at(c, "bonk", 1.0, () => { kick(r, "Neck", -420); kick(r, "Head", -240, 0, 160); c.sq.v -= 5; flash(headTop(r), 0.35 * U, 0xfff2c0); sparks(headTop(r), 10, 0.05 * U, 0xffe080, 1.2 * U, 5 * U); orbitStars(c, r, 4, 1.0); camState.shake = 0.5; c.hit = headTop(r); });
    at(c, "ding", 2.55, () => { const p = headTop(r); sparks(p, 16, 0.06 * U, 0xfff0a0, 1.0 * U, 2 * U); flash(p, 0.5 * U, 0xfff0a0, 0.3); });
    at(c, "stand", 2.62, () => { c.sq.v += 2.5; });
    r.sq = sStep(c.sq, dt);
    drive(r, A, dt, layer);
    // crown
    const g = c.crown, sc = r.scale;
    if (t < 0.45) g.visible = false;
    else if (t < 1.0) { g.visible = true; const u = E.in2(win(t, 0.45, 1.0)), h = headTop(r), st = h.clone().add(V(0.12 * U, 2.6 * U, -0.1 * U)), p = st.lerp(h, u);
      g.matrix.compose(p, new THREE.Quaternion().setFromEuler(new THREE.Euler(0.4 * Math.sin(t * 9), t * 14, 0.3 * Math.cos(t * 7))), V(sc, sc, sc)); }
    else if (t < 1.55) { const u = win(t, 1.0, 1.55), h = headTop(r), p = c.hit.clone().lerp(h, u).add(V(Math.sin(Math.PI * u) * 0.22 * U, 4 * 0.42 * U * u * (1 - u), -Math.sin(Math.PI * u) * 0.05 * U));
      g.matrix.compose(p, new THREE.Quaternion().setFromEuler(new THREE.Euler(u * Math.PI * 2, u * 3, 0.5 * Math.sin(u * 9))), V(sc, sc, sc)); }
    else { let tilt = 0.5, slide = 0.25;
      if (t < 1.75) { const u = win(t, 1.55, 1.75); tilt = 0.5 + 0.15 * Math.sin(u * Math.PI * 3) * (1 - u); }
      else if (t < 2.55) { const u = win(t, 1.9, 2.55); tilt = 0.5 * (1 - E.io(u)) + 0.18 * Math.sin(t * 38) * (1 - u) * (u > 0 ? 1 : 0); slide = 0.25 * (1 - E.io(u)); }
      else { tilt = 0.06 * Math.sin((t - 2.55) * 30) * Math.exp(-(t - 2.55) * 6); slide = 0; }
      if (c.fired.ding && t > 2.55) {}
      g.matrix.copy(r.segW.Head).multiply(new THREE.Matrix4().makeTranslation(r.headTopL.x + slide * c.crownR, r.headTopL.y - c.crownR * 0.05, r.headTopL.z)).multiply(new THREE.Matrix4().makeRotationZ(-tilt)); }
    if (t > 3.3) { c.glT = (c.glT || 0) - dt; if (c.glT <= 0) { c.glT = 0.9; const p = V(0, c.crownR * 0.9, 0).applyMatrix4(g.matrix); flash(p, 0.18 * U, 0xffffff, 0.35); } }
    // flag + point ring
    c.flag.forEach(f => { const u = f.i / (c.fn - 1), w = Math.sin(t * 7 - f.i * 0.8) * 0.06 * U * u * (t > 2.6 ? 1.6 : 1); f.m.position.set(c.flagBase.x - 0.012 * U - u * c.fw, c.flagBase.y + Math.sin(t * 5 - f.i) * 0.008 * U * u, c.flagBase.z + w); f.m.rotation.y = Math.cos(t * 7 - f.i * 0.8) * 0.18 * u; });
    c.ring.material.opacity = 0.65 + 0.25 * Math.sin(t * 4);
    camShot(c, t, dt, [[0, [-0.5, 0.28, -1], 1.0, 0, 0], [0.5, [-0.5, 0.18, -1], 1.05, 0.35, 0], [0.95, [-0.42, 0.3, -1], 0.62, 0, 0.6, "out"], [2.55, [-0.42, 0.3, -1], 0.6, 0, 0.6], [3.2, [-0.52, 0.12, -1], 0.98, 0, 0.1], [5.4, [-0.56, 0.14, -1], 1.02, 0, 0.1]], worldBox(r), headC(r));
  },
});

// =====================================================================================================================
// 3 · UNKILLABLE — chewing, not a care in the world; a flaming meteor smashes into its head and shatters. It blinks,
// looks at the rocks, shrugs, goes back to chewing. A pebble bonks it again; nothing.
TITLES.push({
  id: "unkill", name: "UNKILLABLE", kind: "good", cap: "The asteroid missed. Again.", stat: "0 DEATHS", len: 5.4,
  rule: "Didn't die once (and got at least 1 kill or 30 s on the point)", src: "counted today", beats: "Chewing, not a care in the world. A flaming meteor smashes into its head and shatters into rocks. It looks at the rocks, shrugs and goes back to chewing, smoke curling off its head. A last pebble bonks it; nothing.",
  setup(c) { const r = c.r, U = r.U; c.met = meteorMesh(0.16 * U, true); c.met.visible = false; c.props.add(c.met); },
  update(c, t, dt) {
    const r = c.r, U = r.U;
    const LUP = addPose(P.CHILL, {Neck: [26, 8, 0], Head: [20, 6, 0], Jaw: [-6, 0, 0]}), LROCK = BOTH({Neck: [-10, 0, 0], Head: [-6, 0, 0]}), LCAM = BOTH({RootJoint: [2, 0, 0], Neck: [6, 0, 0], Head: [-2, 0, 0]});
    LROCK.Neck = [-10, 28, 0]; LROCK.Head = [-6, 14, 0]; LCAM.Neck = [6, -16, 0]; LCAM.Head = [-2, -10, 6];
    const A = pk(t, [[0, P.CHILL], [1.7, P.CHILL], [1.78, addPose(P.CHILL, {Neck: [-8, 0, 0]})], [2.0, P.CHILL], [2.45, LUP], [2.85, LROCK], [3.15, LCAM], [3.5, P.SHRUG, "back"], [3.95, P.SHRUG], [4.3, P.CHILL], [5.4, P.CHILL]]);
    const chew = (t < 1.7 || t > 4.25) ? 1 : 0;
    const layer = addPose(breathe(t, 1), {Jaw: [chew * (-5 - 7 * Math.max(0, Math.sin(t * 2 * Math.PI * 2.4))), 0, 0], Head: [0, 0, chew * 3 * Math.sin(t * 2 * Math.PI * 1.2)]});
    // meteor: glint, streak in, BONK
    const h = headTop(r), st = h.clone().add(V(-1.3 * U, 3.3 * U, 0.9 * U));
    at(c, "glint", 0.5, () => { flash(st, 0.4 * U, 0xffe0b0, 0.5); });
    if (t > 0.85 && t < 1.7) { const u = win(t, 0.85, 1.7); c.met.visible = true; c.met.position.copy(st).lerp(h, u); c.met.userData.rock.rotation.x += dt * 6; c.met.userData.rock.rotation.z += dt * 4; trail(c.met.position, U, 0.2 * U, 2); }
    at(c, "hit", 1.7, () => { c.met.visible = false; hitStop = 0.12; flash(h, 0.9 * U, 0xffe0a0, 0.25); sparks(h, 22, 0.07 * U, 0xffc060, 1.6 * U, 5 * U); camState.shake = 1.0;
      for (let i = 0; i < 12; i++) { const a = Math.random() * Math.PI * 2, s = (0.035 + Math.random() * 0.04) * U, rk = rock(s, i % 3 ? 0x5a4a3e : 0x7a6656); rk.position.copy(h).add(V(0, 0.05 * U, 0));
        addDebris(rk, V(Math.cos(a) * (0.6 + Math.random()) * U, (0.9 + Math.random() * 0.9) * U, Math.sin(a) * (0.6 + Math.random()) * U), V(Math.random() * 9, Math.random() * 9, Math.random() * 9), {r: s, grav: 5 * U, life: 3.6, bounce: 0.4}); }
      puff(h.clone(), V(0, 0.3 * U, 0), 0.3 * U, 0x8a8078, 1.0, 2.2, 0.7); kick(r, "Neck", -170); kick(r, "Head", 0, 0, 140); c.sq.v -= 2.8; });
    if (t > 1.75 && t < 4.9) { c.smT = (c.smT || 0) - dt; if (c.smT <= 0) { c.smT = 0.11; puff(headTop(r).add(V((Math.random() - .5) * 0.04 * U, 0.02 * U, 0)), V(0.05 * U, 0.35 * U, 0), 0.05 * U, 0x9a9a9a, 1.1, 2.6, 0.5); } }
    // the last pebble
    if (t > 4.45 && t < 4.75) { if (!c.peb) { c.peb = rock(0.03 * U, 0x6a5a4a); c.props.add(c.peb); } const u = E.in2(win(t, 4.45, 4.75)); c.peb.position.copy(h).add(V(0.05 * U, 1.4 * U * (1 - u), 0)); }
    at(c, "pebble", 4.75, () => { if (c.peb) { c.props.remove(c.peb); const p = rock(0.03 * U, 0x6a5a4a); p.position.copy(h); addDebris(p, V(0.5 * U, 0.8 * U, -0.2 * U), V(8, 3, 5), {r: 0.03 * U, grav: 5 * U, life: 2}); } flash(h, 0.15 * U, 0xffffff, 0.12); });
    r.sq = sStep(c.sq, dt);
    drive(r, A, dt, layer);
    camShot(c, t, dt, [[0, [-0.5, 0.28, -1], 0.9, 0, 0.2], [0.85, [-0.5, 0.2, -1], 1.15, 0.4, 0], [1.55, [-0.42, 0.3, -1], 0.68, 0.05, 0.5, "out"], [2.6, [-0.45, 0.3, -1], 0.8, 0, 0.3], [5.4, [-0.5, 0.3, -1], 0.9, 0, 0.2]], worldBox(r), headC(r), c.met.visible ? c.met.position : null, kf(t, [[0.8, 0], [1.05, 0.12], [1.5, 0.05], [1.7, 0]]));
  },
});

// =====================================================================================================================
// 4 · MEDIC — a med kit drops in; it noses the lid open (hearts pop out), comes up with a plaster stuck on its snout,
// can't shake it off, then lunges at the camera and slaps a plaster on YOUR screen.
TITLES.push({
  id: "medic", name: "MEDIC", kind: "good", cap: "Patched up the whole team", stat: "640 HP HEALED", len: 5.4, isNew: true,
  rule: "Most HP healed on teammates (at least 100)", src: "new counting", beats: "A med kit drops in. It noses the lid open (hearts pop out), comes up with a plaster stuck on its snout and can't shake it off, then lunges at the camera and slaps a plaster right on your screen.",
  setup(c) {
    const r = c.r, U = r.U, m0 = peckPoint(r, P.PECK);
    const kh = clamp(m0.y - 0.02 * U, 0.12 * U, 0.4 * U), kw = 0.36 * U, kd = 0.26 * U, g = new THREE.Group();
    const body = bx(kw, kh * 0.78, kd, 0xf2f2f2); body.position.y = kh * 0.39; g.add(body);
    const band = bx(kw * 1.01, kh * 0.08, kd * 1.01, 0xd8d8d8); band.position.y = kh * 0.7; g.add(band);
    const cf1 = bx(kw * 0.12, kh * 0.4, 0.01 * U, 0xe0284a), cf2 = bx(kw * 0.36, kh * 0.13, 0.01 * U, 0xe0284a); cf1.position.set(0, kh * 0.38, -kd / 2 - 0.004 * U); cf2.position.copy(cf1.position); g.add(cf1, cf2);
    const hinge = new THREE.Group(); hinge.position.set(0, kh * 0.78, kd / 2); g.add(hinge);
    const lid = bx(kw * 1.03, kh * 0.22, kd * 1.03, 0xf8f8f8); lid.position.set(0, kh * 0.11, -kd / 2); hinge.add(lid);
    const lc1 = bx(kw * 0.12, 0.012 * U, kd * 0.6, 0xe0284a), lc2 = bx(kw * 0.5, 0.012 * U, kd * 0.16, 0xe0284a); lc1.position.set(0, kh * 0.225, -kd / 2); lc2.position.copy(lc1.position); hinge.add(lc1, lc2);
    const inside = bx(kw * 0.9, 0.01 * U, kd * 0.85, 0xc0303a); inside.position.y = kh * 0.77; g.add(inside);
    g.position.set(m0.x, 0, m0.z); c.props.add(g); c.kit = g; c.hinge = hinge; c.kh = kh; c.lid = sSpring(0, 18, 0.32); c.kitSq = sSpring(1, 26, 0.3);
    // plaster on the snout (head-segment units)
    const hb = r.segBox.Head, hw = hb.max.x - hb.min.x, pl = new THREE.Group();
    const strip = bx(hw * 1.15, hw * 0.08, hw * 0.34, 0xf1c79c); pl.add(strip); const padm = bx(hw * 0.4, hw * 0.1, hw * 0.24, 0xfbe9d6); pl.add(padm);
    pl.matrixAutoUpdate = false; pl.visible = false; c.props.add(pl); c.plaster = pl;
    c.snout = V(lerp(hb.min.x, hb.max.x, 0.5), hb.max.y, lerp(r.mouthL.z, hb.getCenter(V(0, 0, 0)).z, 0.45));
    c.camP = V(-0.42 * U, 0.55 * U, -1.45 * U); c.yawCam = yawTo(V(0, 0, 0), c.camP);
  },
  update(c, t, dt) {
    const r = c.r, U = r.U;
    const CUR = BOTH({Neck: [-14, 0, 0], Head: [-4, 0, 0]}); CUR.Head = [-4, 0, 18]; CUR.Neck = [-14, -6, 0];
    const DIP = addPose(P.PECK, {Neck: [-8, 0, 0], Head: [-6, 0, 0]}), WIND = BOTH({RootJoint: [10, 0, 0], Neck: [28, 0, 0], Head: [-12, 0, 0], ArmL: [-20, 0, 0]}), LUNGE = BOTH({RootJoint: [-2, 0, 0], Neck: [6, 0, 0], Head: [-2, 0, 0], Jaw: [-34, 0, 0], ArmL: [-46, 0, 0], LegL: [-10, 0, 0], KneeL: [-10, 0, 0]});
    const A = pk(t, [[0, P.IDLE], [0.55, P.IDLE], [0.78, CUR], [0.95, P.PECK_UP], [1.05, P.PECK, "out"], [1.18, P.PECK_UP], [1.36, DIP], [1.52, DIP], [1.72, P.PECK_UP, "out"], [2.05, P.IDLE], [2.3, WIND], [2.48, LUNGE, "out5"], [2.66, LUNGE], [3.05, P.PROUD, "out"], [5.4, P.PROUD]]);
    let layer = breathe(t, 1);
    if (t > 1.72 && t < 2.12) { const u = win(t, 1.72, 2.12); layer = addPose(layer, {Neck: [0, 22 * Math.sin(u * Math.PI * 2 * 3) * Math.sin(u * Math.PI), 0], Head: [0, 14 * Math.sin(u * Math.PI * 2 * 3 - 0.8) * Math.sin(u * Math.PI), 8 * Math.sin(u * Math.PI * 6)]}); }
    at(c, "aim", 2.0, () => { c.camAt = cam.position.clone(); c.yawCam = yawTo(r.pos, c.camAt); const mo = mouthPt(r); c.lungeD = clamp(Math.hypot(c.camAt.x - mo.x, c.camAt.z - mo.z) - 0.95 * U, 0, 0.8 * U); });
    r.yaw = kf(t, [[2.05, 0], [2.32, c.yawCam || 0], [3.0, c.yawCam || 0], [3.6, (c.yawCam || 0) * 0.4]]);
    const dir = c.camAt ? V(c.camAt.x, 0, c.camAt.z).normalize() : V(0, 0, -1), lung = kf(t, [[2.3, 0], [2.5, c.lungeD || 0, "out5"], [2.68, c.lungeD || 0], [3.1, 0, "out"]]);
    r.pos.set(dir.x * lung, 0, dir.z * lung);
    // kit drop + lid
    const kd = kf(t, [[0.12, 2.6 * U], [0.55, 0, "in2"]]); c.kit.position.y = kd; c.kit.visible = t > 0.12;
    at(c, "kitland", 0.55, () => { c.kitSq.v -= 6; dustRing(V(c.kit.position.x, 0, c.kit.position.z), 10, 0.12 * U, 0.6 * U); });
    at(c, "open", 1.05, () => { c.lid.tg = rad(-118); c.lid.v -= 14; for (let i = 0; i < 9; i++) { const s = sprite(T.heart, 0xffffff, 0.08 * U, false); const p0 = c.kit.position.clone().add(V(0, c.kh, 0)); s.position.copy(p0); const v = V((Math.random() - .5) * 0.7 * U, (0.7 + Math.random() * 0.6) * U, (Math.random() - .5) * 0.7 * U);
      addFx(s, 1.6, (o, u, d2) => { o.position.addScaledVector(v, d2); v.multiplyScalar(Math.pow(0.3, d2)); o.scale.setScalar(0.08 * U * (u < 0.15 ? E.back(u / 0.15) : 1)); o.material.opacity = u > 0.7 ? (1 - u) / 0.3 : 1; }); } sparks(c.kit.position.clone().add(V(0, c.kh, 0)), 10, 0.04 * U, 0xffd0e0, 0.8 * U, 2 * U); });
    c.hinge.rotation.x = sStep(c.lid, dt); const ks = sStep(c.kitSq, dt); c.kit.scale.set(1 / Math.sqrt(ks), ks, 1 / Math.sqrt(ks));
    at(c, "slap", 2.62, () => { camState.shake = 1.3; hitStop = 0.06; });
    { const fo = $("flashov"); fo.style.transition = "none"; fo.style.opacity = t < 2.62 ? 0 : 0.55 * (1 - win(t, 2.62, 2.85)); }
    // screen plasters
    const pl1 = $("pl1"), pl2 = $("pl2");
    if (t >= 2.62) { const u = win(t, 2.62, 2.82), k = 1.8 - 0.8 * E.back(u); pl1.style.opacity = 0.95; pl2.style.opacity = 0.95; pl1.style.transform = `rotate(-32deg) scale(${k})`; pl2.style.transform = `rotate(38deg) scale(${k})`; }
    else { pl1.style.opacity = 0; pl2.style.opacity = 0; }
    // snout plaster
    c.plaster.visible = t > 1.5; if (c.plaster.visible) c.plaster.matrix.copy(r.segW.Head).multiply(new THREE.Matrix4().makeTranslation(c.snout.x, c.snout.y, c.snout.z)).multiply(new THREE.Matrix4().makeRotationZ(0.25 + 0.08 * Math.sin(t * 20) * (t < 2.1 ? 1 : 0)));
    if (t > 3.0) { c.hT = (c.hT || 0) - dt; if (c.hT <= 0) { c.hT = 0.14; const a = Math.random() * Math.PI * 2, p0 = r.pos.clone().add(V(Math.cos(a) * 0.4 * U, (0.1 + Math.random() * 0.6) * r.H, Math.sin(a) * 0.4 * U)); const s = sprite(Math.random() < 0.7 ? T.plus : T.heart, 0xffffff, 0.07 * U, false); s.position.copy(p0);
      addFx(s, 1.2, (o, u, d2) => { o.position.y += 0.35 * U * d2; o.scale.setScalar(0.07 * U * (u < 0.2 ? E.back(u / 0.2) : 1)); o.material.opacity = u > 0.7 ? (1 - u) / 0.3 : 1; }); } }
    drive(r, A, dt, layer);
    c.camHold = t > 2.2 && t < 3.0; camShot(c, t, dt, [[0, [-0.35, 0.32, -1], 0.95, 0, 0], [0.6, [-0.45, 0.35, -1], 0.85, -0.1, 0], [1.9, [-0.4, 0.2, -1], 0.8, 0, 0.3], [2.2, [-0.3, 0.06, -1], 0.9, 0, 0.45], [3.2, [-0.3, 0.12, -1], 0.95, 0, 0.2], [5.4, [-0.35, 0.22, -1], 1.0, 0, 0]], worldBox(r).union(new THREE.Box3().setFromObject(c.kit)), headC(r));
  },
});

// =====================================================================================================================
// 5 · BUTTON MASHER — finds a big red arcade button and pecks it like crazy (counter flying up, sparks, smoke) until the
// button pops off and flies away. Stares after it. One last sad peck on the empty stand.
TITLES.push({
  id: "masher", name: "BUTTON MASHER", kind: "good", cap: "Never met a cooldown it liked", stat: "47 ABILITIES", len: 5.4, isNew: true,
  rule: "Most abilities used (at least 20)", src: "new counting", beats: "Finds a giant red arcade button and pecks it like crazy while a counter flies up, sparks fly and the button starts smoking, until the button pops off its spring and flies away. It stares after it, then gives the empty stand one last sad peck.",
  setup(c) {
    const r = c.r, U = r.U, m0 = peckPoint(r, P.PECK), domeH = 0.05 * U;
    const ph = Math.max(0.08 * U, m0.y - domeH - 0.02 * U), g = new THREE.Group();
    const ped = bx(0.2 * U, ph, 0.2 * U, 0x2b3242); ped.position.y = ph / 2; g.add(ped);
    const trim = bx(0.23 * U, 0.025 * U, 0.23 * U, 0xffc832); trim.position.y = ph; g.add(trim);
    const stripe = bx(0.205 * U, 0.03 * U, 0.205 * U, 0xffc832); stripe.position.y = ph * 0.3; g.add(stripe);
    const ringm = mesh(new THREE.CylinderGeometry(0.085 * U, 0.09 * U, 0.02 * U, 24), 0x111111); ringm.position.y = ph + 0.02 * U; g.add(ringm);
    const dome = mesh(new THREE.CylinderGeometry(0.068 * U, 0.072 * U, domeH, 24), 0xe0283a, {mat: {emissive: 0x300000}}); dome.position.y = ph + 0.02 * U + domeH / 2; g.add(dome);
    const domeTop = mesh(new THREE.SphereGeometry(0.068 * U, 20, 10, 0, Math.PI * 2, 0, Math.PI / 2), 0xe0283a, {mat: {emissive: 0x300000}}); domeTop.scale.y = 0.35; domeTop.position.y = domeH / 2; dome.add(domeTop);
    const coil = mesh(new THREE.CylinderGeometry(0.02 * U, 0.02 * U, 1, 8), 0xc8ccd4); coil.visible = false; g.add(coil);
    g.position.set(m0.x, 0, m0.z); c.props.add(g); c.btn = {g, dome, domeTop, coil, ph, domeY: dome.position.y}; c.hits = 0; c.lastIdx = -1; c.coil = sSpring(0, 30, 0.2);
  },
  update(c, t, dt) {
    const r = c.r, U = r.U, B = c.btn, cnt = $("counter");
    const EYE = BOTH({RootJoint: [-4, 0, 0], Neck: [-16, 0, 0], Head: [-6, 0, 0]}); EYE.Head = [-6, 0, 16];
    const LUPB = BOTH({RootJoint: [6, 0, 0], Neck: [40, 0, 0], Head: [22, 0, 0], Jaw: [-16, 0, 0]}); LUPB.Neck = [40, 22, 0];
    const LCAM = {Neck: [0, -16, 0], Head: [-2, -8, 0], Jaw: [-8, 0, 0]};
    const SLUMP = BOTH({RootJoint: [-6, 0, 0], Neck: [-16, 0, 0], Head: [4, 0, 0], ArmL: [10, 0, 0], Tail1: [10, 0, 0], Tail2: [6, 0, 0]});
    let A, direct = false, layer = null;
    const mashOn = t >= 0.85 && t < 3.0;
    if (mashOn) {
      const ph = (t - 0.85) * 7.2, f = 0.5 - 0.5 * Math.cos(ph * Math.PI * 2), idx = Math.floor(ph + 0.5);
      A = lerpPose(P.PECK_UP, P.PECK, Math.pow(f, 0.7)); direct = true;
      const st = Math.sin(t * Math.PI * 2 * 3.6);
      A = addPose(A, {LegL: [12 * Math.max(0, st), 0, 0], KneeL: [-22 * Math.max(0, st), 0, 0], LegR: [12 * Math.max(0, -st), 0, 0], KneeR: [-22 * Math.max(0, -st), 0, 0], Tail1: [0, 14 * Math.sin(t * 46), 0], Tail2: [0, 18 * Math.sin(t * 46 - .8), 0], Tail3: [0, 20 * Math.sin(t * 46 - 1.6), 0], ArmL: [-20 * f, 0, 0], ArmR: [-20 * f, 0, 0]});
      if (idx > c.lastIdx && (ph - Math.floor(ph)) > 0.45) { c.lastIdx = idx; c.hits = Math.min(47, Math.max(c.hits + 1, Math.round(47 * Math.pow(sat((t - 0.85) / 2.1), 1.3)))); const p = B.g.position.clone().add(V(0, B.domeY + 0.04 * U, 0));
        sparks(p, 5, 0.04 * U, c.hits > 30 ? 0xffa040 : 0xfff4c8, 0.7 * U, 3 * U); c.pop = 0; camState.shake = Math.max(camState.shake, 0.25); }
      B.dome.position.y = B.domeY - 0.022 * U * f;
    } else if (t < 0.85) {
      A = pk(t, [[0, P.IDLE], [0.4, EYE], [0.62, P.PECK_UP], [0.78, P.PECK, "out"], [0.85, P.PECK_UP]]);
      at(c, "first", 0.78, () => { c.hits = 1; c.pop = 0; sparks(B.g.position.clone().add(V(0, B.domeY + 0.04 * U, 0)), 4, 0.04 * U, 0xfff4c8, 0.6 * U, 3 * U); });
    } else A = pk(t, [[3.0, P.PECK], [3.32, P.PECK], [3.75, LUPB, "out"], [4.0, LUPB], [4.25, LCAM], [4.38, P.PECK_UP], [4.5, P.PECK, "out"], [4.62, P.PECK_UP], [4.95, SLUMP], [5.4, SLUMP]]);
    if (t > 3.0) layer = breathe(t, 0.6);
    // heat + smoke
    const heat = sat(c.hits / 47); B.dome.material.emissive.setRGB(0.2 + 0.8 * heat, 0.03 + 0.25 * heat * heat, 0); B.domeTop.material.emissive.copy(B.dome.material.emissive);
    if (t > 2.1 && t < 3.6) { c.smT = (c.smT || 0) - dt; if (c.smT <= 0) { c.smT = 0.07; puff(B.g.position.clone().add(V(0, B.ph + 0.08 * U, 0)), V((Math.random() - .5) * 0.1 * U, 0.5 * U, 0), 0.06 * U, 0x6a6a6a, 0.9, 2.4, 0.6); } }
    // pop!
    at(c, "pop", 3.0, () => { c.hits = 47; c.pop = 0; hitStop = 0.07; camState.shake = 0.8; const p = B.g.position.clone().add(V(0, B.domeY, 0)); flash(p, 0.4 * U, 0xffd0a0); sparks(p, 24, 0.06 * U, 0xffb040, 1.6 * U, 4 * U);
      B.dome.visible = false; const fly = new THREE.Group(); const d1 = B.dome.clone(); d1.position.set(0, 0, 0); d1.visible = true; fly.add(d1); fly.position.copy(p);
      addDebris(fly, V(0.7 * U, 4.2 * U, 0.5 * U), V(9, 4, 7), {r: 0.05 * U, grav: 2.4 * U, life: 3, bounce: 0.3, fade: false}); c.fly = fly; c.coil.v = 14; B.coil.visible = true;
      for (let i = 0; i < 3; i++) { const bolt = bx(0.02 * U, 0.01 * U, 0.01 * U, 0x9aa0aa); bolt.position.copy(p); addDebris(bolt, V((Math.random() - .5) * 1.4 * U, (1 + Math.random()) * U, (Math.random() - .5) * 1.4 * U), V(10, 10, 10), {r: 0.01 * U, grav: 5 * U, life: 2.4}); } });
    at(c, "thunk", 3.05, () => { dustRing(B.g.position.clone().add(V(0, B.ph, 0)), 6, 0.06 * U, 0.3 * U, 0x9a9a9a); });
    at(c, "sad", 4.5, () => { c.hits = 48; c.pop = 0; c.sad = true; flash(B.g.position.clone().add(V(0, B.ph + 0.03 * U, 0)), 0.12 * U, 0xffffff, 0.12); });
    if (B.coil.visible) { const k = 1 + sStep(c.coil, dt) * 0.4; const L = 0.12 * U * Math.max(0.2, k); B.coil.scale.set(1, L, 1); B.coil.position.y = B.ph + 0.02 * U + L / 2; }
    // counter overlay
    c.pop = (c.pop === undefined ? 9 : c.pop) + dt;
    if (c.hits > 0 && t < 5.2) { cnt.style.opacity = 1; cnt.textContent = "x" + c.hits; const k = 1 + 0.5 * Math.max(0, 1 - c.pop / 0.12); cnt.style.transform = `translateX(-50%) scale(${k}) rotate(${(c.hits % 2 ? 1 : -1) * 4 * Math.max(0, 1 - c.pop / 0.12)}deg)`; cnt.style.color = c.sad ? "#8f99aa" : heat > 0.6 ? "#ffb040" : "#ffffff"; }
    else cnt.style.opacity = 0;
    drive(r, A, dt, layer, direct);
    const flyLook = c.fly && t < 4.0 ? c.fly.position : null;
    camShot(c, t, dt, [[0, [1, 0.32, -0.6], 0.95, 0, 0], [0.85, [1, 0.24, -0.65], 0.75, 0, 0.3], [3.0, [1, 0.2, -0.65], 0.66, 0, 0.35, "lin"], [3.35, [1, 0.28, -0.65], 1.0, 0.25, 0], [4.1, [1, 0.3, -0.68], 0.9, 0, 0.1], [5.4, [1, 0.32, -0.68], 0.95, 0, 0.1]], worldBox(r).union(new THREE.Box3().setFromObject(c.btn.g)), headC(r), flyLook, kf(t, [[3.05, 0], [3.4, 0.45], [3.85, 0.3], [4.1, 0]]));
  },
});

// =====================================================================================================================
// 6 · CARRIED — a teammate grabs it by the tail, hammer-throws it into a backpack headfirst (legs kicking), zips it up,
// picks the bag up in its jaws and trots off with it swinging.
TITLES.push({
  id: "carried", name: "CARRIED", kind: "roast", cap: "Packed up and carried to the win", stat: "40 SCORE · LOWEST", len: 6.4,
  rule: "Lowest score on the team, under half of the top teammate's", src: "counted today (scoreboard score)", beats: "A teammate sneaks up, grabs it by the tail, spins it round and hammer-throws it headfirst into a backpack. Legs kicking, the bag gets zipped up and swallows it whole, then the teammate picks the bag up in its jaws and trots off with it swinging, the tail poking out.",
  setup(c) {
    const r = c.r, U = r.U, m = c.m; c.U0 = U;
    setRigScale(m, m.base * clamp(1.12 * r.H / (m.m.H * m.base), 0.4, 3));
    // mate's bite pose: blend IDLE -> PECK until the mouth is at the tail tip's height
    poseRig(r, {}); const tt = tailTip(r);
    let best = 0, bdist = Infinity; m.pos.set(0, 0, 0); m.yaw = 0;
    for (let b = 0; b <= 1.001; b += 0.05) { poseRig(m, lerpPose(P.IDLE, P.PECK, b)); const d = Math.abs(mouthPt(m).y - tt.y); if (d < bdist) { bdist = d; best = b; } }
    c.bite = lerpPose(P.IDLE, P.PECK, best); poseRig(m, c.bite); const mm = mouthPt(m);
    c.M0 = V(tt.x - mm.x, 0, tt.z - mm.z); c.mouthOff = mm; // mate stands so its mouth is on the tail tip
    // the bag: the carried dino at 70 % goes in nose first; the bag is sized from that pose so nothing pokes out the sides
    const Ls = 0.7 * r.L, bh = 0.46 * Ls; c.B = V(-2.25 * U, 0, -0.55 * U);
    const s0 = r.scale; setRigScale(r, r.base * 0.7); r.plant = "none"; r.yaw = 0; r.rx = rad(-92); r.rz = 0; r.pos.set(0, 0, 0); poseRig(r, P.STARTLED);
    const hip = segPt(r, "Tail1", V(0, 0, 0)); c.inBag = V(c.B.x - hip.x, bh * 1.05 - hip.y + 0.04 * U, c.B.z - hip.z);
    r.pos.copy(c.inBag); poseRig(r, P.STARTLED);
    const inside = worldBox(r, p => segC(r, p.seg).y < bh * 1.05); let ex = 0, ez = 0;
    if (!inside.isEmpty()) { ex = Math.max(Math.abs(inside.min.x - c.B.x), Math.abs(inside.max.x - c.B.x)); ez = Math.max(Math.abs(inside.min.z - c.B.z), Math.abs(inside.max.z - c.B.z)); }
    const bw = Math.max(0.62 * bh, 2 * ex * 1.15), bd = Math.max(0.5 * bh, 2 * ez * 1.15); c.bh = bh; c.bw = bw; c.bd = bd;
    c.deep = c.inBag.clone().add(V(0, -0.6 * bh, 0));
    setRigScale(r, s0); r.yaw = 0; r.rx = 0; r.plant = "feet"; r.pos.set(0, 0, 0); poseRig(r, {});
    const bag = new THREE.Group(), BLUE = 0x3d7fe0, DK = 0x24508f;
    const core = bx(bw, bh, bd, BLUE); core.position.y = bh / 2; bag.add(core);
    const roundT = bx(bw * 0.92, bh * 0.06, bd * 0.92, BLUE); roundT.position.y = bh + bh * 0.02; bag.add(roundT);
    const pocket = bx(bw * 0.7, bh * 0.38, bd * 0.18, DK); pocket.position.set(0, bh * 0.3, -bd / 2 - bd * 0.08); bag.add(pocket);
    const pz = bx(bw * 0.6, bh * 0.02, 0.01 * U, 0xffc832); pz.position.set(0, bh * 0.47, -bd / 2 - bd * 0.175); bag.add(pz);
    for (const sx of [-1, 1]) { const sp = bx(bw * 0.12, bh * 0.5, bd * 0.3, DK); sp.position.set(sx * (bw / 2 + bw * 0.05), bh * 0.3, 0); bag.add(sp);
      const strap = bx(bw * 0.1, bh * 0.8, bd * 0.06, 0x1d2a44); strap.position.set(sx * bw * 0.25, bh * 0.5, bd / 2 + bd * 0.04); bag.add(strap); }
    const handle = new THREE.Mesh(new THREE.TorusGeometry(bw * 0.14, bw * 0.03, 6, 14, Math.PI), new THREE.MeshLambertMaterial({color: 0x1d2a44})); handle.position.set(0, bh * 1.04, 0); bag.add(handle);
    const hole = bx(bw * 0.86, 0.01 * U, bd * 0.8, 0x0d1a33); hole.position.y = bh * 1.055; bag.add(hole);
    const zipBase = bx(bw * 0.9, bh * 0.025, bd * 0.06, 0xffc832); zipBase.position.set(0, bh * 1.06, -bd * 0.42); bag.add(zipBase);
    const cover = bx(1, bh * 0.05, bd * 0.86, BLUE); cover.position.y = bh * 1.07; cover.visible = false; bag.add(cover);
    const pull = bx(bw * 0.06, bh * 0.08, bw * 0.04, 0xffe080); pull.visible = false; bag.add(pull);
    const tailP = new THREE.Group(); const tcol = parseInt((r.segs.Tail4[0] || r.segs.Tail1[0]).color, 16); for (let i = 0; i < 3; i++) { const tb = bx(bw * 0.14 * (1 - i * 0.22), bw * 0.14 * (1 - i * 0.22), bh * 0.18, tcol); tb.position.z = i * bh * 0.16; tailP.add(tb); }
    tailP.position.set(bw * 0.36, bh * 1.08, 0); tailP.visible = false; bag.add(tailP);
    bag.position.copy(c.B); c.props.add(bag); c.bag = {g: bag, cover, pull, tailP, handle, hole};
    c.bagSq = sSpring(1, 20, 0.25);
    // mate's pick-up spot (mouth on the handle) and exit
    m.pos.set(0, 0, 0); m.yaw = yawTo(c.M0, c.B); poseRig(m, P.PECK); const pm = mouthPt(m); c.yawBag = m.yaw;
    c.Mpick = V(c.B.x - pm.x, 0, c.B.z - pm.z); m.yaw = 0; m.pos.copy(c.M0); poseRig(m, c.bite);
    c.M = c.M0.clone(); c.matePh = 0; c.spin = 0; c.msq = sSpring(1, 22, 0.3);
  },
  update(c, t, dt) {
    const r = c.r, m = c.m, U = c.U0, bag = c.bag;
    // ---- mate ----
    let mA, mLayer = null, mDirect = false;
    const enter = win(t, 0.05, 0.62);
    if (t < 0.95) {
      c.M.copy(c.M0).add(V(3.0 * U * (1 - E.out(enter)), 0, 0)); m.yaw = kf(t, [[0, Math.PI / 2], [0.48, Math.PI / 2], [0.66, 0]]);
      c.matePh += dt * 2.6 * (1 - enter * 0.85);
      mA = pk(t, [[0, P.STALK], [0.5, P.STALK], [0.66, addPose(c.bite, {Jaw: [-34, 0, 0]})], [0.74, c.bite, "out5"]]);
      if (t < 0.6) mA = addPose(mA, walkLayer(c.matePh, 1 - win(t, 0.4, 0.6), m));
    } else if (t < 2.35) {
      const u = win(t, 0.95, 2.35); c.spin = 2 * Math.PI * 1.6 * u * u; m.yaw = c.spin; c.M.copy(c.M0);
      const SPIN = BOTH({RootJoint: [14, 0, 0], Neck: [-6, 0, 0], Head: [6, 0, 0], ArmL: [-24, 0, 0], Tail1: [-8, 0, 0], Tail2: [-6, 0, 0]});
      mA = addPose(lerpPose(c.bite, SPIN, E.io(win(t, 0.95, 1.2))), walkLayer(c.spin / Math.PI, 0.45, m));
      c.duT = (c.duT || 0) - dt; if (c.duT <= 0) { c.duT = 0.07; const a = Math.random() * Math.PI * 2; puff(c.M.clone().add(V(Math.cos(a) * 0.3 * U, 0.05 * U, Math.sin(a) * 0.3 * U)), V(-Math.sin(a), 0.2, Math.cos(a)).multiplyScalar(0.8 * U), 0.14 * U, 0xd9c9a0, 0.7, 1.6, 0.7); }
    } else if (t < 3.3) { // follow-through: keeps turning, dizzy
      const u = win(t, 2.35, 3.0); m.yaw = c.spin + 2.2 * E.out(u); c.M.copy(c.M0);
      mA = addPose(BOTH({RootJoint: [-4, 0, 0], Neck: [10, 0, 0], Head: [-6, 0, 0], ArmL: [-10, 0, 0]}), {Neck: [0, 14 * Math.sin(t * 7), 10 * Math.cos(t * 7)], Head: [0, 0, 10 * Math.sin(t * 7 + 1)]});
      at(c, "dizzy", 2.4, () => orbitStars(c, m, 3, 0.9));
    } else if (t < 4.95) { // walk to the bag, grab the handle, fling it up onto its back
      const yaw0 = c.spin + 2.2; const u = win(t, 3.45, 4.3);
      m.yaw = kf(t, [[3.3, yaw0], [3.5, c.yawBag + Math.round((yaw0 - c.yawBag) / (2 * Math.PI)) * 2 * Math.PI]]);
      c.M.copy(c.M0).lerp(c.Mpick, E.io(u)); c.matePh += dt * 2.2 * (u > 0 && u < 1 ? 1 : 0);
      const FLING = BOTH({RootJoint: [14, 0, 0], Neck: [46, 0, 0], Head: [26, 0, 0], Jaw: [-30, 0, 0], ArmL: [-30, 0, 0], LegL: [6, 0, 0], KneeL: [-14, 0, 0]});
      mA = pk(t, [[3.3, P.IDLE], [4.3, P.IDLE], [4.44, P.PECK, "out"], [4.52, P.PECK], [4.66, FLING, "out5"], [4.85, FLING], [4.95, P.PROUD]]);
      if (u > 0 && u < 1) mA = addPose(mA, walkLayer(c.matePh, 0.9, m));
      at(c, "backland", 4.85, () => { c.msq.v -= 6; c.bagSq.v -= 5; kick(m, "Neck", -300); dustRing(c.M.clone(), 8, 0.12 * U, 0.5 * U); });
    } else { // trots off wearing it
      const u = (t - 4.95), dir = V(-1, 0, -0.32).normalize(), yd = yawTo(V(0, 0, 0), dir);
      m.yaw = kf(t, [[4.95, c.yawBag], [5.2, yd + Math.round((c.yawBag - yd) / (2 * Math.PI)) * 2 * Math.PI]]);
      c.M.copy(c.Mpick).addScaledVector(dir, 1.5 * U * Math.max(0, u - 0.1)); c.matePh += dt * 3.0;
      mA = addPose(P.PROUD, walkLayer(c.matePh, 1, m)); mA = addPose(mA, {Jaw: [-10, 0, 0]});
    }
    m.sq = sStep(c.msq, dt);
    m.pos.copy(c.M); drive(m, mA, dt, mLayer, mDirect);
    // ---- carried ----
    let A, layer = null;
    if (t < 0.95) {
      r.plant = "feet"; r.pos.set(0, 0, 0); r.yaw = 0; r.rx = 0; r.rz = 0; setRigScale(r, r.base);
      A = pk(t, [[0, P.CHILL], [0.72, P.CHILL], [0.82, P.STARTLED, "out5"]]);
      if (t < 0.72) A = addPose(A, {Neck: [4 * Math.sin(t * 3), 22 * Math.sin(t * 2.6), 0], Head: [0, 10 * Math.sin(t * 2.6 - .5), 0]});
      at(c, "bang", 0.74, () => { iconPop(T.bang, headTop(r).add(V(0, 0.18 * U, 0)), 0.22 * U, 0.8, 0.1 * U); kick(r, "Neck", 300); c.sq.v += 3; });
      drive(r, A, dt, layer); r.sq = sStep(c.sq, dt);
    } else if (t < 2.35) { // swung by the tail
      const u = win(t, 0.95, 2.35); r.plant = "none"; r.sq = 1;
      const mo = mouthPt(m), out = V(mo.x - c.M.x, 0, mo.z - c.M.z).normalize();
      r.yaw = Math.atan2(-out.x, -out.z); r.rx = rad(10) * E.io(sat(u * 2)); r.rz = 2 * Math.PI * 0.8 * u * u;
      A = addPose(P.STARTLED, flailLayer(t, E.io(sat(u * 2.5))));
      r.pos.set(0, 0, 0); drive(r, A, dt, layer); const tt = tailTip(r); r.pos.set(mo.x - tt.x, mo.y - tt.y, mo.z - tt.z); poseRig(r, r.A);
      c.rel = {pos: r.pos.clone(), yaw: r.yaw, rx: r.rx, rz: r.rz};
    } else if (t < 3.05) { // flying
      const u = win(t, 2.35, 3.05), e = E.io(u); r.plant = "none";
      setRigScale(r, r.base * lerp(1, 0.7, E.out(u)));
      const p = c.rel.pos.clone().lerp(c.inBag, u); p.y += 4 * 1.1 * U * u * (1 - u); r.pos.copy(p);
      const yawT = Math.round(c.rel.yaw / (2 * Math.PI)) * 2 * Math.PI; r.yaw = lerp(c.rel.yaw, yawT, e);
      r.rx = lerp(c.rel.rx, rad(-92), E.out(u)); r.rz = lerp(c.rel.rz, Math.ceil(c.rel.rz / (2 * Math.PI) + 0.5) * 2 * Math.PI, e);
      A = addPose(P.STARTLED, flailLayer(t, 1)); drive(r, A, dt, layer);
      at(c, "whoosh", 2.4, () => { for (let i = 0; i < 5; i++) puff(r.pos.clone().add(V(0, 0.3 * U, 0)), V((Math.random() - .5) * U, 0.2 * U, (Math.random() - .5) * U), 0.15 * U, 0xffffff, 0.5, 1.5, 0.5); });
    } else { // in the bag
      setRigScale(r, r.base * 0.7); r.plant = "none"; r.yaw = 0; r.rx = rad(-92); r.rz = 0;
      const sink = E.in2(win(t, 3.85, 4.1)); r.pos.copy(c.inBag).lerp(c.deep, sink);
      const legs = flailLayer(t * 1.3, 1); A = addPose(P.STARTLED, {LegL: legs.LegL, LegR: legs.LegR, KneeL: legs.KneeL, KneeR: legs.KneeR, Tail1: [0, 20 * Math.sin(t * 13), 0], Tail2: [0, 26 * Math.sin(t * 13 - 1), 0], Tail3: [0, 30 * Math.sin(t * 13 - 2), 0]});
      drive(r, A, dt, layer);
      r.g.visible = t < 4.1;
      at(c, "landbag", 3.05, () => { c.bagSq.v -= 8; hitStop = 0.06; camState.shake = 0.7; dustRing(c.B.clone(), 12, 0.2 * U, 0.9 * U); });
      at(c, "gulp", 4.05, () => { c.bagSq.v -= 6; puff(c.B.clone().add(V(0, c.bh * 1.1, 0)), V(0, 0.4 * U, 0), 0.15 * U, 0xffffff, 0.5, 2, 0.6); });
    }
    // ---- bag ----
    const bs = sStep(c.bagSq, dt), bulge = t > 4.95 ? 1 + 0.1 * Math.max(0, Math.sin((t - 4.95) * 5.5)) ** 8 : 1;
    const sqM = new THREE.Matrix4().makeScale(1 / Math.sqrt(bs) * bulge, bs, 1 / Math.sqrt(bs) * bulge);
    const tb = m.segBox.Torso, backL = V((tb.min.x + tb.max.x) / 2, tb.max.y * 0.95, lerp((tb.min.z + tb.max.z) / 2, tb.max.z, 0.35)), kb = clamp(0.42 * m.H / c.bh, 0.25, 1);
    const onBack = () => r0bag.copy(m.segW.Torso).multiply(new THREE.Matrix4().makeTranslation(backL.x, backL.y, backL.z)).multiply(new THREE.Matrix4().makeScale(kb / m.scale, kb / m.scale, kb / m.scale));
    const r0bag = new THREE.Matrix4(); bag.g.matrixAutoUpdate = false;
    if (t < 4.52) bag.g.matrix.compose(c.B, new THREE.Quaternion(), V(1, 1, 1)).multiply(sqM);
    else if (t < 4.85) { // flung in an arc over its head, flipping, shrinking to backpack size
      const u = win(t, 4.52, 4.85), e = E.io(u); onBack(); const end = V(0, 0, 0).setFromMatrixPosition(r0bag), p = c.B.clone().lerp(end, e); p.y += 4 * 0.9 * U * u * (1 - u);
      const q0 = new THREE.Quaternion(), q1 = new THREE.Quaternion().setFromRotationMatrix(new THREE.Matrix4().extractRotation(r0bag)), q = q0.slerp(q1, e).multiply(new THREE.Quaternion().setFromAxisAngle(V(1, 0, 0), 2 * Math.PI * e));
      const k = lerp(1, kb, e); bag.g.matrix.compose(p, q, V(k, k, k)).multiply(sqM);
    } else { onBack(); const bob = new THREE.Matrix4().makeTranslation(0, Math.abs(Math.sin(c.matePh * Math.PI * 2)) * 0.06 * c.bh, 0); bag.g.matrix.copy(r0bag).multiply(bob).multiply(sqM); }
    const zu = win(t, 3.2, 3.85);
    bag.cover.visible = zu > 0; bag.pull.visible = zu > 0; const cw = c.bw * 0.86 * (t < 4.05 ? 0.78 : 1) * zu;
    bag.cover.scale.x = Math.max(0.001, cw); bag.cover.position.x = -c.bw * 0.43 + cw / 2; bag.pull.position.set(-c.bw * 0.43 + cw, c.bh * 1.1, -c.bd * 0.42);
    if (zu > 0 && zu < 1) { c.zT = (c.zT || 0) - dt; if (c.zT <= 0) { c.zT = 0.05; sparks(bag.pull.getWorldPosition(V(0, 0, 0)), 2, 0.025 * U, 0xffe080, 0.4 * U, 2 * U); } }
    bag.tailP.visible = t > 4.1; if (bag.tailP.visible) { bag.tailP.rotation.set(-0.9 + 0.25 * Math.sin(t * 9), 0.5 * Math.sin(t * 6), 0); }
    at(c, "mmph", 4.25, () => { const s = textSprite("mmph!", "#ffffff", 0.16 * U, "#1d2a44"); s.position.copy(c.B).add(V(0.2 * U, c.bh * 1.5, 0)); addFx(s, 1.1, (o, u) => { o.position.y += 0.002 * U; o.material.opacity = u > 0.7 ? (1 - u) / 0.3 : 1; }); });
    at(c, "mmph2", 5.3, () => { const s = textSprite("mmph!!", "#ffffff", 0.14 * U, "#1d2a44"); s.position.setFromMatrixPosition(bag.g.matrix).add(V(0, c.bh * 0.9, 0)); addFx(s, 1.0, (o, u) => { o.material.opacity = u > 0.7 ? (1 - u) / 0.3 : 1; }); });
    const fb = new THREE.Box3(), bagBox = new THREE.Box3().setFromObject(bag.g);
    if (t < 2.35) { fb.union(worldBox(m)); if (r.g.visible) fb.union(worldBox(r)); }
    else if (t < 3.1) { fb.union(bagBox); if (r.g.visible) fb.union(worldBox(r)); }
    else if (t < 4.5) { fb.union(bagBox); fb.expandByScalar(0.5 * U); if (t > 3.6) fb.union(worldBox(m)); }
    else { fb.union(worldBox(m)); fb.union(bagBox); fb.expandByScalar(0.4 * U); }
    camFrame(fb, t < 2.35 && t > 0.95 ? V(-0.35, 0.85, -1) : V(-0.42, 0.42, -1), dt, t < 0.95 ? 0.8 : 1.0, 0.9 * U);
  },
});

// =====================================================================================================================
// 7 · PACIFIST — a daisy pops up; it sniffs it... ah... ah... ACHOO! The sneeze blasts every petal off and knocks it
// flat on its back, legs twitching in the air; a butterfly lands on its foot.
TITLES.push({
  id: "pacifist", name: "PACIFIST", kind: "roast", cap: "Won without hurting a fly", stat: "0 KILLS", len: 5.6,
  rule: "0 kills", src: "counted today", beats: "A daisy pops up and it stops to sniff it... ah... ah... ACHOO! The sneeze blasts every petal off and knocks it flat on its back, legs twitching in the air, while a butterfly lands on its foot.",
  setup(c) {
    const r = c.r, U = r.U, m0 = peckPoint(r, P.SNIFF);
    const fh = Math.max(0.1 * U, m0.y - 0.07 * U), g = new THREE.Group(), stem = [];
    let parent = g; const n = 4;
    for (let i = 0; i < n; i++) { const s = new THREE.Group(); s.position.y = i ? fh / n : 0; parent.add(s); const seg = bx(0.014 * U, fh / n, 0.014 * U, 0x3f9a3a); seg.position.y = fh / n / 2; s.add(seg); stem.push(s); parent = s; }
    for (const sx of [-1, 1]) { const lf = bx(0.09 * U, 0.008 * U, 0.04 * U, 0x4caa44); lf.position.set(sx * 0.05 * U, 0.01 * U, 0); lf.rotation.z = sx * 0.4; stem[1].add(lf); }
    const head = new THREE.Group(); head.position.y = fh / n; parent.add(head);
    const ctr = mesh(new THREE.CylinderGeometry(0.035 * U, 0.035 * U, 0.02 * U, 16), 0xffc832); head.add(ctr);
    const petals = []; for (let i = 0; i < 12; i++) { const a = i / 12 * Math.PI * 2, pv = new THREE.Group(); pv.rotation.y = a; const p = bx(0.075 * U, 0.008 * U, 0.03 * U, 0xffffff); p.position.x = 0.07 * U; pv.add(p); head.add(pv); petals.push({pv, p, a}); }
    head.rotation.x = -0.5; g.position.set(m0.x, 0, m0.z - 0.04 * U); c.props.add(g); c.fl = {g, stem, head, petals, fh};
    // butterflies
    c.bf = [0, 1].map(i => { const b = new THREE.Group(), body = bx(0.012 * U, 0.012 * U, 0.05 * U, 0x2a2018); b.add(body);
      const wm = new THREE.MeshLambertMaterial({color: i ? 0x7fd0ff : 0xffa040, side: THREE.DoubleSide});
      const wl = new THREE.Group(), wr = new THREE.Group(); const w1 = new THREE.Mesh(new THREE.PlaneGeometry(0.05 * U, 0.045 * U), wm); w1.rotation.x = -Math.PI / 2; w1.position.x = 0.026 * U; wl.add(w1); const w2 = w1.clone(); w2.position.x = -0.026 * U; wr.add(w2); b.add(wl, wr);
      c.props.add(b); return {b, wl, wr, i}; });
    c.fallZ = 0;
  },
  update(c, t, dt) {
    const r = c.r, U = r.U, F = c.fl;
    const AH1 = addPose(P.SNIFF, {Neck: [14, 0, 0], Head: [18, 0, 0], Jaw: [-10, 0, 0]}), AH2 = BOTH({RootJoint: [2, 0, 0], Neck: [16, 0, 0], Head: [24, 0, 0], Jaw: [-18, 0, 0], ArmL: [-14, 0, 0]}), AH3 = BOTH({RootJoint: [14, 0, 0], Neck: [36, 0, 0], Head: [34, 0, 0], Jaw: [-28, 0, 0], ArmL: [-30, 0, 0], Tail1: [-10, 0, 0]});
    const CHOO = BOTH({RootJoint: [-12, 0, 0], Neck: [-34, 0, 0], Head: [-14, 0, 0], Jaw: [-55, 0, 0], ArmL: [24, 0, 0], Tail1: [-14, 0, 0]});
    const ONBACK = BOTH({RootJoint: [-4, 0, 0], Neck: [-16, 0, 0], Head: [-8, 0, 0], Jaw: [-26, 0, 0], ArmL: [-30, 0, 16], LegL: [14, 0, 12], KneeL: [-30, 0, 0], AnkleL: [16, 0, 0], Tail1: [-6, 0, 0], Tail2: [-4, 0, 0]}); ONBACK.Neck = [-28, 26, 0]; ONBACK.Head = [-10, 10, 18];
    const WATCH = BOTH({Neck: [-12, 0, 0], Head: [-6, 0, 0]}); WATCH.Head = [-6, 0, 14];
    const A = pk(t, [[0, P.IDLE], [0.3, WATCH], [0.65, WATCH], [1.1, P.SNIFF], [1.42, P.SNIFF], [1.55, AH1, "out"], [1.78, AH1], [1.88, AH2, "out"], [2.08, AH2], [2.2, AH3, "out"], [2.38, AH3], [2.44, CHOO, "out5"], [2.62, CHOO], [2.95, ONBACK, "out"], [5.6, ONBACK]]);
    let layer = null;
    if (t > 1.5 && t < 2.4) { const k = win(t, 1.5, 2.38); layer = {Neck: [3 * Math.sin(t * 50) * k, 0, 0], Head: [2.5 * Math.sin(t * 61) * k, 0, 0], Jaw: [-3 * Math.abs(Math.sin(t * 40)) * k, 0, 0]}; }
    if (t > 2.95) { const burst = Math.max(0, Math.sin(t * 2.3)) ** 6 + (t < 3.8 ? 1 - win(t, 2.95, 3.8) : 0); layer = {KneeL: [16 * Math.sin(t * 24) * burst, 0, 0], KneeR: [16 * Math.sin(t * 24 + 1.6) * burst, 0, 0], AnkleL: [12 * Math.sin(t * 24 + .5) * burst, 0, 0], AnkleR: [12 * Math.sin(t * 24 + 2.1) * burst, 0, 0], Tail3: [0, 6 * Math.sin(t * 3), 0]}; }
    // inhale + recoil fall
    c.sq.tg = t > 1.0 && t < 2.38 ? 1 + 0.04 * win(t, 1.0, 1.4) + 0.06 * win(t, 1.5, 2.38) : 1;
    at(c, "choo", 2.42, () => { c.sq.v -= 4; kick(r, "Neck", -520); camState.shake = 1.2; hitStop = 0.05;
      const mp = mouthPt(r), d = mp.clone().sub(headC(r)).normalize(); flash(mp, 0.6 * U, 0xffffff, 0.2);
      for (let i = 0; i < 18; i++) puff(mp.clone(), d.clone().multiplyScalar((1.2 + Math.random() * 1.6) * U).add(V((Math.random() - .5) * U, (Math.random() - .5) * 0.6 * U, (Math.random() - .5) * U)), (0.1 + Math.random() * 0.12) * U, 0xffffff, 0.9, 2.4, 0.8);
      // petals blown off
      F.petals.forEach((pt, i) => { const w = pt.p.getWorldPosition(V(0, 0, 0)); pt.pv.visible = false; const pm = bx(0.075 * U, 0.008 * U, 0.03 * U, 0xffffff); pm.position.copy(w);
        addDebris(pm, d.clone().multiplyScalar((0.9 + Math.random() * 1.1) * U).add(V((Math.random() - .5) * 0.8 * U, (0.6 + Math.random() * 0.8) * U, (Math.random() - .5) * 0.8 * U)), V(Math.random() * 8, Math.random() * 8, Math.random() * 8), {r: 0.004 * U, grav: 0.9 * U, drag: 0.04, flutter: 2 * U, life: 3.1, bounce: 0}); });
      c.bf.forEach(b => b.blown = 0); });
    const fall = E.in2(win(t, 2.5, 2.9));
    r.rz = Math.PI * fall; r.rx = rad(-8) * Math.sin(Math.PI * fall); r.plant = t > 2.5 ? "all" : "feet"; r.pos.set(0.12 * U * Math.sin(Math.PI * fall), 0.25 * U * Math.sin(Math.PI * fall), 0.32 * U * E.out(win(t, 2.45, 2.9)));
    at(c, "thud", 2.9, () => { c.sq.v -= 6; camState.shake = 0.9; dustRing(r.pos.clone(), 14, 0.22 * U, 1.0 * U); orbitStars(c, r, 4, 1.4, 0.2); });
    r.sq = sStep(c.sq, dt);
    drive(r, A, dt, layer);
    // flower
    const grow = E.back(win(t, 0.08, 0.45)); F.g.scale.set(1, Math.max(0.001, grow), 1);
    F.petals.forEach((pt, i) => { const k = E.back(win(t, 0.3 + i * 0.02, 0.45 + i * 0.02)); pt.pv.scale.setScalar(Math.max(0.001, k)); });
    const lean = t > 1.0 && t < 2.42 ? 0.14 * win(t, 1.0, 1.4) : 0, droop = t > 2.6 ? 0.42 * E.bounce(win(t, 2.7, 3.6)) : 0;
    F.stem.forEach((s, i) => { s.rotation.x = (lean + droop) * (i ? 1 : 0.4) + (t < 2.42 ? 0.04 * Math.sin(t * 6 + i) * (t > 1.0 ? 2 : 1) : 0); });
    at(c, "bloom", 0.6, () => { sparks(F.head.getWorldPosition(V(0, 0, 0)), 10, 0.03 * U, 0xffffff, 0.5 * U, 1 * U); });
    // butterflies
    const fp = F.head.getWorldPosition(V(0, 0, 0)), foot = segC(r, "FootL");
    c.bf.forEach((b, i) => { let p;
      const orbit = V(fp.x + Math.cos(t * 2.2 + i * 3) * 0.3 * U, fp.y + 0.15 * U + Math.sin(t * 3.1 + i) * 0.08 * U, fp.z + Math.sin(t * 2.2 + i * 3) * 0.3 * U);
      if (t < 2.42) p = orbit;
      else if (t < 3.6) { b.blown = (b.blown || 0) + dt; p = (b.from || (b.from = b.b.position.clone())).clone().add(V((i ? -1 : 1) * 0.8 * U * E.out(sat(b.blown)), 0.5 * U * E.out(sat(b.blown)), 0.3 * U)); b.away = p.clone(); }
      else { const landT = i === 0 ? 4.4 : 5.0, u = E.io(win(t, 3.6, landT)), tgt = i === 0 ? foot.clone().add(V(0, 0.03 * U, 0)) : headTop(r).add(V(0.25 * U, 0.35 * U + Math.sin(t * 2) * 0.05 * U, 0)); p = b.away.clone().lerp(tgt, u).add(V(0, Math.sin(u * Math.PI) * 0.2 * U, 0)); }
      const dv = p.clone().sub(b.b.position); b.b.position.copy(p); if (dv.lengthSq() > 1e-6) b.b.rotation.y = Math.atan2(dv.x, dv.z);
      const perched = i === 0 && t > 4.4; const fl = perched ? 0.25 + 0.35 * Math.max(0, Math.sin(t * 3)) : 0.9 * Math.sin(t * 30 + i);
      b.wl.rotation.z = fl; b.wr.rotation.z = -fl; });
    camShot(c, t, dt, [[0, [-0.6, 0.3, -1], 0.9, 0, 0], [1.15, [-0.62, 0.2, -1], 0.62, 0, 0.5], [2.3, [-0.62, 0.24, -1], 0.68, 0, 0.45], [2.95, [-0.6, 0.75, -1], 0.85, 0, 0], [5.6, [-0.65, 0.8, -1], 0.9, 0, 0]], worldBox(r).union(new THREE.Box3().setFromObject(c.fl.g)), headC(r));
  },
});

// =====================================================================================================================
// 8 · EXTINCT — happy little dance; a shadow grows under it, the sky turns orange, it looks up, jaw drops... METEOR.
// White-out. A fossil pancake in a crater, a museum sign pops up, and its ghost floats up waving, halo and all.
TITLES.push({
  id: "extinct", name: "EXTINCT", kind: "roast", cap: "Died the most. Again.", stat: "6 DEATHS", len: 5.8,
  rule: "Most deaths on the team (at least 4)", src: "counted today", beats: "Doing a happy little dance. A shadow grows under it and the sky turns orange; it looks up and its jaw drops... METEOR. White-out. A fossil pancake in a crater, a museum sign pops up, and its ghost floats up and waves, halo and all.",
  setup(c) {
    const r = c.r, U = r.U;
    const sh = new THREE.Mesh(new THREE.CircleGeometry(1, 48), new THREE.MeshBasicMaterial({color: 0x000000, transparent: true, opacity: 0, depthWrite: false})); sh.rotation.x = -Math.PI / 2; sh.position.y = 0.06; c.props.add(sh); c.shadow = sh;
    c.met = meteorMesh(0.55 * U, true); c.met.visible = false; c.props.add(c.met);
    const cr = new THREE.Group(); const floor = new THREE.Mesh(new THREE.CircleGeometry(0.95 * U, 40), new THREE.MeshLambertMaterial({color: 0x3a2e24})); floor.rotation.x = -Math.PI / 2; floor.position.y = 0.07; floor.receiveShadow = true; cr.add(floor);
    for (let i = 0; i < 22; i++) { const a = i / 22 * Math.PI * 2, rk = rock((0.06 + Math.random() * 0.06) * U, i % 2 ? 0x5a4a3e : 0x4a3c30); rk.position.set(Math.cos(a) * 1.0 * U, 0.03 * U, Math.sin(a) * 1.0 * U); cr.add(rk); }
    cr.visible = false; c.props.add(cr); c.crater = cr;
    // museum sign
    const sg = new THREE.Group(); const post = bx(0.04 * U, 0.45 * U, 0.04 * U, 0x5a3e24); post.position.y = 0.22 * U; sg.add(post);
    const board = new THREE.Mesh(new THREE.BoxGeometry(0.62 * U, 0.34 * U, 0.03 * U), [0, 0, 0, 0, 0, 0].map((_, i) => i === 5 ? textBoard(512, 280, (x, w, h) => {
      x.fillStyle = "#5a3e24"; x.fillRect(0, 0, w, h); x.fillStyle = "#e9dcc0"; x.fillRect(14, 14, w - 28, h - 28); x.strokeStyle = "#8a6a40"; x.lineWidth = 6; x.strokeRect(26, 26, w - 52, h - 52);
      x.fillStyle = "#3a2a18"; x.textAlign = "center"; x.font = "700 30px 'Silkscreen', monospace"; x.fillText("EXHIBIT 6", w / 2, 78); x.font = "700 62px 'Silkscreen', monospace"; x.fillText("EXTINCT", w / 2, 150);
      x.font = "700 24px 'Silkscreen', monospace"; x.fillText("DIED 6 TIMES", w / 2, 198); x.fillStyle = "#7a5a30"; x.fillText("LATE MECHAZOIC", w / 2, 236); }) : new THREE.MeshLambertMaterial({color: 0x5a3e24})));
    board.position.y = 0.5 * U; board.castShadow = true; sg.add(board);
    sg.position.set(-0.85 * U, 0, -0.75 * U); sg.rotation.y = 0.45; sg.scale.setScalar(0.001); c.props.add(sg); c.sign = sg;
    // halo for the ghost
    c.halo = new THREE.Mesh(new THREE.TorusGeometry(0.1 * U, 0.016 * U, 8, 24), new THREE.MeshBasicMaterial({color: 0xffe070, transparent: true})); c.halo.rotation.x = Math.PI / 2; c.halo.visible = false; c.props.add(c.halo);
  },
  update(c, t, dt) {
    const r = c.r, U = r.U, gh = c.gh;
    const LDOWN = BOTH({Neck: [-26, 0, 0], Head: [-10, 0, 0], ArmL: [-10, 0, 0]}); LDOWN.Head = [-10, 0, 18];
    const GAPE = addPose(P.LOOK_UP, {Jaw: [-12, 0, 0], ArmL: [-14, 0, 0]});
    let A = pk(t, [[0, P.HAPPY], [1.0, P.HAPPY], [1.2, LDOWN], [1.45, LDOWN], [1.85, GAPE, "out"], [2.3, GAPE]]);
    let layer = null;
    const dance = 1 - win(t, 0.85, 1.05);
    if (t < 1.1) { layer = {RootJoint: [0, 10 * Math.sin(t * 7) * dance, 6 * Math.sin(t * 7) * dance], Neck: [8 * Math.abs(Math.sin(t * 10)) * dance, 0, 0], ArmL: [0, 0, 26 * Math.sin(t * 10) * dance], ArmR: [0, 0, -26 * Math.sin(t * 10 + 1) * dance], Tail2: [0, 18 * Math.sin(t * 7) * dance, 0], Tail3: [0, 24 * Math.sin(t * 7 - .8) * dance, 0], Tail4: [0, 26 * Math.sin(t * 7 - 1.6) * dance, 0]}; }
    if (t > 1.6 && t < 2.3) layer = {KneeL: [3 * Math.sin(t * 60), 0, 0], KneeR: [3 * Math.sin(t * 60 + 1), 0, 0], Jaw: [-3 * Math.abs(Math.sin(t * 40)), 0, 0]};
    // dance hops
    r.pos.set(0, t < 1.05 ? 0.07 * U * Math.abs(Math.sin(t * Math.PI * 3.2)) * dance : 0, 0); r.yaw = t < 1.05 ? 0.22 * Math.sin(t * Math.PI * 1.6) * dance : 0;
    // doom: shadow + sky
    const dm = E.in2(win(t, 0.8, 2.3)); c.shadow.scale.setScalar(Math.max(0.01, (0.1 + 1.3 * dm) * U)); c.shadow.material.opacity = 0.55 * win(t, 0.8, 1.3) * (t < 2.3 ? 1 : 0);
    const sk = t < 2.3 ? E.io(win(t, 0.9, 2.2)) : 1 - E.io(win(t, 2.6, 4.2)); scene.background.copy(SKY).lerp(SKY_DOOM, sk * 0.85); scene.fog.color.copy(scene.background);
    // meteor
    const M0 = V(0.8 * U, 7.5 * U, 2.4 * U), M1 = V(0, 0.6 * U, 0.1 * U);
    if (t > 1.35 && t < 2.3) { c.met.visible = true; c.met.position.copy(M0).lerp(M1, win(t, 1.35, 2.3)); c.met.userData.rock.rotation.x += dt * 3; trail(c.met.position, U, 0.7 * U, 3); }
    at(c, "impact", 2.3, () => { c.met.visible = false; hitStop = 0.14; camState.shake = 1.8;
      c.crater.visible = true; c.shadow.visible = false; stoneTint(r, 1);
      for (let i = 0; i < 30; i++) { const a = Math.random() * Math.PI * 2; puff(V(Math.cos(a) * 0.3 * U, 0.2 * U, Math.sin(a) * 0.3 * U), V(Math.cos(a) * (1.5 + Math.random() * 2) * U, (0.3 + Math.random() * 0.9) * U, Math.sin(a) * (1.5 + Math.random() * 2) * U), (0.25 + Math.random() * 0.2) * U, i % 3 ? 0xb8a888 : 0x8a7a68, 1.6, 2.4, 0.9); }
      for (let i = 0; i < 18; i++) { const a = Math.random() * Math.PI * 2, s = (0.04 + Math.random() * 0.07) * U, rk = rock(s); rk.position.set(0, 0.3 * U, 0); addDebris(rk, V(Math.cos(a) * (1 + Math.random() * 1.5) * U, (1.5 + Math.random() * 1.5) * U, Math.sin(a) * (1 + Math.random() * 1.5) * U), V(Math.random() * 8, Math.random() * 8, Math.random() * 8), {r: s, grav: 5 * U, life: 3.4, bounce: 0.35}); } });
    const fo = $("flashov"); fo.style.transition = "none"; fo.style.opacity = t < 2.3 ? 0 : 1 - E.in2(win(t, 2.42, 3.1));
    const fossil = t >= 2.3;
    if (fossil) { A = P.FLAT; r.sq = 0.3; r.sqx = 1.35; r.sqz = 1.25; r.plant = "all"; r.pos.set(0, 0.07, 0); snapSprings(r, A); }
    if (t > 2.6 && t < 4.6) { c.smT = (c.smT || 0) - dt; if (c.smT <= 0) { c.smT = 0.12; puff(V((Math.random() - .5) * 0.8 * U, 0.05 * U, (Math.random() - .5) * 0.6 * U), V(0, 0.35 * U, 0), 0.12 * U, 0x8a8078, 1.4, 2, 0.45); } }
    drive(r, A, dt, layer, fossil);
    // sign
    const sgk = E.back(win(t, 3.2, 3.55)); c.sign.scale.setScalar(Math.max(0.001, sgk)); at(c, "sign", 3.25, () => dustRing(c.sign.position.clone(), 8, 0.1 * U, 0.4 * U));
    // ghost
    gh.g.visible = t > 3.45;
    if (gh.g.visible) { const u = win(t, 3.45, 5.8); setRigScale(gh, r.base); gh.plant = "none"; gh.pos.set(Math.sin(t * 2) * 0.06 * U, 0.05 * U + 1.25 * U * E.io(u), 0); gh.yaw = 0.3 * Math.sin(t * 1.3) - 0.25; gh.rx = 0; gh.rz = 0.1 * Math.sin(t * 2.2);
      const GW = BOTH({Neck: [-6, 0, 0], Head: [-4, 0, 0], Tail1: [16, 0, 0], Tail2: [10, 0, 0], Tail3: [8, 0, 0], LegL: [10, 0, 0], KneeL: [-20, 0, 0]}); GW.Head = [-4, 0, 16]; GW.ArmR = [-70, 0, -30 - 25 * Math.sin(t * 9)]; GW.ArmL = [-10, 0, 0];
      drive(gh, GW, dt, {Tail4: [0, 10 * Math.sin(t * 3), 0], Tail5: [0, 14 * Math.sin(t * 3 - 1), 0]});
      gh.ghostMat.opacity = 0.5 * win(t, 3.45, 3.9) * (1 - win(t, 5.3, 5.8));
      c.halo.visible = true; c.halo.position.copy(headTop(gh)).add(V(0, 0.14 * U + 0.015 * U * Math.sin(t * 4), 0)); c.halo.material.opacity = gh.ghostMat.opacity * 1.8; }
    at(c, "cut", 2.3, () => { c.camSnap = true; }); const ebox = worldBox(r); if (gh.g.visible) ebox.union(worldBox(gh));
    camShot(c, t, dt, [[0, [-0.5, 0.3, -1], 0.92, 0, 0], [1.35, [-0.5, 0.24, -1], 0.8, 0, 0.3], [1.6, [-0.42, -0.08, -1], 0.7, 0.9, 0.2, "out"], [2.29, [-0.42, -0.08, -1], 0.7, 0.75, 0.2], [2.31, [-0.4, 1.3, -0.7], 1.2, 0, 0, "lin"], [3.4, [-0.55, 0.8, -1], 1.25, 0, 0], [5.8, [-0.55, 0.45, -1], 1.15, 0, 0]], ebox, headC(r), c.met.visible ? c.met.position : null, kf(t, [[1.4, 0], [1.7, 0.12], [2.25, 0.05], [2.3, 0]]));
  },
});
