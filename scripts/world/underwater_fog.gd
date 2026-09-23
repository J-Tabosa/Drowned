extends CanvasLayer

@onready var veil: ColorRect = $Veil

var _fog_time := 0.0
var _player: Node2D


func _ready() -> void:
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_shader(0.0)


func _process(delta: float) -> void:
	_fog_time += delta
	_update_shader(_fog_time)


func set_fog_enabled(enabled: bool) -> void:
	veil.visible = enabled


func _update_shader(time_value: float) -> void:
	var material := veil.material as ShaderMaterial
	if material == null:
		return
	var viewport := get_viewport()
	var inverse := viewport.get_canvas_transform().affine_inverse()
	var origin := inverse * Vector2.ZERO
	material.set_shader_parameter("fog_time", time_value)
	material.set_shader_parameter("viewport_size", viewport.get_visible_rect().size)
	material.set_shader_parameter("world_origin", origin)
	material.set_shader_parameter("world_axis_x", inverse * Vector2.RIGHT - origin)
	material.set_shader_parameter("world_axis_y", inverse * Vector2.DOWN - origin)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(_player):
		material.set_shader_parameter("player_screen", viewport.get_canvas_transform() * _player.global_position)
