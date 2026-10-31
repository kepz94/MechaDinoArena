function buildLook() {
  equip.forEach(e => { dino.remove(e.mesh); e.mesh.geometry.dispose(); }); equip.length = 0; hidden.clear();
  if (slotted) {
    const P = PARTS[part].id;
    if (P === "siphon" && look === 0) {
      // the tank hangs under the neck just behind the frill (visible from the side), piped to the red throat sac
      piece("Neck_main", [1.15, 0.85, 0.95], [0, -0.62, 0], [0, 0, 0], 0xcfe8ff, {alpha: 0.35});
      piece("Neck_main", [0.88, 0.6, 0.7], [0, -0.64, 0], [0, 0, 0], BLOOD, {glow: true, extra: () => new THREE.Matrix4().makeScale(1 + sc.pulse * 0.25, 1 + sc.pulse * 0.25, 1 + sc.pulse * 0.25)});
      for (const y of [-1.08, -0.18]) piece("Neck_main", [1.22, 0.12, 1.02], [0, y, 0], [0, 0, 0], STEEL);
      for (const z of [0.6, -0.6]) piece("Neck_main", [0.3, 0.5, 0.14], [0, -0.62, z], [0, 0, 0], DARK);
      piece("Neck_sac", [0.9, 0.1, 0.66], [0, -0.3, 0], [0, 0, 0], STEEL);
      piece("Neck_lower", [0.14, 0.14, 0.7], [0, -0.32, 0], [0, 90, 0], BLOOD, {glow: true});
    }
    if (P === "siphon" && look === 1) {
      for (const z of [0.26, -0.26]) {
        piece("Jaw_lower", [0.2, 0.8, 0.2], [0.72, 0.5, z], [0, 0, -8], BRIGHT);
        piece("Jaw_lower", [0.16, 0.16, 0.16], [0.77, 0.92, z], [0, 0, 0], BLOOD, {glow: true});
        piece("Neck_lower", [0.12, 0.12, 0.62], [0, -0.22, z * 1.3], [0, 90, 0], BLOOD, {glow: true});
        piece("Neck_main", [0.12, 0.12, 0.62], [0, -0.22, z * 1.3], [0, 90, 0], BLOOD, {glow: true});
      }
      piece("Jaw_lower", [1.2, 0.12, 0.95], [0.1, 0.24, 0], [0, 0, 0], DARK);
      piece("Torso_breast", [0.55, 0.8, 0.8], [0.32, 0.0, 0], [0, 0, 0], 0xcfe8ff, {alpha: 0.35});
      piece("Torso_breast", [0.36, 0.55, 0.55], [0.32, -0.02, 0], [0, 0, 0], BLOOD, {glow: true, extra: () => new THREE.Matrix4().makeScale(1 + sc.pulse * 0.25, 1 + sc.pulse * 0.25, 1 + sc.pulse * 0.25)});
      for (const y of [-0.42, 0.42]) piece("Torso_breast", [0.6, 0.08, 0.85], [0.32, y, 0], [0, 0, 0], STEEL);
    }
    if (P === "strobe" && look === 0) {
      for (let i = 1; i <= 11; i++) for (const x of [0.07, -0.07]) piece("Head_frill" + i, [0.05, 0.62, 0.16], [x, 0.04, 0], [0, 0, 0], LED, {glow: true, flash: true});
      for (let i = 1; i <= 11; i++) piece("Head_frillrim" + i, [0.16, 0.16, 0.24], [0, 0.1, 0], [0, 0, 0], HOT, {glow: true, flash: true});
      piece("Neck_main", [0.9, 0.16, 0.66], [0, 0.05, 0], [0, 0, 0], STEEL);
    }
    if (P === "strobe" && look === 1) {
      for (const n of ["Head_frillrim2", "Head_frillrim10"]) {
        piece(n, [0.62, 0.62, 0.62], [0, 0.32, 0], [0, 0, 0], DARK);
        piece(n, [0.5, 0.5, 0.66], [0, 0.32, 0], [0, 0, 0], LED, {glow: true, flash: true});
        piece(n, [0.7, 0.12, 0.7], [0, 0.66, 0], [0, 0, 0], STEEL);
      }
      piece("Head_frill6", [0.2, 0.5, 0.5], [0, -0.1, 0], [0, 0, 0], STEEL);
      piece("Neck_main", [0.9, 0.16, 0.66], [0, 0.05, 0], [0, 0, 0], STEEL);
    }
    if (P === "breaker" && look === 0) {
      for (let i = 1; i <= 11; i++) {
        piece("Head_frillrim" + i, [0.13, 0.5, 0.13], [0, 0.3, 0], [0, 0, 0], STEEL);
        piece("Head_frillrim" + i, [0.2, 0.16, 0.2], [0, 0.6, 0], [0, 0, 0], VOLT, {glow: true, flash: true});
      }
      piece("Neck_main", [0.92, 0.22, 0.68], [0, 0.05, 0], [0, 0, 0], DARK);
      piece("Neck_main", [0.95, 0.07, 0.71], [0, 0.05, 0], [0, 0, 0], VOLT, {glow: true, flash: true});
    }
    if (P === "breaker" && look === 1) {
      piece("Torso_hump", [0.95, 0.6, 0.85], [0, 0.45, 0], [0, 0, 0], DARK);
      piece("Torso_hump", [0.98, 0.08, 0.88], [0, 0.6, 0], [0, 0, 0], VOLT, {glow: true, flash: true});
      for (const z of [0.25, -0.25]) {
        piece("Torso_hump", [0.15, 1.1, 0.15], [0, 1.25, z], [0, 0, 0], STEEL);
        for (const y of [0.95, 1.2, 1.45]) piece("Torso_hump", [0.32, 0.06, 0.32], [0, y, z], [0, 0, 0], HOT);
        piece("Torso_hump", [0.26, 0.26, 0.26], [0, 1.85, z], [0, 0, 0], VOLT, {glow: true, flash: true});
      }
    }
  }
  for (const n in partInfo) partInfo[n].mesh.visible = !hidden.has(n);
}
