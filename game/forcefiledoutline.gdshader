shader_type spatial;
render_mode cull_front;


uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
    ALBEDO = outline_color.rgb;
    ALPHA = 0.2;
}