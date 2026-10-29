-- AbilityBar v1.5 (Mecha Dino Arena) — PC ability bar: the 2 mecha loadout slots and this dino's own moves, each with
-- its cooldown. MDA-42, plan docs/plans/ABILITY_BAR_v1.0.md Task 1, mockup docs/mockups/ability_hud_options.html
-- option B "Ability bar" (Kepu 2026-10-29: "i like the ability bar on pc"; "the abilities bar should be different for
-- every dino"; Ram "Only when usable").
-- Who: non-touch devices only (UserInputService.TouchEnabled false). Touch keeps ArenaTouch / MechaButtons; no bar.
-- Display only: Frames and TextLabels, no buttons, so clicks go to the game (a left click still bites). Input stays in
--   MechaButtons (R / C), PounceTest (F), JumpTest (Space), BiteTest (left click), RamTest (E).
-- Layout: ScreenGui "AbilityBar" (DisplayOrder 5) in PlayerGui; holder AnchorPoint (0.5, 1) at (0.5, 0, 1, -24), one
--   centred row. Tile T = clamp(viewport width x 0.045, 56, 84) px, square, gap 8 px. Order: Slot_1 (R), Slot_2 (C),
--   divider (2 px x 0.8 T, white at 0.65, 12 px space each side), then the moves of SPECIES_MOVES[Species] (Raptor:
--   Pounce F, Leap Space; TRex: Bite LMB, Ram E). A species with no row gets every enabled move in the order Bite,
--   Pounce, Leap, Ram. A move whose Enabled attribute is false has no tile; Ram's tile exists only while usable
--   (RamLatchGate ~= "closed", or RamTestState is not "ready" / "off").
-- Tile: rounded square (corner 22%), panel rgb(20, 20, 26) at 0.3; stroke 2.5 px: slots Engineer orange
--   rgb(255, 155, 46) (empty slot white at 0.5), moves white, Bite attack red rgb(240, 90, 79); key hint top left; name
--   centred (FredokaOne); Thrusters charge pips top right; cooldown fill (black at 0.38) rising from the bottom
--   (height = remaining / total); seconds bottom ("2.4s", rgb(255, 217, 168)).
-- Tile states (first match wins; "now" = workspace:GetServerTimeNow(), the clock of the stamps):
--   slot:     "empty"   SkillSlot<n> nil or ""                         "+", white stroke at 0.5
--             "off"     thrusters, DashEnabled ~= true                  dimmed 0.5
--             "active"  thrusters, MechaDashLocal == "dashing"          stroke 4 px white
--             "cooling" thrusters, DashChargesLeft == 0                 fill (DashNextChargeAt - now) / DashRecharge, dim 0.25
--             "ready"   thrusters, charges left >= 1 (fill + seconds to the next charge while not full); other ids: name
--   move:     "stunned" StunnedUntil > now                              sub-label "STUN", dimmed 0.25
--             "active"  Pounce windup / lunge / latched, Leap crouch / air, Ram windup / charge / recoil (TestState)
--             "cooling" now < <Move>PredictedAt + <Move>Cooldown         fill + seconds
--             "ready"   otherwise
-- Bar state (character AbilityBarState): "off" (script attribute AbilityBarEnabled == false), "touch", "on".
-- Diagnostics (character attributes, this client, set on change): AbilityBarVersion, AbilityBarState, AbilityBarTiles
--   ("R:DASH,C:+,F:POUNCE,Space:LEAP"), AbilityBar_<Tile> (state above; Tile = Slot_1 / Slot_2 / Pounce / Leap / Bite /
--   Ram; a Ram without a tile = "hidden").
-- v1.1 (Kepu 2026-10-29: the bar showed faintly through the SKILLS screen's see-through loadout strip -> "yes hide"):
--   the bar is hidden while the character attribute SkillScreenOpen (SkillScreen 1.0+) is true; AbilityBarState
--   "skills" then. Script attribute AbilityBarHideOnSkills (default true; false = 1.0 behaviour).
-- v1.2 (4 slots + Cloak, MDA-53, plans docs/plans/LOADOUT4_v1.0.md Task 3 + docs/plans/CLOAK_v1.0.md Task 5): 4 slot tiles
--   in the order Slot_1 (R), Slot_3 (T), Slot_2 (C), Slot_4 (V) (SLOT_ORDER; keys = MechaButtons 1.4), then the divider
--   and the moves as 1.1. A Cloak Field slot (CloakServer 1.0) has its own states, first match wins:
--     "off"     CloakEnabled ~= true                         dimmed 0.5
--     "active"  CloakedUntil > now                           stroke 4 px white, seconds left of the cloak
--     "cooling" now < CloakReadyAt                           fill (CloakReadyAt - now) / CloakCooldown, seconds, dim 0.25
--     "ready"   otherwise
--   Other tile rules as 1.1. Diagnostics AbilityBar_Slot_3 / _Slot_4; AbilityBarTiles lists all 4 slots
--   ("R:DASH,T:CLOAK FIELD,C:+,V:+,F:POUNCE,Space:LEAP").
-- v1.4 (raptor parts batch 2, MDA-75): TIMED_PARTS += scent ("Scent") and screech ("Screech"; no Until, so it is only
--   ready / cooling). Tile names from the slot part as before.
-- v1.5 (raptor traps, MDA-80): TIMED_PARTS += traps ("Mine"; no Until: ready / cooling).
-- v1.3 (raptor parts batch 1, MDA-65, plan docs/plans/RAPTOR_PARTS_B1_v1.0.md Task 8): Adrenaline Injector and Energy
--   Shield slots (AdrenalineServer 1.0 / EnergyShieldServer 1.0) use the Cloak tile's states with their own attributes
--   (TIMED_PARTS: <Prefix>Enabled, <Prefix>Until, <Prefix>ReadyAt, <Prefix>Cooldown; prefixes "Adrenaline" /
--   "EnergyShield"): off (dimmed 0.5) / active (seconds left) / cooling (fill + seconds, dim 0.25) / ready. Titles come
--   from the path names as before ("ADRENALINE INJECTOR", "ENERGY SHIELD").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.5"
local char = script.Parent
local TIMED_PARTS = {adrenaline = "Adrenaline", shield = "EnergyShield"} -- v1.3: part id -> attribute prefix
TIMED_PARTS.scent, TIMED_PARTS.screech = "Scent", "Screech" -- v1.4: raptor parts batch 2
TIMED_PARTS.traps = "Mine" -- v1.5: Shock Mine
local player = Players:GetPlayerFromCharacter(char) or Players.LocalPlayer

local PANEL = Color3.fromRGB(20, 20, 26)
local ORANGE = Color3.fromRGB(255, 155, 46)
local RED = Color3.fromRGB(240, 90, 79)
local WHITE = Color3.new(1, 1, 1)
local SECS = Color3.fromRGB(255, 217, 168)
local KEY_GREY = Color3.fromRGB(154, 160, 173)
local GAP, DIV_SPACE, BOTTOM = 8, 12, 24

-- moves: enabled attribute, key hint, name, cooldown attribute (+ default), stamp attribute, test-state attribute and
-- the states that count as "active"
local MOVES = {
	Bite = {enabled = "BiteEnabled", enabledDefault = true, key = "LMB", name = "BITE", cd = "BiteCooldown", cdDefault = 0.8,
		stamp = "BitePredictedAt", color = RED},
	Pounce = {enabled = "PounceEnabled", enabledDefault = false, key = "F", name = "POUNCE", cd = "PounceCooldown",
		cdDefault = 3, stamp = "PouncePredictedAt", stateAttr = "PounceTestState",
		active = {windup = true, lunge = true, latched = true}},
	Leap = {enabled = "JumpEnabled", enabledDefault = false, key = "Space", name = "LEAP", cd = "JumpCooldown",
		cdDefault = 0.5, stamp = "JumpPredictedAt", stateAttr = "JumpTestState", active = {crouch = true, air = true}},
	Ram = {enabled = "RamEnabled", enabledDefault = false, key = "E", name = "RAM", cd = "RamCooldown", cdDefault = 6,
		stamp = "RamPredictedAt", stateAttr = "RamTestState", active = {windup = true, charge = true, recoil = true}},
}
local SPECIES_MOVES = {Raptor = {"Pounce", "Leap"}, TRex = {"Bite", "Ram"}}
local FALLBACK_ORDER = {"Bite", "Pounce", "Leap", "Ram"}
local SLOT_KEYS = {"R", "C", "T", "V"} -- v1.2: + T / V (slots 3 / 4)
local SLOT_ORDER = {1, 3, 2, 4} -- v1.2: tile order R, T, C, V

if script:GetAttribute("AbilityBarEnabled") == nil then script:SetAttribute("AbilityBarEnabled", true) end
if script:GetAttribute("AbilityBarHideOnSkills") == nil then script:SetAttribute("AbilityBarHideOnSkills", true) end -- v1.1

local shown = {}
local function show(attr, value)
	if shown[attr] ~= value then
		shown[attr] = value
		char:SetAttribute(attr, value)
	end
end
show("AbilityBarVersion", VERSION)

if UserInputService.TouchEnabled then
	show("AbilityBarState", "touch")
	return
end

local shared = ReplicatedStorage:FindFirstChild("SkillShared")
local okST, ST = pcall(function() return require(shared:WaitForChild("SkillTree", 10)) end)

local pg = player:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("AbilityBar")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "AbilityBar"
gui.ResetOnSpawn = true
gui.DisplayOrder = 5
local holder = Instance.new("Frame")
holder.Name = "Bar"
holder.AnchorPoint = Vector2.new(0.5, 1)
holder.Position = UDim2.new(0.5, 0, 1, -BOTTOM)
holder.BackgroundTransparency = 1
holder.Parent = gui
gui.Parent = pg

local function label(parent, name, text, pos, size, color, maxSize)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position, l.Size = pos, size
	l.Font = Enum.Font.FredokaOne
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color
	l.ZIndex = 3
	l.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = l
	return l
end

-- one tile: {f, stroke, fill, name, key, secs, sub, pips}
local function makeTile(name, keyText, title, strokeColor, withPips)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = PANEL
	f.BackgroundTransparency = 0.3
	f.BorderSizePixel = 0
	f.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.22, 0)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = strokeColor
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = f
	local fill = Instance.new("Frame")
	fill.Name = "Cooldown"
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(1, 0)
	fill.BackgroundColor3 = Color3.new(0, 0, 0)
	fill.BackgroundTransparency = 0.38
	fill.BorderSizePixel = 0
	fill.ZIndex = 2
	fill.Parent = f
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0.22, 0)
	fc.Parent = fill
	local t = {f = f, stroke = stroke, fill = fill, strokeColor = strokeColor}
	t.key = label(f, "Key", keyText, UDim2.fromScale(0.08, 0.05), UDim2.fromScale(0.5, 0.2), KEY_GREY, 14)
	t.key.TextXAlignment = Enum.TextXAlignment.Left
	t.name = label(f, "Main", title, UDim2.fromScale(0.08, 0.36), UDim2.fromScale(0.84, 0.24), WHITE, 18)
	t.sub = label(f, "Sub", "", UDim2.fromScale(0.1, 0.6), UDim2.fromScale(0.8, 0.14), WHITE, 11)
	t.secs = label(f, "Secs", "", UDim2.fromScale(0.1, 0.76), UDim2.fromScale(0.8, 0.17), SECS, 14)
	if withPips then
		local pips = Instance.new("Frame")
		pips.Name = "Pips"
		pips.BackgroundTransparency = 1
		pips.AnchorPoint = Vector2.new(1, 0)
		pips.Position = UDim2.fromScale(0.92, 0.08)
		pips.Size = UDim2.fromScale(0.4, 0.1)
		pips.ZIndex = 3
		pips.Parent = f
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Right
		list.Padding = UDim.new(0.08, 0)
		list.Parent = pips
		t.pips = {}
		for i = 1, 2 do
			local p = Instance.new("Frame")
			p.Name = "Pip_" .. i
			p.Size = UDim2.fromScale(1, 1)
			p.SizeConstraint = Enum.SizeConstraint.RelativeYY
			p.BorderSizePixel = 0
			p.ZIndex = 3
			p.Parent = pips
			local pc = Instance.new("UICorner")
			pc.CornerRadius = UDim.new(0.5, 0)
			pc.Parent = p
			t.pips[i] = p
		end
	end
	return t
