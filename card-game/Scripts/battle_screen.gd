extends CanvasLayer

# The pre-duel screen in your overworld. Attach this script to your battle canvas,
# assign the nodes below in the inspector, and add the canvas to the group "battle_screen"
# (Node dock > Groups) so NPCs can find it.

const CARD_DATABASE = preload("res://Scripts/CardDatabase.gd")

@export var player_image: TextureRect
@export var challenger_image: TextureRect
@export var challenger_name: Label
@export var rules_box: Container        # rule labels are created inside this, above the buttons
@export var error_label: Label          # optional: shows what's wrong with the deck
@export var deck_menu: OptionButton     # all your saved decks; the selected one is the equipped deck
@export var battle_button: Button
@export var quit_button: Button
@export var binder_button: Button
@export var player_fallback: Texture2D  # used if the player has no Sprite2D to copy
@export var rule_bad_color = Color(1.0, 0.3, 0.3)                 # text and border of a broken rule
@export var rule_bad_background = Color(0.55, 0.08, 0.08, 0.7)    # fill of a broken rule

var npc = null
var rule_ids = []
var rule_panels = {}        # rule id -> PanelContainer holding that rule's label


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	battle_button.pressed.connect(_on_battle)
	quit_button.pressed.connect(close)
	binder_button.pressed.connect(_on_binder)
	deck_menu.item_selected.connect(_on_deck_selected)
	# coming back from the binder: reopen for the same challenger
	if GameState.pending_duel_npc != NodePath():
		var node = get_tree().root.get_node_or_null(GameState.pending_duel_npc)
		GameState.pending_duel_npc = NodePath()
		if node:
			call_deferred("open", node)


func open(new_npc):
	npc = new_npc
	var data = NPCDatabase.NPCS.get(npc.npc_id, {})
	rule_ids = data.get("rules", [])
	challenger_name.text = npc._speaker()
	challenger_image.texture = _npc_texture()
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("talk_portrait"):
		player_image.texture = player.talk_portrait
	_build_rule_labels()
	_refresh_decks()
	visible = true
	get_tree().paused = true


func close():
	visible = false
	get_tree().paused = false


func _npc_texture():
	var talk = npc.get("talk_portrait")
	if talk:
		return talk
	var custom = npc.get("sprite_texture")
	if custom:
		return custom
	return npc.get_node("Sprite2D").texture


func _player_texture():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var sprite = player.find_child("Sprite2D", true, false)
		if sprite and sprite.texture:
			return sprite.texture
		var anim = player.find_child("AnimatedSprite2D", true, false)
		if anim and anim.sprite_frames and anim.sprite_frames.get_frame_count(anim.animation) > 0:
			return anim.sprite_frames.get_frame_texture(anim.animation, 0)
	return player_fallback


func _build_rule_labels():
	for child in rules_box.get_children():
		child.queue_free()
	rule_panels.clear()
	for id in rule_ids:
		var rule = BoardRules.RULES.get(id, {})
		if rule.is_empty() or id == "standard":
			continue
		var panel = PanelContainer.new()
		var label = Label.new()
		label.text = "%s: %s" % [rule["name"], rule["description"]]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color", Color.BLACK)
		label.add_theme_font_size_override("font_size", 35)
		panel.add_child(label)
		rules_box.add_child(panel)
		rule_panels[id] = panel
	if rule_panels.is_empty():
		var none = Label.new()
		none.text = "No special rules"
		none.add_theme_color_override("font_color", Color.BLACK)
		none.add_theme_font_size_override("font_size", 40)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rules_box.add_child(none)



func _refresh_decks():
	var rules = BoardRules.build(rule_ids)
	deck_menu.clear()
	var names = GameState.decks.keys()
	names.sort()
	var equipped_index = -1
	if not GameState.decks.has(GameState.selected_deck):
		deck_menu.add_item("Select a deck")
		deck_menu.set_item_metadata(0, "")
		equipped_index = 0
	for n in names:
		var text = n
		if GameState.deck_error(GameState.decks[n], rules) != "":
			text += "  (not legal here)"
		deck_menu.add_item(text)
		var index = deck_menu.item_count - 1
		deck_menu.set_item_metadata(index, n)
		if n == GameState.selected_deck:
			equipped_index = index
	if equipped_index >= 0:
		deck_menu.select(equipped_index)
	_refresh_legality()


func _refresh_legality():
	for panel in rule_panels.values():
		panel.remove_theme_stylebox_override("panel")
		panel.get_child(0).remove_theme_color_override("font_color")
	var has_deck = GameState.decks.has(GameState.selected_deck)
	var cards = GameState.decks.get(GameState.selected_deck, [])
	var error = GameState.deck_error(cards, BoardRules.build(rule_ids))
	if not has_deck:
		error = "No deck equipped"
	battle_button.disabled = error != ""
	if error_label:
		error_label.text = error
		error_label.add_theme_color_override("font_color", rule_bad_color)
	# the rule(s) that ban something in the deck turn red
	for id in rule_ids:
		var banned = BoardRules.RULES.get(id, {}).get("banned_types", [])
		for c in cards:
			if rule_panels.has(id) and CARD_DATABASE.get_card(c)["type"] in banned:
				_mark_rule_broken(rule_panels[id])
				break


func _mark_rule_broken(panel):
	var style = StyleBoxFlat.new()
	style.bg_color = rule_bad_background
	style.border_color = rule_bad_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.get_child(0).add_theme_color_override("font_color", rule_bad_color)


func _on_deck_selected(index):
	var deck_name = deck_menu.get_item_metadata(index)
	if deck_name == "":
		return          # the "Select a deck" placeholder
	GameState.selected_deck = deck_name
	GameState.save_game()
	_refresh_legality()


func _player_position():
	var player = get_tree().get_first_node_in_group("player")
	return player.global_position if player else Vector2.ZERO


func _on_battle():
	GameState.remember_overworld(get_tree().current_scene.scene_file_path, _player_position())
	get_tree().paused = false
	GameState.start_battle(npc.npc_id)


func _on_binder():
	GameState.remember_overworld(get_tree().current_scene.scene_file_path, _player_position())
	GameState.pending_duel_npc = npc.get_path()
	GameState.go_to_binder("duel_screen")
