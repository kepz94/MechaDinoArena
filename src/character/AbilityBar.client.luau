-- AbilityBar v1.12 (Mecha Dino Arena) — PC ability bar: the 2 mecha loadout slots and this dino's own moves, each with
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
-- v1.6 (Kepu 2026-10-30: "can you rename the pounce button to attack and always assign it to left click on pc. it will be called attack for all dinos because my testers were confused what pounce meant last night"): with script attribute AbilityBarAttackEnabled (default true, read at start)
--   the BITE and POUNCE tiles both read "ATTACK" and the Pounce tile's key hint is "LMB" (PounceTest 1.5 binds the left
--   mouse button). false = 1.5 names and keys.
-- v1.7 (pachy headbutt, MDA-120, plan docs/plans/PACHY_PLAYABLE_v1.0.md Task 9, mockup docs/mockups/pachy_charge_options.html
--   option A "Pips", Kepu 2026-10-30 "1.A"): with script attribute AbilityBarHeadbuttEnabled (default true, read at
--   start) the pachy's row is Headbutt (key "LMB", name "ATTACK", yellow stroke rgb(255, 200, 50)) then Leap
--   (SPECIES_MOVES.Pachy). The Headbutt tile has one pip per charge, centred at the bottom (12 px circles at T = 92,
--   scaled with the tile; yellow 2 px ring; filled = ready; the charge refilling next fills from the bottom with its
--   refill progress). Charges come from the server: HeadbuttChargesNow / HeadbuttChargesMax / HeadbuttRefillStart /
--   HeadbuttRefillAt (HeadbuttServer 1.0). Headbutt tile states (first match wins): "stunned" (STUN, dim 0.25) /
--   "active" (HeadbuttLocalState windup / charge: stroke 4 px yellow) / "empty" (0 charges: dim 0.45, white fill at
--   0.89 rising with the refill progress) / "ready". A red "SLOWED" pill sits above the tile while HeadbuttSelfSlowUntil
--   or HeadbuttSlowUntil is in the future. false = 1.6 (the pachy gets the fallback order, no Headbutt tile).
--   Diagnostics: AbilityBar_Headbutt (state), AbilityBarHeadbuttPips ("<ready>/<max>"), AbilityBarHeadbuttSlowed.
-- v1.8 (pachy Grappling Hook, MDA-122): TIMED_PARTS.hookarm = "Hook" -> a Grappling Hook slot tile uses the timed-part
--   states (off / cooling with HookReadyAt and HookCooldown / ready; no HookUntil, so never "active").
-- v1.9 (Kepu 2026-10-30: "mecha legs should take up an ability slot ... it's through the jump button"; SkillTree 1.23):
--   a slotted "mechalegs" tile ("MECHA LEGS") shows "Space" as its key (it fires through the jump, not the slot key)
--   and the leap's states: "off" (MechaLegsEnabled not true) / "active" (JumpTestState crouch / air) / "cooling"
--   (JumpPredictedAt + JumpCooldown, with the sweep and seconds) / "ready". Switch: script attribute
--   AbilityBarLegsEnabled (default true, read at start; false = the plain slot tile).
-- v1.12 (pachy parts batch 3, MDA-126..128): TIMED_PARTS += servodash "ServoDash" and visor "Visor" (both with Until:
--   active / cooling / ready) and ink "Ink" (no Until: cooling / ready). Switch: script attribute AbilityBarBatch3Enabled
--   (default true, read at start; false = 1.11).
-- v1.11 (pachy Med-Station, MDA-125): TIMED_PARTS.medstation = "Med" -> a Med-Station slot tile shows "off" (MedEnabled not
--   true) / "cooling" (sweep + seconds to MedReadyAt, from MedCooldown) / "ready"; the pad's run time is not shown on the
--   tile (no MedUntil). Switch: script attribute AbilityBarMedEnabled (default true, read at start; false = 1.10).
-- v1.10 (pachy Blood Rush, MDA-124, mockup docs/mockups/pachy_sacrifice_options.html "C · Both"): Blood Rush state =
--   BloodRushEnabled, HeadbuttChargesNow 0, and "left" = how many more sacrifices can be made now: min(BloodRushMax -
--   HeadbuttSacrifices, the presses health allows while it stays above half of MaxHealth, each taking BloodRushCost x
--   max, never below 1). On the Headbutt tile at 0 charges with Blood Rush on: the charge pips hide and BloodRushMax red
--   hearts (♥, rgb(224, 40, 74); grey 0.6 when used up) take their place; with left > 0 the tile is painted "sacrifice"
--   (full colour, red 3 px stroke) and a red "-25% HP" tag (the cost in %) sits above the SLOWED pill. A slotted
--   "bloodrush" tile shows key "LMB" (it fires through ATTACK) and "ready" (left > 0) / "spent" (dim 0.25: Blood Rush on,
--   none left) / "waiting" (charges left: ready once they run out) / "off". Switch: script attribute AbilityBarBloodEnabled
--   (default true, read at start; false = 1.9). Diagnostics: AbilityBarBloodLeft.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.12"
if script:GetAttribute("AbilityBarBloodEnabled") == nil then script:SetAttribute("AbilityBarBloodEnabled", true) end -- v1.10
local BLOOD_TILE = script:GetAttribute("AbilityBarBloodEnabled") ~= false
local BLOOD = Color3.fromRGB(224, 40, 74)
local function bloodLeft(char) -- v1.10: sacrifices possible right now (nil when Blood Rush is off)
	if char:GetAttribute("BloodRushEnabled") ~= true then return nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return 0 end
	local max = math.max(1, hum.MaxHealth)
	local cap = (tonumber(char:GetAttribute("BloodRushMax")) or 2) - (tonumber(char:GetAttribute("HeadbuttSacrifices")) or 0)
	local cost = (tonumber(char:GetAttribute("BloodRushCost")) or 0.25) * max
	local h, n = hum.Health, 0
	while n < cap and h > max * 0.5 do h = math.max(1, h - cost); n += 1 end
	return n
