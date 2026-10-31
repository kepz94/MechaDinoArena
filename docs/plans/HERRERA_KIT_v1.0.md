# Mecha Dino Arena v1.0 — Herrerasaurus kit (playable, auto-climb, tree tops, dash-through slash)

**Goal:** the Herrerasaurus is a pickable day-1 dino: a fast, fragile pest that climbs trees on its own, stands on the tree tops where nothing else can follow, and hits with a dash-through slash that leaves the target bleeding.
**Intent (Kepu 2026-10-30):** "a utility Dino someone that's a Pain in the ass to deal with but easy to kill" · "the most mecha utility and the fastest in the game" · 40 HP · ATTACK = hit-and-run slash · hard to catch + climber · "climbing should just happen. If I walk up to a tree as a herra it should automatically start climbing the tree vertically" · slash "Dash-through slash", payoff "Bleed", climbable "Trees only" · drop attack: "should be able to happen if I press the dash aimed at a nearby target but not be its own dedicated button" · "make the top of the trees and palms itself be able to stand on" -> "Herrera only" · dash look "A" (claw streaks).
**Build:** Kepu "Go, all 12 in order".
**Chosen direction:** mockup `docs/mockups/herrera_kit_options.html`, look A · Claw streaks (yellow speed trail during the dash, three red claw marks across the target on the hit, yellow hit number, red bleed numbers).
**Architecture:** follows the pachy's playable pattern. Data on HerreraModelData; species / scale / stats like the pachy; tree tops are invisible proxy parts (new, Herrera-only collision group, not queryable) so the island's own tree parts stay untouched; climbing runs on the owner's client (its body is client-owned physics) and reports its state to the server; the slash copies HeadbuttServer's request / hit-claim / server-owned-charges pattern; poses are IdleAnimation layers; the hitboxes follow the climb like they follow the scurry.

## Global Constraints
- Additive: every change sits behind a switch; raptor / T-Rex / pachy behaviour unchanged.
- Versions: HerreraModelData 1.2 (generator 1.2), StatSheet 1.3, SpeciesServer 1.4, RaptorScale 1.3, TreeTopServer 1.0, ClimbLogic 1.0, ClimbTest 1.0, ClimbServer 1.0, ClimbPose 1.0, IdleAnimation 1.32, ScurryHitbox 1.1, SlashServer 1.0, SlashTest 1.0, SprintTest 1.11, SlashPose 1.0, SlashFX 1.0, AbilityBar 1.8, MainMenu 1.9; specs StatSheet 1.3, ClimbLogic 1.0.
- Numbers are model attributes (tunable): 40 HP; run 90 / walk 48 (raptor 78 / 41.6, about +15%; arena scale applied by StatServer as for every dino); slash dash 25 studs in 0.3 s (at the 2x body), 8 damage, bleed 3 / s for 4 s (players too), 2 charges, 4 s refill each, 0.5 s speed burst x1.4; drop attack range 40 studs, aim cone 35 degrees; climb speed 20 studs/s.
- Install via multi_edit, verify by hash; test with Studio tools only; publish only on Kepu's "publish".

## Do-not-touch
The island's tree parts (Trees folder: trunks, leaves, fronds keep their CanCollide / groups), DinoHitboxes, HeadbuttServer / PounceServer / BiteServer, SkillEffects (its bleed stays the skill bleed), WalkPose / IdlePose / ScurryPose, RaptorModelData / TRexModelData / PachyModelData, BotServer, the Lab.

