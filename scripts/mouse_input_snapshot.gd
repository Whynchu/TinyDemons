extends RefCounted
class_name MouseInputSnapshot

## Typed mouse-only intent crossing the touch provider and gameplay input
## boundary. Physical mouse clicks and held buttons stay distinct from virtual
## touch actions.

var pointer_position := Vector2.ZERO
var has_pointer_position := false
var aim_active := false
var left_button_pressed := false
var left_click_just_pressed := false
var left_click_position := Vector2.ZERO
var right_button_pressed := false
var right_click_just_pressed := false
var right_click_position := Vector2.ZERO
var middle_button_pressed := false
var middle_click_just_pressed := false
var middle_click_position := Vector2.ZERO
