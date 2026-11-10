const RANKS = {"02": "2", "03": "3", "04": "4", "05": "5", "06": "6", "07": "7", "08": "8",
	"09": "9", "10": "10", "J": "Jack", "Q": "Queen", "K": "King", "A": "Ace"}
const SUITS = ["Clubs", "Diamonds", "Hearts", "Spades"]

static func display_name(id):
	var card = get_card(id)
	if card is Dictionary and card.has("name"):
		return card["name"]
	# playing cards (Clubs02, HeartsQ...) are named automatically
	for suit in SUITS:
		if id.begins_with(suit) and RANKS.has(id.substr(suit.length())):
			return RANKS[id.substr(suit.length())] + " of " + suit
	# otherwise put a space before each capital ("FireAlligator" -> "Fire Alligator")
	var result = ""
	for i in range(id.length()):
		var c = id[i]
		var is_upper = c == c.to_upper() and c != c.to_lower()
		if i > 0 and is_upper and id[i - 1] == id[i - 1].to_lower():
			result += " "
		result += c
	return result

static func has_tag(id, tag):
	var card = get_card(id)
	return card is Dictionary and tag in card.get("tags", [])

const CARDS = { #Attack, Health, Type, Mana, Ability Text, Ability script
	#Monsters
	"AngryBeaver" = {"name": "Angry Beaver", "attack": 0, "health": 65, "type": "Monster", "mana": 1, "ability_text": null,
	"script": "res://Scripts/Abilities/Monster_AngryBeaver.gd",
	"tags": ["Animal", "Beaver", "Angry"],
	"attacks": [
		{"name": "Angry", "cost": 2, "damage": 0, "effect": "ability_one", "target": "any"},
		{"name": "Beaver", "cost": 2, "damage": 0, "effect": "ability_two", "target": "none"},
	]},
	
	"BoxPenguin" = {"name": "Box Penguin", "attack": 15, "health": 70, "type": "Monster", "mana": 1, "ability_text": null,
	"ai_role": "defender",
	"tags": ["Animal", "Penguin", "Square"],
	"script": "res://Scripts/Abilities/Monster_BoxPenguin.gd",
	"attacks": [
		{"name": "Quack", "cost": 2, "damage": 15},
	]},
	
	"ChunkyPig" = {"name": "Chunky Pig", "attack": 15, "health": 110, "type": "Monster", "mana": 1, "ability_text": null,
	"ai_role": "defender",
	"tags": ["Animal", "Pig", "Round"],
	"script": "res://Scripts/Abilities/Monster_ChunkyPig.gd",
	"attacks": [
		{"name": "RollOver", "cost": 1, "damage": 15},
		{"name": "FeedingFrenzy", "cost": 3, "damage": 30, "effect": "ability_two", "heals": 20},
	]},
	
	"Dendoko" = {"name": "Dendoko", "attack": 0, "health": 30, "type": "Monster", "mana": 1, "ability_text": null,
	"ai_role": "protected",
	"tags": ["Spooky"],
	"script": "res://Scripts/Abilities/Monster_Dendoko.gd",
	"attacks": [
		{"name": "Stare", "cost": 2, "damage": 0, "effect": "ability_one"},
		{"name": "Creep Shot", "cost": 3, "damage": 0, "effect": "ability_two"},
	]},
	
	"GoblinLamb" = {"name": "Goblin Lamb", "attack": 0, "health": 120, "type": "Monster", "mana": 1, "ability_text": null,
	"script": "res://Scripts/Abilities/Monster_GoblinLamb.gd",
	"tags": ["Animal", "Lamb", "Goblin"],
	"attacks": [
		{"name": "GoblinMode", "cost": 1, "damage": 0, "effect": "ability_one", "target": "none"},
		{"name": "LambMode", "cost": 1, "damage": 0, "effect": "ability_two", "target": "none"},
	]},
	
	"JumpMan" = {"name": "Jump Man", "attack": 20, "health": 120, "type": "Monster", "mana": 1, "ability_text": null,
	"script": "res://Scripts/Abilities/Monster_JumpMan.gd",
	"tags": ["Human", "Humanoid", "Moustache"],
	"attacks": [
		{"name": "Jump", "cost": 1, "damage": "per_mana"},
	]},

	"LiteralFire" = {"name": "Literal Fire", "attack": 20, "health": 40, "type": "Monster", "mana": 1, "ability_text": null,
	"script": "res://Scripts/Abilities/Monster_LiteralFire.gd",
	"tags": ["Fire", "Nature"],
	"attacks": [
		{"name": "Burn", "cost": 1, "damage": 20, "effect": "ability_one", "inflicts": ["burned"]},
		{"name": "Wildfire", "cost": 4, "damage": 99999, "effect": "ability_two"},
	]},

	"MushroomHands" = {"name": "Mushroom Hands Dan", "attack": 5, "health": 90, "type": "Monster", "mana": 1, "ability_text": null,
	"ai_role": "protected",
	"tags": ["Human", "Humanoid", "Mushroom"],
	"script": "res://Scripts/Abilities/Monster_Mushroomhands.gd",
	"attacks": [
		{"name": "Spore", "cost": 1, "damage": 5, "effect": "ability_one", "inflicts": ["stun"]},
	]},
	
	"PunchSnake" = {"name": "Punch Snake", "attack": 30, "health": 80, "type": "Monster", "mana": 1, "ability_text": null,
	"script": "res://Scripts/Abilities/Monster_PunchSnake.gd",
	"tags": ["Animal", "Snake"],
	"attacks": [
		{"name": "Small Punch", "cost": 2, "damage": 30},
		{"name": "Big Punch", "cost": 4, "damage": 100},
	]},
	
	"SonicBat" = {"name": "Sonic Bat", "attack": 15, "health": 60, "type": "Monster", "mana": 1, "ability_text": null,
	"script": "res://Scripts/Abilities/Monster_SonicBat.gd",
	"tags": ["Animal", "Bat", "Sonic", "Noise"],
	"attacks": [
		{"name": "Bite", "cost": 1, "damage": 15},
		{"name": "SonicBlast", "cost": 3, "damage": 50},
	]},

	
	#====================================Magic==================================
	"BuffTree" = {"name": "Buff Tree", "attack": 3, "health": 4, "type": "Magic", "mana": 4, "ability_text": null,
	"script": "res://Scripts/Abilities/Magic_BuffTree.gd",
	"tags": ["Plant", "Nature", "Tree"],
	"attacks": [{"name": "Attack", "cost": 0, "damage": "attack"},
		{"name": "Plant", "cost": 0, "damage": 0, "effect": "ability_one", "target": "none"},]},
	
	"Clown" = {"name": "Clown", "attack": 1, "health": 3, "type": "Magic", "mana": 1, "ability_text": null,
	"ai_role": "protected",
	"tags": ["Human", "Clown"],
	"script": "res://Scripts/Abilities/Magic_Clown.gd",
	"attacks": [
		{"name": "Pocket Sand", "cost": 0, "damage": "attack", "effect": "ability_one", "inflicts": ["blinded"]},
	]},
	
	"FlowerFields" = {"name": "Flower Fields", "attack": 10, "health": 10, "type": "Magic", "mana": 3, "ability_text": null,
	"ai_role": "defender",
	"tags": ["Plant", "Nature", "Flower"],
	"script": "res://Scripts/Abilities/Magic_FlowerFields.gd",
	"attacks": []},
	
	"BrickSidestepper" = {"name": "Brick Sidestepper", "attack": 2, "health": 6, "type": "Magic", "mana": 4, "ability_text": null,
	"ai_role": "defender",
	"tags": ["Brick"],
	"script": "res://Scripts/Abilities/Magic_BrickSidestepper.gd",
	"attacks": [{"name": "Attack", "cost": 0, "damage": "attack"},
		{"name": "Block", "cost": 0, "damage": 0, "passive": true},]},
	
	"FireAlligator" = {"name": "Fire Alligator", "attack": 1, "health": 1, "type": "Magic", "mana": 1, "ability_text": null,
	"ai_role": "protected",
	"tags": ["Animal", "Alligator", "Fire"],
	"script": "res://Scripts/Abilities/Magic_FireAlligator.gd",
	"attacks": [
		{"name": "Burn", "cost": 0, "damage": 1, "effect": "ability_one", "inflicts": ["burned"]},
	]},
	
	"Pencil" = {"name": "Pencil with an Eraser", "attack": 1, "health": 5, "type": "Magic", "mana": 4, "ability_text": null,
	"ai_role": "protected",
	"tags": ["Pencil", "Eraser"],
	"script": "res://Scripts/Abilities/Magic_Pencil.gd",
	"attacks": [
	{"name": "Attack", "cost": 0, "damage": "attack"},
	{"name": "Swap", "cost": 0, "damage": 0, "effect": "ability_one", "target": "any"},
	]},
	
	"Pebble" = {"name": "The Pebble", "attack": 1, "health": 1, "type": "Magic", "mana": 2, "ability_text": null,
	"ai_role": "defender",
	"tags": ["Rock", "Badass"],
	"script": "res://Scripts/Abilities/Magic_Pebble.gd",
	"attacks": [{"name": "Attack", "cost": 0, "damage": "attack"},]},
	
	"ShieldGirl" = {"name": "Shield Girl", "attack": 0, "health": 10, "type": "Magic", "mana": 3, "ability_text": null,
	"ai_role": "defender",
	"tags": ["Human", "Humanoid", "Shield"],
	"script": "res://Scripts/Abilities/Magic_ShieldGirl.gd",
	"attacks": []},
	
	"SkeletonCowboy" = {"name": "Skeleton Cowboy", "attack": 2, "health": 2, "type": "Magic", "mana": 3, "ability_text": null,
	"ai_role": "protected",
	"tags": ["Spooky", "Skeleton", "Cowboy"],
	"script": "res://Scripts/Abilities/Magic_SkeletonCowboy.gd",
	"attacks": [
	{"name": "Attack", "cost": 0, "damage": "attack"},
	{"name": "TieUp", "cost": 0, "damage": 0, "effect": "ability_one"},
]},
	
	"SpaceMonkey" = {"name": "Space Monkey", "attack": 2, "health": 2, "type": "Magic", "mana": 1, "ability_text": null,
	"ai_role": "defender",
	"tags": ["Animal", "Monkey", "Space"],
	"script": "res://Scripts/Abilities/Magic_SpaceMonkey.gd", "transforms_into": "SpiritBomb",
	"attacks": [
		{"name": "Attack", "cost": 0, "damage": "attack"},
	]},
	"SpiritBomb" = {"name": "Spirit Bomb", "attack": 1, "health": 1, "type": "Magic", "mana": 4, "ability_text": null,
	"script": "res://Scripts/Abilities/Magic_SpiritBomb.gd", "transforms_into": "SpaceMonkey",
	"tags": ["Bomb", "Spooky", "Spirit", "Ghost"],
	"attacks": [
		{"name": "Explode", "cost": 0, "damage": 100, "effect": "ability_one"},
	]},
	
	"SwordGuy" = {"name": "Sword Guy", "attack": 5, "health": 1, "type": "Magic", "mana": 3, "ability_text": null,
	"script": "res://Scripts/Abilities/Magic_SwordGuy.gd",
	"tags": ["Human", "Humanoid", "Sword"],
	"attacks": [{"name": "Attack", "cost": 0, "damage": "attack"},]},
	
	"ManaMonster" = {"name": "Mana Monster", "attack": 1, "health": 1, "type": "Magic", "mana": 0, "ability_text": "Use Mana",
	"script": "res://Scripts/Abilities/Magic_ManaMonster.gd","hidden": true,
	"tags": ["Mana", "Playing Card", "Token"],
	"attacks": [{"name": "Attack", "cost": 0, "damage": "attack"},
		{"name": "Mana", "cost": 0, "damage": 0, "effect": "toggle_mana", "target": "none"},]},
	
	
	
	#=====================TEST CARDS=================================
	
	"KnightDuty" = {"name": "Knightly Duty", "attack": 10, "health": 800, "type": "Monster", "mana": 1, "ability_text": null,
	"script": "res://Scripts/Abilities/Monster_KnightDuty.gd","hidden": true,
	"ai_role": "defender", "keywords": ["taunt"],
	"tags": ["Human", "Knight"],
	"attacks": [{"name": "Shield Bash", "cost": 1, "damage": 10}]},

	"KnightArcher" = {"name": "Knight Archer", "attack": 10, "health": 500, "type": "Monster", "mana": 1, "ability_text": null,
	"script": "res://Scripts/Abilities/Monster_KnightArcher.gd","hidden": true,
	"keywords": ["reach"],
	"tags": ["Human", "Knight"],
	"attacks": [{"name": "Arrow", "cost": 1, "damage": 15}]},

	"ToxicToad" = {"name": "Toxic Toad", "attack": 5, "health": 500, "type": "Monster", "mana": 1, "ability_text": null,
	"script": "res://Scripts/Abilities/Monster_ToxicToad.gd",
	"tags": ["Animal", "Frog", "Poison"],
	"attacks": [{"name": "Spit", "cost": 1, "damage": 5, "effect": "ability_one", "inflicts": ["poisoned"]}]},
	
	"QuickdrawKid" = {"name": "Quickdraw Kid", "attack": 15, "health": 400, "type": "Monster", "mana": 1, "ability_text": null,
	"keywords": ["haste"],
	"tags": ["Human", "Cowboy"],
	"attacks": [{"name": "Quick Shot", "cost": 1, "damage": 15}]},

	"SmokeWisp" = {"name": "Smoke Wisp", "attack": 10, "health": 300, "type": "Monster", "mana": 2, "ability_text": null,
	"keywords": ["invisible"],
	"tags": ["Spooky", "Ninja"],
	"attacks": [{"name": "Nip", "cost": 1, "damage": 10}]},

	"KnightJouster" = {"name": "Knight Jouster", "attack": 20, "health": 700, "type": "Monster", "mana": 3, "ability_text": null,
	"keywords": ["trample"],
	"tags": ["Human", "Knight"],
	"attacks": [{"name": "Charge", "cost": 2, "damage": 250}]},

	"SledgehammerSam" = {"name": "Sledgehammer Sam", "attack": 0, "health": 800, "type": "Monster", "mana": 3, "ability_text": null,
	"tags": ["Human", "Brawler"],
	"attacks": [{"name": "Crush", "cost": 2, "damage": 1, "crush": true}]},
	
	"SoapSuds" = {"name": "Soap Suds", "attack": 0, "health": 300, "type": "Magic", "mana": 2, "ability_text": null,
	"ai_role": "protected","hidden": true,
	"tags": ["Clean"],
	"script": "res://Scripts/Abilities/Magic_SoapSuds.gd",
	"attacks": [
		{"name": "Attack", "cost": 0, "damage": "attack"},
		{"name": "Scrub", "cost": 0, "damage": 0, "effect": "ability_one", "target": "any"},
	]},

	"CarWash" = {"name": "Car Wash", "attack": 0, "health": 300, "type": "Magic", "mana": 3, "ability_text": null,
	"ai_role": "protected","hidden": true,
	"tags": ["Clean"],
	"script": "res://Scripts/Abilities/Magic_CarWash.gd",
	"attacks": [
		{"name": "Attack", "cost": 0, "damage": "attack"},
		{"name": "Wash", "cost": 0, "damage": 0, "effect": "ability_one", "target": "none"},
	]},
	
	"ZombieToken" = {"name": "Zombie", "attack": 2, "health": 1, "type": "Magic", "mana": 0, "ability_text": null,
	"token": true,"hidden": true,
	"tags": ["Spooky", "Zombie", "Token"],
	"attacks": [{"name": "Bite", "cost": 0, "damage": "attack"}]},

	"RatToken" = {"name": "Rat", "attack": 1, "health": 1, "type": "Magic", "mana": 0, "ability_text": null,
	"token": true,"hidden": true,
	"tags": ["Animal", "Rat", "Token"],
	"attacks": [{"name": "Nibble", "cost": 0, "damage": "attack"}]},

	"Gravedigger" = {"name": "Gravedigger", "attack": 1, "health": 300, "type": "Magic", "mana": 2, "ability_text": null,
	"ai_role": "protected","hidden": true,
	"tags": ["Human", "Spooky"],
	"script": "res://Scripts/Abilities/Magic_Gravedigger.gd",
	"attacks": [
		{"name": "Attack", "cost": 0, "damage": "attack"},
		{"name": "Raise", "cost": 0, "damage": 0, "effect": "ability_one", "target": "none"},
	]},

	"Prankster" = {"name": "Prankster", "attack": 1, "health": 300, "type": "Magic", "mana": 3, "ability_text": null,
	"ai_role": "protected","hidden": true,
	"tags": ["Human"],
	"script": "res://Scripts/Abilities/Magic_Prankster.gd",
	"attacks": [
		{"name": "Attack", "cost": 0, "damage": "attack"},
		{"name": "Prank", "cost": 0, "damage": 0, "effect": "ability_one", "target": "none"},
	]},
	
	"PinataToken" = {"name": "PinataToken", "attack": 0, "health": 1, "type": "Magic", "mana": 0, "ability_text": null,
	"token": true, "hidden": true, "keywords": ["neutral"],
	"tags": ["Token", "Party"],
	"script": "res://Scripts/Abilities/Magic_Pinata.gd",
	"attacks": []},
	
	#====================Sports===================================
	"EllenBells" = [64, 1, "Sport", 4, 
	null, null],
	
	"JackMaiden" = [82, 1, "Sport", 8, 
	null, null],
	
	"JimFast" = [107, 1, "Sport", 13, 
	null, null],
	
	"JustinMcelroy" = [46, 1, "Sport", 2, 
	null, null],
	
	"MikeyJayden" = [75, 1, "Sport", 12, 
	null, null],
	
	"MikeTiredson" = [122, 1, "Sport", 6, 
	null, null],
	
	"LeonTidy" = [97, 1, "Sport", 10, 
	null, null],
	
	"LionForest" = [71, 1, "Sport", 9, 
	null, null],
	
	"RaffleNeedles" = [66, 1, "Sport", 4, 
	null, null],
	
	"TimothyJones" = [87, 1, "Sport", 7, 
	null, null],
	
	#MANA
	#Attack, Health, Type, Mana, Ability Text, Ability script
	"Clubs02" = [1, 1, "Mana", 2, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Clubs03" = [1, 1, "Mana", 3, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Clubs04" = [1, 1, "Mana", 4, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Clubs05" = [1, 1, "Mana", 5, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Clubs06" = [1, 1, "Mana", 6, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Clubs07" = [1, 1, "Mana", 7, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Clubs08" = [1, 1, "Mana", 8, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Clubs09" = [1, 1, "Mana", 9, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Clubs10" = [1, 1, "Mana", 10, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"ClubsJ" = [1, 1, "Mana", 11, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"ClubsQ" = [1, 1, "Mana", 12, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"ClubsK" = [1, 1, "Mana", 13, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"ClubsA" = [1, 1, "Mana", 14, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Diamonds02" = [1, 1, "Mana", 2, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Diamonds03" = [1, 1, "Mana", 3, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Diamonds04" = [1, 1, "Mana", 4, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Diamonds05" = [1, 1, "Mana", 5, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Diamonds06" = [1, 1, "Mana", 6, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Diamonds07" = [1, 1, "Mana", 7, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Diamonds08" = [1, 1, "Mana", 8, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Diamonds09" = [1, 1, "Mana", 9, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Diamonds10" = [1, 1, "Mana", 10, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"DiamondsJ" = [1, 1, "Mana", 11, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"DiamondsQ" = [1, 1, "Mana", 12, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"DiamondsK" = [1, 1, "Mana", 13, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"DiamondsA" = [1, 1, "Mana", 14, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Hearts02" = [1, 1, "Mana", 2, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Hearts03" = [1, 1, "Mana", 3, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Hearts04" = [1, 1, "Mana", 4, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Hearts05" = [1, 1, "Mana", 5, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Hearts06" = [1, 1, "Mana", 6, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Hearts07" = [1, 1, "Mana", 7, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Hearts08" = [1, 1, "Mana", 8, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Hearts09" = [1, 1, "Mana", 9, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Hearts10" = [1, 1, "Mana", 10, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"HeartsJ" = [1, 1, "Mana", 11, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"HeartsQ" = [1, 1, "Mana", 12, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"HeartsK" = [1, 1, "Mana", 13, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"HeartsA" = [1, 1, "Mana", 14, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Spades02" = [1, 1, "Mana", 2, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Spades03" = [1, 1, "Mana", 3, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Spades04" = [1, 1, "Mana", 4, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Spades05" = [1, 1, "Mana", 5, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Spades06" = [1, 1, "Mana", 6, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Spades07" = [1, 1, "Mana", 7, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Spades08" = [1, 1, "Mana", 8, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Spades09" = [1, 1, "Mana", 9, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"Spades10" = [1, 1, "Mana", 10, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"SpadesJ" = [1, 1, "Mana", 11, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"SpadesQ" = [1, 1, "Mana", 12, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"SpadesK" = [1, 1, "Mana", 13, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"SpadesA" = [1, 1, "Mana", 14, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"JokerBlack" = [1, 1, "Mana", 1,
	null, "res://Scripts/Abilities/Mana_Ability.gd"],
	"JokerRed" = [1, 1, "Mana", 1, 
	null, "res://Scripts/Abilities/Mana_Ability.gd"]
	}
	
static func get_card(card_name) -> Dictionary:
	var entry = CARDS[card_name]
	if entry is Dictionary:
		return entry
	return {
		"attack": entry[0],
		"health": entry[1],
		"type": entry[2],
		"mana": entry[3],
		"ability_text": entry[4],
		"script": entry[5] if entry.size() > 5 else null,
		}
	
