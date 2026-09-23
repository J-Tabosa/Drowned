extends Area2D

var direction := Vector2.RIGHT
var speed := 680.0
var damage := 25.0
var knockback_force := 210.0
var _world_bounds := Rect2(-80, -80, 2460, 1560)
var _flight_time := 0.0


## Configura aparência, direção e dano antes de o projétil entrar na árvore da cena.
func setup(_projectile_color: Color, travel_direction: Vector2, attack_damage: float, travel_speed := 680.0, projectile_knockback := 210.0) -> void:
	direction = travel_direction.normalized()
	damage = attack_damage
	speed = travel_speed
	knockback_force = projectile_knockback
	rotation = direction.angle()
	$Body.color = Color("73d3df")


## Conecta a colisão do projétil às Hurtboxes de inimigos.
func _ready() -> void:
	area_entered.connect(_on_area_entered)
	var arena := get_tree().get_first_node_in_group("walkable_area")
	if is_instance_valid(arena):
		_world_bounds = arena.get_world_rect().grow(80.0)


## Faz a esteira e o brilho oscilarem durante o voo, sem alterar a cadência do disparo.
func _process(delta: float) -> void:
	_flight_time += delta
	$Body/Glow.modulate.a = 0.72 + 0.28 * sin(_flight_time * 27.0)
	$Wake.points = PackedVector2Array([
		Vector2(-48.0 - 5.0 * sin(_flight_time * 31.0), 0.0),
		Vector2(-15.0, 0.0),
	])
	$Wake.modulate.a = 0.62 + 0.18 * sin(_flight_time * 23.0)
	$WakeHighlight.modulate.a = 0.48 + 0.22 * sin(_flight_time * 35.0)


## Move o disparo em linha reta e o remove quando ele deixa os limites amplos do mapa.
func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if not _world_bounds.has_point(global_position):
		queue_free()


## Aplica dano ao primeiro alvo válido e consome o projétil após o acerto.
func _on_area_entered(area: Area2D) -> void:
	if area.has_method("receive_hit") and area.receive_hit(damage, global_position, knockback_force):
		queue_free()
