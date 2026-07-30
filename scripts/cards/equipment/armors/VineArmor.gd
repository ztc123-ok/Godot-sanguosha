class_name VineArmor
extends "res://scripts/cards/equipment/Armor.gd"


func _init() -> void:
	super(
		CardType.VINE_ARMOR,
		"藤甲",
		"锁定技：【南蛮入侵】【万箭齐发】对你无效；你受到的火焰伤害+1。"
	)
