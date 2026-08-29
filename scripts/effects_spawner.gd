extends Node
class_name EffectsSpawner

signal effect_requested(kind: StringName, position: Vector2)
const CHARGE_AURA_TAG := &"charge_aura"
var damage_number_texture_cache: Dictionary = {}
var critical_outline_texture_cache: Dictionary = {}
var name_texture_cache: Dictionary = {}
var keyboard_prompt_texture_cache: Dictionary = {}
var pixel_particle_texture_cache: Dictionary = {}
var damage_numbers: Array[Dictionary] = []
var pixel_particles: Array[Dictionary] = []
var slime_notice_effects: Array[Dictionary] = []
var fire_spark_timer := 0.0
var fire_noise := FastNoiseLite.new()
var charge_aura_timer := 0.0
var charge_ready_blink_timer := 0.0
var charge_aura_active := false
var charge_ready_highlight: Sprite2D = null


func spawn_slime_death_from_root(root: Object, slime: Sprite2D) -> void:
	var tuning := root.get("effects_tuning") as EffectsTuning
	var occlusion := root.get("occlusion_renderer") as OcclusionRenderer
	var source_texture: Texture2D = occlusion.original_actor_textures.get(slime, slime.texture)
	spawn_slime_death_particles(root, source_texture, slime.global_position, int(round(root.call("_actor_foot", slime).y * root.get("DEPTH_Z_SCALE"))) + 1, tuning.slime_death_particle_count, tuning.slime_death_particle_speed_min, tuning.slime_death_particle_speed_max, tuning.slime_death_particle_lifetime, root.get("rng"), Callable(root, "_pixel_particle_texture"))


func spawn_gold_from_root(root: Object, world_position: Vector2, amount: int) -> void:
	var tuning := root.get("effects_tuning") as EffectsTuning; var sprite := Sprite2D.new(); sprite.texture = root.call("_pixel_text_texture", "+%d" % amount, Color8(255, 205, 117)); sprite.centered = false; sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; sprite.z_as_relative = false; sprite.z_index = int(root.get("OVERWORLD_UI_Z")) + 2; sprite.position = world_position; root.add_child(sprite); damage_numbers.append({"sprite": sprite, "timer": tuning.damage_number_lifetime})


func spawn_chest_evaporation_from_root(root: Object) -> void:
	var chest := root.get("chest") as Sprite2D; spawn_chest_evaporation_particles(root, chest.texture, chest.global_position, int(round(root.call("_depth_key", chest) * root.get("DEPTH_Z_SCALE"))) + 1, int(root.get("CHEST_EVAPORATE_PARTICLE_COUNT")), float(root.get("CHEST_EVAPORATE_LIFETIME_MIN")), float(root.get("CHEST_EVAPORATE_LIFETIME_MAX")), root.get("rng"), Callable(root, "_pixel_particle_texture"))


func spawn_chroma_pickup_burst_from_root(root: Object, world_position: Vector2) -> void:
	var random_source := RandomNumberGenerator.new()
	var seed_value := int(round(world_position.x * 100.0)) ^ int(round(world_position.y * 101.0)) ^ Time.get_ticks_msec()
	random_source.seed = seed_value
	var origin: Vector2 = root.call("_snap_half_pixel", world_position) as Vector2
	var z_index := int(round(world_position.y * float(root.get("DEPTH_Z_SCALE")))) + 4
	var chroma_color: Color = PaletteLibrary.ACCENT["blue"]
	var flash := Sprite2D.new()
	flash.name = "ChromaPickupFlash"
	flash.texture = root.call("_pixel_particle_texture", chroma_color.lerp(Color.WHITE, 0.7), 3) as Texture2D
	flash.centered = true
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flash.z_as_relative = false
	flash.z_index = z_index + 1
	flash.position = origin
	root.add_child(flash)
	pixel_particles.append({"sprite": flash, "velocity": Vector2.ZERO, "timer": 0.16, "lifetime": 0.16, "gravity": 0.0, "effect_tag": &"chroma_pickup", "logical_position": origin})
	for index in 18:
		var particle := Sprite2D.new()
		particle.name = "ChromaPickupSplash%d" % index
		var particle_color := chroma_color.lerp(Color.WHITE, random_source.randf_range(0.05, 0.55))
		particle.texture = root.call("_pixel_particle_texture", particle_color, 1 if index % 3 else 2) as Texture2D
		particle.centered = true
		particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		particle.z_as_relative = false
		particle.z_index = z_index
		particle.position = origin
		root.add_child(particle)
		var angle := TAU * float(index) / 18.0 + random_source.randf_range(-0.16, 0.16)
		var speed := random_source.randf_range(18.0, 38.0)
		var lifetime := random_source.randf_range(0.28, 0.48)
		var velocity := Vector2.from_angle(angle) * speed + Vector2(0.0, -random_source.randf_range(2.0, 9.0))
		pixel_particles.append({"sprite": particle, "velocity": velocity, "timer": lifetime, "lifetime": lifetime, "gravity": 30.0, "effect_tag": &"chroma_pickup", "logical_position": origin})


