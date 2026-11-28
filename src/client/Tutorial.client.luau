-- Tutorial v1.1 (Mecha Dino Arena) — the first-time flow's screens (LocalScript, StarterPlayerScripts). MDA-563, plan
-- docs/plans/FIRST_TIME_FLOW_v1.0.md Task 5 + "v1.1 redesign", ADR-013, mockup docs/mockups/first_time_flow_v0.4.html.
-- v1.1 (Kepu 2026-11-22 11:38, after playing 1.0 live on his phone: "unplayable and unprofessional ... The teno has two different
--   attack styles and it doesn't even teach you it ... Look at how big time games handle this ... layout on mobile and spacing";
--   12:09 "Build" on mockup v0.4). A rewrite of the screens; the server flow (TutorialServer 1.1) and every request stay the same.
-- Runs while ReplicatedStorage.TutorialRequest exists. Draws from the player attribute TutStep (0 = hidden).
-- ScreenGui "Tutorial": DisplayOrder 45 (over the game HUD, under EggLoader 100), IgnoreGuiInset, ResetOnSpawn false.
--   u = min(screen width, screen height x 1.9) / 100 (the mockup's 1 cqw on a phone). Text never below its minimum pixel size.
--   Nothing is placed under the Roblox buttons: content starts below GuiService.TopbarInset (its height; 58 px if 0), and the
--   objective box sits top-centre, narrower than the space right of the Roblox buttons (TopbarInset.Min.X).
-- Fonts: titles / buttons FredokaOne with FontSwap = "silk" (Silkscreen, like the rest of the game); every sentence
--   GothamBold / GothamBlack with FontSwap = "keep" (one body font, never mixed; ✓ / ★ / ▼ draw in these, checked live in 1.0).
-- Full-screen moments (opaque backdrop, the game HUD hidden under it):
--   steps 1-2 egg: "MECHA DINO ARENA" / "YOUR FIRST DINO" / "It's free. Tap the egg." A cream egg on a glowing stand, 3 dots;
--     each tap shakes it and adds a crack; the 1st tap sends "next" (step 1); the 3rd hatches it: flash, then "roll" (re-sent
--     every 0.8 s until TutRolled is set).
--   step 2 rolled: "IT HATCHED" + the dino's 3D model (ReplicatedStorage.PregameModels[dino] in a ViewportFrame) in a yellow
--     frame, its role chip (TutorialRules.ROLE), its name, "MAIN ATTACK" and one line per lesson (how + tip); NEXT.
--   step 3: "<DINO>'S GEAR" / "<n> MECHA PARTS" / "All maxed. They're yours." Part cards dealt in (orange "MAXED ★"; passive
--     parts grey "PASSIVE ★"); START TRAINING (TutLastResult "full" -> "Training is full. Trying again." + a new "next" every 3 s).
--   step 7 after TutKilled: "LEVEL UP" / the level / "+1 skill point" / SPEND IT (replay: "BOT DOWN" / "No XP in a replay." / NEXT).
--   step 9: "HOW YOU GET STRONGER" / "SKILL POINTS" / "1 every level. Kills give XP." + 3 tiles; GOT IT.
--   step 10: "TRAINING COMPLETE" / "LEVEL <n> <DINO>" / "<k> parts equipped"; GO TO THE ISLAND.
-- Training (4, 6, 7) and sheets (5, 8): the objective box top-centre ("STEP n/5", the goal, the lessons of step 4 with ticks, one
--   tip line, 5 progress bars). Phone: a pulsing yellow ring, a finger (tap / hold / pull) and a yellow callout on the REAL control
--   (ArenaTouch's visible main attack button; MechaButtons Slot_1 / Slot_2); PC: the callout above the AbilityBar with the key.
--   Step 4 hides the phone's other buttons (ArenaTouch Leap, MechaButtons slots) and puts them back after (only what it hid).
--   4: one lesson at a time (TutLesson / TutLessonsDone); a tick toast per lesson; moves on by itself (server).
--   5: bottom sheet: left the 2 real buttons, each a TAP socket and a PULL socket (PC: 4 keys); right the parts as cards
--      (tap -> SkillRequest("slot", first empty, id); tap a full socket -> clear it); TRY THEM.
--   6: ring + finger + callout on the button of the next unused part (tap for 1 / 2, pull down for 3 / 4); every
--      MechaButtonsLastPress "slot<n>:<part>" sends "used", n (re-sent every 0.5 s until the server has it); moves on by itself.
--   7: "Finish it. Use anything."; the bot's health bar.
--   8: bottom sheet: points box + the dino's stat rows with +; NEXT once a point is spent ("No points to spend." on a replay).
-- Bot marks (steps 4, 6, 7): yellow outline (Highlight) and arrow; health bar at step 7.
-- Switch: script attribute TutorialClientEnabled (default true, read at start). Diagnostics: script TutorialClientVersion;
--   player TutClientStep.
-- v1.2 (Kepu 2026-11-22 13:13 "that egg hatch and reveal looks like shit", 13:22 "I like B" on docs/mockups/egg_hatch_v0.1.html):
--   steps 1-2 are the Incubator while script attribute TutorialIncubatorEnabled ~= false (default true, read per draw; false =
--   the 1.1 egg and reveal card). Egg: a 3D egg (cream, steel belt with a cyan seam) floats in a glass pod on a lit base, cyan
--   light rays turn behind it; "YOUR FIRST DINO" / "It's free. Press and hold." and a yellow HOLD TO HATCH button with 24 lights
--   around it. Holding fills it in TutHatchHold (script attribute, 1.2 s; letting go drains it in half that): the egg shakes,
--   cracks glow (at 1/3 and 2/3), the seam turns yellow, the rays speed up. Full: flash, the glass and cap fly up, shell bits fly
--   out, then (0.7 s) "next" / "roll" as 1.1. While the roll is on its way: the empty pod and "HATCHING". Reveal (TutRolled):
--   the dino (PregameModels body + its free parts, turning slowly) on the pod base, left; it starts black and a cyan scan line
--   colors it in; right a panel: "FREE DINO UNLOCKED", the name, the role chip, "MAIN ATTACK" and one row per lesson (a round
--   TAP / HOLD / key badge, the name, the tip), NEXT. Played once; a redraw of the same scene (same step, roll and screen size)
--   is skipped so nothing restarts.
-- v1.3 (Kepu 2026-11-22 13:47 "These screens don't make no damn sense. Nothing like how the actual equip screens actually look
--   or the stats screen", 13:59 "A" on docs/mockups/lab_coach_v0.1.html): steps 5 (equip) and 8 (spend) run on the REAL Lab
--   while script attribute TutorialLabCoachEnabled ~= false (default true, read per draw; false = the 1.1 sheets). The step
--   opens the compact Lab (PlayerScripts.Lab.Open:Invoke("compact"), the SKILLS button's screen; opened again if closed early)
--   and a coach layer (ScreenGui "TutorialCoach", DisplayOrder 47, over the Lab's 45) darkens everything but the next Lab
--   button (4 dark buttons around a hole, so other taps do nothing), with a yellow ring, a finger and a tag; a chip at the top
--   centre reads "STEP 2/5 EQUIP 4 PARTS 0/4" / "STEP 5/5 SPEND YOUR POINT 1 PT". Lab buttons are found by name every frame
--   (Card_<id>, Tabs.Parts / Tabs.Stats, Right.Detail.Actions.Btn with label T "EQUIP" / "BUY ..." / "UPGRADE ...", Slot_n,
--   Close); the Lab's Grid / Detail scroll is moved so the target is in view. The Lab's code is not changed.
--   Equip: TAP ABILITIES (wrong tab) -> TAP A PART (first not-equipped button part) -> TAP EQUIP (after LabLastPress
--   "card:<id>") -> 1.6 s tag on the slot it landed in ("R = BUTTON 1" / "TAP · 1/4 EQUIPPED"; PC "KEY R") -> again until
--   TutNeed slots are filled -> CLOSE "4/4 EQUIPPED"; the Lab closed with the slots full sends "next" (1.1: TRY THEM).
--   Spend: TAP STATS -> TAP A STAT (the first of this dino's stat rows not maxed) -> TAP BUY "-1 PT" -> CLOSE "STAT +1"; the
--   Lab closed after the buy (or on a replay with 0 points: CLOSE "0 POINTS") sends "next".
-- v1.4 (Kepu 2026-11-22 15:05 "the equip part of the tutorial is buggy. It keeps making me equip into the same slots over and
--   over again"; "showcase all the Dino's before I go to the egg screen so I can see what I can get"):
--   * Equip fix. Cause: the 1.6 s slot tag spotlit the slot with a finger, a tap there selected that slot in the Lab
--     (LabSlotSel), and the Lab's EQUIP fills the selected slot before an empty one, so the next part replaced it, and the
--     tag spotlit that slot again. Now the slot tag has no finger and its hole takes no taps (a clear button covers it), and
--     when a filled slot is selected the coach points at the first empty slot instead of EQUIP (a slot tap with a new part
--     selected equips there): tag "TAP C" / "C = BUTTON 2" (PC "TAP KEY C").
--   * Dino showcase before the egg (step 1, script attribute TutorialShowcaseEnabled, default true): "MECHA DINO ARENA" /
--     "YOUR FIRST DINO" / "1 OF THESE 7 · FREE", the roll pool (TutorialRules.ROLL_POOL) as cards dealt in left to right,
--     each with its 3D model (PregameModels body + its parts) turning, its name and role chip; NEXT opens the egg. Client
--     only (the server step stays 1); seen once per join.
-- v1.5 (Kepu 2026-11-22 20:15 "the presentation screen for the 7 Dino's could be better, look at how other games handle
--   this"; 20:26 "I like A with explanations of the attacks for each Dino and how they work/abilities"; 21:32 "Make it sound
--   like a damn video game"; 21:36 "more specific with damage as well as duration/effects"; 21:42 "Build" on mockup
--   docs/mockups/dino_showcase_v0.4.html): the showcase becomes a select screen (drawShowcase2). Left: "MECHA DINO ARENA" /
--   "YOUR FIRST DINO" / "1 OF THESE 7 · FREE" below the Roblox buttons, the roll pool by role (HOLDER / FIGHTER / RANGED, as
--   PregameScreen ROLE_GROUPS) as 3D tiles. Middle: the picked dino (PregameModels body + all its parts) turning over a base
--   ringed in its role color, one dot per dino, NEXT (to the egg, as 1.4). Right: name, role chip, "1 IN 7"; MAIN ATTACK cards
--   (name, TAP / HOLD / TAP x3 badge (PC: CLICK, Raptor F), one line, stat chips); ABILITIES · n = every live mecha part of
--   that dino (partsOf given, the free dino gets them all, maxed) as rows: name, type (ATTACK / CONTROL / DEFENSE / HEAL / MOVE
--   / SUPPORT / STEALTH / SCOUT / PASSIVE, colored), headline stat; the open ability's card at the bottom: name, type chip,
--   one line, stat chips. The first ability is open; a tap on a row opens it. The screen moves to the next dino every
--   TutShowcaseCycle s (5) and waits TutShowcaseHold s (10) after any tap. Numbers: abilities = SkillTree.effects with every
--   part at step 4 (read in Studio Edit); main attacks = the dino's ModelData attributes. Switch: script attribute
--   TutorialShowcaseCardsEnabled (default true; false = the 1.4 cards). Diagnostic: player attribute TutShowcaseDino.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local VERSION = "1.1"
VERSION = "1.2" -- v1.2 incubator egg + scan reveal
VERSION = "1.3" -- v1.3 equip / spend on the real Lab (coach)
VERSION = "1.4" -- v1.4 equip slot fix + dino showcase
VERSION = "1.5" -- v1.5 showcase select screen + attack / ability cards
VERSION = "1.6" -- v1.6 Lab coach on Lab 2.0 (Lab Revamp v1.0)
-- v1.6 (Lab Revamp v1.0 Task 7, MDA-590, plan docs/plans/LAB_REVAMP_v1.0.md red-team R1): while the Lab is 2.0 or newer
--   (player LabVersion) and script attribute TutorialLab2Enabled ~= false (default true, read per frame), the equip and spend
--   coach steps point at Lab 2.0's buttons (the 1.3 / 1.4 targets stay for an older Lab):
--   * equip (ABILITIES): the detail sheet open (player LabSheet) -> "TAP BACK" on its Back button; a filled slot selected ->
--     "TAP CANCEL" (Lab 2.0 would put the part over it); else the first of this dino's button parts that is not in a slot and
--     whose card button (Card_<id>.Actions.Btn) reads EQUIP or PUT ON -> "TAP EQUIP" / "TAP PUT ON <key>" with "n/N EQUIPPED".
--     The slot tag after each equip (1.4: no finger, no tap) as before.
--   * spend (STATS): the sheet open -> "TAP BACK"; else the first stat row not maxed whose own button (Card_<id>.Actions.Btn)
--     reads BUY / UPGRADE -> "TAP BUY" / "TAP UPGRADE", "-1 PT".
--   The buttons are found under that card (Lab 2.0 has an Actions frame on every card; 1.3's labActionBtn took the first).
VERSION = "1.7" -- v1.7 welcome screen, dino passives, JUMP parts in step 6
VERSION = "1.7.1" -- v1.7.1 the reveal's dino fits (wider camera)
VERSION = "1.8" -- v1.8 the tutorial ends with the first match
VERSION = "1.9" -- v1.9 welcome FIGHT tile: 4v4 Arena matches
VERSION = "1.10" -- v1.10 unlock-only copy + level-1 ability cards
-- v1.10 (unlock-only progression, MDA-617, plan docs/plans/UNLOCK_ONLY_v1.0.md Task 5, ADR-016): while the player's SkillUnlockOnly is
--   true and script attribute TutUnlockCopyEnabled ~= false (read per draw): the gear sheet reads "All unlocked. They're yours." and
--   its part cards "UNLOCKED" (1.9: "All maxed." / "MAXED ★"); the showcase ability cards keep their type and line but drop the
--   stat chips (they were the step-4 numbers; parts are level 1 now). Passive cards unchanged. The welcome screen's middle tile reads
--   UNLOCK "Mecha parts with your points" (1.9: UPGRADE "Mecha parts and skill points").
-- v1.9 (bug hunt 2026-11-27 item 3; Kepu 16:49 "Okay let's do those", copy "FIGHT · 4v4 Arena matches"): while script attribute
--   TutWelcomeArenaCopyEnabled ~= false (default true, read per draw) the welcome screen's FIGHT tile reads "4v4 Arena matches"
--   (1.8: "Squad battles on the island"; no island bots since v1086). Layout, the other two tiles unchanged. false = 1.8.
-- v1.8 (First Steps v1.0, Kepu 2026-11-27 14:15 pick "A" on docs/mockups/first_steps_v0.1.html, capture first_steps_v0.1/
--   phone_tutorial_end.jpg): while script attribute TutFirstMatchEnabled ~= false (default true, read per draw) step 10 reads
--   "TRAINING COMPLETE" / "LEVEL <n> <DINO>" / "Next: a real 4v4 match. Bots fill empty seats." with PLAY YOUR FIRST MATCH (yellow;
--   sets the LOCAL player attribute FsAutoQueue = true, then sends "island" as before; FirstSteps 1.0 joins the Arena queue once the
--   dino stands on the islet) and under it EXPLORE THE ISLAND FIRST (no fill, muted text, no outline; sends "island" only).
--   TutFirstMatchEnabled false = 1.7.1 (GO TO THE ISLAND).
-- v1.7.1 (Kepu 2026-11-26 03:05 live, Therizino "cut off at the top"): drawReveal sets its dino view's camera FieldOfView to the
--   script attribute TutRevealFov (default 44; dinoView's own 30 cut Therizino, Pachy, Teno and Dilo over a turn, measured in
--   Studio). Switch: script attribute TutorialRevealFitEnabled (default true, read per draw; false = 1.7).
-- v1.7 (plan docs/plans/WELCOME_MOVES_v1.0.md, MDA-594..597, mockup docs/mockups/welcome_moves_v0.2.html; Kepu 2026-11-26 after his
--   first-time walkthrough: "the tutorial didn't explain that wings work through the jump button ... can climb up trees ... a
--   welcome to mecha Dino, then a here's our roster screen"; picks "A", "Just have the climbing ability in the description of
--   the Dino attack ability as a passive", "for mecha parts that's just a different mechanic to use it", "Show SKIP after
--   20 s"; "Build" 02:36). State lives in the script-global table WM (the main chunk is near its local limit).
--   * Welcome (MDA-594, script attribute TutorialWelcomeEnabled, default true, read per draw): at step 1, before the roster
--     (the 1.5 showcase), while showcaseOn(): "WELCOME TO" / "MECHA DINO ARENA" ("DINO" yellow), 3 tiles dealt in (FIGHT
--     "Squad battles on the island", UPGRADE "Mecha parts and skill points", COLLECT "7 dinos, skins, emotes, trails"),
--     LET'S GO -> WM.welcomed = true -> the roster. Client only, once per join (like the roster). Scene key "welcome".
--   * Roster (MDA-595): TutorialRosterTitleEnabled: "MEET THE ROSTER" / "1 OF THESE 7 IS YOURS FREE" (was "YOUR FIRST DINO" /
--     "1 OF THESE 7 · FREE"); TutorialRosterPassiveEnabled: a PASSIVE section under MAIN ATTACK with one card per
--     TutorialRules 1.3 passivesFor(dino) (green bar, name, tag chip PASSIVE / ON JUMP, the line on 2 rows at most); none
--     for a dino without one. The ABILITIES list gets the height that is left (min as 1.5).
--   * Reveal (MDA-596, TutorialRevealPassiveEnabled): "PASSIVE" (green) + one row per passive under MAIN ATTACK (a green tag
--     pill, the name, the line). Fit: if the panel's content is taller than the panel, the line steps down to 12 px, then
--     is cut to one row (NEXT is never pushed out).
--   * JUMP parts in step 6 (MDA-597, TutorialJumpPartsEnabled): for a slot (1..TutNeed) holding a TutorialRules 1.3 JUMP part
--     (Glider Wings, Mecha Legs, Hydraulic Leap; their slot buttons do nothing, MechaButtons), a slot press no longer counts
--     (tip for 2 s: "That button does nothing for <part>. It works on JUMP."); the part counts when its stamp changes on the
--     character (GlideStartedAt / JumpDoubleAt / JumpStartedAt with TenoLeapOnJump true) -> "used", n. Coach: touch = ring +
--     finger + callout left of ArenaTouch's JUMP button ("Leap"; callout only if it is missing or hidden), PC = the callout
--     with the key words; tip = the part's line. After TutJumpPartSkipAfter (20) s on the same part: " Or tap SKIP." and a
--     SKIP button inside the objective box -> "used", n (WM.markUsed). Other parts: as 1.6.
script:SetAttribute("TutorialClientVersion", VERSION)
if script:GetAttribute("TutorialClientEnabled") == nil then script:SetAttribute("TutorialClientEnabled", true) end
if script:GetAttribute("TutorialClientEnabled") == false then return end

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("TutorialRequest", 60)
if not remote then return end
local R = require(ReplicatedStorage:WaitForChild("TutorialShared"):WaitForChild("TutorialRules"))
local ST = require(ReplicatedStorage:WaitForChild("SkillShared", 60):WaitForChild("SkillTree"))
local skillRemote = ReplicatedStorage:WaitForChild("SkillRequest", 30)

local C = {
	bg = Color3.fromRGB(11, 15, 22), glow = Color3.fromRGB(38, 50, 74), panel = Color3.fromRGB(13, 19, 28),
	card = Color3.fromRGB(21, 29, 43), line = Color3.fromRGB(42, 52, 70), yellow = Color3.fromRGB(255, 200, 50),
	yellowDark = Color3.fromRGB(181, 138, 18), ink = Color3.fromRGB(27, 20, 6), white = Color3.new(1, 1, 1),
	text = Color3.fromRGB(223, 230, 240), muted = Color3.fromRGB(138, 149, 168), green = Color3.fromRGB(70, 224, 138),
	orange = Color3.fromRGB(255, 155, 46), cyan = Color3.fromRGB(127, 233, 255), pink = Color3.fromRGB(255, 107, 132),
}
local OBJ = {[4] = "ATTACK", [5] = "EQUIP 4 PARTS", [6] = "USE EACH PART", [7] = "DEFEAT THE BOT", [8] = "SPEND YOUR POINT"}
local SLOT_KEYS = {"R", "C", "T", "V"}
local ATTACK_BUTTONS = {"Bite", "PounceMain", "HeadbuttMain", "SlashMain", "TenoMain", "TheriMain", "DiloMain", "TrooMain"}

local gui = Instance.new("ScreenGui")
gui.Name = "Tutorial"
gui.DisplayOrder = 45
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundTransparency = 1
root.Size = UDim2.fromScale(1, 1)
root.Parent = gui

-- ---------- helpers ----------
local u, W, H, topH, freeLeft = 8, 800, 400, 58, 300
local function measure()
	W, H = root.AbsoluteSize.X, root.AbsoluteSize.Y
	if W < 10 then W, H = workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y end
	u = math.min(W, H * 1.9) / 100
	local ok, rect = pcall(function() return GuiService.TopbarInset end)
	topH = ok and rect and rect.Height > 0 and rect.Max.Y or 58
	freeLeft = ok and rect and rect.Min.X > 0 and rect.Min.X or math.min(W * 0.32, 300)
end
local function px(n, min) return math.max(n * u, min or 0) end
local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) return make("UICorner", {CornerRadius = r or UDim.new(0, px(1, 6))}, o) end
local function stroke(o, c, th, t) return make("UIStroke", {Color = c, Thickness = th or 2, Transparency = t or 0,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o) end
local function pad(o, t, r, b, l) make("UIPadding", {PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r or t),
	PaddingBottom = UDim.new(0, b or t), PaddingLeft = UDim.new(0, l or r or t)}, o) end
local function list(o, dir, gap, align)
	return make("UIListLayout", {FillDirection = dir or Enum.FillDirection.Vertical, Padding = UDim.new(0, gap or 0),
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder}, o)
end
-- kind: "title" (FredokaOne -> Silkscreen), "black" / "body" (GothamBlack / GothamBold, kept as Gotham)
local function text(parent, s, kind, size, color, props)
	local font = kind == "title" and Enum.Font.FredokaOne or kind == "black" and Enum.Font.GothamBlack or Enum.Font.GothamBold
	local l = make("TextLabel", {BackgroundTransparency = 1, Text = s, Font = font, TextSize = size, TextColor3 = color or C.white,
		RichText = true, TextWrapped = kind ~= "title", AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new()}, parent)
	l:SetAttribute("FontSwap", kind == "title" and "silk" or "keep")
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end
local function cta(parent, s, onClick, props)
	local b = make("TextButton", {AutoButtonColor = true, BackgroundColor3 = C.yellow, Text = s, Font = Enum.Font.FredokaOne,
		TextSize = px(2.3, 18), TextColor3 = C.ink, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, px(5.4, 44)),
		Modal = true}, parent)
	b:SetAttribute("FontSwap", "silk")
	corner(b, UDim.new(0, px(1.2, 8)))
	pad(b, 0, px(3.6, 22))
	stroke(b, C.yellowDark, px(0.35, 2))
	for k, v in pairs(props or {}) do b[k] = v end
	b.Activated:Connect(onClick)
	return b
end
local function isTouch() return UserInputService.TouchEnabled end
local function step() return tonumber(player:GetAttribute("TutStep")) or 0 end
local function dinoKey()
	local c = player.Character
	local s = c and c:GetAttribute("Species")
	if type(s) == "string" and s ~= "" then return s end
	s = player:GetAttribute("DinoSpecies")
	return type(s) == "string" and s ~= "" and s or "TRex"
end
local function dinoName(k) return k == "TRex" and "T-Rex" or k end
local function send(action, arg) remote:FireServer(action, arg) end
local function pathStep(id) return tonumber(player:GetAttribute("SkillPath_" .. id)) or 0 end
local function partsOf(dino, buttonsOnly, given) -- v1.1 given: the free dino's parts as SkillServer 1.13 gives them (owned or not yet)
	local out = {}
	for _, id in ipairs(ST.PATH_ORDER) do
		local p = ST.PATHS[id]
		if p and p.mech and ST.LIVE_MECH[id] and not p.soon and (not ST.seesPath or ST.seesPath(p, dino))
			and (not buttonsOnly or ST.BUTTONS[id]) and (given or pathStep(id) >= 1) then
			table.insert(out, id)
		end
	end
	return out
end
local function statsOf(dino)
	local out = {}
	for _, a in ipairs(ST.AREAS) do
		for _, p in ipairs(ST.pathsFor and ST.pathsFor(a.id, dino) or a.paths) do
			if not p.mech and not p.soon then table.insert(out, p.id) end
		end
	end
	return out
end
local function pname(id) local p = ST.PATHS[id] return p and p.name or id end
local function need() return tonumber(player:GetAttribute("TutNeed")) or 4 end
local function slotOf(n) local v = player:GetAttribute("SkillSlot" .. n) return type(v) == "string" and v or "" end
local function usedSet() return R.parseDone(player:GetAttribute("TutUsed")) end
local function howWords(L)
	if isTouch() then
		return L.how == "hold" and "HOLD, THEN LET GO" or L.how == "tap3" and "TAP 3 TIMES" or "TAP"
	end
	if L.key then return "PRESS " .. L.key end
	return L.how == "hold" and "HOLD CLICK, LET GO" or L.how == "tap3" and "CLICK 3 TIMES" or "CLICK"
end
local function howLine(L)
	local w = howWords(L):lower()
	return (w:gsub("^%l", string.upper)) .. ". " .. L.line
end
local function botModel()
	local isl = workspace:FindFirstChild("DinoIsland")
	local ib = isl and isl:FindFirstChild("Bots")
	if ib then
		for _, m in ipairs(ib:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("TutOwner") == player.UserId then return m end
		end
	end
	return nil
end
local function tween(o, t, props, style, dir, rep, rev)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, rep or 0, rev or false), props)
	tw:Play()
	return tw
end

-- ---------- full-screen moments ----------
local function backdrop()
	local bg = make("TextButton", {Name = "Backdrop", Text = "", AutoButtonColor = false, BackgroundColor3 = C.bg, Size = UDim2.fromScale(1, 1),
		Modal = true}, root)
	local g = make("Frame", {BackgroundColor3 = C.glow, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(px(62), px(62))}, bg)
	corner(g, UDim.new(0.5, 0))
	make("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 1)})}, g)
	return bg
end
local function sceneColumn(kicker, title, sub)
	local col = make("Frame", {Name = "Scene", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, topH / 2), Size = UDim2.new(0.9, 0, 1, -topH - px(4))}, root)
	list(col, nil, px(1.2, 8))
	local n = 0
	local function add(o) n += 1 o.LayoutOrder = n return o end
	if kicker then add(text(col, kicker, "title", px(1.8, 14), C.yellow)) end -- v1.1 phone check: sizes up (Silkscreen draws ~0.7x)
	if title then add(text(col, title, "title", px(4.6, 32), C.white)) end
	if sub then add(text(col, sub, "body", px(1.8, 16), C.text)) end
	return col, add
end
local function flash()
	local f = make("Frame", {BackgroundColor3 = C.white, Size = UDim2.fromScale(1, 1), ZIndex = 20, BackgroundTransparency = 0.1}, root)
	tween(f, 0.5, {BackgroundTransparency = 1})
	task.delay(0.6, function() f:Destroy() end)
end
local function toast(s)
	local t = text(root, s, "black", px(2.6, 22), C.green, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, topH + px(10)),
		ZIndex = 15, TextStrokeTransparency = 0.4})
	tween(t, 1.2, {Position = UDim2.new(0.5, 0, 0, topH + px(6)), TextTransparency = 1, TextStrokeTransparency = 1})
	task.delay(1.3, function() t:Destroy() end)
end

-- ---------- the egg (steps 1-2) ----------
local egg = {taps = 0, hatching = false, rollLoop = false}
local render -- below
local function drawEgg()
	backdrop()
	local col, add = sceneColumn("MECHA DINO ARENA", "YOUR FIRST DINO", "It's free. Tap the egg.")
	local holder = add(make("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(px(20), px(20))}, col))
	local stand = make("Frame", {BackgroundColor3 = C.cyan, BackgroundTransparency = 0.75, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -px(1.5)), Size = UDim2.fromOffset(px(18), px(2.6))}, holder)
	corner(stand, UDim.new(0.5, 0))
	stroke(stand, C.cyan, px(0.25, 2), 0.4)
	local e = make("TextButton", {Name = "Egg", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(236, 214, 160),
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -px(1.5)), Size = UDim2.fromOffset(px(12.5), px(16)),
		Modal = true}, holder)
	corner(e, UDim.new(0.5, 0))
	make("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255, 250, 236), Color3.fromRGB(178, 146, 86)), Rotation = 55}, e)
	stroke(e, Color3.fromRGB(255, 220, 140), px(0.3, 2), 0.3)
	local cracks = {{0.18, 0.34, 0.4, -20}, {0.46, 0.52, 0.32, 25}, {0.24, 0.62, 0.5, -8}}
	local function drawCracks()
		for i = 1, math.min(egg.taps, 3) do
			local c = cracks[i]
			make("Frame", {Name = "Crack" .. i, BackgroundColor3 = Color3.fromRGB(91, 70, 40), BorderSizePixel = 0,
				Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.new(c[3], 0, 0, px(0.35, 2)), Rotation = c[4]}, e)
		end
	end
	drawCracks()
	local dots = add(make("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(px(8), px(1.6))}, col))
	list(dots, Enum.FillDirection.Horizontal, px(0.9))
	for i = 1, 3 do
		local d = make("Frame", {BackgroundColor3 = C.yellow, BackgroundTransparency = i <= egg.taps and 0 or 1, Size = UDim2.fromOffset(px(1.4, 10), px(1.4, 10)), LayoutOrder = i}, dots)
		corner(d, UDim.new(0.5, 0))
		stroke(d, C.yellow, px(0.2, 2))
	end
	local hint
	if egg.taps == 0 then
		local d = px(3.4, 26)
		hint = make("Frame", {BackgroundColor3 = C.white, BackgroundTransparency = 0.1, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.66, 0.66), Size = UDim2.fromOffset(d, d), ZIndex = 3}, e)
		corner(hint, UDim.new(0.5, 0))
		tween(hint, 0.5, {Size = UDim2.fromOffset(d * 0.68, d * 0.68)}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	end
	e.Activated:Connect(function()
		if egg.hatching then return end
		egg.taps += 1
		if hint then hint:Destroy() hint = nil end
		for _, ch in ipairs(e:GetChildren()) do if ch.Name:sub(1, 5) == "Crack" then ch:Destroy() end end
		drawCracks()
		for i, d in ipairs(dots:GetChildren()) do
			if d:IsA("Frame") then d.BackgroundTransparency = d.LayoutOrder <= egg.taps and 0 or 1 end
		end
		e.Rotation = 0
		tween(e, 0.06, {Rotation = 8}, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 3, true)
		if egg.taps == 1 and step() == 1 then send("next") end
		if egg.taps >= 3 then
			egg.hatching = true
			task.delay(0.45, function()
				flash()
				if egg.rollLoop then return end
				egg.rollLoop = true
				task.spawn(function()
					while step() > 0 and step() <= 2 and (player:GetAttribute("TutRolled") or "") == "" do
						if step() == 2 then send("roll") elseif step() == 1 then send("next") end
						task.wait(0.8)
					end
					egg.rollLoop = false
					render()
				end)
			end)
		end
	end)
end

-- ---------- the dino's 3D portrait ----------
local function portrait(parent, key, size)
	local f = make("Frame", {BackgroundColor3 = Color3.fromRGB(32, 44, 66), Size = UDim2.fromOffset(size, size)}, parent)
	corner(f, UDim.new(0, px(2, 12)))
	stroke(f, C.yellow, px(0.3, 2))
	-- v1.1: PregameModels.<Dino> is a Folder: Body (Model) + Parts.<id> (PregameModels 1.1); framed like PregameScreen's dinoView
	local models = ReplicatedStorage:FindFirstChild("PregameModels")
	local fold = models and models:FindFirstChild(key)
	local body = fold and fold:FindFirstChild("Body")
	if body and body:IsA("Model") then
		local vf = make("ViewportFrame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(150, 160, 180),
			LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.5, -1, -0.6)}, f)
		local m = Instance.new("Model")
		body:Clone().Parent = m
		local pf = fold:FindFirstChild("Parts")
		for _, id in ipairs(partsOf(key, false, true)) do
			local pm = pf and pf:FindFirstChild(id)
			if pm and pm:GetAttribute("Free") ~= true then pm:Clone().Parent = m end
		end
		for _, d in ipairs(m:GetDescendants()) do if d:IsA("BaseScript") then d:Destroy() end end
		local bcf, bsz = body:GetBoundingBox()
		local sz = body:GetAttribute("BodySize") or bsz
		local minY = body:GetAttribute("BodyMinY") or (bcf.Position.Y - sz.Y / 2)
		m.WorldPivot = CFrame.new(bcf.Position.X, minY, bcf.Position.Z)
		m.Parent = vf
		m:PivotTo(CFrame.Angles(0, math.pi + 0.8, 0))
		local mx = math.max(sz.X, sz.Y * 1.35, sz.Z)
		local d, ty = mx * 1.8, sz.Y * 0.42
		local cam = make("Camera", {FieldOfView = 30}, vf)
		cam.CFrame = CFrame.lookAt(Vector3.new(0, ty + d * 0.22, d), Vector3.new(0, ty, 0))
		vf.CurrentCamera = cam
	else
		text(f, string.upper(dinoName(key)):sub(1, 1), "title", size * 0.4, C.yellow, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5)})
	end
	return f
end

-- ---------- objective box ----------
local function objective(s, tip, lessons)
	local maxW = math.max(W - 2 * freeLeft - px(2), px(30))
	local f = make("Frame", {Name = "Objective", BackgroundColor3 = C.panel, BackgroundTransparency = 0.08, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, px(1.2, 6)), Size = UDim2.fromOffset(math.min(px(36), maxW), 0), AutomaticSize = Enum.AutomaticSize.Y}, root)
	corner(f, UDim.new(0, px(1, 8)))
	stroke(f, C.white, 1.5, 0.85)
	-- v1.1 (Studio check): the accent bar stays out of the list (in it, its 100% height fed the box's automatic height)
	make("Frame", {Name = "Accent", BackgroundColor3 = C.yellow, BorderSizePixel = 0, Size = UDim2.new(0, px(0.6, 4), 1, 0)}, f)
	local body = make("Frame", {Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, f)
	pad(body, px(0.8, 6), px(1.4, 10), px(0.9, 7), px(1.8, 14))
	list(body, nil, px(0.35, 3), Enum.HorizontalAlignment.Left)
	local idx = s - 3
	text(body, ("STEP %d/5"):format(idx), "title", px(1.4, 12), C.yellow, {LayoutOrder = 1})
	text(body, OBJ[s] or "", "black", px(2.3, 19), C.white, {LayoutOrder = 2, TextWrapped = false})
	if lessons and #lessons > 1 then
		local row = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3}, body)
		list(row, Enum.FillDirection.Horizontal, px(1.2, 8), Enum.HorizontalAlignment.Left)
		for i, L in ipairs(lessons) do
			local c = L.done and C.green or L.cur and C.white or C.muted
			text(row, (L.done and "✓ " or "• ") .. L.n, "black", px(1.3, 13), c, {LayoutOrder = i})
		end
	end
	if tip then
		text(body, tip, "body", px(1.6, 15), C.text, {LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			TextXAlignment = Enum.TextXAlignment.Left})
	end
	local segs = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, px(0.5, 4)), LayoutOrder = 5}, body)
	list(segs, Enum.FillDirection.Horizontal, px(0.35, 3))
	for k = 1, 5 do
		local b = make("Frame", {BackgroundColor3 = k < idx and C.green or k == idx and C.yellow or C.white,
			BackgroundTransparency = k > idx and 0.85 or 0, Size = UDim2.new(0.2, -px(0.3, 3), 1, 0), LayoutOrder = k}, segs)
		corner(b, UDim.new(0.5, 0))
	end
	return f
