# Mecha Dino Arena — Deflector Shield Wall + Overclock Steam Engine (plan v2.0)

**Ask (Kepu 2026-11-05 15:30):** "Therizino's last two moves" (the two left out of the rework). **Picks (15:52):** "I like both
of your picks" = Deflector **A · Shield Wall**, Overclock **A · Steam Engine**.
**Animation spec:** storyboard tools/mockup/therizino_moves_anim.js v0.5 (artifact Fdapzg56TCAtjxRM4ngcA6 v5), moves
"Deflector Claws" A and "Overclock Joints" A. U = model scale studs per storyboard unit (2 on an adult).
**Why the live ones don't read (grounded):** Deflector: TheriPose 1.7 ARMS_FWD, the Mane Rotor collar spins (TheriPartsAnim),
its film disc shows 35 % at the chest; a block = a small white flash at the collar (TheriMovesFX 1.2 deflectBlock); the
reflect (★) is damage to the shooter inside DiloAttackServer / TenoMovesServer / ScreechServer with nothing drawn; nothing
shows the covered arc (DeflectRules: ±TheriDeflectAngle 70° of the root's facing). Overclock (passive since 1.3): the piston
legs' gears spin and fins open with speed (TheriPartsAnim 1.1), rings glow steady yellow (TheriMovesFX 1.3); the +40 % run,
the ignored slows (★, SprintTest 1.20 slowBack) and the extra jump (III, TheriMovesServer 1.5) show nothing.

## Global constraints
- Additive; every piece behind a switch; off = today's look exactly. No numbers change (SkillTree 1.67 rows as they are).
- One server line: TheriMovesServer 1.7 stamps the character's TheriDeflectWall (= script switch
  TheriMovesDeflectWallEnabled, default true) before TheriDeflectAt, so every client draws the same mode.
- Version branding (headers, VERSIONS, ATTRIBUTES). PC and phone together (no button change). No publish until "Publish".

## Do-not-touch
DeflectRules 1.0 and the three projectile servers (what is blocked / reflected stays exactly as now); SprintTest; JumpServer;
SkillTree / SkillEffects; TheriPartsLooksV2 (Mane Rotor and Piston Legs looks stay); every other move's code.

## Deflector Claws → Shield Wall (stamps: TheriDeflectAt, TheriDeflectUntil, TheriDeflectWall; blocks: TheriDeflectBlockAt /
## BlockFrom / BlockKind from DeflectRules; TheriDeflectReflect = the star)
| Time (s after TheriDeflectAt) | What you see |
|---|---|
| 0 – 0.15 | Brace: GUARD pose (crouch, arms crossed in front); the collar spins up and its fins flare (TheriPartsAnim, unchanged) |
| 0.02 – 0.23 | The wall unrolls from the middle out: 14 panels of 10° (140° = ±TheriDeflectAngle) at radius 9 U, 9 U tall from the ground, blue (#3d9bff) Neon at 0.82 transparency; a light-blue top rim, one middle line, two edge posts; the arc + a faint fan on the ground |
| while TheriDeflectUntil > now | The wall turns with the root's flat facing every frame (the same facing DeflectRules checks); shimmer ±0.06 |
| each TheriDeflectBlockAt | At the wall where the line from TheriDeflectBlockFrom to the chest crosses it: a ripple ring (0.45 s), 8 sparks (0.3 s), a recoil (RootJoint +8°, 0.25 s), a "BLOCKED" pop; with TheriDeflectReflect: a copy of the shot (dart red / boulder grey / cannon dark) flies back to BlockFrom in 0.35 s with a yellow trail, "BOUNCED BACK" |
| until → until + 0.3 | The wall rolls up from the ends into the middle and fades; pose out over 0.3 s |
A shot from outside the arc is not blocked (DeflectRules) and hits as now; the wall shows why.

## Overclock Joints → Steam Engine (passive while TheriClockPassive; star = TheriClockNoSlow; III = TheriClockJumpAdded)
- **Running** (flat root speed ≥ 8 studs/s and on the ground): every 0.23 s, alternating sides, a steam puff leaves that
  haunch's canister (piece "ring_Leg?_haunch") and drifts back / up for 0.55 s (1 → 3.4 U, 0.25 → 1 transparency); 4 yellow
  sparks fly from the same side's knee gear (piece "gear_Shin?_knee"); 8 yellow streaks (0.16 U thick, 4.5 U long) slide back
  along both flanks at 4.2 – 5.1 U from the root.
- **Slow ignored (★):** while TheriClockPassive and TheriClockNoSlow, when ScreechSlowUntil / MineSlowUntil / TenoSlowUntil /
  SmokeSlowUntil / CaltropSlowUntil / GooSlowUntil / HeadbuttSlowUntil (SprintTest 1.20's slowBack list) or DebuffUntil (with
  DebuffSpeedMul < 1) is set to a future time: a yellow 12-tooth ring bursts out from the chest (0.6 s) and a "SLOW IGNORED"
  pop.
- **Extra jump (III):** when JumpStartedAt changes while TheriClockJumpAdded is true and JumpChargesLeft is 0 (the jump that
  empties the pool only exists because of the extra charge): a white steam blast ring under the feet (0.45 s), 6 puffs out, a
  "3rd JUMP" pop.

## Tasks
1. **Server + pose + parts (Wired):** TheriMovesServer 1.7 (TheriDeflectWall stamp + switch); TheriPose 1.11 GUARD + recoil
   (switch TheriPoseGuardEnabled); TheriPartsAnim 1.4 (zdeflect film kept hidden while TheriDeflectWall).
2. **Shield Wall FX (Wired):** TheriMovesFX2 1.2 wall + blocks (switch TheriMovesFX2_wallEnabled); TheriMovesFX 1.5: the v2
   collar flash skips while TheriDeflectWall.
3. **Steam Engine FX (Wired):** TheriMovesFX2 1.2 steam loop (switch TheriMovesFX2_steamEnabled), pooled 8 puffs + 8 sparks +
   8 streaks per passive therizino, hidden when not running.
4. **Studio test + captures from the player camera; docs; report; wait for "Publish".**

## Red-team (synthesized)
1. **The wall is drawn at 18 studs but blocks are judged at the body.** A dart crosses the wall and fizzles at the body
   (DiloFX) ~0.05 s later; the ripple is drawn where its line crosses the wall at the block. Accepted (no projectile-server
   change).
2. **A big wall in front of the owner's camera** could hide targets: fill at 0.82 transparency, only the rim / posts solid;
   up 1 – 2 s.
3. **Every client runs the steam loop for every passive therizino:** 24 pooled parts each, updated only while it runs, hidden
   otherwise (same scale as the Vortex FX).
4. **"3rd JUMP" rule** marks the jump that empties the pool while the extra charge is added — the one you would not have
   without Overclock III. If a refill lands mid-chain it may mark a different jump of the chain. Accepted.
5. **SLOW IGNORED** fires on the attribute being set, so a slow applied to a bot (server-side, not attributes) never shows —
   bots have no Overclock. Covered.
