# Mecha Dino Arena v2.0 — Therizino mecha parts, new looks

**Goal:** replace the 7 Therizino part models (the "slop" boxes) with the redesigned looks Kepu picked, so that they move
like real machines. The moves, numbers, buttons and Lab texts stay exactly as they are.

**Intent (Kepu 2026-11-04 13:25):** "redesign these mecha parts ... create models in our styles ... this just looks like
slop". Scope "Therizino first" (the other dinos follow once this style is approved). 13:49: one-sided parts go on the
camera side. ShoulderCam 1.8 sits over the RIGHT shoulder = +X, and the dino models' L / R names are mirrored, so the camera
side is the model's "…L" parts (Dev Hub lesson 2026-11-04).

**Picks (Kepu 2026-11-04 14:13, mockup docs/mockups/therizino_parts_redesign.html v0.2):** Hook-A Harpoon Gauntlet,
Feathers-A Blade Wings, Harvest-A Pile Bunkers, Grapple-B Belly Winch, Deflect-A Umbrella Gauntlets, Overclock-A Piston
Legs, Snare-A Tail Spool Rig.

**Architecture:** the mockup is the source of truth for the geometry. A small export tool turns its picked looks into a
Luau data module, so the game uses the same numbers as the page. TheriPartsServer builds from that module (v1 builders stay
behind a switch). The moving bits are welded into groups. Each group hangs on one **Weld** whose C0 a new every-client
script, TheriPartsAnim, drives from the same stamps TheriMovesFX already reads. The groups use Welds and not Motor6Ds
because IdleAnimation adopts every Motor6D in the character (IdlePose.addMissing) and would fight us.

## Global constraints
- Additive. TheriPartsServer's v1 tables / builders stay. New behaviour sits behind `TheriPartsLooksV2Enabled` (default
  true; false = v1 looks exactly as published in v423 / v426).
- Versions: TheriPartsServer 1.1, TheriMovesFX 1.2, TheriPose 1.8, new TheriPartsLooksV2 1.0 (data), new TheriPartsAnim
  1.0, new tools/mockup/export_theri_parts_v2.js 1.0, new TheriPartsLooksV2.spec 1.0, mockup v0.3 (role / group tags
  only, no visual change). VERSIONS.md and ATTRIBUTES.md get a row each.
- Install by multi_edit / execute_luau and verify by hash. One-player tests. Publish only on Kepu's "Publish" (both places).
- Style kit (from the mockup):
  - **shell** #5a636f and **plate** #828c99: Plastic with Studs on every face (DinoModelBuilder's rule).
  - **trim** #26292f, **bone** #e2dccb, **rubber** #16171b, **hazY** #ffc832 / **hazK** #1a1a1a: SmoothPlastic.
  - **brass** #c9a24a, **steel** #9aa3ad, **iron** #5d636c: Metal.
  - **glow**: Neon in the part's Lab area colour (attack #ff3b30 Hook / Feathers / Harvest; speed #ffc21a Grapple /
    Overclock; defense #3d9bff Deflect; engineer #ff8a1a Snare).
- Shapes: box → Part; wedge → WedgePart (the mockup's wedge = Roblox's: full bottom and back faces); cyl → Part Cylinder
  (mockup axis Y → Roblox axis X, the existing 90° Z turn); ball → Part Ball; cone (pile tip only) → 4 WedgeParts as a
  pyramid. Every piece is Massless with CanCollide / CanQuery / CanTouch off; Neon pieces don't cast shadows.
- No HUD change (buttons, tiles and Lab texts are untouched), so no PC / phone UI work.

## Do-not-touch
TheriMovesServer (rules, numbers, remotes), SkillTree / SkillEffects (texts, effects), MechaButtons / AbilityBar / Lab /
MainMenu, IdleAnimation, TheriGrappleZip, DeflectRules, every other dino's parts. TheriMovesFX and TheriPose get only the
small v2 hooks in Tasks 4–5.

