extends Node2D

# Sits on a card as a child named "Effects". Shows particles for each active effect, and a list
# of them while the card is highlighted. Drop a scene named <status>.tscn into effect_folder
# (e.g. burned.tscn) to replace that effect's default particles with your own.

@export var card_size = Vector2(120, 170)          # the card's on-screen size, so particles cover it
@export var card_offset = Vector2.ZERO             # shift if the card's origin isn't its centre
@export var effect_folder = "res://Scenes/Effects/"

const HIDDEN = ["original_stats"]
const EFFECTS = {
	"burned": {"name": "Burned", "text": "takes double damage", "color": Color(2.0, 0.45, 0.1), "rise": true},
	"blinded": {"name": "Blinded", "text": "attacks miss half the time", "color": Color(0.85, 0.85, 0.95), "rise": false},
	"tied_to": {"name": "Tied", "text": "can't attack while tied to another card", "color": Color(0.4, 0.7, 1.0), "rise": false},
	"cant_attack": {"name": "Can't attack", "text": "can't attack this turn", "color": Color(0.7, 0.5, 0.9), "rise": false},
	"never_attacks": {"name": "Never attacks", "text": "this card never attacks", "particles": false},
	"haste": {"name": "Haste", "text": "can attack the turn it's played", "color": Color(1.0, 0.9, 0.3), "rise": true},
	"immune_to_attacks": {"name": "Immune to attacks", "text": "attacks do nothing to it", "color": Color(1.0, 0.85, 0.4), "rise": true},
	"only_hurt_by_attacks": {"name": "Only hurt by attacks", "text": "magic and sports do nothing to it", "color": Color(0.9, 0.3, 0.3), "rise": true},
	"ignores_damage": {"name": "Ignores damage", "text": "takes no damage", "color": Color(1, 1, 1), "rise": true},
	"returns_to_hand": {"name": "Returns to hand", "text": "goes back to the hand when destroyed", "color": Color(0.4, 1.0, 0.6), "rise": true},
	"swapped": {"name": "Swapped", "text": "attack and health are swapped", "color": Color(1.0, 0.5, 0.9), "rise": false},
	"_just_played": {"name": "Just played", "text": "can't attack yet", "particles": false},
	"taunt": {"name": "Taunt", "text": "must be attacked first", "particles": false},
	"reach": {"name": "Reach", "text": "can attack the back row", "particles": false},
	"poisoned": {"name": "Poisoned", "text": "loses 1/8 of its health each turn", "color": Color(0.5, 0.9, 0.2), "rise": true},
	"invisible": {"name": "Invisible", "text": "can't be targeted by attacks", "color": Color(0.8, 0.9, 1.0), "rise": true},
	"trample": {"name": "Trample", "text": "excess damage hits the card behind", "particles": false},
}

@onready var card = get_parent()
@onready var fx = $Fx
@onready var list_panel = %EffectList
@onready var list_label = %EffectLabel

var active = []
var last_signature = "?"
var hovered = false


func _ready():
	list_panel.visible = false


func _process(_delta):
	var keys = _active_keys()
	var signature = ",".join(keys)
	if signature == last_signature:
		return
	last_signature = signature
	active = keys
	_rebuild()


func set_hovered(on):
	hovered = on
	_update_list()


func _active_keys():
	var keys = []
	if card.get("statuses") == null or not card.card_slot_card_is_in:
		return keys
	for key in card.statuses:
		if key in HIDDEN:
			continue
		var value = card.statuses[key]
		if value is bool and not value:
			continue
		if value is Array and value.is_empty():
			continue
		keys.append(key)
	for key in card.get_meta("keywords", []):
		if key not in keys:
			keys.append(key)
	var hasty = card.statuses.has("haste") or "haste" in card.get_meta("keywords", [])
	if card.just_played and not hasty:
		keys.append("_just_played")
	return keys


func _info(key):
	return EFFECTS.get(key, {"name": key.capitalize(), "text": ""})


func _rebuild():
	for child in fx.get_children():
		child.queue_free()
	for key in active:
		var info = _info(key)
		if info.get("particles", true):
			fx.add_child(_make_effect(key, info))
	_update_list()


func _make_effect(key, info):
	var path = effect_folder + key + ".tscn"
	if ResourceLoader.exists(path):
		return load(path).instantiate()
	return _default_particles(info.get("color", Color.WHITE), info.get("rise", true))


func _default_particles(color, rise):
	var p = CPUParticles2D.new()
	p.position = card_offset
	p.local_coords = true                          # follows the card as it moves and scales
	p.amount = 14
	p.lifetime = 1.2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = card_size / 2.0
	p.direction = Vector2(0, -1) if rise else Vector2(0, 1)
	p.spread = 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 35.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	var fade = Gradient.new()
	fade.set_color(0, Color(color.r, color.g, color.b, 0.9))
	fade.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = fade
	return p


func _update_list():
	var lines = []
	for key in active:
		var info = _info(key)
		lines.append("%s: %s" % [info["name"], info["text"]] if info["text"] != "" else info["name"])
	list_label.text = "\n".join(lines)
	list_panel.visible = hovered and not lines.is_empty()
