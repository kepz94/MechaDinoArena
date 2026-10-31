# Mecha Dino Arena v1.0 — Herrera mecha parts (spec all, build in one or two passes)

**Goal:** give the Herrera its own set of 8 mecha parts, like the Raptor and Pachy. All are spec'd first, then built together.

**Intent (Kepu 2026-10-31):**
- "Let's save this and work on other abilities the Herrera can have so we can just apply all of them at once."
- "make sure we spec all the abilities as we've done just now so we can be about to get all abilities done in one or two passes."

**Standing rules for every part in this plan:**
- The mockup shows the real Herrera model wearing the part, playing its attack animation, with arcade motion and a look that's recognizable at a glance.
- The mockup is self-contained (three.js inlined) and comes with an MP4.
- Every part:
  - is visible on the dino while slotted;
  - has a Lab card (BuildPreview_<id>);
  - sits behind a switch;
  - gets version rows.
- Today (Studio, 2026-10-31) the Herrera sees no mecha parts at all. The Raptor and Pachy each have 8.

## Status
| # | Part | Spec | Mockup | Built |
|---|---|---|---|---|
| 1 | Iron Claw (Hook Blades) MDA-149 | done (below) | docs/mockups/herrera_ironclaw_options.html, look B; video docs/reference/herrera/mockup_ironclaw_B.mp4 | no |
| 2 | Glider Wings (Bat Membranes) MDA-150 | done (below) | docs/mockups/herrera_parts_b1_options.html, look A; video docs/reference/herrera/mockup_parts_b1_glider.mp4 | no |
| 3 | Quill Launcher (Spine Quills) MDA-151 | done (below) | same page, look B; video mockup_parts_b1_quills.mp4 | no |
| 4 | Smoke Pods (Tail Vents) MDA-152 | done (below) | same page, look B; video mockup_parts_b1_smoke.mp4 | no |
| 5 | Back Plating (Spine Scutes) MDA-153 | done (below) | same page, look A; video mockup_parts_b1_plating.mp4 | no |

The Herrera ends with 5 parts (Kepu picked these 4 from 16 ideas on 2026-10-31). More can be added later the same way.

**Shared for parts 2–5:**
- Steel / dark steel / hot-orange accent, the same colours as Iron Claw (STEEL rgb(154, 166, 184), DARK rgb(93, 104, 120), HOT rgb(255, 138, 42)). The membrane canvas is rgb(224, 116, 42).
- Sizes are at model scale 1 (×2 in game).
- Mockup sources live in tools/mockup/ (parts_b1_app.js and parts_b1_head.html, built by build2.py).

---

## Part 1 — Iron Claw (`ironclaw`) · ATTACK · Herrera only

### Decisions (Kepu 2026-10-31)
- "Let's have an iron claw ability that raises damage by 50% but sacrifices speed by 25% at the star level."
- **Type:** mecha part. "This will take up an ability slot and we need the equipment to be visible."
- **Steps:** "Ladder with slowdown".
- **Damage:** the slash hit only (bleed unchanged).
- **Speed:** the run only. "We only have the run option in this game rn."
- **Look:** B · Hook Blades. "Okay I like it let's do the hook claws. This looks great."
- **Effects:**
  - "Forget the camera shake."
  - The slash arc ring was rejected ("looks so sloppy") and replaced by blade-tip trails. "Okay I like it."

### Steps
| Step | Slash hit | Run |
|---|---|---|
| I | +10% | −5% |
| II | +20% | −10% |
| III | +30% | −15% |
| ★ | +50% | −25% |

Numbers on the Herrera (server rounding `floor(x + 0.5)`):
| Step | Slash 8 | With Razor Claws I (13) | Arena run 58.5 |
|---|---|---|---|
| I | 9 | 14 | 55.6 |
| II | 10 | 16 | 52.7 |
| III | 10 | 17 | 49.7 |
| ★ | 12 | 20 | 43.9 |

### How it works
- Takes a loadout slot (BUTTONS), like Mecha Legs and Blood Rush.
- No key of its own and no cooldown. It acts through the SLASH and is on only while slotted.
- Not slotted, or not bought: no look, no change.

