extends Node

@export var ai_magic_bonus = 10.0            # magic gets its mana back, so it's worth a little extra
@export var ai_role_bonus = 10.0             # extra value for cards tagged with an ai_role (their stats undersell them)
@export var ai_mana_reserve = 0              # mana cards the AI keeps back for casting
@export var ai_sport_high_health = 60        # a target with this much health is worth a sports card
@export var ai_sport_min_damage_fraction = 0.5   # without a kill, a sports card must remove this much of the target's health
@export var ai_depth = 3                  # 0 basic, 1 values targets, 2 +hit-back/abilities/blocking, 3 +ability bonuses
@export var ai_noise = 0.0                # random wobble on every score (higher = sloppier)
@export var ai_min_action_score = 5.0     # options scoring below this are skipped (it would rather pass)
@export var ai_heart_value = 60.0         # value of a direct hit on your hearts
@export var ai_play_bonus = 15.0          # base appeal of putting a card on the board
@export var ai_attach_now_bonus = 15.0    # attaching to a card that can attack this turn
var ai_monsters_played = 0             
enum AIDifficulty { CUSTOM, EASY, NORMAL, HARD }
@export var ai_difficulty: AIDifficulty = AIDifficulty.CUSTOM
@export var give_up_button: Button
var firstturn = true

const CARD_SMALL_CARD_SCALE = 0.8
const CARD_MOVE_SPEED = 0.2
const CARD_ATTACKING_Z_INDEX = 5
const CARD_DEFAULT_Z_INDEX = 0
const BATTLE_POS_OFFSET = 25
const OPPONENT_STARTING_HEALTH = 5
const PLAYER_STARTING_HEALTH = 5
const HEART_ICON = preload("res://Scenes/Heart_Icon.tscn")
const CARD_DATABASE = preload("res://Scripts/CardDatabase.gd")
const USED_CARD_COLOR = Color(0.6, 0.6, 0.6)
const NEGATIVE_STATUSES = ["burned", "blinded", "cant_attack", "poisoned"]
const CARD_SCENES = {"Player": "res://Scenes/card.tscn", "Opponent": "res://Scenes/Opponentcard.tscn"}

@export var ai_cost_penalty = 10.0
@export var stalemate_rounds = 3      # rounds in a row with no damage before the game is called (0 = off)
@export var stalemate_button: Button

var quiet_rounds = 0
var damage_this_round = false
var battle_timer
var empty_monster_card_slots = []
var opponent_cards_on_battlefield = []
var player_cards_on_battlefield = []
var player_cards_that_attacked_this_turn = []
var player_graveyard = []
var opponent_graveyard = []
var card_to_attack
var player_health
var opponent_health
var is_opponents_turn = false
var player_is_attacking = false
var game_over = false
var rounds_played = 0
var hearts_animate = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Audio.play_music("battle")
	firstturn = true
	if not InputMap.has_action("end_turn"):
		InputMap.add_action("end_turn")
		var key = InputEventKey.new()
		key.physical_keycode = KEY_SPACE
		InputMap.action_add_event("end_turn", key)
	battle_timer = $"../BattleTimer"
	battle_timer.one_shot = true
	battle_timer.wait_time = 1.0
	#GameState.reset_save()  --------- Unhide to reset save
	for slot in $"../CardSlots".get_children():
		if slot.name.begins_with("Enemy"):
			empty_monster_card_slots.append(slot)
	
	var diff = GameState.npc_difficulty()
	if diff != "" and AIDifficulty.has(diff):
		ai_difficulty = AIDifficulty[diff]
	apply_ai_difficulty()
	opponent_health = GameState.rules["opponent_hearts"]
	player_health = GameState.rules["player_hearts"]
	call_deferred("_restore_game_over")
	update_hearts_display()
	if give_up_button:
		give_up_button.pressed.connect(_on_give_up)
	if stalemate_button:
		stalemate_button.visible = false
		stalemate_button.pressed.connect(_on_call_stalemate)
	hearts_animate = true
	if GameState.pending_game_over.is_empty():          # not when returning to a game over screen
		_start_with_coin_flip()

func _process(_delta):
	# keeps monster damage labels current (Jump Man gaining mana, Pencil swaps, ...)
	for card in player_cards_on_battlefield + opponent_cards_on_battlefield:
		if is_instance_valid(card) and card.card_type == "Monster":
			update_attack_label(card)

func _on_end_turn_button_pressed() -> void:
	if firstturn == true:
		firstturn = false
	run_turn_end(player_cards_on_battlefield)
	is_opponents_turn = true
	_update_stalemate_button()
	$"../CardManager".cancel_drag()
	$"../CardManager".unselect_selected_monster()
	player_cards_that_attacked_this_turn = []
	clear_status(player_cards_on_battlefield, "cant_attack")
	opponent_turn()

func _on_give_up():
	if game_over:
		return
	var dialog = ConfirmationDialog.new()
	dialog.title = "Give up?"
	dialog.dialog_text = "Give up this battle?\nIt counts as a loss, with no rewards."
	dialog.ok_button_text = "Give Up"
	dialog.cancel_button_text = "Keep Playing"
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(dialog)
	get_tree().paused = true
	dialog.confirmed.connect(_give_up_confirmed)
	dialog.canceled.connect(_give_up_cancelled.bind(dialog))
	dialog.popup_centered()


func _give_up_cancelled(dialog):
	get_tree().paused = false
	dialog.queue_free()


func _give_up_confirmed():
	game_over = true
	GameState.pending_game_over = {}
	GameState.return_to_overworld()

func note_damage():
	damage_this_round = true
	_update_stalemate_button()


func _update_stalemate_button():
	if stalemate_button:
		stalemate_button.visible = quiet_rounds >= stalemate_rounds and not damage_this_round \
			and not game_over and not is_opponents_turn

func has_keyword(card, key):
	return card.statuses.has(key) or key in card.get_meta("keywords", [])

func _start_with_coin_flip():
	var who = GameState.first_turn_for_battle()
	var player_first = who == "player"
	var opponent_name = NPCDatabase.NPCS.get(GameState.current_npc, {}).get("name", "Opponent")
	await get_tree().create_timer(0.7).timeout           # let the hands finish dealing
	if GameState.first_turn_is_fixed():
		Juice.banner("You go first!" if player_first else "%s goes first!" % opponent_name)
	else:
		get_tree().paused = true
		await Juice.coin_flip(player_first, opponent_name)
		get_tree().paused = false
	if not player_first:
		_on_end_turn_button_pressed() 

func cleanse(cards):
	for card in cards:
		for status in NEGATIVE_STATUSES:
			card.statuses.erase(status)
		release_ties(card)                 # also frees whatever it was tied to


func tick_poison(cards, card_owner):
	for card in cards.duplicate():
		if card.statuses.has("poisoned"):
			apply_damage(card, ceili(card.max_health / 8.0), "poison")
			if card.health <= 0:
				destroy_card(card, card_owner)

func _on_call_stalemate():
	if game_over:
		return
	game_over = true
	stalemate_button.visible = false
	get_tree().paused = true
	$"../GameOver".show_result("tie", "TIE", "Stalemate: nobody dealt damage for %d rounds" % quiet_rounds)

func mark_card_used(card):
	card.modulate = USED_CARD_COLOR
	card.set_meta("used_this_turn", true)

func refresh_card_color(cards):
	for card in cards:
		card.modulate = Color.WHITE

func update_hearts_display():
	_fill_hearts(get_node_or_null("../PlayerHearts"), player_health)
	_fill_hearts(get_node_or_null("../OpponentHearts"), opponent_health)
	var player_label = get_node_or_null("../PlayerHealthText")
	if player_label:
		player_label.text = str(maxi(player_health, 0))
	var opponent_label = get_node_or_null("../OpponentHealthText")
	if opponent_label:
		opponent_label.text = str(maxi(opponent_health, 0))


func _fill_hearts(holder, count):
	if not holder:
		return
	count = maxi(count, 0)                 # a big hit can't take you below zero
	while holder.get_child_count() > count:
		var extra = holder.get_child(holder.get_child_count() - 1)
		if hearts_animate:
			Juice.heart_pop(extra)
		holder.remove_child(extra)
		extra.queue_free()
	while holder.get_child_count() < count:
		holder.add_child(HEART_ICON.instantiate())

func _unhandled_input(event):
	if event.is_action_pressed("end_turn"):
		var button = get_node_or_null("../EndTurnButton")
		if button and button.visible and not button.disabled \
				and not game_over and not is_opponents_turn and not get_tree().paused:
			get_viewport().set_input_as_handled()
			button.pressed.emit()

func check_game_over():
	if game_over:
		return
	var outcome = get_game_result()
	if outcome["result"] == "":
		return
	game_over = true
	await get_tree().create_timer(0.8).timeout     # let the hit land first
	var title = "TIE"
	if outcome["result"] == "player":
		title = "YOU WIN"
	elif outcome["result"] == "opponent":
		title = "YOU LOSE"
	get_tree().paused = true
	$"../GameOver".show_result(outcome["result"], title, outcome["reason"])

func _restore_game_over():
	if GameState.pending_game_over.is_empty():
		return
	var p = GameState.pending_game_over
	GameState.pending_game_over = {}
	game_over = true
	get_tree().paused = true
	$"../GameOver".show_result(p["result"], p["title"], p["reason"])

