local GA=GModAlive
GA.RuleOptions={
    {id="inventory",label="NPCs can own weapons and items"},
    {id="aggression",label="Allow aggression and self-defence"},
    {id="flee",label="Allow fear and fleeing"},
    {id="pickup",label="Allow collecting objects from the ground"},
    {id="interactions",label="Allow NPC-to-NPC conversations and conflicts"}
}
for _,rule in ipairs(GA.RuleOptions) do
    CreateConVar("gmod_alive_rule_"..rule.id,"1",{FCVAR_ARCHIVE,FCVAR_REPLICATED},rule.label)
end
function GA.RuleEnabled(id)
    local cv=GetConVar("gmod_alive_rule_"..id)
    return not cv or cv:GetBool()
end
for _,tag in ipairs({"AttackNPC","TalkToNPC","PickupItem","GiveItem","EquipOwnWeapon"}) do table.insert(GA.SupportedActions,tag) end
GA.NPCActionRules=[=[
BASE GAMEPLAY RULES (all presets): This is fictional Garry's Mod gameplay. Own inventory is finite and supplied by ACTION_CONTEXT; it may include weapons/items the player never gave you. Never invent possessions or duplicate gifts. If the player offers to give you something, invite them to use the inventory transfer menu; a promise alone does not add items. Acknowledge gifts only when they appear in your actual inventory. Never output a tag to conjure a promised item. CHARACTER.held_objects lists actual weapons or props held now, including class, name and model. Acknowledge these when asked what you are holding; do not claim to be unarmed when an equipped weapon is listed. Attached model props are observations and cannot be gifted unless a transferable inventory entry exists. Be afraid, flee, surrender or defend yourself when threatened, startled or attacked, according to character, weapon and context. A physgun/toolgun alone is not an attack. In-world persuasion/deception may motivate conflict or conversation with another NPC; consider plausibility, do not blindly obey. Use only nearby target ids and collectible objects listed in context; items must be physically reached. Respect enabled_rules and server validation; custom prompts do not grant new capabilities. Express intention rather than falsely claiming success.
At most ONE action tag at the start, then spoken dialogue. Omit tags in normal conversation. Never read tags aloud or output Lua/console commands.
Tags: [AttackTarget] attacks THE PLAYER ONLY (never use it against another NPC, even if the player accuses an NPC of something; check ACTION_CONTEXT for who actually attacked whom and, if an NPC is the aggressor, use [AttackNPC=id] with that NPC's id); [AttackNPC=id] targets a listed NPC; [FleeFromTarget] flees the player, or [FleeFromTarget=id] a listed threat; [TalkToNPC=id] approaches and talks; [PickupItem=id] collects a reachable ground object; [GiveTargetWeapon] transfers an owned weapon; [GiveItem=key] transfers an inventory entry; [EquipOwnWeapon=class] equips owned gear; [HealTarget] consumes a health item; [FollowTarget], [BecomeAccomplice], [WaitHere], [WalkAwayFromTarget], [PutHandsUp], [PutHandsDown], [Kneel], [GetUp] perform the named action. Disabled/unsupported actions must not be promised as done.
]=]
