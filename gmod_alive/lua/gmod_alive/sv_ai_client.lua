-- ============================================================================
-- GMod Alive — Talking AI NPCs
-- Google Gemini AI Client with Multi-Model Auto-Failover & Memory (sv_ai_client.lua)
-- ============================================================================

if CLIENT then return end

GModAlive = GModAlive or {}
local GA = GModAlive

GA.ServerConfig = GA.ServerConfig or {
	apiKey = "",
	detectedModel = "gemini-flash-lite-latest"
}

GA.PlayerConfigs = GA.PlayerConfigs or {}
GA.NpcMemory = GA.NpcMemory or {}

local MAX_HISTORY_TURNS = 4

function GA.LoadServerConfig()
	if not file.IsDir(GA.DataDir, "DATA") then
		file.CreateDir(GA.DataDir)
	end
	if file.Exists(GA.ConfigFile, "DATA") then
		local raw = file.Read(GA.ConfigFile, "DATA")
		local ok, decoded = pcall(util.JSONToTable, raw or "")
		if ok and istable(decoded) then
			GA.ServerConfig.apiKey = string.Trim(tostring(decoded.apiKey or GA.ServerConfig.apiKey))
			local savedModel = string.Trim(tostring(decoded.detectedModel or decoded.model or ""))
			if savedModel == ""  then
				savedModel = GA.DefaultModel
			end
			GA.ServerConfig.detectedModel = savedModel
            GA.ServerConfig.provider = GA.Providers[decoded.provider] and decoded.provider or "gemini"
			GA.ServerConfig.promptPreset = GA.PromptPresets[decoded.promptPreset] and decoded.promptPreset or "rp"
			GA.ServerConfig.customPrompt = utf8.sub(tostring(decoded.customPrompt or ""),1,6000)
		end
	end
end

function GA.SaveServerConfig(apiKey, detectedModel)
	if not file.IsDir(GA.DataDir, "DATA") then
		file.CreateDir(GA.DataDir)
	end
	if apiKey and string.Trim(apiKey) ~= "" then
		GA.ServerConfig.apiKey = string.Trim(apiKey)
	end
	if detectedModel and string.Trim(detectedModel) ~= "" then
		GA.ServerConfig.detectedModel = string.Trim(detectedModel)
	end
	file.Write(GA.ConfigFile, util.TableToJSON(GA.ServerConfig, true))
end

GA.LoadServerConfig()

function GA.GetActiveConfig(ply)
    local pCfg=IsValid(ply) and GA.PlayerConfigs[ply:SteamID64() or "local"] or nil
    local cfg=pCfg or GA.ServerConfig
    local provider=GA.Providers[cfg.provider] and cfg.provider or "gemini"
    return {provider=provider,apiKey=string.Trim(tostring(cfg.apiKey or "")),
        model=string.Trim(tostring(cfg.detectedModel or GA.Providers[provider].model or ""))}
end

-- Build ordered list of models to try (starting with preferredModel, then all candidates)
local function BuildModelFailoverQueue(preferredModel)
	local queue = {}
	local seen = {}

	local cleanPref = string.gsub(string.Trim(tostring(preferredModel or "")), "^models/", "")
	if cleanPref ~= "" and cleanPref ~= "Auto" then
		table.insert(queue, cleanPref)
		seen[cleanPref] = true
	end

	for _, m in ipairs(GA.GeminiCandidateModels) do
		if not seen[m] then
			table.insert(queue, m)
			seen[m] = true
		end
	end

	return queue
end

local function GetNpcMemoryKey(ent)
	if not IsValid(ent) then return "invalid" end
	return tostring(ent:GetCreationID() or ent:EntIndex())
end

function GA.GetNpcHistory(ent)
	local key = GetNpcMemoryKey(ent)
	GA.NpcMemory[key] = GA.NpcMemory[key] or {}
	while #GA.NpcMemory[key] > MAX_HISTORY_TURNS * 2 do table.remove(GA.NpcMemory[key], 1) end
	return GA.NpcMemory[key]
