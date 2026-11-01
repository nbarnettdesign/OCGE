class_name BoardRules
extends RefCounted

# Every rule a battle understands, with its normal value.
# A rule set below only lists the rules it changes.
const DEFAULTS = {
	"player_hearts": 5,        # starting hearts
	"opponent_hearts": 5,
	"starting_hand": 5,        # cards drawn at the start (both sides)
	"monsters_per_turn": 1,    # monsters each side may play per turn
	"direct_hit_damage": 1,    # hearts lost per direct attack
	"turn_limit": 0,           # 0 = none. Otherwise after this many rounds, most hearts wins
	"banned_types": [],        # card types nobody may play: "Monster", "Magic", "Sport"
}

# Add a rule set by adding an entry here. NPCs refer to them by id.
const RULES = {
	"standard": {
		"name": "Standard",
		"description": "No special rules.",
	},
	"sudden_death": {
		"name": "Sudden Death",
		"description": "One heart each. First hit wins.",
		"player_hearts": 1, "opponent_hearts": 1,
	},
	"heavy_hearts": {
		"name": "Heavy Hearts",
		"description": "Ten hearts each. A long fight.",
		"player_hearts": 10, "opponent_hearts": 10,
	},
	"big_hands": {
		"name": "Big Hands",
		"description": "Both sides start with 8 cards.",
		"starting_hand": 8,
	},
	"swarm": {
		"name": "Swarm",
		"description": "Play up to two monsters each turn.",
		"monsters_per_turn": 2,
	},
	"hard_hits": {
		"name": "Hard Hits",
		"description": "Direct attacks take two hearts.",
		"direct_hit_damage": 2,
	},
	"speed_duel": {
		"name": "Speed Duel",
		"description": "After 6 rounds, whoever has more hearts wins.",
		"turn_limit": 6,
	},
	"no_sports": {
		"name": "No Sports",
		"description": "Sports cards can't be played.",
		"banned_types": ["Sport"],
	},
	"no_magic": {
		"name": "No Magic",
		"description": "Magic cards can't be played.",
		"banned_types": ["Magic"],
	},
	"no_monsters": {
		"name": "No Monsters",
		"description": "Monster cards can't be played.",
		"banned_types": ["Monster"],
	},
	"boss_fight": {
		"name": "Boss Fight",
		"description": "The opponent starts with 8 hearts.",
		"opponent_hearts": 8,
	},
}


# merges rule sets into one dictionary. Later sets win, banned lists combine
static func build(rule_ids: Array) -> Dictionary:
	var merged = DEFAULTS.duplicate(true)
	for id in rule_ids:
		var rule = RULES.get(id, {})
		for key in rule:
			if key == "name" or key == "description":
				continue
			if key == "banned_types":
				merged[key] = merged[key] + rule[key]
			else:
				merged[key] = rule[key]
	return merged


# readable lines for menus
static func describe(rule_ids: Array) -> Array:
	var lines = []
	for id in rule_ids:
		var rule = RULES.get(id, {})
		if rule.is_empty() or id == "standard":
			continue
		lines.append(rule["name"] + ": " + rule["description"])
	return lines
