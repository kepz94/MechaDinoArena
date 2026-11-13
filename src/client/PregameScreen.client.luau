-- PregameScreen v1.0 (Mecha Dino Arena) — the pre-game LINEUP, SELECT (dino -> mecha parts) and INTRO screens, PC and phone
-- (LocalScript, StarterPlayerScripts). MDA-486 / 487 / 488, plan docs/plans/PREGAME_LINEUP_v1.0.md T10-T12, ADR-012, mockup
-- docs/mockups/pregame_v0.4.html (Kepu 2026-11-12: layout B; "show the 3D Dino model instead of that badge. Then when you select
-- the Dino it transitions to the mecha parts with the previews on that same screen"; D2 the same dino twice is allowed).
-- Reads ReplicatedStorage.Practice (PracticeServer 1.9): PgPhase ("lineup" / "intro" / ""), PgEndsAt, PrStartAt, PrRoster (JSON
--   {A, B}; slots {kind, name, userId, species, w, l, lv, ready, loadout, tier}), PrPrivate; player PrInLobby, PrSide, PgReady,
--   DinoSpecies, SkillSlot1..4, SkillPath_<id>. 3D: ReplicatedStorage.PregameModels.<Dino>.Body / Parts.<id> (PregameModels 1.0),
--   PregameModels.StatSheet (class, starting points, main attack / jump names). Parts: ReplicatedStorage.SkillShared.SkillTree
--   (names, step I text, BUTTONS, soon, seesPath). Roles: ReplicatedStorage.PracticeShared.PracticeRules JOB_OF (hold = HOLDER,
--   duel = FIGHTER, guard = RANGED).
-- ScreenGui "PregameScreen" (DisplayOrder 45, over PracticeLobby 41 and the menu 40; IgnoreGuiInset; ResetOnSpawn false), shown
--   while PrInLobby == true and PgPhase is "lineup" or "intro". The screen is drawn on a design canvas 1000 wide (PC 1000 x 562,
--   16:9; phone (screen wider than 1.9:1) 1000 x 463) scaled to fit the screen (UIScale); 10 px = 1cqw of the mockup.
-- LINEUP: title LINEUP (bots: yellow, else orange), "HARDPOINT VS BOTS · BLUE TEAM", the clock (PrStartAt; red at 5 s) and its bar.
--   Four columns, one per slot of your side: a ViewportFrame with a pedestal (yellow ring for you, else blue) and the slot's dino
--   with its equipped parts (dropped parts left out) swaying; a plaque: name, W-L (humans; "-" when not loaded) or "<TIER> BOT",
--   win % and LV, dino, role, READY / SELECTING..., 4 slot pips. Your plaque / column and the SELECT DINO button open SELECT.
-- SELECT, step DINO: team strip (your side's other slots: thumbnail, name, dino · role; TEAM NEEDS A <role> / TEAM COVERED),
--   roster by role (HOLDER / FIGHTER / RANGED; "TEAM NEEDS" or "n ON TEAM"; teammates' names on a tile; nothing is blocked),
--   the picked dino large in the middle (turns by itself; drag to spin), class · role and its name, its 5 starting points as
--   bars, MAIN ATTACK (CLICK / TAP) and JUMP. BACK -> LINEUP; SELECT <DINO> -> DinoSpeciesRequest when it is not your dino,
--   then step PARTS on the same screen: the roster slides away and the dino takes the space.
--   Step PARTS: 4 slots (key per slot as the Lab: R C T V, touch R C R▼ C▼; tap one to pick it), the dino's mecha parts
--   (the Lab's MECHA ABILITIES) with their step I text and SLOT n / EQUIP / BUY IN THE LAB. Pointing at a part (or tapping one
--   you don't own) shows it on the dino and turns the dino to it; tapping an owned one -> SkillRequest("slot", slot, id).
--   Equipped parts stay on the model. Until your dino is the picked one: "LOADING DINO..." and no equip. CHANGE DINO -> step
--   DINO; CONFIRM -> PracticeRequest("ready") and LINEUP. Opening SELECT while ready sends "unready".
-- INTRO (PgPhase "intro", t = PracticeRules.PG_INTRO - time left): the lineup columns of your side, each lit in turn for
--   BLUE_EACH (1.1) s (the others dimmed) with "BLUE TEAM · n OF 4", the name and "DINO · W-L · %" (bots: tier); then the red
--   side's columns (red rings) with "RED TEAM" and its record (bots: "2 ELITE · 2 HARD"); then VS: both teams as cards, the
--   team records, and "CAPTURE AND HOLD THE HARDPOINT".
-- Switches (script attributes): PregameScreenEnabled (default true, read per frame; false -> never shown, PracticeLobby shows
--   instead), PregameFlatIcons (default false, read when columns / tiles are built: true -> name boxes instead of 3D).
-- Diagnostics: PregameScreenVersion, PregameScreenState ("hidden" / "lineup" / "select" / "intro"), PregameScreenStep ("dino" /
--   "parts"), PregameScreenLastPress, PregameScreenDraft (the dino picked on SELECT).
-- v1.1 (Arena 4v4, MDA-491, plan docs/plans/PREGAME_LINEUP_v1.0.md Part 2): ReplicatedStorage.Practice PrArena == true
--   (PracticeServer 1.10) -> the screens say "ARENA · HARDPOINT" in Arena orange (else as 1.0: a private match "HARDPOINT VS
--   BOTS" in yellow, a public one "HARDPOINT PRACTICE").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 Arena match look
VERSION = "1.2" -- v1.2 SAVED LOADOUT tag
-- v1.2 (saved loadout, MDA-504, plan docs/plans/PREMATCH_AND_SAVED_LOADOUT_v1.0.md B3, mockup docs/mockups/save_loadout_v0.1.html
--   "PRE-GAME"): on the SELECT view's parts step, "SAVED LOADOUT" (green, 10, right-aligned, left of the clock) while
--   SkillLoadoutFrom == "saved" (SkillServer 1.12 put your saved loadout in) and SkillSlot1..4 equal SkillSavedLoadout.
--   Hidden otherwise. Switch: script attribute PregameSavedTagEnabled (default true, read per draw; false = 1.1).
script:SetAttribute("PregameScreenVersion", VERSION)
for k, v in pairs({PregameScreenEnabled = true, PregameFlatIcons = false}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("Practice", 60)
if not state then return end -- no practice match on this server
local request = ReplicatedStorage:WaitForChild("PracticeRequest", 30)
local speciesRemote = ReplicatedStorage:WaitForChild("DinoSpeciesRequest", 30)
local skillRemote = ReplicatedStorage:WaitForChild("SkillRequest", 30)
local skillShared = ReplicatedStorage:WaitForChild("SkillShared", 30)
local ST = skillShared and require(skillShared:WaitForChild("SkillTree"))
local prShared = ReplicatedStorage:WaitForChild("PracticeShared", 30)
local PR = prShared and prShared:FindFirstChild("PracticeRules") and require(prShared.PracticeRules) or {}
local models = ReplicatedStorage:WaitForChild("PregameModels", 30)
local Sheet = nil
if models then
	for _, d in ipairs({"Raptor", "TRex", "Pachy", "Herrera", "Teno", "Therizino", "Dilo", "Troodon"}) do models:WaitForChild(d, 20) end
	local ss = models:WaitForChild("StatSheet", 10)
	if ss then pcall(function() Sheet = require(ss) end) end
end

-- ---------- look ----------
local C = {
	ink = Color3.fromRGB(13, 18, 24), panel = Color3.fromRGB(21, 29, 39), panel2 = Color3.fromRGB(27, 37, 50),
	line = Color3.fromRGB(38, 50, 67), text = Color3.fromRGB(231, 237, 245), muted = Color3.fromRGB(147, 162, 182),
	blue = Color3.fromRGB(90, 160, 255), red = Color3.fromRGB(224, 40, 74), yellow = Color3.fromRGB(255, 200, 50),
	green = Color3.fromRGB(70, 224, 138), bots = Color3.fromRGB(255, 214, 64), arena = Color3.fromRGB(255, 155, 46),
	volt = Color3.fromRGB(127, 233, 255), dark = Color3.fromRGB(27, 20, 5), slate = Color3.fromRGB(58, 70, 86),
}
local LOUD = Enum.Font.GothamBlack -- FontSwap turns it Silkscreen
local BODY = Enum.Font.Gotham
local ORDER = {"Raptor", "TRex", "Pachy", "Herrera", "Teno", "Therizino", "Dilo", "Troodon"}
local ROLE_OF_JOB = {hold = "HOLDER", duel = "FIGHTER", guard = "RANGED"}
local ROLE_GROUPS = {{"HOLDER", {"Pachy", "Teno"}}, {"FIGHTER", {"Raptor", "TRex", "Herrera", "Therizino"}}, {"RANGED", {"Dilo", "Troodon"}}}
local STAT_N = {"Health", "Attack", "Defense", "Speed", "Support"}
local SLOT_KEYS = UserInputService.TouchEnabled and {"R", "C", "R▼", "C▼"} or {"R", "C", "T", "V"}
local BLUE_EACH, RED_SHOW = 1.1, 2.0
local function nameOf(d) return d == "TRex" and "T-REX" or string.upper(tostring(d or "")) end
local function roleOf(d)
	local j = PR.JOB_OF and PR.JOB_OF[d]
	return ROLE_OF_JOB[j or ""] or "FIGHTER"
end
local function now() return workspace:GetServerTimeNow() end
local function press(id) script:SetAttribute("PregameScreenLastPress", id) end

-- ---------- gui scaffolding ----------
local pg = player:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("PregameScreen")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "PregameScreen"
gui.DisplayOrder = 45
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = pg

local back = Instance.new("Frame")
back.Name = "Backdrop"
back.Size = UDim2.fromScale(1, 1)
back.BackgroundColor3 = Color3.fromRGB(8, 11, 16)
back.BorderSizePixel = 0
back.Parent = gui
local canvas = Instance.new("Frame")
canvas.Name = "Canvas"
canvas.AnchorPoint = Vector2.new(0.5, 0.5)
canvas.Position = UDim2.fromScale(0.5, 0.5)
canvas.Size = UDim2.fromOffset(1000, 562)
canvas.BackgroundColor3 = C.ink
canvas.BorderSizePixel = 0
canvas.ClipsDescendants = true
canvas.Parent = back
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(29, 38, 56), Color3.fromRGB(11, 15, 21))
grad.Rotation = 90
grad.Parent = canvas
local uiScale = Instance.new("UIScale")
uiScale.Parent = canvas

local H = 562
local phone = false
do -- the screen shape at start (phone: wider than 1.9:1)
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	phone = vp.X / math.max(1, vp.Y) >= 1.9
end
local TF = phone and 1.4 or 1 -- text factor: phones show the same canvas smaller, so text is drawn bigger

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(p, r) return new("UICorner", {CornerRadius = UDim.new(0, r or 6)}, p) end
local function stroke(p, color, th)
	return new("UIStroke", {ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = color or C.line, Thickness = th or 1.5}, p)
end
local function text(parent, props)
	local l = new("TextLabel", {BackgroundTransparency = 1, Font = props.font or LOUD, TextColor3 = props.color or C.text,
		TextSize = (props.size or 10) * TF, Text = props.text or "", TextXAlignment = props.x or Enum.TextXAlignment.Center,
		TextYAlignment = props.y or Enum.TextYAlignment.Center, Size = props.sz or UDim2.new(1, 0, 0, (props.size or 10) * TF + 4),
		Position = props.pos or UDim2.new(), TextWrapped = props.wrap or false, TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = props.anchor or Vector2.zero, Name = props.name or "Text", ZIndex = props.z or 1}, parent)
	return l
end
local function button(parent, label, primary, props)
	local b = new("TextButton", {AutoButtonColor = true, Font = LOUD, Text = label, TextSize = props.size or 14,
		TextColor3 = primary and C.dark or C.text, BackgroundColor3 = primary and C.yellow or Color3.fromRGB(13, 18, 24),
		BackgroundTransparency = primary and 0 or 0.25, Size = props.sz or UDim2.fromOffset(200, 40),
		Position = props.pos or UDim2.new(), AnchorPoint = props.anchor or Vector2.zero, Name = props.name or "Button", ZIndex = props.z or 3},
		parent)
	corner(b, 8)
	if not primary then stroke(b, Color3.fromRGB(68, 83, 106), 1.8) end
	return b
end

-- views
local views = {}
for _, n in ipairs({"Lineup", "Select", "Intro"}) do
	views[n] = new("Frame", {Name = n, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false}, canvas)
end

-- top bar (one per view)
local function topBar(v)
	local t = {}
	t.title = text(v, {text = "LINEUP", size = 23, x = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(30, 18), sz = UDim2.fromOffset(500, 26)})
	t.sub = text(v, {text = "", size = 10.5, color = Color3.fromRGB(201, 212, 226), x = Enum.TextXAlignment.Left,
		pos = UDim2.fromOffset(30, 46), sz = UDim2.fromOffset(600, 14)})
	t.clock = text(v, {text = "0:30", size = 32, x = Enum.TextXAlignment.Right, pos = UDim2.new(1, -30, 0, 14), anchor = Vector2.new(1, 0),
		sz = UDim2.fromOffset(200, 34)})
	t.note = text(v, {text = "", size = 9, color = C.muted, x = Enum.TextXAlignment.Right, pos = UDim2.new(1, -30, 0, 48),
		anchor = Vector2.new(1, 0), sz = UDim2.fromOffset(300, 12)})
	t.bar = new("Frame", {Name = "Bar", Position = UDim2.fromOffset(30, 66), Size = UDim2.new(1, -60, 0, 4),
		BackgroundColor3 = Color3.fromRGB(40, 46, 56), BorderSizePixel = 0}, v)
	corner(t.bar, 2)
	t.fill = new("Frame", {Name = "Fill", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = C.bots}, t.bar)
	corner(t.fill, 2)
	return t
end
local tops = {Lineup = topBar(views.Lineup), Select = topBar(views.Select)}

-- ---------- 3D ----------
local VIEW_AMBIENT, VIEW_LIGHT = Color3.fromRGB(150, 160, 180), Color3.fromRGB(255, 255, 255)
local function bodyOf(d)
	local f = models and models:FindFirstChild(d or "")
	return f and f:FindFirstChild("Body")
end
local function partModel(d, id)
	local f = models and models:FindFirstChild(d or "")
	local parts = f and f:FindFirstChild("Parts")
	return parts and parts:FindFirstChild(id or "")
end
local function flat() return script:GetAttribute("PregameFlatIcons") == true or not models end

-- a dino rig: a Model holding the body + parts, with its pivot under the feet centre
local function rig(d, ids)
	local body = bodyOf(d)
	if not body then return nil end
	local m = Instance.new("Model")
	m.Name = "Rig_" .. d
	local b = body:Clone()
	b.Parent = m
	for _, id in ipairs(ids or {}) do
		local p = id ~= "" and partModel(d, id)
		if p and p:GetAttribute("Free") ~= true then p:Clone().Parent = m end
	end
	local size = body:GetAttribute("BodySize") or select(2, body:GetBoundingBox())
	local minY = body:GetAttribute("BodyMinY") or (body:GetBoundingBox().Position.Y - size.Y / 2)
	local cf = body:GetBoundingBox()
	m.WorldPivot = CFrame.new(cf.Position.X, minY, cf.Position.Z)
	m:SetAttribute("RigH", size.Y)
	m:SetAttribute("RigMax", math.max(size.X, size.Y * 1.35, size.Z))
	return m
end
local function pedestal(parent, radius, ringColor)
	local base = new("Part", {Name = "Pedestal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(radius * 0.18, radius * 2.2, radius * 2.2),
		CFrame = CFrame.new(0, -radius * 0.09, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(28, 38, 54),
		Material = Enum.Material.SmoothPlastic, Anchored = true}, parent)
	local ring = new("Part", {Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(radius * 0.02, radius * 2.32, radius * 2.32),
		CFrame = CFrame.new(0, -radius * 0.17, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = ringColor,
		Material = Enum.Material.Neon, Anchored = true}, parent)
	return base, ring
end
-- a viewport showing one dino on a pedestal, the camera fitted to the dino
local function dinoView(parent, props)
	local vf = new("ViewportFrame", {Name = props.name or "View", BackgroundTransparency = 1, Size = props.sz or UDim2.fromScale(1, 1),
		Position = props.pos or UDim2.new(), Ambient = VIEW_AMBIENT, LightColor = VIEW_LIGHT,
		LightDirection = Vector3.new(-0.5, -1, -0.6), ZIndex = props.z or 1}, parent)
	local cam = new("Camera", {FieldOfView = props.fov or 30}, vf)
	vf.CurrentCamera = cam
	local o = {vf = vf, cam = cam, d = nil, key = nil, yaw = props.yaw or (math.pi + 0.8), dist = 1, h = 1, pedestal = props.pedestal}
	function o.set(d, ids, ringColor)
		local key = tostring(d) .. "|" .. table.concat(ids or {}, ",") .. "|" .. tostring(ringColor)
		if key == o.key then return end
		o.d = d
		for _, ch in ipairs(vf:GetChildren()) do if not ch:IsA("Camera") then ch:Destroy() end end
		o.model = nil
		local m = d and rig(d, ids)
		if not m then o.key = nil return end -- the models may not be built yet: try again on the next set
		o.key, o.pivot0 = key, m.WorldPivot
		local mx, h = m:GetAttribute("RigMax"), m:GetAttribute("RigH")
		o.dist, o.h, o.max = mx * (props.fit or 2.6), h, mx
		if o.pedestal ~= false then o.base, o.ring = pedestal(vf, mx * 0.42, ringColor or C.blue) end
		m.Parent = vf
		o.model = m
		o.place()
	end
	function o.place()
		if not o.model then return end
		o.model:PivotTo(CFrame.Angles(0, o.yaw, 0))
		local ty = o.h * (props.look or 0.42)
		local d = o.dist
		cam.CFrame = CFrame.lookAt(Vector3.new(0, ty + d * (props.tilt or 0.22), d), Vector3.new(0, ty, 0))
	end
	return o
end

-- static thumbnails (never move: rendered once)
local function thumb(parent, d, props)
	if flat() then
		local f = new("Frame", {BackgroundColor3 = C.panel2, Size = props.sz or UDim2.fromScale(1, 1), Position = props.pos or UDim2.new(),
			Name = "Thumb"}, parent)
		corner(f, 4)
		text(f, {text = d and nameOf(d) or "?", size = 9, color = C.muted, sz = UDim2.fromScale(1, 1)})
		return f
	end
	local o = dinoView(parent, {sz = props.sz, pos = props.pos, pedestal = false, fit = 2.2, look = 0.45, tilt = 0.18, name = "Thumb",
		yaw = math.pi + 0.75})
	o.set(d, {})
	return o.vf
end

-- ---------- data ----------
local roster = {A = {}, B = {}}
local function readRoster()
	local ok, r = pcall(function() return HttpService:JSONDecode(state:GetAttribute("PrRoster") or "{}") end)
	roster = (ok and type(r) == "table") and r or {}
	roster.A, roster.B = roster.A or {}, roster.B or {}
end
local function mySide() return player:GetAttribute("PrSide") == "B" and "B" or "A" end
local function otherSide() return mySide() == "A" and "B" or "A" end
local function isMe(e) return e and e.kind == "human" and e.userId == player.UserId end
local function myDino()
	local c = player.Character
	local sp = c and c:GetAttribute("Species")
	if type(sp) == "string" and sp ~= "" then return sp end
	sp = player:GetAttribute("DinoSpecies")
	return (type(sp) == "string" and sp ~= "") and sp or "TRex"
end
local function myLoadout()
	local t = {}
	for n = 1, 4 do
		local v = player:GetAttribute("SkillSlot" .. n)
		t[n] = (type(v) == "string") and v or ""
	end
	return t
end
local function stepsOf(id) return tonumber(player:GetAttribute("SkillPath_" .. id)) or 0 end
local function partsFor(d)
	local out = {}
	if not ST then return out end
	for _, a in ipairs(ST.AREAS or {}) do
		local ps = ST.pathsFor and ST.pathsFor(a.id, d) or a.paths
		for _, p in ipairs(ps) do
			if p.mech == true and ST.BUTTONS[p.id] == true and not p.soon then table.insert(out, p.id) end
		end
	end
	return out
end
local function owned(id, d)
	local p = ST and ST.PATHS[id]
	return p ~= nil and stepsOf(id) >= 1 and (not ST.seesPath or ST.seesPath(p, d))
end
local function partName(id) local p = ST and ST.PATHS[id] return p and p.name or id end
local function partText(id)
	local p = ST and ST.PATHS[id]
	local s = p and p.steps and p.steps[1]
	if type(s) ~= "string" then return "" end
	s = s:gsub("^Button:%s*", ""):gsub("^Passive:%s*", "")
	return s
end
local function pct(w, l)
	w, l = tonumber(w) or 0, tonumber(l) or 0
	if w + l == 0 then return 0 end
	return math.floor(100 * w / (w + l) + 0.5)
end
local function recordOf(e)
	if e.kind == "bot" then return (e.tier and string.upper(e.tier) or "") .. " BOT", "" end
	if e.w == nil or e.l == nil then return "-", "LV " .. tostring(e.lv or "-") end
	return ("%d-%d"):format(e.w, e.l), ("%d%% WINS · LV %s"):format(pct(e.w, e.l), tostring(e.lv or "-"))
end
local function slotDino(e) return isMe(e) and myDino() or e.species end
local function slotLoadout(e) return isMe(e) and myLoadout() or (e.loadout or {}) end
local function modeColor()
	if state:GetAttribute("PrArena") == true then return C.arena end -- v1.1
	return state:GetAttribute("PrPrivate") == true and C.bots or C.arena
end
local function modeLine()
	if state:GetAttribute("PrArena") == true then return "ARENA · HARDPOINT" end -- v1.1
	return state:GetAttribute("PrPrivate") == true and "HARDPOINT VS BOTS" or "HARDPOINT PRACTICE"
end

-- ---------- LINEUP ----------
local L = views.Lineup
local cols = {}
local function colRect(i)
	local top, viewH, plaqueY = 74, phone and 214 or 268, phone and 268 or 336
	return 50 + (i - 1) * 225, top, viewH, plaqueY
end
for i = 1, 4 do
	local col = {}
	local x, top, viewH, py = colRect(i)
	col.frame = new("Frame", {Name = "Col" .. i, BackgroundTransparency = 1, Position = UDim2.fromOffset(x, top), Size = UDim2.fromOffset(225, viewH)}, L)
	col.click = new("TextButton", {Name = "Hit", BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 4}, col.frame)
	col.plaque = new("TextButton", {Name = "Plaque" .. i, AutoButtonColor = false, Text = "", BackgroundColor3 = Color3.fromRGB(17, 24, 33),
		BackgroundTransparency = 0.08, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(x + 112, py), Size = UDim2.fromOffset(190, 118), ZIndex = 5}, L)
	corner(col.plaque, 6)
	col.stroke = stroke(col.plaque, C.line, 1.5)
	local function row(name, y, size, color, font)
		return text(col.plaque, {name = name, size = size, color = color, font = font, pos = UDim2.fromOffset(6, y), sz = UDim2.new(1, -12, 0, size + 3), z = 6})
	end
	col.pn = row("Name", 5, 10, C.text)
	col.wl = row("Record", 18, 16.5, C.text)
	col.pct = row("Pct", 37, 6.5, C.muted)
	col.dn = row("Dino", 49, 8, Color3.fromRGB(201, 212, 226))
	col.role = row("Role", 60, 6.5, C.bots)
	col.st = row("Ready", 72, 7.5, C.muted)
	col.pips = new("Frame", {Name = "Pips", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(56, 12), ZIndex = 6}, col.plaque)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), HorizontalAlignment = Enum.HorizontalAlignment.Center}, col.pips)
	col.pip = {}
	for k = 1, 4 do
		col.pip[k] = new("Frame", {BackgroundColor3 = Color3.fromRGB(43, 55, 71), BorderSizePixel = 0, Size = UDim2.fromOffset(11, 11), ZIndex = 6}, col.pips)
		corner(col.pip[k], 3)
	end
	if phone then -- phones: name, record, ready and the pips only
		col.pct.Visible, col.dn.Visible, col.role.Visible = false, false, false
		col.wl.Position, col.st.Position = UDim2.fromOffset(6, 22), UDim2.fromOffset(6, 50)
		col.pips.Position = UDim2.new(0.5, 0, 0, 72)
		col.plaque.Size = UDim2.fromOffset(190, 92)
	end
	col.tap = text(L, {name = "Tap" .. i, text = "TAP TO SELECT", size = 8, color = C.dark, anchor = Vector2.new(0.5, 1),
		pos = UDim2.fromOffset(x + 112, top + 14), sz = UDim2.fromOffset(110, 16), z = 6})
	col.tap.BackgroundTransparency, col.tap.BackgroundColor3 = 0, C.yellow
	corner(col.tap, 4)
	col.view = nil
	col.flat = nil
	cols[i] = col
end
local cta = button(L, "SELECT DINO", true, {sz = UDim2.fromOffset(190, 40), anchor = Vector2.new(0.5, 1), pos = UDim2.new(0.5, 0, 1, -16), name = "Select", size = 14})
local allReadyLbl = text(L, {text = "ALL READY · STARTING", size = 10, color = C.green, anchor = Vector2.new(0, 1),
	pos = UDim2.new(0.5, 110, 1, -26), sz = UDim2.fromOffset(200, 14), x = Enum.TextXAlignment.Left})

local function setColumn(col, e, ringColor, me)
	if not e then col.frame.Visible, col.plaque.Visible = false, false return end
	col.frame.Visible, col.plaque.Visible = true, true
	local d, lo = slotDino(e), slotLoadout(e)
	if flat() then
		if not col.flat then
			col.flat = new("TextLabel", {BackgroundColor3 = C.panel2, Size = UDim2.new(0.7, 0, 0.6, 0), Position = UDim2.fromScale(0.15, 0.25),
				Font = LOUD, TextSize = 16, TextColor3 = C.text, Name = "Flat"}, col.frame)
			corner(col.flat, 8)
		end
		col.flat.Text = nameOf(d)
	else
		if not col.view then col.view = dinoView(col.frame, {name = "View", fov = 30, fit = 2.55}) end
		col.view.set(d, lo, ringColor)
	end
	col.pn.Text = me and "YOU" or tostring(e.name or "")
	local rec, sub = recordOf(e)
	col.wl.Text, col.pct.Text = rec, sub
	col.wl.TextSize = (e.kind == "bot" and 11 or 16.5) * TF
	col.dn.Text, col.role.Text = nameOf(d), roleOf(d)
	col.role.TextColor3 = modeColor()
	local ready = e.kind == "bot" or e.ready == true
	col.st.Text = ready and "READY" or "SELECTING..."
	col.st.TextColor3 = ready and C.green or C.muted
	for k = 1, 4 do col.pip[k].BackgroundColor3 = (lo[k] and lo[k] ~= "") and C.volt or Color3.fromRGB(43, 55, 71) end
	col.stroke.Color = me and C.yellow or C.line
	col.tap.Visible = me
	col.tap.Text = player:GetAttribute("PgReady") == true and "TAP TO CHANGE" or "TAP TO SELECT"
	col.plaque.Active = me
end

-- ---------- SELECT ----------
local S = views.Select
local sel = {step = "dino", draft = nil, act = 1, ghost = nil, ghostId = nil, drag = nil, auto = true, yawTo = nil}
local strip = new("Frame", {Name = "TeamStrip", BackgroundTransparency = 1, Position = UDim2.fromOffset(30, 80), Size = UDim2.new(1, -60, 0, 30)}, S)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 7), VerticalAlignment = Enum.VerticalAlignment.Center}, strip)
local needsLbl = text(S, {text = "", size = 8.2, color = C.yellow, x = Enum.TextXAlignment.Right, anchor = Vector2.new(1, 0),
	pos = UDim2.new(1, -30, 0, 88), sz = UDim2.fromOffset(260, 14)})

local PANE_H = phone and 280 or 370
local roster3 = new("Frame", {Name = "Roster", BackgroundTransparency = 1, Position = UDim2.fromOffset(30, 122), Size = UDim2.fromOffset(185, PANE_H)}, S)
new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, roster3)
local showPane = new("Frame", {Name = "Show", BackgroundTransparency = 1, Position = UDim2.fromOffset(225, 122), Size = UDim2.fromOffset(415, PANE_H), ClipsDescendants = true}, S)
local infoPane = new("Frame", {Name = "Info", BackgroundTransparency = 1, Position = UDim2.new(1, -350, 0, 122), Size = UDim2.fromOffset(320, PANE_H)}, S)
local show = dinoView(showPane, {name = "Showcase", fov = 28, fit = 2.35, look = 0.42, tilt = 0.2, yaw = math.pi + 0.75, z = 1})
local cls = text(showPane, {text = "", size = 9, color = C.bots, pos = UDim2.fromOffset(0, 2), z = 2})
local dname = text(showPane, {text = "", size = 32, pos = UDim2.fromOffset(0, 14), sz = UDim2.new(1, 0, 0, 36), z = 2})
local hint = text(showPane, {text = "DRAG TO SPIN", size = 7, color = C.muted, anchor = Vector2.new(0, 1), pos = UDim2.new(0, 0, 1, -4), z = 2})
local acts = new("Frame", {Name = "Acts", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(440, 40)}, S)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center}, acts)
local backBtn = button(acts, "BACK", false, {sz = UDim2.fromOffset(150, 40), name = "Back"})
local goBtn = button(acts, "SELECT", true, {sz = UDim2.fromOffset(240, 40), name = "Go"})
local toast = text(S, {text = "", size = 9, anchor = Vector2.new(0.5, 1), pos = UDim2.new(0.5, 0, 1, -70), sz = UDim2.fromOffset(360, 22), z = 8})
toast.BackgroundTransparency, toast.BackgroundColor3, toast.Visible = 0, Color3.fromRGB(15, 21, 29), false
corner(toast, 5)
stroke(toast, C.red, 1.5)
local toastUntil = 0
local function showToast(msg) toast.Text = msg toast.Visible = true toastUntil = os.clock() + 1.8 end

