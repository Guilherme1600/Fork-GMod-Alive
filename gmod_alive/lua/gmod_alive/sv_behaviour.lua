if CLIENT then return end
local GA=GModAlive
local legacyAction=GA.ExecuteNPCAction
local tasks={}
local seedWeapons={"weapon_pistol","weapon_smg1","weapon_shotgun"}
local groundItems={item_healthkit=true,item_healthvial=true,item_battery=true,item_ammo_pistol=true,item_ammo_smg1=true,item_box_buckshot=true,item_ammo_357=true}
local function alive(ent) return IsValid(ent) and ent:Health()>0 end
local function visible(a,b)
    return not util.TraceLine({start=a:WorldSpaceCenter(),endpos=b:WorldSpaceCenter(),filter={a,b}}).Hit
end
local function actualWeapon(npc)
    local weapon
    if npc.GetActiveWeapon then local ok,value=pcall(npc.GetActiveWeapon,npc) if ok then weapon=value end end
    return IsValid(weapon) and weapon or nil
end
local function add(inv,key,kind,model)
    if not inv[key] and table.Count(inv)>=12 then return false end
    inv[key]=inv[key] or {count=0,kind=kind,model=model}
    if inv[key].count>=5 then return false end
    inv[key].count=inv[key].count+1 return true
