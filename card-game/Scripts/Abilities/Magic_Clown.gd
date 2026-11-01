extends CardAbility


func on_played():
	#print(card.name, " played")
	#print("Pocket Sand: Blinding taget - Target has 50% chance to miss attack")
	return


func ability_one(target):
	battle().apply_status(target, "blinded")

func ai_ability_score(move_index, target):   # move 1 = Pocket Sand
	if move_index != 1 or target.statuses.has("blinded") or target.attack <= 0:
		return 0.0
	return 5.0 + target.attack * 0.5
