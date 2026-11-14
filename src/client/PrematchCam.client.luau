-- PrematchCam v1.0 (Mecha Dino Arena) — the camera fly-over during the 10 s pre-match countdown (LocalScript, StarterPlayerScripts).
-- MDA-531, plan docs/plans/PREMATCH_LOCK_PAN_v1.0.md rule 5, mockup docs/mockups/prematch_pan_lock_v0.1.html "A · Fly over"; Kepu
-- 2026-11-13 18:23 "during the countdown for game start the camera should pan to the point then pan back to the dinos".
-- Runs while ReplicatedStorage.Practice PrPrematch == true, ReplicatedStorage.Hardpoint HpPhase == "warmup", you are out of the menu
--   (InMenu ~= true) and your dino is alive. L = HpPointEndsAt - server time (seconds left in the countdown):
--   * L > PanStart (9): the normal camera.
--   * take (once per warm-up, only while PanOrbitAt < L <= PanStart, and never while another script has ShoulderCamExternal):
--     the current camera CFrame / type / FOV are saved, character ShoulderCamExternal = true (ShoulderCam 1.10 stands aside, as
--     for the Dilo scope / Cruise Missile), CameraType Scriptable, character PrematchPanning = true.
--   * out (take -> PanOrbitAt (7)): glides along a curve from the saved view up over a high midpoint (PanHighUp (80) studs above
--     the middle of the way) to the orbit start, looking from the saved look point over to the point; FOV -> PanFov (60).
--   * orbit (PanOrbitAt -> PanBackAt (5)): circles the point (HpPoints[HpIndex], else the first) at PanOrbitRadius (60) studs out
--     and PanOrbitHeight (70) studs up, PanOrbitSpeed (0.35) rad/s, looking at the point; it starts on the side facing your dino.
--   * back (PanBackAt -> PanEndAt (3)): glides from where the orbit is over a high midpoint back to the saved view; FOV back.
--   * L <= PanEndAt, leaving the warm-up, the menu, death or the character going away: the camera is handed back at once (saved
--     type / CFrame / FOV, ShoulderCamExternal false, PrematchPanning false). The last 3 s are free to look around.
--   Late join (L <= PanOrbitAt when it would start): no pan this warm-up.
-- Render step "DinoPrematchCam" at Camera + 8 (after ShoulderCam at Camera and the Cruise cam at Camera + 6).
-- Switch: script attribute PrematchCamEnabled (default true, read per frame; false = no pan, and a running pan hands back).
-- Every number above is a script attribute of the same name. Diagnostics: PrematchCamVersion, PrematchCamState ("off" / "out" /
--   "orbit" / "back" / "done"), PrematchCamPans (pans started).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local VERSION = "1.0"
script:SetAttribute("PrematchCamVersion", VERSION)
for k, v in pairs({PrematchCamEnabled = true, PanStart = 9, PanOrbitAt = 7, PanBackAt = 5, PanEndAt = 3, PanOrbitRadius = 60,
	PanOrbitHeight = 70, PanOrbitSpeed = 0.35, PanHighUp = 80, PanFov = 60, PrematchCamPans = 0}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function cfg(k) return tonumber(script:GetAttribute(k)) or 0 end
local function setState(s) if script:GetAttribute("PrematchCamState") ~= s then script:SetAttribute("PrematchCamState", s) end end
setState("off")

local player = Players.LocalPlayer
local hp = ReplicatedStorage:WaitForChild("Hardpoint", 60)
if not hp then return end

local function smooth(t) t = math.clamp(t, 0, 1) return t * t * (3 - 2 * t) end
local function bezier(a, b, c, t) local u = 1 - t return a * (u * u) + b * (2 * u * t) + c * (t * t) end
local function pointPos()
	local ok, list = pcall(function() return HttpService:JSONDecode(hp:GetAttribute("HpPoints") or "[]") end)
	if not ok or type(list) ~= "table" then return nil end
	local i = tonumber(hp:GetAttribute("HpIndex"))
	local p = (i and list[i]) or list[1]
	if type(p) ~= "table" or not tonumber(p.x) then return nil end
	return Vector3.new(tonumber(p.x), tonumber(p.y) or 0, tonumber(p.z) or 0)
end

local pan = nil -- {saved = {cf, type, fov}, char, p1, a0, takeL, savedLook, ownsExternal}
local doneFor = nil -- the HpPointEndsAt a pan already ran (or was skipped) for

local function release(state)
	if not pan then return end
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = pan.saved.type
		cam.CFrame = pan.saved.cf
		cam.FieldOfView = pan.saved.fov
	end
	if pan.char and pan.char.Parent then
		if pan.ownsExternal then pan.char:SetAttribute("ShoulderCamExternal", false) end
		pan.char:SetAttribute("PrematchPanning", false)
	end
	pan = nil
	setState(state or "done")
end

local function orbitPos(p1, ang)
	return p1 + Vector3.new(math.cos(ang) * cfg("PanOrbitRadius"), cfg("PanOrbitHeight"), math.sin(ang) * cfg("PanOrbitRadius"))
end

local BIND = "DinoPrematchCam"
pcall(function() RunService:UnbindFromRenderStep(BIND) end)
RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 8, function()
	local pr = ReplicatedStorage:FindFirstChild("Practice")
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local ends = tonumber(hp:GetAttribute("HpPointEndsAt")) or 0
	local L = ends - workspace:GetServerTimeNow()
	local on = script:GetAttribute("PrematchCamEnabled") ~= false and pr ~= nil and pr:GetAttribute("PrPrematch") == true
		and hp:GetAttribute("HpPhase") == "warmup" and player:GetAttribute("InMenu") ~= true
		and hum ~= nil and hum.Health > 0 and hrp ~= nil
	if pan then
		if not on or char ~= pan.char or L <= cfg("PanEndAt") then release() return end
	else
		if not on then setState("off") return end
		if doneFor == ends or L > cfg("PanStart") then return end
		doneFor = ends
		if L <= cfg("PanOrbitAt") or char:GetAttribute("ShoulderCamExternal") == true then setState("off") return end -- late / busy
		local p1 = pointPos()
		local cam = workspace.CurrentCamera
		if not (p1 and cam) then return end
		local d = hrp.Position - p1
		pan = {saved = {cf = cam.CFrame, type = cam.CameraType, fov = cam.FieldOfView}, char = char, p1 = p1,
			a0 = math.atan2(d.Z, d.X), takeL = L, ownsExternal = true}
		pan.savedLook = cam.CFrame.Position + cam.CFrame.LookVector * 20
		char:SetAttribute("ShoulderCamExternal", true)
		char:SetAttribute("PrematchPanning", true)
		cam.CameraType = Enum.CameraType.Scriptable
		script:SetAttribute("PrematchCamPans", cfg("PrematchCamPans") + 1)
	end
	local cam = workspace.CurrentCamera
	if not cam then return end
	if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
	local orbitAt, backAt, endAt = cfg("PanOrbitAt"), cfg("PanBackAt"), cfg("PanEndAt")
	local p1, savedPos = pan.p1, pan.saved.cf.Position
	local speed = cfg("PanOrbitSpeed")
	local pos, look, fov
	if L > orbitAt then -- out
		local t = smooth((pan.takeL - L) / math.max(0.05, pan.takeL - orbitAt))
		local o = orbitPos(p1, pan.a0)
		local high = (savedPos + o) / 2 + Vector3.new(0, cfg("PanHighUp"), 0)
		pos = bezier(savedPos, high, o, t)
		look = pan.savedLook:Lerp(p1, t)
		fov = pan.saved.fov + (cfg("PanFov") - pan.saved.fov) * t
		setState("out")
	elseif L > backAt then -- orbit
		pos = orbitPos(p1, pan.a0 + speed * (orbitAt - L))
		look, fov = p1, cfg("PanFov")
		setState("orbit")
	else -- back
		local t = smooth((backAt - L) / math.max(0.05, backAt - endAt))
		local o = orbitPos(p1, pan.a0 + speed * (orbitAt - backAt))
		local high = (savedPos + o) / 2 + Vector3.new(0, cfg("PanHighUp"), 0)
		pos = bezier(o, high, savedPos, t)
		look = p1:Lerp(pan.savedLook, t)
		fov = cfg("PanFov") + (pan.saved.fov - cfg("PanFov")) * t
		setState("back")
	end
	if (look - pos).Magnitude > 0.1 then cam.CFrame = CFrame.lookAt(pos, look) end
	cam.FieldOfView = fov
end)

player.CharacterRemoving:Connect(function() release("off") end)