## File structure
| File | New / changed | Job |
|---|---|---|
| tools/mockup/therizino_parts_v2_looks.js | changed (v0.3) | `role` / `group` tags on the picked looks' pieces |
| tools/mockup/export_theri_parts_v2.js | new | headless export of the 7 picked looks → src/shared/TheriPartsLooksV2.luau |
| src/shared/TheriPartsLooksV2.luau | new (generated) | pieces, groups and beams per part id (ServerStorage.DinoArcade) |
| tools/tests/TheriPartsLooksV2.spec.luau | new | data checks (Studio Edit) |
| src/server/TheriPartsServer.server.luau | 1.1 | builds v2 looks + Lab cards from the module |
| src/client/TheriPartsAnim.client.luau | new | every client: drives the groups' Weld C0 from the stamps |
| src/client/TheriMovesFX.client.luau | 1.2 | the hook chain leaves the gauntlet muzzle; no FX rotors on v2 deflect; v2 overclock glow in the speed yellow |
| src/character/IdleAnimation/TheriPose.luau | 1.8 | Hook aim raises the camera-side arm (the gauntlet) instead of the crane lean |

## Deterministic map (per part: rest look → when used → back to rest)
| Part · look | Sits on | Moving groups (TheriPartsAnim) | When used (stamp → end) | Rest |
|---|---|---|---|---|
| zhook · Harpoon Gauntlet (55 pieces + 1 beam) | camera-side forearm (model ArmL_fore), beam to ArmL_upper | `drum` spins about its axis 14 rad/s; `hookhead` hidden | TheriHookAt → +0.15 + TheriHookPullTime + 0.2 (the FX chain + hook fly from role `muzzle`) | drum still, hookhead shown |
| zfeather · Blade Wings (78) | both forearms | 12 `blade_k` groups fan open (angles from the mockup) and quiver | TheriFeatherAt → +0.6 open, closed by +1.0; FX hides role `blade` until TheriFeatherReadyAt (as now) | folded |
| zharvest · Pile Bunkers (62) | both forearms | `pile_L` / `pile_R` ram 0.9 studs × scale, 0.9 s pump | TheriFieldAt + 0.35 → TheriFieldUntil, or until the body moves (TheriPose's rule: flat speed ≥ 6) | retracted |
| zgrapple · Belly Winch (50) | under the body + chest | `drum` spins 16 rad/s; `prong_1..3` open 45° | TheriGrappleAt (result "zip") → + TheriGrappleTime + 0.2 | closed |
| zdeflect · Umbrella Gauntlets (54) | both forearms / wrists | 12 `rib_k` swing out (−170° → −75°) in 0.15 s, then the hub set spins 14 rad/s (opposite ways per arm) | TheriDeflectAt → TheriDeflectUntil, fold over 0.3 s | folded along the arm |
| zclock · Piston Legs (56) | haunches, thighs, knees, shins | `gear_L` / `gear_R` spin 12 rad/s; 8 `fin_k` flip 10° → 50° | TheriClockAt → TheriClockUntil | gears idle 0.3 rad/s |
| zsnare · Tail Spool Rig (66) | Tail2 / 3 / 4 | `spool_1..3` spin 16 rad/s | TheriSnareAt → +0.6 | still |
Edge branches (every look):
- Part not slotted → no model (as now).
- Character respawn → built again on spawn (as now).
- Scale change (GrowthServer ScaleTo) → TheriPartsAnim re-reads each Weld's rest C0 when `char:GetScale()` changes (the
  IdleAnimation 1.24 re-fit rule).
- Another player's therizino → animated on every client from the replicated stamps.
- `TheriPartsAnimEnabled` false → groups sit at rest.
- `TheriPartsLooksV2Enabled` false → v1 looks.

## Tasks

