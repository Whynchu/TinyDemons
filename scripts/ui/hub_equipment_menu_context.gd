extends RefCounted
class_name HubEquipmentMenuContext

## Typed inputs shared by the Hub and Pause Equipment render paths.

var view: EquipmentMenuLayout = null
var menu_state: HubMenuState = null
var profile: PlayerProfile = null
var pixel_texture: Callable = Callable()
var navigation_texture: Texture2D = null
var portrait_texture: Texture2D = null
var stat_snapshot: CombatStatSnapshot = null
var player_stats: StatsComponent = null
var selected_slot_candidates: Array[ItemInstance] = []
var legacy_slot_texts: Array[Sprite2D] = []
var legacy_candidate_texts: Array[Sprite2D] = []
var read_only := false
var show_navigation := false
