extends Area2D

var direction := Vector2.RIGHT
var speed := 680.0
var damage := 25.0
var _world_bounds := Rect2(-80, -80, 2460, 1560)


## Configura aparência, direção e dano antes de o projétil entrar na árvore da cena.
func setup(projectile_color: Color, travel_direction: Vector2, attack_damage: float) -> void:
	direction = travel_direction.normalized()
	damage = attack_damage
	rotation = direction.angle()
	$Body.color = projectile_color


## Conecta a colisão do projétil às Hurtboxes de inimigos.
func _ready() -> void:
	area_entered.connect(_on_area_entered)
	var arena := get_tree().get_first_node_in_group("walkable_area")
	if is_instance_valid(arena):
		_world_bounds = arena.get_world_rect().grow(80.0)


## Move o disparo em linha reta e o remove quando ele deixa os limites amplos do mapa.
func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if not _world_bounds.has_point(global_position):
		queue_free()


## Aplica dano ao primeiro alvo válido e consome o projétil após o acerto.
func _on_area_entered(area: Area2D) -> void:
	if area.has_method("receive_hit") and area.receive_hit(damage, global_position, 210.0):
		queue_free()
