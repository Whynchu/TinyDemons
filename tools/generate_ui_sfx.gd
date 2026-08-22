extends SceneTree

## Deterministic offline synthesizer for the original Tiny Demons UI sound set.
## Run with:
##   godot --headless --path . --script res://tools/generate_ui_sfx.gd

const SAMPLE_RATE := 44100
const OUTPUT_DIR := "res://assets/sounds/generated_ui"

const RECIPES := {
	"ui_hover": {"duration": 0.400, "notes": [[0.000, 0.075, 1046.5, 1318.5, 0.34], [0.155, 0.105, 1568.0, 1396.9, 0.19]], "click": 0.25},
	"ui_confirm": {"duration": 0.500, "notes": [[0.000, 0.190, 659.3, 784.0, 0.34], [0.095, 0.310, 987.8, 1174.7, 0.27]], "click": 0.22},
	"ui_cancel": {"duration": 0.480, "notes": [[0.000, 0.075, 784.0, 698.5, 0.30], [0.125, 0.075, 622.3, 554.4, 0.26], [0.255, 0.115, 466.2, 392.0, 0.22]], "click": 0.23},
	"ui_denied": {"duration": 0.560, "notes": [[0.000, 0.090, 311.1, 293.7, 0.30], [0.155, 0.090, 311.1, 277.2, 0.28], [0.315, 0.125, 293.7, 261.6, 0.26]], "click": 0.30},
	"ui_open": {"duration": 0.700, "notes": [[0.000, 0.095, 392.0, 523.3, 0.28], [0.150, 0.105, 587.3, 784.0, 0.25], [0.315, 0.230, 987.8, 1174.7, 0.22]], "click": 0.19},
	"ui_close": {"duration": 0.720, "notes": [[0.000, 0.060, 987.8, 880.0, 0.27], [0.105, 0.060, 784.0, 698.5, 0.25], [0.210, 0.060, 659.3, 587.3, 0.23], [0.315, 0.065, 523.3, 466.2, 0.21], [0.430, 0.145, 392.0, 349.2, 0.19]], "click": 0.21},
	"ui_save": {"duration": 0.940, "notes": [[0.000, 0.300, 523.3, 587.3, 0.25], [0.125, 0.360, 659.3, 698.5, 0.25], [0.260, 0.580, 784.0, 1046.5, 0.27]], "click": 0.13},
	"ui_item_get": {"duration": 0.950, "notes": [[0.000, 0.180, 659.3, 784.0, 0.29], [0.090, 0.230, 987.8, 1174.7, 0.25], [0.490, 0.180, 1046.5, 1318.5, 0.25], [0.585, 0.260, 1568.0, 1760.0, 0.20]], "click": 0.21},
	"ui_money_get": {"duration": 0.500, "notes": [[0.000, 0.055, 1174.7, 1318.5, 0.17], [0.095, 0.055, 1396.9, 1568.0, 0.16], [0.190, 0.055, 1568.0, 1760.0, 0.15], [0.285, 0.090, 1760.0, 2093.0, 0.14]], "click": 0.18},
	"ui_level_up": {"duration": 1.400, "notes": [[0.000, 0.300, 392.0, 523.3, 0.24], [0.160, 0.340, 523.3, 659.3, 0.24], [0.340, 0.400, 659.3, 784.0, 0.24], [0.600, 0.650, 1046.5, 1318.5, 0.24]], "click": 0.16},
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for sound_name: String in RECIPES:
		_generate(sound_name, RECIPES[sound_name] as Dictionary)
	print("Generated %d original UI candidates in %s" % [RECIPES.size(), OUTPUT_DIR])
	quit()


func _generate(sound_name: String, recipe: Dictionary) -> void:
	var frame_count := int(ceil(float(recipe.duration) * SAMPLE_RATE))
	var left := PackedFloat32Array()
	var right := PackedFloat32Array()
	left.resize(frame_count)
	right.resize(frame_count)
	var note_index := 0
	for note_data in recipe.notes:
		var pan := -0.16 if note_index % 2 == 0 else 0.16
		_add_tone(left, right, float(note_data[0]), float(note_data[1]), float(note_data[2]), float(note_data[3]), float(note_data[4]), pan)
		note_index += 1
	var seed_value := sound_name.hash()
	_add_body(left, right, float(recipe.duration), float(recipe.notes[0][2]), float(recipe.click) * 0.55)
	_add_click(left, right, float(recipe.click), seed_value)
	_add_sparkles(left, right, float(recipe.duration), float(recipe.click), seed_value + 101)
	_add_air_tail(left, right, float(recipe.duration), float(recipe.click) * 0.025, seed_value + 307)
	var peak := 0.001
	for i in frame_count:
		peak = maxf(peak, maxf(absf(left[i]), absf(right[i])))
	var data := PackedByteArray()
	data.resize(frame_count * 4)
	for i in frame_count:
		var gain := minf(1.0, 0.90 / peak)
		var left_sample := _finish_sample(left[i] * gain)
		var right_sample := _finish_sample(right[i] * gain)
		data.encode_s16(i * 4, int(left_sample * 32767.0))
		data.encode_s16(i * 4 + 2, int(right_sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = true
	stream.data = data
	var error := stream.save_to_wav(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(sound_name)))
	if error != OK:
		push_error("Could not save %s: %s" % [sound_name, error_string(error)])


func _finish_sample(sample: float) -> float:
	var saturated := tanh(sample * 1.24) / tanh(1.24)
	return clampf(roundf(saturated * 2047.0) / 2047.0, -1.0, 1.0)


func _add_tone(left: PackedFloat32Array, right: PackedFloat32Array, start: float, duration: float, start_hz: float, end_hz: float, amplitude: float, pan: float) -> void:
	var first := int(start * SAMPLE_RATE)
	var count := mini(int(duration * SAMPLE_RATE), left.size() - first)
	var phase := 0.0
	var shimmer_phase := 0.0
	for offset in count:
		var progress := float(offset) / maxf(1.0, float(count - 1))
		var frequency := lerpf(start_hz, end_hz, progress)
		phase += TAU * frequency / SAMPLE_RATE
		shimmer_phase += TAU * frequency * 2.73 / SAMPLE_RATE
		var attack := minf(1.0, float(offset) / maxf(1.0, 0.006 * SAMPLE_RATE))
		var decay := pow(1.0 - progress, 2.25)
		var pitch_snap := sin(phase + sin(phase * 0.5) * 0.08)
		var glass_harmonic := sin(phase * 2.01) * 0.22 + sin(phase * 4.07) * 0.09
		var inharmonic := sin(shimmer_phase) * 0.11 * pow(1.0 - progress, 1.3)
		var value := (pitch_snap + glass_harmonic + inharmonic) * attack * decay * amplitude
		var left_gain := sqrt((1.0 - pan) * 0.5) * 1.414
		var right_gain := sqrt((1.0 + pan) * 0.5) * 1.414
		left[first + offset] += value * left_gain
		right[first + offset] += value * right_gain


func _add_body(left: PackedFloat32Array, right: PackedFloat32Array, total_duration: float, frequency: float, amplitude: float) -> void:
	var duration := minf(total_duration, 0.115)
	var count := mini(left.size(), int(duration * SAMPLE_RATE))
	var phase := 0.0
	for i in count:
		var progress := float(i) / maxf(1.0, float(count - 1))
		phase += TAU * frequency * 0.5 / SAMPLE_RATE
		var value := sin(phase) * pow(1.0 - progress, 3.0) * amplitude
		left[i] += value
		right[i] += value


func _add_click(left: PackedFloat32Array, right: PackedFloat32Array, amplitude: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var count := mini(left.size(), int(0.024 * SAMPLE_RATE))
	for i in count:
		var progress := float(i) / maxf(1.0, float(count - 1))
		var noise := rng.randf_range(-1.0, 1.0)
		var alternating := 1.0 if i % 2 == 0 else -1.0
		var knock := sin(TAU * 2400.0 * float(i) / SAMPLE_RATE) * 0.35
		var value := (noise * 0.45 + alternating * 0.20 + knock) * pow(1.0 - progress, 4.5) * amplitude
		left[i] += value * 0.93
		right[i] += value * 1.07


func _add_sparkles(left: PackedFloat32Array, right: PackedFloat32Array, total_duration: float, amplitude: float, seed_value: int) -> void:
	if total_duration < 0.12:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var grain_count := clampi(int(total_duration * 11.0), 2, 9)
	for grain in grain_count:
		var start := rng.randf_range(0.035, maxf(0.040, total_duration * 0.72))
		var duration := rng.randf_range(0.018, 0.055)
		var frequency := rng.randf_range(1800.0, 5200.0)
		var pan := rng.randf_range(-0.65, 0.65)
		_add_tone(left, right, start, duration, frequency, frequency * rng.randf_range(0.92, 1.12), amplitude * rng.randf_range(0.055, 0.12), pan)


func _add_air_tail(left: PackedFloat32Array, right: PackedFloat32Array, total_duration: float, amplitude: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var previous := 0.0
	for i in left.size():
		var progress := float(i) / maxf(1.0, float(left.size() - 1))
		var noise := rng.randf_range(-1.0, 1.0)
		var high_pass := noise - previous * 0.86
		previous = noise
		var envelope := pow(1.0 - progress, 2.0) * minf(1.0, progress * total_duration * 80.0)
		left[i] += high_pass * envelope * amplitude * 0.88
		right[i] += high_pass * envelope * amplitude * 1.12
