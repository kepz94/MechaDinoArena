-- HardpointHUD v1.1 (Mecha Dino Arena) — the Arena Hardpoint HUD, PC and phone (LocalScript, StarterPlayerScripts). MDA-402,
-- plan docs/plans/HARDPOINT_v1.0.md Task 7, mockups docs/mockups/arena_hardpoint_v0.1.html (Kepu 2026-11-10: the HUD "Look at how
-- Call of Duty Mobile does it") + hardpoint_point_look_v0.1.html (the marker and name tags).
-- Reads ReplicatedStorage.Hardpoint (HardpointServer 1.0) and the player attribute HardpointTeam; draws only while HpLive, the
--   player is out of the menu (InMenu ~= true) and HpPhase is warmup / live / results.
-- ScreenGui "HardpointHUD" (DisplayOrder 6, ScreenInsets DeviceSafeInsets, ResetOnSpawn false), FredokaOne, the HUD panel look
--   (rgb(20,20,26) at 0.18, white stroke 0.5 / 1.5 px, corner 10). Your team is always blue rgb(90,160,255), the enemy red
--   rgb(224,40,74) (Call of Duty).
--   * Score card, top left under Roblox's top bar: AnchorPoint (0, 0) at (0, 16, 0, 58), width clamp(26% of the screen, 220,
--     330), 58 tall: team emblem (blue), your score row (blue bar + number) over the enemy row (red), and on the right the
--     match clock m:ss ("II" while paused, the point is held) and "P{n} · m:ss" (yellow).
--   * Status line 6 px under the card: GET READY / POINT OPEN / SECURED · +1 / s / ENEMY HAS THE POINT / CONTESTED.
--   * Next notice under it while HpShowNext: "NEXT: P{n} {NAME} IN m:ss".
--   * Marker: projected every frame from the point centre + 34 studs: label (CAPTURE / DEFEND / CONTESTED, LOCKED m:ss in the
--     warmup), a diamond with the point number, and the distance ("ON POINT" when you count); clamped to the screen edge
--     (smaller) when off screen or behind the camera.
--   * Name tags: a BillboardGui over every other counted player (team set, out of the menu, alive), own team blue, enemy red.
--   * Results: a centre panel VICTORY / DEFEAT / DRAW, "you – them" and "NEXT MATCH IN m:ss".
-- Switch: script attribute HardpointHUDEnabled (default true). Diagnostics: HardpointHUDVersion, HardpointHUDState.
-- v1.1 (MDA-402, found in Play 2026-11-10), three marker fixes under one switch, script attribute HardpointHUDMarkerFix
--   (default true; false = 1.0):
--   * position: 1.0 placed the marker GuiInset (58 px) too low (WorldToViewportPoint is screen pixels; this ScreenGui's
--     AbsolutePosition is (0, -58)); now the inset is taken off;
--   * a point behind the camera: 1.0 put the marker at 85% of the screen height, on the ability bar; now it goes to the
--     side edge (left or right, the side the point is on) at half height;
--   * the top limit stays where 1.0 showed it (150 px under the top bar), and a marker in the left column (on screen or
--     clamped to the edge) is pushed below the status / next pills (6 px gap) instead of covering them or the score card.
-- v1.2 (practice match, MDA-414, plan docs/plans/PRACTICE_MATCH_v1.0.md Task 10, mockup docs/mockups/practice_match_v0.1.html
--   end screen; Kepu 2026-11-10 "Build"): the results panel becomes a scoreboard (Arena and practice). Panel "Board" in the
--   middle, designed 720 x 316 and scaled by a UIScale = min(1.2, 94% of the width / 720, 86% of the height / 316):
--   VICTORY / DEFEAT / DRAW (40), a line "PRACTICE · <DIFFICULTY> BOTS" (ReplicatedStorage.Practice exists) or "HARDPOINT",
--   two tables side by side from HpBoard (HardpointServer 1.1): your team on the left "BLUE · <score>", the other "RED ·
--   <score>" (no team of yours: A left); columns name (★ you, BOT tag), dino, K, D, on point (m:ss); most kills first, at most
--   6 rows each; your row yellow. Under them "TEAM SCREEN IN m:ss" (practice) / "NEXT MATCH IN m:ss" (HpResultsEndAt), PLAY
--   AGAIN (yellow; closes the board until the next results: the Arena's next match / practice's team screen come by
--   themselves when the results end) and MAIN MENU (DinoModeRequest "menu").
--   Switch: script attribute HardpointHUDBoardEnabled (default true, read at start; false = 1.1's small results panel).
--   Diagnostics: HardpointHUDBoard ("shown" / "dismissed" / "hidden"), HardpointHUDBoardPress ("again" / "menu").
--   Also in 1.2 (QA 2026-11-10: the CONTESTED marker sat on the kill feed): a marker in the left column is pushed below the
--   kill feed's lines too (PlayerGui.KillFeed.Lines, KillFeed 1.0) while they show. Switch: script attribute
--   HardpointHUDMarkerFeedGap (default true, read per frame; false = only below the pills, as 1.1).
-- v1.3 (Team Tags, MDA-418, plan docs/plans/TEAM_TAGS_v1.0.md Task 3; Kepu 2026-11-10 "Both, Arena too"): the 1.0 name tags
--   over players step aside while TeamTags 1.0 is on (the sibling LocalScript "TeamTags" has TeamTagsState "on"), so a
--   player never has both. Switch: script attribute HardpointHUDTagsYieldEnabled (default true, read every 0.5 s; false =
--   1.2: tags always). Diagnostic: HardpointHUDTagsYielding (true / false).
-- v1.4 (marker v2, MDA-423, plan docs/plans/HARDPOINT_SPAWNS_MARKER_v1.0.md Task 3; Kepu 2026-11-10 "the point indicator when
--   it transitions doesn't really accurately show me where the next one is, it's pretty glitchy"; 23:39 "just go with the
--   compass bar forget the arrow"): a compass strip, Frame "Compass" in this ScreenGui.
--   * Place: in the score card's row (y 58, 26 px tall; phone 22) centred in the space right of the card (from the card's
--     right + 12 to the screen's right − 16), 30% of the screen wide (phone 34%), 180 to 420 px; if that space is narrower
--     than 180 px, at the top centre (y 10). Shows ±90° round where the camera faces (flat).
--   * World ticks every 15° that slide as you turn; N / E / S / W letters (north = −Z); a notch at the centre.
--   * Current point (warm-up: point 1): solid diamond with its number, in the point colour (blue you hold, red they hold,
--     yellow contested (blinks), white open, grey locked) and the distance in studs under it. Next point (HpShowNext, last
--     10 s): hollow grey diamond with its number and the countdown ("0:07").
--   * A point outside ±90° sits at the strip's end with ◀ / ▶ on the side it really is; beyond ±170° it keeps the side it
--     had (hysteresis), so it never flips across behind you. Icons glide to their spot (rate 14 / s); when HpIndex changes,
--     the current icon starts from where the NEXT icon was.
--   * The 3D marker over the point shows only while the point is on screen (no edge placement).
--   Phone = UserInputService.TouchEnabled or the character's ArenaTouchState == "on" (the ArenaTouchForceTouch hook).
--   Switch: script attribute HardpointHUDCompassEnabled (default true, read at start; false = 1.3 marker, no compass).
--   Diagnostics: HardpointHUDCompass ("" / "cur:<rel>° next:<rel>°"), HardpointHUDCompassPlace ("row" / "top").
-- v1.5 (MDA-423, found in the QA run 2026-11-11 on a 439 px wide window): the strip's row space now ends 96 px from the right
--   (the CLASSIC camera button sits there) and needs 140 px (1.4: 16 px, 180); when there is no room it goes under the pills in
--   the left column (x 16, the score card's width, 6 px under the lowest visible of Status / Next; place "column") instead
--   of the top centre, where it covered SKILLS / MENU. KillFeed 1.1 keeps its lines under it.
-- v1.6 (MDA-427, plan docs/plans/HUD_SLIM_SPAWNS_FAR_v1.0.md Task 3, mockup docs/mockups/hud_slim_compass_v0.1.html; Kepu
--   2026-11-11 "fix the compass on mobile. theres so much space in the top middle of the screen between the roblox settings and
--   the skills button. make it more transparent and fit in that space. also make the point and score board smaller"; picks
--   "A · See-through panel", "Smaller, 80%"):
--   * Compass in the top gap: left = the right edge of the Roblox top-left buttons (GuiService.TopbarInset.Min.X, in this
--     gui's frame) + 12, at least 16; right = the SKILLS button's left (PlayerGui.LabButton.Skills) − 12, else the MENU pill's
--     (PlayerGui.ArenaStatus Pill) − 12, else the screen's right − 16; also never past TopbarInset.Max.X − 12. Width =
--     min(the 1.4 width, the gap), centred on the screen, then kept inside the gap; top = the SKILLS (or MENU) top, else 8.
--     Read every frame. A gap under 140 px -> the 1.5 placement. Place diag "top".
--     Switch: script attribute HardpointHUDCompassTopEnabled (default true, read per frame; false = 1.5 placement).
--   * Look A: panel BackgroundTransparency = attribute HardpointHUDCompassBgT (default 0.65; 1.4: 0.25), outline
--     transparency = HardpointHUDCompassStrokeT (default 0.85; 1.4: 0.75). Read per frame.
--   * Slim HUD: a UIScale "HardpointHUDSlim" on ScoreCard, Status and Next = attribute HardpointHUDScale (default 0.8, kept in
--     0.5 .. 1.2; 1 = the 1.5 size); the card keeps its top-left at (16, 58); Status top = 58 + 58 s + 6 s, Next top = Status
--     top + 30 s; the 1.5 column fallback puts the compass 6 s under the lowest visible pill. Read per frame. The kill feed and
--     the 3D marker place themselves from real on-screen sizes, so they follow.
-- v1.7 (point marker v3, MDA-433, plan docs/plans/POINT_MARKER_v3.md, mockup docs/mockups/point_marker_v0.2.html; Kepu
--   2026-11-11 "fix the actual hard point icon how it interacts with the screen ... Look at how cod does it", pick "A · Rides
--   the edge"). The marker ("Marker": label, diamond with the number, distance) is placed by these rules instead of 1.1–1.6's:
--   * anchor = point centre + HardpointHUDMarkerLift (6) studs; the diamond's centre sits on it (AnchorPoint 0.5, 0.5).
--   * safe frame (screen px): this gui's safe area minus HardpointHUDMarkerEdge (28) left / right; top = the Roblox top bar's
--     bottom (TopbarInset.Max.Y) + 8; bottom = safe bottom − HardpointHUDMarkerBottomPhone (110) on a phone / BottomPC (60).
--   * in view (in front and inside the frame): placed exactly on the anchor (glued, no easing once there), full marker.
--   * off view: the screen direction to the anchor pushed onto the frame's edge; behind the camera the direction is (its
--     sideways offset, its distance behind) so it slides along the bottom edge and goes round smoothly (QA 2026-11-11: a left
--     / right switch crossed the middle of the screen). Diamond + distance only (no label), UIScale 0.84.
--   * moving between in view and off view blends over HardpointHUDMarkerBlend (0.15) s from where it was to the live spot,
--     then it is exactly on the spot (QA 2026-11-11: an easing glide lagged 60–100 px behind while turning).
--   * opacity: within HardpointHUDMarkerFade (70) px of the screen centre it goes down to 35%; while you're on the point (not
--     in the warm-up) it fades out (10 / s).
--   * ZIndex 0, so the score card, pills and kill feed draw over it. No height limit, no left-column push.
--   Switch: script attribute HardpointHUDMarkerV3Enabled (default true, read per frame; false = 1.6 marker).
--   Diagnostic: HardpointHUDMarker ("view" / "edge L" / "edge R" / "edge T" / "edge B" / "on point" / "off").
-- v1.8 (match end, MDA-465, plan docs/plans/MATCH_END_v1.0.md Task 5, mockup docs/mockups/match_end_v0.1.html; Kepu 2026-11-11
--   19:43 "Build with all the recs": B · Three beats, MVP one per team, XP lines, Leader decides). The 15 s results play three
--   beats, timed from the results start (HpResultsEndAt − HardpointRules.RESULTS) plus any skips:
--   * 0–2 s banner: a dim over the screen, VICTORY (yellow) / DEFEAT (pink rgb(255,107,132)) / DRAW (white) at 84, "BLUE you –
--     foe RED" under it, then "HARDPOINT" / "PRACTICE · <DIFFICULTY> BOTS".
--   * 2–6 s spotlight (only when HpAwards (HardpointServer 1.5) names an MVP or SVP; else the board comes at 2 s): one card per
--     award, MVP (gold rgb(255,210,90) pill and outline) then SVP (silver rgb(201,211,224)), 250 × 330 each: the pill, a
--     ViewportFrame with a copy of that player's character (scripts, sounds, billboards removed, parts anchored, camera at 40°
--     fitted to the copy's largest side × 0.62 from the front-right), name, "<dino> · BLUE / RED", "<k> K   <m:ss> ON PT". No living character
--     (or HardpointHUDSpotModelEnabled false) -> the dino's name in the box instead.
--   * 6 s (or 2 s) to the end: the board, grown to 760 × 400: tables 350 wide with an XP column ("+N" green, "—" for bots and
--     players without awards), MVP / SVP tags before the name and the header "ON PT"; an XP strip (your "+N XP" counting up over 2.5 s, the lines
--     Kills / Point / Win (Draw) / MVP / SVP, "<DINO> LV n" with a bar from your level before to after, "n / next", "▲ +n
--     LEVEL(S) · +n SKILL PT"; "NO XP THIS MATCH" without a row); footer: the countdown and a note ("★ LEADER CHOOSES" for a
--     squad member who is not the leader, "★ YOU CHOOSE FOR THE SQUAD" for the leader), PLAY AGAIN (1.2) and BACK TO ISLAND
--     (cyan; DinoModeRequest "island", ModeServer 1.3 takes the squad when the leader presses; its text then follows
--     ModeLastResult: SAVING… / TELEPORTING… / LIVE GAME ONLY / TRY AGAIN). A squad member's buttons are greyed and do
--     nothing. HubOn ~= true -> MAIN MENU instead of BACK TO ISLAND.
--   * Tap: during the banner / spotlight a full-screen button skips to the next beat ("TAP TO SKIP >" bottom right).
--   Phone and PC: everything scales with the 1.2 rule (min(1.2, 94% width / 760, 86% height / 400)).
--   Switches: script attributes HardpointHUDMatchEndEnabled (default true, read at start; false = 1.7 / 1.2 board) and
--   HardpointHUDSpotModelEnabled (default true, read per spotlight). Diagnostics: HardpointHUDEnd ("banner" / "spot" /
--   "board" / "off"), HardpointHUDEndModel ("model" / "noChar" / "noClone" / "off"), HardpointHUDEndSkips.
-- v1.9 (Kepu 2026-11-12 15:38 "I barely saw the mvp screen", pick A): the spotlight shows HardpointHUDSpotSec (6, was 4) s, so
--   the board comes at 8 s (7 s of board); a tap in the first HardpointHUDSkipGuard (1.5) s of the banner or the spotlight does
--   not skip (a click / tap on ATTACK as the match ends no longer jumps past both). Same look. Switch: script attribute
--   HardpointHUDEndTimingV2Enabled (default true; the spotlight length is read at start, the guard per tap; false = 1.8).
--   Diagnostic: HardpointHUDEndSkipsIgnored.
-- v1.10 (Kepu 2026-11-12 15:39 "it should default back to the island after the match stats and everything"): when nobody
--   chose (no PLAY AGAIN / MAIN MENU / BACK TO ISLAND press this results), HardpointHUDAutoIslandLead (1) s before the results
--   end the client sends DinoModeRequest "island" by itself, as the BACK TO ISLAND button does (ModeServer 1.3: a squad leader
--   takes the squad; a squad member never sends it: the leader decides; PLAY AGAIN by the leader keeps the squad here). Only
--   on a server with ReplicatedStorage HubOn = true (else the old next match / team screen). The board countdown then reads
--   "BACK TO ISLAND IN m:ss" (after PLAY AGAIN: the old "TEAM SCREEN IN" / "NEXT MATCH IN"). Switch: script attribute
--   HardpointHUDAutoIslandEnabled (default true, read per frame; false = 1.9). Diagnostic: HardpointHUDAutoIsland ("sent" /
--   "chose:<press>" / "member" / "off").
-- v1.11 (Arena record, MDA-496, plan docs/plans/ARENA_RECORD_v1.1.md T4, mockup docs/mockups/wl_record_v0.1.html "MATCH
--   RESULTS (FIRST BEAT)"; Kepu 2026-11-13 pick "C · B + name tag"): on the banner beat of an Arena 4v4 (ReplicatedStorage.Practice
--   PrArena == true), under "ARENA" / the practice line, a record line (y 172, centred) and the last-10 squares (y 216):
--     "RECORD" (muted) "<from>" (muted) "→" "<to>" (white) + tag "+1 W" (green rgb(70,224,138)) / "+1 L" (pink) when
--     ArenaMatchOut is "w" / "l"; "RECORD" "<from>" + tag "RECORD UNCHANGED" (grey rgb(58,70,86)) when "n"; from "-" -> "RECORD —"
--     + the tag only. to = from + 1 win / loss (computed; the menu shows the saved record).
--     Squares (18 px, 6 apart, centred): ArenaMatchLast + the new outcome, the last 10, oldest left.
--   Inputs (ArenaRecordServer 1.2 player attributes): ArenaMatchId, ArenaMatchOut, ArenaMatchFrom, ArenaMatchLast. The line shows
--   only when ArenaMatchId differs from the value this client saw when HpPhase last became "live" (a result for this match).
--   Bots matches and public Hardpoint: the banner as 1.10. Switch: script attribute HardpointHUDRecordLineEnabled (default true,
--   read per frame; false = 1.10). Diagnostic: HardpointHUDRecordLine ("w" / "l" / "n" / "none").
-- v1.12 (Kepu 2026-11-13 12:37 "Yes change it to show arena"): in an Arena 4v4 (ReplicatedStorage.Practice PrArena == true) the
--   line under the score on the banner beat and under the title on the board reads "ARENA" instead of "PRACTICE · <tier> BOTS".
--   Bots matches still read "PRACTICE · <tier> BOTS", public Hardpoint "HARDPOINT". Switch: script attribute
--   HardpointHUDArenaLabelEnabled (default true, read per frame; false = 1.11).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService") -- v1.1

local VERSION = "1.5"
VERSION = "1.6" -- v1.6 top-gap compass + slim HUD
VERSION = "1.7" -- v1.7 point marker v3
VERSION = "1.8" -- v1.8 match end
VERSION = "1.9" -- v1.9 end timing
VERSION = "1.10" -- v1.10 auto back to island
VERSION = "1.11" -- v1.11 Arena record line on the banner
VERSION = "1.12" -- v1.12 ARENA label on the results
VERSION = "1.13" -- v1.13 phone HUD v2 score strip
-- v1.13 (phone HUD v2, MDA-534, plan docs/plans/PHONE_HUD_V2_v1.0.md rule 4, mockup docs/mockups/phone_hud_v0.1.html "A · your
--   version"; Kepu 2026-11-13: "really consider all the space being taken up on the phone screen", pick "I like option A but keep
--   the current button style"): while player attribute PhoneHudV2 is true (PhoneMenu 1.0) and script attribute
--   HardpointHUDPhoneV2Enabled ~= false (default true, read per frame), the compass stays in the top gap (top 8, the right limit 12 px
--   left of PhoneMenu's ☰, 44 px kept free each side) and becomes the middle of a score strip: the score card, Status and Next
--   pills are hidden; "PhoneYou" (blue rgb(90,160,255), your score) sits 4 px left of the compass and "PhoneFoe" (red
--   rgb(224,40,74), their score) 4 px right of it, each HardpointHUDPhoneBoxW (40) wide and as tall as the compass + its under
--   line (corner 6, FredokaOne 18 white); "PhoneStatus" under that row, the strip's width: "<P1 · 1:23> · <status>" (warm-up
--   "P1 IN 0:08 · GET READY"; status text / colour as the Status pill; "· NEXT P2 IN 0:20" added while NEXT shows), TextSize 12.
--   All three show only with the compass. Off / PC: as 1.12.
if script:GetAttribute("HardpointHUDArenaLabelEnabled") == nil then script:SetAttribute("HardpointHUDArenaLabelEnabled", true) end
script:SetAttribute("HardpointHUDVersion", VERSION)
if script:GetAttribute("HardpointHUDEnabled") == nil then script:SetAttribute("HardpointHUDEnabled", true) end

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("Hardpoint", 60)
if not state then return end
local shared = ReplicatedStorage:WaitForChild("HardpointShared", 30)
local H = shared and require(shared:WaitForChild("HardpointRules"))

local BLUE, RED, YELLOW = Color3.fromRGB(90, 160, 255), Color3.fromRGB(224, 40, 74), Color3.fromRGB(255, 200, 50)
local BLUE_T, RED_T = Color3.fromRGB(188, 216, 255), Color3.fromRGB(255, 194, 204)
local PANEL = Color3.fromRGB(20, 20, 26)
local FONT = Enum.Font.FredokaOne

local function now() return workspace:GetServerTimeNow() end
local function fmt(s)
	s = math.max(0, math.ceil(s - 1e-6))
	return ("%d:%02d"):format(s // 60, s % 60)
end
local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = p return c end
local function stroke(p, color, tr, th)
	local s = Instance.new("UIStroke") s.Color = color s.Transparency = tr s.Thickness = th
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Parent = p return s
end
local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do l[k] = v end
	l.Parent = parent
	return l
end

-- ---------- the gui ----------
local gui = Instance.new("ScreenGui")
gui.Name = "HardpointHUD"
gui.DisplayOrder = 6
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Name = "ScoreCard"
card.AnchorPoint = Vector2.new(0, 0)
card.Position = UDim2.new(0, 16, 0, 58)
card.Size = UDim2.fromOffset(260, 58)
card.BackgroundColor3 = PANEL
card.BackgroundTransparency = 0.18
corner(card, 10)
stroke(card, Color3.new(1, 1, 1), 0.5, 1.5)
card.Parent = gui

local emblem = Instance.new("Frame")
emblem.Name = "Emblem"
emblem.Position = UDim2.fromOffset(9, 13)
emblem.Size = UDim2.fromOffset(32, 32)
emblem.BackgroundColor3 = BLUE
corner(emblem, 7)
stroke(emblem, Color3.new(1, 1, 1), 0.3, 1.5)
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(110, 175, 255), Color3.fromRGB(42, 95, 174))
grad.Rotation = 45
grad.Parent = emblem
emblem.Parent = card

local function row(y, fill)
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 50, 0, y)
	back.Size = UDim2.new(1, -150, 0, 9)
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.BackgroundTransparency = 0.86
	corner(back, 5)
	back.Parent = card
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(0, 1)
	f.BackgroundColor3 = fill
	corner(f, 5)
	f.Parent = back
	return back, f
end
local youBack, youFill = row(15, BLUE)
local foeBack, foeFill = row(34, RED)
local youNum = label(card, {Position = UDim2.new(1, -98, 0, 9), Size = UDim2.fromOffset(40, 20), TextSize = 17, TextColor3 = BLUE_T,
	TextXAlignment = Enum.TextXAlignment.Right, Text = "0"})
local foeNum = label(card, {Position = UDim2.new(1, -98, 0, 28), Size = UDim2.fromOffset(40, 20), TextSize = 17, TextColor3 = RED_T,
	TextXAlignment = Enum.TextXAlignment.Right, Text = "0"})
local sep = Instance.new("Frame")
sep.Position = UDim2.new(1, -52, 0, 9)
sep.Size = UDim2.fromOffset(1, 40)
sep.BackgroundColor3 = Color3.new(1, 1, 1)
sep.BackgroundTransparency = 0.75
sep.BorderSizePixel = 0
sep.Parent = card
local clockL = label(card, {Position = UDim2.new(1, -50, 0, 8), Size = UDim2.fromOffset(46, 20), TextSize = 16, Text = "10:00"})
local pointL = label(card, {Position = UDim2.new(1, -50, 0, 30), Size = UDim2.fromOffset(46, 18), TextSize = 13, TextColor3 = YELLOW, Text = "P1"})

local function pill(name)
	local l = label(gui, {Name = name, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), TextSize = 15,
		BackgroundTransparency = 0.45, BackgroundColor3 = PANEL, Text = ""})
	l.Position = UDim2.new(0, 16, 0, 0)
	corner(l, 6)
	local pad = Instance.new("UIPadding") pad.PaddingLeft = UDim.new(0, 8) pad.PaddingRight = UDim.new(0, 8) pad.Parent = l
	return l
end
local status = pill("Status")
local nextL = pill("Next")
-- v1.6: slim HUD (see the header)
if script:GetAttribute("HardpointHUDScale") == nil then script:SetAttribute("HardpointHUDScale", 0.8) end
local slimScales = {}
for _, o in ipairs({card, status, nextL}) do
	local u = Instance.new("UIScale")
	u.Name = "HardpointHUDSlim"
	u.Parent = o
	table.insert(slimScales, u)
end
local slimS, slimStatusY, slimNextY = 1, 58 + 58 + 6, 58 + 58 + 6 + 30
local function slimUpdate()
	local s = tonumber(script:GetAttribute("HardpointHUDScale")) or 1
	s = math.clamp(s, 0.5, 1.2)
	slimS = s
	for _, u in ipairs(slimScales) do u.Scale = s end
	slimStatusY = 58 + 58 * s + 6 * s
	slimNextY = slimStatusY + 30 * s
	status.Position = UDim2.new(0, 16, 0, slimStatusY)
	nextL.Position = UDim2.new(0, 16, 0, slimNextY)
end
nextL.TextColor3 = YELLOW

-- marker
local marker = Instance.new("Frame")
marker.Name = "Marker"
marker.AnchorPoint = Vector2.new(0.5, 1)
marker.Size = UDim2.fromOffset(120, 74)
marker.BackgroundTransparency = 1
marker.Parent = gui
local mLabel = label(marker, {Size = UDim2.new(1, 0, 0, 18), TextSize = 14, Text = "CAPTURE", TextStrokeTransparency = 0.5})
local dia = Instance.new("Frame")
dia.AnchorPoint = Vector2.new(0.5, 0.5)
dia.Position = UDim2.new(0.5, 0, 0, 37)
dia.Size = UDim2.fromOffset(26, 26)
dia.Rotation = 45
dia.BackgroundColor3 = PANEL
dia.BackgroundTransparency = 0.4
corner(dia, 4)
local diaStroke = stroke(dia, Color3.new(1, 1, 1), 0, 3)
dia.Parent = marker
local diaNum = label(dia, {Size = UDim2.fromScale(1, 1), Rotation = -45, TextSize = 15, Text = "1"})
local mDist = label(marker, {Position = UDim2.new(0, 0, 0, 54), Size = UDim2.new(1, 0, 0, 18), TextSize = 13, Text = "",
	TextStrokeTransparency = 0.5})

-- results
local results = Instance.new("Frame")
results.Name = "Results"
results.AnchorPoint = Vector2.new(0.5, 0.5)
results.Position = UDim2.fromScale(0.5, 0.4)
results.Size = UDim2.fromOffset(320, 120)
results.BackgroundColor3 = PANEL
results.BackgroundTransparency = 0.12
corner(results, 12)
local resStroke = stroke(results, BLUE, 0.1, 2)
results.Visible = false
results.Parent = gui
local resTitle = label(results, {Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 44), TextSize = 40, Text = "VICTORY"})
local resScore = label(results, {Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 24), TextSize = 20,
	TextColor3 = Color3.fromRGB(207, 211, 220), Text = ""})
