extends CardAbility


func on_played():
	return

func ability_one(target):
	battle().apply_status(target, "cant_attack")
	#print("STARE on ", target.name, " | ", target.statuses)
	
func ability_two(target):
	battle().return_card_to_hand(target)

func ai_ability_score(move_index, target):   # 0 = Stare, 1 = Creep Shot
	if move_index == 0:
		if target.statuses.has("cant_attack") or target.attack <= 0:
			return 0.0
		return 4.0 + target.attack * 0.7
	if target.attached_mana <= 0:
		return 0.0
	return target.attached_mana * 12.0 + battle().ai_card_value(target) * 0.2 - 4.0
