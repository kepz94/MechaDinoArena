# Mecha Dino Arena — Tenontosaurus mecha parts, new looks (plan v2.0)

**Ask (Kepu 2026-11-05 16:09):** "the teno mecha parts and animation is a bit underwhelming" → scope "Looks first" (moves'
animations later). 16:16: "look at how other games do it then build our version". **Picks (16:48, mockup
docs/mockups/teno_parts_redesign.html v0.1, artifact KPdJjknnEN76qHwM3A4kee):** Grab-B **Pincer Tail** (Zoids Death Stinger),
Mortar-B **Back Cannon** (Zoids Gordos + Horizon Ravager Cannon), Stomp-A **Quake Hooves** (Horizon Behemoth Quake Smash),
Bellow-A **Shriek Sacs** (Horizon Longleg), Challenge-C **Alarm Beacon** (Horizon Longleg / Behemoth antennae), Leap-A
**Chicken-Leg Rams** (Armored Core 6 reverse-joint legs), Shield-B **Shield Mane** (Zoids Shield Liger).
**Why the live ones are underwhelming (grounded):** TenoPartsServer 1.2 builds 4–14 plain pieces per part (steel / dark
Metal boxes, one Neon dot), all welded still: nothing moves. The only motion is TenoMovesFX hiding the mortar "rock" and
glowing the stomp "heat" strip.
**Architecture:** the Therizino path (plan THERIZINO_PARTS_LOOKS_v2.0, live since v434): the mockup is the source of truth,
an export tool writes a Luau data module, the parts server builds from it (old builders behind a switch), moving bits are
groups hung on Welds that a new every-client script drives from the stamps the move server already sets.

## Global constraints
- Additive, every piece behind a switch; off = today's look exactly. No numbers, remotes, buttons, Lab texts or SkillTree
  rows change. No HUD change (PC and phone untouched).
- Versions: TenoPartsServer 1.3, new TenoPartsLooksV2 1.0 (generated data), new TenoPartsAnim 1.0, new
  tools/mockup/export_teno_parts_v2.js 1.0, new tools/tests/TenoPartsLooksV2.spec 1.0, TenoMovesServer 1.9, TenoMovesFX 1.6,
  mockup v0.2 (export tags only, no visual change). VERSIONS.md + ATTRIBUTES.md rows.
