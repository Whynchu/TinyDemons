extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/boss_room_debug.tscn") as PackedScene
	_expect(packed != null, "boss debug scene loads", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	get_root().add_child(gameplay)
	for _frame in 90:
		await process_frame
	var slimes := gameplay.get("slimes") as Array[Sprite2D]
	var boss: Sprite2D = null
	for slime in slimes:
		if float(slime.get_meta("encounter_scale", 1.0)) > 1.0:
			boss = slime
			break
	_expect(boss != null, "boss room creates a scaled boss", failures)
	if boss != null:
		var sprite_rect: Rect2 = gameplay.call("_sprite_source_global_rect", boss)
		var collision_rect: Rect2 = gameplay.call("_collision_rect", boss)
		var body := gameplay.call("_slime_body_polygon", boss) as PackedVector2Array
		var body_rect := _bounds(body)
		var raw_guide := ActorGeometry.guide_rect(boss, "CollisionGuide")
		_expect(sprite_rect.intersects(body_rect), "boss body overlaps rendered sprite", failures)
		_expect(sprite_rect.encloses(collision_rect), "boss collision guide stays inside rendered sprite", failures)
		_expect(collision_rect.get_center().distance_to(raw_guide.get_center()) > 5.0, "boss guide receives foot compensation", failures)
		var combat_target: Vector2 = gameplay.call("_magic_target_point", boss)
		_expect(Geometry2D.is_point_in_polygon(combat_target, body), "boss combat target stays inside authored body", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var result := Rect2(points[0], Vector2.ZERO)
	for point in points:
		result = result.expand(point)
	return result


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("BOSS_GEOMETRY_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
