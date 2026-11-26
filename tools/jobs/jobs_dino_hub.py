"""Island DINO hub (Kepu 2026-11-26 15:39). Run: python3 -I tools/launch_patch.py <outdir> tools/jobs/jobs_dino_hub.py"""
Q = ('Kepu 2026-11-26 15:39 "I think the main problem is the menu button. When I click Dino I don\'t have much options on what to do, '
     'the Skill button is also kind of redundant. I tried to edit my Dino skins and emotes and trails but the only way I can do that '
     'is go all the way to the main menu. Also the Dino options on the island only have mecha parts but not even descriptions, it\'s '
     'just not consistent"; standing pick: recommended option')
SSS = 'game:GetService("ServerScriptService").'
SPS = 'game:GetService("StarterPlayer").StarterPlayerScripts.'
JOBS = {}

# ---------------- Lab 2.4 ----------------
L = []
a = 'VERSION = "2.3" -- v2.3 no STATS tab while every stat is maxed\n'
L.append((a, a + '''VERSION = "2.4" -- v2.4 island DINO hub
-- v2.4 (''' + Q + '''): the island Lab is the one DINO place.
--   * The island pill (ScreenGui "LabButton", TextButton "Skills", same spot, size, badge, phone drawer slot) reads "DINO" instead of
--     "SKILLS" (read at start). IslandDino 1.1 hides its own DINO pill while this is on, so there is one DINO button.
--   * The compact Lab on the hub (ReplicatedStorage ServerKind "hub", player PrInMatch / PrInLobby not true) shows the LOOKS tabs as
--     the full Lab does: ABILITIES | SKINS | EMOTES | TRAILS (STATS stays hidden while every stat is maxed, Lab 2.3). Equips and buys
--     go through the same remotes; SkinServer 1.9 accepts skin equips / buys on the hub out of the menu. Match servers keep the
--     1.x compact Lab (ABILITIES only).
--   * CHANGE DINO (TextButton "ChangeDino" in the top bar, left of the points chip; panel fill, yellow stroke, FredokaOne, height =
--     the X button (>= LabMinTap 44)): shown in the compact Lab on the hub. Tap -> the Lab closes, player IslandPickToLab = true and
--     IslandPickOpen = true (local): PregameScreen 1.9 shows the dino step; picking a dino (or BACK) closes it and reopens this Lab
--     on your new dino (descriptions in the detail sheet), instead of the parts step without descriptions. IslandPickToLab is
--     cleared when the picker closes another way.
--   Switch: script attribute LabIslandHubEnabled (true; pill text read at start, tabs / CHANGE DINO read per draw; false = 2.3).
--   Diagnostic: player LabLastPress "changeDino".
--   New code lives in the script-global table L4 (the main chunk is at the 200-local limit).
''' + 'if script:GetAttribute("LabIslandHubEnabled") == nil then script:SetAttribute("LabIslandHubEnabled", true) end -- v2.4\n'
             + 'L4 = {} -- v2.4: island DINO hub helpers (script-global, as EMO / TRL / L2 / L3)\n'))
