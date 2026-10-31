-- MechaButtons v1.22 (Mecha Dino Arena) — the 2 mecha loadout buttons (touch), PC keys 1 / 2, and the Thrusters dash on the
-- owner's client. MDA-28, plan docs/plans/MECHA_THRUSTERS_v1.0.md Task 6, mockup docs/mockups/mecha_thrusters_options.html
-- option A "Thumb arc" (Kepu 2026-10-28).
-- Slots: player attributes SkillSlot1 / SkillSlot2 (SkillServer 1.1; path id or ""). A press on a slot holding "thrusters"
--   fires ReplicatedStorage.DinoDashRequest:FireServer(server time) (MechaServer 1.0 gates it). An empty slot does nothing.
-- Touch (UserInputService.TouchEnabled): ScreenGui "MechaButtons" (DisplayOrder 5), buttons Slot_1 / Slot_2, AnchorPoint
--   (1, 1), position and size in fractions of the screen like ArenaTouch 1.2:
--     AutoRun true  (RUN hidden):  Slot_1 right 21%, bottom 8%;   Slot_2 right 32.5%, bottom 18%; 9.5% of the width
--     AutoRun false (RUN shown):   Slot_1 right 33%, bottom 8%;   Slot_2 right 33%, bottom 28%;   9.5% of the width
--   Look: rounded square (corner 22%), panel (20, 20, 26) at 0.3, 2.5 px Engineer-orange (255, 155, 46) stroke.
--   Full slot: "DASH", charge pips top right (DashChargesLeft of DashCharges), a dark fill from the bottom showing the time
--   to the next charge (DashNextChargeAt, DashRecharge), key hint "1" / "2" (v1.1: "R" / "C", empty on touch); dimmed
--   (0.5) while DashEnabled is not true.
--   Empty slot: white stroke at 0.5, "+" and "slot n".
-- PC / no touch: no buttons; keys 1 and 2 (v1.1: R and C) press slot 1 and 2 (when the key is not used by a text box). Test hook: script
--   attribute MechaButtonsForceTouch (default nil / false) = true draws the touch buttons without touch (layout checks).
-- Dash physics (this client owns the character): on a new DashStartedAt, a LinearVelocity on the HumanoidRootPart
--   (VelocityConstraintMode Plane, world X / Z) at DashDistance / DashTime studs/s along the flat look direction, for
--   DashTime s; with DashHop > 0 the root also gets an upward speed sqrt(2 x gravity x DashHop) and the Humanoid is put in
--   Freefall. At the end the root's horizontal speed is set to 0 (keeps its vertical speed), so the dino stops where the
--   dash ends instead of sliding on.
-- Diagnostics (character attributes, this client): MechaButtonsVersion, MechaButtonsState ("on" touch / "keys"),
--   MechaButtonsLastPress ("slot1:thrusters" / "slot2:empty" ...), MechaDashLocal ("idle" / "dashing"), MechaDashLocalCount.
-- v1.1 (MDA-33; Kepu 2026-10-28 after trying it on PC: "what the hell was that ... make the thrusters actually last longer",
--   "1.5 s boost, steerable"; keys "shouldnt be the number 1 button ... assign it to Q or e or something" -> "R / C";
--   "make it visible on pc what ability you have gained" -> "New ability" popup):
--   * Keys: R = slot 1, C = slot 2 (RoarTest R / CreepTest C are off in Mecha, ArenaScope 1.2+); 1 / 2 no longer do
--     anything. Key hints on the buttons show R / C (empty on real touch devices).
--   * Boost: when the character has DashSpeedMul (SkillEffects 1.2), a new DashStartedAt starts a boost for DashTime s
--     (1.5 s; 2 s from III) at DashSpeedMul (2) x the run speed (max of MoveRunSpeed and Humanoid.WalkSpeed). Steerable:
--     every frame the direction is the Humanoid's MoveDirection (flat) while you move, else the last direction (first:
--     where the dino faces). The star hop works as in 1.0 (at the start). It ends early on death, a stun (StunnedUntil in
--     the future) or a pounce latch (PounceLatched). At the end the horizontal speed is set to 0 as in 1.0. Without
--     DashSpeedMul the 1.0 dash (DashDistance / DashTime straight ahead) is used.
--   * Popup (PC and touch): ScreenGui "MechaNews" (DisplayOrder 25, above the skill screen), top centre, 4 s: "⚙ NEW:
--     <PART NAME>" and "Press R to use it" / "Press C to use it" (PC) / "Tap its button to use it" (touch) / "Put it in a
--     LOADOUT slot (SKILLS)" when it is not in a slot. Shown when a loadout part's SkillPath_<id> goes from 0 to 1 or more
--     while this character exists (SkillTree.BUTTONS from ReplicatedStorage.SkillShared; not on join / respawn).
--     Diagnostics MechaNewsShown (path id), MechaBoostDir ("move" / "keep").
-- v1.2 (MDA-35; Kepu: "its an arcade game. i want these boosts to feel significant" -> camera punch, speed lines):
--   during a boost (this client) an envelope k goes 0 -> 1 in 0.15 s, stays 1 while boosting and goes back to 0 in 0.3 s
--   after it ends:
--   * camera punch: RenderStep "MechaBoostCam" at Camera priority + 2 (after ShoulderCam 1.5 and SkillScreen's mouse
--     bind): Camera.FieldOfView = the FOV at boost start + 15 x k, and a small shake (pitch / yaw up to 0.6 degrees x k,
--     from math.noise); the start FOV is put back and the bind removed when k is 0 again;
--   * speed lines: ScreenGui "MechaSpeedLines" (DisplayOrder 4) with 40 white streaks (100-220 x 4 px) flying outward
--     from around the middle of the screen toward the edges, transparency 1 - 0.65 x k (hidden at k 0).
--   Script attribute MechaBoostFxEnabled (default true; false = no punch and no lines). Diagnostic MechaBoostFx (k, 0.1).
-- v1.3 (air pounce, PounceTest 1.4): a boost also ends when this character starts a pounce (PounceLocalState "windup" or
--   "lunge"), so the boost's LinearVelocity (MaxForce infinite) does not hold the lunge back; the boost's end sets the
--   horizontal speed to 0 during the 0.1 s wind-up, then the lunge sets its own speed. Script attribute
--   MechaBoostPounceEnds (default true; false = 1.2 behaviour). Diagnostic (character): MechaBoostEnd ("pounce").
-- v1.4 (4 slots + Cloak, MDA-53, plans docs/plans/LOADOUT4_v1.0.md Task 2 + docs/plans/CLOAK_v1.0.md Task 5; Kepu
--   2026-10-29: eFootball-style tap-and-pull, look A "Sub-label", fire on release, PC T / V):
--   * Slots 1-4 (SkillSlot1..4, SkillTree 1.5 SLOTS 4): PC keys R / C / T / V press slots 1 / 2 / 3 / 4.
--   * Touch: button n (1, 2) holds a tap part (slot n) and a pull part (slot n + 2).
--       pull slot empty (or MechaButtonsPullEnabled false): presses slot n on InputBegan, as 1.3;
--       pull slot set: InputBegan keeps the start Y; the touch is "pulling" once it is >= PULL_PX below the start
--         (PULL_PX = clamp(0.22 x button height, 14, 24) px; tracked through UserInputService so it keeps working below the
--         button); while pulling the stroke is white 4 px and the pull label white; InputEnded presses slot n + 2 when
--         pulling, else slot n (fire on release).
--   * Pull label ("Pull"): "▼ NAME" along the bottom (y 0.78, 0.16 of the button), rgb(255, 217, 168), 0.5 while that
--     part is not ready; hidden when the pull slot is empty (the empty button's "slot n" text is then hidden too).
--   * Cloak (CloakServer 1.0): a press on a slot holding "cloak" fires ReplicatedStorage.DinoCloakRequest:FireServer(server
--     time). The button shows "CLOAK", ready while CloakEnabled is true, CloakedUntil <= now and now >= CloakReadyAt
--     (else 0.5); the dark fill is the cooldown left (CloakReadyAt - now) / CloakCooldown. No pips.
--   * NEW popup: looks up slots 1-4: "Press R / C / T / V to use it" (PC), "Tap its button" (slot 1 / 2) or "Tap and pull
--     down its button" (slot 3 / 4) (touch).
--   * Toggle: script attribute MechaButtonsPullEnabled (default true; false = 1.3 touch behaviour, slots 3 / 4 by T / V
--     only). Diagnostics: MechaButtonsLastPress "slot3:..." / "slot4:...", MechaButtonsLastGesture ("tap" / "pull" /
--     "press" = fired on InputBegan), MechaButtonsPullPx.
-- v1.5 (raptor parts batch 1, MDA-65, plan docs/plans/RAPTOR_PARTS_B1_v1.0.md Task 8): two more button parts, handled
--   like Cloak through TIMED_PARTS (part id -> attribute prefix, remote): "adrenaline" -> "Adrenaline",
--   DinoAdrenalineRequest (AdrenalineServer 1.0); "shield" -> "EnergyShield", DinoEnergyShieldRequest
--   (EnergyShieldServer 1.0). A press fires the remote with the server time. Ready while <Prefix>Enabled is true,
--   <Prefix>Until <= now and now >= <Prefix>ReadyAt (else 0.5); the dark fill is the cooldown left / <Prefix>Cooldown.
--   Button names "ADRENALINE" / "SHIELD". Thrusters / Cloak unchanged.
-- v1.6 (Kepu 2026-10-29: "if you jump and press the thruster it should boost you straight up unless you move the analog
--   forward. It would allow for more creative gameplay to get out of sticky situations" -> "About 30 studs", "Any
--   direction"): a Thrusters boost that starts in the air (Humanoid.FloorMaterial == Air) with no move input
--   (MoveDirection flat length < 0.1) goes straight up instead: a LinearVelocity (Vector mode, world) of
--   (0, MechaAirUpHeight / MechaAirUpTime, 0) for MechaAirUpTime s (script attributes, defaults 30 studs / 0.6 s), no
--   steering, no star hop; at the end the vertical speed is set to 0 so the rise peaks there and gravity takes over. Any
--   stick / key direction in the air gives the normal boost that way. Script attribute MechaAirUpEnabled (default
--   true). Diagnostics: character MechaBoostMode ("ground" / "air" / "up"), MechaAirUpCount.
--   v1.6 hover (Kepu: "just hit it and stay until the boost ends then drop"): after the MechaAirUpTime rise the
--   LinearVelocity holds (0, 0, 0) until DashTime ends (the whole boost), then it is removed and gravity takes over.
--   Diagnostic: MechaAirUpPhase ("rise" / "hover" / "done").
-- v1.7 (Kepu 2026-10-29, after v70: "I just jumped and pressed dash then tried to move forward but it didn't really push
--   forward once it hit the height ceiling"; 1.6 had no steering on the straight-up boost): during the straight-up
--   boost the stick / keys now steer it like the normal boost: with move input the sideways speed is the boost speed
--   (DashSpeedMul x run speed) in the move direction, without it 0; the up speed keeps the rise / hover profile, so the
--   height is held while flying until the boost ends, then the drop. MechaBoostDir "move" / "keep" as on the ground.
-- v1.8 (raptor parts batch 2, MDA-74 / MDA-75, plan docs/plans/RAPTOR_PARTS_B2_v1.0.md Tasks 6-7):
--   * TIMED_PARTS += scent ("Scent", DinoScentRequest, "SCENT"; ScentServer 1.0) and screech ("Screech",
--     DinoScreechRequest, "SCREECH"; ScreechServer 1.0). Scent is a normal press.
--   * Raptor Screech is hold-to-aim (Kepu: "it needs to be aimed" -> C "Hold to aim"): pressing its slot starts the aim;
--     an aim line "ScreechAim" (client-only red neon beam at the raptor's root height, where the bolt flies, along its
--     facing, with a Highlight that shows through grass and rocks)
--     grows from 0 to ScreechRange over AIM_TIME (1) s and stays at the max while held; letting go fires
--     DinoScreechRequest(server time, held range). PC: key down / key up (R / C / T / V). Touch: the slot's button
--     down / up; with a pull part on the same button, the aim follows the gesture: it aims the tap slot until the
--     touch counts as a pull, then the pull slot (if that is Screech), and the release fires the one aimed. Dying,
--     the character leaving or Screech leaving the slot cancels the aim.
--     Diagnostics: MechaScreechAim ("idle" / "aiming"), MechaScreechHeld (last held range, studs), MechaScreechFired.
--   * Jam (MDA-74): a new PartsJammedAt during a boost ends it (MechaBoostEnd "jammed").
-- v1.9 (Kepu: Raptor Screech renamed "Shock Dart"): its button reads "SHOCK DART". Nothing else changed.
-- v1.10 (Kepu after v80: Shock Cannon, "Always full range"): its button reads "SHOCK CANNON"; while the character
--   attribute ScreechFullRange is true (ScreechServer 1.2 Shock Cannon mode) the aim line is full ScreechRange at once and
--   the release sends the full range (a quick press used to fire ~8 studs because the line grew over 1 s).
-- v1.11 (raptor traps, MDA-80): TIMED_PARTS += traps ("Mine", DinoMineRequest, "SHOCK MINE"; MineServer 1.0), a normal press.
-- v1.12 (Shock Cannon thumb aim, Kepu 2026-10-30: "for shock cannon when you hold it down and the laser shows you can manually aim the laser and when you release it shoots ... on mobile it's hard to move the camera with your thumb already down" -> "I want to hold, once laser shows up I can just keep dragging without lifting my finger to aim"; "Yes, snap to face it"):
--   on touch, the finger that holds a Shock Cannon button also aims it. The aim locks AIM_LOCK (0.25) s after the aim
--   starts (or at once when the finger moves sideways / up more than AIM_DEAD (14) px); before that a quick drag down is
--   still the pull to slot 3 / 4 as before. Once locked, the pull-down is off for that touch and the finger's offset from
--   where the aim started works like a small joystick: within AIM_DEAD px = straight ahead (the raptor's facing, as
--   before); farther = the flat direction camera-right x dx + camera-forward x (-dy) (up = ahead of the camera, down =
--   behind, all the way round). The red aim line follows that direction. Letting go fires there: DinoScreechRequest gets
--   a 3rd argument, the aim direction (ScreechServer 1.7), and when the finger had aimed, the raptor snaps to face it
--   (HumanoidRootPart turned on this client, the owner) and the camera turns the same way (ShoulderCamLookAt). PC keys
--   are unchanged (aim with the camera; no direction sent). Script attribute MechaThumbAimEnabled (default true; false =
--   1.11). Diagnostics: MechaScreechAimMode ("ahead" / "thumb"), MechaScreechAimDeg (degrees from the facing).
-- v1.13 (Kepu 2026-10-30 after the v126 test: "The laser on the cannon with the touch thing is way too sensitive ... it
--   should be able to aim up and down too not just side to side. It should feel smooth nothing jerky you don't need to be
--   able to aim 90 degrees from you just what's in front of you"; cone size: no preference -> +/-30 sides, +/-15 up/down):
--   with script attribute MechaAimConeEnabled (default true; false = 1.12) the thumb aim is a cone in front of the raptor:
--   * stick -> target angles, per axis: offset beyond AIM_DEAD (14) px, divided by AIM_FULL_PX (110) px, clamped to 1:
--     sideways = yaw up to CONE_YAW (30) degrees left / right of the raptor's facing; finger up = aim up, finger down =
--     aim down, up to CONE_PITCH (15) degrees. Before the aim locks (and inside the dead zone) the target is straight ahead.
--   * smooth: the shown yaw / pitch ease toward the target (1 - e^(-AIM_SMOOTH (14) x dt) per frame), no jumps.
--   * the red line starts where the shot leaves (the cannon's ShockMuzzle when the cannon model has one, else 4 studs
--     ahead of the root, as ScreechServer) and runs along the aimed direction, cut short where it meets something solid
--     (ray, CanCollide parts, own character excluded).
--   * the direction sent on release is the shown one (3D, with the pitch; ScreechServer 1.8 uses the pitch) when it is
--     more than SEND_EPS (0.01 rad) off the facing, else none (= the facing, as before). The snap-to-face turns the raptor
--     to the flat part only (no tilt); the camera follows that flat direction.
--   PC keys are unchanged. Diagnostics: MechaScreechAimDeg (signed yaw, degrees, + = right), MechaScreechAimPitch
--   (degrees, + = up), MechaScreechAimMode ("ahead" / "thumb").
-- v1.22 (Kepu 2026-10-30: "when I click tether spike it changes the camera angle where I only aim as I'm strafe walking. It
--   shows like a launcher pov where I can properly aim. Just like dedicated aiming" -> mockup
--   docs/mockups/pachy_tether_aim_options.html B "Top-down tactical"; fire: tap Tether again; cancel: CANCEL button +
--   timeout; move: strafe at walk speed). With script attribute MechaTetherAimMode (default true, read at each press;
--   false = 1.21 hold-to-aim) the Tether Spike no longer uses hold-to-aim:
--   * press (key or button, tap) while the tether is ready (TetherEnabled, TetherReadyAt passed) = enter aim mode; press
--     again (or PC left click) = fire DinoTetherRequest(stamp, circle centre) and leave; CANCEL button / right click / Q
--     = leave without firing; TAC_TIMEOUT (6) s = leave without firing; death / respawn / the part leaving the slot =
--     leave. A press while cooling does nothing (MechaTetherAimEnd "cooldown").
--   * camera: RenderStep "TetherTacCam" (Camera + 10): Scriptable, high above (TAC_HEIGHT 85 studs) and TAC_BACK (28)
--     behind a point TAC_AHEAD (35) studs ahead of the pachy, looking down at it; the yaw is fixed at the moment you
--     enter (forward = up on screen) and it follows the pachy's position. ShoulderCamEnabled and TurnLimitEnabled are set
--     false while aiming (put back as they were after), the mouse is free and shown.
--   * circle: "TetherAim" (as 1.20) starting TAC_START (40) studs ahead; PC: under the mouse cursor (ray on the ground,
--     trees / rocks / grass / dinos skipped); touch: a drag that starts on the right 60% of the screen (not on a button)
--     moves it TAC_DRAG (0.18) studs per pixel. Kept 6 .. TetherRange studs from the pachy, snapped onto the ground
--     (same skip list). A neon line "TetherAimLine" runs from the pachy to it.
--   * the pachy turns to face the circle every frame (AutoRotate off) and moves with the normal controls relative to the
--     fixed camera, so it strafes; SprintTest 1.11 keeps it at walk speed while the character attribute TetherAiming is
--     true.
--   * HUD: ScreenGui "TetherAimHud" (DisplayOrder 7): "TETHER AIM - tap TETHER to fire" (PC: "click or TETHER key to
--     fire") tag at the top centre, the seconds left under it, and a CANCEL button under that.
--   Diagnostics: MechaTetherAim ("tactical" / "idle"), MechaTetherAimEnd ("fired" / "cancel" / "timeout" / "gone" /
--   "cooldown"), MechaTetherAimDist, MechaTetherFired. Character attribute TetherAiming (true while in aim mode).
-- v1.21 (Kepu 2026-10-30 after playing v205: "that was so wonky trying to aim that ... It was locking onto the top of trees
--   too and everything" -> "Camera tilt = distance"): with script attribute MechaTetherTiltAim (default true, read each
--   frame; false = 1.20 crosshair ray) the landing circle no longer follows what the screen's centre ray hits. Instead:
--   direction = the camera's flat facing; distance = TetherRange x clamp((pitch - TILT_NEAR) / (TILT_FAR - TILT_NEAR), 0,
--   1), floored at TILT_MIN_DIST (6) studs, pitch = the camera's up/down angle (TILT_NEAR -45 degrees = closest, TILT_FAR
--   -5 degrees or higher = full range). The ground under it is found with a ray from 80 studs up that skips
--   DinoIsland.Trees / Rocks / TallGrass / Bots / EdgeWalls, every character and the FX folders, so the circle always sits
--   on the ground or the mountain steps. The touch drag after the aim locks (1.20) is unchanged and still moves it.
-- v1.20 (pachy Tether Spike, MDA-129, TetherServer 1.0; Kepu 2026-10-30: "It will launch like a splash ... a splash area that
--   you're aiming at" -> "Hold, circle, release"): TIMED_PARTS.tether = {"Tether", "DinoTetherRequest", "TETHER SPIKE"}
--   and the tether uses the Shock Cannon's hold-to-aim plumbing (PC key down / up, touch press / drag / release, the
--   pull gesture) with its own aim: a client-only landing circle "TetherAim" (flat neon yellow disc, TetherSplash x 2
--   studs across, Highlight outline always on top) on the ground. Where it sits: the ground point under the screen's
--   centre (camera ray), at most TetherRange studs (flat) from the pachy; on touch, once the aim locks (as 1.12), the
--   finger's offset moves it: direction = camera-right x dx + camera-forward x (-dy), distance = TetherRange x
--   clamp((|offset| - AIM_DEAD) / (AIM_FULL_PX x 1.6), 0, 1). It eases toward the target (AIM_SMOOTH). Letting go fires
--   DinoTetherRequest(server time, circle centre). Diagnostics: MechaTetherAim ("idle" / "aiming"), MechaTetherAimDist
--   (studs, flat), MechaTetherFired. Switch: script attribute MechaButtonsTetherEnabled (default true, read at start;
--   false = 1.19, no tether entry).
-- v1.19 (pachy parts batch 3, MDA-126..128, plan docs/plans/PACHY_PARTS_B3_v1.0.md): TIMED_PARTS += servodash
--   {"ServoDash", "DinoServoDashRequest", "SERVO DASH"}, visor {"Visor", "DinoVisorRequest", "DOME VISOR"} and ink {"Ink",
--   "DinoInkRequest", "INK SHOOTER"}. Ink fires along the camera look like the Grappling Hook: DinoInkRequest(stamp,
--   camera LookVector). Switch: script attribute MechaButtonsBatch3Enabled (default true, read at start; false = 1.18).
-- v1.18 (pachy Med-Station, MDA-125, plan docs/plans/PACHY_MEDSTATION_v1.0.md): TIMED_PARTS.medstation = {"Med",
--   "DinoMedRequest", "MED-STATION"}: a slotted Med-Station button reads "MED-STATION", is lit while MedEnabled and
--   MedReadyAt has passed (cooldown sweep from MedCooldown) and a press fires DinoMedRequest(stamp) (MedStationServer 1.0).
--   Switch: script attribute MechaButtonsMedEnabled (default true, read at start; false = 1.17, no entry).
-- v1.17 (pachy Blood Rush, MDA-124): a slotted "bloodrush" button reads "BLOOD RUSH" and is lit while a sacrifice can
--   be made now (BloodRushEnabled, HeadbuttChargesNow 0, health above half, HeadbuttSacrifices < BloodRushMax); pressing
--   it does nothing (ATTACK fires it). Switch: script attribute MechaButtonsBloodEnabled (default true).
-- v1.16 (Kepu 2026-10-30: "mecha legs should take up an ability slot ... it's through the jump button"; SkillTree 1.23):
--   a slotted "mechalegs" button reads "MECHA LEGS" and shows the leap's readiness (MechaLegsEnabled and the leap off
--   cooldown: JumpPredictedAt + JumpCooldown) with the cooldown sweep. Pressing it does nothing (the jump fires it);
--   MechaButtonsLastPress still records the press. Switch: script attribute MechaButtonsLegsEnabled (default true).
-- v1.15 (pachy Grappling Hook, MDA-122): TIMED_PARTS.hookarm = {"Hook", "DinoHookRequest", "GRAPPLING HOOK"}; pressing its
--   slot fires DinoHookRequest(stamp, camera LookVector) (HookServer 1.0 aims along it) instead of the plain stamp.
--   Ready / cooldown look from HookEnabled / HookReadyAt / HookCooldown like the other timed parts.
-- v1.14 (Kepu 2026-10-30 after v128: "when I shoot the cannon don't adjust the camera angle"): with script attribute
--   MechaAimKeepCamEnabled (default true) the release no longer sets ShoulderCamLookAt, so the camera stays where it was;
--   the raptor still snaps to face the shot (then turns back toward the camera at its turn rate, TurnLimit "aim"). false =
--   1.13 (the camera turns to the shot). Diagnostic: character MechaScreechCamMoved (true / false, the last shot).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.22"
if script:GetAttribute("MechaButtonsBloodEnabled") == nil then script:SetAttribute("MechaButtonsBloodEnabled", true) end -- v1.17
local BLOOD_BTN = script:GetAttribute("MechaButtonsBloodEnabled") ~= false
if script:GetAttribute("MechaButtonsLegsEnabled") == nil then script:SetAttribute("MechaButtonsLegsEnabled", true) end -- v1.16
local LEGS_BTN = script:GetAttribute("MechaButtonsLegsEnabled") ~= false
local AIM_LOCK, AIM_DEAD = 0.25, 14 -- v1.12
if script:GetAttribute("MechaButtonsTetherEnabled") == nil then script:SetAttribute("MechaButtonsTetherEnabled", true) end -- v1.20
local TETHER_BTN = script:GetAttribute("MechaButtonsTetherEnabled") ~= false
local AIM_FULL_PX, CONE_YAW, CONE_PITCH, AIM_SMOOTH, SEND_EPS = 110, math.rad(30), math.rad(15), 14, 0.01 -- v1.13
if script:GetAttribute("MechaAimConeEnabled") == nil then script:SetAttribute("MechaAimConeEnabled", true) end -- v1.13
if script:GetAttribute("MechaAimKeepCamEnabled") == nil then script:SetAttribute("MechaAimKeepCamEnabled", true) end -- v1.14
if script:GetAttribute("MechaThumbAimEnabled") == nil then script:SetAttribute("MechaThumbAimEnabled", true) end
local PANEL = Color3.fromRGB(20, 20, 26)
local ORANGE = Color3.fromRGB(255, 155, 46)
local SPOTS = {
	[true] = {{0.21, 0.08}, {0.325, 0.18}},  -- AutoRun on: RUN's spot + the arc
	[false] = {{0.33, 0.08}, {0.33, 0.28}},  -- RUN shown: inner column
}
local SIZE = 0.095
local KEYS = {Enum.KeyCode.R, Enum.KeyCode.C, Enum.KeyCode.T, Enum.KeyCode.V} -- v1.1: slot 1 / slot 2 (was 1 / 2); v1.4: + T / V
local KEY_NAMES = {"R", "C", "T", "V"}
local PULL_COLOR = Color3.fromRGB(255, 217, 168) -- v1.4
if script:GetAttribute("MechaButtonsPullEnabled") == nil then script:SetAttribute("MechaButtonsPullEnabled", true) end -- v1.4
for k, v in pairs({MechaAirUpEnabled = true, MechaAirUpHeight = 30, MechaAirUpTime = 0.6}) do -- v1.6
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end

local char = script.Parent
local player = Players.LocalPlayer
local hum = char:WaitForChild("Humanoid", 10)
local hrp = char:WaitForChild("HumanoidRootPart", 10)
char:SetAttribute("MechaButtonsVersion", VERSION)
char:SetAttribute("MechaDashLocal", "idle")
local remote = ReplicatedStorage:WaitForChild("DinoDashRequest", 20)
local cloakRemote -- v1.4: DinoCloakRequest (CloakServer 1.0), looked up on first use
local TIMED_PARTS = { -- v1.5: part id -> {attribute prefix, remote name, button name}
	adrenaline = {"Adrenaline", "DinoAdrenalineRequest", "ADRENALINE"},
	shield = {"EnergyShield", "DinoEnergyShieldRequest", "SHIELD"},
}
TIMED_PARTS.scent = {"Scent", "DinoScentRequest", "SCENT"} -- v1.8
TIMED_PARTS.screech = {"Screech", "DinoScreechRequest", "SHOCK CANNON"} -- v1.8 (hold-to-aim, see aimStart); v1.9: Shock Dart; v1.10: Shock Cannon
TIMED_PARTS.traps = {"Mine", "DinoMineRequest", "SHOCK MINE"} -- v1.11
TIMED_PARTS.hookarm = {"Hook", "DinoHookRequest", "GRAPPLING HOOK"} -- v1.15: pachy Grappling Hook (fires with the aim)
if script:GetAttribute("MechaButtonsMedEnabled") == nil then script:SetAttribute("MechaButtonsMedEnabled", true) end -- v1.18
if script:GetAttribute("MechaButtonsMedEnabled") ~= false then TIMED_PARTS.medstation = {"Med", "DinoMedRequest", "MED-STATION"} end -- v1.18: pachy Med-Station
if script:GetAttribute("MechaButtonsBatch3Enabled") == nil then script:SetAttribute("MechaButtonsBatch3Enabled", true) end -- v1.19
local B3_BTN = script:GetAttribute("MechaButtonsBatch3Enabled") ~= false
if B3_BTN then -- v1.19: pachy parts batch 3
	TIMED_PARTS.servodash = {"ServoDash", "DinoServoDashRequest", "SERVO DASH"}
	TIMED_PARTS.visor = {"Visor", "DinoVisorRequest", "DOME VISOR"}
	TIMED_PARTS.ink = {"Ink", "DinoInkRequest", "INK SHOOTER"}
end
if TETHER_BTN then TIMED_PARTS.tether = {"Tether", "DinoTetherRequest", "TETHER SPIKE"} end -- v1.20
-- v1.20: parts that use hold-to-aim
local function aimedPart(id) -- v1.22: the tether holds-to-aim only when its aim mode is off
	return id == "screech" or (TETHER_BTN and id == "tether" and script:GetAttribute("MechaTetherAimMode") == false)
end
local AIM_TIME = 1 -- v1.8: s for the aim line to reach ScreechRange
local aim -- v1.8: {slot, t0, input, gesture, part}

local function slotPart(n)
	local v = player:GetAttribute("SkillSlot" .. n)
	return (type(v) == "string" and v ~= "") and v or nil
end

-- v1.8: Raptor Screech hold-to-aim
local function aimRange()
	if not aim then return 0 end
	local maxR = tonumber(char:GetAttribute("ScreechRange")) or 0
	if char:GetAttribute("ScreechFullRange") == true then -- v1.10: Shock Cannon, full range at once
		return maxR
	else
		return maxR * math.clamp((os.clock() - aim.t0) / AIM_TIME, 0, 1)
	end
end
local function aimCancel()
	if aim and aim.part then aim.part:Destroy() end
	local wasTether = aim and aim.kind == "tether" -- v1.20
	aim = nil
	char:SetAttribute(wasTether and "MechaTetherAim" or "MechaScreechAim", "idle")
end
local function aimStart(n, input, isGesture)
	aimCancel()
	if not hrp then return end
	if TETHER_BTN and slotPart(n) == "tether" then -- v1.20: the landing circle
		local splash = math.max(1, tonumber(char:GetAttribute("TetherSplash")) or 8)
		local disc = Instance.new("Part")
		disc.Name = "TetherAim"
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(0.2, splash * 2, splash * 2)
		disc.Color = Color3.fromRGB(255, 200, 50)
		disc.Material = Enum.Material.Neon
		disc.Transparency = 0.55
		disc.Anchored, disc.CanCollide, disc.CanQuery, disc.CanTouch, disc.CastShadow = true, false, false, false, false
		local hl = Instance.new("Highlight")
		hl.FillColor, hl.OutlineColor = disc.Color, Color3.new(1, 1, 1)
		hl.FillTransparency, hl.OutlineTransparency = 0.6, 0.2
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = disc
		disc.Parent = workspace
		aim = {slot = n, t0 = os.clock(), input = input, gesture = isGesture == true, part = disc, kind = "tether"}
		if aim.gesture and input and script:GetAttribute("MechaThumbAimEnabled") ~= false then
			aim.origin = Vector2.new(input.Position.X, input.Position.Y)
			aim.lockAt = os.clock() + AIM_LOCK
		end
		char:SetAttribute("MechaTetherAim", "aiming")
		return
	end
	local line = Instance.new("Part")
	line.Name = "ScreechAim"
	line.Color = Color3.fromRGB(240, 90, 79)
	line.Material = Enum.Material.Neon
	line.Transparency = 0.25
	line.Anchored, line.CanCollide, line.CanQuery, line.CanTouch, line.CastShadow = true, false, false, false, false
	line.Size = Vector3.new(0.5, 0.5, 0.1)
	local hl = Instance.new("Highlight") -- Play: a ground strip was hidden by the rock steps; the beam shows through
	hl.FillColor, hl.OutlineColor = line.Color, Color3.new(1, 1, 1)
	hl.FillTransparency, hl.OutlineTransparency = 0.2, 0.6
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = line
	line.Parent = workspace
	aim = {slot = n, t0 = os.clock(), input = input, gesture = isGesture == true, part = line, kind = "screech"}
	if aim.gesture and input and script:GetAttribute("MechaThumbAimEnabled") ~= false then -- v1.12: thumb aim
		aim.origin = Vector2.new(input.Position.X, input.Position.Y)
		aim.lockAt = os.clock() + AIM_LOCK
	end
	char:SetAttribute("MechaScreechAim", "aiming")
end
local function aimRelease()
	if not aim then return end
	if aim.kind == "tether" then -- v1.20: fire at the circle
		local pos = aim.landPos
		aimCancel()
		local r = ReplicatedStorage:FindFirstChild("DinoTetherRequest")
		if r and typeof(pos) == "Vector3" then
			r:FireServer(workspace:GetServerTimeNow(), pos)
			char:SetAttribute("MechaTetherFired", (char:GetAttribute("MechaTetherFired") or 0) + 1)
		end
		return
	end
	local range = aimRange()
	local thumbDir = aim.thumbDir -- v1.12
	aimCancel()
	char:SetAttribute("MechaScreechHeld", math.floor(range * 10 + 0.5) / 10)
	local r = ReplicatedStorage:FindFirstChild("DinoScreechRequest")
	if r then
		local faceDir = thumbDir -- v1.13: the cone's direction has a pitch; turn to its flat part only
		if thumbDir and script:GetAttribute("MechaAimConeEnabled") ~= false then
			local fl = Vector3.new(thumbDir.X, 0, thumbDir.Z)
			faceDir = fl.Magnitude > 1e-3 and fl.Unit or nil
		end
		if faceDir and hrp then -- v1.12: face the shot, camera too
			hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + faceDir)
			local camMoved = script:GetAttribute("MechaAimKeepCamEnabled") == false -- v1.14: camera stays
			if camMoved then char:SetAttribute("ShoulderCamLookAt", hrp.Position + faceDir * 500) end
			char:SetAttribute("MechaScreechCamMoved", camMoved)
		end
		r:FireServer(workspace:GetServerTimeNow(), range, thumbDir)
		char:SetAttribute("MechaScreechFired", (char:GetAttribute("MechaScreechFired") or 0) + 1)
	end
end
-- v1.13: the thumb aim cone (smooth yaw + pitch in front of the raptor)
local coneRay = RaycastParams.new()
coneRay.FilterType = Enum.RaycastFilterType.Exclude
coneRay.RespectCanCollide = true
local function coneAxis(v) -- px offset -> -1..1 past the dead zone
	local m = math.abs(v) - AIM_DEAD
	if m <= 0 then return 0 end
	return math.sign(v) * math.clamp(m / AIM_FULL_PX, 0, 1)
end
local function coneStep(facing, len, dt)
	local tyaw, tpitch = 0, 0
	if aim.locked and aim.stick then
		tyaw = coneAxis(aim.stick.X) * CONE_YAW
		tpitch = coneAxis(-aim.stick.Y) * CONE_PITCH
	end
	local k = 1 - math.exp(-AIM_SMOOTH * math.clamp(dt or 0, 0, 0.1))
	aim.yaw = (aim.yaw or 0) + (tyaw - (aim.yaw or 0)) * k
	aim.pitch = (aim.pitch or 0) + (tpitch - (aim.pitch or 0)) * k
	local right = facing:Cross(Vector3.yAxis)
	local h = facing * math.cos(aim.yaw) + right * math.sin(aim.yaw)
	local look = (h * math.cos(aim.pitch) + Vector3.yAxis * math.sin(aim.pitch)).Unit
	aim.thumbDir = (math.abs(aim.yaw) > SEND_EPS or math.abs(aim.pitch) > SEND_EPS) and look or nil
	char:SetAttribute("MechaScreechAimMode", aim.thumbDir and "thumb" or "ahead")
	char:SetAttribute("MechaScreechAimDeg", math.floor(math.deg(aim.yaw) + 0.5))
	char:SetAttribute("MechaScreechAimPitch", math.floor(math.deg(aim.pitch) + 0.5))
	local cm = char:FindFirstChild("Mecha_ShockCannon")
	local pod = cm and cm:FindFirstChild("Pod")
	local mz = pod and pod:FindFirstChild("ShockMuzzle")
	local start = (mz and mz:IsA("Attachment")) and mz.WorldPosition or hrp.Position + h * 4
	coneRay.FilterDescendantsInstances = {char, aim.part}
	local hit = workspace:Raycast(start, look * len, coneRay)
	local L = hit and math.max(0.1, (hit.Position - start).Magnitude) or len
	aim.part.Size = Vector3.new(0.5, 0.5, L)
	aim.part.CFrame = CFrame.lookAt(start + look * (L / 2), start + look * (L / 2 + 1))
end
-- v1.20: the tether landing circle
local tetherRay = RaycastParams.new()
tetherRay.FilterType = Enum.RaycastFilterType.Exclude
local TILT_NEAR, TILT_FAR, TILT_MIN_DIST = math.rad(-45), math.rad(-5), 6 -- v1.21
if script:GetAttribute("MechaTetherTiltAim") == nil then script:SetAttribute("MechaTetherTiltAim", true) end -- v1.21
local groundRay = RaycastParams.new() -- v1.21: ground only (no trees / rocks / grass / dinos)
groundRay.FilterType = Enum.RaycastFilterType.Exclude
local function groundExclude()
	local ex = {aim.part}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Trees", "Rocks", "TallGrass", "Bots", "EdgeWalls", "Prey"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	for _, n in ipairs({"DinoFX", "DinoFX_Local"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	groundRay.FilterDescendantsInstances = ex
	return groundRay
end
local function tetherStep(dt)
	local range = math.max(1, tonumber(char:GetAttribute("TetherRange")) or 60)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local ex = {char, aim.part}
	local fx = workspace:FindFirstChild("DinoFX")
	if fx then table.insert(ex, fx) end
	tetherRay.FilterDescendantsInstances = ex
	local base = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
	local goal
	if aim.origin and aim.locked and aim.stick and aim.stick.Magnitude > AIM_DEAD then -- touch: the finger moves it
		local f = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
		local rt = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z)
		if f.Magnitude > 1e-3 and rt.Magnitude > 1e-3 then
			local d = rt.Unit * aim.stick.X + f.Unit * (-aim.stick.Y)
			if d.Magnitude > 1e-3 then
				local k = math.clamp((aim.stick.Magnitude - AIM_DEAD) / (AIM_FULL_PX * 1.6), 0, 1)
				goal = base + d.Unit * range * k
			end
		end
	end
	if not goal and script:GetAttribute("MechaTetherTiltAim") ~= false then -- v1.21: camera tilt = distance
		local look = cam.CFrame.LookVector
		local f = Vector3.new(look.X, 0, look.Z)
		if f.Magnitude > 1e-3 then
			local pitch = math.asin(math.clamp(look.Y, -1, 1))
			local k = math.clamp((pitch - TILT_NEAR) / (TILT_FAR - TILT_NEAR), 0, 1)
			goal = base + f.Unit * math.max(TILT_MIN_DIST, range * k)
		end
	end
	if not goal then -- the ground under the screen's centre
		local vp = cam.ViewportSize
		local ray = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, tetherRay)
		local p = hit and hit.Position or (ray.Origin + ray.Direction * 600)
		goal = Vector3.new(p.X, 0, p.Z)
	end
	local off = goal - base
	if off.Magnitude > range then off = off.Unit * range end
	goal = base + off
	local k = 1 - math.exp(-AIM_SMOOTH * math.clamp(dt or 0, 0, 0.1))
	aim.flat = aim.flat and aim.flat:Lerp(goal, k) or goal
	local g
	if script:GetAttribute("MechaTetherTiltAim") ~= false then -- v1.21: ground only
		g = workspace:Raycast(Vector3.new(aim.flat.X, hrp.Position.Y + 80, aim.flat.Z), Vector3.new(0, -260, 0), groundExclude())
	else
		g = workspace:Raycast(Vector3.new(aim.flat.X, hrp.Position.Y + 60, aim.flat.Z), Vector3.new(0, -240, 0), tetherRay)
	end
	local gp = g and g.Position or Vector3.new(aim.flat.X, hrp.Position.Y - 3, aim.flat.Z)
	aim.landPos = gp
	aim.part.CFrame = CFrame.new(gp + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	char:SetAttribute("MechaTetherAimDist", math.floor((aim.flat - base).Magnitude * 10 + 0.5) / 10)
end
RunService.RenderStepped:Connect(function(dt)
	if not aim then return end
	if not char.Parent or not hum or hum.Health <= 0 or slotPart(aim.slot) ~= aim.kind then aimCancel() return end -- v1.20: aim.kind
	if aim.kind == "tether" then tetherStep(dt) return end -- v1.20
	local len = math.max(0.1, aimRange())
	local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if look.Magnitude < 1e-3 then return end
	look = look.Unit
	local facing = look
	if aim.origin and script:GetAttribute("MechaAimConeEnabled") ~= false then coneStep(facing, len, dt) return end -- v1.13
	aim.thumbDir = nil -- v1.12: the thumb's joystick direction, once locked and out of the dead zone
	if aim.locked and aim.stick and aim.stick.Magnitude > AIM_DEAD then
		local cf = workspace.CurrentCamera.CFrame
		local f = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
		local rt = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
		if f.Magnitude > 1e-3 and rt.Magnitude > 1e-3 then
			local d = rt.Unit * aim.stick.X + f.Unit * (-aim.stick.Y)
			if d.Magnitude > 1e-3 then
				look = d.Unit
				aim.thumbDir = look
			end
		end
	end
	char:SetAttribute("MechaScreechAimMode", aim.thumbDir and "thumb" or "ahead")
	char:SetAttribute("MechaScreechAimDeg", math.floor(math.deg(math.acos(math.clamp(facing:Dot(look), -1, 1))) + 0.5))
	local base = hrp.Position -- the bolt's height (ScreechServer starts it 4 studs ahead of the root)
	aim.part.Size = Vector3.new(0.5, 0.5, len)
	aim.part.CFrame = CFrame.lookAt(base + look * (4 + len / 2), base + look * (5 + len / 2))
end)

-- v1.22: Tether Spike tactical aim mode (see the header)
if script:GetAttribute("MechaTetherAimMode") == nil then script:SetAttribute("MechaTetherAimMode", true) end
local ContextActionService = game:GetService("ContextActionService")
local TAC_HEIGHT, TAC_BACK, TAC_AHEAD, TAC_TIMEOUT, TAC_DRAG, TAC_START = 85, 28, 35, 6, 0.18, 40
local tac -- {slot, t0, disc, line, gui, fwd, flat, landPos, conns, prev*}
local function tacOn() return TETHER_BTN and script:GetAttribute("MechaTetherAimMode") ~= false end
local tacRay = RaycastParams.new()
tacRay.FilterType = Enum.RaycastFilterType.Exclude
local function tacExclude()
	local ex = {}
	if tac then
		if tac.disc then table.insert(ex, tac.disc) end
		if tac.line then table.insert(ex, tac.line) end
	end
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Trees", "Rocks", "TallGrass", "Bots", "EdgeWalls", "Prey"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	for _, n in ipairs({"DinoFX", "DinoFX_Local"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	tacRay.FilterDescendantsInstances = ex
	return tacRay
end
local function tacEnd(fire, why)
	local s = tac
	if not s then return end
	tac = nil
	pcall(function() RunService:UnbindFromRenderStep("TetherTacCam") end)
	pcall(function() ContextActionService:UnbindAction("TetherTacInput") end)
	for _, c in ipairs(s.conns) do c:Disconnect() end
	for _, x in ipairs({s.disc, s.line, s.gui}) do if x then x:Destroy() end end
	local cam = workspace.CurrentCamera
	if cam and s.prevFov then cam.FieldOfView = s.prevFov end
	char:SetAttribute("TetherAiming", false)
	char:SetAttribute("TurnLimitEnabled", s.prevTurn)
	char:SetAttribute("ShoulderCamEnabled", s.prevCam)
	if hum and s.prevTurn == false then hum.AutoRotate = true end
	char:SetAttribute("MechaTetherAimEnd", why)
	char:SetAttribute("MechaTetherAim", "idle")
	if fire and typeof(s.landPos) == "Vector3" then
		local r = ReplicatedStorage:FindFirstChild("DinoTetherRequest")
		if r then
			r:FireServer(workspace:GetServerTimeNow(), s.landPos)
			char:SetAttribute("MechaTetherFired", (char:GetAttribute("MechaTetherFired") or 0) + 1)
		end
	end
end
local function tacStep(dt)
	local s = tac
	if not s then return end
	if not char.Parent or not hum or hum.Health <= 0 or slotPart(s.slot) ~= "tether" then tacEnd(false, "gone") return end
	if os.clock() - s.t0 > TAC_TIMEOUT then tacEnd(false, "timeout") return end
	local cam = workspace.CurrentCamera
	if not cam then return end
	local range = math.max(1, tonumber(char:GetAttribute("TetherRange")) or 90)
	local base = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
	-- the camera: high above, looking down at the area ahead (yaw fixed at the start)
	local center = hrp.Position + s.fwd * TAC_AHEAD
	local eye = center + Vector3.new(0, TAC_HEIGHT, 0) - s.fwd * TAC_BACK
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(eye, center)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	-- where the circle goes: the mouse (PC) or the drag (touch)
	if UserInputService.MouseEnabled and not s.touched then
		local mp = UserInputService:GetMouseLocation()
		local ray = cam:ViewportPointToRay(mp.X, mp.Y)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, tacExclude())
		local p = hit and hit.Position or (ray.Origin + ray.Direction * ((ray.Origin.Y - hrp.Position.Y) / math.max(0.05, -ray.Direction.Y)))
		s.flat = Vector3.new(p.X, 0, p.Z)
	end
	local off = s.flat - base
	if off.Magnitude > range then off = off.Unit * range end
	if off.Magnitude < 6 then off = (off.Magnitude > 1e-3 and off.Unit or s.fwd) * 6 end
	s.flat = base + off
	local g = workspace:Raycast(Vector3.new(s.flat.X, hrp.Position.Y + 80, s.flat.Z), Vector3.new(0, -260, 0), tacExclude())
	local gp = g and g.Position or Vector3.new(s.flat.X, hrp.Position.Y - 3, s.flat.Z)
	s.landPos = gp
	s.disc.CFrame = CFrame.new(gp + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local from = Vector3.new(hrp.Position.X, gp.Y + 0.35, hrp.Position.Z)
	local to = gp + Vector3.new(0, 0.35, 0)
	local L = math.max(0.1, (to - from).Magnitude)
	s.line.Size = Vector3.new(0.35, 0.1, L)
	s.line.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
	-- the pachy faces the circle and walks / strafes without turning
	hum.AutoRotate = false
	local face = Vector3.new(gp.X, hrp.Position.Y, gp.Z)
	if (face - hrp.Position).Magnitude > 0.5 then hrp.CFrame = CFrame.lookAt(hrp.Position, face) end
	local left = math.max(0, TAC_TIMEOUT - (os.clock() - s.t0))
	if s.timer then s.timer.Text = ("%.1fs"):format(left) end
	char:SetAttribute("MechaTetherAimDist", math.floor(off.Magnitude * 10 + 0.5) / 10)
end
local function tacStart(n)
	if tac or not hrp or not hum or hum.Health <= 0 then return end
	if char:GetAttribute("TetherEnabled") ~= true then return end
	if (tonumber(char:GetAttribute("TetherReadyAt")) or 0) > workspace:GetServerTimeNow() then
		char:SetAttribute("MechaTetherAimEnd", "cooldown")
		return
	end
	local cam = workspace.CurrentCamera
	local f = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	f = f.Magnitude > 1e-3 and f.Unit or Vector3.new(0, 0, -1)
	local splash = math.max(1, tonumber(char:GetAttribute("TetherSplash")) or 8)
	local disc = Instance.new("Part")
	disc.Name = "TetherAim"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.2, splash * 2, splash * 2)
	disc.Color = Color3.fromRGB(255, 200, 50)
	disc.Material = Enum.Material.Neon
	disc.Transparency = 0.5
	disc.Anchored, disc.CanCollide, disc.CanQuery, disc.CanTouch, disc.CastShadow = true, false, false, false, false
	local hl = Instance.new("Highlight")
	hl.FillColor, hl.OutlineColor = disc.Color, Color3.new(1, 1, 1)
	hl.FillTransparency, hl.OutlineTransparency = 0.6, 0.1
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = disc
	disc.Parent = workspace
	local line = Instance.new("Part")
	line.Name = "TetherAimLine"
	line.Color = Color3.fromRGB(255, 200, 50)
	line.Material = Enum.Material.Neon
	line.Transparency = 0.35
	line.Anchored, line.CanCollide, line.CanQuery, line.CanTouch, line.CastShadow = true, false, false, false, false
	line.Parent = workspace
	local gui = Instance.new("ScreenGui")
	gui.Name = "TetherAimHud"
	gui.ResetOnSpawn = true
	gui.DisplayOrder = 7
	gui.IgnoreGuiInset = true
	local tag = Instance.new("TextLabel")
	tag.Name = "Tag"
	tag.AnchorPoint = Vector2.new(0.5, 0)
	tag.Position = UDim2.new(0.5, 0, 0, 58)
	tag.Size = UDim2.fromOffset(330, 34)
	tag.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	tag.BackgroundTransparency = 0.35
	tag.Font = Enum.Font.FredokaOne
	tag.TextSize = 18
	tag.TextColor3 = Color3.fromRGB(255, 200, 50)
	tag.Text = UserInputService.TouchEnabled and not UserInputService.MouseEnabled and "TETHER AIM \u{00B7} tap TETHER to fire"
		or "TETHER AIM \u{00B7} click or TETHER key to fire"
	tag.Parent = gui
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0.5, 0)
	tc.Parent = tag
	local timer = Instance.new("TextLabel")
	timer.Name = "Timer"
	timer.AnchorPoint = Vector2.new(0.5, 0)
	timer.Position = UDim2.new(0.5, 0, 0, 96)
	timer.Size = UDim2.fromOffset(80, 22)
	timer.BackgroundTransparency = 1
	timer.Font = Enum.Font.GothamBold
	timer.TextSize = 14
	timer.TextColor3 = Color3.new(1, 1, 1)
	timer.TextStrokeTransparency = 0.4
	timer.Parent = gui
	local cancel = Instance.new("TextButton")
	cancel.Name = "Cancel"
	cancel.AnchorPoint = Vector2.new(0.5, 0)
	cancel.Position = UDim2.new(0.5, 0, 0, 122)
	cancel.Size = UDim2.fromOffset(120, 38)
	cancel.BackgroundColor3 = PANEL
	cancel.BackgroundTransparency = 0.15
	cancel.AutoButtonColor = true
	cancel.Font = Enum.Font.FredokaOne
	cancel.TextSize = 18
	cancel.TextColor3 = Color3.new(1, 1, 1)
	cancel.Text = "CANCEL"
	cancel.Parent = gui
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0.3, 0)
	cc.Parent = cancel
	local cs = Instance.new("UIStroke")
	cs.Color = ORANGE
	cs.Thickness = 2
	cs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cs.Parent = cancel
	gui.Parent = player:WaitForChild("PlayerGui")
	tac = {slot = n, t0 = os.clock(), disc = disc, line = line, gui = gui, timer = timer, fwd = f,
		flat = Vector3.new(hrp.Position.X, 0, hrp.Position.Z) + f * TAC_START, conns = {},
		prevTurn = char:GetAttribute("TurnLimitEnabled"), prevCam = char:GetAttribute("ShoulderCamEnabled"),
		prevFov = cam and cam.FieldOfView}
	table.insert(tac.conns, cancel.Activated:Connect(function() tacEnd(false, "cancel") end))
	-- touch: a drag that starts on the right side of the screen (not on a button) moves the circle
	local drags = {}
	table.insert(tac.conns, UserInputService.TouchStarted:Connect(function(input, processed)
		if processed or not tac then return end
		local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1000, 600)
		if input.Position.X > vp.X * 0.4 then drags[input] = Vector2.new(input.Position.X, input.Position.Y) end
	end))
	table.insert(tac.conns, UserInputService.TouchMoved:Connect(function(input)
		local last = drags[input]
		if not (last and tac) then return end
		local now = Vector2.new(input.Position.X, input.Position.Y)
		local d = now - last
		drags[input] = now
		local rt = Vector3.new(-tac.fwd.Z, 0, tac.fwd.X) -- screen right = the camera's right (yaw fixed)
		tac.touched = true
		tac.flat += (rt * d.X + tac.fwd * (-d.Y)) * TAC_DRAG
	end))
	table.insert(tac.conns, UserInputService.TouchEnded:Connect(function(input) drags[input] = nil end))
	ContextActionService:BindActionAtPriority("TetherTacInput", function(_, state, input)
		if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			tacEnd(true, "fired")
		else
			tacEnd(false, "cancel")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 50, Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2,
		Enum.KeyCode.Q)
	char:SetAttribute("ShoulderCamEnabled", false)
	char:SetAttribute("TurnLimitEnabled", false)
	char:SetAttribute("TetherAiming", true)
	char:SetAttribute("MechaTetherAim", "tactical")
	char:SetAttribute("MechaTetherAimEnd", nil)
	RunService:BindToRenderStep("TetherTacCam", Enum.RenderPriority.Camera.Value + 10, tacStep)
