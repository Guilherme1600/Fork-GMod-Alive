if SERVER then return end
local GA=GModAlive
function GA.OpenFirstRun()
    if IsValid(GA.SetupWindow) then GA.SetupWindow:MakePopup() return end
    local cfg=GA.ClientAPIConfig
    local f=vgui.Create("DFrame") GA.SetupWindow=f
    f:SetSize(math.min(680,ScrW()-32),math.min(620,ScrH()-32)) f:Center() f:SetTitle("") f:MakePopup()
    f:DockPadding(24,78,24,20)
    GA.UI.Frame(f,"GMod Alive","First-time setup")
    local continue=vgui.Create("DButton",f) continue:Dock(BOTTOM) continue:SetTall(42) continue:SetText("Continue to settings")
    continue:SetFont("GA.Settings.Body") continue:SetTextColor(color_white)
    GA.UI.Button(continue,true)
    local scroll=vgui.Create("DScrollPanel",f) scroll:Dock(FILL) scroll:DockMargin(0,0,0,16)
    local function text(value,height)
        local label=vgui.Create("DLabel",scroll) label:Dock(TOP) label:DockMargin(0,0,0,14) label:SetTall(height)
        label:SetWrap(true) label:SetFont("GA.Settings.Body") label:SetTextColor(GA.UI.text) label:SetText(value)
    end
    text("1. Choose your AI provider in Connection: Gemini, Groq, DeepSeek, OpenRouter or OpenAI. Paste that provider's key and exact model ID, then use Test connection.",72)
    text("For Gemini: open Google AI Studio, sign in, choose Get API key / Create API key, select a project and copy the key. Free access has model and project limits. Other providers have their own pricing.",82)
    local link=vgui.Create("DButton",scroll) link:Dock(TOP) link:DockMargin(0,0,0,16) link:SetTall(38) link:SetText("Open Google AI Studio")
    GA.UI.Button(link,false)
    link.DoClick=function() gui.OpenURL("https://aistudio.google.com/apikey") end
    text("2. Press G near an NPC and write your message. NPCs answer in the language of your latest message. F6 opens settings. Microphone recording is not used.",72)
    text("3. Choose text or voice with subtitles. Neural voice is OFF by default. If enabled, it uses your selected provider's speech API and may consume substantial audio tokens, free quota or paid credits. Some providers or languages do not support speech.",94)
    text("In Personality, choose Roleplay, Medieval RPG, Assistant or paste your own prompt. Subtitles appear above the NPC when speech starts; text mode shows them immediately.",72)
    continue.DoClick=function()
        cfg.firstRunComplete=true GA.SaveAndSyncClientAPIConfig(false) f:Close()
        timer.Simple(0,function() GA.OpenSettings() end)
    end
end
