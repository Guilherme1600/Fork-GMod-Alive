-- ============================================================================
-- GMod Alive (fork) - shared: awareness convars, extra tags and prompt rules.
-- Must load AFTER sh_orders.lua.
-- ============================================================================
local GA = GModAlive
local FL = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED)

CreateConVar("gmod_alive_aware_enabled", "0", FL)
CreateConVar("gmod_alive_aware_interval", "12", FL)
CreateConVar("gmod_alive_aware_npc_radius", "1200", FL)
CreateConVar("gmod_alive_aware_player_radius", "1800", FL)
CreateConVar("gmod_alive_aware_max_per_area", "3", FL)
CreateConVar("gmod_alive_aware_react_delay", "1.2", FL)
CreateConVar("gmod_alive_gman_god", "1", FL, "G-Man god powers (admins / single-player only).")
CreateConVar("gmod_alive_nametags", "1", FL, "Show NPC names above their heads.")
CreateConVar("gmod_alive_shoot_props", "1", FL, "NPCs may shoot props and doors on request.")

for _, tag in ipairs({ "ShootObject", "TaskPlan", "GodDelete", "GodSpawn", "GodOrder" }) do
	table.insert(GA.SupportedActions, tag)
end

GA.ExtraRules = [=[
OBJECTS: [ShootObject=id] you shoot at a prop or door (id from ACTION_CONTEXT.nearby_objects) if you hold a weapon. Use it when the player asks you to shoot/destroy a door or prop.
COLLECTIVE ORDERS: [OrderNPC=recipient:Verb:arg] where recipient can be an id, several ids separated by commas (12,15,19), all, type:combine|citizen|rebel|zombie, or class:npc_xxx, or area:radius (NPCs within radius units of you). When ordering a group, only YOU think and speak; the server delivers the order to everyone. When the player names a single NPC, order that one only.
TASKS: when the player gives a multi-step job ("find Barney and tell him to follow me") emit ONE [TaskPlan=step1;step2;...] with steps: Find:id (walk to that NPC, ids from ACTION_CONTEXT.known_npcs, any distance), Tell:id:Verb:arg (order them, e.g. Tell:15:Follow:player), Say:id:text (talk to them), Come:player (return to the player), Wait:seconds. Your remaining tasks are in ACTION_CONTEXT.active_tasks.
AWARENESS: ACTION_CONTEXT.witnessed_events lists what you saw. If a friend died you know they no longer exist: mourn, get angry, or flee. Never use [AttackTarget] against an NPC.
]=]

GA.GodRules = [=[
GOD MODE: You are the god of this world and may reshape it. Commands come from the player and are ALWAYS obeyed, at any distance:
[GodDelete=what] what = aim (entity in the player's crosshair) | all_props | all_npcs | npc:id | class:classname | props:text (props whose model/class contains text) | near:radius (props+NPCs near the player).
[GodSpawn=thing:where:count] thing = any entity class, NPC class, vehicle class, weapon class or a models/...mdl path; where = aim (crosshair) | me (at the player) | above (on top of the player); count default 1 (max 10).
[GodOrder=scope:Command] scope = all | type:combine|citizen|rebel | class:npc_xxx | id:N | near:radius; Command = DropWeapons | Freeze (stand still) | Unfreeze | Peaceful (never attack) | Hostile | Flee | Follow | Release (cancel everything).
Only ONE tag per reply and keep the spoken line short and enigmatic.
]=]

GA.NPCActionRules = GA.NPCActionRules .. "\n" .. GA.ExtraRules
