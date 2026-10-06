extends Area2D

@export var damage := 10.0
@export var knockback_force := 180.0

var _hit_targets: Dictionary = {}
var _activation_id := 0
var _active := false


## Começa desativada e conecta a detecção de áreas que entrarem durante um ataque.
func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)


## Ativa a área pelo tempo informado e garante apenas um acerto por alvo nessa ativação.
func activate(duration: float) -> void:
	_activation_id += 1
	var activation := _activation_id
	_active = true
	_hit_targets.clear()
	monitoring = true
	await get_tree().physics_frame
	if activation != _activation_id:
		return
	for area in get_overlapping_areas():
		_apply_hit(area)
	await get_tree().create_timer(duration, false).timeout
	if activation == _activation_id:
		_active = false
		monitoring = false


## Cancela uma ativação pendente ao morrer, interromper um ataque ou alcançar uma parede.
func deactivate() -> void:
	_activation_id += 1
	_active = false
	set_deferred("monitoring", false)


## Encaminha novas sobreposições para a rotina central de aplicação de dano.
func _on_area_entered(area: Area2D) -> void:
	_apply_hit(area)


## Valida a Hurtbox, aplica dano e recuo e memoriza o alvo já atingido.
func _apply_hit(area: Area2D) -> void:
	if not _active or not monitoring or not area.has_method("receive_hit"):
		return
	var target_id := area.get_instance_id()
	if _hit_targets.has(target_id):
		return
	if area.receive_hit(damage, global_position, knockback_force):
		_hit_targets[target_id] = true
