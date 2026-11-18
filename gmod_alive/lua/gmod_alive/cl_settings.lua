if SERVER then return end
local GA=GModAlive
local configPath="gmod_alive/client_api.json"
local C=GA.UI
surface.CreateFont("GA.Settings.Title",{font="Roboto",size=29,weight=800,extended=true})
surface.CreateFont("GA.Settings.Body",{font="Roboto",size=17,weight=500,extended=true})
surface.CreateFont("GA.Settings.Small",{font="Roboto",size=15,weight=400,extended=true})
GA.ClientAPIConfig=GA.ClientAPIConfig or {}
function GA.LoadClientAPIConfig()
    local path=file.Exists(configPath,"DATA") and configPath or GA.ConfigFile
    local data=util.JSONToTable(file.Read(path,"DATA") or "")
    if istable(data) then GA.ClientAPIConfig=data end
    local cfg=GA.ClientAPIConfig
    cfg.provider=GA.Providers[cfg.provider] and cfg.provider or "gemini"
    cfg.providerProfiles=istable(cfg.providerProfiles) and cfg.providerProfiles or {}
    if cfg.subtitleVersion~=2 then
        cfg.subtitleVersion=2 RunConsoleCommand("gmod_alive_subtitles","1")
    end
    cfg.ttsProvider="matched"
    cfg.speechProfiles=istable(cfg.speechProfiles) and cfg.speechProfiles or {}
    if cfg.neuralVoiceVersion~=1 then
        cfg.neuralVoiceVersion=1 cfg.responseMode="text" RunConsoleCommand("gmod_alive_tts_enabled","0")
    end
    cfg.voiceChoice=({auto=true,male=true,female=true})[cfg.voiceChoice] and cfg.voiceChoice or "auto"
    cfg.apiKey=tostring(cfg.apiKey or "") cfg.detectedModel=tostring(cfg.detectedModel or GA.DefaultModel)
    cfg.responseMode=cfg.responseMode=="voice" and "voice" or "text"
    cfg.promptPreset=GA.PromptPresets[cfg.promptPreset] and cfg.promptPreset or "rp"
    cfg.uiLanguage=({en=true,ptbr=true,es=true})[cfg.uiLanguage] and cfg.uiLanguage or "en"
    cfg.customPrompt=tostring(cfg.customPrompt or "") cfg.savedPresets=istable(cfg.savedPresets) and cfg.savedPresets or {}
end
GA.LoadClientAPIConfig()
local function persist() file.CreateDir(GA.DataDir) file.Write(configPath,util.TableToJSON(GA.ClientAPIConfig,true)) end
function GA.SaveAndSyncClientAPIConfig(runTest)
    persist()
    net.Start("GModAlive_SyncConfig") net.WriteString(GA.ClientAPIConfig.apiKey) net.WriteBool(runTest==true) net.WriteString(GA.ClientAPIConfig.provider) net.WriteString(GA.ClientAPIConfig.detectedModel) net.SendToServer()
    net.Start("GModAlive_Personality") net.WriteString(GA.ClientAPIConfig.promptPreset)
    net.WriteString(utf8.sub(GA.ClientAPIConfig.customPrompt,1,6000)) net.SendToServer()
    if runTest then GA.APITesting=true GA.APITestStarted=RealTime() GA.APIStatusText=GA.L("Testing AI connection…") GA.APIStatusOK=nil end
