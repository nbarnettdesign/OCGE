extends CardAbility

func on_turn_start():
	battle().heal(card, card.max_health)

func on_played():
	#print(card.name, " played")
	#print("ABILITY TRIGGERED")
	return

func ability_one():
	#print("Quack: Force target to attack (You choose their Target)")
	return
	
func ability_two():
	#print("Sturdy - Heals back to full health at the start of your turn")
	return