end

local function slotId(n)
	local v = player:GetAttribute("SkillSlot" .. n)
	return (type(v) == "string" and v ~= "") and v or nil
end

local function enabled(m)
	local v = char:GetAttribute(m.enabled)
	if v == nil then v = m.enabledDefault end
	return v == true
end

local function ramUsable()
	local st = char:GetAttribute("RamTestState")
	return char:GetAttribute("RamLatchGate") ~= "closed" or (st ~= nil and st ~= "ready" and st ~= "off")
end

local function moveList()
	local order = SPECIES_MOVES[char:GetAttribute("Species")] or FALLBACK_ORDER
	local list = {}
	for _, id in ipairs(order) do
		local m = MOVES[id]
		if m and enabled(m) and (id ~= "Ram" or ramUsable()) then table.insert(list, id) end
	end
	return list
end

local tiles = {}   -- ordered {id, kind ("slot" / "move"), t, n / move}
local divider
local signature = ""

local function tileSize()
	local cam = workspace.CurrentCamera
	local w = cam and cam.ViewportSize.X or 1280
	return math.clamp(math.floor(w * 0.045 + 0.5), 56, 84)
end

local function layout()
	local T = tileSize()
	local x = 0
	for i, e in ipairs(tiles) do
		if i == #SLOT_ORDER + 1 and divider then -- v1.2: after the 4 slot tiles (was 3)
			x += DIV_SPACE - GAP
			divider.Size = UDim2.fromOffset(2, math.floor(T * 0.8))
			divider.Position = UDim2.fromOffset(x, math.floor(T * 0.1))
			x += 2 + DIV_SPACE
		end
		e.t.f.Size = UDim2.fromOffset(T, T)
		e.t.f.Position = UDim2.fromOffset(x, 0)
		x += T + GAP
	end
	holder.Size = UDim2.fromOffset(math.max(0, x - GAP), T)
