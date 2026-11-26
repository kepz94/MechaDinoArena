-- HubLockRules v1.0 (Mecha Dino Arena) — which actions the island spawn lock stops (ModuleScript, StarterPlayerScripts). Plan
-- docs/plans/SPAWN_LOCK_v1.0.md Task 1; Kepu 2026-11-26 "having attack buttons locked on spawn and up until the timer goes down",
-- picks "Island PROTECTED timer", "Attacks only".
-- The lock is on while the character attribute HubSafe is true (HubServer: on the islet, or HubRules.GUARD 3 s after leaving it;
-- a HubSafe dino already can't hurt or be hurt) and the calling script's switch is on.
-- ATTACK_PARTS = the mecha parts whose type is ATTACK or CONTROL (Tutorial SC_INFO, 2026-11-26): they stay locked. MOVE / DEFENSE /
--   HEAL / STEALTH / SCOUT / SUPPORT / PASSIVE parts keep working. ATTACK_MOVES = the main-attack moves (AbilityBar MOVES names)
--   and ATTACK_BUTTONS = the phone's main-attack buttons (ArenaTouch names); LEAP / HOP / RUN are not in them.
-- isAttackPart(id) -> bool; isAttackMove(name) -> bool; isAttackButton(name) -> bool; locked(char, switchOn) -> bool.
local M = {}
M.Version = "1.0"
M.ATTACK_PARTS = {}
for _, id in ipairs({
	-- ATTACK
	"traps", "bloodrush", "quills", "cmissile", "tmortar", "zhook", "zfeather", "dgatling", "dmortar", "dspine", "dover", "dscope", "osentry",
	-- CONTROL
	"screech", "hookarm", "ink", "tether", "strobe", "caltrops", "goo", "tgrab", "tstomp", "tchallenge", "zharvest", "zsnare", "dhiss",
	"olantern", "osleep",
}) do M.ATTACK_PARTS[id] = true end
M.ATTACK_MOVES = {Bite = true, Pounce = true, Ram = true, Headbutt = true, Slash = true, TenoAttack = true, TheriAttack = true,
	DiloAttack = true, TrooAttack = true}
M.ATTACK_BUTTONS = {Bite = true, PounceMain = true, Ram = true, HeadbuttMain = true, SlashMain = true, TenoMain = true, TheriMain = true,
	DiloMain = true, TrooMain = true}

function M.isAttackPart(id) return type(id) == "string" and M.ATTACK_PARTS[id] == true end
function M.isAttackMove(name) return type(name) == "string" and M.ATTACK_MOVES[name] == true end
function M.isAttackButton(name) return type(name) == "string" and M.ATTACK_BUTTONS[name] == true end
function M.locked(char, switchOn)
	return switchOn ~= false and char ~= nil and char:GetAttribute("HubSafe") == true
end

return M
