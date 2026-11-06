-- TenoPoseFix v1.0 (Mecha Dino Arena) — two fixes for the teno's own character on its owner's client (LocalScript in
-- StarterPlayerScripts). Kepu 2026-11-05 17:40: "The jump is like glitching when I land". Studio (v460, frame recording):
--   * the landing tail slam (TenoPose "tland", SLAM_DOWN2) and the mortar wind-up (MORTAR_COIL) push the tail into the
--     ground; the tail hitboxes (DinoHitboxes 1.2: Hitbox_Tail1..5 CanCollide true, so the tail can't pass into the world)
--     then lift the whole body: the root rose 2.4 - 3.2 studs and fell back over ~0.5 s ("pop").
--   * the slam began ~0.2 s after the touchdown, when the server's TenoLeapLandedAt arrived.
-- What it does (only the local player's character, Species "Teno"):
--   * tail clip: while the character's TenoPoseState (IdleAnimation 1.37+) is one of TAIL_DOWN ("tland", "tmortar",
--     "tgrab", "tleap"), every Hitbox_Tail* part of its Hitboxes folder that collides is set CanCollide false on this client
--     (the owner simulates its own character, so the body no longer rides up on its tail) and put back to true when the state
--     ends (or the switch goes off). Bites / hits are unchanged (CanQuery is not touched). Checked every Stepped.
--   * local landing: a jump that rose at least LAND_RISE (2) studs above where it left the ground, while the character's
--     TenoLeapOnJump is true and JumpStartedAt (JumpServer) is younger than 3 s, stamps the character's TenoLocalLandAt
--     (server time) when the Humanoid lands. TenoPose 1.10 starts the owner's "tland" slam from it. Local only (not
--     replicated); other players still see the slam at the server's stamp.
-- Switches: script attributes TenoTailClipEnabled, TenoLocalLandEnabled (default true each, read each frame / each landing).
-- Diagnostics: script TenoPoseFixVersion; character TenoTailClipActive (true while the tail passes through), TenoLocalLandAt.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local LAND_RISE = 2
local TAIL_DOWN = {tland = true, tmortar = true, tgrab = true, tleap = true}
script:SetAttribute("TenoPoseFixVersion", VERSION)
if script:GetAttribute("TenoTailClipEnabled") == nil then script:SetAttribute("TenoTailClipEnabled", true) end
if script:GetAttribute("TenoLocalLandEnabled") == nil then script:SetAttribute("TenoLocalLandEnabled", true) end

local player = Players.LocalPlayer
local char, clipped = nil, {} -- clipped: [part] = true (we turned its collision off)

local function tailBoxes(c)
	local out = {}
	local f = c:FindFirstChild("Hitboxes")
	if f then for _, d in ipairs(f:GetChildren()) do if d:IsA("BasePart") and d.Name:sub(1, 11) == "Hitbox_Tail" then table.insert(out, d) end end end
	return out
end
local function restore()
	for p in pairs(clipped) do if p.Parent then p.CanCollide = true end end
	clipped = {}
	if char and char:GetAttribute("TenoTailClipActive") then char:SetAttribute("TenoTailClipActive", false) end
end

RunService.Stepped:Connect(function()
	local c = player.Character
	if c ~= char then restore() char = c end
	if not c then return end
	local want = script:GetAttribute("TenoTailClipEnabled") ~= false and c:GetAttribute("Species") == "Teno"
		and TAIL_DOWN[c:GetAttribute("TenoPoseState") or ""] == true
	if want then
		for _, p in ipairs(tailBoxes(c)) do
			if p.CanCollide then p.CanCollide = false clipped[p] = true end
		end
		if not c:GetAttribute("TenoTailClipActive") then c:SetAttribute("TenoTailClipActive", true) end
	elseif next(clipped) then
		restore()
	end
end)

-- local landing
local function watch(c)
	local hum = c:WaitForChild("Humanoid", 10)
	local root = c:WaitForChild("HumanoidRootPart", 10)
	if not (hum and root) then return end
	local groundY, peakY, airborne = root.Position.Y, root.Position.Y, false
	RunService.Heartbeat:Connect(function()
		if not root.Parent then return end
		if airborne then peakY = math.max(peakY, root.Position.Y) elseif hum.FloorMaterial ~= Enum.Material.Air then groundY = root.Position.Y end
	end)
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping or new == Enum.HumanoidStateType.Freefall then
			if not airborne then airborne, peakY = true, root.Position.Y end
		elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running or new == Enum.HumanoidStateType.RunningNoPhysics then
			if airborne then
				airborne = false
				local now = workspace:GetServerTimeNow()
				local js = tonumber(c:GetAttribute("JumpStartedAt"))
				if script:GetAttribute("TenoLocalLandEnabled") ~= false and c:GetAttribute("Species") == "Teno" and c:GetAttribute("TenoLeapOnJump") == true
					and js and now - js < 3 and peakY - groundY >= LAND_RISE then
					c:SetAttribute("TenoLocalLandAt", now)
				end
			end
		end
	end)
end
player.CharacterAdded:Connect(watch)
if player.Character then task.spawn(watch, player.Character) end
