extends Node
class_name ActorCollisionSystem

## Contact-resolution boundary. Existing gameplay resolver remains authoritative
## until static-map and actor-contact parity is verified.

var actors: Array[Sprite2D] = []
@export var contact_distance := 64.0


func set_actors(new_actors: Array[Sprite2D]) -> void:
	actors = new_actors.duplicate()


func add_actor(actor: Sprite2D) -> void:
	if not actors.has(actor):
		actors.append(actor)


func remove_actor(actor: Sprite2D) -> void:
	actors.erase(actor)


func contacts_for(actor: Sprite2D) -> Array[Sprite2D]:
	var contacts: Array[Sprite2D] = []
	for other in actors:
		if other == actor or not is_instance_valid(other) or not other.visible:
			continue
		if actor.global_position.distance_to(other.global_position) <= contact_distance:
			contacts.append(other)
	return contacts
