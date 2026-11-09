extends CanvasLayer

var rect

func _ready():
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate.a = 0.0
	add_child(rect)


func change_scene(path, duration = 0.25):
	rect.mouse_filter = Control.MOUSE_FILTER_STOP       # no clicking during the fade
	var out = create_tween()
	out.tween_property(rect, "modulate:a", 1.0, duration)
	await out.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame                      # the new scene is up
	var back = create_tween()
	back.tween_property(rect, "modulate:a", 0.0, duration)
	await back.finished
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