end
if script:GetAttribute("AbilityBarLegsEnabled") == nil then script:SetAttribute("AbilityBarLegsEnabled", true) end -- v1.9
local LEGS_TILE = script:GetAttribute("AbilityBarLegsEnabled") ~= false
local char = script.Parent
local TIMED_PARTS = {adrenaline = "Adrenaline", shield = "EnergyShield"} -- v1.3: part id -> attribute prefix
TIMED_PARTS.scent, TIMED_PARTS.screech = "Scent", "Screech" -- v1.4: raptor parts batch 2
TIMED_PARTS.traps = "Mine" -- v1.5: Shock Mine
TIMED_PARTS.hookarm = "Hook" -- v1.8: pachy Grappling Hook (HookEnabled / HookReadyAt / HookCooldown; no HookUntil)
if script:GetAttribute("AbilityBarMedEnabled") == nil then script:SetAttribute("AbilityBarMedEnabled", true) end -- v1.11
if script:GetAttribute("AbilityBarMedEnabled") ~= false then TIMED_PARTS.medstation = "Med" end -- v1.11: pachy Med-Station (no MedUntil: ready / cooling)
if script:GetAttribute("AbilityBarBatch3Enabled") == nil then script:SetAttribute("AbilityBarBatch3Enabled", true) end -- v1.12
if script:GetAttribute("AbilityBarBatch3Enabled") ~= false then -- v1.12: pachy parts batch 3
	TIMED_PARTS.servodash, TIMED_PARTS.visor, TIMED_PARTS.ink = "ServoDash", "Visor", "Ink"
end
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
if script:GetAttribute("AbilityBarAttackEnabled") == nil then script:SetAttribute("AbilityBarAttackEnabled", true) end -- v1.6
if script:GetAttribute("AbilityBarAttackEnabled") ~= false then -- v1.6: one name for every dino's main attack
	MOVES.Bite.name, MOVES.Pounce.name, MOVES.Pounce.key = "ATTACK", "ATTACK", "LMB"