local function teamRoles()
	local c = {HOLDER = 0, FIGHTER = 0, RANGED = 0}
	for _, e in ipairs(roster[mySide()] or {}) do
		if not isMe(e) then c[roleOf(e.species)] += 1 end
	end
	if sel.draft then c[roleOf(sel.draft)] += 1 end
	return c
end
local function mateNamesOn(d)
	local n = {}
	for _, e in ipairs(roster[mySide()] or {}) do
		if not isMe(e) and e.species == d then table.insert(n, string.upper(tostring(e.name))) end
	end
	return table.concat(n, " · ")
end

-- the tile widgets (built once; thumbnails render once)
local tiles = {}
local groupHead = {}
for gi, g in ipairs(ROLE_GROUPS) do
	local grp = new("Frame", {Name = "Group_" .. g[1], BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = gi}, roster3)
	local head = new("Frame", {Name = "Head", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14)}, grp)
	text(head, {text = g[1], size = 7.4, color = C.muted, x = Enum.TextXAlignment.Left, sz = UDim2.fromScale(1, 1)})
	groupHead[g[1]] = text(head, {text = "", size = 7.4, color = C.muted, x = Enum.TextXAlignment.Right, sz = UDim2.fromScale(1, 1)})
	new("Frame", {BackgroundColor3 = C.line, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1)}, head)
	local grid = new("Frame", {Name = "Tiles", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, grp)
	new("UIGridLayout", {CellSize = UDim2.fromOffset(88, phone and 44 or 78), CellPadding = UDim2.fromOffset(5, 5), SortOrder = Enum.SortOrder.LayoutOrder}, grid)
	for k, d in ipairs(g[2]) do
		local t = new("TextButton", {Name = d, AutoButtonColor = false, Text = "", BackgroundColor3 = C.panel2, LayoutOrder = k}, grid)
		corner(t, 6)
		local s = stroke(t, C.line, 1.8)
		thumb(t, d, {sz = UDim2.new(1, -4, 1, -16), pos = UDim2.fromOffset(2, 2)})
		text(t, {text = nameOf(d), size = 7.2, anchor = Vector2.new(0, 1), pos = UDim2.new(0, 0, 1, -2), sz = UDim2.new(1, 0, 0, 11), z = 2})
		local tag = text(t, {text = "", size = 5.5, color = C.blue, x = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(4, 2), sz = UDim2.new(1, -8, 0, 8), z = 3})
		tiles[d] = {b = t, s = s, tag = tag}
	end
end

-- info panes
local info = {dino = new("Frame", {Name = "DinoInfo", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)}, infoPane),
	parts = new("Frame", {Name = "PartsInfo", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false}, infoPane)}
