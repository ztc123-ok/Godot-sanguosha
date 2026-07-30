class_name QilinBow
extends "res://scripts/cards/equipment/Weapon.gd"


func _init() -> void:
	super(
		CardType.QILIN_BOW,
		"麒麟弓",
		"攻击范围5。你的【杀】造成伤害后，可弃置目标装备区里的一匹马。",
		5
	)
