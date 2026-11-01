extends CardAbility




func on_played():
	#print(card.name, " played")
	#print("ABILITY TRIGGERED")
	return

func ability_one(target):
	battle().apply_status(target, "burned")
	

func ability_two(target):
	card.health = 0
	battle().update_health_label(card)

func ai_ability_score(move_index, target):   # 0 = Burn, 1 = Wildfire
	var b = battle()
	if move_index == 0:
		return 0.0 if target.statuses.has("burned") else 10.0
	var penalty = b.ai_card_value(card)
	if b.opponent_cards_on_battlefield.size() <= 1:
		penalty += b.ai_heart_value
	return -penalty
