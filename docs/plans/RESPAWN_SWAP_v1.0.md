# Mecha Dino Arena — Respawn: swap dino + loadout v1.0

**Ask (Kepu 2026-11-13 21:18):** "the ability to change Dino and load out mid match. Maybe a 5 second respawn wait with the option to change Dino in that time and the few seconds after you spawn have the button stay there".
**Mockup:** docs/mockups/respawn_change_v0.1.html.
**Picks:**
- Respawn screen: "C · Death cam + button".
- If the timer runs out while you're still picking: "Wait for me".
- After you spawn, the button stays for "5 s or until you attack/get hit".

## Today (code facts)
- Respawn time: DinoHealthServer 1.0 sets the global Players.RespawnTime = 3. Roblox respawns the player as the T-Rex, then SpeciesServer swaps them to their DinoSpecies.
- Placement: PracticeServer places a match human on a spawn spot 0.6 s after CharacterAdded (placeHuman).
- Changing dino mid-match today: MENU, which leaves the match.
- Practice matches can run on public Sandbox servers that also have island players, so the global RespawnTime must stay 3. The 5 s wait is done per player by holding the new body out of the world.

## Rules
1. **Hold (RespawnServer 1.0, new + PracticeServer 1.13).** A player dies while in a match (PrInMatch, Practice PrPhase "match"):
   - Player attributes are set: `RespawnHold` = true, `RespawnDiedAt`, `RespawnAt` = died + RespawnWait (5), `RespawnPickOpen` = false.
   - Roblox still respawns at 3 s. PracticeServer 1.13 parks that body instead of placing it: HumanoidRootPart anchored at RespawnParkY (3000) studs up.
   - Release happens at `RespawnAt`, or while the picker is open, when it closes; at the latest at died + 5 + RespawnPickMax (10). The new body must be alive and be the wanted species.
   - On release: `RespawnHold` = false, the body is unanchored and placed (placeHuman), and `RespawnGraceUntil` = placement + RespawnGrace (5).
   - The match ending, leaving the match, or the switch going off releases or clears everything.
2. **Death cam (RespawnScreen 1.0, new, client).** While `RespawnHold` is on:
   - The camera follows the killer, taken from the dead body's KilledByUserId (a player) or KilledBy (a bot model "PBot_<name>" / that name). The view is 18 studs behind and 8 up. Without a killer, it looks down at where you died.
   - A tag above them reads "<NAME> · <DINO> · <hp> HP".
   - Top centre: "ELIMINATED BY <NAME>" plus a ring counting down to "RESPAWN IN n".
   - Bottom centre: a yellow "CHANGE DINO / LOADOUT" button, also opened with the B key on PC.
   - The mouse is free while held. ShoulderCam stands aside through ShoulderCamExternal.
3. **Picker (PregameScreen 1.4).** RespawnRequest("open") sets `RespawnPickOpen`.
   - The pre-game SELECT screen shows over the game: the dino step, then the parts step.
   - The top-bar clock shows the respawn countdown, reading "WAITING FOR YOU" once past `RespawnAt`.
   - SELECT on a dino sends RespawnRequest("dino", id) instead of DinoSpeciesRequest.
   - The parts step works as in the lobby (SkillRequest "slot"). Parts can be changed once the body is that dino.
   - Confirm / READY sends RespawnRequest("ready"). BACK on the dino step sends "close". Both close the picker.
