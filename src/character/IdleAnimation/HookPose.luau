-- HookPose v1.3 (Mecha Dino Arena) — the pachy's Grappling Hook pose (HookServer 1.0), per-joint offsets multiplied onto
-- the current pose (IdleAnimation 1.30). MDA-122, plan docs/plans/PACHY_PARTS_v1.0.md Drop A Task 6 (Kepu 2026-10-30:
-- "something he lifts his arm to shoot" · "pull them in then the pachy would dip its head for a smash").
-- Joint frames are world-aligned at build time: rotation about Z = pitch (positive lifts the front).
-- Phases from the pachy's server stamps (same on every client): HookStartedAt, HookLaunchAt, HookContactAt,
--   HookSmashAt, HookResult, HookBusyUntil.
--   raise  start .. launch            right arm lifts forward (ArmR +ARM_UP), body leans back a touch
--   hold   launch .. smash (or end)   arm stays up while the claw flies and reels
--   smash  smash .. +SMASH            arm drops, the head dips hard for the smash and snaps back (then done)
--   lower  end .. +LOWER              after a miss: the arm eases down
-- phase(model, serverNow) -> phase or nil, u (0..1). get(phase, u, k, model) -> offsets.
-- v1.1 (Kepu 2026-10-30: "it shoots at the ground because the dino arm doesnt lift straight"): the arm lift is ARM_LEVEL
--   degrees (Studio measure: the pachy forearm rests ~58 deg below level; +75 left it ~20 deg above) plus the shot's pitch
--   (HookAimDir, HookServer 1.2 keeps it within -2 .. +25 deg), so the raised forearm points straight along the shot.
--   Model attribute HookArmLevel overrides ARM_LEVEL (tuning).
-- v1.2 (Kepu: the hook goes on the dino's right arm; HookServer 1.4): the lifted joint is the model attribute HookArmSeg
--   ("ArmL" = the pachy's real right arm; HookServer stamps it), "ArmR" when the attribute is missing (= 1.1). Both arm
--   joints have the same frame (rotation about Z lifts the front), so the lift is the same.
-- v1.3 (MDA-306, plan docs/plans/PACHY_MOVES_ANIM_v1.0.md Task 4; Kepu 2026-11-05 23:34 "A for everything": "A · Brace &
--   Reel"; mockup docs/mockups/pachy_moves_anim.html v0.1 keys H_BRACE / H_KICK / H_REEL / H_COCK / H_SMASH): model switch
--   HookBraceEnabled (default true, read every frame). Same stamps and timing; the arm keeps ARM_LEVEL + the aim pitch.
--   start -> launch: plants the feet wide, the hook arm comes up (BRACE); launch -> +0.05 s: the arm kicks (KICK), then back
--   to BRACE; hit: from HookContactAt three tugs (REEL / BRACE every 0.06-0.08 s), REEL held, HookSmashAt - 0.12: the head
--   cocks back (COCK), smash: SMASH in 0.06 s held to +0.3 s, back to rest by +0.7 s (SMASH_BRACE); miss: BRACE held to
--   HookBusyUntil, then lowered in LOWER.

local HookPose = {}
HookPose.Version = "1.2"
HookPose.Version = "1.3" -- v1.3 Brace & Reel
HookPose.SMASH_BRACE = 0.7 -- v1.3
local function braceOn(model) return model ~= nil and model:GetAttribute("HookBraceEnabled") ~= false end
HookPose.ARM_UP = 75 -- 1.0 (kept for reference)
HookPose.ARM_LEVEL = 56 -- v1.1
HookPose.SMASH = 0.3
HookPose.LOWER = 0.25

local rad, sin, pi = math.rad, math.sin, math.pi
local function smoothstep(x) x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end

function HookPose.phase(model, t)
	if model:GetAttribute("HookPoseEnabled") == false then return nil, 0 end
	local s = tonumber(model:GetAttribute("HookStartedAt"))
	if not s or t < s then return nil, 0 end
	local launch = tonumber(model:GetAttribute("HookLaunchAt")) or s
	local smash = tonumber(model:GetAttribute("HookSmashAt")) or 0
	local busy = tonumber(model:GetAttribute("HookBusyUntil")) or launch
	if t < launch then return "raise", (t - s) / math.max(0.01, launch - s) end
	if smash > 0 then
		if t < smash then return "hold", 0 end
		local SM = braceOn(model) and HookPose.SMASH_BRACE or HookPose.SMASH -- v1.3
		if t < smash + SM then return "smash", (t - smash) / SM end
		return nil, 0
	end
	if t < busy then return "hold", 0 end
	if t < busy + HookPose.LOWER then return "lower", (t - busy) / HookPose.LOWER end
	return nil, 0
end

-- v1.3: Brace & Reel keys {pitch, yaw, roll}; arm = {lift weight, extra degrees} on the hook arm, other = the free arm
local function BOTHK(t) local o = {} for n, v in pairs(t) do o[n] = v end return o end
local BK = {
	ZERO = {arm = {0, 0}},
	BRACE = {arm = {1, 0}, other = {-20, 0, 0}, RootJoint = {-6, 6, 0}, Neck = {-4, -6, 0}, Head = {-4, 0, 0}, Tail1 = {4, -8, 0},
		LegL = {14, 0, -6}, KneeL = {-26, 0, 0}, AnkleL = {12, 0, 0}, LegR = {-16, 0, 6}, KneeR = {-18, 0, 0}, AnkleR = {-6, 0, 0}},
}
BK.KICK = BOTHK(BK.BRACE); BK.KICK.arm = {1, 14}; BK.KICK.RootJoint = {0, 6, 0}; BK.KICK.Neck = {2, -6, 0}
BK.REEL = BOTHK(BK.BRACE); BK.REEL.arm = {1, -26}; BK.REEL.RootJoint = {2, 6, 0}; BK.REEL.Neck = {2, -6, 0}; BK.REEL.Head = {0, 0, 0}
BK.COCK = {arm = {0, 10}, other = {-10, 0, 0}, RootJoint = {10, 0, 0}, Neck = {22, 0, 0}, Head = {16, 0, 0}, Jaw = {-10, 0, 0}, Tail1 = {8, 0, 0}}
BK.SMASH = {arm = {0, -30}, other = {-30, 0, 0}, RootJoint = {-12, 0, 0}, Neck = {-34, 0, 0}, Head = {-46, 0, 0}, Tail1 = {-6, 0, 0}}
HookPose.KEYS = BK
local BJ = {"other", "RootJoint", "Neck", "Head", "Jaw", "Tail1", "LegL", "LegR", "KneeL", "KneeR", "AnkleL", "AnkleR"}
local EASE = {io = smoothstep, out = function(x) x = math.clamp(x, 0, 1); return 1 - (1 - x) ^ 3 end,
	out5 = function(x) x = math.clamp(x, 0, 1); return 1 - (1 - x) ^ 5 end, in2 = function(x) x = math.clamp(x, 0, 1); return x * x end}
local function bsample(keys, t)
	local a, b, u = keys[1], keys[1], 1
	if t > keys[1][1] then
		a, b = keys[#keys], keys[#keys]
		for i = 2, #keys do if t <= keys[i][1] then a, b = keys[i - 1], keys[i]; break end end
		if a ~= b then u = EASE[b[3] or "io"]((t - a[1]) / math.max(1e-4, b[1] - a[1])) end
	end
	local A, B, o = BK[a[2]], BK[b[2]], {}
	for _, n in ipairs(BJ) do
		local va, vb = A[n] or {0, 0, 0}, B[n] or {0, 0, 0}
		o[n] = {va[1] + (vb[1] - va[1]) * u, va[2] + (vb[2] - va[2]) * u, va[3] + (vb[3] - va[3]) * u}
	end
	o.arm = {A.arm[1] + (B.arm[1] - A.arm[1]) * u, A.arm[2] + (B.arm[2] - A.arm[2]) * u}
	return o
end
local function braceGet(model, k, lift, seg)
	local t = workspace:GetServerTimeNow()
	local s = tonumber(model:GetAttribute("HookStartedAt")) or t
	local L = tonumber(model:GetAttribute("HookLaunchAt")) or s
	local C = tonumber(model:GetAttribute("HookContactAt")) or 0
	local S = tonumber(model:GetAttribute("HookSmashAt")) or 0
	local busy = tonumber(model:GetAttribute("HookBusyUntil")) or L
	local keys = {{s, "ZERO"}, {L, "BRACE", "io"}, {L + 0.05, "KICK", "out5"}}
	if S > 0 and C > 0 then
		local c0 = math.max(C, L + 0.1)
		table.insert(keys, {c0, "BRACE", "io"})
		local tug = {{0.08, "REEL", "out"}, {0.16, "BRACE", "io"}, {0.24, "REEL", "out"}, {0.30, "BRACE", "io"}, {0.36, "REEL", "out"}}
		for _, q in ipairs(tug) do if c0 + q[1] < S - 0.12 then table.insert(keys, {c0 + q[1], q[2], q[3]}) end end
		table.insert(keys, {math.max(keys[#keys][1] + 0.01, S - 0.12), "REEL", "io"})
		table.insert(keys, {S, "COCK", "io"})
		table.insert(keys, {S + 0.06, "SMASH", "in2"})
		table.insert(keys, {S + 0.3, "SMASH", "io"})
		table.insert(keys, {S + HookPose.SMASH_BRACE, "ZERO", "io"})
	else
		table.insert(keys, {L + 0.12, "BRACE", "io"})
		table.insert(keys, {math.max(L + 0.13, busy), "BRACE", "io"})
		table.insert(keys, {math.max(L + 0.14, busy) + HookPose.LOWER, "ZERO", "io"})
	end
	local p = bsample(keys, t)
	local out = {}
	local other = seg == "ArmL" and "ArmR" or "ArmL"
	out[seg] = CFrame.Angles(0, 0, rad((lift * p.arm[1] + p.arm[2]) * k))
	for _, n in ipairs(BJ) do
		local v = p[n]
		if v[1] ~= 0 or v[2] ~= 0 or v[3] ~= 0 then out[n == "other" and other or n] = CFrame.Angles(rad(v[3] * k), rad(v[2] * k), rad(v[1] * k)) end
	end
	return out
end
HookPose.braceOn = braceOn

function HookPose.get(phase, u, k, model)
	local out = {}
	local arm, dip, back = 0, 0, 0
	if phase == "raise" then arm, back = smoothstep(u), smoothstep(u)
	elseif phase == "hold" then arm, back = 1, 1
	elseif phase == "smash" then
		arm = 1 - smoothstep(u * 2)
		dip = sin(pi * math.clamp(u, 0, 1))
	elseif phase == "lower" then arm, back = 1 - smoothstep(u), 1 - smoothstep(u)
	end
	local lift = HookPose.ARM_LEVEL -- v1.1: level + the shot's pitch
	if model then
		lift = tonumber(model:GetAttribute("HookArmLevel")) or lift
		local d = model:GetAttribute("HookAimDir")
		if typeof(d) == "Vector3" and d.Magnitude > 1e-3 then lift += math.deg(math.asin(math.clamp(d.Unit.Y, -1, 1))) end
	end
	local seg = model and model:GetAttribute("HookArmSeg") -- v1.2
	seg = (seg == "ArmL" or seg == "ArmR") and seg or "ArmR"
	if braceOn(model) then return braceGet(model, k, lift, seg) end -- v1.3
	out[seg] = CFrame.Angles(0, 0, rad(lift * arm * k))
	out.RootJoint = CFrame.Angles(0, 0, rad((3 * back - 6 * dip) * k))
	out.Neck = CFrame.Angles(0, 0, rad((4 * back - 30 * dip) * k))
	out.Head = CFrame.Angles(0, 0, rad(-40 * dip * k))
	return out
end

return HookPose
