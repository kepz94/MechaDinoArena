-- TrooPassives v1.0 (Mecha Dino Arena) — shared rule for the Troodon's Overheal Plume (ServerStorage.DinoArcade.TrooPassives).
-- MDA-349, plan docs/plans/TROODON_PARTS_v1.0.md ticket 5 (Kepu 2026-11-09 17:17 "Build all of them" + "Use the references we
-- chose from the previous mockups": Overheal Plume A "Tail Plume"). Used by TrooAttackServer 1.4 (zone / self heals) and
-- TrooMovesServer 1.6 (Mender Drone heals); the soak itself is TrooMovesServer 1.6's health watcher.
-- plumeAdd(healer, target, overflow, t, allowBot) -> plume added (number):
--   healer = the troodon whose heal it is; overflow = the part of the heal that did not fit under the target's max (> 0);
--   counts only while the healer's TrooPartPlumeEnabled is true (SkillEffects 1.52) and TrooPartPlumeMax > 0, and only when
--   target == healer, or target is a player squadmate of the healer (SquadRules.sameChar) and the healer's TrooPartPlumeSquad
--   (star) is true; allowBot = true also lets a bot target count (the Studio test ally only; callers pass it).
--   The target's plume = min(TrooPartPlumeMax of the healer, the running plume + overflow) (a plume past its TrooPlumeUntil
--   counts as 0); then target attributes TrooPlumeMax, TrooPlume (0.1 steps), TrooPlumeBy (healer name), TrooPlumeUntil = t +
--   the healer's TrooPartPlumeFade (5 / 7 s), and TrooPlumeAt = t (last; TrooPartsFX 1.3). A heal that adds nothing (the plume
--   already full) still refreshes TrooPlumeUntil.
-- Diagnostics: module field M.adds (count).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local M = {VERSION = "1.0", adds = 0}

local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local squadMod
local function squadmate(a, b)
	if not squadMod then
		local arc = ServerStorage:FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	return squadMod.sameChar(a, b) == true
end

function M.plumeAdd(healer, target, overflow, t, allowBot)
	if typeof(healer) ~= "Instance" or typeof(target) ~= "Instance" or typeof(overflow) ~= "number" or overflow <= 0 then return 0 end
	if healer:GetAttribute("TrooPartPlumeEnabled") ~= true then return 0 end
	local mx = math.max(0, num(healer, "TrooPartPlumeMax", 0))
	if mx <= 0 then return 0 end
	local isPlayer = Players:GetPlayerFromCharacter(target) ~= nil
	if target ~= healer then
		if healer:GetAttribute("TrooPartPlumeSquad") ~= true then return 0 end
		if not (isPlayer and squadmate(healer, target)) and not (allowBot == true and not isPlayer) then return 0 end
	elseif not isPlayer then
		return 0
	end
	local cur = num(target, "TrooPlumeUntil", 0) > t and num(target, "TrooPlume", 0) or 0
	local new = math.min(mx, cur + overflow)
	target:SetAttribute("TrooPlumeMax", mx)
	target:SetAttribute("TrooPlume", math.floor(new * 10 + 0.5) / 10)
	target:SetAttribute("TrooPlumeBy", healer.Name)
	target:SetAttribute("TrooPlumeUntil", t + math.max(0.5, num(healer, "TrooPartPlumeFade", 5)))
	target:SetAttribute("TrooPlumeAt", t) -- last: TrooPartsFX
	M.adds += 1
	return new - cur
end

return M
