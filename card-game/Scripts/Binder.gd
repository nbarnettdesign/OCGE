extends Control

# The binder: browse your collection, build and save decks, pick an opponent and start a battle.
# All the visuals live in Binder.tscn and binder_card.tscn. Style them in the editor.

const CARD_DATABASE = preload("res://Scripts/CardDatabase.gd")
const TYPE_FILTERS = ["All", "Monster", "Magic", "Sport"]

@export var card_scene: PackedScene
@export var art_folder = "res://CardSprites/"     # card art lives at art_folder + art_prefix + name + ".png"
@export var art_prefix = "Cards_"
@export var illegal_bg = Color(0.65, 0.1, 0.1, 0.55)     # row colour for cards breaking the rules
@export var illegal_fg = Color(1.0, 0.8, 0.8)
@export var cards_per_page = 4        # set to the number of cards your grid shows (columns x rows)
var page = 0
@export var card_size = Vector2(150, 210)


@onready var filter_menu = %FilterMenu
@onready var grid = %Grid
@onready var preview_art = %PreviewArt
@onready var preview_text = %PreviewText
@onready var deck_name_edit = %DeckNameEdit
@onready var saved_decks = %SavedDecks
@onready var load_button = %LoadButton
@onready var save_button = %SaveButton
@onready var new_button = %NewButton
@onready var delete_button = %DeleteButton
@onready var deck_list = %DeckList
@onready var status_label = %StatusLabel
@onready var npc_menu = %NpcMenu
@onready var npc_info = %NpcInfo
@onready var battle_button = %BattleButton
@onready var transform_box = $Margin/Columns/Side/Preview/TransformBox
@onready var transform_art = $Margin/Columns/Side/Preview/TransformBox/TransformArt
@onready var transform_name = $Margin/Columns/Side/Preview/TransformBox/TransformName
@onready var unsaved_dialog = %UnsavedDialog
@onready var search_edit = %SearchEdit
@onready var prev_button = %PrevPageButton
@onready var next_button = %NextPageButton
@onready var page_label = %PageLabel
@onready var sleeve_menu = %SleeveMenu
@onready var sleeve_preview = %SleevePreview
@onready var collection_label = %CollectionLabel

var deck_cards = []        # the deck being edited
var type_filter = "All"
var deck_rows = []         # card name behind each row of deck_list


func _ready():
	Audio.play_music("menu")
	_update_debug_widgets()
	for t in TYPE_FILTERS:
		filter_menu.add_item(t)
	filter_menu.item_selected.connect(_on_filter_selected)
	search_edit.text_changed.connect(_on_search_changed)
	prev_button.pressed.connect(_change_page.bind(-1))
	next_button.pressed.connect(_change_page.bind(1))
	

	npc_menu.add_item("Practice (random opponent)")
	npc_menu.set_item_metadata(0, "")
	var selected_npc_index = 0
	for id in NPCDatabase.NPCS:
		npc_menu.add_item(NPCDatabase.NPCS[id]["name"])
		var index = npc_menu.item_count - 1
		npc_menu.set_item_metadata(index, id)
		if id == GameState.current_npc and GameState.binder_origin in ["duel_screen", "gameover"]:
			selected_npc_index = index
	npc_menu.select(selected_npc_index)
	npc_menu.item_selected.connect(_on_npc_selected)

	deck_list.rows = deck_rows
	deck_list.make_preview = Callable(self, "_make_drag_preview")
	deck_list.can_accept = Callable(self, "_can_add")
	deck_list.card_dropped.connect(_add_card)
	deck_list.dragged_out.connect(_on_deck_dragged_out)
	deck_list.item_selected.connect(_on_deck_row_selected)
	load_button.pressed.connect(_on_load)
	save_button.pressed.connect(_on_save)
	new_button.pressed.connect(_on_new)
	delete_button.pressed.connect(_on_delete)
	battle_button.pressed.connect(_on_battle)
	unsaved_dialog.add_button("No", true, "no")
	unsaved_dialog.confirmed.connect(_on_unsaved_yes)
	unsaved_dialog.custom_action.connect(_on_unsaved_action)

	if GameState.binder_draft.has("cards"):
		deck_cards = GameState.binder_draft["cards"].duplicate()
		deck_name_edit.text = GameState.binder_draft["name"]
	elif GameState.decks.has(GameState.selected_deck):
		deck_cards = GameState.decks[GameState.selected_deck].duplicate()
		deck_name_edit.text = GameState.selected_deck
	sleeve_menu.item_selected.connect(_on_sleeve_selected)
	_refresh_sleeves()
	_refresh_saved_decks()
	_on_npc_selected(selected_npc_index)
	_refresh()
	transform_box.visible = false
	
	var back = get_node_or_null("BackButton")
	if back:
		back.visible = GameState.binder_origin != ""
		back.pressed.connect(_close)

func _is_working_origin():
	return GameState.binder_origin in ["duel_screen", "gameover"]

