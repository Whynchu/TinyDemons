extends Node
class_name EffectsSpawner

signal effect_requested(kind: StringName, position: Vector2)
var damage_number_texture_cache: Dictionary = {}
var pixel_particle_texture_cache: Dictionary = {}
var damage_numbers: Array[Dictionary] = []
var pixel_particles: Array[Dictionary] = []
var fire_spark_timer := 0.0
var fire_noise := FastNoiseLite.new()


func spawn_slime_death_from_root(root: Object, slime: Sprite2D) -> void:
	var tuning := root.get("effects_tuning") as EffectsTuning
	var occlusion := root.get("occlusion_renderer") as OcclusionRenderer
	var source_texture: Texture2D = occlusion.original_actor_textures.get(slime, slime.texture)
	spawn_slime_death_particles(root, source_texture, slime.global_position, int(round(root.call("_actor_foot", slime).y * root.get("DEPTH_Z_SCALE"))) + 1, tuning.slime_death_particle_count, tuning.slime_death_particle_speed_min, tuning.slime_death_particle_speed_max, tuning.slime_death_particle_lifetime, root.get("rng"), Callable(root, "_pixel_particle_texture"))


func spawn_gold_from_root(root: Object, world_position: Vector2, amount: int) -> void:
	var tuning := root.get("effects_tuning") as EffectsTuning; var sprite := Sprite2D.new(); sprite.texture = root.call("_pixel_number_texture", "+%d" % amount, Color8(255, 205, 117)); sprite.centered = false; sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; sprite.z_as_relative = false; sprite.z_index = int(root.get("OVERWORLD_UI_Z")) + 2; sprite.position = world_position; root.add_child(sprite); damage_numbers.append({"sprite": sprite, "timer": tuning.damage_number_lifetime})


func spawn_chest_evaporation_from_root(root: Object) -> void:
	var chest := root.get("chest") as Sprite2D; spawn_chest_evaporation_particles(root, chest.texture, chest.global_position, int(round(root.call("_depth_key", chest) * root.get("DEPTH_Z_SCALE"))) + 1, int(root.get("CHEST_EVAPORATE_PARTICLE_COUNT")), float(root.get("CHEST_EVAPORATE_LIFETIME_MIN")), float(root.get("CHEST_EVAPORATE_LIFETIME_MAX")), root.get("rng"), Callable(root, "_pixel_particle_texture"))


func update_pixel_particles_from_root(root: Object, delta: float) -> void:
	update_pixel_particles(delta, Callable(root, "_snap_half_pixel"), (root.get("effects_tuning") as EffectsTuning).slime_death_particle_lifetime)
	update_fire_sparks_from_root(root, delta)


func update_fire_sparks_from_root(root: Object, delta: float) -> void:
	var fire := root.get("rest_fire") as Sprite2D
	if fire == null or not fire.visible:
		fire_spark_timer = 0.0
		return
	fire_spark_timer -= delta
	if fire_spark_timer > 0.0:
		return
	fire_spark_timer = root.get("rng").randf_range(0.45, 1.05)
	fire_noise.seed = int(root.get("rng").randi())
	var noise_speed: float = fire_noise.get_noise_1d(float(Time.get_ticks_msec()) * 0.01)
	var origin := fire.global_position + Vector2(root.get("rng").randf_range(-4.0, 4.0), 1.0)
	var particle := Sprite2D.new()
	particle.name = "FireSpark"
	particle.texture = root.call("_pixel_particle_texture", Color.WHITE) as Texture2D
	particle.centered = false
	particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particle.z_as_relative = false
	particle.z_index = fire.z_index + 2
	particle.position = origin
	particle.modulate = Color8(214, 54, 42)
	root.add_child(particle)
	var lifetime: float = float(root.get("rng").randf_range(0.28, 0.5))
	pixel_particles.append({"sprite": particle, "velocity": Vector2(noise_speed * 5.0, root.get("rng").randf_range(-18.0, -11.0)), "timer": lifetime, "lifetime": lifetime, "gravity": -3.0, "fire_spark": true})


