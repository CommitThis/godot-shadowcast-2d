shader_type canvas_item;

uniform float base_height = 0;

void fragment() {
	vec4 height_colour = texture(TEXTURE, UV);

    float normalised_height = base_height / 255.0;
    COLOR = vec4(
            normalised_height + (height_colour.r), // Above
            normalised_height - (height_colour.g), // Below
            height_colour.b,
            height_colour.a
        );
}