end

local function rebuild()
	local moves = moveList()
	local parts = {}
	for _, n in ipairs(SLOT_ORDER) do table.insert(parts, tostring(slotId(n) or "")) end -- v1.2: 4 slots
	local sig = table.concat(parts, ",") .. "|" .. table.concat(moves, ",")
	if sig == signature and #tiles > 0 then return end
	signature = sig
	for _, e in ipairs(tiles) do e.t.f:Destroy() end
	if divider then divider:Destroy() end
	tiles = {}
	local names = {}
	for _, n in ipairs(SLOT_ORDER) do -- v1.2: R, T, C, V (was 1, 2)
		local id = slotId(n)
		local title = not id and "+" or id == "thrusters" and "DASH"
			or string.upper(okST and ST.PATHS[id] and ST.PATHS[id].name or id)
		local t = makeTile("Slot_" .. n, SLOT_KEYS[n], title, id and ORANGE or WHITE, id == "thrusters")
		if not id then t.stroke.Transparency = 0.5 end
		table.insert(tiles, {id = "Slot_" .. n, kind = "slot", n = n, part = id, t = t})
		table.insert(names, SLOT_KEYS[n] .. ":" .. title)
	end
	divider = nil
	if #moves > 0 then
		divider = Instance.new("Frame")
		divider.Name = "Divider"
		divider.BackgroundColor3 = WHITE
		divider.BackgroundTransparency = 0.65
		divider.BorderSizePixel = 0
		divider.Parent = holder
	end
	for _, id in ipairs(moves) do
		local m = MOVES[id]
		local t = makeTile(id, m.key, m.name, m.color or WHITE, false)
		table.insert(tiles, {id = id, kind = "move", move = m, t = t})
		table.insert(names, m.key .. ":" .. m.name)
	end
	if not table.find(moves, "Ram") and enabled(MOVES.Ram) then show("AbilityBar_Ram", "hidden") end
	show("AbilityBarTiles", table.concat(names, ","))
	layout()
