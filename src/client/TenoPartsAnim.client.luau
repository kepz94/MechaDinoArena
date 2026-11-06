-- TenoPartsAnim v1.0 (Mecha Dino Arena) — makes the machinery on the Tenontosaurus' redesigned mecha parts move (every
-- client, every teno). MDA-275, plan docs/plans/TENO_PARTS_LOOKS_v2.0.md Task 3; looks TenoPartsServer 1.3 + TenoPartsLooksV2
-- 1.0 (Kepu 2026-11-05 16:48 picks), motions as in docs/mockups/teno_parts_redesign.html v0.2. Built from TheriPartsAnim 1.0's
-- loop (that script is not edited).
-- What moves: every Weld "TPartJoint_<group>" inside a "TPart_<id>" model whose TPartLooks is "v2". Its C0 is set here each
--   RenderStepped: C0 = rest x motion, rest = attribute TPartRestC0 with its position x (model scale / TPartBuiltScale), motion
--   by TPartType about TPartAxis (pivot frame): "spin" = TPartAmt rad/s x u (+ an idle speed, below; the angle is kept);
--   "swing" = TPartAmt degrees x u; "slide" = TPartAmt x scale x u along the axis; "aim" (the leg rams) = the pivot's Y turned
--   every frame toward the TPartAimAnchor part's TPartAimPoint (x scale), so the rams telescope with the legs.
-- Driven by the stamps TenoMovesServer already sets (server time); a stamp older than the model's TPartBuiltAt is ignored:
--   tgrab   TenoGrabStartedAt: pincers open over 0.25 s; at TenoGrabCatchAt (newer than the start) they snap shut (u = -0.2,
--           past the 8-degree rest) in 0.08 s and stay shut; at TenoGrabThrowAtPlan (else TenoGrabThrowAt) they open over
--           0.1 s and are back at rest 0.5 s later. No catch by start + 1.0: back to rest over 0.2 s.
--   tmortar TenoMortarStartedAt: the barrel lifts over 0.3 s; the 4 "charge" rings light one by one across start -> the shot
--           (TenoMortarFiredAt, else start + 0.55); at the shot: "kick" slides back (0.05 s out, 0.2 s in), the "flash" film
--           fades over 0.2 s, the rings go dark; the barrel lowers over 0.4 s from shot + 0.4.
--   tstomp  TenoStompStartedAt: the wrist rings spin up over 0.5 s (idle 0.8 rad/s, 13 rad/s at full); at TenoStompAt (else
--           start + 0.5): the forearm rams punch (0.15 s), the "puff" films over the stacks grow x3 and fade over 0.3 s, the
--           rings spin down over 0.8 s.
--   tbellow TenoBellowStartedAt -> TenoBellowAt (else start + 0.5) + 0.8: u up over 0.15 s, down over 0.3 s. The "sac"
--           ellipsoids always breathe (mesh scale 1 + 0.04 sin 2t) and pump with u (+ 0.35 u (0.5 + 0.5 sin 6t)); their
--           opacity 0.55 + 0.25 u.
--   tchallenge TenoChallengeStartedAt -> TenoChallengeAt (else start + 0.5) + 1.0: u up over 0.2 s, down over 0.4 s; the
--           antennae stand up (swing), the "reflector" spins 1.5 + 10 u rad/s, the "dome" opacity 0.35 + 0.2 u, the
--           "flashball" film flashes (0.35 u x max(0, sin 23t)).
--   tleap   while TenoLeapUntil > now: the knee gears spin 8 rad/s (idle 0.5) and the 5 "gauge" bars flash at 6 Hz;
--           otherwise round(5 x TenoLeapChargesLeft / max(TenoLeapCharges, left, 1)) bars are lit. The rams always aim.
--   tmud    TenoMudCoatAt (newer than TenoMudEndedAt) while TenoMudUntil > now: the 10 mane blades swing forward over 0.15 s,
--           the "disc" film shows (0.3 + 0.08 sin 4t) x u and the "rim" 0.9 u; at TenoMudEndedAt (or TenoMudUntil) they fold
--           back over 0.3 s.
-- Who: every player's character, plus (Studio test hook) any workspace Model with attribute TenoPartsAnimTarget = true.
-- Switch: script attribute TenoPartsAnimEnabled (default true, read each frame; false = every joint at rest, lights off).
-- Diagnostics: script TenoPartsAnimVersion, TenoPartsAnimJoints (joints written, last frame); model TenoPartsAnimActive
--   ("<id>,..." parts moving now, this client).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
script:SetAttribute("TenoPartsAnimVersion", VERSION)
if script:GetAttribute("TenoPartsAnimEnabled") == nil then script:SetAttribute("TenoPartsAnimEnabled", true) end

