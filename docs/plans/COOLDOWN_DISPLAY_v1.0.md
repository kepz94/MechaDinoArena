# Mecha Dino Arena v1.0 — Every cooldown on screen (PC + phone)

**Ask (Kepu 2026-11-06 02:37):** "I need all cool downs to be [shown] on screen cause I was playing using some dinos and I
could tell their cooldowns wasn't appearing."
**Audit (read-only, 2026-11-06):**
- PC (AbilityBar 1.31, non-touch only): the 6 Teno slot parts + the Teno Hydraulic Leap slot tile + all 7 Dilo parts have no
  `TIMED_PARTS` entry (AbilityBar:219-247), so they fall through to `paint(e, "ready")` (:893-894) and always say ready.
  Every other part and every own move already shows the fill + seconds.
- Phone: MechaButtons slot buttons show the sweep (`s.cd`, :1692) but blank the sub text (`s.sub.Text = ""`, :1630), so no
  seconds; ArenaTouch RAM / POUNCE / JUMP only dim (:24, :28) and BITE has no cooldown read.
**Picks (02:4x):** phone "Sweep + seconds"; T-Rex Roar "Leave Roar for now".

## Global constraints
- Additive; one switch per file; the existing looks reused exactly (PC: `paint(e, state, dim, frac, secs)` AbilityBar:715-730,
  the "Cooldown" fill + `"%.1fs"`; phone: the `s.cd` sweep and the PC seconds format).
- PC and phone ship together. Versions: AbilityBar 1.32, MechaButtons 1.37, ArenaTouch 1.17 (re-read live versions first).
- Install by multi_edit, hash verify, one-player Play test; publish only on "Publish".

## Do-not-touch
Every part / move server (the ready attributes already exist), the pips rows (headbutt, slash, slam, therizino hits, dart,
leap charges), the SILENCED tiles, the jets "2 / 3" text, RoarTest / the T-Rex Roar.

## Tasks (one ticket) — Dev Hub MDA-322
1. **AbilityBar 1.32** (Wired): `TIMED_PARTS` entries tgrab TenoGrab, tmortar TenoMortar, tstomp TenoStomp, tbellow
   TenoBellow, tchallenge TenoChallenge, tmud TenoMud, tleap TenoLeap; dgatling DiloPartGatling, dmortar DiloPartMortar,
   dhiss DiloPartHiss, dspine DiloPartSpine, dpump DiloPartPump, djets DiloPartJets, dover DiloPartOver (the existing
   :879-892 branch draws them). Spring Jets / Hydraulic Leap: fill + seconds to the next charge, charges in the tile's
   existing sub text. Switch `AbilityBarTenoDiloTimersEnabled`.
2. **MechaButtons 1.37** (Wired): while a slot part is cooling (partState frac > 0), `s.sub.Text` = seconds left
   (`"%.1fs"`); SILENCED and the jets "2 / 3" keep priority. Switch `MechaButtonsSecondsEnabled`.
3. **ArenaTouch 1.17** (Wired): RAM, POUNCE, JUMP and BITE get the slot sweep + seconds from `<Move>PredictedAt` /
   `<Move>StartedAt` + `<Move>Cooldown` (AbilityBar MOVES :260-270 as the source of truth) instead of only dimming; pips
   buttons unchanged. Switch `ArenaTouchMoveTimersEnabled`.

## Deterministic map
| State | Condition | PC tile | Phone button |
|---|---|---|---|
| off | part not enabled | as today ("off") | as today |
| active | `<P>Until` > now | as today ("active") | as today |
| cooling | `<P>ReadyAt` > now | fill = left / Cooldown, "3.2s" | sweep + "3.2s" |
| ready | otherwise | "ready" | full, no text |
| charges (jets, teno leap) | left < max | charges text + fill / seconds to next charge | "2 / 3" kept; sweep to next charge |
| silenced | `SilencedUntil` > now | SILENCED (wins) | SILENCED (wins) |

## Red-team (one paragraph, single-ticket change)
How it fails: (a) a wrong prefix leaves a tile stuck on ready again — mitigated by a Play check of all 14 tiles from their
ReadyAt stamps; (b) seconds text on the big phone ATTACK / JUMP buttons crowding the label — the seconds go in the existing
sub line, not over the main label; (c) BITE / JUMP cooldowns under 1 s flicker "0.4s" — shown like the PC (which already
does this). Phone seconds are checked by forcing the touch layout in Studio (device emulator) where possible; otherwise by
reading the drawn text in Play.

## Build notes (2026-11-06)
- Installed by multi_edit, hashes = repo (len/hash): AbilityBar 68552/912967003, MechaButtons 102575/414023073, ArenaTouch
  52892/613867675; all three compile (loadstring).
- Play test (one player; SkillServer saving off for the session; slots set only on the client copy of the player and
  restored on the server to the loaded values; ready attributes stamped on the character locally, so no part was bought):
  - PC, all 14 tiles: tgrab / tmortar / tstomp / tbellow / tchallenge / dgatling / dmortar / dhiss / dspine cooling with
    fill + seconds and back to ready; tmud and dpump / dover "active" with seconds during TenoMudUntil / DiloImmuneUntil /
    DiloOverdriveUntil; tleap "1 / 2" ready, then "0 / 2" cooling with seconds; djets "2 / 3". Pachy hookarm unchanged.
  - Phone (forced with the existing ArenaTouchForceTouch / MechaButtonsForceTouch test switches on the Play copies): POUNCE
    and JUMP sweep + seconds (diag "Pounce 1.7, Jump 1.5"), cleared at ready; slot buttons "3.5s" / "4.5s", cleared at ready;
    capture shows ATTACK "19.6s" with the dark fill rising and JUMP "14.6s".
  - Switches off: ArenaTouch (no fill / text), MechaButtons (no seconds; a stale "x.xs" is now cleared when switched off
    mid-countdown — fix found in the test), AbilityBar (teno tile back to always "ready"; hook still counts down).
  - Console errors 0.
- Deviations: Spring Jets / Hydraulic Leap show "left / max" while charges remain and fill + seconds only at 0 left (their
  ReadyAt only moves when the last charge is spent; no next-charge time exists without a server change). Bite / Ram not
  seen on the raptor (hidden there); same code path as POUNCE / JUMP.
- Not run: a real phone, the T-Rex BITE / RAM buttons, gamepad.