# returns {"result": "player" / "opponent" / "tie" / "", "reason": String}
func get_game_result():
	# 1. hearts
	if player_health <= 0 and opponent_health <= 0:
		return {"result": "tie", "reason": "Both out of hearts"}
	if opponent_health <= 0:
		return {"result": "player", "reason": "Opponent out of hearts"}
	if player_health <= 0:
		return {"result": "opponent", "reason": "You ran out of hearts"}

	# 2. nobody can ever reach the other side's hearts
	var player_stuck = side_cannot_win("Player")
	var opponent_stuck = side_cannot_win("Opponent")
	if player_stuck and opponent_stuck:
		return {"result": "tie", "reason": "Neither side can attack anymore"}
	if player_stuck and not side_has_type("Player", "Sport"):
		return {"result": "opponent", "reason": "You have nothing left that can attack"}
	if opponent_stuck and not side_has_type("Opponent", "Sport"):
		return {"result": "player", "reason": "Opponent has nothing left that can attack"}

	# 3. mana ran out, or the turn limit hit: most hearts wins
	var limit = GameState.rules["turn_limit"]
	var limit_hit = limit > 0 and rounds_played >= limit
	if mana_exhausted() or limit_hit:
		var why = "Turn limit reached" if limit_hit else "Out of mana"
		if limit_hit:
			why = "Turn limit reached"
		if player_health > opponent_health:
			return {"result": "player", "reason": why + " - you have more hearts"}
		if opponent_health > player_health:
			return {"result": "opponent", "reason": why + " - opponent has more hearts"}
		return {"result": "tie", "reason": why + " - hearts are equal"}

	return {"result": "", "reason": ""}

func mana_exhausted():
	return $"../ManaDeck".mana_deck.is_empty() 
	#currently last mana drawn ends, add back in next 2 lines to make it wait for mana to be spent too
		#and $"../PlayerManaHand".player_mana_hand.is_empty() \
		#and $"../OpponentManaHand".opponent_mana_hand.is_empty()

func spawn_card(card_name, side, slot = null, play_hook = false):
	if slot == null:
		slot = free_slot_for(side)
	if slot == null:
		return null
	var card = load(CARD_SCENES[side]).instantiate()
	CardFactory.apply_data(card, card_name)
	var deck = $"../Deck" if side == "Player" else $"../OpponentDeck"
	if ResourceLoader.exists("res://CardSprites/Cards_" + card_name + ".png"):
		for kind in ["Monster", "Magic", "Sport"]:
			if kind != card.card_type:
				deck.hide_text(card, kind)
		deck.show_text(card, card.card_type, card_name)
		update_attack_label(card)
	else:                                  # no art yet: the same placeholder the decks use
		card.get_node("Attack").text = "!"
		card.get_node("Health").text = "!"
		card.get_node("CardImage").texture = load("res://CardSprites/Cards_back.png")
	$"../CardManager".add_child(card)
	card.name = "Card"
	CardFactory.apply_sleeve(card, GameState.equipped_sleeve if side == "Player" else GameState.npc_sleeve())
	card.position = slot.position
	card.scale = Vector2.ZERO
	var target_scale
	if side == "Player":
		var size = $"../CardManager".IN_SLOT_CARD_SCALE
		target_scale = Vector2(size, size)
		slot.get_node("Area2D/CollisionShape2D").set_deferred("disabled", true)
		player_cards_on_battlefield.append(card)
	else:
		target_scale = Vector2(CARD_SMALL_CARD_SCALE, CARD_SMALL_CARD_SCALE)
		card.rotation_degrees = 180
		empty_monster_card_slots.erase(slot)
		opponent_cards_on_battlefield.append(card)
	slot.card_in_slot = true
	card.card_slot_card_is_in = slot
	card.just_played = true                # summoned cards can't attack until their owner's next turn
	card.get_node("AnimationPlayer").play("card_flip")
	create_tween().tween_property(card, "scale", target_scale, 0.3)
	if play_hook:
		trigger_hook(card, "on_played")
	return card


# a free slot on a side's half of the board, front row (odd numbers) first
func free_slot_for(side):
	var options = []
	if side == "Player":
		for slot in $"../CardSlots".get_children():
			if not slot.name.begins_with("Enemy") and slot.get("card_in_slot") == false:
				options.append(slot)
	else:
		options = empty_monster_card_slots.duplicate()
	if options.is_empty():
		return null
	for slot in options:
		if slot_number(slot) % 2 == 1:
			return slot
	return options[0]


func slot_number(slot):
	var slot_name = String(slot.name)
	var digits = ""
	for i in range(slot_name.length() - 1, -1, -1):
		if slot_name[i].is_valid_int():
			digits = slot_name[i] + digits
		else:
			break
	return int(digits) if digits != "" else -1

# card types in a side's hand and deck
func side_card_types(side):
	var types = []
	var hand
	var deck
	if side == "Player":
		hand = $"../PlayerHand".player_hand
		deck = $"../Deck".player_deck
	else:
		hand = $"../OpponentHand".opponent_mana_hand   # (this array is the opponent's card hand)
		deck = $"../OpponentDeck".opponent_deck
	for c in hand:
		types.append(c.card_type)
	for n in deck:
		types.append(CARD_DATABASE.get_card(n)["type"])
	return types

func side_has_type(side, type_name):
	return type_name in side_card_types(side)

func side_cannot_win(side):
	var field = player_cards_on_battlefield if side == "Player" else opponent_cards_on_battlefield
	for card in field:
		if not card.statuses.has("never_attacks"):
			return false
	var types = side_card_types(side)
	return not ("Monster" in types or "Magic" in types)

func has_tag(card, tag):
	return tag in card.get_meta("tags", [])

# cards on the field with a tag. side: "Player", "Opponent" or "both"
func cards_with_tag(tag, side = "both"):
	var pool = []
	if side != "Opponent":
		pool += player_cards_on_battlefield
	if side != "Player":
		pool += opponent_cards_on_battlefield
	var result = []
	for c in pool:
		if has_tag(c, tag):
			result.append(c)
	return result

func opponent_turn():
	# start of the opponent's turn
	Juice.banner("Opponent's Turn", Color(0.9, 0.45, 0.4))
	ai_monsters_played = 0
	for mana_card in $"../OpponentManaHand".opponent_mana_hand:
		mana_card.mana_selected = false
		mana_card.modulate.a = 1.0
	for card in opponent_cards_on_battlefield:
		card.modulate = Color.WHITE
		card.just_played = false
		trigger_hook(card, "on_turn_start")
	restore_magic_health(opponent_cards_on_battlefield)
	tick_poison(opponent_cards_on_battlefield, "Opponent")
	$"../EndTurnButton".disabled = true
	$"../EndTurnButton".visible = false

	# draw
	if $"../ManaDeck".mana_deck.size() != 0:
		$"../ManaDeck".draw_card()
		await wait(1.0)
	if firstturn == false:
		if $"../OpponentDeck".opponent_deck.size() != 0:
			$"../OpponentDeck".draw_card()
			await wait(1.0)
	check_game_over()

	# play a card if there's a free slot
	if ai_depth <= 0:
		if empty_monster_card_slots.size() != 0:
			await ai_play_phase()
		await ai_sports_phase()
		await ai_attach_mana()
		await ai_attack_phase_basic()
	else:
		await ai_turn_loop()
	end_opponent_turn()

func direct_attack(attacking_card, attacker):
	mark_card_used(attacking_card)
	var new_pos_y
	if attacker == "Opponent":
		new_pos_y = 1080
	else:
		$"../EndTurnButton".disabled = true
		$"../EndTurnButton".visible = false
		player_is_attacking = true
		new_pos_y = 0
		player_cards_that_attacked_this_turn.append(attacking_card)
	
	var new_pos = Vector2(attacking_card.position.x, new_pos_y)
	attacking_card.z_index = CARD_ATTACKING_Z_INDEX
	
	var tween = get_tree().create_tween()
	tween.tween_property(attacking_card, "position", new_pos, CARD_MOVE_SPEED)
	await wait(0.15)
	
	var missed = attacking_card.statuses.has("blinded") and randf() < 0.5
	if missed:
		#print(attacking_card.name, " missed!")
		return
	elif attacker == "Opponent":
		player_health -= GameState.rules["direct_hit_damage"]
		note_damage()
		Juice.shake(14.0, 0.3)
	else:
		opponent_health -= GameState.rules["direct_hit_damage"]
		note_damage()
		Juice.shake(14.0, 0.3)
	update_hearts_display()
	check_game_over()
		
	var tween2 = get_tree().create_tween()
	tween2.tween_property(attacking_card, "position", attacking_card.card_slot_card_is_in.position, CARD_MOVE_SPEED)
	attacking_card.z_index = CARD_DEFAULT_Z_INDEX
	await tween2.finished
	
	attacking_card.z_index = CARD_DEFAULT_Z_INDEX
	await wait(1.0)
	
	if attacker == "Player":
		player_is_attacking = false
		$"../EndTurnButton".disabled = false
		$"../EndTurnButton".visible = true
	

