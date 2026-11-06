-- HerreraMovesPose v1.2 (Mecha Dino Arena) — the Herrera's Glider Wings glide pose and the Strobe Frill rear-up, used by
-- IdleAnimation 1.36. Plan docs/plans/HERRERA_PARTS_v1.0.md Part 2 (glide pose) and Part 7 (rear-up), "Pass 2 — build map".
-- Joint frames as ScurryPose 1.0: pitch about Z (+ lifts the front / swings a limb forward; Tail + = lower), yaw about Y,
--   roll about X; RootJoint carries the whole-body pitch.
-- Glide (full pose, ScurryPose.meanAngles + offsets, with the mean scurry drop like HerreraJumpPose's air pose):
--   arms out (ArmL roll -GlideArmRoll, ArmR roll +GlideArmRoll, pitch +GlideArmPitch), legs trailing (LegL / LegR pitch
--   -GlideLegTrail), the tail straightened (the scurry tail angles x GlideTailKeep), body pitch +GlidePitch.
--   glideWeight(model, isOwner, dt) -> 0..1: eases in over GLIDE_IN (0.2 s) while gliding (owner: GlideLocal, GliderTest
--   1.0; others: the replicated Gliding), out over GLIDE_OUT (0.25 s). The caller lerps the pose toward getGlide(...) by it.
-- Strobe rear-up (offsets multiplied on top): from the model's StrobeStartedAt (HerreraMovesServer 1.0): up over
--   STROBE_UP (0.15 s), held STROBE_HOLD (0.2 s), down over STROBE_DOWN (0.2 s): RootJoint +18 x k, Neck +18 x k,
--   Jaw -20 x k. strobe(model, serverNow) -> {[joint] = CFrame} or nil.
-- Switches (model attributes): GlidePoseEnabled, StrobePoseEnabled (default true each).
-- v1.1 (MDA-166, plan docs/plans/HERRERA_PARTS_v1.0.md Part 10 "On fire: ... body pitch -7 deg (gooKick)"; Kepu 2026-11-03
--   "166- make it"): gooKick(model, serverNow) -> {RootJoint = pitch -7 x k} or nil, from the model's GooFiredAt
--   (HerreraMovesServer 1.2) for GOO_KICK (0.35 s): k rises to 1 over the first 15% (out) and eases back to 0 (in-out).
--   Switch: model attribute GooPosePoseEnabled (default true; false = nil).
-- v1.2 (plan docs/plans/HERRERA_MOVES_ANIM_v1.0.md Tasks 4-5, MDA-294 / 295; Kepu 2026-11-05 20:40 "A for everything except
--   B for glide and drop"; mockup docs/mockups/herrera_moves_anim.html v0.1): offsets as {pitch, yaw, roll} degrees.
--   moves(model, serverNow) -> {[joint] = CFrame}, id or nil: the sum of the move poses running now, each keyed from its
--   wind-up stamp W (HerreraMovesServer 1.5 / AdrenalineServer 1.6) and fire stamp F (fallback F = W + <P>WindupTime;
--   without a wind-up stamp the pose starts at F and eases in over 0.15 s):
--     quills    QuillWindupAt / QuillStartedAt: -> ANCHOR by F (legs splayed, crouch, tail down), a kick (RootJoint +3,
--               Neck +3, 0.04 s) per quill (QuillShot, 0.045 s apart), held to QuillLandedAt (at least F + 0.45, else
--               F + 0.6), -> 0 over 0.7 s.                                   switch QuillAnimPoseEnabled
--     smoke     SmokeWindupAt / SmokeStartedAt: -> LOW + TAIL_UP by F + 0.05, held to SmokeUntil - 0.4, -> 0 by SmokeUntil
--               + 0.2.                                                         switch SmokeAnimPoseEnabled
--     strobe    StrobeStartedAt / StrobeAt: -> PULLBACK by F, -> SNAPFWD by F + 0.08 (ease out), held to F + 0.5, -> 0
--               by F + 1.2; strobe() (the 1.1 rear-up) returns nil while on.   switch StrobeAnimPoseEnabled
--     breaker   BreakerWindupAt / BreakerAt: -> SHAKE (40 rad/s) by W + 0.1, shaking to F, -> ROARUP by F + 0.1 (ease out),
--               held to F + 0.5, -> 0 by F + 1.2.                              switch BreakerAnimPoseEnabled
--     caltrops  CaltropDroppedAt D: -> tail lift by D + 0.2, held to D + 0.7, -> 0 by D + 1.3.  switch CaltropAnimPoseEnabled
--     goo       GooWindupAt / GooFiredAt: -> PULLBACK by F, -> SNAPFWD by F + 0.07 (ease out), -> SNAPFWD + RECOIL by
--               F + 0.3, -> 0 by F + 0.95; gooKick() (1.1) returns nil while on.  switch GooAnimPoseEnabled
--     adrenaline (Species "Herrera") AdrenalineWindupAt / AdrenalineStartedAt: -> LOOKSHOULDER by W + 0.25, held to
--               W + 0.3, -> shiver (SHAKE at 20 rad/s) by W + 0.5, -> ROARUP by F + 0.2 (ease out), -> 0 by F + 0.5 (the
--               mockup's times).                                                switch AdrenAnimPoseEnabled
--   bank(model, hrp, dt, glideWeight, isOwner) -> RootJoint roll CFrame or nil (Banking Glide): the HRP's flat yaw rate
--   (smoothed over 0.15 s) x GlideBankGain (0.35) degrees, clamped to +-GlideBankMax (26), x the glide weight. Switch
--   GlideBankEnabled. Diagnostic (owner): GlideBankRoll.
--   corkscrew(model, isOwner, phase, kind, u) -> {[joint] = CFrame} or nil: a dive slash that started from a glide (owner:
--   GlideLocal true or GlideLocalReason "slash" at the dash's first frame and not on a tree; others: SlashGlideDive)
--   rolls RootJoint 360 x smoothstep(u) and adds STOOP x smoothstep(u / 0.6). Switch GlideCorkscrewEnabled. Diagnostic
--   GlideCorkscrews (count).
local ScurryPose = require(script.Parent:WaitForChild("ScurryPose"))
local M = {}
M.Version = "1.0"
M.Version = "1.1" -- v1.1 gooKick
M.Version = "1.2" -- v1.2 move poses, bank, corkscrew
M.Defaults = {GlideArmRoll = 55, GlideArmPitch = 20, GlideLegTrail = 45, GlideTailKeep = 0.2, GlidePitch = 14}
local GLIDE_IN, GLIDE_OUT = 0.2, 0.25
local STROBE_UP, STROBE_HOLD, STROBE_DOWN = 0.15, 0.2, 0.2
local rad = math.rad

local function settings(model)
	local s = {}
	for k, v in pairs(M.Defaults) do
		local a = model and model:GetAttribute(k)
		s[k] = type(a) == "number" and a or v
	end
	return s
end
local function add(o, n, p, y, r)
	if not o[n] then return end
	o[n][1] += p
	o[n][2] += (y or 0)
	o[n][3] += (r or 0)
end

local weights = setmetatable({}, {__mode = "k"})
function M.glideWeight(model, isOwner, dt)
	local on = model:GetAttribute("GlidePoseEnabled") ~= false
		and (isOwner and model:GetAttribute("GlideLocal") or model:GetAttribute("Gliding")) == true
	local w = weights[model] or 0
	if on then w = math.min(1, w + dt / GLIDE_IN) else w = math.max(0, w - dt / GLIDE_OUT) end
	weights[model] = w
	return w * w * (3 - 2 * w)
end

local meanDrop
function M.getGlide(model, ss, geo, motors, scale)
	local s = settings(model)
	local o = ScurryPose.meanAngles(ss)
	add(o, "ArmL", s.GlideArmPitch, 0, -s.GlideArmRoll)
	add(o, "ArmR", s.GlideArmPitch, 0, s.GlideArmRoll)
	add(o, "LegL", -s.GlideLegTrail)
	add(o, "LegR", -s.GlideLegTrail)
	for i = 1, 5 do
		local n = o["Tail" .. i]
		if n then n[1], n[2], n[3] = n[1] * s.GlideTailKeep, n[2] * s.GlideTailKeep, n[3] * s.GlideTailKeep end
	end
	add(o, "RootJoint", s.GlidePitch)
	if not meanDrop or meanDrop.geo ~= geo then
		local _, d = ScurryPose.fitted(ScurryPose.meanAngles(ss), geo, motors, scale)
		meanDrop = {geo = geo, d = d}
	end
	local pose = ScurryPose.toPose(o)
	pose.RootJoint = CFrame.new(0, meanDrop.d, 0) * pose.RootJoint
	return pose
end

local function rot(p) return CFrame.fromEulerAngles(0, 0, rad(p), Enum.RotationOrder.ZYX) end
function M.strobe(model, serverNow)
	if model:GetAttribute("StrobePoseEnabled") == false then return nil end
	if model:GetAttribute("StrobeAnimPoseEnabled") ~= false then return nil end -- v1.2: moves() plays the Frill Display
	local st = model:GetAttribute("StrobeStartedAt")
	if typeof(st) ~= "number" then return nil end
	local t = serverNow - st
	local k
	if t < 0 or t > STROBE_UP + STROBE_HOLD + STROBE_DOWN then return nil
	elseif t < STROBE_UP then k = t / STROBE_UP
	elseif t < STROBE_UP + STROBE_HOLD then k = 1
	else k = 1 - (t - STROBE_UP - STROBE_HOLD) / STROBE_DOWN end
	k = k * k * (3 - 2 * k)
	return {RootJoint = rot(18 * k), Neck = rot(18 * k), Jaw = rot(-20 * k)}
end

-- v1.1: the Goo Blob Shooter's recoil
local GOO_KICK = 0.35
function M.gooKick(model, serverNow)
	if model:GetAttribute("GooPosePoseEnabled") == false then return nil end
	if model:GetAttribute("GooAnimPoseEnabled") ~= false then return nil end -- v1.2: moves() plays the Frill Spit
	local at = model:GetAttribute("GooFiredAt")
	if typeof(at) ~= "number" then return nil end
	local u = (serverNow - at) / GOO_KICK
	if u < 0 or u > 1 then return nil end
	local k
	if u < 0.15 then k = 1 - (1 - u / 0.15) ^ 2 else local v = (u - 0.15) / 0.85 k = 1 - v * v * (3 - 2 * v) end
	return {RootJoint = rot(-7 * k)}
end

-- v1.2: move poses ----------------------------------------------------------------------------------------------------
local sin, clamp = math.sin, math.clamp
local function rot3(p, y, r) return CFrame.fromEulerAngles(rad(r), rad(y), rad(p), Enum.RotationOrder.ZYX) end
local function smooth(u) u = clamp(u, 0, 1) return u * u * (3 - 2 * u) end
local function easeOut(u) u = clamp(u, 0, 1) return 1 - (1 - u) * (1 - u) end
local Z = {}
local ANCHOR = {RootJoint = {-8, 0, 0}, LegL = {26, 16, 0}, LegR = {26, -16, 0}, KneeL = {-36, 0, 0}, KneeR = {-36, 0, 0},
	AnkleL = {12, 0, 0}, AnkleR = {12, 0, 0}, ArmL = {10, 0, -12}, ArmR = {10, 0, 12}, Neck = {-10, 0, 0}, Head = {8, 0, 0},
	Tail1 = {10, 0, 0}, Tail2 = {6, 0, 0}}
local LOWTAIL = {RootJoint = {-24, 0, 0}, LegL = {40, 0, 0}, LegR = {40, 0, 0}, KneeL = {-62, 0, 0}, KneeR = {-62, 0, 0},
	AnkleL = {22, 0, 0}, AnkleR = {22, 0, 0}, ArmL = {30, 0, -10}, ArmR = {30, 0, 10}, Neck = {-12, 0, 0}, Head = {6, 0, 0},
	Tail1 = {-4, 0, 0}, Tail2 = {-6, 0, 0}, Tail3 = {-8, 0, 0}}
local PULLBACK = {RootJoint = {10, 0, 0}, Neck = {28, 0, 0}, Head = {-18, 0, 0}, Jaw = {-10, 0, 0}, ArmL = {10, 0, 0}, ArmR = {10, 0, 0}}
local SNAPFWD = {RootJoint = {-10, 0, 0}, Neck = {-16, 0, 0}, Head = {8, 0, 0}, Jaw = {-34, 0, 0}, LegL = {16, 0, 0}, KneeL = {-16, 0, 0}}
local SNAPRECOIL = {RootJoint = {-4, 0, 0}, Neck = {-10, 0, 0}, Head = {8, 0, 0}, Jaw = {-34, 0, 0}, LegL = {16, 0, 0}, KneeL = {-16, 0, 0}}
local ROARUP = {RootJoint = {14, 0, 0}, Neck = {32, 0, 0}, Head = {10, 0, 0}, Jaw = {-40, 0, 0}, ArmL = {20, 0, -20},
	ArmR = {20, 0, 20}, Tail1 = {-10, 0, 0}}
local TAILLIFT = {Tail1 = {-20, 0, 0}, Tail2 = {-14, 0, 0}, Tail3 = {-8, 0, 0}, RootJoint = {-10, 0, 0}}
local LOOKSHOULDER = {Neck = {-6, 34, 0}, Head = {-14, 20, 0}, ArmL = {16, 0, 0}, RootJoint = {-4, 0, 0}}
local STOOP = {RootJoint = {-40, 0, 0}, ArmL = {-30, 0, -10}, ArmR = {-30, 0, 10}, LegL = {-60, 0, 0}, LegR = {-60, 0, 0},
	Neck = {-8, 0, 0}, Head = {10, 0, 0}, Jaw = {-20, 0, 0}, Tail1 = {-10, 0, 0}, Tail2 = {-6, 0, 0}}
local function shake(t, rate)
	local w = t * rate
	return {RootJoint = {0, 0, 14 * sin(w)}, Neck = {0, 18 * sin(w + 1), 10 * sin(w)}, Head = {0, 14 * sin(w + 2), 0},
		Tail1 = {0, -14 * sin(w + 1), 0}, Tail2 = {0, -18 * sin(w + 2), 0}, Tail3 = {0, -20 * sin(w + 3), 0}}
end
M.Poses = {ANCHOR = ANCHOR, LOWTAIL = LOWTAIL, PULLBACK = PULLBACK, SNAPFWD = SNAPFWD, SNAPRECOIL = SNAPRECOIL,
	ROARUP = ROARUP, TAILLIFT = TAILLIFT, LOOKSHOULDER = LOOKSHOULDER, STOOP = STOOP}

local function lerpP(a, b, k)
	local o = {}
	for n, v in pairs(a) do o[n] = {v[1] * (1 - k), v[2] * (1 - k), v[3] * (1 - k)} end
	for n, v in pairs(b) do
		local w = o[n] or {0, 0, 0}
		o[n] = {w[1] + v[1] * k, w[2] + v[2] * k, w[3] + v[3] * k}
	end
	return o
end
-- keys {{time, pose (table or function(t)), ease}, ...}; the ease shapes the move INTO that key; nil past the last key
local function at(t, keys)
	if t < keys[1][1] or t > keys[#keys][1] then return nil end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b[1] then
			local pa = type(a[2]) == "function" and a[2](t) or a[2]
			local pb = type(b[2]) == "function" and b[2](t) or b[2]
			local span = b[1] - a[1]
			local u = span > 1e-4 and (t - a[1]) / span or 1
			return lerpP(pa, pb, (b[3] or smooth)(u))
		end
	end
	return nil
end
M.at = at
local function stampNum(model, k)
	local v = model:GetAttribute(k)
	return typeof(v) == "number" and v or nil
end
-- W, F from a wind-up stamp and a fire stamp; a = the wind-up length used for the keys
local function pair(model, wk, fk, tk, default)
	local W, F = stampNum(model, wk), stampNum(model, fk)
	if W and (not F or W > F + 1e-3) then
		F = W + (stampNum(model, tk) or default)
	elseif F and (not W or F - W > 2) then
		W = F
	end
	if not W then return nil end
	return W, F, math.max(F - W, 0.15)
end

local MOVES = {}
MOVES.quills = function(model, now)
	local W, F, a = pair(model, "QuillWindupAt", "QuillStartedAt", "QuillWindupTime", 0.35)
	if not W then return nil end
	local landed = stampNum(model, "QuillLandedAt")
	local L = (landed and landed >= F) and math.max(landed, F + 0.45) or F + 0.6
	local t = now - W
	local p = at(t, {{0, Z}, {a, ANCHOR}, {a + (L - F), ANCHOR}, {a + (L - F) + 0.7, Z}})
	if not p then return nil end
	local fireAt = F - W
	local n = math.max(1, math.floor(tonumber(model:GetAttribute("QuillShot")) or 5))
	for i = 0, n - 1 do
		local d = t - (fireAt + i * 0.045)
		if d >= 0 and d < 0.04 then
			local k = sin(math.pi * d / 0.04)
			p.RootJoint = p.RootJoint or {0, 0, 0}
			p.Neck = p.Neck or {0, 0, 0}
			p.RootJoint[1] += 3 * k
			p.Neck[1] += 3 * k
		end
	end
	return p
end
MOVES.smoke = function(model, now)
	local W, F, a = pair(model, "SmokeWindupAt", "SmokeStartedAt", "SmokeWindupTime", 0.25)
	if not W then return nil end
	local U = stampNum(model, "SmokeUntil") or (F + 4)
	if U < F then U = F + 4 end
	local hold = math.max(a + 0.05, a + (U - F) - 0.4)
	return at(now - W, {{0, Z}, {a + 0.05, LOWTAIL}, {hold, LOWTAIL}, {a + (U - F) + 0.2, Z}})
end
MOVES.strobe = function(model, now)
	local W, F, a = pair(model, "StrobeStartedAt", "StrobeAt", "StrobeWindupTime", 0.40)
	if not W then return nil end
	return at(now - W, {{0, Z}, {a, PULLBACK}, {a + 0.08, SNAPFWD, easeOut}, {a + 0.5, SNAPFWD}, {a + 1.2, Z}})
end
MOVES.breaker = function(model, now)
	local W, F, a = pair(model, "BreakerWindupAt", "BreakerAt", "BreakerWindupTime", 0.30)
	if not W then return nil end
	local sh = function(t) return shake(t, 40) end
	return at(now - W, {{0, Z}, {math.min(0.1, a), sh, easeOut}, {a, sh}, {a + 0.1, ROARUP, easeOut}, {a + 0.5, ROARUP}, {a + 1.2, Z}})
end
MOVES.caltrops = function(model, now)
	local D = stampNum(model, "CaltropDroppedAt")
	if not D then return nil end
	return at(now - D, {{0, Z}, {0.2, TAILLIFT}, {0.7, TAILLIFT}, {1.3, Z}})
end
MOVES.goo = function(model, now)
	local W, F, a = pair(model, "GooWindupAt", "GooFiredAt", "GooWindupTime", 0.35)
	if not W then return nil end
	return at(now - W, {{0, Z}, {a, PULLBACK}, {a + 0.07, SNAPFWD, easeOut}, {a + 0.3, SNAPRECOIL}, {a + 0.95, Z}})
end
MOVES.adrenaline = function(model, now)
	if model:GetAttribute("Species") ~= "Herrera" then return nil end
	local W, F, a = pair(model, "AdrenalineWindupAt", "AdrenalineStartedAt", "AdrenalineWindupTime", 0.45)
	if not W then return nil end
	local sv = function(t) return shake(t, 20) end
	if F - W < 0.05 then -- no wind-up: a short roar only
		return at(now - W, {{0, Z}, {0.15, ROARUP, easeOut}, {0.45, Z}})
	end
	return at(now - W, {{0, Z}, {0.25, LOOKSHOULDER}, {0.3, LOOKSHOULDER}, {math.min(0.5, a), sv}, {a + 0.2, ROARUP, easeOut}, {a + 0.5, Z}})
end
local ORDER = {{"quills", "QuillAnimPoseEnabled"}, {"smoke", "SmokeAnimPoseEnabled"}, {"strobe", "StrobeAnimPoseEnabled"},
	{"breaker", "BreakerAnimPoseEnabled"}, {"caltrops", "CaltropAnimPoseEnabled"}, {"goo", "GooAnimPoseEnabled"},
	{"adrenaline", "AdrenAnimPoseEnabled"}}
function M.movesAngles(model, serverNow)
	local sum, last
	for _, e in ipairs(ORDER) do
		if model:GetAttribute(e[2]) ~= false then
			local p = MOVES[e[1]](model, serverNow)
			if p then
				sum = sum or {}
				for n, v in pairs(p) do
					local w = sum[n] or {0, 0, 0}
					sum[n] = {w[1] + v[1], w[2] + v[2], w[3] + v[3]}
				end
				last = e[1]
			end
		end
	end
	return sum, last
end
function M.moves(model, serverNow)
	local sum, last = M.movesAngles(model, serverNow)
	if not sum then return nil, nil end
	local out = {}
	for n, v in pairs(sum) do out[n] = rot3(v[1], v[2], v[3]) end
	return out, last
end

-- v1.2: Banking Glide
local banks = setmetatable({}, {__mode = "k"})
function M.bank(model, hrp, dt, gw, isOwner)
	local st = banks[model]
	if not st then st = {w = 0} banks[model] = st end
	local look = hrp.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	if st.yaw and dt > 1e-4 then
		local d = yaw - st.yaw
		if d > math.pi then d -= 2 * math.pi elseif d < -math.pi then d += 2 * math.pi end
		st.w += (d / dt - st.w) * math.min(1, dt / 0.15)
	end
	st.yaw = yaw
	if model:GetAttribute("GlideBankEnabled") == false or gw <= 0 then
		if isOwner then model:SetAttribute("GlideBankRoll", 0) end
		return nil
	end
	local gain = tonumber(model:GetAttribute("GlideBankGain")) or 0.35
	local mx = tonumber(model:GetAttribute("GlideBankMax")) or 26
	local roll = clamp(math.deg(st.w) * gain, -mx, mx) * gw * M.BANK_SIGN
	if isOwner then model:SetAttribute("GlideBankRoll", math.floor(roll * 10 + 0.5) / 10) end
	return rot3(0, 0, roll)
end
M.BANK_SIGN = 1

-- v1.2: corkscrew drop
local screws = setmetatable({}, {__mode = "k"})
function M.corkscrew(model, isOwner, phase, kind, u)
	if model:GetAttribute("GlideCorkscrewEnabled") == false then return nil end
	if phase ~= "dash" or kind ~= "dive" then screws[model] = nil return nil end
	local key = isOwner and model:GetAttribute("SlashPredictedAt") or model:GetAttribute("SlashStartedAt")
	local m = screws[model]
	if not m or m.key ~= key then
		local glide
		if isOwner then
			local cs = model:GetAttribute("ClimbLocalState")
			glide = (model:GetAttribute("GlideLocal") == true or model:GetAttribute("GlideLocalReason") == "slash")
				and cs ~= "climbing" and cs ~= "clinging" and cs ~= "top"
		else
			glide = model:GetAttribute("SlashGlideDive") == true
		end
		m = {key = key, glide = glide}
		screws[model] = m
		if glide then model:SetAttribute("GlideCorkscrews", (model:GetAttribute("GlideCorkscrews") or 0) + 1) end
	end
	if not m.glide then return nil end
	local p = lerpP({}, STOOP, smooth(u / 0.6))
	p.RootJoint = p.RootJoint or {0, 0, 0}
	p.RootJoint[3] += 360 * smooth(u)
	local out = {}
	for n, v in pairs(p) do out[n] = rot3(v[1], v[2], v[3]) end
	return out
end

return M
