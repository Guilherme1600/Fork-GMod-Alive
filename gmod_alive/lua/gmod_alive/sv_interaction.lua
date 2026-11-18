if CLIENT then return end
local GA=GModAlive
util.AddNetworkString("GModAlive_Conversation")
util.AddNetworkString("GModAlive_Inventory")
local sessions={} local requests=setmetatable({},{__mode="k"}) local inventoryRequests=setmetatable({},{__mode="k"})
local function canInteract(ply,npc)
    return GA.IsEnabled() and IsValid(ply) and ply:Alive() and GA.IsValidTalkTarget(npc)
        and ply:GetPos():DistToSqr(npc:GetPos())<=GA.GetMaxDistance()^2
        and not util.TraceLine({start=ply:EyePos(),endpos=npc:WorldSpaceCenter(),filter={ply,npc}}).Hit
end
function GA.IsNPCConversationPaused(npc) return sessions[npc]~=nil end
function GA.EndNPCConversation(npc)
    local previous=sessions[npc] if not previous then return end sessions[npc]=nil
    if IsValid(npc) and npc.loco and previous.speed then npc.loco:SetDesiredSpeed(previous.speed) end
    if IsValid(npc) and npc.ClearSchedule then npc:ClearSchedule() end
end
function GA.PauseNPCForConversation(npc,ply,seconds)
    if not canInteract(ply,npc) then return false end
    local existing=sessions[npc]
    if existing and IsValid(existing.ply) and existing.ply~=ply then return false end
    local session=existing or {ply=ply}
    session.expires=CurTime()+(seconds or 12) sessions[npc]=session
    if npc.ClearSchedule then npc:ClearSchedule() end
    if npc.StopMoving then npc:StopMoving(true) end
    if npc.SetSchedule then npc:SetSchedule(SCHED_IDLE_STAND) end
    if npc.loco and npc.loco.GetDesiredSpeed and npc.loco.SetDesiredSpeed then
        session.speed=session.speed or npc.loco:GetDesiredSpeed() npc.loco:SetDesiredSpeed(0)
    end
    GA.MakeNPCFaceTarget(npc,ply)
    return true
end
net.Receive("GModAlive_Conversation",function(_,ply)
    local npc=net.ReadEntity() local creation=net.ReadUInt(32) local open=net.ReadBool()
    if not IsValid(npc) or npc:GetCreationID()~=creation then return end
    if not open then if sessions[npc] and sessions[npc].ply==ply then GA.EndNPCConversation(npc) end requests[ply]=nil return end
    if (requests[ply] or -10)>CurTime()-0.2 then return end requests[ply]=CurTime()
    GA.PauseNPCForConversation(npc,ply,12)
end)
net.Receive("GModAlive_Inventory",function(_,ply)
    local npc=net.ReadEntity() local creation=net.ReadUInt(32)
    if not IsValid(npc) or npc:GetCreationID()~=creation or not canInteract(ply,npc) then return end
    if (inventoryRequests[ply] or -10)>CurTime()-0.5 then return end inventoryRequests[ply]=CurTime()
    local inventory=GA.GetNPCInventoryInfo(npc) local rows={}
    for class,item in pairs(inventory) do
        rows[#rows+1]={class=utf8.sub(class,1,160),name=utf8.sub(item.name or GA.ItemLabel(class,item.model),1,100),
            count=math.Clamp(item.count or 0,0,20),model=utf8.sub(item.model or GA.ItemPreviewModel(class),1,240),kind=item.kind or "item",equipped=item.equipped==true,attached=item.attached==true}
    end
    table.sort(rows,function(a,b) if a.equipped~=b.equipped then return a.equipped end return a.name<b.name end)
    local profile=GA.InspectNPC(npc,ply)
    net.Start("GModAlive_Inventory") net.WriteEntity(npc) net.WriteUInt(creation,32)
    net.WriteString(profile and profile.name or "NPC") net.WriteString(util.TableToJSON(rows)) net.Send(ply)
end)
timer.Create("GModAlive_ConversationFocus",0.2,0,function()
    for npc,session in pairs(sessions) do
        if not canInteract(session.ply,npc) or CurTime()>session.expires then GA.EndNPCConversation(npc)
        else
            if npc.StopMoving then npc:StopMoving(true) end
            if npc.SetSchedule and (not npc.IsCurrentSchedule or not npc:IsCurrentSchedule(SCHED_IDLE_STAND)) then npc:SetSchedule(SCHED_IDLE_STAND) end
            GA.MakeNPCFaceTarget(npc,session.ply)
            if npc.AddFacingTarget then npc:AddFacingTarget(session.ply,1,0.4) end
        end
    end
end)
hook.Add("EntityTakeDamage","GModAlive_ReleaseConversationOnDamage",function(npc) GA.EndNPCConversation(npc) end)
hook.Add("PlayerDisconnected","GModAlive_ReleaseConversations",function(ply) for npc,session in pairs(sessions) do if session.ply==ply then GA.EndNPCConversation(npc) end end end)
