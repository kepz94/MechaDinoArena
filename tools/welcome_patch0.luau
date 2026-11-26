-- welcome_patch0 (WELCOME_MOVES v1.0 Task 1, MDA-593): TutorialRules 1.3 passives + JUMP parts. Pairs on TutorialRules.
local PAIRS = {
{[=====[local M = {}
M.Version = "1.0"]=====], [=====[-- v1.3 (plan docs/plans/WELCOME_MOVES_v1.0.md Task 1, MDA-593, mockup docs/mockups/welcome_moves_v0.2.html; Kepu 2026-11-26
--   02:10 "Just have the climbing ability in the description of the Dino attack ability as a passive", "for mecha parts that's
--   just a different mechanic to use it"; "Build" 02:36):
--   PASSIVES[dino] = list of {n = name, tag = "PASSIVE" | "ON JUMP", line} = a dino's built-in move that is not a button
--   (Herrera climbing: ClimbLogic 1.1 + SlashServer "dive"; Therizino Spin Dive and Troodon Flap & Glide on JUMP, their
--   ModelData). passivesFor(dino) -> a copy of PASSIVES[dino], {} for nil / unknown.
--   JUMP_PARTS[id] = {stamp, needAttr?, big, pcBig, small, tip}: mecha parts that fire through JUMP, not their slot button
--   (MechaButtons: Glider Wings has no key, Mecha Legs / Hydraulic Leap presses do nothing). stamp = the character attribute
--   written when the move really happens (HerreraMovesServer GlideStartedAt, JumpServer 1.2 JumpDoubleAt, JumpServer
--   JumpStartedAt); needAttr = a character attribute that must be true at that moment (TenoLeapOnJump: the jump is the
--   hydraulic leap). jumpPart(id) -> the entry or nil. jumpPartEvent(entry, attrName, needValue) -> true when attrName is
--   entry.stamp and (no needAttr or needValue == true).
local M = {}
M.Version = "1.0"]=====]},
{[=====[M.Version = "1.2" -- v1.2 a lesson needs the attack to land on the bot]=====], [=====[M.Version = "1.2" -- v1.2 a lesson needs the attack to land on the bot
M.Version = "1.3" -- v1.3 passives + JUMP parts]=====]},
{[=====[	end
	return table.concat(out, ",")
end

return M]=====], [=====[	end
	return table.concat(out, ",")
end

-- v1.3: passives + JUMP parts (see the header)
M.PASSIVES = {
	Herrera = {{n = "Tree Climber", tag = "PASSIVE", line = "Walk into a tree to climb it. SLASH from a tree drops onto the dino below."}},
	Therizino = {{n = "Spin Dive", tag = "ON JUMP", line = "JUMP spins you forward. 3 charges."}},
	Troodon = {{n = "Flap & Glide", tag = "ON JUMP", line = "JUMP, then JUMP twice more in the air. Then it glides."}},
}
function M.passivesFor(dino)
	local out = {}
	for _, P in ipairs(M.PASSIVES[dino or ""] or {}) do table.insert(out, P) end
	return out
end
M.JUMP_PARTS = {
	glider = {stamp = "GlideStartedAt", big = "JUMP, THEN HOLD JUMP", pcBig = "SPACE, THEN HOLD SPACE", small = "Glider Wings",
		tip = "Glider Wings works on JUMP. Jump, then hold JUMP in the air."},
	mechalegs = {stamp = "JumpDoubleAt", big = "JUMP, THEN JUMP AGAIN", pcBig = "SPACE, THEN SPACE AGAIN", small = "Mecha Legs",
		tip = "Mecha Legs works on JUMP. Leap, then JUMP again in the air."},
	tleap = {stamp = "JumpStartedAt", needAttr = "TenoLeapOnJump", big = "TAP JUMP", pcBig = "PRESS SPACE", small = "Hydraulic Leap",
		tip = "Hydraulic Leap works on JUMP. Every jump is the leap."},
}
function M.jumpPart(id)
	return id and M.JUMP_PARTS[id] or nil
end
function M.jumpPartEvent(entry, attrName, needValue)
	if type(entry) ~= "table" or attrName ~= entry.stamp then return false end
	return entry.needAttr == nil or needValue == true
end

return M]=====]},
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
