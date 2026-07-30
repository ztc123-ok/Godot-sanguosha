class_name SerpentSpear
extends "res://scripts/cards/equipment/Weapon.gd"


func _init() -> void:
	super(
		CardType.SERPENT_SPEAR,
		"丈八蛇矛",
		"攻击范围3。你可以将两张手牌当【杀】使用或打出。",
		3
	)
