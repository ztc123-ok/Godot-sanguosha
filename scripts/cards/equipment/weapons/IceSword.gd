class_name IceSword
extends "res://scripts/cards/equipment/Weapon.gd"


func _init() -> void:
	super(
		CardType.ICE_SWORD,
		"寒冰剑",
		"攻击范围2。你的【杀】即将造成伤害时，若目标有牌，可防止伤害并依次弃置其两张牌。",
		2
	)
