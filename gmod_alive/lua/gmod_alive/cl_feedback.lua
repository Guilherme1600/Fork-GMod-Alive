if SERVER then return end
local GA=GModAlive
GA.QueuedSubtitles={} GA.NpcSubtitles={}
GA.NpcStatuses={} GA.StatusTimes={} GA.HUDToasts={} GA.ClientChatLog=GA.ClientChatLog or {}
for name,size in pairs({GModAlive_Title=20,GModAlive_Subtitle=19,GModAlive_Small=15,GModAlive_Badge=14}) do
    surface.CreateFont(name,{font="Roboto",size=size,weight=500,extended=true})
end
function GA.AddHUDToast(text,isError)
    if isError then GA.LastVisibleError={text=utf8.sub(tostring(text),1,100),untilTime=RealTime()+7} end
end
function GA.WrapText(text,font,width)
    surface.SetFont(font) local lines,line={},""
    for word in tostring(text):gmatch("%S+") do
        local nextLine=line=="" and word or line.." "..word
        if surface.GetTextSize(nextLine)>width and line~="" then lines[#lines+1]=line line=word else line=nextLine end
    end
    if line~="" then lines[#lines+1]=line end return lines
end
function GA.BeginNPCSubtitle(sub,duration)
    if not sub then return end
    local now=RealTime() local length=utf8.len(sub.text) or #sub.text
    sub.started=true sub.startedAt=now sub.expiresAt=now+math.max(duration or 0,math.Clamp(length/30+4,7,70))
    GA.NpcSubtitles[sub.entIndex]=sub GA.ActiveSubtitle=sub
    if not GetConVar("gmod_alive_tts_enabled"):GetBool() and GA.AnimateTextMouth then GA.AnimateTextMouth(sub.entIndex,sub.expiresAt-now) end
end
net.Receive("GModAlive_SystemNotice",function()
    local isError=net.ReadBool() local text=net.ReadString()
    if isError then GA.PendingVoiceReply=nil GA.AddHUDToast(text,true) MsgC(Color(255,160,140),"[GMod Alive] ",color_white,text.."\n") end
end)
net.Receive("GModAlive_NPCStatus",function()
    local index=net.ReadUInt(16) GA.NpcStatuses[index]=net.ReadString() GA.StatusTimes[index]=RealTime()
end)
net.Receive("GModAlive_NPCResponse",function()
    local index=net.ReadUInt(16) local name=net.ReadString() local role=net.ReadString() local mod=net.ReadString()
    local text=net.ReadString() local action=net.ReadString() local heard=net.ReadString() local pitch=net.ReadFloat() local female=net.ReadBool() local language=net.ReadString()
    GA.PendingVoiceReply=nil GA.NpcStatuses[index]=""
    local npc=Entity(index) local ply=LocalPlayer()
    if not IsValid(npc) or not IsValid(ply) or ply:GetPos():DistToSqr(npc:GetPos())>math.max(GA.GetMaxDistance()*2,600)^2 then return end
    GA.QueuedSubtitles[index]={entIndex=index,creation=npc:GetCreationID(),name=name,text=text}
    GA.NpcSubtitles[index]=GA.QueuedSubtitles[index]
    if not GetConVar("gmod_alive_tts_enabled"):GetBool() then
        if GA.StopNPCTTS then GA.StopNPCTTS(index) end
        GA.BeginNPCSubtitle(GA.QueuedSubtitles[index])
        GA.QueuedSubtitles[index]=nil
    else GA.Speak3DTTS(index,text,pitch,female,language) end
end)
hook.Remove("HUDPaint","GModAlive_DrawHUD")
hook.Remove("HUDPaint","GModAlive_EssentialVoiceStatus")
hook.Remove("PostDrawTranslucentRenderables","GModAlive_Draw3DBubbles")
hook.Add("HUDPaint","GModAlive_Feedback",function()
    if not GA.IsEnabled() or IsValid(GA.SettingsWindow) then return end
    local status,color
    local state=GA.VoiceState or {}
    if state.isListening then status=GA.L("OUVINDO • solte a tecla para enviar") color=Color(62,155,220)
    elseif state.waitingForFlush then status=GA.L("PROCESSANDO SUA VOZ…") color=Color(62,155,220)
    elseif GA.PendingVoiceReply and RealTime()<GA.PendingVoiceReply then status=GA.L("PENSANDO…") color=Color(62,155,220)
    else
        for _,q in pairs(GA.ActiveTTSQueues or {}) do
            if not IsValid(q.station) then status=GA.L("GERANDO VOZ…") color=Color(62,155,220) break end
        end
        if not status then
            for index,value in pairs(GA.NpcStatuses) do
                local npc=Entity(index)
                if value=="thinking" and RealTime()-(GA.StatusTimes[index] or 0)<135 and IsValid(npc) and IsValid(LocalPlayer())
                    and LocalPlayer():GetPos():DistToSqr(npc:GetPos())<=GA.GetMaxDistance()^2 then status=GA.L("PENSANDO…") color=Color(62,155,220) break end
            end
        end
    end
    if not status and GA.LastVisibleError and RealTime()<GA.LastVisibleError.untilTime then status=GA.LastVisibleError.text color=Color(255,155,135) end
    local subtitleHeight=0
    if status==GA.L("PENSANDO…") or status==GA.L("GERANDO VOZ…") then status=nil end
    if status and GetConVar("gmod_alive_status_visible"):GetBool() then
        surface.SetFont("GModAlive_Subtitle") local textWidth=surface.GetTextSize(status)
        local width=math.min(ScrW()-32,math.max(360,textWidth+44)) local x,y=(ScrW()-width)/2,ScrH()-subtitleHeight-94
        draw.RoundedBox(0,x,y,width,46,Color(245,251,255,245)) draw.RoundedBox(0,x,y,4,46,color)
        draw.SimpleText(status,"GModAlive_Subtitle",ScrW()/2,y+23,color,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end
end)

local function headPosition(npc)
    local id=npc:LookupBone("ValveBiped.Bip01_Head1") or npc:LookupBone("Head") or npc:LookupBone("head")
    local pos=id and npc:GetBonePosition(id)
    if not pos or pos:DistToSqr(npc:GetPos())<4 then
        local eyes=npc:LookupAttachment("eyes")
        local attachment=eyes and eyes>0 and npc:GetAttachment(eyes)
        pos=attachment and attachment.Pos or npc:GetPos()+Vector(0,0,npc:OBBMaxs().z)
    end
    return pos+Vector(0,0,7)
end
hook.Add("HUDPaint","GModAlive_HeadThinking",function()
    if not GA.IsEnabled() or IsValid(GA.SettingsWindow) or IsValid(GA.SetupWindow) then return end
    local ply=LocalPlayer() if not IsValid(ply) then return end
    local showStatus=GetConVar("gmod_alive_status_visible"):GetBool()
    local showSubs=GetConVar("gmod_alive_subtitles"):GetBool() or not GetConVar("gmod_alive_tts_enabled"):GetBool()
    for _,npc in ipairs(ents.FindInSphere(ply:GetPos(),math.max(GA.GetMaxDistance()*2,600))) do
        if GA.IsValidTalkTarget(npc) then
            local id=npc:EntIndex() local queue=GA.ActiveTTSQueues[id]
            local pending=GA.PendingTarget==npc and GA.PendingVoiceReply and RealTime()<GA.PendingVoiceReply
            local thinking=(GA.NpcStatuses[id]=="thinking" and RealTime()-(GA.StatusTimes[id] or 0)<135) or pending or (queue and not IsValid(queue.station))
            local blocked=util.TraceLine({start=ply:EyePos(),endpos=npc:WorldSpaceCenter(),filter={ply,npc}}).Hit
            local anchor=headPosition(npc):ToScreen()
            if not blocked and anchor.visible then
                if thinking and showStatus then
                    local dots=string.rep(".",math.floor(RealTime()*2)%3+1)
                    local title=GA.L("PENSANDO…"):gsub("…$","")..dots
                    draw.SimpleTextOutlined(title,"GModAlive_Small",anchor.x,anchor.y-5,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_BOTTOM,2,color_black)
                end
            end
        end
    end
end)
hook.Add("HUDPaint","GModAlive_SubtitleRenderer",function()
    if not GA.IsEnabled() then return end
    if not GetConVar("gmod_alive_subtitles"):GetBool() and GetConVar("gmod_alive_tts_enabled"):GetBool() then return end
    local ply=LocalPlayer() if not IsValid(ply) then return end
    local now=RealTime() local fallback
    local function drawSubtitle(sub,x,y)
        local elapsed=math.max(0,now-(sub.startedAt or now))
        local count=math.min(utf8.len(sub.text) or #sub.text,math.floor(elapsed*45)+1)
        local first=math.floor(math.max(0,count-1)/240)*240+1
        local lines=GA.WrapText(utf8.sub(sub.text,first,count),"GModAlive_Subtitle",math.min(500,ScrW()-48))
        local alpha=math.floor(255*math.min(1,elapsed/0.15,math.max(0,sub.expiresAt-now)/0.4))
        for i,line in ipairs(lines) do
            draw.SimpleTextOutlined(line,"GModAlive_Subtitle",x,y-(#lines-i)*23,Color(255,255,255,alpha),TEXT_ALIGN_CENTER,TEXT_ALIGN_BOTTOM,2,Color(0,0,0,alpha))
        end
    end
    for id,sub in pairs(GA.NpcSubtitles) do
        local npc=Entity(id)
        if not IsValid(npc) or npc:GetCreationID()~=sub.creation or (sub.expiresAt and now>sub.expiresAt) then GA.NpcSubtitles[id]=nil
        elseif sub.started and ply:GetPos():DistToSqr(npc:GetPos())<=math.max(GA.GetMaxDistance()*2,600)^2 then
            local pos=headPosition(npc):ToScreen()
            local blocked=util.TraceLine({start=ply:EyePos(),endpos=npc:WorldSpaceCenter(),filter={ply,npc}}).Hit
            if pos.visible and not blocked and pos.y>60 and pos.y<ScrH()-30 and pos.x>40 and pos.x<ScrW()-40 then
                drawSubtitle(sub,math.Clamp(pos.x,math.min(260,ScrW()/2),math.max(ScrW()-260,ScrW()/2)),pos.y-4)
            elseif not fallback or sub.startedAt>fallback.startedAt then fallback=sub end
        end
    end
    if fallback then drawSubtitle(fallback,ScrW()/2,ScrH()-50) end
end)
