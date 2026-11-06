# Mecha Dino Arena — Herrerasaurus mecha parts, new looks (plan v2.0)

**Ask (Kepu 2026-11-05 19:10):** "Next it looks good" → "Herrera looks + animations" (the Teno / Therizino treatment:
looks first, then the animation pass). **Picks (19:39, mockup docs/mockups/herrera_parts_redesign.html v0.1, artifact
D72LBxUy3HeQWzXwruNNih): "A for everything except B for the Quill launcher":** Iron Claw A **Wing Blades** (Monster Hunter
Nargacuga), Glider Wings A **Sword Wings** (Zoids Storm Sworder), Quill Launcher B **Missile Pods** (Zoids Gun Sniper), Smoke
Pods A **Stealth Generator** (Horizon Stalker), Back Plating A **Lamellar Armour** (samurai o-yoroi), Blood Siphon A **Fang
Siphons** (MH Sunbreak Malzeno), Strobe Frill A **Flash Crest** (MH Gypceros), Stun Breaker A **Tesla Coils** (Red Alert),
Razor Caltrops A **Drop Chute** (Spy Hunter), Goo Blob Shooter A **Spit Sacs** (HFW Bilegut), Adrenaline Injector A **Stim
Shot** (Apex Legends Octane).
**Why (grounded):** HerreraPartsServer 1.3 builds 5–34 flat pieces per part, all welded still; the only motion is the
glider being rebuilt open / folded on `Gliding` (1.2), the fluid Transparency tween (1.3) and HerreraMovesFX's goo /
caltrop kick copies.
**Architecture:** the Teno v2 path (plan TENO_PARTS_LOOKS_v2.0, live since v463): the mockup is the source of truth, an
export tool writes a Luau data module, the parts server builds from it (old builders kept behind a switch), moving bits are
groups on Welds that a new every-client script drives from the stamps the move servers already set. Existing FX keep
working through the same `HPartRole` names.

## Global constraints
- Additive, every change behind a switch; off = today's look exactly. No numbers, remotes, buttons, Lab texts or SkillTree
  rows change. No HUD change (PC and phone untouched). Saved progress untouched.
- Versions: HerreraPartsServer 1.4, new HerreraPartsLooksV2 1.0 (generated), new HerreraPartsAnim 1.0, new
  tools/mockup/export_herrera_parts_v2.js 1.0, new tools/tests/HerreraPartsLooksV2.spec 1.0, HerreraMovesServer 1.4,
  HerreraPartsFX 1.1, mockup v0.2 (export tags only, no visual change). VERSIONS.md + ATTRIBUTES.md rows.
