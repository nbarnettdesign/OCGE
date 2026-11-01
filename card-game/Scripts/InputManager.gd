extends Node2D

signal left_mouse_button_clicked
signal left_mouse_button_released
signal right_mouse_button_clicked
signal right_mouse_button_released

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_DECK = 4
const COLLISION_MASK_OPPONENT_CARD = 8


var card_manager_reference
var deck_reference

func _ready() -> void:
	card_manager_reference = $"../CardManager"
	deck_reference = $"../Deck"
 
func _input(event):
	if event is InputEventMouseButton and $"../CardManager".mouse_over_attack_menu:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			emit_signal("left_mouse_button_clicked")
			raycast_at_cursor()
		else:
			emit_signal("left_mouse_button_released")
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			emit_signal("right_mouse_button_clicked")
		else:
			emit_signal("right_mouse_button_released")
		


func raycast_at_cursor():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		var result_collision_mask = result[0].collider.collision_mask
		if result_collision_mask == COLLISION_MASK_CARD:
			#card clicked
			var card_found = result[0].collider.get_parent()
			if card_found:
				card_manager_reference.card_clicked(card_found)
		elif result_collision_mask == COLLISION_MASK_DECK:
			#Deck Clicked
			deck_reference.draw_card()
		elif result_collision_mask == COLLISION_MASK_OPPONENT_CARD:
			$"../BattleManager".opponent_card_selected(result[0].collider.get_parent())
