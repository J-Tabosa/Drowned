extends Node2D

const DIALOGUE_CATALOG := preload("res://scripts/narrative/dialogue_catalog.gd")


## Desenha um fundo atmosférico provisório para a conversa após o naufrágio.
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 648), Color("071521"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 430), Vector2(180, 350), Vector2(390, 410),
		Vector2(610, 300), Vector2(850, 390), Vector2(1152, 315),
		Vector2(1152, 648), Vector2(0, 648),
	]), Color("123743"))
	for ruin in [Rect2(150, 245, 72, 245), Rect2(830, 195, 90, 305), Rect2(970, 280, 55, 220)]:
		draw_rect(ruin, Color("1d4651"))
		draw_rect(ruin, Color("4e7d83"), false, 3.0)
	draw_circle(Vector2(570, 185), 62.0, Color(0.25, 0.78, 0.84, 0.18))


## Inicia a conversa apropriada e abre a área jogável quando ela terminar.
func _ready() -> void:
	queue_redraw()
	await get_tree().process_frame
	var sequence := DIALOGUE_CATALOG.get_intro(GameState.selected_character_id)
	await DialogueManager.play(sequence)
	get_tree().change_scene_to_file("res://scenes/world/areas/movement_lab.tscn")
