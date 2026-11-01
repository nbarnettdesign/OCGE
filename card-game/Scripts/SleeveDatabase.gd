class_name SleeveDatabase
extends RefCounted

# texture = the card back picture. Make every sleeve the same pixel size as your current deck back
# wild - it will show up randomly in the wild (if npc has no sleeve assigned)
const SLEEVES = {
	"default": {"name": "Classic", "texture": "res://CardSprites/Cards_back.png", "wild": true},
	"party": {"name": "Party Time", "texture": "res://CardSprites/Sleeves/party.png", "wild": false},
	"flames": {"name": "Flames", "texture": "res://CardSprites/Sleeves/flames.png", "wild": false},
	"gold": {"name": "Gold Leaf", "texture": "res://CardSprites/Sleeves/gold.png", "wild": false},
}
