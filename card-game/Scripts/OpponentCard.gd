extends Node2D

var card_type
var starting_position
var hand_position
var card_slot_card_is_in
var attack
var health
var mana
var ability
var defeated = false
var ability_script
var max_health
var statuses = {}
var just_played = false
var attacks = []
var selected_attack = 0
const ENERGY_ICON = preload("res://Scenes/energy_icon.tscn")

@export var energy_icon_gap = 4.0   # space between icons until they start overlapping

var attached_mana = 0:
	set(value):
		attached_mana = value
		update_energy_icons()


func update_energy_icons():
	var holder = get_node_or_null("EnergyIcons")
	if not holder:
		return

	# add or remove icons to match the count
	while holder.get_child_count() > attached_mana:
		var extra = holder.get_child(holder.get_child_count() - 1)
		holder.remove_child(extra)
		extra.queue_free()
	while holder.get_child_count() < attached_mana:
		holder.add_child(ENERGY_ICON.instantiate())

	var count = holder.get_child_count()
	if count == 0:
		return

	# normal spacing, squeezed only if the stack would run past the container
	var icon_h = holder.get_child(0).custom_minimum_size.y
	var step = icon_h + energy_icon_gap
	if count > 1 and (count - 1) * step + icon_h > holder.size.y:
		step = (holder.size.y - icon_h) / (count - 1)

	for i in range(count):
		var icon = holder.get_child(i)
		icon.size = icon.custom_minimum_size
		icon.position = Vector2(0, i * step)
