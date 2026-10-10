extends Node2D
## Pequeno recurso temporário: exige buscar a posição do inimigo derrotado.

var player: Node2D
var arena: Node2D
var _age := 0.0
var _collected := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 5
	add_to_group("breath_pickups")

func _process(delta: float) -> void:
	_age += delta
	if _age > 14.0:
		queue_free()
		return
	queue_redraw()
	if _collected or not is_instance_valid(player) or player._dead or not player._controls_enabled:
		return
	if global_position.distance_to(player.global_position) > 58.0:
		return
	if is_instance_valid(arena) and arena.get_farthest_walkable_position(global_position, player.global_position, 4.0).distance_to(player.global_position) > 12.0:
		return
	_collected = true
	player.health_component.heal(5.0)
	player.skill_cooldown_remaining = maxf(0.0, player.skill_cooldown_remaining - 0.8)
	preload("res://scripts/components/gameplay_feedback.gd").burst(get_parent(), global_position, Color("83dfbe"))
	queue_free()

func _draw() -> void:
	var tint := Color("83dfbe")
	tint.a = clampf(14.0 - _age, 0.0, 1.0)
	var rise := sin(_age * 4.0) * 3.0
	draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 24, Color(tint, tint.a * 0.35), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -11 + rise), Vector2(7, rise), Vector2(0, 11 + rise), Vector2(-7, rise)]), tint)
