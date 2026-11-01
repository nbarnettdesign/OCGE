extends CardAbility


func on_played():
	#print(card.name, " played")
	return

func ability_one(target):
	#print("Roll Over - Just damage")
	return
	
func ability_two(target):
	battle().heal(card,20)

func ai_ability_score(move_index, _target):   # FeedingFrenzy heals it
	if card.attacks[move_index]["name"] != "FeedingFrenzy":
		return 0.0
	return 8.0 if card.health < card.max_health * 0.6 else 0.0
