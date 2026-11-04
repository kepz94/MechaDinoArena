# Mecha Dino Arena v1.0 — Therizinosaurus mecha button parts (7 parts)

**Goal:** the therizino gets its own MECHA ABILITIES: 7 button parts it can slot (4 slots: R / T / C / V), each with a
visible part, a Lab card and four steps. Today it has none.

**Intent (Kepu 2026-11-04):** "Do dilo's and zino's stats" -> therizino "Button parts" -> "Create 20 options ... Only tell me
what the maxed out ability would be" -> picks "1. 3. 5. 12. 18. 19. 16. For therizino".
**Looks (Kepu 2026-11-04 11:07, mockup docs/mockups/therizino_parts_options.html v0.1):** 1-C Back Crane, 3-A Arm Racks,
5-B Arm Pistons, 12-C Belly Winch, 16-A Spinner Hubs, 18-C Joint Rings, 19-A Tail Spools.

**Architecture:** the teno abilities pattern (docs/plans/TENO_ABILITIES_v1.0.md):
- SkillTree adds therizino-only button parts (`dino = "Therizino"`, LIVE_MECH, BUTTONS), ids prefixed `z` (no clash).
- SkillEffects writes `TheriPart*` character attributes while a part is bought AND slotted (off values otherwise).
- New TheriPartsServer builds the looks (`ZPart_<id>`) and the Lab cards (`BuildPreview_<id>`); Lab / MainMenu learn the
  `ZPart_` prefix.
- New TheriMovesServer owns the remotes and the effects; new TheriMovesFX draws them; MechaButtons gets 7 `TIMED_PARTS`
  entries (PC, gamepad and phone together); TheriPose gets the move poses.

## Global constraints
- Additive only; every script change behind its own switch; every number an attribute with a default.
- Versions: SkillTree 1.61, SkillTreeTheriParts.spec 1.0, SkillEffects 1.42; new TheriPartsServer 1.0, TheriMovesServer
  1.0, TheriMovesFX 1.0; MechaButtons, Lab, MainMenu, TheriPose, IdleAnimation, SprintTest bumped at build time (re-read
  their current versions first). VERSIONS.md / ATTRIBUTES.md rows for each.
- Install by multi_edit / execute_luau and verify by hash. Publish only on Kepu's "Publish" (both places). One-player tests.
- Every ability: parts shown only while slotted; a Lab card; squadmates never hit (SquadRules sameChar); players only where
  ModeRules.canAffect allows (the Arena); bots always.
- Upgrade rule (Herrera trim): steps extend time / reach / count / recharge, never re-stack the main %.

## Do-not-touch
The therizino's cut chain and Spin Dive (TheriAttackServer, TheriSpinServer) except the two read-only hooks named below;
the therizino stat rows (SkillTree 1.57 / 1.58); every other dino's parts and servers unless a task names it.

## The 7 abilities (Lab step texts; ★ = Kepu's picked maxed text)
| # | id | Name · area · look | I | II | III | ★ | Recharge |
|---|---|---|---|---|---|---|---|
| 1 | `zhook` | Reaper's Hook · ATTACK · C Back Crane | Fire a claw chain 50 studs and yank the dino in | Chain 65 studs | Chain 80 studs; recharge 15 s | The yanked dino is stunned 1 s and cut 1 starts on it | 18 s |
| 3 | `zfeather` | Feather Barrage · ATTACK · A Arm Racks | 8 feather blades in a 20-stud fan: 3 each, slowed 25% for 1 s | 10 blades, 25 studs | Slow 2 s | 12 blades, 30 studs | 14 s |
| 5 | `zharvest` | Harvest Field · ATTACK · B Arm Pistons | A 12-stud circle for 3 s: enemies inside bleed 4/s, slowed 30% | Circle 16 | Lasts 4 s | Circle 20, lasts 5 s | 20 s |
| 12 | `zgrapple` | Grapple Zip · SPEED · C Belly Winch | Hook a tree or wall up to 40 studs and zip there | 55 studs | 70 studs; recharge 10 s | 2 charges | 12 s |
| 16 | `zdeflect` | Deflector Claws · DEFENSE · A Spinner Hubs | Claws spin in front 1 s, block darts | 1.5 s; blocks boulders and cannon shots too | 2 s; recharge 13 s | Blocked shots bounce back at the shooter | 16 s |
| 18 | `zclock` | Overclock Joints · SPEED · C Joint Rings | 3 s: run 40% faster | 4 s; cut taps 30% faster too | 5 s; recharge 18 s | Slows don't work on you while it's on | 22 s |
| 19 | `zsnare` | Snare Wires · ENGINEER · A Tail Spools | Lay 1 wire trap: the first dino across is rooted 1 s and takes 12 | 2 traps | Rooted 2 s | 3 traps | 18 s |

"Circle 12 / 16 / 20" = radius or diameter: Kepu decides (red-team 1). "Rockets" from the mockup's step I is dropped: the
Shoulder Rocket part is "soon" (SkillTree), so no rocket exists to block (red-team 2).