end

-- ---------- pointing at the real controls ----------
local function rectOf(o)
	if not (o and o:IsA("GuiObject") and o.Visible and o.AbsoluteSize.X > 0) then return nil end
	local sg = o:FindFirstAncestorWhichIsA("ScreenGui")
	if sg and not sg.Enabled then return nil end
	local inset = (sg and not sg.IgnoreGuiInset) and GuiService:GetGuiInset() or Vector2.zero
	return o.AbsolutePosition + inset, o.AbsoluteSize
end
local function attackButton()
	local at = player.PlayerGui:FindFirstChild("ArenaTouch")
	if not at then return nil end
	for _, n in ipairs(ATTACK_BUTTONS) do
		for _, d in ipairs(at:GetDescendants()) do
			if d.Name == n and d:IsA("GuiObject") and d.Visible then return d end
		end
	end
	return nil
end
local function slotButton(b)
	local mg = player.PlayerGui:FindFirstChild("MechaButtons")
	return mg and mg:FindFirstChild("Slot_" .. b, true)
end
local function pcBar()
	local ab = player.PlayerGui:FindFirstChild("AbilityBar")
	return ab and ab:FindFirstChild("Bar", true)
end
local overlay = {}
local function pointAt(target, round, fingerKind, big, small, side)
	local pos, size = rectOf(target)
	if not pos then return false end
	local c = pos + size / 2
	local ring = make("Frame", {Name = "Ring", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(c.X, c.Y), Size = UDim2.fromOffset(size.X + px(1.6, 12), size.Y + px(1.6, 12)), ZIndex = 4}, root)
	corner(ring, round and UDim.new(0.5, 0) or UDim.new(0.24, 0))
	local rs = stroke(ring, C.yellow, px(0.45, 3))
	tween(rs, 0.5, {Transparency = 0.6}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	if fingerKind then
		local d = math.max(size.X * 0.36, px(3, 22))
		local fg = make("Frame", {Name = "Finger", BackgroundColor3 = C.white, BackgroundTransparency = 0.08, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(c.X, c.Y - (fingerKind == "pull" and d * 0.7 or 0)), Size = UDim2.fromOffset(d, d), ZIndex = 6}, root)
		corner(fg, UDim.new(0.5, 0))
		stroke(fg, C.white, 3)
		if fingerKind == "pull" then
			tween(fg, 1.1, {Position = UDim2.fromOffset(c.X, c.Y + d * 1.3)}, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1)
		elseif fingerKind == "hold" then
			tween(fg, 0.9, {Size = UDim2.fromOffset(d * 0.66, d * 0.66), BackgroundColor3 = C.yellow}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		else
			tween(fg, fingerKind == "tap3" and 0.22 or 0.45, {Size = UDim2.fromOffset(d * 0.66, d * 0.66)}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		end
	end
	if big then
		local cl = make("Frame", {Name = "Callout", BackgroundColor3 = C.yellow, AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 5,
			AnchorPoint = side == "left" and Vector2.new(1, 0.5) or Vector2.new(0.5, 1),
			Position = side == "left" and UDim2.fromOffset(pos.X - px(1.6, 10), c.Y) or UDim2.fromOffset(c.X, pos.Y - px(1.4, 10))}, root)
		corner(cl, UDim.new(0, px(0.8, 6)))
		pad(cl, px(0.5, 4), px(1, 8))
		list(cl, nil, 0, Enum.HorizontalAlignment.Left)
		text(cl, big, "title", px(2.2, 18), C.ink, {LayoutOrder = 1, ZIndex = 5})
		if small and small ~= "" then text(cl, small, "body", px(1.3, 12), Color3.fromRGB(74, 58, 16), {LayoutOrder = 2, TextWrapped = false, ZIndex = 5}) end
	end
	return true
end
local function pcCallout(big, small)
	local bar = pcBar()
	local pos, size = rectOf(bar)
	local x = pos and (pos.X + size.X / 2) or W / 2
	local y = pos and pos.Y or H - px(8)
	local cl = make("Frame", {Name = "Callout", BackgroundColor3 = C.yellow, AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 5,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(x, y - px(1.4, 10))}, root)
	corner(cl, UDim.new(0, px(0.8, 6)))
	pad(cl, px(0.5, 4), px(1, 8))
	list(cl, nil, 0, Enum.HorizontalAlignment.Center)
	text(cl, big, "title", px(2.2, 18), C.ink, {LayoutOrder = 1, ZIndex = 5})
	if small and small ~= "" then text(cl, small, "body", px(1.3, 12), Color3.fromRGB(74, 58, 16), {LayoutOrder = 2, TextWrapped = false, ZIndex = 5}) end
end

-- hide the phone's other buttons during step 4 (only what this script hid comes back)
local hidden = {}
local function hideOthers(on)
	if not isTouch() then return end
	local targets = {}
	if on then
		local at = player.PlayerGui:FindFirstChild("ArenaTouch")
		local leap = at and at:FindFirstChild("Leap", true)
		if leap then table.insert(targets, leap) end
		for b = 1, 2 do local s = slotButton(b) if s then table.insert(targets, s) end end
		for _, o in ipairs(targets) do
			if o:IsA("GuiObject") and o.Visible then hidden[o] = true o.Visible = false end
		end
	else
		for o in pairs(hidden) do if o.Parent then o.Visible = true end end
		hidden = {}
	end
end

-- ---------- bot marks ----------
local mark = {bot = nil, hl = nil, bb = nil}
local function clearMark()
	if mark.hl then mark.hl:Destroy() end
	if mark.bb then mark.bb:Destroy() end
	mark.bot, mark.hl, mark.bb = nil, nil, nil
end
local function updateMark()
	local s = step()
	local bot = (s == 4 or s == 6 or s == 7) and botModel() or nil
	if bot ~= mark.bot then
		clearMark()
		if bot then
			mark.bot = bot
			mark.hl = make("Highlight", {FillTransparency = 1, OutlineColor = C.yellow, OutlineTransparency = 0.1,
				DepthMode = Enum.HighlightDepthMode.AlwaysOnTop}, bot)
			local head = bot:FindFirstChild("Head") or bot:FindFirstChild("HumanoidRootPart")
			mark.bb = make("BillboardGui", {Size = UDim2.fromOffset(150, 64), StudsOffset = Vector3.new(0, 8, 0), AlwaysOnTop = true,
				Adornee = head, LightInfluence = 0}, bot)
			text(mark.bb, "▼", "black", 34, C.yellow, {Name = "Arrow", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 22)})
			local bar = make("Frame", {Name = "Bar", BackgroundColor3 = Color3.fromRGB(40, 20, 24), Size = UDim2.new(1, 0, 0, 10)}, mark.bb)
			corner(bar, UDim.new(0.5, 0))
			local fill = make("Frame", {Name = "Fill", BackgroundColor3 = C.pink, Size = UDim2.fromScale(1, 1)}, bar)
			corner(fill, UDim.new(0.5, 0))
		end
	end
	if mark.bb then
		local bar = mark.bb:FindFirstChild("Bar")
		if bar then
			bar.Visible = s == 7
			local hp = tonumber(mark.bot:GetAttribute("DummyHealth")) or 0
			local max = tonumber(mark.bot:GetAttribute("DummyMaxHealth")) or 1
			bar.Fill.Size = UDim2.fromScale(math.clamp(hp / math.max(max, 1), 0, 1), 1)
		end
	end
end

-- ---------- bottom sheet ----------
local function sheet()
	local f = make("Frame", {Name = "Sheet", BackgroundColor3 = C.panel, BackgroundTransparency = 0.03, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, px(2)), Size = UDim2.new(1, 0, 0, px(33, 230))}, root)
	corner(f, UDim.new(0, px(2, 14)))
	stroke(f, C.line, 2)
	local inner = make("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(px(6, 24), px(1.8, 12)),
		Size = UDim2.new(1, -2 * px(6, 24), 1, -px(1.8, 12) - px(3.6, 24))}, f)
	return f, inner
