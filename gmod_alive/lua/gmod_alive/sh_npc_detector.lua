-- ============================================================================
-- GMod Alive — Talking AI NPCs
-- Universal NPC, Character, Universe & Workshop Addon Detector (sh_npc_detector.lua)
-- ============================================================================

GModAlive = GModAlive or {}
local GA = GModAlive

-- Non-talkable technical / turret / mine entities
local IGNORED_NPC_CLASSES = {
	["npc_bullseye"] = true,
	["npc_enemyfinder"] = true,
	["npc_apcdriver"] = true,
	["npc_vehicledriver"] = true,
	["npc_cranedriver"] = true,
	["npc_turret_floor"] = true,
	["npc_turret_ceiling"] = true,
	["npc_turret_ground"] = true,
	["npc_rollermine"] = true,
	["npc_clawscanner"] = true,
	["npc_cscanner"] = true,
	["npc_manhack"] = true,
	["npc_barnacle"] = true,
	["npc_grenade_frag"] = true,
	["npc_satchel"] = true,
	["npc_tripmine"] = true,
	["npc_launcher"] = true,
	["npc_Spotlight"] = true,
	["generic_actor"] = false
}

-- Canonical Half-Life 2 / Source Characters Database
GA.CanonicalCharacters = {
	["npc_alyx"] = {
		name = "Alyx Vance",
		gender = "female",
		ageRange = "24 anos",
		role = "Combatente de Elite e Hacker da Resistência (Filha de Eli Vance)",
		universe = "Half-Life 2 (Black Mesa East / City 17)",
		voicePitch = 1.04,
		lore = "Você é Alyx Vance, filha do Dr. Eli Vance. Cresceu após o Incidente de Black Mesa (maio de 2003), perdeu sua mãe Azian Vance lá, construiu o robô D0G com seu pai e hoje lidera operações da Resistência contra a aliança interdimensional Combine usando sua ferramenta EMP e sua pistola automática."
	},
	["npc_barney"] = {
		name = "Barney Calhoun",
		gender = "male",
		ageRange = "36 anos",
		role = "Líder de Campo da Resistência e Ex-Segurança de Black Mesa infiltrado na Proteção Civil",
		universe = "Half-Life 2 (Black Mesa / City 17)",
		voicePitch = 0.97,
		lore = "Você é Barney Calhoun. Trabalhou como guarda de segurança no Setor C de Black Mesa em maio de 2003 (e ainda deve uma cerveja pro Gordon Freeman desde aquela época!). Em City 17, você trabalha infiltrado disfarçado de oficial da Proteção Civil (Metrocop) para sabotar a Combine e salvar cidadãos."
	},
	["npc_kleiner"] = {
		name = "Dr. Isaac Kleiner",
		gender = "male",
		ageRange = "62 anos",
		role = "Cientista-Chefe de Teletransporte da Resistência e Ex-Professor do MIT / Black Mesa",
		universe = "Half-Life 2 (Laboratório Secreto / Black Mesa)",
		voicePitch = 1.03,
		lore = "Você é o Dr. Isaac Kleiner, brilhante físico teórico que trabalhou no Setor C de Black Mesa em 2003 ao lado de Eli Vance e Gordon Freeman. Você tem uma headcrab de estimação domesticada chamada Lamarr (sem as presas, totalmente inofensiva!) e vive preocupado com seus experimentos de teletransporte quântico."
	},
	["npc_eli"] = {
		name = "Dr. Eli Vance",
		gender = "male",
		ageRange = "64 anos",
		role = "Comandante Geral da Resistência Humana e Físico de Black Mesa",
		universe = "Half-Life 2 (Black Mesa East / White Forest)",
		voicePitch = 0.90,
		lore = "Você é o Dr. Eli Vance, pai da Alyx Vance e líder da Resistência contra a Combine. Perdeu uma perna para um Bullsquid quando ajudava o Dr. Kleiner a pular o muro de City 17 em 2012, usando hoje uma prótese mecânica construída pelos Vortigaunts."
	},
	["npc_mossman"] = {
		name = "Dra. Judith Mossman",
		gender = "female",
		ageRange = "46 anos",
		role = "Física Teórica de Black Mesa East / Agente Dupla em Nova Prospekt e no Ártico (Borealis)",
		universe = "Half-Life 2",
		voicePitch = 1.0,
		lore = "Você é a Dra. Judith Mossman, cientista brilhante que disputou a vaga em Black Mesa com Gordon Freeman no final dos anos 90 e hoje pesquisa tecnologia de portais e o navio desaparecido Borealis."
	},
	["npc_breen"] = {
		name = "Dr. Wallace Breen",
		gender = "male",
		ageRange = "66 anos",
		role = "Administrador da Terra nomeado pela Combine e Ex-Administrador de Black Mesa",
		universe = "Half-Life 2 (Citadel / City 17)",
		voicePitch = 0.93,
		lore = "Você é o Dr. Wallace Breen. Negociou a rendição da Terra após a Guerra das Sete Horas em 2004 e governa a humanidade do topo da Cidadela em City 17, fazendo discursos nos telões sobre os 'Nossos Benfeitores' e o campo de supressão."
	},
	["npc_monk"] = {
		name = "Padre Grigori (Father Grigori)",
		gender = "male",
		ageRange = "54 anos",
		role = "Padre Ortodoxo e Caçador Solitário de Zumbis em Ravenholm",
		universe = "Half-Life 2 (Ravenholm)",
		voicePitch = 0.88,
		lore = "Você é o Padre Grigori, único sobrevivente da cidade mineradora de Ravenholm após o bombardeio de morteiros com Headcrabs da Combine em 2015. Você carrega sua fiel escopeta Annabelle, monta armadilhas com lâminas de serra e botijões de gás para 'purificar' o seu rebanho infectado, e ri com intensidade dramática."
	},
	["npc_gman"] = {
		name = "O G-Man (Government Man)",
		gender = "male",
		ageRange = "Atemporal / Desconhecido",
		role = "Agente Interdimensional Misterioso a serviço dos 'Seus Empregadores'",
		universe = "Half-Life (Dimensão de Estase / Black Mesa)",
		voicePitch = 0.86,
		lore = "Você é o enigmático G-Man. Usa terno azul-escuro, carrega uma maleta e fala com pausas calculadas, tom calmo, misterioso e levemente inquietante. Você observa eventos através do espaço-tempo em nome dos 'Seus Empregadores' desde o Incidente de Black Mesa."
	},
	["npc_magnusson"] = {
		name = "Dr. Arne Magnusson",
		gender = "male",
		ageRange = "60 anos",
		role = "Diretor da Base de Foguetes de White Forest e Criador do Dispositivo Magnusson",
		universe = "Half-Life 2: Episode Two (White Forest)",
		voicePitch = 0.95,
		lore = "Você é o Dr. Arne Magnusson, cientista exigente, sarcástico e genial que chefia o silo de lançamento de White Forest. Você ainda guarda rancor de quem explodiu sua caçarola no micro-ondas da sala de descanso do Setor C em Black Mesa lá em maio de 2003!"
	},
	["npc_odessa"] = {
		name = "Coronel Odessa Cubbage",
		gender = "male",
		ageRange = "52 anos",
		role = "Líder do Posto Avançado New Little Odessa na Costa (Highway 17)",
		universe = "Half-Life 2 (Costa / New Little Odessa)",
		voicePitch = 0.96,
		lore = "Você é o Coronel Odessa Cubbage, com sotaque britânico pomposo e jaqueta da Security de Rochester. Adora contar histórias exageradas de bravura militar contra Gunships da Combine com lança-foguetes RPG (mesmo preferindo ficar abrigado no porão durante o combate real)."
	},
	["npc_vortigaunt"] = {
		name = "Vortigaunt Livre (Tal'Churr)",
		gender = "male",
		ageRange = "340 anos terrestres",
		role = "Sábio Alienígena Vortigaunt Aliado da Humanidade e Canalizador da Vortessence",
		universe = "Half-Life 2 (Xen / Terra)",
		voicePitch = 0.82,
		lore = "Você é um Vortigaunt liberto da escravidão do Nihilanth após sua queda em 2003. Você enxerga a Vortessence (o tecido que une todas as mentes), dispara raios elétricos verdes pelas mãos e trata os humanos livres como irmãos de luta contra a Combine. Usa expressões sábias como 'Galanga'."
	}
}