end

function GA.AppendNpcHistory(ent, userText, assistantText)
	local key = GetNpcMemoryKey(ent)
	GA.NpcMemory[key] = GA.NpcMemory[key] or {}
	local hist = GA.NpcMemory[key]

	if userText and string.Trim(userText) ~= "" then
		table.insert(hist, { role = "user", text = string.Trim(userText) })
	end
	if assistantText and string.Trim(assistantText) ~= "" then
		table.insert(hist, { role = "assistant", text = string.Trim(assistantText) })
	end

	while #hist > (MAX_HISTORY_TURNS * 2) do
		table.remove(hist, 1)
	end
end

function GA.ClearAllNpcMemory()
	GA.NpcMemory = {}
end

function GA.ParseAIResponse(rawText)
	local text = tostring(rawText or "")
	text = string.Trim(text)

	local language=text:match("%[[Ll][Aa][Nn][Gg]:%s*([%a%-]+)%s*%]")
    text=text:gsub("%[[Ll][Aa][Nn][Gg]:%s*[%a%-]+%s*%]", "")
    local heardText = nil
	local sHeard, eHeard, capturedHeard = string.find(text, "%[[Hh]eard:%s*(.-)%]")
	if sHeard and capturedHeard then
		heardText = string.Trim(capturedHeard)
		text = string.sub(text, 1, sHeard - 1) .. string.sub(text, eHeard + 1)
		text = string.Trim(text)
	end

	local actionTag = nil
	local actionParam = nil

	for _, validAct in ipairs(GA.SupportedActions) do
		local patParam = "%[%s*" .. validAct .. "%s*=%s*(.-)%s*%]"
		local sP, eP, capP = string.find(text, patParam)
		if sP then
			actionTag = validAct
			actionParam = string.Trim(capP or "")
			text = string.sub(text, 1, sP - 1) .. string.sub(text, eP + 1)
			break
		end

		local patSimple = "%[%s*" .. validAct .. "%s*%]"
		local sA, eA = string.find(text, patSimple)
		if sA then
			actionTag = validAct
			text = string.sub(text, 1, sA - 1) .. string.sub(text, eA + 1)
			break
		end
	end

	text = string.gsub(text, "%[[%w_=%-:%s]+%]", "")
	text = string.gsub(text, "%*%*(.-)%*%*", "%1")
	text = string.gsub(text, "%*(.-)%*", "%1")
	text = string.gsub(text, "%s+", " ")
	text = string.Trim(text)

	return {
		spokenText = text,
        language = language or "en-US",
		actionTag = actionTag,
		actionParam = actionParam,
		heardText = heardText
	}
end