end
local function header(parent, s, order)
	return text(parent, s, "title", px(1.7, 13), C.yellow, {LayoutOrder = order or 0, TextXAlignment = Enum.TextXAlignment.Left})
end

-- ---------- v1.2: the incubator (see the header) ----------
local RunService = game:GetService("RunService")
if script:GetAttribute("TutorialIncubatorEnabled") == nil then script:SetAttribute("TutorialIncubatorEnabled", true) end
if script:GetAttribute("TutHatchHold") == nil then script:SetAttribute("TutHatchHold", 1.2) end
local function incubatorOn() return script:GetAttribute("TutorialIncubatorEnabled") ~= false end
local pod = {p = 0, holding = false, phase = "charge", revealed = false, conn = nil, sceneKey = nil, input = nil, showcased = false}
if script:GetAttribute("TutorialShowcaseEnabled") == nil then script:SetAttribute("TutorialShowcaseEnabled", true) end -- v1.4
local function showcaseOn() return script:GetAttribute("TutorialShowcaseEnabled") ~= false end
local function podStop() if pod.conn then pod.conn:Disconnect() pod.conn = nil end end
local function podReset() podStop() pod.p, pod.holding, pod.phase, pod.revealed, pod.sceneKey, pod.input = 0, false, "charge", false, nil, nil end
UserInputService.InputEnded:Connect(function(io)
	if io == pod.input or io.UserInputType == Enum.UserInputType.MouseButton1 then pod.holding = false end
end)
local ROLE_COLOR = {HOLDER = C.cyan, FIGHTER = C.pink, RANGED = C.green}
local function podRays(cx, cy, color)
	local holder = make("Frame", {Name = "Rays", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy),
		Size = UDim2.fromOffset(px(120), px(120))}, root)
	local beams = {}
	for i = 1, 12 do
		local b = make("Frame", {BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, px(2.8, 12)), Rotation = (i - 1) * 15, BackgroundTransparency = 0.62}, holder)
		make("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.28, 0.55),
			NumberSequenceKeypoint.new(0.45, 0.85), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(0.55, 0.85),
			NumberSequenceKeypoint.new(0.72, 0.55), NumberSequenceKeypoint.new(1, 1)})}, b)
		table.insert(beams, b)
	end
	return holder, beams
end
local function vpart(parent, props)
	local o = Instance.new("Part")
	o.Anchored, o.CanCollide, o.CastShadow = true, false, false
	o.TopSurface, o.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
-- the 3D egg: radius 1 (x, z), 1.32 tall; returns the viewport, its seam and the 3 crack groups
local function eggView(parent)
	local vf = make("ViewportFrame", {Name = "EggView", BackgroundTransparency = 1, Ambient = Color3.fromRGB(150, 140, 125),
		LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.6, -0.7, -0.8)}, parent)
	local egg = vpart(vf, {Name = "Egg", Size = Vector3.new(2, 2, 2), Color = Color3.fromRGB(238, 218, 170), Material = Enum.Material.SmoothPlastic})
	make("SpecialMesh", {MeshType = Enum.MeshType.Sphere, Scale = Vector3.new(1, 1.32, 1)}, egg)
	local up = CFrame.Angles(0, 0, math.rad(90))
	vpart(vf, {Name = "Belt", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.32, 2.04, 2.04), CFrame = CFrame.new(0, -0.12, 0) * up,
		Color = Color3.fromRGB(128, 142, 168), Material = Enum.Material.Metal})
	local seam = vpart(vf, {Name = "Seam", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.07, 2.08, 2.08), CFrame = CFrame.new(0, -0.12, 0) * up,
		Color = C.cyan, Material = Enum.Material.Neon})
	local function surf(x, y) return math.sqrt(math.max(0, 1 - x * x - (y / 1.32) ^ 2)) end
	for _, sp in ipairs({{-0.5, 0.8}, {0.3, 1.0}, {0.62, 0.45}, {-0.7, 0.25}, {0.15, -0.75}, {-0.42, -0.95}, {0.66, -0.55}}) do
		vpart(vf, {Name = "Spot", Shape = Enum.PartType.Ball, Size = Vector3.new(0.16, 0.16, 0.16), Color = Color3.fromRGB(176, 140, 86),
			CFrame = CFrame.new(sp[1], sp[2], surf(sp[1], sp[2]) - 0.05), Material = Enum.Material.SmoothPlastic})
	end
	local lines = {
		{{-0.45, 0.78}, {-0.28, 0.56}, {-0.42, 0.36}, {-0.22, 0.18}},
		{{0.36, 0.95}, {0.24, 0.7}, {0.44, 0.5}, {0.3, 0.3}},
		{{-0.76, -0.52}, {-0.46, -0.42}, {-0.3, -0.64}, {-0.04, -0.48}, {0.16, -0.72}, {0.42, -0.52}, {0.72, -0.66}},
	}
	local cracks = {}
	for i, pts in ipairs(lines) do
		cracks[i] = {}
		for k = 1, #pts - 1 do
			local a, b = pts[k], pts[k + 1]
			local mx, my = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
			local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
			local ang = math.atan2(b[2] - a[2], b[1] - a[1])
			table.insert(cracks[i], vpart(vf, {Name = "Crack", Size = Vector3.new(len + 0.04, 0.06, 0.04), Color = C.yellow, Material = Enum.Material.Neon,
				Transparency = 1, CFrame = CFrame.new(mx, my, surf(mx, my) + 0.01) * CFrame.Angles(0, 0, ang)}))
		end
	end
	local cam = make("Camera", {FieldOfView = 30, CFrame = CFrame.lookAt(Vector3.new(0, 0.25, 6.6), Vector3.new(0, 0, 0))}, vf)
	vf.CurrentCamera = cam
	return vf, seam, cracks
end
-- the pod: glass, cap and lit base; returns the frame and its parts
local function podFrame(cx, top, w, h)
	local f = make("Frame", {Name = "Pod", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, top),
		Size = UDim2.fromOffset(w, h)}, root)
	local baseH = px(6, 34)
	local base = make("Frame", {Name = "Base", BackgroundColor3 = Color3.fromRGB(52, 64, 94), AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, baseH), ZIndex = 4}, f)
	corner(base, UDim.new(0, px(1.4, 8)))
	make("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(150, 160, 185), Color3.fromRGB(60, 66, 86)), Rotation = 90}, base)
	local bar = make("Frame", {Name = "Light", BackgroundColor3 = C.cyan, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.new(0.8, 0, 0, px(0.6, 4)), ZIndex = 5}, base)
	corner(bar, UDim.new(0.5, 0))
	stroke(bar, C.cyan, px(0.5, 3), 0.55)
	local glass = make("Frame", {Name = "Glass", BackgroundColor3 = C.cyan, BackgroundTransparency = 0.9, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(1, -px(2.8, 14), 1, -baseH + px(1, 6)), ZIndex = 3}, f)
	corner(glass, UDim.new(0, math.floor(w * 0.42)))
	local gs = stroke(glass, C.cyan, px(0.35, 2), 0.35)
	make("Frame", {Name = "Shine", BackgroundColor3 = C.white, BackgroundTransparency = 0.82, BorderSizePixel = 0, Position = UDim2.new(0.24, 0, 0.16, 0),
		Size = UDim2.new(0, px(0.7, 4), 0.62, 0), ZIndex = 3}, glass)
	local cap = make("Frame", {Name = "Cap", BackgroundColor3 = Color3.fromRGB(62, 76, 106), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.66, 0, 0, px(2, 11)), ZIndex = 4}, f)
	corner(cap, UDim.new(0.5, 0))
	return f, glass, gs, cap, baseH
end
local function hatchText(parent, s2, kind, size, color, y)
	return text(parent, s2, kind, size, color, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(W / 2, y), TextWrapped = false})
end
local function shardsAt(x, y)
	for i = 1, 9 do
		local a = (i / 9) * math.pi * 2 + math.random() * 0.4
		local d = px(16 + math.random() * 10)
		local sh = make("Frame", {BackgroundColor3 = Color3.fromRGB(240, 222, 178), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(px(2.4, 12), px(1.8, 9)), Rotation = math.random(0, 90), ZIndex = 12}, root)
		corner(sh, UDim.new(0, px(0.4, 2)))
		tween(sh, 0.9, {Position = UDim2.fromOffset(x + math.cos(a) * d, y + math.sin(a) * d * 0.7), Rotation = sh.Rotation + math.random(-360, 360),
			BackgroundTransparency = 1}, Enum.EasingStyle.Quart)
	end
end
local function rollLoop()
	if egg.rollLoop then return end
	egg.rollLoop = true
	task.spawn(function()
		while step() > 0 and step() <= 2 and (player:GetAttribute("TutRolled") or "") == "" do
			if step() == 2 then send("roll") elseif step() == 1 then send("next") end
			task.wait(0.8)
		end
		egg.rollLoop = false
		task.defer(function() render() end)
	end)
end

