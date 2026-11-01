extends CanvasLayer

# Shown after a win: pick one card from the options, then press Add to collection.
#   var card = await picker.choose(["CardA", "CardB", ...])

signal done(card_name)

const CARD_DATABASE = preload("res://Scripts/CardDatabase.gd")

@export var card_scene: PackedScene
@export var art_folder = "res://CardSprites/"
@export var art_prefix = "Cards_"

@onready var title_label = %TitleLabel
@onready var options_row = %OptionsRow
@onready var preview_art = %PreviewArt
@onready var preview_text = %PreviewText
@onready var add_button = %AddButton
@onready var deck_pile = get_node_or_null("%DeckPile")

var selected = ""


func _ready():
	add_button.pressed.connect(func(): done.emit(selected))
	


func choose(options, title = "Choose your reward"):
	title_label.text = title
	add_button.disabled = true
	preview_art.visible = false              # info only appears once you click a card
	preview_text.visible = false
	var sleeve = _sleeve_texture()
	var group = ButtonGroup.new()
	var entries = []
	for card_name in options:
		var card = card_scene.instantiate()
		options_row.add_child(card)
		card.setup(card_name, 1, 0, GameState.MAX_COPIES, _art(card_name))
		card.set_info("Owned: %d" % GameState.collection.get(card_name, 0))
		card.toggle_mode = true
		card.button_group = group
		card.chosen.connect(_select)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE      # not clickable until they've all been dealt
		card.modulate.a = 0.0
		entries.append({"name": card_name, "card": card})
	get_tree().paused = true
	if deck_pile:
		deck_pile.texture = sleeve
	else:
		print("RewardPicker: add a TextureRect named DeckPile (unique name) to show the deck")
	await get_tree().process_frame               # let the row lay itself out
	await get_tree().process_frame
	await _pull_cards(entries, sleeve)
	for entry in entries:
		entry["card"].mouse_filter = Control.MOUSE_FILTER_STOP
	var result = await done
	await _put_back(entries, result, sleeve)
	queue_free()
	return result


func _select(card_name):
	selected = card_name
	add_button.disabled = false
	preview_art.visible = true
	preview_text.visible = true
	_preview(card_name)


func _art(card_name):
	var path = art_folder + art_prefix + card_name + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _preview(card_name):
	var data = CARD_DATABASE.get_card(card_name)
	var text = "%s\n%s   ATK %s   HP %s   Mana %s" % [
		CARD_DATABASE.display_name(card_name), data["type"], data["attack"], data["health"], data["mana"]]
	for move in data.get("attacks", []):
		if move.get("passive", false):
			continue
		text += "\n- %s (cost %s)" % [move["name"], move["cost"]]
	preview_text.text = text
	preview_art.texture = _art(card_name)

func _sleeve_texture():
	var id = GameState.npc_sleeve()                  # the sleeve the opponent was using
	for key in [id, "default"]:
		var path = SleeveDatabase.SLEEVES.get(key, {}).get("texture", "")
		if path != "" and ResourceLoader.exists(path):
			return load(path)
	return null


func _make_cover(card, texture):
	var cover = TextureRect.new()
	cover.texture = texture
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_SCALE
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(cover)
	return cover

# deals the cards out of the pile one at a time, face-down, then flips each one
func _pull_cards(entries, sleeve):
	if deck_pile == null or sleeve == null:
		for entry in entries:
			entry["card"].modulate.a = 1.0
		return
	var from = deck_pile.get_global_rect().get_center()
	var last = null
	for i in entries.size():
		var card = entries[i]["card"]
		card.pivot_offset = card.size / 2.0
		var proxy = _make_proxy(card, sleeve)
		proxy.global_position = from - card.size / 2.0
		proxy.scale = Vector2(0.4, 0.4)
		var target = card.global_position
		var t = create_tween()
		t.tween_interval(i * 0.3)
		t.tween_callback(func(): proxy.modulate.a = 1.0)
		t.tween_property(proxy, "global_position", target, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(proxy, "scale", Vector2.ONE, 0.4)
		t.tween_property(proxy, "scale:x", 0.0, 0.12)
		t.tween_callback(_reveal.bind(proxy, card))
		t.tween_property(card, "scale:x", 1.0, 0.12)
		last = t
	if last:
		await last.finished

func _make_proxy(card, sleeve):
	var proxy = TextureRect.new()
	proxy.texture = sleeve
	proxy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	proxy.stretch_mode = TextureRect.STRETCH_SCALE
	proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proxy.size = card.size
	proxy.pivot_offset = card.size / 2.0
	proxy.modulate.a = 0.0
	add_child(proxy)
	return proxy


func _reveal(proxy, card):
	proxy.queue_free()
	card.scale.x = 0.0
	card.modulate.a = 1.0


# the card you took stays; the others turn face-down and slide back into the deck
func _put_back(entries, chosen, sleeve):
	for entry in entries:
		entry["card"].mouse_filter = Control.MOUSE_FILTER_IGNORE
	if deck_pile == null or sleeve == null:
		return
	var to = deck_pile.get_global_rect().get_center()
	for entry in entries:
		var card = entry["card"]
		var t = create_tween()
		if entry["name"] == chosen:
			t.tween_property(card, "scale", Vector2(1.12, 1.12), 0.2)
		else:
			var proxy = _make_proxy(card, sleeve)
			proxy.global_position = card.global_position
			t.tween_property(card, "scale:x", 0.0, 0.12)
			t.tween_callback(_turn_face_down.bind(proxy, card))
			t.tween_property(proxy, "scale:x", 1.0, 0.12)
			t.tween_property(proxy, "global_position", to - card.size / 2.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(proxy, "scale", Vector2(0.4, 0.4), 0.35)
	await get_tree().create_timer(0.75, true).timeout


func _turn_face_down(proxy, card):
	card.modulate.a = 0.0
	proxy.scale.x = 0.0
	proxy.modulate.a = 1.0
