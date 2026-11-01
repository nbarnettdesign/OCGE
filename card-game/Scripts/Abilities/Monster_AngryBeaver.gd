extends CardAbility


func on_played():
	#print(card.name, " played")
	return
# Angry: the clicked enemy card is forced to attack a card of your choice
func ability_one(target):
	if target == null:
		return
	var b = battle()
	if b.player_cards_on_battlefield.size() + b.opponent_cards_on_battlefield.size() < 2:
		return
	var victim
	if b.owner_of(card) == "Player":
		victim = await b.get_node("../CardManager").pick_card(target)
	else:
		victim = ai_choose_victim(target)
	if victim == null:
		return
	await b.forced_attack(target, victim)

func ability_two(_target):
	var b = battle()
	b.draw_extra_mana(b.owner_of(card))
	
func ai_ability_score(move_index, target):   # 0 = Angry, 1 = Beaver
	var b = battle()
	if move_index == 1:
		var deck = b.get_node("../ManaDeck").mana_deck
		return 10.0 if deck.size() > 0 and b.ai_available_mana() < 4 else 0.0
	if target == null:
		return 0.0
	var victim = ai_choose_victim(target)
	var dmg = b.ai_best_damage(target, target.attached_mana)
	if victim == null or dmg <= 0:
		return 0.0
	var gain = b.ai_card_value(victim) * min(1.0, float(dmg) / max(1, victim.health))
	if dmg >= victim.health:
		gain += 10.0
	if target in b.opponent_cards_on_battlefield:
		# our own card attacking again: only worth it if it has already attacked
		return gain if target.get_meta("used_this_turn", false) else 0.0
	return gain * 0.8      # forcing one of your cards to hit another of yours

func ai_choose_victim(forced):
	var b = battle()
	var dmg = b.ai_best_damage(forced, forced.attached_mana)
	var best = null
	var best_score = -1.0
	for c in b.player_cards_on_battlefield:
		if c == forced:
			continue
		var s = b.ai_card_value(c) * min(1.0, float(dmg) / max(1, c.health))
		if s > best_score:
			best_score = s
			best = c
	return best
