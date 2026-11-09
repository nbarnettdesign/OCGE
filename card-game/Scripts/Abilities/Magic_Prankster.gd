extends CardAbility

func ability_one(_target):
	var b = battle()
	b.spawn_card("PinataToken", _enemy_of(b.owner_of(card)))

func ai_ability_score(_move_index, _target):
	var b = battle()
	return 3.0 if b.free_slot_for(_enemy_of(b.owner_of(card))) != null else 0.0

func _enemy_of(side):
	return "Opponent" if side == "Player" else "Player"
