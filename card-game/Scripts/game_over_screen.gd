extends Node

# Attach this to your GameOver node and assign the nodes below in the inspector.
#
# Won:  shows "Get my rewards" (or "Continue" if the battle has no reward) and nothing else.
# Lost: shows Battle Again, a Change Deck dropdown, the Binder button and Give Up.

const RewardPickerScene = preload("res://Scenes/reward_picker.tscn")

@export var message_label: Label          # your existing Message label
@export var rewards_button: Button        # "Get my rewards" / "Continue"   (win only)
@export var play_again_button: Button     # "Battle Again"                  (loss only)
@export var deck_menu: OptionButton       # change deck                     (loss only)
@export var binder_button: Button         #                                 (loss only)
@export var give_up_button: Button        #                                 (loss only)
@export var error_label: Label            # optional: why the equipped deck can't be used
@export var bad_color = Color(1.0, 0.3, 0.3)

var result = ""
var title = ""
var reason = ""
var reward_choices = []


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	rewards_button.pressed.connect(_on_rewards)
	play_again_button.pressed.connect(_on_play_again)
	deck_menu.item_selected.connect(_on_deck_selected)
	binder_button.pressed.connect(_on_binder)
	give_up_button.pressed.connect(_on_give_up)


func show_result(new_result, new_title, new_reason):
	result = new_result
	title = new_title
	reason = new_reason
	var won = result == "player"
	var sleeve_name = GameState.unlock_npc_sleeve() if won else ""
	message_label.text = title + "\n" + reason
	if sleeve_name != "":
		message_label.text += "\nNew card sleeve unlocked: " + sleeve_name
	reward_choices = GameState.reward_options() if won else []
	rewards_button.visible = won
	rewards_button.disabled = false
	rewards_button.text = "Get my rewards" if not reward_choices.is_empty() else "Continue"
	for c in [play_again_button, deck_menu, binder_button, give_up_button]:
		c.visible = not won
	if error_label:
		error_label.visible = not won
	if not won:
		_refresh_decks()
	set("visible", true)


# ---------- won ----------

func _on_rewards():
	rewards_button.disabled = true
	if reward_choices.is_empty():
		GameState.mark_defeated()
	else:
		var picker = RewardPickerScene.instantiate()
		get_tree().current_scene.add_child(picker)
		var picked = await picker.choose(reward_choices)
		GameState.claim_reward(picked)
	GameState.return_to_overworld()


# ---------- lost ----------

func _refresh_decks():
	deck_menu.clear()
	var names = GameState.decks.keys()
	names.sort()
	var equipped_index = -1
	if not GameState.decks.has(GameState.selected_deck):
		deck_menu.add_item("Select a deck")
		deck_menu.set_item_metadata(0, "")
		equipped_index = 0
	for n in names:
		var text = n
		if GameState.deck_error(GameState.decks[n], GameState.rules) != "":
			text += "  (not legal here)"
		deck_menu.add_item(text)
		var index = deck_menu.item_count - 1
		deck_menu.set_item_metadata(index, n)
		if n == GameState.selected_deck:
			equipped_index = index
	if equipped_index >= 0:
		deck_menu.select(equipped_index)
	_refresh_legality()


func _refresh_legality():
	var has_deck = GameState.decks.has(GameState.selected_deck)
	var cards = GameState.decks.get(GameState.selected_deck, [])
	var error = GameState.deck_error(cards, GameState.rules)
	if not has_deck:
		error = "No deck equipped"
	play_again_button.disabled = error != ""
	if error_label:
		error_label.text = error
		error_label.add_theme_color_override("font_color", bad_color)


func _on_deck_selected(index):
	var deck_name = deck_menu.get_item_metadata(index)
	if deck_name == "":
		return
	GameState.selected_deck = deck_name
	GameState.save_game()
	_refresh_legality()


func _on_play_again():
	GameState.pending_game_over = {}
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_binder():
	# the binder's Back button returns here, to this same game over screen
	GameState.pending_game_over = {"result": result, "title": title, "reason": reason}
	GameState.go_to_binder("gameover")


func _on_give_up():
	GameState.pending_game_over = {}
	GameState.return_to_overworld()