end
char.AncestryChanged:Connect(function(_, parent) if not parent then tacEnd(false, "gone") end end)

local function press(n, input)
	local id = slotPart(n)
	char:SetAttribute("MechaButtonsLastPress", ("slot%d:%s"):format(n, id or "empty"))
	if tacOn() and id == "tether" then -- v1.22: tap = aim mode, tap again = fire
		if tac then tacEnd(true, "fired") else tacStart(n) end
		return
	end
	if aimedPart(id) then -- v1.8: start the aim; the release fires (v1.20: + tether)
		aimStart(n, input, false)
		return
	end
	if B3_BTN and id == "ink" then -- v1.19: the ink fires along the camera look (InkServer 1.0)
		local r = ReplicatedStorage:FindFirstChild("DinoInkRequest")
		local cam = workspace.CurrentCamera
		if r and cam then r:FireServer(workspace:GetServerTimeNow(), cam.CFrame.LookVector) end
		return
	end
	if id == "hookarm" then -- v1.15: the hook fires along the camera look (HookServer 1.0)
		local r = ReplicatedStorage:FindFirstChild("DinoHookRequest")
		local cam = workspace.CurrentCamera
		if r and cam then r:FireServer(workspace:GetServerTimeNow(), cam.CFrame.LookVector) end
		return
	end
	if id == "thrusters" and remote then remote:FireServer(workspace:GetServerTimeNow()) end
	if id == "cloak" then -- v1.4
		cloakRemote = cloakRemote or ReplicatedStorage:FindFirstChild("DinoCloakRequest")
		if cloakRemote then cloakRemote:FireServer(workspace:GetServerTimeNow()) end
	end
	local tp = id and TIMED_PARTS[id] -- v1.5
	if tp then
		local r = ReplicatedStorage:FindFirstChild(tp[2])
		if r then r:FireServer(workspace:GetServerTimeNow()) end
	end
