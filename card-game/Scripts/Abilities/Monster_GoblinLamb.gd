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

func ai_ability_score(move_index, _target):   # 0 = Goblin Mode, 1 = Lamb Mode
	var b = battle()
	if move_index == 0:
		var hand_size = b.get_node("../PlayerHand").player_hand.size()
		return (hand_size - 3) * 6.0 if hand_size > 3 else 0.0
	if b.get_node("../OpponentDeck").opponent_deck.is_empty():
		return 0.0
	var gain = 0.0
	if card.health < card.max_health * 0.25:
		gain += 15.0                                  # nearly dead anyway
	var best_in_hand = 0.0
	for c in b.get_node("../OpponentHand").opponent_mana_hand:
		if c.card_type == "Monster" or c.card_type == "Magic":
			best_in_hand = max(best_in_hand, b.ai_card_weight(c))
	var mine = b.ai_card_value(card)
	if best_in_hand < mine:
		gain += 10.0 + min(20.0, (mine - best_in_hand) * 0.2)   # nothing in hand beats it: a draw can only help
	if b.opponent_cards_on_battlefield.size() <= 1:
		gain -= b.ai_heart_value * 0.5               # it's the last card on the field
	return max(gain, 0.0)
