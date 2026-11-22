-- TutorialRules v1.0 (Mecha Dino Arena) — pure rules for the first-time flow. MDA-558, plan docs/plans/FIRST_TIME_FLOW_v1.0.md
-- Task 0, ADR-013, mockup docs/mockups/first_time_flow_v0.3.html (Kepu 2026-11-22: "A + B's cards", no skip, old players keep
-- all + TUTORIAL button; 10:46 red-team: roll 7 (no T-Rex), a saved lastSpecies also marks an old player).
-- Rojo: src/shared -> ServerStorage.DinoArcade.TutorialRules (TutorialServer clones it to ReplicatedStorage.TutorialShared).
-- classify(ownValue, readOk, skillState, hasLastSpecies, enabled, force) -> "off" | "new" | "done" | "resume" | "grand",
--   first matching row:
--     enabled ~= true                         -> "off"   (OwnershipEnabled false)
--     force == true                           -> "new"   (Studio test: Workspace TutorialTestForce)
--     readOk ~= true                          -> "off"   (ownership store read failed: never lock anyone out)
--     skillState not "loaded" / "new"         -> "off"   (SkillServer noApi / failed / off / loading)
--     ownValue table, tut.done == true        -> "done"
--     ownValue table                          -> "resume" (rolled, not finished)
--     skillState "loaded" or hasLastSpecies   -> "grand" (old player: owns all, never sees the flow)
--     otherwise                               -> "new"
-- rollPick(pool, r) -> pool[floor(r * #pool) + 1] (r clamped to [0, 1)), nil for an empty pool.
-- startStep(state, replay) -> 3 for a replay or "resume", 1 for "new", else nil.
-- laneCFrame(origin, lane, spacing) -> origin * CFrame.new((lane - 1) * spacing, 0, 0).
-- ownedString(set) -> the owned keys in ALL_DINOS order, comma-separated. allOwned() -> every key of ALL_DINOS.
local M = {}
M.Version = "1.0"

M.ALL_DINOS = {"Raptor", "TRex", "Pachy", "Herrera", "Teno", "Therizino", "Dilo", "Troodon"}
M.ROLL_POOL = {"Raptor", "Pachy", "Herrera", "Teno", "Therizino", "Dilo", "Troodon"} -- Kepu 10:46 "No, roll 7"
M.STEPS = {"Welcome", "Roll", "Parts", "Hit the bot", "Equip 4 parts", "Use each part", "Defeat the bot", "Spend your point",
	"Skill points", "Island"}

function M.classify(ownValue, readOk, skillState, hasLastSpecies, enabled, force)
	if enabled ~= true then return "off" end
	if force == true then return "new" end
	if readOk ~= true then return "off" end
	if skillState ~= "loaded" and skillState ~= "new" then return "off" end
	if type(ownValue) == "table" then
		if type(ownValue.tut) == "table" and ownValue.tut.done == true then return "done" end
		return "resume"
	end
	if skillState == "loaded" or hasLastSpecies == true then return "grand" end
	return "new"
end

function M.rollPick(pool, r)
	if type(pool) ~= "table" or #pool == 0 then return nil end
	r = math.clamp(tonumber(r) or 0, 0, 0.999999)
	return pool[math.floor(r * #pool) + 1]
end

function M.startStep(state, replay)
	if replay == true or state == "resume" then return 3 end
	if state == "new" then return 1 end
	return nil
end

function M.laneCFrame(origin, lane, spacing)
	return origin * CFrame.new((lane - 1) * spacing, 0, 0)
end

function M.allOwned()
	local t = {}
	for _, k in ipairs(M.ALL_DINOS) do t[k] = true end
	return t
end

function M.ownedString(set)
	local out = {}
	for _, k in ipairs(M.ALL_DINOS) do
		if type(set) == "table" and set[k] then table.insert(out, k) end
	end
	return table.concat(out, ",")
end

return M