local function drawCharge()
	backdrop()
	local rays, beams = podRays(W / 2, H * 0.55, C.cyan)
	hatchText(root, "MECHA DINO ARENA", "title", px(1.8, 14), C.yellow, H * 0.05)
	hatchText(root, "YOUR FIRST DINO", "title", px(4.6, 32), C.white, H * 0.1)
	hatchText(root, "It's free. Press and hold.", "body", px(1.9, 16), C.text, H * 0.21)
	local pw, ph = px(23, 130), H * 0.45
	local f, glass, gs, cap, baseH = podFrame(W / 2, H * 0.27, pw, ph)
	local eh = ph - baseH - px(3, 16)
	local vf, seam, cracks = eggView(f)
	vf.AnchorPoint = Vector2.new(0.5, 1)
	vf.Size = UDim2.fromOffset(eh * 0.8, eh)
	vf.ZIndex = 2
	local eggPos = UDim2.new(0.5, 0, 1, -baseH + px(0.4, 2))
	vf.Position = eggPos
	local d = math.max(px(12, 72), 72)
	local by = H - px(1.8, 10) - d / 2
	local btn = make("TextButton", {Name = "Hold", Text = "", AutoButtonColor = false, BackgroundColor3 = C.yellow, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(W / 2, by), Size = UDim2.fromOffset(d, d), ZIndex = 6, Modal = true}, root)
	corner(btn, UDim.new(0.5, 0))
	stroke(btn, C.yellowDark, px(0.35, 2))
	local sc = make("UIScale", {}, btn)
	text(btn, "HOLD\nTO\nHATCH", "title", px(2.1, 15), C.ink, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 7,
		TextWrapped = false, LineHeight = 0.9})
	local dots = {}
	for i = 1, 24 do
		local a = (i - 1) / 24 * math.pi * 2 - math.pi / 2
		local r = d / 2 + px(1.2, 7)
		local dt = make("Frame", {BackgroundColor3 = C.cyan, BackgroundTransparency = 0.8, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(W / 2 + math.cos(a) * r, by + math.sin(a) * r), Size = UDim2.fromOffset(px(0.9, 5), px(0.9, 5)), ZIndex = 6}, root)
		corner(dt, UDim.new(0.5, 0))
		dots[i] = dt
	end
	local function isPress(io) return io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch end
	btn.InputBegan:Connect(function(io) if isPress(io) and pod.phase == "charge" then pod.holding, pod.input = true, io end end)
	btn.InputEnded:Connect(function(io) if isPress(io) then pod.holding = false end end)
	local t0 = os.clock()
	pod.conn = RunService.RenderStepped:Connect(function(dt2)
		if pod.phase ~= "charge" then return end
		local hold = math.max(0.2, tonumber(script:GetAttribute("TutHatchHold")) or 1.2)
		pod.p = math.clamp(pod.p + (pod.holding and dt2 / hold or -dt2 / (hold / 2)), 0, 1)
		local p = pod.p
		rays.Rotation += dt2 * (6 + 50 * p)
		for _, b in ipairs(beams) do b.BackgroundTransparency = 0.62 - 0.4 * p end
		gs.Transparency = 0.35 - 0.3 * p
		local lit = math.floor(p * 24 + 0.001)
		for i, dt3 in ipairs(dots) do dt3.BackgroundTransparency = i <= lit and 0 or 0.8 end
		local j = pod.holding and px(0.35) * p or 0
		vf.Position = eggPos + UDim2.fromOffset((math.random() * 2 - 1) * j, (math.random() * 2 - 1) * j - (pod.holding and 0 or math.sin((os.clock() - t0) * 2.4) * px(0.5)))
		seam.Color = p > 0.5 and C.yellow or C.cyan
		for i, group in ipairs(cracks) do
			local on = (i == 1 and p >= 0.34) or (i == 2 and p >= 0.67)
			for _, c in ipairs(group) do c.Transparency = on and 0 or 1 end
		end
		sc.Scale = pod.holding and 0.93 or (p == 0 and 1 + 0.04 * math.sin((os.clock() - t0) * 5) or 1)
		if p >= 1 then
			pod.phase = "open"
			pod.holding = false
			for _, c in ipairs(cracks[3]) do c.Transparency = 0 end
			flash()
			local gy = glass.Position
			tween(glass, 0.6, {Position = gy - UDim2.fromOffset(0, H * 0.6), BackgroundTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(gs, 0.5, {Transparency = 1})
			tween(cap, 0.6, {Position = cap.Position - UDim2.fromOffset(0, H * 0.6), BackgroundTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(vf, 0.35, {ImageTransparency = 1, Size = UDim2.fromOffset(eh * 0.8 * 1.3, eh * 1.3)})
			local ap = vf.AbsolutePosition + vf.AbsoluteSize / 2 - root.AbsolutePosition
			shardsAt(ap.X, ap.Y)
			btn.Visible = false
			for _, dt3 in ipairs(dots) do dt3.Visible = false end
			task.delay(0.7, rollLoop)
		end
	end)
end

local function drawWait()
	backdrop()
	local rays, beams = podRays(W / 2, H * 0.55, C.yellow)
	for _, b in ipairs(beams) do b.BackgroundTransparency = 0.3 end
	local pw, ph = px(23, 130), H * 0.45
	local f, glass, gs, cap = podFrame(W / 2, H * 0.27, pw, ph)
	glass.Visible, cap.Visible = false, false
	local t = hatchText(root, "HATCHING", "title", px(3, 22), C.yellow, H * 0.16)
	tween(t, 0.4, {TextTransparency = 0.6}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	pod.conn = RunService.RenderStepped:Connect(function(dt2) rays.Rotation += dt2 * 40 end)
end

-- the rolled dino in a viewport (PregameModels body + its free parts), turning; returns the viewport and a turn function
local function dinoView(parent, key)
	local vf = make("ViewportFrame", {Name = "DinoView", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(150, 160, 180),
		LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.5, -1, -0.6)}, parent)
	local models = ReplicatedStorage:FindFirstChild("PregameModels")
	local fold = models and models:FindFirstChild(key)
	local body = fold and fold:FindFirstChild("Body")
	if not (body and body:IsA("Model")) then
		text(parent, string.upper(dinoName(key)), "title", px(4, 30), C.yellow, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5)})
		return vf, function() end
	end
	local m = Instance.new("Model")
	body:Clone().Parent = m
	local pf = fold:FindFirstChild("Parts")
	for _, id in ipairs(partsOf(key, false, true)) do
		local pm = pf and pf:FindFirstChild(id)
		if pm and pm:GetAttribute("Free") ~= true then pm:Clone().Parent = m end
	end
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("BaseScript") then d:Destroy() end end
	local bcf, bsz = body:GetBoundingBox()
	local sz = body:GetAttribute("BodySize") or bsz
	local minY = body:GetAttribute("BodyMinY") or (bcf.Position.Y - sz.Y / 2)
	m.WorldPivot = CFrame.new(bcf.Position.X, minY, bcf.Position.Z)
	m.Parent = vf
	local yaw = math.pi + 0.8
	m:PivotTo(CFrame.Angles(0, yaw, 0))
	local mx = math.max(sz.X, sz.Y * 1.35, sz.Z)
	local d, ty = mx * 1.4, sz.Y * 0.45
	local cam = make("Camera", {FieldOfView = 30, CFrame = CFrame.lookAt(Vector3.new(0, ty + d * 0.2, d), Vector3.new(0, ty, 0))}, vf)
	vf.CurrentCamera = cam
	return vf, function(dt2) yaw += dt2 * 0.45 m:PivotTo(CFrame.Angles(0, yaw, 0)) end
end
local function badgeWords(L)
	if L.key and not isTouch() then return L.key end
	if L.how == "hold" then return "HOLD" end
	if L.how == "tap3" then return isTouch() and "TAP\nX3" or "CLICK\nX3" end
	return isTouch() and "TAP" or "CLICK"
end

local function drawReveal(rolled, animate)
	backdrop()
	local cx = W * 0.3
	local rays, beams = podRays(cx, H * 0.5, C.cyan)
	-- the dino on the pod base
	local vw, vh = math.min(px(44), W * 0.46), H * 0.56
	local holder = make("Frame", {Name = "Dino", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, H * 0.44),
		Size = UDim2.fromOffset(vw, vh), ZIndex = 3}, root)
	local base = make("Frame", {Name = "Base", BackgroundColor3 = Color3.fromRGB(52, 64, 94), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 2,
		Position = UDim2.fromOffset(cx, H * 0.44 + vh * 0.3), Size = UDim2.fromOffset(px(22, 130), px(6, 34))}, root)
	corner(base, UDim.new(0, px(1.4, 8)))
	make("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(150, 160, 185), Color3.fromRGB(60, 66, 86)), Rotation = 90}, base)
	local bar = make("Frame", {BackgroundColor3 = C.cyan, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(0.8, 0, 0, px(0.6, 4)), ZIndex = 3}, base)
	corner(bar, UDim.new(0.5, 0))
	stroke(bar, C.cyan, px(0.5, 3), 0.55)
	local vf, turn = dinoView(holder, rolled)
	if script:GetAttribute("TutorialRevealFitEnabled") ~= false and vf.CurrentCamera then -- v1.7.1: tall / long dinos fit
		vf.CurrentCamera.FieldOfView = tonumber(script:GetAttribute("TutRevealFov")) or 44
	end
	-- the panel
	local role = R.ROLE[rolled] or "FIGHTER"
	local pw = math.min(px(44), W * 0.42)
	local panel = make("CanvasGroup", {Name = "Panel", BackgroundTransparency = 1, Position = UDim2.fromOffset(W * 0.54, math.max(H * 0.1, topH * 0.6)),
		Size = UDim2.fromOffset(pw, H * 0.86), ZIndex = 5}, root)
	list(panel, nil, px(0.8, 5), Enum.HorizontalAlignment.Left).VerticalAlignment = Enum.VerticalAlignment.Top
	text(panel, "FREE DINO UNLOCKED", "title", px(1.9, 14), C.cyan, {LayoutOrder = 1})
	text(panel, string.upper(dinoName(rolled)), "title", px(6, 40), C.white, {LayoutOrder = 2})
	local chip = text(panel, " " .. role .. " ", "title", px(1.8, 13), C.ink, {BackgroundTransparency = 0, BackgroundColor3 = ROLE_COLOR[role] or C.cyan,
		LayoutOrder = 3})
	corner(chip, UDim.new(0, px(0.6, 4)))
	pad(chip, px(0.4, 3), px(0.6, 4))
	local hr = make("Frame", {BackgroundColor3 = C.cyan, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 2), LayoutOrder = 4}, panel)
	make("UIGradient", {Transparency = NumberSequence.new(0, 1)}, hr)
	text(panel, "MAIN ATTACK", "title", px(1.9, 14), C.yellow, {LayoutOrder = 5})
	local bd = px(6.2, 44)
	for i, L in ipairs(R.lessonsFor(rolled)) do
		local row = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5 + i}, panel)
		local hold = L.how == "hold"
		local bdg = make("Frame", {BackgroundColor3 = hold and C.cyan or C.yellow, Size = UDim2.fromOffset(bd, bd)}, row)
		corner(bdg, UDim.new(0.5, 0))
		if hold then stroke(bdg, C.cyan, px(0.4, 3), 0.4) end
		text(bdg, badgeWords(L), "title", px(1.7, 12), C.ink, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), TextWrapped = false,
			LineHeight = 0.9})
		local col = make("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(bd + px(1.4, 8), 0), Size = UDim2.new(1, -bd - px(1.4, 8), 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y}, row)
		list(col, nil, px(0.2, 2), Enum.HorizontalAlignment.Left).VerticalAlignment = Enum.VerticalAlignment.Top
		text(col, L.n, "black", px(2.5, 19), C.white, {LayoutOrder = 1, TextWrapped = false})
		text(col, L.line, "body", px(1.8, 14), C.muted, {LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			TextXAlignment = Enum.TextXAlignment.Left})
	end
	local pss = script:GetAttribute("TutorialRevealPassiveEnabled") ~= false and R.passivesFor(rolled) or {} -- v1.7: PASSIVE
	if #pss > 0 then
		text(panel, "PASSIVE", "title", px(1.9, 14), C.green, {LayoutOrder = 12})
		local slotW = px(9, 66)
		for i, P in ipairs(pss) do
			local row = make("Frame", {Name = "Passive", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 12 + i}, panel)
			local tg = text(row, " " .. P.tag .. " ", "black", px(1.3, 11), C.ink, {BackgroundTransparency = 0, BackgroundColor3 = C.green,
				TextWrapped = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(slotW / 2, px(0.4, 3))})
			corner(tg, UDim.new(0.5, 0))
			pad(tg, px(0.4, 3), px(0.6, 4))
			local col = make("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(slotW + px(1.4, 8), 0), Size = UDim2.new(1, -slotW - px(1.4, 8), 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y}, row)
			list(col, nil, px(0.2, 2), Enum.HorizontalAlignment.Left).VerticalAlignment = Enum.VerticalAlignment.Top
			text(col, P.n, "black", px(2.1, 16), C.white, {LayoutOrder = 1, TextWrapped = false})
			local ln = text(col, P.line, "body", px(1.8, 14), C.muted, {LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				TextXAlignment = Enum.TextXAlignment.Left})
			task.defer(function() -- fit: never push NEXT out of the panel
				local lay = panel:FindFirstChildOfClass("UIListLayout")
				if not (lay and ln.Parent) or lay.AbsoluteContentSize.Y <= panel.AbsoluteSize.Y then return end
				ln.TextSize = 12
				task.defer(function()
					if ln.Parent and lay.AbsoluteContentSize.Y > panel.AbsoluteSize.Y then
						ln.AutomaticSize = Enum.AutomaticSize.None
						ln.Size = UDim2.new(1, 0, 0, math.ceil(ln.TextSize * 1.25))
						ln.TextTruncate = Enum.TextTruncate.AtEnd
					end
				end)
			end)
		end
	end
	if ReplicatedStorage:GetAttribute("TutUnlockTextOn") == true then
		text(panel, "More dinos unlock with skill points.", "body", px(1.4, 12), C.muted, {LayoutOrder = 20})
	end
	local nb = cta(panel, "NEXT", function() send("next") end, {LayoutOrder = 21})
	-- motion
	local scanY = 0
	local scan = make("Frame", {Name = "Scan", BackgroundColor3 = C.cyan, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4,
		Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0.9, 0, 0, px(0.5, 3)), Visible = false}, holder)
	stroke(scan, C.cyan, px(0.6, 4), 0.5)
	if animate then
		pod.revealed = true
		vf.ImageColor3 = Color3.new(0, 0, 0)
		holder.Position = UDim2.fromOffset(W / 2, H * 0.44)
		base.Position = UDim2.fromOffset(W / 2, H * 0.44 + vh * 0.3)
		tween(holder, 0.6, {Position = UDim2.fromOffset(cx, H * 0.44)}, Enum.EasingStyle.Back)
		tween(base, 0.6, {Position = UDim2.fromOffset(cx, H * 0.44 + vh * 0.3)}, Enum.EasingStyle.Back)
		panel.GroupTransparency = 1
		panel.Position += UDim2.fromOffset(px(3), 0)
		task.delay(0.55, function()
			if not scan.Parent then return end
			scan.Visible = true
			tween(scan, 0.9, {Position = UDim2.fromScale(0.5, 1)}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			tween(vf, 0.9, {ImageColor3 = Color3.new(1, 1, 1)}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			for _, b in ipairs(beams) do tween(b, 0.5, {BackgroundTransparency = 0.3}) end
			task.delay(0.95, function()
				if scan.Parent then scan.Visible = false end
				for _, b in ipairs(beams) do if b.Parent then tween(b, 0.8, {BackgroundTransparency = 0.6}) end end
			end)
		end)
		task.delay(1.1, function()
			if panel.Parent then tween(panel, 0.4, {GroupTransparency = 0, Position = panel.Position - UDim2.fromOffset(px(3), 0)}) end
		end)
	end
	pod.conn = RunService.RenderStepped:Connect(function(dt2)
		rays.Rotation += dt2 * 6
		turn(dt2)
	end)
end

-- v1.4: the dino showcase before the egg (see the header)
local function drawShowcase()
	backdrop()
	local rays = podRays(W / 2, H * 0.52, C.cyan)
	hatchText(root, "MECHA DINO ARENA", "title", px(1.8, 14), C.yellow, H * 0.05)
	hatchText(root, "YOUR FIRST DINO", "title", px(4.6, 32), C.white, H * 0.1)
	hatchText(root, ("1 OF THESE %d \u{00B7} FREE"):format(#R.ROLL_POOL), "black", px(2, 16), C.text, H * 0.21)
	local n = #R.ROLL_POOL
	local gutter = math.max(px(3, 16), freeLeft > 0 and 0 or 0)
	local gap = px(1, 6)
	local cw = math.min(px(13, 80), (W - 2 * gutter - (n - 1) * gap) / n)
	local ch = math.min(H * 0.46, cw * 1.55)
	local x0 = W / 2 - (n * cw + (n - 1) * gap) / 2
	local y0 = H * 0.3
	local turns = {}
	-- the 3D bodies arrive from the server after the join: draw again every 0.5 s until all are complete (PieceCount, as
	-- PregameScreen 1.3 does)
	local models = ReplicatedStorage:FindFirstChild("PregameModels")
	local ready = models ~= nil
	for _, key in ipairs(R.ROLL_POOL) do
		local f = models and models:FindFirstChild(key)
		local body = f and f:FindFirstChild("Body")
		local pc = body and tonumber(body:GetAttribute("PieceCount"))
		if not body or (pc and #body:GetDescendants() < pc) then ready = false end
	end
	if not ready then
		task.delay(0.5, function()
			if step() == 1 and not pod.showcased and pod.phase == "charge" then pod.sceneKey = nil render() end
		end)
	end
	local deal = ready and not pod.dealt
	if ready then pod.dealt = true end
	for i, key in ipairs(R.ROLL_POOL) do
		local role = R.ROLE[key] or "FIGHTER"
		local cg = make("Frame", {Name = "Dino_" .. key, BackgroundColor3 = C.card, -- v1.4: a Frame (viewports do not draw inside a CanvasGroup)
			Position = UDim2.fromOffset(x0 + (i - 1) * (cw + gap), y0 + (deal and px(3) or 0)), Size = UDim2.fromOffset(cw, ch), ZIndex = 3}, root)
		corner(cg, UDim.new(0, px(1.2, 8)))
		stroke(cg, ROLE_COLOR[role] or C.cyan, px(0.25, 2), 0.25)
		local art = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -px(5.6, 34))}, cg)
		if ready then
			local _, turn = dinoView(art, key)
			table.insert(turns, turn)
		end
		local nm = text(cg, string.upper(dinoName(key)), "title", px(1.5, 11), C.white, {AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -px(2.6, 16)), TextWrapped = false})
		local chip = text(cg, " " .. role .. " ", "title", px(1.1, 9), C.ink, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -px(0.8, 5)),
			BackgroundTransparency = 0, BackgroundColor3 = ROLE_COLOR[role] or C.cyan, TextWrapped = false})
		corner(chip, UDim.new(0, px(0.4, 3)))
		for _, dd in ipairs(cg:GetDescendants()) do if dd:IsA("GuiObject") then dd.ZIndex = 4 end end -- over the card (the gui sorts globally)
		if deal then
			cg.Visible = false
			task.delay(0.08 * i, function()
				if cg.Parent then
					cg.Visible = true
					tween(cg, 0.35, {Position = UDim2.fromOffset(x0 + (i - 1) * (cw + gap), y0)}, Enum.EasingStyle.Back)
				end
			end)
		end
	end
	local b = cta(root, "NEXT", function()
		pod.showcased = true
		pod.sceneKey = nil
		task.defer(function() render() end)
	end, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -px(2.2, 12))})
	b.ZIndex = 6
	pod.conn = RunService.RenderStepped:Connect(function(dt2)
		rays.Rotation += dt2 * 6
		for _, t in ipairs(turns) do t(dt2) end
	end)
end
-- ---------- v1.5: the dino showcase as a select screen with attack / ability cards (see the header) ----------
if script:GetAttribute("TutorialShowcaseCardsEnabled") == nil then script:SetAttribute("TutorialShowcaseCardsEnabled", true) end
local function showcase2On() return script:GetAttribute("TutorialShowcaseCardsEnabled") ~= false end
if script:GetAttribute("TutShowcaseCycle") == nil then script:SetAttribute("TutShowcaseCycle", 5) end -- s per dino
if script:GetAttribute("TutShowcaseHold") == nil then script:SetAttribute("TutShowcaseHold", 10) end -- s of no cycling after a tap
local TextService = game:GetService("TextService")
local SC_GROUPS = {{"HOLDER", {"Pachy", "Teno"}}, {"FIGHTER", {"Raptor", "Herrera", "Therizino"}}, {"RANGED", {"Dilo", "Troodon"}}} -- PregameScreen ROLE_GROUPS (roll pool only)
local SC_TYPE = {ATTACK = Color3.fromRGB(255, 107, 132), CONTROL = Color3.fromRGB(180, 140, 255), DEFENSE = Color3.fromRGB(127, 233, 255),
	HEAL = Color3.fromRGB(70, 224, 138), MOVE = Color3.fromRGB(255, 155, 46), SUPPORT = Color3.fromRGB(255, 200, 50),
	STEALTH = Color3.fromRGB(159, 176, 200), SCOUT = Color3.fromRGB(198, 211, 106), PASSIVE = Color3.fromRGB(138, 149, 168)}
