shader_type canvas_item;

uniform float base_height = 0;

void fragment() {
	vec4 height_colour = texture(TEXTURE, UV);

    COLOR = vec4(
            height_colour.r + base_height / 255.0,
            height_colour.g,
            height_colour.b,
            height_colour.a
        );

}
