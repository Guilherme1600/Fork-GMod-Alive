if SERVER then return end
local GA=GModAlive
GA.SpeechProviders={
    gemini={model="gemini-2.5-flash-preview-tts",voice="auto"},
    openai={model="gpt-4o-mini-tts",voice="onyx",url="https://api.openai.com/v1/audio/speech"},
    groq={model="canopylabs/orpheus-v1-english",voice="troy",url="https://api.groq.com/openai/v1/audio/speech"},
    openrouter={model="x-ai/grok-voice-tts-1.0",voice="rex",url="https://openrouter.ai/api/v1/audio/speech"}
}
function GA.RequestNeuralSpeech(text,language,npc,isFemale,callback)
    local cfg=GA.ClientAPIConfig or {} local provider=cfg.provider or "gemini"
    local spec=GA.SpeechProviders[provider]
    if not spec then callback(false,"This provider has no supported speech API. Text replies remain available.") return end
    if not cfg.apiKey or cfg.apiKey=="" then callback(false,"Enter this provider's API key in F6.") return end
    local profile=(cfg.speechProfiles or {})[provider] or {}
    local model=string.Trim(profile.model or spec.model) local voice=string.Trim(profile.voice or spec.voice)
    if model=="" or #model>180 or voice=="" or #voice>100 then callback(false,"Set a valid speech model and voice in F6.") return end
    if provider=="groq" and model==spec.model and not tostring(language):lower():match("^en") then
        callback(false,"Groq's default speech model supports English. Choose a supported language/model or use text.") return
    end
    if provider=="gemini" then
        if voice=="auto" then
            local pool=isFemale and {"Kore","Aoede"} or {"Charon","Algenib","Orus"}
            local seed=tonumber(util.CRC((npc:GetModel() or "")..npc:GetCreationID())) or 0 voice=pool[(seed%#pool)+1]
        end
        GA.GeminiRequest(cfg.apiKey,model,{contents={{role="user",parts={{text="Read this dialogue only, naturally in its original language ("..tostring(language).."). Mature, grounded voice.\n"..utf8.sub(text,1,1800)}}}},
            generationConfig={responseModalities={"AUDIO"},speechConfig={voiceConfig={prebuiltVoiceConfig={voiceName=voice}}}}},function(ok,data)
                if not ok then callback(false,data) return end
                local candidate=data.candidates and data.candidates[1] local chunks={} local mime=""
                for _,part in ipairs(candidate and candidate.content and candidate.content.parts or {}) do
                    local audio=part.inlineData or part.inline_data
                    if audio and audio.data then local raw=util.Base64Decode(audio.data) if raw then chunks[#chunks+1]=raw mime=audio.mimeType or audio.mime_type or "" end end
                end
                local raw=table.concat(chunks)
                if #raw<100 or #raw>12000000 then callback(false,"Gemini returned no valid speech audio.") return end
                if raw:sub(1,4)~="RIFF" then
                    mime=mime:lower()
                    if not mime:find("l16",1,true) and not mime:find("pcm",1,true) then callback(false,"Unexpected Gemini audio format.") return end
                    local rate=tonumber(mime:match("rate=(%d+)")) or 24000
                    if rate<8000 or rate>96000 or #raw%2~=0 then callback(false,"Invalid speech sample format.") return end
                    raw=GA.PackVoiceWav(raw,rate,1)
                end
                callback(true,raw,"wav")
            end)
        return
    end
    local payload={model=model,voice=voice,input=utf8.sub(text,1,1800),response_format=provider=="groq" and "wav" or "mp3"}
    if provider=="openai" then payload.instructions="Speak naturally in the language of the supplied dialogue, with a mature voice." end
    local done=false
    local function finish(ok,data,ext) if done then return end done=true callback(ok,data,ext) end
    timer.Simple(65,function() finish(false,"Neural speech timed out. Showing text instead.") end)
    local queued=HTTP({url=spec.url,method="POST",type="application/json",headers={Authorization="Bearer "..cfg.apiKey},body=util.TableToJSON(payload),
        success=function(code,body)
            if code<200 or code>=300 then finish(false,"Speech API HTTP "..code..". Check model, voice, quota and billing in F6.") return end
            if not body or #body<100 or #body>12000000 then finish(false,"Invalid speech audio response.") return end
            local wav=body:sub(1,4)=="RIFF" local mp3=body:sub(1,3)=="ID3" or (body:byte(1)==255 and (body:byte(2) or 0)>=224)
            if not wav and not mp3 then finish(false,"Unsupported speech audio format. Use MP3 or WAV.") return end
            finish(true,body,wav and "wav" or "mp3")
        end,failed=function() finish(false,"Could not connect to this provider's speech API.") end})
    if not queued then finish(false,"GMod could not start the speech request.") end
end
