class_name VermilionFan
extends "res://scripts/cards/equipment/Weapon.gd"


func _init() -> void:
	super(
		CardType.VERMILION_FAN,
		"朱雀羽扇",
		"攻击范围4。你使用的普通【杀】视为火属性【杀】。",
		4
	)