local resNext = label(results, {Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 0, 20), TextSize = 14, TextColor3 = YELLOW, Text = ""})

-- v1.2: the scoreboard (see the header)
if script:GetAttribute("HardpointHUDBoardEnabled") == nil then script:SetAttribute("HardpointHUDBoardEnabled", true) end
local boardOn = script:GetAttribute("HardpointHUDBoardEnabled") ~= false
local BOARD_W, BOARD_H, BOARD_ROWS, ROW_H = 720, 316, 6, 22
local SHORT = {TRex = "T-Rex", Raptor = "Raptor", Pachy = "Pachy", Herrera = "Herrera", Teno = "Teno", Therizino = "Therizino",
	Dilo = "Dilo", Troodon = "Troodon"}
local MUTED_C = Color3.fromRGB(143, 153, 170)
local boardDismissed = false
local bp = Instance.new("Frame")
bp.Name = "Board"
bp.AnchorPoint = Vector2.new(0.5, 0.5)
bp.Position = UDim2.fromScale(0.5, 0.5)
bp.Size = UDim2.fromOffset(BOARD_W, BOARD_H)
bp.BackgroundColor3 = PANEL
bp.BackgroundTransparency = 0.08
bp.Visible = false
bp.Parent = gui
corner(bp, 12)
local bpStroke = stroke(bp, BLUE, 0.1, 2)
local bpScale = Instance.new("UIScale")
bpScale.Parent = bp
local bTitle = label(bp, {Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 42), TextSize = 40, Text = "VICTORY"})
local bSub = label(bp, {Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 18), TextSize = 14, TextColor3 = MUTED_C, Text = ""})
local COLS = {{x = 0, w = 0.40, a = Enum.TextXAlignment.Left}, {x = 0.40, w = 0.22, a = Enum.TextXAlignment.Left},
	{x = 0.62, w = 0.08, a = Enum.TextXAlignment.Right}, {x = 0.70, w = 0.08, a = Enum.TextXAlignment.Right},
	{x = 0.78, w = 0.22, a = Enum.TextXAlignment.Right}}
