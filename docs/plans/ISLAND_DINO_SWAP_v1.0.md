# Mecha Dino Arena — Island dino swap v1.0

**Ask (Kepu 2026-11-15 10:53):** "when i load on to the main island there is no option at all to change dino, i have to leave all the way to the home screen to do so which is not optimal." 10:58: "this is for the main island not any game modes".
**Mockup:** docs/mockups/island_dino_swap_v0.1.html.
**Picks:**
- Where: "A · Dino button".
- When: "Any time" (no damage lockout; a swap gives a fresh body at full health).

## Today (code facts)
- Island HUD (Studio capture, kind "hub"):
  - SKILLS pill: Lab, ScreenGui LabButton, DeviceSafeInsets.
  - MENU pill: ArenaStatus.
  - SQUAD and the camera button.
  - On the phone (Phone HUD v2) these four sit in the ☰ drawer: [MENU][SKILLS] / [CAMERA][SQUAD].
- MENU → home screen (InMenu): ◀ ▶ swap there, then PLAY → ModeServer unparks and HubServer places you on the portal islet.
- `DinoSpeciesRequest` (SpeciesServer 1.9) swaps in place for every dino except the T-Rex. The new body is built at the old body's spot. The T-Rex goes through LoadCharacter and lands at the SpawnLocation. 2 s cooldown.
- **HubServer 1.5 places every new body on the islet** (CharacterAdded → 0.3 s → place). An island swap would therefore drop you at the portals.
- **PregameScreen (the SELECT screen) does not run on the hub.** It waits up to 60 s for ReplicatedStorage.Practice, which PracticeServer never makes on a hub server, then exits. It also waits 30 s each for PracticeRequest and PracticeShared.
- ShoulderCam locks the PC mouse every frame. PregameScreen never frees it, so in shoulder mode its buttons can't be clicked outside a menu. This also affects the respawn picker during the after-spawn window.

## Rules
1. **DINO pill (IslandDino 1.0, new, StarterPlayerScripts).**
   - Shown only on the island: ReplicatedStorage ServerKind == "hub", not InMenu, picker closed, alive.
   - Look: a copy of the SKILLS pill (PANEL rgb(20,20,26) at 0.18, white stroke 0.5 / 1.5, corner 10, 36 tall, FredokaOne 18 "DINO", padding 12).
   - PC: 8 px left of the leftmost of SKILLS / MENU on their row. Phone HUD v2: the same, but only while the ☰ drawer is open (it then sits left of MENU).
   - Tap → local player attribute IslandPickOpen = true.
2. **Picker (PregameScreen 1.5, island mode).**
   - On a hub server it no longer waits for match objects: a stand-in state folder, and no 30 s waits.
   - While IslandPickOpen it shows the SELECT screen: dino step, then parts step.
   - Texts: "ISLAND · PICK YOUR DINO" / "ISLAND · <DINO> · PICK 4 PARTS". The team strip and "TEAM NEEDS" labels are hidden. The clock is blank, with the note "SWAP WHERE YOU STAND".
   - SELECT on another dino → DinoSpeciesRequest (today's swap). Parts work as in the lobby.
   - CONFIRM or BACK on the dino step closes it.
   - The mouse is freed while it is open. The same applies to the respawn picker.
3. **Stay where you are (HubServer 1.6).**
   - A new body that replaces a live body that has been around at least HubSwapMinAge (1) s, out of the menu, is a swap. Bodies from deaths and the T-Rex step of a respawn don't count.
   - For a swap, the islet placement is skipped. If the new body is more than HubSwapKeepDist (6) studs from the old spot (the T-Rex, built by LoadCharacter), it is moved there: same ground height and facing, held by the server for HubPlaceHold (0.3) s.
4. **Scope.** Island (hub) only. Practice and Arena matches keep the respawn swap. MENU, the home screen and the death respawn on the island are unchanged.

## Tasks (MDA-543..545)
1. MDA-543 HubServer 1.6: rule 3.
2. MDA-544 PregameScreen 1.5: rule 2.
3. MDA-545 IslandDino 1.0 (new): rule 1.

## Do-not-touch
SpeciesServer swap and cooldown, the home screen, the Lab, PhoneMenu / drawer code, match flow (lineup, intro, respawn), the islet placement for joins / PLAY / deaths.

## Red-team (folded in)
- **"A death respawn could be kept at the old SpawnLocation."** After a death, Roblox makes a T-Rex and SpeciesServer swaps it at once. That T-Rex is under 1 s old, so the min-age rule treats it as a respawn and the dino still goes to the islet.
- **"Swap to heal in island PvP."** Accepted. Kepu picked "Any time". The 2 s server cooldown stays.
- **"PregameScreen behaving differently in matches."** The changes only apply when there is no Practice state and ServerKind is "hub", or while IslandPickOpen is set. Switch PregameIslandPickEnabled = false restores 1.4.
- **"The T-Rex lands in the air or inside something."** The old ground height is kept, the old spot was free a moment ago, and the move is server-held like HubServer 1.5's islet move.

## Build notes (2026-11-15)
- HubServer 1.6: the old body is already destroyed when the deferred CharacterAdded runs (Studio: no Humanoid, Parent nil). So each body's last live state (alive, root CFrame, ground height) is kept every Heartbeat, in a weak table keyed by character.
- IslandDino 1.0: pills inside a DeviceSafeInsets ScreenGui report negative AbsolutePosition Y. The "parked off-screen" test is measured from the pill's own ScreenGui top, not from 0.

## Studio test (2026-11-15)
**PC (island, kind "hub"):**
- DINO sits 8 px left of SKILLS, in the same style.
- Tapping it opens SELECT with "ISLAND · PICK YOUR DINO" in yellow, no team strip, and the note "SWAP WHERE YOU STAND".
- Raptor → Herrera: moved 0.6 studs, "kept swap", and the parts step listed Herrera's parts.
- → T-Rex: flat distance 0.0 from the old spot ("moved swap").
- A death as T-Rex, and a death as Raptor (with the T-Rex step), both respawned on the islet ("placed").

**Phone (iPhone 17 Pro emulation, phone HUD v2):**
- DINO is hidden with ☰ closed. With ☰ open it sits left of MENU.
- A tap opens the picker. Teno was picked and the parts step read "ISLAND · TENO · PICK 4 PARTS".
- CONFIRM LOADOUT closed it. Result: Teno, "kept swap".

**Regression (bots match, kind "practice"):**
- The lineup screen is unchanged and the DINO pill is hidden.
- The respawn picker is unchanged (match texts, team strip, clock), and the mouse is free (MouseBehavior Default).
