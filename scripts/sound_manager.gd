extends Node
class_name SoundManager

## Plays short sound effects. Friendly keys map to clip files in
## assets/sounds/. Missing clips no-op so the game runs before audio is added.
## Each sound gets its own AudioStreamPlayer so overlapping effects mix.

const SOUNDS_PATH := "res://assets/sounds/"
const BATTLE_PATH := SOUNDS_PATH + "10_Free_RPG_Battle_SFX/"
const UI_PATH := SOUNDS_PATH + "10_ui_sfx_free_samples/"
const KH_UI_PATH := SOUNDS_PATH + "reconstructed_ui/"
const MUSIC_PATH := SOUNDS_PATH + "Soundtrack/TINY DEMONS - MAIN THEME.wav"

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
	"magic_cast": BATTLE_PATH + "55_Encounter_02.wav",
	"magic_hit": BATTLE_PATH + "15_Impact_flesh_02.wav",
	"ui_hover": KH_UI_PATH + "sys-click.sms-real.wav",
	"ui_confirm": KH_UI_PATH + "sys-click104b.sms-real.wav",
	"ui_decline": KH_UI_PATH + "sys-cansel.sms-real.wav",
	"ui_denied": UI_PATH + "033_Denied_03.wav",
	"ui_use_item": UI_PATH + "051_use_item_01.wav",
	"ui_equip": UI_PATH + "070_Equip_10.wav",
	"ui_unequip": UI_PATH + "071_Unequip_01.wav",
	"ui_buy_sell": UI_PATH + "079_Buy_sell_01.wav",
	"ui_pause": KH_UI_PATH + "sys-saveload.sms-real.wav",
	"ui_unpause": KH_UI_PATH + "sys-close.sms-real.wav",
	"enemy_alert": KH_UI_PATH + "sys-chagef1.sms-real.wav",
	"item_pickup": KH_UI_PATH + "sys-itemget.sms-real.wav",
	"chest_unlock": KH_UI_PATH + "sys-tresure.sms-real.wav",
	"chest_reward": KH_UI_PATH + "sys-money-get.sms-real.wav",
	"run_clear": KH_UI_PATH + "sys-money-get.sms-real.wav",
	"level_up": KH_UI_PATH + "ef-mon-up.sms-real.wav",
	"enemy_hit_1": KH_UI_PATH + "BTL-MON-HIT01.sms-real.wav",
	"enemy_hit_2": KH_UI_PATH + "BTL-MON-HIT02.sms-real.wav",
	"enemy_hit_3": KH_UI_PATH + "BTL-MON-HIT03.sms-real.wav",
	"enemy_hit_4": KH_UI_PATH + "BTL-MON-HIT04.sms-real.wav",
	"enemy_hit_5": KH_UI_PATH + "BTL-MON-HIT05.sms-real.wav",
	"enemy_hit_6": KH_UI_PATH + "BTL-MON-HIT06.sms-real.wav",
	"target_release": KH_UI_PATH + "sys-cansel.sms-real.wav",
	"foot_left": KH_UI_PATH + "sys-sr-footl.sms-real.wav",
	"foot_right": KH_UI_PATH + "sys-sr-footr.sms-real.wav",
}

var _players: Dictionary = {}
var _chatter_player: AudioStreamPlayer = null
var _music_player: AudioStreamPlayer = null
var _music_fade_tween: Tween = null

func _ready() -> void:
	# Load frequently-used menu cues before the first menu transition. Loading
	# an imported WAV on the exact frame a page opens causes a visible hitch.
	for sound_name in ["ui_hover", "ui_confirm", "ui_decline", "ui_unpause"]:
		_player(sound_name)


func _exit_tree() -> void:
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
		_music_fade_tween = null
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
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
		_music_fade_tween = null
	if _music_player.stream == null and ResourceLoader.exists(MUSIC_PATH):
		_music_player.stream = load(MUSIC_PATH) as AudioStream
		if not _music_player.finished.is_connected(_replay_music):
			_music_player.finished.connect(_replay_music)
	_music_player.volume_db = linear_to_db(volume_linear)
	if _music_player.stream != null and not _music_player.playing:
		_music_player.play()


func fade_out_music(duration: float = 1.0) -> void:
	if _music_player == null or not _music_player.playing:
		return
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(_music_player, "volume_db", -80.0, duration)
	_music_fade_tween.tween_callback(func() -> void:
		if _music_player != null:
			_music_player.stop()
		_music_fade_tween = null
	)


func _replay_music() -> void:
	if _music_player != null and _music_player.stream != null:
		_music_player.play()


func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()


func play(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if sound_name == "enemy_hit":
		sound_name = "enemy_hit_%d" % randi_range(1, 6)
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
