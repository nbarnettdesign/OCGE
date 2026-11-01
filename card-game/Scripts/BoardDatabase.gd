class_name BoardDatabase
extends RefCounted

# table  = tabletop picture (same size as your current table). "" keeps the scene's own table
# layout = optional scene that rearranges the slots. "" keeps the main scene's layout
# random = true: can be picked at random for NPCs that don't choose a board
const BOARDS = {
	"classic": {"name": "Classic", "table": "", "layout": "", "random": true},
	"oak": {"name": "Oak Table", "table": "res://Boards/table_oak.png", "layout": "", "random": true},
	"felt": {"name": "Green Felt", "table": "res://Boards/table_felt.png", "layout": "", "random": true},
	"cluttered": {"name": "Cluttered Desk", "table": "res://Boards/table_desk.png",
		"layout": "res://Scenes/Boards/board_cluttered.tscn", "random": false},
}