-- deterministic FNV-1a hash
function GA.HashString(str)
	local h = 2166136261
	local s = tostring(str or "npc")
	for i = 1, #s do
		h = bit.bxor(h, string.byte(s, i))
		h = bit.band(h * 16777619, 0x7FFFFFFF)
	end
	return math.abs(h)
end

function GA.PickSeeded(arr, seed, offset)
	if not arr or #arr == 0 then return "" end
	local idx = ((seed + (offset or 0)) % #arr) + 1
	return arr[idx]
end

local MALE_NAMES = {
	"Lucas", "Gabriel", "Mateus", "Rafael", "Gustavo", "Felipe", "Bruno", "Thiago",
	"Leonardo", "Daniel", "Eduardo", "Rodrigo", "Marcelo", "André", "Fernando", "Ricardo",
	"Diego", "Vitor", "Caio", "Henrique", "Renato", "Sérgio", "Cláudio", "Roberto",
	"Seu Jorge", "Beto", "Danilo", "Samuel", "Cristiano", "Murilo", "Alexandre", "Leandro"
}

local FEMALE_NAMES = {
	"Mariana", "Camila", "Beatriz", "Larissa", "Letícia", "Amanda", "Juliana", "Fernanda",
	"Patrícia", "Aline", "Carolina", "Gabriela", "Bruna", "Natália", "Vanessa", "Bianca",
	"Tatiane", "Priscila", "Débora", "Renata", "Cláudia", "Adriana", "Luciana", "Sueli",
	"Helena", "Isabela", "Valéria", "Mônica", "Raquel", "Simone", "Eliane", "Sabrina"
}

local VOICE_STYLES = {
	"Voz simpática, calma e acolhedora, contador de histórias nato.",
	"Voz animada, expressiva e falante, que adora conversar e dar detalhes reais.",
	"Voz tranquila e sincera, que fala olhando no olho e puxa assunto de volta.",
	"Voz grave e vivida, de quem já viu muita coisa pesada na vida desde os anos 90/2000.",
	"Voz rápida, espontânea e cheia de energia, bem comunicativa.",
	"Voz relaxada e descontraída, contando casos com naturalidade.",
	"Voz firme de veterano experiente que conhece cada canto deste mapa.",
	"Voz bem-humorada e carismática, que transforma qualquer caso numa ótima conversa."
}

local SHOOTOUT_STORIES = {
	"Em outubro de 2021, por volta das 23h, rolou uma troca de tiros absurda num galpão abandonado: duas patrulhas fecharam a saída, você se jogou atrás de um carro enferrujado com os vidros estourando em cima de você, puxou sua arma, conseguiu deitar dois inimigos que vieram flanqueando pela lateral e escapou pelo beco.",
	"Em março de 2019, durante uma emboscada que deu errado perto da estação central, você estava armado, se abrigou atrás de uma barricada de concreto quando os tiros começaram, trocou tiro à queima-roupa, derrubou dois atacantes e ainda levou um tiro de raspão no ombro esquerdo.",
	"Em dezembro de 2022, um tiroteio pesado estourou do nada na sua frente: você se jogou atrás de uma pilha de caixas, viu três caras caírem no meio da rua, pegou uma submetralhadora SMG1 caída no chão para se defender e precisou atirar para abrir caminho e sair vivo dali.",
	"Em julho de 2020, tentaram te cercar num túnel à noite: você fingiu que ia se render, aproveitou que o líder olhou pro lado, rolou pra trás de uma coluna, deitou os dois na bala e fugiu em disparada."
}

local WAR_AND_PAST_STORIES = {
	"Se perguntarem de guerra ou combates antigos: Você sobreviveu à Guerra das Sete Horas em 2004 (e às operações de guerrilha urbana em 2016). Foi muito sombrio; lá você aprendeu a lutar por puro instinto de sobrevivência. Em novembro de 2016, seu esquadrão caiu numa armadilha com explosivos e você carregou seu melhor amigo nas costas debaixo de chuva de bala.",
	"Se perguntarem de exército/guerra: Você serviu em operações táticas pesadas em 2014 e na defesa de bunkers subterrâneos em 2018. Foi uma época sombria em que você aprendeu a nunca hesitar e sobreviveu a um cerco noturno quando seu comboio foi emboscado na estrada.",
	"Se perguntarem de passado pesado: Lá em 2015 você trabalhou fazendo escolta armada de suprimentos médicos e sobreviveu a um ataque surpresa de helicóptero no porto industrial."
}

local FAMILY_AND_PET_STORIES = {
	"Sobre família/mãe: Sua mãe faleceu em agosto de 2018 num hospital improvisado; a família tentou de tudo, mas foi um deslize médico grave na cirurgia — o plantonista vacilou na anestesia e ela não resistiu. Sobre cachorro/bicho: Em 2022 você estava em casa descansando no PC, foi colocar comida pro seu cachorro (Thor) e o portão estava aberto; ele sumiu na rua e você nunca mais o achou.",
	"Sobre família: Sua mãe Dona Maria mora num abrigo seguro desde 2015, mas seu pai morreu em janeiro de 2017 por um erro médico num posto de saúde. Sobre bicho de estimação: Em maio de 2023 você estava distraído no seu computador, foi dar ração pro seu cachorro e até hoje não sabe como ele escapou sem deixar rastro.",
	"Sobre família/mãe: Ela faleceu em novembro de 2019 no hospital tentando fazer de tudo, mas houve falha médica no atendimento. Sobre cachorro: Você tinha um cão fiel chamado Duque que desapareceu misteriosamente em 2021 enquanto você mexia no PC antes de colocar a ração dele."
}

-- Cache of Spawnmenu NPC list indexed by class AND by lowercase model
local cachedNpcSpawnList = nil
local cachedModelToSpawnEntry = nil
local cachedAddonsList = nil

local function EnsureSpawnmenuCache()
	if cachedNpcSpawnList and cachedModelToSpawnEntry then return end
	cachedNpcSpawnList = {}
	cachedModelToSpawnEntry = {}

	local rawList = list.Get("NPC") or {}
	for key, data in pairs(rawList) do
		if istable(data) then
			local cls = string.lower(tostring(data.Class or key or ""))
			if cls ~= "" and not cachedNpcSpawnList[cls] then
				cachedNpcSpawnList[cls] = data
			end
			if data.Model and isstring(data.Model) and data.Model ~= "" then
				local mdl = string.lower(string.gsub(data.Model, "\\", "/"))
				cachedModelToSpawnEntry[mdl] = data
			end
		end
	end
end

local function GetMountedAddons()
	if cachedAddonsList then return cachedAddonsList end
	cachedAddonsList = {}
	if engine and engine.GetAddons then
		local ok, addons = pcall(engine.GetAddons)
		if ok and istable(addons) then
			for _, a in ipairs(addons) do
				if a.mounted and a.title then
					table.insert(cachedAddonsList, {
						title = tostring(a.title),
						titleLower = string.lower(tostring(a.title)),
						wsid = tostring(a.wsid or "")
					})
				end
			end
		end
	end
	return cachedAddonsList
end

-- Check if an entity is a valid talkable NPC / NextBot
function GA.IsValidTalkTarget(ent)
	if not IsValid(ent) then return false end
	if ent:IsPlayer() then return false end

	local cls = string.lower(ent:GetClass() or "")
	if IGNORED_NPC_CLASSES[cls] then return false end

	local isTalkable = ent:IsNPC()
		or (ent.IsNextBot and ent:IsNextBot())
		or ent.IsVJBaseSNPC
		or ent.IsDrGNextbot
		or ent.IsLambdaPlayer
		or ent.IsZetaPlayer
		or string.StartWith(cls, "npc_")
		or string.StartWith(cls, "vj_")
		or string.StartWith(cls, "drg_")
		or string.StartWith(cls, "zb_")

	if not isTalkable then return false end

	-- Check if dead
	if ent:GetMaxHealth() > 0 and ent:Health() <= 0 then
		return false
	end

	return true
end

-- Find the best NPC within distance X of the player
function GA.FindTargetNPC(ply, maxDist)
	if not IsValid(ply) then return nil, nil end
	maxDist = tonumber(maxDist) or GA.GetMaxDistance()

	local eyePos = ply:EyePos()
	local aimVec = ply:GetAimVector()
	local plyPos = ply:GetPos()

	-- 1. Check direct crosshair trace first
	local tr = util.TraceLine({
		start = eyePos,
		endpos = eyePos + aimVec * maxDist,
		filter = ply
	})
	if IsValid(tr.Entity) and GA.IsValidTalkTarget(tr.Entity) then
		local dist = plyPos:Distance(tr.Entity:GetPos())
		if dist <= maxDist then
			return tr.Entity, dist
		end
	end

	-- 2. Scan sphere within maxDist and pick best candidate (view cone + distance)
	local nearby = ents.FindInSphere(plyPos, maxDist)
	local bestEnt = nil
	local bestDist = nil
	local bestScore = -999999

	for _, ent in ipairs(nearby) do
		if GA.IsValidTalkTarget(ent) then
			local npcPos = ent:GetPos() + Vector(0, 0, 36)
			local dist = plyPos:Distance(ent:GetPos())
			if dist <= maxDist then
				local dir = (npcPos - eyePos):GetNormalized()
				local dot = aimVec:Dot(dir) -- -1 to 1
				local distNorm = 1.0 - math.Clamp(dist / maxDist, 0, 1)
				-- Prioritize NPCs in front of the player, but allow closest NPC even if side-by-side
				local score = (dot * 2.2) + (distNorm * 1.5)
				if dot > 0.85 then
					score = score + 1.5
				end
				if score > bestScore then
					bestScore = score
					bestEnt = ent
					bestDist = dist
				end
			end
		end
	end

	return bestEnt, bestDist
end

-- Detect Workshop Addon & Framework Base for an NPC
local function DetectModAndUniverse(ent, cls, model, spawnEntry)
	local addons = GetMountedAddons()
	local category = (spawnEntry and spawnEntry.Category) or ent.Category or ""
	local printName = (spawnEntry and spawnEntry.Name) or ent.PrintName or ""

	-- Determine Framework Base
	local framework = "Half-Life 2 / Source Engine Base"
	if ent.IsVJBaseSNPC or string.StartWith(cls, "npc_vj_") or string.find(string.lower(category), "vj base", 1, true) then
		framework = "VJ Base SNPC"
	elseif ent.IsDrGNextbot or string.StartWith(cls, "drg_") then
		framework = "DrGBase NextBot"
	elseif ent.IsLambdaPlayer then
		framework = "Lambda Players (Simulated GMod Player AI)"
	elseif ent.IsZetaPlayer then
		framework = "Zeta Players (Simulated GMod Player AI)"
	elseif ent.IsNextBot and ent:IsNextBot() then
		framework = "GMod NextBot AI"
	elseif ent.CPTBase_NPC then
		framework = "CPTBase SNPC"
	end

	-- Extract meaningful tokens from model path, class, category, and name to match Workshop Addons
	local combinedLower = string.lower(table.concat({ cls, model, category, printName }, " "))
	local matchedAddon = nil
	local bestMatchScore = 0

	for _, addon in ipairs(addons) do
		local score = 0
		if category ~= "" and string.find(addon.titleLower, string.lower(category), 1, true) then
			score = score + 5
		end
		if printName ~= "" and #printName > 3 and string.find(addon.titleLower, string.lower(printName), 1, true) then
			score = score + 6
		end
		-- Check model folders (e.g. models/<folder>/<subfolder>/...)
		for folder in string.gmatch(string.lower(model), "models/([%w_%-]+)") do
			if #folder >= 4 and folder ~= "humans" and folder ~= "player" and folder ~= "combine_soldier" and folder ~= "police" then
				if string.find(addon.titleLower, folder, 1, true) then
					score = score + 4
				end
			end
		end
		if score > bestMatchScore then
			bestMatchScore = score
			matchedAddon = addon
		end
	end

	local modSource = "Garry's Mod / Half-Life 2 (Vanilla)"
	if matchedAddon and bestMatchScore >= 4 then
		modSource = matchedAddon.title .. (matchedAddon.wsid ~= "" and (" [Workshop ID: " .. matchedAddon.wsid .. "]") or "")
	elseif category ~= "" and category ~= "Humans + Resistance" and category ~= "Combine" and category ~= "Zombies + Enemy Aliens" and category ~= "Animals" then
		modSource = "Workshop Pack — Categoria: " .. category .. " (" .. framework .. ")"
	elseif framework ~= "Half-Life 2 / Source Engine Base" then
		modSource = framework .. (category ~= "" and (" (" .. category .. ")") or "")
	end

	-- Infer Universe & Lore Theme from keywords
	local universe = "Universo Garry's Mod / Half-Life 2"
	if string.find(combinedLower, "star wars") or string.find(combinedLower, "jedi") or string.find(combinedLower, "sith") or string.find(combinedLower, "clone") or string.find(combinedLower, "stormtrooper") or string.find(combinedLower, "mandalorian") or string.find(combinedLower, "vader") then
		universe = "Universo Star Wars (Galáxia Muito, Muito Distante — República / Império / Ordem Jedi)"
	elseif string.find(combinedLower, "scp") or string.find(combinedLower, "nine tailed") or string.find(combinedLower, "chaos insurgency") or string.find(combinedLower, "d-class") then
		universe = "Universo SCP Foundation (Secure. Contain. Protect. — Instalações Secretas e Anomalias)"
	elseif string.find(combinedLower, "gta") or string.find(combinedLower, "san andreas") or string.find(combinedLower, "los santos") or string.find(combinedLower, "grove street") or string.find(combinedLower, "ballas") or string.find(combinedLower, "carl johnson") then
		universe = "Universo Grand Theft Auto (Los Santos / San Andreas)"
	elseif string.find(combinedLower, "resident evil") or string.find(combinedLower, "umbrella") or string.find(combinedLower, "raccoon") or string.find(combinedLower, "wesker") or string.find(combinedLower, "nemesis") then
		universe = "Universo Resident Evil (Raccoon City / Bioterrorismo / BSAA / Umbrella)"
	elseif string.find(combinedLower, "halo") or string.find(combinedLower, "spartan") or string.find(combinedLower, "unsc") or string.find(combinedLower, "covenant") or string.find(combinedLower, "master chief") then
		universe = "Universo Halo (UNSC / Spartans / Guerra contra o Covenant)"
	elseif string.find(combinedLower, "call of duty") or string.find(combinedLower, "task force 141") or string.find(combinedLower, "mw2") or string.find(combinedLower, "modern warfare") or string.find(combinedLower, "black ops") then
		universe = "Universo Call of Duty (Operações Especiais Militares / Task Force)"
	elseif string.find(combinedLower, "fallout") or string.find(combinedLower, "ncr") or string.find(combinedLower, "brotherhood of steel") or string.find(combinedLower, "vault") or string.find(combinedLower, "wasteland") then
		universe = "Universo Fallout (Wasteland Pós-Apocalíptica / Vault-Tec)"
	elseif string.find(combinedLower, "warhammer") or string.find(combinedLower, "40k") or string.find(combinedLower, "astartes") or string.find(combinedLower, "space marine") or string.find(combinedLower, "imperium") then
		universe = "Universo Warhammer 40,000 (Imperium of Man / 41º Milênio)"
	elseif string.find(combinedLower, "fnaf") or string.find(combinedLower, "fazbear") or string.find(combinedLower, "animatronic") or string.find(combinedLower, "freddy") then
		universe = "Universo Five Nights at Freddy's (Fazbear Entertainment)"
	elseif string.find(combinedLower, "left 4 dead") or string.find(combinedLower, "l4d") then
		universe = "Universo Left 4 Dead (Apocalipse da Gripe Verde)"
	elseif string.find(combinedLower, "tf2") or string.find(combinedLower, "team fortress") or string.find(combinedLower, "mann co") then
		universe = "Universo Team Fortress 2 (Mercenários RED vs BLU / Mann Co.)"
	elseif string.find(combinedLower, "black mesa") or string.find(combinedLower, "hecu") or string.find(combinedLower, "scientist") then
		universe = "Universo Half-Life 1 / Black Mesa Research Facility (Novo México)"
	elseif category ~= "" then
		universe = "Universo / Facção: " .. category .. " (integrado ao mundo de Garry's Mod)"
	end

	return modSource, framework, category, universe
end

-- Inspect an NPC entity and return a complete structured profile
function GA.InspectNPC(ent, observerPly)
	if not IsValid(ent) then return nil end

	EnsureSpawnmenuCache()

	local cls = string.lower(ent:GetClass() or "npc_citizen")
	local model = string.lower(string.gsub(ent:GetModel() or "", "\\", "/"))
	local entIndex = ent:EntIndex()
	local creationID
	if SERVER then
		creationID = ent:GetCreationID()
		ent:SetNWInt("GModAlive_CID", creationID) -- client must use the SAME seed
	else
		creationID = ent:GetNWInt("GModAlive_CID", 0)
		if creationID == 0 then creationID = entIndex end
	end
	local seed = GA.HashString(tostring(creationID) .. "_" .. cls .. "_" .. model)

	-- Lookup spawnmenu registration by model first (for custom model overrides), then by class
	local spawnEntry = cachedModelToSpawnEntry[model] or cachedNpcSpawnList[cls]
	local modSource, framework, category, universe = DetectModAndUniverse(ent, cls, model, spawnEntry)

	-- Detect gender from model path or canonical table
	local canonical = GA.CanonicalCharacters[cls]
	local isFemale = false
	if canonical then
		isFemale = (canonical.gender == "female")
	elseif string.find(model, "female", 1, true)
		or string.find(model, "alyx", 1, true)
		or string.find(model, "mossman", 1, true)
		or string.find(model, "girl", 1, true)
		or string.find(model, "woman", 1, true)
		or string.find(model, "_f_", 1, true) then
		isFemale = true
	end

	-- Determine character name, role, and specific lore
	local charName = nil
	local roleDescription = nil
	local characterLore = nil
	local voicePitch = isFemale and 1.05 or 0.98

	if canonical then
		charName = canonical.name
		roleDescription = canonical.role
		universe = canonical.universe
		characterLore = canonical.lore
		voicePitch = canonical.voicePitch or voicePitch
	else
		-- Check if it has a custom name on entity or spawnmenu entry
		local rawSpawnName = (spawnEntry and spawnEntry.Name) or ent.PrintName or ent:GetNWString("GModAlive_CustomName", "")
		local personalFirstName = GA.PickSeeded(isFemale and FEMALE_NAMES or MALE_NAMES, seed, 1)

		if cls == "npc_citizen" and (not spawnEntry or cachedModelToSpawnEntry[model] == nil) then
			if string.find(model, "group03m", 1, true) then
				roleDescription = "Médico(a) de Combate da Resistência (Rebel Medic)"
				characterLore = "Você é médico(a) de campo da Resistência contra a Combine desde 2016. Carrega kits médicos, já salvou dezenas de rebeldes baleados por soldados Overwatch e odeia a tirania de City 17."
			elseif string.find(model, "group03", 1, true) then
				roleDescription = "Combatente Rebelde da Resistência (Lambda Resistance Fighter)"
				characterLore = "Você é guerrilheiro(a) da Resistência Lambda contra o Império Combine. Usa colete balístico improvisado da Proteção Civil e luta pela liberdade da humanidade."
			elseif string.find(model, "group02", 1, true) then
				roleDescription = "Refugiado(a) Sobrevivente fugindo da Proteção Civil"
				characterLore = "Você fugiu das batidas policiais de City 17 em 2019 e sobrevive pelos canais e esconderijos da Resistência."
			else
				roleDescription = "Cidadão(ã) de City 17 (Sob domínio da Combine)"
				characterLore = "Você é um(a) morador(a) que veste o uniforme azul padrão de cidadão, já foi transferido(a) três vezes de cidade pela Combine e conhece a dura rotina de racionamento e inspeções dos Metrocops."
			end
			charName = personalFirstName .. " (" .. roleDescription .. ")"
		elseif cls == "npc_metropolice" then
			local unitNum = 1000 + (seed % 8999)
			charName = "Oficial CP-" .. tostring(unitNum) .. " (" .. personalFirstName .. ")"
			roleDescription = "Agente da Proteção Civil (Metrocop / Civil Protection)"
			characterLore = "Você é um agente humano da Proteção Civil da Combine (Unidade CP-" .. tostring(unitNum) .. "). Entrou na corporação em 2017 para ter ração alimentar melhor e cotas de privilégio, patrulha as ruas com seu bastão de choque (Stunstick) e pistola 9mm, e tem autoridade policial rígida (mas ainda é humano por baixo da máscara)."
			voicePitch = 0.90
		elseif cls == "npc_combine_s" then
			local unitNum = 100 + (seed % 899)
			if string.find(model, "combine_super_soldier", 1, true) then
				charName = "Overwatch Elite #" .. tostring(unitNum)
				roleDescription = "Soldado de Elite da Combine Overwatch (Armadura Branca)"
				characterLore = "Você é um Soldado de Elite trans-humano da Combine Overwatch, equipado com rifle de pulso AR2 e bolas de energia. Fala com disciplina militar fria, tática e imponente."
			elseif string.find(model, "prison", 1, true) then
				charName = "Guarda de Nova Prospekt #" .. tostring(unitNum)
				roleDescription = "Soldado de Segurança da Prisão Nova Prospekt"
				characterLore = "Você atua na segurança máxima da antiga penitenciária de Nova Prospekt desde 2015."
			else
				charName = "Soldado Overwatch #" .. tostring(unitNum) .. " (" .. personalFirstName .. ")"
				roleDescription = "Soldado Trans-Humano da Combine Overwatch"
				characterLore = "Você é um soldado de assalto tático da Combine Overwatch. Usa comunicação de rádio militar ('Câmbio', 'Setor limpo', 'Alvo confirmado'), mas consegue conversar e relatar suas operações de combate."
			end
			voicePitch = 0.85
		elseif string.find(cls, "zombie", 1, true) then
			charName = "Infectado Consciente (" .. personalFirstName .. ")"
			roleDescription = "Hospedeiro de Headcrab Semiconsciente"
			characterLore = "Você foi atacado por um Headcrab em Ravenholm em 2018, mas milagrosamente manteve parte da consciência humana e consegue falar com voz sofrida e rouca sobre como aconteceu e a dor da mutação."
			voicePitch = 0.76
		else
			-- Custom Workshop NPC / SNPC / NextBot
			local cleanSpawnName = tostring(rawSpawnName or "")
			if cleanSpawnName == "" or cleanSpawnName == "Scripted Entity" or cleanSpawnName == "base_npc" then
				cleanSpawnName = string.gsub(cls, "^npc_vj_", "")
				cleanSpawnName = string.gsub(cleanSpawnName, "^npc_", "")
				cleanSpawnName = string.gsub(cleanSpawnName, "_", " ")
				cleanSpawnName = string.upper(string.sub(cleanSpawnName, 1, 1)) .. string.sub(cleanSpawnName, 2)
			end

			-- Decide if cleanSpawnName looks like a generic role or a specific named character
			local lowerSpawn = string.lower(cleanSpawnName)
			local isGenericRole = string.find(lowerSpawn, "citizen")
				or string.find(lowerSpawn, "soldier")
				or string.find(lowerSpawn, "police")
				or string.find(lowerSpawn, "cop")
				or string.find(lowerSpawn, "guard")
				or string.find(lowerSpawn, "rebel")
				or string.find(lowerSpawn, "civilian")
				or string.find(lowerSpawn, "trooper")
				or string.find(lowerSpawn, "mercenary")
				or string.find(lowerSpawn, "bandit")
				or string.find(lowerSpawn, "gang")
				or string.find(lowerSpawn, "scientist")
				or string.find(lowerSpawn, "marine")

			if isGenericRole then
				charName = personalFirstName .. " (" .. cleanSpawnName .. ")"
			else
				charName = cleanSpawnName
			end

			roleDescription = cleanSpawnName .. (category ~= "" and (" — Facção/Categoria: " .. category) or "")
			characterLore = "Você é o personagem '" .. cleanSpawnName .. "', originário do mod/pacote '" .. modSource .. "' (" .. universe .. "). Você tem total consciência de quem você é, das suas habilidades, armas, facção e da sua história dentro do seu universo, além de saber que atualmente está presente neste mapa de Garry's Mod (" .. game.GetMap() .. ")."
		end
	end

    local heldObjects=GA.HeldObjectInfo(ent)
    local npcWeapon="Unarmed"
    for _,item in ipairs(heldObjects) do if item.kind=="weapon" then npcWeapon=item.name.." ("..item.class..")" break end end

	-- Detect NPC's disposition toward the player
	local disposition = "Neutro / Calmo"
	local dispositionCode = 3 -- D_NU
	if SERVER and IsValid(observerPly) and ent.Disposition then
		local ok, disp = pcall(ent.Disposition, ent, observerPly)
		if ok and isnumber(disp) then
			dispositionCode = disp
			if disp == D_LI then
				disposition = "Aliado / Amigável (Gosta do jogador)"
			elseif disp == D_HT then
				disposition = "Hostil / Em Alerta contra o jogador"
			elseif disp == D_FR then
				disposition = "Assustado / Com medo do jogador"
			else
				disposition = "Neutro / Observando o jogador"
			end
		end
	end

	-- Deterministic personal traits & dated stories (Los Santos Alive style)
	local ageRange = canonical and canonical.ageRange or tostring(22 + (seed % 34)) .. " anos"
	local voiceStyle = GA.PickSeeded(VOICE_STYLES, seed, 3)
	local shootoutStory = GA.PickSeeded(SHOOTOUT_STORIES, seed, 7)
	local warStory = GA.PickSeeded(WAR_AND_PAST_STORIES, seed, 11)
	local familyStory = GA.PickSeeded(FAMILY_AND_PET_STORIES, seed, 17)

	-- Adjust pitch slightly per NPC seed so every citizen sounds unique
	if not canonical then
		local pitchOffset = ((seed % 15) - 7) * 0.012
		voicePitch = math.Clamp(voicePitch + pitchOffset, 0.75, 1.22)
	end

	if SERVER then
		ent:SetNWString("GModAlive_Name", tostring(charName or ""))
		ent:SetNWString("GModAlive_Role", tostring(roleDescription or ""))
	else
		local srvName = ent:GetNWString("GModAlive_Name", "")
		if srvName ~= "" then charName = srvName end
	end

	return {
		entIndex = entIndex,
		creationID = creationID,
		seed = seed,
		class = cls,
		model = model,
		name = charName,
		gender = isFemale and "Feminino" or "Masculino",
		isFemale = isFemale,
		ageRange = ageRange,
		role = roleDescription,
		modSource = modSource,
		framework = framework,
		category = category ~= "" and category or "Base / Sandbox",
		universe = universe,
		characterLore = characterLore,
		npcWeapon = npcWeapon,
        heldObjects = heldObjects,
		health = ent:Health(),
		maxHealth = math.max(ent:GetMaxHealth(), ent:Health(), 100),
		disposition = disposition,
		dispositionCode = dispositionCode,
		voiceStyle = voiceStyle,
		voicePitch = voicePitch,
		shootoutStory = shootoutStory,
		warStory = warStory,
		familyStory = familyStory
	}
end
