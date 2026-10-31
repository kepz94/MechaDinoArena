# Mecha Dino Arena v1.0 — Per-dino stat lines (Herrera first)

**Goal:** each dino's STATS tab shows rows named and worded for that dino's own moves, and every step does something on that dino.

**Intent (Kepu 2026-10-31):**
- "you keep applying these to any new Dino we make even tho most of them are specific to either t-Rex or the Raptor."
- "I need you to just have a generalized stat line that can be customized to the Dino."
- "you wouldn't call it jaws here because the herera doesn't use jaws at all."

**Chosen direction:** mockup `docs/mockups/stat_lines_per_dino_options.html`.
- Option **A · Same rows, own names**.
- New rows **Tree Stalker** and **Blood Frenzy**.
- Picked by Kepu on 2026-10-31 (AskUserQuestion).

**Architecture:**
- Same path ids, so saved steps keep their pips.
- `path.nameFor[dino]` (new) and `path.stepsFor[dino]` (existing) give each dino its own name and step text.
- `SkillTree.effects(steps, dino)` turns the Herrera's steps into its own effects.
- SkillEffects writes those effects as character attributes that the slash, sprint and climb scripts already read, plus a few new flags.

## Audit before the change (Herrera, v256)
| Row | Before |
|---|---|
| Regeneration | worked |
| Lifesteal | did nothing (heals only from bite, pounce and headbutt hits) |
| Jaws I | worked (+5 Attack → slash 8 → 13) |
| Jaws II–★ | did nothing (bite cooldown / T-Rex bleed / crush) |
| Thick Hide | worked |
| Sprint Legs I/II/★ | worked |
| Sprint Legs III | did nothing (pounce / ram / leap cooldowns) |

## Rows now (Herrera)
| Row (path id) | Area | I | II | III | ★ |
|---|---|---|---|---|---|
| Regeneration (regen) | Health | unchanged | | | |
| Blood Drinker (lifesteal) | Health | 5% of slash + bleed damage | 10% | 15% | overheal shield |
| Razor Claws (jaws) | Attack | +5 Attack (slash 13) | refill ×0.65 (4 → 2.6 s) | bleed 5/s | 3rd charge |
| Blood Frenzy (frenzy, new) | Attack | run ×1.1 while a bleeding dino is within 40 × scale | bleed 6 s | +3 on a bleeding dino | a kill while it bleeds refills all charges |
| Wiry Frame (hide) | Defense | same effects as Thick Hide, own text | | | |
| Scurry Legs (legs) | Speed | I / II / ★ unchanged | | climb ×1.35 | |
| Tree Stalker (stalker, new) | Hunt (new area) | drop attack 55 studs (was 40) | drop hit refills a charge | on a tree top, other players' screens hide your badges / bars | drop hit stuns 0.5 s |

- Sprint Legs III text per dino:
  - T-Rex: "Ram and leap".
  - Raptor: "Pounce and leap".
  - Pachy: "Leap".
  - Herrera: "Climb 35% faster".

## Versions and switches
| Script | Version | Switch |
|---|---|---|
| SkillTree | 1.37 | HERRERA_STATS |
| Lab | 1.9 | LabNameForEnabled |
| SkillEffects | 1.26 | SkillEffectsHerreraEnabled |
| SlashServer | 1.3 | SlashSkillsEnabled |
| SprintTest | 1.13 | SprintFrenzyEnabled |
| TreeTopHide | 1.0 (new) | TreeTopHideEnabled |

## Do-not-touch
- The T-Rex, Raptor and Pachy effects (`effects(steps)` without a dino is unchanged for them).
- SkillServer saving.
- The slash request / hit checks.
- ClimbTest.
- CloakFX: TreeTopHide uses PlayerToHideFrom, not Enabled.

## Deterministic map
| State | Condition | Result |
|---|---|---|
| Lab row name | `nameFor[species]` set | that name; else `path.name` |
| Effects | Species "Herrera" | `effects(steps, "Herrera")` |
| Effects | any other dino | `effects(steps)` (unchanged) |
| Herrera stat writes | SkillEffectsEnabled false | bases written back, flags off |
| Slash hit | target already slash-bleeding | damage + SlashBleedBonus |
| Dive hit | SlashDiveRefill | +1 charge (once per dive) |
| Dive hit | SlashDiveStun > 0 and the target survives | StunnedUntil = max(current, now + stun) |
| Kill by slash | target was bleeding and SlashKillRefill | all charges |
| Kill by bleed tick | attacker's SlashKillRefill | all charges |
| Kill | target not bleeding | no refill |
| Frenzy | SlashFrenzyMul ≠ 1 and a slash-bleeding dino within range | SlashFrenzyUntil = now + 0.5 → SprintTest × mul |
| Tree-top hide | another player's dino with TreeTopHidden and ClimbState "top" | its BillboardGuis are hidden on this client |
| Tree-top hide | that dino leaves the top | restored |

## Studio check (2026-10-31)
- **Effect values:** test steps jaws 4 / stalker 4 / frenzy 4 / lifesteal 3 / legs 3 gave refill 2.6, charges 3, bleed 5/s for 6 s, dive range 55 studs, climb 13.5, slash 13.
- **Slash, Blood Drinker, Blood Frenzy:**
  - 13 hit → +2 HP;
  - bleed ticks of 5, each +0.75 HP;
  - Frenzy active next to the bleeding bot;
  - the second hit did 16.
- **Drop attack:** a dive at 47.5 studs was accepted, with refill 3 → 2 → 3 and the stun applied.
- **Kill refill:** a bleed-tick kill went 0 → full; a kill on a non-bleeding bot gave no refill.
- **Step reset:** when SkillServer reset the steps, every base was written back.
- **Not tested:** TreeTopHide with a second player (Kepu's rule). Its property and the gui locations were checked instead.

## Accepted limits
- Blood Frenzy I counts slash bleeds only. The Herrera has no other bleed.
- Future dinos get their own rows the same way: `nameFor` / `stepsFor` + `effects(steps, dino)`.
