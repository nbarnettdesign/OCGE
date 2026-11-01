extends Node2D

const CARD_SCENE_PATH = "res://Scenes/card.tscn"
const CARD_DRAW_SPEED = .4
const STARTING_HAND_SIZE = 0

var mana_deck = []
var card_database_reference
var drawn_card_this_turn = false


func _ready() -> void:
	
	$CardCountText.text = str(mana_deck.size())
	card_database_reference = preload("res://Scripts/CardDatabase.gd")
	mana_deck = $"../DeckDatabase".manadeck.duplicate()
	mana_deck.shuffle()
	for i in range(STARTING_HAND_SIZE):
		draw_card()
		drawn_card_this_turn = false
	draw_card()
	$CardCountText.text = str(mana_deck.size())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func draw_card():
	var is_opponent = $"../BattleManager".is_opponents_turn
	if drawn_card_this_turn && !is_opponent:
		return
	drawn_card_this_turn = true
	
	
	if mana_deck.size() != 0:
		var card_drawn_name = mana_deck[0]
		mana_deck.erase(card_drawn_name)

		$CardCountText.text = str(mana_deck.size())
		#deck runs out of cards
		if(mana_deck.size() == 0):
			$Area2D/CollisionShape2D.disabled = true
			$Sprite2D.modulate.a = 0.2
			$CardCountText.text = ""
		var card_scene = preload(CARD_SCENE_PATH)
		var card_image_path
		var new_card = card_scene.instantiate()
		assign_card_info_to_card(new_card, card_drawn_name)
		if ResourceLoader.exists("res://CardSprites/PlayingMana/Cards_" + card_drawn_name + ".png"):
			if new_card.card_type == "Mana":
				hide_text(new_card, "Magic")
				hide_text(new_card, "Sport")
				hide_text(new_card, "Monster")
				show_text(new_card, "Mana", card_drawn_name)
			else:
				card_image_path = str("res://CardSprites/Cards_back.png")
				new_card.get_node("Attack").text = "!"
				new_card.get_node("Health").text = "!"
				new_card.get_node("CardImage").texture = load(card_image_path)
		$"../CardManager".add_child(new_card)
		new_card.position = position
		new_card.name = "ManaCard"
		
		if is_opponent:
			new_card.get_node("Area2D/CollisionShape2D").disabled = true
			$"../OpponentManaHand".add_card_to_hand(new_card, CARD_DRAW_SPEED)
		else:
			$"../PlayerManaHand".add_card_to_hand(new_card, CARD_DRAW_SPEED)
		new_card.get_node("AnimationPlayer").play("card_flip_mana")

func hide_text(new_card, newcardtype):
	for n in CardFactory.attack_nodes(new_card, newcardtype):
		n.visible = false
	new_card.get_node(str("Transform/HealthText" + newcardtype)).visible = false
	new_card.get_node(str("Transform/Mana" + newcardtype)).visible = false
	new_card.get_node(str("Transform/AbilityText" + newcardtype)).visible = false

func show_text(new_card, newcardtype, card_drawn_name):
	new_card.get_node("CardImage").texture = load(str("res://CardSprites/PlayingMana/Cards_" + card_drawn_name + ".png"))

func assign_card_info_to_card(new_card, card_drawn_name):
	CardFactory.apply_data(new_card, card_drawn_name)

func reset_draw():
	drawn_card_this_turn = false
