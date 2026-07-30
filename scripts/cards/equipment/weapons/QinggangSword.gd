class_name QinggangSword
extends "res://scripts/cards/equipment/Weapon.gd"


func _init() -> void:
	super(
		CardType.QINGGANG_SWORD,
		"青釭剑",
		"攻击范围2。锁定技：你的【杀】无视目标防具。",
		2
	)
