"""Unlock-only v1.0 Task 2 (MDA-614): SkillServer 1.19. Run: python3 -I tools/launch_patch.py <outdir> <this file>"""
SSS = 'game:GetService("ServerScriptService").'
JOBS = {}
P = []
a = 'VERSION = "1.18" -- v1.18 every stat row maxed for everyone\n'
P.append((a, a + '''VERSION = "1.19" -- v1.19 unlock-only progression
-- v1.19 (unlock-only progression, MDA-614, plan docs/plans/UNLOCK_ONLY_v1.0.md Task 2, ADR-016; Kepu 2026-11-27 19:31 "take out the
--   upgrade and stat system entirely so that people are just unlocking Dino's and mecha parts. Not upgrading the mecha parts"; picks
--   "Base numbers", "Level 1", "Flat 10 points each", "Dino + all its parts", "One shared wallet", "Stay unlocked, free"; 19:43
--   "Build"). While script attribute SkillUnlockOnlyEnabled ~= false (default true, read at each use; a change republishes nobody
--   by itself, the next publish shows it):
--   * Effective steps (stepsFor) = SkillTree.unlockSteps(saved steps, dino, given): every live mecha part the dino owns (saved step
--     >= 1, or given: the free dino, MaxedDinos, the test layer) at 1, every stat row at 0 (the dino's base numbers). The saved
--     steps are never rewritten (load's mastery clamp and over-pool reset are skipped), so the switch off brings 1.18 back.
--   * No stat rows are given (testStats returns none); player SkillAllStatsMax stays true so the Lab keeps the STATS tab hidden.
--   * Wallet: one account pool. SkillLeft = earnedOf (level points + bonus - dino unlocks) - pspend (points spent on part unlocks,
--     saved as value.pspend, a whole number >= 0); SkillSpent = SkillPartSpent = pspend.
--   * SkillRequest("buy", id): "notPart" (not a live part of the active dino), "owned" (effective step 1), "noPoints" (SkillLeft
--     < script attribute SkillPartPrice, default SkillTree.PART_PRICE 10), else the saved step becomes 1 (at least), pspend +=
--     price, autoSlot as 1.1, SkillLastPoints "part -10", result "ok".
--   * SkillRequest("respec") -> "disabled" (no refunds). SkillSpendUnlock (dino unlock): checked against SkillLeft; no build reset.
--   * Player attributes: SkillUnlockOnly (true / false), SkillPartPrice, SkillPartSpent, SkillKitOwned / SkillKitTotal (live
--     parts of the active dino owned / all).
--   false = 1.18 exactly (pspend kept in the save, ignored).
'''))
a = 'local function testStats(d)\n\tlocal out = {}\n'
P.append((a, '''if script:GetAttribute("SkillUnlockOnlyEnabled") == nil then script:SetAttribute("SkillUnlockOnlyEnabled", true) end -- v1.19
if script:GetAttribute("SkillPartPrice") == nil then script:SetAttribute("SkillPartPrice", ST.PART_PRICE or 10) end -- v1.19
local function unlockOnly() return script:GetAttribute("SkillUnlockOnlyEnabled") ~= false and ST.unlockSteps ~= nil end -- v1.19
local function partPrice() return math.max(0, math.floor(tonumber(script:GetAttribute("SkillPartPrice")) or ST.PART_PRICE or 10)) end
''' + a + '\tif unlockOnly() then return out end -- v1.19: no stat rows given\n'))
a = 'local function stepsFor(d) -- v1.5: real steps, plus the test parts at star while the layer is on (v1.6: all live parts)\n'
P.append((a, a + '''	if unlockOnly() then -- v1.19: owned / given parts at 1, stat rows at 0
		local given = {}
		for _, id in ipairs(testParts(d)) do given[id] = true end
		return ST.unlockSteps(d.steps, d.active, given)
	end
'''))
a = '	player:SetAttribute("SkillAllStatsMax", script:GetAttribute("SkillAllStatsMaxEnabled") ~= false) -- v1.18\n'
P.append((a, '	player:SetAttribute("SkillAllStatsMax", script:GetAttribute("SkillAllStatsMaxEnabled") ~= false or unlockOnly()) -- v1.18; v1.19: + unlock-only (STATS tab hidden)\n'
	'	player:SetAttribute("SkillUnlockOnly", unlockOnly()) -- v1.19\n	player:SetAttribute("SkillPartPrice", partPrice()) -- v1.19\n'))
