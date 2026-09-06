extends RefCounted
class_name FusionMenuModel

var state := 0
var rows: Array[Dictionary] = []
var selected_row := 0
var item_selected := false
var scroll_fraction := 0.0
var stat_comparison: Array[Dictionary] = []
var owned_count := 0
var fusion_count := 1
var fusion_count_max := 1
var soul_cost := 0
var can_fuse := false
var can_salvage := false
var message := ""
