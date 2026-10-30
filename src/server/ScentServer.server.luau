-- ScentServer v1.1 (Mecha Dino Arena) — Scent Sense, a raptor button part (raptor parts batch 2): the server gate and
-- cooldown for the sniff; the trails themselves are drawn by the owner's client (ScentFX 1.0, visible to you only).
-- MDA-72, plan docs/plans/RAPTOR_PARTS_B2_v1.0.md Task 3, mockup docs/mockups/raptor_parts_b2_scent_screech.html
-- (Kepu 2026-10-29: "I like scent sense. Let's add that" -> A "Glowing paw prints", cloaked raptors leave faint prints).
-- Settings come from the character (SkillEffects 1.8): ScentEnabled (bought AND slotted), ScentRadius (60; 81 from II),
--   ScentMemory (8; 10.8 from III), ScentTime (6), ScentCooldown (16), ScentFresh (III), ScentBlood (star).
-- Client -> server: ReplicatedStorage.DinoScentRequest:FireServer(clientServerTime). Checks, first failing wins:
--   "badArg", "dead", "disabled" (ScentServerEnabled false or ScentEnabled ~= true), "stunned" (StunnedUntil > now),
--   "active" (ScentUntil > now), "cooldown" (now < ScentReadyAt), "ok". ok: ScentUntil = now + ScentTime, ScentReadyAt
--   = ScentUntil + ScentCooldown (counted from the end, like the other timed parts), ScentCount + 1, ScentStartedAt =
--   now (last; ScentFX and CloakServer react to it). ScentEnabled turning false ends a running sniff early
--   (ScentUntil = now, ScentReadyAt = now + cooldown, ScentEndReason "disabled"); the end by time sets ScentEndReason
--   "time".
-- Settings: script attribute ScentServerEnabled (default true).
-- Diagnostics: script ScentServerVersion, ScentRequests; character ScentServerResult, ScentCount, ScentEndReason,
--   ScentState ("off" / "on").
-- v1.1 (Kepu 2026-10-29: "Scent sense could be a mask that the Dino wears around the nose and mouth"; mockup
--   docs/mockups/scent_mask_options.html, picked A "Breather"): Model "Mecha_Scent" under the character while ScentEnabled
--   is true (bought and slotted). Built in the Root frames of the "Head" and "Jaw" segments (axes nearest the body's
--   right / up, so the pose at build time doesn't matter), sized from the snout box (Head parts named *snout* / *tip*;
--   none -> the front 40% of the Head box), extents ex / ey / ez (right / up / forward):
--   * on the Head Root (WeldConstraint): "MaskPlate" (dark metal rgb(58, 67, 80); 2ex x 1.12, 2ey x 1.12, 2ez x 0.5,
--     covering the front half of the snout and the tip), "MaskTop" (rgb(88, 101, 122) strip on top), "MaskVent" (volt neon,
--     on the plate's front face), two cheek canisters "MaskCanL" / "MaskCanR" (cylinders across the head, diameter
--     2ey x 0.9, just behind the plate on each side) with volt neon cores "MaskCoreL" / "MaskCoreR";
--   * on the Jaw Root: "MaskChin" (dark metal guard on the front of the jaw, 2jex x 1.1, 2jey x 0.75, 2jez x 0.4) and "MaskChinVent"
--     (volt neon strip on its front), so the jaw still opens to bite.
--   Massless, CanCollide / CanQuery / CanTouch false, no shadow. Volt parts: Transparency 0.35, 0 while a sniff runs
--   (ScentState "on"). Removed when ScentEnabled turns off or the switch is off. Switch: script attribute ScentMaskEnabled
--   (default true; false = no mask). Diagnostic: character ScentMaskState ("none" / "on" / "noHead").
--   BindableFunction "BuildPreview" (server only): Invoke(model) builds the mask on a Lab mannequin (ScentEnabled = true)
--   and returns its Model (LabPreviewServer 1.1); switch ScentServerPreviewEnabled (default true).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.1"

