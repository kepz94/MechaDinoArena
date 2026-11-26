SSS = 'game:GetService("ServerScriptService").'
QE = 'Kepu 2026-11-26 12:11 "MOVE THE EGG ROLL MACHINE NEXT TO THE BRIDGE TO THE SIDE OF IT SO ALL PLAYERS SEE IT WHEN WALKING BACK TO THE ISLAND"'
QF = ('Kepu 2026-11-26 12:14 "PUT IT ON THE OTHER SIDE OF WHERE THE EGG IS LOCATED SO THERES THE EGG MACHINE ON ONE SIDE OF THE BRIDGE '
      'ENTRANCE TO THE ISLAND AND THE FEEDBACK MACHINE ON THE OTHER SIDE"')
FACE = ('faces the point FaceAngle / FaceRadius from the plaza centre (default 225 deg, 190 studs: out along the bridge deck, which '
        'runs 225 deg, r 125-209), so players walking back over the bridge see its front')
JOBS = {}

# FavEggStandServer 1.1
E = []
a = 'local VERSION = "1.0"\n'
E.append((a, a + '''VERSION = "1.1" -- v1.1 beside the bridge, facing it
-- v1.1 (''' + QE + '''): the stand moves to the islet beside the bridge mouth: FavEggStandAngle default 239 (was 315),
--   FavEggStandRadius 100 (was 45): 25 studs to the side of the bridge line, inside the plaza edge (r 110). It ''' + FACE + '''.
--   Attributes FavEggStandFaceAngle (225), FavEggStandFaceRadius (190); switch FavEggStandFaceEnabled (true, read at start; false
--   = faces the plaza centre as 1.0). FeedbackStandServer 1.1 mirrors it on the other side of the bridge.
'''))
a = 'for k, v in pairs({FavEggStandEnabled = true, FavEggStandAngle = 315, FavEggStandRadius = 45, FavEggPromptRange = 20, FavEggStandScale = 2.2}) do\n'
E.append((a, 'for k, v in pairs({FavEggStandEnabled = true, FavEggStandAngle = 239, FavEggStandRadius = 100, FavEggPromptRange = 20, FavEggStandScale = 2.2, -- v1.1: 239 / 100 (1.0: 315 / 45)\n'
             '\tFavEggStandFaceEnabled = true, FavEggStandFaceAngle = 225, FavEggStandFaceRadius = 190}) do -- v1.1\n'))
a = '\tlocal base = CFrame.lookAt(Vector3.new(x, gy, z), Vector3.new(c.X, gy, c.Z))\n'
E.append((a, a + '''	if script:GetAttribute("FavEggStandFaceEnabled") ~= false then -- v1.1: face out along the bridge
		local fa = math.rad(tonumber(script:GetAttribute("FavEggStandFaceAngle")) or 225)
		local fr = tonumber(script:GetAttribute("FavEggStandFaceRadius")) or 190
		base = CFrame.lookAt(Vector3.new(x, gy, z), Vector3.new(c.X + math.cos(fa) * fr, gy, c.Z + math.sin(fa) * fr))
	end
'''))
JOBS["FavEggStandServer"] = ("src/server/FavEggStandServer.server.luau", SSS + "FavEggStandServer", E)

# FeedbackStandServer 1.2
F = []
a = 'local VERSION = "1.0"\n'
F.append((a, a + '''VERSION = "1.1" -- v1.1 the other side of the bridge, facing it
-- v1.1 (''' + QF + '''): FeedbackStandAngle default 211 (was 145), FeedbackStandRadius 100 (was 45): 22 studs to the
--   other side of the bridge line from the Favorite Egg (239). It ''' + FACE + '''. Attributes FeedbackStandFaceAngle (225),
--   FeedbackStandFaceRadius (190); switch FeedbackStandFaceEnabled (true, read at start; false = faces the plaza centre as 1.0).
'''))
a = 'for k, v in pairs({FeedbackStandEnabled = true, FeedbackStandAngle = 145, FeedbackStandRadius = 45, FeedbackStandScale = 2,\n\tFeedbackPromptRange = 14}) do\n'
F.append((a, 'for k, v in pairs({FeedbackStandEnabled = true, FeedbackStandAngle = 211, FeedbackStandRadius = 100, FeedbackStandScale = 2, -- v1.1: 211 / 100 (1.0: 145 / 45)\n'
             '\tFeedbackPromptRange = 14, FeedbackStandFaceEnabled = true, FeedbackStandFaceAngle = 225, FeedbackStandFaceRadius = 190}) do -- v1.1\n'))