-- Request to Google Gemini with automatic multi-model cascade failover (handles 503 High Demand, 404, 429)
local function RequestGeminiWithFailover(apiKey, modelQueue, queueIdx, systemPrompt, history, userText, audioBase64, callback)
    local modelName=modelQueue[queueIdx]
    if not modelName then callback(false,"No available Gemini model.") return end
    local contents={}
    for _,turn in ipairs(history or {}) do
        table.insert(contents,{role=turn.role=="assistant" and "model" or "user",parts={{text=turn.text}}})
    end
    local parts={{text=userText or "Hello"}}
    table.insert(contents,{role="user",parts=parts})
    local generation={temperature=0.8,maxOutputTokens=768}
    if modelName=="gemini-2.5-flash" then generation.thinkingConfig={thinkingBudget=0} end
    GA.GeminiRequest(apiKey,modelName,{systemInstruction={parts={{text=systemPrompt}}},contents=contents,generationConfig=generation},function(ok,data,code)
        if not ok then
            -- Only an unavailable model permits fallback; never conceal quota/auth errors.
            if code==404 and queueIdx<#modelQueue then
                RequestGeminiWithFailover(apiKey,modelQueue,queueIdx+1,systemPrompt,history,userText,audioBase64,callback)
            else callback(false,data,modelName) end
            return
        end
        local candidate=data.candidates and data.candidates[1]
        local output=candidate and candidate.content and candidate.content.parts
        local texts={}
        for _,part in ipairs(output or {}) do if part.text and not part.thought then texts[#texts+1]=part.text end end
        local text=string.Trim(table.concat(texts))
        if text=="" then callback(false,"Gemini returned no spoken response (possibly blocked).",modelName) return end
        callback(true,utf8.sub(text,1,1800),modelName)
    end)
end

function GA.AutoDetectGeminiModel(apiKey, callback)
	local queue = BuildModelFailoverQueue(GA.ServerConfig.detectedModel)
	callback(true, queue[1] or "gemini-flash-lite-latest")
end

local function requestConfigured(cfg,systemPrompt,history,userText,callback)
    if cfg.provider=="gemini" then
        RequestGeminiWithFailover(cfg.apiKey,BuildModelFailoverQueue(cfg.model),1,systemPrompt,history,userText,nil,callback)
    else GA.CompatibleChatRequest(cfg,systemPrompt,history,userText,callback) end
end

function GA.GenerateNPCResponse(opts, callback)
	local ply = opts.ply
	local npc = opts.npc
	local userText = string.Trim(tostring(opts.userText or ""))


	if not IsValid(npc) then
		callback(false, "Invalid NPC.")
		return
	end

	local cfg = GA.GetActiveConfig(ply)
	if cfg.apiKey == "" then
		callback(false, "No API key configured for this provider. Open F6 > Connection.")
		return
	end

	local systemPrompt, profile = GA.BuildSystemPrompt(npc, ply)
	local history = GA.GetNpcHistory(npc)

	requestConfigured(cfg, systemPrompt, history, userText, function(ok, rawOutput, usedModel)
		if not ok then
			callback(false, rawOutput, profile)
			return
		end

        if IsValid(ply) and usedModel and usedModel ~= "" and GA.GetActiveConfig(ply).provider==cfg.provider and GA.GetActiveConfig(ply).apiKey==cfg.apiKey then
			local steamKey = ply:SteamID64() or "local"
			GA.PlayerConfigs[steamKey] = GA.PlayerConfigs[steamKey] or {}
			GA.PlayerConfigs[steamKey].detectedModel = usedModel
		end

		local parsed = GA.ParseAIResponse(rawOutput)
        if profile then profile.responseLanguage=parsed.language end
		local finalUserText = parsed.heardText or (userText ~= "" and userText or "(Voice Message)")
		if parsed.spokenText ~= "" then
			GA.AppendNpcHistory(npc, finalUserText, parsed.spokenText)
		end

		callback(true, parsed, profile, finalUserText)
	end)
end

-- Auto-detect working model via live failover cascade & test connection
function GA.TestAPIConnection(ply, callback)
	local cfg = GA.GetActiveConfig(ply)
	if cfg.apiKey == "" then
		callback(false, "Enter an API key for the selected provider first!", 0, "")
		return
	end

	local startT = SysTime()
	local modelQueue = BuildModelFailoverQueue(cfg.model)
	local testSys = "You are the connection test for 'GMod Alive — Talking AI NPCs' in Garry's Mod. Reply in 1 short sentence in English confirming the AI is connected!"
	local testMsg = "Test connection!"

	requestConfigured(cfg, testSys, {}, testMsg, function(ok, res, workingModel)
		local latencyMs = math.Round((SysTime() - startT) * 1000)
		if ok and workingModel and workingModel ~= "" then
			local steamKey = IsValid(ply) and (ply:SteamID64() or "local") or "local"
			GA.PlayerConfigs[steamKey] = GA.PlayerConfigs[steamKey] or {}
			GA.PlayerConfigs[steamKey].detectedModel = workingModel
			if game.SinglePlayer() or (IsValid(ply) and (ply:IsSuperAdmin() or ply:IsListenServerHost())) then
				GA.SaveServerConfig(cfg.apiKey, workingModel)
			end
		end
		callback(ok, res, latencyMs, workingModel or "gemini-flash-lite-latest")
	end)
end
