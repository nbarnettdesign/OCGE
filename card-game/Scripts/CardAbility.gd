class_name CardAbility
extends RefCounted

var card   # the card this script belongs to

func battle():
	return card.get_node("../../BattleManager")
