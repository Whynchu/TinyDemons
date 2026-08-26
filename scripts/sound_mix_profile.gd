@tool
class_name SoundMixProfile
extends Resource

## Editor-facing per-cue mix trims.
##
## Select `assets/sounds/sound_mix_profile.tres` in the FileSystem dock. Every
## value below is an inspector slider with a dB suffix. These values are added
## to the event-specific level passed by gameplay, so a cue can still have a
## deliberately softer variation without losing a single central adjustment.
## With the game running, save the resource after changing a slider (`Ctrl+S`)
## and the active mix refreshes automatically within a fraction of a second.

const VOLUME_PROPERTY_BY_KEY: Dictionary = {
	&"title_music": &"title_music_db",
	&"run_music": &"run_music_db",
	&"chatter": &"chatter_db",
	&"slash": &"slash_db",
	&"miss": &"miss_db",
	&"flesh": &"flesh_db",
	&"bite": &"bite_db",
	&"block": &"block_db",
	&"flee": &"flee_db",
	&"enemy_death": &"enemy_death_db",
	&"impact_flesh": &"impact_flesh_db",
	&"encounter": &"encounter_db",
	&"claw": &"claw_db",
	&"magic_cast": &"magic_cast_db",
	&"magic_hit": &"magic_hit_db",
	&"ui_hover": &"ui_hover_db",
	&"ui_confirm": &"ui_confirm_db",
	&"ui_decline": &"ui_decline_db",
	&"ui_denied": &"ui_denied_db",
	&"ui_use_item": &"ui_use_item_db",
	&"ui_equip": &"ui_equip_db",
	&"ui_unequip": &"ui_unequip_db",
	&"ui_buy_sell": &"ui_buy_sell_db",
	&"ui_pause": &"ui_pause_db",
	&"ui_unpause": &"ui_unpause_db",
	&"enemy_alert": &"enemy_alert_db",
	&"item_pickup": &"item_pickup_db",
	&"chest_unlock": &"chest_unlock_db",
	&"chest_reward": &"chest_reward_db",
	&"run_clear": &"run_clear_db",
	&"level_up": &"level_up_db",
	&"enemy_hit_1": &"enemy_hit_1_db",
	&"enemy_hit_2": &"enemy_hit_2_db",
	&"enemy_hit_3": &"enemy_hit_3_db",
	&"enemy_hit_4": &"enemy_hit_4_db",
	&"enemy_hit_5": &"enemy_hit_5_db",
	&"enemy_hit_6": &"enemy_hit_6_db",
	&"orb_hit": &"orb_hit_db",
	&"target_release": &"target_release_db",
	&"foot_left": &"foot_left_db",
	&"foot_right": &"foot_right_db",
}

@export_category("Music")
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var title_music_db := -16.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var run_music_db := -10.0

@export_category("Procedural")
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var chatter_db := 0.0

@export_category("Combat")
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var slash_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var miss_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var flesh_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var bite_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var block_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var flee_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var enemy_death_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var impact_flesh_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var encounter_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var claw_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var magic_cast_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var magic_hit_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var enemy_alert_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var enemy_hit_1_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var enemy_hit_2_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var enemy_hit_3_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var enemy_hit_4_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var enemy_hit_5_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var enemy_hit_6_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var orb_hit_db := 0.0

@export_category("UI and Items")
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var ui_hover_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var ui_confirm_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var ui_decline_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var ui_denied_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var ui_use_item_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var ui_equip_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var ui_unequip_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var ui_buy_sell_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var ui_pause_db := -8.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var ui_unpause_db := -6.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var item_pickup_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var chest_unlock_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var chest_reward_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var run_clear_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var level_up_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var target_release_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var foot_left_db := 0.0
@export_range(-80.0, 6.0, 0.5, "suffix:dB") var foot_right_db := 0.0


func volume_db_for(sound_name: StringName, fallback_db: float = 0.0) -> float:
	var property_name: StringName = VOLUME_PROPERTY_BY_KEY.get(sound_name, &"")
	if property_name.is_empty():
		return fallback_db
	return float(get(property_name))


func has_volume_entry(sound_name: StringName) -> bool:
	return VOLUME_PROPERTY_BY_KEY.has(sound_name)


func value_signature() -> int:
	var values := PackedStringArray()
	for sound_name in VOLUME_PROPERTY_BY_KEY:
		values.append("%s=%s" % [sound_name, volume_db_for(sound_name)])
	return "|".join(values).hash()