func update_pixel_particles_from_root(root: Object, delta: float) -> void:
	update_charge_aura_from_root(root, delta)
	update_pixel_particles(delta, Callable(root, "_snap_half_pixel"), (root.get("effects_tuning") as EffectsTuning).slime_death_particle_lifetime)
	update_slime_notices(root, delta)
	update_fire_sparks_from_root(root, delta)


## Emits a restrained foot-level charge effect. The cadence, launch speed, and
## outward curl ramp with the held charge: it starts as a few soft wisps and
## reaches a denser, streaked air-whip at the one-second cap without tinting or
## flashing the player sprite itself.
func update_charge_aura_from_root(root: Object, delta: float) -> void:
	var attack := root.get("player_attack_component") as PlayerAttackComponent
	var player := root.get("player") as Sprite2D
	if attack == null or player == null or not is_instance_valid(player) or not attack.is_charging():
		if charge_aura_active:
			clear_effect_particles(CHARGE_AURA_TAG)
		charge_aura_active = false
		charge_aura_timer = 0.0
		_hide_charge_ready_highlight()
		charge_ready_blink_timer = 0.0
		return
	var tuning := root.get("player_tuning") as PlayerTuning
	if tuning == null:
		_hide_charge_ready_highlight()
		charge_ready_blink_timer = 0.0
		return
	var charge_span := maxf(tuning.charge_maximum_time, tuning.charge_minimum_time)
	var progress := clampf(attack.charge_elapsed / maxf(charge_span, 0.01), 0.0, 1.0)
	var eased_progress := progress * progress * (3.0 - 2.0 * progress)
	_update_charge_ready_highlight(root, player, progress, delta)
	var cadence := lerpf(tuning.charge_aura_start_interval, tuning.charge_aura_peak_interval, eased_progress)
	cadence = maxf(cadence, 0.016)
	if not charge_aura_active:
		charge_aura_active = true
		charge_aura_timer = 0.0
	charge_aura_timer -= maxf(delta, 0.0)
	var random_source := root.get("rng") as RandomNumberGenerator
	if random_source == null:
		random_source = RandomNumberGenerator.new()
		random_source.randomize()
	var emitted := 0
	while charge_aura_timer <= 0.0 and emitted < 4:
		_spawn_charge_aura_particle(root, player, tuning, eased_progress, random_source)
		charge_aura_timer += cadence
		emitted += 1
	if emitted >= 4 and charge_aura_timer <= 0.0:
		charge_aura_timer = cadence


