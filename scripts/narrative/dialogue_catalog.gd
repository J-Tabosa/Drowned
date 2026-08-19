extends RefCounted


## Monta uma introdução com o jogador ao centro, dois amigos e a entrada de um monstro.
static func get_intro(character_id: String) -> Dictionary:
	var player := _profile(character_id)
	var friends: Array[Dictionary] = []
	for profile in GameState.CHARACTER_PROFILES:
		if profile.id != character_id:
			friends.append(_profile(profile.id))
	var friend_left: Dictionary = friends[0]
	var friend_right: Dictionary = friends[1]
	var monster := {
		"id": "abyssal_creature",
		"name": "Criatura Abissal",
		"color": Color("8f5bb7"),
		"portrait": null,
	}
	return _build_sequence(
		{
			"player": player,
			"friend_left": friend_left,
			"friend_right": friend_right,
			"monster": monster,
		},
		{
			"left": "friend_left",
			"center": "player",
			"right": "friend_right",
		},
		[
			{
				"actor": "friend_left",
				"text": "Finalmente! %s, você está inteiro." % player.name,
			},
			{
				"actor": "player",
				"text": "Por pouco. E vocês dois? A corrente separou o resto da tripulação.",
			},
			{
				"actor": "friend_right",
				"text": "Estamos vivos. Mas há alguma coisa circulando entre aquelas ruínas.",
			},
			{
				"actor": "player",
				"text": "Fiquem perto. Encontramos uma saída juntos.",
			},
			{
				"actor": "monster",
				"transitions": [
					{"action": "exit", "slot": "left"},
					{"action": "replace", "slot": "right", "actor": "monster"},
				],
				"text": "A superfície continua devolvendo náufragos às nossas portas.",
			},
			{
				"actor": "player",
				"text": "Se entende nossa língua, então entende isto: fique longe deles.",
			},
			{
				"actor": "monster",
				"text": "Atlântida não pertence aos vivos.",
			},
		]
	)


## Converte um perfil jogável no formato usado pelo registro de atores do diálogo.
static func _profile(character_id: String) -> Dictionary:
	for profile in GameState.CHARACTER_PROFILES:
		if profile.id == character_id:
			return {
				"id": profile.id,
				"name": profile.name,
				"color": profile.color,
				"portrait": null,
			}
	return {}


## Agrupa registro de atores, ocupação inicial e linhas no contrato consumido pelo manager.
static func _build_sequence(actors: Dictionary, initial_slots: Dictionary, lines: Array) -> Dictionary:
	return {
		"actors": actors,
		"initial_slots": initial_slots,
		"lines": lines,
		"characters_per_second": 42.0,
	}
