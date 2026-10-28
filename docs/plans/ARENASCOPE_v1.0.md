# Mecha Dino Arena — Arena scope v1.0 (what stays, what is switched off)

**Goal:** remove the survival-game layer from Mecha Dino Arena (Kepu, 2026-10-28: "the hunger and thirst bars should not exist", "its not a survival game anymore"). Nothing is deleted. Each system is switched off in Mecha only:
- in the Studio place: the script's `Enabled = false`;
- in the repo: a `.meta.json` with `"Enabled": false`, so a Rojo sync gives the same result.

Dino Arcade (kepz94/DinoBlox) is untouched.

## Kepu's answers (2026-10-28)
| System | Decision | Scripts |
|---|---|---|
| Hunger / thirst, eating, drinking | OFF | SurvivalServer, SurvivalBars |
| Prey animals | OFF | PreyServer |
| Carcasses + flies | OFF | SurvivalServer (makes them), CarcassFlies |
| Goals | OFF | GoalServer, GoalTracker |
| Growth | already off via `GrowthEnabled` (StatServer 1.0); kept for part 3 (XP → skill points) | GrowthServer, GrowthBar, LevelUpFX: unchanged |
| Bot dinos | ON | BotServer (bots still roam, fight and chase; prey hunting finds nothing) |
| Ambush grass + creep | OFF; the grass stays as scenery | CreepServer, CreepTest, CoverHint, BushView; hiding through BotServer 1.11 `BotHidingEnabled = false` |
| Training dummy | OFF | BiteDummy |
| Hitbox view (H) | ON | HitboxView |
| Roar (T-Rex) | OFF | RoarServer, RoarTest, RoarFX |
| Ram (T-Rex), incl. throwing latched raptors off (ShakeOffServer) | ON | RamServer, RamTest, ShakeOffServer |
| Pounce + latch (Raptor), leap | ON | PounceServer, PounceTest, JumpServer, JumpTest |
| Bite, sprint | ON | BiteServer, BiteTest, SprintTest |
| Class card | hidden until the skill tree screen | ClassCard (StatServer keeps applying stats) |
| HUD: health + species picker top-right, stamina while latched, custom mobile buttons | next plan (mockup gate) | HealthBar, SpeciesPicker, StaminaBar, the *Test input scripts |

## Changes
1. **ArenaScope 1.0** (new server script, check only). At start it publishes, for every scoped script:
   - `ArenaScope_<Name>`: "off" / "on" / "missing" / "mismatch" (expected off but enabled, or the reverse);
   - script attributes `ArenaScopeVersion` and `ArenaScopeMismatches`.

   It changes nothing, so the scope stays traceable in Play.
2. **BotServer 1.11.** Script attribute `BotHidingEnabled` (default true = v1.10). When false:
   - every player gets `Hidden = false`, `HiddenReason = "off"`, `CoverHint = false`;
   - neither the v1.7 grass rule nor the legacy bush rule runs.

   Mecha sets it false: in the place (script attribute) and in `BotServer.meta.json` "attributes".
3. **`.meta.json` `"Enabled": false`** for the 15 OFF scripts above. RoarFX's existing meta keeps its RunContext.

## How it fails (one paragraph, 2 tickets)
- **A script switched off while another reads what it wrote:**
  - SurvivalServer's carcass and eat attributes: only BotServer's own eat pose uses the same attribute names, and it writes them itself.
  - GoalServer's `GoalXpEarned` is read by GrowthServer, which is off.
  - PreyServer's prey are made at runtime, so none exist.

  Checked by grep (2026-10-28).
- **A Rojo sync re-enabling them:** covered by the meta files.
- **Bots still hunting:** with no prey they only fight bots and chase players.

**Acceptance (Play):**
- no hunger / thirst bars, prey, carcasses, goals or class card;
- C and R do nothing;
- a raptor in tall grass stays `Hidden = false` (bots still chase it);
- bite, sprint, ram (+ tree throw-off), pounce + latch and leap still work;
- bots still fight;
- `ArenaScopeMismatches = 0`;
- no new warnings.
