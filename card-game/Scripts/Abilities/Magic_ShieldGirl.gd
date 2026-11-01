extends CardAbility


func on_played():
	card.statuses["immune_to_attacks"] = true
