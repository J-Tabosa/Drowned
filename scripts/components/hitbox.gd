extends Area2D

@export var damage := 10.0
@export var knockback_force := 180.0

var _hit_targets: Dictionary = {}


## Começa desativada e conecta a detecção de áreas que entrarem durante um ataque.
func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)


## Ativa a área pelo tempo informado e garante apenas um acerto por alvo nessa ativação.
func activate(duration: float) -> void:
	_hit_targets.clear()
	monitoring = true
	await get_tree().physics_frame
	for area in get_overlapping_areas():
		_apply_hit(area)
	await get_tree().create_timer(duration).timeout
	monitoring = false


## Encaminha novas sobreposições para a rotina central de aplicação de dano.
func _on_area_entered(area: Area2D) -> void:
	_apply_hit(area)


## Valida a Hurtbox, aplica dano e recuo e memoriza o alvo já atingido.
func _apply_hit(area: Area2D) -> void:
	if not monitoring or not area.has_method("receive_hit"):
		return
	var target_id := area.get_instance_id()
	if _hit_targets.has(target_id):
		return
	if area.receive_hit(damage, global_position, knockback_force):
		_hit_targets[target_id] = true