local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function up(e, a) return math.clamp(e / a, 0, 1) end
local function stamp(c, k, built) -- a stamp, or nil when missing or older than the build
	local v = tonumber(c:GetAttribute(k))
	if not v or v < built then return nil end
	return v
end

-- state per part id: {u (default for every group), g = {[group name prefix] = u}, idle = {[prefix] = rad/s}, lit = {[role] = bool},
-- op = {[role] = opacity}, pulse = {[role] = scale}}
local ACT = {
	tgrab = function(c, t, built)
		local s = stamp(c, "TenoGrabStartedAt", built)
		if not s or t - s > 4 then return {u = 0} end
		local e = t - s
		local catch = stamp(c, "TenoGrabCatchAt", s)
		local throw = stamp(c, "TenoGrabThrowAtPlan", s) or stamp(c, "TenoGrabThrowAt", s)
		if catch and t >= catch then
			if throw and t >= throw then
				local k = t - throw
				if k < 0.1 then return {u = -0.2 + 1.2 * up(k, 0.1)} end
				return {u = math.max(0, 1 - up(k - 0.1, 0.5))}
			end
			return {u = 1 - 1.2 * up(t - catch, 0.08)}
		end
		if not catch and e > 1.0 then return {u = math.max(0, 1 - up(e - 1.0, 0.2))} end
		return {u = up(e, 0.25)}
	end,
	tmortar = function(c, t, built)
		local s = stamp(c, "TenoMortarStartedAt", built)
		if not s or t - s > 3 then return {u = 0, g = {kick = 0}, lit = {}} end
		local fired = stamp(c, "TenoMortarFiredAt", s)
		local shot = fired or (s + 0.55)
		local u = (t < shot + 0.4) and up(t - s, 0.3) or math.max(0, 1 - up(t - shot - 0.4, 0.4))
		local lit, kick, flash = {}, 0, 0
		if t < shot then
			local n = math.clamp(math.floor(4 * (t - s) / math.max(0.05, shot - s)) + 1, 1, 4)
			for k = 1, n do lit["charge" .. k] = true end
		elseif fired then
			local k = t - fired
			kick = k < 0.05 and up(k, 0.05) or math.max(0, 1 - up(k - 0.05, 0.2))
			flash = math.max(0, 1 - up(k, 0.2))
		end
		return {u = u, g = {kick = kick}, lit = lit, op = {flash = flash}}
	end,
	tstomp = function(c, t, built)
		local s = stamp(c, "TenoStompStartedAt", built)
		if not s or t - s > 3 then return {u = 0, g = {ram = 0}, idle = {ring = 0.8}, op = {puff = 0}} end
		local hit = stamp(c, "TenoStompAt", s) or (s + 0.5)
		if t < hit then return {u = up(t - s, 0.5), g = {ram = 0}, idle = {ring = 0.8}, op = {puff = 0}} end
		local k = t - hit
		local ram = k < 0.15 and math.sin(math.pi * k / 0.15) or 0
		local puff = k < 0.3 and 0.7 * (1 - k / 0.3) or 0
		return {u = math.max(0, 1 - up(k, 0.8)), g = {ram = ram}, idle = {ring = 0.8}, op = {puff = puff}, pulse = {puff = 1 + 2 * up(k, 0.3)}}
	end,
	tbellow = function(c, t, built)
		local s = stamp(c, "TenoBellowStartedAt", built)
		local u = 0
		if s then
			local fin = (stamp(c, "TenoBellowAt", s) or (s + 0.5)) + 0.8
			u = t < fin and up(t - s, 0.15) or math.max(0, 1 - up(t - fin, 0.3))
		end
		local f = 1 + 0.04 * math.sin(2 * t) + 0.35 * u * (0.5 + 0.5 * math.sin(6 * t))
		return {u = u, pulse = {sac = f}, op = {sac = 0.55 + 0.25 * u}}
	end,
	tchallenge = function(c, t, built)
		local s = stamp(c, "TenoChallengeStartedAt", built)
		local u = 0
		if s then
			local fin = (stamp(c, "TenoChallengeAt", s) or (s + 0.5)) + 1.0
			u = t < fin and up(t - s, 0.2) or math.max(0, 1 - up(t - fin, 0.4))
		end
		return {u = u, g = {reflector = u}, idle = {reflector = 1.5}, op = {dome = 0.35 + 0.2 * u, flashball = 0.35 * u * math.max(0, math.sin(23 * t))}}
	end,
	tleap = function(c, t)
		local air = num(c, "TenoLeapUntil", 0) > t
		local lit = {}
		if air then
			if math.floor(t * 12) % 2 == 0 then for k = 1, 5 do lit["gauge" .. k] = true end end
		else
			local left = math.max(0, num(c, "TenoLeapChargesLeft", 0))
			local n = math.floor(5 * left / math.max(num(c, "TenoLeapCharges", 1), left, 1) + 0.5)
			for k = 1, n do lit["gauge" .. k] = true end
		end
		return {u = air and 1 or 0, idle = {gear = 0.5}, lit = lit}
	end,
	tmud = function(c, t, built)
		local coat = stamp(c, "TenoMudCoatAt", built)
		if not coat then return {u = 0, op = {disc = 0, rim = 0}} end
		local ended = stamp(c, "TenoMudEndedAt", coat)
		local untilT = num(c, "TenoMudUntil", coat)
		local stop = ended or untilT
		local u = t < stop and up(t - coat, 0.15) or math.max(0, 1 - up(t - stop, 0.3))
		return {u = u, op = {disc = (0.3 + 0.08 * math.sin(4 * t)) * u, rim = 0.9 * u}}
	end,
}

