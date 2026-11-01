extends PanelContainer

# One save slot in the main menu's Saves list. Style it in save_slot_row.tscn.

signal load_pressed(slot)
signal delete_pressed(slot)

@onready var info_label = %InfoLabel
@onready var load_button = %LoadButton
@onready var delete_button = %DeleteButton

var slot = 0


func _ready():
	load_button.pressed.connect(func(): load_pressed.emit(slot))
	delete_button.pressed.connect(func(): delete_pressed.emit(slot))


func setup(new_slot, summary):
	slot = new_slot
	var empty = summary.is_empty()
	load_button.disabled = empty
	delete_button.disabled = empty
	if empty:
		info_label.text = "Slot %d\nEmpty" % slot
		return
	var bias = Time.get_time_zone_from_system()["bias"]
	var when = Time.get_datetime_string_from_unix_time(int(summary["saved_at"]) + bias * 60)
	info_label.text = "Slot %d - %s\n%d cards, %d opponents beaten\nLast saved %s" % [
		slot, summary["name"], summary["cards"], summary["defeated"], when.replace("T", " ")]
