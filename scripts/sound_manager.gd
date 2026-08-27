extends Node
class_name SoundManager

## Plays short sound effects. Friendly keys map to clip files in
## assets/sounds/. Missing clips no-op so the game runs before audio is added.
## Each sound gets its own AudioStreamPlayer so overlapping effects mix.

const SOUNDS_PATH := "res://assets/sounds/"
const BATTLE_PATH := SOUNDS_PATH + "10_Free_RPG_Battle_SFX/"
const UI_PATH := SOUNDS_PATH + "10_ui_sfx_free_samples/"
const KH_UI_PATH := SOUNDS_PATH + "reconstructed_ui/"
const SOUND_MIX_PROFILE_PATH := SOUNDS_PATH + "sound_mix_profile.tres"
const SOUND_MIX_PROFILE_POLL_INTERVAL := 0.20
# digital_forever is intentionally kept well below the old theme's default
# level. The source mix is mastered hot, so -16 dB keeps it underneath the
# title UI and gameplay cues instead of making the menu overpowering.
const TITLE_MUSIC_PATH := SOUNDS_PATH + "Soundtrack/digital_forever.mp3"
# Keep the old name as a compatibility alias for callers that treat the title
# theme as the default music track.
const MUSIC_PATH := TITLE_MUSIC_PATH
const RUN_MUSIC_PATH := SOUNDS_PATH + "Soundtrack/Dungeon-Crawl.wav"
const TITLE_MUSIC_VOLUME_DB := -16.0
const RUN_MUSIC_VOLUME_DB := -10.0
const TITLE_MUSIC_VOLUME_LINEAR := 0.15848932
const RUN_MUSIC_VOLUME_LINEAR := 0.31622776

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
	"orb_hit": KH_UI_PATH + "BTL-MON-HIT04.sms-real.wav",
	"enemy_hit_5": KH_UI_PATH + "BTL-MON-HIT05.sms-real.wav",
	"enemy_hit_6": KH_UI_PATH + "BTL-MON-HIT06.sms-real.wav",
	"target_release": KH_UI_PATH + "sys-cansel.sms-real.wav",
	"foot_left": KH_UI_PATH + "sys-sr-footl.sms-real.wav",
	"foot_right": KH_UI_PATH + "sys-sr-footr.sms-real.wav",
}

var _players: Dictionary = {}
var _mix_profile: Resource = null
var _mix_profile_file_signature := 0
var _mix_profile_value_signature := 0
var _mix_profile_poll_timer := 0.0
var _player_requested_volume_db: Dictionary = {}
var _chatter_player: AudioStreamPlayer = null
var _chatter_requested_volume_db := -12.0
var _music_player: AudioStreamPlayer = null
var _music_fade_tween: Tween = null
var _music_stream_path := ""
var _music_mix_key: StringName = &""
var _music_fallback_volume_db := TITLE_MUSIC_VOLUME_DB
var _music_volume_percent := 100
var _sfx_volume_percent := 100
var _settings_service: SettingsService = null


func configure_settings(settings: SettingsService) -> void:
	_settings_service = settings
	if _settings_service != null:
		_music_volume_percent = int(_settings_service.get_setting(&"music_volume", 100))
		_sfx_volume_percent = int(_settings_service.get_setting(&"sfx_volume", 100))
		if not _settings_service.setting_changed.is_connected(_on_setting_changed):
			_settings_service.setting_changed.connect(_on_setting_changed)
	_refresh_audio_volumes()


func set_music_volume(value: int) -> void:
	var clamped := clampi(value, 0, 100)
	if _settings_service != null and int(_settings_service.get_setting(&"music_volume", _music_volume_percent)) != clamped:
		_settings_service.set_setting(&"music_volume", clamped)
		return
	_music_volume_percent = clamped
	_refresh_audio_volumes()


func set_sfx_volume(value: int) -> void:
	var clamped := clampi(value, 0, 100)
	if _settings_service != null and int(_settings_service.get_setting(&"sfx_volume", _sfx_volume_percent)) != clamped:
		_settings_service.set_setting(&"sfx_volume", clamped)
		return
	_sfx_volume_percent = clamped
	_refresh_audio_volumes()


