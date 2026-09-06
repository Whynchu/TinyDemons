extends FusionMenuLayout

const EffectsSpawnerScript = preload("res://scripts/effects_spawner.gd")

func _ready() -> void:
	super._ready()
	var renderer := EffectsSpawnerScript.new()
	add_child(renderer)
	set_pixel_texture(Callable(renderer, "number_texture"))
	var model := FusionMenuModel.new()
	model.state = FUSION_TARGET
	model.selected_row = 1
	model.owned_count = 3
	model.fusion_count = 2
	model.fusion_count_max = 3
	model.rows = [
		{"label": "SWORD F2", "slot": "WPN", "color": Color8(255, 255, 255), "soul_cost": 12},
		{"label": "STAFF F1", "slot": "WPN", "color": Color8(180, 220, 255), "soul_cost": 18},
		{"label": "ARMOR F3", "slot": "ARM", "color": Color8(255, 205, 117), "soul_cost": 24},
	]
	model.stat_comparison = [
		{"label": "VIT", "before": 10, "after": 12, "after_color": Color8(150, 255, 180)},
		{"label": "STR", "before": 8, "after": 9, "after_color": Color8(150, 255, 180)},
		{"label": "DEF", "before": 7, "after": 7, "after_color": Color8(244, 244, 244)},
		{"label": "AGI", "before": 6, "after": 8, "after_color": Color8(150, 255, 180)},
		{"label": "INT", "before": 5, "after": 6, "after_color": Color8(150, 255, 180)},
		{"label": "MND", "before": 4, "after": 4, "after_color": Color8(244, 244, 244)},
	]
	sell_amount_changed.connect(_on_count_changed.bind(model))
	render_fusion(model)

func _on_count_changed(delta: int, model: FusionMenuModel) -> void:
	model.fusion_count = clampi(model.fusion_count + delta, 1, model.fusion_count_max)
	model.soul_cost = 24 * model.fusion_count
	render_fusion(model)