func _update_debug_widgets():
	var show_picker = GameState.debug_binder_opponents and not _is_working_origin()
	npc_menu.visible = show_picker
	npc_info.visible = show_picker
	battle_button.visible = show_picker

# true when the deck in the editor differs from what's saved under its name
func _has_changes():
	var deck_name = deck_name_edit.text.strip_edges()
	if not GameState.decks.has(deck_name):
		return not deck_cards.is_empty()        # a brand new deck that hasn't been saved
	var current = deck_cards.duplicate()
	var saved = GameState.decks[deck_name].duplicate()
	current.sort()
	saved.sort()
	return current != saved


func _close():
	if _is_working_origin() and _has_changes():
		var shown = deck_name_edit.text.strip_edges()
		if shown == "":
			shown = "My Deck"
		unsaved_dialog.dialog_text = "You have unsaved changes.\nWould you like to save \"%s\"?" % shown
		unsaved_dialog.popup_centered()
		return                                  # Cancel just closes the dialog and leaves you here
	_leave(false)


func _on_unsaved_yes():
	_leave(true)


func _on_unsaved_action(action):
	if action == "no":
		unsaved_dialog.hide()
		_leave(false)                           # nothing was saved, so the saved deck is untouched


func _leave(save_first):
	if save_first:
		_on_save()
	if _is_working_origin():
		var deck_name = deck_name_edit.text.strip_edges()
		if GameState.decks.has(deck_name):      # equip it, even if it isn't legal here
			GameState.selected_deck = deck_name
		GameState.binder_draft = {}             # no unsaved edits are carried over
		GameState.save_game()
	else:
		GameState.binder_draft = {"name": deck_name_edit.text, "cards": deck_cards.duplicate()}
	GameState.close_binder()


# Tab closes the binder, but only when it was opened from the overworld
func _input(event):
	if event.is_action_pressed("binder_toggle") and GameState.binder_origin == "overworld":
		get_viewport().set_input_as_handled()
		_close()
# ---------- refreshing ----------

func _refresh():
	_refresh_collection()
	_refresh_deck()


func _deck_counts():
	var counts = {}
	for c in deck_cards:
		counts[c] = counts.get(c, 0) + 1
	return counts


func _refresh_collection():
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var counts = _deck_counts()
	var query = search_edit.text.strip_edges().to_lower()
	var all_names = GameState.collection.keys()
	all_names.sort()
	var names = []
	for card_name in all_names:
		var data = CARD_DATABASE.get_card(card_name)
		if type_filter != "All" and data["type"] != type_filter:
			continue
		if query != "" and not _matches(card_name, data, query):
			continue
		names.append(card_name)
	var pages = max(1, ceili(names.size() / float(cards_per_page)))
	page = clampi(page, 0, pages - 1)
	var start = page * cards_per_page
	for card_name in names.slice(start, start + cards_per_page):
		var data = CARD_DATABASE.get_card(card_name)
		var card = card_scene.instantiate()
		grid.add_child(card)
		card.custom_minimum_size = card_size
		card.setup(card_name, GameState.collection[card_name], counts.get(card_name, 0),
			GameState.MAX_COPIES, _art(card_name))
		card.set_new(GameState.new_cards.has(card_name))
		card.chosen.connect(_preview)
		card.hovered.connect(_on_card_hover.bind(card))
	page_label.text = "Page %d / %d" % [page + 1, pages]
	prev_button.disabled = page <= 0
	next_button.disabled = page >= pages - 1
	collection_label.text = "Collected %d / %d" % [GameState.collected_count(), GameState.collectible_cards().size()]

func _on_card_hover(card_name, card):
	_preview(card_name)
	if GameState.new_cards.has(card_name):
		GameState.new_cards.erase(card_name)       # seen it now
		card.set_new(false)


func _refresh_sleeves():
	sleeve_menu.clear()
	var selected = 0
	for i in GameState.sleeves.size():
		var id = GameState.sleeves[i]
		sleeve_menu.add_item(SleeveDatabase.SLEEVES[id]["name"])
		sleeve_menu.set_item_metadata(i, id)
		if id == GameState.equipped_sleeve:
			selected = i
	sleeve_menu.select(selected)
	_update_sleeve_preview()

func _on_sleeve_selected(index):
	GameState.equipped_sleeve = sleeve_menu.get_item_metadata(index)
	_update_sleeve_preview()
	GameState.save_game()

func _update_sleeve_preview():
	var path = SleeveDatabase.SLEEVES[GameState.equipped_sleeve]["texture"]
	sleeve_preview.texture = load(path) if ResourceLoader.exists(path) else null

