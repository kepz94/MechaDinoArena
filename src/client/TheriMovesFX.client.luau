-- TheriMovesFX v1.0 (Mecha Dino Arena) — client effects for the Therizinosaurus' mecha button parts, build 1 (every client
-- draws them for every therizino). Plan docs/plans/THERIZINO_PARTS_v1.0.md Task 5 (MDA-245); looks from the mockup
-- docs/mockups/therizino_parts_options.html v0.1 (chain links, feather blades, red field); server TheriMovesServer 1.0.
--   * Reaper's Hook: TheriHookAt -> a steel chain (alternating light / dark links, CHAIN_STEP studs apart) from the
--     ZPart_zhook "jib" (else the root) to TheriHookAimEnd: it shoots out over SHOOT_TIME (0.15) s; on "hit" it then
--     follows the hooked dino (TheriHookTarget) back for TheriHookPullTime s and goes; on "noTarget" / "blocked" /
--     "shielded" it falls back over 0.25 s.
--   * Feather Barrage: TheriFeatherAt -> one white feather blade per direction (count from the owner's TheriFeatherCount,
--     spread over TheriFeatherFan around TheriFeatherDir) flies from the chest to TheriFeatherRange studs in BLADE_TIME
--     (0.3) s and fades; the ZPart_zfeather "blade" pieces hide until the next fire is ready (TheriFeatherReadyAt).
--   * Harvest Field: TheriFieldAt -> a flat red ring (Neon, 0.6 transparent) of radius TheriFieldRadiusNow at
--     TheriFieldCenter that grows in 0.25 s and pulses until TheriFieldUntil, with blood-red specks rising.
--   * Snare Wires: the trap models are server-built (TheriMovesServer 1.0); nothing here.
-- Everything lives in Workspace.DinoFX_Local.TheriMovesFX (no collision / query / touch, anchored). Switches: script
-- attributes TheriMovesFXEnabled (default true), TheriMovesFX_<hook | feather | field>Enabled (default true; read at each
-- event). Diagnostics: script TheriMovesFXVersion, TheriMovesFXEvents (count), TheriMovesFXLast.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local CHAIN_STEP, SHOOT_TIME, BLADE_TIME = 1.7, 0.15, 0.3
local LIGHT, DARK = Color3.fromRGB(184, 192, 200), Color3.fromRGB(124, 132, 142)
local FEATHER = Color3.fromRGB(240, 234, 216)
local BLOOD = Color3.fromRGB(192, 24, 42)

script:SetAttribute("TheriMovesFXVersion", VERSION)
script:SetAttribute("TheriMovesFXEvents", 0)
for _, k in ipairs({"TheriMovesFXEnabled", "TheriMovesFX_hookEnabled", "TheriMovesFX_featherEnabled", "TheriMovesFX_fieldEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local function on(k) return script:GetAttribute("TheriMovesFXEnabled") ~= false and script:GetAttribute("TheriMovesFX_" .. k .. "Enabled") ~= false end
local function note(s)
	script:SetAttribute("TheriMovesFXEvents", (script:GetAttribute("TheriMovesFXEvents") or 0) + 1)
	script:SetAttribute("TheriMovesFXLast", s)
end
local function now() return workspace:GetServerTimeNow() end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end

local folder
local function fx()
	if folder and folder.Parent then return folder end
	local root = workspace:FindFirstChild("DinoFX_Local")
	if not root then
		root = Instance.new("Folder")
		root.Name = "DinoFX_Local"
		root.Parent = workspace
	end
	folder = root:FindFirstChild("TheriMovesFX") or Instance.new("Folder")
	folder.Name = "TheriMovesFX"
	folder.Parent = root
	return folder
end
local function part(size, color, mat, transp)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Size, p.Color, p.Material = size, color, mat or Enum.Material.Metal
	p.Transparency = transp or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = fx()
	return p
end
local function zpiece(char, id, role)
	local m = char:FindFirstChild("ZPart_" .. id)
	local out = {}
	if m then
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("ZPartRole") == role then table.insert(out, p) end
		end
	end
	return out
end

-- Reaper's Hook --------------------------------------------------------------------------------------------------------------
local function chain(char, s)
	local at = num(char, "TheriHookAt", 0)
	local result = char:GetAttribute("TheriHookResult")
	local aimEnd = char:GetAttribute("TheriHookAimEnd")
	if typeof(aimEnd) ~= "Vector3" then return end
	local pull = num(char, "TheriHookPullTime", 0)
	local target = char:GetAttribute("TheriHookTarget")
	local tm = (result == "hit" and type(target) == "string" and target ~= "") and workspace:FindFirstChild(target, true) or nil
	local troot = tm and tm:IsA("Model") and tm:FindFirstChild("HumanoidRootPart") or nil
	local links = {}
	local t0 = os.clock()
	local total = SHOOT_TIME + (result == "hit" and pull or 0.25)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local e = os.clock() - t0
		local jib = zpiece(char, "zhook", "jib")[1]
		local from = jib and jib.Position or (char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position)
		if e >= total or not from or not char.Parent then
			conn:Disconnect()
			for _, l in ipairs(links) do l:Destroy() end
			return
		end
		local tip
		if e < SHOOT_TIME then
			tip = from:Lerp(aimEnd, e / SHOOT_TIME)
		elseif result == "hit" and troot and troot.Parent then
			tip = troot.Position
		else
			local k = (e - SHOOT_TIME) / 0.25
			tip = aimEnd:Lerp(from, math.clamp(k, 0, 1)) - Vector3.new(0, 3 * k * s, 0)
		end
		local d = tip - from
		local n = math.clamp(math.floor(d.Magnitude / (CHAIN_STEP * s / 2)), 1, 90)
		for i = #links + 1, n do
			links[i] = part(Vector3.new(0.42, 0.42, 0.9) * s / 2 * 1.4, i % 2 == 0 and LIGHT or DARK, Enum.Material.Metal)
		end
		for i, l in ipairs(links) do
			if i <= n then
				local p = from + d * ((i - 0.5) / n)
				l.CFrame = CFrame.lookAt(p, tip) * CFrame.Angles(0, 0, i % 2 == 0 and math.rad(90) or 0)
				l.Transparency = 0
			else
				l.Transparency = 1
			end
		end
	end)
	note("hook:" .. tostring(result))
end

-- Feather Barrage -----------------------------------------------------------------------------------------------------------
local function feathers(char, s)
	local dir = char:GetAttribute("TheriFeatherDir")
	local root = char:FindFirstChild("HumanoidRootPart")
	if typeof(dir) ~= "Vector3" or not root then return end
	local n = math.max(1, math.floor(num(char, "TheriFeatherCount", 8)))
	local range = num(char, "TheriFeatherRange", 20)
	local fan = math.rad(num(char, "TheriFeatherFan", 60))
	local origin = root.Position + Vector3.new(0, 1.5 * s, 0)
	local blades = {}
	for i = 1, n do
		local a = n == 1 and 0 or (-fan / 2 + fan * (i - 1) / (n - 1))
		local d = (CFrame.Angles(0, a, 0) * dir).Unit
		local b = part(Vector3.new(0.12, 0.3, 1.6) * s / 2 * 1.5, FEATHER, Enum.Material.SmoothPlastic)
		table.insert(blades, {p = b, d = d})
	end
	local racks = zpiece(char, "zfeather", "blade")
	for _, r in ipairs(racks) do r.Transparency = 1 end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / BLADE_TIME
		if k >= 1.3 then
			conn:Disconnect()
			for _, b in ipairs(blades) do b.p:Destroy() end
			return
		end
		for _, b in ipairs(blades) do
			local pos = origin + b.d * range * math.min(k, 1)
			b.p.CFrame = CFrame.lookAt(pos, pos + b.d) * CFrame.Angles(0, 0, os.clock() * 20)
			b.p.Transparency = k > 1 and (k - 1) / 0.3 or 0
		end
	end)
	task.spawn(function() -- the rack blades come back when the part is ready again
		local readyAt = num(char, "TheriFeatherReadyAt", now() + 1)
		while char.Parent and now() < readyAt do task.wait(0.25) end
		for _, r in ipairs(racks) do if r.Parent then r.Transparency = 0 end end
	end)
	note("feather")
