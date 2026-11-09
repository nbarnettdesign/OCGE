extends Node2D

const CARD_SCENE_PATH = "res://Scenes/card.tscn"
const CARD_DRAW_SPEED = .4
const STARTING_HAND_SIZE = 5

var player_deck = []
var card_database_reference
var drawn_card_this_turn = false


func _ready() -> void:
	
	$CardCountText.text = str(player_deck.size())
	card_database_reference = preload("res://Scripts/CardDatabase.gd")
	player_deck = GameState.player_deck_for_battle()
	player_deck.shuffle()
	for i in range(GameState.rules["starting_hand"]):
		draw_card()
		drawn_card_this_turn = false
	drawn_card_this_turn = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func draw_card():
	if drawn_card_this_turn:
		return
	drawn_card_this_turn = true
	if player_deck.size() != 0:
		var card_drawn_name = player_deck[0]
		player_deck.erase(card_drawn_name)

		$CardCountText.text = str(player_deck.size())
		#deck runs out of cards
		if(player_deck.size() == 0):
			$Area2D/CollisionShape2D.disabled = true
			$Sprite2D.modulate.a = 0.2
			$CardCountText.text = ""
		var card_scene = preload(CARD_SCENE_PATH)
		var new_card = card_scene.instantiate()
		assign_card_info_to_card(new_card, card_drawn_name)
		if new_card.card_type == "Monster":
			hide_text(new_card, "Magic")
			hide_text(new_card, "Sport")
			show_text(new_card, "Monster", card_drawn_name)
			
		elif new_card.card_type == "Magic":
			hide_text(new_card, "Monster")
			hide_text(new_card, "Sport")
			show_text(new_card, "Magic", card_drawn_name)
			
		elif new_card.card_type == "Sport":
			hide_text(new_card, "Magic")
			hide_text(new_card, "Monster")
			show_text(new_card, "Sport", card_drawn_name)
				
		$"../CardManager".add_child(new_card)
		new_card.position = position
		new_card.name = "Card"
		CardFactory.apply_sleeve(new_card, GameState.equipped_sleeve)
		$"../PlayerHand".add_card_to_hand(new_card, CARD_DRAW_SPEED)
		new_card.get_node("AnimationPlayer").play("card_flip")
		Audio.play("draw")

func hide_text(new_card, newcardtype):
	for n in CardFactory.attack_nodes(new_card, newcardtype):
		n.visible = false
	new_card.get_node(str("Transform/HealthText" + newcardtype)).visible = false
	new_card.get_node(str("Transform/Mana" + newcardtype)).visible = false
	new_card.get_node(str("Transform/AbilityText" + newcardtype)).visible = false

func show_text(new_card, newcardtype, card_drawn_name):
	for n in CardFactory.attack_nodes(new_card, newcardtype):
		n.visible = true
	new_card.get_node(str("Transform/HealthText" + newcardtype)).visible = true
	new_card.get_node(str("Transform/Mana" + newcardtype)).visible = true
	new_card.get_node(str("Transform/AbilityText" + newcardtype)).visible = false
	if ResourceLoader.exists("res://CardSprites/Cards_" + card_drawn_name + ".png"):
		new_card.get_node("CardImage").texture = load(str("res://CardSprites/Cards_" + card_drawn_name + ".png"))
	else:
		var card_image_path = str("res://CardSprites/Cards_back.png")
		new_card.get_node(str("Transform/AbilityText" + newcardtype)).text = new_card.name
		new_card.get_node(str("Transform/AbilityText" + newcardtype)).visible = true
		new_card.get_node("CardImage").texture = load(card_image_path)
	$"../BattleManager".update_attack_label(new_card)
	new_card.get_node(str("Transform/HealthText" + newcardtype)).text = str(new_card.health)
	new_card.get_node(str("Transform/Mana" + newcardtype)).text = str(new_card.mana)
	new_card.get_node(str("Transform/AbilityText" + newcardtype)).text = str(new_card.mana)

func assign_card_info_to_card(new_card, card_drawn_name):
	CardFactory.apply_data(new_card, card_drawn_name)

func reset_draw():
	drawn_card_this_turn = false