func begin_player_death(root: Object, depth_scale: float) -> void:
	if bool(root.get("player_dead")):
		return
	root.set("player_dead", true); root.set("player_death_pending", false); root.set("player_death_timer", 0.0); root.set("player_death_particles_started", false)
	root.set("player_is_attacking", false); root.set("player_is_rolling", false); root.call("_clear_roll_dust")
	var player := root.get("player") as Sprite2D
	(root.get("player_attack_visual") as Sprite2D).visible = false
	root.set("player_death_origin", player.global_position); root.set("player_death_offset", player.offset); root.set("player_death_scale", player.scale); root.set("player_death_texture", player.texture)
	player.visible = false
	var shadow := root.get("player_shadow") as Sprite2D
	if shadow != null: shadow.visible = false
	var sprite_shadow := root.get("player_sprite_shadow") as Sprite2D
	if sprite_shadow != null: sprite_shadow.visible = false
	var overlay := Sprite2D.new()
	overlay.name = "PlayerDeathWhite"; overlay.texture = root.call("_white_texture", player.texture); overlay.centered = player.centered; overlay.offset = player.offset; overlay.scale = player.scale; overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; overlay.z_as_relative = false; overlay.z_index = int(round(root.call("_depth_key", player) * depth_scale)) + 2; overlay.global_position = player.global_position; overlay.modulate = Color(1, 1, 1, 0)
	root.add_child(overlay); root.set("player_death_overlay", overlay)
var roll_dust_sprite: Sprite2D = null
var roll_dust_frame := 0
var roll_dust_timer := 0.0
var roll_dust_flipped := false
var roll_dust_origin := Vector2.ZERO
var roll_dust_drift := Vector2.ZERO