func _spawn_charge_aura_particle(root: Object, player: Sprite2D, tuning: PlayerTuning, progress: float, random_source: RandomNumberGenerator) -> void:
	var foot: Vector2 = root.call("_actor_foot", player)
	var side := -1.0 if random_source.randf() < 0.5 else 1.0
	var spread := lerpf(tuning.charge_aura_start_spread, tuning.charge_aura_peak_spread, progress)
	var launch_speed := lerpf(tuning.charge_aura_start_speed, tuning.charge_aura_peak_speed, progress)
	var rise_speed := lerpf(tuning.charge_aura_start_rise, tuning.charge_aura_peak_rise, progress)
	var curl := lerpf(tuning.charge_aura_start_curl, tuning.charge_aura_peak_curl, progress)
	var origin := foot + Vector2(side * random_source.randf_range(0.0, spread), random_source.randf_range(-0.5, 0.5))
	var horizontal_speed := side * launch_speed * random_source.randf_range(0.35, 0.90)
	var vertical_speed := -rise_speed * random_source.randf_range(0.80, 1.15)
	# The charge effect is deliberately neutral so it reads as compressed air,
	# while the player outline below provides the neutral charge feedback.
	var air_color := Color.WHITE
	var pixel_size := 2 if progress >= 0.70 and random_source.randf() < 0.30 else 1
	var particle := Sprite2D.new()
	particle.name = "ChargeAuraParticle"
	particle.texture = root.call("_pixel_particle_texture", air_color, pixel_size) as Texture2D
	particle.centered = true
	particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particle.z_as_relative = false
	particle.z_index = maxi(player.z_index - 2, 0)
	particle.position = origin
	particle.modulate = Color(air_color.r, air_color.g, air_color.b, lerpf(0.38, 0.78, progress))
	particle.scale = Vector2(1.0, 2.0 if progress >= 0.70 else 1.0)
	particle.rotation = Vector2(horizontal_speed, vertical_speed).angle() + PI * 0.5
	root.add_child(particle)
	var lifetime := maxf(tuning.charge_aura_particle_lifetime * random_source.randf_range(0.78, 1.12), 0.05)
	pixel_particles.append({
		"sprite": particle,
		"velocity": Vector2(horizontal_speed, vertical_speed),
		"timer": lifetime,
		"lifetime": lifetime,
		"gravity": lerpf(34.0, 52.0, progress),
		"effect_tag": CHARGE_AURA_TAG,
		"logical_position": origin,
		"alpha_scale": lerpf(0.38, 0.78, progress),
		"curl": side * curl * random_source.randf_range(0.75, 1.25),
		"charge_progress": progress,
	})


func _update_charge_ready_highlight(root: Object, player: Sprite2D, progress: float, delta: float) -> void:
	if progress < 0.82 or player.texture == null:
		_hide_charge_ready_highlight()
		return
	charge_ready_blink_timer = fmod(charge_ready_blink_timer + maxf(delta, 0.0), 0.20)
	if charge_ready_highlight == null or not is_instance_valid(charge_ready_highlight):
		charge_ready_highlight = Sprite2D.new()
		charge_ready_highlight.name = "ChargeReadyHighlight"
		charge_ready_highlight.centered = player.centered
		charge_ready_highlight.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		charge_ready_highlight.z_as_relative = true
		charge_ready_highlight.z_index = 2
		player.add_child(charge_ready_highlight)
	var renderer := root.get("occlusion_renderer") as OcclusionRenderer
	if renderer != null:
		charge_ready_highlight.texture = renderer.highlighted_texture(player.texture)
	else:
		charge_ready_highlight.texture = root.call("_white_texture", player.texture) as Texture2D
	ActorGeometry.sync_overlay(charge_ready_highlight, player)
	var readiness := clampf((progress - 0.82) / 0.18, 0.0, 1.0)
	var blink := 0.5 + 0.5 * sin(charge_ready_blink_timer / 0.20 * TAU)
	var alpha := lerpf(0.12, 0.46, readiness) * lerpf(0.55, 1.0, blink)
	charge_ready_highlight.modulate = Color(1.0, 1.0, 1.0, alpha)
	charge_ready_highlight.visible = true


func _hide_charge_ready_highlight() -> void:
	if charge_ready_highlight != null and is_instance_valid(charge_ready_highlight):
		charge_ready_highlight.visible = false


func spawn_slime_notice(root: Object, slime: Sprite2D, duration: float) -> void:
	var marker := Sprite2D.new()
	marker.name = "SlimeNotice"
	marker.texture = root.call("_pixel_text_texture", "!", Color8(255, 205, 117)) as Texture2D
	marker.centered = true
	marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marker.z_as_relative = false
	root.add_child(marker)
	slime_notice_effects.append({"sprite": marker, "slime": slime, "timer": duration, "duration": duration})


func clear_slime_notices() -> void:
	for effect in slime_notice_effects:
		var marker := effect.get("sprite") as Sprite2D
		if marker != null:
			marker.queue_free()
	slime_notice_effects.clear()


