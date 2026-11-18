-- ============================================================================
-- GMod Alive — Talking AI NPCs
-- Server Networking, Native GMod Voice WAV Reader & Chat Hooks (sv_main.lua)
-- ============================================================================

if CLIENT then return end

GModAlive = GModAlive or {}
local GA = GModAlive

util.AddNetworkString("GModAlive_SendTurn")
util.AddNetworkString("GModAlive_VoiceStatus")
util.AddNetworkString("GModAlive_NPCResponse")
util.AddNetworkString("GModAlive_NPCStatus")
util.AddNetworkString("GModAlive_SyncConfig")
util.AddNetworkString("GModAlive_APITestResult")
util.AddNetworkString("GModAlive_SystemNotice")
util.AddNetworkString("GModAlive_ClearMemory")

function GA.SendNotice(ply, msg, isError)
	if not IsValid(ply) then return end
	net.Start("GModAlive_SystemNotice")
	net.WriteBool(isError and true or false)
	net.WriteString(tostring(msg or ""))
	net.Send(ply)
end

function GA.SetNPCStatus(npc, statusText)
	if not IsValid(npc) then return end
	npc:SetNWString("GModAlive_Status", tostring(statusText or ""))
	net.Start("GModAlive_NPCStatus")
	net.WriteUInt(npc:EntIndex(), 16)
	net.WriteString(tostring(statusText or ""))
	net.Broadcast()
end

function GA.BroadcastNPCResponse(npc, speakerPly, spokenText, actionTag, profile, heardText)
	if not IsValid(npc) then return end
	profile = profile or GA.InspectNPC(npc, speakerPly)

	net.Start("GModAlive_NPCResponse")
	net.WriteUInt(npc:EntIndex(), 16)
	net.WriteString(profile and profile.name or "NPC")
	net.WriteString(profile and profile.role or "Character")
	net.WriteString(profile and profile.modSource or "Garry's Mod")
	net.WriteString(tostring(spokenText or ""))
	net.WriteString(tostring(actionTag or ""))
	net.WriteString(tostring(heardText or ""))
	net.WriteFloat(profile and profile.voicePitch or 1.0)
	net.WriteBool(profile and profile.isFemale or false)
    net.WriteString(profile and profile.responseLanguage or "en-US")
	net.Broadcast()
end

local lastTurn,inFlight={},{}
local function canTalk(ply,npc)
    if not IsValid(ply) or not ply:Alive() or not IsValid(npc) or not GA.IsValidTalkTarget(npc) then return false end
    if ply:GetPos():DistToSqr(npc:GetPos())>GA.GetMaxDistance()^2 then return false end
    return not util.TraceLine({start=ply:EyePos(),endpos=npc:WorldSpaceCenter(),filter={ply,npc}}).Hit
end
function GA.HandlePlayerTurn(ply,npc,userText,isVoiceTurn,rawWav)
    if not IsValid(ply) or not GA.IsEnabled() then return end
    if not canTalk(ply,npc) then GA.SendNotice(ply,"Move closer to a visible living NPC.",true) return end
    if (lastTurn[ply] or 0)>RealTime() or inFlight[npc] then return end
    userText=utf8.sub(string.Trim(tostring(userText or "")),1,1500)
    if isVoiceTurn or rawWav or userText=="" then return end
    lastTurn[ply]=RealTime()+1
    if GA.IsGiftOffer and GA.IsGiftOffer(userText) then GA.OfferInventory(ply,npc) return end
    local request={} inFlight[npc]=request
    GA.PauseNPCForConversation(npc,ply,135)
    GA.MakeNPCFaceTarget(npc,ply) GA.SetNPCStatus(npc,"thinking")
    local function release()
        if inFlight[npc]~=request then return false end
        inFlight[npc]=nil if IsValid(npc) then GA.SetNPCStatus(npc,"") end return true
    end
    timer.Simple(135,function() if release() then GA.EndNPCConversation(npc) GA.SendNotice(ply,"AI response timed out.",true) end end)
    local ok=pcall(GA.GenerateNPCResponse,{ply=ply,npc=npc,userText=userText,rawWavBytes=rawWav},function(success,result,profile,heard)
        if not release() then return end
        if not success then GA.EndNPCConversation(npc) GA.SendNotice(ply,tostring(result),true) return end
        if not canTalk(ply,npc) then return end
        if result.actionTag then
            local actionOK,reason=GA.ExecuteNPCAction(npc,ply,result.actionTag,result.actionParam)
            if actionOK==false then GA.SendNotice(ply,"Action not completed: "..tostring(reason or "unsupported action"),true) end
        end
        ply.GModAlive_LastUtterance=heard or userText
        if result.spokenText and result.spokenText~="" then
            GA.MakeNPCFaceTarget(npc,ply) GA.StartNPCSpeakingState(npc,result.spokenText)
            GA.BroadcastNPCResponse(npc,ply,result.spokenText,result.actionTag,profile,heard)
            if not result.actionTag then GA.PauseNPCForConversation(npc,ply,math.Clamp(utf8.len(result.spokenText)*0.08+12,12,55)) end
        end
    end)
    if not ok and release() then GA.EndNPCConversation(npc) GA.SendNotice(ply,"The NPC request failed internally. Check the server console.",true) ErrorNoHalt("[GMod Alive] NPC request failed internally.\n") end
