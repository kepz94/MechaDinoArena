-- HeadbuttPose v1.0 (Mecha Dino Arena) — the pachy's headbutt charge pose (HeadbuttTest 1.0 / HeadbuttServer 1.0), as
-- per-joint offsets multiplied onto the current pose (IdleAnimation 1.29). MDA-119, plan docs/plans/PACHY_PLAYABLE_v1.0.md
-- Task 8 (Kepu 2026-10-30: "animations that indicate a speed up and the charge. the pachy should dip its head forward
-- with intent like the inspo pick that i sent where its charging"; inspo docs/reference/pachy/).
-- Joint frames are world-aligned at build time: rotation about Z = pitch (positive lifts the front), about Y = yaw,
-- about X = roll; tail positive pitch = lower (PouncePose convention).
-- Phases (attributes below):
--   windup  0 .. HeadbuttWindup  quick rear-up of the head (first 40%), then it drops: the "about to charge" tell
--   charge  until the end        body low in front, neck down and forward, head tucked so the dome leads, arms tucked,
--                                tail straight out behind (counters the tail sag), a fast small head bob (the speed-up)
--   impact  hit .. +IMPACT       the dome snaps up and back from the hit and shakes, then eases out
--   fade    end .. +FADE         eases out after a charge that missed
-- phase(model, isOwner, serverNow): owner client = HeadbuttLocalState / HeadbuttPredictedAt / HeadbuttLocalEndAt
--   (HeadbuttTest 1.0); other clients = server stamps HeadbuttStartedAt, HeadbuttHitAt, HeadbuttEndedAt.
--   Returns phase ("windup" / "charge" / "impact" / "fade" / nil), u (0..1 inside the phase), source ("local" / "server").

local HeadbuttPose = {}

HeadbuttPose.Version = "1.0"
HeadbuttPose.Defaults = {
	HeadbuttEnabled = false, -- PachyModelData 1.1 sets true
	HeadbuttWindup  = 0.15,
	HeadbuttMaxTime = 1.8,
	HeadbuttPoseEnabled = true, -- switch: false = no headbutt pose (IdleAnimation 1.28 look)
}
HeadbuttPose.IMPACT = 0.3 -- = HeadbuttTest 1.0 RECOVER, so the owner's impact ends with its recover state
HeadbuttPose.FADE = 0.25

local rad, sin, pi = math.rad, math.sin, math.pi
local function smoothstep(x) x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end

function HeadbuttPose.settings(model)
	local s = {}
	for k, v in pairs(HeadbuttPose.Defaults) do
		local a = model:GetAttribute(k)
		if a == nil then a = v end
		s[k] = a
	end
	return s
end

function HeadbuttPose.phase(model, isOwner, serverNow)
	local s = HeadbuttPose.settings(model)
	if s.HeadbuttEnabled ~= true or s.HeadbuttPoseEnabled == false then return nil, 0, "none" end
	local W = math.max(0.01, tonumber(s.HeadbuttWindup) or 0.15)
	if isOwner then
		local st = model:GetAttribute("HeadbuttLocalState")
		local pStart = model:GetAttribute("HeadbuttPredictedAt")
		local endAt = model:GetAttribute("HeadbuttLocalEndAt")
		if st == "windup" and typeof(pStart) == "number" then
			return "windup", math.clamp((serverNow - pStart) / W, 0, 1), "local"
		elseif st == "charge" then
			return "charge", 0, "local"
		elseif st == "recover" and typeof(endAt) == "number" then
			return "impact", math.clamp((serverNow - endAt) / HeadbuttPose.IMPACT, 0, 1), "local"
		elseif typeof(endAt) == "number" and typeof(pStart) == "number" and endAt >= pStart
			and serverNow - endAt < HeadbuttPose.FADE then
			return "fade", (serverNow - endAt) / HeadbuttPose.FADE, "local"
		end
		return nil, 0, "local"
	end
	local start = model:GetAttribute("HeadbuttStartedAt")
	if typeof(start) ~= "number" then return nil, 0, "server" end
	local hitAt = model:GetAttribute("HeadbuttHitAt")
	local endAt = model:GetAttribute("HeadbuttEndedAt")
	if typeof(hitAt) == "number" and hitAt >= start - 0.001 then
		if serverNow - hitAt < HeadbuttPose.IMPACT then
			return "impact", math.clamp((serverNow - hitAt) / HeadbuttPose.IMPACT, 0, 1), "server"
		end
		return nil, 0, "server"
	end
	if typeof(endAt) == "number" and endAt >= start - 0.001 then
		if serverNow - endAt < HeadbuttPose.FADE then return "fade", (serverNow - endAt) / HeadbuttPose.FADE, "server" end
		return nil, 0, "server"
	end
	local t = serverNow - start
	if t >= 0 and t < W then return "windup", t / W, "server" end
	if t >= W and t < W + (tonumber(s.HeadbuttMaxTime) or 1.8) + 1 then return "charge", 0, "server" end
	return nil, 0, "server"
end

-- phase / u from HeadbuttPose.phase; k: overall weight 0..1; now: clock seconds
function HeadbuttPose.get(phase, u, k, now)
	local out = {}
	local rear = (phase == "windup" and u < 0.4) and sin(pi * u / 0.4) or 0
	local w = phase == "windup" and smoothstep((u - 0.3) / 0.7) or 0
	local c = phase == "charge" and 1 or 0
	local hit = phase == "impact" and (1 - smoothstep(u)) or 0
	local fade = phase == "fade" and (1 - smoothstep(u)) or 0
	local low = math.max(w, c, fade, hit * 0.5)
	local bob = c * sin(now * 2 * pi * 4.5)
	local shake = rad(9 * hit * sin(now * 2 * pi * 10))
	out.RootJoint = CFrame.Angles(0, 0, rad((-8 * low + 5 * rear + 3 * hit) * k))
	out.Neck = CFrame.Angles(0, shake * 0.5, rad((-26 * low + 12 * rear + 22 * hit + 2.5 * bob) * k))
	out.Head = CFrame.Angles(shake * 0.4, shake, rad((-38 * low + 8 * rear + 20 * hit) * k))
	out.Jaw = CFrame.Angles(0, 0, 0)
	out.ArmL = CFrame.Angles(0, 0, rad(-35 * low * k))
	out.ArmR = CFrame.Angles(0, 0, rad(-35 * low * k))
	-- tail straight out behind: the body's -8 pitch already raises it, so Tail1 lowers it back near level (Studio
	-- capture: -10 / -6 / -4 / -3 lifted it about 30 degrees)
	out.Tail1 = CFrame.Angles(0, 0, rad(6 * low * k))
	return out
end

return HeadbuttPose
