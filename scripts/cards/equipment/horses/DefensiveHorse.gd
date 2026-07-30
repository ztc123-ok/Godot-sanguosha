class_name DefensiveHorse
extends "res://scripts/cards/equipment/Horse.gd"


func _init() -> void:
	super(
		CardType.HORSE_PLUS,
		"+1马",
		"防御坐骑：其他角色计算与你的距离时+1。",
		Slot.HORSE_PLUS,
		1
	)
