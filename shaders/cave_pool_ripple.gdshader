shader_type canvas_item;

uniform float phase_offset = 0.0;

varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	float row = floor(UV.y / TEXTURE_PIXEL_SIZE.y);
	float wave = sin(TIME * 1.35 + row * 0.43 + phase_offset);
	float pixel_shift = floor(wave + 0.5) * TEXTURE_PIXEL_SIZE.x;
	vec2 moved_uv = fract(UV + vec2(pixel_shift, 0.0));
	vec4 water = texture(TEXTURE, moved_uv);
	float glimmer = 0.97 + 0.03 * sin(TIME * 1.1 + floor(UV.x * 8.0) + phase_offset);
	COLOR = vec4(water.rgb * glimmer, water.a) * vertex_tint;
}
