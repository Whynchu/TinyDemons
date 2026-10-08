shader_type canvas_item;
render_mode unshaded;

// One shared field: source brightness is selected, never added.
const int MAX_LIGHTS = 64;
uniform int light_count = 0;
uniform vec4 light_centers[MAX_LIGHTS]; // world center xy, energy z
uniform vec4 light_inverse_axes[MAX_LIGHTS]; // normalized inverse 2x2
uniform vec4 light_colors[MAX_LIGHTS];
uniform float ambient = 0.64;
uniform float inner_radius = 0.58;
uniform float inner_level = 0.78;
uniform float outer_level = 0.40;

varying vec2 world_position;
varying vec4 vertex_tint;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
    vertex_tint = COLOR;
}

void fragment() {
    vec2 world_pixel = floor(world_position) + vec2(0.5);
    float strongest = 0.0;
    vec3 tint_sum = vec3(0.0);
    float tint_count = 0.0;
    for (int i = 0; i < MAX_LIGHTS; i++) {
        if (i >= light_count) { break; }
        vec2 delta = world_pixel - light_centers[i].xy;
        vec4 axes = light_inverse_axes[i];
        vec2 local = vec2(dot(axes.xy, delta), dot(axes.zw, delta));
        float radius_squared = dot(local, local);
        float band = radius_squared < inner_radius * inner_radius ? inner_level : outer_level;
        float strength = radius_squared < 1.0 ? band * light_centers[i].z : 0.0;
        if (strength > strongest + 0.000001) {
            strongest = strength;
            tint_sum = light_colors[i].rgb;
            tint_count = 1.0;
        } else if (strength > 0.0 && abs(strength - strongest) <= 0.000001) {
            tint_sum += light_colors[i].rgb;
            tint_count += 1.0;
        }
    }
    vec3 illumination = vec3(ambient) + strongest * tint_sum / max(tint_count, 1.0);
    COLOR = texture(TEXTURE, UV) * vertex_tint * vec4(illumination, 1.0);
}
