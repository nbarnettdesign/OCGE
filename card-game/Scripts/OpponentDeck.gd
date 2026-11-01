extends Node2D

const CARD_SCENE_PATH = "res://Scenes/Opponentcard.tscn"
const CARD_DRAW_SPEED = .4
const STARTING_HAND_SIZE = 5

var opponent_deck = [["Dante", "Gun", "Link", "Wolvy", "Goomy", "Dante", "Gun", "Link", "Wolvy", "Goomy"]]
var card_database_reference


func _ready() -> void:
	opponent_deck = GameState.opponent_deck_for_battle()
	opponent_deck.shuffle()
	$Deck/CardCountText.text = str(opponent_deck.size())
	card_database_reference = preload("res://Scripts/CardDatabase.gd")
	for i in range(mini(GameState.rules["starting_hand"], opponent_deck.size())):
		draw_card()



# Called every frame. 'delta' is the elapsed time since the previous frame.
func draw_card():
	if opponent_deck.is_empty():
		return
	var card_drawn_name = opponent_deck[0]
	opponent_deck.erase(card_drawn_name)
	$Deck/CardCountText.text = str(opponent_deck.size())
	#deck runs out of cards
	if(opponent_deck.size() == 0):
		$Deck/Sprite2D.modulate.a = 0.2
		$Deck/CardCountText.text = ""
	var card_scene = preload(CARD_SCENE_PATH)
	var card_image_path
	var new_card = card_scene.instantiate()
	assign_card_info_to_card(new_card, card_drawn_name)
	if ResourceLoader.exists("res://CardSprites/Cards_" + card_drawn_name + ".png"):
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
				
	else:
		card_image_path = str("res://CardSprites/Cards_back.png")
		new_card.get_node("Attack").text = "!"
		new_card.get_node("Health").text = "!"
		new_card.get_node("CardImage").texture = load(card_image_path)
	$"../CardManager".add_child(new_card)
	
	new_card.position = position
	new_card.rotation_degrees = 180
	new_card.name = "Card"
	CardFactory.apply_sleeve(new_card, GameState.npc_sleeve())
	$"../OpponentHand".add_card_to_hand(new_card, CARD_DRAW_SPEED)
	#new_card.get_node("AnimationPlayer").play("card_flip")

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
	new_card.get_node("CardImage").texture = load(str("res://CardSprites/Cards_" + card_drawn_name + ".png"))
	$"../BattleManager".update_attack_label(new_card)
	new_card.get_node(str("Transform/HealthText" + newcardtype)).text = str(new_card.health)
	new_card.get_node(str("Transform/Mana" + newcardtype)).text = str(new_card.mana)
	new_card.get_node(str("Transform/AbilityText" + newcardtype)).text = str(new_card.mana)

func assign_card_info_to_card(new_card, card_drawn_name):
	CardFactory.apply_data(new_card, card_drawn_name)
