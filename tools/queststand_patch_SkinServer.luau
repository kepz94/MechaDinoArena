-- queststand_patch_SkinServer: QUEST_STAND_v1.0.
local PAIRS = {
{[=====[VERSION = "1.6" -- v1.6 island streak earn stat]=====], [=====[VERSION = "1.6" -- v1.6 island streak earn stat
VERSION = "1.7" -- v1.7 stand claims + SkinGrant
-- v1.7 (Quest Stand, plan docs/plans/QUEST_STAND_v1.0.md Task 3; picks "Claim at the stand", "Always claimable"): the earn check
--   skips skins whose unlock has claim == "stand" (UniversalSkins 1.5: Zebra, Storm Front) while script attribute
--   SkinStandClaimsEnabled ~= false (read per check; false = 1.6, they unlock by themselves again). Skins already owned stay owned.
--   New server-only BindableFunction SkinGrant (child of this script): Invoke(player, id, reason) -> "ok" / "owned" / "unknown" /
--   "notLoaded" / "failed" / "disabled" (universal skins off): writes owned[id] in the same UpdateAsync as the earn check, then
--   SkinUnlocked / SkinUnlockedAt and SkinServerResult "earned". Diagnostic: script SkinQuestGrants.]=====]},
{[=====[		if sk.unlock.kind == "earn" and st.owned[id] ~= true and US.unlocked(id, stats) then table.insert(new, id) end]=====], [=====[		if sk.unlock.kind == "earn" and st.owned[id] ~= true and US.unlocked(id, stats)
			and not (sk.unlock.claim == "stand" and script:GetAttribute("SkinStandClaimsEnabled") ~= false) then -- v1.7
			table.insert(new, id)
		end]=====]},
{[=====[	Players.PlayerAdded:Connect(watch)
	for _, p in ipairs(Players:GetPlayers()) do watch(p) end
end
]=====], [=====[	Players.PlayerAdded:Connect(watch)
	for _, p in ipairs(Players:GetPlayers()) do watch(p) end
end
-- v1.7: SkinGrant for the Quest Stand (see the v1.7 note)
if script:GetAttribute("SkinStandClaimsEnabled") == nil then script:SetAttribute("SkinStandClaimsEnabled", true) end
do
	local grantFn = script:FindFirstChild("SkinGrant") or Instance.new("BindableFunction")
	grantFn.Name = "SkinGrant"
	grantFn.Parent = script
	grantFn.OnInvoke = function(player, id, reason)
		if not uni then return "disabled" end
		if typeof(player) ~= "Instance" or not player:IsA("Player") or type(id) ~= "string" or not US.get(id) then return "unknown" end
		local st = states[player]
		if not (st and st.loaded and store) then return "notLoaded" end
		if st.owned[id] == true then return "owned" end
		local ok, value = pcall(function()
			return store:UpdateAsync("u" .. player.UserId, function(old)
				local v = blank(old)
				v.owned[id] = true
				return v
			end)
		end)
		if not (ok and player.Parent) then return "failed" end
		takeValue(st, value)
		st.owned[id] = true
		script:SetAttribute("SkinQuestGrants", (script:GetAttribute("SkinQuestGrants") or 0) + 1)
		publish(player)
		player:SetAttribute("SkinUnlocked", id)
		player:SetAttribute("SkinUnlockedAt", workspace:GetServerTimeNow())
		setResult(player, "earned")
		return "ok"
	end
end
]=====]},
}
local s = sc.Source
for k, pr in ipairs(PAIRS) do
	local a, b = string.find(s, pr[1], 1, true)
	assert(a, "miss " .. k)
	assert(not string.find(s, pr[1], b + 1, true), "dup " .. k)
	s = s:sub(1, a - 1) .. pr[2] .. s:sub(b + 1)
end
local m = Instance.new("ModuleScript")
m.Source = "return function()\n" .. s .. "\nend"
m.Parent = workspace
local okC, errC = pcall(require, m)
m:Destroy()
if not okC then return "COMPILE FAIL " .. tostring(errC) end
sc.Source = s
local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
return #s .. " " .. h
