shader_type canvas_item;

uniform sampler2D grey_texture : filter_nearest;
uniform float grey_mix : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec4 grey = texture(grey_texture, UV);
	if (grey_mix <= 0.001) {
		COLOR = source;
	} else if (grey_mix >= 0.999) {
		// Keep alpha owned by the source texture. The source may be an
		// occlusion/dither texture; taking grey.a here restores the covered
		// pixels whenever the player's Chroma reaches zero.
		COLOR = vec4(grey.rgb, source.a);
	} else {
		COLOR = vec4(mix(source.rgb, grey.rgb, grey_mix), source.a);
	}
}
