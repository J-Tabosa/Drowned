shader_type canvas_item;
uniform float phase = 0.0;
uniform float storm = 0.0;

void fragment() {
	vec2 uv = UV;
	if (uv.y > 0.48) {
		float band = floor(uv.y * 135.0);
		uv.x += sin(band * 0.42 + phase * (1.0 + storm)) * (0.002 + storm * 0.006);
		uv.x = clamp(uv.x, 0.001, 0.999);
	}
	vec4 col = texture(TEXTURE, uv);
	float sky = 1.0 - smoothstep(0.43, 0.52, uv.y);
	vec3 night = col.rgb * vec3(0.23, 0.31, 0.48);
	night = mix(night, vec3(0.035, 0.055, 0.10), sky * 0.48);
	COLOR = vec4(mix(col.rgb, night, storm), col.a);
}
