extends CardAbility

func ability_one(target):
	if target != null and is_instance_valid(target):
		battle().apply_status(target, "poisoned")