end

-- v1.4: is a part ready to use, and how much of its cooldown is left (0..1)
local function partState(id)
	local now = workspace:GetServerTimeNow()
	if BLOOD_BTN and id == "bloodrush" then -- v1.17: a sacrifice can be made now
		local hum = char:FindFirstChildOfClass("Humanoid")
		local ok = char:GetAttribute("BloodRushEnabled") == true and hum ~= nil
			and (tonumber(char:GetAttribute("HeadbuttChargesNow")) or 1) < 1
			and hum.Health > hum.MaxHealth * 0.5
			and (tonumber(char:GetAttribute("HeadbuttSacrifices")) or 0) < (tonumber(char:GetAttribute("BloodRushMax")) or 2)
		return ok, 0
	end
	if LEGS_BTN and id == "mechalegs" then -- v1.16: the leap's cooldown
		local cd = tonumber(char:GetAttribute("JumpCooldown")) or 6
		local stamp = char:GetAttribute("JumpPredictedAt")
		local left = typeof(stamp) == "number" and (stamp + cd - now) or 0
		return char:GetAttribute("MechaLegsEnabled") == true and left <= 0, (cd > 0 and left > 0) and math.clamp(left / cd, 0, 1) or 0
	end
	if id == "cloak" then
		local ready = char:GetAttribute("CloakEnabled") == true and (tonumber(char:GetAttribute("CloakedUntil")) or 0) <= now
			and now >= (tonumber(char:GetAttribute("CloakReadyAt")) or 0)
		local cd = tonumber(char:GetAttribute("CloakCooldown")) or 0
		local left = (tonumber(char:GetAttribute("CloakReadyAt")) or 0) - now
		return ready, (cd > 0 and left > 0) and math.clamp(left / cd, 0, 1) or 0
	end
	local tp = TIMED_PARTS[id] -- v1.5
	if tp then
		local px = tp[1]
		local readyAt = tonumber(char:GetAttribute(px .. "ReadyAt")) or 0
		local ready = char:GetAttribute(px .. "Enabled") == true and (tonumber(char:GetAttribute(px .. "Until")) or 0) <= now
			and now >= readyAt
		local cd = tonumber(char:GetAttribute(px .. "Cooldown")) or 0
		local left = readyAt - now
		return ready, (cd > 0 and left > 0) and math.clamp(left / cd, 0, 1) or 0
	end
	local nextAt = tonumber(char:GetAttribute("DashNextChargeAt")) or 0
	local rc = tonumber(char:GetAttribute("DashRecharge")) or 8
	local frac = 0
	if id == "thrusters" and nextAt > 0 and rc > 0 then frac = math.clamp((nextAt - now) / rc, 0, 1) end
	return char:GetAttribute("DashEnabled") == true, frac
