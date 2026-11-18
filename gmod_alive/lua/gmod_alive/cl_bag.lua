if SERVER then return end
local GA=GModAlive local C=GA.UI
local function request(npc)
    net.Start("GModAlive_Bag") net.WriteEntity(IsValid(npc) and npc or NULL) net.WriteUInt(IsValid(npc) and npc:GetCreationID() or 0,32) net.SendToServer()
end
local function closeFocus(npc,creation,open)
    if not IsValid(npc) or npc:GetCreationID()~=creation then return end
    net.Start("GModAlive_Conversation") net.WriteEntity(npc) net.WriteUInt(creation,32) net.WriteBool(open) net.SendToServer()
end
local function gridSection(parent,title)
    local header=vgui.Create("DLabel",parent) header:Dock(TOP) header:SetTall(29) header:DockMargin(0,8,0,5)
    header:SetText(title) header:SetFont("GA.RPG.Body") header:SetTextColor(C.text)
    local grid=vgui.Create("DIconLayout",parent) grid:Dock(TOP) grid:SetSpaceX(5) grid:SetSpaceY(5)
    return grid,header
end
local function openBag(npc)
    if IsValid(GA.InventoryWindow) then GA.InventoryWindow:Close() end
    local f=vgui.Create("DFrame") GA.InventoryWindow=f f.npc=IsValid(npc) and npc or NULL f.creation=IsValid(npc) and npc:GetCreationID() or 0
    f:SetSize(math.min(780,ScrW()-32),math.min(750,ScrH()-32)) f:Center() f:MakePopup() f:DockPadding(24,78,24,18)
    C.Frame(f,"Inventory",IsValid(npc) and "Your belongings  /  Give items to this NPC" or "Your belongings")
    local footer=vgui.Create("DPanel",f) footer:Dock(BOTTOM) footer:SetTall(187) footer:DockMargin(0,16,0,0) footer.Paint=function() end
    local catalogueButton=vgui.Create("DButton",footer) catalogueButton:Dock(TOP) catalogueButton:SetTall(31) catalogueButton:DockMargin(0,0,0,7)
    catalogueButton:SetText("Add items — open catalogue") C.Button(catalogueButton,false)
    catalogueButton:SetTooltip("Create items in single-player or as a server administrator.")
    catalogueButton.DoClick=function()
        local open=not f.cataloguePanel:IsVisible() f.cataloguePanel:SetVisible(open)
        f:SetWide(math.min(open and 1080 or 780,ScrW()-32)) f:Center()
        if open and not f.catalogueBuilt then GA.BuildCatalogue(f.cataloguePanel,f) f.catalogueBuilt=true end
        f:InvalidateLayout(true)
    end
    local selected=vgui.Create("DLabel",footer) selected:Dock(TOP) selected:SetTall(39) selected:SetWrap(true) selected:SetFont("GA.RPG.Body") selected:SetTextColor(C.text)
    selected:SetText("Select an item. Weapons, ammunition and collected objects appear here.") f.selectionLabel=selected
    local actions=vgui.Create("DPanel",footer) actions:Dock(TOP) actions:SetTall(34) actions.Paint=function() end
    local amount=vgui.Create("DNumberWang",actions) amount:Dock(LEFT) amount:SetWide(62) amount:SetMin(1) amount:SetMax(999) amount:SetValue(1) amount:SetDecimals(0) f.amount=amount
    local give=vgui.Create("DButton",actions) give:Dock(LEFT) give:SetWide(172) give:DockMargin(8,0,0,0) give:SetText("Give selected item") C.Button(give,true) f.give=give
    give.DoClick=function()
        local item=f.selected
        if not item or f.selectedSide~="player" or item.transferable==false or not IsValid(npc) then return end
        net.Start("GModAlive_Deposit") net.WriteEntity(npc) net.WriteUInt(f.creation,32) net.WriteString(item.id) net.WriteUInt(math.Clamp(math.floor(amount:GetValue()),1,999),16) net.SendToServer()
    end
    local ask=vgui.Create("DButton",actions) ask:Dock(LEFT) ask:SetWide(133) ask:DockMargin(8,0,0,0) ask:SetText("Ask for item") C.Button(ask,false) f.ask=ask
    ask.DoClick=function()
        local item=f.selected if not item or f.selectedSide~="npc" or not IsValid(npc) then return end
        f:Close() GA.OpenTalkDialog(npc,"Could you give me your "..item.name.." ("..item.class..")?")
    end
    local collect=vgui.Create("DButton",actions) collect:Dock(RIGHT) collect:SetWide(166) collect:SetText("Store looked-at item") C.Button(collect,false)
    collect.DoClick=function() net.Start("GModAlive_StoreGround") net.SendToServer() end
    local release=vgui.Create("DButton",footer) release:Dock(TOP) release:DockMargin(0,6,0,0) release:SetTall(30) release:SetText("Place selected collected item on the ground") C.Button(release,false)
    release.DoClick=function()
        if not f.selected or f.selectedSide~="player" or not f.selected.id:match("^stash:") then return end
        net.Start("GModAlive_Withdraw") net.WriteString(f.selected.id) net.SendToServer()
    end
    local note=vgui.Create("DLabel",footer) note:Dock(BOTTOM) note:SetTall(30) note:SetFont("GA.RPG.Small") note:SetWrap(true) note:SetTextColor(C.muted)
    note:SetText("Drag catalogue → your slots; your items → NPC slots. Quantity uses the amount field. Stored objects last for this session.")
    local cataloguePanel=vgui.Create("DPanel",f) cataloguePanel:Dock(RIGHT) cataloguePanel:SetWide(274) cataloguePanel:DockMargin(16,0,0,0) cataloguePanel:SetVisible(false) f.cataloguePanel=cataloguePanel
    local scroll=vgui.Create("DScrollPanel",f) scroll:Dock(FILL) f.scroll=scroll
    local canvas=scroll:GetCanvas()
    f.playerGrid,f.playerHeader=gridSection(canvas,"Your inventory")
    f.npcGrid,f.npcHeader=gridSection(canvas,"NPC inventory")
    f.npcGrid:SetVisible(IsValid(npc)) f.npcHeader:SetVisible(IsValid(npc))
    local function createDrop(_,panels,dropped)
        if not dropped or not panels or not IsValid(panels[1]) then return end
        if GA.CreateCatalogueEntry then GA.CreateCatalogueEntry(panels[1].GACatalogueItem) end
    end
    local function giveDrop(_,panels,dropped)
        if not dropped or not panels or not IsValid(panels[1]) or not IsValid(npc) then return end
        local source=panels[1] local item=source.GAInventoryItem
        if source.GAInventoryOwner~=f or not item or item.transferable==false then return end
        net.Start("GModAlive_Deposit") net.WriteEntity(npc) net.WriteUInt(f.creation,32) net.WriteString(item.id)
        net.WriteUInt(math.Clamp(math.floor(f.amount:GetValue()),1,item.kind=="ammo" and math.min(item.count,999) or 1),16) net.SendToServer()
    end
    f.playerGrid:Receiver("GModAlive_Catalogue",createDrop) f.playerHeader:Receiver("GModAlive_Catalogue",createDrop)
    f.npcGrid:Receiver("GModAlive_PlayerItem",giveDrop) f.npcHeader:Receiver("GModAlive_PlayerItem",giveDrop)
    local nextRefresh=RealTime()+2 local nextFocus=RealTime()+4 local nativeThink=f.Think
    if IsValid(npc) then closeFocus(npc,f.creation,true) end
    f.Think=function(self)
        if nativeThink then nativeThink(self) end
        local ply=LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then f:Close() return end
        if f.creation~=0 and (not IsValid(npc) or npc:GetCreationID()~=f.creation or ply:GetPos():DistToSqr(npc:GetPos())>GA.GetMaxDistance()^2) then f:Close() return end
        if dragndrop.IsDragging() then nextRefresh=RealTime()+0.3
        elseif RealTime()>nextRefresh then nextRefresh=RealTime()+2 request(npc) end
        if RealTime()>nextFocus then nextFocus=RealTime()+4 closeFocus(npc,f.creation,true) end
        give:SetEnabled(IsValid(npc) and f.selectedSide=="player" and f.selected and f.selected.transferable~=false or false)
        ask:SetEnabled(IsValid(npc) and f.selectedSide=="npc")
        release:SetEnabled(f.selectedSide=="player" and f.selected and f.selected.id:match("^stash:")~=nil or false)
    end
    f.OnRemove=function() closeFocus(npc,f.creation,false) end
    request(npc)
