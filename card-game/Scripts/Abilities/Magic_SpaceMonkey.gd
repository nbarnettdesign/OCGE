extends CardAbility

const TRANSFORM_COST = 4

func on_played():
	card.statuses["returns_to_hand"] = true

func on_returned_to_hand():
	card.attack += 2
	card.max_health += 2
	card.health = card.max_health
	card.mana += 1
	var b = battle()
	b.update_attack_label(card)
	b.update_health_label(card)
	b.update_mana_label(card)
	if card.mana >= TRANSFORM_COST:
		card.set_meta("used_this_turn", false)
		b.call_deferred("transform_card", card, "SpiritBomb")   # deferred: this script gets replaced
