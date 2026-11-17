# Title show sound effects — cue sheet v1.0 (MDA-552, round 15)

Kepu 2026-11-17 15:05 "Nah these are ass, I think it would be better to have better music and sound effects during these";
15:10 "Clown music for the crappy title cards and hero music for the good ones" / "With the appropriate sound effects".
Renders: `docs/sfx/gen_titles_sfx.py` v1.0 (Sonniss GDC 2026 bundle; sources and renders not in this repo). Times are seconds
into the title (VictoryTitlesAnim 1.1 beats) unless marked g (seconds from the end of the match, results start).

| Cue | When | Built from |
|---|---|---|
| res_cheer | g 0.0 | crowd cheering and applause (KSL, small club) 0-3.4 s |
| res_fireworks | g 0.25 | fireworks, powerful explosions (2.45-7.35 s) |
| slam_hero | title start + 0.3 - 0.74 (hit on the lower-third slam) | Impact Cut Sweep |
| slam_roast | title start + 0.3 - 0.47 (snap on the slam) | Transition Frantic Shaker Snap |
| apex_pounce / land / roar / cheer | 1.05 / 1.48 / 2.22 / 3.45 | wind whoosh; low metal thud + wood pieces (bones); T-Rex 3.55-5.4 s + trailer boom 075; crowd cheer |
| mash_click x16 | 0.78, then 0.85 + (k + 0.45) / 7.2 for k = 0..14 (each press), pitch +3 % a press | deep latch click + UI click |
| mash_sizzle / pop / fly / sad / wahwah | 2.1 / 2.72 (boing peak on 3.0) / 3.1 / 4.36 / 4.6 | fire crackle; boing + small cartoon blast; debris whoosh; muted deny + click; cartoon bass-down |
| ext_happy x2 / gulp / fall / impact / sign / ghost | 0.05, 0.5 / 1.0 / 1.5 (peak on 2.3) / 2.22 / 3.22 / 3.45 | happy plucks + kalimba; cartoon bubbles; fire whoosh; trailer boom 214 + cartoon blast + thunder rumble; pop + cartoon pops; magic light spell |
| car_bite / swish x5 / fling / dizzy / poof / bag / zip / mmph x2 / thump | 0.7 / 1.0-2.05 / 1.58 / 2.4 / 2.6 / 2.95 / 3.85 / 4.25, 5.3 / 4.85 | dinosaur bite; infographic swish (pitch rising); snap-spin; cartoon dizzy; cartoon pops; canvas bag + basket pats; velcro rip; muffled grunt (low-passed 900 Hz); low thud |
| board_cheer / board_fireworks | g 26.2 / 26.4 | crowd cheer 0-7 s; fireworks with whistles |

Music (round 15, in game only): hero music under APEX PREDATOR / KING OF THE HILL / UNKILLABLE / MEDIC / BUTTON MASHER, clown
music under EXTINCT / CARRIED / PACIFIST; each cue starts with its title and fades at the next. Candidates from Roblox's APM
library are listed on the Results Show Mockup page (v1.1); Kepu picks.
Not yet cued: KING OF THE HILL, UNKILLABLE, MEDIC, PACIFIST (not in the recording).
