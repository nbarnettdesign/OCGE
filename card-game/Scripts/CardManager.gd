extends Node2D

@export var attack_menu_offset = Vector2(-90, 40)   # top-left of the menu, from the card's centre, in card pixels
@export var attack_menu_width = 180.0               # in card pixels
@export var show_button_text = false                 # false = invisible click areas over the printed text
var mouse_over_attack_menu = false
var attack_menu_card
@onready var attack_menu = $"../AttackMenu/Buttons"
@onready var attack_buttons = [$"../AttackMenu/Buttons/Attack1", $"../AttackMenu/Buttons/Attack2"]

const GraveyardScene = preload("res://Scenes/graveyard_view.tscn")
@export var discard_click_size = Vector2(160, 220)      # the area around a discard pile that opens it

signal card_picked(card)
var pick_active = false
var pick_exclude = null
var hint_label = null

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_CARD_SLOT = 2
const COLLISION_MASK_OPPONENT_CARD = 8
const DEFAULT_CARD_MOVE_SPEED = .1
const DEFAULT_CARD_SCALE = 1
const IN_SLOT_CARD_SCALE = .8
const DEFAULT_MANA_SCALE = .6
const BIGGER_MANA_SCALE = 1
const BIGGER_CARD_SCALE = 2
const BIG_CARD_SCALE = 1.2
const HOVER_ZOOM_DELAY = 1.0

signal block_decided(accepted)
var block_prompt_card = null
var block_pulse = null
const MANA_DRAG_THRESHOLD = 50.0     # pixels the mouse must move before an energy drag starts
var pending_mana_card = null
var pending_mana_origin = Vector2.ZERO
var hover_token = 0
var screen_size
var card_being_dragged
var is_hovering_over_card
var player_hand_reference
var monsters_played_this_turn = 0
var played_magic_card_this_turn = false
var selected_monster
var hoveredcard
var menu_leave_timer = 0.0
var hover_target = null

var player_active_mana = 0
var player_active_mana_cards = 0
var opponent_active_mana = 0
var opponent_active_mana_cards = 0

var inspected_enemy = null
var inspected_enemy_scale = Vector2.ONE
var inspected_enemy_z = 0

var drag_grab_offset = Vector2.ZERO
var pending_mana_grab = Vector2.ZERO

func _ready() -> void:
	screen_size = get_viewport_rect().size
	player_hand_reference = $"../PlayerHand"
	$"../OpponentActiveManaText".text = str(opponent_active_mana)
	$"../PlayerActiveManaText".text = str(player_active_mana)
	$"../OpponentActiveManaCardsText".text = str(opponent_active_mana_cards)
	$"../PlayerActiveManaCardsText".text = str(player_active_mana_cards)
	$"../InputManager".connect("left_mouse_button_released", on_left_click_released)
	$"../InputManager".connect("left_mouse_button_clicked", on_left_click_pressed)
	$"../InputManager".connect("right_mouse_button_released", on_right_click_released)
	for i in range(attack_buttons.size()):
		attack_buttons[i].pressed.connect(on_attack_button_pressed.bind(i))
		attack_buttons[i].mouse_entered.connect(func(): mouse_over_attack_menu = true)
		attack_buttons[i].mouse_exited.connect(func(): mouse_over_attack_menu = false)
	setup_hint_label()
	_style_attack_buttons()


func _process(delta: float) -> void:
	if inspected_enemy:
		if not is_instance_valid(inspected_enemy) or raycast_check_for_opponent_card() != inspected_enemy:
			end_enemy_inspect()
	if pending_mana_card:
		if get_global_mouse_position().distance_to(pending_mana_origin) > MANA_DRAG_THRESHOLD:
			var card = pending_mana_card
			pending_mana_card = null
			start_drag(card)
			drag_grab_offset = card.position - get_global_mouse_position()    # no jump when it starts
			create_tween().tween_property(self, "drag_grab_offset", pending_mana_grab, 0.15)
	if card_being_dragged:
		var mouse_pos = get_global_mouse_position() + drag_grab_offset
		card_being_dragged.position = Vector2(clamp(mouse_pos.x, 0, screen_size.x), clamp(mouse_pos.y, 0, screen_size.y))
	if attack_menu_card and not block_prompt_card:
		if raycast_check_for_card() == attack_menu_card or mouse_over_attack_menu:
			menu_leave_timer = 0.0
		else:
			menu_leave_timer += delta
			if menu_leave_timer > 0.15:
				hide_attack_menu()
	if attack_menu.visible and is_instance_valid(attack_menu_card):
		place_attack_menu(attack_menu_card)

