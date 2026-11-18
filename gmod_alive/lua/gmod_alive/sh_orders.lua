-- ============================================================================
-- GMod Alive (fork) - NPC Orders & Extra Actions
-- Shared definitions (sh_orders.lua)
-- Must load AFTER sh_rules.lua (it extends GA.RuleOptions, GA.SupportedActions
-- and GA.NPCActionRules).
-- ============================================================================

local GA = GModAlive

-- Extra rules. They are appended to GA.RuleOptions, so the existing
-- "NPC rules" page in F6 shows them as checkboxes automatically.
local extraRules = {
	{ id = "orders",              label = "Allow NPCs to give orders to other NPCs",                 default = "1" },
	{ id = "orders_always_obey",  label = "Ordered NPCs always obey (ignore rank and attitude)",     default = "0" },
	{ id = "orders_spoken_reply", label = "Ordered NPCs answer out loud (uses one extra AI request)", default = "1" }
}

for _, rule in ipairs(extraRules) do
	GA.RuleOptions[#GA.RuleOptions + 1] = { id = rule.id, label = rule.label }
	CreateConVar("gmod_alive_rule_" .. rule.id, rule.default, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, rule.label)
end

CreateConVar("gmod_alive_orders_max", "8", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Maximum number of NPC orders active at the same time", 1, 30)

-- New action tags the AI may emit (parsed by GA.ParseAIResponse).
for _, tag in ipairs({
	"OrderNPC",
	"CallForHelp",
	"HealNPC",
	"Gesture",
	"GuardPosition",
	"PatrolArea",
	"ProtectTarget"
}) do
	table.insert(GA.SupportedActions, tag)
end

GA.OrderRules = [=[
COMMAND RULES (NPCs commanding NPCs): ACTION_CONTEXT.nearby_npcs lists each nearby NPC with its id, rank (higher = more authority) and attitude_towards_them. Give an order only when it suits your character, your rank and the situation, for example when the player asks you to command someone, or when you are an officer or leader. The server decides whether the other NPC obeys; never claim obedience before it is confirmed (see ACTION_CONTEXT.recent_orders).
Order format: [OrderNPC=id:Verb] or [OrderNPC=id:Verb:arg]. id may be the word all (up to four nearby friendly NPCs). Verbs: Follow:arg (follow arg), Come:arg (walk to arg), Protect:arg (bodyguard arg), Guard (hold the spot where they stand), Wait, Patrol, Stop (stand down), Attack:targetId, Flee:targetId, Heal:targetId, Fetch:itemId. Use the word player as targetId/arg to mean the PLAYER and me to mean yourself. IMPORTANT: when the player says "follow ME", "come to ME" or "protect ME" and you order another NPC, ALWAYS write [OrderNPC=<id>:Follow:player] (or Come:player / Protect:player), NEVER leave the arg empty or use me, otherwise they follow you instead of the player. Only use ids listed in context.
Other tags: [CallForHelp] shouts so nearby allies come or join your fight; [HealNPC=id] you heal a listed NPC with your own medkit; [GuardPosition] and [PatrolArea] you guard or patrol on your own; [ProtectTarget] or [ProtectTarget=id] you bodyguard the player or a listed NPC; [Gesture=wave|salute|halt|forward|bow|agree|disagree|cheer] plays an animation (only works if the model has it).
Never use order tags when you are replying to another NPC's order or in NPC-to-NPC chatter. Still at most ONE tag per reply.
]=]

GA.NPCActionRules = GA.NPCActionRules .. "\n" .. GA.OrderRules