-- main attacks: name, how (as TutorialRules LESSONS), PC key, line, stats {label, value}. Numbers = the dino's ModelData attributes
-- (RaptorModelData Pounce*, PachyModelData Headbutt*, HerreraModelData Slash*, TenoModelData TenoScratch* / TenoSlam*,
-- TherizinoModelData TheriHitDamage1-3, DiloModelData DiloDart* / DiloVenom* / DiloSpit*, TroodonModelData TrooPod* / TrooZone*)
local SC_ATK = {
	Raptor = {{"Pounce", "tap", "F", "Leap onto an enemy and latch on. Keep clawing while you ride it.", {{"DMG", "8 + 5 / 0.5 S"}, {"COST", "15 STAMINA"}, {"CD", "3 S"}}}},
	Pachy = {{"Headbutt", "tap", nil, "Charge head first. A full run-up hits hardest. The target is shoved back and slowed.", {{"DMG", "25"}, {"UP CLOSE", "18"}, {"SHOVE", "40 STUDS"}, {"SLOW", "35% · 3 S"}, {"CHARGES", "2 · 3 S"}}}},
	Herrera = {{"Dash Slash", "tap", nil, "Dash straight through an enemy and slash it open. It keeps bleeding.", {{"DMG", "15"}, {"BLEED", "4/S · 4 S"}, {"CHARGES", "3 · 2.5 S"}}}},
	Teno = {{"Scratch", "tap", nil, "Swipe whatever is in front of you.", {{"DMG", "12"}}},
		{"Tail Slam", "hold", nil, "Turn your back and slam everything behind you.", {{"DMG", "25"}, {"CHARGES", "3 · 8 S"}}}},
	Therizino = {{"Claw Combo", "tap3", nil, "Three slashes. The third one is the big hit.", {{"DMG", "11 · 11 · 24"}}}},
	Dilo = {{"Spit", "tap", nil, "Spit venom from range. It burns after it lands.", {{"DMG", "5"}, {"VENOM", "4/S · 1.5 S"}, {"RANGE", "60"}, {"AMMO", "5 · 3 S RELOAD"}}}},
	Troodon = {{"Glow Pod Toss", "tap", nil, "Lob a glowing pod. It splats into a zone that burns and slows enemies and heals your squad.", {{"DMG", "4 + 1/S"}, {"SLOW", "25% · 3 S"}, {"HEAL", "+5 SQUAD"}, {"CHARGES", "3 · 2 S"}}}},
}
-- abilities at max (the free dino gets every part maxed, SkillServer 1.13): type, line, stats. Numbers = SkillTree.effects(every
-- part at step 4, dino) read in Studio 2026-11-22; Thrusters recharge = SkillEffects 1.54 SkillDashRechargeFast 5.6.
local SC_INFO = {
	adrenaline = {"HEAL", "Jab in a boost. Heal and sprint, and it snaps you out of a stun.", {{"HEAL", "34% HP"}, {"SPEED", "+40%"}, {"TIME", "3 S"}, {"CD", "10.3 S"}}},
	screech = {"CONTROL", "Your shoulder cannon fires an electric ball. The first dino hit is stunned and its cloak drops.", {{"DMG", "30"}, {"STUN", "1.1 S"}, {"RANGE", "270"}, {"CD", "10.3 S"}}},
	shield = {"DEFENSE", "Block every hit. You move slower while it's up.", {{"BLOCK", "ALL DMG"}, {"TIME", "2.77 S"}, {"SPEED", "68%"}, {"CD", "11.8 S"}}},
	cloak = {"STEALTH", "Go nearly invisible and bots lose you. Stand still to stay hidden twice as long. Strike out of it for bonus damage.", {{"TIME", "4.1 S"}, {"STILL", "8.2 S"}, {"AMBUSH", "+35% DMG"}, {"CD", "12 S"}}},
	thrusters = {"MOVE", "Pop a hop, then rocket forward. Steer the boost.", {{"SPEED", "2X"}, {"TIME", "1.85 S"}, {"HOP", "25 STUDS"}, {"CHARGES", "2 · 5.6 S"}}},
	traps = {"ATTACK", "Throw a mine ahead. Whoever walks into it gets blasted back, dazed, slowed, and loses its boost, Shield and Adrenaline.", {{"DMG", "25"}, {"DAZE", "1 S"}, {"SLOW", "50% · 2 S"}, {"CHARGES", "4 · 8.8 S"}}},
	scent = {"SCOUT", "Sniff the air. Every dino that passed by leaves a glowing trail. Bleeding dinos always leave a blood trail.", {{"RANGE", "81"}, {"TRAILS", "10.8 S OLD"}, {"TIME", "6 S"}, {"CD", "16 S"}}},
	medstation = {"HEAL", "Drop a healing pad. Stand in the circle for a full heal.", {{"HEAL", "10% / S"}, {"TIME", "10 S"}, {"AREA", "18 STUDS"}, {"CD", "30 S"}}},
	hookarm = {"CONTROL", "Fire your claw arm at a dino and yank it in for a head smash.", {{"DMG", "15"}, {"PULL", "+ KNOCKBACK"}, {"RANGE", "160"}, {"CD", "6 S"}}},
	mechalegs = {"MOVE", "Piston legs. Leap farther and higher, then leap again in mid-air.", {{"LEAP", "+50% DIST"}, {"POWER", "+45%"}, {"AIR LEAP", "YES"}, {"CD", "2.73 S"}}},
	servodash = {"MOVE", "Hip thrusters blast you forward into a sprint. The headbutt slow can't touch you, and you get a headbutt back.", {{"SPEED", "2X"}, {"TIME", "1.5 S"}, {"REFILL", "+1 HEADBUTT"}, {"CD", "5.6 S"}}},
	visor = {"DEFENSE", "Force field up front. Blocks bites, pounces, headbutts, hooks, cannon shots and ink, and knocks the attacker back.", {{"TIME", "2 S"}, {"BLOCK", "FRONT"}, {"KNOCKBACK", "YES"}, {"CD", "10 S"}}},
	ink = {"CONTROL", "Fire an ink glob. The dino hit and everyone next to it go blind: players see black, bots forget you.", {{"BLIND", "2 S"}, {"SPLASH", "6 STUDS"}, {"RANGE", "160"}, {"CD", "11 S"}}},
	tether = {"CONTROL", "Aim from above and lob a spike. The closest dino in the circle is yanked to it and chained down.", {{"CHAIN", "5 S"}, {"AREA", "15 STUDS"}, {"RANGE", "180"}, {"CD", "10 S"}}},
	bloodrush = {"ATTACK", "Out of headbutts? Pay health for one more. It hits harder and cripples the target.", {{"COST", "25% HP"}, {"DMG", "+25%"}, {"SLOW", "55% · 4 S"}, {"USES", "2"}}},
	quills = {"ATTACK", "Fire a volley of quills at your target.", {{"DMG", "8 x 4"}, {"RANGE", "80"}, {"CD", "20 S"}}},
	glider = {"MOVE", "Hold JUMP in the air to glide. Hit SLASH mid-glide to dive onto anything below.", {{"FALL", "8 STUDS/S"}, {"DIVE", "+30% DMG"}, {"LANDING", "BLEED BURST"}}},
	smoke = {"STEALTH", "Pop a smoke cloud. Bots lose you, you run faster inside, enemies run slower.", {{"TIME", "6 S"}, {"AREA", "28 STUDS"}, {"YOU", "+25% SPEED"}, {"ENEMIES", "-25% SPEED"}, {"CD", "18 S"}}},
	strobe = {"CONTROL", "Flash your frill. Enemies in front can't attack and take extra damage.", {{"DAZE", "1.5 S"}, {"DMG TAKEN", "+20%"}, {"CONE", "90° · 25"}, {"CD", "16 S"}}},
	breaker = {"DEFENSE", "Stunned or pinned? Break free, shove everyone off you and shrug off damage.", {{"PUSH", "10 STUDS"}, {"IMMUNE", "1 S"}, {"CD", "14 S"}}},
	caltrops = {"CONTROL", "Drop hidden razor spikes behind you. Whoever steps on one bleeds and slows.", {{"SPIKES", "10"}, {"BLEED", "3/S · 3 S"}, {"SLOW", "30% · 1 S"}, {"TIME", "14 S"}, {"CD", "16 S"}}},
	goo = {"CONTROL", "Fire 2 goo blobs that splat into sticky puddles. Enemies stay slowed after they get out.", {{"SLOW", "50%"}, {"TIME", "8 S"}, {"AREA", "29 STUDS"}, {"CD", "14 S"}}},
	hadren = {"HEAL", "Jab in a boost. Heal, sprint, and refill every slash charge.", {{"HEAL", "34% HP"}, {"SPEED", "+40%"}, {"TIME", "3 S"}, {"CD", "10.3 S"}}},
	cmissile = {"ATTACK", "Launch a missile and fly it in yourself. Leaves a burning crater. Never hits your team.", {{"DMG", "40"}, {"AREA", "55 STUDS"}, {"BURN", "8/S · 4 S"}, {"CD", "20 S"}}},
	tgrab = {"CONTROL", "Snatch a dino up to Pachy size with your tail and fling it. It's stunned and crashes into anyone where it lands.", {{"DMG", "8"}, {"CRASH", "8 DMG"}, {"STUN", "1 S"}, {"FLING", "45 STUDS"}, {"CD", "16 S"}}},
	tmortar = {"ATTACK", "Lob 2 boulders where you aim. They splash, slow, and leave rubble behind.", {{"DMG", "2 x 12"}, {"SLOW", "30% · 2 S"}, {"AREA", "14 STUDS"}, {"RANGE", "180"}, {"CD", "14 S"}}},
	tstomp = {"CONTROL", "Rear up and stomp. The shockwave stuns everything close and drains a raptor on your back.", {{"DMG", "6"}, {"STUN", "1 S"}, {"AREA", "20 STUDS"}, {"CD", "15 S"}}},
	tbellow = {"SUPPORT", "Rally the herd. You and nearby squadmates get tanky and fast, and stuns are cleared.", {{"DMG TAKEN", "-50%"}, {"SPEED", "+50%"}, {"TIME", "6 S"}, {"RANGE", "40"}, {"CD", "30 S"}}},
	tchallenge = {"CONTROL", "Call out every enemy near you. They hit weaker, move slower, and bots come for you.", {{"THEIR DMG", "-40%"}, {"SLOW", "20%"}, {"TIME", "7 S"}, {"RANGE", "45"}, {"CD", "20 S"}}},
	tleap = {"MOVE", "Every jump is a hydraulic leap. Land it with a tail slam that stuns.", {{"DMG", "10"}, {"STUN", "0.5 S"}, {"LEAP", "55 STUDS"}, {"CHARGES", "2 · 4.2 S"}}},
	tmud = {"DEFENSE", "Energy shield that eats your next hits. Every block slows enemies around you, and it bursts when it ends.", {{"BLOCKS", "4 HITS"}, {"TIME", "12 S"}, {"SLOW", "40% · 4 S"}, {"CD", "20 S"}}},
	zhook = {"ATTACK", "Fire your chest claw at an enemy, reel in and slash. It's stunned and your combo starts on it.", {{"DMG", "10"}, {"STUN", "1 S"}, {"RANGE", "160"}, {"CD", "14 S"}}},
	zfeather = {"ATTACK", "Fan out feather blades. Every hit slows.", {{"DMG", "12 x 3"}, {"SLOW", "25% · 2 S"}, {"RANGE", "100"}, {"CD", "14 S"}}},
	zharvest = {"CONTROL", "Stab your claws in. A spinning sickle ring drags enemies to you while they bleed.", {{"BLEED", "4/S"}, {"SLOW", "30%"}, {"TIME", "5 S"}, {"AREA", "38 STUDS"}, {"CD", "20 S"}}},
	zgrapple = {"MOVE", "Jolt the way you're moving.", {{"DASH", "50 STUDS"}, {"CHARGES", "3 · 3 S"}}},
	zdeflect = {"DEFENSE", "Spin your claws in front of you. Darts, boulders and cannon shots bounce back at the shooter.", {{"TIME", "2 S"}, {"REFLECT", "YES"}, {"CD", "13 S"}}},
	zclock = {"PASSIVE", "Overclocked joints. Always on.", {{"SPEED", "+40%"}, {"SLASH", "30% FASTER"}, {"JUMPS", "+1"}, {"SLOWS", "IMMUNE"}}},
	zsnare = {"CONTROL", "Sling a bola from your tail. It wraps the target's legs and holds it in place.", {{"DMG", "12"}, {"ROOT", "2 S"}, {"RANGE", "160"}, {"CHARGES", "3 · 14 S"}}},
	dgatling = {"ATTACK", "Your hood barrels spray auto-aimed venom darts.", {{"DMG", "8 x 3"}, {"VENOM", "EACH DART"}, {"TIME", "1 S"}, {"CD", "10 S"}}},
	dmortar = {"ATTACK", "Lob a toxin canister. It blows up and leaves a poison cloud.", {{"DMG", "20"}, {"CLOUD", "5 S"}, {"AREA", "54 STUDS"}, {"RANGE", "120"}, {"CD", "16 S"}}},
	dhiss = {"CONTROL", "Blast a sonic hiss. Dinos in the cone get knocked back and their mecha parts shut down.", {{"SILENCE", "3 S"}, {"KNOCKBACK", "YES"}, {"CD", "12 S"}}},
	dspine = {"ATTACK", "Fire venom spines out in every direction.", {{"DMG", "12 x 4"}, {"VENOM", "EACH SPINE"}, {"CD", "12 S"}}},
	dpump = {"HEAL", "Pump antivenom. Clear every debuff, heal up, then shrug off slows, stuns and blinds.", {{"HEAL", "+30 HP"}, {"IMMUNE", "4 S"}, {"CD", "20 S"}}},
	djets = {"MOVE", "Your tail booster fires a dash and leaves a poison trail.", {{"DASH", "65 STUDS"}, {"CHARGES", "3 · 4.2 S"}}},
	dover = {"ATTACK", "Overdrive. Spit nonstop with no ammo and double venom. Your shots refill.", {{"TIME", "8 S"}, {"VENOM", "2X DMG"}, {"CD", "30 S"}}},
	dscope = {"ATTACK", "Hold to scope in, let go to fire an instant venom shot. A hit marks the dino for your squad.", {{"DMG", "15 - 40"}, {"CHARGE", "1 S"}, {"RANGE", "200"}, {"MARK", "3 S"}, {"CD", "8 S"}}},
	omender = {"HEAL", "Your drone heals your most hurt squadmate, then moves on to the next. Solo, it heals you.", {{"HEAL", "4/S"}, {"TIME", "5.4 S"}, {"RANGE", "40"}, {"CD", "14.8 S"}}},
	olantern = {"CONTROL", "Throw a lantern. It zaps the nearest enemy and chains through the pack.", {{"DMG", "12 EACH"}, {"STUN", "1 S"}, {"TARGETS", "3"}, {"CD", "10.3 S"}}},
	osapwall = {"DEFENSE", "Throw a sap pod. It hardens into a giant wall that stops dinos and shots.", {{"WALL", "100 x 30"}, {"TIME", "8 S"}, {"CHARGES", "2 · 18 S"}}},
	oshed = {"DEFENSE", "Shed your feathers to break a stun, pin or grab. The burst knocks dinos back and slows them.", {{"IMMUNE", "1.4 S"}, {"AREA", "20 STUDS"}, {"SLOW", "25% · 2 S"}, {"CD", "17.7 S"}}},
	oportal = {"MOVE", "Drop a portal, run, drop the other end. Any dino can zip along your path untouchable.", {{"SPEED", "5X"}, {"LENGTH", "250 STUDS"}, {"OPEN", "30 S"}, {"CD", "45 S"}}},
	obloom = {"PASSIVE", "Bigger, longer glow zones. When one ends, it heals your squad and keeps enemies slowed.", {{"AREA", "54 STUDS"}, {"TIME", "4 S"}, {"END", "+5 HEAL"}}},
	oburst = {"HEAL", "Throw a bud. Squadmates heal and get boosted healing. Enemies inside heal less.", {{"HEAL", "+20 HP"}, {"BOOST", "+50% · 5.4 S"}, {"AREA", "54 STUDS"}, {"CD", "13.3 S"}}},
	odome = {"DEFENSE", "Throw a canister and a giant dome pops up. Enemy shots stop on it, yours go out.", {{"TIME", "6.75 S"}, {"AREA", "121 STUDS"}, {"CD", "18.5 S"}}},
	osleep = {"CONTROL", "Fire a sleep dart. The target and one enemy next to it are out cold until something hits them.", {{"SLEEP", "3.4 S"}, {"TARGETS", "2"}, {"RANGE", "120"}, {"CD", "8.9 S"}}},
	osentry = {"ATTACK", "Throw twin turrets. They shoot the nearest enemy until they run dry.", {{"DMG", "UP TO 20"}, {"TIME", "10.8 S"}, {"RANGE", "60"}, {"CD", "16.3 S"}}},
}
local function scHead(stats) -- the row's headline: DMG if any, else the first stat
	for _, kv in ipairs(stats) do
		if kv[1] == "DMG" then
			local v = kv[2]
			return v:sub(-5) == " EACH" and v:sub(1, -6) .. " DMG EACH" or v .. " DMG"
		end
	end
	local kv = stats[1]
	if not kv then return "" end
	return kv[2]:sub(-2) == "HP" and kv[2] or kv[2] .. " " .. kv[1]
end
local function scBadge(how, key)
	if key and not isTouch() then return key end
	if how == "hold" then return isTouch() and "HOLD" or "HOLD CLICK" end
	if how == "tap3" then return isTouch() and "TAP x3" or "CLICK x3" end
	return isTouch() and "TAP" or "CLICK"
