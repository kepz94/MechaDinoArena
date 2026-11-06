// export_herrera_parts_v2.js v1.0 (Mecha Dino Arena) — exports the 11 picked Herrerasaurus part looks from the redesign
// mockup (docs/mockups/herrera_parts_redesign.html v0.2; Kepu 2026-11-05 19:39 picks "A for everything except B for the Quill
// launcher") to src/shared/HerreraPartsLooksV2.luau. Plan docs/plans/HERRERA_PARTS_LOOKS_v2.0.md Task 1 (MDA-287). From
// export_teno_parts_v2.js 1.0 (same piece / group rows), plus the cables (the Fang Siphons' tubes) as beams
// {a0, p0, a1, p1, d}: a Beam between two anchor-relative points on two body parts. No struts on the Herrera.
// Run: python3 tools/mockup/build_herrera_parts_v2.py && node tools/mockup/export_herrera_parts_v2.js
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const ROOT = path.resolve(__dirname, '..', '..');
const PICKS = [["ironclaw", 0], ["glider", 0], ["quills", 1], ["smoke", 0], ["plating", 0], ["siphon", 0], ["strobe", 0], ["breaker", 0], ["caltrops", 0], ["goo", 0], ["hadren", 0]];
(async () => {
  const b = await chromium.launch({args: ['--use-gl=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist']});
  const p = await b.newPage();
  const errs = []; p.on('pageerror', e => errs.push(String(e)));
  await p.goto('file://' + path.join(ROOT, 'docs', 'mockups', 'herrera_parts_redesign.html'));
  await p.waitForTimeout(600);
  const out = await p.evaluate((PICKS) => {
    const r3 = v => { const x = Math.round(v * 1000) / 1000; return Object.is(x, -0) ? 0 : x; };
    const r2 = v => { const x = Math.round(v * 100) / 100; return Object.is(x, -0) ? 0 : x; };
    const dec = m => { const P = new THREE.Vector3(), Q = new THREE.Quaternion(), S = new THREE.Vector3(); m.decompose(P, Q, S); return {P, Q, S}; };
    // position + XYZ Euler degrees (three's "XYZ" = Rx * Ry * Rz = Roblox CFrame.Angles(rx, ry, rz)), scale ignored
    const comps = m => { const {P, Q} = dec(m), e = new THREE.Euler().setFromQuaternion(Q, "XYZ"), d = THREE.MathUtils.radToDeg; return [r3(P.x), r3(P.y), r3(P.z), r2(d(e.x)), r2(d(e.y)), r2(d(e.z))]; };
    const unscaled = m => { const {P, Q} = dec(m); return new THREE.Matrix4().compose(P, Q, new THREE.Vector3(1, 1, 1)); };
    const res = {};
    pose({});
    for (const [pid, li] of PICKS) {
      cur = PARTS.findIndex(x => x.id === pid); look = li; old = false; plan = -1; use = 0; t = 0; build(); pose({}); updateEquip();
      const mounts = [], mkey = [];
      const mountOf = (part, mo) => { const fr = comps(mo), k = part + ':' + fr.join(','); let i = mkey.indexOf(k); if (i < 0) { mkey.push(k); mounts.push({anchor: part, frame: fr}); i = mounts.length - 1; } return i + 1; };
      const pieces = [], struts = [];
      for (const e of equip) {
        if (e.strut) { const s = e.strut; const ia = dino.byName[s.pa].cf.clone().invert(), ib = dino.byName[s.pb].cf.clone().invert();
          struts.push({a0: s.pa, p0: new THREE.Vector3(...s.a).applyMatrix4(ia).toArray().map(r3), a1: s.pb, p1: new THREE.Vector3(...s.b).applyMatrix4(ib).toArray().map(r3), f0: s.f0, f1: s.f1, d: s.d, mat: s.key}); continue; }
        const film = !!e.film && !e.solid;
        if (film && !e.role) continue; // FX-only films: the animation pass
        if (e.show && !e.show(0, 0) && !film && !e.keep) continue;
        const mo = unscaled(e.mountOff), scaled = e.mountOff;
        const placeL = e.place ? e.place(e.filmAt || 0, 0) : scaled.clone().invert().multiply(e.off); // in the (scaled) mount frame
        const L = mo.clone().invert().multiply(scaled).multiply(placeL); // in the unscaled mount frame
        const {S} = dec(L), s = e.s;
        let size;
        if (e.sh === "cyl" || e.sh === "cone") size = [s[0] * (S.x + S.z) / 2, s[1] * S.y, 0];
        else if (e.sh === "ring") size = [s[0] * (S.x + S.y) / 2, s[1] * Math.min(S.x, S.y), 0];
        else if (e.sh === "ball") size = [s[0] * S.x, s[1] * S.y, s[2] * S.z];
        else size = [s[0] * S.x, s[1] * S.y, s[2] * S.z];
        const col = e.key === "white" ? e.mesh.material.color.getHex() : 0;
        pieces.push({mount: mountOf(e.part, mo), shape: e.sh, size: size.map(v => r3(v || 0)), off: comps(L), mat: e.key, role: e.role || "", group: e.group || "",
          flags: (e.detail ? 1 : 0) + (film ? 2 : 0) + (e.keep && !e.solid ? 4 : 0), color: col, alpha: e.solid || 1});
      }
      const groups = GROUPS.map(g => { const mo = unscaled(g.mountOff); const L = mo.clone().invert().multiply(g.mountOff).multiply(g.local);
        return {name: g.name, mount: mountOf(g.part, mo), pivot: comps(L), type: g.motion.type, axis: g.motion.axis, amt: Math.round(g.motion.amt * 10000) / 10000 * (g.motion.type === "slide" ? dec(g.mountOff).S.x : 1), parent: g.parent || ""}; });
      const beams = cables.map(c => ({a0: c.pa, p0: new THREE.Vector3(...c.a).applyMatrix4(dino.byName[c.pa].cf.clone().invert()).toArray().map(r3), a1: c.pb, p1: new THREE.Vector3(...c.b).applyMatrix4(dino.byName[c.pb].cf.clone().invert()).toArray().map(r3), d: c.d}));
      res[pid] = {look: PARTS[cur].looks[li].name, glow: AREA[PARTS[cur].area][2], mounts, pieces, groups, struts, beams, hides: [...HIDDEN]};
    }
    return res;
  }, PICKS);
  await b.close();
  if (errs.length) { console.error(errs); process.exit(1); }
  const q = s => JSON.stringify(s);
  const arr = a => '{' + a.join(', ') + '}';
  let L = `-- HerreraPartsLooksV2 v1.0 (Mecha Dino Arena) — GENERATED by tools/mockup/export_herrera_parts_v2.js 1.0 from
-- docs/mockups/herrera_parts_redesign.html v0.2 (Kepu 2026-11-05 19:39 picks: Iron Claw A Wing Blades, Glider Wings A Sword
-- Wings, Quill Launcher B Missile Pods, Smoke Pods A Stealth Generator, Back Plating A Lamellar Armour, Blood Siphon A Fang
-- Siphons, Strobe Frill A Flash Crest, Stun Breaker A Tesla Coils, Razor Caltrops A Drop Chute, Goo Blob Shooter A Spit Sacs,
-- Adrenaline Injector A Stim Shot). Plan docs/plans/HERRERA_PARTS_LOOKS_v2.0.md Task 1 (MDA-287). Do not edit by hand:
-- change the mockup, re-export.
-- ServerStorage.DinoArcade.HerreraPartsLooksV2 (ModuleScript). Scale 1 = HerreraModelData units (the server multiplies
-- positions and sizes by the model's scale). LOOKS[id] = {look, glow (Color3), mounts, pieces, groups, struts, beams, hides}:
-- A frame = x, y, z, rx, ry, rz: CFrame.new(x, y, z) * CFrame.Angles(rad rx, rad ry, rad rz).
--   mount = {anchor (HerreraModelData part), frame (relative to the anchor)}
--   piece = {mount, shape ("box" | "wedge" | "cyl" | "ball" | "cone" | "ring"), sx, sy, sz (cyl / cone: diameter, length along
--     the piece's Y, 0; ring: radius, tube, 0, a torus about the piece's Z; ball: x, y, z diameters, an ellipsoid when they
--     differ), frame (6, in the mount's frame), mat (kit key), role ("" = none; the HPartRole the FX scripts read), group
--     ("" = none), flags (1 = detail, dropped by "lite"; 2 = film: see-through, shown only while the move plays; 4 = hidden at
--     rest), colour (0 = the kit's / the part's glow), alpha (opacity at rest, 1 = solid)}
--   group = {name, mount, frame (6: the pivot), type ("spin" | "swing" | "slide"), axis ("X" | "Y" | "Z"), amt (spin rad/s;
--     swing degrees at full; slide units at full, x scale), parent ("" = none)}
--   beam = {a0, p0, a1, p1 (anchor-relative points on two body parts), d (width)}: a dark rubber Beam (the siphon tubes).
--   hides = the body parts this look hides (the 7 back quills for the Lamellar Armour).
-- The camera side is +X = the model's "...L" parts.
local M = {}
M.Version = "1.0"
M.KIT = {shell = {0x5a636f, "stud"}, plate = {0x828c99, "stud"}, trim = {0x26292f, "plain"}, bone = {0xe2dccb, "plain"},
	ivory = {0xcfc6ae, "stud"}, brass = {0xc9a24a, "metal"}, steel = {0x9aa3ad, "metal"}, iron = {0x5d636c, "metal"},
	rubber = {0x16171b, "plain"}, hazY = {0xffc832, "plain"}, hazK = {0x1a1a1a, "plain"}, glow = {0, "neon"}, white = {0xf4f8ff, "neon"},
	dark = {0x3a3f47, "metal"}, bright = {0xd3dbe6, "metal"}, copper = {0xc8743a, "metal"}, lime = {0xa6e22e, "neon"},
	blood = {0xd0202a, "neon"}, adr = {0x46e08a, "neon"}}
M.LOOKS = {}
`;
  for (const [pid] of PICKS) {
    const d = out[pid];
    L += `M.LOOKS.${pid} = {look = ${q(d.look)}, glow = Color3.fromRGB(${(d.glow >> 16) & 255}, ${(d.glow >> 8) & 255}, ${d.glow & 255}),\nmounts = {\n`;
    for (const mt of d.mounts) L += `{${q(mt.anchor)}, ${mt.frame.join(', ')}},\n`;
    L += `},\npieces = {\n`;
    for (const pc of d.pieces) L += `{${pc.mount}, ${q(pc.shape)}, ${pc.size.join(', ')}, ${pc.off.join(', ')}, ${q(pc.mat)}, ${q(pc.role)}, ${q(pc.group)}, ${pc.flags}, ${pc.color}, ${pc.alpha}},\n`;
    L += `},\ngroups = {\n`;
    for (const g of d.groups) L += `{${q(g.name)}, ${g.mount}, ${g.pivot.join(', ')}, ${q(g.type)}, ${q(g.axis)}, ${Math.round(g.amt * 10000) / 10000}, ${q(g.parent)}},\n`;
    L += `},\nbeams = {\n`;
    for (const bm of d.beams) L += `{a0 = ${q(bm.a0)}, p0 = ${arr(bm.p0)}, a1 = ${q(bm.a1)}, p1 = ${arr(bm.p1)}, d = ${bm.d}},\n`;
    L += `},\nhides = {${d.hides.map(q).join(', ')}},\nstruts = {\n`;
    for (const s of d.struts) L += `{a0 = ${q(s.a0)}, p0 = ${arr(s.p0)}, a1 = ${q(s.a1)}, p1 = ${arr(s.p1)}, f0 = ${s.f0}, f1 = ${s.f1}, d = ${s.d}, mat = ${q(s.mat)}},\n`;
    L += `},\n}\n`;
  }
  L += `return M\n`;
  fs.writeFileSync(path.join(ROOT, 'src', 'shared', 'HerreraPartsLooksV2.luau'), L);
  for (const [pid] of PICKS) { const d = out[pid]; console.log(pid, d.look, 'mounts', d.mounts.length, 'pieces', d.pieces.length, 'detail', d.pieces.filter(x => x.flags & 1).length, 'groups', d.groups.map(g => g.name).join(','), 'beams', d.beams.length, 'hides', d.hides.length, 'roles', [...new Set(d.pieces.map(x => x.role).filter(Boolean))].join(',')); }
})();