end
net.Receive("GModAlive_SendTurn",function(_,ply)
    local npc=Entity(net.ReadUInt(16)) local text=net.ReadString() local voice=net.ReadBool() local len=net.ReadUInt(16)
    if voice or len>0 then return end
    GA.HandlePlayerTurn(ply,npc,text,false,nil)
end)
timer.Remove("GModAlive_ExpireVoiceUploads")
hook.Add("PlayerDisconnected","GModAlive_ReleasePlayer",function(ply)
    lastTurn[ply]=nil GA.PlayerConfigs[ply:SteamID64()]=nil
end)

local lastConfig=setmetatable({},{__mode="k"})
net.Receive("GModAlive_SyncConfig", function(_,ply)
    if not IsValid(ply) then return end
    local apiKey=string.Trim(net.ReadString()) local runTest=net.ReadBool()
    local provider=net.ReadString() local model=string.Trim(net.ReadString())
    if not GA.Providers[provider] or #apiKey>500 or #model>180 or apiKey:find("[%c]") or model:find("[%c]") then return end
    if (lastConfig[ply] or -10)>RealTime()-1 then return end lastConfig[ply]=RealTime()
    local steamKey=ply:SteamID64() or "local"
    local cfg=GA.PlayerConfigs[steamKey] or {} GA.PlayerConfigs[steamKey]=cfg
    local changed=cfg.provider~=provider or cfg.detectedModel~=model
    cfg.apiKey=apiKey cfg.provider=provider cfg.detectedModel=model
    if changed then GA.ClearAllNpcMemory() end
    if game.SinglePlayer() or ply:IsListenServerHost() then
        GA.ServerConfig.provider=provider GA.ServerConfig.apiKey=apiKey GA.ServerConfig.detectedModel=model
        GA.SaveServerConfig(nil,nil)
    end

	if runTest then
		GA.TestAPIConnection(ply, function(ok, msg, latencyMs, detectedModel)
			if IsValid(ply) then
				net.Start("GModAlive_APITestResult")
				net.WriteBool(ok and true or false)
				net.WriteUInt(math.Clamp(latencyMs or 0, 0, 65000), 16)
				net.WriteString(tostring(detectedModel or ""))
				net.WriteString(tostring(msg or ""))
				net.Send(ply)
			end
			if ok then
				GA.SendNotice(ply, string.format("AI Connected (%s - %d ms): \"%s\"", tostring(detectedModel), latencyMs or 0, tostring(msg)), false)
			else
				GA.SendNotice(ply, "API Test Failed: " .. tostring(msg), true)
			end
		end)
	end
end)

net.Receive("GModAlive_ClearMemory", function(_, ply)
	if not IsValid(ply) or not (game.SinglePlayer() or ply:IsSuperAdmin()) then return end
	GA.ClearAllNpcMemory()
	GA.SendNotice(ply, "Conversation memory cleared for all NPCs!", false)
end)

hook.Add("PlayerSay", "GModAlive_ProximityChatHook", function(ply, text, teamChat)
	if not IsValid(ply) or not GA.IsEnabled() then return end
	local raw = string.Trim(tostring(text or ""))
	if raw == "" then return end

	local isExplicitCmd = false
	if string.StartWith(string.lower(raw), "!ai ") or string.StartWith(string.lower(raw), "/ai ") then
		raw = string.Trim(string.sub(raw, 5))
		isExplicitCmd = true
	elseif string.StartWith(raw, "!") or string.StartWith(raw, "/") then
		return
	end

	local cvChat = GetConVar("gmod_alive_chat_listen")
	local autoListen = not cvChat or cvChat:GetBool()
	if not isExplicitCmd and not autoListen then return end

	local maxDist = GA.GetMaxDistance()
	local targetNpc = GA.FindTargetNPC(ply, maxDist)
	if IsValid(targetNpc) then
		timer.Simple(0.05, function()
			if IsValid(ply) and IsValid(targetNpc) then
				GA.HandlePlayerTurn(ply, targetNpc, raw, false, nil)
			end
		end)
	elseif isExplicitCmd then
		GA.SendNotice(ply, string.format("No NPC within range (%d units).", math.Round(maxDist)), true)
	end
end)

util.AddNetworkString("GModAlive_Personality")
util.AddNetworkString("GModAlive_PersonalitySaved")
net.Receive("GModAlive_Personality",function(bits,ply)
    if not IsValid(ply) or bits>210000 then return end
    local preset=net.ReadString() local custom=net.ReadString()
    if not GA.PromptPresets[preset] or #custom>24000 then return end
    local id=ply:SteamID64() GA.PlayerConfigs[id]=GA.PlayerConfigs[id] or {}
    local cfg=GA.PlayerConfigs[id] local changed=cfg.promptPreset~=preset or cfg.customPrompt~=custom
    cfg.promptPreset=preset cfg.customPrompt=utf8.sub(custom,1,6000)
    if changed then GA.ClearAllNpcMemory() end
    if game.SinglePlayer() or ply:IsListenServerHost() then
        GA.ServerConfig.promptPreset=preset GA.ServerConfig.customPrompt=cfg.customPrompt
        GA.SaveServerConfig(nil,nil)
    end
    net.Start("GModAlive_PersonalitySaved") net.Send(ply)
end)