a = '	player:SetAttribute("SkillLeft", earned - spent)\n'
P.append((a, a + '''	if unlockOnly() then -- v1.19: the shared wallet
		player:SetAttribute("SkillSpent", d.pspend or 0)
		player:SetAttribute("SkillLeft", math.max(0, earned - (d.pspend or 0)))
	end
	player:SetAttribute("SkillPartSpent", d.pspend or 0) -- v1.19
'''))
a = '	local eff = stepsFor(d) -- v1.5 (1.4: cloak 4 here only)\n'
P.append((a, a + '''	do -- v1.19: kit counts for the active dino
		local own, total = 0, 0
		if d.active and ST.isPart then
			for _, id in ipairs(ST.PATH_ORDER) do
				if ST.isPart(id, d.active) then total += 1 if (eff[id] or 0) >= 1 then own += 1 end end
			end
		end
		player:SetAttribute("SkillKitOwned", own)
		player:SetAttribute("SkillKitTotal", total)
	end
'''))
a = '\tif not ST.masteryOk(steps, key) then -- v1.3: over Mastery 3 -> every line back to step II\n'
P.append((a, '\tif not unlockOnly() and not ST.masteryOk(steps, key) then -- v1.3: over Mastery 3 -> every line back to step II (v1.19: not in unlock-only)\n'))
a = '\tif ST.spent(noStats(steps, key), key) > (cap or ST.pointsOf((ST.levelOf(xp)))) then steps = ST.sanitize({}, key) end -- v1.18: noStats\n'
P.append((a, '\tif not unlockOnly() and ST.spent(noStats(steps, key), key) > (cap or ST.pointsOf((ST.levelOf(xp)))) then steps = ST.sanitize({}, key) end -- v1.18: noStats; v1.19: kept in unlock-only\n'))
a = '\tvalue.unlock = d.unlock or 0 -- v1.17\n'
P.append((a, a + '\tvalue.pspend = d.pspend or 0 -- v1.19\n'))
a = '\td.unlock = 0 -- v1.17\n'
P.append((a, a + '\td.pspend = 0 -- v1.19\n'))
a = '\t\t\td.unlock = math.max(0, math.floor(tonumber(value.unlock) or 0)) -- v1.17\n'
P.append((a, a + '\t\t\td.pspend = math.max(0, math.floor(tonumber(value.pspend) or 0)) -- v1.19\n'))
a = '\tif action == "buy" and type(pathId) == "string" then\n'
P.append((a, '''	if action == "buy" and type(pathId) == "string" and unlockOnly() then -- v1.19: unlock a part
		local why
		local eff = stepsFor(d)
		local price = partPrice()
		if not ST.isPart(pathId, d.active) then
			why = "notPart"
		elseif (eff[pathId] or 0) >= 1 then
			why = "owned"
		elseif math.max(0, earnedOf(d) - (d.pspend or 0)) < price then
			why = "noPoints"
		else
			d.steps = ST.sanitize(d.steps, d.active)
			d.steps[pathId] = math.max(1, d.steps[pathId] or 0)
			d.pspend = (d.pspend or 0) + price
			if script:GetAttribute("SkillLoadoutEnabled") ~= false then d.loadout = ST.autoSlot(d.loadout, stepsFor(d), pathId, d.active) end
			d.dirty = true
			publish(player, d, false)
			player:SetAttribute("SkillLastPoints", "part -" .. price)
			why = "ok"
		end
		player:SetAttribute("SkillLastResult", why)
	elseif action == "buy" and type(pathId) == "string" then
'''))
a = '\telseif action == "respec" then\n'
P.append((a, '\telseif action == "respec" and unlockOnly() then -- v1.19: no refunds\n\t\tplayer:SetAttribute("SkillLastResult", "disabled")\n' + a))
a = '\tlocal before = earnedOf(d)\n\tif before < amount then return "notEnough", before end\n'
P.append((a, '\tlocal before = earnedOf(d)\n\tif unlockOnly() then before = math.max(0, before - (d.pspend or 0)) end -- v1.19: the shared wallet\n\tif before < amount then return "notEnough", before end\n'))
a = '\tif d.active and ST.spent((buyBase(d)), d.active) > cap then -- the active build, as a respec (v1.18: given rows left out)\n'
P.append((a, '\tif not unlockOnly() and d.active and ST.spent((buyBase(d)), d.active) > cap then -- the active build, as a respec (v1.18: given rows left out; v1.19: not in unlock-only)\n'))
a = '\t\tif key ~= d.active and type(r) == "table" and ST.spent(noStats(r.steps or {}, key), key) > cap then -- v1.18: noStats\n'
P.append((a, '\t\tif not unlockOnly() and key ~= d.active and type(r) == "table" and ST.spent(noStats(r.steps or {}, key), key) > cap then -- v1.18: noStats; v1.19: not in unlock-only\n'))
JOBS["SkillServer"] = ("src/server/SkillServer.server.luau", SSS + "SkillServer", P)
