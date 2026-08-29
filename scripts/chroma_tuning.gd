extends Resource
class_name ChromaTuning

## First-pass runtime tuning for neutral Chroma drops.
## These values are intentionally conservative until the authored tutorial and
## enemy encounter pacing are playable end-to-end.
@export var pickup_value := 20
@export_range(0.0, 1.0, 0.01) var enemy_drop_chance := 0.35
@export var pickup_collection_distance := 10.0
@export var pickup_air_time := 0.38
@export var pickup_launch_speed := 18.0
@export var pickup_launch_spread := 10.0
