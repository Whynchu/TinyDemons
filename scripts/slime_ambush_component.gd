extends Node
class_name SlimeAmbushComponent

var active := false
var hidden := false
var reveal_timer := 0.0
var reveal_window := 0.5
var block_stun := 1.0
var hit_extension := 0.5
var hidden_modulate := Color(0.55, 0.55, 0.62, 0.5)


func configure(active_value: bool, reveal_window_value: float, block_stun_value: float, hit_extension_value: float) -> void:
	active = active_value
	reveal_window = reveal_window_value
	block_stun = block_stun_value
	hit_extension = hit_extension_value


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