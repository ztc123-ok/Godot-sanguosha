class_name Halberd
extends "res://scripts/cards/equipment/Weapon.gd"


func _init() -> void:
	super(
		CardType.HALBERD,
		"方天画戟",
		"攻击范围4。最后一张手牌为【杀】时可额外指定目标；双人局无额外目标。",
		4
	)
