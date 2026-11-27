"""First Steps v1.0 (Kepu 2026-11-27 14:15 pick "A" on docs/mockups/first_steps_v0.1.html): edits to existing scripts.
New scripts (FirstStepsServer 1.0, FirstSteps 1.0) are installed whole by tools/jobs/install_new.py.
* HubServer 1.10: HubQueueRequest("join") joins the Arena queue like walking into the ARENA portal.
* Tutorial 1.8: step 10 -> PLAY YOUR FIRST MATCH (+ the LOCAL attribute FsAutoQueue) and EXPLORE THE ISLAND FIRST.
* PlaytimeClient 1.2: the gift chip hides while the player is in the Arena queue (it sat under the FINDING MATCH pill on phones).
Run: python3 -I tools/launch_patch.py <outdir> tools/jobs/jobs_firststeps.py"""
SSS = 'game:GetService("ServerScriptService").'
SPS = 'game:GetService("StarterPlayer").StarterPlayerScripts.'
JOBS = {}

H = []
a = 'VERSION = "1.9" -- v1.9 island respawn + return to pad\n'
H.append((a, a + '''VERSION = "1.10" -- v1.10 HubQueueRequest "join" (the lobby PLAY button)
-- v1.10 (First Steps v1.0, Kepu 2026-11-27 14:15 pick "A" on docs/mockups/first_steps_v0.1.html, the island lobby's PLAY button,
--   FirstSteps 1.0): RemoteEvent HubQueueRequest also takes "join": the same as walking into the ARENA portal (joinQueue: the squad
--   leader brings the squad, others get HubLastResult "notLeader"; already queued / in a trip -> nothing), only while the queue is on
--   (queueOn()), the player is not InMenu and its character is alive. Switch: script attribute HubQueueJoinRequestEnabled (default
--   true, read per request; false = 1.9, "join" ignored). Diagnostic: player HubJoinLast ("ok" / "busy" / "notLeader" / "off" /
--   "menu" / "dead").
'''))
a = '''		if action == "leave" then leaveQueue(p) end
'''
H.append((a, a + '''		if action == "join" then -- v1.10: the lobby PLAY button
			local r
			if script:GetAttribute("HubQueueJoinRequestEnabled") == false or not queueOn() then
				r = "off"
			elseif p:GetAttribute("InMenu") == true then
				r = "menu"
			else
				local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
				if not hum or hum.Health <= 0 then r = "dead" else r = joinQueue(p) end
			end
			p:SetAttribute("HubJoinLast", r)
		end
'''))
JOBS["HubServer"] = ("src/server/HubServer/init.server.luau", SSS + "HubServer", H)

T = []
a = 'VERSION = "1.7.1" -- v1.7.1 the reveal\'s dino fits (wider camera)\n'
T.append((a, a + '''VERSION = "1.8" -- v1.8 the tutorial ends with the first match
-- v1.8 (First Steps v1.0, Kepu 2026-11-27 14:15 pick "A" on docs/mockups/first_steps_v0.1.html, capture first_steps_v0.1/
--   phone_tutorial_end.jpg): while script attribute TutFirstMatchEnabled ~= false (default true, read per draw) step 10 reads
--   "TRAINING COMPLETE" / "LEVEL <n> <DINO>" / "Next: a real 4v4 match. Bots fill empty seats." with PLAY YOUR FIRST MATCH (yellow;
--   sets the LOCAL player attribute FsAutoQueue = true, then sends "island" as before; FirstSteps 1.0 joins the Arena queue once the
--   dino stands on the islet) and under it EXPLORE THE ISLAND FIRST (no fill, muted text, no outline; sends "island" only).
--   TutFirstMatchEnabled false = 1.7.1 (GO TO THE ISLAND).
'''))
a = '''		local col, add = sceneColumn("TRAINING COMPLETE", "LEVEL " .. tostring(player:GetAttribute("SkillLevel") or 1) .. " " .. string.upper(dinoName(dino)),
			k .. " parts equipped")
		add(cta(col, "GO TO THE ISLAND", function() send("island") end))
'''
T.append((a, '''		if script:GetAttribute("TutFirstMatchEnabled") ~= false then -- v1.8: the first match
			local col, add = sceneColumn("TRAINING COMPLETE", "LEVEL " .. tostring(player:GetAttribute("SkillLevel") or 1) .. " " .. string.upper(dinoName(dino)),
				"Next: a real 4v4 match. Bots fill empty seats.")
			add(cta(col, "PLAY YOUR FIRST MATCH", function() player:SetAttribute("FsAutoQueue", true) send("island") end))
			local ex = cta(col, "EXPLORE THE ISLAND FIRST", function() player:SetAttribute("FsAutoQueue", nil) send("island") end,
				{BackgroundTransparency = 1, TextColor3 = C.muted})
			for _, c in ipairs(ex:GetChildren()) do if c:IsA("UIStroke") then c:Destroy() end end
			add(ex)
		else
		local col, add = sceneColumn("TRAINING COMPLETE", "LEVEL " .. tostring(player:GetAttribute("SkillLevel") or 1) .. " " .. string.upper(dinoName(dino)),
			k .. " parts equipped")
		add(cta(col, "GO TO THE ISLAND", function() send("island") end))
		end
'''))
JOBS["Tutorial"] = ("src/client/Tutorial.client.luau", SPS + "Tutorial", T)

P = []
a = 'VERSION = "1.1" -- v1.1 track capped at 30 min\n'
P.append((a, a + '''VERSION = "1.2" -- v1.2 chip hides while queued
-- v1.2 (First Steps v1.0, Kepu 2026-11-27; found in the mockup test docs/mockups/first_steps_v0.1/phone_queue_overlap_today.jpg: on
--   phones the Arena queue pill "FINDING MATCH" (PortalHUD) sat on top of this chip, both top centre): while script attribute
--   PlaytimeChipQueueHideEnabled ~= false (default true, read per frame) the chip (and the track) hide while player HubQueueState is
--   "queued" or "found". false = 1.1.
'''))
a = '''	if (tonumber(player:GetAttribute("TutLane")) or 0) > 0 then return false end
	local tut = pg:FindFirstChild("Tutorial")
'''
P.append((a, '''	if (tonumber(player:GetAttribute("TutLane")) or 0) > 0 then return false end
	if script:GetAttribute("PlaytimeChipQueueHideEnabled") ~= false then -- v1.2: the queue pill takes the top centre
		local qs = player:GetAttribute("HubQueueState")
		if qs == "queued" or qs == "found" then return false end
	end
	local tut = pg:FindFirstChild("Tutorial")
'''))
JOBS["PlaytimeClient"] = ("src/client/PlaytimeClient.client.luau", SPS + "PlaytimeClient", P)