local bTables = {}
for t = 1, 2 do
	local f = Instance.new("Frame")
	f.Name = t == 1 and "Mine" or "Theirs"
	f.BackgroundTransparency = 1
	f.Position = UDim2.fromOffset(t == 1 and 18 or 366, 84)
	f.Size = UDim2.fromOffset(336, ROW_H * (BOARD_ROWS + 1))
	f.Parent = bp
	local rowsT = {}
	for r = 0, BOARD_ROWS do
		local cells = {}
		for c, col in ipairs(COLS) do
			local l = label(f, {Position = UDim2.new(col.x, 0, 0, r * ROW_H), Size = UDim2.new(col.w, -4, 0, ROW_H), TextSize = r == 0 and 13 or 15,
				TextXAlignment = col.a, TextColor3 = r == 0 and MUTED_C or Color3.new(1, 1, 1), Text = "", RichText = true,
				TextTruncate = Enum.TextTruncate.AtEnd})
			cells[c] = l
		end
		if r > 0 then
			local line = Instance.new("Frame")
			line.BorderSizePixel = 0
			line.BackgroundColor3 = Color3.new(1, 1, 1)
			line.BackgroundTransparency = 0.92
			line.Position = UDim2.fromOffset(0, r * ROW_H)
			line.Size = UDim2.new(1, 0, 0, 1)
			line.Parent = f
		end
		rowsT[r] = cells
	end
	bTables[t] = rowsT
end
local bNext = label(bp, {Position = UDim2.fromOffset(18, 248), Size = UDim2.fromOffset(250, 52), TextSize = 15, TextColor3 = YELLOW,
	TextXAlignment = Enum.TextXAlignment.Left, Text = ""})
local function boardButton(name, text, x, w, color, tc)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Position, b.Size = UDim2.fromOffset(x, 248), UDim2.fromOffset(w, 52)
	b.BackgroundColor3 = color
	b.Font = FONT
	b.TextSize = 18
	b.TextColor3 = tc
	b.Text = text
	b.Parent = bp
	corner(b, 8)
	stroke(b, Color3.fromRGB(26, 19, 0), 0, 2)
	return b
end
local againB = boardButton("PlayAgain", "PLAY AGAIN", 362, 172, YELLOW, Color3.fromRGB(27, 20, 6))
local menuB = boardButton("MainMenu", "MAIN MENU", 546, 156, Color3.fromRGB(43, 53, 66), Color3.new(1, 1, 1))
againB.Activated:Connect(function()
	boardDismissed = true
	bp.Visible = false
	script:SetAttribute("HardpointHUDBoardPress", "again")
end)
menuB.Activated:Connect(function()
	script:SetAttribute("HardpointHUDBoardPress", "menu")
	local mr = ReplicatedStorage:FindFirstChild("DinoModeRequest")
	if mr then mr:FireServer("menu") end
end)
local function mss(s) s = math.max(0, math.floor((tonumber(s) or 0) + 0.5)) return ("%d:%02d"):format(s // 60, s % 60) end
-- v1.12: an Arena 4v4 reads ARENA (see the header)
local function arenaLabel(pr)
	return pr ~= nil and pr:GetAttribute("PrArena") == true and script:GetAttribute("HardpointHUDArenaLabelEnabled") ~= false
end
local function drawBoard(mine, you, foe, title)
	local vp = workspace.CurrentCamera.ViewportSize
	bpScale.Scale = math.min(1.2, vp.X * 0.94 / BOARD_W, vp.Y * 0.86 / BOARD_H)
	bTitle.Text = title
	bTitle.TextColor3 = title == "VICTORY" and BLUE_T or (title == "DEFEAT" and RED_T or YELLOW)
	bpStroke.Color = title == "VICTORY" and BLUE or (title == "DEFEAT" and RED or YELLOW)
	local pr = ReplicatedStorage:FindFirstChild("Practice")
	bSub.Text = pr and ("PRACTICE · " .. string.upper(tostring(pr:GetAttribute("PrDifficulty") or "")) .. " BOTS") or "HARDPOINT"
	if arenaLabel(pr) then bSub.Text = "ARENA" end -- v1.12
	bNext.Text = (pr and "TEAM SCREEN IN " or "NEXT MATCH IN ") .. fmt((state:GetAttribute("HpResultsEndAt") or now()) - now())
	local ok, list = pcall(function() return HttpService:JSONDecode(state:GetAttribute("HpBoard") or "[]") end)
	if not ok or type(list) ~= "table" then list = {} end
	local left = (mine == "A" or mine == "B") and mine or "A"
	local right = left == "A" and "B" or "A"
	local scores = {A = state:GetAttribute("HpScoreA") or 0, B = state:GetAttribute("HpScoreB") or 0}
	for t, side in ipairs({left, right}) do
		local rows = {}
		for _, r in ipairs(list) do if r.team == side then table.insert(rows, r) end end
		table.sort(rows, function(x, y) if x.k ~= y.k then return x.k > y.k end return tostring(x.name) < tostring(y.name) end)
		local T = bTables[t]
		local hdCol = t == 1 and "#5aa0ff" or "#e0284a"
		T[0][1].Text = ('<font color="%s">%s · %d</font>'):format(hdCol, t == 1 and "BLUE" or "RED", scores[side])
		T[0][2].Text, T[0][3].Text, T[0][4].Text, T[0][5].Text = "Dino", "K", "D", "On point"
		for i = 1, BOARD_ROWS do
			local r = rows[i]
			local cells = T[i]
			if r then
				local me = r.id == "u" .. player.UserId
				local nm = (me and "★ " or "") .. tostring(r.name)
				if r.bot then nm = nm .. ' <font size="10" color="#8f99aa">BOT</font>' end
				cells[1].Text, cells[2].Text = nm, SHORT[r.species] or tostring(r.species or "")
				cells[3].Text, cells[4].Text, cells[5].Text = tostring(r.k or 0), tostring(r.d or 0), mss(r.pt)
				for _, c in ipairs(cells) do c.TextColor3 = me and YELLOW or Color3.new(1, 1, 1) end
			else
				for _, c in ipairs(cells) do c.Text = "" end
			end
		end
	end
end

-- ---------- v1.8: match end (see the header) ----------
if script:GetAttribute("HardpointHUDMatchEndEnabled") == nil then script:SetAttribute("HardpointHUDMatchEndEnabled", true) end
if script:GetAttribute("HardpointHUDSpotModelEnabled") == nil then script:SetAttribute("HardpointHUDSpotModelEnabled", true) end
local meOn = boardOn and script:GetAttribute("HardpointHUDMatchEndEnabled") ~= false
local GREEN = Color3.fromRGB(120, 200, 80)
local GOLD, SILVER = Color3.fromRGB(255, 210, 90), Color3.fromRGB(201, 211, 224)
local PINK = Color3.fromRGB(255, 107, 132)
local CYAN_B = Color3.fromRGB(95, 224, 200)
local DARK_T = Color3.fromRGB(27, 20, 6)
local END_W, END_H = 760, 400
local BEAT_BANNER, BEAT_SPOT = 2, 6
-- v1.9: end timing (see the header)
for k, v in pairs({HardpointHUDEndTimingV2Enabled = true, HardpointHUDSpotSec = 6, HardpointHUDSkipGuard = 1.5}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
if script:GetAttribute("HardpointHUDEndTimingV2Enabled") ~= false then
	BEAT_SPOT = BEAT_BANNER + (tonumber(script:GetAttribute("HardpointHUDSpotSec")) or 6)
end
local RES = (H and H.RESULTS) or 15
local endKey, endSkip, spotKey = nil, 0, nil
local endCanChoose = true
local islandPressAt = 0
local SkillTreeC
do
	local f = ReplicatedStorage:FindFirstChild("SkillShared")
	local m = f and f:FindFirstChild("SkillTree")
	if m then local ok, mod = pcall(require, m) if ok then SkillTreeC = mod end end
end
local function xpNext(level)
	if SkillTreeC and SkillTreeC.xpToNext then return SkillTreeC.xpToNext(level) end
	return 30 + 10 * (level - 1)
end

local endDim = Instance.new("Frame")
endDim.Name = "EndDim"
endDim.Size = UDim2.fromScale(1, 1)
endDim.BackgroundColor3 = Color3.new(0, 0, 0)
endDim.BackgroundTransparency = 0.5
endDim.BorderSizePixel = 0
endDim.Visible = false
endDim.Parent = gui

local endBanner = Instance.new("Frame")
endBanner.Name = "EndBanner"
endBanner.AnchorPoint = Vector2.new(0.5, 0.5)
endBanner.Position = UDim2.fromScale(0.5, 0.45)
endBanner.Size = UDim2.fromOffset(END_W, 170)
endBanner.BackgroundTransparency = 1
endBanner.Visible = false
endBanner.Parent = gui
local endBannerScale = Instance.new("UIScale")
endBannerScale.Parent = endBanner
local ebTitle = label(endBanner, {Size = UDim2.new(1, 0, 0, 96), TextSize = 84, Text = "VICTORY", TextStrokeTransparency = 0.6})
local ebScore = label(endBanner, {Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 30), TextSize = 26, Text = "",
	RichText = true, TextStrokeTransparency = 0.7})
local ebSub = label(endBanner, {Position = UDim2.fromOffset(0, 140), Size = UDim2.new(1, 0, 0, 22), TextSize = 16,
	TextColor3 = Color3.fromRGB(207, 211, 220), Text = ""})

local endSpot = Instance.new("Frame")
endSpot.Name = "EndSpot"
endSpot.AnchorPoint = Vector2.new(0.5, 0.5)
endSpot.Position = UDim2.fromScale(0.5, 0.5)
endSpot.Size = UDim2.fromOffset(560, 340)
endSpot.BackgroundTransparency = 1
endSpot.Visible = false
endSpot.Parent = gui
local endSpotScale = Instance.new("UIScale")
endSpotScale.Parent = endSpot
local spotList = Instance.new("UIListLayout")
spotList.FillDirection = Enum.FillDirection.Horizontal
spotList.HorizontalAlignment = Enum.HorizontalAlignment.Center
spotList.VerticalAlignment = Enum.VerticalAlignment.Center
spotList.Padding = UDim.new(0, 28)
spotList.SortOrder = Enum.SortOrder.LayoutOrder
spotList.Parent = endSpot
local function spotCard(order)
	local c = Instance.new("Frame")
	c.Name = "Card" .. order
	c.LayoutOrder = order
	c.Size = UDim2.fromOffset(250, 330)
	c.BackgroundColor3 = PANEL
	c.BackgroundTransparency = 0.08
	c.Parent = endSpot
	corner(c, 14)
	local st = stroke(c, GOLD, 0, 3)
	local pill = label(c, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(84, 26),
		TextSize = 18, Text = "MVP", BackgroundTransparency = 0, BackgroundColor3 = GOLD, TextColor3 = DARK_T})
	corner(pill, 6)
	local vpf = Instance.new("ViewportFrame")
	vpf.AnchorPoint = Vector2.new(0.5, 0)
	vpf.Position = UDim2.new(0.5, 0, 0, 48)
	vpf.Size = UDim2.fromOffset(214, 170)
	vpf.BackgroundColor3 = Color3.fromRGB(38, 46, 58)
	vpf.BackgroundTransparency = 0.2
	vpf.Ambient = Color3.fromRGB(170, 170, 170)
	vpf.LightColor = Color3.new(1, 1, 1)
	vpf.LightDirection = Vector3.new(-1, -1, -0.6)
	vpf.Parent = c
	corner(vpf, 10)
	local fb = label(vpf, {Size = UDim2.fromScale(1, 1), TextSize = 22, Text = "", TextColor3 = Color3.fromRGB(207, 211, 220)})
	local nm = label(c, {Position = UDim2.fromOffset(8, 226), Size = UDim2.new(1, -16, 0, 28), TextSize = 22, Text = "",
		TextTruncate = Enum.TextTruncate.AtEnd})
	local sub = label(c, {Position = UDim2.fromOffset(8, 254), Size = UDim2.new(1, -16, 0, 20), TextSize = 14, Text = "",
		TextColor3 = MUTED_C})
	local stats = label(c, {Position = UDim2.fromOffset(8, 284), Size = UDim2.new(1, -16, 0, 24), TextSize = 16, Text = "",
		RichText = true})
	return {card = c, stroke = st, pill = pill, vpf = vpf, fb = fb, name = nm, sub = sub, stats = stats}
