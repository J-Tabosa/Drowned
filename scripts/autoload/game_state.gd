extends Node

signal progression_changed(character_id: String)
const SKILLS := preload("res://scripts/gameplay/skill_catalog.gd")
const PROGRESSION_FILE := "user://progression.cfg"
var _progression: Dictionary = {}

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
		"passive_name": "Maré de Ferro",
		"passive_description": "Acertos dão +10% de dano por carga (até 3), por 8 s.",
		"skill_name": "Âncora Giratória",
		"skill_description": "Varre ao redor e consome as cargas para causar mais dano.",
		"skill_cooldown": 7.0,
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
		"damage": 32.0,
		"action": "shoot",
		"action_name": "Disparo de Arpão",
		"cooldown": 0.78,
		"passive_name": "Mira Firme",
		"passive_description": "Pare por 1,2 s: o próximo arpão ganha +25% de dano e perfura 2 alvos.",
		"skill_name": "Salva de Arpões",
		"skill_description": "Dispara 5 arpões em leque que atravessam até 3 alvos cada.",
		"skill_cooldown": 6.0,
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
		"passive_name": "Segundo Fôlego",
		"passive_description": "Acertar o retorno do mergulho cura 6 de vida e dá +20% de velocidade por 2 s.",
		"skill_name": "Correnteza Abissal",
		"skill_description": "Cria uma correnteza no cursor: 5 pulsos puxam e ferem inimigos.",
		"skill_cooldown": 8.0,
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


# Preferência persistida, disponível também na primeira conversa do prólogo.
const DIALOGUE_SPEEDS := [22.0, 42.0, 75.0, 0.0]
var dialogue_speed_index := 1

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("user://preferences.cfg") == OK:
		dialogue_speed_index = clampi(int(config.get_value("dialogue", "speed", 1)), 0, 3)
	_load_progression()

func set_dialogue_speed(index: int) -> void:
	dialogue_speed_index = clampi(index, 0, 3)
	var config := ConfigFile.new()
	config.load("user://preferences.cfg")
	config.set_value("dialogue", "speed", dialogue_speed_index)
	config.save("user://preferences.cfg")

func get_dialogue_speed() -> float:
	return DIALOGUE_SPEEDS[dialogue_speed_index]


func _valid_character(character_id: String) -> bool:
	for profile in CHARACTER_PROFILES:
		if profile.id == character_id:
			return true
	return false


func _load_progression() -> void:
	var config := ConfigFile.new()
	config.load(PROGRESSION_FILE)
	_progression.clear()
	for profile in CHARACTER_PROFILES:
		var learned: Array[String] = []
		for skill_id in config.get_value(profile.id, "learned", []):
			if skill_id is String and not SKILLS.find_skill(profile.id, skill_id).is_empty() and not learned.has(skill_id):
				learned.append(skill_id)
		_progression[profile.id] = {"xp": maxi(0, int(config.get_value(profile.id, "xp", 0))), "learned": learned}


func _save_progression() -> void:
	var config := ConfigFile.new()
	for character_id in _progression:
		config.set_value(character_id, "xp", _progression[character_id].xp)
		config.set_value(character_id, "learned", _progression[character_id].learned)
	config.save(PROGRESSION_FILE)


func get_skill_xp(character_id: String) -> int:
	return int(_progression.get(character_id, {}).get("xp", 0))


func get_learned_skills(character_id: String) -> Array:
	return _progression.get(character_id, {}).get("learned", []).duplicate()


func has_skill(character_id: String, skill_id: String) -> bool:
	return get_learned_skills(character_id).has(skill_id)


## Only the prologue boss reward is admitted here; ordinary enemies grant breath.
func collect_boss_xp(character_id: String, amount: int, boss_id: String) -> bool:
	if boss_id != "guardian_prologue" or not _valid_character(character_id) or amount <= 0 or amount > 100:
		return false
	_progression[character_id].xp += amount
	_save_progression()
	progression_changed.emit(character_id)
	return true


func can_learn_skill(character_id: String, skill_id: String) -> bool:
	if not _valid_character(character_id) or has_skill(character_id, skill_id):
		return false
	var skill := SKILLS.find_skill(character_id, skill_id)
	if skill.is_empty():
		return false
	return get_skill_xp(character_id) >= skill.cost and (skill.requires.is_empty() or has_skill(character_id, skill.requires))


func learn_skill(character_id: String, skill_id: String) -> bool:
	if not can_learn_skill(character_id, skill_id):
		return false
	var skill := SKILLS.find_skill(character_id, skill_id)
	_progression[character_id].xp -= int(skill.cost)
	_progression[character_id].learned.append(skill_id)
	_save_progression()
	progression_changed.emit(character_id)
	return true
