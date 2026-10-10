shader_type canvas_item;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	// Sprite atlas has five animation rows; reveal boots, torso, then head.
	float row_y = fract(UV.y * 5.0);
	if (row_y < 1.0 - reveal) {
		COLOR.a = 0.0;
	}
}
