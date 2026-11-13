-- PregameModels v1.0 (Mecha Dino Arena) — the 3D dinos and mecha parts the pre-game screens show (Script, ServerScriptService).
-- MDA-485, plan docs/plans/PREGAME_LINEUP_v1.0.md T9, mockup docs/mockups/pregame_v0.4.html (Kepu 2026-11-12 18:54: "show the 3D
-- Dino model instead of that badge ... transitions to the mecha parts with the previews on that same screen").
-- Output: ReplicatedStorage.PregameModels (Folder) > <Dino> (Folder, one per DINOS) > Body (Model) + Parts (Folder) > <pathId>
--   (Model). PregameScreen 1.0 clones them into ViewportFrames.
--   * Body: ServerStorage.DinoArcade.DinoModelBuilder.build(Models.<Dino>ModelData), pivoted to the origin facing -Z (as the Lab's
--     mannequins), cleaned (below). Attribute BodySize (bounding box size, Vector3), BodyMinY (bounding box bottom).
--   * Parts: every path the Lab shows as a MECHA ABILITY for that dino (SkillTree: mech, BUTTONS, not soon, seesPath(p, dino)),
--     built by the same BindableFunction the Lab uses (LabPreviewServer 1.2's rule: "BuildPreview_<id>" anywhere under
--     ServerScriptService, or "BuildPreview" in a SOURCES script) on a fresh copy of that dino's body at the origin, so the part
--     sits where it does on the dino (not re-centred, unlike the Lab). PreviewBody "none" or a SOURCES entry without a body
--     (Shock Mine, Med-Station: things dropped on the ground) -> built with no body, attribute Free = true (the screen puts it
--     beside the dino).
--   * Clean (the Lab's): scripts, sounds, particles, trails, beams, lights, fire, smoke, sparkles removed; joints to parts outside
--     the model removed; every BasePart Anchored, CanCollide / CanQuery / CanTouch false.
-- When: BUILD_DELAY (3) s after start (the part scripts make their BindableFunctions at start), all bodies, then every part,
--   task.wait() between builds. A builder added later (DescendantAdded) builds its missing parts then.
-- Switch: script attribute PregameModelsEnabled (default true, read at start; false -> nothing is built; the screens fall back to
--   flat icons). Also a copy of ServerStorage.DinoArcade.StatSheet (pure) as PregameModels.StatSheet, for the select screen's
--   class, stats and main attack / jump names. Diagnostics: PregameModelsVersion, PregameModelsState ("off" / "building" / "ready"), PregameModelsBodies,
--   PregameModelsParts (count), PregameModelsMissing (comma list "<dino>:<id>" of wanted parts with no builder or a failed build).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local VERSION = "1.0"
local BUILD_DELAY = 3
local DINOS = {"Raptor", "TRex", "Pachy", "Herrera", "Teno", "Therizino", "Dilo", "Troodon"}
local SOURCES = { -- LabPreviewServer 1.0's list: these scripts expose a plain "BuildPreview"
	{id = "adrenaline", script = "AdrenalineServer", body = true},
	{id = "screech", script = "ScreechServer", body = true},
	{id = "shield", script = "EnergyShieldServer", body = true},
	{id = "cloak", script = "CloakServer", body = true},
	{id = "blade", script = "BladeServer", body = true},
	{id = "thrusters", script = "MechaServer", body = true},
	{id = "traps", script = "MineServer", body = false},
	{id = "scent", script = "ScentServer", body = true},
}
local DROP = {"BaseScript", "Sound", "ParticleEmitter", "Trail", "Beam", "Light", "Fire", "Smoke", "Sparkles"}

script:SetAttribute("PregameModelsVersion", VERSION)
if script:GetAttribute("PregameModelsEnabled") == nil then script:SetAttribute("PregameModelsEnabled", true) end
if script:GetAttribute("PregameModelsEnabled") == false then
	script:SetAttribute("PregameModelsState", "off")
	return
end
script:SetAttribute("PregameModelsState", "building")

local da = ServerStorage:WaitForChild("DinoArcade", 10)
local Builder, ST
pcall(function() Builder = require(da:WaitForChild("DinoModelBuilder", 10)) end)
pcall(function() ST = require(da:WaitForChild("SkillTree", 10)) end)

local root = ReplicatedStorage:FindFirstChild("PregameModels")
if not root then
	root = Instance.new("Folder")
	root.Name = "PregameModels"
	root.Parent = ReplicatedStorage
end
do -- the stat sheet for the select screen
	local ss = da and da:FindFirstChild("StatSheet")
	if ss and not root:FindFirstChild("StatSheet") then ss:Clone().Parent = root end
end

local function clean(model)
	model.Parent = nil
	for _, d in ipairs(model:GetDescendants()) do
		local drop = false
		for _, cls in ipairs(DROP) do
			if d:IsA(cls) then drop = true break end
		end
		if drop then
			d:Destroy()
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint") then
			local a = d:IsA("Constraint") and nil or d.Part0
			local b = d:IsA("Constraint") and nil or d.Part1
			if d:IsA("Constraint") or not (a and a:IsDescendantOf(model) and b and b:IsDescendantOf(model)) then d:Destroy() end
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
		end
	end
end

-- bodies: [dino] = the clean template kept here (never parented to Workspace)
local bodies, folders = {}, {}
local function bodyOf(dino)
	if bodies[dino] ~= nil then return bodies[dino] or nil end
	local ok, m = pcall(function()
		local mod = da:WaitForChild("Models"):FindFirstChild(dino .. "ModelData")
		if not (Builder and mod) then return nil end
		return Builder.build(require(mod), {name = "Pregame_" .. dino})
	end)
	if not ok or not m then
		if not ok then warn("PregameModels: " .. dino .. " body: " .. tostring(m)) end
		bodies[dino] = false
		return nil
	end
	m:PivotTo(CFrame.new())
	bodies[dino] = m
	local f = Instance.new("Folder")
	f.Name = dino
	local show = m:Clone()
	clean(show)
	show.Name = "Body"
	local cf, size = show:GetBoundingBox()
	show:SetAttribute("BodySize", size)
	show:SetAttribute("BodyMinY", cf.Position.Y - size.Y / 2)
	show.Parent = f
	local parts = Instance.new("Folder")
	parts.Name = "Parts"
	parts.Parent = f
	f.Parent = root
	folders[dino] = f
	local n = 0
	for _, v in pairs(bodies) do if v then n += 1 end end
	script:SetAttribute("PregameModelsBodies", n)
	return m
end

-- which parts each dino shows (the Lab's MECHA ABILITIES)
local function wanted(dino)
	local out = {}
	if not ST then return out end
	for _, id in ipairs(ST.PATH_ORDER or {}) do
		local p = ST.PATHS[id]
		if p and p.mech == true and ST.BUTTONS[id] == true and not p.soon and (not ST.seesPath or ST.seesPath(p, dino)) then
			table.insert(out, id)
		end
	end
	return out
end

-- builders: [id] = {fn, body (true / false)}
local builders = {}
local function addBuilder(fn)
	if not fn:IsA("BindableFunction") then return nil end
	local id = fn.Name:match("^BuildPreview_(.+)$")
	if not id then return nil end
	builders[id] = {fn = fn, body = fn:GetAttribute("PreviewBody") ~= "none"}
	return id
end
local function addSources() -- after BUILD_DELAY: those scripts make "BuildPreview" when they start
	for _, src in ipairs(SOURCES) do
		local s = ServerScriptService:FindFirstChild(src.script)
		local fn = s and s:WaitForChild("BuildPreview", 10)
		if fn and fn:IsA("BindableFunction") then builders[src.id] = {fn = fn, body = src.body} end
	end
end

local missing = {}
local function setMissing()
	local out = {}
	for k in pairs(missing) do table.insert(out, k) end
	table.sort(out)
	script:SetAttribute("PregameModelsMissing", table.concat(out, ","))
	local n = 0
	for _, f in pairs(folders) do n += #f.Parts:GetChildren() end
	script:SetAttribute("PregameModelsParts", n)
end

local function build(dino, id)
	local f = folders[dino]
	if not f or f.Parts:FindFirstChild(id) then return end
	local b = builders[id]
	if not b then missing[dino .. ":" .. id] = true return end
	local ok, res = pcall(function()
		if b.body then
			local m = bodyOf(dino)
			if not m then return nil end
			local c = m:Clone()
			c:PivotTo(CFrame.new())
			local r = b.fn:Invoke(c)
			if r then r.Parent = nil end
			c:Destroy()
			return r
		end
		return b.fn:Invoke()
	end)
	if ok and typeof(res) == "Instance" and res:IsA("Model") then
		clean(res)
		res.Name = id
		res:SetAttribute("PathId", id)
		res:SetAttribute("Free", not b.body)
		if not b.body then -- a dropped thing: stand it on y = 0 at the origin; the screen moves it beside the dino
			local cf, size = res:GetBoundingBox()
			res:PivotTo(res:GetPivot() - Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z))
		end
		res.Parent = f.Parts
		missing[dino .. ":" .. id] = nil
	else
		if not ok then warn("PregameModels: " .. dino .. ":" .. id .. ": " .. tostring(res)) end
		missing[dino .. ":" .. id] = true
	end
end

task.wait(BUILD_DELAY)
addSources()
for _, d in ipairs(ServerScriptService:GetDescendants()) do addBuilder(d) end
for _, dino in ipairs(DINOS) do
	bodyOf(dino)
	task.wait()
end
for _, dino in ipairs(DINOS) do
	for _, id in ipairs(wanted(dino)) do
		build(dino, id)
		task.wait()
	end
end
setMissing()
script:SetAttribute("PregameModelsState", "ready")

ServerScriptService.DescendantAdded:Connect(function(d)
	task.defer(function()
		local id = addBuilder(d)
		if not id then return end
		for _, dino in ipairs(DINOS) do
			if table.find(wanted(dino), id) then build(dino, id) end
		end
		setMissing()
	end)
end)
