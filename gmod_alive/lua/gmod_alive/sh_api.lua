local GA=GModAlive
function GA.GeminiRequest(apiKey,model,payload,callback)
    if not isstring(model) or #model>100 or not model:match("^[%w._%-]+$") then callback(false,"Invalid Gemini model.") return end
    if not isstring(apiKey) or string.Trim(apiKey)=="" then callback(false,"Configure your Gemini API key in Options > GMod Alive.") return end
    local done=false
    local function finish(ok,result,code) if done then return end done=true callback(ok,result,code) end
    timer.Simple(65,function() finish(false,"Gemini timed out. Try again.",0) end)
    local queued=HTTP({url="https://generativelanguage.googleapis.com/v1beta/models/"..model..":generateContent",
        method="POST",type="application/json",headers={["x-goog-api-key"]=apiKey},body=util.TableToJSON(payload),
        success=function(code,body)
            if code<200 or code>=300 then
                local errors={[400]="Gemini rejected the request. Check model support and key.",[401]="Invalid Gemini API key.",
                    [403]="Gemini access denied. Check the key, project and region.",[404]="Gemini model is unavailable.",
                    [429]="Gemini quota or rate limit reached. Check AI Studio usage.",[500]="Gemini had a temporary error.",[503]="Gemini is currently busy."}
                finish(false,errors[code] or ("Gemini HTTP "..code),code) return
            end
            if not body or #body>12000000 then finish(false,"Gemini response is too large.",code) return end
            local data=util.JSONToTable(body)
            if not istable(data) then finish(false,"Invalid Gemini response.",code) return end
            finish(true,data,code)
        end,failed=function() finish(false,"Could not connect to Gemini. Check the internet connection.",0) end})
    if not queued then finish(false,"GMod could not start the Gemini HTTPS request.",0) end
end
