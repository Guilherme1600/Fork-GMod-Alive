if CLIENT then return end
local GA=GModAlive
for _,name in ipairs({"GModAlive_Bag","GModAlive_Deposit","GModAlive_StoreGround","GModAlive_OfferInventory","GModAlive_Withdraw"}) do util.AddNetworkString(name) end
local stashes=setmetatable({},{__mode="k"}) local cooldown=setmetatable({},{__mode="k"})
local readCooldown=setmetatable({},{__mode="k"})
local protected={gmod_tool=true,weapon_physgun=true,weapon_physcannon=true,gmod_camera=true,weapon_fists=true}
local groundItems={item_healthkit=true,item_healthvial=true,item_battery=true,item_ammo_pistol=true,item_ammo_smg1=true,item_box_buckshot=true,item_ammo_357=true}
local function stash(ply) stashes[ply]=stashes[ply] or {} return stashes[ply] end
local function canUse(ply,npc)
    if not GA.IsEnabled() or not IsValid(ply) or not ply:Alive() then return false end
    if not IsValid(npc) then return npc==NULL end
    return GA.IsValidTalkTarget(npc) and ply:GetPos():DistToSqr(npc:GetPos())<=GA.GetMaxDistance()^2
        and not util.TraceLine({start=ply:EyePos(),endpos=npc:WorldSpaceCenter(),filter={ply,npc}}).Hit
end
local function allow(ply)
    if (cooldown[ply] or -1)>CurTime() then return false end cooldown[ply]=CurTime()+0.2 return true
end
local function row(key,class,item)
    local model=item.model or GA.ItemPreviewModel(class)
    return {id=key,class=class,name=utf8.sub(item.name or GA.ItemLabel(class,model),1,100),kind=item.kind or "item",
        count=math.Clamp(item.count or 1,0,65535),model=utf8.sub(model or "",1,240),equipped=item.equipped==true,transferable=item.transferable~=false}