a = 'local function useUni() return uniSkinsOn and uniMod() ~= nil end\n'
L.append((a, '''function L4.islandHub() -- v2.4: the compact Lab on the main island
	return script:GetAttribute("LabIslandHubEnabled") ~= false and ReplicatedStorage:GetAttribute("ServerKind") == "hub"
		and player:GetAttribute("PrInMatch") ~= true and player:GetAttribute("PrInLobby") ~= true
end
function L4.looksMode() return mode == "full" or (mode == "compact" and L4.islandHub()) end -- v2.4: LOOKS tabs here
''' + a))
a = 'local function uniTab() return useUni() and tab == "skins" and mode == "full" end\n'
L.append((a, 'local function uniTab() return useUni() and tab == "skins" and L4.looksMode() end -- v2.4: was mode == "full"\n'))
a = '\tlocal full = skinsOn and mode == "full"\n'
L.append((a, '\tlocal full = skinsOn and L4.looksMode() -- v2.4: was mode == "full"\n'))
a = 'function L2.openLooks(kind)\n\tif not (skinsOn and mode == "full") then return end\n'
L.append((a, 'function L2.openLooks(kind)\n\tif not (skinsOn and L4.looksMode()) then return end -- v2.4: was mode == "full"\n'))
a = 'tabSkins.Activated:Connect(function() -- v1.6\n\tif not (skinsOn and mode == "full") then return end\n'
L.append((a, 'tabSkins.Activated:Connect(function() -- v1.6\n\tif not (skinsOn and L4.looksMode()) then return end -- v2.4: was mode == "full"\n'))
a = '\t\tif kind ~= "full" and tab == "skins" then tab = "parts" end -- v1.6: SKINS only in the full Lab\n'
L.append((a, '\t\tif kind ~= "full" and tab == "skins" and not L4.looksMode() then tab = "parts" end -- v1.6: SKINS only in the full Lab (v2.4: and the island Lab)\n'))
a = 'closeX.Size = UDim2.fromScale(1, 1)\n'
L.append((a, a + '''L4.chgB = button(barRight, "ChangeDino", PANEL) -- v2.4: CHANGE DINO (island Lab)
L4.chgB.LayoutOrder = 0
L4.chgB.AutomaticSize = Enum.AutomaticSize.X
L4.chgB.Visible = false
L4.chgCorner = corner(L4.chgB)
stroke(L4.chgB, YELLOW, 0.2, 2)
L4.chgPad = pad(L4.chgB, 12)
L4.chgL = label(L4.chgB, "T", Enum.Font.FredokaOne, 16, WHITE, "CHANGE DINO")
L4.chgL.AutomaticSize = Enum.AutomaticSize.X
'''))
a = '\tcloseX.TextSize = math.max(2.4 * ch, 14)\n'
L.append((a, a + '''	L4.chgB.Visible = mode == "compact" and L4.islandHub() -- v2.4
	L4.chgB.Size = UDim2.fromOffset(0, S.closeS)
	L4.chgCorner.CornerRadius = UDim.new(0, 1.6 * ch)
	L4.chgPad.PaddingLeft, L4.chgPad.PaddingRight = UDim.new(0, 1.6 * ch), UDim.new(0, 1.6 * ch)
	L4.chgL.TextSize = math.max(2.2 * ch, 13)
	L4.chgL.Size = UDim2.fromOffset(0, S.closeS)
'''))
a = 'closeB.Activated:Connect(function() press("close") setOpen(nil) end)\n'
L.append((a, a + '''L4.chgB.Activated:Connect(function() -- v2.4: CHANGE DINO -> the island picker, back to this Lab after (PregameScreen 1.9)
	if not (mode == "compact" and L4.islandHub()) then return end
	press("changeDino")
	setOpen(nil)
	player:SetAttribute("IslandPickToLab", true)
	player:SetAttribute("IslandPickOpen", true)
end)
player:GetAttributeChangedSignal("IslandPickOpen"):Connect(function() -- v2.4: closed another way -> no return trip
	if player:GetAttribute("IslandPickOpen") ~= true then
		task.delay(0.3, function()
			if player:GetAttribute("IslandPickOpen") ~= true then player:SetAttribute("IslandPickToLab", nil) end
		end)
	end
end)
'''))
a = 'lbText.TextStrokeTransparency = 0.6\n'
L.append((a, a + 'if script:GetAttribute("LabIslandHubEnabled") ~= false then lbText.Text = "DINO" end -- v2.4: one DINO button\n'))
JOBS["Lab"] = ("src/client/Lab.client.luau", SPS + "Lab", L)

# ---------------- IslandDino 1.1 ----------------
D = []
a = 'local VERSION = "1.0"\n'
D.append((a, a + '''VERSION = "1.1" -- v1.1 yields to the Lab's DINO pill
-- v1.1 (''' + Q + '''): while the Lab's script attribute LabIslandHubEnabled is not false (Lab 2.4: its pill reads DINO and opens the
--   island Lab with abilities, looks and CHANGE DINO), this pill stays hidden, so there is one DINO button. Switch: script attribute
--   IslandDinoYieldEnabled (true, read per frame; false = 1.0 pill shown as well).
'''))
a = '\t\tand player:GetAttribute("IslandPickOpen") ~= true\n'
D.append((a, a + '''	if on and script:GetAttribute("IslandDinoYieldEnabled") ~= false then -- v1.1
		local ps = player:FindFirstChild("PlayerScripts")
		local lab = ps and ps:FindFirstChild("Lab")
		if lab and lab:GetAttribute("LabIslandHubEnabled") ~= false then on = false end
	end
'''))
JOBS["IslandDino"] = ("src/client/IslandDino.client.luau", SPS + "IslandDino", D)

