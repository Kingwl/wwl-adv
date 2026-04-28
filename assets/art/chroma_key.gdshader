shader_type canvas_item;

uniform vec4 chroma_key : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform float tolerance : hint_range(0.0, 1.0) = 0.15;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    float diff = distance(color.rgb, chroma_key.rgb);
    if (diff < tolerance) {
        color.a = 0.0;
    }
    COLOR = color;
}
