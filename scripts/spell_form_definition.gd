@tool
extends Resource

enum Delivery {
	PROJECTILE,
	PROJECTILE_SPLASH,
	CONE,
	INSTANT_TARGET,
	BEAM,
	RADIAL_SELF,
}

@export var id: StringName = &""
@export_range(0, 7, 1) var native_element := 0
@export_enum("Projectile", "Projectile Splash", "Cone", "Instant Target", "Beam", "Radial Self") var delivery: int = Delivery.PROJECTILE
@export var chroma_cost := 10
@export var cooldown := 2.0
@export var damage_multiplier := 1.15
