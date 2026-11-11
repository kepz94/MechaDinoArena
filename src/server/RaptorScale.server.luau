-- RaptorScale v1.8 (Mecha Dino Arena) — makes every raptor bigger: player raptors and raptor bots. MDA-20, plan
-- docs/plans/TERRITORIES_v1.0.md Task 4 (Kepu 2026-10-28: "the raptor bots might be a little too small ... esp with the
-- camera angle"; answers: 2x, bots and players).
-- Who: every player character whose Species is "Raptor" (CharacterAdded, also SpeciesServer's raptor body) and every
--   model with BotSpecies "Raptor" (BotServer bots, Workspace.DinoIsland.Bots), once per model.
-- What: Model:ScaleTo(RaptorScale) (body, hitboxes, joints; IdleAnimation 1.24 / ShoulderCam 1.1 re-fit on scale, as for
--   growth), then the GrowthCurve distance keys the raptor has (BiteReachBack, BiteLungeDist, PounceDistance, PounceReach,
--   PounceLatchStandoff, EatRange, EatHeight, CameraStartZoom, ShoulderCamDistance; a missing key uses the reading
--   script's default from FALLBACK, a key with neither is left alone) are multiplied by the same factor (CameraZoom 1.1
--   zooms out again when CameraStartZoom changes). Then, if the body's lowest point is below the ground under it, the
--   model is lifted so it stands on the ground (0.2 stud gap). Health, speeds and damage are not changed.
-- Settings (script attributes): RaptorScaleEnabled (default true; false = new raptors keep scale 1), RaptorScale (2).
-- Diagnostics: script RaptorScaleVersion, RaptorScaleCount (models scaled); model RaptorScaleApplied (the factor used),
--   RaptorScaleLift (studs lifted, 0.1 steps).
-- v1.1 (MDA-118, plan docs/plans/PACHY_PLAYABLE_v1.0.md Task 4; Kepu 2026-10-30: pachy "a bit bigger than raptor" =
--   built at 15 studs and doubled like the raptor): player characters whose Species is "Pachy" are scaled the same way
--   (same distance keys and ground lift) by the script attribute PachyScale (default 2) while RaptorScalePachyEnabled
--   (default true) is on. Diagnostic: the model's RaptorScaleApplied holds the factor used.
-- v1.2 (Kepu 2026-10-30: "You made the bot pachys so damn small wtf. Make them raptor sized"): pachy bots (models with
--   BotSpecies "Pachy", BotServer 1.19) are scaled like the player pachy, by PachyScale (2), so they stand next to the
--   2x raptor bots at the pachy's "a bit bigger than raptor" size. Switch: script attribute RaptorScalePachyBotsEnabled
--   (default true, read per new bot; false = 1.1, pachy bots stay at scale 1).
-- v1.3 (MDA-135, plan docs/plans/HERRERA_KIT_v1.0.md Task 3): player characters whose Species is "Herrera" are scaled
--   like the pachy (same distance keys and ground lift) by the script attribute HerreraScale (default 2) while
--   RaptorScaleHerreraEnabled (default true) is on. (The header line read v1.1 through 1.2.)
-- v1.4 (MDA-172, plan docs/plans/TENO_KIT_v1.0.md Task 3): player characters whose Species is "Teno" are scaled the same way
--   by the script attribute TenoScale (default 2) while RaptorScaleTenoEnabled (default true) is on.
-- v1.5 (MDA-193, plan docs/plans/TREX_REDESIGN_v1.0.md Task 2; Kepu 2026-11-02 picked X = the true-to-life T-Rex at roster
--   scale): player characters whose Species is "TRex" (TRexModelData 2.0 / StarterCharacter 1.3, built at 38 studs) and
--   models with BotSpecies "TRex" are scaled the same way (Model:ScaleTo, the GrowthCurve distance keys, ground lift) by
--   the script attribute TRexScale (default 1.63 = 62 / 38). Switches: RaptorScaleTRexEnabled (players, default true) and
--   RaptorScaleTRexBotsEnabled (bots, default true), read per new model; off = the true-to-life T-Rex at 38 studs. Growth:
--   as for the other dinos (GrowthServer sets an absolute scale, RaptorScale multiplies once per model, marked by
--   RaptorScaleApplied, so the two never stack twice). The VERSION constant (still "1.2" through 1.4) now reads "1.5".
-- v1.6 (MDA-199, plan docs/plans/THERIZINO_KIT_v1.0.md Task 3): player characters whose Species is "Therizino" are scaled the
--   same way by the script attribute TherizinoScale (default 2) while RaptorScaleTheriEnabled (default true) is on.
-- v1.7 (MDA-223, plan docs/plans/DILO_KIT_v1.0.md Task 3): player characters whose Species is "Dilo" are scaled the same way by
--   the script attribute DiloScale (default 2) while RaptorScaleDiloEnabled (default true) is on.
-- v1.8 (MDA-332, plan docs/plans/TROODON_KIT_v1.0.md Task 3): player characters whose Species is "Troodon" are scaled the same
--   way by the script attribute TroodonScale (default 2) while RaptorScaleTroodonEnabled (default true) is on.
-- v1.9 (MDA-420; Kepu 2026-11-10 23:30 on live v662: "Why did you create a bunch of mini Dino's? ... not even scaled at the
--   correct size"): bots (models with BotSpecies, e.g. the practice bots of PracticeBots 1.1) of Herrera, Teno, Therizino,
--   Dilo and Troodon are scaled like the player of that species, by HerreraScale / TenoScale / TherizinoScale / DiloScale /
--   TroodonScale (default 2 each), the same distance keys and ground lift. Before 1.9 only Raptor, Pachy and T-Rex bots were
--   scaled, so those five came out at half a player's size. Switch: script attribute RaptorScaleOtherBotsEnabled (default
--   true, read per new bot; false = 1.8).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.6"
VERSION = "1.7" -- v1.7 Dilo
VERSION = "1.8" -- v1.8 Troodon
VERSION = "1.9" -- v1.9 the other five bot species
local DEFAULTS = {RaptorScaleEnabled = true, RaptorScale = 2}
local FALLBACK = {BiteReachBack = 8, BiteLungeDist = 3, EatRange = 8, EatHeight = 20, CameraStartZoom = 35} -- = GrowthServer 1.2
local GC = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("GrowthCurve"))

script:SetAttribute("RaptorScaleVersion", VERSION)
for k, v in pairs(DEFAULTS) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
script:SetAttribute("RaptorScaleCount", 0)

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function groundUnder(model, pos)
	local ignore = {model}
	local island = workspace:FindFirstChild("DinoIsland")
	local bots = island and island:FindFirstChild("Bots")
	if bots then table.insert(ignore, bots) end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(ignore, p.Character) end
	end
	params.FilterDescendantsInstances = ignore
	local r = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -200, 0), params)
	return r and r.Position.Y or nil
