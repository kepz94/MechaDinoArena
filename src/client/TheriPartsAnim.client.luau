-- TheriPartsAnim v1.4 (Mecha Dino Arena) — makes the machinery on the Therizinosaurus' redesigned mecha parts move (every
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
-- Film pieces (ZPartFilm, the shield disc) are shown see-through (Transparency 1 - 0.35 x u: the mockup's 0.35 opacity).
-- v1.1 (passive Overclock, Kepu 2026-11-04 "gears spin while you move", plan docs/plans/THERIZINO_GRAPPLE_CLOCK_v1.0.md,
--   MDA-258; TheriMovesServer 1.3): while the model's TheriClockPassive is true, zclock's u follows how fast it moves:
--   target = clamp(flat root speed / PASSIVE_FULL (8) studs/s, 0, 1), eased toward at PASSIVE_RATE (6) per s (gears at full
--   spin while moving, idling at 0.3 rad/s standing; fins out while moving). Switch TheriPartsAnimClockMoveEnabled (default
--   true; false = 1.0: full spin the whole time).
-- v1.2 (therizino moves rework, plan docs/plans/THERIZINO_MOVES_REWORK_v1.0.md, MDA-264; TheriMovesServer 1.4, looks
--   TheriPartsLooksV2 1.2): the newest of the old and the new stamps drives each part:
--   zhook   TheriReelAt (Reaper Launcher): up over the brace (TheriReelBrace: the prongs open in the muzzle, the chain drum
--           spins), held while the claw is out, down over 0.3 s; the "hookhead" pieces are hidden from the brace's end until the
--           claw is back (hit / missed: brace + fly + TheriReelTime + 0.5; otherwise brace + 2 x fly). TheriMovesFX2 draws it.
--   zgrapple TheriDashAt (result "dash", Storm Core): up over 0.05 s, held to TheriDashDelay + TheriDashTime + 0.25, down over
--           0.2 s (the glass film shows while it charges and jolts).
--   zsnare  TheriBolaAt: as TheriSnareAt (the spools spin while the bola winds up and flies).
--   Switch: script attribute TheriPartsAnimReworkEnabled (default true; false = 1.1).
-- v1.3 (Wing Volley, plan docs/plans/THERIZINO_FEATHER_VOLLEY_v1.0.md, MDA-266; TheriMovesServer 1.6): zfeather, when the
--   model's TheriFeatherVolley is true (and TheriPartsAnimReworkEnabled): u up over 0.3 s (the wings fan for the wind-up), held
--   to 1.3, down over 0.3 s; the wing's "blade" pieces are hidden from the release (0.42) to 1.2 s (the wings are empty while
--   TheriMovesFX2 1.1 flies the darts), unless TheriVolleyResult is "cancelled". Otherwise the 1.0 zfeather.
-- v1.4 (Deflector Shield Wall, plan docs/plans/THERIZINO_DEFLECT_CLOCK_v2.0.md, MDA-269; TheriMovesServer 1.7): while the
--   model's TheriDeflectWall is true (and TheriPartsAnimReworkEnabled) the zdeflect film pieces (the old chest disc) stay
--   hidden: TheriMovesFX2 1.2 draws the Shield Wall instead. The collar still spins and its fins flare as before.
-- Who: every player's character, plus (Studio test hook) any workspace Model with attribute TheriPartsAnimTarget = true.
-- Switch: script attribute TheriPartsAnimEnabled (default true, read each frame; false = every joint back at rest).
-- Diagnostics: script TheriPartsAnimVersion, TheriPartsAnimJoints (joints driven, last frame); model TheriPartsAnimActive
--   ("<id>,..." parts moving now, this client).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 passive Overclock legs follow movement
VERSION = "1.2" -- v1.2 moves rework stamps (reel, dash, bola)
VERSION = "1.3" -- v1.3 Wing Volley wings
VERSION = "1.4" -- v1.4 Shield Wall hides the old disc
local PASSIVE_FULL, PASSIVE_RATE = 8, 6
if script:GetAttribute("TheriPartsAnimClockMoveEnabled") == nil then script:SetAttribute("TheriPartsAnimClockMoveEnabled", true) end
local clockEase = setmetatable({}, {__mode = "k"}) -- [model] = {u, at} (losing it only resets the easing)
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
		if c:GetAttribute("TheriClockPassive") == true and script:GetAttribute("TheriPartsAnimClockMoveEnabled") ~= false then -- v1.1
			local r = c:FindFirstChild("HumanoidRootPart")
			local v = r and r.AssemblyLinearVelocity or Vector3.zero
			local target = math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / PASSIVE_FULL, 0, 1)
			local st = clockEase[c] or {u = 0, at = os.clock()}
			clockEase[c] = st
			local dt = math.min(0.1, os.clock() - st.at)
			st.at = os.clock()
			st.u += (target - st.u) * math.min(1, PASSIVE_RATE * dt)
			if st.u < 0.01 then st.u = 0 end
			return st.u
		end
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

