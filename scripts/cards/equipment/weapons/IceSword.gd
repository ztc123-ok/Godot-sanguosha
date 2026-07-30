class_name IceSword
extends "res://scripts/cards/equipment/Weapon.gd"


func _init() -> void:
	super(
		CardType.ICE_SWORD,
		"寒冰剑",
		"攻击范围2。你的【杀】即将造成伤害时，可防止伤害并弃置目标两张牌。",
		2
	)
