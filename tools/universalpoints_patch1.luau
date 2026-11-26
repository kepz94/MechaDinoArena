-- universalpoints_patch1 (SkillServer 1.15): UNIVERSAL_POINTS_v1.0 Task 2.
local PAIRS = {
{[=====[VERSION = "1.14" -- v1.14 fresh save store (account reset)]=====], [=====[VERSION = "1.14" -- v1.14 fresh save store (account reset)
VERSION = "1.15" -- v1.15 universal skill points + bonus points
-- v1.15 (universal points, plan docs/plans/UNIVERSAL_POINTS_v1.0.md Task 2; Kepu 2026-11-26 "Make all points universal", "the daily
--   quest rewards will be skill points"; picks "Full pool on every dino", "Highest dino's XP", "Yes, past 40"; red-team "Accept",
--   "Yes, that's the point", "No cap"). While script attribute SkillUniversalEnabled ~= false (read at each player's load, d.universal):
--   * One account XP (so one level) for every dino: it lives in d.xp and is NOT swapped when the dino changes (switchTo keeps it;
--     stash still writes it into the record). Kill XP and SkillGrantXp raise it, so every dino levels together.
--   * Load: account XP = SkillPool.accountXp(value) = max(value.uxp, every dino record's xp) (the migration from 1.14 saves;
--     nobody goes down); bonus = SkillPool.cleanBonus(value.bonus, SkillBonusMax). A record's build-over-points reset uses the
--     account points instead of the record's own level points.
--   * Points: SkillPoints = pointsOf(account level) + bonus (SkillPool.earned); each dino spends from the full pool on its own
--     build (builds, loadouts, saved loadouts stay per dino); buys use the same number. Bonus can go past 40 (no cap unless
--     script attribute SkillBonusMax is set). Mastery 3 unchanged.
--   * Save: top-level uxp (account XP) and bonus are added to the value; v stays 2, so 1.14 still reads it. With the switch off,
--     the loaded uxp / bonus are written back untouched (nothing is lost).
--   * Server-only BindableFunction SkillGrantPoints (child of this script): Invoke(player, amount, reason) -> "ok", before, after
--     (bonus totals) | "disabled" (SkillEnabled / SkillGrantPointsEnabled false or universal off for the player) | "notLoaded" |
--     "badArg" (not a Player, amount not a whole number 1..100). For the Quest Stand (roadmap piece 4).
--   Player attributes: SkillBonusPoints, SkillUniversal ("on" / "off"), SkillAccountFrom ("new" / "max of N dinos" / "uxp of N
--   dinos"), SkillLastPoints ("quest +3"). Script attributes: SkillUniversalEnabled (true), SkillGrantPointsEnabled (true),
--   SkillBonusMax (unset = no cap), SkillPointGrants (count). Switch off = 1.14 (per-dino XP; bonus ignored but kept in the save).]=====]},
{[=====[local ST = require(treeModule)
]=====], [=====[local ST = require(treeModule)
local SkillPool = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("SkillPool")) -- v1.15
if script:GetAttribute("SkillUniversalEnabled") == nil then script:SetAttribute("SkillUniversalEnabled", true) end -- v1.15
if script:GetAttribute("SkillGrantPointsEnabled") == nil then script:SetAttribute("SkillGrantPointsEnabled", true) end -- v1.15
local function bonusMax() local m = script:GetAttribute("SkillBonusMax") return type(m) == "number" and m or nil end -- v1.15
local function earnedOf(d) -- v1.15: account level points + bonus when universal, else 1.14
	if d.universal then return SkillPool.earned(d.xp, d.bonus, ST, bonusMax()) end
	return ST.pointsOf((ST.levelOf(d.xp)))
end
]=====]},
{[=====[local earned = ST.pointsOf(level)]=====], [=====[local earned = earnedOf(d) -- v1.15 (1.14: ST.pointsOf(level))]=====]},
{[=====[player:SetAttribute("SkillLeft", earned - spent)
]=====], [=====[player:SetAttribute("SkillLeft", earned - spent)
	player:SetAttribute("SkillBonusPoints", d.universal and SkillPool.cleanBonus(d.bonus, bonusMax()) or 0) -- v1.15
	player:SetAttribute("SkillUniversal", d.universal and "on" or "off") -- v1.15
]=====]},
{[=====[local earned = ST.pointsOf((ST.levelOf(d.xp)))]=====], [=====[local earned = earnedOf(d) -- v1.15 (1.14: ST.pointsOf((ST.levelOf(d.xp))))]=====]},
{[=====[	if d.active == key then return end
	stash(d)
]=====], [=====[	if d.active == key then return end
	if d.universal and d.active then d.uxp = d.xp end -- v1.15: the account XP so far
	stash(d)
]=====]},
{[=====[d.xp, d.steps, d.loadout = r.xp, r.steps, r.loadout
]=====], [=====[d.xp, d.steps, d.loadout = r.xp, r.steps, r.loadout
	if d.universal then d.xp = d.uxp or 0 end -- v1.15: one account XP, not the record's
]=====]},
{[=====[local function cleanRecord(raw, key)]=====], [=====[local function cleanRecord(raw, key, cap) -- v1.15: + cap (account points when universal)]=====]},
{[=====[if ST.spent(steps, key) > ST.pointsOf((ST.levelOf(xp))) then]=====], [=====[if ST.spent(steps, key) > (cap or ST.pointsOf((ST.levelOf(xp)))) then]=====]},
{[=====[	d.saved = {} -- v1.12
]=====], [=====[	d.saved = {} -- v1.12
	d.universal = script:GetAttribute("SkillUniversalEnabled") ~= false -- v1.15
	d.uxp, d.bonus = 0, 0
	player:SetAttribute("SkillAccountFrom", "new")
]=====]},
{[=====[elseif type(value) == "table" and value.v == 2 and type(value.dinos) == "table" then -- v1.2: per-dino records
]=====], [=====[elseif type(value) == "table" and value.v == 2 and type(value.dinos) == "table" then -- v1.2: per-dino records
			d.rawUxp, d.rawBonus = value.uxp, value.bonus -- v1.15: written back as they are while universal is off
			local cap -- v1.15: the account points every record is checked against
			if d.universal then
				d.uxp, d.bonus = SkillPool.accountXp(value), SkillPool.cleanBonus(value.bonus, bonusMax())
				cap = SkillPool.earned(d.uxp, d.bonus, ST, bonusMax())
				local n = 0 for _ in pairs(value.dinos) do n += 1 end
				player:SetAttribute("SkillAccountFrom", (type(value.uxp) == "number" and "uxp" or "max") .. " of " .. n .. " dinos")
			end
]=====]},
{[=====[d.dinos[key] = cleanRecord(raw, key)]=====], [=====[d.dinos[key] = cleanRecord(raw, key, cap)]=====]},
{[=====[	if type(d.saved) == "table" then -- v1.12]=====], [=====[	if d.universal then value.uxp, value.bonus = d.xp, d.bonus -- v1.15
	else value.uxp, value.bonus = d.rawUxp, d.rawBonus end
	if type(d.saved) == "table" then -- v1.12]=====]},
{[=====[	return "ok", {level = l1, into = i1, next = n1}, {level = l2, into = i2, next = n2}
end]=====], [=====[	return "ok", {level = l1, into = i1, next = n1}, {level = l2, into = i2, next = n2}
end

-- ---------- v1.15: bonus skill points grant (see the v1.15 note) ----------
script:SetAttribute("SkillPointGrants", script:GetAttribute("SkillPointGrants") or 0)
local pointsFn = script:FindFirstChild("SkillGrantPoints")
if not pointsFn then
	pointsFn = Instance.new("BindableFunction")
	pointsFn.Name = "SkillGrantPoints"
	pointsFn.Parent = script
end
pointsFn.OnInvoke = function(player, amount, reason)
	if script:GetAttribute("SkillEnabled") == false or script:GetAttribute("SkillGrantPointsEnabled") == false then return "disabled" end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or not SkillPool.grantOk(amount) then return "badArg" end
	local d = data[player]
	if not d or not d.loaded then return "notLoaded" end
	if not d.universal then return "disabled" end
	local before = SkillPool.cleanBonus(d.bonus, bonusMax())
	d.bonus = SkillPool.cleanBonus(before + amount, bonusMax())
	d.dirty = true
	publish(player, d, false)
	player:SetAttribute("SkillLastPoints", tostring(reason or "points") .. " +" .. amount)
	script:SetAttribute("SkillPointGrants", (script:GetAttribute("SkillPointGrants") or 0) + 1)
	return "ok", before, d.bonus
end]=====]},
}
local s = sc.Source
for k, pr in ipairs(PAIRS) do
	local a, b = string.find(s, pr[1], 1, true)
	assert(a, "miss " .. k .. ": " .. pr[1]:sub(1, 60))
	assert(not string.find(s, pr[1], b + 1, true), "dup " .. k)
	s = s:sub(1, a - 1) .. pr[2] .. s:sub(b + 1)
end
sc.Source = s
local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
return #s .. " " .. h
