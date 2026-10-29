# Mecha Dino Arena — Raptor Traps v1.0: Shock Mine (Grapple scrapped)

**Goal:** give the raptor a trap part so it can control ground ahead of a fight, and scrap the Grapple Hook (it overlapped Thrusters / Pounce / Shock Cannon).
**Intent (Kepu 2026-10-29):** "Nah, let's scrap it and introduce traps. Maybe that'll make the raptor more diverse."
**Chosen direction:** mockup `docs/mockups/raptor_traps_options.html` — **B · Shock mine**, in the **Engineer** area. **Bots trigger mines**. Kepu's calls: the mine's damage **hurts players too** (the game's first player-vs-player damage; Energy Shield blocks it), **bots are slowed too**, numbers as proposed.
**Architecture:** batch 1/2 timed-part pattern: SkillTree effects -> SkillEffects character attributes (while slotted) -> MineServer gate + mines -> MechaButtons / AbilityBar TIMED_PARTS. Slow: players through SprintTest (MineSlowUntil × MineSlowMul); bots through MineServer itself (WalkSpeed scaled on Stepped, BotServer untouched).

## Numbers (35% rule)
| Step | Shock Mine |
|---|---|
| I | Button: throw a mine 30 studs ahead along your facing (lands on the ground). Arms 0.5 s after landing, lasts 60 s. A dino (not you; bots too) within 6 studs sets it off: 15 damage + 50% slow for 2 s; recharge 12 s; 1 mine out |
| II | 2 mines out at once (a new one replaces the oldest) — 2.0x |
| III | Recharge 8.8 s (12 / 8.8 = 1.36) |
| ★ | Mines also jam parts (PartsJammedAt: boost, Shield, Adrenaline end) |

Effects: mineDamage 15, mineSlow 0.5, mineSlowTime 2, mineCooldown 12 / 8.8, mineMax 1 / 2, mineJam (★).

## Tasks
1. **SkillTree 1.12** (Logic): OWNER.grapple "none" (scrapped, hidden); OWNER.traps "Raptor", LIVE_MECH + BUTTONS traps; path shown as "Shock Mine" with step texts; effects; spec 1.12.
2. **SkillEffects 1.9** (Wired): MineEnabled / Damage / Slow / SlowTime / Cooldown / Max / Jam while slotted.
3. **MineServer 1.0** (Wired, new): DinoMineRequest(stamp) gate (badArg / dead / disabled / stunned / latched / cooldown / ok); throw arc 0.6 s to the ground point; mine model (dark disc, cyan blinking light); arm 0.5 s; trigger 6 studs (players other than the owner, bots in DinoIsland.Bots, alive); damage: player Humanoid:TakeDamage (+ LastHitBy / LastHitAt like a bot bite), bot DummyHealth (+ kill attribution KilledWith "mine"); slow: MineSlowUntil / MineSlowMul on the target; bot WalkSpeed scaled on Stepped while slowed; ★ PartsJammedAt; electric burst. Over the max: oldest removed ("replaced"); 60 s expiry ("expired"); owner death / leaving / MineEnabled false removes them. MineStartedAt stamped on a throw. Off switch MineServerEnabled.
4. **SprintTest 1.8** (Wired): MineSlowUntil × MineSlowMul in the part multipliers (MoveSpeedParts "mine").
5. **CloakServer 1.5** (Wired): PART_STAMPS += MineStartedAt (throwing a mine ends your cloak, like every other part).
6. **MechaButtons 1.11 + AbilityBar 1.5** (Wired): TIMED_PARTS.traps ("Mine", DinoMineRequest, "SHOCK MINE").
7. **ArenaScope 1.9**: expects MineServer.

## Do-not-touch
BotServer AI (bot slow is done from MineServer), PounceServer, Shock Cannon, Thrusters physics, Scent.

## Red-team (one paragraph)
Player damage is new to the game: it makes the mine the only part that can kill a player, so 15 (25% of a raptor's 60, 7.5% of a T-Rex's 200) is the line to watch — accepted, Kepu tunes after playing; Energy Shield blocks it through the existing TakeDamage block. Bot slow without touching BotServer: MineServer rescales WalkSpeed every Stepped and remembers the AI's last value, so the AI's own speed changes still land; risk of a 1-frame full-speed step, accepted. Mines are server parts visible to everyone (blinking), so they are an area-denial tool, not a hidden one — that's the B pick. A raptor at II can hold 2 mines for 60 s; the cap and expiry keep the arena from filling up.

## Follow-up after v84 — blast + launch (Kepu 2026-10-29)
Kepu: "a bot walked on it but it didn't do anything to the bot noticeably. Remember this needs to feel like a game. I need to see some effects on the player and make this an actual useful gadget." Picks: **Blast + launch**, damage **25**, feedback **Zap on the dino**, **Damage number**, **Zap sound** (not "Bigger blast": the 1.0 burst stays).

| Task | Mode | Change |
|---|---|---|
| 8 — SkillTree 1.13 + spec | Logic | mineDamage 25; mineLaunch 25; mineDaze 1; step I text |
| 9 — SkillEffects 1.10 | Wired | MineLaunch, MineDaze |
| 10 — MineServer 1.1 | Wired | launch mode (MineLaunchEnabled): players thrown by the existing stun toss (StunTossFrom / Distance / At + StunnedUntil = 0.6 + daze; StunClient unchanged); bots thrown by MineServer (anchored arc + flip) then StunnedUntil = landing + daze (BotServer lays them down, StunFX stars); zap arcs + sparks + light on the target; rising "-25" / "BLOCKED"; zap sound (MineSoundId) |

Red-team (one paragraph): thrown dinos land 25 studs away from the mine, so a raptor that wants to follow up has to chase, which Pounce covers; the toss uses the same island-limit clamp as the ram toss. A bot already busy (latched, pinned, ramming) is only dazed so MineServer never fights BotServer for the root. Shield: damage shows "BLOCKED" but the throw still happens (the shield blocks damage, not shoves) — flagged to Kepu. The sound is a public Creator Store asset; if it fails to load the blast is silent (MineSoundId swaps it).
