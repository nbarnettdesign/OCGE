extends Button

# One card in the binder grid. Style it in binder_card.tscn.

signal chosen(card_name)
signal hovered(card_name)

const CARD_DATABASE = preload("res://Scripts/CardDatabase.gd")

var card_name = ""
@export var empty_tint = Color(0.5, 0.5, 0.5, 1.0)   # colour when no copies are left to add

@onready var art = %Art
@onready var name_label = %NameLabel
@onready var info_label = %InfoLabel

var badge = null

func _ready():
	pressed.connect(func(): chosen.emit(card_name))
	mouse_entered.connect(func(): hovered.emit(card_name))


# call after add_child
func setup(new_name, owned, in_deck, max_copies, texture):
	card_name = new_name
	var data = CARD_DATABASE.get_card(new_name)
	name_label.text = new_name
	info_label.text = "%s   x%d free" % [data["type"], owned - in_deck]
	art.texture = texture
	disabled = in_deck >= min(owned, max_copies)
	modulate = empty_tint if disabled else Color(1, 1, 1, 1)
	
func _get_drag_data(_at_position):
	if disabled:
		return null     # already at its copy limit
	var preview
	if art.texture:
		preview = TextureRect.new()
		preview.texture = art.texture
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.custom_minimum_size = Vector2(90, 126)
		preview.size = Vector2(90, 126)
		preview.modulate.a = 0.85
	else:
		preview = Label.new()
		preview.text = card_name
	set_drag_preview(preview)
	return {"card": card_name, "from": "collection"}

func set_info(text):
	info_label.text = text

func set_new(on):
	if not on:
		if badge:
			badge.queue_free()
			badge = null
		return
	if badge:
		return
	badge = Label.new()
	badge.text = "NEW"
	badge.add_theme_font_size_override("font_size", 16)
	badge.add_theme_color_override("font_color", Color(0.12, 0.08, 0.02))
	badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.78, 0.30)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	badge.add_theme_stylebox_override("normal", style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
