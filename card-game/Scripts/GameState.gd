extends Node

# Autoload this as "GameState": Project Settings > Globals > Autoload.
# It holds the save data (collection, decks) and the settings for the battle about to start.

const SAVE_PATH = "user://save.json"
const BATTLE_SCENE = "res://Scenes/Main.tscn"      # <- change to your battle scene
const BINDER_SCENE = "res://Scenes/Binder.tscn"
const DECK_MIN = 5
const DECK_MAX = 20
const MAX_COPIES = 5
const DeckDB = preload("res://Scripts/DeckDatabase.gd")
const CardDB = preload("res://Scripts/CardDatabase.gd")
const SETTINGS_PATH = "user://settings.cfg"
const rewardCardAmount = 3
var settings = {"volume": 1.0, "music_volume": 0.8, "sfx_volume": 1.0, "fullscreen": false}
var collection = {}        # card name -> copies owned
var decks = {}             # deck name -> Array of card names
var selected_deck = ""     # the deck used in battle
var defeated = {}          # npc id -> true
var new_cards = []            # cards you've won but haven't looked at yet (they show a NEW badge)
var win_counts = {}           # npc id -> times beaten
var sleeves = ["default"]            # sleeves the player owns
var equipped_sleeve = "default"
var opponent_sleeve = "default"  

var binder_origin = ""       # "overworld", "battle" or "" (opened directly)
var binder_draft = {}        # unsaved deck edits kept while the binder is closed
var pending_duel_npc = NodePath()
var pending_game_over = {}

var current_npc = ""       # "" = practice
var rules = BoardRules.build([])
var overworld_scene = ""             # scene to come back to after a battle
var overworld_position = Vector2.ZERO
var _restore_player = false

const META_PATH = "user://save_meta.json"
const SLOT_COUNT = 3
const OVERWORLD_SCENE = "res://Scenes/TestOverworldLevel.tscn"     # <- change to your overworld scene
const MENU_SCENE = "res://Scenes/main_menu.tscn"

var current_slot = 0            # 0 = no slot loaded (you ran a scene directly), so nothing is saved
var player_name = "Player"
var npc_deck_choice = {}   # npc id -> name of the deck they're locked to

var world_scene = "TestOverworldLevel"              # the map you were last on
var world_position = Vector2.ZERO
var has_world_position = false
var debug_binder_opponents = false 

func _ready():
	get_tree().node_added.connect(_on_node_added)
	_ensure_action("binder_toggle", KEY_TAB)
	_migrate_old_save()
	_new_state()
	load_settings()
	var autosave = Timer.new()
	autosave.wait_time = 30.0
	autosave.autostart = true
	autosave.timeout.connect(save_game)
	add_child(autosave)
	
# ---------- Settings ----------

func load_settings():
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		settings["volume"] = cfg.get_value("audio", "volume", 1.0)
		settings["music_volume"] = cfg.get_value("audio", "music_volume", 0.8)
		settings["sfx_volume"] = cfg.get_value("audio", "sfx_volume", 1.0)
		settings["fullscreen"] = cfg.get_value("display", "fullscreen", false)
	apply_settings()


func save_settings():
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "volume", settings["volume"])
	cfg.set_value("audio", "music_volume", settings["music_volume"])
	cfg.set_value("audio", "sfx_volume", settings["sfx_volume"])
	cfg.set_value("display", "fullscreen", settings["fullscreen"])
	cfg.save(SETTINGS_PATH)


func apply_settings():
	_set_bus("Master", settings["volume"])
	_set_bus("Music", settings["music_volume"])
	_set_bus("SFX", settings["sfx_volume"])
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"]
		else DisplayServer.WINDOW_MODE_WINDOWED)


func _set_bus(bus_name, linear):
	var index = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.0)

# ---------- save slots ----------

func slot_path(slot):
	return "user://save_%d.json" % slot


func slot_exists(slot):
	return FileAccess.file_exists(slot_path(slot))


# {} for an empty slot, otherwise the info shown in the menu
func slot_summary(slot):
	if not slot_exists(slot):
		return {}
	var f = FileAccess.open(slot_path(slot), FileAccess.READ)
	if not f:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		return {}
	var cards = 0
	for k in data.get("collection", {}):
		cards += int(data["collection"][k])
	return {
		"name": data.get("player_name", "Player"),
		"cards": cards,
		"defeated": data.get("defeated", {}).size(),
		"saved_at": data.get("saved_at", 0),
	}