## Deterministic map
| State | Condition | Result |
|---|---|---|
| Ground | not climbing, not on a tree top | scurry gait, LMB = ground dash |
| Grab | Herrera, ClimbEnabled, moving forward, a trunk part (Trees descendant named `^Trunk`) within ClimbGrabDist ahead at body height | ClimbState "climbing" (server stamped), body held on the trunk |
| Climbing | holding forward | moves up the trunk at ClimbSpeed |
| Clinging | on the trunk, forward released | holds still |
| Slide down | on the trunk, holding back | moves down at ClimbSpeed; at the ground -> Ground |
| Hop off | Space on the trunk or a tree top | small hop backward / off -> Ground (air) |
| Mantle | climbing and a tree-top proxy is within ClimbTopGap above the head, or the trunk ends | moved onto the top face of the highest proxy over the trunk -> TreeTop |
| TreeTop | standing on a proxy | normal scurry / idle on it; walking off the edge falls -> Ground |
| Dash (ground) | LMB, a charge, not stunned / pinned / menu | 25-stud dash along the body's facing, claws each dino passed once, speed burst after |
| Dash (dive) | LMB while Climbing / Clinging / TreeTop, a dino within ClimbDiveRange, below, inside the aim cone of the camera look | dash arcs down to that dino, claws it (and any dino passed), speed burst after landing |
| Dash (no target from a tree) | LMB on a tree, no dino in the cone | leaps off forward (same dash, no target) |
| Empty / stunned / pinned / menu / dead | LMB | refused with a reason (SlashServerResult), nothing moves |
| Bleed | a slash hit, target not shielded | 3 / s for 4 s; a new hit restarts it; a shielded target takes the hit, not the bleed |
| Other dinos at a tree top | any | pass through leaves as today (proxies only collide with the Herrera's body) |

## Task 1 — HerreraModelData 1.2 · Mode: Logic
**Files:** `tools/herrera_generator.py` 1.2, `src/shared/Models/HerreraModelData.luau`.
**Steps:** attributes DinoMaxHealth 40, MoveRunSpeed 90, MoveWalkSpeed 48, CameraStartZoom 16, TurnLimitRate 540 (raptor values), SlashEnabled true, Slash* (SlashCharges 2, SlashRefill 4, SlashDist 12.5, SlashTime 0.3, SlashDamage 8, SlashBleedDps 3, SlashBleedTime 4, SlashBurstMul 1.4, SlashBurstTime 0.5, SlashDiveRange 20, SlashDiveCone 35, SlashReach 2) — distances at scale 1, doubled by the 2x body; ClimbEnabled true, Climb* (ClimbSpeed 10, ClimbGrabDist 1.5, ClimbTopGap 2, ClimbHopSpeed 12). Geometry unchanged; generator asserts kept.
**Acceptance:** only attribute / version lines differ from 1.1; install hash checked.

## Task 2 — StatSheet 1.3 · Mode: Logic
**Files:** `src/shared/StatSheet.luau`, `tools/tests/StatSheet.spec.luau`.
**Interfaces:** produces `StatSheet.SPECIES.Herrera = {class = "Utility", start = {Health = 2, Attack = 3, Defense = 2, Speed = 10, Support = 1}, abilities = {"Dash-through slash", "Auto-climb"}}`; ATTACK_KEYS gains SlashDamage.
**Steps:** spec first (Herrera present, start points sum, SlashDamage scales with Attack) -> FAIL -> code -> PASS.

## Task 3 — Playable Herrera: SpeciesServer 1.4 + RaptorScale 1.3 · Mode: Wired
**Files:** `src/server/SpeciesServer.server.luau`, `src/server/RaptorScale.server.luau`.
**Steps:** a Herrera template from HerreraModelData exactly like the pachy's (SpeciesHerreraEnabled, SpeciesHerreraTemplate; "Herrera" a known species; respawn keeps it; remembered like the others). RaptorScale scales Species "Herrera" characters by HerreraScale (2) (RaptorScaleHerreraEnabled).
**Acceptance:** DinoSpeciesRequest "Herrera" -> ok; spawns 2x, 40 HP, run speed = 90 x arena scale; death respawns a Herrera; raptor / pachy / T-Rex switching unchanged.

## Task 4 — TreeTopServer 1.0 · Mode: Wired
**Files:** Create `src/server/TreeTopServer.server.luau`.
**Steps:** collision groups "HerreraBody" (collidable exactly like "Default" with every registered group, copied at start) and "TreeTop" (collidable with HerreraBody only). Folder Workspace.DinoIsland.TreeTops with invisible proxies (Transparency 1, Anchored, CanCollide true, CanQuery false, CanTouch false, group TreeTop, attribute TreeTopOf = tree name): jungle trees -> one proxy per Canopy / Canopy2 / Canopy3 / CanopySide (same CFrame and size); pines -> Leaves1-4; palms -> one flat box (crown-centred, frond span x 0.8 wide, 0.6 thick, top at the highest frond's top). Herrera characters' HumanoidRootPart -> HerreraBody (CharacterAdded + Species "Herrera"). Switch TreeTopEnabled (off = no proxies, no group change). Diagnostics TreeTopCount (by kind), TreeTopState.
**Acceptance:** 357 trees -> proxies built; a Herrera dropped onto a palm / jungle / pine top stands on it; a raptor / pachy / bot falls through as today; island tree parts unchanged (CanCollide / group counts identical before and after).

## Task 5 — ClimbLogic 1.0 · Mode: Logic
**Files:** Create `src/shared/ClimbLogic.luau`; Test `tools/tests/ClimbLogic.spec.luau`.
**Interfaces:** `ClimbLogic.step(state, input, probe, s) -> newState, velocity` (pure): state "ground" / "climbing" / "clinging" / "top"; input {forward, back, hop}; probe {trunkAhead (distance or nil), topAbove (gap or nil), groundBelow (gap), onTop}; returns the next state and the wanted vertical speed / hop. `ClimbLogic.mantleTarget(proxies, trunkPos) -> CFrame` (top face of the highest proxy over the trunk). Every row of the deterministic map is a spec case.

## Task 6 — Climbing: ClimbTest 1.0 + ClimbServer 1.0 · Mode: Wired
**Files:** Create `src/character/ClimbTest.client.luau`, `src/server/ClimbServer.server.luau`.
**Steps:** owner client, Herrera only: probes each frame (forward ray at body height against trunk parts; proxies read from the TreeTops folder by position, not raycast); ClimbLogic.step; while climbing / clinging: Humanoid PlatformStand, a LinearVelocity (vertical) and AlignOrientation (body faces the trunk) on the HumanoidRootPart, held ClimbGrabDist from the trunk surface; mantle = CFrame onto mantleTarget; hop = velocity back + up; exit restores the humanoid. Remote DinoClimbState(state, treeName) -> ClimbServer stamps ClimbState / ClimbTree / ClimbAt on the character (checks: Herrera, alive, not menu; tree exists; "top" only within 6 studs of a proxy top). Switch ClimbEnabled (model) + ClimbServerEnabled.
**Acceptance:** run into a palm, jungle and pine trunk -> climbs; release -> clings; back -> slides down to the ground; Space -> hops off; top -> stands on the tree top; other players see ClimbState.

## Task 7 — ClimbPose 1.0 + IdleAnimation 1.32 + ScurryHitbox 1.1 · Mode: Wired
**Files:** Create `src/character/IdleAnimation/ClimbPose.luau`; Modify IdleAnimation (climb layer), `src/server/ScurryHitbox.server.luau`.
**Steps:** while ClimbState is climbing / clinging: RootJoint pitch +90 (nose up, belly on the trunk), limbs in the scurry diagonal-pair cycle driven by climb distance (still while clinging), tail hanging; replaces the idle / scurry pose by its weight (0.2 s blend). ScurryHitbox: a third box target "climb" (the same FK with the climb pose) used while ClimbState is climbing / clinging.
**Acceptance:** captures match the mockup's climb; hitboxes stand vertical on the trunk while climbing (server).

## Task 8 — SlashServer 1.0 · Mode: Wired
**Files:** Create `src/server/SlashServer.server.luau`.
**Steps:** HeadbuttServer pattern. Server-owned charges (SlashChargesNow / Max, SlashRefillStart / At). Remotes: DinoSlashRequest(stamp, kind, targetName?) -> "badArg" / "dead" / "disabled" / "menu" / "stunned" / "pinned" / "busy" / "empty" / "noTree" (kind "dive" while not climbing / on a tree top) -> "ok" (charge spent, SlashStartedAt, SlashKind, SlashFrom = server position, SlashDir). DinoSlashHit(stamp, model) -> once per target per dash; valid when the target's closest hitbox point is within SlashReach x scale + tolerance of the dash path (segment from SlashFrom along SlashDir for the dash length, or to the dive target) and within the dash time + slack; damage SlashDamage x roar debuff off DummyHealth (kill stamps KilledWith "slash"); bleed (own table, ticks every 0.5 s, SlashBleedUntil / SlashBleedBy on the target, kill stamps KilledWith "bleed"), skipped under the Energy Shield; attacker SlashBurstUntil / SlashBurstMul at the dash end. Switch SlashServerEnabled.
**Acceptance:** charges 2 -> 1 -> 0, refill 4 s each; a hit takes 8 and bleeds 12 over 4 s; a second hit restarts the bleed (no stacking); shielded target: hit, no bleed; far claims "far"; same target twice "used".

## Task 9 — SlashTest 1.0 + SprintTest 1.11 · Mode: Wired
**Files:** Create `src/character/SlashTest.client.luau`; Modify `src/character/SprintTest.client.luau` (+ SlashBurstUntil / SlashBurstMul in its multiplier list).
**Steps:** LMB / gamepad R2 / touch "Slash" (like HeadbuttTest) on Herrera only. Ground: LinearVelocity along the facing for SlashTime; dive: pick the dino (Hitboxes + Bitable, not self) within SlashDiveRange x scale, below the body, nearest the camera look inside SlashDiveCone; none -> leap forward. Each frame of the dash: overlap test of the body against target hitboxes -> DinoSlashHit claims. Local state for the pose (SlashLocalState).
**Acceptance:** dash covers ~25 studs; passes through a bot -> one claim, "hit"; dive from a palm top onto a bot below lands next to it; speed burst after.

## Task 10 — SlashPose 1.0 + SlashFX 1.0 (look A) · Mode: Wired
**Files:** Create `src/character/IdleAnimation/SlashPose.luau` (+ IdleAnimation layer), `src/client/SlashFX.client.luau`.
**Steps:** pose: arms thrown forward and the swipe at mid dash, nose-down dive. FX (option A): yellow speed trail during the dash; three red claw marks across the target on SlashHitAt; yellow "-8"; red "-3" per bleed tick and blood drops while SlashBleedUntil.
**Layout:** same colours as the mockup: trail FFE066, claw marks FF3B2F, hit number FFD84A, bleed number FF4A4A.

## Task 11 — AbilityBar 1.8 + MainMenu 1.9 · Mode: Wired
**Files:** `src/character/AbilityBar.client.luau`, `src/client/MainMenu.client.luau`.
**Steps:** SPECIES_MOVES.Herrera = {"Slash", "Hop"}: Slash tile "SLASH" on LMB with the headbutt tile's pips (2, refill fill from the bottom), yellow stroke while dashing, dim when empty; Hop tile "HOP" on Space, lit only while climbing / on a tree top (dim on the ground). MainMenu DINOS + {id = "Herrera", name = "HERRERA", sub = "40 HP · climber, dash slash"} after the pachy (switch MainMenuHerreraEnabled).
**Layout:** exactly the mockup's bar: R, T, LMB SLASH (pips), Space HOP.

## Task 12 — Studio Play check · Mode: Wired
Pick Herrera in the menu; climb a palm, a jungle tree, a pine; stand on each top; a raptor bot cannot stand there; ground dash through a bot (8 + bleed 12); dive from a tree top onto a bot; charges and refill on the bar; captures to docs/reference/herrera/; raptor / pachy / T-Rex unchanged.

## Red-team
1. **Server sees the dash late.** The Herrera's body is moved by its own client; HeadbuttServer 1.4 found the server position lagging ~18 studs on a charge. Mitigation (in Task 8): hits are checked against the dash path from the request (SlashFrom + SlashDir / dive target) and a time window, not the server's current body position.
2. **Tree-top camping.** Nothing else can stand up there, so a Herrera can sit on a tree top out of reach. Ranged mecha parts (hook, mines, screech) still reach it; a melee-only player cannot. Kepu 2026-10-30: "Allow it" — accepted risk: only ranged mecha parts reach a Herrera on a tree top.
3. **Making leaves solid breaks other systems.** Avoided: the island's leaves are not changed; the tree tops are new invisible proxies with CanQuery off, so every existing raycast (StepAssist, Screech, Mine, MechaButtons, MedStation use RespectCanCollide) and every other dino ignore them.
4. **Humanoid fights the climb.** A Humanoid tries to stand up / fall; climbing uses PlatformStand + LinearVelocity + AlignOrientation (the HeadbuttShove approach for forces) and restores the humanoid on every exit (hop, slide to the ground, mantle, death, stun). Each exit is an acceptance item.
5. **Size of the drop.** 12 tasks. Build order puts the playable dino + tree tops + climbing first (Tasks 1-7), then the slash (8-11), so the climb can be tried while the slash is built.
