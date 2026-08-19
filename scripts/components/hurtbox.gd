extends Area2D

@export_node_path("Node") var health_component_path: NodePath

@onready var health_component: Node = get_node(health_component_path)


## Pergunta ao ator se ele pode sofrer dano e, em caso positivo, atualiza vida e recuo.
func receive_hit(damage: float, source_position: Vector2, knockback_force := 0.0) -> bool:
	var actor := get_parent()
	if actor.has_method("can_receive_damage") and not actor.can_receive_damage():
		return false
	health_component.take_damage(damage, source_position)
	if knockback_force > 0.0 and actor.has_method("receive_knockback"):
		actor.receive_knockback(source_position, knockback_force)
	return true
