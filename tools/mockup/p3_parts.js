const VOLT = 0x7fe9ff, BLOOD = 0xd0202a, LED = 0xffe7b0, GOO = 0xa6e22e, GOO_D = 0x5f8f12, ADR = 0x46e08a;
// ---------- parts: steps, looks, notes (Kepu 2026-10-31 picks) ----------
const PARTS = [
  {id: "caltrops", name: "Razor Caltrops", area: "UTILITY", key: "R", steps: [
      "Button: drop 6 razor spikes in a 10-stud patch behind you for 8 s. An enemy that steps on one bleeds 3/s for 3 s and is slowed 30% for 1 s",
      "10 spikes, 14-stud patch", "Spikes last 14 s", "Enemies can't see the spikes (only you and your squad do)"],
    note: "Its own slot key, 16 s cooldown. Picked ladder: \"Bleed trap\". Each spike is used up when an enemy steps on it. Works on bots and players.",
    looks: [
      {name: "A · Tail Spreader", sub: "a spike hopper on the base of the tail", why: "A steel hopper sits on the base of the tail with red spike tips poking out of the top. On the button it rattles and sprays the spikes out behind you, like a crop duster. You see where they come from.", parts: "Hopper box with 2 steel bands, 5 red spike tips on top, a rear chute."},
      {name: "B · Hip Drums", sub: "two spinning spike drums on the hips", why: "A revolver-style drum on each hip, rimmed with red spike tips. On the button both drums spin and fling spikes backward. It reads as 'mecha gear' from the side.", parts: "2 drums with steel caps, 6 spike tips on each rim, hip brace."}]},
  {id: "blob", name: "Goo Blob Shooter", area: "UTILITY", key: "R", steps: [
      "Button: lob a goo blob up to 60 studs. It splats into a 16-stud goo puddle for 5 s; enemies in the goo are slowed 40%",
      "Puddle 22 studs wide", "Fires 2 blobs side by side", "Puddles last 8 s"],
    note: "Its own slot key, 18 s cooldown (not given yet: tunable). Hold to aim, a landing circle shows where it splats (like the Tether Spike), release to fire. Picked ladder: \"Two blobs\". The goo is lime green so it can't be mixed up with the Med Station's green pad.",
    looks: [
      {name: "A · Hump Mortar", sub: "a stubby goo mortar on the hump", why: "A short, wide mortar tube on the hump with a glass goo tank behind it. It thumps and kicks back when it fires, and the blob sails up in a high arc. Very readable from far away.", parts: "Mortar tube tilted forward, lime muzzle ring, glass goo tank with a lime core, base plate."},
      {name: "B · Goo Spitter", sub: "a steel spit nozzle on the snout + a goo sac", why: "A steel nozzle bolted to the snout and a glass goo sac on the throat. The Herrera rears back and spits the blob. It plays on the 'spitting dino' idea.", parts: "Snout nozzle with a lime ring, glass throat sac with a lime core, 2 steel bands."}]},
  {id: "adren", name: "Adrenaline Injector", area: "HEALTH", key: "R", steps: [
      "Button: heal 25% of max health over 3 s and run 1.4x faster while it lasts", "Heal 34%", "Recharges 26% faster", "Also refills every slash charge at once"],
    note: "Its own slot key, 20 s cooldown (14.8 s from III); the cooldown counts from when the boost ends, like the raptor's. ★ is the Herrera twist: Stun Breaker already covers stuns, so it refills your slash charges instead.",
    looks: [
      {name: "A · Back Tanks", sub: "the raptor's green tanks, Herrera-sized", why: "Two glass tanks of green serum on the hump, the same family as the raptor's Adrenaline look. The serum drains when you use it and you glow green. Players who know the raptor part recognize it at once.", parts: "2 glass tanks with green cores (they drain on use), steel caps, a feed tube to the neck."},
      {name: "B · Neck Injector", sub: "a big auto-injector pen on the neck", why: "A chunky injector pen clamped to the side of the neck with a green vial window. On the button the plunger slams in with a click. It's a clear, punchy 'shot of adrenaline'.", parts: "Injector pen with a red cap, green vial window, sliding plunger, neck clamp."}]}];