local AXIS = {X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis}
local function rotAbout(axis, a)
	if axis == "X" then return CFrame.Angles(a, 0, 0) elseif axis == "Y" then return CFrame.Angles(0, a, 0) end
	return CFrame.Angles(0, 0, a)
end
local function prefix(name) return (name:match("^(.-)_[LR%d]+$") or name) end -- "ring_L" -> "ring", "blade_3" -> "blade"

-- tracked models: [model] = {parts = {[TPart model] = info}} (plain table; a model leaves 5 s after it is unparented)
local tracked = {}
local function scanPart(tm, model)
	local info = {joints = {}, pieces = {}, id = tm:GetAttribute("TPartId"), built = num(tm, "TPartBuiltAt", 0)}
	for _, d in ipairs(tm:GetDescendants()) do
		if d:IsA("Weld") and d.Name:sub(1, 11) == "TPartJoint_" then
			local rest = d:GetAttribute("TPartRestC0")
			if typeof(rest) == "CFrame" then
				local name = d.Name:sub(12)
				local j = {weld = d, rest = rest, built = num(d, "TPartBuiltScale", 1), type = d:GetAttribute("TPartType"), name = name, pre = prefix(name),
					axis = d:GetAttribute("TPartAxis") or "X", amt = num(d, "TPartAmt", 0), angle = 0}
				if j.type == "aim" then
					j.aimPart = model:FindFirstChild(d:GetAttribute("TPartAimAnchor") or "", true)
					j.aimPoint = d:GetAttribute("TPartAimPoint")
				end
				table.insert(info.joints, j)
			end
		elseif d:IsA("BasePart") then
			local role = d:GetAttribute("TPartRole")
			if role and (d:GetAttribute("TPartFilm") or d:GetAttribute("TPartHidden") or d:GetAttribute("TPartAlpha") or role == "sac" or role == "puff") then
				table.insert(info.pieces, {part = d, role = role, film = d:GetAttribute("TPartFilm") == true, hidden = d:GetAttribute("TPartHidden") == true,
					alpha = d:GetAttribute("TPartAlpha"), base = d:GetAttribute("TPartBaseSize"), mesh = d:FindFirstChildOfClass("SpecialMesh")})
			end
		end
	end
	return info
