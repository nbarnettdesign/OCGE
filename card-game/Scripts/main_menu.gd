extends Control

# The main menu: Continue, Saves (3 slots you can load or delete), New Game (pick a name), Quit.
# All the visuals live in main_menu.tscn and save_slot_row.tscn.

@onready var main_panel = %MainPanel
@onready var continue_button = %ContinueButton
@onready var saves_button = %SavesButton
@onready var new_game_button = %NewGameButton
@onready var quit_button = %QuitButton

@onready var saves_panel = %SavesPanel
@onready var slot_list = %SlotList
@onready var saves_back_button = %SavesBackButton

@onready var new_panel = %NewGamePanel
@onready var name_edit = %NameEdit
@onready var slot_menu = %SlotMenu
@onready var warning_label = %WarningLabel
@onready var start_button = %StartButton
@onready var new_back_button = %NewBackButton

@onready var confirm = %ConfirmDialog

var pending = Callable()       # what to do if the confirm dialog is accepted


func _ready():
	continue_button.pressed.connect(_on_continue)
	saves_button.pressed.connect(func(): _show(saves_panel))
	new_game_button.pressed.connect(_on_new_game)
	quit_button.pressed.connect(func(): get_tree().quit())
	saves_back_button.pressed.connect(func(): _show(main_panel))
	new_back_button.pressed.connect(func(): _show(main_panel))
	start_button.pressed.connect(_on_start)
	name_edit.text_submitted.connect(func(_text): _on_start())
	slot_menu.item_selected.connect(func(_i): _update_warning())
	confirm.confirmed.connect(_on_confirmed)
	for row in slot_list.get_children():
		row.load_pressed.connect(_on_load_slot)
		row.delete_pressed.connect(_on_delete_slot)
	_refresh()
	_show(main_panel)


func _show(panel):
	for p in [main_panel, saves_panel, new_panel]:
		p.visible = p == panel


func _refresh():
	continue_button.disabled = GameState.last_slot() == 0
	var rows = slot_list.get_children()
	for i in range(rows.size()):
		rows[i].setup(i + 1, GameState.slot_summary(i + 1))
	# the slot picker for a new game
	slot_menu.clear()
	var first_empty = -1
	for slot in range(1, GameState.SLOT_COUNT + 1):
		var summary = GameState.slot_summary(slot)
		var label = "empty" if summary.is_empty() else summary["name"]
		slot_menu.add_item("Slot %d - %s" % [slot, label])
		if summary.is_empty() and first_empty < 0:
			first_empty = slot - 1
	slot_menu.select(max(first_empty, 0))
	_update_warning()


func _update_warning():
	var slot = slot_menu.selected + 1
	var summary = GameState.slot_summary(slot)
	if summary.is_empty():
		warning_label.text = ""
	else:
		warning_label.text = "This will replace %s's save in slot %d." % [summary["name"], slot]


# ---------- main buttons ----------

func _on_continue():
	var slot = GameState.last_slot()
	if slot > 0 and GameState.load_slot(slot):
		GameState.start_game()


func _on_new_game():
	name_edit.text = ""
	_refresh()
	_show(new_panel)
	name_edit.grab_focus()


# ---------- saves list ----------

func _on_load_slot(slot):
	if GameState.load_slot(slot):
		GameState.start_game()


func _on_delete_slot(slot):
	var summary = GameState.slot_summary(slot)
	_ask("Delete %s's save in slot %d?\nThis can't be undone." % [summary["name"], slot],
		func():
			GameState.delete_slot(slot)
			_refresh())


# ---------- new game ----------

func _on_start():
	var new_name = name_edit.text.strip_edges()
	if new_name == "":
		warning_label.text = "Enter a name first."
		name_edit.grab_focus()
		return
	var slot = slot_menu.selected + 1
	var existing = GameState.slot_summary(slot)
	if existing.is_empty():
		_begin(slot, new_name)
	else:
		_ask("Replace %s's save in slot %d with a new game?" % [existing["name"], slot],
			func(): _begin(slot, new_name))


func _begin(slot, new_name):
	GameState.new_game_in_slot(slot, new_name)
	GameState.start_game()


# ---------- confirm dialog ----------

func _ask(text, action):
	pending = action
	confirm.dialog_text = text
	confirm.popup_centered()


func _on_confirmed():
	if pending.is_valid():
		pending.call()
	pending = Callable()