func attack(attacking_card, defending_card, attacker, force_hit = false):
	mark_card_used(attacking_card)
	defending_card = await offer_block(attacking_card, defending_card, attacker)
	if attacker == "Player":
		player_is_attacking = true
		$"../EndTurnButton".disabled = true
		$"../EndTurnButton".visible = false
		$"../CardManager".selected_monster = null
		$"../CardManager".hide_attack_menu()
		player_cards_that_attacked_this_turn.append(attacking_card)
	attacking_card.z_index = CARD_ATTACKING_Z_INDEX
	var new_pos = Vector2(defending_card.position.x, defending_card.position.x + BATTLE_POS_OFFSET )
	var tween = get_tree().create_tween()
	tween.tween_property(attacking_card, "position", defending_card.card_slot_card_is_in.position, CARD_MOVE_SPEED)
	await tween.finished
	var tween2 = get_tree().create_tween()
	tween2.tween_property(attacking_card, "position", attacking_card.card_slot_card_is_in.position, CARD_MOVE_SPEED)
	attacking_card.z_index = CARD_DEFAULT_Z_INDEX
	
	#If defender is magic, it hits back, else it doenst
	var move = attacking_card.attacks[attacking_card.selected_attack]
	var damage = move_damage(attacking_card, move)
	if move.get("crush", false):               # Crush: always half of the target's current health, rounded up
		damage = ceili(defending_card.health / 2.0)
	var trample_excess = 0
	var trample_card = null
	var friendly_target = (defending_card in player_cards_on_battlefield) == (attacker == "Player") and not force_hit
	var missed = attacking_card.statuses.has("blinded") and randf() < 0.5 and not friendly_target
	if missed:
		#print(attacking_card.name, " missed!")
		return
	else:
		if damage > 0 and not friendly_target:
			var health_before = defending_card.health
			var dealt = apply_damage(defending_card, damage, "attack")
			if has_keyword(attacking_card, "trample") and dealt > health_before:
				trample_excess = dealt - health_before
				trample_card = card_behind(defending_card)
			if defending_card.card_type == "Magic":
				apply_damage(attacking_card, defending_card.attack, "attack")
		if not friendly_target:
			trigger_hook(defending_card, "on_attacked", [attacking_card, damage])
		if move.has("effect"):
			await trigger_hook(attacking_card, move["effect"], [defending_card])
	
	
	await wait(1.0)
	attacking_card.z_index = CARD_DEFAULT_Z_INDEX
	
	var card_was_destroyed = false
	
	if attacking_card.health == 0:
		destroy_card(attacking_card, attacker)
		card_was_destroyed = true
	
	if defending_card.health == 0:
		var defender_owner = "Player" if defending_card in player_cards_on_battlefield else "Opponent"
		destroy_card(defending_card, defender_owner)
		if trample_excess > 0 and trample_card and is_instance_valid(trample_card) and trample_card.health > 0:
			apply_damage(trample_card, trample_excess, "attack")
			if trample_card.health == 0:
				destroy_card(trample_card, owner_of(trample_card))
		card_was_destroyed = true
	
	if card_was_destroyed:
		await wait(1.0)
		
	if attacker == "Player":
		$"../EndTurnButton".disabled = false
		$"../EndTurnButton".visible = true
		player_is_attacking = false

func forced_attack(forced_card, target):
	if not is_instance_valid(forced_card) or not is_instance_valid(target) or target == forced_card:
		return
	var best = -1
	var best_damage = 0
	for i in range(forced_card.attacks.size()):
		var m = forced_card.attacks[i]
		if m.get("passive", false):
			continue
		var d = move_damage(forced_card, m)
		if d > best_damage:
			best_damage = d
			best = i
	if best < 0:
		return
	forced_card.selected_attack = best
	await attack(forced_card, target, owner_of(forced_card), true)


func is_tied(card):
	if not card.statuses.has("tied_to"):
		return false
	var still_tied = []
	for other in card.statuses["tied_to"]:
		if is_instance_valid(other) and (other in player_cards_on_battlefield or other in opponent_cards_on_battlefield):
			still_tied.append(other)
	if still_tied.is_empty():
		card.statuses.erase("tied_to")
		return false
	card.statuses["tied_to"] = still_tied
	return true
	
func offer_block(attacking_card, defending_card, attacker):
	var friendly = (defending_card in player_cards_on_battlefield) == (attacker == "Player")
	if friendly:
		return defending_card
	var defender_is_player = defending_card in player_cards_on_battlefield
	for blocker in adjacent_cards(defending_card):
		if blocker == attacking_card or blocker.health <= 0:
			continue
		if (blocker in player_cards_on_battlefield) != defender_is_player:
			continue
		var script = blocker.ability_script
		if not script or not script.has_method("can_block"):
			continue
		if not script.can_block(attacking_card, defending_card):
			continue
		var accepted
		if defender_is_player:
			accepted = await $"../CardManager".ask_block(blocker)
		else:
			accepted = ai_wants_block(blocker, attacking_card, defending_card)
		if accepted:
			return blocker
	return defending_card

# AI blocks if the hit would kill the target (or the target is "protected")
# and the blocker would survive it
func ai_wants_block(blocker, attacking_card, target):
	if ai_depth < 2:
		return false
	var dmg
	if attacking_card.card_type == "Sport":
		dmg = attacking_card.attack
	else:
		dmg = move_damage(attacking_card, attacking_card.attacks[attacking_card.selected_attack])
	if dmg <= 0 or blocker.health <= dmg:
		return false
	return target.health <= dmg or target.get_meta("ai_role", "") == "protected"
	

func destroy_card(card, card_owner):
	if card.has_meta("planted_mana"):
		if card.get("mana_selected"):
			$"../CardManager".drop_planted_selection(card)
		release_ties(card)
		remove_planted_from_field(card)     # gone for good: no discard
		card.queue_free()
		return
	if card.get_meta("token", false):
		release_ties(card)
		var slot = card.card_slot_card_is_in
		if card_owner == "Player":
			player_cards_on_battlefield.erase(card)
			if slot:
				slot.get_node("Area2D/CollisionShape2D").disabled = false
		else:
			opponent_cards_on_battlefield.erase(card)
			if slot and slot.card_slot_type == "Monster" and slot not in empty_monster_card_slots:
				empty_monster_card_slots.append(slot)
		trigger_hook(card, "on_destroyed")        # the Piñata pays out here
		if slot:
			slot.card_in_slot = false
		card.card_slot_card_is_in = null
		card.defeated = true
		card.get_node("Area2D/CollisionShape2D").set_deferred("disabled", true)
		var fade = get_tree().create_tween()
		fade.tween_property(card, "modulate:a", 0.0, 0.25)
		fade.tween_callback(card.queue_free)
		check_game_over()
		return
	if card.statuses.has("returns_to_hand"):
		return_card_to_hand(card)
		trigger_hook(card, "on_returned_to_hand")
		return
	release_ties(card)
	restore_original_stats(card)
	var new_pos
	if card_owner == "Player":
		card.defeated = true
		card.get_node("Area2D/CollisionShape2D").disabled = true
		new_pos = $"../PlayerDiscard".position
		if card in player_cards_on_battlefield:
			player_cards_on_battlefield.erase(card)
		card.card_slot_card_is_in.get_node("Area2D/CollisionShape2D").disabled = false
	else:
		new_pos = $"../OpponentDiscard".position
		card.get_node("Area2D/CollisionShape2D").set_deferred("disabled", true)
		opponent_cards_on_battlefield.erase(card)
		if card.card_slot_card_is_in.card_slot_type == "Monster" and card.card_slot_card_is_in not in empty_monster_card_slots:
			empty_monster_card_slots.append(card.card_slot_card_is_in)
	trigger_hook(card, "on_destroyed")
	if card_owner == "Player":
		player_graveyard.append(card)
	else:
		opponent_graveyard.append(card)
	card.card_slot_card_is_in.card_in_slot = false
	card.card_slot_card_is_in = null
	
	card.attached_mana = 0
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", new_pos, CARD_MOVE_SPEED)
	check_game_over()

func opponent_card_selected(defending_card):
	if $"../CardManager".pick_active:
		$"../CardManager".submit_pick(defending_card)
		return
	var attacking_card = $"../CardManager".selected_monster
	if attacking_card and defending_card in opponent_cards_on_battlefield and not player_is_attacking:
		if not can_be_attacked(defending_card, attacking_card):
			return
		attack(attacking_card, defending_card, "Player")


func try_play_card_with_highest_atk():
	var opponent_mana_hand = $"../OpponentHand".opponent_mana_hand
	if opponent_mana_hand.size() == 0:
		return
		#set random slot
	var random_empty_empty_monster_card_slot = empty_monster_card_slots.pick_random()
	empty_monster_card_slots.erase(random_empty_empty_monster_card_slot)
	var card_with_highest_atk = opponent_mana_hand[0]
	for card in opponent_mana_hand:
		if card.attack > card_with_highest_atk.attack:
			card_with_highest_atk = card
	
	card_with_highest_atk.rotation_degrees = 180
	var tween = get_tree().create_tween()
	tween.tween_property(card_with_highest_atk, "position", random_empty_empty_monster_card_slot.position, CARD_MOVE_SPEED)
	var tween2 = get_tree().create_tween()
	tween2.tween_property(card_with_highest_atk, "scale", Vector2(CARD_SMALL_CARD_SCALE,CARD_SMALL_CARD_SCALE), CARD_MOVE_SPEED)
	card_with_highest_atk.get_node("AnimationPlayer").play("card_flip")
	$"../OpponentHand".remove_card_from_hand(card_with_highest_atk)
	card_with_highest_atk.card_slot_card_is_in = random_empty_empty_monster_card_slot
	random_empty_empty_monster_card_slot.card_in_slot = true
	trigger_hook(card_with_highest_atk, "on_played")
	card_with_highest_atk.just_played = true
	opponent_cards_on_battlefield.append(card_with_highest_atk)
	await wait(1.0)

