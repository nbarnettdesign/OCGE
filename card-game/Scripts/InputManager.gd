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
	if result.size() == 0:
		return
	# the card drawn on top wins, not whichever the physics engine lists first
	var top = null
	var top_mask = 0
	for r in result:
		var mask = r.collider.collision_mask
		if mask != COLLISION_MASK_CARD and mask != COLLISION_MASK_OPPONENT_CARD:
			continue
		var c = r.collider.get_parent()
		if mask == COLLISION_MASK_OPPONENT_CARD and not c.card_slot_card_is_in:
			continue                              # hidden hand cards can't be clicked
		if top == null or card_manager_reference.is_above(c, top):
			top = c
			top_mask = mask
	if top != null:
		if top_mask == COLLISION_MASK_CARD:
			card_manager_reference.card_clicked(top)
		else:
			$"../BattleManager".opponent_card_selected(top)
		return
	for r in result:
		if r.collider.collision_mask == COLLISION_MASK_DECK:
			deck_reference.draw_card()
			return