end
local spotCards = {spotCard(1), spotCard(2)}

local endSkipB = Instance.new("TextButton")
endSkipB.Name = "EndSkip"
endSkipB.Size = UDim2.fromScale(1, 1)
endSkipB.BackgroundTransparency = 1
endSkipB.Text = ""
endSkipB.ZIndex = 5
endSkipB.Visible = false
endSkipB.Parent = gui
label(endSkipB, {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(150, 28),
	TextSize = 14, Text = "TAP TO SKIP >", BackgroundTransparency = 0.45, BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 5})

-- the board, grown (only with the switch on)
local COLS2 = {{0, 0.34, Enum.TextXAlignment.Left}, {0.34, 0.18, Enum.TextXAlignment.Left}, {0.52, 0.07, Enum.TextXAlignment.Right},
	{0.59, 0.07, Enum.TextXAlignment.Right}, {0.66, 0.16, Enum.TextXAlignment.Right}, {0.82, 0.18, Enum.TextXAlignment.Right}}
local xpCells = {}
local strip, sTot, sParts, sDino, sBar, sNum, sUp, sNote, islandB
if meOn then
	bp.Size = UDim2.fromOffset(END_W, END_H)
	for t = 1, 2 do
		local T = bTables[t]
		local f = T[0][1].Parent
		f.Position = UDim2.fromOffset(t == 1 and 18 or 392, 84)
		f.Size = UDim2.fromOffset(350, ROW_H * (BOARD_ROWS + 1))
		xpCells[t] = {}
		for r = 0, BOARD_ROWS do
			for c = 1, 5 do
				local col = COLS2[c]
				T[r][c].Position = UDim2.new(col[1], 0, 0, r * ROW_H)
				T[r][c].Size = UDim2.new(col[2], -4, 0, ROW_H)
				T[r][c].TextXAlignment = col[3]
			end
			local col = COLS2[6]
			xpCells[t][r] = label(f, {Position = UDim2.new(col[1], 0, 0, r * ROW_H), Size = UDim2.new(col[2], -4, 0, ROW_H),
				TextSize = r == 0 and 13 or 15, TextXAlignment = col[3], TextColor3 = r == 0 and MUTED_C or GREEN,
				Text = r == 0 and "XP" or "", TextTruncate = Enum.TextTruncate.AtEnd})
		end
	end
	strip = Instance.new("Frame")
	strip.Name = "XpStrip"
	strip.Position = UDim2.fromOffset(18, 246)
	strip.Size = UDim2.fromOffset(END_W - 36, 72)
	strip.BackgroundColor3 = Color3.new(1, 1, 1)
	strip.BackgroundTransparency = 0.94
	strip.Parent = bp
	corner(strip, 8)
	sTot = label(strip, {Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(150, 30), TextSize = 26, TextColor3 = GREEN,
		TextXAlignment = Enum.TextXAlignment.Left, Text = ""})
	sParts = label(strip, {Position = UDim2.fromOffset(170, 8), Size = UDim2.new(1, -182, 0, 26), TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left, RichText = true, Text = "", TextTruncate = Enum.TextTruncate.AtEnd})
	sDino = label(strip, {Position = UDim2.fromOffset(12, 42), Size = UDim2.fromOffset(150, 22), TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left, Text = ""})
	local barBg = Instance.new("Frame")
	barBg.Position = UDim2.fromOffset(170, 47)
	barBg.Size = UDim2.new(1, -470, 0, 12)
	barBg.BackgroundColor3 = Color3.new(1, 1, 1)
	barBg.BackgroundTransparency = 0.85
	barBg.BorderSizePixel = 0
	barBg.Parent = strip
	corner(barBg, 6)
	sBar = Instance.new("Frame")
	sBar.Size = UDim2.fromScale(0, 1)
	sBar.BackgroundColor3 = GREEN
	sBar.BorderSizePixel = 0
	sBar.Parent = barBg
	corner(sBar, 6)
	sNum = label(strip, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -200, 0, 42), Size = UDim2.fromOffset(90, 22),
		TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right, Text = ""})
	sUp = label(strip, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 42), Size = UDim2.fromOffset(186, 22),
		TextSize = 13, TextColor3 = YELLOW, TextXAlignment = Enum.TextXAlignment.Right, Text = ""})
	bNext.Position, bNext.Size = UDim2.fromOffset(18, 330), UDim2.fromOffset(330, 26)
	sNote = label(bp, {Position = UDim2.fromOffset(18, 358), Size = UDim2.fromOffset(330, 22), TextSize = 14, TextColor3 = MUTED_C,
		TextXAlignment = Enum.TextXAlignment.Left, Text = ""})
	islandB = boardButton("BackToIsland", "BACK TO ISLAND", END_W - 18 - 210, 210, CYAN_B, Color3.fromRGB(3, 33, 26))
	islandB.Position = UDim2.fromOffset(END_W - 18 - 210, 330)
	againB.Position = UDim2.fromOffset(END_W - 18 - 210 - 12 - 172, 330)
	menuB.Position = UDim2.fromOffset(END_W - 18 - 156, 330)
	islandB.Activated:Connect(function()
		if not endCanChoose then return end
		islandPressAt = now()
		script:SetAttribute("HardpointHUDBoardPress", "island")
		local mr = ReplicatedStorage:FindFirstChild("DinoModeRequest")
		if mr then mr:FireServer("island") end
	end)
	-- a squad member's PLAY AGAIN does nothing (1.2's handler hides the board; put it back)
	againB.Activated:Connect(function()
		if not endCanChoose then boardDismissed = false end
	end)
end

local awCache, awRaw = nil, nil
local function readAwards()
	local raw = state:GetAttribute("HpAwards")
	if raw ~= awRaw then
		awRaw = raw
		local ok, t = pcall(function() return HttpService:JSONDecode(raw) end)
		awCache = (type(raw) == "string" and raw ~= "" and ok and type(t) == "table") and t or nil
	end
	return awCache
end
local function readBoardList()
	local ok, list = pcall(function() return HttpService:JSONDecode(state:GetAttribute("HpBoard") or "[]") end)
	return (ok and type(list) == "table") and list or {}
end

local function modelInto(c, uid)
	for _, ch in ipairs(c.vpf:GetChildren()) do
		if ch:IsA("Model") or ch:IsA("Camera") then ch:Destroy() end
	end
	c.fb.Visible = true
	if script:GetAttribute("HardpointHUDSpotModelEnabled") == false then return "off" end
	local pl = uid and Players:GetPlayerByUserId(uid)
	local chr = pl and pl.Character
	local hum = chr and chr:FindFirstChildOfClass("Humanoid")
	local root = chr and chr:FindFirstChild("HumanoidRootPart")
	if not (chr and hum and root and hum.Health > 0) then return "noChar" end
	local was = chr.Archivable
	chr.Archivable = true
	local ok, copy = pcall(function() return chr:Clone() end)
	chr.Archivable = was
	if not ok or not copy then return "noClone" end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local h2 = copy:FindFirstChildOfClass("Humanoid")
	if h2 then h2.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	copy.Parent = c.vpf
	local cf, size = copy:GetBoundingBox()
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local right = Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z)
	right = right.Magnitude > 0.01 and right.Unit or Vector3.new(1, 0, 0)
	local dist = (math.max(size.X, size.Y, size.Z) * 0.62) / math.tan(math.rad(20))
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(cf.Position + (look + right * 0.55).Unit * dist + Vector3.new(0, size.Y * 0.12, 0), cf.Position)
	cam.Parent = c.vpf
	c.vpf.CurrentCamera = cam
	c.fb.Visible = false
	return "model"
end

