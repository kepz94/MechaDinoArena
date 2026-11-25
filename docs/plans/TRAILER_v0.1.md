# Mecha Dino Arena page video, plan v0.1 (2026-11-25)

Full plan (research, storyboard, camera playbook, rules, production): Claude Doc "Mecha Dino Arena Trailer Plan"
(https://claude.ai/artifact/1eg4g5yYmGXTysA1H3o4SR). Kepu 14:24: "make this a professional trailer ... research how other games run
little ads ... copy camera angles and strategies". Status: waiting for Kepu's sign-off; nothing built yet.

Rule of the cut: open on the biggest fight moment (hook under 3 s), gameplay first, cold open -> core idea -> escalation -> style ->
win -> title; 1-3 word captions for sound-off; 30 s max (Roblox video limit), real footage only, no promo text, catalog music only.

| # | Time (s) | Shot (who does it, in code) | Caption |
| --- | --- | --- | --- |
| 1 | 0.0-1.5 | Cruise Missile dive onto the point, blast on the bots (Herrera, part cmissile) | MECHA DINOS |
| 2 | 1.5-3.0 | T-Rex roars at the lens, rings hit two bots, DEF badges (T-Rex RoarEnabled; RoarServer / RoarFX) | 4v4 ARENA |
| 3 | 3.0-5.5 | Teams clash on the hardpoint, score ticking (PracticeServer) | HOLD THE POINT |
| 4 | 5.5-7.0 | Raptor pounce latches onto a bigger bot (PounceServer) | |
| 5 | 7.0-8.5 | Reaper's Hook yank + double slash, kill feed line (Therizino, part zhook) | |
| 6 | 8.5-10.0 | Sonic Hiss knocks back two bots (Dilo, part dhiss) | |
| 7 | 10.0-11.5 | Portal Feathers zip at 5x run speed (Troodon, part oportal) | |
| 8 | 11.5-14.0 | 8 dinos, 0.3 s hero pose each (UniversalSkins.DINOS) | 8 DINOS |
| 9 | 14.0-17.0 | Lab: Shock Cannon, Energy Shield, Thrusters (Raptor parts screech / shield / thrusters) | BUILD YOUR MECHA |
| 10 | 17.0-19.5 | Thrusters boost, Shock Cannon stun, Energy Shield blocks a bite (Raptor) | |
| 11 | 19.5-22.0 | Skin swaps x3, then Rainbow Road run-by | SKINS & TRAILS |
| 12 | 22.0-24.0 | Last capture tick, final KO | |
| 13 | 24.0-27.5 | Victory stage, winner's title (VictoryTitles) | |
| 14 | 27.5-30.0 | Fly through the Arena gate into the logo | logo |

Grounding (live SkillTree in Studio, 2026-11-25; Kepu 14:29 "The t-Rex doesn't have the shock cannon"): the T-Rex has no mecha
parts (bite + roar only); Shock Cannon / Energy Shield / Thrusters are Raptor parts. Practice bots carry no parts
(PracticeRules.BOT_LIVE = {}) and are never T-Rex, so every ability is fired by Kepu's test dino re-spawned per species.

Needs from Kepu: bigger Studio viewport while filming (now 847 x 541); access to
C:\Users\Kepu_\AppData\Local\Roblox\tmp-capture-storage\mcp (or clips copied to Downloads); audio choice; storyboard sign-off.
