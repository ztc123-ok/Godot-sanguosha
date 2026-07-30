class_name RockCleavingAxe
extends "res://scripts/cards/equipment/Weapon.gd"


func _init() -> void:
	super(
		CardType.ROCK_CLEAVING_AXE,
		"贯石斧",
		"攻击范围3。你的【杀】被【闪】抵消后，可弃置两张牌令此【杀】仍造成伤害。",
		3
	)
