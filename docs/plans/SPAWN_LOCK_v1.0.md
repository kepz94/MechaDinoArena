# Mecha Dino Arena v1.0 — Island Spawn Attack Lock (roadmap piece 1)

**Goal:** on the island, while you are protected (on the islet or the 3 s PROTECTED guard after leaving it), your attacks are locked with the same padlocks as the Arena countdown, and bots don't fight on / right off the islet.
**Kepu 2026-11-26:** "having attack buttons locked on spawn and up until the timer goes down. the bots are just fighting right at spawn even without damage"; picks "Island PROTECTED timer", "Attacks only", bots were "Fighting each other".
**Architecture:** client-side lock keyed on the existing character attribute HubSafe (HubServer: islet or HubRules.GUARD 3 s), plus FillerServer giving bots the same protection. No server move script changes: a HubSafe dino already can't hurt or be hurt (HubServer 1.3 / ArenaPvP 1.4).

## Grounding
- HubSafe = HubRules.protected(HubInZone, HubGuardUntil, now) on the character (HubServer/init.server.luau ~681).
- The Arena countdown lock (PracticeServer 1.12 PrematchLockUntil) is read by 14 character scripts; each has `locked()` = `PrematchLockUntil > now`. Padlocks: AbilityBar 1.44 (tiles), ArenaTouch 1.21 (buttons), MechaButtons 1.50 (slots). JumpTest also locks, so reusing PrematchLockUntil would stop JUMP on the islet.
- FillerServer 1.1: targets exclude bots inside the safe area and HubSafe players, but a bot still steps (and swings) while it walks off the islet, and bots just outside fight each other there.
- Part types (Tutorial SC_INFO): ATTACK 13 (traps bloodrush quills cmissile tmortar zhook zfeather dgatling dmortar dspine dover dscope osentry), CONTROL 15 (screech hookarm ink tether strobe caltrops goo tgrab tstomp tchallenge zharvest zsnare dhiss olantern osleep). MOVE / DEFENSE / HEAL / STEALTH / SCOUT / SUPPORT / PASSIVE stay usable.

## Do-not-touch
Arena / bots match lock (PracticeServer 1.12, PrematchLockUntil), every server move script, HubServer, ArenaPvP, JumpTest and the other movement scripts, PortalHUD.

## Tasks
1. **HubLockRules 1.0** (new ModuleScript, StarterPlayerScripts, Logic + spec): `ATTACK_PARTS` (the 28 ids above), `isAttackPart(id)`, `locked(char, scriptSwitch)` = `char.HubSafe == true` and the switch on.
2. **Attack inputs** (Wired): BiteTest, PounceTest, RamTest, RoarTest, HeadbuttTest, SlashTest, TenoAttackTest, TheriAttackTest, DiloAttackTest, TrooAttackTest: `locked()` also true while HubLockRules.locked (switch `HubSafeAttackLockEnabled` on each script, default true).
3. **Buttons** (Wired): ArenaTouch (main attack buttons + RAM get padlocks; JUMP / RUN don't), AbilityBar (move tiles except LEAP / HOP, and slot tiles holding an attack part), MechaButtons (a press of an attack part is dropped; a slot button shows the padlock when its tap part is an attack part). Same padlock look as the Arena countdown.
4. **FillerServer 1.2** (Wired): a bot inside the safe area, or for 3 s (HubRules.GUARD) after leaving it, is not a target and steps with no enemies (walks only). Switch `FillerSafeGuardEnabled`.

## How this fails (red-team, short)
- A pull-down (slot 3 / 4) attack part shares a button with a non-attack tap part: that press is blocked but the button shows no padlock. Accepted (the press still does nothing).
- If HubSafe were ever stuck true, attacks would stay locked on the island: the switch turns it off live; HubServer writes HubSafe on every change and clears the guard on a fresh body.
- Studio check: hub Play with the save switches off; filler bots need FillerTestReal in Studio.

## Build (2026-11-26, Kepu "Build" 04:17)
Built as planned; patches tools/spawnlock_patch_*.luau from tools/spawnlock_generator.py, spec tools/tests/HubLockRules.spec.luau PASS 57. Studio checks and hashes in docs/VERSIONS.md. Not published. Still to see live: a real phone on the islet, and bots walking off the islet without swinging.
