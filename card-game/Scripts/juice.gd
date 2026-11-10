extends CanvasLayer

# Combat feedback: floating numbers, flashes, screen shake, hit-stop, turn banners, heart pops.

const BIG_HIT = 40                         # damage at or above this gets a bigger number and a hit-stop
const RED = Color(1.0, 0.35, 0.3)
const GREEN = Color(0.4, 1.0, 0.5)
const GOLD = Color(0.86, 0.70, 0.36)

var shake_strength = 0.0
var shake_left = 0.0
var shake_total = 0.01
var tip_panel = null
var tip_label = null
var tip_owner = null

func _ready():
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta):
	if tip_owner != null and not is_instance_valid(tip_owner):
		hide_tip()
	if shake_left > 0.0:
		shake_left -= delta
		var fade = clampf(shake_left / shake_total, 0.0, 1.0)
		_apply_offset(Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength * fade)
		if shake_left <= 0.0:
			_apply_offset(Vector2.ZERO)


func _apply_offset(offset):
	var cam = get_viewport().get_camera_2d()
	if cam:
		cam.offset = offset
	else:
		get_viewport().canvas_transform = Transform2D(0.0, offset)


func shake(strength = 8.0, duration = 0.25):
	shake_strength = maxf(shake_strength if shake_left > 0.0 else 0.0, strength)
	shake_total = maxf(duration, 0.05)
	shake_left = shake_total


func hit_stop(duration = 0.06):
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func _screen_pos(node):
	var slot = node.get("card_slot_card_is_in")      # the home slot, not where the attack animation moved the card
	if slot != null and is_instance_valid(slot):
		return slot.get_global_transform_with_canvas().origin
	return node.get_global_transform_with_canvas().origin


# a number that pops, floats up and fades
func float_text(screen_pos, text, color = Color.WHITE, size = 38):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.reset_size()
	label.position = screen_pos - label.size / 2.0
	label.pivot_offset = label.size / 2.0
	var t = create_tween()
	t.tween_property(label, "scale", Vector2(1.3, 1.3), 0.1).from(Vector2(0.4, 0.4))
	t.tween_property(label, "scale", Vector2.ONE, 0.08)
	t.tween_property(label, "position:y", label.position.y - 70.0, 0.7)
	t.parallel().tween_property(label, "modulate:a", 0.0, 0.45).set_delay(0.3)
	t.tween_callback(label.queue_free)


func float_at(card, text, color = Color.WHITE, size = 38):
	if is_instance_valid(card):
		float_text(_screen_pos(card) + Vector2(0, -60), text, color, size)


func flash(node, color = RED):
	if not is_instance_valid(node):
		return
	var base = node.get_meta("flash_base", node.modulate)
	node.set_meta("flash_base", base)
	var old = node.get_meta("flash_tween", null)
	if old and old.is_valid():
		old.kill()
	node.modulate = color
	var t = node.create_tween()
	node.set_meta("flash_tween", t)
	t.tween_property(node, "modulate", base, 0.3)


# everything that should happen when a card takes damage
func hit(card, amount):
	if not is_instance_valid(card):
		return
	var big = amount >= BIG_HIT
	float_at(card, "-" + str(int(amount)), RED, 46 if big else 36)
	flash(card.get_node_or_null("CardImage"))
	shake(clampf(amount * 0.2, 3.0, 20.0), 0.2)
	if big:
		hit_stop(0.07)


func banner(text, color = GOLD):
	var label = Label.new()
	label.text = text
	label.theme_type_variation = "TitleLabel"
	label.add_theme_font_size_override("font_size", 72)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 12)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	add_child(label)
	label.pivot_offset = get_viewport().get_visible_rect().size / 2.0
	var t = create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.15)
	t.parallel().tween_property(label, "scale", Vector2.ONE, 0.2).from(Vector2(1.4, 1.4))
	t.tween_interval(0.5)
	t.tween_property(label, "modulate:a", 0.0, 0.3)
	t.tween_callback(label.queue_free)


# a lost heart grows and fades out where it was
func heart_pop(heart):
	if not is_instance_valid(heart) or not heart.is_inside_tree():
		return
	var ghost = heart.duplicate()
	add_child(ghost)
	ghost.position = heart.get_global_transform_with_canvas().origin
	if ghost is Control:
		ghost.size = heart.size
		ghost.pivot_offset = heart.size / 2.0
	var t = create_tween()
	t.tween_property(ghost, "scale", Vector2(1.8, 1.8), 0.35)
	t.parallel().tween_property(ghost, "modulate:a", 0.0, 0.35)
	t.parallel().tween_property(ghost, "rotation", 0.5, 0.35)
	t.tween_callback(ghost.queue_free)