end
local function partName(id)
	if id == "thrusters" then return "DASH" end
	if LEGS_BTN and id == "mechalegs" then return "MECHA LEGS" end -- v1.16
	if BLOOD_BTN and id == "bloodrush" then return "BLOOD RUSH" end -- v1.17
	if TIMED_PARTS[id] then return TIMED_PARTS[id][3] end -- v1.5
	return string.upper(id)
end

-- dash physics --------------------------------------------------------------------------------------------------------
local lastDash = char:GetAttribute("DashStartedAt")

-- v1.2: boost feel (camera punch + speed lines) --------------------------------------------------------------------
local FX_BIND = "MechaBoostCam"
local fxBoosting, fxK, fxBaseFov, fxGui, fxLines, fxT = false, 0, nil, nil, nil, 0
local function fxOn() return script:GetAttribute("MechaBoostFxEnabled") ~= false end
local function pounceStarted() -- v1.3
	if script:GetAttribute("MechaBoostPounceEnds") == false then return false end
	local s = char:GetAttribute("PounceLocalState")
	return s == "windup" or s == "lunge"
end
local function fxBuild()
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return end
	local old = pg:FindFirstChild("MechaSpeedLines")
	if old then old:Destroy() end
	fxGui = Instance.new("ScreenGui")
	fxGui.Name = "MechaSpeedLines"
	fxGui.ResetOnSpawn = true
	fxGui.DisplayOrder = 4
	fxGui.IgnoreGuiInset = true
	fxLines = {}
	for i = 1, 40 do -- 40 streaks (24 looked sparse in Play)
		local f = Instance.new("Frame")
		f.Name = "Line_" .. i
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BorderSizePixel = 0
		f.Parent = fxGui
		fxLines[i] = {f = f, a = math.random() * math.pi * 2, r = 0.45 + math.random() * 0.55, len = 100 + math.random() * 120}
	end
	fxGui.Parent = pg
