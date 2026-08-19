extends Node

const CHARACTER_PROFILES: Array[Dictionary] = [
	{
		"id": "breaker",
		"name": "Quebra-Mar",
		"role": "Combate próximo",
		"description": "Resistente e direto. Seu golpe cobre uma área curta à frente.",
		"color": Color("e85d75"),
		"speed": 245.0,
		"max_health": 140.0,
		"damage": 45.0,
		"action": "melee",
		"action_name": "Golpe de Âncora",
		"cooldown": 0.42,
	},
	{
		"id": "sharpshooter",
		"name": "Vigia",
		"role": "Combate à distância",
		"description": "Ágil e precisa. Dispara na direção do cursor ou do movimento.",
		"color": Color("f4b942"),
		"speed": 265.0,
		"max_health": 100.0,
		"damage": 28.0,
		"action": "shoot",
		"action_name": "Disparo de Sinalizador",
		"cooldown": 0.28,
	},
	{
		"id": "diver",
		"name": "Mergulhador",
		"role": "Mobilidade",
		"description": "Explorador veloz. Avança rapidamente e atravessa o perigo.",
		"color": Color("42c6d7"),
		"speed": 280.0,
		"max_health": 110.0,
		"damage": 32.0,
		"action": "dash",
		"action_name": "Investida de Maré",
		"cooldown": 0.72,
	},
]

var selected_character_id: String = "breaker"


## Procura e devolve os dados do personagem selecionado, usando o primeiro perfil como segurança.
func get_selected_profile() -> Dictionary:
	for profile in CHARACTER_PROFILES:
		if profile.id == selected_character_id:
			return profile
	return CHARACTER_PROFILES[0]


## Registra o identificador escolhido para que ele persista durante a troca de cenas.
func select_character(character_id: String) -> void:
	selected_character_id = character_id
