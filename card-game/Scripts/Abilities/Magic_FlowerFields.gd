extends CardAbility


var hits = 0                 # attacks from cards on the field this turn
var lethal_pending = false   # the damage taken this turn has been enough to kill it

func on_played():
	hits = 0
	lethal_pending = false
	card.statuses["never_attacks"] = true

# any damage, sports cards included
func on_damaged(amount, source_type):
	if card.health <= 0:
		lethal_pending = true
	settle()

# only attacks from cards on the field (sports cards don't call this)
func on_attacked(attacker, damage):
	if damage > 0:
		hits += 1
		settle()
func ai_hits_needed():
	return max(1, 2 - hits)

func settle():
	if not lethal_pending:
		return
	if hits >= 2:
		card.health = 0   # enough damage and two attacks: destroyed
	else:
		card.health = 1   # enough damage, but not enough attacks yet: survives
	battle().update_health_label(card)

func on_turn_start():
	hits = 0
	lethal_pending = false

func on_status_applied(status):
	if status == "burned":
		card.health = 0
		battle().update_health_label(card)

func predict_damage(amount):
	return mini(amount, card.health - 1) if card.health > 1 else amount
