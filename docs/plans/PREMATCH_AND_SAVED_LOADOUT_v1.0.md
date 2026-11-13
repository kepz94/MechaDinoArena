# Mecha Dino Arena v1.0: Pre-match countdown + Saved loadout (drafted 2026-11-13)

Kepu 2026-11-13 12:58: "when the game intros are done instead of just going straight into the game and starting it, have a 10 second count down with the objective of the game showing on the screen and where the first point is. Look at how cod does this." / "allow players to save their Dino loadouts in the lab so when they select a Dino in the pregame it automatically loads their saved load out."

## Part A: Pre-match countdown
**Chosen direction:** A · Centre countdown, everyone held in place (Kepu picks), mockup docs/mockups/prematch_countdown_v0.1.html (artifact JNrC3Eg3zWyvJsuFFA784q).
**CoD reference:** after the infil a countdown runs with everyone held (look only), mode + objective on screen, the first objective's marker already in the world and on the minimap; the match starts at 0.

### Deterministic map
| Time (from the intro's end) | Server | Screen |
|---|---|---|
| intro ends | PracticeServer starts the match with HardpointPractice("start", lead) (lead = PrPrematchLead 5): HardpointServer sets HpMatchStartAt = now + lead, so its warm-up (FIRST 5 s) lasts lead + 5 = 10 s. Humans placed on their spawns and held (root anchored, server-owned); bots spawned and their brain skipped while held | PrematchCountdown: dim edges, HARDPOINT, CAPTURE AND HOLD THE HARDPOINT, +1 PER SECOND PER DINO ON THE POINT · FIRST TO 250, MATCH BEGINS IN, number 10…1 (yellow at 3…1), pill FIRST POINT · P1 <NAME>, HELD UNTIL GO. The P1 marker (HardpointHUD marker v3) already shows P1 and its distance during the warm-up |
| HpPhase becomes "live" (P1 live) | humans unanchored (ownership back to auto); bots run | "GO" for 1 s, then nothing |
| a human joins / respawns during the warm-up | placed and held like the others | same screen |
| switch off (PrPrematchEnabled false) | 1.10: start with no lead, nobody held | nothing (1.0 screen off) |
Applies to the bots match and the Arena 4v4 (both run on PracticeServer). Public Hardpoint (Arena place, no intro): unchanged.

### Tasks
| T | Name | Mode |
|---|---|---|
| A1 | HardpointServer 1.8: practice "start" takes an optional lead (0–30 s) -> HpMatchStartAt = now + lead (warm-up = lead + FIRST). No lead = 1.7 | Wired |
| A2 | PracticeServer 1.11: PrPrematchEnabled (true), PrPrematchLead (5); Practice attribute PrPrematch (true for this match); hold humans while HpPhase == "warmup" (anchor after placeHuman, release at "live" or on leaving); skip bot ticks while warm-up | Wired |
| A3 | PrematchCountdown.client 1.0 (new): layout A, PC + phone, shows while Practice PrPrematch and HpPhase "warmup", GO 1 s after "live"; switch PrematchCountdownEnabled | Wired |

## Part B: Saved loadout
**Kepu pick:** "A SAVE button only" (one saved loadout per dino). Placement: mockup docs/mockups/save_loadout_v0.1.html (artifact 1AVJfKFaSkSp8BNzNTJsyW), A · SAVE tile in the slot row or B · SAVED chip above the slots (pick pending).
**Today (grounded, SkillServer 1.10):** each dino already keeps its own last 4 slots and saves them on every change; switching dino loads that dino's last slots (checked in Studio: Raptor shield / thrusters came back after Pachy).
**New:** a separate saved loadout per dino, set only by SAVE; the pre-game puts it in your slots when you pick that dino.

### Deterministic map
| When | Result |
|---|---|
| Lab SAVE (SkillRequest "saveLoadout") | the active dino's record.saved = its current 4 slots (saved with the record); player SkillSavedLoadout = "a,b,c,d"; toast "<DINO> LOADOUT SAVED" |
| Lab shows | SAVED ✓ when the 4 slots equal SkillSavedLoadout, else SAVE LOADOUT |
| Pre-game lineup (PgPhase "lineup"): you pick a dino, or you arrive with one | if that dino has a saved loadout: slots = saved (parts you no longer own dropped, as any load); SkillLoadoutFrom "saved"; the parts step shows SAVED LOADOUT |
| no saved loadout for that dino | slots as today (its last slots) |
| changing slots in the pre-game | changes the slots, not the saved loadout |
| island / menu dino switch | as today (last slots) |
| switch off (SkillSavedLoadoutEnabled false) | 1.10 |

### Tasks
| T | Name | Mode |
|---|---|---|
| B1 | SkillTree: sanitizeLoadout reused for saved (no change) + SkillServer 1.12: record.saved, "saveLoadout" request, SkillSavedLoadout, apply on pre-game pick / arrival | Wired |
| B2 | Lab 1.16: SAVE control (picked placement), PC + phone | Wired |
| B3 | PregameScreen 1.2: SAVED LOADOUT tag on the parts step | Wired |

## Red-team (2026-11-13)
| Challenge | Outcome |
|---|---|
| Anchored players can still press abilities during the hold | Accepted: spawns are 700–900 studs from the point and ≥ 900 apart, so nothing reaches an enemy; cooldowns used in the hold are spent |
| A longer warm-up shifts the 600 s clock and P1's 60 s | Mitigated: the lead only moves HpMatchStartAt; phaseAt counts from it, so rotations and the clock start at GO |
| Saved loadout fights the auto-saved last slots | Mitigated: saved is only read in the pre-game; everywhere else stays as today |
| Players in the menu during the countdown | Unchanged: the menu still opens; the hold applies when they come out during the warm-up |
