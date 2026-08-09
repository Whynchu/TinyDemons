extends Node
class_name ChestController

signal unlocked
signal reward_claimed

var unlocked_state := false
var claimed := false


func unlock() -> void:
	if not unlocked_state:
		unlocked_state = true
		unlocked.emit()


func claim_reward() -> void:
	if unlocked_state and not claimed:
		claimed = true
		reward_claimed.emit()
