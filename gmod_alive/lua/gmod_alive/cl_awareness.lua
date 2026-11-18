-- ============================================================================
-- GMod Alive (fork) - cl_awareness.lua : NPC name tags (white name + class).
-- ============================================================================
local GA = GModAlive

local CLASS_LABELS = {
	npc_citizen = "Citizen", npc_metropolice = "Combine Police", npc_combine_s = "Combine Soldier",
	npc_gman = "G-Man", npc_alyx = "Alyx Vance", npc_barney = "Barney", npc_kleiner = "Dr. Kleiner",
	npc_eli = "Dr. Eli Vance", npc_mossman = "Dr. Mossman", npc_breen = "Dr. Breen", npc_monk = "Father Grigori",
	npc_vortigaunt = "Vortigaunt", npc_zombie = "Zombie", npc_fastzombie = "Fast Zombie", npc_antlion = "Antlion"
}

surface.CreateFont("GA.NameTag", { font = "Roboto", size = 22, weight = 700, extended = true })
surface.CreateFont("GA.NameTagSub", { font = "Roboto", size = 16, weight = 500, extended = true })

local cvTags

hook.Add("HUDPaint", "GModAlive_NameTags", function()
	cvTags = cvTags or GetConVar("gmod_alive_nametags")
	if not cvTags or not cvTags:GetBool() then return end
	if not GA.IsValidTalkTarget then return end
	local lp = LocalPlayer()
	if not IsValid(lp) then return end
	local eye = lp:EyePos()
	for _, ent in ipairs(ents.FindInSphere(lp:GetPos(), 700)) do
		if ent:IsNPC() and GA.IsValidTalkTarget(ent) and not ent:IsDormant() then
			local name = ent:GetNWString("GModAlive_Name", "")
			if name == "" then
				local p = GA.InspectNPC(ent)
				name = p and p.name or ""
			end
			if name ~= "" then
				local top = ent:GetPos() + Vector(0, 0, (ent:OBBMaxs().z or 72) + 14)
				local tr = util.TraceLine({ start = eye, endpos = ent:WorldSpaceCenter(), filter = { lp, ent }, mask = MASK_OPAQUE })
				if not tr.Hit then
					local sp = top:ToScreen()
					if sp.visible then
						local d = eye:Distance(top)
						local alpha = math.Clamp(255 - (d - 450) * 1.2, 40, 255)
						local cls = CLASS_LABELS[ent:GetClass()] or string.gsub(ent:GetClass(), "^npc_", "")
						local id = ent:EntIndex()
						local busy = (GA.NpcSubtitles and GA.NpcSubtitles[id]) or (GA.NpcStatuses and GA.NpcStatuses[id] == "thinking")
						local y = busy and (sp.y + 22) or (sp.y - 18)
						local va = busy and TEXT_ALIGN_TOP or TEXT_ALIGN_BOTTOM
						draw.SimpleTextOutlined(name, "GA.NameTag", sp.x, y, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, va, 1, Color(0, 0, 0, alpha))
						draw.SimpleTextOutlined(cls, "GA.NameTagSub", sp.x, busy and (y + 24) or (sp.y - 18), Color(190, 200, 215, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, alpha))
					end
				end
			end
		end
	end
end)