func pick_card(exclude):
	pick_exclude = exclude
	pick_active = true
	show_hint("Choose what it attacks")
	var picked = await card_picked
	hide_hint()
	return picked

func submit_pick(card):
	if card == pick_exclude or not card.card_slot_card_is_in:
		return
	pick_active = false
	pick_exclude = null
	card_picked.emit(card)

func forget_selected_mana(card):
	if card.mana_selected:
		player_active_mana -= card.mana
		player_active_mana_cards -= 1
		card.mana_selected = false
		$"../PlayerActiveManaText".text = str(player_active_mana)
		$"../PlayerActiveManaCardsText".text = str(player_active_mana_cards)

func card_clicked(card):
	# an "any"-target ability is waiting for a target: clicking one of your own cards uses it on that card
	if pick_active:
		submit_pick(card)
		return
	if block_prompt_card:
		block_decided.emit(false)
		return
	if selected_monster and selected_monster != card and card.card_slot_card_is_in \
			and card in $"../BattleManager".player_cards_on_battlefield \
			and not $"../BattleManager".player_is_attacking:
		var chosen = selected_monster.attacks[selected_monster.selected_attack]
		var mode = chosen.get("target", "enemy")
		if mode == "any" or (mode == "enemy" and $"../BattleManager".has_keyword(card, "neutral")):
			$"../BattleManager".attack(selected_monster, card, "Player")
			return
	if card != attack_menu_card and card != selected_monster:
		deselect_all()

	if card.card_slot_card_is_in:
		if $"../BattleManager".is_opponents_turn == true:
			return
		if card.has_meta("planted_mana") and card.mana_selected:
			toggle_planted_mana(card)     # click a selected planted card again to unselect it
			return
		if card.card_type == "Monster" and player_active_mana_cards > 0:
			attach_selected_mana(card)
			return
		if $"../BattleManager".player_is_attacking:
			return
		if card in $"../BattleManager".player_cards_that_attacked_this_turn:
			return
		if not $"../BattleManager".can_card_attack(card):
			return

		# clicking the monster that's already selected deselects it
		if selected_monster == card:
			select_card_for_battle(card)
			try_show_hover_menu(card)
			return

		if not $"../BattleManager".has_usable_attack(card):
			return

		if card.card_type == "Magic":
			select_magic_card(card)
		else:
			show_attack_menu(card)    # monsters always use the menu
	else:
		if card.card_type == "Mana":
			if plant_mode_active() and not $"../BattleManager".is_opponents_turn:
				begin_pending_mana_drag(card)     # the drag starts once the mouse moves
			else:
				toggle_mana_selection(card)
			return
		if not $"../BattleManager".is_opponents_turn:
			start_drag(card)                      # no picking cards up on their turn

func select_card_for_battle(card):
	if selected_monster:
		if selected_monster == card:
			card.position.y += 20.0
			selected_monster = null
		else:
			selected_monster.position.y += 20.0
			selected_monster = card
			card.position.y -= 20
	else:
		selected_monster = card
		card.position.y -= 20.0

func flash_hint(text):
	show_hint(text)
	await get_tree().create_timer(1.5).timeout
	if hint_label.text == text:
		hide_hint()

func start_drag(card):
	drag_grab_offset = Vector2.ZERO
	card_being_dragged = card
	card.set_meta("drag_origin", card.position)
	card.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)