local function fillSpot(aw, mine)
	local list = readBoardList()
	local byId = {}
	for _, r in ipairs(list) do byId[r.id] = r end
	local picks = {}
	if aw.mvp ~= "" then table.insert(picks, {id = aw.mvp, kind = "MVP", col = GOLD}) end
	if aw.svp ~= "" then table.insert(picks, {id = aw.svp, kind = "SVP", col = SILVER}) end
	local how = {}
	for i, c in ipairs(spotCards) do
		local pk = picks[i]
		c.card.Visible = pk ~= nil
		if pk then
			local r = byId[pk.id] or {}
			c.pill.Text, c.pill.BackgroundColor3, c.stroke.Color = pk.kind, pk.col, pk.col
			local sp = SHORT[r.species] or tostring(r.species or "")
			c.name.Text = tostring(r.name or "")
			c.sub.Text = ("%s · %s"):format(sp, r.team == mine and "BLUE" or "RED")
			c.stats.Text = ('<font color="#%s">%d</font> K   <font color="#%s">%s</font> ON PT'):format(pk.col:ToHex(), r.k or 0,
				pk.col:ToHex(), mss(r.pt))
			c.fb.Text = string.upper(sp)
			table.insert(how, modelInto(c, tonumber(string.match(pk.id, "^u(%d+)$") or "")))
		end
	end
	script:SetAttribute("HardpointHUDEndModel", table.concat(how, ","))
end

local function fillStrip(aw, prog)
	local row = aw and aw.rows and aw.rows["u" .. player.UserId]
	strip.Visible = aw ~= nil
	if not aw then return end
	if not row then
		sTot.Text, sParts.Text, sDino.Text, sNum.Text, sUp.Text = "+0 XP", "NO XP THIS MATCH", "", "", ""
		sBar.Size = UDim2.fromScale(0, 1)
		return
	end
	local total = tonumber(row.total) or 0
	local shown = math.floor(total * prog + 0.5)
	sTot.Text = ("+%d XP"):format(shown)
	local parts = {}
	for _, it in ipairs({{"Kills", row.kill}, {aw.winner == "draw" and "Draw" or "Win", row.win}, {"Point", row.point},
		{"MVP", row.mvp}, {"SVP", row.svp}}) do
		if (tonumber(it[2]) or 0) > 0 then table.insert(parts, ('%s <font color="#78c850">+%d</font>'):format(it[1], it[2])) end
	end
	sParts.Text = #parts > 0 and table.concat(parts, "    ") or "NO XP THIS MATCH"
	local lvB, lvA = tonumber(row.lvB) or 0, tonumber(row.lvA) or 0
	if lvA <= 0 then
		sDino.Text, sNum.Text, sUp.Text = "", "", ""
		sBar.Size = UDim2.fromScale(0, 1)
		return
	end
	local L, into, nxt = lvB, tonumber(row.inB) or 0, tonumber(row.nxB) or xpNext(lvB)
	local add = shown
	while add > 0 and L < lvA and nxt > 0 do
		if into + add >= nxt then add -= (nxt - into) L += 1 into = 0 nxt = xpNext(L) else into += add add = 0 end
	end
	if L >= lvA then into, nxt = math.min(into + add, tonumber(row.inA) or 0), tonumber(row.nxA) or 0 end
	if prog >= 1 then L, into, nxt = lvA, tonumber(row.inA) or 0, tonumber(row.nxA) or 0 end
	local ch = player.Character
	local sp = (ch and ch:GetAttribute("Species")) or player:GetAttribute("DinoSpecies") or ""
	sDino.Text = ("%s LV %d"):format(string.upper(SHORT[sp] or tostring(sp)), L)
	sBar.Size = UDim2.fromScale(nxt > 0 and math.clamp(into / nxt, 0, 1) or 1, 1)
	sNum.Text = nxt > 0 and ("%d / %d"):format(into, nxt) or "MAX"
	local ups = L - lvB
	sUp.Text = ups > 0 and ("▲ +%d LEVEL%s · +%d SKILL PT"):format(ups, ups > 1 and "S" or "", ups) or ""
end

local RESULT_TEXT = {saving = "SAVING…", teleporting = "TELEPORTING…", studio = "LIVE GAME ONLY", teleportFailed = "TRY AGAIN",
	badArg = "TRY AGAIN", busy = "TRY AGAIN"}
local function fillButtons()
	local hubOn = ReplicatedStorage:GetAttribute("HubOn") == true
	islandB.Visible, menuB.Visible = hubOn, not hubOn
	local sq = player:GetAttribute("SquadId")
	local inSq = type(sq) == "string" and sq ~= ""
	local leader = inSq and player:GetAttribute("SquadLeader") == true
	local member = inSq and not leader
	endCanChoose = not member
	for _, b in ipairs({againB, islandB, menuB}) do
		b.AutoButtonColor = not member
		b.BackgroundTransparency = member and 0.6 or 0
		b.TextTransparency = member and 0.45 or 0
	end
	sNote.Text = member and "★ LEADER CHOOSES" or (leader and "★ YOU CHOOSE FOR THE SQUAD" or "")
	local txt = "BACK TO ISLAND"
	if islandPressAt > 0 and (player:GetAttribute("ModeLastAt") or 0) >= islandPressAt - 0.5 then
		txt = RESULT_TEXT[player:GetAttribute("ModeLastResult")] or txt
	end
	islandB.Text = txt
end

local function drawEndBoard(mine, aw)
	local list = readBoardList()
	local left = (mine == "A" or mine == "B") and mine or "A"
	local right = left == "A" and "B" or "A"
	for t, side in ipairs({left, right}) do
		bTables[t][0][5].Text = "ON PT"
		local rows = {}
		for _, r in ipairs(list) do if r.team == side then table.insert(rows, r) end end
		table.sort(rows, function(x, y) if x.k ~= y.k then return x.k > y.k end return tostring(x.name) < tostring(y.name) end)
		for i = 1, BOARD_ROWS do
			local r = rows[i]
			local cell = xpCells[t][i]
			if r then
				local a = aw and aw.rows and aw.rows[r.id]
				cell.Text = (a and not r.bot) and ("+" .. tostring(a.total or 0)) or "—"
				local tag = aw and ((r.id == aw.mvp and '<font size="11" color="#ffd25a">MVP</font> ')
					or (r.id == aw.svp and '<font size="11" color="#c9d3e0">SVP</font> ')) or nil
				if tag then bTables[t][i][1].Text = tag .. bTables[t][i][1].Text end
				cell.TextColor3 = r.id == "u" .. player.UserId and YELLOW or GREEN
			else
				cell.Text = ""
			end
		end
	end
end

local function endHide()
	if endDim.Visible or endBanner.Visible or endSpot.Visible or endSkipB.Visible then
		endDim.Visible, endBanner.Visible, endSpot.Visible, endSkipB.Visible = false, false, false, false
	end
	if script:GetAttribute("HardpointHUDEnd") ~= "off" then script:SetAttribute("HardpointHUDEnd", "off") end
end

-- v1.10: auto back to island (see the header)
for k, v in pairs({HardpointHUDAutoIslandEnabled = true, HardpointHUDAutoIslandLead = 1}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local autoKey, autoChoice, autoSent = nil, nil, false
local function autoPress(what)
	return function()
		if endCanChoose and not autoSent then autoChoice = autoChoice or what end
	end
end
againB.Activated:Connect(autoPress("again"))
menuB.Activated:Connect(autoPress("menu"))
if islandB then islandB.Activated:Connect(autoPress("island")) end
local function autoIsland(endsAt)
	if autoKey ~= endsAt then autoKey, autoChoice, autoSent = endsAt, nil, false end
	local on = script:GetAttribute("HardpointHUDAutoIslandEnabled") ~= false and ReplicatedStorage:GetAttribute("HubOn") == true
	local left = endsAt - now()
	if on and autoChoice == nil then
		bNext.Text = "BACK TO ISLAND IN " .. fmt(left)
	end
	local diag = (not on and "off") or (not endCanChoose and "member") or (autoChoice and ("chose:" .. autoChoice)) or
		(autoSent and "sent") or "waiting"
	if not autoSent and on and endCanChoose and autoChoice == nil
		and left <= (tonumber(script:GetAttribute("HardpointHUDAutoIslandLead")) or 1) then
		autoSent = true
		diag = "sent"
		islandPressAt = now()
		local mr = ReplicatedStorage:FindFirstChild("DinoModeRequest")
		if mr then mr:FireServer("island") end
	end
	if script:GetAttribute("HardpointHUDAutoIsland") ~= diag then script:SetAttribute("HardpointHUDAutoIsland", diag) end
end

-- v1.11: Arena record line on the banner (see the header)
local recordLine
do
	if script:GetAttribute("HardpointHUDRecordLineEnabled") == nil then script:SetAttribute("HardpointHUDRecordLineEnabled", true) end
	local GREEN, GREYTAG, MUTEDC = Color3.fromRGB(70, 224, 138), Color3.fromRGB(58, 70, 86), Color3.fromRGB(147, 162, 182)
	local liveId = player:GetAttribute("ArenaMatchId")
	state:GetAttributeChangedSignal("HpPhase"):Connect(function()
		if state:GetAttribute("HpPhase") == "live" then liveId = player:GetAttribute("ArenaMatchId") end
	end)
	local row = Instance.new("Frame")
	row.Name = "RecordLine"
	row.BackgroundTransparency = 1
	row.Position, row.Size = UDim2.fromOffset(0, 172), UDim2.new(1, 0, 0, 36)
	row.Visible = false
	row.Parent = endBanner
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 12)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	local function part(order, size, color)
		local l = label(row, {LayoutOrder = order, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, size + 6),
			TextSize = size, TextColor3 = color, TextStrokeTransparency = 0.7})
		return l
	end
	local head = part(1, 16, MUTEDC)
	head.Text = "RECORD"
	local from = part(2, 24, MUTEDC)
	local arrow = part(3, 20, MUTEDC)
	arrow.Text = "→"
	local to = part(4, 30, Color3.new(1, 1, 1))
	local tag = label(row, {LayoutOrder = 5, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), TextSize = 16,
		BackgroundTransparency = 0, TextColor3 = Color3.fromRGB(13, 18, 24)})
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 6)
	tc.Parent = tag
	local tp = Instance.new("UIPadding")
	tp.PaddingLeft, tp.PaddingRight = UDim.new(0, 9), UDim.new(0, 9)
	tp.Parent = tag
	local dots = Instance.new("Frame")
	dots.Name = "RecordLast"
	dots.BackgroundTransparency = 1
	dots.Position, dots.Size = UDim2.fromOffset(0, 216), UDim2.new(1, 0, 0, 18)
	dots.Visible = false
	dots.Parent = endBanner
	local dl = Instance.new("UIListLayout")
	dl.FillDirection = Enum.FillDirection.Horizontal
	dl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dl.Padding = UDim.new(0, 6)
	dl.SortOrder = Enum.SortOrder.LayoutOrder
	dl.Parent = dots
	local drawnKey
	recordLine = function()
		local pr = ReplicatedStorage:FindFirstChild("Practice")
		local id = player:GetAttribute("ArenaMatchId")
		local out = player:GetAttribute("ArenaMatchOut")
		local show = script:GetAttribute("HardpointHUDRecordLineEnabled") ~= false and pr ~= nil and pr:GetAttribute("PrArena") == true
			and type(id) == "string" and id ~= "" and id ~= liveId and (out == "w" or out == "l" or out == "n")
		row.Visible, dots.Visible = show, show
		local diag = show and out or "none"
		if script:GetAttribute("HardpointHUDRecordLine") ~= diag then script:SetAttribute("HardpointHUDRecordLine", diag) end
		if not show then return end
		local fromT = tostring(player:GetAttribute("ArenaMatchFrom") or "-")
		local key = id .. out .. fromT
		if drawnKey == key then return end
		drawnKey = key
		local w, l = string.match(fromT, "^(%d+)%-(%d+)$")
		local known = w ~= nil
		w, l = tonumber(w) or 0, tonumber(l) or 0
		from.Text = known and fromT or "—"
		local counted = out == "w" or out == "l"
		arrow.Visible = known and counted
		to.Visible = known and counted
		to.Text = out == "w" and ("%d-%d"):format(w + 1, l) or ("%d-%d"):format(w, l + 1)
		tag.Text = out == "w" and "+1 W" or out == "l" and "+1 L" or "RECORD UNCHANGED"
		tag.BackgroundColor3 = out == "w" and GREEN or out == "l" and PINK or GREYTAG
		tag.TextColor3 = counted and Color3.fromRGB(13, 18, 24) or Color3.new(1, 1, 1)
		local last = tostring(player:GetAttribute("ArenaMatchLast") or ""):gsub("[^wl]", "")
		if counted then last ..= out end
		last = last:sub(-10)
		for _, c in ipairs(dots:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
		for i = 1, #last do
			local sq = Instance.new("Frame")
			sq.Name = "D" .. i
			sq.LayoutOrder = i
			sq.BorderSizePixel = 0
			sq.Size = UDim2.fromOffset(18, 18)
			sq.BackgroundColor3 = last:sub(i, i) == "w" and GREEN or PINK
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 4)
			c.Parent = sq
			sq.Parent = dots
		end
	end
