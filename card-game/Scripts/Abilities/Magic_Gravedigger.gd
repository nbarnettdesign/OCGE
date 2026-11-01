extends CardAbility

func ability_one(_target):
	var b = battle()
	b.spawn_card("ZombieToken", b.owner_of(card))

func ai_ability_score(_move_index, _target):
	var b = battle()
	return 5.0 if b.free_slot_for(b.owner_of(card)) != null else 0.0