end
net.Receive("GModAlive_APITestResult",function()
    local ok=net.ReadBool() local latency=net.ReadUInt(16) local model=net.ReadString() local message=net.ReadString()
    GA.APITesting=false GA.APIStatusOK=ok
    GA.APIStatusText=ok and (GA.L("Conectada • ")..model.." • "..latency.." ms") or (GA.L("Não conectou: ")..message)
    if ok then
        GA.ClientAPIConfig.detectedModel=model
        local cfg=GA.ClientAPIConfig cfg.providerProfiles[cfg.provider]={apiKey=cfg.apiKey,model=model}
        if GA.SettingsControls and IsValid(GA.SettingsControls.model) then GA.SettingsControls.model:SetText(model) end
        persist()
    end
end)
net.Receive("GModAlive_PersonalitySaved",function() GA.PersonalitySavedAt=RealTime() end)
hook.Add("InitPostEntity","GModAlive_AutoSyncConfigOnJoin",function()
    timer.Simple(2,function()
        local ply=LocalPlayer()
        if IsValid(ply) and (game.SinglePlayer() or ply:IsListenServerHost()) then GA.LoadClientAPIConfig() RunConsoleCommand("gmod_alive_tts_enabled",GA.ClientAPIConfig.responseMode=="text" and "0" or "1") GA.SaveAndSyncClientAPIConfig(false) end
    end)
end)
local function page(parent)
    local scroll=vgui.Create("DScrollPanel",parent) scroll:Dock(FILL)
    local canvas=scroll:GetCanvas() canvas.rows={}
    canvas.PerformLayout=function(self,w)
        local y=18
        for _,row in ipairs(self.rows) do row.panel:SetPos(20,y) row.panel:SetSize(math.max(100,w-46),row.height) y=y+row.height+row.gap end
        self:SetTall(y+10)
    end
    return scroll,canvas
