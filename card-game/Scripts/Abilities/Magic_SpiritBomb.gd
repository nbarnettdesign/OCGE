extends CardAbility

func on_played():
	card.statuses["haste"] = true
	#print("haste set: ", card.statuses)

# Detonate: destroys itself, the target and everything next to the target.
# Health is set to 0 directly, so it ignores immunity statuses.
func ability_one(target):
	card.health = 0              # attack() destroys the bomb itself
	if target == null:
		return
	var b = battle()
	target.health = 0            # attack() destroys the target
	for other in b.adjacent_cards(target):
		if other == card:
			continue
		other.health = 0
		var owner = "Player" if other in b.player_cards_on_battlefield else "Opponent"
		b.destroy_card(other, owner)

# in the discard pile it turns back into a fresh Space Monkey
func on_destroyed():
	battle().call_deferred("transform_card", card, "SpaceMonkey")

func ai_ability_score(_move_index, target):
	var b = battle()
	var total = b.ai_card_value(target)
	for other in b.adjacent_cards(target):
		if other != card:
			total += b.ai_card_value(other) * (1.0 if other in b.player_cards_on_battlefield else -1.0)
	return total - b.ai_card_value(card) * 0.5
