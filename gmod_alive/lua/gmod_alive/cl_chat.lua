if SERVER then return end
local GA=GModAlive local C=GA.UI
function GA.OpenTalkDialog(npc,draft)
    local ply=LocalPlayer() if not IsValid(ply) then return end
    if not IsValid(npc) then npc=GA.FindTargetNPC(ply,GA.GetMaxDistance()) end
    if not IsValid(npc) then GA.AddHUDToast("No NPC nearby",true) return end
    if IsValid(GA.TalkWindow) then GA.TalkWindow:Close() end
    local creation=npc:GetCreationID() local profile=GA.InspectNPC(npc,ply)
    local f=vgui.Create("DFrame") GA.TalkWindow=f
    f:SetSize(math.min(590,ScrW()-32),128) f:SetPos((ScrW()-f:GetWide())/2,ScrH()-190)
    f:SetTitle("") f:SetDraggable(false) f:MakePopup()
    f.Paint=function(_,w,h)
        surface.SetDrawColor(C.bg) surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(C.line) surface.DrawOutlinedRect(0,0,w,h,1)
        draw.SimpleText(profile and profile.name or "NPC","GA.RPG.Body",14,12,C.text)
        draw.SimpleText("Enter to send · Esc to close","GA.RPG.Small",14,103,C.muted)
    end
    local input=vgui.Create("DTextEntry",f) input:SetPos(14,42) input:SetSize(f:GetWide()-108,38)
    input:SetPlaceholderText("Type a message…") input:SetMaximumCharCount(1500)
    input:SetAllowNonAsciiCharacters(true) input:SetHistoryEnabled(false) input:SetEnterAllowed(true)
    input:SetUpdateOnType(false) C.Entry(input)
    local send=vgui.Create("DButton",f) send:SetPos(f:GetWide()-84,42) send:SetSize(70,38) send:SetText("Send") C.Button(send,true)
    local inventory=vgui.Create("DButton",f) inventory:SetPos(f:GetWide()-110,91) inventory:SetSize(96,25) inventory:SetText("Inventory") C.Button(inventory,false)
    local function focus(open)
        if not IsValid(npc) or npc:GetCreationID()~=creation then return end
        net.Start("GModAlive_Conversation") net.WriteEntity(npc) net.WriteUInt(creation,32) net.WriteBool(open) net.SendToServer()
    end
    focus(true) local heartbeat=RealTime()+4
    local nativeThink=f.Think
    f.Think=function(self)
        if nativeThink then nativeThink(self) end
        if RealTime()>heartbeat then heartbeat=RealTime()+4 focus(true) end
    end
    f.OnRemove=function() if not f.submitted then focus(false) end end
    local aware=vgui.Create("DButton",f) aware:SetPos(f:GetWide()-216,91) aware:SetSize(100,25) C.Button(aware,false)
    local function refreshAware() aware:SetText(npc:GetNWBool("GModAlive_Aware",false) and "Awareness: ON" or "Awareness: OFF") end
    refreshAware()
    aware.DoClick=function()
        net.Start("GModAlive_ToggleAware") net.WriteUInt(npc:EntIndex(),16) net.WriteBool(not npc:GetNWBool("GModAlive_Aware",false)) net.SendToServer()
        timer.Simple(0.3,function() if IsValid(aware) and IsValid(npc) then refreshAware() end end)
    end
    inventory.DoClick=function() if GA.OpenNPCInventory then f:Close() GA.OpenNPCInventory(npc) end end
    local function submit()
        local text=string.Trim(input:GetValue())
        if text=="" then input:RequestFocus() return end
        if not IsValid(npc) or npc:GetCreationID()~=creation or ply:GetPos():DistToSqr(npc:GetPos())>GA.GetMaxDistance()^2 then GA.AddHUDToast("No NPC nearby",true) f:Close() return end
        net.Start("GModAlive_SendTurn") net.WriteUInt(npc:EntIndex(),16) net.WriteString(text) net.WriteBool(false) net.WriteUInt(0,16) net.SendToServer()
        GA.PendingVoiceReply=RealTime()+135 GA.PendingTarget=npc f.submitted=true f:Close()
    end
    send.DoClick=submit input.OnEnter=submit
    -- Extend the native handler instead of replacing it: Backspace, Delete,
    -- selection, key repeat, Unicode and clipboard editing remain native.
    input.OnKeyCode=function(_,key) if key==KEY_ESCAPE then f:Close() end end
    if isstring(draft) then input:SetText(utf8.sub(draft,1,1500)) input:SetCaretPos(utf8.len(input:GetValue())) end
    input:RequestFocus()
end
concommand.Add("gmod_alive_talk",function() GA.OpenTalkDialog() end)