do
	local box = new("Frame", {Name = "Stats", BackgroundColor3 = C.panel, BackgroundTransparency = 0.14, Size = UDim2.new(1, 0, 0, 104)}, info.dino)
	corner(box, 9) stroke(box, C.line, 1.5)
	info.bars = {}
	for i, n in ipairs(STAT_N) do
		local y = 10 + (i - 1) * 18
		text(box, {text = string.upper(n), size = 7, color = C.muted, x = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(10, y), sz = UDim2.fromOffset(70, 12)})
		local bar = new("Frame", {BackgroundColor3 = Color3.fromRGB(28, 38, 51), BorderSizePixel = 0, Position = UDim2.fromOffset(84, y + 2), Size = UDim2.new(1, -124, 0, 7)}, box)
		corner(bar, 4)
		local fill = new("Frame", {BackgroundColor3 = C.volt, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1)}, bar)
		corner(fill, 4)
		local v = text(box, {text = "", size = 7.5, x = Enum.TextXAlignment.Right, anchor = Vector2.new(1, 0), pos = UDim2.new(1, -10, 0, y), sz = UDim2.fromOffset(24, 12)})
		info.bars[i] = {fill = fill, v = v}
	end
	local function abil(y, icon, iconColor, key)
		local f = new("Frame", {BackgroundColor3 = Color3.fromRGB(17, 24, 33), Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 40)}, info.dino)
		corner(f, 6) stroke(f, C.line, 1.5)
		local ic = new("TextLabel", {BackgroundColor3 = iconColor, Font = LOUD, Text = icon, TextSize = 12, TextColor3 = C.ink, Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(28, 28)}, f)
		corner(ic, 5)
		local n = text(f, {text = "", size = 8.6, x = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(42, 0), sz = UDim2.new(1, -120, 1, 0)})
		local k = text(f, {text = key, size = 6.6, color = C.muted, x = Enum.TextXAlignment.Right, anchor = Vector2.new(1, 0), pos = UDim2.new(1, -8, 0, 0), sz = UDim2.fromOffset(80, 40)})
		return n
	end
	text(info.dino, {text = "MAIN ATTACK", size = 7.6, color = C.muted, x = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(0, 112), sz = UDim2.new(1, 0, 0, 12)})
	info.main = abil(128, "A", C.yellow, UserInputService.TouchEnabled and "TAP" or "CLICK")
	info.jump = abil(174, "J", C.slate, "JUMP")
	info.partsHead = text(info.dino, {text = "", size = 7.6, color = C.muted, x = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(0, 222), sz = UDim2.new(1, 0, 0, 12)})
