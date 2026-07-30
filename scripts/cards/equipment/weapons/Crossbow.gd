class_name Crossbow
extends "res://scripts/cards/equipment/Weapon.gd"


func _init() -> void:
	super(
		CardType.CROSSBOW,
		"诸葛连弩",
		"攻击范围1。锁定技：出牌阶段使用【杀】无次数限制。",
		1
	)
