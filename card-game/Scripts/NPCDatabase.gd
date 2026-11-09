class_name NPCDatabase
extends RefCounted

# One entry per opponent. These four are examples: rename them, change the decks,
# and add as many as you like.
#
#  deck        name of a deck variable in DeckDatabase.gd (or use "cards": [..] for a custom list)
# ===== defaultDeck, deck1, deck2, deckClown, deckZoo, deckBats, deckSnakes, deckSpooky, deckFire, deckGarden, deckSports, deckCollector
#  rules       ids from BoardRules.gd
# ===== "standard": No special rules.  | "sudden_death": One heart each. First hit wins. | "heavy_hearts": Ten hearts each. A long fight.
# ===== "big_hands": Both sides start with 8 cards | "Swarn": Play up to 2 monsters each turn | "Hard_Hits": Direct Attacks take 2 Hearts
# ===== "speed_duel": After 6 rounds, most hearts wins. | "no_sports": Sports cards cant be played | "no_magic": Magic cards cant be played
# ===== "boss_fight": Opponent starts with 8 hearts
#  difficulty  (the presets on BattleManager)
# ===== EASY, NORMAL, HARD
#  rewards     count: cards dropped per win; pool: {card, weight}; first_win_card: guaranteed on the
#              first win; repeatable: false = only rewards the first win
# add "first_turn": "opponent",     # "player", "opponent", or leave out for a coin toss