func last_slot():
	if not FileAccess.file_exists(META_PATH):
		return 0
	var f = FileAccess.open(META_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text()) if f else null
	if data is Dictionary:
		var s = int(data.get("last_slot", 0))
		if s > 0 and slot_exists(s):
			return s
	return 0


func _write_meta(slot):
	var f = FileAccess.open(META_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"last_slot": slot}))


# a fresh game's data, in memory only
func _new_state():
	new_cards = []
	win_counts = {}
	var db = DeckDB.new()
	collection.clear()
	for c in db.defaultDeck:
		collection[c] = collection.get(c, 0) + 1
	decks = {"Default Deck": db.defaultDeck.duplicate()}
	selected_deck = "Default Deck"
	defeated = {}
	npc_deck_choice = {}
	binder_draft = {}
	sleeves = ["default"]
	equipped_sleeve = "default"
	db.free()


# clears anything left over from the previous session
func _reset_session():
	current_npc = ""
	rules = BoardRules.build([])
	binder_origin = ""
	binder_draft = {}
	pending_game_over = {}
	pending_duel_npc = NodePath()
	overworld_scene = ""
	overworld_position = Vector2.ZERO
	world_scene = ""
	world_position = Vector2.ZERO
	has_world_position = false
	_restore_player = false


func new_game_in_slot(slot, new_name):
	_reset_session()
	current_slot = slot
	player_name = new_name
	_new_state()
	save_game()
	_write_meta(slot)


func load_slot(slot):
	if not slot_exists(slot):
		return false
	var f = FileAccess.open(slot_path(slot), FileAccess.READ)
	if not f:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		return false
	_reset_session()
	current_slot = slot
	player_name = data.get("player_name", "Player")
	collection.clear()
	for k in data.get("collection", {}):
		collection[k] = int(data["collection"][k])
	decks.clear()
	for k in data.get("decks", {}):
		decks[k] = data["decks"][k].duplicate()
	selected_deck = data.get("selected_deck", "")
	defeated = data.get("defeated", {})
	new_cards = data.get("new_cards", [])
	win_counts = data.get("win_counts", {})
	npc_deck_choice = data.get("npc_deck_choice", {})
	sleeves = data.get("sleeves", ["default"])
	if not sleeves.has("default"):
		sleeves.append("default")
	equipped_sleeve = data.get("equipped_sleeve", "default")
	if not sleeves.has(equipped_sleeve):
		equipped_sleeve = "default"
	binder_draft = data.get("binder_draft", {})
	world_scene = data.get("world_scene", "")
	var p = data.get("player_position", [])
	if p is Array and p.size() == 2:
		world_position = Vector2(p[0], p[1])
	has_world_position = data.get("has_position", false)
	_write_meta(slot)
	return true