end
do
	text(info.parts, {name = "SlotsHead", text = "SLOTS", size = 7.6, color = C.muted, x = Enum.TextXAlignment.Left, sz = UDim2.new(1, 0, 0, 12)})
	local row = new("Frame", {Name = "Slots", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 44)}, info.parts)
	new("UIGridLayout", {CellSize = UDim2.new(0.25, -4, 1, 0), CellPadding = UDim2.fromOffset(5, 0)}, row)
	info.slots = {}
	for n = 1, 4 do
		local b = new("TextButton", {Name = "Slot" .. n, AutoButtonColor = false, Text = "", BackgroundColor3 = Color3.fromRGB(17, 24, 33), LayoutOrder = n}, row)
		corner(b, 6)
		local s = stroke(b, C.line, 1.8)
		text(b, {text = "SLOT " .. n .. " · " .. SLOT_KEYS[n], size = 6, color = C.muted, pos = UDim2.fromOffset(0, 4), sz = UDim2.new(1, 0, 0, 9)})
		local nm = text(b, {text = "EMPTY", size = 7, wrap = true, pos = UDim2.fromOffset(4, 15), sz = UDim2.new(1, -8, 0, 26)})
		info.slots[n] = {b = b, s = s, nm = nm}
	end
	info.listHead = text(info.parts, {text = "", size = 7.6, color = C.muted, x = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(0, 68), sz = UDim2.new(1, 0, 0, 12)})
	info.list = new("ScrollingFrame", {Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 1, -84), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.slate}, info.parts)
	new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, info.list)
	info.loading = text(info.parts, {text = "LOADING DINO...", size = 9, color = C.muted, pos = UDim2.fromOffset(0, 100), sz = UDim2.new(1, 0, 0, 14)})
