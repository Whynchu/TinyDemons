extends SceneTree

## Validates the time-frequency metric used by the click optimizer. This tool
## intentionally performs no synthesis: a metric must prove its invariances and
## discrimination before it is allowed to rank generated sounds.

const SAMPLE_RATE := 22050
const CLICK_NAMES := ["SYS-CLICK", "SYS-CLICK102", "SYS-CLICK104", "SYS-CLICK104B"]
const FFT_SIZES := [128, 512, 2048]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var workspace := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var analysis_dir := workspace.path_join("sfx analysis")
	var references := {}
	for click_name in CLICK_NAMES:
		var path := analysis_dir.path_join(click_name + ".wav")
		if not FileAccess.file_exists(path):
			push_error("Missing decoded reference: %s" % path)
			quit(1)
			return
		references[click_name] = _prepare(_read_wav(path))
	var cross_losses: Array[float] = []
	for i in CLICK_NAMES.size():
		for j in range(i + 1, CLICK_NAMES.size()):
			cross_losses.append(float(_compare(references[CLICK_NAMES[i]], references[CLICK_NAMES[j]]).total))
	cross_losses.sort()
	var calibration := cross_losses[cross_losses.size() / 2]
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		if args.size() > 1:
			_score_candidate(args[0], args[1], references, calibration)
		else:
			_rerank_finalists(args[0], references, calibration)
		return
	var base: PackedFloat32Array = references["SYS-CLICK"]
	var validations := {
		"self": _compare(base, base),
		"gain_x_0_35": _compare(base, _scaled(base, 0.35)),
		"front_padding_20ms": _compare(base, _padded(base, int(0.020 * SAMPLE_RATE))),
		"shift_4ms": _compare(base, _padded(base, int(0.004 * SAMPLE_RATE))),
	}
	var unrelated_path := ProjectSettings.globalize_path("res://assets/sounds/generated_ui/ui_level_up.wav")
	if FileAccess.file_exists(unrelated_path):
		validations["unrelated_level_up"] = _compare(base, _prepare(_read_wav(unrelated_path)))
	var matrix := {}
	for target_name in CLICK_NAMES:
		var row := {}
		for candidate_name in CLICK_NAMES:
			var result := _compare(references[target_name], references[candidate_name])
			result.score = _score(float(result.total), calibration)
			row[candidate_name] = result
		matrix[target_name] = row
	for key in validations:
		validations[key].score = _score(float(validations[key].total), calibration)
	var report := {
		"sample_rate": SAMPLE_RATE,
		"fft_sizes": FFT_SIZES,
		"cross_reference_calibration_loss": calibration,
		"validation": validations,
		"click_discrimination_matrix": matrix,
	}
	var output_path := ProjectSettings.globalize_path("res://tools/audio_match_metric_report.json")
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print("Metric validation")
	for key in validations:
		print("  %s: loss=%.6f score=%.2f" % [key, validations[key].total, validations[key].score])
	print("Cross-click scores")
	for target_name in CLICK_NAMES:
		var values: Array[String] = []
		for candidate_name in CLICK_NAMES:
			values.append("%s=%.1f" % [candidate_name, matrix[target_name][candidate_name].score])
		print("  %s: %s" % [target_name, ", ".join(values)])
	quit()


func _score_candidate(target_name: String, candidate_path: String, references: Dictionary, calibration: float) -> void:
	if not references.has(target_name) or not FileAccess.file_exists(candidate_path):
		push_error("Target or candidate missing: %s / %s" % [target_name, candidate_path])
		quit(1)
		return
	var candidate := _prepare(_read_wav(candidate_path))
	var components := _compare(references[target_name], candidate)
	components.score = _score(float(components.total), calibration)
	var report_path := ProjectSettings.globalize_path("res://tools/audio_match_candidate_report.json")
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	report_file.store_string(JSON.stringify({"target": target_name, "candidate": candidate_path, "components": components}, "\t"))
	print("Candidate score for %s: %.2f (loss %.6f)" % [target_name, components.score, components.total])
	print("  attack=%.6f body=%.6f tail=%.6f envelope=%.6f waveform=%.6f" % [components.attack, components.body, components.tail, components.envelope, components.waveform])
	quit()


