-- RaptorScale v1.1 (Mecha Dino Arena) — makes every raptor bigger: player raptors and raptor bots. MDA-20, plan
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
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.1"
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
end
workspace.DescendantAdded:Connect(onModel)
for _, d in ipairs(workspace:GetDescendants()) do onModel(d) end
