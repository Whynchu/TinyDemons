extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for Chroma ownership characterization", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	get_root().add_child(gameplay)
	for _frame in 30:
		await process_frame
	var chroma := gameplay.get("player_chroma_component") as Node
	var ability := gameplay.get("player_aspect_ability_component") as Node
	var projectile_controller := gameplay.get_node_or_null("MagicProjectileController") as Node
	var pickup_controller := gameplay.get_node_or_null("ChromaPickupController") as Node
	_expect(chroma != null, "player Chroma component is installed", failures)
	_expect(ability != null, "aspect ability component is installed", failures)
	_expect(projectile_controller != null, "projectile lifecycle owner is installed", failures)
	_expect(pickup_controller != null, "Chroma pickup lifecycle owner is installed", failures)
	if chroma != null:
		_expect(int(chroma.get("current_chroma")) == 0, "new runtime starts at zero Chroma", failures)
		_expect(int(chroma.call("ability_mode")) == 0, "new runtime resolves the Gray ability mode", failures)
	_expect(gameplay.get("player_mp") == null, "coordinator no longer mirrors MP state", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("CHROMA_PROJECTILE_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