end
local SPECIES_MOVES = {Raptor = {"Pounce", "Leap"}, TRex = {"Bite", "Ram"}}
local YELLOW = Color3.fromRGB(255, 200, 50) -- v1.7
if script:GetAttribute("AbilityBarHeadbuttEnabled") == nil then script:SetAttribute("AbilityBarHeadbuttEnabled", true) end -- v1.7
local HEADBUTT_ON = script:GetAttribute("AbilityBarHeadbuttEnabled") ~= false
if HEADBUTT_ON then -- v1.7: pachy headbutt tile (not in FALLBACK_ORDER, so other dinos never get it)
	MOVES.Headbutt = {enabled = "HeadbuttEnabled", enabledDefault = false, key = "LMB", name = "ATTACK", color = YELLOW,
		charges = true}
	SPECIES_MOVES.Pachy = {"Headbutt", "Leap"}
end
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
		local key = (LEGS_TILE and id == "mechalegs") and "Space" or SLOT_KEYS[n] -- v1.9: Mecha Legs fires through the jump
		if BLOOD_TILE and id == "bloodrush" then key = "LMB" end -- v1.10: Blood Rush fires through ATTACK
		local t = makeTile("Slot_" .. n, key, title, id and ORANGE or WHITE, id == "thrusters")
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
		if m.charges then -- v1.7: charge pips (bottom centre) + SLOWED pill
			local row = Instance.new("Frame")
			row.Name = "ChargePips"
			row.BackgroundTransparency = 1
			row.AnchorPoint = Vector2.new(0.5, 1)
			row.Position = UDim2.fromScale(0.5, 0.935)
			row.Size = UDim2.fromScale(0.9, 0.13)
			row.ZIndex = 4
			row.Parent = t.f
			local list = Instance.new("UIListLayout")
			list.FillDirection = Enum.FillDirection.Horizontal
			list.HorizontalAlignment = Enum.HorizontalAlignment.Center
			list.VerticalAlignment = Enum.VerticalAlignment.Center
			list.Padding = UDim.new(0.1, 0)
			list.Parent = row
			t.chargePips = {}
			for i = 1, 3 do
				local pip = Instance.new("Frame")
				pip.Name = "Charge_" .. i
				pip.Size = UDim2.fromScale(1, 1)
				pip.SizeConstraint = Enum.SizeConstraint.RelativeYY
				pip.BackgroundTransparency = 1
				pip.ClipsDescendants = true
				pip.ZIndex = 4
				pip.LayoutOrder = i
				pip.Parent = row
				local pc = Instance.new("UICorner")
				pc.CornerRadius = UDim.new(0.5, 0)
				pc.Parent = pip
				local ring = Instance.new("UIStroke")
				ring.Color = YELLOW
				ring.Thickness = 2
				ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				ring.Parent = pip
				local fillP = Instance.new("Frame")
				fillP.Name = "Fill"
				fillP.AnchorPoint = Vector2.new(0, 1)
				fillP.Position = UDim2.fromScale(0, 1)
				fillP.Size = UDim2.fromScale(1, 0)
				fillP.BackgroundColor3 = YELLOW
				fillP.BorderSizePixel = 0
				fillP.ZIndex = 4
				fillP.Parent = pip
				local fc2 = Instance.new("UICorner")
				fc2.CornerRadius = UDim.new(0.5, 0)
				fc2.Parent = fillP
				t.chargePips[i] = {f = pip, fill = fillP, ring = ring}
			end
			local slow = Instance.new("TextLabel")
			slow.Name = "Slowed"
			slow.AnchorPoint = Vector2.new(0.5, 1)
			slow.Position = UDim2.new(0.5, 0, 0, -6)
			slow.Size = UDim2.fromScale(1.05, 0.26)
			slow.BackgroundColor3 = RED
			slow.BorderSizePixel = 0
			slow.Font = Enum.Font.FredokaOne
			slow.Text = "SLOWED"
			slow.TextScaled = true
			slow.TextColor3 = WHITE
			slow.Visible = false
			slow.ZIndex = 5
			slow.Parent = t.f
			local sc = Instance.new("UICorner")
			sc.CornerRadius = UDim.new(0.5, 0)
			sc.Parent = slow
			local sp = Instance.new("UIPadding")
			sp.PaddingTop, sp.PaddingBottom = UDim.new(0.14, 0), UDim.new(0.14, 0)
			sp.Parent = slow
			t.slowed = slow
			if BLOOD_TILE then -- v1.10: Blood Rush hearts + cost tag
				local hearts = Instance.new("Frame")
				hearts.Name = "BloodHearts"
				hearts.BackgroundTransparency = 1
				hearts.AnchorPoint = Vector2.new(0.5, 1)
				hearts.Position = UDim2.fromScale(0.5, 0.96)
				hearts.Size = UDim2.fromScale(0.9, 0.2)
				hearts.ZIndex = 4
				hearts.Visible = false
				hearts.Parent = t.f
				local hl = Instance.new("UIListLayout")
				hl.FillDirection = Enum.FillDirection.Horizontal
				hl.HorizontalAlignment = Enum.HorizontalAlignment.Center
				hl.VerticalAlignment = Enum.VerticalAlignment.Center
				hl.Padding = UDim.new(0.06, 0)
				hl.Parent = hearts
				t.bloodHearts = {}
				for i = 1, 3 do
					local h = Instance.new("TextLabel")
					h.Name = "Heart_" .. i
					h.BackgroundTransparency = 1
					h.Size = UDim2.fromScale(1, 1)
					h.SizeConstraint = Enum.SizeConstraint.RelativeYY
					h.Font = Enum.Font.GothamBlack
					h.Text = "♥"
					h.TextScaled = true
					h.TextColor3 = BLOOD
					h.ZIndex = 4
					h.LayoutOrder = i
					h.Parent = hearts
					t.bloodHearts[i] = h
				end
				t.bloodRow = hearts
				local tagL = Instance.new("TextLabel")
				tagL.Name = "BloodTag"
				tagL.AnchorPoint = Vector2.new(0.5, 1)
				tagL.Position = UDim2.new(0.5, 0, -0.3, -8)
				tagL.Size = UDim2.fromScale(1.05, 0.24)
				tagL.BackgroundColor3 = BLOOD
				tagL.BorderSizePixel = 0
				tagL.Font = Enum.Font.FredokaOne
				tagL.Text = "-25% HP"
				tagL.TextScaled = true
				tagL.TextColor3 = WHITE
				tagL.Visible = false
				tagL.ZIndex = 5
				tagL.Parent = t.f
				local tc = Instance.new("UICorner")
				tc.CornerRadius = UDim.new(0.5, 0)
				tc.Parent = tagL
				local tp = Instance.new("UIPadding")
				tp.PaddingTop, tp.PaddingBottom = UDim.new(0.14, 0), UDim.new(0.14, 0)
				tp.Parent = tagL
				t.bloodTag = tagL
			end
		end
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
			elseif BLOOD_TILE and e.part == "bloodrush" then -- v1.10: Blood Rush
				local left = bloodLeft(char)
				if left == nil then
					paint(e, "off", 0.5, 0, nil)
				elseif (tonumber(char:GetAttribute("HeadbuttChargesNow")) or 1) >= 1 then
					paint(e, "waiting", 0, 0, nil)
				elseif left > 0 then
					paint(e, "ready", 0, 0, nil)
					e.t.stroke.Color = BLOOD
				else
					paint(e, "spent", 0.25, 0, nil)
				end
			elseif LEGS_TILE and e.part == "mechalegs" then -- v1.9: Mecha Legs = the leap's cooldown
				local cd = math.max(0.01, tonumber(char:GetAttribute("JumpCooldown")) or 6)
				local stamp = char:GetAttribute("JumpPredictedAt")
				local left = typeof(stamp) == "number" and math.max(0, stamp + cd - now) or 0
				local js = char:GetAttribute("JumpTestState")
				if char:GetAttribute("MechaLegsEnabled") ~= true then
					paint(e, "off", 0.5, 0, nil)
				elseif js == "crouch" or js == "air" then
					paint(e, "active", 0, left / cd, left)
				elseif left > 0 then
					paint(e, "cooling", 0.25, left / cd, left)
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
		elseif e.move.charges then -- v1.7: pachy headbutt (charges, no cooldown)
			local maxC = math.clamp(math.floor(tonumber(char:GetAttribute("HeadbuttChargesMax")) or 2), 1, 3)
			local nowC = math.clamp(math.floor(tonumber(char:GetAttribute("HeadbuttChargesNow")) or maxC), 0, maxC)
			local rs, ra = tonumber(char:GetAttribute("HeadbuttRefillStart")) or 0, tonumber(char:GetAttribute("HeadbuttRefillAt")) or 0
			local part = (ra > rs and nowC < maxC) and math.clamp((now - rs) / (ra - rs), 0, 1) or 0
			for i, pip in ipairs(e.t.chargePips) do
				pip.f.Visible = i <= maxC
				pip.fill.Size = UDim2.fromScale(1, i <= nowC and 1 or (i == nowC + 1 and part or 0))
			end
			local bLeft = BLOOD_TILE and nowC <= 0 and bloodLeft(char) or nil -- v1.10
			if e.t.bloodRow then
				local bMax = math.clamp(math.floor(tonumber(char:GetAttribute("BloodRushMax")) or 2), 1, 3)
				e.t.bloodRow.Visible = bLeft ~= nil
				e.t.chargePips[1].f.Parent.Visible = bLeft == nil
				for i, h in ipairs(e.t.bloodHearts) do
					h.Visible = i <= bMax
					h.TextColor3 = (bLeft and i <= bLeft) and BLOOD or WHITE
					h.TextTransparency = (bLeft and i <= bLeft) and 0 or 0.6
				end
				e.t.bloodTag.Visible = bLeft ~= nil and bLeft > 0
				e.t.bloodTag.Text = ("-%d%% HP"):format(math.floor((tonumber(char:GetAttribute("BloodRushCost")) or 0.25) * 100 + 0.5))
				show("AbilityBarBloodLeft", bLeft or -1)
			end
			local slowedUntil = math.max(tonumber(char:GetAttribute("HeadbuttSelfSlowUntil")) or 0,
				tonumber(char:GetAttribute("HeadbuttSlowUntil")) or 0)
			e.t.slowed.Visible = slowedUntil > now
			local hs = char:GetAttribute("HeadbuttLocalState")
			e.t.fill.BackgroundColor3, e.t.fill.BackgroundTransparency = Color3.new(0, 0, 0), 0.38
			if (tonumber(char:GetAttribute("StunnedUntil")) or 0) > now then
				paint(e, "stunned", 0.25, 0, nil, "STUN")
			elseif hs == "windup" or hs == "charge" then
				paint(e, "active", 0, 0, nil)
				e.t.stroke.Color = YELLOW
			elseif nowC <= 0 and bLeft and bLeft > 0 then -- v1.10: a Blood Rush sacrifice is ready
				paint(e, "sacrifice", 0, 0, nil)
				e.t.stroke.Thickness, e.t.stroke.Color = 3, BLOOD
				e.t.fill.Size = UDim2.fromScale(1, part)
				e.t.fill.BackgroundColor3, e.t.fill.BackgroundTransparency = WHITE, 0.89
			elseif nowC <= 0 then
				paint(e, "empty", 0.45, 0, nil)
				e.t.fill.BackgroundColor3, e.t.fill.BackgroundTransparency = WHITE, 0.89
				e.t.fill.Size = UDim2.fromScale(1, part)
			else
				paint(e, "ready", 0, 0, nil)
			end
			show("AbilityBarHeadbuttPips", nowC .. "/" .. maxC)
			show("AbilityBarHeadbuttSlowed", slowedUntil > now)
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