end
local function track(model)
	if tracked[model] then return end
	local st = {parts = {}}
	tracked[model] = st
	local function add(tm)
		if tm:IsA("Model") and tm.Name:sub(1, 6) == "TPart_" and tm:GetAttribute("TPartLooks") == "v2" then
			local pending = false
			local function rescan() -- again whenever more of it replicates in (streaming)
				if pending then return end
				pending = true
				task.defer(function()
					pending = false
					if tm.Parent then st.parts[tm] = scanPart(tm, model) end
				end)
			end
			rescan()
			tm.DescendantAdded:Connect(rescan)
		end
	end
	for _, ch in ipairs(model:GetChildren()) do add(ch) end
	model.ChildAdded:Connect(add)
	model.ChildRemoved:Connect(function(ch) st.parts[ch] = nil end)
	model.AncestryChanged:Connect(function()
		if model.Parent == nil then task.delay(5, function() if model.Parent == nil then tracked[model] = nil end end) end
	end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(track)
	if p.Character then track(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
local function maybeTarget(d) if d:IsA("Model") and d:GetAttribute("TenoPartsAnimTarget") == true then track(d) end end
for _, d in ipairs(workspace:GetChildren()) do maybeTarget(d) end
workspace.ChildAdded:Connect(function(d) task.defer(maybeTarget, d) end)

local REST = {u = 0}
RunService.RenderStepped:Connect(function(dt)
	local on = script:GetAttribute("TenoPartsAnimEnabled") ~= false
	local t = workspace:GetServerTimeNow()
	local driven = 0
	for model, st in pairs(tracked) do
		if model.Parent then
			local sc = model:GetScale()
			local active = {}
			for tm, info in pairs(st.parts) do
				if tm.Parent then
					local f = ACT[info.id]
					local S = (on and f) and f(model, t, info.built) or REST
					local busy = (S.u or 0) ~= 0
					if busy then table.insert(active, info.id) end
					for _, j in ipairs(info.joints) do
						local u = S.g and S.g[j.pre]
						if u == nil then u = S.u or 0 end
						local idle = on and S.idle and S.idle[j.pre] or 0
						local still = j.type ~= "aim" and u == 0 and idle == 0 and j.angle == 0 and j.rested == true and j.sc == sc
						if j.weld.Parent and not still then
							j.rested = u == 0 and idle == 0
							j.sc = sc
							local restNow = CFrame.new(j.rest.Position * (sc / j.built)) * j.rest.Rotation
							local motion = CFrame.identity
							if j.type == "spin" then
								if not on then
									j.angle = 0
								elseif u ~= 0 or idle ~= 0 then
									j.angle = (j.angle + (j.amt * u + idle * (1 - math.abs(u))) * dt) % (2 * math.pi)
								elseif j.angle ~= 0 then -- stopped: settle on to the next whole turn at 6 rad/s (exact rest)
									j.angle += 6 * dt
									if j.angle >= 2 * math.pi then j.angle = 0 end
								end
								motion = rotAbout(j.axis, j.angle)
							elseif on and j.type == "swing" then
								motion = rotAbout(j.axis, math.rad(j.amt) * u)
							elseif on and j.type == "slide" then
								motion = CFrame.new((AXIS[j.axis] or Vector3.yAxis) * j.amt * sc * u)
							end
							local p0 = j.weld.Part0
							if j.type == "aim" and on and p0 and j.aimPart and j.aimPart.Parent and typeof(j.aimPoint) == "Vector3" then
								local from = (p0.CFrame * restNow).Position
								local target = j.aimPart.CFrame * (j.aimPoint * sc)
								if (target - from).Magnitude > 1e-3 then
									j.weld.C0 = p0.CFrame:ToObjectSpace(CFrame.lookAt(from, target, p0.CFrame.RightVector) * CFrame.Angles(-math.pi / 2, 0, 0))
								end
							else
								j.weld.C0 = restNow * motion
							end
							driven += 1
						end
					end
					for _, pc in ipairs(info.pieces) do
						local p = pc.part
						if p.Parent then
							local tr
							if pc.hidden then
								tr = (on and S.lit and S.lit[pc.role]) and 0 or 1
							elseif S.op and S.op[pc.role] ~= nil then
								tr = 1 - (on and S.op[pc.role] or (pc.alpha or 0))
							elseif pc.film then
								tr = 1 - 0.35 * (S.u or 0)
							end
							if tr and p.Transparency ~= tr then p.Transparency = tr end
							local k = on and S.pulse and S.pulse[pc.role]
							if k then
								if pc.mesh then pc.mesh.Scale = Vector3.one * k
								elseif typeof(pc.base) == "Vector3" then p.Size = pc.base * (sc / num(tm, "TPartBuiltScale", sc)) * k end
							end
						end
					end
				end
			end
			local s = table.concat(active, ",")
			if model:GetAttribute("TenoPartsAnimActive") ~= s then model:SetAttribute("TenoPartsAnimActive", s) end
		end
	end
	script:SetAttribute("TenoPartsAnimJoints", driven)
end)
