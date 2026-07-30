class_name SilverLion
extends "res://scripts/cards/equipment/Armor.gd"


func _init() -> void:
	super(
		CardType.SILVER_LION,
		"白银狮子",
		"锁定技：每次受到伤害时伤害值至多为1；失去装备区里的此牌后回复1点体力。"
	)
