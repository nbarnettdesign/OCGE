extends CardAbility

func ability_one(_target):
	var b = battle()
	b.cleanse(b.player_cards_on_battlefield + b.opponent_cards_on_battlefield)
