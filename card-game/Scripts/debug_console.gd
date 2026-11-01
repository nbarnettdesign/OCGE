extends CanvasLayer

# In-game debug console. Open/close with ` (backtick) or F1.
# It only works when running from the editor (debug builds). Exported releases ignore it,
# unless you set ENABLED_IN_RELEASE to true.

const CARD_DATABASE = preload("res://Scripts/CardDatabase.gd")
const DeckDB = preload("res://Scripts/DeckDatabase.gd")
const ENABLED_IN_RELEASE = false

var panel
var output
var line
var history = []
var history_index = 0
var was_paused = false


func _ready():
	if not (OS.is_debug_build() or ENABLED_IN_RELEASE):
		set_process_input(false)
		return
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	panel.visible = false
	_say("Debug console. Type help for commands.", Color.GRAY)


func _build_ui():
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.anchor_bottom = 0.45
	panel.offset_bottom = 0
	panel.self_modulate = Color(1, 1, 1, 0.95)
	add_child(panel)
	var box = VBoxContainer.new()
	panel.add_child(box)
	output = RichTextLabel.new()
	output.bbcode_enabled = true
	output.scroll_following = true
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(output)
	line = LineEdit.new()
	line.placeholder_text = "command (type help)"
	line.text_submitted.connect(_on_submit)
	line.gui_input.connect(_on_line_input)
	box.add_child(line)


func _input(event):
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_QUOTELEFT or event.keycode == KEY_F1 \
			or (panel.visible and event.keycode == KEY_ESCAPE):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle():
	if panel.visible:
		panel.visible = false
		get_tree().paused = was_paused
	else:
		was_paused = get_tree().paused
		get_tree().paused = true         # the game waits while you type
		panel.visible = true
		line.clear()
		line.grab_focus()


func _on_line_input(event):                # up/down arrows recall earlier commands
	if event is InputEventKey and event.pressed and not history.is_empty():
		if event.keycode == KEY_UP:
			history_index = maxi(0, history_index - 1)
			line.text = history[history_index]
			line.caret_column = line.text.length()
			line.accept_event()
		elif event.keycode == KEY_DOWN:
			history_index = mini(history.size(), history_index + 1)
			line.text = history[history_index] if history_index < history.size() else ""
			line.caret_column = line.text.length()
			line.accept_event()


func _on_submit(text):
	line.clear()
	text = text.strip_edges()
	if text == "":
		return
	history.append(text)
	history_index = history.size()
	_say("> " + text, Color.WHITE)
	var parts = text.split(" ", false)
	_run(parts[0].to_lower(), Array(parts.slice(1)))
	line.grab_focus()


func _say(text, color = Color.LIGHT_GRAY):
	output.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), str(text).replace("[", "[lb]")])


func _bad(text):
	_say(text, Color(1.0, 0.45, 0.45))


# after anything that changes your save: store it and refresh the open scene (e.g. the Binder)
func _changed(text):
	GameState.save_game()
	var scene = get_tree().current_scene
	for method in ["_refresh", "_refresh_sleeves"]:
		if scene and scene.has_method(method):
			scene.call(method)
	_say(text, Color.LIGHT_GREEN)


func _run(cmd, args):
	match cmd:
		"help": _help()
		"give": _give(args, 1)
		"take": _give(args, -1)
		"allcards": _allcards(args)
		"cards": _list_cards(args)
		"resetcollection": _reset_collection()
		"givedeck": _givedeck(args)
		"decks": _say(", ".join(_deck_names()))
		"sleeves": _say(", ".join(SleeveDatabase.SLEEVES.keys()))
		"allsleeves": _allsleeves()
		"sleeve": _sleeve(args)
		"npcs": _say(", ".join(NPCDatabase.NPCS.keys()))
		"defeat": _defeat(args, true)
		"undefeat": _defeat(args, false)
		"defeatall": _defeat_all(true)
		"undefeatall": _defeat_all(false)
		"win": _end_battle(true)
		"lose": _end_battle(false)
		"draw": _draw(args)
		"save": _changed("Saved.")
		"clear": output.clear()
		_: _bad("Unknown command: " + cmd + " (type help)")


func _help():
	_say("give <card> [n]      add copies    |  take <card> [n]   remove copies")
	_say("allcards [n]         own at least n of every real card (default: the copy limit)")
	_say("cards [text]         list card names   |  resetcollection  back to the starting cards")
	_say("givedeck <deck>      save a built-in deck and own its cards  |  decks  list them")
	_say("sleeves / allsleeves / sleeve <id>   list, unlock all, unlock and equip one")
	_say("npcs / defeat <id> / undefeat <id> / defeatall / undefeatall")
	_say("win / lose / draw [n]   (inside a battle)")
	_say("save / clear.   Card names ignore case and spaces: give space monkey 2")


# ---------- cards ----------

