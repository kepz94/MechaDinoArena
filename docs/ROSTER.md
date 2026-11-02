# Dino roster v1.1

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

## Version log
| Version | Change |
|---|---|
| 1.0 | First list (Kepu 2026-11-01: "Let's save this model and I'll send you more Dino's that we're going to roll out so we can build on that list"). |
| 1.1 | Troodon role: skirmisher build (Kepu 2026-11-02). Planned table gains a Role column. |
