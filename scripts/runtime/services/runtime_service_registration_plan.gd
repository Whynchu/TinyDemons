extends RefCounted
class_name RuntimeServiceRegistrationPlan

## GameplayBootstrap-owned declarations and validation for ordered runtime services.
class Row:
	extends RefCounted

	var node_name: StringName
	var service_script: Script
	var parent: Node
	var dependencies: Array[StringName] = []
	var configure_callable: Callable

	func _init(
		registered_name: StringName,
		registered_script: Script,
		registered_parent: Node,
		registered_dependencies: Array[StringName] = [],
		registered_configure_callable: Callable = Callable()
	) -> void:
		node_name = registered_name
		service_script = registered_script
		parent = registered_parent
		dependencies = registered_dependencies.duplicate()
		configure_callable = registered_configure_callable


## This bounded cohort proves that actual registrations can be checked as rows.
## Configuration remains at the call site so its existing typed setup order is
## visible and unchanged.
static func early_service_registrations(root: Node) -> Array[Row]:
	var registrations: Array[Row] = []
	registrations.append(Row.new(&"SettingsService", SettingsService, root))
	registrations.append(Row.new(&"DisplayController", DisplayController, root, [&"SettingsService"]))
	registrations.append(Row.new(&"InputRouter", InputRouter, root))
	registrations.append(Row.new(&"InputDeviceTracker", preload("res://scripts/services/input_device_tracker.gd"), root))
	registrations.append(Row.new(&"TouchControlsLayer", preload("res://scripts/ui/touch_controls_layer.gd"), root, [&"InputRouter", &"InputDeviceTracker"]))
	registrations.append(Row.new(&"DebugSessionController", DebugSessionController, root))
	return registrations


static func row_for(registrations: Array[Row], node_name: StringName) -> Row:
	for registration in registrations:
		if registration.node_name == node_name:
			return registration
	return null


## Instantiates each validated row in order, running its optional setup callback
## before creating the next sibling so setup-sensitive boot order is preserved.
static func register_all(registrations: Array[Row]) -> Array[String]:
	var errors := registration_errors(registrations)
	if not errors.is_empty():
		return errors
	for registration in registrations:
		var node := registration.service_script.new() as Node
		if node == null:
			errors.append("%s script did not instantiate a Node" % registration.node_name)
			return errors
		node.name = registration.node_name
		registration.parent.add_child(node)
		if registration.configure_callable.is_valid():
			registration.configure_callable.call(node)
	return live_registration_errors(registrations)


## Rejects incomplete, duplicate, or forward references in the declared rows.
static func registration_errors(registrations: Array[Row]) -> Array[String]:
	var errors: Array[String] = []
	var positions: Dictionary = {}
	for index in registrations.size():
		var registration := registrations[index]
		if registration.node_name.is_empty():
			errors.append("service row %d has an empty name" % index)
			continue
		if positions.has(registration.node_name):
			errors.append("duplicate service %s" % registration.node_name)
		else:
			positions[registration.node_name] = index
		if registration.service_script == null:
			errors.append("service %s has no script" % registration.node_name)
		if registration.parent == null:
			errors.append("service %s has no parent" % registration.node_name)
	for index in registrations.size():
		var registration := registrations[index]
		var seen_dependencies: Dictionary = {}
		for dependency: StringName in registration.dependencies:
			if seen_dependencies.has(dependency):
				errors.append("%s repeats dependency %s" % [registration.node_name, dependency])
				continue
			seen_dependencies[dependency] = true
			if not positions.has(dependency):
				errors.append("%s requires missing service %s" % [registration.node_name, dependency])
			elif int(positions[dependency]) >= index:
				errors.append("%s requires %s to be registered earlier" % [registration.node_name, dependency])
	return errors


## Checks row metadata against live nodes, parents, scripts, and prerequisite
## order after the cohort has been attached to the scene tree.
static func live_registration_errors(registrations: Array[Row]) -> Array[String]:
	var errors := registration_errors(registrations)
	if not errors.is_empty():
		return errors
	var live_nodes: Dictionary = {}
	for registration in registrations:
		var node := registration.parent.get_node_or_null(NodePath(String(registration.node_name)))
		if node == null:
			errors.append("%s is not registered under its declared parent" % registration.node_name)
			continue
		if node.get_parent() != registration.parent:
			errors.append("%s has an unexpected parent" % registration.node_name)
		if node.get_script() != registration.service_script:
			errors.append("%s has an unexpected script" % registration.node_name)
		live_nodes[registration.node_name] = node
	for registration in registrations:
		if not live_nodes.has(registration.node_name):
			continue
		var node := live_nodes[registration.node_name] as Node
		for dependency: StringName in registration.dependencies:
			if not live_nodes.has(dependency):
				continue
			var dependency_row := row_for(registrations, dependency)
			if dependency_row.parent != registration.parent:
				errors.append("%s and prerequisite %s must share a parent for ordered registration" % [registration.node_name, dependency])
				continue
			var dependency_node := live_nodes[dependency] as Node
			if dependency_node.get_index() >= node.get_index():
				errors.append("%s was registered before prerequisite %s" % [registration.node_name, dependency])
	return errors
