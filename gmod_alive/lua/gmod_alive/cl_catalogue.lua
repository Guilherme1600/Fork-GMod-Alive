if SERVER then return end
local GA=GModAlive local C=GA.UI
local function fetch(query)
    net.Start("GModAlive_Catalogue") net.WriteString(utf8.sub(query or "",1,100)) net.SendToServer()
end
function GA.CreateCatalogueEntry(item)
    local f=GA.InventoryWindow if not IsValid(f) or not item then return end
    net.Start("GModAlive_CreateBagItem") net.WriteString(item.id)
    net.WriteUInt(math.Clamp(math.floor(f.amount:GetValue()),1,item.kind=="ammo" and 999 or 5),16)
    net.WriteEntity(f.npc) net.WriteUInt(f.creation,32) net.SendToServer()
end
function GA.BuildCatalogue(parent,f)
    parent:DockPadding(10,10,10,10)
    parent.Paint=function(_,w,h) surface.SetDrawColor(C.surface) surface.DrawRect(0,0,w,h) surface.SetDrawColor(C.line) surface.DrawOutlinedRect(0,0,w,h,1) end
    local title=vgui.Create("DLabel",parent) title:Dock(TOP) title:SetTall(25) title:SetText("Add items") title:SetTextColor(C.text) title:SetFont("GA.RPG.Body")
    local search=vgui.Create("DTextEntry",parent) search:Dock(TOP) search:SetTall(32) search:DockMargin(0,6,0,8) search:SetPlaceholderText("Search weapons, items or ammo…") C.Entry(search) f.catalogueSearch=search
    search:SetMaximumCharCount(100)
    local token=0
    search.OnChange=function()
        token=token+1 local current=token
        timer.Simple(0.3,function() if IsValid(search) and current==token then fetch(search:GetValue()) end end)
    end
    local preview=vgui.Create("DModelPanel",parent) preview:Dock(TOP) preview:SetTall(125) preview:SetMouseInputEnabled(false) preview.LayoutEntity=function() end f.cataloguePreview=preview
    local detail=vgui.Create("DLabel",parent) detail:Dock(TOP) detail:SetTall(37) detail:SetWrap(true) detail:SetTextColor(C.text) detail:SetFont("GA.RPG.Small") detail:SetText("Select or hover over an item to preview it.") f.catalogueDetail=detail
    local add=vgui.Create("DButton",parent) add:Dock(TOP) add:SetTall(33) add:DockMargin(0,4,0,8) add:SetText("Add selected item") C.Button(add,true)
    add.DoClick=function() GA.CreateCatalogueEntry(f.catalogueSelected) end
    local status=vgui.Create("DLabel",parent) status:Dock(TOP) status:SetTall(39) status:SetWrap(true) status:SetFont("GA.RPG.Small") status:SetTextColor(C.muted)
    status:SetText("Drag a catalogue item onto your inventory. Single-player / admins only.") f.catalogueStatus=status
    local list=vgui.Create("DScrollPanel",parent) list:Dock(FILL) f.catalogueList=list
    fetch("")
end
net.Receive("GModAlive_Catalogue",function()
    local permitted=net.ReadBool() local total=net.ReadUInt(16) local raw=net.ReadString()
    local f=GA.InventoryWindow
    if not IsValid(f) or not IsValid(f.catalogueList) or #raw>60000 then return end
    local rows=util.JSONToTable(raw) if not istable(rows) then return end
    f.catalogueList:Clear() f.catalogueSelected=nil
    if not permitted then f.catalogueStatus:SetText("Creating items is restricted to single-player and server administrators.") return end
    f.catalogueStatus:SetText(#rows.." / "..total.." results. Drag onto your inventory. Use search for more items.")
    for _,item in ipairs(rows) do
        local button=vgui.Create("DButton",f.catalogueList) button:Dock(TOP) button:SetTall(49) button:DockMargin(0,0,0,4) button:SetText("")
        button.GACatalogueItem=item button:Droppable("GModAlive_Catalogue")
        button.Paint=function(self,w,h)
            surface.SetDrawColor(self:IsHovered() and C.input or C.bg) surface.DrawRect(0,0,w,h)
            surface.SetDrawColor(C.line) surface.DrawOutlinedRect(0,0,w,h,1)
        end
        if item.model and item.model:lower():sub(-4)==".mdl" and file.Exists(item.model,"GAME") then
            local icon=vgui.Create("SpawnIcon",button) icon:SetPos(3,3) icon:SetSize(42,42) icon:SetModel(item.model) icon:SetMouseInputEnabled(false)
        end
        local label=vgui.Create("DLabel",button) label:SetPos(50,4) label:SetSize(180,40) label:SetWrap(true) label:SetFont("GA.RPG.Small") label:SetTextColor(C.text) label:SetText(item.name) label:SetMouseInputEnabled(false)
        button:SetTooltip(item.name.."\n"..item.class.."\nDrag to your inventory")
        local function select()
            f.catalogueSelected=item f.catalogueDetail:SetText(item.name.."\n"..item.class)
            local p=f.cataloguePreview
            local valid=item.model and item.model:lower():sub(-4)==".mdl" and file.Exists(item.model,"GAME")
            p:SetVisible(valid)
            if valid then
                p:SetModel(item.model) local ent=p:GetEntity()
                if IsValid(ent) then local low,high=ent:GetRenderBounds() local center=(low+high)*0.5 local radius=math.max((high-low):Length()*0.5,8)
                    p:SetFOV(40) p:SetLookAt(center) p:SetCamPos(center+Vector(radius*1.9,radius*1.4,radius*0.7)) p:SetAmbientLight(Color(235,226,205))
                end
            end
        end
        button.DoClick=select button.OnCursorEntered=select
    end
end)
