extends Node2D

const CARD_WIDTH = 100
const HAND_Y_POSITION = 920
const DEFAULT_CARD_MOVE_SPEED = 0.1

var player_hand = []
var center_screen_x
var card_animate_speed = 0.1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	center_screen_x = get_viewport().size.x / 2
	
	

func add_card_to_hand(card, speed):
	if card not in player_hand:
		player_hand.insert(0, card)
		update_hand_positions(speed)
	else:
		animate_card_to_position(card, card.hand_position, DEFAULT_CARD_MOVE_SPEED)
	

func update_hand_positions(speed):
	for i in range(player_hand.size()):
		#get card position based on index
		var new_position = Vector2(calculate_card_position(i), HAND_Y_POSITION)
		var card = player_hand[i]
		card.hand_position = new_position
		animate_card_to_position(card, new_position, speed)


func calculate_card_position(index):
	var total_width = (player_hand.size() -1) * CARD_WIDTH
	var x_offset = center_screen_x + index * CARD_WIDTH - total_width / 2
	return x_offset


func animate_card_to_position(card, new_position, speed):
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", new_position, speed)


func remove_card_from_hand(card):
	if card in player_hand:
		player_hand.erase(card)
		update_hand_positions(DEFAULT_CARD_MOVE_SPEED)
		
func reorder_card_in_hand(card):
	player_hand.erase(card)

	# Default to the right end of the hand
	var new_index = player_hand.size()
	for i in range(player_hand.size()):
		if card.position.x < player_hand[i].hand_position.x:
			new_index = i
			break

	player_hand.insert(new_index, card)
	update_hand_positions(DEFAULT_CARD_MOVE_SPEED)
