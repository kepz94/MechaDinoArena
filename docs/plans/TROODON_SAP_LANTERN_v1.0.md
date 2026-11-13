# Mecha Dino Arena — Troodon Sap Wall charges + loud Arc Lantern v1.0

**Ask (Kepu 2026-11-13 15:08):** "I want the Troodon to be able to spit up to 2 sap walls out like that's the charges. Then for the arc lanterns I want the effects to show more electricity especially if it's bouncing on to other dinos, it needs to be visibly obvious that the Dino took the hit and got a debuff."

**Mockup:** docs/mockups/troodon_lantern_sap_v0.1.html. **Picks (15:2x):** "B · Shocked mark", Sap Wall "Yes, as shown" (2 charges at every rank, both walls can stand at once, the button shows 2 / 2, each charge refills on its own 18 s timer).

## Do-not-touch
Lantern damage (12), stun (1 s), range / chain / targets / cooldown; the Sap Wall size, time, height, placement and block rules; every other dino and part; PracticeKit bot timings.

## Tasks
1. **TrooMovesServer 1.12 — Sap Wall charges.** Script attribute `TrooMoves_sapCharges` (2). Character `TrooPartSapCharges` (max) and `TrooPartSapLeft`; each throw ("ok") uses one charge and starts its own refill `TrooPartSapCooldown` s later; `TrooPartSapReadyAt` = now while a charge is left, else the next refill (the Spring Jets pattern, DiloMovesServer). A wall not raised at the splat ("occupied") gives its charge back. Switch `TrooMovesSapChargesEnabled` (false = 1.11: one wall, one recharge).
2. **SkillTree 1.91 — text.** Sap Wall step 1 "Recharges in 18 s" -> "2 charges, each recharges in 18 s" (`TROO_SAP_CHARGES_TEXT`, miss counter).
3. **AbilityBar 1.41 + MechaButtons 1.46 — the button.** `CHARGE_ATTR.osapwall` = {TrooPartSapLeft, TrooPartSapCharges}: "2 / 2" in the sub text while a charge is left, the cooling fill + seconds at 0 (as Spring Jets). Touch slot: same "left / max" sub label, redrawn on change. Switches `AbilityBarSapChargesEnabled`, `MechaButtonsSapChargesEnabled`.
4. **TrooPartsFX 1.6 — loud lantern (B).** Switch `TrooPartsFX_lanternLoudEnabled` (false = 1.5).
   - Each chain zap: bolts x`lanternBoltMul` (2) wider, living `lanternBoltLife` (0.6 s), the bolt head travels to the dino over `lanternBoltTravel` (0.08 s), 3 forks off the bolt.
   - Each zapped dino: a white flash (Highlight, `lanternFlashTime` 0.12 s).
   - While the stun lasts (only when it really landed): a flickering electric-blue outline (Highlight, VOLT) and a "⚡ SHOCKED" tag over the head with a bar that drains to the stun's end. Removed when the stun ends or is broken.
5. **QA + docs + publish on Kepu's word.**

## Red-team (folded in)
- **Two walls can seal a lane / the point for 8 s at star.** Accepted (Kepu's ask); numbers are attributes (`TrooMoves_sapCharges`).
- **Bots:** PracticeKit throws the Sap Wall on its own 12 s timer, so bots don't double-throw faster than before. Unchanged.
- **Highlight cap (31 a player):** a lantern adds at most 3 at once (Night Watcher caps itself at 10). OK.
- **Immune targets (Feather Shed, Antivenom):** no stun -> white flash only, no SHOCKED tag (the tag only shows a debuff that's real).
- **The ⚡ glyph in Silkscreen:** check in Studio; fall back to "SHOCKED" alone if it doesn't draw.