end
function GA.OpenNPCInventory(npc)
    if not IsValid(npc) then npc=GA.FindTargetNPC(LocalPlayer(),GA.GetMaxDistance()) end
    if not IsValid(npc) then GA.AddHUDToast("No NPC nearby",true) return end
    openBag(npc)
end
function GA.OpenPlayerInventory() openBag(NULL) end
local function fill(f,grid,items,side)
    grid:Clear()
    local columns=math.max(3,math.floor(math.max(grid:GetWide(),f:GetWide()-(f.cataloguePanel:IsVisible() and 340 or 65))/82))
    local minSlots=side=="player" and columns*4 or columns*2
    for index=1,math.max(minSlots,#items) do
        local item=items[index] local slot=grid:Add("DButton") slot:SetSize(76,76) slot:SetText("")
        slot.Paint=function(self,w,h)
            local active=item and f.selectedKey==side..":"..item.id
            surface.SetDrawColor(self:IsHovered() and C.input or C.surface) surface.DrawRect(0,0,w,h)
            surface.SetDrawColor(active and C.accent or C.line) surface.DrawOutlinedRect(0,0,w,h,active and 2 or 1)
            surface.SetDrawColor(Color(255,249,225,65)) surface.DrawLine(2,2,w-3,2)
            if item then
                if item.equipped then surface.SetDrawColor(92,145,65) surface.DrawRect(4,h-6,w-8,3) end
                draw.SimpleText(item.count.."x","GA.RPG.Small",w-5,h-9,C.text,TEXT_ALIGN_RIGHT,TEXT_ALIGN_BOTTOM)
            end
        end
        if item then
            if side=="player" and item.transferable~=false then
                slot.GAInventoryItem=item slot.GAInventoryOwner=f slot:Droppable("GModAlive_PlayerItem")
            end
            if item.model and item.model:lower():sub(-4)==".mdl" and file.Exists(item.model,"GAME") then
                local icon=vgui.Create("SpawnIcon",slot) icon:SetPos(7,4) icon:SetSize(62,59) icon:SetModel(item.model) icon:SetMouseInputEnabled(false)
            else
                local icon=vgui.Create("DImage",slot) icon:SetPos(19,12) icon:SetSize(38,38) icon:SetImage("icon16/package.png") icon:SetMouseInputEnabled(false)
            end
            slot:SetTooltip(item.name.."\n"..item.class..(item.transferable==false and "\nEssential tool — cannot be given away" or ""))
            slot.DoClick=function()
                f.selected=item f.selectedSide=side f.selectedKey=side..":"..item.id
                f.selectionLabel:SetText(item.name.."  ·  "..item.count.."  ·  "..(item.equipped and "Equipped" or "Stored")..(side=="player" and "  —  Your inventory" or "  —  NPC inventory"))
                f.amount:SetMax(item.kind=="ammo" and math.min(item.count,999) or item.count) f.amount:SetValue(1)
            end
            if f.selectedKey==side..":"..item.id then f.selected=item end
        else slot:SetEnabled(false) end
    end
    grid:InvalidateLayout(true)
end
net.Receive("GModAlive_Bag",function()
    local npc=net.ReadEntity() local creation=net.ReadUInt(32) local raw=net.ReadString() local f=GA.InventoryWindow
    if not IsValid(f) or f.npc~=npc or f.creation~=creation or #raw>60000 then return end
    if dragndrop.IsDragging() then return end
    if f.lastSnapshot==raw then return end
    local data=util.JSONToTable(raw) if not istable(data) or not istable(data.player) or not istable(data.npc) then return end
    f.lastSnapshot=raw f.selected=nil
    f.playerHeader:SetText((LocalPlayer():Nick() or "Player").." — Personal  ·  "..#data.player.." item types")
    f.npcHeader:SetText((data.name~="" and data.name or "NPC").."  ·  "..#data.npc.." item types")
    fill(f,f.playerGrid,data.player,"player") fill(f,f.npcGrid,data.npc,"npc")
    if not f.selected then f.selectedKey=nil f.selectionLabel:SetText("Select an item to inspect or transfer.")
    else
        f.selectionLabel:SetText(f.selected.name.."  ·  "..f.selected.count.."  ·  "..(f.selected.equipped and "Equipped" or "Stored"))
        f.amount:SetMax(math.min(f.selected.count,999))
    end
    f.scroll:GetCanvas():InvalidateLayout(true)
end)
net.Receive("GModAlive_OfferInventory",function()
    local npc=net.ReadEntity() local creation=net.ReadUInt(32)
    GA.PendingVoiceReply=nil
    if IsValid(npc) and npc:GetCreationID()==creation then GA.OpenNPCInventory(npc) end
end)
concommand.Add("gmod_alive_inventory",GA.OpenNPCInventory)
concommand.Add("gmod_alive_player_inventory",GA.OpenPlayerInventory)
