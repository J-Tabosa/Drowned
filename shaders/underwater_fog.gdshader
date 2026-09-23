// Adapted from HexagonNico's "2D fog overlay" (CC0):
// https://godotshaders.com/shader/2d-fog-overlay-2/
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D noise_texture: repeat_enable, filter_linear;
uniform float density: hint_range(0.0, 1.0) = 0.29;
uniform vec2 speed = vec2(0.004, -0.002);
uniform float fog_time = 0.0;
uniform vec2 viewport_size = vec2(1152.0, 648.0);
uniform vec2 world_origin = vec2(0.0);
uniform vec2 world_axis_x = vec2(1.0, 0.0);
uniform vec2 world_axis_y = vec2(0.0, 1.0);
uniform vec2 player_screen = vec2(576.0, 324.0);

void fragment() {
	vec2 pixel = UV * viewport_size;
	vec2 world = world_origin + world_axis_x * pixel.x + world_axis_y * pixel.y;
	vec2 uv = world * 0.00072 + speed * fog_time;
	float primary_noise = texture(noise_texture, uv).r;
	// A second, broader sample breaks up the repeat without a visible crossfade.
	float broad_noise = texture(noise_texture, world * 0.00039 + vec2(0.37, 0.18) - speed * fog_time * 0.43).r;
	float noise = mix(primary_noise, broad_noise, 0.35);
	float fog = smoothstep(0.25, 0.75, noise);
	float player_clearing = mix(0.38, 1.0, smoothstep(85.0, 340.0, distance(pixel, player_screen)));
	COLOR.rgb = vec3(0.43, 0.61, 0.64);
	COLOR.a *= fog * density * player_clearing;
}
