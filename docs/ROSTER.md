# Dino roster v1.6

The list of dinos that are in the game, and the ones planned for roll-out. Add new dinos at the bottom of "Planned" as
Kepu sends them; each one goes model mockup → Kepu's pick → model data → kit plan → playable.

Sources: `src/shared/Models/*ModelData.luau`, `src/server/DinoHealthServer.server.luau` (health by species: TRex 200,
Raptor 60), `src/server/SpeciesServer.server.luau` (playable species).

## In the game (playable)
| # | Dino | Model data | HP | Run speed | Length in game | Role / Kepu's words |
|---|---|---|---|---|---|---|
| 1 | T-Rex | TRexModelData | 200 | 44 | ~40 | The heavy (bite, roar) |
| 2 | Raptor | RaptorModelData 1.13 | 60 | 78 | ~25.7 | Pounce / latch hunter |
| 3 | Pachy | PachyModelData | 90 | 56.9 | — | Headbutt / ram |
| 4 | Herrera | HerreraModelData 1.3 | 40 | 90 | ~22.4 | "a Pain in the ass to deal with but easy to kill", most mecha utility, fastest |
| 5 | Teno (Tenontosaurus) | TenoModelData 1.3 (1.4 written, not installed) | 150 | 52 | ~47 | Tank: scratch + rear tail slam |

## Planned
| # | Dino | Status | Model | Roster | Role / Kepu's words | Notes |
|---|---|---|---|---|---|---|
| 6 | Troodon | Model saved (v1.0), not installed, not playable | TroodonModelData 1.0 = B Night Watcher (mockup docs/mockups/troodon_model_options.html v0.2) | Day 1 | Skirmisher build ("The troodon will be a skirmisher build") | 12 studs at scale 1 (~24 in game), between the Herrera and the raptor; true to the animal, feathered; long drooping arms; big eyes. Kit: not planned yet (the kit plan turns "skirmisher" into moves and numbers). |
| 7 | Therizino (Therizinosaurus) | Model saved (v1.0), not installed, not playable | TherizinoModelData 1.0 = A Reaper (mockup docs/mockups/therizino_model_options.html v0.2) | Day 1 | Slasher build ("Therizino. Slasher build") | Size "Between raptor and T-Rex (~32)": 16 studs at scale 1; style "True to the animal"; "Fully feathered". Reaper: tall and gaunt, ragged feather cloak, skull-like hooked-beak head, the longest thin scythe claws held out wide. Our own design of the animal, not a copy of the film reference (© UCS LLC and Amblin). |
| 8 | Zuul (Zuul crurivastator, ankylosaur) | Model mockup v0.1 out for a pick (A Fortress / B Thornback / C Battering Ram) | — (mockup docs/mockups/zuul_model_options.html, tools/zuul_generator.py 0.1) | Day 1 | Counter-attacker | Size "Like the T-Rex (~40)": 20 studs at scale 1, low and wide, four legs (Arm segments = front legs); style "Heavier armor / spikier"; tail club is the weapon. Run inspo (Kepu's screen recording 2026-11-02, a third-party Zuul animation, not stored in the repo): a diagonal trot, the body swaying side to side, the head kept low and steady, and the tail whipping side to side in a wave that grows toward the club (strongest seen from above). For the gait plan. |

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
