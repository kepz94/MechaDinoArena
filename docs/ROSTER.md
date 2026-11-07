# Dino roster v1.27

The list of dinos that are in the game, and the ones planned for roll-out. Add new dinos at the bottom of "Planned" as
Kepu sends them; each one goes model mockup → Kepu's pick → model data → kit plan → playable.

Sources: `src/shared/Models/*ModelData.luau`, `src/server/DinoHealthServer.server.luau` (health by species: TRex 200,
Raptor 60), `src/server/SpeciesServer.server.luau` (playable species).

## In the game (playable)
| # | Dino | Model data | HP | Run speed | Length in game | Role / Kepu's words |
|---|---|---|---|---|---|---|
| 1 | T-Rex | TRexModelData 2.0 (installed, StarterCharacter 1.3; RaptorScale 1.5 x1.63) | 200 | 60 | ~62 | The heavy (bite, roar). Redesign X = Apex true to life at roster scale (published v321) |
| 2 | Raptor | RaptorModelData 1.13 | 60 | 78 | ~25.7 | Pounce / latch hunter |
| 3 | Pachy | PachyModelData 1.4 (installed, published v319) | 90 | 56.9 | — | Headbutt / ram. Redesign saved: refined Crowned Skull, horns always on, mid section +25%, cream dome; Battering Dome star = stat boosts only |
| 4 | Herrera | HerreraModelData 1.3 | 40 | 90 | ~22.4 | "a Pain in the ass to deal with but easy to kill", most mecha utility, fastest |
| 5 | Teno (Tenontosaurus) | TenoModelData 1.4 (installed, published v323) | 150 | 52 | ~47 | Tank: scratch + rear tail slam |
| 6 | Troodon | TroodonModelData 1.1 (B Night Watcher + kit attributes; kit plan docs/plans/TROODON_KIT_v1.0.md, MDA-330..339) | 55 | 74 | ~24 | Area control + support (Kepu 2026-11-06, replaces the 1.1 "skirmisher"): Glow Pod Toss (a lobbed pod that splashes a glow zone 20 studs across for 3 s: 6 + 3 x 3 to enemies, slow 25%, +5 x 4 heal to squadmates, +2 self-heal per enemy hit; 2 charges) and the Evade Hop (~18 studs straight back, ~5.3 high, 2 charges). Not published yet |
| 7 | Therizino (Therizinosaurus) | TherizinoModelData 1.5 (A Reaper, stance C3 Low flare, open hand; kit plan docs/plans/THERIZINO_KIT_v1.0.md) | 80 | 66 | ~32 | Slasher build ("Therizino. Slasher build") |
| 9 | Dilo (Dilophosaurus) | DiloModelData 1.3 (E Bruiser Face, split hood frill; kit plan docs/plans/DILO_KIT_v1.0.md) | 70 | 66 | ~26 | Ranged spitter (venom dart + Cobra Leap) |

