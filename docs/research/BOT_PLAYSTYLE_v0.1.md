# Mecha Dino Arena — bot playstyle research (v0.1, 2026-11-11)

Kepu 2026-11-11 13:21: "let's rework the bots playstyle. Look up guides out there on how to program bots ... simplifying bots
to certain actions ... For example the pachy play objective while other Dino's look for 1v1 matchups ... report back".
Research only; nothing built. Live code: PracticeRules 1.x (roles cap / cap / def / hunt / esc, shuffled, not tied to the dino)
and PracticeBrain 1.0.

## What the live bots do (from the code)
- Roles only set where a bot walks while it sees nobody (PracticeRules.goalFor). Once any enemy is in sight (Easy 70 / Normal 90
  / Hard 110 studs, cone 120°), every bot fights the best-scored enemy (scoreTarget = distance − 60 if on the point + 30 x hp).
  So in practice every bot plays the same way: chase the nearest enemy. Several bots can pile onto one target.
- Roles are dealt at random each match, so a Pachy can be the hunter and a Raptor the point holder.
- QA 2026-11-11: in a 40 s watch from the start no bot reached the point; they fought on the way.

## What the guides say
1. Layers. A team brain decides the jobs, each bot only does its job, and actions are the button presses (Killzone 2:
   commander -> squad -> bot; Dota 2: team desires -> bot modes -> actions).
2. Few modes per bot, picked by score. Each bot scores every mode 0..1 about every 0.3 s and runs the highest (Dota 2
   GetDesire). Simple to read and to tune.
3. The job fits the character. TF2 bots: each class has its own behaviour (Heavy pushes, Engineer guards a spot, Sniper lurks
   at sight spots, Spy flanks); offensive / defensive rosters set how many of each.
4. Job split follows the score. Killzone 1: nothing held -> 100% attack; something held -> 50–75% attack, the rest defend;
   roles are given again at each respawn (TF2 can re-pick on death too).
5. Don't dogpile. Limit how many attackers take one target (attack tokens / slots) — this is what makes 1v1s happen.
6. Fair and readable beats smart. No wall knowledge, a reaction delay, a miss or tell before the first hit, "intelligence !=
   fun", players should feel they earned kills (Valve-archive FPS AI survey; Killzone: predictable, no information a human
   couldn't have).
7. Keep plans short and re-decide often (Killzone: bots replan 5x / s, squads 2x / s).
8. On Roblox: a small state machine (one module per state) or utility scores grouped by a state machine; stagger ticks; stop
   pathfinding while fighting (devforum).

## Sources
- Killzone 2 bot system (Verweij): https://www.guerrilla-games.com/media/News/Files/VUA07_Verweij_Hierarchically-Layered-MP-Bot_System.pdf
- Dota 2 bot scripting: https://developer.valvesoftware.com/wiki/Dota_Bot_Scripting
- TFBot technicalities: https://developer.valvesoftware.com/wiki/TFBot_Technicalities
- AI in FPS games (survey): https://www.valvearchive.com/archive/Other%20Files/Publications/AI%20in%20First-Person%20Shooter%20Games.pdf
- Halo Infinite bots: https://kotaku.com/why-halo-infinite-s-bots-act-so-much-like-people-1847511140 ,
  https://gameinformer.com/preview/2021/11/15/how-halo-infinites-bots-became-so-ruthless-and-helped-343-develop-multiplayer
- Attack tokens: https://www.strayspark.studio/blog/attack-token-system-ue5-group-combat-that-feels-fair
- Roblox NPC frameworks: https://devforum.roblox.com/t/using-ai-behavior-frameworks-for-npcs/3482097