### Look (B · Hook Blades)
- **Per arm**, welded to `Arm<L/R>_hand`, massless, no collision, colours no skin role uses:
  - a dark knuckle plate (0.72 × 0.24 × 0.60 at +0.15 Y);
  - a steel wrist band on `Arm<L/R>_fore` (0.50 × 0.26 × 0.48 at −0.52 Y);
  - a 4-piece iron sickle along the hand-local curve (+X = forward) (0.05, 0) → (0.75, 0.12) → (1.35, 0) → (1.75, −0.35) → (1.90, −0.80):
    - piece thickness 0.30 / 0.26 / 0.20 / 0.15, depth 0.13, steel;
    - a hot-orange Neon edge strip (0.07 thick, 0.15 deep) on the inner (lower) side of each piece.
- **Units:** sizes are at model scale 1 (HerreraModelData). The game model is ×2, so the builder multiplies by the model's scale.
- **Colours:**
  - STEEL rgb(154, 166, 184);
  - DARK rgb(93, 104, 120);
  - HOT rgb(255, 138, 42), Neon.

### Attack effects (only while slotted)
1. **Wind-up:** the iron flashes white for about 0.25 s at the slash start, and the AbilityBar tile flashes.
2. **Bigger rake:** the SlashPose ground swipe ×1.35 while slotted. The windup cocks the arms back, ArmL −55 / ArmR −35 pitch.
3. **Blade-tip trails:**
   - one Roblox `Trail` per blade, Attachment0 at the tip (1.90, −0.80) and Attachment1 at (1.78, −0.42);
   - Lifetime 0.11 s, colour HOT;
   - transparency 0.1 at the tip to 0.85 at the base, fading out;
   - enabled only during the windup / dash / recover.
4. **On a hit:**
   - 18 orange + 6 white spark bits;
   - hit-stop 0.09 s on the attacker's client;
   - the damage number bigger and yellow, with "CLANG!" under it.
   - **NO camera shake.**
5. **Footsteps from III:** heavier dust puffs while running.

### Build (re-ground every file before writing)
**SkillTree:**
- New path `ironclaw` "Iron Claw":
  - mech = true, soon = false;
  - area attack, `dino = "Herrera"`, OWNER Herrera;
  - LIVE_MECH and BUTTONS.
- Step texts are the four rows above.
- effects:
  - ironClawDamageMul 1.1 / 1.2 / 1.3 / 1.5;
  - ironClawSpeedMul 0.95 / 0.90 / 0.85 / 0.75;
  - ironClawDust (III+).
- Switch HERRERA_IRONCLAW.

**SkillEffects:** on a Herrera with `ironclaw` bought AND slotted, write these character attributes (off values otherwise):
- IronClawEnabled;
- IronClawDamageMul;
- IronClawSpeedMul;
- IronClawDust;
- IronClawLook.

**SlashServer:**
- Slash hit damage = (SlashDamage + bonus) × IronClawDamageMul, before the debuff multiplier.
- The bleed is unchanged.

**SprintTest:** run speed × IronClawSpeedMul while IronClawEnabled (MoveSpeedParts "ironclaw").

**IronClawServer (new):**
- Builds `Iron_Claw` while IronClawLook, removes it when IronClawLook goes false.
- Adds the two Trail attachments per blade.
- BindableFunction `BuildPreview_ironclaw` for the Lab card (LabPreviewServer pattern, like MechaLegsServer 1.1).

**IronClawFX (new client):**
- the wind-up flash;
- the trails on / off with the SlashLocalState / SlashStartedAt phases;
- sparks and "CLANG!" on SlashHitAt;
- the local hit-stop;
- the dust.

**IdleAnimation / SlashPose:**
- The ×1.35 rake and the arm wind-up while IronClawEnabled.
- Model attribute `IronClawPoseMul` (default 1.35).

**Lab:**
- The card shows the preview model.
- The step texts come from SkillTree.

**AbilityBar:** the slotted IRON CLAW tile (steel style, no cooldown), which flashes on each slash.

### Acceptance
- Herrera MECHA ABILITIES tab shows Iron Claw with a Lab card of the blades.
- Slotting it shows the hook blades on the dino; unslotting removes them.
- I–★ change the slash hit and run speed exactly as in the table; the bleed is unchanged.
- The trails show only during the slash.
- No camera shake.
- The T-Rex, Raptor and Pachy are unchanged.
- Tested on PC, gamepad and the phone layout before publish.

---

## Part 2 — Glider Wings (`glider`) · SPEED · Herrera only

### Decisions (Kepu 2026-10-31)
- Chosen from the mobility ideas.
- Steps: "Glide strike".
- Look: A · Bat Membranes.

### Steps
| Step | Effect |
|---|---|
| I | Glide: hold JUMP in the air, fall at 8 studs/s, keep your run speed forward. |
| II | SLASH while gliding = drop attack on anything below (55 studs). |
| III | Drop attack from a glide +30% damage. |
| ★ | The glide drop lands with a bleed burst: every dino within 10 studs bleeds. This uses the Herrera's normal slash bleed (3/s, or 5/s with Razor Claws III). |