func save_game():
	if current_slot == 0:
		return
	_capture_world_position()
	var data = {
		"player_name": player_name,
		"saved_at": Time.get_unix_time_from_system(),
		"collection": collection,
		"decks": decks,
		"selected_deck": selected_deck,
		"defeated": defeated,
		"binder_draft": binder_draft,
		"world_scene": world_scene,
		"player_position": [world_position.x, world_position.y],
		"has_position": has_world_position,
		"npc_deck_choice": npc_deck_choice,
		"sleeves": sleeves,
		"equipped_sleeve": equipped_sleeve,
		"new_cards": new_cards,
		"win_counts": win_counts,
	}
	var f = FileAccess.open(slot_path(current_slot), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func delete_slot(slot):
	var was_last = last_slot() == slot
	DirAccess.remove_absolute(slot_path(slot))
	if current_slot == slot:
		current_slot = 0
	if was_last:      # point Continue at the most recently saved slot that's left
		var best = 0
		var best_time = -1.0
		for s in range(1, SLOT_COUNT + 1):
			var summary = slot_summary(s)
			if not summary.is_empty() and summary["saved_at"] > best_time:
				best = s
				best_time = summary["saved_at"]
		_write_meta(best)


# your old single save becomes slot 1
func _migrate_old_save():
	if FileAccess.file_exists(SAVE_PATH) and not slot_exists(1):
		DirAccess.rename_absolute(SAVE_PATH, slot_path(1))
		if last_slot() == 0:
			_write_meta(1)


func start_game():
	get_tree().paused = false
	var scene = OVERWORLD_SCENE
	if world_scene != "" and ResourceLoader.exists(world_scene):
		scene = world_scene
		if has_world_position:       # Continue: put the player back where they were
			overworld_position = world_position
			_restore_player = true
	Transition.change_scene(scene)


func go_to_menu():
	get_tree().paused = false
	Transition.change_scene(MENU_SCENE)

# ---------- decks ----------

# "" if the deck is legal, otherwise a message
func deck_error(cards, rule_set = null):
	if cards.size() < DECK_MIN:
		return "Needs at least %d cards" % DECK_MIN
	if cards.size() > DECK_MAX:
		return "No more than %d cards" % DECK_MAX
	var counts = {}
	for c in cards:
		counts[c] = counts.get(c, 0) + 1
	for c in counts:
		if counts[c] > min(MAX_COPIES, collection.get(c, 0)):
			return "Too many copies of " + c
	if rule_set != null:
		for banned in rule_set["banned_types"]:
			var count = 0
			for c in cards:
				if CardDB.get_card(c)["type"] == banned:
					count += 1
			if count > 0:
				return "This match bans %s cards (%d in your deck)" % [banned, count]
	return ""

func offending_cards(cards, rule_set = null):
	var result = []
	var counts = {}
	for c in cards:
		counts[c] = counts.get(c, 0) + 1
	for c in counts:
		if counts[c] > min(MAX_COPIES, collection.get(c, 0)):
			result.append(c)
		elif rule_set != null and CardDB.get_card(c)["type"] in rule_set["banned_types"]:
			result.append(c)
	return result

func player_deck_for_battle():
	if deck_error(decks[selected_deck], rules) == "":
		return decks[selected_deck].duplicate()
	return _random_deck()


func opponent_deck_for_battle():
	var npc = NPCDatabase.NPCS.get(current_npc, {})
	if npc.has("cards"):
		return npc["cards"].duplicate()
	var deck_name = _npc_deck_name(npc)
	if deck_name != "":
		var db = DeckDB.new()
		var d = db.get(deck_name)
		db.free()
		if d != null:
			return d.duplicate()
	return _random_deck()


func _npc_deck_name(npc):
	var options = npc.get("decks", [])
	if options.is_empty():
		return npc.get("deck", "")
	var locked = npc_deck_choice.get(current_npc, "")
	if locked in options:                 # still a valid choice, so keep it
		return locked
	var pick = options.pick_random()
	npc_deck_choice[current_npc] = pick
	save_game()
	return pick


func _random_deck():
	var db = DeckDB.new()
	var d = db.random_deck()
	db.free()
	return d



#--------Overworld stuff ---------------
func remember_overworld(scene_path, player_position):
	overworld_scene = scene_path
	overworld_position = player_position
	world_scene = scene_path
	world_position = player_position
	has_world_position = true
	save_game()
	_restore_player = true


func return_to_overworld():
	if overworld_scene == "":
		go_to_binder()
		return
	get_tree().paused = false
	Transition.change_scene(overworld_scene)


# puts the player back where they were when the overworld loads again
func _on_node_added(node):
	if _restore_player and node is Node2D and node.is_in_group("player"):
		_restore_player = false
		node.global_position = overworld_position      # now, before the camera first looks
		_snap_camera.call_deferred(node)


func _snap_camera(player):
	var cam = get_viewport().get_camera_2d()
	if cam == null or not is_instance_valid(player):
		return
	if not player.is_ancestor_of(cam):
		cam.global_position = player.global_position   # a camera that follows from outside the player
	cam.reset_smoothing()
	cam.force_update_scroll()


# ---------- battles ----------

func start_battle(npc_id):
	current_npc = npc_id
	opponent_sleeve = _pick_opponent_sleeve()
	var npc = NPCDatabase.NPCS.get(npc_id, {})
	rules = BoardRules.build(npc.get("rules", []))
	get_tree().paused = false
	Transition.change_scene(BATTLE_SCENE)
	


func go_to_binder(origin = ""):
	binder_origin = origin
	get_tree().paused = false
	Transition.change_scene(BINDER_SCENE)


# leaves the binder, back to wherever it was opened from
func close_binder():
	get_tree().paused = false
	if binder_origin == "battle" or binder_origin == "gameover":
		Transition.change_scene(BATTLE_SCENE)
	else:
		return_to_overworld()


func _ensure_action(action, keycode):
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var key = InputEventKey.new()
	key.physical_keycode = keycode
	InputMap.action_add_event(action, key)


# Tab in the overworld opens the binder
func _input(event):
	if get_tree().paused:
		return
	if not event.is_action_pressed("binder_toggle"):
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null or get_tree().current_scene == null:
		return
	get_viewport().set_input_as_handled()
	remember_overworld(get_tree().current_scene.scene_file_path, player.global_position)
	go_to_binder("overworld")


func npc_difficulty():
	return NPCDatabase.NPCS.get(current_npc, {}).get("difficulty", "")


func is_banned(card_type):
	return card_type in rules["banned_types"]


# adds the win rewards to the collection. Returns text for the game over screen
func reward_options():
	if current_npc == "":
		return []
	var rewards = NPCDatabase.NPCS.get(current_npc, {}).get("rewards", {})
	var first = not defeated.has(current_npc)
	if not first and not rewards.get("repeatable", true):
		return []
	var options = []
	if first and rewards.has("first_win_card"):
		options.append(rewards["first_win_card"])
	var pool = rewards.get("pool", []).duplicate()
	for c in rewards.get("cards", []):          # shorthand: just list the card names
		pool.append({"card": c, "weight": 1})
	var want = rewards.get("options", rewardCardAmount)
	while options.size() < want and not pool.is_empty():
		var pick = _weighted_pick(pool)
		options.append(pick)
		pool = pool.filter(func(e): return e["card"] != pick)
	return options

func claim_reward(card_name):
	if collection.get(card_name, 0) == 0 and not new_cards.has(card_name):
		new_cards.append(card_name)               # first copy: shows a NEW badge in the Binder
	collection[card_name] = collection.get(card_name, 0) + 1
	mark_defeated()

func board_for_battle():
	var npc = NPCDatabase.NPCS.get(current_npc, {})
	var id = npc.get("board", "")
	if id == "" and npc.has("boards"):
		id = npc["boards"].pick_random()           # a few options: picked at random each battle
	if not BoardDatabase.BOARDS.has(id):
		var pool = BoardDatabase.BOARDS.keys().filter(func(k): return BoardDatabase.BOARDS[k].get("random", false))
		if pool.is_empty():
			return {}
		id = pool.pick_random()
	return BoardDatabase.BOARDS[id]

func npc_sleeve():
	return opponent_sleeve

func _pick_opponent_sleeve():
	var npc = NPCDatabase.NPCS.get(current_npc, {})
	var id = npc.get("sleeve", "")
	if id == "" and npc.has("sleeves"):
		id = npc["sleeves"].pick_random()
	if id == "":
		id = NPCDatabase.FACTIONS.get(npc.get("faction", ""), {}).get("sleeve", "")
	if not SleeveDatabase.SLEEVES.has(id):
		var pool = ["default"]
		for key in SleeveDatabase.SLEEVES:
			if SleeveDatabase.SLEEVES[key].get("wild", false):
				pool.append(key)
		id = pool.pick_random()
	return id

func unlock_npc_sleeve():
	var id = NPCDatabase.NPCS.get(current_npc, {}).get("sleeve_reward", "")
	if id == "" or sleeves.has(id) or not SleeveDatabase.SLEEVES.has(id):
		return ""
	sleeves.append(id)
	return SleeveDatabase.SLEEVES[id]["name"]

func mark_defeated():
	if current_npc != "":
		defeated[current_npc] = true
		win_counts[current_npc] = win_counts.get(current_npc, 0) + 1
	save_game()

func _capture_world_position():
	if _restore_player:
		return          # still waiting to put the player back, so the position isn't valid yet
	var player = get_tree().get_first_node_in_group("player")
	var scene = get_tree().current_scene
	if player and player is Node2D and scene and scene.scene_file_path != "":
		world_scene = scene.scene_file_path
		world_position = player.global_position
		has_world_position = true


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func _weighted_pick(pool):
	var total = 0.0
	for entry in pool:
		total += entry.get("weight", 1.0)
	var roll = randf() * total
	for entry in pool:
		roll -= entry.get("weight", 1.0)
		if roll <= 0:
			return entry["card"]
	return pool[-1]["card"]
	
# every card that can be collected: not energy cards, tokens, the Mana Monster, or anything marked "hidden"
func collectible_cards():
	var db = preload("res://Scripts/CardDatabase.gd")
	var list = []
	for card in db.CARDS.keys():
		var data = db.get_card(card)
		if data.get("type", "") != "Mana" and not data.get("token", false) \
				and not data.get("hidden", false) and card != "ManaMonster":
			list.append(card)
	return list


func collected_count():
	var owned = 0
	for card in collectible_cards():
		if collection.get(card, 0) > 0:
			owned += 1
	return owned

func first_turn_is_fixed():
	return NPCDatabase.NPCS.get(current_npc, {}).get("first_turn", "random") in ["player", "opponent"]


func first_turn_for_battle():
	var setting = NPCDatabase.NPCS.get(current_npc, {}).get("first_turn", "random")
	if setting == "player" or setting == "opponent":
		return setting
	return "player" if randf() < 0.5 else "opponent"
