# Mecha Dino Arena — Phone HUD v2 "Clean corners, your buttons" v1.0

**Ask (Kepu 2026-11-13 20:12):** "let's look at the phone layout and how other games do it. I want you to really consider all the space being taken up on the phone screen and how it can be optimized".
**Pick (20:2x):** "I like option A but keep the current button style that we use with the tap/swipe buttons". The mockup tab is "A · your version".
**Mockup:** docs/mockups/phone_hud_v0.1.html. It contains a Studio capture and measured boxes on an iPhone 17 Pro emulation (750 × 381), and research from Fortnite, CoD Mobile, Roblox and Brawl Stars.
**Goal:** the HUD covers 37% → 25% of the screen, and 10 → 5 game buttons are showing. Phone only; PC is unchanged.

## Global constraints
- Every change applies only while the player attribute `PhoneHudV2` is true. PhoneMenu 1.0 sets it: true on a touch device (TouchEnabled, or the character's ArenaTouchState "on" = the ArenaTouchForceTouch Studio hook) while its script attribute `PhoneHudV2Enabled` is not false.
- One switch (`PhoneHudV2Enabled` = false) puts every phone piece back exactly as it is today.
- Additive changes only, every number an attribute, version-branded, hash-checked installs.

## Rules
1. **☰ button (PhoneMenu 1.0, new, StarterPlayerScripts).**
   - Look and spot: a 44 × 36 pill at (1, −16, 0, 8) with DeviceSafeInsets, where MENU sits today. Panel rgb(13,18,24) at 0.18, yellow stroke, yellow "☰".
   - Tap: toggles the player attribute `PhoneMenuOpen`.
   - Closing: any touch that ends outside the ☰ closes the drawer 0.15 s later. A drawer button's own tap goes through first.
   - Badge: a yellow dot shows on ☰ while the SKILLS badge is showing (unspent points).
   - Drawer spots (`PhoneMenuY_Skills` 50, `PhoneMenuY_Menu` 50) are published as player attributes.
2. **Drawer (Lab 1.17, ArenaStatus 1.9).**
   - While `PhoneHudV2` is on, a late render step places the SKILLS pill and the MENU pill:
     - drawer open: at (1, −16, 0, y);
     - drawer closed: 400 px above the screen (not drawn, not tappable).
   - MENU goes left of SKILLS. SQUAD already sits under SKILLS (SquadHUD) and the camera button already sits under MENU (CameraModes), so both follow on their own. The open drawer is a 2 × 2 block, [MENU][SKILLS] / [CAMERA][SQUAD], that stays above JUMP. The Studio test showed a single column covering JUMP, which is why it changed.
3. **Health (ArenaStatus 1.9).**
   - BarsBL moves to the top-left: AnchorPoint (0, 0) at (0, 16, 0, Roblox top-bar bottom + 6), 160 px wide (`ArenaPhoneBarsWidth`).
   - The look and contents (health, shield, blood, stamina) are unchanged.
4. **Score strip (HardpointHUD 1.13).** The compass stays (picks 2026-11-10 "Compass bar", 2026-11-11 "fit in that space"). While `PhoneHudV2` is on:
   - the score card, Status pill and Next pill are hidden;
   - a blue box (your score) sits just left of the compass and a red box (their score) just right of it, each 40 wide and as tall as the compass plus its under line;
   - a line under the compass row reads `P<n> · <time> · <status>` (status texts and colours as the Status pill; warm-up "P1 IN <time> · GET READY"; NEXT when shown);
   - the compass's right limit also stops 12 px left of ☰.
5. **Kill feed (KillFeed 1.2).** Lines move to the top-right, right-aligned, top at the ☰ bottom + 6 (y 50). The phone rules stay: 3 lines, 4 s, banner.
6. **Move stick (PhoneLayoutServer 1.0, new, ServerScriptService).**
   - Every player's `DevTouchMovementMode` = DynamicThumbstick: the stick appears where the thumb lands on the left side.
   - Switch: `PhoneDynamicStickEnabled`. Off (or switched off later) = the player keeps / gets back UserChoice.
7. **Right-hand buttons:** unchanged (ATTACK, JUMP, the two square tap / swipe part buttons). Kepu's pick.

## Tasks (MDA-532..536)
1. MDA-532 PhoneMenu 1.0 (new): rule 1.
2. MDA-533 Lab 1.17 + ArenaStatus 1.9: rules 2–3.
3. MDA-534 HardpointHUD 1.13: rule 4.
4. MDA-535 KillFeed 1.2: rule 5.
5. MDA-536 PhoneLayoutServer 1.0 (new): rule 6.

## Do-not-touch
- PC HUD.
- ArenaTouch / MechaButtons (right-hand buttons).
- SquadHUD and CameraModes code (they follow SKILLS / MENU).
- The compass's drawing.
- The 3D P1 marker.
- The countdown, pre-game and cruise screens.

## Red-team (folded in)
- **Removing the compass would undo 2 earlier picks.** The strip is built around the compass instead of replacing it.
- **Health was moved bottom-left at Kepu's ask (2026-10-29).** The A mockup showed it moving top-left and Kepu picked A, so this is accepted. The switch brings back the bottom-left bar.
- **Unspent skill points could go unnoticed with SKILLS tucked away.** The yellow dot on ☰ covers this.
- **Overriding other scripts' positions could fight their own loops.** The override runs in a render step after everything else (Last + 40) and only while `PhoneHudV2` is on.
- **A dynamic stick changes how moving feels.** This is Kepu's pick (A). The switch reverts it.
