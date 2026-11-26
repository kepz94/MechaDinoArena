-- QuestStandServer v1.0 (Mecha Dino Arena) — the island Quest Stand stall (Script, ServerScriptService). Plan
-- docs/plans/QUEST_STAND_v1.0.md Task 4; Kepu 2026-11-26 picks on mockup docs/mockups/quest_stand_v0.1.html: "Mirror of the shop".
-- Waits (hub servers only) for Workspace.ShopStand (ShopStandServer 1.1) and Workspace.PortalIslet.Plaza / Portal_arena, then clones the
--   shop stall as Workspace.QuestStand (the shop itself is not touched). Spot: the plaza centre c (Plaza X, Z), the shop's distance from
--   c, at the shop's angle mirrored over the line from c through the ARENA portal (QuestStandAngle overrides, degrees from world +X
--   toward +Z); turned to face c, the same height as the shop.
-- Look: the Roof / Valance parts' orange -> blue rgb(47,143,216) and yellow -> cyan rgb(127,233,255); the sign's text "QUESTS" (cyan);
--   a notice board (dark wood, 3 pinned papers) on the back wall, facing the front.
-- Model attributes for QuestStandClient 1.0 / QuestServer 1.0: QuestStandFront (the shop's front point moved with the stall) and
--   QuestStandRange (QuestStandRange script attribute, 24).
-- Switches / numbers (script attributes, read at start): QuestStandEnabled (true; false = nothing built), QuestStandAngle (unset =
--   mirrored), QuestStandRange (24).
-- Diagnostics: QuestStandServerVersion, QuestStandState ("off" / "notHub" / "waiting" / "built" / "error: ..."), QuestStandAngleUsed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VERSION = "1.0"
script:SetAttribute("QuestStandServerVersion", VERSION)
if script:GetAttribute("QuestStandEnabled") == nil then script:SetAttribute("QuestStandEnabled", true) end
if script:GetAttribute("QuestStandRange") == nil then script:SetAttribute("QuestStandRange", 24) end
local function state(s) script:SetAttribute("QuestStandState", s) end
if script:GetAttribute("QuestStandEnabled") == false then state("off") return end

state("waiting")
local shop, plaza, portal
local t0 = os.clock()
while os.clock() - t0 < 180 do
	local kind = ReplicatedStorage:GetAttribute("ServerKind")
	if kind ~= nil and kind ~= "hub" then state("notHub") return end
	shop = workspace:FindFirstChild("ShopStand")
	local islet = workspace:FindFirstChild("PortalIslet")
	plaza = islet and islet:FindFirstChild("Plaza")
	portal = islet and islet:FindFirstChild("Portal_arena")
	if kind == "hub" and shop and plaza and portal and typeof(shop:GetAttribute("ShopStandFront")) == "Vector3" then break end
	task.wait(0.5)
end
if not (shop and plaza and portal) then state("waiting: no shop / plaza / portal") return end
task.wait(0.5) -- the shop finishes building in one go; a short wait keeps us off its last frame

local ok, err = pcall(function()
	local old = workspace:FindFirstChild("QuestStand")
	if old then old:Destroy() end
	local c = Vector3.new(plaza.Position.X, 0, plaza.Position.Z)
	local sp = shop:GetPivot()
	local flat = Vector3.new(sp.Position.X, 0, sp.Position.Z) - c
	local r = flat.Magnitude
	local aShop = math.atan2(flat.Z, flat.X)
	local pp = portal:GetPivot().Position
	local aPortal = math.atan2(pp.Z - c.Z, pp.X - c.X)
	local a = 2 * aPortal - aShop
	local override = tonumber(script:GetAttribute("QuestStandAngle"))
	if override then a = math.rad(override) end
	script:SetAttribute("QuestStandAngleUsed", math.floor(math.deg(a) % 360 * 10 + 0.5) / 10)
	local pos = Vector3.new(c.X + math.cos(a) * r, sp.Position.Y, c.Z + math.sin(a) * r)
	local look = Vector3.new(c.X, sp.Position.Y, c.Z)
	local newPivot = CFrame.lookAt(pos, look)
	-- the shop's pivot looks at c too (ShopStandServer turns it to face c), so the same lookAt keeps the stall's front to the centre
	local m = shop:Clone()
	m.Name = "QuestStand"
	for k in pairs(m:GetAttributes()) do m:SetAttribute(k, nil) end
	local BLUE, CYAN = Color3.fromRGB(47, 143, 216), Color3.fromRGB(127, 233, 255)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == "Roof" or d.Name == "Valance") then
			local col = d.Color -- the shop's orange rgb(255,122,26) -> blue, yellow rgb(255,200,50) -> cyan
			if col.R > 0.8 and col.G < 0.6 then d.Color = BLUE elseif col.R > 0.8 and col.G >= 0.6 then d.Color = CYAN end
		elseif d:IsA("TextLabel") and d.Text == "SHOP" then
			d.Text = "QUESTS"
			d.TextColor3 = CYAN
		end
	end
	-- the notice board on the back wall
	local back = m:FindFirstChild("BackWall")
	if back and back:IsA("BasePart") then
		local f = sp.LookVector
		local bw = back.Size.X > back.Size.Z and back.Size.X or back.Size.Z
		local thick = math.min(back.Size.X, back.Size.Z)
		local boardCF = CFrame.lookAt(back.Position + f * (thick / 2 + 0.25) + Vector3.new(0, back.Size.Y * 0.12, 0),
			back.Position + f * 10 + Vector3.new(0, back.Size.Y * 0.12, 0))
		local board = Instance.new("Part")
		board.Name = "NoticeBoard"
		board.Anchored, board.CanCollide = true, false
		board.Material = Enum.Material.Wood
		board.Color = Color3.fromRGB(91, 61, 34)
		board.Size = Vector3.new(bw * 0.55, back.Size.Y * 0.38, 0.4)
		board.CFrame = boardCF
		board.Parent = m
		local papers = {{-0.3, Color3.fromRGB(243, 231, 200), -4}, {0, Color3.fromRGB(255, 243, 176), 3}, {0.3, Color3.fromRGB(243, 231, 200), -2}}
		for i, p in ipairs(papers) do
			local pa = Instance.new("Part")
			pa.Name = "Paper" .. i
			pa.Anchored, pa.CanCollide = true, false
			pa.Material = Enum.Material.SmoothPlastic
			pa.Color = p[2]
			pa.Size = Vector3.new(board.Size.X * 0.22, board.Size.Y * 0.7, 0.1)
			pa.CFrame = boardCF * CFrame.new(board.Size.X * p[1], 0, -0.25) * CFrame.Angles(0, 0, math.rad(p[3]))
			pa.Parent = m
			local pin = Instance.new("Part")
			pin.Name = "Pin" .. i
			pin.Shape = Enum.PartType.Ball
			pin.Anchored, pin.CanCollide = true, false
			pin.Color = Color3.fromRGB(255, 90, 110)
			pin.Size = Vector3.new(0.5, 0.5, 0.5)
			pin.CFrame = pa.CFrame * CFrame.new(0, pa.Size.Y * 0.4, -0.15)
			pin.Parent = m
		end
	end
	m:PivotTo(newPivot)
	local front = shop:GetAttribute("ShopStandFront")
	local frontNew = newPivot * (sp:Inverse() * front)
	m:SetAttribute("QuestStandFront", frontNew)
	m:SetAttribute("QuestStandRange", tonumber(script:GetAttribute("QuestStandRange")) or 24)
	m.Parent = workspace
end)
state(ok and "built" or ("error: " .. tostring(err)))
