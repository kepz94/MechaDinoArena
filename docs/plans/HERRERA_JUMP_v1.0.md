# Mecha Dino Arena v1.0 — Herrera jump (MDA-147)

**Goal:** the Herrera has a strong jump by default: Space on PC, the JUMP button on phone, no cooldown, hold to keep jumping, its own animation.
**Intent (Kepu 2026-10-31):**
- "have the Herrera have a jump button by default with its own jump animation".
- "most mobile yet fragile Dino so no cool down on jumps you can just hold the button and it will spam it".
- "a strong jump and it will be high for it's size since it climbs trees".
- "call it all jump".
**Chosen direction:** mockup `docs/mockups/herrera_jump_options.html`.
- Animation **C · Branch reach**.
- Height **18 studs**.
- **No stamina cost**.
- (Kepu 2026-10-31, AskUserQuestion.)
**Architecture:**
- The Herrera uses the shared leap (JumpTest / JumpServer), with its numbers set by a new server script, like TRexJump.
- A new pose module draws the branch-reach jump on the scurry rig. IdleAnimation uses it on scurry models instead of JumpPose.
- One small generic gate in JumpTest (JumpSuppressed) keeps the leap and the tree hop from both firing on one press.

## Global Constraints
- Additive, every change behind a switch. Hash-verified installs. Commit + push each step. Publish only on "publish".
- Versions:
  - New: HerreraJump 1.0, HerreraJumpPose 1.0.
  - Changed: JumpTest 1.3, ClimbTest 1.13, IdleAnimation 1.34, AbilityBar 1.17, ArenaTouch 1.8.
- Test on PC + the phone layout (ArenaTouchForceTouch) before publish (lesson 2026-10-31).

## Do-not-touch
- Raptor / pachy / T-Rex jump numbers and JumpPose 1.0.
- JumpServer.
- ClimbLogic.
- The slash.
- MechaButtons.
- SkillEffects (its cooldown base is set, not changed).

## Deterministic map
| State | Condition | Result |
|---|---|---|
| Herrera on the ground, JUMP pressed / held | JumpTestState ready, not on a tree | crouch 0.08 s → leap ~18 studs (JumpLaunchPower 75, tuned in Studio to 18 ± 1); re-leaps on landing while held (JumpCooldown 0, JumpStaminaCost 0) |
| Herrera on a trunk / tree top, JUMP | ClimbLocalState climbing / clinging / top | ClimbTest hop (unchanged); JumpTest refuses ("suppressed") |
| Herrera leaping, grabs a trunk (holding forward) | ClimbLocalState becomes climbing | JumpTest ends the leap at once (air hold off); the climb takes over; IdleAnimation drops the jump pose |
| Herrera hops off a tree | ClimbState tree → ground while airborne | the jump pose's air + landing phases play (no crouch) |
| Any other dino | JumpSuppressed never set | unchanged |
| Phone JUMP held | finger down on JUMP | Humanoid.Jump stays true (every dino: hold re-leaps on landing, like holding Space on PC); ClimbTest hops once per press (rising edge) |
| PC bar / phone JUMP on the Herrera | — | lit when JumpTestState ready or on a tree; active (white ring) while crouch / air |

## Tasks
1. **HerreraJump 1.0** (new ServerScriptService Script, Wired).
   - Species "Herrera" characters get JumpEnabled true, JumpWindup 0.08, JumpLaunchPower 75, JumpBoost 10, JumpBoostMinSpeed 2, JumpAirHold true, JumpStaminaCost 0.
   - JumpCooldown 0 and SkillBase_JumpCooldown 0 (SkillEffects writes base × multiplier; base 0 keeps it 0). These are written even where set: the model data has JumpEnabled false.
   - Switch HerreraJumpEnabled.
   - Diagnostics: HerreraJumpVersion / HerreraJumpApplied.
2. **JumpTest 1.3** (Wired). While JumpSuppressed is true:
   - A press is refused ("suppressed").
   - A crouch is cancelled.
   - A leap in the air ends at once (air hold off).
   - Switch JumpSuppressEnabled.
3. **ClimbTest 1.13** (Wired): JumpSuppressed = ClimbLocalState is climbing / clinging / top (written on change). Switch ClimbJumpSuppressEnabled.
4. **HerreraJumpPose 1.0** (new module under IdleAnimation, Wired; angles from the mockup's option C on ScurryPose.meanAngles).
   - crouch(c), air(a, vyN), land(u) return joint poses.
   - Crouch / land are ground-fitted (ScurryPose.fitted); air is not.
   - Tunable model attributes HJump*.
5. **IdleAnimation 1.34** (Wired). On GaitScurry models with HerreraJumpPoseEnabled ~= false, the leap layer uses HerreraJumpPose. The jump also ends while ClimbState is climbing / clinging / top, and a tree → ground change while airborne starts a jump at the air phase.
6. **AbilityBar 1.17** (Wired): the Herrera's JUMP tile is ready when JumpTestState is ready or on a tree, and active during crouch / air. Switch AbilityBarHerreraJumpEnabled.
7. **ArenaTouch 1.8** (Wired): holding JUMP keeps Humanoid.Jump true until the finger lifts (a tap still lasts at least LEAP_HOLD). Switch ArenaTouchJumpHoldEnabled.
8. **Studio check**:
   - Height measured (JumpPeakHeight 18 ± 1; tune JumpLaunchPower).
   - Hold = repeated jumps.
   - Mid-air grab.
   - Tree hop pose.
   - Raptor / pachy / T-Rex unchanged.
   - Forced-touch layout.

## Red-team (short)
- **Two handlers on one press.** Space on a tree top made both JumpTest (standing on a pad = grounded) and the ClimbTest hop fire. The JumpSuppressed gate removes that; it is checked in Studio.
- **SkillEffects overwriting the cooldown.** Sprint Legs III would write 0.5 × 0.74 = 0.37 back. Setting SkillBase_JumpCooldown 0 makes every write 0.
- **Holding JUMP on a phone now re-leaps for the raptor / pachy / T-Rex too.** That is the same as holding Space on PC today. It is behind ArenaTouchJumpHoldEnabled, so it can be turned off if Kepu wants taps only on those dinos.
- **18 studs depends on the floor push.** The raptor measured 1.24 × v²/2g. The Herrera is tuned in Studio from JumpPeakHeight, not assumed.
