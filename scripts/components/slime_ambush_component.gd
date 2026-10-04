extends Node
class_name SlimeAmbushComponent

var active := false
var hidden := false
var reveal_timer := 0.0
## Editor-facing defaults used when configure() does not supply explicit values.
@export var default_reveal_window := 0.5
@export var default_block_stun := 1.0
@export var default_hit_extension := 0.5
@export var hidden_modulate := Color(0.55, 0.55, 0.62, 0.5)

var reveal_window := 0.5
var block_stun := 1.0
var hit_extension := 0.5


func configure(active_value: bool, reveal_window_value: float = -1.0, block_stun_value: float = -1.0, hit_extension_value: float = -1.0) -> void:
	active = active_value
	reveal_window = maxf(default_reveal_window if reveal_window_value < 0.0 else reveal_window_value, 0.0)
	block_stun = maxf(default_block_stun if block_stun_value < 0.0 else block_stun_value, 0.0)
	hit_extension = maxf(default_hit_extension if hit_extension_value < 0.0 else hit_extension_value, 0.0)


func is_hidden() -> bool:
	return active and hidden


func apply_hidden(actor: Sprite2D) -> void:
	hidden = true
	reveal_timer = 0.0
	actor.self_modulate = hidden_modulate


func reveal(actor: Sprite2D) -> void:
	hidden = false
	actor.self_modulate = Color.WHITE


func begin_rehide(actor: Sprite2D, window: float) -> void:
	if not active or hidden:
		return
	reveal_timer = window
	actor.self_modulate = Color.WHITE


func begin_block_stun(actor: Sprite2D) -> void:
	if not active or hidden:
		return
	reveal_timer = block_stun
	actor.self_modulate = Color.WHITE


func extend_rehide(actor: Sprite2D, amount: float) -> void:
	if not active or hidden:
		return
	reveal_timer += amount
	actor.self_modulate = Color.WHITE


func tick(actor: Sprite2D, delta: float) -> void:
	if not active or hidden:
		return
	if reveal_timer > 0.0:
		reveal_timer = maxf(reveal_timer - delta, 0.0)
		if reveal_timer <= 0.0:
			apply_hidden(actor)