extends Node

const CHARACTER_PROFILES: Array[Dictionary] = [
	{
		"id": "breaker",
		"name": "Quebra-Mar",
		"role": "Combate próximo",
		"description": "Resistente e direto. Seu golpe cobre uma área curta à frente.",
		"color": Color("e85d75"),
		"sprite": "res://assets/sprites/characters/quebra_mar_idle_32.png",
		"animation_sheet": "res://assets/sprites/characters/animations/quebra_mar_sheet_96.png",
		"portrait": "res://assets/sprites/characters/quebra_mar_source.png",
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
		"description": "Ágil e precisa. Dispara arpões velozes e fortes com cadência controlada.",
		"color": Color("f4b942"),
		"sprite": "res://assets/sprites/characters/vigia_idle_32.png",
		"animation_sheet": "res://assets/sprites/characters/animations/vigia_sheet_96.png",
		"portrait": "res://assets/sprites/characters/vigia_source.png",
		"speed": 265.0,
		"max_health": 100.0,
		"damage": 44.0,
		"action": "shoot",
		"action_name": "Disparo de Arpão",
		"cooldown": 0.68,
	},
	{
		"id": "diver",
		"name": "Mergulhador",
		"role": "Mergulho e controle",
		"description": "Marca um ponto, desaparece sob a água e retorna com uma onda de impacto.",
		"color": Color("42c6d7"),
		"sprite": "res://assets/sprites/characters/mergulhador_idle_32.png",
		"animation_sheet": "res://assets/sprites/characters/animations/mergulhador_sheet_96.png",
		"portrait": "res://assets/sprites/characters/mergulhador_source.png",
		"speed": 280.0,
		"max_health": 115.0,
		"damage": 38.0,
		"action": "dive",
		"action_name": "Mergulho Abissal",
		"cooldown": 1.1,
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
