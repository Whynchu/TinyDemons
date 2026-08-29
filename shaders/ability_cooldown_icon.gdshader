shader_type canvas_item;
render_mode unshaded;

// The value is the fraction of the cooldown still remaining. While it is
// above zero the remaining sector stays grey and dim; the elapsed sector keeps
// the selected Chroma palette and is brightened so cooldown progress is easy to
// read without making the whole button look ready too early.
uniform float cooldown_ratio : hint_range(0.0, 1.0) = 0.0;
uniform float unavailable : hint_range(0.0, 1.0) = 0.0;
uniform float desaturation_amount : hint_range(0.0, 1.0) = 0.92;
uniform float cooldown_dim : hint_range(0.0, 1.0) = 0.58;
uniform float elapsed_brightness : hint_range(0.0, 1.0) = 0.82;
uniform float flash_strength : hint_range(0.0, 2.0) = 0.0;

const float TAU_VALUE = 6.28318530718;


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (source.a <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		vec2 from_center = UV - vec2(0.5);
		// atan(x, -y) starts at 12 o'clock and increases clockwise in Godot's
		// screen-space UV coordinates.
		float angle = atan(from_center.x, -from_center.y);
		float clockwise = mod(angle / TAU_VALUE + 1.0, 1.0);
		float covered = max(cooldown_ratio, unavailable);
		float dimmed_sector = step(clockwise, covered);
		float cooldown_active = step(0.0001, covered);

		float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
		vec3 grey = vec3(luminance);
		vec3 dimmed = mix(source.rgb, grey, desaturation_amount) * cooldown_dim;
		vec3 deeper_sector = dimmed * 0.72;
		vec3 elapsed_color = min(source.rgb * elapsed_brightness, vec3(1.0));
		vec3 cooldown_color = mix(elapsed_color, deeper_sector, dimmed_sector);
		vec3 output_color = mix(source.rgb, cooldown_color, cooldown_active);
		// A short additive flash keeps the authored icon readable on activation
		// before the radial cooldown treatment settles over it.
		output_color = min(output_color + vec3(flash_strength), vec3(1.0));
		COLOR = vec4(output_color, source.a);
	}
}
