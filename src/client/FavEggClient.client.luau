-- FavEggClient v1.0 (Mecha Dino Arena) — the Favorite Egg on the player's side (LocalScript, StarterPlayerScripts).
-- Plan docs/plans/FAVORITE_EGG_v1.0.md Task 5 (MDA-611), mockup docs/mockups/favorite_egg_v0.1.html option "B · Prize reel"
-- (Kepu 2026-11-26 pick). Works with Workspace.FavEggStand (FavEggStandServer 1.0) and ReplicatedStorage.FavEggRequest (FavEggServer 1.0).
-- Stand, per player (local only): the timer billboard's Clock counts down to player FavEggEndsAt (server time) as HH:MM:SS
--   ("48:00:00" before the first "seen"); the egg bobs (1 stud, 2.4 s; still with Reduced Motion). State "rolled": the egg and spots
--   grey, the prompt reads "ROLLED ✓" / "Thanks for the favorite!". State "expired": the stand's parts, sign and prompt hidden.
--   While FavEggState is "unseen" and the character is within FavEggSeenNear (55) studs of FavEggFront, FavEggRequest("seen") is
--   sent (at most every 2 s).
-- Prompt (FREE ROLL): "rolled" -> toast "YOU ALREADY ROLLED · THANKS!"; "open" -> AvatarEditorService:PromptSetFavorite(
--   FavEggFavoriteId (game.PlaceId), Enum.AvatarItemType.Asset, true) and waits for PromptSetFavoriteCompleted: Success ->
--   FavEggRequest("favorited") -> "ok" -> the reveal; anything else -> toast "FAVORITE TO ROLL THE EGG". Server refusals get short
--   toasts ("GET CLOSER TO THE EGG", "THE FREE EGG HAS GONE", "LOADING, TRY AGAIN", "TRY AGAIN").
-- Reveal (ScreenGui "FavEgg", DisplayOrder 70, IgnoreGuiInset; design 1000 x 460 scaled by a UIScale to the screen):
--   * a dark backdrop; the reel: the server's 40 cards (150 x 180: a 90 px swatch, the name, "KIND · TIER", a 4 px outline in the
--     tier colour: COMMON rgb(159,179,200), RARE rgb(74,168,255), EPIC rgb(184,107,255), LEGENDARY rgb(255,176,46), DINO
--     rgb(70,224,138)) slides left and eases out (Quart) over FavEggReelTime (4) s onto the prize under a yellow marker (0.3 s with
--     Reduced Motion);
--   * then the prize: 8 slow-turning rays in the tier colour, the kind chip, a 150 px swatch, the name (Silkscreen 36), the tier,
--     a hint line, and the buttons: trails "EQUIP" (DinoTrailRequest "equip" once the trail is owned) + "NICE"; everything else
--     "NICE" only, with the hint ("EQUIP IT IN THE LAB", "ADDED TO YOUR EMOTE WHEEL", "PICK IT WITH THE DINO BUTTON · ALL PARTS
--     MAXED", "ADDED TO YOUR SKILL POINTS"). Buttons 200 x 64 design (>= 44 px on phones). NICE / EQUIP close it with the toast
--     "<NAME> UNLOCKED".
-- Swatches: skins = UniversalSkins sw stripes; trails = TrailCatalog sw stripes; emotes = the emote's word on dark; dinos = green
--   with the dino name; points = yellow "+10".
-- Switches (script attributes): FavEggClientEnabled (true, read at start), FavEggReelTime (4), FavEggSeenNear (55),
--   FavEggFavoriteId (unset = game.PlaceId), FavEggTestFakeFavorite (false; Studio only: skip Roblox's window and answer Success).
-- Diagnostics: FavEggClientVersion, FavEggFavResult (the last PromptSetFavoriteCompleted result), FavEggRevealShown (count).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local AvatarEditorService = game:GetService("AvatarEditorService")

local VERSION = "1.0"
script:SetAttribute("FavEggClientVersion", VERSION)
for k, v in pairs({FavEggClientEnabled = true, FavEggReelTime = 4, FavEggSeenNear = 55, FavEggTestFakeFavorite = false}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
if script:GetAttribute("FavEggClientEnabled") == false then return end
local function A(k, d) return tonumber(script:GetAttribute(k)) or d end
local player = Players.LocalPlayer
local SILK = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold)
local TIER = {common = {"COMMON", Color3.fromRGB(159, 179, 200)}, rare = {"RARE", Color3.fromRGB(74, 168, 255)},
	epic = {"EPIC", Color3.fromRGB(184, 107, 255)}, legend = {"LEGENDARY", Color3.fromRGB(255, 176, 46)},
	dino = {"DINO", Color3.fromRGB(70, 224, 138)}}
local YELLOW, LIP, INK = Color3.fromRGB(255, 200, 50), Color3.fromRGB(184, 138, 18), Color3.fromRGB(27, 20, 6)

local function req(folder, name)
	local f = ReplicatedStorage:FindFirstChild(folder)
	local m = f and f:FindFirstChild(name)
	local ok, r = pcall(function() return m and require(m) end)
	return ok and r or nil
end
local US, EC, TC

local function reducedMotion()
	local ok, v = pcall(function() return GuiService.ReducedMotionEnabled end)
	return ok and v == true
end

-- ---------- UI helpers ----------
local function corner(o, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = o return c end
local function stroke(o, col, t) local s = Instance.new("UIStroke") s.Color = col s.Thickness = t s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Parent = o return s end
local function frame(parent, name, x, y, w, h, col)
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = col or Color3.new()
	f.BackgroundTransparency = col and 0 or 1
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end
local function text(parent, name, x, y, w, h, t, size, col, align)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(w, h)
	l.FontFace = SILK
	l:SetAttribute("FontSwap", "keep")
	l.TextSize = size
	l.TextColor3 = col
	l.TextWrapped = true
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.Text = t
	l.Parent = parent
	return l
end
local function stripes(parent, cols)
	for i, c in ipairs(cols) do
		local s = Instance.new("Frame")
		s.BorderSizePixel = 0
		s.BackgroundColor3 = c
		s.Position = UDim2.fromScale((i - 1) / #cols, 0)
		s.Size = UDim2.fromScale(1 / #cols + 0.01, 1)
		s.Parent = parent
	end
end
local function swatch(parent, item, x, y, size)
	local sw = frame(parent, "Swatch", x, y, size, size, Color3.fromRGB(29, 36, 52))
	sw.ClipsDescendants = true
	corner(sw, math.floor(size / 7))
	if item.kind == "skin" then
		US = US or req("SkinShared", "UniversalSkins")
		local s = US and US.get(item.id)
		local cols = {}
		for _, hex in ipairs(s and s.sw or {"5E943E"}) do table.insert(cols, Color3.fromHex(hex)) end
		stripes(sw, cols)
	elseif item.kind == "trail" then
		TC = TC or req("TrailShared", "TrailCatalog")
		local t = TC and TC.get(item.id)
		local cols = {}
		for _, c in ipairs(t and t.sw or {}) do if typeof(c) == "Color3" then table.insert(cols, c) end end
		if #cols == 0 then cols = {Color3.fromRGB(127, 233, 255)} end
		stripes(sw, cols)
	elseif item.kind == "emote" then
		EC = EC or req("EmoteShared", "EmoteCatalog")
		local e = EC and EC.get(item.id)
		sw.BackgroundColor3 = Color3.fromRGB(18, 35, 58)
		text(sw, "Word", 4, 0, size - 8, size, e and e.word or "!", math.floor(size / 5), Color3.fromRGB(127, 233, 255))
	elseif item.kind == "dino" then
		sw.BackgroundColor3 = Color3.fromRGB(46, 110, 58)
		text(sw, "Dino", 4, 0, size - 8, size, item.name, math.floor(size / 6), Color3.new(1, 1, 1))
	else
		sw.BackgroundColor3 = YELLOW
		text(sw, "Pts", 0, 0, size, size, "+" .. tostring(item.id), math.floor(size / 3), INK)
	end
	return sw
end
local KIND = {skin = "SKIN", emote = "EMOTE", trail = "TRAIL", dino = "DINO", points = "POINTS"}
local HINT = {skin = "EQUIP IT IN THE LAB", emote = "ADDED TO YOUR EMOTE WHEEL", trail = "ON EVERY DINO",
	dino = "PICK IT WITH THE DINO BUTTON · ALL PARTS MAXED", points = "ADDED TO YOUR SKILL POINTS"}

-- ---------- the reveal screen ----------
local W, H = 1000, 460
local gui = Instance.new("ScreenGui")
gui.Name = "FavEgg"
gui.DisplayOrder = 70
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local back = Instance.new("TextButton")
back.Name = "Back"
back.Text = ""
back.AutoButtonColor = false
back.Size = UDim2.fromScale(1, 1)
back.BackgroundColor3 = Color3.fromRGB(5, 8, 13)
back.BackgroundTransparency = 0.04
back.Parent = gui
local stage = frame(gui, "Stage", 0, 0, W, H)
stage.AnchorPoint = Vector2.new(0.5, 0.5)
stage.Position = UDim2.fromScale(0.5, 0.5)
local scale = Instance.new("UIScale")
scale.Parent = stage
local function fit()
	local cam = workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
	scale.Scale = math.min(vs.X / W, vs.Y / H) * 0.96
end
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -24)
toast.Size = UDim2.fromOffset(360, 48)
toast.BackgroundColor3 = Color3.fromRGB(11, 15, 22)
toast.FontFace = SILK
toast:SetAttribute("FontSwap", "keep")
toast.TextSize = 18
toast.TextColor3 = Color3.new(1, 1, 1)
toast.Visible = false
corner(toast, 12)
stroke(toast, YELLOW, 3)
local toastGui = Instance.new("ScreenGui")
toastGui.Name = "FavEggToast"
toastGui.DisplayOrder = 71
toastGui.ResetOnSpawn = false
toastGui.Parent = gui.Parent
toast.Parent = toastGui
local toastId = 0
local function showToast(t)
	toastId += 1
	local my = toastId
	toast.Text = t
	toast.Size = UDim2.fromOffset(math.max(260, #t * 14 + 48), 48)
	toast.Visible = true
	task.delay(2.4, function() if toastId == my then toast.Visible = false end end)
end

local function clearStage() for _, c in ipairs(stage:GetChildren()) do if not c:IsA("UIScale") then c:Destroy() end end end
local function close(msg)
	gui.Enabled = false
	clearStage()
	if msg then showToast(msg) end
end

local function card(parent, item, x)
	local t = TIER[item.tier] or TIER.common
	local c = frame(parent, "Card", x, 0, 150, 180, Color3.fromRGB(21, 29, 43))
	corner(c, 14)
	stroke(c, t[2], 4)
	swatch(c, item, 30, 14, 90)
	text(c, "Name", 6, 108, 138, 40, string.upper(item.name or ""), 14, Color3.new(1, 1, 1))
	text(c, "Kind", 6, 148, 138, 22, (KIND[item.kind] or "") .. " · " .. t[1], 11, t[2])
	return c
end

local function showPrize(prize)
	clearStage()
	local t = TIER[prize.tier] or TIER.common
	local rays = frame(stage, "Rays", W / 2 - 420, H / 2 - 420, 840, 840)
	for i = 1, 8 do
		local r = frame(rays, "Ray" .. i, 410, 0, 20, 840, t[2])
		r.BackgroundTransparency = 0.82
		r.Rotation = i * 22.5
	end
	if not reducedMotion() then
		TweenService:Create(rays, TweenInfo.new(16, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360}):Play()
	end
	local chip = text(stage, "KindChip", W / 2 - 70, 18, 140, 30, KIND[prize.kind] or "", 16, INK)
	chip.BackgroundTransparency = 0
	chip.BackgroundColor3 = t[2]
	corner(chip, 8)
	local sw = swatch(stage, prize, W / 2 - 75, 58, 150)
	stroke(sw, t[2], 4)
	text(stage, "Name", 100, 216, W - 200, 48, string.upper(prize.name or ""), 36, Color3.new(1, 1, 1))
	text(stage, "Tier", 100, 264, W - 200, 26, t[1], 18, t[2])
	text(stage, "Hint", 100, 292, W - 200, 24, HINT[prize.kind] or "", 14, Color3.fromRGB(138, 149, 168))
	local msg = string.upper(prize.name or "") .. " UNLOCKED"
	local function button(name, label, x, primary, fn)
		local holder = frame(stage, name, x, 336, 200, 64)
		if primary then local lip = frame(holder, "Lip", 0, 6, 200, 64, LIP) corner(lip, 14) end
		local b = Instance.new("TextButton")
		b.Name = "Button"
		b.Size = UDim2.fromOffset(200, 64)
		b.BackgroundColor3 = primary and YELLOW or Color3.fromRGB(27, 36, 52)
		b.FontFace = SILK
		b:SetAttribute("FontSwap", "keep")
		b.TextSize = 22
		b.TextColor3 = primary and INK or Color3.new(1, 1, 1)
		b.Text = label
		b.ZIndex = 2
		b.Parent = holder
		corner(b, 14)
		if not primary then stroke(b, Color3.fromRGB(42, 52, 70), 3) end
		b.Activated:Connect(fn)
	end
	if prize.kind == "trail" then
		button("Equip", "EQUIP", W / 2 - 210, true, function()
			close(msg)
			task.spawn(function()
				local t0 = os.clock()
				while os.clock() - t0 < 10 do
					if string.find("," .. tostring(player:GetAttribute("TrailOwned") or "") .. ",", "," .. prize.id .. ",", 1, true) then break end
					task.wait(0.25)
				end
				local r = ReplicatedStorage:FindFirstChild("DinoTrailRequest")
				if r then r:FireServer("equip", prize.id) end
			end)
		end)
		button("Nice", "NICE", W / 2 + 10, false, function() close(msg) end)
	else
		button("Nice", "NICE", W / 2 - 100, true, function() close(msg) end)
	end
	script:SetAttribute("FavEggRevealShown", (script:GetAttribute("FavEggRevealShown") or 0) + 1)
end

local function reveal(prize, reel)
	fit()
	clearStage()
	gui.Enabled = true
	local holder = frame(stage, "Reel", 0, 130, W, 190)
	holder.ClipsDescendants = true
	local strip = frame(holder, "Strip", 0, 5, 10, 180)
	local STEP = 162
	local at = 1
	for i, it in ipairs(reel or {prize}) do
		card(strip, it, (i - 1) * STEP)
		if it.kind == prize.kind and it.id == prize.id and it.tier == prize.tier then at = i end
	end
	local mark = frame(holder, "Mark", W / 2 - 3, 0, 6, 190, YELLOW)
	mark.ZIndex = 3
	local target = -((at - 1) * STEP + 75 - W / 2) + Random.new():NextInteger(-40, 40)
	strip.Position = UDim2.fromOffset(0, 5)
	local dur = reducedMotion() and 0.3 or A("FavEggReelTime", 4)
	local tw = TweenService:Create(strip, TweenInfo.new(dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.fromOffset(target, 5)})
	tw:Play()
	tw.Completed:Wait()
	task.wait(0.35)
	if gui.Enabled then showPrize(prize) end
end

-- ---------- the stand ----------
local remote = ReplicatedStorage:WaitForChild("FavEggRequest", 60)
local stand = workspace:WaitForChild("FavEggStand", 120)
if not (remote and stand) then return end
local prompt = stand:FindFirstChild("FavEggPrompt", true)
local egg = stand:FindFirstChild("Egg")
local eggRest = egg and egg.CFrame
local spots = {}
for _, d in ipairs(stand:GetDescendants()) do
	if d:IsA("BasePart") and d:GetAttribute("EggSpot") then spots[d] = egg and eggRest:ToObjectSpace(d.CFrame) end
end
local clock = stand:FindFirstChild("Clock", true)
local busy = false

local function fmt(s)
	s = math.max(0, math.floor(s))
	return ("%02d:%02d:%02d"):format(s // 3600, s % 3600 // 60, s % 60)
end
local GREY = Color3.fromRGB(150, 150, 150)
local hidden, greyed = false, false
local function applyState()
	local st = player:GetAttribute("FavEggState")
	if st == "expired" and not hidden then
		hidden = true
		for _, d in ipairs(stand:GetDescendants()) do
			if d:IsA("BasePart") then d.LocalTransparencyModifier = 1 end
			if d:IsA("SurfaceGui") or d:IsA("BillboardGui") then d.Enabled = false end
		end
		if prompt then prompt.Enabled = false end
	end
	if st == "rolled" and not greyed and egg then
		greyed = true
		egg.Color = GREY
		for p in pairs(spots) do p.Color = GREY end
		if prompt then prompt.ActionText = "ROLLED ✓" prompt.ObjectText = "Thanks for the favorite!" end
	end
end
player:GetAttributeChangedSignal("FavEggState"):Connect(applyState)
applyState()

local lastSeen = 0
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	if egg and eggRest and not reducedMotion() and player:GetAttribute("FavEggState") ~= "rolled" then
		local cf = eggRest * CFrame.new(0, math.sin(t * 2 * math.pi / 2.4) * 0.5, 0) * CFrame.Angles(0, 0, math.rad(4 * math.sin(t * 2 * math.pi / 2.4)))
		egg.CFrame = cf
		for p, rel in pairs(spots) do p.CFrame = cf * rel end
	end
	if clock then
		local ends = tonumber(player:GetAttribute("FavEggEndsAt"))
		local txt = ends and fmt(ends - workspace:GetServerTimeNow()) or "48:00:00"
		if clock.Text ~= txt then clock.Text = txt end
	end
	if player:GetAttribute("FavEggState") == "unseen" and t - lastSeen > 2 then
		local f = stand:GetAttribute("FavEggFront")
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if typeof(f) == "Vector3" and hrp and Vector3.new(hrp.Position.X - f.X, 0, hrp.Position.Z - f.Z).Magnitude <= A("FavEggSeenNear", 55) then
			lastSeen = t
			task.spawn(function() pcall(function() remote:InvokeServer("seen") end) end)
		end
	end
end)

local WORDS = {notNear = "GET CLOSER TO THE EGG", expired = "THE FREE EGG HAS GONE", notLoaded = "LOADING, TRY AGAIN",
	notOpen = "LOADING, TRY AGAIN", busy = "ONE MOMENT", failed = "TRY AGAIN", notHub = "ONLY ON THE ISLAND"}

local function askFavorite()
	if RunService:IsStudio() and script:GetAttribute("FavEggTestFakeFavorite") == true then
		script:SetAttribute("FavEggFavResult", "fake Success")
		return true
	end
	local id = tonumber(script:GetAttribute("FavEggFavoriteId")) or game.PlaceId
	local got
	local conn = AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(r) got = r end)
	local ok = pcall(function() AvatarEditorService:PromptSetFavorite(id, Enum.AvatarItemType.Asset, true) end)
	local t0 = os.clock()
	while ok and got == nil and os.clock() - t0 < 120 do task.wait(0.1) end
	conn:Disconnect()
	script:SetAttribute("FavEggFavResult", ok and tostring(got) or "promptError")
	return got == Enum.AvatarPromptResult.Success
end

local function onPrompt()
	if busy or gui.Enabled then return end
	local st = player:GetAttribute("FavEggState")
	if st == "rolled" then showToast("YOU ALREADY ROLLED · THANKS!") return end
	if st == "expired" then return end
	busy = true
	if st == "unseen" then pcall(function() remote:InvokeServer("seen") end) end
	if askFavorite() then
		local ok, r, prize, reel = pcall(function() return remote:InvokeServer("favorited") end)
		if ok and r == "ok" and type(prize) == "table" then
			reveal(prize, reel)
		elseif ok and r == "rolled" then
			showToast("YOU ALREADY ROLLED · THANKS!")
		else
			showToast(WORDS[ok and r or "failed"] or "TRY AGAIN")
		end
	else
		showToast("FAVORITE TO ROLL THE EGG")
	end
	busy = false
end
if prompt then prompt.Triggered:Connect(onPrompt) end
