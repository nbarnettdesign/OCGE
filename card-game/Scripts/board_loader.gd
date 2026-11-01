extends Node

# Optional: assign these in the Inspector. If they're empty the script looks for them itself.
@export var table_node: CanvasItem
@export var player_deck_sprite: Sprite2D
@export var opponent_deck_sprite: Sprite2D


func _ready():
	var root = get_parent()
	if table_node == null:
		table_node = _find_table(root)
	if player_deck_sprite == null:
		player_deck_sprite = root.get_node_or_null("Deck/Sprite2D")
	if opponent_deck_sprite == null:
		opponent_deck_sprite = root.get_node_or_null("OpponentDeck/Deck/Sprite2D")
	_apply_board(GameState.board_for_battle())
	_apply_sleeve(player_deck_sprite, GameState.equipped_sleeve)
	_apply_sleeve(opponent_deck_sprite, GameState.npc_sleeve())


func _find_table(root):
	for child in root.get_children():
		if str(child.name).to_lower() in ["table", "tabletop", "background", "bg", "backdrop", "board"]:
			return child
	for child in root.get_children():             # otherwise the first picture directly under the root
		if child is Sprite2D or child is TextureRect:
			return child
	return null

func _apply_board(board):
	if board.is_empty():
		return
	var layout_path = board.get("layout", "")
	if layout_path != "" and ResourceLoader.exists(layout_path):
		_apply_layout(load(layout_path).instantiate())
	var table_path = board.get("table", "")
	if table_path != "" and table_node and ResourceLoader.exists(table_path):
		table_node.set("texture", load(table_path))


# reads slot positions (and an optional "Table" sprite) from a layout scene, then throws it away
func _apply_layout(layout):
	var slots = get_parent().get_node_or_null("CardSlots")
	for item in layout.get_children():
		if item.name == "Table":
			if table_node and item.get("texture"):
				table_node.set("texture", item.texture)
		elif slots and item is Node2D:
			var slot = slots.get_node_or_null(str(item.name))
			if slot and slot is Node2D:
				slot.position = item.position
	layout.free()


func _apply_sleeve(sprite, id):
	if sprite == null or not SleeveDatabase.SLEEVES.has(id):
		return
	var path = SleeveDatabase.SLEEVES[id].get("texture", "")
	if path != "" and ResourceLoader.exists(path):
		sprite.texture = load(path)
	elif path != "":
		#print("BoardLoader: sleeve image not found: ", path)
		return