const BOT_BITE = 20, SLASH = 8;
let part = 0, look = 0, step = 3, slotted = true, labView = false, slow = false;
function tipSpike(anchor, pos, rotd, scale) { const s = scale || 1;
  piece(anchor, [0.09 * s, 0.26 * s, 0.09 * s], pos, rotd, STEEL);
  piece(anchor, [0.07 * s, 0.1 * s, 0.07 * s], [pos[0], pos[1] + 0.15 * s, pos[2]], rotd, BLOOD, {glow: true}); }
function buildLook() {
  equip.forEach(e => { dino.remove(e.mesh); e.mesh.geometry.dispose(); }); equip.length = 0; hidden.clear();
  if (slotted) {
    const P = PARTS[part].id;
    if (P === "caltrops" && look === 0) {
      const rattle = () => new THREE.Matrix4().makeTranslation(0, sc.rattle ? Math.sin(T * 60) * 0.04 * sc.rattle : 0, 0);
      piece("Tail1_main", [0.85, 0.5, 0.6], [0, 0.42, 0], [0, 0, 0], DARK, {extra: rattle});
      for (const x of [-0.3, 0.3]) piece("Tail1_main", [0.08, 0.54, 0.64], [x, 0.42, 0], [0, 0, 0], STEEL, {extra: rattle});
      for (let i = 0; i < 5; i++) tipSpike("Tail1_main", [-0.3 + i * 0.15, 0.78, (i % 2 ? 0.12 : -0.12)], [0, 0, (i - 2) * 12]);
      piece("Tail1_main", [0.3, 0.26, 0.5], [0.52, 0.32, 0], [0, 0, -20], STEEL);
    }
    if (P === "caltrops" && look === 1) {
      for (const z of [0.5, -0.5]) {
        const spin = () => new THREE.Matrix4().makeRotationZ(sc.spin || 0);
        piece("Torso_hips", [0.7, 0.7, 0.26], [-0.05, -0.02, z], [0, 0, 0], DARK, {extra: spin});
        piece("Torso_hips", [0.42, 0.42, 0.3], [-0.05, -0.02, z], [0, 0, 45], STEEL, {extra: spin});
        for (let i = 0; i < 6; i++) { const a = i * Math.PI / 3;
          piece("Torso_hips", [0.1, 0.24, 0.1], [0, 0, 0], [0, 0, 0], BLOOD, {glow: true, extra: () => new THREE.Matrix4().makeTranslation(-0.05, -0.02, z)
            .multiply(new THREE.Matrix4().makeRotationZ((sc.spin || 0) + a)).multiply(new THREE.Matrix4().makeTranslation(0.44, 0, 0)).multiply(new THREE.Matrix4().makeRotationZ(-Math.PI / 2))}); }
      }
      piece("Torso_hips", [0.5, 0.14, 1.05], [-0.05, 0.38, 0], [0, 0, 0], STEEL);
    }
    if (P === "blob" && look === 0) {
      const recoil = () => new THREE.Matrix4().makeTranslation(-0.25 * (sc.kick || 0), -0.15 * (sc.kick || 0), 0);
      piece("Torso_hump", [0.9, 0.12, 0.8], [0, 0.32, 0], [0, 0, 0], DARK);
      piece("Torso_hump", [0.5, 1.0, 0.5], [0.22, 0.85, 0], [0, 0, -32], STEEL, {extra: recoil});
      piece("Torso_hump", [0.58, 0.14, 0.58], [0.48, 1.27, 0], [0, 0, -32], GOO, {glow: true, extra: recoil});
      piece("Torso_hump", [0.6, 0.55, 0.6], [-0.42, 0.62, 0], [0, 0, 0], 0xe0ffd0, {alpha: 0.35});
      piece("Torso_hump", [0.42, 0.4, 0.42], [-0.42, 0.6, 0], [0, 0, 0], GOO, {glow: true, extra: () => new THREE.Matrix4().makeScale(1, Math.max(0.15, 1 - 0.6 * (sc.drain || 0)), 1)});
      for (const y of [0.36, 0.88]) piece("Torso_hump", [0.64, 0.06, 0.64], [-0.42, y, 0], [0, 0, 0], STEEL);
    }
    if (P === "blob" && look === 1) {
      piece("Head_snout", [0.42, 0.42, 0.5], [0.56, 0.02, 0], [0, 0, 0], STEEL);
      piece("Head_snout", [0.12, 0.46, 0.56], [0.79, 0.02, 0], [0, 0, 0], GOO, {glow: true});
      piece("Head_snout", [0.6, 0.12, 0.82], [0.1, 0.34, 0], [0, 0, 0], DARK);
      piece("Neck_sac", [1.0, 0.72, 0.78], [0, -0.05, 0], [0, 0, 0], 0xe0ffd0, {alpha: 0.35});
      piece("Neck_sac", [0.78, 0.5, 0.58], [0, -0.07, 0], [0, 0, 0], GOO, {glow: true, extra: () => { const k = 1 - 0.5 * (sc.drain || 0) + 0.25 * (sc.kick || 0); return new THREE.Matrix4().makeScale(k, k, k); }});
      for (const x of [-0.36, 0.36]) piece("Neck_sac", [0.08, 0.76, 0.82], [x, -0.05, 0], [0, 0, 0], STEEL);
    }
    if (P === "adren" && look === 0) {
      for (const z of [0.27, -0.27]) {
        piece("Torso_hump", [0.34, 0.85, 0.34], [-0.1, 0.72, z], [0, 0, 0], 0xd8fff0, {alpha: 0.35});
        piece("Torso_hump", [0.24, 0.7, 0.24], [-0.1, 0.66, z], [0, 0, 0], ADR, {glow: true, flash: true, extra: () => { const f = Math.max(0.08, 1 - (sc.drain || 0)); return new THREE.Matrix4().makeTranslation(0, -0.35 * (1 - f), 0).multiply(new THREE.Matrix4().makeScale(1, f, 1)); }});
        piece("Torso_hump", [0.38, 0.1, 0.38], [-0.1, 1.17, z], [0, 0, 0], STEEL);
        piece("Torso_hump", [0.38, 0.1, 0.38], [-0.1, 0.28, z], [0, 0, 0], STEEL);
      }
      piece("Torso_hump", [0.9, 0.1, 0.1], [0.45, 1.0, 0], [0, 0, -25], ADR, {glow: true, flash: true});
    }
    if (P === "adren" && look === 1) {
      const z = 0.4;
      piece("Neck_main", [0.95, 0.3, 0.3], [0, 0.05, z], [0, 0, -10], STEEL);
      piece("Neck_main", [0.42, 0.2, 0.32], [0.1, 0.05, z + 0.02], [0, 0, -10], ADR, {glow: true, flash: true, extra: () => new THREE.Matrix4().makeScale(Math.max(0.1, 1 - (sc.drain || 0)), 1, 1)});
      piece("Neck_main", [0.22, 0.34, 0.34], [-0.55, 0.13, z], [0, 0, -10], BLOOD);
      piece("Neck_main", [0.5, 0.12, 0.12], [-0.85, 0.18, z], [0, 0, -10], BRIGHT, {extra: () => new THREE.Matrix4().makeTranslation(0.32 * (sc.plunge || 0), 0, 0)});
      piece("Neck_main", [0.86, 0.14, 0.12], [0, 0.0, 0.29], [0, 0, 0], DARK);
    }
  }
  for (const n in partInfo) partInfo[n].mesh.visible = !hidden.has(n);
}
