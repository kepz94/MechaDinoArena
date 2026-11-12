-- PortalHUD v1.0 (Mecha Dino Arena) — the island hub's screen parts: the safe-area banner, the portal countdown, the travel
-- screen and the portal toasts (LocalScript, StarterPlayerScripts, PC and phone; MDA-459, plan docs/plans/ISLAND_HUB_v1.0.md
-- Task 8, ADR-011, mockup docs/mockups/island_portals_v0.1.html "Try the portal flow"; Kepu 2026-11-11 picks "C · Portal
-- Islet", leader walks in and the whole squad goes, 3 s guard both ways).
-- Reads (HubServer 1.0): ReplicatedStorage HubLive; character HubInZone, HubGuardUntil, HubSafe; player HubTripMode,
--   HubTripEndsAt, HubTripLeader, HubTripMembers, HubTripState, HubLastResult / HubLastAt, HubLastLeader; InMenu.
-- ScreenGui "PortalHUD" (DisplayOrder 20, IgnoreGuiInset, ResetOnSpawn false). Sizes scale with u = clamp(screen height / 720,
--   0.55, 1.3). Fonts: GothamBlack / FredokaOne (FontSwap 1.0 turns the short ones Silkscreen).
--   * Banner (top centre, max(7% of the height, 100 px) down, under the SKILLS / SQUAD pills; only while HubLive and not InMenu):
--       on the islet / bridge -> "SAFE AREA" (cyan rgb(95, 224, 200)) / "NO FIGHTING HERE";
--       guard running -> "FIGHTING ON" (red rgb(255, 106, 128)) / "PROTECTED n" (n = whole seconds left, rounded up);
--       guard just ended -> "FIGHTING ON" / "PLAYERS CAN HIT YOU" for 2 s; then hidden.
--   * Countdown panel (centre, 44% wide, at most 520 px) while HubTripState == "count": the mode name (ARENA orange
--       rgb(255, 155, 46) / HARDPOINT VS BOTS yellow rgb(255, 200, 50)), one line, the seconds left (rounded up), one chip per
--       traveller (HubTripMembers; ★ after the leader HubTripLeader); then "STEP OUT TO CANCEL" for the one who walked in, or
--       "<LEADER> PICKED THIS · YOUR SQUAD GOES TOGETHER" and a red LEAVE SQUAD button (-> DinoSquadRequest "leave") for the
--       others. HubTripState "saving" -> the same panel reads "SAVING YOUR LOADOUT" over "...".
--   * Travel: HubTripState "teleporting" -> ReplicatedFirst.EggLoader.Show(target) ("Arena" / "Sandbox") and
--       TeleportService:SetTeleportGui(its gui), like MainMenu 1.1's trips; no EggLoader -> a full-screen "TRAVELING TO <MODE>".
--       "failed" -> EggLoader.Hide.
--   * Toast (bottom centre, 2.6 s) on HubLastAt: notLeader -> "ONLY <LEADER> ★ CAN START A MODE" (no leader name -> "ONLY THE
--       SQUAD LEADER CAN START A MODE"); failed -> "COULDN'T TRAVEL · TRY AGAIN"; studio -> "TRAVEL WORKS IN THE LIVE GAME";
--       cancelled -> "TRIP CANCELLED".
-- Switch: script attribute PortalHUDEnabled (default true, read per frame; false = nothing shown).
-- Diagnostics: player PortalHUDVersion, PortalHUDBanner ("safe" / "guard" / "fight" / "hidden"), PortalHUDPanel ("count" /
--   "saving" / "hidden"), PortalHUDToast (last toast text), PortalHUDTravel ("egg" / "screen" / "").
-- v1.1 (Kepu 2026-11-11 18:48: a portal "goes straight to the loading", HubServer 1.1 / HubRules 1.1 TRIP_TIME 0): the travel
--   loader (EggLoader, or the full-screen fallback "TRAVELING TO <MODE>") comes up at "saving" as well as "teleporting", so
--   walking into a portal goes straight to the loading screen; the countdown panel only shows while a "count" phase exists.
--   Switch: script attribute PortalHUDLoadOnSaveEnabled (default true, read per change; false = 1.0).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.1"
local player = Players.LocalPlayer
player:SetAttribute("PortalHUDVersion", VERSION)
if script:GetAttribute("PortalHUDEnabled") == nil then script:SetAttribute("PortalHUDEnabled", true) end
if script:GetAttribute("PortalHUDLoadOnSaveEnabled") == nil then script:SetAttribute("PortalHUDLoadOnSaveEnabled", true) end -- v1.1
local function loading(st) -- v1.1
	return st == "teleporting" or (st == "saving" and script:GetAttribute("PortalHUDLoadOnSaveEnabled") ~= false)
end

local PANEL = Color3.fromRGB(20, 20, 26)
local CYAN = Color3.fromRGB(95, 224, 200)
local RED = Color3.fromRGB(255, 106, 128)
local LEAVE_RED = Color3.fromRGB(224, 40, 74)
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(170, 180, 196)
local GREEN = Color3.fromRGB(120, 200, 80)
local MODES = {
	arena = {name = "ARENA", sub = "Hardpoint · players only", color = Color3.fromRGB(255, 155, 46), egg = "Arena"},
	bots = {name = "HARDPOINT VS BOTS", sub = "5v5 · your squad vs bots", color = Color3.fromRGB(255, 200, 50), egg = "Sandbox"},
}
local TOASTS = {failed = "COULDN'T TRAVEL · TRY AGAIN", studio = "TRAVEL WORKS IN THE LIVE GAME", cancelled = "TRIP CANCELLED"}

local function now() return workspace:GetServerTimeNow() end
local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r or 8) c.Parent = p return c end
local function stroke(p, col, th) local s = Instance.new("UIStroke") s.Color = col s.Thickness = th or 2 s.Parent = p return s end
local function label(parent, name, font, col)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Font = font
	t.TextColor3 = col
	t.Text = ""
	t.Parent = parent
	return t
end

local gui = Instance.new("ScreenGui")
gui.Name = "PortalHUD"
gui.DisplayOrder = 20
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- banner
local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.BackgroundColor3 = PANEL
banner.BackgroundTransparency = 0.16
banner.Visible = false
banner.Parent = gui
local bannerCorner = corner(banner)
local bannerStroke = stroke(banner, CYAN, 2)
local bTitle = label(banner, "Title", Enum.Font.GothamBlack, CYAN)
local bLine = label(banner, "Line", Enum.Font.GothamBlack, WHITE)

-- countdown panel
local panel = Instance.new("Frame")
panel.Name = "Countdown"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = PANEL
panel.BackgroundTransparency = 0.12
panel.Visible = false
panel.Parent = gui
local panelCorner = corner(panel, 10)
local panelStroke = stroke(panel, WHITE, 2)
local pList = Instance.new("UIListLayout")
pList.HorizontalAlignment = Enum.HorizontalAlignment.Center
pList.SortOrder = Enum.SortOrder.LayoutOrder
pList.Parent = panel
local pPad = Instance.new("UIPadding")
pPad.Parent = panel
local pTitle = label(panel, "Title", Enum.Font.FredokaOne, WHITE) pTitle.LayoutOrder = 1
local pSub = label(panel, "Sub", Enum.Font.GothamBold, MUTED) pSub.LayoutOrder = 2
local pCount = label(panel, "Count", Enum.Font.FredokaOne, WHITE) pCount.LayoutOrder = 3
local chips = Instance.new("Frame")
chips.Name = "Mates"
chips.BackgroundTransparency = 1
chips.LayoutOrder = 4
chips.Parent = panel
local cList = Instance.new("UIListLayout")
cList.FillDirection = Enum.FillDirection.Horizontal
cList.HorizontalAlignment = Enum.HorizontalAlignment.Center
cList.Wraps = true
cList.Parent = chips
local pHint = label(panel, "Hint", Enum.Font.GothamBlack, MUTED) pHint.LayoutOrder = 6
pHint.TextWrapped = true
local leaveB = Instance.new("TextButton")
leaveB.Name = "LeaveSquad"
leaveB.Text = "LEAVE SQUAD"
leaveB.Font = Enum.Font.GothamBlack
leaveB.TextColor3 = WHITE
leaveB.BackgroundColor3 = LEAVE_RED
leaveB.AutoButtonColor = true
leaveB.LayoutOrder = 5
leaveB.Parent = panel
local leaveCorner = corner(leaveB)
leaveB.Activated:Connect(function()
	local r = ReplicatedStorage:FindFirstChild("DinoSquadRequest")
	if r then r:FireServer("leave") end
end)

-- travel screen (no EggLoader)
local travel = Instance.new("Frame")
travel.Name = "Travel"
travel.Size = UDim2.fromScale(1, 1)
travel.BackgroundColor3 = Color3.fromRGB(14, 18, 24)
travel.Visible = false
travel.ZIndex = 10
travel.Parent = gui
local tText = label(travel, "Text", Enum.Font.FredokaOne, WHITE)
tText.Size = UDim2.fromScale(1, 1)
tText.ZIndex = 11

-- toast
local toast = label(gui, "Toast", Enum.Font.GothamBlack, WHITE)
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.BackgroundColor3 = PANEL
toast.BackgroundTransparency = 0.12
toast.AutomaticSize = Enum.AutomaticSize.X
toast.Visible = false
local toastCorner = corner(toast)
stroke(toast, Color3.fromRGB(255, 200, 50), 2)
local toastPad = Instance.new("UIPadding") toastPad.Parent = toast
local toastUntil = 0

local function showToast(text)
	toast.Text = text
	toastUntil = os.clock() + 2.6
	player:SetAttribute("PortalHUDToast", text)
end
player:GetAttributeChangedSignal("HubLastAt"):Connect(function()
	local r = player:GetAttribute("HubLastResult")
	if r == "notLeader" then
		local who = player:GetAttribute("HubLastLeader")
		showToast((type(who) == "string" and who ~= "") and ("ONLY " .. string.upper(who) .. " ★ CAN START A MODE")
			or "ONLY THE SQUAD LEADER CAN START A MODE")
	elseif TOASTS[r] then
		showToast(TOASTS[r])
	end
end)

-- travel loader
local eggShown = false
local function travelState(st, mode)
	local loader = game:GetService("ReplicatedFirst"):FindFirstChild("EggLoader")
	if loading(st) and not eggShown then -- v1.1: + saving
		local showFn = loader and loader:FindFirstChild("Show")
		if showFn then
			eggShown = true
			local ok, g = pcall(function() return showFn:Invoke((MODES[mode] or MODES.arena).egg) end)
			if ok and g then pcall(function() game:GetService("TeleportService"):SetTeleportGui(g) end) end
			player:SetAttribute("PortalHUDTravel", "egg")
		else
			player:SetAttribute("PortalHUDTravel", "screen")
		end
	elseif not loading(st) and eggShown then -- v1.1
		eggShown = false
		local hideFn = loader and loader:FindFirstChild("Hide")
		if hideFn then pcall(function() hideFn:Invoke() end) end
		player:SetAttribute("PortalHUDTravel", "")
	end
end
player:GetAttributeChangedSignal("HubTripState"):Connect(function()
	travelState(player:GetAttribute("HubTripState"), player:GetAttribute("HubTripMode"))
end)

-- chips
local chipKey = ""
local function drawChips(u, members, leader)
	local key = members .. "|" .. leader
	if key == chipKey then return end
	chipKey = key
	for _, c in ipairs(chips:GetChildren()) do
		if c:IsA("TextLabel") then c:Destroy() end
	end
	if members == "" or leader == "" then return end
	for name in string.gmatch(members, "[^,]+") do
		local c = label(chips, "Chip", Enum.Font.GothamBlack, WHITE)
		c.Text = (name == player.Name and "YOU" or string.upper(name)) .. (name == leader and " ★" or "")
		c.BackgroundColor3 = Color3.fromRGB(40, 46, 58)
		c.BackgroundTransparency = 0
		c.AutomaticSize = Enum.AutomaticSize.X
		c.TextSize = math.floor(13 * u)
		c.Size = UDim2.fromOffset(0, math.floor(13 * u) + math.floor(10 * u))
		corner(c, 6)
		stroke(c, GREEN, 1.5)
		local p = Instance.new("UIPadding") p.PaddingLeft = UDim.new(0, 8) p.PaddingRight = UDim.new(0, 8) p.Parent = c
	end
end

local lastGuardEnd = 0
local lastU = -1
RunService.RenderStepped:Connect(function()
	local on = script:GetAttribute("PortalHUDEnabled") ~= false
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local u = math.clamp(vp.Y / 720, 0.55, 1.3)
	local t = now()
	local menu = player:GetAttribute("InMenu") == true
	local live = on and ReplicatedStorage:GetAttribute("HubLive") == true and not menu
	local c = player.Character
	-- banner
	local mode = "hidden"
	if live and c then
		local guard = tonumber(c:GetAttribute("HubGuardUntil")) or 0
		if c:GetAttribute("HubInZone") == true then
			mode = "safe"
		elseif guard > t then
			mode = "guard"
			lastGuardEnd = guard
		elseif lastGuardEnd > 0 and t - lastGuardEnd < 2 then
			mode = "fight"
		end
	end
	banner.Visible = mode ~= "hidden"
	if player:GetAttribute("PortalHUDBanner") ~= mode then player:SetAttribute("PortalHUDBanner", mode) end
	if u ~= lastU then -- sizes only when the screen changes (FontSwap re-fits a TextSize a script sets)
		lastU = u
		chipKey = ""
		local ts, ls = math.floor(22 * u + 0.5), math.floor(13 * u + 0.5)
		banner.Size = UDim2.fromOffset(math.floor(260 * u), ts + ls + math.floor(22 * u))
		banner.Position = UDim2.new(0.5, 0, 0, math.floor(math.max(vp.Y * 0.07, 100))) -- under the SKILLS / SQUAD pills
		bannerCorner.CornerRadius = UDim.new(0, math.floor(8 * u))
		bTitle.TextSize, bLine.TextSize = ts, ls
		bTitle.Size, bTitle.Position = UDim2.new(1, 0, 0, ts), UDim2.fromOffset(0, math.floor(8 * u))
		bLine.Size, bLine.Position = UDim2.new(1, 0, 0, ls), UDim2.fromOffset(0, math.floor(8 * u) + ts + math.floor(4 * u))
		local titleS, subS, countS, chipS, hintS = math.floor(30 * u), math.floor(14 * u), math.floor(72 * u), math.floor(13 * u),
			math.floor(12 * u)
		panel.AutomaticSize = Enum.AutomaticSize.Y
		panel.Position = UDim2.fromScale(0.5, 0.45)
		panelCorner.CornerRadius = UDim.new(0, math.floor(10 * u))
		pPad.PaddingTop, pPad.PaddingBottom = UDim.new(0, math.floor(14 * u)), UDim.new(0, math.floor(14 * u))
		pPad.PaddingLeft, pPad.PaddingRight = UDim.new(0, math.floor(12 * u)), UDim.new(0, math.floor(12 * u))
		pList.Padding = UDim.new(0, math.floor(6 * u))
		pTitle.TextSize, pTitle.Size = titleS, UDim2.new(1, 0, 0, titleS)
		pSub.TextSize, pSub.Size = subS, UDim2.new(1, 0, 0, subS)
		pCount.TextSize, pCount.Size = countS, UDim2.new(1, 0, 0, countS)
		cList.Padding = UDim.new(0, math.floor(6 * u))
		chips.Size = UDim2.new(1, 0, 0, chipS + math.floor(10 * u))
		leaveB.TextSize = math.floor(14 * u)
		leaveB.Size = UDim2.fromOffset(math.floor(150 * u), math.max(36, math.floor(34 * u)))
		leaveCorner.CornerRadius = UDim.new(0, math.floor(8 * u))
		pHint.TextSize, pHint.Size = hintS, UDim2.new(1, 0, 0, hintS * 2 + 4)
		tText.TextSize = math.floor(34 * u)
		local s2 = math.floor(15 * u)
		toast.TextSize = s2
		toast.Size = UDim2.fromOffset(0, s2 + math.floor(16 * u))
		toast.Position = UDim2.new(0.5, 0, 0.78, 0)
		toastCorner.CornerRadius = UDim.new(0, math.floor(8 * u))
		toastPad.PaddingLeft, toastPad.PaddingRight = UDim.new(0, math.floor(14 * u)), UDim.new(0, math.floor(14 * u))
	end
	if banner.Visible then
		local col = mode == "safe" and CYAN or RED
		bTitle.TextColor3, bannerStroke.Color = col, col
		if mode == "safe" then
			bTitle.Text, bLine.Text = "SAFE AREA", "NO FIGHTING HERE"
		elseif mode == "guard" then
			bTitle.Text, bLine.Text = "FIGHTING ON", "PROTECTED " .. math.max(1, math.ceil(lastGuardEnd - t))
		else
			bTitle.Text, bLine.Text = "FIGHTING ON", "PLAYERS CAN HIT YOU"
		end
	end
	-- countdown / saving
	local st = player:GetAttribute("HubTripState")
	local md = MODES[player:GetAttribute("HubTripMode")]
	local pmode = (on and md and (st == "count" or (st == "saving" and not loading(st)))) and st or "hidden" -- v1.1
	panel.Visible = pmode ~= "hidden"
	if player:GetAttribute("PortalHUDPanel") ~= pmode then player:SetAttribute("PortalHUDPanel", pmode) end
	if panel.Visible then
		local w = math.min(vp.X * 0.44, 520 * u)
		w = math.max(w, math.min(vp.X - 32, 300))
		local leader = player:GetAttribute("HubTripLeader") or ""
		local members = player:GetAttribute("HubTripMembers") or ""
		local mine = leader == "" or leader == player.Name
		if panel.Size.X.Offset ~= math.floor(w) then panel.Size = UDim2.fromOffset(math.floor(w), 0) end
		panelStroke.Color = md.color
		pTitle.Text, pTitle.TextColor3 = md.name, md.color
		pSub.Text = st == "saving" and "SAVING YOUR LOADOUT" or md.sub
		if st == "saving" then
			pCount.Text = "..."
		else
			local left = math.max(0, math.ceil((tonumber(player:GetAttribute("HubTripEndsAt")) or t) - t))
			pCount.Text = tostring(left)
		end
		drawChips(u, members, leader)
		chips.Visible = leader ~= ""
		leaveB.Visible = not mine and st == "count"
		pHint.Text = mine and "STEP OUT TO CANCEL" or (string.upper(leader) .. " PICKED THIS · YOUR SQUAD GOES TOGETHER")
		pHint.Visible = st == "count"
	end
	-- travel screen (no EggLoader)
	travel.Visible = on and loading(st) and player:GetAttribute("PortalHUDTravel") == "screen" and md ~= nil -- v1.1
	if travel.Visible then
		tText.Text = "TRAVELING TO\n" .. md.name
	end
	-- toast
	toast.Visible = on and os.clock() < toastUntil
end)
