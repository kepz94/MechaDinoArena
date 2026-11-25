-- ShopScreen v1.0 (Mecha Dino Arena) — the main menu SHOP: buy what you don't own yet. Plan docs/plans/SHOP_v1.0.md, mockup
-- docs/mockups/main_menu_shop_v0.1.html option A "Featured + rows" (Kepu 2026-11-24 18:58 "a shop button on the main menu where it's
-- dedicated to buying stuff you don't have"; 19:11 "we're going to be selling other things in the store like animations and
-- accessories"; 19:12 "build the shop knowing other tabs will be added"; picks "A · Featured + rows", featured "Change every day").
-- LocalScript in StarterPlayerScripts. ScreenGui "Shop" (DisplayOrder 50, IgnoreGuiInset, hidden until opened).
-- Opened by MainMenu 1.29's SHOP tile through the BindableFunction "Open" under this script ("Close" closes). Only while InMenu.
-- Categories: CATEGORIES lists the tabs (id, name, items()). v1.0 has one, SKINS: the Robux skins of
--   ReplicatedStorage.SkinShared.UniversalSkins (unlock.kind "robux") that the player does not own (player SkinOwnedU, or every skin
--   while SkinAllUnlocked). A new tab = a new CATEGORIES entry with its own items(), preview(model, item) and buy(item); FEATURED
--   picks from every category.
-- Featured: 2 items, the same for everyone, new every UTC day (server time): day = floor(GetServerTimeNow() / 86400); one animated
--   (999) item and one other, chosen by hash(day). An owned featured item is not shown. Timer chip "NEW IN <h>H <m>M" (to 00:00 UTC).
-- Screen (mockup A): header "SHOP", a short line and the timer, X; category tabs; left (58% width): FEATURED (2 big cards), then
--   R$149 / R$499 / R$999 sections (4 cards a row; featured items not repeated); right: 3D preview (the selected item on your dino,
--   or another dino with ◀ ▶; ReplicatedStorage.PregameModels.<Dino>.Body, tagged + painted with UniversalSkins; animated blocks via
--   SkinFX), then "SKIN · R$<price>[ · ANIMATED]", name, "✓ WORKS ON ALL 8 DINOS", a line, and BUY.
-- BUY (skins): ReplicatedStorage.DinoSkinRequest:FireServer("buy", id, dino) -> SkinServer 1.2 (credit of that price, else Roblox's
--   window for that price's product). Button: "BUY · R$<price>" / "UNLOCK · 1 CREDIT" (SkinCredits_<RARITY> > 0) / "…" (waiting, at
--   most BUY_WAIT s) / "LOADING" (save not loaded). Results (SkinServerResult): "bought" -> toast "<NAME> UNLOCKED · ON <DINO>"
--   (SkinServer equips it on that dino) and the item leaves the shop; "owned" -> toast "ALREADY YOURS".
-- Empty: "YOU OWN EVERY SKIN" (every skin owned, or SkinAllUnlocked while the test switch is on).
-- Menu badge: player attribute ShopBadge = true while a featured item is not owned and the shop was not opened this session.
-- Switches (script attributes): ShopEnabled (default true, read at start; false = no shop, Open returns false); ShopTestShowAll
--   (default false, read per draw; true = list every Robux skin even when owned, for Studio looks only).
-- v1.1 (Kepu 2026-11-24 "Build next", plan docs/plans/EMOTES_v1.0.md): EMOTES tab = the 149 R$ emotes of
--   ReplicatedStorage.EmoteShared.EmoteCatalog (EmoteServer 1.0) the player does not own (player EmoteOwned, or all while
--   EmoteAllUnlocked). Card: the emote's pop-up word instead of colour swatches. Preview: your dino (or ◀ ▶ another) in its equipped
--   skin, doing the emote on a loop (EmotePose 1.0 from the character's IdleAnimation, joints moved by hand in the ViewportFrame)
--   with the word on top. BUY -> ReplicatedStorage.DinoEmoteRequest:FireServer("buy", id) (149 product prompt); results from player
--   EmoteResult ("bought" -> "<NAME> UNLOCKED", "owned" -> "ALREADY YOURS"). Emotes are not in FEATURED (featured stays skins only).
--   Switch: script attribute ShopEmotesEnabled (default true, read at start; false = the 1.0 shop).
-- Diagnostics (LocalPlayer): ShopVersion, ShopOpen, ShopItems (listed), ShopFeatured ("id,id"), ShopSelected, ShopView (dino),
--   ShopLastBuy (state).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local VERSION = "1.1" -- v1.1 EMOTES tab
local BUY_WAIT = 60
local player = Players.LocalPlayer
player:SetAttribute("ShopVersion", VERSION)
player:SetAttribute("ShopOpen", false)
if script:GetAttribute("ShopEnabled") == nil then script:SetAttribute("ShopEnabled", true) end
if script:GetAttribute("ShopTestShowAll") == nil then script:SetAttribute("ShopTestShowAll", false) end

local openFn = script:FindFirstChild("Open") or Instance.new("BindableFunction")
openFn.Name = "Open"
openFn.Parent = script
local closeFn = script:FindFirstChild("Close") or Instance.new("BindableFunction")
closeFn.Name = "Close"
closeFn.Parent = script
if script:GetAttribute("ShopEnabled") == false then
	openFn.OnInvoke = function() return false end
	closeFn.OnInvoke = function() return false end
	return
end

local PANEL = Color3.fromRGB(20, 27, 40)
local PANEL2 = Color3.fromRGB(28, 34, 48)
local YELLOW = Color3.fromRGB(255, 200, 50)
local VOLT = Color3.fromRGB(127, 233, 255)
local GREEN = Color3.fromRGB(70, 224, 138)
local PINK = Color3.fromRGB(255, 90, 110)
local GREY = Color3.fromRGB(207, 211, 220)
local MUTED = Color3.fromRGB(143, 153, 170)
local WHITE = Color3.new(1, 1, 1)
local DARK_TEXT = Color3.fromRGB(27, 20, 6)

-- ---------- helpers ----------
local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = r or UDim.new(0, 8) c.Parent = p return c end
local function stroke(p, color, t, th)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color, s.Transparency, s.Thickness = color, t, th
	s.Parent = p
	return s
end
local function frame(parent, name, color, transp)
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	if color then f.BackgroundColor3 = color f.BackgroundTransparency = transp or 0 else f.BackgroundTransparency = 1 end
	f.Parent = parent
	return f
end
local function label(parent, name, font, size, color, text)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.Text = text or ""
	l.Parent = parent
	return l
end
local function button(parent, name, color, transp)
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.Text = ""
	b.BorderSizePixel = 0
	b.BackgroundColor3 = color or PANEL
	b.BackgroundTransparency = transp or 0
	b.Parent = parent
	return b
end
local function topLeftClear()
	local ok, v = pcall(function() return GuiService.TopbarInset.Min.X end)
	if ok and type(v) == "number" and v > 0 then return v else return 220 end
end
local function frac(x) return x - math.floor(x) end
local function hsh(a, b) return frac(math.sin(a * 12.9898 + b * 78.233) * 43758.5453) end
local function press(v) player:SetAttribute("ShopLastPress", v) end

-- ---------- data ----------
local USM
local function US()
	if USM then return USM end
	local f = ReplicatedStorage:FindFirstChild("SkinShared")
	local m = f and f:FindFirstChild("UniversalSkins")
	if m then
		local ok, r = pcall(require, m)
		if ok then USM = r end
	end
	return USM
end
local SCM
local function SC()
	if SCM then return SCM end
	local f = ReplicatedStorage:FindFirstChild("SkinShared")
	local m = f and f:FindFirstChild("SkinCatalog")
	if m then
		local ok, r = pcall(require, m)
		if ok then SCM = r end
	end
	return SCM
end
local function ownedSet()
	local set = {}
	local v = player:GetAttribute("SkinOwnedU")
	if type(v) == "string" then
		for id in v:gmatch("[^,]+") do set[id] = true end
	end
	return set
end
local function priceOf(sk)
	local live = player:GetAttribute("SkinPrice_" .. tostring(sk.unlock.rarity))
	if type(live) == "number" then return live end
	return sk.unlock.price
end
local function species()
	local c = player.Character
	local sp = c and c:GetAttribute("Species")
	if type(sp) == "string" and sp ~= "" then return sp end
	sp = player:GetAttribute("DinoSpecies")
	if type(sp) == "string" and sp ~= "" then return sp end
	return "Raptor"
end

-- an item: {cat, id, name, price, anim, sw}; every Robux skin (owned too), in UniversalSkins.ORDER
local function allSkins()
	local us = US()
	local out = {}
	if not us then return out end
	for _, id in ipairs(us.ORDER) do
		local sk = us.SKINS[id]
		if sk and sk.unlock.kind == "robux" then
			table.insert(out, {cat = "skins", id = id, name = sk.name, price = priceOf(sk), tier = sk.unlock.price, anim = sk.anim == true, sw = sk.sw or {}})
		end
	end
	return out
end
local function skinOwned(it)
	if script:GetAttribute("ShopTestShowAll") == true then return false end
	if player:GetAttribute("SkinAllUnlocked") == true then return true end
	return ownedSet()[it.id] == true
end
-- v1.1: emotes (EmoteCatalog 1.0, client copy made by EmoteServer 1.0)
local ECM
local function EC()
	if ECM then return ECM end
	local f = ReplicatedStorage:FindFirstChild("EmoteShared")
	local m = f and f:FindFirstChild("EmoteCatalog")
	if m then
		local ok, r = pcall(require, m)
		if ok then ECM = r end
	end
	return ECM
end
local function allEmotes()
	local ec = EC()
	local out = {}
	if not ec then return out end
	for _, id in ipairs(ec.ORDER) do
		local e = ec.get(id)
		if e and e.unlock.kind == "robux" then
			table.insert(out, {cat = "emotes", id = id, name = e.name, price = e.unlock.price, tier = e.unlock.price, anim = false, sw = {},
				emote = true, word = e.word, desc = e.desc, dur = e.dur})
		end
	end
	return out
end
local function emoteOwned(it)
	if script:GetAttribute("ShopTestShowAll") == true then return false end
	if player:GetAttribute("EmoteAllUnlocked") == true then return true end
	for id in tostring(player:GetAttribute("EmoteOwned") or ""):gmatch("[^,]+") do
		if id == it.id then return true end
	end
	return false
end
-- v1.0: one tab; animations and accessories add their own entries here
local CATEGORIES = {
	{id = "skins", name = "SKINS", all = allSkins, owned = skinOwned, kind = "SKIN"},
}
if script:GetAttribute("ShopEmotesEnabled") == nil then script:SetAttribute("ShopEmotesEnabled", true) end -- v1.1
if script:GetAttribute("ShopEmotesEnabled") ~= false then
	table.insert(CATEGORIES, {id = "emotes", name = "EMOTES", all = allEmotes, owned = emoteOwned, kind = "EMOTE", featured = false})
end
local function featured()
	local all = {}
	for _, c in ipairs(CATEGORIES) do
		if c.featured ~= false then -- v1.1: emotes stay out of FEATURED
			for _, it in ipairs(c.all()) do table.insert(all, it) end
		end
	end
	local day = math.floor(workspace:GetServerTimeNow() / 86400)
	local anim, plain = {}, {}
	for _, it in ipairs(all) do table.insert(it.anim and anim or plain, it) end
	local out = {}
	if #anim > 0 then table.insert(out, anim[math.floor(hsh(day, 1) * #anim) + 1]) end
	if #plain > 0 then table.insert(out, plain[math.floor(hsh(day, 2) * #plain) + 1]) end
	return out, day
end
local function catOf(id) for _, c in ipairs(CATEGORIES) do if c.id == id then return c end end end

-- ---------- gui ----------
local pg = player:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("Shop")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "Shop"
gui.DisplayOrder = 50
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = pg
local root = button(gui, "Root", Color3.fromRGB(10, 14, 22), 0.03) -- takes every touch
root.Size = UDim2.fromScale(1, 1)
local head = frame(root, "Head")
local headLine = frame(head, "Line", WHITE, 0.92)
local titleL = label(head, "Title", Enum.Font.FredokaOne, 24, WHITE, "SHOP")
titleL.TextXAlignment = Enum.TextXAlignment.Left
titleL.AutomaticSize = Enum.AutomaticSize.X
local subL = label(head, "Sub", Enum.Font.GothamBlack, 11, MUTED, "Skins you don't own yet. Every skin works on all 8 dinos.")
subL.TextXAlignment = Enum.TextXAlignment.Left
subL.TextTruncate = Enum.TextTruncate.AtEnd
local timer = label(head, "Timer", Enum.Font.GothamBlack, 11, YELLOW, "")
timer.BackgroundTransparency = 0
timer.BackgroundColor3 = Color3.fromRGB(51, 40, 12)
timer.AutomaticSize = Enum.AutomaticSize.X
local timerC = corner(timer, UDim.new(1, 0))
local timerPad = Instance.new("UIPadding") timerPad.Parent = timer
local closeB = button(head, "Close", PANEL, 0.1)
local closeC = corner(closeB)
stroke(closeB, WHITE, 0.8, 2)
local closeX = label(closeB, "X", Enum.Font.FredokaOne, 18, WHITE, "X")
closeX.Size = UDim2.fromScale(1, 1)
local tabsRow = frame(root, "Tabs")
local tabsList = Instance.new("UIListLayout")
tabsList.FillDirection = Enum.FillDirection.Horizontal
tabsList.SortOrder = Enum.SortOrder.LayoutOrder
tabsList.Parent = tabsRow
local list = Instance.new("ScrollingFrame")
list.Name = "List"
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.ScrollBarImageColor3 = YELLOW
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = root
local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list
local listPad = Instance.new("UIPadding") listPad.Parent = list
local prev = frame(root, "Preview", Color3.fromRGB(14, 19, 29), 0)
prev.ClipsDescendants = true
local prevC = corner(prev)
stroke(prev, WHITE, 0.88, 2)
local view = Instance.new("ViewportFrame")
view.Name = "View"
view.Size = UDim2.fromScale(1, 1)
view.BackgroundTransparency = 1
view.Ambient = Color3.fromRGB(150, 150, 160)
view.LightColor = Color3.fromRGB(255, 250, 240)
view.LightDirection = Vector3.new(-0.4, -1, -0.6)
view.Parent = prev
local cam = Instance.new("Camera")
cam.FieldOfView = 34
cam.Parent = view
view.CurrentCamera = cam
local onTag = label(prev, "On", Enum.Font.GothamBlack, 11, WHITE, "")
onTag.BackgroundTransparency = 0.45
onTag.BackgroundColor3 = Color3.new(0, 0, 0)
onTag.AutomaticSize = Enum.AutomaticSize.X
local onC = corner(onTag)
local onPad = Instance.new("UIPadding") onPad.Parent = onTag
local dPrev = button(prev, "DinoPrev", PANEL, 0.1)
local dNext = button(prev, "DinoNext", PANEL, 0.1)
local dPrevC, dNextC = corner(dPrev), corner(dNext)
local dPrevL = label(dPrev, "T", Enum.Font.FredokaOne, 16, WHITE, "◀") dPrevL.Size = UDim2.fromScale(1, 1)
local dNextL = label(dNext, "T", Enum.Font.FredokaOne, 16, WHITE, "▶") dNextL.Size = UDim2.fromScale(1, 1)
local dName = label(prev, "Dino", Enum.Font.FredokaOne, 14, WHITE, "")
local wordL = label(prev, "EmoteWord", Enum.Font.Bangers, 30, YELLOW, "") -- v1.1
wordL.AnchorPoint = Vector2.new(0.5, 0)
wordL.Position = UDim2.fromScale(0.5, 0.1)
wordL.Size = UDim2.fromScale(0.8, 0.14)
wordL.TextScaled = true
wordL.Visible = false
do local s = Instance.new("UIStroke") s.Thickness = 3 s.Parent = wordL end
local info = frame(root, "Info")
local infoList = Instance.new("UIListLayout")
infoList.SortOrder = Enum.SortOrder.LayoutOrder
infoList.Parent = info
local toast = label(root, "Toast", Enum.Font.FredokaOne, 16, YELLOW, "")
toast.BackgroundTransparency = 0.05
toast.BackgroundColor3 = Color3.fromRGB(12, 17, 27)
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.AutomaticSize = Enum.AutomaticSize.X
toast.Visible = false
toast.ZIndex = 10
local toastC = corner(toast)
stroke(toast, YELLOW, 0, 2)
local toastPad = Instance.new("UIPadding") toastPad.Parent = toast

-- ---------- state ----------
local open = false
local tab = "skins"
local sel = nil -- item id
local view_sp = nil -- dino on the preview (nil = yours)
local S = {}
local model, modelKey = nil, nil
local center, radius, orbit = Vector3.zero, 20, 0
local buyPendingAt = nil
local seenThisSession = false
local toastToken = 0
local function showToast(t)
	toastToken += 1
	local my = toastToken
	toast.Text = t
	toast.Visible = true
	task.delay(1.6, function() if toastToken == my then toast.Visible = false end end)
end
local function shownSpecies() return view_sp or species() end
local function dinoName(sp)
	local us = US()
	return us and us.DINO_NAMES[sp] or string.upper(sp)
end

local function measure()
	local W, H = root.AbsoluteSize.X, root.AbsoluteSize.Y
	S.W, S.H, S.ch, S.cw = W, H, H / 100, W / 100
end

-- the preview model: the shown dino's body, wearing the selected skin
local function buildModel()
	local sp = shownSpecies()
	if modelKey == sp and model and model.Parent then return end
	if model then model:Destroy() model = nil end
	modelKey = nil
	local f = ReplicatedStorage:FindFirstChild("PregameModels")
	local holder = f and f:FindFirstChild(sp)
	local src = holder and holder:FindFirstChild("Body")
	if not src then return end
	local copy = src:Clone()
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end
	local us, sc = US(), SC()
	if us and sc then us.tagModel(copy, sp, sc.roleOf) end
	local cf, size = copy:GetBoundingBox()
	center = cf.Position
	local a = view.AbsoluteSize
	local aspect = (a.X > 0 and a.Y > 0) and a.X / a.Y or 1.3
	local t = math.tan(math.rad(cam.FieldOfView / 2))
	local w = math.sqrt(size.X ^ 2 + size.Z ^ 2)
	radius = math.max(((size.Y + 0.3 * w) * 0.5) / t, (w * 0.5) / (t * aspect)) * 0.9 -- 1.1 drew the dino small (Studio phone test)
	copy.Parent = view
	model, modelKey = copy, sp
end
local function paintModel()
	local us, sc = US(), SC()
	if not (model and us and sc) then return end
	local sp = shownSpecies()
	local classic = sc.get(sp, "classic")
	local skin = sel or "classic"
	if tab == "emotes" then -- v1.1: an emote plays on the dino's equipped skin
		local eq = player:GetAttribute("SkinEquipped_" .. sp)
		skin = (type(eq) == "string" and us.get(eq)) and eq or "classic"
	end
	us.paintModel(model, skin, classic and classic.colors)
end

-- ---------- drawing ----------
local redraw
local function clear(p)
	for _, ch in ipairs(p:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
end
local function swatch(parent, it, h)
	local s = frame(parent, "Colors", PANEL2, 0)
	s.Size = UDim2.new(1, 0, 0, h)
	s.ClipsDescendants = true
	corner(s, UDim.new(0, 0.9 * S.ch))
	local n = math.max(1, math.min(4, #it.sw))
	for i = 1, n do
		local c = frame(s, "C" .. i, Color3.fromHex(it.sw[i]), 0)
		c.Position, c.Size = UDim2.fromScale((i - 1) / n, 0), UDim2.fromScale(1 / n, 1)
	end
	return s
end
local function card(parent, it, big, order)
	local ch = S.ch
	local b = button(parent, "Item_" .. it.id, PANEL2, 0)
	b.LayoutOrder = order
	corner(b, UDim.new(0, 1.4 * ch))
	stroke(b, sel == it.id and YELLOW or WHITE, sel == it.id and 0 or 0.9, sel == it.id and 2.5 or 2)
	local p = 1 * ch
	local inner = frame(b, "In")
	inner.Position, inner.Size = UDim2.fromOffset(p, p), UDim2.new(1, -2 * p, 1, -2 * p)
	local l = Instance.new("UIListLayout")
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, 0.6 * ch)
	l.Parent = inner
	local swH = big and math.max(17 * ch, 50) or math.max(6.5 * ch, 22)
	local sw
	if it.word then -- v1.1: emote cards show the pop-up word
		sw = frame(inner, "Word", Color3.fromRGB(27, 35, 51), 0)
		sw.Size = UDim2.new(1, 0, 0, swH)
		corner(sw, UDim.new(0, 0.9 * S.ch))
		local w = label(sw, "W", Enum.Font.Bangers, swH * 0.6, YELLOW, it.word)
		w.Size = UDim2.fromScale(0.92, 0.85)
		w.Position = UDim2.fromScale(0.04, 0.08)
		w.TextScaled = true
		local ws = Instance.new("UIStroke")
		ws.Thickness = 2
		ws.Parent = w
	else
		sw = swatch(inner, it, swH)
	end
	sw.LayoutOrder = 1
	local nS = big and math.max(2.6 * ch, 13) or math.max(1.8 * ch, 9)
	local nm = label(inner, "Name", Enum.Font.FredokaOne, nS, WHITE, it.name)
	nm.LayoutOrder = 2
	nm.TextXAlignment = Enum.TextXAlignment.Left
	nm.TextScaled = true
	local fit = Instance.new("UITextSizeConstraint")
	fit.MinTextSize, fit.MaxTextSize = 6, nS
	fit.Parent = nm
	nm.Size = UDim2.new(1, 0, 0, nS * 1.2)
	local row = frame(inner, "Row")
	row.LayoutOrder = 3
	local pS = math.max(1.7 * ch, 9)
	row.Size = UDim2.new(1, 0, 0, pS * 1.2)
	local pr = label(row, "Price", Enum.Font.GothamBlack, pS, YELLOW, "R$" .. tostring(it.price or "?"))
	pr.TextXAlignment = Enum.TextXAlignment.Left
	pr.Size = UDim2.fromScale(1, 1)
	if it.anim then
		local an = label(row, "Anim", Enum.Font.GothamBlack, math.max(1.3 * ch, 7), VOLT, "ANIMATED")
		an.TextXAlignment = Enum.TextXAlignment.Right
		an.Size = UDim2.fromScale(1, 1)
	end
	b.Activated:Connect(function()
		press("item:" .. it.id)
		sel = it.id
		redraw()
	end)
	return b
end
local function section(order, title, note)
	local ch = S.ch
	local s = frame(list, "Sec_" .. title)
	s.LayoutOrder = order
	local tS = math.max(2.2 * ch, 11)
	s.Size = UDim2.new(1, 0, 0, tS + 2.2 * ch)
	local t = label(s, "T", Enum.Font.FredokaOne, tS, YELLOW, title)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Bottom
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.new(0, 0, 1, -0.6 * ch)
	if note then
		local n = label(s, "N", Enum.Font.GothamBlack, math.max(1.6 * ch, 9), MUTED, note)
		n.TextXAlignment = Enum.TextXAlignment.Left
		n.TextYAlignment = Enum.TextYAlignment.Bottom
		n.Size = UDim2.new(1, 0, 1, -0.7 * ch)
		local function place() n.Position = UDim2.fromOffset(t.TextBounds.X + 1.2 * ch, 0) end
		t:GetPropertyChangedSignal("TextBounds"):Connect(place)
		place()
	end
	return s
end
local function grid(order, cols, cellH)
	local ch = S.ch
	local g = frame(list, "Grid" .. order)
	g.LayoutOrder = order
	g.AutomaticSize = Enum.AutomaticSize.Y
	g.Size = UDim2.new(1, 0, 0, 0)
	local gl = Instance.new("UIGridLayout")
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.CellPadding = UDim2.fromOffset(1.2 * ch, 1.2 * ch)
	local w = (S.W * 0.58 - 11 - (cols - 1) * 1.2 * ch) / cols
	gl.CellSize = UDim2.fromOffset(w, cellH)
	gl.Parent = g
	return g
end

local function itemsFor(c)
	local out = {}
	for _, it in ipairs(c.all()) do
		if not c.owned(it) then table.insert(out, it) end
	end
	return out
end
local function findItem(id)
	for _, c in ipairs(CATEGORIES) do
		for _, it in ipairs(c.all()) do if it.id == id then return it, c end end
	end
end

local function drawList()
	clear(list)
	local ch = S.ch
	local c = catOf(tab) or CATEGORIES[1]
	local items = itemsFor(c)
	local feat, day = featured()
	local featShown = {}
	if c.featured == false then feat = {} end -- v1.1: no FEATURED row on the EMOTES tab
	for _, it in ipairs(feat) do
		local fc = catOf(it.cat)
		if fc and not fc.owned(it) then table.insert(featShown, it) end
	end
	local featIds, valid = {}, {}
	for _, it in ipairs(feat) do table.insert(featIds, it.id) end
	for _, it in ipairs(items) do valid[it.id] = true end
	for _, it in ipairs(featShown) do valid[it.id] = true end
	player:SetAttribute("ShopFeatured", table.concat(featIds, ","))
	player:SetAttribute("ShopFeaturedDay", day)
	player:SetAttribute("ShopItems", #items)
	if sel and not valid[sel] then sel = nil end
	if not sel then sel = (featShown[1] and featShown[1].id) or (items[1] and items[1].id) end
	player:SetAttribute("ShopSelected", sel or "")
	if #items == 0 and #featShown == 0 then
		local e = label(list, "Empty", Enum.Font.FredokaOne, math.max(2.6 * ch, 13), MUTED, "YOU OWN EVERY " .. c.name:sub(1, -2))
		e.Size = UDim2.new(1, 0, 0, 8 * ch)
		e.TextXAlignment = Enum.TextXAlignment.Left
		return
	end
	local order = 0
	local isFeat = {}
	if #featShown > 0 then
		order += 1
		section(order, "FEATURED", "New every day")
		order += 1
		local g = grid(order, 2, math.max(17 * ch, 50) + 2 * ch + math.max(2.6 * ch, 13) * 1.2 + math.max(1.7 * ch, 9) * 1.2 + 1.2 * ch)
		for i, it in ipairs(featShown) do card(g, it, true, i) isFeat[it.id] = true end
	end
	local tiers = {}
	for _, it in ipairs(items) do
		if not isFeat[it.id] then
			tiers[it.tier] = tiers[it.tier] or {}
			table.insert(tiers[it.tier], it)
		end
	end
	local keys = {}
	for k in pairs(tiers) do table.insert(keys, k) end
	table.sort(keys)
	local cellH = math.max(6.5 * ch, 22) + 2 * ch + math.max(1.8 * ch, 9) * 1.2 + math.max(1.7 * ch, 9) * 1.2 + 1.2 * ch
	for _, k in ipairs(keys) do
		local r = tiers[k]
		order += 1
		section(order, "R$" .. tostring(r[1].price), #r .. " to get")
		order += 1
		local g = grid(order, 4, cellH)
		for i, it in ipairs(r) do card(g, it, false, i) end
	end
end

local function detailButton(text, color, txtColor, enabled, order)
	local ch = S.ch
	local b = button(info, "Btn", color, enabled and 0 or 0.5)
	b.LayoutOrder = order
	b.Size = UDim2.new(1, 0, 0, math.max(8 * ch, 34))
	corner(b, UDim.new(0, 1.6 * ch))
	local band = frame(b, "Band", Color3.new(0, 0, 0), 0.78)
	band.AnchorPoint = Vector2.new(0, 1)
	band.Position = UDim2.fromScale(0, 1)
	band.Size = UDim2.new(1, 0, 0, 0.9 * ch)
	corner(band, UDim.new(0, 1.6 * ch))
	local l = label(b, "T", Enum.Font.FredokaOne, math.max(2.8 * ch, 13), txtColor, text)
	l.Size = UDim2.fromScale(1, 1)
	l.TextTransparency = enabled and 0 or 0.35
	return b
end
local function saveReady()
	local s = player:GetAttribute("SkinSaveState")
	return s ~= nil and s ~= "loading" and s ~= "loadFailed" and s ~= "noApi"
end
local function emoteSaveReady() -- v1.1
	local s = player:GetAttribute("EmoteSaveState")
	return s ~= nil and s ~= "loading" and s ~= "loadFailed" and s ~= "noApi"
end
local function drawInfo()
	clear(info)
	local ch = S.ch
	infoList.Padding = UDim.new(0, 0.9 * ch)
	local it, c = nil, nil
	if sel then it, c = findItem(sel) end
	prev.Visible = it ~= nil
	if not it then return end
	local us = US()
	local sk = us and us.get(it.id)
	local k = label(info, "Kind", Enum.Font.GothamBlack, math.max(1.7 * ch, 9), VOLT,
		("%s · R$%s%s"):format(c.kind, tostring(it.price or "?"), it.anim and " · ANIMATED" or ""))
	k.LayoutOrder = 1
	k.TextXAlignment = Enum.TextXAlignment.Left
	k.Size = UDim2.new(1, 0, 0, math.max(1.7 * ch, 9) * 1.3)
	local nS = math.max(3.6 * ch, 16)
	local n = label(info, "Name", Enum.Font.FredokaOne, nS, WHITE, it.name)
	n.LayoutOrder = 2
	n.TextXAlignment = Enum.TextXAlignment.Left
	n.Size = UDim2.new(1, 0, 0, nS * 1.1)
	local a = label(info, "All", Enum.Font.GothamBlack, math.max(1.7 * ch, 9), GREEN, "✓ WORKS ON ALL 8 DINOS")
	a.LayoutOrder = 3
	a.TextXAlignment = Enum.TextXAlignment.Left
	a.Size = UDim2.new(1, 0, 0, math.max(1.7 * ch, 9) * 1.3)
	local ln = label(info, "Line", Enum.Font.GothamBlack, math.max(1.9 * ch, 10), GREY,
		it.emote and (tostring(it.desc) .. " Every dino can do it.") or "Buy it once and every dino can wear it.")
	ln.LayoutOrder = 4
	ln.TextXAlignment = Enum.TextXAlignment.Left
	ln.TextWrapped = true
	ln.AutomaticSize = Enum.AutomaticSize.Y
	ln.Size = UDim2.new(1, 0, 0, 0)
	local credits = it.emote and 0 or tonumber(player:GetAttribute("SkinCredits_" .. tostring(sk and sk.unlock.rarity))) or 0
	local waiting = buyPendingAt ~= nil and os.clock() - buyPendingAt < BUY_WAIT
	local state, b
	if waiting then
		state = "wait"
		b = detailButton("…", YELLOW, DARK_TEXT, false, 5)
	elseif not (it.emote and emoteSaveReady() or (not it.emote and saveReady())) then
		state = "loading"
		b = detailButton("LOADING", YELLOW, DARK_TEXT, false, 5)
	elseif credits > 0 then
		state = "credit"
		b = detailButton("UNLOCK · 1 CREDIT", YELLOW, DARK_TEXT, true, 5)
	else
		state = "get"
		b = detailButton("BUY · R$" .. tostring(it.price or "?"), YELLOW, DARK_TEXT, true, 5)
	end
	player:SetAttribute("ShopLastBuy", state)
	if state == "credit" or state == "get" then
		b.Activated:Connect(function()
			press("buy:" .. it.id)
			if it.emote then -- v1.1
				local er = ReplicatedStorage:FindFirstChild("DinoEmoteRequest")
				if not er then return end
				buyPendingAt = os.clock()
				er:FireServer("buy", it.id)
				redraw()
				return
			end
			local r = ReplicatedStorage:FindFirstChild("DinoSkinRequest")
			if not r then return end
			buyPendingAt = os.clock()
			r:FireServer("buy", it.id, shownSpecies())
			redraw()
		end)
	end
end

local function layout()
	measure()
	local ch, cw, W, H = S.ch, S.cw, S.W, S.H
	local headH = math.max(11 * ch, 44)
	local leftPad = math.max(topLeftClear() + 1.6 * ch, 3 * cw)
	head.Size = UDim2.new(1, 0, 0, headH)
	headLine.Position, headLine.Size = UDim2.new(0, 0, 1, -2), UDim2.new(1, 0, 0, 2)
	local tS = math.max(4.4 * ch, 18)
	titleL.TextSize = tS
	titleL.Position, titleL.Size = UDim2.fromOffset(leftPad, 0), UDim2.new(0, 0, 1, 0)
	local closeS = math.max(7 * ch, 30)
	closeB.Position, closeB.Size = UDim2.new(1, -2.4 * cw - closeS, 0.5, -closeS / 2), UDim2.fromOffset(closeS, closeS)
	closeC.CornerRadius = UDim.new(0, 1.6 * ch)
	closeX.TextSize = closeS * 0.5
	local smallS = math.max(1.8 * ch, 9)
	timer.TextSize = smallS
	timer.Size = UDim2.fromOffset(0, smallS + 1.4 * ch)
	timerPad.PaddingLeft, timerPad.PaddingRight = UDim.new(0, 1.4 * ch), UDim.new(0, 1.4 * ch)
	timer.AnchorPoint = Vector2.new(1, 0.5)
	timer.Position = UDim2.new(1, -2.4 * cw - closeS - 1.6 * ch, 0.5, 0)
	local subX = leftPad + titleL.TextBounds.X + 2 * ch
	subL.TextSize = smallS
	subL.Position = UDim2.fromOffset(subX, 0)
	subL.Size = UDim2.new(0, math.max(W - subX - (W - timer.AbsolutePosition.X) - 2 * ch, 0), 1, 0)
	-- tabs
	local tabH = math.max(1.9 * ch, 10) + 1.8 * ch
	tabsRow.Position, tabsRow.Size = UDim2.fromOffset(2.4 * cw, headH + 1.2 * ch), UDim2.new(0.58, 0, 0, tabH)
	tabsList.Padding = UDim.new(0, ch)
	-- list (left) and preview + info (right)
	local top = headH + 1.2 * ch + tabH + 0.6 * ch
	list.Position, list.Size = UDim2.fromOffset(2.4 * cw, top), UDim2.new(0.58, 0, 1, -top - 2 * ch)
	listPad.PaddingRight = UDim.new(0, 8)
	listPad.PaddingLeft, listPad.PaddingTop = UDim.new(0, 3), UDim.new(0, 3)
	local rx = 2.4 * cw + 0.58 * W + 2 * cw
	local rw = W - rx - 2.4 * cw
	local pTop = headH + 1.2 * ch
	local pH = (H - pTop - 2 * ch) * 0.55
	prev.Position, prev.Size = UDim2.fromOffset(rx, pTop), UDim2.fromOffset(rw, pH)
	prevC.CornerRadius = UDim.new(0, 2 * ch)
	local tagS = math.max(1.6 * ch, 9)
	onTag.TextSize = tagS
	onTag.Position, onTag.Size = UDim2.fromOffset(1.4 * ch, 1.4 * ch), UDim2.fromOffset(0, tagS + 1.2 * ch)
	onC.CornerRadius = UDim.new(0, 0.8 * ch)
	onPad.PaddingLeft, onPad.PaddingRight = UDim.new(0, ch), UDim.new(0, ch)
	local arrow = math.max(6.5 * ch, 28)
	local nameW = math.max(rw - 2 * arrow - 4 * ch, 40)
	local ay = pH - arrow - 1.2 * ch
	local ax = (rw - (2 * arrow + nameW + 2 * ch)) / 2
	dPrev.Position, dPrev.Size = UDim2.fromOffset(ax, ay), UDim2.fromOffset(arrow, arrow)
	dNext.Position, dNext.Size = UDim2.fromOffset(ax + arrow + nameW + 2 * ch, ay), UDim2.fromOffset(arrow, arrow)
	dPrevC.CornerRadius, dNextC.CornerRadius = UDim.new(0, 1.2 * ch), UDim.new(0, 1.2 * ch)
	dPrevL.TextSize, dNextL.TextSize = arrow * 0.5, arrow * 0.5
	dName.TextSize = math.max(2 * ch, 10)
	dName.Position, dName.Size = UDim2.fromOffset(ax + arrow + ch, ay), UDim2.fromOffset(nameW, arrow)
	info.Position, info.Size = UDim2.fromOffset(rx, pTop + pH + 1.6 * ch), UDim2.fromOffset(rw, H - pTop - pH - 3.6 * ch)
	toast.TextSize = math.max(2.4 * ch, 12)
	toast.Position = UDim2.new(0.5, 0, 0, headH + 1.6 * ch)
	toast.Size = UDim2.fromOffset(0, math.max(2.4 * ch, 12) + 2.4 * ch)
	toastC.CornerRadius = UDim.new(0, 1.4 * ch)
	toastPad.PaddingLeft, toastPad.PaddingRight = UDim.new(0, 2.4 * ch), UDim.new(0, 2.4 * ch)
end
local function drawTabs()
	clear(tabsRow)
	local ch = S.ch
	for i, c in ipairs(CATEGORIES) do
		local on = c.id == tab
		local b = button(tabsRow, "Tab_" .. c.id, on and YELLOW or PANEL2, 0)
		b.LayoutOrder = i
		b.AutomaticSize = Enum.AutomaticSize.X
		b.Size = UDim2.new(0, 0, 1, 0)
		corner(b, UDim.new(0, 1.2 * ch))
		local l = label(b, "T", Enum.Font.FredokaOne, math.max(1.9 * ch, 10), on and DARK_TEXT or MUTED, c.name)
		l.AutomaticSize = Enum.AutomaticSize.X
		l.Size = UDim2.new(0, 0, 1, 0)
		local p = Instance.new("UIPadding")
		p.PaddingLeft, p.PaddingRight = UDim.new(0, 1.8 * ch), UDim.new(0, 1.8 * ch)
		p.Parent = b
		b.Activated:Connect(function() press("tab:" .. c.id) tab = c.id sel = nil redraw() end)
	end
end
local function updateTimer()
	local now = workspace:GetServerTimeNow()
	local left = math.max(0, 86400 - (now % 86400))
	timer.Text = ("NEW IN %dH %02dM"):format(math.floor(left / 3600), math.floor(left % 3600 / 60))
end
local function updateBadge()
	local feat = featured()
	local any = false
	for _, it in ipairs(feat) do
		local c = catOf(it.cat)
		if c and not c.owned(it) then any = true break end
	end
	player:SetAttribute("ShopBadge", any and not seenThisSession)
end

function redraw()
	if not open then return end
	layout()
	drawTabs()
	drawList()
	drawInfo()
	buildModel()
	paintModel()
	local sp = shownSpecies()
	onTag.Text = sp == species() and ("ON YOUR " .. dinoName(sp)) or ("TRYING ON " .. dinoName(sp))
	local selIt = sel and findItem(sel) -- v1.1
	wordL.Visible = selIt ~= nil and selIt.emote == true
	wordL.Text = wordL.Visible and selIt.word or ""
	dName.Text = dinoName(sp)
	updateTimer()
	subL.Text = tab == "emotes" and "Emotes you don't own yet. Every emote works on all 8 dinos." -- v1.1
		or "Skins you don't own yet. Every skin works on all 8 dinos."
	player:SetAttribute("ShopView", sp)
end

local function setOpen(on)
	if on and player:GetAttribute("InMenu") ~= true then return false end
	open = on
	gui.Enabled = on
	player:SetAttribute("ShopOpen", on)
	if on then
		seenThisSession = true
		updateBadge()
		view_sp = nil
		redraw()
	else
		toast.Visible = false
	end
	return true
end
openFn.OnInvoke = function() return setOpen(true) end
closeFn.OnInvoke = function() setOpen(false) return true end
closeB.Activated:Connect(function() press("close") setOpen(false) end)
local function stepDino(d)
	local us = US()
	if not us then return end
	local list_ = us.DINOS
	local i = table.find(list_, shownSpecies()) or 1
	local sp = list_[(i - 1 + d) % #list_ + 1]
	view_sp = sp ~= species() and sp or nil
	press("dino:" .. sp)
	redraw()
end
dPrev.Activated:Connect(function() stepDino(-1) end)
dNext.Activated:Connect(function() stepDino(1) end)

-- turning model, timer
-- v1.1: the selected emote on the preview dino (joints moved by hand: no physics in a ViewportFrame)
local emoteRig = nil
local function emotePoseModule()
	local c = player.Character
	local m = c and c:FindFirstChild("IdleAnimation") and c.IdleAnimation:FindFirstChild("EmotePose")
	m = m or (game:GetService("StarterPlayer"):FindFirstChild("StarterCharacterScripts") and game.StarterPlayer.StarterCharacterScripts:FindFirstChild("IdleAnimation")
		and game.StarterPlayer.StarterCharacterScripts.IdleAnimation:FindFirstChild("EmotePose"))
	if not m then return nil end
	local ok, r = pcall(require, m)
	return ok and r or nil
end
local function buildEmoteRig()
	emoteRig = {model = model}
	local hrp = model and model:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local js = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then table.insert(js, d) end
	end
	local done, order = {[hrp] = true}, {}
	for _ = 1, 40 do
		if #order >= #js then break end
		for _, m in ipairs(js) do
			if not done[m.Part1] and done[m.Part0] then table.insert(order, {m = m, c0 = m.C0, c1i = m.C1:Inverse()}) done[m.Part1] = true end
		end
	end
	local parts = {}
	for _, j in ipairs(order) do
		local r = j.m.Part1
		local l = {}
		for _, p in ipairs(r.Parent:GetChildren()) do
			if p:IsA("BasePart") then table.insert(l, {p, r.CFrame:ToObjectSpace(p.CFrame)}) end
		end
		parts[r] = l
	end
	local P = emotePoseModule()
	emoteRig = {model = model, hrp = hrp, base = hrp.CFrame, order = order, parts = parts, P = P, R = P and P.rig(model, nil)}
end
local emoteClock, emoteShown = 0, false
local function poseEmote(dt)
	local it = sel and findItem(sel)
	local want = open and tab == "emotes" and it ~= nil and it.emote == true and model ~= nil
	if not want and not emoteShown then return end
	if not emoteRig or emoteRig.model ~= model then buildEmoteRig() end
	local r = emoteRig
	if not (r and r.order and r.P and r.R) then return end
	local pose = {}
	if want then
		emoteClock += dt
		local cycle = it.dur + 0.8
		local et = emoteClock % cycle
		if et <= it.dur then pose = r.P.get(it.id, et / it.dur, et, r.R) or {} end
	end
	local W = {[r.hrp] = r.base}
	for _, j in ipairs(r.order) do
		local m = j.m
		local w0 = W[m.Part0]
		if w0 then
			local w1 = w0 * j.c0 * (pose[m.Name] or CFrame.identity) * j.c1i
			W[m.Part1] = w1
			for _, e in ipairs(r.parts[m.Part1]) do e[1].CFrame = w1 * e[2] end
		end
	end
	emoteShown = want
end
RunService.RenderStepped:Connect(function(dt)
	if not open then return end
	poseEmote(dt)
	orbit += dt * 0.5
	cam.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(orbit), 0.3, math.cos(orbit)).Unit * radius, center)
end)
task.spawn(function()
	while true do
		task.wait(20)
		if open then updateTimer() end
		updateBadge()
	end
end)

-- data changes
local queued = false
local function queue()
	if queued or not open then return end
	queued = true
	task.defer(function() queued = false redraw() end)
end
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(queue)
player.AttributeChanged:Connect(function(name)
	if name == "SkinOwnedU" or name == "SkinAllUnlocked" or name:sub(1, 11) == "SkinCredits" or name:sub(1, 9) == "SkinPrice"
		or name == "SkinSaveState" or name == "EmoteOwned" or name == "EmoteAllUnlocked" or name == "EmoteSaveState" then -- v1.1 Emote*
		updateBadge()
		queue()
	end
	if name == "SkinServerResultAt" then
		local res = player:GetAttribute("SkinServerResult")
		if res ~= "prompted" then buyPendingAt = nil end
		if open then
			local us = US()
			if res == "bought" then
				local sk = us and us.get(player:GetAttribute("SkinLastBought"))
				if sk then showToast(string.upper(sk.name) .. " UNLOCKED · ON " .. dinoName(shownSpecies())) end
			elseif res == "owned" then
				showToast("ALREADY YOURS")
			elseif res == "promptFailed" or res == "noProduct" or res == "notLoaded" then
				showToast("TRY AGAIN IN A MOMENT")
			end
		end
		queue()
	end
	if name == "EmoteResult" then -- v1.1
		local res = player:GetAttribute("EmoteResult")
		if res ~= "prompted" then buyPendingAt = nil end
		if open and tab == "emotes" then
			local ec = EC()
			if res == "bought" then
				local e = ec and ec.get(player:GetAttribute("EmoteUnlocked"))
				showToast(e and (string.upper(e.name) .. " UNLOCKED") or "UNLOCKED")
			elseif res == "owned" then
				showToast("ALREADY YOURS")
			elseif res == "promptFailed" or res == "noProduct" or res == "notLoaded" then
				showToast("TRY AGAIN IN A MOMENT")
			end
		end
		queue()
	end
	if name == "InMenu" and player:GetAttribute("InMenu") ~= true and open then setOpen(false) end
end)
task.defer(updateBadge)
