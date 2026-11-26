-- PersonaPlates v1.0 (Mecha Dino Arena) — no bot health plate over filler bots (LocalScript, StarterPlayerScripts). Filler Bots
-- v1.0 T5 (MDA-578), plan docs/plans/FILLER_BOTS_v1.0.md, option A. Found in the T2 Studio check 2026-11-25: BiteTargetHealth's
-- green name + health BillboardGui "TargetBar" floats over every bot, and players have none, so it gives the bots away (and
-- TargetHUD 1.x copies it on screen when you hit one, which never happens for a player).
-- What: every model in Workspace.DinoIsland.Bots with FillerPersona = true (now, added later, and when the attribute turns
--   true): its "TargetBar" BillboardGui (anywhere in the model, now or added later) is moved out of the model on this client
--   only (Parent = nil; the server's copy is untouched). TargetHUD then finds no bar, as for a player. Practice bots without a
--   persona keep their plate.
-- Switch: script attribute PersonaPlatesEnabled (default true, read when a plate is found; false = plates stay).
-- Diagnostics: PersonaPlatesVersion, PersonaPlatesHidden (count).
local VERSION = "1.0"
script:SetAttribute("PersonaPlatesVersion", VERSION)
if script:GetAttribute("PersonaPlatesEnabled") == nil then script:SetAttribute("PersonaPlatesEnabled", true) end
script:SetAttribute("PersonaPlatesHidden", 0)

local function hidePlate(b)
	if not (b:IsA("BillboardGui") and b.Name == "TargetBar") then return end
	if script:GetAttribute("PersonaPlatesEnabled") == false then return end
	task.defer(function()
		if b.Parent then
			b.Parent = nil
			script:SetAttribute("PersonaPlatesHidden", (script:GetAttribute("PersonaPlatesHidden") or 0) + 1)
		end
	end)
end

local function watch(m)
	if not m:IsA("Model") then return end
	local done = false
	local function go()
		if done or m:GetAttribute("FillerPersona") ~= true then return end
		done = true
		for _, d in ipairs(m:GetDescendants()) do hidePlate(d) end
		m.DescendantAdded:Connect(hidePlate)
	end
	go()
	if not done then m:GetAttributeChangedSignal("FillerPersona"):Connect(go) end
end

task.spawn(function()
	local isl = workspace:WaitForChild("DinoIsland", 1e9)
	local f = isl and isl:WaitForChild("Bots", 1e9)
	if not f then return end
	f.ChildAdded:Connect(watch)
	for _, m in ipairs(f:GetChildren()) do watch(m) end
end)