func _find_card(text):
	var wanted = text.to_lower().replace(" ", "")
	var partial = []
	for card in CARD_DATABASE.CARDS.keys():
		if card.to_lower() == wanted:
			return card
		if wanted != "" and wanted in card.to_lower():
			partial.append(card)
	return partial[0] if partial.size() == 1 else ""


func _is_collectible(card):
	return not CARD_DATABASE.get_card(card).get("token", false) and card != "ManaMonster"


func _give(args, sign):
	var count = 1
	if args.size() > 1 and args[-1].is_valid_int():
		count = int(args[-1])
		args = args.slice(0, args.size() - 1)
	var card = _find_card(" ".join(args))
	if card == "":
		_bad("No single card matches '%s'. Try: cards %s" % [" ".join(args), " ".join(args)])
		return
	var now = maxi(0, GameState.collection.get(card, 0) + count * sign)
	if now == 0:
		GameState.collection.erase(card)
	else:
		GameState.collection[card] = now
	_changed("%s now has %d copies." % [card, now])


func _allcards(args):
	var count = int(args[0]) if args.size() > 0 and args[0].is_valid_int() else GameState.MAX_COPIES
	var total = 0
	for card in CARD_DATABASE.CARDS.keys():
		if _is_collectible(card):
			GameState.collection[card] = maxi(GameState.collection.get(card, 0), count)
			total += 1
	_changed("%d cards, each at %d or more copies." % [total, count])


func _list_cards(args):
	var filter = "".join(args).to_lower()
	var names = []
	for card in CARD_DATABASE.CARDS.keys():
		if filter == "" or filter in card.to_lower():
			names.append(card)
	_say(", ".join(names) if not names.is_empty() else "No cards match.")


func _reset_collection():
	var db = DeckDB.new()
	var start = db.get("defaultDeck")
	db.free()
	GameState.collection = {}
	for card in start:
		GameState.collection[card] = GameState.collection.get(card, 0) + 1
	_changed("Collection reset to the starting cards.")


# ---------- decks ----------

func _deck_names():
	var db = DeckDB.new()
	var names = []
	for p in db.get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and db.get(p["name"]) is Array:
			names.append(p["name"])
	db.free()
	return names


func _givedeck(args):
	var wanted = "".join(args).to_lower()
	var found = ""
	for deck_name in _deck_names():
		if deck_name.to_lower() == wanted:
			found = deck_name
	if found == "":
		_bad("No deck called '%s'. Type decks to see them." % wanted)
		return
	var db = DeckDB.new()
	var list = db.get(found).duplicate()
	db.free()
	GameState.decks[found] = list
	var counts = {}
	for card in list:
		counts[card] = counts.get(card, 0) + 1
	for card in counts:
		GameState.collection[card] = maxi(GameState.collection.get(card, 0), counts[card])
	_changed("Saved deck '%s' (%d cards) and made sure you own them." % [found, list.size()])


# ---------- sleeves ----------

func _allsleeves():
	for id in SleeveDatabase.SLEEVES.keys():
		if not GameState.sleeves.has(id):
			GameState.sleeves.append(id)
	_changed("All sleeves unlocked.")


func _sleeve(args):
	var id = "".join(args).to_lower()
	if not SleeveDatabase.SLEEVES.has(id):
		_bad("No sleeve '%s'. Type sleeves to see them." % id)
		return
	if not GameState.sleeves.has(id):
		GameState.sleeves.append(id)
	GameState.equipped_sleeve = id
	_changed("Sleeve '%s' unlocked and equipped." % id)


# ---------- opponents ----------

func _defeat(args, on):
	var id = "".join(args).to_lower()
	if not NPCDatabase.NPCS.has(id):
		_bad("No NPC '%s'. Type npcs to see them." % id)
		return
	if on:
		GameState.defeated[id] = true
	else:
		GameState.defeated.erase(id)
	_changed("%s marked %s." % [id, "defeated" if on else "not defeated"])


func _defeat_all(on):
	GameState.defeated = {}
	if on:
		for id in NPCDatabase.NPCS.keys():
			GameState.defeated[id] = true
	_changed("Everyone marked %s." % ("defeated" if on else "not defeated"))


# ---------- battle ----------

func _battle():
	var scene = get_tree().current_scene
	return scene.get_node_or_null("BattleManager") if scene else null


func _end_battle(player_wins):
	var bm = _battle()
	if bm == null:
		_bad("You're not in a battle.")
		return
	if player_wins:
		bm.opponent_health = 0
	else:
		bm.player_health = 0
	bm.check_game_over()
	was_paused = was_paused or bm.game_over     # the game over screen pauses the game: keep it that way
	_say("Done.", Color.LIGHT_GREEN)


func _draw(args):
	var bm = _battle()
	if bm == null:
		_bad("You're not in a battle.")
		return
	bm.draw_extra_cards("Player", int(args[0]) if args.size() > 0 and args[0].is_valid_int() else 1)
	_say("Drawing...", Color.LIGHT_GREEN)
