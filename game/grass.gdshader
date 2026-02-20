shader_type spatial;

uniform sampler2D tex;
uniform vec3 background : source_color = vec3(0.15, 0.5, 0.15);
uniform vec3 lines : source_color = vec3(0.25, 0.7, 0.25);

void fragment() {
    float mask = texture(tex, UV).r;
    ALBEDO = mix(background, lines, mask);
}
