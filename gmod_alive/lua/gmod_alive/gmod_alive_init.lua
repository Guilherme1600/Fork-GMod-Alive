-- ============================================================================
-- GMod Alive — Talking AI NPCs
-- Autorun Bootstrap (Server & Client)
-- ============================================================================

GModAlive = GModAlive or {}
GModAlive.Version = "2.1.0-fork"
GModAlive.Prefix = "gmod_alive"

local sharedFiles = {
	"gmod_alive/sh_config.lua",
	"gmod_alive/sh_audio.lua",
	"gmod_alive/sh_presets.lua",
	"gmod_alive/sh_rules.lua",
	"gmod_alive/sh_orders.lua",
	"gmod_alive/sh_awareness.lua",
	"gmod_alive/sh_providers.lua",
	"gmod_alive/sh_api.lua",
	"gmod_alive/sh_inventory.lua",
	"gmod_alive/sh_npc_detector.lua"
}

local serverFiles = {
	"gmod_alive/sv_system_prompt.lua",
	"gmod_alive/sv_ai_client.lua",
	"gmod_alive/sv_actions.lua",
	"gmod_alive/sv_behaviour.lua",
	"gmod_alive/sv_orders.lua",
	"gmod_alive/sv_interaction.lua",
	"gmod_alive/sv_main.lua",
	"gmod_alive/sv_trade.lua",
	"gmod_alive/sv_awareness.lua",
	"gmod_alive/sv_extras.lua"
}

local clientFiles = {
	"gmod_alive/cl_theme.lua",
	"gmod_alive/cl_language.lua",
	"gmod_alive/cl_neural_api.lua",
	"gmod_alive/cl_free_speech.lua",
	"gmod_alive/cl_text_input.lua",
	"gmod_alive/cl_feedback.lua",
	"gmod_alive/cl_chat.lua",
	"gmod_alive/cl_bag.lua",
	"gmod_alive/cl_catalogue.lua",
	"gmod_alive/cl_settings.lua",
	"gmod_alive/cl_welcome.lua",
	"gmod_alive/cl_awareness.lua"
}

if SERVER then
	AddCSLuaFile()

	for _, filePath in ipairs(sharedFiles) do
		AddCSLuaFile(filePath)
		include(filePath)
	end

	for _, filePath in ipairs(clientFiles) do
		AddCSLuaFile(filePath)
	end

	for _, filePath in ipairs(serverFiles) do
		include(filePath)
	end

	resource.AddSingleFile("materials/gmod_alive/gmod_alive_icon.png")
	resource.AddSingleFile("sound/gmod_alive/ptt_start.wav")
	resource.AddSingleFile("sound/gmod_alive/ptt_stop.wav")
	resource.AddSingleFile("sound/gmod_alive/ui_click.wav")

	MsgC(
		Color(64, 224, 160), "[GMod Alive — Talking AI NPCs] ",
		Color(235, 240, 245), "v" .. GModAlive.Version .. " (Server) loaded.\n"
	)
else
	for _, filePath in ipairs(sharedFiles) do
		include(filePath)
	end

	for _, filePath in ipairs(clientFiles) do
		include(filePath)
	end

	MsgC(
		Color(64, 224, 160), "[GMod Alive — Talking AI NPCs] ",
		Color(235, 240, 245), "v" .. GModAlive.Version .. " (Client) loaded. ",
		Color(175, 195, 215), "Settings: Spawnmenu (Q) -> Options -> GMod Alive\n"
	)
end
