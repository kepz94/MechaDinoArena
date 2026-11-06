-- HerreraPartsAnim v1.0 (Mecha Dino Arena) — makes the machinery on the Herrerasaurus' redesigned mecha parts move (every
-- client, every Herrera). MDA-289, plan docs/plans/HERRERA_PARTS_LOOKS_v2.0.md Task 3; looks HerreraPartsServer 1.4 +
-- HerreraPartsLooksV2 1.0 (Kepu 2026-11-05 19:39 picks), motions as in docs/mockups/herrera_parts_redesign.html v0.2. Built
-- from TenoPartsAnim 1.1's loop (that script is not edited).
-- What moves: every Weld "HPartJoint_<group>" inside an "HPart_<id>" model whose HPartLooks is "v2". Its C0 is set here each
--   RenderStepped: C0 = rest x motion, rest = attribute HPartRestC0 with its position x (model scale / HPartBuiltScale),
--   motion by HPartType about HPartAxis (pivot frame): "swing" = HPartAmt degrees x u; "slide" = HPartAmt x scale x u along
--   the axis; "spin" = HPartAmt rad/s x u (none on the Herrera yet). u per group: by its full name, else by its prefix
--   ("blade_L1" -> "blade"), else the part's u.
-- Driven by the stamps the move servers already set (server time); a stamp older than the model's HPartBuiltAt is ignored:
--   ironclaw SlashStartedAt: the 6 wing blades swing forward over 0.08 s, held SlashDashTime (else 0.3), back over 0.25 s.
--   glider   Gliding true: the 8 wing blades spread (wing_* yaw + droop_*) over 0.3 s and the "membrane" films fade in to
--            0.55; Gliding false: fold over 0.3 s (the change time is taken on this client).
--   quills   QuillStartedAt: the pod lids open over 0.15 s, held until QuillLandedAt (else start + 1.5) + 0.1, shut over 0.3 s.
--   smoke    SmokeStartedAt -> SmokeUntil (else start + 4): the 4 fins fan open over 0.25 s, close over 0.4 s.
--   plating  PlatingHitAt: row_k (one per body segment, hips -> tail) lifts 0.05 x scale over 0.06 s from 0.04 (k - 1) s and
--            settles over 0.2 s (the ripple).
--   caltrops CaltropDroppedAt: the trap door opens over 0.1 s, held CaltropCount (else 6) x 0.035 + 0.2 s, shuts over 0.3 s.
--   goo      the "sac" ellipsoids breathe (mesh scale 1 + 0.06 sin 2t); GooFiredAt: squeeze to 0.65 in 0.06 s, refill over 0.5 s.
--   hadren   AdrenalineStartedAt: the plunger pushes in over 0.5 s, held to AdrenalineTime (else 3), back out over the rest of
--            AdrenalineCooldown (else 20; at least 1 s).
--   siphon / strobe / breaker have no moving groups (their FX use the "core" / "led" / "tip" / "band" pieces).
-- Who: every player's character, plus (Studio test hook) any workspace Model with attribute HerreraPartsAnimTarget = true.
-- Switch: script attribute HerreraPartsAnimEnabled (default true, read each frame; false = every joint at rest).
-- Diagnostics: script HerreraPartsAnimVersion, HerreraPartsAnimJoints (joints written, last frame); model
--   HerreraPartsAnimActive ("<id>,..." parts moving now, this client).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
script:SetAttribute("HerreraPartsAnimVersion", VERSION)
if script:GetAttribute("HerreraPartsAnimEnabled") == nil then script:SetAttribute("HerreraPartsAnimEnabled", true) end

local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function up(e, a) return math.clamp(e / a, 0, 1) end
local function sm(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local function stamp(c, k, built) -- a stamp, or nil when missing or older than the build
	local v = tonumber(c:GetAttribute(k))
	if not v or v < built then return nil end
	return v
end
local function pulse(e, rise, hold, fall) -- 0 -> 1 over rise, held, 1 -> 0 over fall
	if e < 0 then return 0 end
	if e < rise then return up(e, rise) end
	if e < rise + hold then return 1 end
	return math.max(0, 1 - up(e - rise - hold, fall))
end

-- state per part id: {u (default for every group), g = {[group name or prefix] = u}, op = {[role] = opacity}, pulse = {[role] = scale}}
-- mem = this model's own table (the glider's change time)
local ACT = {
	ironclaw = function(c, t, built)
		local s = stamp(c, "SlashStartedAt", built)
		if not s or t - s > 3 then return {u = 0} end
		return {u = pulse(t - s, 0.08, num(c, "SlashDashTime", 0.3), 0.25)}
	end,
	glider = function(c, t, built, mem)
		local on = c:GetAttribute("Gliding") == true
		if mem.glide ~= on then mem.glide, mem.glideAt = on, (mem.glide == nil and -1e9 or t) end
		local k = up(t - mem.glideAt, 0.3)
		local u = on and k or (1 - k)
		u = u * u * (3 - 2 * u)
		return {u = u, op = {membrane = 0.55 * u}}
	end,
	quills = function(c, t, built)
		local s = stamp(c, "QuillStartedAt", built)
		if not s or t - s > 8 then return {u = 0} end
		local landed = stamp(c, "QuillLandedAt", s) or (s + 1.5)
		return {u = pulse(t - s, 0.15, math.max(0, landed + 0.1 - s - 0.15), 0.3)}
	end,
	smoke = function(c, t, built)
		local s = stamp(c, "SmokeStartedAt", built)
		if not s then return {u = 0} end
		local untilT = num(c, "SmokeUntil", s + 4)
		if untilT < s then untilT = s + 4 end
		return {u = pulse(t - s, 0.25, math.max(0, untilT - s - 0.25), 0.4)}
	end,
	plating = function(c, t, built)
		local s = stamp(c, "PlatingHitAt", built)
		if not s or t - s > 2 then return {u = 0} end
		local g = {}
		for k = 1, 6 do g["row_" .. k] = pulse(t - s - 0.04 * (k - 1), 0.06, 0, 0.2) end
		return {u = pulse(t - s, 0.06, 0.2, 0.2), g = g}
	end,
	caltrops = function(c, t, built)
		local s = stamp(c, "CaltropDroppedAt", built)
		if not s or t - s > 4 then return {u = 0} end
		return {u = pulse(t - s, 0.1, num(c, "CaltropCount", 6) * 0.035 + 0.2, 0.3)}
	end,
	goo = function(c, t, built)
		local f = 1 + 0.06 * math.sin(2 * t)
		local s = stamp(c, "GooFiredAt", built)
		local u = 0
		if s then
			local e = t - s
			if e >= 0 and e < 0.06 then f *= 1 - 0.35 * up(e, 0.06)
			elseif e >= 0.06 and e < 0.56 then f *= 0.65 + 0.35 * sm((e - 0.06) / 0.5) end
			if e >= 0 and e < 0.56 then u = 1 end
		end
		return {u = u, pulse = {sac = f}}
	end,
	hadren = function(c, t, built)
		local s = stamp(c, "AdrenalineStartedAt", built)
		if not s then return {u = 0} end
		local T, CD = num(c, "AdrenalineTime", 3), num(c, "AdrenalineCooldown", 20)
		return {u = pulse(t - s, 0.5, math.max(0, T - 0.5), math.max(1, CD - T))}
	end,
}

