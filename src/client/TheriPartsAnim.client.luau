-- TheriPartsAnim v1.0 (Mecha Dino Arena) — makes the machinery on the Therizinosaurus' redesigned mecha parts move (every
-- client, every therizino). MDA-251, plan docs/plans/THERIZINO_PARTS_LOOKS_v2.0.md Task 3; looks TheriPartsServer 1.1 +
-- TheriPartsLooksV2 1.1 (Kepu 2026-11-04 14:49 picks), motions as in docs/mockups/therizino_parts_redesign.html v0.5.
-- What moves: every Weld "ZPartJoint_<group>" inside a "ZPart_<id>" model (TheriPartsServer 1.1). Its C0 is set here each
--   RenderStepped: C0 = rest x motion, where rest = attribute ZPartRestC0 with its position x (model scale / ZPartBuiltScale)
--   (so a GrowthServer ScaleTo is followed), and motion by the weld's ZPartType about ZPartAxis (in the pivot's frame):
--   "spin" = turning at ZPartAmt rad/s x u (the angle is kept when it stops; gear_* groups idle at 0.3 rad/s);
--   "swing" = ZPartAmt degrees x u; "slide" = ZPartAmt studs x scale x u along the axis.
-- u (0..1) per part, from the stamps the move servers already set (server time):
--   zhook   TheriHookAt (with a TheriHookResult): up over 0.15 s, held to out + 0.2, down over 0.3 s, where out = 0.15 +
--           TheriHookPullTime on "hit", else 0.15 + 0.25 (the chain's time in TheriMovesFX); while the chain is out the
--           "hookhead" pieces are hidden (TheriMovesFX 1.2 draws the claw at the chain's tip).
--   zfeather TheriFeatherAt: up over 0.12 s, held to 0.6, down by 1.0; the blades quiver while open (x 0.75 + 0.25 sin 6t).
--   zgrapple TheriGrappleAt with result "zip": up over 0.12 s, held to TheriGrappleTime + 0.2, down over 0.2 s.
--   zdeflect TheriDeflectAt .. TheriDeflectUntil: up over 0.15 s, down over 0.3 s after the end.
--   zclock  TheriClockAt .. TheriClockUntil: up over 0.2 s, down over 0.3 s.
--   zsnare  TheriSnareAt: up over 0.1 s, held to 0.6, down by 0.8.
--   zharvest has no moving groups.
-- Film pieces (ZPartFilm, the shield disc) are shown see-through (Transparency 1 - 0.65 x u).
-- Who: every player's character, plus (Studio test hook) any workspace Model with attribute TheriPartsAnimTarget = true.
-- Switch: script attribute TheriPartsAnimEnabled (default true, read each frame; false = every joint back at rest).
-- Diagnostics: script TheriPartsAnimVersion, TheriPartsAnimJoints (joints driven, last frame); model TheriPartsAnimActive
--   ("<id>,..." parts moving now, this client).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
script:SetAttribute("TheriPartsAnimVersion", VERSION)
if script:GetAttribute("TheriPartsAnimEnabled") == nil then script:SetAttribute("TheriPartsAnimEnabled", true) end

local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function up(e, a) return math.clamp(e / a, 0, 1) end

-- u per part id (c = the character / model, t = server time); second return for zhook: hide the hook head
local ACT = {
	zhook = function(c, t)
		if c:GetAttribute("TheriHookResult") == nil then return 0 end
		local e = t - num(c, "TheriHookAt", -1e9)
		local pull = math.max(0, num(c, "TheriHookPullTime", 0))
		-- the chain is out as long as TheriMovesFX 1.1 draws it: 0.15 s out, then the pull ("hit") or a 0.25 s fall back
		local out = 0.15 + (c:GetAttribute("TheriHookResult") == "hit" and pull or 0.25)
		local hold = out + 0.2
		if e < 0 or e > hold + 0.3 then return 0, false end
		local hide = e < out
		if e < 0.15 then return up(e, 0.15), hide end
		if e < hold then return 1, hide end
		return 1 - up(e - hold, 0.3), false
	end,
	zfeather = function(c, t)
		local e = t - num(c, "TheriFeatherAt", -1e9)
		if e < 0 or e > 1 then return 0 end
		if e < 0.12 then return up(e, 0.12) end
		if e < 0.6 then return 1 end
		return 1 - up(e - 0.6, 0.4)
	end,
	zgrapple = function(c, t)
		if c:GetAttribute("TheriGrappleResult") ~= "zip" then return 0 end
		local e = t - num(c, "TheriGrappleAt", -1e9)
		local zt = math.max(0, num(c, "TheriGrappleTime", 0.5))
		if e < 0 or e > zt + 0.4 then return 0 end
		if e < 0.12 then return up(e, 0.12) end
		if e < zt + 0.2 then return 1 end
		return 1 - up(e - zt - 0.2, 0.2)
	end,
	zdeflect = function(c, t)
		local e = t - num(c, "TheriDeflectAt", -1e9)
		local un = num(c, "TheriDeflectUntil", -1e9)
		if e < 0 then return 0 end
		if t < un then return up(e, 0.15) end
		return math.max(0, 1 - up(t - un, 0.3))
	end,
	zclock = function(c, t)
		local e = t - num(c, "TheriClockAt", -1e9)
		local un = num(c, "TheriClockUntil", -1e9)
		if e < 0 then return 0 end
		if t < un then return up(e, 0.2) end
		return math.max(0, 1 - up(t - un, 0.3))
	end,
	zsnare = function(c, t)
		local e = t - num(c, "TheriSnareAt", -1e9)
		if e < 0 or e > 0.8 then return 0 end
		if e < 0.1 then return up(e, 0.1) end
		if e < 0.6 then return 1 end
		return 1 - up(e - 0.6, 0.2)
	end,
}

local AXIS = {X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis}
local function rotAbout(axis, a)
	if axis == "X" then return CFrame.Angles(a, 0, 0) elseif axis == "Y" then return CFrame.Angles(0, a, 0) end
	return CFrame.Angles(0, 0, a)
end

-- tracked models: [model] = {parts = {[ZPart model] = {joints = {...}, heads = {...}, films = {...}}}}
local tracked = setmetatable({}, {__mode = "k"})
local function scanPart(zm)
	local info = {joints = {}, heads = {}, films = {}, id = zm:GetAttribute("ZPartId")}
	for _, d in ipairs(zm:GetDescendants()) do
		if d:IsA("Weld") and d.Name:sub(1, 11) == "ZPartJoint_" then
			local rest = d:GetAttribute("ZPartRestC0")
			if typeof(rest) == "CFrame" then
				table.insert(info.joints, {weld = d, rest = rest, built = num(d, "ZPartBuiltScale", 1), type = d:GetAttribute("ZPartType"),
					axis = d:GetAttribute("ZPartAxis") or "X", amt = num(d, "ZPartAmt", 0), angle = 0,
					idle = d.Name:sub(12, 16) == "gear_"})
			end
		elseif d:IsA("BasePart") then
			if d:GetAttribute("ZPartRole") == "hookhead" then table.insert(info.heads, d) end
			if d:GetAttribute("ZPartFilm") == true then table.insert(info.films, d) end
		end
	end
	return info
end
local function track(model)
	if tracked[model] then return end
	local st = {parts = {}}
	tracked[model] = st
	local function add(zm)
		if zm:IsA("Model") and zm.Name:sub(1, 6) == "ZPart_" and zm:GetAttribute("ZPartLooks") == "v2" then
			task.defer(function() if zm.Parent then st.parts[zm] = scanPart(zm) end end)
		end
	end
	for _, ch in ipairs(model:GetChildren()) do add(ch) end
	model.ChildAdded:Connect(add)
	model.ChildRemoved:Connect(function(ch) st.parts[ch] = nil end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(track)
	if p.Character then track(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
-- Studio test hook: server-made models marked TheriPartsAnimTarget
local function maybeTarget(d) if d:IsA("Model") and d:GetAttribute("TheriPartsAnimTarget") == true then track(d) end end
for _, d in ipairs(workspace:GetChildren()) do maybeTarget(d) end
workspace.ChildAdded:Connect(function(d) task.defer(maybeTarget, d) end)

RunService.RenderStepped:Connect(function(dt)
	local on = script:GetAttribute("TheriPartsAnimEnabled") ~= false
	local t = workspace:GetServerTimeNow()
	local driven = 0
	for model, st in pairs(tracked) do
		if model.Parent then
			local sc = model:GetScale()
			local active = {}
			for zm, info in pairs(st.parts) do
				if zm.Parent then
					local f = ACT[info.id]
					local u, hide = 0, false
					if on and f then u, hide = f(model, t) end
					u = u or 0
					if u > 0 then table.insert(active, info.id) end
					for _, j in ipairs(info.joints) do
						-- only write while moving, while a gear idles, while settling, after a scale change, or once at rest
						-- (phone cost: plan red-team 1)
						local idling = on and j.idle
						local still = u <= 0 and not idling and j.angle == 0 and j.rested == true and j.sc == sc
						if j.weld.Parent and not still then
							j.rested = u <= 0 and not idling
							j.sc = sc
							local restNow = CFrame.new(j.rest.Position * (sc / j.built)) * j.rest.Rotation
							local motion = CFrame.identity
							if j.type == "spin" then
								if not on then
									j.angle = 0
								elseif u > 0 or idling then
									j.angle = (j.angle + (j.amt * u + (idling and 0.3 * (1 - u) or 0)) * dt) % (2 * math.pi)
								elseif j.angle ~= 0 then
									-- stopped: settle on, the way it was turning, to the next whole turn at 6 rad/s (exact rest)
									if j.amt >= 0 then
										j.angle += 6 * dt
										if j.angle >= 2 * math.pi then j.angle = 0 end
									else
										j.angle -= 6 * dt
										if j.angle <= 0 then j.angle = 0 end
									end
								end
								motion = rotAbout(j.axis, j.angle)
							elseif on and j.type == "swing" then
								-- the Blade Wings quiver while open, as in the mockup: u x (0.75 + 0.25 sin 6t)
								local k = info.id == "zfeather" and u * (0.75 + 0.25 * math.sin(6 * os.clock())) or u
								motion = rotAbout(j.axis, math.rad(j.amt) * k)
							elseif on and j.type == "slide" then
								motion = CFrame.new((AXIS[j.axis] or Vector3.yAxis) * j.amt * sc * u)
							end
							j.weld.C0 = restNow * motion
							driven += 1
						end
					end
					for _, h in ipairs(info.heads) do h.LocalTransparencyModifier = hide and 1 or 0 end
					for _, f2 in ipairs(info.films) do f2.Transparency = 1 - 0.65 * u end
				end
			end
			local s = table.concat(active, ",")
			if model:GetAttribute("TheriPartsAnimActive") ~= s then model:SetAttribute("TheriPartsAnimActive", s) end
		else
			tracked[model] = nil -- the character left
		end
	end
	script:SetAttribute("TheriPartsAnimJoints", driven)
end)
