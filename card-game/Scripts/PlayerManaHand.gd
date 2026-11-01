extends Node2D

const CARD_WIDTH = 40
const HAND_Y_POSITION = 500
const HAND_X_OFFSET = -300
const DEFAULT_CARD_MOVE_SPEED = 0.1
const DECK_X = 960              # x position of the mana deck (or read it from the deck node)
const DECK_GAP = 120            # space between deck and the nearest card
const SPREAD_DIRECTION = -1     # -1 = spread left, 1 = spread right

var player_mana_hand = []
var center_screen_x
var card_animate_speed = 0.1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	center_screen_x = get_viewport().size.x / 2
	
	

func add_card_to_hand(card, speed):
	if card not in player_mana_hand:
		player_mana_hand.insert(0, card)
		update_hand_positions(speed)
	else:
		animate_card_to_position(card, card.hand_position, DEFAULT_CARD_MOVE_SPEED)
	

func update_hand_positions(speed):
	for i in range(player_mana_hand.size()):
		#get card position based on index
		var new_position = Vector2(calculate_card_position(i), HAND_Y_POSITION)
		var card = player_mana_hand[i]
		card.hand_position = new_position
		if card.mana_selected:
			new_position.y -= 20.0      # selected energy stays lifted when the hand rearranges
		animate_card_to_position(card, new_position, speed)


func calculate_card_position(index):
	return DECK_X + SPREAD_DIRECTION * (DECK_GAP + index * CARD_WIDTH)


func animate_card_to_position(card, new_position, speed):
	var old_tween = card.get_meta("move_tween", null)
	if old_tween and old_tween.is_valid():
		old_tween.kill()          # a newer move replaces any move still running
	var tween = get_tree().create_tween()
	card.set_meta("move_tween", tween)
	tween.tween_property(card, "position", new_position, speed)


func remove_card_from_hand(card):
	if card in player_mana_hand:
		player_mana_hand.erase(card)
		update_hand_positions(DEFAULT_CARD_MOVE_SPEED)
		
func reorder_card_in_hand(card):
	player_mana_hand.erase(card)

	# Default to the right end of the hand
	var new_index = player_mana_hand.size()
	for i in range(player_mana_hand.size()):
		if card.position.x < player_mana_hand[i].hand_position.x:
			new_index = i
			break

	player_mana_hand.insert(new_index, card)
	update_hand_positions(DEFAULT_CARD_MOVE_SPEED)