end
local weaponClasses={npc_citizen=true,npc_barney=true,npc_alyx=true,npc_combine_s=true,npc_metropolice=true,npc_monk=true}
local function seedWeapon(npc)
    if npc.GModAlive_WeaponSeeded or not GA.IsEnabled() or not GA.RuleEnabled("inventory") then return end
    npc.GModAlive_WeaponSeeded=true
    if actualWeapon(npc) or not npc.Give then return end
    local cls=npc:GetClass() local capable=weaponClasses[cls]
    if not capable and npc.CapabilitiesGet and CAP_USE_WEAPONS then
        capable=bit.band(npc:CapabilitiesGet(),CAP_USE_WEAPONS)~=0
    end
    if not capable then return end
    local probability=GetConVar("gmod_alive_armed_chance"):GetFloat()/100
    if util.SharedRandom("GModAlive.Inventory",0,1,npc:GetCreationID())>=probability then return end
    local classWeapons={npc_metropolice={"weapon_pistol","weapon_smg1"},npc_combine_s={"weapon_smg1","weapon_shotgun","weapon_ar2"},
        npc_alyx={"weapon_alyxgun"},npc_barney={"weapon_pistol"},npc_monk={"weapon_annabelle"}}
    local options=classWeapons[cls] or seedWeapons
    local index=math.Clamp(math.floor(util.SharedRandom("GModAlive.Weapon",1,#options+1,npc:GetCreationID())),1,#options)
    pcall(npc.Give,npc,options[index])
end
function GA.EnsureNPCInventory(npc)
    if not IsValid(npc) then return {} end
    seedWeapon(npc)
    if npc.GModAlive_Inventory then return npc.GModAlive_Inventory end
    local inv={} npc.GModAlive_Inventory=inv
    if not GA.RuleEnabled("inventory") then return inv end
    local cls=npc:GetClass() local model=string.lower(npc:GetModel() or "")
    if cls=="npc_citizen" or cls=="npc_barney" or cls=="npc_alyx" then
        add(inv,"item_healthkit","item")
    elseif cls:find("combine",1,true) or cls=="npc_metropolice" then add(inv,"item_battery","item") end
    return inv
end
function GA.GetNPCInventoryInfo(npc)
    local inv=table.Copy(GA.EnsureNPCInventory(npc))
    for _,held in ipairs(GA.HeldObjectInfo(npc)) do
        local key=held.attached and ("held:"..held.class..":"..util.CRC(held.model or "")) or held.class
        inv[key]=inv[key] or {count=0,kind=held.kind,model=held.model}
        inv[key].count=inv[key].count+1 inv[key].equipped=true inv[key].name=held.name inv[key].attached=held.attached
    end
    return inv
end
local function collectible(ent)
    if not IsValid(ent) or ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() or IsValid(ent:GetOwner()) or IsValid(ent:GetParent()) then return false end
    if ent:IsWeapon() or groundItems[ent:GetClass()] then return true end
    if ent:GetClass()=="prop_physics" then
        local physics=ent:GetPhysicsObject()
        return IsValid(physics) and physics:GetMass()<=80 and not ent:IsPlayerHolding()
    end
    return false
end
function GA.ActionContext(npc,ply)
    local data={held_objects=GA.HeldObjectInfo(npc),inventory=GA.GetNPCInventoryInfo(npc),nearby_npcs={},ground_objects={},enabled_rules={}}
    for _,rule in ipairs(GA.RuleOptions) do data.enabled_rules[rule.id]=GA.RuleEnabled(rule.id) end
    local list=ents.FindInSphere(npc:GetPos(),900)
    table.sort(list,function(a,b) return a:GetPos():DistToSqr(npc:GetPos())<b:GetPos():DistToSqr(npc:GetPos()) end)
    for _,ent in ipairs(list) do
        if ent~=npc and visible(npc,ent) then
            local distance=math.Round(npc:GetPos():Distance(ent:GetPos()))
            if GA.IsValidTalkTarget(ent) and #data.nearby_npcs<8 then
                local profile=GA.InspectNPC(ent,ply)
                data.nearby_npcs[#data.nearby_npcs+1]={id=ent:EntIndex(),name=profile and profile.name or ent:GetClass(),class=ent:GetClass(),distance_units=distance,armed=actualWeapon(ent)~=nil}
            elseif collectible(ent) and distance<=600 and #data.ground_objects<8 then
                data.ground_objects[#data.ground_objects+1]={id=ent:EntIndex(),class=ent:GetClass(),model=ent:GetModel(),distance_units=distance}
            end
        end
    end
    if npc.GModAlive_RecentThreat and CurTime()-npc.GModAlive_RecentThreat.time<20 then data.recent_threat=npc.GModAlive_RecentThreat end
    if npc.GModAlive_RecentGift and CurTime()-npc.GModAlive_RecentGift.time<120 then data.received_gift=npc.GModAlive_RecentGift end
    return data
end
local function nearbyTarget(npc,parameter,kind)
    local id=tonumber(string.Trim(tostring(parameter or "")))
    local target=id and Entity(id)
    if not IsValid(target) or target==npc or npc:GetPos():DistToSqr(target:GetPos())>900^2 or not visible(npc,target) then return nil end
    if kind=="npc" and not GA.IsValidTalkTarget(target) then return nil end
    if kind=="item" and not collectible(target) then return nil end
    return target
end
local function move(npc,position,run)
    if not npc.SetLastPosition or not npc.SetSchedule then return false end
    npc:SetLastPosition(position) npc:SetSchedule(run and SCHED_FORCED_GO_RUN or SCHED_FORCED_GO) return true
end
local function attack(npc,target)
    if not GetConVar("gmod_alive_actions_enabled"):GetBool() or not GA.RuleEnabled("aggression") or not alive(target) or not npc.SetEnemy or not npc.AddEntityRelationship then return false,"Combat is disabled or unsupported." end
    tasks[npc]=nil
    npc.GModAlive_FollowingPlayer=nil npc.GModAlive_HostileTo=target npc.GModAlive_CombatUntil=CurTime()+45
    npc:SetNWBool("GModAlive_Surrendered",false) npc:AddEntityRelationship(target,D_HT,99) npc:SetEnemy(target)
    if npc.UpdateEnemyMemory then npc:UpdateEnemyMemory(target,target:GetPos()) end
    if npc.SetSchedule then npc:SetSchedule(SCHED_CHASE_ENEMY) end
    return true
end
local function give(npc,ply,key)
    if not GA.RuleEnabled("inventory") or not alive(ply) or not ply:IsPlayer() or npc:GetPos():DistToSqr(ply:GetPos())>400^2 then return false,"Move closer to receive an item." end
    local inv=GA.EnsureNPCInventory(npc) local held=actualWeapon(npc)
    local equipped=held and held:GetClass()==key
    local item=inv[key]
    if not equipped and (not item or item.count<=0) then return false,"The NPC does not own that item." end
    if equipped or (item and item.kind=="weapon") then
        if ply:HasWeapon(key) then return false,"You already have that weapon." end
        local weapon=ply:Give(key,true)
        if not IsValid(weapon) then return false,"Weapon transfer was not supported." end
        local state=equipped and {clip1=held:Clip1(),clip2=held:Clip2(),skin=held:GetSkin()} or item and item.weaponStates and table.remove(item.weaponStates,1)
        if state then weapon:SetClip1(state.clip1 or -1) weapon:SetClip2(state.clip2 or -1) weapon:SetSkin(state.skin or 0) end
        if equipped then held:Remove() else item.count=item.count-1 end
    elseif item and item.kind=="ammo" then
        local granted=ply:GiveAmmo(math.min(item.count,30),item.ammoID,true)
        if not granted or granted<1 then return false,"You cannot carry more of that ammunition." end
        item.count=item.count-granted
    else
        local entity=ents.Create(item.kind=="prop" and "prop_physics" or key)
        if not IsValid(entity) then return false,"Item could not be created." end
        if item.kind=="prop" then entity:SetModel(item.model) end
        entity:SetPos(ply:GetPos()+ply:GetForward()*45+Vector(0,0,25)) entity:Spawn()
        item.count=item.count-1
    end
    if item and item.count<=0 then inv[key]=nil end
    return true
end
function GA.ExecuteNPCAction(npc,ply,tag,param)
    if not IsValid(npc) or not GetConVar("gmod_alive_actions_enabled"):GetBool() then return false,"NPC actions are disabled." end
    if GA.EndNPCConversation then GA.EndNPCConversation(npc) end
    if tag=="AttackTarget" or tag=="AttackNPC" then
        if tag=="AttackNPC" and not GA.RuleEnabled("interactions") then return false,"NPC interactions are disabled." end
        local target=ply
        if tag=="AttackNPC" then target=nearbyTarget(npc,param,"npc") end
        if not IsValid(target) then return false,"The requested target is not nearby." end
        return attack(npc,target)
    elseif tag=="FleeFromTarget" then
        if not GA.RuleEnabled("flee") then return false,"Fleeing is disabled." end
        local threat=ply
        if param and param~="" then threat=nearbyTarget(npc,param) end
        if not IsValid(threat) then return false,"No nearby threat." end
        tasks[npc]=nil npc.GModAlive_FollowingPlayer=nil npc.GModAlive_HostileTo=nil
        if npc.SetEnemy then npc:SetEnemy(NULL) end
        if npc.AddEntityRelationship then npc:AddEntityRelationship(threat,D_FR,99) end
        local direction=npc:GetPos()-threat:GetPos() direction.z=0
        if direction:LengthSqr()<1 then direction=npc:GetForward() end
        return move(npc,npc:GetPos()+direction:GetNormalized()*800,true)
    elseif tag=="GiveTargetWeapon" then
        local held=actualWeapon(npc) local key=held and held:GetClass() or nil
        for class,item in pairs(GA.EnsureNPCInventory(npc)) do if not key and item.kind=="weapon" and item.count>0 then key=class end end
        if not key then return false,"The NPC has no weapon to give." end
        return give(npc,ply,key)
    elseif tag=="GiveItem" then return give(npc,ply,tostring(param or ""))
    elseif tag=="EquipOwnWeapon" then
        local inv=GA.EnsureNPCInventory(npc) local item=inv[param or ""]
        if not GA.RuleEnabled("inventory") or not item or item.kind~="weapon" or not npc.Give then return false,"That weapon is not in the NPC inventory." end
        local old=actualWeapon(npc) if old then return false,"The NPC already has an equipped weapon." end
        npc:Give(param) local held=actualWeapon(npc)
        if not held or held:GetClass()~=param then return false,"This NPC cannot equip that weapon." end
        item.count=item.count-1 if item.count<=0 then inv[param]=nil end return true
    elseif tag=="HealTarget" then
        local inv=GA.EnsureNPCInventory(npc) local key=inv.item_healthkit and "item_healthkit" or inv.item_healthvial and "item_healthvial"
        if not key or not GA.RuleEnabled("inventory") or not alive(ply) or npc:GetPos():DistToSqr(ply:GetPos())>250^2 then return false,"No health item available or player is too far away." end
        ply:SetHealth(math.min(ply:GetMaxHealth(),ply:Health()+(key=="item_healthkit" and 25 or 10)))
        inv[key].count=inv[key].count-1 if inv[key].count<=0 then inv[key]=nil end return true
    elseif tag=="PickupItem" or tag=="TalkToNPC" or tag=="InitiateDirectedInteraction" then
        if tag=="PickupItem" and not (GA.RuleEnabled("inventory") and GA.RuleEnabled("pickup")) then return false,"Collecting items is disabled." end
        if tag~="PickupItem" and not GA.RuleEnabled("interactions") then return false,"NPC interactions are disabled." end
        local target=nearbyTarget(npc,param,tag=="PickupItem" and "item" or "npc")
        if not target and tag=="InitiateDirectedInteraction" then
            for _,ent in ipairs(ents.FindInSphere(npc:GetPos(),700)) do if ent~=npc and GA.IsValidTalkTarget(ent) and visible(npc,ent) then target=ent break end end
        end
        if not target then return false,"The requested target is not nearby or visible." end
        if not npc.SetLastPosition or not npc.SetSchedule then return false,"This NPC framework does not support these movement tasks." end
        npc.GModAlive_FollowingPlayer=nil
        tasks[npc]={target=target,ply=ply,kind=tag=="PickupItem" and "pickup" or "talk",expires=CurTime()+18,nextMove=0}
        return true
    end
    if tag=="WaitHere" or tag=="FollowTarget" or tag=="BecomeAccomplice" then tasks[npc]=nil end
    legacyAction(npc,ply,tag,param) return true
end
function GA.StartNpcToNpcConversation(speaker,observer,target)
    if not alive(speaker) or not alive(target) or not GA.RuleEnabled("interactions") or not GetConVar("gmod_alive_npc_to_npc"):GetBool() then return end
    if (speaker.GModAlive_ConversationUntil and speaker.GModAlive_ConversationUntil>CurTime())
        or (target.GModAlive_ConversationUntil and target.GModAlive_ConversationUntil>CurTime()) then return end
    speaker.GModAlive_ConversationUntil=CurTime()+60 target.GModAlive_ConversationUntil=CurTime()+60
    local profile=GA.InspectNPC(target,observer) local language=IsValid(observer) and observer.GModAlive_LastUtterance or "Hello"
    GA.MakeNPCFaceTarget(speaker,target) GA.MakeNPCFaceTarget(target,speaker)
    timer.Simple(5,function()
        if not alive(speaker) or not alive(target) then return end
        GA.SetNPCStatus(speaker,"thinking")
        GA.GenerateNPCResponse({ply=observer,npc=speaker,userText="Speak directly to the nearby character "..(profile and profile.name or "NPC")..". Start a brief natural in-character conversation. No action tags. Use the language of this earlier player utterance: "..tostring(language)},function(ok,response,p)
            if IsValid(speaker) then GA.SetNPCStatus(speaker,"") end
            if not ok or not istable(response) or not alive(speaker) or not alive(target) then return end
            GA.BroadcastNPCResponse(speaker,observer,response.spokenText,nil,p,"")
            timer.Simple(math.Clamp(utf8.len(response.spokenText)*0.1+10,10,45),function()
                if not alive(speaker) or not alive(target) or speaker:GetPos():DistToSqr(target:GetPos())>900^2 then return end
                GA.SetNPCStatus(target,"thinking")
                GA.GenerateNPCResponse({ply=observer,npc=target,userText="Reply briefly to the character who said: "..response.spokenText..". Use the same language. No action tags."},function(ok2,reply,p2)
                    if IsValid(target) then GA.SetNPCStatus(target,"") end
                    if ok2 and istable(reply) and alive(target) then GA.BroadcastNPCResponse(target,observer,reply.spokenText,nil,p2,"") end
                end)
            end)
        end)
    end)
end
timer.Create("GModAlive_InventoryTasks",0.35,0,function()
    if not GA.IsEnabled() then return end
    for npc,task in pairs(tasks) do
        if not GetConVar("gmod_alive_actions_enabled"):GetBool() or not alive(npc) or not IsValid(task.target) or CurTime()>task.expires
            or (task.kind=="pickup" and not (GA.RuleEnabled("inventory") and GA.RuleEnabled("pickup")))
            or (task.kind=="talk" and not GA.RuleEnabled("interactions")) then tasks[npc]=nil
        elseif GA.IsNPCConversationPaused and GA.IsNPCConversationPaused(npc) then
            task.expires=task.expires+0.35
        else
            local radius=task.kind=="pickup" and 100 or 170
            if npc:GetPos():DistToSqr(task.target:GetPos())<=radius^2 and visible(npc,task.target) then
                tasks[npc]=nil
                if task.kind=="talk" then GA.StartNpcToNpcConversation(npc,task.ply,task.target)
                elseif collectible(task.target) then
                    local target=task.target local class=target:GetClass() local kind=target:IsWeapon() and "weapon" or class=="prop_physics" and "prop" or "item"
                    local key=kind=="prop" and ("prop:"..util.CRC(target:GetModel() or "")) or class
                    local inv=GA.EnsureNPCInventory(npc)
                    if add(inv,key,kind,target:GetModel()) then
                        if kind=="weapon" then
                            inv[key].weaponStates=inv[key].weaponStates or {}
                            inv[key].weaponStates[#inv[key].weaponStates+1]={clip1=target:Clip1(),clip2=target:Clip2(),skin=target:GetSkin()}
                        end
                        target:Remove()
                    end
                end
            elseif CurTime()>=task.nextMove then
                task.nextMove=CurTime()+1
                local offset=npc:GetPos()-task.target:GetPos() offset.z=0
                move(npc,task.target:GetPos()+offset:GetNormalized()*60,false)
            end
        end
    end
    for _,npc in ipairs(ents.GetAll()) do
        local target=npc.GModAlive_HostileTo
        if IsValid(target) and (not GetConVar("gmod_alive_actions_enabled"):GetBool() or not GA.RuleEnabled("aggression") or not alive(npc) or not alive(target) or CurTime()>(npc.GModAlive_CombatUntil or 0)) then
            npc.GModAlive_HostileTo=nil
            if npc.SetEnemy then npc:SetEnemy(NULL) end
            if IsValid(target) and npc.AddEntityRelationship then npc:AddEntityRelationship(target,D_NU,99) end
        elseif alive(npc) and alive(target) and not actualWeapon(npc) and not (GA.IsNPCConversationPaused and GA.IsNPCConversationPaused(npc)) then
            local distance=npc:GetPos():DistToSqr(target:GetPos())
            if distance<85^2 and visible(npc,target) and CurTime()>(npc.GModAlive_NextMelee or 0) then
                npc.GModAlive_NextMelee=CurTime()+1.2
                local damage=DamageInfo() damage:SetDamage(8) damage:SetDamageType(DMG_CLUB) damage:SetAttacker(npc) damage:SetInflictor(npc)
                target:TakeDamageInfo(damage)
            elseif CurTime()>(npc.GModAlive_NextChase or 0) then npc.GModAlive_NextChase=CurTime()+1 move(npc,target:GetPos(),true) end
        end
    end
end)
hook.Add("OnEntityCreated","GModAlive_OwnInventory",function(ent)
    timer.Simple(0.5,function() if IsValid(ent) and GA.IsValidTalkTarget(ent) then GA.EnsureNPCInventory(ent) end end)
end)
hook.Add("EntityTakeDamage","GModAlive_ThreatResponse",function(npc,damage)
    if not GA.IsEnabled() or not GetConVar("gmod_alive_actions_enabled"):GetBool() or not GA.IsValidTalkTarget(npc) or damage:GetDamage()<=0 then return end
    local attacker=damage:GetAttacker()
    if not alive(attacker) or attacker==npc then return end
    npc.GModAlive_RecentThreat={kind="attacked",entity=attacker:EntIndex(),time=CurTime()}
    if CurTime()<(npc.GModAlive_NextReaction or 0) then return end npc.GModAlive_NextReaction=CurTime()+3
    timer.Simple(0,function()
        if not alive(npc) or not alive(attacker) then return end
        if actualWeapon(npc) and GA.RuleEnabled("aggression") then attack(npc,attacker)
        elseif GA.RuleEnabled("flee") then GA.ExecuteNPCAction(npc,attacker,"FleeFromTarget") end
    end)
end)
hook.Add("EntityFireBullets","GModAlive_Startle",function(shooter)
    if not GA.IsEnabled() or not GetConVar("gmod_alive_actions_enabled"):GetBool() or not IsValid(shooter) or not shooter:IsPlayer() then return end
    for _,npc in ipairs(ents.FindInSphere(shooter:GetPos(),220)) do
        if GA.IsValidTalkTarget(npc) then
            npc.GModAlive_RecentThreat={kind="nearby_gunshot",entity=shooter:EntIndex(),time=CurTime()}
            if not actualWeapon(npc) and GA.RuleEnabled("flee") and CurTime()>(npc.GModAlive_NextReaction or 0) then
                npc.GModAlive_NextReaction=CurTime()+5
                timer.Simple(0,function() if alive(npc) and IsValid(shooter) then GA.ExecuteNPCAction(npc,shooter,"FleeFromTarget") end end)
            end
        end
    end
end)

hook.Add("InitPostEntity","GModAlive_SeedExistingNPCInventory",function()
    timer.Simple(1,function() for _,npc in ipairs(ents.GetAll()) do
        if GA.IsEnabled() and GA.IsValidTalkTarget(npc) then GA.EnsureNPCInventory(npc) end
    end end)
end)