func update_health_label(card):
	card.get_node(str("Transform/HealthText" + card.card_type)).text = str(card.health)

func update_mana_label(card):
	card.get_node(str("Transform/Mana" + card.card_type)).text = str(card.mana)

func apply_damage(target, amount, source_type):
	if target.statuses.has("immune_to_attacks") and source_type == "attack":
		amount = 0    # Shield Girl
	if target.statuses.has("only_hurt_by_attacks") and source_type != "attack":
		amount = 0    # Sword Guy
	if target.statuses.has("burned"):
		amount *= 2   # Fire Alligator, Literal Fire
	if target.statuses.has("ignores_damage"):
		amount = 0    
	target.health = max(0, target.health - amount)
	update_health_label(target)
	if amount > 0:
		note_damage()
		Juice.hit(target, amount)
		Audio.play("hit")
		trigger_hook(target, "on_damaged", [amount, source_type])
	return amount

# what a hit of this size would really do to this target (no side effects)
func predict_amount(amount, target, source_type = "attack"):
	if target.ability_script and target.ability_script.has_method("predict_damage"):
		amount = target.ability_script.predict_damage(amount)    # some cards cap what one hit can do
	if target.statuses.has("immune_to_attacks") and source_type == "attack":
		return 0
	if target.statuses.has("only_hurt_by_attacks") and source_type != "attack":
		return 0
	if target.statuses.has("burned"):
		amount *= 2
	if target.statuses.has("ignores_damage"):
		return 0
	return amount


func predict_damage(attacker, move, target):
	var amount = move_damage(attacker, move)
	if move.get("crush", false):
		amount = ceili(target.health / 2.0)
	return predict_amount(amount, target, "attack")


func can_use_attack(card, attack_data):
	return card.attached_mana >= attack_data["cost"]
	

func slot_has_card(slot):
	for card in player_cards_on_battlefield:
		if card.card_slot_card_is_in == slot:
			return true
	for card in opponent_cards_on_battlefield:
		if card.card_slot_card_is_in == slot:
			return true
	return false

func choose_default_attack(card):
	for i in range(card.attacks.size() - 1, -1, -1):
		var move = card.attacks[i]
		if move_damage(card, move) > 0 and can_use_attack(card, move):
			card.selected_attack = i
			return true
	return false

func has_usable_attack(card):
	for atk in card.attacks:
		if can_use_attack(card, atk):
			return true
	return false

func get_attack_damage(card):
	return move_damage(card, card.attacks[card.selected_attack])

func restore_magic_health(cards):
	for card in cards:
		if card.card_type == "Magic":
			card.health = card.max_health
			update_health_label(card)

func can_be_attacked(card, attacker = null):
	if not _hittable(card, attacker):
		return false
	if has_keyword(card, "taunt"):
		return true
	var side = player_cards_on_battlefield if card in player_cards_on_battlefield else opponent_cards_on_battlefield
	for other in side:
		if other != card and has_keyword(other, "taunt") and _hittable(other, attacker):
			return false
	return true


func _hittable(card, attacker):
	return not has_keyword(card, "invisible") and _row_exposed(card, attacker)


# this is your old can_be_attacked: the front-row rule, plus a Reach shortcut
func _row_exposed(card, attacker):
	var slot = card.card_slot_card_is_in
	if not slot:
		return false
	if attacker and has_keyword(attacker, "reach"):
		return true                        # Reach ignores the front-row rule

	# split a name like "EnemyCardSlot4" into its prefix and number
	var slot_name = String(slot.name)
	var digits = ""
	for i in range(slot_name.length() - 1, -1, -1):
		if slot_name[i].is_valid_int():
			digits = slot_name[i] + digits
		else:
			break
	if digits == "":
		return true   # no number in the name, so no rule applies

	var number = int(digits)
	if number % 2 != 0:
		return true   # odd slots are the front row

	var prefix = slot_name.substr(0, slot_name.length() - digits.length())
	var front_slot = slot.get_parent().get_node_or_null(prefix + str(number - 1))
	return not (front_slot and slot_has_card(front_slot))


func get_attackable(cards, attacker = null):
	return cards.filter(func(c): return can_be_attacked(c, attacker))

func trigger_hook(card, hook_name, args = []):
	if card.ability_script and card.ability_script.has_method(hook_name):
		return await card.ability_script.callv(hook_name, args)

# for abilities that need no target. The effect function receives null.
func use_self_ability(card):
	mark_card_used(card)
	var move = card.attacks[card.selected_attack]
	player_cards_that_attacked_this_turn.append(card)
	trigger_hook(card, move["effect"], [null])

func apply_status(card, status):
	card.statuses[status] = true
	trigger_hook(card, "on_status_applied", [status])

func clear_status(cards, status):
	for card in cards:
		card.statuses.erase(status)

func run_turn_end(cards):
	for card in cards.duplicate():
		var used = card.get_meta("used_this_turn", false)
		trigger_hook(card, "on_turn_end", [used])
		card.set_meta("used_this_turn", false)

func heal(card, amount):
	var before = card.health
	card.health = min(card.max_health, card.health + amount)
	if card.health > before:
		Juice.float_at(card, "+" + str(card.health - before), Juice.GREEN)

func transform_card(card, new_name):
	if not is_instance_valid(card):
		return
	card.statuses.clear()
	if card.has_meta("ai_role"):
		card.remove_meta("ai_role")
	CardFactory.apply_data(card, new_name)
	card.selected_attack = 0
	var art = "res://CardSprites/Cards_" + new_name + ".png"
	if ResourceLoader.exists(art):
		card.get_node("CardImage").texture = load(art)
	update_attack_label(card)
	update_health_label(card)
	update_mana_label(card)



# cards next to a card: left/right in the same row, plus the one in front or behind
func adjacent_cards(card):
	var result = []
	var slot = card.card_slot_card_is_in
	if not slot:
		return result
	var slot_name = String(slot.name)
	var digits = ""
	for i in range(slot_name.length() - 1, -1, -1):
		if slot_name[i].is_valid_int():
			digits = slot_name[i] + digits
		else:
			break
	if digits == "":
		return result
	var number = int(digits)
	var prefix = slot_name.substr(0, slot_name.length() - digits.length())
	var partner = number + 1 if number % 2 != 0 else number - 1
	for n in [partner, number - 2, number + 2]:
		var neighbour_slot = slot.get_parent().get_node_or_null(prefix + str(n))
		if neighbour_slot:
			var other = card_in_slot(neighbour_slot)
			if other and other != card:
				result.append(other)
	return result


func can_card_attack(card):
	#print(card.name, " ", card.just_played, " ", card.statuses)
	if card.just_played and not has_keyword(card, "haste"):
		return false
	if card.statuses.has("never_attacks"):
		return false
	if card.statuses.has("cant_attack"):
		return false
	if is_tied(card):
		return false
	return true

func tie_cards(a, b):
	for pair in [[a, b], [b, a]]:
		if not pair[0].statuses.has("tied_to"):
			pair[0].statuses["tied_to"] = []
		pair[0].statuses["tied_to"].append(pair[1])

func release_ties(card):
	if not card.statuses.has("tied_to"):
		return
	for other in card.statuses["tied_to"]:
		if is_instance_valid(other) and other.statuses.has("tied_to"):
			other.statuses["tied_to"].erase(card)
			if other.statuses["tied_to"].is_empty():
				other.statuses.erase("tied_to")   # nobody holds it any more
	card.statuses.erase("tied_to")

# the card in the slot straight behind this one (front-row slots are odd, the back slot is the next number)
func card_behind(card):
	var slot = card.card_slot_card_is_in
	if not slot:
		return null
	var slot_name = String(slot.name)
	var digits = ""
	for i in range(slot_name.length() - 1, -1, -1):
		if slot_name[i].is_valid_int():
			digits = slot_name[i] + digits
		else:
			break
	if digits == "" or int(digits) % 2 == 0:
		return null                        # already the back row, or not a numbered slot
	var prefix = slot_name.substr(0, slot_name.length() - digits.length())
	var behind_slot = slot.get_parent().get_node_or_null(prefix + str(int(digits) + 1))
	if behind_slot == null:
		return null
	for c in player_cards_on_battlefield + opponent_cards_on_battlefield:
		if c.card_slot_card_is_in == behind_slot:
			return c
	return null

