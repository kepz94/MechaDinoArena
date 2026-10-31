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
