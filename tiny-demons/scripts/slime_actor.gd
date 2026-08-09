extends Node2D
class_name SlimeActor

@export_enum("blue", "green", "red") var variant := "green"
@export var tuning: SlimeTuning


func _ready() -> void:
	if tuning == null:
		tuning = SlimeTuning.new()