func end_opponent_turn():
	rounds_played += 1
	quiet_rounds = 0 if damage_this_round else quiet_rounds + 1
	damage_this_round = false
	run_turn_end(opponent_cards_on_battlefield)
	clear_status(opponent_cards_on_battlefield, "cant_attack")
	is_opponents_turn = false
	Juice.banner("Your Turn")
	$"../CardManager".cancel_drag()
	if firstturn == false:
		$"../Deck".reset_draw()
		$"../Deck".draw_card()
	else:
		firstturn = false
	$"../ManaDeck".reset_draw()
	$"../ManaDeck".draw_card()
	$"../CardManager".reset_played_cards()
	for card in player_cards_on_battlefield:
		card.just_played = false
		card.modulate = Color.WHITE
		trigger_hook(card, "on_turn_start")
	$"../EndTurnButton".disabled = false
	$"../EndTurnButton".visible = true
	$"../CardManager".refresh_mana_cards()
	restore_magic_health(player_cards_on_battlefield)
	tick_poison(player_cards_on_battlefield, "Player")
	_update_stalemate_button()
	check_game_over()
	
	

func move_damage(card, move):
	if move.get("crush", false):
		return maxi(card.attack, 1)            # the real damage depends on the target
	var d = move["damage"]
	if d is String:
		if d == "per_mana":
			return card.attack * card.attached_mana     # attack is the per-mana multiplier
		return card.attack
	# a swapped monster (Pencil) hits with its swapped attack on its first move
	if card.card_type == "Monster" and card.statuses.get("swapped", false) \
			and not card.attacks.is_empty() and move == card.attacks[0] and d != 0:
		return card.attack
	return d

func owner_of(card):
	return "Player" if card in player_cards_on_battlefield else "Opponent"

# draws cards for a side, ignoring the once-per-turn draw limit
func draw_extra_cards(side, amount):
	for i in range(amount):
		if side == "Player":
			var deck = $"../Deck"
			if deck.player_deck.is_empty():
				return
			var had_drawn = deck.drawn_card_this_turn
			deck.drawn_card_this_turn = false
			deck.draw_card()
			deck.drawn_card_this_turn = had_drawn
		else:
			var odeck = $"../OpponentDeck"
			if odeck.opponent_deck.is_empty():
				return
			odeck.draw_card()
		await wait(0.2)

# takes an energy card from the shared mana deck (must be that side's own turn)
func draw_extra_mana(side):
	var md = $"../ManaDeck"
	if md.mana_deck.is_empty():
		return
	if side == "Player":
		var had_drawn = md.drawn_card_this_turn
		md.drawn_card_this_turn = false
		md.draw_card()
		md.drawn_card_this_turn = had_drawn
	else:
		md.draw_card()

func refresh_deck_display(side):
	if side == "Player":
		var d = $"../Deck"
		var count = d.player_deck.size()
		d.get_node("CardCountText").text = str(count) if count > 0 else ""
		d.get_node("Area2D/CollisionShape2D").disabled = count == 0
		d.get_node("Sprite2D").modulate.a = 1.0 if count > 0 else 0.2
	else:
		var d = $"../OpponentDeck"
		var count = d.opponent_deck.size()
		d.get_node("Deck/CardCountText").text = str(count) if count > 0 else ""
		d.get_node("Deck/Sprite2D").modulate.a = 1.0 if count > 0 else 0.2

func shuffle_hand_into_deck(side):
	var hand
	var deck
	if side == "Player":
		hand = $"../PlayerHand".player_hand
		deck = $"../Deck".player_deck
	else:
		hand = $"../OpponentHand".opponent_mana_hand   # (this array is the opponent's card hand)
		deck = $"../OpponentDeck".opponent_deck
	for c in hand.duplicate():
		var n = c.get_meta("card_name", "")
		if n != "":
			deck.append(n)
		hand.erase(c)
		c.queue_free()
	deck.shuffle()
	refresh_deck_display(side)

# takes a card off the field and shuffles it into its owner's deck (no discard)
func shuffle_card_into_deck(card):
	var side = owner_of(card)
	var slot = card.card_slot_card_is_in
	release_ties(card)
	restore_original_stats(card)
	player_cards_that_attacked_this_turn.erase(card)
	if side == "Player":
		player_cards_on_battlefield.erase(card)
		slot.get_node("Area2D/CollisionShape2D").disabled = false
		$"../Deck".player_deck.append(card.get_meta("card_name", ""))
		$"../Deck".player_deck.shuffle()
	else:
		opponent_cards_on_battlefield.erase(card)
		if slot.card_slot_type == "Monster" and slot not in empty_monster_card_slots:
			empty_monster_card_slots.append(slot)
		$"../OpponentDeck".opponent_deck.append(card.get_meta("card_name", ""))
		$"../OpponentDeck".opponent_deck.shuffle()
	slot.card_in_slot = false
	card.card_slot_card_is_in = null
	refresh_deck_display(side)
	card.queue_free()

func update_attack_label(card):
	
	if card.card_type != "Monster":
		card.get_node("Transform/AttackText" + card.card_type).text = str(card.attack)
		return
	var labels = CardFactory.attack_nodes(card, "Monster")
	for i in range(2):
		var text = ""
		if i < card.attacks.size() and not card.attacks[i].get("passive", false):
			var move = card.attacks[i]
			if move.get("crush", false):
				text = ""                              # no fixed amount to show
			elif move["damage"] is String and move["damage"] == "per_mana":
				text = str(card.attack) + "x" if card.attack > 0 else ""
			else:
				var d = move_damage(card, move)
				if d >= 1000:
					text = "∞"
				elif d > 0:
					text = str(d)
		if labels[i] != null:
			if labels[i].text != text:
				labels[i].text = text

func swap_attack_and_health(card):
	if not card.statuses.has("original_stats"):
		card.statuses["original_stats"] = {"attack": card.attack, "max_health": card.max_health}
	var old_attack = card.attack
	card.attack = card.health
	card.health = old_attack
	card.max_health = card.health
	update_attack_label(card)
	update_health_label(card)
	if card.card_type == "Monster":
		card.statuses["swapped"] = not card.statuses.get("swapped", false)

func restore_original_stats(card):
	if not card.statuses.has("original_stats"):
		return
	var original = card.statuses["original_stats"]
	card.attack = original["attack"]
	card.max_health = original["max_health"]
	card.health = card.max_health
	card.statuses.erase("original_stats")
	card.statuses.erase("swapped")
	update_attack_label(card)
	update_health_label(card)

func return_card_to_hand(card):
	player_cards_that_attacked_this_turn.erase(card)
	card.modulate = Color.WHITE
	var slot = card.card_slot_card_is_in
	if not slot:
		return   # not on the field
	update_attack_label(card)

	var is_player_card = card in player_cards_on_battlefield

	# free the slot
	slot.card_in_slot = false
	card.card_slot_card_is_in = null

	# the card comes back fresh
	card.attached_mana = 0
	restore_original_stats(card)
	card.statuses.clear()
	card.just_played = false
	card.health = card.max_health
	update_health_label(card)
	card.z_index = 1

	var target_scale = Vector2(.8,.8)
	if is_player_card:
		player_cards_on_battlefield.erase(card)
		slot.get_node("Area2D/CollisionShape2D").set_deferred("disabled", false)   # slot is usable again
		var s = $"../CardManager".DEFAULT_CARD_SCALE
		target_scale = Vector2(s, s)
		$"../PlayerHand".add_card_to_hand(card, CARD_MOVE_SPEED)
	else:
		opponent_cards_on_battlefield.erase(card)
		if slot.card_slot_type == "Monster" and slot not in empty_monster_card_slots:
			empty_monster_card_slots.append(slot)
		card.get_node("AnimationPlayer").play_backwards("card_flip")   # face-down again
		$"../OpponentHand".add_card_to_hand(card, CARD_MOVE_SPEED)

	var scale_tween = get_tree().create_tween()
	scale_tween.tween_property(card, "scale", target_scale, CARD_MOVE_SPEED)
	check_game_over()

func wait(wait_time):
	#wait 1 second
	battle_timer.wait_time = wait_time
	battle_timer.start()
	await battle_timer.timeout


#=============================AI DECISIONS============================================



func apply_ai_difficulty():
	match ai_difficulty:
		AIDifficulty.EASY:
			ai_depth = 1
			ai_noise = 15.0
		AIDifficulty.NORMAL:
			ai_depth = 2
			ai_noise = 5.0
		AIDifficulty.HARD:
			ai_depth = 3
			ai_noise = 0.0

# ---------- mana ----------
func ai_unspent_mana_cards():
	var cards = []
	for mana_card in $"../OpponentManaHand".opponent_mana_hand:
		if not mana_card.mana_selected:
			cards.append(mana_card)
	return cards


func ai_available_mana():
	return ai_unspent_mana_cards().size()


func ai_available_mana_value():
	var total = 0
	for mana_card in ai_unspent_mana_cards():
		total += mana_card.mana
	return total

func ai_card_value(card):
	var v = card.attack + card.health * 0.5
	if card.get_meta("ai_role", "") != "":
		v += ai_role_bonus
	return max(5.0, v)

# can the AI land `needed` attacks on the target this turn, with enough total damage?
func ai_can_finish(card, damage, target, needed):
	var hits = 1
	var total = damage
	for other in opponent_cards_on_battlefield:
		if other == card or other.get_meta("used_this_turn", false) or not can_card_attack(other):
			continue
		var best = ai_best_damage(other, other.attached_mana)
		if best > 0:
			hits += 1
			total += best
	return hits >= needed and total >= target.health

