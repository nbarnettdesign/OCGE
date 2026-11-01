extends CardAbility


func on_turn_end(used):
	if used:
		return
	if not card.statuses.has("original_stats"):
		card.statuses["original_stats"] = {"attack": card.attack, "max_health": card.max_health}
	card.max_health += 2
	card.health += 2
	battle().update_health_label(card)
