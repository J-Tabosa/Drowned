extends Node2D
## Warned, position-locked strike. A player who keeps moving can leave its shadow.

var target: Node2D
var boss: Node2D
var warning_time := 1.0
var damage := 24.0
var radius := 48.0
var _age := 0.0
var _hit := false
var _cancelled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("boss_hazards")
	z_index = 6


func _process(delta: float) -> void:
	if not is_instance_valid(boss) or boss._dead or not is_instance_valid(target) or target._dead:
		_cancelled = true
		queue_free()
		return
	_age += delta
	if _age >= warning_time + 0.20 and not _hit:
		_hit = true
		if global_position.distance_to(target.global_position) <= radius:
			target.get_node("Hurtbox").receive_hit(damage, global_position - Vector2(0, 12), 190.0)
		var feedback := preload("res://scripts/components/gameplay_feedback.gd")
		feedback.impact(get_parent(), global_position, Vector2.DOWN, true)
		feedback.sound(self, "heavy_hit")
	if _age > warning_time + 0.7:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if _cancelled:
		return
	var warning := clampf(_age / warning_time, 0.0, 1.0)
	if not _hit:
		# Angular ground shadow and crossing cracks are distinct from spawn circles.
		var diamond := PackedVector2Array([Vector2(-radius, 0), Vector2(0, -radius * 0.55),
			Vector2(radius, 0), Vector2(0, radius * 0.55)])
		draw_colored_polygon(diamond, Color(0.95, 0.46, 0.27, 0.15 + warning * 0.2))
		draw_polyline(PackedVector2Array([Vector2(-radius, 0), Vector2(-12, 6), Vector2(0, -5), Vector2(radius, 0)]),
			Color("efa16b"), 2.0)
		draw_line(Vector2(0, -radius * 0.5), Vector2(0, radius * 0.5), Color("efa16b"), 2.0)
	if _age >= warning_time:
		var fall := clampf((_age - warning_time) / 0.20, 0.0, 1.0)
		var offset := Vector2(0, -260 * (1.0 - fall))
		draw_colored_polygon(PackedVector2Array([offset + Vector2(-17, -70),
			offset + Vector2(17, -70), offset + Vector2(10, -22), offset]), Color("576873"))
		draw_colored_polygon(PackedVector2Array([offset + Vector2(-17, -70),
			offset + Vector2(-7, -67), offset + Vector2(-3, -24), offset]), Color("88979b"))
	if _hit:
		for index in 5:
			var angle := TAU * index / 5.0
			var distance := (_age - warning_time - 0.2) * 65.0
			draw_rect(Rect2((Vector2.from_angle(angle) * distance).round(), Vector2(6, 4)), Color("6d7f87"))