end

local function endFrame(mine, you, foe, title)
	local endsAt = state:GetAttribute("HpResultsEndAt") or now()
	if endKey ~= endsAt then endKey, endSkip, spotKey, islandPressAt = endsAt, 0, nil, 0 end
	local t = now() - (endsAt - RES) + endSkip
	local aw = readAwards()
	local hasSpot = aw ~= nil and ((aw.mvp or "") ~= "" or (aw.svp or "") ~= "")
	local beat = (t < BEAT_BANNER and "banner") or ((hasSpot and t < BEAT_SPOT) and "spot") or "board"
	local vp = workspace.CurrentCamera.ViewportSize
	local sc = math.min(1.2, vp.X * 0.94 / END_W, vp.Y * 0.86 / END_H)
	endBannerScale.Scale, endSpotScale.Scale, bpScale.Scale = sc, sc, sc
	local hid = boardDismissed
	endDim.Visible = beat ~= "board" and not hid
	endBanner.Visible = beat == "banner" and not hid
	endSpot.Visible = beat == "spot" and not hid
	endSkipB.Visible = beat ~= "board" and not hid
	bp.Visible = beat == "board" and not hid
	if script:GetAttribute("HardpointHUDEnd") ~= beat then script:SetAttribute("HardpointHUDEnd", beat) end
	if hid then return end
	if beat == "banner" then
		ebTitle.Text = title
		ebTitle.TextColor3 = title == "VICTORY" and YELLOW or (title == "DEFEAT" and PINK or Color3.new(1, 1, 1))
		ebScore.Text = ('<font color="#5aa0ff">BLUE %d</font>   –   <font color="#e0284a">%d RED</font>'):format(you, foe)
		local pr = ReplicatedStorage:FindFirstChild("Practice")
		ebSub.Text = pr and ("PRACTICE · " .. string.upper(tostring(pr:GetAttribute("PrDifficulty") or "")) .. " BOTS") or "HARDPOINT"
		if arenaLabel(pr) then ebSub.Text = "ARENA" end -- v1.12
		recordLine() -- v1.11
	elseif beat == "spot" then
		if spotKey ~= endsAt then
			spotKey = endsAt
			fillSpot(aw, mine)
		end
	else
		drawEndBoard(mine, aw)
		local start = hasSpot and BEAT_SPOT or BEAT_BANNER
		fillStrip(aw, math.clamp((t - start - 0.3) / 2.5, 0, 1))
		fillButtons()
		autoIsland(endsAt) -- v1.10
	end
end

endSkipB.Activated:Connect(function()
	local endsAt = state:GetAttribute("HpResultsEndAt") or now()
	local t = now() - (endsAt - RES) + endSkip
	local aw = readAwards()
	local hasSpot = aw ~= nil and ((aw.mvp or "") ~= "" or (aw.svp or "") ~= "")
	if script:GetAttribute("HardpointHUDEndTimingV2Enabled") ~= false then -- v1.9: skip guard
		local into = (t < BEAT_BANNER) and t or (t - BEAT_BANNER)
		if into < (tonumber(script:GetAttribute("HardpointHUDSkipGuard")) or 1.5) then
			script:SetAttribute("HardpointHUDEndSkipsIgnored", (script:GetAttribute("HardpointHUDEndSkipsIgnored") or 0) + 1)
			return
		end
	end
	if t < BEAT_BANNER then
		endSkip += BEAT_BANNER - t
	elseif hasSpot and t < BEAT_SPOT then
		endSkip += BEAT_SPOT - t
	end
	script:SetAttribute("HardpointHUDEndSkips", (script:GetAttribute("HardpointHUDEndSkips") or 0) + 1)
end)

-- ---------- data ----------
local points = {}
local function readPoints()
	local ok, list = pcall(function() return HttpService:JSONDecode(state:GetAttribute("HpPoints") or "[]") end)
	points = {}
	if ok and type(list) == "table" then
		for i, p in ipairs(list) do points[i] = {name = tostring(p.name), centre = Vector3.new(p.x, p.y, p.z)} end
	end
end
readPoints()
state:GetAttributeChangedSignal("HpPoints"):Connect(readPoints)

-- v1.4: the compass (see the header)
if script:GetAttribute("HardpointHUDCompassEnabled") == nil then script:SetAttribute("HardpointHUDCompassEnabled", true) end
local compassOn = script:GetAttribute("HardpointHUDCompassEnabled") ~= false
local UIS = game:GetService("UserInputService")
local GREY = Color3.fromRGB(201, 206, 216)
local cmp = Instance.new("Frame")
cmp.Name = "Compass"
cmp.BackgroundColor3 = PANEL
cmp.BackgroundTransparency = 0.25
cmp.ClipsDescendants = true
cmp.Visible = false
cmp.Parent = gui
corner(cmp, 6)
stroke(cmp, Color3.new(1, 1, 1), 0.75, 1)
local cmpTicks = {}
for i = 0, 23 do
	local deg = i * 15
	local t
	local letter = ({[0] = "N", [90] = "E", [180] = "S", [270] = "W"})[deg]
	if letter then
		t = label(cmp, {Size = UDim2.fromOffset(16, 14), AnchorPoint = Vector2.new(0.5, 0), TextSize = 12, Text = letter,
			TextColor3 = Color3.fromRGB(230, 236, 245)})
	else
		t = Instance.new("Frame")
		t.BorderSizePixel = 0
		t.BackgroundColor3 = Color3.new(1, 1, 1)
		t.BackgroundTransparency = deg % 45 == 0 and 0.35 or 0.6
		t.AnchorPoint = Vector2.new(0.5, 0)
		t.Parent = cmp
	end
	cmpTicks[i] = {g = t, deg = deg, letter = letter ~= nil}
end
local notch = label(cmp, {Size = UDim2.fromOffset(12, 10), AnchorPoint = Vector2.new(0.5, 1), TextSize = 10, Text = "▲",
	TextColor3 = YELLOW})
local function cmpIcon(name)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.Size = UDim2.fromOffset(60, 26)
	f.ZIndex = 3
	f.Parent = cmp
	local d = Instance.new("Frame")
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Rotation = 45
	d.BorderSizePixel = 0
	d.ZIndex = 3
	d.Parent = f
	local ds = stroke(d, Color3.new(1, 1, 1), 0, 2)
	local n = label(f, {AnchorPoint = Vector2.new(0.5, 0.5), TextSize = 11, Text = "1", ZIndex = 4})
	local side = label(f, {AnchorPoint = Vector2.new(0.5, 0.5), TextSize = 12, Text = "", ZIndex = 4})
	local sub = label(cmp, {AnchorPoint = Vector2.new(0.5, 0), TextSize = 10, Text = "", ZIndex = 3,
		TextStrokeTransparency = 0.4})
	return {f = f, d = d, ds = ds, n = n, side = side, sub = sub, x = nil, edgeSide = 0}
end
local curIcon, nextIcon = cmpIcon("Current"), cmpIcon("Next")
local cmpLastIdx, cmpLastT = nil, os.clock()
local function flatYaw(v) return math.deg(math.atan2(v.X, -v.Z)) end -- 0 = north (−Z), 90 = east (+X)
local function wrap(a) return (a + 180) % 360 - 180 end
local function cmpPhone()
	local c = player.Character
	return UIS.TouchEnabled or (c ~= nil and c:GetAttribute("ArenaTouchState") == "on")
end
-- place one icon; returns the relative bearing used
local function cmpPlace(ic, target, camPos, camYaw, W, Hh, dt, look)
	local rel = wrap(flatYaw(target - camPos) - camYaw)
	local x
	if math.abs(rel) <= 90 then
		ic.edgeSide = 0
		x = (0.5 + rel / 180) * W
		ic.side.Text = ""
	else
		local s = rel > 0 and 1 or -1
		if math.abs(rel) > 170 and ic.edgeSide ~= 0 then s = ic.edgeSide end -- hysteresis behind you
		ic.edgeSide = s
		x = s > 0 and (W - 10) or 10
		ic.side.Text = s > 0 and "▶" or "◀"
	end
	if not ic.x then ic.x = x end
	ic.x += (x - ic.x) * (1 - math.exp(-14 * dt))
	local dsz = math.floor(Hh * 0.55)
	ic.f.Size = UDim2.fromOffset(dsz + 24, Hh)
	ic.f.Position = UDim2.fromOffset(ic.x, 0)
	ic.d.Size = UDim2.fromOffset(dsz, dsz)
	ic.d.Position = UDim2.new(0.5, 0, 0, Hh * 0.45)
	ic.n.Position = UDim2.new(0.5, 0, 0, Hh * 0.45)
	ic.n.Size = UDim2.fromOffset(dsz, dsz)
	ic.side.Position = UDim2.new(0.5, ic.edgeSide * (dsz * 0.5 + 7), 0, Hh * 0.45)
	ic.side.Size = UDim2.fromOffset(10, dsz)
	ic.sub.Position = UDim2.fromOffset(ic.x, Hh * 0.45 + dsz * 0.5 + 1)
	ic.sub.Size = UDim2.fromOffset(60, 10)
	return rel
end
-- v1.6: the top gap between the Roblox buttons and SKILLS (see the header); returns left, right, top in this gui's frame
if script:GetAttribute("HardpointHUDCompassTopEnabled") == nil then script:SetAttribute("HardpointHUDCompassTopEnabled", true) end
if script:GetAttribute("HardpointHUDCompassBgT") == nil then script:SetAttribute("HardpointHUDCompassBgT", 0.65) end
if script:GetAttribute("HardpointHUDCompassStrokeT") == nil then script:SetAttribute("HardpointHUDCompassStrokeT", 0.85) end
local cmpStroke = cmp:FindFirstChildOfClass("UIStroke")
local function topGap(vp)
	local go = gui.AbsolutePosition
	local giv = GuiService:GetGuiInset()
	local L = 16
	local okT, tb = pcall(function() return GuiService.TopbarInset end)
	if okT and tb and tb.Width > 0 then L = math.max(16, tb.Min.X - giv.X - go.X + 12) end
	local pg = gui.Parent
	local R, T
	local lb = pg and pg:FindFirstChild("LabButton")
	local sk = lb and lb:IsA("ScreenGui") and lb.Enabled and lb:FindFirstChild("Skills")
	if sk and sk:IsA("GuiObject") and sk.Visible and sk.AbsoluteSize.X > 0 then
		R, T = sk.AbsolutePosition.X - go.X - 12, sk.AbsolutePosition.Y - go.Y
	end
	if not R then
		local st = pg and pg:FindFirstChild("ArenaStatus")
		local pl = st and st:IsA("ScreenGui") and st.Enabled and st:FindFirstChild("Pill", true)
		if pl and pl:IsA("GuiObject") and pl.Visible and pl.AbsoluteSize.X > 0 then
			R, T = pl.AbsolutePosition.X - go.X - 12, pl.AbsolutePosition.Y - go.Y
		end
	end
	if not R then R = vp.X - go.X - 16 end
	if okT and tb and tb.Width > 0 and tb.Max.X < vp.X - 1 then R = math.min(R, tb.Max.X - giv.X - go.X - 12) end
	return L, R, math.max(0, T or 8)