## Planned
| # | Dino | Status | Model | Roster | Role / Kepu's words | Notes |
|---|---|---|---|---|---|---|
| 8 | Zuul (Zuul crurivastator, ankylosaur) | Model installed in Studio + Studio-only display (published v359), not playable, kit not planned | ZuulModelData 1.1 = C Battering Ram (mockup docs/mockups/zuul_model_options.html v0.4; 1.0 was D Thornback Mace) | Day 1 | Counter-attacker | Size "Like the T-Rex (~40)": 20 studs at scale 1, low and wide, four legs (Arm segments = front legs); style "Heavier armor / spikier"; tail club is the weapon. Battering Ram: front-heavy, high armoured shoulders with huge forward shoulder spikes, rows of flat keeled plates on the back, side spikes growing toward the shoulders, brow horns pointing forward, the tail held up straight with a heavy spiked block mace. Run inspo (Kepu's screen recording 2026-11-02, a third-party Zuul animation, not stored in the repo): measured frame by frame (10 fps): one stride cycle ~0.75 s, a diagonal trot, the body nearly level with a slight bob, the head low and steady, and the tail bobbing UP AND DOWN in a wave that grows toward the club (side view: the club travels ~12% of the body length top to bottom each cycle; top view: almost no side-to-side swing). For the gait plan. (v1.6 said side to side: wrong, read off a small contact sheet; corrected by Kepu.) |

## Version log
| Version | Change |
|---|---|
| 1.0 | First list (Kepu 2026-11-01: "Let's save this model and I'll send you more Dino's that we're going to roll out so we can build on that list"). |
| 1.1 | Troodon role: skirmisher build (Kepu 2026-11-02). Planned table gains a Role column. |
| 1.2 | Added #7 Therizino, slasher build (Kepu 2026-11-02). |
| 1.3 | Therizino: Day 1, ~32 in game, true to the animal, fully feathered; model mockup v0.1 (Kepu 2026-11-02 "Make the model"). |
| 1.4 | Therizino mockup v0.2: three different styles (Reaper, Brute, Mantis) built around intimidating slashing claws (Kepu 2026-11-02). |
| 1.5 | Therizino model saved: TherizinoModelData 1.0 = A Reaper (Kepu 2026-11-02: "Let's go with the reaper look"). |
| 1.6 | Added #8 Zuul: counter-attacker, Day 1, ~40 in game, heavier armour / spikier; model mockup v0.1 (three styles); run inspo notes (Kepu 2026-11-02). |
| 1.7 | Zuul run inspo corrected: the tail bobs up and down, not side to side (Kepu 2026-11-02; re-measured from the video). |
| 1.8 | Zuul model saved: ZuulModelData 1.0 = D Thornback Mace (Kepu 2026-11-02: "I want the thorn back with the mace shape at the end of the tail from the battering ram build"). |
| 1.9 | Zuul model switched to C Battering Ram: ZuulModelData 1.1 (Kepu 2026-11-02: "Okay let's just go with the battering Ram version"). |
| 1.10 | Added #9 Dilo: ranged spitter, Day 1, raptor size, twin crests + our own fold-out frill; model mockup v0.1 (three styles) (Kepu 2026-11-02). |
| 1.11 | Dilo mockup v0.2: the frill splits in the middle (Kepu 2026-11-02). |
| 1.12 | Dilo mockup v0.3: D Cobra Hood Red, the Cobra Hood with a red frill and yellow markings (Kepu 2026-11-02). |
| 1.13 | Dilo mockup v0.4: D's frill itself is red and yellow, in red / yellow / red rings (Kepu 2026-11-02). |
| 1.14 | Dilo mockup v0.5: side-by-side compare with the saved troodon (Kepu 2026-11-02: "Can you compare it to the troodon"). |
| 1.15 | Dilo mockup v0.6: D 35% thicker (body, neck, tail, legs, arms; head +18%) (Kepu 2026-11-02: "the Dilo is too thin"). |
| 1.16 | Dilo mockup v0.7: D 70% thicker all around, head +35% (Kepu 2026-11-02: "Maybe even more thicker just all around"). |
| 1.17 | Dilo mockup v0.8: three wider face options on D's body, E Bruiser / F Croc / G Viper, and a face close-up view (Kepu 2026-11-02: "the face looks too skinny and narrow"). |
| 1.18 | Dilo model saved: DiloModelData 1.0 = E, the Bruiser face on D's body (Kepu 2026-11-02: "I like the bruiser face."). |
| 1.19 | Pachy head rework mockup v0.1: three more intimidating domes (Kepu 2026-11-02: "the pachy dome ... Looks too much like an egg ... should be a more intimidating Dino"). |
| 1.20 | Pachy mockup v0.2: Crowned Skull + spikes always on (Kepu's pick) with a bulkier mid section, E +25% / F +40% (Kepu 2026-11-02). |
| 1.21 | Pachy mockup v0.3 / v0.4: the Crowned Skull redone with more care (dome grows out of the skull, ten chunky horns round its base, flush brows, slit eyes, cheek horns, nose and spine knobs) (Kepu 2026-11-02: "put more effort into the design. This looks really sloppy"). |
| 1.22 | T-Rex redesign mockup v0.1: three designs with real proportions, same colour roles and length (Kepu 2026-11-02: "the t-Rex needs a redesign. It looks way too cartoonish with its portions"). |
| 1.23 | T-Rex mockup v0.2: A2 Apex true to life (real-size skull ~13%, head level with the back, tail ~half the length) and X = A2 at roster scale, 62 studs (Kepu 2026-11-02: "Okay do it"). |
| 1.24 | T-Rex redesign: Kepu picked X, the true-to-life Apex at roster scale (62 studs) (2026-11-02: "Let's go with X that looks way cooler"); plan TREX_REDESIGN_v1.0 written. |
| 1.25 | Pachy redesign saved: PachyModelData 1.4 (E +25%, cream, star = stat boosts only); T-Rex plan approved (Kepu 2026-11-02: "I'm good with this plan"). |
| 1.26 | Status catch-up from the repo (2026-11-02): T-Rex 2.0, Pachy 1.4 and Teno 1.4 are installed and published; Troodon / Therizino / Zuul / Dilo models are installed in Studio with Studio-only displays (published v359 / v361), Therizino stance 1.2 (open hand, claws hanging low). None of the four is playable; no kit plan yet. |
| 1.27 | Troodon kit (plan TROODON_KIT_v1.0, MDA-330..339, 2026-11-06): troodon role "Area control + support" (replaces 1.1's "skirmisher"), playable (SpeciesServer 1.8), model data 1.1. Therizino (kit plan THERIZINO_KIT_v1.0, model data 1.5) and Dilo (kit plan DILO_KIT_v1.0, model data 1.3) were already playable: moved to "In the game". Zuul stays planned. |
