shader_type canvas_item;

// GPU palette swap for pixel-art actors. Replaces up to four exact source
// colors with target colors, reproducing SpriteFrameLibrary's CPU recolor
// without generating a separate texture per palette.
//
// The source colors are byte-exact in the authored art, so keep `tolerance`
// small; a loose tolerance would also recolor incidental near-matches on
// antialiased or dithered pixels.
uniform vec4 from_color[4] : source_color;
uniform vec4 to_color[4] : source_color;
uniform float tolerance : hint_range(0.0, 0.5) = 0.002;

// Fragment COLOR already includes the sampled texture in CanvasItem shaders.
// Carry the vertex tint separately so the swapped texture is only sampled once.
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	for (int i = 0; i < 4; i++) {
		if (distance(tex.rgb, from_color[i].rgb) < tolerance) {
			tex.rgb = to_color[i].rgb;
			break;
		}
	}
	COLOR = tex * vertex_tint;
}
