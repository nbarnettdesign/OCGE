extends CanvasLayer

# A simple dialogue box. Created by npc.gd; pauses the game while it's open.
#   var choice = await box.open("Name", ["line one", "line two"], ["Yes", "No"])
# choice is the index of the button pressed, or -1 when there were no choices.

signal finished(choice)

@export var chars_per_second = 60.0

@onready var speaker_label = %SpeakerLabel
@onready var text_label = %TextLabel
@onready var hint_label = %HintLabel
@onready var choice_row = %ChoiceRow
@onready var player_portrait = %PlayerPortrait
@onready var npc_portrait = %NPCPortrait

const PLAYER_PREFIX = "player:"
const DIM = Color(0.45, 0.45, 0.45)


var npc_name = ""
var speakers = []                                # one bool per line: true = the player speaks



var lines = []
var choices = []
var line_index = 0
var opened_at = 0
var typing = false
var waiting_for_choice = false
var tween = null


func open(speaker, new_lines, new_choices = [], npc_texture = null):
	npc_name = speaker
	lines = []
	speakers = []
	for line in new_lines:
		var text = str(line).replace("{player}", GameState.player_name)
		var from_player = text.to_lower().begins_with(PLAYER_PREFIX)
		if from_player:
			text = text.substr(PLAYER_PREFIX.length()).strip_edges()
		lines.append(text)
		speakers.append(from_player)
	choices = new_choices
	line_index = 0
	choice_row.visible = false
	hint_label.visible = false
	_set_portrait(npc_portrait, npc_texture)
	_set_portrait(player_portrait, _find_player_texture())
	opened_at = Time.get_ticks_msec()
	get_tree().paused = true
	_show_line()
	var result = await finished
	get_tree().paused = false
	queue_free()
	return result


func _show_line():
	var from_player = speakers[line_index]
	speaker_label.text = GameState.player_name if from_player else npc_name
	_highlight(from_player)
	text_label.text = lines[line_index]
	text_label.visible_characters = 0
	hint_label.visible = false
	typing = true
	if tween:
		tween.kill()
	var total = text_label.get_total_character_count()
	tween = create_tween()
	tween.tween_property(text_label, "visible_characters", total, max(0.05, total / chars_per_second))
	tween.finished.connect(_on_line_typed)


func _on_line_typed():
	typing = false
	text_label.visible_characters = -1
	if line_index >= lines.size() - 1 and not choices.is_empty():
		_show_choices()
	else:
		hint_label.visible = true


func _show_choices():
	_highlight(true)
	waiting_for_choice = true
	for child in choice_row.get_children():
		child.queue_free()
	for i in range(choices.size()):
		var button = Button.new()
		button.text = choices[i]
		button.custom_minimum_size = Vector2(160, 44)
		button.pressed.connect(_choose.bind(i))
		choice_row.add_child(button)
	choice_row.visible = true
	choice_row.get_child(0).grab_focus()


func _choose(index):
	waiting_for_choice = false
	finished.emit(index)


func _advance():
	if waiting_for_choice:
		return
	if typing:
		tween.kill()
		_on_line_typed()      # finish typing the line
		return
	if line_index < lines.size() - 1:
		line_index += 1
		_show_line()
	else:
		finished.emit(-1)


func _input(event):
	# ignore the key press that opened the box
	if Time.get_ticks_msec() - opened_at < 200 or waiting_for_choice:
		return
	var click = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if click or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_advance()

func sprite_texture_of(sprite):
	if sprite == null or sprite.texture == null:
		return null
	if sprite is Sprite2D and sprite.hframes * sprite.vframes > 1:     # sprite sheet: grab the current frame
		var tex = AtlasTexture.new()
		tex.atlas = sprite.texture
		var cell = sprite.texture.get_size() / Vector2(sprite.hframes, sprite.vframes)
		var cell_pos = Vector2(sprite.frame % sprite.hframes, int(sprite.frame / sprite.hframes))
		tex.region = Rect2(cell_pos * cell, cell)
		return tex
	return sprite.texture

func _set_portrait(portrait, texture):
	portrait.texture = texture
	portrait.visible = texture != null
	
func _find_player_texture():
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	if player.get("talk_portrait"):                  # the dedicated talking sprite
		return player.talk_portrait
	var sprite = player.find_child("Sprite2D", true, false)      # fallback: the map sprite
	if sprite:
		return sprite_texture_of(sprite)
	var anim = player.find_child("AnimatedSprite2D", true, false)
	if anim and anim.sprite_frames:
		return anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	return null


func _highlight(player_talking):
	if player_portrait:
		player_portrait.modulate = Color.WHITE if player_talking else DIM
	if npc_portrait:
		npc_portrait.modulate = DIM if player_talking else Color.WHITE
