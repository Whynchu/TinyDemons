shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_threshold = 0.05;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (base.a > alpha_threshold) {
		COLOR = base;
	} else {
		float outline_alpha = 0.0;
		outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a);
		outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(-TEXTURE_PIXEL_SIZE.x, 0.0)).a);
		outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a);
		outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(0.0, -TEXTURE_PIXEL_SIZE.y)).a);
		outline_alpha = max(outline_alpha, texture(TEXTURE, UV + TEXTURE_PIXEL_SIZE).a);
		outline_alpha = max(outline_alpha, texture(TEXTURE, UV - TEXTURE_PIXEL_SIZE).a);
		outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, -TEXTURE_PIXEL_SIZE.y)).a);
		outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(-TEXTURE_PIXEL_SIZE.x, TEXTURE_PIXEL_SIZE.y)).a);

		if (outline_alpha > alpha_threshold) {
			COLOR = outline_color;
		} else {
			COLOR = vec4(0.0);
		}
	}
}