func _rerank_finalists(target_name: String, references: Dictionary, calibration: float) -> void:
	if not references.has(target_name):
		push_error("Unknown click target: %s" % target_name)
		quit(1)
		return
	var directory_path := ProjectSettings.globalize_path("res://assets/sounds/generated_clicks_v2")
	var directory := DirAccess.open(directory_path)
	if directory == null:
		push_error("Finalist directory is missing: %s" % directory_path)
		quit(1)
		return
	var prefix := target_name.to_lower() + "_proxy_"
	var results: Array[Dictionary] = []
	for filename in directory.get_files():
		if not filename.begins_with(prefix) or filename.get_extension().to_lower() != "wav":
			continue
		var candidate := _prepare(_read_wav(directory_path.path_join(filename)))
		var components := _compare(references[target_name], candidate)
		components.score = _score(float(components.total), calibration)
		results.append({"file": filename, "components": components})
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.components.total) < float(b.components.total))
	if results.is_empty():
		push_error("No finalists found for %s" % target_name)
		quit(1)
		return
	var winner: Dictionary = results[0]
	var winner_path := directory_path.path_join(winner.file)
	var selected_path := directory_path.path_join(target_name.to_lower() + "_selected.wav")
	var copy_error := DirAccess.copy_absolute(winner_path, selected_path)
	if copy_error != OK:
		push_error("Could not save selected finalist: %s" % error_string(copy_error))
	var report_path := directory_path.path_join(target_name.to_lower() + "_rerank.json")
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	report_file.store_string(JSON.stringify({"target": target_name, "calibration_loss": calibration, "winner": winner, "ranking": results}, "\t"))
	print("Multi-resolution finalist ranking for %s" % target_name)
	for rank in results.size():
		print("  %02d %s score=%.2f loss=%.6f" % [rank, results[rank].file, results[rank].components.score, results[rank].components.total])
	quit()


func _compare(target_input: PackedFloat32Array, candidate_input: PackedFloat32Array) -> Dictionary:
	var target := _normalize(_trim(target_input))
	var candidate := _normalize(_trim(candidate_input))
	var lag := _best_lag(target, candidate, int(0.025 * SAMPLE_RATE))
	candidate = _align(candidate, lag, target.size())
	var attack_end := mini(target.size(), int(0.065 * SAMPLE_RATE))
	var body_end := mini(target.size(), int(0.300 * SAMPLE_RATE))
	var attack := _region_loss(target.slice(0, attack_end), candidate.slice(0, attack_end))
	var body := _region_loss(target.slice(attack_end, body_end), candidate.slice(attack_end, body_end))
	var tail := _region_loss(target.slice(body_end), candidate.slice(body_end)) if body_end < target.size() else 0.0
	var envelope := _envelope_loss(target, candidate, 96)
	var waveform := _waveform_loss(target, candidate)
	var total := attack * 0.34 + body * 0.30 + tail * 0.16 + envelope * 0.14 + waveform * 0.06
	return {
		"total": total,
		"attack": attack,
		"body": body,
		"tail": tail,
		"envelope": envelope,
		"waveform": waveform,
		"alignment_samples": lag,
	}


func _region_loss(target: PackedFloat32Array, candidate: PackedFloat32Array) -> float:
	if target.size() < 16:
		return 0.0
	var log_magnitude := 0.0
	var convergence := 0.0
	var used := 0
	for fft_size in FFT_SIZES:
		if target.size() < fft_size / 2:
			continue
		var pair := _stft_pair_loss(target, candidate, fft_size, maxi(16, fft_size / 4))
		log_magnitude += pair.log_magnitude
		convergence += pair.convergence
		used += 1
	if used == 0:
		return 0.0
	return (log_magnitude / used) * 0.72 + (convergence / used) * 0.28