### How it works
- Takes a slot. There's no key of its own: it acts through JUMP, like Mecha Legs.
- No cooldown.
- Gliding:
  - Starts when JUMP is held while airborne and falling: after any leap, a tree hop, or stepping off a ledge.
  - Ends on landing, on a grab onto a trunk (ClimbTest), or when JUMP is released.
  - While gliding, the vertical speed is clamped to −8 studs/s, and the horizontal speed is held at the run speed (after Iron Claw / Frenzy multipliers) in the facing direction, steerable by the stick.
- II:
  - SlashServer accepts kind "dive" while the character attribute `Gliding` is true, the same as on a tree.
  - The target rules are unchanged: below you, within SlashDiveRange (Tree Stalker raises it).
  - Only drop attacks get the glide bonus; the ground slash doesn't.
- III: the dive hit × 1.3 when it started from a glide.
- ★: on a glide-dive hit, apply the slash bleed to every Bitable model within 10 studs (× scale) of the landing point, the hit target included.

### Look (A · Bat Membranes)
- Welded to `Torso_chest`, both sides (chest local Z = side), massless, no collision:
  - three membrane panels (chord 1.9 / 1.6 / 1.15, span 1.3 / 2.4 / 3.6 from 0.62 out), canvas colour, transparency 0.1;
  - a steel leading-edge spar (3.8 long);
  - three dark finger rods fanned at −25° / −50° / −75° (3.4 / 2.6 / 1.7 long);
  - a hot-orange Neon shoulder hub;
  - a steel rod along each forearm.
- **Folded:** span scaled to 5% from the body edge (a thin strip at the chest sides).
- **Opening:** opens in 0.2 s when the glide starts and folds in 0.25 s on landing.
- **Glide pose:** arms out (roll −55 on the left / +55 on the right, pitch +20), legs trailing (pitch −45), tail straightened (×0.2 of the scurry tail), body pitch +14.

### Acceptance
- Hold JUMP after a leap or tree hop → the wings open and you glide at a fall of 8 studs/s.
- Release JUMP or land → the wings fold.
- II: SLASH while gliding does a drop attack on a target below within range.
- III: that drop attack does +30%.
- ★: it also makes every dino within 10 studs bleed.
- No effect when not slotted.

---

## Part 3 — Quill Launcher (`quills`) · ATTACK · Herrera only

### Decisions (Kepu 2026-10-31)
- Volley.
- "No bleed we'll just increase the quill count. Have it have a long cooldown."
- Look: B · Spine Quills.

### Steps
| Step | Effect |
|---|---|
| I | Fire 5 quills at your target, 4 damage each (40 studs). |
| II | 8 quills. |
| III | 12 quills. |
| ★ | 17 quills. |

### How it works
- Takes a slot and fires on its slot key.
- Cooldown 20 s.
- Target:
  - the Bitable model closest to your aim within a 40-stud × scale cone of 35° in front of you (the same target pick as the slash dive);
  - without a target, the quills fly straight ahead 40 studs.
- Firing:
  - quills leave the 7 spine tubes in turn, one every 0.045 s;
  - each flies on a slight arc at 45 studs/s (model ×2 → 90 studs/s in game);
  - each hit does 4 damage (DummyHealth).
- Hits are server-checked: the server fixes the target and the count at the request, and applies the damage at the computed flight time.
- No bleed, no slow.

### Look (B · Spine Quills)
- The 7 `Torso_quill1..7` parts are hidden and replaced, each welded to its quill:
  - a steel tube (width ×1.9, length ×1.15);
  - a hot-orange Neon tip;
  - a dark collar.
- Fired quills are steel shafts (1.3 long) with a hot-orange tip and dark fletching.

### Feel (arcade)
- A small recoil nod per quill.
- A white number "4" per hit.
- A big yellow total with "N QUILLS × 4" once all have landed.
- The slot tile shows the 20 s cooldown sweep.

### Acceptance
- Pressing the slot key fires 5 / 8 / 12 / 17 quills for I–★, at 4 damage each, up to 40 studs.
- Then a 20 s cooldown.
- No bleed.
- The spine quills are steel with glowing tips only while slotted.

---

## Part 4 — Smoke Pods (`smoke`) · TRICKSTER · Herrera only

### Decisions (Kepu 2026-10-31)
- Vanish cloud.
- Look: B · Tail Vents.

