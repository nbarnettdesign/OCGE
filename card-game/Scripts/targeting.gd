extends CanvasLayer

# While you aim an attack: a curved arrow, outlines round legal targets, and a damage preview
# (with any effects it adds and Trample overflow). While you drag a sport card: outlines and a preview.

const VALID = Color(1.0, 0.85, 0.35)
const LETHAL = Color(1.0, 0.35, 0.3)
const NONE = Color(0.65, 0.65, 0.7)
const STATUS_NAMES = {"burned": "Burned", "poisoned": "Poisoned", "blinded": "Blinded",
	"tied_to": "Tied", "cant_attack": "Can't attack"}

var canvas
var cm
var battle
var time = 0.0


func _ready():
	layer = 120
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_overlay)
	add_child(canvas)


func _process(delta):
	time += delta
	canvas.queue_redraw()


func _draw_overlay():
	var scene = get_tree().current_scene
	if scene == null:
		return
	cm = scene.get_node_or_null("CardManager")
	battle = scene.get_node_or_null("BattleManager")
	if cm == null or battle == null or battle.game_over or battle.is_opponents_turn or battle.player_is_attacking:
		return
	var source = cm.selected_monster
	if is_instance_valid(source) and source.card_slot_card_is_in and not source.mana_selected:
		_draw_attack(source)
	elif is_instance_valid(cm.card_being_dragged) and cm.card_being_dragged.card_type == "Sport":
		_draw_sport(cm.card_being_dragged)


func _pulse():
	return 0.45 + 0.2 * sin(time * 5.0)


# ---------- a monster with an attack chosen ----------

func _draw_attack(source):
	var move = source.attacks[source.selected_attack]
	var mode = move.get("target", "enemy")
	if mode == "none":
		return
	var candidates = battle.opponent_cards_on_battlefield.duplicate()
	if mode == "any":
		candidates += battle.player_cards_on_battlefield
		candidates.erase(source)
	elif battle.has_method("neutral_cards"):
		candidates += battle.neutral_cards(battle.player_cards_on_battlefield, source)
	var legal = []
	for c in candidates:
		if _legal(source, c, mode):
			legal.append(c)
			_outline(c, VALID, _pulse())
	var hover = cm.raycast_check_for_opponent_card()
	if hover == null:
		hover = cm.raycast_check_for_card()
	if hover == source or not hover in legal:
		hover = null
	var end = get_viewport().get_mouse_position()
	var color = NONE
	if hover:
		end = Juice.card_rect(hover).get_center()
		color = VALID
		var lines = []
		var friendly = hover in battle.player_cards_on_battlefield and not battle.has_keyword(hover, "neutral")
		var effect_only = move["damage"] is int and move["damage"] == 0 and not move.get("crush", false)
		if friendly or effect_only:
			lines.append([str(move["name"]), VALID])
		else:
			var damage = battle.predict_damage(source, move, hover)
			var result = _damage_text(damage, hover)
			color = result[1]
			lines.append(result)
			if battle.has_keyword(source, "trample") and battle.has_method("card_behind") and damage >= hover.health:
				var behind = battle.card_behind(hover)
				if behind:
					var spill = battle.predict_amount(damage - hover.health, behind, "attack")
					if spill > 0:
						var spill_result = _damage_text(spill, behind)
						_outline(behind, spill_result[1], 0.9)
						_label(behind, [[spill_result[0] + "  (trample)", spill_result[1]]])
		for effect in move.get("inflicts", []):
			lines.append(["+ " + STATUS_NAMES.get(effect, str(effect).capitalize()), VALID])
		_outline(hover, color, 0.95)
		_label(hover, lines)
		var heal_amount = int(move.get("heals", 0))
		if heal_amount > 0:
			var gain = mini(heal_amount, source.max_health - source.health)
			if gain > 0:
				_label(source, [["+%d" % gain, Color(0.4, 1.0, 0.5)]])
	_arrow(Juice.card_rect(source).get_center(), end, color)


func _legal(source, target, mode):
	if mode == "any":
		return true
	if target in battle.player_cards_on_battlefield:
		return battle.has_keyword(target, "neutral")
	return battle.can_be_attacked(target, source)


# ---------- a sport being dragged ----------

func _draw_sport(card):
	for c in battle.opponent_cards_on_battlefield:
		_outline(c, VALID, _pulse())
	var hover = cm.raycast_check_for_opponent_card()
	if hover:
		var result = _damage_text(battle.predict_amount(card.attack, hover, "sport"), hover)
		_outline(hover, result[1], 0.95)
		_label(hover, [result])


func _damage_text(damage, target):
	if damage <= 0:
		return ["No effect", NONE]
	if damage >= target.health:
		return ["-%d  KO!" % damage, LETHAL]
	return ["-%d" % damage, VALID]


# ---------- drawing helpers ----------

# the card's own outline (it follows the card's scale and rotation)
func _outline(card, color, alpha):
	var img = card.get_node_or_null("CardImage")
	if img == null:
		return
	var local = Rect2(Vector2.ZERO, img.size) if img is Control else img.get_rect()
	canvas.draw_set_transform_matrix(img.get_global_transform_with_canvas())
	canvas.draw_rect(local.grow(6.0), Color(0, 0, 0, alpha * 0.6), false, 10.0)
	canvas.draw_rect(local.grow(6.0), Color(color.r, color.g, color.b, alpha), false, 5.0)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


# stacked lines of text above a card: each entry is [text, colour]
func _label(card, lines):
	var rect = Juice.card_rect(card)
	var y = rect.position.y - 14.0 - 38.0 * (lines.size() - 1)
	var font = canvas.get_theme_default_font()
	for line in lines:
		var pos = Vector2(rect.get_center().x - 160.0, y)
		canvas.draw_string_outline(font, pos, line[0], HORIZONTAL_ALIGNMENT_CENTER, 320.0, 32, 8, Color(0, 0, 0, 0.9))
		canvas.draw_string(font, pos, line[0], HORIZONTAL_ALIGNMENT_CENTER, 320.0, 32, line[1])
		y += 38.0


func _arrow(from, to, color):
	var ctrl = (from + to) / 2.0 + Vector2(0, -80.0 - from.distance_to(to) * 0.15)
	var points = PackedVector2Array()
	for i in 21:
		var t = i / 20.0
		points.append(from.lerp(ctrl, t).lerp(ctrl.lerp(to, t), t))
	canvas.draw_polyline(points, Color(0, 0, 0, 0.6), 10.0, true)
	canvas.draw_polyline(points, color, 6.0, true)
	var dir = (points[points.size() - 1] - points[points.size() - 2]).normalized()
	var side = dir.orthogonal()
	var tip = points[points.size() - 1] + dir * 14.0
	var back = points[points.size() - 1] - dir * 26.0
	canvas.draw_colored_polygon(PackedVector2Array([tip, back + side * 18.0, back - side * 18.0]), color)
