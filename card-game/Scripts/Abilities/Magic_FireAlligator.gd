extends CardAbility



func on_played():
	#print(card.name, " played")
	#print("Burns attacked target (Burned target takes double damage)")
	return

func on_attacked(attacker, damage):
	if damage > 0:
		battle().apply_status(attacker, "burned")

func ability_one(target):
	battle().apply_status(target, "burned")
	

func ai_ability_score(_move_index, target):
	return 0.0 if target.statuses.has("burned") else 8.0
