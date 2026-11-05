# Mecha Dino Arena — Feather Barrage → Wing Volley (plan v1.0)

**Ask (Kepu 2026-11-04 18:03):** "The feather animation can barely even be fucking seen. It's so fucking mid. You need to put
more fucking effort in these animations man." **Pick (19:08):** "A" = Wing Volley.
**Animation spec:** the 3D storyboard tools/mockup/therizino_moves_anim.js v0.4, move "Feather Barrage", variant A
(docs/mockups/therizino_moves_anim.html, artifact Fdapzg56TCAtjxRM4ngcA6 v4). Its phase times, poses, sizes and arc are the
game's below (U = model scale studs per storyboard unit: 2 on an adult).
**Why the live one can't be seen (grounded):** TheriMovesFX 1.3 feathers(): blades 0.12×0.3×1.6 × s/2 × 1.5 studs, pale
(240,234,216) SmoothPlastic, from the root + 1.5 s up, flat to the range in BLADE_TIME 0.3 s, then fade 0.09 s. From the
ShoulderCam they fly under the dino's own back. TheriPose 1.6 FEATHER is 0.24 s. No tell, no landing, no hit sign.

## Global constraints
- Additive; one switch: TheriMovesServer script attribute TheriMovesFeatherVolleyEnabled (default true). The server stamps
  the character's TheriFeatherVolley (true / false) at every press, and every client follows that stamp, so all clients agree.
  Off = the 1.5 Feather Barrage exactly (instant damage, old pose, old FX).
- Same part id (zfeather), remote (DinoTheriFeatherRequest), SkillTree rows and numbers: 8 / 10 / 12 blades, 20 / 25 / 30 studs,
  60° fan, 3 damage each, slowed 25 % for 1 / 2 s, recharge 14 s. No save change.
- Version branding in every header, docs/VERSIONS.md, docs/ATTRIBUTES.md. PC and phone ship together (no button change).
- No publish until Kepu says "Publish" (both places). The latch-leap fix (IdleAnimation 1.44, TheriPose 1.9) ships with it.

## Do-not-touch
The other Therizino moves (Vortex, Bola, Dash, Reel, Deflector, Overclock) and their FX / poses; SkillTree / SkillEffects;
MechaButtons; TheriPartsLooksV2 (the Blade Wings look stays); TheriMovesFX 1.3's other handlers; the 1.5 feather handler body
(it only gains an early return while the switch is on); the other dinos; HookServer, BotServer.

## Timeline (s after the press; storyboard A)
| Phase | Time | What you see |
|---|---|---|
| Wind-up | 0 – 0.35 | Arms cross over the chest (VOLLEY_CROSS); both Blade Wings fan open (u 0 → 1 over 0.3); a red fan (60°, range) lights on the ground in front, pulsing brighter until release |
| Release | 0.35 – 0.48 | Arms whip open wide (VOLLEY_WIDE, legs brace); at **0.42** every blade leaves: the wing pieces hide (empty wings) |
| Flight | 0.42 – 1.02 | One big bone dart per blade (3.3 U long, red edge, brass quill) flies from its wing (darts right of the heading from the right-of-screen wing ArmL, left from ArmR) in a 4.5 U high arc, spinning, with a red trail and red glow — over the dino's back, so the player camera sees them. Darts judged as hits home onto their target's torso |
| Land | 1.02 | Hit darts stick in the target (follow it) with 6 orange sparks, a red flash and a "3" pop; damage + slow happen now. Missed darts dive into the ground at the fan's edge with a dust puff |
| Recover | 1.0 – 1.5 | Pose eases back to idle; wings reload (pieces show again at 1.2), fold 1.3 – 1.6; stuck darts fade 1.62 – 1.92 |

## Deterministic map (server, TheriMovesServer 1.6)
Press (DinoTheriFeatherRequest): check() + ok() exactly as 1.5 (recharge starts at the press).
- Switch off → char TheriFeatherVolley = false, then the 1.5 handler (unchanged).
- Switch on → the 1.5 handler returns at its top; the new handler:
  1. dir = heading(char, aimDir) (as 1.5); origin = root position at the press. Stamps TheriFeatherVolley true,
     TheriFeatherDir, TheriFeatherOrigin, TheriVolleyRelease (VOLLEY_RELEASE 0.42), TheriVolleyFlight (VOLLEY_FLIGHT 0.6),
     TheriVolleyResult "windup", TheriVolleyDarts "", TheriFeatherHits "", TheriFeatherAt t (last: pose / FX / anim).
  2. Wait VOLLEY_RELEASE. Then t1 = now:
     - char gone, Humanoid dead, or StunnedUntil > t1 → TheriVolleyResult "cancelled", TheriVolleyFiredAt t1. Nothing more
       (the recharge already ran: as any interrupted move).
     - else → judge with the 1.5 blade test from origin + dir (same dirs, range, BLADE_WIDTH 1.5, flat-blade switch) against
       candidates() at t1. Each dart i (1..n) that touches ≥ 1 dino gets the one whose root is nearest along its line.
       Stamps TheriFeatherHits ("name=blades|...", 1.5 format), TheriVolleyDarts ("i=name|..."), TheriVolleyResult "fired",
       TheriVolleyFiredAt t1 (last).
  3. Wait VOLLEY_FLIGHT. Then t2 = now. For each judged dino: not stillTarget(char, m) → skipped; else damage() × its blade
     count ("therifeather"; shielded → 0 inside damage()) and slow() (shield-checked inside). Stamps TheriVolleyLanded
     ("name=blades|..." of the ones not skipped), TheriVolleyLandedAt t2 (last). Counter TheriMovesVolleyHits.