func _stft_pair_loss(target: PackedFloat32Array, candidate: PackedFloat32Array, fft_size: int, hop: int) -> Dictionary:
	var log_sum := 0.0
	var difference_energy := 0.0
	var target_energy := 0.000001
	var value_count := 0
	var frame_count := maxi(1, int(ceil(float(maxi(target.size(), fft_size) - fft_size) / hop)) + 1)
	for frame in frame_count:
		var offset := frame * hop
		var target_spectrum := _magnitude_spectrum(target, offset, fft_size)
		var candidate_spectrum := _magnitude_spectrum(candidate, offset, fft_size)
		for bin in target_spectrum.size():
			var target_value := target_spectrum[bin]
			var candidate_value := candidate_spectrum[bin]
			var log_difference := log(0.0001 + target_value) - log(0.0001 + candidate_value)
			log_sum += log_difference * log_difference
			var difference := target_value - candidate_value
			difference_energy += difference * difference
			target_energy += target_value * target_value
			value_count += 1
	return {
		"log_magnitude": sqrt(log_sum / maxf(1.0, value_count)) / 6.0,
		"convergence": sqrt(difference_energy / target_energy),
	}


func _magnitude_spectrum(samples: PackedFloat32Array, offset: int, fft_size: int) -> PackedFloat32Array:
	var values: Array[Vector2] = []
	values.resize(fft_size)
	for i in fft_size:
		var sample := samples[offset + i] if offset + i < samples.size() else 0.0
		var window := 0.5 - 0.5 * cos(TAU * i / maxf(1.0, fft_size - 1.0))
		values[i] = Vector2(sample * window, 0.0)
	_fft(values)
	var result := PackedFloat32Array()
	result.resize(fft_size / 2 + 1)
	for i in result.size():
		result[i] = values[i].length() / fft_size
	return result


func _fft(values: Array[Vector2]) -> void:
	var count := values.size()
	var j := 0
	for i in range(1, count):
		var bit := count >> 1
		while j & bit:
			j ^= bit
			bit >>= 1
		j ^= bit
		if i < j:
			var temporary := values[i]
			values[i] = values[j]
			values[j] = temporary
	var length := 2
	while length <= count:
		var angle := -TAU / length
		var root := Vector2(cos(angle), sin(angle))
		for start in range(0, count, length):
			var factor := Vector2(1.0, 0.0)
			for offset in length / 2:
				var even := values[start + offset]
				var odd := _complex_multiply(values[start + offset + length / 2], factor)
				values[start + offset] = even + odd
				values[start + offset + length / 2] = even - odd
				factor = _complex_multiply(factor, root)
		length *= 2


func _complex_multiply(a: Vector2, b: Vector2) -> Vector2:
	return Vector2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x)


func _envelope_loss(target: PackedFloat32Array, candidate: PackedFloat32Array, bins: int) -> float:
	var target_envelope := _rms_bins(target, bins)
	var candidate_envelope := _rms_bins(candidate, bins)
	var sum := 0.0
	for i in bins:
		var difference := sqrt(target_envelope[i]) - sqrt(candidate_envelope[i])
		sum += difference * difference
	return sqrt(sum / bins)


func _rms_bins(samples: PackedFloat32Array, bins: int) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(bins)
	for bin in bins:
		var first := int(float(bin) / bins * samples.size())
		var last := maxi(first + 1, int(float(bin + 1) / bins * samples.size()))
		var sum := 0.0
		for i in range(first, mini(last, samples.size())):
			sum += samples[i] * samples[i]
		result[bin] = sqrt(sum / maxf(1.0, last - first))
	return result