func music_volume() -> int:
	return _music_volume_percent


func sfx_volume() -> int:
	return _sfx_volume_percent


func _on_setting_changed(key: StringName, value: Variant) -> void:
	if key == &"music_volume":
		_music_volume_percent = clampi(int(value), 0, 100)
	elif key == &"sfx_volume":
		_sfx_volume_percent = clampi(int(value), 0, 100)
	else:
		return
	_refresh_audio_volumes()


func _settings_volume_db(percent: int) -> float:
	if percent <= 0:
		return -80.0
	return linear_to_db(clampf(float(percent) / 100.0, 0.0001, 1.0))

func _ready() -> void:
	_ensure_mix_profile()
	# Load frequently-used menu cues before the first menu transition. Loading
	# an imported WAV on the exact frame a page opens causes a visible hitch.
	for sound_name in ["ui_hover", "ui_confirm", "ui_decline", "ui_unpause"]:
		_player(sound_name)


func _process(delta: float) -> void:
	if _mix_profile == null:
		return
	_mix_profile_poll_timer -= delta
	if _mix_profile_poll_timer > 0.0:
		return
	_mix_profile_poll_timer = SOUND_MIX_PROFILE_POLL_INTERVAL
	var current_value_signature := _profile_value_signature()
	if current_value_signature != 0 and current_value_signature != _mix_profile_value_signature:
		_mix_profile_value_signature = current_value_signature
		_refresh_audio_volumes()
	var current_signature := _profile_file_signature()
	if current_signature != 0 and current_signature != _mix_profile_file_signature:
		_reload_mix_profile(current_signature)


func _exit_tree() -> void:
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
		_music_fade_tween = null
	if _music_player != null:
		_music_player.stop()
		_music_player.stream = null


func start_music(volume_linear: float = -1.0) -> void:
	start_title_music(volume_linear)


func start_title_music(volume_linear: float = -1.0) -> void:
	_start_music_track(TITLE_MUSIC_PATH, volume_linear)


func start_run_music(volume_linear: float = -1.0) -> void:
	_start_music_track(RUN_MUSIC_PATH, volume_linear)


func _start_music_track(track_path: String, volume_linear: float) -> void:
	_ensure_mix_profile()
	var resolved_track_path := _preferred_audio_path(track_path)
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "Music_Theme"
		_music_player.bus = "Master"
		_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_music_player)
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
		_music_fade_tween = null
	if _music_stream_path != resolved_track_path:
		_music_player.stop()
		_music_player.stream = null
		_music_stream_path = resolved_track_path
		_music_player.stream = load(_music_stream_path) as AudioStream
		if not _music_player.finished.is_connected(_replay_music):
			_music_player.finished.connect(_replay_music)
	var music_key: StringName = &"run_music" if track_path == RUN_MUSIC_PATH else &"title_music"
	var fallback_volume_db := RUN_MUSIC_VOLUME_DB if music_key == &"run_music" else TITLE_MUSIC_VOLUME_DB
	if volume_linear >= 0.0:
		fallback_volume_db = linear_to_db(maxf(volume_linear, 0.000001))
	_music_mix_key = music_key
	_music_fallback_volume_db = fallback_volume_db
	_music_player.volume_db = _profile_music_volume_db(music_key, fallback_volume_db) + _settings_volume_db(_music_volume_percent)
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
		_music_stream_path = ""


