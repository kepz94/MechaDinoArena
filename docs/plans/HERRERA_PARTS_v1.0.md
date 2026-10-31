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
| 1 | Iron Claw (Hook Blades) MDA-149 | done (below) | docs/mockups/herrera_ironclaw_options.html, look B; video docs/reference/herrera/mockup_ironclaw_B.mp4 | pass 1 (Studio 2026-10-31) |
| 2 | Glider Wings (Bat Membranes) MDA-150 | done (below) | docs/mockups/herrera_parts_b1_options.html, look A; video docs/reference/herrera/mockup_parts_b1_glider.mp4 | look + Lab card (pass 1); move pass 2 (Studio 2026-10-31) |
| 3 | Quill Launcher (Spine Quills) MDA-151 | done (below) | same page, look B; video mockup_parts_b1_quills.mp4 | look + Lab card (pass 1); move pass 2 (Studio 2026-10-31) |
| 4 | Smoke Pods (Tail Vents) MDA-152 | done (below) | same page, look B; video mockup_parts_b1_smoke.mp4 | look + Lab card (pass 1); move pass 2 (Studio 2026-10-31) |
| 5 | Back Plating (Spine Scutes) MDA-153 | done (below) | same page, look A; video mockup_parts_b1_plating.mp4 | pass 1 (Studio 2026-10-31) |
| 6 | Blood Siphon (Throat Pump) MDA-154 | done (below) | docs/mockups/herrera_parts_b2_options.html, look A; video docs/reference/herrera/mockup_parts_b2_siphon.mp4 | pass 1 (Studio 2026-10-31) |
| 7 | Strobe Frill (LED Frill) MDA-155 | done (below) | same page, look A; video mockup_parts_b2_strobe.mp4 | look + Lab card (pass 1); move pass 2 (Studio 2026-10-31) |
| 8 | Stun Breaker (Back Capacitor) MDA-156 | done (below) | same page, look B; video mockup_parts_b2_breaker.mp4 | look + Lab card (pass 1); move pass 2 (Studio 2026-10-31) |

The Herrera ends with 8 parts, like the Raptor and Pachy.

- Batch 1 (parts 2–5): picked from 16 ideas.
- Batch 2 (parts 6–8): picked to fill the gaps Kepu asked about ("where are we lacking rn?"):
  - Health: no healing part yet.
  - A second Utility part.
  - A way out of a stun.
- Areas: attack 2, speed 1, utility 2, defense 2, health 1.
- Mockup sources for batch 2: tools/mockup/p2_*.js, built by build3.py.

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

## Part 6 — Blood Siphon (`siphon`) · HEALTH · Herrera only

### Decisions (Kepu 2026-10-31)
- Health gap: Blood Siphon.
- Look: A · Throat Pump.

### Steps
| Step | Effect |
|---|---|
| I | Heal 1 HP/s for each bleeding enemy within 15 studs. |
| II | 1.5 HP/s each. |
| III | Range 25 studs. |
| ★ | A bleed kill near you (within the range) heals 25% of your max health. |

