-- SlashPose v1.0 (Mecha Dino Arena) — the Herrerasaurus' dash-through slash pose (SlashTest 1.2 / SlashServer 1.2), as
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
local SlashPose = {}
SlashPose.Version = "1.0"
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

function SlashPose.phase(model, isOwner, serverNow)
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
	if phase == "fade" then
		a, w = angles(kind, 1), 1 - smoothstep(u)
	else
		a, w = angles(kind, u), 1
	end
	local out = {}
	for name, v in pairs(a) do out[name] = rot(v[1] * w, v[2] * w, v[3] * w) end
	return out
end

return SlashPose
