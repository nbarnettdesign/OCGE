extends CardAbility


func on_played():
	card.statuses["only_hurt_by_attacks"] = true