end
local function drawShowcase2()
	backdrop()
	local function cq(n, mn) return math.max(W * n / 100, mn or 0) end
	local function z(o, n) o.ZIndex = n return o end
	local function lbl(parent, s2, font, size, color, props)
		local l = make("TextLabel", {BackgroundTransparency = 1, Text = s2, Font = font, TextSize = size, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.fromScale(1, 1), ZIndex = 6}, parent)
		l:SetAttribute("FontSwap", font == Enum.Font.FredokaOne and "silk" or "keep")
		for k, v in pairs(props or {}) do l[k] = v end
		return l
	end
	local models = ReplicatedStorage:FindFirstChild("PregameModels")
	local ready = models ~= nil
	for _, key in ipairs(R.ROLL_POOL) do
		local f = models and models:FindFirstChild(key)
		local body = f and f:FindFirstChild("Body")
		local pc = body and tonumber(body:GetAttribute("PieceCount"))
		if not body or (pc and #body:GetDescendants() < pc) then ready = false end
	end
	if not ready then -- the 3D bodies arrive after the join (as 1.4): draw again every 0.5 s until all are complete
		task.delay(0.5, function()
			if step() == 1 and not pod.showcased and pod.phase == "charge" then pod.sceneKey = nil render() end
		end)
	end
	pod.scIdx = pod.scIdx or 1
	local L0, topY = W * 0.03, math.max(topH + px(0.6, 4), H * 0.05)
	-- left: title + roster by role
	local tb = z(make("Frame", {Name = "Title", BackgroundTransparency = 1, Position = UDim2.fromOffset(L0, topY), Size = UDim2.fromOffset(W * 0.24, cq(7.4, 52))}, root), 5)
	list(tb, nil, 0, Enum.HorizontalAlignment.Left).VerticalAlignment = Enum.VerticalAlignment.Top
	text(tb, "MECHA DINO ARENA", "title", cq(1.3, 9), C.yellow, {LayoutOrder = 1, ZIndex = 6})
	local rosterT = script:GetAttribute("TutorialRosterTitleEnabled") ~= false -- v1.7
	text(tb, rosterT and "MEET THE ROSTER" or "YOUR FIRST DINO", "title", cq(3, 20), C.white, {LayoutOrder = 2, ZIndex = 6})
	text(tb, (rosterT and "1 OF THESE %d IS YOURS FREE" or "1 OF THESE %d \u{00B7} FREE"):format(#R.ROLL_POOL), "black", cq(1.2, 9), C.text,
		{LayoutOrder = 3, ZIndex = 6})
	local tile = math.min(cq(6.6, 44), (H - topY - cq(7.4, 52) - 3 * cq(1.6, 12) - px(1, 6)) / 3.3)
	local roster = z(make("Frame", {Name = "Roster", BackgroundTransparency = 1, Position = UDim2.fromOffset(L0, topY + cq(7.4, 52) + px(0.6, 4)),
		Size = UDim2.fromOffset(W * 0.235, H)}, root), 5)
	list(roster, nil, px(0.6, 4), Enum.HorizontalAlignment.Left).VerticalAlignment = Enum.VerticalAlignment.Top
	local tiles, tileTurns = {}, {}
	for gi, g in ipairs(SC_GROUPS) do
		local role = g[1]
		local grp = z(make("Frame", {BackgroundTransparency = 1, LayoutOrder = gi, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0)}, roster), 5)
		list(grp, nil, px(0.3, 2), Enum.HorizontalAlignment.Left).VerticalAlignment = Enum.VerticalAlignment.Top
		text(grp, role, "black", cq(1, 8), ROLE_COLOR[role] or C.cyan, {LayoutOrder = 1, ZIndex = 6})
		local row = z(make("Frame", {BackgroundTransparency = 1, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, tile * 1.06)}, grp), 5)
		list(row, Enum.FillDirection.Horizontal, px(0.6, 4), Enum.HorizontalAlignment.Left)
		for ki, key in ipairs(g[2]) do
			local t = z(make("TextButton", {Name = "Tile_" .. key, Text = "", AutoButtonColor = true, BackgroundColor3 = C.card, LayoutOrder = ki,
				Size = UDim2.fromOffset(tile, tile * 1.06)}, row), 6)
			corner(t, UDim.new(0, px(0.9, 6)))
			local st = stroke(t, C.line, px(0.25, 2))
			local art = z(make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -cq(1.6, 12))}, t), 7)
			if ready then local vf, _ = dinoView(art, key) vf.ZIndex = 7 end
			text(t, string.upper(dinoName(key)), "black", cq(0.9, 8), C.white, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -px(0.3, 2)),
				TextWrapped = false, ZIndex = 8})
			tiles[key] = {b = t, s = st}
		end
	end
	-- middle: the dino on its base
	-- the stage keeps a wide shape (w / h 1.25) so the turning dino fits; it stands on the base, above the dots and NEXT
	local sx, sw2 = W * 0.265, W * 0.245
	local nextB = H - cq(2.4, 14)
	local dotsY = nextB - px(5.4, 44) - px(1.6, 12)
	local baseH = sw2 * 0.86 * 0.22
	local baseY = dotsY - px(1.4, 10) - baseH / 2
	local sh = math.min(sw2 / 1.25, baseY - math.max(topH, H * 0.12))
	local sy = baseY + baseH * 0.1 - sh
	local base = z(make("Frame", {Name = "Base", BackgroundColor3 = Color3.fromRGB(52, 64, 94), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(sx + sw2 / 2, baseY), Size = UDim2.fromOffset(sw2 * 0.86, baseH)}, root), 3)
	corner(base, UDim.new(0.5, 0))
	make("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(150, 160, 185), Color3.fromRGB(60, 66, 86)), Rotation = 90}, base)
	local ring = stroke(base, C.cyan, px(0.45, 3), 0)
	local stage = z(make("Frame", {Name = "Stage", BackgroundTransparency = 1, Position = UDim2.fromOffset(sx, sy), Size = UDim2.fromOffset(sw2, sh)}, root), 4)
	local dots = z(make("Frame", {Name = "Dots", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(sx + sw2 / 2, dotsY),
		Size = UDim2.fromOffset(sw2, px(1, 7))}, root), 5)
	list(dots, Enum.FillDirection.Horizontal, px(0.6, 4))
	local dotList = {}
	for i = 1, #R.ROLL_POOL do
		local d = z(make("Frame", {BackgroundColor3 = C.line, LayoutOrder = i, Size = UDim2.fromOffset(px(0.75, 5), px(0.75, 5))}, dots), 6)
		corner(d, UDim.new(0.5, 0))
		dotList[i] = d
	end
	local nb = cta(root, "NEXT", function()
		pod.showcased = true
		pod.sceneKey = nil
		task.defer(function() render() end)
	end, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(sx + sw2 / 2, nextB)})
	nb.Name = "Next"
	nb.ZIndex = 8
	-- right: name, main attack cards, abilities, the open ability's card
	local ix, iw = W * 0.515, W * 0.459
	local iy = math.max(H * 0.045, topH * 0.6)
	local ih = H - cq(2.4, 14) - iy
	local info = z(make("Frame", {Name = "Info", BackgroundTransparency = 1, Position = UDim2.fromOffset(ix, iy), Size = UDim2.fromOffset(iw, ih)}, root), 5)
	local gap = px(0.55, 4)
	local nameS, lineS, statL, statV = cq(3, 20), cq(1.05, 10), cq(0.72, 7), cq(1.05, 10)
	local gridH = statL + statV + px(0.7, 6)
	local function statGrid(parent, stats, y)
		local g = z(make("Frame", {Name = "Stats", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, gridH)}, parent), 6)
		list(g, Enum.FillDirection.Horizontal, px(0.4, 3), Enum.HorizontalAlignment.Left)
		for i, kv in ipairs(stats) do
			local c = z(make("Frame", {BackgroundColor3 = Color3.fromRGB(11, 17, 26), LayoutOrder = i, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0)}, g), 7)
			corner(c, UDim.new(0, px(0.4, 3)))
			stroke(c, C.line, 1)
			pad(c, px(0.2, 2), px(0.6, 5))
			list(c, nil, 0, Enum.HorizontalAlignment.Left)
			text(c, kv[1], "black", statL, C.muted, {LayoutOrder = 1, ZIndex = 8, TextWrapped = false})
			text(c, kv[2], "black", statV, C.yellow, {LayoutOrder = 2, ZIndex = 8, TextWrapped = false})
		end
		return g
	end
	local head = z(make("Frame", {Name = "Head", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, nameS * 1.1)}, info), 5)
	local nameL = lbl(head, "", Enum.Font.FredokaOne, nameS, C.white, {AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0)})
	local chip = text(head, "", "black", cq(1, 8), C.ink, {BackgroundTransparency = 0, AnchorPoint = Vector2.new(0, 0.5), TextWrapped = false, ZIndex = 7})
	corner(chip, UDim.new(0, px(0.4, 3)))
	pad(chip, px(0.2, 2), px(0.6, 5))
	lbl(head, ("1 IN %d"):format(#R.ROLL_POOL), Enum.Font.GothamBlack, cq(1.15, 9), C.yellow, {TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center})
	local body = z(make("Frame", {Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, nameS * 1.1 + gap), Size = UDim2.new(1, 0, 1, -(nameS * 1.1 + gap))}, info), 5)
	local detH = px(0.6, 5) * 2 + cq(1.6, 12) * 1.2 + lineS * 1.25 * 2 + gridH + gap * 2
	local function section(parent, s2, y)
		local f = z(make("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, cq(1, 8) * 1.3)}, parent), 5)
		lbl(f, s2, Enum.Font.GothamBlack, cq(0.95, 8), C.muted)
		local ln = z(make("Frame", {BackgroundColor3 = C.line, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0.68, 0, 0, 1)}, f), 6)
		return f, f.Size.Y.Offset
	end
	local view = {}
	local function openAbility(dino, id)
		pod.scAb = id
		for aid, r in pairs(view.rows or {}) do
			r.s.Color = aid == id and C.yellow or C.line
			r.b.BackgroundColor3 = aid == id and Color3.fromRGB(29, 39, 56) or C.card
		end
		local d = view.detail
		if not d then return end
		for _, c in ipairs(d:GetChildren()) do if not c:IsA("UICorner") and not c:IsA("UIStroke") then c:Destroy() end end
		local inf = SC_INFO[id] or {"PASSIVE", "", {}}
		if player:GetAttribute("SkillUnlockOnly") == true and script:GetAttribute("TutUnlockCopyEnabled") ~= false then inf = {inf[1], inf[2], {}} end -- v1.10
		local ty = SC_TYPE[inf[1]] or C.muted
		local p0 = px(0.6, 5)
		local nm = text(d, pname(id), "title", cq(1.6, 12), C.white, {Position = UDim2.fromOffset(p0 * 1.5, p0), TextWrapped = false, ZIndex = 7})
		local tchip = text(d, " " .. inf[1] .. " ", "black", cq(0.85, 8), C.ink, {BackgroundTransparency = 0, BackgroundColor3 = ty, TextWrapped = false, ZIndex = 7})
		corner(tchip, UDim.new(0, px(0.35, 3)))
		task.defer(function() if tchip.Parent then tchip.Position = UDim2.fromOffset(nm.AbsoluteSize.X + p0 * 2.6, p0 + (nm.AbsoluteSize.Y - tchip.AbsoluteSize.Y) / 2) end end)
		local y = p0 + cq(1.6, 12) * 1.2
		local ln = lbl(d, inf[2], Enum.Font.GothamBold, lineS, C.text, {TextWrapped = true, Position = UDim2.fromOffset(p0 * 1.5, y), Size = UDim2.new(1, -p0 * 3, 0, lineS * 2.5)})
		statGrid(d, inf[3], y + lineS * 2.5 + gap).Position = UDim2.fromOffset(p0 * 1.5, y + lineS * 2.5 + gap)
		local _ = ln
	end
	local function show(i)
		pod.scIdx = i
		local key = R.ROLL_POOL[i]
		local role = R.ROLE[key] or "FIGHTER"
		for k, t in pairs(tiles) do
			t.s.Color = k == key and C.yellow or C.line
			t.s.Thickness = k == key and px(0.35, 3) or px(0.25, 2)
		end
		for j, d in ipairs(dotList) do d.BackgroundColor3 = j == i and C.yellow or C.line end
		ring.Color = ROLE_COLOR[role] or C.cyan
		nameL.Text = string.upper(dinoName(key))
		chip.Text = role
		chip.BackgroundColor3 = ROLE_COLOR[role] or C.cyan
		task.defer(function() if chip.Parent then chip.Position = UDim2.new(0, nameL.AbsoluteSize.X + px(1, 7), 0.5, 0) end end)
		stage:ClearAllChildren()
		view.turn = nil
		if ready then
			local vf, turn = dinoView(stage, key)
			vf.ZIndex = 4
			if vf.CurrentCamera then vf.CurrentCamera.FieldOfView = 40 end -- wider than dinoView's 30: long dinos (Teno) fit the stage
			view.turn = turn
		end
		body:ClearAllChildren()
		local y = 0
		local _, sh2 = section(body, "MAIN ATTACK", y)
		y += sh2 + gap * 0.6
		local atks = SC_ATK[key] or {}
		local cols = math.max(1, #atks) -- two main attacks (Teno) sit side by side
		local cw = (iw - gap * (cols - 1)) / cols
		local p0 = px(0.55, 4)
		local cardH = 0
		local lineHs = {}
		for ai, a in ipairs(atks) do
			local tsz = TextService:GetTextSize(a[4], lineS, Enum.Font.GothamBold, Vector2.new(cw - p0 * 3.5, 1000))
			local lines = math.clamp(math.ceil(tsz.Y / (lineS * 1.05) - 0.01), 1, 2) -- the line wraps to 2 rows when it needs to
			lineHs[ai] = lineS * 1.3 * lines
			cardH = math.max(cardH, p0 * 2 + cq(1.5, 12) * 1.15 + lineHs[ai] + gap + gridH)
		end
		for ai, a in ipairs(atks) do
			local lineH = lineHs[ai]
			local card = z(make("Frame", {Name = "Attack", BackgroundColor3 = C.card, Position = UDim2.fromOffset((ai - 1) * (cw + gap), y), Size = UDim2.fromOffset(cw, cardH)}, body), 5)
			corner(card, UDim.new(0, px(0.7, 5)))
			stroke(card, C.line, 1)
			z(make("Frame", {BackgroundColor3 = C.yellow, BorderSizePixel = 0, Size = UDim2.new(0, px(0.45, 3), 1, 0)}, card), 6)
			text(card, a[1], "title", cq(1.5, 12), C.white, {Position = UDim2.fromOffset(p0 * 2, p0), TextWrapped = false, ZIndex = 7})
			local bd = text(card, " " .. scBadge(a[2], a[3]) .. " ", "black", cq(0.95, 8), C.ink, {BackgroundTransparency = 0, BackgroundColor3 = C.yellow,
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -p0 * 1.5, 0, p0), TextWrapped = false, ZIndex = 7})
			corner(bd, UDim.new(0, px(0.4, 3)))
			lbl(card, a[4], Enum.Font.GothamBold, lineS, C.text, {Position = UDim2.fromOffset(p0 * 2, p0 + cq(1.5, 12) * 1.15), Size = UDim2.new(1, -p0 * 3.5, 0, lineH),
				TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd})
			statGrid(card, a[5], 0).Position = UDim2.new(0, p0 * 2, 1, -(p0 + gridH))
		end
		y += cardH + gap
		local pss = script:GetAttribute("TutorialRosterPassiveEnabled") ~= false and R.passivesFor(key) or {} -- v1.7: PASSIVE
		if #pss > 0 then
			local _, shp = section(body, "PASSIVE", y)
			y += shp + gap * 0.6
			for _, P in ipairs(pss) do
				local tsz = TextService:GetTextSize(P.line, lineS, Enum.Font.GothamBold, Vector2.new(iw - p0 * 3.5, 1000))
				local lineH = lineS * 1.3 * math.clamp(math.ceil(tsz.Y / (lineS * 1.05) - 0.01), 1, 2)
				local ph = p0 * 2 + cq(1.5, 12) * 1.15 + lineH
				local pc = z(make("Frame", {Name = "Passive", BackgroundColor3 = C.card, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, ph)}, body), 5)
				corner(pc, UDim.new(0, px(0.7, 5)))
				stroke(pc, C.line, 1)
				z(make("Frame", {BackgroundColor3 = C.green, BorderSizePixel = 0, Size = UDim2.new(0, px(0.45, 3), 1, 0)}, pc), 6)
				text(pc, P.n, "title", cq(1.5, 12), C.white, {Position = UDim2.fromOffset(p0 * 2, p0), TextWrapped = false, ZIndex = 7})
				local tg = text(pc, " " .. P.tag .. " ", "black", cq(0.95, 8), C.ink, {BackgroundTransparency = 0, BackgroundColor3 = C.green,
					AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -p0 * 1.5, 0, p0), TextWrapped = false, ZIndex = 7})
				corner(tg, UDim.new(0, px(0.4, 3)))
				lbl(pc, P.line, Enum.Font.GothamBold, lineS, C.text, {Position = UDim2.fromOffset(p0 * 2, p0 + cq(1.5, 12) * 1.15),
					Size = UDim2.new(1, -p0 * 3.5, 0, lineH), TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd})
				y += ph + gap
			end
		end
		local ids = partsOf(key, false, true)
		local _, sh3 = section(body, ("ABILITIES \u{00B7} %d"):format(#ids), y)
		y += sh3 + gap * 0.6
		local listH = math.max(px(6, 40), body.AbsoluteSize.Y - y - detH - gap)
		local sc = z(make("ScrollingFrame", {Name = "Abilities", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, listH),
			ScrollBarThickness = px(0.3, 3), ScrollBarImageColor3 = C.line, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y}, body), 5)
		local rowH = cq(1.12, 10) * 1.1 + cq(0.78, 7) * 1.1 + px(0.4, 3)
		local cellW = (iw - px(0.3, 3)) / 2 - gap / 2
		make("UIGridLayout", {CellSize = UDim2.new(0.5, -gap / 2 - px(0.3, 3), 0, rowH), CellPadding = UDim2.fromOffset(gap * 0.7, gap * 0.5),
			SortOrder = Enum.SortOrder.LayoutOrder}, sc)
		view.rows = {}
		for i, id in ipairs(ids) do
			local inf = SC_INFO[id] or {"PASSIVE", "", {}}
			if player:GetAttribute("SkillUnlockOnly") == true and script:GetAttribute("TutUnlockCopyEnabled") ~= false then inf = {inf[1], inf[2], {}} end -- v1.10
			local ty = SC_TYPE[inf[1]] or C.muted
			local b = z(make("TextButton", {Name = "Ab_" .. id, Text = "", AutoButtonColor = true, BackgroundColor3 = C.card, LayoutOrder = i}, sc), 6)
			corner(b, UDim.new(0, px(0.6, 4)))
			local s = stroke(b, C.line, 1)
			z(make("Frame", {BackgroundColor3 = ty, BorderSizePixel = 0, Size = UDim2.new(0, px(0.35, 3), 1, 0)}, b), 7)
			local p0 = px(0.2, 1)
			local hl = scHead(inf[3])
			local hw = TextService:GetTextSize(hl, cq(0.88, 8), Enum.Font.GothamBlack, Vector2.new(1000, 100)).X + px(0.6, 5) -- the headline keeps its width
			local nw = math.max(cellW * 0.3, cellW - hw - px(1.1, 8) - px(0.6, 5))
			lbl(b, pname(id), Enum.Font.GothamBold, cq(1.12, 10), C.white, {Position = UDim2.fromOffset(px(1.1, 8), p0), Size = UDim2.new(0, nw, 0, cq(1.12, 10) * 1.1),
				TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8})
			lbl(b, inf[1], Enum.Font.GothamBlack, cq(0.78, 7), ty, {Position = UDim2.fromOffset(px(1.1, 8), p0 + cq(1.12, 10) * 1.1), Size = UDim2.new(0.62, 0, 0, cq(0.78, 7) * 1.1), ZIndex = 8})
			lbl(b, hl, Enum.Font.GothamBlack, cq(0.88, 8), C.yellow, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -px(0.6, 5), 0, 0),
				Size = UDim2.new(0, hw, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8})
			b.Activated:Connect(function()
				pod.scHoldUntil = os.clock() + (tonumber(script:GetAttribute("TutShowcaseHold")) or 10)
				openAbility(key, id)
			end)
			view.rows[id] = {b = b, s = s}
		end
		local d = z(make("Frame", {Name = "Card", BackgroundColor3 = Color3.fromRGB(13, 19, 28), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, detH)}, body), 5)
		corner(d, UDim.new(0, px(0.7, 5)))
		stroke(d, C.line, 1)
		view.detail = d
		openAbility(key, ids[1])
		pod.scShownAt = os.clock()
		player:SetAttribute("TutShowcaseDino", key)
	end
	for key, t in pairs(tiles) do
		t.b.Activated:Connect(function()
			pod.scHoldUntil = os.clock() + (tonumber(script:GetAttribute("TutShowcaseHold")) or 10)
			show(table.find(R.ROLL_POOL, key) or 1)
		end)
	end
	task.defer(function() if body.Parent then show(pod.scIdx) end end) -- after layout (the list height reads body's size)
	pod.conn = RunService.RenderStepped:Connect(function(dt2)
		if view.turn then view.turn(dt2) end
		local cyc = tonumber(script:GetAttribute("TutShowcaseCycle")) or 5
		if cyc > 0 and pod.scShownAt and os.clock() - pod.scShownAt > cyc and os.clock() > (pod.scHoldUntil or 0) then
			show(pod.scIdx % #R.ROLL_POOL + 1)
		end
	end)
end
-- v1.7: the welcome screen (see the header)
WM = {welcomed = false, jpN = nil, jpSince = 0, jpTapAt = -100, jpTok = 0}
for _, k in ipairs({"TutorialWelcomeEnabled", "TutorialRosterTitleEnabled", "TutorialRosterPassiveEnabled", "TutorialRevealPassiveEnabled",
	"TutorialJumpPartsEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
if script:GetAttribute("TutJumpPartSkipAfter") == nil then script:SetAttribute("TutJumpPartSkipAfter", 20) end
if script:GetAttribute("TutorialRevealFitEnabled") == nil then script:SetAttribute("TutorialRevealFitEnabled", true) end -- v1.7.1
if script:GetAttribute("TutRevealFov") == nil then script:SetAttribute("TutRevealFov", 44) end -- v1.7.1
local function welcomeOn() return script:GetAttribute("TutorialWelcomeEnabled") ~= false end
local function drawWelcome()
	backdrop()
	local function cq(n, mn) return math.max(W * n / 100, mn or 0) end
	local head = make("Frame", {Name = "WelcomeHead", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), ZIndex = 5,
		Position = UDim2.new(0.5, 0, 0, math.max(topH + px(0.6, 4), H * 0.14)), Size = UDim2.new(0.9, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, root)
	list(head, nil, px(0.5, 4))
	text(head, "WELCOME TO", "black", cq(1.6, 11), C.cyan, {LayoutOrder = 1, TextWrapped = false})
	text(head, 'MECHA <font color="#FFC832">DINO</font> ARENA', "title", cq(6.4, 32), C.white, {LayoutOrder = 2})
	local tw, gap = cq(19, 118), cq(1.6, 10)
	local th = cq(9.5, 66) -- Studio check: fitted (13.5 cqw left the tiles half empty)
	local row = make("Frame", {Name = "Tiles", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), ZIndex = 5,
		Position = UDim2.new(0.5, 0, 0, H * 0.43), Size = UDim2.fromOffset(tw * 3 + gap * 2, th)}, root)
	list(row, Enum.FillDirection.Horizontal, gap)
	local TILES = {{"", "FIGHT", "Squad battles on the island"}, {"", "UPGRADE", "Mecha parts and skill points"},
		{"", "COLLECT", "7 dinos, skins, emotes, trails"}} -- Studio check: no icons (see the tile text below)
	if script:GetAttribute("TutWelcomeArenaCopyEnabled") ~= false then TILES[1][3] = "4v4 Arena matches" end -- v1.9
	if player:GetAttribute("SkillUnlockOnly") == true and script:GetAttribute("TutUnlockCopyEnabled") ~= false then TILES[2][2], TILES[2][3] = "UNLOCK", "Mecha parts with your points" end -- v1.10
	for i, t in ipairs(TILES) do
		local holder = make("Frame", {Name = "Slot" .. i, BackgroundTransparency = 1, LayoutOrder = i, Size = UDim2.fromOffset(tw, th)}, row)
		local card = make("Frame", {Name = "Tile", BackgroundColor3 = C.card, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, px(2, 14)),
			BackgroundTransparency = 1}, holder)
		corner(card, UDim.new(0, px(1.4, 10)))
		local st = stroke(card, C.line, px(0.25, 2), 1)
		pad(card, px(1, 8), px(1, 8))
		list(card, nil, px(0.5, 4)) -- Studio check: centred, no icon line (the emoji ignored the yellow)
		local parts = {
			text(card, t[2], "title", cq(2.2, 15), C.yellow, {LayoutOrder = 2, TextTransparency = 1}),
			text(card, t[3], "body", cq(1.4, 11), C.text, {LayoutOrder = 3, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0),
				TextTransparency = 1}),
		}
		task.delay(0.12 * (i - 1), function()
			if not card.Parent then return end
			tween(card, 0.45, {BackgroundTransparency = 0, Position = UDim2.fromOffset(0, 0)})
			tween(st, 0.45, {Transparency = 0})
			for _, l in ipairs(parts) do tween(l, 0.45, {TextTransparency = 0}) end
		end)
	end
	local b = cta(root, "LET'S GO", function()
		WM.welcomed = true
		pod.sceneKey = nil
		task.defer(function() render() end)
	end, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -cq(3.4, 18))})
	b.Name = "LetsGo"
	b.ZIndex = 8
end
local function incubatorKey(s)
	local rolled = player:GetAttribute("TutRolled") or ""
	local scene = rolled == "" and (pod.phase == "open" and "wait" or "charge") or ("reveal:" .. rolled)
	if s == 1 and rolled == "" and pod.phase ~= "open" then scene = (showcaseOn() and not pod.showcased) and "showcase" or "charge" end -- v1.4
	if scene == "showcase" and welcomeOn() and not WM.welcomed then scene = "welcome" end -- v1.7
	return scene .. "|" .. math.floor(W) .. "x" .. math.floor(H) .. "|" .. tostring(isTouch())
end

-- ---------- v1.3: the Lab coach (see the header) ----------
if script:GetAttribute("TutorialLabCoachEnabled") == nil then script:SetAttribute("TutorialLabCoachEnabled", true) end
local function coachOn() return script:GetAttribute("TutorialLabCoachEnabled") ~= false end
local coachGui = Instance.new("ScreenGui")
coachGui.Name = "TutorialCoach"
coachGui.DisplayOrder = 47
coachGui.IgnoreGuiInset = true
pcall(function() coachGui.ScreenInsets = Enum.ScreenInsets.None end) -- the dark layer reaches the phone's side edges too
coachGui.ResetOnSpawn = false
coachGui.Enabled = false
coachGui.Parent = player:WaitForChild("PlayerGui")
local coach = {conn = nil, step = 0, picked = nil, prev = {}, flash = nil, sent = false, reopenAt = 0, parts = nil}
local function coachStop()
	if coach.conn then coach.conn:Disconnect() coach.conn = nil end
	coachGui.Enabled = false
	coachGui:ClearAllChildren()
end
local function labScript() return player:FindFirstChild("PlayerScripts") and player.PlayerScripts:FindFirstChild("Lab") end
local function labGui() return player.PlayerGui:FindFirstChild("Lab") end
local function labOpen(open)
	local l = labScript()
	local fn = l and l:FindFirstChild(open and "Open" or "Close")
	if fn then task.spawn(function() pcall(function() fn:Invoke(open and "compact" or nil) end) end) end
end
local function labFind(name, class)
	local g = labGui()
	if not g then return nil end
	for _, d in ipairs(g:GetDescendants()) do
		if d.Name == name and (not class or d:IsA(class)) then return d end
	end
	return nil
