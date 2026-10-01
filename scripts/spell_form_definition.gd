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

enum ProjectileShape {
	ORB,
	SHARD,
	DROPLET,
	HEX,
}

@export var id: StringName = &""
@export_range(0, 7, 1) var native_element := 0
@export_enum("Projectile", "Projectile Splash", "Cone", "Instant Target", "Beam", "Radial Self") var delivery: int = Delivery.PROJECTILE
@export var chroma_cost := 10
@export var cooldown := 2.0
@export var damage_multiplier := 1.15
@export_enum("Orb", "Shard", "Droplet", "Hex Sigil") var projectile_shape: int = ProjectileShape.ORB
@export_range(1, 12, 1) var projectile_size := 4
@export_range(1.0, 240.0, 1.0) var projectile_speed := 70.0
@export_range(0.05, 5.0, 0.05) var projectile_lifetime := 0.6
@export_range(0.0, 0.5, 0.01) var projectile_minimum_travel_time := 0.0
@export_range(0.0, 128.0, 1.0) var delivery_radius := 0.0
@export_range(0.0, 1.0, 0.05) var splash_secondary_damage_ratio := 0.5
@export_range(0.0, 180.0, 1.0) var delivery_angle_degrees := 90.0
@export_range(0.0, 256.0, 1.0) var delivery_range := 64.0
@export_range(0.05, 10.0, 0.05) var delivery_duration := 1.8
@export_range(0.05, 5.0, 0.05) var tick_interval := 0.45
@export_range(0.0, 1.0, 0.01) var lifesteal_ratio := 0.0
@export_range(0.0, 2.0, 0.01) var knockback_multiplier := 0.25
@export_range(0.05, 30.0, 0.05) var mark_duration := 3.0
@export_range(1.0, 3.0, 0.01) var mark_damage_multiplier := 1.0