### Task 1 — Export the picked looks to data · Mode: Logic
**Files:** modify `tools/mockup/therizino_parts_v2_looks.js` (role / group tags, v0.3). Create
`tools/mockup/export_theri_parts_v2.js`, `src/shared/TheriPartsLooksV2.luau` (generated) and
`tools/tests/TheriPartsLooksV2.spec.luau`.
**Interfaces:** produces `TheriPartsLooksV2.LOOKS[id] = {pieces = {{anchor, shape, size {x, y, z}, off {x, y, z, r00..r22},
mat, role?, group?}}, groups = {{name, anchor, pivot (CFrame components, anchor-relative)}}, beams = {{a0 = {part, pos},
a1 = {part, pos}, width}}}`, `TheriPartsLooksV2.GLOW[id] = Color3`, `TheriPartsLooksV2.Version = "1.0"`. Sizes and offsets
are at scale 1; the server multiplies positions by the model scale.
- [ ] Tag the moving pieces in the 7 picked looks with `group` and pivot, and the FX pieces with `role`: zhook `muzzle`,
  `hookhead`, `drum`; zfeather `blade`; zgrapple `nozzle`, `drum`, `prong`; zdeflect `hub`, `rib`; zclock `ring` (the glow
  pieces), `gear`, `fin`; zsnare `spool`.
- [ ] Write the exporter: load the page headless, build each picked look at use = 0, and for each piece write
  `anchor.cf⁻¹ × pieceRest` (static) or `mountOff × place(0, 0)` (placed). Write the cone as 4 wedges. Emit the Luau module.
- [ ] Write the spec, run it and watch it fail on an empty module.
- [ ] Export, then run the spec until it passes.
- [ ] Commit.
**Acceptance:**
- Piece counts match the mockup: 55 / 78 / 62 / 50 / 54 / 56 / 66.
- Every anchor is a real TherizinoModelData part.
- zhook's pieces all sit on "…L" parts (the camera side).
- Every `mat` is in the kit, and every role that TheriMovesFX / TheriPartsAnim read exists.
- Every group has ≥ 1 piece and one pivot.
- Re-running the export gives the identical file (same hash).
**Out of scope:** the 10 un-picked looks (they stay mockup-only).

### Task 2 — Build the v2 looks in the game · Mode: Wired
**Files:** modify `src/server/TheriPartsServer.server.luau` (1.1).
**Interfaces:** consumes `TheriPartsLooksV2` (Task 1). Produces `ZPart_<id>` models with attribute `ZPartLooks = "v2"`.
Group roots carry a Weld named `ZPartJoint_<group>` (Part0 = anchor, Part1 = group root, C0 = pivot × scale) and attribute
`ZPartGroup`. Members are welded (WeldConstraint) to their group root, static pieces to their anchor. Each beam is a Beam
`ZPartBeam_<n>` (rubber colour, width × scale, Segments 6, CurveSize0 −0.6) between two Attachments. Lab cards use the same
build.
- [ ] Add the material kit and the shape mapping (Global constraints).
- [ ] Add `buildV2(model, id)` next to `buildPart` and choose between them by `TheriPartsLooksV2Enabled`.
- [ ] Install, then check in Studio Play: all 7 slotted, the counts in `TheriPartsBuilt`, each look captured from the Player
  camera and compared with the mockup's Player camera / close-up.
- [ ] Commit.
**Acceptance:**
- Each look matches its mockup capture (same placement, colours and studs).
- The gauntlet is on the camera side.
- The Lab card shows the new look.
- With the switch off you get the v1 looks.
- Nothing collides or blocks raycasts (CanQuery off).
- 4 parts slotted: ≤ 260 pieces on the dino.
**Out of scope:** motion (Task 3).