- Style kit as Teno v2 (studded shell / plate, SmoothPlastic trim / bone / rubber / hazard, Metal brass / steel / iron /
  bright / copper, Neon glow in the Lab area colour: attack #ff3b30, defense #3d9bff, health #3ddc84, speed #ffc21a,
  engineer #ff8a1a; goo lime #a6e22e, blood #d0202a, adrenaline #46e08a). Massless, no collide / query / touch.
- One-sided parts on the camera side (+X, the "…L" parts): the Stim Shot is on the left shoulder.
- Install by multi_edit / execute_luau, verify by hash. One-player tests; test SkillSlots saved in ZZ_TenoTestBefore-style
  attribute and restored. Publish only on "Publish".
- Body poses do not change in this plan (raptor IdleAnimation untouched); the mockup's "Use it" poses, arcs, flash cone,
  shock rings, haze and veins are the animation pass that follows.

## Do-not-touch
SkillTree / SkillEffects, MechaButtons / AbilityBar / Lab / MainMenu, IdleAnimation and every pose script, SlashServer /
SlashTest, BoneCrest, AdrenalineServer, every HerreraMovesServer rule except the goo blob start point (Task 4), HerreraMovesFX
(its roles are kept, not edited), RaptorScale, every other dino's parts (TenoParts* / TheriParts* copied from, not edited).

## File structure
| File | New / changed | Job |
|---|---|---|
| tools/mockup/herrera_parts_v2_looks.js | v0.2 | `group` / `role` / `detail` tags on the 11 picked looks (no visual change) |
| tools/mockup/export_herrera_parts_v2.js | new | headless export of the picks → src/shared/HerreraPartsLooksV2.luau |
| src/shared/HerreraPartsLooksV2.luau | new (generated) | mounts, pieces, groups per part id |
| tools/tests/HerreraPartsLooksV2.spec.luau | new | data checks (Studio Edit) |
| src/server/HerreraPartsServer.server.luau | 1.4 | builds v2 looks + Lab cards from the module (Model "HPart_<id>", same names, HPartRole kept) |
| src/client/HerreraPartsAnim.client.luau | new | every client: drives the groups from the Herrera stamps |
| src/server/HerreraMovesServer.server.luau | 1.4 | the goo blob leaves the jaw nozzle ("muzzle") when there is one |
| src/client/HerreraPartsFX.client.luau | 1.1 | Iron Claw trail attachments on the blade tips (v2) |

## Deterministic map (part · look → roles kept → moving groups → driven by → rest)
| Part · look | Sits on | Roles (existing FX) | Groups (HerreraPartsAnim) | Driven by (server time) | Rest |
|---|---|---|---|---|---|
| ironclaw · Wing Blades | bracer on both forearms, 3 blades each | `blade`, `edge` (HerreraPartsFX flash); trail attachments on blade 1's tip | `blade_L1..3` / `blade_R1..3` swing about Z (−92 to −72°: back → forward past the hand) | SlashStartedAt: forward in 0.08 s, held SlashDashTime (else 0.3), back over 0.25 s | lying back along the forearm |
| glider · Sword Wings | hinge block on both shoulders, 4 blades each | `membrane` (4 yellow films per side), `glow` | `wing_L1..4` / `wing_R1..4` swing about Y (folded → spread, 81°–55° by blade) with child `droop_*` swing about Z | `Gliding` true: open over 0.3 s; false: fold over 0.3 s (replaces the 1.2 rebuild; the films fade in / out) | folded back along the flanks |
| quills · Missile Pods | a pod on each shoulder of the back | `tip` × 8 (the tube mouths: HerreraMovesFX quills leave them in turn) | `lid_L` / `lid_R` swing about X +58° | QuillStartedAt: open over 0.15 s, held until QuillLandedAt (else start + 1.5), shut over 0.3 s | shut; back quills stay visible (HIDES.quills off for v2) |
| smoke · Stealth Generator | tail base (Tail1_main) | `nozzle` (the core strip + 4 fin tips: smoke puffs leave them) | `fin_1..4` swing about X ±40° (alternate) | SmokeStartedAt → SmokeUntil: open over 0.25 s, close over 0.4 s | fins upright |
| plating · Lamellar Armour | hips, waist, chest, hump, Tail1, Tail2 (replaces the 7 quills as now) | `plate` (HerreraPartsFX hit flash) | `row_1..6` slide +Y 0.05 (one per body segment, 0.04 s apart) | PlatingHitAt: up 0.06 s, down 0.2 s (the ripple) | plates flat |
| siphon · Fang Siphons | fangs on Jaw_lower, glass tanks + blood fluid on both Neck_main sides, tubes jaw → tank | `core` (the 2 blood fluids: HerreraPartsFX beads fly into them, pulse on SiphonHealAt) | — (tubes = 2 Beams jaw → tank, follow both parts) | — | tanks 1/3 full |
| strobe · Flash Crest | mirror-steel face on all 11 frill blades, a bulb on each rim | `led` (the 11 bulbs: HerreraMovesFX strobes them white) | — | — | bulbs orange |
| breaker · Tesla Coils | a coil on each shoulder | `tip` (the 2 top balls: bolts leave them), `band` (the 2 brass rings: flash) | — | — | — |
| caltrops · Drop Chute | hopper on Tail1_main | `chute` (the slide exit: spikes leave it; hopper kick as now) | `door` swing about Z −69° | CaltropDroppedAt: open over 0.1 s, held until + CaltropCount × ArmGap + 0.2, shut over 0.3 s | shut |
| goo · Spit Sacs | lime sacs in iron rings on both Neck_main sides, nozzle under Jaw_lower | `muzzle` + `tube` (the nozzle: the kick copies + Task 4's blob start), `sac` | films `sac_L` / `sac_R` client-local Size × 0.65 (squeeze) | GooFiredAt: squeeze in 0.06 s, refill over 0.5 s | breathing ± 6 % |
| hadren · Stim Shot | syringe in the left shoulder (Torso_chest) | `fluid` (the green fluid: the 1.3 Transparency tween keeps working) | `plunger` slide −0.8 along the syringe | AdrenalineStartedAt: push over 0.5 s, held for AdrenalineTime, back over AdrenalineCooldown | plunger out |

Edge branches (every look):
- Part not slotted → no model (as now). Respawn → rebuilt. Another player's Herrera → animated on every client. Bots have no
  parts (as now).
- Scale change (RaptorScale / GrowthServer) → HerreraPartsAnim re-reads the rest C0 × (scale / built scale) (TheriPartsAnim rule).
- A stamp older than the model's build time → ignored (no replay on respawn).
- `HerreraPartsLooksV2Enabled` false → the 1.3 looks, HIDES and glide rebuild exactly. `HerreraPartsAnimEnabled` false →
  groups at rest (glider: shown open while Gliding through the 1.2 rebuild path only when V2 is off; with V2 on and Anim
  off it stays folded).
- `HerreraPartsDetail` "lite" → bolts / stripes / small glow nubs skipped (the Teno rule).
- Old roles not in v2: `spar`, `rod` (glider), `vent` — nothing reads them. Every role an FX script reads (blade, edge, plate,
  core, tip, nozzle, led, band, chute, tube, muzzle, fluid) exists on the matching v2 look.

## Tasks
### Task 1 — Tags + export + data · Mode: Logic
Files: tools/mockup/herrera_parts_v2_looks.js (v0.2: group / role / detail tags and pivots of the map), new
tools/mockup/export_herrera_parts_v2.js (from export_teno_parts_v2.js 1.0; PICKS ironclaw 0, glider 0, quills 1, smoke 0,
plating 0, siphon 0, strobe 0, breaker 0, caltrops 0, goo 0, hadren 0; Beams exported as {a0, p0, a1, p1}), generated
src/shared/HerreraPartsLooksV2.luau, new tools/tests/HerreraPartsLooksV2.spec.luau.
Acceptance: spec passes in Studio Edit: 11 ids; every anchor exists on HerreraModelData; every group in the map exists with
its type / axis / amount; every role listed in the map present; rest offsets equal the mockup's at use = 0 to 0.001; piece
counts reported (Lamellar ≤ 110, others ≤ 60).

### Task 2 — Build the looks · Mode: Wired
HerreraPartsServer 1.4: `buildV2` (from TenoPartsServer 1.3, prefix "HPart", attribute HPartRole), films invisible until
animated except the always-see-through ones (sacs, tanks, syringe glass), the 7 back quills hidden for plating only, the
Lab cards (BuildPreview_<id>) built from it with the glider open. Switch HerreraPartsLooksV2Enabled (default true).
Diagnostic HerreraPartsBuilt as now.
Acceptance: Studio Play, test Herrera, each part slotted in turn (slots restored): model on the right anchors, camera-side
view matches the mockup; each Lab card shows the new look; switch off → 1.3 looks.

### Task 3 — Make it move · Mode: Wired
New HerreraPartsAnim 1.0 (from TenoPartsAnim 1.0's frame loop): the map's groups and timings, film fades, sac Size pulse,
Beams for the siphon tubes. Switch HerreraPartsAnimEnabled. Diagnostics HerreraPartsAnimVersion, HerreraPartsAnimJoints,
model HerreraPartsAnimActive.
Acceptance: each move once in Studio: blades swing on a slash; wings spread while gliding and fold on landing; lids open for
a quill volley and quills leave the pods; fins open with the smoke and puffs leave the generator; plates ripple on a rear
hit; beads fly into the neck tanks; bulbs strobe; bolts from the coil tops; door opens and spikes leave the chute; sacs
squeeze on a goo shot; plunger pushes on the adrenaline. Player-camera captures for each.

### Task 4 — Goo from the mouth + claw trails · Mode: Wired
HerreraMovesServer 1.4: the blob's `from` = the HPart_goo "muzzle" piece position when present (else the hump as 1.3).
Switch HerreraMoves_gooMuzzleEnabled (default true). HerreraPartsFX 1.1: with v2 Iron Claw, the IronClawTip / IronClawMid
attachments are on blade 1's tip / middle (so the trail follows the swing). Switch HerreraPartsFXBladeTrailEnabled.
Acceptance: a goo shot leaves the jaw nozzle; the slash trail draws along the blade tips; switches off → 1.3 / 1.0.

### Task 5 — Docs, report, wait for "Publish"
VERSIONS / ATTRIBUTES rows, Dev Hub notes, report Added / Removed / Next. Then the animation-pass mockup.

## Red-team
(see the report to Kepu; resolved answers are folded in here after his reply)