end

local function setGhost(id)
	if sel.ghostId == id then return end
	if sel.ghost then sel.ghost:Destroy() sel.ghost = nil end
	sel.ghostId = id
	if not id or not show.model or flat() then
		show.yawTo = nil
		return
	end
	local m = partModel(show.d, id)
	if not m then return end
	local equipped = table.find(myLoadout(), id) ~= nil and m:GetAttribute("Free") ~= true
	local g = m:Clone()
	if m:GetAttribute("Free") == true then -- a dropped thing: beside the dino
		local size = bodyOf(show.d):GetAttribute("BodySize") or Vector3.new(4, 4, 4)
		g:PivotTo(CFrame.new(size.X * 0.9, 0, 0) * g:GetPivot())
	end
	if equipped then g:Destroy() g = nil end
	if g then
		g.Name = "Ghost"
		-- in rig space: the rig model's pivot holds the yaw; parent into the rig so it turns with it
		g.Parent = show.model
		g:PivotTo(show.model:GetPivot() * show.pivot0:Inverse() * g:GetPivot())
		sel.ghost = g
	end
	-- turn that side of the dino to the camera (nearest 3/4 view); worked out in the models' own space
	local bb = m:GetBoundingBox().Position
	if m:GetAttribute("Free") == true then bb += Vector3.new((bodyOf(show.d):GetAttribute("BodySize") or Vector3.new(4, 4, 4)).X * 0.9, 0, 0) end
	local bc = bodyOf(show.d):GetBoundingBox().Position
	local ph = math.atan2(bb.X - bc.X, bb.Z - bc.Z)
	local best, bd = math.pi + 0.75, 99
	for _, v in ipairs({math.pi + 0.75, math.pi - 0.75, 0.75, -0.75}) do
		local dd = math.abs(((v + ph) % (2 * math.pi) + 3 * math.pi) % (2 * math.pi) - math.pi)
		if dd < bd then bd, best = dd, v end
	end
	show.yawTo, sel.auto = best, false
end

