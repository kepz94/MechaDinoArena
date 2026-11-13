# Dev Hub backlog audit (2026-11-13)

Source: Dev Hub `list_tickets` status backlog (141 tickets, MDA-334..492). Evidence per ticket: a docs/VERSIONS.md row naming the ticket (or its range), the script version in src/ and a publish row. Every publish uploads the whole place, and v764 (2026-11-13) was published with all scripts hash-matched to GitHub, so built = live.
Nothing was closed. Kepu approves.

## A. Built and published (close)
| Group | Tickets | Evidence (VERSIONS / script / publish) |
|---|---|---|
| Troodon kit + parts | 334, 336, 338, 349, 373–389 | TrooAttackTest 1.0+, TrooFX 1.0+, TrooPartsServer 1.0, TrooSlotServer, SkillTree 1.81–1.88; v609, v611, v619 |
| Balance pass 1 | 355–367 | ModelData installs (VERSIONS "Balance pass 1 Studio install"), BoneCrest 1.7 + 17 servers, SkillTree 1.79; v582, v600 |
| Pachy bugs | 355, 356 | HeadbuttServer 1.18, HeadbuttTest 1.3 |
| Troodon bugs | 376, 377 | TrooMovesServer 1.8 / 1.11; v609, v611 |
| Camera modes | 368–372 | CameraSettings 1.0, CameraModes 1.0, ShoulderCam 1.9, MechaButtons 1.40 |
| Dilo VFX + Cobra Spring | 390–395 | DiloPartsVFX 1.0 (Reactor Glow, Liquid Venom, Chem Warfare), DiloModelData 1.13 |
| Hardpoint v1.0 | 396–403 | HardpointRules 1.0, HardpointServer 1.0, ArenaSpawnServer 1.3, HardpointPointFX 1.0, HardpointHUD 1.0 |
| Practice match v1.0 | 404–415 | PracticeRules 1.0, PracticeServer 1.0–1.2, PracticeBots, PracticeLobby, KillFeed, MainMenu 1.22, HardpointHUD 1.2; v699 (Nov 10) |
| Team Tags v1.0 | 416–419 | TeamTagRules 1.0, TeamTags 1.0/1.1, HardpointHUD 1.3; v662 |
| Bots half size | 420 | RaptorScale 1.9 |
| Spawns + marker v2, far spawns, slim HUD | 421–428 | HardpointRules 1.1/1.2, HardpointServer 1.2/1.3, HardpointHUD 1.4/1.6 |
| Bot jobs | 429–432 | PracticeRules 1.1, PracticeServer 1.3, PracticeBrain 1.1 |
| Point marker v3 | 433, 434 | HardpointHUD 1.7 |
| Dilo ammo / Hiss, Troodon double tap, Dilo texts | 435–441 | DiloModelData 1.14, DiloAttackServer 1.10, DiloMovesServer 1.11, TrooAttackServer 1.8, SkillTree 1.89; v680, v686 |
| Lab clips | 442–447 | LabClipRecipes 1.0/1.1, LabClipPlayer 1.0/1.1, Lab 1.15; v686, v690 |
| Silkscreen font | 449–451 | FontSwapRules 1.0, FontSwap 1.0; v692 |
| Island hub | 452–459 | HubRules 1.0, ModeRules 1.2, SquadRules 1.3, HubServer 1.0, PortalHUD 1.0, MainMenu 1.23; v699 (Nov 11), v701 |
| Match end | 461–465 | MatchAwards 1.0, SkillServer 1.10, KillFeedServer 1.1, HardpointServer 1.5, HardpointHUD 1.8 |
| Bots v2 | 466–473 | PracticeRules 1.2, WaterSwim 1.1, PracticeBrain2 2.0+, PracticeKit 1.0+, PracticeServer 1.7; v724 |
| Rift gates | 474–476 | PortalRift.build 1.0, PortalFX 1.0, HubServer 1.3; v741 |
| Mode loading | 478, 479 | EggLoader 1.3, MainMenu 1.25; v741 |
| Pre-game Part 1 + 2 | 481–491 | ArenaRecordRules 1.0, ArenaRecordServer 1.1, PracticeRules 1.3, PracticeServer 1.9/1.10, PregameModels 1.0, PregameScreen 1.0/1.1, HubRules 1.2, ModeRules 1.4, HubServer 1.4, PortalHUD 1.3; v760, v764 |

## B. Waiting on Kepu (keep open until he says)
| Ticket | Why |
|---|---|
| MDA-448 | Lab clips for the other dinos: "needs Kepu's look" |
| MDA-460 | Island hub live checks |
| MDA-477 | Rift gates live check |
| MDA-480 | Mode loading live check |
| MDA-492 | Max players ≥ 8: both places are already 50 (Open Cloud read 2026-11-13). Closable if Kepu keeps 50. |

## C. Not built (keep)
| Ticket | Why |
|---|---|
| MDA-354 | Gamepad buttons for mecha parts: no gamepad mapping in MechaButtons / AbilityBar |

## Outcome (2026-11-13 11:42–12:10)
- **What Kepu approved:**
  - "Close the 136 + 492", then "Close all the tickets".
  - For the last 11: "Close all but MDA-354".
- **Closed: 148 tickets.** Each one's acceptance items were ticked, then the ticket moved to done:
  - MDA-334..492 (A and B above, plus MDA-426 and MDA-437, which this list had missed)
  - MDA-493..498 (Arena record v1.1 and Elite combos, live in v769)
- MDA-492 has a note: max players stays 50.
- **Still in the backlog:** MDA-354 (gamepad buttons, not built).
