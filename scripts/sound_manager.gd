extends Node
class_name SoundManager

## Plays short sound effects. Friendly keys map to clip files in
## assets/sounds/. Missing clips no-op so the game runs before audio is added.
## Each sound gets its own AudioStreamPlayer so overlapping effects mix.

const SOUNDS_PATH := "res://assets/sounds/"
const BATTLE_PATH := SOUNDS_PATH + "10_Free_RPG_Battle_SFX/"
const UI_PATH := SOUNDS_PATH + "10_ui_sfx_free_samples/"
const MUSIC_PATH := SOUNDS_PATH + "Soundtrack/TINY_DEMONS_Main_Theme_Demo.wav"

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
var _chatter_player: AudioStreamPlayer = null
var _music_player: AudioStreamPlayer = null


func _ready() -> void:
	start_music()


func _exit_tree() -> void:
	if _music_player != null:
		_music_player.stop()
		_music_player.stream = null


func start_music(volume_linear: float = 0.6) -> void:
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "Music_Theme"
		_music_player.bus = "Master"
		_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_music_player)
	if _music_player.stream == null and ResourceLoader.exists(MUSIC_PATH):
		_music_player.stream = load(MUSIC_PATH) as AudioStream
		if not _music_player.finished.is_connected(_replay_music):
			_music_player.finished.connect(_replay_music)
	_music_player.volume_db = linear_to_db(volume_linear)
	if _music_player.stream != null and not _music_player.playing:
		_music_player.play()


func _replay_music() -> void:
	if _music_player != null and _music_player.stream != null:
		_music_player.play()


func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()


func play(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var player := _player(sound_name)
	if player == null or player.stream == null:
		return
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func chatter(volume_db: float = -12.0) -> void:
	if _chatter_player == null:
		_chatter_player = AudioStreamPlayer.new()
		_chatter_player.name = "SFX_Chatter"
		_chatter_player.bus = "Master"
		_chatter_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_chatter_player)
	if not _chatter_player.playing:
		_chatter_player.stream = _chatter_blip()
		_chatter_player.volume_db = volume_db
		_chatter_player.pitch_scale = 0.85 + randf_range(0.0, 0.35)
		_chatter_player.play()


func stop(sound_name: String) -> void:
	var player := _player(sound_name)
	if player != null:
		player.stop()


func _chatter_blip() -> AudioStreamWAV:
	var sample_rate := 11025
	var frames := 150
	var data := PackedByteArray()
	data.resize(frames * 2)
	var base_freq := 220.0 + randf_range(-40.0, 40.0)
	var phase := 0.0
	for i in frames:
		phase += base_freq / float(sample_rate)
		var square := 0.35 if fmod(phase, 1.0) < 0.5 else -0.35
		var fade := 1.0 - float(i) / float(frames)
		var sample := int(clampf(square * fade, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


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
