extends CardAbility


func on_played():
	#print(card.name, " played")
	#print("Swap attack and Defence of another card instead of attacking")
	return

func ability_one(target):
	battle().swap_attack_and_health(target)
	
func ai_ability_score(_move_index, target):   # Swap
	var b = battle()
	var diff = float(target.health - target.attack)
	var gain = 0.0
	if target in b.opponent_cards_on_battlefield:
		# its new health would be its old attack: never swap if that dies to a hit next turn
		if target.attack <= 0 or target.attack <= b.ai_max_incoming_hit():
			return 0.0
		gain = diff * 0.3 if diff > 0 else 0.0
	else:
		gain = -diff * 0.3 if diff < 0 else 0.0
	return gain if gain >= 6.0 else 0.0