func number_texture(text: String, color: Color) -> Texture2D:
	var cache_key := "%s:%s" % [text, _rgb_key(color)]
	if damage_number_texture_cache.has(cache_key):
		return damage_number_texture_cache[cache_key]
	var patterns := {
		"+": ["000", "010", "111", "010", "000"], "!": ["010", "010", "010", "000", "010"], ".": ["0", "0", "0", "0", "1"], "/": ["001", "001", "010", "100", "100"],
		"R": ["110", "101", "110", "101", "101"], "S": ["111", "100", "111", "001", "111"], "T": ["111", "010", "010", "010", "010"], "I": ["111", "010", "010", "010", "111"], "Y": ["101", "101", "010", "010", "010"],
		"N": ["1001", "1101", "1011", "1001", "1001"], "D": ["110", "101", "101", "101", "110"], "F": ["111", "100", "110", "100", "100"], "C": ["111", "100", "100", "100", "111"], "U": ["101", "101", "101", "101", "111"], "L": ["100", "100", "100", "100", "111"],
		"0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"], "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "111", "001", "111"], "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"], "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"], "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
		"G": ["111", "100", "101", "101", "111"], "H": ["101", "101", "111", "101", "101"], "K": ["101", "110", "100", "110", "101"], "P": ["110", "101", "110", "100", "100"], "W": ["10101", "10101", "10101", "11011", "01010"], "A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"], "M": ["10001", "11011", "10101", "10001", "10001"], "E": ["111", "100", "110", "100", "111"], "O": ["111", "101", "101", "101", "111"], "V": ["101", "101", "101", "101", "010"], "<": ["001", "010", "100", "010", "001"], ">": ["100", "010", "001", "010", "100"], " ": ["0", "0", "0", "0", "0"]
	}
	var image_width := 0
	for digit in text:
		image_width += (patterns.get(digit, patterns["0"])[0] as String).length() + 1
	image_width = maxi(image_width - 1, 1)
	var image := Image.create(image_width, 5, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var x_offset := 0
	for digit in text:
		var pattern: Array = patterns.get(digit, patterns["0"])
		for y in 5:
			var row := pattern[y] as String
			for x in row.length():
				if row[x] == "1":
					image.set_pixel(x_offset + x, y, color)
		x_offset += (pattern[0] as String).length() + 1
	var texture := ImageTexture.create_from_image(image)
	damage_number_texture_cache[cache_key] = texture
	return texture


func name_texture(text: String, color: Color) -> Texture2D:
	var glyphs := {"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"], "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01110"], "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"], "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"], "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"], "V": ["10001", "10001", "10001", "10001", "01010", "01010", "00100"], "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"], "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"], "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"], "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"], "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"], "5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"], "6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"], "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"], "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"], "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"], ".": ["0", "0", "0", "0", "0", "0", "1"], "d": ["00001", "00001", "01101", "10011", "10001", "10011", "01101"], "i": ["010", "000", "110", "010", "010", "010", "111"], "l": ["110", "010", "010", "010", "010", "010", "111"], "r": ["000", "000", "101", "110", "100", "100", "100"], "u": ["000", "000", "101", "101", "101", "111", "101"], "e": ["000", "000", "010", "101", "111", "100", "011"], "n": ["000", "000", "110", "101", "101", "101", "101"], "m": ["00000", "00000", "11011", "10101", "10101", "10101", "10101"], " ": ["0", "0", "0", "0", "0", "0", "0"]}
	var width := 0
	for character in text:
		width += (glyphs.get(character, glyphs[" "])[0] as String).length() + 1
	width = maxi(width - 1, 1)
	var image := Image.create(width, 7, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var x_offset := 0
	for character in text:
		var pattern: Array = glyphs.get(character, glyphs[" "])
		for y in 7:
			var row := pattern[y] as String
			for x in row.length():
				if row[x] == "1":
					image.set_pixel(x_offset + x, y, color)
		x_offset += (pattern[0] as String).length() + 1
	return ImageTexture.create_from_image(image)


func spawn_player_death_particles(parent: Node, texture: Texture2D, origin: Vector2, offset: Vector2, scale: Vector2, z_index: int, lifetime_max: float, random_seed: int, pixel_texture: Callable, flip_h: bool = false) -> void:
	if texture == null:
		return
	var image := texture.get_image()
	if image == null:
		return
	var noise := FastNoiseLite.new()
	noise.seed = random_seed
	noise.frequency = 0.32
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	var candidates: Array[Vector2i] = []
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0 and noise.get_noise_2d(float(x), float(y)) > -0.22:
				candidates.append(Vector2i(x, y))
	candidates.shuffle()
	for source_pixel in candidates:
		var particle := Sprite2D.new()
		particle.texture = pixel_texture.call(Color.WHITE) as Texture2D
		particle.centered = false
		particle.scale = scale
		particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		particle.z_as_relative = false
		particle.z_index = z_index
		var pixel_x := image.get_width() - 1 - source_pixel.x if flip_h else source_pixel.x
		particle.position = origin + offset + Vector2(pixel_x, source_pixel.y) * scale
		parent.add_child(particle)
		var lifetime := randf_range(1.2, lifetime_max)
		pixel_particles.append({"sprite": particle, "velocity": Vector2(0.0, randf_range(-18.0, -7.0)), "timer": lifetime, "lifetime": lifetime, "gravity": 0.0})


func spawn_slime_death_particles(parent: Node, texture: Texture2D, position: Vector2, z_index: int, count: int, speed_min: float, speed_max: float, lifetime: float, random_source: RandomNumberGenerator, pixel_texture: Callable) -> void:
	if texture == null:
		return
	var image := texture.get_image()
	if image == null:
		return
	var pixels: Array[Vector2i] = []
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				pixels.append(Vector2i(x, y))
	pixels.shuffle()
	for index in mini(count, pixels.size()):
		var source_pixel := pixels[index]
		var particle := Sprite2D.new()
		particle.texture = pixel_texture.call(image.get_pixelv(source_pixel)) as Texture2D
		particle.centered = false
		particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		particle.z_as_relative = false
		particle.z_index = z_index
		particle.position = position + Vector2(source_pixel) + Vector2(0, -2)
		parent.add_child(particle)
		var direction := -1.0 if float(source_pixel.x) < float(image.get_width()) * 0.5 else 1.0
		pixel_particles.append({"sprite": particle, "velocity": Vector2(direction * random_source.randf_range(speed_min * 0.5, speed_max * 0.75), random_source.randf_range(-10.0, -2.0)), "timer": lifetime, "gravity": 30.0})


func spawn_chest_evaporation_particles(parent: Node, texture: Texture2D, position: Vector2, z_index: int, count: int, lifetime_min: float, lifetime_max: float, random_source: RandomNumberGenerator, pixel_texture: Callable) -> void:
	if texture == null: return
	var image: Image = texture.get_image()
	if image == null: return
	var noise := FastNoiseLite.new(); noise.seed = random_source.randi(); noise.frequency = 0.45; noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	var candidates: Array[Vector2i] = []
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0 and noise.get_noise_2d(float(x), float(y)) > -0.18: candidates.append(Vector2i(x, y))
	candidates.shuffle()
	for index in mini(count, candidates.size()):
		var source_pixel := candidates[index]; var particle := Sprite2D.new(); particle.texture = pixel_texture.call(image.get_pixelv(source_pixel)); particle.centered = false; particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; particle.z_as_relative = false; particle.z_index = z_index; particle.position = position + Vector2(source_pixel); parent.add_child(particle)
		var lifetime := random_source.randf_range(lifetime_min, lifetime_max); pixel_particles.append({"sprite": particle, "velocity": Vector2(0.0, random_source.randf_range(-24.0, -12.0)), "timer": lifetime, "lifetime": lifetime, "gravity": 0.0})



func spawn_damage_number(parent: Node, world_position: Vector2, value: int, velocity: Vector2, was_critical: bool, pixel_number: Callable, snap_position: Callable, lifetime: float, pop_time: float) -> void:
	spawn_health_number(parent, world_position, value, velocity, was_critical, false, Color.WHITE, pixel_number, snap_position, lifetime, pop_time)


func spawn_health_number(parent: Node, world_position: Vector2, value: int, velocity: Vector2, was_critical: bool, is_healing: bool, healing_color: Color, pixel_number: Callable, snap_position: Callable, lifetime: float, pop_time: float) -> void:
	var number_text := "+%d" % maxi(value, 0) if is_healing else str(maxi(value, 0))
	var color := healing_color if is_healing else Color8(255, 226, 92) if was_critical else Color.WHITE
	var shadow := Sprite2D.new()
	shadow.texture = pixel_number.call(number_text, Color8(0, 0, 0, 76)) as Texture2D
	shadow.centered = false
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.z_as_relative = false
	shadow.z_index = 4091
	shadow.position = snap_position.call(world_position + Vector2(0.0, 0.5))
	parent.add_child(shadow)
	var sprite := Sprite2D.new()
	sprite.texture = pixel_number.call(number_text, color) as Texture2D
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_as_relative = false
	sprite.z_index = 4092
	sprite.position = world_position
	parent.add_child(sprite)
	damage_numbers.append({"sprite": sprite, "shadow": shadow, "timer": lifetime, "pop_timer": pop_time, "velocity": velocity})


func _rgb_key(color: Color) -> String:
	return "%02x%02x%02x%02x" % [roundi(color.r * 255.0), roundi(color.g * 255.0), roundi(color.b * 255.0), roundi(color.a * 255.0)]


func request_effect(kind: StringName, position: Vector2) -> void:
	effect_requested.emit(kind, position)


func update_pixel_particles(delta: float, snap_position: Callable, default_lifetime: float) -> void:
	for index in range(pixel_particles.size() - 1, -1, -1):
		var particle_data := pixel_particles[index]
		var particle := particle_data["sprite"] as Sprite2D
		var timer := float(particle_data["timer"]) - delta
		if particle == null or timer <= 0.0:
			if particle != null:
				particle.queue_free()
			pixel_particles.remove_at(index)
			continue
		var velocity := particle_data["velocity"] as Vector2
		velocity.y += float(particle_data.get("gravity", 18.0)) * delta
		var logical_position := particle_data.get("logical_position", particle.position) as Vector2
		logical_position += velocity * delta
		particle_data["logical_position"] = logical_position
		particle.position = snap_position.call(logical_position)
		var color := particle.modulate
		var lifetime := float(particle_data.get("lifetime", default_lifetime))
		color.a = clampf(timer / lifetime, 0.0, 1.0)
		if bool(particle_data.get("fire_spark", false)):
			var progress := 1.0 - clampf(timer / lifetime, 0.0, 1.0)
			var fire_color := Color(1.0, 0.12, 0.05).lerp(Color(1.0, 0.86, 0.18), clampf(progress / 0.35, 0.0, 1.0))
			color = Color(fire_color.r, fire_color.g, fire_color.b, clampf(1.0 - progress, 0.0, 1.0))
		particle.modulate = color
		particle_data["velocity"] = velocity
		particle_data["timer"] = timer


func update_damage_numbers(delta: float, snap_position: Callable, default_lifetime: float) -> void:
	for index in range(damage_numbers.size() - 1, -1, -1):
		var damage_number := damage_numbers[index]
		var sprite := damage_number["sprite"] as Sprite2D
		var shadow := damage_number.get("shadow") as Sprite2D
		if sprite == null:
			if shadow != null:
				shadow.queue_free()
			damage_numbers.remove_at(index)
			continue
		var pop_timer := float(damage_number.get("pop_timer", 0.0))
		if pop_timer > 0.0:
			damage_number["pop_timer"] = maxf(pop_timer - delta, 0.0)
			sprite.modulate = Color.WHITE
			continue
		var timer := float(damage_number["timer"]) - delta
		if timer <= 0.0:
			sprite.queue_free()
			if shadow != null:
				shadow.queue_free()
			damage_numbers.remove_at(index)
			continue
		var logical_position := damage_number.get("logical_position", sprite.position) as Vector2
		logical_position += damage_number.get("velocity", Vector2.ZERO) as Vector2 * delta
		damage_number["logical_position"] = logical_position
		sprite.position = snap_position.call(logical_position)
		if shadow != null:
			shadow.position = snap_position.call(logical_position + Vector2(0.0, 0.5))
		var alpha := clampf(timer / default_lifetime, 0.0, 1.0)
		sprite.modulate.a = alpha
		if shadow != null:
			shadow.modulate.a = alpha
		damage_number["timer"] = timer


func start_roll_dust(parent: Node, player: Sprite2D, direction: Vector2, frames: Array[Texture2D], flipped_frames: Array[Texture2D], actor_foot: Callable, snap_position: Callable) -> void:
	clear_roll_dust()
	if frames.is_empty(): return
	roll_dust_flipped = direction.x > 0.01 or (absf(direction.x) <= 0.01 and not player.flip_h)
	var active_frames := flipped_frames if roll_dust_flipped else frames
	roll_dust_sprite = Sprite2D.new(); roll_dust_sprite.name = "RollDust"; roll_dust_sprite.texture = active_frames[0]; roll_dust_sprite.centered = false; roll_dust_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; roll_dust_sprite.z_as_relative = false; roll_dust_sprite.z_index = maxi(player.z_index - 2, 0)
	var emission_anchor: Vector2 = actor_foot.call(player) + Vector2(0.0, -3.0) - direction * 2.0 + Vector2(0.0, 3.0); var texture_anchor := Vector2(15.0, 15.0) if roll_dust_flipped else Vector2(0.0, 15.0); roll_dust_sprite.global_position = snap_position.call(emission_anchor - texture_anchor); roll_dust_origin = roll_dust_sprite.global_position; roll_dust_drift = Vector2.LEFT if roll_dust_flipped else Vector2.RIGHT; parent.add_child(roll_dust_sprite); roll_dust_frame = 0; roll_dust_timer = 0.0


func update_roll_dust(delta: float, player_z: int, frames: Array[Texture2D], flipped_frames: Array[Texture2D], frame_time: float, snap_position: Callable) -> void:
	if roll_dust_sprite == null: return
	roll_dust_sprite.z_index = maxi(player_z - 1, 0); roll_dust_timer += delta
	if roll_dust_timer < frame_time: return
	roll_dust_timer = fmod(roll_dust_timer, frame_time); roll_dust_frame += 1
	var active_frames := flipped_frames if roll_dust_flipped else frames
	if roll_dust_frame >= active_frames.size(): clear_roll_dust(); return
	roll_dust_sprite.texture = active_frames[roll_dust_frame]; roll_dust_sprite.global_position = snap_position.call(roll_dust_origin + roll_dust_drift * float(roll_dust_frame) * 0.5)


func clear_roll_dust() -> void:
	if roll_dust_sprite != null: roll_dust_sprite.queue_free()
	roll_dust_sprite = null; roll_dust_frame = 0; roll_dust_timer = 0.0; roll_dust_flipped = false; roll_dust_origin = Vector2.ZERO; roll_dust_drift = Vector2.ZERO