func finish_drag():
	if GameState.is_banned(card_being_dragged.card_type):
			flash_hint("%s cards are banned in this battle" % card_being_dragged.card_type)
			var banned = card_being_dragged
			card_being_dragged = null
			banned.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)
			player_hand_reference.reorder_card_in_hand(banned)
			return
	if not $"../BattleManager".is_opponents_turn:
		if card_being_dragged.card_type == "Mana":
			finish_mana_drag()
			return
		if card_being_dragged.card_type == "Sport":
			finish_sport_drag()
			return
		card_being_dragged.scale = Vector2(IN_SLOT_CARD_SCALE, IN_SLOT_CARD_SCALE)
		var card_slot_found = raycast_check_for_card_slot()
		if card_slot_found and not card_slot_found.card_in_slot && card_being_dragged.card_type != "Mana":
			if card_being_dragged.card_type == "Monster" or card_being_dragged.card_type == "Magic":
				if card_being_dragged.card_type == "Monster" && monsters_played_this_turn < GameState.rules["monsters_per_turn"]:
					$"../BattleManager".trigger_hook(card_being_dragged, "on_played")
					Audio.play("place")
					player_hand_reference.remove_card_from_hand(card_being_dragged)
					#Card being dragged, drop into empty card slot
					card_being_dragged.position = card_slot_found.position
					card_slot_found.card_in_slot = true
					card_being_dragged.card_slot_card_is_in = card_slot_found
					card_slot_found.get_node("Area2D/CollisionShape2D").disabled = true
					$"../BattleManager".player_cards_on_battlefield.append(card_being_dragged)
					monsters_played_this_turn += 1
					if card_being_dragged:
						card_being_dragged.just_played = true
					card_being_dragged = null
				elif card_being_dragged.card_type == "Magic" && player_active_mana_cards >= card_being_dragged.mana:
					$"../BattleManager".trigger_hook(card_being_dragged, "on_played")
					Audio.play("place")
					player_hand_reference.remove_card_from_hand(card_being_dragged)
					#Card being dragged, drop into empty card slot
					card_being_dragged.position = card_slot_found.position
					card_slot_found.card_in_slot = true
					card_being_dragged.card_slot_card_is_in = card_slot_found
					card_slot_found.get_node("Area2D/CollisionShape2D").disabled = true
					$"../BattleManager".player_cards_on_battlefield.append(card_being_dragged)
					if card_being_dragged.mana != 0:
							spend_selected_mana_cards(card_being_dragged.mana)
					if card_being_dragged:
						card_being_dragged.just_played = true
					card_being_dragged = null
				else:
					if card_being_dragged.card_type != "Mana":
						player_hand_reference.reorder_card_in_hand(card_being_dragged)
			else:
				if card_being_dragged.card_type != "Mana":
					player_hand_reference.reorder_card_in_hand(card_being_dragged)
		else:
			if card_being_dragged.card_type != "Mana":
				player_hand_reference.reorder_card_in_hand(card_being_dragged)
	else:
			if card_being_dragged.card_type != "Mana":
				player_hand_reference.reorder_card_in_hand(card_being_dragged)
	card_being_dragged = null

func finish_sport_drag():
	var sport = card_being_dragged
	card_being_dragged = null
	sport.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)

	var battle = $"../BattleManager"
	var target = raycast_check_for_opponent_card()
	var cost = sport.mana

	# target must be an opponent monster or magic card sitting in a slot, and you need the mana
	if not target or not target.card_slot_card_is_in \
			or target.card_type not in ["Monster", "Magic"] \
			or player_active_mana < cost:
		player_hand_reference.reorder_card_in_hand(sport)
		return

	player_hand_reference.remove_card_from_hand(sport)
	sport.get_node("Area2D/CollisionShape2D").set_deferred("disabled", true)
	if cost != 0:
		spend_selected_active_mana(cost)
		target = await battle.offer_block(sport, target, "Player")

	# fly to the target
	var tween = get_tree().create_tween()
	tween.tween_property(sport, "position", target.position, 0.15)
	$"../BattleManager".player_graveyard.append(sport)
	await tween.finished

	# damage
	battle.apply_damage(target, sport.attack, "sport")

	await get_tree().create_timer(0.5).timeout

	# sports card goes to the discard pile and stays there
	sport.defeated = true   # same flag destroy_card uses, stops hover effects
	sport.z_index = 1
	var discard_tween = get_tree().create_tween()
	discard_tween.tween_property(sport, "position", $"../PlayerDiscard".position, 0.2)
	discard_tween.parallel().tween_property(sport, "scale", Vector2(IN_SLOT_CARD_SCALE, IN_SLOT_CARD_SCALE), 0.2)

	# destroy the target if it died
	if target.health == 0:
		battle.destroy_card(target, "Opponent")