## Deterministic map
| State | Condition | Result |
|---|---|---|
| Not bought / not slotted / not a therizino | — | off values; no `ZPart_<id>`; no button |
| Any request | first failing check: badArg, dead, disabled, menu, stunned, pinned, dazed, cooldown | `TheriPart<Id>Result` = reason; nothing happens |
| ok | — | `TheriPart<Id>ReadyAt` = now + recharge (Grapple ★: per charge) |
| Hook | nearest allowed dino in a 20° cone of the camera heading within reach (HookServer 1.8's aim rule; objects never) | yanked to 6 studs in front (HookServer's pull); none -> "noTarget", no recharge; ★ StunnedUntil = max(old, now + 1) and TheriAttackServer starts cut 1 on it (read-only hook: a server call into its existing cut-1 path, behind TheriAttackHookCutEnabled) |
| Feather | N blades spread evenly over a 60° fan, range R | each allowed dino whose hitboxes a blade line crosses: 3 per blade, slow tag (TenoSlowUntil / TenoSlowMul 0.75; the stronger / longer kept, the existing tag) |
| Harvest | circle at the therizino's feet for T s | every 0.5 s each allowed dino inside: bleed 2 (4/s), slow tag 0.7 for 0.6 s (refreshed while inside) |
| Grapple | raycast from the chest along the camera heading, reach R, against the world only (no characters, no bots) | hit -> the owner's client zips the root to 4 studs short of the hit point (TenoLeapLaunch's client-launch pattern); miss -> "noAnchor", no recharge |
| Deflect | TheriDeflectUntil = now + T | a projectile resolving on the therizino from within 70° of its facing is blocked (no damage, no venom / stun / slow); Projectile list by step: I dilo dart, II + tenos' mortar boulders and the raptor / T-Rex Shock Cannon; ★ the blocked shot's damage goes to the shooter. Each projectile server checks a shared `DeflectRules` module at impact (one line, behind its own switch) |
| Overclock | TheriClockUntil = now + T | SprintTest run / walk x 1.4; II+ TheriAttackServer's tap gap x 0.7 (read-only hook); ★ slow tags ignored (SprintTest and TheriMovesServer skip TenoSlowMul while on) |
| Snare | trap placed 8 studs ahead on the ground, up to the step count alive at once (the oldest goes) | the first allowed dino whose root comes within 4 studs: 12 damage, rooted (TetheredUntil-style root: TetherServer's rope with reach 0) for 1 / 2 s, trap gone |

## Tasks (two builds, like the teno)
**Build 1 (fight parts on proven patterns):** Reaper's Hook, Feather Barrage, Harvest Field, Snare Wires.
**Build 2 (movement + cross-server):** Grapple Zip, Overclock Joints, Deflector Claws.

1. **SkillTreeTheriParts.spec 1.0 + SkillTree 1.61** (Logic): the 7 paths via `part(...)`, `dino = "Therizino"`, effects
   (numbers above), build-2 parts `soon` until build 2. Switch `SkillTree.THERI_PARTS`.
2. **SkillEffects 1.42** (Wired): `ZPARTS` list writing TheriPart* attributes. Switch `SkillEffectsTheriPartsEnabled`.
3. **TheriPartsServer 1.0** (Wired): the 7 looks from the picks (`ZPart_<id>`, welded, massless, no collision), shown while
   enabled; `BuildPreview_<id>`; Lab / MainMenu learn `ZPart_`. Switch `TheriPartsServerEnabled`.
4. **TheriMovesServer 1.0 build 1** (Wired): remotes and the four build-1 rows of the map. Switches `TheriMoves_<id>Enabled`.
5. **Client build 1** (Wired): MechaButtons 4 entries (PC + phone), TheriMovesFX (chain, blades, field, wires), TheriPose
   moves.
6. **Studio check build 1**, then publish on Kepu's word.
7. **Build 2 server**: Grapple (world raycast + client launch), Overclock (SprintTest + TheriAttackServer gap hook),
   Deflector (`DeflectRules` module + one-line checks in DiloAttackServer, TenoMovesServer, ScreechServer).
8. **Client build 2 + Studio check 2**, then publish.

## Red-team rulings (Kepu 2026-11-04)
- 1 Harvest Field: "Across" (12 / 16 / 20 studs wide; radius 6 / 8 / 10).
- 2 Deflector Claws: "Yes, in build 2" (one guarded line each in DiloAttackServer, TenoMovesServer, ScreechServer).
- 3 Snare root: "Reuse the Tether chain".
- 4 Reaper's Hook star cut-1 hook: kept as recommended (one guarded call).
- 5 Builds: "Two builds".

## Red-team
1. Harvest Field "12 / 16 / 20-stud circle": across or out from the centre? Across = 12 / 16 / 20 studs wide (10 out at
   max, about the therizino's own length). Out from the centre = 24 / 32 / 40 studs wide (a big zone). Recommended: across
   (the mockup drew it that way; bleed 4/s plus a 30% slow in a 40-wide zone would cover most fights).
2. Deflector Claws touches other dinos' servers (dilo dart, teno mortar, Shock Cannon) — the biggest risk in this plan. A
   shared module keeps each edit to one guarded line. Rockets are dropped (none exist). Recommended: keep, build 2.
3. Snare "rooted": reuse TetherServer's rope (proven, players and bots) vs a new "rooted" tag every mover would have to
   read. Recommended: the rope.
4. Reaper's Hook ★ "cut 1 starts on it" needs a small hook into TheriAttackServer (do-not-touch otherwise). Recommended:
   allowed as one guarded call.
5. Scope: 7 parts ~ the teno's two builds. Recommended: two builds as above.