### Task 3 — Make the machinery move · Mode: Wired
**Files:** create `src/client/TheriPartsAnim.client.luau` (1.0, StarterPlayerScripts).
**Interfaces:** consumes `ZPartJoint_<group>` Welds (Task 2) and the stamps in the deterministic map. Produces local Weld C0
each RenderStepped. Diagnostics: script `TheriPartsAnimVersion`, `TheriPartsAnimJoints` (count driven), character
`TheriPartsAnimState` (this client).
- [ ] Port the mockup's motions per group (same angles, speeds and timings as the table).
- [ ] Re-capture rest C0 on scale change; drop characters that leave.
- [ ] Studio: use each part, check every motion, and capture the deploy frames (frozen clock).
- [ ] Commit.
**Acceptance:**
- Every row of the deterministic map behaves as written, at scale 2 and after a ScaleTo.
- The groups return to rest exactly.
- No error with the part unslotted mid-motion.
- The switch off leaves everything at rest.

### Task 4 — FX hooks for the new looks · Mode: Wired
**Files:** modify `src/client/TheriMovesFX.client.luau` (1.2).
- [ ] Hook chain origin: role `muzzle` if present, else `jib` (v1). With v2 the bone sickle flies at the chain's tip (built
  from the `hookhead` pieces' sizes and colours) while the gauntlet's own `hookhead` is hidden (TheriPartsAnim).
- [ ] Deflect: skip the FX rotors when `ZPartLooks == "v2"` (the ribs are the rotor), and keep the block flash at the hub.
- [ ] Overclock: v2 `ring` pieces pulse between the speed yellow and white instead of orange.
- [ ] Switch `TheriMovesFXV2Enabled`.
- [ ] Commit.
**Acceptance:**
- The chain leaves the gauntlet muzzle.
- There are no double rotors.
- The v1 looks still use the v1 FX.

### Task 5 — Hook aim pose · Mode: Wired
**Files:** modify `src/character/IdleAnimation/TheriPose.luau` (1.8).
- [ ] With the v2 hook look on, the hook pose aims the camera-side arm: `ArmL {70, 0, 6}, ArmR {10, 0, 0},
  RootJoint −6, Neck −4` (the mockup's ARM_L_FWD), same timing as 1.6's HOOK_AIM. Switch `TheriHookArmPoseEnabled`.
- [ ] Capture the pose from the Player camera.
- [ ] Commit.
**Acceptance:**
- The gauntlet arm points where the chain goes.
- The v1 crane look keeps the 1.6 pose.

### Task 6 — Studio check, docs, report · Mode: Wired
- [ ] Do a full Play pass with all 7 (4 at a time in the slots), on PC, plus the Lab cards. Test values go on the test
  player only and are restored; slots are cleared to "".
- [ ] Captures go in docs/reference/therizino/parts_v2_*.jpg.
- [ ] Add the VERSIONS / ATTRIBUTES rows.
- [ ] Report with Added / Removed / Next, and wait for "Publish". Kepu checks on his phone after the publish.

## Red-team (draft, waiting on Kepu)
1. **Phone frame rate.** 4 slots can put about 260 extra pieces and about 40 moving joints on one therizino, and several
   therizinos in a server multiply that. Mitigation: TheriPartsAnim only updates groups while a move plays, and a
   `TheriPartsDetail = "lite"` switch drops bolts, teeth and stripes (about 30% of the pieces). Kepu's phone test after
   the publish decides whether lite becomes the default.
2. **Other players seeing the motion.** Weld C0 is changed locally on every client, the way IdleAnimation already poses
   joints. The rule says no second player, so Task 3 checks it with a server-made therizino dummy whose stamps the server
   sets, which the test client must see move.
3. **The hook firing from a hanging arm.** Without the Task 5 pose, the chain would leave a muzzle that points at the
   ground. Task 5 stays in.
4. **Arm parts look small from the player camera.** Kepu picked them after seeing the Player camera view, so this is an
   accepted risk.
5. **Mockup → game drift.** The exporter takes the numbers from the page itself, with the spec plus side-by-side captures
   in Task 2.
