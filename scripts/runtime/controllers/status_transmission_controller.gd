extends RefCounted
class_name StatusTransmissionController

const StatusApplicationRequestScript = preload("res://scripts/content/status_application_request.gd")
const PAIR_COOLDOWN := 3.0

var _pair_cooldowns: Dictionary[String, float] = {}
var _room_key: StringName = &""


func reset_for_room(room_key: StringName) -> void:
	if room_key == _room_key:
		return
	_room_key = room_key
	_pair_cooldowns.clear()


func process_contacts(
	contacts: Array[StatusContactPair],
	delta: float,
	room_key: StringName,
	random_source: RandomNumberGenerator
) -> void:
	reset_for_room(room_key)
	_advance_cooldowns(delta)
	if random_source == null:
		return

	# Snapshot every source before applying any transfer. Contacts share this map,
	# so a status received from one actor cannot continue along another pair.
	var source_records: Dictionary[int, Array] = {}
	for contact in contacts:
		if contact == null or not _actor_is_eligible(contact.first) or not _actor_is_eligible(contact.second):
			continue
		for actor in [contact.first, contact.second]:
			var actor_id: int = int(actor.get_instance_id())
			if source_records.has(actor_id):
				continue
			var component := actor.get_node_or_null("Status") as StatusComponent
			var payloads: Array[Dictionary] = []
			if component != null:
				for record in component.transmissible_records():
					payloads.append({
						"definition": record.definition,
						"source_element": record.source_element,
					})
			source_records[actor_id] = payloads

	for contact in contacts:
		if contact == null or not _actor_is_eligible(contact.first) or not _actor_is_eligible(contact.second):
			continue
		var first_records: Array = source_records.get(contact.first.get_instance_id(), [])
		var second_records: Array = source_records.get(contact.second.get_instance_id(), [])
		if first_records.is_empty() and second_records.is_empty():
			continue
		var pair_key := _pair_key(contact.first, contact.second)
		if _pair_cooldowns.has(pair_key):
			continue
		# Cool down the unordered pair even when immunity or a special defense
		# rejects the batch; repeated frame contacts must not reapply it.
		_pair_cooldowns[pair_key] = PAIR_COOLDOWN
		_transfer_records(contact.first, contact.second, first_records, random_source)
		_transfer_records(contact.second, contact.first, second_records, random_source)


func _transfer_records(source_actor: Sprite2D, target_actor: Sprite2D, payloads: Array, random_source: RandomNumberGenerator) -> void:
	if payloads.is_empty():
		return
	for value: Variant in payloads:
		if not value is Dictionary:
			continue
		var payload := value as Dictionary
		var definition := payload.get("definition") as StatusEffectDefinition
		var source_element := int(payload.get("source_element", ElementCatalog.Element.NEUTRAL))
		if definition == null or source_element == ElementCatalog.Element.NEUTRAL:
			continue
		var request := StatusApplicationRequestScript.new() as StatusApplicationRequest
		request.configure_transmission(target_actor, definition, source_element, source_actor, random_source)
		StatusApplication.apply(request)


func _actor_is_eligible(actor: Sprite2D) -> bool:
	if actor == null or not is_instance_valid(actor) or not actor.visible or not actor.is_visible_in_tree():
		return false
	if bool(actor.get_meta("boss_airborne", false)):
		return false
	if actor is SlimeActor and (actor as SlimeActor).is_spawn_locked():
		return false
	var spawn := actor.get_node_or_null("Spawn")
	if spawn != null and bool(spawn.call("is_active")):
		return false
	var health := actor.get_node_or_null("Health") as HealthComponent
	if health != null and health.is_dead():
		return false
	var combat := actor.get_node_or_null("Combat") as SlimeCombatComponent
	return combat == null or not combat.dead


func _pair_key(first: Sprite2D, second: Sprite2D) -> String:
	var first_identity := _actor_identity(first)
	var second_identity := _actor_identity(second)
	if first_identity > second_identity:
		var swap := first_identity
		first_identity = second_identity
		second_identity = swap
	return "%s|%s" % [first_identity, second_identity]


func _actor_identity(actor: Sprite2D) -> String:
	return "%d:%d" % [actor.get_instance_id(), int(actor.get_meta("status_spawn_generation", 0))]


func _advance_cooldowns(delta: float) -> void:
	var step := maxf(delta, 0.0)
	for key: String in _pair_cooldowns.keys():
		var remaining := float(_pair_cooldowns[key]) - step
		if remaining <= 0.0:
			_pair_cooldowns.erase(key)
		else:
			_pair_cooldowns[key] = remaining