- A new press can't happen inside 1.02 s (recharge 14 s), so one volley per therizino at a time.

## Client
- **TheriPose 1.10** (feather branch): when the model's TheriFeatherVolley is true, poses VOLLEY_CROSS {ArmL 60 70 45, ArmR
  60 -70 -45, RootJoint 8, Neck 10, Tail1 -8} 0 → 0.35 (io), VOLLEY_WIDE {ArmL 40 -80 -60, ArmR 40 80 60, RootJoint -10, Neck
  -8, LegL 10, KneeL -14} 0.35 → 0.48 (out), held to 1.0, out by 1.5 (io). Else 1.6 FEATHER. Switch TheriPoseVolleyEnabled
  (model attribute, nil = true).
- **TheriPartsAnim 1.3** (zfeather): volley → u = up(e, 0.3) to 0.42, 1 to 1.3, then down over 0.3; the "blade" pieces are
  hidden from 0.42 to 1.2 unless TheriVolleyResult is "cancelled". Gated by TheriPartsAnimReworkEnabled (1.2's switch).
- **TheriMovesFX2 1.1** volley(char) on TheriFeatherAt when TheriFeatherVolley is true (switch TheriMovesFX2_volleyEnabled):
  ground fan (12 triangle slices of WedgeParts, red Neon, transparency 0.75 → 0.45 pulsing at 40 rad/s × 0.2 until 0.4, fade
  0.42 → 0.8; an arc edge of 16 Neon segments + two side edges at 0.3 transparency) at the ground under TheriFeatherOrigin;
  darts read TheriVolleyDarts once TheriVolleyFiredAt ≥ the stamp: from the wing point (Arm?_fore CFrame × (±0.5, 0.2, -0.3)
  U) along P(v) = lerp(from, to, v) + up × sin(πv) × 4.5 U, v = easeOut(0.7u + 0.3u²), u = (t - 0.42) / 0.6; to = the
  target's Hitbox_Torso (else root) for hits, else ground at origin + d × range. Dart = bone box 0.24×0.75×3.3 U, bone tip
  wedge, red Neon edge, brass quill (× 1.5 of the storyboard's 1.0 sizes), spin 20 rad/s about its axis; trail = red Neon box
  P(v(u - 0.22)) → pos, 0.48 U thick, transparency 0.4; glow = red Neon ball 1.65 U, transparency 0.65. Hit: stuck 0.6 U
  inside along the last direction, following the target root, sparks 0..0.3 s, flash(model, RED, 0.08), a "3" BillboardGui
  (the owner's TheriFeatherDamage) rising 0..0.9 s; fade 1.62 → 1.92. Miss: at the ground, tipped 20° down, dust puff,
  fade 1.22 → 1.52. "cancelled": the fan fades over 0.2 s, no darts.
- **TheriMovesFX 1.4**: feathers() returns at once when TheriFeatherVolley is true (no double draw).

## Tasks
1. **Server + spec** (Logic): TheriMovesServer 1.6 as the map; SkillTreeTheriParts.spec 1.6 adds: fire at an anchored bot in the
   fan → no damage at +0.2 s, damage 3 × blades and slow at +1.2 s, TheriVolleyDarts names it; bot moved out after release still
   hit (judged at release); stunned at release → "cancelled", no damage; switch off → instant 1.5 damage. Verify by hash.
2. **Pose + parts** (Wired): TheriPose 1.10, TheriPartsAnim 1.3. Studio: capture the cross, the whip, empty wings, reload.
3. **FX** (Wired): TheriMovesFX2 1.1, TheriMovesFX 1.4 guard. Studio: ShoulderCam captures at 0.3 / 0.7 / 1.05 / 1.4 s next to
   the storyboard frames (darts above the back, red fan, sticks, misses); phone-size capture.
4. **Docs**: VERSIONS, ATTRIBUTES, Dev Hub notes; report Added / Removed / Next; wait for "Publish".

## Red-team (synthesized)
1. **Damage moves from the press to 1.02 s later.** That is the point of a readable volley (the hit happens when you see the
   dart stick), but it is a feel change on a short-range move. Mitigation: judged at the release (0.42 s): the red fan is the
   honest tell; who is in it at the release is hit, and the darts home in (no dodging a dart you saw leave). **Flagged to
   Kepu** — "Build" accepts it.
2. **The fan is fixed where you pressed.** Walking during the 0.42 s wind-up moves the dino up to ~7 studs from the fan's tip;
   darts still start at the wings (cosmetic) and fly to the targets. Accepted: what's red on the ground is what gets hit.
3. **Stun / death during the wind-up**: "cancelled", recharge kept spent (same as any interrupted move). Mapped branch.
4. **Phone cost**: up to 12 darts × 6 parts + 30 fan parts for ~1.9 s per volley, created then destroyed (the Vortex FX is of the
   same size). Accepted; the part counts are in the FX diagnostics (TheriMovesFX2Last).
5. **Targets that die / leave / get shielded in flight**: skipped at landing (stillTarget) or 0 inside damage(); the dart still
   sticks visually where it was going (FX can't know) — only on a 0.6 s window. Accepted.
