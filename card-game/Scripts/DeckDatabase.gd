extends Node

var manadeck = ["Clubs02", "Clubs03", "Clubs04", "Clubs05", "Clubs06", "Clubs07", "Clubs08", "Clubs09", "Clubs10", "ClubsJ", "ClubsQ", "ClubsK", "ClubsA",
"Diamonds02", "Diamonds03", "Diamonds04", "Diamonds05", "Diamonds06", "Diamonds07", "Diamonds08", "Diamonds09", "Diamonds10", "DiamondsJ", "DiamondsQ", "DiamondsK", "DiamondsA",
"Hearts02", "Hearts03", "Hearts04", "Hearts05", "Hearts06", "Hearts07", "Hearts08", "Hearts09", "Hearts10", "HeartsJ", "HeartsQ", "HeartsK", "HeartsA",
"Spades02", "Spades03", "Spades04", "Spades05", "Spades06", "Spades07", "Spades08", "Spades09", "Spades10", "SpadesJ", "SpadesQ", "SpadesK", "SpadesA"]

# DECKS
#== defaultDeck, deck1, deck2, deckClown, deckZoo, deckBats, deckSnakes, deckSpooky, deckFire, deckGarden, deckSports, deckCollector

var defaultDeck = ["ChunkyPig", "FireAlligator", "SonicBat", "JumpMan", "LiteralFire", "JimFast", "JustinMcelroy", "MushroomHands"]

var deck1 = ["SwordGuy", "SkeletonCowboy", "ShieldGirl", "FireAlligator", "BuffTree", "Dendoko", "SonicBat",
 "PunchSnake", "ChunkyPig", "LiteralFire", "JimFast", "LionForest", "EllenBells", "TimothyJones", "JustinMcelroy"]

var deck2 = ["SpaceMonkey", "Pencil", "Pebble", "BrickSidestepper", "FlowerFields", "Clown", "MushroomHands", 
"BoxPenguin", "GoblinLamb", "JumpMan", "AngryBeaver", "LeonTidy", "RaffleNeedles", "MikeTiredson", "JackMaiden", 
"MikeyJayden"]

var deckClown = ["Clown", "Clown", "Clown", "Clown", "SpaceMonkey", "SpaceMonkey", "Pebble", "Pebble",
 "FireAlligator", "AngryBeaver", "BoxPenguin", "MushroomHands", "SonicBat", "JustinMcelroy", "ChunkyPig"]

var deckZoo = ["AngryBeaver", "AngryBeaver", "BoxPenguin", "BoxPenguin", "BoxPenguin", "ChunkyPig", "ChunkyPig",
 "SonicBat", "SonicBat", "PunchSnake", "GoblinLamb", "SpaceMonkey", "SpaceMonkey", "FireAlligator", "JustinMcelroy"]

var deckBats = ["SonicBat", "SonicBat", "SonicBat", "SonicBat", "PunchSnake", "PunchSnake", "PunchSnake",
 "BoxPenguin", "LiteralFire", "EllenBells", "EllenBells", "RaffleNeedles", "RaffleNeedles", "JustinMcelroy", "ChunkyPig"]

var deckSnakes = ["PunchSnake", "PunchSnake", "PunchSnake", "PunchSnake", "SonicBat", "SonicBat", "ChunkyPig", "ChunkyPig",
 "JumpMan", "LiteralFire", "BrickSidestepper", "ShieldGirl", "SwordGuy", "EllenBells", "JustinMcelroy", "FireAlligator"]

var deckSpooky = ["SkeletonCowboy", "SkeletonCowboy", "SkeletonCowboy", "SpaceMonkey", "SpaceMonkey", "SpaceMonkey",
 "MushroomHands", "PunchSnake", "SonicBat", "ChunkyPig", "BoxPenguin", "LiteralFire", "ShieldGirl", "RaffleNeedles", "MikeTiredson"]

var deckFire = ["LiteralFire", "LiteralFire", "LiteralFire", "LiteralFire", "FireAlligator", "FireAlligator", "FireAlligator",
 "FireAlligator", "SwordGuy", "SwordGuy", "PunchSnake", "ChunkyPig", "JumpMan", "SonicBat", "BrickSidestepper"]

var deckGarden = ["FlowerFields", "FlowerFields", "FlowerFields", "Pebble", "Pebble", "BrickSidestepper", "BrickSidestepper",
 "Pencil", "Pencil", "MushroomHands", "MushroomHands", "BuffTree", "JumpMan", "ChunkyPig", "BoxPenguin"]

var deckSports = ["JustinMcelroy", "JustinMcelroy", "EllenBells", "EllenBells", "RaffleNeedles", "RaffleNeedles",
 "MikeTiredson", "MikeTiredson", "TimothyJones", "JackMaiden", "ChunkyPig", "ChunkyPig", "BoxPenguin", "JumpMan", "SonicBat"]

var deckCollector = ["LionForest", "LeonTidy", "MikeyJayden", "JimFast", "TimothyJones", "JackMaiden", "ChunkyPig", "ChunkyPig",
 "JumpMan", "JumpMan", "PunchSnake", "PunchSnake", "LiteralFire", "SonicBat", "BoxPenguin", "SwordGuy"]

var deckMonster = ["Dendoko", "SonicBat", "PunchSnake", "ChunkyPig", "LiteralFire", "MushroomHands", 
"BoxPenguin", "GoblinLamb", "JumpMan", "AngryBeaver"]

var deckMagic = ["SwordGuy", "SkeletonCowboy", "ShieldGirl", "FireAlligator", "BuffTree", "SpaceMonkey", 
"Pencil", "Pebble", "BrickSidestepper", "FlowerFields", "Clown"]


func random_deck():
	var all_decks = [deck1, deck2]
	return all_decks.pick_random().duplicate()