end
local function fxStep(dt)
	fxT += dt
	if fxBoosting then fxK = math.min(1, fxK + dt / 0.15) else fxK = math.max(0, fxK - dt / 0.3) end
	local cam = workspace.CurrentCamera
	if cam and fxBaseFov then
		cam.FieldOfView = fxBaseFov + 15 * fxK
		local amp = math.rad(0.6) * fxK
		cam.CFrame = cam.CFrame * CFrame.Angles(math.noise(fxT * 18, 1.3) * amp, math.noise(fxT * 18, 7.1) * amp, 0)
	end
	if fxGui and fxLines then
		local size = fxGui.AbsoluteSize
		local half = math.sqrt(size.X * size.X + size.Y * size.Y) / 2
		for _, l in ipairs(fxLines) do
			l.r += dt * 2.2
			if l.r > 1.05 then l.a, l.r, l.len = math.random() * math.pi * 2, 0.45 + math.random() * 0.2, 100 + math.random() * 120 end
			local x, y = size.X / 2 + math.cos(l.a) * l.r * half, size.Y / 2 + math.sin(l.a) * l.r * half
			l.f.Position = UDim2.fromOffset(x, y)
			l.f.Size = UDim2.fromOffset(l.len, 4)
			l.f.Rotation = math.deg(l.a)
			l.f.BackgroundTransparency = 1 - 0.65 * fxK
		end
		fxGui.Enabled = fxK > 0
	end
	local shown = math.floor(fxK * 10 + 0.5) / 10
	if char:GetAttribute("MechaBoostFx") ~= shown then char:SetAttribute("MechaBoostFx", shown) end
	if fxK <= 0 and not fxBoosting then
		if cam and fxBaseFov then cam.FieldOfView = fxBaseFov end
		fxBaseFov = nil
		pcall(function() RunService:UnbindFromRenderStep(FX_BIND) end)
	end
