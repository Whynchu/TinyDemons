extends RefCounted
class_name MenuPlayerContext

const AspectCatalogScript = preload("res://scripts/aspect_catalog.gd")

## Read-only player presentation data for menu-owned player cards.
##
## Menus need a small view of the player, not the complete GameplayState root.
## The composition root assembles this snapshot at the menu boundary so the
## presenter can render it without discovering gameplay dependencies through
## root.get/call.

var profile: PlayerProfile = null
var snapshot: CombatStatSnapshot = null
var combat_tuning: CombatTuning = null
var progression_tuning: ProgressionTuning = null
var player_tuning: PlayerTuning = null
var health_component: HealthComponent = null
var chroma_component: PlayerChromaComponent = null
var palette_name: StringName = &"blue"
var portrait_provider: Callable = Callable()


func _init(
	new_profile: PlayerProfile,
	new_snapshot: CombatStatSnapshot,
	new_combat_tuning: CombatTuning,
	new_progression_tuning: ProgressionTuning,
	new_player_tuning: PlayerTuning,
	new_health_component: HealthComponent,
	new_chroma_component: PlayerChromaComponent,
	new_palette_name: StringName,
	new_portrait_provider: Callable = Callable()
) -> void:
	profile = new_profile
	snapshot = new_snapshot
	combat_tuning = new_combat_tuning
	progression_tuning = new_progression_tuning
	player_tuning = new_player_tuning
	health_component = new_health_component
	chroma_component = new_chroma_component
	palette_name = new_palette_name if not new_palette_name.is_empty() else &"blue"
	portrait_provider = new_portrait_provider


func is_valid() -> bool:
	return profile != null and snapshot != null


func max_health() -> int:
	if snapshot == null:
		return 0
	return roundi(CombatCalculator.max_health_for_snapshot(snapshot, combat_tuning))


func current_health() -> int:
	var maximum := max_health()
	if health_component == null:
		return maximum
	return roundi(clampf(health_component.current_health, 0.0, float(maximum)))


func chroma() -> int:
	return chroma_component.current_chroma if chroma_component != null else 0


func element_display_name() -> String:
	if chroma_component == null:
		return "NORMAL"
	return AspectCatalogScript.display_name(chroma_component.aspect_name())


func portrait_texture() -> Texture2D:
	if not portrait_provider.is_valid():
		return null
	return portrait_provider.call(String(palette_name)) as Texture2D