func play(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if sound_name == "enemy_hit":
		sound_name = "enemy_hit_%d" % randi_range(1, 6)
	var player := _player(sound_name)
	if player == null or player.stream == null:
		return
	_player_requested_volume_db[sound_name] = volume_db
	player.volume_db = volume_db + _profile_trim_db(StringName(sound_name)) + _settings_volume_db(_sfx_volume_percent)
	player.pitch_scale = pitch_scale
	player.play()


func chatter(volume_db: float = -12.0) -> void:
	_ensure_mix_profile()
	_chatter_requested_volume_db = volume_db
	if _chatter_player == null:
		_chatter_player = AudioStreamPlayer.new()
		_chatter_player.name = "SFX_Chatter"
		_chatter_player.bus = "Master"
		_chatter_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_chatter_player)
	if not _chatter_player.playing:
		_chatter_player.stream = _chatter_blip()
		_chatter_player.volume_db = volume_db + _profile_trim_db(&"chatter") + _settings_volume_db(_sfx_volume_percent)
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
	if path.is_empty():
		return null
	var preferred_path := _preferred_audio_path(path)
	if not ResourceLoader.exists(preferred_path):
		return null
	return load(preferred_path) as AudioStream


func _preferred_audio_path(path: String) -> String:
	var ogg_path := path.get_basename() + ".ogg"
	return ogg_path if ResourceLoader.exists(ogg_path) else path


func get_mix_profile() -> Resource:
	_ensure_mix_profile()
	return _mix_profile


func _ensure_mix_profile() -> void:
	if _mix_profile != null:
		return
	_mix_profile = load(SOUND_MIX_PROFILE_PATH) as Resource
	if _mix_profile == null:
		return
	_mix_profile_file_signature = _profile_file_signature()
	_mix_profile_value_signature = _profile_value_signature()
	if not _mix_profile.changed.is_connected(_on_mix_profile_changed):
		_mix_profile.changed.connect(_on_mix_profile_changed)


func _reload_mix_profile(file_signature: int) -> void:
	var refreshed_profile := ResourceLoader.load(SOUND_MIX_PROFILE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as Resource
	if refreshed_profile == null:
		return
	if _mix_profile != null and _mix_profile.changed.is_connected(_on_mix_profile_changed):
		_mix_profile.changed.disconnect(_on_mix_profile_changed)
	_mix_profile = refreshed_profile
	_mix_profile_file_signature = file_signature
	_mix_profile_value_signature = _profile_value_signature()
	if not _mix_profile.changed.is_connected(_on_mix_profile_changed):
		_mix_profile.changed.connect(_on_mix_profile_changed)
	_refresh_audio_volumes()


func _on_mix_profile_changed() -> void:
	_mix_profile_file_signature = _profile_file_signature()
	_mix_profile_value_signature = _profile_value_signature()
	_refresh_audio_volumes()


func _refresh_audio_volumes() -> void:
	for sound_name in _players:
		var player := _players[sound_name] as AudioStreamPlayer
		if player == null:
			continue
		var requested_volume_db := float(_player_requested_volume_db.get(sound_name, 0.0))
		player.volume_db = requested_volume_db + _profile_trim_db(StringName(sound_name)) + _settings_volume_db(_sfx_volume_percent)
	if _chatter_player != null:
		_chatter_player.volume_db = _chatter_requested_volume_db + _profile_trim_db(&"chatter") + _settings_volume_db(_sfx_volume_percent)
	if _music_player != null and not _music_mix_key.is_empty():
		_music_player.volume_db = _profile_music_volume_db(_music_mix_key, _music_fallback_volume_db) + _settings_volume_db(_music_volume_percent)


func _profile_file_signature() -> int:
	if not FileAccess.file_exists(SOUND_MIX_PROFILE_PATH):
		return 0
	return FileAccess.get_file_as_string(SOUND_MIX_PROFILE_PATH).hash()


func _profile_value_signature() -> int:
	if _mix_profile == null:
		return 0
	return int(_mix_profile.call("value_signature"))


func _profile_trim_db(sound_name: StringName) -> float:
	_ensure_mix_profile()
	if _mix_profile == null:
		return 0.0
	return float(_mix_profile.call("volume_db_for", sound_name, 0.0))


func _profile_music_volume_db(sound_name: StringName, fallback_db: float) -> float:
	_ensure_mix_profile()
	if _mix_profile == null:
		return fallback_db
	return float(_mix_profile.call("volume_db_for", sound_name, fallback_db))
