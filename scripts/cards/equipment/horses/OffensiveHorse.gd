class_name OffensiveHorse
extends "res://scripts/cards/equipment/Horse.gd"


func _init() -> void:
	super(
		CardType.HORSE_MINUS,
		"-1马",
		"进攻坐骑：你计算与其他角色的距离时-1（最终距离至少为1）。",
		Slot.HORSE_MINUS,
		-1
	)