end
local function playerRows(ply)
    local rows={}
    for _,weapon in ipairs(ply:GetWeapons()) do
        if #rows>=60 then break end
        if IsValid(weapon) then
            local class=weapon:GetClass()
            rows[#rows+1]=row("weapon:"..weapon:EntIndex()..":"..weapon:GetCreationID(),class,
                {kind="weapon",name=GA.ItemLabel(class,weapon:GetModel(),weapon),model=weapon:GetModel(),equipped=weapon==ply:GetActiveWeapon(),transferable=not protected[class]})
        end
    end
    for id=0,255 do
        local count=ply:GetAmmoCount(id)
        if count>0 and #rows<80 then
            local name=game.GetAmmoName(id)
            rows[#rows+1]=row("ammo:"..id,"ammo:"..id,{name=(name or "Ammo").." ammunition",kind="ammo",count=count,model="models/items/boxsrounds.mdl"})
        end
    end
    for class,item in SortedPairs(stash(ply)) do if #rows<96 and item.count>0 then rows[#rows+1]=row("stash:"..class,class,item) end end
    table.sort(rows,function(a,b) if a.equipped~=b.equipped then return a.equipped end return a.name<b.name end)
    return rows
end
function GA.SendBagSnapshot(ply,npc)
    if not canUse(ply,npc) then return end
    local npcRows={} local name=""
    if IsValid(npc) then
        local profile=GA.InspectNPC(npc,ply) name=profile and profile.name or "NPC"
        for class,item in SortedPairs(GA.GetNPCInventoryInfo(npc)) do if item.count>0 then npcRows[#npcRows+1]=row(class,class,item) end end
    end
    local json=util.TableToJSON({player=playerRows(ply),npc=npcRows,name=name})
    if not json or #json>60000 then GA.SendNotice(ply,"Inventory is too large to display.",true) return end
    net.Start("GModAlive_Bag") net.WriteEntity(npc) net.WriteUInt(IsValid(npc) and npc:GetCreationID() or 0,32) net.WriteString(json) net.Send(ply)
end
net.Receive("GModAlive_Bag",function(_,ply)
    local npc=net.ReadEntity() local creation=net.ReadUInt(32)
    if IsValid(npc) and npc:GetCreationID()~=creation then return end
    if (readCooldown[ply] or -1)>CurTime() or not canUse(ply,npc) then return end readCooldown[ply]=CurTime()+0.3
    GA.SendBagSnapshot(ply,npc)
end)
local function room(inv,key,kind,amount)
    local entry=inv[key]
    if not entry and table.Count(inv)>=12 then return false end
    return (not entry or entry.kind==kind) and (entry and entry.count or 0)+amount<=(kind=="ammo" and 10000 or 5)
end
local function deposit(inv,key,item,amount,state)
    inv[key]=inv[key] or {count=0,kind=item.kind,model=item.model,name=item.name,ammoID=item.ammoID}
    local entry=inv[key] entry.count=entry.count+amount
    if state then entry.weaponStates=entry.weaponStates or {} entry.weaponStates[#entry.weaponStates+1]=state end
end
local function recordGift(npc,ply,class,amount)
    npc.GModAlive_RecentGift={from=ply.Nick and ply:Nick() or "Player",item=class,amount=amount,time=CurTime()}
end
function GA.DepositPlayerItem(ply,npc,id,amount)
    if not IsValid(npc) or not canUse(ply,npc) or not GA.RuleEnabled("inventory") then return false,"Move close to a living NPC with inventory enabled." end
    amount=math.Clamp(math.floor(tonumber(amount) or 1),1,999)
    local inv=GA.EnsureNPCInventory(npc)
    local index,creation=id:match("^weapon:(%d+):(%d+)$")
    if index then
        local weapon=Entity(tonumber(index))
        if not IsValid(weapon) or not weapon:IsWeapon() or weapon:GetOwner()~=ply or weapon:GetCreationID()~=tonumber(creation) then return false,"You no longer own that weapon." end
        local class=weapon:GetClass()
        if protected[class] then return false,"Keep your essential tools." end
        if not room(inv,class,"weapon",1) then return false,"The NPC has no space for that weapon." end
        local state={clip1=weapon:Clip1(),clip2=weapon:Clip2(),skin=weapon:GetSkin()}
        deposit(inv,class,{kind="weapon",model=weapon:GetModel(),name=GA.ItemLabel(class,weapon:GetModel(),weapon)},1,state)
        weapon:Remove()
        recordGift(npc,ply,class,1)
        return true
    end
    local ammo=id:match("^ammo:(%d+)$")
    if ammo then
        ammo=tonumber(ammo) if ammo>255 or not game.GetAmmoName(ammo) then return false,"Invalid ammunition." end
        amount=math.min(amount,ply:GetAmmoCount(ammo))
        if amount<1 or not room(inv,id,"ammo",amount) then return false,"No ammunition available, or NPC inventory is full." end
        local before=ply:GetAmmoCount(ammo) ply:RemoveAmmo(amount,ammo)
        local removed=before-ply:GetAmmoCount(ammo)
        if removed<1 then return false,"Ammunition transfer failed." end
        deposit(inv,id,{kind="ammo",ammoID=ammo,model="models/items/boxsrounds.mdl",name=game.GetAmmoName(ammo).." ammunition"},removed)
        recordGift(npc,ply,id,removed)
        return true
    end
    local key=id:match("^stash:(.+)$") local bag=stash(ply) local item=key and bag[key]
    if not item or item.count<1 then return false,"That item is not in your inventory." end
    amount=math.min(amount,item.count)
    if item.kind=="weapon" then amount=1 end
    if not room(inv,key,item.kind,amount) then return false,"The NPC inventory is full." end
    local state=item.weaponStates and table.remove(item.weaponStates,1)
    deposit(inv,key,item,amount,state)
    item.count=item.count-amount if item.count<=0 then bag[key]=nil end
    recordGift(npc,ply,key,amount)
    return true
end
net.Receive("GModAlive_Deposit",function(_,ply)
    local npc=net.ReadEntity() local creation=net.ReadUInt(32) local id=net.ReadString() local amount=net.ReadUInt(16)
    if not IsValid(npc) or npc:GetCreationID()~=creation or #id>200 or not allow(ply) then return end
    local ok,message=GA.DepositPlayerItem(ply,npc,id,amount)
    if not ok then GA.SendNotice(ply,message,true) end
    GA.SendBagSnapshot(ply,npc)
end)
net.Receive("GModAlive_StoreGround",function(_,ply)
    if not allow(ply) or not canUse(ply,NULL) then return end
    local ent=ply:GetEyeTrace().Entity
    if not IsValid(ent) or ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() or IsValid(ent:GetOwner()) or IsValid(ent:GetParent()) or ply:GetPos():DistToSqr(ent:GetPos())>150^2 then GA.SendNotice(ply,"Look at a loose item within reach.",true) return end
    if ent.CPPIGetOwner then local owner=ent:CPPIGetOwner() if IsValid(owner) and owner~=ply then GA.SendNotice(ply,"This object belongs to another player.",true) return end end
    local class=ent:GetClass() local kind=ent:IsWeapon() and "weapon" or class=="prop_physics" and "prop" or "item"
    if protected[class] then GA.SendNotice(ply,"Essential tools cannot be stored.",true) return end
    if kind=="item" and not groundItems[class] then GA.SendNotice(ply,"This entity cannot be stored.",true) return end
    if kind=="prop" then
        local physics=ent:GetPhysicsObject()
        if not IsValid(physics) or physics:GetMass()>80 or ent:IsPlayerHolding() or constraint.HasConstraints(ent) then GA.SendNotice(ply,"Only loose, small props can be stored.",true) return end
    end
    local key=kind=="prop" and "prop:"..util.CRC(ent:GetModel() or "") or class
    local bag=stash(ply)
    if not room(bag,key,kind,1) then GA.SendNotice(ply,"Your stored inventory is full.",true) return end
    local state=kind=="weapon" and {clip1=ent:Clip1(),clip2=ent:Clip2(),skin=ent:GetSkin()} or nil
    deposit(bag,key,{kind=kind,model=ent:GetModel(),name=GA.ItemLabel(class,ent:GetModel(),ent)},1,state)
    ent:Remove() GA.SendBagSnapshot(ply,NULL)
end)
net.Receive("GModAlive_Withdraw",function(_,ply)
    local id=net.ReadString()
    if #id>200 or not allow(ply) or not canUse(ply,NULL) then return end
    local key=id:match("^stash:(.+)$") local bag=stash(ply) local item=key and bag[key]
    if not item or item.count<1 then GA.SendNotice(ply,"Select one of your collected items first.",true) return end
    local entity=ents.Create(item.kind=="prop" and "prop_physics" or key)
    if not IsValid(entity) then GA.SendNotice(ply,"This item cannot be placed in the world.",true) return end
    if item.kind=="prop" then entity:SetModel(item.model) end
    entity:SetPos(ply:GetPos()+ply:GetForward()*45+Vector(0,0,25)) entity:Spawn()
    if not IsValid(entity) then GA.SendNotice(ply,"Could not place this item.",true) return end
    local state=item.weaponStates and table.remove(item.weaponStates,1)
    if state and entity:IsWeapon() then entity:SetClip1(state.clip1 or -1) entity:SetClip2(state.clip2 or -1) entity:SetSkin(state.skin or 0) end
    item.count=item.count-1 if item.count<=0 then bag[key]=nil end
    GA.SendBagSnapshot(ply,NULL)
end)
function GA.IsGiftOffer(text)
    local lower=text:gsub("[A-Z]",function(c) return string.char(c:byte()+32) end)
    for _,phrase in ipairs({"não vou","nao vou","não quero","nao quero","won't","not going to","don't want","no quiero","no te voy"}) do if lower:find(phrase,1,true) then return false end end
    for _,phrase in ipairs({"vou te dar","quero te dar","te entregar","lhe dar","dar para voce","dar pra voce","dar para você","dar pra você","te dar uma","te dar um","give you","giving you","offer you","take this","toma essa","toma isso","te voy a dar","quiero darte","te regalo","je vais te donner","ich gebe dir"}) do
        if lower:find(phrase,1,true) then return true end
    end
    return false
end
function GA.OfferInventory(ply,npc)
    if not IsValid(npc) or not canUse(ply,npc) then return end
    GA.PauseNPCForConversation(npc,ply,15)
    net.Start("GModAlive_OfferInventory") net.WriteEntity(npc) net.WriteUInt(npc:GetCreationID(),32) net.Send(ply)
end

util.AddNetworkString("GModAlive_Catalogue")
util.AddNetworkString("GModAlive_CreateBagItem")
local catalogueCooldown=setmetatable({},{__mode="k"})
function GA.CanCreateInventoryItems(ply)
    return IsValid(ply) and (game.SinglePlayer() or ply:IsAdmin())
end
local function catalogue()
    local entries={} local seen={}
    local function add(id,class,kind,name,model,ammoID)
        if seen[id] or #id>160 then return end seen[id]=true
        entries[#entries+1]={id=id,class=class,kind=kind,name=utf8.sub(name or GA.ItemLabel(class,model),1,100),model=utf8.sub(model or GA.ItemPreviewModel(class),1,240),ammoID=ammoID}
    end
    for _,class in ipairs({"weapon_pistol","weapon_smg1","weapon_shotgun","weapon_ar2","weapon_357","weapon_crossbow","weapon_crowbar","weapon_stunstick","weapon_frag","weapon_rpg"}) do
        add("weapon:"..class,class,"weapon",GA.ItemLabel(class),GA.ItemPreviewModel(class))
    end
    for _,weapon in ipairs(weapons.GetList()) do
        local class=weapon.ClassName
        if isstring(class) and class:match("^[%w_]+$") and weapon.Spawnable and not protected[class] then
            add("weapon:"..class,class,"weapon",weapon.PrintName or class,weapon.WorldModel or GA.ItemPreviewModel(class))
        end
    end
    for class in pairs(groundItems) do add("item:"..class,class,"item",GA.ItemLabel(class),GA.ItemPreviewModel(class)) end
    for id=0,255 do local name=game.GetAmmoName(id) if name and name~="" then
        add("ammo:"..id,"ammo:"..id,"ammo",name.." ammunition","models/items/boxsrounds.mdl",id)
    end end
    table.sort(entries,function(a,b) if a.kind~=b.kind then return a.kind<b.kind end return a.name<b.name end)
    return entries
end
local function fold(text) return text:gsub("[A-Z]",function(c) return string.char(c:byte()+32) end) end
net.Receive("GModAlive_Catalogue",function(_,ply)
    local query=net.ReadString()
    if #query>120 or not canUse(ply,NULL) then return end
    if (catalogueCooldown[ply] or -1)>CurTime() then return end catalogueCooldown[ply]=CurTime()+0.2
    local rows={} local total=0 local permitted=GA.CanCreateInventoryItems(ply)
    if permitted then
        query=fold(query)
        for _,item in ipairs(catalogue()) do
            if query=="" or fold(item.name.." "..item.class):find(query,1,true) then
                total=total+1 if #rows<180 then rows[#rows+1]=item end
            end
        end
    end
    local reply=util.TableToJSON(rows) or "[]"
    while #reply>50000 and #rows>0 do table.remove(rows) reply=util.TableToJSON(rows) end
    net.Start("GModAlive_Catalogue") net.WriteBool(permitted) net.WriteUInt(math.min(total,65535),16) net.WriteString(reply) net.Send(ply)
end)
function GA.CreateInventoryItem(ply,id,amount)
    if not canUse(ply,NULL) or not GA.CanCreateInventoryItems(ply) then return false,"Only single-player or server admins can create inventory items." end
    local found
    for _,entry in ipairs(catalogue()) do if entry.id==id then found=entry break end end
    if not found then return false,"That item is not in the server catalogue." end
    amount=math.Clamp(math.floor(tonumber(amount) or 1),1,found.kind=="ammo" and 999 or 5)
    if found.kind=="ammo" then
        local granted=ply:GiveAmmo(amount,found.ammoID,true)
        if not granted or granted<1 then return false,"You cannot carry more of this ammunition." end
        return true
    end
    local key=found.class local bag=stash(ply)
    if not room(bag,key,found.kind,amount) then return false,"No free space for this item or stack." end
    deposit(bag,key,found,amount)
    -- Created weapons start without ammunition; ammo can be added separately.
    if found.kind=="weapon" then
        bag[key].weaponStates=bag[key].weaponStates or {}
        for _=1,amount do bag[key].weaponStates[#bag[key].weaponStates+1]={clip1=0,clip2=0,skin=0} end
    end
    return true
end
net.Receive("GModAlive_CreateBagItem",function(_,ply)
    local id=net.ReadString() local amount=net.ReadUInt(16) local npc=net.ReadEntity() local creation=net.ReadUInt(32)
    if #id>160 or not allow(ply) then return end
    local ok,message=GA.CreateInventoryItem(ply,id,amount)
    if not ok then GA.SendNotice(ply,message,true) end
    if IsValid(npc) and npc:GetCreationID()==creation and canUse(ply,npc) then GA.SendBagSnapshot(ply,npc)
    else GA.SendBagSnapshot(ply,NULL) end
end)
