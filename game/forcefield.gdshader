shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled;

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 5.0) = 1.0;

void fragment() {
    ALBEDO = color.rgb;
    EMISSION = glow_color.rgb * glow_intensity;
    ALPHA = 0.2; // mesh itself is invisible, only emission shows
}