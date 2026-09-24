extends Area2D

const PIXEL_ASSET := preload("res://scripts/world/pixel_asset_cache.gd")
const RELIC_TEXTURE := preload("res://assets/sprites/world/compass_relic_pixel.png")

signal picked_up

var _base_y := 0.0
var _time := 0.0
var _taken := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	$Sprite2D.texture = PIXEL_ASSET.pixel_texture(RELIC_TEXTURE, Vector2i(32, 32))
	_base_y = $Sprite2D.position.y
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _taken:
		return
	_time += delta
	$Sprite2D.position.y = _base_y + sin(_time * 2.4) * 5.0
	$Sprite2D.rotation = sin(_time * 1.4) * 0.04


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body is CollisionObject2D or not body.get_collision_layer_value(1):
		return
	_taken = true
	picked_up.emit()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.25)
	tween.chain().tween_callback(queue_free)
