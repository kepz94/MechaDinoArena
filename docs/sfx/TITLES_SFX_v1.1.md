# Title show sound effects and music — cue sheet v1.1 (MDA-552, round 16)

Kepu 2026-11-17 16:48 kept all 16 music tracks (8 hero, 8 clown). This is the in-game build: `src/client/VictoryTitlesAudio.luau`
1.0, driven by VictoryTitles 1.3. Renders: `docs/sfx/gen_titles_sfx.py` v1.1 (Sonniss GDC 2026 bundle; sources and renders are
not in this repo). Times are seconds on the title's own clock (VictoryTitlesAnim 1.3 `runner.time()`, the animation's beats),
so a cue stays on the picture when the game runs slow. v1.0 (cue sheet `TITLES_SFX_v1.0.md`) is unchanged and still drives the
mockup page.

## Music

Each title starts a track picked at random (never one of the last two) from its list, at VictoryMusicVolume 0.4, and fades out
over 0.35 s when the next title starts, a title is skipped or the show stops.

| Titles | Tracks (Roblox asset id) |
|---|---|
| Good: APEX PREDATOR, KING OF THE HILL, UNKILLABLE, MEDIC, BUTTON MASHER | All Action Hero (f) 1839895012, Day Of The Election Sting 2 9042409054, Global Success StingA 1848016523, Herald of Freedom (Sting 1) 95493370982599, Forging The Army StingA 1835295052, Wings of Destiny (Sting 2) 94745027512855, The Ultimate Challenge StingA 1848014986, Triumph 1839432165 |
| Roasts: EXTINCT, CARRIED, PACIFIST | Clown Parade Sting 1 9046171154, Clown Parade Sting 2 9046171148, Circus And Clowns Link 9046172786, Clown Parade Link 9046171151, Circus And Clowns Sting 2 9046173035, Round Up Round Up Link 2 9046174316, Cheerful Tuba 9042030749, Funny Cut D3 1846070982 |

## Sound effects

| Cue | When | Built from |
|---|---|---|
| res_cheer / res_fireworks | the results start (a match with a winner) / + 0.25 s | as v1.0 |
| gslam_hero / gslam_roast | with each title (wall clock; the hit is 0.42 s in, the lower third slams in at 0.3-0.55 s) | Impact Cut Sweep from 0.62 s; Transition Frantic Shaker Snap from 0.05 s |
| apex, masher, extinct, carried | as v1.0 | as v1.0 |
| king_bonk | 0.10 (hit on the bonk, 1.0) | Cartoon Airy Impact Creaks (the rising air is the crown falling) + metal tap |
| king_coin / king_land | 1.1 / 1.55 | coin flip (the crown spinning off); metal tap + wood piece (it lands crooked) |
| king_rattle | 1.9 | spring-wire clatter (the head shake) |
| king_ding | 2.49 (ding on 2.55) | Ting Coins + Button Arp Twinkle |
| apex_cheer | 3.2 | crowd cheer as it stands up proud |
| unk_chew x2 | 0.0, 4.3 | dinosaur eating, 0.8-2.4 s |
| unk_glint | 0.45 | Button Arp Twinkle |
| ext_fall | 0.9 (peak on the hit, 1.7) | fire whoosh (as v1.0) |
| unk_hit | 1.68 | cartoon blast + trailer boom 075 + wood pieces (rocks) + debris whoosh |
| unk_rocks / unk_pebble | 2.35 / 4.75 | board-game piece bounces x5 (falling rocks); piece + faint metal tap |
| medic: car_swish / car_thump | 0.12 (pitch 0.8) / 0.55 | the kit drops in and lands |
| med_open | 0.98 (lid on 1.05) | antique lid + Cofetti Whoosh Pluck Spill (hearts) + Game Entry Happy |
| car_zip / car_swish x2 | 1.45 / 1.75, 1.95 (pitch 1.15, 1.3) | the plaster sticks; the head shake |
| med_slap | 2.42 (hit on the slap, 2.62) | heavy swing to thud + combat quick smack |
| med_heal | 3.0 | Power Up Bright Positive shimmer |
| pac_bloom | 0.1 | Magic Creation 23 (the daisy grows) |
| pac_ah x3 | 1.5 / 1.83 / 2.15 (pitch 1.1 / 1.25 / 1.4) | police officer gasp (ah... ah... ah...) |
| pac_choo | 2.38 (choo on 2.42) | violent exhale + anime exhale + Cofetti spill (the petals) + smack |
| car_thump / car_dizzy / unk_glint | 2.9 / 2.95 / 4.4 (pitch 1.2) | it lands on its back; stars; the butterfly lands on its foot |
| board_cheer / board_fireworks | the show ends by itself / + 0.2 s | as v1.0 |

Volumes: each cue's default (`VictorySfxVol_<cue>`) sets its active loudness to a target (beds -26 to -20 dB, big moments -13
to -15 dB, others -17 dB). Ids: `VictorySfxId_<cue>` (a blank cue is silent); the uploaded ids are VictoryTitlesAudio 1.1's M.IDS.
