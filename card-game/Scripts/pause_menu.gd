extends CanvasLayer

@export var in_battle = false          # tick this on the copy in the battle scene

@onready var main_page = %MainPage
@onready var settings_page = %SettingsPage
@onready var save_label = %SaveLabel
@onready var volume_slider = %VolumeSlider
@onready var fullscreen_check = %FullscreenCheck
@onready var confirm_dialog = %ConfirmDialog
@onready var music_slider = %MusicSlider
@onready var sfx_slider = %SfxSlider

var confirm_action = ""


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	%ResumeButton.pressed.connect(close)
	%SaveButton.pressed.connect(_on_save)
	%SettingsButton.pressed.connect(_show_settings.bind(true))
	%BackButton.pressed.connect(_show_settings.bind(false))
	%QuitMenuButton.pressed.connect(_ask.bind("menu"))
	%QuitDesktopButton.pressed.connect(_ask.bind("desktop"))
	confirm_dialog.confirmed.connect(_on_confirmed)
	music_slider.value = GameState.settings["music_volume"] * 100.0
	sfx_slider.value = GameState.settings["sfx_volume"] * 100.0
	music_slider.value_changed.connect(_on_slider.bind("music_volume"))
	sfx_slider.value_changed.connect(_on_slider.bind("sfx_volume"))
	volume_slider.value = GameState.settings["volume"] * 100.0
	fullscreen_check.button_pressed = GameState.settings["fullscreen"]
	volume_slider.value_changed.connect(_on_volume)
	fullscreen_check.toggled.connect(_on_fullscreen)

func _on_slider(value, key):
	GameState.settings[key] = value / 100.0
	GameState.apply_settings()
	GameState.save_settings()

func _unhandled_input(event):
	if not event.is_action_pressed("ui_cancel"):
		return
	if visible:
		if settings_page.visible:
			_show_settings(false)
		else:
			close()
	elif not get_tree().paused:            # dialogue, game over and the graveyard already pause the game
		open()
	get_viewport().set_input_as_handled()


func open():
	get_tree().paused = true
	visible = true
	save_label.text = ""
	_show_settings(false)


func close():
	visible = false
	get_tree().paused = false


func _show_settings(to_settings):
	main_page.visible = not to_settings
	settings_page.visible = to_settings
	if to_settings:
		volume_slider.grab_focus()
	else:
		%ResumeButton.grab_focus()


func _on_save():
	if GameState.current_slot == 0:
		save_label.text = "Start from the main menu to save."
		return
	GameState.save_game()
	save_label.text = "Game saved."


func _ask(action):
	confirm_action = action
	var where = "return to the main menu" if action == "menu" else "quit the game"
	if in_battle:
		confirm_dialog.dialog_text = "Leave this battle and %s?\nIt counts as a loss (no rewards). Your progress is saved." % where
	else:
		confirm_dialog.dialog_text = "Save and %s?" % where
	confirm_dialog.popup_centered()


func _on_confirmed():
	GameState.save_game()
	if in_battle:
		var battle = get_parent().get_node_or_null("BattleManager")
		if battle:
			battle.game_over = true        # stops the AI mid-turn
	if confirm_action == "menu":
		GameState.go_to_menu()
	else:
		get_tree().quit()


func _on_volume(value):
	GameState.settings["volume"] = value / 100.0
	GameState.apply_settings()
	GameState.save_settings()


func _on_fullscreen(on):
	GameState.settings["fullscreen"] = on
	GameState.apply_settings()
	GameState.save_settings()
