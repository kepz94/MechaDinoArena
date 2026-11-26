-- eggloader_patch2 (EggLoader 1.9, Load Screen v1.0 Tasks 1-3): look A, one screen per trip, status words.
local PAIRS = {
{[=====[VERSION = "1.8" -- v1.8 the baby has one mouth]=====], [=====[VERSION = "1.8" -- v1.8 the baby has one mouth
VERSION = "1.9" -- v1.9 look A, one screen per trip, status words
-- v1.9 (Load Screen v1.0, plan docs/plans/LOAD_SCREEN_v1.0.md, mockup docs/mockups/load_screen_v0.1.html; Kepu 2026-11-26 03:15 "nail
--   down the double loading screen problem that we keep having", 03:27 "make that load screen more professional", 03:37 "just do A.
--   i dont want the hatch to be for the arena loading screen we already have that"; red-team: "Allow the word", "Yes, build it"):
--   * Look A (script attribute EggLoaderLookAEnabled, default true, read per build) on the egg screens only (not the splash, not
--     the Arena / Bots briefing): no grid, pod glass / lid / base or side gauge; "MECHA DINO" over "ARENA" centred at the top, the
--     egg centred on a soft light (its bottom at 66% of the height), a slim bar (56% of the width, at least 260 px, 13 ch from the
--     bottom) with the status word on its left and the % on its right just above it, the tip centred under it. Cracks, rocking,
--     hatch and baby as before; the hatch line (HATCHED! / WELCOME TO THE ...!) shows in the status spot.
--   * One screen per trip (EggLoaderSeamlessEnabled, default true, read at start): on arrival the trip's teleport gui
--     (TeleportService:GetArrivingTeleportGui) is put on screen (PlayerGui, DisplayOrder 101) BEFORE
--     ReplicatedFirst:RemoveDefaultLoadingScreen, so there is no gap; the new screen builds under it with the same % (1.2), the
--     same tip (EggLoaderTipIdx on the travel gui) and a bar that moves on from that % (the time curve starts at it); once its
--     labels' fonts are loaded (ContentProvider:PreloadAsync, at most EggLoaderSwapWait (2) s) the copy is removed in one frame.
--     Diagnostic: player EggLoaderArriveCopy ("kept" / "timeout").
--   * Status words (EggLoaderStatusEnabled, default true, read per frame): the bar follows steps and stops at each step's cap
--     until the step is done: travel SAVING (0.2) -> TRAVELING (0.45); then LOADING (0.6, until game:IsLoaded) -> SPAWNING (0.75,
--     until the character has a root) -> LINEUP STARTING (pre-game lineup / intro) or ALMOST READY (0.95) -> READY (1). Egg
--     screens show the word in the status spot; the Arena / Bots briefing puts it in front of its tip ("JOINING  ·  TIP: ...").
--     Diagnostic: player EggLoaderWaitingFor = the first part of the load rule still failing ("game" / "character" / "inMenu" /
--     "parked" / "noGround" / "menu" / "menuWait", nil once loaded), for live hangs (MDA-598).]=====]},
{[=====[local islandEgg = script:GetAttribute("EggLoaderIslandEggEnabled") ~= false -- v1.5]=====], [=====[local islandEgg = script:GetAttribute("EggLoaderIslandEggEnabled") ~= false -- v1.5
for k, v in pairs({EggLoaderLookAEnabled = true, EggLoaderSeamlessEnabled = true, EggLoaderStatusEnabled = true, EggLoaderSwapWait = 2}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end -- v1.9
end]=====]},
{[=====[ReplicatedFirst:RemoveDefaultLoadingScreen()
local pg = player:WaitForChild("PlayerGui")]=====], [=====[local earlyCopy = nil -- v1.9: the trip's screen, on screen before the default loading screen goes (no gap)
if script:GetAttribute("EggLoaderSeamlessEnabled") ~= false then
	pcall(function() earlyCopy = TeleportService:GetArrivingTeleportGui() end)
	if earlyCopy then
		pcall(function()
			earlyCopy.DisplayOrder = 101
			earlyCopy.Parent = player:WaitForChild("PlayerGui")
		end)
	end
end
ReplicatedFirst:RemoveDefaultLoadingScreen()
local pg = player:WaitForChild("PlayerGui")]=====]},
{[=====[	if chars("TIP: " .. t)]=====], [=====[	if chars((script:GetAttribute("EggLoaderStatusEnabled") ~= false and "LINEUP STARTING  \u{00B7}  " or "") .. "TIP: " .. t)]=====]},
{[=====[	local k = math.floor(t / 4) % #b.d.tips + 1
	if b.tipK ~= k then b.tipK = k b.tip.Text = "TIP: " .. b.d.tips[k] end]=====], [=====[	local k = (math.floor(t / 4) + (s.tipOff or 0)) % #b.d.tips + 1 -- v1.9: + the trip's tip
	local word = script:GetAttribute("EggLoaderStatusEnabled") ~= false and s.statusWord or nil -- v1.9
	local key = k .. "|" .. tostring(word)
	if b.tipK ~= key then
		b.tipK = key
		b.tip.Text = (word and (word .. "  \u{00B7}  ") or "") .. "TIP: " .. b.d.tips[k]
		if s.mode == "travel" then s.gui:SetAttribute("EggLoaderTipIdx", k) end -- v1.9
	end]=====]},
{[=====[local current -- the screen on show]=====], [=====[local arriveTip = nil -- v1.9: the tip index read from the arriving teleport gui
local current -- the screen on show]=====]},
{[=====[	s.tip.Text = TIPS[math.random(1, #TIPS)]]=====], [=====[	s.tipIdx = (mode == "arrive" and tonumber(arriveTip) and TIPS[tonumber(arriveTip)]) and tonumber(arriveTip) or math.random(1, #TIPS) -- v1.9
	s.tip.Text = TIPS[s.tipIdx]
	gui:SetAttribute("EggLoaderTipIdx", s.tipIdx) -- v1.9: the arrive screen keeps it]=====]},
{[=====[	gui.Parent = pg
	return s
end]=====], [=====[	if mode == "arrive" and s.brief and tonumber(arriveTip) then s.tipOff = tonumber(arriveTip) - 1 end -- v1.9: same tip
	if not s.brief and mode ~= "splash" and script:GetAttribute("EggLoaderLookAEnabled") ~= false then -- v1.9: look A
		s.lookA = true
		s.glowA = frame(root, "GlowA", VOLT, 2)
		s.glowA.BackgroundTransparency = 0.5
		round(s.glowA, UDim.new(0.5, 0))
		local glg = Instance.new("UIGradient")
		glg.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 1)})
		glg.Parent = s.glowA
		s.barA = frame(root, "BarA", Color3.new(1, 1, 1), 3)
		s.barA.BackgroundTransparency = 0.9
		round(s.barA, UDim.new(1, 0))
		s.barAFill = frame(s.barA, "Fill", VOLT, 3)
		s.barAFill.Size = UDim2.fromScale(0, 1)
		round(s.barAFill, UDim.new(1, 0))
		s.statusA = silk(root, "StatusA", VOLT, true)
		s.statusA.ZIndex = 3
		s.statusA.TextWrapped = false
		s.statusA.Text = s.caption.Text
		s.pctA = silk(root, "PctA", Color3.new(1, 1, 1), true)
		s.pctA.ZIndex = 3
		s.pctA.TextWrapped = false
		s.pctA.TextXAlignment = Enum.TextXAlignment.Right
		s.pctA.Text = "0%"
		s.grid.Visible, s.tube.Visible, s.pct.Visible, s.caption.Visible = false, false, false, false
		s.glass.Visible, s.lid.Visible, s.base.Visible = false, false, false
		s.tip.TextXAlignment = Enum.TextXAlignment.Center
	end
	gui.Parent = pg
	return s
end]=====]},
{[=====[	if s.brief then layoutBrief(s) end -- v1.3
end]=====], [=====[	if s.lookA then -- v1.9: look A (see the header)
		local topY = math.max(inset + 2 * ch, 9 * ch)
		local tSm, tBg = math.max(2.6 * ch, 10), math.max(7 * ch, 26)
		for _, l in ipairs({s.titleSmall, s.title, s.titleShadow}) do l.TextXAlignment = Enum.TextXAlignment.Center end
		s.titleSmall.Position, s.titleSmall.Size, s.titleSmall.TextSize = UDim2.fromOffset(0, topY), UDim2.new(1, 0, 0, tSm), tSm
		s.title.Position, s.title.Size, s.title.TextSize = UDim2.fromOffset(0, topY + tSm + 0.6 * ch), UDim2.new(1, 0, 0, tBg), tBg
		s.titleShadow.Position, s.titleShadow.Size, s.titleShadow.TextSize = UDim2.fromOffset(0, topY + tSm + 1.1 * ch), UDim2.new(1, 0, 0, tBg), tBg
		-- the egg: the pod box moved so the egg's bottom (pivot, 54.3 ch into the pod) sits at 66% of the height
		local pivotIn = s.wob.Position.Y.Offset
		s.pod.Position = UDim2.fromOffset((W - podW) / 2, 66 * ch - pivotIn)
		s.glowA.AnchorPoint = Vector2.new(0.5, 0.5)
		s.glowA.Position, s.glowA.Size = UDim2.fromOffset(W / 2, 66 * ch), UDim2.fromOffset(34 * ch, 5 * ch)
		-- bar, status, %, tip
		local barW = math.max(math.min(W * 0.56, W - 32), math.min(260, W - 32))
		local barH = math.max(ch, 6)
		local barX, barY = (W - barW) / 2, H - 13 * ch
		s.barA.Position, s.barA.Size = UDim2.fromOffset(barX, barY), UDim2.fromOffset(barW, barH)
		local stS = math.max(2.4 * ch, 12)
		s.statusA.Position, s.statusA.Size, s.statusA.TextSize = UDim2.fromOffset(barX, barY - 1.2 * ch - stS), UDim2.fromOffset(barW * 0.7, stS), stS
		s.pctA.Position, s.pctA.Size, s.pctA.TextSize = UDim2.fromOffset(barX + barW * 0.7, barY - 1.2 * ch - stS), UDim2.fromOffset(barW * 0.3, stS), stS
		local tS = math.max(2.2 * ch, 12)
		s.tip.Position, s.tip.Size, s.tip.TextSize = UDim2.fromOffset(W * 0.1, barY + barH + 2.2 * ch), UDim2.fromOffset(W * 0.8, tS * 1.35 * 2), tS
	end
	if s.brief then layoutBrief(s) end -- v1.3
end]=====]},
{[=====[local function finish(s)]=====], [=====[-- v1.9: status words (see the header)
local function waitWhy(s) -- the first part of the load rule still failing, nil once loaded
	if isLoaded(s) then return nil end
	if not game:IsLoaded() then return "game" end
	local c = player.Character
	if not c then return "character" end
	local inMenu = player:GetAttribute("InMenu")
	if s.mode == "play" or (s.mode == "arrive" and inMenu == false) then
		if not c:FindFirstChild("HumanoidRootPart") then return "character" end
		if inMenu ~= false then return "inMenu" end
		if (tonumber(player:GetAttribute("ModeParkSlot")) or 0) ~= 0 then return "parked" end
		return "noGround"
	end
	if inMenu == nil then return "menuWait" end
	return "menu"
end
local function stepNow(s) -- -> word, cap, why
	if s.mode == "travel" then
		if player:GetAttribute("HubTripState") == "saving" or player:GetAttribute("ModeLastResult") == "saving" then return "SAVING", 0.2, "travel" end
		return "TRAVELING", 0.45, "travel"
	end
	local why = waitWhy(s)
	if why == nil then return "READY", 1, nil end
	if why == "game" then return "LOADING", 0.6, why end
	local c = player.Character
	if why == "character" or not (c and c:FindFirstChild("HumanoidRootPart")) then return "SPAWNING", 0.75, why end
	local pr = game:GetService("ReplicatedStorage"):FindFirstChild("Practice")
	local pgPhase = pr and pr:GetAttribute("PgPhase")
	if pgPhase == "lineup" or pgPhase == "intro" then return "LINEUP STARTING", 0.95, why end
	return "ALMOST READY", 0.95, why
end

local function finish(s)]=====]},
{[=====[	task.wait(0.7)
	setState("hatched")]=====], [=====[	if s.lookA then s.statusA.Text = s.caption.Text end -- v1.9
	task.wait(0.7)
	setState("hatched")]=====]},
{[=====[		local timeCurve = 0.95 * (1 - math.exp(-t / 6))
		local assetPart = 0
		if s.mode ~= "travel" and s.maxQueue > 0 then assetPart = 0.95 * (1 - q / s.maxQueue) end
		local target = math.min(0.95, math.max(timeCurve, assetPart))]=====], [=====[		local timeCurve = 0.95 * (1 - math.exp(-t / 6))
		local stOn = script:GetAttribute("EggLoaderStatusEnabled") ~= false -- v1.9
		if stOn and s.p0 then timeCurve = s.p0 + (0.95 - s.p0) * (1 - math.exp(-t / 6)) end -- v1.9: moves on from the carried %
		local assetPart = 0
		if s.mode ~= "travel" and s.maxQueue > 0 then assetPart = 0.95 * (1 - q / s.maxQueue) end
		local target = math.min(0.95, math.max(timeCurve, assetPart))
		if stOn then -- v1.9: steps
			local word, cap, why = stepNow(s)
			target = math.min(target, cap)
			s.statusWord = word
			if s.lookA then s.statusA.Text = word end
			if player:GetAttribute("EggLoaderWaitingFor") ~= why then player:SetAttribute("EggLoaderWaitingFor", why) end
		end]=====]},
{[=====[		s.fill.Size = UDim2.fromScale(1, s.p)
		s.pct.Text = math.floor(s.p * 100) .. "%"]=====], [=====[		s.fill.Size = UDim2.fromScale(1, s.p)
		s.pct.Text = math.floor(s.p * 100) .. "%"
		if s.lookA then s.barAFill.Size = UDim2.fromScale(s.p, 1) s.pctA.Text = s.pct.Text end -- v1.9]=====]},
{[=====[local arriving
pcall(function() arriving = TeleportService:GetArrivingTeleportGui() end)
local arrivedFrom = arriving and arriving:GetAttribute("EggLoaderTarget")
local carried = arriving and tonumber(arriving:GetAttribute("EggLoaderCarry")) -- v1.2
briefSquad = arriving and arriving:GetAttribute("EggLoaderSquad") -- v1.3
if arriving then arriving:Destroy() end]=====], [=====[local arriving = earlyCopy -- v1.9: already on screen
if not arriving then pcall(function() arriving = TeleportService:GetArrivingTeleportGui() end) end
local arrivedFrom = arriving and arriving:GetAttribute("EggLoaderTarget")
local carried = arriving and tonumber(arriving:GetAttribute("EggLoaderCarry")) -- v1.2
briefSquad = arriving and arriving:GetAttribute("EggLoaderSquad") -- v1.3
arriveTip = arriving and arriving:GetAttribute("EggLoaderTipIdx") -- v1.9
local keepCopy = earlyCopy ~= nil and arriving == earlyCopy and (arrivedFrom == "Arena" or arrivedFrom == "Sandbox" or arrivedFrom == "Bots"
	or arrivedFrom == "Island") -- v1.9
if arriving and not keepCopy then arriving:Destroy() end]=====]},
{[=====[		s.p = math.clamp(carried or ARRIVE_FLOOR, 0, 0.95)
		player:SetAttribute("EggLoaderArriveFrom", s.p)
	end]=====], [=====[		s.p = math.clamp(carried or ARRIVE_FLOOR, 0, 0.95)
		player:SetAttribute("EggLoaderArriveFrom", s.p)
	end
	if s then s.p0 = s.p end -- v1.9: the bar moves on from here
	if keepCopy and s then -- v1.9: swap the trip's screen for this one in one frame, once this one is drawn
		local copy = arriving
		task.spawn(function()
			local labels = {}
			for _, d in ipairs(s.gui:GetDescendants()) do if d:IsA("TextLabel") then table.insert(labels, d) end end
			local done = false
			task.spawn(function() pcall(function() ContentProvider:PreloadAsync(labels) end) done = true end)
			local t0 = os.clock()
			local maxWait = tonumber(script:GetAttribute("EggLoaderSwapWait")) or 2
			while not done and os.clock() - t0 < maxWait do task.wait() end
			RunService.RenderStepped:Wait()
			if copy.Parent then copy:Destroy() end
			player:SetAttribute("EggLoaderArriveCopy", done and "kept" or "timeout")
		end)
	end]=====]},
}
local s = sc.Source
for k, pr in ipairs(PAIRS) do
	local a, b = string.find(s, pr[1], 1, true)
	assert(a, "miss " .. k .. ": " .. pr[1]:sub(1, 60))
	assert(not string.find(s, pr[1], b + 1, true), "dup " .. k)
	s = s:sub(1, a - 1) .. pr[2] .. s:sub(b + 1)
end
sc.Source = s
local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
return #s .. " " .. h
