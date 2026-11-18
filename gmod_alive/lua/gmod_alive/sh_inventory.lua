local GA=GModAlive
function GA.ItemLabel(class,model,entity)
    if IsValid(entity) and entity.GetPrintName then
        local ok,name=pcall(entity.GetPrintName,entity)
        if ok and isstring(name) and name~="" and name~=class and name:sub(1,1)~="#" then return name end
    end
    local names={weapon_pistol="Pistol",weapon_smg1="SMG",weapon_shotgun="Shotgun",weapon_ar2="Pulse rifle",
        weapon_357=".357 Magnum",weapon_crossbow="Crossbow",weapon_crowbar="Crowbar",weapon_stunstick="Stun stick",
        weapon_alyxgun="Alyx's gun",item_healthkit="Health kit",item_healthvial="Health vial",item_battery="Suit battery"}
    if names[class] then return names[class] end
    local stored=weapons.GetStored(class)
    if stored and isstring(stored.PrintName) and stored.PrintName~="" then return stored.PrintName end
    local label=(class:sub(1,5)=="prop_" or class:sub(1,5)=="prop:") and string.GetFileFromFilename(model or "") or class
    return (label:gsub("%.mdl$",""):gsub("_"," "))
end
function GA.HeldObjectInfo(npc)
    local result={} if not IsValid(npc) then return result end
    local held
    if npc.GetActiveWeapon then local ok,weapon=pcall(npc.GetActiveWeapon,npc) if ok then held=weapon end end
    if IsValid(held) then
        result[#result+1]={class=held:GetClass(),name=GA.ItemLabel(held:GetClass(),held:GetModel(),held),model=held:GetModel(),kind="weapon",equipped=true}
    end
    local hands={}
    for _,name in ipairs({"ValveBiped.Bip01_R_Hand","ValveBiped.Bip01_L_Hand"}) do
        local bone=npc:LookupBone(name) local pos=bone and npc:GetBonePosition(bone)
        if pos then hands[#hands+1]=pos end
    end
    local right=npc:LookupAttachment("anim_attachment_RH") local left=npc:LookupAttachment("anim_attachment_LH")
    for _,child in ipairs(npc:GetChildren()) do
        if #result>=4 then break end
        if IsValid(child) and child~=held and (child:IsWeapon() or child:GetClass():find("prop",1,true)) then
            local attachment=child:GetParentAttachment()
            local inHand=attachment>0 and (attachment==right or attachment==left)
            for _,pos in ipairs(hands) do if child:GetPos():DistToSqr(pos)<18^2 then inHand=true end end
            if inHand then result[#result+1]={class=child:GetClass(),name=GA.ItemLabel(child:GetClass(),child:GetModel(),child),model=child:GetModel(),kind=child:IsWeapon() and "weapon" or "prop",equipped=true,attached=true} end
        end
    end
    return result
end
CreateConVar("gmod_alive_armed_chance","80",{FCVAR_ARCHIVE,FCVAR_REPLICATED},"Chance (%) to arm an eligible unarmed humanoid NPC",0,100)

function GA.ItemPreviewModel(class)
    local stored=weapons.GetStored(class)
    if stored and stored.WorldModel then return stored.WorldModel end
    local models={weapon_pistol="models/weapons/w_pistol.mdl",weapon_smg1="models/weapons/w_smg1.mdl",
        weapon_shotgun="models/weapons/w_shotgun.mdl",weapon_ar2="models/weapons/w_irifle.mdl",
        weapon_frag="models/weapons/w_grenade.mdl",weapon_rpg="models/weapons/w_rocket_launcher.mdl",
        weapon_357="models/weapons/w_357.mdl",weapon_crowbar="models/weapons/w_crowbar.mdl",
        weapon_stunstick="models/weapons/w_stunbaton.mdl",weapon_crossbow="models/weapons/w_crossbow.mdl",
        item_ammo_pistol="models/items/boxsrounds.mdl",item_ammo_smg1="models/items/boxmrounds.mdl",item_box_buckshot="models/items/boxbuckshot.mdl",item_ammo_357="models/items/357ammo.mdl",
        item_healthkit="models/items/healthkit.mdl",item_healthvial="models/healthvial.mdl",item_battery="models/items/battery.mdl"}
    return models[class] or ""
end
