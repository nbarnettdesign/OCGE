extends ItemList

# The deck list in the binder.
#  - drag a collection card onto it to add the card
#  - drag a row off it and let go anywhere else to remove one copy
#  - letting go back on the list just cancels

signal card_dropped(card_name)      # a collection card was dropped here
signal dragged_out(card_name)       # a row was dropped somewhere that isn't this list

var rows = []                       # card name behind each row (Binder keeps this up to date)
var can_accept = Callable()         # func(card_name) -> bool
var make_preview = Callable()       # func(card_name) -> Control, shown under the mouse

var dragging_card = ""


func _get_drag_data(at_position):
	var index = get_item_at_position(at_position, true)
	if index < 0 or index >= rows.size():
		return null
	dragging_card = rows[index]
	if make_preview.is_valid():
		set_drag_preview(make_preview.call(dragging_card))
	return {"card": dragging_card, "from": "deck"}


func _can_drop_data(_at_position, data):
	if not (data is Dictionary) or not data.has("card"):
		return false
	if data["from"] == "deck":
		return true      # back onto the list = cancel
	return can_accept.is_valid() and can_accept.call(data["card"])


func _drop_data(_at_position, data):
	if data["from"] == "collection":
		card_dropped.emit(data["card"])


func _notification(what):
	if what == NOTIFICATION_DRAG_END and dragging_card != "":
		var card_name = dragging_card
		dragging_card = ""
		if not get_viewport().gui_is_drag_successful():
			dragged_out.emit(card_name)