func _waveform_loss(target: PackedFloat32Array, candidate: PackedFloat32Array) -> float:
	var dot := 0.0
	var target_energy := 0.000001
	var candidate_energy := 0.000001
	for i in mini(target.size(), candidate.size()):
		dot += target[i] * candidate[i]
		target_energy += target[i] * target[i]
		candidate_energy += candidate[i] * candidate[i]
	return 1.0 - absf(dot / sqrt(target_energy * candidate_energy))


func _best_lag(target: PackedFloat32Array, candidate: PackedFloat32Array, maximum: int) -> int:
	var best_lag := 0
	var best_correlation := -INF
	var stride := 8
	# Anchor the coarse grid at zero, then refine sample-by-sample. Starting the
	# range at an arbitrary negative maximum can accidentally omit zero entirely.
	var coarse_start := -maximum + (maximum % 4)
	for lag in range(coarse_start, maximum + 1, 4):
		var correlation := _lag_correlation(target, candidate, lag, stride)
		if correlation > best_correlation:
			best_correlation = correlation
			best_lag = lag
	var coarse_best := best_lag
	for lag in range(coarse_best - 4, coarse_best + 5):
		if lag < -maximum or lag > maximum:
			continue
		var correlation := _lag_correlation(target, candidate, lag, stride)
		if correlation > best_correlation:
			best_correlation = correlation
			best_lag = lag
	return best_lag


func _lag_correlation(target: PackedFloat32Array, candidate: PackedFloat32Array, lag: int, stride: int) -> float:
	var dot := 0.0
	var target_energy := 0.000001
	var candidate_energy := 0.000001
	for i in range(0, target.size(), stride):
		var candidate_index := i + lag
		if candidate_index < 0 or candidate_index >= candidate.size():
			continue
		dot += target[i] * candidate[candidate_index]
		target_energy += target[i] * target[i]
		candidate_energy += candidate[candidate_index] * candidate[candidate_index]
	return absf(dot / sqrt(target_energy * candidate_energy))


func _align(source: PackedFloat32Array, lag: int, size: int) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(size)
	for i in size:
		var source_index := i + lag
		if source_index >= 0 and source_index < source.size():
			result[i] = source[source_index]
	return result


func _score(loss: float, calibration: float) -> float:
	return 100.0 * exp(-loss / maxf(0.000001, calibration))


func _scaled(source: PackedFloat32Array, gain: float) -> PackedFloat32Array:
	var result := source.duplicate()
	for i in result.size():
		result[i] *= gain
	return result


func _padded(source: PackedFloat32Array, count: int) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(source.size() + count)
	for i in source.size():
		result[i + count] = source[i]
	return result


func _prepare(input: Dictionary) -> PackedFloat32Array:
	var source: PackedFloat32Array = input.samples
	var source_rate: int = input.sample_rate
	if source_rate == SAMPLE_RATE:
		return _trim(source)
	var count := int(ceil(float(source.size()) * SAMPLE_RATE / source_rate))
	var result := PackedFloat32Array()
	result.resize(count)
	for i in count:
		var position := float(i) * source_rate / SAMPLE_RATE
		var low := mini(int(position), source.size() - 1)
		var high := mini(low + 1, source.size() - 1)
		result[i] = lerpf(source[low], source[high], position - low)
	return _trim(result)


func _trim(source: PackedFloat32Array) -> PackedFloat32Array:
	if source.is_empty():
		return source
	var peak := 0.000001
	for value in source:
		peak = maxf(peak, absf(value))
	var threshold := peak * 0.006
	var first := 0
	var last := source.size() - 1
	while first < source.size() and absf(source[first]) < threshold:
		first += 1
	while last > first and absf(source[last]) < threshold:
		last -= 1
	return source.slice(first, last + 1)


func _normalize(source: PackedFloat32Array) -> PackedFloat32Array:
	var result := source.duplicate()
	var energy := 0.000001
	for value in result:
		energy += value * value
	var rms := sqrt(energy / maxf(1.0, result.size()))
	for i in result.size():
		result[i] /= rms
	return result


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
