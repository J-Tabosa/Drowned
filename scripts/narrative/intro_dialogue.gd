extends Node2D

const DIALOGUE_CATALOG := preload("res://scripts/narrative/dialogue_catalog.gd")
const CAVE_BACKGROUND := preload("res://scenes/world/effects/dialogue_cave_background.tscn")


func _ready() -> void:
	var environment := CAVE_BACKGROUND.instantiate()
	add_child(environment)
	MusicDirector.set_context("cavern")
	if SceneTransition.busy:
		await SceneTransition.revealed
	await get_tree().process_frame
	await DialogueManager.play(DIALOGUE_CATALOG.get_intro(GameState.selected_character_id))
	SceneTransition.transition_to("res://scenes/world/areas/movement_lab.tscn")