-- v1.2: the moves rework stamps (see the header) --------------------------------------------------------------------------
if script:GetAttribute("TheriPartsAnimReworkEnabled") == nil then script:SetAttribute("TheriPartsAnimReworkEnabled", true) end
do
	local function rw() return script:GetAttribute("TheriPartsAnimReworkEnabled") ~= false end
	local hookV11, grappleV11, snareV11 = ACT.zhook, ACT.zgrapple, ACT.zsnare
	ACT.zhook = function(c, t)
		local at = num(c, "TheriReelAt", -1e9)
		if not rw() or at < num(c, "TheriHookAt", -1e9) then return hookV11(c, t) end
		local e = t - at
		local brace, fly = math.max(0.05, num(c, "TheriReelBrace", 0.3)), math.max(0, num(c, "TheriReelFly", 0.2))
		local res = c:GetAttribute("TheriReelResult")
		local back = (res == "hit" or res == "missed") and (brace + fly + math.max(0, num(c, "TheriReelTime", 0.5)) + 0.5) or (brace + 2 * fly)
		if e < 0 or e > back + 0.3 then return 0, false end
		local hide = e >= brace and e < back
		if e < brace then return up(e, brace), false end
		if e < back then return 1, hide end
		return 1 - up(e - back, 0.3), false
	end
	ACT.zgrapple = function(c, t)
		local at = num(c, "TheriDashAt", -1e9)
		if not rw() or at < num(c, "TheriGrappleAt", -1e9) or c:GetAttribute("TheriDashResult") ~= "dash" then return grappleV11(c, t) end
		local e = t - at
		local hold = math.max(0, num(c, "TheriDashDelay", 0.16)) + math.max(0, num(c, "TheriDashTime", 0.12)) + 0.25
		if e < 0 or e > hold + 0.2 then return 0 end
		if e < 0.05 then return up(e, 0.05) end
		if e < hold then return 1 end
		return 1 - up(e - hold, 0.2)
	end
	ACT.zsnare = function(c, t)
		local at = num(c, "TheriBolaAt", -1e9)
		if not rw() or at < num(c, "TheriSnareAt", -1e9) then return snareV11(c, t) end
		local e = t - at
		if e < 0 or e > 1.2 then return 0 end
		if e < 0.1 then return up(e, 0.1) end
		if e < 1.0 then return 1 end
		return 1 - up(e - 1.0, 0.2)
	end
	local featherV10 = ACT.zfeather -- v1.3: the Wing Volley
	ACT.zfeather = function(c, t)
		if not rw() or c:GetAttribute("TheriFeatherVolley") ~= true then return featherV10(c, t) end
		local e = t - num(c, "TheriFeatherAt", -1e9)
		if e < 0 or e > 1.6 then return 0, false end
		local hide = c:GetAttribute("TheriVolleyResult") ~= "cancelled" and e >= 0.42 and e < 1.2
		if e < 0.3 then return up(e, 0.3), false end
		if e < 1.3 then return 1, hide end
		return 1 - up(e - 1.3, 0.3), false
	end
end

local AXIS = {X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis}
local function rotAbout(axis, a)
	if axis == "X" then return CFrame.Angles(a, 0, 0) elseif axis == "Y" then return CFrame.Angles(0, a, 0) end
	return CFrame.Angles(0, 0, a)
end

-- tracked models: [model] = {parts = {[ZPart model] = {joints = {...}, heads = {...}, films = {...}}}}
-- (a plain table: a weak-keyed table can drop an Instance whose Lua wrapper is collected; a model leaves it 5 s after it is
-- unparented and still gone, e.g. a dead character)
local tracked = {}
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
			if info.id == "zfeather" and d:GetAttribute("ZPartRole") == "blade" then table.insert(info.heads, d) end -- v1.3: hidden while empty
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
			-- scan now and again whenever more of it replicates in (with streaming, the welds can arrive after the model)
			local pending = false
			local function rescan()
				if pending then return end
				pending = true
				task.defer(function()
					pending = false
					if zm.Parent then st.parts[zm] = scanPart(zm) end
				end)
			end
			rescan()
			zm.DescendantAdded:Connect(rescan)
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
					local wallOn = info.id == "zdeflect" and model:GetAttribute("TheriDeflectWall") == true and script:GetAttribute("TheriPartsAnimReworkEnabled") ~= false -- v1.4
					for _, f2 in ipairs(info.films) do f2.Transparency = wallOn and 1 or (1 - 0.35 * u) end
				end
			end
			local s = table.concat(active, ",")
			if model:GetAttribute("TheriPartsAnimActive") ~= s then model:SetAttribute("TheriPartsAnimActive", s) end
		end
	end
	script:SetAttribute("TheriPartsAnimJoints", driven)
end)
