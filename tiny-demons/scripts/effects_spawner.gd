extends Node
class_name EffectsSpawner

signal effect_requested(kind: StringName, position: Vector2)


func request_effect(kind: StringName, position: Vector2) -> void:
	effect_requested.emit(kind, position)