a = '\tlocal base = CFrame.lookAt(Vector3.new(x, gy, z), Vector3.new(c.X, gy, c.Z))\n'
F.append((a, a + '''	if script:GetAttribute("FeedbackStandFaceEnabled") ~= false then -- v1.1: face out along the bridge
		local fa = math.rad(tonumber(script:GetAttribute("FeedbackStandFaceAngle")) or 225)
		local fr = tonumber(script:GetAttribute("FeedbackStandFaceRadius")) or 190
		base = CFrame.lookAt(Vector3.new(x, gy, z), Vector3.new(c.X + math.cos(fa) * fr, gy, c.Z + math.sin(fa) * fr))
	end
'''))
JOBS["FeedbackStandServer"] = ("src/server/FeedbackStandServer.server.luau", SSS + "FeedbackStandServer", F)

# HubServer 1.9: island respawn + return-to-pad request
QR = ('Kepu 2026-11-26 12:11 "WHEN A DINOSAUR DIES ON THE ISLAND, AUTO SPAWN ON THE ISLAND ITSELF NEAR OTHER DINOS NOT TOO CLOSE BUT ON THE '
      'ISLAND STILL SO PEOPLE CAN CONTINUALLY FIGHT ... GIVE A POP UP AFTER A RESPAWN FOR 2 SECONDS TO RETURN TO SPAWN PAD"')