end
local function labActionBtn(prefixes)
	local acts = labFind("Actions")
	if not acts then return nil end
	for _, b in ipairs(acts:GetChildren()) do
		local t = b:IsA("GuiButton") and b:FindFirstChild("T")
		if t and t:IsA("TextLabel") then
			for _, pfx in ipairs(prefixes) do
				if string.sub(t.Text, 1, #pfx) == pfx then return b end
			end
		end
	end
	return nil
end
-- move a scrolling frame so the target is inside its window
local function scrollTo(target)
	local sf = target and target:FindFirstAncestorWhichIsA("ScrollingFrame")
	if not sf then return end
	local top, bottom = sf.AbsolutePosition.Y, sf.AbsolutePosition.Y + sf.AbsoluteWindowSize.Y
	local ty, tb = target.AbsolutePosition.Y, target.AbsolutePosition.Y + target.AbsoluteSize.Y
	if tb > bottom - 4 then
		sf.CanvasPosition = Vector2.new(sf.CanvasPosition.X, sf.CanvasPosition.Y + (tb - bottom) + 8)
	elseif ty < top + 2 then
		sf.CanvasPosition = Vector2.new(sf.CanvasPosition.X, math.max(0, sf.CanvasPosition.Y - (top - ty) - 8))
	end
end
local SLOT_TAGS_TOUCH = {{"R = BUTTON 1", "TAP"}, {"C = BUTTON 2", "TAP"}, {"R\u{25BC} = BUTTON 1", "PULL \u{25BC}"}, {"C\u{25BC} = BUTTON 2", "PULL \u{25BC}"}}
local SLOT_KEYS_PC = {"R", "C", "T", "V"}
-- the coach's pieces (built once per draw, moved every frame)
local function coachBuild(s)
	coachGui:ClearAllChildren()
	coachGui.Enabled = true
	local cr = make("Frame", {Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)}, coachGui)
	local shades = {}
	for i = 1, 4 do
		shades[i] = make("TextButton", {Name = "Shade" .. i, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(4, 7, 12),
			BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 1}, cr)
	end
	local ring = make("Frame", {Name = "Ring", BackgroundTransparency = 1, ZIndex = 3}, cr)
	corner(ring, UDim.new(0, px(1.2, 8)))
	local rs = stroke(ring, C.yellow, px(0.45, 3))
	tween(rs, 0.5, {Transparency = 0.55}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local d = px(3.4, 24)
	local finger = make("Frame", {Name = "Finger", BackgroundColor3 = C.white, BackgroundTransparency = 0.05, AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(d, d), ZIndex = 5}, cr)
	corner(finger, UDim.new(0.5, 0))
	stroke(finger, C.white, 3, 0.5)
	local fs = make("UIScale", {}, finger)
	tween(fs, 0.45, {Scale = 0.7}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local bub = make("Frame", {Name = "Tag", BackgroundColor3 = C.yellow, AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 6}, cr)
	corner(bub, UDim.new(0, px(0.9, 6)))
	pad(bub, px(0.7, 5), px(1.2, 9))
	list(bub, nil, px(0.2, 2), Enum.HorizontalAlignment.Left)
	local big = text(bub, "", "title", px(2.3, 17), C.ink, {LayoutOrder = 1, ZIndex = 6, TextWrapped = false})
	local small = text(bub, "", "black", px(1.5, 12), Color3.fromRGB(74, 58, 16), {LayoutOrder = 2, ZIndex = 6, TextWrapped = false})
	-- the chip
	local chip = make("Frame", {Name = "Chip", BackgroundColor3 = C.panel, BackgroundTransparency = 0.05, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(W / 2, math.max(topH / 2, px(3, 20))), AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 7}, cr)
	corner(chip, UDim.new(0, px(1, 8)))
	stroke(chip, C.yellow, 1.5, 0.6)
	pad(chip, px(0.6, 4), px(1.4, 10))
	list(chip, Enum.FillDirection.Horizontal, px(1.2, 8))
	text(chip, s == 5 and "STEP 2/5" or "STEP 5/5", "title", px(1.4, 11), C.yellow, {LayoutOrder = 1, ZIndex = 7})
	text(chip, OBJ[s] or "", "black", px(2, 15), C.white, {LayoutOrder = 2, ZIndex = 7, TextWrapped = false})
	local count = text(chip, "", "title", px(1.4, 11), C.ink, {LayoutOrder = 3, ZIndex = 7, BackgroundTransparency = 0, BackgroundColor3 = C.green})
	corner(count, UDim.new(0, px(0.5, 4)))
	pad(count, px(0.3, 2), px(0.6, 4))
	local block = make("TextButton", {Name = "Block", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, ZIndex = 4, Visible = false}, cr) -- v1.4
	return {cr = cr, shades = shades, ring = ring, finger = finger, bub = bub, big = big, small = small, count = count, block = block}
end
local function coachPlace(ui, target, bigText, smallText, noTap) -- v1.4: + noTap
	local cr = ui.cr
	local pos, size
	if target and target:IsA("GuiObject") and target.AbsoluteSize.X > 0 then
		local sg = target:FindFirstAncestorWhichIsA("ScreenGui")
		local shown = sg == nil or sg.Enabled
		local q = target
		while shown and q and q ~= sg do
			if q:IsA("GuiObject") and not q.Visible then shown = false end
			q = q.Parent
		end
		-- both screens' AbsolutePosition share one origin: offsets in the coach root are AbsolutePosition - root's
		if shown then pos, size = target.AbsolutePosition - cr.AbsolutePosition, target.AbsoluteSize end
	end
	local CW, CH = cr.AbsoluteSize.X, cr.AbsoluteSize.Y
	if not pos then
		-- nothing to point at (the Lab is still opening): dark everywhere
		ui.shades[1].Position, ui.shades[1].Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(CW, CH)
		for i = 2, 4 do ui.shades[i].Size = UDim2.fromOffset(0, 0) end
		ui.ring.Visible, ui.finger.Visible, ui.bub.Visible = false, false, false
		ui.block.Visible = false
		return
	end
	local m = px(0.5, 4)
	local x0, y0, x1, y1 = pos.X - m, pos.Y - m, pos.X + size.X + m, pos.Y + size.Y + m
	ui.shades[1].Position, ui.shades[1].Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(CW, math.max(0, y0))
	ui.shades[2].Position, ui.shades[2].Size = UDim2.fromOffset(0, y1), UDim2.fromOffset(CW, math.max(0, CH - y1))
	ui.shades[3].Position, ui.shades[3].Size = UDim2.fromOffset(0, y0), UDim2.fromOffset(math.max(0, x0), y1 - y0)
	ui.shades[4].Position, ui.shades[4].Size = UDim2.fromOffset(x1, y0), UDim2.fromOffset(math.max(0, CW - x1), y1 - y0)
	ui.ring.Visible, ui.finger.Visible, ui.bub.Visible = true, not noTap, true
	ui.block.Visible = noTap == true -- v1.4: the hole takes no taps
	ui.block.Position, ui.block.Size = UDim2.fromOffset(x0, y0), UDim2.fromOffset(x1 - x0, y1 - y0)
	ui.ring.Position, ui.ring.Size = UDim2.fromOffset(x0, y0), UDim2.fromOffset(x1 - x0, y1 - y0)
	ui.finger.Position = UDim2.fromOffset(pos.X + size.X * 0.85, pos.Y + size.Y * 0.85)
	ui.big.Text = bigText
	ui.small.Text = smallText or ""
	ui.small.Visible = smallText ~= nil and smallText ~= ""
	local bw, bh = ui.bub.AbsoluteSize.X, ui.bub.AbsoluteSize.Y
	local gap = px(1.2, 8)
	local bx, by
	if x1 + gap + bw <= CW - 6 then
		bx, by = x1 + gap, (y0 + y1) / 2 - bh / 2
	elseif x0 - gap - bw >= 6 then
		bx, by = x0 - gap - bw, (y0 + y1) / 2 - bh / 2
	elseif y0 - gap - bh >= 6 then
		bx, by = (x0 + x1) / 2 - bw / 2, y0 - gap - bh
	else
		bx, by = (x0 + x1) / 2 - bw / 2, y1 + gap
	end
	bx = math.clamp(bx, 6, math.max(6, CW - bw - 6))
	by = math.clamp(by, 6, math.max(6, CH - bh - 6))
	ui.bub.Position = UDim2.fromOffset(bx, by)
end
LC2 = {} -- v1.6: Lab 2.0 coach targets (script-global, so the main chunk gets no new locals)
function LC2.on()
	return script:GetAttribute("TutorialLab2Enabled") ~= false and (tonumber(player:GetAttribute("LabVersion")) or 0) >= 2
end
function LC2.cardBtn(id)
	local card = labFind("Card_" .. id, "GuiButton")
	local acts = card and card:FindFirstChild("Actions")
	local b = acts and acts:FindFirstChild("Btn")
	local t = b and b:FindFirstChild("T")
	return b, t and t:IsA("TextLabel") and t.Text or ""
end
function LC2.equip(dino, n, filled)
	if player:GetAttribute("LabSheet") == true then return labFind("Back", "GuiButton"), "TAP BACK" end
	local ss = tonumber(player:GetAttribute("LabSlotSel")) or 0
	if ss > 0 and slotOf(ss) ~= "" then return labFind("Cancel", "GuiButton"), "TAP CANCEL" end
	local inSlot = {}
	for k = 1, 4 do inSlot[slotOf(k)] = true end
	for _, id in ipairs(partsOf(dino, true)) do
		if not inSlot[id] then
			local b, txt = LC2.cardBtn(id)
			if b and (txt:sub(1, 5) == "EQUIP" or txt:sub(1, 6) == "PUT ON") then
				return b, "TAP " .. txt, ("%d/%d EQUIPPED"):format(filled, n)
			end
		end
	end
	return nil, "TAP A PART"
end
function LC2.spend(dino)
	if player:GetAttribute("LabSheet") == true then return labFind("Back", "GuiButton"), "TAP BACK" end
	for _, id in ipairs(statsOf(dino)) do
		if pathStep(id) < 4 then
			local b, txt = LC2.cardBtn(id)
			if b and (txt:sub(1, 3) == "BUY" or txt:sub(1, 7) == "UPGRADE") then
				return b, txt:sub(1, 3) == "BUY" and "TAP BUY" or "TAP UPGRADE", "-1 PT"
			end
		end
	end
	return nil, "TAP A STAT"
end
local function drawCoach(s)
	coachStop()
	if coach.step ~= s then
		coach.step, coach.picked, coach.flash, coach.sent, coach.prev = s, nil, nil, false, {}
		for k = 1, 4 do coach.prev[k] = slotOf(k) end
	end
	if player:GetAttribute("LabOpen") ~= "compact" then labOpen(true) end
	local ui = coachBuild(s)
	local dino = dinoKey()
	local startPts = tonumber(player:GetAttribute("TutPtsStart")) or 0
	coach.conn = RunService.RenderStepped:Connect(function()
		local open = player:GetAttribute("LabOpen") == "compact"
		local press = player:GetAttribute("LabLastPress")
		local tab = player:GetAttribute("LabTab")
		local sel = player:GetAttribute("LabSelected")
		if type(press) == "string" and press:sub(1, 5) == "card:" then coach.picked = press:sub(6) end
		local target, big, small, noTap
		if s == 5 then
			local n = need()
			local filled = 0
			for k = 1, 4 do
				local v = slotOf(k)
				if v ~= "" and coach.prev[k] ~= v then coach.flash = {k = k, untilT = os.clock() + 1.6} coach.picked = nil end
				coach.prev[k] = v
			end
			for k = 1, n do if slotOf(k) ~= "" then filled += 1 end end
			ui.count.Text = ("%d/%d"):format(math.min(filled, n), n)
			if filled >= n then
				if not open then
					if not coach.sent then coach.sent = true send("next") end
					return
				end
				target, big, small = labFind("Close", "GuiButton"), "CLOSE", ("%d/%d EQUIPPED"):format(n, n)
			elseif coach.flash and os.clock() < coach.flash.untilT then
				local k = coach.flash.k
				target = labFind("Slot_" .. k, "GuiButton")
				noTap = true -- v1.4
				if isTouch() then
					local t = SLOT_TAGS_TOUCH[k]
					big, small = t[1], ("%s \u{00B7} %d/%d EQUIPPED"):format(t[2], filled, n)
				else
					big, small = "KEY " .. SLOT_KEYS_PC[k], ("%d/%d EQUIPPED"):format(filled, n)
				end
			elseif not open then
				if os.clock() > coach.reopenAt then coach.reopenAt = os.clock() + 1 labOpen(true) end
			elseif tab ~= "parts" then
				target, big = labFind("Parts", "GuiButton"), "TAP ABILITIES"
			elseif LC2.on() then -- v1.6: Lab 2.0
				target, big, small = LC2.equip(dino, n, filled)
			else
				local inSlot = {}
				for k = 1, 4 do inSlot[slotOf(k)] = true end
				local want = (coach.picked and not inSlot[coach.picked] and ST.BUTTONS[coach.picked]) and coach.picked or nil
				local ss = tonumber(player:GetAttribute("LabSlotSel")) or 0
				local empty
				for k = 1, n do if slotOf(k) == "" then empty = k break end end
				if want and sel == want and ss > 0 and slotOf(ss) ~= "" and empty then
					-- v1.4: a filled slot is selected, so EQUIP would replace it: equip by tapping the empty slot
					target = labFind("Slot_" .. empty, "GuiButton")
					if isTouch() then
						local t = SLOT_TAGS_TOUCH[empty]
						big, small = "TAP " .. string.split(t[1], " ")[1], t[1]
					else
						big, small = "TAP KEY " .. SLOT_KEYS_PC[empty], ("%d/%d EQUIPPED"):format(filled, n)
					end
				elseif want and sel == want then
					target, big = labActionBtn({"EQUIP"}), "TAP EQUIP"
				else
					for _, id in ipairs(partsOf(dino, true)) do
						if not inSlot[id] and labFind("Card_" .. id, "GuiButton") then want = id break end
					end
					target, big = want and labFind("Card_" .. want, "GuiButton"), "TAP A PART"
				end
			end
		else
			local spent = (tonumber(player:GetAttribute("SkillSpent")) or 0) > startPts
			local left = tonumber(player:GetAttribute("SkillLeft")) or 0
			local replay = player:GetAttribute("TutReplay") == true
			ui.count.Text = spent and "DONE" or (left == 1 and "1 PT" or (left .. " PTS"))
			if spent or (replay and left == 0) then
				if not open then
					if not coach.sent then coach.sent = true send("next") end
					return
				end
				target, big, small = labFind("Close", "GuiButton"), "CLOSE", spent and "STAT +1" or "0 POINTS"
			elseif not open then
				if os.clock() > coach.reopenAt then coach.reopenAt = os.clock() + 1 labOpen(true) end
			elseif tab ~= "stats" then
				target, big = labFind("Stats", "GuiButton"), "TAP STATS"
			elseif LC2.on() then -- v1.6: Lab 2.0
				target, big, small = LC2.spend(dino)
			else
				local statId
				for _, id in ipairs(statsOf(dino)) do
					if pathStep(id) < 4 and labFind("Card_" .. id, "GuiButton") then statId = id break end
				end
				if statId and sel == statId and coach.picked == statId then
					target, big, small = labActionBtn({"BUY", "UPGRADE"}), "TAP BUY", "-1 PT"
				else
					target, big = statId and labFind("Card_" .. statId, "GuiButton"), "TAP A STAT"
				end
			end
		end
		if target then scrollTo(target) end
		coachPlace(ui, target, big or "", small, noTap)
	end)
end

-- ---------- render ----------
local lastSpentId = nil
local fullRetry = false
local shownLessons = {}
local function scenePartsCards(col, add, ids)
	local cols = math.min(5, math.max(3, math.ceil(#ids / 2)))
	local cw, chh, gap = px(15), px(6.6, 50), px(1)
	local rows = math.ceil(#ids / cols)
	local g = add(make("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(cols * cw + (cols - 1) * gap, rows * chh + (rows - 1) * gap)}, col))
	make("UIGridLayout", {CellSize = UDim2.fromOffset(cw, chh), CellPadding = UDim2.fromOffset(gap, gap), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center}, g)
	for i, id in ipairs(ids) do
		local passive = not ST.BUTTONS[id]
		local cg = make("CanvasGroup", {BackgroundColor3 = C.card, LayoutOrder = i, GroupTransparency = 1}, g)
		corner(cg, UDim.new(0, px(1.2, 8)))
		stroke(cg, passive and Color3.fromRGB(107, 122, 148) or C.orange, px(0.22, 2))
		pad(cg, 0, px(1, 8))
		list(cg, nil, px(0.2, 2), Enum.HorizontalAlignment.Left)
		-- v1.1 phone check: long names shrink to the card (were cut: "Goo Blob Shoote"); the star line stays Gotham (Silkscreen has no star)
		local nm = text(cg, pname(id), "black", px(1.5, 13), C.white, {LayoutOrder = 1, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.new(1, 0, 0, px(3.2, 24)), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left})
		make("UITextSizeConstraint", {MaxTextSize = px(1.5, 13), MinTextSize = 9}, nm)
		local unl = player:GetAttribute("SkillUnlockOnly") == true and script:GetAttribute("TutUnlockCopyEnabled") ~= false -- v1.10
		text(cg, passive and "PASSIVE ★" or (unl and "UNLOCKED" or "MAXED ★"), "black", px(1.2, 11), passive and C.muted or C.yellow, {LayoutOrder = 2})
		task.delay(0.06 * i, function() if cg.Parent then tween(cg, 0.3, {GroupTransparency = 0}) end end)
	end
end

function render()
	local s = step()
	if s == 1 or s == 2 then -- v1.2: the incubator keeps its scene while nothing it shows changed
		if incubatorOn() then
			measure()
			if pod.sceneKey ~= nil and pod.sceneKey == incubatorKey(s) and #root:GetChildren() > 0 then return end
		end
	end
	if (s == 5 or s == 8) and coachOn() and coach.conn ~= nil and coach.step == s then return end -- v1.3: the coach keeps running
	podStop()
	pod.sceneKey = nil
	coachStop() -- v1.3
	root:ClearAllChildren()
	gui.Enabled = s > 0
	player:SetAttribute("TutClientStep", s)
	updateMark()
	hideOthers(false)
	if s <= 0 then return end
	measure()
	local dino = dinoKey()
	local replay = player:GetAttribute("TutReplay") == true
	local unlockText = ReplicatedStorage:GetAttribute("TutUnlockTextOn") == true
	local lessons = R.lessonsFor(dino)
	if (s == 1 or s == 2) and incubatorOn() then -- v1.2
		pod.sceneKey = incubatorKey(s)
		local rolled = player:GetAttribute("TutRolled") or ""
		if rolled ~= "" and s == 2 then
			drawReveal(rolled, not pod.revealed)
		elseif pod.phase == "open" then
			drawWait()
		elseif s == 1 and showcaseOn() and not pod.showcased then -- v1.4
			if welcomeOn() and not WM.welcomed then drawWelcome() -- v1.7
			elseif showcase2On() then drawShowcase2() else drawShowcase() end -- v1.5
		else
			drawCharge()
		end
	elseif s == 1 or (s == 2 and ((player:GetAttribute("TutRolled") or "") == "" or egg.hatching and egg.rollLoop)) then
		drawEgg()
	elseif s == 2 then
		local rolled = player:GetAttribute("TutRolled")
		local rl = R.lessonsFor(rolled)
		backdrop()
		local col, add = sceneColumn("IT HATCHED", nil, nil)
		local row = add(make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY}, col)) -- v1.1: grows to its content
		list(row, Enum.FillDirection.Horizontal, px(3))
		local pf = portrait(row, rolled, px(17, 120))
		pf.LayoutOrder = 1
		local facts = make("Frame", {BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), LayoutOrder = 2}, row)
		list(facts, nil, px(0.5, 4), Enum.HorizontalAlignment.Left)
		local chip = text(facts, " " .. (R.ROLE[rolled] or "FIGHTER") .. " ", "title", px(1.4, 12), C.ink, {BackgroundTransparency = 0,
			BackgroundColor3 = C.cyan, LayoutOrder = 1})
		corner(chip, UDim.new(0, 4))
		text(facts, string.upper(dinoName(rolled)), "title", px(4.4, 30), C.white, {LayoutOrder = 2})
		text(facts, "MAIN ATTACK", "title", px(1.4, 12), C.yellow, {LayoutOrder = 3})
		for i, L in ipairs(rl) do
			text(facts, L.n, "black", px(1.7, 15), C.white, {LayoutOrder = 3 + i * 2})
			text(facts, howLine(L), "body", px(1.35, 13), C.muted, {LayoutOrder = 4 + i * 2, Size = UDim2.fromOffset(px(30), 0),
				AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left})
		end
		if unlockText then add(text(col, "More dinos unlock with skill points.", "body", px(1.5, 14), C.muted)) end
		add(cta(col, "NEXT", function() send("next") end))
		flash()
	elseif s == 3 then
		backdrop()
		local free = player:GetAttribute("FreeDino")
		local key = (type(free) == "string" and free ~= "") and free or dino
		local ids = partsOf(key, false, true) -- v1.1: the body is still the old dino here, so its parts are not published yet
		local col, add = sceneColumn(string.upper(dinoName(key)) .. "'S GEAR", #ids .. " MECHA PARTS", (player:GetAttribute("SkillUnlockOnly") == true and script:GetAttribute("TutUnlockCopyEnabled") ~= false) and "All unlocked. They're yours." or "All maxed. They're yours.") -- v1.10
		scenePartsCards(col, add, ids)
		if player:GetAttribute("TutLastResult") == "full" then add(text(col, "Training is full. Trying again.", "body", px(1.5, 14), C.orange)) end
		add(cta(col, "START TRAINING", function() send("next") fullRetry = true end))
	elseif s == 4 then
		local cur = tonumber(player:GetAttribute("TutLesson")) or 1
		local done = R.parseDone(player:GetAttribute("TutLessonsDone"))
		local rows = {}
		for i, L in ipairs(lessons) do rows[i] = {n = L.n, done = done[i], cur = i == cur} end
		local all = player:GetAttribute("TutHit") == true
		local L = lessons[cur]
		objective(4, all and "Nice. That's your attack." or (L and L.line), rows)
		for i, L2 in ipairs(lessons) do
			if done[i] and not shownLessons[i] then shownLessons[i] = true toast("✓ " .. L2.n) end
		end
		if not all and L then
			if isTouch() then
				hideOthers(true)
				pointAt(attackButton(), true, L.how, howWords(L), L.n, "left")
			else
				pcCallout(howWords(L), L.n)
			end
		end
	elseif (s == 5 or s == 8) and coachOn() then -- v1.3: the real Lab
		drawCoach(s)
	elseif s == 5 then
		local n = need()
		local filled = 0
		for k = 1, n do if slotOf(k) ~= "" then filled += 1 end end
		objective(5, filled >= n and "Ready. Try them on the bot."
			or (isTouch() and "Each button holds 2 parts. Tap for the top one, pull down for the bottom one." or "Pick a part for each key."))
		local f, inner = sheet()
		local left = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(0, px(30, 200), 1, 0)}, inner)
		list(left, nil, px(0.8, 6), Enum.HorizontalAlignment.Left).VerticalAlignment = Enum.VerticalAlignment.Top
		header(left, isTouch() and "YOUR 2 BUTTONS" or "YOUR KEYS", 0)
		local map = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -px(3, 20)), LayoutOrder = 1}, left)
		list(map, Enum.FillDirection.Horizontal, px(1.6, 10)).VerticalAlignment = Enum.VerticalAlignment.Top
		local nextEmpty
		for k = 1, n do if slotOf(k) == "" then nextEmpty = k break end end
		local function socket(parent, k, lab, h, order)
			local id = slotOf(k)
			local b = make("TextButton", {Text = "", AutoButtonColor = id ~= "", BackgroundColor3 = k == nextEmpty and Color3.fromRGB(58, 48, 18) or C.card,
				Size = UDim2.new(1, 0, 0, h), LayoutOrder = order}, parent)
			if k == nextEmpty then stroke(b, C.yellow, px(0.25, 2)) end
			list(b, nil, px(0.2, 2))
			text(b, id ~= "" and pname(id) or "EMPTY", "black", px(1.35, 12), id ~= "" and C.white or C.muted, {LayoutOrder = 1,
				Size = UDim2.new(1, -px(1, 8), 0, 0), AutomaticSize = Enum.AutomaticSize.Y})
			if lab then text(b, lab, "black", px(1.2, 11), C.orange, {LayoutOrder = 2}) end
			b.Activated:Connect(function() if id ~= "" and skillRemote then skillRemote:FireServer("slot", k, "") end end)
		end
		if isTouch() then
			for bnum = 1, 2 do
				local bb = make("Frame", {BackgroundColor3 = Color3.fromRGB(18, 26, 38), Size = UDim2.new(0.5, -px(0.8, 5), 1, 0), LayoutOrder = bnum}, map)
				corner(bb, UDim.new(0, px(1.6, 10)))
				stroke(bb, C.white, 2, 0.75)
				list(bb, nil, 0).VerticalAlignment = Enum.VerticalAlignment.Top
				text(bb, "BUTTON " .. bnum, "title", px(1.3, 11), C.muted, {LayoutOrder = 0, Size = UDim2.new(1, 0, 0, px(2.6, 18)), AutomaticSize = Enum.AutomaticSize.None})
				local hh = (bb.AbsoluteSize.Y > 0 and bb.AbsoluteSize.Y or px(24)) - px(2.6, 18)
				socket(bb, bnum, "TAP", math.max(hh / 2, px(7, 44)), 1)
				socket(bb, bnum + 2, "PULL ▼", math.max(hh / 2, px(7, 44)), 2)
			end
		else
			local grid = make("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), LayoutOrder = 1}, map)
			make("UIGridLayout", {CellSize = UDim2.new(0.5, -px(0.5, 4), 0.5, -px(0.5, 4)), CellPadding = UDim2.fromOffset(px(0.8, 6), px(0.8, 6)),
				SortOrder = Enum.SortOrder.LayoutOrder}, grid)
			for k = 1, 4 do
				local cell = make("Frame", {BackgroundTransparency = 1, LayoutOrder = k}, grid)
				corner(cell, UDim.new(0, px(1, 8)))
				socket(cell, k, "KEY " .. SLOT_KEYS[k], px(8, 50), 1)
			end
		end
		local right = make("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(px(32, 210), 0), Size = UDim2.new(1, -px(32, 210), 1, 0)}, inner)
		header(right, ("TAP A PART  %d/%d"):format(filled, n), 0)
		local sc = make("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, px(2.6, 18)),
			Size = UDim2.new(1, 0, 1, -px(2.6, 18)), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = px(0.5, 4), ScrollingDirection = Enum.ScrollingDirection.Y}, right)
		make("UIGridLayout", {CellSize = UDim2.new(1 / 3, -px(0.7, 5), 0, px(5.6, 44)), CellPadding = UDim2.fromOffset(px(0.9, 6), px(0.9, 6)),
			SortOrder = Enum.SortOrder.LayoutOrder}, sc)
		local inSlot = {}
		for k = 1, 4 do inSlot[slotOf(k)] = true end
		local firstFree = true
		for i, id in ipairs(partsOf(dino, true)) do
			local used = inSlot[id]
			local b = make("TextButton", {Text = "", AutoButtonColor = not used, BackgroundColor3 = C.card, LayoutOrder = i}, sc)
			corner(b, UDim.new(0, px(1, 8)))
			local glow = not used and firstFree and nextEmpty ~= nil
			if not used then firstFree = false end
			stroke(b, used and C.line or C.orange, glow and px(0.4, 3) or px(0.22, 2))
			text(b, pname(id), "black", px(1.35, 12), used and C.muted or C.white, {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, px(1, 8), 0.5, 0),
				Size = UDim2.new(1, -px(4, 28), 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left})
			text(b, "★", "black", px(1.4, 13), used and C.muted or C.yellow, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -px(1, 8), 0.5, 0)})
			b.Activated:Connect(function()
				if used or not skillRemote or not nextEmpty then return end
				skillRemote:FireServer("slot", nextEmpty, id)
			end)
		end
		if filled >= n then
			cta(root, n == 0 and "NEXT" or "TRY THEM", function() send("next") end, {AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -px(6, 24), 1, -f.Size.Y.Offset + px(2) - px(1.2, 8))})
		end
	elseif s == 6 then
		local used, n = usedSet(), need()
		local nextI
		for i = 1, n do if not used[i] then nextI = i break end end
		local tip
		if not nextI then tip = n == 4 and "All 4 done." or "All done."
		elseif not isTouch() then tip = "Each part is on its own key."
		elseif nextI > 2 then tip = (used[3] or used[4]) and "Pull down again." or "Each button has a 2nd part. Press and drag down."
		else tip = "Tap a button to use its part." end
		local J = nextI and script:GetAttribute("TutorialJumpPartsEnabled") ~= false and R.jumpPart(slotOf(nextI)) or nil -- v1.7
		local skipNow = false
		if J then
			local key = nextI .. ":" .. slotOf(nextI)
			if WM.jpN ~= key then WM.jpN, WM.jpSince = key, os.clock() end
			local after = math.max(0, tonumber(script:GetAttribute("TutJumpPartSkipAfter")) or 20)
			local waited, tapAgo = os.clock() - WM.jpSince, os.clock() - WM.jpTapAt
			skipNow = waited >= after
			tip = tapAgo < 2 and ("That button does nothing for " .. J.small .. ". It works on JUMP.") or J.tip
			if skipNow then tip ..= " Or tap SKIP." end
			WM.jpTok += 1
			local tok = WM.jpTok
			local wake = math.min(skipNow and math.huge or after - waited, tapAgo < 2 and 2 - tapAgo or math.huge)
			if wake < math.huge then task.delay(wake + 0.05, function() if WM.jpTok == tok and step() == 6 then render() end end) end
		else
			WM.jpN = nil
		end
		local obj = objective(6, tip)
		if J and skipNow then
			local k = nextI
			local sk = cta(obj:FindFirstChild("Body") or obj, "SKIP", function() if WM.markUsed then WM.markUsed(k) end end, {LayoutOrder = 6})
			sk.Name = "SkipPart"
		end
		for i = 1, 4 do
			if used[i] and not shownLessons["u" .. i] then shownLessons["u" .. i] = true toast("✓ " .. pname(slotOf(i))) end
		end
		if nextI then
			local part = pname(slotOf(nextI))
			if J then -- v1.7: a JUMP part: the JUMP button and the real input
				local at = player.PlayerGui:FindFirstChild("ArenaTouch")
				local leap = at and at:FindFirstChild("Leap", true)
				if isTouch() and leap and leap:IsA("GuiObject") and leap.Visible then
					pointAt(leap, true, string.find(J.big, "HOLD") and "hold" or "tap", J.big, J.small, "left")
				else
					pcCallout(isTouch() and J.big or J.pcBig, J.small)
				end
			elseif isTouch() then
				local pull = nextI > 2
				pointAt(slotButton(pull and nextI - 2 or nextI), false, pull and "pull" or "tap", pull and "PULL DOWN ▼" or "TAP", part, "up")
			else
				pcCallout("PRESS " .. SLOT_KEYS[nextI], part)
			end
		end
	elseif s == 7 then
		if player:GetAttribute("TutKilled") == true then
			backdrop()
			if replay then
				local col, add = sceneColumn("TRAINING", "BOT DOWN", "No XP in a replay.")
				add(cta(col, "NEXT", function() send("next") end))
			else
				local col, add = sceneColumn("LEVEL UP", nil, nil)
				add(text(col, tostring(player:GetAttribute("SkillLevel") or 2), "title", px(14, 96), C.yellow))
				add(text(col, "+1 skill point", "body", px(1.9, 17), C.text))
				add(cta(col, "SPEND IT", function() send("next") end))
			end
			flash()
		else
			objective(7, "Finish it. Use anything.")
			if isTouch() then pointAt(attackButton(), true, nil, nil, nil) end
		end
	elseif s == 8 then
		local left = tonumber(player:GetAttribute("SkillLeft")) or 0
		local spentNow = (tonumber(player:GetAttribute("SkillSpent")) or 0) > (tonumber(player:GetAttribute("TutPtsStart")) or 0)
		objective(8, spentNow and ((lastSpentId and pname(lastSpentId) or "Your stat") .. " went up.")
			or (replay and left == 0) and "No points to spend." or "Tap + on a stat.")
		local f, inner = sheet()
		local box = make("Frame", {BackgroundColor3 = C.card, Size = UDim2.new(0, px(16, 110), 1, 0)}, inner)
		corner(box, UDim.new(0, px(1.4, 10)))
		list(box, nil, px(0.4, 3))
		text(box, tostring(left), "title", px(7, 48), C.yellow, {LayoutOrder = 1})
		text(box, left == 1 and "SKILL POINT" or "SKILL POINTS", "black", px(1.3, 12), C.white, {LayoutOrder = 2})
		text(box, "1 every level", "body", px(1.1, 11), C.muted, {LayoutOrder = 3})
		local right = make("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(px(18, 124), 0), Size = UDim2.new(1, -px(18, 124), 1, 0)}, inner)
		header(right, string.upper(dinoName(dino)) .. " STATS", 0)
		local sc = make("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, px(2.6, 18)),
			Size = UDim2.new(1, 0, 1, -px(2.6, 18)), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = px(0.5, 4), ScrollingDirection = Enum.ScrollingDirection.Y}, right)
		make("UIGridLayout", {CellSize = UDim2.new(0.5, -px(0.6, 4), 0, px(5.6, 44)), CellPadding = UDim2.fromOffset(px(0.9, 6), px(0.9, 6)),
			SortOrder = Enum.SortOrder.LayoutOrder}, sc)
		for i, id in ipairs(statsOf(dino)) do
			local n = pathStep(id)
			local r = make("Frame", {BackgroundColor3 = C.card, LayoutOrder = i}, sc)
			corner(r, UDim.new(0, px(1, 8)))
			stroke(r, C.line, 2)
			text(r, pname(id), "black", px(1.35, 12), C.white, {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, px(1.2, 8), 0.5, 0),
				Size = UDim2.new(0.6, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left})
			text(r, n > 0 and ({"I", "II", "III", "★"})[n] or "-", "black", px(1.5, 13), n > 0 and C.green or C.muted,
				{AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -px(6.4, 48), 0.5, 0)})
			if n < 4 and left > 0 and not spentNow then
				local b = make("TextButton", {Text = "+", Font = Enum.Font.GothamBlack, TextSize = px(2.2, 20), TextColor3 = C.ink,
					BackgroundColor3 = C.yellow, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -px(0.6, 4), 0.5, 0),
					Size = UDim2.fromOffset(px(4.6, 40), px(4.2, 36)), Modal = true}, r)
				b:SetAttribute("FontSwap", "keep")
				corner(b, UDim.new(0, px(0.9, 6)))
				if i == 1 then tween(b, 0.5, {BackgroundColor3 = C.white}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true) end
				b.Activated:Connect(function()
					lastSpentId = id
					if skillRemote then skillRemote:FireServer("buy", id) end
				end)
			end
		end
		if spentNow or (replay and left == 0) then
			cta(root, "NEXT", function() send("next") end, {AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -px(6, 24), 1, -f.Size.Y.Offset + px(2) - px(1.2, 8))})
		end
	elseif s == 9 then
		backdrop()
		local col, add = sceneColumn("HOW YOU GET STRONGER", "SKILL POINTS", "1 every level. Kills give XP.")
		local row = add(make("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(px(60), px(11, 90))}, col))
		list(row, Enum.FillDirection.Horizontal, px(1.4, 10))
		local tiles = {{"+HP", "STATS", "Health, attack, armor, speed."}, {"I → ★", "PARTS", "Every part goes from I to ★."},
			{"NEW", "NEW DINOS", unlockText and "Points from any dino count." or "Coming soon."}}
		for i, t in ipairs(tiles) do
			local tf = make("Frame", {BackgroundColor3 = C.card, Size = UDim2.new(1 / 3, -px(1, 7), 1, 0), LayoutOrder = i}, row)
			corner(tf, UDim.new(0, px(1.4, 10)))
			stroke(tf, C.line, 2)
			pad(tf, px(1.2, 8))
			list(tf, nil, px(0.3, 2), Enum.HorizontalAlignment.Left).VerticalAlignment = Enum.VerticalAlignment.Top
			text(tf, t[1], "black", px(2.4, 18), C.yellow, {LayoutOrder = 1})
			text(tf, t[2], "black", px(1.5, 14), C.white, {LayoutOrder = 2})
			text(tf, t[3], "body", px(1.25, 12), C.muted, {LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				TextXAlignment = Enum.TextXAlignment.Left})
		end
		add(cta(col, "GOT IT", function() send("next") end))
	elseif s == 10 then
		backdrop()
		local k = 0
		for i = 1, 4 do if slotOf(i) ~= "" then k += 1 end end
		if script:GetAttribute("TutFirstMatchEnabled") ~= false then -- v1.8: the first match
			local col, add = sceneColumn("TRAINING COMPLETE", "LEVEL " .. tostring(player:GetAttribute("SkillLevel") or 1) .. " " .. string.upper(dinoName(dino)),
				"Next: a real 4v4 match. Bots fill empty seats.")
			add(cta(col, "PLAY YOUR FIRST MATCH", function() player:SetAttribute("FsAutoQueue", true) send("island") end))
			local ex = cta(col, "EXPLORE THE ISLAND FIRST", function() player:SetAttribute("FsAutoQueue", nil) send("island") end,
				{BackgroundTransparency = 1, TextColor3 = C.muted})
			for _, c in ipairs(ex:GetChildren()) do if c:IsA("UIStroke") then c:Destroy() end end
			add(ex)
		else
		local col, add = sceneColumn("TRAINING COMPLETE", "LEVEL " .. tostring(player:GetAttribute("SkillLevel") or 1) .. " " .. string.upper(dinoName(dino)),
			k .. " parts equipped")
		add(cta(col, "GO TO THE ISLAND", function() send("island") end))
		end
	end
end

-- ---------- triggers ----------
local queued = false
local function queue()
	if queued then return end
	queued = true
	task.defer(function()
		queued = false
		render()
	end)
end
local WATCH = {TutStep = true, TutRolled = true, TutHit = true, TutUsed = true, TutKilled = true, TutNeed = true, TutLane = true,
	TutReplay = true, TutLastResult = true, TutLesson = true, TutLessonsDone = true, SkillSpent = true, SkillLeft = true,
	SkillLevel = true, FreeDino = true, SkillSlot1 = true, SkillSlot2 = true, SkillSlot3 = true, SkillSlot4 = true}
player.AttributeChanged:Connect(function(name)
	if name == "TutStep" then
		local s = step()
		if s ~= 8 then lastSpentId = nil end
		if s <= 1 then egg.taps, egg.hatching = 0, false end
		if s == 0 or s >= 3 then podReset() end -- v1.2
		if coach.step ~= 0 and s ~= coach.step then -- v1.3: leaving a Lab step
			if player:GetAttribute("LabOpen") == "compact" then labOpen(false) end
			coach.step = 0
		end
		if s ~= 4 and s ~= 6 then shownLessons = {} end
	end
	if WATCH[name] or (step() == 5 and name:sub(1, 10) == "SkillPath_") then queue() end
end)
ReplicatedStorage:GetAttributeChangedSignal("TutUnlockTextOn"):Connect(queue)
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(queue)

-- step 6: each part used (MechaButtonsLastPress lives on the character, written by MechaButtons on this client)
local localUsed = {}
WM.markUsed = function(n) localUsed[n] = true send("used", n) end -- v1.7: SKIP on a JUMP part
local charConn
local function onChar(c)
	if charConn then charConn:Disconnect() end
	charConn = c:GetAttributeChangedSignal("MechaButtonsLastPress"):Connect(function()
		if step() ~= 6 then return end
		local n, id = string.match(c:GetAttribute("MechaButtonsLastPress") or "", "^slot(%d):(.+)$")
		n = tonumber(n)
		if n and n <= need() and id ~= "empty" then
			if script:GetAttribute("TutorialJumpPartsEnabled") ~= false and R.jumpPart(id) then -- v1.7: that button does nothing
				WM.jpTapAt = os.clock()
				queue()
				return
			end
			localUsed[n] = true
			send("used", n)
		end
	end)
	c.AttributeChanged:Connect(function(name) -- v1.7: a JUMP part counts when its move really happens (TutorialRules 1.3)
		if step() ~= 6 or script:GetAttribute("TutorialJumpPartsEnabled") == false then return end
		for k = 1, math.min(4, need()) do
			local J = R.jumpPart(slotOf(k))
			if J and not localUsed[k] and R.jumpPartEvent(J, name, J.needAttr and c:GetAttribute(J.needAttr) or nil) then
				localUsed[k] = true
				send("used", k)
			end
		end
	end)
	c:GetAttributeChangedSignal("Species"):Connect(queue)
	queue()
end
player.CharacterAdded:Connect(onChar)
if player.Character then onChar(player.Character) end

-- the bot marks, the "full" retry, re-sending used parts, keeping the phone's other buttons hidden in step 4
task.spawn(function()
	local lastRetry, lastUsed = 0, 0
	while true do
		task.wait(0.2)
		local s = step()
		if s > 0 then updateMark() end
		if s == 3 and fullRetry and player:GetAttribute("TutLastResult") == "full" and os.clock() - lastRetry > 3 then
			lastRetry = os.clock()
			send("next")
		end
		if s ~= 3 then fullRetry = false end
		if s == 6 and os.clock() - lastUsed > 0.5 then
			lastUsed = os.clock()
			local have = usedSet()
			for n in pairs(localUsed) do if not have[n] then send("used", n) end end
		elseif s ~= 6 then
			localUsed = {}
		end
		if s == 4 and player:GetAttribute("TutHit") ~= true then hideOthers(true) end
	end
end)
render()
