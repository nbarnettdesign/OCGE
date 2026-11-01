extends CardAbility

func on_played():
	#print(card.name, " played")
	return

# while a Buff Tree is on your field, energy cards can be dragged onto free slots
func allows_planting():
	return true