- Style kit and shapes exactly as the Therizino v2 (studded shell / plate, SmoothPlastic trim / bone / rubber / hazard,
  Metal brass / steel / iron, Neon glow in the Lab area colour: attack #ff3b30, defense #3d9bff, health #3ddc84, speed
  #ffc21a; Shield Armor keeps its purple #9646ff / lilac #cda0ff). Massless, no collide / query / touch.
- Install by multi_edit / execute_luau, verify by hash. One-player tests; test slots restored. Publish only on "Publish".
- The body poses (TenoPose) do not change in this plan; the scorpion curl, rear-up timing, sound rings, scan cones and
  shock rings shown in the mockup's "Use it" are the animation pass that follows.

## Do-not-touch
SkillTree / SkillEffects, MechaButtons / AbilityBar / Lab / MainMenu, IdleAnimation + TenoPose, JumpServer, TenoAttackServer,
TenoLeapLaunch, every TenoMovesServer rule except the one boulder start point (Task 4), TenoMovesFX except Task 4's flash
point, TheriPartsServer / TheriPartsAnim / TheriPartsLooksV2 (copied from, not edited), every other dino's parts.

## File structure
| File | New / changed | Job |
|---|---|---|
| tools/mockup/teno_parts_v2_looks.js | v0.2 | `group` / `role` / `detail` tags on the 7 picked looks (no visual change) |
| tools/mockup/export_teno_parts_v2.js | new | headless export of the picks → src/shared/TenoPartsLooksV2.luau |
| src/shared/TenoPartsLooksV2.luau | new (generated) | mounts, pieces, groups, struts per part id |
| tools/tests/TenoPartsLooksV2.spec.luau | new | data checks (Studio Edit) |
| src/server/TenoPartsServer.server.luau | 1.3 | builds v2 looks + Lab cards from the module (Model "TPart_<id>", same names) |
| src/client/TenoPartsAnim.client.luau | new | every client: drives the groups from the teno stamps |
| src/server/TenoMovesServer.server.luau | 1.9 | the boulder leaves the cannon's "muzzle" piece when there is one |
| src/client/TenoMovesFX.client.luau | 1.6 | the launch flash at the "muzzle" piece when there is one |

## Deterministic map (part · look → moving groups → what drives them → rest)
| Part · look | Sits on | Groups / roles (TenoPartsAnim) | Driven by (server time) | Rest |
|---|---|---|---|---|
| tgrab · Pincer Tail | armour plates + red line on Tail2–Tail5; pincer on Tail5 (×1.7) | `pincer_L` / `pincer_R` swing about Y, ±38° (open) | TenoGrabStartedAt: open over 0.25 s; TenoGrabCatchAt (newer than the start): shut in 0.08 s; TenoGrabThrowAtPlan: open over 0.1 s, shut by +0.6; no catch by start + 1.0: shut over 0.2 s | 8° open |
| tmortar · Back Cannon | turret on the back (×1.35); hopper on the camera side | `barrel` swing about X +26° (elevate); `kick` (child of barrel) slide −0.4 × scale along the barrel; role `charge` (4 glow rings) lit 1..4 across start → fire; film `flash` at the muzzle; role `rock` = the front hopper boulder; role `muzzle` | TenoMortarStartedAt: elevate over 0.3 s, rings light at k/4 of (TenoMortarFiredAt or start + 0.55); TenoMortarFiredAt: kick 0.15 s + flash 0.2 s, rings off; down over 0.4 s from fire + 0.4 | barrel 32°, rings off |
| tstomp · Quake Hooves | boots on both hands (×1.25), rams on both forearms, stacks on the shoulders (×1.6) | `ring_L` / `ring_R` spin (with their fins and glow nubs) 0.8 → 13 rad/s; `ram_L` / `ram_R` slide −0.12 × scale; films `puff_L` / `puff_R` over the stacks | TenoStompStartedAt: spin up over 0.5 s; TenoStompAt: rams punch 0.15 s, puffs 0.3 s, spin down over 0.8 s | rings idle 0.8 rad/s |
| tbellow · Shriek Sacs | both sides of Neck_base | films `sac_L` / `sac_R` pulse: Size × (1 + 0.35 u (0.5 + 0.5 sin 6t)) (client-local Size) | TenoBellowStartedAt → TenoBellowAt + 0.8 (up 0.15 s, down 0.3 s) | sacs at 0.55 see-through, breathing ± 4 % |
| tchallenge · Alarm Beacon | antennae on the head; beacon on the shoulders | `ant_L` / `ant_R` swing about Z 35° (stand up); `reflector` spin 1.5 → 11.5 rad/s; dome film brighter; role `lens` = the reflector (the red paint beams start there) | TenoChallengeStartedAt → TenoChallengeAt + 1.0 (up 0.2 s, down 0.4 s) | antennae laid back 55°, slow spin |
| tleap · Chicken-Leg Rams | both hind legs: ram housing on the haunch, rod on the heel, gear on the knee, gauge on the thigh | struts `ram_L` / `ram_R` (type "aim": the housing's axis points at the heel point, the rod's at the hip point, each frame, so they telescope with the legs); `gear_L` / `gear_R` spin; role `gauge` (5 glow bars) | gauge bars lit = round(5 × TenoLeapChargesLeft / TenoLeapCharges); all 5 flash at 6 Hz while TenoLeapUntil > now; gears spin 8 rad/s while TenoLeapUntil > now, idle 0.5 | gears idle |
| tmud · Shield Mane | 10 blades round the neck base (on Torso_chest), 2 generators behind | `blade_1..10` swing about X −82° (folded back 72° → forward −10°); films `disc` + `rim` | TenoMudCoatAt (newer than TenoMudEndedAt): forward over 0.15 s, disc fades in; held while TenoMudUntil > now; TenoMudEndedAt or until: fold over 0.3 s | blades folded back along the neck |

Edge branches (every look):
- Part not slotted → no model (as now). Respawn → rebuilt (as now). Another player's teno → animated on every client.
- Scale change (GrowthServer ScaleTo) → TenoPartsAnim re-reads the rest C0 × (scale / built scale) (the TheriPartsAnim rule).
- A stamp older than the model's build time → ignored (no motion replay on respawn).
- `TenoPartsLooksV2Enabled` false → the 1.2 looks (and their roles) exactly. `TenoPartsAnimEnabled` false → groups at rest.
- `TenoPartsDetail` "lite" → bolts / stripes / glow nubs skipped (the Therizino rule).
- Old roles: `heat` (stomp) no longer exists on v2 → TenoMovesFX's heat glow finds nothing and does nothing (the spinning
  rings are the tell). `rock` and `lens` keep working (tagged above).