end
local function fxStart()
	if not fxOn() then return end
	fxBoosting = true
	if not fxBaseFov then
		fxBaseFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
		if not (fxGui and fxGui.Parent) then fxBuild() end
		pcall(function() RunService:UnbindFromRenderStep(FX_BIND) end)
		RunService:BindToRenderStep(FX_BIND, Enum.RenderPriority.Camera.Value + 2, fxStep)
	end
end
local function fxStop() fxBoosting = false end
char.AncestryChanged:Connect(function(_, parent)
	if parent then return end
	pcall(function() RunService:UnbindFromRenderStep(FX_BIND) end)
	local cam = workspace.CurrentCamera
	if cam and fxBaseFov then cam.FieldOfView = fxBaseFov end
	if fxGui then fxGui:Destroy() end
end)

local boostConn -- v1.1
local function boost() -- v1.1: steerable boost for DashTime s at DashSpeedMul x run speed
	if not (hrp and hum and hum.Health > 0) then return end
	local t = tonumber(char:GetAttribute("DashTime")) or 1.5
	local mul = tonumber(char:GetAttribute("DashSpeedMul")) or 2
	local hop = tonumber(char:GetAttribute("DashHop")) or 0
	local speed = math.max(tonumber(char:GetAttribute("MoveRunSpeed")) or 0, hum.WalkSpeed) * mul
	local dir = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if t <= 0 or speed <= 0 or dir.Magnitude < 1e-3 then return end
	dir = dir.Unit
	-- v1.6: in the air with no move input -> straight up
	local inAir = hum.FloorMaterial == Enum.Material.Air
	local still = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z).Magnitude < 0.1
	local up = false
	if script:GetAttribute("MechaAirUpEnabled") ~= false and inAir and still then up = true end
	local upH = math.max(0, tonumber(script:GetAttribute("MechaAirUpHeight")) or 30)
	local upT = math.max(0.05, tonumber(script:GetAttribute("MechaAirUpTime")) or 0.6)
	if up then
		t = math.max(t, upT) -- v1.6 hover: the rise, then hold the height until the boost ends
		char:SetAttribute("MechaAirUpPhase", "rise")
		char:SetAttribute("MechaBoostMode", "up")
		char:SetAttribute("MechaAirUpCount", (char:GetAttribute("MechaAirUpCount") or 0) + 1)
	elseif inAir then
		char:SetAttribute("MechaBoostMode", "air")
	else
		char:SetAttribute("MechaBoostMode", "ground")
	end
	if boostConn then boostConn:Disconnect() end
	local old = hrp:FindFirstChild("MechaDash")
	if old then old:Destroy() end
	local oldAt = hrp:FindFirstChild("MechaDashAt")
	if oldAt then oldAt:Destroy() end
	local at = Instance.new("Attachment")
	at.Name = "MechaDashAt"
	at.Parent = hrp
	local lv = Instance.new("LinearVelocity")
	lv.Name = "MechaDash"
	lv.Attachment0 = at
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
	if up then -- v1.6: straight up, no sideways speed
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		lv.VectorVelocity = Vector3.new(0, upH / upT, 0)
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	lv.MaxForce = math.huge
	lv.Parent = hrp
	if hop > 0 and not up then -- v1.6: no star hop on the straight-up boost
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
		local cur = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(cur.X, math.sqrt(2 * workspace.Gravity * hop), cur.Z)
	end
	char:SetAttribute("MechaDashLocal", "dashing")
	char:SetAttribute("MechaDashLocalCount", (char:GetAttribute("MechaDashLocalCount") or 0) + 1)
	fxStart() -- v1.2
	local t0 = os.clock()
	local jam0 = char:GetAttribute("PartsJammedAt") -- v1.8
	local conn
	local function stop()
		fxStop() -- v1.2
		if conn then conn:Disconnect() end
		if boostConn == conn then boostConn = nil end
		lv:Destroy()
		at:Destroy()
		if hrp.Parent then
			local cur = hrp.AssemblyLinearVelocity
			hrp.AssemblyLinearVelocity = Vector3.new(0, up and math.min(cur.Y, 0) or cur.Y, 0) -- v1.6: the rise peaks here
		end
		if up and char.Parent then char:SetAttribute("MechaAirUpPhase", "done") end -- v1.6 hover
		if char.Parent then char:SetAttribute("MechaDashLocal", "idle") end
	end
	conn = RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		if pounceStarted() then -- v1.3
			char:SetAttribute("MechaBoostEnd", "pounce")
			stop()
			return
		end
		if char:GetAttribute("PartsJammedAt") ~= jam0 then -- v1.8: star Raptor Screech hit
			char:SetAttribute("MechaBoostEnd", "jammed")
			stop()
			return
		end
		if os.clock() - t0 >= t or not char.Parent or hum.Health <= 0 or char:GetAttribute("PounceLatched") == true
			or (tonumber(char:GetAttribute("StunnedUntil")) or 0) > now then
			stop()
			return
		end
		if up then -- v1.6: after the rise, hold the height; v1.7: steerable at boost speed while rising / hovering
			if os.clock() - t0 >= upT and char:GetAttribute("MechaAirUpPhase") == "rise" then
				char:SetAttribute("MechaAirUpPhase", "hover")
			end
			local vy = char:GetAttribute("MechaAirUpPhase") == "rise" and upH / upT or 0
			local umd = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
			local side = Vector3.zero
			if umd.Magnitude > 0.1 then
				side = umd.Unit * speed
				if char:GetAttribute("MechaBoostDir") ~= "move" then char:SetAttribute("MechaBoostDir", "move") end
			elseif char:GetAttribute("MechaBoostDir") ~= "keep" then
				char:SetAttribute("MechaBoostDir", "keep")
			end
			lv.VectorVelocity = Vector3.new(side.X, vy, side.Z)
			return
		end
		local md = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
		if md.Magnitude > 0.1 then
			dir = md.Unit
			if char:GetAttribute("MechaBoostDir") ~= "move" then char:SetAttribute("MechaBoostDir", "move") end
		elseif char:GetAttribute("MechaBoostDir") ~= "keep" then
			char:SetAttribute("MechaBoostDir", "keep")
		end
		lv.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
	end)
	boostConn = conn