local AXIS = {X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis}
local function rotAbout(axis, a)
	if axis == "X" then return CFrame.Angles(a, 0, 0) elseif axis == "Y" then return CFrame.Angles(0, a, 0) end
	return CFrame.Angles(0, 0, a)
end
local function prefix(name) return (name:match("^(.-)_[LR%d]+$") or name) end -- "ring_L" -> "ring", "blade_3" -> "blade"

-- tracked models: [model] = {parts = {[HPart model] = info}} (plain table; a model leaves 5 s after it is unparented)
local tracked = {}
local function scanPart(tm, model)
	local info = {joints = {}, pieces = {}, id = tm:GetAttribute("HPartId"), built = num(tm, "HPartBuiltAt", 0)}
	for _, d in ipairs(tm:GetDescendants()) do
		if d:IsA("Weld") and d.Name:sub(1, 11) == "HPartJoint_" then
			local rest = d:GetAttribute("HPartRestC0")
			if typeof(rest) == "CFrame" then
				local name = d.Name:sub(12)
				local j = {weld = d, rest = rest, built = num(d, "HPartBuiltScale", 1), type = d:GetAttribute("HPartType"), name = name, pre = prefix(name),
					axis = d:GetAttribute("HPartAxis") or "X", amt = num(d, "HPartAmt", 0), angle = 0}
				if j.type == "aim" then
					j.aimPart = model:FindFirstChild(d:GetAttribute("HPartAimAnchor") or "", true)
					j.aimPoint = d:GetAttribute("HPartAimPoint")
				end
				table.insert(info.joints, j)
			end
		elseif d:IsA("BasePart") then
			local role = d:GetAttribute("HPartRole")
			if role and (d:GetAttribute("HPartFilm") or d:GetAttribute("HPartHidden") or d:GetAttribute("HPartAlpha") or role == "sac" or role == "puff") then
				table.insert(info.pieces, {part = d, role = role, film = d:GetAttribute("HPartFilm") == true, hidden = d:GetAttribute("HPartHidden") == true,
					alpha = d:GetAttribute("HPartAlpha"), base = d:GetAttribute("HPartBaseSize"), mesh = d:FindFirstChildOfClass("SpecialMesh")})
			end
		end
	end
	return info
end
local function track(model)
	if tracked[model] then return end
	local st = {parts = {}, mem = {}}
	tracked[model] = st
	local function add(tm)
		if tm:IsA("Model") and tm.Name:sub(1, 6) == "HPart_" and tm:GetAttribute("HPartLooks") == "v2" then
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
local function maybeTarget(d) if d:IsA("Model") and d:GetAttribute("HerreraPartsAnimTarget") == true then track(d) end end
for _, d in ipairs(workspace:GetChildren()) do maybeTarget(d) end
workspace.ChildAdded:Connect(function(d) task.defer(maybeTarget, d) end)

local REST = {u = 0}
RunService.RenderStepped:Connect(function(dt)
	local on = script:GetAttribute("HerreraPartsAnimEnabled") ~= false
	local t = workspace:GetServerTimeNow()
	local driven = 0
	for model, st in pairs(tracked) do
		if model.Parent then
			local sc = model:GetScale()
			local active = {}
			for tm, info in pairs(st.parts) do
				if tm.Parent then
					local f = ACT[info.id]
					local S = (on and f) and f(model, t, info.built, st.mem) or REST
					local busy = (S.u or 0) ~= 0
					if busy then table.insert(active, info.id) end
					for _, j in ipairs(info.joints) do
						local u = S.g and (S.g[j.name] or S.g[j.pre]) -- full name first (row_1..6), then the prefix
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
								elseif typeof(pc.base) == "Vector3" then p.Size = pc.base * (sc / num(tm, "HPartBuiltScale", sc)) * k end
							end
						end
					end
				end
			end
			local s = table.concat(active, ",")
			if model:GetAttribute("HerreraPartsAnimActive") ~= s then model:SetAttribute("HerreraPartsAnimActive", s) end
		end
	end
	script:SetAttribute("HerreraPartsAnimJoints", driven)
end)