# the old behaviour: every card hits a random legal target
func ai_attack_phase_basic():
	for card in opponent_cards_on_battlefield.duplicate():
		if not can_card_attack(card) or not choose_default_attack(card):
			continue
		if player_cards_on_battlefield.size() == 0:
			await direct_attack(card, "Opponent")
		else:
			var card_to_attack = get_attackable(player_cards_on_battlefield, card).pick_random()
			await attack(card, card_to_attack, "Opponent")

func ai_turn_loop():
	var guard = 25
	while guard > 0 and not game_over:
		guard -= 1
		var action = ai_best_action()
		if action.is_empty():
			return
		await ai_run_action(action)

func ai_best_action():
	var options = ai_economy_options()
	for card in opponent_cards_on_battlefield:
		if card.get_meta("used_this_turn", false) or not can_card_attack(card):
			continue
		for i in range(card.attacks.size()):
			options.append_array(ai_move_options(card, i))
	var best = {}
	var best_score = ai_min_action_score
	for option in options:
		var score = option["score"] + randf_range(-ai_noise, ai_noise)
		if score > best_score:
			best_score = score
			best = option
	return best

func ai_run_action(action):
	var card = action["card"]
	match action["kind"]:
		"play":
			if card.card_type == "Monster":
				ai_monsters_played += 1
			else:
				ai_spend_mana_cards(card.mana)
			await ai_play_card(card, action["slot"])
		"sport":
			await ai_use_sport(card, action["target"])
		"attach":
			for n in range(action["count"]):
				attach_ai_mana_card(card)
				await wait(0.3)
		"plant":
			await plant_ai_mana_card(card, ai_best_plant_slot())
		"direct":
			card.selected_attack = action["move"]
			await direct_attack(card, "Opponent")
		"self":
			card.selected_attack = action["move"]
			mark_card_used(card)
			await trigger_hook(card, card.attacks[action["move"]]["effect"], [null])
		_:
			card.selected_attack = action["move"]
			await attack(card, action["target"], "Opponent")
	await wait(0.5)

# everything that isn't attacking: playing cards, sports, and mana for monsters
func ai_economy_options():
	var options = []
	var hand = $"../OpponentHand".opponent_mana_hand   # the AI's hand of cards

	if not empty_monster_card_slots.is_empty():
		for card in hand:
			if GameState.is_banned(card.card_type): 
				continue
			if ai_monsters_played >= GameState.rules["monsters_per_turn"]:
				continue
			if card.card_type == "Monster":
				if ai_monsters_played >= GameState.rules["monsters_per_turn"]:
					continue
			elif card.card_type == "Magic":
				if ai_available_mana() < card.mana:
					continue
			else:
				continue
			if ai_card_weight(card) <= 0:
				continue
			var slot = choose_ai_slot(card)
			options.append({"kind": "play", "card": card, "slot": slot, "score": ai_play_score(card, slot)})

	for sport in hand:
		if sport.card_type != "Sport" or ai_available_mana_value() < sport.mana:
			continue
		for target in player_cards_on_battlefield:
			var s = ai_sport_score(sport, target)
			if s > 0:
				options.append({"kind": "sport", "card": sport, "target": target, "score": s})

	var owned = $"../OpponentManaHand".opponent_mana_hand.size()
	var surplus = min(ai_available_mana(), owned - ai_reserve())
	var no_options = not ai_has_attack_option()
	for card in opponent_cards_on_battlefield:
		var plan = ai_attach_plan(card, surplus, no_options)
		if not plan.is_empty():
			options.append({"kind": "attach", "card": card, "count": plan["needed"], "score": plan["score"]})
	# Buff Tree: plant spare energy as 1/1 blockers when outnumbered or in danger
	if ai_depth >= 2 and ai_has_buff_tree() and not empty_monster_card_slots.is_empty():
		var energy = $"../OpponentManaHand".opponent_mana_hand
		var gap = player_attackers() - opponent_cards_on_battlefield.size()
		if energy.size() > ai_reserve() and (gap > 0 or ai_hearts_in_danger()):
			var s = 8.0 + max(gap, 0) * 10.0 + (30.0 if ai_hearts_in_danger() else 0.0)
			options.append({"kind": "plant", "card": energy.back(), "score": s})
	return options
	

func ai_play_score(card, slot):
	var s = ai_card_weight(card) * 0.6 + ai_play_bonus
	if opponent_cards_on_battlefield.is_empty():
		s += 20.0
	if ai_depth >= 2:
		s += ai_slot_score(card, slot) * 0.5
		if ai_hearts_in_danger():
			s += 40.0 if opponent_cards_on_battlefield.size() <= 1 else 15.0
		if card.get_meta("ai_role", "") == "defender" and player_attackers() > opponent_cards_on_battlefield.size():
			s += 15.0        # more attackers against us than blockers
	return s

func ai_sport_score(sport, target):
	if target.statuses.has("only_hurt_by_attacks") or target.statuses.has("ignores_damage"):
		return 0.0
	var hindrance = target.get_meta("ai_role", "") == "protected"
	if not hindrance and target.health < ai_sport_high_health:
		return 0.0
	var damage = sport.attack * (2 if target.statuses.has("burned") else 1)
	var kills = damage >= target.health
	if not kills and damage < target.health * ai_sport_min_damage_fraction:
		return 0.0
	var value = ai_card_value(target)
	var score = value * min(1.0, float(damage) / max(1, target.health))
	if kills:
		score += value * 0.5 + 10.0
	if hindrance:
		score += 20.0
	# top difficulty keeps the sports card if a plain attack can finish the same kill
	if ai_depth >= 3 and kills and ai_attack_kills(target):
		return 0.0
	return score

func ai_attack_kills(target):
	for card in opponent_cards_on_battlefield:
		if card.get_meta("used_this_turn", false) or not can_card_attack(card):
			continue
		for move in card.attacks:
			if move.get("passive", false) or not can_use_attack(card, move):
				continue
			var d = move_damage(card, move) * (2 if target.statuses.has("burned") else 1)
			if d >= target.health:
				return true
	return false

# attaching mana, using the same budget rules as before (surplus over the reserve, or all of it
# if nothing can attack). Returns {} or {"needed": cards to attach, "score": value}
func ai_attach_plan(card, surplus, no_options):
	if ai_available_mana() == 0 or card.card_type != "Monster" or card.statuses.has("never_attacks"):
		return {}
	var budget = max(surplus, 0)
	if no_options:
		budget = ai_available_mana()
	var cheap = cheapest_damaging_cost(card)
	if cheap >= 0 and cheap <= ai_cheap_attack_cost and card.attached_mana < cheap:
		budget = max(budget, cheap - card.attached_mana)
	budget = min(budget, ai_available_mana())
	var cost = strongest_unlockable_cost(card, budget)
	if cost < 0:
		return {}
	var needed = cost - card.attached_mana
	if needed <= 0:
		return {}
	var now = ai_best_damage(card, card.attached_mana)
	var after = ai_best_damage(card, cost)
	var score = 8.0 + min(after - now, 60.0) * 0.5
	if now <= 0:
		score += 10.0     # it can't hurt anything yet
	if can_card_attack(card) and not card.get_meta("used_this_turn", false):
		score += ai_attach_now_bonus
	if ai_depth >= 2 and can_be_attacked(card) and ai_max_incoming_hit() >= card.health:
		score *= 0.5      # attached mana is lost if the card dies, and this one is likely to
	return {"needed": needed, "score": score}

# strongest damage a card could do with this much mana attached
func ai_best_damage(card, mana):
	var best = 0
	for move in card.attacks:
		if move.get("passive", false) or move["cost"] > mana:
			continue
		var d = move_damage(card, move)
		if move["damage"] is String and move["damage"] == "per_mana":
			d = card.attack * mana
		best = max(best, d)
	return best

func ai_move_options(card, i):
	var options = []
	var move = card.attacks[i]
	if move.get("passive", false) or not can_use_attack(card, move):
		return options
	var damage = move_damage(card, move)
	var mode = move.get("target", "enemy")
	var script = card.ability_script
	var scorer = move.has("effect") and script != null and script.has_method("ai_ability_score")

	if mode == "none":
		if scorer and ai_depth >= 2:
			var s = script.ai_ability_score(i, null)
			if s > 0:
				options.append({"card": card, "move": i, "target": null, "kind": "self", "score": s})
		return options

	if mode != "any" and player_cards_on_battlefield.is_empty():
		if damage > 0:
			var s = ai_heart_value
			if ai_depth >= 2 and player_health <= 1:
				s += 1000.0     # lethal
			options.append({"card": card, "move": i, "target": null, "kind": "direct", "score": s})
		return options

	var pool = get_attackable(player_cards_on_battlefield, card)
	if mode == "any":
		pool = player_cards_on_battlefield + opponent_cards_on_battlefield
	for target in pool:
		if target == card:
			continue
		var s = ai_score_move(card, i, damage, target, scorer)
		if s > 0:
			options.append({"card": card, "move": i, "target": target, "kind": "attack", "score": s})
	return options