end

-- Harvest Field -------------------------------------------------------------------------------------------------------------
local function field(char, s)
	local c = char:GetAttribute("TheriFieldCenter")
	if typeof(c) ~= "Vector3" then return end
	local r = num(char, "TheriFieldRadiusNow", 6)
	local untilT = num(char, "TheriFieldUntil", now() + 3)
	local ring = part(Vector3.new(0.3, r * 2, r * 2), BLOOD, Enum.Material.Neon, 0.6)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(c + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local edge = part(Vector3.new(0.35, r * 2 + 0.6, r * 2 + 0.6), Color3.fromRGB(255, 60, 60), Enum.Material.Neon, 0.3)
	edge.Shape = Enum.PartType.Cylinder
	edge.CFrame = ring.CFrame * CFrame.new(-0.02, 0, 0)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = now()
		if t >= untilT or not char.Parent then
			conn:Disconnect()
			ring:Destroy()
			edge:Destroy()
			return
		end
		local e = os.clock() - t0
		local grow = math.min(1, e / 0.25)
		ring.Size = Vector3.new(0.36, r * 2 * grow, r * 2 * grow)
		edge.Size = Vector3.new(0.3, (r * 2 + 0.6) * grow, (r * 2 + 0.6) * grow)
		ring.Transparency = 0.55 + 0.15 * math.sin(e * 8)
		if math.random() < 0.25 then
			local a, rr = math.random() * math.pi * 2, math.random() * r
			local sp = part(Vector3.new(0.25, 0.25, 0.25) * s, BLOOD, Enum.Material.Neon, 0.2)
			sp.CFrame = CFrame.new(c + Vector3.new(math.cos(a) * rr, 0.3, math.sin(a) * rr))
			task.spawn(function()
				for i = 1, 12 do
					if not sp.Parent then return end
					sp.CFrame += Vector3.new(0, 0.25 * s, 0)
					sp.Transparency = 0.2 + i / 15
					task.wait(0.04)
				end
				sp:Destroy()
			end)
		end
	end)
	note("field")
end

-- watch every character ------------------------------------------------------------------------------------------------------
local function watch(char)
	local function s() return char:GetScale() end
	char:GetAttributeChangedSignal("TheriHookAt"):Connect(function() if on("hook") then chain(char, s()) end end)
	char:GetAttributeChangedSignal("TheriFeatherAt"):Connect(function() if on("feather") then feathers(char, s()) end end)
	char:GetAttributeChangedSignal("TheriFieldAt"):Connect(function() if on("field") then field(char, s()) end end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(watch)
	if p.Character then watch(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
