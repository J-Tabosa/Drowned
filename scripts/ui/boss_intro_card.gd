extends CanvasLayer

@onready var curtain: Control = %Curtain
@onready var dimmer: ColorRect = %Dimmer
@onready var theme_bar: Polygon2D = %ThemeBar
@onready var portrait_panel: Control = %PortraitPanel
@onready var portrait_body: ColorRect = %PortraitBody
@onready var portrait_head: ColorRect = %PortraitHead
@onready var information_panel: Control = %InformationPanel
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var description_label: Label = %DescriptionLabel


## Começa invisível e processa mesmo durante outras apresentações que pausam a árvore.
func _ready() -> void:
	curtain.visible = false


## Apresenta a arte completa placeholder, faixa temática e classificação do encontro.
func play(
	title: String,
	subtitle: String,
	description: String,
	theme_color: Color,
	duration := 2.7
) -> void:
	title_label.text = title
	subtitle_label.text = subtitle
	description_label.text = description
	theme_bar.color = Color(theme_color, 0.92)
	portrait_body.color = theme_color.darkened(0.10)
	portrait_head.color = theme_color.lightened(0.12)
	subtitle_label.add_theme_color_override("font_color", Color("f1dff5"))
	curtain.visible = true
	dimmer.modulate.a = 0.0
	portrait_panel.position.x = -430.0
	information_panel.position.x = 1180.0
	theme_bar.scale.x = 0.05
	var entrance := create_tween().set_parallel(true)
	entrance.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	entrance.tween_property(dimmer, "modulate:a", 1.0, 0.32)
	entrance.tween_property(portrait_panel, "position:x", 68.0, 0.52)
	entrance.tween_property(information_panel, "position:x", 510.0, 0.48).set_delay(0.08)
	entrance.tween_property(theme_bar, "scale:x", 1.0, 0.44)
	await entrance.finished
	await get_tree().create_timer(duration, true).timeout
	var exit_tween := create_tween().set_parallel(true)
	exit_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(dimmer, "modulate:a", 0.0, 0.28)
	exit_tween.tween_property(portrait_panel, "position:x", -430.0, 0.36)
	exit_tween.tween_property(information_panel, "position:x", 1180.0, 0.34)
	exit_tween.tween_property(theme_bar, "scale:x", 0.05, 0.32)
	await exit_tween.finished
	curtain.visible = false
