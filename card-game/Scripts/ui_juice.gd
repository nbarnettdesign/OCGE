extends Node

# Every button gets a hover sound, a click sound and a small pop. Big buttons (cards) get sounds only.
# Add a button to the group "no_juice" to leave it alone.

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node):
	if node is BaseButton and not node.is_in_group("no_juice"):
		node.mouse_entered.connect(_hover.bind(node))
		node.mouse_exited.connect(_unhover.bind(node))
		node.pressed.connect(func(): Audio.play("click"))


func _hover(button):
	if button.disabled:
		return
	Audio.play("hover")
	if button.size.y > 120:
		return
	button.pivot_offset = button.size / 2.0
	button.create_tween().tween_property(button, "scale", Vector2(1.05, 1.05), 0.08)


func _unhover(button):
	if button.size.y > 120:
		return
	button.create_tween().tween_property(button, "scale", Vector2.ONE, 0.08)
