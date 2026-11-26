-- HubLockRules.spec v1.0 (Mecha Dino Arena) — run in Studio Edit; returns "PASS n" or "FAIL ...".
local src = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("HubLockRules")
if not src then return "FAIL missing StarterPlayerScripts.HubLockRules" end
local ok, R = pcall(function() local c = src:Clone() c.Parent = workspace local m = require(c) c:Destroy() return m end)
if not ok then return "FAIL require: " .. tostring(R) end
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local n = 0 for _ in pairs(R.ATTACK_PARTS) do n += 1 end
eq("28 attack parts", n, 28)
for _, id in ipairs({"quills", "screech", "tether", "dscope", "osleep"}) do eq("attack " .. id, R.isAttackPart(id), true) end
for _, id in ipairs({"thrusters", "glider", "mechalegs", "tleap", "shield", "cloak", "adrenaline", "medstation", "scent", "tbellow", "zclock"}) do
	eq("not attack " .. id, R.isAttackPart(id), false)
end
eq("nil part", R.isAttackPart(nil), false)
eq("move Bite", R.isAttackMove("Bite"), true)
eq("move Leap", R.isAttackMove("Leap"), false)
eq("move Hop", R.isAttackMove("Hop"), false)
eq("button TrooMain", R.isAttackButton("TrooMain"), true)
eq("button Leap", R.isAttackButton("Leap"), false)
eq("button Run", R.isAttackButton("Run"), false)
local okST, ST = pcall(function() return require(game:GetService("ServerStorage").DinoArcade.SkillTree) end)
for id in pairs(R.ATTACK_PARTS) do eq("in SkillTree " .. id, okST and ST.PATHS[id] ~= nil, true) end
local fake = Instance.new("Model")
eq("locked off (no HubSafe)", R.locked(fake, true), false)
fake:SetAttribute("HubSafe", true)
eq("locked on", R.locked(fake, true), true)
eq("switch off", R.locked(fake, false), false)
eq("switch nil = on", R.locked(fake, nil), true)
eq("no char", R.locked(nil, true), false)
fake:Destroy()
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, "; ") end
return "PASS " .. passes
