-- SlashPose v1.2 (Mecha Dino Arena) — the Herrerasaurus' dash-through slash pose (SlashTest 1.2 / SlashServer 1.2), as
-- per-joint offsets multiplied onto the current pose (IdleAnimation 1.33). MDA-142, plan docs/plans/HERRERA_KIT_v1.0.md
-- Task 10, mockup docs/mockups/herrera_kit_options.html (Kepu 2026-10-30 dash look "A"); the numbers are the mockup's
-- swipe() / dive() offsets.
-- Joint frames: rig 1.3 joint pose = restC0 * pose; pitch = about Z (+ lifts the front / swings a limb forward), yaw =
--   about Y, roll = about X; rotation = CFrame.fromEulerAngles(roll, yaw, pitch, Enum.RotationOrder.ZYX) (ScurryPose 1.0).
-- Kinds:
--   ground  u = 0..1 over the dash: swipe weight k = sin(pi x (u - 0.2) / 0.6) for 0.2 < u < 0.8, else 0:
--           ArmL pitch +60k / roll -20k, ArmR pitch -40k / roll +20k, Jaw -18k (one claw rakes forward, the other back).
--   dive    (dive with a target, or the leap off a tree) arms thrown forward, legs trailing, jaw open: d = min(1, 3u):
--           ArmL / ArmR pitch +50d, LegL / LegR pitch -40d, Jaw -20d; the body pitches nose-down
--           RootJoint -35 x sin(pi x min(1, 1.3u)); the swipe on top over the last quarter (k = 4 x (u - 0.75)).
--   fade    FADE s after the dash: the dash-end offsets (u = 1) scaled by 1 - smoothstep.
-- phase(model, isOwner, serverNow) -> phase ("dash" / "fade" / nil), kind ("ground" / "dive"), u (0..1), source:
--   owner client: SlashLocalState / SlashLocalKind / SlashPredictedAt / SlashLocalEndAt (SlashTest); the dash time is
--     the server's SlashDashTime once SlashStartedAt for this dash has arrived, else SlashTime.
--   other clients: SlashStartedAt / SlashDashTime / SlashKind (+ SlashDiveTarget: "dive" kind either way).
-- Switch: model attribute SlashPoseEnabled (default true; false = no slash pose).
-- v1.1 (Herrera Iron Claw, MDA-149, plan docs/plans/HERRERA_PARTS_v1.0.md Part 1 "bigger rake"): phase(model, ...) also
--   notes the model's rake size: IronClawPoseMul (model attribute, default 1.35) while its IronClawEnabled is true, else 1;
--   the next get() multiplies the swipe offsets (the arms' rake and the jaw) by it (the dive's arm / leg / body offsets are
--   unchanged). IdleAnimation calls phase() then get() for one model at a time, so the value belongs to that model.
--   Switch: model attribute SlashPoseIronClawEnabled (default true; false = 1.0).
-- v1.2 (plan docs/plans/HERRERA_MOVES_ANIM_v1.0.md Task 3, MDA-293; Kepu 2026-11-05 picked "A · Cross Rake", red-team
--   "others see the dash only"): while the model attribute SlashPoseCrossRakeEnabled is not false (read in phase()):
--   * phase "coil" (owner only: SlashLocalState "coil" from SlashTest 1.6, u = (now - SlashLocalCoilAt) /
--     SlashLocalCoilTime): COCK x smoothstep(u) (the body drops, both arms pull back, the jaw opens a little);
--   * ground dash: COCK -> RAKE_X by u 0.65 (ease out) and held (both arms cross forward, a lunge);
--   * fade: RAKE_X x (1 - smoothstep) over FADE_X (0.65 s) instead of FADE (0.2 s), owner and others;
--   * the arms' pitch / roll and the jaw x the Iron Claw rake size (1.1). The dive kind is unchanged.
--   Others see the dash from SlashStartedAt (the coil happens before the request). Diagnostic (via IdleAnimation):
--   SlashPoseState "coil".
local SlashPose = {}
SlashPose.Version = "1.1"
SlashPose.Version = "1.2" -- v1.2 Cross Rake
local rakeMul = 1 -- v1.1: set by phase(), used by the next get()
SlashPose.Defaults = {SlashEnabled = false, SlashTime = 0.3, SlashPoseEnabled = true}
SlashPose.FADE = 0.2