### Steps
| Step | Effect |
|---|---|
| I | Smoke cloud (12 studs) for 4 s: inside it your name and health bar are hidden, and bots lose you. |
| II | The cloud lasts 6 s. |
| III | Run 25% faster inside the smoke. |
| ★ | Enemies inside the smoke are slowed 25%. |

### How it works
- Takes a slot and fires on its slot key.
- Cooldown 18 s.
- The cloud stays where it was dropped, as a 12-stud × scale radius sphere around the drop point.
- **While you're inside:**
  - your BillboardGuis are hidden for other players (the TreeTopHide pattern);
  - bots targeting you drop their target (BotHunt's target is cleared, with a "?" pop) and go back to wandering;
  - they can't pick you as a target until you leave the cloud.
- **III:** run speed × 1.25 while you're inside (SprintTest, MoveSpeedParts "smoke").
- **★:** any other character or bot inside gets a 25% slow while inside (the SprintTest pattern for players, the bot's walk speed for bots).
- **Visual:** about 70 round cartoon puffs (white / light grey Ball parts, 0.8–2.1 radius × scale) that pop out from the vents in 0.35 s, wobble gently, and fade over 0.6 s at the end. A "POOF!" pop.

### Look (B · Tail Vents)
- Welded to `Tail1_main`:
  - a dark vent block (0.70 × 0.62 × 0.62);
  - a hot-orange Neon intake ring;
  - 3 steel nozzles angled back 25°.
- The smoke bursts out of the nozzles.

### Acceptance
- The slot key drops a 12-stud cloud for 4 s (6 s from II).
- Inside it: your name and bar are hidden and bots lose you.
- III: +25% run inside.
- ★: enemies inside are slowed 25%.
- 18 s cooldown.
- The tail vents show only while slotted.

---

## Part 5 — Back Plating (`plating`) · DEFENSE · Herrera only

### Decisions (Kepu 2026-10-31)
- Rear guard with "Max -30% damage".
- Look: A · Spine Scutes.
- The step numbers and "from behind only, front unchanged" were stated in the pick question.

### Steps
| Step | Damage from behind |
|---|---|
| I | −10% |
| II | −15% |
| III | −22% |
| ★ | −30% |

The front is always unchanged.

### How it works
- Takes a slot. Always on while slotted, no key.
- **"From behind":** the attacker's root is in the back half-space of the Herrera, i.e. the dot product of the Herrera's look vector with (attacker − Herrera) is < 0.
- **Applied:** in the Herrera's incoming-damage path, alongside Thick Hide / Wiry Frame. Re-ground which scripts apply bite / slash / headbutt damage to a player dino (ArenaPvP / DummyHealth bridge) before choosing the hook.
- **Feel:**
  - a plated hit makes orange-white sparks off the plates;
  - the plates flash white for 0.25 s;
  - the number shows the struck-through original and the reduced value, with "−N% PLATED".

### Look (A · Spine Scutes)
- The back quills `Torso_quill1..7` are hidden.
- 6 overlapping steel plates (tilted −6°) on `Torso_hips`, `Torso_waist`, `Torso_chest`, `Torso_hump`, `Tail1_main` and `Tail2_main`, each with:
  - a dark rim;
  - 2 bright rivets.

### Acceptance
- Hits from behind are −10 / −15 / −22 / −30% for I–★; hits from the front are unchanged.
- Sparks and the plated number on reduced hits.
- The plates show only while slotted.

---

## Build order (one or two passes)
**Pass 1 (shared plumbing + the simpler parts):**
1. SkillTree paths `ironclaw`, `glider`, `quills`, `smoke`, `plating` (Herrera, mech, LIVE_MECH, BUTTONS), their step texts and effects.
2. SkillEffects writes for the five parts.
3. The visuals: a server script per part, or one `HerreraPartsServer` with a part table (preferred: one script, one switch per part), building each look plus `BuildPreview_<id>` for the Lab card.
4. Iron Claw (SlashServer multiplier, SprintTest, FX).
5. Back Plating (damage hook).

**Pass 2 (new behaviour):**
1. Glider (JumpTest / ClimbTest glide state, SlashServer dive while gliding, bleed burst).
2. Quill Launcher (remote + server flight / damage + client FX).
3. Smoke Pods (cloud server object, hide, BotHunt target drop, slows).

**AbilityBar / ArenaTouch:** slot tiles for the keyed parts (quills, smoke). Check the phone layout through ArenaTouch's styled table (the 2026-10-31 lesson).