func ai_score_move(card, i, damage, target, scorer):
	var ally = target in opponent_cards_on_battlefield
	var score = 0.0
	if damage > 0 and not ally:
		if target.statuses.has("immune_to_attacks") or target.statuses.has("ignores_damage"):
			damage = 0
		var target_script = target.ability_script
		if ai_depth >= 2 and target_script and target_script.has_method("ai_hits_needed"):
			var needed = target_script.ai_hits_needed()
			if needed > 1 and not ai_can_finish(card, damage, target, needed):
				return 0.0      # it can't be finished this turn: the attack would be wasted
		var dmg = damage * (2 if target.statuses.has("burned") else 1)
		if dmg > 0:
			var value = ai_card_value(target)
			score = value * min(1.0, float(dmg) / max(1, target.health))
			if dmg >= target.health:
				score += value * 0.5 + 10.0
			# magic hits back. Our own magic heals each turn, so for it only a lethal hit-back matters
			if ai_depth >= 2 and target.card_type == "Magic" and target.attack > 0:
				var back = target.attack
				if back >= card.health:
					score -= ai_card_value(card)
					if opponent_cards_on_battlefield.size() <= 1:
						score -= ai_heart_value * (2.0 if ai_hearts_in_danger() else 1.0)
				elif card.card_type != "Magic":
					score -= ai_card_value(card) * float(back) / max(1, card.health)
	if scorer and ((damage <= 0 and ai_depth >= 2) or ai_depth >= 3):
		score += card.ability_script.ai_ability_score(i, target)
	return score


# magic costs a number of cards: use the lowest-value ones
func ai_spend_mana_cards(count):
	var cards = ai_unspent_mana_cards()
	cards.sort_custom(func(a, b): return a.mana < b.mana)
	for i in range(min(count, cards.size())):
		cards[i].mana_selected = true
		cards[i].modulate.a = 0.4


# sports cost value: use the fewest cards, highest value first
func ai_spend_mana_value(cost):
	var cards = ai_unspent_mana_cards()
	cards.sort_custom(func(a, b): return a.mana > b.mana)
	var spent = 0
	for mana_card in cards:
		if spent >= cost:
			break
		mana_card.mana_selected = true
		mana_card.modulate.a = 0.4
		spent += mana_card.mana


func ai_owned_mana_value():
	var total = 0
	for c in $"../OpponentManaHand".opponent_mana_hand:
		total += c.mana
	return total


func ai_cards_needed_for_value(cost):
	var values = []
	for c in $"../OpponentManaHand".opponent_mana_hand:
		values.append(c.mana)
	values.sort()
	values.reverse()
	var total = 0
	var count = 0
	for v in values:
		if total >= cost:
			break
		total += v
		count += 1
	return count


func ai_reserve():
	var reserve = ai_mana_reserve
	var cheapest_sport = -1
	for card in $"../OpponentHand".opponent_mana_hand:   # this is the AI's hand of cards
		if card.card_type == "Magic" and ai_card_weight(card) > 0:
			reserve = max(reserve, card.mana)
		elif card.card_type == "Sport":
			if cheapest_sport < 0 or card.mana < cheapest_sport:
				cheapest_sport = card.mana
	if cheapest_sport > 0 and ai_owned_mana_value() >= cheapest_sport:
		reserve = max(reserve, ai_cards_needed_for_value(cheapest_sport))
	return reserve


# ---------- weighting ----------
func ai_card_weight(card):
	var base = card.attack + card.health * 0.5
	if card.get_meta("ai_role", "") != "":
		base += ai_role_bonus
	if card.card_type == "Monster":
		return base   # monsters are free
	var owned = max(1, $"../OpponentManaHand".opponent_mana_hand.size())
	return base + ai_magic_bonus - card.mana * ai_cost_penalty / owned


# ---------- slots ----------


func card_in_slot(slot):
	for c in player_cards_on_battlefield + opponent_cards_on_battlefield:
		if c.card_slot_card_is_in == slot:
			return c
	return null

# health of the card standing in front of a back-row slot (0 if none)
func front_card_health(slot):
	var n = slot_number(slot)
	var prefix = String(slot.name).trim_suffix(str(n))
	var front_slot = slot.get_parent().get_node_or_null(prefix + str(n - 1))
	var front_card = card_in_slot(front_slot) if front_slot else null
	return front_card.health if front_card else 0


# "defender" cards go in front. "protected" cards go behind the sturdiest card in front.
# Untagged monsters go in front and untagged magic goes behind if it can.
func choose_ai_slot_basic(card):
	var role = card.get_meta("ai_role", "")
	var front = []
	var behind = []
	for slot in empty_monster_card_slots:
		var n = slot_number(slot)
		if n <= 0:
			continue
		if n % 2 == 1:
			front.append(slot)
		else:
			var prefix = String(slot.name).trim_suffix(str(n))
			var front_slot = slot.get_parent().get_node_or_null(prefix + str(n - 1))
			if front_slot and card_in_slot(front_slot):
				behind.append(slot)

	var wants_back = role == "protected" or (role == "" and card.card_type == "Magic")
	if wants_back and not behind.is_empty():
		behind.sort_custom(func(a, b): return front_card_health(a) > front_card_health(b))
		return behind[0]
	if not front.is_empty():
		return front.pick_random()
	if not behind.is_empty():
		return behind.pick_random()
	return empty_monster_card_slots.pick_random()


# ---------- playing monsters and magic ----------
func ai_play_card(card, slot):
	empty_monster_card_slots.erase(slot)
	card.rotation_degrees = 180
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", slot.position, CARD_MOVE_SPEED)
	var tween2 = get_tree().create_tween()
	tween2.tween_property(card, "scale", Vector2(CARD_SMALL_CARD_SCALE, CARD_SMALL_CARD_SCALE), CARD_MOVE_SPEED)
	card.get_node("AnimationPlayer").play("card_flip")
	$"../OpponentHand".remove_card_from_hand(card)
	card.card_slot_card_is_in = slot
	slot.card_in_slot = true
	trigger_hook(card, "on_played")
	card.just_played = true
	opponent_cards_on_battlefield.append(card)
	await wait(1.0)


func ai_play_phase():
	var hand = $"../OpponentHand".opponent_mana_hand   # this is the AI's hand of cards
	var candidates = []
	for card in hand:
		if card.card_type == "Monster" or card.card_type == "Magic" and not GameState.is_banned(card.card_type):
			candidates.append(card)
	candidates.sort_custom(func(a, b): return ai_card_weight(a) > ai_card_weight(b))

	var played_monster = 0
	for card in candidates:
		if empty_monster_card_slots.is_empty():
			break
		if ai_card_weight(card) <= 0:
			continue
		if card.card_type == "Monster":
			if played_monster:
				continue
			played_monster += 1
		else:
			if ai_available_mana() < card.mana:
				continue
			ai_spend_mana_cards(card.mana)
		await ai_play_card(card, choose_ai_slot(card))


# ---------- sports cards ----------
# worth using on a high-health card, or on a hindrance (cards tagged "protected": Pencil, Skeleton Cowboy)
func ai_best_sport_target(sport):
	var best = null
	var best_score = 0.0
	for target in player_cards_on_battlefield:
		if target.statuses.has("only_hurt_by_attacks"):
			continue   # sports cards can't hurt it
		var hindrance = target.get_meta("ai_role", "") == "protected"
		if not hindrance and target.health < ai_sport_high_health:
			continue
		var damage = sport.attack * (2 if target.statuses.has("burned") else 1)
		var kills = damage >= target.health
		if not kills and damage < target.health * ai_sport_min_damage_fraction:
			continue
		var score = target.attack + target.health * 0.5
		if kills:
			score += 100
		if hindrance:
			score += 50
		if score > best_score:
			best_score = score
			best = target
	return best


func ai_use_sport(sport, target):
	$"../OpponentHand".remove_card_from_hand(sport)
	ai_spend_mana_value(sport.mana)
	sport.get_node("Area2D/CollisionShape2D").set_deferred("disabled", true)
	sport.rotation_degrees = 180
	sport.get_node("AnimationPlayer").play("card_flip")
	sport.z_index = CARD_ATTACKING_Z_INDEX
	target = await offer_block(sport, target, "Opponent")

	var tween = get_tree().create_tween()
	tween.tween_property(sport, "position", target.position, CARD_MOVE_SPEED)
	opponent_graveyard.append(sport)
	tween.parallel().tween_property(sport, "scale", Vector2(CARD_SMALL_CARD_SCALE, CARD_SMALL_CARD_SCALE), CARD_MOVE_SPEED)
	await tween.finished

	apply_damage(target, sport.attack, "sport")
	await wait(0.5)

	sport.defeated = true
	sport.z_index = 1
	var discard_tween = get_tree().create_tween()
	discard_tween.tween_property(sport, "position", $"../OpponentDiscard".position, 0.2)

	if target.health == 0:
		destroy_card(target, "Player")
		await wait(1.0)


func ai_sports_phase():
	if GameState.is_banned("Sport"): 
		return
	var sports = []
	for card in $"../OpponentHand".opponent_mana_hand:   # this is the AI's hand of cards
		if card.card_type == "Sport":
			sports.append(card)
	sports.sort_custom(func(a, b): return a.attack > b.attack)
	for sport in sports:
		if player_cards_on_battlefield.is_empty():
			return
		if ai_available_mana_value() < sport.mana:
			continue
		var target = ai_best_sport_target(sport)
		if target:
			await ai_use_sport(sport, target)


