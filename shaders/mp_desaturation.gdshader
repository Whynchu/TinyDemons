shader_type canvas_item;

// Player/attack material: GPU palette swap folded into the MP-desaturation
// blend so a single material still owns the sprite slot.
//
// Palette swap mirrors SpriteFrameLibrary's actor recolor (blue source tones ->
// current palette). Defaults leave it inert, so equipment layers that share this
// shader are unaffected until a caller sets real color pairs.
uniform vec4 from_color[4] : source_color;
uniform vec4 to_color[4] : source_color;
uniform float tolerance : hint_range(0.0, 0.5) = 0.002;

uniform sampler2D grey_texture : filter_nearest;
uniform float grey_mix : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	for (int i = 0; i < 4; i++) {
		if (distance(source.rgb, from_color[i].rgb) < tolerance) {
			source.rgb = to_color[i].rgb;
			break;
		}
	}
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
