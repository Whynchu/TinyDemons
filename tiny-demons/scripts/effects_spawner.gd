extends Node
class_name EffectsSpawner

signal effect_requested(kind: StringName, position: Vector2)
var damage_number_texture_cache: Dictionary = {}
var pixel_particle_texture_cache: Dictionary = {}


func request_effect(kind: StringName, position: Vector2) -> void:
	effect_requested.emit(kind, position)