const NPCS = {
	"clown_kid": {
		"name": "Clown Kid", "intro": "Cheap tricks and a big red nose.",
		"dialogue": ["Ten clowns and a dream.", "player: I count four.", "...Four clowns and a dream."],
		"win_dialogue": ["Okay, okay. Take a trick. I've got more."],
		"deck": "deckClown", "rules": ["standard"], "difficulty": "EASY",
		"faction": "circus",
		"sleeve_reward": "party",
		"rewards": {"repeatable": true, "cards": ["Clown", "SpaceMonkey", "Pebble", "FireAlligator", "JustinMcelroy"]},
	},
	"Tester": {
		"name": "Tester", "intro": "Cheap tricks and a big red nose.",
		"dialogue": ["Ten clowns and a dream.", "player: I count four.", "...Four clowns and a dream."],
		"win_dialogue": ["Okay, okay. Take a trick. I've got more."],
		"deck": "testDeck", "rules": ["standard"], "difficulty": "EASY",
		"faction": "circus",
		"sleeve_reward": "party",
		"rewards": {"repeatable": true, "cards": ["Clown", "SpaceMonkey", "Pebble", "FireAlligator", "JustinMcelroy"]},
	},
	"zoo_keeper": {
		"name": "Zoo Keeper", "intro": "Everything here bites. Probably.",
		"dialogue": ["Welcome to the zoo!", "player: Is that a penguin in a box?", "Don't ask. He won't tell you either."],
		"win_dialogue": ["You handled them better than I do."],
		"deck": "deckZoo", "rules": ["standard"], "difficulty": "EASY",
		"rewards": {"repeatable": true, "cards": ["AngryBeaver", "BoxPenguin", "GoblinLamb", "ChunkyPig", "SonicBat"]},
	},
	"bat_trainer": {
		"name": "Bat Trainer", "intro": "One hit decides it.",
		"dialogue": ["Shh. Do you hear that?", "player: Hear what?", "The sound of one hit ending the match."],
		"win_dialogue": ["Impressive. You hit first."],
		"decks": ["deckBats", "deckSnakes"], "rules": ["sudden_death"], "difficulty": "NORMAL",
		"rewards": {"repeatable": true, "cards": ["PunchSnake", "EllenBells", "RaffleNeedles", "SonicBat", "JustinMcelroy"]},
	},
	"ghost_host": {
		"name": "Ghost Host", "intro": "Direct hits hurt twice as much here.",
		"dialogue": ["Welcome, welcome. Mind the draft.", "player: Why is it so cold?", "Oh, that's just the guests."],
		"win_dialogue": ["You may haunt my halls any time."],
		"deck": "deckSpooky", "rules": ["hard_hits"], "difficulty": "NORMAL",
		"rewards": {"repeatable": true, "cards": ["Dendoko", "SkeletonCowboy", "LiteralFire", "FireAlligator", "SonicBat"]},
	},
	"fire_chief": {
		"name": "Fire Chief", "intro": "No sports. Big hands.",
		"dialogue": ["Fire safety is no game.", "player: Then why are we playing one?", "Training exercise. Now sit down."],
		"win_dialogue": ["Consider yourself certified."],
		"deck": "deckFire", "rules": ["no_sports", "big_hands"], "difficulty": "NORMAL",
		"board": "cluttered",
		"faction": "fire_dept",
		"sleeve_reward": "flames",
		"rewards": {"repeatable": true, "cards": ["ShieldGirl", "SwordGuy", "MushroomHands", "LiteralFire", "FireAlligator"]},
	},
	"gardener": {
		"name": "The Gardener", "intro": "Two monsters a turn. Everything grows.",
		"dialogue": ["Mind the flowers.", "player: Is that rock a card too?", "Everything here is a card. Even the rock."],
		"win_dialogue": ["Well pruned."],
		"deck": "deckGarden", "rules": ["swarm"], "difficulty": "NORMAL",
		"rewards": {"repeatable": true, "cards": ["Pencil", "BrickSidestepper", "FlowerFields", "BuffTree", "JumpMan"]},
	},
	"sports_coach": {
		"name": "Coach", "intro": "Six rounds. Most hearts wins.",
		"dialogue": ["Drop and give me six rounds!", "player: Six rounds of what?", "Cards. Always cards."],
		"win_dialogue": ["Not bad, rookie. Not bad at all."],
		"deck": "deckSports", "rules": ["speed_duel"], "difficulty": "HARD",
		"rewards": {"repeatable": true, "cards": ["MikeTiredson", "TimothyJones", "JackMaiden", "JimFast", "JustinMcelroy"]},
	},
	"the_collector": {
		"name": "The Collector", "intro": "Ten hearts. Two monsters a turn.",
		"dialogue": ["I've been waiting for someone with a real collection.", "player: I'm working on it.", "Then let's see how far along you are."],
		"win_dialogue": ["Hm. Perhaps you'll complete the set after all."],
		"decks": ["deck2", "deckCollector"], "rules": ["heavy_hearts", "swarm"], "difficulty": "HARD",
		"boards": ["felt", "cluttered"],
		"sleeve": "gold",
		"sleeve_reward": "gold",
		"rewards": {"repeatable": true, "cards": ["LionForest", "LeonTidy", "MikeyJayden", "JimFast", "BuffTree"]},
	},
	"monster_mash": {
		"name": "Monster Man", "intro": "Who needs all these cards, Only Monsters!.",
		"dialogue": ["MONSTERS ONLY.", "player: but i have so many cards already", "NO! MONSTERS ONLY!"],
		"win_dialogue": ["Doesnt count, not until you've Collected them all."],
		"decks": ["deckMonsters"], "rules": ["no_magic", "no_sports"], "difficulty": "HARD",
		"boards": ["felt", "cluttered"],
		"sleeve": "gold",
		"sleeve_reward": "gold",
		"rewards": {"repeatable": true, "cards": ["Dendoko", "SonicBat", "PunchSnake", "ChunkyPig", "LiteralFire", "MushroomHands",  "BoxPenguin", "GoblinLamb", "JumpMan", "AngryBeaver"]},
	},
	"wizard": {
		"name": "Wizard", "intro": "Magic only fool.",
		"dialogue": ["Wanna see a trick?", "player: uh yeah, sure", "im about to make your win streak disapear"],
		"win_dialogue": ["fine, you win, get lost"],
		"decks": ["deckMagic"], "rules": ["no_monsters", "no_sports"], "difficulty": "HARD",
		"boards": ["felt", "cluttered"],
		"sleeve": "party",
		"sleeve_reward": "gold",
		"rewards": {"repeatable": true, "cards": ["SwordGuy", "SkeletonCowboy", "ShieldGirl", "FireAlligator", "BuffTree", "SpaceMonkey", "Pencil", "Pebble", "BrickSidestepper", "FlowerFields", "Clown"]},
	},
}
const FACTIONS = {
	"fire_dept": {"name": "Fire Department", "sleeve": "flames"},
	"circus": {"name": "Circus Troupe", "sleeve": "party"},
}
