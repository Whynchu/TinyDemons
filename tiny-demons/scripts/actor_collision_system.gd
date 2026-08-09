extends Node
class_name ActorCollisionSystem

## Contact-resolution boundary. Existing gameplay resolver remains authoritative
## until static-map and actor-contact parity is verified.

var actors: Array[Sprite2D] = []


func set_actors(new_actors: Array[Sprite2D]) -> void:
	actors = new_actors.duplicate()


func add_actor(actor: Sprite2D) -> void:
	if not actors.has(actor):
		actors.append(actor)


func remove_actor(actor: Sprite2D) -> void:
	actors.erase(actor)