# ---------- attaching mana to monsters ----------
func strongest_unlockable_cost(card, extra_energy) -> int:
	for i in range(card.attacks.size() - 1, -1, -1):
		var move = card.attacks[i]
		var damaging = move["damage"] is String or move["damage"] > 0
		if damaging and card.attached_mana + extra_energy >= move["cost"]:
			return move["cost"]
	return -1


func attach_ai_mana_card(monster):
	var cards = ai_unspent_mana_cards()
	if cards.is_empty():
		return
	cards.sort_custom(func(a, b): return a.mana < b.mana)
	var mana_card = cards[0]
	$"../OpponentManaHand".remove_card_from_hand(mana_card)
	monster.attached_mana += 1
	var tween = get_tree().create_tween()
	tween.tween_property(mana_card, "position", monster.position, 0.15)
	tween.tween_callback(mana_card.queue_free)


# can anything it owns attack right now?
func ai_has_attack_option():
	for card in opponent_cards_on_battlefield:
		if can_card_attack(card) and strongest_unlockable_cost(card, 0) >= 0:
			return true
	return false


# attach only the surplus. If nothing can attack, unlocking an attack is worth spending the reserve too
@export var ai_cheap_attack_cost = 1   # attacks at or under this cost are always worth unlocking


func cheapest_damaging_cost(card):
	var best = -1
	for move in card.attacks:
		var damaging = move["damage"] is String or move["damage"] > 0
		if damaging and (best < 0 or move["cost"] < best):
			best = move["cost"]
	return best


func ai_attach_mana():
	var owned = $"../OpponentManaHand".opponent_mana_hand.size()
	var surplus = min(ai_available_mana(), owned - ai_reserve())
	var no_options = not ai_has_attack_option()

	for card in opponent_cards_on_battlefield:
		if ai_available_mana() == 0:
			return
		if card.card_type != "Monster" or card.statuses.has("never_attacks"):
			continue

		var budget = max(surplus, 0)
		if no_options:
			budget = ai_available_mana()
		var cheap = cheapest_damaging_cost(card)
		if cheap >= 0 and cheap <= ai_cheap_attack_cost and card.attached_mana < cheap:
			budget = max(budget, cheap - card.attached_mana)
		budget = min(budget, ai_available_mana())

		var cost = strongest_unlockable_cost(card, budget)
		if cost < 0:
			continue
		var needed = cost - card.attached_mana
		if needed <= 0:
			continue
		for i in range(needed):
			attach_ai_mana_card(card)
			surplus -= 1
			await wait(0.3)
		no_options = false
	

func plant_mana_card(m, slot):
	var cm = $"../CardManager"
	var value = m.mana
	$"../PlayerManaHand".remove_card_from_hand(m)
	cm.forget_selected_mana(m)
	CardFactory.apply_data(m, "ManaMonster")
	m.modulate = Color(1, 1, 1, 1)
	m.set_meta("planted_mana", value)
	for part in ["AttackText", "HealthText", "Mana"]:
		m.get_node("Transform/" + part + "Magic").visible = true
	update_attack_label(m)
	update_health_label(m)
	update_mana_label(m)
	m.scale = Vector2(cm.IN_SLOT_CARD_SCALE, cm.IN_SLOT_CARD_SCALE)
	m.position = slot.position
	slot.card_in_slot = true
	m.card_slot_card_is_in = slot
	slot.get_node("Area2D/CollisionShape2D").disabled = true
	player_cards_on_battlefield.append(m)
	m.just_played = true

# a planted energy card leaving the field (used up as equipment)
func remove_planted_from_field(c):
	if c in opponent_cards_on_battlefield:
		var oslot = c.card_slot_card_is_in
		opponent_cards_on_battlefield.erase(c)
		if oslot and oslot not in empty_monster_card_slots:
			empty_monster_card_slots.append(oslot)
		if oslot:
			oslot.card_in_slot = false
		c.card_slot_card_is_in = null
		check_game_over()
		return
	player_cards_on_battlefield.erase(c)
	player_cards_that_attacked_this_turn.erase(c)
	var slot = c.card_slot_card_is_in
	slot.card_in_slot = false
	slot.get_node("Area2D/CollisionShape2D").disabled = false
	c.card_slot_card_is_in = null
	c.get_node("Area2D/CollisionShape2D").set_deferred("disabled", true)
	check_game_over()

func choose_ai_slot(card):
	if ai_depth >= 2:
		var best = null
		var best_score = -INF
		for slot in empty_monster_card_slots:
			var s = ai_slot_score(card, slot) + randf_range(-ai_noise, ai_noise) * 0.2
			if s > best_score:
				best_score = s
				best = slot
		if best:
			return best
	return choose_ai_slot_basic(card)

func ai_slot_score(card, slot):
	var n = slot_number(slot)
	if n <= 0:
		return 0.0
	var is_front = n % 2 == 1
	var shielded = false
	if not is_front:
		var prefix = String(slot.name).trim_suffix(str(n))
		var front_slot = slot.get_parent().get_node_or_null(prefix + str(n - 1))
		shielded = front_slot != null and card_in_slot(front_slot) != null

	var role = card.get_meta("ai_role", "")
	var wants_back = role == "protected" or (role == "" and card.card_type == "Magic")
	var score = 0.0
	if wants_back:
		if shielded:
			score += 15.0 + front_card_health(slot) * 0.1   # behind the sturdiest front card
		elif is_front:
			score -= 15.0
		else:
			score -= 5.0
	elif role == "defender":
		score += 15.0 if is_front else -10.0
	else:
		if is_front:
			score += 5.0
		elif not shielded:
			score -= 5.0

	# a blocker likes standing next to cards worth protecting
	if card.ability_script and card.ability_script.has_method("can_block"):
		for other in adjacent_cards_of_slot(slot):
			score += ai_card_value(other) * 0.15

	# a reachable card that the player's board can kill next turn is a poor placement
	if not shielded and ai_max_incoming_hit() >= card.health:
		score -= ai_card_value(card) * 0.4
	return score

# the biggest single hit the player's board could deal next turn
func ai_max_incoming_hit():
	var best = 0
	for c in player_cards_on_battlefield:
		if c.statuses.has("never_attacks") or c.statuses.has("cant_attack") or c.statuses.has("tied_to"):
			continue
		best = max(best, ai_best_damage(c, c.attached_mana + 1))   # +1: they may attach more
	return best

# same neighbours as adjacent_cards, but for an empty slot
func adjacent_cards_of_slot(slot, ignore = null):
	var result = []
	var number = slot_number(slot)
	if number <= 0:
		return result
	var prefix = String(slot.name).trim_suffix(str(number))
	var partner = number + 1 if number % 2 != 0 else number - 1
	for n in [partner, number - 2, number + 2]:
		var neighbour = slot.get_parent().get_node_or_null(prefix + str(n))
		if neighbour:
			var other = card_in_slot(neighbour)
			if other and other != ignore:
				result.append(other)
	return result
	
# how many of the player's cards could attack next turn
func player_attackers():
	var n = 0
	for c in player_cards_on_battlefield:
		if c.statuses.has("never_attacks") or c.statuses.has("cant_attack") or c.statuses.has("tied_to"):
			continue
		if ai_best_damage(c, c.attached_mana + 1) > 0:
			n += 1
	return n

# true if an empty field would let the player finish the AI's hearts
func ai_hearts_in_danger():
	return opponent_health <= player_attackers() * GameState.rules["direct_hit_damage"]

func ai_has_buff_tree():
	for c in opponent_cards_on_battlefield:
		if c.ability_script and c.ability_script.has_method("allows_planting"):
			return true
	return false

func ai_best_plant_slot():
	var best = null
	var best_score = -INF
	for slot in empty_monster_card_slots:
		var s = (10.0 if slot_number(slot) % 2 == 1 else 0.0) + randf()   # front row blocks
		if s > best_score:
			best_score = s
			best = slot
	return best

func plant_ai_mana_card(m, slot):
	var value = m.mana
	var cm = $"../CardManager"
	$"../OpponentManaHand".remove_card_from_hand(m)
	CardFactory.apply_data(m, "ManaMonster")
	m.set_meta("planted_mana", value)
	for part in ["AttackText", "HealthText", "Mana"]:
		m.get_node("Transform/" + part + "Magic").visible = true
	update_attack_label(m)
	update_health_label(m)
	update_mana_label(m)
	empty_monster_card_slots.erase(slot)
	slot.card_in_slot = true
	m.card_slot_card_is_in = slot
	opponent_cards_on_battlefield.append(m)
	m.just_played = true
	var area = m.get_node_or_null("Area2D")      # make it pickable like any other enemy card
	if area:
		print("planted mana mask was: ", area.collision_mask)
		area.collision_mask = 8
		var shape = area.get_node_or_null("CollisionShape2D")
		if shape:
			shape.set_deferred("disabled", false)
	m.rotation_degrees = 180
	m.scale = Vector2(cm.IN_SLOT_CARD_SCALE, cm.IN_SLOT_CARD_SCALE)
	var tween = get_tree().create_tween()
	tween.tween_property(m, "position", slot.position, 0.4)
	await tween.finished
