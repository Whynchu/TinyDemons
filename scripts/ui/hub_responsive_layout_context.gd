extends RefCounted
class_name HubResponsiveLayoutContext

var overlay: ColorRect = null
var view_size := Vector2.ZERO
var page := 0
var content_focus := false
var stat_row := 0
var action_column := 0
var gear_browsing := false
var menu_row := 0
var is_root := true
var animate_cursor := false
var preserve_cursor_motion := false
var pages: HubPageVisibilityPresenter
var stats: HubStatsScreenPresenter
var commands: HubCommandShellPresenter
var cursor_animator: MenuCursorAnimator
var tween_owner: Node
