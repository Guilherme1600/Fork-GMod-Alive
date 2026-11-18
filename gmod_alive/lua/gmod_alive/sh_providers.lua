local GA=GModAlive
GA.Providers={
    gemini={name="Google Gemini",model="gemini-flash-lite-latest",link="https://aistudio.google.com/apikey"},
    groq={name="Groq",url="https://api.groq.com/openai/v1/chat/completions",link="https://console.groq.com/keys"},
    deepseek={name="DeepSeek",model="deepseek-flash",url="https://api.deepseek.com/chat/completions",link="https://platform.deepseek.com/api_keys"},
    openrouter={name="OpenRouter",url="https://openrouter.ai/api/v1/chat/completions",link="https://openrouter.ai/settings/keys"},
    openai={name="OpenAI",url="https://api.openai.com/v1/chat/completions",link="https://platform.openai.com/api-keys"},
    -- Local model served by Ollama: no paid API, no key needed. The model ID is whatever you typed
    -- in F6 (e.g. llama3.1:8b, qwen2.5:7b, mistral, or your own custom model created with `ollama create`).
    ollama={name="Ollama (local model)",model="llama3.1",localModel=true,link="https://ollama.com/library"}
}
GA.ProviderOrder={"gemini","groq","deepseek","openrouter","openai","ollama"}

-- The Ollama address is a SERVER setting (server console / server.cfg / listen-server host), never
-- something a remote player can send, so players cannot point the server at arbitrary hosts.
if SERVER then
    CreateConVar("gmod_alive_ollama_url","http://127.0.0.1:11434",FCVAR_ARCHIVE,"Base URL of the Ollama server (e.g. http://127.0.0.1:11434)")
end
function GA.GetOllamaURL()
    local cv=GetConVar("gmod_alive_ollama_url")
    local url=string.Trim(cv and cv:GetString() or "http://127.0.0.1:11434")
    if not url:match("^https?://[%w%.%-_:%[%]]+") or url:find("[%c%s]") then url="http://127.0.0.1:11434" end
    url=url:gsub("/+$","")
    if not url:find("/chat/completions",1,true) then
        url=url:gsub("/v1$","").."/v1/chat/completions"
    end
    return url
end
-- All destinations are fixed. A remote player cannot supply a server HTTP URL.
function GA.CompatibleChatRequest(cfg,systemPrompt,history,text,callback)
    local provider=GA.Providers[cfg.provider]
    if not provider or not (provider.url or provider.localModel) then callback(false,"Unknown AI provider.") return end
    local isLocal=provider.localModel==true
    local url=isLocal and GA.GetOllamaURL() or provider.url
    if not isLocal and cfg.apiKey=="" then callback(false,"Enter the selected provider's API key in F6.") return end
    if cfg.model=="" or #cfg.model>180 or cfg.model:find("[%c]") then callback(false,"Enter a valid model ID for this provider in F6.") return end
    local messages={{role="system",content=systemPrompt}}
    for _,turn in ipairs(history or {}) do messages[#messages+1]={role=turn.role,content=turn.text} end
    messages[#messages+1]={role="user",content=text}
    local payload={model=cfg.model,messages=messages,stream=false}
    if cfg.provider=="openai" then payload.max_completion_tokens=768
    else payload.max_tokens=768 end
    if cfg.provider=="deepseek" then payload.thinking={type="disabled"} end
    local finished=false
    local function done(ok,result)
        if finished then return end finished=true callback(ok,result,cfg.model)
    end
    -- local models can be slow on CPU / first load, so they get a much longer timeout
    timer.Simple(isLocal and 170 or 65,function() done(false,provider.name.." request timed out.") end)
    local headers={}
    if cfg.apiKey~="" then headers.Authorization="Bearer "..cfg.apiKey end
    local queued=HTTP({url=url,method="POST",type="application/json",
        headers=headers,body=util.TableToJSON(payload),
        success=function(code,body)
            if code<200 or code>=300 then
                local errors={[400]="Check the model ID and supported request options.",[401]="Invalid API key.",[403]="Access denied for this key or region.",
                    [404]=isLocal and ("Ollama has no model '"..cfg.model.."'. Run: ollama pull "..cfg.model) or "Model or endpoint unavailable.",[429]="Quota or rate limit reached."}
                done(false,provider.name..": "..(errors[code] or ("HTTP "..code))) return
            end
            if not body or #body>2000000 then done(false,"AI response is too large.") return end
            local data=util.JSONToTable(body)
            local choice=istable(data) and data.choices and data.choices[1]
            local reply=choice and choice.message and choice.message.content
            if not isstring(reply) or string.Trim(reply)=="" then done(false,"The AI returned no dialogue. Check the selected model.") return end
            reply=string.Trim((reply:gsub("<think>.-</think>","")))
            if reply=="" then done(false,"The AI returned no dialogue. Check the selected model.") return end
            done(true,utf8.sub(reply,1,1800))
        end,failed=function(reason) done(false,isLocal and ("Could not reach Ollama at "..url.." (reason: "..tostring(reason or "unknown").."). Is 'ollama serve' running on the server machine?") or ("Could not connect to "..provider.name..".")) end})
    if not queued then done(false,"GMod could not start the AI request.") end
end
