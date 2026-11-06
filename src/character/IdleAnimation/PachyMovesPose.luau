-- PachyMovesPose v1.0 (Mecha Dino Arena) — the pachy's part-move poses and its Coiled Spring leap accents (ModuleScript
-- under IdleAnimation 1.46). MDA-305 / MDA-307, plan docs/plans/PACHY_MOVES_ANIM_v1.0.md Tasks 3 + 5; Kepu 2026-11-05 23:34
-- "A for everything"; mockup docs/mockups/pachy_moves_anim.html v0.1 (keys in tools/mockup/pachy_moves_anim.js).
-- Offsets are multiplied on top of the current pose (walk / run / jump), only on models with Species "Pachy". Joint frames
-- are world-aligned at build time: rotation about Z = pitch (+ lifts the front / swings a limb forward; tail + = lower;
-- jaw - = open; knee - = bend), about Y = yaw (+ toward the dino's left), about X = roll. Right joints mirror the left.
-- Model switch PachyMovesPoseEnabled (default true) and one per move (default true), read every frame:
--   PachyServoPoseEnabled  Thruster Kick: ServoDashStartedAt -> ServoDashBlastAt (ServoDashServer 1.2; missing = the start)
--                          SQUAT; the blast BLAST (0.25 s); the run DASH_RUN lean until ServoDashUntil; then BRAKE 0.35 s,
--                          back to rest by +0.8 s.
--   PachyVisorPoseEnabled  Turtle Brace: VisorStartedAt -> BRACE in 0.1 s (out5), held to VisorUntil; VisorBlockAt
--                          (BoneCrest 1.6) adds BRACE_HIT for 0.4 s; after VisorUntil a head shake (0.1-0.6 s) and rest
--                          by +0.25 s.
--   PachyInkPoseEnabled    Shoulder Cannon: InkStartedAt -> INK_TURN in 0.1 s; InkFireAt (InkServer 1.7; missing = the start)
--                          INK_KICK (0.03 s, out5) -> INK_TURN (0.3 s) -> rest (0.8 s).
--   PachyTetherPoseEnabled Tail Sling: while aiming (owner: TetherAimLocalAt newer than TetherAimLocalEndAt, MechaButtons
--                          1.34; others: TetherAimAt newer than TetherAimEndAt / TetherStartedAt, TetherServer 1.4; at
--                          most 3 s) SLING_COCK (in 0.25 s); TetherStartedAt SLING_WHIP (0.08 s out5) -> rest (0.4 s);
--                          TetherLandAt SLING_FLICK (0.1 s) -> rest (0.5 s).
--   PachyMedPoseEnabled    Deploy Drop: MedDeployAt (MedStationServer 1.3) LAY (0.15 s) held to 0.3 s -> rest (0.7 s).
--   PachyLastStandPoseEnabled Battle Roar: PachyLastStandAt (PachyStatsServer 1.1) HURT (0.05 s) -> ROAR (0.25 s, out5)
--                          held to 0.75 s -> rest (1.1 s).
--   PachyLeapPoseEnabled   Coiled Spring accents on the biped leap (JumpPose stays underneath; heights / timing untouched):
--                          crouch: dome tucked, tail low; push (0.06 s): body + dome thrown forward; air: tucked into a
--                          ball; double jump (JumpDoubleAt / JumpDoublePredictedAt): KICK 0.05 s (out5) -> ball again by
--                          0.22 s; landing (0.25 s): knees soak it. No landing FX.
-- moves(model, serverNow, isOwner) -> offsets or nil, id. leap(model, state, t, W, landAge, serverNow, isOwner) -> offsets or nil.
-- v1.1 (MDA-305 Play test 2026-11-06: the bent legs lifted the feet off the ground, up to 1.4 studs in LAY): each key has a
--   body drop (DROP, studs at model scale 2, measured in Studio as the foot lift of that key; x model scale / 2) blended like
--   the angles and put on the RootJoint as a downward move, so the feet stay on the ground. BLAST keeps its lift (the
--   launch kick). Switch: model attribute PachyMovesPlantEnabled (default true, read every frame; false = 1.0).
--   Diagnostic: model PachyMovesDrop (studs, 0.01 steps, set on change).
local PachyMovesPose = {}
PachyMovesPose.Version = "1.0"
PachyMovesPose.Version = "1.1" -- v1.1 body drop

local rad, sin, min, max = math.rad, math.sin, math.min, math.max
local function clamp(x, a, b) return max(a, min(b, x)) end
local EASE = {
	io = function(x) x = clamp(x, 0, 1); return x * x * (3 - 2 * x) end,
	out = function(x) x = clamp(x, 0, 1); return 1 - (1 - x) ^ 3 end,
	out5 = function(x) x = clamp(x, 0, 1); return 1 - (1 - x) ^ 5 end,
	in2 = function(x) x = clamp(x, 0, 1); return x * x end,
}
local function BOTH(t)
	local o = {}
	for n, v in pairs(t) do o[n] = v; if n:sub(-1) == "L" then o[n:sub(1, -2) .. "R"] = {v[1], -v[2], -v[3]} end end
	return o
end
local function over(a, b) local o = {} for n, v in pairs(a) do o[n] = v end for n, v in pairs(b) do o[n] = v end return o end
local function plus(a, b)
	local o = {} for n, v in pairs(a) do o[n] = v end
	for n, v in pairs(b) do local w = o[n] or {0, 0, 0}; o[n] = {w[1] + v[1], w[2] + v[2], w[3] + v[3]} end
	return o
end
local K = {ZERO = {}}
-- Servo Dash (Thruster Kick)
K.SQUAT = BOTH({RootJoint = {-6, 0, 0}, Neck = {-8, 0, 0}, Head = {-4, 0, 0}, ArmL = {-30, 0, 0}, LegL = {30, 0, 0}, KneeL = {-56, 0, 0}, AnkleL = {24, 0, 0}, Tail1 = {6, 0, 0}})
K.BLAST = BOTH({RootJoint = {-18, 0, 0}, Neck = {-14, 0, 0}, Head = {-20, 0, 0}, Jaw = {-6, 0, 0}, ArmL = {-48, 0, 0}, LegL = {-30, 0, 0}, KneeL = {-10, 0, 0}, AnkleL = {-36, 0, 0}, Tail1 = {-14, 0, 0}, Tail2 = {-6, 0, 0}})
K.DASH_RUN = BOTH({RootJoint = {-10, 0, 0}, Neck = {-10, 0, 0}, Head = {-14, 0, 0}, ArmL = {-40, 0, 0}, Tail1 = {-8, 0, 0}, Tail2 = {-4, 0, 0}})
K.BRAKE = over(BOTH({RootJoint = {12, 0, 0}, Neck = {16, 0, 0}, Head = {10, 0, 0}, ArmL = {20, 0, 0}, Tail1 = {12, 0, 0}}),
	{LegL = {36, 0, 0}, KneeL = {-14, 0, 0}, AnkleL = {22, 0, 0}, LegR = {14, 0, 0}, KneeR = {-34, 0, 0}})
-- Visor (Turtle Brace)
K.BRACE = over(BOTH({RootJoint = {-6, 0, 0}, Neck = {-16, 0, 0}, Head = {-22, 0, 0}, ArmL = {36, 0, -10}, Tail1 = {8, 0, 0}, Tail2 = {4, 0, 0}}),
	{LegL = {22, 0, -6}, KneeL = {-40, 0, 0}, AnkleL = {18, 0, 0}, LegR = {-10, 0, 6}, KneeR = {-30, 0, 0}, AnkleR = {10, 0, 0}})
K.BRACE_HIT = plus(K.BRACE, {RootJoint = {6, 0, 0}, Neck = {10, 0, 0}, Head = {8, 0, 0}})
-- Ink (Shoulder Cannon): the tank is on the dino's left, so the body yaws right to bring that shoulder in
K.INK_TURN = {RootJoint = {-2, -16, 0}, Neck = {-4, 14, 0}, Head = {-6, 6, 0}, ArmL = {-20, 0, 0}, ArmR = {-20, 0, 0}, Tail1 = {0, 12, 0},
	LegL = {12, 0, 0}, KneeL = {-24, 0, 0}, LegR = {-10, 0, 0}, KneeR = {-18, 0, 0}}
K.INK_KICK = plus(K.INK_TURN, {RootJoint = {6, 6, -8}, Neck = {8, 0, 0}})
-- Tether (Tail Sling)
K.SLING_COCK = BOTH({RootJoint = {-8, 0, 0}, Neck = {-6, 0, 0}, Head = {-6, 0, 0}, ArmL = {-20, 0, 0}, Tail1 = {-34, 0, 0}, Tail2 = {-26, 0, 0}, Tail3 = {-20, 0, 0}, Tail4 = {-14, 0, 0}, Tail5 = {-10, 0, 0}, LegL = {10, 0, 0}, KneeL = {-24, 0, 0}, AnkleL = {10, 0, 0}})
K.SLING_WHIP = BOTH({RootJoint = {4, 0, 0}, Neck = {4, 0, 0}, Head = {-2, 0, 0}, ArmL = {-10, 0, 0}, Tail1 = {14, 0, 0}, Tail2 = {10, 0, 0}, Tail3 = {8, 0, 0}, Tail4 = {6, 0, 0}})
K.SLING_FLICK = {Tail1 = {-10, 12, 0}, Tail2 = {-6, 14, 0}, Tail3 = {-4, 16, 0}}
-- Med-Station (Deploy Drop)
K.LAY = BOTH({RootJoint = {-14, 0, 0}, Neck = {-14, 0, 0}, Head = {6, 0, 0}, ArmL = {-20, 0, 0}, LegL = {30, 0, 0}, KneeL = {-54, 0, 0}, AnkleL = {22, 0, 0}, Tail1 = {-22, 0, 0}, Tail2 = {-16, 0, 0}, Tail3 = {-10, 0, 0}})
-- Last Stand (Battle Roar)
K.HURT = BOTH({RootJoint = {8, 0, 4}, Neck = {14, -12, 0}, Head = {8, -6, 0}, Jaw = {-14, 0, 0}, ArmL = {-20, 0, 0}})
K.ROAR = BOTH({RootJoint = {10, 0, 0}, Neck = {30, 0, 0}, Head = {22, 0, 0}, Jaw = {-46, 0, 0}, ArmL = {30, 0, -20}, Tail1 = {-8, 0, 0}, Tail2 = {-6, 0, 0}, LegL = {8, 0, 0}, KneeL = {-20, 0, 0}})
-- leap accents (Coiled Spring), relative to the biped JumpPose
K.L_COIL = BOTH({Neck = {-10, 0, 0}, Head = {-16, 0, 0}, Tail1 = {6, 0, 0}, Tail2 = {6, 0, 0}})
K.L_FIRE = BOTH({RootJoint = {-14, 0, 0}, Neck = {-24, 0, 0}, Head = {-16, 0, 0}, ArmL = {-15, 0, 0}, Tail1 = {-4, 0, 0}})
K.L_BALL = BOTH({Neck = {-20, 0, 0}, Head = {-24, 0, 0}, ArmL = {-5, 0, 0}, LegL = {16, 0, 0}, KneeL = {-24, 0, 0}, AnkleL = {10, 0, 0}, Tail1 = {24, 0, 0}, Tail2 = {16, 0, 0}, Tail3 = {10, 0, 0}})
K.L_KICK = BOTH({RootJoint = {10, 0, 0}, Neck = {16, 0, 0}, Head = {8, 0, 0}, ArmL = {5, 0, 0}, LegL = {-46, 0, 0}, KneeL = {56, 0, 0}, AnkleL = {-60, 0, 0}, Tail1 = {-16, 0, 0}, Tail2 = {-8, 0, 0}})
K.L_ABSORB = BOTH({Neck = {-6, 0, 0}, LegL = {6, 0, 0}, KneeL = {-16, 0, 0}})
PachyMovesPose.KEYS = K
-- v1.1: studs the body moves down at full weight (model scale 2); negative = up (the key sinks the feet)
local DROP = {SQUAT = 0.98, DASH_RUN = -0.17, BRAKE = 0.61, BRACE = 0.68, BRACE_HIT = 0.68, INK_TURN = -0.09, INK_KICK = -0.2,
	SLING_COCK = 0.37, SLING_WHIP = 0.04, LAY = 1.38, HURT = 0.37, ROAR = 0.38}
PachyMovesPose.DROP = DROP

local NAMES = {"RootJoint", "Neck", "Head", "Jaw", "ArmL", "ArmR", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "LegL", "LegR", "KneeL", "KneeR", "AnkleL", "AnkleR"}
-- keys {{t, name, ease}, ...} -> {joint = {p, y, r}}; t before the first key = the first key, after the last = the last
local function sample(keys, t)
	local a, b, u = keys[1], keys[1], 1
	if t > keys[1][1] then
		a, b = keys[#keys], keys[#keys]
		for i = 2, #keys do if t <= keys[i][1] then a, b = keys[i - 1], keys[i]; break end end
		if a ~= b then u = EASE[b[3] or "io"]((t - a[1]) / max(1e-4, b[1] - a[1])) end
	end
	local A, B, o = K[a[2]], K[b[2]], {}
	for _, n in ipairs(NAMES) do
		local va, vb = A[n] or {0, 0, 0}, B[n] or {0, 0, 0}
		o[n] = {va[1] + (vb[1] - va[1]) * u, va[2] + (vb[2] - va[2]) * u, va[3] + (vb[3] - va[3]) * u}
	end
	local da, db = DROP[a[2]] or 0, DROP[b[2]] or 0 -- v1.1
	o._drop = da + (db - da) * u
	return o
end
local function toCF(p, w, model)
	local out = {}
	for n, v in pairs(p) do
		if n ~= "_drop" and (v[1] ~= 0 or v[2] ~= 0 or v[3] ~= 0) then out[n] = CFrame.Angles(rad(v[3] * w), rad(v[2] * w), rad(v[1] * w)) end
	end
	if model then -- v1.1: the body drop
		local d = 0
		if model:GetAttribute("PachyMovesPlantEnabled") ~= false and p._drop and p._drop ~= 0 then
			d = p._drop * w * (model:IsA("Model") and model:GetScale() or 2) / 2
			out.RootJoint = CFrame.new(0, -d, 0) * (out.RootJoint or CFrame.identity)
		end
		local r = math.floor(d * 100 + 0.5) / 100
		if model:GetAttribute("PachyMovesDrop") ~= r then model:SetAttribute("PachyMovesDrop", r) end
	end
	return out
end
local function num(m, k) local v = m:GetAttribute(k) return typeof(v) == "number" and v == v and v or nil end
local function on(m, k) return m:GetAttribute(k) ~= false end
local function add(acc, p)
	for _, n in ipairs(NAMES) do local a, b = acc[n], p[n]; acc[n] = {a[1] + b[1], a[2] + b[2], a[3] + b[3]} end
	acc._drop = (acc._drop or 0) + (p._drop or 0) -- v1.1
end

-- each returns {joint = {p, y, r}} or nil
local function servo(m, T)
	local s, u = num(m, "ServoDashStartedAt"), num(m, "ServoDashUntil")
	if not s or not u or T < s or T > u + 0.8 then return nil end
	local b = num(m, "ServoDashBlastAt") or s
	if b < s or b > s + 0.5 then b = s end
	return sample({{s, "ZERO"}, {b, "SQUAT", "io"}, {b + 0.06, "BLAST", "out5"}, {b + 0.25, "BLAST"}, {b + 0.37, "DASH_RUN", "io"},
		{max(b + 0.38, u), "DASH_RUN"}, {max(b + 0.5, u + 0.12), "BRAKE", "out"}, {max(b + 0.73, u + 0.35), "BRAKE", "io"}, {max(b + 1.2, u + 0.8), "ZERO", "io"}}, T)
end
local function visor(m, T)
	local s, u = num(m, "VisorStartedAt"), num(m, "VisorUntil")
	if not s or not u or T < s or T > u + 0.65 then return nil end
	local p = sample({{s, "ZERO"}, {s + 0.1, "BRACE", "out5"}, {max(s + 0.11, u), "BRACE"}, {max(s + 0.12, u) + 0.25, "ZERO", "io"}}, T)
	local blk = num(m, "VisorBlockAt")
	if blk and blk >= s and T >= blk and T < blk + 0.4 then
		local w = T < blk + 0.06 and EASE.out((T - blk) / 0.06) or 1 - EASE.io((T - blk - 0.06) / 0.34)
		local hit = {RootJoint = {6, 0, 0}, Neck = {10, 0, 0}, Head = {8, 0, 0}}
		for n, v in pairs(hit) do p[n] = {p[n][1] + v[1] * w, p[n][2], p[n][3]} end
	end
	local e = T - u
	if e > 0.1 and e < 0.6 then
		local d = 1 - (e - 0.1) / 0.5
		p.Neck[2] += 8 * sin((e - 0.1) * 34) * d
		p.Head[2] += 6 * sin((e - 0.1) * 34 + 0.6) * d
	end
	return p
end
local function ink(m, T)
	local s = num(m, "InkStartedAt")
	if not s or T < s or T > s + 1.2 then return nil end
	local f = num(m, "InkFireAt") or s
	if f < s or f > s + 0.5 then f = s end
	if m:GetAttribute("InkCancelAt") and (num(m, "InkCancelAt") or 0) >= s then
		return sample({{s, "ZERO"}, {s + 0.1, "INK_TURN", "io"}, {s + 0.5, "ZERO", "io"}}, T)
	end
	local keys = {{s, "ZERO"}}
	if f > s + 0.01 then table.insert(keys, {f, "INK_TURN", "io"}) end
	table.insert(keys, {f + 0.03, "INK_KICK", "out5"})
	table.insert(keys, {f + 0.3, "INK_TURN", "io"})
	table.insert(keys, {f + 0.8, "ZERO", "io"})
	return sample(keys, T)
end
local function tether(m, T, isOwner)
	local acc, any = nil, false
	local aimAt, aimEnd
	if isOwner and m:GetAttribute("TetherAimLocalAt") ~= nil then
		aimAt, aimEnd = num(m, "TetherAimLocalAt"), num(m, "TetherAimLocalEndAt")
	else
		aimAt, aimEnd = num(m, "TetherAimAt"), num(m, "TetherAimEndAt")
	end
	local rel = num(m, "TetherStartedAt") or -1e9
	local land = num(m, "TetherLandAt") or -1e9
	local p = sample({{0, "ZERO"}}, 0)
	if aimAt and T >= aimAt and T < aimAt + 3 then
		local endAt = max(aimEnd or -1e9, rel)
		local w
		if endAt < aimAt then w = EASE.io((T - aimAt) / 0.25)
		elseif T < endAt + 0.12 then w = EASE.io((endAt - aimAt) / 0.25) * (1 - EASE.io((T - endAt) / 0.12))
		else w = 0 end
		if w > 0 then
			for n, v in pairs(K.SLING_COCK) do p[n] = {p[n][1] + v[1] * w, p[n][2] + v[2] * w, p[n][3] + v[3] * w} end
			p._drop = (p._drop or 0) + DROP.SLING_COCK * w -- v1.1
			any = true
		end
	end
	if T >= rel and T < rel + 0.4 then add(p, sample({{rel, "ZERO"}, {rel + 0.08, "SLING_WHIP", "out5"}, {rel + 0.4, "ZERO", "io"}}, T)); any = true end
	if T >= land and T < land + 0.5 then add(p, sample({{land, "ZERO"}, {land + 0.1, "SLING_FLICK", "out"}, {land + 0.5, "ZERO", "io"}}, T)); any = true end
	return any and p or nil
end
local function med(m, T)
	local s = num(m, "MedDeployAt")
	if not s or T < s or T > s + 0.7 then return nil end
	return sample({{s, "ZERO"}, {s + 0.15, "LAY", "io"}, {s + 0.3, "LAY"}, {s + 0.7, "ZERO", "io"}}, T)
end
local function lastStand(m, T)
	local s = num(m, "PachyLastStandAt")
	if not s or T < s or T > s + 1.1 then return nil end
	return sample({{s, "ZERO"}, {s + 0.05, "HURT", "out"}, {s + 0.25, "ROAR", "out5"}, {s + 0.75, "ROAR"}, {s + 1.1, "ZERO", "io"}}, T)
end

local MOVES = {
	{"servo", "PachyServoPoseEnabled", servo}, {"visor", "PachyVisorPoseEnabled", visor}, {"ink", "PachyInkPoseEnabled", ink},
	{"tether", "PachyTetherPoseEnabled", tether}, {"med", "PachyMedPoseEnabled", med}, {"laststand", "PachyLastStandPoseEnabled", lastStand},
}
function PachyMovesPose.on(model) return model:GetAttribute("Species") == "Pachy" and model:GetAttribute("PachyMovesPoseEnabled") ~= false end

function PachyMovesPose.moves(model, serverNow, isOwner)
	if not PachyMovesPose.on(model) then return nil end
	local acc, ids = nil, {}
	for _, mv in ipairs(MOVES) do
		if on(model, mv[2]) then
			local p = mv[3](model, serverNow, isOwner)
			if p then
				if not acc then acc = sample({{0, "ZERO"}}, 0) end
				add(acc, p)
				table.insert(ids, mv[1])
			end
		end
	end
	if not acc then
		if model:GetAttribute("PachyMovesDrop") ~= nil and model:GetAttribute("PachyMovesDrop") ~= 0 then model:SetAttribute("PachyMovesDrop", 0) end -- v1.1
		return nil, ""
	end
	return toCF(acc, 1, model), table.concat(ids, "+") -- v1.1: + model (the body drop)
end

-- state: IdleAnimation's jump state ("crouch" / "push" / "rise" / "fall" / "land" / "none"); t = s since the leap start;
-- W = JumpWindup; landAge = s since touchdown (nil in the air)
function PachyMovesPose.leap(model, state, t, W, landAge, serverNow, isOwner)
	if not PachyMovesPose.on(model) or model:GetAttribute("PachyLeapPoseEnabled") == false or state == "none" then return nil end
	local p = sample({{0, "ZERO"}}, 0)
	local function blend(key, w) if w > 0 then for n, v in pairs(K[key]) do p[n] = {p[n][1] + v[1] * w, p[n][2] + v[2] * w, p[n][3] + v[3] * w} end end end
	if state == "crouch" then
		blend("L_COIL", EASE.io(t / max(0.01, W)))
	elseif state == "push" then
		local x = t - W
		blend("L_COIL", 1 - EASE.io(x / 0.06)); blend("L_FIRE", EASE.out5(x / 0.06))
	elseif state == "rise" or state == "fall" then
		local x = t - W
		local fire = 1 - EASE.io((x - 0.06) / 0.16)
		local ball = EASE.io((x - 0.06) / 0.16) * (state == "fall" and 0.6 or 1)
		local dj = num(model, "JumpDoubleAt")
		local djp = isOwner and num(model, "JumpDoublePredictedAt") or nil
		if djp and (not dj or djp > dj) then dj = djp end
		local kick = 0
		if dj and dj > serverNow - 0.4 and dj >= serverNow - x - 0.05 then
			local a = serverNow - dj
			kick = a < 0.05 and EASE.out5(a / 0.05) or 1 - EASE.io((a - 0.05) / 0.17)
		end
		blend("L_FIRE", math.clamp(fire, 0, 1)); blend("L_BALL", ball * (1 - kick)); blend("L_KICK", kick)
	elseif state == "land" and landAge then
		blend("L_ABSORB", landAge < 0.08 and EASE.out(landAge / 0.08) or 1 - EASE.io((landAge - 0.08) / 0.17))
	else
		return nil
	end
	return toCF(p, 1)
end

return PachyMovesPose
