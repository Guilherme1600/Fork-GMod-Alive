if SERVER then return end
local GA=GModAlive
-- Remove previous hooks during Lua auto-refresh as well as on a fresh load.
for _,pair in ipairs({{"Think","GModAlive_KeyBindMonitor"},{"PlayerStartVoice","GModAlive_NativeVoiceStart"},
    {"PlayerEndVoice","GModAlive_NativeVoiceEnd"},{"HUDShouldDraw","GModAlive_HideNativeVoiceIndicator"}}) do hook.Remove(pair[1],pair[2]) end
GA.VoiceState=nil
GA.StartPushToTalk=nil GA.StopPushToTalk=nil
concommand.Remove("gmod_alive_mic_status")
local held,inventoryHeld=false,false
hook.Add("Think","GModAlive_TextKey",function()
    local blocked=not GA.IsEnabled() or gui.IsGameUIVisible() or gui.IsConsoleVisible() or IsValid(vgui.GetKeyboardFocus()) or GA.IsChatOpen
    local cv=GetConVar("gmod_alive_talk_key") local key=cv and cv:GetInt() or KEY_G
    local down=key>0 and input.IsButtonDown(key)
    if down and not held and not blocked and not IsValid(GA.TalkWindow) then
        local npc=GA.FindTargetNPC(LocalPlayer(),GA.GetMaxDistance())
        if IsValid(npc) then GA.OpenTalkDialog(npc) else GA.AddHUDToast("No NPC nearby",true) end
    end
    held=down
    local invCV=GetConVar("gmod_alive_inventory_key") local invKey=invCV and invCV:GetInt() or KEY_I
    local invDown=invKey>0 and input.IsButtonDown(invKey)
    if invDown and not inventoryHeld and not blocked and GA.OpenPlayerInventory then GA.OpenPlayerInventory() end
    inventoryHeld=invDown
end)
hook.Add("StartChat","GModAlive_ChatFocus",function() GA.IsChatOpen=true end)
hook.Add("FinishChat","GModAlive_ChatFocus",function() GA.IsChatOpen=false end)
