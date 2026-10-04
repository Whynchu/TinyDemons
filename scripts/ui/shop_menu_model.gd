extends RefCounted
class_name ShopMenuModel

var state := 0
var sell_mode := false
var selected_row := 0
var row_labels: Array[String] = []
var row_colors: Array[Color] = []
var row_prices: Array[String] = []
var row_soul_values: Array[int] = []
var row_slots: Array[StringName] = []
var stat_comparison: Array[Dictionary] = []
var owned_count := 0
var quantity := 1
var max_quantity := 1
var scroll_fraction := 0.0
