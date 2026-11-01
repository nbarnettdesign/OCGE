extends StaticBody2D

# An overworld character. Walk up and press E to talk.
# If npc_id matches an entry in NPCDatabase.gd they offer a battle using that entry's deck,
# rules and difficulty. Leave npc_id empty for someone who just talks, or tick opens_binder
# for a desk/chest that opens the deck builder.

const DialogueScene = preload("res://Scenes/dialogue_box.tscn")

@export var npc_id = ""                         # key in NPCDatabase.NPCS
@export var display_name = ""                   # overrides the database name
@export var talk_lines: Array[String] = []      # what a non-battle NPC says
@export var can_rematch = true                  # offer another battle after you've won
@export var opens_binder = false                # talk, then open the binder
@export var prompt_text = "E"
@export var sprite_texture: Texture2D  
@export var sprite_size = Vector2(32, 48) 
@export var win_lines: Array[String] = []       # what a beaten NPC says (empty = use the database)
@export var talk_portrait: Texture2D  

@onready var zone = $InteractZone
@onready var prompt = $Prompt

var player_near = null
var talking = false


func _ready():
	_ensure_interact_action()
	prompt.text = prompt_text
	prompt.visible = false
	zone.body_entered.connect(_on_entered)
	zone.body_exited.connect(_on_exited)
	zone.area_entered.connect(_on_entered)
	zone.area_exited.connect(_on_exited)
	if sprite_texture:
		$Sprite2D.texture = sprite_texture
	_fit_to_sprite()

func _fit_to_sprite():
	var sprite = $Sprite2D
	if sprite.texture == null:
		return
	var tex_size = sprite.texture.get_size()
	if sprite_size != Vector2.ZERO:
		var factor = min(sprite_size.x / tex_size.x, sprite_size.y / tex_size.y)
		sprite.scale = Vector2(factor, factor)
	var size = tex_size * sprite.scale
	# the body collider sits at the feet, as wide as the sprite
	var body = $CollisionShape2D
	body.shape = body.shape.duplicate()          # so other NPCs don't share the change
	body.shape.size = Vector2(size.x * 0.8, 16)
	body.position = Vector2(0, size.y / 2.0 - 8)
	# the E prompt floats above the head
	prompt.position = Vector2(-prompt.size.x / 2.0, -size.y / 2.0 - 32)
	
func _ensure_interact_action():
	if InputMap.has_action("interact"):
		return
	InputMap.add_action("interact")
	var key = InputEventKey.new()
	key.physical_keycode = KEY_E
	InputMap.action_add_event("interact", key)


func _data():
	return NPCDatabase.NPCS.get(npc_id, {})


func _speaker():
	if display_name != "":
		return display_name
	return _data().get("name", String(name))


func _on_entered(thing):
	if thing.is_in_group("player"):
		player_near = thing
		prompt.visible = not talking


func _on_exited(thing):
	if thing == player_near:
		player_near = null
		prompt.visible = false

func _talk_texture(box):
	if talk_portrait:
		return talk_portrait
	return box.sprite_texture_of($Sprite2D)  

func _unhandled_input(event):
	if player_near and not talking and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		talk()


func talk():
	talking = true
	prompt.visible = false
	var box = DialogueScene.instantiate()
	get_tree().current_scene.add_child(box)
	var data = _data()
	var portrait = _talk_texture(box)

	# someone who only talks (or a binder desk)
	if data.is_empty():
		var lines = talk_lines if not talk_lines.is_empty() else ["..."]
		await box.open(_speaker(), lines, [], portrait)
		if opens_binder and player_near:
			_remember_position()
			GameState.go_to_binder("overworld")
		_done()
		return

	# a fighter
	var won = GameState.defeated.has(npc_id)
	var lines = []
	if won:
		if not win_lines.is_empty():
			lines.append_array(win_lines)
		else:
			lines.append_array(data.get("win_dialogue", ["You beat me fair and square."]))
		if not can_rematch:
			await box.open(_speaker(), lines, [], portrait)
			_done()
			return
		lines.append("Fancy another match?")
	else:
		if not talk_lines.is_empty():
			lines.append_array(talk_lines)
		else:
			lines.append_array(data.get("dialogue", [data.get("intro", "Care for a match?")]))
	await box.open(_speaker(), lines, [], portrait)

	# after the talking, go to the duel screen or straight into the battle
	if player_near:
		var screen = get_tree().get_first_node_in_group("battle_screen")
		if screen:
			screen.open(self)
		else:
			_remember_position()
			GameState.start_battle(npc_id)
	_done()



func _remember_position():
	GameState.remember_overworld(get_tree().current_scene.scene_file_path, player_near.global_position)


func _done():
	talking = false
	prompt.visible = player_near != null
