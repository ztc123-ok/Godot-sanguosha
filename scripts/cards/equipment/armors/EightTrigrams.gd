class_name EightTrigrams
extends "res://scripts/cards/equipment/Armor.gd"


func _init() -> void:
	super(
		CardType.EIGHT_TRIGRAMS,
		"八卦阵",
		"每当你需要使用或打出【闪】时，可进行判定；若结果为红色，视为使用或打出【闪】。"
	)
