extends CardAbility

# whoever destroys it with an attack draws 2 cards
func on_destroyed():
	var side = card.get_meta("killed_by", "")
	if side != "":
		await battle().draw_extra_cards(side, 2)
