extends RefCounted
class_name HubTransactionMenuContext

var profile: PlayerProfile
var catalog: ItemCatalog
var items: Array[ItemInstance] = []
var prices: Array[String] = []
var soul_values: Array[int] = []
var sold_flags: Array[bool] = []
var item_slots: Array[StringName] = []
var sell_owned_counts: Array[int] = []
var state := 0
var sell_mode := false
var selected_index := 0
var scroll := 0.0
var owned_count := 0
var max_quantity := 1
var quantity := 1
var batch_value: Dictionary = {}

var fusion_candidates: Array[ItemInstance] = []
var fusion_state := 0
var fusion_item_selected := false
var fusion_target_instance_id := ""
var fusion_count := 1
var fusion_message := ""
var fusion_details: Dictionary = {}
