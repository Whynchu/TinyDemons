extends RefCounted

## Owns render-rate presentation work after the final physics step.
class_name GameplayPresentationRuntimeController

const MAP_LIGHTING_CONTROLLER_SCRIPT = preload("res://scripts/runtime/world/map_lighting_controller.gd")


static func present(root: GameplayState, delta: float) -> void:
	var screens := root.screen_state_controller as ScreenStateController
	if root.boot_active or root.loading_screen_active or (screens != null and screens.state != &"gameplay"):
		return
	var minimap := root.dungeon_minimap_controller as Node
	if minimap != null and bool(minimap.call("is_map_open")):
		return
	var run_complete_overlay := screens.run_complete_presenter.overlay if screens != null else null
	if run_complete_overlay != null and run_complete_overlay.visible:
		return
	# Catch-up steps may update HUD targets repeatedly; render only final values.
	root._update_mp_desaturation()
	root._update_player_health_ui(0.0)
	root._update_player_mp_ui(0.0)
	root._update_target_ui()
	var combat := root.combat_runtime_controller as CombatRuntimeController
	if combat != null:
		combat.update_enemy_health_presentation(root, delta)
	root._update_overworld_ui()
	root._update_depth_sorting()
	present_actor_status_auras(root)
	var actor_presentation := root.actor_presentation_runtime_controller as ActorPresentationRuntimeController
	if actor_presentation != null:
		for slime in root.slimes:
			if is_instance_valid(slime) and slime.visible and slime.is_visible_in_tree():
				actor_presentation.sync_slime_shadow(root, slime)
	root._update_actor_occlusion(delta)
	root._update_player_palette_flash(delta)
	root._update_player_shadow()
	root._update_cloaked_demon_shadow()
	if root.effects_spawner != null:
		root.effects_spawner.sync_status_particle_depths()
	MAP_LIGHTING_CONTROLLER_SCRIPT.refresh_for_actor(root.player)


static func present_actor_status_auras(root: GameplayState) -> void:
	if root.player != null and not root.player_dead and not root.player_death_pending:
		_present_actor_status_aura(root.player)
	for actor in root.slimes:
		if actor == null or not is_instance_valid(actor) or not actor.visible or not actor.is_visible_in_tree():
			continue
		if root.combat_runtime_controller.is_slime_dead(root, actor):
			continue
		_present_actor_status_aura(actor)


static func maintain_enemy_regen_lock(root: GameplayState, delta: float) -> void:
	for slime in root.slimes:
		if root.combat_runtime_controller.is_slime_dead(root, slime) or not root._is_slime_aggroed(slime):
			continue
		var health: HealthComponent = root._slime_health(slime) as HealthComponent
		if health != null:
			health.regen_delay_timer = maxf(health.regen_delay_timer, health.regen_interval + delta)


static func _present_actor_status_aura(actor: Sprite2D) -> void:
	var slime_actor := actor as SlimeActor
	var component: StatusComponent = slime_actor._status_component if slime_actor != null and is_instance_valid(slime_actor._status_component) else actor.get_node_or_null("Status") as StatusComponent
	if component == null:
		return
	var aura: ElementAuraComponent = slime_actor._aura_component if slime_actor != null and is_instance_valid(slime_actor._aura_component) else actor.get_node_or_null("ElementAura") as ElementAuraComponent
	if aura != null and is_instance_valid(aura):
		aura.present_status_aura()