func cancel_drag():
	pending_mana_card = null
	if not card_being_dragged:
		return
	var card = card_being_dragged
	card_being_dragged = null
	highlight_card(card, false)                   # resets its scale and z-index
	if card.card_type == "Mana":
		create_tween().tween_property(card, "position", card.get_meta("drag_origin", card.position), 0.1)
	else:
		player_hand_reference.reorder_card_in_hand(card)

func spend_selected_mana_cards(cost):
	var spent = 0
	for mana_card in $"../PlayerManaHand".player_mana_hand:
		if spent >= cost:
			break
		if mana_card.mana_selected:
			spent += 1
			mana_card.mana_selected = false
			player_active_mana -= mana_card.mana
			mana_card.get_node("Area2D/CollisionShape2D").set_deferred("disabled", true)

			var tween = get_tree().create_tween()
			tween.set_parallel(true)
			tween.tween_property(mana_card, "position", mana_card.hand_position, 0.1)
			tween.tween_property(mana_card, "modulate:a", 0.4, 0.1)
			
	for c in planted_mana_cards():
		if spent >= cost:
			break
		if c.mana_selected:
			spent += 1
			player_active_mana -= c.get_meta("planted_mana", 1)
			grey_out_planted(c)
	# whatever is still selected stays active
	player_active_mana_cards -= spent
	$"../PlayerActiveManaCardsText".text = str(player_active_mana_cards)
	$"../PlayerActiveManaText".text = str(player_active_mana)
	
func spend_selected_active_mana(cost):
	var spent = 0
	for mana_card in $"../PlayerManaHand".player_mana_hand:
		if spent >= cost:
			break
		if mana_card.mana_selected:
			spent += mana_card.mana
			mana_card.mana_selected = false
			player_active_mana_cards -= 1

			mana_card.get_node("Area2D/CollisionShape2D").set_deferred("disabled", true)

			var tween = get_tree().create_tween()
			tween.set_parallel(true)
			tween.tween_property(mana_card, "position", mana_card.hand_position, 0.1)
			tween.tween_property(mana_card, "modulate:a", 0.4, 0.1)
	for c in planted_mana_cards():
		if spent >= cost:
			break
		if c.mana_selected:
			spent += c.get_meta("planted_mana", 1)
			player_active_mana_cards -= 1
			grey_out_planted(c)
	# whatever is still selected stays active
	player_active_mana -= spent
	$"../PlayerActiveManaText".text = str(player_active_mana)
	$"../PlayerActiveManaCardsText".text = str(player_active_mana_cards)

func setup_hint_label():
	hint_label = Label.new()
	hint_label.visible = false
	hint_label.z_index = 50
	hint_label.add_theme_font_size_override("font_size", 28)
	hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hint_label.add_theme_constant_override("outline_size", 6)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.size = Vector2(900, 40)
	hint_label.position = Vector2(screen_size.x / 2 - 450, screen_size.y / 2 - 20)
	add_child(hint_label)

func show_hint(text):
	hint_label.text = text
	hint_label.visible = true

func hide_hint():
	hint_label.visible = false

