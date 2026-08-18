extends Node
class_name SoundManager

## Plays short sound effects. Friendly keys map to clip files in
## assets/sounds/. Missing clips no-op so the game runs before audio is added.
## Each sound gets its own AudioStreamPlayer so overlapping effects mix.

const SOUNDS_PATH := "res://assets/sounds/"
const BATTLE_PATH := SOUNDS_PATH + "10_Free_RPG_Battle_SFX/"
const UI_PATH := SOUNDS_PATH + "10_ui_sfx_free_samples/"

const CLIPS := {
	"slash": BATTLE_PATH + "22_Slash_04.wav",
	"miss": BATTLE_PATH + "35_Miss_Evade_02.wav",
	"flesh": BATTLE_PATH + "77_flesh_02.wav",
	"bite": BATTLE_PATH + "08_Bite_04.wav",
	"block": BATTLE_PATH + "39_Block_03.wav",
	"flee": BATTLE_PATH + "51_Flee_02.wav",
	"enemy_death": BATTLE_PATH + "69_Enemy_death_01.wav",
	"impact_flesh": BATTLE_PATH + "15_Impact_flesh_02.wav",
	"encounter": BATTLE_PATH + "55_Encounter_02.wav",
	"claw": BATTLE_PATH + "03_Claw_03.wav",
	"ui_hover": UI_PATH + "001_Hover_01.wav",
	"ui_confirm": UI_PATH + "013_Confirm_03.wav",
	"ui_decline": UI_PATH + "029_Decline_09.wav",
	"ui_denied": UI_PATH + "033_Denied_03.wav",
	"ui_use_item": UI_PATH + "051_use_item_01.wav",
	"ui_equip": UI_PATH + "070_Equip_10.wav",
	"ui_unequip": UI_PATH + "071_Unequip_01.wav",
	"ui_buy_sell": UI_PATH + "079_Buy_sell_01.wav",
	"ui_pause": UI_PATH + "092_Pause_04.wav",
	"ui_unpause": UI_PATH + "098_Unpause_04.wav",
}

var _players: Dictionary = {}


func play(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var player := _player(sound_name)
	if player == null or player.stream == null:
		return
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func stop(sound_name: String) -> void:
	var player := _player(sound_name)
	if player != null:
		player.stop()


func _player(sound_name: String) -> AudioStreamPlayer:
	if _players.has(sound_name):
		return _players[sound_name] as AudioStreamPlayer
	var stream := _load_stream(sound_name)
	var player := AudioStreamPlayer.new()
	player.name = "SFX_%s" % sound_name
	player.stream = stream
	player.bus = "Master"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	_players[sound_name] = player
	return player


func _load_stream(sound_name: String) -> AudioStream:
	var path: String = CLIPS.get(sound_name, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