local rad, sin, pi = math.rad, math.sin, math.pi
local function smoothstep(x) x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end
local function rot(p, y, r) return CFrame.fromEulerAngles(rad(r), rad(y), rad(p), Enum.RotationOrder.ZYX) end

function SlashPose.settings(model)
	local s = {}
	for k, v in pairs(SlashPose.Defaults) do
		local a = model:GetAttribute(k)
		if a == nil then a = v end
		s[k] = a
	end
	return s
end

-- v1.2: Cross Rake
local crossOn = false -- set by phase(), used by the next get()
local FADE_X = 0.65
local COCK = {RootJoint = {-10, 0, 0}, LegL = {28, 0, 0}, LegR = {28, 0, 0}, KneeL = {-40, 0, 0}, KneeR = {-40, 0, 0},
	AnkleL = {12, 0, 0}, AnkleR = {12, 0, 0}, Neck = {-6, 0, 0}, Head = {6, 0, 0}, ArmL = {-45, 0, -10}, ArmR = {-45, 0, 10},
	Jaw = {-10, 0, 0}, Tail1 = {-6, 0, 0}}
local RAKE_X = {RootJoint = {-18, 0, 0}, ArmL = {75, 0, -22}, ArmR = {75, 0, 22}, Neck = {-10, 0, 0}, Head = {10, 0, 0},
	Jaw = {-26, 0, 0}, LegL = {-18, 0, 0}, LegR = {24, 0, 0}, KneeR = {-20, 0, 0}, Tail1 = {-8, 0, 0}}
local function blendX(a, b, k)
	local o = {}
	for n, v in pairs(a) do o[n] = {v[1] * (1 - k), v[2] * (1 - k), v[3] * (1 - k)} end
	for n, v in pairs(b) do
		local w = o[n] or {0, 0, 0}
		o[n] = {w[1] + v[1] * k, w[2] + v[2] * k, w[3] + v[3] * k}
	end
	return o
end
local function crossAngles(phase, u)
	local a
	if phase == "coil" then
		a = blendX(COCK, {}, 1 - smoothstep(u))
	elseif phase == "fade" then
		a = blendX(RAKE_X, {}, smoothstep(u))
	else
		local k = math.clamp(u / 0.65, 0, 1)
		a = blendX(COCK, RAKE_X, 1 - (1 - k) * (1 - k))
	end
	for _, n in ipairs({"ArmL", "ArmR", "Jaw"}) do
		local v = a[n]
		if v then v[1], v[3] = v[1] * rakeMul, v[3] * rakeMul end
	end
	return a
end
SlashPose.crossAngles = crossAngles

local phase11
function SlashPose.phase(model, isOwner, serverNow)
	crossOn = model:GetAttribute("SlashPoseCrossRakeEnabled") ~= false
	if not crossOn then return phase11(model, isOwner, serverNow) end
	if isOwner and model:GetAttribute("SlashLocalState") == "coil" and model:GetAttribute("SlashEnabled") == true
		and model:GetAttribute("SlashPoseEnabled") ~= false then
		rakeMul = 1
		if model:GetAttribute("IronClawEnabled") == true and model:GetAttribute("SlashPoseIronClawEnabled") ~= false then
			rakeMul = tonumber(model:GetAttribute("IronClawPoseMul")) or 1.35
		end
		local at = tonumber(model:GetAttribute("SlashLocalCoilAt")) or serverNow
		local ct = math.max(0.02, tonumber(model:GetAttribute("SlashLocalCoilTime")) or 0.15)
		return "coil", "ground", math.clamp((serverNow - at) / ct, 0, 1), "local"
	end
	local keep = SlashPose.FADE
	SlashPose.FADE = FADE_X -- the 1.1 phase reads it at the call
	local a, b, c, d = phase11(model, isOwner, serverNow)
	SlashPose.FADE = keep
	if a ~= nil and b ~= "ground" then -- the dive keeps the 1.1 fade length
		if a == "fade" and c * FADE_X >= keep then return nil, b, 0, d end
		if a == "fade" then c = c * FADE_X / keep end
	end
	return a, b, c, d