### How it works
- Takes a slot. Always on while slotted, no key.
- **What counts as a bleeding enemy:**
  - another character or bot with SlashBleedUntil > now, or SkillBleedUntil > now (any attacker's bleed);
  - its root within the range × scale of yours.
- **Ticks:** every 1 s, through SkillEffects' `heal(char, st, amount, "siphon")`. Overheal becomes the Blood Drinker ★ shield when that's bought.
- **★:** on KilledWith "bleed" (any attacker) within range, heal 25% of max health once per kill.
- **Visual:** while healing, red beads (Neon cubes, 0.3 × scale) fly on an arc from each bleeding enemy's chest to the tank, about 8 per second per enemy. The tank core pulses (scale +25%) on each tick.
- **Feel:** a green "+1" / "+1.5" pop per tick per enemy, and a big "+N BLEED KILL · 25%" on ★.

### Look (A · Throat Pump)
- A glass tank under the neck, just behind the frill (`Neck_main`), visible from the side:
  - a glass box 1.15 × 0.85 × 0.95 at −0.62 Y, Glass, transparency 0.65;
  - a glowing red core 0.88 × 0.6 × 0.7, Neon rgb(208, 32, 42);
  - 2 steel bands;
  - 2 dark side clamps.
- A steel band on the red throat sac (`Neck_sac`) and a red Neon pipe under `Neck_lower`.

### Acceptance
- Near bleeding enemies you heal 1 / 1.5 HP/s each, within 15 studs (25 from III).
- ★: a bleed kill in range heals 25% of max health.
- The beads and the tank pulse show; the tank shows only while slotted.

---

## Part 7 — Strobe Frill (`strobe`) · UTILITY · Herrera only

### Decisions (Kepu 2026-10-31)
- Utility gap: Strobe Frill.
- Look: A · LED Frill.

### Steps
| Step | Effect |
|---|---|
| I | Frill flash in a 60° cone, 20 studs: enemies are dazed (can't attack) for 1 s. |
| II | Daze 1.5 s. |
| III | Cone 90°, 25 studs. |
| ★ | Dazed enemies take +20% damage while dazed. |

### How it works
- Takes a slot and fires on its slot key.
- Cooldown 16 s.
- **Flash:** a 0.15 s rear-up (body +18°, neck +18°, jaw open), then the flash. Server-checked, from the server's root position and facing.
- **Who is hit:** every enemy character or bot whose root is within range × scale and inside the half-angle (30°, or 45° from III) of the facing.
- **Daze:** sets `DazedUntil = now + daze` on the target.
  - The attack / ability servers refuse requests while DazedUntil > now (result "dazed"): BiteServer, PounceServer, SlashServer, HeadbuttServer, the mech parts. Re-ground each one.
  - Bots skip attacks while dazed.
- **★:** damage taken while DazedUntil > now is × 1.2 (the same multiplier spot as the roar debuff).
- **Visual:**
  - the frill strips strobe white about 5 times in 0.35 s;
  - a white flare sphere at the head (0.3 s);
  - 13 light rays across the cone (0.4 s);
  - "FLASH!" pop.
- **On the dazed:** 4 yellow stars spin over the head for the daze, with a "DAZED N s" pop.

### Look (A · LED Frill)
- On each of the 11 frill spines (`Head_frill1..11`): a light strip on both faces (0.05 × 0.62 × 0.16, Neon rgb(255, 231, 176)).
- On each rim (`Head_frillrim1..11`): a hot-orange Neon lamp.
- A steel collar on `Neck_main`.
- The strips go white during the flash.

### Acceptance
- The slot key flashes a 60° / 20-stud cone (90° / 25 from III).
- Enemies in it can't attack for 1 s (1.5 from II), with stars over their heads.
- ★: +20% damage taken while dazed.
- 16 s cooldown.
- The LEDs show only while slotted.

---

## Part 8 — Stun Breaker (`breaker`) · DEFENSE · Herrera only

### Decisions (Kepu 2026-10-31)
- Escape gap: Stun Breaker.
- Look: B · Back Capacitor.

### Steps
| Step | Effect |
|---|---|
| I | Break out of a stun / pin. |
| II | Pushes nearby enemies back 10 studs. |
| III | Cooldown 14 s. |
| ★ | 1 s of no damage after breaking out. |

### How it works
- Takes a slot and fires on its slot key.
- Cooldown 20 s (14 s from III).
- **When it can be used:** only while StunnedUntil > now or PinHeld is true. Otherwise the request is refused ("notStunned") and the tile shows dimmed.
- **I:** clears the stun / pin on the server (StunnedUntil = now; PinHeld released through the pin owner's script; re-ground the pounce / tether pin owners).
- **II:** every enemy within 10 studs × scale is pushed 10 studs × scale away from you over about 0.3 s (the knockback pattern of HeadbuttServer / VisorServer).
- **★:** `StunBreakImmuneUntil = now + 1`. Incoming damage is 0 until then (the same hook as Back Plating). Your dino blinks white.
- **Visual:**
  - "BREAK!" pop;
  - 10 zig-zag electric bolts (cyan / white Neon segments, 0.2 s) arc out of the two coil tips;
  - the capacitor band flashes;
  - your stun stars vanish.

### Look (B · Back Capacitor)
- On `Torso_hump`:
  - a dark capacitor box 0.95 × 0.6 × 0.85 with a cyan Neon band rgb(127, 233, 255);
  - two steel coil prongs (1.1 tall, ±0.25 apart), each with 3 hot-orange coil rings and a cyan Neon tip.

### Acceptance
- While stunned or pinned, the slot key breaks you out (refused when you're not stunned).
- II: pushes enemies within 10 studs back 10 studs.
- III: cooldown 14 s.
- ★: 1 s of no damage, with the white blink.
- Bolts show from the coil prongs.
- The capacitor shows only while slotted.

---

## Build order (one or two passes)
**Pass 1 (shared plumbing + the simpler parts):**
1. SkillTree paths `ironclaw`, `glider`, `quills`, `smoke`, `plating`, `siphon`, `strobe`, `breaker` (Herrera, mech, LIVE_MECH, BUTTONS), their step texts and effects.
2. SkillEffects writes for the eight parts. Blood Siphon goes in pass 1: a SkillEffects tick plus the beads FX.
3. The visuals: a server script per part, or one `HerreraPartsServer` with a part table (preferred: one script, one switch per part), building each look plus `BuildPreview_<id>` for the Lab card.
4. Iron Claw (SlashServer multiplier, SprintTest, FX).
5. Back Plating (damage hook, shared with Stun Breaker ★ immunity).
6. Blood Siphon.

**Pass 2 (new behaviour):**
1. Glider (JumpTest / ClimbTest glide state, SlashServer dive while gliding, bleed burst).
2. Quill Launcher (remote + server flight / damage + client FX).
3. Smoke Pods (cloud server object, hide, BotHunt target drop, slows).
4. Strobe Frill (DazedUntil + attack servers refuse while dazed; ★ damage multiplier).
5. Stun Breaker (break the stun / pin, push, ★ immunity).

**AbilityBar / ArenaTouch:** slot tiles for the keyed parts (quills, smoke, strobe, breaker; the breaker tile is dimmed unless you're stunned). Check the phone layout through ArenaTouch's styled table (the 2026-10-31 lesson).


---

## Pass 2 — build map (2026-10-31, after Kepu's "Okay next")

### New scripts
| Script | Place | Version | Switch | Job |
|---|---|---|---|---|
| HerreraMovesServer | ServerScriptService | 1.0 | HerreraMovesServerEnabled, HerreraMoves_<id>Enabled | remotes DinoQuillRequest, DinoSmokeRequest, DinoStrobeRequest, DinoBreakerRequest, DinoGlideRequest; checks, targets, damage, daze, clouds, push, immunity |
| HerreraMovesFX | StarterPlayerScripts | 1.0 | HerreraMovesFXEnabled | every client: quill flights + numbers, smoke puffs, strobe flash / rays, daze stars, breaker bolts / blink, "?" pops |
| GliderTest | StarterCharacterScripts | 1.0 | GliderTestEnabled | owner client: glide while JUMP is held in the air (fall clamp, forward hold), tells the server |
| IdleAnimation/HerreraMovesPose | module | 1.0 | model GlidePoseEnabled / StrobePoseEnabled | glide pose (full pose) and the strobe rear-up (offsets) |

### Extended scripts (each change behind its own switch)
| Script | Version | Change |
|---|---|---|
| SlashServer | 1.5 | "dazed" refusal; damage × DazedDamageMul while dazed, 0 while StunBreakImmuneUntil; dive accepted while Gliding + GliderDrop; glide dive × GliderDropMul; ★ bleed burst within GliderBurst studs |
| SlashTest | 1.4 | kind "dive" while GlideLocal + GliderDrop |
| BiteServer 1.9, PounceServer 1.12, HeadbuttServer 1.11, RamServer 1.2, HookServer 1.7, InkServer 1.5, MineServer 1.7, TetherServer 1.2, ScreechServer 1.10 | | "dazed" refusal (DazedUntil > now); Headbutt / Hook also the damage-taken multiplier |
| BoneCrest | 1.4 | factor(): 0 while StunBreakImmuneUntil; × DazedDamageMul while dazed (covers bites, pounces, bot hits) |
| BotServer | 1.22 | a dazed bot starts no bite / pounce / headbutt; SmokeHidden players are dropped at once and not picked |
| SprintTest | 1.15 | × SmokeRunMul while SmokeRunUntil; × SmokeSlowMul while SmokeSlowUntil |
| TreeTopHide | 1.1 | also hides the BillboardGuis of a player with SmokeHidden |
| MechaButtons | 1.24 | TIMED_PARTS quills / smoke / strobe / breaker; quills fire with the camera look; breaker ready only while stunned / pinned |
| AbilityBar | 1.18 | same tiles; breaker "waiting" unless stunned / pinned |
| IdleAnimation | 1.36 | glide pose (lerped in over 0.2 s, out over 0.25 s) after the leap layer; strobe rear-up on top |
| HerreraPartsServer | 1.2 | glider wings open while Gliding |
| SkillTree | 1.40 | HERRERA_PASS2_SOON = false (the five parts go live) |

### Re-grounded scope of "can't attack" (daze)
- Refused while dazed: bite, pounce, slash, headbutt, ram, Grappling Hook, Ink Shooter, Shock Mine, Tether Spike, Shock Cannon, Quill Launcher, Strobe Frill.
- Not refused (not attacks): moving, leap, climb, Thrusters, Cloak, Energy Shield, Dome Visor, Adrenaline, Servo Dash, Med-Station, Scent, Smoke Pods, Stun Breaker, roar.

### Deterministic map
| State | Condition | Result |
|---|---|---|
| Quill request | badArg / dead / disabled / menu / stunned / pinned / dazed / cooldown | refused (QuillServerResult) |
| Quill volley | ok, target in 35° flat cone within QuillRange × scale, line of sight | QuillCount quills at it; else straight ahead QuillRange × scale ("miss") |
| Quill hit | arrives, target alive, no Energy Shield | QuillDamage × roar debuff × daze ★ × immunity off DummyHealth; kill → KilledWith "quills" |
| Smoke request | badArg / dead / disabled / menu / stunned / pinned / cooldown | refused |
| Smoke cloud | ok | centre = root, radius SmokeRadius × scale, until now + SmokeTime |
| Owner inside | root within radius | SmokeHidden true; SmokeRunUntil = cloud end (III) |
| Owner outside / cloud over | | SmokeHidden false, SmokeRunUntil 0 |
| Enemy inside (★) | SmokeSlowMul < 1, player allowed by ModeRules or a bot | player SmokeSlowUntil / SmokeSlowMul; bot WalkSpeed × mul |
| Strobe request | badArg / dead / disabled / menu / stunned / pinned / dazed / cooldown | refused |
| Strobe flash | ok, 0.15 s later | every allowed enemy root within StrobeRange × scale and StrobeAngle / 2 of the facing (flat): DazedUntil = max(old, now + StrobeDaze), DazedDamageMul = StrobeDazedMul; Energy Shield = skipped |
| Breaker request | badArg / dead / disabled / menu / notStunned (not stunned and not PinHeld) / cooldown | refused |
| Breaker ok | | StunnedUntil = now; a pinner gets ShakeOffReason "breaker" + ShakeOffAt (PounceServer releases); II push enemies within BreakerPush × scale; ★ StunBreakImmuneUntil = now + BreakerImmune |
| Glide (client) | GliderEnabled, JUMP held, airborne, falling, not on a tree, not slashing / stunned / pinned | GlideLocal true, vertical speed ≥ −GliderFall, forward held at the run speed when no stick input; server Gliding true |
| Glide ends | land / grab a trunk / release JUMP / slash dash / part off | GlideLocal false, server Gliding false |
| Slash "dive" request | not on a tree, Gliding and GliderDrop | accepted (was "noTree"); SlashGlideDive true |
| Glide dive hit | | × GliderDropMul; ★ every Bitable model within GliderBurst × scale of the landing point bleeds (the slash bleed) |

---

## Pass 3 — parts 9–11 (Kepu 2026-10-31: "Let's plan 3 abilities right now")

**Intent:** three more Herrera button parts: a bleed trap, "a blob shooter that slows a wide area of the field" and "an adrenaline that works like raptors".
**Mockup:** docs/mockups/herrera_parts_b3_options.html (sources tools/mockup/p3_parts.js, p3_scen.js, build4.py); videos docs/reference/herrera/mockup_parts_b3_caltrops.mp4, _blob.mp4, _adrenaline.mp4.
**Picks (Kepu 2026-10-31):** Caltrops ladder "Bleed trap", look A · Tail Spreader. Blob ladder "Two blobs", "Lobbed arc", cooldown 14 s, look A · Hump Mortar. Adrenaline "Same, but ★ refills slash charges", look A · Back Tanks.
**After pass 3:** the Herrera has 11 parts (8 button parts; siphon / ironclaw / plating are passive).

### Status
| # | Part | Path id | Area | Ticket | Built |
|---|---|---|---|---|---|
| 9 | Razor Caltrops (Tail Spreader) | `caltrops` | eng (UTILITY) | MDA-165 | no |
| 10 | Goo Blob Shooter (Hump Mortar) | `goo` | eng (UTILITY) | MDA-166 | no |
| 11 | Adrenaline Injector (Back Tanks) | `hadren` | health | MDA-167 | no |

## Part 9 — Razor Caltrops (`caltrops`)
### Steps
| Step | Effect |
|---|---|
| I | Button: drop 6 razor spikes in a 10-stud patch behind you, for 8 s. An enemy that steps on one bleeds 3/s for 3 s and is slowed 30% for 1 s. Recharges in 16 s. |
| II | 10 spikes, 14-stud patch. |
| III | Spikes last 14 s. |
| ★ | Enemies can't see the spikes (only you and your squad). |
### How it works
- Request `DinoCaltropRequest(stamp)`; HerreraMovesServer `check(..., "caltrops", "Caltrop", {})` (refused: badArg / dead / disabled / menu / stunned / pinned / cooldown; not "dazed": a trap is not an attack — same row as Smoke Pods).
- Patch centre = root − facing(flat) × (CaltropRadius + 4) × scale; spikes at sunflower spots (i × 137.5°, r × √((i+0.5)/n)) dropped onto the ground (ray down, the TetherServer 1.1 skip list). A new patch replaces the owner's old one.
- Server data, client drawn: Folder `ReplicatedStorage.CaltropPatches`, one Configuration per patch (`Owner` name, `OwnerUserId`, `Until`, `Hidden` (★), `Scale`, `Spikes` = JSON array of {x,y,z,used}). HerreraMovesFX 1.3 draws each spike (3 crossed steel bars + red Neon tips, scale-1 size 0.2 × 1.1 × 0.2) — for every viewer when Hidden is false; when Hidden is true only for the owner (and squadmates once Squads ships: SquadRules.same).
- Trigger: every 0.1 s, for every allowed enemy (`candidates(self)`) whose root is within 1.6 × scale studs (flat) of an unused spike: spike used (removed), target `CaltropBleedUntil = now + 3`, `CaltropBleedBy`, `CaltropSlowUntil = now + 1`, `CaltropSlowMul = 0.7`; one trigger per target per 0.35 s. Energy Shield (EnergyShieldUntil) = no trigger, spike kept.
- Bleed ticks every 1 s while CaltropBleedUntil ≥ now: 3 off DummyHealth through `takeHealth` (× takenMul: daze ★, immunity), KilledWith "caltrops". A new spike restarts the 3 s.
- Slow: players → SprintTest 1.16 × CaltropSlowMul while CaltropSlowUntil > now; bots → WalkSpeed × 0.7 while slowed (the Smoke ★ bot pattern).
- Blood Siphon counts CaltropBleedUntil as "bleeding" (SkillEffects 1.29).
### Look (A · Tail Spreader)
- On `Tail1_main`: dark hopper 0.85 × 0.5 × 0.6 at (0, 0.42, 0); 2 steel bands 0.08 × 0.54 × 0.64 at x ±0.3; 5 spike tips (steel 0.09 × 0.26 × 0.09 + blood Neon 0.07 × 0.1 × 0.07 on top) along the top at z ±0.12, fanned ±24°; steel rear chute 0.3 × 0.26 × 0.5 at (0.52, 0.32, 0), tilted −20°.
- On use: the hopper rattles 0.5 s (HerreraMovesFX), spikes arc out of the chute (0.4–0.56 s each, staggered 0.04 s).
### Acceptance
- Slot key drops 6 spikes in a 10-stud patch behind (10 / 14 from II), lasting 8 s (14 from III); 16 s cooldown.
- An enemy stepping on one: −3 at once and every second for 3 s, 30% slower for 1 s; the spike is gone.
- ★: other players never see the spikes; you do.
- Bots step on them and slow; a shielded enemy doesn't trigger them.

## Part 10 — Goo Blob Shooter (`goo`)
### Steps
| Step | Effect |
|---|---|
| I | Button: toss a goo blob 30 studs ahead (straight down while gliding). It splats into a 16-stud goo puddle for 5 s; enemies in the goo are slowed 40%. Recharges in 14 s. |
| II | Puddle 22 studs wide. |
| III | Fires 2 blobs side by side. |
| ★ | Puddles last 8 s. |
### How it works
- Aim (Kepu 2026-10-31 15:49, replaces the tether-style aim and its red-team copy: "Have the blobs just toss from a set distance and be dropped immediately under you when gliding as herrera"; picked 30 studs): no aim mode. A tap fires at once. The landing point is the root + facing (flat) × GooToss (30) × scale, dropped onto the ground. While Gliding is true, the landing point is the ground straight under the root (the blob falls straight down). MechaButtons sends `DinoGooRequest(stamp)`; the server works out the point itself.
- Request `DinoGooRequest(stamp)`; `check(..., "goo", "Goo", {})` (not refused by daze — area denial, like smoke).
- III: two landing points = the landing point ± right(flat, perpendicular to the facing) × GooRadius × 0.85 × scale.
- Flight 0.85 s (0.12 s stagger for the 2nd), apex 14 studs above the higher end, from the mortar muzzle; server part "GooBlob" (anchored, no collide / query / touch) in Workspace.DinoFX.GooFX.
- Puddle: Part "GooPuddle" (Cylinder, lime Neon rgb(166, 226, 46) at 0.25 transparency, height 0.2, anchored, no collide / query / touch) + darker rim, for GooTime (5; 8 at ★).
- Slow: every 0.2 s each allowed enemy whose root is within GooRadius × scale (flat) of a live puddle: player `GooSlowUntil = now + 0.3`, `GooSlowMul = 0.6` (SprintTest 1.16); bot WalkSpeed × 0.6 while inside, put back on leaving / puddle end. No damage.
### Look (A · Hump Mortar)
- On `Torso_hump`: dark base plate 0.9 × 0.12 × 0.8 at (0, 0.32, 0); steel tube 0.5 × 1.0 × 0.5 at (0.22, 0.85, 0) tilted −32° (forward); lime Neon muzzle ring 0.58 × 0.14 × 0.58 at (0.48, 1.27, 0) same tilt; glass tank 0.6 × 0.55 × 0.6 at (−0.42, 0.62, 0) with a lime Neon core 0.42 × 0.4 × 0.42 (level drains on fire, refills over the cooldown); 2 steel bands.
- On fire: the tube kicks back 0.25 along its axis (0.35 s), body pitch −7° (HerreraMovesPose 1.1 `gooKick`), "THUMP!" pop.
### Acceptance
- Tap → aim circle; tap → blob arcs and splats a 16-stud puddle (22 from II) where the circle was; 14 s cooldown.
- Enemies (bots and Arena players) inside run 40% slower; outside, normal.
- III: two puddles side by side. ★: 8 s puddles.

## Part 11 — Adrenaline Injector (`hadren`)
### Steps
| Step | Effect |
|---|---|
| I | Button: heal 25% of max health over 3 s and run 1.4x faster while it lasts. Recharges in 20 s. |
| II | Heal 34%. |
| III | Recharges 26% faster (14.8 s). |
| ★ | Also refills every slash charge at once. |
### How it works
- Re-uses AdrenalineServer 1.4 unchanged in its maths: SkillTree 1.43 `effects()` sets the same keys (adrenHeal, adrenTime, adrenSpeedMul, adrenCooldown) from `s.hadren` on a Herrera, plus `adrenSlashRefill` at ★ (adrenStunClear stays false). SkillEffects 1.29 writes the Adrenaline* attributes when `hadren` is in a slot on a Herrera (the raptor `inSlot("adrenaline")` row is unchanged) plus `AdrenalineSlashRefill`.
- ★: AdrenalineServer 1.5 on "ok" with AdrenalineSlashRefill → character `SlashRefillAllAt = now`; SlashServer 1.6 listens and sets charges to SlashChargesMax (the Blood Frenzy ★ refill code path), SlashSkillLast "adrenRefill".
- Cooldown from the end of the boost (AdrenalineServer as is). MechaButtons / AbilityBar: TIMED_PARTS.hadren = {"Adrenaline", "DinoAdrenalineRequest", "ADRENALINE"}.
- AdrenalineServer 1.5 builds no raptor look on a Species "Herrera" (switch AdrenalineHerreraLookOff, default true); HerreraPartsServer 1.3 builds the Back Tanks.
### Look (A · Back Tanks)
- On `Torso_hump`, two tanks at z ±0.27: glass 0.34 × 0.85 × 0.34 at (−0.1, 0.72, z); green Neon fluid rgb(70, 224, 138) 0.24 × 0.7 × 0.24 at (−0.1, 0.66, z) whose height follows AdrenalineServer's fluid rule (drains over the boost, refills over the cooldown; bottom fixed); steel caps 0.38 × 0.1 × 0.38 at y 1.17 and 0.28; a green Neon feed tube 0.9 × 0.1 × 0.1 at (0.45, 1.0, 0) tilted −25°.
- During the boost: green Highlight pulse (AdrenalineServer's AdrenalineGlow), foot trails, "+N" pops — all existing.
### Acceptance
- Slot key: +25% of max health over 3 s (34% from II), 1.4x run while it lasts; cooldown 20 s (14.8 from III) counted from the end.
- ★: both slash pips refill at once.
- The raptor's Adrenaline Injector is unchanged (regression check on a raptor).

## Pass 3 — build map
| Script | Version | Change | Switch |
|---|---|---|---|
| SkillTree | 1.43 | `part("caltrops"…)`, `part("goo"…)`, `part("hadren"…)` (Herrera, LIVE_MECH, BUTTONS) + step texts above; effects wrapper: caltropCount 6/10, caltropRadius 5/7 (studs, half the patch), caltropTime 8/14, caltropHidden ★, caltropBleedDps 3, caltropBleedTime 3, caltropSlowMul 0.7, caltropSlowTime 1, caltropCooldown 16; gooToss 30, gooRadius 8/11, gooTime 5/8, gooCount 1/2 (III), gooSlowMul 0.6, gooCooldown 14; hadren → adren keys + adrenSlashRefill | SkillTree.HERRERA_PASS3 |
| SkillEffects | 1.29 | Herrera rows Caltrop* / Goo* (prefix loop as 1.27); Adrenaline* from hadren; siphon counts CaltropBleedUntil | SkillEffectsHerreraPass3Enabled |
| HerreraMovesServer | 1.1 | DinoCaltropRequest, DinoGooRequest; patches, triggers, bleed ticks, puddles, slows | HerreraMoves_caltropsEnabled, HerreraMoves_gooEnabled |
| HerreraMovesFX | 1.3 | spike drawing (Hidden rule), hopper rattle, spike arcs, goo flight drips, splat, puddle bubbles, "SLOWED" pops | HerreraMovesFXPass3Enabled |
| HerreraMovesPose | 1.1 | gooKick (body −7°, 0.35 s from GooFiredAt) | model GooPosePoseEnabled |
| HerreraPartsServer | 1.3 | looks HPart_caltrops / HPart_goo / HPart_hadren + BuildPreview_caltrops / _goo / _hadren; tank fluid level | HerreraParts_<id>Enabled |
| AdrenalineServer | 1.5 | no raptor look on a Herrera; ★ SlashRefillAllAt | AdrenalineHerreraLookOff, AdrenalineSlashRefillEnabled |
| SlashServer | 1.6 | SlashRefillAllAt → charges = max | SlashAdrenRefillEnabled |
| SprintTest | 1.16 | × CaltropSlowMul / × GooSlowMul while their Until > now | SprintTestPass3SlowEnabled |
| MechaButtons | 1.25 | TIMED_PARTS caltrops / goo / hadren (normal presses; no goo aim) | MechaButtonsHerreraPass3Enabled |
| AbilityBar | 1.19 | the same three tiles | AbilityBarHerreraPass3Enabled |

### Deterministic map
| State | Condition | Result |
|---|---|---|
| Caltrop request | badArg / dead / disabled / menu / stunned / pinned / cooldown | refused (CaltropServerResult) |
| Caltrop drop | ok | old patch removed; new patch CaltropCount spikes, Until = now + CaltropTime |
| Spike stepped | allowed enemy root within 1.6 × scale, unused, no shield, ≥ 0.35 s since its last trigger | used; bleed 3 s, slow 1 s |
| Spike, shielded enemy | EnergyShieldUntil > now | nothing, spike stays |
| Patch over | now ≥ Until, owner dead / left / part off | patch removed (bleeds already running finish) |
| Spike drawing | Hidden false | every client; Hidden true → owner (+ squad) only |
| Goo toss | tap while ready, not gliding | lands GooToss (30) × scale ahead |
| Goo drop | tap while Gliding | lands straight under you |
| Goo request | badArg / dead / disabled / menu / stunned / pinned / cooldown | refused (GooServerResult) |
| Goo fire | ok | GooCount blobs; puddle(s) at landing for GooTime |
| In goo | allowed enemy root within GooRadius × scale of a live puddle | player GooSlowUntil = now + 0.3, GooSlowMul 0.6; bot WalkSpeed × 0.6 |
| Out of goo / puddle ends | | player slow lapses ≤ 0.3 s; bot WalkSpeed restored |
| Adrenaline (Herrera) | AdrenalineServer rules as today | heal / run / cooldown; ★ SlashRefillAllAt → charges max |

### Pass 3 red-team synthesis (Kepu 2026-10-31)
- Tickets: H1 MDA-164 (SkillTree / SkillEffects), H2 MDA-165, H3 MDA-166, H4 MDA-167, H5 MDA-168 (Studio check).
- Build after Squads v1.0 ("Squads first").
- Goo aim: superseded by Kepu 15:49, fixed 30-stud toss / straight down while gliding. No aim code; the tether is untouched.
- Caltrops ★ "hidden": the spike data lives in ReplicatedStorage, so an exploiter could read it. Accepted risk (casual game; the same holds for any client-drawn FX).
- Herrera Adrenaline re-uses AdrenalineServer: a raptor regression check is part of the acceptance.
- New targets (caltrops, goo) go through `candidates` / `mayAffect`, so the squad check covers them.