script:SetAttribute("ScentServerVersion", VERSION)
if script:GetAttribute("ScentServerEnabled") == nil then script:SetAttribute("ScentServerEnabled", true) end
script:SetAttribute("ScentRequests", 0)
local function on() return script:GetAttribute("ScentServerEnabled") ~= false end
local function now() return workspace:GetServerTimeNow() end

local remote = ReplicatedStorage:FindFirstChild("DinoScentRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoScentRequest"
	remote.Parent = ReplicatedStorage
end

local chars = {} -- [char] = {hum, active}

-- ---------- v1.1: the Breather mask ----------
if script:GetAttribute("ScentMaskEnabled") == nil then script:SetAttribute("ScentMaskEnabled", true) end
local MDARK, MLIGHT, MVOLT = Color3.fromRGB(58, 67, 80), Color3.fromRGB(88, 101, 122), Color3.fromRGB(127, 233, 255)
local function mpart(name, size, cf, color, parent, mount, neon, shape)
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = neon and Enum.Material.Neon or Enum.Material.Metal
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored, p.Massless = false, true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	if neon then p.Transparency = 0.35 end
	p.Parent = parent
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = mount, p
	w.Parent = p
	return p
end
local function boxOf(parts, root)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(parts) do
		for _, sx in ipairs({-0.5, 0.5}) do for _, sy in ipairs({-0.5, 0.5}) do for _, sz in ipairs({-0.5, 0.5}) do
			local q = root.CFrame:PointToObjectSpace(p.CFrame * Vector3.new(p.Size.X * sx, p.Size.Y * sy, p.Size.Z * sz))
			lo, hi = lo:Min(q), hi:Max(q)
		end end end
	end
	if lo.X == math.huge then return nil end
	return lo, hi
end
local function axisOf(root, dir)
	local v = root.CFrame:VectorToObjectSpace(dir)
	local a = Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
	if a.X >= a.Y and a.X >= a.Z then return Vector3.new(v.X >= 0 and 1 or -1, 0, 0) end
	if a.Y >= a.Z then return Vector3.new(0, v.Y >= 0 and 1 or -1, 0) end
	return Vector3.new(0, 0, v.Z >= 0 and 1 or -1)
end
local function extent(lo, hi, axis)
	local h = (hi - lo) / 2
	return math.abs(axis.X) * h.X + math.abs(axis.Y) * h.Y + math.abs(axis.Z) * h.Z
end
local function bodyAxes(root, hrp) -- right, up, back (z = x cross y)
	local x = axisOf(root, hrp.CFrame.RightVector)
	local y = axisOf(root, hrp.CFrame.UpVector)
	if math.abs(x:Dot(y)) > 0.5 then y = axisOf(root, hrp.CFrame.LookVector):Cross(x) end
	return x, y, x:Cross(y)
end
local function segParts(seg, root, pattern)
	local out = {}
	for _, d in ipairs(seg:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root and (pattern == nil or string.find(string.lower(d.Name), pattern)) then
			table.insert(out, d)
		end
	end
	return out
end
local function buildMask(char)
	local old = char:FindFirstChild("Mecha_Scent")
	if old then old:Destroy() end
	if not on() or script:GetAttribute("ScentMaskEnabled") == false or char:GetAttribute("ScentEnabled") ~= true then
		char:SetAttribute("ScentMaskState", "none")
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local head = char:FindFirstChild("Head")
	local hroot = head and head:FindFirstChild("Root")
	if not (hrp and hroot and hroot:IsA("BasePart")) then char:SetAttribute("ScentMaskState", "noHead") return end
	local x, y, z = bodyAxes(hroot, hrp)
	local snout = segParts(head, hroot, "snout")
	for _, p in ipairs(segParts(head, hroot, "tip")) do table.insert(snout, p) end
	local lo, hi = boxOf(snout, hroot)
	if not lo then -- no snout parts: the front 40% of the head box
		local hlo, hhi = boxOf(segParts(head, hroot, nil), hroot)
		if not hlo then char:SetAttribute("ScentMaskState", "noHead") return end
		local hc, half = (hlo + hhi) / 2, (hhi - hlo) / 2
		local fc = hc - z * (extent(hlo, hhi, z) * 0.6) -- the front part of the head box
		lo, hi = fc - half * 0.5, fc + half * 0.5
	end
	local c = (lo + hi) / 2
	local ex, ey, ez = extent(lo, hi, x), extent(lo, hi, y), extent(lo, hi, z)
	local function at(pLocal) return hroot.CFrame * CFrame.fromMatrix(pLocal, x, y, z) end
	local function sz(a, b, cc) return Vector3.new(a, b, cc) end -- (right, up, back) in the frame built by at()
	local model = Instance.new("Model")
	model.Name = "Mecha_Scent"
	-- plate over the front of the snout and the tip
	local plateC = c - z * (ez * 0.52) + y * (ey * 0.04)
	local plate = mpart("MaskPlate", sz(2 * ex * 1.12, 2 * ey * 1.12, 2 * ez * 0.5), at(plateC), MDARK, model, hroot)
	mpart("MaskTop", sz(2 * ex * 0.95, ey * 0.22, 2 * ez * 0.42), at(plateC + y * (ey * 1.12 + ey * 0.1)), MLIGHT, model, hroot)
	mpart("MaskVent", sz(2 * ex * 0.75, ey * 0.5, ez * 0.08), at(plateC - z * (ez * 0.5 + ez * 0.03)), MVOLT, model, hroot, true)
	-- cheek canisters (cylinder axis = the part's X = across the head)
	local d = 2 * ey * 0.9
	for _, side in ipairs({{"L", -1}, {"R", 1}}) do
		local cc = c + z * (ez * 0.15) + x * side[2] * (ex * 1.12 + d * 0.28) - y * (ey * 0.15)
		mpart("MaskCan" .. side[1], Vector3.new(d * 0.55, d, d), at(cc), MLIGHT, model, hroot, false, Enum.PartType.Cylinder)
		mpart("MaskCore" .. side[1], Vector3.new(d * 0.6, d * 0.5, d * 0.5), at(cc), MVOLT, model, hroot, true, Enum.PartType.Cylinder)
	end
	-- chin guard on the jaw (opens with the bite)
	local jaw = char:FindFirstChild("Jaw")
	local jroot = jaw and jaw:FindFirstChild("Root")
	if jroot and jroot:IsA("BasePart") then
		local jx, jy, jz = bodyAxes(jroot, hrp)
		local jlo, jhi = boxOf(segParts(jaw, jroot, nil), jroot)
		if jlo then
			local jc = (jlo + jhi) / 2
			local jex, jey, jez = extent(jlo, jhi, jx), extent(jlo, jhi, jy), extent(jlo, jhi, jz)
			local gc = jc - jz * (jez * 0.6) - jy * (jey * 0.1)
			local gcf = jroot.CFrame * CFrame.fromMatrix(gc, jx, jy, jz)
			mpart("MaskChin", Vector3.new(2 * jex * 1.1, 2 * jey * 0.75, 2 * jez * 0.4), gcf, MDARK, model, jroot)
			mpart("MaskChinVent", Vector3.new(2 * jex * 0.8, jey * 0.4, jez * 0.06),
				gcf * CFrame.new(0, 0, -(jez * 0.4 + jez * 0.03)), MVOLT, model, jroot, true)
		end
	end
	model.Parent = char
	char:SetAttribute("ScentMaskState", "on")
	return plate
end
local function maskGlow(char)
	local m = char:FindFirstChild("Mecha_Scent")
	if not m then return end
	local lit = char:GetAttribute("ScentState") == "on"
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p.Material == Enum.Material.Neon then p.Transparency = lit and 0 or 0.35 end
	end
end

local function finish(char, reason)
	local st = chars[char]
	if not st or not st.active then return end
	st.active = false
	local t = now()
	if reason ~= "time" then
		char:SetAttribute("ScentUntil", t)
		char:SetAttribute("ScentReadyAt", t + (tonumber(char:GetAttribute("ScentCooldown")) or 0))
	end
	char:SetAttribute("ScentEndReason", reason)
	char:SetAttribute("ScentState", "off")
end

remote.OnServerEvent:Connect(function(player, stamp)
	local char = player.Character
	local st = char and chars[char]
	if not st then return end
	script:SetAttribute("ScentRequests", (script:GetAttribute("ScentRequests") or 0) + 1)
	local t = now()
	local hum = st.hum
	local result
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		result = "badArg"
	elseif not hum or hum.Health <= 0 then
		result = "dead"
	elseif not on() or char:GetAttribute("ScentEnabled") ~= true then
		result = "disabled"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		result = "stunned"
	elseif (tonumber(char:GetAttribute("ScentUntil")) or 0) > t then
		result = "active"
	elseif t < (tonumber(char:GetAttribute("ScentReadyAt")) or 0) then
		result = "cooldown"
	else
		result = "ok"
	end
	char:SetAttribute("ScentServerResult", result)
	if result ~= "ok" then return end
	local dur = math.max(0.1, tonumber(char:GetAttribute("ScentTime")) or 6)
	st.active = true
	char:SetAttribute("ScentEndReason", "")
	char:SetAttribute("ScentUntil", t + dur)
	char:SetAttribute("ScentReadyAt", t + dur + (tonumber(char:GetAttribute("ScentCooldown")) or 0))
	char:SetAttribute("ScentCount", (char:GetAttribute("ScentCount") or 0) + 1)
	char:SetAttribute("ScentState", "on")
	char:SetAttribute("ScentStartedAt", t) -- last: readers react to this one
end)

RunService.Heartbeat:Connect(function()
	local t = now()
	for char, st in pairs(chars) do
		if st.active then
			if not char.Parent or st.hum.Health <= 0 then
				finish(char, "dead")
			elseif t >= (tonumber(char:GetAttribute("ScentUntil")) or 0) then
				finish(char, "time")
			end
		end
	end
end)

local function onCharacter(char)
	if chars[char] then return end
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	chars[char] = {hum = hum, active = false}
	char:SetAttribute("ScentUntil", 0)
	char:SetAttribute("ScentReadyAt", 0)
	char:SetAttribute("ScentState", "off")
	char:GetAttributeChangedSignal("ScentEnabled"):Connect(function()
		if char:GetAttribute("ScentEnabled") ~= true then finish(char, "disabled") end
		buildMask(char) -- v1.1
	end)
	char:GetAttributeChangedSignal("ScentState"):Connect(function() maskGlow(char) end) -- v1.1
	task.spawn(function() -- v1.1
		char:WaitForChild("Head", 10)
		buildMask(char)
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
end

script:GetAttributeChangedSignal("ScentServerEnabled"):Connect(function()
	for char in pairs(chars) do buildMask(char) end -- v1.1
	if on() then return end
	for char in pairs(chars) do finish(char, "disabled") end
end)
script:GetAttributeChangedSignal("ScentMaskEnabled"):Connect(function() -- v1.1
	for char in pairs(chars) do buildMask(char) end
end)

local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

-- v1.1: Lab card preview (LabPreviewServer 1.1)
if script:GetAttribute("ScentServerPreviewEnabled") == nil then script:SetAttribute("ScentServerPreviewEnabled", true) end
local previewFn = script:FindFirstChild("BuildPreview") or Instance.new("BindableFunction")
previewFn.Name = "BuildPreview"
previewFn.Parent = script
previewFn.OnInvoke = function(model)
	if script:GetAttribute("ScentServerPreviewEnabled") == false or typeof(model) ~= "Instance" then return nil end
	model:SetAttribute("ScentEnabled", true)
	buildMask(model)
	return model:FindFirstChild("Mecha_Scent")
end
