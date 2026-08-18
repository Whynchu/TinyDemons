extends Node
class_name SoundManager

## Plays short chip-style sound effects rendered from Beepbox (WAV/OGG clips
## in assets/sounds/). Missing clips no-op so the game runs before audio is
## added. Each sound gets its own AudioStreamPlayer so overlapping effects mix.

const SOUNDS_PATH := "res://assets/sounds/"

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
	var path := "%s%s.wav" % [SOUNDS_PATH, sound_name]
	if not ResourceLoader.exists(path):
		path = "%s%s.ogg" % [SOUNDS_PATH, sound_name]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