local partRows = {}
local function drawParts()
	for _, r in pairs(partRows) do r:Destroy() end
	partRows = {}
	local d = sel.draft
	local lo = myLoadout()
	for n = 1, 4 do
		local s = info.slots[n]
		s.nm.Text = lo[n] ~= "" and string.upper(partName(lo[n])) or "EMPTY"
		s.nm.TextColor3 = lo[n] ~= "" and C.text or C.muted
		s.s.Color = sel.act == n and C.yellow or C.line
	end
	local ready = myDino() == d
	info.loading.Visible = not ready
	local ids = partsFor(d)
	info.listHead.Text = nameOf(d) .. " PARTS"
	if #ids == 0 then info.listHead.Text = nameOf(d) .. " · NO MECHA PARTS" end
	if not ready then return end
	for k, id in ipairs(ids) do
		local own = owned(id, d)
		local at = table.find(lo, id)
		local b = new("TextButton", {Name = id, AutoButtonColor = false, Text = "", BackgroundColor3 = C.panel, LayoutOrder = k,
			Size = UDim2.new(1, -6, 0, phone and 30 or 44)}, info.list)
		corner(b, 5)
		stroke(b, at == sel.act and C.yellow or C.line, 1.5)
		local ic = new("TextLabel", {BackgroundColor3 = own and (at and C.yellow or C.volt) or C.slate, Font = LOUD, TextSize = 10,
			Text = own and (at and tostring(at) or "+") or "X", TextColor3 = own and C.ink or C.muted, Position = UDim2.fromOffset(5, phone and 4 or 8),
			Size = UDim2.fromOffset(phone and 22 or 28, phone and 22 or 28)}, b)
		corner(ic, 4)
		local left = phone and 32 or 40
		text(b, {text = string.upper(partName(id)), size = 8, x = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(left, phone and 2 or 4), sz = UDim2.new(1, -left - 84, 0, 12)})
		if not phone then
			text(b, {text = partText(id), size = 9, font = BODY, color = Color3.fromRGB(170, 182, 198), x = Enum.TextXAlignment.Left, wrap = true,
				y = Enum.TextYAlignment.Top, pos = UDim2.fromOffset(left, 18), sz = UDim2.new(1, -left - 84, 0, 24)})
		end
		text(b, {text = own and (at and ("SLOT " .. at) or "EQUIP") or "BUY IN THE LAB", size = 6, color = own and (at and C.yellow or C.volt) or C.red,
			x = Enum.TextXAlignment.Right, anchor = Vector2.new(1, 0), pos = UDim2.new(1, -8, 0, 0), sz = UDim2.new(0, 80, 1, 0)})
		if not own then b.BackgroundTransparency = 0.4 end
		b.MouseEnter:Connect(function() setGhost(id) end)
		b.MouseLeave:Connect(function() if sel.ghostId == id then setGhost(nil) end end)
		b.Activated:Connect(function()
			press("part:" .. id)
			if not own then
				setGhost(id)
				showToast("BUY " .. string.upper(partName(id)) .. " IN THE LAB FIRST")
				return
			end
			if skillRemote then skillRemote:FireServer("slot", sel.act, id) end
			setGhost(id)
			local lo2 = myLoadout()
			lo2[sel.act] = id
			for n = 1, 4 do -- next empty slot
				if lo2[n] == "" then sel.act = n break end
			end
		end)
		partRows[id] = b
	end
end