## Tasks
### Task 1 — Tags + export + data · Mode: Logic
Files: tools/mockup/teno_parts_v2_looks.js (v0.2: group / role / detail tags, the group pivots and motions of the map),
new tools/mockup/export_teno_parts_v2.js (from export_theri_parts_v2.js 1.2; `dino` instead of `theri`; struts exported as
{anchorA, pointA, anchorB, pointB, f0, f1, d, mat}), generated src/shared/TenoPartsLooksV2.luau, new
tools/tests/TenoPartsLooksV2.spec.luau.
Acceptance: the spec passes in Studio Edit: 7 ids; every anchor exists on TenoModelData look E; every group named in the map
exists with its type / axis / amount; roles rock, muzzle, lens, charge, gauge present; piece counts ≤ 90 per part; rest
offsets equal the mockup's at use = 0 to 0.001.

### Task 2 — Build the looks · Mode: Wired
TenoPartsServer 1.3: `buildV2` (copied from TheriPartsServer 1.1's, prefix "TPart"), struts as two welded pieces with
ZPartType "aim" + ZPartAimAnchor / ZPartAimPoint, films start invisible, TPartRole attribute kept, Lab cards
(BuildPreview_<id>) use it. Switch TenoPartsLooksV2Enabled (default true). Diagnostic TenoPartsBuilt as now.
Acceptance: Studio Play, test teno, each part slotted in turn (slots restored): the model appears on the right anchors, the
camera-side view matches the mockup; Lab card of each part shows the new look; switch off → 1.2 looks.

### Task 3 — Make it move · Mode: Wired
New TenoPartsAnim 1.0 (from TheriPartsAnim 1.0's frame loop): the map's u per part, spin / swing / slide / aim / pulse,
charge and gauge lighting, films. Switch TenoPartsAnimEnabled. Diagnostics TenoPartsAnimVersion, TenoPartsAnimJoints, model
TenoPartsAnimActive.
Acceptance: each move pressed once in Studio (anchored bots): pincers open → snap on the catch → open at the throw; barrel
lifts, 4 rings light, kick at the fire; rings spin up and rams punch at the stomp; sacs pump on the bellow; antennae stand
and the light spins on the call; rams telescope through a JUMP leap and the gauge shows the charges; mane blades swing
forward and the disc shows while the shield is up. Player-camera captures for each.

### Task 4 — Boulder from the cannon · Mode: Wired
TenoMovesServer 1.9: at the fire, when the character's TPart_tmortar has a piece with TPartRole "muzzle", the boulder starts
at that piece's position (else Tail3 as 1.8). Switch TenoMovesMortarMuzzleEnabled (default true). TenoMovesFX 1.6: the launch
flash at the "muzzle" piece when present (else the rock as 1.5). Switch TenoMovesFXMuzzleEnabled.
Acceptance: a mortar shot in Studio leaves the barrel tip; the hopper boulder hides for 2.4 s; switch off → from the tail.

### Task 5 — Docs, report, wait for "Publish"
VERSIONS / ATTRIBUTES rows, Dev Hub notes, report Added / Removed / Next.

## Red-team (synthesized)
1. **The tail whip still plays for a cannon shot.** TenoPose's mortar wind-up + whip (1.8) stays (do-not-touch, animation
   pass next), so for ~0.5 s the tail whips while the boulder leaves the back cannon. Mitigation: Task 4 moves the boulder to
   the muzzle so the shot reads right; the pose is the first item of the animation pass. **Flagged.**
2. **Struts between two moving parts** are new (the Therizino has none). If the aim math is wrong the ram floats off the
   leg. Mitigation: "aim" pieces are welded at their own anchor and only rotate (position fixed), so the worst case is a
   wrong angle, never a detached piece; Studio captures through a full JUMP leap are an acceptance item.
3. **Client-local Size pulse on the sacs** replicates nothing and costs a Size write per frame per teno; it is only while the
   bellow is up (~1.3 s) and on 2 parts. Accepted.
4. **Phone cost:** the Tail plates + pincer (~40), cannon (~45), hooves (~65), beacon (~25), rams (~30), mane (~45), sacs
   (~20) — the Therizino set is 55–78 per part and runs; "lite" detail exists for phones if needed. Accepted.
5. **Old FX roles:** the stomp's orange heat glow disappears with the boots (no `heat` piece). Accepted: the spin-up rings
   are the new tell; nothing errors (roles() returns an empty list).
