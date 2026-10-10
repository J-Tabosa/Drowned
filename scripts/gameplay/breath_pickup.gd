extends Node2D
## Pixel motes home toward the player. Mob motes restore breath, never skill XP.

var player: Node2D
var arena: Node2D
var is_boss_xp := false
var _age := 0.0
var _collected := false
var _speed := 80.0
var _trail: Array[Vector2] = []
var _trail_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 5
	add_to_group("boss_xp_motes" if is_boss_xp else "breath_pickups")


func _process(delta: float) -> void:
	_age += delta
	if _age > 24.0:
		queue_free()
		return
	if not is_instance_valid(player) or player._dead or _collected:
		return
	var distance := global_position.distance_to(player.global_position)
	if _age > 0.25 and (is_boss_xp or distance < 260.0):
		var target: Vector2 = player.global_position
		if is_instance_valid(arena):
			var reachable: Vector2 = arena.get_farthest_walkable_position(global_position, target, 4.0)
			if reachable.distance_to(target) > 12.0:
				var path: PackedVector2Array = arena.get_enemy_path(global_position, target, 4.0)
				while not path.is_empty() and global_position.distance_to(path[0]) < 14.0:
					path.remove_at(0)
				if path.is_empty():
					queue_redraw()
					return
				target = path[0]
		_speed = minf(620.0, _speed + delta * 600.0)
		var next := global_position.move_toward(target, delta * _speed)
		if is_instance_valid(arena):
			next = arena.get_farthest_walkable_position(global_position, next, 4.0)
		global_position = next
	_trail_time += delta
	if _trail_time >= 0.06:
		_trail_time = 0.0
		_trail.append(global_position)
		if _trail.size() > 5:
			_trail.pop_front()
	if global_position.distance_to(player.global_position) < 28.0:
		_collected = true
		if not is_boss_xp:
			player.health_component.heal(5.0)
			player.skill_cooldown_remaining = maxf(0.0, player.skill_cooldown_remaining - 0.8)
		preload("res://scripts/components/gameplay_feedback.gd").burst(get_parent(), global_position,
			Color("e8c36d") if is_boss_xp else Color("83dfbe"))
		queue_free()
	queue_redraw()


func _draw() -> void:
	var tint := Color("e8c36d") if is_boss_xp else Color("83dfbe")
	for index in _trail.size():
		draw_rect(Rect2(to_local(_trail[index]).round() - Vector2(1, 1), Vector2(3, 3)),
			Color(tint, float(index + 1) / 8.0))
	var rise := roundf(sin(_age * 4.0) * 2.0)
	draw_rect(Rect2(-7, -7 + rise, 14, 14), Color(tint, 0.12))
	draw_rect(Rect2(-4, -4 + rise, 8, 8), tint.darkened(0.28))
	draw_rect(Rect2(-3, -3 + rise, 5, 5), tint)
	draw_rect(Rect2(-2, -3 + rise, 2, 2), Color("f1ffe8"))