end

-- look of one tile for a state: dim = extra tile transparency, frac = cooldown fill 0..1, secs = seconds left
local function paint(e, state, dim, frac, secs, sub)
	local t = e.t
	t.f.BackgroundTransparency = 0.3 + dim * 0.7
	local textT = dim
	t.name.TextTransparency, t.key.TextTransparency, t.sub.TextTransparency = textT, textT, textT
	t.fill.Size = UDim2.fromScale(1, math.clamp(frac, 0, 1))
	t.secs.Text = secs and secs > 0 and ("%.1fs"):format(secs) or ""
	t.sub.Text = sub or ""
	if state == "active" then
		t.stroke.Thickness, t.stroke.Color = 4, WHITE
	else
		t.stroke.Thickness, t.stroke.Color = 2.5, t.strokeColor
	end
	show("AbilityBar_" .. e.id, state)
end

local function update()
	local on = script:GetAttribute("AbilityBarEnabled") ~= false
	local skills = on and script:GetAttribute("AbilityBarHideOnSkills") ~= false and char:GetAttribute("SkillScreenOpen") == true -- v1.1
	gui.Enabled = on and not skills
	show("AbilityBarState", not on and "off" or skills and "skills" or "on")
	if not on or skills then return end
	rebuild()
	local now = workspace:GetServerTimeNow()
	for _, e in ipairs(tiles) do
		if e.kind == "slot" then
			if not e.part then
				paint(e, "empty", 0, 0, nil)
			elseif e.part == "thrusters" then
				local total = math.max(1, char:GetAttribute("DashCharges") or 1)
				local left = char:GetAttribute("DashChargesLeft") or total
				local nextAt = char:GetAttribute("DashNextChargeAt") or 0
				local rec = math.max(0.01, char:GetAttribute("DashRecharge") or 8)
				local wait = left < total and math.max(0, nextAt - now) or 0
				for i, p in ipairs(e.t.pips) do
					p.Visible = i <= total
					p.BackgroundColor3 = i <= left and ORANGE or WHITE
					p.BackgroundTransparency = i <= left and 0 or 0.75
				end
				if char:GetAttribute("DashEnabled") ~= true then
					paint(e, "off", 0.5, 0, nil)
				elseif char:GetAttribute("MechaDashLocal") == "dashing" then
					paint(e, "active", 0, wait / rec, wait)
				elseif left <= 0 then
					paint(e, "cooling", 0.25, wait / rec, wait)
				else
					paint(e, "ready", 0, wait / rec, wait)
				end
			elseif e.part == "cloak" then -- v1.2: Cloak Field
				local readyAt = tonumber(char:GetAttribute("CloakReadyAt")) or 0
				local untilT = tonumber(char:GetAttribute("CloakedUntil")) or 0
				local cd = math.max(0.01, tonumber(char:GetAttribute("CloakCooldown")) or 12)
				if char:GetAttribute("CloakEnabled") ~= true then
					paint(e, "off", 0.5, 0, nil)
				elseif untilT > now then
					paint(e, "active", 0, 0, untilT - now)
				elseif now < readyAt then
					paint(e, "cooling", 0.25, (readyAt - now) / cd, readyAt - now)
				else
					paint(e, "ready", 0, 0, nil)
				end
			elseif TIMED_PARTS[e.part] then -- v1.3: Adrenaline / Energy Shield
				local px = TIMED_PARTS[e.part]
				local readyAt = tonumber(char:GetAttribute(px .. "ReadyAt")) or 0
				local untilT = tonumber(char:GetAttribute(px .. "Until")) or 0
				local cd = math.max(0.01, tonumber(char:GetAttribute(px .. "Cooldown")) or 1)
				if char:GetAttribute(px .. "Enabled") ~= true then
					paint(e, "off", 0.5, 0, nil)
				elseif untilT > now then
					paint(e, "active", 0, 0, untilT - now)
				elseif now < readyAt then
					paint(e, "cooling", 0.25, (readyAt - now) / cd, readyAt - now)
				else
					paint(e, "ready", 0, 0, nil)
				end
			else
				paint(e, "ready", 0, 0, nil)
			end
		else
			local m = e.move
			local cd = math.max(0.01, char:GetAttribute(m.cd) or m.cdDefault)
			local stamp = char:GetAttribute(m.stamp)
			local left = typeof(stamp) == "number" and math.max(0, stamp + cd - now) or 0
			local st = m.stateAttr and char:GetAttribute(m.stateAttr)
			if (tonumber(char:GetAttribute("StunnedUntil")) or 0) > now then
				paint(e, "stunned", 0.25, left / cd, left, "STUN")
			elseif m.active and st and m.active[st] then
				paint(e, "active", 0, left / cd, left)
			elseif left > 0 then
				paint(e, "cooling", 0, left / cd, left)
			else
				paint(e, "ready", 0, 0, nil)
			end
		end
	end
end

local conns = {}
table.insert(conns, RunService.RenderStepped:Connect(update))
local cam = workspace.CurrentCamera
if cam then table.insert(conns, cam:GetPropertyChangedSignal("ViewportSize"):Connect(layout)) end
local function cleanup()
	for _, c in ipairs(conns) do c:Disconnect() end
	if gui.Parent then gui:Destroy() end
end
char.AncestryChanged:Connect(function(_, parent) if not parent then cleanup() end end)
local hum = char:FindFirstChildOfClass("Humanoid")
if hum then hum.Died:Connect(cleanup) end
update()
