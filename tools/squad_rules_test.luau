-- squad_rules_test v1.0 — Studio check for SquadRules 1.0 (MDA-158). Run in the Edit or Server datamodel with execute_luau.
-- Pure rows (sameIds) + the instance rows (same / sameChar / idOf) with temporary attributes, put back after.
local R = require(game:GetService("ServerStorage").DinoArcade.SquadRules)
local RS = game:GetService("ReplicatedStorage")
local fails, n = {}, 0
local function check(name, got, want)
	n += 1
	if got ~= want then table.insert(fails, name .. ": got " .. tostring(got) .. " want " .. tostring(want)) end
end
-- pure
check("live off", R.sameIds(false, "a", "a", false), false)
check("live nil", R.sameIds(nil, "a", "a", false), false)
check("same id", R.sameIds(true, "a", "a", false), true)
check("diff id", R.sameIds(true, "a", "b", false), false)
check("both empty", R.sameIds(true, "", "", false), false)
check("self", R.sameIds(true, "a", "a", true), false)
check("nil id", R.sameIds(true, nil, "a", false), false)
check("number id", R.sameIds(true, 1, 1, false), false)
-- instances (two plain models with SquadTestId stand in for squad members)
local oldLive = RS:GetAttribute("SquadsLive")
local a, b, c = Instance.new("Model"), Instance.new("Model"), Instance.new("Model")
a:SetAttribute("SquadTestId", "x_1"); b:SetAttribute("SquadTestId", "x_1"); c:SetAttribute("SquadTestId", "y_2")
RS:SetAttribute("SquadsLive", true)
check("idOf a", R.idOf(a), "x_1")
check("idOf nil", R.idOf(nil), "")
check("sameChar a b", R.sameChar(a, b), true)
check("sameChar a c", R.sameChar(a, c), false)
check("sameChar a a", R.sameChar(a, a), false)
check("sameChar a nil", R.sameChar(a, nil), false)
check("same nil nil", R.same(nil, nil), false)
check("members empty", #R.members(""), 0)
RS:SetAttribute("SquadsLive", false)
check("sameChar not live", R.sameChar(a, b), false)
RS:SetAttribute("SquadsLive", oldLive)
a:Destroy(); b:Destroy(); c:Destroy()
return (#fails == 0 and "PASS " or "FAIL ") .. n .. " checks" .. (#fails > 0 and ("\n" .. table.concat(fails, "\n")) or "")