4. **Swap while held.** RespawnServer sets DinoSpecies.
   - If the parked body is already alive and is another dino, it calls LoadCharacter: T-Rex, then SpeciesServer swaps it, and it is parked again.
   - If the player is still dead, nothing more happens: the Roblox respawn plus SpeciesServer do it.
   - SpeciesServer 1.9 remembers DinoSpecies changes (saved like today's last dino).
5. **After spawn (RespawnScreen + RespawnServer).** While `RespawnGraceUntil` > now:
   - A yellow pill sits under the score strip / compass: a ring + "CHANGE", with "ENDS IF YOU ATTACK" under it. Tapping it or pressing B opens the picker.
   - A dino swap ends the grace and puts the player back on hold at once (RespawnAt = now, cap now + 10 s, player `RespawnFromGrace` = true so no death screen shows). The new body (LoadCharacter → SpeciesServer swap) is parked while the picker stays on its parts step; confirming places it on a spawn spot as the new dino at full health. No second window. (Build change: the first build closed the picker on the swap, which skipped the loadout step.)
   - The window ending any way (hit, attack, time) while not on hold closes the picker.
   - The grace ends on: any health loss (server); an attack press reported by the client, RespawnRequest("attacked") (LMB, R / C / T / V / E / Q / F / Space on PC; a touch that starts on ATTACK / JUMP / a part button on the phone); a swap; or 5 s.
6. **Scope.** Players in a match only (practice and Arena; PracticeServer runs both). The island keeps the 3 s respawn. Bots are unchanged.

## Tasks (MDA-537..541)
1. MDA-537 RespawnServer 1.0 (new): rules 1, 4, 5 (server side), remote RespawnRequest.
2. MDA-538 PracticeServer 1.13: park while RespawnHold, place on release.
3. MDA-539 SpeciesServer 1.9: remember DinoSpecies changes.
4. MDA-540 RespawnScreen 1.0 (new): rules 2, 5 (client side).
5. MDA-541 PregameScreen 1.4: rule 3.

## Do-not-touch
Island respawn (3 s), bots, the prematch hold, SkillServer, the lobby / intro flow, Hardpoint scoring.

## Red-team (folded in)
- **Healing by swapping mid-fight.** Any damage taken ends the grace, as does an attack press, and the swap puts you back at a spawn spot.
- **An AFK player sitting in the picker forever.** The hold is capped at died + 15 s.
- **The global RespawnTime affecting island players.** It isn't changed. The hold is per player.
- **Parked bodies being seen or hit.** They are 3000 studs up and anchored. Bots path on the ground.
- **A missed attack not ending the grace when the client report is dropped.** The worst case is a swap at the spawn spot within 5 s. Accepted.

## Build notes (2026-11-13)
- Camera hand-back (RespawnScreen 1.0): the default camera adopted the death cam's angle and distance after release (high, far view). Once the body is off the park, the camera is now put 12 studs behind / 5 up from it before CameraType goes back to Custom.
- The killer tag is kept below the countdown ring (top y + 104 px). On the phone HUD the top text starts at y 80 (64 on PC), clear of the score strip. Key hints ("OR PRESS B", "B ·") show only without touch.

## Studio test (2026-11-13, practice match vs bots)
- PC: death → hold 5.0 s → placed, window 5 s. Body parked at y 3000, anchored, while held. Death cam on PBot_Ivy, "ELIMINATED BY IVY", tag "IVY · HERRERA · 90 HP", ring counting. B opened the picker ("0:05 / RESPAWN IN" → "WAIT / WAITING FOR YOU"). Raptor picked → parked body swapped to Raptor (dino:Raptor), parts step listed Raptor parts, CONFIRM LOADOUT → spawned as Raptor with the CHANGE pill. LMB in the window → graceEnd:attack. CHANGE pill → T-Rex → T-Rex 200/200 at a spawn spot (first build). Camera behind the body after release (fix verified).
- Phone (iPhone 17 Pro emulation, phone HUD v2): dead view clear of the strip, no key hint, CHANGE DINO / LOADOUT opened the picker; Pachy picked → spawned as Pachy, pill "CHANGE n" under the strip. Tap on ATTACK (touch) → graceEnd:attack. 5 HP hit with the picker open → graceEnd:hit and the picker closed. Window swap Pachy → Raptor → hold (RespawnFromGrace, parked, picker open) → ready → placed as Raptor, no window, no death-screen flash. Death cam followed PBot_Lumen with the tag under the ring.
