if SERVER then return end
local GA=GModAlive
GA.ActiveTTSQueues={} GA.ActiveVoiceLevels={}
file.CreateDir("gmod_alive/audio")
local serial=0
local flexNames={"jaw_drop","mouth_open","open_jaw","mouthopen","jawopen","right_mouth_drop","left_mouth_drop"}
local function reset(q)
    if not q then return end
    if IsValid(q.station) then q.station:Stop() end
    if IsValid(q.npc) and q.npc:GetCreationID()==q.creation then
        for id,value in pairs(q.original or {}) do q.npc:SetFlexWeight(id,value) end
        if q.bone then q.npc:ManipulateBoneAngles(q.bone,q.boneAngle) end
    end
    if q.path then file.Delete(q.path) end
end
GA.TextMouthAnimations={}
function GA.StopTextMouth(index)
    local q=GA.TextMouthAnimations[index] GA.TextMouthAnimations[index]=nil
    reset(q)
end
function GA.AnimateTextMouth(index,duration)
    GA.StopTextMouth(index)
    local npc=Entity(index) if not IsValid(npc) then return end
    local q={npc=npc,creation=npc:GetCreationID(),original={},started=RealTime(),expires=RealTime()+duration}
    for _,name in ipairs(flexNames) do local id=npc:GetFlexIDByName(name) if id and id>=0 then q.original[id]=npc:GetFlexWeight(id) end end
    if table.IsEmpty(q.original) then
        q.bone=npc:LookupBone("ValveBiped.Bip01_Jaw") or npc:LookupBone("jaw")
        if q.bone then q.boneAngle=npc:GetManipulateBoneAngles(q.bone) end
    end
    GA.TextMouthAnimations[index]=q
end
hook.Add("Think","GModAlive_TextMouth",function()
    for index,q in pairs(GA.TextMouthAnimations) do
        if not GA.IsEnabled() or not IsValid(q.npc) or q.npc:GetCreationID()~=q.creation or RealTime()>q.expires then GA.StopTextMouth(index)
        else
            local t=RealTime()-q.started local weight=math.abs(math.sin(t*12.7))*math.abs(math.sin(t*3.4))*0.65
            for id in pairs(q.original) do q.npc:SetFlexWeight(id,weight) end
            if q.bone then q.npc:ManipulateBoneAngles(q.bone,q.boneAngle+Angle(0,0,weight*15)) end
        end
    end
end)
function GA.StopNPCTTS(index)
    GA.StopTextMouth(index)
    local q=GA.ActiveTTSQueues[index] GA.ActiveTTSQueues[index]=nil GA.ActiveVoiceLevels[index]=0
    if q and GA.ActiveSubtitle==q.subtitle then GA.ActiveSubtitle=nil end
    reset(q)
end
function GA.Speak3DTTS(index,text,pitch,isFemale,language)
    if not GetConVar("gmod_alive_tts_enabled"):GetBool() then return end
    local npc=Entity(index) if not IsValid(npc) then return end
    GA.StopNPCTTS(index) serial=serial+1
    local subtitle=GA.QueuedSubtitles[index]
    local q={npc=npc,creation=npc:GetCreationID(),token=serial,original={},weight=0,
        rate=math.Clamp(GetConVar("gmod_alive_voice_tone"):GetFloat(),0.8,1.1),subtitle=subtitle,expires=RealTime()+75}
    GA.ActiveTTSQueues[index]=q
    local function current() return GA.ActiveTTSQueues[index]==q and IsValid(npc) and npc:GetCreationID()==q.creation end
    local function fallback(message)
        GA.StopNPCTTS(index)
        if subtitle then
            GA.BeginNPCSubtitle(subtitle)
            GA.AnimateTextMouth(index,subtitle.expiresAt-RealTime())
            GA.ActiveSubtitle=subtitle GA.QueuedSubtitles[index]=nil
        end
        GA.AddHUDToast(tostring(message),true)
    end
    q.nextPart=function() GA.StopNPCTTS(index) end
    GA.RequestNeuralSpeech(text,language,npc,isFemale,function(ok,raw,ext)
        if not current() then return end
        if not GetConVar("gmod_alive_tts_enabled"):GetBool() then GA.StopNPCTTS(index) return end
        if not ok then fallback(raw) return end
        q.path="gmod_alive/audio/neural_"..q.token.."_"..os.time().."."..ext file.Write(q.path,raw)
        local path=q.path
        sound.PlayFile("data/"..path,"3d mono noplay",function(station)
            if not current() then if IsValid(station) then station:Stop() end file.Delete(path) return end
            if not IsValid(station) then fallback("Could not play neural speech. Showing text instead.") return end
            q.station=station q.expires=RealTime()+math.max(station:GetLength()/q.rate,1)+3
            for _,name in ipairs(flexNames) do local id=npc:GetFlexIDByName(name) if id and id>=0 then q.original[id]=npc:GetFlexWeight(id) end end
            if table.IsEmpty(q.original) then
                q.bone=npc:LookupBone("ValveBiped.Bip01_Jaw") or npc:LookupBone("jaw")
                if q.bone then q.boneAngle=npc:GetManipulateBoneAngles(q.bone) end
            end
            q.startedAt=RealTime()
            station:SetPos(npc:EyePos()) station:Set3DFadeDistance(80,math.max(320,GA.GetMaxDistance()*2))
            station:SetVolume(math.Clamp(GetConVar("gmod_alive_tts_volume"):GetFloat(),0,2)) station:SetPlaybackRate(q.rate) station:Play()
            if subtitle then
                GA.BeginNPCSubtitle(subtitle,station:GetLength()/q.rate+0.5)
                GA.ActiveSubtitle=subtitle GA.QueuedSubtitles[index]=nil
            end
        end)
    end)
end
hook.Add("Think","GModAlive_TTSPositionAndLipSync",function()
    for index,q in pairs(GA.ActiveTTSQueues) do
        if not GA.IsEnabled() or not IsValid(q.npc) or q.npc:GetCreationID()~=q.creation or q.npc:Health()<=0 then GA.StopNPCTTS(index)
        elseif RealTime()>q.expires then
            local subtitle=q.subtitle GA.StopNPCTTS(index)
            if subtitle then GA.BeginNPCSubtitle(subtitle) GA.AnimateTextMouth(index,subtitle.expiresAt-RealTime()) end
            GA.AddHUDToast("Neural speech timed out. Showing text instead.",true)
        elseif IsValid(q.station) then
            local st=q.station st:SetPos(q.npc:EyePos()) local l,r=st:GetLevel()
            local level=math.max(l or 0,r or 0)
            if level<0.003 and st:GetState()==GMOD_CHANNEL_PLAYING then
                local t=RealTime()-(q.startedAt or RealTime()) level=(0.045+math.abs(math.sin(t*12.7))*0.095)*math.abs(math.sin(t*3.4))
            end
            q.weight=Lerp(math.Clamp(RealFrameTime()*22,0,1),q.weight,math.Clamp(level*4,0,1))
            GA.ActiveVoiceLevels[index]=q.weight
            for id in pairs(q.original) do q.npc:SetFlexWeight(id,q.weight) end
            if q.bone then q.npc:ManipulateBoneAngles(q.bone,q.boneAngle+Angle(0,0,q.weight*15)) end
            if st:GetState()==GMOD_CHANNEL_STOPPED then q.nextPart() end
        end
    end
end)
hook.Add("ShutDown","GModAlive_SpeechCleanup",function() for index in pairs(GA.ActiveTTSQueues) do GA.StopNPCTTS(index) end for index in pairs(GA.TextMouthAnimations) do GA.StopTextMouth(index) end end)
