extends RefCounted
class_name FeedbackAnimationRegistry

## Shared, frame-driven presentation timeline.
##
## Gameplay feedback must not create an independent process loop or a SceneTree
## tween that keeps running through hitstop and pause. Owners register a short
## deterministic entry and the gameplay frame controller advances it.

var _next_id := 1
var _entries: Array[Dictionary] = []


func register(owner: Object, duration: float, on_update: Callable, on_complete: Callable = Callable()) -> int:
	if owner == null or not is_instance_valid(owner) or not on_update.is_valid():
		return 0
	var id := _next_id
	_next_id += 1
	_entries.append({
		"id": id,
		"owner": owner,
		"duration": maxf(duration, 0.0001),
		"elapsed": 0.0,
		"on_update": on_update,
		"on_complete": on_complete,
	})
	return id


func tick(delta: float) -> void:
	if _entries.is_empty():
		return
	var step := maxf(delta, 0.0)
	for index in range(_entries.size() - 1, -1, -1):
		var entry := _entries[index] as Dictionary
		var id := int(entry.get("id", 0))
		var owner := entry.get("owner") as Object
		if owner == null or not is_instance_valid(owner):
			_remove_id(id)
			continue
		var duration := maxf(float(entry.get("duration", 0.0001)), 0.0001)
		var elapsed := minf(float(entry.get("elapsed", 0.0)) + step, duration)
		entry["elapsed"] = elapsed
		var progress := clampf(elapsed / duration, 0.0, 1.0)
		var on_update: Callable = entry.get("on_update", Callable())
		if on_update.is_valid():
			on_update.call(progress)
		if _index_for(id) < 0:
			continue
		if progress < 1.0:
			var current_index := _index_for(id)
			if current_index >= 0:
				_entries[current_index] = entry
			continue
		var on_complete: Callable = entry.get("on_complete", Callable())
		_remove_id(id)
		if on_complete.is_valid():
			on_complete.call()


func finish(id: int) -> void:
	var index := _index_for(id)
	if index < 0:
		return
	var entry := _entries[index] as Dictionary
	_entries.remove_at(index)
	var owner := entry.get("owner") as Object
	if owner != null and is_instance_valid(owner):
		var on_update: Callable = entry.get("on_update", Callable())
		if on_update.is_valid():
			on_update.call(1.0)
		var on_complete: Callable = entry.get("on_complete", Callable())
		if on_complete.is_valid():
			on_complete.call()


func cancel(id: int) -> void:
	var index := _index_for(id)
	if index >= 0:
		_entries.remove_at(index)


func active_count() -> int:
	return _entries.size()


func _index_for(id: int) -> int:
	for index in _entries.size():
		if int((_entries[index] as Dictionary).get("id", 0)) == id:
			return index
	return -1


func _remove_id(id: int) -> void:
	var index := _index_for(id)
	if index >= 0:
		_entries.remove_at(index)