func update_slime_notices(_root: Object, delta: float) -> void:
	for index in range(slime_notice_effects.size() - 1, -1, -1):
		var effect := slime_notice_effects[index]
		var marker := effect.get("sprite") as Sprite2D
		var slime := effect.get("slime") as Sprite2D
		var timer := float(effect.get("timer", 0.0)) - delta
		if marker == null or slime == null or not is_instance_valid(slime) or not slime.visible or timer <= 0.0:
			if marker != null:
				marker.queue_free()
			slime_notice_effects.remove_at(index)
			continue
		var duration := maxf(float(effect.get("duration", 0.01)), 0.01)
		var progress := 1.0 - clampf(timer / duration, 0.0, 1.0)
		var encounter_scale := float(slime.get_meta("encounter_scale", 1.0))
		marker.global_position = slime.global_position + Vector2(8.0, -5.0 - 13.0 * (encounter_scale - 1.0) - progress * 3.0)
		# Keep the glyph at native 1:1 pixels; the upward motion supplies the pop.
		marker.scale = Vector2.ONE
		marker.modulate = Color(1.0, 1.0, 1.0, clampf(timer / minf(duration, 0.16), 0.0, 1.0))
		marker.z_index = slime.z_index + 4
		effect["timer"] = timer
		slime_notice_effects[index] = effect


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
	root.set("player_is_attacking", false); root.set("player_is_rolling", false); root.set("player_is_backflipping", false); root.call("_clear_roll_dust")
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
	if text.contains("\n"):
		var multiline_texture := _multiline_number_texture(text, color)
		damage_number_texture_cache[cache_key] = multiline_texture
		return multiline_texture
	var patterns := {
		"+": ["000", "010", "111", "010", "000"], "-": ["000", "000", "111", "000", "000"], "_": ["000", "000", "000", "000", "111"], ":": ["0", "1", "0", "1", "0"], ";": ["0", "1", "0", "1", "1"], "!": ["010", "010", "010", "000", "010"], ".": ["0", "0", "0", "0", "1"], ",": ["0", "0", "0", "1", "1"], "'": ["1", "1", "0", "0", "0"], "\"": ["101", "101", "000", "000", "000"], "(": ["001", "010", "100", "010", "001"], ")": ["100", "010", "001", "010", "100"], "/": ["001", "001", "010", "100", "100"],
		"R": ["110", "101", "110", "101", "101"], "S": ["111", "100", "111", "001", "111"], "T": ["111", "010", "010", "010", "010"], "I": ["111", "010", "010", "010", "111"], "Y": ["101", "101", "010", "010", "010"],
		"N": ["1001", "1101", "1011", "1001", "1001"], "D": ["110", "101", "101", "101", "110"], "F": ["111", "100", "110", "100", "100"], "C": ["111", "100", "100", "100", "111"], "U": ["101", "101", "101", "101", "111"], "L": ["100", "100", "100", "100", "111"],
		"0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"], "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "111", "001", "111"], "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"], "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"], "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
		"G": ["111", "100", "101", "101", "111"], "H": ["101", "101", "111", "101", "101"], "K": ["101", "110", "100", "110", "101"], "P": ["110", "101", "110", "100", "100"], "W": ["10101", "10101", "10101", "11011", "01010"], "A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"], "M": ["10001", "11011", "10101", "10001", "10001"], "E": ["111", "100", "110", "100", "111"], "O": ["111", "101", "101", "101", "111"], "V": ["101", "101", "101", "101", "010"], "X": ["101", "101", "010", "101", "101"], "?": ["110", "001", "010", "000", "010"], "<": ["001", "010", "100", "010", "001"], ">": ["100", "010", "001", "010", "100"], "%": ["11001", "11010", "00100", "01011", "10011"], " ": ["0", "0", "0", "0", "0"]
		,"o": ["000", "101", "101", "101", "111"], "g": ["000", "101", "101", "111", "110"], "x": ["000", "000", "101", "010", "101"], "p": ["000", "110", "101", "110", "100"], "l": ["100", "100", "100", "100", "110"], "v": ["000", "000", "101", "101", "010"]
	}
	patterns["J"] = ["001", "001", "001", "101", "010"]
	patterns["Q"] = ["111", "101", "111", "001", "001"]
	patterns["Z"] = ["111", "001", "010", "100", "111"]
	# Lowercase uses the same five-pixel cap as the combat glyphs, but the
	# previous set was a collection of partially drawn three-pixel shapes. In
	# descriptions that made o/e read like broken boxes and g/y lose their
	# identity. Keep a shared baseline and give the curved/descending letters
	# enough horizontal room to survive nearest-neighbour scaling.
	patterns["a"] = ["000", "010", "101", "111", "101"]
	patterns["b"] = ["100", "100", "110", "101", "110"]
	patterns["c"] = ["000", "011", "100", "100", "011"]
	patterns["d"] = ["001", "001", "011", "101", "011"]
	patterns["e"] = ["0000", "0110", "1001", "1111", "1000"]
	patterns["f"] = ["011", "100", "110", "100", "100"]
	patterns["g"] = ["0000", "0110", "1001", "0111", "0001"]
	patterns["h"] = ["100", "100", "110", "101", "101"]
	patterns["i"] = ["010", "000", "110", "010", "111"]
	patterns["j"] = ["001", "000", "001", "101", "010"]
	patterns["k"] = ["100", "100", "101", "110", "101"]
	patterns["l"] = ["100", "100", "100", "100", "110"]
	patterns["m"] = ["00000", "00000", "11011", "10101", "10101"]
	patterns["n"] = ["000", "000", "110", "101", "101"]
	patterns["o"] = ["0000", "0110", "1001", "1001", "0110"]
	patterns["p"] = ["000", "110", "101", "110", "100"]
	patterns["q"] = ["000", "011", "101", "011", "001"]
	patterns["r"] = ["000", "110", "101", "100", "100"]
	patterns["s"] = ["000", "011", "100", "010", "110"]
	patterns["t"] = ["010", "010", "111", "010", "011"]
	patterns["u"] = ["000", "101", "101", "101", "011"]
	patterns["v"] = ["000", "101", "101", "010", "010"]
	patterns["w"] = ["00000", "00000", "10101", "10101", "01010"]
	patterns["x"] = ["000", "101", "010", "101", "101"]
	patterns["y"] = ["0000", "1001", "1001", "0111", "0010"]
	patterns["z"] = ["000", "111", "010", "100", "111"]
	var compact_patterns: Dictionary = {}
	for character in patterns:
		compact_patterns[character] = _compact_glyph_pattern(patterns[character] as Array)
	var image_width := 0
	for digit in text:
		image_width += (compact_patterns.get(digit, compact_patterns[" "])[0] as String).length() + 1
	image_width = maxi(image_width - 1, 1)
	var image := Image.create(image_width, 5, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var x_offset := 0
	for digit in text:
		var pattern: Array = compact_patterns.get(digit, compact_patterns[" "])
		for y in 5:
			var row := pattern[y] as String
			for x in row.length():
				if row[x] == "1":
					image.set_pixel(x_offset + x, y, color)
		x_offset += (pattern[0] as String).length() + 1
	var texture := ImageTexture.create_from_image(image)
	damage_number_texture_cache[cache_key] = texture
	return texture


func _multiline_number_texture(text: String, color: Color) -> Texture2D:
	var lines := text.split("\n")
	var line_textures: Array[Texture2D] = []
	var width := 1
	for line in lines:
		var line_texture := number_texture(String(line), color)
		line_textures.append(line_texture)
		width = maxi(width, line_texture.get_width())
	var line_spacing := 2
	var image := Image.create(width, maxi(1, line_textures.size() * 5 + (line_textures.size() - 1) * line_spacing), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var y_offset := 0
	for line_texture in line_textures:
		var line_image := line_texture.get_image()
		image.blit_rect(line_image, Rect2i(Vector2i.ZERO, line_image.get_size()), Vector2i(0, y_offset))
		y_offset += 5 + line_spacing
	return ImageTexture.create_from_image(image)


func critical_outline_texture(text: String, pixel_number: Callable) -> Texture2D:
	var cache_key := text
	if critical_outline_texture_cache.has(cache_key):
		return critical_outline_texture_cache[cache_key]
	var source := pixel_number.call(text, Color.WHITE) as Texture2D
	if source == null:
		return null
	var source_image := source.get_image()
	var image := Image.create(source_image.get_width() + 2, source_image.get_height() + 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in source_image.get_height():
		for x in source_image.get_width():
			if source_image.get_pixel(x, y).a <= 0.0:
				continue
			for offset_y in range(-1, 2):
				for offset_x in range(-1, 2):
					image.set_pixel(x + 1 + offset_x, y + 1 + offset_y, Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	critical_outline_texture_cache[cache_key] = texture
	return texture


func prompt_texture(text: String, color: Color) -> Texture2D:
	return name_texture(text.to_upper(), color)


func keyboard_prompt_texture(text: String) -> Texture2D:
	var normalized := text.to_upper()
	if keyboard_prompt_texture_cache.has(normalized):
		return keyboard_prompt_texture_cache[normalized]
	var glyph_texture := name_texture(normalized, Color.WHITE)
	if glyph_texture == null:
		return null
	var glyph_image := glyph_texture.get_image()
	var padding := 2
	var image := Image.create(glyph_image.get_width() + padding * 2, glyph_image.get_height() + padding * 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	for y in glyph_image.get_height():
		for x in glyph_image.get_width():
			var glyph_color := glyph_image.get_pixel(x, y)
			if glyph_color.a > 0.0:
				image.set_pixel(x + padding, y + padding, glyph_color)
	var texture := ImageTexture.create_from_image(image)
	keyboard_prompt_texture_cache[normalized] = texture
	return texture


func name_texture(text: String, color: Color) -> Texture2D:
	var cache_key := "%s:%s" % [text, _rgb_key(color)]
	if name_texture_cache.has(cache_key):
		return name_texture_cache[cache_key]
	var glyphs := {"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"], "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"], "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01110"], "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"], "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"], "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"], "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"], "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"], "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"], "V": ["10001", "10001", "10001", "10001", "01010", "01010", "00100"], "X": ["10001", "01010", "00100", "00100", "01010", "10001", "10001"], "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"], "?": ["01110", "10001", "00010", "00100", "00100", "00000", "00100"], "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"], "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"], "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"], "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"], "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"], "5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"], "6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"], "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"], "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"], "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"], ".": ["0", "0", "0", "0", "0", "0", "1"], "d": ["00001", "00001", "01101", "10011", "10001", "10011", "01101"], "i": ["010", "000", "110", "010", "010", "010", "111"], "l": ["110", "010", "010", "010", "010", "010", "111"], "r": ["000", "000", "101", "110", "100", "100", "100"], "u": ["000", "000", "101", "101", "101", "111", "101"], "e": ["000", "000", "010", "101", "111", "100", "011"], "o": ["000", "000", "111", "101", "101", "101", "111"], "g": ["000", "000", "111", "101", "101", "111", "100"], "n": ["000", "000", "110", "101", "101", "101", "101"], "m": ["00000", "00000", "11011", "10101", "10101", "10101", "10101"], " ": ["0", "0", "0", "0", "0", "0", "0"]}
	glyphs["v"] = ["00000", "00000", "10001", "10001", "01010", "01010", "00100"]
	glyphs[":"] = ["0", "1", "0", "0", "0", "1", "0"]
	glyphs["-"] = ["000", "000", "000", "111", "000", "000", "000"]
	glyphs["A"] = ["00100", "01010", "10001", "10001", "11111", "10001", "10001"]
	glyphs["C"] = ["01110", "10001", "10000", "10000", "10000", "10001", "01110"]
	glyphs["D"] = ["11110", "10001", "10001", "10001", "10001", "10001", "11110"]
	glyphs["F"] = ["11111", "10000", "10000", "11110", "10000", "10000", "10000"]
	glyphs["H"] = ["10001", "10001", "10001", "11111", "10001", "10001", "10001"]
	glyphs["I"] = ["11111", "00100", "00100", "00100", "00100", "00100", "11111"]
	glyphs["J"] = ["00111", "00010", "00010", "00010", "10010", "10010", "01100"]
	glyphs["K"] = ["10001", "10010", "10100", "11000", "10100", "10010", "10001"]
	glyphs["M"] = ["10001", "11011", "10101", "10101", "10001", "10001", "10001"]
	glyphs["P"] = ["11110", "10001", "10001", "11110", "10000", "10000", "10000"]
	glyphs["Q"] = ["01110", "10001", "10001", "10001", "10101", "10010", "01101"]
	glyphs["U"] = ["10001", "10001", "10001", "10001", "10001", "10001", "01110"]
	glyphs["W"] = ["10001", "10001", "10001", "10101", "10101", "11011", "10001"]
	glyphs["Z"] = ["11111", "00001", "00010", "00100", "01000", "10000", "11111"]
	glyphs["a"] = ["00000", "00000", "01110", "00001", "01111", "10001", "01111"]
	glyphs["b"] = ["10000", "10000", "10110", "11001", "10001", "11001", "10110"]
	glyphs["c"] = ["00000", "00000", "01110", "10001", "10000", "10001", "01110"]
	glyphs["d"] = ["00001", "00001", "01101", "10011", "10001", "10011", "01101"]
	glyphs["e"] = ["00000", "00000", "01110", "10001", "11111", "10000", "01110"]
	glyphs["f"] = ["00110", "01001", "01000", "11100", "01000", "01000", "01000"]
	glyphs["g"] = ["00000", "00000", "01110", "10001", "01111", "00001", "01110"]
	glyphs["h"] = ["10000", "10000", "10110", "11001", "10001", "10001", "10001"]
	glyphs["i"] = ["00100", "00000", "01100", "00100", "00100", "00100", "01110"]
	glyphs["j"] = ["00010", "00000", "00110", "00010", "00010", "10010", "01100"]
	glyphs["k"] = ["10000", "10000", "10010", "10100", "11000", "10100", "10010"]
	glyphs["l"] = ["11000", "01000", "01000", "01000", "01000", "01000", "11100"]
	glyphs["m"] = ["00000", "00000", "11010", "10101", "10101", "10101", "10101"]
	glyphs["n"] = ["00000", "00000", "10110", "11001", "10001", "10001", "10001"]
	glyphs["o"] = ["00000", "00000", "01110", "10001", "10001", "10001", "01110"]
	glyphs["p"] = ["00000", "00000", "10110", "11001", "10001", "11001", "10110"]
	glyphs["q"] = ["00000", "00000", "01101", "10011", "10001", "10011", "01101"]
	glyphs["r"] = ["00000", "00000", "10110", "11001", "10000", "10000", "10000"]
	glyphs["s"] = ["00000", "00000", "01111", "10000", "01110", "00001", "11110"]
	glyphs["t"] = ["01000", "01000", "11100", "01000", "01001", "01001", "00110"]
	glyphs["u"] = ["00000", "00000", "10001", "10001", "10001", "10011", "01101"]
	glyphs["v"] = ["00000", "00000", "10001", "10001", "01010", "01010", "00100"]
	glyphs["w"] = ["00000", "00000", "10001", "10001", "10101", "10101", "01010"]
	glyphs["x"] = ["00000", "00000", "10001", "01010", "00100", "01010", "10001"]
	glyphs["y"] = ["00000", "00000", "10001", "10001", "01111", "00001", "01110"]
	glyphs["z"] = ["00000", "00000", "11111", "00010", "00100", "01000", "11111"]
	var compact_glyphs: Dictionary = {}
	for character in glyphs:
		compact_glyphs[character] = _compact_glyph_pattern(glyphs[character] as Array)
	var width := 0
	for character in text:
		width += (compact_glyphs.get(character, compact_glyphs[" "])[0] as String).length() + 1
	width = maxi(width - 1, 1)
	var image := Image.create(width, 7, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var x_offset := 0
	for character in text:
		var pattern: Array = compact_glyphs.get(character, compact_glyphs[" "])
		for y in 7:
			var row := pattern[y] as String
			for x in row.length():
				if row[x] == "1":
					image.set_pixel(x_offset + x, y, color)
		x_offset += (pattern[0] as String).length() + 1
	var texture := ImageTexture.create_from_image(image)
	name_texture_cache[cache_key] = texture
	return texture


func _compact_glyph_pattern(pattern: Array) -> Array:
	var min_x := 999
	var max_x := -1
	for row_value in pattern:
		var row := row_value as String
		for x in row.length():
			if row[x] == "1":
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
	if max_x < min_x:
		var empty_pattern: Array = []
		for _row in pattern.size():
			empty_pattern.append("0")
		return empty_pattern
	var compacted: Array = []
	for row_value in pattern:
		var row := row_value as String
		compacted.append(row.substr(min_x, max_x - min_x + 1))
	return compacted


func spawn_player_death_particles(parent: Node, texture: Texture2D, origin: Vector2, offset: Vector2, scale: Vector2, z_index: int, lifetime_max: float, random_seed: int, pixel_texture: Callable, flip_h: bool = false, effect_tag: StringName = &"") -> void:
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
		pixel_particles.append({"sprite": particle, "velocity": Vector2(0.0, randf_range(-18.0, -7.0)), "timer": lifetime, "lifetime": lifetime, "gravity": 0.0, "effect_tag": effect_tag})


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


func spawn_health_number(parent: Node, world_position: Vector2, value: int, velocity: Vector2, was_critical: bool, is_healing: bool, healing_color: Color, pixel_number: Callable, snap_position: Callable, lifetime: float, pop_time: float, display_text := "") -> void:
	var number_text := String(display_text) if not String(display_text).is_empty() else "+%d" % maxi(value, 0) if is_healing else str(maxi(value, 0))
	# `healing_color` also carries the requested color for non-healing special
	# numbers, such as the light-blue damage absorbed by the shield.
	var color := healing_color if is_healing or not healing_color.is_equal_approx(Color.WHITE) else Color.WHITE
	var shadow := Sprite2D.new()
	shadow.texture = pixel_number.call(number_text, Color8(0, 0, 0, 76)) as Texture2D
	shadow.centered = false
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.z_as_relative = false
	shadow.z_index = 4091
	shadow.position = snap_position.call(world_position + Vector2(0.0, 0.5))
	parent.add_child(shadow)
	var outline: Sprite2D = null
	if was_critical:
		outline = Sprite2D.new()
		outline.name = "CriticalDamageOutline"
		outline.texture = critical_outline_texture(number_text, pixel_number)
		outline.centered = false
		outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		outline.z_as_relative = false
		outline.z_index = 4091
		outline.position = snap_position.call(world_position - Vector2.ONE)
		parent.add_child(outline)
	var sprite := Sprite2D.new()
	sprite.texture = pixel_number.call(number_text, color) as Texture2D
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_as_relative = false
	sprite.z_index = 4092
	sprite.position = world_position
	parent.add_child(sprite)
	damage_numbers.append({"sprite": sprite, "shadow": shadow, "outline": outline, "timer": lifetime, "pop_timer": pop_time, "velocity": velocity})


func _rgb_key(color: Color) -> String:
	return "%02x%02x%02x%02x" % [roundi(color.r * 255.0), roundi(color.g * 255.0), roundi(color.b * 255.0), roundi(color.a * 255.0)]


func request_effect(kind: StringName, position: Vector2) -> void:
	effect_requested.emit(kind, position)


func clear_effect_particles(effect_tag: StringName) -> void:
	for index in range(pixel_particles.size() - 1, -1, -1):
		var particle_data := pixel_particles[index]
		if particle_data.get("effect_tag", &"") != effect_tag:
			continue
		var particle := particle_data.get("sprite") as Sprite2D
		if particle != null:
			particle.queue_free()
		pixel_particles.remove_at(index)
	if effect_tag == CHARGE_AURA_TAG:
		charge_aura_active = false
		charge_aura_timer = 0.0


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
		if particle_data.get("effect_tag", &"") == CHARGE_AURA_TAG:
			velocity.x += float(particle_data.get("curl", 0.0)) * delta
		var logical_position := particle_data.get("logical_position", particle.position) as Vector2
		logical_position += velocity * delta
		particle_data["logical_position"] = logical_position
		particle.position = snap_position.call(logical_position)
		var color := particle.modulate
		var lifetime := float(particle_data.get("lifetime", default_lifetime))
		color.a = float(particle_data.get("alpha_scale", 1.0)) * clampf(timer / lifetime, 0.0, 1.0)
		if particle_data.get("effect_tag", &"") == CHARGE_AURA_TAG:
			particle.rotation = velocity.angle() + PI * 0.5
			var charge_progress := float(particle_data.get("charge_progress", 0.0))
			particle.scale = Vector2(1.0, 2.0 if charge_progress >= 0.70 else 1.0)
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
		var outline := damage_number.get("outline") as Sprite2D
		if sprite == null:
			if shadow != null:
				shadow.queue_free()
			if outline != null:
				outline.queue_free()
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
			if outline != null:
				outline.queue_free()
			damage_numbers.remove_at(index)
			continue
		var logical_position := damage_number.get("logical_position", sprite.position) as Vector2
		logical_position += damage_number.get("velocity", Vector2.ZERO) as Vector2 * delta
		damage_number["logical_position"] = logical_position
		sprite.position = snap_position.call(logical_position)
		if shadow != null:
			shadow.position = snap_position.call(logical_position + Vector2(0.0, 0.5))
		if outline != null:
			outline.position = snap_position.call(logical_position - Vector2.ONE)
		var alpha := clampf(timer / default_lifetime, 0.0, 1.0)
		sprite.modulate.a = alpha
		if shadow != null:
			shadow.modulate.a = alpha
		if outline != null:
			outline.modulate.a = alpha
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