# ---------------- PregameScreen 1.9 ----------------
P = []
a = 'VERSION = "1.8" -- v1.8 coming soon + locked dinos\n'
P.append((a, a + '''VERSION = "1.9" -- v1.9 island pick back to the Lab
-- v1.9 (''' + Q + '''): island mode opened from the Lab's CHANGE DINO (player IslandPickToLab = true, Lab 2.4): SELECT on the dino step
--   sends the swap as before (DinoSpeciesRequest), then closes the screen (IslandPickOpen = false) instead of going to the parts step,
--   and reopens the island Lab (PlayerScripts.Lab.Open "compact") once your character is the picked dino (Species attribute, up to
--   PregameToLabWait 6 s); BACK on the dino step closes it and reopens the Lab too. Locked / coming soon dinos behave as 1.8.
--   Switch: script attribute PregameIslandToLabEnabled (true, read per press; false = 1.8 parts step). Diagnostic PregameToLab (count).
'''))
a = 'backBtn.Activated:Connect(function()\n'
P.append((a, '''local function toLab(want) -- v1.9: close the island pick, reopen the island Lab on the (new) dino
	player:SetAttribute("IslandPickToLab", nil)
	player:SetAttribute("IslandPickOpen", false)
	setGhost(nil)
	setView("hidden")
	script:SetAttribute("PregameToLab", (script:GetAttribute("PregameToLab") or 0) + 1)
	task.spawn(function()
		local t0 = os.clock()
		local waitMax = tonumber(script:GetAttribute("PregameToLabWait")) or 6
		while want and os.clock() - t0 < waitMax do
			local c = player.Character
			if c and c:GetAttribute("Species") == want then break end
			task.wait(0.1)
		end
		task.wait(0.3)
		if player:GetAttribute("InMenu") == true then return end
		local ps = player:FindFirstChild("PlayerScripts")
		local lab = ps and ps:FindFirstChild("Lab")
		local open = lab and lab:FindFirstChild("Open")
		if open then pcall(function() open:Invoke("compact") end) end
	end)
end
local function toLabOn() -- v1.9
	return islandMode() and player:GetAttribute("IslandPickToLab") == true and script:GetAttribute("PregameIslandToLabEnabled") ~= false
end
''' + a))
a = '\t\tpress("back")\n\t\tif respawnMode() then respawnFire("close") setView("hidden") -- v1.4\n'
P.append((a, '\t\tpress("back")\n\t\tif toLabOn() then toLab(nil) return end -- v1.9\n\t\tif respawnMode() then respawnFire("close") setView("hidden") -- v1.4\n'))
a = '\t\t\tif respawnMode() then respawnFire("dino", sel.draft) -- v1.4\n\t\t\telseif speciesRemote then speciesRemote:FireServer(sel.draft) end\n\t\tend\n\t\tsel.step = "parts"\n'
P.append((a, '\t\t\tif respawnMode() then respawnFire("dino", sel.draft) -- v1.4\n\t\t\telseif speciesRemote then speciesRemote:FireServer(sel.draft) end\n\t\tend\n'
             '\t\tif toLabOn() then toLab(sel.draft) return end -- v1.9: back to the island Lab, not the parts step\n\t\tsel.step = "parts"\n'))
JOBS["PregameScreen"] = ("src/client/PregameScreen.client.luau", SPS + "PregameScreen", P)

# ---------------- SkinServer 1.9 ----------------
K = []
a = 'VERSION = "1.8" -- v1.8 dino receipts + launch reset\n'
K.append((a, a + '''VERSION = "1.9" -- v1.9 skins on the island
-- v1.9 (''' + Q + '''): skin equip / buy requests also pass the "notInMenu" check on the main island (ReplicatedStorage ServerKind
--   "hub", player PrInMatch / PrInLobby not true), where the island Lab (Lab 2.4) shows SKINS; an equip for the dino you are
--   repaints your body at once (dress, as before). A skin bought there is equipped at once too ("bought", as in the menu).
--   Match servers unchanged. Switch: script attribute SkinIslandEquipEnabled (true, read per request).
if script:GetAttribute("SkinIslandEquipEnabled") == nil then script:SetAttribute("SkinIslandEquipEnabled", true) end
local function menuOk(player) -- v1.9: in the menu, or on the main island
	if player:GetAttribute("InMenu") == true then return true end
	return script:GetAttribute("SkinIslandEquipEnabled") ~= false and ReplicatedStorage:GetAttribute("ServerKind") == "hub"
		and player:GetAttribute("PrInMatch") ~= true and player:GetAttribute("PrInLobby") ~= true
end
'''))
for tail in ['\n\telseif not (char and char.Parent and species) then\n\t\tresult = "noBody"\n\telseif not sk then',
             '\n\telseif species == nil and not (char',
             '\n\telseif not species then',
             '\n\telseif not (char and char.Parent and species) then\n\t\tresult = "noBody"\n\telseif not SC.get(species, id)']:
    K.append(('elseif player:GetAttribute("InMenu") ~= true then\n\t\tresult = "notInMenu"' + tail,
              'elseif not menuOk(player) then -- v1.9: was InMenu ~= true\n\t\tresult = "notInMenu"' + tail))
a = '\t\tif player:GetAttribute("InMenu") == true then\n\t\t\tequipBought('
K.append((a, '\t\tif menuOk(player) then -- v1.9: was InMenu == true\n\t\t\tequipBought('))
JOBS["SkinServer"] = ("src/server/SkinServer.server.luau", SSS + "SkinServer", K)