func attach_selected_mana(monster):
	var to_attach = []
	for mana_card in $"../PlayerManaHand".player_mana_hand:
		if mana_card.mana_selected:
			to_attach.append(mana_card)
	if attack_menu_card == monster:
		show_attack_menu(monster)

	for mana_card in to_attach:
		$"../PlayerManaHand".remove_card_from_hand(mana_card)
		mana_card.mana_selected = false

		monster.attached_mana += 1
		player_active_mana -= mana_card.mana
		player_active_mana_cards -= 1

		# slide into the monster, then delete
		var tween = get_tree().create_tween()
		tween.tween_property(mana_card, "position", monster.position, 0.15)
		tween.tween_callback(mana_card.queue_free)
	for c in planted_mana_cards():
		if c.mana_selected and c != monster:
			c.mana_selected = false
			monster.attached_mana += 1
			player_active_mana -= c.get_meta("planted_mana", 1)
			player_active_mana_cards -= 1
			$"../BattleManager".remove_planted_from_field(c)
			var tween = get_tree().create_tween()
			tween.tween_property(c, "position", monster.position, 0.15)
			tween.tween_callback(c.queue_free)
	$"../PlayerActiveManaText".text = str(player_active_mana)
	$"../PlayerActiveManaCardsText".text = str(player_active_mana_cards)

func try_show_hover_menu(card):
	if card_being_dragged or not card.card_slot_card_is_in:
		return
	if card not in $"../BattleManager".player_cards_on_battlefield:
		return    
	if card.card_type != "Monster" and card.card_type != "Magic":
		return
	var battle = $"../BattleManager"
	if battle.is_opponents_turn or battle.player_is_attacking:
		return
	if card in battle.player_cards_that_attacked_this_turn:
		return
	if not battle.can_card_attack(card) and not card.has_meta("planted_mana"):
		return
	if card.card_type == "Magic" and visible_move_count(card) <= 1:
		return   # a magic card with only a basic attack has no buttons
	show_attack_menu(card)

func refresh_mana_cards():
	# call at the start of the player's turn
	for mana_card in $"../PlayerManaHand".player_mana_hand:
		mana_card.get_node("Area2D/CollisionShape2D").set_deferred("disabled", false)
		mana_card.modulate.a = 1.0
		mana_card.mana_selected = false
	player_active_mana = 0
	player_active_mana_cards = 0
	$"../PlayerActiveManaText".text = str(player_active_mana)
	$"../PlayerActiveManaCardsText".text = str(player_active_mana_cards)
	$"../PlayerManaHand".update_hand_positions(0.1)      # everything back to its resting place
	for c in planted_mana_cards():
		if c.mana_selected and c.card_slot_card_is_in:
			c.mana_selected = false
			c.position = c.card_slot_card_is_in.position

func unselect_selected_monster():
	hide_attack_menu()
	if selected_monster:
		if not selected_monster.mana_selected:      # a card lifted as energy keeps its lift
			selected_monster.position.y += 20
		selected_monster = null

func discard_pile_under_mouse():
	var mouse = get_global_mouse_position()
	var piles = {"Player": $"../PlayerDiscard", "Opponent": $"../OpponentDiscard"}
	for side in piles:
		var rect = Rect2(piles[side].position - discard_click_size / 2.0, discard_click_size)
		if rect.has_point(mouse):
			return side
	return ""

func open_graveyard(side):
	var battle = $"../BattleManager"
	var view = GraveyardScene.instantiate()
	get_tree().current_scene.add_child(view)
	if side == "Player":
		view.show_cards("Your graveyard", battle.player_graveyard)
	else:
		view.show_cards("Opponent's graveyard", battle.opponent_graveyard)

func connect_card_signals(card):
	card.connect("hovered", on_hovered_over_card)
	card.connect("hovered_off", on_hovered_off_card)

func on_left_click_released():
	if pending_mana_card:
		var card = pending_mana_card
		pending_mana_card = null
		toggle_mana_selection(card)      # released before moving: a plain click
		return
	if card_being_dragged:
				finish_drag()

func on_left_click_pressed():
	# clicking a card (yours or the opponent's) is handled by the normal click code
	if block_prompt_card:
		if not mouse_over_attack_menu:
			block_decided.emit(false)
		return
	if raycast_check_for_card() or raycast_check_for_opponent_card():
		return
	deselect_all()


func deselect_all():
	hide_attack_menu()
	unselect_selected_monster()

