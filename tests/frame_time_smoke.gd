extends SceneTree

const WARMUP_FRAMES := 60
const SAMPLE_FRAMES := 180


func _initialize() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("FRAME_TIME_SAMPLE_FAILED: main scene did not load")
		quit(1)
		return
	var gameplay := packed.instantiate()
	get_root().add_child(gameplay)
	for _frame in WARMUP_FRAMES:
		await process_frame
	var samples: Array[float] = []
	for _frame in SAMPLE_FRAMES:
		var started_usec := Time.get_ticks_usec()
		await process_frame
		samples.append(float(Time.get_ticks_usec() - started_usec) / 1000.0)
	var total_ms := 0.0
	var worst_ms := 0.0
	for sample_ms in samples:
		total_ms += sample_ms
		worst_ms = maxf(worst_ms, sample_ms)
	var average_ms := total_ms / float(samples.size())
	print("FRAME_TIME_SAMPLE_OK avg_ms=%.3f worst_ms=%.3f frames=%d warmup=%d" % [average_ms, worst_ms, SAMPLE_FRAMES, WARMUP_FRAMES])
	gameplay.queue_free()
	await process_frame
	quit(0)
