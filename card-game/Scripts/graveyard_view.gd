extends CanvasLayer

# Shows every card in a graveyard, like a hand. Opened by right-clicking a discard pile.
# Pauses the game while open. Close with the button, Escape or a right click.

const CARD_DATABASE = preload("res://Scripts/CardDatabase.gd")

@export var art_folder = "res://CardSprites/"
@export var art_prefix = "Cards_"
@export var thumb_size = Vector2(150, 210)

@onready var title_label = %TitleLabel
@onready var cards_box = %CardsBox
@onready var empty_label = %EmptyLabel
@onready var preview_art = %PreviewArt
@onready var preview_text = %PreviewText
@onready var close_button = %CloseButton


func _ready():
	close_button.pressed.connect(close)


# cards: an Array of card nodes (the graveyard list from BattleManager)
func show_cards(title, cards):
	title_label.text = title
	empty_label.visible = cards.is_empty()
	for card in cards:
		if not is_instance_valid(card):
			continue
		var id = card.get_meta("card_name", "")
		var thumb = TextureRect.new()
		thumb.custom_minimum_size = thumb_size
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.texture = _art(id)
		thumb.tooltip_text = CARD_DATABASE.display_name(id)
		thumb.mouse_entered.connect(_preview.bind(id))
		if thumb.texture == null:
			var label = Label.new()
			label.text = CARD_DATABASE.display_name(id)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			thumb.add_child(label)
			label.size = thumb_size
		cards_box.add_child(thumb)
	if not cards.is_empty():
		_preview(cards[0].get_meta("card_name", ""))
	get_tree().paused = true


func _art(id):
	var path = art_folder + art_prefix + id + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _preview(id):
	if id == "":
		return
	var data = CARD_DATABASE.get_card(id)
	var text = "%s\n%s   ATK %s   HP %s   Mana %s" % [
		CARD_DATABASE.display_name(id), data["type"], data["attack"], data["health"], data["mana"]]
	for move in data.get("attacks", []):
		if move.get("passive", false):
			continue
		text += "\n- %s (cost %s)" % [move["name"], move["cost"]]
	preview_text.text = text
	preview_art.texture = _art(id)


func close():
	get_tree().paused = false
	queue_free()


func _input(event):
	var right_click = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	if event.is_action_pressed("ui_cancel") or right_click:
		get_viewport().set_input_as_handled()
		close()
