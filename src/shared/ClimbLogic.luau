-- ClimbLogic v1.1 (Mecha Dino Arena) — the Herrerasaurus' auto-climb state machine (pure, no Instance access). MDA-137,
-- plan docs/plans/HERRERA_KIT_v1.0.md Task 5 (Kepu 2026-10-30: "climbing should just happen. If I walk up to a tree as a
-- herra it should automatically start climbing the tree vertically"; tree tops standable, Herrera only).
-- Used by ClimbTest 1.0 (owner client) every frame; ClimbServer 1.0 only stamps the reported state.
-- States: "ground" (anywhere off a trunk), "climbing" (on a trunk, moving), "clinging" (on a trunk, still), "top" (standing
--   on a tree-top proxy). The body is held on the trunk only in "climbing" / "clinging".
-- step(state, input, probe, s) -> nextState, out
--   input: {forward = bool (moving / pushing forward), back = bool (pushing backward), hop = bool (Space this frame)}
--   probe: {trunkAhead = studs to a trunk surface in front at body height or nil, topAbove = studs from the head to the
--           underside of a tree-top proxy above or nil, trunkEnds = true when there is no trunk above the head,
--           groundBelow = studs from the feet to the ground or nil (nothing below), onTop = standing on a proxy}
--   s: {grab = ClimbGrabDist, topGap = ClimbTopGap, speed = ClimbSpeed} (studs, studs, studs/s; already scaled)
--   out: {hold = bool (keep the body on the trunk), vy = vertical speed while held, hop = bool (push off backward),
--         mantle = bool (move onto the tree top now), reason = short string for diagnostics}
-- Rules (the plan's deterministic map):
--   ground / top + forward + trunkAhead <= grab                      -> climbing (grab), vy = +speed
--   top + hop                                                        -> ground, hop (off the tree top)
--   climbing / clinging + hop                                        -> ground, hop
--   climbing / clinging, trunk lost (trunkAhead nil or > grab x 2)    -> ground (let go)
--   climbing / clinging + forward + topAbove <= topGap               -> top, mantle
--   climbing / clinging + forward + trunkEnds                         -> top, mantle (v1.1; reason "trunkEnd")
--   climbing / clinging + forward                                     -> climbing, vy = +speed
--   climbing / clinging + back + groundBelow <= 0.5                   -> ground (slid down to the ground)
--   climbing / clinging + back                                        -> climbing, vy = -speed
--   climbing / clinging, no input                                     -> clinging, vy 0
--   ground / top otherwise                                            -> top if onTop, else ground
-- mantleTarget(proxies, trunkPos, bodyY) -> Vector3 or nil: the top face centre-above-the-trunk of the highest proxy
--   whose footprint contains the trunk (horizontal distance <= its reach) and whose top is above bodyY - 1.
--   proxies: array of {x, z, top, reach} (plain numbers).
-- treeTopTarget(proxies, bodyY) -> Vector3 or nil (v1.1): the climbed tree's own highest proxy whose top is above
--   bodyY - 1, at that proxy's x / z (no footprint test). The caller passes only that tree's proxies; used when
--   mantleTarget finds none over the trunk (a leaning palm's crown is off the trunk line).
-- v1.1 (MDA-145, Kepu 2026-10-31 live on a phone: stuck clinging under a palm crown): the plan's map says the mantle
--   happens when a tree-top proxy is within ClimbTopGap above the head "or the trunk ends". 1.0 clung at the trunk end
--   instead, so on a leaning palm (the vertical climb loses the trunk ~15 studs below the crown) forward did nothing
--   and the body stayed there. Now forward at the trunk end mantles; with no input it still clings.
local ClimbLogic = {}
ClimbLogic.Version = "1.1"

local function held(vy, reason) return {hold = true, vy = vy, hop = false, mantle = false, reason = reason} end
local function free(reason) return {hold = false, vy = 0, hop = false, mantle = false, reason = reason} end

function ClimbLogic.step(state, input, probe, s)
	input = input or {}
	probe = probe or {}
	local onTrunk = state == "climbing" or state == "clinging"
	if not onTrunk then
		if input.forward and probe.trunkAhead and probe.trunkAhead <= s.grab then
			return "climbing", held(s.speed, "grab")
		end
		if state == "top" and input.hop then
			local o = free("hopOffTop")
			o.hop = true
			return "ground", o
		end
		return probe.onTop and "top" or "ground", free(probe.onTop and "onTop" or "ground")
	end
	if input.hop then
		local o = free("hop")
		o.hop = true
		return "ground", o
	end
	if not probe.trunkAhead or probe.trunkAhead > s.grab * 2 then
		return "ground", free("lostTrunk")
	end
	if input.forward then
		if probe.topAbove and probe.topAbove <= s.topGap then
			local o = free("mantle")
			o.mantle = true
			return "top", o
		end
		if probe.trunkEnds then -- v1.1: the trunk ends -> onto the tree top (was: cling)
			local o = free("trunkEnd")
			o.mantle = true
			return "top", o
		end
		return "climbing", held(s.speed, "up")
	end
	if input.back then
		if probe.groundBelow and probe.groundBelow <= 0.5 then
			return "ground", free("slidDown")
		end
		return "climbing", held(-s.speed, "down")
	end
	return "clinging", held(0, "cling")
end

function ClimbLogic.mantleTarget(proxies, trunkPos, bodyY)
	local best
	for _, p in ipairs(proxies or {}) do
		local d = math.sqrt((p.x - trunkPos.X) ^ 2 + (p.z - trunkPos.Z) ^ 2)
		if d <= p.reach and p.top > bodyY - 1 and (not best or p.top > best.top) then best = p end
	end
	if not best then return nil end
	return Vector3.new(trunkPos.X, best.top, trunkPos.Z)
end

function ClimbLogic.treeTopTarget(proxies, bodyY) -- v1.1
	local best
	for _, p in ipairs(proxies or {}) do
		if p.top > bodyY - 1 and (not best or p.top > best.top) then best = p end
	end
	if not best then return nil end
	return Vector3.new(best.x, best.top, best.z)
end

return ClimbLogic
