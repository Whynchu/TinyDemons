extends RefCounted
class_name HubItemVisibilityContext

## Carries the mutable page, focus, selection, and profile state for legacy Hub widget visibility.
var profile: PlayerProfile
var page := 0
var content_focus := false
var is_root := true
var equipment_action_focus := false
var gear_browsing := false
var item_index := 0
var action_column := 0
var shop_command_focus := false
var highlight_color := Color.WHITE
