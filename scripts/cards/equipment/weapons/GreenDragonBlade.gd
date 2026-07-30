class_name GreenDragonBlade
extends "res://scripts/cards/equipment/Weapon.gd"


func _init() -> void:
	super(
		CardType.GREEN_DRAGON_BLADE,
		"青龙偃月刀",
		"攻击范围3。你的【杀】被【闪】抵消后，可继续对同一目标使用【杀】。",
		3
	)
