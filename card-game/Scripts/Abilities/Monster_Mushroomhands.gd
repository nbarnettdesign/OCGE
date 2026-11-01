extends CardAbility


func on_played():
	#print(card.name, " played")
	#print("ABILITY TRIGGERED")
	return

func ability_one(target):
	battle().apply_status(target, "cant_attack")
	
func ability_two():
	#print("None")
	return

func ai_ability_score(_move_index, target):   # Spore: bonus on top of its 5 damage
	if target.statuses.has("cant_attack") or target.attack <= 0:
		return 0.0
	return 3.0 + target.attack * 0.5