end
local function row(parent,p,h,gap)
    parent.rows[#parent.rows+1]={panel=p,height=h,gap=gap or 10} parent:InvalidateLayout(true) return p
end
local function label(parent,text,h,color)
    local p=vgui.Create("DLabel",parent) p:SetFont("GA.Settings.Body") p:SetTextColor(color or C.text) p:SetWrap(true) p:SetText(GA.L(text))
    return row(parent,p,h or 26)
end
local function button(parent,text,fn,accent)
    local p=vgui.Create("DButton",parent) p:SetText(GA.L(text)) p:SetFont("GA.Settings.Body") p:SetTextColor(accent and C.bg or C.text)
    p.Paint=function(self,w,h) draw.RoundedBox(0,0,0,w,h,accent and C.accent or (self:IsHovered() and C.input or C.input)) end
    C.Button(p,accent) p.DoClick=fn return row(parent,p,40)
end
local function entry(parent,value,height,multiline,placeholder)
    local p=vgui.Create("DTextEntry",parent) p:SetFont("GA.Settings.Body") p:SetMultiline(multiline==true)
    p:SetText(value or "") p:SetTextColor(C.text) p:SetCursorColor(C.accent) p:SetHighlightColor(Color(50,115,104))
    p:SetPaintBackground(false) p:SetMaximumCharCount(multiline and 6000 or 500)
    p.Paint=function(self,w,h)
        draw.RoundedBox(0,0,0,w,h,C.input)
        self:DrawTextEntryText(C.text,C.accent,C.text)
        if self:GetValue()=="" and not self:IsEditing() and placeholder then draw.SimpleText(GA.L(placeholder),"GA.Settings.Body",8,8,C.muted) end
    end
    C.Entry(p) return row(parent,p,height or 42)
end
local function checkbox(parent,text,cvar)
    local p=vgui.Create("DCheckBoxLabel",parent) p:SetText(GA.L(text)) p:SetFont("GA.Settings.Body") p:SetTextColor(C.text) p:SetConVar(cvar)
    return row(parent,p,29)
end
function GA.OpenSettings()
    if not GA.ClientAPIConfig.firstRunComplete and GA.OpenFirstRun then GA.OpenFirstRun() return end
    if IsValid(GA.SettingsWindow) then GA.SettingsWindow:Close() return end
    GA.LoadClientAPIConfig()
    local cfg=GA.ClientAPIConfig
    local f=vgui.Create("DFrame") GA.SettingsWindow=f
    f:SetTitle("") f:SetSize(math.min(900,ScrW()-36),math.min(760,ScrH()-36)) f:Center() f:MakePopup()
    f:DockPadding(16,84,16,16)
    local language=vgui.Create("DComboBox",f)
    C.Combo(language)
    language:SetPos(f:GetWide()-215,42) language:SetSize(188,28) language:SetSortItems(false)
    language:SetValue(({en="English",ptbr="Português (Brasil)",es="Español"})[cfg.uiLanguage])
    language:AddChoice("English","en") language:AddChoice("Português (Brasil)","ptbr") language:AddChoice("Español","es")
    language.OnSelect=function(_,_,_,id)
        local controls=GA.SettingsControls
        if controls and IsValid(controls.api) then
            cfg.apiKey=controls.api:GetValue() cfg.detectedModel=controls.model:GetValue() cfg.customPrompt=controls.editor:GetValue()
            cfg.providerProfiles[cfg.provider]={apiKey=cfg.apiKey,model=cfg.detectedModel}
        end
        cfg.uiLanguage=id persist() f:Close() timer.Simple(0,function() GA.OpenSettings() end)
    end

    C.Frame(f,"GMod Alive","Settings")
    local footer=vgui.Create("DPanel",f) footer:Dock(BOTTOM) footer:SetTall(52) footer.Paint=function() end
    local footerText=vgui.Create("DLabel",footer) footerText:Dock(FILL) footerText:SetFont("GA.Settings.Small") footerText:SetTextColor(C.muted) footerText:SetText(GA.L("F6: settings • G: type to a nearby NPC"))
    local save=vgui.Create("DButton",footer) save:Dock(RIGHT) save:SetWide(160) save:DockMargin(12,9,0,0) save:SetText(GA.L("Salvar tudo")) save:SetFont("GA.Settings.Body")
    C.Button(save,true)
    local nav=vgui.Create("DPanel",f) nav:Dock(TOP) nav:SetTall(46) nav:DockMargin(0,0,0,10) nav.Paint=function() end
    local holder=vgui.Create("DPanel",f) holder:Dock(FILL) holder.Paint=function(_,w,h) draw.RoundedBox(0,0,0,w,h,C.surface) end
    local pages,buttons={},{} local active=1
    for index,name in ipairs({GA.L("Conexão"),GA.L("Áudio e teclas"),GA.L("Personalidade"),GA.L("Legendas e jogo"),"NPC rules","Awareness & G-Man"}) do
        local b=vgui.Create("DButton",nav) b:SetText(GA.L(name)) b:SetFont("GA.Settings.Body") buttons[index]=b
        b.Paint=function(_,w,h) draw.RoundedBox(0,0,0,w,h,active==index and C.input or C.bg) end
        b:SetTextColor(C.text)
        local scroll,body=page(holder) pages[index]={scroll=scroll,body=body} scroll:SetVisible(index==1)
        b.DoClick=function()
            active=index for i,p in ipairs(pages) do p.scroll:SetVisible(i==index) end
        end
    end
    nav.PerformLayout=function(_,w) for i,b in ipairs(buttons) do b:SetPos((i-1)*(w/#buttons),0) b:SetSize(w/#buttons-6,42) end end
    local connection=pages[1].body
    label(connection,"AI provider",30,C.accent)
    local provider=vgui.Create("DComboBox",connection) provider:SetSortItems(false)
    C.Combo(provider)
    provider:SetValue(GA.Providers[cfg.provider].name)
    provider.Think=function(self) self:SetEnabled(not GA.APITesting) end
    for _,id in ipairs(GA.ProviderOrder) do provider:AddChoice(GA.Providers[id].name,id) end row(connection,provider,38)
    label(connection,GA.L("Chave da API"),24)
    local api=entry(connection,cfg.apiKey,46,false,GA.L("Cole sua chave aqui")) api:SetTextHidden(true)
    label(connection,GA.L("pegue a sua gratuitamente no google ai studio, siga o passo a passo na página do mod caso tenha dúvidas."),54,C.muted)
    label(connection,"Model ID (from your provider's model list)",25)
    local model=entry(connection,cfg.detectedModel,40,false,"Exact model ID")
    model.Think=function(self) self:SetEnabled(not GA.APITesting) end
    local speechModel,speechVoice
    local currentProvider=cfg.provider
    local function collectConnection()
        cfg.apiKey=string.Trim(api:GetValue()) cfg.detectedModel=string.Trim(model:GetValue())
        cfg.providerProfiles[currentProvider]={apiKey=cfg.apiKey,model=cfg.detectedModel}
        if IsValid(speechModel) and IsValid(speechVoice) then cfg.speechProfiles[currentProvider]={model=speechModel:GetValue(),voice=speechVoice:GetValue()} end
    end
    provider.OnSelect=function(_,_,_,id)
        collectConnection() cfg.provider=id currentProvider=id
        local saved=cfg.providerProfiles[id] or {}
        cfg.apiKey=saved.apiKey or "" cfg.detectedModel=saved.model or GA.Providers[id].model or ""
        api:SetText(cfg.apiKey) model:SetText(cfg.detectedModel)
        local spec=GA.SpeechProviders[id] or {} local speech=cfg.speechProfiles[id] or {}
        if IsValid(speechModel) then speechModel:SetText(speech.model or spec.model or "") speechVoice:SetText(speech.voice or spec.voice or "") end
        GA.APIStatusText="Provider changed. Save or test this connection." GA.APIStatusOK=nil
    end
    local reveal=vgui.Create("DCheckBoxLabel",connection) reveal:SetText(GA.L("Mostrar chave")) reveal:SetTextColor(C.text) reveal:SetFont("GA.Settings.Body")
    reveal.OnChange=function(_,value) api:SetTextHidden(not value) end row(connection,reveal,26)
    button(connection,"Get API key from selected provider",function() gui.OpenURL(GA.Providers[cfg.provider].link) end)
    local statusLabel=label(connection,"",65,C.muted)
    statusLabel.Think=function(self)
        local text=GA.APIStatusText or GA.L("Ainda não testada. Cole sua chave e teste a conexão.")
        if self:GetText()~=text then self:SetText(text) end
        self:SetTextColor(GA.APIStatusOK==true and C.accent or GA.APIStatusOK==false and C.bad or C.muted)
    end
    local test=button(connection,GA.L("Salvar chave e testar conexão"),function()
        if GA.APITesting then return end collectConnection()
        if cfg.apiKey=="" and not GA.Providers[cfg.provider].localModel then GA.APIStatusText=GA.L("Cole uma chave antes de testar.") GA.APIStatusOK=false return end
        GA.SaveAndSyncClientAPIConfig(true)
    end,true)
    test.Think=function(self) self:SetEnabled(not GA.APITesting) end
    label(connection,"Ollama (local model): choose 'Ollama (local model)', leave the key EMPTY and type your model name above exactly as in `ollama list` (e.g. llama3.1:8b, qwen2.5:7b or your own custom model). Ollama must be running on the machine that hosts the game server. Nothing is sent to a paid API.",78,C.muted)
    if game.SinglePlayer() or (IsValid(LocalPlayer()) and LocalPlayer():IsListenServerHost()) then
        label(connection,"Ollama address (server host only)",24)
        local ou=entry(connection,GetConVar("gmod_alive_ollama_url") and GetConVar("gmod_alive_ollama_url"):GetString() or "http://127.0.0.1:11434",38,false,"http://127.0.0.1:11434")
        ou.OnLoseFocus=function(self) RunConsoleCommand("gmod_alive_ollama_url",string.Trim(self:GetValue())) end
    end
    label(connection,GA.L("Provider quotas and pricing vary. Your key is stored locally and sent to this game server for AI requests. Use servers you trust."),52,C.muted)
    local audio=pages[2].body
    label(audio,"NPC voice",26,C.accent)
    checkbox(audio,"Enable neural NPC voice (uses your selected provider)","gmod_alive_tts_enabled")
    label(audio,"OFF BY DEFAULT. Neural speech can consume a lot of audio tokens and quickly exhaust a free plan's quota. Paid plans may incur extra charges. Each voiced reply makes a separate speech request.",91,C.accent)
    label(audio,"Gemini uses Gemini TTS. OpenAI, Groq and OpenRouter use their own speech APIs with the same provider key. DeepSeek currently has no supported public TTS route here. Failed speech falls back to text.",88,C.muted)
    local spec=GA.SpeechProviders[cfg.provider] or {} local speech=cfg.speechProfiles[cfg.provider] or {}
    label(audio,"Speech model ID",25) speechModel=entry(audio,speech.model or spec.model or "",40,false,"Provider's speech model")
    label(audio,"Voice ID",25) speechVoice=entry(audio,speech.voice or spec.voice or "",40,false,"Voice supported by this speech model")
    label(audio,"Gemini: auto varies voices by character; Charon, Algenib and Orus are deeper options. Groq's default model speaks English only. Model and voice IDs are specific to each provider. Voices are AI-generated.",87,C.muted)
    local tone=vgui.Create("DNumSlider",audio) tone:SetText("Voice tone") tone:SetMin(0.8) tone:SetMax(1.1) tone:SetDecimals(2)
    tone:SetConVar("gmod_alive_voice_tone") tone.Label:SetTextColor(C.text) row(audio,tone,45)
    label(audio,"Text input",30,C.accent)
    label(audio,"Press G near an NPC and type your message. Microphone recording is removed.",52,C.muted)
    local function binder(title,cvName,other)
        label(audio,title,25)
        local b=vgui.Create("DBinder",audio) b:SetValue(GetConVar(cvName):GetInt()) b:SetFont("GA.Settings.Body")
        b.OnChange=function(self,code)
            if code<=0 or code>KEY_LAST or code==KEY_F6 or code==KEY_BACKSPACE or code==KEY_DELETE or code==KEY_ENTER or code==KEY_ESCAPE or code==KEY_TAB or (other and code==GetConVar(other):GetInt()) then footerText:SetText(GA.L("Tecla inválida ou já utilizada. F6 fica para o menu.")) self:SetText(GA.L("Escolha outra tecla")) return end
            RunConsoleCommand(cvName,tostring(code)) footerText:SetText(GA.L("Atalho salvo."))
        end row(audio,b,38)
    end
    binder(GA.L("Abrir conversa por texto (padrão: G)"),"gmod_alive_talk_key","gmod_alive_inventory_key")
    binder("Your inventory (default: I)","gmod_alive_inventory_key","gmod_alive_talk_key")
    button(audio,"View nearby NPC inventory",function() if GA.OpenNPCInventory then GA.OpenNPCInventory() end end)
    local personality=pages[3].body
    label(personality,GA.L("Como o NPC deve conversar?"),30,C.accent)
    local selected=cfg.promptPreset
    local select=vgui.Create("DComboBox",personality) select:SetSortItems(false) select:SetValue(GA.L(GA.PromptPresets[selected].name))
    C.Combo(select)
    for _,id in ipairs({"rp","medieval","assistant","custom"}) do select:AddChoice(GA.L(GA.PromptPresets[id].name),id) end row(personality,select,39)
    local description=label(personality,GA.L(GA.PromptPresets[selected].description),47,C.muted)
    label(personality,GA.L("Seu system prompt — escreva ou cole com Ctrl+V"),25)
    local editor=entry(personality,cfg.customPrompt,235,true,GA.L("Ex.: Você é um cavaleiro viajante…"))
    label(personality,GA.L("Com Meu prompt, este texto substitui a personalidade base. Nos outros modos, funciona como instrução adicional. O idioma acompanha a mensagem recebida."),57,C.muted)
    select.OnSelect=function(_,_,_,id) selected=id description:SetText(GA.L(GA.PromptPresets[id].description)) end
    button(personality,GA.L("Usar o texto do preset no editor"),function()
        editor:SetText(GA.PromptPresets[selected].text) selected="custom" select:SetValue(GA.L("Meu prompt")) description:SetText(GA.L(GA.PromptPresets.custom.description))
    end)
    local presetName=entry(personality,"",38,false,GA.L("Nome para salvar seu preset pessoal"))
    local saved
    button(personality,GA.L("Salvar preset pessoal neste computador"),function()
        local name=utf8.sub(string.Trim(presetName:GetValue()),1,50)
        if name=="" then footerText:SetText(GA.L("Dê um nome ao preset pessoal.")) return end
        local existed=cfg.savedPresets[name]~=nil
        cfg.savedPresets[name]={preset=selected,text=editor:GetValue()} persist()
        if not existed and IsValid(saved) then saved:AddChoice(name) end
        footerText:SetText(GA.L("Preset salvo: ")..name)
    end)
    saved=vgui.Create("DComboBox",personality) saved:SetValue(GA.L("Carregar um preset pessoal"))
    C.Combo(saved)
    for name in SortedPairs(cfg.savedPresets) do saved:AddChoice(name) end row(personality,saved,38)
    saved.OnSelect=function(_,_,name)
        local item=cfg.savedPresets[name] if not item then return end
        selected=GA.PromptPresets[item.preset] and item.preset or "custom" editor:SetText(item.text or "")
        select:SetValue(GA.L(GA.PromptPresets[selected].name)) description:SetText(GA.L(GA.PromptPresets[selected].description))
    end
    local display=pages[4].body
    label(display,GA.L("Resposta visível e conversa natural"),30,C.accent)
    label(display,"Reply mode",26)
    local replyMode=vgui.Create("DComboBox",display) replyMode:SetSortItems(false)
    C.Combo(replyMode)
    replyMode:SetValue(cfg.responseMode=="text" and "Text — fast" or "Voice + subtitles")
    replyMode:AddChoice("Text — fast","text") replyMode:AddChoice("Voice + subtitles","voice")
    replyMode.OnSelect=function(_,_,_,id) cfg.responseMode=id RunConsoleCommand("gmod_alive_tts_enabled",id=="voice" and "1" or "0") end row(display,replyMode,38)
    label(display,"Neural voice is optional and consumes additional provider quota. Leave it disabled for fast text-only replies.",59,C.accent)
    button(display,"Open first-time setup again",function() f:Close() timer.Simple(0,GA.OpenFirstRun) end)
    checkbox(display,GA.L("Mostrar legenda da resposta do NPC"),"gmod_alive_subtitles")
    checkbox(display,GA.L("Show NPC thinking status"),"gmod_alive_status_visible")

    label(display,GA.L("Idioma automático"),25)
    label(display,GA.L("The NPC replies in the language of your latest written message. You can explicitly ask for another language. This applies to all providers and personality presets."),65,C.muted)
    local function slider(title,cv,min,max,decimals)
        local s=vgui.Create("DNumSlider",display) s:SetText(GA.L(title)) s:SetMin(min) s:SetMax(max) s:SetDecimals(decimals) s:SetConVar(cv) s.Label:SetTextColor(C.text) return row(display,s,45)
    end
    slider(GA.L("Volume da voz"),"gmod_alive_tts_volume",0,2,2)
    slider(GA.L("Distância para conversar (unidades)"),"gmod_alive_distance",60,1500,0)
    checkbox(display,GA.L("Permitir ações físicas do NPC"),"gmod_alive_actions_enabled")
    button(display,GA.L("Apagar memória das conversas"),function() net.Start("GModAlive_ClearMemory") net.SendToServer() footerText:SetText(GA.L("Pedido de limpeza de memória enviado.")) end)
    local rules=pages[5].body
    label(rules,"NPC behaviour",27,C.accent)
    label(rules,"Base gameplay rules apply in every personality preset. Changes are saved automatically on your local server.",51,C.muted)
    for _,rule in ipairs(GA.RuleOptions) do checkbox(rules,rule.label,"gmod_alive_rule_"..rule.id) end
    label(rules,"Own inventory",27,C.accent)
    local armed=vgui.Create("DNumSlider",rules) armed:SetText("Armed NPC chance (%)") armed:SetMin(0) armed:SetMax(100) armed:SetDecimals(0)
    armed:SetConVar("gmod_alive_armed_chance") armed.Label:SetTextColor(C.text) row(rules,armed,45)
    label(rules,"NPCs can start with their own finite weapons and items. You do not have to supply them. Weapons and loot are actual game objects, not imaginary possessions.",67,C.muted)
    label(rules,"Threats and persuasion",27,C.accent)
    label(rules,"Threatened NPCs may flee, surrender or defend themselves. In-world persuasion can lead them to confront another nearby NPC or start a conversation. Their character and current context guide the decision.",86,C.muted)
    label(rules,"Collect and transfer",27,C.accent)
    label(rules,"NPCs approach reachable weapons, items and small props before collecting them. Giving items consumes their inventory. Custom NPC frameworks may require additional movement or combat support.",76,C.muted)
    local aw=pages[6].body
    local function numSlider(text,cvar,min,max,dec)
        local sl=vgui.Create("DNumSlider",aw) sl:SetText(text) sl:SetMin(min) sl:SetMax(max) sl:SetDecimals(dec or 0)
        sl:SetConVar(cvar) sl.Label:SetTextColor(C.text) row(aw,sl,45) return sl
    end
    label(aw,"Self-awareness",27,C.accent)
    label(aw,"NPCs watch the world and react on their own (a friend killed, someone attacked, etc.). If the global option is off you can enable it per NPC with the 'Awareness' button in the talk window.",67,C.muted)
    checkbox(aw,"Enable self-awareness for ALL NPCs","gmod_alive_aware_enabled")
    numSlider("Think every (seconds)","gmod_alive_aware_interval",2,120,0)
    numSlider("NPC awareness radius (units)","gmod_alive_aware_npc_radius",200,5000,0)
    numSlider("Player radius (units): NPC thinks only if a player is this close","gmod_alive_aware_player_radius",200,8000,0)
    numSlider("Max NPCs thinking per area","gmod_alive_aware_max_per_area",1,30,0)
    numSlider("Reaction delay to events (seconds)","gmod_alive_aware_react_delay",0,10,1)
    label(aw,"Extras",27,C.accent)
    checkbox(aw,"Show NPC names above their heads","gmod_alive_nametags")
    checkbox(aw,"NPCs may shoot props and doors when asked","gmod_alive_shoot_props")
    checkbox(aw,"G-Man god powers (delete / spawn / command everyone; admins and single-player only)","gmod_alive_gman_god")
    label(aw,"Talk to the G-Man (npc_gman): 'delete everything I am aiming at', 'spawn a jeep above me', 'everyone drop your weapons', 'all combine freeze'. Ask him to 'release everyone' to undo.",67,C.muted)
    save.DoClick=function()
        collectConnection() cfg.responseMode=GetConVar("gmod_alive_tts_enabled"):GetBool() and "voice" or "text" cfg.promptPreset=selected cfg.customPrompt=utf8.sub(editor:GetValue(),1,6000)
        if selected=="custom" and string.Trim(cfg.customPrompt)=="" then footerText:SetText(GA.L("Escreva seu prompt ou selecione um preset.")) return end
        GA.SaveAndSyncClientAPIConfig(false) footerText:SetText(GA.L("Configurações salvas e enviadas ao jogo."))
    end
    GA.SettingsControls={api=api,test=test,preset=select,editor=editor,save=save,pages=pages,model=model,provider=provider}
end
function GA.BuildSettingsPanel(p)
    p:Clear() p:Help(GA.L("Configure AI providers, NPC voice, text key, personality and subtitles in F6."))
    local b=p:Button(GA.L("Abrir GMod Alive — F6")) b.DoClick=GA.OpenSettings
end
hook.Add("AddToolMenuCategories","GModAlive_SettingsCategory",function() spawnmenu.AddToolCategory("Options","GMod Alive","GMod Alive") end)
hook.Add("PopulateToolMenu","GModAlive_PopulateToolMenu",function() spawnmenu.AddToolMenuOption("Options","GMod Alive","GModAlive_Settings","GMod Alive","","",GA.BuildSettingsPanel) end)
concommand.Add("gmod_alive_menu",GA.OpenSettings)
local wasDown=false
hook.Add("Think","GModAlive_SettingsShortcut",function()
    local down=input.IsKeyDown(KEY_F6)
    if down and not wasDown and not input.IsKeyTrapping() and not gui.IsConsoleVisible() and not gui.IsGameUIVisible() then GA.OpenSettings() end wasDown=down
    if GA.APITesting and RealTime()-(GA.APITestStarted or 0)>70 then GA.APITesting=false GA.APIStatusOK=false GA.APIStatusText=GA.L("A conexão demorou demais. Tente novamente.") end
end)
