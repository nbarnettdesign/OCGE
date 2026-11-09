class_name CardFactory
extends RefCounted

const CARD_DATABASE = preload("res://Scripts/CardDatabase.gd")

# Copies a card's database data onto a card node. Used by all three decks.
static func apply_data(card, card_name):
	var data = CARD_DATABASE.get_card(card_name)
	card.attack = data["attack"]
	card.health = data["health"]
	card.max_health = data["health"]
	card.card_type = data["type"]
	card.mana = data["mana"]
	card.ability = data["ability_text"]
	
	var script_path = data.get("script")
	if script_path:
		var ability = load(script_path).new()
		ability.card = card
		card.ability_script = ability
	if data.has("attacks"):
		card.attacks = data["attacks"]
	else:
		card.attacks = [{"name": "Attack", "cost": 0, "damage": "attack"}]
	var role = data.get("ai_role", "")
	if role != "":
		card.set_meta("ai_role", role)
	card.set_meta("keywords", data.get("keywords", []))
	card.set_meta("card_name", card_name)
	card.set_meta("tags", CARD_DATABASE.get_card(card_name).get("tags", []))
	card.set_meta("token", data.get("token", false))

static func attack_nodes(card, card_type):
	if card_type == "Monster":
		return [card.get_node("Transform/AttackTextMonster1"), card.get_node("Transform/AttackTextMonster2")]
	return [card.get_node("Transform/AttackText" + card_type)]
	
static func apply_sleeve(card, sleeve_id):
	if sleeve_id == "default" or not SleeveDatabase.SLEEVES.has(sleeve_id):
		return
	var path = SleeveDatabase.SLEEVES[sleeve_id].get("texture", "")
	if path == "" or not ResourceLoader.exists(path):
		return
	for node in card.find_children("*", "", true, false):
		if node.is_in_group("card_back") or node.name in ["CardBack", "Back"]:
			if "texture" in node:
				node.texture = load(path)
			return
	print("Sleeve: no card back node found on ", card.name, " (add it to the group card_back)")
