-- TeamTagShare v1.0 (Mecha Dino Arena) — gives clients the friend / foe rules. MDA-416, plan docs/plans/TEAM_TAGS_v1.0.md Task 1.
-- Clones ServerStorage.DinoArcade.TeamTagRules into a Folder ReplicatedStorage.TeamTagShared (made once; an existing one is
-- kept). TeamTags 1.0 (client) requires ReplicatedStorage.TeamTagShared.TeamTagRules. Diagnostic: TeamTagShareVersion,
-- TeamTagShareState ("ok" / "noRules").
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.0"
script:SetAttribute("TeamTagShareVersion", VERSION)
local rules = ServerStorage:WaitForChild("DinoArcade"):WaitForChild("TeamTagRules", 30)
if not rules then
	script:SetAttribute("TeamTagShareState", "noRules")
	return
end
local f = ReplicatedStorage:FindFirstChild("TeamTagShared")
if not f then
	f = Instance.new("Folder")
	f.Name = "TeamTagShared"
	rules:Clone().Parent = f
	f.Parent = ReplicatedStorage
end
script:SetAttribute("TeamTagShareState", "ok")