H = []
a = 'VERSION = "1.8" -- v1.8 one portal (ARENA, centered)\n'
H.append((a, a + '''VERSION = "1.9" -- v1.9 island respawn + return to pad
-- v1.9 (''' + QR + '''): on the hub, a player whose dino dies OFF the islet (character HubInZone not true, not InMenu, not
--   in a tutorial lane) comes back ON the island instead of the islet pad:
--   * Death: Humanoid.Died -> diedAt[player] (opening the menu drops it). The next islet placement within IslandRespawnWindow (20) s that is a new spawn (not a
--     v1.5 re-place) goes to an island spot instead (the v1.6 dino-swap rule and the v1.7 tutorial rule sit inside, so a swapped
--     body keeps its place). The death stays pending until a body that is the player's own dino (Species == DinoSpecies) is placed
--     (SpeciesServer may swap the first body); a body placed within 4 s of the last island spot reuses that spot.
--   * Spot: anchors = live dinos on the island (other players: alive, not InMenu, not HubInZone; Workspace.DinoIsland.Bots: alive);
--     up to IslandRespawnTries (40) random points IslandRespawnMin..IslandRespawnMax (60..110) studs (flat) from a random anchor:
--     ground is Workspace.DinoIsland.Ground, dry (y >= 0), flat (normal Y > 0.9), no Trees / Rocks / MountainSteps / EdgeWalls part
--     within 18 studs, outside every SafeZone, and every live dino at least IslandRespawnClear (45) studs away (not too close).
--     No anchor -> random points over the island's ground. Facing: toward the anchor (camera too, ShoulderCamLookAt for 1 s).
--     No spot -> the islet pad as before.
--   * Placed like the islet spawn (root server-owned + anchored for HubPlaceHold s, then free); a check at 1 s puts it back on the
--     spot once if it is near the old SpawnLocation (the v1.5 client echo). Player attributes IslandRespawnAt (server time, set
--     when the own dino is placed; IslandRespawnClient 1.0 shows the button), HubPlaceLast "island <anchor>", IslandRespawnNear.
--   * RemoteEvent ReplicatedStorage.HubIslandRequest ("pad"): within IslandPadWindow (2.5) s of IslandRespawnAt and alive -> the
--     islet pad placement (the 1.8 chain), HubPlaceLast "pad", player IslandPadAt. Else ignored.
--   Switch: script attribute IslandRespawnEnabled (true, read per death / placement). Diagnostics: IslandRespawns, IslandPadReturns,
--   IslandRespawnFallbacks (no spot found).
'''))
a = '-- ---------- trips ----------\n'
H.append((a, '''-- v1.9: island respawn (see the header)
for k, v in pairs({IslandRespawnEnabled = true, IslandRespawnWindow = 20, IslandRespawnTries = 40, IslandRespawnMin = 60,
	IslandRespawnMax = 110, IslandRespawnClear = 45, IslandPadWindow = 2.5}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
do
	local function islandOn() return KIND == "hub" and script:GetAttribute("IslandRespawnEnabled") ~= false end
	local function bumpI(k) script:SetAttribute(k, (script:GetAttribute(k) or 0) + 1) end
	local diedAt, lastSpot = {}, {}
	local function watchDeaths(p)
		p:GetAttributeChangedSignal("InMenu"):Connect(function() -- the menu drops a pending island respawn
			if p:GetAttribute("InMenu") == true then diedAt[p], lastSpot[p] = nil, nil end
		end)
		p.CharacterAdded:Connect(function(c)
			local hum = c:WaitForChild("Humanoid", 10)
			if not hum then return end
			hum.Died:Connect(function()
				if not islandOn() or p:GetAttribute("InMenu") == true then return end
				if (tonumber(p:GetAttribute("TutLane")) or 0) > 0 or c:GetAttribute("HubInZone") == true then return end
				diedAt[p] = os.clock()
			end)
		end)
	end
	Players.PlayerAdded:Connect(watchDeaths)
	for _, p in ipairs(Players:GetPlayers()) do watchDeaths(p) end
	Players.PlayerRemoving:Connect(function(p) diedAt[p], lastSpot[p] = nil, nil end)

	local function liveDinos(except)
		local list = {}
		for _, o in ipairs(Players:GetPlayers()) do
			local r, c = rootOf(o)
			if o ~= except and r and o:GetAttribute("InMenu") ~= true and c:GetAttribute("HubInZone") ~= true then
				table.insert(list, {pos = r.Position, name = o.Name})
			end
		end
		local island = workspace:FindFirstChild("DinoIsland")
		local bots = island and island:FindFirstChild("Bots")
		if bots then
			for _, b in ipairs(bots:GetChildren()) do
				local r = b:IsA("Model") and (b:FindFirstChild("HumanoidRootPart") or b.PrimaryPart)
				local h = b:FindFirstChildOfClass("Humanoid")
				local hp = b:GetAttribute("DummyHealth")
				if r and ((h and h.Health > 0) or (typeof(hp) == "number" and hp > 0)) then table.insert(list, {pos = r.Position, name = b.Name}) end
			end
		end
		return list
	end
	local groundBox -- v1.9: {centre CFrame, size} of Workspace.DinoIsland.Ground, built on first use
	local function findSpot(p)
		local island = workspace:FindFirstChild("DinoIsland")
		local groundF = island and island:FindFirstChild("Ground")
		if not groundF then return nil end
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = {groundF}
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Include
		local block = {}
		for _, n in ipairs({"Trees", "Rocks", "MountainSteps", "EdgeWalls"}) do
			local f = island:FindFirstChild(n)
			if f then table.insert(block, f) end
		end
		op.FilterDescendantsInstances = block
		local live = liveDinos(p)
		local mn, mx = tonumber(script:GetAttribute("IslandRespawnMin")) or 60, tonumber(script:GetAttribute("IslandRespawnMax")) or 110
		local clearD = tonumber(script:GetAttribute("IslandRespawnClear")) or 45
		if not groundBox then -- v1.9: Ground is a Folder of parts (Studio check 2026-11-26): one box over all of them, cached
			local mn, mx = Vector3.one * 1e9, Vector3.one * -1e9
			for _, d in ipairs(groundF:GetDescendants()) do
				if d:IsA("BasePart") then
					local h = d.Size / 2
					mn, mx = mn:Min(d.Position - h), mx:Max(d.Position + h)
				end
			end
			if mx.X < mn.X then return nil end
			groundBox = {CFrame.new((mn + mx) / 2), mx - mn}
		end
		local gcf, gsize = groundBox[1], groundBox[2]
		for _ = 1, math.max(1, math.floor(tonumber(script:GetAttribute("IslandRespawnTries")) or 40)) do
			local anchor, x, z
			if #live > 0 then
				anchor = live[math.random(1, #live)]
				local a = math.random() * 2 * math.pi
				local d = mn + math.random() * (mx - mn)
				x, z = anchor.pos.X + math.cos(a) * d, anchor.pos.Z + math.sin(a) * d
			else
				x = gcf.Position.X + (math.random() - 0.5) * gsize.X * 0.8
				z = gcf.Position.Z + (math.random() - 0.5) * gsize.Z * 0.8
			end
			local hit = workspace:Raycast(Vector3.new(x, gcf.Position.Y + gsize.Y / 2 + 300, z), Vector3.new(0, -2000, 0), rp)
			if hit and hit.Position.Y >= 0 and hit.Normal.Y > 0.9 and not HubRules.inZone(hit.Position, zones)
				and #workspace:GetPartBoundsInBox(CFrame.new(hit.Position + Vector3.new(0, 12, 0)), Vector3.new(36, 22, 36), op) == 0 then
				local ok = true
				for _, o in ipairs(live) do
					if Vector3.new(o.pos.X - x, 0, o.pos.Z - z).Magnitude < clearD then ok = false break end
				end
				if ok then
					local look
					if anchor then
						local d = Vector3.new(anchor.pos.X - x, 0, anchor.pos.Z - z)
						if d.Magnitude > 1 then look = d.Unit end
					end
					if not look then
						local d = Vector3.new(gcf.Position.X - x, 0, gcf.Position.Z - z)
						look = d.Magnitude > 1 and d.Unit or Vector3.new(0, 0, -1)
					end
					return hit.Position, look, anchor and anchor.name or ""
				end
			end
		end
		return nil
	end
	local function standAt(p, c, ground, look)
		local hrp = c:FindFirstChild("HumanoidRootPart")
		local hum = c:FindFirstChildOfClass("Humanoid")
		if not (hrp and hum) then return false end
		local pos = ground + Vector3.new(0, hrp.Size.Y / 2 + hum.HipHeight, 0)
		pcall(function() hrp:SetNetworkOwner(nil) end)
		hrp.Anchored = true
		c:PivotTo(CFrame.lookAt(pos, pos + look))
		hrp.AssemblyLinearVelocity = Vector3.zero
		c:SetAttribute("HubGuardUntil", nil)
		c:SetAttribute("ShoulderCamLookAt", pos + look * 500)
		task.delay(1, function() if c.Parent then c:SetAttribute("ShoulderCamLookAt", nil) end end)
		task.delay(tonumber(script:GetAttribute("HubPlaceHold")) or 0.3, function()
			if hrp.Parent and hrp.Anchored and p:GetAttribute("InMenu") ~= true then
				hrp.Anchored = false
				pcall(function() hrp:SetNetworkOwnershipAuto() end)
			end
		end)
		task.delay(1, function() -- the v1.5 client echo: back on the spot once
			if p.Character == c and hrp.Parent and hum.Health > 0 and nearOldSpawn(hrp.Position) then
				c:PivotTo(CFrame.lookAt(pos, pos + look))
				bumpI("HubPlaceFixes")
			end
		end)
		return true
	end
	local rawPlaceV18 = place
	place = function(p, fixes)
		local c = p.Character
		local t0 = diedAt[p]
		if not fixes and c and t0 and islandOn() and p:GetAttribute("InMenu") ~= true
			and os.clock() - t0 <= (tonumber(script:GetAttribute("IslandRespawnWindow")) or 20)
			and (tonumber(p:GetAttribute("TutLane")) or 0) <= 0 then
			local spot, look, near
			local ls = lastSpot[p]
			if ls and os.clock() - ls.at <= 4 then spot, look, near = ls.ground, ls.look, ls.near else spot, look, near = findSpot(p) end
			if spot and standAt(p, c, spot, look) then
				lastSpot[p] = {ground = spot, look = look, near = near, at = os.clock()}
				local want = p:GetAttribute("DinoSpecies")
				p:SetAttribute("HubPlaceLast", "island " .. tostring(near))
				p:SetAttribute("IslandRespawnNear", near)
				if want == nil or c:GetAttribute("Species") == want then
					diedAt[p] = nil
					bumpI("IslandRespawns")
					p:SetAttribute("IslandRespawnAt", now()) -- last: the client shows the button
				end
				return
			end
			bumpI("IslandRespawnFallbacks")
			diedAt[p] = nil
		end
		return rawPlaceV18(p, fixes)
	end
	local req = ReplicatedStorage:FindFirstChild("HubIslandRequest")
	if not req then
		req = Instance.new("RemoteEvent")
		req.Name = "HubIslandRequest"
		req.Parent = ReplicatedStorage
	end
	req.OnServerEvent:Connect(function(p, action)
		if action ~= "pad" or not islandOn() then return end
		local at = tonumber(p:GetAttribute("IslandRespawnAt"))
		if not at or now() - at > (tonumber(script:GetAttribute("IslandPadWindow")) or 2.5) then return end
		local r = rootOf(p)
		if not r or p:GetAttribute("InMenu") == true then return end
		p:SetAttribute("IslandRespawnAt", nil)
		lastSpot[p] = nil
		rawPlaceV18(p, nil)
		p:SetAttribute("HubPlaceLast", "pad")
		p:SetAttribute("IslandPadAt", now())
		bumpI("IslandPadReturns")
	end)
end

''' + a))
JOBS["HubServer"] = ("src/server/HubServer/init.server.luau", SSS + "HubServer", H)
