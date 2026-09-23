extends RefCounted


## Monta a conversa inicial somente com o trio, apresentando a exploração da caverna.
static func get_intro(character_id: String) -> Dictionary:
	var player := _profile(character_id)
	var friends: Array[Dictionary] = []
	for profile in GameState.CHARACTER_PROFILES:
		if profile.id != character_id:
			friends.append(_profile(profile.id))
	var friend_left: Dictionary = friends[0]
	var friend_right: Dictionary = friends[1]
	return _build_sequence(
		{
			"player": player,
			"friend_left": friend_left,
			"friend_right": friend_right,
		},
		{
			"left": "friend_left",
			"center": "player",
			"right": "friend_right",
		},
		[
			{
				"actor": "friend_left",
				"text": "Ainda estamos inteiros. Já é mais do que eu esperava depois daquela corrente.",
			},
			{
				"actor": "friend_right",
				"text": "A água trouxe a gente para uma caverna enorme. Deve existir outra passagem por aqui.",
			},
			{
				"actor": "player",
				"text": "Então vamos explorar a área. Devagar, procurando sinais de uma saída e do resto da tripulação.",
			},
			{
				"actor": "friend_left",
				"text": "Sem se separar desta vez. Se alguma coisa se mover, avisem antes de atacar.",
			},
			{
				"actor": "player",
				"text": "Combinado. Fiquem perto de mim. Vamos descobrir onde fomos parar.",
			},
		]
	)


## Pequenos achados no ritmo da exploração, sem transformar o tutorial em um bloco de texto.
static func get_exploration_echo(character_id: String, echo_index: int) -> Dictionary:
	var player := _profile(character_id)
	var companion := {}
	for profile in GameState.CHARACTER_PROFILES:
		if profile.id != character_id:
			companion = _profile(profile.id)
			break
	var conversations := [
		[
			{"actor": "companion", "text": "Essas marcas não são naturais. Alguém tentou indicar um caminho antes de nós."},
			{"actor": "player", "text": "Então seguimos os sinais, mas sem baixar a guarda."},
		],
		[
			{"actor": "player", "text": "Pegadas recentes. Elas entram na câmara, mas nenhuma volta."},
			{"actor": "companion", "text": "Os ruídos estão mais próximos. Seja o que for, já sabe que chegamos."},
		],
		[
			{"actor": "companion", "text": "O selo está ligado à passagem. As criaturas devem estar mantendo o portão fechado."},
			{"actor": "player", "text": "Limpamos a câmara e seguimos até a fonte desse lugar."},
		],
	]
	var safe_index := clampi(echo_index, 0, conversations.size() - 1)
	return _build_sequence(
		{"player": player, "companion": companion},
		{"center": "player", "right": "companion"},
		conversations[safe_index]
	)


## Monta o diálogo disparado após os mobs, enquanto a câmera revela o mini-chefe.
static func get_boss_reveal(character_id: String) -> Dictionary:
	var player := _profile(character_id)
	var friends: Array[Dictionary] = []
	for profile in GameState.CHARACTER_PROFILES:
		if profile.id != character_id:
			friends.append(_profile(profile.id))
	var friend_left: Dictionary = friends[0]
	var friend_right: Dictionary = friends[1]
	return _build_sequence(
		{
			"player": player,
			"friend_left": friend_left,
			"friend_right": friend_right,
		},
		{
			"left": "friend_left",
			"center": "player",
			"right": "friend_right",
		},
		[
			{
				"actor": "friend_right",
				"text": "O que raios é aquilo?",
			},
			{
				"actor": "friend_left",
				"text": "Não é igual aos Afogados que enfrentamos. Aquilo estava esperando por nós.",
			},
			{
				"actor": "player",
				"text": "É o guardião desta passagem. Não entrem na sala até estarmos prontos.",
			},
			{
				"actor": "friend_right",
				"text": "Ótimo. Um monstro gigante entre nós e a única saída.",
			},
			{
				"actor": "player",
				"text": "Fiquem atentos ao avanço dele. Quando abrir uma brecha, nós atacamos juntos.",
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
				"portrait": profile.get("portrait", ""),
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