end
local function drawCompass(dt, cam, vp, idx, warm, rel, remaining, showNext)
	local phone = cmpPhone()
	local Hh = phone and 22 or 26
	local W = math.clamp(vp.X * (phone and 0.34 or 0.30), 180, 420)
	local left = card.AbsolutePosition.X - gui.AbsolutePosition.X + card.AbsoluteSize.X + 12
	local room = (vp.X - 96) - left -- v1.5: 96 (1.4: 16)
	local x, y
	local topDone = false -- v1.6: the top gap first
	cmp.BackgroundTransparency = tonumber(script:GetAttribute("HardpointHUDCompassBgT")) or 0.25
	if cmpStroke then cmpStroke.Transparency = tonumber(script:GetAttribute("HardpointHUDCompassStrokeT")) or 0.75 end
	if script:GetAttribute("HardpointHUDCompassTopEnabled") ~= false then
		local gL, gR, gT = topGap(vp)
		if gR - gL >= 140 then
			W = math.min(W, gR - gL)
			local mid = vp.X / 2 - gui.AbsolutePosition.X
			x, y = math.clamp(mid - W / 2, gL, gR - W), gT
			topDone = true
			script:SetAttribute("HardpointHUDCompassPlace", "top")
		end
	end
	if topDone then
		-- v1.6: placed in the top gap
	elseif room >= 140 then -- v1.5: 140 (1.4: 180)
		W = math.min(W, room)
		x, y = left + (room - W) / 2, 58 + (58 - Hh) / 2
		script:SetAttribute("HardpointHUDCompassPlace", "row")
	else -- v1.5: under the pills (1.4: the top centre)
		W = card.AbsoluteSize.X
		x, y = 16, (nextL.Visible and 152 or 122) + 24 + 6
		if slimS ~= 1 then y = (nextL.Visible and slimNextY or slimStatusY) + 24 * slimS + 6 * slimS end -- v1.6
		script:SetAttribute("HardpointHUDCompassPlace", "column")
	end
	cmp.Position, cmp.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(W, Hh)
	cmp.Visible = true
	local camPos = cam.CFrame.Position
	local camYaw = flatYaw(cam.CFrame.LookVector)
	for _, t in pairs(cmpTicks) do
		local r = wrap(t.deg - camYaw)
		t.g.Visible = math.abs(r) <= 90
		if t.g.Visible then
			if t.letter then
				t.g.Position = UDim2.fromOffset((0.5 + r / 180) * W, 1)
			else
				local tall = t.deg % 45 == 0
				t.g.Size = UDim2.fromOffset(1, tall and Hh * 0.35 or Hh * 0.2)
				t.g.Position = UDim2.fromOffset((0.5 + r / 180) * W, 1)
			end
		end
	end
	notch.Position = UDim2.fromOffset(W / 2, Hh + 1)
	-- current point
	local ci = warm and 1 or idx
	local p = points[ci]
	if cmpLastIdx and cmpLastIdx ~= ci and nextIcon.x then curIcon.x = nextIcon.x end -- take over from NEXT
	cmpLastIdx = ci
	local diag = ""
	if p then
		local blink = rel == "C" and (math.floor(os.clock() * 4) % 2 == 1)
		local col = warm and GREY or (rel == "you" and BLUE or (rel == "foe" and RED or (rel == "C" and YELLOW or Color3.new(1, 1, 1))))
		curIcon.d.BackgroundColor3 = col
		curIcon.d.BackgroundTransparency = blink and 0.5 or 0
		curIcon.ds.Color = Color3.new(1, 1, 1)
		curIcon.n.Text = tostring(ci)
		curIcon.n.TextColor3 = (col == Color3.new(1, 1, 1) or col == GREY or col == YELLOW) and Color3.fromRGB(26, 19, 0) or Color3.new(1, 1, 1)
		local r = cmpPlace(curIcon, p.centre, camPos, camYaw, W, Hh, dt)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		curIcon.sub.Text = hrp and tostring(math.floor((hrp.Position - p.centre).Magnitude + 0.5)) or ""
		curIcon.f.Visible, curIcon.sub.Visible = true, false -- the distance shows under the strip below
		diag = ("cur:%d"):format(math.floor(r + 0.5))
	else
		curIcon.f.Visible, curIcon.sub.Visible = false, false
	end
	-- next point
	local ni = tonumber(state:GetAttribute("HpNextIndex")) or 1
	local np = showNext and points[ni] or nil
	if np then
		nextIcon.d.BackgroundColor3 = PANEL
		nextIcon.d.BackgroundTransparency = 0.2
		nextIcon.ds.Color = GREY
		nextIcon.n.Text = tostring(ni)
		nextIcon.n.TextColor3 = GREY
		local r = cmpPlace(nextIcon, np.centre, camPos, camYaw, W, Hh, dt)
		nextIcon.f.Visible = true
		diag ..= (" next:%d"):format(math.floor(r + 0.5))
	else
		nextIcon.f.Visible = false
		nextIcon.x = nil
	end
	script:SetAttribute("HardpointHUDCompass", diag)
	return curIcon, nextIcon
end
-- the readouts under the strip (distance / countdown), outside the clipped strip
local cmpUnder = Instance.new("Frame")
cmpUnder.Name = "CompassUnder"
cmpUnder.BackgroundTransparency = 1
cmpUnder.Visible = false
cmpUnder.Parent = gui
local curDist = label(cmpUnder, {AnchorPoint = Vector2.new(0.5, 0), TextSize = 12, Text = "", TextStrokeTransparency = 0.35})
local nextCount = label(cmpUnder, {AnchorPoint = Vector2.new(0.5, 0), TextSize = 12, Text = "", TextColor3 = GREY,
	TextStrokeTransparency = 0.35})

-- v1.13: phone HUD v2 score strip (see the header)
if script:GetAttribute("HardpointHUDPhoneV2Enabled") == nil then script:SetAttribute("HardpointHUDPhoneV2Enabled", true) end
if script:GetAttribute("HardpointHUDPhoneBoxW") == nil then script:SetAttribute("HardpointHUDPhoneBoxW", 40) end
local function phoneV2() return player:GetAttribute("PhoneHudV2") == true and script:GetAttribute("HardpointHUDPhoneV2Enabled") ~= false end
local function v2box(name, color)
	local f = label(gui, {Name = name, BackgroundTransparency = 0.08, BackgroundColor3 = color, TextSize = 18, Text = "0", Visible = false})
	corner(f, 6)
	return f
end
local pYou, pFoe = v2box("PhoneYou", BLUE), v2box("PhoneFoe", RED)
local pStatus = label(gui, {Name = "PhoneStatus", TextSize = 12, Text = "", Visible = false, TextStrokeTransparency = 0.35})
local v2hid = false
do
	local rawTopGap = topGap
	topGap = function(vp)
		local L, R, T = rawTopGap(vp)
		if not phoneV2() then return L, R, T end
		local go = gui.AbsolutePosition
		local pm = gui.Parent and gui.Parent:FindFirstChild("PhoneMenu")
		local b = pm and pm:IsA("ScreenGui") and pm.Enabled and pm:FindFirstChild("Burger")
		if b and b.AbsoluteSize.X > 0 then R = b.AbsolutePosition.X - go.X - 12 end
		local box = (tonumber(script:GetAttribute("HardpointHUDPhoneBoxW")) or 40) + 4
		return L + box, R - box, 8
	end
	local rawDraw = drawCompass
	drawCompass = function(...)
		local c1, c2 = rawDraw(...)
		local on = phoneV2() and cmp.Visible
		if on then
			card.Visible, status.Visible = false, false
			local showNext = nextL.Visible
			nextL.Visible = false
			v2hid = true
			local bw = tonumber(script:GetAttribute("HardpointHUDPhoneBoxW")) or 40
			local cp, cs = cmp.Position, cmp.Size
			local x, y, w, h = cp.X.Offset, cp.Y.Offset, cs.X.Offset, cs.Y.Offset + 15
			pYou.Position, pYou.Size = UDim2.fromOffset(x - 4 - bw, y), UDim2.fromOffset(bw, h)
			pFoe.Position, pFoe.Size = UDim2.fromOffset(x + w + 4, y), UDim2.fromOffset(bw, h)
			pYou.Text, pFoe.Text = youNum.Text, foeNum.Text
			pStatus.Position, pStatus.Size = UDim2.fromOffset(x - 4 - bw, y + h + 2), UDim2.fromOffset(w + 8 + 2 * bw, 14)
			local t = pointL.Text .. " · " .. status.Text
			if showNext then t ..= " · " .. nextL.Text end
			pStatus.Text, pStatus.TextColor3 = t, status.TextColor3
		elseif v2hid then
			card.Visible = true
			v2hid = false
		end
		pYou.Visible, pFoe.Visible, pStatus.Visible = on, on, on
		return c1, c2
	end
	cmp:GetPropertyChangedSignal("Visible"):Connect(function()
		if not cmp.Visible then pYou.Visible, pFoe.Visible, pStatus.Visible = false, false, false end
	end)
end

local tags = {} -- [player] = BillboardGui
local function tagFor(pl)
	local g = tags[pl]
	if g and g.Parent then return g end
	g = Instance.new("BillboardGui")
	g.Name = "HardpointTag"
	g.AlwaysOnTop = true
	g.Size = UDim2.fromOffset(180, 24)
	g.LightInfluence = 0
	g.MaxDistance = 600
	local l = label(g, {Name = "Label", Size = UDim2.fromScale(1, 1), TextSize = 15, TextStrokeTransparency = 0.4, Text = pl.DisplayName})
	l.TextColor3 = Color3.new(1, 1, 1)
	g.Parent = gui
	tags[pl] = g
	return g
end
local function dropTag(pl)
	if tags[pl] then tags[pl]:Destroy() tags[pl] = nil end
end
Players.PlayerRemoving:Connect(dropTag)

local function updateTags(mine, live)
	local tt = script.Parent:FindFirstChild("TeamTags") -- v1.3
	local yielding = script:GetAttribute("HardpointHUDTagsYieldEnabled") ~= false and tt ~= nil and tt:GetAttribute("TeamTagsState") == "on"
	script:SetAttribute("HardpointHUDTagsYielding", yielding)
	if yielding then live = false end
	for _, pl in ipairs(Players:GetPlayers()) do
		local t = pl:GetAttribute("HardpointTeam")
		local c = pl.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if live and pl ~= player and (t == "A" or t == "B") and hrp and hum and hum.Health > 0 and pl:GetAttribute("InMenu") ~= true then
			local g = tagFor(pl)
			g.Adornee = hrp
			local ok, size = pcall(function() return c:GetExtentsSize() end)
			g.StudsOffsetWorldSpace = Vector3.new(0, (ok and size.Y or 8) * 0.6 + 3, 0)
			g.Label.TextColor3 = (t == mine) and BLUE or RED
		else
			dropTag(pl)
		end
	end
end

