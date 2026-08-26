extends SceneTree

## Black-box evolutionary matcher for one decoded click reference.
## Decode references first with decode_sfx_references.gd, then run:
##   godot --headless --path . --script res://tools/optimize_click_match.gd -- SYS-CLICK

const SAMPLE_RATE := 11025
const POPULATION := 14
const SURVIVORS := 4
const GENERATIONS := 10
const FINALISTS := 8
const OUTPUT_DIR := "res://assets/sounds/generated_clicks_v2"
const PARAM_RANGES := {
	"base_hz": Vector2(180.0, 2600.0),
	"sweep_octaves": Vector2(-2.0, 2.0),
	"attack": Vector2(0.0005, 0.018),
	"decay": Vector2(0.025, 0.55),
	"tone_gain": Vector2(0.10, 1.0),
	"partial_ratio": Vector2(1.35, 6.2),
	"partial_gain": Vector2(0.0, 0.85),
	"metal_ratio": Vector2(2.1, 10.0),
	"metal_gain": Vector2(0.0, 0.55),
	"fm_ratio": Vector2(0.25, 8.0),
	"fm_index": Vector2(0.0, 7.0),
	"fm_decay": Vector2(0.004, 0.30),
	"noise_gain": Vector2(0.0, 0.90),
	"noise_decay": Vector2(0.003, 0.12),
	"noise_color": Vector2(-0.92, 0.92),
	"resonator_hz": Vector2(300.0, 7200.0),
	"resonator_gain": Vector2(0.0, 0.75),
	"resonator_decay": Vector2(0.006, 0.32),
	"modal_gain": Vector2(0.0, 1.0),
	"modal_spread": Vector2(0.18, 1.9),
	"modal_tilt": Vector2(-2.4, 0.4),
	"modal_decay": Vector2(0.035, 0.75),
	"modal_decay_spread": Vector2(0.55, 1.28),
	"modal_drift": Vector2(-2.5, 2.5),
	"modal_oddity": Vector2(0.0, 0.45),
	"excitation_decay": Vector2(0.002, 0.065),
	"body_gain": Vector2(0.0, 0.55),
	"event_count": Vector2(1.0, 4.99),
	"event_spacing": Vector2(0.018, 0.24),
	"event_pitch": Vector2(0.55, 1.85),
	"event_decay": Vector2(0.35, 1.0),
	"echo_delay": Vector2(0.0, 0.18),
	"echo_gain": Vector2(0.0, 0.65),
	"drive": Vector2(0.7, 3.5),
	"quantization": Vector2(64.0, 4096.0),
}

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 0x54494e5944454d4f
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var target_name := "SYS-CLICK" if args.is_empty() else args[0]
	var workspace := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var target_path := workspace.path_join("sfx analysis").path_join(target_name + ".wav")
	if not FileAccess.file_exists(target_path):
		push_error("Decoded reference is missing: %s" % target_path)
		quit(1)
		return
	var target := _trim_and_resample(_read_wav(target_path))
	if target.is_empty():
		push_error("Reference contains no measurable audio: %s" % target_name)
		quit(1)
		return
	var target_features := _features(target)
	var silence := PackedFloat32Array()
	silence.resize(target.size())
	var null_loss := _feature_loss(target_features, _features(silence))
	var population: Array[Dictionary] = []
	for i in POPULATION:
		population.append(_random_candidate())
	var history: Array = []
	for generation in GENERATIONS:
		for candidate in population:
			var audio := _synthesize(candidate.params, target.size())
			candidate.loss = _feature_loss(target_features, _features(audio))
		population.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.loss) < float(b.loss))
		var best: Dictionary = population[0]
		var score := _calibrated_score(float(best.loss), null_loss)
		history.append({"generation": generation, "loss": best.loss, "score": score})
		print("%s generation %02d: loss=%.6f score=%.2f" % [target_name, generation, best.loss, score])
		var next: Array[Dictionary] = []
		for survivor in SURVIVORS:
			next.append({"params": (population[survivor].params as Dictionary).duplicate(true), "loss": INF})
		var mutation_scale := lerpf(0.24, 0.035, float(generation) / maxf(1.0, GENERATIONS - 1.0))
		while next.size() < POPULATION - 2:
			var parent: Dictionary = population[_rng.randi_range(0, SURVIVORS - 1)]
			next.append({"params": _mutate(parent.params, mutation_scale), "loss": INF})
		next.append(_random_candidate())
		next.append(_random_candidate())
		population = next
	# Score the last offspring population before selecting the final result.
	for candidate in population:
		candidate.loss = _feature_loss(target_features, _features(_synthesize(candidate.params, target.size())))
	population.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.loss) < float(b.loss))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var finalist_reports: Array = []
	for rank in mini(FINALISTS, population.size()):
		var finalist: Dictionary = population[rank]
		var finalist_audio := _synthesize(finalist.params, target.size())
		var stem := "%s_proxy_%02d" % [target_name.to_lower(), rank]
		_save_wav(OUTPUT_DIR.path_join(stem), finalist_audio)
		finalist_reports.append({"rank": rank, "proxy_loss": finalist.loss, "parameters": finalist.params})
	var winner: Dictionary = population[0]
	var report := {
		"target": target_name,
		"sample_rate": SAMPLE_RATE,
		"active_seconds": float(target.size()) / SAMPLE_RATE,
		"loss": winner.loss,
		"score": _calibrated_score(float(winner.loss), null_loss),
		"silence_loss": null_loss,
		"parameters": winner.params,
		"finalists": finalist_reports,
		"history": history,
	}
	var report_file := FileAccess.open(OUTPUT_DIR.path_join(target_name.to_lower() + "_match.json"), FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t"))
	print("Saved %d %s proxy finalists; multi-resolution reranking is still required" % [FINALISTS, target_name])
	quit()


func _calibrated_score(loss: float, null_loss: float) -> float:
	# Zero is no better than silence; 100 is feature-identical to the target.
	return clampf((1.0 - loss / maxf(0.000001, null_loss)) * 100.0, 0.0, 100.0)


func _random_candidate() -> Dictionary:
	var params := {}
	for key: String in PARAM_RANGES:
		var limits: Vector2 = PARAM_RANGES[key]
		params[key] = _rng.randf_range(limits.x, limits.y)
	return {"params": params, "loss": INF}


func _mutate(source: Dictionary, scale: float) -> Dictionary:
	var result := source.duplicate(true)
	for key: String in PARAM_RANGES:
		if _rng.randf() > 0.72:
			continue
		var limits: Vector2 = PARAM_RANGES[key]
		var span := limits.y - limits.x
		result[key] = clampf(float(result[key]) + _rng.randfn(0.0, span * scale), limits.x, limits.y)
	return result


func _synthesize(params: Dictionary, frame_count: int) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(frame_count)
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = 0x434c49434b
	var event_count := clampi(int(round(float(params.event_count))), 1, 4)
	var event_phases: Array[float] = []
	var partial_phases: Array[float] = []
	var metal_phases: Array[float] = []
	var fm_phases: Array[float] = []
	var resonator_phases: Array[float] = []
	for event in event_count:
		event_phases.append(0.0)
		partial_phases.append(0.0)
		metal_phases.append(0.0)
		fm_phases.append(0.0)
		resonator_phases.append(0.0)
	var colored_noise := 0.0
	for i in frame_count:
		var time := float(i) / SAMPLE_RATE
		var raw_noise := noise_rng.randf_range(-1.0, 1.0)
		var color := float(params.noise_color)
		colored_noise = raw_noise * (1.0 - absf(color)) + colored_noise * color
		var value := 0.0
		for event in event_count:
			var local_time := time - event * float(params.event_spacing)
			if local_time < 0.0:
				continue
			var event_gain := pow(float(params.event_decay), event)
			var event_frequency := float(params.base_hz) * pow(float(params.event_pitch), event)
			var progress := clampf(local_time / maxf(0.001, float(params.decay)), 0.0, 1.0)
			var frequency := event_frequency * pow(2.0, float(params.sweep_octaves) * progress)
			fm_phases[event] += TAU * frequency * float(params.fm_ratio) / SAMPLE_RATE
			var fm_amount := float(params.fm_index) * exp(-local_time / maxf(0.001, float(params.fm_decay)))
			event_phases[event] += TAU * frequency / SAMPLE_RATE + sin(fm_phases[event]) * fm_amount / SAMPLE_RATE * 80.0
			partial_phases[event] += TAU * frequency * float(params.partial_ratio) / SAMPLE_RATE
			metal_phases[event] += TAU * frequency * float(params.metal_ratio) / SAMPLE_RATE
			resonator_phases[event] += TAU * float(params.resonator_hz) / SAMPLE_RATE
			var attack_env := minf(1.0, local_time / maxf(0.0001, float(params.attack)))
			var tone_env := attack_env * exp(-local_time / maxf(0.001, float(params.decay)))
			var noise_env := exp(-local_time / maxf(0.001, float(params.noise_decay)))
			var resonator_env := exp(-local_time / maxf(0.001, float(params.resonator_decay)))
			var tone := sin(event_phases[event]) * float(params.tone_gain)
			tone += sin(partial_phases[event]) * float(params.partial_gain)
			tone += sin(metal_phases[event]) * float(params.metal_gain)
			var body := sin(event_phases[event] * 0.5) * float(params.body_gain) * exp(-local_time / 0.065)
			var noise := colored_noise * float(params.noise_gain) * noise_env
			var resonator := sin(resonator_phases[event]) * colored_noise * float(params.resonator_gain) * resonator_env
			var excitation := exp(-local_time / maxf(0.001, float(params.excitation_decay)))
			var modal_body := 0.0
			for mode in 7:
				var mode_number := float(mode + 1)
				var unevenness := sin(mode_number * 12.9898 + event * 7.13) * float(params.modal_oddity)
				var ratio := 1.0 + mode * float(params.modal_spread) + unevenness
				var modal_frequency := event_frequency * maxf(0.2, ratio)
				var modal_decay := float(params.modal_decay) * pow(float(params.modal_decay_spread), mode)
				var modal_envelope := exp(-local_time / maxf(0.004, modal_decay))
				var modal_amplitude := pow(mode_number, float(params.modal_tilt))
				var chirped_time := local_time + 0.5 * float(params.modal_drift) * local_time * local_time
				var modal_phase := TAU * modal_frequency * chirped_time + mode * 0.73
				modal_body += sin(modal_phase) * modal_amplitude * modal_envelope
			modal_body *= float(params.modal_gain) * (1.0 - excitation * 0.35)
			value += (tone * tone_env + body + noise + resonator + modal_body) * event_gain
		samples[i] = value
	var delay_frames := int(float(params.echo_delay) * SAMPLE_RATE)
	if delay_frames > 0 and delay_frames < frame_count:
		for i in range(delay_frames, frame_count):
			samples[i] += samples[i - delay_frames] * float(params.echo_gain)
	var peak := 0.001
	for value in samples:
		peak = maxf(peak, absf(value))
	var drive := float(params.drive)
	var steps := maxf(2.0, float(params.quantization))
	for i in samples.size():
		var value := samples[i] / peak * 0.92
		value = tanh(value * drive) / tanh(drive)
		samples[i] = roundf(value * steps) / steps
	return samples


func _features(source: PackedFloat32Array) -> Dictionary:
	var samples := _normalize(source)
	return {
		"envelope": _rms_bins(samples, 64),
		"transient": _rms_bins(samples.slice(0, mini(samples.size(), int(0.08 * SAMPLE_RATE))), 24),
		"zcr": _zcr_bins(samples, 32),
		"spectrum": _spectral_bands(samples, 36),
		"early_spectrum": _spectral_bands(samples.slice(0, mini(samples.size(), int(0.12 * SAMPLE_RATE))), 24),
	}


func _feature_loss(target: Dictionary, candidate: Dictionary) -> float:
	return (
		_vector_mse(target.envelope, candidate.envelope) * 0.24
		+ _vector_mse(target.transient, candidate.transient) * 0.20
		+ _vector_mse(target.zcr, candidate.zcr) * 0.10
		+ _vector_mse(target.spectrum, candidate.spectrum) * 0.28
		+ _vector_mse(target.early_spectrum, candidate.early_spectrum) * 0.18
	)


func _rms_bins(samples: PackedFloat32Array, bin_count: int) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(bin_count)
	for bin in bin_count:
		var first := int(float(bin) / bin_count * samples.size())
		var last := maxi(first + 1, int(float(bin + 1) / bin_count * samples.size()))
		var sum := 0.0
		for i in range(first, mini(last, samples.size())):
			sum += samples[i] * samples[i]
		result[bin] = sqrt(sum / maxf(1.0, last - first))
	return result


func _zcr_bins(samples: PackedFloat32Array, bin_count: int) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(bin_count)
	for bin in bin_count:
		var first := maxi(1, int(float(bin) / bin_count * samples.size()))
		var last := maxi(first + 1, int(float(bin + 1) / bin_count * samples.size()))
		var crossings := 0.0
		for i in range(first, mini(last, samples.size())):
			if (samples[i] >= 0.0) != (samples[i - 1] >= 0.0):
				crossings += 1.0
		result[bin] = crossings / maxf(1.0, last - first)
	return result


func _spectral_bands(samples: PackedFloat32Array, band_count: int) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(band_count)
	if samples.is_empty():
		return result
	# Analyze at most 4096 evenly distributed samples to keep optimization fast.
	var stride := maxi(1, int(ceil(float(samples.size()) / 4096.0)))
	var analyzed_count := int(ceil(float(samples.size()) / stride))
	var total := 0.000001
	for band in band_count:
		var ratio := float(band) / maxf(1.0, band_count - 1.0)
		var frequency := 80.0 * pow(90.0, ratio)
		var omega := TAU * frequency * stride / SAMPLE_RATE
		var coefficient := 2.0 * cos(omega)
		var q0 := 0.0
		var q1 := 0.0
		var q2 := 0.0
		for index in analyzed_count:
			var sample_index := mini(index * stride, samples.size() - 1)
			var window := 0.5 - 0.5 * cos(TAU * index / maxf(1.0, analyzed_count - 1.0))
			q0 = samples[sample_index] * window + coefficient * q1 - q2
			q2 = q1
			q1 = q0
		var power := maxf(0.0, q1 * q1 + q2 * q2 - coefficient * q1 * q2)
		result[band] = sqrt(power) / maxf(1.0, analyzed_count)
		total += result[band]
	for band in band_count:
		result[band] /= total
	return result


func _vector_mse(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var count := mini(a.size(), b.size())
	var sum := 0.0
	for i in count:
		var difference := a[i] - b[i]
		sum += difference * difference
	return sum / maxf(1.0, count)


func _normalize(source: PackedFloat32Array) -> PackedFloat32Array:
	var result := source.duplicate()
	var peak := 0.000001
	for value in result:
		peak = maxf(peak, absf(value))
	for i in result.size():
		result[i] /= peak
	return result


func _trim_and_resample(input: Dictionary) -> PackedFloat32Array:
	var source: PackedFloat32Array = input.samples
	var source_rate: int = input.sample_rate
	var peak := 0.000001
	for value in source:
		peak = maxf(peak, absf(value))
	var threshold := peak * 0.01
	var first := 0
	var last := source.size() - 1
	while first < source.size() and absf(source[first]) < threshold:
		first += 1
	while last > first and absf(source[last]) < threshold:
		last -= 1
	var trimmed := source.slice(first, last + 1)
	if source_rate == SAMPLE_RATE:
		return trimmed
	var output_count := int(ceil(float(trimmed.size()) * SAMPLE_RATE / source_rate))
	var output := PackedFloat32Array()
	output.resize(output_count)
	for i in output_count:
		var position := float(i) * source_rate / SAMPLE_RATE
		var low := mini(int(floor(position)), trimmed.size() - 1)
		var high := mini(low + 1, trimmed.size() - 1)
		output[i] = lerpf(trimmed[low], trimmed[high], position - low)
	return output


func _read_wav(path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	var channels := bytes.decode_u16(22)
	var sample_rate := bytes.decode_u32(24)
	var offset := 12
	var data_offset := -1
	var data_size := 0
	while offset + 8 <= bytes.size():
		var chunk_name := bytes.slice(offset, offset + 4).get_string_from_ascii()
		var chunk_size := bytes.decode_u32(offset + 4)
		if chunk_name == "data":
			data_offset = offset + 8
			data_size = chunk_size
			break
		offset += 8 + chunk_size + (chunk_size % 2)
	var samples := PackedFloat32Array()
	if data_offset < 0:
		return {"samples": samples, "sample_rate": int(sample_rate)}
	var frames := int(data_size / (channels * 2))
	samples.resize(frames)
	for frame in frames:
		var sum := 0.0
		for channel in channels:
			sum += bytes.decode_s16(data_offset + (frame * channels + channel) * 2) / 32768.0
		samples[frame] = sum / channels
	return {"samples": samples, "sample_rate": int(sample_rate)}


func _save_wav(path_without_extension: String, samples: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	var error := stream.save_to_wav(ProjectSettings.globalize_path(path_without_extension))
	if error != OK:
		push_error("Could not save optimized WAV: %s" % error_string(error))