func on_right_click_released():
	var pile = discard_pile_under_mouse()
	if pile != "":
		open_graveyard(pile)
		return
	var enemy = raycast_check_for_opponent_card()
	if enemy:
		inspect_enemy(enemy)
		return
	if is_hovering_over_card:
		var card = raycast_check_for_card()
		card.scale = Vector2(BIGGER_CARD_SCALE, BIGGER_CARD_SCALE)
		card.z_index = 2

func is_above(a, b):
	if a.z_index != b.z_index:
		return a.z_index > b.z_index
	return a.get_index() > b.get_index()

func raycast_check_for_opponent_card():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	var best = null
	for r in space_state.intersect_point(parameters, 8):
		if r.collider.collision_mask == 8:
			var c = r.collider.get_parent()
			if c.card_slot_card_is_in and (best == null or is_above(c, best)):    # only cards on the field
				best = c
	return best

func _show_effects(card, on):
	if is_instance_valid(card):
		var fx = card.get_node_or_null("Effects")
		if fx:
			fx.set_hovered(on)

func inspect_enemy(card):
	end_enemy_inspect()
	inspected_enemy = card
	inspected_enemy_scale = card.scale
	inspected_enemy_z = card.z_index
	card.scale = Vector2(BIGGER_CARD_SCALE, BIGGER_CARD_SCALE)
	card.rotation_degrees += 180
	card.z_index = 5
	_show_effects(card, true)

func end_enemy_inspect():
	if inspected_enemy and is_instance_valid(inspected_enemy):
		inspected_enemy.scale = inspected_enemy_scale
		inspected_enemy.z_index = inspected_enemy_z
		inspected_enemy.rotation_degrees -= 180
		_show_effects(inspected_enemy, false)
	inspected_enemy = null

func on_hovered_over_card(card):
	if card.card_slot_card_is_in and card not in $"../BattleManager".player_cards_on_battlefield:
		return
	#if card.card_slot_card_is_in:
		#return
	if !is_hovering_over_card && card.card_type != "Mana":
		is_hovering_over_card = true
		highlight_card(card, true)
		try_show_hover_menu(card) 

func on_hovered_off_card(card):
	if !card.defeated:
		if !card_being_dragged:
			highlight_card(card, false)
			var new_card_hovered = raycast_check_for_card()
			if(new_card_hovered):
				highlight_card(new_card_hovered, true)
				try_show_hover_menu(new_card_hovered)
			else:
				is_hovering_over_card = false
	else:
		highlight_card(card, false)
	hover_target = null
	

func _style_attack_buttons():
	var clear = StyleBoxEmpty.new()
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.18)
	hover.set_corner_radius_all(4)
	var off = StyleBoxFlat.new()
	off.bg_color = Color(0, 0, 0, 0.3)          # dims an unavailable move but keeps it readable
	off.set_corner_radius_all(4)
	for button in attack_buttons:
		button.add_theme_stylebox_override("normal", clear)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		button.add_theme_stylebox_override("focus", clear)
		button.add_theme_stylebox_override("disabled", off)
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			button.add_theme_color_override(color_name, Color(1, 1, 1))
		button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		button.add_theme_constant_override("outline_size", 6)

func highlight_card(card, hovered):
	if hover_target != card && hover_target != null:
		on_hovered_off_card(hover_target)
		hover_target = card
	if card == block_prompt_card and not hovered:
		return
	if card == attack_menu_card:
		return 
	_show_effects(card, hovered)
	if hovered:
		if(card.card_type == "Mana"):
			card.z_index = 2
		else:
			card.scale = Vector2(BIG_CARD_SCALE, BIG_CARD_SCALE)
			card.z_index = 2
	elif card.card_slot_card_is_in:
		card.scale = Vector2(IN_SLOT_CARD_SCALE, IN_SLOT_CARD_SCALE)
		card.z_index = 1
	else:
		if(card.card_type == "Mana"):
			card.scale = Vector2(DEFAULT_MANA_SCALE, DEFAULT_MANA_SCALE)
			card.z_index = 1
		else:
			card.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)
			card.z_index = 1

func raycast_check_for_card_slot():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD_SLOT
	var result = space_state.intersect_point(parameters)
	if result.size() >0:
		return result[0].collider.get_parent()
	return null