end

phase11 = function(model, isOwner, serverNow)
	rakeMul = 1 -- v1.1
	if model:GetAttribute("IronClawEnabled") == true and model:GetAttribute("SlashPoseIronClawEnabled") ~= false then
		rakeMul = tonumber(model:GetAttribute("IronClawPoseMul")) or 1.35
	end
	local s = SlashPose.settings(model)
	if s.SlashEnabled ~= true or s.SlashPoseEnabled == false then return nil, "ground", 0, "none" end
	local T = math.max(0.05, tonumber(s.SlashTime) or 0.3)
	if isOwner then
		local st = model:GetAttribute("SlashLocalState")
		local start = model:GetAttribute("SlashPredictedAt")
		local kind = model:GetAttribute("SlashLocalKind") == "ground" and "ground" or "dive"
		if typeof(start) ~= "number" then return nil, kind, 0, "local" end
		local dur = T
		local sStart, sDur = model:GetAttribute("SlashStartedAt"), model:GetAttribute("SlashDashTime")
		if typeof(sStart) == "number" and typeof(sDur) == "number" and sStart >= start - 0.5 then dur = math.max(0.05, sDur) end
		if st == "dash" then
			return "dash", kind, math.clamp((serverNow - start) / dur, 0, 1), "local"
		end
		local endAt = model:GetAttribute("SlashLocalEndAt")
		if typeof(endAt) == "number" and endAt >= start and serverNow - endAt < SlashPose.FADE then
			return "fade", kind, (serverNow - endAt) / SlashPose.FADE, "local"
		end
		return nil, kind, 0, "local"
	end
	local start = model:GetAttribute("SlashStartedAt")
	if typeof(start) ~= "number" then return nil, "ground", 0, "server" end
	local kind = model:GetAttribute("SlashKind") == "dive" and "dive" or "ground"
	local dur = math.max(0.05, tonumber(model:GetAttribute("SlashDashTime")) or T)
	local t = serverNow - start
	if t >= 0 and t < dur then return "dash", kind, t / dur, "server" end
	if t >= dur and t < dur + SlashPose.FADE then return "fade", kind, (t - dur) / SlashPose.FADE, "server" end
	return nil, kind, 0, "server"
end

-- the offsets at u for a kind, as {joint = {pitch, yaw, roll}}
local function angles(kind, u)
	local a = {ArmL = {0, 0, 0}, ArmR = {0, 0, 0}, Jaw = {0, 0, 0}, LegL = {0, 0, 0}, LegR = {0, 0, 0}, RootJoint = {0, 0, 0}}
	local k
	if kind == "dive" then
		local d = math.min(1, 3 * u)
		a.ArmL[1] += 50 * d
		a.ArmR[1] += 50 * d
		a.LegL[1] -= 40 * d
		a.LegR[1] -= 40 * d
		a.Jaw[1] -= 20 * d
		a.RootJoint[1] = -35 * sin(pi * math.min(1, 1.3 * u))
		k = u > 0.75 and math.min(1, 4 * (u - 0.75)) or 0
	else
		k = (u > 0.2 and u < 0.8) and sin(pi * (u - 0.2) / 0.6) or 0
	end
	k *= rakeMul -- v1.1: Iron Claw's bigger rake
	a.ArmL[1] += 60 * k
	a.ArmL[3] -= 20 * k
	a.ArmR[1] -= 40 * k
	a.ArmR[3] += 20 * k
	a.Jaw[1] -= 18 * k
	return a
end
SlashPose.angles = angles

-- phase / kind / u from SlashPose.phase; returns {[joint] = CFrame offset}
function SlashPose.get(phase, kind, u)
	local a, w
	if crossOn and (phase == "coil" or kind == "ground") then -- v1.2
		a, w = crossAngles(phase, u), 1
	elseif phase == "fade" then
		a, w = angles(kind, 1), 1 - smoothstep(u)
	else
		a, w = angles(kind, u), 1
	end
	local out = {}
	for name, v in pairs(a) do out[name] = rot(v[1] * w, v[2] * w, v[3] * w) end
	return out
end

return SlashPose
