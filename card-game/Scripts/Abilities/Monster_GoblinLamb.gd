extends CardAbility


func on_played():
	#print(card.name, " played")
	return

# Goblin Mode: the enemy's hand is shuffled into their deck, then they draw 3
func ability_one(_target):
	var b = battle()
	var enemy = "Opponent" if b.owner_of(card) == "Player" else "Player"
	b.shuffle_hand_into_deck(enemy)
	b.draw_extra_cards(enemy, 3)

# Lamb Mode: Goblin Lamb shuffles itself into your deck, then you draw 2
func ability_two(_target):
	var b = battle()
	var side = b.owner_of(card)
	b.shuffle_card_into_deck(card)
	b.draw_extra_cards(side, 2)

func ai_ability_score(i, _target):
	var b = battle()
	var side = b.owner_of(card)
	var enemy = "Player" if side == "Opponent" else "Opponent"
	if i == 0:                                    # Goblin Mode: their hand goes back into their deck, then they draw 3
		return maxf(b.hand_size(enemy) - 3, 0) * 8.0
	if i == 1:                                    # Lamb Mode: this card goes into our deck and we draw 2
		if b.hand_size(side) <= 1 or b.ai_max_incoming_hit() >= card.health:
			return 12.0
	return 0.0
