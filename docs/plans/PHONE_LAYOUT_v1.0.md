# Mecha Dino Arena v1.0 — One phone layout for every dino (MDA-146) + T-Rex jump

**Goal:** every dino has the same phone controls: the big yellow ATTACK button (the dino's own attack), a JUMP button above it, and the two loadout slots. Only the moves behind the buttons differ. LEAP is called JUMP everywhere.
**Intent:**
- Kepu 2026-10-31: "same base layout for every Dino with only the variation in the actual move animation and the abilities themselves"; "call it all jump".
- Bug: the Herrera slash showed Roblox's raw grey "Slash" circle and no ATTACK, and the circle stayed on the next dino.
**Chosen direction:** mockup `docs/mockups/phone_layout_unified_options.html`, option **A** (Kepu 2026-10-31: "A · T-Rex gets JUMP").
**Architecture:**
- ArenaTouch already lays each move's Roblox CAS touch button, invisible, over its own styled button.
- Additions:
  - DinoSlash becomes one more entry in that table.
  - LEAP is renamed JUMP and shown on every dino.
  - Leftover CAS buttons of other dinos stay hidden because they are in the table but not wanted.
  - The T-Rex gets the shared leap (JumpTest / JumpServer / JumpPose) through a new small server script.

## Global Constraints
- Additive, every change behind a switch. Hash-verified installs, commit + push each step, publish only on "publish".
- Versions:
  - ArenaTouch 1.7, SlashTest 1.3, ClimbTest 1.11, AbilityBar 1.15, TRexJump 1.0 (new).
  - IdleAnimation unchanged: its leap layer already runs on every JumpEnabled rig 1.3 dino.
- Test on PC and on the phone layout before publish (lesson 2026-10-31).
- Phone layout check in Studio: new ArenaTouch test hook `ArenaTouchForceTouch`, like MechaButtonsForceTouch.

## Do-not-touch
- MechaButtons slot tiles (positions / look).
- The pachy ATTACK extras: pips, SLOWED, Blood Rush hearts.
- RUN button rules.
- The raptor / pachy jump numbers.
- JumpTest / JumpServer / JumpPose code.
- PC LMB attack paths.

## Deterministic map
| Dino | ATTACK (right 5%, bottom 10%, 13.5% W) | JUMP (right 7%, bottom 43%, 9.5% W) |
|---|---|---|
| T-Rex | bite (DinoBiteTest) | the leap, new: TRexJump 1.0 sets JumpEnabled + the numbers below |
| Raptor | pounce (DinoPounce) | the leap (as before; label LEAP → JUMP) |
| Pachy | headbutt (DinoHeadbutt) + pips / SLOWED / hearts | the leap (as before) |
| Herrera | slash (DinoSlash) + 2 charge pips; dim at 0; yellow glow while dashing | on a trunk / tree top: jumps off the tree (ClimbTest hop); on the ground: dim until MDA-147 gives it its own jump |
| Any dino, another dino's leftover CAS button | hidden (the action is in ArenaTouch's table but not wanted) | — |

## Tasks
1. **SlashTest 1.3** (Wired): unbind leftover "DinoSlash" / "DinoSlashClick" at start.
2. **ArenaTouch 1.7** (Wired). Switches: ArenaTouchSlashEnabled, ArenaTouchJumpForAllEnabled.
   - "SlashMain" ATTACK over CAS "DinoSlash", with 2 charge pips (SlashChargesNow / Max / Refill*), dim at 0 and a yellow glow while SlashLocalState is "dash".
   - LEAP renamed JUMP.
   - JUMP shown while JumpEnabled or ClimbEnabled. A press sets Humanoid.Jump for LEAP_HOLD (unchanged), which also reaches ClimbTest.
   - Dim while not usable: JumpTestState not "ready", or a Herrera on the ground before its own jump.
   - Test hook ArenaTouchForceTouch.
3. **ClimbTest 1.11** (Wired): a hop also fires on a rising edge of Humanoid.Jump (phone JUMP), besides JumpAction (PC Space).
4. **AbilityBar 1.15** (Wired): the Leap tile name becomes JUMP; the Herrera's HOP becomes JUMP (key Space). Switch AbilityBarJumpNameEnabled.
5. **TRexJump 1.0** (Wired, new server script).
   - Characters with Species "TRex" get, only where unset: JumpEnabled true, JumpWindup 0.2, JumpLaunchPower 50, JumpBoost 6, JumpBoostMinSpeed 2, JumpAirHold true, JumpStaminaCost 0, JumpCooldown 1.
   - A lower, slower leap than the raptor's 59 / 10 / 0.5. These are tunable attributes; Kepu confirms the feel.
   - Switch TRexJumpEnabled.
6. **Studio check**:
   - PC: each dino's bar reads JUMP; Space jumps on the T-Rex; Herrera Space on a tree hops.
   - Forced-touch layout on each dino: ATTACK + JUMP + slots; no grey Slash circle after Herrera → pachy; phone JUMP hops the Herrera off a tree.

## Red-team (short)
- **Risk: the T-Rex jump breaks T-Rex-only systems** (ram latch, a raptor on its back).
  - JumpTest is already proven on two dinos and the T-Rex keeps all its own moves.
  - TRexJump is one switch, so it can be turned off live.
- **Risk: Humanoid.Jump as the hop input also fires from Roblox's own controls.**
  - This game has no PlayerModule control scripts, so only ArenaTouch sets it.
- **Risk: the forced-touch hook differs from a real phone.**
  - The real-phone check stays on Kepu's list before publish.