local lastTags = 0
-- v1.7: point marker v3 (see the header)
for k, v in pairs({HardpointHUDMarkerV3Enabled = true, HardpointHUDMarkerLift = 6, HardpointHUDMarkerEdge = 28,
	HardpointHUDMarkerBottomPhone = 110, HardpointHUDMarkerBottomPC = 60, HardpointHUDMarkerFade = 70, HardpointHUDMarkerBlend = 0.15}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local mv3Scale = Instance.new("UIScale")
mv3Scale.Name = "MarkerV3Scale"
mv3Scale.Parent = marker
local mv3 = {x = nil, y = nil, a = 1, glued = false, side = 0, state = "off", t = os.clock(), applied = false,
	kind = nil, fromX = 0, fromY = 0, blendAt = 0}
local function mv3Num(k, d) return tonumber(script:GetAttribute(k)) or d end
local function mv3Alpha(a, strokeBase)
	local t = 1 - a
	for _, l in ipairs({mLabel, diaNum, mDist}) do
		l.TextTransparency = t
		l.TextStrokeTransparency = 0.5 + 0.5 * t
	end
	dia.BackgroundTransparency = 0.4 + 0.6 * t
	diaStroke.Transparency = strokeBase + (1 - strokeBase) * t
end
local function mv3Off()
	if not mv3.applied then return end
	mv3.applied = false
	marker.AnchorPoint = Vector2.new(0.5, 1)
	marker.ZIndex = 1
	mv3Scale.Scale = 1
	mLabel.Visible = true
	for _, l in ipairs({mLabel, diaNum, mDist}) do l.TextTransparency = 0 l.TextStrokeTransparency = 0.5 end
	dia.BackgroundTransparency = 0.4
	mv3.x, mv3.y, mv3.glued = nil, nil, false
end
local function markerV3(cam, vp, p, warm)
	local now = os.clock()
	local dt = math.clamp(now - mv3.t, 0, 0.1)
	mv3.t = now
	mv3.applied = true
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.ZIndex = 0
	marker.Size = UDim2.fromOffset(120, 74)
	local gi = GuiService:GetGuiInset()
	local gTop = gui.AbsolutePosition + gi -- this gui's top-left in screen px
	local gSize = gui.AbsoluteSize
	local okT, tb = pcall(function() return GuiService.TopbarInset end)
	local edge = mv3Num("HardpointHUDMarkerEdge", 28)
	local L, R = gTop.X + edge, gTop.X + gSize.X - edge
	local T = ((okT and tb and tb.Height > 0) and tb.Max.Y or gi.Y) + 8
	local B = gTop.Y + gSize.Y - (cmpPhone() and mv3Num("HardpointHUDMarkerBottomPhone", 110) or mv3Num("HardpointHUDMarkerBottomPC", 60))
	if B < T + 40 then B = T + 40 end
	local anchor = p.centre + Vector3.new(0, mv3Num("HardpointHUDMarkerLift", 6), 0)
	local sp = cam:WorldToViewportPoint(anchor)
	local inView = sp.Z > 0 and sp.X >= L and sp.X <= R and sp.Y >= T and sp.Y <= B
	local tx, ty, state
	if inView then
		tx, ty, state = sp.X, sp.Y, "view"
		mv3.side = 0
	else
		local v = cam.CFrame:PointToObjectSpace(anchor)
		local mx, my, hw, hh = (L + R) / 2, (T + B) / 2, (R - L) / 2, (B - T) / 2
		if v.Z < 0 then -- in front, outside the frame: the screen direction onto the edge
			local dx, dy = sp.X - mx, sp.Y - my
			if math.abs(dx) < 1e-3 and math.abs(dy) < 1e-3 then dx = 1 end
			local k = math.min(hw / math.max(math.abs(dx), 1e-3), hh / math.max(math.abs(dy), 1e-3))
			tx, ty = mx + dx * k, my + dy * k
			mv3.side = dx >= 0 and 1 or -1
		else -- behind: sideways offset + distance behind, so it rides the bottom edge round
			local dx, dy = v.X, math.max(v.Z, 1e-3)
			local k = math.min(hw / math.max(math.abs(dx), 1e-3), hh / dy)
			tx, ty = mx + dx * k, my + dy * k
			mv3.side = dx >= 0 and 1 or -1
		end
		if math.abs(tx - L) < 1 then state = "edge L" elseif math.abs(tx - R) < 1 then state = "edge R"
		elseif math.abs(ty - T) < 1 then state = "edge T" else state = "edge B" end
	end
	-- place: on the live spot; a change between in view and off view blends over HardpointHUDMarkerBlend s
	local kind = (state == "view") and "view" or "edge"
	if mv3.x == nil then mv3.x, mv3.y, mv3.kind = tx, ty, kind end
	if kind ~= mv3.kind then
		mv3.kind, mv3.fromX, mv3.fromY, mv3.blendAt = kind, mv3.x, mv3.y, now
	end
	local bl = mv3Num("HardpointHUDMarkerBlend", 0.15)
	local f = bl > 0 and math.clamp((now - mv3.blendAt) / bl, 0, 1) or 1
	f = f * f * (3 - 2 * f)
	mv3.x, mv3.y = mv3.fromX + (tx - mv3.fromX) * f, mv3.fromY + (ty - mv3.fromY) * f
	mv3.glued = f >= 1
	-- opacity
	local a = 1
	if state == "view" then
		local fade = mv3Num("HardpointHUDMarkerFade", 70)
		local dc = math.sqrt((mv3.x - vp.X / 2) ^ 2 + (mv3.y - vp.Y / 2) ^ 2)
		if fade > 0 and dc < fade then a = 0.35 + 0.65 * (dc / fade) end
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not warm and hrp and H and H.inPoint(hrp.Position, p.centre) then a, state = 0, "on point" end
	mv3.a += (a - mv3.a) * (1 - math.exp(-10 * dt))
	mv3.state = state
	mLabel.Visible = state == "view"
	mv3Scale.Scale = (state == "view") and 1 or 0.84
	mv3Alpha(math.clamp(mv3.a, 0, 1), diaStroke.Transparency)
	marker.Position = UDim2.fromOffset(mv3.x - gTop.X, mv3.y - gTop.Y)
	marker.Visible = mv3.a > 0.02
	if script:GetAttribute("HardpointHUDMarker") ~= state then script:SetAttribute("HardpointHUDMarker", state) end
end

RunService.RenderStepped:Connect(function()
	local phase = state:GetAttribute("HpPhase")
	local show = script:GetAttribute("HardpointHUDEnabled") ~= false and state:GetAttribute("HpLive") == true
		and player:GetAttribute("InMenu") ~= true and (phase == "warmup" or phase == "live" or phase == "results")
	gui.Enabled = show
	if os.clock() - lastTags > 0.5 then
		lastTags = os.clock()
		updateTags(player:GetAttribute("HardpointTeam"), show and phase ~= "results")
	end
	if not show then
		script:SetAttribute("HardpointHUDState", "hidden")
		return
	end
	local cam = workspace.CurrentCamera
	local vp = cam.ViewportSize
	card.Size = UDim2.fromOffset(math.clamp(vp.X * 0.26, 220, 330), 58)
	status.Position = UDim2.new(0, 16, 0, 58 + 58 + 6)
	nextL.Position = UDim2.new(0, 16, 0, 58 + 58 + 6 + 30)
	slimUpdate() -- v1.6

	local mine = player:GetAttribute("HardpointTeam")
	local sa, sb = state:GetAttribute("HpScoreA") or 0, state:GetAttribute("HpScoreB") or 0
	local you, foe = sa, sb
	if mine == "B" then you, foe = sb, sa end
	local limit = H and H.LIMIT or 250
	youNum.Text, foeNum.Text = tostring(you), tostring(foe)
	youFill.Size = UDim2.fromScale(math.clamp(you / limit, 0, 1), 1)
	foeFill.Size = UDim2.fromScale(math.clamp(foe / limit, 0, 1), 1)
	clockL.Text = fmt(state:GetAttribute("HpClock") or 600) .. (state:GetAttribute("HpClockPaused") and " II" or "")

	local idx = tonumber(state:GetAttribute("HpIndex")) or 1
	local remaining = (state:GetAttribute("HpPointEndsAt") or now()) - now()
	local occ = state:GetAttribute("HpOcc") or "N"
	local rel = occ == "C" and "C" or ((occ == "A" or occ == "B") and (occ == mine and "you" or "foe") or "N")

	if phase == "results" and boardOn then -- v1.2: the scoreboard
		cmp.Visible, cmpUnder.Visible = false, false -- v1.4
		results.Visible = false
		marker.Visible, status.Visible, nextL.Visible = false, false, false
		pointL.Text = ""
		local w = state:GetAttribute("HpWinner")
		local title = (w == "draw") and "DRAW" or (w == mine and "VICTORY" or "DEFEAT")
		bp.Visible = not boardDismissed
		if not boardDismissed then drawBoard(mine, you, foe, title) end
		if meOn then endFrame(mine, you, foe, title) end -- v1.8
		script:SetAttribute("HardpointHUDBoard", boardDismissed and "dismissed" or "shown")
		script:SetAttribute("HardpointHUDState", "results")
		return
	end
	if meOn then endHide() end -- v1.8
	if bp.Visible or boardDismissed then -- v1.2: out of the results
		bp.Visible, boardDismissed = false, false
		script:SetAttribute("HardpointHUDBoard", "hidden")
	end
	if phase == "results" then
		cmp.Visible, cmpUnder.Visible = false, false -- v1.4
		results.Visible = true
		marker.Visible, status.Visible, nextL.Visible = false, false, false
		local w = state:GetAttribute("HpWinner")
		local title = (w == "draw") and "DRAW" or (w == mine and "VICTORY" or "DEFEAT")
		resTitle.Text = title
		resStroke.Color = title == "VICTORY" and BLUE or (title == "DEFEAT" and RED or YELLOW)
		resScore.Text = ("%d – %d"):format(you, foe)
		resNext.Text = "NEXT MATCH IN " .. fmt((state:GetAttribute("HpResultsEndAt") or now()) - now())
		pointL.Text = ""
		script:SetAttribute("HardpointHUDState", "results")
		return
	end
	results.Visible = false
	status.Visible = true
	local warm = phase == "warmup"
	pointL.Text = warm and ("P1 IN " .. fmt(remaining)) or ("P%d · %s"):format(idx, fmt(remaining))
	if warm then
		status.Text, status.TextColor3 = "GET READY", Color3.new(1, 1, 1)
	elseif rel == "you" then
		status.Text, status.TextColor3 = "SECURED · +1 / s", BLUE_T
	elseif rel == "foe" then
		status.Text, status.TextColor3 = "ENEMY HAS THE POINT", RED_T
	elseif rel == "C" then
		status.Text, status.TextColor3 = "CONTESTED", YELLOW
	else
		status.Text, status.TextColor3 = "POINT OPEN", Color3.new(1, 1, 1)
	end
	local showNext = (not warm) and state:GetAttribute("HpShowNext") == true
	nextL.Visible = showNext
	if showNext then
		local ni = tonumber(state:GetAttribute("HpNextIndex")) or 1
		nextL.Text = ("NEXT: P%d %s IN %s"):format(ni, points[ni] and string.upper(points[ni].name) or "", fmt(remaining))
	end

	-- marker
	local p = points[warm and 1 or idx]
	marker.Visible = p ~= nil
	if p then
		local blink = rel == "C" and (math.floor(os.clock() * 4) % 2 == 1)
		local col = warm and Color3.fromRGB(201, 206, 216) or (rel == "you" and BLUE or (rel == "foe" and RED or (rel == "C" and YELLOW or Color3.new(1, 1, 1))))
		mLabel.Text = warm and ("LOCKED " .. fmt(remaining)) or (rel == "you" and "DEFEND" or (rel == "C" and "CONTESTED" or "CAPTURE"))
		mLabel.TextColor3 = (rel == "you" and BLUE_T) or (rel == "foe" and RED_T) or (rel == "C" and YELLOW) or Color3.new(1, 1, 1)
		diaStroke.Color = col
		diaStroke.Transparency = blink and 0.6 or 0
		diaNum.Text = tostring(warm and 1 or idx)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local inside = H and H.inPoint(hrp.Position, p.centre)
			mDist.Text = (inside and not warm) and "ON POINT" or (math.floor((hrp.Position - p.centre).Magnitude + 0.5) .. " studs")
		end
		local sp, onScreen = cam:WorldToViewportPoint(p.centre + Vector3.new(0, 34, 0))
		local x, y, edge = sp.X, sp.Y, false
		if sp.Z < 0 then x, y, edge = vp.X - x, vp.Y * 0.85, true end
		local inset = gui.AbsolutePosition
		if not onScreen or sp.Z < 0 then edge = true end
		x = math.clamp(x, 70, vp.X - 70)
		y = math.clamp(y, 150, vp.Y - 40)
		-- v1.1 (see the header): x / y are viewport (screen) pixels; AbsolutePosition is GuiInset pixels higher
		local fix = script:GetAttribute("HardpointHUDMarkerFix") ~= false
		if fix then
			local gi = GuiService:GetGuiInset()
			inset = inset + gi
			if sp.Z < 0 then
				x = (x < vp.X / 2) and 70 or (vp.X - 70)
				y = vp.Y * 0.5
			end
			y = math.max(y, 150 + gi.Y) -- the 1.0 top limit as it showed (150 under the top bar)
			local left = card.AbsolutePosition.X + card.AbsoluteSize.X
			if x - 60 < left then
				local low = nextL.Visible and nextL or status
				y = math.max(y, low.AbsolutePosition.Y + gi.Y + low.AbsoluteSize.Y + 6 + 74)
				local kfg = script:GetAttribute("HardpointHUDMarkerFeedGap") ~= false and gui.Parent:FindFirstChild("KillFeed") -- v1.2
				local lines = kfg and kfg.Enabled and kfg:FindFirstChild("Lines")
				if lines and lines.AbsoluteSize.Y > 1 then
					y = math.max(y, lines.AbsolutePosition.Y + gi.Y + lines.AbsoluteSize.Y + 6 + 74)
				end
			end
		end
		marker.Position = UDim2.fromOffset(x - inset.X, y - inset.Y)
		marker.Size = edge and UDim2.fromOffset(100, 62) or UDim2.fromOffset(120, 74)
		if compassOn and edge then marker.Visible = false end -- v1.4: the compass shows the way; 3D marker only on screen
		if script:GetAttribute("HardpointHUDMarkerV3Enabled") ~= false then markerV3(cam, vp, p, warm) else mv3Off() end -- v1.7
	end
	-- v1.4: the compass
	if compassOn then
		local t = os.clock()
		local dt = math.clamp(t - cmpLastT, 0, 0.1)
		cmpLastT = t
		local c1, c2 = drawCompass(dt, cam, vp, idx, warm, rel, remaining, showNext)
		local cp, cs = cmp.Position, cmp.Size
		cmpUnder.Visible = true
		cmpUnder.Position, cmpUnder.Size = UDim2.fromOffset(cp.X.Offset, cp.Y.Offset + cs.Y.Offset + 1), UDim2.fromOffset(cs.X.Offset, 14)
		curDist.Visible = c1.f.Visible
		curDist.Text = c1.sub.Text
		curDist.Position, curDist.Size = UDim2.fromOffset(c1.x or 0, 0), UDim2.fromOffset(60, 14)
		nextCount.Visible = c2.f.Visible
		nextCount.Text = "NEXT " .. fmt(remaining)
		nextCount.Position, nextCount.Size = UDim2.fromOffset(c2.x or 0, 0), UDim2.fromOffset(70, 14)
	else
		cmp.Visible, cmpUnder.Visible = false, false
	end
	script:SetAttribute("HardpointHUDState", rel)
end)