func raycast_check_for_card():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD
	var result = space_state.intersect_point(parameters)
	if result.size() >0:
		# return result[0].collider.get_parent()
		return get_card_with_highest_z_index(result)
	return null


func get_card_with_highest_z_index(cards):
	var best = cards[0].collider.get_parent()
	for i in range(1, cards.size()):
		var current = cards[i].collider.get_parent()
		if is_above(current, best):
			best = current
	return best

func reset_played_cards():
	monsters_played_this_turn = 0
	played_magic_card_this_turn = false
	
func show_attack_menu(card):
	if attack_menu_card and attack_menu_card != card:
		hide_attack_menu()
	menu_leave_timer = 0.0
	attack_menu_card = card
	var first = 1 if card.card_type == "Magic" else 0
	var prompting = card == block_prompt_card
	for i in range(attack_buttons.size()):
		var button = attack_buttons[i]
		var move_index = first + i
		if move_index < card.attacks.size():
			var atk = card.attacks[move_index]
			if atk.get("passive", false) != prompting:
				button.visible = false   # passive moves only show during a prompt, and only they do
				continue
			var label = atk["name"] + " (" + str(atk["cost"]) + ")"
			var show_text = show_button_text
			if atk.get("effect", "") == "toggle_mana":
				label = "Stop Using Mana" if card.mana_selected else "Use Mana"
				show_text = true
			button.text = label if show_text else ""
			button.disabled = not $"../BattleManager".can_use_attack(card, atk)
			button.visible = true
		else:
			button.visible = false
	place_attack_menu(card)
	attack_menu.visible = true
	
func place_attack_menu(card):
	var s = card.global_scale
	attack_menu.scale = s
	attack_menu.custom_minimum_size.x = attack_menu_width
	attack_menu.global_position = card.global_position + attack_menu_offset * s


func hide_attack_menu():
	var card = attack_menu_card
	attack_menu.visible = false
	attack_menu_card = null
	mouse_over_attack_menu = false
	if card and is_instance_valid(card) and raycast_check_for_card() != card:
		highlight_card(card, false)


func on_attack_button_pressed(button_index):
	if block_prompt_card:
		block_decided.emit(true)
		return
	if attack_menu_card:
		var first = 1 if attack_menu_card.card_type == "Magic" else 0
		on_attack_chosen(attack_menu_card, first + button_index)


func select_magic_card(card):
	card.selected_attack = 0   # basic attack unless an ability button is pressed
	if $"../BattleManager".opponent_cards_on_battlefield.size() == 0:
		# nothing to hit, so the basic attack goes straight at the opponent (abilities need a target)
		$"../BattleManager".direct_attack(card, "Player")
		return
	select_card_for_battle(card)    # raised, waiting for a target click
	if visible_move_count(card) > 1:
		show_attack_menu(card)      # ability buttons only

func on_attack_chosen(card, attack_index):
	hide_attack_menu()
	card.selected_attack = attack_index
	var battle = $"../BattleManager"
	var move = card.attacks[attack_index]
	if move.get("effect", "") == "toggle_mana":
		toggle_planted_mana(card)
		card.selected_attack = 0
		return
	var target_mode = move.get("target", "enemy")

	if target_mode == "none":
		if selected_monster == card:
			unselect_selected_monster()    # lower it first if it was raised
		battle.use_self_ability(card)      # no target needed, fires straight away
	elif target_mode == "any":
		# needs another card on the field to aim at, from either side
		if battle.player_cards_on_battlefield.size() + battle.opponent_cards_on_battlefield.size() < 2:
			return
		if selected_monster != card:
			select_card_for_battle(card)
	elif battle.opponent_cards_on_battlefield.size() == 0:
		if battle.move_damage(card, move) > 0:
			battle.direct_attack(card, "Player")   # nothing to hit, so it goes at the opponent (effect skipped)
		# an effect-only move needs a target, so with an empty field nothing happens
	else:
		if selected_monster != card:
			select_card_for_battle(card)

