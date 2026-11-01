extends CardAbility


func on_played():
	#print(card.name, " played")
	#print("Instead of attacking, Tie up another card. Both that card and skeleton cowboy can not attack until one is destroyed")
	return
	
func ability_one(target):
	battle().tie_cards(card, target)
	
func ai_ability_score(_move_index, target):   # TieUp
	if target.statuses.has("tied_to") or target.attack <= 0:
		return 0.0
	var gain = (target.attack - card.attack) * 0.6
	return gain if gain >= 6.0 else 0.0
