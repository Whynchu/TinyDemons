@tool
extends ColorRect

const EffectsSpawnerScript = preload("res://scripts/effects_spawner.gd")

const PAGE_TITLES := {
	"HubRootPage/Title": "DEMON HUB",
	"HubAllocatePage/Title": "STATS",
	"HubItemsPage/Title": "SHOP",
	"HubBindPage/Title": "BIND",
}

const PREVIEW_TEXT := {
	"HubPreviewCommandStats": ["STATS", Vector2(99, 8), Color.WHITE],
	"HubPreviewCommandShop": ["SHOP", Vector2(132, 8), Color.WHITE],
	"HubPreviewCommandFusion": ["FUSION", Vector2(166, 8), Color.WHITE],
	"HubPreviewCommandBind": ["BIND", Vector2(202, 8), Color.WHITE],
	"HubPreviewPoints": ["POINTS 2", Vector2(5, 27), Color8(255, 205, 117)],
	"HubPreviewVit": ["VIT  15", Vector2(63, 44), Color.WHITE],
	"HubPreviewStr": ["STR  12", Vector2(63, 54), Color.WHITE],
	"HubPreviewDef": ["DEF   8", Vector2(63, 64), Color.WHITE],
	"HubPreviewAgi": ["AGI   7", Vector2(63, 74), Color.WHITE],
	"HubPreviewInt": ["INT   6", Vector2(63, 84), Color.WHITE],
	"HubPreviewMnd": ["MND   5", Vector2(63, 94), Color.WHITE],
	"HubPreviewDerivedHp": ["HP       58", Vector2(142, 44), Color8(56, 183, 100)],
	"HubPreviewDerivedAtk": ["P ATK     9", Vector2(142, 54), Color.WHITE],
	"HubPreviewDerivedMatk": ["M ATK     5", Vector2(142, 64), Color.WHITE],
	"HubPreviewDerivedPdef": ["P DEF     5", Vector2(142, 74), Color.WHITE],
	"HubPreviewDerivedMdef": ["M DEF     5", Vector2(142, 84), Color.WHITE],
	"HubPreviewDerivedSpd": ["SPD      1.05", Vector2(142, 94), Color.WHITE],
	"HubPreviewDerivedRec": ["REC      1.03", Vector2(142, 104), Color.WHITE],
	"HubPreviewFooter": ["APPLY    CLEAR    AUTO     RESPEC 50", Vector2(44, 120), Color.WHITE],
	"HubPreviewPrompt": ["○ SELECT   × BACK", Vector2(108, 145), Color8(234, 122, 197)],
}


func _ready() -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	var renderer := EffectsSpawnerScript.new()
	for node_path: String in PAGE_TITLES:
		var title := get_node_or_null(node_path) as Sprite2D
		if title != null:
			title.texture = renderer.call("number_texture", PAGE_TITLES[node_path], Color.WHITE) as Texture2D
	# Runtime creates these sprites from the controller because their textures
	# depend on the player's profile. The editor preview mirrors the authored
	# 240x160 render so opening demon_hub_menu.tscn never shows blank panels.
	var root_page := get_node_or_null("HubRootPage") as Control
	if root_page != null:
		for child_name in ["TitleTab", "TitleRule"]:
			var chrome := root_page.get_node_or_null(child_name) as CanvasItem
			if chrome != null: chrome.visible = false
	for preview_name: String in PREVIEW_TEXT:
		var data: Array = PREVIEW_TEXT[preview_name]
		var sprite := get_node_or_null(preview_name) as Sprite2D
		var created := false
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.name = preview_name
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(sprite)
			created = true
		# Persistent .tscn nodes keep their authored position. Defaults are only
		# applied to a newly-created fallback, so dragging a piece in Godot sticks.
		if created:
			sprite.position = data[1] as Vector2
		sprite.texture = renderer.call("number_texture", str(data[0]), data[2] as Color) as Texture2D
	renderer.free()
