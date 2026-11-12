-- HubModeRules.spec v1.0 (Mecha Dino Arena) — ModeRules 1.2 + SquadRules 1.3 (plan docs/plans/ISLAND_HUB_v1.0.md Task 2,
-- MDA-453). Run in Studio Edit (client side: the safe row must answer false there) and in a Play Server (the safe row
-- answers true); it sets ReplicatedStorage HubLive / HubSafeRules, Workspace ModeTestPractice and a temporary
-- ServerScriptService.HubServer only while it runs, and puts every one back. Returns "PASS n" or "FAIL ...".
local RS, SSS = game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService")
local arcade = game:GetService("ServerStorage").DinoArcade
local clones = {}
local function fresh(name) -- the clone stays until the end (ModeRules.serverKind finds HubRules next to itself)
	local src = arcade:FindFirstChild(name)
	local c = src:Clone() c.Parent = src.Parent
	table.insert(clones, c)
	local ok, m = pcall(require, c)
	return ok and m or nil
end
local SERVER = game:GetService("RunService"):IsServer()
local MR, SR = fresh("ModeRules"), fresh("SquadRules")
if not MR or not SR then return "FAIL require" end
local saved = {hub = RS:GetAttribute("HubLive"), rules = RS:GetAttribute("HubSafeRules"), prac = workspace:GetAttribute("ModeTestPractice"),
	arena = workspace:GetAttribute("ModeTestArena")}
local fails, passes = {}, 0
local function eq(name, got, want) if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end end
local okRun, err = pcall(function()
	eq("mr version", MR.Version, "1.2"); eq("sr version", SR.Version, "1.3")
	-- canAffect: hub row
	RS:SetAttribute("HubLive", nil)
	eq("sandbox pvp off", MR.canAffect(true, true, false, "sandbox"), false)
	RS:SetAttribute("HubLive", true)
	eq("hub pvp on", MR.canAffect(true, true, false, "sandbox"), true)
	eq("hub menu still safe", MR.canAffect(true, true, true, "sandbox"), false)
	eq("hub bots", MR.canAffect(false, true, false, "sandbox"), true)
	eq("hub non player", MR.canAffect(true, false, false, "sandbox"), true)
	eq("hub unknown mode", MR.canAffect(true, true, false, "other"), false)
	eq("hubLive", MR.hubLive(), true)
	RS:SetAttribute("HubLive", nil)
	eq("hubLive off", MR.hubLive(), false)
	-- serverKind in Studio Edit
	workspace:SetAttribute("ModeTestArena", nil)
	workspace:SetAttribute("ModeTestPractice", nil)
	local had = SSS:FindFirstChild("HubServer")
	if not had and not SERVER then
		eq("kind no hub", MR.serverKind(), "practice")
		local tmp = Instance.new("Script") tmp.Name = "HubServer" tmp.Disabled = true tmp.Parent = SSS
		eq("kind hub script disabled", MR.serverKind(), "practice")
		tmp.Disabled = false
		eq("kind hub", MR.serverKind(), "hub")
		workspace:SetAttribute("ModeTestPractice", true)
		eq("kind test practice", MR.serverKind(), "practice")
		workspace:SetAttribute("ModeTestPractice", nil)
		tmp:SetAttribute("HubEnabled", false)
		eq("kind switch off", MR.serverKind(), "practice")
		tmp:Destroy()
	elseif had then
		eq("kind hub (installed)", MR.serverKind(), had.Enabled and had:GetAttribute("HubEnabled") ~= false and "hub" or "practice")
	end
	workspace:SetAttribute("ModeTestArena", true)
	eq("kind arena", MR.serverKind(), "arena")
	workspace:SetAttribute("ModeTestArena", nil)
	-- sameChar safe row
	local a = Instance.new("Model") a.Name = "ZZ_HubA"
	local b = Instance.new("Model") b.Name = "ZZ_HubB"
	RS:SetAttribute("HubLive", true)
	eq("no safe", SR.sameChar(a, b), false)
	a:SetAttribute("HubSafe", true)
	eq("a safe", SR.sameChar(a, b), SERVER)
	eq("b order", SR.sameChar(b, a), SERVER)
	eq("self", SR.sameChar(a, a), SR.sameIds(SR.live(), SR.idOf(a), SR.idOf(a), true))
	RS:SetAttribute("HubSafeRules", false)
	eq("switch off", SR.sameChar(a, b), false)
	RS:SetAttribute("HubSafeRules", nil)
	RS:SetAttribute("HubLive", nil)
	eq("hub off", SR.sameChar(a, b), false)
	a:SetAttribute("HubSafe", nil) b:SetAttribute("HubSafe", true)
	RS:SetAttribute("HubLive", true)
	eq("b safe", SR.sameChar(a, b), SERVER)
	a:Destroy() b:Destroy()
	-- leaders (no players in Edit)
	eq("leaderOf none", SR.leaderOf("x_1"), nil)
	eq("leaderOf empty", SR.leaderOf(""), nil)
	eq("isLeader nil", SR.isLeader(nil), false)
end)
RS:SetAttribute("HubLive", saved.hub); RS:SetAttribute("HubSafeRules", saved.rules)
workspace:SetAttribute("ModeTestPractice", saved.prac); workspace:SetAttribute("ModeTestArena", saved.arena)
for _, c in ipairs(clones) do c:Destroy() end
if not okRun then return "FAIL error: " .. tostring(err) end
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes .. (SERVER and " (server)" or " (edit/client)")