func ask_block(card):
	deselect_all()
	block_prompt_card = card
	card.scale = Vector2(BIG_CARD_SCALE, BIG_CARD_SCALE)
	card.z_index = 2
	show_attack_menu(card)
	var button = attack_buttons[0]
	button.text = "Block?"
	block_pulse = create_tween().set_loops()
	block_pulse.tween_property(button, "modulate:a", 0.35, 0.4)
	block_pulse.tween_property(button, "modulate:a", 1.0, 0.4)
	show_hint("Click Block? to step in, or click anywhere else")
	var accepted = await block_decided
	hide_hint()
	if block_pulse:
		block_pulse.kill()
		block_pulse = null
	button.modulate.a = 1.0
	block_prompt_card = null
	hide_attack_menu()
	if is_instance_valid(card):
		highlight_card(card, false)
	return accepted

# moves that show up as buttons in the normal menu (not passive ones)
func visible_move_count(card):
	var n = 0
	for m in card.attacks:
		if not m.get("passive", false):
			n += 1
	return n

func toggle_mana_selection(card):
	if !card.mana_selected:
		player_active_mana += card.mana
		player_active_mana_cards += 1
		card.mana_selected = true
		card.position.y = card.hand_position.y - 20.0
	else:
		player_active_mana -= card.mana
		player_active_mana_cards -= 1
		card.mana_selected = false
		card.position.y = card.hand_position.y
	$"../PlayerActiveManaText".text = str(player_active_mana)
	$"../PlayerActiveManaCardsText".text = str(player_active_mana_cards)

func planted_mana_cards():
	var result = []
	for c in $"../BattleManager".player_cards_on_battlefield:
		if c.has_meta("planted_mana"):
			result.append(c)
	return result

func begin_pending_mana_drag(card):
	pending_mana_card = card
	pending_mana_grab = card.position - get_global_mouse_position()
	pending_mana_origin = get_global_mouse_position()

func toggle_planted_mana(card):
	if card not in $"../BattleManager".player_cards_on_battlefield:
		return
	var value = card.get_meta("planted_mana", 1)
	if selected_monster == card:
		selected_monster = null      # the energy lift replaces the attack-selection lift
	var rest = card.card_slot_card_is_in.position
	if not card.mana_selected:
		player_active_mana += value
		player_active_mana_cards += 1
		card.mana_selected = true
		card.position = rest + Vector2(0, -20)
	else:
		player_active_mana -= value
		player_active_mana_cards -= 1
		card.mana_selected = false
		card.position = rest
	$"../PlayerActiveManaText".text = str(player_active_mana)
	$"../PlayerActiveManaCardsText".text = str(player_active_mana_cards)

# spent planted energy stays on the field, greyed out as if it had attacked
func grey_out_planted(card):
	card.mana_selected = false
	card.position = card.card_slot_card_is_in.position
	$"../BattleManager".mark_card_used(card)
	$"../BattleManager".player_cards_that_attacked_this_turn.append(card)

func plant_mode_active():
	for c in $"../BattleManager".player_cards_on_battlefield:
		if c.ability_script and c.ability_script.has_method("allows_planting"):
			return true
	return false

func drop_planted_selection(card):
	player_active_mana -= card.get_meta("planted_mana", 1)
	player_active_mana_cards -= 1
	card.mana_selected = false
	$"../PlayerActiveManaText".text = str(player_active_mana)
	$"../PlayerActiveManaCardsText".text = str(player_active_mana_cards)

func finish_mana_drag():
	var mana = card_being_dragged
	card_being_dragged = null
	var origin = mana.get_meta("drag_origin", mana.position)
	var moved = mana.position.distance_to(origin) > 10.0
	var slot = raycast_check_for_card_slot()
	if plant_mode_active() and slot and not slot.card_in_slot and not slot.name.begins_with("Enemy"):
		$"../BattleManager".plant_mana_card(mana, slot)
		return
	if moved:
		var tween = get_tree().create_tween()
		tween.tween_property(mana, "position", origin, 0.1)
		Audio.play("place")
	else:
		mana.position = origin
		toggle_mana_selection(mana)   # it was a click, not a drag