func _refresh_deck():
	deck_list.clear()
	deck_rows.clear()
	var counts = _deck_counts()
	var names = counts.keys()
	names.sort()
	for card_name in names:
		deck_list.add_item("%s  x%d" % [card_name, counts[card_name]])
		deck_rows.append(card_name)
	var rules = _selected_rules()
	var bad = GameState.offending_cards(deck_cards, rules)
	for i in range(deck_rows.size()):
		if deck_rows[i] in bad:
			deck_list.set_item_custom_bg_color(i, illegal_bg)
			deck_list.set_item_custom_fg_color(i, illegal_fg)
	var error = GameState.deck_error(deck_cards, rules)
	status_label.text = "%d cards (%d to %d, up to %d copies each)" % [
		deck_cards.size(), GameState.DECK_MIN, GameState.DECK_MAX, GameState.MAX_COPIES]
	if error != "":
		status_label.text += "\n" + error
	battle_button.disabled = error != ""
	battle_button.text = error if error != "" else "Battle!"


func _refresh_saved_decks():
	saved_decks.clear()
	var names = GameState.decks.keys()
	names.sort()
	for n in names:
		saved_decks.add_item(n)
		if n == deck_name_edit.text:
			saved_decks.select(saved_decks.item_count - 1)


func _art(card_name):
	var path = art_folder + art_prefix + card_name + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _preview(card_name):
	var data = CARD_DATABASE.get_card(card_name)
	var text = "%s\n%s   ATK %s   HP %s   Mana %s" % [
		card_name, data["type"], data["attack"], data["health"], data["mana"]]
	for move in data.get("attacks", []):
		if move.get("passive", false):
			continue
		text += "\n- %s (cost %s)" % [move["name"], move["cost"]]
	preview_text.text = text
	preview_art.texture = _art(card_name)
	var into = data.get("transforms_into", "")
	transform_box.visible = into != ""
	if into != "":
		transform_art.texture = _art(into)
		transform_name.text = into


# ---------- deck editing ----------

func _add_card(card_name):
	deck_cards.append(card_name)
	_refresh()


func _on_deck_row_selected(index):
	_preview(deck_rows[index])

func _on_deck_dragged_out(card_name):
	deck_cards.erase(card_name)      # removes one copy
	_refresh()

func _can_add(card_name):
	if deck_cards.size() >= GameState.DECK_MAX:
		return false
	var limit = min(GameState.collection.get(card_name, 0), GameState.MAX_COPIES)
	return _deck_counts().get(card_name, 0) < limit

func _make_drag_preview(card_name):
	var tex = _art(card_name)
	if tex:
		var rect = TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(90, 126)
		rect.size = Vector2(90, 126)
		rect.modulate.a = 0.85
		return rect
	var label = Label.new()
	label.text = card_name
	return label


func _matches(card_name, data, query):
	if query in card_name.to_lower():
		return true
	for tag in data.get("tags", []):          # "animal" finds every Animal card
		if query in str(tag).to_lower():
			return true
	return false


func _on_search_changed(_text):
	page = 0
	_refresh_collection()


func _change_page(step):
	page += step
	_refresh_collection()


func _on_filter_selected(index):
	type_filter = TYPE_FILTERS[index]
	page = 0
	_refresh_collection()


func _on_save():
	var deck_name = deck_name_edit.text.strip_edges()
	if deck_name == "":
		deck_name = "My Deck"
		deck_name_edit.text = deck_name
	GameState.decks[deck_name] = deck_cards.duplicate()
	if GameState.deck_error(deck_cards) == "":
		GameState.selected_deck = deck_name
	GameState.save_game()
	_refresh_saved_decks()


func _on_load():
	if saved_decks.item_count == 0:
		return
	var deck_name = saved_decks.get_item_text(saved_decks.selected)
	deck_cards = GameState.decks[deck_name].duplicate()
	deck_name_edit.text = deck_name
	_refresh()


func _on_new():
	deck_cards.clear()
	deck_name_edit.text = ""
	_refresh()


func _on_delete():
	if saved_decks.item_count == 0:
		return
	var deck_name = saved_decks.get_item_text(saved_decks.selected)
	GameState.decks.erase(deck_name)
	if GameState.selected_deck == deck_name:
		GameState.selected_deck = ""
	GameState.save_game()
	_refresh_saved_decks()

func _selected_rules():
	var id = npc_menu.get_item_metadata(npc_menu.selected)
	return BoardRules.build(NPCDatabase.NPCS.get(id, {}).get("rules", []))

# ---------- battle ----------

func _on_npc_selected(index):
	_refresh_deck()
	var id = npc_menu.get_item_metadata(index)
	var npc = NPCDatabase.NPCS.get(id, {})
	if npc.is_empty():
		npc_info.text = "A random deck with standard rules. No rewards."
		return
	var text = "%s\n%s\nDifficulty: %s" % [npc["name"], npc.get("intro", ""), npc.get("difficulty", "?")]
	for line in BoardRules.describe(npc.get("rules", [])):
		text += "\n" + line
		text += "\nWins: %d" % int(GameState.win_counts.get(id, 0))
	npc_info.text = text


func _on_battle():
	_on_save()
	GameState.start_battle(npc_menu.get_item_metadata(npc_menu.selected))