end
local function dash()
	if not (hrp and hum and hum.Health > 0) then return end
	local dist = tonumber(char:GetAttribute("DashDistance")) or 0
	local t = tonumber(char:GetAttribute("DashTime")) or 0.35
	local hop = tonumber(char:GetAttribute("DashHop")) or 0
	local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if dist <= 0 or t <= 0 or look.Magnitude < 1e-3 then return end
	local v = look.Unit * (dist / t)
	local at = Instance.new("Attachment")
	at.Name = "MechaDashAt"
	at.Parent = hrp
	local lv = Instance.new("LinearVelocity")
	lv.Name = "MechaDash"
	lv.Attachment0 = at
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.new(v.X, v.Z)
	lv.MaxForce = math.huge
	lv.Parent = hrp
	if hop > 0 then
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
		local cur = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(cur.X, math.sqrt(2 * workspace.Gravity * hop), cur.Z)
	end
	char:SetAttribute("MechaDashLocal", "dashing")
	char:SetAttribute("MechaDashLocalCount", (char:GetAttribute("MechaDashLocalCount") or 0) + 1)
	task.delay(t, function()
		lv:Destroy()
		at:Destroy()
		-- stop the dash speed (measured in Play: without this the dino slid ~60 studs more after a 50-stud dash)
		if hrp.Parent then
			local cur = hrp.AssemblyLinearVelocity
			hrp.AssemblyLinearVelocity = Vector3.new(0, cur.Y, 0)
		end
		if char.Parent then char:SetAttribute("MechaDashLocal", "idle") end
	end)
end
char:GetAttributeChangedSignal("DashStartedAt"):Connect(function()
	local s = char:GetAttribute("DashStartedAt")
	if s == lastDash then return end
	lastDash = s
	if char:GetAttribute("DashSpeedMul") ~= nil then boost() else dash() end -- v1.1
end)

-- PC keys ------------------------------------------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	for n, k in ipairs(KEYS) do -- v1.1: R / C (was 1 / 2); v1.4: + T / V (slots 3 / 4)
		if input.KeyCode == k then press(n, input) break end
	end
end)
UserInputService.InputEnded:Connect(function(input) -- v1.8: let go of the key / touch that started a Screech aim
	if aim and not aim.gesture then
		if (aim.input and input == aim.input) or (input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode == KEYS[aim.slot]) then
			aimRelease()
		end
	end
end)

-- v1.1: "new ability" popup ----------------------------------------------------------------------------------------
local pgNews = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:FindFirstChild("SkillShared")
local okST, ST = pcall(function() return require(shared:WaitForChild("SkillTree", 10)) end)
local isTouch = UserInputService.TouchEnabled
local function showNews(id)
	local p = okST and ST.PATHS[id]
	if not p then return end
	local slot
	for n = 1, 4 do if slotPart(n) == id then slot = n break end end -- v1.4: 4 slots
	local how = not slot and "Put it in a LOADOUT slot (SKILLS)"
		or isTouch and (slot <= 2 and "Tap its button to use it" or "Tap and pull down its button to use it")
		or ("Press %s to use it"):format(KEY_NAMES[slot])
	local old = pgNews:FindFirstChild("MechaNews")
	if old then old:Destroy() end
	local g = Instance.new("ScreenGui")
	g.Name = "MechaNews"
	g.ResetOnSpawn = true
	g.DisplayOrder = 25
	local f = Instance.new("Frame")
	f.Name = "Box"
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.Position = UDim2.new(0.5, 0, 0, 60)
	f.Size = UDim2.fromOffset(320, 70)
	f.BackgroundColor3 = PANEL
	f.BackgroundTransparency = 0.1
	f.Parent = g
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = f
	local st = Instance.new("UIStroke")
	st.Color, st.Thickness = ORANGE, 2.5
	st.Parent = f
	local function line(text, y, h, size, color)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(12, y)
		l.Size = UDim2.new(1, -24, 0, h)
		l.Font = Enum.Font.FredokaOne
		l.Text = text
		l.TextSize = size
		l.TextColor3 = color
		l.Parent = f
		return l
	end
	line("⚙ NEW: " .. string.upper(p.name), 8, 28, 22, ORANGE).Name = "Title"
	line(how, 38, 22, 16, Color3.new(1, 1, 1)).Name = "How"
	g.Parent = pgNews
	char:SetAttribute("MechaNewsShown", id)
	task.delay(4, function() if g.Parent then g:Destroy() end end)
end
local known = {}
if okST then
	for id in pairs(ST.BUTTONS or {}) do known[id] = player:GetAttribute("SkillPath_" .. id) or 0 end
	player.AttributeChanged:Connect(function(name)
		local id = name:sub(1, 10) == "SkillPath_" and name:sub(11) or nil
		if not id or known[id] == nil then return end
		local n = player:GetAttribute(name) or 0
		local was = known[id]
		known[id] = n
		if was == 0 and n >= 1 then
			task.delay(0.3, function() showNews(id) end) -- the slot (SkillSlot1..4) arrives with the same buy
		end
	end)
end

-- test hook: script attribute MechaButtonsForceTouch = true draws the touch buttons on PC too (Studio layout checks)
if not UserInputService.TouchEnabled and script:GetAttribute("MechaButtonsForceTouch") ~= true then
	char:SetAttribute("MechaButtonsState", "keys")
	return
end
char:SetAttribute("MechaButtonsState", "on")

-- touch buttons ------------------------------------------------------------------------------------------------------
local pg = player:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("MechaButtons")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "MechaButtons"
gui.ResetOnSpawn = true
gui.DisplayOrder = 5