# a coin toss overlay. Face one is you, face two is the opponent. Click or press a key to skip.
func coin_flip(player_first, opponent_name = "Opponent"):
	var screen = get_viewport().get_visible_rect().size
	var state = {"skip": false}
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.modulate.a = 0.0
	root.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventKey) and e.pressed:
			state["skip"] = true)
	add_child(root)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.86, 0.70, 0.36)
	style.set_corner_radius_all(110)
	style.set_border_width_all(8)
	style.border_color = Color(0.55, 0.42, 0.16)
	var coin = Panel.new()
	coin.add_theme_stylebox_override("panel", style)
	coin.size = Vector2(220, 220)
	coin.pivot_offset = Vector2(110, 110)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rest = screen / 2.0 - coin.size / 2.0
	coin.position = rest
	root.add_child(coin)

	var face = Label.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face.add_theme_font_size_override("font_size", 52)
	face.add_theme_color_override("font_color", Color(0.25, 0.17, 0.05))
	face.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	face.text = "YOU"
	coin.add_child(face)

	var result = Label.new()
	result.text = "You go first!" if player_first else "%s goes first!" % opponent_name
	result.theme_type_variation = "TitleLabel"
	result.add_theme_font_size_override("font_size", 56)
	result.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	result.add_theme_constant_override("outline_size", 10)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.size = Vector2(screen.x, 80)
	result.position = Vector2(0, rest.y + 260.0)
	result.pivot_offset = result.size / 2.0
	result.modulate.a = 0.0
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(result)

	var end_angle = 5 * TAU + (0.0 if player_first else PI)
	var step = func(p):                           # p goes 0 to 1 over the whole toss
		var angle = end_angle * (1.0 - pow(1.0 - p, 2.0))
		var c = cos(angle)
		coin.scale.x = maxf(absf(c), 0.04)
		face.text = "YOU" if c >= 0.0 else "THEM"
		coin.position.y = rest.y - sin(p * PI) * 260.0

	var fade_in = create_tween()
	fade_in.tween_property(root, "modulate:a", 1.0, 0.2)
	await _wait_tween(fade_in, state)
	var toss = create_tween()
	toss.tween_method(step, 0.0, 1.0, 1.7)
	await _wait_tween(toss, state)
	step.call(1.0)                                # land exactly on the result
	if has_node("/root/Audio"):
		get_node("/root/Audio").play("flip")
	var pop = create_tween()
	pop.tween_property(result, "modulate:a", 1.0, 0.15)
	pop.parallel().tween_property(result, "scale", Vector2.ONE, 0.2).from(Vector2(0.6, 0.6))
	await _wait_tween(pop, state)
	var held = 0.0
	while held < 1.0 and not state["skip"]:
		await get_tree().process_frame
		held += get_process_delta_time()
	var fade_out = create_tween()
	fade_out.tween_property(root, "modulate:a", 0.0, 0.25)
	await fade_out.finished
	root.queue_free()


func _wait_tween(t, state):
	while t.is_valid() and t.is_running():
		if state["skip"]:
			t.custom_step(10.0)                   # jump straight to the end
			break
		await get_tree().process_frame
		
# the card's picture as a screen rectangle (follows scale and rotation)
func card_rect(card):
	var rect = null
	for node in card.find_children("*", "CanvasItem", true, false):
		if not (node is Sprite2D or node is TextureRect) or not node.is_visible_in_tree():
			continue
		if node.get("texture") == null:
			continue
		var local = Rect2(Vector2.ZERO, node.size) if node is Control else node.get_rect()
		var xf = node.get_global_transform_with_canvas()
		var r = Rect2(xf * local.position, Vector2.ZERO)
		for corner in [Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)]:
			r = r.expand(xf * corner)
		if r.size.x < 40.0 or r.size.y < 40.0:
			continue                                # skip small icons such as attached energy
		rect = r if rect == null else rect.merge(r)
	if rect == null:
		var p = _screen_pos(card)
		return Rect2(p - Vector2(60, 85), Vector2(120, 170))
	return rect


func _ensure_tip():
	if tip_panel != null:
		return
	tip_panel = PanelContainer.new()
	tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_label = Label.new()
	tip_label.custom_minimum_size = Vector2(240, 0)
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_panel.add_child(tip_label)
	tip_panel.visible = false
	add_child(tip_panel)


func show_tip(card, text):
	_ensure_tip()
	tip_owner = card
	tip_label.text = text
	tip_panel.visible = true
	tip_panel.size = Vector2.ZERO
	_place_tip.call_deferred()


func _place_tip():
	if not is_instance_valid(tip_owner) or tip_panel == null:
		return
	var rect = card_rect(tip_owner)
	var screen = get_viewport().get_visible_rect().size
	var x = rect.end.x + 16.0
	if x + tip_panel.size.x > screen.x:
		x = rect.position.x - tip_panel.size.x - 16.0
	var y = clampf(rect.get_center().y - tip_panel.size.y / 2.0, 8.0, screen.y - tip_panel.size.y - 8.0)
	tip_panel.position = Vector2(x, y)


func hide_tip():
	tip_owner = null
	if tip_panel:
		tip_panel.visible = false
