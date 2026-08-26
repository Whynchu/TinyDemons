shader_type canvas_item;

uniform sampler2D grey_texture : filter_nearest;
uniform float grey_mix : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec4 grey = texture(grey_texture, UV);
	if (grey_mix <= 0.001) {
		COLOR = source;
	} else if (grey_mix >= 0.999) {
		COLOR = grey;
	} else {
		COLOR = mix(source, grey, grey_mix);
	}
}