end

if script:GetAttribute("RaptorScalePachyEnabled") == nil then script:SetAttribute("RaptorScalePachyEnabled", true) end -- v1.1
if script:GetAttribute("PachyScale") == nil then script:SetAttribute("PachyScale", 2) end -- v1.1
if script:GetAttribute("RaptorScalePachyBotsEnabled") == nil then script:SetAttribute("RaptorScalePachyBotsEnabled", true) end -- v1.2
if script:GetAttribute("RaptorScaleHerreraEnabled") == nil then script:SetAttribute("RaptorScaleHerreraEnabled", true) end -- v1.3
if script:GetAttribute("HerreraScale") == nil then script:SetAttribute("HerreraScale", 2) end -- v1.3
if script:GetAttribute("RaptorScaleTRexEnabled") == nil then script:SetAttribute("RaptorScaleTRexEnabled", true) end -- v1.5
if script:GetAttribute("RaptorScaleTRexBotsEnabled") == nil then script:SetAttribute("RaptorScaleTRexBotsEnabled", true) end -- v1.5
if script:GetAttribute("TRexScale") == nil then script:SetAttribute("TRexScale", 1.63) end -- v1.5
if script:GetAttribute("RaptorScaleOtherBotsEnabled") == nil then script:SetAttribute("RaptorScaleOtherBotsEnabled", true) end -- v1.9
local OTHER_BOT_SCALE = {Herrera = "HerreraScale", Teno = "TenoScale", Therizino = "TherizinoScale", Dilo = "DiloScale",
	Troodon = "TroodonScale"} -- v1.9: bot species -> the player scale attribute (default 2)

