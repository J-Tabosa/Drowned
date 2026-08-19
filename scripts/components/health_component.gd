extends Node

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source_position: Vector2)
signal healed(amount: float)
signal died

@export var max_health := 100.0

var current_health := 100.0


## Inicializa a vida atual no máximo e avisa qualquer HUD já conectado.
func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


## Redefine a vida máxima e começa o componente completamente curado.
func configure(new_max_health: float) -> void:
	max_health = new_max_health
	current_health = max_health
	health_changed.emit(current_health, max_health)


## Subtrai dano válido, emite os sinais de atualização e dispara a morte ao chegar a zero.
func take_damage(amount: float, source_position := Vector2.ZERO) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	var previous := current_health
	current_health = maxf(0.0, current_health - amount)
	damaged.emit(previous - current_health, source_position)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		died.emit()


## Recupera vida sem ultrapassar o máximo e ignora atores que já morreram.
func heal(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	var previous := current_health
	current_health = minf(max_health, current_health + amount)
	healed.emit(current_health - previous)
	health_changed.emit(current_health, max_health)


## Restaura toda a vida usando a mesma regra pública de cura.
func heal_full() -> void:
	heal(max_health)


## Remove toda a vida restante; é usado pelo botão de morte e por testes.
func kill() -> void:
	take_damage(current_health)