local function label(parent, text, pos, size, maxSize, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position, l.Size = pos, size
	l.Font = Enum.Font.FredokaOne
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = l
	return l
end

local slots = {}
local draw -- v1.4: forward
-- v1.4: tap-and-pull gesture ------------------------------------------------------------------------------------------
local function pullOn() return script:GetAttribute("MechaButtonsPullEnabled") ~= false end
local gesture -- {n, input, y0, pulling, px}
local function setPulling(on)
	local s = gesture and slots[gesture.n]
	if not s or gesture.pulling == on then return end
	gesture.pulling = on
	if on then
		s.stroke.Color, s.stroke.Transparency, s.stroke.Thickness = Color3.new(1, 1, 1), 0, 4
		s.pull.TextColor3, s.pull.TextTransparency = Color3.new(1, 1, 1), 0
	else
		s.stroke.Thickness = 2.5
		s.pull.TextColor3 = PULL_COLOR
		draw()
	end
end
local function beginGesture(n, input)
	local s = slots[n]
	local h = s and s.b.AbsoluteSize.Y or 60
	local px = math.clamp(0.22 * h, 14, 24)
	gesture = {n = n, input = input, y0 = input.Position.Y, pulling = false, px = px}
	char:SetAttribute("MechaButtonsPullPx", math.floor(px * 10 + 0.5) / 10)
	if aimedPart(slotPart(n)) then aimStart(n, input, true) end -- v1.8: aim the tap slot until it becomes a pull (v1.20: + tether)
end
local function endGesture()
	local g = gesture
	if not g then return end
	local pulled = g.pulling
	setPulling(false)
	gesture = nil
	local s = slots[g.n]
	if s then s.scale.Scale = 1 end
	char:SetAttribute("MechaButtonsLastGesture", pulled and "pull" or "tap")
	local chosen = pulled and g.n + 2 or g.n
	if aimedPart(slotPart(chosen)) then -- v1.8: the release fires the aimed Screech (v1.20: + tether)
		char:SetAttribute("MechaButtonsLastPress", ("slot%d:%s"):format(chosen, slotPart(chosen)))
		if aim and aim.slot == chosen then aimRelease() else aimCancel() end
		return
	end
	aimCancel()
	press(chosen)
end
UserInputService.InputChanged:Connect(function(input)
	if not gesture then return end
	if input == gesture.input or (gesture.input.UserInputType == Enum.UserInputType.MouseButton1
		and input.UserInputType == Enum.UserInputType.MouseMovement) then
		if aim and aim.gesture and aim.origin then -- v1.12: thumb aim; once locked the drag aims, no pull
			local d = Vector2.new(input.Position.X, input.Position.Y) - aim.origin
			if not aim.locked and (os.clock() >= aim.lockAt or math.abs(d.X) > AIM_DEAD or d.Y < -AIM_DEAD) then
				aim.locked = true
			end
			if aim.locked then
				aim.stick = d
				return
			end
		end
		setPulling(input.Position.Y - gesture.y0 >= gesture.px)
		local want = gesture.pulling and gesture.n + 2 or gesture.n -- v1.8: aim the slot the gesture would fire
		if aimedPart(slotPart(want)) then -- v1.20: + tether
			if not (aim and aim.slot == want) then aimStart(want, gesture.input, true) end
		elseif aim and aim.gesture then
			aimCancel()
		end
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if gesture and input == gesture.input then endGesture() end
end)

for n = 1, 2 do
	local b = Instance.new("TextButton")
	b.Name = "Slot_" .. n
	b.AnchorPoint = Vector2.new(1, 1)
	b.Size = UDim2.fromScale(SIZE, SIZE)
	b.SizeConstraint = Enum.SizeConstraint.RelativeXX
	b.BackgroundColor3 = PANEL
	b.BackgroundTransparency = 0.3
	b.AutoButtonColor = false
	b.Text = ""
	b.ClipsDescendants = true
	b.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.22, 0)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	local cd = Instance.new("Frame")
	cd.Name = "Cooldown"
	cd.AnchorPoint = Vector2.new(0, 1)
	cd.Position = UDim2.fromScale(0, 1)
	cd.Size = UDim2.fromScale(1, 0)
	cd.BackgroundColor3 = Color3.new(0, 0, 0)
	cd.BackgroundTransparency = 0.45
	cd.BorderSizePixel = 0
	cd.Parent = b
	local cdCorner = Instance.new("UICorner") -- ClipsDescendants does not follow the button's rounded corners
	cdCorner.CornerRadius = UDim.new(0.22, 0)
	cdCorner.Parent = cd
	local main = label(b, "DASH", UDim2.fromScale(0.1, 0.3), UDim2.fromScale(0.8, 0.4), 18)
	main.Name = "Main"
	local sub = label(b, "", UDim2.fromScale(0.1, 0.68), UDim2.fromScale(0.8, 0.22), 11)
	sub.Name = "Sub"
	sub.TextTransparency = 0.25
	local pull = label(b, "", UDim2.fromScale(0.04, 0.78), UDim2.fromScale(0.92, 0.16), 12, PULL_COLOR) -- v1.4
	pull.Name = "Pull"
	local key = label(b, UserInputService.TouchEnabled and "" or KEY_NAMES[n], UDim2.fromScale(0.08, 0.04), UDim2.fromScale(0.22, 0.22), 10, -- v1.1: R / C
		Color3.fromRGB(154, 160, 173))
	key.Name = "Key"
	local pips = Instance.new("Frame")
	pips.Name = "Pips"
	pips.BackgroundTransparency = 1
	pips.AnchorPoint = Vector2.new(1, 0)
	pips.Position = UDim2.fromScale(0.92, 0.07)
	pips.Size = UDim2.fromScale(0.4, 0.12)
	pips.Parent = b
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.Padding = UDim.new(0.08, 0)
	list.Parent = pips
	local pipFrames = {}
	for i = 1, 2 do
		local p = Instance.new("Frame")
		p.Name = "Pip_" .. i
		p.Size = UDim2.fromScale(1, 1) -- a circle as tall as the pip row
		p.SizeConstraint = Enum.SizeConstraint.RelativeYY
		p.BorderSizePixel = 0
		p.Parent = pips
		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(0.5, 0)
		pc.Parent = p
		pipFrames[i] = p
	end
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		scale.Scale = 0.92
		if pullOn() and slotPart(n + 2) then -- v1.4: decide on release
			beginGesture(n, input)
		else
			char:SetAttribute("MechaButtonsLastGesture", "press")
			press(n, input)
		end
	end)
	b.InputEnded:Connect(function() scale.Scale = 1 end)
	slots[n] = {b = b, stroke = stroke, cd = cd, main = main, sub = sub, pull = pull, pips = pipFrames, scale = scale}
end

local function layout()
	local spots = SPOTS[char:GetAttribute("AutoRun") == true]
	for n, s in ipairs(slots) do
		s.b.Position = UDim2.new(1 - spots[n][1], 0, 1 - spots[n][2], 0)
	end
end

draw = function()
	local ready = char:GetAttribute("DashEnabled") == true
	local max = math.clamp(tonumber(char:GetAttribute("DashCharges")) or 0, 0, 2)
	local left = tonumber(char:GetAttribute("DashChargesLeft")) or 0
	for n, s in ipairs(slots) do
		if gesture and gesture.n == n and gesture.pulling then continue end -- v1.4: keep the pulling look
		local id = slotPart(n)
		if id == "cloak" or TIMED_PARTS[id] or (LEGS_BTN and id == "mechalegs") or (BLOOD_BTN and id == "bloodrush") then ready = (partState(id)) else ready = char:GetAttribute("DashEnabled") == true end -- v1.4; v1.5: + timed parts; v1.16: + legs
		if id then
			s.stroke.Color, s.stroke.Transparency = ORANGE, ready and 0 or 0.5
			s.main.Text = partName(id) -- v1.4 (was: thrusters -> DASH, else the id)
			s.main.TextTransparency = ready and 0 or 0.5
			s.sub.Text = ""
			for i, p in ipairs(s.pips) do
				p.Visible = id == "thrusters" and i <= max -- v1.4: pips are the dash charges only
				p.BackgroundColor3 = i <= left and ORANGE or Color3.fromRGB(85, 85, 85)
			end
		else
			s.stroke.Color, s.stroke.Transparency = Color3.new(1, 1, 1), 0.5
			s.main.Text, s.main.TextTransparency = "+", 0.4
			s.sub.Text = "slot " .. n
			for _, p in ipairs(s.pips) do p.Visible = false end
			s.cd.Size = UDim2.fromScale(1, 0)
		end
		-- v1.4: pull part sub-label
		local pid = pullOn() and slotPart(n + 2) or nil
		if pid then
			local pready = partState(pid)
			s.pull.Text = "▼ " .. partName(pid)
			s.pull.TextTransparency = pready and 0 or 0.5
			if not id then s.sub.Text = "" end
		else
			s.pull.Text = ""
		end
	end
end

local lastCloakReady -- v1.4: redraw when the cloak's readiness flips (cooldown runs out)
local lastTimedReady = {} -- v1.5: the same for the timed parts
RunService.RenderStepped:Connect(function()
	local nextAt = tonumber(char:GetAttribute("DashNextChargeAt")) or 0
	local rc = tonumber(char:GetAttribute("DashRecharge")) or 8
	local frac = 0
	if nextAt > 0 and rc > 0 then frac = math.clamp((nextAt - workspace:GetServerTimeNow()) / rc, 0, 1) end
	local cReady, cFrac = partState("cloak") -- v1.4
	local redraw = false
	for n, s in ipairs(slots) do
		local id = slotPart(n)
		local tFrac = 0
		if id and (TIMED_PARTS[id] or (LEGS_BTN and id == "mechalegs") or (BLOOD_BTN and id == "bloodrush")) then -- v1.5; v1.16: + legs; v1.17: + blood
			local r, f = partState(id)
			tFrac = f
			if r ~= lastTimedReady[id] then lastTimedReady[id] = r; redraw = true end
		end
		s.cd.Size = UDim2.fromScale(1, id == "thrusters" and frac or id == "cloak" and cFrac or tFrac)
	end
	if cReady ~= lastCloakReady then lastCloakReady = cReady; redraw = true end
	if redraw then draw() end
end)

local WATCH = {DashEnabled = true, DashCharges = true, DashChargesLeft = true, AutoRun = true,
	CloakEnabled = true, CloakState = true, CloakReadyAt = true} -- v1.4: + cloak
WATCH.MechaLegsEnabled, WATCH.JumpPredictedAt = true, true -- v1.16
WATCH.BloodRushEnabled, WATCH.HeadbuttChargesNow, WATCH.HeadbuttSacrifices = true, true, true -- v1.17
for _, tp in pairs(TIMED_PARTS) do -- v1.5
	for _, k in ipairs({"Enabled", "Until", "ReadyAt"}) do WATCH[tp[1] .. k] = true end
end
char.AttributeChanged:Connect(function(name)
	if name == "AutoRun" then layout() end
	if WATCH[name] then draw() end
end)
player.AttributeChanged:Connect(function(name)
	if name:sub(1, 9) == "SkillSlot" then draw() end -- v1.4: slots 1-4 (was 1 / 2)
end)
layout()
draw()
gui.Parent = pg