local function drawSelect()
	local d, parts = sel.draft, sel.step == "parts"
	script:SetAttribute("PregameScreenStep", sel.step)
	script:SetAttribute("PregameScreenDraft", d or "")
	tops.Select.title.Text = parts and "MECHA PARTS" or "SELECT DINO"
	tops.Select.sub.Text = modeLine() .. " · " .. (parts and (nameOf(d) .. " · PICK 4 PARTS") or "PICK YOUR DINO")
	do -- v1.2: SAVED LOADOUT tag
		local tg = tops.Select.savedTag
		if not tg then
			tg = text(tops.Select.title.Parent, {text = "SAVED LOADOUT", size = 10, color = C.green, x = Enum.TextXAlignment.Right,
				pos = UDim2.new(1, -240, 0, 24), anchor = Vector2.new(1, 0), sz = UDim2.fromOffset(220, 14)})
			tops.Select.savedTag = tg
		end
		local cur = {}
		for n = 1, 4 do cur[n] = tostring(player:GetAttribute("SkillSlot" .. n) or "") end
		local sv = tostring(player:GetAttribute("SkillSavedLoadout") or "")
		tg.Visible = parts and script:GetAttribute("PregameSavedTagEnabled") ~= false and player:GetAttribute("SkillLoadoutFrom") == "saved"
			and sv ~= "" and table.concat(cur, ",") == sv
	end
	-- team strip
	for _, ch in ipairs(strip:GetChildren()) do if not ch:IsA("UIListLayout") then ch:Destroy() end end
	text(strip, {text = "YOUR TEAM", size = 7.8, color = C.muted, sz = UDim2.fromOffset(70, 30), x = Enum.TextXAlignment.Left})
	for _, e in ipairs(roster[mySide()] or {}) do
		if not isMe(e) then
			local chip = new("Frame", {BackgroundColor3 = Color3.fromRGB(18, 25, 35), Size = UDim2.fromOffset(150, 30)}, strip)
			corner(chip, 5) stroke(chip, C.line, 1.5)
			new("Frame", {BackgroundColor3 = C.blue, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 3)}, chip)
			thumb(chip, e.species, {sz = UDim2.fromOffset(32, 24), pos = UDim2.fromOffset(3, 4)})
			text(chip, {text = tostring(e.name), size = 7.8, x = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(40, 3), sz = UDim2.fromOffset(106, 12)})
			text(chip, {text = nameOf(e.species) .. " · " .. roleOf(e.species), size = 6, color = C.muted, x = Enum.TextXAlignment.Left,
				pos = UDim2.fromOffset(40, 16), sz = UDim2.fromOffset(106, 10)})
		end
	end
	local c = teamRoles()
	local need = {}
	for _, g in ipairs(ROLE_GROUPS) do if c[g[1]] == 0 then table.insert(need, g[1]) end end
	needsLbl.Text = #need > 0 and ("TEAM NEEDS A " .. table.concat(need, " OR ")) or "TEAM COVERED"
	needsLbl.TextColor3 = #need > 0 and C.yellow or C.green
	for _, g in ipairs(ROLE_GROUPS) do
		groupHead[g[1]].Text = c[g[1]] == 0 and "TEAM NEEDS" or (c[g[1]] .. " ON TEAM")
		groupHead[g[1]].TextColor3 = c[g[1]] == 0 and C.yellow or C.muted
	end
	for dd, t in pairs(tiles) do
		t.s.Color = dd == d and C.yellow or C.line
		t.b.BackgroundColor3 = dd == d and Color3.fromRGB(42, 42, 28) or C.panel2
		t.tag.Text = mateNamesOn(dd)
	end
	-- showcase
	cls.Text = d and ((Sheet and Sheet.SPECIES and Sheet.SPECIES[d] and string.upper(Sheet.SPECIES[d].class) or "") .. " · " .. roleOf(d)) or ""
	cls.TextColor3 = modeColor()
	dname.Text = d and nameOf(d) or ""
	hint.Text = parts and "DRAG TO SPIN · POINT AT A PART TO SEE IT" or "DRAG TO SPIN"
	if not flat() then show.set(d, (d == myDino()) and myLoadout() or {}, C.volt) end
	-- info
	info.dino.Visible, info.parts.Visible = not parts, parts
	local sp = d and Sheet and Sheet.SPECIES and Sheet.SPECIES[d]
	for i, n in ipairs(STAT_N) do
		local v = sp and sp.start and sp.start[n] or 0
		info.bars[i].fill.Size = UDim2.fromScale(math.clamp(v / 10, 0, 1), 1)
		info.bars[i].v.Text = tostring(v)
	end
	info.main.Text = sp and sp.abilities and string.upper(tostring(sp.abilities[1] or "")) or ""
	info.jump.Text = sp and sp.abilities and string.upper(tostring(sp.abilities[2] or "")) or ""
	local np = d and #partsFor(d) or 0
	info.partsHead.Text = "MECHA PARTS · " .. (np > 0 and (np .. " TO CHOOSE FROM") or "NONE YET")
	if parts then drawParts() end
	backBtn.Text = parts and "CHANGE DINO" or "BACK"
	goBtn.Text = parts and "CONFIRM LOADOUT" or (d and ("SELECT " .. nameOf(d)) or "SELECT")
	-- the slide: parts step widens the dino and hides the roster
	local ti = TweenInfo.new(0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(roster3, ti, {Position = UDim2.fromOffset(parts and -230 or 30, 122)}):Play()
	TweenService:Create(showPane, ti, {Position = UDim2.fromOffset(parts and 30 or 225, 122), Size = UDim2.fromOffset(parts and 560 or 415, PANE_H)}):Play()
	TweenService:Create(infoPane, ti, {Position = UDim2.new(1, parts and -400 or -350, 0, 122), Size = UDim2.fromOffset(parts and 370 or 320, PANE_H)}):Play()
	if not parts then setGhost(nil) sel.auto = true end
end

for d, t in pairs(tiles) do
	t.b.Activated:Connect(function()
		if sel.step ~= "dino" then return end
		press("tile:" .. d)
		sel.draft = d
		drawSelect()
	end)
	t.b.MouseEnter:Connect(function() if sel.step == "dino" then t.s.Color = sel.draft == d and C.yellow or Color3.fromRGB(75, 93, 118) end end)
	t.b.MouseLeave:Connect(function() if sel.step == "dino" then t.s.Color = sel.draft == d and C.yellow or C.line end end)
end
for n, s in ipairs(info.slots) do
	s.b.Activated:Connect(function() press("slot:" .. n) sel.act = n drawParts() end)
end
-- drag to spin
showPane.InputBegan:Connect(function(io)
	if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
		sel.drag = {x = io.Position.X, yaw = show.yaw}
		sel.auto, show.yawTo = false, nil
	end
end)
UserInputService.InputChanged:Connect(function(io)
	if sel.drag and (io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch) then
		show.yaw = sel.drag.yaw + (io.Position.X - sel.drag.x) * 0.012 / math.max(0.2, uiScale.Scale)
	end
end)
UserInputService.InputEnded:Connect(function(io)
	if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then sel.drag = nil end
end)

-- ---------- INTRO ----------
local I = views.Intro
local icols = {}
for i = 1, 4 do
	local f = new("Frame", {Name = "ICol" .. i, BackgroundTransparency = 1, Position = UDim2.fromOffset(50 + (i - 1) * 225, 60), Size = UDim2.fromOffset(225, phone and 330 or 420)}, I)
	icols[i] = {frame = f, view = nil, flat = nil}
end
local barTop = new("Frame", {BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 55), ZIndex = 5}, I)
local barBot = new("Frame", {BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 55), ZIndex = 5}, I)
local callout = new("Frame", {Name = "Callout", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.fromOffset(600, 80), ZIndex = 6}, I)
local coT = text(callout, {text = "", size = 10, z = 6})
local coN = text(callout, {text = "", size = 31, pos = UDim2.fromOffset(0, 14), sz = UDim2.new(1, 0, 0, 36), z = 6})
local coR = text(callout, {text = "", size = 11.5, color = Color3.fromRGB(201, 212, 226), pos = UDim2.fromOffset(0, 52), sz = UDim2.new(1, 0, 0, 16), z = 6})
local counter = text(I, {text = "PLAYER INTROS", size = 10, color = C.muted, x = Enum.TextXAlignment.Right, anchor = Vector2.new(1, 1), pos = UDim2.new(1, -30, 1, -64), sz = UDim2.fromOffset(300, 14), z = 6})
local vs = new("Frame", {Name = "VS", BackgroundColor3 = Color3.fromRGB(6, 8, 12), BorderSizePixel = 0, Position = UDim2.fromOffset(0, 55), Size = UDim2.new(1, 0, 1, -110), Visible = false, ZIndex = 7}, I)
local vsL = new("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(30, 40), Size = UDim2.new(0.4, -30, 1, -110), ZIndex = 7}, vs)
new("UIListLayout", {Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Left}, vsL)
local vsR = new("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -30, 0, 40), Size = UDim2.new(0.4, -30, 1, -110), ZIndex = 7}, vs)
new("UIListLayout", {Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right}, vsR)
local vsMid = text(vs, {text = "VS", size = 70, anchor = Vector2.new(0.5, 0.5), pos = UDim2.new(0.5, 0, 0.45, 0), sz = UDim2.fromOffset(200, 80), z = 7})
local vsGo = text(vs, {text = "CAPTURE AND HOLD THE HARDPOINT", size = 16, anchor = Vector2.new(0.5, 1), pos = UDim2.new(0.5, 0, 1, -12), sz = UDim2.fromOffset(700, 22), z = 7})

local function introColumns(list, ringColor, lit)
	for i = 1, 4 do
		local ic, e = icols[i], list[i]
		ic.frame.Visible = e ~= nil
		if e then
			local d = slotDino(e)
			if flat() then
				if not ic.flat then
					ic.flat = new("TextLabel", {BackgroundColor3 = C.panel2, Size = UDim2.new(0.7, 0, 0.35, 0), Position = UDim2.fromScale(0.15, 0.4), Font = LOUD, TextSize = 16, TextColor3 = C.text}, ic.frame)
					corner(ic.flat, 8)
				end
				ic.flat.Text = nameOf(d)
				ic.flat.BackgroundTransparency = (lit == nil or lit == i) and 0 or 0.6
			else
				if not ic.view then ic.view = dinoView(ic.frame, {name = "View", fov = 30, fit = 3.2, look = 0.36}) end
				ic.view.set(d, slotLoadout(e), ringColor)
				ic.view.vf.ImageColor3 = (lit == nil or lit == i) and Color3.new(1, 1, 1) or Color3.fromRGB(55, 60, 72)
			end
		end
	end
end
local vsKey = nil
local function drawVs()
	local key = HttpService:JSONEncode(roster)
	if key == vsKey then return end
	vsKey = key
	for _, f in ipairs({vsL, vsR}) do for _, ch in ipairs(f:GetChildren()) do if not ch:IsA("UIListLayout") then ch:Destroy() end end end
	local function card(parent, e)
		local c = new("Frame", {BackgroundColor3 = Color3.fromRGB(18, 25, 35), Size = UDim2.fromOffset(220, 40), ZIndex = 7}, parent)
		corner(c, 6) stroke(c, C.line, 1.5)
		local t = thumb(c, slotDino(e), {sz = UDim2.fromOffset(44, 32), pos = UDim2.fromOffset(4, 4)})
		t.ZIndex = 8
		text(c, {text = isMe(e) and "YOU" or tostring(e.name), size = 9.5, x = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(54, 5), sz = UDim2.fromOffset(160, 14), z = 8})
		local rec = recordOf(e)
		text(c, {text = rec, size = 8, color = C.muted, x = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(54, 21), sz = UDim2.fromOffset(160, 12), z = 8})
	end
	for _, e in ipairs(roster[mySide()] or {}) do card(vsL, e) end
	for _, e in ipairs(roster[otherSide()] or {}) do card(vsR, e) end
end
local function teamRecord(list)
	local w, l, any = 0, 0, false
	for _, e in ipairs(list) do
		if e.kind == "human" and e.w and e.l then w += e.w l += e.l any = true end
	end
	return any and ("%dW %dL"):format(w, l) or nil
end
local function botMix(list)
	local c, order = {}, {}
	for _, e in ipairs(list) do
		if e.kind == "bot" and e.tier then
			if not c[e.tier] then table.insert(order, e.tier) end
			c[e.tier] = (c[e.tier] or 0) + 1
		end
	end
	local out = {}
	for _, t in ipairs(order) do table.insert(out, c[t] .. " " .. string.upper(t)) end
	return table.concat(out, " · ")
end
local function drawIntro(t)
	local mine, theirs = roster[mySide()] or {}, roster[otherSide()] or {}
	local blueEnd = BLUE_EACH * math.max(1, #mine)
	if t < blueEnd then
		vs.Visible = false
		local i = math.clamp(math.floor(t / BLUE_EACH) + 1, 1, #mine)
		introColumns(mine, C.blue, i)
		local e = mine[i]
		if e then
			coT.Text, coT.TextColor3 = ("BLUE TEAM · %d OF %d"):format(i, #mine), C.blue
			coN.Text = isMe(e) and "YOU" or tostring(e.name)
			local rec, sub = recordOf(e)
			coR.Text = nameOf(slotDino(e)) .. " · " .. rec .. (sub ~= "" and (" · " .. sub) or "")
		end
		counter.Text = "PLAYER INTROS"
	elseif t < blueEnd + RED_SHOW then
		vs.Visible = false
		introColumns(theirs, C.red, nil)
		coT.Text, coT.TextColor3 = "RED TEAM", C.red
		local allBots = true
		for _, e in ipairs(theirs) do if e.kind ~= "bot" then allBots = false end end
		coN.Text = allBots and "BOTS" or "THE OPPONENTS"
		coR.Text = allBots and botMix(theirs) or (teamRecord(theirs) or "")
		counter.Text = "PLAYER INTROS"
	else
		drawVs()
		vs.Visible = true
		coT.Text, coN.Text, coR.Text = "", "", ""
		vsMid.TextColor3 = modeColor()
		vsGo.TextColor3 = modeColor()
		counter.Text = ""
	end
end

-- ---------- wiring ----------
local view = "hidden"
local function setView(v)
	if v == view then return end
	view = v
	views.Lineup.Visible = v == "lineup"
	views.Select.Visible = v == "select"
	views.Intro.Visible = v == "intro"
	script:SetAttribute("PregameScreenState", v)
end
local function openSelect()
	press("open")
	sel.draft = myDino()
	sel.step = "dino"
	sel.act = 1
	for n, id in ipairs(myLoadout()) do if id == "" then sel.act = n break end end
	if player:GetAttribute("PgReady") == true and request then request:FireServer("unready") end
	setView("select")
	drawSelect()
end
cta.Activated:Connect(openSelect)
for _, col in ipairs(cols) do
	col.plaque.Activated:Connect(function() if col.plaque.Active then openSelect() end end)
	col.click.Activated:Connect(function() if col.tap.Visible then openSelect() end end)
end
backBtn.Activated:Connect(function()
	if sel.step == "parts" then
		press("toDino")
		sel.step = "dino"
		drawSelect()
	else
		press("back")
		setView("lineup")
	end
end)
goBtn.Activated:Connect(function()
	if sel.step == "dino" then
		if not sel.draft then return end
		press("pick:" .. sel.draft)
		if sel.draft ~= myDino() and speciesRemote then speciesRemote:FireServer(sel.draft) end
		sel.step = "parts"
		sel.act = 1
		drawSelect()
	else
		press("confirm")
		if request then request:FireServer("ready") end
		setGhost(nil)
		setView("lineup")
	end
end)

local function layout()
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local wasPhone = phone
	phone = vp.X / math.max(1, vp.Y) >= 1.9
	H = phone and 463 or 562
	canvas.Size = UDim2.fromOffset(1000, H)
	uiScale.Scale = math.min(vp.X / 1000, vp.Y / H)
	if phone ~= wasPhone then
		for i, col in ipairs(cols) do
			local x, top, viewH, py = colRect(i)
			col.frame.Size = UDim2.fromOffset(225, viewH)
			col.plaque.Position = UDim2.fromOffset(x + 112, py)
		end
		for _, g in ipairs(roster3:GetChildren()) do
			local grid = g:FindFirstChild("Tiles")
			local gl = grid and grid:FindFirstChildOfClass("UIGridLayout")
			if gl then gl.CellSize = UDim2.fromOffset(88, phone and 44 or 78) end
		end
		PANE_H = phone and 280 or 370
		roster3.Size = UDim2.fromOffset(185, PANE_H)
		infoPane.Size = UDim2.fromOffset(infoPane.Size.X.Offset, PANE_H)
		showPane.Size = UDim2.fromOffset(showPane.Size.X.Offset, PANE_H)
		for _, ic in ipairs(icols) do ic.frame.Size = UDim2.fromOffset(225, phone and 330 or 420) end
	end
end
layout()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end

local sig = ""
local function refresh()
	readRoster()
	local pgPhase = state:GetAttribute("PgPhase")
	local mine = roster[mySide()] or {}
	-- lineup
	tops.Lineup.title.TextColor3, tops.Select.title.TextColor3 = modeColor(), modeColor()
	tops.Lineup.fill.BackgroundColor3, tops.Select.fill.BackgroundColor3 = modeColor(), modeColor()
	tops.Lineup.sub.Text = modeLine() .. " · " .. (mySide() == "A" and "BLUE TEAM" or "RED TEAM")
	for i, col in ipairs(cols) do setColumn(col, mine[i], C.blue, isMe(mine[i])) end
	local allReady = #mine > 0
	for _, e in ipairs(mine) do if e.kind == "human" and e.ready ~= true then allReady = false end end
	for _, e in ipairs(roster[otherSide()] or {}) do if e.kind == "human" and e.ready ~= true then allReady = false end end
	allReadyLbl.Visible = allReady
	cta.Text = player:GetAttribute("PgReady") == true and "CHANGE DINO" or "SELECT DINO"
	if view == "select" then drawSelect() end
	return pgPhase
end
state:GetAttributeChangedSignal("PrRoster"):Connect(function() sig = "" end)
player:GetAttributeChangedSignal("DinoSpecies"):Connect(function() sig = "" end)
for n = 1, 4 do player:GetAttributeChangedSignal("SkillSlot" .. n):Connect(function() sig = "" end) end
player:GetAttributeChangedSignal("SkillSavedLoadout"):Connect(function() sig = "" end) -- v1.2
player:GetAttributeChangedSignal("SkillLoadoutFrom"):Connect(function() sig = "" end) -- v1.2
player.AttributeChanged:Connect(function(a) if string.sub(a, 1, 10) == "SkillPath_" then sig = "" end end)
player.CharacterAdded:Connect(function() task.delay(0.5, function() sig = "" end) end)

local lastAnim = 0
RunService.RenderStepped:Connect(function(dt)
	local pgPhase = state:GetAttribute("PgPhase")
	local on = script:GetAttribute("PregameScreenEnabled") ~= false and player:GetAttribute("PrInLobby") == true
		and (pgPhase == "lineup" or pgPhase == "intro")
	gui.Enabled = on
	if not on then
		if view ~= "hidden" then setView("hidden") setGhost(nil) end
		return
	end
	if pgPhase == "intro" then
		if view ~= "intro" then setGhost(nil) setView("intro") sig = "" end
	elseif view == "hidden" or view == "intro" then
		setView("lineup")
		sig = ""
	end
	local s2 = tostring(state:GetAttribute("PrRoster")) .. "|" .. tostring(pgPhase) .. "|" .. tostring(player:GetAttribute("PgReady"))
	if s2 ~= sig then
		sig = s2
		refresh()
	end
	-- clocks
	local ends = tonumber(state:GetAttribute("PgEndsAt")) or 0
	local left = math.max(0, ends - now())
	local total = PR.PG_LINEUP or 30
	for _, t in pairs(tops) do
		local s = math.ceil(left - 1e-6)
		t.clock.Text = ("0:%02d"):format(math.min(59, s))
		t.clock.TextColor3 = s <= 5 and C.red or C.text
		t.fill.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
		t.note.Text = player:GetAttribute("PgReady") == true and "YOU'RE READY" or "MATCH STARTS AT 0:00"
	end
	toast.Visible = os.clock() < toastUntil
	-- motion (about 30 fps is plenty for the sway)
	lastAnim += dt
	if lastAnim < 1 / 30 then return end
	local step = lastAnim
	lastAnim = 0
	local tt = os.clock()
	if view == "lineup" then
		for i, col in ipairs(cols) do
			if col.view and col.view.model then
				col.view.yaw = math.pi + 0.8 + math.sin(tt / 1.4 + i) * 0.12
				col.view.place()
			end
		end
	elseif view == "select" and show.model then
		if sel.auto and not sel.drag then show.yaw += step * 0.45 end
		if show.yawTo and not sel.drag then
			local dy = ((show.yawTo - show.yaw + math.pi) % (2 * math.pi)) - math.pi
			show.yaw += dy * math.min(1, step * 5)
			if math.abs(dy) < 0.01 then show.yawTo = nil end
		end
		show.place()
	elseif view == "intro" then
		drawIntro((PR.PG_INTRO or 8) - left)
		for i, ic in ipairs(icols) do
			if ic.view and ic.view.model then
				ic.view.yaw = math.pi + 0.8 + math.sin(tt / 1.4 + i) * 0.12
				ic.view.place()
			end
		end
	end
end)