local function apply(model, factor) -- v1.1: factor = the pachy's scale (nil = RaptorScale)
	if model:GetAttribute("RaptorScaleApplied") ~= nil or script:GetAttribute("RaptorScaleEnabled") == false then return end
	local f = factor or tonumber(script:GetAttribute("RaptorScale")) or DEFAULTS.RaptorScale
	if f <= 0 or math.abs(f - 1) < 1e-3 then return end
	model:SetAttribute("RaptorScaleApplied", f)
	model:ScaleTo(model:GetScale() * f)
	for _, k in ipairs(GC.DISTANCE_KEYS) do
		local v = model:GetAttribute(k)
		if type(v) ~= "number" then v = FALLBACK[k] end
		if type(v) == "number" then model:SetAttribute(k, v * f) end
	end
	-- stand on the ground
	local cf, size = model:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	local ground = groundUnder(model, cf.Position)
	local lift = 0
	if ground and bottom < ground + 0.2 then
		lift = ground + 0.2 - bottom
		model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
	end
	model:SetAttribute("RaptorScaleLift", math.floor(lift * 10 + 0.5) / 10)
	script:SetAttribute("RaptorScaleCount", (script:GetAttribute("RaptorScaleCount") or 0) + 1)
end

-- player raptors
local function onCharacter(char)
	if not char:FindFirstChildOfClass("Humanoid") then char:WaitForChild("Humanoid", 10) end
	if char.Parent and char:GetAttribute("Species") == "Raptor" then apply(char) end
	if char.Parent and char:GetAttribute("Species") == "Pachy" and script:GetAttribute("RaptorScalePachyEnabled") ~= false then -- v1.1
		apply(char, tonumber(script:GetAttribute("PachyScale")) or 2)
	end
	if char.Parent and char:GetAttribute("Species") == "Herrera" and script:GetAttribute("RaptorScaleHerreraEnabled") ~= false then -- v1.3
		apply(char, tonumber(script:GetAttribute("HerreraScale")) or 2)
	end
	if char.Parent and char:GetAttribute("Species") == "Teno" and script:GetAttribute("RaptorScaleTenoEnabled") ~= false then -- v1.4
		apply(char, tonumber(script:GetAttribute("TenoScale")) or 2)
	end
	if char.Parent and char:GetAttribute("Species") == "TRex" and script:GetAttribute("RaptorScaleTRexEnabled") ~= false then -- v1.5
		apply(char, tonumber(script:GetAttribute("TRexScale")) or 1.63)
	end
	if char.Parent and char:GetAttribute("Species") == "Therizino" and script:GetAttribute("RaptorScaleTheriEnabled") ~= false then -- v1.6
		apply(char, tonumber(script:GetAttribute("TherizinoScale")) or 2)
	end
	if char.Parent and char:GetAttribute("Species") == "Dilo" and script:GetAttribute("RaptorScaleDiloEnabled") ~= false then -- v1.7
		apply(char, tonumber(script:GetAttribute("DiloScale")) or 2)
	end
	if char.Parent and char:GetAttribute("Species") == "Troodon" and script:GetAttribute("RaptorScaleTroodonEnabled") ~= false then -- v1.8
		apply(char, tonumber(script:GetAttribute("TroodonScale")) or 2)
	end
end
local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

-- raptor bots
local function onModel(m)
	if m:IsA("Model") and m:GetAttribute("BotSpecies") == "Raptor" then task.defer(apply, m) end
	if m:IsA("Model") and m:GetAttribute("BotSpecies") == "Pachy" and script:GetAttribute("RaptorScalePachyBotsEnabled") ~= false then -- v1.2
		task.defer(apply, m, tonumber(script:GetAttribute("PachyScale")) or 2)
	end
	if m:IsA("Model") and m:GetAttribute("BotSpecies") == "TRex" and script:GetAttribute("RaptorScaleTRexBotsEnabled") ~= false then -- v1.5
		task.defer(apply, m, tonumber(script:GetAttribute("TRexScale")) or 1.63)
	end
	local key = m:IsA("Model") and OTHER_BOT_SCALE[m:GetAttribute("BotSpecies")] -- v1.9
	if key and script:GetAttribute("RaptorScaleOtherBotsEnabled") ~= false then
		task.defer(apply, m, tonumber(script:GetAttribute(key)) or 2)
	end
end
workspace.DescendantAdded:Connect(onModel)
for _, d in ipairs(workspace:GetDescendants()) do onModel(d) end
